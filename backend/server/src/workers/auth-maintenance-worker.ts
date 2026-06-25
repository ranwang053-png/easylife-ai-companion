import type { Database } from "../database.js";

export class AuthMaintenanceWorker {
  constructor(private readonly database: Database) {}

  async runOnce(): Promise<void> {
    await this.database.transaction(async (client) => {
      await client.query(
        `DELETE FROM sms_challenges
         WHERE created_at < now() - interval '1 day'
           AND (
             expires_at <= now()
             OR consumed_at IS NOT NULL
             OR invalidated_at IS NOT NULL
           )`,
      );
      await client.query(
        `DELETE FROM account_deletion_tokens
         WHERE expires_at < now() - interval '1 day'
           OR consumed_at < now() - interval '1 day'`,
      );
      await client.query(
        `DELETE FROM auth_sessions
         WHERE expires_at < now() - interval '30 days'
           OR revoked_at < now() - interval '30 days'`,
      );
      await client.query(
        `DELETE FROM security_events
         WHERE created_at < now() - interval '180 days'`,
      );
    });
  }
}
