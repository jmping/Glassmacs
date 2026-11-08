# Glassmacs documentation

> **Document ID:** DOC-NAV  
> **Status:** Informational  
> **Owner:** Glassmacs maintainers  
> **Last reviewed:** 2026-11-06  
> **Coverage:** Documentation navigation  
> **Supersedes:** None

The existing [documentation index and authority register](index.md) (**DOC-INDEX**) remains the canonical source for document ownership, status and scope. The [documentation governance policy](documentation-governance.md) (**DOC-GOV**) defines lifecycle and metadata. The [documentation change register](documentation-changelog.md) (**DOC-CHANGELOG**) records authority changes. This page is a short navigation guide, not a second authority register.

## Getting started

- [Project README](../README.md) — overview, development status and build instructions.
- [macOS application](macos-launcher.md) — packaging, installation and platform requirements.
- [R workflows](r-workflows.md) — ESS and research tools.
- [Keybindings](keybindings.md) — keyboard profiles.
- [Architecture](architecture.md) — component boundaries and intended design.
- [Acceptance matrix](acceptance-matrix.md) — implementation and verification evidence.
- [Contributing](../CONTRIBUTING.md) — contributor workflow.
- [Development](development.md) — build and test details.

## Linked presentation integration (PR #98)

- [Implementation and verification record](linked-presentation-implementation-record.md) — completed source changes, runtime invariants, CI evidence and unresolved native GUI gates.
- [Copilot candidate handoff](copilot-candidate-handoff.md) — exact-SHA macOS build, packaged GUI harness, manual test matrix, candidate archive and evidence requirements.
- [Execution plan](linked-presentation-execution-plan.md) — stage history and integration constraints.

## Reference system

The [authority register](index.md) defines stable `DOC-*` IDs. The [machine-readable registry](registry.toml) supports automated identity/path checks but does not supersede the authority register. Use [governance](documentation-governance.md) for status and review conventions. GitHub CI tests code and packaging; native GUI acceptance is performed locally on a Mac.
