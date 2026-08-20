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

`Permission` enums are backed PHP enums, one per domain
(`App\Domains\{Domain}\Enums\Permission`). Their values are the Spatie
Permission names.

## Repository + Criteria (not Spatie Query Builder)

This stack does not use `spatie/laravel-query-builder`. Handle
filtering/sorting through a hand-rolled Repository + Criteria pair from
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

- `Criteria` is a plain DTO of allowed filter/sort params. Construct the
  `Repository` with it (`new TicketRepository(TicketCriteria::from($request))`).
  `AbstractRepository::makeQuery()` reflects over the criteria to call
  the matching method (camelCased) if one exists.
- Every allowed filter is an explicit method on the repository. This is
  the same discipline as Query Builder's `allowedFilters()`, just
  hand-written. Adding a filterable column means adding a method, not
  opening the query up generically.
- Declare `$with` once on the repository so eager loading is not
  scattered across call sites. Check it before adding a new relation
  access in a Resource/serializer.
- Set `$searchableColumns` and `$useScout` when the domain is
  Meilisearch-indexed. The repository's `search()` picks Scout vs. a
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

### Do Not Duplicate HTTP Coverage in Unit Tests

- If an HTTP/feature test already exercises a code path end-to-end
  (controller → Action → Repository → response), do not also write a Unit
  test that re-covers the same behavior. It is redundant coverage that
  doubles maintenance cost without catching anything new.
- Write a Unit test only when the HTTP test genuinely cannot reach the
  thing you are testing:
  - Logic isolated enough that an HTTP round-trip is the wrong tool for
    it. For example: a value object, a DTO transform, a state-machine
    edge case, a helper/formatter. Asserting the narrow behavior
    directly is clearer than inferring it from a response body.
  - The scenario needs mocking/faking (`Http::fake()`, `Queue::fake()`,
    `Bus::fake()`, `Notification::fake()`, a mocked external service or
    time) to isolate from a dependency an HTTP test would otherwise hit
    for real, or to assert something was dispatched/called rather than
    its downstream effect.
- When in doubt, check whether an existing Feature test already covers
  the path before adding a new Unit test. Do not assume one is missing
  without looking.

### Test Suite Setup

- Use Pest for the test suite. Put feature tests under `tests/Feature/`
  and unit tests under `tests/Unit/`.
- Use `RefreshDatabase` with SQLite `:memory:` for the test database.
  `phpunit.xml` `<env>` values win over `.env.testing` (which points at
  pgsql/redis). Do not treat `.env.testing`'s connection settings as
  the ones actually in effect during a test run.
- Migrate the schema once per test process, not once per test. Each
  test then runs inside a transaction that rolls back at teardown.
- Define factories in `database/factories/`. Models use the `#[Table]`
  and `#[Fillable]` attributes.

### Seed roles and permissions once per process

A `createUser(attributes?, role?, permissions?)` test helper that calls
`assignRole()` / `givePermissionTo()` requires role and permission rows
to already exist in the database. An `app:rebuild-roles-and-permissions`
command (or equivalent) makes those rows from the `Role`/`Permission`
enums.

Do not run that rebuild command in a Pest `beforeEach`. At roughly 150
queries per invocation, running it per test (hundreds of tests) adds
minutes to the suite.

Run it once per test process instead, hooked into the migration step:

- Apply `RefreshDatabase` directly in `tests/TestCase.php` (not through
  `pest()->use()`), alias the trait's `migrateDatabases` method, and run
  the rebuild command right after `migrate:fresh`.
- `RefreshDatabase::refreshTestDatabase()` caches the in-memory PDO
  connection after `migrateDatabases()` returns. The seeded roles
  become part of the committed baseline every test rolls back to. Every
  test still sees roles and permissions; nothing leaks between tests.

Do not run the rebuild command inside `refreshTestDatabase()` after
`beginDatabaseTransaction()`. That inserts the rows inside the first
test's own transaction, and they roll back at that test's teardown,
leaving every later test without roles and permissions.

### Common test patterns

- Build the permission array and pass it to `createUser()` for
  authorized tests:
  ```php
  $user = createUser(permissions: [Permission::READ_TICKET->value]);
  ```
- Assign a role when the test exercises role-based behavior:
  ```php
  $user = createUser(role: Role::TECHNICIAN->value, permissions: [...]);
  ```
- Feature tests hit the HTTP route end-to-end (controller → Action →
  Repository → response), matching the `requiresPermissions()`
  constructor gate under test.
- Assert JSON responses with `assertJsonPath()`. Assert domain logic
  (state transitions, number generation, DTO transforms) in unit tests.
- Fake external calls with `Http::fake()` (for example WAHA) and
  `Notification::fake()` (notification channels).

### Running tests

- `php artisan test --compact` runs the full suite.
- `php artisan test --compact --filter=testName` runs a focused subset.
- `php artisan test --compact tests/Feature/Domains/Ticket/Controllers/TicketControllerTest.php`
  runs one file.
- Run only the tests relevant to the change in progress. Reserve the
  full suite for before merge or CI.

## Code Style Enforcement

- Start every PHP file with `declare(strict_types=1);`. Pint enforces
  this, so do not skip it on new files.
- Use `configs/php/pint.json` / `configs/php/rector-base.php` in this
  harness repo. They mirror `vindo-api`'s actual
  `pint.json`/`rector.php`. Sync those rather than hand-configuring per
  project. Larastan (`larastan/larastan`) runs at level 9 in `vindo-api`.
  Match that level for new projects unless there is a reason to start
  lower.
