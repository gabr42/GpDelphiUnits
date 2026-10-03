///<summary>Thread-safe event bus for cross-thread event dispatch using QueueUserAPC.</summary>
///<author>Claude (Anthropic AI), Primoz Gabrijelcic</author>
///<remarks><para>
///   (c) 2026 Primoz Gabrijelcic
///   Free for personal and commercial use. No rights reserved.
///
///   Author            : Claude (Anthropic AI), Primoz Gabrijelcic
///   Creation date     : 2026-02-12
///   Last modification : 2026-06-01
///   Version           : 1.07
///</para><para>
///   History:
///     1.07: 2026-06-01
///       - Fixed use-after-free / double-free crash under concurrent Fire +
///         rapid RegisterThread/UnregisterThread churn. RegisterThread opened
///         the subscriber thread handle with THREAD_SET_CONTEXT only (enough
///         for QueueUserAPC), but GetExitCodeThread requires
///         THREAD_QUERY_INFORMATION. Without it GetExitCodeThread always failed,
///         so DetectAndRemoveDeadThreads (and Destroy) took the failure branch
///         and misclassified every *live* registered thread as dead, freeing its
///         TThreadDispatchState while APCs were still in flight. The bug was
///         dormant in normal use (dead-thread detection only runs when a dispatch
///         fails) but lethal under high thread churn. Fix: open the handle with
///         THREAD_SET_CONTEXT or THREAD_QUERY_INFORMATION.
///     1.06: 2026-05-14
///       - Fixed permanent leak when a subscriber thread terminates without
///         calling UnregisterThread and without entering alertable wait. In
///         that case the pending APC in the thread's queue never fires, so
///         the AddRef from DispatchToBackgroundThread (the "APC ref") is
///         never balanced. DetectAndRemoveDeadThreads and Destroy now detect
///         this condition (APCSignaled=1 on a confirmed-dead thread) and
///         release the APC ref together with the bus's initial ref via a new
///         ReleaseRefs(count) helper that atomically subtracts both and calls
///         Free when the count reaches zero. The <= 0 guard in ReleaseRefs
///         also tolerates the edge case where the APC fired early (IsActive=
///         false, releasing its own ref) but left APCSignaled=1 unreset,
///         preventing a double-free in that scenario.
///     1.05: 2026-05-11
///       - Fixed remaining shutdown leak: a Fire in flight on a producer
///         thread could complete its QueueUserAPC after UnregisterThread had
///         already removed the state from FThreadStates, orphaning the APC's
///         AddRef when the subscriber thread terminated without re-entering
///         alertable wait. Fire now holds the read lock for the entire
///         cross-thread dispatch loop so UnregisterThread's BeginWrite waits
///         for in-flight dispatches to complete. Same-thread synchronous
///         handlers are deferred and invoked after EndRead so they can call
///         back into the bus without deadlocking on the non-recursive
///         SRWLock. Dispatch order: same-thread handlers now run after all
///         cross-thread dispatches in the same Fire call.
///       - DetectAndRemoveDeadThreads now drains each dead thread's
///         EventQueue before releasing the bus's ref. Defense in depth: if a
///         dead thread's state survives the Release (pinned by an APC that
///         was queued before the thread died and will never fire), its
///         captured event records are still freed.
///     1.04: 2026-05-04
///       - Fixed shutdown memory leak when subscriber thread terminates with
///         pending APCs (state, queued closures, and captured event records all
///         leaked because the AddRef from QueueUserAPC was never balanced).
///       - GetThreadState now AddRefs the returned state under the lock; Fire and
///         Subscribe Release it after use. Closes a use-after-free race between
///         Fire and UnregisterThread.
///       - UnregisterThread drains pending APCs via SleepEx(0, true) before
///         removing the thread state.
///       - Destroy drains each thread state's EventQueue so captured event records
///         (and their managed fields, e.g. IGpBuffer) are released.
///     1.03: 2026-03-19
///       - [DEBUG] UnregisterThread now raises an exception when the calling
///         thread was not previously registered.
///       - UnregisterThread is now a no-op when called from the main thread,
///         matching the existing RegisterThread behavior.
///     1.02: 2026-03-18
///       - RegisterThread now accepts an optional AThreadName parameter so callers
///         can supply the thread name explicitly (works in all Delphi versions).
///       - [DEBUG] APCProc warns (OutputDebugString + DebugBreak) when an APC fires
///         for a thread with no active subscriptions — detects missing UnregisterThread.
///       - [DEBUG] Destroy warns when a thread is still registered with no active
///         subscriptions at bus destruction — catches the same mistake without needing
///         a stale APC to fire.
///       - [DEBUG] Thread name included in all warnings; captured at RegisterThread
///         time via GetThreadDescription (Win10+ / Delphi 10.4+).
///     1.01: 2026-02-19
///       - Fixed crash when event bus is destroyed (or UnregisterThread called) while
///         APCs are still pending in a subscriber thread's APC queue.
///     1.0: 2026-02-13
///       - Initial release.
///       - Type-safe event bus with record-constrained events.
///       - Cross-thread dispatch via QueueUserAPC for background threads.
///       - TThread.Synchronize for main thread dispatch.
///       - Dead thread detection and cleanup.
///</para></remarks>

