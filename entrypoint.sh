#!/bin/bash

set -euo pipefail

run_as_claude() {
    sudo -u claude -H "$@"
}

copy_template() {
    local relative_path="${1:?template path is required}"
    local source_path="/opt/templates/$relative_path"
    local destination_path="/workspace/$relative_path"

    if [ ! -f "$source_path" ] || [ -f "$destination_path" ]; then
        return 0
    fi

    mkdir -p "$(dirname "$destination_path")"
    cp "$source_path" "$destination_path"
    echo "[init] Copied $relative_path"

    if [ -d /workspace/.git ]; then
        case "$relative_path" in
            CLAUDE.md|docs/*) ;;
            *)
                grep -qxF "$relative_path" /workspace/.gitignore 2>/dev/null || \
                    echo "$relative_path" >> /workspace/.gitignore
                ;;
        esac
    fi
}

ensure_onboarding_skip() {
    if [ ! -f /home/claude/.claude.json ]; then
        printf '{ "hasCompletedOnboarding": true }\n' > /home/claude/.claude.json
        chown claude:claude /home/claude/.claude.json
        chmod 600 /home/claude/.claude.json
    fi
}

ensure_oauth_fallback() {
    if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ ! -f /home/claude/.claude/.credentials.json ]; then
        install -d -m 700 -o claude -g claude /home/claude/.claude
        umask 077
        printf '{ "claudeAiOauth": { "accessToken": "%s" } }\n' "$CLAUDE_CODE_OAUTH_TOKEN" \
            > /home/claude/.claude/.credentials.json
        chown claude:claude /home/claude/.claude/.credentials.json
    fi
}

install_workspace_templates() {
    copy_template "CLAUDE.md"
    copy_template ".ralphrc"
    copy_template "progress.txt"

    for document_path in /opt/templates/docs/*.md; do
        [ -f "$document_path" ] || continue
        copy_template "docs/$(basename "$document_path")"
    done
}

configure_hooks() {
    local claude_dir="/workspace/.claude"
    local settings_path="$claude_dir/settings.local.json"

    mkdir -p "$claude_dir/hooks"

    if [ ! -f "$claude_dir/hooks/post-tool-use.sh" ]; then
        cp /opt/templates/hooks/post-tool-use.sh "$claude_dir/hooks/post-tool-use.sh"
        chmod +x "$claude_dir/hooks/post-tool-use.sh"
        echo "[init] Installed postToolUse hook"
    fi

    if [ -f "$settings_path" ]; then
        if ! jq -e '.hooks.PostToolUse[]? | select(.command == ".claude/hooks/post-tool-use.sh")' \
            "$settings_path" >/dev/null 2>&1; then
            jq '
                .hooks = (.hooks // {}) |
                .hooks.PostToolUse = (
                    (.hooks.PostToolUse // []) + [
                        {
                            "matcher": "^(Write|Edit|MultiEdit)$",
                            "command": ".claude/hooks/post-tool-use.sh"
                        }
                    ]
                )
            ' "$settings_path" > "$settings_path.tmp"
            mv "$settings_path.tmp" "$settings_path"
            echo "[init] Added postToolUse hook to settings.local.json"
        fi
        return 0
    fi

    cat > "$settings_path" <<'EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "^(Write|Edit|MultiEdit)$",
        "command": ".claude/hooks/post-tool-use.sh"
      }
    ]
  }
}
EOF
    echo "[init] Created settings.local.json with hooks"
}

configure_git() {
    run_as_claude git config --global --add safe.directory '*' >/dev/null 2>&1 || true
    run_as_claude git config --global pull.rebase true >/dev/null 2>&1 || true

    if [ -z "$(run_as_claude git config --global user.name 2>/dev/null || true)" ]; then
        run_as_claude git config --global user.name "claude-agent"
        run_as_claude git config --global user.email "claude-agent@container"
    fi
}

configure_ssh() {
    install -d -m 700 -o claude -g claude /home/claude/.ssh

    if [ -n "${SSH_PUBLIC_KEY:-}" ]; then
        printf '%s\n' "$SSH_PUBLIC_KEY" > /home/claude/.ssh/authorized_keys
        chown claude:claude /home/claude/.ssh/authorized_keys
        chmod 600 /home/claude/.ssh/authorized_keys
    fi

    ssh-keygen -A >/dev/null 2>&1

    cat > /etc/ssh/claude-dockord_sshd_config <<EOF
Port ${SSH_PORT:-2222}
ListenAddress 0.0.0.0
Protocol 2
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitRootLogin no
AllowUsers claude
X11Forwarding no
AllowTcpForwarding no
PermitTunnel no
PrintMotd no
PidFile /var/run/sshd.pid
Subsystem sftp internal-sftp
EOF
}

ensure_onboarding_skip
ensure_oauth_fallback
install_workspace_templates
configure_hooks
configure_git
configure_ssh

exec "$@"
