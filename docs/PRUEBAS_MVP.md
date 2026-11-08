# Pruebas de aceptación manuales del MVP

Usa únicamente datos ficticios. Antes de probar, ejecuta `docker compose up -d --build` y `scripts/smoke-test`.

## Autenticación
1. Inicia sesión con `admin` y la contraseña definida en `.env`.
2. Comprueba que `GET /api/auth/me` devuelve username, nombre y rol.
3. Prueba una contraseña incorrecta: debe responder HTTP 401.
4. Prueba un endpoint sin token: debe responder HTTP 401.

## Pacientes
1. Registra una persona sin teléfono; debe guardarse correctamente.
2. Busca por nombres y por documento.
3. Abre un paciente y actualiza sus datos; verifica que se guarden al volver al listado.
4. Registra un documento repetido; debe rechazarse por unicidad.

## Agenda
1. Programa una cita con profesional y recurso.
2. Intenta otra cita que se cruce con el mismo profesional: HTTP 409.
3. Intenta otra cita que se cruce con el mismo recurso: HTTP 409.
4. Repite usando mayúsculas/minúsculas distintas en el nombre del recurso: también debe bloquearse.
5. Cancela una cita y comprueba que libera el horario.

## Sesiones y cobros
1. Registra una sesión para una cita programada desde usuario clínico.
2. Verifica que la cita cambia a COMPLETADA y que no se acepta una segunda sesión para la misma cita.
3. Crea una factura y registra pagos parciales.
4. Intenta pagar más que el saldo; debe responder HTTP 409.
5. Comprueba que el estado cambia a PAGADA cuando el saldo llega a cero.

## Plataformas
- Android Emulator: `API_BASE_URL=http://10.0.2.2:8080/api`.
- Chrome/Web: `API_BASE_URL=http://localhost:8080/api`.
- Android/iOS físico: usa `http://IP_LAN_DEL_SERVIDOR:8080/api`, abre el puerto 8080 solo en la red privada y no publiques PostgreSQL.
- macOS/Linux/Windows desktop: usa `http://localhost:8080/api`.
- iOS simulator: `http://localhost:8080/api` con Xcode en macOS.

La compilación para iOS requiere macOS y Xcode. El SDK de Flutter crea la estructura nativa mediante el script `prepare-flutter`; el código funcional de la aplicación está bajo `mobile/lib`.
