#!/bin/bash

if [ -t 1 ]; then
    B='\033[1m'
    D='\033[2m'
    C='\033[0;36m'
    G='\033[0;32m'
    Y='\033[0;33m'
    R='\033[0;31m'
    N='\033[0m'
else
    B=''
    D=''
    C=''
    G=''
    Y=''
    R=''
    N=''
fi

banner() {
    echo ""
    echo -e "${B}┌──────────────────────────────────────────────┐${N}"
    echo -e "${B}│${C}    ╔═╗╦  ╔═╗╦ ╦╔╦╗╔═╗                       ${B}│${N}"
    echo -e "${B}│${C}    ║  ║  ╠═╣║ ║ ║║║╣    ${D}dockord${C}              ${B}│${N}"
    echo -e "${B}│${C}    ╚═╝╩═╝╩ ╩╚═╝═╩╝╚═╝                       ${B}│${N}"
    echo -e "${B}│${D}    Persistent Claude container orchestration ${B}│${N}"
    echo -e "${B}└──────────────────────────────────────────────┘${N}"
    echo ""
}

step()    { echo -e "  ${B}[$1]${N} $2"; }
ok()      { echo -e "       ${G}✓ $1${N}"; }
info()    { echo -e "       ${D}$1${N}"; }
warn()    { echo -e "       ${Y}⚠ $1${N}"; }
fail()    { echo -e "       ${R}✗ $1${N}"; }
prompt()  { echo -ne "  ${B}▸${N} $1"; }
divider() { echo -e "  ${D}────────────────────────────────────────${N}"; }

read_with_default() {
    local prompt_text="${1:?prompt text is required}"
    local default_value="${2-}"
    local input

    prompt "$prompt_text" >&2
    read -r input

    if [ -z "$input" ]; then
        printf '%s' "$default_value"
        return
    fi

    printf '%s' "$input"
}

is_yes() {
    case "${1:-}" in
        y|Y|yes|YES|"") return 0 ;;
        *) return 1 ;;
    esac
}

usage() {
    local app_name="${1:-claude-dockord}"

    banner
    cat <<EOF
  COMMANDS
    setup                       Build image, start container, authenticate Claude
    run <path> [options]        Start or refresh the persistent container for a project
    monitor                     Live token/session usage dashboard
    logs                        List agent activity logs
    log <filename>              Read a specific agent log
    export-logs                 Copy all logs to ./agent-logs-export/
    status                      Show running container state and SSH details
    attach                      Attach to the dockord tmux session
    teardown                    Stop the container, keep image and volumes
    nuke                        Remove the container, image, and named volumes

  RUN OPTIONS
    --ram <size>                Container memory limit (default: 16g)
    --task <prompt>             Fire-and-forget Claude prompt in tmux
    --ralph <prompt>            Ralph loop kickoff in tmux
    --ralph-iter <n>            Max Ralph iterations (default: 30)
    --agents <prompt>           Claude kickoff for multi-agent orchestration
    --auto <prompt>             Auto-restart Claude loop on rate limits
    --source <value>            Supporting path, URL, or note for the initial request
    --ssh-port <port>           Preferred localhost SSH port (default: 2222 or next free)
    --no-open                   Do not offer to open a new terminal automatically
    --rc                        Remind you to enable Remote Control after connecting

  EXAMPLES
    ${app_name} setup
    ${app_name} run ~/code/my-app
    ${app_name} run ~/code/my-app --ralph "implement JWT auth"
    ${app_name} run ~/code/my-app --task "triage failing tests" --source docs/spec.md
    ${app_name} monitor

EOF
}
