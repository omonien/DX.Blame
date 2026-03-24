# Phase 7: Engine VCS Dispatch - Research

**Researched:** 2026-03-24
**Domain:** Delphi refactoring -- routing VCS calls through IVCSProvider interface
**Confidence:** HIGH

## Summary

Phase 7 is a pure refactoring phase. The IVCSProvider interface and TGitProvider implementation already exist from Phase 6. The task is to make four consumer units (Engine, CommitDetail, Navigation, Popup) stop importing Git-specific units directly and instead route all VCS operations through the provider interface.

The codebase is well-structured with clear seams. Every Git-specific call in the consumers has an exact counterpart in IVCSProvider. The main architectural decision is where IVCSProvider lives (ownership/lifecycle) and how it gets passed to the various consumers. The engine is the natural owner since it already handles initialization and project switching.

**Primary recommendation:** Store IVCSProvider as a field on TBlameEngine, create TGitProvider in Initialize, expose it as a property, and have CommitDetail/Navigation/Popup access it via BlameEngine.Provider.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None -- all decisions in this phase are Claude's discretion.

### Claude's Discretion
- **Provider ownership & lifecycle** -- Where IVCSProvider is created, stored, and how it's made available to Engine, CommitDetail, Navigation, and Popup. Must account for Phase 8 (VCS Discovery) needing to swap providers later.
- **CommitDetail threading** -- How TCommitDetailThread transitions from direct TGitProcess/FindGitExecutable calls to provider-based dispatch. Thread-safety considerations for the provider reference.
- **Sentinel constant migration** -- Whether cUncommittedHash/cNotCommittedAuthor move to VCS.Types as shared defaults or are always queried via provider methods (provider already has GetUncommittedHash/GetUncommittedAuthor from Phase 6).
- **Uses clause cleanup** -- Which Git-specific unit references to remove from consumer units, and how to handle any remaining Git.Types references.

### Deferred Ideas (OUT OF SCOPE)
None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| VCSA-05 | Engine dispatches all VCS operations through IVCSProvider (no direct Git calls) | All four consumer units mapped with exact Git call sites and their IVCSProvider replacements. Architecture pattern for provider ownership documented. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| IVCSProvider | from Phase 6 | VCS-neutral dispatch interface | Already defined with full API surface |
| TGitProvider | from Phase 6 | Git backend implementation | Already delegates to existing Git units |
| TVCSProcess | from Phase 6 | Base process class with CancelProcess | Already VCS-neutral |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| DX.Blame.VCS.Types | from Phase 6 | TBlameLineInfo, TBlameData, constants | All consumer units already use this |
| DX.Blame.VCS.Provider | from Phase 6 | IVCSProvider interface definition | Add to uses clauses replacing Git units |

No new libraries or packages needed. This is purely rewiring existing code.

## Architecture Patterns

### Provider Ownership -- Engine as Provider Host

**What:** TBlameEngine owns the IVCSProvider reference. All other units access it via `BlameEngine.Provider`.

**Why this pattern:**
1. Engine already manages the VCS lifecycle (Initialize, OnProjectSwitch, ClearDiscoveryCache)
2. Engine is already a singleton accessed globally
3. Phase 8 (VCS Discovery) will need to swap providers -- having a single owner makes this trivial
4. All consumers already reference BlameEngine (Navigation, Popup both call BlameEngine.GitAvailable, BlameEngine.RepoRoot)

**Structure:**
```pascal
TBlameEngine = class
private
  FProvider: IVCSProvider;
  FVCSAvailable: Boolean;  // renamed from FGitAvailable
  FVCSNotified: Boolean;   // renamed from FGitNotified
public
  property Provider: IVCSProvider read FProvider;
  property VCSAvailable: Boolean read FVCSAvailable;  // renamed from GitAvailable
  // GitAvailable kept temporarily as alias if needed for compilation
end;
```

### Provider Injection into Threads

**What:** Pass the IVCSProvider reference into TBlameThread and TCommitDetailThread constructors, not re-discover it each time.

**Why:** Threads currently call FindGitExecutable independently (CommitDetail does this). By passing the provider, we eliminate redundant discovery and ensure the thread uses the same provider instance the engine has.

**Thread-safety note:** IVCSProvider is reference-counted (TInterfacedObject). Passing it to a thread creates an additional reference, preventing premature destruction. The provider's methods create fresh TVCSProcess instances per call, so there is no shared mutable state. This is inherently thread-safe.

