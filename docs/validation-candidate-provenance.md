# Signed validation candidate provenance

**Candidate, not yet published:** `Glassmacs-main-b7f1996-validation.dmg`,
213,096,758 bytes, SHA-256
`3ac8d1a16a7e422b5e1aa54857a72e9b6dbd1217733ef15c446f2454300e35fd`.

The application was built from Glassmacs
[`b7f19966e447ad94c5d894211a2dfe15a86c184e`](https://github.com/jmping/Glassmacs/commit/b7f19966e447ad94c5d894211a2dfe15a86c184e),
before the distribution infrastructure changes containing this document.
Those changes did not produce the application's binaries. Record the
infrastructure commit and the application commit separately in any release
evidence; do not imply this candidate was rebuilt from the infrastructure
commit. Its bundle predates `GlassmacsReleaseVersion` and reports the upstream
Emacs version as its short version.

Developer ID signing, hardened runtime, secure timestamp, Apple notarization,
stapling and Gatekeeper assessment succeeded for the DMG and mounted app.
Apple submission `a3c15008-ec66-489f-9f20-f2acb42a1603` was accepted with
no issues. The mounted app validator inspected 547 Mach-O files and their
direct dependencies. An isolated arm64 process explicitly compiled an `.eln`
file; it did not demonstrate loading that file from an untrusted cache.

Recorded results: ERT 489 passed, 18 skipped, 0 unexpected; Python 49 passed;
Swift 7 passed. These results concern the candidate and then-current
infrastructure, not a later rebuilt binary. A prior background Cocoa smoke
test exercised two real R processes, source routing and queue operations.
Physical GUI interactions, clean installation, downloaded quarantine and
Intel execution remain unverified. macOS 13 is the declared minimum; the
candidate was tested on Apple Silicon with macOS 27.2.1, Emacs 31.1, ESS
26.5.0 and R 4.6.2.

Local evidence is retained under `build/distribution-evidence/` and must be
reviewed for privacy before release. SHA-256 fingerprints:

| Evidence | SHA-256 |
| --- | --- |
| Apple notary log | `63327658beb72bb3db97ddf84bf2c8adfcd5e079d81558c6528a4b142c89e0ca` |
| Apple submission result | `6776ddf3e3a93cfbc4848c214ee75b7f65e13224c6744dc34e4754d5058e1115` |
| DMG validation log | `c6f40a67bda9d9c31bba007c6213b0169ee5264da8db4660249b0a7b58efc122` |
| ERT log | `f406d86d11a2a5ec1a85f3c6529fe238c87f04f868a6dfa85c0d20a699ac103b` |
| Python log | `3dec8d0fc6383eedeaa38f0e68e471fd63d5d3bb67eecddb4235d22f466f560c` |
| Swift log | `ea6188f56f05af66572f8514fe2e41b0a9a4f57ad336cc6640b8779597c6e135` |
| Native compilation probe | `9a1a9bd9a6bd2d3dfa95901fdcb462dfe3e1a9e3c8b66683a351aa991ab69a91` |

The candidate must not be published until the unresolved source and licensing
items in [the source inventory](macos-source-inventory.md) are resolved.
