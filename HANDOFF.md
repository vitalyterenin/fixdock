# Fixdock handoff

## Current distribution

The project now supports a public MIT-licensed Apple Silicon DMG and signed
Sparkle updates. See [README](README.md) for installation and current behavior,
[release operations](docs/releases.md) for publication, and [AGENTS](AGENTS.md) for
maintenance constraints. Earlier local paths/build instructions below are historical.
Automatic cursor-free transfer and the exact PCSX2 shutdown reproduction remain
unresolved; this release does not claim to solve them.

## Publication review

2026-11-08T12:25:43+01:00 — reviewed the local changes for publication to
`vitalyterenin/fixdock` on `main` at the user's request. Added six event-filter
regressions and reset stale pointer history when stopping the event tap. All
11 Swift tests passed, signing-isolation checks and shell syntax checks passed,
and the release app built with its stable signature verified. The signing test
uses the repository's tracked `Scripts/` path casing. README now documents the
existing visibility enforcement and normal-quit restoration behavior.

This review did not install or launch a new app, reproduce the PCSX2 shutdown,
or resolve the pending live validation recorded below.

## Goal

Make Fixdock a utility that locks the Dock to a user-selected display and can switch the selected display without using the physical cursor as the transfer mechanism.

The old cursor-driven transfer worked technically but had unacceptable UX: while the user worked, the cursor jumped to a monitor edge and back. It felt like broken input control. This approach is prohibited.

## Critical rule: never move the cursor

This is a hard project constraint.

Do not:

- programmatically move the visible cursor to transfer the Dock;
- use `CGWarpMouseCursorPosition`;
- hide the cursor with `NSCursor.hide()` to conceal a transfer;
- post synthetic mouse-move or edge events as a Dock-transfer mechanism;
- return the cursor “back” after a programmatic transfer;
- add such a mechanism to production, a debug flag, or an experiment without the user's separate explicit permission.

If a hypothesis requires physical-cursor movement, reject it and do not implement it.

## Current lock repair

The current app also enforces Dock visibility: autohide is disabled and locked,
Option-Command-D and Fn-A are filtered, and external visibility changes trigger
a corrective Dock restart. Normal quit restores the persisted visibility
snapshot. This visibility repair supersedes the historical blanket restart
restriction below; restarting Dock must never be used to transfer it.

2026-11-07T20:30:54+01:00 — installed a signed local repair after the Dock moved during PCSX2 shutdown.

- Missing or unexpected Dock observations never authorize switching. Only an explicit display selection can request a manual transfer; it requires a detected Dock, connected displays, and a live Accessibility event tap. Arrival consumes the request.
- Screen and Space changes preserve the saved target. An unavailable target stays selected.
- Event-tap health uses the actual enabled/valid state and retries recovery. The first mouse event at a forbidden edge is filtered; locations outside that display are excluded.
- Preference reads use synchronized Core Foundation preferences instead of spawning `defaults` on the event-tap run loop. Common-mode polling and workspace notifications recheck protection.
- Five policy regressions passed. The installed app completed eight native fullscreen transitions across both displays plus presentation-mode hiding/window teardown, with 787 samples and no unlock or detected relocation. Dock PID 984 remained unchanged during this test.
- The exact PCSX2 shutdown/crash was not reproduced. User validation in that application remains pending. No GitHub writes were made.

## Project state

Project path:

```bash
~/Developer/fixdock
```

Installed app:

```text
/Applications/Fixdock.app
```

Bundle ID: `local.vitalyterenin.Fixdock`.

Build and install:

```bash
cd ~/Developer/fixdock
Scripts/install-app.sh
```

Key files:

