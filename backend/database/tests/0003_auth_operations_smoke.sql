\set ON_ERROR_STOP on

BEGIN;

INSERT INTO users (
  id,
  phone_lookup_hash,
  phone_ciphertext
)
VALUES (
  'a1000000-0000-0000-0000-000000000001',
  decode(repeat('a1', 32), 'hex'),
  convert_to('encrypted-phone-worker', 'UTF8')
);

SELECT begin_account_deletion(
  'a1000000-0000-0000-0000-000000000001',
  'a2000000-0000-0000-0000-000000000001'
);

UPDATE account_deletion_requests
SET
  status = 'processing',
  attempt_count = attempt_count + 1,
  processing_started_at = now(),
  lease_expires_at = now() + interval '5 minutes',
  worker_id = 'smoke-worker'
WHERE id = 'a2000000-0000-0000-0000-000000000001';

SELECT purge_deleted_account(
  'a2000000-0000-0000-0000-000000000001'
);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM users
    WHERE id = 'a1000000-0000-0000-0000-000000000001'
  ) THEN
    RAISE EXCEPTION 'worker purge did not delete the account';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM account_deletion_requests
    WHERE id = 'a2000000-0000-0000-0000-000000000001'
      AND status = 'completed'
      AND attempt_count = 1
      AND completed_at IS NOT NULL
      AND lease_expires_at IS NULL
      AND worker_id IS NULL
  ) THEN
    RAISE EXCEPTION 'worker purge did not complete the deletion request';
  END IF;
END;
$$;

ROLLBACK;
