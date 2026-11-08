CREATE TABLE IF NOT EXISTS medico_area (
    user_id BIGINT NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    tipo_tratamiento VARCHAR(40) NOT NULL,
    PRIMARY KEY (user_id, tipo_tratamiento)
);

-- Asignamos por defecto Ozonoterapia a los médicos existentes para que no fallen
INSERT INTO medico_area (user_id, tipo_tratamiento)
SELECT id, 'OZONOTERAPIA' FROM app_user WHERE role = 'MEDICO'
ON CONFLICT DO NOTHING;