# Native multi-document quit review contract

The Glassmacs quit review presents **Save**, **Don't Save**, and **Cancel**
for the current modified document, with one checkbox:

> ☐ Apply this choice to all remaining modified documents

## Non-negotiable default

The checkbox **must be unchecked whenever any dialog opens**. This includes
the first dialog in a quit attempt, each subsequent document dialog, a new
quit attempt after cancellation, a quit attempt after an unsuccessful save,
and a quit attempt following a previous checked or unchecked selection.

- Never persist the checkbox value to Custom, preferences, defaults, recovery
  state, or disk.
- Never reuse the value from a previous dialog or previous quit attempt.
- A new dialog gets a freshly initialized false/unchecked value, even if
  an earlier dialog in the same quit attempt had the box checked.
- An explicit checked choice applies only to the remaining documents of
  **that one quit attempt**. It does not modify future defaults.
- Cancel aborts quitting, irrespective of checkbox state.
- Don't Save must not irreversibly discard unsaved changes until the quit
  operation is committed. A canceled or vetoed quit must preserve them.
- Save failures must stop the quit, keep the app open, and preserve unsaved
  document state.
- With no modified documents, no save review dialog is needed.

## UI and tests

Use a real native macOS checkbox, not an extra button or an emulated
multi-choice entry. A non-native/terminal fallback may use a clearly
described explicit scope question, but must also default to *current file*.

Acceptance tests must verify:
1. Every presentation initializes checkbox to false.
2. Checking it for one quit does not carry over to another quit.
3. Checking it for document A does not precheck document B.
4. Unchecked Save/Don't Save affects only the current document.
5. Checked Save/Don't Save applies to remaining documents in that quit.
6. Cancel, failed save, and quit veto never silently discard changes.
7. All quit entry points (Cmd-Q, menu Quit, direct quit commands) use
   consistent safeguards.

The initial three-choice, all-or-nothing implementation in PR #86 is
**not the accepted final UI**. Keep the PR in draft until the native
checkbox and these tests are implemented and validated.
