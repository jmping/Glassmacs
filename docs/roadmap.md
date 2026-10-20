# Glassmacs development roadmap

> **Document ID:** DOC-ROADMAP  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-20  
> **Coverage:** Delivery milestones, priorities, dependencies and acceptance criteria  
> **Supersedes:** None


This roadmap translates the [architecture](architecture.md) into staged, testable delivery. It is a planning document, not a statement that planned features are implemented. Keep the README's project vision and Aquamacs-inspired macOS/R emphasis intact. Update milestone status as pull requests merge; do not claim GUI, SSH, performance or language integration was tested unless it actually was.

## Principles and cross-cutting acceptance criteria

1. **Upstream first:** GNU Emacs, ESS, AUCTeX, TRAMP, OpenSSH and maintained document packages own their respective domains. Avoid forks, duplicated parsers or a second R evaluation implementation.
2. **Local and remote are peers:** editing location, execution location, project root, working directory and artifact destination are explicit and may differ.
3. **Fast and responsive:** use persistent sessions and asynchronous work; measure overhead against comparable Terminal commands before asserting improvements.
4. **macOS without Emacs regressions:** hybrid Aquamacs/macOS Command shortcuts coexist with standard Control/Meta and ESS/AUCTeX mode-local bindings.
5. **Isolation and security:** do not alter other Emacs/Aquamacs profiles, silently run project-supplied code, weaken SSH host checking or expose development servers publicly.
6. **Honest verification:** distinguish unit tests, Linux CI, macOS GUI checks and opt-in remote integration tests. Mark skipped tests and missing dependencies.
7. **Shared execution infrastructure:** R, LaTeX, Quarto, Sweave and Shiny use common process/session/job/path/artifact facilities, with domain-specific adapters only where needed.

## Milestone 1 — Initial foundation (merged; prototype)

**Delivered:** modular Emacs Lisp entry point, isolated package storage, hybrid keybinding implementation, dark/light themes, initial ESS/R and document associations, local Shiny commands, ERT tests and documentation.

**Not established:** fully working macOS Cocoa behavior, comprehensive ESS integration, CI, remote execution, performance superiority, native app packaging, or robust LaTeX tooling.

## Milestone 2 — Stabilize the core and validate local research workflows

**Priority:** next implementation PR.

- Audit startup, package initialization, error handling and isolation; add CI and supported Emacs compatibility checks.
- Verify current ESS APIs, R major mode, `M-x R`, source evaluation and persistent inferior-R process behavior; keep standard ESS bindings.
- Fix graphical-frame initialization and hybrid keyboard conflicts; check actual macOS GUI behavior manually.
- Validate syntax highlighting, theme loading, user-configurable fonts and diagnostics.
- Verify R Markdown, Quarto, Sweave and Rd associations and basic local rendering.
- Establish local direct execution and a minimal project execution profile design without replacing ESS's process machinery.
- Verify a basic local LaTeX/AUCTeX editing and build workflow where dependencies are installed; document missing tools clearly.
- Add baseline measurements for startup, interactive R evaluation, direct Rscript and large output.

**Exit criteria:** isolated launch and automated tests pass in declared environments; an R session can be started and used where R/ESS are installed; local LaTeX build is documented and demonstrable where TeX/AUCTeX are installed; no unsupported performance or macOS claims.

## R graphics and plotting workstream (dogfood priority)

**Status: partially addressed by issue #10; no Glassmacs-managed plot viewer has been implemented.** Documentation now describes a base R/ESS graphics smoke path and optional `ggplot2` check. Standard ESS/R graphics devices may work where the local R graphics stack is configured, but the macOS workflow has not been validated as a Glassmacs integration. Plotting is a core base R research workflow, not an optional IDE-style embellishment.

