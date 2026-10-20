# Glassmacs

**The power of Emacs. The elegance of macOS. Built for R and research.**

Glassmacs is an open-source project to create a modern, Mac-native GNU Emacs experience, inspired by Aquamacs and designed for statistical computing, programming, and reproducible research.

Glassmacs combines the extensibility and power of GNU Emacs with the familiar conventions of modern macOS, attractive syntax highlighting, and integrated workflows for R, ESS, Shiny, Quarto, R Markdown, Sweave, and LaTeX.

## Project Vision

Aquamacs brought GNU Emacs closer to the Mac by adopting native keyboard shortcuts, application conventions, and user-friendly defaults.

Glassmacs aims to carry that philosophy forward for contemporary macOS, without maintaining a heavily modified Emacs core.

Our goals are to:

- **Feel at home on macOS.** Modern interface conventions, attractive typography, native-feeling window management, and light/dark appearances.
- **Preserve Aquamacs muscle memory.** Familiar editing shortcuts combined with contemporary macOS keyboard conventions.
- **Make R a first-class language.** Excellent ESS integration, intelligent indentation, syntax highlighting, completion, diagnostics, and interactive R sessions.
- **Support reproducible research.** Seamless editing, execution, rendering, and previewing of R Markdown, Quarto, Sweave, and knitr documents.
- **Make Shiny development easier.** Integrated application execution, diagnostics, and preview workflows.
- **Be a dependable plain text editor.** Open and edit ordinary text files without requiring R or research tooling, and provide safe, responsive inspection of very large text documents and logs.
- **Remain true to GNU Emacs.** Preserve Emacs extensibility, existing packages, and conventional Emacs commands.
- **Minimize maintenance overhead.** Prefer upstream GNU Emacs and actively maintained packages over custom forks and duplicated functionality.

## Planned Features

### Modern macOS Experience
- Native GNU Emacs graphical editor
- Modern macOS-inspired appearance
- Light and dark themes
- Customizable fonts and syntax highlighting
- Mac-style application and document shortcuts
- Familiar Aquamacs editing behavior
- Optional Swift-based application integration

### R and Statistical Computing
- Modern Emacs Speaks Statistics (ESS)
- Interactive R sessions
- Send lines, regions, functions, and buffers to R
- Context-aware syntax highlighting
- Completion and diagnostic integration
- R help, documentation, and package-development tools

### Reproducible Documents
- R Markdown (`.Rmd`)
- Quarto (`.qmd`)
- Sweave (`.Rnw`, `.Snw`)
- knitr
- LaTeX and AUCTeX
- Embedded R code chunks
- HTML, PDF, and other supported output formats
- Render and preview commands

### Shiny Development
- Run and stop local Shiny applications
- Support `app.R` and `ui.R` / `server.R` projects
- View application output and errors
- Open local application previews

### Hybrid Aquamacs/macOS Keybindings
- Command-key shortcuts for common Mac operations
- Traditional Emacs Control and Meta key sequences
- Preserved ESS evaluation commands
- Configurable keyboard profiles


### Execution and remote research roadmap

Glassmacs aims to support fast local direct execution, persistent terminal/PTY sessions, and SSH/TRAMP-based remote R and research workflows. The editor and computational host need not be the same machine. Planned capabilities include per-project execution profiles, remote ESS, asynchronous rendering, remote Shiny previews through secure SSH port forwarding, and detachable long-running server jobs. **These features are architectural goals, not part of the present prototype.** See [execution architecture](docs/architecture.md) and [R workflows](docs/r-workflows.md).

## Architecture

Glassmacs is intended to use an upstream GNU Emacs release as its editing engine.

The project will provide a modular Emacs Lisp configuration layer for macOS behavior, appearance, language integration, and research workflows.

Where necessary, lightweight Swift components may provide additional macOS application integration.

The project will avoid modifying the GNU Emacs core unless a specific limitation makes such changes necessary.

## Getting started with the prototype

The first development milestone provides an experimental Emacs Lisp configuration,
not a packaged macOS application. Install GNU Emacs 29 or newer, then from a
checkout of Glassmacs run:

```sh
./scripts/bootstrap
./scripts/glassmacs
```

The bootstrap installs ESS and optional document-editing packages in
`~/.config/glassmacs/elpa`, separate from your existing Emacs and Aquamacs
configuration. Set `GLASSMACS_HOME` to choose another data directory.
The launcher starts Emacs with `-Q` and loads Glassmacs's `init.el`;
it does not edit `~/.emacs`, `~/.emacs.d`, or Aquamacs preferences.

Install R separately and ensure its executable is available on `PATH`.
Quarto and other rendering tools are also external dependencies.

Run the automated tests with:

```sh
./scripts/test
```

See [development](docs/development.md), [architecture](docs/architecture.md),
[roadmap](docs/roadmap.md),
[keybindings](docs/keybindings.md), and [R workflows](docs/r-workflows.md)
for details.

## Prototype implementation status

The first milestone introduces:

- Isolated startup and package storage.
- A macOS graphical Command-key profile, intended to preserve conventional
  Emacs Control/Meta bindings and language-mode keymaps.
- Optional modern ESS integration and `.R`/`.r` file associations.
- Glassmacs dark and light themes.
- Best-effort R Markdown, Quarto, Sweave/knitr, and Rd editing support,
  plus document-rendering commands.
- Local Shiny process start/stop commands.
- Emacs Lisp tests for startup, keybindings, file associations, themes,
  string quoting, and missing dependencies.

**Not yet verified:** Native macOS Cocoa behavior and full Aquamacs
keybinding compatibility. Copilot developed this milestone in a Linux
environment. ESS, R, document rendering, and Shiny functionality require
the relevant Emacs packages, R packages, and external executables.
Package versions are not pinned to a reproducible snapshot.
A native Swift integration layer, standalone application packaging,
and polished previews remain future work.

## Development Status

**Early prototype available for testing; not yet a production-ready macOS application.**

The initial development priorities are:

1. Establish a stable GNU Emacs baseline on modern macOS.
2. Implement hybrid Aquamacs/macOS keybindings.
3. Configure and test modern ESS and R.
4. Integrate R Markdown, Quarto, Sweave, and Shiny workflows.
5. Develop the visual theme and native application experience.
6. Package and test a standalone macOS application.

The first milestone implements part of this foundation, as described above. The complete feature set remains a development goal.

## Relationship to Aquamacs

Glassmacs is inspired by Aquamacs and its philosophy of making GNU Emacs comfortable for Mac users.

It is an independent experimental project, not an official Aquamacs release or an affiliated GNU Emacs distribution.

We intend to acknowledge and respect the contributions of the Aquamacs, GNU Emacs, ESS, and broader open-source communities.

## License

License selection and third-party code obligations will be documented before redistribution. Components derived from GNU Emacs or Aquamacs must comply with their applicable GNU GPL terms.

## Contributing

Contributions, bug reports, feature suggestions, and testing are welcome as development progresses, particularly from users of R, ESS, Aquamacs, Quarto, Shiny, and reproducible research tools.
