# Documentation governance policy

> **Document ID:** DOC-GOV  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-19  
> **Coverage:** Documentation lifecycle, metadata and review policy  
> **Supersedes:** None

The [documentation index](index.md) is the sole authority register. This policy defines how documents are created, updated and retired.

## Required metadata

Every maintained Markdown document, including the README, starts with a title followed by a compact metadata block:

- **Document ID:** stable identifier registered in the index
- **Status:** Canonical, Proposed, Informational, Deprecated, Superseded or Archived
- **Owner:** person or maintainer group accountable for scope
- **Effective date:** date the current document was first adopted, not the date of every edit
- **Last reviewed:** date of substantive editorial review
- **Coverage:** one-sentence statement of what the document controls
- **Supersedes:** document IDs or None; for superseded files include **Superseded by**

Use ISO 8601 dates. Avoid pretending a historical file was reviewed earlier than the first governance pass; the initial date is a baseline for this PR, not the original creation date.

## Change procedure

1. Identify the canonical document from [the index](index.md) before editing; change that document first.
2. Update its `Last reviewed` date for a substantive review, and update its coverage line if scope changes.
3. Update dependent summaries/links in other documents without duplicating authority.
4. If a document is added, split, merged, renamed, deprecated, superseded, changes owner, or gains/loses canonical coverage, **update the index and append a dated entry to the [change register](documentation-changelog.md) in the same PR**.
5. For routine edits within unchanged coverage, Git history and the PR description suffice; a change-register entry is optional.
6. Explicitly mark implementation status and validation evidence. Planned architecture is not a claim of shipped functionality.
7. Run a link/metadata consistency check (initially manual) and include a documentation impact statement in the PR description.

## Documentation impact checklist for PRs

- [ ] Canonical document identified and updated
- [ ] Document metadata and review dates correct
- [ ] Scope/authority change recorded in index and change register, if applicable
- [ ] Related documents link to the canonical source rather than conflicting with it
- [ ] Planned vs implemented claims distinguished; tests/evidence linked when asserting implementation
- [ ] No broken relative links or orphaned documents
- [ ] Superseded material points to the successor

## ADR lifecycle

Use `docs/adr/NNNN-short-title.md` for decisions with lasting architectural consequences. Proposed ADRs are noncanonical. When accepted, record status, date, rationale, alternatives, consequences and superseded decisions; add the ADR to the index. Keep old ADRs for traceability, clearly marking Superseded when replaced.

## Release and implementation reporting

The roadmap is a plan. A milestone is completed only when linked PRs and applicable tests support it. Do not automatically update status merely because a target date passed. Feature claims in the README and user workflows must be qualified when they are planned or experimental.