unit GpEventBus;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.TypInfo, System.SyncObjs,
  System.Generics.Collections,
  DSiWin32;

const
  CDefaultQueueDepth = 1024;

type
  /// Event handler signature: receives event data (must be a record type)
  TEventHandler<T: record> = reference to procedure(const eventData: T);

  /// Subscription handle for explicit unsubscribe and lifetime management
  IEventSubscription = interface
    ['{E8F9A2C1-4B3D-4E2F-9F1A-5D6E8C9B2A1F}']
    function  GetThreadID: TThreadID;
    function  IsActive: boolean;
    procedure Unsubscribe;
    property ThreadID: TThreadID read GetThreadID;
  end;

  /// Core event bus class (not interface - Delphi interfaces cannot have generic methods)
  TEventBus = class
  strict private
    type
      TSubscriptionRecord = record
        EventBus      : TEventBus;
        Handler       : IInterface;  // Stores TEventHandler<T> as interface to keep it alive
        SubscriptionID: TGUID;
        ThreadHandle  : THandle;
        ThreadID      : TThreadID;
      end;

      TThreadDispatchState = class
      strict private
        FBusAlive: integer;  // 1 = bus alive, 0 = bus gone; written/read via TInterlocked
        FRefCount: integer;
      public
        APCSignaled : integer;
        EventQueue  : TThreadedQueue<TProc>;
        ThreadHandle: THandle;
        ThreadID    : TThreadID;
        {$IFDEF DEBUG}
        SubscriptionCount: integer;  // Active subscription count; 0 = UnregisterThread forgotten
        ThreadName       : string;   // Captured at RegisterThread time for diagnostic messages
        {$ENDIF}
        constructor Create(AThreadID: TThreadID; AThreadHandle: THandle; AQueueDepth: integer);
        destructor  Destroy; override;
        procedure AddRef;
        procedure Deactivate;  // Called by bus on shutdown; signals APCProc to exit early
        function  IsActive: boolean;  // APCProc checks this before processing the queue
        procedure Release;
        procedure ReleaseRefs(count: integer);  // Atomically release count refs; free when total hits 0
      end;

      TSubscriptionList = class
      strict private
        FLock         : TLightweightMREW;
        FSubscriptions: TList<TSubscriptionRecord>;
        FTypeInfo     : PTypeInfo;
      public
        constructor Create(ATypeInfo: PTypeInfo);
        destructor  Destroy; override;
        function  Count: integer;
        function  GetActiveSubscriptions: TArray<TSubscriptionRecord>;
        procedure Add(const subscription: TSubscriptionRecord);
        procedure Remove(const subscriptionID: TGUID);
        procedure RemoveDeadThreads(const deadThreadIDs: TArray<TThreadID>);
        {$IFDEF DEBUG}
        function  GetSubscriptionThreadID(const subscriptionID: TGUID): TThreadID;
        {$ENDIF}
      end;

  strict private
    FLock         : TLightweightMREW;
    FQueueDepth   : integer;
    FSubscriptions: TDictionary<PTypeInfo, TSubscriptionList>;
    FThreadStates : TDictionary<TThreadID, TThreadDispatchState>;

    procedure DetectAndRemoveDeadThreads;
    procedure DispatchToBackgroundThread(const state: TThreadDispatchState; const proc: TProc);
    procedure DispatchToMainThread(const proc: TProc);
    function  GetOrCreateSubscriptionList(ATypeInfo: PTypeInfo): TSubscriptionList;
    function  GetThreadState(threadID: TThreadID): TThreadDispatchState;
    function  MakeCallback<T: record>(handler: TEventHandler<T>; const eventData: T): TProc;
    class procedure APCProc(dwParam: UIntPtr); stdcall; static;
  public
    constructor Create(AQueueDepth: integer = CDefaultQueueDepth);
    destructor  Destroy; override;

    procedure Fire<T: record>(const eventData: T);
    procedure RegisterThread(const AThreadName: string = '');
    procedure RemoveSubscription(ATypeInfo: PTypeInfo; const subscriptionID: TGUID);
    function  Subscribe<T: record>(const handler: TEventHandler<T>): IEventSubscription;
    function  SubscriptionCount<T: record>: integer;
    procedure UnregisterThread;
    procedure UnsubscribeAll<T: record>;
  end;

  TEventSubscription = class(TInterfacedObject, IEventSubscription)
  strict private
    FActive        : integer;  // 0=inactive, 1=active (for TInterlocked operations)
    FEventBus      : TEventBus;
    FSubscriptionID: TGUID;
    FThreadID      : TThreadID;
    FTypeInfo      : PTypeInfo;
  public
    constructor Create(AEventBus: TEventBus; ATypeInfo: PTypeInfo; const ASubscriptionID: TGUID; AThreadID: TThreadID);
    function  GetThreadID: TThreadID;
    function  IsActive: boolean;
    procedure Unsubscribe;
  end;

  function CreateEventBus(AQueueDepth: integer = CDefaultQueueDepth): TEventBus;
  function EventBus: TEventBus;

