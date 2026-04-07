/// <summary>
/// DX.Blame.Settings.Frame
/// TFrame embedding all DX.Blame settings controls for the IDE Options dialog.
/// </summary>
///
/// <remarks>
/// Provides TFrameDXBlameSettings, a TFrame containing all DX.Blame configuration
/// controls mirroring TFormDXBlameSettings. Designed to be hosted by the IDE
/// Tools > Options dialog via INTAAddInOptions (see DX.Blame.Settings.Options).
/// LoadFromSettings and SaveToSettings replicate the modal form's logic exactly,
/// including all side effects: INI persistence, editor invalidation, and VCS
/// re-detection when the preference changes.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Settings.Frame;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Dialogs,
  Vcl.Graphics;

type
  /// <summary>
  /// Settings frame for embedding in the IDE Tools > Options dialog.
  /// All control names are identical to TFormDXBlameSettings for consistency.
  /// </summary>
  TFrameDXBlameSettings = class(TFrame)
    GroupBoxFormat: TGroupBox;
    CheckBoxShowAuthor: TCheckBox;
    LabelDateFormat: TLabel;
    ComboBoxDateFormat: TComboBox;
    CheckBoxShowSummary: TCheckBox;
    LabelMaxLength: TLabel;
    EditMaxLength: TEdit;
    UpDownMaxLength: TUpDown;
    GroupBoxAppearance: TGroupBox;
    RadioButtonAutoColor: TRadioButton;
    RadioButtonCustomColor: TRadioButton;
    PanelColorPreview: TPanel;
    ButtonChooseColor: TButton;
    GroupBoxDisplay: TGroupBox;
    LabelAnnotationPosition: TLabel;
    ComboBoxAnnotationPosition: TComboBox;
    LabelPopupTrigger: TLabel;
    ComboBoxPopupTrigger: TComboBox;
    CheckBoxShowInline: TCheckBox;
    CheckBoxShowStatusbar: TCheckBox;
    GroupBoxVCS: TGroupBox;
    LabelVCSPreference: TLabel;
    ComboBoxVCSPreference: TComboBox;
    GroupBoxHotkey: TGroupBox;
    LabelHotkeyValue: TLabel;
    LabelHotkeyInfo: TLabel;
    CheckBoxEnableDebugLogging: TCheckBox;
    ButtonResetDefaults: TButton;
    ColorDialog: TColorDialog;
    procedure RadioButtonCustomColorClick(Sender: TObject);
    procedure RadioButtonAutoColorClick(Sender: TObject);
    procedure ButtonChooseColorClick(Sender: TObject);
    procedure ButtonResetDefaultsClick(Sender: TObject);
  private
    FSelectedColor: TColor;
    /// <summary>Enables or disables the color preview panel and choose button.</summary>
    procedure UpdateColorPreviewState;
  public
    /// <summary>Populates all controls from the BlameSettings singleton.</summary>
    procedure LoadFromSettings;
    /// <summary>
    /// Writes all controls back to the BlameSettings singleton and persists to INI.
    /// Also calls InvalidateAllEditors and triggers VCS re-detection if VCS preference changed.
    /// </summary>
    procedure SaveToSettings;
  end;

implementation

{$R *.dfm}

uses
  ToolsAPI,
  DX.Blame.Settings,
  DX.Blame.Engine,
  DX.Blame.Renderer;

{ TFrameDXBlameSettings }

procedure TFrameDXBlameSettings.LoadFromSettings;
var
  LSettings: TDXBlameSettings;
