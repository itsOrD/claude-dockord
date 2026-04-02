#!/bin/bash

SESSION_NAME="${SESSION_NAME:-dockord}"
STATE_DIR="${CLAUDE_DOCKORD_STATE_DIR:-$HOME/.claude-dockord}"
SSH_KEY_PATH="${CLAUDE_DOCKORD_SSH_KEY_PATH:-$STATE_DIR/id_ed25519}"
KNOWN_HOSTS_PATH="${CLAUDE_DOCKORD_KNOWN_HOSTS_PATH:-$STATE_DIR/known_hosts}"
SESSION_STATE_PATH="${CLAUDE_DOCKORD_SESSION_STATE_PATH:-$STATE_DIR/current-session.env}"
DEFAULT_SSH_PORT="${CLAUDE_DOCKORD_DEFAULT_SSH_PORT:-2222}"
REQUEST_REMOTE_PATH="/tmp/claude-dockord/request.md"
CONTAINER_NAME="${COMPOSE_PROJECT_NAME:-claude-dockord}"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

docker_daemon_available() {
    docker info >/dev/null 2>&1
}

ensure_state_dir() {
    mkdir -p "$STATE_DIR"
    chmod 700 "$STATE_DIR"
    touch "$KNOWN_HOSTS_PATH"
    chmod 600 "$KNOWN_HOSTS_PATH"
}

ensure_host_dependencies() {
    local dependency

    for dependency in docker ssh-keygen; do
        if ! command_exists "$dependency"; then
            echo "Missing required host dependency: $dependency" >&2
            return 1
        fi
    done

    if ! docker_daemon_available; then
        echo "Cannot connect to the Docker daemon. Start Docker Desktop or your Docker service first." >&2
        return 1
    fi
}

resolve_project_path() {
    local project_path="${1:?project path is required}"

    project_path="${project_path/#\~/$HOME}"

    if [ ! -d "$project_path" ]; then
        echo "$project_path is not a directory." >&2
        return 1
    fi

    (
        cd "$project_path" >/dev/null 2>&1
        pwd
    )
}

ensure_ssh_key() {
    if [ ! -f "$SSH_KEY_PATH" ]; then
        ssh-keygen -q -t ed25519 -N "" -f "$SSH_KEY_PATH" >/dev/null
    fi

    chmod 600 "$SSH_KEY_PATH"
    chmod 644 "$SSH_KEY_PATH.pub"
}

ssh_public_key_contents() {
    cat "$SSH_KEY_PATH.pub"
}

port_is_in_use() {
    local port="${1:?port is required}"

    if command_exists nc; then
        nc -z 127.0.0.1 "$port" >/dev/null 2>&1
        return
    fi

    if command_exists lsof; then
        lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
        return
    fi

    return 1
}

pick_ssh_port() {
    local requested_port="${1-}"
    local candidate="${requested_port:-$DEFAULT_SSH_PORT}"
    local attempts=0

    while port_is_in_use "$candidate"; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 50 ]; then
            echo "Unable to find a free SSH port near ${requested_port:-$DEFAULT_SSH_PORT}." >&2
            return 1
        fi
        candidate=$((candidate + 1))
    done

    printf '%s' "$candidate"
}

export_compose_environment() {
    local project_path="${1:?project path is required}"
    local ram="${2:?ram is required}"
    local ssh_port="${3:?ssh port is required}"

    export HOST_WORKSPACE_PATH="$project_path"
    export MEMORY_LIMIT="$ram"
    export SSH_PORT="$ssh_port"
    export SSH_PUBLIC_KEY
    SSH_PUBLIC_KEY="$(ssh_public_key_contents)"
}

docker_compose_up() {
    docker compose up -d --build --remove-orphans
}

container_is_running() {
    [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || true)" = "true" ]
}

wait_for_container() {
    local attempts=0

    until container_is_running; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 30 ]; then
            echo "Container ${CONTAINER_NAME} did not become ready." >&2
            return 1
        fi
        sleep 1
    done
}

wait_for_ssh() {
    local ssh_port="${1:?ssh port is required}"
    local attempts=0

    until port_is_in_use "$ssh_port"; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 30 ]; then
            echo "SSH on port ${ssh_port} did not become ready." >&2
            return 1
        fi
        sleep 1
    done
}