**Phase 1 — Reliable immediate fallback (next integrated dogfood build):** verify that ordinary `plot(cars)`, multi-page/base graphics, and `ggplot2` output can be produced from a real ESS R session on macOS using an available native R graphics device. Document the device actually used, startup requirements, focus/window behavior, closing and reopening devices, errors and recovery. Prefer a supported native macOS graphics device when available; permit an explicitly selected X11/XQuartz device as a **fallback**, not a required dependency or the sole strategy. X11 has historically been brittle (display forwarding, server lifecycle and dependency drift); do not silently select it or claim it is reliable without testing. A basic external graphics window is acceptable for the first dogfood build; plotting must not prevent source editing or block Glassmacs startup when graphics facilities are absent.

**Phase 2 — Session-aware integrated plot viewing:** evaluate a standard R graphics-device-to-file workflow (PNG/SVG/PDF as appropriate) with asynchronous artifact detection and an Emacs image/document buffer or configurable separate native macOS frame. Support plot history, next/previous, refresh, zoom, export and clipboard where feasible. Associate plots with their originating ESS session; support multiple sessions without mixing histories. Preserve normal R graphics semantics and support base graphics and `ggplot2` without a package-specific plotting API. Avoid forcing an RStudio-style pane or creating spurious frames for non-plot special buffers.

**Phase 3 — Remote plots:** support explicitly remote ESS sessions and remote-generated graphics artifacts via existing SSH/TRAMP facilities, with bounded transfers, host/path identity, error reporting, disconnection recovery and cleanup. Do not rely on X11 forwarding as the primary remote graphics transport; do not require an SSH server for local plotting. Interactive graphics and advanced device synchronization are separate optional investigations.

**Verification:** CI should cover viewer state, session association, artifact lifecycle and fallback behavior; opt-in integration tests should use real R/ESS and available graphics devices. Clearly distinguish mocks, local macOS GUI tests and remote SSH tests. Ask the maintainer for no more than three manual dogfood checks: create a base R plot, create a ggplot2 plot if installed, and navigate/close/reopen the resulting graphics without losing editing focus. Record unsupported devices and untested environments rather than claiming cross-platform parity.

**Exit criteria:** first, ordinary plots are demonstrably usable from the maintainer's macOS ESS workflow with a documented non-X11 preferred path and explicit X11 fallback where configured; subsequently, Glassmacs can display and manage plots by R session, including remote artifacts, without compromising editing responsiveness or requiring X11.

## Milestone 3 — Terminal and SSH research execution

**Implemented foundation (partial; this does not complete the milestone):** normal TRAMP file access, an opt-in remote shell, a small read-only remote-context interface, connection inspection/cleanup, and a minimal optional Mosh terminal launcher. Unit tests do not use a real SSH server. Remote ESS and execution routing remain planned.

**Issue #12 local-session slice (partial):** buffer-local R target selection,
stale process-incarnation rejection, one-off region routing, visible modeline
state, side-effect-free Emacs context menus, and editable per-console comint
history are implemented. Common ESS evaluation entry points use the immutable
queue when a source buffer has an explicit target. This is local ESS routing,
not remote execution, host/path mapping, or full multi-project acceptance.

- Implement a minimal execution selection interface for local direct, local PTY and opt-in SSH.
- Integrate persistent project terminal sessions with established Emacs facilities; preserve ESS evaluation semantics.
- Establish supported remote ESS R sessions.
- Define session identity, project-root and working-directory selection, path mapping, environment handling and disconnect/reconnect expectations.
- Benchmark cold and warm SSH connection, remote evaluation and terminal equivalents.
- Add mocked SSH tests and opt-in integration tests using an explicitly configured test host.

**Exit criteria:** the intended R session/host is unambiguous; a remote R source file can be edited and evaluated against its correct remote session on a configured test host; failed SSH operations are recoverable; no secrets or host-key bypasses.

## Milestone 4 — Reproducible documents, LaTeX and remote artifacts

