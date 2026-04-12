object FormDXBlameSettings: TFormDXBlameSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'DX Blame Settings'
  ClientHeight = 765
  ClientWidth = 500
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object GroupBoxFormat: TGroupBox
    Left = 12
    Top = 12
    Width = 476
    Height = 145
    Caption = ' Format '
    TabOrder = 0
    object LabelDateFormat: TLabel
      Left = 16
      Top = 52
      Width = 67
      Height = 15
      Caption = 'Date Format:'
    end
    object LabelMaxLength: TLabel
      Left = 16
      Top = 112
      Width = 65
      Height = 15
      Caption = 'Max Length:'
    end
    object CheckBoxShowAuthor: TCheckBox
      Left = 16
      Top = 24
      Width = 444
      Height = 17
      Caption = 'Show Author'
      TabOrder = 0
    end
    object ComboBoxDateFormat: TComboBox
      Left = 100
      Top = 49
      Width = 356
      Height = 23
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 1
      Items.Strings = (
        'Relative (e.g. 3 months ago)'
        'Absolute (e.g. 2026-01-15)')
    end
    object CheckBoxShowSummary: TCheckBox
      Left = 16
      Top = 84
      Width = 444
      Height = 17
      Caption = 'Show Commit Summary'
      TabOrder = 2
    end
    object EditMaxLength: TEdit
      Left = 100
      Top = 109
      Width = 60
      Height = 23
      NumbersOnly = True
      TabOrder = 3
      Text = '80'
    end
    object UpDownMaxLength: TUpDown
      Left = 160
      Top = 109
      Width = 17
      Height = 23
      Associate = EditMaxLength
      Min = 20
      Max = 200
      Position = 80
      TabOrder = 4
    end
  end
  object GroupBoxAppearance: TGroupBox
    Left = 12
    Top = 168
    Width = 476
    Height = 85
    Caption = ' Appearance '
    TabOrder = 1
    object RadioButtonAutoColor: TRadioButton
      Left = 16
      Top = 24
      Width = 200
      Height = 17
      Caption = 'Auto (derive from IDE theme)'
      Checked = True
      TabOrder = 0
      TabStop = True
      OnClick = RadioButtonAutoColorClick
    end
    object RadioButtonCustomColor: TRadioButton
      Left = 16
      Top = 52
      Width = 110
      Height = 17
      Caption = 'Custom Color'
      TabOrder = 1
      OnClick = RadioButtonCustomColorClick
    end
    object PanelColorPreview: TPanel
      Left = 140
      Top = 48
      Width = 60
      Height = 25
      Color = clGray
      Enabled = False
      ParentBackground = False
      TabOrder = 2
    end
    object ButtonChooseColor: TButton
      Left = 210
      Top = 48
      Width = 75
      Height = 25
      Caption = 'Choose...'
      Enabled = False
      TabOrder = 3
      OnClick = ButtonChooseColorClick
    end
  end
  object GroupBoxDisplay: TGroupBox
    Left = 12
    Top = 264
    Width = 476
    Height = 160
    Caption = ' Display '
    TabOrder = 2
    object LabelAnnotationPosition: TLabel
      Left = 16
      Top = 24
      Width = 110
      Height = 15
      Caption = 'Annotation Position:'
    end
    object ComboBoxAnnotationPosition: TComboBox
      Left = 140
      Top = 21
      Width = 316
      Height = 23
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 0
      Items.Strings = (
        'Caret-anchored (default)'
        'Right-aligned in editor')
    end
    object LabelPopupTrigger: TLabel
      Left = 16
      Top = 56
      Width = 78
      Height = 15
      Caption = 'Popup Trigger:'
    end
    object ComboBoxPopupTrigger: TComboBox
      Left = 140
      Top = 53
      Width = 316
      Height = 23
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 1
      Items.Strings = (
        'Hover (default)'
        'Click on hash link')
    end
    object CheckBoxShowInline: TCheckBox
      Left = 16
      Top = 88
      Width = 444
      Height = 17
      Caption = 'Show inline annotations'
      Checked = True
      State = cbChecked
      TabOrder = 2
    end
    object CheckBoxShowStatusbar: TCheckBox
      Left = 16
      Top = 112
      Width = 444
      Height = 17
      Caption = 'Show in Statusbar'
      Checked = True
      State = cbChecked
      TabOrder = 3
    end
  end
  object GroupBoxVCS: TGroupBox
    Left = 12
    Top = 435
    Width = 476
    Height = 55
    Caption = ' Version Control '
    TabOrder = 3
    object LabelVCSPreference: TLabel
      Left = 16
      Top = 22
      Width = 68
      Height = 15
      Caption = 'VCS Backend:'
    end
    object ComboBoxVCSPreference: TComboBox
      Left = 100
      Top = 19
      Width = 356
      Height = 23
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 0
      Items.Strings = (
        'Auto (detect from repository)'
        'Git'
        'Mercurial')
    end
  end
  object GroupBoxHotkey: TGroupBox
    Left = 12
    Top = 500
    Width = 476
    Height = 122
    Caption = ' Hotkey '
    TabOrder = 4
    object LabelHotkeyValue: TLabel
      Left = 16
      Top = 24
      Width = 60
      Height = 15
      Caption = 'Ctrl+Alt+B'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object LabelHotkeyInfo: TLabel
      Left = 16
      Top = 44
      Width = 444
      Height = 68
      Anchors = [akLeft, akTop, akRight]
      Caption = 
        'The shortcut is fixed in the plugin (Ctrl+Alt+B). Reassigning it is not supported in this release. In Tools > Options > Editor > Key Mappings you can only enable or disable the "DX Blame Toggle" module and change its order in the list—not the key combination. This page shows the default for reference.'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsItalic]
      ParentFont = False
      WordWrap = True
    end
  end
  object GroupBoxDiagnostics: TGroupBox
    Left = 12
    Top = 630
    Width = 476
    Height = 75
    Caption = ' Diagnostics '
    TabOrder = 5
    object CheckBoxEnableDebugLogging: TCheckBox
      Left = 16
      Top = 24
      Width = 444
      Height = 17
      Caption = 'Enable debug logging'
      TabOrder = 0
    end
    object CheckBoxSuppressPopupInDebug: TCheckBox
      Left = 16
      Top = 47
      Width = 444
      Height = 17
      Caption = 'Suppress popup during debugging'
      Checked = True
      State = cbChecked
      TabOrder = 1
    end
  end
  object ButtonResetDefaults: TButton
    Left = 12
    Top = 721
    Width = 120
    Height = 28
    Caption = 'Reset to Defaults'
    TabOrder = 6
    OnClick = ButtonResetDefaultsClick
  end
  object ButtonOK: TButton
    Left = 320
    Top = 721
    Width = 80
    Height = 28
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 7
    OnClick = ButtonOKClick
  end
  object ButtonCancel: TButton
    Left = 408
    Top = 721
    Width = 80
    Height = 28
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 8
    OnClick = ButtonCancelClick
  end
  object ColorDialog: TColorDialog
    Left = 340
    Top = 180
  end
end
