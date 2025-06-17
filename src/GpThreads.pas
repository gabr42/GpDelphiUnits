(*:Safer threads and thread list.
   @desc <pre>
   (c) 2022 F A Bernhardt GmbH

   Maintainer        : Primoz Gabrijelcic
   Creation date     : 1999-03-22
   Last modification : 2022-03-21
   Version           : 1.20
</pre>*)(*
   History:
     1.20: 2022-03-21
       - Exported SuspendThread and ResumeThread.
       - Corrected error code in SuspendThread when operation was successful.
       - Implemented TThreadData.LogString.
       - AddThread initializes TThreadData to zeroes (cosmetic).
     1.19: 2020-08-25
       - SuspendThread and ResumeThread moved here from unit GpExcept.
     1.18b: 2018-01-23
       - Destructor should not crash anymore when constructor raises an exception.
     1.18a: 2017-08-02
       - Fixed: CleanupThreads removed all threads with arAlways AutoRemove flag when
         called from user code. Only arIfStopped threads have to be removed in that case.
     1.18: 2016-10-27
       - tdAutoRemove changed to a three-state value.
     1.17: 2015-03-03
       - [Istvan] Fixed CleanupThreads thread removal.
     1.16: 2012-08-27
       - [Istvan] Added CleanupThreads to remove threads that aren't active.
     1.15: 2011-09-27
       - Implemented TThreadTimesSnapshot class.
     1.14: 2011-08-31
       - Uses OtlCommon.Utils to set thread name.
     1.13a: 2010-04-09
       - [Istvan] Better handle invalid handle in finalization with GetHandleInformation.
     1.13: 2010-04-09
       - [Istvan] Ignore STATUS_INVALID_HANDLE in finalization if we're in a library
          because the process handle might've been invalidated/
     1.12c: 2009-09-28
       - Fixed a bug where AddThreads was called before GpThreads was initialized.
         [AddThreads was called from an OTL thread created by another unit.]
     1.12b: 2009-03-16
       - Handle case where GpThreads finalization is called before the last thread is
         destroyed.
     1.12a: 2009-02-06
       - Fixed bug in TNamedThread.Terminate which caused a deadlock under very special
         circumstances:
           thread := TNamedThread.Create(suspended := true);
           thread.Terminate;
           thread.Resume;
           thread.Terminate; // <- deadlocked here
           thread.WaitFor;
           thread.Free;
         (This actually occurred in NC if you terminated NC while it was still initializing.)
     1.12: 2008-06-03
       - Added public global procedure ProcessThreadMessages.
     1.11: 2007-12-17
       - Added lifecycle event list to base thread object, limited to 20 events by
         default. Application can change this limit.
     1.10: 2006-01-30
       - Added pre/post execution hooks.
       - Added public accessor for thRunning internal variable.
     1.09: 2006-01-26
       - Added process-wide unique ID to each thread's ThreadData.
       - Refactored thread initialization and cleanup into separate methods.
       - Added 'userData' pointer to the IterateThreads.
     1.08a: 2006-01-04
       - Sends thread name to the debugger only when ShowThreadNames is defined.         
     1.08: 2005-11-09
       - Sends thread name to the debugger when debugged on D7 and newer.
     1.07: 2005-04-08
       - Modified Terminate to wait on thread startup.
     1.06: 2004-07-08
       - Added function FindThreadData.
       - Added method TNamedThread.ThreadData.
     1.05a: 2003-08-27
       - Modification from 1.04 hanged the program if the thread was never
         started (created in suspended state and never resumed).
     1.05: 2003-08-25
       - Added ProcessThreadMessages method.
     1.04: 2003-07-03
       - Modified destructor to stop the thread if it was not already stopped.
     1.03: 2002-11-22
       - Modified initialization code to set main thread name to the exe name
         (instead of 'main program').
     1.02: 2000-07-24
       - Added code to log top of thread stack to AddThread.
     1.01: 2000-07-24
       - AddThread and RemoveThread methods made public to allow TSafeThread to
         correctly log the name of a thread that caused exception.
     1.0: 1999-03-22
       - TSafeThread class moved from GpExcept unit to this unit; renamed to
         TNamedThread.
*)

{$I MSDEFINE.INC}
{$H-,J+} // Don't change!

unit GpThreads;

interface

uses
  Windows,
  Classes,
  SyncObjs,
  GpLists,
  GpLifecycleEventList,
  {$IFDEF MSWINDOWS}
  OtlCommon.Utils,
  {$ENDIF MSWINDOWS}
  OtlSync;

