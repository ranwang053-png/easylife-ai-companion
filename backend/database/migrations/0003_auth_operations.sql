BEGIN;

ALTER TABLE account_deletion_requests
  ADD COLUMN attempt_count integer NOT NULL DEFAULT 0,
  ADD COLUMN next_attempt_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN lease_expires_at timestamptz,
  ADD COLUMN worker_id text;

ALTER TABLE sms_challenges
  ADD COLUMN provider_message_id text,
  ADD COLUMN provider_sent_at timestamptz;

ALTER TABLE sms_challenges
  ADD CONSTRAINT sms_provider_message_id_length
    CHECK (
      provider_message_id IS NULL
      OR char_length(provider_message_id) BETWEEN 1 AND 200
    ),
  ADD CONSTRAINT sms_provider_delivery_consistent
    CHECK (
      (provider_sent_at IS NULL AND provider_message_id IS NULL)
      OR provider_sent_at IS NOT NULL
    );

ALTER TABLE account_deletion_requests
  ADD CONSTRAINT deletion_request_attempt_count_nonnegative
    CHECK (attempt_count >= 0),
  ADD CONSTRAINT deletion_request_worker_id_length
    CHECK (worker_id IS NULL OR char_length(worker_id) BETWEEN 1 AND 100);

ALTER TABLE account_deletion_requests
  DROP CONSTRAINT deletion_request_state_consistent;

ALTER TABLE account_deletion_requests
  ADD CONSTRAINT deletion_request_state_consistent
    CHECK (
      (status = 'pending'
        AND processing_started_at IS NULL
        AND completed_at IS NULL
        AND failure_code IS NULL
        AND lease_expires_at IS NULL
        AND worker_id IS NULL)
      OR
      (status = 'processing'
        AND processing_started_at IS NOT NULL
        AND completed_at IS NULL
        AND failure_code IS NULL
        AND lease_expires_at IS NOT NULL
        AND worker_id IS NOT NULL)
      OR
      (status = 'completed'
        AND processing_started_at IS NOT NULL
        AND completed_at IS NOT NULL
        AND failure_code IS NULL
        AND lease_expires_at IS NULL
        AND worker_id IS NULL)
      OR
      (status = 'failed'
        AND processing_started_at IS NOT NULL
        AND completed_at IS NULL
        AND failure_code IS NOT NULL
        AND lease_expires_at IS NULL
        AND worker_id IS NULL)
    );

CREATE INDEX account_deletion_requests_ready_idx
  ON account_deletion_requests (next_attempt_at, requested_at)
  WHERE status IN ('pending', 'failed');

CREATE INDEX account_deletion_requests_expired_lease_idx
  ON account_deletion_requests (lease_expires_at)
  WHERE status = 'processing';

CREATE OR REPLACE FUNCTION purge_deleted_account(
  deletion_request_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  target_user_id uuid;
  target_phone_lookup_hash bytea;
BEGIN
  UPDATE account_deletion_requests
  SET
    status = 'processing',
    attempt_count = attempt_count + 1,
    processing_started_at = now(),
    completed_at = NULL,
    failure_code = NULL,
    lease_expires_at = now() + interval '5 minutes',
    worker_id = 'manual-purge'
  WHERE id = deletion_request_id
    AND status IN ('pending', 'failed');

  SELECT deletion.user_id, account.phone_lookup_hash
  INTO target_user_id, target_phone_lookup_hash
  FROM account_deletion_requests AS deletion
  JOIN users AS account ON account.id = deletion.user_id
  WHERE deletion.id = deletion_request_id
    AND deletion.status = 'processing'
  FOR UPDATE;

  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'processing deletion request not found';
  END IF;

  DELETE FROM sms_challenges
  WHERE phone_lookup_hash = target_phone_lookup_hash;

  DELETE FROM users
  WHERE id = target_user_id
    AND status = 'deletion_pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'account is not pending deletion';
  END IF;

  UPDATE account_deletion_requests
  SET
    status = 'completed',
    completed_at = now(),
    lease_expires_at = NULL,
    worker_id = NULL,
    failure_code = NULL
  WHERE id = deletion_request_id;
END;
$$;

REVOKE ALL ON FUNCTION purge_deleted_account(uuid) FROM PUBLIC;

COMMIT;
