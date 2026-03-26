object FrameDXBlameSettings: TFrameDXBlameSettings
  Left = 0
  Top = 0
  Width = 400
  Height = 590
  ParentFont = True
  TabOrder = 0
  object GroupBoxFormat: TGroupBox
    Left = 12
    Top = 12
    Width = 376
    Height = 145
    Anchors = [akLeft, akTop, akRight]
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
      Width = 340
      Height = 17
      Caption = 'Show Author'
      TabOrder = 0
    end
    object ComboBoxDateFormat: TComboBox
      Left = 100
      Top = 49
      Width = 256
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
      Width = 340
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
    Width = 376
    Height = 85
    Anchors = [akLeft, akTop, akRight]
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
    Width = 376
    Height = 165
    Anchors = [akLeft, akTop, akRight]
    Caption = ' Display '
    TabOrder = 2
    object RadioButtonCurrentLine: TRadioButton
      Left = 16
      Top = 24
      Width = 140
      Height = 17
      Caption = 'Current line only'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object RadioButtonAllLines: TRadioButton
      Left = 200
      Top = 24
      Width = 140
      Height = 17
      Caption = 'All lines'
      TabOrder = 1
    end
    object LabelAnnotationPosition: TLabel
      Left = 16
      Top = 56
      Width = 110
      Height = 15
      Caption = 'Annotation Position:'
    end
    object ComboBoxAnnotationPosition: TComboBox
      Left = 140
      Top = 53
      Width = 216
      Height = 23
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 2
      Items.Strings = (
        'End of line (default)'
        'Caret-anchored')
    end
    object CheckBoxShowInline: TCheckBox
      Left = 16
      Top = 88
      Width = 340
      Height = 17
      Caption = 'Show inline annotations'
      Checked = True
      State = cbChecked
      TabOrder = 3
    end
    object CheckBoxShowStatusbar: TCheckBox
      Left = 16
      Top = 112
      Width = 340
      Height = 17
      Caption = 'Show in Statusbar'
      TabOrder = 4
    end
  end
  object GroupBoxVCS: TGroupBox
    Left = 12
    Top = 440
    Width = 376
    Height = 55
    Anchors = [akLeft, akTop, akRight]
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
      Width = 256
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
    Top = 505
    Width = 376
    Height = 70
    Anchors = [akLeft, akTop, akRight]
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
      Width = 216
      Height = 15
      Caption = 'Requires IDE restart to change'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsItalic]
      ParentFont = False
    end
  end
  object ColorDialog: TColorDialog
    Left = 340
    Top = 180
  end
end
