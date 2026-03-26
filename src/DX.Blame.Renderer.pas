/// <summary>
/// DX.Blame.Renderer
/// INTACodeEditorEvents implementation for inline blame painting and click detection.
/// </summary>
///
/// <remarks>
/// TDXBlameRenderer hooks into the Delphi IDE code editor via
/// INTACodeEditorEvents and INTACodeEditorEvents370 to paint blame
/// annotations inline after the last character of each line. Annotations
/// are rendered in italic style using a theme-derived muted color.
/// Canvas state is saved and restored to prevent IDE painting corruption.
/// Click detection on annotation areas triggers the blame popup panel.
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
  /// </summary>
  TDXBlameRenderer = class(TNotifierObject, INTACodeEditorEvents,
    INTACodeEditorEvents370)
  private
    FCurrentLine: Integer;
    FCurrentEditor: TWinControl;
    FCurrentFileName: string;
  protected
    { INTACodeEditorEvents }
    procedure EditorScrolled(const Editor: TWinControl;
      const Direction: TCodeEditorScrollDirection);
    procedure EditorResized(const Editor: TWinControl);
    procedure EditorElided(const Editor: TWinControl;
      const LogicalLineNum: Integer);
    procedure EditorUnElided(const Editor: TWinControl;
      const LogicalLineNum: Integer);
    procedure EditorMouseDown(const Editor: TWinControl;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer); overload;
    procedure EditorMouseMove(const Editor: TWinControl;
      Shift: TShiftState; X, Y: Integer);
    procedure EditorMouseUp(const Editor: TWinControl;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer); overload;
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
    function AllowedEvents: TCodeEditorEvents;
    function AllowedGutterStages: TPaintGutterStages;
    function AllowedLineStages: TPaintLineStages;
    function UIOptions: TCodeEditorUIOptions;
    { INTACodeEditorEvents370 }
    procedure EditorMouseDown(const Editor: TWinControl;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer;
      var Handled: Boolean); overload;
    procedure EditorMouseUp(const Editor: TWinControl;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer;
      var Handled: Boolean); overload;
    procedure EditorKeyDown(const Editor: TWinControl; Key: Word;
      Shift: TShiftState; var Handled: Boolean);
    procedure EditorKeyUp(const Editor: TWinControl; Key: Word;
      Shift: TShiftState; var Handled: Boolean);
    procedure EditorSetCaretPos(const Editor: TWinControl; X, Y: Integer);
  end;

/// <summary>Registers the renderer notifier with the IDE editor services.</summary>
procedure RegisterRenderer;

/// <summary>Unregisters the renderer notifier from the IDE editor services.</summary>
procedure UnregisterRenderer;

/// <summary>Invalidates the top editor to trigger a repaint cycle.</summary>
procedure InvalidateAllEditors;

/// <summary>Cleans up the popup panel. Called during finalization.</summary>
procedure CleanupPopup;

implementation

uses
  System.Generics.Collections,
  System.Math,
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

{ TDXBlameRenderer }

function TDXBlameRenderer.AllowedEvents: TCodeEditorEvents;
begin
  // cevPaintLineEvents for PaintLine; cevKeyboardEvents ensures
  // EditorSetCaretPos fires on cursor movement; cevMouseEvents for annotation clicks
  Result := [cevPaintLineEvents, cevKeyboardEvents, cevMouseEvents];
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

procedure TDXBlameRenderer.EditorSetCaretPos(const Editor: TWinControl;
  X, Y: Integer);
