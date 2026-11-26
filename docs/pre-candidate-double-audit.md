# Glassmacs pre-candidate double audit and hardening ledger

> **Document ID:** DOC-PRE-CANDIDATE-AUDIT  
> **Status:** Informational; source/automated hardening audit complete, physical release gates NOT RUN  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-11-26  
> **Last reviewed:** 2026-11-26  
> **Coverage:** Integrated research-document + native presentation candidate and independent release gates  
> **Supersedes:** None

## Scope and evidence boundary

This audit began at draft integration PR [#112](https://github.com/jmping/Glassmacs/pull/112), baseline `b0b0e7446239d0122dfccddeb3d12aa80eec044d`. The hardening from former stacked PR #137 has been fast-forward consolidated into the validated source snapshot `9d14aeebf16a84cd143e52911f5a503c53731303` ([CI run 45755474378](https://github.com/jmping/Glassmacs/actions/runs/45755474378), all four substantive jobs successful). PR #112 remains draft and is not a publication candidate. The audit deliberately separates *inspected code and automated checks* from *observed physical Cocoa/SSH behavior*. No physical Mac, clean user account, trusted SSH host, Intel test, notarization or distribution test has been performed as part of this pass.

The two independent passes are (A) behavior/data-integrity/lifecycle and (B) packaging/security/release operations. Every risk below is a finding or an explicit verification gap, not a claim of broad certification.

## Audit A — architecture, behavior, lifecycle and data integrity

| Area | Code/evidence inspected | Finding or risk | Severity | Disposition |
| --- | --- | --- | --- | --- |
| Document job ownership | `lisp/glassmacs-document-jobs.el`, `lisp/glassmacs-document-local.el`, `tests/test-glassmacs-document-jobs.el` | The 100-record dashboard cap previously truncated oldest records unconditionally, including running, pending and uncertain jobs; process could remain live but disappear from the dashboard. | P1 | Fix in #137 preserves active/uncertain rows, soft-caps terminal history; adds saturation tests. |
| Document process transitions | `lisp/glassmacs-document-jobs.el`, `lisp/glassmacs-document-local.el` | Pending→running→terminal or uncertain is monotone. Explicit cancellation targets owned local process. Cancellation is best-effort and **not a subprocess-tree guarantee**. | P1 residual | Test nested render subprocess cleanup on packaged macOS, especially cancellation during Quarto/Pandoc child work. Do not assert complete tree termination from the current adapter. |
| Renderer identity | `lisp/glassmacs-documents.el`, `tests/test-glassmacs-document-acceptance.el` | Opt-in concurrent local R Markdown runs use separate jobs, logs and source paths; the legacy single-process path remains default. UI focus/output opening and actual Quarto/Sweave remain physical acceptance gates. | P1 gap | Re-run real R Markdown on exact hardening head; physical concurrent Rmd/Quarto and console routing remain NOT RUN. |
| Output history | `lisp/glassmacs-document-history.el` | Opt-in JSON index is capped, atomically replaced, made mode 0600 and requires local absolute paths. Existing index reads and symlink/file permission behavior merit hostile-profile testing; recorded paths are private metadata, not source code. | P2 residual | Test malformed/oversized JSON, symlinked index/home, write failure and permissions on clean profile. |
| Local preview | `lisp/glassmacs-shiny.el` | A process-output line resembling “Listening on” or “Browse at” was accepted as an arbitrary HTTP(S) URL and auto-opened in the user's browser. | P1 | Fix in #137 accepts only explicit-port loopback URLs; test hostile external hosts, lookalike domains, absent/invalid ports and valid IPv4/IPv6. |
| Shiny lifecycle | `lisp/glassmacs-shiny.el` | Single owned app is intentionally separate from document build processes; reload is user-initiated. Native browser presentation and cleanup after rapid reload/quit remain unobserved. | P1 gap | Stress repeated start/reload/stop, fast exits, malformed output and process cleanup in a packaged Mac. |
| Native windows and ESS | `lisp/glassmacs-frames.el`, `docs/window-presentation-audit.md`, #135, #136 | Ten incremental cycles added close/selection safeguards, but terminal ERT cannot certify Cocoa focus, Finder events, multi-Space/full-screen and live ESS process ownership. | P0 gate | Run physical candidate matrix on two simultaneous live R consoles, multiple tabs/frames and unsaved sources. |
| Remote job provenance | [#102](https://github.com/jmping/Glassmacs/pull/102) and `lisp/glassmacs-remote.el` | Advanced remote-R implementation is on a separate draft head, **not** part of #112. Simple TRAMP helpers in #112 do not mean remote durable R execution has been accepted. | P0 scope gate | Keep #102 independently gated until trusted SSH/disconnect/uncertain/no-replay/artifact checks pass. Decide integration scope explicitly before candidate. |
| Capability inventory | [#109](https://github.com/jmping/Glassmacs/pull/109) | Separate PR against main; its Emacs Plus capability inventory is not incorporated into #112. | P2 scope | Do not describe the inventory as part of the integrated candidate. |

### Audit A regression scenarios

1. Saturate the research-job registry with more than its soft limit of pending/running/uncertain jobs; retain each owner's dashboard row, ID and cancel/log affordance. Insert completed jobs without sacrificing active visibility.
2. Feed a Shiny process-log buffer an external `Listening on` URL followed by a real loopback URL; ignore external links and use only validated loopback with explicit port. Exercise incomplete output lines.
3. Run concurrent real R Markdown builds and cancel one with an active child process; verify surviving peer, child cleanup, status and no replay.
4. Packaged macOS: cycle documents, R Help, Customize, inactive tabs, native close and frame focus while two ESS processes are live; record source/console selection at every step.

## Audit B — release, security, dependency and operability

| Area | Evidence inspected | Risk/gate | Severity | Required verification |
| --- | --- | --- | --- | --- |
| CI scope | `.github/workflows/ci.yml`, #112 [prior exact-head CI](https://github.com/jmping/Glassmacs/actions/runs/45745743006) | Window-only jobs passed batch ERT and app-bundle checks, but `ess-r-integration` was path-filtered skipped. No automatic inference that real R tested the combined head. | P0 before candidate | On final candidate SHA require successful real ESS/R job (not skipped) and inspect real test skip counts, in addition to Emacs/macOS jobs. |
| macOS bundle integrity | `scripts/build-macos-app`, `scripts/validate-macos-app` | Pinned upstream archive checksum, launcher compilation, Mach-O relocation and bundled startup checks exist. These are static/terminal checks, not clean-machine LaunchServices or GUI certification. | P0 gate | Verify same exact app bytes on arm64 and Intel, no Nix/Homebrew dependency, isolated profile, Finder and Dock. |
| Distribution trust | `scripts/sign-macos-app`, `scripts/notarize-macos-app`, `docs/macos-acceptance-checklist.md` | Signing/notarization/Gatekeeper/corresponding-source and license review not evidenced for this future commit. Prior signed artifact cannot certify a changed candidate. | P0 gate | Review redistributable upstream Emacs/ESS dependencies; sign/notarize and Gatekeeper-test only after candidate is selected. |
| Restart and close | `docs/macos-acceptance-checklist.md`, `docs/research-document-integration-acceptance.md` | Native unsaved-document prompts, Dock Quit, crash restoration, multi-monitor placement and no process replay still need observed results. | P0 gate | Run documented exact-build scenarios and attach dated logs/screenshots/results. |
| Third-party toolchain | `.github/workflows/ci.yml`, `macos/upstream-emacs.env`, `macos/bundled-ess.env` | Pinned Emacs/ESS and polymode revisions improve reproducibility, but clean-machine R/Quarto/Pandoc availability and runtime version matrix are not covered by static bundle success. | P1 gate | Record exact versions and missing components; use a fresh macOS account and record skip as NOT RUN. |
| Remote trust | #102 and research-document acceptance | Mock-based TRAMP tests do not establish real host-key prompts, interrupt recovery, no-replay behavior or artifact bounds on a trusted server. | P0 separate gate | Keep no credential bypass and no production host probing in CI. Physical/trusted-host acceptance must be explicit. |
| Provenance of acceptance | `acceptance/matrix.toml` and generated documentation | Results for prior heads cannot be promoted to final commit; generated checklist currently marks physical items NOT RUN. | P0 gate | Every result must identify source SHA, binary SHA-256, platform, operator, outcome and evidence. Modify source matrix then regenerate; do not hand-edit generated files. |

## Candidate decision rules

- **Block** candidate cut for any P0 data loss, accidental termination/replay, wrong-console execution, remote host trust failure, broken packaged launch, unresolved native close prompts, or invalid distributable license/source provenance.
- **Require** exact final-head CI including the real ESS/R integration path; document skipped tests and flakes. A green overall workflow with a skipped required job is insufficient.
- **Require** physically witnessed GUI, clean-machine and both-architecture checks against the exact built artifact, not older artifacts or Linux ERT.
- **Allow** P2 cosmetic/documentation debt only when it is described transparently and demonstrably cannot threaten data or release trust.
- **Hold** draft #112, #102, #137 and `main` unchanged with respect to publication until gates are met. No DMG publication by automation.

## Tracking and next actions

**Verified at frozen source SHA `9d14aee`:** PR #137's hardening changes are incorporated into #112 via protected fast-forward. [Exact-head run 45755474378](https://github.com/jmping/Glassmacs/actions/runs/45755474378) reports `changes`, `emacs-batch`, **real `ess-r-integration`**, and `macos-launcher` success. No GUI, Intel, clean-machine, trusted SSH or Gatekeeper pass is inferred. Next: build the frozen private validation candidate on a physical Mac using [the Copilot handoff](validation-candidate-2026-11-26.md); run packaged GUI and R/Quarto/close acceptance; separately triage #102 for trusted SSH; inspect signing/licenses; record defects and repeat affected gates before authorizing any public release.
