/// <summary>
/// DX.Blame.Registration
/// Central OTA lifecycle unit for the DX.Blame design-time plugin.
/// </summary>
///
/// <remarks>
/// Handles all IDE integration: wizard registration, splash screen bitmap,
/// Help > About entry, and Tools menu placeholder. All OTA registrations
/// are cleaned up in reverse order during finalization to prevent access
/// violations on BPL unload.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Registration;

interface

procedure Register;

implementation

uses
  ToolsAPI,
  System.SysUtils,
  System.Classes,
  Vcl.Menus,
  Winapi.Windows,
  DX.Blame.Version;

var
  GWizardIndex: Integer = -1;
  GAboutPluginIndex: Integer = -1;
  GMenuParentItem: TMenuItem = nil;

type
  /// <summary>
  /// Minimal IOTAWizard implementation for IDE registration.
  /// Phase 1 placeholder -- Execute is a no-op.
  /// </summary>
  TDXBlameWizard = class(TNotifierObject, IOTAWizard)
  public
    { IOTAWizard }
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
  end;

{ TDXBlameWizard }

function TDXBlameWizard.GetIDString: string;
begin
  Result := 'DX.Blame';
end;

function TDXBlameWizard.GetName: string;
begin
  Result := cDXBlameName;
end;

function TDXBlameWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TDXBlameWizard.Execute;
begin
  // No-op for Phase 1 -- wizard exists for IDE registration only
end;

/// <summary>
/// Creates the "DX Blame" submenu under the IDE Tools menu with
/// two disabled placeholder items: "Enable Blame" and "Settings...".
/// </summary>
procedure CreateToolsMenu;
var
  LNTAServices: INTAServices;
  LSubItem: TMenuItem;
begin
  if not Supports(BorlandIDEServices, INTAServices, LNTAServices) then
    Exit;

  GMenuParentItem := TMenuItem.Create(nil);
  GMenuParentItem.Caption := 'DX Blame';
  GMenuParentItem.Name := 'DXBlameMenu';

  LSubItem := TMenuItem.Create(GMenuParentItem);
  LSubItem.Caption := 'Enable Blame';
  LSubItem.Name := 'DXBlameEnableItem';
  LSubItem.Enabled := False;
  GMenuParentItem.Add(LSubItem);

  LSubItem := TMenuItem.Create(GMenuParentItem);
  LSubItem.Caption := 'Settings...';
  LSubItem.Name := 'DXBlameSettingsItem';
  LSubItem.Enabled := False;
  GMenuParentItem.Add(LSubItem);

  LNTAServices.AddActionMenu('ToolsMenu', nil, GMenuParentItem);
end;

/// <summary>
/// Removes the "DX Blame" menu and all children from the IDE.
/// Children are freed automatically by the parent TMenuItem owner.
/// </summary>
procedure RemoveToolsMenu;
begin
  FreeAndNil(GMenuParentItem);
end;

/// <summary>
/// Called by the IDE when the design-time package is loaded.
/// Registers the wizard, about box entry, and Tools menu items.
/// </summary>
procedure Register;
var
  LWizardServices: IOTAWizardServices;
  LAboutBoxServices: IOTAAboutBoxServices;
  LAboutBmp: HBITMAP;
begin
  // Register wizard
  if Supports(BorlandIDEServices, IOTAWizardServices, LWizardServices) then
    GWizardIndex := LWizardServices.AddWizard(TDXBlameWizard.Create);

  // Register about box entry (bitmap ownership transfers to IDE -- do NOT free)
  if Supports(BorlandIDEServices, IOTAAboutBoxServices, LAboutBoxServices) then
  begin
    LAboutBmp := LoadBitmap(FindResourceHInstance(HInstance), 'DXBLAMESPLASH');
    GAboutPluginIndex := LAboutBoxServices.AddPluginInfo(
      cDXBlameName,
      cDXBlameDescription + sLineBreak + cDXBlameCopyright,
      LAboutBmp,
      False,
      '',
      cDXBlameVersion
    );
  end;

  // Create Tools menu placeholder
  CreateToolsMenu;
end;

initialization
  // Splash screen registration -- must happen during initialization,
  // before Register is called, while IDE splash screen is still visible.
  // Use AddPluginBitmap, NOT AddProductBitmap (broken per QC 42320).
  if Assigned(SplashScreenServices) then
  begin
    SplashScreenServices.AddPluginBitmap(
      cDXBlameName,
      LoadBitmap(FindResourceHInstance(HInstance), 'DXBLAMESPLASH'),
      False,
      'Open Source'
    );
  end;

finalization
  // Reverse-order cleanup to prevent access violations on BPL unload:
  // 1. Remove UI elements (menu items) first
  RemoveToolsMenu;

  // 2. Remove wizard registration
  if GWizardIndex > 0 then
    if Assigned(BorlandIDEServices) then
      (BorlandIDEServices as IOTAWizardServices).RemoveWizard(GWizardIndex);

  // 3. Remove about box entry last
  if GAboutPluginIndex > 0 then
    if Assigned(BorlandIDEServices) then
      (BorlandIDEServices as IOTAAboutBoxServices).RemovePluginInfo(GAboutPluginIndex);

end.
