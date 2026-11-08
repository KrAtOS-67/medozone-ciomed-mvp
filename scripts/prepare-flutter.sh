#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/mobile"
command -v flutter >/dev/null || { echo "No se encontró Flutter en PATH" >&2; exit 1; }
command -v python3 >/dev/null || { echo "Se necesita Python 3 para ajustar los manifiestos de desarrollo" >&2; exit 1; }
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
flutter create --platforms=android,ios,web,windows,macos,linux --org bo.ciomed --project-name medozone_ciomed "$TEMP_DIR/scaffold"
for platform in android ios web windows macos linux; do
  rm -rf "$MOBILE/$platform"
  cp -R "$TEMP_DIR/scaffold/$platform" "$MOBILE/$platform"
done
cp "$TEMP_DIR/scaffold/.metadata" "$MOBILE/.metadata"
cp "$TEMP_DIR/scaffold/analysis_options.yaml" "$MOBILE/analysis_options.yaml"
python3 "$ROOT/scripts/configure_flutter_platforms.py" "$MOBILE"
(cd "$MOBILE" && flutter pub get)
echo "Plataformas Flutter preparadas en $MOBILE"
