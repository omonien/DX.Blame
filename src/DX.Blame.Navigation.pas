/// <summary>
/// DX.Blame.Navigation
/// Parent commit navigation for blame archaeology.
/// </summary>
///
/// <remarks>
/// Enables users to trace a line's history through successive commits by
/// navigating to the parent revision. The file content at the parent commit
/// is retrieved via git show, written to a temp file, and opened in a new
/// IDE editor tab. Context menu integration attaches a "Previous Revision"
/// item to the editor popup menu.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Navigation;

interface

/// <summary>
/// Opens the file at the specified commit in a new editor tab.
/// Shows an informational message if the file doesn't exist at that commit.
/// </summary>
procedure NavigateToRevision(const AFileName: string;
  const ACommitHash: string; const ARepoRoot: string);

/// <summary>
/// Returns True if the commit hash is valid for revision navigation.
/// Returns False for empty hashes or uncommitted lines.
/// </summary>
function IsRevisionAvailable(const ACommitHash: string): Boolean;

/// <summary>
/// Attaches "Previous Revision" menu item to the editor context menu.
/// </summary>
procedure AttachContextMenu;

/// <summary>
/// Removes "Previous Revision" menu item from the editor context menu.
/// </summary>
procedure DetachContextMenu;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Vcl.Menus,
  Vcl.Dialogs,
  Vcl.Forms,
  ToolsAPI,
  DX.Blame.VCS.Types,
  DX.Blame.Git.Types,
  DX.Blame.Git.Discovery,
  DX.Blame.Git.Process,
  DX.Blame.Engine,
  DX.Blame.Formatter,
  DX.Blame.Settings;

type
  /// <summary>
  /// Helper object to provide a method-based event handler for the context menu.
  /// Standalone procedures cannot be assigned to TNotifyEvent (method pointer).
  /// </summary>
  TNavigationMenuHandler = class
  public
    procedure OnRevisionClick(Sender: TObject);
    procedure OnEditorPopup(Sender: TObject);
  end;

var
  GContextMenuItem: TMenuItem;
  GSeparatorItem: TMenuItem;
  GMenuHandler: TNavigationMenuHandler;

/// <summary>
/// Retrieves file content at a specific commit via git show.
/// </summary>
function GetFileAtCommit(const ACommitHash, ARelativePath, ARepoRoot: string): string;
var
  LGitPath: string;
  LProcess: TGitProcess;
  LOutput: string;
  LExitCode: Integer;
begin
  Result := '';

  LGitPath := FindGitExecutable;
  if LGitPath = '' then
    Exit;

  LProcess := TGitProcess.Create(LGitPath, ARepoRoot);
  try
    LExitCode := LProcess.Execute('show ' + ACommitHash + ':' + ARelativePath, LOutput);
    if LExitCode = 0 then
      Result := LOutput;
  finally
    LProcess.Free;
  end;
end;

function IsRevisionAvailable(const ACommitHash: string): Boolean;
begin
  Result := (ACommitHash <> '') and (ACommitHash <> cUncommittedHash);
end;

/// <summary>
/// Formats the time portion for the context menu caption, matching the
/// user's configured date format (relative or absolute).
/// </summary>
function FormatRevisionTime(ADateTime: TDateTime): string;
begin
  case BlameSettings.DateFormat of
    dfRelative: Result := FormatRelativeTime(ADateTime);
    dfAbsolute: Result := FormatDateTime('yyyy-mm-dd', ADateTime);
  else
    Result := FormatRelativeTime(ADateTime);
  end;
end;

procedure NavigateToRevision(const AFileName: string;
  const ACommitHash: string; const ARepoRoot: string);
var
  LRelPath: string;
  LContent: string;
  LTempDir: string;
  LTempFile: string;
  LShortHash: string;
  LBaseName: string;
  LExt: string;
  LActionServices: IOTAActionServices;
begin
  if not IsRevisionAvailable(ACommitHash) then
    Exit;

  LShortHash := Copy(ACommitHash, 1, 7);

  // 1. Compute relative path (forward slashes for git)
  LRelPath := ExtractRelativePath(IncludeTrailingPathDelimiter(ARepoRoot), AFileName);
  LRelPath := StringReplace(LRelPath, '\', '/', [rfReplaceAll]);

  // 2. Get file content at the annotated commit
  LContent := GetFileAtCommit(ACommitHash, LRelPath, ARepoRoot);
  if LContent = '' then
  begin
    MessageDlg(Format(
      'Could not retrieve %s at commit %s.',
      [ExtractFileName(AFileName), LShortHash]), mtWarning, [mbOK], 0);
    Exit;
  end;

  // 3. Write to temp file
  LBaseName := ChangeFileExt(ExtractFileName(AFileName), '');
  LExt := ExtractFileExt(AFileName);
  LTempDir := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) + 'DX.Blame';
  ForceDirectories(LTempDir);
  LTempFile := IncludeTrailingPathDelimiter(LTempDir) + LBaseName + '.' + LShortHash + LExt;

  TFile.WriteAllText(LTempFile, LContent, TEncoding.UTF8);

  // 4. Open in IDE
  if Supports(BorlandIDEServices, IOTAActionServices, LActionServices) then
    LActionServices.OpenFile(LTempFile);