implementation

uses
  System.Rtti
  {$IFDEF DEBUG}
  , GpEventBus.AlertableWaitMonitor
  {$ENDIF}
  ;

var
  GEventBus    : TEventBus;
  GEventBusLock: TLightweightMREW;

{ TEventBus.TThreadDispatchState }

constructor TEventBus.TThreadDispatchState.Create(AThreadID: TThreadID; AThreadHandle: THandle; AQueueDepth: integer);
begin
  inherited Create;
  ThreadID := AThreadID;
  ThreadHandle := AThreadHandle;
  EventQueue := TThreadedQueue<TProc>.Create(AQueueDepth, 100, 0);
  APCSignaled := 0;
  FBusAlive := 1;  // Bus is alive at creation
  FRefCount := 1;  // Initial ref for the bus
end; { TEventBus.TThreadDispatchState.Create }

destructor TEventBus.TThreadDispatchState.Destroy;
begin
  if assigned(EventQueue) then
    FreeAndNil(EventQueue);
  if ThreadHandle <> 0 then begin
    CloseHandle(ThreadHandle);
    ThreadHandle := 0;
  end;
  inherited;
end; { TEventBus.TThreadDispatchState.Destroy }

procedure TEventBus.TThreadDispatchState.AddRef;
begin
  TInterlocked.Increment(FRefCount);
end; { TEventBus.TThreadDispatchState.AddRef }

procedure TEventBus.TThreadDispatchState.Deactivate;
begin
  TInterlocked.Exchange(FBusAlive, 0);
end; { TEventBus.TThreadDispatchState.Deactivate }

function TEventBus.TThreadDispatchState.IsActive: boolean;
begin
  Result := TInterlocked.CompareExchange(FBusAlive, 0, 0) = 1;
end; { TEventBus.TThreadDispatchState.IsActive }

procedure TEventBus.TThreadDispatchState.Release;
begin
  if TInterlocked.Decrement(FRefCount) = 0 then
    Free;
end; { TEventBus.TThreadDispatchState.Release }

procedure TEventBus.TThreadDispatchState.ReleaseRefs(count: integer);
begin
  // Atomically subtract `count` refs and free when the total reaches zero.
  // Using <= 0 rather than = 0 so that a stale APCSignaled=1 (set by an APC
  // that fired early due to IsActive=false and released its ref, but did not
  // reset APCSignaled) causes exactly one Free rather than a permanent leak.
  if TInterlocked.Add(FRefCount, -count) <= 0 then
    Free;
end; { TEventBus.TThreadDispatchState.ReleaseRefs }

{ TEventSubscription }

constructor TEventSubscription.Create(AEventBus: TEventBus; ATypeInfo: PTypeInfo; const ASubscriptionID: TGUID; AThreadID: TThreadID);
begin
  inherited Create;
  FEventBus := AEventBus;
  FTypeInfo := ATypeInfo;
  FSubscriptionID := ASubscriptionID;
  FThreadID := AThreadID;
  FActive := 1;  // Active
end; { TEventSubscription.Create }

procedure TEventSubscription.Unsubscribe;
begin
  // Thread-safe: only one thread will successfully transition from 1 (active) to 0 (inactive)
  if (TInterlocked.CompareExchange(FActive, 0, 1) = 1) and assigned(FEventBus) then
    FEventBus.RemoveSubscription(FTypeInfo, FSubscriptionID);
end; { TEventSubscription.Unsubscribe }

function TEventSubscription.IsActive: boolean;
begin
  // Use CompareExchange with no change to atomically read the value
  Result := TInterlocked.CompareExchange(FActive, 0, 0) = 1;
end; { TEventSubscription.IsActive }

function TEventSubscription.GetThreadID: TThreadID;
begin
  Result := FThreadID;
end; { TEventSubscription.GetThreadID }

{ TEventBus.TSubscriptionList }

