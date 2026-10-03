# GpEventBus

**Version:** 1.01
**Authors:** Claude (Anthropic AI), Primoz Gabrijelcic
**Created:** 2026-02-13
**Last Modified:** 2026-02-16
**License:** Free for personal and commercial use. No rights reserved.

## Overview

`GpEventBus` is a thread-safe event bus for Delphi that enables type-safe, cross-thread event dispatch. It uses **QueueUserAPC** for efficient background thread dispatch and **TThread.Queue** for main thread dispatch.

### Key Features

- **Type-safe events**: Events are identified purely by their type parameter `T` (no string names)
- **Cross-thread dispatch**: Producers fire events from any thread; subscribers receive callbacks in their own thread context
- **Record-constrained**: Event data must be records (value types) for safe copying across threads
- **No dependencies**: Uses only standard Delphi RTL (no Spring4D or other libraries)
- **Thread-safe**: All operations use `TLightweightMREW` for efficient reader-writer locking
- **Dead thread detection**: Automatically cleans up subscriptions for terminated threads

## Architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  Producer   │────────>│  Event Bus   │────────>│ Subscriber  │
│ (Any Thread)│  Fire() │   Registry   │ Dispatch│(Own Thread) │
└─────────────┘         └──────────────┘         └─────────────┘
                              │
                              ├─> Main Thread: TThread.Queue
                              └─> Background:  QueueUserAPC
```

## Quick Start

### 1. Define Event Type (Record)

```delphi
type
  TDataReadyEvent = record
    FileName: string;
    BytesRead: Int64;
    Success: Boolean;
    class function Create(const AFileName: string; ABytes: Int64;
      ASuccess: Boolean): TDataReadyEvent; static;
  end;

class function TDataReadyEvent.Create(const AFileName: string;
  ABytes: Int64; ASuccess: Boolean): TDataReadyEvent;
begin
  Result.FileName := AFileName;
  Result.BytesRead := ABytes;
  Result.Success := ASuccess;
end;
```

### 2. Subscribe from Main Thread (VCL)

```delphi
type
  TMainForm = class(TForm)
  private
    FSubscription: IEventSubscription;
  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
  end;

procedure TMainForm.AfterConstruction;
begin
  inherited;
  // Main thread doesn't need RegisterThread (auto-detected)
  FSubscription := EventBus.Subscribe<TDataReadyEvent>(
    procedure(const evt: TDataReadyEvent)
    begin
      // Executes in main thread - safe to update UI
      if evt.Success then
        StatusBar1.SimpleText := Format('Loaded %s (%d bytes)',
          [evt.FileName, evt.BytesRead])
      else
        ShowMessage('Load failed: ' + evt.FileName);
    end);
end;

procedure TMainForm.BeforeDestruction;
begin
  FSubscription.Unsubscribe;  // Clean up
  inherited;
end;
```

### 3. Subscribe from Background Thread

```delphi
type
  TWorkerThread = class(TThread)
  private
    FSubscription: IEventSubscription;
  protected
    procedure Execute; override;
  end;

procedure TWorkerThread.Execute;
begin
  // STEP 1: Register this thread for event dispatch
  EventBus.RegisterThread;
  try
    // STEP 2: Subscribe to events
    FSubscription := EventBus.Subscribe<TDataReadyEvent>(
      procedure(const evt: TDataReadyEvent)
      begin
        // Executes in THIS background thread
        ProcessFile(evt.FileName, evt.BytesRead);
      end);

    // STEP 3: Alertable wait loop (REQUIRED for QueueUserAPC)
    while not Terminated do
    begin
      // Sleep in alertable state - APCs will wake us up
      if SleepEx(100, True) = WAIT_IO_COMPLETION then
        Continue;  // APC executed, loop again

      // Optional: Do periodic work here
      CheckHeartbeat;
    end;
  finally
    // STEP 4: Clean up before thread terminates
    FSubscription := nil;  // Unsubscribe
    EventBus.UnregisterThread;
  end;
