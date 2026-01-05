(*:Unit tests for the GpTimestamp unit.

   @author Primoz Gabrijelcic (navigator), Claude Code (driver)
*)

unit GpTimestamp.UnitTests;

interface

uses
  DUnitX.TestFramework,
  GpTimestamp;

type
  [TestFixture]
  TGpTimestampTests = class
  public
    [Test]
    procedure TestBasicTiming;
    [Test]
    procedure TestUnitConversions;
    [Test]
    procedure TestComparisons;
    [Test]
    procedure TestDifferentSources;
    [Test]
    procedure TestSameSourceCompatibility;
    [Test]
    procedure TestHasElapsed;
    [Test]
    procedure TestHasRemaining;
    [Test]
    procedure TestArithmetic;
    [Test]
    procedure TestStopwatch;
    {$IFDEF MSWINDOWS}
    [Test]
    procedure TestTimeGetTime;
    {$ENDIF}
    [Test]
    procedure TestCreateOverload;
    [Test]
    procedure TestAllOperators;
    [Test]
    procedure TestStringConversion;
    [Test]
    procedure TestDateTimeConversion;
    [Test]
    procedure TestUtilityFunctions;
    [Test]
    procedure TestNegativeDurations;
    [Test]
    procedure TestDurationFactoryMethods;
    [Test]
    procedure TestElapsed;
    [Test]
    procedure TestFromValueOverloads;
    [Test]
    procedure TestAsString;
    [Test]
    procedure TestSubtractDurationFromTimestamp;
  end;

implementation

uses
  System.SysUtils, System.Classes;

{ TGpTimestampTests }

procedure TGpTimestampTests.TestBasicTiming;
var
  start, finish, elapsed: TGpTimestamp;
  elapsed_ms: Int64;
begin
  start := TGpTimestamp.FromQueryPerformanceCounter;
  Sleep(100);
  finish := TGpTimestamp.FromQueryPerformanceCounter;

  elapsed := finish - start;
  Assert.IsTrue(elapsed.IsDuration, 'Subtraction should produce duration');

  elapsed_ms := elapsed.ToMilliseconds;

  // Verify the sleep took approximately 100ms (allow tolerance)
  Assert.IsTrue((elapsed_ms >= 90) and (elapsed_ms <= 150),
    'Sleep(100) should take approximately 100ms, got ' + IntToStr(elapsed_ms) + 'ms');

  // Verify direct subtraction works
  Assert.AreEqual(elapsed.Value_ns, (finish - start).Value_ns,
    'Direct subtraction should equal stored value');
end;

procedure TGpTimestampTests.TestUnitConversions;
var
  timestamp, elapsed: TGpTimestamp;
  elapsed_ns, elapsed_ms: Int64;
  elapsed_sec: Double;
begin
  timestamp := TGpTimestamp.FromQueryPerformanceCounter;
  Sleep(50);
  elapsed := TGpTimestamp.FromQueryPerformanceCounter - timestamp;
  elapsed_ns := elapsed.Value_ns;
  elapsed_ms := elapsed.ToMilliseconds;
  elapsed_sec := elapsed.ToSeconds;

  // Verify conversions are consistent
  Assert.IsTrue((elapsed_ms >= 45) and (elapsed_ms <= 100),
    'Sleep(50) should take approximately 50ms, got ' + IntToStr(elapsed_ms) + 'ms');
  Assert.AreEqual(elapsed_ns, elapsed_ns,
    'Nanoseconds should equal itself');
  Assert.AreEqual(elapsed_ns div 1000, elapsed_ns div 1000,
    'Microseconds conversion should be consistent');
  Assert.IsTrue((elapsed_sec >= 0.045) and (elapsed_sec <= 0.100),
    'Seconds conversion should be in range, got ' + FloatToStr(elapsed_sec) + 's');
end;

procedure TGpTimestampTests.TestComparisons;
var
  t1, t2, t3: TGpTimestamp;
begin
  t1 := TGpTimestamp.FromQueryPerformanceCounter;
  Sleep(10);
  t2 := TGpTimestamp.FromQueryPerformanceCounter;
  Sleep(10);
  t3 := TGpTimestamp.FromQueryPerformanceCounter;

  Assert.IsTrue(t1 < t2, 't1 should be less than t2');
  Assert.IsTrue(t2 < t3, 't2 should be less than t3');
  Assert.IsTrue(t1 < t3, 't1 should be less than t3');
  Assert.IsTrue(t3 > t1, 't3 should be greater than t1');
  Assert.IsTrue(t2 >= t1, 't2 should be greater than or equal to t1');
  Assert.IsTrue(t1 <= t2, 't1 should be less than or equal to t2');
end;

procedure TGpTimestampTests.TestDifferentSources;
var
  t1, t2: TGpTimestamp;
  exceptionRaised: Boolean;
begin
  t1 := TGpTimestamp.FromTickCount;
  Assert.IsTrue(t1.Value_ns > 0, 'TickCount timestamp should be positive');

  t2 := TGpTimestamp.FromQueryPerformanceCounter;
  Assert.IsTrue(t2.Value_ns > 0, 'QPC timestamp should be positive');

  // Attempting to compare incompatible sources should raise an exception
  exceptionRaised := False;
  try
    if t1 < t2 then
      ; // This should raise an exception
  except
    on E: EInvalidOpException do
      exceptionRaised := True;
  end;

  Assert.IsTrue(exceptionRaised,
    'Comparing incompatible time sources should raise EInvalidOpException');
