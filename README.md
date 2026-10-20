# Glassmacs

> **Document ID:** DOC-README  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-20
> **Coverage:** Project identity, audience, vision and high-level getting started  
> **Supersedes:** None


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

## Install and launch the development distribution

Glassmacs is a development distribution layered on upstream GNU Emacs, not a
standalone application. Install GNU Emacs 29 or newer (recommended) and make its
`emacs` executable available on `PATH`. From a checkout of Glassmacs, start the
graphical editor with:

```sh
./scripts/glassmacs
```

Use `./scripts/glassmacs -nw` for terminal Emacs, and pass ordinary Emacs
arguments or file paths after the launcher, for example
`./scripts/glassmacs some-file.R` or
`./scripts/glassmacs /ssh:research:/home/user/project/analysis.R`. The same
terminal command works on Linux with a terminal-capable GNU Emacs. Glassmacs
forwards these arguments to upstream Emacs; no separate argument syntax is
introduced. Set `GLASSMACS_EMACS` if the executable is not named `emacs` or is
not on `PATH`.

Core editing requires only GNU Emacs. ESS, R, Quarto, TeX/AUCTeX, SSH and Mosh
are optional integrations; ordinary text editing does not require them. To
install the optional Emacs packages for research/document workflows, run:

```sh
./scripts/bootstrap
```

This explicit first-run step needs network access when packages are missing.
Normal Glassmacs startup does not install packages or refresh package archives,
so it can run offline after any desired packages have been installed. Package
versions are not locked or reproducible yet. Packages and Glassmacs settings
are kept under `~/.config/glassmacs` by default; set `GLASSMACS_HOME` to use a
different directory. The launcher starts Emacs with `-Q` and does not modify
`~/.emacs`, `~/.emacs.d`, or Aquamacs preferences. Start ordinary GNU Emacs
with `emacs` (not the Glassmacs launcher) to return to its normal configuration.

Install R, Quarto, TeX and remote tools separately when needed, and ensure their
executables are available on `PATH`. Missing optional integrations do not block
startup; the relevant command reports what is missing.

For installation details and a manual smoke test, see
[development](docs/development.md). Linux batch/terminal checks do not validate
macOS Cocoa behavior. A native macOS graphical build, its hybrid shortcuts and
appearance still require manual verification; no standalone app packaging,
signing or notarization is provided.

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

## Planned AI and remote terminal integration

- **Support opt-in AI assistance.** Query local or remote agents about code, errors and documents with explicit context sharing, permissions and reviewed edits.
- **Support resilient remote terminals.** Offer Mosh as an optional interactive transport alongside SSH/TRAMP and tmux for unstable connections.

See [architecture](docs/architecture.md) and [roadmap](docs/roadmap.md) for proposed capabilities, trust boundaries and delivery stages. These integrations are not yet implemented.

Glassmacs also plans **research application profiles**: lightweight support for imported or embedded model syntax, local or remote execution, diagnostics and output artifacts. Early candidates include `lavaan`, JAGS/BUGS and Stan, with an extensible route to other installed statistical applications. Profiles reuse the execution infrastructure and remain optional; opening a file never implicitly executes it.

## Who Glassmacs is for

Glassmacs is designed for **experienced base R, ESS and Emacs users who work across languages, applications and remote computers**. It is not an RStudio clone or a project to impose RStudio-style workflows on established researchers. R is a first-class language, not the owner of the workspace. Files, buffers, terminals, external tools and reproducible scripts come first; integrations remain optional, transparent and composable.

See the [canonical documentation index](docs/index.md) for document authority, [governance policy](docs/documentation-governance.md) for updates, and [change register](docs/documentation-changelog.md) for changes in coverage.

## License

License selection and third-party code obligations will be documented before redistribution. Components derived from GNU Emacs or Aquamacs must comply with their applicable GNU GPL terms.

## Contributing

Contributions, bug reports, feature suggestions, and testing are welcome as development progresses, particularly from users of R, ESS, Aquamacs, Quarto, Shiny, and reproducible research tools.
