# GpEventBus Test Application

## Overview

This test application demonstrates all features of the `GpEventBus` cross-thread event system.

## What It Demonstrates

### 1. **Main Thread Events** (Tab 1)

- **Log Event Display**: Subscribe to `TLogEvent` from main thread, display with colored text
- **Fire Events**: Send Info/Warning/Error log events from main thread
- **Progress Events**: Subscribe to progress updates, update progress bar in real-time
- **Data Events**: Subscribe to data events, display in status bar
- **Dynamic Subscription**: Subscribe/unsubscribe at runtime, see live subscription counts

### 2. **Background Threads** (Tab 2)

- **Worker Thread 1 & 2**: Independent background threads that:
  - Register with EventBus using `RegisterThread`
  - Subscribe to `TLogEvent` and `TDataEvent`
  - Use **alertable wait** (`WaitForSingleObjectEx`) - critical for QueueUserAPC
  - Receive events in their own thread context
  - Log received events to their own memo controls
  - Properly unregister when stopped

- **Event Producer Thread**: Background thread that:
  - Periodically fires events from a non-main thread
  - Fires different event types (TLogEvent, TProgressEvent, TDataEvent)
  - Demonstrates cross-thread event production
  - Configurable interval

### 3. **Event Log** (Tab 3)

- Global log of all system events (thread starts/stops, subscriptions, event fires)
- Timestamped entries
- Shows main thread ID for reference

## Event Types

```delphi
// Log events with severity levels
TLogEvent = record
  Level: TLogLevel;       // llDebug, llInfo, llWarning, llError
  Message: string;
  ThreadID: TThreadID;
  Timestamp: TDateTime;
end;

// Progress reporting
TProgressEvent = record
  TaskName: string;
  Current: Integer;
  Total: Integer;
  Percentage: Double;
end;

// Generic data events
TDataEvent = record
  DataID: Integer;
  Description: string;
  Value: Double;
end;
```

## How to Use

### Test Scenario 1: Main Thread Only

1. Go to **Main Thread Events** tab
2. Click **Subscribe** under "Log Event Subscription"
3. Click **Fire Info Event**, **Fire Warning Event**, **Fire Error Event**
4. Observe colored log messages appear in the memo
5. Click **Unsubscribe** to stop receiving events

### Test Scenario 2: Cross-Thread Events

1. Go to **Background Threads** tab
2. Click **Start Worker 1**
3. Go back to **Main Thread Events** tab
4. Click **Fire Info Event**
5. Switch to **Background Threads** tab
6. Observe the event appears in Worker 1's memo
7. The event was fired from main thread but received in Worker 1's thread!

### Test Scenario 3: Multiple Subscribers

1. Go to **Main Thread Events** tab
2. Click **Subscribe** for Log Events
3. Go to **Background Threads** tab
4. Click **Start Worker 1** and **Start Worker 2**
5. Go back to **Main Thread Events** tab
6. Click **Fire Info Event**
7. Observe the event appears in:
   - Main thread memo (colored)
   - Worker 1 memo
   - Worker 2 memo
8. One event, three subscribers in different threads!

### Test Scenario 4: Background Event Producer

1. Go to **Main Thread Events** tab
2. Subscribe to **Log Events**, **Progress Events**, and **Data Events**
3. Go to **Background Threads** tab
4. Click **Start Worker 1** (optional: start Worker 2)
5. Enter interval (e.g., 1000 ms)
6. Click **Start Producer**
7. Observe:
   - Progress bar updating automatically
   - Log messages appearing
   - Status bar showing data values
   - Worker threads receiving events
8. All events are fired from Producer thread, received by main thread and workers!

### Test Scenario 5: Thread Lifecycle

1. Go to **Background Threads** tab
2. Click **Start Worker 1**
3. Observe messages in Worker 1 memo:
   - "Starting, ThreadID=..."
   - "Registered with EventBus"
   - "Subscribed to events"
4. Click **Stop Worker 1**
5. Observe shutdown messages:
   - "Shutting down"
   - "Unregistered from EventBus"
6. Go to **Event Log** tab to see complete lifecycle

### Test Scenario 6: Subscription Counts

1. Observe the **Subscriptions: X** labels throughout the UI
2. These update every 500ms via Timer
3. Start/stop workers and subscribe/unsubscribe to see counts change
4. Demonstrates `EventBus.SubscriptionCount<T>` API

## Key Implementation Details

### Worker Thread Structure

