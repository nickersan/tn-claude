---
name: start-change
description: Run a feature or change from one main thread, cut into small verifiable slices (one repo each) that are implemented, released and smoke-tested in dependency order as forks, with draft acceptance tests written and reviewed before any code. Use when starting, planning or implementing a feature or OpenSpec change, or when the user says to build, start or implement one. The front half of complete-change.
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
- **One writer per repo; independent slices may run side by side.** Order follows dependency only: a slice waits for
  the release of every slice it builds on. Slices that need nothing of each other's (different repos, neither consuming
  the other's unreleased work), within a change or across changes, can be built in parallel forks. Two writers never touch
  the same repo. Releases and smoke runs stay one at a time, since acceptance needs a quiet machine and each smoke run
  should test one new release. The main thread checks each result and diff before releasing it. Nothing is released on a
  red or unrun suite.
- **Each slice is released on its own.** A repo trusts the tests it carries (unit, integration, contract), so once they
  are green and the diff is reviewed it is released, not held for the rest of the change. A big push at the end, with every
  repo landing at once, was the risk; releasing in dependency order keeps each step small, and a consumer builds against
  its provider's released version and stubs, never a `-SNAPSHOT`. This holds only because:
  - **Changes only add.** A service or library stays compatible with every released consumer: new endpoints, optional
    fields, migrations that only add, readers that ignore what they do not know. Removing or renaming is two releases:
    consumers stop using it, then it goes. Something no released consumer uses is free to change.
  - **The consumer drives the contract.** A provider's slice writes the contracts for what its consumer will call before
    the provider's code, so a released API is the one the next slice needs. A call with no contract is untested until
    acceptance; the review checks for one.
  - **Smoke runs after every release.** A repo's own tests cannot see its wiring into the platform (deployment config,
    network policies, auth), so the project's smoke scenarios run against the release before the next slice starts:
    web for a service or BFF, every platform for an app or front end.
  - **The acceptance repo is released last**, by `complete-change`, so the nightly run never fails on scenarios for a
    feature still being built.
  How to release a repo is `complete-change`'s "Releasing a repo".
- **Acceptance has its own thread.** A separate thread owns the acceptance scenarios and their helpers. It is not the
  thread writing the implementation.

## Small changes

Decide at the start, and say it out loud: "Small change: <why>" or "Normal change: <which test failed>". A change is
**small** only when all of these hold:

- it touches **one capability** (one spec) and **at most 2 repos**, counting the acceptance repo;
- it adds **no new component** and **no new UI screen**;
- existing acceptance scenarios already cover the behaviour, or **one** scenario is added or changed;
- it changes no contract that other repos consume beyond the 2, and needs no new decision between real alternatives.

If any fails, it is a normal change. The user can override either way ("treat it as small" / "do it in full"); their word
wins and you say what that changes. Re-check when a slice grows: a small change that stops meeting the test becomes normal,
and you say so.

A small change keeps every rule of this skill (one main thread, forked slices, one repo at a time, each slice released
and smoke-tested) and trims the ceremony around them:

- `proposal.md` is short (why, what changes, impact) with `tasks.md`; no `design.md` unless a real decision needs recording.
- One or two slices; skip the size guide in step 1.
- Acceptance: when no scenario is added or changed, there is no draft and no draft review (name the scenarios that already
  cover it). When one is added or changed, draft it and get the user's review before any slice, as in step 3.
- Step 5 still applies in full to any acceptance change made during implementation.

## Steps

1. **Size it.** Read the proposal, design, delta specs and tasks. As a guide (not a rule), a change that needs more than
   about 6 slices, or touches more than about 4 repos, is a candidate for splitting into separate OpenSpec changes, each
   shippable and verifiable alone. If so, say so and propose the split with a reason, and let the user decide. Going on
   as one change is fine when they say so, or when the pieces cannot ship apart. Say which of the split changes depend on
   each other and which could run alongside each other.

2. **Cut `tasks.md` into slices.** Group tasks by repo in dependency order (library or service before the BFF that
   consumes it, client before app, app before web and mobile). Each slice states: the repo, the tasks, a "done when" line
   naming the tests that must pass, then "released, smoke green". A slice whose consumer is not built yet starts with the
   contracts that consumer will need. Revise the OpenSpec artifacts (`openspec-update-change`) rather than keeping the
   slices only in chat, and validate with `openspec validate <change> --strict`.

3. **Draft the acceptance tests first, in their own thread.** Before any implementation code, the acceptance thread drafts
   the scenarios (feature files and any new helpers) from the delta specs: every scenario in the specs has a test named
   for it. The draft does not need to pass yet. **The user reviews the draft and approves it before any slice starts.**
   Do not begin implementation on an unreviewed draft.

4. **Implement slice by slice.** Start a slice when every slice it depends on is released; independent ones may run at
   once (see "Shape of the work"). For each slice: fork, implement, run that repo's suites to green, report to the
   main thread, review the diff against the spec and standards (including that it breaks no released consumer, and that
   every call it makes or serves has a contract), release it (`complete-change`, "Releasing a repo"), run the smoke
   scenarios against the release, then move on. Tick the tasks as they are verified. A red smoke run stops the chain: fix
   it with another release, never by rolling back or moving on.

5. **Acceptance changes during implementation are called out.** Implementation may show that a scenario is wrong,
   missing or needs another helper. Modifying or adding acceptance tests is allowed, but never silently: stop, tell the
   user exactly what changed and why (the scenario before and after, or the new scenario), and wait for their review
   before going on. Never weaken or delete a scenario to make it pass. A change in behaviour also updates the delta spec.

6. **Hand over to `complete-change`** when every slice is released with smoke green and the approved acceptance set exists. A change with no
   reviewed acceptance tests is not ready to complete (a small change that adds or changes no scenario relies on the
   existing ones it named).

## Guardrails

- The user's instruction wins on any of this, including the size guide in step 1: say what you are doing differently and
  carry on.
- A slice is released only when its own suites are green and its diff is reviewed, after the user's yes for that release,
  and never one that breaks a released consumer. The acceptance repo is not released by a slice.
- One writer per repo. A second fork that writes code may start only in another repo and only when it needs nothing
  unreleased from the running one; otherwise wait.
- A slice that grows past one repo or past its "done when" is a signal to stop and re-slice, not to push on.
- Keep generated skills (such as the `openspec-*` ones) as they are; the CLI regenerates them.
