# GpTimestamp - Type-Safe Timestamp with Multiple Time Sources

**Version:** 1.02 (2025-01-05)
**Author:** Primoz Gabrijelcic (navigator), Claude Code (driver)
**License:** BSD
**Unit File:** GpTimestamp.pas

## Overview

GpTimestamp provides a type-safe timestamp implementation that prevents mixing incompatible time measurements through operator overloading. All time values are stored internally as nanoseconds (Int64), providing 292 years of range at nanosecond precision.

### Key Features

- **Type-safe time measurements** - Prevents mixing timestamps from different sources
- **Multiple time sources** - Support for QueryPerformanceCounter, GetTickCount, TStopwatch, TDateTime, and more
- **Operator overloading** - Automatic compatibility checking on all arithmetic and comparison operations
- **Nanosecond precision** - All values stored as Int64 nanoseconds internally
- **Cross-platform support** - Works on Windows and non-Windows platforms with appropriate fallbacks
- **Fail-fast design** - Raises EInvalidOpException immediately when mixing incompatible timebases
- **Duration semantics** - Special `tsDuration` source type compatible with all other sources

## Platform Dependencies

### Fully Cross-Platform Features

- `FromStopwatch` - Uses System.Diagnostics.TStopwatch
- `FromDateTime` / `ToDateTime` - TDateTime conversions
- `Elapsed` / `HasElapsed` (for Stopwatch/DateTime)
- All conversion methods (ToMilliseconds, ToMicroseconds, etc.)
- All operators and comparisons

### Windows-Only Features

The following features are **only available on Windows** (controlled by `{$IFDEF MSWINDOWS}`):

| Feature | Description | Dependency/Alternative |
|---------|-------------|------------------------|
| `FromTickCount` (both overloads) | GetTickCount64 timing | Use `FromStopwatch` for cross-platform |
| `FromQueryPerformanceCounter` (both overloads) | QueryPerformanceCounter timing | Use `FromStopwatch` for cross-platform |
| `FromTimeGetTime` (both overloads) | Multimedia timer via DSiTimeGetTime64 | Requires **DSiWin32.pas** |
| `HasElapsed` (for TickCount/QPC/TimeGetTime) | Timeout checking | Use `FromStopwatch` timestamps instead |
| `Elapsed` (for TickCount/QPC/TimeGetTime) | Elapsed time | Use `FromStopwatch` timestamps instead |

## Minimum Delphi Version

**Minimum Required:** Delphi 2010 or later (intruduction of TStopwatch)

## Dependencies

### Required Units

1. **System.SysUtils** - Exception handling, string formatting
2. **System.Diagnostics** - TStopwatch for cross-platform timing

### Conditional Windows Dependencies

3. **Winapi.Windows** - QueryPerformanceCounter, QueryPerformanceFrequency, GetTickCount64
4. **DSiWin32.pas** - DSiTimeGetTime64 function (located in same directory)

> **Note:** GpTimestamp is self-contained and doesn't depend on other GpXxx utility units, making it safe for use in base infrastructure projects.

## Time Sources

```pascal
TTimeSource = (
  tsNone,                    // Uninitialized
  tsTickCount,               // GetTickCount64 - millisecond resolution (Windows only)
  tsQueryPerformanceCounter, // QueryPerformanceCounter - high precision (Windows only)
  tsTimeGetTime,             // DSiTimeGetTime64 - millisecond resolution (Windows only)
  tsStopwatch,               // TStopwatch - high precision (cross-platform)
  tsDateTime,                // TDateTime - Delphi date/time (cross-platform)
  tsDuration                 // Pure duration, compatible with all sources
);
```

## Type Alias

```pascal
_TS_ = TGpTimestamp;
```

A short alias for `TGpTimestamp` to reduce verbosity in code. Use this for cleaner, more concise syntax:

```pascal
// Instead of:
timestamp := TGpTimestamp.Milliseconds(500);
while not start.HasElapsed(TGpTimestamp.Microseconds(500)) do
  Something();

// You can write:
timestamp := _TS_.Milliseconds(500);
while not start.HasElapsed(_TS_.Microseconds(500)) do
  Something();
```

The alias is particularly useful when using factory methods and duration creation frequently in your code.

## API Reference

### Factory Methods (Class Functions)

#### High-Precision Timing (Cross-Platform)

