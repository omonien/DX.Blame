/// <summary>
/// DX.Blame.Settings.Form
/// VCL modal dialog for configuring all DX.Blame display options.
/// </summary>
///
/// <remarks>
/// Provides TFormDXBlameSettings, a modal settings dialog that exposes all
/// CONF-01/CONF-02 configuration options: author visibility, date format,
/// commit summary, max annotation length, custom color, and display scope.
/// On OK, settings are written back to the TDXBlameSettings singleton and
/// persisted to INI. The class method ShowSettings handles create/show/free.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Settings.Form;

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
  /// Modal settings dialog for all DX.Blame configuration options.
  /// </summary>
  TFormDXBlameSettings = class(TForm)
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
    RadioButtonCurrentLine: TRadioButton;
    RadioButtonAllLines: TRadioButton;
    LabelAnnotationPosition: TLabel;
    ComboBoxAnnotationPosition: TComboBox;
    GroupBoxVCS: TGroupBox;
    LabelVCSPreference: TLabel;
    ComboBoxVCSPreference: TComboBox;
    GroupBoxHotkey: TGroupBox;
    LabelHotkeyValue: TLabel;
    LabelHotkeyInfo: TLabel;
    ButtonOK: TButton;
    ButtonCancel: TButton;
    ColorDialog: TColorDialog;
    procedure FormCreate(Sender: TObject);
    procedure ButtonOKClick(Sender: TObject);
    procedure ButtonCancelClick(Sender: TObject);
    procedure RadioButtonCustomColorClick(Sender: TObject);
    procedure RadioButtonAutoColorClick(Sender: TObject);
    procedure ButtonChooseColorClick(Sender: TObject);
  private
    FSelectedColor: TColor;
    procedure LoadFromSettings;
    procedure SaveToSettings;
    procedure UpdateColorPreviewState;
  public
    /// <summary>Creates, shows modal, and frees the settings dialog.</summary>
    class procedure ShowSettings;
  end;

var
  FormDXBlameSettings: TFormDXBlameSettings;

implementation

{$R *.dfm}

uses
  ToolsAPI,
  DX.Blame.Settings,
  DX.Blame.Engine,
  DX.Blame.Renderer;

{ TFormDXBlameSettings }

class procedure TFormDXBlameSettings.ShowSettings;
var
  LForm: TFormDXBlameSettings;
begin
  LForm := TFormDXBlameSettings.Create(Application);
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

procedure TFormDXBlameSettings.FormCreate(Sender: TObject);
begin
  LoadFromSettings;
end;

procedure TFormDXBlameSettings.LoadFromSettings;
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

  if LSettings.DisplayScope = dsCurrentLine then
    RadioButtonCurrentLine.Checked := True
  else
    RadioButtonAllLines.Checked := True;

  ComboBoxAnnotationPosition.ItemIndex := Ord(LSettings.AnnotationPosition);

  LabelHotkeyValue.Caption := LSettings.ToggleHotkey;

  ComboBoxVCSPreference.ItemIndex := Ord(LSettings.VCSPreference);
end;

procedure TFormDXBlameSettings.SaveToSettings;
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

  if RadioButtonAllLines.Checked then
    LSettings.DisplayScope := dsAllLines
  else
    LSettings.DisplayScope := dsCurrentLine;

  LSettings.AnnotationPosition := TDXBlameAnnotationPosition(ComboBoxAnnotationPosition.ItemIndex);

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

procedure TFormDXBlameSettings.ButtonOKClick(Sender: TObject);
begin
  SaveToSettings;
  ModalResult := mrOk;
end;

procedure TFormDXBlameSettings.ButtonCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TFormDXBlameSettings.RadioButtonCustomColorClick(Sender: TObject);
begin
  UpdateColorPreviewState;
end;

procedure TFormDXBlameSettings.RadioButtonAutoColorClick(Sender: TObject);
begin
  UpdateColorPreviewState;
end;

procedure TFormDXBlameSettings.ButtonChooseColorClick(Sender: TObject);
begin
  ColorDialog.Color := FSelectedColor;
  if ColorDialog.Execute then
  begin
    FSelectedColor := ColorDialog.Color;
    PanelColorPreview.Color := FSelectedColor;
  end;
end;

procedure TFormDXBlameSettings.UpdateColorPreviewState;
var
  LEnabled: Boolean;
begin
  LEnabled := RadioButtonCustomColor.Checked;
  PanelColorPreview.Enabled := LEnabled;
  ButtonChooseColor.Enabled := LEnabled;
end;

end.
