#!/bin/bash

terminal_supports_auto_open() {
    case "$(uname -s)" in
        Darwin) command -v osascript >/dev/null 2>&1 ;;
        Linux)
            command -v x-terminal-emulator >/dev/null 2>&1 || \
                command -v gnome-terminal >/dev/null 2>&1 || \
                command -v konsole >/dev/null 2>&1
            ;;
        *) return 1 ;;
    esac
}

open_in_new_terminal() {
    local shell_command="${1:?shell command is required}"

    case "$(uname -s)" in
        Darwin)
            osascript <<EOF "$shell_command"
on run argv
    set commandText to item 1 of argv
    tell application "Terminal"
        activate
        do script commandText
    end tell
end run
EOF
            ;;
        Linux)
            if command -v x-terminal-emulator >/dev/null 2>&1; then
                x-terminal-emulator -e bash -lc "$shell_command" >/dev/null 2>&1 &
            elif command -v gnome-terminal >/dev/null 2>&1; then
                gnome-terminal -- bash -lc "$shell_command" >/dev/null 2>&1 &
            elif command -v konsole >/dev/null 2>&1; then
                konsole -e bash -lc "$shell_command" >/dev/null 2>&1 &
            else
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac
}
