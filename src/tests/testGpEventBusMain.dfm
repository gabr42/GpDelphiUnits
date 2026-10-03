object frmEventBusTest: TfrmEventBusTest
  Left = 0
  Top = 0
  Caption = 'GpEventBus Test Application'
  ClientHeight = 641
  ClientWidth = 984
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 13
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 984
    Height = 622
    ActivePage = tsBackgroundThreads
    Align = alClient
    TabOrder = 0
    object tsMainThread: TTabSheet
      Caption = 'Main Thread Events'
      object GroupBox1: TGroupBox
        Left = 3
        Top = 3
        Width = 966
        Height = 234
        Caption = ' Log Display (Main Thread) '
        TabOrder = 0
        object memoLog: TMemo
          Left = 10
          Top = 20
          Width = 945
          Height = 174
          ScrollBars = ssVertical
          TabOrder = 0
        end
        object btnClearLog: TButton
          Left = 10
          Top = 200
          Width = 90
          Height = 25
          Caption = 'Clear Log'
          TabOrder = 1
          OnClick = btnClearLogClick
        end
      end
      object GroupBox2: TGroupBox
        Left = 3
        Top = 243
        Width = 313
        Height = 154
        Caption = ' Fire Log Events '
        TabOrder = 1
        object btnFireLogInfo: TButton
          Left = 16
          Top = 24
          Width = 120
          Height = 30
          Caption = 'Fire Info Event'
          TabOrder = 0
          OnClick = btnFireLogInfoClick
        end
        object btnFireLogWarning: TButton
          Left = 16
          Top = 60
          Width = 120
          Height = 30
          Caption = 'Fire Warning Event'
          TabOrder = 1
          OnClick = btnFireLogWarningClick
        end
        object btnFireLogError: TButton
          Left = 16
          Top = 96
          Width = 120
          Height = 30
          Caption = 'Fire Error Event'
          TabOrder = 2
          OnClick = btnFireLogErrorClick
        end
      end
      object GroupBox3: TGroupBox
        Left = 322
        Top = 243
        Width = 313
        Height = 154
        Caption = ' Log Event Subscription '
        TabOrder = 2
        object lblLogSubscriptions: TLabel
          Left = 16
          Top = 120
          Width = 89
          Height = 13
          Caption = 'Subscriptions: 0'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Tahoma'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object btnSubscribeLog: TButton
          Left = 16
          Top = 24
          Width = 120
          Height = 30
          Caption = 'Subscribe'
          TabOrder = 0
          OnClick = btnSubscribeLogClick
        end
        object btnUnsubscribeLog: TButton
          Left = 16
          Top = 60
          Width = 120
          Height = 30
          Caption = 'Unsubscribe'
          TabOrder = 1
          OnClick = btnUnsubscribeLogClick
        end
      end
      object GroupBox8: TGroupBox
        Left = 641
        Top = 243
        Width = 328
        Height = 154
        Caption = ' Progress Events '
        TabOrder = 3
        object lblProgress: TLabel
          Left = 16
          Top = 90
          Width = 67
          Height = 13
          Caption = 'No progress'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Tahoma'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object lblProgressSubscriptions: TLabel
          Left = 168
          Top = 120
          Width = 89
          Height = 13
          Caption = 'Subscriptions: 0'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Tahoma'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object ProgressBar1: TProgressBar
          Left = 16
          Top = 64
          Width = 297
          Height = 17
          TabOrder = 0
        end
        object btnFireProgress: TButton
          Left = 16
          Top = 24
          Width = 120
          Height = 30
          Caption = 'Fire Progress (1-10)'
          TabOrder = 1
          OnClick = btnFireProgressClick
        end
        object btnSubscribeProgress: TButton
          Left = 16
          Top = 113
          Width = 70
          Height = 25
          Caption = 'Subscribe'
          TabOrder = 2
          OnClick = btnSubscribeProgressClick
        end
        object btnUnsubscribeProgress: TButton
          Left = 92
          Top = 113
          Width = 70
          Height = 25
          Caption = 'Unsubscribe'
          TabOrder = 3
          OnClick = btnUnsubscribeProgressClick
        end
      end
      object GroupBox9: TGroupBox
        Left = 3
        Top = 403
        Width = 313
        Height = 154
        Caption = ' Data Events '
        TabOrder = 4
        object Label5: TLabel
          Left = 16
          Top = 36
          Width = 30
          Height = 13
          Caption = 'Value:'
        end
        object lblDataSubscriptions: TLabel
          Left = 16
          Top = 132
          Width = 89
          Height = 13
          Caption = 'Subscriptions: 0'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Tahoma'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object btnFireData: TButton
          Left = 16
          Top = 64
          Width = 120
          Height = 30
          Caption = 'Fire Data Event'
          TabOrder = 0
          OnClick = btnFireDataClick
        end
        object edtDataValue: TEdit
          Left = 60
          Top = 33
          Width = 76
          Height = 21
          TabOrder = 1
          Text = '42.5'
        end
        object btnSubscribeData: TButton
          Left = 16
          Top = 100
          Width = 60
          Height = 25
          Caption = 'Subscribe'
          TabOrder = 2
          OnClick = btnSubscribeDataClick
        end
        object btnUnsubscribeData: TButton
          Left = 82
          Top = 100
          Width = 70
          Height = 25
          Caption = 'Unsubscribe'
          TabOrder = 3
          OnClick = btnUnsubscribeDataClick
        end
      end
    end
    object tsBackgroundThreads: TTabSheet
      Caption = 'Background Threads'
      ImageIndex = 1
      object GroupBox4: TGroupBox
        Left = 3
        Top = 3
        Width = 481
        Height = 282
        Caption = ' Worker Thread 1 '
        TabOrder = 0
        object Label1: TLabel
          Left = 16
          Top = 20
          Width = 412
          Height = 13
          Caption = 
            'Subscribes to TLogEvent and TDataEvent. Receives events in its o' +
            'wn thread context.'
        end
        object memoWorker1: TMemo
          Left = 16
          Top = 72
          Width = 449
          Height = 169
          ScrollBars = ssVertical
          TabOrder = 0
        end
        object btnStartWorker1: TButton
          Left = 16
          Top = 39
          Width = 100
          Height = 25
          Caption = 'Start Worker 1'
          TabOrder = 1
          OnClick = btnStartWorker1Click
        end
        object btnStopWorker1: TButton
          Left = 122
          Top = 39
          Width = 100
          Height = 25
          Caption = 'Stop Worker 1'
          TabOrder = 2
          OnClick = btnStopWorker1Click
        end
      end
      object GroupBox5: TGroupBox
        Left = 490
        Top = 3
        Width = 481
        Height = 282
        Caption = ' Worker Thread 2 '
        TabOrder = 1
        object Label2: TLabel
          Left = 16
          Top = 20
          Width = 412
          Height = 13
          Caption = 
            'Subscribes to TLogEvent and TDataEvent. Receives events in its o' +
            'wn thread context.'
        end
        object memoWorker2: TMemo
          Left = 16
          Top = 72
          Width = 449
          Height = 169
          ScrollBars = ssVertical
          TabOrder = 0
        end
        object btnStartWorker2: TButton
          Left = 16
          Top = 39
          Width = 100
          Height = 25
          Caption = 'Start Worker 2'
          TabOrder = 1
          OnClick = btnStartWorker2Click
        end
        object btnStopWorker2: TButton
          Left = 122
          Top = 39
          Width = 100
          Height = 25
          Caption = 'Stop Worker 2'
          TabOrder = 2
          OnClick = btnStopWorker2Click
        end
      end
      object GroupBox7: TGroupBox
        Left = 3
        Top = 291
        Width = 481
        Height = 282
        Caption = ' Event Producer Thread '
        TabOrder = 2
        object Label3: TLabel
          Left = 16
          Top = 20
          Width = 441
          Height = 13
          Caption = 
            'Periodically fires events from background thread (TLogEvent, TPr' +
            'ogressEvent, TDataEvent)'
        end
        object Label4: TLabel
          Left = 16
          Top = 50
          Width = 79
          Height = 13
          Caption = 'Interval (ms):'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Tahoma'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object btnStartProducer: TButton
          Left = 204
          Top = 45
          Width = 100
          Height = 25
          Caption = 'Start Producer'
          TabOrder = 0
          OnClick = btnStartProducerClick
        end
        object btnStopProducer: TButton
          Left = 310
          Top = 45
          Width = 100
          Height = 25
          Caption = 'Stop Producer'
          TabOrder = 1
          OnClick = btnStopProducerClick
        end
        object edtProducerInterval: TEdit
          Left = 102
          Top = 47
          Width = 80
          Height = 21
          TabOrder = 2
          Text = '1000'
        end
      end
    end
    object tsEvents: TTabSheet
      Caption = 'Event Log'
      ImageIndex = 2
      object GroupBox6: TGroupBox
        Left = 3
        Top = 3
        Width = 966
        Height = 570
        Caption = ' Global Event Log '
        TabOrder = 0
        object memoEventLog: TMemo
          Left = 10
          Top = 20
          Width = 945
          Height = 510
          ScrollBars = ssVertical
          TabOrder = 0
        end
        object btnClearEvents: TButton
          Left = 10
          Top = 536
          Width = 90
          Height = 25
          Caption = 'Clear Log'
          TabOrder = 1
          OnClick = btnClearEventsClick
        end
      end
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 622
    Width = 984
    Height = 19
    Panels = <>
    SimplePanel = True
  end
  object Timer1: TTimer
    Interval = 500
    OnTimer = Timer1Timer
    Left = 904
    Top = 8
  end
end
