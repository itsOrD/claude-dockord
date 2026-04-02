#!/bin/bash

set -euo pipefail

run_as_claude() {
    sudo -u claude -H "$@"
}

ensure_workspace_path_owner() {
    local path="${1:?path is required}"
    chown claude:claude "$path" >/dev/null 2>&1 || true
}

copy_template() {
    local relative_path="${1:?template path is required}"
    local source_path="/opt/templates/$relative_path"
    local destination_path="/workspace/$relative_path"
    local destination_dir

    if [ ! -f "$source_path" ] || [ -f "$destination_path" ]; then
        return 0
    fi

    destination_dir="$(dirname "$destination_path")"
    mkdir -p "$destination_dir"
    ensure_workspace_path_owner "$destination_dir"

    cp "$source_path" "$destination_path"
    ensure_workspace_path_owner "$destination_path"
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
    ensure_workspace_path_owner "$claude_dir"
    ensure_workspace_path_owner "$claude_dir/hooks"

    if [ ! -f "$claude_dir/hooks/post-tool-use.sh" ]; then
        cp /opt/templates/hooks/post-tool-use.sh "$claude_dir/hooks/post-tool-use.sh"
        ensure_workspace_path_owner "$claude_dir/hooks/post-tool-use.sh"
        chmod +x "$claude_dir/hooks/post-tool-use.sh"
        echo "[init] Installed postToolUse hook"
    fi

    if [ -f "$settings_path" ]; then
        if ! jq -e . "$settings_path" >/dev/null 2>&1; then
            echo "[init] Skipping hook merge: $settings_path is not valid JSON"
            return 0
        fi

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
            ensure_workspace_path_owner "$settings_path"
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
    ensure_workspace_path_owner "$settings_path"
    echo "[init] Created settings.local.json with hooks"
}

remove_wildcard_safe_directory() {
    local existing_entries

    existing_entries="$(run_as_claude git config --global --get-all safe.directory 2>/dev/null || true)"
    if printf '%s\n' "$existing_entries" | grep -qxF '*'; then
        run_as_claude git config --global --unset-all safe.directory >/dev/null 2>&1 || true
    fi
}

ensure_safe_directory() {
    local path="${1:?path is required}"
    local existing_entries

    existing_entries="$(run_as_claude git config --global --get-all safe.directory 2>/dev/null || true)"
    if printf '%s\n' "$existing_entries" | grep -qxF "$path"; then
        return 0
    fi

    run_as_claude git config --global --add safe.directory "$path" >/dev/null 2>&1 || true
}

configure_git() {
    remove_wildcard_safe_directory
    ensure_safe_directory "/workspace"
    ensure_safe_directory "/worktrees"
    run_as_claude git config --global pull.rebase true >/dev/null 2>&1 || true

    if [ -z "$(run_as_claude git config --global user.name 2>/dev/null || true)" ]; then
        run_as_claude git config --global user.name "claude-agent"
        run_as_claude git config --global user.email "claude-agent@container"
    fi
}

unlock_ssh_user() {
    # Debian locks newly created accounts by default, which blocks sshd before pubkey auth.
    passwd -d claude >/dev/null 2>&1 || true
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
Port 2222
ListenAddress 0.0.0.0
Protocol 2
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM no
PubkeyAuthentication yes
AuthenticationMethods publickey
AuthorizedKeysFile .ssh/authorized_keys
PermitRootLogin no
PermitEmptyPasswords no
PermitUserEnvironment no
AllowUsers claude
AllowAgentForwarding no
X11Forwarding no
GatewayPorts no
AllowTcpForwarding no
PermitTunnel no
UseDNS no
PrintMotd no
PidFile /var/run/sshd.pid
Subsystem sftp internal-sftp
EOF
}

main() {
    ensure_onboarding_skip
    install_workspace_templates
    configure_hooks
    configure_git
    unlock_ssh_user
    configure_ssh

    exec "$@"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
