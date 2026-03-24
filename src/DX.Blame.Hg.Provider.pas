/// <summary>
/// DX.Blame.Hg.Provider
/// Stub IVCSProvider implementation for Mercurial.
/// </summary>
///
/// <remarks>
/// THgProvider implements IVCSProvider with working discovery operations
/// (delegating to DX.Blame.Hg.Discovery) and stub blame operations that
/// raise ENotSupportedException. Full Mercurial blame support will be
/// implemented in Phase 9.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Hg.Provider;

interface

uses
  Winapi.Windows,
  DX.Blame.VCS.Types,
  DX.Blame.VCS.Provider;

type
  /// <summary>
  /// Mercurial-specific implementation of IVCSProvider.
  /// Discovery methods are functional; blame operations raise ENotSupportedException.
  /// </summary>
  THgProvider = class(TInterfacedObject, IVCSProvider)
  public
    { IVCSProvider - Discovery (functional) }
    function FindExecutable: string;
    function FindRepoRoot(const APath: string): string;
    procedure ClearDiscoveryCache;
    function GetDisplayName: string;
    function GetUncommittedHash: string;
    function GetUncommittedAuthor: string;

    { IVCSProvider - Blame operations (stub - Phase 9) }
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
  end;

implementation

uses
  System.SysUtils,
  DX.Blame.Hg.Discovery;

const
  /// <summary>
  /// Mercurial convention for uncommitted changes: 12 hex f characters.
  /// </summary>
  cHgUncommittedHash = 'ffffffffffff';

  /// <summary>
  /// Display author for uncommitted changes, matching Git provider behavior.
  /// </summary>
  cHgNotCommittedAuthor = 'Not Committed';

{ THgProvider - Discovery }

function THgProvider.FindExecutable: string;
begin
  Result := FindHgExecutable;
end;

function THgProvider.FindRepoRoot(const APath: string): string;
begin
  Result := FindHgRepoRoot(APath);
end;

procedure THgProvider.ClearDiscoveryCache;
begin
  ClearHgDiscoveryCache;
end;

function THgProvider.GetDisplayName: string;
begin
  Result := 'Mercurial';
end;

function THgProvider.GetUncommittedHash: string;
begin
  Result := cHgUncommittedHash;
end;

function THgProvider.GetUncommittedAuthor: string;
begin
  Result := cHgNotCommittedAuthor;
end;

{ THgProvider - Blame stubs }

function THgProvider.ExecuteBlame(const ARepoRoot, AFilePath: string;
  out AOutput: string; var AProcessHandle: THandle): Integer;
begin
  raise ENotSupportedException.Create('Mercurial blame not yet implemented');
end;

function THgProvider.ParseBlameOutput(const AOutput: string): TArray<TBlameLineInfo>;
begin
  raise ENotSupportedException.Create('Mercurial blame not yet implemented');
end;

function THgProvider.GetCommitMessage(const ARepoRoot, ACommitHash: string;
  out AMessage: string): Boolean;
begin
  raise ENotSupportedException.Create('Mercurial blame not yet implemented');
end;

function THgProvider.GetFileDiff(const ARepoRoot, ACommitHash, ARelativePath: string;
  out ADiff: string): Boolean;
begin
  raise ENotSupportedException.Create('Mercurial blame not yet implemented');
end;

function THgProvider.GetFullDiff(const ARepoRoot, ACommitHash: string;
  out ADiff: string): Boolean;
begin
  raise ENotSupportedException.Create('Mercurial blame not yet implemented');
end;

function THgProvider.GetFileAtRevision(const ARepoRoot, ACommitHash,
  ARelativePath: string; out AContent: string): Boolean;
begin
  raise ENotSupportedException.Create('Mercurial blame not yet implemented');
end;

end.
