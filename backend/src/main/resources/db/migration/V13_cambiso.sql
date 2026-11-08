ALTER TABLE sesion_tratamiento ALTER COLUMN presion TYPE VARCHAR(20);

ALTER TABLE sesion_tratamiento DROP CONSTRAINT IF EXISTS sesion_tratamiento_estado_check;
ALTER TABLE sesion_tratamiento ADD CONSTRAINT sesion_tratamiento_estado_check CHECK (estado IN ('PENDIENTE', 'COMPLETADA'));