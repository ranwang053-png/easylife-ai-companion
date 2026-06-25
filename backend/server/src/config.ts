export interface AppConfig {
  host: string;
  port: number;
  nodeEnv: string;
  logLevel: "silent" | "info";
  enableTestTriggers: boolean;
  fixedAccessTokens: readonly string[];
  auth?: {
    databaseUrl: string;
    smsProviderUrl: URL;
    smsProviderToken: string;
    phoneLookupPepper: Buffer;
    phoneEncryptionKey: Buffer;
    smsCodePepper: Buffer;
    devicePepper: Buffer;
    ipPepper: Buffer;
    refreshTokenPepper: Buffer;
    deletionTokenPepper: Buffer;
    accessTokenKey: Buffer;
    accessTokenKeyId: string;
    accessTokenPreviousKeys: ReadonlyMap<string, Buffer>;
    issuer: string;
    audience: string;
    trustProxy: boolean;
    smsProviderMaxAttempts: number;
    accountDeletionCleanupUrl?: URL;
    accountDeletionCleanupToken?: string;
    accountDeletionLeaseSeconds: number;
    accountDeletionPollSeconds: number;
    accountDeletionMaxBackoffSeconds: number;
    authMaintenanceIntervalSeconds: number;
  };
}

export function loadConfig(
  environment: NodeJS.ProcessEnv = process.env,
): AppConfig {
  const port = Number.parseInt(environment.PORT ?? "3000", 10);
  const nodeEnv = environment.NODE_ENV ?? "development";
  const databaseUrl =
    environment.DATABASE_URL === undefined ||
    environment.DATABASE_URL.length === 0
      ? undefined
      : environment.DATABASE_URL;
  const allowsFixedAuth = nodeEnv === "development" || nodeEnv === "test";

  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error("PORT must be an integer between 1 and 65535");
  }

  if (!allowsFixedAuth && databaseUrl === undefined) {
    throw new Error(
      "DATABASE_URL and real authentication secrets must be configured outside development and test",
    );
  }
  if (!allowsFixedAuth && environment.ENABLE_TEST_TRIGGERS === "true") {
    throw new Error(
      "ENABLE_TEST_TRIGGERS cannot be enabled outside development and test",
    );
  }

  const base: AppConfig = {
    host: environment.HOST ?? "127.0.0.1",
    port,
    nodeEnv,
    logLevel: environment.LOG_LEVEL === "silent" ? "silent" : "info",
    enableTestTriggers: environment.ENABLE_TEST_TRIGGERS === "true",
    fixedAccessTokens: [
      environment.FIXED_ACCESS_TOKEN ??
        "example-access-token-with-at-least-twenty-characters",
      environment.FIXED_ROTATED_ACCESS_TOKEN ??
        "rotated-access-token-with-at-least-twenty-characters",
    ],
  };

  if (databaseUrl === undefined) {
    return base;
  }

  const smsProviderUrl = required(environment, "SMS_PROVIDER_URL");
  const parsedSmsProviderUrl = new URL(smsProviderUrl);
  if (!allowsFixedAuth && parsedSmsProviderUrl.protocol !== "https:") {
    throw new Error(
      "SMS_PROVIDER_URL must use HTTPS outside development and test",
    );
  }
  const secrets = {
    phoneLookupPepper: secret(environment, "PHONE_LOOKUP_PEPPER"),
    phoneEncryptionKey: secret(environment, "PHONE_ENCRYPTION_KEY"),
    smsCodePepper: secret(environment, "SMS_CODE_PEPPER"),
    devicePepper: secret(environment, "DEVICE_PEPPER"),
    ipPepper: secret(environment, "IP_PEPPER"),
    refreshTokenPepper: secret(environment, "REFRESH_TOKEN_PEPPER"),
    deletionTokenPepper: secret(environment, "DELETION_TOKEN_PEPPER"),
    accessTokenKey: secret(environment, "ACCESS_TOKEN_KEY"),
  };
  if (
    new Set(Object.values(secrets).map((value) => value.toString("hex")))
      .size !== Object.keys(secrets).length
  ) {
    throw new Error("Authentication secrets must be independently generated");
  }
  const accessTokenKeyId = environment.ACCESS_TOKEN_KEY_ID ?? "current";
  if (!/^[A-Za-z0-9._-]{1,50}$/.test(accessTokenKeyId)) {
    throw new Error("ACCESS_TOKEN_KEY_ID has an invalid format");
  }
  const accessTokenPreviousKeys = previousAccessTokenKeys(
    environment.ACCESS_TOKEN_PREVIOUS_KEYS,
  );
  if (accessTokenPreviousKeys.has(accessTokenKeyId)) {
    throw new Error(
      "ACCESS_TOKEN_PREVIOUS_KEYS cannot contain ACCESS_TOKEN_KEY_ID",
    );
  }
  const cleanupUrl = optionalUrl(
    environment.ACCOUNT_DELETION_CLEANUP_URL,
    "ACCOUNT_DELETION_CLEANUP_URL",
  );
  const allowDatabaseOnly =
    environment.ACCOUNT_DELETION_ALLOW_DATABASE_ONLY === "true";
  if (!allowsFixedAuth && cleanupUrl === undefined && !allowDatabaseOnly) {
    throw new Error(
      "Configure ACCOUNT_DELETION_CLEANUP_URL or explicitly allow database-only account deletion",
    );
  }
  if (
    cleanupUrl !== undefined &&
    !allowsFixedAuth &&
    cleanupUrl.protocol !== "https:"
  ) {
    throw new Error(
      "ACCOUNT_DELETION_CLEANUP_URL must use HTTPS outside development and test",
    );
  }
  const cleanupConfig =
    cleanupUrl === undefined
      ? {}
      : {
          accountDeletionCleanupUrl: cleanupUrl,
          accountDeletionCleanupToken: required(
            environment,
            "ACCOUNT_DELETION_CLEANUP_TOKEN",
          ),
        };

  return {
    ...base,
    auth: {
      databaseUrl,
      smsProviderUrl: parsedSmsProviderUrl,
      smsProviderToken: required(environment, "SMS_PROVIDER_TOKEN"),
      ...secrets,
      accessTokenKeyId,
      accessTokenPreviousKeys,
      issuer: environment.ACCESS_TOKEN_ISSUER ?? "easylife-api",
      audience: environment.ACCESS_TOKEN_AUDIENCE ?? "easylife-ios",
      trustProxy: environment.TRUST_PROXY === "true",
      smsProviderMaxAttempts: integer(
        environment,
        "SMS_PROVIDER_MAX_ATTEMPTS",
        3,
        1,
        5,
      ),
      ...cleanupConfig,
      accountDeletionLeaseSeconds: integer(
        environment,
        "ACCOUNT_DELETION_LEASE_SECONDS",
        300,
        30,
        3600,
      ),
      accountDeletionPollSeconds: integer(
        environment,
        "ACCOUNT_DELETION_POLL_SECONDS",
        5,
        1,
        300,
      ),
      accountDeletionMaxBackoffSeconds: integer(
        environment,
        "ACCOUNT_DELETION_MAX_BACKOFF_SECONDS",
        3600,
        60,
        86400,
      ),
      authMaintenanceIntervalSeconds: integer(
        environment,
        "AUTH_MAINTENANCE_INTERVAL_SECONDS",
        3600,
        60,
        86400,
      ),
    },
  };
}

