/// <summary>
/// DX.Blame.Statusbar
/// Statusbar panel component that displays blame info for the current caret line.
/// </summary>
///
/// <remarks>
/// TDXBlameStatusbar attaches a TStatusPanel to the IDE's main statusbar and
/// updates it on every caret-moved event (via GOnCaretMoved in Renderer.pas).
/// FreeNotification ensures safe cleanup if the edit window form is destroyed
/// while the panel is still attached. Clicking the panel opens the commit
/// detail popup. The panel is hidden (empty text) when no blame data is
/// available or when ShowStatusbar is False in settings.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Statusbar;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.ComCtrls,
  DX.Blame.VCS.Types;

type
  /// <summary>
  /// Manages a single TStatusPanel in the IDE statusbar showing blame info
  /// for the current caret line. Handles panel lifecycle and click-to-popup.
  /// </summary>
  TDXBlameStatusbar = class(TComponent)
  private
    FPanel: TStatusPanel;
    FStatusBar: TStatusBar;
    FPanelIndex: Integer;
    FHasBlameData: Boolean;
    FFileName: string;
    FFOldOnMouseDown: TMouseEvent;
    FFOldOnMouseMove: TMouseMoveEvent;
    FLineInfo: TBlameLineInfo;
    FPopup: TObject; // TDXBlamePopup — forward-declared to avoid circular uses

    /// <summary>Returns True if X is within our panel's horizontal bounds.</summary>
    function IsClickOnOurPanel(X: Integer): Boolean;
    /// <summary>Shows the blame popup near the given X coordinate.</summary>
    procedure ShowPopupAt(X: Integer);
    procedure HandleStatusBarMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure HandleStatusBarMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
  protected
    /// <summary>
    /// Handles FreeNotification from the statusbar host. When the statusbar
    /// is destroyed, clears all panel references to prevent access violations.
    /// </summary>
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>
    /// Attaches this component to the given IDE statusbar, adding a blame panel.
    /// Detaches from any previously attached statusbar first.
    /// </summary>
    procedure AttachToStatusBar(AStatusBar: TStatusBar);

    /// <summary>
    /// Removes the blame panel from the statusbar and restores the original
    /// OnMouseDown handler. Safe to call multiple times.
    /// </summary>
    procedure DetachFromStatusBar;

    /// <summary>
    /// Updates the statusbar panel text for the given file and line number.
    /// Clears the panel when blame data is unavailable or ShowStatusbar is False.
    /// </summary>
    procedure UpdateForLine(const AFileName: string; ALine: Integer);
  end;

implementation

uses
  Vcl.Forms,
  Winapi.Windows,
  DX.Blame.Settings,
  DX.Blame.Formatter,
  DX.Blame.Engine,
  DX.Blame.Cache,
  DX.Blame.Popup;

{ TDXBlameStatusbar }

constructor TDXBlameStatusbar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPanelIndex := -1;
  FHasBlameData := False;
  FPopup := nil;
end;

destructor TDXBlameStatusbar.Destroy;
begin
  DetachFromStatusBar;
  FPopup.Free;
  inherited Destroy;
end;

procedure TDXBlameStatusbar.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  // The host statusbar was destroyed — nil all references to avoid AV
  if (Operation = opRemove) and (AComponent = FStatusBar) then
  begin
    FPanel := nil;
    FStatusBar := nil;
    FPanelIndex := -1;
    FFOldOnMouseDown := nil;
  end;
end;

procedure TDXBlameStatusbar.AttachToStatusBar(AStatusBar: TStatusBar);
begin
  // Detach from previous statusbar if any
  DetachFromStatusBar;

  if AStatusBar = nil then
    Exit;

  FStatusBar := AStatusBar;
  // Register for FreeNotification so we learn when the statusbar is destroyed
  AStatusBar.FreeNotification(Self);

  // Add the blame panel at the end of the statusbar
  FPanel := FStatusBar.Panels.Add;
  FPanel.Width := 300;
  FPanel.Style := psText;
  FPanel.Text := '';
  FPanelIndex := FPanel.Index;

  // Chain the existing mouse handlers
  FFOldOnMouseDown := FStatusBar.OnMouseDown;
  FStatusBar.OnMouseDown := HandleStatusBarMouseDown;
  FFOldOnMouseMove := FStatusBar.OnMouseMove;
  FStatusBar.OnMouseMove := HandleStatusBarMouseMove;
end;

procedure TDXBlameStatusbar.DetachFromStatusBar;
var
  i: Integer;
begin
  if FStatusBar = nil then
    Exit;

  // Restore original mouse handlers before removing the panel
  FStatusBar.OnMouseDown := FFOldOnMouseDown;
  FStatusBar.OnMouseMove := FFOldOnMouseMove;

  // Remove the panel by reference (index may have shifted)
  if FPanel <> nil then
  begin
    for i := 0 to FStatusBar.Panels.Count - 1 do
    begin
      if FStatusBar.Panels.Items[i] = FPanel then
      begin
        FStatusBar.Panels.Delete(i);
        Break;
      end;
    end;
  end;

  // Unregister FreeNotification
  FStatusBar.RemoveFreeNotification(Self);

  FPanel := nil;
  FStatusBar := nil;
  FPanelIndex := -1;
  FFOldOnMouseDown := nil;
  FFOldOnMouseMove := nil;
