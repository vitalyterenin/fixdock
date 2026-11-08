# Fixdock maintenance

Write source, documentation, and GitHub content in English. Preserve bundle ID
`local.vitalyterenin.Fixdock`, update key, and pinned release certificate. Use the
refreshed `app-release` skill and [release guide](docs/releases.md).

Never move or hide the pointer, warp it, or post synthetic mouse/edge events to
transfer Dock, including in experiments. Do not restore DockRelocator. Only a
proven cursor-free transfer may replace the manual gesture. Dock restarts are
allowed only for existing visibility correction/restoration, never for transfer.
Preserve a single display-selection control.

Run `bash Scripts/test.sh` and build the app for changes. Diagnostics and smoke
tests must not write Dock settings, request permissions, or start monitoring.
Build outside Documents to avoid file-provider signature invalidation. Local
signing must never alter the user's keychain search list. CI may import the
pinned key temporarily but must restore its search list and delete its keychain.

MIT is owner approved. Review all maintained docs and complete dependency notices
before tagging. Verify both app and DMG notices in the anonymous public download.
Keep experiments outside the shipped app.
