/// <summary>
/// DX.Blame.Hg.Discovery
/// Mercurial executable finder and repository root detection.
/// </summary>
///
/// <remarks>
/// Provides functions to locate hg.exe on the system (PATH and common
/// TortoiseHg install locations) and to detect whether a given directory
/// resides inside a Mercurial repository. Results are cached per session
/// and cleared on project switch via ClearHgDiscoveryCache.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Hg.Discovery;

interface

/// <summary>
/// Returns the full path to hg.exe, or an empty string if not found.
/// The result is cached after the first successful search.
/// </summary>
function FindHgExecutable: string;

/// <summary>
/// Finds the Mercurial repository root for the given path by walking parent
/// directories for a .hg folder, then verifying with hg root.
/// Returns an empty string if the path is not inside a Mercurial repository
/// or if hg.exe is not available.
/// </summary>
function FindHgRepoRoot(const APath: string): string;

/// <summary>
/// Resets cached hg path and repo root. Call on project switch.
/// </summary>
procedure ClearHgDiscoveryCache;

/// <summary>
/// Returns the full path to thg.exe (TortoiseHg GUI launcher), or an empty
/// string if not found. Derives the path from hg.exe since both ship in the
/// same TortoiseHg installation directory.
/// </summary>
function FindThgExecutable: string;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  DX.Blame.VCS.Process;

var
  GCachedHgPath: string;
  GHgPathSearched: Boolean;
  GCachedHgRepoRoot: string;
  GCachedHgRepoRootSource: string;

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
  LPathEnv := System.SysUtils.GetEnvironmentVariable('PATH');
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

  // 2. TortoiseHg default install location
  LCandidate := 'C:\Program Files\TortoiseHg\hg.exe';
  if TFile.Exists(LCandidate) then
  begin
    GCachedHgPath := LCandidate;
    Exit(GCachedHgPath);
  end;

  // 3. TortoiseHg x86 install location
  LCandidate := 'C:\Program Files (x86)\TortoiseHg\hg.exe';
  if TFile.Exists(LCandidate) then
  begin
    GCachedHgPath := LCandidate;
    Exit(GCachedHgPath);
  end;

  Result := '';
end;

function FindHgRepoRoot(const APath: string): string;
var
  LDir: string;
  LParent: string;
  LHgDir: string;
  LHgPath: string;
  LOutput: string;
  LProcess: TVCSProcess;
begin
  // Return cached result if querying for the same source path
  if (GCachedHgRepoRoot <> '') and SameText(APath, GCachedHgRepoRootSource) then
    Exit(GCachedHgRepoRoot);

  Result := '';

  // Determine starting directory
  if TDirectory.Exists(APath) then
    LDir := APath
  else
    LDir := TPath.GetDirectoryName(APath);

  if LDir = '' then
    Exit;

  // Walk parent directories looking for .hg folder
  while LDir <> '' do
  begin
    LHgDir := TPath.Combine(LDir, '.hg');
    if TDirectory.Exists(LHgDir) then
    begin
      // Unlike Git, Mercurial without hg.exe is unusable, so we only
      // confirm if hg.exe is available. No fallback for missing executable.
      LHgPath := FindHgExecutable;
      if LHgPath = '' then
        Exit('');

      // Verify with hg root, but use LDir as the repo root to avoid
      // UNC vs drive letter mismatches (same approach as Git discovery).
      LProcess := TVCSProcess.Create(LHgPath, LDir);
      try
        if LProcess.Execute('root', LOutput) = 0 then
        begin
          Result := LDir;
          GCachedHgRepoRoot := Result;
          GCachedHgRepoRootSource := APath;
          Exit;
        end;
      finally
        LProcess.Free;
      end;

      // hg root failed — not a valid repo despite .hg presence
      Exit('');
    end;

    LParent := TDirectory.GetParent(LDir);
    if (LParent = '') or SameText(LParent, LDir) then
      Break;
    LDir := LParent;
  end;
end;

function FindThgExecutable: string;
var
  LHgPath: string;
begin
  LHgPath := FindHgExecutable;
  if LHgPath = '' then
    Exit('');
  Result := TPath.Combine(TPath.GetDirectoryName(LHgPath), 'thg.exe');
  if not TFile.Exists(Result) then
    Result := '';
end;

procedure ClearHgDiscoveryCache;
begin
  GCachedHgPath := '';
  GHgPathSearched := False;
  GCachedHgRepoRoot := '';
  GCachedHgRepoRootSource := '';
end;

end.
