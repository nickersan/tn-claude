# General conventions

Status: **mostly placeholder** — one section (Comments) is drafted below; the rest
is still to be written.

Cross-cutting conventions that apply to every component regardless of technology:

- Repository naming (`tn-*`, `<project>-*`, `<project>-platform`, `<project>-acceptance`).
- Component `component.yaml` shape (`name`, `layer`, `type`).
- Branch model, commit message format (Conventional Commits), PR expectations.
- README structure, `CLAUDE.md` expectations for component repos.
- Documentation and ADR location.

To be written. Where a rule already exists implicitly in `tn-lang` / `tn-query`
(e.g. Conventional Commits, `develop` + `main` branch model, GitHub Packages), distil
it from there rather than inventing.

## Comments

**Code should be clear and minimal; a comment is only warranted when the code
cannot make its own intent clear.** Don't narrate what the code already says
(`// increment i` above `i++`); don't leave a comment as a substitute for a clearer
name or a smaller method. A comment earns its place when it explains a *why* the
code can't carry — a non-obvious constraint, a deliberate deviation from the
obvious approach, a reference to the external reason something is shaped the way it
is.

This is already how `tn-lang` and `tn-query` are written — see e.g. `Strings.java`,
`Iterables.java`, `DefaultQueryParser.java`, none of which carry a single comment.
This isn't a new rule so much as making an existing, unstated one explicit.
