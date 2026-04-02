#!/bin/bash
set -e

# ── Onboarding Skip (always) ─────────────────────────────────────
if [ ! -f /home/claude/.claude.json ]; then
    echo '{ "hasCompletedOnboarding": true }' > /home/claude/.claude.json
fi

# ── OAuth Token (fallback for non-RC usage) ───────────────────────
if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    mkdir -p /home/claude/.claude
    if [ ! -f /home/claude/.claude/.credentials.json ]; then
        echo "{ \"claudeAiOauth\": { \"accessToken\": \"${CLAUDE_CODE_OAUTH_TOKEN}\" } }" \
            > /home/claude/.claude/.credentials.json
    fi
fi

# ── Template Initialization ───────────────────────────────────────
copy_template() {
    local src="/opt/templates/$1"
    local dst="/workspace/$1"
    if [ ! -f "$dst" ] && [ -f "$src" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        echo "[init] Copied $1"
        # Auto-gitignore ephemeral files (not CLAUDE.md or docs/ — those should be committed)
        if [ -d /workspace/.git ]; then
            case "$1" in
                CLAUDE.md|docs/*) ;;  # Don't gitignore these
                *)
                    grep -qxF "$1" /workspace/.gitignore 2>/dev/null || \
                        echo "$1" >> /workspace/.gitignore
                    ;;
            esac
        fi
    fi
}

copy_template "CLAUDE.md"
copy_template ".ralphrc"
copy_template "progress.txt"

for doc in /opt/templates/docs/*.md; do
    [ -f "$doc" ] && copy_template "docs/$(basename "$doc")"
done

# ── Hooks Setup ───────────────────────────────────────────────────
CLAUDE_DIR="/workspace/.claude"
mkdir -p "$CLAUDE_DIR/hooks"

# Install hook script if not present
if [ ! -f "$CLAUDE_DIR/hooks/post-tool-use.sh" ]; then
    cp /opt/templates/hooks/post-tool-use.sh "$CLAUDE_DIR/hooks/post-tool-use.sh"
    chmod +x "$CLAUDE_DIR/hooks/post-tool-use.sh"
    echo "[init] Installed postToolUse hook"
fi

# Merge hook config into settings.local.json (don't overwrite existing settings)
if [ -f "$CLAUDE_DIR/settings.local.json" ]; then
    # Only add hooks if not already present
    if ! jq -e '.hooks.PostToolUse' "$CLAUDE_DIR/settings.local.json" >/dev/null 2>&1; then
        jq '. + {"hooks":{"PostToolUse":[{"matcher":"^(Write|Edit|MultiEdit)$","command":".claude/hooks/post-tool-use.sh"}]}}' \
            "$CLAUDE_DIR/settings.local.json" > "$CLAUDE_DIR/settings.local.json.tmp" && \
            mv "$CLAUDE_DIR/settings.local.json.tmp" "$CLAUDE_DIR/settings.local.json"
        echo "[init] Added hooks to existing settings.local.json"
    fi
else
    cat > "$CLAUDE_DIR/settings.local.json" << 'SETTINGS'
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
SETTINGS
    echo "[init] Created settings.local.json with hooks"
fi

# ── Git Configuration ─────────────────────────────────────────────
git config --global --add safe.directory '*' 2>/dev/null || true
git config --global pull.rebase true 2>/dev/null || true

if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
    git config --global user.name "claude-agent"
    git config --global user.email "claude-agent@container"
fi

# ── Execute ───────────────────────────────────────────────────────
exec "$@"
