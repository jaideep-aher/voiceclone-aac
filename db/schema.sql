-- VoiceClone AAC — Railway PostgreSQL schema
-- Run this once after adding the Postgres plugin in Railway:
--   railway run psql $DATABASE_URL -f db/schema.sql

CREATE TABLE IF NOT EXISTS profiles (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  display_name  TEXT NOT NULL DEFAULT '',
  voice_clone_id     TEXT,
  voice_clone_status TEXT NOT NULL DEFAULT 'none'
    CHECK (voice_clone_status IN ('none', 'processing', 'active', 'failed')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS phrases (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  text           TEXT NOT NULL,
  category       TEXT NOT NULL DEFAULT 'custom'
    CHECK (category IN ('medical', 'family', 'daily', 'emergency', 'custom')),
  is_quick_phrase BOOLEAN NOT NULL DEFAULT false,
  audio_url      TEXT,
  use_count      INTEGER NOT NULL DEFAULT 0,
  last_used_at   TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS voice_samples (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  duration_seconds DOUBLE PRECISION NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS phrases_user_id_idx       ON phrases(user_id);
CREATE INDEX IF NOT EXISTS phrases_user_category_idx ON phrases(user_id, category);
CREATE INDEX IF NOT EXISTS profiles_email_idx        ON profiles(email);
