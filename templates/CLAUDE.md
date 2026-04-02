# CLAUDE.md — Autonomous Development Operating Manual

You are in an isolated Docker container with `--dangerously-skip-permissions`.
You have sudo and unrestricted tool use. Damage is contained. Act decisively.

Reference docs are in `docs/` — read them when the topic is relevant, not upfront.

---

## Planning (mandatory)

Every task begins with a written plan saved to `/agent-logs/<agent-name>-plan.md`.
Do NOT write code until the plan exists.

1. Restate the task. Identify ambiguities.
2. Decompose into ordered vertical slices (each independently committable).
3. Identify risks, edge cases, and dependencies.
4. Choose the simplest approach. State rejected alternatives and why.
5. Define "done" — what tests prove completion?

Update the plan if reality diverges. The plan is living, not a contract.

---

## Git Workflow

- `main` is protected. Never commit directly.
- All work on feature branches via git worktrees at `/worktrees/`.
- **Never delete feature branches** after merging.
- Conventional commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`
- Each commit = one logical, independently revertable change. Use `git add -p` to split.

### Pre-Merge Quality Gate (in order, each its own commit)
1. Code smells — `refactor: address code smells in <area>`
2. Simplify — `refactor: simplify <what>`
3. Security audit — `fix(security): <what>`
4. Tests (full suite must pass) — `test: add coverage for <what>`
5. README/docs — `docs: update <what>`
6. Rebase ff-only:
   ```bash
   git checkout main && git pull --ff-only
   git checkout feat/branch && git rebase main
   git checkout main && git merge --ff-only feat/branch
   ```

A `postToolUse` hook monitors uncommitted changes and README staleness.

---

## Token Budget Awareness

Use 1M context models. Monitor context usage throughout the session.

- **Above 66%**: Stop spawning new subagents. Finish current work.
- **Above 75%**: Commit all work-in-progress. Run `/compact`.
- **Above 80%**: Focus only on the highest-priority remaining item. Skip nice-to-haves.
- **Above 90%**: Commit everything, update `progress.txt`, exit cleanly.

Use subagents for all research and investigation to keep the main context clean.

### Compaction Instructions
When compacting, always preserve: modified file list, current plan,
test commands, branch state, and next steps.

---

## Activity Logging

Every agent writes a persistent log to `/agent-logs/<agent-name>-activity.md`.
Update after every commit, decision, and status change.
See `docs/activity-logging.md` for format.

---

## Agent Teams

See `docs/agent-teams.md` for roles, rules, and spawning patterns.
Key rules: each teammate gets its own worktree, every agent logs to `/agent-logs/`,
reviewer runs quality gate before lead merges.

---

## Ralph Loop Compatibility

When running under Ralph:
- Orient first: read `progress.txt`, `git log --oneline -20`, `/agent-logs/`.
- Plan first: write/update plan before touching code.
- Update `progress.txt` at end of each iteration.
- Only EXIT_SIGNAL when ALL tasks are genuinely complete and tests pass.
- Checkpoint commit before each iteration ends.

---

## Tool Installation

Install whatever you need. No restrictions. Log installations in your activity log.
See `docs/tools-and-setup.md` for MCP servers, Remote Control, and common tools.

---

## Session Lifecycle

1. **Orient** — Read `progress.txt`, `git log`, `/agent-logs/`, this file.
2. **Plan** — Write plan to `/agent-logs/`. Do not skip this.
3. **Execute** — Smallest increments. Commit each. Log each.
4. **Verify** — Run tests after each commit. Fix immediately.
5. **Record** — Update `progress.txt` and activity log.
6. **Repeat** or **exit cleanly** with updated state.
