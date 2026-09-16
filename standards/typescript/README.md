# TypeScript standard

Status: **placeholder**.

Framework-agnostic TypeScript conventions — for a `typescript-client-library`
component, and shared by `react-web` / `native-ui` components alongside their own
framework-specific standard (`react/`).

No TypeScript code exists yet. First real candidate: `okayat-client` (a package
capturing what a BFF provides, consumed by both a React web frontend and a React
Native/Expo app). Write this standard when that component is created. Expected
topics:

- `tsconfig` baseline (strictness, module resolution), shared across `react-web`,
  `native-ui` and plain client libraries.
- Package manager and workspace/monorepo tooling (if a single repo ever holds
  multiple TS packages).
- Linting/formatting (ESLint + Prettier) and how it's enforced in CI.
- API client conventions: how a client package is generated or hand-written from a
  BFF's contract, versioning, and how it's published/consumed by web and native.
- Testing (Vitest/Jest), coverage expectations.
