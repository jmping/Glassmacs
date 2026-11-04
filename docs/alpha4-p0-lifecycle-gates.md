# Alpha 4 P0 lifecycle acceptance gates (PR #87)

This work is stacked on PR #86. Rebase/retarget onto `main` once #86 merges.

| Issue | Required packaged-app evidence | Safety invariant |
| --- | --- | --- |
| #41 | Close last window of edited scratch and untitled buffers; reopen | No silent loss or stranded edits |
| #47 | Close live R console; reopen, then explicitly terminate | Closing a window never silently kills R |
| #52 | Open multiple R Help topics while source is dirty | Source frame and modified buffer remain intact |
| #44 | Launch fresh offline app and open `.R` | ESS works without package installation or network |
| #78 | Start/switch R console, move between frames, open Preferences | No source displacement; menu actions discoverable |
| #80 | Preferences, R history, close prompts | Correct native frame placement and safe close |
| #34 | Fresh home, Finder open while windowless, dylib closure | No launch crash, missing library, or lost open event |

## Validation rules

1. Automated batch and GUI checks must not claim native alert coverage unless they interact with actual AppKit buttons and checkbox.
2. For every native quit dialog presentation, **Apply this choice to all remaining modified documents** starts unchecked. The state must never persist.
3. Cancel and save errors preserve unsaved document content; quit vetoes must not mark documents clean.
4. Test packaged application behavior rather than assuming passing Emacs batch tests prove macOS integration.
5. Close P0 issues only when the corresponding acceptance evidence exists.
