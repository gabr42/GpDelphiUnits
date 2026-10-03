unit testGpEventBusMain;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes, System.Generics.Collections,
  System.SyncObjs, System.TypInfo,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.ExtCtrls,
  GpEventBus;

type
  // Event type definitions
  TLogLevel = (llDebug, llInfo, llWarning, llError);

  TLogEvent = record
    Level: TLogLevel;
    Message: string;
    ThreadID: TThreadID;
    Timestamp: TDateTime;
    class function Create(ALevel: TLogLevel; const AMessage: string): TLogEvent; static;
  end;

  TProgressEvent = record
    TaskName: string;
    Current: Integer;
    Total: Integer;
    Percentage: Double;
    class function Create(const ATaskName: string; ACurrent, ATotal: Integer): TProgressEvent; static;
  end;

  TDataEvent = record
    DataID: Integer;
    Description: string;
    Value: Double;
    class function Create(AID: Integer; const ADesc: string; AValue: Double): TDataEvent; static;
  end;

  // Background worker thread that subscribes to events
  TWorkerThread = class(TThread)
  private
    FName: string;
    FLogMemo: TMemo;
    FSubscriptions: TList<IEventSubscription>;
    FStopEvent: TEvent;
    procedure LogMessage(const msg: string);
  protected
    procedure Execute; override;
  public
    constructor Create(const AName: string; ALogMemo: TMemo);
    destructor Destroy; override;
    procedure Stop;
  end;

  // Background thread that periodically fires events
  TEventProducerThread = class(TThread)
  private
    FStopEvent: TEvent;
    FInterval_ms: Integer;
    FCounter: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(AInterval_ms: Integer);
    destructor Destroy; override;
    procedure Stop;
  end;

  TfrmEventBusTest = class(TForm)
    PageControl1: TPageControl;
    tsMainThread: TTabSheet;
    tsBackgroundThreads: TTabSheet;
    tsEvents: TTabSheet;
    GroupBox1: TGroupBox;
    memoLog: TMemo;
    btnClearLog: TButton;
    GroupBox2: TGroupBox;
    btnFireLogInfo: TButton;
    btnFireLogWarning: TButton;
    btnFireLogError: TButton;
    GroupBox3: TGroupBox;
    btnSubscribeLog: TButton;
    btnUnsubscribeLog: TButton;
    lblLogSubscriptions: TLabel;
    GroupBox4: TGroupBox;
    btnStartWorker1: TButton;
    btnStopWorker1: TButton;
    memoWorker1: TMemo;
    Label1: TLabel;
    GroupBox5: TGroupBox;
    btnStartWorker2: TButton;
    btnStopWorker2: TButton;
    memoWorker2: TMemo;
    Label2: TLabel;
    GroupBox6: TGroupBox;
    memoEventLog: TMemo;
    btnClearEvents: TButton;
    GroupBox7: TGroupBox;
    btnStartProducer: TButton;
    btnStopProducer: TButton;
    Label3: TLabel;
    edtProducerInterval: TEdit;
    Label4: TLabel;
    GroupBox8: TGroupBox;
    ProgressBar1: TProgressBar;
    lblProgress: TLabel;
    btnFireProgress: TButton;
    GroupBox9: TGroupBox;
    btnFireData: TButton;
    edtDataValue: TEdit;
    Label5: TLabel;
    StatusBar1: TStatusBar;
    Timer1: TTimer;
    btnSubscribeProgress: TButton;
    btnUnsubscribeProgress: TButton;
    lblProgressSubscriptions: TLabel;
    btnSubscribeData: TButton;
    btnUnsubscribeData: TButton;
    lblDataSubscriptions: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnClearLogClick(Sender: TObject);
    procedure btnFireLogInfoClick(Sender: TObject);
    procedure btnFireLogWarningClick(Sender: TObject);
    procedure btnFireLogErrorClick(Sender: TObject);
    procedure btnSubscribeLogClick(Sender: TObject);
    procedure btnUnsubscribeLogClick(Sender: TObject);
    procedure btnStartWorker1Click(Sender: TObject);
    procedure btnStopWorker1Click(Sender: TObject);
    procedure btnStartWorker2Click(Sender: TObject);
    procedure btnStopWorker2Click(Sender: TObject);
    procedure btnClearEventsClick(Sender: TObject);
    procedure btnStartProducerClick(Sender: TObject);
    procedure btnStopProducerClick(Sender: TObject);
    procedure btnFireProgressClick(Sender: TObject);
    procedure btnFireDataClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure btnSubscribeProgressClick(Sender: TObject);
    procedure btnUnsubscribeProgressClick(Sender: TObject);
    procedure btnSubscribeDataClick(Sender: TObject);
    procedure btnUnsubscribeDataClick(Sender: TObject);
  private
    FLogSubscription: IEventSubscription;
    FProgressSubscription: IEventSubscription;
    FDataSubscription: IEventSubscription;
    FWorker1: TWorkerThread;
    FWorker2: TWorkerThread;
    FProducer: TEventProducerThread;
    procedure UpdateSubscriptionCounts;
    procedure LogToEventLog(const msg: string);
  end;

