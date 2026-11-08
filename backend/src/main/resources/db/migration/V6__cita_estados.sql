-- Eliminar la restriccion anterior
ALTER TABLE cita DROP CONSTRAINT IF EXISTS cita_estado_check;

-- Renombrar COMPLETADA a ATENDIDA
UPDATE cita SET estado = 'ATENDIDA' WHERE estado = 'COMPLETADA';

-- Agregar la nueva restriccion con los 5 estados
ALTER TABLE cita ADD CONSTRAINT cita_estado_check 
CHECK (estado IN ('PROGRAMADA', 'CONFIRMADA', 'ATENDIDA', 'CANCELADA', 'AUSENTE'));