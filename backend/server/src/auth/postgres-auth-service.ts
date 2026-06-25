import { randomUUID } from "node:crypto";
import type { Request } from "express";
import { decodeProtectedHeader, SignJWT, jwtVerify } from "jose";
import type { PoolClient } from "pg";

import type { Database } from "../database.js";
import type { JsonObject } from "../types.js";
import {
  AuthServiceError,
  type AuthContext,
  type AuthService,
} from "./auth-service.js";
import {
  encryptPhone,
  equalHashes,
  keyedHash,
  randomSmsCode,
  randomToken,
} from "./crypto.js";
import type { SmsProvider, SmsPurpose } from "./sms-provider.js";
import { recordSecurityEvent } from "./security-events.js";

const accessTokenExpiresIn = 900;
const refreshTokenExpiresIn = 2_592_000;

interface AuthSecrets {
  phoneLookupPepper: Buffer;
  phoneEncryptionKey: Buffer;
  smsCodePepper: Buffer;
  devicePepper: Buffer;
  ipPepper: Buffer;
  refreshTokenPepper: Buffer;
  deletionTokenPepper: Buffer;
  accessTokenKey: Uint8Array;
  accessTokenKeyId: string;
  accessTokenPreviousKeys: ReadonlyMap<string, Uint8Array>;
}

interface PostgresAuthOptions {
  database: Database;
  smsProvider: SmsProvider;
  secrets: AuthSecrets;
  issuer: string;
  audience: string;
}

interface SessionResult {
  userId: string;
  sessionId: string;
  refreshToken: string;
}

export class PostgresAuthService implements AuthService {
  constructor(private readonly options: PostgresAuthOptions) {}

  async sendSmsCode(body: JsonObject, request: Request): Promise<JsonObject> {
    const phone = body.phone as string;
    const purpose = body.purpose as SmsPurpose;
    const deviceId = body.deviceId as string;
    const challengeId = randomUUID();
    const code = randomSmsCode();
    const phoneHash = this.phoneHash(phone);
    const deviceHash = this.deviceHash(deviceId);
    const ipHash = keyedHash(
      this.clientAddress(request),
      this.options.secrets.ipPepper,
    );
    const codeHash = this.smsCodeHash(challengeId, code);

    await this.options.database.transaction(async (client) => {
      await client.query(
        "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
        [phoneHash.toString("hex")],
      );

      const limits = await client.query<{
        resend_blocked: boolean;
        phone_hour: string;
        phone_day: string;
        device_hour: string;
        ip_hour: string;
      }>(
        `SELECT
          EXISTS (
            SELECT 1 FROM sms_challenges
            WHERE phone_lookup_hash = $1
              AND resend_after > now()
          ) AS resend_blocked,
          (
            SELECT count(*) FROM sms_challenges
            WHERE phone_lookup_hash = $1
              AND created_at >= now() - interval '1 hour'
          ) AS phone_hour,
          (
            SELECT count(*) FROM sms_challenges
            WHERE phone_lookup_hash = $1
              AND created_at >= now() - interval '1 day'
          ) AS phone_day,
          (
            SELECT count(*) FROM sms_challenges
            WHERE device_lookup_hash = $2
              AND created_at >= now() - interval '1 hour'
          ) AS device_hour,
          (
            SELECT count(*) FROM sms_challenges
            WHERE ip_lookup_hash = $3
              AND created_at >= now() - interval '1 hour'
          ) AS ip_hour`,
        [phoneHash, deviceHash, ipHash],
      );
      const limit = limits.rows[0];
      if (
        limit === undefined ||
        limit.resend_blocked ||
        Number(limit.phone_hour) >= 5 ||
        Number(limit.phone_day) >= 10 ||
        Number(limit.device_hour) >= 20 ||
        Number(limit.ip_hour) >= 20
      ) {
        throw new AuthServiceError("RATE_LIMITED");
      }

      await client.query(
        `INSERT INTO sms_challenges (
          id,
          phone_lookup_hash,
          phone_ciphertext,
          purpose,
          code_hash,
          device_lookup_hash,
          ip_lookup_hash,
          expires_at,
          resend_after
        )
        VALUES (
          $1, $2, $3, $4, $5, $6, $7,
          now() + interval '5 minutes',
          now() + interval '60 seconds'
        )`,
        [
          challengeId,
          phoneHash,
          encryptPhone(phone, this.options.secrets.phoneEncryptionKey),
          purpose,
          codeHash,
          deviceHash,
          ipHash,
        ],
      );
    });

    try {
      const receipt = await this.options.smsProvider.sendCode({
        phone,
        code,
        purpose,
        requestId: request.requestId,
        idempotencyKey: challengeId,
      });
      await this.options.database.pool.query(
        `UPDATE sms_challenges
         SET
           provider_message_id = $2,
           provider_sent_at = now()
         WHERE id = $1`,
        [challengeId, receipt.messageId ?? null],
      );
      await recordSecurityEvent(this.options.database.pool, {
        requestId: request.requestId,
        eventType: "sms_code_send",
        outcome: "success",
        metadata: { purpose },
      });
    } catch {
      await this.options.database.pool.query(
        `UPDATE sms_challenges
         SET invalidated_at = COALESCE(invalidated_at, now())
         WHERE id = $1`,
        [challengeId],
      );
      await recordSecurityEvent(this.options.database.pool, {
        requestId: request.requestId,
        eventType: "sms_code_send",
        outcome: "failed",
        metadata: { purpose },
      });
      throw new AuthServiceError("SMS_PROVIDER_UNAVAILABLE");
    }

    return {
      challengeId,
      expiresIn: 300,
      resendAfter: 60,
    };
  }

