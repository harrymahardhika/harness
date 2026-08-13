# Universal Rules

These rules apply to every project regardless of stack. Import them via
`@~/harness/claude/common/CLAUDE.md` (or your project's relative path back
to this repo) from each project's own `CLAUDE.md`. See the harness README
for the exact import syntax.

## Commit Message Conventions

- Use Conventional Commits: `type(scope): summary`. For example:
  `fix(auth): reject expired tokens`. Common types: `feat`, `fix`,
  `refactor`, `test`, `chore`, `docs`, `perf`.
- Write the summary line in the imperative mood. Do not add a trailing
  period. Keep it under 72 chars.
- Add a body when the diff does not explain the _why_. The body explains
  the reason for the change, not just the change itself.
- Never mention Claude or AI authorship in the commit body text. Use the
  trailer instead:
  ```
  Co-Authored-By: Claude <noreply@anthropic.com>
  ```
- Commit or push only when the user asks. Do not create a feature branch
  on your own initiative. This applies even when the user requests a
  commit while on the repo's default branch. Stay on the current branch
  unless the user explicitly asks you to create or switch branches.
- Do not run `git commit --amend` or force-push over commits you did not
  create in this session without explicit confirmation.

## Testing-Before-Done Gates

- A task is not "done" until its tests pass. Do not report a feature or
  fix as complete until you have run the relevant tests (Pest for PHP,
  Vitest for Vue/TS) and shown the passing output.
- Run only the test(s) relevant to the change being made. This can be a
  single file, a class, or a `--filter` run. Do not run the full test
  suite unless the user explicitly asks. The full suite is slow and
  mostly re-confirms unrelated code.
- Treat `.feature` files as living documentation in some projects (for
  example `analytics-api`, alongside `todo.md`). They are not a required
  source of Pest tests in every project. Most projects in this stack (for
  example `vindo-api`) have no `.feature` files at all. Those projects
  gate on plain Pest `it()` tests instead. See
  `claude/agents/test-writer.md` for which mode applies. Do not invent a
  `.feature`-to-Pest requirement for a project that does not have one.
- When tests fail, say so plainly and show the actual failure output. Do
  not paraphrase a failure as a pass. Do not silently skip a failing test
  to reach "green".
- When a test cannot be run in this environment (for example a missing
  service or no database), say that explicitly. Do not assume it would
  pass.

## Safety Rules for Destructive Commands

- Treat these commands as requiring explicit human confirmation, even in
  auto-accept modes: `rm -rf`, `git reset --hard`, `git push --force`,
  any `migrate:fresh` / `migrate:reset` / `db:wipe` outside a local
  environment, and any command that drops or truncates a database or
  table.
- Read a file first before deleting or overwriting it when you did not
  create it in this session. When its contents contradict how it was
  described to you, stop and surface that instead of proceeding.
- Prefer reversible operations (soft delete, `git mv`, backups) over
  irreversible ones when both accomplish the goal.
- See `hooks/settings.json` for the PreToolUse hook that mechanically
  blocks a subset of these.

## Ambiguous Requirements: Ask vs. Assume

- Ask when the decision is hard to reverse, affects data integrity,
  changes a public API or contract, or the codebase shows no existing
  convention to follow.
- Assume (and briefly state the assumption inline) when the codebase
  already has a clear, consistent convention nearby, when the choice is
  cosmetic or local, or when getting it wrong costs one cheap follow-up
  edit.
- When assuming, say so explicitly in the response. For example:
  "I assumed X because Y, let me know if that is wrong". Do not stay
  silent about it.
- Never guess at business logic (pricing, permissions, financial
  calculations). Always ask.

## Code Style

- Prefer an early return (guard clause) over wrapping the remaining logic
  in an `else`. Once a condition is handled and returns, throws, or
  continues, drop the `else` and let the rest of the function run
  unindented.

## Parallelizable Work: Sub-Agents at Lower Effort, Reviewed in Main Thread

- When a task genuinely decomposes into independent chunks (for example
  reviewing several unrelated files or domains, or researching multiple
  unrelated areas), prefer spawning one sub-agent per chunk over one long
  serial pass. This is not a default for ordinary multi-step tasks or
  small work. A sub-agent starts cold and re-derives context. It only
  pays off when the chunks are genuinely independent and substantial
  enough to be worth that overhead.
- Run those sub-agents at a lower reasoning-effort level than the main
  thread's. The chunk-level work is narrower in scope. It does not need
  the main thread's full effort to do well. Lower effort is faster and
  cheaper per call.
- Treat a sub-agent's output as never final on its own. Review and
  synthesize every sub-agent's work in the main thread before reporting
  it as done. Their reports are not shown to the user directly. The main
  thread is accountable for catching a sub-agent that went off track.

## Expensive Tools: Explicit Invocation Only

- `claude-in-chrome` (browser control) burns credits disproportionately.
  Never use it as a default or convenience option. Use it only when the
  user explicitly asks for it by name or unambiguously asks for live
  browser interaction or automation that no other tool can satisfy.
- Prefer `WebFetch`, reading local files, or asking the user to check
  something manually before considering `claude-in-chrome`.
