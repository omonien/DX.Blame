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

/// <summary>Creates the appropriate renderer for the current Delphi version.</summary>
function CreateBlameRenderer: INTACodeEditorEvents;

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
  System.Math,
  Winapi.Messages,
  Vcl.ExtCtrls,
  ToolsAPI,
  DX.Blame.Settings,
  DX.Blame.Formatter,
  DX.Blame.Engine,
  DX.Blame.VCS.Types,
  DX.Blame.Git.Types,
  DX.Blame.Cache,
  DX.Blame.Popup,
  DX.Blame.CommitDetail,
  DX.Blame.Logging;

var
  GPaintDebugCount: Integer = 0;

type
  /// <summary>Helper class for hover timer callback.</summary>
  THoverTimerHelper = class
    procedure OnHoverCheck(Sender: TObject);
  end;

/// <summary>Returns True if the IDE debugger is currently in a running/break state.</summary>
function IsDebuggerRunning: Boolean;
var
  LDebugServices: IOTADebuggerServices;
begin
  Result := False;
  if Supports(BorlandIDEServices, IOTADebuggerServices, LDebugServices) then
  begin
    if LDebugServices.CurrentDebugger <> nil then
      Result := LDebugServices.CurrentDebugger.State in [dsRunnable, dsStopped, dsPaused];
  end;
end;

var
  GRendererIndex: Integer = -1;
  GPopup: TDXBlamePopup = nil;

  // Last-painted annotation position (only the caret line is annotated).
  // Updated in PaintLine, reset in BeginPaint. Used for hit-testing in
  // DoAnnotationClick and EditorMouseMove between paint cycles.
  GAnnotationRowTop: Integer = -1;
  GAnnotationStartX: Integer = 0;
  GAnnotationHashWidth: Integer = 0;
  GAnnotationLine: Integer = 0;
  GCellHeight: Integer = 0;
  GLastPaintEditor: TWinControl = nil;

  // Hover popup state
  GHoverTimerHelper: THoverTimerHelper = nil;
  GHoverCheckTimer: TTimer = nil;
  GHoverPopupLine: Integer = -1;
  GHoverAnnotationScreenRect: TRect;

  // Scroll detection
  GPopupAnchorRowTop: Integer = -1;
  GCaretLinePaintedThisCycle: Boolean = False;
  // After scroll-dismiss, hover re-trigger is suppressed until the mouse
  // physically moves away from its current screen position.
  GScrollHideSuppressActive: Boolean = False;
  GScrollHidePosX: Integer = 0;
  GScrollHidePosY: Integer = 0;

  // WM_MOUSEWHEEL subclassing: original WndProc of the editor control.
  // Installed in BeginPaint when a new editor is seen; removed on unregister.
  GSubclassedEditor: TWinControl = nil;
  GOrigEditorWndProc: Pointer = nil;

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

/// <summary>Hides the popup and resets all popup/hover tracking state.</summary>
procedure HidePopup;
begin
  if (GPopup <> nil) and GPopup.Visible then
    GPopup.Hide;
  GHoverPopupLine := -1;
  GPopupAnchorRowTop := -1;
  if GHoverCheckTimer <> nil then
    GHoverCheckTimer.Enabled := False;
end;

/// <summary>
/// Hides popup due to scroll and activates position-based hover suppression.
/// Hover will not re-trigger until the mouse physically moves from its
/// current screen position, preventing flicker from EditorMouseMove events
/// that fire at the same position after scroll.
/// </summary>
procedure HidePopupForScroll;
var
  LPos: TPoint;
begin
  HidePopup;
  GetCursorPos(LPos);
  GScrollHideSuppressActive := True;
  GScrollHidePosX := LPos.X;
  GScrollHidePosY := LPos.Y;
end;

/// <summary>
/// Subclassed WndProc for the editor control. Intercepts WM_MOUSEWHEEL
/// to hide the popup on mouse-wheel scroll, since neither EditorScrolled
/// nor PaintLine fire during scroll-blit (the IDE shifts pixels instead
/// of repainting individual lines).
/// </summary>
function EditorWndProc(AHwnd: HWND; AMsg: UINT; AWParam: WPARAM;
  ALParam: LPARAM): LRESULT; stdcall;
begin
  if (AMsg = WM_MOUSEWHEEL) or (AMsg = WM_MOUSEHWHEEL) then
    HidePopupForScroll;
  Result := CallWindowProc(GOrigEditorWndProc, AHwnd, AMsg, AWParam, ALParam);