- Refine R Markdown, Quarto, Sweave/knitr, AUCTeX and LaTeX editing, compilation, log parsing and diagnostics.
- Use common asynchronous job management for local and remote `latexmk`, TeX engines, Rscript, Quarto and related tools.
- Support engine selection (`pdflatex`, `xelatex`, `lualatex`), bibliography passes (BibTeX/Biber), generated-file discovery and clean rebuilds via maintained upstream facilities.
- Preserve project-specific build flags, dependencies and working directories without constructing unsafe shell strings.
- Implement remote artifact location and retrieval/preview policies for PDFs, HTML and generated files.
- Support PDF preview on macOS and design/verify SyncTeX forward/inverse search where the source and PDF may live on different hosts; path mapping and preview tooling must be explicit.
- Make document rendering cancellable and nonblocking, with visible logs, exit status and errors.

**Exit criteria:** local LaTeX and representative Sweave/Quarto-to-PDF builds are verifiable; remote compilation and PDF preview work against a configured test host; source/PDF synchronization limitations are documented and tested where supported.

## Milestone 5 — Shiny and durable remote computation

- Remote Shiny process startup, readiness checks and explicit SSH loopback port forwarding with safe local preview, collision handling and teardown.
- Separate ordinary SSH/ESS sessions from durable server-side `tmux` or scheduler-backed jobs.
- Provide explicit submit/attach/detach/status/log/cancel/reconnect operations where supported.
- Support result and artifact retrieval without assuming a shared filesystem.
- Exercise network interruption, process cleanup and resource ownership scenarios.

**Exit criteria:** remote Shiny is not publicly exposed by default; tunnels and processes have observable lifecycle; durable jobs can survive client disconnect as documented and are not inadvertently killed by GUI shutdown.

## Aquamacs feature and settings compatibility track

The [proposed Aquamacs feature inventory](aquamacs-compatibility.md) and [menu architecture](menu-architecture.md) enumerate historical behaviors, intended replacements and tests; these proposals must be reviewed before claiming binding feature parity.

- **Milestone 2/issue #10 partial implementation:** interactive document opening now has a configurable `new-frame`/`new-tab`/`reuse-current` policy, defaults to `new-frame` on macOS, and excludes special-mode and Dired buffers. A diagnostics command and a manual R graphics path are documented. ERT covers policy selection/classification and noninteractive opens; actual Cocoa frame behavior, existing-file reuse, preference restart persistence, dirty Close/Save/Quit, Finder opens and native R plotting remain unverified or incomplete.
- **Milestone 2/next GUI validation:** verify **new graphical frame as the default for opening/creating ordinary documents on macOS**; confirm tab and reuse policies persist without creating spurious frames for ESS, Help or completion buffers. Add tests for open-existing behavior, dirty Close/Save/Quit, and settings persistence.
- **Milestones 2–3:** align dynamic File/Edit/View/Window menus, shortcuts, enablement and checked/radio state with the same command and preference APIs; audit actual Mac keymaps, modifier layouts and nonmac behavior.
- **Milestones 3–4:** implement document/tab detach and merge, session restoration, clipboard semantics, per-mode typography, recent files/Finder, text wrapping and safety settings.
- **Milestone 6:** refine native printing, spelling, formatted/PDF copy, custom toolbars, Apple menu/Services, migration wizard, help and update experience.

Exit conditions require **actual macOS GUI tests** for window/tab behavior, not merely ERT in Linux CI; documented intentional departures from Aquamacs do not count as missing features when approved. Current prototype does not satisfy these tests.

## Milestone 6 — Native macOS refinement and packaging

- Refine Cocoa window/frame behavior, typography, dark/light appearance, shortcuts, file associations and application conventions.
- **Issue #12 prototype:** an optional unsigned Swift/AppKit launcher/helper supports Finder file-open events, configurable upstream Emacs/checkout/home paths, emacsclient forwarding, and a local status-menu preferences surface. It does not replace Emacs editing, native menus, or process ownership.
- Continue assessing lifecycle, document integration, preview coordination, packaging and updates; never replace Emacs editing or execution engines.
- Package a standalone macOS application only after isolation, dependencies, licensing and signing/distribution strategy are defined.
- Test on supported macOS and hardware combinations; compare against Aquamacs workflows and Terminal baselines.

