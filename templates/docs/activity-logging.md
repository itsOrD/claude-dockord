# Activity Logging Reference

Every agent maintains a persistent activity log at `/agent-logs/<agent-name>-activity.md`.
This volume survives container restarts and agent kills.

## Format

```markdown
# Activity Log: <agent-name>
Created: <timestamp>
Role: <lead | builder | reviewer>
Branch: <branch-name>
Task: <one-line summary>

## Plan
<link to plan file or inline summary>

## Activity
- [HH:MM] Started: <what>
- [HH:MM] Committed: <hash> <message>
- [HH:MM] Decision: <what and why>
- [HH:MM] Blocked: <issue>
- [HH:MM] Installed: <tool> — <why>
- [HH:MM] Completed: <what>

## Final Status
<completed | in-progress | blocked | failed>
<what was accomplished>
<what remains>
```

## Rules

- Write to this file after every commit, decision, and status change.
- If you are killed mid-task, this log must let the next agent pick up exactly where you left off.
- Include commit hashes so work can be traced.
- Include tool installations so the environment can be reproduced.
