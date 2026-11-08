-- ============================================================
-- Recuperación segura de contraseñas
-- ============================================================

-- Email por usuario (único, case-insensitive)
ALTER TABLE app_user ADD COLUMN IF NOT EXISTS email VARCHAR(180);
CREATE UNIQUE INDEX IF NOT EXISTS ux_app_user_email
    ON app_user (lower(email))
    WHERE email IS NOT NULL AND email <> '';

-- Tokens de recuperación (se guarda SOLO el hash SHA-256)
CREATE TABLE password_reset_token (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT       NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    token_hash   CHAR(64)     NOT NULL,
    expires_at   TIMESTAMP    NOT NULL,
    used         BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    used_at      TIMESTAMP,
    created_ip   VARCHAR(45)
);
CREATE INDEX ix_prt_hash   ON password_reset_token(token_hash);
CREATE INDEX ix_prt_user   ON password_reset_token(user_id, created_at DESC);
CREATE INDEX ix_prt_activo ON password_reset_token(expires_at) WHERE used = FALSE;