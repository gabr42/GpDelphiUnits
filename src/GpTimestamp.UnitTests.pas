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
    procedure TestCustomTimebase;
    [Test]
    procedure TestDifferentSources;
    [Test]
    procedure TestSameSourceCompatibility;
    [Test]
    procedure TestHasElapsed;
    [Test]
    procedure TestArithmetic;
    [Test]
    procedure TestDVB_Conversions;
    [Test]
    procedure TestDVB_Compatibility;
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
    procedure TestUnixTimeConversion;
    [Test]
    procedure TestUtilityFunctions;
    [Test]
    procedure TestNegativeDurations;
    [Test]
    procedure TestDurationFactoryMethods;
    [Test]
    procedure TestElapsed;
  end;

implementation

uses
  System.SysUtils;

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

procedure TGpTimestampTests.TestCustomTimebase;
var
  timeBase: Int64;
  measurement1, measurement2: TGpTimestamp;
  elapsed_ns, elapsed_ms: Int64;
begin
  // Create a custom timebase for related measurements
  timeBase := TGpTimestamp.FromQueryPerformanceCounter.Value_ns;
  Assert.IsTrue(timeBase > 0, 'Custom timebase should be positive');

  // First measurement
  measurement1 := TGpTimestamp.FromCustom(timeBase, TGpTimestamp.FromQueryPerformanceCounter.Value_ns);

  Sleep(25);

  // Second measurement with same timebase
  measurement2 := TGpTimestamp.FromCustom(timeBase, TGpTimestamp.FromQueryPerformanceCounter.Value_ns);

  // These can be compared because they share the same custom timebase
  elapsed_ms := (measurement2 - measurement1).ToMilliseconds;
  Assert.IsTrue((elapsed_ms >= 20) and (elapsed_ms <= 50),
    'Elapsed time should be approximately 25ms, got ' + IntToStr(elapsed_ms) + 'ms');
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
begin
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
end;

procedure TGpTimestampTests.TestArithmetic;
var
  timestamp: TGpTimestamp;
  future, past: TGpTimestamp;
  duration: TGpTimestamp;
begin
  timestamp := TGpTimestamp.FromQueryPerformanceCounter;

  // Create a duration of 1 second
  duration := TGpTimestamp.Create(tsDuration, 0, 1000000000);
  future := timestamp + duration;
  Assert.AreEqual(Int64(1000), (future - timestamp).ToMilliseconds,
    'Adding 1 second should result in 1000ms difference');

  // Create a duration of 500ms
  duration := TGpTimestamp.Create(tsDuration, 0, 500000000);
  past := timestamp - duration;
  Assert.AreEqual(Int64(500), (timestamp - past).ToMilliseconds,
    'Subtracting 500ms should result in 500ms difference');

  // Verify the order
  Assert.IsTrue(past < timestamp, 'Past should be less than timestamp');
  Assert.IsTrue(timestamp < future, 'Timestamp should be less than future');
end;

procedure TGpTimestampTests.TestDVB_Conversions;
var
  pcr_value, pts_value: Int64;
  ts_from_pcr, ts_from_pts: TGpTimestamp;
  converted_pcr, converted_pts: Int64;
begin
  // Test PCR conversion (27 MHz clock)
  // 27,000,000 PCR ticks = 1 second = 1,000,000,000 nanoseconds
  pcr_value := 27000000;  // 1 second in PCR ticks
  ts_from_pcr := TGpTimestamp.FromDVB_PCR(pcr_value);

  Assert.IsTrue(ts_from_pcr.Value_ns >= 999900000, 'PCR to ns conversion should be approximately 1 second');
  Assert.IsTrue(ts_from_pcr.Value_ns <= 1000100000, 'PCR to ns conversion should be approximately 1 second');

  // Convert back to PCR
  converted_pcr := ts_from_pcr.ToPCR;
  Assert.IsTrue(abs(converted_pcr - pcr_value) <= 1,
    'PCR round-trip conversion should be accurate within 1 tick');

  // Test PTS conversion (90 kHz clock)
  // 90,000 PTS ticks = 1 second = 1,000,000,000 nanoseconds
  pts_value := 90000;  // 1 second in PTS ticks
  ts_from_pts := TGpTimestamp.FromDVB_PTS(pts_value);

  Assert.IsTrue(ts_from_pts.Value_ns >= 999900000, 'PTS to ns conversion should be approximately 1 second');
  Assert.IsTrue(ts_from_pts.Value_ns <= 1000100000, 'PTS to ns conversion should be approximately 1 second');

  // Convert back to PTS
  converted_pts := ts_from_pts.ToPTS;
  Assert.IsTrue(abs(converted_pts - pts_value) <= 1,
    'PTS round-trip conversion should be accurate within 1 tick');

  // Test smaller values for precision
  pcr_value := 27000;  // 1 millisecond in PCR ticks
  ts_from_pcr := TGpTimestamp.FromDVB_PCR(pcr_value);
  Assert.IsTrue(abs(ts_from_pcr.Value_ns - 1000000) <= 1000,
    'PCR conversion should handle millisecond precision');

  pts_value := 90;  // 1 millisecond in PTS ticks
  ts_from_pts := TGpTimestamp.FromDVB_PTS(pts_value);
  Assert.IsTrue(abs(ts_from_pts.Value_ns - 1000000) <= 1000,
    'PTS conversion should handle millisecond precision');
