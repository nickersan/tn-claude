# Acceptance suite standard

Applies to `acceptance-suite` components (`okayat-acceptance`). Builds on
[`conventions/`](../conventions/README.md). The Android specifics are in
[`android-emulator.md`](android-emulator.md); this file is what holds for any platform the
suite drives.

## A failing run is a finding, and a restarted run teaches nothing

- **Read the failure's own message before changing anything.** A suite run takes an hour or
  more, and every change made on a guess costs another. Open the failing scenario's artifacts
  (error context, screen dump, device and service logs) first; if they do not say why, change the
  harness so the next failure does, and wait for it. A harness helper that times out reports what
  it saw and how long each call took, not "timed out".
- **Do not restart a run on partial evidence, or edit the harness while one is going.** A worker
  started after the edit runs different code from the one before it, so the run proves nothing
  about either. Stop the run, fix, and start one that is a single piece of code throughout.
- **Measure a configuration; do not infer it from suite runs.** Whether an environment comes up
  working is a rate (how many of N starts), so it is measured by starting it N times and counting
  (`scripts/emulator-boot-test.ts`), not by whether a suite happened to pass. A suite run mixes the
  environment's reliability with every defect in the scenarios and helpers, and cannot separate them.
- **Profile every run.** The harness writes a sample every few seconds of what the host, the
  container VM and the device were doing (CPU, memory, load, swap) beside the scenario timings, so
  that a slow or failing scenario can be set against what the machine was doing. A slowdown
  nobody can see is argued about; one in a CSV is read.
- **No workarounds for an unreliable environment.** Watchdogs that kill a hung device, restart
  loops, snapshot restores and "is the screen alive" probes each hide a cause and add a way to fail.
  Start a configuration that works (measured, above), and let a failure fail. A probe belongs in
  the measuring script, not in the run.

## One setup on every machine

- **The same defaults everywhere.** The suite runs on a developer's laptop and on the machine that
  runs the nightly build; both use the same configuration unless one is shown to need otherwise.
  What can differ per machine (GPU mode, cores, memory) is a setting with a default, never a
  constant in code: an environment variable for one run, then the machine's own file in the home
  folder (outside the repo), then the default. Say in the README how to override and how to measure
  that a different value works on that machine.
- **Prerequisites are checked, not discovered.** What a run needs (a JDK for the app build, an SDK,
  logged-in registries, a free emulator) is checked before it starts and named in the failure.

## Platforms are tested by the scenarios that use them

- **A helper that no scenario reaches on its platform is untested.** When a scenario has several
  people and only the first uses the device (the others using the web), a device helper for
  something only a later person does is never run on the device. It can be wrong for months. Each
  helper has at least one scenario where the device is the one that does it, and a change of a
  selector or a helper is checked on the device it is for, not assumed from the web's passing.
- **A selector built from the app's words matches every form of them.** The helper that gathered
  "spaces" text never saw "1 of 1 space taken", so every scenario with a limit of one timed out
  with the screen showing exactly what was wanted. Match the stem (`space`), or each count
  (`1 space`, `2 spaces`), and give the scenarios a case for one.
- **Waits are polls of cheap reads.** Each poll of a wait reads once, and scrolls or searches only
  as far as is bounded. A poll that can outlast the wait never gets a second look, and reports
  nothing. Every wait that can time out says, in its error, what was there and what was wanted.

## Services under test

- **Heap sizes are left alone until measured.** In a measured comparison on nine Android
  scenarios, a 512 MB to 1 GB heap on the services did not make them faster (it was slightly slower
  than the JVM defaults). Collections are logged instead: the `local` and
  `acceptance` overlays carry GC logging for every JVM service (see
  [`kubernetes/`](../kubernetes/README.md)), so memory behaviour is seen in each pod's log.
- **The container VM competes with the device.** On a laptop, the Docker (WSL2) VM and the
  emulator share the same memory and cores, and the VM takes up to half the memory and every core
  by default. The profile CSV records the VM's CPU and memory beside the emulator's; cap the VM only
  from what it shows (a machine-wide setting, to be agreed, not changed in passing).
