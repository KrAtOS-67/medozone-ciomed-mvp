param(
  [ValidateSet('android','chrome','web-server','windows','macos','linux','ios')][string]$Target = 'chrome',
  [string]$ApiUrl = ''
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Mobile = Join-Path $Root 'mobile'
if (-not (Test-Path (Join-Path $Root '.env'))) { Copy-Item (Join-Path $Root '.env.example') (Join-Path $Root '.env'); throw 'Se creó .env. Edita las contraseñas y JWT_SECRET_BASE64 antes de iniciar.' }
$EnvText = Get-Content (Join-Path $Root '.env') -Raw
if ($EnvText -match 'REEMPLAZAR_POR_BASE64|CAMBIAR_POR') { throw 'Edita .env y reemplaza todos los valores de ejemplo.' }
$PlatformFolder = switch ($Target) {
  'android' { 'android' }
  { $_ -in @('chrome','web-server') } { 'web' }
  'windows' { 'windows' }
  'macos' { 'macos' }
  'ios' { 'ios' }
  'linux' { 'linux' }
}
if (-not (Test-Path (Join-Path $Mobile $PlatformFolder))) { & (Join-Path $PSScriptRoot 'prepare-flutter.ps1') }
if ($Target -eq 'ios' -and -not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) { throw 'El simulador/dispositivo iOS requiere macOS y Xcode.' }
if ($Target -eq 'macos' -and -not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) { throw 'macOS desktop requiere macOS.' }
Push-Location $Root
try { docker compose up -d --build; if ($LASTEXITCODE -ne 0) { throw 'Docker Compose no pudo levantar el backend.' } }
finally { Pop-Location }
if ([string]::IsNullOrWhiteSpace($ApiUrl)) {
  $ApiUrl = if ($Target -eq 'android') { 'http://10.0.2.2:8080/api' } else { 'http://localhost:8080/api' }
}
Push-Location $Mobile
try { flutter run -d $Target --dart-define="API_BASE_URL=$ApiUrl"; if ($LASTEXITCODE -ne 0) { throw 'flutter run terminó con errores.' } }
finally { Pop-Location }
