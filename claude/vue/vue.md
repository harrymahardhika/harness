---
paths: ["**/*.vue", "resources/js/**/*.ts", "src/**/*.ts"]
---

# Vue 3 Conventions

This file reflects the actual setup in `vindo-app` (Vue 3 + Tailwind v4 +
shadcn-vue + Pinia, pnpm-managed).

## Composition API Only

- Use `<script setup lang="ts">` for every component you hand-write. Do
  not use Options API or mixins. Put shared logic in composables under
  `src/composables/`.
- The one standing exception: shadcn-vue's generated primitives under
  `src/components/ui/**`. Those are vendored/generated code, excluded
  from lint (`globalIgnores(['src/components/ui/**'])`), and not held to
  these conventions since you do not hand-edit them.
- **Do not hand-edit a primitive to fix a styling bug, even a trivial
  one**, including one that only shows up after a project-level style
  change (for example a contrast tweak in `src/style.css` clipping with
  a primitive's hardcoded classes). A hand-edit gets silently blown away
  the next time `shadcn-vue add` regenerates that primitive. Revert the
  primitive to stock output and apply the fix as global CSS in
  `src/style.css`, keyed off the primitive's stable `data-slot="..."`
  attribute (shadcn-vue primitives all carry one). That is a project
  file, so it survives regeneration.
- Use the generic typed form for props/emits exclusively:
  ```ts
  const props = defineProps<{ ticket?: Ticket | null }>()
  const emit = defineEmits<{ close: [] }>()
  ```
  Never use the runtime array/object form (`defineProps(['x'])`).
- Default to `ref`. Reach for `reactive` only for a handful of genuinely
  cohesive local state (it is rare in practice; do not make it the
  default).

## Pinia: Setup-Store Syntax

- Use the setup store (function form) for every store. Never use the
  options-object form:
  ```ts
  export const useTicketStore = defineStore('ticket', () => {
    const { entities, selected, meta, links, loading, refetch, notFound } = useEntity<Ticket>()
    return { entities, selected, meta, links, loading, refetch, notFound }
  })
  ```
- Prefer composing a store out of a shared composable (for example
  `useEntity<T>()` for list/detail/pagination state) over
  reimplementing the same fetch/loading/pagination shape per store.
- Name store files in kebab-case (`ticket.ts`, `work-order.ts`),
  matching the domain, not the exported symbol.

## Tailwind v4: CSS-Based Theme, No `tailwind.config`

- This stack is Tailwind v4. There is no `tailwind.config.js/ts`. Define
  design tokens (colors, radius, fonts) as CSS custom properties in
  `src/style.css` via `@theme inline { ... }`, using `oklch()` color
  values, following the shadcn-vue v4 convention. When adding a new
  token, add it there. Do not add a config file that will not be read.
- Compose classes with the project's `cn()` helper (`clsx` +
  `tailwind-merge`, from `src/lib/utils.ts`) rather than raw
  template-literal concatenation:
  ```ts
  import { cn } from '@/lib/utils'
  cn('flex items-center gap-2', isActive && 'bg-primary text-primary-foreground')
  ```
- **Reserve `class-variance-authority` (cva) for `src/components/ui/**`**
  (the shadcn-vue generated primitives that define variant APIs).
  App-level feature components consume those primitives and compose
  classes with `cn()`. Do not introduce `cva` in a feature component;
  that is a signal the variant belongs in a primitive instead.
- Arbitrary-value utilities (`w-[...]`) are fine when they are
  structural (`grid-cols-[1fr_auto]`, `w-[calc(100vw-2rem)]`, attribute
  selectors like `[&_svg:not([class*=size-])]:size-4`). That is normal
  here. Avoid a one-off magic pixel value (`w-[137px]`) where an
  existing spacing token already covers it.
- No class-sorting plugin is configured (no `prettier-plugin-tailwindcss`).
  Class order is not auto-enforced. Keep it loosely grouped
  (layout → spacing → color → state variants) for readability.

## `as const` Over TS Enums

- Do not use `enum`/`const enum` anywhere in `src/`. Status/kind value
  sets are `as const` object maps:
  ```ts
  const TicketPriority = {
    LOW: 'low',
    MEDIUM: 'medium',
    HIGH: 'high',
    URGENT: 'urgent',
  } as const

  export default TicketPriority
  ```
- In `vindo-app`, files under `src/constants/*.ts` are **generated**
  from the Laravel backend (`php artisan app:generate-constants`) and
  carry a `// Generated file, do not manually edit` header. If you see
  that header, edit the backend enum and regenerate. Do not hand-edit
  the constant. Ad-hoc `as const` maps outside `constants/` (not
  generated) are fine to hand-write the same way.

## Composable Naming (soft rule)

- Prefer a `useX.ts` filename for new composables (`useDeviceSize.ts` is
  the pattern to follow). Do not rename existing plain-noun composable
  files (`app.ts`, `fetch.ts`, `entity.ts`) just to enforce this. The
  existing codebase is inconsistent here and it is not worth the churn.
  New composables must still use `useX` for both the filename and the
  exported function.

## Test Location

- Put tests under a top-level `tests/` directory (for example
  `tests/components/`, `tests/composables/`, mirroring the `src/`
  structure). Do not colocate them next to the source file. Do not
  create `Component.spec.ts` / `Component.test.ts` alongside
  `Component.vue`. Put it under `tests/` instead.

## API Communication

- Do not use axios. Send HTTP through `@vueuse/core`'s `useFetch`,
  wrapped in `src/composables/fetch.ts` (auth header injection, 401
  handling, error normalization). Resource-specific calls live in
  `src/api/{Resource}.ts` classes extending a base `Api` class (`get`,
  `paginate`, `show`, `store`, `update`, `destroy`, `pdf`). Export each
  as a singleton (`export default new TicketApi()`).

## Type Declarations

- Hand-maintain all domain/shared types as global ambient declarations
  in `src/types.d.ts` (not colocated per-feature, no import needed). Do
  not declare a domain `interface`/`type` inline in a component or
  composable. Do not start a parallel per-file convention (for example a
  `types.ts` next to a feature). Add it to `types.d.ts` instead. Purely
  local, non-reusable shapes (for example a one-off prop-destructuring
  helper type) are the only exception.
