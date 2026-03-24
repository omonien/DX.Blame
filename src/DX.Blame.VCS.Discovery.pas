/// <summary>
/// DX.Blame.VCS.Discovery
/// VCS detection orchestrator with dual-VCS prompt and persistence.
/// </summary>
///
/// <remarks>
/// TVCSDiscovery scans parent directories for .git and .hg markers to detect
/// which version control systems are present. For single-VCS repos it returns
/// the matching provider directly. For dual-VCS repos it prompts the user once
/// via a TaskDialog and persists the choice per project path in settings.ini.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.VCS.Discovery;

interface

uses
  DX.Blame.VCS.Provider;

type
  /// <summary>Available VCS types detected by the discovery scan.</summary>
  TVCSType = (vtNone, vtGit, vtMercurial);

  /// <summary>
  /// Orchestrates VCS detection by scanning for .git/.hg markers, resolving
  /// conflicts via user prompt with persisted choice, and returning the
  /// appropriate IVCSProvider.
  /// </summary>
  TVCSDiscovery = class
  public
    /// <summary>
    /// Detects the appropriate VCS provider for the given project path.
    /// Returns nil if no VCS is found or the VCS executable is missing.
    /// ARepoRoot receives the repository root directory on success.
    /// </summary>
    class function DetectProvider(const AProjectPath: string;
      out ARepoRoot: string): IVCSProvider;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Vcl.Dialogs,
  Vcl.Controls,
  DX.Blame.Git.Provider,
  DX.Blame.Hg.Provider,
  DX.Blame.Settings;

{ TVCSDiscovery - Private class methods }

class function TVCSDiscovery.DetectProvider(const AProjectPath: string;
  out ARepoRoot: string): IVCSProvider;

  function ScanForVCS(const APath: string; out AHasGit, AHasHg: Boolean): Boolean;
  var
    LDir: string;
    LParent: string;
  begin
    AHasGit := False;
    AHasHg := False;

    if TDirectory.Exists(APath) then
      LDir := APath
    else
      LDir := TPath.GetDirectoryName(APath);

    if LDir = '' then
      Exit(False);

    while LDir <> '' do
    begin
      if (not AHasGit) and TDirectory.Exists(TPath.Combine(LDir, '.git')) then
        AHasGit := True;
      if (not AHasHg) and TDirectory.Exists(TPath.Combine(LDir, '.hg')) then
        AHasHg := True;

      if AHasGit and AHasHg then
        Break;

      LParent := TDirectory.GetParent(LDir);
      if (LParent = '') or SameText(LParent, LDir) then
        Break;
      LDir := LParent;
    end;

    Result := AHasGit or AHasHg;
  end;

  function PromptForVCS(const AProjPath: string): TVCSType;
  var
    LDialog: TTaskDialog;
    LBtnGit: TTaskDialogButtonItem;
    LBtnHg: TTaskDialogButtonItem;
  begin
    LDialog := TTaskDialog.Create(nil);
    try
      LDialog.Caption := 'DX.Blame';
      LDialog.Title := 'DX.Blame - Multiple VCS Detected';
      LDialog.Text := 'Both Git and Mercurial repositories were found for this project. ' +
        'Which VCS should DX.Blame use for blame annotations?';
      LDialog.CommonButtons := [];
      LDialog.MainIcon := tdiInformation;

      LBtnGit := TTaskDialogButtonItem(LDialog.Buttons.Add);
      LBtnGit.Caption := 'Use Git';
      LBtnGit.ModalResult := 100;

      LBtnHg := TTaskDialogButtonItem(LDialog.Buttons.Add);
      LBtnHg.Caption := 'Use Mercurial';
      LBtnHg.ModalResult := 101;

      if LDialog.Execute then
      begin
        case LDialog.ModalResult of
          100:
          begin
            BlameSettings.SetVCSChoice(AProjPath, 'Git');
            Result := vtGit;
          end;
          101:
          begin
            BlameSettings.SetVCSChoice(AProjPath, 'Mercurial');
            Result := vtMercurial;
          end;
        else
          // User closed dialog without choosing — default to Git
          BlameSettings.SetVCSChoice(AProjPath, 'Git');
          Result := vtGit;
        end;
      end
      else
      begin
        // Dialog cancelled — default to Git (preserves existing behavior)
        BlameSettings.SetVCSChoice(AProjPath, 'Git');
        Result := vtGit;
      end;
    finally
      LDialog.Free;
    end;
  end;

  function ResolveChoice(const AProjPath: string; AHasGit, AHasHg: Boolean): TVCSType;
  var
    LStored: string;
  begin
    if AHasGit and AHasHg then
    begin
      LStored := BlameSettings.GetVCSChoice(AProjPath);
      if SameText(LStored, 'Git') then
        Result := vtGit
      else if SameText(LStored, 'Mercurial') then
        Result := vtMercurial
      else
        Result := PromptForVCS(AProjPath);
    end
    else if AHasGit then
      Result := vtGit
    else if AHasHg then
      Result := vtMercurial
    else
      Result := vtNone;
  end;

var
  LHasGit: Boolean;
  LHasHg: Boolean;
  LChoice: TVCSType;
begin
  Result := nil;
  ARepoRoot := '';

  if not ScanForVCS(AProjectPath, LHasGit, LHasHg) then
    Exit;

  LChoice := ResolveChoice(AProjectPath, LHasGit, LHasHg);

  case LChoice of
    vtGit:
      Result := TGitProvider.Create;
    vtMercurial:
      Result := THgProvider.Create;
    vtNone:
      Exit;
  end;

  // Validate: executable must exist and repo root must resolve
  if Result.FindExecutable = '' then
  begin
    Result := nil;
    Exit;
  end;

  ARepoRoot := Result.FindRepoRoot(AProjectPath);
  if ARepoRoot = '' then
  begin
    Result := nil;
    Exit;
  end;
end;

end.
