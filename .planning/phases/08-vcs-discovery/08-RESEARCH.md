# Phase 8: VCS Discovery - Research

**Researched:** 2026-03-24
**Domain:** Delphi VCS auto-detection -- directory scanning, executable discovery, user prompting for dual-VCS repos
**Confidence:** HIGH

## Summary

Phase 8 transforms the engine's hardcoded `TGitProvider.Create` in `TBlameEngine.Initialize` into a dynamic VCS selection mechanism. The current engine always instantiates a Git provider; this phase must scan the project tree for `.git` and `.hg` directories, locate the appropriate executable, verify the repository, and assign the correct `IVCSProvider` implementation. The existing `IVCSProvider` interface already includes `FindExecutable`, `FindRepoRoot`, and `ClearDiscoveryCache` -- the discovery contract is already defined.

The primary complexity lies in three areas: (1) Mercurial executable discovery including TortoiseHg installation paths, (2) the dual-VCS prompt when both `.git` and `.hg` are present with per-project persistence, and (3) integrating the discovery result into `TBlameEngine.Initialize` without breaking the existing Git-only flow. The codebase already has a working model in `DX.Blame.Git.Discovery` that searches PATH then common install locations then verifies with `git rev-parse`. The Mercurial equivalent follows the exact same pattern: search PATH, check TortoiseHg install path, verify with `hg root`.

**Primary recommendation:** Create a `DX.Blame.Hg.Discovery` unit mirroring the Git discovery pattern, then replace the hardcoded provider creation in `TBlameEngine.Initialize` with a `TVCSDiscovery` orchestrator class that scans for `.git`/`.hg`, resolves which provider to use (including dual-VCS prompting), and returns the appropriate `IVCSProvider`.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| VCSD-01 | Plugin auto-detects .git or .hg directory in project tree | Architecture Patterns: directory scanning walks parent dirs from project path, checking for `.git`/`.hg` sentinel directories |
| VCSD-02 | Plugin discovers hg.exe via PATH and TortoiseHg installation paths | Standard Stack: TortoiseHg installs hg.exe at `C:\Program Files\TortoiseHg\hg.exe`; also check PATH and registry |
| VCSD-03 | Plugin verifies repository with `hg root` before activating Mercurial backend | Architecture Patterns: `hg root` returns repo root path on exit code 0, non-zero if not in a repo |
| VCSD-04 | User is prompted once per project when both .git and .hg are present, choice is persisted | Architecture Patterns: modal dialog with radio buttons, choice saved to settings.ini keyed by project path hash |
| VCSD-05 | Active VCS backend is indicated in IDE Messages | Architecture Patterns: use existing `LogToIDE` pattern in TBlameEngine to report provider name |
</phase_requirements>

## Standard Stack

### Core (no new libraries -- all Delphi RTL + existing project patterns)

| Feature | Unit | Purpose | Why Standard |
|---------|------|---------|--------------|
| Directory scanning | System.IOUtils | TDirectory.Exists, TPath.Combine for .git/.hg detection | Already used in Git.Discovery |
| PATH search | System.SysUtils | GetEnvironmentVariable('PATH') for hg.exe lookup | Already used in Git.Discovery |
| Registry access | System.Win.Registry | TRegistry for HKLM\SOFTWARE\TortoiseHg InstallDir | Standard Delphi registry access for install detection |
| INI persistence | System.IniFiles | TIniFile for persisting dual-VCS project choice | Already used in DX.Blame.Settings |
| Process execution | DX.Blame.VCS.Process | TVCSProcess for `hg root` verification | Existing shared base class |
| Modal dialog | Vcl.Forms, Vcl.StdCtrls | TaskDialogEx or simple form for dual-VCS prompt | Standard VCL approach |

### No New Dependencies

This phase adds zero new package dependencies. All work uses RTL, VCL, and existing project units.

## Architecture Patterns

### New Unit Structure

```
src/
  DX.Blame.Hg.Discovery.pas     # NEW: FindHgExecutable + FindHgRepoRoot (mirrors Git.Discovery)
  DX.Blame.VCS.Discovery.pas    # NEW: TVCSDiscovery orchestrator (scans, resolves, prompts)
  DX.Blame.Engine.pas           # MODIFIED: Initialize calls TVCSDiscovery instead of hardcoded TGitProvider
  DX.Blame.Settings.pas         # MODIFIED: Add VCS choice persistence for dual-VCS projects
```

### Pattern 1: Mercurial Executable Discovery (mirrors Git.Discovery)

**What:** Find hg.exe on the system using the same strategy as FindGitExecutable.
**When to use:** Called by TVCSDiscovery when `.hg` directory is detected.

