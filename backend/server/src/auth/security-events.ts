interface Queryable {
  query(text: string, values?: readonly unknown[]): Promise<unknown>;
}

export async function recordSecurityEvent(
  queryable: Queryable,
  event: {
    userId?: string;
    requestId?: string;
    eventType: string;
    outcome: string;
    metadata?: Record<string, string | number | boolean>;
  },
): Promise<void> {
  try {
    await queryable.query(
      `INSERT INTO security_events (
        user_id,
        request_id,
        event_type,
        outcome,
        metadata
      )
      VALUES ($1, $2, $3, $4, $5::jsonb)`,
      [
        event.userId ?? null,
        event.requestId ?? null,
        event.eventType,
        event.outcome,
        JSON.stringify(event.metadata ?? {}),
      ],
    );
  } catch {
    // Authentication must not fail only because security audit storage is
    // temporarily unavailable. Operational monitoring should alert on this.
  }
}
