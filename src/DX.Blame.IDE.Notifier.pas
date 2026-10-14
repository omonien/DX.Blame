/// <summary>
/// DX.Blame.IDE.Notifier
/// OTA notifiers for IDE file events that drive the blame pipeline.
/// </summary>
///
/// <remarks>
/// Implements IOTAIDENotifier to hook into file open, close, and project
/// switch events, delegating to TBlameEngine. Also implements
/// IOTAModuleNotifier on a per-module basis to detect save events (which
/// IOTAIDENotifier does not fire). One module notifier is attached on file
/// open and detached on file close.
///
/// ofnFileOpened names only the primary file. A C++ module in one editor tab
/// still has ModuleFileCount = 2 (.cpp and .h). The open handler requests
/// blame for every module file editor, the module notifier keeps that list
/// and re-blames each file on save, and close drops the same list.
///
/// ModuleFileCount, ModuleFileEditors, and IOTAEditor.FileName come from
/// IOTAModule40 / IOTAEditor. They exist in Delphi 12 and Delphi 13. This
/// unit does not call INTACodeEditorEvents370 or any other Delphi 13-only
/// ToolsAPI member.
///
/// All OTA notifications arrive on the main thread, so no additional
/// synchronization is needed for the notifier dictionary.
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
  System.Generics.Collections,
  ToolsAPI,
  DX.Blame.Engine,
  DX.Blame.Logging,
  DX.Blame.ModuleFiles;

type
  /// <summary>
  /// Per-module notifier that detects file save events.
  /// Keeps every source file that belongs to the module, not only the
  /// file name passed to ofnFileOpened.
  /// </summary>
  TDXBlameModuleNotifier = class(TNotifierObject, IOTANotifier, IOTAModuleNotifier)
  private
    FFileNames: TArray<string>;
    FNotifierIndex: Integer;
  public
    constructor Create(const AFileNames: TArray<string>);
    { IOTAModuleNotifier }
    function CheckOverwrite: Boolean;
    procedure ModuleRenamed(const NewName: string);
    { IOTANotifier }
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;

    function PrimaryFileName: string;
    property FileNames: TArray<string> read FFileNames;
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
  // Keyed by lowercase path. Every file in a module points at the same
  // notifier instance so close of either the .cpp or the .h finds it.
  GModuleNotifiers: TDictionary<string, TDXBlameModuleNotifier>;

function FindTrackedNotifier(const AFileNames: TArray<string>): TDXBlameModuleNotifier;
var
  LName: string;
begin
  Result := nil;
  if GModuleNotifiers = nil then
    Exit;
  for LName in AFileNames do
    if GModuleNotifiers.TryGetValue(LowerCase(LName), Result) then
      Exit;
end;

procedure RememberModuleNotifier(ANotifier: TDXBlameModuleNotifier);
var
  LName: string;
begin
  if (GModuleNotifiers = nil) or (ANotifier = nil) then
    Exit;
  for LName in ANotifier.FileNames do
    GModuleNotifiers.AddOrSetValue(LowerCase(LName), ANotifier);
end;

/// <summary>
/// Removes every dictionary key for this notifier, then asks the IDE to
/// release it. RemoveNotifier can free the object, so the file list is
/// copied first. Each copied path is then dropped from the blame cache.
/// </summary>
procedure DetachModuleNotifier(ANotifier: TDXBlameModuleNotifier;
  const ALookupFileName: string);
var
  LNames: TArray<string>;
  LIndex: Integer;
  LLookup: string;
  LModuleServices: IOTAModuleServices;
  LModule: IOTAModule;
  LKeys: TList<string>;
  LPair: TPair<string, TDXBlameModuleNotifier>;
  LKey: string;
  LName: string;
begin
  if ANotifier = nil then
    Exit;

  LNames := Copy(ANotifier.FileNames);
  LIndex := ANotifier.NotifierIndex;
  if ALookupFileName <> '' then
    LLookup := ALookupFileName
  else if Length(LNames) > 0 then
    LLookup := LNames[0]
  else
    LLookup := '';

  if GModuleNotifiers <> nil then
  begin
    LKeys := TList<string>.Create;
    try
      for LPair in GModuleNotifiers do
        if LPair.Value = ANotifier then
          LKeys.Add(LPair.Key);
      for LKey in LKeys do
        GModuleNotifiers.Remove(LKey);
    finally
      LKeys.Free;
    end;
  end;

  if (LIndex >= 0) and (LLookup <> '') and
    Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
  begin
    LModule := LModuleServices.FindModule(LLookup);
    if LModule <> nil then
      LModule.RemoveNotifier(LIndex);
  end;

  for LName in LNames do
    BlameEngine.CancelAndRemove(LName);
end;

{ TDXBlameModuleNotifier }

constructor TDXBlameModuleNotifier.Create(const AFileNames: TArray<string>);
begin
  inherited Create;
  FFileNames := Copy(AFileNames);
  FNotifierIndex := -1;
end;

function TDXBlameModuleNotifier.PrimaryFileName: string;
begin
  if Length(FFileNames) > 0 then
    Result := FFileNames[0]
  else
    Result := '';
end;

function TDXBlameModuleNotifier.CheckOverwrite: Boolean;
begin
  Result := True;
