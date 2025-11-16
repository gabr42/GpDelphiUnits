# GpTimestamp - Type-Safe Timestamp with Multiple Time Sources

**Version:** 0.1 (2025-11-16)
**Author:** Primoz Gabrijelcic (navigator), Claude Code (driver)
**License:** BSD
**Unit File:** GpTimestamp.pas

## Overview

GpTimestamp provides a type-safe timestamp implementation that prevents mixing incompatible time measurements through operator overloading. All time values are stored internally as nanoseconds (Int64), providing 292 years of range at nanosecond precision.

### Key Features

- **Type-safe time measurements** - Prevents mixing timestamps from different sources
- **Multiple time sources** - Support for QueryPerformanceCounter, GetTickCount, TStopwatch, DVB timestamps, and more
- **Operator overloading** - Automatic compatibility checking on all arithmetic and comparison operations
- **Nanosecond precision** - All values stored as Int64 nanoseconds internally
- **Cross-platform support** - Works on Windows and non-Windows platforms with appropriate fallbacks
- **Fail-fast design** - Raises EInvalidOpException immediately when mixing incompatible timebases
- **Duration semantics** - Special `tsDuration` source type compatible with all other sources

## Platform Dependencies

### Windows-Only Features

The following features are only available on Windows (controlled by `{$IFDEF MSWINDOWS}`):

| Feature | Description | Dependency |
|---------|-------------|------------|
| `FromTimeGetTime` | Multimedia timer via DSiTimeGetTime64 | Requires **DSiWin32.pas** |
| `HasElapsed` (TimeGetTime) | Timeout checking for TimeGetTime source | Windows only |

### Platform-Specific Implementations

The following methods have Windows-specific implementations with cross-platform fallbacks:

| Method | Windows Implementation | Non-Windows Fallback |
|--------|----------------------|---------------------|
| `FromTickCount` | GetTickCount64 | TStopwatch.GetTimeStamp conversion |
| `FromQueryPerformanceCounter` | QueryPerformanceCounter | TStopwatch.GetTimeStamp conversion |
| `GetPerformanceFrequency` | QueryPerformanceFrequency | TStopwatch.Frequency |

### Fully Cross-Platform Features

- `FromStopwatch` - Uses System.Diagnostics.TStopwatch
- `FromDVB_PCR` / `FromDVB_PTS` - DVB timestamp support
- `FromDateTime` / `ToDateTime` - TDateTime conversions
- `FromUnixTime` - Unix timestamp support
- `FromCustom` - Custom timebase support
- All conversion methods (ToMilliseconds, ToMicroseconds, etc.)
- All operators and comparisons

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
  tsTickCount,               // GetTickCount64 - millisecond resolution
  tsQueryPerformanceCounter, // QueryPerformanceCounter - high precision
  tsTimeGetTime,             // DSiTimeGetTime64 - millisecond (Windows only)
  tsStopwatch,               // TStopwatch (cross-platform)
  tsCustom,                  // User-defined timebase
  tsDVB,                     // DVB/MPEG PCR/PTS timestamps
  tsDuration                 // Pure duration, compatible with all sources
);
```

## Public Constants

### Timebase Constants

```pascal
const
  // Delphi TDateTime epoch (December 30, 1899)
  // Used by FromDateTime; all TDateTime-based timestamps share this timebase
  CDelphiDateTimeEpoch: Int64 = 18991230;

  // Unix epoch (January 1, 1970, 00:00:00 UTC)
  // Used by FromUnixTime; all Unix time-based timestamps share this timebase
  CUnixTimeEpoch: Int64 = 19700101;