- `Sources/Fixdock/AppDelegate.swift` — menu-bar UI, display selection, orchestration.
- `Sources/Fixdock/MouseEdgeGuard.swift` — Accessibility event tap suppressing the Dock edge gesture on non-selected displays.
- `Sources/Fixdock/DockSystemController.swift` — `com.apple.dock allow-display-switching` handling.
- `Sources/Fixdock/DisplayManager.swift` — display list and coordinates.
- `Experiments/SkyLightDockDisplaySwitch/` — Swift CLI for private SkyLight/CoreGraphics Services hypotheses.
- `Experiments/DockSidecarProbe/` — Swift CLI for the `com.apple.dock.sidecar` XPC endpoint.

Historical baseline as of 2026-05-02T00:16:39+02:00 (the lock repair above supersedes its automatic unlock behavior):

- Automatic Dock transfer on choosing a different display still does not work.
- Production can lock the Dock where it already is and suppress edge gestures elsewhere when Accessibility is available.
- When another display is selected, Fixdock enables normal switching through `allow-display-switching = true` and gives an honest fallback: move the cursor to the selected display edge once manually.
- The current Dock display comes first from the real Dock window via `CGWindowListCopyWindowInfo`, then the `SLSGetDockRectWithOrientation` fallback.
- Production has no `DockRelocator`, synthetic mouse events, `CGWarpMouseCursorPosition`, `NSCursor.hide()`, `killall Dock`, persistent unified logs, or legacy `DockAnchor` migrations.
- Local builds use a stable per-Mac self-signed `Fixdock Local Code Signing` identity. `Scripts/setup-signing.sh` creates it under `~/Library/Application Support/Fixdock/Signing`; an existing installation may override this location. Fixdock checks Accessibility silently at launch and exposes `Open Accessibility Settings` in its menu instead of automatically prompting.

Historical updates:

- **2026-05-01T23:00:30+02:00:** production stopped launching `DockRelocator` automatically at launch, display selection, or display changes; removed it from the production target; replaced it with a single manual-edge fallback; stopped using `killall Dock`; and added the SkyLight experiment.
- **2026-05-01T23:25:00+02:00:** added `--test-dock-rect-reason`; verified `SLSGetDockRectWithReason` and `SLSSetDockRectWithReason` signatures; confirmed the setter changes WindowServer's Dock rectangle but not the real Dock window; added `DockSidecarProbe`; found minimal XPC messages disconnected; AX `NextDockForDisplayID` gave errors `-25202` and `-25213`; no installed DockLock Lite app was found, though `pro.docklock.lite` preferences remain.
- **2026-05-02T00:02:44+02:00:** `AppDelegate.updateProtection()` now writes `allow-display-switching` before starting `MouseEdgeGuard`; false is set while already on target even without Accessibility, true when target differs or the Dock display is unknown; real Dock-window detection became primary; the rebuilt app was installed and tested with target display IDs 3 and 1.
- **2026-05-02T00:08:11+02:00:** temporary unified logs were removed; an `Open Accessibility` menu item was added; resetting TCC and manually granting Accessibility brought up the event tap; `security find-identity -v -p codesigning` returned `0 valid identities found`.
- **2026-05-02T00:14:57+02:00:** removed legacy `DockAnchor` migration and keys, its install-script removal, and direct production references; changed fallback status text from `DA` to `FD`.
- **2026-05-02T00:16:39+02:00:** project Markdown documents were updated to record that automatic switching is unavailable and production uses a manual edge gesture as the fallback; experiment documents include negative findings and guarded-write limits.

## Established facts

Works:

- `defaults write com.apple.dock allow-display-switching -bool false` locks the Dock on its current display.
- `defaults write com.apple.dock allow-display-switching -bool true` restores normal macOS Dock switching between displays.
- With Accessibility, `MouseEdgeGuard` suppresses the edge gesture on non-selected displays without blocking the entire bottom strip.

Not acceptable:

- any solution that moves the visible user cursor;
- background `killall Dock` or timer-based Dock restarts as a transfer mechanism, which cause display flashing; conditional visibility repair is the existing exception described above;
- a broad invisible edge strip that makes cursor motion feel obstructed;
- UI with separate protection/lock/allow-switching modes: selection of one display is the sole control.