```pascal
class function FromStopwatch: TGpTimestamp; overload;
class function FromStopwatch(value: Int64): TGpTimestamp; overload;
```
Captures current time from TStopwatch, or creates a timestamp from a specific TStopwatch value. Fully cross-platform with microsecond+ resolution. The overload with value parameter allows creating timestamps from previously captured stopwatch values.

#### High-Precision Timing (Windows Only)

```pascal
class function FromQueryPerformanceCounter: TGpTimestamp; overload;  // Windows only
class function FromQueryPerformanceCounter(value: Int64): TGpTimestamp; overload;  // Windows only
```
Captures current time from QueryPerformanceCounter (microsecond+ resolution), or creates a timestamp from a specific QPC value. **Windows only.** The overload with value parameter allows creating timestamps from previously captured QPC values. For cross-platform high-precision timing, use `FromStopwatch` instead.

#### Millisecond-Resolution Timing (Windows Only)

```pascal
class function FromTickCount: TGpTimestamp; overload;  // Windows only
class function FromTickCount(value_ms: Int64): TGpTimestamp; overload;  // Windows only
```
Captures current time from GetTickCount64 (millisecond resolution), or creates a timestamp from a specific tick count value in milliseconds. **Windows only.** The overload with value parameter allows creating timestamps from previously captured tick count values. For cross-platform timing, use `FromStopwatch` instead.

```pascal
class function FromTimeGetTime: TGpTimestamp; overload;  // Windows only
class function FromTimeGetTime(value_ms: Int64): TGpTimestamp; overload;  // Windows only
```
Captures current time from DSiTimeGetTime64 (millisecond resolution), or creates a timestamp from a specific TimeGetTime value in milliseconds. **Windows only.** The overload with value parameter allows creating timestamps from previously captured TimeGetTime values.

#### TDateTime Timing

```pascal
class function FromDateTime: TGpTimestamp; overload;
```
Captures current UTC date/time using `TTimeZone.Local.ToUniversalTime(Now)`. Uses tsDateTime source. Values are stored relative to the GpTimestamp epoch (2025-12-12T00:00:00).

```pascal
class function FromDateTime(dt: TDateTime): TGpTimestamp; overload;
```
Creates a timestamp from TDateTime value. Uses tsDateTime source. All TDateTime-based timestamps are compatible with each other. Values are stored relative to the GpTimestamp epoch (2025-12-12T00:00:00).

#### Duration Factory Methods

These methods create duration timestamps (tsDuration source) that are compatible with all other timestamp sources.

```pascal
class function Nanoseconds(ns: Int64): TGpTimestamp;
class function Microseconds(us: Int64): TGpTimestamp;
class function Milliseconds(ms: Int64): TGpTimestamp;
class function Seconds(s: Double): TGpTimestamp;
class function Minutes(m: Int64): TGpTimestamp;
class function Hours(h: Int64): TGpTimestamp;
```

Create durations of the specified length. The `Seconds` method supports fractional values for sub-second precision. All return tsDuration timestamps that can be used in arithmetic with any timestamp source.

**Examples:**
```pascal
var
  timeout: TGpTimestamp;
  delay: TGpTimestamp;
  timestamp: TGpTimestamp;
begin
  // Create durations
  timeout := TGpTimestamp.Milliseconds(500);
  delay := TGpTimestamp.Seconds(2.5);

  // Use in arithmetic
  timestamp := TGpTimestamp.FromStopwatch;
  timestamp := timestamp + TGpTimestamp.Minutes(5);  // Add 5 minutes

  // Combine durations
  delay := TGpTimestamp.Seconds(1) + TGpTimestamp.Milliseconds(500);  // 1.5 seconds
end;
```

#### Generic Creation

```pascal
class function Create(aTimeSource: TTimeSource; aValue_ns: Int64): TGpTimestamp;
```
Creates a timestamp with explicit time source and value in nanoseconds. Most flexible creation method. Use this when you need complete control over timestamp parameters.

#### Utility Factory Methods

```pascal
class function Zero(source: TTimeSource): TGpTimestamp;
```
Returns a zero timestamp for the specified time source.

```pascal
class function Invalid: TGpTimestamp;
```
Returns an invalid timestamp (tsNone source).

```pascal
class function Min(const a, b: TGpTimestamp): TGpTimestamp;
```
Returns the earlier of two timestamps. Raises exception if timestamps are incompatible.

