---
phase: 13-statusbar-display-navigation
plan: 02
subsystem: ui
tags: [delphi, context-menu, blame-toggle, navigation, auto-scroll, ota]

# Dependency graph
requires:
  - phase: 13-01
    provides: GOnCaretMoved callback pattern for inter-unit wiring
  - phase: 11-01
    provides: AttachContextMenu/DetachContextMenu infrastructure in Navigation.pas
provides:
  - Context menu "Enable/Disable Blame" toggle with Ctrl+Alt+B hint and checkmark
  - GOnContextMenuToggle callback variable (wired to SyncEnableBlameCheckmark)
  - NavigateToRevision optional ALineNumber param for auto-scroll
  - DetachContextMenu Pitfall 3 fix (restores OnPopup to nil when no original handler)
affects:
  - phase-14-settings
  - any future plan using NavigateToRevision or context menu

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Callback variable pattern for cross-unit synchronization without circular dependency (GOnContextMenuToggle mirrors OnBlameToggled)
    - Default parameter for backward-compatible API extension (ALineNumber = 0)
    - FindModule + SetCursorPos + Center for post-OpenFile editor scroll

key-files:
  created: []
  modified:
    - src/DX.Blame.Navigation.pas
    - src/DX.Blame.Registration.pas

key-decisions:
  - "GOnContextMenuToggle callback (not direct call) avoids Navigation -> Registration circular dependency"
  - "ALineNumber = 0 default param preserves backward compat for NavigateToRevision"
  - "GEnableBlameItem always shown in context menu (does not require VCS availability)"
  - "DetachContextMenu: removed Assigned(GOriginalOnPopup) guard — nil is valid restore target"
  - "System.SysUtils in interface uses clause only (not repeated in implementation) for TProc availability"

patterns-established:
  - "Callback variable pattern: var GOnXxx: TProc in interface, wired in Registration.pas Register procedure"
  - "Default parameter extension: AParam: T = default preserves all callers when extending procedure signatures"

requirements-completed: [NAV-01, NAV-02]

# Metrics
duration: 5min
completed: 2026-03-26
---

# Phase 13 Plan 02: Context Menu Toggle and Auto-Scroll Summary

**Editor context menu gains Enable/Disable Blame toggle with Ctrl+Alt+B hint, and revision navigation auto-scrolls to the originating source line using FindModule + SetCursorPos + Center.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-26T22:12:04Z
- **Completed:** 2026-03-26T22:17:00Z
- **Tasks:** 2 (+ 1 auto-approved checkpoint)
- **Files modified:** 2

## Accomplishments

- Context menu now shows "Enable Blame" / "Disable Blame" with Ctrl+Alt+B tab-hint and a checkmark reflecting current state
- Clicking the context menu toggle changes blame state, persists to INI, fires GOnContextMenuToggle, and invalidates editors — keeping Tools menu checkmark in sync
- NavigateToRevision extended with optional ALineNumber param: after OpenFile, editor scrolls to and centers the originating source line
- Fixed DetachContextMenu Pitfall 3: OnPopup is now restored unconditionally when GHookedPopup != nil, so nil (no original handler) is correctly restored on unload

## Task Commits

Each task was committed atomically:

1. **Tasks 1 + 2: Context menu toggle and auto-scroll** - `4688ba8` (feat)

## Files Created/Modified

- `src/DX.Blame.Navigation.pas` — Added GOnContextMenuToggle var, GEnableBlameItem, OnToggleBlameClick, ALineNumber param + scroll block, DetachContextMenu bugfix, DX.Blame.Renderer added to implementation uses
- `src/DX.Blame.Registration.pas` — Wired DX.Blame.Navigation.GOnContextMenuToggle := SyncEnableBlameCheckmark

## Decisions Made

- `GOnContextMenuToggle` callback var in Navigation interface, assigned in Registration.pas — identical pattern to `OnBlameToggled` in KeyBinding.pas. Prevents Navigation referencing Registration (would create circular dependency).
- `ALineNumber: Integer = 0` default parameter in `NavigateToRevision` — backward compatible; no existing callers need changes.
- `GEnableBlameItem` always shown, not conditional on VCS availability — user should always be able to toggle blame even when no VCS is detected.
- Removed `Assigned(GOriginalOnPopup)` guard in `DetachContextMenu` — nil is the correct "no handler" state and must be explicitly restored.
- `System.SysUtils` placed only in interface `uses` clause (not duplicated in implementation) since `TProc` lives there and Delphi prohibits same-unit in both sections.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed duplicate System.SysUtils in uses clauses**
- **Found during:** Task 1 (build verification)
- **Issue:** Plan instructed adding `uses System.SysUtils;` to interface section for `TProc`, but implementation section already had `System.SysUtils` — Delphi error E2004: Identifier redeclared
- **Fix:** Kept `System.SysUtils` in interface uses only; removed from implementation uses (it is already transitively visible)
- **Files modified:** src/DX.Blame.Navigation.pas
- **Verification:** Win64 build succeeds (6454 lines, no errors); Win32 link fails only due to IDE-loaded BPL lock, not a code error
- **Committed in:** 4688ba8

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Minor uses-clause correction required by Delphi compilation rules. No scope change.

## Issues Encountered

Win32 Debug build cannot link because `DX.Blame370.bpl` is locked by the running Delphi IDE. Win64 Debug build confirms all code compiles without errors. This is normal during IDE-plugin development — install requires unloading the package first.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 13 complete: statusbar display (13-01) and context menu + auto-scroll (13-02) both shipped
- Phase 14 (Settings UI) can proceed; all menu wiring and toggle infrastructure is in place
- Known limitation: statusbar FreeNotification single-window lifecycle needs empirical IDE validation

---
*Phase: 13-statusbar-display-navigation*
*Completed: 2026-03-26*
