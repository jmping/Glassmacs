# Glassmacs development roadmap

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

## Milestone 3 — Terminal and SSH research execution

- Implement a minimal execution selection interface for local direct, local PTY and opt-in SSH.
- Integrate persistent project terminal sessions with established Emacs facilities; preserve ESS evaluation semantics.
- Open remote project files through TRAMP and establish supported remote ESS R sessions.
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

## Milestone 6 — Native macOS refinement and packaging

- Refine Cocoa window/frame behavior, typography, dark/light appearance, shortcuts, file associations and application conventions.
- Assess an optional thin Swift/AppKit layer for lifecycle, preferences, document integration, preview coordination, packaging and updates; never replace Emacs editing or execution engines.
- Package a standalone macOS application only after isolation, dependencies, licensing and signing/distribution strategy are defined.
- Test on supported macOS and hardware combinations; compare against Aquamacs workflows and Terminal baselines.

**Exit criteria:** reproducible packaging and installation, documented compatibility, stable R/LaTeX/remote workflows, and measured GUI performance with transparent limitations.

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

Acceptance: rapidly submitting multiple R expressions leaves editing responsive; only one command at a time is dispatched to a single ESS session; users can pause or delete work not yet sent; interrupting the current evaluation does not silently delete or run the rest; edits to source buffers do not mutate queued snapshots; a reconnect never silently replays potentially executed work. See [architecture](architecture.md).

## AI agents and resilient remote terminal track

- **Milestone 2 (design):** specify an opt-in provider-neutral AI adapter contract, context/permission model and UI prototype. No AI dependency may delay reliable ESS, plain-text editing or safe output handling.
- **Milestone 3:** implement a minimal local-agent interface and a remote/API adapter with streaming, cancellation, visible context selection and read-only querying. Validate separate editor/compute/agent host identities and graceful operation when offline.
- **Milestone 4:** add diff-based proposed edits with explicit approval; optionally expose reviewed R snippets to the execution queue. Add error/log explanation for R and LaTeX with bounded context and response handling.
- **Milestone 5:** add optional Mosh terminal integration alongside SSH/TRAMP and `tmux`; verify reconnect behavior and ensure queue entries are never silently replayed.
- **Milestone 6:** refine native macOS AI interaction and credentials UX without hardwiring a vendor or exposing research data by default.

Acceptance: Glassmacs starts and edits normally without AI; the user can ask a configured local or remote agent about a selected region, see the transmitted context and cancel a streaming response; agents cannot silently run commands or change files; proposed edits require diff approval; Mosh can reconnect a terminal without claiming to replace SSH or guaranteeing exactly-once command delivery. See [architecture](architecture.md).

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
