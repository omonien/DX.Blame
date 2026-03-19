---
phase: 02-blame-data-pipeline
plan: 02
subsystem: blame-parser-cache
tags: [porcelain-parser, thread-safe-cache, dunitx, tdd, state-machine]

# Dependency graph
requires:
  - phase: 02-blame-data-pipeline
    plan: 01
    provides: TBlameLineInfo, TBlameData, cUncommittedHash, FindGitExecutable, FindGitRepoRoot
provides:
  - ParseBlameOutput procedure for converting porcelain output to TBlameLineInfo array
  - TBlameCache thread-safe per-file blame data store
  - Comprehensive test coverage for parser, cache, and discovery
affects: [02-blame-data-pipeline]

# Tech tracking
tech-stack:
  added: [System.DateUtils/UnixToDateTime, System.SyncObjs/TCriticalSection, System.Generics.Collections/TObjectDictionary]
  patterns: [line-porcelain-state-machine, doOwnsValues-lifetime, critical-section-guard]

key-files:
  created:
    - src/DX.Blame.Git.Blame.pas
    - src/DX.Blame.Cache.pas
    - tests/DX.Blame.Tests.Git.Blame.pas
    - tests/DX.Blame.Tests.Cache.pas
    - tests/DX.Blame.Tests.Git.Discovery.pas
  modified:
    - src/DX.Blame.dpk
    - tests/DX.Blame.Tests.dpr
    - tests/DX.Blame.Tests.dproj
    - tests/DX.Blame.Tests.Version.pas

key-decisions:
  - "ParseBlameOutput uses a state machine scanning for hex headers, reading key-value pairs, stopping at TAB content line"
  - "TBlameCache uses TObjectDictionary with doOwnsValues for automatic TBlameData lifetime management"
  - "All cache methods guarded by TCriticalSection for thread safety"
  - "Path normalization via LowerCase for case-insensitive Windows file path lookup"

patterns-established:
  - "Porcelain parser: split by LF, detect header by 40 hex chars, parse key-value until TAB line"
  - "Cache guard pattern: FLock.Enter; try ... finally FLock.Leave; end on all public methods"
  - "Win64 DUnitX: Integer cast needed for Length() in Assert.AreEqual due to NativeInt return type"

requirements-completed: [BLAME-04, BLAME-05, BLAME-06]

# Metrics
duration: 4min
completed: 2026-03-19
---

# Phase 2 Plan 02: Parser and Cache Summary

**Porcelain parser state machine and thread-safe TBlameCache with 28 passing DUnitX tests covering parser, cache, and discovery**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-19T19:28:35Z
- **Completed:** 2026-03-19T19:33:03Z
- **Tasks:** 3
- **Files created:** 5
- **Files modified:** 4

## Accomplishments

- ParseBlameOutput converts git blame --line-porcelain output into TBlameLineInfo arrays via a state machine that scans hex headers, reads key-value metadata, and stops at TAB content lines
- Uncommitted lines (all-zero hash) are detected and author overridden to cNotCommittedAuthor
- TBlameCache stores TBlameData instances keyed by lowercase path with full thread safety via TCriticalSection
- Cache owns stored objects via TObjectDictionary doOwnsValues -- automatic cleanup on remove/clear/destroy
- Discovery integration tests validate FindGitExecutable, FindGitRepoRoot, and ClearDiscoveryCache against the live system
- Full test suite: 28 tests passing (10 version + 6 parser + 7 cache + 5 discovery)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create porcelain parser unit with tests** - `1d28460` (feat)
2. **Task 2: Create thread-safe cache unit with tests** - `6d08af6` (feat)
3. **Task 3: Create git discovery tests** - `737770a` (test)

## Files Created/Modified

- `src/DX.Blame.Git.Blame.pas` - Porcelain output parser with state machine
- `src/DX.Blame.Cache.pas` - Thread-safe per-file blame cache with TCriticalSection
- `tests/DX.Blame.Tests.Git.Blame.pas` - 6 parser tests (committed, uncommitted, multi-line, empty, UTF-8, summary)
- `tests/DX.Blame.Tests.Cache.pas` - 7 cache tests (store/get, missing, invalidate, clear, case-insensitive, overwrite)
- `tests/DX.Blame.Tests.Git.Discovery.pas` - 5 discovery integration tests
- `src/DX.Blame.dpk` - Added DX.Blame.Git.Blame and DX.Blame.Cache to contains clause
- `tests/DX.Blame.Tests.dpr` - Added all three new test units to uses clause
- `tests/DX.Blame.Tests.dproj` - Added DCCReference entries for new test files
- `tests/DX.Blame.Tests.Version.pas` - Fixed Win64 AreEqual type inference

## Decisions Made

- ParseBlameOutput uses a simple state machine: scan for 40-char hex header, read key-value pairs until TAB content line, then emit record
- TBlameCache uses TObjectDictionary with doOwnsValues for automatic TBlameData lifetime management on removal, clear, and destruction
- All cache public methods acquire/release TCriticalSection for thread safety
- Path normalization uses LowerCase for case-insensitive Windows path matching

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed Win64 Assert.AreEqual type inference in Version tests**
- **Found during:** Task 1 (build step)
- **Issue:** DUnitX Assert.AreEqual generic type inference fails on Win64 when comparing Integer literal with Length() which returns NativeInt
- **Fix:** Added Integer() cast to both operands in Assert.AreEqual(Integer(4), Integer(Length(LParts)))
- **Files modified:** tests/DX.Blame.Tests.Version.pas
- **Committed in:** 1d28460 (Task 1 commit)

**2. [Rule 3 - Blocking] Applied same Integer cast pattern to parser test assertions**
- **Found during:** Task 1 (build step)
- **Issue:** Same NativeInt/Integer type inference issue in all Assert.AreEqual calls comparing integers with Length() or record fields
- **Fix:** Cast both operands to Integer in all affected Assert.AreEqual calls
- **Files modified:** tests/DX.Blame.Tests.Git.Blame.pas
- **Committed in:** 1d28460 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (both blocking type inference issues on Win64)
**Impact on plan:** Both fixes necessary for compilation. No scope creep.

## Issues Encountered

None beyond the type inference fixes documented above.

## User Setup Required

None.

## Next Phase Readiness

- All parser and cache units compile and are registered in the DPK
- TBlameCache is ready for the blame engine (Plan 03) to use for storing/retrieving results
- ParseBlameOutput is ready for the blame thread to call after executing git blame
- 28 tests provide regression safety for all data layer units

---
*Phase: 02-blame-data-pipeline*
*Completed: 2026-03-19*
