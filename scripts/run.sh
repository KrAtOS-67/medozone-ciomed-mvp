#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-chrome}"
API_URL="${2:-}"
if [[ ! -f "$ROOT/.env" ]]; then cp "$ROOT/.env.example" "$ROOT/.env"; echo "Se creó .env. Edita secretos antes de continuar."; exit 2; fi
if grep -q 'REEMPLAZAR_POR_BASE64' "$ROOT/.env" || grep -q 'CAMBIAR_POR' "$ROOT/.env"; then echo "Edita .env y reemplaza los valores de ejemplo antes de iniciar." >&2; exit 2; fi
case "$TARGET" in
  android) PLATFORM_DIR="android" ;;
  chrome|web-server) PLATFORM_DIR="web" ;;
  windows) PLATFORM_DIR="windows" ;;
  macos) PLATFORM_DIR="macos" ;;
  linux) PLATFORM_DIR="linux" ;;
  ios) PLATFORM_DIR="ios" ;;
  *) echo "Target no reconocido: $TARGET" >&2; exit 2 ;;
esac
if [[ ! -d "$ROOT/mobile/$PLATFORM_DIR" ]]; then "$ROOT/scripts/prepare-flutter.sh"; fi
if [[ "$TARGET" == "ios" && "$(uname -s)" != "Darwin" ]]; then echo "iOS requiere macOS y Xcode." >&2; exit 2; fi
if [[ "$TARGET" == "macos" && "$(uname -s)" != "Darwin" ]]; then echo "macOS desktop requiere macOS." >&2; exit 2; fi
(cd "$ROOT" && docker compose up -d --build)
if [[ -z "$API_URL" ]]; then
  case "$TARGET" in
    android) API_URL="http://10.0.2.2:8080/api" ;;
    *) API_URL="http://localhost:8080/api" ;;
  esac
fi
cd "$ROOT/mobile"
flutter run -d "$TARGET" --dart-define="API_BASE_URL=$API_URL"
