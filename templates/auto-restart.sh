#!/bin/bash
# auto-restart.sh — Runs claude in a loop, auto-waits on rate limits, resumes.
# Usage: auto-restart.sh "your task description"

set -euo pipefail

TASK="${1:?Usage: auto-restart.sh \"task description\"}"
WAIT_MINUTES=30
MAX_RETRIES=10
RETRY=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Auto-Restart Mode"
echo "  Task: $TASK"
echo "  Will retry up to $MAX_RETRIES times on rate limits"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

while [ "$RETRY" -lt "$MAX_RETRIES" ]; do
    echo ""
    echo "[$(date '+%H:%M')] Starting claude session (attempt $((RETRY + 1))/$MAX_RETRIES)..."

    # Run claude, capture exit code
    set +e
    if [ "$RETRY" -eq 0 ]; then
        claude --dangerously-skip-permissions -p "$TASK" 2>&1 | tee /tmp/claude-session.log
    else
        # Resume previous session on retries
        claude --dangerously-skip-permissions --continue 2>&1 | tee /tmp/claude-session.log
    fi
    EXIT_CODE=$?
    set -e

    # Check if it was a rate limit
    if grep -qi "usage limit\|rate limit\|limit reached\|out of extra usage\|capacity" /tmp/claude-session.log 2>/dev/null; then
        RETRY=$((RETRY + 1))
        echo ""
        echo "[$(date '+%H:%M')] Rate limited. Waiting $WAIT_MINUTES minutes before retry..."
        echo "                   (attempt $RETRY/$MAX_RETRIES)"
        sleep $((WAIT_MINUTES * 60))
    elif [ "$EXIT_CODE" -eq 0 ]; then
        echo ""
        echo "[$(date '+%H:%M')] Session completed successfully."
        break
    else
        echo ""
        echo "[$(date '+%H:%M')] Session exited with code $EXIT_CODE."
        echo "                   Check /tmp/claude-session.log for details."
        break
    fi
done

if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
    echo ""
    echo "[$(date '+%H:%M')] Exhausted $MAX_RETRIES retries. Giving up."
    exit 1
fi
