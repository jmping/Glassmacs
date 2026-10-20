# R and reproducible-document workflows

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
