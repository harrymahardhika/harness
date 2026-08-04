// Shared ESLint flat config base for Vue 3 + TypeScript projects, mirroring
// `vindo-app`'s actual `eslint.config.ts`: eslint-plugin-vue at the
// `flat/essential` level (not recommended/strict), oxlint delegated a
// category of fast rules via eslint-plugin-oxlint, and
// eslint-config-prettier turning off any formatting-related rules since
// Prettier owns formatting.
//
// Exported as an array so a project spreads it into its own flat config:
//
//   // eslint.config.ts
//   import { globalIgnores } from 'eslint/config'
//   import harnessBase from './harness/configs/ts/eslint.config.base.ts'
//
//   export default [
//     ...harnessBase,
//     globalIgnores(['src/components/ui/**']), // generated/vendored code
//     {
//       rules: {
//         // project-specific overrides
//       },
//     },
//   ]
//
// Requires (pnpm add -D): eslint, @vue/eslint-config-typescript,
// eslint-plugin-vue, eslint-plugin-oxlint, oxlint, eslint-config-prettier.
// eslint-plugin-oxlint also needs an `.oxlintrc.json` in the project root
// (see configs/ts/oxlint.config.base.json in this harness repo).

import { defineConfigWithVueTs, vueTsConfigs } from '@vue/eslint-config-typescript'
import pluginVue from 'eslint-plugin-vue'
import pluginOxlint from 'eslint-plugin-oxlint'
import skipFormatting from 'eslint-config-prettier/flat'

export default defineConfigWithVueTs(
  {
    name: 'app/files-to-lint',
    files: ['**/*.{vue,ts,mts,tsx}'],
  },

  ...pluginVue.configs['flat/essential'],
  vueTsConfigs.recommended,
  {
    rules: {
      // Short/single-word component names are common here (shadcn-vue
      // primitives, small app components) — matches vindo-app.
      'vue/multi-word-component-names': 'off',
    },
  },

  // Delegates a category of fast correctness rules to oxlint instead of
  // duplicating them here — see .oxlintrc.json.
  ...pluginOxlint.buildFromOxlintConfigFile('.oxlintrc.json'),

  skipFormatting,
)
