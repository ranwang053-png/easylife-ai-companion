BEGIN;

CREATE TABLE auth_refresh_token_history (
  token_hash bytea PRIMARY KEY,
  session_id uuid NOT NULL REFERENCES auth_sessions(id) ON DELETE CASCADE,
  used_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT auth_refresh_history_hash_length
    CHECK (octet_length(token_hash) = 32)
);

CREATE INDEX auth_refresh_token_history_session_idx
  ON auth_refresh_token_history (session_id, used_at DESC);

CREATE TABLE account_deletion_tokens (
  token_hash bytea PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_lookup_hash bytea NOT NULL,
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT account_deletion_token_hash_length
    CHECK (octet_length(token_hash) = 32),
  CONSTRAINT account_deletion_device_hash_length
    CHECK (octet_length(device_lookup_hash) = 32),
  CONSTRAINT account_deletion_token_expiry
    CHECK (expires_at > created_at)
);

CREATE INDEX account_deletion_tokens_expiry_idx
  ON account_deletion_tokens (expires_at)
  WHERE consumed_at IS NULL;

COMMENT ON TABLE auth_refresh_token_history IS
  'Hashes of already rotated refresh tokens, retained to detect replay. Never store plaintext tokens.';
COMMENT ON TABLE account_deletion_tokens IS
  'One-time account deletion verification tokens. Token and device values are stored only as keyed hashes.';

COMMIT;