container_exec() {
    docker exec "$CONTAINER_NAME" "$@"
}

container_exec_as_claude() {
    docker exec --user claude --workdir /workspace -e HOME=/home/claude "$CONTAINER_NAME" "$@"
}

container_shell_as_claude() {
    local shell_command="${1:?shell command is required}"
    container_exec_as_claude bash -lc "$shell_command"
}

container_tty_shell_as_claude() {
    local shell_command="${1:?shell command is required}"
    docker exec -it --user claude --workdir /workspace -e HOME=/home/claude "$CONTAINER_NAME" bash -lc "$shell_command"
}

container_has_claude_auth() {
    container_shell_as_claude 'test -f /home/claude/.claude/.credentials.json'
}

ensure_ralph_plugin() {
    container_exec_as_claude claude --dangerously-skip-permissions -p \
        '/plugin install ralph-wiggum@claude-plugins-official' >/dev/null 2>&1
}

build_initial_prompt() {
    local task="${1:-}"
    local sources="${2:-}"

    if [ -z "$sources" ]; then
        printf '%s' "$task"
        return
    fi

    cat <<EOF
$task

Before changing code, review the following context if it is relevant:
$sources
EOF
}

copy_request_to_container() {
    local request="${1:?request content is required}"
    local tmp_file

    tmp_file="$(mktemp "${TMPDIR:-/tmp}/claude-dockord-request.XXXXXX")"
    printf '%s\n' "$request" > "$tmp_file"

    container_exec mkdir -p /tmp/claude-dockord
    docker cp "$tmp_file" "$CONTAINER_NAME:$REQUEST_REMOTE_PATH" >/dev/null

    rm -f "$tmp_file"
}

build_tmux_launch_command() {
    local mode="${1:?mode is required}"
    local max_iterations="${2:?max iterations are required}"
    local command_parts

    command_parts=(/usr/local/bin/claude-dockord-launch-session "$mode" "$REQUEST_REMOTE_PATH" "$max_iterations")
    printf '%q ' "${command_parts[@]}"
}

launch_mode_session() {
    local mode="${1:?mode is required}"
    local request="${2:-}"
    local max_iterations="${3:-30}"
    local launch_command

    if [ -n "$request" ]; then
        copy_request_to_container "$request"
    else
        container_exec rm -f "$REQUEST_REMOTE_PATH" >/dev/null 2>&1 || true
    fi

    container_exec_as_claude tmux kill-session -t "$SESSION_NAME" >/dev/null 2>&1 || true

    launch_command="$(build_tmux_launch_command "$mode" "$max_iterations")"
    container_exec_as_claude tmux new-session -d -s "$SESSION_NAME" "$launch_command"
}

ssh_command() {
    local ssh_port="${1:?ssh port is required}"

    printf 'ssh -i %q -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=%q -p %q claude@127.0.0.1' \
        "$SSH_KEY_PATH" "$KNOWN_HOSTS_PATH" "$ssh_port"
}

ssh_attach_command() {
    local ssh_port="${1:?ssh port is required}"
    local base_command

    base_command="$(ssh_command "$ssh_port")"
    printf "%s -t 'tmux attach -t %s || exec zsh -l'" "$base_command" "$SESSION_NAME"
}

save_session_state() {
    local project_path="${1:?project path is required}"
    local ssh_port="${2:?ssh port is required}"
    local ram="${3:?ram is required}"
    local mode="${4:?mode is required}"

    {
        printf 'PROJECT_PATH=%q\n' "$project_path"
        printf 'SSH_PORT=%q\n' "$ssh_port"
        printf 'RAM=%q\n' "$ram"
        printf 'MODE=%q\n' "$mode"
    } > "$SESSION_STATE_PATH"
}

load_session_state() {
    if [ -f "$SESSION_STATE_PATH" ]; then
        # shellcheck disable=SC1090
        source "$SESSION_STATE_PATH"
        return 0
    fi

    return 1
}

sanitize_log_filename() {
    local file_name="${1:-}"

    case "$file_name" in
        ""|*/*|*..*)
            return 1
            ;;
        *)
            printf '%s' "$file_name"
            ;;
    esac
}
