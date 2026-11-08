$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $Root
try { docker compose down; if ($LASTEXITCODE -ne 0) { throw 'docker compose down falló.' } }
finally { Pop-Location }
