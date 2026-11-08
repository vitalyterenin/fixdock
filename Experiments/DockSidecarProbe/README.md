# DockSidecarProbe

An experiment for testing the `com.apple.dock.sidecar` XPC endpoint.

Dock contains the strings `getDockDisplay`, `requestDockOnDisplay`, and `removeDockFromDisplay`, and has an active launchd endpoint `com.apple.dock.sidecar`. This probe sends minimal XPC dictionary messages and prints replies/events without moving the cursor.

## Current result

The endpoint exists, but minimal dictionary messages do not yet follow Dock's actual protocol:

- `getDockDisplay` disconnects or returns an invalid reply;
- `requestDockOnDisplay` with `disp`, `display`, or `displayID` also disconnects;
- a reverse-engineered `DockSidecarConnection` / `SidecarMessage` handshake is likely required instead of key guessing.

This experiment has not demonstrated a working cursor-free Dock transfer and must not move into production.

Run commands from the Fixdock repository root. These experiments are not shipped.

## Read-only run

```bash
cd Experiments/DockSidecarProbe
swift run DockSidecarProbe
```

## Guarded write run

```bash
swift run DockSidecarProbe --target-display <CGDirectDisplayID> --apply
```

`--apply` is required for `requestDockOnDisplay` messages because they may change the Dock display.

Do not run the guarded-write mode unless you are prepared to restore Dock state manually.
