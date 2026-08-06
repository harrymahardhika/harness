# Universal Rules

These rules apply to every project regardless of stack. They are imported
via `@~/harness/claude/common/CLAUDE.md` (or your project's relative path
back to this repo) from each project's own `CLAUDE.md`. See the harness
README for the exact import syntax.

## Commit Message Conventions

- Use Conventional Commits: `type(scope): summary`, e.g. `fix(auth): reject expired tokens`.
  Common types: `feat`, `fix`, `refactor`, `test`, `chore`, `docs`, `perf`.
- Summary line is imperative mood, no trailing period, ideally under 72 chars.
- Body (when needed) explains _why_, not just _what_ — the diff already shows what changed.
- Never mention Claude/AI authorship in the commit body text itself; use the
  trailer instead:
  ```
  Co-Authored-By: Claude <noreply@anthropic.com>
  ```
- Only commit or push when the user asks. Do not create a feature branch
  on your own initiative — including when a commit is requested while on
  the repo's default branch. Stay on the current branch unless the user
  explicitly asks you to create or switch branches.
- Never `git commit --amend` or force-push over commits you didn't just
  create in this session without explicit confirmation.

## Testing-Before-Done Gates

- A task is not "done" until its tests pass. Never report a feature/fix as
  complete without having run the relevant tests (Pest for PHP, Vitest for
  Vue/TS) and shown the passing output.
- Prefer running only the test(s) relevant to the change being made (a
  single file, class, or `--filter`). Do not run the full test suite
  unless explicitly asked to — it's slow and mostly re-confirms unrelated
  code.
- `.feature` files are living documentation in some projects (e.g.
  `analytics-api`, alongside `todo.md`), not a required source of Pest
  tests in every project — most projects in this stack (e.g. `vindo-api`)
  have no `.feature` files at all and are gated on plain Pest `it()`
  tests instead. See `claude/agents/test-writer.md` for which mode
  applies. Don't invent a `.feature`-to-Pest requirement for a project
  that doesn't have one.
- If tests fail, say so plainly with the actual failure output. Do not
  paraphrase a failure as a pass, and do not silently skip a failing test
  to reach "green."
- If a test genuinely cannot be run in this environment (e.g. missing
  service, no DB), say that explicitly rather than assuming it would pass.

## Safety Rules for Destructive Commands

- Treat these as requiring explicit human confirmation, even in
  auto-accept modes: `rm -rf`, `git reset --hard`, `git push --force`,
  any `migrate:fresh` / `migrate:reset` / `db:wipe` outside a local
  environment, and any command that drops or truncates a database/table.
- Before deleting or overwriting a file you did not create in this
  session, read it first. If its contents contradict how it was
  described to you, stop and surface that instead of proceeding.
- Prefer reversible operations (soft delete, `git mv`, backups) over
  irreversible ones when both accomplish the goal.
- See `hooks/settings.json` for the PreToolUse hook that mechanically
  blocks a subset of these.

## Ambiguous Requirements: Ask vs. Assume

- Ask when the decision is: hard to reverse, affects data integrity,
  changes a public API/contract, or the codebase shows no existing
  convention to follow.
- Assume (and briefly state the assumption inline) when: the codebase
  already has a clear, consistent convention nearby, the choice is
  cosmetic/local, or getting it wrong costs one cheap follow-up edit.
- When assuming, say so explicitly in the response ("I assumed X because
  Y — let me know if that's wrong") rather than staying silent about it.
- Never guess at business logic (pricing, permissions, financial
  calculations) — always ask.

## Expensive Tools: Explicit Invocation Only

- `claude-in-chrome` (browser control) burns credits disproportionately.
  Never reach for it as a default or convenience option. Only use it when
  the user explicitly asks for it by name or unambiguously asks for live
  browser interaction/automation that no other tool can satisfy.
- Prefer `WebFetch`, reading local files, or asking the user to check
  something manually before considering it.
