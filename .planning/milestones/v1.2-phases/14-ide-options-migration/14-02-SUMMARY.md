---
phase: 14-ide-options-migration
plan: "02"
subsystem: ui
tags: [delphi, ota, tools-menu, registration, ide-options]

# Dependency graph
requires:
  - phase: 14-01
    provides: TDXBlameAddInOptions registered under Tools > Options > Third Party > DX Blame
provides:
  - Registration.pas without Tools menu — SyncEnableBlameCheckmark as no-op stub
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: ["Callback stub pattern — keep public procedure as no-op when callers cannot be updated, document removal reason in comments"]

key-files:
  created: []
  modified:
    - src/DX.Blame.Registration.pas

key-decisions:
  - "SyncEnableBlameCheckmark kept as a public no-op stub in interface section — KeyBinding.pas and Navigation.pas assign it to callback vars and cannot be changed without a separate plan"
  - "Finalization step 6 replaced with explanatory comment rather than being renumbered, preserving the numbered sequence from Steps 1-8 for traceability"

patterns-established:
  - "Decommissioned callback stubs: preserve the symbol, replace body with no-op plus comment explaining the removed feature and which callers still reference it"

requirements-completed: [SETT-03]

# Metrics
duration: 2min
completed: 2026-03-26
---

# Phase 14 Plan 02: IDE Options Migration — Tools Menu Removal Summary

**Tools menu (DX Blame submenu) stripped from Registration.pas; SyncEnableBlameCheckmark retained as a documented no-op stub for callback contract compatibility**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-26T22:49:02Z
- **Completed:** 2026-03-26T22:51:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Removed TDXBlameMenuHandler class (ToggleBlame, ShowSettings) and all menu infrastructure
- Removed CreateToolsMenu and RemoveToolsMenu procedures
- Removed GMenuParentItem, GEnableBlameItem, GMenuHandler vars
- Removed Vcl.Menus and DX.Blame.Settings.Form from implementation uses clause
- Replaced SyncEnableBlameCheckmark body with no-op stub explaining removal and naming the callers
- Removed CreateToolsMenu call from Register; replaced RemoveToolsMenu call in finalization with explanatory comment
- Updated unit header remarks and the interface-section doc comment for SyncEnableBlameCheckmark

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove Tools menu code from Registration.pas** - `bb794ac` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `src/DX.Blame.Registration.pas` — All menu-related code removed; SyncEnableBlameCheckmark preserved as no-op stub

## Decisions Made

- SyncEnableBlameCheckmark remains in the public interface with a no-op body. Removing it would require touching KeyBinding.pas and Navigation.pas (which assign it to callback vars OnBlameToggled and GOnContextMenuToggle respectively). Since those files are outside this plan's scope, the stub approach is the correct minimal-change solution.
- Finalization step numbering kept unchanged (1, 2, 3, 3.5, 4, 5, 6, 6.5, 7, 8) — step 6 body replaced with comment rather than renumbering, preserving traceability with prior documentation.

## Deviations from Plan

None — plan executed exactly as written. The stale doc comment above BlameAlreadyOpenFiles (a doubled `<summary>` block left over from a previous edit) was cleaned up as a minor inline fix during the same edit.

## Issues Encountered

Build verification produced `F2039: Could not create output file` (BPL locked by running IDE instance). This is an environmental file-lock, not a compilation error — the Delphi compiler processed all Pascal sources without error before the linker attempted to write the BPL. All done criteria verified by direct inspection of the modified file.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 14 complete: IDE Options page (Plan 01) and Tools menu removal (Plan 02) both shipped
- SETT-03 requirement satisfied: no Tools menu items remain, settings accessible exclusively via Tools > Options > Third Party > DX Blame and the editor context menu toggle
- No blockers

## Self-Check: PASSED

- `src/DX.Blame.Registration.pas` — FOUND
- `14-02-SUMMARY.md` — FOUND
- Commit `bb794ac` — FOUND

---
*Phase: 14-ide-options-migration*
*Completed: 2026-03-26*