```pascal
TBlameThread = class(TThread)
private
  FProvider: IVCSProvider;
  FRepoRoot: string;
  FFileName: string;
  FProcessHandle: THandle;
  FEngine: TBlameEngine;
  // FGitPath removed -- no longer needed
end;

TCommitDetailThread = class(TThread)
private
  FProvider: IVCSProvider;
  FCommitHash: string;
  FRepoRoot: string;
  FRelativeFilePath: string;
  FOnComplete: TCommitDetailCompleteEvent;
end;
```

### Sentinel Constants Strategy

**Recommendation:** Query sentinels via provider methods (GetUncommittedHash, GetUncommittedAuthor).

**Rationale:**
- Different VCS backends may have different sentinel values (Git uses 40 zeros, Mercurial may use different format)
- The provider already exposes these methods
- Popup uses `cNotCommittedAuthor` (line 194) and Navigation uses `cUncommittedHash` (line 108) -- both can call `BlameEngine.Provider.GetUncommittedHash/GetUncommittedAuthor`
- Avoids importing DX.Blame.Git.Types entirely

**Alternative considered:** Move constants to VCS.Types as shared defaults. Rejected because it would couple VCS.Types to Git-specific values and require Mercurial to override them.

### Process Cancellation Pattern

**What:** TBlameThread.Cancel currently calls `TGitProcess.CancelProcess(FProcessHandle)`. Since CancelProcess is a class method on TVCSProcess (the base class), change this to `TVCSProcess.CancelProcess(FProcessHandle)`.

**Note:** This is purely a reference change. CancelProcess is already defined on TVCSProcess, not TGitProcess. The code just references it through the subclass name.

### Unit Dependency Map (Before -> After)

| Unit | Before (Git-specific uses) | After (VCS-neutral uses) |
|------|---------------------------|-------------------------|
| DX.Blame.Engine | Git.Discovery, Git.Process, Git.Blame | VCS.Provider, VCS.Process (for CancelProcess only) |
| DX.Blame.CommitDetail | Git.Discovery, Git.Process | VCS.Provider |
| DX.Blame.Navigation | Git.Types, Git.Discovery, Git.Process | VCS.Provider (via BlameEngine.Provider) |
| DX.Blame.Popup | Git.Types | VCS.Provider (via BlameEngine.Provider) |

### Recommended Change Sequence

1. **Engine first** -- Add FProvider field, create TGitProvider in Initialize, rename FGitAvailable/FGitPath, refactor TBlameThread
2. **CommitDetail second** -- Pass provider into TCommitDetailThread, update FetchCommitDetailAsync signature
3. **Navigation third** -- Replace GetFileAtCommit internals, replace cUncommittedHash with provider call, replace GitAvailable check
4. **Popup last** -- Replace cNotCommittedAuthor with provider call, remove Git.Types from uses

### Anti-Patterns to Avoid

- **Creating provider per operation:** Do NOT instantiate TGitProvider in each thread or call site. One provider per engine lifecycle.
- **Storing provider in global var outside engine:** Breaks Phase 8 swapping. Engine must be the single owner.
- **Keeping GitAvailable as the only property name:** Rename to VCSAvailable for clarity. Can keep GitAvailable as deprecated alias temporarily if needed for compilation, but the primary property should be VCS-neutral.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Blame execution dispatch | Custom conditional logic per VCS type | IVCSProvider.ExecuteBlame + ParseBlameOutput | Already implemented in TGitProvider |
| Commit detail fetching | Inline TGitProcess creation | IVCSProvider.GetCommitMessage/GetFileDiff/GetFullDiff | Already implemented |
| File-at-revision retrieval | Inline TGitProcess creation | IVCSProvider.GetFileAtRevision | Already implemented |
| Discovery (exe + repo root) | Direct FindGitExecutable/FindGitRepoRoot calls | IVCSProvider.FindExecutable/FindRepoRoot | Already implemented |
| Process cancellation | Git-specific cancellation | TVCSProcess.CancelProcess (base class) | Already VCS-neutral |

## Common Pitfalls

### Pitfall 1: FetchCommitDetailAsync Signature Change
**What goes wrong:** FetchCommitDetailAsync is a module-level procedure. Changing its signature to accept IVCSProvider breaks all callers (Popup, Diff.Form).
**Why it happens:** CommitDetailThread currently discovers Git internally, so the caller doesn't pass a provider. Adding a provider parameter changes the public API.
**How to avoid:** Add `AProvider: IVCSProvider` as the first parameter to both FetchCommitDetailAsync and TCommitDetailThread.Create. Update all three call sites: Popup.ShowForCommit, Popup.UpdateContent, Diff.Form.ShowDiff/DoToggleScopeClick.
**Warning signs:** Compilation errors in Popup and Diff.Form units.

