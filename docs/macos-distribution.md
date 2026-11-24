# macOS distribution candidates

This process is separate from the ad-hoc development build in
[`macos-launcher.md`](macos-launcher.md). **A signed and notarized image is
not, by itself, a release approval.** In particular, the exact corresponding
source and licenses for the pinned upstream Emacs build and all redistributed
dependencies must be identified, obtained and reviewed before publication.
The links included in the DMG are not a substitute for that review.

## Prerequisites

- macOS with Xcode command-line tools, R, and the dependencies described in
  `macos-launcher.md`; network access to Apple and GitHub.
- A valid **Developer ID Application** identity with its private key:
  `security find-identity -v -p codesigning`. Select its SHA-1 explicitly; do
  not use an ad-hoc or Mac App Store identity.
- A notarytool Keychain profile, created interactively with
  `xcrun notarytool store-credentials glassmacs-notary`. Check it with
  `xcrun notarytool history --keychain-profile glassmacs-notary`. Never put
  credentials, private keys or exported certificates in this repository.
- A clean release checkout at the reviewed commit and a unique version and
  build number. The stable bundle identifier is `org.glassmacs.Glassmacs`.
  Glassmacs versions are `X.Y.Z`, `X.Y.Z-alpha.N`, `X.Y.Z-beta.N` or
  `X.Y.Z-rc.N` (without a leading `v`). `CFBundleShortVersionString` is the
  numeric `X.Y.Z`; the full release version is `GlassmacsReleaseVersion`.
  `CFBundleVersion` is a monotonically increasing numeric build number of one
  to three components, e.g. `2026.11.23`. Keep a release ledger and increase
  it for every distributed build.

## Build and package

The following produces a candidate only; it does not install or publish it.
Replace the placeholders with reviewed values and use a clean checkout:

```sh
export GLASSMACS_SIGN_IDENTITY=DEVELOPER_ID_CERTIFICATE_SHA1
export MACOSX_DEPLOYMENT_TARGET=13.0
./scripts/update-build-sign --no-pull --require-notarization \
  --notary-profile glassmacs-notary --version 0.2.0-beta.1 --build-number 2026.11.23
./scripts/package-macos-dmg build/Glassmacs.app \
  build/artifacts/Glassmacs-v0.2.0-beta.1.dmg glassmacs-notary
```

The version is set before code signing; builds without version options retain
the previous development behavior. The first command builds, runs ERT, Python
and Swift suites, signs, notarizes and staples the app. It also creates its
legacy ZIP. The second requires an already stapled Developer ID app, constructs
an image with an Applications link and notices, signs it with a timestamp,
submits it using notarytool, checks Apple's submission ID and archive hash in
the log, staples it, then mounts it read-only and validates the app and image.
Only after these checks is the DMG and its `.sha256` created. Submission and
Apple log JSON files are kept beside the DMG; on rejection inspect the log.
Outputs are never overwritten.

Signing explicitly seals nested Mach-O files, the known helper app, Emacs and
the outer bundle with hardened runtime. Unknown nested code bundles are rejected
until an explicit signing order is added. No broad library-validation or JIT
entitlement is granted. The pinned app currently disables native JIT by
default; loading bundled native Lisp is not proof that on-demand compilation
works. Some embedded libgccjit strings reference `/nix/store`; these are not
proof that a clean machine can compile native Lisp. Investigate and validate
this on each supported architecture without relaxing hardened runtime merely
to make a test pass.

## Release gate and publication

Independently verify the exact DMG and record the actual results, skips and
evidence locations. Prepare an archive containing the **complete corresponding source**
and required licensing materials for the actual distributed binaries, not
just a GitHub auto-generated archive of Glassmacs. Obtain a qualified license
review and retain its evidence. Do not mark missing tests or unavailable
source as passing.

Create a UTF-8 JSON evidence file bound to the exact artifacts. Each of these
keys must have a `result`, a named `reviewer`, and an `evidence` location
describing the actual review or test:

`automated_tests`, `native_gui_arm64`, `native_gui_x86_64`,
`clean_install_arm64`, `clean_install_x86_64`, `native_compilation`,
`dependency_audit`, `ess_r`, `corresponding_source_and_licenses`.