```

These constants can be used with the `Create` or `FromCustom` methods to create timestamps compatible with DateTime or Unix time values.

## API Reference

### Factory Methods (Class Functions)

#### High-Precision Timing

```pascal
class function FromQueryPerformanceCounter: TGpTimestamp;
```
Captures current time from QueryPerformanceCounter (microsecond+ resolution). Cross-platform with TStopwatch fallback.

```pascal
class function FromStopwatch: TGpTimestamp;
```
Captures current time from TStopwatch. Fully cross-platform.

#### Millisecond-Resolution Timing

```pascal
class function FromTickCount: TGpTimestamp;
```
Captures current time from GetTickCount64 (millisecond resolution). Cross-platform with TStopwatch fallback.

```pascal
class function FromTimeGetTime: TGpTimestamp;  // Windows only
```
Captures current time from DSiTimeGetTime64 (millisecond resolution). **Windows only.**

#### External Timestamp Conversions

```pascal
class function FromDateTime(dt: TDateTime): TGpTimestamp;
```
Creates a timestamp from TDateTime value. Uses tsCustom with CDelphiDateTimeEpoch as timebase. All TDateTime-based timestamps are compatible with each other.

```pascal
class function FromUnixTime(unixTime: Int64): TGpTimestamp;
```
Creates a timestamp from Unix time (seconds since January 1, 1970, 00:00:00 UTC). Uses tsCustom with CUnixTimeEpoch as timebase. All Unix time-based timestamps are compatible with each other.

#### DVB Timestamp Support

```pascal
class function FromDVB_PCR(pcr: Int64): TGpTimestamp;
```
Creates a timestamp from DVB PCR (Program Clock Reference) value. PCR uses a 27 MHz clock (1 tick ≈ 37.037 nanoseconds).

```pascal
class function FromDVB_PTS(pts: Int64): TGpTimestamp;
```
Creates a timestamp from DVB PTS (Presentation Time Stamp) value. PTS uses a 90 kHz clock (1 tick ≈ 11111.111 nanoseconds).

#### Custom Timestamps

```pascal
class function FromCustom(aTimeBase: Int64; aValue_ns: Int64): TGpTimestamp;
```
Creates a timestamp with a custom timebase and value in nanoseconds. Timestamps with the same timebase are compatible.

```pascal
class function Create(aTimeSource: TTimeSource; aTimeBase: Int64;
                     aValue_ns: Int64): TGpTimestamp;
```
Creates a timestamp with explicit time source, timebase, and value in nanoseconds. Most flexible creation method.

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
  timestamp := TGpTimestamp.FromQueryPerformanceCounter;
  timestamp := timestamp + TGpTimestamp.Minutes(5);  // Add 5 minutes

  // Combine durations
  delay := TGpTimestamp.Seconds(1) + TGpTimestamp.Milliseconds(500);  // 1.5 seconds
end;
```

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

```pascal
class function Abs(duration_ns: Int64): Int64;
```
Returns the absolute value of a duration in nanoseconds.

### Conversion Methods

```pascal
function ToMilliseconds: Int64;
function ToMicroseconds: Int64;
function ToNanoseconds: Int64;
function ToSeconds: Double;
```
Convert the timestamp value to various time units. Note: Precision depends on the time source; this is just unit conversion.

```pascal
function ToPCR: Int64;
function ToPTS: Int64;
```
Convert the timestamp to DVB PCR or PTS values (27 MHz and 90 kHz clocks respectively).

```pascal
function ToDateTime: TDateTime;
```
Converts the timestamp to TDateTime. Note: Returns a relative time value, not an absolute date/time.

### String Conversions

```pascal
function ToString: string;
```
Returns a human-readable string representation. Format: "1.234567s [QPC]" or "123.456ms [TickCount]".

```pascal
function ToDebugString: string;
```
Returns a detailed debug string with all internal fields. Format: "Source=QPC, Base=0, Value=1234567890ns".

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
function HasElapsed(timeout_ms: Int64): Boolean;
```
Checks if the specified timeout (in milliseconds) has elapsed since this timestamp. Automatically uses the same time source for the comparison. Supported for: tsTickCount, tsQueryPerformanceCounter, tsTimeGetTime (Windows), tsStopwatch.

```pascal
function Elapsed: TGpTimestamp;
```
Returns the time elapsed since this timestamp as a duration (tsDuration). Automatically captures the current time using the same time source and returns the difference. This is a convenience method equivalent to `(TGpTimestamp.FromXxx - self)` but more readable.

**Supported for:** tsTickCount, tsQueryPerformanceCounter, tsTimeGetTime (Windows), tsStopwatch.

**Raises:** EInvalidOpException for unsupported time sources (tsCustom, tsDVB, tsDuration, tsNone).

**Example:**
```pascal
var
  start: TGpTimestamp;
  elapsed_ms: Int64;
begin
  start := TGpTimestamp.FromQueryPerformanceCounter;
  DoWork;
  elapsed_ms := start.Elapsed.ToMilliseconds;  // Clean and readable!
