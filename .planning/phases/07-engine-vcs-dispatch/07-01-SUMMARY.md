---
phase: 07-engine-vcs-dispatch
plan: 01
subsystem: engine
tags: [ivcs-provider, blame-engine, commit-detail, vcs-abstraction, delphi]

# Dependency graph
requires:
  - phase: 06-vcs-abstraction
    provides: IVCSProvider interface, TGitProvider, TVCSProcess
provides:
  - Provider-dispatched blame engine with FProvider field
  - Provider-dispatched commit detail fetch with IVCSProvider parameter
  - VCSAvailable property replacing GitAvailable
affects: [07-02-navigation-popup-migration, 08-vcs-discovery]

# Tech tracking
tech-stack:
  added: []
  patterns: [provider-dispatch via IVCSProvider in engine and thread classes]

key-files:
  created: []
  modified:
    - src/DX.Blame.Engine.pas
    - src/DX.Blame.CommitDetail.pas
    - src/DX.Blame.Navigation.pas

key-decisions:
  - "TBlameThread holds IVCSProvider interface reference (ref-counted) instead of string path"
  - "FetchCommitDetailAsync takes IVCSProvider as first parameter -- breaking change resolved in Plan 02"

patterns-established:
  - "Provider-dispatch: threads receive IVCSProvider and call provider methods instead of creating TGitProcess directly"

requirements-completed: [VCSA-05]

# Metrics
duration: 4min
completed: 2026-03-24
---

# Phase 7 Plan 1: Engine VCS Dispatch Summary

**Engine and CommitDetail refactored to dispatch all VCS operations through IVCSProvider instead of direct Git unit calls**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-24T09:19:28Z
- **Completed:** 2026-03-24T09:24:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- TBlameEngine owns FProvider: IVCSProvider, creates TGitProvider in Initialize, dispatches blame through provider
- TBlameThread receives IVCSProvider and calls ExecuteBlame/ParseBlameOutput (no more TGitProcess)
- TCommitDetailThread receives IVCSProvider and calls GetCommitMessage/GetFileDiff/GetFullDiff
- FetchCommitDetailAsync has IVCSProvider as first parameter
- Both Engine and CommitDetail implementation sections have zero Git-specific unit imports (except Git.Provider for TGitProvider.Create in Engine)
- GitAvailable property renamed to VCSAvailable throughout

## Task Commits

Each task was committed atomically:

1. **Task 1: Refactor Engine to use IVCSProvider** - `04d06b7` (feat)
2. **Task 2: Refactor CommitDetail to accept IVCSProvider** - `1ca49e8` (feat)

## Files Created/Modified
- `src/DX.Blame.Engine.pas` - Provider-dispatched blame engine with FProvider field, VCSAvailable property, provider-injected TBlameThread
- `src/DX.Blame.CommitDetail.pas` - Provider-dispatched commit detail fetch, FetchCommitDetailAsync with IVCSProvider parameter
- `src/DX.Blame.Navigation.pas` - Updated GitAvailable references to VCSAvailable

## Decisions Made
- TBlameThread holds IVCSProvider as interface field for correct reference counting (no manual Free needed)
- FetchCommitDetailAsync takes IVCSProvider as first parameter, breaking downstream callers (Popup, Diff.Form) which will be fixed in Plan 02

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated Navigation.pas GitAvailable references to VCSAvailable**
- **Found during:** Task 1 (Engine refactoring)
- **Issue:** DX.Blame.Navigation.pas referenced BlameEngine.GitAvailable which was renamed to VCSAvailable, causing compile failure
- **Fix:** Updated both references in Navigation.pas to use VCSAvailable
- **Files modified:** src/DX.Blame.Navigation.pas
- **Verification:** Package compiles successfully after fix
- **Committed in:** 04d06b7 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary fix for compilation. Navigation.pas was planned for Plan 02 but the property rename in Engine made it a blocker.

## Issues Encountered
- Compilation fails after Task 2 due to Diff.Form.pas and Popup.pas calling FetchCommitDetailAsync with old signature (missing IVCSProvider parameter). This is expected and documented in the plan -- resolved in Plan 02.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Engine and CommitDetail are fully provider-dispatched
- Plan 02 needs to update Popup.pas and Diff.Form.pas to pass BlameEngine.Provider to FetchCommitDetailAsync
- Navigation.pas already has VCSAvailable fix, but still needs provider parameter for any FetchCommitDetailAsync calls

## Self-Check: PASSED

All files exist, all commits verified.

---
*Phase: 07-engine-vcs-dispatch*
*Completed: 2026-03-24*