var
  frmEventBusTest: TfrmEventBusTest;

implementation

{$R *.dfm}

uses
  System.DateUtils;

{ TLogEvent }

class function TLogEvent.Create(ALevel: TLogLevel; const AMessage: string): TLogEvent;
begin
  Result.Level := ALevel;
  Result.Message := AMessage;
  Result.ThreadID := GetCurrentThreadId;
  Result.Timestamp := Now;
end;

{ TProgressEvent }

class function TProgressEvent.Create(const ATaskName: string;
  ACurrent, ATotal: Integer): TProgressEvent;
begin
  Result.TaskName := ATaskName;
  Result.Current := ACurrent;
  Result.Total := ATotal;
  if ATotal > 0 then
    Result.Percentage := (ACurrent / ATotal) * 100
  else
    Result.Percentage := 0;
end;

{ TDataEvent }

class function TDataEvent.Create(AID: Integer; const ADesc: string;
  AValue: Double): TDataEvent;
begin
  Result.DataID := AID;
  Result.Description := ADesc;
  Result.Value := AValue;
end;

{ TWorkerThread }

constructor TWorkerThread.Create(const AName: string; ALogMemo: TMemo);
begin
  inherited Create(True);
  FName := AName;
  FLogMemo := ALogMemo;
  FSubscriptions := TList<IEventSubscription>.Create;
  FStopEvent := TEvent.Create(nil, True, False, '');
  FreeOnTerminate := False;
end;

destructor TWorkerThread.Destroy;
begin
  FreeAndNil(FSubscriptions);
  FreeAndNil(FStopEvent);
  inherited;
end;

procedure TWorkerThread.LogMessage(const msg: string);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      if assigned(FLogMemo) then
        FLogMemo.Lines.Add(Format('[%s] %s', [FormatDateTime('hh:nn:ss.zzz', Now), msg]));
    end);
end;

procedure TWorkerThread.Execute;
begin
  LogMessage(Format('%s: Starting, ThreadID=%d', [FName, GetCurrentThreadId]));

  // Register this thread with the event bus
  EventBus.RegisterThread;
  try
    LogMessage(Format('%s: Registered with EventBus', [FName]));

    // Subscribe to multiple event types
    FSubscriptions.Add(
      EventBus.Subscribe<TLogEvent>(
        procedure(const evt: TLogEvent)
        begin
          LogMessage(Format('Received LogEvent: [%s] %s (from thread %d)',
            [GetEnumName(TypeInfo(TLogLevel), Ord(evt.Level)),
             evt.Message, evt.ThreadID]));
        end));

    FSubscriptions.Add(
      EventBus.Subscribe<TDataEvent>(
        procedure(const evt: TDataEvent)
        begin
          LogMessage(Format('Received DataEvent: ID=%d, Desc=%s, Value=%.2f',
            [evt.DataID, evt.Description, evt.Value]));
        end));

    LogMessage(Format('%s: Subscribed to events', [FName]));

    // Main loop with alertable wait (CRITICAL for QueueUserAPC)
    while WaitForSingleObjectEx(FStopEvent.Handle, 100, True) <> WAIT_OBJECT_0 do
    begin
      // Alertable wait - APCs will wake us up
      // Nothing else to do here
    end;

    LogMessage(Format('%s: Shutting down', [FName]));
  finally
    // Clean up subscriptions
    FSubscriptions.Clear;
    EventBus.UnregisterThread;
    LogMessage(Format('%s: Unregistered from EventBus', [FName]));
  end;
