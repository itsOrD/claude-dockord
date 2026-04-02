#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/claude-dockord-cli-home.XXXXXX")"
trap 'rm -rf "$TEST_HOME"' EXIT

export HOME="$TEST_HOME"
export COMPOSE_PROJECT_NAME="claude-dockord"

# shellcheck disable=SC1091
source "$ROOT_DIR/tests/helpers.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/claude-dockord"

parse_run_flags --task "implement tests" --source "docs/spec.md" --ralph-iter 7 --ssh-port 2300 --rc --no-open
assert_equals "task" "$MODE" "Task mode should be selected when --task is supplied"
assert_equals "implement tests" "$TASK" "Task text should be captured from --task"
assert_contains "$SOURCES" "docs/spec.md" "Source references should be appended"
assert_equals "7" "$MAX_ITER" "Ralph iteration override should be captured"
assert_equals "2300" "$REQUESTED_SSH_PORT" "Requested SSH port should be captured"
assert_equals "false" "$OPEN_TERMINAL" "--no-open should disable auto-open"
assert_equals "1" "$SHOW_RC_HINT" "--rc should enable the RC hint"

if (parse_run_flags --task "a" --ralph "b") >/dev/null 2>&1; then
    echo "ASSERTION FAILED: Conflicting run mode options should fail" >&2
    exit 1
fi

if (parse_run_flags --ram) >/dev/null 2>&1; then
    echo "ASSERTION FAILED: Missing flag value should fail" >&2
    exit 1
fi

if (parse_run_flags --task "a" --ralph-iter "zero") >/dev/null 2>&1; then
    echo "ASSERTION FAILED: Non-numeric --ralph-iter should fail" >&2
    exit 1
fi

if (parse_run_flags --task "a" --ralph-iter "0") >/dev/null 2>&1; then
    echo "ASSERTION FAILED: Non-positive --ralph-iter should fail" >&2
    exit 1
fi

if (parse_run_flags --task "a" --ssh-port "70000") >/dev/null 2>&1; then
    echo "ASSERTION FAILED: SSH ports above 65535 should fail" >&2
    exit 1
fi

if (parse_run_flags --task "a" --ssh-port "port") >/dev/null 2>&1; then
    echo "ASSERTION FAILED: Non-numeric --ssh-port should fail" >&2
    exit 1
fi

echo "cli_test.sh: PASS"