**Exit criteria:** reproducible packaging and installation, documented compatibility, stable R/LaTeX/remote workflows, and measured GUI performance with transparent limitations.

Issue #12 does **not** satisfy this milestone's exit criteria: the launcher is
unsigned, macOS CI is compile/package-only, and Finder/Cocoa/ESS GUI flows remain
unverified on a real Mac. The build and known boundaries are documented in
[the macOS launcher guide](macos-launcher.md).

## Integrated distribution and remote editing workstream (next release gate)

**Delivery decision (2026-10-19):** assemble one integrated, runnable Glassmacs distribution and exercise cross-feature scenarios before further isolated feature proliferation. This complements—not replaces—the existing macOS-first, upstream-GNU-Emacs, ESS-first, Aquamacs-compatibility, plain-text, document and remote-execution milestones. GNU Emacs remains upstream; do **not** fork the editor merely for distribution. Prefer a shared Lisp core with capability-gated macOS GUI and terminal adapters rather than separate implementations.

### Three first-class operating modes

| Mode | Emacs process | Editing UI and files | Computation |
| --- | --- | --- | --- |
| Local GUI | macOS | Native Glassmacs GUI; local buffers | Local sessions |
| GUI with remote buffers | macOS | Native Glassmacs GUI; remote files via SSH/TRAMP | Explicitly chosen local or remote session |
| Remote-running Glassmacs | Remote Linux/Unix host | Terminal Emacs over SSH, optionally Mosh/tmux or an Emacs daemon/client | Server-local sessions |

The second mode does **not** require a remote GUI Emacs, and the third does **not** require macOS, Cocoa, Swift, native menus, or an active graphical display. A locally opened remote file and a file opened by a remote Emacs process are separate buffers/processes; ordinary file-change/conflict detection applies. Live cross-process buffer synchronization is out of scope for the first release.

### Workstream A — integrated distribution, startup, dependency isolation (first PR)

- Provide a documented, reproducible installation and launch path for an upstream-GNU-Emacs-based Glassmacs distribution, with isolated configuration/package storage and no mutation of the user's other Emacs/Aquamacs profiles.
- Make GUI, terminal (`-nw`) and batch startup robust, graceful when optional R/ESS/TeX/Quarto/Mosh tools are missing, and usable offline after required dependencies have been installed. Record Emacs/ESS/version assumptions and dependency resolution; avoid unsupported claims of fully reproducible packages without pinning.
- Establish a macOS runnable release candidate and diagnostics; define app packaging/signing as a subsequent, explicit gate rather than blocking basic startup on Swift/AppKit or a GNU Emacs fork.
- Run merged-main ERT and byte compilation; test the integrated startup paths and preserve local plain-text editing without R or network access.
- Coordinate `init.el`, startup loading and scripts with the terminal and GUI-remote agents rather than letting parallel PRs overwrite one another.

### Workstream B — remote-running terminal/headless Glassmacs (parallel PR)

- Support interactive `glassmacs -nw` (proposed launcher syntax) on supported remote Linux/Unix hosts via ordinary SSH; document an optional `glassmacs --daemon` / `glassmacsclient -t` workflow, names subject to implementation. A regular terminal Emacs session is an acceptable first implementation; no new network protocol or custom terminal emulator.
- Reuse the **same core** for editing, ESS/R sessions, immutable per-session execution queues, confirmation of pending-command removal, session inspection, plain-text files and supported document modes. Terminal confirmation must be possible without GUI dialogs, with *Keep* as the safe default.
- Gate native macOS frame/tab/appearance/menus/keybindings on display/platform capabilities. Preserve ordinary terminal Control/Meta, ESS/AUCTeX and SSH/tmux key behavior. Avoid unconditional macOS dependencies or remote startup network access.
- Distinguish Emacs server lifetime, terminal/tmux lifetime and R/job lifetime: reconnecting a client does not prove job durability; never silently replay uncertain R commands or discard orphaned queue entries.
- Test `emacs -Q --batch` where applicable, true `-nw` terminal startup, Linux operation, daemon/client lifecycle, optional R/ESS on the remote host, missing-dependency/offline behavior and absence of graphical-display assumptions. CI stubs are not proof of real SSH or interactive terminal behavior.

