# Documentation and reference standard

> **Document ID:** DOC-STANDARDS  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Last reviewed:** 2026-11-06  
> **Coverage:** Document organization, identifiers, references and lifecycle  
> **Supersedes:** None

## Organization

The repository root contains the public README, CONTRIBUTING and other repository-wide files. `docs/README.md` is the documentation index. As documents are revised, use `docs/user/` for user instructions, `docs/development/` for contributor/build guidance, `docs/specifications/` for behavior contracts, `docs/governance/` for process and standards, and `docs/archive/` for historical material.

Do not move existing documents solely to satisfy the directory layout without updating their links and generated-document paths. Existing links and build tooling take priority during migration.

## Identity and metadata

Each substantive document has a unique, permanent `DOC-*` identifier. IDs are never reassigned or derived from file paths. Use the metadata fields Document ID, Status, Owner, Last reviewed, Coverage and Supersedes. Valid lifecycle statuses are **Draft**, **Canonical**, **Superseded** and **Archived**. A superseded document must name its successor. Update Last reviewed only after substantive review.

Register canonical documents in `docs/registry.toml`; the registry is the source of truth for identifiers and paths. The index provides human-readable navigation.

## References

Use relative Markdown links for repository documents, with readable titles. Cite requirement IDs (for example `KEY-003`) consistently with `acceptance/matrix.toml`. Cite source paths, test names, issues and PRs where implementation claims require evidence. Distinguish planned, implemented, automated, locally observed and release-verified behavior. Never infer GUI acceptance from a passing CI build.

## Change control

Update affected canonical docs in the same PR as behavioral changes. Generated documents must be changed through their generators and validated with their existing checks. Historical material should be marked archived and linked to current guidance, not silently rewritten as if it were current. Avoid duplicating normative instructions across documents.

## Validation

Documentation changes must preserve registry uniqueness, registered paths and IDs, internal links, and generated-document consistency. The existing `scripts/acceptance-matrix check` remains authoritative for its generated acceptance documents. GUI tests remain local.
