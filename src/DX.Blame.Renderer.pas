/// <summary>
/// DX.Blame.Renderer
/// INTACodeEditorEvents implementation for inline blame painting and click detection.
/// </summary>
///
/// <remarks>
/// TDXBlameRenderer hooks into the Delphi IDE code editor via
/// INTACodeEditorEvents to paint blame annotations inline after the last
/// character of each line. Annotations are rendered in italic style using
/// a theme-derived muted color. Canvas state is saved and restored to
/// prevent IDE painting corruption. On Delphi 12, click detection calls
/// DoAnnotationClick directly from EditorMouseDown without consuming the
/// event. On Delphi 13+, TDXBlameRendererD13 (DX.Blame.Renderer.D13) extends
/// this class with INTACodeEditorEvents370 to consume clicks and track the
/// caret via EditorSetCaretPos.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Renderer;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.Graphics,
  Winapi.Windows,
  ToolsAPI,
  ToolsAPI.Editor;

type
  /// <summary>
  /// Editor events notifier that paints blame annotations inline after
  /// the last character of each code line and handles annotation clicks.
  /// Compatible with Delphi 12+. For Delphi 13 event-consuming behaviour
  /// see TDXBlameRendererD13 in DX.Blame.Renderer.D13.
  /// </summary>
  TDXBlameRenderer = class(TNotifierObject, INTACodeEditorEvents)
  protected
    FCurrentLine: Integer;
    FCurrentEditor: TWinControl;
    FCurrentFileName: string;
    { INTACodeEditorEvents }
    procedure EditorScrolled(const Editor: TWinControl;
      const Direction: TCodeEditorScrollDirection);
    procedure EditorResized(const Editor: TWinControl);
    procedure EditorElided(const Editor: TWinControl;
      const LogicalLineNum: Integer);
    procedure EditorUnElided(const Editor: TWinControl;
      const LogicalLineNum: Integer);
    procedure EditorMouseDown(const Editor: TWinControl;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure EditorMouseMove(const Editor: TWinControl;
      Shift: TShiftState; X, Y: Integer);
    procedure EditorMouseUp(const Editor: TWinControl;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure BeginPaint(const Editor: TWinControl;
      const ForceFullRepaint: Boolean);
    procedure EndPaint(const Editor: TWinControl);
    procedure PaintLine(const Rect: TRect; const Stage: TPaintLineStage;
      const BeforeEvent: Boolean; var AllowDefaultPainting: Boolean;
      const Context: INTACodeEditorPaintContext);
    procedure PaintGutter(const Rect: TRect; const Stage: TPaintGutterStage;
      const BeforeEvent: Boolean; var AllowDefaultPainting: Boolean;
      const Context: INTACodeEditorPaintContext);
    procedure PaintText(const Rect: TRect; const ColNum: SmallInt;
      const Text: string; const SyntaxCode: TOTASyntaxCode;
      const Hilight, BeforeEvent: Boolean;
      var AllowDefaultPainting: Boolean;
      const Context: INTACodeEditorPaintContext);
    function AllowedEvents: TCodeEditorEvents; virtual;
    function AllowedGutterStages: TPaintGutterStages;
    function AllowedLineStages: TPaintLineStages;
    function UIOptions: TCodeEditorUIOptions;
    /// <summary>
    /// Shared click-handling logic for annotation hit-test and popup display.
    /// Called from EditorMouseDown (D12) and TDXBlameRendererD13.EditorMouseDown
    /// (D13, with var Handled). Sets Handled to True when the click is consumed.
    /// </summary>
    procedure DoAnnotationClick(const Editor: TWinControl;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer;
      var Handled: Boolean);
  end;

/// <summary>Registers the renderer notifier with the IDE editor services.</summary>
procedure RegisterRenderer(ANotifier: INTACodeEditorEvents);

/// <summary>Unregisters the renderer notifier from the IDE editor services.</summary>
procedure UnregisterRenderer;

/// <summary>Invalidates the top editor to trigger a repaint cycle.</summary>
procedure InvalidateAllEditors;

/// <summary>Cleans up the popup panel. Called during finalization.</summary>
procedure CleanupPopup;

var
  /// <summary>
  /// Optional callback invoked when the editor caret moves to a new position.
  /// Assigned by Registration.pas to wire statusbar updates. Nil when statusbar
  /// feature is not active.
  /// </summary>
  GOnCaretMoved: procedure(const AFileName: string; ALine: Integer);

implementation

uses
  System.Generics.Collections,
  System.Math,
  Vcl.ExtCtrls,
  DX.Blame.Settings,
  DX.Blame.Formatter,
  DX.Blame.Engine,
  DX.Blame.VCS.Types,
  DX.Blame.Cache,
  DX.Blame.Popup,
  DX.Blame.CommitDetail;

{$IFDEF DEBUG}
var
  GPaintDebugCount: Integer = 0;

procedure DebugLog(const AMsg: string);
var
  LMsgServices: IOTAMessageServices;
begin
  if Supports(BorlandIDEServices, IOTAMessageServices, LMsgServices) then
    LMsgServices.AddTitleMessage(AMsg);
end;
{$ENDIF}

type
  /// <summary>Helper class for hover timer callback.</summary>
  THoverTimerHelper = class
    procedure OnHoverCheck(Sender: TObject);
  end;

var
  GRendererIndex: Integer = -1;
  GPopup: TDXBlamePopup = nil;

  // Per-paint-cycle annotation hit-test data:
  // Maps paint rect top Y to annotation start X
  GAnnotationXByRow: TDictionary<Integer, Integer>;
  // Maps paint rect top Y to logical line number
  GLineByRow: TDictionary<Integer, Integer>;
  // Maps paint rect top Y to hash text pixel width (0 for uncommitted)
  GHashWidthByRow: TDictionary<Integer, Integer>;
  // Cell height from the last paint cycle
  GCellHeight: Integer = 0;
  // Editor TWinControl from the last paint cycle
  GLastPaintEditor: TWinControl = nil;

  // Hover popup state
  GHoverTimerHelper: THoverTimerHelper = nil;
  GHoverCheckTimer: TTimer = nil;
  GHoverPopupLine: Integer = -1;
  GHoverAnnotationScreenRect: TRect;

function DeriveAnnotationColor: TColor;
var
  LServices: INTACodeEditorServices;
  LBgColor: TColor;
  LR, LG, LB: Byte;
begin
  Result := clGray;
  if Supports(BorlandIDEServices, INTACodeEditorServices, LServices) then
  begin
    LBgColor := ColorToRGB(LServices.Options.BackgroundColor[atWhiteSpace]);
    LR := (GetRValue(LBgColor) + 128) div 2;
    LG := (GetGValue(LBgColor) + 128) div 2;
    LB := (GetBValue(LBgColor) + 128) div 2;
    Result := TColor(RGB(LR, LG, LB));
  end;
end;

{ TDXBlameRenderer }

function TDXBlameRenderer.AllowedEvents: TCodeEditorEvents;
begin
  // cevPaintLineEvents for PaintLine; cevMouseEvents for annotation clicks.
  // On Delphi 13+, TDXBlameRendererD13 overrides this to also include
  // cevKeyboardEvents for EditorSetCaretPos-based caret tracking.
  Result := [cevPaintLineEvents, cevMouseEvents];
end;

function TDXBlameRenderer.AllowedLineStages: TPaintLineStages;
begin
  Result := [plsEndPaint];
end;

function TDXBlameRenderer.AllowedGutterStages: TPaintGutterStages;
begin
  Result := [];
end;

function TDXBlameRenderer.UIOptions: TCodeEditorUIOptions;
begin
  Result := [];
end;

procedure TDXBlameRenderer.BeginPaint(const Editor: TWinControl;
  const ForceFullRepaint: Boolean);
begin
  // Clear hit-test data for the new paint cycle
  if GAnnotationXByRow <> nil then
    GAnnotationXByRow.Clear;
  if GLineByRow <> nil then
    GLineByRow.Clear;
  if GHashWidthByRow <> nil then
    GHashWidthByRow.Clear;

  // Hide popup if editor changed (switched tabs)
  if (GLastPaintEditor <> nil) and (GLastPaintEditor <> Editor) then
  begin
    if (GPopup <> nil) and GPopup.Visible then
      GPopup.Hide;
  end;
  GLastPaintEditor := Editor;
end;

procedure TDXBlameRenderer.PaintLine(const Rect: TRect;
  const Stage: TPaintLineStage; const BeforeEvent: Boolean;
  var AllowDefaultPainting: Boolean;
  const Context: INTACodeEditorPaintContext);
var
  LCanvas: TCanvas;
  LLogicalLine: Integer;
  LLineIndex: Integer;
  LFileName: string;
  LBlameData: TBlameData;
  LText: string;
  LAnnotationX: Integer;
  LCaretX: Integer;
  LTextWidth: Integer;
  LRightAlignedX: Integer;
  LSavedFontStyle: TFontStyles;
  LSavedFontColor: TColor;
  LSavedBrushStyle: TBrushStyle;
  LAnnotationColor: TColor;
  LHashLen: Integer;
  LHashText: string;
  LRestText: string;
  LHashWidth: Integer;
begin
  {$IFDEF DEBUG}
  if GPaintDebugCount < 20 then
  begin
    Inc(GPaintDebugCount);
    DebugLog(Format('DX.Blame.Renderer: PaintLine #%d stage=%d before=%s enabled=%s line=%d curLine=%d',
      [GPaintDebugCount, Ord(Stage), BoolToStr(BeforeEvent, True),
       BoolToStr(BlameSettings.Enabled, True),
       Context.LogicalLineNum, FCurrentLine]));
  end;
  {$ENDIF}

  if (Stage <> plsEndPaint) or BeforeEvent then
    Exit;

  if not BlameSettings.Enabled then
    Exit;

  // Skip inline rendering when inline display is disabled
  // (blame may still be globally enabled for statusbar display in Phase 13)
  if not BlameSettings.ShowInline then
    Exit;

  // Store cell height for hit-testing in EditorMouseDown
  GCellHeight := Context.CellSize.cy;

  LLogicalLine := Context.LogicalLineNum;

  // Always read the logical caret line from the EditView -- EditorSetCaretPos
  // Y is view-relative (screen row), not usable for line matching.
  if Context.EditView <> nil then
    FCurrentLine := Context.EditView.CursorPos.Line;

  // Only paint the annotation for the caret line
  if LLogicalLine <> FCurrentLine then
    Exit;

  // Get the file name from the edit view
  if Context.EditView = nil then
    Exit;
  if Context.EditView.Buffer = nil then
    Exit;

  LFileName := Context.EditView.Buffer.FileName;
  if LFileName = '' then
    Exit;

  // Store current file name for click handling
  FCurrentFileName := LFileName;

  // Look up blame data from cache
  if not BlameEngine.Cache.TryGet(LFileName, LBlameData) then
  begin
    {$IFDEF DEBUG}
    if GPaintDebugCount < 20 then
    begin
      Inc(GPaintDebugCount);
      DebugLog('DX.Blame.Renderer: cache miss for ' + LFileName);
    end;
    {$ENDIF}
    Exit;
  end;

  // Skip annotation when buffer has been modified since last save --
  // blame cache is stale and line indices would map to wrong lines
  if Context.EditView.Buffer.IsModified then
    Exit;

  // Index into Lines array (0-based, LogicalLineNum is 1-based)
  LLineIndex := LLogicalLine - 1;
  if (LLineIndex < 0) or (LLineIndex >= Length(LBlameData.Lines)) then
    Exit;

  // Format the annotation text
  LText := FormatBlameAnnotation(LBlameData.Lines[LLineIndex], BlameSettings);
  if LText = '' then
    Exit;

  LCanvas := Context.Canvas;

  // Save canvas state
  LSavedFontStyle := LCanvas.Font.Style;
  LSavedFontColor := LCanvas.Font.Color;
  LSavedBrushStyle := LCanvas.Brush.Style;
  try
    // Set font to italic, keeping editor font name and size
    LCanvas.Font.Style := [fsItalic];

    // Determine annotation color
    if BlameSettings.UseCustomColor then
      LAnnotationColor := BlameSettings.CustomColor
    else
      LAnnotationColor := DeriveAnnotationColor;
    LCanvas.Font.Color := LAnnotationColor;

    // Base X position: after visible text + 3 chars padding
    LAnnotationX := Context.LineState.VisibleTextRect.Right +
      (Context.CellSize.cx * 3);

    case BlameSettings.AnnotationPosition of
      apCaretColumn:
      begin
        // Caret-anchored: right of cursor with gap, or right of end-of-line if longer
        if (Context.EditView <> nil) and (Context.EditView.CursorPos.Col > 0) then
        begin
          LCaretX := (Context.EditView.CursorPos.Col - 1) * Context.CellSize.cx +
            Context.LineState.VisibleTextRect.Left;
          LAnnotationX := Max(LCaretX + (Context.CellSize.cx * 3), LAnnotationX);
        end;
      end;
      apRightAligned:
      begin
        // Right-aligned in editor window, or after end-of-line with gap if line overflows
        LTextWidth := LCanvas.TextWidth(LText);
        LRightAlignedX := Rect.Right - LTextWidth - (Context.CellSize.cx * 2);
        LAnnotationX := Max(LRightAlignedX, LAnnotationX);
      end;
    end;

    // Store annotation position for click hit-testing
    if GAnnotationXByRow <> nil then
      GAnnotationXByRow.AddOrSetValue(Rect.Top, LAnnotationX);
    if GLineByRow <> nil then
      GLineByRow.AddOrSetValue(Rect.Top, LLogicalLine);

    // Transparent background for annotation text
    LCanvas.Brush.Style := bsClear;

    // Render annotation text
    if BlameSettings.PopupTrigger = ptClick then
    begin
      // Click mode: underlined hash prefix (hotlink) + italic rest
      LHashLen := GetAnnotationClickableLength(LBlameData.Lines[LLineIndex], BlameSettings);
      if LHashLen > 0 then
      begin
        LHashText := Copy(LText, 1, LHashLen);
        LRestText := Copy(LText, LHashLen + 1);
        LCanvas.Font.Style := [fsUnderline, fsItalic];
        LCanvas.TextOut(LAnnotationX, Rect.Top, LHashText);
        LHashWidth := LCanvas.TextWidth(LHashText);
        if GHashWidthByRow <> nil then
          GHashWidthByRow.AddOrSetValue(Rect.Top, LHashWidth);
        LCanvas.Font.Style := [fsItalic];
        LCanvas.TextOut(LAnnotationX + LHashWidth, Rect.Top, LRestText);
      end
      else
      begin
        if GHashWidthByRow <> nil then
          GHashWidthByRow.AddOrSetValue(Rect.Top, 0);
        LCanvas.TextOut(LAnnotationX, Rect.Top, LText);
      end;
    end
    else
    begin
      // Hover mode: plain italic, no hotlink underline
      if GHashWidthByRow <> nil then
        GHashWidthByRow.AddOrSetValue(Rect.Top, 0);
      LCanvas.TextOut(LAnnotationX, Rect.Top, LText);
    end;
  finally
    // Restore canvas state
    LCanvas.Font.Style := LSavedFontStyle;
    LCanvas.Font.Color := LSavedFontColor;
    LCanvas.Brush.Style := LSavedBrushStyle;
  end;
end;

procedure TDXBlameRenderer.PaintGutter(const Rect: TRect;
  const Stage: TPaintGutterStage; const BeforeEvent: Boolean;
  var AllowDefaultPainting: Boolean;
  const Context: INTACodeEditorPaintContext);
begin
  // No gutter painting
end;

procedure TDXBlameRenderer.PaintText(const Rect: TRect;
  const ColNum: SmallInt; const Text: string;
  const SyntaxCode: TOTASyntaxCode; const Hilight, BeforeEvent: Boolean;
  var AllowDefaultPainting: Boolean;
  const Context: INTACodeEditorPaintContext);
begin
  // No text painting override
end;

procedure TDXBlameRenderer.EndPaint(const Editor: TWinControl);
begin
  // No action needed
end;

procedure TDXBlameRenderer.EditorScrolled(const Editor: TWinControl;
  const Direction: TCodeEditorScrollDirection);
begin
  // Hide popup on scroll to prevent stale positioning
  if (GPopup <> nil) and GPopup.Visible then
    GPopup.Hide;
end;

procedure TDXBlameRenderer.EditorResized(const Editor: TWinControl);
begin
  // No action needed
end;

procedure TDXBlameRenderer.EditorElided(const Editor: TWinControl;
  const LogicalLineNum: Integer);
begin
  // No action needed
end;

procedure TDXBlameRenderer.EditorUnElided(const Editor: TWinControl;
  const LogicalLineNum: Integer);
begin
  // No action needed
end;

procedure TDXBlameRenderer.DoAnnotationClick(const Editor: TWinControl;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer;
  var Handled: Boolean);
var
  LRowTop: Integer;
  LAnnotationX: Integer;
  LLogicalLine: Integer;
  LLineIndex: Integer;
  LFileName: string;
  LBlameData: TBlameData;
  LScreenPos: TPoint;
  LRepoRoot: string;
  LRelPath: string;
  LPair: TPair<Integer, Integer>;
  LFound: Boolean;
begin
  if Button <> mbLeft then
    Exit;
  if not BlameSettings.Enabled then
    Exit;
  // In hover mode, popup is triggered by mouse move, not click
  if BlameSettings.PopupTrigger = ptHover then
    Exit;
  if GAnnotationXByRow = nil then
    Exit;
  if GCellHeight <= 0 then
    Exit;

  // Find the row that contains the click Y coordinate
  LFound := False;
  LRowTop := 0;
  LAnnotationX := 0;
  LLogicalLine := 0;

  for LPair in GAnnotationXByRow do
  begin
    LRowTop := LPair.Key;
    if (Y >= LRowTop) and (Y < LRowTop + GCellHeight) then
    begin
      LAnnotationX := LPair.Value;
      if (GLineByRow <> nil) and GLineByRow.TryGetValue(LRowTop, LLogicalLine) then
        LFound := True;
      Break;
    end;
  end;

  if not LFound then
    Exit;

  // Check if click is on the underlined hash region only
  if X < LAnnotationX then
    Exit;
  if (GHashWidthByRow = nil) or not GHashWidthByRow.ContainsKey(LRowTop) then
    Exit;
  if GHashWidthByRow[LRowTop] = 0 then
    Exit; // uncommitted line, not clickable
  if X >= LAnnotationX + GHashWidthByRow[LRowTop] then
    Exit;

  // Get blame data for the clicked line
  LFileName := FCurrentFileName;
  if LFileName = '' then
    Exit;

  if not BlameEngine.Cache.TryGet(LFileName, LBlameData) then
    Exit;

  LLineIndex := LLogicalLine - 1;
  if (LLineIndex < 0) or (LLineIndex >= Length(LBlameData.Lines)) then
    Exit;

  // Compute screen position for popup placement
  LScreenPos := Editor.ClientToScreen(Point(X, Y));

  // Compute relative file path for git commands
  LRepoRoot := BlameEngine.RepoRoot;
  if LRepoRoot <> '' then
    LRelPath := ExtractRelativePath(
      IncludeTrailingPathDelimiter(LRepoRoot), LFileName)
  else
    LRelPath := ExtractFileName(LFileName);
  LRelPath := StringReplace(LRelPath, '\\', '/', [rfReplaceAll]);

  // Create or update popup
  if GPopup = nil then
    GPopup := TDXBlamePopup.Create(nil);

  if GPopup.Visible then
    GPopup.UpdateContent(LBlameData.Lines[LLineIndex], LRepoRoot, LRelPath)
  else
    GPopup.ShowForCommit(LBlameData.Lines[LLineIndex], LScreenPos, LRepoRoot, LRelPath);

  Handled := True;
end;

procedure TDXBlameRenderer.EditorMouseDown(const Editor: TWinControl;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LHandled: Boolean;
begin
  // On Delphi 12 (no INTACodeEditorEvents370), handle clicks directly.
  // LHandled is discarded; IDE will still process the click normally.
  // On Delphi 13+, TDXBlameRendererD13 overrides this to a no-op and
  // handles clicks via EditorMouseDown with var Handled instead.
  LHandled := False;
  DoAnnotationClick(Editor, Button, Shift, X, Y, LHandled);
end;

procedure TDXBlameRenderer.EditorMouseMove(const Editor: TWinControl;
  Shift: TShiftState; X, Y: Integer);
var
  LPair: TPair<Integer, Integer>;
  LRowTop: Integer;
  LAnnotationX: Integer;
  LLogicalLine: Integer;
  LLineIndex: Integer;
  LBlameData: TBlameData;
  LScreenPos: TPoint;
  LRepoRoot: string;
  LRelPath: string;
begin
  if BlameSettings.PopupTrigger <> ptHover then
    Exit;
  if not BlameSettings.Enabled then
    Exit;
  if GAnnotationXByRow = nil then
    Exit;
  if GCellHeight <= 0 then
    Exit;

  // Only trigger hover on the caret line where an annotation is actually shown
  if not BlameSettings.ShowInline then
    Exit;
  if FCurrentLine <= 0 then
    Exit;

  // Check if mouse is over the caret line's annotation area
  LLogicalLine := -1;
  LRowTop := 0;
  LAnnotationX := 0;
  for LPair in GAnnotationXByRow do
  begin
    LRowTop := LPair.Key;
    if (Y >= LRowTop) and (Y < LRowTop + GCellHeight) and (X >= LPair.Value) then
    begin
      LAnnotationX := LPair.Value;
      if (GLineByRow <> nil) then
        GLineByRow.TryGetValue(LRowTop, LLogicalLine);
      // Only accept if this is the caret line
      if LLogicalLine <> FCurrentLine then
        LLogicalLine := -1;
      Break;
    end;
  end;

  if LLogicalLine <= 0 then
  begin
    // Mouse not over annotation — start hide timer if popup is showing
    if (GHoverPopupLine > 0) and (GHoverCheckTimer <> nil) then
      GHoverCheckTimer.Enabled := True;
    Exit;
  end;

  // Mouse is over annotation — cancel any pending hide
  if GHoverCheckTimer <> nil then
    GHoverCheckTimer.Enabled := False;

  // Already showing popup for this line
  if (GPopup <> nil) and GPopup.Visible and (GHoverPopupLine = LLogicalLine) then
    Exit;

  // Get blame data for hover
  if FCurrentFileName = '' then
    Exit;
  if not BlameEngine.Cache.TryGet(FCurrentFileName, LBlameData) then
    Exit;

  LLineIndex := LLogicalLine - 1;
  if (LLineIndex < 0) or (LLineIndex >= Length(LBlameData.Lines)) then
    Exit;

  // Compute screen position for popup near the annotation
  LScreenPos := Editor.ClientToScreen(Point(LAnnotationX, LRowTop + GCellHeight));

  // Compute relative file path
  LRepoRoot := BlameEngine.RepoRoot;
  if LRepoRoot <> '' then
    LRelPath := ExtractRelativePath(
      IncludeTrailingPathDelimiter(LRepoRoot), FCurrentFileName)
  else
    LRelPath := ExtractFileName(FCurrentFileName);
  LRelPath := StringReplace(LRelPath, '\\', '/', [rfReplaceAll]);

  // Store annotation screen rect for hover check timer
  GHoverAnnotationScreenRect := Rect(
    Editor.ClientToScreen(Point(LAnnotationX, LRowTop)).X,
    Editor.ClientToScreen(Point(LAnnotationX, LRowTop)).Y,
    Editor.ClientToScreen(Point(Editor.Width, LRowTop + GCellHeight)).X,
    Editor.ClientToScreen(Point(Editor.Width, LRowTop + GCellHeight)).Y);

  // Create or show popup
  if GPopup = nil then
    GPopup := TDXBlamePopup.Create(nil);

  GHoverPopupLine := LLogicalLine;

  if GPopup.Visible then
    GPopup.UpdateContent(LBlameData.Lines[LLineIndex], LRepoRoot, LRelPath)
  else
    GPopup.ShowForHover(LBlameData.Lines[LLineIndex], LScreenPos, LRepoRoot, LRelPath);

  // Start hover check timer
  if GHoverCheckTimer <> nil then
    GHoverCheckTimer.Enabled := True;
end;

procedure TDXBlameRenderer.EditorMouseUp(const Editor: TWinControl;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  // No action needed
end;

{ THoverTimerHelper }

procedure THoverTimerHelper.OnHoverCheck(Sender: TObject);
var
  LCursorPos: TPoint;
begin
  GetCursorPos(LCursorPos);
  if (GPopup <> nil) and GPopup.Visible then
  begin
    // Keep popup if cursor is over annotation area or popup itself
    if PtInRect(GHoverAnnotationScreenRect, LCursorPos) or
       PtInRect(GPopup.BoundsRect, LCursorPos) then
      Exit;
    GPopup.Hide;
  end;
  GHoverPopupLine := -1;
  GHoverCheckTimer.Enabled := False;
end;

{ Module-level helpers }

procedure InvalidateAllEditors;
var
  LServices: INTACodeEditorServices;
begin
  if Supports(BorlandIDEServices, INTACodeEditorServices, LServices) then
    LServices.InvalidateTopEditor;
end;

procedure CleanupPopup;
begin
  FreeAndNil(GPopup);
end;

procedure RegisterRenderer(ANotifier: INTACodeEditorEvents);
var
  LServices: INTACodeEditorServices;
begin
  // Initialize hit-test dictionaries
  if GAnnotationXByRow = nil then
    GAnnotationXByRow := TDictionary<Integer, Integer>.Create;
  if GLineByRow = nil then
    GLineByRow := TDictionary<Integer, Integer>.Create;
  if GHashWidthByRow = nil then
    GHashWidthByRow := TDictionary<Integer, Integer>.Create;

  // Initialize hover timer
  if GHoverTimerHelper = nil then
    GHoverTimerHelper := THoverTimerHelper.Create;
  if GHoverCheckTimer = nil then
  begin
    GHoverCheckTimer := TTimer.Create(nil);
    GHoverCheckTimer.Interval := 250;
    GHoverCheckTimer.Enabled := False;
    GHoverCheckTimer.OnTimer := GHoverTimerHelper.OnHoverCheck;
  end;

  if Supports(BorlandIDEServices, INTACodeEditorServices, LServices) then
    GRendererIndex := LServices.AddEditorEventsNotifier(ANotifier);
end;

procedure UnregisterRenderer;
var
  LServices: INTACodeEditorServices;
begin
  if GRendererIndex >= 0 then
  begin
    if Supports(BorlandIDEServices, INTACodeEditorServices, LServices) then
      LServices.RemoveEditorEventsNotifier(GRendererIndex);
    GRendererIndex := -1;
  end;
end;

initialization

finalization
  CleanupPopup;
  FreeAndNil(GHoverCheckTimer);
  FreeAndNil(GHoverTimerHelper);
  FreeAndNil(GAnnotationXByRow);
  FreeAndNil(GLineByRow);
  FreeAndNil(GHashWidthByRow);

end.
