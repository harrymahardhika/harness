---
paths: ["**/*.php"]
---

# Laravel Conventions

Reflects the actual architecture used in `vindo-api` (domain-module Laravel
API on PHP 8.3 / Laravel 13 / PostgreSQL). Treat this as the standard for
new Laravel projects in this stack, not just documentation of one repo.

## Domain-Module Architecture

Code is organized by domain, not by technical layer. Everything for a
domain lives together under `app/Domains/{DomainName}/`:

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

Non-domain code (`app/Console`, `app/Http/Middleware`, `app/Providers`,
`app/Services`, `app/Support`) stays outside `Domains/`. When adding a new
feature, ask "which domain does this belong to" before picking a
directory — don't fall back to a flat `app/Http/Controllers` +
`app/Models` layout.

## Action Classes

Business logic lives in Action classes extending `AbstractAction` (sync)
or `AbstractAsyncAction` (queued) from the internal `harrym/domain-support`
package, dispatched via Laravel's `Dispatchable` bus — not called as plain
services or instantiated-and-invoked directly.

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

- Constructor-inject everything the action needs; `handle()` takes no
  arguments and does the work, wrapped in `DB::transaction()` when it
  writes.
- Invoke with `dispatch_sync(new AssignTicket($ticket, $assigneeId))` from
  sync contexts (controllers, tests) or `dispatch(new SomeAsyncAction(...))`
  when it should queue (extend `AbstractAsyncAction`, which already
  implements `ShouldQueue`).
- There is no separate `app/Jobs` directory and no Horizon in this stack —
  queued work is an `AbstractAsyncAction`, not a standalone job class. If a
  project later adds Horizon, async actions still own the business logic;
  Horizon only changes how the queue is monitored/dispatched.
- Business-rule violations are domain exceptions thrown with `throw_if()`/
  `throw_unless()` inside the action (e.g. `TicketException::cannotAssignClosed()`),
  not generic `abort()` calls.

## Authorization: Permission Middleware + Inline Checks

There are **no Laravel Policies** and **no static `canX()` gate methods**
on action classes. Authorization is:

1. **Route-method-level**, via a `requiresPermissions()` call in the
   controller constructor (from the `HasPermissionMiddleware` trait),
   mapping a `Permission` backed enum to controller methods:

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
   method — every domain controller needs this in its constructor; a
   controller with no `requiresPermissions()` call is a red flag, not an
   oversight to leave alone.

2. **Inline row/field-level checks**, using `$user->can()` directly
   against the same `Permission` enum, for authorization that can't be
   expressed as a blanket per-method rule:
   ```php
   abort_if($authUser->isNot($user) && ! $authUser->can(Permission::EDIT_USER->value), 403);
   ```

3. **Business-rule guards** (as opposed to permission checks) are
   `throw_if()`/`throw_unless()` against domain exceptions inside the
   Action class itself — see above. Don't put business-rule branching in
   the controller or the permission check.

`Permission` enums are backed PHP enums, one per domain
(`App\Domains\{Domain}\Enums\Permission`), whose values are the Spatie
Permission names.

## Repository + Criteria (not Spatie Query Builder)

This stack does not use `spatie/laravel-query-builder`. Filtering/sorting
goes through a hand-rolled Repository + Criteria pair from
`harrym/domain-support`:

```php
final class TicketCriteria extends AbstractCriteria
{
    public function __construct(
        ?string $search = null, ?string $sort_column = null, ?string $sort_order = null,
        ?int $per_page = null, ?int $limit = null,
        public ?string $status = null,
        public ?string $priority = null,
        public ?int $requester_id = null,
    ) {
        parent::__construct($search, $sort_column, $sort_order, $per_page, $limit);
    }
}

final class TicketRepository extends AbstractRepository
{
    protected string $model = Ticket::class;
    protected ?array $searchableColumns = ['subject', 'number'];
    protected ?array $with = ['requester', 'assignee'];
    protected bool $useScout = true;

    public function status(string $status): static
    {
        $this->query->where('status', $status);
        return $this;
    }

    public function priority(string $priority): static { /* ... */ return $this; }
}
```

- `Criteria` is a plain DTO of allowed filter/sort params; `Repository`
  gets constructed with it (`new TicketRepository(TicketCriteria::from($request))`)
  and `AbstractRepository::makeQuery()` reflects over the criteria to call
  the matching method (camelCased) if one exists.
- Every allowed filter is an explicit method on the repository — same
  discipline as Query Builder's `allowedFilters()`, just hand-written.
  Adding a filterable column means adding a method, not opening the query
  up generically.
- `$with` is declared once on the repository so eager loading isn't
  scattered across call sites — check it before adding a new relation
  access in a Resource/serializer.
- Set `$searchableColumns` and `$useScout` when the domain is Meilisearch-
  indexed; the repository's `search()` picks Scout vs. a Postgres
  `ilike`/`LOWER() LIKE` fallback automatically.

## PostgreSQL Conventions

- `snake_case` columns, plural table names (`tickets`, `ticket_comments`).
- Foreign keys via `$table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();`
  — Laravel's `foreignId()`/`constrained()` helpers, `_id` suffix.
- Boolean columns are prefixed `is_` (e.g. `is_blocked`), cast to
  `'boolean'` in the model's `casts()`.
- **Timestamps are timezone-aware**: use `$table->timestampsTz()` and
  `$table->softDeletesTz()`, never the plain (non-`Tz`) variants. Extra
  event timestamps follow `{event}_at`, also `timestampTz()`.
- Status/enum-like columns are plain `string` columns backed by either a
  PHP backed enum or a `spatie/laravel-model-states` state machine on the
  model side — not native Postgres `ENUM` types:
  ```php
  $table->string('employment_status')->default(EmploymentStatus::ACTIVE->value);
  ```
  Use `spatie/laravel-model-states` (`App\Domains\{Domain}\States\{Model}\...`)
  when the column has real state-machine transitions (e.g. Ticket's
  `Open → InProgress → Closed`), checked with `instanceof` and moved with
  `$model->status->transitionTo(InProgress::class)`. Use a plain backed
  enum when it's just a fixed set of values with no transition logic.
- Add explicit `$table->index(...)` on any column a Repository filters on.
- Migration filenames: `YYYY_MM_DD_HHMMSS_create_x_table.php`.

## Spatie Packages Actually In Use

- **`spatie/laravel-permission`** — `HasRoles` on the `User` model;
  authorization checks per above (permission middleware + `$user->can()`).
- **`spatie/laravel-model-states`** — status/state-machine columns, see above.
- **`spatie/laravel-data`** — DTOs for request payloads and API responses
  (`TicketData`, `PaginatedDataCollection`, etc.), used pervasively;
  prefer a `spatie/laravel-data` object over an ad-hoc array/Resource when
  shaping input or output.
- **`spatie/laravel-query-builder`** and **`spatie/laravel-medialibrary`**
  are **not** part of this stack — don't reach for them. Filtering goes
  through Repository+Criteria (above); file/attachment handling is a
  custom domain model (`app/Domains/Attachment/*`), not Media Library.

## Code Style Enforcement

- Every PHP file starts with `declare(strict_types=1);` — enforced by
  Pint, don't skip it on new files.
- `configs/php/pint.json` / `configs/php/rector-base.php` in this harness
  repo mirror `vindo-api`'s actual `pint.json`/`rector.php` — sync those
  rather than hand-configuring per project. Larastan (`larastan/larastan`)
  runs at level 9 in `vindo-api`; match that level for new projects unless
  there's a reason to start lower.
