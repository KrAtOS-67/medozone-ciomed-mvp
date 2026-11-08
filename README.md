# MedOzone CIOMED · MVP multiplataforma

Proyecto fuente completo del MVP: Flutter/Dart + API REST Spring Boot + PostgreSQL. El backend y la base de datos se ejecutan con Docker Compose; Flutter se puede ejecutar en Android, iOS, web, Windows, macOS y Linux.

## 1. Alcance funcional del MVP

- Login JWT y roles: ADMIN, RECEPCIONISTA, MEDICO y ENFERMERA.
- Gestión de pacientes: registrar, buscar, consultar y actualizar; teléfono opcional.
- Agenda de citas y bloqueo de cruces por profesional y recurso (validado en PostgreSQL).
- Registro manual de sesiones clínicas, sin prescripción ni control electrónico de equipos.
- Facturas administrativas y pagos parciales, incluido efectivo.
- Resumen diario para perfiles administrativos.

SMS reales, recuperación de contraseñas, exportaciones PDF/Excel, integración de hardware, facturación fiscal y uso clínico en producción quedan fuera de esta primera entrega y requieren decisiones/aprobación de CIOMED.

## 2. Requisitos

- Docker Desktop / Docker Engine con Docker Compose v2.
- Flutter stable (recomendado 3.47.x o posterior estable), Git y Python 3 para preparar manifiestos locales.
- Para Android: Android Studio, SDK y emulador o dispositivo.
- Para iOS: macOS, Xcode y CocoaPods.
- Para Windows desktop: Visual Studio 2022 con carga de trabajo Desktop development with C++; flutter_secure_storage puede requerir ATL.
- Para Linux desktop: dependencias de Flutter para Linux y `libsecret-1-dev`/keyring para almacenamiento seguro.
- Para macOS desktop: Xcode Command Line Tools.

Flutter publica soporte para Android/iOS, Windows/macOS/Linux y web; las herramientas de compilación cambian según plataforma. Consulta https://docs.flutter.dev/reference/supported-platforms.

## 3. Configuración inicial (todos los sistemas)

1. Clona o descomprime este repositorio.
2. Copia `.env.example` a `.env`.
3. Cambia `POSTGRES_PASSWORD` y `MEDOZONE_DEMO_PASSWORD` por valores distintos y fuertes.
4. Genera JWT secret de 32 bytes en Base64 y pega el resultado en `JWT_SECRET_BASE64`.

Linux/macOS/Git Bash:
```bash
openssl rand -base64 32
cp .env.example .env
```

PowerShell:
```powershell
Copy-Item .env.example .env
$bytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$rng.Dispose()
[Convert]::ToBase64String($bytes)
```

No subas `.env` a Git. No uses las claves de ejemplo.

## 4. Preparar los proyectos nativos de Flutter

Los directorios de plataforma se generan usando `flutter create` oficial para la versión estable instalada. El código de la aplicación ya está completo en `mobile/lib`; el proceso genera solo los wrappers nativos necesarios para compilar cada target y conserva los archivos Dart y `pubspec.yaml`.

Linux/macOS:
```bash
./scripts/prepare-flutter.sh
```

Windows PowerShell:
```powershell
./scripts/prepare-flutter.ps1
```

Ejecuta este paso una sola vez por copia del proyecto (y de nuevo al actualizar Flutter si fuese necesario).

## 5. Ejecutar todo de una vez

Estos comandos levantan PostgreSQL y Spring Boot mediante Docker y arrancan Flutter.

Windows PowerShell:
```powershell
./scripts/run.ps1 -Target android
./scripts/run.ps1 -Target chrome
./scripts/run.ps1 -Target windows
```

Linux/macOS:
```bash
./scripts/run.sh android
./scripts/run.sh chrome
./scripts/run.sh linux
./scripts/run.sh macos
```

iOS (solo macOS con Xcode):
```bash
./scripts/run.sh ios
```

Targets disponibles: `android`, `chrome`, `web-server`, `windows`, `macos`, `linux`, `ios` (respetando las herramientas instaladas para cada sistema operativo).

## 6. Direcciones de API

- Android Emulator: `http://10.0.2.2:8080/api` (el script lo selecciona automáticamente).
- iOS Simulator, web y desktop: `http://localhost:8080/api`.
- Teléfono físico: proporciona la IP LAN de la computadora que ejecuta Docker.

