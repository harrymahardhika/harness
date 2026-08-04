// Shared ESLint flat config base for Vue 3 + TypeScript projects.
//
// Exported as an array so a project spreads it into its own flat config
// and layers project-specific overrides after it:
//
//   // eslint.config.js
//   import harnessBase from './harness/configs/js/eslint.config.base.js'
//
//   export default [
//     ...harnessBase,
//     {
//       rules: {
//         // project-specific overrides
//       },
//     },
//   ]
//
// Requires (pnpm add -D): eslint, typescript-eslint, eslint-plugin-vue,
// vue-eslint-parser, @vue/eslint-config-typescript (peer of eslint-plugin-vue).

import js from '@eslint/js'
import pluginVue from 'eslint-plugin-vue'
import tseslint from 'typescript-eslint'

export default [
  js.configs.recommended,
  ...tseslint.configs.recommended,
  ...pluginVue.configs['flat/recommended'],
  {
    languageOptions: {
      parserOptions: {
        parser: tseslint.parser,
        sourceType: 'module',
        ecmaVersion: 'latest',
      },
    },
    rules: {
      // Composition API only — see claude/vue/vue.md. These two catch the
      // most common Options-API regressions.
      'vue/no-deprecated-data-object-declaration': 'error',
      'vue/component-api-style': ['error', ['script-setup']],

      // `as const` over TS enums (see claude/vue/vue.md) — ESLint can't
      // fully police "don't use enum", so this is enforced in review.
      '@typescript-eslint/no-explicit-any': 'warn',
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      '@typescript-eslint/consistent-type-imports': 'error',

      'vue/multi-word-component-names': 'off',
      'vue/require-default-prop': 'off',
      'vue/attributes-order': 'warn',
      'vue/no-unused-vars': 'error',
    },
  },
  {
    ignores: ['dist/**', 'node_modules/**', 'vendor/**', 'bootstrap/cache/**', '*.blade.php'],
  },
]
