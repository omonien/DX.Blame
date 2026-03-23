# Phase 6: VCS Abstraction Foundation - Research

**Researched:** 2026-03-23
**Domain:** Delphi OOP refactoring — extracting VCS-neutral abstractions from Git-specific units
**Confidence:** HIGH

## Summary

This phase is a pure refactoring task within an existing, working Delphi IDE plugin. The goal is to extract VCS-neutral types, a shared process base class, and a provider interface from the existing Git-specific implementation. No new external libraries are needed — this is structural reorganization using standard Delphi language features (interfaces, inheritance, unit renaming).

The codebase is compact (17 units) with a clear dependency graph. Six units currently reference `DX.Blame.Git.Types` in their `uses` clauses, four reference `DX.Blame.Git.Process`, and three reference `DX.Blame.Git.Discovery`. The refactoring must touch all of these without breaking the existing blame pipeline. The key risk is introducing a compilation error in the unit dependency chain that blocks the entire package from loading in the IDE.

**Primary recommendation:** Work in strict dependency order — create VCS.Types first (leaf unit, no dependencies), then VCS.Process (depends only on WinAPI), then the IVCSProvider interface, then TGitProvider wrapper, then update all consumers. Each step must compile before proceeding to the next.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- TVCSProcess is the base class owning all CreateProcess+pipe capture logic (Execute, ExecuteAsync, CancelProcess)
- TGitProcess and future THgProcess are thin subclasses that only pass the correct executable path
- CancelProcess remains a class method on TVCSProcess (callable without instance, just needs handle)
- The duplicated ExecuteGitSync in Git.Discovery is eliminated — discovery units use TVCSProcess.Execute instead
- TVCSProcess lives in its own unit: DX.Blame.VCS.Process (mirrors the current Git.Types / Git.Process split)

### Claude's Discretion
- Interface granularity (single IVCSProvider vs split interfaces) — choose what fits the existing call sites best
- Unit namespace organization — naming convention for new VCS-neutral units beyond VCS.Types and VCS.Process
- Type migration scope — which types move to VCS.Types vs stay Git-specific (e.g., sentinel values for uncommitted lines)
- Whether Git.Blame and Git.Process remain as implementation units behind TGitProvider or get folded in
- TCommitDetail record placement (stays in CommitDetail unit or moves to VCS.Types)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| VCSA-01 | IVCSProvider interface defines blame, commit detail, diff, file-at-revision, and discovery operations | Architecture Patterns section covers interface design with method signatures derived from actual call sites |
| VCSA-02 | Shared VCS-neutral types (TBlameLineInfo, TBlameData, TCommitDetail) in DX.Blame.VCS.Types | Standard Stack section maps every type that moves; dependency graph shows all consumers |
| VCSA-03 | Shared TVCSProcess base class extracted from TGitProcess for DRY CLI execution | Architecture Patterns section details the inheritance hierarchy and ExecuteGitSync elimination |
| VCSA-04 | TGitProvider wraps existing Git units behind IVCSProvider interface | Architecture Patterns section shows TGitProvider structure delegating to existing Git units |
</phase_requirements>

## Standard Stack

### Core (no new libraries — all Delphi RTL)

| Feature | Unit | Purpose | Why Standard |
|---------|------|---------|--------------|
| Interfaces | System (built-in) | IVCSProvider contract | Delphi interfaces with reference counting are the standard polymorphism mechanism for plugin architectures |
| Inheritance | System (built-in) | TVCSProcess base class | Simple single-inheritance for the process wrapper hierarchy |
| Records | System (built-in) | TBlameLineInfo, TCommitDetail | Value types for data transfer — already the established pattern |
| Generics | System.Generics.Collections | TDictionary, TList | Already used throughout the codebase |

### No New Dependencies

This phase adds zero new library dependencies. The existing `requires` clause (`rtl`, `vcl`, `designide`) remains unchanged. All work is reorganizing existing code into new units.

## Architecture Patterns

### Current Unit Dependency Graph

