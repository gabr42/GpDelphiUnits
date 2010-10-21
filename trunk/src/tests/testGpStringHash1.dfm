object frmTestGpStringHash: TfrmTestGpStringHash
  Left = 0
  Top = 0
  Caption = 'TGpStringHash tester'
  ClientHeight = 286
  ClientWidth = 426
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object lbLog: TListBox
    AlignWithMargins = True
    Left = 3
    Top = 35
    Width = 420
    Height = 248
    Margins.Top = 35
    Align = alClient
    ItemHeight = 13
    TabOrder = 0
  end
  object btnTestStringHash: TButton
    Left = 3
    Top = 5
    Width = 86
    Height = 25
    Caption = 'Test hash'
    TabOrder = 1
    OnClick = btnTestStringHashClick
  end
  object btnTestStringTable: TButton
    Left = 95
    Top = 5
    Width = 85
    Height = 25
    Caption = 'Test table'
    TabOrder = 2
    OnClick = btnTestStringTableClick
  end
  object btnTestDictionary: TButton
    Left = 186
    Top = 5
    Width = 84
    Height = 25
    Caption = 'Test dictionary'
    TabOrder = 3
    OnClick = btnTestDictionaryClick
  end
end
