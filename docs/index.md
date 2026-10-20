# Documentation index and authority register

> **Document ID:** DOC-INDEX  
> **Status:** Canonical documentation governance  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-19  
> **Coverage:** Documentation authority, status, ownership and navigation  
> **Supersedes:** None

This is the **canonical index** for maintained project documentation. If a document's authority or scope is unclear, this register governs. Architecture documents describe intended design, **not proof of implementation**; source code and verified tests establish actual behavior.

## Authority register

| Document | ID | Authority / status | Canonical coverage | Exclusions |
| --- | --- | --- | --- | --- |
| [README](../README.md) | DOC-README | Canonical for project identity | Vision, intended audience, high-level feature promises, getting started | Detailed design, delivery schedule |
| [Architecture](architecture.md) | DOC-ARCH | Canonical for target design | Invariants, boundaries, security, execution and integration contracts | Proof features are implemented, milestone status |
| [Aquamacs compatibility inventory](aquamacs-compatibility.md) | DOC-AQUA-COMPAT | Proposed, target for canonical after review | Historical feature inventory, window defaults, settings parity and acceptance contracts | General execution architecture, current implementation proof |
| [Menu architecture](menu-architecture.md) | DOC-MENU | Proposed, target for canonical after review | Menu taxonomy, command/capability mappings and dynamic menu state | Keyboard binding authority, feature parity status |
| [Roadmap](roadmap.md) | DOC-ROADMAP | Canonical for planned delivery | Milestones, priorities, acceptance criteria, dependencies | Actual implemented state without verification |
| [Development](development.md) | DOC-DEV | Canonical for contributor workflow | Build, tests, CI and verification procedures | Product vision, architecture decisions |
| [R workflows](r-workflows.md) | DOC-R-WORKFLOWS | Canonical for documented user workflows | Available R/document commands and explicitly labeled proposed workflows | General architecture decisions |
| [Keybindings](keybindings.md) | DOC-KEYS | Canonical for keyboard profile | Implemented shortcuts and documented intended mappings | General macOS architecture |
| [Documentation change register](documentation-changelog.md) | DOC-CHANGELOG | Canonical historical register | Changes to document scope, authority, status, ownership, splits, mergers and supersession | Complete code change history |
| [Documentation governance](documentation-governance.md) | DOC-GOV | Canonical policy | Metadata requirements, precedence, lifecycle, review and update procedure | Individual feature specifications |

The two new proposed documents are review candidates on the documentation PR. Once accepted, update their status to Canonical and register their scopes as binding. The proposed inventory records a **new Mac graphical-window default** for ordinary new documents; the architecture and roadmap must incorporate it before implementation.

If the same subject appears in several documents, the **canonical coverage column** determines authority. Other documents should summarize and link to it, not establish conflicting requirements. Proposed ADRs under `docs/adr/` become canonical for their *specific accepted decision* only after being marked Accepted and linked here; an accepted ADR supersedes inconsistent architecture prose until the architecture is reconciled.

## Status vocabulary

- **Canonical:** authoritative within its listed scope, regardless of whether features described are implemented.
- **Proposed:** draft for review; not binding until accepted/merged and registered.
- **Informational:** explanation, example or background; not authoritative.
- **Deprecated:** still accessible but should not guide new work.
- **Superseded:** replaced by a linked successor; retained only for historical context.
- **Archived:** historical record, no longer maintained.

**Implementation labels** are separate: *implemented and verified*, *implemented but unverified*, *partially implemented*, *planned*, or *not supported*. Never substitute document status for implementation status.

## Precedence and conflict handling

1. Actual repository code and reproducible tests establish **what currently works**; documents may describe intended behavior but must label it.
2. For intended product direction, the README owns identity, the architecture owns technical constraints, and the roadmap owns delivery priority.
3. Accepted ADRs control their narrowly defined decision; update architecture and the index promptly.
4. A conflict between two canonical documents is a documentation defect: open an issue/PR, identify the owner, and reconcile it. Do not silently choose the newer-looking file.
5. Git history is the exact source for line-by-line edits; the change register explains changes in **coverage and authority**, not every typo.

## Maintenance

See [documentation governance](documentation-governance.md) for the required PR checklist and [documentation change register](documentation-changelog.md) for dated scope changes. Dates use ISO 8601 `YYYY-MM-DD`; dates represent an editorial update, not automatic verification of technical claims.
