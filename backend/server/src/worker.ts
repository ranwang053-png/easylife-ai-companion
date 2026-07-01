import "./env.js";

import { randomUUID } from "node:crypto";

import { loadConfig, type AppConfig } from "./config.js";
import { Database } from "./database.js";
import {
  AccountDeletionWorker,
  DatabaseOnlyAccountDeletionCleaner,
  WebhookAccountDeletionCleaner,
} from "./workers/account-deletion-worker.js";
import { AuthMaintenanceWorker } from "./workers/auth-maintenance-worker.js";

const config = loadConfig();
const authConfig = requireAuthConfig(config);

const database = new Database(authConfig.databaseUrl);
await database.assertAuthSchema();
await database.assertOperationsSchema();

const cleaner =
  authConfig.accountDeletionCleanupUrl === undefined
    ? new DatabaseOnlyAccountDeletionCleaner()
    : new WebhookAccountDeletionCleaner(
        authConfig.accountDeletionCleanupUrl,
        authConfig.accountDeletionCleanupToken ?? "",
      );
const deletionWorker = new AccountDeletionWorker(database, cleaner, {
  workerId: `${process.pid}-${randomUUID()}`,
  leaseSeconds: authConfig.accountDeletionLeaseSeconds,
  maxBackoffSeconds: authConfig.accountDeletionMaxBackoffSeconds,
});
const maintenanceWorker = new AuthMaintenanceWorker(database);

let stopping = false;
let lastMaintenanceAt = 0;

if (config.logLevel !== "silent") {
  console.info(
    JSON.stringify({
      event: "background_worker_started",
      worker: "auth_operations",
    }),
  );
}

async function tick(): Promise<void> {
  const now = Date.now();
  if (
    now - lastMaintenanceAt >=
    authConfig.authMaintenanceIntervalSeconds * 1000
  ) {
    await maintenanceWorker.runOnce();
    lastMaintenanceAt = now;
  }

  const processed = await deletionWorker.runOnce();
  if (!processed) {
    await delay(authConfig.accountDeletionPollSeconds * 1000);
  }
}

async function run(): Promise<void> {
  while (!stopping) {
    try {
      await tick();
    } catch {
      if (config.logLevel !== "silent") {
        console.error(
          JSON.stringify({
            event: "background_worker_tick_failed",
            worker: "auth_operations",
          }),
        );
      }
      await delay(authConfig.accountDeletionPollSeconds * 1000);
    }
  }
  await database.close();
}

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function stop(): void {
  stopping = true;
  if (config.logLevel !== "silent") {
    console.info(
      JSON.stringify({
        event: "background_worker_stopping",
        worker: "auth_operations",
      }),
    );
  }
}

function requireAuthConfig(value: AppConfig): NonNullable<AppConfig["auth"]> {
  if (value.auth === undefined) {
    throw new Error("The background worker requires DATABASE_URL");
  }
  return value.auth;
}

process.on("SIGINT", stop);
process.on("SIGTERM", stop);

await run();
