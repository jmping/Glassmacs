# Glassmacs architecture

## Product contract

Glassmacs is an R-first, modern macOS GNU Emacs distribution inspired by Aquamacs. It must preserve upstream Emacs extensibility, familiar Aquamacs/macOS hybrid shortcuts, and traditional Emacs/ESS controls while delivering attractive source highlighting, interactive research workflows, and a responsive interface. It is not a fork of GNU Emacs or a port of obsolete Aquamacs internals.

**Execution placement is independent from editing placement.** A source buffer may live locally or on a remote server, and computation may occur locally, in a persistent terminal session, or remotely over SSH. Avoid assuming that the Mac running the GUI runs R, Quarto, Shiny, or compute-intensive jobs.

## Existing implementation (Milestone 1)

- `init.el`: isolated entry point into the `lisp/` configuration.
- `glassmacs-core.el`: package initialization under `GLASSMACS_HOME`, basic direct process invocation and R string quoting.
- `glassmacs-keys.el`: macOS graphical Command-key shortcuts with Control/Meta preserved.
- `glassmacs-r.el`: ESS/R modes and evaluation helpers.
- `glassmacs-documents.el`: document-mode selection and local rendering/knitting.
- `glassmacs-shiny.el`: local Shiny subprocess management.
- `glassmacs-appearance.el`: dark/light themes.

These are an experimental foundation. Remote backends, unified execution profiles, remote Shiny forwarding, durable jobs and macOS GUI validation **are design requirements, not implemented features**. Dependencies currently come from GNU ELPA, NonGNU ELPA and MELPA, without lockfiles. No changes to existing user Emacs or Aquamacs configuration are permitted.

## Execution architecture: components and responsibilities

```text
Glassmacs GUI / project / buffer / ESS / document commands
                        |
             Execution selection
            (project + buffer context)
                        |
       +----------------+------------------+
       |                |                  |
 Local direct       Terminal/PTy       Remote SSH
 processes          session            + TRAMP
       |                |                  |
 Rscript/quarto      shell/R       remote R, scripts,
 local Shiny        interactive     Quarto, Shiny, jobs
       +----------------+------------------+
                        |
          buffers, logs, status, errors,
          previews, artifacts and diagnostics
```

Introduce a small `glassmacs-execution.el` interface when implementation begins. Keep backend choice, project profiles, process lifecycle, and working-directory policy separate from GUI, ESS and document-format modules. Do not build a universal command runner: **ESS must keep its own supported inferior-R process communication and evaluation APIs.** Routing should select/configure the correct ESS session, not inject arbitrary text into a shell.

### Backend contract

| Backend | Semantics | Guidance |
| --- | --- | --- |
| Local direct | Direct argument-vector subprocesses and asynchronous processes | Avoid shell startup where unnecessary; keep interactive R in a persistent ESS session |
| Local terminal | PTY-backed persistent shell or R session | Reuse Emacs `comint`, `term` or justified upstream alternatives; distinguish this from ESS |
| Remote SSH | SSH transport, TRAMP file access, remote ESS where supported | Reuse OpenSSH, `~/.ssh/config`, authentication agents and host-key verification; no custom SSH protocol |

Each job/session should expose an explicit identity and state: backend, host (if any), project root, remote/local working directory, executable, environment policy, process or session ID, lifecycle state, output/log buffers and whether it survives disconnection. Distinguish interactive persistent sessions from one-off batch jobs and durable detached jobs. Do not imply that all modes provide the same capabilities.

### Project configuration and routing policy

Provide an opt-in, user-controlled project execution profile that specifies backend (`local`, `terminal`, `ssh`), SSH host alias, working directory, R program, and optional session identifier. A hypothetical Lisp value is:

```elisp
(setq glassmacs-project-execution
      '(:backend ssh
        :host "research-server"
        :directory "/home/user/projects/analysis"
        :program "R"
        :session "analysis"))
```

**Illustrative only — not yet a supported API.** Final design should clarify per-project versus per-buffer overrides, default to safe local behavior, validate configuration, and avoid ambiguity when local source files are executed remotely. Project metadata must not silently gain authority to execute commands. Opening a project must not automatically run remote code or connect to untrusted hosts.

Project semantics: treat source location, execution location, project root, process working directory, and results/artifact location as distinct. Define explicit mappings or transfer mechanisms for local-source/remote-execution scenarios; do not assume matching absolute paths or a shared filesystem. Resolve the R session by project + host + relevant working-directory context, with visible user override, so evaluation never accidentally reaches an unrelated session.

