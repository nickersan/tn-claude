# TypeScript standard

Framework-agnostic TypeScript conventions for a `typescript-client-library`
component, also followed by `react-web` and `native-ui` components alongside their
own framework standard (`react/`). The reference implementation is `okayat-client`.

## Tooling

- **npm**, one package per repository, like every other tn component (no
  monorepo). Commit `package-lock.json`.
- **TypeScript 5.9** (`~5.9.x`). TypeScript 7 (the native compiler) isn't supported
  by typescript-eslint or openapi-typescript yet; move when both support it.
- **Vitest** for tests, under `test/`, run with `npm test`.
- **ESLint** (flat config) with `typescript-eslint`'s `strict` rules and
  `@stylistic` for layout. **No Prettier**: it can't produce the layout below.
- A `verify` script runs everything CI and publishing need:
  `typecheck && lint && test && build`.

## `tsconfig`

`strict`, plus `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`,
`noImplicitOverride`, `isolatedModules` and `verbatimModuleSyntax`. Target
`ES2022`. Module resolution depends on what the code is:
- **A published library:** `module` and `moduleResolution: NodeNext`, so relative
  imports carry `.js` extensions and `dist` loads in Node as well as in bundlers.
  Consumers' test runners (Vitest) load dependencies through Node, so a library
  built with `Bundler` resolution breaks them. A separate `tsconfig.build.json`
  emits `dist` with declarations and source maps, and `verify` ends by importing
  `dist` in plain Node (`scripts/check-dist.mjs`).
- **An app** (`react-web`, `native-ui`), which only its own bundler reads:
  `module: ESNext` with `moduleResolution: Bundler`.

## Layout — the same as tn's Java

Enforced by `@stylistic` in `eslint.config.js`, matching
`standards/java/formatting.md`:
- Allman braces (single-line blocks allowed). Two-space indent. 180 columns.
- Double quotes, semicolons, no trailing commas.
- A single-statement `if` has no braces. If any branch of an if/else needs
  braces, all branches have them (`curly: multi-or-nest, consistent`).
- No trailing whitespace, and a final newline.

The naming, comment (`standards/conventions/README.md`) and composed-method
(`standards/java/idioms.md`) rules apply as in Java. Absence is `undefined` or an
optional property, never `null`.

## API clients — generated types, hand-written functions

A client for a service's HTTP API:
- **Types come from the service's OpenAPI document.** Commit a snapshot
  (`openapi.json`) and generate `src/generated/api.ts` with `openapi-typescript`
  (`npm run api:update` refreshes both from a running service). Never hand-write a
  type the document describes, and never edit generated files.
- **The service must describe itself fully.** Every always-present property is
  marked required, paging is documented as its real query parameters (springdoc
  `@ParameterObject`), and an absent optional property is omitted rather than sent
  as `null` (`spring.jackson.default-property-inclusion: non_null`). Otherwise the
  generated types are wrong. Fix the service, not the client.
- **Functions are small, hand-written wrappers around `fetch`**, grouped by
  resource, with no runtime dependency. Request paths are typed as `keyof paths`
  from the generated types, so a path the service no longer has fails to compile.
- **Errors** are one error class carrying the HTTP status, so callers branch on
  status (401, 403, 404, 409, 429).
- **Anything platform-specific is injectable**, with the global as the default:
  `fetch`, and `EventSource` (React Native has none).
- **Ids stay as the service sends them.** 64-bit ids are hex strings, never
  numbers (see a project's design decision on ids, e.g. okayat's Decision 26).

## Publishing

Published to GitHub Packages as `@nickersan/<name>`, with `.npmrc` mapping the
scope to `https://npm.pkg.github.com`. `prepublishOnly` runs `verify`. Only `dist`
is published (`files`).
