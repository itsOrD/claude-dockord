#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/claude-dockord-entrypoint-home.XXXXXX")"
trap 'rm -rf "$TEST_HOME"' EXIT

export HOME="$TEST_HOME"

# shellcheck disable=SC1091
source "$ROOT_DIR/tests/helpers.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/entrypoint.sh"

run_as_claude() {
    "$@"
}

git config --global --add safe.directory '*'

configure_git

SAFE_DIRECTORIES="$(git config --global --get-all safe.directory 2>/dev/null || true)"
assert_contains "$SAFE_DIRECTORIES" "/workspace" "configure_git should trust /workspace"
assert_contains "$SAFE_DIRECTORIES" "/worktrees" "configure_git should trust /worktrees"

if printf '%s\n' "$SAFE_DIRECTORIES" | grep -qxF '*'; then
    echo "ASSERTION FAILED: configure_git should remove wildcard safe.directory entries" >&2
    exit 1
fi

WORKSPACE_COUNT="$(printf '%s\n' "$SAFE_DIRECTORIES" | grep -cx '/workspace' || true)"
WORKTREES_COUNT="$(printf '%s\n' "$SAFE_DIRECTORIES" | grep -cx '/worktrees' || true)"
assert_equals "1" "$WORKSPACE_COUNT" "configure_git should add /workspace exactly once"
assert_equals "1" "$WORKTREES_COUNT" "configure_git should add /worktrees exactly once"

echo "entrypoint_test.sh: PASS"
