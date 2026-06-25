import type { PoolClient } from "pg";

import type { Database } from "../database.js";

export interface AccountDeletionJob {
  id: string;
  userId: string;
  attemptCount: number;
}

export interface AccountDeletionCleaner {
  cleanup(job: AccountDeletionJob): Promise<void>;
}

export class DatabaseOnlyAccountDeletionCleaner implements AccountDeletionCleaner {
  async cleanup(_job: AccountDeletionJob): Promise<void> {}
}

export class WebhookAccountDeletionCleaner implements AccountDeletionCleaner {
  constructor(
    private readonly endpoint: URL,
    private readonly bearerToken: string,
  ) {}

  async cleanup(job: AccountDeletionJob): Promise<void> {
    const response = await fetch(this.endpoint, {
      method: "POST",
      headers: {
        authorization: `Bearer ${this.bearerToken}`,
        "content-type": "application/json",
        "idempotency-key": job.id,
      },
      body: JSON.stringify({
        deletionRequestId: job.id,
        userId: job.userId,
      }),
      signal: AbortSignal.timeout(15_000),
    });

    if (!response.ok) {
      throw new AccountDeletionCleanupError(
        response.status === 429 || response.status >= 500
          ? "external_cleanup_retryable"
          : "external_cleanup_rejected",
      );
    }
  }
}

export class AccountDeletionCleanupError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "AccountDeletionCleanupError";
  }
}

export class AccountDeletionWorker {
  constructor(
    private readonly database: Database,
    private readonly cleaner: AccountDeletionCleaner,
    private readonly options: {
      workerId: string;
      leaseSeconds: number;
      maxBackoffSeconds: number;
    },
  ) {}

  async runOnce(): Promise<boolean> {
    const job = await this.database.transaction((client) => this.claim(client));
    if (job === null) return false;

    try {
      await this.cleaner.cleanup(job);
      await this.database.pool.query("SELECT purge_deleted_account($1)", [
        job.id,
      ]);
    } catch (error) {
      await this.fail(job, error);
    }
    return true;
  }

  private async claim(client: PoolClient): Promise<AccountDeletionJob | null> {
    const result = await client.query<{
      id: string;
      user_id: string | null;
      attempt_count: number;
    }>(
      `WITH candidate AS (
        SELECT id
        FROM account_deletion_requests
        WHERE (
          status IN ('pending', 'failed')
          AND next_attempt_at <= now()
        ) OR (
          status = 'processing'
          AND lease_expires_at <= now()
        )
        ORDER BY requested_at
        FOR UPDATE SKIP LOCKED
        LIMIT 1
      )
      UPDATE account_deletion_requests AS deletion
      SET
        status = 'processing',
        attempt_count = deletion.attempt_count + 1,
        processing_started_at = now(),
        completed_at = NULL,
        failure_code = NULL,
        lease_expires_at = now() + ($1 * interval '1 second'),
        worker_id = $2
      FROM candidate
      WHERE deletion.id = candidate.id
      RETURNING
        deletion.id,
        deletion.user_id,
        deletion.attempt_count`,
      [this.options.leaseSeconds, this.options.workerId],
    );
    const row = result.rows[0];
    if (row === undefined || row.user_id === null) return null;
    return {
      id: row.id,
      userId: row.user_id,
      attemptCount: row.attempt_count,
    };
  }

  private async fail(job: AccountDeletionJob, error: unknown): Promise<void> {
    const code =
      error instanceof AccountDeletionCleanupError
        ? error.code
        : "account_deletion_failed";
    const backoffSeconds = Math.min(
      this.options.maxBackoffSeconds,
      60 * 2 ** Math.min(job.attemptCount, 10),
    );

    await this.database.pool.query(
      `UPDATE account_deletion_requests
       SET
         status = 'failed',
         failure_code = $2,
         next_attempt_at = now() + ($3 * interval '1 second'),
         lease_expires_at = NULL,
         worker_id = NULL
       WHERE id = $1
         AND status = 'processing'
         AND worker_id = $4`,
      [job.id, code, backoffSeconds, this.options.workerId],
    );
  }
}
