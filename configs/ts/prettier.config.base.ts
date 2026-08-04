// Shared Prettier config base for Vue 3 + TypeScript projects, matching
// `vindo-app`'s actual `.prettierrc.json` exactly: no semicolons, single
// quotes, 100 print width, no plugins. Tailwind classes are NOT
// auto-sorted in this stack (no prettier-plugin-tailwindcss) — see
// claude/vue/vue.md for why (class order is loosely grouped by hand).
//
// Exported as an object so a project spreads it and overrides selectively:
//
//   // prettier.config.ts
//   import harnessBase from './harness/configs/ts/prettier.config.base.ts'
//
//   export default {
//     ...harnessBase,
//   }
//
// Requires (pnpm add -D): prettier.

import type { Config } from 'prettier'

export default {
  semi: false,
  singleQuote: true,
  printWidth: 100,
} satisfies Config
