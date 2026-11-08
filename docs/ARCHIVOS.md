# Mapa de archivos de MedOzone CIOMED

Este mapa corresponde al contenido real de la carpeta del proyecto. Los wrappers nativos Android/iOS/Web/Windows/macOS/Linux se crean con `scripts/prepare-flutter` usando la versión de Flutter instalada.

- `.env.example` — Plantilla de variables privadas para PostgreSQL, JWT, CORS y puertos publicados.
- `backend/Dockerfile` — Compilación multietapa Maven/JDK 21 y ejecución no-root del backend.
- `backend/pom.xml` — Dependencias y configuración Maven de Spring Boot.
- `backend/src/main/java/bo/ciomed/medozone/MedOzoneApplication.java` — Punto de entrada Spring Boot.
- `backend/src/main/java/bo/ciomed/medozone/auth/AuthController.java` — Login JWT y endpoint del perfil autenticado.
- `backend/src/main/java/bo/ciomed/medozone/citas/CitaController.java` — Agenda, creación, cancelación y validación de cruces.
- `backend/src/main/java/bo/ciomed/medozone/clinica/SesionController.java` — Registro y consulta de sesiones clínicas manuales.
- `backend/src/main/java/bo/ciomed/medozone/common/ApiExceptionHandler.java` — Errores HTTP uniformes y mensajes de validación.
- `backend/src/main/java/bo/ciomed/medozone/config/SecurityConfig.java` — Stateless security, CORS, reglas públicas y filtros JWT.
- `backend/src/main/java/bo/ciomed/medozone/config/WebConfig.java` — Lista de orígenes permitidos en desarrollo web.
- `backend/src/main/java/bo/ciomed/medozone/facturacion/FacturacionController.java` — Facturas, pagos parciales y saldo pendiente.
- `backend/src/main/java/bo/ciomed/medozone/pacientes/PacienteController.java` — CRUD básico, consulta y búsqueda de pacientes.
- `backend/src/main/java/bo/ciomed/medozone/reportes/ReporteController.java` — Indicadores agregados del día.
- `backend/src/main/java/bo/ciomed/medozone/security/JwtAuthenticationFilter.java` — Lee Bearer token y crea el contexto de seguridad.
- `backend/src/main/java/bo/ciomed/medozone/security/JwtService.java` — Emisión y validación de tokens JWT.
- `backend/src/main/java/bo/ciomed/medozone/seed/DemoDataInitializer.java` — Crea cuentas de demostración solo con perfil dev.
- `backend/src/main/resources/application.yml` — Configuración externa de API, BD, CORS, Flyway, JWT y zona horaria.
- `backend/src/main/resources/db/migration/V1__schema_inicial.sql` — Tablas, índices, restricciones y protección de solapamientos en PostgreSQL.
- `compose.yaml` — Levanta PostgreSQL y el backend Spring Boot con Docker Compose.
- `docs/PRUEBAS_MVP.md` — Casos funcionales de aceptación y red.
- `mobile/lib/core/api_client.dart` — Cliente REST, token seguro, headers y manejo de errores.
- `mobile/lib/main.dart` — Punto de entrada y restauración/validación de sesión.
- `mobile/lib/screens/appointment_form_screen.dart` — Formulario de reserva.
- `mobile/lib/screens/appointments_screen.dart` — Listado de agenda y acciones de citas.
- `mobile/lib/screens/billing_screen.dart` — Facturas, pagos y saldos.
- `mobile/lib/screens/home_screen.dart` — Menú principal y tarjetas por rol.
- `mobile/lib/screens/login_screen.dart` — Pantalla de acceso CIOMED.
- `mobile/lib/screens/patient_form_screen.dart` — Formulario de alta y edición de paciente.
- `mobile/lib/screens/patients_screen.dart` — Listado y búsqueda de pacientes.
- `mobile/lib/screens/reports_screen.dart` — Resumen administrativo.
- `mobile/lib/screens/session_form_screen.dart` — Formulario de registro clínico manual.
- `mobile/lib/screens/sessions_screen.dart` — Historial de sesiones.
- `mobile/lib/screens/settings_screen.dart` — Datos de cuenta, información y cierre de sesión.
- `mobile/pubspec.yaml` — Nombre de la app y dependencias Flutter.
- `scripts/build.ps1` — Compila paquetes release desde PowerShell.
- `scripts/build.sh` — Compila APK, AAB, iOS, web o desktop con URL HTTPS.
- `scripts/configure_flutter_platforms.py` — Aplica permisos locales de Android/iOS y título web.
- `scripts/prepare-flutter.ps1` — Genera wrappers nativos Flutter para seis targets desde PowerShell.
- `scripts/prepare-flutter.sh` — Genera wrappers nativos Flutter para seis targets desde Linux/macOS.
- `scripts/run.ps1` — Levanta Docker y ejecuta un target Flutter desde PowerShell.
- `scripts/run.sh` — Levanta Docker y ejecuta un target Flutter desde Bash.
- `scripts/smoke-test.ps1` — Prueba health, login y perfil JWT desde PowerShell.
- `scripts/smoke-test.sh` — Prueba health, login y perfil JWT desde Bash.
- `scripts/stop.ps1` — Detiene contenedores Docker desde PowerShell.
- `scripts/stop.sh` — Detiene contenedores Docker sin eliminar el volumen.

## Recursos visuales
La carpeta `docs/prototipos/` contiene las siete imágenes de referencia del PDF: login, menú principal, pacientes, agenda, seguimiento clínico, facturación y reportes. La app Flutter reconstruye las pantallas usando widgets; no utiliza las capturas como interfaz.
