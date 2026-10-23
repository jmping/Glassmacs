# Aquamacs historical regression inventory

> **Document ID:** DOC-AQUA-REGRESSION  
> **Status:** Proposed  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-23  
> **Last reviewed:** 2026-10-23  
> **Coverage:** Sources, methodology, classification and prioritized regression plan derived from the Aquamacs issue history  
> **Supersedes:** None

This is a discovery and test-design document. **No tests or production code are added by it.** It does not block the 0.1.0 release, PR #18 or CI work. The behavior Glassmacs promises is controlled by [DOC-AQUA-COMPAT](aquamacs-compatibility.md), [keybindings](keybindings.md) and [architecture](architecture.md); this document only decides which historical failures deserve a regression test.

Machine-readable data lives in `tests/historical/inventory/`:

| File | Content |
|---|---|
| `sources.json` | Source inventory (location, coverage, accessibility, limitations) |
| `aquamacs-issues.json` | 231 records, one per Aquamacs issue, original id preserved as `aquamacs-emacs#N` |
| `regression-map.json` | 25 proposed regression tests (`RT-001`…`RT-025`) mapped to issue ids |

## 1. Source inventory

| ID | Source | Coverage | Access | Limitations |
|---|---|---|---|---|
| SRC-01 | [GitHub issues, aquamacs-emacs/aquamacs-emacs](https://github.com/aquamacs-emacs/aquamacs-emacs/issues) | 2009-04 to 2026-10; 231 issues, 37 PRs, 67 open | Public API, fully mined | Pre-2013 issues are mostly forwarded mailing-list reports; many resolutions exist only as comment text (18 issues link commits); numbering gaps are PRs |
| SRC-02 | Source branches (aquamacs3, aquamacs4, aquamacs-4-dev, master, emacs-24/25) | 2008–2026 | Public | Commit messages were not mined beyond issue-linked commits |
| SRC-03 | `CHANGELOG.Aquamacs.tex` (917 items, 0.9.3 to 3.6.1) | Release notes | Public | No issue ids; not individually cross-linked yet |
| SRC-04 | `BUGS`, `ChangeLog.1/.2` | Inherited from GNU Emacs | Public | Not mined |
| SRC-05 | Launchpad `bugs.launchpad.net/aquamacs` | n/a | Public | Bug tracking disabled, zero bugs |
| SRC-06 | `aquamacs-bugs` / `aquamacs-devel` mailing lists (Gmane, Google Groups, SourceForge era) | ~2008–2013 | **Not retrieved** | Wayback API was offline; originals of forwarded reports likely live here. Open follow-up |
| SRC-07 | `aquamacs.org/bugs` | unknown | 404 | Unavailable |
| SRC-08 | GNU Emacs debbugs | Upstream | Public | Only ids cited by Aquamacs records (e.g. 26323, 34762, 26982, 38618) are recorded; not independently verified |
| SRC-09 | Aquamacs automated tests | none | n/a | No Aquamacs-specific tests exist (issue #198 requests one); `test/automated` is upstream Emacs |

GitHub is therefore **not** the complete historical record; SRC-06 is the largest known gap.

## 2. Methodology and confidence

1. Every issue, its comments and its closing events were fetched (SRC-01) and normalized into one record.
2. Subsystem, severity and class were assigned by a script (group tables plus per-issue overrides) from the **title, an opening excerpt and the last comment**. Records carry `triage_basis` saying so; **no full-thread review was done**, and every classification has `classification_status: "triage-hypothesis"`.
3. `documented_resolution` quotes the record only. `root_cause` is filled only when a maintainer states it; otherwise it is empty. Nothing is inferred.
4. `glassmacs_potentially_affected` is always a **hypothesis**: Glassmacs does not share Aquamacs's Lisp, so an Aquamacs fix does not prove a Glassmacs exposure.
5. Each of the 25 proposed tests lists the original issue ids, so a future test traces back to its source.

**Confirmed** (from the record): issue existence, dates, labels, state, quoted maintainer statements, linked commits, cited GNU Emacs bug numbers. **Hypotheses**: severity, subsystem, class, Glassmacs exposure, proposed tests.

## 3. Classification

| Class | Meaning | Count |
|---|---|---|
| A | Relevant; automatable Glassmacs regression test | 41 |
| B | Relevant; needs macOS GUI or physical acceptance | 66 |
| C | Handled upstream; verify only | 19 |
| D | Obsolete (Aquamacs-only build, distribution, tabbar, AUCTeX bundling, ODB…) | 81 |
| E | Not applicable; Glassmacs differs on purpose (smart-spacing, autoface, one-buffer-per-frame, CLI tools install…) | 16 |
| F | Insufficient evidence; investigate | 8 |

Priority counts: P0 7, P1 48, P2 52, verify 19, investigate 8, none 97. Priorities favor data safety, ordinary editing, application lifecycle, documents/windows, menus, keyboard, clipboard, Unicode and ESS/R.

## 4. Proposed suite layout

```
tests/historical/                 ERT regressions: test-historical-*.el
tests/historical/inventory/       JSON inventory and mapping (this PR)
tests/macos/                      Cocoa/bundle tests and ACCEPTANCE.md checklist
tests/fixtures/historical/         minimal reproduction files
docs/aquamacs-regression-inventory.md
```

Prefer extending `tests/test-glassmacs.el`, `-sessions.el`, `-r-ui.el` and `-remote.el` where a test fits existing coverage. New files must be added to the explicit `-l` list in `scripts/test` and to the CI ERT steps (not changed in this phase). Tests validate Glassmacs behavior, not Aquamacs internals, and do not copy upstream GNU Emacs tests.

Every test carries a header (or docstring) with:

```
Historical-ID: aquamacs-emacs#N [, …]    ; RT-nnn
Failure:       user-visible failure prevented
Promise:       Glassmacs behavior promised (DOC-AQUA-COMPAT id)
Expected:      concrete expected result
Environment:   batch | real R/ESS | macOS GUI | bundle; skip conditions
```

## 5. Prioritized regression matrix

Effort: S < ½ day, M ½–2 days, L > 2 days. Full details (failure, promise, expected result, environment, existing coverage, evidence note) are in `regression-map.json`.

| RT | Regression | Historical issues | Class | Pri | Effort | Timing |
|---|---|---|---|---|---|---|
| RT-001 | Open/New document with no visible frame | #270, #219, #22, #85, #55 | A+B | P0 | S | **Before** (batch 1) |
| RT-002 | `save-some-buffers` accepts `!` | #16 | A | P0 | S | **Before** (batch 1) |
| RT-003 | Unsaved new documents never silently discarded | #158, #17 | A | P0 | M | **Before** (batch 1) |
| RT-012 | Native crash and dialog checklist | #160, #218, #168, #222, #59, #255, #229, #83 | B | P0 | S | **Before** (batch 1, manual) |
| RT-004 | Unwritable or missing `GLASSMACS_HOME` | #52, #99 | A | P1 | M | **Before** (batch 1) |
| RT-005 | Customize persists to isolated `custom.el` | #246, #6, #48 | A | P1 | M | **Before** (batch 1) |
| RT-008 | Keyboard binding invariants | #45, #68, #101, #28, #76 | A | P1 | S | **Before** (batch 1) |
| RT-009 | Unicode round trip through R/ESS | #53, #132 | A | P1 | M | **Before** (batch 1) |
| RT-011 | Open-file and drag-and-drop honour policy | #39, #84 | A | P1 | S | **Before** (batch 1) |
| RT-006 | Initial frame visible when startup prompts | #147 | A+B | P1 | M | Before (cheap assertion) |
| RT-010 | Clipboard round trip with external apps | #47 | B | P1 | M | Before (manual) |
| RT-013 | Menu bar with R and TRAMP buffers | #180, #196, #235 | B | P1 | S | Before (manual) |
| RT-018 | Option-as-Meta vs composed characters | #43, #233, #58 | A | P1 | M | Before (confirm KEY-002 first) |
| RT-007 | Auto-revert never clobbers modified buffers | #245 | A | P1 | M | After |
| RT-014 | TRAMP file as first document | #103 | A | P1 | M | After |
| RT-015 | emacsclient / server opening | #102, #60, #247, #249, #144 | A | P1 | M | After |
| RT-016 | Frame cycling, `delete-other-windows` | #37, #38, #46, #54 | A | P2 | M | After |
| RT-017 | File locks and removable volumes | #96 | A | P2 | S | After |
| RT-019 | TLS trust and package signatures in bundle | #133, #205, #166 | A | P2 | S | After |
| RT-020 | Session restore without duplicate frames | #81, #13 | A | P2 | M | After |
| RT-021 | Full-screen behavior | #2, #5, #11, #66, #62, #24 | B | P2 | S | After |
| RT-022 | Spell-check fails clearly | #34, #35, #36, #265 | B | P2 | S | After |
| RT-023 | XML comment hang (Emacs version guard) | #93, #231, #107 | C | P2 | S | After |
| RT-024 | Info/Lisp navigation in bundle | #9, #8, #123, #124 | A | P2 | S | After |
| RT-025 | Display smoke checklist | #23, #97, #104, #105, #41 | B | P2 | S | After |

Existing coverage already overlaps RT-001, RT-008, RT-011, RT-013 and RT-014 (see `existing_coverage` in the map); those extend existing tests rather than add new ones. Verified gaps by grep: save-some-buffers, buffer-offer-save, modifier variables, `other-frame`, clipboard, server/emacsclient, auto-revert, locks, and non-ASCII test content.

## 6. Recommended initial batch (for review; before 0.1.0)

Nine items, about 4–6 days total, nearly all batch ERT with no new dependencies:

1. RT-001 no-frame open/new document (extend existing lifecycle tests; top item, tied to open aquamacs-emacs#270).
2. RT-002 `save-some-buffers` `!`.
3. RT-003 unsaved new-document prompts.
4. RT-004 unwritable `GLASSMACS_HOME`.
5. RT-005 Customize persistence.
6. RT-008 keyboard invariants.
7. RT-009 Unicode through ESS/R (runs in the real-R CI job only).
8. RT-011 open-event and drag-and-drop policy.
9. RT-012 manual `tests/macos/ACCEPTANCE.md` checklist (also holds RT-010, RT-013, RT-021 steps).

## 7. Roadmap

1. **Review** this inventory and the batch (this step).
2. **Batch 1**: add `tests/historical/` files, wire into `scripts/test` and CI, update `docs/development.md`.
3. **Pre-release acceptance**: run the manual checklist on Apple Silicon and Intel.
4. **After 0.1.0**: remaining RT items by priority; retrieve SRC-06 and resolve the 8 class F issues.
5. **Maintenance**: regenerate or hand-edit the JSON when new Aquamacs issues appear; promote `triage-hypothesis` classifications after full-thread review.

## 8. Exclusions and open questions

- Class D (81) and E (16) issues get no tests; E items are intentional differences.
- Class C items get at most a version-guard smoke test, never a copy of upstream tests.
- Whether the Glassmacs bundle ships `emacsclient` is unknown (RT-015).
- KEY-002 and the Option-as-Meta default need a documented decision before RT-018.
- Records dated 2026 (e.g. #270) come from Aquamacs 4 alpha against macOS versions newer than those Glassmacs CI covers.
