# claude-dockord

Autonomous multi-agent development environment for Claude Code. One command to launch containerized AI agents that plan, implement, test, review, and ship code — with git worktree isolation, ralph loops, token budget management, and phone-based monitoring.

Built for developers who want to delegate entire features to AI agents and check in from their phone.

## Quick Start

```bash
# One-time setup (builds image, authenticates, installs ralph plugin)
./claude-dockord setup

# Interactive — choose mode, provide task, launch
./claude-dockord run ~/code/my-app

# Or go direct with flags
./claude-dockord run ~/code/my-app --ralph "implement JWT auth with refresh tokens"

# Fire-and-forget with auto-restart on rate limits
./claude-dockord run ~/code/my-app --auto "implement JWT auth with refresh tokens and full test coverage"

# Autonomous ralph loop (iterates until done)
./claude-dockord run ~/code/my-app --ralph "migrate the database layer to SQLAlchemy"

# Multi-agent team
./claude-dockord run ~/code/my-app --agents "Spawn builder-api and builder-tests in separate worktrees, plus a reviewer for quality gate"

# Monitor token usage from another terminal
./claude-dockord monitor

# Check on agent activity
./claude-dockord logs
```

## What It Does

```
You run one command. Then:

1. Docker container spins up with Claude Code, tmux, and full toolchain
2. CLAUDE.md injects autonomous operating rules into every session
3. Agent writes a plan to /agent-logs/ before touching any code
4. Work happens on feature branches via git worktrees (parallel-safe)
5. Each commit is a vertical slice (independently revertable)
6. postToolUse hooks enforce commit discipline and README freshness
7. Token budget rules trigger compaction and graceful exit before limits hit
8. On rate limits, auto-restart waits and resumes with --continue
9. Pre-merge quality gate runs: code smells → simplify → security → tests → docs
10. ff-only rebase onto main. Feature branches preserved.
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Host Machine                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Docker Container (isolated, --dangerously-skip-perms)    │  │
│  │                                                           │  │
│  │  ┌─────────┐  ┌─────────┐  ┌──────────┐                 │  │
│  │  │  Lead   │  │ Builder │  │ Builder  │  Agent Teams     │  │
│  │  │ (Opus)  │  │(Sonnet) │  │(Sonnet)  │  via tmux       │  │
│  │  └────┬────┘  └────┬────┘  └────┬─────┘                 │  │
│  │       │             │            │                        │  │
│  │  ┌────┴─────────────┴────────────┴─────┐                 │  │
│  │  │         Shared Task List            │                 │  │
│  │  └─────────────────────────────────────┘                 │  │
│  │                                                           │  │
│  │  /workspace ──── mounted from host (your repo)            │  │
│  │  /worktrees ──── parallel feature branches (volume)       │  │
│  │  /agent-logs ─── persistent activity journals (volume)    │  │
│  │                                                           │  │
│  │  Hooks: postToolUse → git discipline + README awareness   │  │
│  │  Rules: CLAUDE.md → plan first, vertical slices, quality  │  │
│  │         gate, token budget awareness                      │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  📱 Remote Control ← Claude mobile app (optional)              │
│  📊 ccusage ← live token monitoring                            │
└─────────────────────────────────────────────────────────────────┘
```

## CLI Reference

| Command | Description |
|---------|-------------|
| `claude-dockord setup` | Build image + OAuth login |
| `claude-dockord run <path> [opts]` | Launch session against a project |
| `claude-dockord monitor` | Live token usage dashboard |
| `claude-dockord logs` | List agent activity logs |
| `claude-dockord log <file>` | Read a specific agent's log |
| `claude-dockord export-logs` | Copy all logs to host |
| `claude-dockord attach` | Attach to tmux (watch agent teams) |
| `claude-dockord status` | Show running containers |
| `claude-dockord teardown` | Stop containers, keep volumes |
| `claude-dockord nuke` | Remove everything |

### Run Options

| Flag | Default | Description |
|------|---------|-------------|
| `--ram <size>` | `16g` | Container memory limit |
| `--task <prompt>` | — | Single-shot fire-and-forget |
| `--ralph <prompt>` | — | Ralph loop with circuit breakers |
| `--ralph-iter <n>` | `30` | Max ralph iterations |
| `--agents <prompt>` | — | Multi-agent with team coordination |
| `--auto <prompt>` | — | Auto-restart on rate limits |
| `--rc` | — | Enable Remote Control for phone access |

## Design Decisions

**Why Docker?** `--dangerously-skip-permissions` gives Claude unrestricted shell access. Containerization bounds the blast radius to your mounted project. Host filesystem, SSH keys, and other projects are untouchable.

**Why CLAUDE.md over interactive plan mode?** Plan mode (Shift+Tab) pauses for human approval. CLAUDE.md encodes the same discipline — plan before code, commit in vertical slices — without a human gate. The agent writes the plan, then proceeds autonomously.

**Why a separate reviewer agent?** The agent that writes code shouldn't approve its own work. The quality gate runs as a dedicated reviewer with a separate context window.

**Why git worktrees?** Two agents in the same directory means merge conflicts mid-work. Worktrees give each agent its own checkout on its own branch.

**Why token budget rules?** The 5-hour rolling window is shared across all agents. Without budget awareness, agents burn through quota mid-feature. Tiered rules (66% stop spawning → 75% compact → 90% exit) produce graceful degradation.

**Why hooks instead of more CLAUDE.md?** CLAUDE.md is advisory. Hooks are deterministic. Git discipline and README checks fire every time, regardless of context pressure.

## File Structure

```
├── claude-dockord            # CLI entry point
├── Dockerfile
├── docker-compose.yml
├── entrypoint.sh
├── Makefile                  # Alternative interface
├── templates/
│   ├── CLAUDE.md             # Core operating rules (~108 lines)
│   ├── .ralphrc              # Ralph loop config
│   ├── progress.txt          # State persistence across iterations
│   ├── auto-restart.sh       # Rate limit wait + resume loop
│   ├── docs/
│   │   ├── activity-logging.md
│   │   ├── agent-teams.md
│   │   ├── code-standards.md
│   │   └── tools-and-setup.md
│   └── hooks/
│       └── post-tool-use.sh  # Git discipline + README hook
├── .dockerignore
├── .env.example
└── .gitignore
```

## Requirements

- Docker Desktop
- Claude Code CLI: `npm install -g @anthropic-ai/claude-code`
- Claude Max subscription

## Token Budget

Multi-agent work burns quota fast. With 3 agents expect 1-2 hours per 5-hour window. Ralph loops and `--auto` mode handle rate limits automatically (wait + resume).

As of April 2026, there are [known caching bugs](https://github.com/anthropics/claude-code/issues/40524) inflating token usage. Monitor with `claude-dockord monitor`.

## License

MIT
