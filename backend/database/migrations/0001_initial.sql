BEGIN;

CREATE TYPE account_status AS ENUM (
  'active',
  'deletion_pending'
);

CREATE TYPE sms_purpose AS ENUM (
  'login',
  'account_deletion'
);

CREATE TYPE sync_entity_type AS ENUM (
  'userProfile',
  'petProfile',
  'emotionEntry',
  'memoryNote'
);

CREATE TYPE sync_operation AS ENUM (
  'upsert',
  'delete'
);

CREATE TYPE sync_mutation_status AS ENUM (
  'applied',
  'conflict',
  'rejected'
);

CREATE TYPE deletion_status AS ENUM (
  'pending',
  'processing',
  'completed',
  'failed'
);

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_lookup_hash bytea NOT NULL UNIQUE,
  phone_ciphertext bytea NOT NULL,
  status account_status NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  last_login_at timestamptz,
  deletion_requested_at timestamptz,
  CONSTRAINT users_phone_lookup_hash_length
    CHECK (octet_length(phone_lookup_hash) = 32),
  CONSTRAINT users_phone_ciphertext_not_empty
    CHECK (octet_length(phone_ciphertext) > 0),
  CONSTRAINT users_deletion_state_consistent
    CHECK (
      (status = 'active' AND deletion_requested_at IS NULL)
      OR
      (status = 'deletion_pending' AND deletion_requested_at IS NOT NULL)
    )
);

COMMENT ON COLUMN users.phone_lookup_hash IS
  'HMAC-SHA-256 of normalized E.164 phone using a server-side pepper. Never log.';
COMMENT ON COLUMN users.phone_ciphertext IS
  'Application-layer encrypted normalized E.164 phone. Encryption key stays outside PostgreSQL.';

CREATE TABLE sms_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_lookup_hash bytea NOT NULL,
  phone_ciphertext bytea NOT NULL,
  purpose sms_purpose NOT NULL,
  code_hash bytea NOT NULL,
  device_lookup_hash bytea NOT NULL,
  ip_lookup_hash bytea NOT NULL,
  expires_at timestamptz NOT NULL,
  resend_after timestamptz NOT NULL,
  failed_attempts smallint NOT NULL DEFAULT 0,
  consumed_at timestamptz,
  invalidated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sms_phone_lookup_hash_length
    CHECK (octet_length(phone_lookup_hash) = 32),
  CONSTRAINT sms_code_hash_not_empty
    CHECK (octet_length(code_hash) > 0),
  CONSTRAINT sms_device_lookup_hash_length
    CHECK (octet_length(device_lookup_hash) = 32),
  CONSTRAINT sms_ip_lookup_hash_length
    CHECK (octet_length(ip_lookup_hash) = 32),
  CONSTRAINT sms_failed_attempts_range
    CHECK (failed_attempts BETWEEN 0 AND 5),
  CONSTRAINT sms_expiry_after_creation
    CHECK (expires_at > created_at),
  CONSTRAINT sms_resend_after_creation
    CHECK (resend_after > created_at)
);

COMMENT ON COLUMN sms_challenges.code_hash IS
  'Keyed hash of challenge id and SMS code. Never store or log the plaintext code.';
COMMENT ON COLUMN sms_challenges.ip_lookup_hash IS
  'Keyed hash used only for rate limiting. Never store raw IP addresses.';

CREATE INDEX sms_challenges_phone_created_idx
  ON sms_challenges (phone_lookup_hash, created_at DESC);
CREATE INDEX sms_challenges_device_created_idx
  ON sms_challenges (device_lookup_hash, created_at DESC);
CREATE INDEX sms_challenges_ip_created_idx
  ON sms_challenges (ip_lookup_hash, created_at DESC);
CREATE INDEX sms_challenges_expiry_idx
  ON sms_challenges (expires_at)
  WHERE consumed_at IS NULL AND invalidated_at IS NULL;

CREATE TABLE auth_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_lookup_hash bytea NOT NULL,
  refresh_token_hash bytea NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  revoke_reason text,
  CONSTRAINT auth_device_lookup_hash_length
    CHECK (octet_length(device_lookup_hash) = 32),
  CONSTRAINT auth_refresh_token_hash_length
    CHECK (octet_length(refresh_token_hash) = 32),
  CONSTRAINT auth_expiry_after_creation
    CHECK (expires_at > created_at)
);

