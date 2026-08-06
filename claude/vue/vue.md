---
paths: ["**/*.vue", "resources/js/**/*.ts", "src/**/*.ts"]
---

# Vue 3 Conventions

Reflects the actual setup in `vindo-app` (Vue 3 + Tailwind v4 + shadcn-vue +
Pinia, pnpm-managed).

## Composition API Only

- `<script setup lang="ts">` for every component you hand-write. No
  Options API, no mixins — composables under `src/composables/` for
  shared logic.
- The one standing exception: shadcn-vue's generated primitives under
  `src/components/ui/**` — those are vendored/generated code, excluded
  from lint (`globalIgnores(['src/components/ui/**'])`), and not held to
  these conventions since you don't hand-edit them.
- Props/emits use the generic typed form exclusively:
  ```ts
  const props = defineProps<{ ticket?: Ticket | null }>()
  const emit = defineEmits<{ close: [] }>()
  ```
  Never the runtime array/object form (`defineProps(['x'])`).
- Default to `ref`; reach for `reactive` only for a handful of genuinely
  cohesive local state (it's rare in practice — don't make it the default).

## Pinia: Setup-Store Syntax

- Every store is a setup store (function form), never the options-object
  form:
  ```ts
  export const useTicketStore = defineStore('ticket', () => {
    const { entities, selected, meta, links, loading, refetch, notFound } = useEntity<Ticket>()
    return { entities, selected, meta, links, loading, refetch, notFound }
  })
  ```
- Prefer composing a store out of a shared composable (e.g. `useEntity<T>()`
  for list/detail/pagination state) over reimplementing the same
  fetch/loading/pagination shape per store.
- Store filenames are kebab-case (`ticket.ts`, `work-order.ts`), matching
  the domain, not the exported symbol.

## Tailwind v4: CSS-Based Theme, No `tailwind.config`

- This stack is Tailwind v4 — there is no `tailwind.config.js/ts`. Design
  tokens (colors, radius, fonts) are defined as CSS custom properties in
  `src/style.css` via `@theme inline { ... }`, using `oklch()` color
  values, following the shadcn-vue v4 convention. When adding a new
  token, add it there — don't add a config file that won't be read.
- Compose classes with the project's `cn()` helper
  (`clsx` + `tailwind-merge`, from `src/lib/utils.ts`) rather than raw
  template-literal concatenation:
  ```ts
  import { cn } from '@/lib/utils'
  cn('flex items-center gap-2', isActive && 'bg-primary text-primary-foreground')
  ```
- **`class-variance-authority` (cva) is reserved for `src/components/ui/**`**
  (the shadcn-vue generated primitives that define variant APIs). App-level
  feature components consume those primitives and compose classes with
  `cn()` — don't introduce `cva` in a feature component; that's a signal
  the variant belongs in a primitive instead.
- Arbitrary-value utilities (`w-[...]`) are fine when they're structural
  (`grid-cols-[1fr_auto]`, `w-[calc(100vw-2rem)]`, attribute selectors like
  `[&_svg:not([class*=size-])]:size-4`) — that's normal here. What to avoid
  is a one-off magic pixel value (`w-[137px]`) where an existing spacing
  token already covers it.
- No class-sorting plugin is configured (no `prettier-plugin-tailwindcss`)
  — class order isn't auto-enforced, just keep it loosely grouped
  (layout → spacing → color → state variants) for readability.

## `as const` Over TS Enums

- No `enum`/`const enum` anywhere in `src/`. Status/kind value sets are
  `as const` object maps:
  ```ts
  const TicketPriority = {
    LOW: 'low',
    MEDIUM: 'medium',
    HIGH: 'high',
    URGENT: 'urgent',
  } as const

  export default TicketPriority
  ```
- In `vindo-app`, files under `src/constants/*.ts` are **generated** from
  the Laravel backend (`php artisan app:generate-constants`) and carry a
  `// Generated file, do not manually edit` header — if you see that
  header, edit the backend enum and regenerate, don't hand-edit the
  constant. Ad-hoc `as const` maps outside `constants/` (not generated)
  are fine to hand-write the same way.

## Composable Naming (soft rule)

- Prefer a `useX.ts` filename for new composables (`useDeviceSize.ts` is
  the pattern to follow), but don't rename existing plain-noun composable
  files (`app.ts`, `fetch.ts`, `entity.ts`) just to enforce this — the
  existing codebase is inconsistent here and it's not worth the churn.
  New composables should still use `useX` for both the filename and the
  exported function.

## Test Location

- Tests live under a top-level `tests/` directory (e.g. `tests/components/`,
  `tests/composables/`, mirroring the `src/` structure), not colocated
  next to the source file. Don't create `Component.spec.ts` /
  `Component.test.ts` alongside `Component.vue` — put it under `tests/`
  instead.

## API Communication

- No axios. HTTP goes through `@vueuse/core`'s `useFetch`, wrapped in
  `src/composables/fetch.ts` (auth header injection, 401 handling, error
  normalization). Resource-specific calls live in `src/api/{Resource}.ts`
  classes extending a base `Api` class (`get`, `paginate`, `show`,
  `store`, `update`, `destroy`, `pdf`), each exported as a singleton
  (`export default new TicketApi()`).

## Type Declarations

- All domain/shared types are hand-maintained as global ambient
  declarations in `src/types.d.ts` (not colocated per-feature, no import
  needed). Don't declare a domain `interface`/`type` inline in a
  component or composable, and don't start a parallel per-file
  convention (e.g. a `types.ts` next to a feature) — add it to
  `types.d.ts` instead. Purely local, non-reusable shapes (e.g. a
  one-off prop-destructuring helper type) are the only exception.