type
  PThreadData = ^TThreadData;

  TNamedThread = class(TThread)
  private
    thDontDump           : boolean;
    thEventList          : IGpLifecycleEventList;
    thInitialized        : boolean;
    thName               : string;
    thRunning            : boolean;
    thTerminateEvent     : THandle;
    thThreadFinishedEvent: THandle;
  protected
    procedure CleanupThreadData; virtual;
    function  GetThreadFinished: boolean;
    procedure InitializeThreadData; virtual;
    procedure PostExecute; virtual;
    procedure PreExecute; virtual;
    property IsRunning: boolean read thRunning;
  public
    constructor Create(CreateSuspended: boolean; const ThreadName: string);
    constructor CreateEx(CreateSuspended: boolean; const ThreadName: string; DontDump:
      boolean);
    destructor  Destroy; override;
    procedure Execute; override;
    procedure ProcessThreadMessages(exitOnTerminate: boolean = false);
    procedure SafeExecute; virtual; abstract;
    procedure Terminate; virtual;
    function  ThreadData: PThreadData;
    property DontDump: boolean read thDontDump write thDontDump;
    property EventList: IGpLifecycleEventList read thEventList write thEventList;
    property Name: string read thName;
    property Terminated;
    property TerminateEvent: THandle read thTerminateEvent;
    property ThreadFinished: Boolean read GetThreadFinished;
    property ThreadFinishedEvent: THandle read thThreadFinishedEvent;
  end; { TNamedThread }

  TAutoRemove = (arNone, arIfStopped, arAlways);

  TThreadData = record
    tdID        : DWORD;
    tdUniqueID  : int64;
    tdHandle    : THandle;
    tdName      : string;
    tdNext      : PThreadData;
    tdThread    : TNamedThread;
    tdSuspended : boolean;
    tdSuspCount : DWORD;
    tdSuspError : DWORD;
    tdTOS       : DWORD;
    tdAutoRemove: TAutoRemove;
    function LogString: AnsiString;
  end; { TThreadData }

  TIterateProc = procedure(threadData: PThreadData; userData: pointer); stdcall;

var
  exceptLock: TOmniCS;

  //:Get current thread name (works only if thread is derived from TSafeThread, returns IntToStr(GetCurrentThreadID) otherwise).
  function  GetCurrentThreadName: string;
  //:Converts thread number to formatted thread name.
  function  GetFormattedThreadName(threadID: DWORD): string;
  //:Iterates over all registered threads and passes userdata pointer to each iterator.
  procedure IterateThreads(iterator: TIterateProc; userData: pointer = nil); overload;

  //:Adds thread to the global list.
  procedure AddThread(threadID: DWORD; threadHandle: THandle; threadName: string;
    threadPtr: TNamedThread; autoRemoveOnHalt: TAutoRemove = arNone);
  //:Removes thread from the global list.
  procedure RemoveThread(threadID: DWORD);
  //:Locates thread data in the global list.
  function  FindThreadData(threadID: DWORD): PThreadData;
  //:removes terminated threads from the global list.
  procedure CleanupThreads();

  procedure ProcessThreadMessages;

type
  TThreadTimesSnapshot = class
  strict private
    FThreadTimes: TGpCountedIntegerList;
  protected
    procedure CalcDiff(threadData: PThreadData);
    procedure PrepareSnapshot(threadData: PThreadData);
  public
    constructor Create;
    destructor  Destroy; override;
    procedure   Snapshot;
    function    SnapshotDiff: WideString;
  end; { TThreadTimesSnapshot }

procedure SuspendThread(threadData: PThreadData; userData: pointer); stdcall;
procedure ResumeThread(threadData: PThreadData; userData: pointer); stdcall;

implementation

uses
  SysUtils,
  Messages,
  DSiWin32;

const
  threadList: PThreadData = nil;
  threadUniqueID: int64 = 0;

{ Helpers }

function GetStackTop: DWORD; // Copied from HVYAST32.PAS
asm
  {$IFDEF CPUx64}
  XOR RAX, RAX  // return nil as this is not supported
  {$ELSE}
  MOV EAX, FS:[4]
  {$ENDIF}
end; { GetStackTop }

{ Thread management }

procedure AddThread(threadID: DWORD; threadHandle: THandle; threadName: string;
  threadPtr: TNamedThread; autoRemoveOnHalt: TAutoRemove);
var
  td: PThreadData;