CREATE INDEX auth_sessions_user_active_idx
  ON auth_sessions (user_id, expires_at DESC)
  WHERE revoked_at IS NULL;

CREATE TABLE user_profiles (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  nickname text NOT NULL DEFAULT '',
  birthday date,
  gender text,
  occupation text NOT NULL DEFAULT '',
  mbti text NOT NULL DEFAULT '',
  zodiac text NOT NULL DEFAULT '',
  goals jsonb NOT NULL DEFAULT '[]'::jsonb,
  target_weight numeric(5, 2) NOT NULL DEFAULT 0,
  diet_preference text NOT NULL DEFAULT '',
  food_restrictions text NOT NULL DEFAULT '',
  pet_reminder_style text NOT NULL DEFAULT '轻提醒',
  birth_place text NOT NULL DEFAULT '',
  current_residence text NOT NULL DEFAULT '',
  personal_tags jsonb NOT NULL DEFAULT '[]'::jsonb,
  version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_profiles_nickname_length
    CHECK (char_length(nickname) <= 50),
  CONSTRAINT user_profiles_target_weight_range
    CHECK (target_weight BETWEEN 0 AND 500),
  CONSTRAINT user_profiles_goals_array
    CHECK (jsonb_typeof(goals) = 'array'),
  CONSTRAINT user_profiles_personal_tags_array
    CHECK (jsonb_typeof(personal_tags) = 'array'),
  CONSTRAINT user_profiles_version_positive
    CHECK (version > 0)
);

CREATE TABLE pet_profiles (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  name text NOT NULL,
  birthday date,
  gender text,
  personality_tags jsonb NOT NULL DEFAULT '[]'::jsonb,
  relationship_note text NOT NULL DEFAULT '',
  original_photo_url text,
  generated_avatar_url text,
  profile_source text NOT NULL DEFAULT '',
  personality_summary text NOT NULL DEFAULT '',
  version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT pet_profiles_name_length
    CHECK (char_length(name) BETWEEN 1 AND 50),
  CONSTRAINT pet_profiles_personality_tags_array
    CHECK (jsonb_typeof(personality_tags) = 'array'),
  CONSTRAINT pet_profiles_version_positive
    CHECK (version > 0)
);

CREATE TABLE emotion_entries (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  occurred_at timestamptz NOT NULL,
  user_text text NOT NULL,
  emotion_label text NOT NULL,
  emotion_labels jsonb NOT NULL,
  emotion_score numeric(4, 3) NOT NULL,
  pet_reply text NOT NULL,
  suggestion text NOT NULL,
  version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT emotion_entries_user_text_length
    CHECK (char_length(user_text) BETWEEN 1 AND 4000),
  CONSTRAINT emotion_entries_label_length
    CHECK (char_length(emotion_label) BETWEEN 1 AND 30),
  CONSTRAINT emotion_entries_labels_array
    CHECK (
      jsonb_typeof(emotion_labels) = 'array'
      AND jsonb_array_length(emotion_labels) BETWEEN 1 AND 4
      AND emotion_labels ->> 0 = emotion_label
    ),
  CONSTRAINT emotion_entries_score_range
    CHECK (emotion_score BETWEEN 0 AND 1),
  CONSTRAINT emotion_entries_version_positive
    CHECK (version > 0),
  UNIQUE (id, user_id)
);

CREATE INDEX emotion_entries_user_time_idx
  ON emotion_entries (user_id, occurred_at DESC)
  WHERE deleted_at IS NULL;

CREATE TABLE memory_notes (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_emotion_entry_id uuid,
  content text NOT NULL,
  version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT memory_notes_content_length
    CHECK (char_length(content) BETWEEN 1 AND 500),
  CONSTRAINT memory_notes_version_positive
    CHECK (version > 0),
  CONSTRAINT memory_notes_source_same_user
    FOREIGN KEY (source_emotion_entry_id, user_id)
    REFERENCES emotion_entries(id, user_id)
    ON DELETE CASCADE
);