end;

procedure TGpTimestampTests.TestDVB_Compatibility;
var
  t1_pcr, t2_pcr, t1_pts, t2_pts: TGpTimestamp;
  elapsed_ns: Int64;
  exceptionRaised: Boolean;
begin
  // Both from PCR - should be compatible
  t1_pcr := TGpTimestamp.FromDVB_PCR(27000000);  // 1 second
  t2_pcr := TGpTimestamp.FromDVB_PCR(54000000);  // 2 seconds

  elapsed_ns := (t2_pcr - t1_pcr).Value_ns;
  Assert.IsTrue(abs(elapsed_ns - 1000000000) <= 1000,
    'Elapsed time between two PCR timestamps should be 1 second');
  Assert.IsTrue(t1_pcr < t2_pcr, 't1_pcr should be less than t2_pcr');

  // Both from PTS - should be compatible
  t1_pts := TGpTimestamp.FromDVB_PTS(90000);   // 1 second
  t2_pts := TGpTimestamp.FromDVB_PTS(180000);  // 2 seconds

  elapsed_ns := (t2_pts - t1_pts).Value_ns;
  Assert.IsTrue(abs(elapsed_ns - 1000000000) <= 1000,
    'Elapsed time between two PTS timestamps should be 1 second');
  Assert.IsTrue(t1_pts < t2_pts, 't1_pts should be less than t2_pts');

  // PCR and PTS should be compatible (both use tsDVB)
  t1_pcr := TGpTimestamp.FromDVB_PCR(27000000);  // 1 second
  t1_pts := TGpTimestamp.FromDVB_PTS(90000);     // 1 second

  elapsed_ns := (t1_pts - t1_pcr).Value_ns;
  Assert.IsTrue(abs(elapsed_ns) <= 1000,
    'PCR and PTS representing same time should have minimal difference');

  // DVB and other sources should be incompatible
  t1_pcr := TGpTimestamp.FromDVB_PCR(27000000);
  t2_pcr := TGpTimestamp.FromTickCount;

  exceptionRaised := False;
  try
    if t1_pcr < t2_pcr then
      ; // This should raise an exception
  except
    on E: EInvalidOpException do
      exceptionRaised := True;
  end;

  Assert.IsTrue(exceptionRaised,
    'Comparing DVB and TickCount sources should raise EInvalidOpException');
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
  ts1 := TGpTimestamp.Create(tsDVB, 0, 1000000000);  // 1 second in nanoseconds
  Assert.AreEqual(Ord(tsDVB), Ord(ts1.TimeSource), 'Should be tsDVB source');
  Assert.AreEqual(Int64(0), ts1.TimeBase, 'TimeBase should be 0');
  Assert.AreEqual(Int64(1000000000), ts1.Value_ns, 'Value should be 1 second');

  ts2 := TGpTimestamp.Create(tsDVB, 0, 2000000000);  // 2 seconds in nanoseconds
  Assert.IsTrue(ts1 < ts2, 'ts1 should be less than ts2');

  elapsed_ns := (ts2 - ts1).Value_ns;
  Assert.AreEqual(Int64(1000000000), elapsed_ns, 'Elapsed should be 1 second');

  // Test with custom timebase
  ts1 := TGpTimestamp.Create(tsCustom, 123456, 1000000000);
  ts2 := TGpTimestamp.Create(tsCustom, 123456, 2000000000);
  elapsed_ns := (ts2 - ts1).Value_ns;
  Assert.AreEqual(Int64(1000000000), elapsed_ns, 'Elapsed should be 1 second for custom timebase');
