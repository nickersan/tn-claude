---
name: complete-change
description: Finish a feature or task properly - every touched repo's suites, a review of the change against its spec and the standards, the publish chain, the specs synced and the OpenSpec change archived, every component released (each on its own, smoke-tested), the change's acceptance scenarios (smoke plus the touched capabilities, every platform) green on the released code, then the specs, Kustomize and acceptance pushed. Use when the work is done, or the user says to finish, complete, wrap up or ship a feature, task or change.
---

Finish a change in a tn-layer project. Its component repos are released one by one as their slices are done (see
"Releasing a repo"); the change is not done, and is not archived as done, until every suite that
could have been affected is green on the final code, and that includes the change's acceptance scenarios: the smoke scenarios
plus every scenario of the capabilities it touched, on every platform (the acceptance standard, `standards/acceptance/README.md`,
"What finishes a change"). The full acceptance suites run only when the user asks for them for this change; the nightly run covers
the rest. This skill is the order to do it in; it does not replace judgment. Stop and tell the
user when something fails and the cause is not clear.

**Project specifics come from the project.** Which suites are the acceptance suites, how to run them, their
prerequisites, and the order repos publish in are in the project's own `CLAUDE.md` (a "Finishing a change" section, or a doc it points to) or its
README. Read them first. If the project names no acceptance suites, say so and treat its repos' own suites as the bar.
A change `start-change` called **small** has the same acceptance bar; steps 1-3 and 5, 7-9 are done in full, and the review in
step 3 is never skipped. A project with no nightly run of its full suites says so, and its changes finish on the full suites.

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
4. **Every touched component repo is released.** `start-change` releases each slice as it is done (see "Releasing a
   repo"). Check that each touched repo's work is on `origin/main` and released, with its smoke run green. Anything not yet
   released (a fix from the review in step 3, or a change made without slices) is released now the same way, in
   dependency order. The acceptance repo and the platform or spec repo are not released here; step 8 does them.

5. **Sync the specs and archive the change** (OpenSpec projects: the `openspec-archive-change` skill or `/opsx:archive`),
   before the final acceptance run, because an acceptance coverage check usually reads the main specs:
   - Merge the delta specs into the main specs (sync, then verify each capability reads as synced), then archive.
   - Distil as the project's OpenSpec config says: keep the why, cross-component rules, domain meaning and lessons; do
     not copy the change in; leave the archived folder as history; do not rework earlier archives.
   - Validate the specs. Archiving stays local until step 8; if the acceptance run fails, fix the cause and leave the
     archive as it is.
   - Do not archive a change with unfinished tasks without the user's say-so.

6. **Run the change's acceptance scenarios on the final code**: the smoke scenarios and every scenario of the capabilities the change
   touched, on every platform the project has, without the scenarios that take the environment down (outages run nightly), against the
   released versions of every touched repo (images built from the released checkouts, or the released images). Note anything the run needs first (registry logins, a JDK, an emulator). Long runs
   are normal: start early, let them finish, and do not stop or narrow one to finish sooner without the user saying so.
   Say plainly what ran and that the rest of the suites is left to the nightly run. Run the full suites only when the user asks.

7. **Triage every failure; never retry until green.** Decide which it is, and say so:
   - *the change* - fix the code;
   - *a stale scenario or helper* - the app changed and the acceptance steps did not (an element renamed, a screen merged
     into another, a form that now keeps its state): fix the helper or the scenario, or the app if the old behaviour was
     right;
   - *the environment* - an image that does not hold the code you think it does, a hung emulator, a missing login: fix
     it, or tell the user what they need to do.
   Calling a failure pre-existing needs evidence that it fails the same way without the change. A fix to a component is
   released (see "Releasing a repo"), never rolled back. Rerun fixes with a subset or `--last-failed`, but finish with one
   full run on the final released code.

8. **Release what is left: the specs, Kustomize and acceptance.** Only when everything above is green. The components are
   already released (step 4); push the platform or spec repo (the archived change, the synced specs, any inventory,
   guidance or config changes), then align Kustomize and the acceptance suite with the released versions and image tags
   and push them, through the project's release script as in "Releasing a repo" (a yes from the user for this release
   too). The acceptance repo goes last, so the nightly run only meets the new scenarios once everything they test is out.

## Releasing a repo

Each component repo is released on its own, in dependency order, as soon as its slice is done (`start-change`), not held
for the rest of the change. This is safe only when the release breaks no released consumer (changes only add; removing or
renaming takes two releases) and every call between repos has a contract: the repo's own unit, integration and contract
tests are then what it is released on, and the smoke run checks its wiring into the platform.

1. Its own suites are green from a clean build (step 2) and its diff is reviewed (step 3, for that repo's diff).
2. Its build declares the version on `origin/main` (CI sets the version itself from the conventional commits since the last
   tag and ignores the declared one) and depends on no `-SNAPSHOT` of another repo: a dependency on a provider changed in
   this change points at the provider's release. Commit messages use conventional types: `feat` and `fix` release, so
   choose them on purpose. Add the trailer the session asks for.
3. Push through the project's release script where it has one (its finishing document says where): run `<script> <repo>`
   as a dry run, show the plan, ask the user in the session whether to release, and run its `--execute` only after a yes
   for that release (OK AT's script takes `--confirmed` from an agent; the project's finishing document says how its script is
   told). A yes covers that release only; ask again for the next. Never push by another route to get around the script.
   Without a script: pull with rebase, check no `-SNAPSHOT` of any repo remains in a build or package file, push.
4. Wait for the repo's CI to release (the session's watchers, not a polling loop), then pull the release commit. Renovate may
   have moved a dependency in the meantime: rebase over it, do not fight it. Stop at the first CI failure.
5. Run the project's smoke scenarios against the release, with every other component at its current release: web for a
   service or BFF, every platform for an app or front end. One release and one smoke run at a time (acceptance needs a quiet
   machine). A red smoke run stops the chain; triage it as in step 7 and fix it with another release, never by rolling back.

9. **Tear down and report.** Remove kept test environments and stop emulators or servers you started. Then report
   plainly: what changed in each repo and its version, which suites ran and their totals, anything not run or left open,
   and anything the user has to do.

## Guardrails

- A component repo is released only when its own suites are green and its diff reviewed, in dependency order, compatible with
  every released consumer, and only after the user says yes to that release in the session; its smoke run follows before
  anything else is released. The specs, Kustomize and the acceptance repo are pushed only in step 8, once the acceptance run
  is green.
- A change that has not been reviewed against its spec and the standards (step 3) is not finished, however green the suites. A fix the
  review makes puts the suites, and the acceptance run, back to unrun for the code it touched.
- Green means a suite ran in full on the final code and passed. A subset, an old run, or a rerun of only the failures is
  not green.
- The user's instruction wins: if they say to skip a suite or to stop, do that and record it in the report.
- Keep generated skills (such as the `openspec-*` ones) as they are; the CLI regenerates them.
