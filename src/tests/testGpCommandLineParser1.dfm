object frmTestGpCommandLineParser: TfrmTestGpCommandLineParser
  Left = 0
  Top = 0
  Caption = 'GpCommandLineParser tester'
  ClientHeight = 535
  ClientWidth = 733
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  DesignSize = (
    733
    535)
  PixelsPerInch = 96
  TextHeight = 13
  object inpCommandLine: TLabeledEdit
    Left = 8
    Top = 24
    Width = 716
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    EditLabel.Width = 70
    EditLabel.Height = 13
    EditLabel.Caption = 'Command line:'
    TabOrder = 0
  end
  object btnParse: TButton
    Left = 8
    Top = 51
    Width = 717
    Height = 25
    Anchors = [akLeft, akTop, akRight]
    Caption = 'Parse command line'
    TabOrder = 1
    OnClick = btnParseClick
  end
  object lbLog: TListBox
    Left = 8
    Top = 82
    Width = 717
    Height = 445
    Anchors = [akLeft, akTop, akRight, akBottom]
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Consolas'
    Font.Style = []
    ItemHeight = 13
    ParentFont = False
    TabOrder = 2
  end
end