constructor TEventBus.TSubscriptionList.Create(ATypeInfo: PTypeInfo);
begin
  inherited Create;
  FTypeInfo := ATypeInfo;
  FSubscriptions := TList<TSubscriptionRecord>.Create;
end; { TEventBus.TSubscriptionList.Create }

destructor TEventBus.TSubscriptionList.Destroy;
begin
  FreeAndNil(FSubscriptions);
  inherited;
end; { TEventBus.TSubscriptionList.Destroy }

procedure TEventBus.TSubscriptionList.Add(const subscription: TSubscriptionRecord);
begin
  FLock.BeginWrite;
  try
    FSubscriptions.Add(subscription);
  finally FLock.EndWrite; end;
end; { TEventBus.TSubscriptionList.Add }

procedure TEventBus.TSubscriptionList.Remove(const subscriptionID: TGUID);
var
  i: integer;
begin
  FLock.BeginWrite;
  try
    for i := FSubscriptions.Count-1 downto 0 do
      if IsEqualGUID(FSubscriptions[i].SubscriptionID, subscriptionID) then begin
        FSubscriptions.Delete(i);
        Break;
      end;
  finally FLock.EndWrite; end;
end; { TEventBus.TSubscriptionList.Remove }

function TEventBus.TSubscriptionList.GetActiveSubscriptions: TArray<TSubscriptionRecord>;
begin
  FLock.BeginRead;
  try
    Result := FSubscriptions.ToArray;
  finally FLock.EndRead; end;
end; { TEventBus.TSubscriptionList.GetActiveSubscriptions }

procedure TEventBus.TSubscriptionList.RemoveDeadThreads(const deadThreadIDs: TArray<TThreadID>);
var
  i       : integer;
  threadID: TThreadID;
begin
  if Length(deadThreadIDs) = 0 then
    Exit;

  FLock.BeginWrite;
  try
    for i := FSubscriptions.Count-1 downto 0 do
      for threadID in deadThreadIDs do
        if FSubscriptions[i].ThreadID = threadID then begin
          FSubscriptions.Delete(i);
          Break;
        end;
  finally FLock.EndWrite; end;
end; { TEventBus.TSubscriptionList.RemoveDeadThreads }

{$IFDEF DEBUG}
function TEventBus.TSubscriptionList.GetSubscriptionThreadID(const subscriptionID: TGUID): TThreadID;
var
  i: integer;
begin
  Result := 0;
  FLock.BeginRead;
  try
    for i := 0 to FSubscriptions.Count-1 do
      if IsEqualGUID(FSubscriptions[i].SubscriptionID, subscriptionID) then
        Exit(FSubscriptions[i].ThreadID);
  finally FLock.EndRead; end;
end; { TEventBus.TSubscriptionList.GetSubscriptionThreadID }
{$ENDIF}

function TEventBus.TSubscriptionList.Count: integer;
begin
  FLock.BeginRead;
  try
    Result := FSubscriptions.Count;
  finally FLock.EndRead; end;
end; { TEventBus.TSubscriptionList.Count }

{ TEventBus }

constructor TEventBus.Create(AQueueDepth: integer);
begin
  inherited Create;
  FQueueDepth := AQueueDepth;
  FSubscriptions := TDictionary<PTypeInfo, TSubscriptionList>.Create;
  FThreadStates := TDictionary<TThreadID, TThreadDispatchState>.Create;
end; { TEventBus.Create }

destructor TEventBus.Destroy;
var
  list : TSubscriptionList;
  proc : TProc;
  state: TThreadDispatchState;
begin
  for list in FSubscriptions.Values do
    list.Free;
  FreeAndNil(FSubscriptions);

  {$IFDEF DEBUG}
  for state in FThreadStates.Values do
    if TInterlocked.CompareExchange(state.SubscriptionCount, 0, 0) = 0 then begin
      OutputDebugString(PChar(Format(
        'TEventBus [DEBUG] Thread %d (%s): bus destroyed with thread still registered ' +
        'but no active subscriptions. Probable cause: Unsubscribe was called ' +
        'without calling UnregisterThread.',
        [state.ThreadID, state.ThreadName])));
      DebugBreak;
    end;
  {$ENDIF}

  for state in FThreadStates.Values do begin
    state.Deactivate;  // Signal to any pending APCProc calls that bus is gone
    // Drain any queued closures so their captured records (and resources held by
    // managed fields, e.g. IGpBuffer) are released even if the state itself is
    // pinned by a never-firing APC's outstanding AddRef. PopTimeout=0 makes
    // PopItem return wrTimeout immediately on empty queue. Do NOT call
    // DoShutDown — once shut down, PopItem incorrectly returns wrSignaled with
    // a default item on an empty queue (RTL behavior at PopItem in
    // System.Generics.Collections.pas), which would spin forever.
    while state.EventQueue.PopItem(proc) = wrSignaled do
      ; // proc auto-released at next assignment / loop exit
    // If the subscriber thread terminated without calling UnregisterThread and
    // without entering alertable wait, its pending APC will never fire, leaving
    // the AddRef from DispatchToBackgroundThread permanently unbalanced. Check
    // the thread's exit code: if it is dead, reclaim the APC ref together with
    // the bus's initial ref in one atomic operation. For live threads, leave
    // FRefCount=1; the APC will fire when the thread next enters alertable wait
    // (IsActive=false causes APCProc to exit early and release its ref via the
    // finally block), at which point FRefCount drops to 0 and the state is freed.
    var extraRefs := 0;
    if TInterlocked.CompareExchange(state.APCSignaled, 0, 0) = 1 then begin
      var exitCode: DWORD;
      if not GetExitCodeThread(state.ThreadHandle, exitCode) or (exitCode <> STILL_ACTIVE) then
        if TInterlocked.Exchange(state.APCSignaled, 0) = 1 then
          extraRefs := 1;
    end;
    state.ReleaseRefs(1 + extraRefs);
  end;
  FreeAndNil(FThreadStates);

  inherited;
