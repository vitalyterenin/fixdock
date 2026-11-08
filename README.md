# Fixdock

Fixdock is a macOS menu-bar utility that keeps the Dock on a selected display.
It blocks Dock edge gestures on other displays and keeps autohide disabled while
running. Moving the Dock requires one manual edge gesture; Fixdock never moves
the pointer for you.

## Install

Requires **macOS 14 or later and Apple Silicon**.

1. Download [Fixdock.dmg](https://github.com/vitalyterenin/fixdock/releases/latest/download/Fixdock.dmg).
2. Open the image, drag Fixdock to Applications, eject the image, and open the installed app.
3. If macOS blocks the first launch, use **System Settings → Privacy & Security → Open Anyway**.
4. Choose **Open Accessibility Settings** in the Fixdock menu and enable only Fixdock.

The app uses a persistent self-signed certificate, not Apple Developer ID, and is
not notarized. You do not need to install or trust a certificate. Accessibility
enables the event filter; Input Monitoring and Screen Recording are not required.
Fixdock checks access silently and never opens a permission prompt automatically.

## Use

Choose a display under **Dock Display**. When the Dock is already there, Fixdock
locks it. Otherwise, follow the menu status and move the pointer to that display's
Dock edge once. Arrival consumes the transfer request and locks the Dock again.
Selecting a display is the only transfer control. **Launch at Login** is optional
and initially off.

Selection persists locally. A disconnected display remains selected. Missing Dock
observations, Space/fullscreen transitions, and unexpected display changes keep
switching blocked. Reselect the target to request a transfer after an unexpected
move. Without a working Accessibility event tap, the preference lock remains,
but Fixdock cannot filter gestures or authorize a transfer.

While running, Fixdock disables and locks autohide and filters Option-Command-D
and Fn-A. External visibility changes can trigger a corrective Dock restart.
**Quit Fixdock** restores saved autohide settings and allows normal display
switching. The visibility snapshot survives crashes so the next normal quit can
restore it. Forced termination cannot perform cleanup.

## Updates and removal

**Updates → Check for Updates…** checks manually. Automatic checking and installation
are enabled by default, with checks every four hours while running. Saved choices
in the Updates submenu take precedence; installation may wait for quit or permission.
The title shows the running app's version. Feed and archives use Fixdock's own
Ed25519 key; the app and helpers use its persistent code-signing certificate.
A previous locally built copy has a different identity and may need its
Accessibility entry removed and the public copy added once.

To uninstall, turn off Launch at Login, quit normally, then remove the app.
After a crash, reopen Fixdock and quit normally to restore saved visibility.
These recovery commands reset only display switching, not saved autohide settings:

```sh
defaults delete com.apple.dock allow-display-switching
killall Dock
```

## Privacy and limitations

Fixdock stores display selection, a visibility snapshot, and update preferences
in local UserDefaults. The event filter inspects pointer position and shortcut
key codes without recording or transmitting input. There is no telemetry.
Updates contact GitHub Pages and GitHub Releases, which receive normal network
request metadata. System profiling and delta updates are disabled.

The app uses internal Dock preferences, Dock window metadata, and a private
SkyLight rectangle reader as a fallback. Apple can change those mechanisms.
Automatic cursor-free relocation is not implemented. The reported PCSX2 shutdown
case remains unreproduced; see [research history](HANDOFF.md). Experiments are
excluded from the shipped app.

## Build and test

Requires Apple Silicon, Swift 6+ through Xcode or Command Line Tools, Python 3,
and network access to resolve pinned Sparkle dependencies. From the repository root:

```sh
bash Scripts/test.sh
bash Scripts/build-app.sh
"$HOME/Library/Developer/Fixdock/Fixdock.app/Contents/MacOS/Fixdock" --diagnostics
"$HOME/Library/Developer/Fixdock/Fixdock.app/Contents/MacOS/Fixdock" --smoke-test
```

The default build is ad hoc signed for development and cannot be packaged as a
public release. Caches and app output stay outside Documents. Overrides are
`FIXDOCK_BUILD_DIR`, `FIXDOCK_OUTPUT_DIR`, and `FIXDOCK_TOOLS_DIR`. Diagnostics and
menu validation do not write Dock preferences, monitor input, request permission,
or check updates. Swift tests inspect local input events without posting them.

For a stable per-Mac source installation:

```sh
bash Scripts/install-app.sh
bash Scripts/verify-install.sh
```

This builds, installs at `/Applications/Fixdock.app`, and launches the app.
`Scripts/build-local-app.sh` reuses a private per-Mac identity under
`~/Library/Application Support/Fixdock/Signing`, separate from public releases.
Never commit or share the key. Signing-isolation tests use mock security tools.

See [release operations](docs/releases.md) and [maintenance constraints](AGENTS.md).

## Support and license

Report reproducible problems in [GitHub Issues](https://github.com/vitalyterenin/fixdock/issues),
including macOS version, display arrangement, and menu status. Maintained by Vitaly
Terenin. Fixdock is [MIT licensed](LICENSE); Sparkle retains its own terms in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Both documents ship in the app and DMG.
