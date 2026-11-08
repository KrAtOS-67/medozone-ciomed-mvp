-- Contador de intentos fallidos por código
ALTER TABLE password_reset_token
    ADD COLUMN IF NOT EXISTS attempts INTEGER NOT NULL DEFAULT 0;

-- Índice para limpieza de códigos viejos
CREATE INDEX IF NOT EXISTS ix_prt_cleanup
    ON password_reset_token(expires_at)
    WHERE used = FALSE;