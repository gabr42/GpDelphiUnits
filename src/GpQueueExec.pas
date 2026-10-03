///<summary>Queue anonymous procedure to a hidden window executing in a main thread.
///</summary>
///<author>Primoz Gabrijelcic</author>
///<remarks><para>
///   (c) 2026 Primoz Gabrijelcic
///   Free for personal and commercial use. No rights reserved.
///
///   Author            : Primoz Gabrijelcic
///   Creation date     : 2013-07-18
///   Last modification : 2026-05-04
///   Version           : 2.03a
///</para><para>
///   History:
///     2.03a: 2026-05-04
///       - Free unscheduled queued events when closing main TQueueExec object.
///     2.03: 2026-04-21
///       - Added After(owner: TComponent; timeout_ms; proc) overload. A pending call
///         scheduled with an owner is automatically cancelled if the owner is freed
///         before the timer fires. Use this when the deferred anonymous method
///         captures Self (or any other component) that may be destroyed during the
///         delay window. If the owner is already in csDestroying state at the time
///         of the call, the proc is not scheduled.
///       - Added CancelAfter(owner: TComponent) to cancel all pending After() calls
///         scheduled with a given owner.
///       - Added Queue(owner: TComponent; proc), Queue(owner, thread, proc) and
///         Queue(owner, threadID, proc) overloads. If the owner is freed before the
///         posted message is processed, the proc is silently skipped. The underlying
///         message cannot be retracted, so the TQueueProc object is freed when the
///         cancelled message is eventually picked up.
///       - Added CancelQueue(owner: TComponent) to cancel all pending Queue() calls
///         scheduled with a given owner.
///       - Owner-aware After() and Queue() calls and their cancellation must all be
///         issued from the main thread. The component FreeNotification machinery is
///         not thread-safe. Posted procs can still be processed by any registered
///         target thread - cancellation is delivered safely via a locked pending list.
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

  procedure After(timeout_ms: integer; proc: TProc); overload;
  procedure After(owner: TComponent; timeout_ms: integer; proc: TProc); overload;
  procedure CancelAfter(owner: TComponent);
  procedure Queue(proc: TProc); overload;
  procedure Queue(thread: TThread; proc: TProc); overload;
  procedure Queue(threadID: TThreadID; proc: TProc); overload;
  procedure Queue(owner: TComponent; proc: TProc); overload;
  procedure Queue(owner: TComponent; thread: TThread; proc: TProc); overload;
  procedure Queue(owner: TComponent; threadID: TThreadID; proc: TProc); overload;
  procedure CancelQueue(owner: TComponent);

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
    Proc     : TProc;
    Owner    : TComponent;
    Cancelled: boolean;
  end; { TQueueProc }

  TQueueExec = class;

  TAfterNotifier = class(TComponent)
  strict private
    FExec: TQueueExec;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(exec: TQueueExec); reintroduce;
  end; { TAfterNotifier }

  TQueueExec = class
  strict private type
    TTimerData = record
      TimerID: NativeUInt;
      Proc   : TProc;
      Owner  : TComponent;
      constructor Create(ATimerID: NativeUInt; AProc: TProc; AOwner: TComponent);
    end;
  strict private
    FHThreads    : TDictionary<TThreadID, HWND>;
    FNotifier    : TAfterNotifier;
    FPendingProcs: TList<TQueueProc>;
    FTimerID     : NativeUInt;
    FTimerData   : TList<TTimerData>;
  strict protected
    procedure DeallocateDeadThreadWindows;
    function  GetWindowForThreadID(threadID: TThreadID; autoCreate: boolean): HWND;
    procedure WndProc(var Message: TMessage);
  protected
    function  FindTimer(timerID: NativeUInt): integer;
    procedure HandleOwnerFreed(owner: TComponent);
  public
    constructor Create;
    destructor  Destroy; override;
    procedure After(timeout_ms: integer; proc: TProc); overload;
    procedure After(owner: TComponent; timeout_ms: integer; proc: TProc); overload;
    procedure CancelAfter(owner: TComponent);
    procedure CancelQueue(owner: TComponent);
    procedure Queue(proc: TProc); overload;
    procedure Queue(thread: TThread; proc: TProc); overload; inline;
    procedure Queue(threadID: TThreadID; proc: TProc); overload;
    procedure Queue(owner: TComponent; proc: TProc); overload;
    procedure Queue(owner: TComponent; thread: TThread; proc: TProc); overload; inline;
    procedure Queue(owner: TComponent; threadID: TThreadID; proc: TProc); overload;
    procedure RegisterQueueTarget;
    procedure UnregisterQueueTarget;
  end; { TQueueExec }

