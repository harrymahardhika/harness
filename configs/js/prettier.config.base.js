// Shared Prettier config base for Vue 3 + TypeScript / Laravel projects.
//
// Exported as an object so a project spreads it and overrides selectively:
//
//   // prettier.config.js
//   import harnessBase from './harness/configs/js/prettier.config.base.js'
//
//   export default {
//     ...harnessBase,
//     tabWidth: 4, // project-specific override
//   }
//
// Requires (pnpm add -D): prettier, prettier-plugin-tailwindcss.

export default {
  semi: false,
  singleQuote: true,
  trailingComma: 'all',
  printWidth: 100,
  tabWidth: 2,
  useTabs: false,
  arrowParens: 'always',
  bracketSpacing: true,
  vueIndentScriptAndStyle: false,
  endOfLine: 'lf',

  // Sorts Tailwind classes into the canonical order automatically.
  // https://github.com/tailwindlabs/prettier-plugin-tailwindcss
  plugins: ['prettier-plugin-tailwindcss'],

  overrides: [
    {
      files: '*.vue',
      options: {
        parser: 'vue',
      },
    },
  ],
}