### ESS and R

Maintain ESS as the owner of editing, syntax highlighting, completion, help and source-to-inferior-R evaluation. Use current supported ESS APIs, preserve `M-x R`, `C-c C-c`, `C-c C-r`, and other mode-local bindings. Keep sessions persistent and make target session/host visible. Support selection, safe restart and teardown, remote environment discovery, and stable source/console navigation. Use `executable-find` locally and configurable R program discovery remotely; do not hard-code CRAN/Homebrew architectures. Document actual capabilities and test against compatible ESS versions.

### Document rendering and artifacts

R Markdown, Quarto, Sweave/knitr, LaTeX/AUCTeX, and Rd editing must respect backend choice. Rendering is potentially slow and must not freeze the GUI. Retain direct argv invocation locally, preserve structured argument boundaries, and use carefully specified, safely quoted remote invocation instead of interpolating filenames into shell fragments. Track job state, errors, output, generated artifacts, and which filesystem owns them. A preview may require an explicit copy, remote file access, or SSH tunnel. Never assume a local browser can open a server-side path.

#
## LaTeX and PDF integration (shared execution architecture)

LaTeX is a first-class research workflow, **not** a fourth execution backend. AUCTeX and established Emacs/TeX facilities should own editing, compilation commands, error navigation and source/PDF synchronization. The execution layer should supply the same local-direct, terminal/PTY and SSH job/session capabilities used for R, Quarto and Sweave. Avoid a separate LaTeX-specific process framework.

- Support project-selected TeX toolchains and engines such as `latexmk`, `pdflatex`, `xelatex`, `lualatex`, BibTeX and Biber through established AUCTeX/TeX integrations, with asynchronous execution and clear log/error handling.
- Keep source location, TeX working directory, auxiliary/output directories, generated PDF location and viewer location distinct; resolve dependencies and relative `\\input`/bibliography paths in the selected project context.
- Reuse the same remote path-mapping, artifact transfer/access, cancellation and process-status mechanisms as document rendering generally. Never assume a PDF built remotely exists at a corresponding local path.
- Provide a local macOS PDF preview workflow and design SyncTeX forward/inverse search with explicit source/PDF path translation for remote compilation. This is a specific integration requirement, not something generic SSH execution provides automatically.
- Preserve AUCTeX and ESS mode-specific keymaps, especially in Sweave and embedded-document buffers. Treat R Markdown/Quarto/Sweave-to-PDF as multi-stage workflows that may invoke R, Pandoc, LaTeX and bibliography tools on the same selected execution host.
- Test a basic local AUCTeX/LaTeX build first; remote builds, artifact preview and remote SyncTeX require separate opt-in integration tests.

These are target requirements; the current prototype does not yet verify an end-to-end LaTeX workflow.

## Shiny

Support existing loopback-only local Shiny operation. For remote Shiny, plan SSH local port forwarding from an explicit selected server-side loopback port to a controlled local port, with collision handling, readiness/error reporting, cleanup, and an explicit local preview URL. Do not bind a remote development app to a public interface by default. Clearly identify local vs remote processes and tunnels; stopping a preview must not silently kill an unrelated remote process.

### Durable remote work

Interactive ESS/SSH processes generally do **not** imply survival of disconnection. Add an optional design for server-side `tmux` or a scheduler-backed batch job, with explicit attach, detach, reconnect, status, logs, cancellation and artifact retrieval semantics. Model ownership, orphaned jobs and reconnect failure. Job durability is a separate capability; do not claim it until verified. Do not kill durable server jobs merely because the editor closes.

## Plain text editing and large-file safety

Glassmacs must remain a dependable **general-purpose plain text editor**, independently of its R/research tooling. Opening `.txt`, `.log`, `.csv`, configuration files, and files without an extension must not require ESS, R, Quarto or a project profile. Preserve conventional GNU Emacs text editing, search, undo, encoding/line-ending handling and save semantics, with an approachable macOS interface.

**Large-file safety is a separate requirement from long-line handling.** Emacs `so-long-mode` helps avoid expensive operations on very long lines; it does not provide bounded-memory reading of arbitrarily large files. `find-file-literally` can bypass some decoding and file-processing behavior, but it is not a streaming viewer. Consider a maintained large-file facility such as `vlf` for chunked inspection when appropriate, while verifying its compatibility and write semantics before enabling editing.

