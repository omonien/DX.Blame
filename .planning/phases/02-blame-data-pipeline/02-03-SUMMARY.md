---
phase: 02-blame-data-pipeline
plan: 03
subsystem: blame-engine-integration
tags: [async-threading, debounce, cancellation, ota-notifiers, tthread-queue, singleton]

# Dependency graph
requires:
  - phase: 02-blame-data-pipeline
    plan: 01
    provides: TGitProcess, FindGitExecutable, FindGitRepoRoot, TBlameLineInfo, TBlameData
  - phase: 02-blame-data-pipeline
    plan: 02
    provides: ParseBlameOutput, TBlameCache
provides:
  - TBlameEngine central orchestrator with async blame lifecycle
  - TBlameThread background execution with TThread.Queue result delivery
  - TDXBlameIDENotifier for file open/close/project switch events
  - TDXBlameModuleNotifier for save-triggered re-blame
  - Full plugin lifecycle wiring in Registration.pas
affects: [03-rendering-ux, 04-tooltip-detail]

# Tech tracking
tech-stack:
  added: [Vcl.ExtCtrls/TTimer, System.SyncObjs/TCriticalSection, ToolsAPI/IOTAIDENotifier, ToolsAPI/IOTAModuleNotifier]
  patterns: [singleton-lazy-init, debounce-timer, thread-queue-callback, forward-declaration, ota-notifier-lifecycle]

key-files:
  created:
    - src/DX.Blame.Engine.pas
    - src/DX.Blame.IDE.Notifier.pas
  modified:
    - src/DX.Blame.Registration.pas
    - src/DX.Blame.dpk

key-decisions:
  - "TBlameThread holds engine reference instead of TProc callbacks to avoid anonymous method type incompatibility"
  - "Delphi 13 requires initialization section before finalization (new compiler strictness)"
  - "Module notifiers managed per-file in TDictionary for clean attach/detach on open/close"
  - "Notifier cleanup in finalization runs before menu/wizard cleanup (reverse registration order)"

patterns-established:
  - "Engine singleton: unit-level function with lazy init, freed in finalization"
  - "Debounce pattern: TTimer per-file in dictionary, reset on repeat, fire-once then free"
  - "Retry pattern: TDictionary<string,Boolean> tracks first-failure, one-shot retry timer"
  - "OTA lifecycle: RegisterIDENotifiers in Register, UnregisterIDENotifiers in finalization"

requirements-completed: [BLAME-02, BLAME-03, BLAME-04, BLAME-05, BLAME-06]

# Metrics
duration: 12min
completed: 2026-03-19
---

# Phase 2 Plan 03: Engine and IDE Integration Summary

**TBlameEngine async orchestrator with TThread.Queue, debounce timers, cancellation, and OTA notifiers wiring file open/close/save into the blame pipeline**

## Performance

- **Duration:** 12 min
- **Started:** 2026-03-19T19:35:35Z
- **Completed:** 2026-03-19T19:48:02Z
- **Tasks:** 2
- **Files created:** 2
- **Files modified:** 2

## Accomplishments

- TBlameEngine orchestrates full async blame lifecycle: request, execute in background thread, parse, cache, cancel, retry, debounce
- TBlameThread runs git blame --line-porcelain in background and delivers parsed TBlameData via TThread.Queue to main thread
- TDXBlameIDENotifier hooks ofnFileOpened (triggers blame), ofnFileClosing (cancels + clears), ofnProjectDesktopLoad (full switch)
- TDXBlameModuleNotifier hooks AfterSave for debounced re-blame on file save
- Registration.pas wires everything: RegisterIDENotifiers + BlameEngine.Initialize in Register, clean reverse-order finalization
- All 28 existing tests still pass -- no regressions

## Task Commits

Each task was committed atomically:

1. **Task 1: Create blame engine with async threading and debounce** - `a6b242e` (feat)
2. **Task 2: Create IDE notifier and wire into Registration.pas** - `eed3eb5` (feat)

## Files Created/Modified

- `src/DX.Blame.Engine.pas` - TBlameEngine orchestrator, TBlameThread, BlameEngine singleton, debounce/retry/cancel logic
- `src/DX.Blame.IDE.Notifier.pas` - TDXBlameIDENotifier (file events), TDXBlameModuleNotifier (save detection), register/unregister pair
- `src/DX.Blame.Registration.pas` - Added notifier registration + engine initialization in Register, notifier cleanup in finalization
- `src/DX.Blame.dpk` - All 9 production units in dependency order

## Decisions Made

- Used engine reference pattern (TBlameThread.FEngine) instead of TProc callbacks to avoid Delphi generic anonymous method type incompatibility with method references
- Discovered Delphi 13 (37.0) requires `initialization` section before `finalization` -- standalone `finalization` triggers E2029
- Module notifiers tracked in TDictionary keyed by lowercase filename for O(1) attach/detach on file open/close
- Finalization order: notifiers first, then menu, then wizard, then about box (reverse of registration)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] TProc callback type incompatibility with method references**
- **Found during:** Task 1 (Engine compilation)
- **Issue:** TProc<string, TBlameData> and TProc<string, string> cannot be assigned from anonymous methods wrapping method references in Delphi 13
- **Fix:** Changed TBlameThread to hold a TBlameEngine reference and call HandleBlameComplete/HandleBlameError directly via TThread.Queue
- **Files modified:** src/DX.Blame.Engine.pas
- **Committed in:** a6b242e (Task 1 commit)

**2. [Rule 3 - Blocking] Delphi 13 requires initialization before finalization**
- **Found during:** Task 1 (Engine compilation)
- **Issue:** Delphi 37.0 compiler rejects standalone `finalization` section with E2029 "Declaration expected but FINALIZATION found"
- **Fix:** Added empty `initialization` section before `finalization` in DX.Blame.Engine.pas
- **Files modified:** src/DX.Blame.Engine.pas
- **Committed in:** a6b242e (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both fixes necessary for compilation. No scope creep.

## Issues Encountered

None beyond the auto-fixed compiler issues documented above.

## User Setup Required

None.

## Next Phase Readiness

- Complete Phase 2 data pipeline is functional: file open triggers async blame, results land in cache, saves re-trigger, close cancels
- Phase 3 (Rendering + UX) can hook into BlameEngine.HandleBlameComplete to trigger UI repaint
- Phase 3 can read cached blame data via BlameEngine.Cache.TryGet for editor gutter rendering
- 9 production units and 28 tests provide solid foundation for UI integration

---
*Phase: 02-blame-data-pipeline*
*Completed: 2026-03-19*