end;
```

### Operators

#### Arithmetic Operators

```pascal
class operator Subtract(const a, b: TGpTimestamp): TGpTimestamp;
```
**Semantics:**
- `timestamp - timestamp` → duration (tsDuration source)
- `duration - duration` → duration
- `duration - timestamp` → **ERROR** (raises EInvalidOpException)

```pascal
class operator Add(const a, b: TGpTimestamp): TGpTimestamp;
```
**Semantics:**
- `timestamp + duration` → timestamp (preserves timestamp's source)
- `duration + timestamp` → timestamp (preserves timestamp's source)
- `duration + duration` → duration
- `timestamp + timestamp` → **ERROR** (raises EInvalidOpException)

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
property TimeBase: Int64 read FTimeBase;
```
The reference timebase (0 for source's natural origin, or custom epoch value).

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

### Rule 2: Custom Timebase Matching
**Two tsCustom timestamps with the same FTimeBase are compatible.** This enables session-relative measurements.

### Rule 3: Everything Else is Incompatible
**Different sources or different custom timebases raise EInvalidOpException.**

Examples:
```pascal
// COMPATIBLE - same source
t1 := TGpTimestamp.FromTickCount;
t2 := TGpTimestamp.FromTickCount;
elapsed := t2 - t1;  // OK

// COMPATIBLE - same custom timebase
timeBase := TGpTimestamp.Now.Value_ns;
m1 := TGpTimestamp.FromCustom(timeBase, value1);
m2 := TGpTimestamp.FromCustom(timeBase, value2);
diff := m2 - m1;  // OK

// INCOMPATIBLE - different sources
t1 := TGpTimestamp.FromTickCount;
t2 := TGpTimestamp.FromQueryPerformanceCounter;
if t1 < t2 then  // EXCEPTION: EInvalidOpException
```

## Usage Examples

### Basic Timing with Fluent API

```pascal
var
  start: TGpTimestamp;
  elapsed_ms: Int64;
begin
  start := TGpTimestamp.FromQueryPerformanceCounter;
  DoWork;

  // Fluent API - subtraction returns duration, call methods on it
  elapsed_ms := (TGpTimestamp.FromQueryPerformanceCounter - start).ToMilliseconds;
  WriteLn('Elapsed: ', elapsed_ms, ' ms');

  // Or use the convenient Elapsed method (recommended!)
  elapsed_ms := start.Elapsed.ToMilliseconds;
  WriteLn('Elapsed: ', elapsed_ms, ' ms');

  // Or access raw nanoseconds
  WriteLn('Elapsed: ', start.Elapsed.Value_ns, ' ns');
end;
```

### Using Now for Best Available Timer

```pascal
var
  start, finish: TGpTimestamp;
begin
  start := TGpTimestamp.FromQueryPerformanceCounter;  // High precision
  Sleep(100);
  finish := TGpTimestamp.FromQueryPerformanceCounter;

  WriteLn('Sleep took: ', (finish - start).ToMilliseconds, ' ms');
end;
```

### Duration Arithmetic

```pascal
var
  timestamp, future: TGpTimestamp;
  duration: TGpTimestamp;
begin
  timestamp := TGpTimestamp.FromQueryPerformanceCounter;

  // Create durations using factory methods (much cleaner!)
  duration := TGpTimestamp.Seconds(1);
  future := timestamp + duration;  // Works with any timestamp source

  // Verify
  Assert((future - timestamp).IsDuration);
  Assert((future - timestamp).ToMilliseconds = 1000);

  // Combine durations
  duration := TGpTimestamp.Minutes(5) + TGpTimestamp.Seconds(30);  // 5.5 minutes
  future := timestamp + duration;

  // Use fractional seconds
  duration := TGpTimestamp.Seconds(2.5);  // 2500 milliseconds
  Assert(duration.ToMilliseconds = 2500);
end;
```

### Custom Timebase for Session Measurements

```pascal
var
  sessionStart: Int64;
  measurement1, measurement2: TGpTimestamp;
  elapsed_ms: Int64;
begin
  // Create a custom timebase representing session start
  sessionStart := TGpTimestamp.FromQueryPerformanceCounter.Value_ns;

  // First measurement
  measurement1 := TGpTimestamp.FromCustom(sessionStart,
                    TGpTimestamp.FromQueryPerformanceCounter.Value_ns);
  DoSomething;

  // Second measurement
  measurement2 := TGpTimestamp.FromCustom(sessionStart,
                    TGpTimestamp.FromQueryPerformanceCounter.Value_ns);

  // Compatible because they share the same custom timebase
  elapsed_ms := (measurement2 - measurement1).ToMilliseconds;
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

  // Compatible - both use CDelphiDateTimeEpoch
  diff := (ts2 - ts1).ToDateTime;
  WriteLn('Elapsed days: ', diff);

  // Round-trip conversion
  dt := ts1.ToDateTime;
end;
```

### Unix Time Conversion

```pascal
var
  unixTime: Int64;
  ts: TGpTimestamp;
begin
  // Current Unix timestamp
  unixTime := DateTimeToUnix(Now);

  // Convert to TGpTimestamp
  ts := TGpTimestamp.FromUnixTime(unixTime);

  // All Unix time timestamps are compatible
  WriteLn('TimeSource: ', Ord(ts.TimeSource));  // tsCustom
  WriteLn('TimeBase: ', ts.TimeBase);            // CUnixTimeEpoch

  // Unix epoch (Jan 1, 1970)
  ts := TGpTimestamp.FromUnixTime(0);
  WriteLn('Unix epoch: ', ts.Value_ns);  // 0
end;
```

### DVB Timestamp Handling

```pascal
var
  pcr_timestamp, pts_timestamp: TGpTimestamp;
  converted_pcr: Int64;
begin
  // Convert from DVB PCR (27 MHz clock) to nanoseconds
  pcr_timestamp := TGpTimestamp.FromDVB_PCR(27000000);  // 1 second

  // Convert from DVB PTS (90 kHz clock) to nanoseconds
  pts_timestamp := TGpTimestamp.FromDVB_PTS(90000);  // 1 second

  // Both use tsDVB source, so they're compatible
  WriteLn('Difference: ', (pcr_timestamp - pts_timestamp).ToMilliseconds, ' ms');

  // Convert back to PCR
  converted_pcr := pcr_timestamp.ToPCR;
  Assert(converted_pcr = 27000000);
end;
```

### Timeout Checking

```pascal
var
  start: TGpTimestamp;
begin
  start := TGpTimestamp.FromQueryPerformanceCounter;

  while not start.HasElapsed(5000) do  // 5 second timeout
  begin
    ProcessMessages;
    if WorkCompleted then
      Break;
  end;

  if start.HasElapsed(5000) then
    WriteLn('Timeout!')
  else
    WriteLn('Completed in time');
end;
```

### Comparing and Finding Min/Max

```pascal
var
  t1, t2, earliest, latest: TGpTimestamp;
begin
  t1 := TGpTimestamp.FromQueryPerformanceCounter;
  Sleep(10);
  t2 := TGpTimestamp.FromQueryPerformanceCounter;

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

### Fail-Fast Approach

Mixing incompatible timebases raises `EInvalidOpException` immediately rather than producing silently incorrect results. This catches bugs early during development.

### Duration vs Timestamp Semantics

- **Timestamps** have a specific time source and timebase
- **Durations** (tsDuration) represent time differences and are universally compatible
- **Arithmetic rules** enforce correct semantics:
  - timestamp - timestamp = duration ✓
  - timestamp + duration = timestamp ✓
  - timestamp + timestamp = ERROR ✗

## Testing

The unit includes comprehensive unit tests in `GpTimestamp.UnitTests.pas` with 19 test methods covering:

- Basic timing with various sources
- Unit conversions (ns, μs, ms, seconds)
- Comparisons and ordering
- Custom timebase functionality
- Incompatible source detection
- DVB PCR/PTS conversions
- Stopwatch integration
- TimeGetTime (Windows only)
- DateTime and Unix time conversions
- All arithmetic operators
- String conversions
- Utility functions (Min, Max, Zero, Invalid, Abs)
- Negative duration handling

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
    FTimeBase: Int64;          // 8 bytes
    FValue: Int64;             // 8 bytes
  // Total: 20 bytes (may be padded to 24 bytes depending on alignment)
```

### Conversion Constants

Internal constants used for all conversions (defined in implementation section):

```pascal
const
  CNanosecondsPerMicrosecond = 1000;
  CNanosecondsPerMillisecond = 1000000;
  CNanosecondsPerSecond = 1000000000;
  CNanosecondsPerDay = Int64(86400000000000);

  CDVB_PCR_Frequency_MHz = 27;   // DVB PCR: 27 MHz clock
  CDVB_PTS_Frequency_kHz = 90;   // DVB PTS: 90 kHz clock
```

## Best Practices

### When to Use Which Time Source

| Use Case | Recommended Source | Reason |
|----------|-------------------|--------|
| High-precision profiling | `FromQueryPerformanceCounter` | Microsecond+ resolution |
| Cross-platform timing | `FromStopwatch` | Guaranteed cross-platform |
| Simple timeout tracking | `FromTickCount` | Sufficient for millisecond timeouts |
| Windows multimedia | `FromTimeGetTime` | Consistent with multimedia timers |
| DVB/MPEG timestamps | `FromDVB_PCR` / `FromDVB_PTS` | Native DVB support |
| Session-relative times | `FromCustom` | Share custom timebase |
| External timestamps | `FromDateTime` / `FromUnixTime` | Maintain compatibility |

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
  start := TGpTimestamp.FromTickCount;
  DoWork;
  elapsed_ms := (TGpTimestamp.FromTickCount - start).ToMilliseconds;
end;
```

### Use Descriptive Variable Names

```pascal
var
  requestStart, requestEnd: TGpTimestamp;
  processingDuration: TGpTimestamp;
  timeout_ms: Int64;
begin
  requestStart := TGpTimestamp.FromQueryPerformanceCounter;
  ProcessRequest;
  requestEnd := TGpTimestamp.FromQueryPerformanceCounter;

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
  t1 := TGpTimestamp.FromQueryPerformanceCounter;
  t2 := TGpTimestamp.FromQueryPerformanceCounter;
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
