# Contributing to Glassmacs

> **Document ID:** DOC-CONTRIB  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Last reviewed:** 2026-11-06  
> **Coverage:** Contributions, review and validation  
> **Supersedes:** None

Glassmacs combines upstream Cocoa GNU Emacs with a macOS application wrapper and Emacs Lisp configuration. Changes should preserve upstream compatibility and avoid unnecessary Emacs-core forks.

## Workflow

1. Create a topic branch from `main` and keep changes focused.
2. Add or update automated tests for testable behavior.
3. Update the relevant canonical documentation and acceptance requirements when behavior changes.
4. Open a pull request describing the change, risks, automated checks and any local macOS validation.
5. Merge after review and applicable CI checks pass; use squash merges for focused changes.

## Automated checks

- `./scripts/test` runs Emacs Lisp tests.
- `./scripts/acceptance-matrix check` validates the generated acceptance documents and test references.
- GitHub Actions validates Emacs, ESS/R integration, macOS builds and packaging.

The CI workflow uses change-based job selection; branch protection should account for skipped jobs before making individual jobs required.

## Local macOS GUI acceptance

Native windows, menus, focus, keyboard shortcuts, dialogs, recovery and usability must be tested locally on a Mac by a maintainer or a local testing assistant. GitHub Actions does not run GUI acceptance. For GUI-affecting PRs, record the app build tested, scenarios exercised, observed results and outstanding limitations. Do not describe a build-only CI pass as GUI verification.

## Documentation

Start at the [documentation index](docs/README.md) and follow the [documentation standard](docs/governance/documentation-standard.md). Keep implemented functionality, experimental features and roadmap goals distinct. Do not commit machine-specific secrets, signing identities or private data.
