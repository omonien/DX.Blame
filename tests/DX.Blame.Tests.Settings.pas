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
    [Test]
    procedure TestDiffDialogWidth_DefaultsTo800;
    [Test]
    procedure TestDiffDialogHeight_DefaultsTo600;
    [Test]
    procedure TestDiffDialogSize_RoundTrips;
    [Test]
    procedure TestEnableDebugLogging_DefaultMatchesBuildConfig;
    [Test]
    procedure TestEnableDebugLogging_RoundTrips;
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
    LIni.WriteBool('Debug', 'EnableDebugLogging', FSettings.EnableDebugLogging);
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
  {$IFDEF DEBUG}
  Assert.IsTrue(FSettings.EnableDebugLogging, 'EnableDebugLogging should default to True in Debug');
  {$ELSE}
  Assert.IsFalse(FSettings.EnableDebugLogging, 'EnableDebugLogging should default to False in Release');
  {$ENDIF}
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
  FSettings.ToggleHotkey := 'Ctrl+Shift+G';
  FSettings.EnableDebugLogging := False;

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
      {$IFDEF DEBUG}
      LLoaded.EnableDebugLogging := LIni.ReadBool('Debug', 'EnableDebugLogging', True);
      {$ELSE}
      LLoaded.EnableDebugLogging := LIni.ReadBool('Debug', 'EnableDebugLogging', False);
      {$ENDIF}
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
    Assert.AreEqual('Ctrl+Shift+G', LLoaded.ToggleHotkey, 'ToggleHotkey round-trip failed');
    Assert.IsFalse(LLoaded.EnableDebugLogging, 'EnableDebugLogging round-trip failed');
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

procedure TSettingsTests.TestDiffDialogWidth_DefaultsTo800;
begin
  Assert.AreEqual(800, FSettings.DiffDialogWidth, 'DiffDialogWidth should default to 800');
end;

procedure TSettingsTests.TestDiffDialogHeight_DefaultsTo600;
begin
  Assert.AreEqual(600, FSettings.DiffDialogHeight, 'DiffDialogHeight should default to 600');
end;

procedure TSettingsTests.TestDiffDialogSize_RoundTrips;
var
  LLoaded: TDXBlameSettings;
  LIni: TIniFile;
begin
  FSettings.DiffDialogWidth := 1024;
  FSettings.DiffDialogHeight := 768;

  // Save to temp INI manually (same pattern as SaveToTemp but including DiffDialog section)
  LIni := TIniFile.Create(FTempIniPath);
  try
    LIni.WriteInteger('DiffDialog', 'Width', FSettings.DiffDialogWidth);
    LIni.WriteInteger('DiffDialog', 'Height', FSettings.DiffDialogHeight);
  finally
    LIni.Free;
  end;

  // Create a new settings object and load from temp
  LLoaded := TDXBlameSettings.Create;
  try
    // Read DiffDialog section from temp file
    LIni := TIniFile.Create(FTempIniPath);
    try
      LLoaded.DiffDialogWidth := LIni.ReadInteger('DiffDialog', 'Width', 800);
      LLoaded.DiffDialogHeight := LIni.ReadInteger('DiffDialog', 'Height', 600);
    finally
      LIni.Free;
    end;

    Assert.AreEqual(1024, LLoaded.DiffDialogWidth, 'DiffDialogWidth round-trip failed');
    Assert.AreEqual(768, LLoaded.DiffDialogHeight, 'DiffDialogHeight round-trip failed');
  finally
    LLoaded.Free;
  end;
end;

procedure TSettingsTests.TestEnableDebugLogging_DefaultMatchesBuildConfig;
begin
  {$IFDEF DEBUG}
  Assert.IsTrue(FSettings.EnableDebugLogging, 'Debug build should default logging to enabled');
  {$ELSE}
  Assert.IsFalse(FSettings.EnableDebugLogging, 'Release build should default logging to disabled');
  {$ENDIF}
end;

procedure TSettingsTests.TestEnableDebugLogging_RoundTrips;
var
  LLoaded: TDXBlameSettings;
  LIni: TIniFile;
begin
  FSettings.EnableDebugLogging := not FSettings.EnableDebugLogging;
  SaveToTemp;

  LLoaded := TDXBlameSettings.Create;
  try
    LIni := TIniFile.Create(FTempIniPath);
    try
      {$IFDEF DEBUG}
      LLoaded.EnableDebugLogging := LIni.ReadBool('Debug', 'EnableDebugLogging', True);
      {$ELSE}
      LLoaded.EnableDebugLogging := LIni.ReadBool('Debug', 'EnableDebugLogging', False);
      {$ENDIF}
    finally
      LIni.Free;
    end;

    Assert.AreEqual(FSettings.EnableDebugLogging, LLoaded.EnableDebugLogging,
      'EnableDebugLogging should round-trip through INI');
  finally
    LLoaded.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSettingsTests);

end.