```
DX.Blame.Git.Types (leaf — no project dependencies)
  ├── DX.Blame.Git.Blame        (interface uses)
  ├── DX.Blame.Cache             (interface uses)
  ├── DX.Blame.Formatter         (interface uses)
  ├── DX.Blame.Engine            (interface uses)
  ├── DX.Blame.Popup             (interface uses)
  ├── DX.Blame.Diff.Form         (interface uses)
  ├── DX.Blame.Navigation        (implementation uses)
  └── DX.Blame.Renderer          (implementation uses)

DX.Blame.Git.Process (leaf — no project dependencies)
  ├── DX.Blame.Engine            (implementation uses)
  ├── DX.Blame.CommitDetail      (implementation uses)
  └── DX.Blame.Navigation        (implementation uses)

DX.Blame.Git.Discovery (leaf — no project dependencies)
  ├── DX.Blame.Engine            (implementation uses)
  ├── DX.Blame.CommitDetail      (implementation uses)
  └── DX.Blame.Navigation        (implementation uses)

DX.Blame.Git.Blame (depends on Git.Types)
  └── DX.Blame.Engine            (implementation uses)
```

### Target Unit Structure After Phase 6

```
src/
├── DX.Blame.VCS.Types.pas       # NEW: TBlameLineInfo, TBlameData, shared constants
├── DX.Blame.VCS.Process.pas     # NEW: TVCSProcess base class (all pipe logic)
├── DX.Blame.VCS.Provider.pas    # NEW: IVCSProvider interface
├── DX.Blame.Git.Provider.pas    # NEW: TGitProvider implementing IVCSProvider
├── DX.Blame.Git.Types.pas       # KEEPS: Git-specific sentinel constants, re-exports VCS types
├── DX.Blame.Git.Process.pas     # KEEPS: TGitProcess (thin subclass of TVCSProcess)
├── DX.Blame.Git.Blame.pas       # KEEPS: ParseBlameOutput (Git-specific parser)
├── DX.Blame.Git.Discovery.pas   # MODIFIED: ExecuteGitSync removed, uses TVCSProcess
├── DX.Blame.CommitDetail.pas    # MODIFIED: uses VCS.Types + VCS.Process instead of Git.*
├── DX.Blame.Engine.pas          # MODIFIED: uses VCS.Types in interface
├── DX.Blame.Cache.pas           # MODIFIED: uses VCS.Types
├── DX.Blame.Formatter.pas       # MODIFIED: uses VCS.Types
├── DX.Blame.Popup.pas           # MODIFIED: uses VCS.Types
├── DX.Blame.Diff.Form.pas       # MODIFIED: uses VCS.Types
├── DX.Blame.Navigation.pas      # MODIFIED: uses VCS.Types
├── DX.Blame.Renderer.pas        # MODIFIED: uses VCS.Types
└── ... (remaining units unchanged)
```

### Pattern 1: TVCSProcess Inheritance Hierarchy

**What:** Extract all CreateProcess+pipe logic into TVCSProcess, make TGitProcess a thin subclass.

**Design:**
```pascal
// DX.Blame.VCS.Process.pas
TVCSProcess = class
private
  FExePath: string;
  FWorkDir: string;
public
  constructor Create(const AExePath, AWorkDir: string);
  function Execute(const AArgs: string; out AOutput: string): Integer;
  function ExecuteAsync(const AArgs: string; out AOutput: string;
    var AProcessHandle: THandle): Integer;
  class procedure CancelProcess(var AProcessHandle: THandle);
  property ExePath: string read FExePath;
  property WorkDir: string read FWorkDir;
end;

// DX.Blame.Git.Process.pas (becomes thin subclass)
TGitProcess = class(TVCSProcess)
public
  constructor Create(const AGitPath, AWorkDir: string);
  // Inherits Execute, ExecuteAsync, CancelProcess from TVCSProcess
  property GitPath: string read GetGitPath; // Alias for ExePath
end;
```

**Key implementation detail:** The property rename from `GitPath` to `ExePath` on the base class. TGitProcess can add a `GitPath` read-only property that returns `ExePath` for backward compatibility, but all new code should use `ExePath`. Alternatively, since this is Phase 6 and all consumers will be updated, `GitPath` can be dropped from TGitProcess and all call sites updated to `ExePath`.

### Pattern 2: Type Migration to VCS.Types

