# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal, reusable set of Claude Code configuration — rule files, subagent
definitions, hook scripts, and quality-tool base configs — for a Laravel
(API-only, action-class architecture) + Vue 3 (Composition API) + Tailwind +
PostgreSQL + Meilisearch + Spatie + Forge + Horizon stack. Consuming
projects pull pieces of this repo in rather than duplicating them; this repo
itself has no build, no test suite, and no runtime — it's config and docs.

There is no package manager, build step, or test framework for this repo
itself. "Testing" a change here means: `bash -n <script>` for shell syntax,
and manually exercising `bin/sync-config.sh` against a scratch target
directory (see below) since there's no automated test harness for it.

```bash
bash -n hooks/guard-destructive-bash.sh   # syntax-check the hook
bash -n bin/sync-config.sh                # syntax-check the sync script

# Manual smoke test of sync-config.sh against a throwaway target:
tmp=$(mktemp -d)
bin/sync-config.sh "$tmp" fullstack           # fresh sync
bin/sync-config.sh "$tmp" fullstack           # should be a no-op (Synced: 0)
echo '// edit' >> "$tmp/harness/configs/ts/prettier.config.base.ts"
bin/sync-config.sh "$tmp" fullstack           # should SKIP with a warning, not clobber
```

## Architecture: three distinct consumption mechanisms

Files in this repo are pulled into consuming projects via **three different
mechanisms** — which one applies depends on the subdirectory, and it matters
because it changes how an edit here propagates:

1. **`claude/common/CLAUDE.md`, `claude/laravel/laravel.md`, `claude/vue/vue.md`**
   — consumed via Claude Code's `@import` syntax from a project's own
   `CLAUDE.md` (e.g. `@~/Code/harness/claude/laravel/laravel.md`). Edits here
   take effect immediately in every importing project, no sync step. The
   Laravel/Vue files carry `paths:` YAML frontmatter scoping them to matching
   files — keep that frontmatter in sync with the file's actual scope if you
   rename or move it.

2. **`claude/agents/*.md`, `hooks/settings.json`, `hooks/guard-destructive-bash.sh`**
   — consumed via **symlinks** into a project's `.claude/` directory. Also
   propagate immediately on edit. `hooks/settings.json` is a _reference_
   fragment — projects merge its `hooks.PreToolUse` array into their own
   `.claude/settings.json` by hand rather than symlinking the whole file if
   they already have other settings, so don't assume every consumer has it
   symlinked wholesale.

3. **`configs/php/*`, `configs/ts/*`** — consumed via **`bin/sync-config.sh`**,
   which _copies_ (not symlinks) files into `<target>/harness/configs/...`
   and tracks a checksum manifest (`.harness-sync-manifest.json`, written in
   the _target_ project, not here) to detect local edits and avoid
   clobbering them. Editing a file under `configs/` here has **no effect**
   on consuming projects until they re-run `sync-config.sh`. Keep this in
   mind when asked to "update the eslint config" — the fix lands here, but
   propagation is a separate, project-side step.

Because of (3), when editing `configs/php/rector-base.php` or
`configs/ts/eslint.config.base.ts`, the header docblock/comment in each file
showing the project-side import path (`__DIR__ . '/harness/configs/...'`)
must stay accurate — it's the contract consuming projects code against.

Config files under `configs/ts/` are TypeScript (`.ts`), not `.js` —
matches the stack's TS-first convention and `vindo-app`'s actual
`eslint.config.ts`. `configs/ts/oxlint.config.base.json` is the one
exception, since oxlint requires a fixed `.oxlintrc.json`-shaped file.

## `bin/sync-config.sh` stack sets

The `laravel` / `vue` / `fullstack` arguments to `sync-config.sh` map to
fixed file lists hardcoded in the script's `case` statement (search for
`files=(`) — there's no manifest-driven or auto-discovered set. Adding a new
config file under `configs/` requires adding it to the relevant `case` arm
manually, or it will silently never sync.

## Conventions encoded in the rule files (don't relitigate these)

These are the load-bearing architectural decisions the `claude/*.md` files
enforce for _consuming_ Laravel/Vue projects — worth knowing so edits to
this repo stay consistent with them:

- **No Laravel Policies, no `canX()` gates either.** Authorization is
  `requiresPermissions()` constructor middleware on domain controllers
  plus inline `$user->can()` checks, with business-rule guards as
  `throw_if()`/`throw_unless()` domain exceptions inside Action classes —
  see `claude/laravel/laravel.md` for the full pattern.
- **No TypeScript `enum`.** Status/kind value sets use `as const` + a
  derived union type instead, to keep runtime values as plain strings
  matching PHP backed-enum serialization.
- **Composition API only** in Vue — `<script setup lang="ts">`, no Options
  API, no mixins.
- Destructive commands (`rm -rf`, `migrate:fresh`/`reset`, `db:wipe` outside
  `APP_ENV=local`/`testing`) are gated behind approval by
  `hooks/guard-destructive-bash.sh`, which parses the target project's
  `.env` to decide — it walks up from `$PWD` looking for the nearest `.env`,
  falling back to `$CLAUDE_PROJECT_DIR/.env`.

## Rector base config

`configs/php/rector-base.php` mirrors `vindo-api`'s actual `rector.php`:
PHP 8.3, the full set of prepared Rector rule sets (codeQuality,
codingStyle, deadCode, earlyReturn, privatization, typeDeclarations — all
enabled), plus `driftingly/rector-laravel`'s Laravel-specific sets. This
is deliberately the _full_ set actually run against a real codebase in
this stack, not a conservative subset — see that file's own docblock
before narrowing it.

## Local Markdown formatting

This repo has a `package.json` with Prettier as the one local dev
dependency, used only to format `**/*.md` (`pnpm format:md` /
`pnpm format:md:check`). `.prettierrc.json` sets
`embeddedLanguageFormatting: "off"` deliberately — Prettier's Markdown
formatter recursively reformats fenced code blocks by detected language,
and it has actually corrupted content here before (mangled a literal
`@~/...` CLAUDE.md import-path example inside a fenced block). Don't
re-enable embedded formatting without re-checking every fenced example
across `claude/**/*.md` and `README.md` for corruption first.