Design requirements:

- Detect potentially expensive opens before normal loading, using configurable file-size thresholds, long-line indicators where practical, and remote-file context. Avoid reading the entire file just to decide whether to read it.
- Offer clear choices: open normally, open in a conservative read-only inspection mode, or use a chunked/streaming large-file viewer if available. Do not silently truncate data or represent a partial view as the entire file.
- Prefer read-only by default in large-file inspection; require an explicit, well-understood transition before editing and saving. Never overwrite a complete file with a displayed subset.
- Disable or defer expensive syntax highlighting, tree-sitter parsing, LSP/diagnostics, auto-formatting, line numbers, eager hooks, large undo histories and automatic project indexing when they threaten responsiveness. Apply safeguards only where needed; normal files retain full editing features.
- Preserve byte integrity and communicate encoding, newline conversion and binary-file limitations. Avoid silent conversions on save. Provide reliable search and navigation for large logs, with documented limitations for partial-buffer views.
- Make large remote files safe to inspect without unexpectedly transferring the entire file; specify remote chunking/transport behavior and failures.
- Keep GUI responsiveness and cancellation observable. Test sparse/large files, single enormous lines, multi-gigabyte logs when resources permit, invalid encodings, remote files, permission errors and save protection.
- Benchmark open time, peak memory, scrolling/search latency and cancellation against stock GNU Emacs and Terminal utilities on matched files. Define size thresholds through measurements, not unsupported assumptions.

The initial implementation may provide conservative detection, user choice and read-only inspection before implementing fully featured chunked editing. Document supported file sizes and limitations rather than promising arbitrary-size editing.

## Nonblocking, user-editable R execution queue

Repeated source evaluation must never make the Glassmacs GUI wait synchronously for the entire backlog. Implement a **per-session execution queue** between user commands and supported ESS evaluation submission, preserving ESS's ownership of the inferior-R process and prompt handling. The queue is an orchestration layer, not a replacement for ESS/comint.

### Queue model and semantics

- Each submitted unit has a stable ID, target session/host, project, source file/buffer and source range, captured code snapshot, submission timestamp, status and optional dependencies. Snapshot code when enqueued so later source edits cannot silently alter a pending command; allow explicit editing of the queued snapshot before dispatch.
- States should distinguish `pending`, `dispatching`, `running`, `completed`, `failed`, `cancelled` and `interrupted`, with a separate `paused` flag on the queue. Only a single active evaluation may own a given sequential ESS session; unrelated sessions may run concurrently.
- Preserve FIFO by default. Allow inspection, editing, reordering, deleting selected pending entries, clearing future work, pausing after the current evaluation, and resuming. Show a preview of the exact code and target R session before dispatch. No action on pending entries should alter already-dispatched code.
- **Interrupt current** sends a supported ESS/process interrupt and leaves future work paused pending explicit user action. **Cancel pending** only removes commands not dispatched. **Terminate session** is a distinct explicit action. Never imply that interrupting R rolls back side effects already performed.
- A source region may be queued as one atomic unit. Splitting it into expressions is optional and must use a correct R parser/ESS-supported expression boundary mechanism; never split arbitrary R code by physical lines. Respect multiline functions, pipes, braces, strings and comments.
- Dispatch the next entry only when supported ESS signals establish that the previous evaluation is finished and the target process is ready. Do not infer completion from a timeout or arbitrary output text alone. Define behavior for prompts, errors, debugger/browser prompts, `readline()`, interactive input, process restarts, lost SSH connections and changed working directories.
- Integrate with bounded console output: output suppression must not be mistaken for evaluation completion; queue progress and status must remain accurate when printing is flooded or discarded. Keep queue metadata and retained logs bounded.
- Maintain a nonblocking queue UI (for example, an Emacs tabulated list or special-mode buffer) with explicit actions and keyboard shortcuts that do not shadow ESS/Aquamacs bindings. User editing of queued code must be safe and reviewable, not silent mutation of the source file.
- Treat remote execution similarly, but never replay unacknowledged or partially executed commands automatically after SSH disconnect: they may have already produced side effects. Mark uncertain entries and require explicit reconciliation or resubmission. Pending queues must be bound to the correct session/host.
- By default, the queue may be ephemeral; persistence, crash recovery and automatic retries require an explicit design for sensitive code, filesystem writes, duplicate execution and side effects. Do not auto-retry non-idempotent work.

### Verification