  async verifySmsCode(body: JsonObject, request: Request): Promise<JsonObject> {
    const challengeId = body.challengeId as string;
    const phone = body.phone as string;
    const code = body.code as string;
    const deviceId = body.deviceId as string;
    const phoneHash = this.phoneHash(phone);
    const deviceHash = this.deviceHash(deviceId);

    const result = await this.options.database.transaction(async (client) => {
      const challengeResult = await client.query<{
        purpose: SmsPurpose;
        phone_lookup_hash: Buffer;
        device_lookup_hash: Buffer;
        code_hash: Buffer;
        failed_attempts: number;
        expired: boolean;
        consumed: boolean;
        invalidated: boolean;
      }>(
        `SELECT
          purpose,
          phone_lookup_hash,
          device_lookup_hash,
          code_hash,
          failed_attempts,
          expires_at <= now() AS expired,
          consumed_at IS NOT NULL AS consumed,
          invalidated_at IS NOT NULL AS invalidated
        FROM sms_challenges
        WHERE id = $1
        FOR UPDATE`,
        [challengeId],
      );
      const challenge = challengeResult.rows[0];

      if (
        challenge === undefined ||
        challenge.expired ||
        challenge.consumed ||
        challenge.invalidated ||
        !equalHashes(challenge.phone_lookup_hash, phoneHash) ||
        !equalHashes(challenge.device_lookup_hash, deviceHash)
      ) {
        throw new AuthServiceError("SMS_CODE_EXPIRED");
      }

      if (
        !equalHashes(challenge.code_hash, this.smsCodeHash(challengeId, code))
      ) {
        const attempts = challenge.failed_attempts + 1;
        await client.query(
          `UPDATE sms_challenges
           SET
             failed_attempts = $2::smallint,
             invalidated_at = CASE
               WHEN $2::smallint >= 5 THEN now()
               ELSE invalidated_at
             END
           WHERE id = $1`,
          [challengeId, attempts],
        );
        return {
          kind: "verification_error" as const,
          purpose: challenge.purpose,
          attempts,
          code:
            attempts >= 5
              ? ("VERIFICATION_ATTEMPTS_EXCEEDED" as const)
              : ("SMS_CODE_INVALID" as const),
        };
      }

      await client.query(
        "UPDATE sms_challenges SET consumed_at = now() WHERE id = $1",
        [challengeId],
      );

      if (challenge.purpose === "account_deletion") {
        return this.createDeletionVerification(client, phoneHash, deviceHash);
      }

      return this.createLoginSession(client, phone, phoneHash, deviceHash);
    });

    if (result.kind === "verification_error") {
      await recordSecurityEvent(this.options.database.pool, {
        requestId: request.requestId,
        eventType: "sms_code_verify",
        outcome: result.attempts >= 5 ? "attempts_exceeded" : "invalid",
        metadata: {
          purpose: result.purpose,
          attempts: result.attempts,
        },
      });
      throw new AuthServiceError(result.code);
    }
    if (result.kind === "deletion") {
      await recordSecurityEvent(this.options.database.pool, {
        userId: result.userId,
        requestId: request.requestId,
        eventType: "account_deletion_verify",
        outcome: "success",
      });
      return {
        purpose: "account_deletion",
        deletionToken: result.deletionToken,
        expiresIn: 600,
      };
    }

    await recordSecurityEvent(this.options.database.pool, {
      userId: result.userId,
      requestId: request.requestId,
      eventType: "login",
      outcome: "success",
      metadata: { isNewUser: result.isNewUser },
    });
    return {
      purpose: "login",
      isNewUser: result.isNewUser,
      user: {
        id: result.userId,
        phoneMasked: maskPhone(phone),
      },
      tokens: await this.tokenPair(result),
    };
  }

