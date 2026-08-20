---
paths: ["**/*.php"]
---

# Laravel Conventions

This file reflects the actual architecture used in `vindo-api` (a
domain-module Laravel API on PHP 8.3 / Laravel 13 / PostgreSQL). Treat it
as the standard for new Laravel projects in this stack, not just
documentation of one repo.

## Domain-Module Architecture

Organize code by domain, not by technical layer. Keep everything for a
domain together under `app/Domains/{DomainName}/`:

```
app/Domains/Ticket/
├── Actions/        # AbstractAction / AbstractAsyncAction subclasses
├── Controllers/
├── Models/
├── Repositories/    # Repository + Criteria (see below)
├── Requests/
├── DTO/             # spatie/laravel-data objects
├── Enums/           # incl. Permission enum for this domain
├── Exceptions/       # domain-specific exception classes
├── States/          # spatie/laravel-model-states, if the domain has a status machine
└── Notifications/
```

Keep non-domain code (`app/Console`, `app/Http/Middleware`,
`app/Providers`, `app/Services`, `app/Support`) outside `Domains/`. When
adding a new feature, ask "which domain does this belong to" before
picking a directory. Do not fall back to a flat `app/Http/Controllers` +
`app/Models` layout.

## Action Classes

Put business logic in Action classes. Extend `AbstractAction` (sync) or
`AbstractAsyncAction` (queued) from the internal `harrym/domain-support`
package. Dispatch these via Laravel's `Dispatchable` bus. Do not call
them as plain services or instantiate-and-invoke them directly.

```php
final class AssignTicket extends AbstractAction
{
    public function __construct(
        private readonly Ticket $ticket,
        private readonly int $assigneeId,
    ) {}

    public function handle(): Ticket
    {
        return DB::transaction(function (): Ticket {
            throw_if($this->ticket->status instanceof Closed, TicketException::cannotAssignClosed());
            // ...
            return $this->ticket;
        });
    }
}
```

- Constructor-inject everything the action needs. `handle()` takes no
  arguments and does the work. Wrap `handle()` in `DB::transaction()`
  when it writes.
- Invoke with `dispatch_sync(new AssignTicket($ticket, $assigneeId))`
  from sync contexts (controllers, tests). Use `dispatch(new SomeAsyncAction(...))`
  for queued work. Queued actions extend `AbstractAsyncAction`, which
  already implements `ShouldQueue`.
- There is no separate `app/Jobs` directory and no Horizon in this
  stack. Queued work is an `AbstractAsyncAction`, not a standalone job
  class. If a project later adds Horizon, async actions still own the
  business logic. Horizon only changes how the queue is
  monitored/dispatched.
- Throw business-rule violations as domain exceptions with
  `throw_if()`/`throw_unless()` inside the action. For example:
  `TicketException::cannotAssignClosed()`. Do not use generic `abort()`
  calls.

## Authorization: Permission Middleware + Inline Checks

There are **no Laravel Policies** and **no static `canX()` gate
methods** on action classes. Authorize with the two mechanisms below.

1. **Route-method-level**, via a `requiresPermissions()` call in the
   controller constructor (from the `HasPermissionMiddleware` trait).
   Map a `Permission` backed enum to controller methods:

   ```php
   public function __construct()
   {
       $this->requiresPermissions([
           Permission::BROWSE_TICKETS->value => ['index'],
           Permission::READ_TICKET->value => ['show'],
           Permission::EDIT_TICKET->value => ['update'],
           Permission::ASSIGN_TICKET->value => ['assign'],
       ]);
   }
   ```

   This applies Spatie Permission's `permission:` route middleware per
   method. Every domain controller needs this in its constructor. A
   controller with no `requiresPermissions()` call is a red flag, not an
   oversight to leave alone.

2. **Inline row/field-level checks**, using `$user->can()` directly
   against the same `Permission` enum. Use these for authorization that
   cannot be expressed as a blanket per-method rule:

   ```php
   abort_if($authUser->isNot($user) && ! $authUser->can(Permission::EDIT_USER->value), 403);
   ```

3. **Business-rule guards** (as opposed to permission checks) are
   `throw_if()`/`throw_unless()` against domain exceptions inside the
   Action class itself. See above. Do not put business-rule branching in
   the controller or the permission check.

`Permission` enums are backed PHP enums, one per domain. See the
project's `.claude/rules/permissions.md` for where roles/permissions
live and how they're synced.

## Repository + Criteria (not Spatie Query Builder)

This stack does not use `spatie/laravel-query-builder`. Filtering/sorting
goes through a hand-rolled Repository + Criteria pair from
`harrym/domain-support` — see the project's
`.claude/rules/repositories.md` for the field-to-method wiring
convention. Set `$searchableColumns` and `$useScout` on the repository
when the domain is Meilisearch-indexed; `search()` picks Scout vs. a
Postgres `ilike`/`LOWER() LIKE` fallback automatically.