**What:** Move VCS-neutral types from Git.Types to VCS.Types.

**Types that move to DX.Blame.VCS.Types:**
- `TBlameLineInfo` record — fully VCS-neutral (hash, author, time, summary, line numbers)
- `TBlameData` class — fully VCS-neutral (lines array, filename, timestamp)
- `cDefaultRetryDelayMs` constant — timing, not Git-specific
- `cDefaultDebounceMs` constant — timing, not Git-specific

**Types that stay in DX.Blame.Git.Types (Git-specific):**
- `cUncommittedHash` — the 40-zero SHA-1 sentinel is Git-specific (Mercurial uses different format)
- `cNotCommittedAuthor` — tied to the uncommitted detection logic

**Recommendation for TCommitDetail:** Keep `TCommitDetail` record and `TCommitDetailCache` in `DX.Blame.CommitDetail.pas`. The record is already VCS-neutral (FullMessage, FileDiff, FullDiff, Fetched). Moving it to VCS.Types would create a very large types unit and the CommitDetail unit already owns the cache + thread. No benefit to moving it now — Phase 7 will wire it through the provider.

**Git.Types becomes a thin re-export unit:**
```pascal
unit DX.Blame.Git.Types;
interface
uses
  DX.Blame.VCS.Types;
const
  cUncommittedHash = '0000000000000000000000000000000000000000';
  cNotCommittedAuthor = 'Not committed yet';
// TBlameLineInfo and TBlameData are now in DX.Blame.VCS.Types
// but accessible here via the uses clause for backward compatibility
implementation
end.
```

**Important:** Delphi does NOT re-export types from used units implicitly. Any unit that currently uses `DX.Blame.Git.Types` to access `TBlameLineInfo` must have its uses clause changed to `DX.Blame.VCS.Types`. The Git.Types unit is only useful for the Git-specific constants. This means all 8 consumer units need their `uses` updated.

### Pattern 3: IVCSProvider Interface

**What:** Single interface covering all VCS operations needed by the engine.

**Recommendation: Single interface.** The existing call sites in Engine, CommitDetail, and Navigation need blame, commit detail, diff, and file-at-revision. Splitting into IVCSBlameProvider, IVCSDiffProvider etc. adds complexity without benefit — every provider must implement all operations anyway.

```pascal
// DX.Blame.VCS.Provider.pas
IVCSProvider = interface
  ['{GUID}']
  /// Blame
  function ExecuteBlame(const ARepoRoot, AFilePath: string;
    out AOutput: string; var AProcessHandle: THandle): Integer;

  /// Commit detail
  function GetCommitMessage(const ARepoRoot, ACommitHash: string;
    out AMessage: string): Boolean;
  function GetFileDiff(const ARepoRoot, ACommitHash, ARelativePath: string;
    out ADiff: string): Boolean;
  function GetFullDiff(const ARepoRoot, ACommitHash: string;
    out ADiff: string): Boolean;

  /// Revision navigation
  function GetFileAtRevision(const ARepoRoot, ACommitHash, ARelativePath: string;
    out AContent: string): Boolean;

  /// Discovery
  function FindExecutable: string;
  function FindRepoRoot(const APath: string): string;
  procedure ClearDiscoveryCache;

  /// Identity
  function GetDisplayName: string;   // 'Git' or 'Mercurial'
  function GetUncommittedHash: string; // VCS-specific sentinel
  function GetUncommittedAuthor: string;
end;
```

**Why include discovery in the interface:** Phase 8 needs per-VCS discovery (Git looks for .git + git.exe, Hg looks for .hg + hg.exe). Putting discovery on the provider keeps the abstraction clean.

**Why include identity methods:** `GetUncommittedHash` and `GetUncommittedAuthor` let each VCS define its own sentinel values. Git uses 40 zeros; Mercurial will use a different convention.

### Pattern 4: TGitProvider Wrapper

**What:** TGitProvider implements IVCSProvider by delegating to existing Git units.