end; { TEventBus.Destroy }

function TEventBus.GetOrCreateSubscriptionList(ATypeInfo: PTypeInfo): TSubscriptionList;
begin
  FLock.BeginRead;
  try
    if FSubscriptions.TryGetValue(ATypeInfo, Result) then
      Exit;
  finally FLock.EndRead; end;

  FLock.BeginWrite;
  try
    if not FSubscriptions.TryGetValue(ATypeInfo, Result) then begin
      Result := TSubscriptionList.Create(ATypeInfo);
      FSubscriptions.Add(ATypeInfo, Result);
    end;
  finally FLock.EndWrite; end;
end; { TEventBus.GetOrCreateSubscriptionList }

function TEventBus.GetThreadState(threadID: TThreadID): TThreadDispatchState;
begin
  FLock.BeginRead;
  try
    if not FThreadStates.TryGetValue(threadID, Result) then
      raise Exception.CreateFmt('TEventBus.GetThreadState: Thread %d is not registered. Call RegisterThread before subscribing.', [threadID]);
    Result.AddRef;
  finally FLock.EndRead; end;
end; { TEventBus.GetThreadState }

{$IFDEF DEBUG}
function GetCurrentThreadName: string;
// Reads the thread description set via SetThreadDescription (Win10 1607+ / Delphi 10.4+).
// Returns empty string if the API is unavailable or no name was set.
var
  name: PWideChar;
begin
  Result := '';
  name := nil;
  if Succeeded(DSiGetThreadDescription(GetCurrentThread, name)) and assigned(name) then begin
    Result := string(name);
    LocalFree(HLOCAL(Pointer(name)));
  end;
end; { GetCurrentThreadName }
{$ENDIF}

procedure TEventBus.RegisterThread(const AThreadName: string = '');
var
  state       : TThreadDispatchState;
  threadHandle: THandle;
  threadID    : TThreadID;
begin
  threadID := GetCurrentThreadId;
  if threadID = MainThreadID then
    Exit;

  FLock.BeginRead;
  try
    if FThreadStates.ContainsKey(threadID) then
      Exit;
  finally FLock.EndRead; end;

  // THREAD_SET_CONTEXT is required by QueueUserAPC; THREAD_QUERY_INFORMATION is
  // required by GetExitCodeThread (used by DetectAndRemoveDeadThreads/Destroy).
  // Without the query right GetExitCodeThread fails, and dead-thread detection
  // would misclassify every live thread as dead and free its state while APCs
  // are still in flight (use-after-free / double-free under concurrent dispatch).
  threadHandle := DSiOpenThread(THREAD_SET_CONTEXT or THREAD_QUERY_INFORMATION, false, threadID);
  if threadHandle = 0 then
    raise Exception.CreateFmt('TEventBus.RegisterThread: Failed to open thread handle for thread %d. OS error %d: %s',
      [threadID, Winapi.Windows.GetLastError, SysErrorMessage(Winapi.Windows.GetLastError)]);

  FLock.BeginWrite;
  try
    if not FThreadStates.ContainsKey(threadID) then begin
      state := TThreadDispatchState.Create(threadID, threadHandle, FQueueDepth);
      FThreadStates.Add(threadID, state);

      {$IFDEF DEBUG}
      if AThreadName <> '' then
        state.ThreadName := AThreadName
      else
        state.ThreadName := GetCurrentThreadName;
      // Queue alertable wait test for this thread
      TAlertableWaitMonitor.GetInstance.QueueTest(threadID);
      {$ENDIF}
    end
    else
      CloseHandle(threadHandle);
  finally FLock.EndWrite; end;