### Workstream C — first-class remote buffers in the native macOS GUI (parallel PR)

**Binding architectural requirement:** a TRAMP-backed remote file is a **first-class Glassmacs document**, participating in ordinary editing, search, undo, navigation, window/frame/tab preferences and Close/Save/Quit semantics. Opening or creating an ordinary remote document obeys the same **separate native graphical frame by default** policy as local documents, with user-selectable tab/reuse exceptions and distinct special-buffer policies.

- Reuse upstream TRAMP/OpenSSH and existing `glassmacs-remote.el`; support normal `find-file` remote paths (e.g. `/ssh:research:/home/user/project/analysis.R`), not a parallel remote-file abstraction. A remote GUI document must not depend on a remote-running Emacs.
- Make host/remote-path identity intelligible in the document title or nonblocking status UI. Never trigger remote metadata queries just to render a menu, title, tooltip or contextual indicator. Remote discovery must remain explicit or asynchronous.
- Preserve unsaved local buffer modifications on SSH disconnect or save failure. On reconnection allow explicit save retry; respect Emacs/TRAMP external-modification and overwrite conflict checks. Never silently overwrite a concurrently modified remote file or persist a truncated/partial large-file view as the complete file.
- Treat editing location and computation location as **independent**. Opening a remote R script must not automatically start an R session or choose remote execution. Future execution UI must show the chosen host/session and pending queue, and ambiguous selection must prompt/error rather than guess.
- Validate ordinary remote edit/save, dirty Close/Quit, frame/tab policy, offline/disconnect/reconnect, conflicting changes, slow-server responsiveness, remote large-file safeguards and host/path display on an actual macOS Cocoa GUI plus an opt-in test SSH host. Keep real-network tests out of public CI.

### Workstream D — integrated ESS/R correctness and cross-feature stabilization (release gate)

- Validate PR #6's actual ESS readiness/busy transitions, prompt/continuation/error semantics, sentinel/termination observation, multi-session routing and FIFO queue against real R/ESS (not only process mocks); no completion inference solely from console text.
- Exercise long-running commands, rapid multiline submissions, immutable snapshots, failed sends, interruption, unexpected process termination and session uncertainty. **Every pending-command removal requires confirmation**, including bulk/noninteractive entry points; keep intended ordering and removal audit history and never auto-replay uncertain execution.
- Verify remote source buffers plus explicitly chosen local-vs-remote execution, remote Emacs with server-local ESS/R, SSH disconnect and reconnect, local GUI buffers, and plain-text/document workflows across all modes. Remote ESS integration remains a separate implementation prerequisite, **not** a feature delivered by PRs #6–#8.
- Run full ERT/byte compilation on the combined `main` plus macOS Cocoa, Linux terminal, real R/ESS, SSH/TRAMP and (where configured) Mosh/tmux/daemon smoke and failure-injection tests. Capture versions, installed tools, skipped tests, results and regressions. Treat each merged PR as integrated but **not yet end-to-end verified**.

### Delivery sequencing, ownership and exit criteria

Develop A (distribution/startup), B (remote terminal) and C (GUI remote documents) in separate, rebased PRs with disjoint modules and coordinated entry-point edits; D is the consolidated real-environment validation and stabilization gate. The earlier proposed PR numbers 9–12 are **workstream placeholders**, not reserved GitHub PR numbers. Do not claim features implemented simply because they appear here.