```pascal
// DX.Blame.Git.Provider.pas
TGitProvider = class(TInterfacedObject, IVCSProvider)
private
  // Delegates to existing units — no new logic
public
  function ExecuteBlame(const ARepoRoot, AFilePath: string;
    out AOutput: string; var AProcessHandle: THandle): Integer;
  function GetCommitMessage(const ARepoRoot, ACommitHash: string;
    out AMessage: string): Boolean;
  // ... etc
  function GetDisplayName: string;  // Returns 'Git'
  function GetUncommittedHash: string; // Returns cUncommittedHash
  function GetUncommittedAuthor: string; // Returns cNotCommittedAuthor
end;
```

**Implementation approach:** TGitProvider creates temporary TGitProcess instances (as the current code already does) and calls FindGitExecutable/FindGitRepoRoot from Git.Discovery. It is a thin delegation layer — no new logic.

### Pattern 5: Eliminating ExecuteGitSync Duplication

**What:** The `ExecuteGitSync` function in `DX.Blame.Git.Discovery` (lines 58-124) is a full copy of the CreateProcess+pipe logic from `TGitProcess.ExecuteAsync`. After TVCSProcess exists, Discovery should create a temporary TVCSProcess instance instead.

```pascal
// In DX.Blame.Git.Discovery.pas — replace ExecuteGitSync with:
function ExecuteGitSync(const AGitPath, AWorkDir, AArgs: string;
  out AOutput: string): Integer;
var
  LProcess: TVCSProcess;
begin
  LProcess := TVCSProcess.Create(AGitPath, AWorkDir);
  try
    Result := LProcess.Execute(AArgs, AOutput);
  finally
    LProcess.Free;
  end;
end;
```

This eliminates ~65 lines of duplicated pipe logic. The function signature stays the same, so `FindGitRepoRoot` needs no changes.

### Anti-Patterns to Avoid

- **Circular unit references:** VCS.Types must NOT use any Git.* unit. VCS.Process must NOT use Git.* units. The dependency must flow one way: Git.* depends on VCS.*, never the reverse.
- **Moving too much into VCS.Types:** Keep the unit focused on data types. Do not put caching, threading, or process logic there.
- **Breaking Git.Types consumers in one step:** Update units one at a time, compiling after each change. Do not mass-rename all uses clauses simultaneously.
- **Forgetting the .dpk file:** New units must be added to the `contains` clause in `DX.Blame.dpk`, or the package will not compile.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Interface reference counting | Custom AddRef/Release | TInterfacedObject | Delphi's built-in reference counting for interfaces is correct and tested |
| GUID generation | Manual string | Ctrl+Shift+G in IDE or online generator | GUIDs must be unique; manual strings risk collision |

## Common Pitfalls

### Pitfall 1: Delphi Does Not Re-Export Types Through Uses
**What goes wrong:** Developer assumes that if Unit A uses Unit B, and Unit C uses Unit A, then Unit C can see types from Unit B. This is FALSE in Delphi.
**Why it happens:** Other languages (like C++ with `#include`) propagate declarations transitively.
**How to avoid:** Every unit that references TBlameLineInfo or TBlameData must directly list DX.Blame.VCS.Types in its own `uses` clause.
**Warning signs:** Compiler error "Undeclared identifier 'TBlameLineInfo'" after changing only some units.

### Pitfall 2: Interface Section vs Implementation Section Uses
**What goes wrong:** Changing a `uses` clause in the `interface` section when the type is only referenced in `implementation`, or vice versa.
**Why it happens:** Delphi has two distinct uses clauses with different visibility rules. Types used in public declarations (type definitions, method signatures) must be in the interface uses. Types used only in method bodies can be in implementation uses.
**How to avoid:** Check whether Git.Types appears in `interface uses` or `implementation uses` for each consumer:
  - **Interface uses** (must see VCS.Types in interface): Engine, Cache, Formatter, Popup, Diff.Form, Git.Blame
  - **Implementation uses** (can see VCS.Types in implementation): Navigation, Renderer
**Warning signs:** Compiler error about "Forward declaration not resolved" or "Type not found".

### Pitfall 3: Package Registration Order
**What goes wrong:** New units added to `.dpk` `contains` clause in wrong order, causing compilation to fail because a unit is compiled before its dependency.
**Why it happens:** Delphi compiles units in the order listed in `contains` (unless smart linking resolves it). Explicit ordering is safer.
**How to avoid:** Add VCS.Types before VCS.Process before VCS.Provider before Git.Provider in the `contains` clause. Place them before the existing Git.Types entry.

