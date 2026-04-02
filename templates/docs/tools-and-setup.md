# Tools & Setup Reference

## Tool Installation

Install whatever you need. No restrictions. Log installations in your activity log.

- **MCP servers**: `claude mcp add <n> -- <command>`
- **Node tools**: `npm install -g <package>`
- **Python tools**: `pip install --break-system-packages <package>`
- **System packages**: `sudo apt-get update && sudo apt-get install -y <package>`

### Recommended MCP Servers

- **context7** — Up-to-date library docs:
  `claude mcp add -s user --transport http context7 https://mcp.context7.com/mcp`
- **github** — Repo access:
  `claude mcp add github -- docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN ghcr.io/github/github-mcp-server`

## Remote Control (phone/tablet access)

Requires full OAuth auth (not token-based). Run `claude auth login` first.

```bash
# From within a session:
/rc

# Or start with RC enabled:
claude remote-control
```

Scan the QR code with the Claude mobile app or open the URL in a browser.
Your local files and MCP servers stay on the container — only chat messages
flow through the encrypted bridge.

Constraints: one session at a time, terminal must stay open, ~10 min network
timeout disconnects the session.

## Host Access

This container is meant to stay up between sessions.

- SSH in from the host with the command printed by `claude-dockord run`
- Default tmux session name: `dockord`
- Reattach after SSH with:

```bash
tmux attach -t dockord || zsh -l
```

## Monitoring

Token usage monitoring via ccusage (pre-installed):

```bash
ccusage blocks --live          # Real-time 5-hour billing window
ccusage daily                  # Daily breakdown
ccusage daily --breakdown      # Per-model cost breakdown
ccusage monthly                # Monthly aggregation
```

Run `ccusage blocks --live` in a tmux pane alongside your work session.

## Security Note

When adding MCP servers, prefer HTTPS transport URLs. HTTP connections
transmit data unencrypted and are vulnerable to interception.
