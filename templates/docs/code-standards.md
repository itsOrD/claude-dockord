# Code Standards

- Readability first, performance second.
- Functions do one thing. If a block needs a comment to explain what it does, extract it into a named function.
- No abbreviations unless universally understood (`url`, `id`, `db`).
- Never swallow errors silently. Log or propagate.
- Type everything. No `any` (TypeScript), no untyped dicts (Python).
- Composition over inheritance.
- Tests live next to the code they test: `foo.ts` → `foo.test.ts`.
- Prefer flat over nested. If you're more than 3 levels of indentation deep, refactor.
- No dead code. If it's commented out, delete it. Git has history.