### Pitfall 4: CancelProcess as Class Method on Base
**What goes wrong:** CancelProcess is a class method (callable without an instance). When moving it to TVCSProcess, it must remain a `class procedure` — not an instance method.
**Why it happens:** The existing code calls `TGitProcess.CancelProcess(FProcessHandle)` from TBlameThread.Cancel without a process instance.
**How to avoid:** Declare it as `class procedure CancelProcess(var AProcessHandle: THandle);` on TVCSProcess. TBlameThread.Cancel can then call `TVCSProcess.CancelProcess(FProcessHandle)`.

### Pitfall 5: Forgetting to Update the DPK Contains Clause
**What goes wrong:** New units compile individually but the package fails to build because they are not listed in `DX.Blame.dpk`.
**How to avoid:** Add all four new units to the `contains` clause:
```
DX.Blame.VCS.Types in 'DX.Blame.VCS.Types.pas',
DX.Blame.VCS.Process in 'DX.Blame.VCS.Process.pas',
DX.Blame.VCS.Provider in 'DX.Blame.VCS.Provider.pas',
DX.Blame.Git.Provider in 'DX.Blame.Git.Provider.pas',
```

## Code Examples

### New Unit: DX.Blame.VCS.Types (core types)

```pascal
unit DX.Blame.VCS.Types;

interface

uses
  System.SysUtils;

const
  cDefaultRetryDelayMs = 2500;
  cDefaultDebounceMs = 500;

type
  TBlameLineInfo = record
    CommitHash: string;
    Author: string;
    AuthorMail: string;
    AuthorTime: TDateTime;
    Summary: string;
    OriginalLine: Integer;
    FinalLine: Integer;
    IsUncommitted: Boolean;
  end;

  TBlameData = class
  private
    FLines: TArray<TBlameLineInfo>;
    FFileName: string;
    FTimestamp: TDateTime;
  public
    constructor Create(const AFileName: string);
    property Lines: TArray<TBlameLineInfo> read FLines write FLines;
    property FileName: string read FFileName;
    property Timestamp: TDateTime read FTimestamp write FTimestamp;
  end;

implementation

constructor TBlameData.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := LowerCase(AFileName);
  FTimestamp := Now;
end;

end.
```

### Refactored DX.Blame.Git.Types (Git-specific constants only)

```pascal
unit DX.Blame.Git.Types;

interface

uses
  DX.Blame.VCS.Types;  // Makes TBlameLineInfo, TBlameData visible to this unit

const
  cUncommittedHash = '0000000000000000000000000000000000000000';
  cNotCommittedAuthor = 'Not committed yet';

implementation

end.
```

### TVCSProcess Base Class (key method)

```pascal
unit DX.Blame.VCS.Process;

interface

uses
  Winapi.Windows;

type
  TVCSProcess = class
  private
    FExePath: string;
    FWorkDir: string;
  public
    constructor Create(const AExePath, AWorkDir: string);
    function Execute(const AArgs: string; out AOutput: string): Integer;
    function ExecuteAsync(const AArgs: string; out AOutput: string;
      var AProcessHandle: THandle): Integer;
    class procedure CancelProcess(var AProcessHandle: THandle);
    property ExePath: string read FExePath;
    property WorkDir: string read FWorkDir;
  end;

implementation
// ... exact same implementation as current TGitProcess, with FGitPath renamed to FExePath
end.
```

### Thin TGitProcess Subclass

