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

uses
  System.SysUtils;

/// <summary>
/// Opens the file at the specified commit in a new editor tab.
/// Shows an informational message if the file doesn't exist at that commit.
/// </summary>
procedure NavigateToRevision(const AFileName: string;
  const ACommitHash: string; const ARepoRoot: string;
  ALineNumber: Integer = 0);

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

var
  /// <summary>
  /// Callback invoked after blame is toggled via context menu.
  /// Assigned by Registration.pas to wire menu checkmark synchronization
  /// without creating a circular dependency.
  /// </summary>
  GOnContextMenuToggle: TProc;

implementation

uses
  System.Classes,
  System.IOUtils,
  Vcl.Menus,
  Vcl.Dialogs,
  Vcl.Forms,
  ToolsAPI,
  DX.Blame.VCS.Types,
  DX.Blame.VCS.Provider,
  Winapi.Windows,
  Winapi.ShellAPI,
  DX.Blame.Engine,
  DX.Blame.Formatter,
  DX.Blame.Settings,
  DX.Blame.Hg.Discovery,
  DX.Blame.Renderer;

type
  /// <summary>
  /// Helper object to provide a method-based event handler for the context menu.
  /// Standalone procedures cannot be assigned to TNotifyEvent (method pointer).
  /// </summary>
  TNavigationMenuHandler = class
  public
    procedure OnRevisionClick(Sender: TObject);
    procedure OnEditorPopup(Sender: TObject);
    procedure OnThgAnnotateClick(Sender: TObject);
    procedure OnThgLogClick(Sender: TObject);
    procedure OnToggleBlameClick(Sender: TObject);
  end;

var
  GContextMenuItem: TMenuItem;
  GSeparatorItem: TMenuItem;
  GThgSeparatorItem: TMenuItem;
  GThgAnnotateItem: TMenuItem;
  GThgLogItem: TMenuItem;
  GEnableBlameItem: TMenuItem;
  GMenuHandler: TNavigationMenuHandler;

/// <summary>
/// Retrieves file content at a specific commit via git show.
/// </summary>
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

function IsRevisionAvailable(const ACommitHash: string): Boolean;
begin
  Result := (ACommitHash <> '') and (BlameEngine.Provider <> nil) and
    (ACommitHash <> BlameEngine.Provider.GetUncommittedHash);
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
  const ACommitHash: string; const ARepoRoot: string;
  ALineNumber: Integer = 0);
var
  LRelPath: string;
  LContent: string;
  LTempDir: string;
  LTempFile: string;
  LShortHash: string;
  LBaseName: string;
  LExt: string;
  LActionServices: IOTAActionServices;
  LModuleServices: IOTAModuleServices;
  LModule: IOTAModule;
  LSourceEditor: IOTASourceEditor;
  LEditView: IOTAEditView;
  LEditPos: TOTAEditPos;
  i: Integer;
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

  // 5. Auto-scroll to source line if requested
  if ALineNumber > 0 then
  begin
    if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
    begin
      LModule := LModuleServices.FindModule(LTempFile);
      if LModule <> nil then
      begin
        for i := 0 to LModule.GetModuleFileCount - 1 do
        begin
          if Supports(LModule.GetModuleFileEditor(i), IOTASourceEditor, LSourceEditor) then
          begin
            LSourceEditor.Show;
            LEditView := (BorlandIDEServices as IOTAEditorServices).TopView;
            if LEditView <> nil then
            begin
              LEditPos.Col := 1;
              LEditPos.Line := ALineNumber;
              LEditView.SetCursorPos(LEditPos);
              LEditView.Center(ALineNumber, 1);
              LEditView.Paint;
            end;
            Break;
          end;
        end;
      end;
    end;
  end;
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
  if not BlameEngine.VCSAvailable then
    Exit;

  if not TryGetCurrentLineInfo(LFileName, LLineInfo) then
    Exit;

  if not IsRevisionAvailable(LLineInfo.CommitHash) then
    Exit;

  NavigateToRevision(LFileName, LLineInfo.CommitHash, BlameEngine.RepoRoot,
    LLineInfo.FinalLine);
end;

/// <summary>
/// Launches thg.exe with the given command, repo root, and file path.
/// Fire-and-forget via ShellExecute -- does not wait for thg to exit.
/// </summary>
procedure LaunchThg(const ACommand, ARepoRoot, AFilePath: string);
var
  LThgPath: string;
  LArgs: string;
begin
  LThgPath := FindThgExecutable;
  if LThgPath = '' then
    Exit;
  LArgs := ACommand + ' -R "' + ARepoRoot + '" "' + AFilePath + '"';
  ShellExecute(0, 'open', PChar(LThgPath), PChar(LArgs), PChar(ARepoRoot), SW_SHOWNORMAL);