Test rapid repeated submissions, multiline regions, queued edits/reordering/deletion, pause/resume, ESS readiness and error prompts, R interrupts, process death, output flooding, remote disconnection, and multiple concurrent sessions. Verify that the editor remains responsive and no command is silently duplicated, lost or sent to the wrong R session. Measure dispatch overhead and latency against direct ESS and Terminal baselines. Mark any guarantees that cannot be established in the test environment as unverified.

**Status:** This queue is a planned capability; no queue UI or dispatcher exists in the current prototype.

## Bounded R console output and output-flood recovery

Printing an unexpectedly large R object (for example, an enormous data frame or database query result) must not freeze Glassmacs, exhaust editor memory or require terminating an otherwise healthy R session. This is **distinct from large-file loading** and applies to ESS inferior-R consoles, local subprocesses, terminal/PTY sessions and remote SSH streams.

Separate three user actions with clearly different semantics:

1. **Stop displaying output:** stop appending excessive output to the visible buffer while keeping the console usable. This must not be presented as an R interrupt or as a guarantee that R has stopped generating output.
2. **Interrupt computation:** use the supported ESS/process interrupt path to request that the current R operation stop. The R session should remain alive where possible.
3. **Terminate session:** explicitly stop the R process, with confirmation where appropriate; reserve for irrecoverable sessions.

Design an output budget for interactive consoles and command output: configurable byte/line thresholds, per-burst rate detection, bounded retained history, and a clear notification such as *Output limit reached — additional output suppressed*. Offer a user action to resume display, inspect a bounded tail, or redirect output to a user-selected file when supported. Never silently discard output while implying that it is complete. Do not confuse console-output truncation with truncating a file being edited.

**Transport/backpressure constraint:** suppressing buffer insertion does not automatically suppress R's printing. The consumer must continue draining or explicitly interrupt/stop the producer where appropriate; otherwise full pipes/PTYs or SSH channel windows can block R. Design bounded queues and nonblocking draining with careful flow control. For a local subprocess, it may be possible to drain and discard after a threshold; for ESS/comint, integrate with supported process filters and their prompt/session bookkeeping rather than replacing them with a filter that breaks ESS state. Remote SSH and PTY behavior requires independent validation. Avoid unbounded in-memory buffering or unbounded temporary logging as a supposed fix.

Preserve command boundaries, prompts, ESS markers, error messages and session state when output is suppressed; an output flood must not leave evaluation permanently marked busy or route subsequent commands to the wrong session. Expose clear status for *output suppressed*, *interrupt requested*, *process still running*, and *session terminated*. Automatic limits should be conservative and configurable, with an explicit opt-in path for genuinely large output.

Test a large R data-frame print, repeated fast output, a never-ending print loop, multiline errors, prompts after suppression, manual interruption, remote SSH flooding, and recovery for subsequent evaluations. Benchmarks must include peak editor memory, redisplay responsiveness, CPU use, output throughput and R-process liveness. No performance or interruption guarantees should be claimed without empirical tests.

## Performance requirements

The old Aquamacs experience was noticeably slower than equivalent Terminal workflows. Glassmacs must minimize overhead and **measure** it.

- Avoid blocking the UI on long subprocesses, SSH operations, rendering or large volumes of stdout/stderr.
- Avoid repeatedly launching shells or R for routine interactive evaluation. Prefer persistent ESS and PTY sessions.
- Avoid expensive buffer redisplay/fontification on large R output where possible without hiding information.
- Cache remote connection/session state only where correct; allow deterministic reset.
- Provide benchmarks separating GUI startup, package loading, R initialization, first command latency, repeated ESS evaluation round trips, direct `Rscript`, output throughput, SSH handshake, steady-state SSH evaluation, remote transfer and actual R compute time.
- Compare representative commands against Terminal on the same machine/server with equal R version, packages, environment, input and warm/cold process conditions. Report median and spread, platform/build details, skipped cases and regression thresholds; do not assert speedups without measurements.

Latency, throughput, compute duration, remote network delay and perceived GUI responsiveness are different metrics. Do not substitute one for another.

## Security and trust boundaries

- Trust system OpenSSH, SSH agents, `~/.ssh/config` and host-key checking; do not invent an SSH authenticator, disable verification or store keys/passwords.
- Never auto-execute repository-provided project settings, shell code or remote commands as a side effect of opening a directory.
- Prefer argv APIs; validate executable and arguments, use correct escaping only where remote shells are unavoidable, and test whitespace, Unicode and metacharacters.
- Use least privilege and user-selected host aliases; do not silently forward agents or ports.
- Default Shiny and previews to loopback, with explicit, scoped forwarding.
- Avoid writing tokens, keys, private environment variables or sensitive server output into persistent logs.

