# Glassmacs Remote R Campaign — Integrated Acceptance

> **Scope:** PR #102 integration branch, with SSH/ESS, remote queue safety,
> durable Rscript jobs, cancellation, and explicitly retrieved graphics/artifacts.
> **Certification:** Not yet performed on a real SSH host or macOS GUI.
> **Release gate:** Keep draft and out of main until the owner verifies the full
> campaign as one packaged-app component.

## Automated gates

Use the normal repository GitHub CI for the consolidated #102 head. Record
the exact SHA, run URL and outcomes for `emacs-batch`, `ess-r-integration`
and `macos-launcher`. Unit tests use mocked process/host contexts; a green
CI is **not** evidence of an actual remote R process.

## Mac GUI + opt-in SSH acceptance (manual)

Configure a test SSH alias in `~/.ssh/config` pointing to a machine with
`Rscript`, R, and a writable project directory. Never publish credentials
or machine-specific paths in GitHub test fixtures.

| Step | Acceptance requirement | Evidence |
| --- | --- | --- |
| Local regression | Open local R and run ESS code; the local queue/graphics/windowing controls still work | screenshot + result |
| Remote startup | R > New Remote R Console; the remote R prompt works and `Sys.info()[["nodename"]]` and `Sys.getpid()` identify the remote host | redacted transcript |
| Multi-session | Run local R and two independent remote consoles, switch source targets, and verify the correct host receives each command | redacted transcript |
| Cross-host safeguards | Open source on host A, link console on host B, verify submission blocks until explicit R-menu approval; verify changed host or target invalidates approval | no-send evidence |
| Queue failure | Submit long-running R and a second queued command, sever remote SSH; in-flight command becomes uncertain, second orphaned and **neither replays** after new console starts | queue inspector screenshot |
| Durable server-owned job | Submit a source file using R > Submit Durable Remote Rscript Job; close Glassmacs entirely, reopen, restore private local registry, and inspect job status and logs | job ID + result |
| Cancellation | Submit an opt-in long Rscript job, request cancellation, verify server marker and that the remote process exits; no PID guessing from Glassmacs | redacted server status |
| Artifacts | Generate PNG and PDF remotely, preview via R menu without X11, associate one preview with remote ESS session; explicitly download to a local path | GUI screenshots |
| Artifact safety | Reject `../`, symlink escape, unsupported types, over-limit transfer, and preexisting local destination without copying | error messages |
| Connection ambiguity | Disconnect SSH during job submission/refresh, reopen and inspect before retrying; never assume a missing/stale marker proves termination | status + no duplicate |

## Intentional boundaries

A disconnected *interactive* ESS console cannot be magically reattached to
an arbitrary surviving R process. Start a **new interactive session** and
reconcile uncertain computations manually. **Durable jobs** are separate
server-owned Rscript processes, not ESS sessions, and support explicit
status/exit markers. Cooperative cancellation is best effort, not process
tree or scheduler control. Slurm/PBS and automatic Quartz/X11 device capture
are deferred; PNG/PDF retrieval uses file artifacts.

The private local job registry stores host aliases, work directories,
opaque IDs and last-known status, not code/credentials. Inspect it for local
file permissions and confirm generated job folders are private.

## Exit criteria for promoting the campaign to main

1. Consolidated #102 CI fully green (not cancelled or pending).
2. A real SSH/R test host verified with both interactive and durable workflows.
3. Native macOS GUI and clean install checked on the packaged app.
4. No silent command replay, cross-host misrouting or unintended file overwrite.
5. Known limitations and failures recorded with SHA and reproduction steps.

**Do not mark the campaign release-ready solely because these instructions
and mocked tests exist.**
