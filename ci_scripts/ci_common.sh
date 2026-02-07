#!/bin/sh
set -euo pipefail

ensure_flutter() {
  if command -v flutter >/dev/null 2>&1; then
    FLUTTER_BIN="$(command -v flutter)"
    return 0
  fi

  for candidate in \
    "${FLUTTER_ROOT:-}/bin/flutter" \
    "$HOME/flutter/bin/flutter" \
    "$HOME/development/flutter/bin/flutter" \
    "/Volumes/workspace/flutter/bin/flutter" \
    "/opt/flutter/bin/flutter" \
    "/usr/local/bin/flutter"
  do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      FLUTTER_BIN="$candidate"
      export PATH="$(dirname "$FLUTTER_BIN"):$PATH"
      return 0
    fi
  done

  FLUTTER_SDK_DIR="${CI_FLUTTER_SDK_DIR:-$HOME/flutter}"
  echo "==> Flutter not found on PATH; bootstrapping SDK at $FLUTTER_SDK_DIR"

  if [ ! -x "$FLUTTER_SDK_DIR/bin/flutter" ]; then
    rm -rf "$FLUTTER_SDK_DIR"
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_SDK_DIR"
  fi

  FLUTTER_BIN="$FLUTTER_SDK_DIR/bin/flutter"
  export PATH="$FLUTTER_SDK_DIR/bin:$PATH"
}
