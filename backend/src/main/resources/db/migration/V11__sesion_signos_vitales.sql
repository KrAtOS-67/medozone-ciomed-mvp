-- Estado de la sesión (PENDIENTE = enfermería preparó, COMPLETADA = médico finalizó)
ALTER TABLE sesion_tratamiento ADD COLUMN IF NOT EXISTS estado VARCHAR(20) NOT NULL DEFAULT 'COMPLETADA';

-- Signos vitales
ALTER TABLE sesion_tratamiento ADD COLUMN IF NOT EXISTS temperatura NUMERIC(5,2);
ALTER TABLE sesion_tratamiento ADD COLUMN IF NOT EXISTS frecuencia_cardiaca INTEGER;
ALTER TABLE sesion_tratamiento ADD COLUMN IF NOT EXISTS frecuencia_respiratoria INTEGER;
ALTER TABLE sesion_tratamiento ADD COLUMN IF NOT EXISTS saturacion_oxigeno INTEGER;
ALTER TABLE sesion_tratamiento ADD COLUMN IF NOT EXISTS peso NUMERIC(5,2);
ALTER TABLE sesion_tratamiento ADD COLUMN IF NOT EXISTS talla NUMERIC(5,2);