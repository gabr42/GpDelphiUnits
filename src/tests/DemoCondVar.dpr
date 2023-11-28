program DemoCondVar;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.SyncObjs, System.Classes,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  {$IFDEF POSIX}
  Posix.SysTypes, Posix.Pthread, Posix.Signal,
  {$ENDIF}
  GpSync.CondVar;

var
  [volatile] countA: integer;
  [volatile] countB: integer;
  lcv: TLockConditionVariable;
  cv2: TLightweightCondVar;
  [volatile] stop: boolean;
  [volatile] numRunning: int64;
  [volatile] grabA, grabB: integer;
  [volatile] lockThread: TThreadID;

procedure CountEventsA;
begin
  TInterlocked.Increment(numRunning);
  while not stop do begin
    Sleep(Random(5));

    lcv.Acquire;
    try
      Assert(lockThread = 0);
      lockThread := TThread.Current.ThreadID;
      Inc(countA);
      lcv.Signal;
      lockThread := 0;
    finally lcv.Release; end;
  end;
  TInterlocked.Decrement(numRunning);
end;

procedure CountEventsB;
begin
  TInterlocked.Increment(numRunning);
  while not stop do begin
    Sleep(Random(50));

    lcv.Acquire;
    try
      Assert(lockThread = 0);
      lockThread := TThread.Current.ThreadID;
      Inc(countB);
      lcv.Signal;
      lockThread := 0;
    finally lcv.Release; end;
  end;
  TInterlocked.Decrement(numRunning);
end;

procedure ProcessEvents;
begin
  lcv.Acquire;
  try
    while not stop do begin
      if not lcv.TryWait(1000) then
        Write('.')
      else begin
        Assert(lockThread = 0);
        lockThread := TThread.Current.ThreadID;
        if countA > 0 then
          Write(StringOfChar('a', countA));
        countA := 0;
        if countB > 0 then
          Write(StringOfChar('b', countB));
        countB := 0;
        lockThread := 0;
      end;
      Write('/');
    end;
  finally lcv.Release; end;
end;

procedure TriggerPeek;
begin
  TInterlocked.Increment(numRunning);
  while not stop do begin
    Sleep(10);
    cv2.Signal;
  end;
  TInterlocked.Decrement(numRunning);
end;

procedure PeekEvents;
begin
  TInterlocked.Increment(numRunning);
  lcv.Acquire;
  try
    while not stop do begin
      if cv2.TryWait(lcv.Synchro^, 1000) then begin
        Assert(lockThread = 0);
        lockThread := TThread.Current.ThreadID;
        Inc(grabA, countA);
        Inc(grabB, countB);
        lockThread := 0;
      end;
    end;
  finally lcv.Release; end;
  TInterlocked.Decrement(numRunning);
end;

{$IFDEF MSWINDOWS}
function console_handler(dwCtrlType: DWORD): BOOL; stdcall;
begin
  stop := true;
  Result := true;
end;
{$ENDIF}

{$IFDEF POSIX}
procedure HandleSignals(sigNum: integer); cdecl;
begin
  stop := true;
end;
{$ENDIF}

begin
  try
    stop := false;
    {$IFDEF MSWINDOWS}
    SetConsoleCtrlHandler(@console_handler, true);
    {$ENDIF}
    {$IFDEF POSIX}
    signal(SIGINT, HandleSignals);
    {$ENDIF}

    countA := 0; countB := 0;
    grabA := 0; grabB := 0;
    lockThread := 0;
    TThread.CreateAnonymousThread(CountEventsA).Start;
    TThread.CreateAnonymousThread(CountEventsB).Start;
    TThread.CreateAnonymousThread(PeekEvents).Start;
    TThread.CreateAnonymousThread(TriggerPeek).Start;
    ProcessEvents;
    while TInterlocked.Read(numRunning) > 0 do
      Sleep(0);
    Writeln;
    Writeln('A: ', grabA);
    Writeln('B: ', grabB);
    Write('> ');
    Readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
