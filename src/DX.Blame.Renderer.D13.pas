/// <summary>
/// DX.Blame.Renderer.D13
/// Delphi 13 renderer descendant adding INTACodeEditorEvents370 support.
/// </summary>
///
/// <remarks>
/// TDXBlameRendererD13 extends TDXBlameRenderer with INTACodeEditorEvents370,
/// available from Delphi 13 (CompilerVersion 37) onwards. The 370 interface
/// adds var Handled overloads for mouse and keyboard events, allowing the
/// renderer to consume annotation clicks (preventing the IDE from moving the
/// caret into the annotation gutter area) and to track caret position via
/// EditorSetCaretPos for accurate statusbar updates.
///
/// This entire unit is compiled only when CompilerVersion >= 37.0.
/// On Delphi 12, Registration.pas instantiates TDXBlameRenderer directly.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Renderer.D13;

interface

{$IF CompilerVersion >= 37.0}

uses
  System.Classes,
  Vcl.Controls,
  ToolsAPI,
  ToolsAPI.Editor,
  DX.Blame.Renderer;

type
  /// <summary>
  /// Delphi 13+ renderer that extends TDXBlameRenderer with
  /// INTACodeEditorEvents370. Adds event-consuming click handling and
  /// caret-position tracking via EditorSetCaretPos.
  /// </summary>
  TDXBlameRendererD13 = class(TDXBlameRenderer, INTACodeEditorEvents370)
  protected
    { INTACodeEditorEvents — override base no-op; D13 uses 370 overload instead }
    procedure EditorMouseDown(const Editor: TWinControl;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer); overload;
    function AllowedEvents: TCodeEditorEvents; override;
    { INTACodeEditorEvents370 }
    procedure EditorMouseDown(const Editor: TWinControl;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer;
      var Handled: Boolean); overload;
    procedure EditorMouseUp(const Editor: TWinControl;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer;
      var Handled: Boolean);
    procedure EditorKeyDown(const Editor: TWinControl; Key: Word;
      Shift: TShiftState; var Handled: Boolean);
    procedure EditorKeyUp(const Editor: TWinControl; Key: Word;
      Shift: TShiftState; var Handled: Boolean);
    procedure EditorSetCaretPos(const Editor: TWinControl; X, Y: Integer);
  end;

{$IFEND}

implementation

{$IF CompilerVersion >= 37.0}

{ TDXBlameRendererD13 }

function TDXBlameRendererD13.AllowedEvents: TCodeEditorEvents;
begin
  // Include cevKeyboardEvents so EditorSetCaretPos fires on cursor movement.
  Result := [cevPaintLineEvents, cevKeyboardEvents, cevMouseEvents];
end;

procedure TDXBlameRendererD13.EditorMouseDown(const Editor: TWinControl;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  // No action — handled by the INTACodeEditorEvents370 overload with var Handled.
end;

procedure TDXBlameRendererD13.EditorMouseDown(const Editor: TWinControl;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer;
  var Handled: Boolean);
begin
  DoAnnotationClick(Editor, Button, Shift, X, Y, Handled);
end;

procedure TDXBlameRendererD13.EditorMouseUp(const Editor: TWinControl;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer;
  var Handled: Boolean);
begin
  // No action needed
end;

procedure TDXBlameRendererD13.EditorKeyDown(const Editor: TWinControl;
  Key: Word; Shift: TShiftState; var Handled: Boolean);
begin
  // No action needed
end;

procedure TDXBlameRendererD13.EditorKeyUp(const Editor: TWinControl;
  Key: Word; Shift: TShiftState; var Handled: Boolean);
begin
  // No action needed
end;

procedure TDXBlameRendererD13.EditorSetCaretPos(const Editor: TWinControl;
  X, Y: Integer);
begin
  // Y is view-relative (row on screen), NOT a logical line number.
  // We only use this event to trigger a repaint; the actual logical
  // caret line is read from EditView.CursorPos.Line in PaintLine.
  FCurrentEditor := Editor;
  InvalidateAllEditors;
  // Notify statusbar of caret movement using FCurrentLine from the last paint
  // cycle. FCurrentLine may lag one paint cycle, which is imperceptible.
  if Assigned(GOnCaretMoved) and (FCurrentFileName <> '') then
    GOnCaretMoved(FCurrentFileName, FCurrentLine);
end;

{$IFEND}

end.
