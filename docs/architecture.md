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

## Existing limitations

Current implementation is local-first, uses no version-locked package snapshot and has not been confirmed in native macOS Cocoa. The proposed execution layer and backend contracts in this document are targets, **not assertions of existing code**. Preserve these distinctions in README and workflow documentation.
