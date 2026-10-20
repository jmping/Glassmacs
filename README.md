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

## Architecture

Glassmacs is intended to use an upstream GNU Emacs release as its editing engine.

The project will provide a modular Emacs Lisp configuration layer for macOS behavior, appearance, language integration, and research workflows.

Where necessary, lightweight Swift components may provide additional macOS application integration.

The project will avoid modifying the GNU Emacs core unless a specific limitation makes such changes necessary.

## Development Status

**Early planning and prototyping.**

The initial development priorities are:

1. Establish a stable GNU Emacs baseline on modern macOS.
2. Implement hybrid Aquamacs/macOS keybindings.
3. Configure and test modern ESS and R.
4. Integrate R Markdown, Quarto, Sweave, and Shiny workflows.
5. Develop the visual theme and native application experience.
6. Package and test a standalone macOS application.

The features described above are project goals and are not yet implemented.

## Relationship to Aquamacs

Glassmacs is inspired by Aquamacs and its philosophy of making GNU Emacs comfortable for Mac users.

It is an independent experimental project, not an official Aquamacs release or an affiliated GNU Emacs distribution.

We intend to acknowledge and respect the contributions of the Aquamacs, GNU Emacs, ESS, and broader open-source communities.

## License

License selection and third-party code obligations will be documented before redistribution. Components derived from GNU Emacs or Aquamacs must comply with their applicable GNU GPL terms.

## Contributing

Contributions, bug reports, feature suggestions, and testing are welcome as development progresses, particularly from users of R, ESS, Aquamacs, Quarto, Shiny, and reproducible research tools.
