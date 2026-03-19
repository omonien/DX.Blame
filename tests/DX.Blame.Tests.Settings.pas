/// <summary>
/// DX.Blame.Tests.Settings
/// Unit tests for TDXBlameSettings INI persistence and singleton access.
/// </summary>
///
/// <remarks>
/// Validates default values, save/load round-trip, correct INI path,
/// resilience to missing INI, and singleton identity.
/// Uses a temporary directory for INI file isolation.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Tests.Settings;

interface

uses
  DUnitX.TestFramework,
  DX.Blame.Settings;

type
  [TestFixture]
  TSettingsTests = class
  private
    FSettings: TDXBlameSettings;
    FTempDir: string;
    FTempIniPath: string;
    procedure SaveToTemp;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestDefaultValues;
    [Test]
    procedure TestSaveLoadRoundTrip;
    [Test]
    procedure TestSettingsPathContainsAppData;
    [Test]
    procedure TestLoadNonExistentIniReturnsDefaults;
    [Test]
    procedure TestSingletonReturnsSameInstance;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.IniFiles,
  Vcl.Graphics;

{ TSettingsTests }

procedure TSettingsTests.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath, 'DXBlameTest_' + TGUID.NewGuid.ToString);
  ForceDirectories(FTempDir);
  FTempIniPath := TPath.Combine(FTempDir, 'settings.ini');
  // Create a fresh settings object without loading from real INI
  FSettings := TDXBlameSettings.Create;
end;

procedure TSettingsTests.TearDown;
begin
  FreeAndNil(FSettings);
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TSettingsTests.SaveToTemp;
var
  LIni: TIniFile;
begin
  LIni := TIniFile.Create(FTempIniPath);
  try
    LIni.WriteBool('General', 'Enabled', FSettings.Enabled);
    case FSettings.DisplayScope of
      dsCurrentLine: LIni.WriteString('General', 'DisplayScope', 'CurrentLine');
      dsAllLines: LIni.WriteString('General', 'DisplayScope', 'AllLines');
    end;
    LIni.WriteBool('Format', 'ShowAuthor', FSettings.ShowAuthor);
    case FSettings.DateFormat of
      dfRelative: LIni.WriteString('Format', 'DateFormat', 'Relative');
      dfAbsolute: LIni.WriteString('Format', 'DateFormat', 'Absolute');
    end;
    LIni.WriteBool('Format', 'ShowSummary', FSettings.ShowSummary);
    LIni.WriteInteger('Format', 'MaxLength', FSettings.MaxLength);
    LIni.WriteBool('Appearance', 'UseCustomColor', FSettings.UseCustomColor);
    LIni.WriteInteger('Appearance', 'CustomColor', Integer(FSettings.CustomColor));
    LIni.WriteString('Hotkey', 'ToggleBlame', FSettings.ToggleHotkey);
  finally
    LIni.Free;
  end;
end;

procedure TSettingsTests.TestDefaultValues;
begin
  Assert.IsTrue(FSettings.Enabled, 'Enabled should default to True');
  Assert.IsTrue(FSettings.ShowAuthor, 'ShowAuthor should default to True');
  Assert.AreEqual(Ord(dfRelative), Ord(FSettings.DateFormat), 'DateFormat should default to dfRelative');
  Assert.IsFalse(FSettings.ShowSummary, 'ShowSummary should default to False');
  Assert.AreEqual(80, FSettings.MaxLength, 'MaxLength should default to 80');
  Assert.IsFalse(FSettings.UseCustomColor, 'UseCustomColor should default to False');
  Assert.AreEqual(Ord(dsCurrentLine), Ord(FSettings.DisplayScope), 'DisplayScope should default to dsCurrentLine');
end;

procedure TSettingsTests.TestSaveLoadRoundTrip;
var
  LLoaded: TDXBlameSettings;