end; { TEventBus.RegisterThread }

procedure TEventBus.UnregisterThread;
var
  list    : TSubscriptionList;
  state   : TThreadDispatchState;
  threadID: TThreadID;
begin
  threadID := GetCurrentThreadId;
  if threadID = MainThreadID then
    Exit;

  FLock.BeginWrite;
  try
    if FThreadStates.TryGetValue(threadID, state) then begin
      state.Deactivate;  // Signal to any pending APCProc calls that bus is gone
      state.Release;     // Release bus's ref; state freed here if no APCs pending
      SleepEx(0, true);  // Clean up pending APCs
      FThreadStates.Remove(threadID);
    end
    {$IFDEF DEBUG}
    else
      raise Exception.CreateFmt(
        'TEventBus.UnregisterThread: Thread %d (%s) was not registered.',
        [threadID, GetCurrentThreadName]);
    {$ENDIF}
  finally FLock.EndWrite; end;

  FLock.BeginRead;
  try
    for list in FSubscriptions.Values do
      list.RemoveDeadThreads([threadID]);
  finally FLock.EndRead; end;
end; { TEventBus.UnregisterThread }

procedure TEventBus.DispatchToMainThread(const proc: TProc);
begin
  TThread.Queue(nil,
    procedure
    begin
      proc;
    end);
end; { TEventBus.DispatchToMainThread }

procedure TEventBus.DispatchToBackgroundThread(const state: TThreadDispatchState; const proc: TProc);
begin
  var pushResult := state.EventQueue.PushItem(proc);
  if pushResult <> wrSignaled then
    raise Exception.CreateFmt('TEventBus.DispatchToBackgroundThread: Failed to push event to the queue. Error status: %d',
      [Ord(pushResult)]);
  var oldValue := TInterlocked.Exchange(state.APCSignaled, 1);
  if oldValue = 0 then begin
    state.AddRef;  // Ref for the pending APC; released in APCProc's finally
    if not QueueUserAPC(@TEventBus.APCProc, state.ThreadHandle, UIntPtr(NativeUInt(state))) then begin
      TInterlocked.Exchange(state.APCSignaled, 0);
      state.Release;  // APC queue failed; undo the AddRef
      raise Exception.CreateFmt('TEventBus.DispatchToBackgroundThread: Failed to queue APC to thread %d. OS error %d: %s',
        [state.ThreadID, Winapi.Windows.GetLastError, SysErrorMessage(Winapi.Windows.GetLastError)]);
    end;
  end;
end; { TEventBus.DispatchToBackgroundThread }

class procedure TEventBus.APCProc(dwParam: UIntPtr); stdcall;
var
  proc    : TProc;
  state   : TThreadDispatchState;
  threadID: TThreadID;
begin
  state := TThreadDispatchState(Pointer(dwParam));
  try
    // Bus is gone (destroyed or UnregisterThread called): exit without touching it
    if not state.IsActive then
      Exit;

    {$IFDEF DEBUG}
    if TInterlocked.CompareExchange(state.SubscriptionCount, 0, 0) = 0 then begin
      OutputDebugString(PChar(Format(
        'TEventBus [DEBUG] Thread %d (%s): APC fired but no active subscriptions remain. ' +
        'Probable cause: Unsubscribe was called without calling UnregisterThread.',
        [state.ThreadID, state.ThreadName])));
      DebugBreak;
    end;
    {$ENDIF}

    threadID := GetCurrentThreadId;

    // Process all queued items
    while state.EventQueue.PopItem(proc) = TWaitResult.wrSignaled do begin
      try
        proc();
      except
        on E: Exception do
          OutputDebugString(PChar(Format('TEventBus.APCProc: Exception in thread %d: %s', [threadID, E.Message])));
      end;
    end;

    TInterlocked.Exchange(state.APCSignaled, 0);

    // CRITICAL: Check if items were added during processing.
    // If so, we need to queue another APC since those items saw APCSignaled=1.
    if state.EventQueue.QueueSize > 0 then begin
      state.AddRef;  // Ref for the new APC; released in that APC's finally
      var oldValue := TInterlocked.Exchange(state.APCSignaled, 1);
      if oldValue = 0 then begin
        if not QueueUserAPC(@TEventBus.APCProc, state.ThreadHandle, dwParam) then begin
          TInterlocked.Exchange(state.APCSignaled, 0);
          state.Release;  // Failed to re-queue; undo the AddRef
          OutputDebugString(PChar(Format('TEventBus.APCProc: Failed to re-queue APC for thread %d. OS error %d: %s',
            [state.ThreadID, Winapi.Windows.GetLastError, SysErrorMessage(Winapi.Windows.GetLastError)])));
        end;
      end
      else
        state.Release;  // Another APC already pending; undo the AddRef
    end;
  finally
    state.Release;  // Release this APC's ref (added in DispatchToBackgroundThread)
  end;
