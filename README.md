# Glassmacs

> **Document ID:** DOC-README  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-27
> **Coverage:** Project identity, audience, vision and high-level getting started  
> **Supersedes:** None

## Integrated 0.1 development status — 2026-10-27

PRs [#18](https://github.com/jmping/Glassmacs/pull/18), [#19](https://github.com/jmping/Glassmacs/pull/19), [#20](https://github.com/jmping/Glassmacs/pull/20), [#21](https://github.com/jmping/Glassmacs/pull/21), and [#22](https://github.com/jmping/Glassmacs/pull/22) have merged into `main`. The most recent merge was #22 at `604e44e`. Their pull-request CI completed successfully (Emacs ERT, ESS/R integration, and macOS launcher build). These results establish code integration and automated validation, **not interactive Cocoa GUI acceptance**.

Implemented capabilities include native application/menu/window infrastructure; configurable new-frame/new-tab/reuse-current document opens; New Buffer in Mode and Change Buffer Mode; ESS-backed R source/console menus and contextual toolbar actions; explicit R session start, targeting, inspection and listing; execution-queue and output controls; Save Document As and non-destructive unsaved-document review; and keyboard/document/toolbar preferences. R Markdown, Quarto, Sweave, Shiny and remote workflows have preliminary integrations and still require separate end-to-end validation. Neither complete historical Aquamacs parity nor a production release is claimed.

**Still outstanding:** signed-app testing of Cocoa reopen/close, document safety and focus, R source-to-console execution, session targeting, native R/Quartz plotting, toolbar image/layout, persistent preferences, and optional rendering/Shiny workflows. A releasable 0.1 build also needs candidate-specific signing, notarization, Gatekeeper checks and license/source-distribution review. Earlier signed builds do not certify the current `main` tree.

**Next audit, separate from this documentation sync:** compare current Glassmacs menu commands against historical Aquamacs menu inventory and then triage historical Aquamacs issues, recording evidence, priority and disposition without treating proposed parity as implemented behavior.

---


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
- A standalone Cocoa application bundle with a thin Swift process bootstrap

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

Glassmacs uses upstream Cocoa GNU Emacs as its editing engine, with a modular
Emacs Lisp configuration for macOS behavior, appearance, and research workflows.

The macOS app build packages the upstream Emacs bundle as the top-level
`Glassmacs.app`; its Swift bootstrap replaces itself with Emacs rather than
spawning a second editor/application. The project avoids modifying GNU Emacs.

## Build and launch

For development on macOS or Linux, install GNU Emacs and run the checkout's
launcher:

```sh
./scripts/glassmacs
```

For a standalone macOS build, use macOS 13 or newer with Swift 6 and the
standard tools documented in the [macOS application guide](docs/macos-launcher.md):

```sh
./scripts/build-macos-app
./scripts/validate-macos-app build/Glassmacs.app
```

The builder downloads the pinned Cocoa Emacs bundle and verifies its checksum.
Drag `build/Glassmacs.app` into `/Applications`, then launch it from Finder,
Spotlight, or the Dock. No separate Emacs installation or Glassmacs checkout is
needed at runtime. Builds are unsigned by default; the documented release
scripts support Developer ID signing and notarization. Dock identity, Finder
integration, and other GUI behavior still require macOS manual testing.

For terminal use or development, `./scripts/glassmacs -nw` starts terminal
Emacs. File arguments are forwarded directly, for example
`./scripts/glassmacs some-file.R` or
`./scripts/glassmacs /ssh:research:/home/user/project/analysis.R`. Set
`GLASSMACS_EMACS` to select a non-default Emacs executable.

Core editing requires only GNU Emacs. ESS, R, Quarto, TeX/AUCTeX, SSH and Mosh
are optional integrations; ordinary text editing does not require them. To
install the optional Emacs packages for research/document workflows, run:

```sh
./scripts/bootstrap
```

This explicit first-run step needs network access when packages are missing.
For the installed macOS app, run its bundled bootstrap:

```sh
GLASSMACS_EMACS="/Applications/Glassmacs.app/Contents/MacOS/Emacs" \
  "/Applications/Glassmacs.app/Contents/Resources/Glassmacs/scripts/bootstrap"
```

Normal startup does not install packages or refresh archives. App state and
packages live in `~/Library/Application Support/Glassmacs`; the development
launcher uses `~/.config/glassmacs`. Set `GLASSMACS_HOME` to override either
location. The app launches with `-Q` and does not modify `~/.emacs`,
`~/.emacs.d`, or Aquamacs preferences. R, ESS, Quarto, TeX and other optional
tools are not bundled. See [R workflows](docs/r-workflows.md) for R setup.

Install R, Quarto, TeX and remote tools separately when needed, and ensure their
executables are available on `PATH`. Missing optional integrations do not block
startup; the relevant command reports what is missing.

For installation, diagnostics, manual macOS GUI checks, and limitations, see
the [macOS application guide](docs/macos-launcher.md). Linux batch/terminal
checks do not validate Cocoa behavior. CI builds and validates the app bundle
but does not perform interactive GUI verification. Signing and notarization
are release-only operations requiring a Developer ID identity and local
notarytool Keychain profile.

Interactive document opens on a graphical macOS session default to a separate
frame, with configurable new-tab and reuse-current policies. Special buffers
and non-graphical sessions are not redirected. Cocoa file-open events use the
same Lisp policy, but the GUI event path and frame behavior remain unverified.
Run `M-x glassmacs-diagnostics` for local dependency and platform information.
For the optional R graphics smoke check, see [R workflows](docs/r-workflows.md).

Run the automated tests with:

```sh
./scripts/test
```

See [development](docs/development.md), [architecture](docs/architecture.md),
[roadmap](docs/roadmap.md),
[keybindings](docs/keybindings.md), and [R workflows](docs/r-workflows.md)
for details.

## Prototype implementation details (historical baseline)

The first milestone introduces:

- Isolated startup and package storage.
- A macOS graphical Command-key profile, intended to preserve conventional
  Emacs Control/Meta bindings and language-mode keymaps.
- Optional modern ESS integration and `.R`/`.r` file associations.
- Glassmacs dark and light themes.
- Best-effort R Markdown, Quarto, Sweave/knitr, and Rd editing support,
  plus document-rendering commands.
- Local Shiny process start/stop commands.
- ERT coverage for isolated startup, document-opening policy, diagnostics,
  keybindings, file associations, themes, R graphics output and missing tools;
  CI also runs a real ESS/R integration job.

**Not yet verified:** Native macOS Cocoa behavior and full Aquamacs
keybinding compatibility. The standalone app build and packaging CI are
implemented, but the GUI app has not yet been exercised on macOS. ESS, R,
document rendering, and Shiny functionality require the relevant Emacs
packages, R packages, and external executables. Optional Emacs package
versions are not pinned to a reproducible snapshot.

Issue #10 adds an interactive document-opening policy and local diagnostics.
The default separate-frame behavior, `new-tab` and `reuse-current` choices,
and privacy-limited report are implemented in Lisp; actual Cocoa frame behavior
and ESS graphics on macOS have not been verified. Standard R graphics remain
owned by the installed R device; Glassmacs has no managed plot viewer.

## Development Status

**Integrated development preview for testing; not yet a production-ready macOS application.** A relocatable app bundle is built in macOS CI, while interactive macOS GUI, ESS/R and native graphics verification remain outstanding.

The initial development priorities are:

1. Establish a stable GNU Emacs baseline on modern macOS.
2. Implement hybrid Aquamacs/macOS keybindings.
3. Configure and test modern ESS and R.
4. Integrate R Markdown, Quarto, Sweave, and Shiny workflows.
5. Develop the visual theme and native application experience.
6. Complete interactive validation and refinement of the standalone macOS application.

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
