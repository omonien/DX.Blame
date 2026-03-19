/// <summary>
/// DX.Blame.KeyBinding
/// IOTAKeyboardBinding for Ctrl+Alt+B toggle.
/// </summary>
///
/// <remarks>
/// TDXBlameKeyBinding registers a partial keyboard binding for the
/// Ctrl+Alt+B shortcut that toggles blame annotation display on/off.
/// The binding toggles BlameSettings.Enabled, persists the change,
/// and invalidates the editor to trigger an immediate visual update.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.KeyBinding;

interface

uses
  System.Classes,
  System.SysUtils,
  ToolsAPI;

type
  /// <summary>
  /// Keyboard binding that toggles blame annotations via Ctrl+Alt+B.
  /// </summary>
  TDXBlameKeyBinding = class(TNotifierObject, IOTAKeyboardBinding)
  public
    /// <summary>Handles the toggle keypress.</summary>
    procedure ToggleBlame(const Context: IOTAKeyContext;
      KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    /// <summary>Returns btPartial for a partial key binding.</summary>
    function GetBindingType: TBindingType;
    /// <summary>Returns the display name for the IDE key binding list.</summary>
    function GetDisplayName: string;
    /// <summary>Returns the unique internal name.</summary>
    function GetName: string;
    /// <summary>Registers the Ctrl+Alt+B shortcut with the binding services.</summary>
    procedure BindKeyboard(const BindingServices: IOTAKeyBindingServices);
  end;

/// <summary>Registers the keyboard binding with the IDE.</summary>
procedure RegisterKeyBinding;

/// <summary>Unregisters the keyboard binding from the IDE.</summary>
procedure UnregisterKeyBinding;

implementation

uses
  Vcl.Menus,
  DX.Blame.Settings,
  DX.Blame.Renderer;

var
  GKeyBindingIndex: Integer = -1;

{ TDXBlameKeyBinding }

function TDXBlameKeyBinding.GetBindingType: TBindingType;
begin
  Result := btPartial;
end;

function TDXBlameKeyBinding.GetName: string;
begin
  Result := 'DX.Blame.ToggleBlame';
end;

function TDXBlameKeyBinding.GetDisplayName: string;
begin
  Result := 'DX Blame Toggle';
end;

procedure TDXBlameKeyBinding.BindKeyboard(
  const BindingServices: IOTAKeyBindingServices);
begin
  BindingServices.AddKeyBinding(
    [ShortCut(Ord('B'), [ssCtrl, ssAlt])], ToggleBlame, nil);
end;

procedure TDXBlameKeyBinding.ToggleBlame(const Context: IOTAKeyContext;
  KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  BlameSettings.Enabled := not BlameSettings.Enabled;
  BlameSettings.Save;
  InvalidateAllEditors;
  BindingResult := krHandled;
end;

{ Module-level helpers }

procedure RegisterKeyBinding;
begin
  GKeyBindingIndex := (BorlandIDEServices as IOTAKeyboardServices)
    .AddKeyboardBinding(TDXBlameKeyBinding.Create);
end;

procedure UnregisterKeyBinding;
begin
  if GKeyBindingIndex >= 0 then
  begin
    (BorlandIDEServices as IOTAKeyboardServices)
      .RemoveKeyboardBinding(GKeyBindingIndex);
    GKeyBindingIndex := -1;
  end;
end;

end.