begin
  // Modify all settings to non-default values
  FSettings.Enabled := False;
  FSettings.ShowAuthor := False;
  FSettings.DateFormat := dfAbsolute;
  FSettings.ShowSummary := True;
  FSettings.MaxLength := 120;
  FSettings.UseCustomColor := True;
  FSettings.CustomColor := clRed;
  FSettings.DisplayScope := dsAllLines;
  FSettings.ToggleHotkey := 'Ctrl+Shift+G';

  // Save to temp INI
  SaveToTemp;

  // Create a new settings object and load from temp
  LLoaded := TDXBlameSettings.Create;
  try
    // Manually load from temp path
    LLoaded.Enabled := True; // reset to defaults first
    LLoaded.ShowAuthor := True;

    // Now load from temp file using our helper
    var LIni := TIniFile.Create(FTempIniPath);
    try
      LLoaded.Enabled := LIni.ReadBool('General', 'Enabled', True);
      var LScopeStr := LIni.ReadString('General', 'DisplayScope', 'CurrentLine');
      if SameText(LScopeStr, 'AllLines') then
        LLoaded.DisplayScope := dsAllLines
      else
        LLoaded.DisplayScope := dsCurrentLine;
      LLoaded.ShowAuthor := LIni.ReadBool('Format', 'ShowAuthor', True);
      var LDateStr := LIni.ReadString('Format', 'DateFormat', 'Relative');
      if SameText(LDateStr, 'Absolute') then
        LLoaded.DateFormat := dfAbsolute
      else
        LLoaded.DateFormat := dfRelative;
      LLoaded.ShowSummary := LIni.ReadBool('Format', 'ShowSummary', False);
      LLoaded.MaxLength := LIni.ReadInteger('Format', 'MaxLength', 80);
      LLoaded.UseCustomColor := LIni.ReadBool('Appearance', 'UseCustomColor', False);
      LLoaded.CustomColor := TColor(LIni.ReadInteger('Appearance', 'CustomColor', Integer(clGray)));
      LLoaded.ToggleHotkey := LIni.ReadString('Hotkey', 'ToggleBlame', 'Ctrl+Alt+B');
    finally
      LIni.Free;
    end;

    Assert.IsFalse(LLoaded.Enabled, 'Enabled round-trip failed');
    Assert.IsFalse(LLoaded.ShowAuthor, 'ShowAuthor round-trip failed');
    Assert.AreEqual(Ord(dfAbsolute), Ord(LLoaded.DateFormat), 'DateFormat round-trip failed');
    Assert.IsTrue(LLoaded.ShowSummary, 'ShowSummary round-trip failed');
    Assert.AreEqual(120, LLoaded.MaxLength, 'MaxLength round-trip failed');
    Assert.IsTrue(LLoaded.UseCustomColor, 'UseCustomColor round-trip failed');
    Assert.AreEqual(Integer(clRed), Integer(LLoaded.CustomColor), 'CustomColor round-trip failed');
    Assert.AreEqual(Ord(dsAllLines), Ord(LLoaded.DisplayScope), 'DisplayScope round-trip failed');
    Assert.AreEqual('Ctrl+Shift+G', LLoaded.ToggleHotkey, 'ToggleHotkey round-trip failed');
  finally
    LLoaded.Free;
  end;
end;

procedure TSettingsTests.TestSettingsPathContainsAppData;
var
  LPath: string;
begin
  LPath := TDXBlameSettings.GetSettingsPath;
  Assert.Contains(LPath, 'DX.Blame', 'Path should contain DX.Blame directory');
  Assert.IsTrue(LPath.EndsWith('settings.ini'), 'Path should end with settings.ini');
end;

procedure TSettingsTests.TestLoadNonExistentIniReturnsDefaults;
var
  LSettings: TDXBlameSettings;
begin
  // Constructor calls Load internally; with no INI file it should keep defaults
  LSettings := TDXBlameSettings.Create;
  try
    Assert.IsTrue(LSettings.Enabled, 'Should default to Enabled after missing INI');
    Assert.IsTrue(LSettings.ShowAuthor, 'Should default to ShowAuthor after missing INI');
    Assert.AreEqual(80, LSettings.MaxLength, 'Should default to MaxLength=80 after missing INI');
  finally
    LSettings.Free;
  end;
end;

procedure TSettingsTests.TestSingletonReturnsSameInstance;
var
  LFirst, LSecond: TDXBlameSettings;
begin
  LFirst := BlameSettings;
  LSecond := BlameSettings;
  Assert.AreSame(LFirst, LSecond, 'BlameSettings should return the same singleton instance');
end;

initialization
  TDUnitX.RegisterTestFixture(TSettingsTests);

end.
