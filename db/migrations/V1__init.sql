-- V1__init.sql — job-tracker-mcp base schema (Phase 1).
--
-- Ownership discipline (PLAN §7): every row carries user_id from the JWT
-- `sub`; every server query scopes by it (no RLS — enforced in SQL text +
-- covered by cross-user tests). No delete tool in v1: archive only.

CREATE TABLE IF NOT EXISTS schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  company TEXT NOT NULL CHECK (char_length(company) BETWEEN 1 AND 200),
  role TEXT NOT NULL CHECK (char_length(role) BETWEEN 1 AND 200),
  source TEXT CHECK (source IS NULL OR char_length(source) <= 100),
  stage TEXT NOT NULL CHECK (stage IN (
    'saved', 'applied', 'screening', 'interview',
    'offer', 'accepted', 'rejected', 'withdrawn'
  )),
  applied_at TIMESTAMPTZ,
  salary_min INTEGER CHECK (salary_min IS NULL OR salary_min >= 0),
  salary_max INTEGER CHECK (salary_max IS NULL OR salary_max >= 0),
  link TEXT,
  notes TEXT CHECK (notes IS NULL OR char_length(notes) <= 10000),
  archived_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (salary_min IS NULL OR salary_max IS NULL OR salary_min <= salary_max)
);

CREATE TABLE IF NOT EXISTS contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  application_id UUID REFERENCES applications (id) ON DELETE SET NULL,
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 200),
  role TEXT,
  company TEXT,
  channels JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  application_id UUID NOT NULL REFERENCES applications (id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN (
    'note', 'call', 'email', 'meeting', 'interview', 'followup', 'other'
  )),
  happened_at TIMESTAMPTZ NOT NULL,
  summary TEXT CHECK (summary IS NULL OR char_length(summary) <= 5000),
  follow_up_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ownership + access-path indexes (every query starts with user_id).
CREATE INDEX IF NOT EXISTS ix_applications_user_stage
  ON applications (user_id, stage) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS ix_applications_user_archived
  ON applications (user_id, archived_at);
CREATE INDEX IF NOT EXISTS ix_contacts_user_app
  ON contacts (user_id, application_id);
CREATE INDEX IF NOT EXISTS ix_interactions_app_happened
  ON interactions (application_id, happened_at DESC);
CREATE INDEX IF NOT EXISTS ix_interactions_user_followup
  ON interactions (user_id, follow_up_at) WHERE follow_up_at IS NOT NULL;
