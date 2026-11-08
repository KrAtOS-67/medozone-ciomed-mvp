param(
  [ValidateSet('android-apk','android-aab','ios','web','windows','macos','linux')][string]$Target = 'android-apk',
  [Parameter(Mandatory=$true)][string]$ApiUrl
)
$ErrorActionPreference = 'Stop'
if (-not $ApiUrl.StartsWith('https://')) { throw 'Para compilar release debes indicar la URL HTTPS del backend.' }
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Mobile = Join-Path $Root 'mobile'
$PlatformFolder = switch ($Target) {
  { $_ -in @('android-apk','android-aab') } { 'android' }
  'ios' { 'ios' }
  'web' { 'web' }
  'windows' { 'windows' }
  'macos' { 'macos' }
  'linux' { 'linux' }
}
if (-not (Test-Path (Join-Path $Mobile $PlatformFolder))) { & (Join-Path $PSScriptRoot 'prepare-flutter.ps1') }
Push-Location $Mobile
try {
  switch ($Target) {
    'android-apk' { flutter build apk --release --dart-define="API_BASE_URL=$ApiUrl" }
    'android-aab' { flutter build appbundle --release --dart-define="API_BASE_URL=$ApiUrl" }
    'ios' { if (-not $IsMacOS) { throw 'iOS requiere macOS y Xcode.' }; flutter build ios --release --dart-define="API_BASE_URL=$ApiUrl" }
    'web' { flutter build web --release --dart-define="API_BASE_URL=$ApiUrl" }
    'windows' { flutter build windows --release --dart-define="API_BASE_URL=$ApiUrl" }
    'macos' { if (-not $IsMacOS) { throw 'macOS desktop requiere macOS.' }; flutter build macos --release --dart-define="API_BASE_URL=$ApiUrl" }
    'linux' { flutter build linux --release --dart-define="API_BASE_URL=$ApiUrl" }
  }
  if ($LASTEXITCODE -ne 0) { throw 'flutter build terminó con errores.' }
} finally { Pop-Location }
