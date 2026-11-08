#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-android-apk}"
API_URL="${2:-}"
if [[ -z "$API_URL" || "$API_URL" != https://* ]]; then
  echo "Indica una URL HTTPS de tu backend para crear un build release." >&2
  echo "Ejemplo: ./scripts/build.sh android-apk https://api.ejemplo.bo/api" >&2
  exit 2
fi
case "$TARGET" in
  android-apk|android-aab) PLATFORM_DIR="android" ;;
  ios) PLATFORM_DIR="ios" ;;
  web) PLATFORM_DIR="web" ;;
  windows) PLATFORM_DIR="windows" ;;
  macos) PLATFORM_DIR="macos" ;;
  linux) PLATFORM_DIR="linux" ;;
  *) echo "Target no reconocido: $TARGET" >&2; exit 2 ;;
esac
if [[ ! -d "$ROOT/mobile/$PLATFORM_DIR" ]]; then "$ROOT/scripts/prepare-flutter.sh"; fi
cd "$ROOT/mobile"
case "$TARGET" in
  android-apk) flutter build apk --release --dart-define="API_BASE_URL=$API_URL" ;;
  android-aab) flutter build appbundle --release --dart-define="API_BASE_URL=$API_URL" ;;
  ios) [[ "$(uname -s)" == "Darwin" ]] || { echo "iOS requiere macOS y Xcode." >&2; exit 2; }; flutter build ios --release --dart-define="API_BASE_URL=$API_URL" ;;
  web) flutter build web --release --dart-define="API_BASE_URL=$API_URL" ;;
  windows) flutter build windows --release --dart-define="API_BASE_URL=$API_URL" ;;
  macos) [[ "$(uname -s)" == "Darwin" ]] || { echo "macOS desktop requiere macOS." >&2; exit 2; }; flutter build macos --release --dart-define="API_BASE_URL=$API_URL" ;;
  linux) flutter build linux --release --dart-define="API_BASE_URL=$API_URL" ;;
  *) echo "Target no reconocido: $TARGET" >&2; exit 2 ;;
esac
