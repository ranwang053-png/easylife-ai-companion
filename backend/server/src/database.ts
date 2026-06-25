import { Pool, type PoolClient } from "pg";

export class Database {
  readonly pool: Pool;

  constructor(connectionString: string) {
    this.pool = new Pool({
      connectionString,
      max: 10,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 5_000,
      allowExitOnIdle: false,
    });
  }

  async transaction<T>(
    callback: (client: PoolClient) => Promise<T>,
  ): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const result = await callback(client);
      await client.query("COMMIT");
      return result;
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }

  async close(): Promise<void> {
    await this.pool.end();
  }

  async assertAuthSchema(): Promise<void> {
    const result = await this.pool.query<{
      sessions: string | null;
      refresh_history: string | null;
      deletion_tokens: string | null;
    }>(
      `SELECT
        to_regclass('auth_sessions')::text AS sessions,
        to_regclass('auth_refresh_token_history')::text AS refresh_history,
        to_regclass('account_deletion_tokens')::text AS deletion_tokens`,
    );
    const schema = result.rows[0];
    if (
      schema?.sessions === null ||
      schema?.refresh_history === null ||
      schema?.deletion_tokens === null ||
      schema === undefined
    ) {
      throw new Error(
        "Authentication database migrations 0001 and 0002 must be applied",
      );
    }
  }

  async assertOperationsSchema(): Promise<void> {
    const result = await this.pool.query<{
      deletion_columns: string;
      sms_columns: string;
    }>(
      `SELECT
        count(*) FILTER (
          WHERE table_name = 'account_deletion_requests'
            AND column_name IN (
              'attempt_count',
              'next_attempt_at',
              'lease_expires_at',
              'worker_id'
            )
        )::text AS deletion_columns,
        count(*) FILTER (
          WHERE table_name = 'sms_challenges'
            AND column_name IN (
              'provider_message_id',
              'provider_sent_at'
            )
        )::text AS sms_columns
       FROM information_schema.columns
       WHERE table_schema = current_schema()`,
    );
    if (
      Number(result.rows[0]?.deletion_columns ?? 0) !== 4 ||
      Number(result.rows[0]?.sms_columns ?? 0) !== 2
    ) {
      throw new Error(
        "Authentication operations migration 0003 must be applied",
      );
    }
  }
}