end;
```

### 4. Fire Events (From Any Thread)

```delphi
// From background thread or main thread
procedure TFileLoader.LoadComplete(const fileName: string; bytesRead: Int64);
begin
  EventBus.Fire<TDataReadyEvent>(
    TDataReadyEvent.Create(fileName, bytesRead, True));
end;
```

## API Reference

### Core Interface: `IEventBus`

#### `Subscribe<T: record>(handler: TEventHandler<T>): IEventSubscription`

Subscribe to event type `T` from the current thread.

**Parameters:**
- `handler`: Anonymous method called when event is fired

**Returns:** Subscription handle for explicit unsubscribe

**Requirements:**
- Background threads must call `RegisterThread` first
- Background threads must use alertable waits (see below)

**Example:**
```delphi
FSubscription := EventBus.Subscribe<TLogEvent>(
  procedure(const evt: TLogEvent)
  begin
    WriteLn(evt.Message);
  end);
```

#### `Fire<T: record>(eventData: T)`

Fire event from any thread. Marshals to all subscribers' threads.

**Parameters:**
- `eventData`: Event data (copied for each subscriber)

**Thread-safe:** Yes

**Example:**
```delphi
EventBus.Fire<TLogEvent>(
  TLogEvent.Create(llInfo, 'Processing started'));
```

#### `UnsubscribeAll<T: record>`

Unsubscribe all handlers for event type `T`.

**Thread-safe:** Yes

**Example:**
```delphi
EventBus.UnsubscribeAll<TLogEvent>;
```

#### `RegisterThread`

Register current thread as event bus target.

**When to call:**
- Before subscribing from background threads
- Not needed for main thread (auto-detected)

**DEBUG Mode Behavior:**
- Automatically queues an alertable wait test (see [GpEventBus.AlertableWaitMonitor](GpEventBus.AlertableWaitMonitor.md))
- Detects threads not using alertable waits within 5 seconds
- Raises exception if thread doesn't enter alertable wait state

**Example:**
```delphi
procedure TMyThread.Execute;
begin
  EventBus.RegisterThread;
  try
    // Subscribe and process...
  finally
    EventBus.UnregisterThread;
  end;
end;
```

#### `UnregisterThread`

Unregister current thread and clean up resources.

**When to call:**
- Before background thread termination
- Automatically unsubscribes all thread's subscriptions

#### `SubscriptionCount<T: record>: Integer`

Get count of active subscriptions for event type `T`.

**Thread-safe:** Yes

### Subscription Interface: `IEventSubscription`

#### `Unsubscribe`

Unsubscribe this handler from the event bus.

**Example:**
```delphi
FSubscription.Unsubscribe;
FSubscription := nil;
```

#### `IsActive: Boolean`

Check if subscription is still active.

#### `ThreadID: TThreadID` (property)

Get the thread ID this subscription belongs to.

### Global Functions

#### `EventBus: IEventBus`

Returns the global event bus singleton.

**Thread-safe:** Yes (lazy initialization)

**Example:**
```delphi
EventBus.Fire<TMyEvent>(data);
```

#### `CreateEventBus(AQueueDepth: Integer = CDefaultQueueDepth): IEventBus`

Creates a new isolated event bus instance (for testing).

**Parameters:**
- `AQueueDepth`: Maximum number of pending events per background thread (default: `CDefaultQueueDepth` = 1024)

**Example:**
```delphi
var
  bus: IEventBus;
begin
  bus := CreateEventBus;  // Default queue depth (1024)
  bus.Subscribe<TTestEvent>(...);

  // Or with custom queue depth for high-frequency events
  bus := CreateEventBus(10000);  // Larger queue
end;
```

## Background Thread Requirements

### Alertable Wait States

Background threads **must** use alertable wait functions for QueueUserAPC to work:

```delphi
// CORRECT - Alertable wait
while not Terminated do
  SleepEx(100, True);  // Second parameter = True

// CORRECT - Alertable wait with event
WaitForSingleObjectEx(FStopEvent, 100, True);

