#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck disable=SC1091
source "$ROOT_DIR/tests/helpers.sh"

info() { :; }
container_tty_shell_as_claude() {
    CAPTURED_AUTH_COMMAND="$1"
}

# shellcheck disable=SC1091
source "$ROOT_DIR/lib/auth.sh"

run_claude_subscription_auth
assert_equals "claude auth login --claudeai" "$CAPTURED_AUTH_COMMAND" \
    "Auth flow should delegate to Claude Code's Claude Max login command"

echo "auth_test.sh: PASS"
