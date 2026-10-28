-- Personal data that now follows the account across devices.
-- Rows are soft-deleted so a removal can travel to the other phones.
-- updated_at is an ISO-8601 UTC string; last write wins when merging.

CREATE TABLE IF NOT EXISTS prayers (
  uuid        TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  status      TEXT NOT NULL,
  created_at  TEXT NOT NULL,
  answered_at TEXT,
  testimony   TEXT,
  updated_at  TEXT NOT NULL,
  deleted_at  TEXT
);
CREATE INDEX IF NOT EXISTS prayers_user_updated ON prayers(user_id, updated_at);

CREATE TABLE IF NOT EXISTS thanks (
  uuid       TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  text       TEXT NOT NULL,
  day        TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);
CREATE INDEX IF NOT EXISTS thanks_user_updated ON thanks(user_id, updated_at);

CREATE TABLE IF NOT EXISTS entries (
  uuid       TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind       TEXT NOT NULL,
  text       TEXT NOT NULL,
  decision   TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);
CREATE INDEX IF NOT EXISTS entries_user_updated ON entries(user_id, updated_at);

