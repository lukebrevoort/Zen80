#!/bin/sh
set -euo pipefail

# Keep this wrapper for local/legacy CI usage.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/ci_scripts/ci_pre_xcodebuild.sh"
