# Glassmacs

> **Document ID:** DOC-README  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-11-06  
> **Coverage:** Project overview, development build and documentation entry points  
> **Supersedes:** None

**The power of Emacs. The elegance of macOS. Built for R and research.**

Glassmacs is an open-source project building a modern, Mac-native GNU Emacs experience inspired by Aquamacs, with a particular emphasis on R, ESS and reproducible research. It combines upstream Cocoa Emacs, modular Emacs Lisp configuration and a thin macOS application bootstrap rather than maintaining a modified Emacs core.

> **Development status:** Glassmacs is under active development, not a production release. Automated CI verifies code and application packaging; interactive macOS behavior is tested separately on a local Mac. A passing build is not a guarantee of GUI correctness, recovery safety or release readiness.

## What Glassmacs offers

- **macOS-oriented editing:** configurable document window/frame policies, native menus and keyboard profiles combining Mac conventions with traditional Emacs shortcuts.
- **R and ESS workflows:** R source editing, interactive R sessions, source-to-console commands, session targeting and contextual menu actions.
- **Research documents:** integrations for R Markdown, Quarto, Sweave, LaTeX/AUCTeX and related tools, with varying levels of implementation and end-to-end verification.
- **Emacs compatibility:** upstream GNU Emacs extensibility and packages, including ordinary text editing without installing R.
- **Application packaging:** a standalone macOS application bundle, with optional research dependencies installed only with user consent.

Some workflows—including native graphics, remote execution, Shiny previews, window restoration and recovery—still require local acceptance testing. See the [acceptance matrix](docs/acceptance-matrix.md) for individual implementation and verification status. Features described in technical documents are not necessarily production-verified.

## Build and run

For development on macOS or Linux, install GNU Emacs and run:

```sh
./scripts/glassmacs
```

For a standalone macOS application, use the prerequisites in the [macOS application guide](docs/macos-launcher.md), then run:

```sh
./scripts/build-macos-app
./scripts/validate-macos-app build/Glassmacs.app
```

The builder obtains a pinned upstream Cocoa Emacs bundle and verifies its checksum. The resulting `build/Glassmacs.app` can be launched locally or copied to `/Applications`. Development builds are unsigned by default; distribution signing, notarization and Gatekeeper validation are separate release tasks. Do not treat a local build as a signed public release.

For terminal Emacs use `./scripts/glassmacs -nw`. File paths may be passed as arguments. `GLASSMACS_EMACS` selects an alternative Emacs executable for development.

## R and research tools

R, ESS, Quarto, TeX/AUCTeX and other research tools are optional and are not all bundled. Plain-text editing does not require them. To install optional Emacs packages in a development checkout:

```sh
./scripts/bootstrap
```

In the macOS app, use **Glassmacs → Install R & Document Packages…**. Package installation requires consent and network access; normal startup does not automatically refresh package archives. Install external tools such as R, Quarto and TeX separately as needed. See [R workflows](docs/r-workflows.md) for setup and usage.

Glassmacs stores application state under `~/Library/Application Support/Glassmacs` and uses `~/.config/glassmacs` for the development launcher. Set `GLASSMACS_HOME` to override the location. It does not use your ordinary Emacs or Aquamacs preferences by default.

## Keyboard and window behavior

Glassmacs supports a hybrid Aquamacs/macOS keyboard profile and traditional Emacs bindings. Native menu shortcut labels are designed to follow the active profile. Document-opening policies can prefer separate frames, tabs or reuse of the current frame. Details and verified behavior are tracked in the [acceptance matrix](docs/acceptance-matrix.md); native behavior should be assessed on a local Mac.

## Known limitations and verification

Glassmacs remains a development project. Interactive macOS behavior—including document/window focus, multiple R consoles, R help placement, crash recovery and native menu interactions—requires local testing. Recovery prototypes should not be relied on as the sole protection against data loss. Signed release testing, notarization and clean-machine acceptance are distinct from CI.

GitHub Actions runs Emacs batch tests, ESS/R integration checks and macOS application build/packaging checks. **GUI acceptance is intentionally local**, performed by maintainers or a local testing assistant. See [Contributing](CONTRIBUTING.md) for the development workflow.

## Documentation

Start with the [documentation index](docs/README.md). Key references include the [macOS application guide](docs/macos-launcher.md), [R workflows](docs/r-workflows.md), [architecture](docs/architecture.md), [acceptance matrix](docs/acceptance-matrix.md) and [documentation standard](docs/governance/documentation-standard.md).

The project uses stable `DOC-*` document identifiers and requirement IDs recorded in the acceptance matrix. Documentation metadata, status and reference rules are described in the [documentation standard](docs/governance/documentation-standard.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for branch, PR, CI and local macOS acceptance expectations. Development changes should keep their associated documentation current. Glassmacs is built on GNU Emacs and upstream packages; consult the repository's licensing files before redistributing a build.
