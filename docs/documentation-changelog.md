# Documentation coverage and authority change register

> **Document ID:** DOC-CHANGELOG  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-19  
> **Coverage:** Dated history of documentation authority and coverage changes  
> **Supersedes:** None

This log records changes in document **scope, ownership, status and authority**. It is not a substitute for Git history or a complete changelog of prose edits.

## 2026-10-19 — Documentation governance baseline (PR #2)

- **Created DOC-INDEX:** central canonical authority and scope register; previously no explicit precedence map existed.
- **Created DOC-GOV:** metadata, status, change-control and review policy.
- **Created DOC-CHANGELOG:** dated record of documentation coverage changes.
- **Registered DOC-README, DOC-ARCH, DOC-ROADMAP, DOC-DEV, DOC-R-WORKFLOWS and DOC-KEYS:** assigned canonical coverage and accountable maintainer group.
- **Expanded DOC-ARCH coverage:** execution/SSH/Mosh, output flooding, editable R execution queue, plain-text and large-file safety, LaTeX/PDF, AI agents, research application profiles and polyglot research-user positioning. These are target requirements, not claims of implementation.
- **Established DOC-ROADMAP as delivery authority:** milestone and acceptance-criteria planning separated from architectural requirements and current feature documentation.
- **Clarified DOC-R-WORKFLOWS:** existing commands versus planned research workflows must be explicitly distinguished.
- **Precedence:** the README controls vision; architecture controls target technical design; roadmap controls delivery planning; code/tests control actual implemented behavior. No documents superseded in this baseline.

Future entries should state date, affected document IDs, old/new coverage or authority, rationale, successor (if any), and associated PR/ADR.
