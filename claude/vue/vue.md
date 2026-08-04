---
paths: ["**/*.vue", "resources/js/**/*.ts"]
---

# Vue 3 Conventions

## Composition API Only

- `<script setup lang="ts">` for every component. Never use the Options
  API (`data()`, `methods:`, `computed:` object form) — if you encounter
  it, that's legacy to flag, not a pattern to extend.
- Prefer composables (`useX.ts` under `resources/js/composables/`) over
  mixins for shared logic. There should be no `mixins:` usage anywhere.
- Props/emits are typed with the `defineProps<T>()` / `defineEmits<T>()`
  generic form, not the runtime array/object declaration form:
  ```ts
  const props = defineProps<{ postId: number; readonly?: boolean }>()
  const emit = defineEmits<{ saved: [id: number] }>()
  ```
- Reach for `ref` by default; use `reactive` only for a genuinely
  cohesive object you always destructure/pass together, and never
  destructure a `reactive()` object directly (breaks reactivity) —
  use `toRefs()` if you must.

## Tailwind Utility Conventions

- Utility classes directly in templates; no scoped `<style>` blocks for
  anything Tailwind already expresses, unless it's a genuinely
  unrepresentable case (complex animation, third-party override).
- Use the project's `tailwind.config` design tokens (spacing, colors)
  instead of arbitrary-value utilities (`w-[137px]`) unless matching a
  one-off design spec — arbitrary values are a signal to add a token.
  instead.
- Group class strings by category (layout → spacing → typography →
  color → state) rather than alphabetically or randomly, so diffs stay
  readable. Use `clsx`/`cva` for conditional class composition instead
  of manual template-literal string concatenation.
- Co-locate responsive/state variants next to their base utility
  (`px-4 md:px-6`, not scattered across the class string).

## `as const` Over TS Enums

- Status/kind-like value sets are defined with `as const` + a derived
  union type, not `enum`:
  ```ts
  export const PostStatus = {
    Draft: 'draft',
    Published: 'published',
    Archived: 'archived',
  } as const

  export type PostStatus = (typeof PostStatus)[keyof typeof PostStatus]
  ```
- This keeps the runtime values as plain strings that match the PHP
  backed-enum values 1:1 across the API boundary — no numeric-enum
  serialization mismatches.
- Never introduce `enum` or `const enum` in new code under
  `resources/js/`; if one exists, prefer migrating it to `as const` when
  you're touching that file anyway rather than leaving it as the odd
  one out.
