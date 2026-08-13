# harness

A personal, reusable set of Claude Code configuration, agent definitions,
and quality-tool configs. Pull it into individual projects the same way
[dotfiles](https://github.com/) get managed with GNU Stow. Stack target:
Laravel (API-only, action-class architecture), Vue 3 (Composition API),
Tailwind, PostgreSQL, Meilisearch, Spatie packages, Forge, Horizon.

```
harness/
├── claude/
│   ├── common/CLAUDE.md       # universal rules, every project
│   ├── laravel/laravel.md     # path-scoped: **/*.php
│   ├── vue/vue.md             # path-scoped: **/*.vue, resources/js/**/*.ts
│   └── agents/                # starter subagent definitions
├── hooks/
│   ├── settings.json          # PreToolUse hook wiring
│   └── guard-destructive-bash.sh
├── configs/
│   ├── php/                   # pint.json, rector-base.php
│   └── ts/                    # eslint.config.base.ts, prettier.config.base.ts, oxlint.config.base.json
├── bin/sync-config.sh
└── README.md
```

## 1. Wiring a project's `CLAUDE.md` with `@imports`

Claude Code supports `@path/to/file` imports inside `CLAUDE.md`. Point a
project's own `CLAUDE.md` back at this repo instead of copy-pasting
rules. Clone or symlink this repo somewhere stable (for example
`~/Code/harness`). Then, in the project:

```markdown
# CLAUDE.md

@~/Code/harness/claude/common/CLAUDE.md
@~/Code/harness/claude/laravel/laravel.md
@~/Code/harness/claude/vue/vue.md

## Project-specific notes

Anything that only makes sense for *this* project goes here, below the
imports. For example: domain vocabulary, deploy quirks, feature flags.
```

Imports resolve relative to the importing file or `~`. An absolute
`~/Code/harness/...` path works regardless of where the project itself
lives on disk. `laravel.md` and `vue.md` carry `paths:` frontmatter
scoping them to matching files. They only apply when Claude is actually
touching `.php` or `.vue`/`resources/js/**/*.ts` files.

If you would rather vendor the harness into the project (for example for
a teammate who has not cloned it separately), use a relative path to a
git submodule or `sync-config.sh`'d copy instead. See §2/§3 below.

## 2. Syncing configs with `bin/sync-config.sh`

Copies a chosen subset of `configs/` into
`<target>/harness/configs/...`, tracking what it last wrote via
`.harness-sync-manifest.json` in the target project. If a
previously-synced file has been edited locally since, skip it with a
warning instead of clobbering it. Back up anything it does overwrite to
`<file>.bak` first.

```bash
# from this repo
bin/sync-config.sh /path/to/project laravel      # pint.json + rector-base.php
bin/sync-config.sh /path/to/project vue           # eslint + prettier + oxlint base configs
bin/sync-config.sh /path/to/project fullstack     # all of the above
bin/sync-config.sh /path/to/project fullstack --dry-run   # preview only
```

In the target project, reference the synced base config from your own:

```php
// rector.php
return RectorConfig::configure()
    ->withSets([__DIR__ . '/harness/configs/php/rector-base.php'])
    ->withPaths([__DIR__ . '/app', __DIR__ . '/routes']);
```

```ts
// eslint.config.ts - copy harness/configs/ts/oxlint.config.base.json to
// .oxlintrc.json first (eslint-plugin-oxlint reads it from the project root)
import harnessBase from './harness/configs/ts/eslint.config.base.ts'

export default [...harnessBase, { rules: { /* project overrides */ } }]
```

Requires `jq` on PATH. Re-run the sync any time this repo's configs
change. Commit the resulting `harness/` copy and manifest in the target
project so teammates get the same baseline without needing this repo
cloned separately.

## 3. Symlinking agents and hooks into a project's `.claude/`

Symlink subagent definitions and the destructive-command hook, do not
copy them. Updates here propagate immediately:

```bash
cd /path/to/project
mkdir -p .claude/agents
ln -s ~/Code/harness/claude/agents/laravel-reviewer.md .claude/agents/laravel-reviewer.md
ln -s ~/Code/harness/claude/agents/test-writer.md .claude/agents/test-writer.md

# hooks/settings.json wires a PreToolUse hook; merge its "hooks" key into
# the project's own .claude/settings.json (Claude Code does not merge
# multiple settings.json files automatically), and symlink the guard
# script itself so the hook command resolves:
mkdir -p .claude
ln -s ~/Code/harness/hooks/guard-destructive-bash.sh .claude/guard-destructive-bash.sh
```

If the project's `.claude/settings.json` does not exist yet, you can
symlink `hooks/settings.json` directly as a starting point:

```bash
ln -s ~/Code/harness/hooks/settings.json .claude/settings.json
```

If it already has other settings, copy the `hooks.PreToolUse` array from
`hooks/settings.json` into it by hand instead of symlinking the whole
file. Otherwise you will clobber the project's own settings.

## Agents

- **`laravel-reviewer`** reviews a diff/PR for N+1 queries and
  action-class architecture violations (stray Policies, missing
  `canX()` gates, business logic leaking into controllers/jobs).
- **`test-writer`** turns Gherkin `.feature` files into Pest tests,
  one test per scenario, run against the actual implementation (never
  invents the API shape).

## Updating this repo

This repo is plain git. No Stow involved (Stow is for the separate
`dotfiles` repo). Edit, commit, and re-run `sync-config.sh` in
consuming projects to pick up config changes. `@import`ed `CLAUDE.md`
files and symlinked agents/hooks pick up edits immediately. No sync step
needed.