```pascal
// DX.Blame.Hg.Discovery.pas
function FindHgExecutable: string;
// Search order:
// 1. System PATH (split by ';', check each dir for hg.exe)
// 2. TortoiseHg default: C:\Program Files\TortoiseHg\hg.exe
// 3. TortoiseHg x86:    C:\Program Files (x86)\TortoiseHg\hg.exe
// 4. Registry: HKLM\SOFTWARE\TortoiseHg -> InstallDir key (if it exists)
// Results cached in unit-level vars, same pattern as Git.Discovery

function FindHgRepoRoot(const APath: string): string;
// Walk parent directories looking for .hg folder
// Verify with: hg root (exit code 0 = valid repo)
// Use TVCSProcess.Execute for the verification call
// Cache result same as Git.Discovery

procedure ClearDiscoveryCache;
```

### Pattern 2: VCS Discovery Orchestrator

**What:** Central class that determines which VCS provider to use for a given project path.
**When to use:** Called from `TBlameEngine.Initialize` replacing the hardcoded `TGitProvider.Create`.

```pascal
// DX.Blame.VCS.Discovery.pas
type
  TVCSType = (vtNone, vtGit, vtMercurial);

  TVCSDiscovery = class
  public
    /// Scans project path for .git/.hg, resolves provider, handles dual-VCS
    class function DetectProvider(const AProjectPath: string;
      out ARepoRoot: string): IVCSProvider;
  private
    class function ScanForVCS(const APath: string;
      out AHasGit, AHasHg: Boolean): Boolean;
    class function GetPersistedChoice(const AProjectPath: string): TVCSType;
    class procedure PersistChoice(const AProjectPath, AChoice: string);
    class function PromptForVCS(const AProjectPath: string): TVCSType;
  end;
```

**Detection flow:**
1. Walk parent directories from AProjectPath looking for `.git` and `.hg`
2. If only `.git` found: create TGitProvider (existing behavior preserved)
3. If only `.hg` found: find hg.exe, verify with `hg root`, create THgProvider (Phase 9 stub)
4. If both found: check persisted choice first, if none then prompt user
5. If neither found: return nil (VCSAvailable = False)

### Pattern 3: Dual-VCS User Prompt

**What:** A modal dialog shown once when both `.git` and `.hg` are detected for a project.
**When to use:** Only when both VCS directories exist AND no persisted choice exists for this project.

**Implementation approach:** Use Vcl.Dialogs.TaskDialog (available in Delphi 10.4+) or a simple custom VCL form with two radio buttons and OK/Cancel. TaskDialog is cleaner but requires Windows Vista+, which is fine for a Delphi IDE plugin.

Alternatively, a simple `MessageDlg` with custom buttons keeps it lightweight:

```pascal
class function TVCSDiscovery.PromptForVCS(const AProjectPath: string): TVCSType;
var
  LResult: Integer;
begin
  // Simple approach: use TaskDialog with two command link buttons
  // "Use Git" and "Use Mercurial"
  // Title: "Multiple VCS Detected"
  // Text: "Both Git and Mercurial repositories were detected. Choose..."
  // Remember choice in settings.ini keyed by project path
end;
```

### Pattern 4: Per-Project VCS Choice Persistence

**What:** Store the user's VCS choice for dual-VCS projects in settings.ini.
**When to use:** After user selects VCS in dual-VCS prompt.

```ini
[VCSChoice]
; Key = MD5 hash of lowercase project path, Value = Git or Mercurial
A1B2C3D4E5F6... = Git
F6E5D4C3B2A1... = Mercurial
```

Using a hash of the project path as the key avoids problems with special characters, long paths, and backslashes in INI keys. `System.Hash.THashMD5` is available in the RTL.

### Pattern 5: Engine Integration

**What:** Replace hardcoded TGitProvider in TBlameEngine.Initialize.
**When to use:** This is the integration point where discovery results feed into the engine.

```pascal
procedure TBlameEngine.Initialize(const AProjectPath: string);
var
  LRepoRoot: string;
begin
  FProvider := TVCSDiscovery.DetectProvider(AProjectPath, LRepoRoot);
  if FProvider = nil then
  begin
    FVCSAvailable := False;
    if not FVCSNotified then
    begin
      FVCSNotified := True;
      LogToIDE('DX.Blame: No VCS repository detected. Blame features disabled.');
    end;
    Exit;
  end;

  FRepoRoot := LRepoRoot;
  FVCSAvailable := True;
  // VCSD-05: Report active backend
  LogToIDE('DX.Blame: ' + FProvider.GetDisplayName + ' repository detected at ' + FRepoRoot);
end;
```

