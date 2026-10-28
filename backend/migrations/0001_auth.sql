-- Gratideo accounts and sessions.
-- The password never reaches the Worker: the phone sends a PBKDF2-SHA256
-- verifier and D1 stores only HMAC-SHA256(PEPPER, verifier).

CREATE TABLE IF NOT EXISTS users (
  id             TEXT PRIMARY KEY,
  email          TEXT NOT NULL UNIQUE,
  name           TEXT NOT NULL,
  verifier_hmac  TEXT NOT NULL,
  kdf_algo       TEXT NOT NULL DEFAULT 'pbkdf2-sha256',
  kdf_iterations INTEGER NOT NULL DEFAULT 210000,
  created_at     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS sessions_expires_at ON sessions(expires_at);
