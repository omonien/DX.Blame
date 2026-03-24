---
phase: 09-mercurial-provider
plan: 02
subsystem: vcs
tags: [mercurial, hg, blame, provider, ivcs]

requires:
  - phase: 09-01
    provides: THgProcess, ParseHgAnnotateOutput, BuildAnnotateArgs, cHgUncommittedHash
provides:
  - Full THgProvider IVCSProvider implementation for Mercurial
  - Package compilation with all 5 Hg units registered
affects: [10-polish]

tech-stack:
  added: []
  patterns: [provider-delegation-pattern-hg, hg-cli-commands]

key-files:
  created: []
  modified:
    - src/DX.Blame.Hg.Provider.pas
    - src/DX.Blame.Hg.Blame.pas
    - src/DX.Blame.dpk
    - src/DX.Blame.dproj

key-decisions:
  - "Mirrored TGitProvider delegation pattern exactly for THgProvider"
  - "Fixed for-loop variable assignment in Hg.Blame parser for Delphi 13 compilation"
  - "Added all missing DCCReference entries to dproj for previously unregistered units"

patterns-established:
  - "Provider delegation: THgProvider delegates to THgProcess/ParseHgAnnotateOutput like TGitProvider delegates to TGitProcess/ParseBlameOutput"

requirements-completed: [HGB-01, HGB-02, HGB-03, HGB-04]

duration: 3min
completed: 2026-03-24
---

# Phase 9 Plan 2: THgProvider Implementation Summary

**Full Mercurial blame provider with hg annotate, log, diff, and cat commands at Git feature parity**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-24T13:31:11Z
- **Completed:** 2026-03-24T13:34:17Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Replaced all 6 ENotSupportedException stubs in THgProvider with real Mercurial CLI implementations
- Registered DX.Blame.Hg.Types, Hg.Process, and Hg.Blame in the DX.Blame package
- Package compiles successfully with zero errors on Delphi 13

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace THgProvider stubs with real implementations** - `2743b38` (feat)
2. **Task 2: Register new units in package and verify compilation** - `bae4a92` (feat)

## Files Created/Modified
- `src/DX.Blame.Hg.Provider.pas` - Full IVCSProvider implementation with ExecuteBlame, ParseBlameOutput, GetCommitMessage, GetFileDiff, GetFullDiff, GetFileAtRevision
- `src/DX.Blame.Hg.Blame.pas` - Fixed for-loop variable assignment (Delphi E2081)
- `src/DX.Blame.dpk` - Added Hg.Types, Hg.Process, Hg.Blame to contains clause
- `src/DX.Blame.dproj` - Added DCCReference entries for all Hg and VCS units

## Decisions Made
- Mirrored TGitProvider delegation pattern exactly -- THgProvider is a thin wrapper around THgProcess and ParseHgAnnotateOutput
- Fixed Delphi E2081 by introducing LLine variable to avoid for-in loop variable assignment
- Added missing DCCReference entries for units that were in dpk but not in dproj (VCS.Types, VCS.Process, VCS.Provider, etc.)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed for-loop variable assignment in Hg.Blame parser**
- **Found during:** Task 2 (compilation verification)
- **Issue:** Delphi E2081: Assignment to FOR-Loop variable 'LRawLine' -- the parser assigned to the for-in iteration variable to trim CR
- **Fix:** Introduced separate LLine variable for the trimmed line, leaving the for-in variable untouched
- **Files modified:** src/DX.Blame.Hg.Blame.pas
- **Verification:** Package compiles successfully
- **Committed in:** bae4a92 (Task 2 commit)

**2. [Rule 3 - Blocking] Added missing DCCReference entries to dproj**
- **Found during:** Task 2 (package registration)
- **Issue:** dproj was missing DCCReference entries for many units already present in dpk (VCS.Types, VCS.Process, VCS.Provider, Git.Provider, Hg.Discovery, Hg.Provider, VCS.Discovery, CommitDetail, Popup, Diff.Form)
- **Fix:** Added all missing DCCReference entries to ensure dproj and dpk are in sync
- **Files modified:** src/DX.Blame.dproj
- **Verification:** Package compiles successfully
- **Committed in:** bae4a92 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both fixes necessary for compilation. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Mercurial provider is complete and at feature parity with Git
- All IVCSProvider methods implemented with real hg CLI commands
- Ready for Phase 10 (polish/testing) if applicable

---
*Phase: 09-mercurial-provider*
*Completed: 2026-03-24*
