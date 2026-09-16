# tn-claude

The shared foundation for the `tn` layer and every project built on top of it.

`tn-claude` is not a code component. It holds the things that are declared **once** and
reused everywhere:

| Path | What it is |
|------|-----------|
| `standards/` | Human-readable engineering standards. Which ones apply to a component is decided by its `type` (see `standards/component-types.yaml`). |
| `openspec/` | Capability contracts for `tn-*` services — what a shared service promises, as testable Requirement/Scenario specs. Not product specs; see `openspec/config.yaml`. Backfilled incrementally, only as a service is touched. |
| `catalog.yaml` | The menu of capabilities the `tn` layer already provides. Projects read this when writing specs. Links to `openspec/specs/<id>` once a capability has a formal contract. |
| `registry.yaml` | Inventory of `tn`-layer component repos. |
| `templates/` | Repo skeletons per component type (placeholder for now). |
| `.claude/skills/` | Skills published as the `tn-claude` plugin (placeholder for now). |
| `docs/architecture/` | Cross-cutting architecture notes (placeholder for now). |

## How a component consumes this

- **Standards + skills** — via the `tn-claude` plugin, referenced once in the
  component repo's `.claude/settings.json`.
- **`tn` code** — as a normal Maven dependency, versions aligned by `com.tn:tn-parent`.
- **Available `tn` capabilities** — by reading `catalog.yaml`.

## Status

Initial draft. The **Java** and **Maven** standards are written; the other standard
areas are placeholders to be filled in as components of those types appear.

Standards here were distilled from the existing `tn-lang`, `tn-query` and `tn-parent`
projects. They describe how this codebase is actually written, not an aspiration
imported from elsewhere.