end; { TEventBus.APCProc }

procedure TEventBus.DetectAndRemoveDeadThreads;
var
  deadThreads: TList<TThreadID>;
  exitCode   : DWORD;
  list       : TSubscriptionList;
  pair       : TPair<TThreadID, TThreadDispatchState>;
  proc       : TProc;
  state      : TThreadDispatchState;
  threadID   : TThreadID;
begin
  deadThreads := TList<TThreadID>.Create;
  try
    FLock.BeginRead;
    try
      for pair in FThreadStates do begin
        state := pair.Value;
        if GetExitCodeThread(state.ThreadHandle, exitCode) then begin
          if exitCode <> STILL_ACTIVE then
            deadThreads.Add(state.ThreadID);
        end
        else
          deadThreads.Add(state.ThreadID);
      end;
    finally FLock.EndRead; end;

    if deadThreads.Count = 0 then
      Exit;

    FLock.BeginWrite;
    try
      for threadID in deadThreads do begin
        if FThreadStates.TryGetValue(threadID, state) then begin
          state.Deactivate;  // Signal to any pending APCProc calls that bus is gone
          // Drain queued closures so captured records (e.g. IGpBuffer) are
          // freed even if the state itself is pinned by the APC ref below.
          while state.EventQueue.PopItem(proc) = wrSignaled do
            ;
          // The thread is confirmed dead: any QueueUserAPC that succeeded will
          // never deliver its APC (dead threads never enter alertable wait).
          // If APCSignaled=1, the corresponding AddRef from DispatchToBackground-
          // Thread has never been balanced. Release that ref together with the
          // bus's initial ref in a single atomic subtraction so Free is called
          // at most once regardless of whether the APC had already fired.
          var extraRefs := 0;
          if TInterlocked.Exchange(state.APCSignaled, 0) = 1 then
            extraRefs := 1;
          state.ReleaseRefs(1 + extraRefs);
          FThreadStates.Remove(threadID);
        end;
      end;
    finally FLock.EndWrite; end;

    FLock.BeginRead;
    try
      for list in FSubscriptions.Values do
        list.RemoveDeadThreads(deadThreads.ToArray);
    finally FLock.EndRead; end;
  finally deadThreads.Free; end;
end; { TEventBus.DetectAndRemoveDeadThreads }

function TEventBus.Subscribe<T>(const handler: TEventHandler<T>): IEventSubscription;
var
  list        : TSubscriptionList;
  state       : TThreadDispatchState;
  subscription: TSubscriptionRecord;
  threadID    : TThreadID;
  typeInfo    : PTypeInfo;
begin
  typeInfo := System.TypeInfo(T);
  threadID := GetCurrentThreadId;

  if threadID <> MainThreadID then begin
    FLock.BeginRead;
    try
      if not FThreadStates.ContainsKey(threadID) then
        raise Exception.CreateFmt('TEventBus.Subscribe: Background thread %d must call RegisterThread before subscribing.', [threadID]);
    finally FLock.EndRead; end;
  end;

  list := GetOrCreateSubscriptionList(typeInfo);

  subscription.ThreadID := threadID;
  subscription.EventBus := Self;
  CreateGUID(subscription.SubscriptionID);
  // Store handler as IInterface to keep it alive via reference counting
  subscription.Handler := IInterface(Pointer(@handler)^);

  if threadID = MainThreadID then
    subscription.ThreadHandle := 0
  else begin
    state := GetThreadState(threadID);
    try
      subscription.ThreadHandle := state.ThreadHandle;
    finally state.Release; end;
  end;

  list.Add(subscription);

  {$IFDEF DEBUG}
  if threadID <> MainThreadID then
    TInterlocked.Increment(state.SubscriptionCount);
  {$ENDIF}

  Result := TEventSubscription.Create(Self, typeInfo, subscription.SubscriptionID, threadID);
end; { TEventBus.Subscribe }

function TEventBus.MakeCallback<T>(handler: TEventHandler<T>; const eventData: T): TProc;
begin
  Result :=
    procedure
    begin
      handler(eventData);
    end;
end; { TEventBus.MakeCallback }

procedure TEventBus.Fire<T>(const eventData: T);
var
  dispatchFailed: boolean;
  list          : TSubscriptionList;
  state         : TThreadDispatchState;
  sub           : TSubscriptionRecord;
  subscriptions : TArray<TSubscriptionRecord>;
  typeInfo      : PTypeInfo;
  currentThread : TThreadID;