UX requirement:

- the menu retains one setting: display selection;
- choosing another display must eventually put the Dock there without involving the visible cursor;
- the Dock must not subsequently move itself to other displays.

## Main problem

No public macOS API for “put the Dock on display X” was found. Normal transfer is tied to an edge gesture. The former `DockRelocator` simulated that gesture through the cursor; it is prohibited and removed from production.

The next phase must find a cursor-free mechanism. Do not temporarily restore cursor transfer.

## Direction 1: private SkyLight/CoreGraphics Services APIs

This is the primary candidate.

Investigate private symbols related to Spaces, displays, and Dock:

```bash
strings /System/Library/CoreServices/Dock.app/Contents/MacOS/Dock | rg -i "display|space|dock|switch"
nm -gj /System/Library/PrivateFrameworks/SkyLight.framework/SkyLight 2>/dev/null | rg -i "display|space|dock|managed"
strings /System/Library/PrivateFrameworks/SkyLight.framework/SkyLight | rg -i "display|space|dock|managed"
```

Look for functions that change current display/current space, `SLSManagedDisplay`/`CGSSpace`/`DisplaySpaces` paths, or a direct Dock-display binding without mouse events. Dock binary already contains `DisplaySpaces`, `ManagedDisplayInfo`, `SLSManagedDisplayIterator`, `CGSSpace`, `SpaceSwitcherDisplay`, `DockImmutabilityPreferences`, and `allow-display-switching`.

Experiment plan:

1. Create a small standalone Swift/C program outside the app that resolves private functions through `dlopen`/`dlsym`.
2. Verify effect through `CGWindowListCopyWindowInfo`: Dock-window bounds must move to the target display frame.
3. Only then move the confirmed mechanism into Fixdock.

Success requires: the Dock moves to the selected display; `CGEvent(source: nil)?.location` is unchanged before and after; no `killall Dock`; and the Dock PID is unchanged.

Current experiment results:

- `SLSCopyManagedDisplays`, `SLSCopyBestManagedDisplayForRect`, `SLSManagedDisplayGetCurrentSpace`, `SLSManagedDisplaysCopyRoleWindows`, `SLSGetDockRectWithOrientation`, and `SLSSetDockRectWithOrientation` resolve through `dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight")`.
- Current configuration: CG display 1 / managed display `37D8832A-2D66-02CA-B9F7-8F30A301B230` / space 1; CG display 3 / managed display `A9689BE6-2B12-4CF5-82E5-79D79F20E9B1` / space 91.
- `SLSManagedDisplaysCopyRoleWindows` over roles `0...64` reported only `role=1` with role windows `[34]` and `[7985]`; neither is the Dock window.
- Stable read signature:

```swift
@convention(c) (
    CGSConnectionID,
    UnsafeMutablePointer<CGRect>,
    UnsafeMutablePointer<Int32>,
    UnsafeMutablePointer<Int32>
) -> Int32
```

- Stable write signature: `@convention(c) (CGSConnectionID, CGRect, Int32, Int32) -> Int32`.
- `SLSSetDockRectWithOrientation` and `SLSSetDockRectWithReason` can alter the WindowServer Dock rectangle without moving the cursor or restarting Dock, but the real `CGWindowListCopyWindowInfo` Dock window remains on its original display. This is not a Dock-transfer solution.
- The former three-argument `SLSGetDockRectWithOrientation` call is unstable and can crash the process. Do not use it.

## Direction 2: Apple Events, Dock scripting, and internal Dock messages

Check whether Dock exposes Apple Events, XPC, or distributed notifications for display switching:

```bash
sdef /System/Library/CoreServices/Dock.app 2>/dev/null
ls -R /System/Library/CoreServices/Dock.app/Contents
strings /System/Library/CoreServices/Dock.app/Contents/MacOS/Dock | rg -i "xpc|mach|notify|notification|display|space"
launchctl print gui/$(id -u)/com.apple.Dock.agent 2>/dev/null
```