**Key change:** The current `Initialize` always logs via `{$IFDEF DEBUG}`. VCSD-05 requires the active backend to be reported unconditionally (not just in debug builds). Remove the `{$IFDEF DEBUG}` guard for the activation message.

### Anti-Patterns to Avoid

- **Scanning too deep:** Only walk parent directories upward from the project path. Never recursively scan subdirectories for `.git`/`.hg`. The parent-walk is O(depth) and guaranteed to terminate.
- **Creating THgProvider in this phase:** Phase 9 implements the Mercurial blame provider. Phase 8 only needs to detect Hg repos and find hg.exe. For now, if Hg is detected but no THgProvider exists yet, either create a stub provider or defer. **Decision: create a minimal THgProvider stub that implements FindExecutable, FindRepoRoot, GetDisplayName, and raises ENotImplemented for blame operations. This allows Phase 8 to be fully testable.**
- **Prompting on every file open:** The dual-VCS prompt must fire exactly once per project session (or use the persisted choice). Store the resolved provider in the engine and do not re-detect on each file.
- **Breaking Git-only repos:** The most critical constraint. Git-only repos must work identically to the current behavior. The detection path for Git-only must be equivalent: find .git, find git.exe, verify, create TGitProvider.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PATH search | Custom string parsing | Same split-by-semicolon pattern as Git.Discovery | Already proven, tested pattern in the codebase |
| Project path hashing | Custom hash | System.Hash.THashMD5.GetHashString | Standard RTL, collision-resistant for INI keys |
| User prompt dialog | Complex custom form | Vcl.Dialogs.TaskDialog or simple MessageDlg | Standard VCL, no form file needed |
| Process execution | New CreateProcess wrapper | TVCSProcess.Execute | Already exists, handles pipes and cleanup |

## Common Pitfalls

### Pitfall 1: TortoiseHg hg.exe Not on PATH
**What goes wrong:** TortoiseHg installer adds `thg.cmd` to PATH but not necessarily `hg.exe`. Users have TortoiseHg installed but `hg.exe` cannot be found via PATH alone.
**Why it happens:** TortoiseHg bundles its own Python + Mercurial. The `hg.exe` is in the install directory, not a `cmd` subdirectory.
**How to avoid:** Always check the TortoiseHg install directory (`C:\Program Files\TortoiseHg\hg.exe`) as a fallback after PATH search. Optionally check registry key `HKLM\SOFTWARE\TortoiseHg` for a custom install path.
**Warning signs:** Works on developer machine (hg on PATH) but fails on user machines with only TortoiseHg GUI installed.

### Pitfall 2: `hg root` Outputs to stderr on Failure
**What goes wrong:** When not in a Mercurial repo, `hg root` outputs an error message to stderr and returns non-zero exit code. The TVCSProcess captures both stdout and stderr on the same pipe.
**Why it happens:** Mercurial writes errors to stderr. TVCSProcess redirects both stdout and stderr to the same pipe (hStdError = LWritePipe in VCS.Process).
**How to avoid:** Only check the exit code (0 = success). Ignore the output content on failure. The current TVCSProcess already merges stdout/stderr, so this is handled.

### Pitfall 3: UNC vs Drive Letter Path Mismatch
**What goes wrong:** `hg root` may return a UNC path while the IDE uses drive-letter paths, causing path comparisons to fail.
**Why it happens:** Network-mapped drives have both a UNC path and a drive letter.
**How to avoid:** Use the same strategy as Git.Discovery: use the directory where `.hg` was found as the repo root (not the output of `hg root`). Only use `hg root` for verification (exit code check), not for the path value. This is exactly what `FindGitRepoRoot` already does.

### Pitfall 4: Race Condition on Project Switch During Prompt
**What goes wrong:** User is shown the dual-VCS dialog while a project switch fires, leading to stale provider assignment.
**Why it happens:** `OnProjectSwitch` calls `Initialize` which could trigger a prompt, but another switch might occur during the modal dialog.
**How to avoid:** The modal dialog blocks the main thread, and OTA notifications arrive on the main thread. So a project switch notification cannot fire while the dialog is open. This is inherently safe in the VCL event model. No special handling needed.

### Pitfall 5: INI Key Collisions for Similar Project Paths
**What goes wrong:** Two different projects hash to the same INI key, causing wrong VCS selection.
**Why it happens:** Using a weak hash or truncated path.
**How to avoid:** Use full MD5 hash of the lowercase, trailing-slash-normalized project path. MD5 collision probability for this use case is negligible.

