#!/bin/bash
# PostToolUse hook — fires after Write/Edit/MultiEdit
# Enforces git commit discipline and README awareness.
# Outputs advisory messages (does not block).

set -euo pipefail

INPUT="$(cat)"

FILE="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)"
[ -z "$FILE" ] && exit 0

git rev-parse --is-inside-work-tree &>/dev/null || exit 0

MESSAGES=""

# ── Git Commit Discipline ─────────────────────────────────────────
CHANGED=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
STAGED=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
TOTAL=$((CHANGED + STAGED))

if [ "$TOTAL" -ge 6 ]; then
    MESSAGES="$TOTAL uncommitted file changes. Commit a vertical slice now."
fi

# ── README Awareness ──────────────────────────────────────────────
case "$FILE" in
    *.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.rs|*.java|*.rb|*.swift|*.kt|*.sh)
        README_TOUCHED=$(( \
            $(git diff --name-only 2>/dev/null | grep -c 'README' || true) + \
            $(git diff --cached --name-only 2>/dev/null | grep -c 'README' || true) \
        ))
        if [ "$README_TOUCHED" -eq 0 ]; then
            REMIND_FILE="/tmp/.claude-readme-remind"
            if [ ! -f "$REMIND_FILE" ] || [ -n "$(find "$REMIND_FILE" -mmin +10 2>/dev/null)" ]; then
                if [ -n "$MESSAGES" ]; then
                    MESSAGES="$MESSAGES Also: source files changed but README.md not updated."
                else
                    MESSAGES="Source files changed but README.md has not been updated."
                fi
                touch "$REMIND_FILE"
            fi
        fi
        ;;
esac

# ── Output ────────────────────────────────────────────────────────
if [ -n "$MESSAGES" ]; then
    jq -n --arg msg "$MESSAGES" '{"message": $msg}'
fi

exit 0