This is less likely than SkyLight, but an internal message path would be cleaner than private WindowServer APIs. `sdef` returned no scripting dictionary. `launchctl` shows an active `com.apple.dock.sidecar` endpoint. Dock contains `SidecarMessage`, `getDockDisplay`, `requestDockOnDisplay`, `removeDockFromDisplay`, and `dockDisplayChanged`. `DockSidecarProbe` currently gets only connection interruption for minimal XPC dictionary messages. Reverse `DockSidecarConnection`/`SidecarMessage` rather than blindly guessing keys.

## Direction 3: reverse engineer DockLock Lite

Local DockLock Lite preferences exist:

```bash
defaults read pro.docklock.lite
```

They include `settings.dock.control_mode = 1`, `settings.dock.lock_position = 1`, and `settings.dock.workspaces`. Determine whether DockLock stores a screen/workspace binding and how it transfers Dock without a visible cursor.

If the app is found or re-downloaded, inspect code signature, entitlements, linked frameworks, strings, runtime logs, and `com.apple.dock`/`com.apple.spaces` defaults before and after a display change. Commands:

```bash
codesign -dv --entitlements :- /path/to/DockLock.app 2>&1
otool -L /path/to/DockLock.app/Contents/MacOS/*
strings /path/to/DockLock.app/Contents/MacOS/* | rg -i "display|space|dock|cursor|mouse|event|sky|sls|cgs"
log stream --style compact --predicate 'process CONTAINS[c] "DockLock" OR process == "Dock"'
fs_usage -w -f filesys | rg "DockLock|com.apple.dock|com.apple.spaces"
```

The app is not in standard application directories, so linked frameworks, entitlements, and runtime logs have not yet been checked.

## Direction 4: window visibility limitation

`currentDockDisplayID` can return `nil` when `CGWindowListCopyWindowInfo` does not expose Dock or the SkyLight fallback lacks a valid rectangle. Current implementation checks the real Dock window, then `SLSGetDockRectWithOrientation`; if still unknown, it keeps `allow-display-switching = false`. Unknown observations must never request or authorize a transfer. Do not add Screen Recording without need: it worsens onboarding.

## Direction 5: fallback without programmatic cursor movement

If no direct API is found, keep the fallback honest and non-annoying:

- the menu selects a target display;
- if the Dock is not there, status says “Move the cursor to the selected display edge once”;
- after the normal manual transfer, Fixdock locks the target through its edge filter.

Only the user decides whether to perform that gesture.

## Important constraints

- Never use visible-cursor movement as a production mechanism.
- Do not restore `DockRelocator`, `CGWarpMouseCursorPosition`, `NSCursor.hide()`, or synthetic mouse-move transfer.
- Do not use `killall Dock` in the background or on a timer to transfer Dock. Preserve the existing conditional visibility repair described above.
- Do not add visible menu modes or restore the old multi-button model.
- Do not impede free cursor movement on a second display or block entire lower/side areas.

## Recommended next step

Continue with standalone experiments in:

```text
Experiments/SkyLightDockDisplaySwitch/
Experiments/DockSidecarProbe/
```

They must accept `displayID`, attempt a private SkyLight/CoreGraphics Services path without changing cursor location, print before/after Dock-window bounds, cursor location, and Dock PID, and determine `SidecarMessage` format plus `com.apple.dock.sidecar` handshake. Move only a proven cursor-free transfer mechanism into `Sources/Fixdock`.

## Removed production behaviour

Transfer formerly ran through:

```text
Sources/Fixdock/AppDelegate.swift
Sources/Fixdock/DockRelocator.swift
```

`DockRelocator` moved the cursor to the target display edge, posted synthetic mouse-moved events, and moved it back. It is removed from the production target. The next phase must identify and verify a cursor-free relocation backend in `Experiments/SkyLightDockDisplaySwitch`, then promote only that verified mechanism into `Sources/Fixdock`.
