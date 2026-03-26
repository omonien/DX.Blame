/// <summary>
/// DX.Blame.Registration
/// Central OTA lifecycle unit for the DX.Blame design-time plugin.
/// </summary>
///
/// <remarks>
/// Handles all IDE integration: wizard registration, splash screen bitmap,
/// Help > About entry, and IDE Options page (Tools > Options > Third Party > DX Blame).
/// All OTA registrations are cleaned up in reverse order during finalization to prevent
/// access violations on BPL unload.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Registration;

interface

procedure Register;

/// <summary>
/// No-op stub kept for callback contract compatibility.
/// OnBlameToggled (KeyBinding.pas) and GOnContextMenuToggle (Navigation.pas) reference
/// this procedure; the Tools menu it previously synced was removed in v1.2 Phase 14.
/// </summary>
procedure SyncEnableBlameCheckmark;

implementation

uses
  ToolsAPI,
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  DX.Blame.Version,
  DX.Blame.IDE.Notifier,
  DX.Blame.Engine,
  DX.Blame.Renderer,
  DX.Blame.Statusbar,
  DX.Blame.KeyBinding,
  DX.Blame.Settings,
  DX.Blame.Settings.Options,
  DX.Blame.Navigation;

var
  GWizardIndex: Integer = -1;
  GAboutPluginIndex: Integer = -1;
  GStatusbar: TDXBlameStatusbar = nil;
  GAddInOptions: INTAAddInOptions = nil;

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

procedure SyncEnableBlameCheckmark;
begin
  // Tools menu removed in v1.2 Phase 14 -- no-op, kept for callback contract
  // (OnBlameToggled in KeyBinding.pas, GOnContextMenuToggle in Navigation.pas)
end;

/// <summary>
/// Requests blame for all modules that were already open before the package loaded.
/// IOTAIDENotifier.FileNotification(ofnFileOpened) does not fire for pre-existing
/// modules, so we must iterate them manually after initialization.
/// </summary>
procedure BlameAlreadyOpenFiles;
var
  LModuleServices: IOTAModuleServices;
  i: Integer;
  LModule: IOTAModule;
  LFileName: string;
begin
  if not Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
    Exit;

  for i := 0 to LModuleServices.ModuleCount - 1 do
  begin
    LModule := LModuleServices.Modules[i];
    if LModule = nil then
      Continue;
    LFileName := LModule.FileName;
    if LFileName <> '' then
      BlameEngine.RequestBlame(LFileName);
  end;
end;

/// <summary>
/// Standalone wrapper so the plain GOnCaretMoved procedure variable can
/// dispatch to the TDXBlameStatusbar method without needing an 'of object' type.
/// </summary>
procedure OnCaretMovedHandler(const AFileName: string; ALine: Integer);
begin
  if GStatusbar <> nil then
    GStatusbar.UpdateForLine(AFileName, ALine);
end;

procedure Register;
var
  LWizardServices: IOTAWizardServices;
  LAboutBoxServices: IOTAAboutBoxServices;
  LAboutBmp: HBITMAP;
  LModuleServices: IOTAModuleServices;
  LProject: IOTAProject;
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

  // Register IDE Options page (Tools > Options > Third Party > DX Blame)
  var LEnvOptSvc: INTAEnvironmentOptionsServices;
  GAddInOptions := TDXBlameAddInOptions.Create;
  if Supports(BorlandIDEServices, INTAEnvironmentOptionsServices, LEnvOptSvc) then
    LEnvOptSvc.RegisterAddInOptions(GAddInOptions);

  // Register IDE notifiers for file open/close/save events
  RegisterIDENotifiers;

  // Initialize blame engine with current project path
  if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
  begin
    LProject := LModuleServices.GetActiveProject;
    if LProject <> nil then
      BlameEngine.Initialize(ExtractFileDir(LProject.FileName));
  end;

  // Register renderer and keyboard binding for inline blame display
  RegisterRenderer;
  RegisterKeyBinding;

  // Wire callback so KeyBinding can sync menu checkmark without circular dependency
  DX.Blame.KeyBinding.OnBlameToggled := SyncEnableBlameCheckmark;

  // Wire callback so Navigation context menu toggle syncs Tools menu checkmark
  DX.Blame.Navigation.GOnContextMenuToggle := SyncEnableBlameCheckmark;

  // Attach "Previous Revision" item to the editor context menu
  AttachContextMenu;

  // Create and attach statusbar blame panel to the top edit window
  GStatusbar := TDXBlameStatusbar.Create(nil);
  var LNTAEditorServices: INTAEditorServices;
  if Supports(BorlandIDEServices, INTAEditorServices, LNTAEditorServices) then
  begin
    var LEditWindow := LNTAEditorServices.TopEditWindow;
    if (LEditWindow <> nil) and (LEditWindow.StatusBar <> nil) then
      GStatusbar.AttachToStatusBar(LEditWindow.StatusBar);
  end;

  // Wire caret-moved callback so statusbar updates on cursor movement
  DX.Blame.Renderer.GOnCaretMoved := OnCaretMovedHandler;

  // Request blame for files already open before the package loaded
  BlameAlreadyOpenFiles;
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
      cDXBlameDescription
    );
  end;

finalization
  // Reverse-order cleanup to prevent access violations on BPL unload:
  // 1. Detach context menu (must happen before any other cleanup)
  DetachContextMenu;

  // 2. Stop keyboard binding (must stop before renderer to avoid toggle during unload)
  UnregisterKeyBinding;

  // 3. Clean up popup panel before stopping renderer
  CleanupPopup;

  // 3.5. Clean up statusbar panel before stopping renderer
  DX.Blame.Renderer.GOnCaretMoved := nil;
  if GStatusbar <> nil then
  begin
    GStatusbar.DetachFromStatusBar;
    FreeAndNil(GStatusbar);
  end;

  // 4. Stop renderer (must stop painting before notifiers are removed)
  UnregisterRenderer;

  // 5. Remove IDE notifiers (notifiers must stop before UI cleanup)
  UnregisterIDENotifiers;

  // 6. (Tools menu removed in v1.2 — no cleanup needed)

  // 6.5. Unregister IDE Options page (must come before RemoveWizard — Pitfall 2 prevention)
  if GAddInOptions <> nil then
  begin
    var LEnvOptSvc: INTAEnvironmentOptionsServices;
    if Supports(BorlandIDEServices, INTAEnvironmentOptionsServices, LEnvOptSvc) then
      LEnvOptSvc.UnregisterAddInOptions(GAddInOptions);
    GAddInOptions := nil;
  end;

  // 7. Remove wizard registration
  if GWizardIndex >= 0 then
    if Assigned(BorlandIDEServices) then
      (BorlandIDEServices as IOTAWizardServices).RemoveWizard(GWizardIndex);

  // 8. Remove about box entry last
  if GAboutPluginIndex >= 0 then
    if Assigned(BorlandIDEServices) then
      (BorlandIDEServices as IOTAAboutBoxServices).RemovePluginInfo(GAboutPluginIndex);

  // BlameEngine singleton is freed in DX.Blame.Engine finalization

end.