var
  GMsgExecuteProc: NativeUInt;

{ TQueueExec.TTimerData }

constructor TQueueExec.TTimerData.Create(ATimerID: NativeUInt; AProc: TProc; AOwner: TComponent);
begin
  TimerID := ATimerID;
  Proc    := AProc;
  Owner   := AOwner;
end; { TQueueExec.TTimerData.Create }

{ TAfterNotifier }

constructor TAfterNotifier.Create(exec: TQueueExec);
begin
  inherited Create(nil);
  FExec := exec;
end; { TAfterNotifier.Create }

procedure TAfterNotifier.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and assigned(FExec) then
    FExec.HandleOwnerFreed(AComponent);
end; { TAfterNotifier.Notification }

{ TQueueExec }

constructor TQueueExec.Create;
begin
  inherited Create;
  Assert(GetCurrentThreadID = MainThreadID);
  FTimerData := TList<TTimerData>.Create;
  FPendingProcs := TList<TQueueProc>.Create;
  FHThreads := TDictionary<TThreadID, HWND>.Create;
  FHThreads.Add(MainThreadID, DSiAllocateHwnd(WndProc));
  FNotifier := TAfterNotifier.Create(Self);
end; { TQueueExec.Create }

destructor TQueueExec.Destroy;
var
  mainWindow : HWND;
  pendingProc: TQueueProc;
  seenOwners : TList<TComponent>;
  threadData : TPair<TThreadID, HWND>;
  timerData  : TTimerData;
begin
  mainWindow := GetWindowForThreadID(MainThreadID, false);
  seenOwners := TList<TComponent>.Create;
  try
    for timerData in FTimerData do begin
      KillTimer(mainWindow, timerData.TimerID);
      if assigned(timerData.Owner) and (seenOwners.IndexOf(timerData.Owner) < 0) then
        seenOwners.Add(timerData.Owner);
    end;
    TMonitor.Enter(FPendingProcs);
    try
      for pendingProc in FPendingProcs do begin
        // Mark cancelled so any message still in a pump is skipped when picked up.
        // TQueueProc objects are freed by WndProc; orphans (if any messages survive
        // window teardown) leak at shutdown, as in prior versions.
        pendingProc.Cancelled := true;
        if assigned(pendingProc.Owner) and (seenOwners.IndexOf(pendingProc.Owner) < 0) then
          seenOwners.Add(pendingProc.Owner);
      end;
    finally TMonitor.Exit(FPendingProcs); end;
    for var owner in seenOwners do
      owner.RemoveFreeNotification(FNotifier);
  finally FreeAndNil(seenOwners); end;
  FreeAndNil(FTimerData);
  FreeAndNil(FNotifier);
  for threadData in FHThreads do
    DSIDeallocateHwnd(threadData.Value);
  for pendingProc in FPendingProcs do
    pendingProc.Free;
  FreeAndNil(FPendingProcs);
  FreeAndNil(FHThreads);
  inherited;
end; { TQueueExec.Destroy }

procedure TQueueExec.After(timeout_ms: integer; proc: TProc);
begin
  After(nil, timeout_ms, proc);
end; { TQueueExec.After }

procedure TQueueExec.After(owner: TComponent; timeout_ms: integer; proc: TProc);
begin
  Assert(GetCurrentThreadID = MainThreadID, 'TQueueExec.After can only be used from the main thread');
  if assigned(owner) and (csDestroying in owner.ComponentState) then
    Exit;
  Inc(FTimerID);
  FTimerData.Add(TTimerData.Create(FTimerID, proc, owner));
  if assigned(owner) then
    owner.FreeNotification(FNotifier);
  SetTimer(GetWindowForThreadID(MainThreadID, false), FTimerID, timeout_ms, nil);
end; { TQueueExec.After }

procedure TQueueExec.CancelAfter(owner: TComponent);
var
  cancelled : boolean;
  i         : integer;
  mainWindow: HWND;
begin
  Assert(GetCurrentThreadID = MainThreadID, 'TQueueExec.CancelAfter can only be used from the main thread');
  if not assigned(owner) then
    Exit;
  mainWindow := GetWindowForThreadID(MainThreadID, false);
  cancelled := false;
  for i := FTimerData.Count - 1 downto 0 do
    if FTimerData[i].Owner = owner then begin
      KillTimer(mainWindow, FTimerData[i].TimerID);
      FTimerData.Delete(i);
      cancelled := true;
    end;
  if cancelled then
    owner.RemoveFreeNotification(FNotifier);
end; { TQueueExec.CancelAfter }

procedure TQueueExec.CancelQueue(owner: TComponent);
var
  cancelled: boolean;
  i        : integer;
