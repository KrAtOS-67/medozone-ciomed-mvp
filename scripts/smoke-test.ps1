$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$EnvMap = @{}
Get-Content (Join-Path $Root '.env') | ForEach-Object { if ($_ -match '^([^#=]+)=(.*)$') { $EnvMap[$matches[1]] = $matches[2] } }
$Base = if ($env:API_URL) { $env:API_URL } else { 'http://localhost:8080' }
$health = Invoke-RestMethod "$Base/actuator/health"
if ($health.status -ne 'UP') { throw 'El backend no está saludable.' }
$body = @{ usuario = 'admin'; contrasena = $EnvMap['MEDOZONE_DEMO_PASSWORD'] } | ConvertTo-Json
$login = Invoke-RestMethod "$Base/api/auth/login" -Method Post -ContentType 'application/json' -Body $body
$profile = Invoke-RestMethod "$Base/api/auth/me" -Headers @{ Authorization = "Bearer $($login.token)" }
if ($profile.rol -ne 'ADMIN') { throw 'El usuario inicial no tiene rol ADMIN.' }
Write-Host 'OK: health y login JWT responden correctamente.'
