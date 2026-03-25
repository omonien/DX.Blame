# Phase 11: Engine Project-Switch Lifecycle Fix - Research

**Researched:** 2026-03-25
**Domain:** Delphi TTimer lifecycle management in IDE plugin engine
**Confidence:** HIGH

## Summary

Phase 11 is a surgical gap closure phase addressing two bugs identified in the v1.1 milestone audit (MISS-1 and MISS-2). Both bugs live in `DX.Blame.Engine.pas` and concern state that is not properly reset during `OnProjectSwitch`.

**MISS-1** is a retry timer leak: `HandleBlameError` (line 467) creates a `TTimer` for retry logic but never tracks it in any collection. `ClearAllTimers` only clears `FDebounceTimers`, so retry timers survive project switches and fire `DoRetryBlame` with stale file paths. The fix requires a dedicated `FRetryTimers` dictionary parallel to `FDebounceTimers`, with cleanup in `ClearAllTimers`.

**MISS-2** is a notification flag suppression: `FVCSNotified` is set to `True` when a "No VCS detected" message is logged, but `OnProjectSwitch` never resets it to `False`. If a user switches from a non-VCS project to another non-VCS project, the diagnostic message is suppressed. The fix is a single line: `FVCSNotified := False` in `OnProjectSwitch` before `Initialize`.

**Primary recommendation:** Add `FRetryTimers: TDictionary<string, TTimer>` field, track retry timers by file key, cancel them in `ClearAllTimers`, and add `FVCSNotified := False` to `OnProjectSwitch`. One plan, two tasks, single file modified.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| VCSA-05 | Engine dispatches all VCS operations through IVCSProvider (no direct Git calls) | MISS-1 fix ensures retry timers don't fire stale blame requests after project switch, maintaining clean provider dispatch lifecycle |
| VCSD-05 | Active VCS backend is indicated in IDE Messages | MISS-2 fix ensures the "No VCS detected" diagnostic is shown per-project, not suppressed after first occurrence |
</phase_requirements>

## Standard Stack

Not applicable -- this phase modifies a single existing file (`DX.Blame.Engine.pas`) using only RTL types already present in the unit. No new libraries or dependencies.

### Existing Dependencies Used
| Type | Unit | Purpose |
|------|------|---------|
| `TDictionary<string, TTimer>` | System.Generics.Collections | Already used for FDebounceTimers; same pattern for FRetryTimers |
| `TTimer` | Vcl.ExtCtrls | Already used for debounce and retry timers |
| `TCriticalSection` | System.SyncObjs | Already used for FLock; protects new collection too |

## Architecture Patterns

### Pattern 1: Tracked Timer Collection (existing pattern)

**What:** Every TTimer created by the engine is stored in a `TDictionary<string, TTimer>` keyed by lowercase filename, enabling deterministic cleanup.

**When to use:** Always -- untracked timers are the root cause of MISS-1.

**Existing example (FDebounceTimers):**
```pascal
// From DX.Blame.Engine.pas lines 296-321
// Timer created and immediately stored in dictionary
LTimer := TTimer.Create(nil);
LTimer.Interval := cDefaultDebounceMs;
LTimer.OnTimer := DoRequestBlame;
LTimer.Enabled := True;
FDebounceTimers.AddOrSetValue(LKey, LTimer);
```

**Cleanup pattern (ClearAllTimers):**
```pascal
// From DX.Blame.Engine.pas lines 547-562
for LPair in FDebounceTimers do
begin
  LPair.Value.Enabled := False;
  LPair.Value.Free;
end;
FDebounceTimers.Clear;
```

The retry timer fix must follow this identical pattern: create, store in `FRetryTimers`, and clean up in `ClearAllTimers`.

### Pattern 2: OnProjectSwitch Full Reset

**What:** `OnProjectSwitch` is the engine's lifecycle boundary -- it must reset ALL mutable state before re-initializing.

**Current reset sequence (line 388-400):**
1. `CancelAllThreads` -- cancels background threads
2. `ClearAllTimers` -- frees debounce timers (will also free retry timers after fix)
3. `FCache.Clear` -- clears blame data cache
4. `CommitDetailCache.Clear` -- clears commit detail cache
5. `FRetryFailed.Clear` -- clears retry-failed flags
6. `FProvider := nil` -- releases VCS provider interface
7. Clear discovery caches (Git + Hg)
8. `Initialize(ANewProjectPath)` -- re-detect VCS for new project

**Missing:** `FVCSNotified := False` must be added before step 8 (Initialize).

### Anti-Patterns to Avoid
- **Untracked resource creation:** Never create a TTimer (or any owned resource) without immediately storing it in a collection that participates in cleanup. This is the exact bug being fixed.
- **Partial state reset:** When adding new fields to the engine, always check whether they need clearing in `OnProjectSwitch`. This is a maintenance discipline issue.

## Don't Hand-Roll

Not applicable -- this phase uses only existing Delphi RTL types and established project patterns.

## Common Pitfalls

### Pitfall 1: DoRetryBlame Timer-to-Key Mapping
**What goes wrong:** The current `DoRetryBlame` finds the file key by scanning `FRetryFailed` for entries without active threads -- it does not know which file the timer belongs to.
**Why it happens:** The retry timer is not associated with any key; it just fires and picks the first eligible retry candidate.
**How to avoid:** With `FRetryTimers` keyed by filename, `DoRetryBlame` can look up the timer's key directly (same reverse-lookup pattern as `DoRequestBlame` uses with `FDebounceTimers`). This is a design improvement but NOT strictly required -- the existing scan approach still works correctly when combined with proper cleanup.
**Recommendation:** Keep the existing `DoRetryBlame` scan logic to minimize change surface. The critical fix is tracking + cleanup, not changing the dispatch mechanism.