// CORRECT - Multiple objects
WaitForMultipleObjectsEx(Count, @Handles, False, Timeout, True);

// WRONG - Non-alertable (events will NOT be delivered)
Sleep(100);
WaitForSingleObject(FStopEvent, 100);
```

### Win32 Alertable Wait Functions

- `SleepEx(dwMilliseconds, bAlertable: BOOL)`
- `WaitForSingleObjectEx(hHandle, dwMilliseconds, bAlertable: BOOL)`
- `WaitForMultipleObjectsEx(..., bAlertable: BOOL)`
- `MsgWaitForMultipleObjectsEx(..., dwFlags)`
- `SignalObjectAndWait(..., bAlertable: BOOL)`

**Key Point:** Set `bAlertable` parameter to `True`.

### Return Value Check

When an APC executes, wait functions return `WAIT_IO_COMPLETION` (192):

```delphi
while not Terminated do
begin
  case WaitForSingleObjectEx(FEvent, 100, True) of
    WAIT_OBJECT_0: HandleEvent;
    WAIT_TIMEOUT: { Continue };
    WAIT_IO_COMPLETION: { APC executed, continue };
  end;
end;
```

### Thread Template

```delphi
type
  TMyWorkerThread = class(TThread)
  private
    FStopEvent: TEvent;
    FSubscriptions: TList<IEventSubscription>;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
  end;

constructor TMyWorkerThread.Create;
begin
  inherited Create(True);  // Suspended
  FStopEvent := TEvent.Create(nil, True, False, '');
  FSubscriptions := TList<IEventSubscription>.Create;
end;

destructor TMyWorkerThread.Destroy;
begin
  FreeAndNil(FSubscriptions);
  FreeAndNil(FStopEvent);
  inherited;
end;

procedure TMyWorkerThread.Execute;
begin
  EventBus.RegisterThread;
  try
    // Subscribe to events
    FSubscriptions.Add(
      EventBus.Subscribe<TWorkEvent>(
        procedure(const evt: TWorkEvent)
        begin
          ProcessWork(evt);
        end));

    // Main loop with alertable wait
    while WaitForSingleObjectEx(FStopEvent.Handle, 100, True) <> WAIT_OBJECT_0 do
    begin
      // Optional periodic work here
    end;
  finally
    FSubscriptions.Clear;  // Unsubscribe all
    EventBus.UnregisterThread;
  end;
end;
```

## Event Data Design

### Records Only

Event data **must** be records (value types):

```delphi
// CORRECT
type
  TUserLoggedInEvent = record
    UserID: Integer;
    UserName: string;
    LoginTime: TDateTime;
  end;

// WRONG - Classes not supported
type
  TUserLoggedInEvent = class
    UserID: Integer;
  end;
```

### Why Records?

1. **Value semantics**: Automatically copied across threads
2. **No lifetime management**: No need to worry about who owns/frees the object
3. **Thread-safe**: Each subscriber gets its own copy
4. **Efficient**: Stack-allocated, no heap overhead for small records

### Managed Records (Delphi 10.4+)

You can use managed records with custom operators:

```delphi
type
  TFileEvent = record
    FileName: string;
    Data: TBytes;
    class operator Initialize(out Dest: TFileEvent);
    class function Create(const AFile: string; const AData: TBytes):
      TFileEvent; static;
  end;

class operator TFileEvent.Initialize(out Dest: TFileEvent);
begin
  Dest.FileName := '';
  Dest.Data := nil;
end;

class function TFileEvent.Create(const AFile: string;
  const AData: TBytes): TFileEvent;
begin
  Result.FileName := AFile;
  Result.Data := AData;
end;
```

### Large Data

For large data, use references:

```delphi
type
  IDataBuffer = interface
    function GetData: TBytes;
    property Data: TBytes read GetData;
  end;

  TDataEvent = record
    Buffer: IDataBuffer;  // Interface reference (ref-counted)
    Size: Int64;
  end;