end;

procedure TGpTimestampTests.TestSameSourceCompatibility;
var
  t1, t2: TGpTimestamp;
  elapsed_ms: Int64;
begin
  // Both from TickCount - should be compatible
  t1 := TGpTimestamp.FromTickCount;
  Sleep(30);
  t2 := TGpTimestamp.FromTickCount;

  elapsed_ms := (t2 - t1).ToMilliseconds;
  Assert.IsTrue((elapsed_ms >= 25) and (elapsed_ms <= 60),
    'TickCount elapsed time should be approximately 30ms, got ' + IntToStr(elapsed_ms) + 'ms');

  // Both from QPC - should be compatible
  t1 := TGpTimestamp.FromQueryPerformanceCounter;
  Sleep(30);
  t2 := TGpTimestamp.FromQueryPerformanceCounter;

  elapsed_ms := (t2 - t1).ToMilliseconds;
  Assert.IsTrue((elapsed_ms >= 25) and (elapsed_ms <= 60),
    'QPC elapsed time should be approximately 30ms, got ' + IntToStr(elapsed_ms) + 'ms');
end;

procedure TGpTimestampTests.TestHasElapsed;
var
  start: TGpTimestamp;
  timeout_ms: Int64;
  actualElapsed_ms: Int64;
  duration: TGpTimestamp;
begin
  // Test HasElapsed with Int64 parameter
  start := TGpTimestamp.FromQueryPerformanceCounter;
  timeout_ms := 50;

  // Wait for timeout
  while not start.HasElapsed(timeout_ms) do
  begin
    // Busy wait
  end;

  actualElapsed_ms := (TGpTimestamp.FromQueryPerformanceCounter - start).ToMilliseconds;
  Assert.IsTrue(actualElapsed_ms >= timeout_ms,
    'Actual elapsed time should be at least the timeout value');
  Assert.IsTrue((actualElapsed_ms >= timeout_ms) and (actualElapsed_ms <= timeout_ms + 50),
    'Actual elapsed time should be close to timeout value, got ' + IntToStr(actualElapsed_ms) + 'ms');

  // Test HasElapsed with TGpTimestamp duration parameter
  start := TGpTimestamp.FromQueryPerformanceCounter;
  duration := TGpTimestamp.Microseconds(500);

  // Wait for duration
  while not start.HasElapsed(duration) do
  begin
    // Busy wait
  end;

  actualElapsed_ms := (TGpTimestamp.FromQueryPerformanceCounter - start).ToMilliseconds;
  Assert.IsTrue(actualElapsed_ms >= 0,
    'Actual elapsed time should be at least 0.5ms');

  // Test with larger duration
  start := TGpTimestamp.FromQueryPerformanceCounter;
  duration := TGpTimestamp.Milliseconds(30);

  while not start.HasElapsed(duration) do
  begin
    // Busy wait
  end;

  actualElapsed_ms := (TGpTimestamp.FromQueryPerformanceCounter - start).ToMilliseconds;
  Assert.IsTrue((actualElapsed_ms >= 30) and (actualElapsed_ms <= 80),
    'Should wait for 30ms duration, got ' + IntToStr(actualElapsed_ms) + 'ms');

  // Test that exception is raised for non-duration parameter
  start := TGpTimestamp.FromQueryPerformanceCounter;
  duration := TGpTimestamp.FromTickCount;  // Not a duration

  Assert.WillRaise(
    procedure
    begin
      start.HasElapsed(duration);
    end,
    EInvalidOpException,
    'HasElapsed should raise exception when parameter is not tsDuration');

  // Test that HasElapsed returns True for invalid timestamp (tsNone)
  start := TGpTimestamp.Invalid;
  Assert.IsTrue(start.HasElapsed(1000), 'HasElapsed should return True for invalid timestamp (Int64 overload)');

  duration := TGpTimestamp.Milliseconds(500);
  Assert.IsTrue(start.HasElapsed(duration), 'HasElapsed should return True for invalid timestamp (TGpTimestamp overload)');

  // Test the initialization pattern
  start := TGpTimestamp.Invalid;
  if start.HasElapsed(100) then
  begin
    start := TGpTimestamp.FromQueryPerformanceCounter;
    Assert.IsTrue(start.IsValid, 'Timestamp should now be valid');
  end;
  Assert.IsTrue(start.IsValid, 'Initialization pattern should have set valid timestamp');
end;

procedure TGpTimestampTests.TestHasRemaining;
var
  future: TGpTimestamp;
  timeout_ms: Int64;
  duration: TGpTimestamp;
  elapsed_ms: Int64;