end;

procedure TDXBlameStatusbar.UpdateForLine(const AFileName: string;
  ALine: Integer);
var
  LBlameData: TBlameData;
  LLineIndex: Integer;
  LText: string;
begin
  if (FPanel = nil) or (FStatusBar = nil) then
    Exit;

  if not BlameSettings.ShowStatusbar then
  begin
    FPanel.Text := '';
    FHasBlameData := False;
    Exit;
  end;

  if (AFileName = '') or (ALine <= 0) then
  begin
    FPanel.Text := '';
    FHasBlameData := False;
    Exit;
  end;

  if not BlameEngine.Cache.TryGet(AFileName, LBlameData) then
  begin
    FPanel.Text := '';
    FHasBlameData := False;
    Exit;
  end;

  LLineIndex := ALine - 1;
  if (LLineIndex < 0) or (LLineIndex >= Length(LBlameData.Lines)) then
  begin
    FPanel.Text := '';
    FHasBlameData := False;
    Exit;
  end;

  // Format using existing blame annotation formatter
  LText := FormatBlameAnnotation(LBlameData.Lines[LLineIndex], BlameSettings);
  FPanel.Text := LText;

  // Store line info for click handler
  FLineInfo := LBlameData.Lines[LLineIndex];
  FHasBlameData := True;
  FFileName := AFileName;
end;

function TDXBlameStatusbar.IsClickOnOurPanel(X: Integer): Boolean;
var
  LPanelLeft: Integer;
  i: Integer;
  LCurrentIndex: Integer;
begin
  Result := False;
  if (FPanel = nil) or (FStatusBar = nil) then
    Exit;

  // Find our panel's current index (may shift if IDE adds/removes panels)
  LCurrentIndex := -1;
  for i := 0 to FStatusBar.Panels.Count - 1 do
    if FStatusBar.Panels.Items[i] = FPanel then
    begin
      LCurrentIndex := i;
      Break;
    end;

  if LCurrentIndex < 0 then
    Exit;

  LPanelLeft := 0;
  for i := 0 to LCurrentIndex - 1 do
    LPanelLeft := LPanelLeft + FStatusBar.Panels.Items[i].Width;
  Result := (X >= LPanelLeft) and (X < LPanelLeft + FPanel.Width);
end;

procedure TDXBlameStatusbar.ShowPopupAt(X: Integer);
var
  LPopup: TDXBlamePopup;
  LScreenPos: TPoint;
  LRepoRoot: string;
  LRelPath: string;
begin
  LScreenPos := FStatusBar.ClientToScreen(Point(X, 0));

  LRepoRoot := BlameEngine.RepoRoot;
  if LRepoRoot <> '' then
    LRelPath := ExtractRelativePath(
      IncludeTrailingPathDelimiter(LRepoRoot), FFileName)
  else
    LRelPath := ExtractFileName(FFileName);
  LRelPath := StringReplace(LRelPath, '\', '/', [rfReplaceAll]);

  if FPopup = nil then
    FPopup := TDXBlamePopup.Create(nil);
  LPopup := TDXBlamePopup(FPopup);

  if LPopup.Visible then
    LPopup.UpdateContent(FLineInfo, LRepoRoot, LRelPath)
  else if BlameSettings.PopupTrigger = ptHover then
    LPopup.ShowForHover(FLineInfo, LScreenPos, LRepoRoot, LRelPath)
  else
    LPopup.ShowForCommit(FLineInfo, LScreenPos, LRepoRoot, LRelPath);
end;

procedure TDXBlameStatusbar.HandleStatusBarMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button = mbLeft) and FHasBlameData and
     (BlameSettings.PopupTrigger = ptClick) and IsClickOnOurPanel(X) then
  begin
    ShowPopupAt(X);
    Exit;
  end;

  if Assigned(FFOldOnMouseDown) then
    FFOldOnMouseDown(Sender, Button, Shift, X, Y);
end;

procedure TDXBlameStatusbar.HandleStatusBarMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
  if FHasBlameData and (BlameSettings.PopupTrigger = ptHover) and
     IsClickOnOurPanel(X) then
  begin
    // Already showing popup — skip
    if (FPopup <> nil) and TDXBlamePopup(FPopup).Visible then
    begin
      if Assigned(FFOldOnMouseMove) then
        FFOldOnMouseMove(Sender, Shift, X, Y);
      Exit;
    end;
    ShowPopupAt(X);
  end
  else
  begin
    // Mouse left our panel — hide hover popup
    if (FPopup <> nil) and TDXBlamePopup(FPopup).Visible and
       (BlameSettings.PopupTrigger = ptHover) then
    begin
      // Only hide if cursor is not over the popup itself
      var LCursorPos: TPoint;
      GetCursorPos(LCursorPos);
      if not PtInRect(TDXBlamePopup(FPopup).BoundsRect, LCursorPos) then
        TDXBlamePopup(FPopup).Hide;
    end;
  end;

  if Assigned(FFOldOnMouseMove) then
    FFOldOnMouseMove(Sender, Shift, X, Y);
end;

end.
