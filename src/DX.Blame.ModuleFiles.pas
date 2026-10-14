/// <summary>
/// DX.Blame.ModuleFiles
/// Pure helpers for multi-file IDE modules (for example a C++ .cpp/.h pair).
/// </summary>
///
/// <remarks>
/// The IDE open notification names only the primary file. Callers pass the
/// notified name plus the module editor file names they already read from
/// ToolsAPI. This unit does not reference ToolsAPI, so DUnitX can cover the
/// file list and the one-shot request guard without hosting the IDE.
///
/// The OTA members used by the caller (IOTAModule.ModuleFileCount,
/// IOTAModule.ModuleFileEditors, IOTAEditor.FileName) are declared on
/// IOTAModule40 and IOTAEditor and exist in both Delphi 12 and Delphi 13.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.ModuleFiles;

interface

uses
  System.Generics.Collections;

/// <summary>
/// Builds the distinct file list to blame for one module.
/// Editor names are kept in order. Empty names are dropped. The notified
/// file is appended when it is not already present (case-insensitive).
/// </summary>
function CollectBlameFileNames(const ANotifiedFileName: string;
  const AEditorFileNames: TArray<string>): TArray<string>;

/// <summary>
/// Records file names that have already been submitted for blame.
/// Contains is case-insensitive. Mark is idempotent. An empty name is ignored
/// so a paint loop cannot lock the guard on a blank buffer.
/// </summary>
TBlameRequestGuard = class
private
  FNames: TDictionary<string, Boolean>;
public
  constructor Create;
  destructor Destroy; override;
  procedure Mark(const AFileName: string);
  function Contains(const AFileName: string): Boolean;
  procedure Remove(const AFileName: string);
  procedure Clear;
end;

implementation

uses
  System.SysUtils;

function CollectBlameFileNames(const ANotifiedFileName: string;
  const AEditorFileNames: TArray<string>): TArray<string>;
var
  LSeen: TDictionary<string, Boolean>;
  LList: TList<string>;
  LName: string;
  LKey: string;
begin
  LSeen := TDictionary<string, Boolean>.Create;
  LList := TList<string>.Create;
  try
    for LName in AEditorFileNames do
    begin
      if LName = '' then
        Continue;
      LKey := LowerCase(LName);
      if LSeen.ContainsKey(LKey) then
        Continue;
      LSeen.Add(LKey, True);
      LList.Add(LName);
    end;

    if ANotifiedFileName <> '' then
    begin
      LKey := LowerCase(ANotifiedFileName);
      if not LSeen.ContainsKey(LKey) then
        LList.Add(ANotifiedFileName);
    end;

    Result := LList.ToArray;
  finally
    LList.Free;
    LSeen.Free;
  end;
end;

{ TBlameRequestGuard }

constructor TBlameRequestGuard.Create;
begin
  inherited Create;
  FNames := TDictionary<string, Boolean>.Create;
end;

destructor TBlameRequestGuard.Destroy;
begin
  FNames.Free;
  inherited;
end;

procedure TBlameRequestGuard.Mark(const AFileName: string);
begin
  if AFileName = '' then
    Exit;
  FNames.AddOrSetValue(LowerCase(AFileName), True);
end;

function TBlameRequestGuard.Contains(const AFileName: string): Boolean;
begin
  Result := (AFileName <> '') and FNames.ContainsKey(LowerCase(AFileName));
end;

procedure TBlameRequestGuard.Remove(const AFileName: string);
begin
  if AFileName = '' then
    Exit;
  FNames.Remove(LowerCase(AFileName));
end;

procedure TBlameRequestGuard.Clear;
begin
  FNames.Clear;
end;

end.
