import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { SignJWT } from "jose";
import request from "supertest";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

import { createApp } from "../src/app.js";
import { PostgresAuthService } from "../src/auth/postgres-auth-service.js";
import type { SmsProvider, SmsPurpose } from "../src/auth/sms-provider.js";
import type { AppConfig } from "../src/config.js";
import { Database } from "../src/database.js";
import {
  AccountDeletionCleanupError,
  AccountDeletionWorker,
  DatabaseOnlyAccountDeletionCleaner,
  type AccountDeletionJob,
} from "../src/workers/account-deletion-worker.js";
import { AuthMaintenanceWorker } from "../src/workers/auth-maintenance-worker.js";

const databaseUrl = process.env.TEST_DATABASE_URL;
const integration = describe.skipIf(databaseUrl === undefined);

class CapturingSmsProvider implements SmsProvider {
  readonly codes = new Map<string, string>();

  async sendCode(input: {
    phone: string;
    code: string;
    purpose: SmsPurpose;
    idempotencyKey: string;
  }): Promise<{ messageId: string }> {
    this.codes.set(`${input.phone}:${input.purpose}`, input.code);
    return { messageId: `message-${input.idempotencyKey}` };
  }
}

integration("PostgreSQL authentication", () => {
  const secret = Buffer.alloc(32, 11);
  const database = new Database(databaseUrl ?? "");
  const smsProvider = new CapturingSmsProvider();
  const authService = new PostgresAuthService({
    database,
    smsProvider,
    secrets: {
      phoneLookupPepper: Buffer.alloc(32, 1),
      phoneEncryptionKey: Buffer.alloc(32, 2),
      smsCodePepper: Buffer.alloc(32, 3),
      devicePepper: Buffer.alloc(32, 4),
      ipPepper: Buffer.alloc(32, 5),
      refreshTokenPepper: Buffer.alloc(32, 6),
      deletionTokenPepper: Buffer.alloc(32, 7),
      accessTokenKey: secret,
      accessTokenKeyId: "test-current",
      accessTokenPreviousKeys: new Map([
        ["test-previous", Buffer.alloc(32, 12)],
      ]),
    },
    issuer: "easylife-test",
    audience: "easylife-ios-test",
  });
  const config: AppConfig = {
    host: "127.0.0.1",
    port: 3000,
    nodeEnv: "test",
    logLevel: "silent",
    allowedOrigins: [],
    enableTestTriggers: false,
    fixedAccessTokens: [],
  };
  const app = createApp({ config, authService });
  const requestId = "6f2aa37d-e95d-4b52-8df4-0cf3e17e5188";

  beforeAll(async () => {
    const migrationRoot = fileURLToPath(
      new URL("../../database/migrations/", import.meta.url),
    );
    await database.pool.query(
      await readFile(`${migrationRoot}0001_initial.sql`, "utf8"),
    );
    await database.pool.query(
      await readFile(`${migrationRoot}0002_auth_hardening.sql`, "utf8"),
    );
    await database.pool.query(
      await readFile(`${migrationRoot}0003_auth_operations.sql`, "utf8"),
    );
  }, 30_000);

  afterAll(async () => {
    await database.close();
  });

  it("registers, rotates once, and revokes the session on replay", async () => {
    const phone = "+8613812345678";
    const deviceId = "6ecb2ba5-6c51-4a40-b908-8be4311c7f85";
    const login = await authenticate(phone, deviceId);

    const protectedResponse = await request(app)
      .post("/v1/emotion/analyze")
      .set("X-Request-Id", requestId)
      .set("Authorization", `Bearer ${login.tokens.accessToken}`)
      .send(emotionRequest());
    expect(protectedResponse.status).toBe(200);
    const context = await authService.authenticateAccessToken(
      login.tokens.accessToken,
    );
    expect(context).not.toBeNull();
    const previousToken = await new SignJWT({
      sid: context?.sessionId,
    })
      .setProtectedHeader({
        alg: "HS256",
        typ: "JWT",
        kid: "test-previous",
      })
      .setSubject(context?.userId ?? "")
      .setIssuer("easylife-test")
      .setAudience("easylife-ios-test")
      .setIssuedAt()
      .setExpirationTime("15m")
      .sign(Buffer.alloc(32, 12));
    expect(await authService.authenticateAccessToken(previousToken)).toEqual(
      context,
    );

    const refresh = await request(app)
      .post("/v1/auth/token/refresh")
      .set("X-Request-Id", requestId)
      .send({
        refreshToken: login.tokens.refreshToken,
        deviceId,
      });
    expect(refresh.status).toBe(200);

    const replay = await request(app)
      .post("/v1/auth/token/refresh")
      .set("X-Request-Id", requestId)
      .send({
        refreshToken: login.tokens.refreshToken,
        deviceId,
      });
    expect(replay.status).toBe(401);
    expect(replay.body.error.code).toBe("INVALID_REFRESH_TOKEN");

    const revoked = await request(app)
      .post("/v1/emotion/analyze")
      .set("X-Request-Id", requestId)
      .set("Authorization", `Bearer ${refresh.body.accessToken}`)
      .send(emotionRequest());
    expect(revoked.status).toBe(401);
  });

  it("persists failed SMS attempts and invalidates the fifth failure", async () => {
    const phone = "+8613612345678";
    const deviceId = "9ecb2ba5-6c51-4a40-b908-8be4311c7f85";
    const challenge = await request(app)
      .post("/v1/auth/sms/codes")
      .set("X-Request-Id", requestId)
      .send({ phone, purpose: "login", deviceId });
    expect(challenge.status).toBe(200);
    const correctCode = smsProvider.codes.get(`${phone}:login`);
    const wrongCode = correctCode === "000000" ? "000001" : "000000";

    for (let attempt = 1; attempt <= 5; attempt += 1) {
      const failure = await request(app)
        .post("/v1/auth/sms/verify")
        .set("X-Request-Id", requestId)
        .send({
          challengeId: challenge.body.challengeId,
          phone,
          code: wrongCode,
          deviceId,
        });
      expect(
        failure.status,
        `attempt ${attempt}: ${JSON.stringify(failure.body)}`,
      ).toBe(attempt === 5 ? 429 : 422);
    }

    const invalidated = await request(app)
      .post("/v1/auth/sms/verify")
      .set("X-Request-Id", requestId)
      .send({
        challengeId: challenge.body.challengeId,
        phone,
        code: correctCode,
        deviceId,
      });
    expect(invalidated.status).toBe(410);
  });

  it("logs out idempotently and invalidates protected access", async () => {
    const phone = "+8613912345678";
    const deviceId = "7ecb2ba5-6c51-4a40-b908-8be4311c7f85";
    const login = await authenticate(phone, deviceId);

    for (let attempt = 0; attempt < 2; attempt += 1) {
      const logout = await request(app)
        .post("/v1/auth/logout")
        .set("X-Request-Id", requestId)
        .set("Authorization", `Bearer ${login.tokens.accessToken}`)
        .send({ deviceId });
      expect(logout.status).toBe(204);
    }

    const protectedResponse = await request(app)
      .post("/v1/emotion/analyze")
      .set("X-Request-Id", requestId)
      .set("Authorization", `Bearer ${login.tokens.accessToken}`)
      .send(emotionRequest());
    expect(protectedResponse.status).toBe(401);
  });

  it("retries a failed deletion cleanup without purging the user", async () => {
    const phone = "+8613512345678";
    const deviceId = "aecb2ba5-6c51-4a40-b908-8be4311c7f85";
    const login = await authenticate(phone, deviceId);
    const user = await authService.authenticateAccessToken(
      login.tokens.accessToken,
    );
    expect(user).not.toBeNull();
    const deletionRequestId = "b2000000-0000-0000-0000-000000000001";
    await database.pool.query("SELECT begin_account_deletion($1, $2)", [
      user?.userId,
      deletionRequestId,
    ]);

    const failingCleaner = {
      async cleanup(_job: AccountDeletionJob): Promise<void> {
        throw new AccountDeletionCleanupError("external_cleanup_retryable");
      },
    };
    const worker = new AccountDeletionWorker(database, failingCleaner, {
      workerId: "failing-worker",
      leaseSeconds: 300,
      maxBackoffSeconds: 3600,
    });
    expect(await worker.runOnce()).toBe(true);

    const failed = await database.pool.query<{
      status: string;
      failure_code: string;
      user_exists: boolean;
    }>(
      `SELECT
        deletion.status,
        deletion.failure_code,
        EXISTS (
          SELECT 1 FROM users WHERE id = deletion.user_id
        ) AS user_exists
       FROM account_deletion_requests AS deletion
       WHERE deletion.id = $1`,
      [deletionRequestId],
    );
    expect(failed.rows[0]).toEqual({
      status: "failed",
      failure_code: "external_cleanup_retryable",
      user_exists: true,
    });
  });

  it("removes expired authentication operational data", async () => {
    const userId = "c1000000-0000-0000-0000-000000000001";
    await database.pool.query(
      `INSERT INTO users (
        id,
        phone_lookup_hash,
        phone_ciphertext
      )
      VALUES ($1, decode(repeat('c1', 32), 'hex'), 'ciphertext')`,
      [userId],
    );
    await database.pool.query(
      `INSERT INTO auth_sessions (
        id,
        user_id,
        device_lookup_hash,
        refresh_token_hash,
        created_at,
        expires_at,
        revoked_at
      )
      VALUES (
        'c2000000-0000-0000-0000-000000000001',
        $1,
        decode(repeat('c2', 32), 'hex'),
        decode(repeat('c3', 32), 'hex'),
        now() - interval '61 days',
        now() - interval '31 days',
        now() - interval '31 days'
      )`,
      [userId],
    );
    await database.pool.query(
      `INSERT INTO account_deletion_tokens (
        token_hash,
        user_id,
        device_lookup_hash,
        created_at,
        expires_at
      )
      VALUES (
        decode(repeat('c4', 32), 'hex'),
        $1,
        decode(repeat('c2', 32), 'hex'),
        now() - interval '3 days',
        now() - interval '2 days'
      )`,
      [userId],
    );
    await database.pool.query(
      `INSERT INTO security_events (
        user_id,
        event_type,
        outcome,
        created_at
      )
      VALUES ($1, 'old_event', 'success', now() - interval '181 days')`,
      [userId],
    );

    await new AuthMaintenanceWorker(database).runOnce();

    const counts = await database.pool.query<{
      sessions: string;
      deletion_tokens: string;
      security_events: string;
    }>(
      `SELECT
        (SELECT count(*) FROM auth_sessions
          WHERE user_id = $1)::text AS sessions,
        (SELECT count(*) FROM account_deletion_tokens
          WHERE user_id = $1)::text AS deletion_tokens,
        (SELECT count(*) FROM security_events
          WHERE user_id = $1)::text AS security_events`,
      [userId],
    );
    expect(counts.rows[0]).toEqual({
      sessions: "0",
      deletion_tokens: "0",
      security_events: "0",
    });
  });

  it("keeps the existing deletion flow and revokes every session", async () => {
    const phone = "+8613712345678";
    const deviceId = "8ecb2ba5-6c51-4a40-b908-8be4311c7f85";
    const login = await authenticate(phone, deviceId);
    await database.pool.query(
      `UPDATE sms_challenges
       SET
         created_at = now() - interval '2 minutes',
         resend_after = now() - interval '1 minute'`,
    );

    const deletionChallenge = await request(app)
      .post("/v1/auth/sms/codes")
      .set("X-Request-Id", requestId)
      .send({
        phone,
        purpose: "account_deletion",
        deviceId,
      });
    expect(deletionChallenge.status).toBe(200);

    const deletionCode = smsProvider.codes.get(`${phone}:account_deletion`);
    expect(deletionCode).toBeDefined();
    const verification = await request(app)
      .post("/v1/auth/sms/verify")
      .set("X-Request-Id", requestId)
      .send({
        challengeId: deletionChallenge.body.challengeId,
        phone,
        code: deletionCode,
        deviceId,
      });
    expect(verification.status).toBe(200);
    expect(verification.body.purpose).toBe("account_deletion");

    const deletion = await request(app)
      .delete("/v1/me/account")
      .set("X-Request-Id", requestId)
      .set("Authorization", `Bearer ${login.tokens.accessToken}`)
      .send({
        deletionToken: verification.body.deletionToken,
        deviceId,
      });
    expect(deletion.status).toBe(202);
    expect(deletion.body.status).toBe("pending");

    const protectedResponse = await request(app)
      .post("/v1/emotion/analyze")
      .set("X-Request-Id", requestId)
      .set("Authorization", `Bearer ${login.tokens.accessToken}`)
      .send(emotionRequest());
    expect(protectedResponse.status).toBe(401);

    const worker = new AccountDeletionWorker(
      database,
      new DatabaseOnlyAccountDeletionCleaner(),
      {
        workerId: "integration-worker",
        leaseSeconds: 300,
        maxBackoffSeconds: 3600,
      },
    );
    expect(await worker.runOnce()).toBe(true);
    const completed = await database.pool.query<{
      status: string;
      user_id: string | null;
    }>(
      `SELECT status, user_id
       FROM account_deletion_requests
       WHERE id = $1`,
      [deletion.body.deletionRequestId],
    );
    expect(completed.rows[0]).toEqual({
      status: "completed",
      user_id: null,
    });
  });

  async function authenticate(phone: string, deviceId: string) {
    const challenge = await request(app)
      .post("/v1/auth/sms/codes")
      .set("X-Request-Id", requestId)
      .send({ phone, purpose: "login", deviceId });
    expect(challenge.status).toBe(200);

    const code = smsProvider.codes.get(`${phone}:login`);
    expect(code).toBeDefined();
    const verification = await request(app)
      .post("/v1/auth/sms/verify")
      .set("X-Request-Id", requestId)
      .send({
        challengeId: challenge.body.challengeId,
        phone,
        code,
        deviceId,
      });
    expect(verification.status).toBe(200);
    return verification.body as {
      tokens: {
        accessToken: string;
        refreshToken: string;
      };
    };
  }
});

function emotionRequest() {
  return {
    text: "今天有点累。",
    context: {
      nickname: "小满",
      goals: [],
      personalTags: [],
      memoryNotes: [],
      petReminderStyle: "轻提醒",
    },
    client: {
      platform: "ios",
      appVersion: "0.3.0+3",
      locale: "zh-CN",
    },
  };
}
