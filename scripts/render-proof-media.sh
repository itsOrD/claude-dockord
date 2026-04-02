#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROOFS_DIR="$ROOT_DIR/proofs"
TRANSCRIPTS_DIR="$PROOFS_DIR/transcripts"
FONT_FILE="${FONT_FILE:-/System/Library/Fonts/Menlo.ttc}"
CANVAS_SIZE="${CANVAS_SIZE:-1600x900}"

render_terminal_png() {
    local title="${1:?title is required}"
    local transcript_path="${2:?transcript path is required}"
    local output_path="${3:?output path is required}"

    ffmpeg -y \
        -f lavfi -i "color=c=#0b1020:s=${CANVAS_SIZE}" \
        -vf "
drawbox=x=48:y=42:w=1504:h=816:color=#0f172a:t=fill,
drawbox=x=48:y=42:w=1504:h=72:color=#1e293b:t=fill,
drawbox=x=80:y=69:w=16:h=16:color=#ef4444:t=fill,
drawbox=x=108:y=69:w=16:h=16:color=#f59e0b:t=fill,
drawbox=x=136:y=69:w=16:h=16:color=#22c55e:t=fill,
drawtext=fontfile=${FONT_FILE}:text='${title}':x=192:y=61:fontsize=30:fontcolor=#f8fafc,
drawtext=fontfile=${FONT_FILE}:textfile=${transcript_path}:x=88:y=146:fontsize=25:fontcolor=#dbe4ee:line_spacing=10
" \
        -frames:v 1 \
        "$output_path" >/dev/null 2>&1
}

render_gif() {
    local frames_manifest

    frames_manifest="$(mktemp "${TMPDIR:-/tmp}/claude-dockord-proof-frames.XXXXXX")"
    cat > "$frames_manifest" <<EOF
file '$PROOFS_DIR/idle-flow.png'
duration 2.2
file '$PROOFS_DIR/oauth-browser-launch.png'
duration 2.2
file '$PROOFS_DIR/ssh-workspace.png'
duration 2.6
file '$PROOFS_DIR/ssh-workspace.png'
EOF

    ffmpeg -y \
        -f concat -safe 0 -i "$frames_manifest" \
        -vf "fps=12,scale=1200:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
        "$PROOFS_DIR/dockord-proof.gif" >/dev/null 2>&1

    rm -f "$frames_manifest"
}

mkdir -p "$PROOFS_DIR"

render_terminal_png "Idle Container Boot" \
    "$TRANSCRIPTS_DIR/idle-flow.txt" \
    "$PROOFS_DIR/idle-flow.png"

render_terminal_png "Claude Max Login Flow" \
    "$TRANSCRIPTS_DIR/oauth-browser-launch.txt" \
    "$PROOFS_DIR/oauth-browser-launch.png"

render_terminal_png "SSH Workspace Reentry" \
    "$TRANSCRIPTS_DIR/ssh-workspace.txt" \
    "$PROOFS_DIR/ssh-workspace.png"

render_gif

echo "Rendered proof media in $PROOFS_DIR"
