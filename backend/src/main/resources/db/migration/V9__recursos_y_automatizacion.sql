CREATE TABLE IF NOT EXISTS recurso (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    tipo_tratamiento VARCHAR(40) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- Insertamos las camillas por defecto
INSERT INTO recurso (nombre, tipo_tratamiento) VALUES 
('Camilla 1', 'OZONOTERAPIA'),
('Camilla 2', 'OZONOTERAPIA'),
('Camara Hiperbarica 1', 'OXIGENOTERAPIA_HIPERBARICA'),
('Camara Hiperbarica 2', 'OXIGENOTERAPIA_HIPERBARICA')
ON CONFLICT (nombre) DO NOTHING;