  async refreshTokens(body: JsonObject): Promise<JsonObject> {
    const refreshToken = body.refreshToken as string;
    const deviceHash = this.deviceHash(body.deviceId as string);
    const refreshHash = this.refreshTokenHash(refreshToken);

    const rotation = await this.options.database.transaction(async (client) => {
      const currentResult = await client.query<{
        id: string;
        user_id: string;
        device_lookup_hash: Buffer;
      }>(
        `SELECT session.id, session.user_id, session.device_lookup_hash
         FROM auth_sessions AS session
         JOIN users AS account ON account.id = session.user_id
         WHERE session.refresh_token_hash = $1
           AND session.revoked_at IS NULL
           AND session.expires_at > now()
           AND account.status = 'active'
         FOR UPDATE OF session`,
        [refreshHash],
      );
      const current = currentResult.rows[0];

      if (current === undefined) {
        await this.revokeReplayedSession(client, refreshHash);
        return { invalid: true as const };
      }
      if (!equalHashes(current.device_lookup_hash, deviceHash)) {
        throw new AuthServiceError("INVALID_REFRESH_TOKEN");
      }

      const nextRefreshToken = randomToken();
      const nextRefreshHash = this.refreshTokenHash(nextRefreshToken);
      await client.query(
        `INSERT INTO auth_refresh_token_history (token_hash, session_id)
         VALUES ($1, $2)`,
        [refreshHash, current.id],
      );
      await client.query(
        `UPDATE auth_sessions
         SET
           refresh_token_hash = $2,
           last_used_at = now(),
           expires_at = now() + interval '30 days'
         WHERE id = $1`,
        [current.id, nextRefreshHash],
      );
      return {
        invalid: false as const,
        userId: current.user_id,
        sessionId: current.id,
        refreshToken: nextRefreshToken,
      };
    });

    if (rotation.invalid) {
      await recordSecurityEvent(this.options.database.pool, {
        eventType: "refresh_token",
        outcome: "invalid_or_replayed",
      });
      throw new AuthServiceError("INVALID_REFRESH_TOKEN");
    }
    await recordSecurityEvent(this.options.database.pool, {
      userId: rotation.userId,
      eventType: "refresh_token",
      outcome: "rotated",
    });
    return this.tokenPair(rotation);
  }

  async authenticateAccessToken(
    token: string,
    options: { allowRevoked?: boolean } = {},
  ): Promise<AuthContext | null> {
    try {
      const protectedHeader = decodeProtectedHeader(token);
      const keyId =
        typeof protectedHeader.kid === "string"
          ? protectedHeader.kid
          : this.options.secrets.accessTokenKeyId;
      const verificationKey =
        keyId === this.options.secrets.accessTokenKeyId
          ? this.options.secrets.accessTokenKey
          : this.options.secrets.accessTokenPreviousKeys.get(keyId);
      if (verificationKey === undefined) return null;
      const verified = await jwtVerify(token, verificationKey, {
        issuer: this.options.issuer,
        audience: this.options.audience,
        algorithms: ["HS256"],
      });
      const userId = verified.payload.sub;
      const sessionId = verified.payload.sid;
      if (typeof userId !== "string" || typeof sessionId !== "string") {
        return null;
      }

      const result = await this.options.database.pool.query<{
        revoked_at: Date | null;
      }>(
        `SELECT session.revoked_at
         FROM auth_sessions AS session
         JOIN users AS account ON account.id = session.user_id
         WHERE session.id = $1
           AND session.user_id = $2
           AND session.expires_at > now()
           AND account.status = 'active'`,
        [sessionId, userId],
      );
      const session = result.rows[0];
      if (
        session === undefined ||
        (session.revoked_at !== null && !options.allowRevoked)
      ) {
        return null;
      }
      return { userId, sessionId };
    } catch {
      return null;
    }
  }

