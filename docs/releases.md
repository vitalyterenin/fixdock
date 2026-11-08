# Fixdock release operations

Use the refreshed `app-release` skill and its
[publishing conventions](https://github.com/vitalyterenin/app-release-kit/blob/main/skills/app-release/references/publishing.md).
Fixdock supports macOS 14+ on Apple Silicon with one stable channel.

## Identity

`release.json` owns version, increasing build, repository, permanent URLs, public
Ed25519 key, approved MIT license, and release certificate SHA-256. Preserve bundle
ID `local.vitalyterenin.Fixdock`, public update key, and `Resources/ReleaseSigning.cer`.
The first downloadable release is 0.1.1 (build 2), following source-only 0.1.0.
There is no prior public feed to migrate.

- Download: https://github.com/vitalyterenin/fixdock/releases/latest/download/Fixdock.dmg
- Feed: https://vitalyterenin.github.io/fixdock/appcast.xml
- Apps catalog: https://teren.in/apps/

The pinned persistent self-signed certificate signs the app and updater helpers.
It is not Developer ID or notarization. Users can need Open Anyway at first launch;
they must not install a trusted root or weaken security settings. Local-source
builds have a different identity and may need one Accessibility grant reset.

Private backups stay outside source. Repository Secrets are `SPARKLE_PRIVATE_KEY`,
`FIXDOCK_SIGNING_P12`, and `FIXDOCK_SIGNING_PASSWORD`. Publication uses GitHub's
short-lived repository token. Website/cloud credentials do not belong here. PR
checks have no signing secrets and use ad hoc signatures rejected by packaging.

## Checks and documentation

From the repository root, with Swift 6+, Python 3, and Xcode or Command Line Tools:

```sh
python3 Scripts/release.py validate
bash Scripts/test.sh
bash Scripts/build-app.sh
"$HOME/Library/Developer/Fixdock/Fixdock.app/Contents/MacOS/Fixdock" --diagnostics
"$HOME/Library/Developer/Fixdock/Fixdock.app/Contents/MacOS/Fixdock" --smoke-test
```

Swift regressions cover observation loss, transfers, disconnected targets, edge
filtering, and shortcuts. Python checks cover publication, signing, and notices.
Local-signing tests mock security tools. Diagnostics/menu checks do not start
protection, write Dock settings, request permissions, or contact update hosts.

Before every release, review README, AGENTS, this guide, HANDOFF, experiment
READMEs, LICENSE, dependency notices, GitHub About, and the Apps card against the
whole app/configuration/workflow. Keep history labeled; correct current commands
and claims. Verify links, commands, images, and changed Markdown rendering. Record
scope, corrections, and actual verification in the PR before tagging.

## Publish

1. Increase version/build, complete documentation, and prepare catalog changes.
2. Push a PR, wait for checks, and merge its exact checked head normally.
3. Tag the merged commit with matching `v<version>` and push the fresh tag.
4. Wait for build and publish jobs in **Release Fixdock**.
5. Verify public feed/DMG signatures, hashes, length, version/build, architecture,
   and complete notices inside the downloaded app and image.
6. Deploy the Apps card through the separate website publication path.

Branch pushes do not publish. Workflow dispatch on a branch prepares artifacts;
dispatch on a matching tag publishes. Pages uses Actions and `github-pages`
allows `v*` tags. Keep release immutability off for old-DMG cleanup.

The macOS job imports the pinned certificate into an isolated CI keychain and
restores the runner's search list. It builds arm64 code and helpers, embeds notices
before signing, verifies certificate-bound requirements, and creates an APFS DMG
with Applications shortcut. It mounts the image read-only for checks, verifies
prior signed feed/build monotonicity, and signs/verifies archive and single-entry
feed. Keys are deleted even on failure; artifacts/hashes are retained for 14 days.

Linux verifies hashes, tag/commit identity, prior feed snapshot, and release state;
it publishes a draft DMG release and verifies anonymous bytes before deploying
Pages. Only after feed/download convergence are old DMG assets removed. Preserve
release records, tags, and unrelated assets. Publication is serialized without
cancelling an active run.

Never overwrite published bytes, force-move tags, or bypass signatures. Retry a
failed publisher with its verified artifact; changed bytes need a new version/build.
GitHub caching can temporarily disagree; Sparkle must reject mismatches and retry.

## Licenses and local builds

Preserve complete MIT terms/copyright and Sparkle 2.10.1's full upstream license
and external notices in `THIRD_PARTY_NOTICES.md`. `Scripts/licenses.py` verifies
terms, dependency pin, actual upstream text, and embedded copies. Recheck license
terms after dependency upgrades. Both documents go into
`Contents/Resources/Licenses` before signing and into the DMG root. Verify the
finished mounted image and repeat on the public download. Tests include an
app-only install with the original image removed.

Build/cache/tool overrides: `FIXDOCK_OUTPUT_DIR`, `FIXDOCK_BUILD_DIR`, and
`FIXDOCK_TOOLS_DIR`. Sparkle tools are version/hash pinned. Release signing needs
`FIXDOCK_SIGN_KEYCHAIN` and `FIXDOCK_REQUIRE_RELEASE_SIGNING=1`; packaging rejects
ad hoc identity. CI passes the update key through stdin, never command arguments.

`Scripts/install-app.sh` calls `Scripts/build-local-app.sh` to preserve stable
per-Mac source identities. They remain separate from public signing and cannot
pass release packaging. Never regenerate public identities to bypass missing keys.
