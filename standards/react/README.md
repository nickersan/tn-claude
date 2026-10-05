# React standard

Applies to `react-web` components. Builds on [`typescript/`](../typescript/README.md)
for tooling, `tsconfig`, layout and linting shared with `native-ui` and client
libraries; this file covers what's React-specific. The reference implementation is
`okayat-web`.

## Framework and build

- **Vite + React + React Router**, a single-page app. All data comes from a BFF
  through the project's `typescript-client-library` (e.g. `okayat-client`), so
  there's no server rendering, and the build is static files.
- **The app calls the BFF on its own origin.** The Vite dev server proxies `/v1`
  to the BFF (`BFF_URL`, read with Vite's `loadEnv`), and the deployed container
  does the same. The BFF needs no CORS configuration.
- The app never calls a BFF endpoint directly; if the client lacks something, add
  it to the client.
- The client package comes from GitHub Packages. The project `.npmrc` reads the
  token from `NODE_AUTH_TOKEN`, so no secret is committed.

## Structure

- **Folders by feature** (`spots/`, `tags/`, `login/`), plus `app/`
  (services, query keys, error text), `session/`, `shell/` and `components/` for
  shared parts. A feature's page, hooks and pure logic (validation, cache patches)
  sit together, with the pure logic in plain `.ts` files.
- **Services through context, not imports.** One `createServices()` builds the
  client and session store, and a context provides them, so tests swap in a fake
  `fetch` and `EventSource` without module mocking.
- **Session state** lives in a small framework-free store (`localStorage` plus
  change notification), read with `useSyncExternalStore`.

## Data

- **TanStack Query** for all server state: `useQuery` for reads, `useMutation`
  for changes, `useInfiniteQuery` for feeds.
- **Query keys are defined in one module** (`app/queryKeys.ts`), so live updates
  patch exactly what screens read.
- **Live updates patch the cache** (`setQueryData`) from one app-wide event
  subscription, rather than refetching. Invalidate only where a patch can't be
  right (e.g. whether a new item matches a search).
- **After a change, update or invalidate what it affects**, including history and
  lists that depend on it.
- **Connection failures are one app-wide banner; other errors sit beside what
  failed.** The query and mutation caches report every outcome to a connection
  status. Not reaching the BFF, or a 502, 503 or 504 from it, shows the banner, and
  the next success clears it. While it shows, every operation on the page is
  disabled (the content sits in a disabled `fieldset`), so it can't be dismissed:
  it's what explains why. Screens show errors through `ErrorMessage`, which stays
  silent for connection failures, so the same failure isn't repeated in several
  places.
- **Anything platform-specific is injected**, as in the client.

## Styling

- **CSS Modules**, one per component, plus `styles/ui.module.css` for shared
  controls (buttons, fields, panels, errors).
- **Design tokens as CSS variables** in `styles/tokens.css`: colours from the
  project's palette, never hard-coded in components. Add a token rather than a
  literal when something new is needed.
- **Accessible by construction.** Every input has a label. Hints and errors are
  linked with `aria-describedby`, not placed inside the label (use `TextField`).
  Regions and lists have names, and errors use `role="alert"`.

## Testing

- **Component tests** with Vitest, Testing Library and `user-event`, in `jsdom`.
  They render the whole app at a path (`renderApp`) against a fake BFF (routing
  by method and path, recording requests) and a fake event stream. They query by
  role and label, as a user would, not by class or test id.
- **Test what the spec says the user sees**, including a control *not* shown to
  someone not allowed to use it.
- Server state updates asynchronously, so assert with `findBy…` or `waitFor`
  after an action, not `getBy…`.
- **Manual and end-to-end checks against running services** (two browser
  sessions, a real rollback) belong to the project's acceptance suite and task
  verification, not component tests.