  async logout(context: AuthContext, body: JsonObject): Promise<void> {
    void body.deviceId;
    await this.options.database.pool.query(
      `UPDATE auth_sessions
       SET
         revoked_at = COALESCE(revoked_at, now()),
         revoke_reason = COALESCE(revoke_reason, 'logout')
       WHERE id = $1
         AND user_id = $2`,
      [context.sessionId, context.userId],
    );
    await recordSecurityEvent(this.options.database.pool, {
      userId: context.userId,
      eventType: "logout",
      outcome: "success",
    });
  }

  async deleteAccount(
    context: AuthContext,
    body: JsonObject,
  ): Promise<JsonObject> {
    const tokenHash = this.deletionTokenHash(body.deletionToken as string);
    const deviceHash = this.deviceHash(body.deviceId as string);

    const result = await this.options.database.transaction(async (client) => {
      const tokenResult = await client.query<{
        user_id: string;
        device_lookup_hash: Buffer;
        expired: boolean;
        consumed: boolean;
      }>(
        `SELECT
          user_id,
          device_lookup_hash,
          expires_at <= now() AS expired,
          consumed_at IS NOT NULL AS consumed
         FROM account_deletion_tokens
         WHERE token_hash = $1
         FOR UPDATE`,
        [tokenHash],
      );
      const token = tokenResult.rows[0];
      if (
        token === undefined ||
        token.expired ||
        token.consumed ||
        token.user_id !== context.userId ||
        !equalHashes(token.device_lookup_hash, deviceHash)
      ) {
        throw new AuthServiceError("DELETION_VERIFICATION_EXPIRED");
      }

      await client.query(
        `UPDATE account_deletion_tokens
         SET consumed_at = now()
         WHERE token_hash = $1`,
        [tokenHash],
      );
      const deletionRequestId = randomUUID();
      await client.query("SELECT begin_account_deletion($1, $2)", [
        context.userId,
        deletionRequestId,
      ]);
      const requestResult = await client.query<{ requested_at: Date }>(
        `SELECT requested_at
         FROM account_deletion_requests
         WHERE id = $1`,
        [deletionRequestId],
      );
      const deletion = requestResult.rows[0];
      if (deletion === undefined) {
        throw new Error("account deletion request was not created");
      }
      return {
        deletionRequestId,
        status: "pending",
        requestedAt: deletion.requested_at.toISOString(),
      };
    });
    await recordSecurityEvent(this.options.database.pool, {
      userId: context.userId,
      eventType: "account_deletion_request",
      outcome: "accepted",
    });
    return result;
  }

  private async createLoginSession(
    client: PoolClient,
    phone: string,
    phoneHash: Buffer,
    deviceHash: Buffer,
  ): Promise<SessionResult & { kind: "login"; isNewUser: boolean }> {
    await client.query(
      "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
      [phoneHash.toString("hex")],
    );
    const existingResult = await client.query<{
      id: string;
      status: "active" | "deletion_pending";
    }>("SELECT id, status FROM users WHERE phone_lookup_hash = $1", [
      phoneHash,
    ]);
    const existing = existingResult.rows[0];
    if (existing?.status === "deletion_pending") {
      throw new AuthServiceError("SMS_CODE_EXPIRED");
    }

    const isNewUser = existing === undefined;
    const userId = existing?.id ?? randomUUID();
    if (isNewUser) {
      await client.query(
        `INSERT INTO users (
          id,
          phone_lookup_hash,
          phone_ciphertext,
          last_login_at
        )
        VALUES ($1, $2, $3, now())`,
        [
          userId,
          phoneHash,
          encryptPhone(phone, this.options.secrets.phoneEncryptionKey),
        ],
      );
    } else {
      await client.query(
        "UPDATE users SET last_login_at = now() WHERE id = $1",
        [userId],
      );
    }

    const sessionId = randomUUID();
    const refreshToken = randomToken();
    await client.query(
      `UPDATE auth_sessions
       SET
         revoked_at = COALESCE(revoked_at, now()),
         revoke_reason = COALESCE(revoke_reason, 'relogin')
       WHERE user_id = $1
         AND device_lookup_hash = $2
         AND revoked_at IS NULL`,
      [userId, deviceHash],
    );
    await client.query(
      `INSERT INTO auth_sessions (
        id,
        user_id,
        device_lookup_hash,
        refresh_token_hash,
        expires_at
      )
      VALUES ($1, $2, $3, $4, now() + interval '30 days')`,
      [sessionId, userId, deviceHash, this.refreshTokenHash(refreshToken)],
    );
    return {
      kind: "login",
      isNewUser,
      userId,
      sessionId,
      refreshToken,
    };
  }