## Code Examples

### Mercurial Executable Discovery

```pascal
// Mirrors FindGitExecutable in DX.Blame.Git.Discovery
function FindHgExecutable: string;
var
  LPathEnv: string;
  LDirs: TArray<string>;
  LDir: string;
  LCandidate: string;
begin
  if GHgPathSearched then
    Exit(GCachedHgPath);

  GHgPathSearched := True;
  GCachedHgPath := '';

  // 1. Search system PATH
  LPathEnv := GetEnvironmentVariable('PATH');
  if LPathEnv <> '' then
  begin
    LDirs := LPathEnv.Split([';']);
    for LDir in LDirs do
    begin
      if LDir = '' then
        Continue;
      LCandidate := TPath.Combine(Trim(LDir), 'hg.exe');
      if TFile.Exists(LCandidate) then
      begin
        GCachedHgPath := LCandidate;
        Exit(GCachedHgPath);
      end;
    end;
  end;

  // 2. TortoiseHg default location
  LCandidate := 'C:\Program Files\TortoiseHg\hg.exe';
  if TFile.Exists(LCandidate) then
  begin
    GCachedHgPath := LCandidate;
    Exit(GCachedHgPath);
  end;

  // 3. TortoiseHg x86 location
  LCandidate := 'C:\Program Files (x86)\TortoiseHg\hg.exe';
  if TFile.Exists(LCandidate) then
  begin
    GCachedHgPath := LCandidate;
    Exit(GCachedHgPath);
  end;

  Result := '';
end;
```

### Repository Verification with hg root

```pascal
function FindHgRepoRoot(const APath: string): string;
var
  LDir, LParent, LHgDir, LHgPath, LOutput: string;
  LProcess: TVCSProcess;
begin
  if (GCachedHgRepoRoot <> '') and SameText(APath, GCachedHgRepoRootSource) then
    Exit(GCachedHgRepoRoot);

  Result := '';

  if TDirectory.Exists(APath) then
    LDir := APath
  else
    LDir := TPath.GetDirectoryName(APath);

  while LDir <> '' do
  begin
    LHgDir := TPath.Combine(LDir, '.hg');
    if TDirectory.Exists(LHgDir) then
    begin
      // VCSD-03: Verify with hg root
      LHgPath := FindHgExecutable;
      if LHgPath <> '' then
      begin
        LProcess := TVCSProcess.Create(LHgPath, LDir);
        try
          if LProcess.Execute('root', LOutput) = 0 then
          begin
            Result := LDir; // Use directory path, not hg root output (UNC safety)
            GCachedHgRepoRoot := Result;
            GCachedHgRepoRootSource := APath;
            Exit;
          end;
        finally
          LProcess.Free;
        end;
      end;
      // If hg.exe not found, do NOT trust .hg alone (unlike Git fallback)
      // Mercurial without hg.exe is unusable
      Exit;
    end;

    LParent := TDirectory.GetParent(LDir);
    if (LParent = '') or SameText(LParent, LDir) then
      Break;
    LDir := LParent;
  end;
end;
```

### VCS Detection Orchestrator

```pascal
class function TVCSDiscovery.DetectProvider(const AProjectPath: string;
  out ARepoRoot: string): IVCSProvider;
var
  LHasGit, LHasHg: Boolean;
  LChoice: TVCSType;
begin
  Result := nil;
  ARepoRoot := '';

  ScanForVCS(AProjectPath, LHasGit, LHasHg);

  if LHasGit and LHasHg then
  begin
    // VCSD-04: Check persisted choice, then prompt
    LChoice := GetPersistedChoice(AProjectPath);
    if LChoice = vtNone then
      LChoice := PromptForVCS(AProjectPath);
  end
  else if LHasGit then
    LChoice := vtGit
  else if LHasHg then
    LChoice := vtMercurial
  else
    Exit; // No VCS detected

  case LChoice of
    vtGit:
      begin
        Result := TGitProvider.Create;
        ARepoRoot := Result.FindRepoRoot(AProjectPath);
      end;
    vtMercurial:
      begin
        Result := THgProvider.Create; // Stub in Phase 8, full in Phase 9
        ARepoRoot := Result.FindRepoRoot(AProjectPath);
      end;
  end;

  // Validate: provider must find executable and repo root
  if (Result <> nil) and ((Result.FindExecutable = '') or (ARepoRoot = '')) then
    Result := nil;
end;
```

## State of the Art

