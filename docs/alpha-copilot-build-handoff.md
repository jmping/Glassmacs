# Alpha candidate build handoff (Copilot)\n\n> **Historical handoff warning (2026-11-06):** This handoff predates the decision to remove GitHub-hosted GUI acceptance. Its requirement for a packaged GUI CI job is obsolete. The current candidate requires successful applicable batch, ESS/R and macOS build/packaging checks, followed by separate local Mac GUI acceptance. See [development](development.md) and the [acceptance matrix](acceptance-matrix.md).\n

This document is the handoff for building the **unsigned, testable Alpha
candidate**, not a declaration that Layer D manual acceptance has passed.

## Preconditions

1. PR #77 is merged into `main` and the chosen candidate commit SHA is
   recorded. Do not build from an unreviewed PR head or an earlier SHA.
2. The candidate SHA has successful Emacs batch, real ESS/R, macOS launcher,
   and packaged GUI jobs. The packaged GUI job must pass
   `scripts/check-alpha-gui-results` (no silently skipped core scenarios).
3. The CI artifact `Glassmacs-macOS-app` exists and the packaged app passes
   `scripts/validate-macos-app`. CI's artifact is the first candidate to
   test; avoid rebuilding unnecessarily.
4. Record architecture, macOS/Xcode versions and SHA alongside the archive.
   Do not describe a single-architecture build as universal.

## Copilot build instruction

> Check out the specified `main` SHA. Build an unsigned Glassmacs Alpha
> candidate using `scripts/build-macos-app` and validate it using
> `scripts/validate-macos-app`. Run `scripts/test`, the existing macOS
> launcher tests, and `scripts/macos-gui-acceptance` against the packaged
> `Glassmacs.app`. Run `scripts/check-alpha-gui-results` on the resulting
> `results.json`; treat skipped required scenarios as failures. Preserve
> `summary.md`, `results.json`, screenshots, warnings, and crash logs.
> Archive the app using `ditto -c -k --sequesterRsrc --keepParent`.
> Report the exact commit SHA, OS/CPU/Xcode, command outcomes, artifact
> name and checksums. Do not claim clean-machine, real-user Dock/Finder,
> interactive graphics, or performance acceptance without recorded
> evidence. Do not sign/notarize unless separately authorized and configured.

## Tester's Layer D checklist

Follow `docs/alpha-acceptance.md` and the generated
`docs/macos-acceptance-checklist.md`. Run from a fresh macOS user account
with the archive unpacked in /Applications. Record PASS/FAIL/NOT RUN,
reproduction steps, hardware/OS, build SHA and evidence for every P0.

Pay particular attention to native Save / Don't Save / Cancel; closing the
last frame; Dock reopen and Finder open; recovery after forced termination;
ESS line/region/function/buffer submissions; interrupt with 100 pending
commands; sustained output; R Help and base/ggplot2 graphics.

**Stop and file a blocker** for data loss, nonresponsive editor, wrong-session
execution, unsafe automatic queue replay, missing libraries, or any required
core GUI scenario that was skipped or failed. The testable Alpha candidate
may be delivered before human Layer D testing, but must not be called
fully accepted until the manual evidence is recorded.