```

## Performance Considerations

### Reader-Writer Locks

`TLightweightMREW` allows:
- Multiple simultaneous readers (e.g., multiple `Fire` calls)
- Exclusive writer (e.g., `Subscribe`, `UnsubscribeAll`)

**Impact:** `Fire` is very fast when no subscriptions are being added/removed.

### Coalescing APC Pattern

Multiple `Fire` calls to the same thread result in:
- All events queued in `TThreadedQueue` (configurable depth, default `CDefaultQueueDepth` = 1024)
- Only **one APC** in flight at a time
- APC drains the full queue when executed

**Impact:** Efficient for high-frequency events.

**Queue Depth:** For high-frequency event scenarios, you can increase the queue depth when creating an event bus instance:
```delphi
var
  bus: TEventBus;
begin
  bus := TEventBus.Create(10000);  // Larger queue for high throughput
end;
```

### Dead Thread Detection

Called only when dispatch fails (QueueUserAPC returns error).

**Cost:** `GetExitCodeThread` syscall per registered thread.

**Optimization:** Detection is lazy - only triggered on failure.

## Testing

### Unit Test Example

```delphi
procedure TestEventBus.TestCrossThreadDispatch;
var
  bus: IEventBus;
  received: Boolean;
  thread: TTestThread;
  event: TManualResetEvent;
begin
  bus := CreateEventBus;  // Isolated instance
  received := False;
  event := TManualResetEvent.Create(nil, True, False, '');
  try
    thread := TTestThread.Create(bus, event,
      procedure(const evt: TTestEvent)
      begin
        received := True;
        event.SetEvent;
      end);
    try
      thread.Start;
      Sleep(100);  // Let thread enter alertable wait

      bus.Fire<TTestEvent>(TTestEvent.Create('test'));

      Assert.AreEqual(wrSignaled, event.WaitFor(1000),
        'Event should be received within 1 second');
      Assert.IsTrue(received, 'Handler should have been called');
    finally
      thread.Terminate;
      thread.WaitFor;
      thread.Free;
    end;
  finally
    event.Free;
  end;
end;
```

## Thread Safety

All operations are thread-safe:

| Operation | Lock Type | Concurrency |
|-----------|-----------|-------------|
| `Subscribe` | Write | Exclusive |
| `Fire` | Read | Multiple simultaneous |
| `UnsubscribeAll` | Write | Exclusive |
| `RegisterThread` | Write | Exclusive |
| `UnregisterThread` | Write | Exclusive |
| `SubscriptionCount` | Read | Multiple simultaneous |

## Limitations

### 1. Record Constraint

Event data must be records. Classes and interfaces are not supported directly.

**Workaround:** Use interface references in records (ref-counted).

### 2. Alertable Wait Required

Background threads **must** use alertable waits. Regular `Sleep` or `WaitForSingleObject` will NOT receive events.

**Workaround:** Always use `SleepEx(..., True)` or `WaitForSingleObjectEx(..., True)`.

### 3. Manual Registration

Background threads must call `RegisterThread` before subscribing.

**Workaround:** Wrap in thread base class or create thread factory.

### 4. No Synchronous Dispatch Option

All background thread dispatches are asynchronous (queued via APC).

**Workaround:** For synchronous calls, use `TThread.Queue` or synchronization primitives.

## Troubleshooting

### Events Not Received in Background Thread

**Symptom:** Subscribed but handler never called.

**Cause:** Thread not in alertable wait state.

**Solution:** Use `SleepEx(timeout, True)` instead of `Sleep(timeout)`.

**DEBUG Mode Detection:** In DEBUG builds, `RegisterThread` automatically queues an alertable wait test. If the thread doesn't enter an alertable wait within 5 seconds, you'll get an exception with a clear error message pointing to the problem.

### Exception: "Thread X is not registered"

**Symptom:** Exception when calling `Subscribe` from background thread.

**Cause:** Forgot to call `RegisterThread`.

**Solution:** Call `EventBus.RegisterThread` before subscribing.

### Access Violation on Thread Termination

**Symptom:** AV when background thread terminates.

**Cause:** Forgot to unregister thread or unsubscribe.

**Solution:** Always call `UnregisterThread` in `finally` block.

### "Failed to queue APC" Exception

**Symptom:** Exception when firing event.

**Cause:** Target thread terminated without unregistering.

**Solution:** Event bus will auto-detect and clean up. Check thread lifecycle.

## Examples

### Example 1: Logger

```delphi
type
  TLogLevel = (llDebug, llInfo, llWarning, llError);

  TLogEvent = record
    Level: TLogLevel;
    Message: string;
    ThreadID: TThreadID;
    Timestamp: TDateTime;
  end;

