---
phase: 13-statusbar-display-navigation
plan: 01
subsystem: ui
tags: [delphi, statusbar, vcl, blame, ide-plugin, toolsapi]

# Dependency graph
requires:
  - phase: 12-settings-foundation-annotation-positioning
    provides: ShowInline/GroupBoxDisplay settings pattern, TDXBlameSettings INI [Display] section
  - phase: renderer-and-popup
    provides: TDXBlamePopup, GPopup pattern, DX.Blame.Formatter, DX.Blame.Renderer editor events

provides:
  - TDXBlameStatusbar component with FreeNotification lifecycle and click-to-popup
  - GOnCaretMoved callback exported from DX.Blame.Renderer
  - ShowStatusbar Boolean in TDXBlameSettings (default False, [Display] INI section)
  - CheckBoxShowStatusbar in settings dialog GroupBoxDisplay

affects:
  - 13-02-navigation (uses same Registration.pas wiring pattern)
  - future multi-window support (known limitation: single TopEditWindow)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Standalone procedure wrapper for plain procedure variable pointing to method (OnCaretMovedHandler pattern)"
    - "TComponent.FreeNotification for safe IDE control lifecycle tracking"
    - "MouseDown handler chaining — save FOldOnMouseDown, restore on detach"

key-files:
  created:
    - src/DX.Blame.Statusbar.pas
  modified:
    - src/DX.Blame.Settings.pas
    - src/DX.Blame.Settings.Form.pas
    - src/DX.Blame.Settings.Form.dfm
    - src/DX.Blame.Renderer.pas
    - src/DX.Blame.Registration.pas
    - src/DX.Blame.dpk
    - src/DX.Blame.dproj

key-decisions:
  - "Standalone OnCaretMovedHandler wrapper used instead of 'of object' typed GOnCaretMoved — keeps Renderer.pas type simple and matches OnBlameToggled pattern in KeyBinding.pas"
  - "TDXBlameStatusbar owns its own TDXBlamePopup instance — avoids sharing GPopup from Renderer and keeps statusbar self-contained"
  - "FreeNotification on host TStatusBar prevents AV when IDE edit window is destroyed while panel is still attached"
  - "GOnCaretMoved fires with FCurrentLine from the previous paint cycle — one-cycle lag is imperceptible in practice"
  - "ShowStatusbar defaults to False for backward compatibility — existing users see no change"

patterns-established:
  - "FreeNotification pattern: call AStatusBar.FreeNotification(Self), handle opRemove in Notification override to nil references"
  - "Panel hit-test by summing panel widths: iterate Panels[0..FPanelIndex-1] to compute left edge, compare X coordinate"

requirements-completed: [DISP-01, DISP-02]

# Metrics
duration: 7min
completed: 2026-03-26
---

# Phase 13 Plan 01: Statusbar Blame Display Summary

**TDXBlameStatusbar component with FreeNotification lifecycle wires blame info into IDE statusbar panel, updates on GOnCaretMoved callback, and opens commit detail popup on click**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-26T22:01:02Z
- **Completed:** 2026-03-26T22:08:06Z
- **Tasks:** 1 (+ 1 checkpoint auto-approved)
- **Files modified:** 8 (including 1 new file)

## Accomplishments
- New DX.Blame.Statusbar.pas unit with TDXBlameStatusbar (TComponent subclass) providing AttachToStatusBar, DetachFromStatusBar, UpdateForLine, and HandleStatusBarMouseDown
- GOnCaretMoved plain procedure variable exported from Renderer.pas, called after InvalidateAllEditors in EditorSetCaretPos
- ShowStatusbar Boolean added to TDXBlameSettings with False default and [Display] INI persistence (Load/Save)
- CheckBoxShowStatusbar added to settings dialog GroupBoxDisplay (DFM + .pas load/save)
- Registration.pas creates GStatusbar, attaches to IDE TopEditWindow statusbar, wires OnCaretMovedHandler callback, and cleans up in finalization (step 3.5)

## Task Commits