end;

{ TNavigationMenuHandler }

/// <summary>
/// Returns the blame line info for the current editor caret line.
/// Returns False if blame data is not available.
/// </summary>
function TryGetCurrentLineInfo(out AFileName: string;
  out ALineInfo: TBlameLineInfo): Boolean;
var
  LEditorServices: IOTAEditorServices;
  LTopView: IOTAEditView;
  LLine: Integer;
  LData: TBlameData;
begin
  Result := False;
  AFileName := '';

  if not Supports(BorlandIDEServices, IOTAEditorServices, LEditorServices) then
    Exit;

  LTopView := LEditorServices.TopView;
  if LTopView = nil then
    Exit;

  AFileName := LTopView.Buffer.FileName;
  LLine := LTopView.CursorPos.Line;

  if not BlameEngine.Cache.TryGet(AFileName, LData) then
    Exit;

  if (LLine < 1) or (LLine > Length(LData.Lines)) then
    Exit;

  ALineInfo := LData.Lines[LLine - 1];
  Result := True;
end;

procedure TNavigationMenuHandler.OnRevisionClick(Sender: TObject);
var
  LFileName: string;
  LLineInfo: TBlameLineInfo;
begin
  if not BlameEngine.GitAvailable then
    Exit;

  if not TryGetCurrentLineInfo(LFileName, LLineInfo) then
    Exit;

  if not IsRevisionAvailable(LLineInfo.CommitHash) then
    Exit;

  NavigateToRevision(LFileName, LLineInfo.CommitHash, BlameEngine.RepoRoot);
end;

var
  GHookedPopup: TPopupMenu;
  GOriginalOnPopup: TNotifyEvent;

/// <summary>
/// Removes our dynamically injected items from the popup menu.
/// Called before each re-injection and during detach.
/// </summary>
procedure RemoveOurItems;
begin
  // Free in reverse order; items remove themselves from parent
  FreeAndNil(GContextMenuItem);
  FreeAndNil(GSeparatorItem);
end;

procedure TNavigationMenuHandler.OnEditorPopup(Sender: TObject);
var
  LFileName: string;
  LLineInfo: TBlameLineInfo;
  LCaption: string;
  LAvailable: Boolean;
begin
  // Clean up any leftover items from previous popup
  RemoveOurItems;

  if (Sender is TPopupMenu) then
  begin
    // Determine caption and availability from current line's blame data
    LAvailable := BlameEngine.GitAvailable and
      TryGetCurrentLineInfo(LFileName, LLineInfo) and
      IsRevisionAvailable(LLineInfo.CommitHash);

    if LAvailable then
      LCaption := 'Show revision ' + FormatRevisionTime(LLineInfo.AuthorTime)
    else
      LCaption := 'Show revision...';

    GSeparatorItem := TMenuItem.Create(nil);
    GSeparatorItem.Caption := '-';
    TPopupMenu(Sender).Items.Add(GSeparatorItem);

    GContextMenuItem := TMenuItem.Create(nil);
    GContextMenuItem.Caption := LCaption;
    GContextMenuItem.Enabled := LAvailable;
    GContextMenuItem.OnClick := Self.OnRevisionClick;
    TPopupMenu(Sender).Items.Add(GContextMenuItem);
  end;

  // Chain to original OnPopup handler
  if Assigned(GOriginalOnPopup) then
    GOriginalOnPopup(Sender);
end;

/// <summary>
/// Finds the editor popup menu via the active edit window form.
/// </summary>
function FindEditorPopupMenu: TPopupMenu;
var
  LNTAServices: INTAEditorServices;
  LEditWindow: INTAEditWindow;
  LForm: TCustomForm;
  LComponent: TComponent;
begin
  Result := nil;

  if not Supports(BorlandIDEServices, INTAEditorServices, LNTAServices) then
    Exit;

  LEditWindow := LNTAServices.TopEditWindow;
  if LEditWindow = nil then
    Exit;

  LForm := LEditWindow.Form;
  if LForm = nil then
    Exit;

  LComponent := LForm.FindComponent('EditorLocalMenu');
  if (LComponent <> nil) and (LComponent is TPopupMenu) then
    Result := TPopupMenu(LComponent);
end;

procedure AttachContextMenu;
var
  LPopup: TPopupMenu;
begin
  if GHookedPopup <> nil then
    Exit;

  LPopup := FindEditorPopupMenu;
  if LPopup = nil then
    Exit;

  // Hook the OnPopup event to inject items dynamically each time
  if GMenuHandler = nil then
    GMenuHandler := TNavigationMenuHandler.Create;
  GOriginalOnPopup := LPopup.OnPopup;
  LPopup.OnPopup := GMenuHandler.OnEditorPopup;
  GHookedPopup := LPopup;
end;

procedure DetachContextMenu;
begin
  RemoveOurItems;

  // Restore original OnPopup handler
  if (GHookedPopup <> nil) and Assigned(GOriginalOnPopup) then
    GHookedPopup.OnPopup := GOriginalOnPopup;

  GHookedPopup := nil;
  GOriginalOnPopup := nil;
  FreeAndNil(GMenuHandler);
end;

end.
