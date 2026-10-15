---
name: complete-change
description: Finish a feature or task properly - every touched repo's suites, the publish chain, the specs synced and the OpenSpec change archived, the project's full acceptance suites green on the final code, then commit, push and CI. Use when the work is done, or the user says to finish, complete, wrap up or ship a feature, task or change.
---

Finish a change in a tn-layer project. A change is not done, committed, pushed or archived as done until every suite that
could have been affected is green on the final code, and that includes the project's full acceptance suites, unless the
user says otherwise for this change. This skill is the order to do it in; it does not replace judgment. Stop and tell the
user when something fails and the cause is not clear.

**Project specifics come from the project.** Which suites are the acceptance suites, how to run them, their
prerequisites, and the order repos publish in are in the project's own `CLAUDE.md` (a "Finishing a change" section) or its
README. Read them first. If the project names no acceptance suites, say so and treat its repos' own suites as the bar.

**Input**: the change or task name (for an OpenSpec project, `openspec list --json` if it is not clear). Announce it:
"Finishing: <name>".

## Steps

1. **Check the work is really done.**
   - Every task is ticked, and each task's stated verification was run, not assumed.
   - What was built still matches the proposal, design and delta specs. Where it moved on (a behaviour added or changed
     while building), update the artifacts and give the new behaviour a scenario, so the specs say what the system does.
     Validate the change (`openspec validate <change> --strict`).
   - Any inventory the project keeps (a registry, a catalog) matches components added or changed.

2. **Run each touched repo's own suites** and get them green before going further: unit, integration and, for a service,
   contract tests (`mvn verify` from a clean `target` when stubs matter: an incremental build can say "stubs are up to
   date" and ship old ones); typecheck, lint and tests for TypeScript repos. Fix failures at the cause. Never skip or
   weaken a test to pass.

3. **Publish in dependency order, testing each consumer against the published version.** Push, wait for CI green, pull
   the release commit for the new version, then bump the consumer and test it: a service's stubs before the service that
   consumes them, a library before the app, the app before its front ends. The project says what its chain is. Commit
   messages use conventional types: `feat` and `fix` release, so choose them on purpose. Add the trailer the session
   asks for. Do not copy unpublished builds into a consumer to make it pass; install the real package. Do not enter
   credentials or tokens for the user (a registry or `docker login`); say what to run.

4. **Sync the specs and archive the change** (OpenSpec projects: the `openspec-archive-change` skill or `/opsx:archive`),
   before the final acceptance run, because an acceptance coverage check usually reads the main specs:
   - Merge the delta specs into the main specs (sync, then verify each capability reads as synced), then archive.
   - Distil as the project's OpenSpec config says: keep the why, cross-component rules, domain meaning and lessons; do
     not copy the change in; leave the archived folder as history; do not rework earlier archives.
   - Validate the specs. Archiving stays local until step 7; if the acceptance run fails, fix the cause and leave the
     archive as it is.
   - Do not archive a change with unfinished tasks without the user's say-so.

5. **Run the project's full acceptance suites on the final code**, every platform it has, in full, against images or
   builds made from the final code. Note anything the run needs first (registry logins, a JDK, an emulator). Long runs
   are normal: start early, let them finish, and do not stop or narrow one to finish sooner without the user saying so.
   Say plainly anything that was not run.

6. **Triage every failure; never retry until green.** Decide which it is, and say so:
   - *the change* - fix the code;
   - *a stale scenario or helper* - the app changed and the acceptance steps did not (an element renamed, a screen merged
     into another, a form that now keeps its state): fix the helper or the scenario, or the app if the old behaviour was
     right;
   - *the environment* - an image that does not hold the code you think it does, a hung emulator, a missing login: fix
     it, or tell the user what they need to do.
   Calling a failure pre-existing needs evidence that it fails the same way without the change. Rerun fixes with a subset
   or `--last-failed`, but finish with one full run on the final code.

7. **Commit, push and wait for green builds.** Only when everything above is green. Commit each repo, pull with rebase,
   push, and wait for each repo's CI using the session's watchers, not a polling loop. Include the platform or spec repo:
   the archived change, the synced specs, and any inventory, guidance or config changes.

8. **Tear down and report.** Remove kept test environments and stop emulators or servers you started. Then report
   plainly: what changed in each repo and its version, which suites ran and their totals, anything not run or left open,
   and anything the user has to do.

## Guardrails

- Green means a suite ran in full on the final code and passed. A subset, an old run, or a rerun of only the failures is
  not green.
- The user's instruction wins: if they say to skip a suite or to stop, do that and record it in the report.
- Keep generated skills (such as the `openspec-*` ones) as they are; the CLI regenerates them.