**Exit criteria:** a researcher can launch Mac GUI Glassmacs, edit/save local and remote documents in the intended frame policy, run terminal Glassmacs on a remote host with ordinary upstream Emacs facilities, use and inspect real ESS/R sessions and conservative queues where dependencies are installed, and recover safely from representative disconnects and execution failures. Evidence must distinguish unit/CI mocks from actual macOS GUI, terminal Linux, R/ESS and SSH tests. Native standalone packaging, remote ESS dispatch, remote durable jobs, shared live buffer synchronization and AI integrations may remain later milestones if explicitly documented.

## Plain text and large-file acceptance track

This is a **core product requirement**, not an optional R feature. Glassmacs must remain a useful general-purpose plain text editor even when no statistical packages are installed.

- **Milestone 2:** verify normal plain-text editing and isolation from R dependencies; add conservative large-file detection and safe open/read-only behavior where feasible; test long-line safeguards and prohibit accidental writes from partial views.
- **Milestone 3:** implement or integrate a validated chunked large-file inspection path, including remote-file handling and clear partial-view indicators; test search/navigation and failure/cancellation behavior.
- **Milestone 4 and later:** improve large-file editing only where correctness and save integrity can be guaranteed; benchmark open time, peak memory and interactive responsiveness on representative text and log files.

Acceptance tests must include ordinary `.txt` and extensionless files, multi-megabyte documents, long single-line files, large logs, non-UTF-8/invalid encoding cases, read-only and permission-restricted files, and remote large files when a test host is available. Do not require all large files to load into a normal Emacs buffer. Never write back a partial view as a complete file. See [architecture](architecture.md) for safety constraints.

## R output-flood protection track

Output-flood handling is a high-priority reliability requirement, separate from large-file inspection:

- **Milestone 2:** document and test how current ESS/comint handles a huge R print; define bounded output budgets and distinct stop-display / interrupt / terminate controls. Implement a conservative, tested local protection path if compatible with ESS.
- **Milestone 3:** integrate output suppression and recovery with persistent terminal and SSH sessions, ensuring channel draining, bounded queues and accurate prompt/session state.
- **Milestone 4:** extend the same protections to rendering logs, batch jobs and remote job output, with bounded tails and explicit truncation indicators.

Acceptance: printing a large object does not cause unbounded Emacs buffer growth or an unresponsive UI; the user can suppress further display without unintentionally killing R; interrupts remain independently available; output truncation is visible; subsequent R evaluation works after the flood ends. Confirm process behavior and transport backpressure under test rather than assuming suppressed display means printing has stopped.

## Nonblocking R execution queue track

The execution queue is a major usability requirement and should be introduced alongside ESS stabilization rather than deferred until a Swift UI exists.

- **Milestone 2:** define per-session job identity and state machine; prototype safe nonblocking FIFO submission using supported ESS completion/readiness signals; expose inspect, pause, cancel pending, interrupt current and resume actions. Preserve conventional ESS commands and add tests for rapid submissions, multiline code and output floods.
- **Milestone 3:** add editable/reorderable pending snapshots and a dedicated queue buffer; connect queue selection to local terminal and remote ESS sessions. Explicitly handle interactive prompts, SSH disconnects and uncertain execution status without automatic retries.
- **Milestone 4:** refine diagnostics, bounded history, cancellation and project/session observability; validate performance and failure recovery with real R sessions.

**Status (2026-10-20):** a minimal subset (session registry, per-session FIFO, inspect, pause/resume, confirmed removal with history, interrupt, orphaning on termination) is implemented; see [R workflows](r-workflows.md). Pending-command removal always requires explicit confirmation. Editing/reordering, a queue buffer, output floods and remote sessions remain planned.

