\set ON_ERROR_STOP on

BEGIN;

INSERT INTO users (
  id,
  phone_lookup_hash,
  phone_ciphertext
)
VALUES (
  '91000000-0000-0000-0000-000000000001',
  decode(repeat('91', 32), 'hex'),
  convert_to('encrypted-phone-auth-hardening', 'UTF8')
);

INSERT INTO auth_sessions (
  id,
  user_id,
  device_lookup_hash,
  refresh_token_hash,
  expires_at
)
VALUES (
  '92000000-0000-0000-0000-000000000001',
  '91000000-0000-0000-0000-000000000001',
  decode(repeat('92', 32), 'hex'),
  decode(repeat('93', 32), 'hex'),
  now() + interval '30 days'
);

INSERT INTO auth_refresh_token_history (
  token_hash,
  session_id
)
VALUES (
  decode(repeat('94', 32), 'hex'),
  '92000000-0000-0000-0000-000000000001'
);

INSERT INTO account_deletion_tokens (
  token_hash,
  user_id,
  device_lookup_hash,
  expires_at
)
VALUES (
  decode(repeat('95', 32), 'hex'),
  '91000000-0000-0000-0000-000000000001',
  decode(repeat('92', 32), 'hex'),
  now() + interval '10 minutes'
);

DO $$
BEGIN
  BEGIN
    INSERT INTO auth_refresh_token_history (
      token_hash,
      session_id
    )
    VALUES (
      decode(repeat('94', 32), 'hex'),
      '92000000-0000-0000-0000-000000000001'
    );
    RAISE EXCEPTION 'duplicate refresh history hash was accepted';
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
  END;
END;
$$;

ROLLBACK;