### Pitfall 2: Interface Reference Counting in Threads
**What goes wrong:** If the provider is stored as a raw pointer rather than an interface reference in the thread, it could be freed while the thread is still running.
**Why it happens:** Delphi interface reference counting only works when stored in interface-typed variables.
**How to avoid:** Always store provider as `IVCSProvider` (not as a class reference or untyped pointer) in thread fields. This guarantees the reference count stays above zero while the thread lives.
**Warning signs:** Access violations during background blame execution after project switch.

### Pitfall 3: ClearDiscoveryCache Direct Call in OnProjectSwitch
**What goes wrong:** Engine.OnProjectSwitch line 409 calls `ClearDiscoveryCache` directly from the Git.Discovery unit. This must route through the provider.
**How to avoid:** Replace with `FProvider.ClearDiscoveryCache` (or nil-check first if provider may not exist yet).
**Warning signs:** Compilation error about undeclared identifier after removing Git.Discovery from uses.

### Pitfall 4: Property Rename Breaking External References
**What goes wrong:** Renaming GitAvailable to VCSAvailable breaks Navigation.OnRevisionClick (line 212) and Navigation.OnEditorPopup (line 252).
**How to avoid:** Either rename all references in the same commit, or add VCSAvailable as new property and deprecate GitAvailable.
**Warning signs:** Compilation errors in Navigation unit.

### Pitfall 5: Popup and Diff.Form Also Need Provider Access
**What goes wrong:** Popup calls FetchCommitDetailAsync which internally discovers Git. Diff.Form also calls FetchCommitDetailAsync. Both need the provider passed through.
**How to avoid:** Since both Popup and Diff.Form already access BlameEngine (Popup indirectly via ShowForCommit parameters, Diff.Form via FetchCommitDetailAsync), pass `BlameEngine.Provider` to FetchCommitDetailAsync calls.
**Warning signs:** CommitDetail thread still calling FindGitExecutable directly.

## Code Examples

### Engine Initialize with Provider

```pascal
procedure TBlameEngine.Initialize(const AProjectPath: string);
var
  LExePath: string;
begin
  // Create provider (hardcoded to Git for now; Phase 8 will add discovery)
  FProvider := TGitProvider.Create;

  LExePath := FProvider.FindExecutable;
  if LExePath = '' then
  begin
    FVCSAvailable := False;
    if not FVCSNotified then
    begin
      FVCSNotified := True;
      LogToIDE('DX.Blame: VCS executable not found. Blame features disabled.');
    end;
    Exit;
  end;

  FRepoRoot := FProvider.FindRepoRoot(AProjectPath);
  if FRepoRoot = '' then
  begin
    FVCSAvailable := False;
    Exit;
  end;

  FVCSAvailable := True;
end;
```

### TBlameThread.Execute with Provider

```pascal
procedure TBlameThread.Execute;
var
  LOutput: string;
  LLines: TArray<TBlameLineInfo>;
  LData: TBlameData;
  LExitCode: Integer;
begin
  LExitCode := FProvider.ExecuteBlame(FRepoRoot, FFileName, LOutput, FProcessHandle);

  if Terminated then
    Exit;

  if LExitCode = 0 then
  begin
    LLines := FProvider.ParseBlameOutput(LOutput);
    LData := TBlameData.Create(FFileName);
    LData.Lines := LLines;
    LData.Timestamp := Now;
    // ... Queue result to main thread (same pattern as current)
  end;
end;
```

### TCommitDetailThread.Execute with Provider

```pascal
procedure TCommitDetailThread.Execute;
var
  LDetail: TCommitDetail;
  LOutput: string;
begin
  // Fetch full commit message
  if FProvider.GetCommitMessage(FRepoRoot, FCommitHash, LOutput) then
    LDetail.FullMessage := LOutput;

  if Terminated then Exit;

  // Fetch file-specific diff
  if FRelativeFilePath <> '' then
    FProvider.GetFileDiff(FRepoRoot, FCommitHash, FRelativeFilePath, LDetail.FileDiff);

  if Terminated then Exit;

  // Fetch full commit diff
  FProvider.GetFullDiff(FRepoRoot, FCommitHash, LDetail.FullDiff);

  LDetail.Fetched := True;

  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FOnComplete) then
        FOnComplete(LDetail);
    end);
end;
```