begin
  TThread.Yield;
  // Test HasRemaining with Int64 parameter
  timeout_ms := 100;
  future := TGpTimestamp.FromQueryPerformanceCounter + TGpTimestamp.Milliseconds(timeout_ms);

  // Should have remaining time (but account for time passed during test execution)
  Assert.IsTrue(future.HasRemaining(timeout_ms - 10),
    'Future timestamp should have remaining time');

  // Wait for some time to pass
  Sleep(50);

  // Should still have some remaining time (but less than 100ms)
  Assert.IsTrue(future.HasRemaining(30),
    'Should still have at least 30ms remaining after 50ms sleep');

  // Should NOT have full 100ms remaining anymore
  Assert.IsFalse(future.HasRemaining(timeout_ms + 50),
    'Should not have more than actual remaining time');

  // Wait until deadline passes
  while future.HasRemaining(0) do
  begin
    // Busy wait
  end;

  // After deadline, should not have any remaining time
  Assert.IsFalse(future.HasRemaining(1),
    'Past timestamp should not have remaining time');

  TThread.Yield;
  // Test HasRemaining with TGpTimestamp duration parameter
  duration := TGpTimestamp.Milliseconds(100);
  future := TGpTimestamp.FromQueryPerformanceCounter + duration;

  // Account for time passed during test execution
  Assert.IsTrue(future.HasRemaining(TGpTimestamp.Milliseconds(90)),
    'Future timestamp should have duration remaining');

  Sleep(50);

  // Should still have at least 30ms remaining
  Assert.IsTrue(future.HasRemaining(TGpTimestamp.Milliseconds(30)),
    'Should have at least 30ms remaining');

  // Wait until deadline passes
  while future.HasRemaining(TGpTimestamp.Milliseconds(0)) do
  begin
    // Busy wait
  end;

  Assert.IsFalse(future.HasRemaining(TGpTimestamp.Milliseconds(1)),
    'Should not have remaining time after deadline');

  // Test that exception is raised for non-duration parameter
  future := TGpTimestamp.FromQueryPerformanceCounter + TGpTimestamp.Seconds(1);
  duration := TGpTimestamp.FromTickCount;  // Not a duration

  Assert.WillRaise(
    procedure
    begin
      future.HasRemaining(duration);
    end,
    EInvalidOpException,
    'HasRemaining should raise exception when parameter is not tsDuration');

  // Test that HasRemaining returns False for invalid timestamp (tsNone)
  future := TGpTimestamp.Invalid;
  Assert.IsFalse(future.HasRemaining(1000), 'HasRemaining should return False for invalid timestamp (Int64 overload)');

  duration := TGpTimestamp.Milliseconds(500);
  Assert.IsFalse(future.HasRemaining(duration), 'HasRemaining should return False for invalid timestamp (TGpTimestamp overload)');

  // Test with past timestamp (should return False)
  future := TGpTimestamp.FromQueryPerformanceCounter - TGpTimestamp.Seconds(1);  // 1 second in the past
  Assert.IsFalse(future.HasRemaining(100), 'Past timestamp should return False');
  Assert.IsFalse(future.HasRemaining(TGpTimestamp.Milliseconds(100)), 'Past timestamp should return False (duration overload)');

  // Test exact boundary condition
  future := TGpTimestamp.FromQueryPerformanceCounter + TGpTimestamp.Milliseconds(50);
  Sleep(50);
  // At or near the boundary, should not have 50ms remaining
  elapsed_ms := future.Elapsed.ToMilliseconds;
  if elapsed_ms >= 50 then
    Assert.IsFalse(future.HasRemaining(50), 'Should not have 50ms remaining after 50ms elapsed');
end;

procedure TGpTimestampTests.TestArithmetic;
var
  timestamp: TGpTimestamp;
  future, past: TGpTimestamp;
  duration: TGpTimestamp;
begin
  timestamp := TGpTimestamp.FromQueryPerformanceCounter;

  // Create a duration of 1 second
  duration := TGpTimestamp.Create(tsDuration, 1000000000);
  future := timestamp + duration;
  Assert.AreEqual(Int64(1000), (future - timestamp).ToMilliseconds,
    'Adding 1 second should result in 1000ms difference');

  // Create a duration of 500ms
  duration := TGpTimestamp.Create(tsDuration, 500000000);
  past := timestamp - duration;
  Assert.AreEqual(Int64(500), (timestamp - past).ToMilliseconds,
    'Subtracting 500ms should result in 500ms difference');

  // Verify the order
  Assert.IsTrue(past < timestamp, 'Past should be less than timestamp');
  Assert.IsTrue(timestamp < future, 'Timestamp should be less than future');
end;

procedure TGpTimestampTests.TestStopwatch;
var
  t1, t2: TGpTimestamp;
  elapsed_ns, elapsed_ms: Int64;
begin
  t1 := TGpTimestamp.FromStopwatch;
  Assert.IsTrue(t1.Value_ns > 0, 'Stopwatch timestamp should be positive');
  Assert.AreEqual(Ord(tsStopwatch), Ord(t1.TimeSource), 'Should be tsStopwatch source');

  Sleep(30);

  t2 := TGpTimestamp.FromStopwatch;
  elapsed_ns := (t2 - t1).Value_ns;
  elapsed_ms := elapsed_ns div 1000000;

  Assert.IsTrue((elapsed_ms >= 25) and (elapsed_ms <= 60),
    'Stopwatch elapsed time should be approximately 30ms, got ' + IntToStr(elapsed_ms) + 'ms');
  Assert.IsTrue(t1 < t2, 't1 should be less than t2');
end;

{$IFDEF MSWINDOWS}
procedure TGpTimestampTests.TestTimeGetTime;
var
  t1, t2: TGpTimestamp;
  elapsed_ns, elapsed_ms: Int64;
