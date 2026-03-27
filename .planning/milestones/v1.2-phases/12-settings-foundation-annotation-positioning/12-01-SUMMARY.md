---
phase: 12-settings-foundation-annotation-positioning
plan: 01
subsystem: ui
tags: [delphi, settings, annotation, caret, renderer, ini-persistence]

# Dependency graph
requires:
  - phase: 11-engine-project-switch
    provides: "BlameEngine and renderer infrastructure used by Settings.Form.pas"
provides:
  - "TDXBlameAnnotationPosition enum (apEndOfLine, apCaretColumn) in DX.Blame.Settings"
  - "AnnotationPosition property on TDXBlameSettings with INI persistence in [Display] section"
  - "Caret-anchored X calculation in PaintLine using Max(caretX, endOfLineX) pattern"
  - "ComboBox for annotation position selection in settings dialog"
affects:
  - phase 13 (statusbar)
  - phase 14 (final polish)

# Tech tracking
tech-stack:
  added: [System.Math (for Max function in Renderer)]
  patterns:
    - "Max(caretX + padding, endOfLineX) prevents annotation from moving left of end-of-line"
    - "LLogicalLine = FCurrentLine guard restricts caret-anchor to caret line only in dsAllLines mode"
    - "New INI section [Display] for annotation positioning — separate from [General] to avoid key conflicts"

key-files:
  created: []
  modified:
    - src/DX.Blame.Settings.pas
    - src/DX.Blame.Renderer.pas
    - src/DX.Blame.Settings.Form.pas
    - src/DX.Blame.Settings.Form.dfm

key-decisions:
  - "Use Max(caretX + padding, endOfLineX) to prevent leftward flicker when caret is to the left of end-of-line"
  - "Only the caret line gets caret-anchored X; non-caret lines in dsAllLines mode stay at end-of-line (DISP-04)"
  - "INI key placed in new [Display] section, not [General], to avoid conflicts with existing DisplayScope key"
  - "Default is apEndOfLine; apCaretColumn must be explicitly selected by user"

patterns-established:
  - "Enum position: new enums declared after existing TDXBlameVCSPreference in type section"
  - "INI round-trip: load uses SameText comparison with string fallback to default value"

requirements-completed: [DISP-03, DISP-04]

# Metrics
duration: 25min
completed: 2026-03-26
---

# Phase 12 Plan 01: Annotation Positioning Summary

**TDXBlameAnnotationPosition enum with caret-anchored X in PaintLine (Max guard) and settings ComboBox, persisted to INI [Display] section**

## Performance

- **Duration:** 25 min
- **Started:** 2026-03-26T18:40:36Z
- **Completed:** 2026-03-26T19:05:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- New `TDXBlameAnnotationPosition = (apEndOfLine, apCaretColumn)` enum in DX.Blame.Settings
- `AnnotationPosition` property with `apEndOfLine` default, loaded/saved via INI `[Display]` section
- Caret-anchored X branch in `PaintLine`: `Max(caretX + 3*cellWidth, endOfLineX)` ensures annotation never jumps left of text end
- Only caret line gets caret-anchored X in dsAllLines mode (DISP-04 requirement satisfied)
- Settings dialog expanded with ComboBox (`End of line (default)` / `Caret-anchored`) inside GroupBoxDisplay

## Task Commits

Each task was committed atomically:

1. **Task 1: Add AnnotationPosition setting with INI persistence** - `0035845` (feat)
2. **Task 2: Implement caret-anchored X in PaintLine and add settings UI** - `14182ad` (feat)

## Files Created/Modified

- `src/DX.Blame.Settings.pas` - Added `TDXBlameAnnotationPosition` enum, `FAnnotationPosition` field, `AnnotationPosition` property, INI load/save in `[Display]` section
- `src/DX.Blame.Renderer.pas` - Added `System.Math` to uses, `LCaretX` local var, caret-anchor branch after end-of-line X calculation
- `src/DX.Blame.Settings.Form.pas` - Added `LabelAnnotationPosition` and `ComboBoxAnnotationPosition` fields; load/save from `AnnotationPosition` property
- `src/DX.Blame.Settings.Form.dfm` - Expanded `GroupBoxDisplay` height 65->110, added label+combobox for annotation position, shifted lower groups and buttons down 45px, `ClientHeight` 535->580

## Decisions Made

- `Max(caretX + padding, endOfLineX)` pattern: ensures annotation never moves left when caret is positioned before end-of-line — prevents visual flicker
- `LLogicalLine = FCurrentLine` guard in renderer: only the caret line gets caret-anchored positioning; non-caret lines in dsAllLines mode stay at end-of-line (DISP-04)
- Separate `[Display]` INI section used instead of adding to `[General]` — avoids any potential key conflicts with existing `DisplayScope` key
- Default is `apEndOfLine` to preserve backwards-compatible behavior for existing users

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected corrupted .pas file after PowerShell CRLF normalization**
- **Found during:** Task 2 verification build
- **Issue:** PowerShell CRLF enforcement script caused `DX.Blame.Settings.Form.pas` to be written as a single-line file (literal `\n` chars from system reminder string representation)
- **Fix:** Rewrote the file using the Write tool with correct content, then applied CRLF conversion via `[System.IO.File]::WriteAllText` with UTF-8 BOM encoding
- **Files modified:** src/DX.Blame.Settings.Form.pas
- **Verification:** Build passed after fix (6035 lines compiled)
- **Committed in:** 14182ad (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - build-blocking file corruption)
**Impact on plan:** CRLF enforcement tooling issue resolved inline; no scope changes.

## Issues Encountered

- PowerShell CRLF enforcement script `$text.Replace([char]10, [char]13 + [char]10)` syntax is invalid for multi-char replacement in some PS versions — used `[System.IO.File]::WriteAllText` with explicit UTF-8 BOM encoding as the correct approach for Delphi .pas files

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `AnnotationPosition` enum and property available in `DX.Blame.Settings` for any future phases needing it
- Settings dialog pattern (group box expansion, ComboBox load/save) established for future settings additions
- Phase 13 (Statusbar) can proceed independently

## Self-Check: PASSED

- src/DX.Blame.Settings.pas: FOUND
- src/DX.Blame.Renderer.pas: FOUND
- src/DX.Blame.Settings.Form.pas: FOUND
- src/DX.Blame.Settings.Form.dfm: FOUND
- .planning/phases/12-settings-foundation-annotation-positioning/12-01-SUMMARY.md: FOUND
- Commit 0035845: FOUND
- Commit 14182ad: FOUND

---
*Phase: 12-settings-foundation-annotation-positioning*
*Completed: 2026-03-26*
