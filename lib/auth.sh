#!/bin/bash

CLAUDE_AUTH_COMMAND="${CLAUDE_AUTH_COMMAND:-claude auth login --claudeai}"

run_claude_subscription_auth() {
    info "Claude Max login runs as the non-root 'claude' user inside the container."
    info "Complete the browser flow and paste the returned authentication code back into Claude Code when prompted."
    container_tty_shell_as_claude "$CLAUDE_AUTH_COMMAND"
}
