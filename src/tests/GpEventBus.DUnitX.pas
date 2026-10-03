unit GpEventBus.DUnitX;

{
  DUnitX test suite for GpEventBus

  Note: Cross-thread dispatch tests require VCL message loop and are expected
  to fail in console DUnitX environment. These tests work correctly in VCL
  applications (verified with testGpEventBus.exe demo).

  Cross-thread tests (expected to fail in console):
  - TestCrossThreadMainToBackground
  - TestCrossThreadBackgroundToMain
  - TestMultipleBackgroundThreads
  - TestAPCFlagClearingMultipleEvents
  - TestMultipleWorkersSimultaneousDispatch

  Same-thread tests (pass in all environments):
  - All other tests work correctly in console and VCL applications
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  Winapi.Windows,
  GpEventBus;

type
  // Test event types
  TTestEvent = record
    Value: Integer;
    Message: string;
    class function Create(AValue: Integer; const AMessage: string): TTestEvent; static;
  end;

  TCounterEvent = record
    Counter: Integer;
  end;

  [TestFixture]
  TGpEventBusTests = class
  private
    FEventBus: TEventBus;
    FReceivedEvents: TList<TTestEvent>;
    FEventCount: Integer;
    FLock: TCriticalSection;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestBasicSubscribeAndFire;
    [Test]
    procedure TestMultipleSubscribers;
    [Test]
    procedure TestUnsubscribe;
    [Test]
    procedure TestUnsubscribeAll;
    [Test]
    procedure TestSubscriptionCount;
    [Test]
    procedure TestCrossThreadMainToBackground;
    [Test]
    procedure TestMultipleBackgroundThreads;
    [Test]
    procedure TestThreadRegistration;
    [Test]
    procedure TestUnregisterThreadCleansUpSubscriptions;
    [Test]
    procedure TestEventDataCopying;
    [Test]
    procedure TestNoSubscribers;
    [Test]
    procedure TestSubscriptionIsActive;
    [Test]
    procedure TestSingletonEventBus;
    [Test]
    procedure TestAPCFlagClearingMultipleEvents;
    [Test]
    procedure TestMultipleWorkersSimultaneousDispatch;
    [Test]
    procedure TestStressAPCQueueing;
  end;

  // Helper thread for cross-thread tests
  TTestWorkerThread = class(TThread)
  private
    FEventBus: TEventBus;
    FSubscription: IEventSubscription;
    FOnEventReceived: TEventHandler<TTestEvent>;
    FReadyEvent: TEvent;
    FStopEvent: TEvent;
    FEventReceived: TEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(AEventBus: TEventBus; const AOnEventReceived: TEventHandler<TTestEvent>);
    destructor Destroy; override;
    procedure WaitUntilReady;
    procedure WaitForEvent(timeout_ms: Integer);
    procedure Stop;
  end;

implementation

uses
  System.DateUtils;

{ TTestEvent }

class function TTestEvent.Create(AValue: Integer; const AMessage: string): TTestEvent;
begin
  Result.Value := AValue;
  Result.Message := AMessage;
end;

{ TTestWorkerThread }

constructor TTestWorkerThread.Create(AEventBus: TEventBus; const AOnEventReceived: TEventHandler<TTestEvent>);
begin
  inherited Create(True);
  FEventBus := AEventBus;
  FOnEventReceived := AOnEventReceived;
  FReadyEvent := TEvent.Create(nil, True, False, '');
  FStopEvent := TEvent.Create(nil, True, False, '');
  FEventReceived := TEvent.Create(nil, True, False, '');
  FreeOnTerminate := False;
end;

destructor TTestWorkerThread.Destroy;
begin
  FreeAndNil(FReadyEvent);
  FreeAndNil(FStopEvent);
  FreeAndNil(FEventReceived);
  inherited;
end;

procedure TTestWorkerThread.Execute;
begin
  FEventBus.RegisterThread;
  try
    FSubscription := FEventBus.Subscribe<TTestEvent>(
      procedure(const evt: TTestEvent)
      begin
        if Assigned(FOnEventReceived) then
          FOnEventReceived(evt);
        FEventReceived.SetEvent;
      end);

    FReadyEvent.SetEvent;

    while WaitForSingleObjectEx(FStopEvent.Handle, 100, True) <> WAIT_OBJECT_0 do
    begin
      // Alertable wait - critical for QueueUserAPC
    end;
  finally
    FSubscription := nil;
    FEventBus.UnregisterThread;
  end;
end;

procedure TTestWorkerThread.WaitUntilReady;
begin
  FReadyEvent.WaitFor(5000);
end;

procedure TTestWorkerThread.WaitForEvent(timeout_ms: Integer);
begin
  FEventReceived.WaitFor(timeout_ms);
  FEventReceived.ResetEvent;
end;

procedure TTestWorkerThread.Stop;
begin
  FStopEvent.SetEvent;
end;

{ TGpEventBusTests }

procedure TGpEventBusTests.Setup;
begin
  FEventBus := CreateEventBus;
  FEventBus.RegisterThread; // Register main test thread
  FReceivedEvents := TList<TTestEvent>.Create;
  FEventCount := 0;
  FLock := TCriticalSection.Create;
end;

procedure TGpEventBusTests.TearDown;
begin
  FreeAndNil(FReceivedEvents);
  FreeAndNil(FLock);
  FEventBus.UnregisterThread; // Unregister main test thread
  FreeAndNil(FEventBus);
end;

procedure TGpEventBusTests.TestBasicSubscribeAndFire;
var
  subscription: IEventSubscription;
  received: Boolean;
  receivedEvent: TTestEvent;
begin
  received := False;

  subscription := FEventBus.Subscribe<TTestEvent>(
    procedure(const evt: TTestEvent)
    begin
      received := True;
      receivedEvent := evt;
    end);

  try
    FEventBus.Fire<TTestEvent>(TTestEvent.Create(42, 'test message'));

    Assert.IsTrue(received, 'Event should have been received');
    Assert.AreEqual(42, receivedEvent.Value);
    Assert.AreEqual('test message', receivedEvent.Message);
  finally
    subscription.Unsubscribe;
  end;
end;

procedure TGpEventBusTests.TestMultipleSubscribers;
var
  sub1, sub2, sub3: IEventSubscription;
  count1, count2, count3: Integer;
begin
  count1 := 0;
  count2 := 0;
  count3 := 0;

  sub1 := FEventBus.Subscribe<TTestEvent>(procedure(const evt: TTestEvent) begin Inc(count1); end);
  sub2 := FEventBus.Subscribe<TTestEvent>(procedure(const evt: TTestEvent) begin Inc(count2); end);
  sub3 := FEventBus.Subscribe<TTestEvent>(procedure(const evt: TTestEvent) begin Inc(count3); end);

  try
    FEventBus.Fire<TTestEvent>(TTestEvent.Create(1, 'test'));

    Assert.AreEqual(1, count1, 'Subscriber 1 should receive event');
    Assert.AreEqual(1, count2, 'Subscriber 2 should receive event');
    Assert.AreEqual(1, count3, 'Subscriber 3 should receive event');

    FEventBus.Fire<TTestEvent>(TTestEvent.Create(2, 'test2'));

    Assert.AreEqual(2, count1);
    Assert.AreEqual(2, count2);
    Assert.AreEqual(2, count3);
  finally
    sub1.Unsubscribe;
    sub2.Unsubscribe;
    sub3.Unsubscribe;
  end;
end;

procedure TGpEventBusTests.TestUnsubscribe;
var
  subscription: IEventSubscription;
  count: Integer;
begin
  count := 0;

  subscription := FEventBus.Subscribe<TTestEvent>(
    procedure(const evt: TTestEvent)
    begin
      Inc(count);
    end);

  FEventBus.Fire<TTestEvent>(TTestEvent.Create(1, 'test'));
  Assert.AreEqual(1, count, 'Should receive first event');

  subscription.Unsubscribe;

  FEventBus.Fire<TTestEvent>(TTestEvent.Create(2, 'test'));
  Assert.AreEqual(1, count, 'Should not receive event after unsubscribe');
end;

procedure TGpEventBusTests.TestUnsubscribeAll;
var
  sub1, sub2: IEventSubscription;
  count1, count2: Integer;
begin
  count1 := 0;
  count2 := 0;

  sub1 := FEventBus.Subscribe<TTestEvent>(procedure(const evt: TTestEvent) begin Inc(count1); end);
  sub2 := FEventBus.Subscribe<TTestEvent>(procedure(const evt: TTestEvent) begin Inc(count2); end);

  FEventBus.Fire<TTestEvent>(TTestEvent.Create(1, 'test'));
  Assert.AreEqual(1, count1);
  Assert.AreEqual(1, count2);

  FEventBus.UnsubscribeAll<TTestEvent>;

  FEventBus.Fire<TTestEvent>(TTestEvent.Create(2, 'test'));
  Assert.AreEqual(1, count1, 'Should not receive after UnsubscribeAll');
  Assert.AreEqual(1, count2, 'Should not receive after UnsubscribeAll');
end;

procedure TGpEventBusTests.TestSubscriptionCount;
var
  sub1, sub2, sub3: IEventSubscription;
begin
  Assert.AreEqual(0, FEventBus.SubscriptionCount<TTestEvent>, 'Initial count should be 0');

  sub1 := FEventBus.Subscribe<TTestEvent>(procedure(const evt: TTestEvent) begin end);
  Assert.AreEqual(1, FEventBus.SubscriptionCount<TTestEvent>);

  sub2 := FEventBus.Subscribe<TTestEvent>(procedure(const evt: TTestEvent) begin end);
  Assert.AreEqual(2, FEventBus.SubscriptionCount<TTestEvent>);

  sub3 := FEventBus.Subscribe<TTestEvent>(procedure(const evt: TTestEvent) begin end);
  Assert.AreEqual(3, FEventBus.SubscriptionCount<TTestEvent>);

  sub1.Unsubscribe;
  Assert.AreEqual(2, FEventBus.SubscriptionCount<TTestEvent>);

  sub2.Unsubscribe;
  sub3.Unsubscribe;
  Assert.AreEqual(0, FEventBus.SubscriptionCount<TTestEvent>);
end;

procedure TGpEventBusTests.TestCrossThreadMainToBackground;
var
  worker: TTestWorkerThread;
  receivedValue: Integer;
  receivedMessage: string;
  handler: TEventHandler<TTestEvent>;
begin
  receivedValue := 0;
  receivedMessage := '';

  handler := procedure(const evt: TTestEvent)
    begin
      receivedValue := evt.Value;
      receivedMessage := evt.Message;
    end;

  worker := TTestWorkerThread.Create(FEventBus, handler);
  try
    worker.Start;
    worker.WaitUntilReady;

    // Fire from main thread
    FEventBus.Fire<TTestEvent>(TTestEvent.Create(123, 'cross-thread test'));

    // Wait for worker to receive
    worker.WaitForEvent(2000);

    Assert.AreEqual(123, receivedValue, 'Worker should receive correct value');
    Assert.AreEqual('cross-thread test', receivedMessage, 'Worker should receive correct message');
  finally
    worker.Stop;
    worker.WaitFor;
    worker.Free;
  end;
end;

procedure TGpEventBusTests.TestMultipleBackgroundThreads;
var
  worker1, worker2, worker3: TTestWorkerThread;
  count1, count2, count3: Integer;
begin
  count1 := 0;
  count2 := 0;
  count3 := 0;

  worker1 := TTestWorkerThread.Create(FEventBus, procedure(const evt: TTestEvent) begin TInterlocked.Increment(count1); end);
  worker2 := TTestWorkerThread.Create(FEventBus, procedure(const evt: TTestEvent) begin TInterlocked.Increment(count2); end);
  worker3 := TTestWorkerThread.Create(FEventBus, procedure(const evt: TTestEvent) begin TInterlocked.Increment(count3); end);
  try
    worker1.Start;
    worker2.Start;
    worker3.Start;
    worker1.WaitUntilReady;
    worker2.WaitUntilReady;
    worker3.WaitUntilReady;

    Assert.AreEqual(3, FEventBus.SubscriptionCount<TTestEvent>, 'Should have 3 subscriptions');

    FEventBus.Fire<TTestEvent>(TTestEvent.Create(1, 'test'));

    worker1.WaitForEvent(1000);
    worker2.WaitForEvent(1000);
    worker3.WaitForEvent(1000);

    Assert.AreEqual(1, count1, 'Worker 1 should receive event');
    Assert.AreEqual(1, count2, 'Worker 2 should receive event');
    Assert.AreEqual(1, count3, 'Worker 3 should receive event');
  finally
    worker1.Stop;
    worker2.Stop;
    worker3.Stop;
    worker1.WaitFor;
    worker2.WaitFor;
    worker3.WaitFor;
    worker1.Free;
    worker2.Free;
    worker3.Free;
  end;
end;

procedure TGpEventBusTests.TestThreadRegistration;
var
  worker: TThread;
  exceptionRaised: Boolean;
begin
  // Test that background thread must call RegisterThread before subscribing
  exceptionRaised := False;
  worker := TThread.CreateAnonymousThread(
    procedure
    begin
      try
        FEventBus.Subscribe<TTestEvent>(procedure(const evt: TTestEvent) begin end);
      except
        on E: Exception do
          exceptionRaised := True;
      end;
    end);
  worker.FreeOnTerminate := False;
  worker.Start;
  worker.WaitFor;
  worker.Free;

  Assert.IsTrue(exceptionRaised, 'Should raise exception when subscribing without RegisterThread');
end;

procedure TGpEventBusTests.TestUnregisterThreadCleansUpSubscriptions;
var
  worker: TTestWorkerThread;
  noHandler: TEventHandler<TTestEvent>;
begin
  noHandler := nil;
  worker := TTestWorkerThread.Create(FEventBus, noHandler);
  try
    worker.Start;
    worker.WaitUntilReady;

    Assert.AreEqual(1, FEventBus.SubscriptionCount<TTestEvent>, 'Should have 1 subscription');

    worker.Stop;
    worker.WaitFor;

    Sleep(100); // Give cleanup time

    Assert.AreEqual(0, FEventBus.SubscriptionCount<TTestEvent>, 'Subscription should be cleaned up');
  finally
    if not worker.Finished then
    begin
      worker.Stop;
      worker.WaitFor;
    end;
    worker.Free;
  end;
end;

procedure TGpEventBusTests.TestEventDataCopying;
var
  subscription: IEventSubscription;
  originalEvent: TTestEvent;
  receivedEvent: TTestEvent;
begin
  originalEvent := TTestEvent.Create(100, 'original');

  subscription := FEventBus.Subscribe<TTestEvent>(
    procedure(const evt: TTestEvent)
    begin
      receivedEvent := evt;
    end);

  try
    FEventBus.Fire<TTestEvent>(originalEvent);

    // Modify original after firing
    originalEvent.Value := 999;
    originalEvent.Message := 'modified';

    // Received event should still have original values
    Assert.AreEqual(100, receivedEvent.Value, 'Event data should be copied');
    Assert.AreEqual('original', receivedEvent.Message, 'Event data should be copied');
  finally
    subscription.Unsubscribe;
  end;
end;

procedure TGpEventBusTests.TestNoSubscribers;
var
  exceptionRaised: Boolean;
begin
  // Should not raise exception when firing with no subscribers
  exceptionRaised := False;
  try
    FEventBus.Fire<TTestEvent>(TTestEvent.Create(1, 'test'));
  except
    exceptionRaised := True;
  end;
  Assert.IsFalse(exceptionRaised, 'Should not raise exception when firing with no subscribers');
end;

procedure TGpEventBusTests.TestSubscriptionIsActive;
var
  subscription: IEventSubscription;
begin
  subscription := FEventBus.Subscribe<TTestEvent>(
    procedure(const evt: TTestEvent)
    begin
    end);

  Assert.IsTrue(subscription.IsActive, 'Subscription should be active after creation');

  subscription.Unsubscribe;

  Assert.IsFalse(subscription.IsActive, 'Subscription should not be active after unsubscribe');
end;

procedure TGpEventBusTests.TestSingletonEventBus;
var
  bus1, bus2: TEventBus;
begin
  bus1 := EventBus;
  bus2 := EventBus;

  Assert.AreSame(bus1, bus2, 'EventBus function should return singleton');
end;

procedure TGpEventBusTests.TestAPCFlagClearingMultipleEvents;
// Tests Bug Fix: APCSignaled flag must be cleared after APC callback
// Without proper clearing, only the first event would be received
// NOTE: Requires VCL message loop - expected to fail in console DUnitX tests
var
  worker: TTestWorkerThread;
  receivedCount: Integer;
  i: Integer;
const
  EVENT_COUNT = 20;  // Fire many events rapidly to test APC flag clearing
begin
  receivedCount := 0;

  worker := TTestWorkerThread.Create(FEventBus,
    procedure(const evt: TTestEvent)
    begin
      TInterlocked.Increment(receivedCount);
    end);
  try
    worker.Start;
    worker.WaitUntilReady;

    // Fire multiple events rapidly to test that APCSignaled flag is properly cleared
    // If flag isn't cleared, only the first event would be received
    for i := 1 to EVENT_COUNT do
    begin
      FEventBus.Fire<TTestEvent>(TTestEvent.Create(i, 'event ' + IntToStr(i)));
      Sleep(10);  // Small delay to allow processing
    end;

    // Wait for all events to be processed
    Sleep(500);

    Assert.AreEqual(EVENT_COUNT, receivedCount,
      'Worker should receive all events (tests APCSignaled flag clearing)');
  finally
    worker.Stop;
    worker.WaitFor;
    worker.Free;
  end;
end;

procedure TGpEventBusTests.TestMultipleWorkersSimultaneousDispatch;
// Tests Bug Fix: TThreadDispatchState must be class (not record) to prevent race conditions
// With record type, workers would steal events from each other (only one receives at a time)
// NOTE: Requires VCL message loop - expected to fail in console DUnitX tests
var
  worker1, worker2, worker3: TTestWorkerThread;
  count1, count2, count3: Integer;
  i: Integer;
const
  EVENT_COUNT = 10;
begin
  count1 := 0;
  count2 := 0;
  count3 := 0;

  // Start 3 workers that all subscribe to same event
  worker1 := TTestWorkerThread.Create(FEventBus,
    procedure(const evt: TTestEvent) begin TInterlocked.Increment(count1); end);
  worker2 := TTestWorkerThread.Create(FEventBus,
    procedure(const evt: TTestEvent) begin TInterlocked.Increment(count2); end);
  worker3 := TTestWorkerThread.Create(FEventBus,
    procedure(const evt: TTestEvent) begin TInterlocked.Increment(count3); end);
  try
    worker1.Start;
    worker2.Start;
    worker3.Start;
    worker1.WaitUntilReady;
    worker2.WaitUntilReady;
    worker3.WaitUntilReady;

    Assert.AreEqual(3, FEventBus.SubscriptionCount<TTestEvent>,
      'Should have 3 active subscriptions');

    // Fire multiple events - ALL workers should receive ALL events simultaneously
    for i := 1 to EVENT_COUNT do
    begin
      FEventBus.Fire<TTestEvent>(TTestEvent.Create(i, 'broadcast ' + IntToStr(i)));
      Sleep(20);  // Small delay between events
    end;

    // Wait for processing
    Sleep(500);

    // All three workers should have received all events
    // This tests that TThreadDispatchState being a class prevents race conditions
    Assert.AreEqual(EVENT_COUNT, count1, 'Worker 1 should receive all events');
    Assert.AreEqual(EVENT_COUNT, count2, 'Worker 2 should receive all events');
    Assert.AreEqual(EVENT_COUNT, count3, 'Worker 3 should receive all events');
  finally
    worker1.Stop;
    worker2.Stop;
    worker3.Stop;
    worker1.WaitFor;
    worker2.WaitFor;
    worker3.WaitFor;
    worker1.Free;
    worker2.Free;
    worker3.Free;
  end;
end;

procedure TGpEventBusTests.TestStressAPCQueueing;
// Stress test: Generate 100,000 events rapidly and verify all are received
// Tests APC coalescing, race condition handling, and that no events are lost
var
  producerThread: TThread;
  worker: TTestWorkerThread;
  receivedCount: Integer;
  allEventsReceived: TEvent;
const
  EVENT_COUNT = 100000;
begin
  receivedCount := 0;
  allEventsReceived := TEvent.Create(nil, True, False, '');
  try
    // Create worker that counts events
    worker := TTestWorkerThread.Create(FEventBus,
      procedure(const evt: TTestEvent)
      var
        count: Integer;
      begin
        count := TInterlocked.Increment(receivedCount);
        if count = EVENT_COUNT then
          allEventsReceived.SetEvent;
      end);
    try
      worker.Start;
      worker.WaitUntilReady;

      // Create producer thread that fires events as fast as possible
      producerThread := TThread.CreateAnonymousThread(
        procedure
        var
          i: Integer;
        begin
          FEventBus.RegisterThread;
          try
            for i := 1 to EVENT_COUNT do
              FEventBus.Fire<TTestEvent>(TTestEvent.Create(i, 'stress'));
          finally
            FEventBus.UnregisterThread;
          end;
        end);
      try
        producerThread.FreeOnTerminate := False;
        producerThread.Start;
        producerThread.WaitFor;

        // Wait for all events to be processed (max 30 seconds)
        if allEventsReceived.WaitFor(30000) <> wrSignaled then
          Assert.Fail(Format('Timeout waiting for events. Received %d/%d',
            [receivedCount, EVENT_COUNT]));

        // Verify all events received
        Assert.AreEqual(EVENT_COUNT, receivedCount,
          'All events should be received (tests APC coalescing and race condition handling)');
      finally
        producerThread.Free;
      end;
    finally
      worker.Stop;
      worker.WaitFor;
      worker.Free;
    end;
  finally
    allEventsReceived.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TGpEventBusTests);

end.