### Navigation GetFileAtCommit via Provider

```pascal
function GetFileAtCommit(const ACommitHash, ARelativePath, ARepoRoot: string): string;
var
  LContent: string;
begin
  Result := '';
  if BlameEngine.Provider = nil then
    Exit;

  if BlameEngine.Provider.GetFileAtRevision(ARepoRoot, ACommitHash, ARelativePath, LContent) then
    Result := LContent;
end;
```

### Popup Sentinel via Provider

```pascal
// Before:
AuthorLabel.Caption := cNotCommittedAuthor;  // from Git.Types

// After:
AuthorLabel.Caption := BlameEngine.Provider.GetUncommittedAuthor;
```

### Navigation IsRevisionAvailable via Provider

```pascal
// Before:
Result := (ACommitHash <> '') and (ACommitHash <> cUncommittedHash);  // from Git.Types

// After -- needs provider passed in or accessed via engine:
function IsRevisionAvailable(const ACommitHash: string): Boolean;
begin
  Result := (ACommitHash <> '') and (BlameEngine.Provider <> nil) and
    (ACommitHash <> BlameEngine.Provider.GetUncommittedHash);
end;
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Direct Git unit imports | IVCSProvider interface | Phase 6 (v1.1) | Interface and Git provider exist, consumers not yet migrated |
| TGitProcess in consumers | Provider dispatches internally | Phase 6 (v1.1) | TGitProvider wraps all Git calls |
| Git.Types constants in consumers | Provider.GetUncommittedHash/Author | Phase 6 (v1.1) | Methods exist, consumers still use constants directly |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | DUnitX (Git submodule under libs/) |
| Config file | tests/DX.Blame.Tests.dproj |
| Quick run command | `powershell -File build/DelphiBuildDPROJ.ps1 tests/DX.Blame.Tests.dproj` |
| Full suite command | `powershell -File build/DelphiBuildDPROJ.ps1 tests/DX.Blame.Tests.dproj && build\Win64\Debug\DX.Blame.Tests.exe` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VCSA-05 | Engine uses no direct Git calls; all operations route through IVCSProvider | manual-only | Compile all units and verify no Git-specific units in consumer uses clauses | N/A |
| VCSA-05 | Existing blame functionality unchanged | smoke | Run existing test suite (Cache, Formatter, CommitDetail tests) | Yes |

**Manual-only justification for VCSA-05 primary check:** The requirement is about code structure (no direct Git imports), not runtime behavior. Verified by compilation and uses-clause inspection. Runtime behavior is validated by existing tests continuing to pass.

### Sampling Rate
- **Per task commit:** Compile all affected units via DelphiBuildDPROJ.ps1
- **Per wave merge:** Full test suite run
- **Phase gate:** Full suite green + manual uses-clause audit

### Wave 0 Gaps
None -- existing test infrastructure covers smoke testing. The primary verification is compilation success and uses-clause inspection, not new test files.

## Open Questions

1. **Property rename timing (GitAvailable -> VCSAvailable)**
   - What we know: Navigation and internal engine code reference GitAvailable
   - What's unclear: Whether to do a clean rename or keep a deprecated alias
   - Recommendation: Clean rename in same commit since all references are internal to the plugin. No external consumers.

2. **FetchCommitDetailAsync signature stability**
   - What we know: Adding IVCSProvider parameter changes the public API of CommitDetail unit
   - What's unclear: Whether Diff.Form should also hold its own provider reference or always go through the async API
   - Recommendation: Pass provider to FetchCommitDetailAsync. Diff.Form accesses it via BlameEngine.Provider at call sites. Simple and consistent.

## Sources

### Primary (HIGH confidence)
- Direct source code analysis of all affected units in Y:\DX.Blame\src\
- IVCSProvider interface definition (DX.Blame.VCS.Provider.pas)
- TGitProvider implementation (DX.Blame.Git.Provider.pas)
- All four consumer units fully read and mapped

### Secondary (MEDIUM confidence)
- Phase 6 completed implementation context from STATE.md
- Phase 7 CONTEXT.md user decisions

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All components exist from Phase 6, verified by reading source
- Architecture: HIGH - Provider-host pattern is straightforward; all call sites mapped
- Pitfalls: HIGH - Every Git call site identified with exact line numbers

**Research date:** 2026-03-24
**Valid until:** Indefinite (pure refactoring of existing codebase, no external dependencies)
