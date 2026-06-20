\set ON_ERROR_STOP on

BEGIN;

INSERT INTO users (
  id,
  phone_lookup_hash,
  phone_ciphertext
)
VALUES (
  '10000000-0000-0000-0000-000000000001',
  decode(repeat('11', 32), 'hex'),
  convert_to('encrypted-phone-one', 'UTF8')
);

DO $$
BEGIN
  BEGIN
    INSERT INTO users (
      id,
      phone_lookup_hash,
      phone_ciphertext
    )
    VALUES (
      '10000000-0000-0000-0000-000000000002',
      decode(repeat('11', 32), 'hex'),
      convert_to('encrypted-phone-duplicate', 'UTF8')
    );
    RAISE EXCEPTION 'duplicate phone hash was accepted';
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
  END;
END;
$$;

INSERT INTO users (
  id,
  phone_lookup_hash,
  phone_ciphertext
)
VALUES (
  '20000000-0000-0000-0000-000000000001',
  decode(repeat('22', 32), 'hex'),
  convert_to('encrypted-phone-two', 'UTF8')
);

INSERT INTO emotion_entries (
  id,
  user_id,
  occurred_at,
  user_text,
  emotion_label,
  emotion_labels,
  emotion_score,
  pet_reply,
  suggestion
)
VALUES (
  '30000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  now(),
  'test emotion text',
  '疲惫',
  '["疲惫", "压力"]'::jsonb,
  0.72,
  'test reply',
  'test suggestion'
);

DO $$
BEGIN
  BEGIN
    INSERT INTO memory_notes (
      id,
      user_id,
      source_emotion_entry_id,
      content
    )
    VALUES (
      '40000000-0000-0000-0000-000000000001',
      '20000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      'cross-user memory must fail'
    );
    RAISE EXCEPTION 'cross-user memory reference was accepted';
  EXCEPTION
    WHEN foreign_key_violation THEN
      NULL;
  END;
END;
$$;

INSERT INTO memory_notes (
  id,
  user_id,
  source_emotion_entry_id,
  content
)
VALUES (
  '40000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'same-user memory succeeds'
);

INSERT INTO sms_challenges (
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
  '50000000-0000-0000-0000-000000000001',
  decode(repeat('11', 32), 'hex'),
  convert_to('encrypted-phone-one', 'UTF8'),
  'login',
  decode(repeat('33', 32), 'hex'),
  decode(repeat('44', 32), 'hex'),
  decode(repeat('55', 32), 'hex'),
  now() + interval '5 minutes',
  now() + interval '60 seconds'
);

INSERT INTO auth_sessions (
  id,
  user_id,
  device_lookup_hash,
  refresh_token_hash,
  expires_at
)
VALUES (
  '60000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  decode(repeat('44', 32), 'hex'),
  decode(repeat('66', 32), 'hex'),
  now() + interval '30 days'
);

SELECT begin_account_deletion(
  '10000000-0000-0000-0000-000000000001',
  '70000000-0000-0000-0000-000000000001'
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM auth_sessions
    WHERE id = '60000000-0000-0000-0000-000000000001'
      AND revoked_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'account deletion did not revoke sessions';
  END IF;
END;
$$;

SELECT purge_deleted_account(
  '70000000-0000-0000-0000-000000000001'
);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM users
    WHERE id = '10000000-0000-0000-0000-000000000001'
  ) THEN
    RAISE EXCEPTION 'user was not physically deleted';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM sms_challenges
    WHERE phone_lookup_hash = decode(repeat('11', 32), 'hex')
  ) THEN
    RAISE EXCEPTION 'phone challenge data was not deleted';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM account_deletion_requests
    WHERE id = '70000000-0000-0000-0000-000000000001'
      AND status = 'completed'
      AND user_id IS NULL
  ) THEN
    RAISE EXCEPTION 'deletion completion proof is invalid';
  END IF;
END;
$$;

ROLLBACK;
