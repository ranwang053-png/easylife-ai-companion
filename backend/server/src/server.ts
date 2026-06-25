import { createApp } from "./app.js";
import { PostgresAuthService } from "./auth/postgres-auth-service.js";
import { WebhookSmsProvider } from "./auth/sms-provider.js";
import { loadConfig } from "./config.js";
import { Database } from "./database.js";

const config = loadConfig();
const database =
  config.auth === undefined ? undefined : new Database(config.auth.databaseUrl);
const authService =
  config.auth === undefined || database === undefined
    ? undefined
    : new PostgresAuthService({
        database,
        smsProvider: new WebhookSmsProvider(
          config.auth.smsProviderUrl,
          config.auth.smsProviderToken,
          config.auth.smsProviderMaxAttempts,
        ),
        secrets: {
          phoneLookupPepper: config.auth.phoneLookupPepper,
          phoneEncryptionKey: config.auth.phoneEncryptionKey,
          smsCodePepper: config.auth.smsCodePepper,
          devicePepper: config.auth.devicePepper,
          ipPepper: config.auth.ipPepper,
          refreshTokenPepper: config.auth.refreshTokenPepper,
          deletionTokenPepper: config.auth.deletionTokenPepper,
          accessTokenKey: config.auth.accessTokenKey,
          accessTokenKeyId: config.auth.accessTokenKeyId,
          accessTokenPreviousKeys: config.auth.accessTokenPreviousKeys,
        },
        issuer: config.auth.issuer,
        audience: config.auth.audience,
      });
await database?.assertAuthSchema();
await database?.assertOperationsSchema();
const app = createApp({
  config,
  ...(authService === undefined ? {} : { authService }),
});

const server = app.listen(config.port, config.host, () => {
  if (config.logLevel !== "silent") {
    console.info(
      JSON.stringify({
        event: "server_started",
        host: config.host,
        port: config.port,
      }),
    );
  }
});

async function shutdown(signal: string): Promise<void> {
  if (config.logLevel !== "silent") {
    console.info(JSON.stringify({ event: "server_stopping", signal }));
  }

  server.close(async (error) => {
    if (error !== undefined) {
      process.exitCode = 1;
    }
    await database?.close();
  });
}

process.on("SIGINT", () => void shutdown("SIGINT"));
process.on("SIGTERM", () => void shutdown("SIGTERM"));
