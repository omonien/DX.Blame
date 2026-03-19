---
phase: 03-inline-rendering-and-ux
plan: 01
subsystem: settings, formatting
tags: [ini-persistence, singleton, relative-time, dunitx, tdd]

requires:
  - phase: 02-blame-data-pipeline
    provides: TBlameLineInfo record and cNotCommittedAuthor constant
provides:
  - TDXBlameSettings singleton with INI persistence at %APPDATA%\DX.Blame\settings.ini
  - FormatRelativeTime pure function for human-readable time deltas
  - FormatBlameAnnotation pure function for configurable annotation text assembly
  - DeriveAnnotationColor with clGray fallback (IDE integration in Plan 02)
affects: [03-02-renderer, 03-03-settings-dialog, 03-04-keybinding, 03-05-navigation]

tech-stack:
  added: [System.IniFiles, System.DateUtils, System.StrUtils]
  patterns: [singleton-with-finalization, pure-formatting-functions, ini-settings-persistence]

key-files:
  created:
    - src/DX.Blame.Settings.pas
    - src/DX.Blame.Formatter.pas
    - tests/DX.Blame.Tests.Settings.pas
    - tests/DX.Blame.Tests.Formatter.pas
  modified:
    - src/DX.Blame.dpk
    - tests/DX.Blame.Tests.dpr
    - tests/DX.Blame.Tests.dproj

key-decisions:
  - "DeriveAnnotationColor returns clGray fallback in non-IDE context; full IDE blending deferred to renderer plan"
  - "Added STRONGLINKTYPES ON to test DPR for reliable DUnitX RTTI fixture discovery"
  - "Used explicit TDUnitX.RegisterTestFixture calls matching existing test pattern"

patterns-established:
  - "Settings singleton: unit-level var, lazy init via BlameSettings function, FreeAndNil in finalization"
  - "INI structure: [General], [Format], [Appearance], [Hotkey] sections"
  - "Time delta tests: use explicit day offsets (Now - N) instead of IncMonth for reliable MonthsBetween results"

requirements-completed: [CONF-01, CONF-02]

duration: 8min
completed: 2026-03-20
---

# Phase 3 Plan 01: Settings and Formatter Summary

**TDXBlameSettings singleton with INI persistence and pure FormatBlameAnnotation/FormatRelativeTime functions, validated by 18 new DUnitX tests**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-19T23:07:39Z
- **Completed:** 2026-03-19T23:15:57Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- TDXBlameSettings singleton loads/saves all config options (Enabled, ShowAuthor, DateFormat, ShowSummary, MaxLength, UseCustomColor, CustomColor, DisplayScope, ToggleHotkey) to INI file with correct defaults
- FormatRelativeTime correctly formats all time ranges from "just now" through years
- FormatBlameAnnotation produces correct output for all config combinations including uncommitted lines and truncation with ellipsis
- DeriveAnnotationColor returns clGray in fallback mode (IDE path tested in Plan 02)
- All 46 tests pass (28 existing + 18 new) with zero regressions

## Task Commits

Each task was committed atomically:

1. **Task 1: Create TDXBlameSettings and DX.Blame.Formatter with unit tests** - `c29f05d` (feat)
2. **Task 2: Add new units to DX.Blame.dpk** - `e1ed0f6` (chore)

## Files Created/Modified
- `src/DX.Blame.Settings.pas` - TDXBlameSettings singleton with INI persistence, all config properties
- `src/DX.Blame.Formatter.pas` - FormatRelativeTime, FormatBlameAnnotation, DeriveAnnotationColor pure functions
- `tests/DX.Blame.Tests.Settings.pas` - 5 tests: defaults, round-trip, path, missing INI, singleton identity
- `tests/DX.Blame.Tests.Formatter.pas` - 13 tests: all time ranges, format combos, truncation, uncommitted, color
- `src/DX.Blame.dpk` - Added Settings and Formatter to contains clause
- `tests/DX.Blame.Tests.dpr` - Added new test units, STRONGLINKTYPES ON
- `tests/DX.Blame.Tests.dproj` - Added DCCReference entries for new test units

## Decisions Made
- DeriveAnnotationColor returns clGray as fallback; full IDE blending via INTACodeEditorServices deferred to renderer plan
- Added {$STRONGLINKTYPES ON} to test DPR for reliable RTTI-based fixture discovery
- Used explicit TDUnitX.RegisterTestFixture calls in initialization sections (matching existing project pattern)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] DUnitX test fixtures not discovered without explicit registration**
- **Found during:** Task 1 (test execution)
- **Issue:** New test fixtures were compiled but DUnitX reported only 28 tests (existing), not 46
- **Fix:** Added TDUnitX.RegisterTestFixture calls in initialization sections and {$STRONGLINKTYPES ON} to match existing test pattern
- **Files modified:** tests/DX.Blame.Tests.Settings.pas, tests/DX.Blame.Tests.Formatter.pas, tests/DX.Blame.Tests.dpr
- **Verification:** Test count increased from 28 to 46, all passing
- **Committed in:** c29f05d (Task 1 commit)

**2. [Rule 1 - Bug] MonthsBetween rounding causes unstable test assertions with IncMonth**
- **Found during:** Task 1 (test execution)
- **Issue:** IncMonth(Now, -2) produced "1 month ago" due to MonthsBetween boundary rounding
- **Fix:** Used explicit day offsets (Now - 65, Now - 95, Now - 370) for reliable month/year boundaries
- **Files modified:** tests/DX.Blame.Tests.Formatter.pas
- **Verification:** All time-based assertions pass reliably
- **Committed in:** c29f05d (Task 1 commit)

**3. [Rule 1 - Bug] Assert.EndsWith parameter order incorrect**
- **Found during:** Task 1 (test execution)
- **Issue:** DUnitX Assert.EndsWith has non-obvious parameter order, causing assertion to check wrong direction
- **Fix:** Replaced with Assert.IsTrue(LPath.EndsWith('settings.ini'))
- **Files modified:** tests/DX.Blame.Tests.Settings.pas
- **Verification:** Settings path test passes
- **Committed in:** c29f05d (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 blocking)
**Impact on plan:** All auto-fixes necessary for correct test execution. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Settings and Formatter contracts are ready for consumption by renderer (Plan 02), settings dialog (Plan 03), keybinding (Plan 04), and navigation (Plan 05)
- TDXBlameSettings singleton provides all config state the renderer needs
- FormatBlameAnnotation accepts TBlameLineInfo + TDXBlameSettings and returns ready-to-paint text
- No blockers for downstream plans

---
*Phase: 03-inline-rendering-and-ux*
*Completed: 2026-03-20*
