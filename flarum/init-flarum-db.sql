-- Flarum database initialization.
-- Pre-creates a table that some nitro-porter versions expect but Flarum does
-- not create by default. Safe to keep: CREATE TABLE IF NOT EXISTS is a no-op
-- if Flarum (or one of its extensions) already created the table.
CREATE TABLE IF NOT EXISTS flarumaccess_tokens (
    id VARCHAR(40) PRIMARY KEY,
    user_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
