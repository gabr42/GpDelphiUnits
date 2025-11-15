# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

GpDelphiUnits is a collection of open-source Delphi utility units providing Win32/Win64 wrappers, data structures, synchronization primitives, file I/O helpers, and various cross-cutting utilities. This is a library repository - there are no build artifacts, only reusable Pascal units.

## Project Structure

- `src/` - All Pascal unit files (.pas)
- `src/tests/` - Test projects (.dpr, .dproj) for specific units
- `update.bat` - Batch file to synchronize files from another location (x:\gp\common)

## Key Units

### Core Infrastructure
- **DSiWin32.pas** - Extensive Win32/Win64 API wrappers and helper functions (378KB, version 2.09+)
- **GpStuff.pas** - General utilities including TGpBuffer, generic helpers, constants (version 2.29)

### Attribute-Based Frameworks
- **GpAutoCreate.pas** - Automatic field creation/destruction via `[GpManaged]` attribute
- **GpCommandLineParser.pas** - Parse command-line arguments using attributes on class properties

### Data Structures
- **GpLists.pas** - TList descendants and compatible classes (297KB)
- **GpLockFreeQueue.pas** - Lock-free, O(1) threadsafe queue implementation
- **GpStringHash.pas** - Preallocated hash table implementation

### File & Stream I/O
- **GpHugeF.pas** - 64-bit file functions with enhanced functionality (155KB)
- **GpTextFile.pas** - 8/16-bit text file interface (uses GpHugeF)
- **GpStreams.pas** - TStream descendants and helpers (115KB)
- **GpStreamWrapper.pas** - Stream wrapper utilities
- **GpTextStream.pas** - Unicode stream wrapper with automatic encoding detection

### Synchronization
- **GpSync.pas** - Enhanced synchronization primitives (88KB)
- **GpSync.CondVar.pas** - Condition variable implementation
- **SpinLock.pas** - Scalable atomic lock

### Time & Measurement
- **GpTimestamp.pas** - Type-safe timestamp with multiple time sources (TGpTimestamp record)
  - Prevents mixing incompatible time measurements through operator overloading
  - Supports GetTickCount64, QueryPerformanceCounter, and custom timebases
  - All values stored internally in nanoseconds (provides 292 years of range at nanosecond precision)
  - Replaces unsafe raw Int64 time values that could be accidentally mixed

### Specialized Utilities
- **GpSharedMemory.pas** - Shared memory implementation (183KB)
- **GpSharedEvents.pas** - Distributed multicast event manager
- **GpStructuredStorage.pas** - Compound file/embedded file system (112KB)
- **GpVersion.pas** - Version info accessors, modifiers, storage
- **GpSecurity.pas** - Windows NT security wrappers
- **GpSysHook.pas** - System-wide hooks (keyboard, mouse, shell, CBT)

## Testing

Test projects are located in `src/tests/` directory:
- `GpTimestampTests.dpr` - DUnitX tests for GpTimestamp (18 tests covering all features)
- `TestGpAutoCreate.dpr/dproj` - Tests for GpAutoCreate
- `TestGpCommandLineParser.dpr/dproj` - Tests for command line parser
- `TestGpStringHash.dpr/dproj` - Tests for string hash
- `TestCondVar.dpr/dproj` - Tests for condition variables
- `DemoCondVar.dpr/dproj` - Demonstration for condition variables

Individual units may also have standalone test programs (e.g., `GpTimestamp_Test.pas/.exe`).

## Design Patterns & Key Concepts

### Type-Safe Time Measurement (GpTimestamp)

**Problem Solved:**
Traditional time measurement in Delphi has three critical issues:
1. Ambiguous units - Hard to tell if Int64 stores milliseconds, microseconds, or nanoseconds
2. Unsafe mixing - Easy to accidentally subtract QueryPerformanceCounter from GetTickCount values
3. No compile-time safety - Relies only on variable naming conventions (_ms, _us suffixes)

**Design Philosophy:**
- **Fail-fast approach** - Mixing incompatible timebases raises EInvalidOpException immediately
- **Operator overloading** - Automatic compatibility checking on all arithmetic and comparisons
- **Internal precision** - All values stored as nanoseconds (Int64) for maximum precision and future needs

