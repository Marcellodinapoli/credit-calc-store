#!/usr/bin/env bash
set -euo pipefail

flutter pub get
(
  cd packages/credit_calc_core
  flutter pub get
)

if [ ! -f web/index.html ]; then
  flutter create --platforms=web .
fi

flutter build web --release