Acceptance: rapidly submitting multiple R expressions leaves editing responsive; only one command at a time is dispatched to a single ESS session; users can pause or delete work not yet sent; interrupting the current evaluation does not silently delete or run the rest; edits to source buffers do not mutate queued snapshots; a reconnect never silently replays potentially executed work. See [architecture](architecture.md).

## AI agents and resilient remote terminal track

- **Milestone 2 (design):** specify an opt-in provider-neutral AI adapter contract, context/permission model and UI prototype. No AI dependency may delay reliable ESS, plain-text editing or safe output handling.
- **Milestone 3:** implement a minimal local-agent interface and a remote/API adapter with streaming, cancellation, visible context selection and read-only querying. Validate separate editor/compute/agent host identities and graceful operation when offline.
- **Milestone 4:** add diff-based proposed edits with explicit approval; optionally expose reviewed R snippets to the execution queue. Add error/log explanation for R and LaTeX with bounded context and response handling.
- **Milestone 5:** extend the minimal Mosh launcher alongside SSH/TRAMP and external `tmux`; verify reconnect behavior and ensure queue entries are never silently replayed.
- **Milestone 6:** refine native macOS AI interaction and credentials UX without hardwiring a vendor or exposing research data by default.

Acceptance: Glassmacs starts and edits normally without AI; the user can ask a configured local or remote agent about a selected region, see the transmitted context and cancel a streaming response; agents cannot silently run commands or change files; proposed edits require diff approval; Mosh can reconnect a terminal without claiming to replace SSH or guaranteeing exactly-once command delivery. See [architecture](architecture.md).

## Research application profile track

- **Milestone 2:** define the profile contract for standalone/embedded syntax, command discovery, execution host, logs, artifacts and optional capabilities. Confirm existing ESS BUGS/JAGS support and candidate Emacs language modes; avoid duplicating maintained integrations.
- **Milestone 3:** implement a minimal end-to-end profile using shared local/SSH execution and queue infrastructure, with explicit executable detection and safe invocation.
- **Milestone 4:** add representative `lavaan` embedded-model support, JAGS model files and Stan/`cmdstanr` workflows where dependencies exist. Verify diagnostics and output artifact handling; separate available editing support from installed runtime support.
- **Milestone 5:** add durable sampling/optimization jobs and remote chain monitoring using common job management; pilot an external executable workflow that is not R-native.
- **Milestone 6:** refine macOS UX and document how contributors add profiles without forking Glassmacs or installing proprietary applications.

Acceptance: a researcher can open a supported external model file without executing it, edit with suitable mode support, explicitly run an installed tool locally or on a configured host, inspect bounded logs and retrieve outputs; missing runtimes do not break editing; user configuration cannot silently launch untrusted commands. See [architecture](architecture.md).


## Multi-project R context, right-click actions and local-test/remote-deploy track

This track supports **ten or more concurrently open research projects**, each potentially with several independent R terminals/processes. Project membership is optional context, not a global active-session switch. See [architecture](architecture.md) for authoritative process identity, per-buffer routing and filesystem separation. All items below are **planned unless explicitly implemented elsewhere**.