  private async createDeletionVerification(
    client: PoolClient,
    phoneHash: Buffer,
    deviceHash: Buffer,
  ): Promise<{
    kind: "deletion";
    deletionToken: string;
    userId: string;
  }> {
    const userResult = await client.query<{
      id: string;
      status: "active" | "deletion_pending";
    }>("SELECT id, status FROM users WHERE phone_lookup_hash = $1", [
      phoneHash,
    ]);
    const user = userResult.rows[0];
    if (user === undefined || user.status !== "active") {
      throw new AuthServiceError("SMS_CODE_EXPIRED");
    }

    const deletionToken = randomToken();
    await client.query(
      `INSERT INTO account_deletion_tokens (
        token_hash,
        user_id,
        device_lookup_hash,
        expires_at
      )
      VALUES ($1, $2, $3, now() + interval '10 minutes')`,
      [this.deletionTokenHash(deletionToken), user.id, deviceHash],
    );
    return {
      kind: "deletion",
      deletionToken,
      userId: user.id,
    };
  }

  private async revokeReplayedSession(
    client: PoolClient,
    refreshHash: Buffer,
  ): Promise<void> {
    await client.query(
      `UPDATE auth_sessions AS session
       SET
         revoked_at = COALESCE(session.revoked_at, now()),
         revoke_reason = COALESCE(session.revoke_reason, 'refresh_reuse')
       FROM auth_refresh_token_history AS history
       WHERE history.token_hash = $1
         AND session.id = history.session_id`,
      [refreshHash],
    );
  }

  private async tokenPair(session: SessionResult): Promise<JsonObject> {
    const accessToken = await new SignJWT({ sid: session.sessionId })
      .setProtectedHeader({
        alg: "HS256",
        typ: "JWT",
        kid: this.options.secrets.accessTokenKeyId,
      })
      .setSubject(session.userId)
      .setIssuer(this.options.issuer)
      .setAudience(this.options.audience)
      .setIssuedAt()
      .setExpirationTime(`${accessTokenExpiresIn}s`)
      .sign(this.options.secrets.accessTokenKey);
    return {
      accessToken,
      accessTokenExpiresIn,
      refreshToken: session.refreshToken,
      refreshTokenExpiresIn,
    };
  }

  private phoneHash(phone: string): Buffer {
    return keyedHash(phone, this.options.secrets.phoneLookupPepper);
  }

  private deviceHash(deviceId: string): Buffer {
    return keyedHash(deviceId, this.options.secrets.devicePepper);
  }

  private refreshTokenHash(token: string): Buffer {
    return keyedHash(token, this.options.secrets.refreshTokenPepper);
  }

  private deletionTokenHash(token: string): Buffer {
    return keyedHash(token, this.options.secrets.deletionTokenPepper);
  }

  private smsCodeHash(challengeId: string, code: string): Buffer {
    return keyedHash(
      `${challengeId}:${code}`,
      this.options.secrets.smsCodePepper,
    );
  }

  private clientAddress(request: Request): string {
    return request.ip || request.socket.remoteAddress || "unknown";
  }
}

function maskPhone(phone: string): string {
  const national = phone.slice(3);
  return `${national.slice(0, 3)}****${national.slice(-4)}`;
}

export type { AuthSecrets, PostgresAuthOptions };