end;

procedure InstallEditorSubclass(AEditor: TWinControl);
begin
  if (AEditor = GSubclassedEditor) then
    Exit;
  // Remove old subclass if switching editors
  if (GSubclassedEditor <> nil) and (GOrigEditorWndProc <> nil) then
    SetWindowLongPtr(GSubclassedEditor.Handle, GWLP_WNDPROC, LONG_PTR(GOrigEditorWndProc));
  GOrigEditorWndProc := Pointer(GetWindowLongPtr(AEditor.Handle, GWLP_WNDPROC));
  SetWindowLongPtr(AEditor.Handle, GWLP_WNDPROC, LONG_PTR(@EditorWndProc));
  GSubclassedEditor := AEditor;
end;

procedure RemoveEditorSubclass;
begin
  if (GSubclassedEditor <> nil) and (GOrigEditorWndProc <> nil) then
  begin
    SetWindowLongPtr(GSubclassedEditor.Handle, GWLP_WNDPROC, LONG_PTR(GOrigEditorWndProc));
    GOrigEditorWndProc := nil;
    GSubclassedEditor := nil;
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
  GAnnotationRowTop := -1;
  GCaretLinePaintedThisCycle := False;

  // Hide popup if editor changed (switched tabs)
  if (GLastPaintEditor <> nil) and (GLastPaintEditor <> Editor) then
    HidePopup;
  GLastPaintEditor := Editor;

  // Subclass editor to intercept WM_MOUSEWHEEL for scroll detection
  InstallEditorSubclass(Editor);
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
  LEditorText: string;
  LBestIndex: Integer;
  LBestDist: Integer;
  LDist: Integer;
  i: Integer;
begin
  if GPaintDebugCount < 20 then
  begin
    Inc(GPaintDebugCount);
    LogDebug('Renderer', Format('PaintLine #%d stage=%d before=%s enabled=%s line=%d curLine=%d',
      [GPaintDebugCount, Ord(Stage), BoolToStr(BeforeEvent, True),
       BoolToStr(BlameSettings.Enabled, True),
       Context.LogicalLineNum, FCurrentLine]));
  end;

  if (Stage <> plsEndPaint) or BeforeEvent then
    Exit;

  if not BlameSettings.Enabled then
    Exit;

  // Skip inline rendering when inline display is disabled
  // (blame may still be globally enabled for statusbar display in Phase 13)
  if not BlameSettings.ShowInline then
    Exit;

  // Suppress annotations while debugger is running (F8 stepping etc.)
  // The annotation following the caret is distracting during debugging.
  if IsDebuggerRunning then
  begin
    HidePopup;
    Exit;
  end;

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
    if GPaintDebugCount < 20 then
    begin
      Inc(GPaintDebugCount);
      LogDebug('Renderer', 'Cache miss for ' + LFileName);
    end;
    Exit;
  end;

  // Match current editor line against blame data.
  // 1) Try exact index first (fast path for unmodified files)
  // 2) If text differs, search all blame lines for nearest positional match
  //    (handles inserted/deleted lines shifting positions)
  // 3) No match found -> "Not committed yet" (truly new or edited content)
  LEditorText := Context.LineState.Text.TrimRight;
  LLineIndex := LLogicalLine - 1;

  if (LLineIndex >= 0) and (LLineIndex < Length(LBlameData.Lines))
    and (LEditorText = LBlameData.Lines[LLineIndex].OriginalText.TrimRight) then
  begin
    // Fast path: exact index match
    LText := FormatBlameAnnotation(LBlameData.Lines[LLineIndex], BlameSettings);
    if LText = '' then
      Exit;
  end
  else
  begin
    // Search all blame lines for matching text, prefer closest position
    LBestIndex := -1;
    LBestDist := MaxInt;
    for i := 0 to Length(LBlameData.Lines) - 1 do
    begin
      if LEditorText = LBlameData.Lines[i].OriginalText.TrimRight then
      begin
        LDist := Abs(i - (LLogicalLine - 1));
        if LDist < LBestDist then
        begin
          LBestDist := LDist;
          LBestIndex := i;
        end;
      end;
    end;

    if LBestIndex >= 0 then
    begin
      LLineIndex := LBestIndex;
      LText := FormatBlameAnnotation(LBlameData.Lines[LLineIndex], BlameSettings);
      if LText = '' then
        Exit;
    end
    else
    begin
      // No matching text found -- line was edited or is entirely new
      LLineIndex := -1;
      LText := cNotCommittedAuthor;
    end;
  end;

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

    // Store annotation position for hit-testing and scroll detection
    GAnnotationRowTop := Rect.Top;
    GAnnotationStartX := LAnnotationX;
    GAnnotationLine := LLogicalLine;
    GCaretLinePaintedThisCycle := True;

    // Transparent background for annotation text
    LCanvas.Brush.Style := bsClear;

    // Render annotation text
    if (BlameSettings.PopupTrigger = ptClick) and (LLineIndex >= 0) then
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
        GAnnotationHashWidth := LHashWidth;
        LCanvas.Font.Style := [fsItalic];
        LCanvas.TextOut(LAnnotationX + LHashWidth, Rect.Top, LRestText);
      end
      else
      begin
        GAnnotationHashWidth := 0;
        LCanvas.TextOut(LAnnotationX, Rect.Top, LText);
      end;
    end
    else
    begin
      // Hover mode: plain italic, no hotlink underline
      GAnnotationHashWidth := 0;
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
  if (GPopup = nil) or (not GPopup.Visible) then
    Exit;
  if not GCaretLinePaintedThisCycle then
  begin
    // Annotation was not painted — caret off-screen or no data
    HidePopupForScroll;
    Exit;
  end;
  // Annotation was painted — check if it moved (scroll with caret still visible)
  if (GPopupAnchorRowTop >= 0) and (GAnnotationRowTop <> GPopupAnchorRowTop) then
    HidePopupForScroll;