begin
  exceptLock.Acquire;
  try
    New(td);
    ZeroMemory(td, SizeOf(TThreadData));
    Inc(threadUniqueID);
    td^.tdID         := threadID;
    td^.tdUniqueID   := threadUniqueID;
    td^.tdHandle     := threadHandle;
    td^.tdName       := threadName;
    td^.tdTOS        := GetStackTop;
    td^.tdThread     := threadPtr;
    td^.tdAutoRemove := autoRemoveOnHalt;
    td^.tdNext       := threadList;
    threadList := td;
  finally exceptLock.Release; end;
end; { AddThread }

procedure RemoveThread(threadID: DWORD);
var
  curr: PThreadData;
  prev: PThreadData;
begin
  exceptLock.Acquire;
  try
    if assigned(threadList) then begin
      if threadList^.tdID = threadID then begin
        curr := threadList;
        threadList := threadList^.tdNext;
        Dispose(curr);
      end
      else begin
        prev := threadList;
        curr := prev^.tdNext;
        while assigned(curr) do begin
          if curr^.tdID = threadID then begin
            prev^.tdNext := curr^.tdNext;
            Dispose(curr);
            Exit;
          end;
          prev := curr;
          curr := curr^.tdNext;
        end;
      end;
    end;
  finally exceptLock.Release; end;
end; { RemoveThread }

procedure InternalCleanupThreads(isHalting: boolean);
var
  curr    : PThreadData;
  exitCode: Cardinal;
  prev    : PThreadData;
  next    : PThreadData;
begin
  exceptLock.Acquire;
  try
    if assigned(threadList) then begin
      prev := threadList;
      curr := prev;
      while assigned(curr) do begin
        if (isHalting and (curr^.tdAutoRemove = arAlways))
           or ((curr^.tdAutoRemove = arIfStopped)
               and GetExitCodeThread(curr.tdHandle, exitCode)
               and (exitCode <> STILL_ACTIVE)) then
        begin
          next := curr^.tdNext;
          if curr = threadList then
          begin
            threadList := next;
            prev := threadList;
          end
          else
            prev^.tdNext := next;
          DSiCloseHandleAndNull(curr.tdHandle);
          Dispose(curr);
          curr := next;
        end
        else
        begin
          prev := curr;
          curr := curr^.tdNext;
        end;
      end;
    end;
  finally exceptLock.Release; end;
end; { InternalCleanupThreads }

procedure CleanupThreads;
begin
  InternalCleanupThreads(false);
end; { CleanupThreads }

function GetThreadName(threadID: DWORD; var threadName: string): boolean;
var
  td: PThreadData;
begin
  exceptLock.Acquire;
  try
    td := FindThreadData(threadID);
    if not assigned(td) then
      Result := false
    else begin
      threadName := td^.tdName;
      Result := true;
    end;
  finally exceptLock.Release; end;
end; { GetThreadName }

function GetFormattedThreadName(threadID: DWORD): string;
var
  threadName: string;
begin
  if GetThreadName(threadID, threadName) then
    threadName := threadName + ' ('+IntToStr(threadID)+')'
  else
    threadName := IntToStr(threadID);
  Result := threadName;
end; { GetFormattedThreadName }

procedure IterateThreads(iterator: TIterateProc; userData: pointer);
var
  td: PThreadData;
begin
  exceptLock.Acquire;
  try
    td := threadList;
    while assigned(td) do begin
      iterator(td, userData);
      td := td^.tdNext;
    end;
  finally exceptLock.Release; end;
end; { IterateThreads }

function FindThreadData(threadID: DWORD): PThreadData;
begin
  exceptLock.Acquire;
  try
    Result := threadList;
    while assigned(Result) do begin
      if Result.tdID = threadID then
        Exit;
      Result := Result^.tdNext;
    end; //while
  finally exceptLock.Release; end;
end; { FindThreadData }

procedure ProcessThreadMessages;
var
  msg: TMsg;
begin
  while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) and (Msg.Message <> WM_QUIT) do begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
  end;
end; { ProcessThreadMessages }

procedure SuspendThread(threadData: PThreadData; userData: pointer); stdcall;
begin
  with threadData^ do begin
    if ((not assigned(tdThread)) or (assigned(tdThread) and (not tdThread.DontDump))) and // main thread or dumpable thread
       (tdID <> GetCurrentThreadID) and (tdHandle <> 0) then
    begin
      tdSuspCount := Windows.SuspendThread(tdHandle);
      tdSuspended := (tdSuspCount <> $FFFFFFFF);
      if tdSuspended then begin
        tdSuspError := 0;
        Inc(tdSuspCount); // SuspendThread returns previous suspend count
      end
      else
        tdSuspError := GetLastError();
    end
    else
    begin
      tdSuspCount := 0;
      tdSuspError := 1;
      tdSuspended := false;
    end;
  end;
