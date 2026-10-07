-- V3__demo_sessions.sql — one-tap ephemeral demo accounts (PLAN decision 14).
--
-- Opaque bearer sessions minted by POST /api/demo/bootstrap. Short-lived,
-- cleaned on every bootstrap call. Demo rows live in the normal tables with
-- user_id = 'demo-<uuid>' so ownership discipline is unchanged.

CREATE TABLE IF NOT EXISTS demo_sessions (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_demo_sessions_expires
  ON demo_sessions (expires_at);