## macOS and user-interface boundary

Upstream GNU Emacs owns editing, buffers, modes and ESS processes. The optional future Swift/AppKit layer may provide lifecycle, preferences, Cocoa window/document integration, application packaging and preview coordination through supported Emacs-client/process interfaces; it must **not** reimplement execution or become a compute proxy. Modern Cocoa appearance and Aquamacs-like keyboard behavior are design requirements, not verified properties. Command-key shortcuts must not shadow Emacs Control/Meta or ESS mode maps. Preserve a conventional Emacs profile and test frames created after startup.

## Testability and acceptance gates

Run isolated batch tests with `./scripts/test`; add CI for Emacs startup, dependency handling, syntax/byte compilation, routing precedence, session identity, file/working-directory mapping, processes, argument safety, and cancellation. Mock SSH configuration and remote invocations; never require credentials or a private host in public CI. Provide opt-in remote integration tests with an explicit controlled test host, plus macOS graphical checks for Cocoa and actual keyboard delivery. Test dependency-absent and installed scenarios, as well as large-output and failed-network cases.

For any claimed remote-R workflow, demonstrate: open a TRAMP project, start supported remote ESS R, evaluate into the intended session, retrieve output/errors, and disconnect/reconnect with documented expected behavior. For any claimed remote Shiny workflow, verify tunnel teardown and non-public binding. Maintain an implemented/tested/planned matrix; CI green does not prove a GUI or remote workload was tested.

See the [development roadmap](roadmap.md) for milestones, acceptance criteria and verification coverage.

## Delivery order and decisions to record

1. **Milestone 2:** stabilize local R/ESS, macOS keybindings, dependency isolation, CI; define the minimal execution profile contract and validate architectural boundaries.
2. **Milestone 3:** persistent terminal integration and opt-in SSH/TRAMP + remote ESS workflow, path mapping, performance instrumentation.
3. **Milestone 4:** remote rendering, artifact handling, Shiny SSH forwarding and durable job lifecycle as separately testable capabilities.
4. **Later:** refined native macOS appearance, Swift/AppKit optional wrapper and standalone packaging.

Before implementation, record design decisions for session ownership, profile trust, local-to-remote file mapping, remote command construction, process cancellation, credential handling, performance test methodology and remote preview lifecycle. Prefer small ADRs under `docs/adr/` for decisions that constrain multiple modules.

## AI agent integration layer (local and remote)

Glassmacs should provide a **provider-neutral, opt-in interface** for consulting local and remote AI agents while editing text, R, LaTeX and research projects. The AI layer is a client and orchestration boundary, not a replacement for Emacs, ESS, document tooling or the execution queue.

- **Entry points:** ask about selection/buffer/project, explain an R/ESS error or LaTeX build log, review code, suggest tests/refactoring, draft documentation, and maintain multi-turn conversations. The UI should remain responsive and support streamed responses, cancellation and a searchable conversation buffer.
- **Adapters:** distinguish local model servers, local CLI agents, cloud APIs and agents launched on SSH-accessible research hosts. Define capability negotiation (chat, tools, file edits, streaming, cancellation, authentication) rather than assuming every provider exposes the same functions. Prefer maintained Emacs integrations/protocols where feasible; avoid hardwiring one vendor.
- **Location model:** record separately the Mac editor, the R/LaTeX execution host, the agent host and the location of referenced files. Remote agent transport can use SSH or authenticated network APIs; Mosh is a terminal experience, not a generic API or TRAMP substitute.
- **Context controls:** show exactly which buffers, selected regions, diagnostics, logs and project files will be transmitted. Default to minimum necessary context. No automatic upload of full projects, large data, credentials, `.Renviron`, SSH keys or sensitive research material. Local and remote agents must be clearly distinguished before a request is sent.
- **Permission boundary:** read-only querying by default. Any proposed file edit should be displayed as a diff and explicitly approved before applying. Shell commands, R evaluations, package installs, network requests and remote file writes require separate user authorization with a clear target host and working directory. Do not execute untrusted tool-call output automatically.
- **Session safety:** agent chat history, permissions and queued R work are separate state machines. Agent-generated R code is not implicitly dispatched to ESS; use an explicit review-and-enqueue action. Cancellation should stop streaming/request processing where supported without terminating unrelated R/SSH sessions.
- **Robustness:** bound streamed response size and retained conversation history; show partial results and errors; manage API secrets via platform/Emacs auth facilities rather than project files or logs; avoid automatic retries of potentially side-effecting agent actions. Provide graceful operation with no AI provider configured.
- **Verification:** adapter mocks, opt-in provider integration, diff approval and rejection, permission prompts, remote path translation, streaming flood limits, offline failures, context redaction and no-provider startup. Do not assert privacy guarantees beyond the configured provider's actual behavior.