end; { SuspendThread }

procedure ResumeThread(threadData: PThreadData; userData: pointer); stdcall;
begin
  with threadData^ do begin
    if tdSuspended then begin
      Windows.ResumeThread(tdHandle);
      tdSuspended := false;
    end;
  end;
end; { ResumeThread }

{ TNamedThread }

constructor TNamedThread.Create(CreateSuspended: boolean; const ThreadName: string);
begin
  CreateEx(CreateSuspended, ThreadName, false);
end; { TNamedThread.Create }

constructor TNamedThread.CreateEx(CreateSuspended: boolean; const ThreadName: string;
  DontDump: boolean);
begin
  thName      := ThreadName;
  thDontDump  := DontDump;
  InitializeThreadData;
  inherited Create(CreateSuspended);
end; { TNamedThread.CreateEx }

destructor TNamedThread.Destroy;
begin
  if thRunning and (not Terminated) then begin
    Terminate;
    WaitFor;
  end;
  CleanupThreadData;
  inherited Destroy;
end; { TNamedThread.Destroy }

procedure TNamedThread.CleanupThreadData;
begin
  DSiCloseHandleAndNull(thThreadFinishedEvent);
  DSiCloseHandleAndNull(thTerminateEvent);
  thEventList := nil;
end; { TNamedThread.CleanupThreadData }

function TNamedThread.GetThreadFinished: boolean;
begin
  Result := WaitForSingleObject(ThreadFinishedEvent, 0) = WAIT_OBJECT_0;
end; { TNamedThread.GetThreadFinished }

procedure TNamedThread.Terminate;
begin
  if not Suspended then // wait for thread to start up
    while not thInitialized do
      Sleep(1);
  inherited Terminate;
  if TerminateEvent <> 0 then
    SetEvent(TerminateEvent);
  thInitialized := true; //handle special case: thread.Create(suspended); thread.Terminate; thread.Resume; thread.Terminate;
end; { TNamedThread.Terminate }

procedure TNamedThread.Execute;
begin
  {$IFDEF MSWINDOWS}
  OtlCommon.Utils.SetThreadName(thName);
  {$ENDIF MSWINDOWS}
  thInitialized := true;
  AddThread(ThreadID, Handle, thName, self);
  thRunning := true;
  try
    PreExecute;
    try
      SafeExecute;
    finally PostExecute; end;
  finally
    thRunning := false;
    RemoveThread(ThreadID);
    Terminate; // set Terminated
    SetEvent (ThreadFinishedEvent);
  end;
end; { TNamedThread.Execute }

procedure TNamedThread.InitializeThreadData;
begin
  thEventList := CreateGpLifecycleEventList;
  thEventList.MaxNumEvents := 20;
  thTerminateEvent := CreateEvent (nil, true, false, nil);
  thThreadFinishedEvent := CreateEvent (nil, true, false, nil);
end; { TNamedThread.InitializeThreadData }

procedure TNamedThread.PostExecute;
begin
  // intentionally empty
end; { TNamedThread.PostExecute }

procedure TNamedThread.PreExecute;
begin
  // intentionally empty
end; { TNamedThread.PreExecute }

procedure TNamedThread.ProcessThreadMessages(exitOnTerminate: boolean);
var
  msg: TMsg;
begin
  while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) and (Msg.Message <> WM_QUIT) do begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
    if exitOnTerminate and (TerminateEvent <> 0)
      and (WaitForSingleObject(TerminateEvent, 0) <> WAIT_TIMEOUT)
    then
      break; //while
  end;
end; { TNamedThread.ProcessThreadMessages }

function TNamedThread.ThreadData: PThreadData;
begin
  Result := FindThreadData(ThreadID);
end; { TNamedThread.ThreadData }

{ Initialization }

function GetProcessThreadHandle: THandle;
var
  hand: THandle;
begin
  if DuplicateHandle(GetCurrentProcess, GetCurrentThread, GetCurrentProcess, @hand,
       0, false, DUPLICATE_SAME_ACCESS) then
    Result := hand
  else
    Result := 0;
end; { GetProcessThreadHandle }

function GetCurrentThreadName: string;
var
  name: string;
begin
  if not GetThreadName(GetCurrentThreadID, name) then
    Result := IntToStr(GetCurrentThreadID)
  else
    Result := name;
