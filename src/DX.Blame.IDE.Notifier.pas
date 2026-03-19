/// <summary>
/// DX.Blame.IDE.Notifier
/// OTA notifiers for IDE file events that drive the blame pipeline.
/// </summary>
///
/// <remarks>
/// Implements IOTAIDENotifier to hook into file open, close, and project
/// switch events, delegating to TBlameEngine. Also implements
/// IOTAModuleNotifier on a per-file basis to detect save events (which
/// IOTAIDENotifier does not fire). Module notifiers are attached on file
/// open and detached on file close. All OTA notifications arrive on the
/// main thread, so no additional synchronization is needed for the
/// notifier dictionaries.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.IDE.Notifier;

interface

/// <summary>Registers IDE and module notifiers. Call from Register procedure.</summary>
procedure RegisterIDENotifiers;

/// <summary>Removes all active notifiers. Call from finalization.</summary>
procedure UnregisterIDENotifiers;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  ToolsAPI,
  DX.Blame.Engine;

type
  /// <summary>
  /// Per-module notifier that detects file save events.
  /// </summary>
  TDXBlameModuleNotifier = class(TNotifierObject, IOTANotifier, IOTAModuleNotifier)
  private
    FFileName: string;
    FNotifierIndex: Integer;
  public
    constructor Create(const AFileName: string);
    { IOTAModuleNotifier }
    function CheckOverwrite: Boolean;
    procedure ModuleRenamed(const NewName: string);
    { IOTANotifier }
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;

    property FileName: string read FFileName;
    property NotifierIndex: Integer read FNotifierIndex write FNotifierIndex;
  end;

  /// <summary>
  /// IDE notifier that hooks file open, close, and project switch events.
  /// </summary>
  TDXBlameIDENotifier = class(TNotifierObject, IOTANotifier, IOTAIDENotifier)
  public
    { IOTAIDENotifier }
    procedure FileNotification(NotifyCode: TOTAFileNotification;
      const FileName: string; var Cancel: Boolean);
    procedure BeforeCompile(const Project: IOTAProject; var Cancel: Boolean); overload;
    procedure AfterCompile(Succeeded: Boolean); overload;
  end;

var
  GIDENotifierIndex: Integer = -1;
  GModuleNotifiers: TDictionary<string, TDXBlameModuleNotifier>;

{ TDXBlameModuleNotifier }

constructor TDXBlameModuleNotifier.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
  FNotifierIndex := -1;
end;

function TDXBlameModuleNotifier.CheckOverwrite: Boolean;
begin
  Result := True;
end;

procedure TDXBlameModuleNotifier.ModuleRenamed(const NewName: string);
begin
  // No action needed -- blame is keyed by the original file path
end;

procedure TDXBlameModuleNotifier.AfterSave;
begin
  BlameEngine.RequestBlameDebounced(FFileName);
end;

procedure TDXBlameModuleNotifier.BeforeSave;
begin
  // No action needed
end;

procedure TDXBlameModuleNotifier.Destroyed;
begin
  // Module is being destroyed -- notifier will be removed by FileNotification/ofnFileClosing
end;

procedure TDXBlameModuleNotifier.Modified;
begin
  // No action needed -- we only care about saves, not edits
end;

{ TDXBlameIDENotifier }

procedure TDXBlameIDENotifier.FileNotification(NotifyCode: TOTAFileNotification;
  const FileName: string; var Cancel: Boolean);
var
  LKey: string;
  LModuleServices: IOTAModuleServices;
  LModule: IOTAModule;
  LNotifier: TDXBlameModuleNotifier;
  LIndex: Integer;
begin
  case NotifyCode of
    ofnFileOpened:
      begin
        BlameEngine.RequestBlame(FileName);

        // Attach module notifier for save detection
        LKey := LowerCase(FileName);
        if (GModuleNotifiers <> nil) and (not GModuleNotifiers.ContainsKey(LKey)) then
        begin
          if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
          begin
            LModule := LModuleServices.FindModule(FileName);
            if LModule <> nil then
            begin
              LNotifier := TDXBlameModuleNotifier.Create(FileName);
              LIndex := LModule.AddNotifier(LNotifier);
              LNotifier.NotifierIndex := LIndex;
              GModuleNotifiers.AddOrSetValue(LKey, LNotifier);
            end;
          end;
        end;
      end;

    ofnFileClosing:
      begin
        BlameEngine.CancelAndRemove(FileName);

        // Detach module notifier
        LKey := LowerCase(FileName);
        if (GModuleNotifiers <> nil) and GModuleNotifiers.TryGetValue(LKey, LNotifier) then
        begin
          if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
          begin
            LModule := LModuleServices.FindModule(FileName);
            if (LModule <> nil) and (LNotifier.NotifierIndex >= 0) then
              LModule.RemoveNotifier(LNotifier.NotifierIndex);
          end;
          GModuleNotifiers.Remove(LKey);
        end;
      end;

    ofnProjectDesktopLoad:
      begin
        BlameEngine.OnProjectSwitch(ExtractFileDir(FileName));
      end;
  end;
end;

procedure TDXBlameIDENotifier.BeforeCompile(const Project: IOTAProject; var Cancel: Boolean);
begin
  // Not used
end;

procedure TDXBlameIDENotifier.AfterCompile(Succeeded: Boolean);
begin
  // Not used
end;

{ Registration }

procedure RegisterIDENotifiers;
var
  LServices: IOTAServices;
begin
  GModuleNotifiers := TDictionary<string, TDXBlameModuleNotifier>.Create;

  if Supports(BorlandIDEServices, IOTAServices, LServices) then
    GIDENotifierIndex := LServices.AddNotifier(TDXBlameIDENotifier.Create);
end;

procedure UnregisterIDENotifiers;
var
  LServices: IOTAServices;
  LModuleServices: IOTAModuleServices;
  LPair: TPair<string, TDXBlameModuleNotifier>;
  LModule: IOTAModule;
begin
  // Remove all active module notifiers
  if GModuleNotifiers <> nil then
  begin
    if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
    begin
      for LPair in GModuleNotifiers do
      begin
        if LPair.Value.NotifierIndex >= 0 then
        begin
          LModule := LModuleServices.FindModule(LPair.Value.FileName);
          if LModule <> nil then
            LModule.RemoveNotifier(LPair.Value.NotifierIndex);
        end;
      end;
    end;
    FreeAndNil(GModuleNotifiers);
  end;

  // Remove IDE notifier
  if GIDENotifierIndex >= 0 then
  begin
    if Supports(BorlandIDEServices, IOTAServices, LServices) then
      LServices.RemoveNotifier(GIDENotifierIndex);
    GIDENotifierIndex := -1;
  end;
end;

end.
