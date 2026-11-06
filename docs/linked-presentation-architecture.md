# Linked presentation architecture — design proposal

Document ID: DOC-LINKED-PRESENTATIONS
Status: Proposed; no runtime behavior changed
Last reviewed: 2026-11-06

## Purpose and constraints

Glassmacs is a working Emacs-based macOS editor with specific remaining windowing defects. This proposal must not trigger a broad rewrite. Existing document opening, tabbing, ESS execution, help, recovery, close handling, menus, and terminal behavior are compatibility requirements.

**Core contract:** Glassmacs manages *linked presentations*, not exclusive frame ownership. Emacs remains authoritative for live buffer/window/frame state. A logical object may have zero, one, or many presentations. Closing a presentation must not implicitly destroy a document, buffer, or process; explicit close/quit policies continue to apply.

## Distinct concepts

- **Object:** document, R session, help topic, or other logical entity; R session identity is already maintained by the session registry.
- **Buffer:** Emacs content/process-buffer representation; not equivalent to an object or a window.
- **Presentation:** a live view of a buffer in an Emacs window, tab, or native frame; derive actual visibility from Emacs rather than maintaining a parallel window database.
- **Link:** a semantic association, such as document targets session, console belongs to session, or preferred presentation. Links do not imply exclusive ownership or object lifetime.

## Operations and intent

Creation, presentation, focus, new view, move, explicit split, explicit tab, replace, and termination must remain distinct. In particular:

| Operation | Contract |
| --- | --- |
| New document | Create document buffer, then present using document policy |
| Open existing document | Prefer suitable existing view; do not duplicate by accident |
| New R console | Create independent R process/session and buffer, then present |
| Show R console | Present existing console; never create another R process |
| Switch R session | Change selected execution target; do not silently move views |
| New view | Create an additional view of the same buffer |
| Move view | Relocate a presentation without killing its buffer |
| Close view | Follow explicit document/console lifecycle policy; never equate hiding a console with terminating R |

An existing visible buffer is not automatically a *suitable* presentation. Suitability must account for role, intent, policy, explicit user layout decisions, and source-view preservation. Conversely, a deliberate user-created split must not be silently undone by a background presentation rule.

## Policy

Preserve existing `glassmacs-document-opening-policy` and other existing settings during migration. Proposed eventual user profiles: native windows, native tabs, classic Emacs layout. Profiles are defaults, not prohibitions on explicit moves/splits. Headless/terminal operation retains ordinary Emacs behavior.

Potential read-only APIs, **not yet implemented**:
- `glassmacs-buffer-role BUFFER`: classify document, console, help, preferences, utility, transient, internal; use explicit metadata/session registry and modes ahead of names.
- `glassmacs-presentation-suitable-p BUFFER WINDOW INTENT POLICY`: evaluate suitability without side effects.
- `glassmacs-resolve-presentation BUFFER INTENT CONTEXT`: compute a decision without displaying anything.

The existing `glassmacs-present-buffer` and `glassmacs-buffer-placement--display` remain the implementation seams. Do not create a competing presentation framework or registry.

## Integration boundaries

Do **not** globally redefine/advise `display-buffer`, `switch-to-buffer`, `pop-to-buffer`, `set-window-buffer`, `delete-window`, or `delete-frame`. Prefer supported `display-buffer-alist` actions for eligible buffer classes, existing Glassmacs interactive commands, and targeted package lifecycle integration where a package bypasses display rules. Minibuffers and internal package buffers must remain unaffected.

ESS may synchronously display an inferior buffer before returning. PR #96 addresses that specific post-startup placement seam; do not assume it is merged or GUI-verified. Session creation and console presentation are independent, and must be tested separately.

## Migration plan and gates

0. **Baseline (current phase):** document current pass/fail/unverified evidence, establish non-regression contract and a repeatable acceptance checklist. No runtime changes.
1. **Source audit:** inventory actual call paths, classification and policy decision points, direct display calls, frame reuse, lifecycle and test coverage. Do not label every direct Emacs display call a defect.
2. **Read-only roles:** add a classifier with headless tests and no startup side effects.
3. **Suitability checks:** test existing view vs appropriate view, explicit user layouts, stale frames/tabs; initially observe only.
4. **Policy resolver:** preserve behavior exactly; compare decisions with existing code before enabling.
5. **Incremental integration:** migrate one entry point at a time, gated by ERT and native GUI evidence.
6. **Optional preferred links:** store minimal, validated nonpersistent hints, not a second frame/window database.
7. **Preferences/menus:** consolidate only after semantics and compatibility are verified.
8. **Recovery:** separately design serializable relationships; never persist raw frame objects or claim to restore R process state from a window snapshot.

Each phase requires a focused PR, no automatic merge, a rollback path, and separate reporting for automated and packaged macOS GUI acceptance. Avoid simultaneous edits to the independent project-aware execution worktree.

## Invariants

1. No primary document silently replaced by starting R, opening help, recovery, or navigation.
2. No loss of modified document content; close/cancel semantics preserved.
3. No R process terminated merely by relocating/hiding a console.
4. Independent R sessions remain independently targetable.
5. Reusing a view does not duplicate frames; creating a new view does not create a new session.
6. Explicit tab/split/move commands take precedence over defaults.
7. Existing help, document tabs, and recovery behavior remain working.
8. Terminal and package-internal Emacs semantics remain intact.
9. All GUI claims identify actual build SHA and observation method.

## Evidence and references

- `docs/window-presentation-audit.md` records earlier PR #84 inventory and release gates; its historical status must not be mistaken for current verification.
- `docs/linked-presentation-phase0.md` is the Phase 0 evidence ledger and test contract.
- `docs/acceptance-matrix.md` is generated from `acceptance/matrix.toml`; do not hand-edit generated acceptance files.

## Approved R console interaction contract (2026-11-06)

The source toolbar **Console** button means **New R Console**, always: each activation starts a distinct ESS/R process, registers a distinct session and presents it. It must never silently focus an existing console. A separate **Link Console** button chooses an existing live session and associates it with the current source document (including its polymode/indirect buffers), without creating a process or moving an unrelated view.

For source execution, an explicit live document-to-session link is authoritative. If no link exists, **prompt the user to choose a live R console before sending code**, even if exactly one live console exists. The selected console becomes the document's explicit link so subsequent sends do not reprompt. If there are no live consoles, do not execute code or silently create a process: show a clear instruction to create one. A stale link must not fall through to another live session; request an explicit new selection. Cancel must not send code or alter the link. The link is document-scoped, not frame-scoped, and survives opening another view of the same document.

This supersedes the current implicit-single-session and ESS-local-process fallback behavior **for user-initiated source execution**; it is an intentional change, not a description of the current implementation. Preserve batch/noninteractive deterministic failure rather than prompting. Audit non-source console commands and explicit one-off sends separately so they do not acquire unwanted prompts.

Implementation should reuse `glassmacs-r-new-console`, `glassmacs-r-select-session`, `glassmacs-r--set-document-target`, and the existing session registry. Distinguish **Link Console** from **Show Console** (focus an existing view) and **New View** (additional presentation). Update existing toolbar tests and add explicit new/link/execution routing tests when the change is implemented in a dedicated runtime PR, not the documentation-only Phase 1 branch.
