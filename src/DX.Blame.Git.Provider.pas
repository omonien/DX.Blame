/// <summary>
/// DX.Blame.Git.Provider
/// Git-specific IVCSProvider implementation delegating to existing Git units.
/// </summary>
///
/// <remarks>
/// TGitProvider is a thin delegation wrapper implementing IVCSProvider for Git.
/// It does not contain new logic; all operations delegate to the existing
/// DX.Blame.Git.Discovery, DX.Blame.Git.Process, and DX.Blame.Git.Blame units.
/// This class serves as the bridge between the VCS-neutral abstraction layer
/// and the Git-specific implementation.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Git.Provider;

interface

uses
  Winapi.Windows,
  DX.Blame.VCS.Types,
  DX.Blame.VCS.Provider;

type
  /// <summary>
  /// Git-specific implementation of IVCSProvider.
  /// Delegates all operations to existing Git discovery, process, and blame units.
  /// </summary>
  TGitProvider = class(TInterfacedObject, IVCSProvider)
  public
    { IVCSProvider }
    function ExecuteBlame(const ARepoRoot, AFilePath: string;
      out AOutput: string; var AProcessHandle: THandle): Integer;
    function ParseBlameOutput(const AOutput: string): TArray<TBlameLineInfo>;
    function GetCommitMessage(const ARepoRoot, ACommitHash: string;
      out AMessage: string): Boolean;
    function GetFileDiff(const ARepoRoot, ACommitHash, ARelativePath: string;
      out ADiff: string): Boolean;
    function GetFullDiff(const ARepoRoot, ACommitHash: string;
      out ADiff: string): Boolean;
    function GetFileAtRevision(const ARepoRoot, ACommitHash, ARelativePath: string;
      out AContent: string): Boolean;
    function FindExecutable: string;
    function FindRepoRoot(const APath: string): string;
    procedure ClearDiscoveryCache;
    function GetDisplayName: string;
    function GetUncommittedHash: string;
    function GetUncommittedAuthor: string;
  end;

implementation

uses
  System.SysUtils,
  DX.Blame.Git.Types,
  DX.Blame.Git.Process,
  DX.Blame.Git.Discovery,
  DX.Blame.Git.Blame;

{ TGitProvider }

function TGitProvider.ExecuteBlame(const ARepoRoot, AFilePath: string;
  out AOutput: string; var AProcessHandle: THandle): Integer;
var
  LProcess: TGitProcess;
  LRelPath: string;
begin
  LProcess := TGitProcess.Create(FindGitExecutable, ARepoRoot);
  try
    LRelPath := ExtractRelativePath(IncludeTrailingPathDelimiter(ARepoRoot), AFilePath);
    LRelPath := StringReplace(LRelPath, '\', '/', [rfReplaceAll]);
    Result := LProcess.ExecuteAsync(
      'blame --line-porcelain -- "' + LRelPath + '"', AOutput, AProcessHandle);
  finally
    LProcess.Free;
  end;
end;

function TGitProvider.ParseBlameOutput(const AOutput: string): TArray<TBlameLineInfo>;
begin
  DX.Blame.Git.Blame.ParseBlameOutput(AOutput, Result);
end;

function TGitProvider.GetCommitMessage(const ARepoRoot, ACommitHash: string;
  out AMessage: string): Boolean;
var
  LProcess: TGitProcess;
  LOutput: string;
begin
  LProcess := TGitProcess.Create(FindGitExecutable, ARepoRoot);
  try
    Result := LProcess.Execute('log -1 --format=%B ' + ACommitHash, LOutput) = 0;
    if Result then
      AMessage := Trim(LOutput);
  finally
    LProcess.Free;
  end;
end;

function TGitProvider.GetFileDiff(const ARepoRoot, ACommitHash, ARelativePath: string;
  out ADiff: string): Boolean;
var
  LProcess: TGitProcess;
  LOutput: string;
begin
  LProcess := TGitProcess.Create(FindGitExecutable, ARepoRoot);
  try
    Result := LProcess.Execute('show ' + ACommitHash + ' -- "' + ARelativePath + '"', LOutput) = 0;
    if Result then
      ADiff := LOutput;
  finally
    LProcess.Free;
  end;
end;

function TGitProvider.GetFullDiff(const ARepoRoot, ACommitHash: string;
  out ADiff: string): Boolean;
var
  LProcess: TGitProcess;
  LOutput: string;
begin
  LProcess := TGitProcess.Create(FindGitExecutable, ARepoRoot);
  try
    Result := LProcess.Execute('show ' + ACommitHash, LOutput) = 0;
    if Result then
      ADiff := LOutput;
  finally
    LProcess.Free;
  end;
end;

function TGitProvider.GetFileAtRevision(const ARepoRoot, ACommitHash,
  ARelativePath: string; out AContent: string): Boolean;
var
  LProcess: TGitProcess;
  LOutput: string;
begin
  LProcess := TGitProcess.Create(FindGitExecutable, ARepoRoot);
  try
    Result := LProcess.Execute('show ' + ACommitHash + ':' + ARelativePath, LOutput) = 0;
    if Result then
      AContent := LOutput;
  finally
    LProcess.Free;
  end;
end;

function TGitProvider.FindExecutable: string;
begin
  Result := FindGitExecutable;
end;

function TGitProvider.FindRepoRoot(const APath: string): string;
begin
  Result := FindGitRepoRoot(APath);
end;

procedure TGitProvider.ClearDiscoveryCache;
begin
  DX.Blame.Git.Discovery.ClearDiscoveryCache;
end;

function TGitProvider.GetDisplayName: string;
begin
  Result := 'Git';
end;

function TGitProvider.GetUncommittedHash: string;
begin
  Result := cUncommittedHash;
end;

function TGitProvider.GetUncommittedAuthor: string;
begin
  Result := cNotCommittedAuthor;
end;

end.
