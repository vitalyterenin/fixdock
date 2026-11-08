# SkyLightDockDisplaySwitch

An experiment for testing Dock transfer between managed displays through private SkyLight APIs without moving the visible cursor.

## Current result

No working Dock-transfer path has been found yet.

Confirmed:

- `SLSCopyManagedDisplays`, `SLSCopyBestManagedDisplayForRect`, `SLSManagedDisplayGetCurrentSpace`, `SLSManagedDisplaysCopyRoleWindows`, `SLSGetDockRectWithOrientation`, and `SLSSetDockRectWithOrientation` resolve through `dlopen`.
- `SLSGetDockRectWithOrientation` reads reliably with four arguments: connection, `CGRect*`, orientation, and reason.
- `SLSSetDockRectWithOrientation` and `SLSSetDockRectWithReason` can change the Dock rectangle in WindowServer.

Unresolved:

- changing the Dock rectangle does not move the actual Dock window reported by `CGWindowListCopyWindowInfo`;
- role windows in the tested range did not match the Dock window;
- production transfer is allowed only after proving that the Dock window moves, cursor location remains unchanged, and the Dock PID does not change.

Run commands from the Fixdock repository root. These experiments are not shipped.

## Run read-only diagnostics

```bash
cd Experiments/SkyLightDockDisplaySwitch
swift run SkyLightDockDisplaySwitch
```

Diagnostics print:

- `CGDirectDisplayID`, bounds, and managed-display identifier for each active display;
- current Dock rectangle from `SLSGetDockRectWithOrientation`;
- current Dock window from `CGWindowListCopyWindowInfo`;
- managed-display role windows for the selected role range;
- cursor position before and after execution.

## Search role windows

```bash
swift run SkyLightDockDisplaySwitch --scan-roles 0...32
```

If a role contains the Dock window ID, it is a candidate for the next write experiment.

## Write experiment

```bash
swift run SkyLightDockDisplaySwitch --target-display <CGDirectDisplayID> --set-role-window <role> --apply
```

`--apply` is mandatory so an accidental run cannot change WindowServer state. Before use, manually confirm that the selected `role` really corresponds to the Dock window.

Do not run write modes blindly. This experiment uses private WindowServer APIs.

## Reversible Dock-rectangle test

```bash
swift run SkyLightDockDisplaySwitch --target-display <CGDirectDisplayID> --test-dock-rect --apply
```

This calls `SLSSetDockRectWithOrientation` with a rectangle on the target display, waits briefly, prints state, and restores the original rectangle by default.

To keep the rectangle instead:

```bash
swift run SkyLightDockDisplaySwitch --target-display <CGDirectDisplayID> --test-dock-rect --keep-dock-rect --apply
```

## Reversible Dock-rectangle-with-reason test

```bash
swift run SkyLightDockDisplaySwitch --target-display <CGDirectDisplayID> --test-dock-rect-reason --apply
```

This calls `SLSSetDockRectWithReason`, waits briefly, prints state, and restores the original rectangle by default. In the current configuration it changes the Dock rectangle in WindowServer, but the actual Dock window stays on the original display.