function required(environment: NodeJS.ProcessEnv, name: string): string {
  const value = environment[name];
  if (value === undefined || value.length === 0) {
    throw new Error(`${name} must be configured when DATABASE_URL is set`);
  }
  return value;
}

function secret(environment: NodeJS.ProcessEnv, name: string): Buffer {
  const encoded = required(environment, name);
  const value = Buffer.from(encoded, "base64");
  if (value.length !== 32) {
    throw new Error(`${name} must be a base64-encoded 32-byte secret`);
  }
  return value;
}

function previousAccessTokenKeys(
  raw: string | undefined,
): ReadonlyMap<string, Buffer> {
  if (raw === undefined || raw.length === 0) return new Map();
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error(
      "ACCESS_TOKEN_PREVIOUS_KEYS must be a JSON object of key ids to base64 secrets",
    );
  }
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("ACCESS_TOKEN_PREVIOUS_KEYS must be a JSON object");
  }
  const result = new Map<string, Buffer>();
  for (const [keyId, encoded] of Object.entries(parsed)) {
    if (!/^[A-Za-z0-9._-]{1,50}$/.test(keyId) || typeof encoded !== "string") {
      throw new Error("ACCESS_TOKEN_PREVIOUS_KEYS contains an invalid entry");
    }
    const value = Buffer.from(encoded, "base64");
    if (value.length !== 32) {
      throw new Error(
        "ACCESS_TOKEN_PREVIOUS_KEYS values must decode to 32 bytes",
      );
    }
    result.set(keyId, value);
  }
  return result;
}

function optionalUrl(raw: string | undefined, name: string): URL | undefined {
  if (raw === undefined || raw.length === 0) return undefined;
  try {
    return new URL(raw);
  } catch {
    throw new Error(`${name} must be a valid URL`);
  }
}

function integer(
  environment: NodeJS.ProcessEnv,
  name: string,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  const value = Number.parseInt(environment[name] ?? String(fallback), 10);
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new Error(
      `${name} must be an integer between ${minimum} and ${maximum}`,
    );
  }
  return value;
}
