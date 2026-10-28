# R and reproducible-document workflows

## Integrated 0.1 development status — 2026-10-27

PRs [#18](https://github.com/jmping/Glassmacs/pull/18), [#19](https://github.com/jmping/Glassmacs/pull/19), [#20](https://github.com/jmping/Glassmacs/pull/20), [#21](https://github.com/jmping/Glassmacs/pull/21), and [#22](https://github.com/jmping/Glassmacs/pull/22) have merged into `main`. The most recent merge was #22 at `604e44e`. Their pull-request CI completed successfully (Emacs ERT, ESS/R integration, and macOS launcher build). These results establish code integration and automated validation, **not interactive Cocoa GUI acceptance**.

Implemented capabilities include native application/menu/window infrastructure; configurable new-frame/new-tab/reuse-current document opens; New Buffer in Mode and Change Buffer Mode; ESS-backed R source/console menus and contextual toolbar actions; explicit R session start, targeting, inspection and listing; execution-queue and output controls; Save Document As and non-destructive unsaved-document review; and keyboard/document/toolbar preferences. R Markdown, Quarto, Sweave, Shiny and remote workflows have preliminary integrations and still require separate end-to-end validation. Neither complete historical Aquamacs parity nor a production release is claimed.

**Still outstanding:** signed-app testing of Cocoa reopen/close, document safety and focus, R source-to-console execution, session targeting, native R/Quartz plotting, toolbar image/layout, persistent preferences, and optional rendering/Shiny workflows. A releasable 0.1 build also needs candidate-specific signing, notarization, Gatekeeper checks and license/source-distribution review. Earlier signed builds do not certify the current `main` tree.

**Next audit, separate from this documentation sync:** compare current Glassmacs menu commands against historical Aquamacs menu inventory and then triage historical Aquamacs issues, recording evidence, priority and disposition without treating proposed parity as implemented behavior.

> **Document ID:** DOC-R-WORKFLOWS  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-28  
> **Coverage:** Current and explicitly proposed R and research document workflows  
> **Supersedes:** None


## ESS and R

Install ESS with **Glassmacs → Install R & Document Packages…** in the app,
or `./scripts/bootstrap` from a source checkout; both run
`glassmacs-install-optional-packages`. `.R` and `.r` files use ESS's
`R-mode` when available and fall back to fundamental mode otherwise; in that
case Glassmacs offers, once per session, to install the packages, and the open
file switches to ESS after installation. When the app is started from Finder
or the Dock, R and Rscript are found through the shell environment import
described in the [macOS application guide](macos-launcher.md). Start a
session with `M-x glassmacs-r-start` (or the usual `M-x R`). ESS's existing
`C-c C-c` and `C-c C-r` bindings are preserved. Glassmacs also exposes
`glassmacs-r-send-line`, `glassmacs-r-send-region`,
`glassmacs-r-send-function`, and `glassmacs-r-send-buffer`.

Set `glassmacs-r-executable` in `~/.config/glassmacs/custom.el` to override
ESS's `inferior-ess-r-program` setting. No platform-specific R path is
assumed. ESS provides completion, help, syntax highlighting, and project-aware
session behavior.

### ESS/R graphics smoke path

Glassmacs does not manage graphics devices or provide a plot viewer. From an R
source buffer, start ESS with `M-x glassmacs-r-start`, then evaluate
`plot(cars)` using `M-x glassmacs-r-send-line` or ESS's normal evaluation
bindings. On macOS, use the native graphics device provided by the installed R
build when available; device and window behavior depend on that R installation.
This path has not been validated on macOS by Linux CI.

If `ggplot2` is already installed, an optional second check is:

```r
ggplot2::ggplot(cars, ggplot2::aes(speed, dist)) +
  ggplot2::geom_point()
```

If the native device is unavailable, check the R build's graphics capabilities
in the ESS console. `X11()` is an explicit fallback only when XQuartz and its
display are configured; Glassmacs neither requires XQuartz nor selects X11
automatically. To diagnose Glassmacs startup and optional dependencies, run
`M-x glassmacs-diagnostics`; it does not probe or execute R.

## Documents

R Markdown (`.Rmd`), Quarto (`.qmd`), Sweave (`.Rnw`, `.Snw`), and R
documentation (`.Rd`) have associations that choose their appropriate
installed mode, with graceful basic-mode fallbacks. The bootstrap installs
markdown-mode, Quarto mode (the MELPA `quarto-mode` package), polymode/poly-R,
and AUCTeX as optional aids.
Poly-R is selected for R Markdown when its mode is available; ESS supplies
Rnw/Rd modes when installed.

- `M-x glassmacs-render-rmarkdown` calls `rmarkdown::render()` with Rscript.
- `M-x glassmacs-render-quarto` invokes `quarto render`.
- `M-x glassmacs-knit-sweave` calls `knitr::knit()` with Rscript.

These commands render the file on disk, so they require a visited file. If
the buffer has unsaved changes they offer to save it first; declining cancels
the render rather than silently rendering stale contents. Paths are passed as
process arguments, not interpolated into a shell command; R paths are quoted
as R string literals. Rendering runs asynchronously, so Emacs stays usable
during long renders: output streams into `*Glassmacs Process*`, and a message
reports success or the nonzero exit status when the renderer finishes. Only
one render runs at a time; starting another while one is running is refused.
A missing executable is reported immediately. R packages such as `rmarkdown` or
`knitr` must be installed in the selected R library.

## Shiny

From `app.R`, `ui.R`, or `server.R`, or a directory containing one of those
layouts, run `M-x glassmacs-shiny-start`. It starts Rscript with
`shiny::runApp()` bound to `127.0.0.1`; it does not select a port or expose the
app on a public interface. `M-x glassmacs-shiny-stop` terminates that process.
Output and startup errors appear in `*Glassmacs Shiny*`. Set
`glassmacs-shiny-launch-browser` to non-nil to let Shiny open the local preview.

R, the Shiny R package, Quarto, and document packages are external
dependencies; their presence is not guaranteed by installing Glassmacs.

## SSH/TRAMP remote files and terminals

Remote files remain ordinary Emacs buffers and use upstream TRAMP/OpenSSH:

- Use `C-x C-f` with a standard path such as `/ssh:research:/home/me/project/file.R`, or run `M-x glassmacs-remote-open` and enter an SSH host name/alias plus an absolute remote path. Directories open through Emacs' normal directory handling.
- `M-x glassmacs-remote-shell` opens an Emacs shell with a TRAMP remote working directory. Commands entered there are explicit user actions.
- `M-x glassmacs-remote-inspect` reports the current remote method, host, user, port and whether an existing TRAMP connection buffer has a live process. It does not connect.
- `M-x glassmacs-remote-cleanup-connection` explicitly cleans up the current TRAMP connection while preserving TRAMP's password cache. Accessing the remote path again can establish a new connection; Glassmacs does not replay commands or retry uncertain operations.
- `M-x glassmacs-remote-check-tools` reports local `ssh`, `mosh` and `tmux` executable availability. It does not probe remote hosts.
- `M-x glassmacs-remote-mosh` optionally starts an interactive Mosh terminal. Local `ssh` and `mosh` executables, a configured SSH host, a remote `mosh-server`, and suitable UDP network access are required. Mosh does not replace TRAMP or OpenSSH file access.

The wrappers accept simple host names/aliases (not `user@host` or wildcard patterns) and absolute remote paths. OpenSSH continues to read the user's existing SSH configuration and use its configured authentication and host-key checks. Glassmacs configuration does not store SSH credentials or private keys and does not edit SSH configuration, agents, or remote hosts. Startup and project opening do not initiate network connections or run remote/project configuration. Native TRAMP error reporting is retained for unavailable hosts, authentication failures and timeouts.

tmux remains an external terminal multiplexer. Glassmacs does not launch, install, or configure it; use it explicitly in a remote shell if it is already available on the host. Local tool detection cannot establish whether remote tmux or `mosh-server` is installed.

The read-only `glassmacs-remote-context` function returns a plist with the method, user, host, port and remote path for a TRAMP path, or nil for a local path. It is an integration point only; it does not create or manage ESS sessions.

### Optional manual SSH verification

Use a host alias already configured by the user; Glassmacs does not create or modify it. Confirm that the alias is trusted and usable with the user's normal OpenSSH setup, then:

1. Launch Glassmacs offline and confirm ordinary local files still open, edit and save.
2. Run `M-x glassmacs-remote-open`, enter the alias and an existing absolute remote test path, edit it, save it, and verify the saved content from a separate SSH client.
3. Run `M-x glassmacs-remote-shell` for the same host/directory and explicitly inspect `pwd` or another harmless command.
4. Run `M-x glassmacs-remote-inspect`, then `M-x glassmacs-remote-cleanup-connection`; access the remote file again and confirm TRAMP reconnects when requested.
5. Optionally test `M-x glassmacs-remote-mosh` only on a host where Mosh is already configured. Do not treat terminal reconnection as proof of exactly-once command delivery.

Do not run this procedure in public CI or use private credentials in tests. Remote ESS, remote R execution, execution queues, durable jobs, remote Shiny and artifact transfer are not provided by this foundation.

## Planned execution routing: local, terminal and SSH

Existing R/document commands run locally. SSH/TRAMP file and interactive shell workflows are implemented; remote execution and unified project backend selection are **not implemented**. The target architecture is described in [architecture](architecture.md).

- **Local direct:** Rscript, Quarto and rendering with direct process arguments; use persistent ESS for interactive evaluation rather than spawning an R process per command.
- **Terminal/PTY:** project-associated persistent shell or R sessions, keeping the console independent from source buffers. Generic terminal text injection must not replace ESS evaluation APIs.
- **SSH/TRAMP:** select an OpenSSH host alias from the user's SSH configuration; open remote files with TRAMP; use established ESS remote-R facilities and verify session and working directory before evaluating.
- **Local editor / remote compute:** explicit mapping or transfer of source code and artifacts is required. A local path is not assumed to exist on the server.
- **Remote Shiny:** future opt-in SSH port forwarding, remote loopback binding, local preview URL and tunnel cleanup, never public exposure by default.
- **Durable remote work:** future tmux/scheduler support with detach/reconnect/log/cancel semantics; ordinary SSH sessions do not guarantee survival across disconnects.

Project execution configuration must be opt-in and non-executable; never run commands simply because a project or TRAMP path was opened. The profile shape in the architecture document is illustrative and is not yet an available Lisp variable.

## LaTeX and PDF workflows

**Implemented (2026-10-28), GUI unverified.** With AUCTeX installed (Glassmacs →
Install R & Document Packages…), Glassmacs configures it for PDF output with
SyncTeX. On macOS the PDF viewer is Skim when `/Applications/Skim.app` is
installed and Preview otherwise (`glassmacs-latex-pdf-viewer`). With Skim,
`C-c C-v` shows the PDF at the source line, and Command-Shift-click in Skim
jumps back to the source once Skim's Sync preference uses the Emacs preset
with Glassmacs's `emacsclient` (`Glassmacs.app/Contents/MacOS/bin/emacsclient`);
Glassmacs starts the Emacs server for this when a document is compiled.
TeX binaries are found through the shell environment import. Glassmacs keeps
typing literal in TeX buffers: `"` inserts `"` (set
`glassmacs-latex-smart-quotes` to use AUCTeX's typographic quotes), and
AUCTeX's electric insertion options stay off. Your own AUCTeX customizations
are not overridden.

`M-x glassmacs-knit-sweave-pdf` knits an `.Rnw` file with
`knitr::knit2pdf()` in the document's directory, without blocking Emacs, and
opens the PDF when it succeeds. SyncTeX positions refer to the generated
`.tex` file, not the `.Rnw` source.

**Spelling.** Glassmacs → Check Document Spelling… reviews the region or
document word by word, and Check Spelling While Typing (off by default)
underlines misspellings in prose modes. Neither changes text unless you pick a
correction. Code and math, identifier-shaped words (`my_data`, `data.frame`,
`ggplot2`, `readRDS`) and the names of objects and functions loaded in the
buffer's R session are not flagged. Those names are read with a hidden `ls()`
over the workspace and attached packages only while R is idle (never queued
behind or interrupting your work), when checking starts and on
`M-x glassmacs-spelling-refresh-r-names`. Install a checker with
`brew install enchant` (uses the macOS dictionaries) or `brew install hunspell`.

### Planned

LaTeX should use the **same** local/terminal/SSH execution routing as R and document rendering, with AUCTeX and established TeX tooling supplying LaTeX-specific behavior. A separate LaTeX execution backend is not needed. Planned supported engines include `latexmk`, `pdflatex`, `xelatex` and `lualatex`, with BibTeX/Biber where appropriate. Local compilation, log/error navigation and PDF preview must be verified with installed dependencies; remote builds additionally require explicit PDF artifact access and source-to-output path mapping. SyncTeX forward/inverse search across a remote boundary requires dedicated integration and testing. These capabilities are not yet validated in Glassmacs.

See the [development roadmap](roadmap.md) for planned delivery and test milestones.

## R console output floods

ESS R consoles have a configurable per-command display budget
(`glassmacs-r-output-budget`, default 1,000,000 characters). When the budget is
exceeded, Glassmacs shows a suppression marker, keeps primary and continuation
prompts visible when ESS marks them, and hides the remaining output until ESS
reports the process idle and a primary prompt appears at the start of a chunk
or after a newline.
An arbitrary chunk suffix resembling a prompt does not reset suppression.
`comint-buffer-maximum-size` is also set from
`glassmacs-r-output-buffer-maximum-lines` (default 10,000) to bound retained
console history; older lines are deleted. ESS continues consuming process output and remains responsible
for process and prompt state. These limits do not stop R from producing data or
guarantee that a local, terminal, or remote transport cannot apply backpressure.

**Chunk-boundary limit:** ESS 24.01.1 sets its `busy` state by matching its
primary-prompt regexp against each raw process-output chunk. If a prompt is
split so no individual chunk matches, ESS may remain busy; Glassmacs does not
replace ESS's process filter or force a readiness transition. Likewise, a
complete output line exactly resembling the R prompt is indistinguishable from
a prompt to ESS itself. Such cases remain a reliability limitation; see the
roadmap's verification status.

Three distinct commands are available: `glassmacs-r-stop-displaying-output`
hides output for the active command without interrupting R;
`glassmacs-r-interrupt` requests an interrupt and keeps pending queue work paused;
and `glassmacs-r-terminate-session` requires interactive confirmation before
terminating the process. When ESS recognizes the next primary prompt, normal
output display resumes automatically. A prompt split across chunks may not be
recognized by ESS, so suppression can remain active in that case. Output
flooding over SSH or a terminal/PTY and native macOS responsiveness have not
been validated; see
[architecture](architecture.md) and [roadmap](roadmap.md).


## R sessions and execution queue (minimal subset implemented)

Implemented in `lisp/glassmacs-sessions.el` and `lisp/glassmacs-r-ui.el`.
Session operations are available through `M-x`; R source buffers and ESS
consoles also have a right-click context menu.

**Sessions.** ESS keeps owning the process, buffer and filters. Glassmacs
observes ESS processes (`ess-process-name-list`, the process `busy` property
ESS maintains) and gives each a stable identity (`R-1`, `R-2`, ...). Commands:
`glassmacs-r-start-session` (reports missing ESS or R), `glassmacs-r-list-sessions`,
`glassmacs-r-select-session` (buffer-local target),
`glassmacs-r-clear-session-target`, and `glassmacs-r-inspect-session`. A selected
target is shown as `R[R-n]` in the modeline; a trailing `!` marks a stale or
terminated process incarnation. Common ESS region, line, function,
and buffer evaluation commands retain their ESS keybindings and route through
the immutable queue when a buffer has an explicit target; without an explicit
target ESS behavior is unchanged. Queue submissions retain the exact session
process identity resolved at submission. If that process exits or restarts,
Glassmacs reports the stale target and does not fall through to a different
session; clear or explicitly select a live target to continue.

With no explicit target, Glassmacs uses the only live session or ESS's
`ess-local-process-name`; with multiple unresolved choices it prompts (and
errors in batch use). `glassmacs-r-submit-region-to-session` is a one-off
selection that does not change the buffer target. Termination is detected by a
sentinel added with `add-function :after` and by polling.

**Editable console history.** Each ESS R process buffer uses its own comint
history ring; history is not shared across R sessions and is in-memory only.
`RET` keeps ESS's own binding (`inferior-ess-send-input`), which runs
`ess-send-input-hook` and resets ESS's prompt and completion-cache state before
submitting the input. `M-p` / `M-n` retain comint history navigation.
`Up` recalls an older entry on the first line of the current prompt input;
`Down` recalls a newer entry on its last line. Within a multiline input, Up/Down
move vertically instead, so the body can be traversed. Left/Right, Home/End,
mouse placement, and ordinary Emacs editing commands edit recalled text in
place; submitting the edited command with Return runs the edited version.
Source-buffer Up/Down retain ordinary cursor navigation.

**Context menu.** Right-click an R source or ESS R console for session
selection/clearing, associated console, run selection, one-off selection in
another session, queue inspection, directory inspection, and an explicit
`getwd()` request. Menu enablement reads current Emacs/process state only; it
does not refresh sessions, connect over SSH, or execute R. The `getwd()` menu
item is an explicit user action and queues a `getwd()` expression to the chosen
session.

`glassmacs-r-inspect-directories` distinguishes the document directory,
document host, buffer `default-directory`, local project root, R process host,
and ESS console `default-directory` recorded at session registration. The
console directory is not guaranteed to equal a live R `getwd()` or a changing
shell cwd. This inspection does not assume these paths share a host, translate
paths, or run `setwd()`. A remote project root is reported as not queried. Use
`glassmacs-r-show-r-working-directory` only when you explicitly want the live R
process to print `getwd()`.

**Queue.** `glassmacs-r-submit-region` / `glassmacs-r-submit-buffer` /
`glassmacs-queue-submit` capture the text as an immutable snapshot and queue it
as one unit (never split by line) on a per-session FIFO. Only one entry is
dispatched at a time via `ess-send-string`, only when ESS reports the process
idle; a timer polls, so Emacs is never blocked. Inspect with
`glassmacs-queue-show` / `glassmacs-queue-pending`; `glassmacs-queue-pause`,
`glassmacs-queue-resume`. States: `pending`, `running`, `completed`, `failed`
(the send itself failed; the queue pauses and nothing is retried),
`uncertain`, `orphaned`, `removed`.

**Removing pending commands.** `glassmacs-queue-remove`,
`glassmacs-queue-remove-entries` and `glassmacs-queue-clear` all go through one
confirmation that shows session, queue position and source preview, warns that
later results may change (order, dependencies, RNG state), and defaults to
**Keep command**. There is no preference to disable it, and non-interactive
calls keep the command. Confirmed removals stay as `removed` records and in
`glassmacs-sessions-history` with timestamp, original position, id and source.
`glassmacs-queue-interrupt` is a separate operation: it interrupts the running
queued command, marks it `uncertain`, pauses the queue and keeps pending work.

**Termination.** A running entry becomes `uncertain`, pending entries become
`orphaned`; records are kept, the queue is paused and nothing is replayed.

**Limitations.** `completed` means ESS saw R return to its primary prompt, not
that the code succeeded; R errors are not parsed. An incomplete expression
leaves R at a continuation prompt and is marked `uncertain`. Entries typed
directly in the console are not tracked, and a busy console delays dispatch.
History is in memory only and bounded: `glassmacs-sessions-history-limit`
(default 10,000 events) caps `glassmacs-sessions-history`, and
`glassmacs-sessions-finished-entry-limit` (default 1,000 per session) caps
finished queue records (`completed`, `failed`, `uncertain`, `orphaned`,
`removed`). The oldest records are discarded first; pending and running
entries are never discarded. Set either option to nil to keep everything.
Not implemented: editing or reordering entries, a
queue buffer UI, persistence across Emacs restarts, SSH/remote sessions. See
[architecture](architecture.md) and [roadmap](roadmap.md).
