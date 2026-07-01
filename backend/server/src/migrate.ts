import "./env.js";

import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import { readdir, readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { Database } from "./database.js";

const databaseUrl = process.env.DATABASE_URL;
if (databaseUrl === undefined || databaseUrl.length === 0) {
  throw new Error("DATABASE_URL is required");
}

const database = new Database(databaseUrl);
const migrationDirectoryCandidates = [
  fileURLToPath(new URL("../../database/migrations/", import.meta.url)),
  fileURLToPath(new URL("../../../database/migrations/", import.meta.url)),
  resolve(process.cwd(), "backend/database/migrations"),
  resolve(process.cwd(), "../database/migrations"),
];
const migrationDirectory = migrationDirectoryCandidates.find(existsSync);
if (migrationDirectory === undefined) {
  throw new Error("Unable to locate backend/database/migrations");
}
const client = await database.pool.connect();

try {
  await client.query(
    `CREATE TABLE IF NOT EXISTS schema_migrations (
      version text PRIMARY KEY,
      checksum text,
      applied_at timestamptz NOT NULL DEFAULT now()
    )`,
  );
  await client.query(
    "SELECT pg_advisory_lock(hashtext('easylife_schema_migrations'))",
  );

  const files = (await readdir(migrationDirectory))
    .filter((file) => /^\d+_.+\.sql$/.test(file))
    .sort();

  for (const file of files) {
    const version = file.slice(0, file.indexOf("_"));
    const raw = await readFile(resolve(migrationDirectory, file), "utf8");
    const checksum = createHash("sha256").update(raw).digest("hex");
    const applied = await client.query<{
      checksum: string | null;
    }>("SELECT checksum FROM schema_migrations WHERE version = $1", [version]);
    const existing = applied.rows[0];

    if (existing !== undefined) {
      if (existing.checksum === null) {
        await client.query(
          `UPDATE schema_migrations
           SET checksum = $2
           WHERE version = $1`,
          [version, checksum],
        );
      } else if (existing.checksum !== checksum) {
        throw new Error(
          `Migration ${version} checksum does not match the applied version`,
        );
      }
      continue;
    }

    try {
      await client.query("BEGIN");
      await client.query(stripTransactionWrapper(raw));
      await client.query(
        `INSERT INTO schema_migrations (version, checksum)
         VALUES ($1, $2)`,
        [version, checksum],
      );
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    }
    console.info(JSON.stringify({ event: "migration_applied", version }));
  }
} finally {
  await client
    .query("SELECT pg_advisory_unlock(hashtext('easylife_schema_migrations'))")
    .catch(() => {});
  client.release();
  await database.close();
}

function stripTransactionWrapper(sql: string): string {
  return sql.replace(/^\s*BEGIN\s*;\s*/i, "").replace(/\s*COMMIT\s*;\s*$/i, "");
}