Ejemplo teléfono físico:
```powershell
./scripts/run.ps1 -Target android -ApiUrl http://192.168.1.20:8080/api
```
Cambia `192.168.1.20` por la IP real del equipo. Para este caso el API se publica en `0.0.0.0:8080` por defecto y el firewall debe permitir solo la red privada. No publiques este puerto en Internet. PostgreSQL no se publica a la LAN.

También puedes ejecutar manualmente:
```bash
docker compose up -d --build
docker compose ps
docker compose logs -f api
cd mobile
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api
```

## Compilar paquetes release

Para distribuir la aplicación, primero despliega la API detrás de HTTPS y usa la URL real del servicio. No compiles release con `http://localhost` ni con el puerto de desarrollo.

PowerShell:
```powershell
./scripts/build.ps1 -Target android-apk -ApiUrl https://api.ejemplo.bo/api
./scripts/build.ps1 -Target android-aab -ApiUrl https://api.ejemplo.bo/api
./scripts/build.ps1 -Target web -ApiUrl https://api.ejemplo.bo/api
```

Linux/macOS:
```bash
./scripts/build.sh android-apk https://api.ejemplo.bo/api
./scripts/build.sh android-aab https://api.ejemplo.bo/api
./scripts/build.sh web https://api.ejemplo.bo/api
./scripts/build.sh ios https://api.ejemplo.bo/api  # macOS + Xcode
```

También se aceptan los destinos `windows`, `macos` y `linux` en el host que tenga sus herramientas nativas instaladas. Los artefactos se generan en `mobile/build/`. Reemplaza el dominio de ejemplo por el backend que CIOMED despliegue con TLS válido.

## 7. Usuarios de demostración

- `admin`
- `recepcion`
- `medico`
- `enfermera`

Los cuatro usan el valor `MEDOZONE_DEMO_PASSWORD` configurado en `.env`. Estos usuarios solo se crean cuando el perfil `dev` arranca por primera vez. No uses el perfil de demostración en producción.

## 8. Comprobar el backend

```bash
curl http://localhost:8080/actuator/health
```
PowerShell:
```powershell
Invoke-RestMethod http://localhost:8080/actuator/health
./scripts/smoke-test.ps1
```
Bash:
```bash
./scripts/smoke-test.sh
```

Para detener contenedores sin borrar los datos: `docker compose down` o `scripts/stop`.
Para borrar también la base de datos local (acción destructiva): `docker compose down -v`.

## 9. Rutas principales

- `POST /api/auth/login`; `GET /api/auth/me`
- `GET/POST/PUT /api/pacientes`
- `GET/POST /api/citas`; `PATCH /api/citas/{id}/cancelar`
- `GET/POST /api/sesiones`
- `GET/POST /api/facturas`; `POST /api/facturas/{id}/pagos`
- `GET /api/reportes/resumen`

Login y `/actuator/health` son públicos. Los demás endpoints requieren JWT y el rol autorizado en el backend.

## 10. Estructura

```text
medozone_mvp/
├── backend/                # Spring Boot, seguridad, API, Flyway
├── mobile/                 # Flutter/Dart y pantallas de CIOMED
├── scripts/                # Preparar, ejecutar, detener y smoke tests
├── docs/                   # Pruebas y prototipos originales
├── compose.yaml            # PostgreSQL + API
└── .env.example            # Variables locales; copiar a .env
```

## 11. Limitaciones y seguridad

Esta es una base MVP académica/de demostración, no una aplicación clínica certificada ni un sistema aprobado para datos reales. Usa datos sintéticos. Antes de producción se necesita HTTPS, secretos gestionados, alta inicial segura de administradores, rotación/revocación de JWT, auditoría detallada, respaldo y restauración probados, política de accesos por CIOMED, revisión de privacidad, aprobación de campos clínicos y reglas contables/fiscales. El permiso HTTP sin TLS agregado al manifiesto Android/iOS es únicamente para pruebas de red local y debe retirarse al configurar HTTPS.

## 12. Versión tecnológica de referencia

- Java 21
- Spring Boot 4.1.2
- PostgreSQL 18.6
- Flutter stable 3.47.x o superior
- Docker Compose v2

Mantén las versiones bloqueadas y vuelve a ejecutar los smoke tests después de actualizar dependencias.