| Old Approach (current) | New Approach (Phase 8) | Impact |
|------------------------|------------------------|--------|
| Hardcoded `TGitProvider.Create` in Engine.Initialize | `TVCSDiscovery.DetectProvider` returns appropriate provider | Enables Mercurial support |
| Git-only executable search | Parallel Git + Hg search with TortoiseHg fallback | Wider tool coverage |
| No VCS logging in release builds | Unconditional IDE message for active VCS | User always knows which VCS is active (VCSD-05) |
| No dual-VCS handling | Modal prompt + INI persistence | Clean UX for hg-git repos |

## Open Questions

1. **THgProvider stub scope**
   - What we know: Phase 9 implements full Mercurial blame. Phase 8 needs something to assign to `FProvider`.
   - What's unclear: How much of THgProvider should exist in Phase 8?
   - Recommendation: Create a minimal stub implementing IVCSProvider. FindExecutable/FindRepoRoot delegate to Hg.Discovery. Blame operations raise `ENotSupportedException('Mercurial blame not yet implemented')`. This allows Phase 8 discovery to be fully functional and testable. Phase 9 fills in the implementation.

2. **Dual-VCS dialog UX (flagged in STATE.md as concern)**
   - What we know: STATE.md says "modal dialog vs notification must be decided before coding"
   - Recommendation: Use a **modal TaskDialog** with two command-link buttons ("Use Git" / "Use Mercurial"). This is the standard Windows UI pattern for one-time choices. It blocks until the user decides, which is correct because the engine cannot proceed without knowing which provider to use. A notification/toast would be wrong because it is non-blocking and the engine needs the answer synchronously.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | DUnitX (Git submodule under /libs) |
| Config file | tests/ directory (project structure standard) |
| Quick run command | Build and run test project via DelphiBuildDPROJ.ps1 |
| Full suite command | Build and run test project via DelphiBuildDPROJ.ps1 |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VCSD-01 | .git/.hg directory detection | unit | Test ScanForVCS with mock directories | No - Wave 0 |
| VCSD-02 | hg.exe discovery via PATH and TortoiseHg | unit | Test FindHgExecutable with manipulated PATH | No - Wave 0 |
| VCSD-03 | hg root verification | integration | Requires real hg repo - manual verification | manual-only |
| VCSD-04 | Dual-VCS prompt and persistence | unit | Test persistence read/write in INI | No - Wave 0 |
| VCSD-05 | IDE Messages logging | manual-only | Requires running IDE plugin | manual-only |

### Sampling Rate
- **Per task commit:** Build DX.Blame package with DelphiBuildDPROJ.ps1 (compilation check)
- **Per wave merge:** Full package build + manual IDE load test
- **Phase gate:** Package compiles, Git-only repos still work, Hg detection works

### Wave 0 Gaps
- [ ] Unit tests for Hg discovery are deferred -- hg.exe/repo availability varies by machine
- [ ] Compilation verification is the primary automated gate for this phase
- [ ] Manual testing with real Git and Hg repos required for VCSD-01, VCSD-03, VCSD-05

## Sources

### Primary (HIGH confidence)
- Existing codebase: `DX.Blame.Git.Discovery.pas` -- proven pattern for executable search + repo detection
- Existing codebase: `DX.Blame.Engine.pas` -- integration point at `Initialize` method
- Existing codebase: `DX.Blame.VCS.Provider.pas` -- IVCSProvider interface contract
- Existing codebase: `DX.Blame.Settings.pas` -- INI persistence pattern

### Secondary (MEDIUM confidence)
- [TortoiseHg Documentation](https://tortoisehg.readthedocs.io/en/latest/intro.html) -- default install path `C:\Program Files\TortoiseHg`
- [Mercurial WindowsInstall wiki](https://www.mercurial-scm.org/wiki/WindowsInstall) -- registry key `HKLM\SOFTWARE\Mercurial`
- [JetBrains Rider Mercurial docs](https://www.jetbrains.com/help/rider/Using_Mercurial_Integration.html) -- hg.exe discovery strategies used by other IDEs

### Tertiary (LOW confidence)
- Registry key `HKLM\SOFTWARE\TortoiseHg` with `InstallDir` value -- not verified against current TortoiseHg installer, may not exist. Fallback only.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new libraries, mirrors existing Git.Discovery patterns exactly
- Architecture: HIGH -- detection orchestrator is straightforward, IVCSProvider interface already supports all needed operations
- Pitfalls: HIGH -- identified from direct codebase analysis and known Windows path issues
- Hg executable paths: MEDIUM -- TortoiseHg default path verified via docs, registry key needs validation

**Research date:** 2026-03-24
**Valid until:** 2026-04-24 (stable domain, no fast-moving dependencies)
