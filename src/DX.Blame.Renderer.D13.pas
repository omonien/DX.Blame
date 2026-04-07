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
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  ToolsAPI,
  ToolsAPI.Editor,
  DX.Blame.Renderer,
  DX.Blame.Logging;

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

/// <summary>Creates the D13 renderer with INTACodeEditorEvents370 support.</summary>
function CreateBlameRenderer: INTACodeEditorEvents;

{$IFEND}

implementation

{$IF CompilerVersion >= 37.0}

function CreateBlameRenderer: INTACodeEditorEvents;
begin
  Result := TDXBlameRendererD13.Create;
end;

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
var
  LEditorServices: IOTAEditorServices;
  LTopView: IOTAEditView;
  LLine: Integer;
begin
  InvalidateAllEditors;

  // Read the current logical line directly from the active top view to avoid
  // one repaint-cycle lag after Enter/newline moves.
  if not Supports(BorlandIDEServices, IOTAEditorServices, LEditorServices) then
    Exit;
  LTopView := LEditorServices.TopView;
  if (LTopView = nil) or (LTopView.Buffer = nil) then
    Exit;

  FCurrentFileName := LTopView.Buffer.FileName;
  LLine := LTopView.CursorPos.Line;
  FCurrentLine := LLine;

  LogDebug('RendererD13', 'Caret moved to line ' + IntToStr(LLine));
  if Assigned(GOnCaretMoved) and (FCurrentFileName <> '') then
    GOnCaretMoved(FCurrentFileName, LLine);
end;

{$IFEND}

end.
