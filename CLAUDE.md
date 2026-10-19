# tn-claude — working notes for Claude

This repo is the **shared foundation** for the `tn` layer and the projects above it.
It contains no production code. Do not add application logic here.

## What lives here

- `standards/` — the single declaration of engineering standards. Edit standards here
  and nowhere else. Keep every file human-readable and short; prefer several focused
  files over one large one.
- `standards/component-types.yaml` — maps a component `type` to the standard sets that
  apply to it. This is the contract other repos rely on.
- `openspec/` — capability contracts for `tn-*` services (schema `spec-driven`, the
  `@fission-ai/openspec` CLI). See `openspec/config.yaml` for how this differs from
  `standards/` and from a consuming project's own spec tree.
- `catalog.yaml` / `registry.yaml` — what the `tn` layer provides / which repos exist.
- `.claude-plugin/` and `skills/` — this repo is also the **`tn` Claude Code plugin**, so its skills run in every
  project as `/tn:<skill>`. `skills/complete-change` (`/tn:complete-change`) is how a feature or task is finished:
  every touched repo's suites, a review of the change against its spec and the standards, the publish chain, the specs synced and the change archived, the project's full
  acceptance suites green, then commit, push and CI. Keep skills project-neutral: what is particular to a project
  (its acceptance suites, prerequisites, publish order) belongs in that project's own `CLAUDE.md`. Install it once:
  `claude plugin marketplace add <path to this repo>`, then `claude plugin install tn@tn-claude`.
- `templates/`, `docs/architecture/` — placeholders for now.

## Ground rules

- **Never modify code in sibling `tn-*` repos from here.** This repo only describes,
  catalogues and specifies; it does not change components.
- Standards must reflect how the code is **actually written** in `tn-lang`, `tn-query`
  and `tn-parent`. When the code and a standard disagree, say so explicitly in the
  standard rather than silently picking one.
- When a rule has a known inconsistency in the existing code, document both the
  observed state and the intended direction, and mark it clearly.
- **A capability spec is not standards.** `openspec/specs/<service>/` describes what
  one `tn-*` service promises (testable, scenario-based). `standards/` describes how
  code is written across all of them. Don't blend the two, and don't write a
  capability spec for a service nobody has asked to change or depend on formally yet.
- **A project's `-platform` change may motivate a capability change here, but should
  not remain its source of truth.** Once a change in this tree is archived, update
  the requesting project's design.md to reference it instead of restating the
  contract (see that repo's own notes).
- **The code documents the system; the specs keep what it can't.** Archiving distils
  the master specs it updates rather than copying the change in, and scenarios are
  captured as tests (`standards/conventions/README.md`; `openspec/config.yaml`
  carries the matching rules and archive guidance).

## Scope of the current draft

Java and Maven standards are written. `conventions/`, `spring-boot/`, `react/`,
`database/` and `kubernetes/` are placeholders — flesh them out only when a component
of that type is being created, and distil from real code where it exists.