**Status:** proposed architectural requirement, not an implemented AI integration.

## Mosh and durable remote terminals

Support **Mosh (Mobile Shell)** as an optional transport for interactive remote terminal sessions on unstable networks. It should coexist with OpenSSH/TRAMP and persistent server-side `tmux` sessions rather than replace them.

- Mosh offers roaming/reconnection and responsive terminal interaction; it is not a general SSH file transfer, port forwarding, TRAMP or batch command backend.
- Continue using OpenSSH for authenticated file access, TRAMP, SSH tunnels, noninteractive execution and remote artifact transfer. Mosh typically relies on SSH for initial login and then uses its own transport; document deployment/network prerequisites.
- Pair Mosh with `tmux` where durable remote process/session persistence is needed. Define attach/detach/reconnect UX, terminal ownership and cleanup.
- Do not equate terminal screen reconciliation with exactly-once delivery of R queue entries. After disconnection, unacknowledged evaluation requests remain uncertain until explicitly reconciled; never replay them automatically.
- Test Wi-Fi interruptions, host changes, reconnect, terminal state, output floods and session recovery on opt-in remote infrastructure.

**Status:** optional future transport; not currently implemented.

## Research application profiles: external syntax and tools

Glassmacs must accommodate established statistical and research applications that use **embedded model syntax, standalone source files, imported scripts, command-line executables or remote jobs**. Users should not have to migrate working research pipelines into a new language or graphical interface to benefit from the editor.

A research application profile is a thin, optional adapter with declarative metadata (file extensions and embedded-language contexts, syntax/major-mode association, executable and version detection, invocation templates, working directory, expected outputs, diagnostic parsing and preview handlers) plus narrowly scoped Emacs Lisp integration where needed. Profiles reuse the common execution router, per-session queues, SSH/TRAMP, optional Mosh terminal sessions, durable jobs, output flood controls, artifact mapping and provenance ledger. They do **not** introduce new process engines.

Representative profiles:

- **lavaan:** R-embedded model syntax and standalone model text where used; highlighting/navigation of parameter specifications, model-fit diagnostics, parameter tables, standardized solutions and optional diagrams. Preserve normal R/ESS evaluation.
- **JAGS/BUGS:** model-file modes, `rjags` and established ESS BUGS/JAGS facilities, chain configuration, progress, diagnostics and remote sampling.
- **Stan:** `.stan` language support, `cmdstanr` and existing `rstan` workflows, compiler diagnostics, model caching, multiple chains and remote results.
- **Other external tools:** configurable command-line statistical applications (for example Stata, SAS, Mplus, Julia or Python workflows) where licensing and installed tools permit; use existing language modes and supported execution adapters rather than claiming universal integration.

Profiles must distinguish **editing support** from **execution support** and **result inspection**; each can be available independently. Detect missing applications and unsupported versions without breaking text editing. Imported external syntax must not be evaluated merely by opening a file. Profile-defined commands and project-local configuration are untrusted until reviewed; require explicit consent before execution and avoid unsafe shell interpolation. Preserve remote host and working-directory identity, job cancellation, path mapping and artifact retrieval. Large model output and diagnostic logs must be bounded.

The profile contract should support discovery, capability negotiation, documentation and optional per-project configuration without silently enabling network access or installing proprietary tools. Define extension points with tests for file detection, embedded syntax, local execution, remote execution, log diagnostics and artifact previews. Start with one or two well-supported profiles and expand based on user demand rather than promising every application at launch.

**Status:** proposed extension architecture; profile-specific functionality beyond existing ESS scaffolding is not yet implemented or validated.

## Existing limitations

Current implementation is local-first, uses no version-locked package snapshot and has not been confirmed in native macOS Cocoa. The proposed execution layer and backend contracts in this document are targets, **not assertions of existing code**. Preserve these distinctions in README and workflow documentation.