- **Near-term, after first Mac/ESS dogfood:** make buffer→R-session association explicit, visible and user-changeable; add an interactive session picker, an optional one-off alternate-target execution command, and a session switcher displaying project/host/process state. Resolve ambiguous automatic associations by prompting; do not silently retarget on process death/restart. Integrate with the existing session FIFO without moving already queued commands.
- **Next GUI usability milestone:** introduce context-aware native right-click menus for source buffers, R terminals, object inspectors and plots using the same Emacs commands as keyboard/menu-bar actions. Prioritize “Send Code To…”, “Run In… Once”, associated terminal, objects, plots and working-directory inspection. Menu refresh must not connect to SSH or evaluate R.
- **R environment inspection milestone:** build an object explorer per live R process (not per project or globally), with bounded, minimally intrusive metadata retrieval, explicit refresh, object inspection and data preview. Handle expensive objects, active bindings and remote latency safely. Explorer views stay bound to their original process identity and show disconnected/historical status after exit.
- **Local-test/remote-deploy milestone:** enable deliberate local testing of code intended for remote SSH deployment, with visible source host, test R target, deployment host/path, project root, runtime environment and optional explicit path mappings. Distinguish validation in local R from deployment compatibility; no implicit remote execution or `setwd()` when switching buffers/targets.
- **Longer-term SSH file operations:** design and implement a graphical local/remote browser, transfer queue and progress/retry UI, upload/download/synchronize with preview/diff and conflict protection, plus explicit remote permission adjustment (mode bits; ownership only where authorized/supported). Reuse TRAMP/SSH; require confirmation for overwrites, recursive operations and permission changes, guard symlinks/partial writes and preserve terminal-mode functionality. Do not conflate copying a file with running it.

**Acceptance:** ten simulated projects and multiple overlapping R sessions remain isolated; changing a buffer target affects only subsequent commands; queued commands retain their original session and code snapshot; project/document/default-directory/shell-cwd/R-`getwd()` are independently represented; a file on SSH host A can deliberately target R on host B without assuming shared paths; context menus are discoverable and side-effect-free until an action is chosen; transfers and permission changes expose source, destination and confirmation. Real macOS/ESS/SSH coverage must be distinguished from mocked tests. Do not let this track block the first usable Mac launch and base R plot.

## Product-fit gate for every milestone

The target audience is **base R / ESS / Emacs power users who routinely cross language and machine boundaries**, not users seeking an RStudio-style IDE. Each milestone PR should explain how it preserves buffer-first editing, direct command-line access, Emacs/ESS keybindings, optional tooling and cross-language workflows. Features must not make R, a project format, a graphical pane, an AI service or a network connection prerequisites for plain-text editing. Use this positioning to prioritize responsiveness, process control, remote execution, file safety and composable integrations over IDE mimicry.

## Verification matrix

| Capability | Unit / CI | Local macOS integration | Opt-in remote integration |
| --- | --- | --- | --- |
| Isolated startup / packages | Required | Required | Not applicable |
| Hybrid keybindings / themes | Emacs tests | Cocoa GUI required | Not applicable |
| ESS R editing / evaluation | Tests with R/ESS | Required | Required for remote ESS |
| Terminal / execution routing | Mock/process tests | Required | Required for SSH backend |
| Quarto / R Markdown / Sweave | Smoke tests when tools installed | Required | Required for remote rendering |
| LaTeX / AUCTeX / PDF / SyncTeX | TeX toolchain smoke tests | PDF preview and SyncTeX | Remote artifact/path mapping |
| Shiny | Local process tests | Local preview | SSH tunnel + remote preview |
| Detached jobs | Lifecycle mocks | Client behavior | Real disconnect/reconnect |
| Performance | Repeatable harness | Terminal comparisons | Same-host/network comparisons |

Record dependencies, skips, tested versions, failures and benchmark conditions in each implementation PR.

## Documentation and decision records

- [Architecture](architecture.md): invariants, module boundaries, security, process/session contracts.
- [R workflows](r-workflows.md): user-facing current commands and future remote research workflows.
- [Development](development.md): testing, performance measurement and CI guidance.
- [Keyboard profile](keybindings.md): current and intended macOS/Emacs key behavior.
- Future ADRs: execution profile schema/trust, ESS session selection, remote path mapping, SSH command safety, job cancellation, artifact preview and SyncTeX strategy.

## Scope management

Each milestone should land as small reviewable PRs with working code and tests. Do not postpone the initial R/ESS usability work for Swift packaging. Equally, do not require a complete remote framework to support basic local LaTeX: AUCTeX and existing TeX tooling should work through the same local execution facilities first. Remote PDF preview and SyncTeX need explicit integration, but not a new backend architecture.