end; { GetCurrentThreadName }

var
  procHand: THandle;
  procHandInfo: Cardinal;

{ TThreadTimesSnapshot }

procedure IterPrepareSnapshot(threadData: PThreadData; userData: pointer); stdcall;
begin
  TThreadTimesSnapshot(userData).PrepareSnapshot(threadData);
end; { IterPrepareSnapshot }

procedure IterCalcDiff(threadData: PThreadData; userData: pointer); stdcall;
begin
  TThreadTimesSnapshot(userData).CalcDiff(threadData);
end; { IterCalcDiff }

constructor TThreadTimesSnapshot.Create;
begin
  inherited Create;
  FThreadTimes := TGpCountedIntegerList.Create;
end; { TThreadTimesSnapshot.Create }

destructor TThreadTimesSnapshot.Destroy;
begin
  FreeAndNil(FThreadTimes);
  inherited;
end; { TThreadTimesSnapshot.Destroy }

procedure TThreadTimesSnapshot.CalcDiff(threadData: PThreadData);
var
  idxSnapshot: integer;
begin
  idxSnapshot := FThreadTimes.IndexOf(integer(threadData.tdID));
  if idxSnapshot >= 0 then
    FThreadTimes.ItemCounter[threadData.tdID] :=
      (DSiGetThreadTime(threadData.tdHandle) div 1000) +
      FThreadTimes.ItemCounter[threadData.tdID]; // already negative
end; { TThreadTimesSnapshot.CalcDiff }

procedure TThreadTimesSnapshot.PrepareSnapshot(threadData: PThreadData);
begin
  FThreadTimes.Ensure(integer(threadData.tdID), - (DSiGetThreadTime(threadData.tdHandle) div 1000));
end; { TThreadTimesSnapshot.PrepareSnapshot }

procedure TThreadTimesSnapshot.Snapshot;
begin
  FThreadTimes.Clear;
  IterateThreads(@IterPrepareSnapshot, pointer(Self));
end; { TThreadTimesSnapshot.Snapshot }

function TThreadTimesSnapshot.SnapshotDiff: WideString;
var
  iThread   : integer;
  pData     : PThreadData;
  prefix    : string;
  threadName: string;
begin
  IterateThreads(@IterCalcDiff, pointer(Self));
  Result := '';
  // pretty much unsafe, ugly things will happen if thread is destroyed while this loop is running
  for iThread := 0 to FThreadTimes.Count - 1 do begin
    if FThreadTimes.Counter[iThread] >= 0 then begin // {skip "0 ms" entries} and removed threads
      if Result <> '' then
        Result := Result + #13#10;
      threadName := '';
      pData := FindThreadData(cardinal(FThreadTimes[iThread]));
      if assigned(pData) then
        threadName := pData.tdName;
      prefix := '';
      if FThreadTimes[iThread] = integer(GetCurrentThreadID) then
        prefix := '*';
      Result := Result + Format('%s%d: %d ms [%s]', [prefix, FThreadTimes[iThread],
        FThreadTimes.Counter[iThread], threadName]);
    end;
  end;
end; { TThreadTimesSnapshot.SnapshotDiff }

{ TThreadData }

function TThreadData.LogString: AnsiString;
begin
  if not assigned(tdThread) then
    Result := AnsiString(Format('External thread ID: %d; Handle: %d; Name: >%s<; Suspended: %d; Suspend count: %d; Suspend error: %d',
                                [tdID, tdHandle, tdName, Ord(tdSuspended), tdSuspCount, tdSuspError]))
  else
    Result := AnsiString(Format('Thread ID: %d; Handle: %d; Name: >%s<; Suspended: %d; Suspend count: %d; Suspend error: %d; DontDump: %d',
                                [tdID, tdHandle, tdName, Ord(tdSuspended), tdSuspCount, tdSuspError, Ord(tdThread.DontDump)]));
end; { TThreadData.LogString }

initialization
  {$IFDEF MSWINDOWS}{$IFDEF ShowThreadNames}
  SetThreadName('Main');
  {$ENDIF}{$ENDIF}
  threadList := nil;
  procHand := GetProcessThreadHandle;
  AddThread(GetCurrentThreadID, procHand, ChangeFileExt(ExtractFileName(ParamStr(0)),''), nil);
finalization
  InternalCleanupThreads(true);
  RemoveThread(GetCurrentThreadID); // just for cosmetic purposes - to remove memory leak
  if (procHand <> 0) and GetHandleInformation(procHand, procHandInfo) then
    CloseHandle(procHand);
end.
