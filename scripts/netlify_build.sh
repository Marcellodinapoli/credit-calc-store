#!/usr/bin/env bash
# Build Flutter Web per Netlify (Linux) o GitHub Actions.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
CACHE_ROOT="${NETLIFY_BUILD_CACHE:-${NETLIFY_BUILD_BASE:-$HOME}/.netlify_cache}"
FLUTTER_DIR="${CACHE_ROOT}/flutter"
export PUB_CACHE="${CACHE_ROOT}/pub-cache"

echo "==> Netlify build CreditPlanet (Flutter web)"
echo "    Root: $ROOT"
echo "    Channel: $FLUTTER_CHANNEL"

if command -v flutter >/dev/null 2>&1; then
  echo "==> Flutter già in PATH"
else
  if [[ ! -f "$FLUTTER_DIR/bin/flutter" ]]; then
    echo "==> Install Flutter ($FLUTTER_CHANNEL)..."
    rm -rf "$FLUTTER_DIR"
    git clone https://github.com/flutter/flutter.git -b "$FLUTTER_CHANNEL" --depth 1 "$FLUTTER_DIR"
  fi
  export PATH="$FLUTTER_DIR/bin:$PATH"
fi

flutter --version
flutter config --enable-web --no-analytics
flutter precache --web
flutter pub get

if [[ -d packages/credit_calc_core ]]; then
  (
    cd packages/credit_calc_core
    flutter pub get
  )
fi

if [[ ! -f web/index.html ]]; then
  flutter create --platforms=web .
fi

flutter build web --release

if [[ ! -f build/web/index.html ]]; then
  echo "ERRORE: build/web/index.html mancante"
  exit 1
fi

echo "==> Build OK: $ROOT/build/web"