```pascal
class function Max(const a, b: TGpTimestamp): TGpTimestamp;
```
Returns the later of two timestamps. Raises exception if timestamps are incompatible.

### Conversion Methods

```pascal
function ToMilliseconds: Int64;
function ToMicroseconds: Int64;
function ToNanoseconds: Int64;
function ToSeconds: Double;
```
Convert the timestamp value to various time units. Note: Precision depends on the time source; this is just unit conversion.

```pascal
function ToDateTime: TDateTime;
```
Converts the timestamp to TDateTime. For tsDateTime timestamps, returns the absolute date/time by adding the epoch (2025-12-12T00:00:00). For other timestamp sources, returns a relative time value.

### String Conversions

```pascal
function ToString: string;
```
Returns a human-readable string representation. Format: "1.234567s [QPC]" or "123.456ms [TickCount]".

```pascal
function ToDebugString: string;
```
Returns a detailed debug string with all internal fields. Format: "Source=QPC, Value=1234567890ns".

```pascal
property AsString: string read/write;
```
Serializes and deserializes the timestamp to/from a string representation. This property allows you to save and restore the complete state of a timestamp, including TimeSource and Value_ns.

**Format:** `"TimeSource|Value_ns"`

**Example:**
```pascal
var
  ts1, ts2: TGpTimestamp;
  serialized: string;
begin
  ts1 := TGpTimestamp.FromStopwatch;
  serialized := ts1.AsString;  // "4|1234567890"

  // Later, restore the timestamp
  ts2.AsString := serialized;
  // ts2 now has the same TimeSource and Value_ns as ts1
end;
```

**Error Handling:** Setting AsString with an invalid format raises EArgumentException with a descriptive message.

### State Checking Methods

```pascal
function IsValid: Boolean;
```
Returns true if the timestamp has a valid time source (not tsNone).

```pascal
function IsDuration: Boolean;
```
Returns true if the timestamp represents a duration (tsDuration source).

```pascal
function HasElapsed(timeout_ms: Int64): Boolean; overload;
function HasElapsed(const duration: TGpTimestamp): Boolean; overload;
```
Checks if the specified timeout has elapsed since this timestamp. Automatically uses the same time source for the comparison.

The first overload accepts timeout in milliseconds as an Int64.

The second overload accepts a TGpTimestamp duration (TimeSource must be tsDuration), enabling more readable, self-documenting code using the duration factory methods.

**Special behavior:** Returns `True` when the timestamp is invalid (TimeSource = tsNone), allowing simple initialization patterns without explicit `IsValid` checks. This is useful for lazy initialization of timers.

**Supported for:**
- Cross-platform: tsStopwatch, tsDateTime
- Windows only: tsTickCount, tsQueryPerformanceCounter, tsTimeGetTime

```pascal
function HasRemaining(timeout_ms: Int64): Boolean; overload;
function HasRemaining(const duration: TGpTimestamp): Boolean; overload;
```
Checks if this timestamp is in the future by at least the specified timeout. Automatically uses the same time source for the comparison.

The first overload accepts timeout in milliseconds as an Int64.

The second overload accepts a TGpTimestamp duration (TimeSource must be tsDuration), enabling more readable, self-documenting code using the duration factory methods.

**Special behavior:** Returns `False` when the timestamp is invalid (TimeSource = tsNone). This is the opposite of `HasElapsed`, which returns `True` for invalid timestamps.

**Supported for:**
- Cross-platform: tsStopwatch, tsDateTime
- Windows only: tsTickCount, tsQueryPerformanceCounter, tsTimeGetTime

```pascal
function Elapsed: TGpTimestamp;
```
Returns the time elapsed since this timestamp as a duration (tsDuration). Automatically captures the current time using the same time source and returns the difference. This is a convenience method equivalent to `(TGpTimestamp.FromXxx - self)` but more readable.

**Supported for:**
- Cross-platform: tsStopwatch, tsDateTime
- Windows only: tsTickCount, tsQueryPerformanceCounter, tsTimeGetTime

**Raises:** EInvalidOpException for unsupported time sources (tsDuration, tsNone).

**Example:**
```pascal
var
  start: TGpTimestamp;
  elapsed_ms: Int64;
begin
  start := TGpTimestamp.FromStopwatch;
  DoWork;
  elapsed_ms := start.Elapsed.ToMilliseconds;  // Clean and readable!
end;
```