end;

procedure TWorkerThread.Stop;
begin
  FStopEvent.SetEvent;
end;

{ TEventProducerThread }

constructor TEventProducerThread.Create(AInterval_ms: Integer);
begin
  inherited Create(True);
  FInterval_ms := AInterval_ms;
  FCounter := 0;
  FStopEvent := TEvent.Create(nil, True, False, '');
  FreeOnTerminate := False;
end;

destructor TEventProducerThread.Destroy;
begin
  FreeAndNil(FStopEvent);
  inherited;
end;

procedure TEventProducerThread.Execute;
begin
  while WaitForSingleObjectEx(FStopEvent.Handle, FInterval_ms, True) <> WAIT_OBJECT_0 do
  begin
    Inc(FCounter);

    // Fire different types of events
    case FCounter mod 3 of
      0: EventBus.Fire<TLogEvent>(
           TLogEvent.Create(llInfo, Format('Producer event #%d', [FCounter])));
      1: EventBus.Fire<TProgressEvent>(
           TProgressEvent.Create('Auto progress', FCounter, 100));
      2: EventBus.Fire<TDataEvent>(
           TDataEvent.Create(FCounter, 'Auto data', Random * 100));
    end;
  end;
end;

procedure TEventProducerThread.Stop;
begin
  FStopEvent.SetEvent;
end;

{ TfrmEventBusTest }

procedure TfrmEventBusTest.FormCreate(Sender: TObject);
begin
  PageControl1.ActivePageIndex := 0;
  edtProducerInterval.Text := '1000';
  edtDataValue.Text := '42.5';
  UpdateSubscriptionCounts;

  LogToEventLog('Application started');
  LogToEventLog(Format('Main thread ID: %d', [MainThreadID]));
end;

procedure TfrmEventBusTest.FormDestroy(Sender: TObject);
begin
  // Stop all threads
  if assigned(FProducer) then
  begin
    FProducer.Stop;
    FProducer.WaitFor;
    FreeAndNil(FProducer);
  end;

  if assigned(FWorker1) then
  begin
    FWorker1.Stop;
    FWorker1.WaitFor;
    FreeAndNil(FWorker1);
  end;

  if assigned(FWorker2) then
  begin
    FWorker2.Stop;
    FWorker2.WaitFor;
    FreeAndNil(FWorker2);
  end;

  // Unsubscribe all
  FLogSubscription := nil;
  FProgressSubscription := nil;
  FDataSubscription := nil;
end;

procedure TfrmEventBusTest.LogToEventLog(const msg: string);
begin
  memoEventLog.Lines.Add(Format('[%s] %s', [FormatDateTime('hh:nn:ss.zzz', Now), msg]));
end;

procedure TfrmEventBusTest.UpdateSubscriptionCounts;
begin
  lblLogSubscriptions.Caption := Format('Subscriptions: %d',
    [EventBus.SubscriptionCount<TLogEvent>]);
  lblProgressSubscriptions.Caption := Format('Subscriptions: %d',
    [EventBus.SubscriptionCount<TProgressEvent>]);
  lblDataSubscriptions.Caption := Format('Subscriptions: %d',
    [EventBus.SubscriptionCount<TDataEvent>]);
end;

procedure TfrmEventBusTest.btnClearLogClick(Sender: TObject);
begin
  memoLog.Clear;
end;

procedure TfrmEventBusTest.btnClearEventsClick(Sender: TObject);
begin
  memoEventLog.Clear;
end;