**Timebase Tracking:**
Each TGpTimestamp stores: `(FTimeSource: TTimeSource, FTimeBase: Int64, FValue: Int64)`
- `TTimeSource` enum: tsNone, tsTickCount, tsQueryPerformanceCounter, tsTimeGetTime, tsStopwatch, tsCustom, tsDVB, tsDuration
- `FTimeBase`: Reference point (0 = source's natural origin, or custom value)
- `FValue`: Time value in nanoseconds
- `tsDuration`: Special source for pure durations/differences, compatible with all other sources

**Compatibility Rules:**
1. `tsDuration` is compatible with everything (allows duration + timestamp arithmetic)
2. Same source type = automatically compatible (e.g., all `FromTickCount` calls)
3. Same custom timebase = compatible (allows session-based measurements)
4. Different sources or timebases = raises exception on comparison/arithmetic

**Arithmetic Semantics:**
- `timestamp - timestamp` → duration (with `tsDuration` source)
- `timestamp + duration` → timestamp (preserves timestamp's source)
- `duration + duration` → duration
- `timestamp - duration` → timestamp
- `timestamp + timestamp` → **ERROR** (raises EInvalidOpException)
- `duration - timestamp` → **ERROR** (raises EInvalidOpException)

**Usage Patterns:**

Simple timing with fluent API (Subtract returns TGpTimestamp with tsDuration):
```pascal
var
  start: TGpTimestamp;
  elapsed_ms: Int64;
begin
  start := TGpTimestamp.Now;
  DoWork;
  // Fluent API - subtraction returns duration, call methods on it
  elapsed_ms := (TGpTimestamp.Now - start).ToMilliseconds;
  WriteLn('Elapsed: ', elapsed_ms, ' ms');

  // Or access raw nanoseconds
  WriteLn('Elapsed: ', (TGpTimestamp.Now - start).Value_ns, ' ns');
end;
```

Duration arithmetic (duration is compatible with all timestamp sources):
```pascal
var
  timestamp, future: TGpTimestamp;
  duration: TGpTimestamp;
begin
  timestamp := TGpTimestamp.Now;

  // Create a duration of 1 second
  duration := TGpTimestamp.Create(tsDuration, 0, 1000000000);
  future := timestamp + duration;  // Works with any timestamp source

  // Durations can be added/subtracted
  Assert.IsTrue((future - timestamp).IsDuration);
  Assert.AreEqual(1000, (future - timestamp).ToMilliseconds);
end;
```

Custom timebase for related measurements:
```pascal
var
  timeBase: Int64;
  measurement1, measurement2: TGpTimestamp;
  elapsed_ms: Int64;
begin
  timeBase := TGpTimestamp.CreateTimeBase;
  measurement1 := TGpTimestamp.Create(timeBase, TGpTimestamp.Now.Value_ns);
  // Later...
  measurement2 := TGpTimestamp.Create(timeBase, TGpTimestamp.Now.Value_ns);
  elapsed_ms := (measurement2 - measurement1).ToMilliseconds;  // Compatible!
end;
```

Mixing sources fails safely at runtime:
```pascal
t1 := TGpTimestamp.FromTickCount;
t2 := TGpTimestamp.FromQueryPerformanceCounter;
if t1 < t2 then  // EXCEPTION: Cannot mix incompatible time measurements
```

DVB timestamp support (for digital video broadcasting):
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
end;
```

**When to Use:**
- Prefer TGpTimestamp over raw Int64 for any time measurement code
- Use `Now` for best available high-precision timing (uses QueryPerformanceCounter)
- Use `FromTickCount` when millisecond resolution is sufficient
- Use `FromQueryPerformanceCounter` when you need explicit high-precision control
- Use `FromStopwatch` for compatibility with TStopwatch
- Use `FromTimeGetTime` on Windows for multimedia timer precision
- Use `FromDVB_PCR`/`FromDVB_PTS` for digital video broadcasting timestamps
- Use custom timebase when measurements need to be relative to a session start time
- Use `tsDuration` source for pure duration values that work with any timestamp source

**Breaking Change Note:**
The Subtract operator now returns `TGpTimestamp` (with `tsDuration` source) instead of `Int64`.
Code like `elapsed := t2 - t1` must be updated to `elapsed := (t2 - t1).Value_ns` or use the fluent API methods like `.ToMilliseconds`.

## Coding Standards

### Delphi Conventions
- All new types must follow Delphi naming standards (TClassName, IInterfaceName, etc.)
- Use triple-slash XML comments (`///`) for public API documentation
- Include version history in unit headers with date, version number, and changes

### Error Handling
- When API functions fail and exception is raised, ALWAYS include OS error code and error message
- Before using GetLastError, search codebase for custom implementations - if found, qualify Windows API calls with `Winapi.Windows.GetLastError`

### Variable Naming
- Use `_ms` suffix for millisecond time values (when using raw Int64)
- Use `_us` suffix for microsecond time values (when using raw Int64)
- Use `_ns` suffix for nanosecond time values (when using raw Int64)
- Prefer TGpTimestamp type over raw Int64 for new time measurement code
- Use inline variables when scope is limited to if/while/repeat/for statements
- Do not capitalize 'assigned' function calls

### Code Quality
- When reading existing code, check for 'copy and paste' errors

## Cross-Platform Support

Several units support both Windows and non-Windows platforms through conditional compilation:
- `{$IFDEF MSWINDOWS}` / `{$IFDEF FPC}` are common
- Some units (GpStuff, GpTimestamp) work on Linux with FPC/Delphi Rio+

## License

Free for personal and commercial use. No rights reserved.
Most units authored by Primoz Gabrijelcic with various contributors acknowledged in file headers.