begin
  LSettings := BlameSettings;

  CheckBoxShowAuthor.Checked := LSettings.ShowAuthor;
  ComboBoxDateFormat.ItemIndex := Ord(LSettings.DateFormat);
  CheckBoxShowSummary.Checked := LSettings.ShowSummary;
  UpDownMaxLength.Position := LSettings.MaxLength;

  if LSettings.UseCustomColor then
    RadioButtonCustomColor.Checked := True
  else
    RadioButtonAutoColor.Checked := True;

  FSelectedColor := LSettings.CustomColor;
  PanelColorPreview.Color := FSelectedColor;
  UpdateColorPreviewState;

  ComboBoxAnnotationPosition.ItemIndex := Ord(LSettings.AnnotationPosition);
  ComboBoxPopupTrigger.ItemIndex := Ord(LSettings.PopupTrigger);
  CheckBoxShowInline.Checked := LSettings.ShowInline;
  CheckBoxShowStatusbar.Checked := LSettings.ShowStatusbar;
  CheckBoxEnableDebugLogging.Checked := LSettings.EnableDebugLogging;

  LabelHotkeyValue.Caption := LSettings.ToggleHotkey;

  ComboBoxVCSPreference.ItemIndex := Ord(LSettings.VCSPreference);
end;

procedure TFrameDXBlameSettings.SaveToSettings;
var
  LSettings: TDXBlameSettings;
  LVCSChanged: Boolean;
  LModuleServices: IOTAModuleServices;
begin
  LSettings := BlameSettings;

  // Detect if VCS preference changed before saving
  LVCSChanged := LSettings.VCSPreference <> TDXBlameVCSPreference(ComboBoxVCSPreference.ItemIndex);

  LSettings.ShowAuthor := CheckBoxShowAuthor.Checked;
  LSettings.DateFormat := TDXBlameDateFormat(ComboBoxDateFormat.ItemIndex);
  LSettings.ShowSummary := CheckBoxShowSummary.Checked;
  LSettings.MaxLength := UpDownMaxLength.Position;
  LSettings.UseCustomColor := RadioButtonCustomColor.Checked;
  LSettings.CustomColor := FSelectedColor;

  LSettings.AnnotationPosition := TDXBlameAnnotationPosition(ComboBoxAnnotationPosition.ItemIndex);
  LSettings.PopupTrigger := TDXBlamePopupTrigger(ComboBoxPopupTrigger.ItemIndex);
  LSettings.ShowInline := CheckBoxShowInline.Checked;
  LSettings.ShowStatusbar := CheckBoxShowStatusbar.Checked;
  LSettings.EnableDebugLogging := CheckBoxEnableDebugLogging.Checked;

  LSettings.VCSPreference := TDXBlameVCSPreference(ComboBoxVCSPreference.ItemIndex);

  LSettings.Save;

  InvalidateAllEditors;

  // Trigger VCS re-detection when preference changed
  if LVCSChanged then
  begin
    if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
      if LModuleServices.MainProjectGroup <> nil then
        if LModuleServices.MainProjectGroup.ActiveProject <> nil then
          BlameEngine.OnProjectSwitch(
            LModuleServices.MainProjectGroup.ActiveProject.FileName);
  end;
end;

procedure TFrameDXBlameSettings.RadioButtonCustomColorClick(Sender: TObject);
begin
  UpdateColorPreviewState;
end;

procedure TFrameDXBlameSettings.RadioButtonAutoColorClick(Sender: TObject);
begin
  UpdateColorPreviewState;
end;

procedure TFrameDXBlameSettings.ButtonChooseColorClick(Sender: TObject);
begin
  ColorDialog.Color := FSelectedColor;
  if ColorDialog.Execute then
  begin
    FSelectedColor := ColorDialog.Color;
    PanelColorPreview.Color := FSelectedColor;
  end;
end;

procedure TFrameDXBlameSettings.ButtonResetDefaultsClick(Sender: TObject);
begin
  BlameSettings.ResetToDefaults;
  LoadFromSettings;
end;

procedure TFrameDXBlameSettings.UpdateColorPreviewState;
var
  LEnabled: Boolean;
begin
  LEnabled := RadioButtonCustomColor.Checked;
  PanelColorPreview.Enabled := LEnabled;
  ButtonChooseColor.Enabled := LEnabled;
end;

end.