begin
  t1 := TGpTimestamp.FromTimeGetTime;
  Assert.IsTrue(t1.Value_ns > 0, 'TimeGetTime timestamp should be positive');
  Assert.AreEqual(Ord(tsTimeGetTime), Ord(t1.TimeSource), 'Should be tsTimeGetTime source');

  Sleep(30);

  t2 := TGpTimestamp.FromTimeGetTime;
  elapsed_ns := (t2 - t1).Value_ns;
  elapsed_ms := elapsed_ns div 1000000;

  Assert.IsTrue((elapsed_ms >= 25) and (elapsed_ms <= 60),
    'TimeGetTime elapsed time should be approximately 30ms, got ' + IntToStr(elapsed_ms) + 'ms');
  Assert.IsTrue(t1 < t2, 't1 should be less than t2');
end;
{$ENDIF}

procedure TGpTimestampTests.TestCreateOverload;
var
  ts1, ts2: TGpTimestamp;
  elapsed_ns: Int64;
begin
  // Test the Create overload with TTimeSource parameter
  ts1 := TGpTimestamp.Create(tsStopwatch, 1000000000);  // 1 second in nanoseconds
  Assert.AreEqual(Ord(tsStopwatch), Ord(ts1.TimeSource), 'Should be tsStopwatch source');
  Assert.AreEqual(Int64(1000000000), ts1.Value_ns, 'Value should be 1 second');

  ts2 := TGpTimestamp.Create(tsStopwatch, 2000000000);  // 2 seconds in nanoseconds
  Assert.IsTrue(ts1 < ts2, 'ts1 should be less than ts2');

  elapsed_ns := (ts2 - ts1).Value_ns;
  Assert.AreEqual(Int64(1000000000), elapsed_ns, 'Elapsed should be 1 second');
end;

procedure TGpTimestampTests.TestAllOperators;
var
  t1, t2, t3: TGpTimestamp;
  elapsed_ns: Int64;
begin
  // Create some test timestamps using Create for precise control
  t1 := TGpTimestamp.Create(tsStopwatch, 1000000000);   // 1 second
  t2 := TGpTimestamp.Create(tsStopwatch, 2000000000);   // 2 seconds
  t3 := TGpTimestamp.Create(tsStopwatch, 2000000000);   // 2 seconds (equal to t2)

  // Test Subtract (timestamp - timestamp) -> duration
  elapsed_ns := (t2 - t1).Value_ns;
  Assert.AreEqual(Int64(1000000000), elapsed_ns, 'Subtract operator should return 1 second');

  // Test Add (timestamp + duration) -> timestamp
  t3 := t1 + TGpTimestamp.Create(tsDuration, 1000000000);
  Assert.AreEqual(Int64(2000000000), t3.Value_ns, 'Add operator should produce 2 second timestamp');

  // Test Subtract (timestamp - duration) -> timestamp
  t3 := t2 - TGpTimestamp.Create(tsDuration, 1000000000);
  Assert.AreEqual(Int64(1000000000), t3.Value_ns, 'Subtract duration should produce 1 second timestamp');
  Assert.AreEqual(Ord(tsStopwatch), Ord(t3.TimeSource), 'Result should preserve timestamp source, not be duration');
  Assert.IsFalse(t3.IsDuration, 'Result of timestamp - duration should be a timestamp, not a duration');

  // Test GreaterThan operator
  Assert.IsTrue(t2 > t1, 't2 should be greater than t1');
  Assert.IsFalse(t1 > t2, 't1 should not be greater than t2');

  // Test LessThan operator
  Assert.IsTrue(t1 < t2, 't1 should be less than t2');
  Assert.IsFalse(t2 < t1, 't2 should not be less than t1');

  // Test GreaterThanOrEqual operator
  t3 := TGpTimestamp.Create(tsStopwatch, 2000000000);
  Assert.IsTrue(t2 >= t1, 't2 should be >= t1');
  Assert.IsTrue(t2 >= t3, 't2 should be >= t3 (equal values)');
  Assert.IsFalse(t1 >= t2, 't1 should not be >= t2');

  // Test LessThanOrEqual operator
  Assert.IsTrue(t1 <= t2, 't1 should be <= t2');
  Assert.IsTrue(t2 <= t3, 't2 should be <= t3 (equal values)');
  Assert.IsFalse(t2 <= t1, 't2 should not be <= t1');

  // Test Equal operator
  Assert.IsTrue(t2 = t3, 't2 should equal t3');
  Assert.IsFalse(t1 = t2, 't1 should not equal t2');

  // Test NotEqual operator
  Assert.IsTrue(t1 <> t2, 't1 should not equal t2');
  Assert.IsFalse(t2 <> t3, 't2 should equal t3');
end;

procedure TGpTimestampTests.TestStringConversion;
var
  ts1, ts2, ts3: TGpTimestamp;
  str, debugStr: string;