### Pitfall 2: Race Between Timer Fire and ClearAllTimers
**What goes wrong:** A retry timer could fire (queuing DoRetryBlame to main thread) at the exact moment OnProjectSwitch runs ClearAllTimers.
**Why it happens:** TTimer.OnTimer fires on the main thread; OnProjectSwitch also runs on the main thread. Since both are main-thread operations, they are serialized -- no actual race condition exists.
**How to avoid:** No special handling needed. Delphi's single-threaded message pump guarantees OnTimer and OnProjectSwitch cannot interleave.

### Pitfall 3: Multiple Retry Timers for Same File
**What goes wrong:** If `HandleBlameError` is called twice for the same file before the first retry fires, two timers would be created.
**Why it happens:** The current code checks `FRetryFailed.ContainsKey` to prevent double-retry, so this cannot happen in practice. But with `FRetryTimers`, the `AddOrSetValue` pattern should be used (not `Add`) as defensive coding.
**How to avoid:** Use `FRetryTimers.AddOrSetValue(LKey, LRetryTimer)` and free any pre-existing timer before creating a new one.

## Code Examples

### Fix 1: Add FRetryTimers Field

```pascal
// In TBlameEngine private section, add after FDebounceTimers:
FRetryTimers: TDictionary<string, TTimer>;
```

### Fix 2: Create/Destroy FRetryTimers

```pascal
// In constructor, after FDebounceTimers creation:
FRetryTimers := TDictionary<string, TTimer>.Create;

// In destructor, after ClearAllTimers (which now cleans retry timers):
FRetryTimers.Free;
```

### Fix 3: Track Retry Timer in HandleBlameError

```pascal
// In HandleBlameError, after creating LRetryTimer:
LRetryTimer := TTimer.Create(nil);
LRetryTimer.Interval := cDefaultRetryDelayMs;
LRetryTimer.OnTimer := DoRetryBlame;
LRetryTimer.Enabled := True;

FLock.Enter;
try
  FRetryTimers.AddOrSetValue(LKey, LRetryTimer);
finally
  FLock.Leave;
end;
```

### Fix 4: Clean Retry Timers in ClearAllTimers

```pascal
// In ClearAllTimers, add after FDebounceTimers cleanup:
for LPair in FRetryTimers do
begin
  LPair.Value.Enabled := False;
  LPair.Value.Free;
end;
FRetryTimers.Clear;
```

Note: `LPair` variable declaration needs adjusting since `FRetryTimers` is `TDictionary<string, TTimer>` (same type as FDebounceTimers), so the existing `LPair: TPair<string, TTimer>` works for both loops.

### Fix 5: Remove Retry Timer in DoRetryBlame

```pascal
// In DoRetryBlame, after disabling/freeing the timer, remove from FRetryTimers:
FLock.Enter;
try
  for LPair in FRetryTimers do
  begin
    if LPair.Value = LTimer then
    begin
      FRetryTimers.Remove(LPair.Key);
      Break;
    end;
  end;
finally
  FLock.Leave;
end;
```

### Fix 6: Reset FVCSNotified in OnProjectSwitch

```pascal
// In OnProjectSwitch, add before Initialize call:
FVCSNotified := False;
Initialize(ANewProjectPath);
```

## State of the Art

Not applicable -- this is a bugfix phase using established Delphi patterns. No technology changes or version concerns.

## Open Questions

None. Both bugs are fully characterized in the milestone audit with clear, verified fix strategies. The source code has been read and the fix locations confirmed.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | DUnitX (submodule in libs/) |
| Config file | tests/ directory (project convention) |
| Quick run command | `powershell -File build/DelphiBuildDPROJ.ps1 -Project tests/*.dproj` |
| Full suite command | Same (single test project) |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VCSA-05 | Retry timers cancelled on project switch | manual-only | Compile + IDE test: trigger blame error, switch project, verify no stale retry | N/A |
| VCSD-05 | FVCSNotified reset per project | manual-only | Compile + IDE test: open non-VCS project, switch to another non-VCS, verify message appears | N/A |

**Justification for manual-only:** Both behaviors require the Delphi IDE runtime (BorlandIDEServices, IOTAMessageServices, TThread.Queue to main thread). Unit testing TTimer lifecycle in an IDE plugin is not feasible without the host IDE. Verification is compilation success + manual IDE testing.

### Sampling Rate
- **Per task commit:** Compile with `DelphiBuildDPROJ.ps1`
- **Per wave merge:** Full compile + manual IDE verification
- **Phase gate:** Compilation green, both behaviors verified in IDE

### Wave 0 Gaps
None -- no automated test infrastructure changes needed. This is a single-file bugfix verified by compilation and manual testing.

## Sources

### Primary (HIGH confidence)
- `src/DX.Blame.Engine.pas` -- full source read, all line references verified against current code
- `.planning/v1.1-MILESTONE-AUDIT.md` -- MISS-1 and MISS-2 descriptions and fix recommendations
- `.planning/ROADMAP.md` -- Phase 11 success criteria and requirements mapping

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no new dependencies, only existing RTL types
- Architecture: HIGH - follows existing FDebounceTimers pattern exactly
- Pitfalls: HIGH - single-file change with well-understood Delphi main-thread TTimer behavior

**Research date:** 2026-03-25
**Valid until:** indefinite (Delphi RTL TTimer/TDictionary are stable APIs)