end;

procedure TDXBlameRenderer.EditorScrolled(const Editor: TWinControl;
  const Direction: TCodeEditorScrollDirection);
begin
  HidePopupForScroll;
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
  LLineIndex: Integer;
  LFileName: string;
  LBlameData: TBlameData;
  LScreenPos: TPoint;
  LRepoRoot: string;
  LRelPath: string;
begin
  if Button <> mbLeft then
    Exit;
  if not BlameSettings.Enabled then
    Exit;
  LogDebug('Renderer', Format('DoAnnotationClick X=%d Y=%d trigger=%d',
    [X, Y, Ord(BlameSettings.PopupTrigger)]));
  if BlameSettings.PopupTrigger = ptHover then
    Exit;
  if GAnnotationRowTop < 0 then
    Exit;
  if GCellHeight <= 0 then
    Exit;

  // Hit-test: click must be on the underlined hash region
  if (Y < GAnnotationRowTop) or (Y >= GAnnotationRowTop + GCellHeight) then
    Exit;
  if X < GAnnotationStartX then
    Exit;
  if GAnnotationHashWidth = 0 then
    Exit;
  if X >= GAnnotationStartX + GAnnotationHashWidth then
    Exit;

  LFileName := FCurrentFileName;
  if LFileName = '' then
    Exit;
  if not BlameEngine.Cache.TryGet(LFileName, LBlameData) then
    Exit;

  LLineIndex := GAnnotationLine - 1;
  if (LLineIndex < 0) or (LLineIndex >= Length(LBlameData.Lines)) then
    Exit;

  LScreenPos := Editor.ClientToScreen(Point(X, Y));

  LRepoRoot := BlameEngine.RepoRoot;
  if LRepoRoot <> '' then
    LRelPath := ExtractRelativePath(
      IncludeTrailingPathDelimiter(LRepoRoot), LFileName)
  else
    LRelPath := ExtractFileName(LFileName);
  LRelPath := StringReplace(LRelPath, '\\', '/', [rfReplaceAll]);

  if GPopup = nil then
    GPopup := TDXBlamePopup.Create(nil);

  GPopupAnchorRowTop := GAnnotationRowTop;

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
  // In click-trigger mode: dismiss popup if click is outside the popup
  // and outside the annotation area (the popup is WS_EX_NOACTIVATE so
  // it never receives CM_DEACTIVATE from the IDE).
  if (BlameSettings.PopupTrigger = ptClick) and (GPopup <> nil) and GPopup.Visible then
  begin
    LHandled := False;
    DoAnnotationClick(Editor, Button, Shift, X, Y, LHandled);
    if not LHandled then
      HidePopup;
    Exit;
  end;

  // On Delphi 12 (no INTACodeEditorEvents370), handle clicks directly.
  LHandled := False;
  DoAnnotationClick(Editor, Button, Shift, X, Y, LHandled);