## PostgreSQL Conventions

- Use `snake_case` columns and plural table names (`tickets`,
  `ticket_comments`).
- Define foreign keys with `$table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();`
  Use Laravel's `foreignId()`/`constrained()` helpers, with the `_id`
  suffix.
- **Postgres does not auto-index foreign keys** (unlike MySQL). Add an
  explicit `$table->index('user_id')` (or fold it into
  `foreignId()->constrained()->index()` chaining) for every foreign key
  column, or joins/lookups on it will full-scan.
- Prefix boolean columns with `is_` (for example `is_blocked`). Cast
  them to `'boolean'` in the model's `casts()`.
- **Never put boolean fields in `$fillable`** (not even in a
  guarded/`safe` input rule). Assignment is always direct property
  access, `$model->is_active = true;`. Never use
  `Model::create($request->validated())` to carry a boolean through mass
  assignment. This keeps mass-assignment surfaces free of toggleable
  flags.
- **Timestamps are timezone-aware**: use `$table->timestampsTz()` and
  `$table->softDeletesTz()`, never the plain (non-`Tz`) variants. Extra
  event timestamps follow `{event}_at`, also `timestampTz()`.
- Use plain `string` columns for status/enum-like columns. Back them
  with either a PHP backed enum or a
  `spatie/laravel-model-states` state machine on the model side. Do not
  use native Postgres `ENUM` types:
  ```php
  $table->string('employment_status')->default(EmploymentStatus::ACTIVE->value);
  ```
  Use `spatie/laravel-model-states`
  (`App\Domains\{Domain}\States\{Model}\...`) when the column has real
  state-machine transitions (for example Ticket's
  `Open → InProgress → Closed`). Check with `instanceof` and move with
  `$model->status->transitionTo(InProgress::class)`. Use a plain backed
  enum when it is just a fixed set of values with no transition logic.
- Add explicit `$table->index(...)` on any column a Repository filters
  on.
- Name migration files: `YYYY_MM_DD_HHMMSS_create_x_table.php`.

## Spatie Packages Actually In Use

- **`spatie/laravel-permission`** has `HasRoles` on the `User` model.
  Use it for authorization checks per above (permission middleware +
  `$user->can()`).
- **`spatie/laravel-model-states`** covers status/state-machine columns,
  see above.
- **`spatie/laravel-data`** provides DTOs for request payloads and API
  responses (`TicketData`, `PaginatedDataCollection`). Prefer a
  `spatie/laravel-data` object over an ad-hoc array/Resource when
  shaping input or output.
- **`spatie/laravel-query-builder`** and
  **`spatie/laravel-medialibrary`** are **not** part of this stack. Do
  not reach for them. Filtering goes through Repository+Criteria (see
  above). File/attachment handling is a custom domain model
  (`app/Domains/Attachment/*`), not Media Library.

## Testing

Project-local test conventions (Pest setup, factories,
`createUser()` patterns, running tests) live in the project's
`.claude/rules/testing.md`. The rules below are cross-project and don't
belong to one path glob:

- **Do not duplicate HTTP coverage in Unit tests.** If a Feature test
  already exercises a path end-to-end (controller → Action →
  Repository → response), don't also write a Unit test for the same
  behavior. Write a Unit test only when an HTTP round-trip is the wrong
  tool: isolated logic (value object, DTO transform, state-machine edge
  case), or a scenario that needs `Http::fake()` / `Queue::fake()` /
  `Bus::fake()` / `Notification::fake()` / mocked time to isolate a
  dependency or assert dispatch rather than downstream effect. Check
  for existing Feature coverage before assuming a Unit test is missing.
- **Seed roles/permissions once per test process, not per test.** A
  `createUser()` helper needs role/permission rows to already exist.
  Run the rebuild command once, right after `migrate:fresh` inside
  `RefreshDatabase`'s `migrateDatabases()` — never in a Pest
  `beforeEach` (~150 queries × hundreds of tests adds minutes) and
  never inside `refreshTestDatabase()` after
  `beginDatabaseTransaction()` (rolls back after the first test, leaving
  every later test without roles).
- `phpunit.xml` `<env>` values win over `.env.testing`; don't treat
  `.env.testing`'s pgsql/redis settings as what's actually in effect
  during a test run.

## Code Style Enforcement

- Start every PHP file with `declare(strict_types=1);`. Pint enforces
  this, so do not skip it on new files.
- Use `configs/php/pint.json` / `configs/php/rector-base.php` in this
  harness repo. They mirror `vindo-api`'s actual
  `pint.json`/`rector.php`. Sync those rather than hand-configuring per
  project. Larastan (`larastan/larastan`) runs at level 9 in `vindo-api`.
  Match that level for new projects unless there is a reason to start
  lower.