CREATE INDEX memory_notes_user_created_idx
  ON memory_notes (user_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE TABLE sync_changes (
  sequence_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  entity_type sync_entity_type NOT NULL,
  entity_id uuid NOT NULL,
  operation sync_operation NOT NULL,
  entity_version bigint NOT NULL,
  changed_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sync_changes_version_positive
    CHECK (entity_version > 0)
);

CREATE INDEX sync_changes_user_sequence_idx
  ON sync_changes (user_id, sequence_id);

CREATE TABLE sync_mutations (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mutation_id uuid NOT NULL,
  device_lookup_hash bytea NOT NULL,
  entity_type sync_entity_type NOT NULL,
  entity_id uuid NOT NULL,
  operation sync_operation NOT NULL,
  base_version bigint NOT NULL,
  status sync_mutation_status NOT NULL,
  applied_version bigint,
  error_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, mutation_id),
  CONSTRAINT sync_mutations_device_hash_length
    CHECK (octet_length(device_lookup_hash) = 32),
  CONSTRAINT sync_mutations_base_version_nonnegative
    CHECK (base_version >= 0),
  CONSTRAINT sync_mutations_result_consistent
    CHECK (
      (status = 'applied' AND applied_version IS NOT NULL AND error_code IS NULL)
      OR
      (status IN ('conflict', 'rejected') AND error_code IS NOT NULL)
    )
);

CREATE INDEX sync_mutations_created_idx
  ON sync_mutations (created_at);

CREATE TABLE account_deletion_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE REFERENCES users(id) ON DELETE SET NULL,
  status deletion_status NOT NULL DEFAULT 'pending',
  requested_at timestamptz NOT NULL DEFAULT now(),
  processing_started_at timestamptz,
  completed_at timestamptz,
  failure_code text,
  CONSTRAINT deletion_request_state_consistent
    CHECK (
      (status = 'pending'
        AND processing_started_at IS NULL
        AND completed_at IS NULL
        AND failure_code IS NULL)
      OR
      (status = 'processing'
        AND processing_started_at IS NOT NULL
        AND completed_at IS NULL
        AND failure_code IS NULL)
      OR
      (status = 'completed'
        AND processing_started_at IS NOT NULL
        AND completed_at IS NOT NULL
        AND failure_code IS NULL)
      OR
      (status = 'failed'
        AND processing_started_at IS NOT NULL
        AND completed_at IS NULL
        AND failure_code IS NOT NULL)
    )
);

CREATE TABLE security_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  request_id uuid,
  event_type text NOT NULL,
  outcome text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT security_events_metadata_object
    CHECK (jsonb_typeof(metadata) = 'object')
);

COMMENT ON TABLE security_events IS
  'Security metadata only. Never store phone numbers, SMS codes, full emotion text, profile payloads, or tokens.';

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER users_set_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER user_profiles_set_updated_at
BEFORE UPDATE ON user_profiles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER pet_profiles_set_updated_at
BEFORE UPDATE ON pet_profiles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER emotion_entries_set_updated_at
BEFORE UPDATE ON emotion_entries
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER memory_notes_set_updated_at
BEFORE UPDATE ON memory_notes
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION begin_account_deletion(
  target_user_id uuid,
  deletion_request_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE users
  SET
    status = 'deletion_pending',
    deletion_requested_at = now()
  WHERE id = target_user_id
    AND status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'active account not found';
  END IF;

  UPDATE auth_sessions
  SET
    revoked_at = COALESCE(revoked_at, now()),
    revoke_reason = COALESCE(revoke_reason, 'account_deletion')
  WHERE user_id = target_user_id;

  INSERT INTO account_deletion_requests (id, user_id)
  VALUES (deletion_request_id, target_user_id);
END;
$$;

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
  SELECT deletion.user_id, account.phone_lookup_hash
  INTO target_user_id, target_phone_lookup_hash
  FROM account_deletion_requests AS deletion
  JOIN users AS account ON account.id = deletion.user_id
  WHERE deletion.id = deletion_request_id
    AND deletion.status IN ('pending', 'failed')
  FOR UPDATE;

  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'deletion request not found or cannot be processed';
  END IF;

  UPDATE account_deletion_requests
  SET
    status = 'processing',
    processing_started_at = now(),
    completed_at = NULL,
    failure_code = NULL
  WHERE id = deletion_request_id;

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
    completed_at = now()
  WHERE id = deletion_request_id;
END;
$$;

REVOKE ALL ON FUNCTION begin_account_deletion(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION purge_deleted_account(uuid) FROM PUBLIC;

COMMIT;
