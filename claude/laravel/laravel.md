---
paths: ["**/*.php"]
---

# Laravel Conventions

## Authorization: Action Classes, Not Policies

This codebase does **not** use Laravel Policies. Authorization lives on
static `canX()` methods on action classes.

- Every action class exposes a static gate method named `can` + the
  action verb, e.g. `canUpdate()`, `canDelete()`, `canPublish()`.
- Signature convention: `public static function canUpdate(User $user, Model $model): bool`.
  For actions with no target model yet (e.g. create), drop the model arg:
  `public static function canCreate(User $user): bool`.
- Controllers/handlers call the gate explicitly before invoking the
  action — do not rely on `$this->authorize()` / policy auto-discovery:
  ```php
  abort_unless(UpdatePostAction::canUpdate($request->user(), $post), 403);

  return (new UpdatePostAction())->handle($post, $request->validated());
  ```
- Never register a `PolicyServiceProvider` mapping or create a class
  under `app/Policies`. If you find one, flag it as a violation rather
  than extending it.
- Spatie `permissions` roles/permissions are checked *inside* `canX()`,
  not scattered across controllers:
  ```php
  public static function canDelete(User $user, Post $post): bool
  {
      return $user->id === $post->author_id || $user->can('posts.delete-any');
  }
  ```

## Spatie Query Builder Conventions

- Every index endpoint that accepts filtering/sorting goes through
  `Spatie\QueryBuilder\QueryBuilder`, not manual `Request` query parsing.
- Declare `allowedFilters()`, `allowedSorts()`, and `allowedIncludes()`
  explicitly and exhaustively — never use `AllowedFilter::exact()` on a
  column you haven't reasoned about exposing.
- Prefer `AllowedFilter::scope()` backed by a named query scope on the
  model over inline closures, so the filter logic is testable in
  isolation.
- Default sort must always be set explicitly (`->defaultSort('-created_at')`)
  — don't rely on database default ordering.

## PostgreSQL Column-Naming Conventions

- `snake_case` for all columns, singular table names avoided (use
  plural: `posts`, `post_comments`).
- Foreign keys: `{singular_referenced_table}_id`, e.g. `user_id`,
  `post_id`. For self-referencing or ambiguous FKs, prefix with role:
  `approved_by_user_id`.
- Boolean columns are prefixed `is_` / `has_`: `is_published`,
  `has_verified_email`.
- Timestamp columns beyond the standard `created_at`/`updated_at` use
  `{event}_at`: `published_at`, `archived_at`. Never store dates as
  strings — use `timestamptz`.
- Enum-like status columns are plain `varchar`/`text` backed by a PHP
  backed enum, not native Postgres `ENUM` types (migration friction).
  Column name is just the noun: `status`, not `status_type`.

## Horizon Queue Job Conventions

- Every queued job implements `ShouldQueue` and declares an explicit
  `$queue` property matching a named Horizon queue (`default`, `emails`,
  `search-index`, etc.) — never leave jobs on the implicit default
  unless that's genuinely intended.
- Jobs are thin: they resolve dependencies and delegate to an action
  class (`public function handle(): void { (new SyncPostToMeilisearchAction())->handle($this->post); }`).
  Business logic does not live in the job body.
- Set `$tries` and `$backoff` explicitly on every job that talks to an
  external service (Meilisearch, mail, Forge deploy hooks) — don't rely
  on the global queue default.
- Failed jobs must be actionable: implement `failed(Throwable $e)` to
  log context (model id, attempt count) rather than swallowing silently.
- Batch related jobs with `Bus::batch()` when they represent one logical
  unit of work (e.g. reindexing all rows of a model) so Horizon
  dashboards reflect real progress instead of N unrelated entries.
