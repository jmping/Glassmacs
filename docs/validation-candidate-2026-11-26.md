# Glassmacs private validation candidate — frozen source and Copilot handoff

> **Document ID:** DOC-VALIDATION-2026-11-26  
> **Status:** Informational, pre-candidate handoff; NOT a release or acceptance certificate  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-11-26  
> **Last reviewed:** 2026-11-26  
> **Coverage:** Exact source freeze, feature/architecture scope, Mac build instructions, evidence and release stop conditions for the next internal validation candidate  
> **Supersedes:** None

## Frozen runtime source and ownership

| Item | Exact value or disposition |
| --- | --- |
| Repository | `jmping/Glassmacs` |
| **Source commit (do not substitute a PR merge SHA)** | `9d14aeebf16a84cd143e52911f5a503c53731303` |
| Immutable-by-procedure checkpoint branch | `candidate/validation-2026-11-26` — do **not** push new commits to it; Git branches can technically move, so verify its head before and after the build. |
| Source-of-truth integration review | [Draft PR #112](https://github.com/jmping/Glassmacs/pull/112) — keep draft, do not merge to `main`. |
| Hardening history | #137 was fast-forwarded into #112. Its earlier source slices remain auditable in Git history. |
| Exact-head CI evidence | [Run 45755474378](https://github.com/jmping/Glassmacs/actions/runs/45755474378), all four jobs **success**: `changes`, `emacs-batch`, `ess-r-integration` (real R), `macos-launcher`. |
| Pinned upstream runtime | Cocoa GNU Emacs **31.1 universal** from `macos/upstream-emacs.env` with SHA-256 `f0383bcbf0104947d3a46266aae43e3dc9e38fd68eeb35f11ee6b9444277b8ec`. |
| Bundled ESS | **26.5.0**, pinned by `macos/bundled-ess.env`, archive SHA-256 `49b40ebf5eee0e24ca0aa8c4c7add3696d8b55b19eb0de0036960f6c1994ae1e`. |
| Candidate class | **Private local macOS validation beta**, NOT a public release, notarized release, or cleared `main` integration. |
| Docs-only handoff branch | `docs/pre-copilot-candidate-readiness-2026-11-26`: instructions only; **do not build this SHA as a substituted runtime candidate**. |

The source freeze and CI apply to the *source commit* above, not to a later documentation commit. No Git tag, GitHub Release, public asset, signed release, or DMG is authorized by this handoff.

## Scope cut and exclusions

**Included**: current GNU Emacs-based local macOS Glassmacs app with native document/frame/tab presentation and lifecycle protections; bundled ESS/R UI; explicit multiple live local R-console routing; local document context and opt-in R Markdown/Quarto/Sweave build-job lifecycle; Shiny process and protected loopback preview; private remembered-output history, logs, dashboard and recovery infrastructure already present in #112.

**Excluded / not certified**: the **advanced remote-R/SSH/host-trust/durable-job campaign #102**, separate Emacs capability inventory #109, and distribution/signing campaign #106. Their features and acceptance gates are **not** inherited by this candidate. Basic upstream TRAMP file-editing behavior does not constitute support for advanced remote execution. No upstream Emacs fork or proprietary Aquamacs code.

Do not expand this scope in a Copilot build. If a scenario exposes a source defect, capture a reproduction and route it to the maintainers; do not silently patch the source or substitute a new commit.

## Architecture and operating-system truth

The build script produces *universal* `arm64` and `x86_64` launcher and quit-helper slices from a pinned universal Emacs app and validates both slices statically. `macOS 13.0` is the minimum value in the app's `LSMinimumSystemVersion` metadata. **Neither fact proves physical Intel operation or macOS 13 compatibility.** The current CI macOS builder runs on Apple Silicon/macOS 15. The first internal candidate is **Apple Silicon-first (provisional)**; Intel and additional macOS versions remain **NOT RUN** until the exact archive has been tested on that hardware. Record Rosetta status explicitly; never relabel a static universal check as Intel acceptance.

The default build uses ad-hoc signing for local development. Developer ID signing, notarization, stapling, browser-downloaded Gatekeeper behavior, and redistributable corresponding-source/license verification are separately gated. **Do not publish or assert them as complete.** A **private unsigned/ad-hoc-signed zipped app** may be generated and locally tested in an isolated profile; do not disable Gatekeeper/security settings or overwrite the user's installed applications.

## Exact assignment to Copilot (Mac with GUI/terminal)

1. **Protect the local machine**: use the existing checkout or a fresh isolated clone; check `git status --porcelain`; if dirty, do not reset, clean, overwrite, or continue in that worktree. Preserve existing installed Glassmacs/Aquamacs/Emacs and user profiles. Fetch branch `candidate/validation-2026-11-26`, verify that `git rev-parse HEAD` **and** `git rev-parse origin/candidate/validation-2026-11-26` equal the full frozen SHA. Abort on mismatch. Use disposable fixture documents and an isolated `GLASSMACS_HOME`.
2. **Capture environment and pins**: `sw_vers`, `uname -m`, `xcodebuild -version`, `swift --version`, `R --version`, `quarto --version`, `pandoc --version` and optional Skim/TeX packages (mark unavailable items NOT RUN). Preserve `macos/*.env` checksums, upstream download hash validation, and real ESS version.
3. **Prefer the exact-head CI archive** when it is retrievable, preserving the artifact ID and workflow run. Otherwise build once from the frozen commit. Use a **new empty output directory** under `build/validation-2026-11-26/`, not an existing installed app. `scripts/build-macos-app` removes an *existing build-tree output path*; check it is absent before invoking.
4. **Build and validate** (when a local build is necessary):
   ```sh
   git fetch origin
   git switch --detach 9d14aeebf16a84cd143e52911f5a503c53731303
   test "$(git rev-parse HEAD)" = 9d14aeebf16a84cd143e52911f5a503c53731303
   test -z "$(git status --porcelain)"
   mkdir -p build/validation-2026-11-26
   test ! -e build/validation-2026-11-26/Glassmacs.app
   ./scripts/build-macos-app build/validation-2026-11-26/Glassmacs.app
   ./scripts/validate-macos-app build/validation-2026-11-26/Glassmacs.app
   GLASSMACS_EMACS="$PWD/build/validation-2026-11-26/Glassmacs.app/Contents/MacOS/Emacs" \
     GLASSMACS_HOME="$PWD/build/validation-2026-11-26/batch-home" ./scripts/test
   ```
   Capture all stdout/stderr logs and exit codes. Check `lipo -info` on the app launcher and Emacs, `codesign --verify --deep --strict`, Mach-O links and the bootstrap. Record `codesign -dv` metadata: an ad-hoc signature is **not** Developer ID distribution acceptance. Use a fresh native-compilation cache; never transplant cached compiler artifacts across build identities.
5. **Run packaged GUI automation** on the actual `Glassmacs.app` in a GUI macOS session, not a Linux batch runner:
   ```sh
   ./scripts/macos-gui-acceptance \
     build/validation-2026-11-26/Glassmacs.app \
     build/validation-2026-11-26/gui-acceptance
   python3 scripts/check-alpha-gui-results \
     build/validation-2026-11-26/gui-acceptance/results.json
   ```
   Retain `results.json`, `summary.md`, warnings, screenshots, crash logs, driver logs and exclusions. The harness simulates some keyboard/close events; **native real input and dialogs require manual observation**.
6. **Physically exercise P0 cross-feature scenarios** using only scratch data: (i) two distinct live local R processes and source-linked execution even when another console has focus; (ii) two modified documents in different frames/tabs, native close, cancel, Save/Don't Save and Quit; (iii) Finder/Dock activation with no window, Help/Customize independent presentation, inactive-tab navigation; (iv) concurrent same-name R Markdown/Quarto jobs, cancel one, check all descendant processes and source-specific outputs; (v) Shiny start/reload/stop and loopback-only preview; (vi) forced termination, recovery without execution replay; (vii) clean macOS account and test on Apple Silicon; (viii) Intel only if physically available, otherwise **NOT RUN**.
7. **Archive and prove provenance**. For a local candidate:
   ```sh
   ditto -c -k --sequesterRsrc --keepParent \
     build/validation-2026-11-26/Glassmacs.app \
     build/validation-2026-11-26/Glassmacs-validation-9d14aee.zip
   shasum -a 256 build/validation-2026-11-26/Glassmacs-validation-9d14aee.zip
   ```
   Record source SHA, source ref, archive ZIP SHA-256, binary architecture slices, OS/CPU/Xcode/Swift versions, upstream Emacs/ESS hashes, whether the archive was from CI or locally rebuilt, operator, signing identity, notarization status, and exact app path. Binary checksum is **not known** before the archive exists.
8. **Return a handback**, not a release: `candidate-manifest.md`, `build.log`, `validate.log`, `batch-tests.log`, `gui-acceptance/results.json`, `gui-acceptance/summary.md`, `manual-matrix.md`, `issues.md`, screenshots/crash evidence. Give every applicable P0 a **PASS / FAIL / NOT RUN** with exact build SHA and reproduction/evidence; record workarounds and unsatisfied gates. **Never silently skip required P0**.

## Stop conditions and final authority

Stop and report a P0 if any unsaved document is lost or silently discarded; source code executes in the wrong R session; cancellation terminates the wrong job or silently replays an R session; a native close/quit prompt cannot veto deletion; the packaged app fails to start or loads unbundled libraries; archive and source cannot be matched; signing/source provenance is ambiguous; or unexpected remote execution occurs. Do not downgrade a failure to a visual/cosmetic issue.

Only the maintainers can subsequently authorize selecting a release candidate, merging `main`, signing/notarizing for distribution, and publishing a DMG. The private candidate build may start **before** physical acceptance (it provides the test object), but a release may not.

### Acceptance sources

- [Pre-candidate double audit](pre-candidate-double-audit.md)
- [macOS physical acceptance checklist](macos-acceptance-checklist.md) — **generated; edit `acceptance/matrix.toml`, not the generated Markdown**
- [Window-presentation audit](window-presentation-audit.md)
- [Research document integration acceptance](research-document-integration-acceptance.md)
- [Earlier linked-presentation Mac handoff](copilot-candidate-handoff.md) — PR #98-specific historical reference; use **this exact SHA** rather than the PR #98 SHA.
- [Release preparation #106](https://github.com/jmping/Glassmacs/pull/106) — separate and incomplete.
