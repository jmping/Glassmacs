# Glassmacs documentation

> **Document ID:** DOC-INDEX  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Last reviewed:** 2026-11-06  
> **Coverage:** Documentation navigation and source-of-truth conventions  
> **Supersedes:** None

This index is the entry point for Glassmacs documentation. The [project README](../README.md) is the public-facing overview; detailed instructions and implementation evidence belong in the documents below.

## Start here

- [Project overview and development build](../README.md) — what Glassmacs is and how to build it.
- [macOS application guide](macos-launcher.md) — app packaging, launch and platform requirements.
- [R workflows](r-workflows.md) — R, ESS and research integrations.
- [Architecture](architecture.md) — implementation and component boundaries.
- [Acceptance matrix](acceptance-matrix.md) — requirements, tests and verification status.
- [Contributing](../CONTRIBUTING.md) — development and review process.
- [Documentation standard](governance/documentation-standard.md) — document IDs, lifecycle and references.

## Source-of-truth rules

- The README introduces the project; specialized guides own detailed instructions.
- A canonical document is authoritative for its subject, **not** proof that every described feature has shipped.
- The acceptance matrix records implementation and verification status separately.
- GUI acceptance runs locally on a Mac, not in GitHub Actions.
- Historical checkpoints should be archived, not presented as current release status.
- The [registry](registry.toml) records document identity and location. Preserve IDs across renames.