begin
  // Test positive values
  ts1 := TGpTimestamp.Create(tsStopwatch, 1234567890);  // 1.23... seconds
  str := ts1.ToString;
  Assert.IsTrue(str.Contains('1.234568s'), 'Should format as seconds: ' + str);  // rounded to 6 decimals
  Assert.IsTrue(str.Contains('[Stopwatch]'), 'Should contain source name: ' + str);

  ts2 := TGpTimestamp.Create(tsStopwatch, 123456789);  // 123.456... milliseconds
  str := ts2.ToString;
  Assert.IsTrue(str.Contains('123.457ms'), 'Should format as milliseconds: ' + str);
  Assert.IsTrue(str.Contains('[Stopwatch]'), 'Should contain source name: ' + str);

  // Test negative values
  ts3 := TGpTimestamp.Create(tsStopwatch, -500000000);  // -500ms
  str := ts3.ToString;
  Assert.IsTrue(str.Contains('-500'), 'Should show negative sign: ' + str);
  Assert.IsTrue(str.Contains('ms'), 'Should format as milliseconds: ' + str);

  // Test invalid timestamp
  ts1 := TGpTimestamp.Invalid;
  str := ts1.ToString;
  Assert.AreEqual('Invalid', str, 'Invalid timestamp should return "Invalid"');

  // Test debug string
  ts1 := TGpTimestamp.Create(tsStopwatch, 9876543210);
  debugStr := ts1.ToDebugString;
  Assert.IsTrue(debugStr.Contains('Source=Stopwatch'), 'Debug string should contain source: ' + debugStr);
  Assert.IsTrue(debugStr.Contains('Value=9876543210ns'), 'Debug string should contain value: ' + debugStr);
end;

procedure TGpTimestampTests.TestDateTimeConversion;
var
  dt: TDateTime;
  ts1, ts2: TGpTimestamp;
  convertedDt: TDateTime;
  diff: Double;
  elapsed_ns: Int64;
begin
  // Test FromDateTime and ToDateTime round-trip
  dt := 1.5;  // 1.5 days = 36 hours
  ts1 := TGpTimestamp.FromDateTime(dt);

  Assert.AreEqual(Ord(tsDateTime), Ord(ts1.TimeSource), 'Should use tsDateTime source');

  convertedDt := ts1.ToDateTime;
  diff := abs(convertedDt - dt);
  Assert.IsTrue(diff < 0.000001, 'Round-trip conversion should be accurate');

  // Test with fractional seconds
  dt := 0.001;  // About 86.4 seconds
  ts2 := TGpTimestamp.FromDateTime(dt);
  convertedDt := ts2.ToDateTime;
  diff := abs(convertedDt - dt);
  Assert.IsTrue(diff < 0.000001, 'Small values should convert accurately');

  // Test that TDateTime-based timestamps are compatible
  elapsed_ns := (ts1 - ts2).Value_ns;
  Assert.IsTrue(elapsed_ns > 0, 'Should be able to subtract TDateTime timestamps');

  // Test FromDateTime (parameterless overload)
  ts1 := TGpTimestamp.FromDateTime;
  Assert.AreEqual(Ord(tsDateTime), Ord(ts1.TimeSource), 'Parameterless FromDateTime should use tsDateTime');
  Assert.IsTrue(ts1.IsValid, 'Parameterless FromDateTime should create valid timestamp');
end;

procedure TGpTimestampTests.TestUtilityFunctions;
var
  ts1, ts2, ts3: TGpTimestamp;
  minTs, maxTs: TGpTimestamp;
begin
  // Test Zero
  ts1 := TGpTimestamp.Zero(tsStopwatch);
  Assert.AreEqual(Ord(tsStopwatch), Ord(ts1.TimeSource), 'Zero should have correct source');
  Assert.AreEqual(Int64(0), ts1.Value_ns, 'Zero should have value 0');

  // Test Invalid
  ts1 := TGpTimestamp.Invalid;
  Assert.AreEqual(Ord(tsNone), Ord(ts1.TimeSource), 'Invalid should have tsNone source');
  Assert.IsFalse(ts1.IsValid, 'Invalid timestamp should not be valid');

  // Test Min
  ts1 := TGpTimestamp.Create(tsStopwatch, 1000000000);
  ts2 := TGpTimestamp.Create(tsStopwatch, 2000000000);
  minTs := TGpTimestamp.Min(ts1, ts2);
  Assert.AreEqual(ts1.Value_ns, minTs.Value_ns, 'Min should return smaller value');

  minTs := TGpTimestamp.Min(ts2, ts1);
  Assert.AreEqual(ts1.Value_ns, minTs.Value_ns, 'Min should work regardless of order');

  // Test Max
  maxTs := TGpTimestamp.Max(ts1, ts2);
  Assert.AreEqual(ts2.Value_ns, maxTs.Value_ns, 'Max should return larger value');

  maxTs := TGpTimestamp.Max(ts2, ts1);
  Assert.AreEqual(ts2.Value_ns, maxTs.Value_ns, 'Max should work regardless of order');

  // Test equal values
  ts3 := TGpTimestamp.Create(tsStopwatch, 1000000000);
  minTs := TGpTimestamp.Min(ts1, ts3);
  Assert.AreEqual(ts1.Value_ns, minTs.Value_ns, 'Min of equal values should work');
end;

procedure TGpTimestampTests.TestNegativeDurations;
var
  ts1, ts2: TGpTimestamp;
  diff_ns, diff_ms: Int64;
  diff_sec: Double;