end;

procedure TGpTimestampTests.TestAllOperators;
var
  t1, t2, t3: TGpTimestamp;
  elapsed_ns: Int64;
begin
  // Create some test timestamps using Create for precise control
  t1 := TGpTimestamp.Create(tsDVB, 0, 1000000000);   // 1 second
  t2 := TGpTimestamp.Create(tsDVB, 0, 2000000000);   // 2 seconds
  t3 := TGpTimestamp.Create(tsDVB, 0, 2000000000);   // 2 seconds (equal to t2)

  // Test Subtract (timestamp - timestamp) -> duration
  elapsed_ns := (t2 - t1).Value_ns;
  Assert.AreEqual(Int64(1000000000), elapsed_ns, 'Subtract operator should return 1 second');

  // Test Add (timestamp + duration) -> timestamp
  t3 := t1 + TGpTimestamp.Create(tsDuration, 0, 1000000000);
  Assert.AreEqual(Int64(2000000000), t3.Value_ns, 'Add operator should produce 2 second timestamp');

  // Test Subtract (timestamp - duration) -> timestamp
  t3 := t2 - TGpTimestamp.Create(tsDuration, 0, 1000000000);
  Assert.AreEqual(Int64(1000000000), t3.Value_ns, 'Subtract duration should produce 1 second timestamp');

  // Test GreaterThan operator
  Assert.IsTrue(t2 > t1, 't2 should be greater than t1');
  Assert.IsFalse(t1 > t2, 't1 should not be greater than t2');

  // Test LessThan operator
  Assert.IsTrue(t1 < t2, 't1 should be less than t2');
  Assert.IsFalse(t2 < t1, 't2 should not be less than t1');

  // Test GreaterThanOrEqual operator
  t3 := TGpTimestamp.Create(tsDVB, 0, 2000000000);
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
  ts1 := TGpTimestamp.Create(tsDVB, 0, 1234567890);  // 1.23... seconds
  str := ts1.ToString;
  Assert.IsTrue(str.Contains('1.234568s'), 'Should format as seconds: ' + str);  // rounded to 6 decimals
  Assert.IsTrue(str.Contains('[DVB]'), 'Should contain source name: ' + str);

  ts2 := TGpTimestamp.Create(tsDVB, 0, 123456789);  // 123.456... milliseconds
  str := ts2.ToString;
  Assert.IsTrue(str.Contains('123.457ms'), 'Should format as milliseconds: ' + str);
  Assert.IsTrue(str.Contains('[DVB]'), 'Should contain source name: ' + str);

  // Test negative values
  ts3 := TGpTimestamp.Create(tsDVB, 0, -500000000);  // -500ms
  str := ts3.ToString;
  Assert.IsTrue(str.Contains('-500'), 'Should show negative sign: ' + str);
  Assert.IsTrue(str.Contains('ms'), 'Should format as milliseconds: ' + str);

  // Test invalid timestamp
  ts1 := TGpTimestamp.Invalid;
  str := ts1.ToString;
  Assert.AreEqual('Invalid', str, 'Invalid timestamp should return "Invalid"');

  // Test debug string
  ts1 := TGpTimestamp.Create(tsCustom, 12345, 9876543210);
  debugStr := ts1.ToDebugString;
  Assert.IsTrue(debugStr.Contains('Source=Custom'), 'Debug string should contain source: ' + debugStr);
  Assert.IsTrue(debugStr.Contains('Base=12345'), 'Debug string should contain base: ' + debugStr);
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

  Assert.AreEqual(Ord(tsCustom), Ord(ts1.TimeSource), 'Should use tsCustom source');
  Assert.AreEqual(CDelphiDateTimeEpoch, ts1.TimeBase, 'Should have Delphi DateTime epoch as timebase');

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
end;

procedure TGpTimestampTests.TestUnixTimeConversion;
var
  unixTime: Int64;
  ts1, ts2: TGpTimestamp;
  elapsed_ns: Int64;
