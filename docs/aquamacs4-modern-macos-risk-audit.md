# Aquamacs 4 modern macOS risk audit

> **Document ID:** DOC-AQUA4-AUDIT  
> **Status:** Informational  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-29  
> **Last reviewed:** 2026-10-29  
> **Coverage:** Source-traced review of Aquamacs 4 (`aquamacs-4-dev`) macOS regressions and what they mean for Glassmacs  
> **Supersedes:** None

This audit answers issue [#34](https://github.com/jmping/Glassmacs/issues/34)'s
source-level follow-up. Its conclusions feed the
[acceptance matrix](acceptance-matrix.md), which is the authority for test
status; this document records evidence and reasoning only.

## Scope and method

- **Aquamacs:** branch `aquamacs-4-dev` at `0f05b614be` (2026-09-26), read as a
  blobless clone. Aquamacs 4 is Emacs 29 with Aquamacs's changes re-applied:
  Aquamacs 3.6 changes onto Emacs 28.3 (`2d81743538`, 2024-06-21), then onto
  Emacs 29.3 (`6331884925`), then the `emacs-29.4` tag merged (`48e0e2bdfe`,
  2024-06-28). The branch's 166,816 commits are almost all upstream Emacs, so
  this audit does not infer causes from the branch diff. Instead it follows
  the per-file history of the Cocoa sources (`src/nsterm.m`, `nsfns.m`,
  `nsmenu.m`, `nsterm.h`, `macfont.m`) and the build and packaging scripts
  since 2023, and splits it into **upstream** commits (authored in GNU Emacs,
  some ported later) and **downstream** Aquamacs commits.
- **Upstream presence:** for each upstream fix Aquamacs carries, whether it is
  in the `emacs-31.1` tag (`a360712c9`, 2026-08-24), which Glassmacs bundles,
  was checked with `git merge-base --is-ancestor` against the GNU Emacs
  history (GitHub mirror `emacs-mirror/emacs`).
- **Issues:** the Aquamacs issue pages listed in #34 were read on 2026-10-29.
  States and diagnoses below are as written there; they are reports, not
  confirmed Glassmacs defects.
- **Glassmacs:** GNU Emacs 31.1's Cocoa build as distributed (universal), an
  isolated Lisp configuration, the Swift launcher and one Objective-C module
  (`macos/GlassmacsLifecycle.m`). Glassmacs carries no patches to Emacs's C
  sources.

## Findings by report

| Aquamacs report | What was seen (issue page) | Source evidence | Cause class | Glassmacs exposure and mitigation |
| --- | --- | --- | --- | --- |
| [#264](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/264), [#268](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/268) | 4.0 alpha crashes at launch in `macfont_encode_char` (macOS 26, Apple Silicon); avoided by removing `(font-backend ns)` from `customizations.el` | `5971c381f1` (2026-05-01) "Add guard against using (font-backend ns) in default-display-alist" | Downstream configuration carried into a newer Emacs | Glassmacs sets no frame font backend and starts from a clean home with `-Q`. That `-Q` was ignored before this audit (LAUNCH-002, fixed), so a user's old frame settings could have loaded. LAUNCH-001 and LAUNCH-002 now run on the packaged app. |
| [#258](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/258), [#266](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/266) | Builds fail on Tahoe: `configure` rejects `aarch64-apple-darwin25`; Apple clang 21 rejects K&R definitions | `2c194ff6e2` (2026-09-26) K&R to ANSI in `window.c`/`nsfns.m`; `b943f1e610` build on a Monterey VM | Building an old Emacs base with new toolchains | Glassmacs compiles only Swift and one Objective-C file, and bundles a released Emacs. Exposure is the lag before upstream builds include fixes (below). DIST-005; the runner matrix is a follow-up. |
| [#243](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/243) | Alpha crashes at start: `libtiff.6.dylib` not bundled (closed) | `b8e4c35c60` copy Homebrew-built libraries into the app; `3f21233751` (cited as the fix); `6cab2c8c8d` bundle and sign in the main build | Packaging of external libraries | The pinned upstream app links libgccjit and others from `/nix/store`; `relocate-macos-dependencies` rewrites them and `validate-macos-app` rejects any unresolved or non-relocatable dependency (DIST-001), now also checking build-machine paths (DIST-003). |
| [#270](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/270) | Open (2026-10-15): with no frames, a file opened from Finder or `open -a` is loaded but never shown; the Dock opens a blank frame | No fix yet; `7a47fd64ff` (2026-03-27) replaced obsolete Aquamacs application-handler code | Lifecycle with zero frames | Glassmacs keeps the last frame hidden rather than deleted, and its lifecycle module routes reopen, menus and keys. ERT covers the Lisp side; the GUI scenarios `finder-open-while-windowless` and `last-window-close-and-dock-reopen` cover the packaged app (FINDER-001, LIFE-001). |
| [#247](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/247), [#249](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/249) | Bundled `emacsclient` fails with `Wrong type argument: windowp` (open) | No fix; other `emacsclient` builds work | Downstream frame code against client frames | Not exposed: Glassmacs starts no server, and documents arrive as Apple Events (CLIENT-001, manual only). |
| [#256](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/256), [#248](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/248) | Menus with shortcuts render wrongly; About did nothing (#248 closed) | `d26d800e14` wrong selector for About; menus defined in Objective-C (`nsaquamacs.m`), planned move to `easy-menu-define` | Downstream Objective-C menus | Glassmacs menus are Lisp keymaps evaluated by Emacs. The menu checker (MENU-001) evaluates every item in key modes; presentation stays manual (MENU-002). |
| [#180](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/180) | Crash in `ns_menu_update` when poly-R and ESS load (2020); worked around by commenting out lines 218–225 of `poly-R.el` | Upstream Emacs bugs 34762 and 26982 cited; Aquamacs `de7408a` | Menu filter evaluated during Cocoa menu updates | GNU Emacs now catches such errors. Glassmacs's menu test still found poly-R's RMarkdown > Templates `:filter` (very likely the same menu definition) failing without an R session in poly-R `fee0b6e`; Glassmacs now guards it (MODE-001). |
| [#246](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/246), [#251](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/251) | Safe directory-local variables re-prompted after saving: saved "in the wrong place" (#246, fixed); beta preferences directory to be reset before release (#251, open) | `3309c854e2`, `c93d17ce53`, `0ba4914100` (`AQUAMACS_PREFERENCES_DIR`) | Preference location and early-init ordering | The same class twice in Glassmacs. The launcher ignored `-Q` (LAUNCH-002), and under `-Q` Emacs refused to save customizations, so toggles, Customize and safe-local answers were lost (PREF-001, PREF-003). Both are fixed, with tests that check where settings are saved. |
| [#265](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/265), [#235](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/235) | Mac speller missing; no Choices buffer (#265, open); SIGABRT "Creating semaphore failed" in NSSpellChecker code (#235, open) | `dd9e0b7e41` removed `ns-spellchecker.el`; `f12395d6a4`, `b329657cff` rework of merged spelling | Downstream Objective-C spelling bridge | Glassmacs has no Objective-C speller. It uses ispell with enchant (AppleSpell), hunspell or aspell, check-only (SPELL-001 to SPELL-003). |
| [#245](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/245) | Auto-revert unreliable with `auto-revert-use-notify` (closed: set to nil) | Merge left Emacs's default `t`; Aquamacs 3.6 had `nil` | Upstream default meets macOS kqueue | Glassmacs had no auto-revert; added, and on macOS it now polls as Aquamacs settled on (REVERT-001). The GUI scenario replaces the file by rename. |
| [#253](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/253) | Enable native compilation (closed: enabled for alpha 2) | `073d2de3a9` enabled; `36cb98e085` (2025-12-30) disabled again: "some odd side effects" | Native compilation on users' machines | Glassmacs loads only the bundle's signed `.eln` files, with JIT compilation and trampolines off (NATIVE-001/002), so no compiler is needed. |
| [#255](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/255), [#241](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/241) | Intermittent hangs in Open/Recent dialogs (3.6 on M4, Rosetta suspected); multi-second hangs opening LaTeX files from other apps on macOS 14, tied to startup files | `5837d547d9` dialog crash; `939182c7df` dialog layout | Old Intel build under Rosetta; heavy startup files | Glassmacs is universal (DIST-002), its startup is small, and every GUI scenario has deadlines. The Cocoa open panel stays manual (DIALOG-001). |
| [#218](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/218), [#160](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/160) | Crash closing the last full-screen window (3.5/3.6, fixed `d23b02d`) | Upstream `a5c71cc23` "Prevent crashes on macOS when fullscreen frame is deleted" (2023), in Emacs 31.1 | Upstream Cocoa fix | Glassmacs hides rather than deletes the final frame; `fullscreen-close-and-reopen` runs on the packaged app (FULL-001). |

## Upstream Cocoa fixes Aquamacs carries, and Emacs 31.1

Aquamacs 4 cherry-picked these GNU Emacs fixes. Glassmacs gets upstream fixes
only through the Emacs release it bundles.

| Fix | Upstream commit | In `emacs-31.1`? |
| --- | --- | --- |
| Fix macOS 26 scrolling lag and input handling issues (bug#80268) | `1c4f09aad` (Aquamacs `a374d02b28`) | Yes |
| Kick the event loop in NS drag and drop (bug#80592) | `7ae5562bd` (Aquamacs `8cff4708c1`) | Yes |
| Fix freeze in NS event handling (bug#81510) | backport `2b47d7192` (Aquamacs `89445cc46c`) | Yes |
| Prevent freezes on macOS (bug#69561) | `d95f2a882`, `4ac4cec65` | Yes |
| Prevent crashes on macOS when fullscreen frame is deleted | `a5c71cc23` | Yes |
| **Fix crash in NS scroll code (bug#81585)**: negative destinations reach `ns_scroll_run` | `b59a6ea35`, 2026-08-09 (Aquamacs `b52cca9aa9`) | **No**: on `master` only |
| **NS port freezes without beach ball (bug#72496)**: app-defined events sent to a window that no longer exists | `ef448d2ca`, 2026-08-02 (Aquamacs `3e2bad9d88`) | **No**: on `master` only |

The last two are real exposure for Glassmacs 0.1. The freeze fix concerns
events addressed to a window that is gone. Glassmacs hides and restores
frames by design, so its window lifecycle is exactly where that path matters.
They are recorded as UPSTREAM-001 and UPSTREAM-002 in the matrix. Glassmacs
cannot patch the bundled binary, so the mitigation is to move the pin to the
first Emacs release that contains both (31.2 if they are backported) and to
watch GUI-run crash reports and hangs, which the harness collects and fails on.

## Architectural lessons for Glassmacs

1. **Keep the Cocoa C code upstream.** Most Aquamacs 4 regressions come from
   re-applying older Objective-C patches to a newer Emacs: the dialog crash
   (`5837d547d9`), the lost `ns_frame_rehighlight` (`291a6cb811`), the About
   selector (#248), menu rendering (#256), and the spelling bridge (#235,
   #265). Glassmacs's single Objective-C module adds behavior without
   replacing Emacs code. It should stay that small, and it has tests.
2. **Own fewer build steps, and verify the ones you own.** Aquamacs builds
   Emacs and its libraries, so new SDKs and compilers break it (#258, #266,
   #243). Glassmacs bundles a released build and validates the result
   statically (Layer B), at the cost of waiting for upstream fixes (above).
3. **Isolation must be tested where users run it.** Aquamacs lost settings to
   wrong paths (#246, #251). Glassmacs had two isolation defects of its own,
   hidden from batch tests because `--batch` implies `-q`. Isolation is now
   checked on the packaged app.
4. **Prefer simple, observable mechanisms on macOS.** Polling beat kqueue for
   auto-revert (#245); bundled native code beats compiling on users' Macs
   (#253, `36cb98e085`).
5. **Third-party menus run inside the Cocoa menu update.** The #180 crash
   came from a mode menu filter. Glassmacs evaluates every menu in key modes
   in CI and guards the one filter it found failing.

## Follow-ups

- Move the Emacs pin when a release contains bug#81585 and bug#72496
  (UPSTREAM-001/002).
- Add a macOS runner matrix for the launcher and module builds (DIST-005).
- poly-R's Templates filter fails without an R session; that belongs to
  poly-R upstream, not to Glassmacs.
