# Documentation index and authority register

> **Document ID:** DOC-INDEX  
> **Status:** Canonical documentation governance  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-29
> **Coverage:** Documentation authority, status, ownership and navigation  
> **Supersedes:** None

This is the **canonical index** for maintained project documentation. The short [navigation page](README.md) is not a second authority register; the [machine-readable registry](registry.toml) is a validated subset of this index. If a document's authority or scope is unclear, this register governs. Architecture documents describe intended design, **not proof of implementation**; source code and verified tests establish actual behavior.

## Comparative audit (informational)

[Menu parity and deliberate differences](aquamacs-menu-parity-audit.md) and [historical Aquamacs issue regression candidates](aquamacs-historical-issues-audit.md) records the first source-oriented comparison of Aquamacs and Glassmacs, with gaps and GUI acceptance tasks. It does not replace the canonical behavioral inventory or menu architecture, and the historical issue audit remains a separate follow-up.

## Authority register

| Document | ID | Authority / status | Canonical coverage | Exclusions |
| --- | --- | --- | --- | --- |
| [Documentation navigation](README.md) | DOC-NAV | Informational | Short navigation into the canonical index and guides | Authority and lifecycle policy |\n| [Contributing](../CONTRIBUTING.md) | DOC-CONTRIB | Canonical for contribution process | Branch, PR, CI and local GUI acceptance workflow | Detailed build commands |\n| [Reference conventions](governance/documentation-standard.md) | DOC-STANDARDS | Canonical supplement | Registry, link and traceability conventions | DOC-GOV lifecycle policy |\n| [README](../README.md) | DOC-README | Canonical for project identity | Vision, intended audience, high-level feature promises, getting started | Detailed design, delivery schedule |
| [Architecture](architecture.md) | DOC-ARCH | Canonical for target design | Invariants, boundaries, lifecycle/document abstractions, security, execution and integration contracts | Proof features are implemented, milestone status |
| [Aquamacs compatibility inventory](aquamacs-compatibility.md) | DOC-AQUA-COMPAT | Proposed, target for canonical after review | Source-traced feature matrix, dispositions, implementation status, priorities and acceptance tests | General execution architecture, menu taxonomy, proof of current implementation |
| [Menu architecture](menu-architecture.md) | DOC-MENU | Proposed, target for canonical after review | Historical menu inventory, proposed taxonomy, Emacs command dispatch, context/state, extensions and menu test strategy | Keyboard binding authority, per-feature parity status |
| [Roadmap](roadmap.md) | DOC-ROADMAP | Canonical for planned delivery | Milestones, priorities, acceptance criteria, dependencies | Actual implemented state without verification |
| [Development](development.md) | DOC-DEV | Canonical for contributor workflow | Build, tests, CI and verification procedures | Product vision, architecture decisions |
| [macOS application](macos-launcher.md) | DOC-MAC-LAUNCHER | Informational | Standalone Cocoa app build, installation, configuration, and GUI verification limits | Emacs/Lisp workflow authority, proof of GUI behavior |
| [R workflows](r-workflows.md) | DOC-R-WORKFLOWS | Canonical for documented user workflows | Available R/document commands and explicitly labeled proposed workflows | General architecture decisions |
| [Keybindings](keybindings.md) | DOC-KEYS | Canonical for keyboard profile | Implemented shortcuts, conflicts, Option/Meta and left/right international modifier behavior | General macOS architecture, feature parity status |
| [Aquamacs 4 modern macOS risk audit](aquamacs4-modern-macos-risk-audit.md) | DOC-AQUA4-AUDIT | Informational | Source-traced evidence for the Aquamacs 4 reports in issue #34 and upstream fixes missing from the bundled Emacs | Test status (see the acceptance matrix) |
| [Acceptance matrix](acceptance-matrix.md) | DOC-ACCEPT | Canonical for acceptance status (generated from `acceptance/matrix.toml`) | Every acceptance risk, its evidence and tests, and its implemented / automated / packaged-app / clean-machine status | Feature specifications, delivery schedule |
| [macOS manual acceptance checklist](macos-acceptance-checklist.md) | DOC-MAC-CHECKLIST | Canonical procedure (generated from `acceptance/matrix.toml`) | Manual (Layer D) checks on a physical or clean Mac and how to record them | Automated checks, which the matrix lists |
| [Documentation change register](documentation-changelog.md) | DOC-CHANGELOG | Canonical historical register | Changes to document scope, authority, status, ownership, splits, mergers and supersession | Complete code change history |
| [Documentation governance](documentation-governance.md) | DOC-GOV | Canonical policy | Metadata requirements, precedence, lifecycle, review and update procedure | Individual feature specifications |

The two proposed Aquamacs documents are review candidates on the documentation PR. Once accepted, update their status to Canonical and register their scopes as binding. The proposed inventory records a **new Mac graphical-window default** for ordinary new documents; architecture now records the required abstractions and the roadmap remains the delivery authority. These specifications are not proof of implementation.

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

### Linked presentation architecture (proposed)

- [Linked presentation design](linked-presentation-architecture.md) — DOC-LINKED-PRESENTATIONS; proposed architecture, informational, not runtime policy.
- [Phase 0 baseline](linked-presentation-phase0.md) — DOC-LINKED-PHASE0; reported GUI evidence and non-regression contract, informational.
- [Phase 1 source audit](linked-presentation-phase1-audit.md) — DOC-LINKED-PHASE1; static call-path inventory, informational.

These documents are subordinate to the existing canonical architecture and acceptance authorities until formally promoted.

- [Integration execution plan](linked-presentation-execution-plan.md) — DOC-LINKED-EXECUTION-PLAN; active PR #98 stage sequence, verification gates and progress ledger; informational until promoted.
