# Android emulator in an acceptance suite

Applies to an `acceptance-suite` that drives a mobile app on the Android Emulator with Appium
(UiAutomator2). Distilled from `okayat-acceptance`, where a stack of workarounds was replaced by
measured settings. The general rules are in [`README.md`](README.md).

## The emulator and its image

- **Use the emulator's newest stable release.** It has no long-term-support channel. Pin it only
  to move off a release shown to be bad, with the measurement that shows it.
- **Use a plain AOSP image (`default`), not a Google APIs one.** A `google_apis` image starts
  Play services, Messages and the full system UI, which keep a freshly booted guest at a load of
  20 or more on 4 cores for minutes: the first scenario after a boot took minutes and often exceeded its
  180-second timeout. The AOSP image booted in about 35 seconds and was quiet in about 80, 5 boots of 5.
- **Check an image against the app before choosing it.** The `aosp_atd` (automated test device)
  image is smaller and quieter, and booted fine, but the app's screen did not follow it in 0 boots
  of 5. Decide by the boot test (below), per app, not by reputation.
- **A window, the machine's GPU, a cold boot.** Run the emulator in a window with `-gpu host`
  (the machine's GPU) and `-no-snapshot`. Headless with software rendering (`swiftshader_indirect`)
  and snapshots saved and restored for each group of scenarios were the source of frozen frames,
  slow drawing and half-restored states. A machine whose GPU misbehaves overrides `-gpu` for
  itself (the README says how) after the boot test shows it does.
- **No sensor, screen-size or boot-animation tricks beyond what the app needs:** a hardware
  keyboard (so the on-screen one does not cover fields), animations off, `-no-boot-anim`,
  `-no-audio`.
- **Gesture navigation, as on a phone as it is sold.** The plain AOSP image starts with three
  navigation buttons (`secure navigation_mode` 0), and the launcher's taskbar then sits over the
  bottom of the screen. An app that draws edge to edge (Android 15 on, so any app built for it)
  has its bottom-most button under that bar, and Appium's tap on its centre presses Home: the
  app is gone, the screen is the launcher, and the failure reads "element not existing" with no
  crash anywhere in the log. Enable `com.android.internal.systemui.navbar.gestural` with
  `cmd overlay enable` after boot (`navigation_mode` becomes 2). The Google image defaulted to
  gestures, which is why the plain one showed it. If a tap leaves the app, look for
  `LAUNCHER_TASKBAR_HOME_BUTTON_TAP` in the device log first. That the app's own button is
  unreachable with three buttons is a finding for the app (safe-area insets), not for the suite.

## Measure it

- **The boot test.** `scripts/emulator-boot-test.ts` boots each named image N times and counts
  how many reach a working screen: Android booted, the app installed, the guest quiet (load at
  most half its cores) within three minutes, and the app's screen followed a tap (the accessibility
  tree has the Profile tab, it is tapped, and the picture changes). Run it on every machine, and
  after any change of emulator, image or GPU mode. Five boots per configuration is the least that
  says anything.
- **The sampler.** Every run writes `build/android/profile-<run>.csv` (host CPU and free memory;
  the emulator's and the container VM's CPU and memory; the guest's load, available memory and
  swap). On Windows the process figures come from `Win32_PerfFormattedData_PerfProc_Process`:
  `Get-Process`'s `CPU` property came back empty in the harness's shell.

## Appium and UiAutomator2

- **End the earlier sessions before opening one.** When a scenario fails, Playwright ends its
  worker without ending its Appium session, which stays alive for the command timeout (600 s here),
  and the next worker's session cannot start its instrumentation ("The instrumentation process
  cannot be initialized within 30000ms"); every scenario after it then fails in milliseconds. Before
  each new session, list the sessions and delete them, and force-stop UiAutomator2's two packages on
  the device (`io.appium.uiautomator2.server` and its `.test`).
- **Listing sessions is an insecure feature, off by default.** Start the Appium the suite owns
  with `--allow-insecure "*:session_discovery"` (the bare `session_discovery` is refused: Appium wants
  the driver or `*` before the colon) and read `/appium/sessions`; `/sessions` is not a route.
- **A test timeout for the first scenario of a group is not a reason to retry.** If the first
  scenario after a boot is slow, the guest is busy (see the sampler); fix that, not the timeout.

## Selectors

- **No backslashes in a `UiSelector` string.** Appium passes the string on as it is, so the `\\d`
  or `\\.` that would be right in a Java string is a literal backslash followed by a `d` or any
  character, and matches nothing. One backslash works (`\w` matched), but write character classes
  (`[0-9]`, `[.]`, `[A-Za-z]`) and the question does not arise. Try a new selector against a live
  emulator before relying on it: a small script that counts what it matches, with the same strings
  as the suite.
- **A selector that matches nothing looks exactly like a screen that is not ready.** It makes a
  wait time out, not fail, and says nothing. Hence the rule in [`README.md`](README.md) that a wait
  says what it saw.

## Timeouts

- **The test timeout covers the slowest honest scenario, not a hung one.** Android scenarios run
  about 40 seconds once the guest is quiet; 300 s is a limit for a scenario that is waiting on
  something, not a budget for a busy guest.
