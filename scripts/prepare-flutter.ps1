$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Mobile = Join-Path $Root 'mobile'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'No se encontró Flutter en PATH.' }
if (-not (Get-Command python -ErrorAction SilentlyContinue) -and -not (Get-Command python3 -ErrorAction SilentlyContinue)) { throw 'Se necesita Python 3 para ajustar los manifiestos de desarrollo.' }
$Python = if (Get-Command python -ErrorAction SilentlyContinue) { 'python' } else { 'python3' }
$Temp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $Temp | Out-Null
try {
  flutter create --platforms=android,ios,web,windows,macos,linux --org bo.ciomed --project-name medozone_ciomed (Join-Path $Temp 'scaffold')
  if ($LASTEXITCODE -ne 0) { throw 'flutter create falló.' }
  foreach ($Platform in @('android','ios','web','windows','macos','linux')) {
    $Destination = Join-Path $Mobile $Platform
    if (Test-Path $Destination) { Remove-Item $Destination -Recurse -Force }
    Copy-Item (Join-Path (Join-Path $Temp 'scaffold') $Platform) $Destination -Recurse
  }
  Copy-Item (Join-Path (Join-Path $Temp 'scaffold') '.metadata') $Mobile -Force
  Copy-Item (Join-Path (Join-Path $Temp 'scaffold') 'analysis_options.yaml') $Mobile -Force
  & $Python (Join-Path $Root 'scripts/configure_flutter_platforms.py') $Mobile
  if ($LASTEXITCODE -ne 0) { throw 'No se pudieron ajustar los archivos de plataforma.' }
  Push-Location $Mobile
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get falló.' }
  Pop-Location
  Write-Host "Plataformas Flutter preparadas en $Mobile"
} finally { Remove-Item $Temp -Recurse -Force -ErrorAction SilentlyContinue }
