# Documentation reference and validation conventions

> **Document ID:** DOC-STANDARDS  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Last reviewed:** 2026-11-06  
> **Coverage:** Supplemental ID registry, link conventions and validation  
> **Supersedes:** None

This standard **supplements**, and does not replace, the existing [documentation governance policy](../documentation-governance.md) (**DOC-GOV**) and [canonical authority register](../index.md) (**DOC-INDEX**). Follow those documents for lifecycle states, metadata, ownership and precedence. Record authority changes in [DOC-CHANGELOG](../documentation-changelog.md).

## References and traceability

Use stable document IDs from DOC-INDEX, requirement IDs from `acceptance/matrix.toml`, and repository-relative Markdown links. IDs are never reused or changed when a file moves. Separate implemented, planned, automated, locally observed and release-verified claims. A green build is not native GUI acceptance.

## Registry and migration

`docs/registry.toml` is a machine-readable subset of the existing authority register for automated validation; it is **not** a second source of truth. Expand it incrementally after checking each document's current ID, metadata and status. Never create a duplicate document ID. Existing `docs/` paths remain stable until links, generators and cross-references can be migrated safely.

The validator checks registered document metadata and links. The generated acceptance documents remain governed by `scripts/acceptance-matrix render` and `scripts/acceptance-matrix check`.