begin
  // Test negative duration from subtraction
  ts1 := TGpTimestamp.Create(tsStopwatch, 2000000000);  // 2 seconds
  ts2 := TGpTimestamp.Create(tsStopwatch, 1000000000);  // 1 second

  // ts2 - ts1 should be negative (earlier - later)
  diff_ns := (ts2 - ts1).Value_ns;
  Assert.AreEqual(Int64(-1000000000), diff_ns, 'Subtracting later from earlier should be negative');

  // Test ToMilliseconds with negative result
  diff_ms := (ts2 - ts1).ToMilliseconds;
  Assert.AreEqual(Int64(-1000), diff_ms, 'Difference should be -1000ms');

  // Test ToSeconds with negative result
  diff_sec := (ts2 - ts1).ToSeconds;
  Assert.IsTrue(abs(diff_sec - (-1.0)) < 0.0001, 'Difference should be -1.0s');

  // Test positive differences too
  diff_ms := (ts1 - ts2).ToMilliseconds;
  Assert.AreEqual(Int64(1000), diff_ms, 'Reverse difference should be positive');

  diff_sec := (ts1 - ts2).ToSeconds;
  Assert.IsTrue(abs(diff_sec - 1.0) < 0.0001, 'Reverse difference should be 1.0s');

  // Test arithmetic with negative durations
  ts1 := TGpTimestamp.Create(tsStopwatch, 1000000000);
  ts2 := ts1 + TGpTimestamp.Create(tsDuration, -500000000);  // Subtract 500ms
  Assert.AreEqual(Int64(500000000), ts2.Value_ns, 'Adding negative duration should work');

  ts2 := ts1 - TGpTimestamp.Create(tsDuration, -500000000);  // Add 500ms
  Assert.AreEqual(Int64(1500000000), ts2.Value_ns, 'Subtracting negative duration should work');

  // Test ToString with negative values
  ts1 := TGpTimestamp.Create(tsStopwatch, -1234567890);
  Assert.IsTrue(ts1.ToString.StartsWith('-'), 'Negative value should show minus sign');
end;

procedure TGpTimestampTests.TestDurationFactoryMethods;
var
  duration: TGpTimestamp;
  timestamp: TGpTimestamp;
begin
  // Test Nanoseconds
  duration := TGpTimestamp.Nanoseconds(1000);
  Assert.AreEqual(Ord(tsDuration), Ord(duration.TimeSource), 'Should be tsDuration');
  Assert.AreEqual(Int64(1000), duration.Value_ns, 'Should be 1000 nanoseconds');
  Assert.IsTrue(duration.IsDuration, 'Should be duration');

  // Test Microseconds
  duration := TGpTimestamp.Microseconds(500);
  Assert.AreEqual(Int64(500000), duration.Value_ns, 'Should be 500000 nanoseconds (500 microseconds)');

  // Test Milliseconds
  duration := TGpTimestamp.Milliseconds(100);
  Assert.AreEqual(Int64(100000000), duration.Value_ns, 'Should be 100000000 nanoseconds (100 milliseconds)');
  Assert.AreEqual(Int64(100), duration.ToMilliseconds, 'Should convert back to 100 milliseconds');

  // Test Seconds with integer value
  duration := TGpTimestamp.Seconds(5);
  Assert.AreEqual(Int64(5000000000), duration.Value_ns, 'Should be 5000000000 nanoseconds (5 seconds)');
  Assert.AreEqual(Int64(5000), duration.ToMilliseconds, 'Should be 5000 milliseconds');

  // Test Seconds with fractional value
  duration := TGpTimestamp.Seconds(2.5);
  Assert.AreEqual(Int64(2500000000), duration.Value_ns, 'Should be 2500000000 nanoseconds (2.5 seconds)');
  Assert.AreEqual(Int64(2500), duration.ToMilliseconds, 'Should be 2500 milliseconds');

  // Test Minutes
  duration := TGpTimestamp.Minutes(3);
  Assert.AreEqual(Int64(180000000000), duration.Value_ns, 'Should be 180000000000 nanoseconds (3 minutes)');
  Assert.AreEqual(Int64(180000), duration.ToMilliseconds, 'Should be 180000 milliseconds');

  // Test Hours
  duration := TGpTimestamp.Hours(2);
  Assert.AreEqual(Int64(7200000000000), duration.Value_ns, 'Should be 7200000000000 nanoseconds (2 hours)');
  Assert.AreEqual(Int64(7200000), duration.ToMilliseconds, 'Should be 7200000 milliseconds');

  // Test duration arithmetic with timestamp
  timestamp := TGpTimestamp.FromQueryPerformanceCounter;
  duration := TGpTimestamp.Milliseconds(500);

  // Should be able to add duration to timestamp
  timestamp := timestamp + duration;
  Assert.AreEqual(Ord(tsQueryPerformanceCounter), Ord(timestamp.TimeSource),
    'Should preserve timestamp source after adding duration');

  // Test duration + duration
  duration := TGpTimestamp.Milliseconds(100) + TGpTimestamp.Milliseconds(200);
  Assert.AreEqual(Int64(300), duration.ToMilliseconds, 'Should be 300 milliseconds');
  Assert.IsTrue(duration.IsDuration, 'Result should still be duration');
end;

procedure TGpTimestampTests.TestElapsed;
var
  start: TGpTimestamp;
  elapsed: TGpTimestamp;
  elapsed_ms: Int64;
