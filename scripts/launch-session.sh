#!/bin/bash

set -euo pipefail

MODE="${1:-idle}"
REQUEST_FILE="${2:-}"
MAX_ITERATIONS="${3:-30}"

read_request() {
    if [ -n "$REQUEST_FILE" ] && [ -f "$REQUEST_FILE" ]; then
        cat "$REQUEST_FILE"
    fi
}

build_ralph_prompt() {
    local request

    request="$(tr '\n' ' ' < "$REQUEST_FILE" | tr -s '[:space:]' ' ')"
    request="${request//\"/\\\"}"
    printf '/ralph-loop:ralph-loop "%s" --max-iterations %s' "$request" "$MAX_ITERATIONS"
}

cd /workspace

case "$MODE" in
    idle)
        exec zsh -l
        ;;
    yolo)
        exec claude --dangerously-skip-permissions
        ;;
    task|agents)
        REQUEST_CONTENT="$(read_request)"
        [ -n "$REQUEST_CONTENT" ] || { echo "No request content was provided." >&2; exit 1; }
        exec claude --dangerously-skip-permissions -p "$REQUEST_CONTENT"
        ;;
    ralph)
        [ -n "$REQUEST_FILE" ] && [ -f "$REQUEST_FILE" ] || { echo "Missing Ralph request file." >&2; exit 1; }
        exec claude --dangerously-skip-permissions -p "$(build_ralph_prompt)"
        ;;
    auto)
        REQUEST_CONTENT="$(read_request)"
        [ -n "$REQUEST_CONTENT" ] || { echo "No auto-restart request content was provided." >&2; exit 1; }
        exec bash /opt/templates/auto-restart.sh "$REQUEST_CONTENT"
        ;;
    *)
        echo "Unsupported launch mode: $MODE" >&2
        exit 1
        ;;
esac
