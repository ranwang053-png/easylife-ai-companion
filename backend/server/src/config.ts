export interface AppConfig {
  host: string;
  port: number;
  nodeEnv: string;
  logLevel: "silent" | "info";
  allowedOrigins: readonly string[];
  enableTestTriggers: boolean;
  fixedAccessTokens: readonly string[];
  ai?: AiConfig;
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

export type AiMode = "fixed" | "gateway";

export type AiProviderId =
  | "fixed"
  | "openai"
  | "anthropic"
  | "deepseek"
  | "doubao"
  | "birefnet";

export type AiCapability =
  | "companion"
  | "emotion"
  | "emotionJournal"
  | "memory"
  | "petProfile"
  | "dailyFortune"
  | "petAvatar"
  | "dietText"
  | "dietVision"
  | "dietSearch"
  | "foodSegmentation";

export interface AiCapabilityConfig {
  provider: AiProviderId;
  model: string;
  imageEnhancement?: "none" | "light";
}

export interface AiProviderConfig {
  apiKey?: string;
  baseUrl?: URL;
}

export interface AiConfig {
  mode: AiMode;
  capabilities: Readonly<Record<AiCapability, AiCapabilityConfig>>;
  providers: Readonly<Record<AiProviderId, AiProviderConfig>>;
  petAvatarProvider?: AiProviderConfig;
  petAvatarStyleReferenceDir?: string;
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
    allowedOrigins: originList(environment.ALLOWED_ORIGINS),
    enableTestTriggers: environment.ENABLE_TEST_TRIGGERS === "true",
    fixedAccessTokens: [
      environment.FIXED_ACCESS_TOKEN ??
        "example-access-token-with-at-least-twenty-characters",
      environment.FIXED_ROTATED_ACCESS_TOKEN ??
        "rotated-access-token-with-at-least-twenty-characters",
    ],
    ai: loadAiConfig(environment),
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

function loadAiConfig(environment: NodeJS.ProcessEnv): AiConfig {
  const mode = aiMode(environment.AI_PROVIDER);
  return {
    mode,
    capabilities: {
      companion: capability(environment, {
        providerName: "AI_COMPANION_PROVIDER",
        modelName: "AI_COMPANION_MODEL",
        fallbackProvider: aiProvider(
          environment.AI_EMOTION_PROVIDER,
          "AI_EMOTION_PROVIDER",
          "openai",
        ),
        fallbackModel: nonEmpty(environment.AI_EMOTION_MODEL, "gpt-5.5"),
      }),
      emotion: capability(environment, {
        providerName: "AI_EMOTION_PROVIDER",
        modelName: "AI_EMOTION_MODEL",
        fallbackProvider: "anthropic",
        fallbackModel: "claude-sonnet-4.6",
      }),
      emotionJournal: capability(environment, {
        providerName: "AI_EMOTION_JOURNAL_PROVIDER",
        modelName: "AI_EMOTION_JOURNAL_MODEL",
        fallbackProvider: aiProvider(
          environment.AI_MEMORY_PROVIDER ?? environment.AI_EMOTION_PROVIDER,
          environment.AI_MEMORY_PROVIDER === undefined
            ? "AI_EMOTION_PROVIDER"
            : "AI_MEMORY_PROVIDER",
          "openai",
        ),
        fallbackModel: nonEmpty(
          environment.AI_MEMORY_MODEL ?? environment.AI_EMOTION_MODEL,
          "gpt-5.5",
        ),
      }),
      memory: capability(environment, {
        providerName: "AI_MEMORY_PROVIDER",
        modelName: "AI_MEMORY_MODEL",
        fallbackProvider: "anthropic",
        fallbackModel: "claude-sonnet-4.6",
      }),
      petProfile: capability(environment, {
        providerName: "AI_PET_PROFILE_PROVIDER",
        modelName: "AI_PET_PROFILE_MODEL",
        fallbackProvider: "anthropic",
        fallbackModel: "claude-sonnet-4.6",
      }),
      dailyFortune: capability(environment, {
        providerName: "AI_DAILY_FORTUNE_PROVIDER",
        modelName: "AI_DAILY_FORTUNE_MODEL",
        fallbackProvider: "openai",
        fallbackModel: "gpt-5.5",
      }),
      petAvatar: capability(environment, {
        providerName: "AI_PET_AVATAR_PROVIDER",
        modelName: "AI_PET_AVATAR_MODEL",
        fallbackProvider: "openai",
        fallbackModel: "gpt-image-1",
      }),
      dietText: capability(environment, {
        providerName: "AI_DIET_TEXT_PROVIDER",
        modelName: "AI_DIET_TEXT_MODEL",
        fallbackProvider: "doubao",
        fallbackModel: "doubao-seed-1-6",
      }),
      dietVision: capability(environment, {
        providerName: "AI_DIET_VISION_PROVIDER",
        modelName: "AI_DIET_VISION_MODEL",
        fallbackProvider: "doubao",
        fallbackModel: "doubao-seed-1-6",
      }),
      dietSearch: capability(environment, {
        providerName: "AI_DIET_SEARCH_PROVIDER",
        modelName: "AI_DIET_SEARCH_MODEL",
        fallbackProvider: "doubao",
        fallbackModel: "doubao-seed-1-6",
      }),
      foodSegmentation: {
        ...capability(environment, {
          providerName: "AI_FOOD_SEGMENTATION_PROVIDER",
          modelName: "AI_FOOD_SEGMENTATION_MODEL",
          fallbackProvider: "birefnet",
          fallbackModel: "BiRefNet",
        }),
        imageEnhancement:
          environment.AI_FOOD_IMAGE_ENHANCEMENT === "light" ? "light" : "none",
      },
    },
    providers: {
      fixed: {},
      openai: providerConfig(environment, "OPENAI"),
      anthropic: providerConfig(environment, "ANTHROPIC"),
      deepseek: providerConfig(environment, "DEEPSEEK"),
      doubao: providerConfig(environment, "DOUBAO"),
      birefnet: providerConfig(environment, "BIREFNET"),
    },
    petAvatarProvider: providerConfigWithFallback(
      environment,
      "AI_PET_AVATAR",
      providerConfig(environment, "OPENAI"),
    ),
    ...(environment.AI_PET_AVATAR_STYLE_REFERENCE_DIR === undefined ||
    environment.AI_PET_AVATAR_STYLE_REFERENCE_DIR.length === 0
      ? {}
      : {
          petAvatarStyleReferenceDir:
            environment.AI_PET_AVATAR_STYLE_REFERENCE_DIR,
        }),
  };
}

function aiMode(raw: string | undefined): AiMode {
  if (raw === undefined || raw.length === 0 || raw === "fixed") return "fixed";
  if (raw === "gateway") return "gateway";
  throw new Error("AI_PROVIDER must be fixed or gateway");
}

function capability(
  environment: NodeJS.ProcessEnv,
  options: {
    providerName: string;
    modelName: string;
    fallbackProvider: AiProviderId;
    fallbackModel: string;
  },
): AiCapabilityConfig {
  return {
    provider: aiProvider(
      environment[options.providerName],
      options.providerName,
      options.fallbackProvider,
    ),
    model: nonEmpty(environment[options.modelName], options.fallbackModel),
  };
}

function aiProvider(
  raw: string | undefined,
  name: string,
  fallback: AiProviderId,
): AiProviderId {
  const value = nonEmpty(raw, fallback);
  if (
    value === "fixed" ||
    value === "openai" ||
    value === "anthropic" ||
    value === "deepseek" ||
    value === "doubao" ||
    value === "birefnet"
  ) {
    return value;
  }
  throw new Error(
    `${name} must be one of fixed, openai, anthropic, deepseek, doubao, birefnet`,
  );
}

function providerConfig(
  environment: NodeJS.ProcessEnv,
  prefix: string,
): AiProviderConfig {
  const apiKey = optionalSecret(environment[`${prefix}_API_KEY`]);
  const baseUrl = optionalUrl(
    environment[`${prefix}_BASE_URL`],
    `${prefix}_BASE_URL`,
  );
  return {
    ...(apiKey === undefined ? {} : { apiKey }),
    ...(baseUrl === undefined ? {} : { baseUrl }),
  };
}

function providerConfigWithFallback(
  environment: NodeJS.ProcessEnv,
  prefix: string,
  fallback: AiProviderConfig,
): AiProviderConfig {
  const override = providerConfig(environment, prefix);
  const apiKey = override.apiKey ?? fallback.apiKey;
  const baseUrl = override.baseUrl ?? fallback.baseUrl;
  return {
    ...(apiKey === undefined ? {} : { apiKey }),
    ...(baseUrl === undefined ? {} : { baseUrl }),
  };
}

function required(environment: NodeJS.ProcessEnv, name: string): string {
  const value = environment[name];
  if (value === undefined || value.length === 0) {
    throw new Error(`${name} must be configured when DATABASE_URL is set`);
  }
  return value;
}

function originList(raw: string | undefined): readonly string[] {
  if (raw === undefined || raw.trim().length === 0) {
    return [];
  }

  return raw
    .split(",")
    .map((value) => value.trim())
    .filter((value) => value.length > 0)
    .map((value) => {
      const normalized = value.replace(/\/+$/, "");
      const parsed = new URL(normalized);
      if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
        throw new Error("ALLOWED_ORIGINS entries must use HTTP or HTTPS");
      }
      if (parsed.origin !== normalized) {
        throw new Error("ALLOWED_ORIGINS entries must be origins without paths");
      }
      return parsed.origin;
    });
}

function optionalSecret(raw: string | undefined): string | undefined {
  if (raw === undefined || raw.length === 0) return undefined;
  return raw;
}

function nonEmpty<T extends string>(
  raw: string | undefined,
  fallback: T,
): T | string {
  if (raw === undefined || raw.length === 0) return fallback;
  return raw;
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