```pascal
unit DX.Blame.Git.Process;

interface

uses
  DX.Blame.VCS.Process;

type
  TGitProcess = class(TVCSProcess)
  public
    constructor Create(const AGitPath, AWorkDir: string);
  end;

implementation

constructor TGitProcess.Create(const AGitPath, AWorkDir: string);
begin
  inherited Create(AGitPath, AWorkDir);
end;

end.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Direct Git.Types usage everywhere | VCS.Types for neutral types, Git.Types for Git-specific | Phase 6 | All 8 consumer units update uses clauses |
| Duplicated CreateProcess in Discovery | Single TVCSProcess.Execute | Phase 6 | ~65 lines of duplication removed |
| No abstraction for VCS operations | IVCSProvider interface | Phase 6 | Foundation for Phase 7 engine dispatch |

## Open Questions

1. **GitPath property backward compatibility**
   - What we know: Current code references `LProcess.GitPath` in no consumer units (only internal to TGitProcess). All external usage creates TGitProcess and calls Execute/ExecuteAsync.
   - What's unclear: Whether any external tooling or future code expects a `GitPath` property.
   - Recommendation: Drop GitPath property from TGitProcess since no external consumer uses it. If needed, add a read-only `GitPath` that returns `ExePath`.

2. **IsUncommitted field placement**
   - What we know: `TBlameLineInfo.IsUncommitted` is set by comparing against `cUncommittedHash`, which is Git-specific.
   - What's unclear: Whether Mercurial's annotate output has an equivalent concept.
   - Recommendation: Keep `IsUncommitted` in the record (it is a universal concept). Each provider's parser sets it using its own sentinel logic. The field itself is VCS-neutral; only the detection logic is VCS-specific.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | No automated test framework currently configured |
| Config file | none |
| Quick run command | `powershell -File build/DelphiBuildDPROJ.ps1 src/DX.Blame.dproj` |
| Full suite command | `powershell -File build/DelphiBuildDPROJ.ps1 src/DX.Blame.dproj` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VCSA-01 | IVCSProvider interface exists and compiles | compilation | `powershell -File build/DelphiBuildDPROJ.ps1 src/DX.Blame.dproj` | N/A - compilation test |
| VCSA-02 | VCS.Types contains TBlameLineInfo, TBlameData | compilation | `powershell -File build/DelphiBuildDPROJ.ps1 src/DX.Blame.dproj` | N/A - compilation test |
| VCSA-03 | TVCSProcess base class works, TGitProcess delegates | compilation + manual | Package compiles and blame works in IDE | N/A |
| VCSA-04 | TGitProvider implements IVCSProvider | compilation | `powershell -File build/DelphiBuildDPROJ.ps1 src/DX.Blame.dproj` | N/A - compilation test |

### Sampling Rate
- **Per task commit:** `powershell -File build/DelphiBuildDPROJ.ps1 src/DX.Blame.dproj`
- **Per wave merge:** Full package compilation + manual IDE load test
- **Phase gate:** Package compiles clean AND blame annotations appear identically in IDE

### Wave 0 Gaps
- [ ] Verify `build/DelphiBuildDPROJ.ps1` exists and is functional
- [ ] No unit test framework (DUnitX) is currently set up — acceptable for this refactoring phase since the primary validation is successful compilation and identical runtime behavior

## Sources

### Primary (HIGH confidence)
- **Codebase analysis** — direct reading of all 17 source files in `src/`
- `DX.Blame.Git.Types.pas` — current type definitions (lines 1-91)
- `DX.Blame.Git.Process.pas` — current process implementation (lines 1-185)
- `DX.Blame.Git.Discovery.pas` — duplicated ExecuteGitSync (lines 58-124)
- `DX.Blame.Git.Blame.pas` — parser consuming Git.Types (lines 1-148)
- `DX.Blame.CommitDetail.pas` — TCommitDetail record and thread (lines 1-239)
- `DX.Blame.Engine.pas` — main orchestrator, all Git.* dependencies (lines 1-580)
- `DX.Blame.Navigation.pas` — revision navigation, Git.* dependencies (lines 1-337)
- `DX.Blame.dpk` — package contains clause (lines 1-59)

### Secondary (MEDIUM confidence)
- Delphi interface and inheritance semantics — well-established language features, verified against codebase patterns

### Tertiary (LOW confidence)
- None — all findings based on direct codebase analysis

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new libraries, all Delphi RTL
- Architecture: HIGH — direct analysis of all 17 source files with complete dependency mapping
- Pitfalls: HIGH — derived from actual Delphi language rules and the specific code patterns in use

**Research date:** 2026-03-23
**Valid until:** indefinite — this is a refactoring of existing code, no external dependencies to go stale