begin
  typeInfo := System.TypeInfo(T);
  currentThread := GetCurrentThreadId;
  dispatchFailed := false;

  // Hold the read lock for the entire cross-thread dispatch loop. This blocks
  // UnregisterThread (which needs BeginWrite) from racing past a producer that
  // has snapshotted the subscriber list but not yet completed QueueUserAPC.
  // Without this, the AddRef from a late QueueUserAPC can be orphaned when the
  // subscriber thread terminates before the APC fires. Same-thread subscribers
  // are deferred and invoked after EndRead so handlers can freely call back
  // into the bus without deadlocking on the non-recursive SRWLock.
  FLock.BeginRead;
  try
    if not FSubscriptions.TryGetValue(typeInfo, list) then
      Exit;

    subscriptions := list.GetActiveSubscriptions;

    for sub in subscriptions do begin
      if sub.ThreadID = currentThread then
        Continue  // deferred: invoked after EndRead in subscription order
      else if sub.ThreadID = MainThreadID then begin
        DispatchToMainThread(MakeCallback<T>(TEventHandler<T>(sub.Handler), eventData));
      end
      else begin
        try
          // Inline of GetThreadState — SRWLock is non-recursive, so we cannot
          // call the public helper (which would re-enter BeginRead) here.
          if not FThreadStates.TryGetValue(sub.ThreadID, state) then begin
            dispatchFailed := true;
            Continue;
          end;
          state.AddRef;
          try
            DispatchToBackgroundThread(state, MakeCallback<T>(TEventHandler<T>(sub.Handler), eventData));
          finally state.Release; end;
        except
          on E: Exception do begin
            dispatchFailed := true;
            OutputDebugString(PChar(Format('TEventBus.Fire: Dispatch failed for thread %d: %s', [sub.ThreadID, E.Message])));
          end;
        end;
      end;
    end;
  finally FLock.EndRead; end;

  // Same-thread synchronous dispatch: run outside the lock so handlers can
  // safely call Fire / Subscribe / UnregisterThread on this bus.
  for sub in subscriptions do
    if sub.ThreadID = currentThread then
      TEventHandler<T>(sub.Handler)(eventData);

  if dispatchFailed then
    DetectAndRemoveDeadThreads;
end; { TEventBus.Fire }

procedure TEventBus.UnsubscribeAll<T>;
var
  list    : TSubscriptionList;
  typeInfo: PTypeInfo;
begin
  typeInfo := System.TypeInfo(T);

  FLock.BeginWrite;
  try
    if FSubscriptions.TryGetValue(typeInfo, list) then begin
      FSubscriptions.Remove(typeInfo);
      list.Free;
    end;
  finally FLock.EndWrite; end;
end; { TEventBus.UnsubscribeAll }

function TEventBus.SubscriptionCount<T>: integer;
var
  list    : TSubscriptionList;
  typeInfo: PTypeInfo;
begin
  typeInfo := System.TypeInfo(T);

  FLock.BeginRead;
  try
    if FSubscriptions.TryGetValue(typeInfo, list) then
      Result := list.Count
    else
      Result := 0;
  finally FLock.EndRead; end;
end; { TEventBus.SubscriptionCount }

procedure TEventBus.RemoveSubscription(ATypeInfo: PTypeInfo; const subscriptionID: TGUID);
var
  list: TSubscriptionList;
begin
  FLock.BeginRead;
  try
    if FSubscriptions.TryGetValue(ATypeInfo, list) then begin
      {$IFDEF DEBUG}
      var removedThreadID := list.GetSubscriptionThreadID(subscriptionID);
      {$ENDIF}
      list.Remove(subscriptionID);
      {$IFDEF DEBUG}
      if (removedThreadID <> 0) and (removedThreadID <> MainThreadID) then begin
        var state: TThreadDispatchState;
        if FThreadStates.TryGetValue(removedThreadID, state) then
          TInterlocked.Decrement(state.SubscriptionCount);
      end;
      {$ENDIF}
    end;
  finally FLock.EndRead; end;
end; { TEventBus.RemoveSubscription }

{ Global functions }

function CreateEventBus(AQueueDepth: integer = 1024): TEventBus;
begin
  Result := TEventBus.Create(AQueueDepth);
end; { CreateEventBus }

function EventBus: TEventBus;
begin
  GEventBusLock.BeginRead;
  try
    if assigned(GEventBus) then begin
      Result := GEventBus;
      Exit;
    end;
  finally GEventBusLock.EndRead; end;

  GEventBusLock.BeginWrite;
  try
    if not assigned(GEventBus) then
      GEventBus := TEventBus.Create;
    Result := GEventBus;
  finally GEventBusLock.EndWrite; end;
end; { EventBus }

initialization
finalization
  {$IFDEF DEBUG}
  TAlertableWaitMonitor.FreeInstance;
  {$ENDIF}
  FreeAndNil(GEventBus);
end.