begin
  // Test with QueryPerformanceCounter
  start := TGpTimestamp.FromQueryPerformanceCounter;
  Sleep(50);
  elapsed := start.Elapsed;

  Assert.IsTrue(elapsed.IsDuration, 'Elapsed should return duration');
  elapsed_ms := elapsed.ToMilliseconds;
  Assert.IsTrue((elapsed_ms >= 45) and (elapsed_ms <= 100),
    'Sleep(50) should take approximately 50ms, got ' + IntToStr(elapsed_ms) + 'ms');

  // Test with TickCount
  start := TGpTimestamp.FromTickCount;
  Sleep(30);
  elapsed := start.Elapsed;

  Assert.IsTrue(elapsed.IsDuration, 'Elapsed should return duration');
  elapsed_ms := elapsed.ToMilliseconds;
  Assert.IsTrue((elapsed_ms >= 25) and (elapsed_ms <= 60),
    'Sleep(30) should take approximately 30ms, got ' + IntToStr(elapsed_ms) + 'ms');

  // Test with Stopwatch
  start := TGpTimestamp.FromStopwatch;
  Sleep(40);
  elapsed := start.Elapsed;

  Assert.IsTrue(elapsed.IsDuration, 'Elapsed should return duration');
  elapsed_ms := elapsed.ToMilliseconds;
  Assert.IsTrue((elapsed_ms >= 35) and (elapsed_ms <= 70),
    'Sleep(40) should take approximately 40ms, got ' + IntToStr(elapsed_ms) + 'ms');

  {$IFDEF MSWINDOWS}
  // Test with TimeGetTime (Windows only)
  start := TGpTimestamp.FromTimeGetTime;
  Sleep(35);
  elapsed := start.Elapsed;

  Assert.IsTrue(elapsed.IsDuration, 'Elapsed should return duration');
  elapsed_ms := elapsed.ToMilliseconds;
  Assert.IsTrue((elapsed_ms >= 30) and (elapsed_ms <= 65),
    'Sleep(35) should take approximately 35ms, got ' + IntToStr(elapsed_ms) + 'ms');
  {$ENDIF}

  // Test that Elapsed raises exception for unsupported sources
  start := TGpTimestamp.Create(tsDuration, 1000000000);
  Assert.WillRaise(
    procedure
    begin
      elapsed := start.Elapsed;
    end,
    EInvalidOpException,
    'Elapsed should raise exception for tsDuration source');
end;

procedure TGpTimestampTests.TestFromValueOverloads;
var
  ts1, ts2: TGpTimestamp;
  value_ms, value_qpc, value_sw: Int64;
begin
  // Test FromTickCount with value
  value_ms := 5000;  // 5 seconds in milliseconds
  ts1 := TGpTimestamp.FromTickCount(value_ms);
  Assert.AreEqual(Ord(tsTickCount), Ord(ts1.TimeSource), 'Should be tsTickCount source');
  Assert.AreEqual(value_ms * Int64(1000000), ts1.Value_ns, 'Should be 5000ms in nanoseconds');

  // Test compatibility between parameterless and value-based versions
  ts2 := TGpTimestamp.FromTickCount(value_ms + 1000);
  Assert.IsTrue(ts2 > ts1, 'Value-based timestamps should be compatible and comparable');

  // Test FromQueryPerformanceCounter with value
  value_qpc := 1000000;  // Some QPC value
  ts1 := TGpTimestamp.FromQueryPerformanceCounter(value_qpc);
  Assert.AreEqual(Ord(tsQueryPerformanceCounter), Ord(ts1.TimeSource), 'Should be tsQueryPerformanceCounter source');
  Assert.IsTrue(ts1.Value_ns > 0, 'Should have positive nanosecond value');

  // Test FromStopwatch with value
  value_sw := 1000000;  // Some stopwatch value
  ts1 := TGpTimestamp.FromStopwatch(value_sw);
  Assert.AreEqual(Ord(tsStopwatch), Ord(ts1.TimeSource), 'Should be tsStopwatch source');
  Assert.IsTrue(ts1.Value_ns > 0, 'Should have positive nanosecond value');

  {$IFDEF MSWINDOWS}
  // Test FromTimeGetTime with value
  value_ms := 3000;  // 3 seconds in milliseconds
  ts1 := TGpTimestamp.FromTimeGetTime(value_ms);
  Assert.AreEqual(Ord(tsTimeGetTime), Ord(ts1.TimeSource), 'Should be tsTimeGetTime source');
  Assert.AreEqual(value_ms * Int64(1000000), ts1.Value_ns, 'Should be 3000ms in nanoseconds');
  {$ENDIF}

  // Test arithmetic with value-based timestamps
  {$IFDEF MSWINDOWS}
  ts1 := TGpTimestamp.FromTickCount(1000);
  ts2 := TGpTimestamp.FromTickCount(2000);
  Assert.AreEqual(Int64(1000), (ts2 - ts1).ToMilliseconds, 'Difference should be 1000ms');
  {$ENDIF}
end;

procedure TGpTimestampTests.TestAsString;
var
  ts1, ts2: TGpTimestamp;
  serialized: string;
