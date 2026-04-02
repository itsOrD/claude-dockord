#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck disable=SC1091
source "$ROOT_DIR/tests/helpers.sh"

OUTPUT="$(printf '\n' | bash -lc "source '$ROOT_DIR/lib/ui.sh'; read_with_default 'Prompt: ' 'fallback'" 2>/dev/null)"
assert_equals "fallback" "$OUTPUT" "read_with_default should return only the captured value"

echo "ui_test.sh: PASS"
