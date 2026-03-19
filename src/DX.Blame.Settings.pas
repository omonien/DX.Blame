/// <summary>
/// DX.Blame.Settings
/// Singleton settings persistence for DX.Blame configuration.
/// </summary>
///
/// <remarks>
/// TDXBlameSettings provides a singleton accessor via BlameSettings function,
/// persisting all configuration to %APPDATA%\DX.Blame\settings.ini using
/// TIniFile. Follows the same lazy-init + finalization pattern as BlameEngine.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Settings;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Graphics;

type
  /// <summary>Date format for blame annotations.</summary>
  TDXBlameDateFormat = (dfRelative, dfAbsolute);

  /// <summary>Display scope for blame annotations.</summary>
  TDXBlameDisplayScope = (dsCurrentLine, dsAllLines);

  /// <summary>
  /// Singleton settings for DX.Blame with INI file persistence.
  /// </summary>
  TDXBlameSettings = class
  private
    FEnabled: Boolean;
    FShowAuthor: Boolean;
    FDateFormat: TDXBlameDateFormat;
    FShowSummary: Boolean;
    FMaxLength: Integer;
    FUseCustomColor: Boolean;
    FCustomColor: TColor;
    FDisplayScope: TDXBlameDisplayScope;
    FToggleHotkey: string;
  public
    constructor Create;

    /// <summary>Loads settings from INI file. Missing keys use defaults.</summary>
    procedure Load;
    /// <summary>Saves current settings to INI file.</summary>
    procedure Save;
    /// <summary>Returns the full path to the settings INI file.</summary>
    class function GetSettingsPath: string;

    property Enabled: Boolean read FEnabled write FEnabled;
    property ShowAuthor: Boolean read FShowAuthor write FShowAuthor;
    property DateFormat: TDXBlameDateFormat read FDateFormat write FDateFormat;
    property ShowSummary: Boolean read FShowSummary write FShowSummary;
    property MaxLength: Integer read FMaxLength write FMaxLength;
    property UseCustomColor: Boolean read FUseCustomColor write FUseCustomColor;
    property CustomColor: TColor read FCustomColor write FCustomColor;
    property DisplayScope: TDXBlameDisplayScope read FDisplayScope write FDisplayScope;
    property ToggleHotkey: string read FToggleHotkey write FToggleHotkey;
  end;

/// <summary>Returns the singleton TDXBlameSettings instance (lazy-initialized).</summary>
function BlameSettings: TDXBlameSettings;

implementation

uses
  System.IniFiles,
  System.IOUtils;

var
  GBlameSettings: TDXBlameSettings;

function BlameSettings: TDXBlameSettings;
begin
  if GBlameSettings = nil then
    GBlameSettings := TDXBlameSettings.Create;
  Result := GBlameSettings;
end;

{ TDXBlameSettings }

constructor TDXBlameSettings.Create;
begin
  inherited Create;
  FEnabled := True;
  FShowAuthor := True;
  FDateFormat := dfRelative;
  FShowSummary := False;
  FMaxLength := 80;
  FUseCustomColor := False;
  FCustomColor := clGray;
  FDisplayScope := dsCurrentLine;
  FToggleHotkey := 'Ctrl+Alt+B';
  Load;
end;

class function TDXBlameSettings.GetSettingsPath: string;
begin
  Result := IncludeTrailingPathDelimiter(
    GetEnvironmentVariable('APPDATA')) + 'DX.Blame\settings.ini';
end;

procedure TDXBlameSettings.Load;
var
  LIni: TIniFile;
  LPath: string;
  LDateStr: string;
  LScopeStr: string;
begin
  LPath := GetSettingsPath;
  if not FileExists(LPath) then
    Exit;

  LIni := TIniFile.Create(LPath);
  try
    FEnabled := LIni.ReadBool('General', 'Enabled', True);

    LScopeStr := LIni.ReadString('General', 'DisplayScope', 'CurrentLine');
    if SameText(LScopeStr, 'AllLines') then
      FDisplayScope := dsAllLines
    else
      FDisplayScope := dsCurrentLine;

    FShowAuthor := LIni.ReadBool('Format', 'ShowAuthor', True);

    LDateStr := LIni.ReadString('Format', 'DateFormat', 'Relative');
    if SameText(LDateStr, 'Absolute') then
      FDateFormat := dfAbsolute
    else
      FDateFormat := dfRelative;

    FShowSummary := LIni.ReadBool('Format', 'ShowSummary', False);
    FMaxLength := LIni.ReadInteger('Format', 'MaxLength', 80);

    FUseCustomColor := LIni.ReadBool('Appearance', 'UseCustomColor', False);
    FCustomColor := TColor(LIni.ReadInteger('Appearance', 'CustomColor', Integer(clGray)));

    FToggleHotkey := LIni.ReadString('Hotkey', 'ToggleBlame', 'Ctrl+Alt+B');
  finally
    LIni.Free;
  end;
end;

procedure TDXBlameSettings.Save;
var
  LIni: TIniFile;
  LPath: string;
begin
  LPath := GetSettingsPath;
  ForceDirectories(ExtractFileDir(LPath));

  LIni := TIniFile.Create(LPath);
  try
    LIni.WriteBool('General', 'Enabled', FEnabled);

    case FDisplayScope of
      dsCurrentLine: LIni.WriteString('General', 'DisplayScope', 'CurrentLine');
      dsAllLines: LIni.WriteString('General', 'DisplayScope', 'AllLines');
    end;

    LIni.WriteBool('Format', 'ShowAuthor', FShowAuthor);

    case FDateFormat of
      dfRelative: LIni.WriteString('Format', 'DateFormat', 'Relative');
      dfAbsolute: LIni.WriteString('Format', 'DateFormat', 'Absolute');
    end;

    LIni.WriteBool('Format', 'ShowSummary', FShowSummary);
    LIni.WriteInteger('Format', 'MaxLength', FMaxLength);

    LIni.WriteBool('Appearance', 'UseCustomColor', FUseCustomColor);
    LIni.WriteInteger('Appearance', 'CustomColor', Integer(FCustomColor));

    LIni.WriteString('Hotkey', 'ToggleBlame', FToggleHotkey);
  finally
    LIni.Free;
  end;
end;

initialization

finalization
  FreeAndNil(GBlameSettings);

end.
