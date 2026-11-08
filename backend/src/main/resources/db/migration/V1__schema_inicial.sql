CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE app_user (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(60) NOT NULL UNIQUE,
    password_hash VARCHAR(100) NOT NULL,
    full_name VARCHAR(140) NOT NULL,
    role VARCHAR(30) NOT NULL CHECK (role IN ('ADMIN', 'MEDICO', 'ENFERMERA', 'RECEPCIONISTA')),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE paciente (
    id BIGSERIAL PRIMARY KEY,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    documento VARCHAR(30),
    fecha_nacimiento DATE,
    telefono VARCHAR(30),
    email VARCHAR(120),
    observaciones VARCHAR(500),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX ux_paciente_documento ON paciente(documento) WHERE documento IS NOT NULL AND documento <> '';
CREATE INDEX ix_paciente_nombre ON paciente (lower(apellidos), lower(nombres));

CREATE TABLE cita (
    id BIGSERIAL PRIMARY KEY,
    paciente_id BIGINT NOT NULL REFERENCES paciente(id),
    profesional VARCHAR(120) NOT NULL,
    recurso VARCHAR(120) NOT NULL,
    tipo_tratamiento VARCHAR(40) NOT NULL CHECK (tipo_tratamiento IN ('OZONOTERAPIA', 'OXIGENOTERAPIA_HIPERBARICA')),
    inicio TIMESTAMP NOT NULL,
    duracion_minutos INTEGER NOT NULL DEFAULT 60 CHECK (duracion_minutos BETWEEN 15 AND 240),
    estado VARCHAR(20) NOT NULL DEFAULT 'PROGRAMADA' CHECK (estado IN ('PROGRAMADA', 'COMPLETADA', 'CANCELADA')),
    motivo VARCHAR(300),
    creado_por VARCHAR(60) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX ix_cita_inicio ON cita(inicio);
CREATE INDEX ix_cita_paciente ON cita(paciente_id, inicio DESC);

-- Las exclusiones se evalúan también en PostgreSQL. Protegen frente a dos reservas simultáneas.
ALTER TABLE cita ADD CONSTRAINT ex_cita_recurso_solapado
EXCLUDE USING gist (
    (lower(recurso)) WITH =,
    tsrange(inicio, inicio + (duracion_minutos * INTERVAL '1 minute'), '[)') WITH &&
) WHERE (estado <> 'CANCELADA');

ALTER TABLE cita ADD CONSTRAINT ex_cita_profesional_solapado
EXCLUDE USING gist (
    (lower(profesional)) WITH =,
    tsrange(inicio, inicio + (duracion_minutos * INTERVAL '1 minute'), '[)') WITH &&
) WHERE (estado <> 'CANCELADA');

CREATE TABLE sesion_tratamiento (
    id BIGSERIAL PRIMARY KEY,
    cita_id BIGINT NOT NULL UNIQUE REFERENCES cita(id),
    dosis NUMERIC(10, 3) NOT NULL CHECK (dosis >= 0),
    presion NUMERIC(10, 3),
    duracion_minutos INTEGER NOT NULL CHECK (duracion_minutos BETWEEN 1 AND 240),
    observaciones VARCHAR(1000),
    registrado_por VARCHAR(60) NOT NULL,
    registrado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX ix_sesion_registro ON sesion_tratamiento(registrado_en DESC);

CREATE TABLE factura (
    id BIGSERIAL PRIMARY KEY,
    paciente_id BIGINT NOT NULL REFERENCES paciente(id),
    concepto VARCHAR(180) NOT NULL,
    total NUMERIC(12, 2) NOT NULL CHECK (total > 0),
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE' CHECK (estado IN ('PENDIENTE', 'PAGADA')),
    emitida_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    creado_por VARCHAR(60) NOT NULL
);
CREATE INDEX ix_factura_paciente ON factura(paciente_id, emitida_en DESC);

CREATE TABLE pago (
    id BIGSERIAL PRIMARY KEY,
    factura_id BIGINT NOT NULL REFERENCES factura(id),
    monto NUMERIC(12, 2) NOT NULL CHECK (monto > 0),
    metodo VARCHAR(20) NOT NULL CHECK (metodo IN ('EFECTIVO', 'TRANSFERENCIA', 'TARJETA')),
    registrado_por VARCHAR(60) NOT NULL,
    pagado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX ix_pago_factura ON pago(factura_id, pagado_en DESC);
