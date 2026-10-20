# Glassmacs

Glassmacs is an isolated GNU Emacs configuration aiming to bring a modern
macOS-native editing experience to R and reproducible research. It is a
configuration layered on upstream Emacs, not an Emacs fork or an Aquamacs
code port.

## Quick start

Install a current GNU Emacs (29 or newer is recommended), then from this
checkout run:

```sh
./scripts/bootstrap
./scripts/glassmacs
```

The bootstrap installs ESS and optional document-mode packages into
`~/.config/glassmacs/elpa`, separate from an existing Emacs or Aquamacs
configuration. Set `GLASSMACS_HOME` to use another isolated data directory.
The launcher uses `emacs -Q` and loads this checkout's `init.el`; it does not
edit `~/.emacs`, `~/.emacs.d`, or Aquamacs preferences. `R` and the Quarto CLI
are separate applications and must be installed and available on `PATH`.

Run the automated tests with `./scripts/test`. See
[development](docs/development.md) for testing and
[architecture](docs/architecture.md) for implementation boundaries.

## Implemented

- Isolated startup and package directory.
- A macOS graphical-only Command-key profile that leaves Emacs Control/Meta
  and language-mode keymaps intact.
- Optional ESS integration and `.R`/`.r` support.
- Built-in Glassmacs dark and light themes.
- Best-effort R Markdown, Quarto, Sweave/knitr, and Rd mode associations;
  renderer commands use direct process invocation.
- Local-only Shiny launch and process-stop commands.
- ERT tests for configuration, bindings, associations, themes, path quoting,
  and missing optional tools.

## Planned / not verified here

Native macOS Cocoa behavior has not been tested on this Linux development
environment. The optional integrations depend on the corresponding R packages,
Quarto, and Emacs packages being installed. The package archives install current
compatible package versions but are not locked to a reproducible package
snapshot. Native Swift application packaging and previews are future work.

See [keybindings](docs/keybindings.md) and [R workflows](docs/r-workflows.md)
for details and known limitations.
