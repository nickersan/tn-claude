---
name: start-change
description: Run a feature or change from one main thread, cut into small verifiable slices (one repo each) that are implemented one at a time as forks, with draft acceptance tests written and reviewed before any code. Use when starting, planning or implementing a feature or OpenSpec change, or when the user says to build, start or implement one. The front half of complete-change.
---

Start and drive a change in a tn-layer project so it stays small enough to verify. A large change that touched many repos
at once, with acceptance written last, is the failure this skill exists to prevent. This skill is the order to work in;
it does not replace judgment. `complete-change` is the back half.

**Input**: the change name (for an OpenSpec project, `openspec list --json` if it is not clear). Announce it:
"Starting: <name>".

## Shape of the work

- **One main thread owns the feature.** It plans, sequences, reviews and verifies. It does not write repo code itself,
  except trivial edits (a version bump, a registry line).
- **Slices are forks of the main thread.** Each slice is small, touches **one repo**, and is independently verifiable.
  Start each with a fork (`start_session` with `context: "fork"`, or a subagent where the user has not asked for a
  session), briefed with its slice only: the repo, what done looks like, the tests that prove it.
- **One repo at a time.** Run slices one after another in dependency order, never two writers at once. A slice is done
  only when that repo's own suites are green (unit, integration, contract, typecheck/lint). A slice commits locally on a
  `-SNAPSHOT` version (`mvn install` for what its consumers need) and never pushes: the nightly builds run on another
  machine, and `complete-change` pushes every repo together, in dependency order, once all are ready. The main thread checks the
  result and the diff before the next fork starts. Nothing moves to the next repo on a red or unrun suite.
- **Acceptance has its own thread.** A separate thread owns the acceptance scenarios and their helpers. It is not the
  thread writing the implementation.

## Steps

1. **Size it.** Read the proposal, design, delta specs and tasks. As a guide (not a rule), a change that needs more than
   about 6 slices, or touches more than about 4 repos, is a candidate for splitting into separate OpenSpec changes, each
   shippable and verifiable alone. If so, say so and propose the split with a reason, and let the user decide. Going on
   as one change is fine when they say so, or when the pieces cannot ship apart.

2. **Cut `tasks.md` into slices.** Group tasks by repo in dependency order (library or service before the BFF that
   consumes it, client before app, app before web and mobile). Each slice states: the repo, the tasks, a "done when" line
   naming the tests that must pass. Revise the OpenSpec artifacts (`openspec-update-change`) rather than keeping the
   slices only in chat, and validate with `openspec validate <change> --strict`.

3. **Draft the acceptance tests first, in their own thread.** Before any implementation code, the acceptance thread drafts
   the scenarios (feature files and any new helpers) from the delta specs: every scenario in the specs has a test named
   for it. The draft does not need to pass yet. **The user reviews the draft and approves it before any slice starts.**
   Do not begin implementation on an unreviewed draft.

4. **Implement slice by slice.** For each slice, in order: fork, implement, run that repo's suites to green, report to the
   main thread, review the diff against the spec and standards, then move on. Tick the tasks as they are verified.

5. **Acceptance changes during implementation are called out.** Implementation may show that a scenario is wrong,
   missing or needs another helper. Modifying or adding acceptance tests is allowed, but never silently: stop, tell the
   user exactly what changed and why (the scenario before and after, or the new scenario), and wait for their review
   before going on. Never weaken or delete a scenario to make it pass. A change in behaviour also updates the delta spec.

6. **Hand over to `complete-change`** when every slice is done and the approved acceptance set exists. A change with no
   reviewed acceptance tests is not ready to complete.

## Guardrails

- The user's instruction wins on any of this, including the size guide in step 1: say what you are doing differently and
  carry on.
- No slice pushes. Commit locally; `complete-change` step 8 is the only push.
- One writer at a time. If a fork is running, do not start another that writes code.
- A slice that grows past one repo or past its "done when" is a signal to stop and re-slice, not to push on.
- Keep generated skills (such as the `openspec-*` ones) as they are; the CLI regenerates them.