// Logger service (background thread)
type
  TLoggerThread = class(TThread)
  private
    FSubscription: IEventSubscription;
    FLogFile: TStreamWriter;
  protected
    procedure Execute; override;
  end;

procedure TLoggerThread.Execute;
begin
  EventBus.RegisterThread;
  try
    FLogFile := TStreamWriter.Create('app.log', True);
    try
      FSubscription := EventBus.Subscribe<TLogEvent>(
        procedure(const evt: TLogEvent)
        begin
          FLogFile.WriteLine(Format('[%s] [%d] %s: %s',
            [FormatDateTime('yyyy-mm-dd hh:nn:ss', evt.Timestamp),
             evt.ThreadID,
             GetEnumName(TypeInfo(TLogLevel), Ord(evt.Level)),
             evt.Message]));
        end);

      while not Terminated do
        SleepEx(100, True);
    finally
      FLogFile.Free;
    end;
  finally
    EventBus.UnregisterThread;
  end;
end;

// Usage from anywhere
procedure Log(level: TLogLevel; const msg: string);
var
  evt: TLogEvent;
begin
  evt.Level := level;
  evt.Message := msg;
  evt.ThreadID := GetCurrentThreadId;
  evt.Timestamp := Now;
  EventBus.Fire<TLogEvent>(evt);
end;
```

### Example 2: Progress Reporting

```delphi
type
  TProgressEvent = record
    TaskName: string;
    Current: Integer;
    Total: Integer;
    Percentage: Double;
  end;

// UI (main thread)
procedure TMainForm.AfterConstruction;
begin
  inherited;
  FProgressSubscription := EventBus.Subscribe<TProgressEvent>(
    procedure(const evt: TProgressEvent)
    begin
      ProgressBar1.Position := Round(evt.Percentage);
      StatusBar1.SimpleText := Format('%s: %d/%d',
        [evt.TaskName, evt.Current, evt.Total]);
    end);
end;

// Worker thread
procedure TProcessor.ProcessFiles(const files: TArray<string>);
var
  i: Integer;
  evt: TProgressEvent;
begin
  evt.TaskName := 'Processing files';
  evt.Total := Length(files);

  for i := 0 to High(files) do
  begin
    ProcessFile(files[i]);

    evt.Current := i + 1;
    evt.Percentage := (evt.Current / evt.Total) * 100;
    EventBus.Fire<TProgressEvent>(evt);
  end;
end;
```

## Version History

### 1.01 (2026-02-16)

- Automatic alertable wait testing in DEBUG builds (integrated into `RegisterThread`)
- Automatic detection of threads not using alertable waits
- Clear error messages when alertable wait requirement is violated

### 1.0 (2026-02-13)

- Initial release
- Type-safe event bus with record-constrained events
- Cross-thread dispatch via QueueUserAPC for background threads
- TThread.Queue for main thread dispatch
- Dead thread detection and cleanup
- TLightweightMREW for efficient reader-writer locking

## See Also

- [GpQueueExec.pas](GpQueueExec.pas) - Alternative cross-thread dispatch using hidden windows
- [System.SyncObjs](https://docwiki.embarcadero.com/Libraries/en/System.SyncObjs) - Delphi synchronization primitives
- [QueueUserAPC (MSDN)](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-queueuserapc) - Win32 APC documentation
