-- Pull cursor on the server clock. Client timestamps are only used to decide
-- which version wins; synced_at is what a device asks for "everything newer than".
ALTER TABLE prayers ADD COLUMN synced_at TEXT NOT NULL DEFAULT '';
ALTER TABLE thanks ADD COLUMN synced_at TEXT NOT NULL DEFAULT '';
ALTER TABLE entries ADD COLUMN synced_at TEXT NOT NULL DEFAULT '';

UPDATE prayers SET synced_at = updated_at WHERE synced_at = '';
UPDATE thanks SET synced_at = updated_at WHERE synced_at = '';
UPDATE entries SET synced_at = updated_at WHERE synced_at = '';

CREATE INDEX IF NOT EXISTS prayers_user_synced ON prayers(user_id, synced_at);
CREATE INDEX IF NOT EXISTS thanks_user_synced ON thanks(user_id, synced_at);
CREATE INDEX IF NOT EXISTS entries_user_synced ON entries(user_id, synced_at);

