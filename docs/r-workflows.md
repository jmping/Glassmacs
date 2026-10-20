# R and reproducible-document workflows

> **Document ID:** DOC-R-WORKFLOWS  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-19  
> **Coverage:** Current and explicitly proposed R and research document workflows  
> **Supersedes:** None


## ESS and R

Install ESS with `./scripts/bootstrap`. `.R` and `.r` files use ESS's
`R-mode` when available and fall back to fundamental mode otherwise. Start a
session with `M-x glassmacs-r-start` (or the usual `M-x R`). ESS's existing
`C-c C-c` and `C-c C-r` bindings are preserved. Glassmacs also exposes
`glassmacs-r-send-line`, `glassmacs-r-send-region`,
`glassmacs-r-send-function`, and `glassmacs-r-send-buffer`.

Set `glassmacs-r-executable` in `~/.config/glassmacs/custom.el` to override
ESS's `inferior-ess-r-program` setting. No platform-specific R path is
assumed. ESS provides completion, help, syntax highlighting, and project-aware
session behavior.

## Documents

R Markdown (`.Rmd`), Quarto (`.qmd`), Sweave (`.Rnw`, `.Snw`), and R
documentation (`.Rd`) have associations that choose their appropriate
installed mode, with graceful basic-mode fallbacks. The bootstrap installs
markdown-mode, Quarto mode, polymode/poly-R, and AUCTeX as optional aids.
Poly-R is selected for R Markdown when its mode is available; ESS supplies
Rnw/Rd modes when installed.

- `M-x glassmacs-render-rmarkdown` calls `rmarkdown::render()` with Rscript.
- `M-x glassmacs-render-quarto` invokes `quarto render`.
- `M-x glassmacs-knit-sweave` calls `knitr::knit()` with Rscript.

These commands require a saved buffer. Paths are passed as process arguments,
not interpolated into a shell command; R paths are quoted as R string
literals. Missing executables and nonzero exit status are reported, with
process output in `*Glassmacs Process*`. R packages such as `rmarkdown` or
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

## Planned execution routing: local, terminal and SSH

The current commands above run locally; remote execution and unified project backend selection are **not implemented**. The target architecture is described in [architecture](architecture.md).

- **Local direct:** Rscript, Quarto and rendering with direct process arguments; use persistent ESS for interactive evaluation rather than spawning an R process per command.
- **Terminal/PTY:** project-associated persistent shell or R sessions, keeping the console independent from source buffers. Generic terminal text injection must not replace ESS evaluation APIs.
- **SSH/TRAMP:** select an OpenSSH host alias from the user's SSH configuration; open remote files with TRAMP; use established ESS remote-R facilities and verify session and working directory before evaluating.
- **Local editor / remote compute:** explicit mapping or transfer of source code and artifacts is required. A local path is not assumed to exist on the server.
- **Remote Shiny:** future opt-in SSH port forwarding, remote loopback binding, local preview URL and tunnel cleanup, never public exposure by default.
- **Durable remote work:** future tmux/scheduler support with detach/reconnect/log/cancel semantics; ordinary SSH sessions do not guarantee survival across disconnects.

Project execution configuration must be opt-in and non-executable; never run commands simply because a project or TRAMP path was opened. The profile shape in the architecture document is illustrative and is not yet an available Lisp variable.

## LaTeX and PDF workflows (planned verification)

LaTeX should use the **same** local/terminal/SSH execution routing as R and document rendering, with AUCTeX and established TeX tooling supplying LaTeX-specific behavior. A separate LaTeX execution backend is not needed. Planned supported engines include `latexmk`, `pdflatex`, `xelatex` and `lualatex`, with BibTeX/Biber where appropriate. Local compilation, log/error navigation and PDF preview must be verified with installed dependencies; remote builds additionally require explicit PDF artifact access and source-to-output path mapping. SyncTeX forward/inverse search across a remote boundary requires dedicated integration and testing. These capabilities are not yet validated in Glassmacs.

See the [development roadmap](roadmap.md) for planned delivery and test milestones.

## R console output floods (planned safeguards)

Accidentally printing an enormous data frame or database result must not make the editor unusable. The design calls for a configurable output budget, visible suppression/truncation status, and three separate commands: **stop displaying**, **interrupt the current R computation**, and **terminate the R session**. The first action does not guarantee that R stops producing output; Glassmacs must continue safely handling the stream or use explicit process control to avoid pipe/PTY/SSH backpressure. Preserve ESS prompts and evaluation state, and make it possible to resume normal evaluation afterward. These protections are **planned, not implemented**; see [architecture](architecture.md) and [roadmap](roadmap.md).


## Pending R evaluation queue (planned)

Glassmacs should offer a per-R-session **execution queue** so multiple evaluation requests do not block editing. Pending entries contain captured code snapshots and target-session information, with a dedicated interface to inspect, edit, reorder, pause, resume or remove work **before** it reaches R. Distinct actions should interrupt the currently running evaluation, clear future pending work, or terminate the session. One complete region is a safe initial queue unit; splitting by source lines is not generally valid R parsing. Interactive prompts, ESS readiness, output suppression and SSH disconnections require explicit state handling. This feature is **not implemented**; see [architecture](architecture.md) and [roadmap](roadmap.md).

