#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a; source "$ROOT/.env"; set +a
BASE="${API_URL:-http://localhost:8080}"
curl --fail --silent "$BASE/actuator/health" | grep -q 'UP'
TOKEN="$(curl --fail --silent "$BASE/api/auth/login" -H 'Content-Type: application/json' -d "{\"usuario\":\"admin\",\"contrasena\":\"$MEDOZONE_DEMO_PASSWORD\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')"
curl --fail --silent "$BASE/api/auth/me" -H "Authorization: Bearer $TOKEN" | grep -q 'ADMIN'
echo 'OK: health y login JWT responden correctamente.'