begin
  // Y is view-relative (row on screen), NOT a logical line number.
  // We only use this event to trigger a repaint; the actual logical
  // caret line is read from EditView.CursorPos.Line in PaintLine.
  FCurrentEditor := Editor;
  InvalidateAllEditors;
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

  // Store cell height for hit-testing in EditorMouseDown
  GCellHeight := Context.CellSize.cy;

  LLogicalLine := Context.LogicalLineNum;

  // Always read the logical caret line from the EditView -- EditorSetCaretPos
  // Y is view-relative (screen row), not usable for line matching.
  if Context.EditView <> nil then
    FCurrentLine := Context.EditView.CursorPos.Line;

  // Display scope check: in current-line mode, only paint the caret line
  if (BlameSettings.DisplayScope = dsCurrentLine) and (LLogicalLine <> FCurrentLine) then
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

    // Compute X position: after visible text + 3 chars padding
    LAnnotationX := Context.LineState.VisibleTextRect.Right +
      (Context.CellSize.cx * 3);

    // Caret-anchored: only for caret line, only when setting is active
    if (BlameSettings.AnnotationPosition = apCaretColumn) and
       (LLogicalLine = FCurrentLine) and
       (Context.EditView <> nil) and
       (Context.EditView.CursorPos.Col > 0) then
    begin
      LCaretX := (Context.EditView.CursorPos.Col - 1) * Context.CellSize.cx +
        Context.LineState.VisibleTextRect.Left;
      LAnnotationX := Max(LCaretX + (Context.CellSize.cx * 3), LAnnotationX);
    end;

    // Store annotation position for click hit-testing
    if GAnnotationXByRow <> nil then
      GAnnotationXByRow.AddOrSetValue(Rect.Top, LAnnotationX);
    if GLineByRow <> nil then
      GLineByRow.AddOrSetValue(Rect.Top, LLogicalLine);

    // Transparent background for annotation text
    LCanvas.Brush.Style := bsClear;

    // Two-part rendering: underlined hash prefix + italic rest
    LHashLen := GetAnnotationClickableLength(LBlameData.Lines[LLineIndex], BlameSettings);
    if LHashLen > 0 then
    begin
      // Draw hash prefix with underline + italic (hotlink style)
      LHashText := Copy(LText, 1, LHashLen);
      LRestText := Copy(LText, LHashLen + 1);
      LCanvas.Font.Style := [fsUnderline, fsItalic];
      LCanvas.TextOut(LAnnotationX, Rect.Top, LHashText);
      LHashWidth := LCanvas.TextWidth(LHashText);
      // Store hash width for click hit-testing
      if GHashWidthByRow <> nil then
        GHashWidthByRow.AddOrSetValue(Rect.Top, LHashWidth);
      // Draw remaining text with italic only
      LCanvas.Font.Style := [fsItalic];
      LCanvas.TextOut(LAnnotationX + LHashWidth, Rect.Top, LRestText);
    end
    else
    begin
      // Uncommitted lines: plain italic, no underline, not clickable
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

procedure TDXBlameRenderer.EditorMouseDown(const Editor: TWinControl;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  // No action needed (non-370 overload)
end;

procedure TDXBlameRenderer.EditorMouseMove(const Editor: TWinControl;
  Shift: TShiftState; X, Y: Integer);
begin
  // No action needed
end;

procedure TDXBlameRenderer.EditorMouseUp(const Editor: TWinControl;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  // No action needed
end;

procedure TDXBlameRenderer.EditorMouseDown(const Editor: TWinControl;
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
  LRelPath := StringReplace(LRelPath, '\', '/', [rfReplaceAll]);

  // Create or update popup
  if GPopup = nil then
    GPopup := TDXBlamePopup.Create(nil);

  if GPopup.Visible then
    GPopup.UpdateContent(LBlameData.Lines[LLineIndex], LRepoRoot, LRelPath)
  else
    GPopup.ShowForCommit(LBlameData.Lines[LLineIndex], LScreenPos, LRepoRoot, LRelPath);

  Handled := True;
end;

procedure TDXBlameRenderer.EditorMouseUp(const Editor: TWinControl;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer;
  var Handled: Boolean);
begin
  // No action needed
end;

procedure TDXBlameRenderer.EditorKeyDown(const Editor: TWinControl;
  Key: Word; Shift: TShiftState; var Handled: Boolean);
begin
  // No action needed
end;

procedure TDXBlameRenderer.EditorKeyUp(const Editor: TWinControl;
  Key: Word; Shift: TShiftState; var Handled: Boolean);
begin
  // No action needed
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

procedure RegisterRenderer;
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

  if Supports(BorlandIDEServices, INTACodeEditorServices, LServices) then
    GRendererIndex := LServices.AddEditorEventsNotifier(TDXBlameRenderer.Create);
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
  FreeAndNil(GAnnotationXByRow);
  FreeAndNil(GLineByRow);
  FreeAndNil(GHashWidthByRow);

end.
