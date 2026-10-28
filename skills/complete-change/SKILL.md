---
name: complete-change
description: Finish a feature or task properly - every touched repo's suites, a review of the change against its spec and the standards, the publish chain, the specs synced and the OpenSpec change archived, the project's full acceptance suites green on the final code, then commit locally, push in dependency order and CI. Use when the work is done, or the user says to finish, complete, wrap up or ship a feature, task or change.
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
   Check the JaCoCo report for each touched component: new or changed code is covered by that component's own tests,
   including wiring and lifecycle, never left for the acceptance suites to catch (see the Java testing standard).

3. **Review the change against the spec and the standards.** Always part of finishing, however small the change. Read the whole
   diff of every touched repo, in a fresh pass rather than from memory of writing it, and check:
   - *the spec*: each requirement and scenario of the change's delta specs is built, and a test named for it proves it; nothing was
     built that the specs do not say (if something was, the specs gain it, as in step 1); the proposal's "what changes" is all there;
   - *the standards*: the standard sets that apply to each component (`standards/component-types.yaml` in the tn layer, and the
     project's own conventions and `CLAUDE.md`) are followed - layout, naming, logging, error handling, dependencies, versions,
     migrations that never edit one already applied - and the surrounding code's idiom and comment density are matched;
   - *the code*: bugs, missing edge cases, leftovers (debug code, dead code, unused names), duplicated logic that should be shared,
     and secrets or personal data in code, tests or logs.
   Use `/code-review` for the correctness pass where it is available. Fix what the review finds, at the cause, and re-run the
   suites it touches (step 2); say in the report what was found and fixed. A review that finds nothing says what it covered.
4. **Integrate locally on `-SNAPSHOT` versions; push nothing yet.** The nightly builds run on another machine from what is
   pushed, so a repo pushed ahead of the others breaks them. Work through the touched repos in dependency order (a
   service's stubs before the service that consumes them, a library before the app, the app before its front ends; the
   project says what its chain is): set the repo's version to a `-SNAPSHOT` of the next release, `mvn install` it (a
   container repo's docker profile builds its image in the install phase, tagged with that version), point the consumer
   at the SNAPSHOT and test the consumer against it. Local acceptance and Kustomize may refer to the SNAPSHOT versions and
   image tags. Commit locally as each repo is finished. Do not copy unpublished builds into a consumer to make it pass.
   Commit messages use conventional types: `feat` and `fix` release, so choose them on purpose. Add the trailer the
   session asks for.

5. **Sync the specs and archive the change** (OpenSpec projects: the `openspec-archive-change` skill or `/opsx:archive`),
   before the final acceptance run, because an acceptance coverage check usually reads the main specs:
   - Merge the delta specs into the main specs (sync, then verify each capability reads as synced), then archive.
   - Distil as the project's OpenSpec config says: keep the why, cross-component rules, domain meaning and lessons; do
     not copy the change in; leave the archived folder as history; do not rework earlier archives.
   - Validate the specs. Archiving stays local until step 8; if the acceptance run fails, fix the cause and leave the
     archive as it is.
   - Do not archive a change with unfinished tasks without the user's say-so.

6. **Run the project's full acceptance suites on the final code**, every platform it has, in full, against images or
   builds made from the final code (SNAPSHOT builds are fine here; step 8 moves them to the released versions). Note anything the run needs first (registry logins, a JDK, an emulator). Long runs
   are normal: start early, let them finish, and do not stop or narrow one to finish sooner without the user saying so.
   Say plainly anything that was not run.

7. **Triage every failure; never retry until green.** Decide which it is, and say so:
   - *the change* - fix the code;
   - *a stale scenario or helper* - the app changed and the acceptance steps did not (an element renamed, a screen merged
     into another, a form that now keeps its state): fix the helper or the scenario, or the app if the old behaviour was
     right;
   - *the environment* - an image that does not hold the code you think it does, a hung emulator, a missing login: fix
     it, or tell the user what they need to do.
   Calling a failure pre-existing needs evidence that it fails the same way without the change. Rerun fixes with a subset
   or `--last-failed`, but finish with one full run on the final code.

8. **Release: push in dependency order and wait for CI at each repo.** Only when everything above is green in every touched
   repo. CI sets the version itself from the conventional commits since the last tag and ignores the one the pom
   declares, so for each repo, in the order of step 4:
   - put the version back to the one on `origin/main` (the last release), and replace every `-SNAPSHOT` dependency on a
     repo already released with its released version; a pushed pom never contains a SNAPSHOT of another repo;
   - commit, pull with rebase, push, and wait for the repo's CI to release (the session's watchers, not a polling loop),
     then pull the release commit. A service's release also pins itself in its `-container` repo and releases the image:
     wait for that too. Renovate may have moved a dependency in the meantime: rebase over it, do not fight it;
   - the next repo then builds against the released version, not the SNAPSHOT.
   Include the platform or spec repo: the archived change, the synced specs, and any inventory, guidance or config
   changes. Last, align Kustomize and the acceptance suite with the released versions and image tags (no SNAPSHOT left in
   either), push them, wait for their CI, and run the project's quick acceptance check against the released versions. Say
   what the full run on the SNAPSHOT builds covered and what was rerun on the released ones.

9. **Tear down and report.** Remove kept test environments and stop emulators or servers you started. Then report
   plainly: what changed in each repo and its version, which suites ran and their totals, anything not run or left open,
   and anything the user has to do.

## Guardrails

- Nothing is pushed until every touched repo is green and ready (steps 1-7). Push only in step 8, in dependency order. A
  repo that cannot be finished holds all the pushes, and the report says so.
- A change that has not been reviewed against its spec and the standards (step 3) is not finished, however green the suites. A fix the
  review makes puts the suites, and the acceptance run, back to unrun for the code it touched.
- Green means a suite ran in full on the final code and passed. A subset, an old run, or a rerun of only the failures is
  not green.
- The user's instruction wins: if they say to skip a suite or to stop, do that and record it in the report.
- Keep generated skills (such as the `openspec-*` ones) as they are; the CLI regenerates them.