end;

procedure TDXBlameRenderer.EditorMouseMove(const Editor: TWinControl;
  Shift: TShiftState; X, Y: Integer);
var
  LLineIndex: Integer;
  LBlameData: TBlameData;
  LScreenPos: TPoint;
  LRepoRoot: string;
  LRelPath: string;
  LCursorScreenPos: TPoint;
  LMouseOverAnnotation: Boolean;
begin
  if BlameSettings.PopupTrigger <> ptHover then
    Exit;
  if not BlameSettings.Enabled then
    Exit;
  if not BlameSettings.ShowInline then
    Exit;
  if FCurrentLine <= 0 then
    Exit;

  // After scroll-dismiss, suppress hover until mouse physically moves
  if GScrollHideSuppressActive then
  begin
    GetCursorPos(LCursorScreenPos);
    if (Abs(LCursorScreenPos.X - GScrollHidePosX) <= 3) and
       (Abs(LCursorScreenPos.Y - GScrollHidePosY) <= 3) then
      Exit;
    GScrollHideSuppressActive := False;
  end;

  if GAnnotationRowTop < 0 then
    Exit;
  if GCellHeight <= 0 then
    Exit;

  // Single hit-test against the one annotation row
  LMouseOverAnnotation :=
    (GAnnotationLine = FCurrentLine) and
    (Y >= GAnnotationRowTop) and (Y < GAnnotationRowTop + GCellHeight) and
    (X >= GAnnotationStartX);

  if not LMouseOverAnnotation then
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
  if (GPopup <> nil) and GPopup.Visible and (GHoverPopupLine = GAnnotationLine) then
    Exit;

  if FCurrentFileName = '' then
    Exit;
  if not BlameEngine.Cache.TryGet(FCurrentFileName, LBlameData) then
    Exit;

  LLineIndex := GAnnotationLine - 1;
  if (LLineIndex < 0) or (LLineIndex >= Length(LBlameData.Lines)) then
    Exit;

  LScreenPos := Editor.ClientToScreen(
    Point(GAnnotationStartX, GAnnotationRowTop + GCellHeight));

  LRepoRoot := BlameEngine.RepoRoot;
  if LRepoRoot <> '' then
    LRelPath := ExtractRelativePath(
      IncludeTrailingPathDelimiter(LRepoRoot), FCurrentFileName)
  else
    LRelPath := ExtractFileName(FCurrentFileName);
  LRelPath := StringReplace(LRelPath, '\\', '/', [rfReplaceAll]);

  // Store annotation screen rect for hover check timer
  GHoverAnnotationScreenRect := System.Types.Rect(
    Editor.ClientToScreen(Point(GAnnotationStartX, GAnnotationRowTop)).X,
    Editor.ClientToScreen(Point(GAnnotationStartX, GAnnotationRowTop)).Y,
    Editor.ClientToScreen(Point(Editor.Width, GAnnotationRowTop + GCellHeight)).X,
    Editor.ClientToScreen(Point(Editor.Width, GAnnotationRowTop + GCellHeight)).Y);

  if GPopup = nil then
    GPopup := TDXBlamePopup.Create(nil);

  GHoverPopupLine := GAnnotationLine;
  GPopupAnchorRowTop := GAnnotationRowTop;

  if GPopup.Visible then
    GPopup.UpdateContent(LBlameData.Lines[LLineIndex], LRepoRoot, LRelPath)
  else
    GPopup.ShowForHover(LBlameData.Lines[LLineIndex], LScreenPos, LRepoRoot, LRelPath);

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
  GPopupAnchorRowTop := -1;
  if GHoverCheckTimer <> nil then
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

function CreateBlameRenderer: INTACodeEditorEvents;
begin
  Result := TDXBlameRenderer.Create;
end;

procedure RegisterRenderer(ANotifier: INTACodeEditorEvents);
var
  LServices: INTACodeEditorServices;
begin
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
  RemoveEditorSubclass;
  if GRendererIndex >= 0 then
  begin
    if Supports(BorlandIDEServices, INTACodeEditorServices, LServices) then
      LServices.RemoveEditorEventsNotifier(GRendererIndex);
    GRendererIndex := -1;
  end;
end;

initialization

finalization
  RemoveEditorSubclass;
  CleanupPopup;
  FreeAndNil(GHoverCheckTimer);
  FreeAndNil(GHoverTimerHelper);

end.
