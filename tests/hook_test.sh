#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_REPO="$(mktemp -d "${TMPDIR:-/tmp}/claude-dockord-hook-test.XXXXXX")"
trap 'rm -rf "$TMP_REPO"; rm -f "$REMINDER_FILE"' EXIT

HOOK_PATH="$ROOT_DIR/templates/hooks/post-tool-use.sh"
REMINDER_FILE="/tmp/.claude-readme-remind"

# shellcheck disable=SC1091
source "$ROOT_DIR/tests/helpers.sh"

rm -f "$REMINDER_FILE"

cd "$TMP_REPO"
git init >/dev/null 2>&1
git config user.name "tester"
git config user.email "tester@example.com"

cat > app.sh <<'EOF'
#!/bin/bash
echo "hello"
EOF

git add app.sh
git commit -m "init app script" >/dev/null 2>&1

echo "echo \"updated\"" >> app.sh
HOOK_OUTPUT="$(printf '{"tool_input":{"file_path":"app.sh"}}' | bash "$HOOK_PATH")"
assert_contains "$HOOK_OUTPUT" "README.md has not been updated." \
    "Shell source edits should trigger a README reminder"

cat > README.md <<'EOF'
# Test Repo
EOF

HOOK_OUTPUT_WITH_README="$(printf '{"tool_input":{"file_path":"app.sh"}}' | bash "$HOOK_PATH")"
assert_equals "" "$HOOK_OUTPUT_WITH_README" "README reminder should clear once README is modified"

NON_CODE_OUTPUT="$(printf '{"tool_input":{"file_path":"notes.txt"}}' | bash "$HOOK_PATH")"
assert_equals "" "$NON_CODE_OUTPUT" "Non-code file edits should not trigger README reminders"

echo "hook_test.sh: PASS"