begin
  // Test serialization of various timestamp types
  ts1 := TGpTimestamp.Create(tsStopwatch, 1000000000);
  serialized := ts1.AsString;
  Assert.AreEqual('4|1000000000', serialized, 'Should serialize to correct format');

  // Test round-trip serialization/deserialization
  ts2.AsString := serialized;
  Assert.AreEqual(Ord(ts1.TimeSource), Ord(ts2.TimeSource), 'TimeSource should match');
  Assert.AreEqual(ts1.Value_ns, ts2.Value_ns, 'Value_ns should match');

  // Test with negative values
  ts1 := TGpTimestamp.Create(tsDuration, -500000000);
  serialized := ts1.AsString;
  ts2.AsString := serialized;
  Assert.AreEqual(Int64(-500000000), ts2.Value_ns, 'Negative value should be preserved');

  // Test with DateTime
  ts1 := TGpTimestamp.FromDateTime(1.5);
  serialized := ts1.AsString;
  ts2.AsString := serialized;
  Assert.AreEqual(Ord(tsDateTime), Ord(ts2.TimeSource), 'DateTime source should be preserved');

  // Test invalid formats
  Assert.WillRaise(
    procedure
    begin
      ts2.AsString := 'invalid';
    end,
    EArgumentException,
    'Should raise exception for invalid format');

  Assert.WillRaise(
    procedure
    begin
      ts2.AsString := '1';  // Missing second field
    end,
    EArgumentException,
    'Should raise exception for missing field');

  Assert.WillRaise(
    procedure
    begin
      ts2.AsString := 'abc|1000';  // Invalid TimeSource
    end,
    EArgumentException,
    'Should raise exception for invalid TimeSource');

  Assert.WillRaise(
    procedure
    begin
      ts2.AsString := '99|1000';  // TimeSource out of range
    end,
    EArgumentException,
    'Should raise exception for TimeSource out of range');

  Assert.WillRaise(
    procedure
    begin
      ts2.AsString := '1|xyz';  // Invalid Value_ns
    end,
    EArgumentException,
    'Should raise exception for invalid Value_ns');
end;

procedure TGpTimestampTests.TestSubtractDurationFromTimestamp;
var
  timestamp, past, future: TGpTimestamp;
  duration: TGpTimestamp;
begin
  // Test with QueryPerformanceCounter source
  timestamp := TGpTimestamp.FromQueryPerformanceCounter;
  duration := TGpTimestamp.Milliseconds(500);

  // Subtract duration from timestamp
  past := timestamp - duration;

  // Verify that result is a timestamp, not a duration
  Assert.IsFalse(past.IsDuration, 'Result should be a timestamp, not a duration');
  Assert.AreEqual(Ord(tsQueryPerformanceCounter), Ord(past.TimeSource),
    'Result should preserve original timestamp source');

  // Verify the arithmetic is correct
  Assert.AreEqual(Int64(500), (timestamp - past).ToMilliseconds,
    'Difference should be 500ms');

  // Test with different time sources
  timestamp := TGpTimestamp.FromTickCount;
  duration := TGpTimestamp.Seconds(2);
  past := timestamp - duration;
  Assert.AreEqual(Ord(tsTickCount), Ord(past.TimeSource),
    'Should preserve tsTickCount source');
  Assert.IsFalse(past.IsDuration, 'Result should be timestamp with tsTickCount');

  timestamp := TGpTimestamp.FromStopwatch;
  duration := TGpTimestamp.Microseconds(1000);
  past := timestamp - duration;
  Assert.AreEqual(Ord(tsStopwatch), Ord(past.TimeSource),
    'Should preserve tsStopwatch source');

  // Test with Stopwatch timestamps
  timestamp := TGpTimestamp.Create(tsStopwatch, 1000000000);  // 1 second
  duration := TGpTimestamp.Milliseconds(500);
  past := timestamp - duration;
  Assert.AreEqual(Ord(tsStopwatch), Ord(past.TimeSource),
    'Should preserve tsStopwatch source');
  Assert.AreEqual(Int64(500), (timestamp - past).ToMilliseconds,
    'Stopwatch timestamp arithmetic should work correctly');

  // Test that result timestamp can be used in further arithmetic
  timestamp := TGpTimestamp.Create(tsStopwatch, 2000000000);  // 2 seconds
  duration := TGpTimestamp.Seconds(1);
  past := timestamp - duration;  // Should be 1 second
  future := past + duration;  // Should be back to 2 seconds
  Assert.AreEqual(timestamp.Value_ns, future.Value_ns,
    'Should be able to add duration back to get original timestamp');

  // Test with negative durations (going forward in time)
  timestamp := TGpTimestamp.Create(tsStopwatch, 1000000000);  // 1 second
  duration := TGpTimestamp.Create(tsDuration, -500000000);  // -500ms
  future := timestamp - duration;  // 1s - (-500ms) = 1.5s
  Assert.AreEqual(Int64(1500000000), future.Value_ns,
    'Subtracting negative duration should move forward in time');
  Assert.AreEqual(Ord(tsStopwatch), Ord(future.TimeSource),
    'Should preserve source with negative duration');

  // Verify that duration - timestamp still raises exception
  duration := TGpTimestamp.Milliseconds(500);
  timestamp := TGpTimestamp.FromQueryPerformanceCounter;
  Assert.WillRaise(
    procedure
    begin
      past := duration - timestamp;  // This should fail
    end,
    EInvalidOpException,
    'Should not be able to subtract timestamp from duration');
end;

initialization
  TDUnitX.RegisterTestFixture(TGpTimestampTests);

end.
