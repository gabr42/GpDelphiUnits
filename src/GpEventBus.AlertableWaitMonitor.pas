///<summary>Monitors background threads to detect missing alertable waits (DEBUG only).</summary>
///<author>Primoz Gabrijelcic, Claude (Anthropic AI)</author>
///<remarks><para>
///   (c) 2026 Primoz Gabrijelcic
///   Free for personal and commercial use. No rights reserved.
///
///   Author            : Primoz Gabrijelcic, Claude (Anthropic AI)
///   Creation date     : 2026-02-16
///   Last modification : 2026-02-16
///   Version           : 1.0
///</para><para>
///   History:
///     1.0: 2026-02-16
///       - Initial release.
///       - Automatic detection of threads not using alertable waits.
///       - Only active in DEBUG builds.
///</para></remarks>

unit GpEventBus.AlertableWaitMonitor;

{$IFDEF DEBUG}

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
  DSiWin32;

const
  /// <summary>
  ///   Timeout for alertable wait test. If a thread doesn't process the test APC
  ///   within this time, an error is logged and an exception is raised.
  /// </summary>
  CAlertableWaitTestTimeout_ms = 5000;  // 5 seconds

type
  /// <summary>
  ///   Monitors background threads to ensure they use alertable waits.
  ///   Only active in DEBUG builds - has zero overhead in RELEASE.
  /// </summary>
  /// <remarks>
  ///   When using GpEventBus with background threads, those threads must use
  ///   alertable waits (SleepEx, WaitForSingleObjectEx with bAlertable=True)
  ///   to receive events via QueueUserAPC. This monitor automatically detects
  ///   misconfigured threads and reports errors during development.
  /// </remarks>
  TAlertableWaitMonitor = class(TThread)
  strict private
    type
      TAlertableWaitTest = record
        ThreadID   : TThreadID;
        TestTime_ms: int64;       // GetTickCount64 when test was queued
        Completed  : boolean;     // Set to true by APC when test succeeds
      end;

    class var FInstance: TAlertableWaitMonitor;
    class var FInstanceLock: TLightweightMREW;

    var
      FLock : TLightweightMREW;
      FTests: TList<TAlertableWaitTest>;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor  Destroy; override;

    /// <summary>
    ///   Returns the singleton instance of the monitor. Creates it if needed.
    /// </summary>
    class function GetInstance: TAlertableWaitMonitor;

    /// <summary>
    ///   Frees the singleton instance. Call during finalization.
    /// </summary>
    class procedure FreeInstance;

    /// <summary>
    ///   Queue an alertable wait test for the specified thread.
    ///   If the thread doesn't process the test APC within the timeout,
    ///   an error will be logged and an exception raised.
    /// </summary>
    /// <param name="threadID">The thread ID to test</param>
    procedure QueueTest(threadID: TThreadID);

    /// <summary>
    ///   Mark a test as completed (called by the APC callback).
    ///   Internal use only.
    /// </summary>
    procedure MarkTestCompleted(threadID: TThreadID);
  end;

implementation

/// <summary>
///   APC callback - called when client thread enters alertable wait.
///   Parameter contains the thread ID being tested.
/// </summary>
procedure AlertableWaitTestAPC(dwParam: UIntPtr); stdcall;
var
  threadID: TThreadID;
begin
  threadID := TThreadID(dwParam);
  TAlertableWaitMonitor.GetInstance.MarkTestCompleted(threadID);
end;

{ TAlertableWaitMonitor }

constructor TAlertableWaitMonitor.Create;
begin
  inherited Create(false);  // Start immediately
  FreeOnTerminate := false;
  FTests := TList<TAlertableWaitTest>.Create;
end; { TAlertableWaitMonitor.Create }

destructor TAlertableWaitMonitor.Destroy;
begin
  FreeAndNil(FTests);
  inherited;
end; { TAlertableWaitMonitor.Destroy }

class function TAlertableWaitMonitor.GetInstance: TAlertableWaitMonitor;
begin
  FInstanceLock.BeginWrite;
  try
    if not assigned(FInstance) then
      FInstance := TAlertableWaitMonitor.Create;
    Result := FInstance;
  finally FInstanceLock.EndWrite; end;
end; { TAlertableWaitMonitor.GetInstance }

class procedure TAlertableWaitMonitor.FreeInstance;
begin
  FInstanceLock.BeginWrite;
  try
    if assigned(FInstance) then begin
      FInstance.Terminate;
      FInstance.WaitFor;
      FreeAndNil(FInstance);
    end;
  finally FInstanceLock.EndWrite; end;
end; { TAlertableWaitMonitor.FreeInstance }

procedure TAlertableWaitMonitor.QueueTest(threadID: TThreadID);
var
  test       : TAlertableWaitTest;
  threadHandle: THandle;
begin
  test.ThreadID := threadID;
  test.TestTime_ms := GetTickCount64;
  test.Completed := false;

  FLock.BeginWrite;
  try
    FTests.Add(test);
  finally FLock.EndWrite; end;

  // Queue APC to client thread - will be called when thread enters alertable wait
  threadHandle := DSiOpenThread(THREAD_SET_CONTEXT, false, threadID);
  if threadHandle <> 0 then begin
    try
      QueueUserAPC(@AlertableWaitTestAPC, threadHandle, UIntPtr(threadID));
    finally
      CloseHandle(threadHandle);
    end;
  end;
end; { TAlertableWaitMonitor.QueueTest }

procedure TAlertableWaitMonitor.MarkTestCompleted(threadID: TThreadID);
var
  i: integer;
begin
  FLock.BeginWrite;
  try
    // Find and remove the FIRST pending test for this thread
    // (there may be multiple tests if same thread creates multiple receivers)
    for i := 0 to FTests.Count-1 do begin
      if (FTests[i].ThreadID = threadID) and (not FTests[i].Completed) then begin
        FTests.Delete(i);  // Remove immediately - test passed
        break;
      end;
    end;
  finally FLock.EndWrite; end;
end; { TAlertableWaitMonitor.MarkTestCompleted }

procedure TAlertableWaitMonitor.Execute;
var
  i          : integer;
  now_ms     : int64;
  test       : TAlertableWaitTest;
  elapsed_ms : int64;
  errorMsg   : string;
begin
  while not Terminated do begin
    Sleep(500);  // Check every 500ms

    now_ms := GetTickCount64;

    FLock.BeginWrite;
    try
      // Check for timed-out tests (completed tests are already removed in MarkTestCompleted)
      for i := FTests.Count-1 downto 0 do begin
        test := FTests[i];
        elapsed_ms := now_ms - test.TestTime_ms;

        if elapsed_ms > CAlertableWaitTestTimeout_ms then begin
          // Test failed - thread is not using alertable waits
          errorMsg := Format(
            'GpEventBus: ERROR - Thread %d is not using alertable waits! ' +
            'Events will not be delivered. Use SleepEx(timeout, True) or ' +
            'WaitForSingleObjectEx(handle, timeout, True) instead of Sleep/WaitFor.',
            [test.ThreadID]);

          OutputDebugString(PChar(errorMsg));

          // Remove failed test
          FTests.Delete(i);

          // Raise exception in monitoring thread - will show in IDE
          raise Exception.Create(errorMsg);
        end;
      end;
    finally FLock.EndWrite; end;
  end;
end; { TAlertableWaitMonitor.Execute }

{$ELSE}

interface

// Empty unit in RELEASE builds

implementation

{$ENDIF}

end.
