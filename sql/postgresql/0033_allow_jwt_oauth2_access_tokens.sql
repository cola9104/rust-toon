-- Rust currently returns signed JWT access tokens. Keep them in Yudao's
-- OAuth2 token table while the authentication transport is migrated to
-- Yudao-style opaque access tokens.
alter table system_oauth2_access_token
    alter column access_token type text;