end;

procedure TNavigationMenuHandler.OnThgAnnotateClick(Sender: TObject);
var
  LEditorServices: IOTAEditorServices;
  LTopView: IOTAEditView;
  LFileName: string;
begin
  if not BlameEngine.VCSAvailable then
    Exit;
  if not Supports(BorlandIDEServices, IOTAEditorServices, LEditorServices) then
    Exit;
  LTopView := LEditorServices.TopView;
  if LTopView = nil then
    Exit;
  LFileName := LTopView.Buffer.FileName;
  LaunchThg('annotate', BlameEngine.RepoRoot, LFileName);
end;

procedure TNavigationMenuHandler.OnThgLogClick(Sender: TObject);
var
  LEditorServices: IOTAEditorServices;
  LTopView: IOTAEditView;
  LFileName: string;
begin
  if not BlameEngine.VCSAvailable then
    Exit;
  if not Supports(BorlandIDEServices, IOTAEditorServices, LEditorServices) then
    Exit;
  LTopView := LEditorServices.TopView;
  if LTopView = nil then
    Exit;
  LFileName := LTopView.Buffer.FileName;
  LaunchThg('log', BlameEngine.RepoRoot, LFileName);
end;

procedure TNavigationMenuHandler.OnToggleBlameClick(Sender: TObject);
begin
  BlameSettings.Enabled := not BlameSettings.Enabled;
  BlameSettings.Save;
  if Assigned(GOnContextMenuToggle) then
    GOnContextMenuToggle();
  InvalidateAllEditors;
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
  // Free in reverse order of insertion; items remove themselves from parent
  FreeAndNil(GThgLogItem);
  FreeAndNil(GThgAnnotateItem);
  FreeAndNil(GThgSeparatorItem);
  FreeAndNil(GContextMenuItem);
  FreeAndNil(GSeparatorItem);
  FreeAndNil(GEnableBlameItem);
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
    // Blame toggle with checkbox (always shown, does not require VCS)
    GEnableBlameItem := TMenuItem.Create(nil);
    GEnableBlameItem.Caption := 'Inline Blaming enabled';
    GEnableBlameItem.ShortCut := Vcl.Menus.ShortCut(Ord('B'), [ssCtrl, ssAlt]);
    GEnableBlameItem.Checked := BlameSettings.Enabled;
    GEnableBlameItem.OnClick := Self.OnToggleBlameClick;
    TPopupMenu(Sender).Items.Add(GEnableBlameItem);

    // Determine caption and availability from current line's blame data
    LAvailable := BlameEngine.VCSAvailable and
      TryGetCurrentLineInfo(LFileName, LLineInfo) and
      IsRevisionAvailable(LLineInfo.CommitHash);

    if LAvailable then
      LCaption := 'Show revision ' + FormatRevisionTime(LLineInfo.AuthorTime)
    else
      LCaption := 'Show revision...';

    GContextMenuItem := TMenuItem.Create(nil);
    GContextMenuItem.Caption := LCaption;
    GContextMenuItem.Enabled := LAvailable;
    GContextMenuItem.OnClick := Self.OnRevisionClick;
    TPopupMenu(Sender).Items.Add(GContextMenuItem);

    // TortoiseHg items: only when Mercurial is active and thg.exe is available
    if (BlameEngine.Provider <> nil) and
       SameText(BlameEngine.Provider.GetDisplayName, 'Mercurial') and
       (FindThgExecutable <> '') then
    begin
      GThgAnnotateItem := TMenuItem.Create(nil);
      GThgAnnotateItem.Caption := 'Open in TortoiseHg Annotate';
      GThgAnnotateItem.OnClick := Self.OnThgAnnotateClick;
      TPopupMenu(Sender).Items.Add(GThgAnnotateItem);

      GThgLogItem := TMenuItem.Create(nil);
      GThgLogItem.Caption := 'Open in TortoiseHg Log';
      GThgLogItem.OnClick := Self.OnThgLogClick;
      TPopupMenu(Sender).Items.Add(GThgLogItem);
    end;

    // Separator after the entire Blame group
    GSeparatorItem := TMenuItem.Create(nil);
    GSeparatorItem.Caption := '-';
    TPopupMenu(Sender).Items.Add(GSeparatorItem);
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

  // Restore original OnPopup handler (nil is a valid restore target when no
  // original handler existed -- without this guard the hook would persist after unload)
  if GHookedPopup <> nil then
    GHookedPopup.OnPopup := GOriginalOnPopup;

  GHookedPopup := nil;
  GOriginalOnPopup := nil;
  FreeAndNil(GMenuHandler);
end;

end.