### Operators

#### Arithmetic Operators

```pascal
class operator Add(const a, b: TGpTimestamp): TGpTimestamp;
```
**Semantics:**
- `timestamp + duration` → timestamp (preserves timestamp's source)
- `duration + timestamp` → timestamp (preserves timestamp's source)
- `duration + duration` → duration
- `timestamp + timestamp` → **ERROR** (raises EInvalidOpException)

```pascal
class operator Subtract(const a, b: TGpTimestamp): TGpTimestamp;
```
**Semantics:**
- `timestamp - timestamp` → duration (tsDuration source)
- `timestamp - duration` → timestamp (preserves timestamp's source)
- `duration - duration` → duration
- `duration - timestamp` → **ERROR** (raises EInvalidOpException)

#### Comparison Operators

```pascal
class operator GreaterThan(const a, b: TGpTimestamp): Boolean;
class operator LessThan(const a, b: TGpTimestamp): Boolean;
class operator GreaterThanOrEqual(const a, b: TGpTimestamp): Boolean;
class operator LessThanOrEqual(const a, b: TGpTimestamp): Boolean;
class operator Equal(const a, b: TGpTimestamp): Boolean;
class operator NotEqual(const a, b: TGpTimestamp): Boolean;
```
All comparison operators check compatibility before comparing values. Raises EInvalidOpException if timestamps have incompatible timebases.

### Properties

```pascal
property TimeSource: TTimeSource read FTimeSource;
```
The time source used for this timestamp.

```pascal
property Value_ns: Int64 read FValue;
```
The time value in nanoseconds.

## Compatibility Rules

The `CheckCompatible` method implements the following rules (enforced by all operators):

### Rule 0: Duration is Universal
**tsDuration is compatible with everything.** This allows:
- `duration + timestamp` = timestamp
- `timestamp - duration` = timestamp
- `duration + duration` = duration

### Rule 1: Same Source Type
**All timestamps from the same source are compatible.** For example:
- All `FromTickCount` calls are compatible with each other
- All `FromQueryPerformanceCounter` calls are compatible with each other
- All `FromStopwatch` calls are compatible with each other
- All `FromDateTime` calls are compatible with each other

### Rule 2: Everything Else is Incompatible
**Different sources raise EInvalidOpException.**

Examples:
```pascal
// COMPATIBLE - same source
t1 := TGpTimestamp.FromStopwatch;
t2 := TGpTimestamp.FromStopwatch;
elapsed := t2 - t1;  // OK

// INCOMPATIBLE - different sources
t1 := TGpTimestamp.FromStopwatch;
t2 := TGpTimestamp.FromTickCount;
if t1 < t2 then  // EXCEPTION: EInvalidOpException
```

## Usage Examples

### Basic Timing with Fluent API

```pascal
var
  start: TGpTimestamp;
  elapsed_ms: Int64;
begin
  start := TGpTimestamp.FromStopwatch;
  DoWork;

  // Fluent API - subtraction returns duration, call methods on it
  elapsed_ms := (TGpTimestamp.FromStopwatch - start).ToMilliseconds;
  WriteLn('Elapsed: ', elapsed_ms, ' ms');

  // Or use the convenient Elapsed method (recommended!)
  elapsed_ms := start.Elapsed.ToMilliseconds;
  WriteLn('Elapsed: ', elapsed_ms, ' ms');

  // Or access raw nanoseconds
  WriteLn('Elapsed: ', start.Elapsed.Value_ns, ' ns');
end;
```

### High-Precision Timing

```pascal
var
  start, finish: TGpTimestamp;
begin
  start := TGpTimestamp.FromStopwatch;  // High precision, cross-platform
  Sleep(100);
  finish := TGpTimestamp.FromStopwatch;

  WriteLn('Sleep took: ', (finish - start).ToMilliseconds, ' ms');
end;
```

### Duration Arithmetic

```pascal
var
  timestamp, future, past: TGpTimestamp;
  duration: TGpTimestamp;
begin
  timestamp := TGpTimestamp.FromStopwatch;

  // Create durations using factory methods (much cleaner!)
  duration := TGpTimestamp.Seconds(1);
  future := timestamp + duration;  // Works with any timestamp source

  // Verify
  Assert((future - timestamp).IsDuration);
  Assert((future - timestamp).ToMilliseconds = 1000);

  // Subtract duration from timestamp (goes back in time)
  past := timestamp - duration;  // Returns timestamp, not duration!
  Assert(not past.IsDuration);  // past is a timestamp
  Assert(past.TimeSource = timestamp.TimeSource);  // Preserves source
  Assert((timestamp - past).ToMilliseconds = 1000);

  // Combine durations
  duration := TGpTimestamp.Minutes(5) + TGpTimestamp.Seconds(30);  // 5.5 minutes
  future := timestamp + duration;

  // Use fractional seconds
  duration := TGpTimestamp.Seconds(2.5);  // 2500 milliseconds
  Assert(duration.ToMilliseconds = 2500);

  // Round-trip arithmetic with timestamp - duration
  future := timestamp + TGpTimestamp.Milliseconds(500);
  past := future - TGpTimestamp.Milliseconds(500);
  Assert(past.Value_ns = timestamp.Value_ns);  // Back to original
end;
```

### DateTime Conversion

```pascal
var
  dt: TDateTime;
  ts1, ts2: TGpTimestamp;
  diff: TDateTime;
begin
  // Convert from TDateTime
  dt := Now;
  ts1 := TGpTimestamp.FromDateTime(dt);

  Sleep(1000);

  // Another DateTime timestamp
  ts2 := TGpTimestamp.FromDateTime(Now);

  // Compatible - both use tsDateTime
  diff := (ts2 - ts1).ToDateTime;
  WriteLn('Elapsed days: ', diff);

  // Round-trip conversion
  dt := ts1.ToDateTime;
end;
```

### Timeout Checking

```pascal
var
  start: TGpTimestamp;
  timeout: TGpTimestamp;
begin
  start := TGpTimestamp.FromStopwatch;

  // Option 1: Using milliseconds (Int64)
  while not start.HasElapsed(5000) do  // 5 second timeout
  begin
    ProcessMessages;
    if WorkCompleted then
      Break;
  end;

  // Option 2: Using TGpTimestamp duration (more readable!)
  timeout := TGpTimestamp.Seconds(5);
  while not start.HasElapsed(timeout) do
  begin
    ProcessMessages;
    if WorkCompleted then
      Break;
  end;

  // Self-documenting inline usage (with alias for brevity)
  while not start.HasElapsed(_TS_.Milliseconds(500)) do
    DoSomething;

  if start.HasElapsed(TGpTimestamp.Seconds(5)) then
    WriteLn('Timeout!')
  else
    WriteLn('Completed in time');
end;
```

### Deadline Checking with HasRemaining

```pascal
var
  deadline: TGpTimestamp;
begin
  // Set a deadline 10 seconds in the future
  deadline := TGpTimestamp.FromStopwatch + TGpTimestamp.Seconds(10);

  // Check if we still have time before the deadline
  while deadline.HasRemaining(1000) do  // While at least 1 second remains
  begin
    ProcessNextItem;
  end;

  // Check with TGpTimestamp duration (more readable!)
  if deadline.HasRemaining(TGpTimestamp.Seconds(5)) then
    WriteLn('Still have at least 5 seconds left')
  else
    WriteLn('Less than 5 seconds remaining or deadline passed');

  // Wait until deadline
  while deadline.HasRemaining(0) do
  begin
    // Busy wait or process work
    ProcessMessages;
  end;

  WriteLn('Deadline reached!');
end;
```

### Simple Initialization Pattern with HasElapsed

The `HasElapsed` method returns `True` for invalid timestamps (TimeSource = tsNone), enabling clean initialization patterns:

```pascal
var
  lastUpdate: TGpTimestamp;  // Defaults to tsNone (invalid)
begin
  // Simple pattern - no need to check IsValid explicitly
  if lastUpdate.HasElapsed(_TS_.Seconds(5)) then
  begin
    PerformUpdate;
    lastUpdate := TGpTimestamp.FromStopwatch;  // Initialize or reset
  end;
end;
```

This is particularly useful for class fields that need periodic updates:

```pascal
type
  TMyClass = class
  private
    FLastCheck: TGpTimestamp;  // Automatically invalid (tsNone) on creation
  public
    procedure Update;
  end;

procedure TMyClass.Update;
begin
  // First call: FLastCheck is invalid, HasElapsed returns True immediately
  // Subsequent calls: Checks if 1 second has actually elapsed
  if FLastCheck.HasElapsed(1000) then
  begin
    DoPeriodicWork;
    FLastCheck := TGpTimestamp.FromStopwatch;
  end;
end;
```

### Comparing and Finding Min/Max

```pascal
var
  t1, t2, earliest, latest: TGpTimestamp;
begin
  t1 := TGpTimestamp.FromStopwatch;
  Sleep(10);
  t2 := TGpTimestamp.FromStopwatch;

  // Comparisons
  Assert(t1 < t2);
  Assert(t2 > t1);
  Assert(t1 <= t2);

  // Find earliest and latest
  earliest := TGpTimestamp.Min(t1, t2);  // Returns t1
  latest := TGpTimestamp.Max(t1, t2);    // Returns t2
end;
```

## Design Concepts

### Type-Safe Time Measurement

**Problem:** Traditional time measurement in Delphi has three critical issues:
1. Ambiguous units - Hard to tell if Int64 stores milliseconds, microseconds, or nanoseconds
2. Unsafe mixing - Easy to accidentally subtract QueryPerformanceCounter from GetTickCount values
3. No compile-time safety - Relies only on variable naming conventions (_ms, _us suffixes)

**Solution:** TGpTimestamp stores both the time source and value, with automatic compatibility checking through operator overloading.

### Nanosecond Internal Storage

All values are stored as Int64 nanoseconds, providing:
- **292 years of range** at nanosecond precision
- **Future-proof precision** - Can represent sub-nanosecond values if needed
- **Consistent internal representation** - Simplifies arithmetic and conversions

### TDateTime Epoch (2025-12-12T00:00:00)

TDateTime-based timestamps are stored relative to the GpTimestamp epoch: **2025-12-12T00:00:00**.

**Why an epoch?**
- **Maximizes precision** - By storing values relative to a modern epoch, we avoid precision loss from Delphi's 1899-12-30 TDateTime base
- **Extended range** - Int64 nanoseconds relative to 2025-12-12 can represent dates from approximately 1733 to 2317
- **Prevents overflow** - Absolute TDateTime values converted to nanoseconds would overflow Int64 for dates after ~1925

**Round-trip guarantee:**
```pascal
var
  dt, converted: TDateTime;
  ts: TGpTimestamp;
begin
  dt := EncodeDate(2025, 12, 15) + EncodeTime(14, 30, 0, 0);
  ts := TGpTimestamp.FromDateTime(dt);
  converted := ts.ToDateTime;
  // converted equals dt within floating-point precision
end;
```

**Note:** The epoch is transparent to users - `FromDateTime` and `ToDateTime` handle the conversion automatically.

### Fail-Fast Approach

Mixing incompatible timebases raises `EInvalidOpException` immediately rather than producing silently incorrect results. This catches bugs early during development.

### Duration vs Timestamp Semantics

- **Timestamps** have a specific time source
- **Durations** (tsDuration) represent time differences and are universally compatible
- **Arithmetic rules** enforce correct semantics:
  - timestamp - timestamp = duration ✓
  - timestamp + duration = timestamp ✓
  - timestamp + timestamp = ERROR ✗
  - duration - timestamp = ERROR ✗

## Version History

### 1.02 (2025-01-05)
- **New feature**: Added `HasRemaining` method with two overloads
  - `HasRemaining(timeout_ms: Int64)` - Checks if timestamp is in the future by at least timeout milliseconds
  - `HasRemaining(const duration: TGpTimestamp)` - Checks if timestamp is in the future by at least the specified duration
  - Returns `False` for invalid timestamps (opposite of `HasElapsed`)
  - Useful for deadline checking and countdown timers

### 1.01 (2025-12-15)
- **TDateTime epoch introduced**: TDateTime timestamps now stored relative to 2025-12-12T00:00:00 epoch
  - Maximizes precision by avoiding Delphi's 1899 TDateTime base
  - Extends usable date range (approximately 1733 to 2317)
  - Prevents Int64 overflow for modern dates
- **API change**: `ToDateTime()` removed inline attribute (uses implementation constant)

### 1.0 (2025-12-12)
- First public release
- Type-safe timestamps with multiple time sources
- Operator overloading for arithmetic and comparisons
- Cross-platform support (Windows and non-Windows)
- Comprehensive unit tests (20 test methods)

## Testing

The unit includes comprehensive unit tests in `GpTimestamp.UnitTests.pas` with 21 test methods covering:

- Basic timing with various sources
- Unit conversions (ns, μs, ms, seconds)
- Comparisons and ordering
- Incompatible source detection
- Stopwatch integration
- TimeGetTime (Windows only)
- DateTime conversions
- All arithmetic operators
- String conversions
- Utility functions (Min, Max, Zero, Invalid)
- Negative duration handling
- Duration factory methods
- Elapsed method
- FromXXX value overloads
- HasElapsed with invalid timestamps (initialization patterns)
- HasRemaining with future timestamps and deadline checking
- Subtract duration from timestamp (timestamp - duration preserves source)

Run tests with:
```
dcc32 -B -U.. GpTimestampTests.dpr
GpTimestampTests.exe
```

## Internal Structure

### Record Layout

```pascal
TGpTimestamp = record
  strict private
    FTimeSource: TTimeSource;  // 4 bytes (Int32 enum)
    FValue: Int64;             // 8 bytes
  // Total: 12 bytes
```

### Conversion Constants

Internal constants used for all conversions (defined in implementation section):

```pascal
const
  CNanosecondsPerMicrosecond = 1000;
  CNanosecondsPerMillisecond = 1000000;
  CNanosecondsPerSecond = 1000000000;
  CNanosecondsPerDay = Int64(86400000000000);
```

## Best Practices

### When to Use Which Time Source

| Use Case | Recommended Source | Reason |
|----------|-------------------|--------|
| High-precision profiling (cross-platform) | `FromStopwatch` | Microsecond+ resolution, guaranteed cross-platform |
| High-precision profiling (Windows) | `FromQueryPerformanceCounter` | Microsecond+ resolution, **Windows only** |
| Simple timeout tracking (Windows) | `FromTickCount` | Millisecond resolution, **Windows only** |
| Simple timeout tracking (cross-platform) | `FromStopwatch` | Works everywhere |
| Windows multimedia | `FromTimeGetTime` | Consistent with multimedia timers, **Windows only** |
| External timestamps | `FromDateTime` | TDateTime compatibility |

### Prefer TGpTimestamp Over Raw Int64

**Instead of:**
```pascal
var
  start_ms, elapsed_ms: Int64;
begin
  start_ms := GetTickCount64;
  DoWork;
  elapsed_ms := GetTickCount64 - start_ms;  // Easy to mix with QPC values!
end;
```

**Use:**
```pascal
var
  start: TGpTimestamp;
begin
  start := TGpTimestamp.FromStopwatch;
  DoWork;
  elapsed_ms := (TGpTimestamp.FromStopwatch - start).ToMilliseconds;
end;
```

### Use Descriptive Variable Names

```pascal
var
  requestStart, requestEnd: TGpTimestamp;
  processingDuration: TGpTimestamp;
  timeout_ms: Int64;
begin
  requestStart := TGpTimestamp.FromStopwatch;
  ProcessRequest;
  requestEnd := TGpTimestamp.FromStopwatch;

  processingDuration := requestEnd - requestStart;
  Assert(processingDuration.IsDuration);

  timeout_ms := processingDuration.ToMilliseconds;
end;
```

## Breaking Changes from Traditional Approaches

### Subtract Operator Returns TGpTimestamp

**Old approach (raw Int64):**
```pascal
var
  t1, t2, elapsed_ns: Int64;
begin
  t1 := GetQPCValue;
  t2 := GetQPCValue;
  elapsed_ns := t2 - t1;  // Direct Int64 result
end;
```

**New approach (TGpTimestamp):**
```pascal
var
  t1, t2: TGpTimestamp;
  elapsed_ns: Int64;
begin
  t1 := TGpTimestamp.FromStopwatch;
  t2 := TGpTimestamp.FromStopwatch;
  elapsed_ns := (t2 - t1).Value_ns;  // or .ToNanoseconds
  // Can also use: .ToMilliseconds, .ToMicroseconds, .ToSeconds
end;
```

## License

This software is distributed under the BSD license.

Copyright (c) 2025, Primoz Gabrijelcic
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
- The name of the Primoz Gabrijelcic may not be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
