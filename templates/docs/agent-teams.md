# Agent Teams Reference

Agent teams are enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

## Roles

- **Lead** — Decomposes work, spawns teammates, coordinates, performs final merge.
- **Builder** — Implements in an isolated worktree. Commits vertical slices.
- **Reviewer** — Runs the Pre-Merge Quality Gate on completed work. Does not merge.

## Rules

- Each teammate gets its own worktree. Never two agents in the same directory.
- Every agent writes to `/agent-logs/` immediately on spawn.
- Builders signal completion via task list update.
- Reviewer runs after builder signals done, before lead merges.
- Use direct messages for coordination. Use broadcasts sparingly (token cost scales with team size).

## Spawning Examples

```
Spawn a builder teammate with the prompt:
  "Your name is builder-auth. Write your activity log to /agent-logs/builder-auth-activity.md.
   Work in /worktrees/feat-auth on branch feat/auth.
   Create the worktree: git worktree add /worktrees/feat-auth -b feat/auth
   Implement [specific scope]. Commit in vertical slices.
   Signal completion via task update when done."

Spawn a reviewer teammate with the prompt:
  "Your name is reviewer. Write your activity log to /agent-logs/reviewer-activity.md.
   When a builder marks their task complete, check out their branch
   and run the Pre-Merge Quality Gate from CLAUDE.md.
   Report issues via task update. Do not merge — only the lead merges."
```

## Token Considerations

A 3-teammate team uses roughly 3-4x the tokens of a single session doing the same
work sequentially. Keep teams small and well-scoped. Prefer subagents for quick
research tasks that don't need inter-agent communication.
