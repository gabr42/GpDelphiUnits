///<summary>Queue anonymous procedure to a hidden window executing in a main thread.
///</summary>
///<author>Primoz Gabrijelcic</author>
///<remarks><para>
///   (c) 2018 Primoz Gabrijelcic
///   Free for personal and commercial use. No rights reserved.
///
///   Author            : Primoz Gabrijelcic
///   Creation date     : 2013-07-18
///   Last modification : 2018-01-09
///   Version           : 2.02a
///</para><para>
///   History:
///     2.02a: 2018-01-09
///       - If a thread wants to receive queued procedures, it has to call
///         RegisterQueueTarget and UnregisterQueueTarget.
///     2.02: 2018-01-04
///       - Implemented Queue(TThread, TProc) and Queue(TThreadID, TProc) overloads which
///         queue directly to a specified thread.
///     2.01: 2017-01-26
///       - After() calls with overlaping times can be nested.
///     2.0: 2016-01-29
///       - Queue can be used from a background TThread-based thread.
///         In that case it will forward request to TThread.Queue.
///     1.01: 2014-08-26
///       - Implemented After function.
///     1.0: 2013-07-18
///       - Created.
///</para></remarks>

unit GpQueueExec;

interface

uses
  System.SysUtils, System.Classes;

  procedure After(timeout_ms: integer; proc: TProc);
  procedure Queue(proc: TProc); overload;
  procedure Queue(thread: TThread; proc: TProc); overload;
  procedure Queue(threadID: TThreadID; proc: TProc); overload;

  procedure RegisterQueueTarget;
  procedure UnregisterQueueTarget;

implementation

uses
  Winapi.Windows, Winapi.Messages, Winapi.TLHelp32,
  System.Generics.Collections,
  DSiWin32,
  GpLists;

type
  TQueueProc = class
    Proc: TProc;
  end; { TQueueProc }

  TQueueExec = class
  strict private type
    TTimerData = TPair<NativeUInt, TProc>;
  strict private
    FHThreads : TDictionary<TThreadID, HWND>;
    FTimerID  : NativeUInt;
    FTimerData: TList<TTimerData>;
  strict protected
    procedure DeallocateDeadThreadWindows;
    function  GetWindowForThreadID(threadID: TThreadID; autoCreate: boolean): HWND;
    procedure WndProc(var Message: TMessage);
  protected
    function FindTimer(timerID: NativeUInt): integer;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure After(timeout_ms: integer; proc: TProc);
    procedure Queue(proc: TProc); overload;
    procedure Queue(thread: TThread; proc: TProc); overload; inline;
    procedure Queue(threadID: TThreadID; proc: TProc); overload;
    procedure RegisterQueueTarget;
    procedure UnregisterQueueTarget;
  end; { TQueueExec }

var
  GMsgExecuteProc: NativeUInt;

{ TQueueExec }

constructor TQueueExec.Create;
begin
  inherited Create;
  Assert(GetCurrentThreadID = MainThreadID);
  FTimerData := TList<TTimerData>.Create;
  FHThreads := TDictionary<TThreadID, HWND>.Create;
  FHThreads.Add(MainThreadID, DSiAllocateHwnd(WndProc));
end; { TQueueExec.Create }

destructor TQueueExec.Destroy;
var
  mainWindow: HWND;
  threadData: TPair<TThreadID, HWND>;
  timerData : TTimerData;
begin
  mainWindow := GetWindowForThreadID(MainThreadID, false);
  for timerData in FTimerData do
    KillTimer(mainWindow, timerData.Key);
  FreeAndNil(FTimerData);
  for threadData in FHThreads do
    DSIDeallocateHwnd(threadData.Value);
  FreeAndNil(FHThreads);
  inherited;
end; { TQueueExec.Destroy }

procedure TQueueExec.After(timeout_ms: integer; proc: TProc);
begin
  Assert(GetCurrentThreadID = MainThreadID, 'TQueueExec.After can only be used from the main thread');
  Inc(FTimerID);
  FTimerData.Add(TTimerData.Create(FTimerID , proc));
  SetTimer(GetWindowForThreadID(MainThreadID, false), FTimerID, timeout_ms, nil);
end; { TQueueExec.After }

procedure TQueueExec.DeallocateDeadThreadWindows;
var
  hnd       : THandle;
  procID    : DWORD;
  removeList: TGpInt64List;
  te        : TThreadEntry32;
  thHnd     : THandle;
  threadList: TGpInt64List;
