-- nitro-porter scratch database initialization.
-- Pre-creates a table nitro-porter expects to exist before a Flarum export run.
CREATE TABLE IF NOT EXISTS access_tokens (
    id VARCHAR(40) PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
