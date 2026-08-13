# AGENTS.md

Personal, reusable config for Laravel (API-only, action-class architecture) + Vue 3 (Composition API) projects. No build, no runtime, no test suite. This repo is config and docs consumed by other projects. `CLAUDE.md` is the detailed reference; this file is the compact operating guide.

## How to "test" a change

There is no test framework. Verification is syntax checks + a manual smoke test of `bin/sync-config.sh` against a throwaway dir:

```bash
bash -n hooks/guard-destructive-bash.sh bin/sync-config.sh

tmp=$(mktemp -d)
bin/sync-config.sh "$tmp" fullstack            # fresh sync
bin/sync-config.sh "$tmp" fullstack            # no-op: "Synced: 0"
echo '// edit' >> "$tmp/harness/configs/ts/prettier.config.base.ts"
bin/sync-config.sh "$tmp" fullstack            # SKIPs, does not clobber local edit
```

## Three consumption mechanisms, propagation differs per directory

1. `claude/common/CLAUDE.md`, `claude/laravel/laravel.md`, `claude/vue/vue.md`. Pulled in via `@~/Code/harness/...` imports in a project's `CLAUDE.md`. Edits apply immediately, no sync step. The Laravel/Vue files carry `paths:` YAML frontmatter scoping them to `**/*.php` / `**/*.vue`, `resources/js/**/*.ts`. Keep it in sync if you move them.
2. `claude/agents/*.md`, `hooks/*`. Symlinked into a project's `.claude/`. Also propagate immediately.
3. `configs/**`. `bin/sync-config.sh` **copies** them into `<target>/harness/configs/...` and tracks a checksum manifest (`.harness-sync-manifest.json`) written in the _target_ project. Editing here has **no effect** on consumers until they re-run the sync. "I fixed the eslint config" is only half the job.

## `bin/sync-config.sh` gotchas

- The `laravel` / `vue` / `fullstack` sets are hardcoded `case` arms in the script (search `files=(`). A new file under `configs/` **silently never syncs** until you add it to the relevant arm.
- Requires `jq` on PATH.
- Skips destination files locally edited since the last sync (hash mismatch) rather than clobbering. Backs up overwrites to `<file>.bak`.
- `configs/ts/*` are TypeScript (`.ts`), not `.js`. Exception: `oxlint.config.base.json`, which keeps a fixed name because oxlint requires an `.oxlintrc.json`-shaped file.

## Config-file contract

- The header docblocks in `configs/php/*` and `configs/ts/*` show the consumer's import path (for example `__DIR__ . '/harness/configs/php/rector-base.php'`). Keep them accurate. Consuming projects code against them.
- `configs/php/rector-base.php` is deliberately the **full** Rector set (codeQuality, codingStyle, deadCode, earlyReturn, privatization, typeDeclarations + `rector-laravel` sets), mirroring `vindo-api`'s real `rector.php`. Do not narrow it to a conservative subset.

## Formatting (the only local tooling)

Prettier is the single dev dependency, used only for Markdown:

```bash
pnpm format:md        # prettier --write "**/*.md"
pnpm format:md:check  # verification
```

`.prettierrc.json` sets `embeddedLanguageFormatting: "off"` deliberately. The Markdown formatter has corrupted fenced examples before (mangled a `@~/...` import path inside a code block). Do not re-enable it without re-checking every fenced block.

## Hook behavior worth knowing

`hooks/guard-destructive-bash.sh` is a PreToolUse hook forcing an approval prompt for `rm -rf` and for `migrate:fresh`/`migrate:reset`/`db:wipe` when the invoking project's `.env` `APP_ENV` is not `local`/`testing`. It walks up from `$PWD` for the nearest `.env`, falls back to `$CLAUDE_PROJECT_DIR/.env`. No `.env` found = treated as non-local. `hooks/settings.json` is a _reference fragment_. Consumers merge its `hooks.PreToolUse` array by hand, so do not assume it is symlinked wholesale.

## Conventions encoded in the rule files (do not relitigate)

- No Laravel Policies, no `canX()` gates. Authorization is `requiresPermissions()` constructor middleware + inline `$user->can()`, with business-rule guards as `throw_if()`/`throw_unless()` domain exceptions inside Action classes.
- No TypeScript `enum`. Use `as const` + derived union types. Values must stay plain strings matching PHP backed-enum serialization.
- Composition API only (`<script setup lang="ts">`), no Options API, no mixins.

## STE100-lite writing rules for all `.md` files

Apply these rules to every Markdown file in this repo. Do not relitigate them.

1. **One instruction per sentence, imperative mood, active voice, present tense.** Write each rule as a direct command. Do not use passive or conditional prose where a command fits.
2. **Terminology consistency.** Use one term per concept. The glossary below lists approved words. Use them, never their synonyms.
3. **No banned words or punctuation.** Forbidden: `should`, `maybe`, `possibly`, `and/or`, `etc.`, em-dashes (`—`), and contractions (`it's`, `you'll`, `doesn't`).

**Approved-term glossary:**

| Use always       | Never use as synonyms                                            |
| ---------------- | ---------------------------------------------------------------- |
| `receive`        | `get`, `fetch`, `obtain`                                         |
| `use`            | `employ`, `utilize`, `leverage`                                  |
| `make` / `write` | `generate`, `create` (keep `create` for Laravel `Model::create`) |
| `must`           | `should`, `need to`                                              |
| `do not`         | `don't`                                                          |
| `start` / `stop` | `begin`, `commence`                                              |
| `for example`    | `e.g.`                                                           |

**Never change technical names.** HTTP method verbs (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`), code identifiers, class names, paths, and command names stay exactly as written. The terminology rule applies to English vocabulary only, never to code or protocol terms.

**Exceptions:** YAML frontmatter (in `claude/agents/*.md` and the `paths:` blocks) is machine-read and stays untouched. Fenced code blocks stay as-is unless a comment inside them violates rule 3.

## Housekeeping

- Plain git repo (Stow is only for the separate dotfiles repo). `.claude/`, `*.bak`, and `scratchpad.txt` are gitignored.
- `scratchpad.txt` is a throwaway notes file. It is not part of the repo's content.