begin
  if FHThreads.Count = 0 then
    Exit;

  thHnd := CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
  if thHnd = INVALID_HANDLE_VALUE then
    Exit;

  procID := GetCurrentProcessId;
  try
    threadList := TGpInt64List.Create;
    try
      te.dwSize := SizeOf(te);
      if Thread32First(thHnd, te) then
      repeat
        if (te.dwSize >= (NativeUInt(@te.tpBasePri) - NativeUInt(@te.dwSize)))
           and (te.th32OwnerProcessID = procID)
        then
          threadList.Add(te.th32ThreadID);
       te.dwSize := SizeOf(te);
      until not Thread32Next(thHnd, te);

      threadList.Sort;
      removeList := TGpInt64List.Create;
      try
        for hnd in FHThreads.Keys do
          if not threadList.Contains(hnd) then
            removeList.Add(hnd);
        for hnd in removeList do begin
          DSiDeallocateHWnd(FHThreads[hnd]);
          FHThreads.Remove(hnd);
        end;
      finally FreeAndNil(removeList); end;
    finally FreeAndNil(threadList); end;
  finally CloseHandle(thHnd); end;
end; { TQueueExec.DeallocateDeadThreadWindows }

function TQueueExec.FindTimer(timerID: NativeUInt): integer;
begin
  for Result := 0 to FTimerData.Count - 1 do
    if FTimerData[Result].Key = timerID then
      Exit;

  Result := -1;
end; { TQueueExec.FindTimer }

function TQueueExec.GetWindowForThreadID(threadID: TThreadID; autoCreate: boolean): HWND;
begin
  TMonitor.Enter(FHThreads);
  try
    if not FHThreads.TryGetValue(threadID, Result) then begin
      if not autoCreate then
        raise Exception.CreateFmt('TQueueExec.GetWindowForThreadID: Receiver for thread %d is not created', [threadID]);
      DeallocateDeadThreadWindows;
      Result := DSiAllocateHWnd(WndProc);
      FHThreads.Add(threadID, Result);
    end;
  finally TMonitor.Exit(FHThreads); end;
end; { TQueueExec.GetWindowForThreadID }

procedure TQueueExec.Queue(proc: TProc);
begin
  Queue(MainThreadID, proc);
end; { TQueueExec.Queue }

procedure TQueueExec.Queue(thread: TThread; proc: TProc);
begin
  Queue(thread.ThreadID, proc);
end; { TQueueExec.Queue }

procedure TQueueExec.Queue(threadID: TThreadID; proc: TProc);
var
  procObj: TQueueProc;
begin
  procObj := TQueueProc.Create;
  procObj.Proc := proc;
  PostMessage(GetWindowForThreadID(threadID, false), GMsgExecuteProc, WParam(procObj), 0);
end; { TQueueExec.Queue }

procedure TQueueExec.RegisterQueueTarget;
begin
  GetWindowForThreadID(GetCurrentThreadID, true);
end; { TQueueExec.RegisterQueueTarget }

procedure TQueueExec.UnregisterQueueTarget;
var
  hWindow: HWND;
  thID   : TThreadID;
begin
  TMonitor.Enter(FHThreads);
  try
    thID := GetCurrentThreadID;
    if (thID <> MainThreadID) and FHThreads.TryGetValue(thID, hWindow) then begin
      DSiDeallocateHWnd(hWindow);
      FHThreads.Remove(thID);
    end;
  finally TMonitor.Exit(FHThreads); end;
end; { TQueueExec.UnregisterQueueTarget }

procedure TQueueExec.WndProc(var Message: TMessage);
var
  idx      : integer;
  procObj  : TQueueProc;
  timerData: TTimerData;
begin
  if Message.Msg = GMsgExecuteProc then begin
    procObj := TQueueProc(Message.WParam);
    if assigned(procObj) then begin
      procObj.Proc();
      procObj.Free;
    end;
  end
  else if Message.Msg = WM_TIMER then begin
    idx := FindTimer(TWMTimer(Message).TimerID);
    if idx >= 0 then begin
      timerData := FTimerData[idx];
      FTimerData.Delete(idx);
      KillTimer(GetWindowForThreadID(MainThreadID, false), timerData.Key);
      timerData.Value();
    end;
  end
  else
    Message.Result := DefWindowProc(GetWindowForThreadID(GetCurrentThreadID, false), Message.Msg, Message.WParam, Message.LParam);
end; { TQueueExec.WndProc }

var
  FQueueExec: TQueueExec;

procedure After(timeout_ms: integer; proc: TProc);
begin
  FQueueExec.After(timeout_ms, proc);
end; { After }

procedure Queue(proc: TProc);
begin
  FQueueExec.Queue(proc);
end; { Queue }

procedure Queue(thread: TThread; proc: TProc);
begin
  FQueueExec.Queue(thread, proc);
end; { Queue }

procedure Queue(threadID: TThreadID; proc: TProc);
begin
  FQueueExec.Queue(threadID, proc);
end; { Queue }

procedure RegisterQueueTarget;
begin
  FQueueExec.RegisterQueueTarget;
end; { RegisterQueueTarget }

procedure UnregisterQueueTarget;
begin
  FQueueExec.UnregisterQueueTarget;
end; { UnregisterQueueTarget }

initialization
  GMsgExecuteProc := RegisterWindowMessage('\Gp\QueueExec\DB2722C2-2B3E-4BED-B7BC-336FC76CE8FC\Execute');
  FQueueExec := TQueueExec.Create;
finalization
  FreeAndNil(FQueueExec);
end.