```delphi
procedure TWorkerThread.Execute;
begin
  EventBus.RegisterThread;  // STEP 1: Register
  try
    // STEP 2: Subscribe
    FSubscriptions.Add(EventBus.Subscribe<TLogEvent>(...));

    // STEP 3: Alertable wait loop (CRITICAL!)
    while WaitForSingleObjectEx(FStopEvent.Handle, 100, True) <> WAIT_OBJECT_0 do
    begin
      // APCs execute here
    end;
  finally
    FSubscriptions.Clear;       // STEP 4: Unsubscribe
    EventBus.UnregisterThread;  // STEP 5: Unregister
  end;
end;
```

**Critical:** The `True` parameter in `WaitForSingleObjectEx` enables alertable wait, allowing QueueUserAPC to deliver events.

### Producer Thread Structure

```delphi
procedure TEventProducerThread.Execute;
begin
  while WaitForSingleObjectEx(FStopEvent.Handle, FInterval_ms, True) <> WAIT_OBJECT_0 do
  begin
    // Fire events from background thread
    EventBus.Fire<TLogEvent>(...);
    EventBus.Fire<TProgressEvent>(...);
    EventBus.Fire<TDataEvent>(...);
  end;
end;
```

Note: Producer doesn't subscribe to events, only fires them.

## What You Should Observe

### Thread Safety

- Multiple threads can fire events simultaneously
- Multiple threads can subscribe/unsubscribe simultaneously
- No crashes, no access violations
- Events never lost (with proper alertable waits)

### Cross-Thread Dispatch

- Events fired from main thread appear in worker threads
- Events fired from producer thread appear in main thread and workers
- Each subscriber receives events in its own thread context

### Performance

- High-frequency events (fast producer interval) handled efficiently
- Coalescing pattern: only one APC in flight per thread at a time
- UI remains responsive even with many events

### Proper Cleanup

- Stopping workers removes their subscriptions
- Subscription counts decrease
- No resource leaks (check with FastMM or AQTime)

## Troubleshooting

### Events not appearing in worker threads

- **Cause:** Forgot alertable wait
- **Fix:** Ensure `WaitForSingleObjectEx(..., True)` has `True` parameter

### "Thread X is not registered" exception

- **Cause:** Forgot to call `RegisterThread`
- **Fix:** Add `EventBus.RegisterThread` before subscribing

### Access violation on shutdown

- **Cause:** Forgot to unregister thread
- **Fix:** Add `EventBus.UnregisterThread` in finally block

### Progress bar not updating

- **Cause:** Not subscribed to `TProgressEvent`
- **Fix:** Click "Subscribe" button for Progress Events

## Expected Output Examples

### Main Thread Log Memo (with colors)

```
[14:23:45.123] [Thread 12345] [llInfo] Info message from main thread
[14:23:46.456] [Thread 67890] [llInfo] Producer event #1
[14:23:47.789] [Thread 12345] [llWarning] Warning message from main thread
```

### Worker 1 Memo

```
[14:23:40.000] Worker-1: Starting, ThreadID=67890
[14:23:40.010] Worker-1: Registered with EventBus
[14:23:40.015] Worker-1: Subscribed to events
[14:23:45.125] Received LogEvent: [llInfo] Info message from main thread (from thread 12345)
[14:23:46.458] Received LogEvent: [llInfo] Producer event #1 (from thread 99999)
```

### Event Log

```
[14:23:35.000] Application started
[14:23:35.005] Main thread ID: 12345
[14:23:38.000] Subscribed to TLogEvent (main thread)
[14:23:40.000] Started Worker Thread 1
[14:23:45.000] Fired TLogEvent (Info)
```

## Performance Test

1. Set producer interval to **100** ms (10 events/sec)
2. Start both workers
3. Subscribe to all event types in main thread
4. Start producer
5. Let run for 10 seconds
6. Observe: UI still responsive, all events delivered

Expected: ~100 events fired, ~300 events delivered (1 fire → 3 subscribers)

## Compilation

### Requirements

- Delphi 12+ (uses generics, anonymous methods, managed records)
- Windows only
- VCL application

### Build

```bash
cd X:\gp\common\tests
"C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc32.exe" -B -U.. testGpEventBus.dpr
./testGpEventBus.exe
```

## Files

- `testGpEventBus.dpr` - Project file
- `testGpEventBusMain.pas` - Main form unit
- `testGpEventBusMain.dfm` - Form layout
- `testGpEventBus.md` - This file
- `../GpEventBus.pas` - Event bus implementation

## See Also

- [GpEventBus.md](../GpEventBus.md) - Full EventBus documentation
- [GpEventBus.pas](../GpEventBus.pas) - Implementation source
