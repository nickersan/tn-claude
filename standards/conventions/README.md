# General conventions

Status: **mostly placeholder** — the documentation, archiving and Comments sections
are drafted below; the rest is still to be written.

Cross-cutting conventions that apply to every component regardless of technology:

- Repository naming (`tn-*`, `<project>-*`, `<project>-platform`, `<project>-acceptance`).
- Component `component.yaml` shape (`name`, `layer`, `type`).
- Branch model, commit message format (Conventional Commits), PR expectations.
- README structure, `CLAUDE.md` expectations for component repos.
- Documentation and ADR location.

To be written. Where a rule already exists implicitly in `tn-lang` / `tn-query`
(e.g. Conventional Commits, `develop` + `main` branch model, GitHub Packages), distil
it from there rather than inventing.

## The code documents the system

**The code base is the primary description of what the system does.** Specs drive
the work, but once a feature is built, its behaviour should be readable from the
code: names that say what things are and do, small composed methods, structure that
mirrors the domain. That doesn't mean more comments (see below). It means code clear
enough that it doesn't need them.

**Scenarios live in tests.** A spec's scenarios should be captured as tests whose
names and structure read as those scenarios ("rejects removing the last
administrator", "passes the caller's token on unchanged"). The tests then document
the behaviour and verify it, and they can't drift from the code the way prose can.

## Specs after archiving — keep the master set minimal

Archiving a change merges its specs into the master set
(`openspec/specs/...`). Treat that as a distilling step, not a copy: keep only the
knowledge the code can't carry. That includes:
- **Why:** the intent behind a rule, the decision taken, and the alternatives
  rejected, where the code shows only the outcome.
- **Rules and guarantees that span components**, which no single file shows (a
  token verified at every hop, never removing the last administrator, even under
  concurrency).
- **Domain meaning and boundaries:** what a concept is, what's deliberately out of
  scope, and what's deferred.
- **Lessons from implementation** that shaped the result but aren't visible in it.

Keep requirements as short statements of behaviour: the contract the tests verify.
Keep a scenario only where it pins down a rule the tests don't make obvious, and
drop any that just restate a test. Leave out anything the code or tests already
say: paths, field lists, step-by-step flows.

This applies to the documents the archive updates. An archived change's own folder
(proposal, design, tasks, delta specs) is the historical record and stays as it is.
System-level documents (a project's `config.yaml` context, `registry.yaml`, the
catalog) stay at system level. Apply this going forward, whenever a change is
archived, rather than reworking specs already archived.

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