begin
  // Test FromUnixTime
  unixTime := 1000000000;  // September 9, 2001, 01:46:40 UTC
  ts1 := TGpTimestamp.FromUnixTime(unixTime);

  Assert.AreEqual(Ord(tsCustom), Ord(ts1.TimeSource), 'Should use tsCustom source');
  Assert.AreEqual(CUnixTimeEpoch, ts1.TimeBase, 'Should have Unix epoch as timebase');
  Assert.AreEqual(unixTime * Int64(1000000000), ts1.Value_ns, 'Value should be in nanoseconds');

  // Test with zero Unix time (epoch)
  ts2 := TGpTimestamp.FromUnixTime(0);
  Assert.AreEqual(Int64(0), ts2.Value_ns, 'Unix epoch should have value 0');
  Assert.AreEqual(CUnixTimeEpoch, ts2.TimeBase, 'Should have Unix epoch as timebase');

  // Test that Unix time-based timestamps are compatible
  elapsed_ns := (ts1 - ts2).Value_ns;
  Assert.AreEqual(unixTime * Int64(1000000000), elapsed_ns, 'Difference should equal unix time in nanoseconds');

  // Test negative Unix time (before epoch)
  ts1 := TGpTimestamp.FromUnixTime(-86400);  // One day before Unix epoch
  Assert.AreEqual(Int64(-86400) * Int64(1000000000), ts1.Value_ns, 'Should handle negative Unix time');
end;

procedure TGpTimestampTests.TestUtilityFunctions;
var
  ts1, ts2, ts3: TGpTimestamp;
  minTs, maxTs: TGpTimestamp;
  absDuration: Int64;
begin
  // Test Zero
  ts1 := TGpTimestamp.Zero(tsDVB);
  Assert.AreEqual(Ord(tsDVB), Ord(ts1.TimeSource), 'Zero should have correct source');
  Assert.AreEqual(Int64(0), ts1.Value_ns, 'Zero should have value 0');
  Assert.AreEqual(Int64(0), ts1.TimeBase, 'Zero should have base 0');

  // Test Invalid
  ts1 := TGpTimestamp.Invalid;
  Assert.AreEqual(Ord(tsNone), Ord(ts1.TimeSource), 'Invalid should have tsNone source');
  Assert.IsFalse(ts1.IsValid, 'Invalid timestamp should not be valid');

  // Test Min
  ts1 := TGpTimestamp.Create(tsDVB, 0, 1000000000);
  ts2 := TGpTimestamp.Create(tsDVB, 0, 2000000000);
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
  ts3 := TGpTimestamp.Create(tsDVB, 0, 1000000000);
  minTs := TGpTimestamp.Min(ts1, ts3);
  Assert.AreEqual(ts1.Value_ns, minTs.Value_ns, 'Min of equal values should work');

  // Test Abs
  absDuration := TGpTimestamp.Abs(-1234567890);
  Assert.AreEqual(Int64(1234567890), absDuration, 'Abs should return positive value');

  absDuration := TGpTimestamp.Abs(1234567890);
  Assert.AreEqual(Int64(1234567890), absDuration, 'Abs of positive should return same value');

  absDuration := TGpTimestamp.Abs(0);
  Assert.AreEqual(Int64(0), absDuration, 'Abs of zero should be zero');
end;

procedure TGpTimestampTests.TestNegativeDurations;
var
  ts1, ts2: TGpTimestamp;
  diff_ns, diff_ms: Int64;
  diff_sec: Double;
begin
  // Test negative duration from subtraction
  ts1 := TGpTimestamp.Create(tsDVB, 0, 2000000000);  // 2 seconds
  ts2 := TGpTimestamp.Create(tsDVB, 0, 1000000000);  // 1 second

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
  ts1 := TGpTimestamp.Create(tsDVB, 0, 1000000000);
  ts2 := ts1 + TGpTimestamp.Create(tsDuration, 0, -500000000);  // Subtract 500ms
  Assert.AreEqual(Int64(500000000), ts2.Value_ns, 'Adding negative duration should work');

  ts2 := ts1 - TGpTimestamp.Create(tsDuration, 0, -500000000);  // Add 500ms
  Assert.AreEqual(Int64(1500000000), ts2.Value_ns, 'Subtracting negative duration should work');

  // Test ToString with negative values
  ts1 := TGpTimestamp.Create(tsDVB, 0, -1234567890);
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
  start := TGpTimestamp.Create(tsDuration, 0, 1000000000);
  Assert.WillRaise(
    procedure
    begin
      elapsed := start.Elapsed;
    end,
    EInvalidOpException,
    'Elapsed should raise exception for tsDuration source');

  start := TGpTimestamp.FromCustom(12345, 1000000000);
  Assert.WillRaise(
    procedure
    begin
      elapsed := start.Elapsed;
    end,
    EInvalidOpException,
    'Elapsed should raise exception for tsCustom source');
end;

initialization
  TDUnitX.RegisterTestFixture(TGpTimestampTests);

end.
