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
- `templates/`, `.claude/skills/`, `docs/architecture/` — placeholders for now.

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

## Scope of the current draft

Java and Maven standards are written. `conventions/`, `spring-boot/`, `react/`,
`database/` and `kubernetes/` are placeholders — flesh them out only when a component
of that type is being created, and distil from real code where it exists.