The top-level fields are `version`, the full 40-character `commit`,
`dmg_sha256`, `source_sha256`, and `checks` (the object of check entries).
Use `shasum -a 256` on the final stapled DMG and source archive. This is a
reviewer attestation, not automated proof of the underlying checks; reviewers
must preserve detailed test records.

For stable and ordinary prereleases every result must be `pass`. For an
explicitly labeled **validation prerelease**, pass `--validation-prerelease`.
It still requires passing automated tests, dependency audit, ESS/R and
corresponding-source/license review. GUI, clean installation and native
compilation observations must be recorded with `pass`, `fail` or `not_tested`,
but are not publication prerequisites. Each observation still needs a
reviewer and an evidence description, even when not tested. Validation
evidence also needs `application_commit` and `provenance`; the application
commit must be an ancestor of the tagged infrastructure commit. Release notes
must clearly identify tested platforms and outstanding checks.
Pass `--evidence-artifact /path/to/reviewed-evidence.zip` with at least one
privacy-scrubbed artifact containing the validation records; the publisher
uploads it alongside the evidence JSON.

The existing candidate predates the Glassmacs version field. To use it without
changing signed bytes, rename a *copy* to the required versioned DMG filename
and copy its matching `.notary-log.json` alongside it. Supply
`--legacy-bundle-version 31.1` and the same `legacy_bundle_version` in
evidence. The release tag is a distribution label, not a version embedded in
that app. Preserve the separate application and infrastructure commits and
the original candidate SHA-256. A legacy bundle is allowed only for a
validation prerelease; a new versioned build remains the normal path.

After review, create and push the exact `vX.Y.Z[-channel.N]` tag at that
commit. With nonempty release notes, publish explicitly:

```sh
./scripts/publish-macos-release --publish \
  --dmg build/artifacts/Glassmacs-v0.2.0-beta.1.dmg \
  --source /path/to/corresponding-source.tar.gz \
  --evidence /path/to/reviewed-evidence.json \
  --notes /path/to/release-notes.md
```

For the existing candidate, after resolving the source blocker and preparing
reviewed evidence, an example validation invocation is:

```sh
cp build/distribution-evidence/Glassmacs-main-b7f1996-validation.dmg \
  build/artifacts/Glassmacs-v0.1.0-alpha.3.dmg
cp build/distribution-evidence/Glassmacs-main-b7f1996-validation.dmg.notary-log.json \
  build/artifacts/Glassmacs-v0.1.0-alpha.3.dmg.notary-log.json
./scripts/publish-macos-release --publish --validation-prerelease \
  --legacy-bundle-version 31.1 \
  --dmg build/artifacts/Glassmacs-v0.1.0-alpha.3.dmg \
  --source /path/to/reviewed-complete-corresponding-source.tar.gz \
  --evidence /path/to/reviewed-evidence.json \
  --evidence-artifact /path/to/reviewed-validation-evidence.zip \
  --notes /path/to/release-notes.md
```

Choose the next unused version after checking GitHub tags. The source archive,
evidence and release notes are not generated by these commands.

This command requires a clean checkout, matching local and origin tags,
matching evidence and checksums, a versioned app inside a signed/stapled DMG,
Gatekeeper acceptance, and the app validator. It creates a draft release with
the DMG, corresponding source, checksums, Apple log, reviewed evidence and
tester checklist/report tool before publishing it. The evidence is public:
remove personal paths, credentials and other private information before
passing it to the publisher.
Alpha, beta and release candidates are prereleases; an unqualified version is
stable. If asset upload or publication fails, inspect the draft on GitHub
before retrying. It never silently replaces an existing release.

Populate `website/src/data/releases.json`'s `validation` object **only after**
the release is public and links work without authentication. Provide `version`,
`date`, `size`, `minimumMacOS`, `architectures`, `limitations`, `asset`,
`notes`, `source` and `checksums`; use actual release asset URLs. The current
site deliberately points to the existing alpha ZIP, not an unpublished DMG.
See [the tester checklist](validation-acceptance.md) and
[candidate provenance](validation-candidate-provenance.md).
Future GitHub Actions credentials should be supplied through protected
secrets/Keychain and retain the same gates; Sparkle, Homebrew and separate
automatic update channels are not implemented.