begin
  Assert(GetCurrentThreadID = MainThreadID, 'TQueueExec.CancelQueue can only be used from the main thread');
  if not assigned(owner) then
    Exit;
  cancelled := false;
  TMonitor.Enter(FPendingProcs);
  try
    for i := 0 to FPendingProcs.Count - 1 do
      if (FPendingProcs[i].Owner = owner) and not FPendingProcs[i].Cancelled then begin
        FPendingProcs[i].Cancelled := true;
        cancelled := true;
      end;
  finally TMonitor.Exit(FPendingProcs); end;
  if cancelled then
    owner.RemoveFreeNotification(FNotifier);
end; { TQueueExec.CancelQueue }

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
    if FTimerData[Result].TimerID = timerID then
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

procedure TQueueExec.HandleOwnerFreed(owner: TComponent);
var
  i         : integer;
  mainWindow: HWND;
begin
  // Invoked from TAfterNotifier.Notification while `owner` is being destroyed.
  // Do not call owner.RemoveFreeNotification here; owner clears its own list.
  mainWindow := GetWindowForThreadID(MainThreadID, false);
  for i := FTimerData.Count - 1 downto 0 do
    if FTimerData[i].Owner = owner then begin
      KillTimer(mainWindow, FTimerData[i].TimerID);
      FTimerData.Delete(i);
    end;
  TMonitor.Enter(FPendingProcs);
  try
    for i := 0 to FPendingProcs.Count - 1 do
      if FPendingProcs[i].Owner = owner then
        FPendingProcs[i].Cancelled := true;
  finally TMonitor.Exit(FPendingProcs); end;
end; { TQueueExec.HandleOwnerFreed }

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

procedure TQueueExec.Queue(owner: TComponent; proc: TProc);
begin
  Queue(owner, MainThreadID, proc);
end; { TQueueExec.Queue }

procedure TQueueExec.Queue(owner: TComponent; thread: TThread; proc: TProc);
begin
  Queue(owner, thread.ThreadID, proc);
end; { TQueueExec.Queue }

procedure TQueueExec.Queue(owner: TComponent; threadID: TThreadID; proc: TProc);
var
  procObj: TQueueProc;
begin
  Assert(GetCurrentThreadID = MainThreadID, 'TQueueExec.Queue(owner, ...) can only be used from the main thread');
  if assigned(owner) and (csDestroying in owner.ComponentState) then
    Exit;
  procObj := TQueueProc.Create;
  procObj.Proc := proc;
  procObj.Owner := owner;
  if assigned(owner) then begin
    TMonitor.Enter(FPendingProcs);
    try
      FPendingProcs.Add(procObj);
    finally TMonitor.Exit(FPendingProcs); end;
    owner.FreeNotification(FNotifier);
  end;
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
  cancelled: boolean;
  idx      : integer;
  procObj  : TQueueProc;
  timerData: TTimerData;
begin
  if Message.Msg = GMsgExecuteProc then begin
    procObj := TQueueProc(Message.WParam);
    if assigned(procObj) then begin
      cancelled := false;
      if assigned(procObj.Owner) then begin
        TMonitor.Enter(FPendingProcs);
        try
          cancelled := procObj.Cancelled;
          FPendingProcs.Remove(procObj);
        finally TMonitor.Exit(FPendingProcs); end;
      end;
      if not cancelled then
        procObj.Proc();
      procObj.Free;
    end;
  end
  else if Message.Msg = WM_TIMER then begin
    idx := FindTimer(TWMTimer(Message).TimerID);
    if idx >= 0 then begin
      timerData := FTimerData[idx];
      FTimerData.Delete(idx);
      KillTimer(GetWindowForThreadID(MainThreadID, false), timerData.TimerID);
      timerData.Proc();
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

procedure After(owner: TComponent; timeout_ms: integer; proc: TProc);
begin
  FQueueExec.After(owner, timeout_ms, proc);
end; { After }

procedure CancelAfter(owner: TComponent);
begin
  FQueueExec.CancelAfter(owner);
end; { CancelAfter }

procedure CancelQueue(owner: TComponent);
begin
  FQueueExec.CancelQueue(owner);
end; { CancelQueue }

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

procedure Queue(owner: TComponent; proc: TProc);
begin
  FQueueExec.Queue(owner, proc);
end; { Queue }

procedure Queue(owner: TComponent; thread: TThread; proc: TProc);
begin
  FQueueExec.Queue(owner, thread, proc);
end; { Queue }

procedure Queue(owner: TComponent; threadID: TThreadID; proc: TProc);
begin
  FQueueExec.Queue(owner, threadID, proc);
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