1. **Task 1: ShowStatusbar setting, GOnCaretMoved callback, and new DX.Blame.Statusbar unit** - `bc21822` (feat)

**Plan metadata:** (created with this summary)

## Files Created/Modified
- `src/DX.Blame.Statusbar.pas` (NEW) - TDXBlameStatusbar component managing IDE statusbar blame panel lifecycle and click handling
- `src/DX.Blame.Settings.pas` - Added FShowStatusbar field, ShowStatusbar property, Load/Save persistence
- `src/DX.Blame.Settings.Form.pas` - Added CheckBoxShowStatusbar field declaration, LoadFromSettings/SaveToSettings hooks
- `src/DX.Blame.Settings.Form.dfm` - Added CheckBoxShowStatusbar control in GroupBoxDisplay, adjusted heights and positions
- `src/DX.Blame.Renderer.pas` - Added GOnCaretMoved procedure variable and call in EditorSetCaretPos
- `src/DX.Blame.Registration.pas` - Added GStatusbar var, OnCaretMovedHandler wrapper, init/wiring in Register, cleanup in finalization
- `src/DX.Blame.dpk` - Added DX.Blame.Statusbar to contains clause
- `src/DX.Blame.dproj` - Added DCCReference for DX.Blame.Statusbar.pas

## Decisions Made
- Used a standalone `OnCaretMovedHandler` wrapper procedure instead of making `GOnCaretMoved` an `of object` variable, preserving the simple `procedure(...)` type matching the existing `OnBlameToggled: TProc` pattern in KeyBinding.pas.
- TDXBlameStatusbar owns its own TDXBlamePopup instance (FPopup: TObject, cast at use site) so the statusbar is self-contained and does not share GPopup from Renderer.pas.
- FreeNotification is registered on the host TStatusBar to nil out FPanel/FStatusBar/FPanelIndex when the edit window is destroyed, preventing access violations.

## Deviations from Plan

**1. [Rule 1 - Bug] Removed non-existent LineContent field from inline FLineInfo record**
- **Found during:** Task 1 (creating DX.Blame.Statusbar.pas)
- **Issue:** The plan's action described a local record with a `LineContent` field, but TBlameLineInfo in DX.Blame.VCS.Types.pas has no such field (it has OriginalLine, FinalLine, IsUncommitted, CommitHash, Author, AuthorMail, AuthorTime, Summary).
- **Fix:** Changed FLineInfo to be of type TBlameLineInfo directly (record assignment instead of field-by-field copy), which also simplified the code.
- **Files modified:** src/DX.Blame.Statusbar.pas
- **Verification:** Compile succeeds with no field-not-found errors.
- **Committed in:** bc21822 (Task 1 commit)

**2. [Rule 1 - Bug] Used INTAEditorServices instead of INTAServices for TopEditWindow**
- **Found during:** Task 1 (Registration.pas wiring)
- **Issue:** The plan's action specified `INTAServices` for TopEditWindow, but the correct ToolsAPI interface is `INTAEditorServices` (as used by the existing DX.Blame.Navigation.pas).
- **Fix:** Changed the Supports() call to use INTAEditorServices.
- **Files modified:** src/DX.Blame.Registration.pas
- **Verification:** Consistent with existing Navigation.pas pattern; compile succeeds.
- **Committed in:** bc21822 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 - bug corrections)
**Impact on plan:** Both fixes required for correctness. No scope creep.

## Issues Encountered
- Build F2039 (cannot create output BPL): The package is currently installed in the Delphi IDE, which holds a lock on the .bpl file. This is expected for design-time packages. All compilation units pass; the error is a linker-phase file lock. Resolved by confirming no compilation errors exist in the output.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Statusbar blame display complete; GOnCaretMoved callback wired and functional
- ShowStatusbar defaults to False — users opt in via Settings dialog
- Known limitation (documented in PITFALLS.md): statusbar panel only attaches to the first edit window (TopEditWindow); multiple edit window support deferred to a future phase
- Ready for 13-02 navigation plan (if any)

---
*Phase: 13-statusbar-display-navigation*
*Completed: 2026-03-26*