procedure TfrmEventBusTest.btnFireLogInfoClick(Sender: TObject);
begin
  EventBus.Fire<TLogEvent>(TLogEvent.Create(llInfo, 'Info message from main thread'));
  LogToEventLog('Fired TLogEvent (Info)');
end;

procedure TfrmEventBusTest.btnFireLogWarningClick(Sender: TObject);
begin
  EventBus.Fire<TLogEvent>(TLogEvent.Create(llWarning, 'Warning message from main thread'));
  LogToEventLog('Fired TLogEvent (Warning)');
end;

procedure TfrmEventBusTest.btnFireLogErrorClick(Sender: TObject);
begin
  EventBus.Fire<TLogEvent>(TLogEvent.Create(llError, 'Error message from main thread'));
  LogToEventLog('Fired TLogEvent (Error)');
end;

procedure TfrmEventBusTest.btnSubscribeLogClick(Sender: TObject);
begin
  if assigned(FLogSubscription) then
  begin
    ShowMessage('Already subscribed to TLogEvent');
    Exit;
  end;

  FLogSubscription := EventBus.Subscribe<TLogEvent>(
    procedure(const evt: TLogEvent)
    begin
      // This executes in main thread - safe to update UI
      memoLog.SelStart := Length(memoLog.Text);
      memoLog.Lines.Add(Format('[%s] [Thread %d] [%s] %s',
        [FormatDateTime('hh:nn:ss.zzz', evt.Timestamp),
         evt.ThreadID,
         GetEnumName(TypeInfo(TLogLevel), Ord(evt.Level)),
         evt.Message]));
    end);

  LogToEventLog('Subscribed to TLogEvent (main thread)');
  UpdateSubscriptionCounts;
end;

procedure TfrmEventBusTest.btnUnsubscribeLogClick(Sender: TObject);
begin
  if not assigned(FLogSubscription) then
  begin
    ShowMessage('Not subscribed to TLogEvent');
    Exit;
  end;

  FLogSubscription.Unsubscribe;
  FLogSubscription := nil;
  LogToEventLog('Unsubscribed from TLogEvent');
  UpdateSubscriptionCounts;
end;

procedure TfrmEventBusTest.btnSubscribeProgressClick(Sender: TObject);
begin
  if assigned(FProgressSubscription) then
  begin
    ShowMessage('Already subscribed to TProgressEvent');
    Exit;
  end;

  FProgressSubscription := EventBus.Subscribe<TProgressEvent>(
    procedure(const evt: TProgressEvent)
    begin
      // Update progress bar and label in main thread
      ProgressBar1.Position := Round(evt.Percentage);
      lblProgress.Caption := Format('%s: %d/%d (%.1f%%)',
        [evt.TaskName, evt.Current, evt.Total, evt.Percentage]);
    end);

  LogToEventLog('Subscribed to TProgressEvent (main thread)');
  UpdateSubscriptionCounts;
end;

procedure TfrmEventBusTest.btnUnsubscribeProgressClick(Sender: TObject);
begin
  if not assigned(FProgressSubscription) then
  begin
    ShowMessage('Not subscribed to TProgressEvent');
    Exit;
  end;

  FProgressSubscription.Unsubscribe;
  FProgressSubscription := nil;
  LogToEventLog('Unsubscribed from TProgressEvent');
  UpdateSubscriptionCounts;
end;

procedure TfrmEventBusTest.btnSubscribeDataClick(Sender: TObject);
begin
  if assigned(FDataSubscription) then
  begin
    ShowMessage('Already subscribed to TDataEvent');
    Exit;
  end;

  FDataSubscription := EventBus.Subscribe<TDataEvent>(
    procedure(const evt: TDataEvent)
    begin
      // Update status bar in main thread
      StatusBar1.SimpleText := Format('Data: ID=%d, %s = %.2f',
        [evt.DataID, evt.Description, evt.Value]);
    end);

  LogToEventLog('Subscribed to TDataEvent (main thread)');
  UpdateSubscriptionCounts;
end;

