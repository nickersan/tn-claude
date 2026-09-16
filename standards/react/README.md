# React standard

Status: **placeholder**.

Applies to `react-web` components (and shared UI conventions for other web UIs).
Builds on [`typescript/`](../typescript/README.md) for language-level conventions
shared with `native-ui` and plain client libraries; this file covers what's
React-specific.

No React code exists in the `tn` layer yet, so this will be written fresh when the
first project web UI is created (candidate: `okayat-web`) — at which point the
decisions below need to be made and recorded here:

- Build tool and framework (Vite / Next.js / Remix), package manager, Node version
  policy.
- Component structure, state management, data fetching.
- Styling approach.
- Testing: unit (Vitest/Jest + Testing Library), component, and where contract /
  end-to-end coverage sits relative to `<project>-acceptance`.
- Linting / formatting (ESLint + Prettier) and how it is enforced in CI.
- Packaging and container build for Kubernetes.
