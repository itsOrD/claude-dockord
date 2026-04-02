#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

bash -n \
    "$ROOT_DIR/claude-dockord" \
    "$ROOT_DIR/lib/ui.sh" \
    "$ROOT_DIR/lib/auth.sh" \
    "$ROOT_DIR/lib/open-terminal.sh" \
    "$ROOT_DIR/lib/session.sh" \
    "$ROOT_DIR/entrypoint.sh" \
    "$ROOT_DIR/scripts/launch-session.sh" \
    "$ROOT_DIR/templates/auto-restart.sh" \
    "$ROOT_DIR/templates/hooks/post-tool-use.sh"

bash "$ROOT_DIR/tests/session_test.sh"
bash "$ROOT_DIR/tests/auth_test.sh"
bash "$ROOT_DIR/tests/ui_test.sh"
bash "$ROOT_DIR/tests/cli_test.sh"

echo "run.sh: PASS"
