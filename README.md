# Fixdock

Fixdock is a macOS menu-bar utility that keeps the Dock on the display selected by the user.

## Install with Codex

Give Codex this prompt:

> Install Fixdock from https://github.com/vitalyterenin/fixdock. Clone the repository, run `Scripts/install-app.sh`, run `Scripts/verify-install.sh`, and then guide me through enabling only Fixdock under Privacy & Security → Accessibility. Do not enable unrelated permissions.

The repository is currently private, so the GitHub account used by Codex must have access to it.

## Install from Terminal

Requirements:

- macOS 14 or later;
- Xcode Command Line Tools with Swift;
- access to this repository.

```bash
git clone https://github.com/vitalyterenin/fixdock.git
cd fixdock
Scripts/install-app.sh
Scripts/verify-install.sh
```

Fixdock is installed at `/Applications/Fixdock.app` and starts immediately.

### One-time macOS setup

1. Open the Fixdock menu-bar icon.
2. Choose `Open Accessibility Settings`.
3. Enable Fixdock under `Privacy & Security → Accessibility`.
4. Optionally choose `Launch at Login` in the Fixdock menu.

Fixdock never opens the Accessibility permission prompt automatically. Input Monitoring is not required.

## Stable local signing

The first build creates a private self-signed code-signing identity under:

```text
~/Library/Application Support/Fixdock/Signing
```

The same identity is reused for later builds on that Mac, so macOS can keep the Accessibility grant instead of treating every rebuild as unrelated code. The private key never belongs in the repository and must not be shared between users.

Signing uses an explicit `codesign --keychain` argument. Setup does not parse or rewrite the user's keychain search list; macOS may register a newly created keychain itself. Run `python3 Scripts/test-signing-isolation.py` to check repeated setup with a mock `security` command, without accessing real credentials.

This local-source installation is intentionally different from distributing a downloadable app binary. A public binary release with the normal Gatekeeper experience requires an Apple Developer ID certificate and notarisation.

## Use

Choose the target under `Dock Display` in the menu-bar app.

Fixdock can:

- lock the Dock to the display where it already is;
- suppress the Dock edge gesture on non-selected displays through Accessibility;
- enable normal macOS switching when another display is selected;
- lock the Dock again after one manual edge gesture on the selected display.

Only an explicit display selection can start a manual transfer, and it requires
a working Accessibility event tap and a detected Dock on a connected display.
Missing Dock observations, fullscreen/Space transitions, and unexpected display
changes keep switching blocked. A disconnected selected display remains selected;
Fixdock does not silently replace it. Reselect the target to request a transfer
if the Dock is already on another display.

Run `swift test` for regressions covering lost observations, unexpected display
changes, explicit transfers, unavailable protection, edge filtering, and Dock
hiding shortcuts. These tests do not post input events or move the cursor.

While running, Fixdock also disables Dock autohide, locks that preference, and
suppresses Option-Command-D and Fn-A. If autohide is changed externally, Fixdock
corrects the preference and restarts Dock to apply it. Normal quit restores the
visibility settings saved before Fixdock first started; the snapshot survives
an app crash so the next normal quit can still restore them.

Fixdock does not automatically move the Dock to another display. The old implementation that moved the visible pointer was removed and must not return. Cursor-free transfer is researched separately under `Experiments/`.

## Build only

```bash
Scripts/build-app.sh
```

The app is produced at `.build/app/Fixdock.app`.

## How it works

Fixdock writes the internal `com.apple.dock allow-display-switching` preference and uses an Accessibility event tap to suppress the Dock edge gesture on non-selected displays. It detects the current Dock display from the real Dock window, with private `SLSGetDockRectWithOrientation` as a fallback.

This is not a system-process patch. Apple may change the internal Dock behaviour in future macOS releases.

## Project structure

- `Sources/Fixdock/AppDelegate.swift` — menu-bar UI, display selection, and orchestration.
- `Sources/Fixdock/MouseEdgeGuard.swift` — Accessibility event tap.
- `Sources/Fixdock/DockSystemController.swift` — Dock-display detection and preference control.
- `Sources/Fixdock/DisplayManager.swift` — display list and coordinates.
- `Scripts/setup-signing.sh` — creates or reuses the per-Mac signing identity.
- `Scripts/build-app.sh` — builds and signs the app.
- `Scripts/install-app.sh` — installs and launches the app.
- `Scripts/verify-install.sh` — verifies the installed bundle and signature.

## Restore normal Dock behaviour

Quit Fixdock from its menu to restore the saved Dock visibility settings and
allow normal display switching. The following commands only reset display
switching; they do not restore the saved autohide settings:

```bash
defaults delete com.apple.dock allow-display-switching
killall Dock
```