end;

procedure TDXBlameModuleNotifier.ModuleRenamed(const NewName: string);
begin
  // No action needed. Blame stays keyed by the paths captured at open.
end;

procedure TDXBlameModuleNotifier.AfterSave;
var
  LFileName: string;
begin
  for LFileName in FFileNames do
    BlameEngine.RequestBlameDebounced(LFileName);
end;

procedure TDXBlameModuleNotifier.BeforeSave;
begin
  // No action needed
end;

procedure TDXBlameModuleNotifier.Destroyed;
begin
  // Module is being destroyed. FileNotification(ofnFileClosing) removes the notifier.
end;

procedure TDXBlameModuleNotifier.Modified;
begin
  // No action needed. We only care about saves, not edits.
end;

{ TDXBlameIDENotifier }

procedure TDXBlameIDENotifier.FileNotification(NotifyCode: TOTAFileNotification;
  const FileName: string; var Cancel: Boolean);
var
  LKey: string;
  LModuleServices: IOTAModuleServices;
  LModule: IOTAModule;
  LEditor: IOTAEditor;
  LEditorNames: TList<string>;
  LFileNames: TArray<string>;
  LName: string;
  LNotifier: TDXBlameModuleNotifier;
  LIndex: Integer;
  i: Integer;
begin
  case NotifyCode of
    ofnFileOpened:
      begin
        LogDebug('IDE', 'File opened: ' + FileName);

        LModule := nil;
        LFileNames := nil;
        LEditorNames := TList<string>.Create;
        try
          if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
            LModule := LModuleServices.FindModule(FileName);

          // IOTAModule40.ModuleFileCount / ModuleFileEditors and
          // IOTAEditor.FileName. Present in Delphi 12 and Delphi 13.
          // ofnFileOpened passes only the primary file (.cpp). The header
          // in the same editor tab is another editor on this module.
          if LModule <> nil then
            for i := 0 to LModule.ModuleFileCount - 1 do
            begin
              LEditor := LModule.ModuleFileEditors[i];
              if (LEditor <> nil) and (LEditor.FileName <> '') then
                LEditorNames.Add(LEditor.FileName);
            end;

          LFileNames := CollectBlameFileNames(FileName, LEditorNames.ToArray);
        finally
          LEditorNames.Free;
        end;

        for LName in LFileNames do
        begin
          LogDebug('IDE', 'Request blame for module file: ' + LName);
          BlameEngine.RequestBlame(LName);
        end;

        if (GModuleNotifiers <> nil) and (LModule <> nil) and
          (Length(LFileNames) > 0) and (FindTrackedNotifier(LFileNames) = nil) then
        begin
          LNotifier := TDXBlameModuleNotifier.Create(LFileNames);
          LIndex := LModule.AddNotifier(LNotifier);
          LNotifier.NotifierIndex := LIndex;
          RememberModuleNotifier(LNotifier);
        end;
      end;

    ofnFileClosing:
      begin
        LogDebug('IDE', 'File closing: ' + FileName);

        LNotifier := nil;
        LKey := LowerCase(FileName);
        if GModuleNotifiers <> nil then
          GModuleNotifiers.TryGetValue(LKey, LNotifier);

        if LNotifier <> nil then
          DetachModuleNotifier(LNotifier, FileName)
        else
          BlameEngine.CancelAndRemove(FileName);
      end;

    ofnProjectDesktopLoad:
      begin
        LogInfo('IDE', 'Project switched: ' + FileName);
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
  LogInfo('IDE', 'IDE notifiers registered');
end;

procedure UnregisterIDENotifiers;
var
  LServices: IOTAServices;
  LModuleServices: IOTAModuleServices;
  LPair: TPair<string, TDXBlameModuleNotifier>;
  LModule: IOTAModule;
  LSnapshot: TList<TDXBlameModuleNotifier>;
  LIndexes: TList<Integer>;
  LPrimaries: TList<string>;
  j: Integer;
begin
  // Remove each module notifier once. Several dictionary keys share one instance.
  // Read the notifier fields into lists first. RemoveNotifier can free the object.
  if GModuleNotifiers <> nil then
  begin
    LSnapshot := TList<TDXBlameModuleNotifier>.Create;
    LIndexes := TList<Integer>.Create;
    LPrimaries := TList<string>.Create;
    try
      for LPair in GModuleNotifiers do
      begin
        if LSnapshot.IndexOf(LPair.Value) >= 0 then
          Continue;
        LSnapshot.Add(LPair.Value);
        LIndexes.Add(LPair.Value.NotifierIndex);
        LPrimaries.Add(LPair.Value.PrimaryFileName);
      end;

      if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
      begin
        for j := 0 to LSnapshot.Count - 1 do
        begin
          if (LIndexes[j] < 0) or (LPrimaries[j] = '') then
            Continue;
          LModule := LModuleServices.FindModule(LPrimaries[j]);
          if LModule <> nil then
            LModule.RemoveNotifier(LIndexes[j]);
        end;
      end;
    finally
      LPrimaries.Free;
      LIndexes.Free;
      LSnapshot.Free;
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
  LogInfo('IDE', 'IDE notifiers unregistered');
end;

end.