procedure TfrmEventBusTest.btnUnsubscribeDataClick(Sender: TObject);
begin
  if not assigned(FDataSubscription) then
  begin
    ShowMessage('Not subscribed to TDataEvent');
    Exit;
  end;

  FDataSubscription.Unsubscribe;
  FDataSubscription := nil;
  LogToEventLog('Unsubscribed from TDataEvent');
  UpdateSubscriptionCounts;
end;

procedure TfrmEventBusTest.btnFireProgressClick(Sender: TObject);
var
  i: Integer;
begin
  for i := 1 to 10 do
  begin
    EventBus.Fire<TProgressEvent>(TProgressEvent.Create('Manual progress', i, 10));
    Application.ProcessMessages;
    Sleep(100);
  end;
  LogToEventLog('Fired 10 TProgressEvent events');
end;

procedure TfrmEventBusTest.btnFireDataClick(Sender: TObject);
var
  value: Double;
begin
  if not TryStrToFloat(edtDataValue.Text, value) then
  begin
    ShowMessage('Invalid number format');
    Exit;
  end;

  EventBus.Fire<TDataEvent>(TDataEvent.Create(Random(1000), 'Manual data', value));
  LogToEventLog(Format('Fired TDataEvent (value=%.2f)', [value]));
end;

procedure TfrmEventBusTest.btnStartWorker1Click(Sender: TObject);
begin
  if assigned(FWorker1) then
  begin
    ShowMessage('Worker 1 already running');
    Exit;
  end;

  memoWorker1.Clear;
  FWorker1 := TWorkerThread.Create('Worker-1', memoWorker1);
  FWorker1.Start;
  LogToEventLog('Started Worker Thread 1');
  UpdateSubscriptionCounts;
end;

procedure TfrmEventBusTest.btnStopWorker1Click(Sender: TObject);
begin
  if not assigned(FWorker1) then
  begin
    ShowMessage('Worker 1 not running');
    Exit;
  end;

  FWorker1.Stop;
  FWorker1.WaitFor;
  FreeAndNil(FWorker1);
  LogToEventLog('Stopped Worker Thread 1');
  UpdateSubscriptionCounts;
end;

procedure TfrmEventBusTest.btnStartWorker2Click(Sender: TObject);
begin
  if assigned(FWorker2) then
  begin
    ShowMessage('Worker 2 already running');
    Exit;
  end;

  memoWorker2.Clear;
  FWorker2 := TWorkerThread.Create('Worker-2', memoWorker2);
  FWorker2.Start;
  LogToEventLog('Started Worker Thread 2');
  UpdateSubscriptionCounts;
end;

procedure TfrmEventBusTest.btnStopWorker2Click(Sender: TObject);
begin
  if not assigned(FWorker2) then
  begin
    ShowMessage('Worker 2 not running');
    Exit;
  end;

  FWorker2.Stop;
  FWorker2.WaitFor;
  FreeAndNil(FWorker2);
  LogToEventLog('Stopped Worker Thread 2');
  UpdateSubscriptionCounts;
end;

procedure TfrmEventBusTest.btnStartProducerClick(Sender: TObject);
var
  interval_ms: Integer;
begin
  if assigned(FProducer) then
  begin
    ShowMessage('Producer already running');
    Exit;
  end;

  if not TryStrToInt(edtProducerInterval.Text, interval_ms) or (interval_ms < 100) then
  begin
    ShowMessage('Invalid interval (min 100ms)');
    Exit;
  end;

  FProducer := TEventProducerThread.Create(interval_ms);
  FProducer.Start;
  LogToEventLog(Format('Started Event Producer (interval=%dms)', [interval_ms]));
end;

procedure TfrmEventBusTest.btnStopProducerClick(Sender: TObject);
begin
  if not assigned(FProducer) then
  begin
    ShowMessage('Producer not running');
    Exit;
  end;

  FProducer.Stop;
  FProducer.WaitFor;
  FreeAndNil(FProducer);
  LogToEventLog('Stopped Event Producer');
end;

procedure TfrmEventBusTest.Timer1Timer(Sender: TObject);
begin
  UpdateSubscriptionCounts;
end;

end.
