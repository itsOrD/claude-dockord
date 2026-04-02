#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/claude-dockord-home.XXXXXX")"
trap 'rm -rf "$TEST_HOME"' EXIT

export HOME="$TEST_HOME"
export COMPOSE_PROJECT_NAME="claude-dockord"

# shellcheck disable=SC1091
source "$ROOT_DIR/tests/helpers.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/session.sh"

TASK_PROMPT="Implement the onboarding flow."
NO_SOURCE_PROMPT="$(build_initial_prompt "$TASK_PROMPT" "")"
assert_equals "$TASK_PROMPT" "$NO_SOURCE_PROMPT" "Prompt without sources should be unchanged"

WITH_SOURCE_PROMPT="$(build_initial_prompt "$TASK_PROMPT" "- docs/spec.md")"
assert_contains "$WITH_SOURCE_PROMPT" "$TASK_PROMPT" "Prompt should keep the original task"
assert_contains "$WITH_SOURCE_PROMPT" "docs/spec.md" "Prompt should include source references"

SAFE_NAME="$(sanitize_log_filename "agent-activity.md")"
assert_equals "agent-activity.md" "$SAFE_NAME" "Basename log files should be allowed"

if sanitize_log_filename "../secrets.txt" >/dev/null 2>&1; then
    echo "ASSERTION FAILED: Path traversal should be rejected for log filenames" >&2
    exit 1
fi

ensure_state_dir
ensure_ssh_key

SSH_CMD="$(ssh_command 2233)"
assert_contains "$SSH_CMD" "2233" "SSH command should include the selected port"
assert_contains "$SSH_CMD" "$SSH_KEY_PATH" "SSH command should include the generated key path"

ATTACH_CMD="$(ssh_attach_command 2233)"
assert_contains "$ATTACH_CMD" "tmux attach -t dockord" "Attach command should jump into the tmux session"

(
    port_is_in_use() {
        [ "$1" = "3000" ]
    }

    NEXT_PORT="$(pick_ssh_port 3000)"
    assert_equals "3001" "$NEXT_PORT" "pick_ssh_port should advance to the next free port"
)

if pick_ssh_port "abc" >/dev/null 2>&1; then
    echo "ASSERTION FAILED: Non-numeric SSH ports should be rejected" >&2
    exit 1
fi

if pick_ssh_port "70000" >/dev/null 2>&1; then
    echo "ASSERTION FAILED: SSH ports above 65535 should be rejected" >&2
    exit 1
fi

save_session_state "/tmp/project" "2233" "24g" "ralph"
load_session_state
assert_equals "/tmp/project" "$PROJECT_PATH" "Saved session state should restore the project path"
assert_equals "2233" "$SSH_PORT" "Saved session state should restore the SSH port"
assert_equals "24g" "$RAM" "Saved session state should restore RAM"
assert_equals "ralph" "$MODE" "Saved session state should restore mode"

if sanitize_log_filename $'activity\nlog.md' >/dev/null 2>&1; then
    echo "ASSERTION FAILED: Newlines should be rejected for log filenames" >&2
    exit 1
fi

if sanitize_log_filename "-activity.md" >/dev/null 2>&1; then
    echo "ASSERTION FAILED: Leading dashes should be rejected for log filenames" >&2
    exit 1
fi

echo "session_test.sh: PASS"
