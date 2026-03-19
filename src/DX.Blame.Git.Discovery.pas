/// <summary>
/// DX.Blame.Git.Discovery
/// Git executable finder and repository root detection.
/// </summary>
///
/// <remarks>
/// Provides functions to locate git.exe on the system (PATH and common
/// install locations) and to detect whether a given directory resides
/// inside a git repository. Results are cached per session and cleared
/// on project switch via ClearDiscoveryCache.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Git.Discovery;

interface

/// <summary>
/// Returns the full path to git.exe, or an empty string if not found.
/// The result is cached after the first successful search.
/// </summary>
function FindGitExecutable: string;

/// <summary>
/// Finds the git repository root for the given path by walking parent
/// directories for a .git folder, then verifying with git rev-parse.
/// Returns an empty string if the path is not inside a git repository.
/// </summary>
function FindGitRepoRoot(const APath: string): string;

/// <summary>
/// Resets cached git path and repo root. Call on project switch.
/// </summary>
procedure ClearDiscoveryCache;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Winapi.Windows;

var
  GCachedGitPath: string;
  GGitPathSearched: Boolean;
  GCachedRepoRoot: string;
  GCachedRepoRootSource: string;

/// <summary>
/// Executes a git command synchronously and captures stdout.
/// Used internally for rev-parse verification. Returns the exit code.
/// </summary>
function ExecuteGitSync(const AGitPath, AWorkDir, AArgs: string;
  out AOutput: string): Integer;
var
  LSA: TSecurityAttributes;
  LReadPipe, LWritePipe: THandle;
  LSI: TStartupInfo;
  LPI: TProcessInformation;
  LBuffer: TBytes;
  LBytesRead: DWORD;
  LStream: TBytesStream;
  LExitCode: DWORD;
  LCmdLine: string;
begin
  Result := -1;
  AOutput := '';

  LSA.nLength := SizeOf(LSA);
  LSA.bInheritHandle := True;
  LSA.lpSecurityDescriptor := nil;

  if not CreatePipe(LReadPipe, LWritePipe, @LSA, 0) then
    Exit;
  try
    SetHandleInformation(LReadPipe, HANDLE_FLAG_INHERIT, 0);

    FillChar(LSI, SizeOf(LSI), 0);
    LSI.cb := SizeOf(LSI);
    LSI.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    LSI.hStdOutput := LWritePipe;
    LSI.hStdError := LWritePipe;
    LSI.wShowWindow := SW_HIDE;

    LCmdLine := Format('"%s" %s', [AGitPath, AArgs]);

    if not CreateProcess(nil, PChar(LCmdLine), nil, nil, True,
      CREATE_NO_WINDOW, nil, PChar(AWorkDir), LSI, LPI) then
      Exit;
    try
      // Close write end immediately to avoid deadlock
      CloseHandle(LWritePipe);
      LWritePipe := 0;

      LStream := TBytesStream.Create;
      try
        SetLength(LBuffer, 4096);
        while ReadFile(LReadPipe, LBuffer[0], Length(LBuffer), LBytesRead, nil)
          and (LBytesRead > 0) do
          LStream.WriteBuffer(LBuffer[0], LBytesRead);

        AOutput := TEncoding.UTF8.GetString(LStream.Bytes, 0, Integer(LStream.Size));
      finally
        LStream.Free;
      end;

      WaitForSingleObject(LPI.hProcess, 5000);
      GetExitCodeProcess(LPI.hProcess, LExitCode);
      Result := Integer(LExitCode);
    finally
      CloseHandle(LPI.hThread);
      CloseHandle(LPI.hProcess);
    end;
  finally
    if LWritePipe <> 0 then
      CloseHandle(LWritePipe);
    CloseHandle(LReadPipe);
  end;
end;

function FindGitExecutable: string;
var
  LPathEnv: string;
  LDirs: TArray<string>;
  LDir: string;
  LCandidate: string;
  LLocalAppData: string;
begin
  if GGitPathSearched then
    Exit(GCachedGitPath);

  GGitPathSearched := True;
  GCachedGitPath := '';

  // 1. Search system PATH
  LPathEnv := System.SysUtils.GetEnvironmentVariable('PATH');
  if LPathEnv <> '' then
  begin
    LDirs := LPathEnv.Split([';']);
    for LDir in LDirs do
    begin
      if LDir = '' then
        Continue;
      LCandidate := TPath.Combine(Trim(LDir), 'git.exe');
      if TFile.Exists(LCandidate) then
      begin
        GCachedGitPath := LCandidate;
        Exit(GCachedGitPath);
      end;
    end;
  end;

  // 2. Common install locations
  LCandidate := 'C:\Program Files\Git\cmd\git.exe';
  if TFile.Exists(LCandidate) then
  begin
    GCachedGitPath := LCandidate;
    Exit(GCachedGitPath);
  end;

  LCandidate := 'C:\Program Files (x86)\Git\cmd\git.exe';
  if TFile.Exists(LCandidate) then
  begin
    GCachedGitPath := LCandidate;
    Exit(GCachedGitPath);
  end;

  // 3. User-specific location
  LLocalAppData := System.SysUtils.GetEnvironmentVariable('LOCALAPPDATA');
  if LLocalAppData <> '' then
  begin
    LCandidate := TPath.Combine(LLocalAppData, 'Programs\Git\cmd\git.exe');
    if TFile.Exists(LCandidate) then
    begin
      GCachedGitPath := LCandidate;
      Exit(GCachedGitPath);
    end;
  end;

  Result := '';
end;

function FindGitRepoRoot(const APath: string): string;
var
  LDir: string;
  LParent: string;
  LGitDir: string;
  LGitPath: string;
  LOutput: string;
begin
  // Return cached result if querying for the same source path
  if (GCachedRepoRoot <> '') and SameText(APath, GCachedRepoRootSource) then
    Exit(GCachedRepoRoot);

  Result := '';

  // Determine starting directory
  if TDirectory.Exists(APath) then
    LDir := APath
  else
    LDir := TPath.GetDirectoryName(APath);

  if LDir = '' then
    Exit;

  // Walk parent directories looking for .git folder
  while LDir <> '' do
  begin
    LGitDir := TPath.Combine(LDir, '.git');
    if TDirectory.Exists(LGitDir) then
    begin
      // Verify with git rev-parse --show-toplevel
      LGitPath := FindGitExecutable;
      if LGitPath <> '' then
      begin
        if ExecuteGitSync(LGitPath, LDir, 'rev-parse --show-toplevel', LOutput) = 0 then
        begin
          Result := Trim(LOutput);
          // Normalize forward slashes from git to backslashes
          Result := StringReplace(Result, '/', '\', [rfReplaceAll]);
          GCachedRepoRoot := Result;
          GCachedRepoRootSource := APath;
          Exit;
        end;
      end;
      // Fallback: if git not found, trust the .git folder presence
      Result := LDir;
      GCachedRepoRoot := Result;
      GCachedRepoRootSource := APath;
      Exit;
    end;

    LParent := TDirectory.GetParent(LDir);
    if (LParent = '') or SameText(LParent, LDir) then
      Break;
    LDir := LParent;
  end;
end;

procedure ClearDiscoveryCache;
begin
  GCachedGitPath := '';
  GGitPathSearched := False;
  GCachedRepoRoot := '';
  GCachedRepoRootSource := '';
end;

end.
