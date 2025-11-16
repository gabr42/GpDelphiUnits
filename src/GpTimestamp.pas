(*:Type-safe timestamp with multiple time source. Prevents mixing incompatible time measurements.

   @author Primoz Gabrijelcic (navigator), Claude Code (driver)
   @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2025, Primoz Gabrijelcic
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
- Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.
- The name of the Primoz Gabrijelcic may not be used to endorse or promote
  products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

   Author            : Primoz Gabrijelcic
   Creation date     : 2025-11-15
   Last modification : 2025-11-16
   Version           : 0.1
</pre>*)(*
   History:
     0.1: 2025-11-15
       - Released. Not yet fully tested. There may be dragons!
*)

unit GpTimestamp;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils;

type
  /// <summary>
  /// Identifies which clock source is used for time measurement.
  /// </summary>
  TTimeSource = (
    tsNone,                    // Uninitialized
    tsTickCount,               // GetTickCount64 - millisecond resolution
    tsQueryPerformanceCounter, // QueryPerformanceCounter - high precision
    tsTimeGetTime,             // DSiTimeGetTime64 - millisecond resolution (Windows only)
    tsStopwatch,               // TStopwatch (cross-platform)
    tsCustom,                  // User-defined timebase
    tsDVB,                     // DVB/MPEG PCR/PTS timestamps
    tsDuration                 // Pure duration/difference, compatible with all sources
  );

  /// <summary>
  /// Time measurement type that stores both the timebase and time value.
  /// All time values are stored internally as nanoseconds.
  /// Prevents mixing times from different timebases through operator overloading.
  /// </summary>
  TGpTimestamp = record
  strict private
    FTimeSource: TTimeSource;  // Which clock source was used
    FTimeBase: Int64;          // Reference point (0 = use source's natural origin)
    FValue: Int64;             // Time value in nanoseconds

    procedure CheckCompatible(const other: TGpTimestamp); inline;
    class function GetPerformanceFrequency: Int64; static;
  public
    /// <summary>
    /// Captures current time from GetTickCount64 (millisecond resolution).
    /// </summary>
    class function FromTickCount: TGpTimestamp; static;

    /// <summary>
    /// Captures current time from QueryPerformanceCounter (microsecond+ resolution).
    /// </summary>
    class function FromQueryPerformanceCounter: TGpTimestamp; static;

    {$IFDEF MSWINDOWS}
    /// <summary>
    /// Captures current time from DSiTimeGetTime64 (millisecond resolution).
    /// </summary>
    class function FromTimeGetTime: TGpTimestamp; static;
    {$ENDIF}

    /// <summary>
    /// Captures current time from TStopwatch (cross-platform).
    /// </summary>
    class function FromStopwatch: TGpTimestamp; static;

    /// <summary>
    /// Creates a timestamp from a DVB PCR (Program Clock Reference) value.
    /// PCR uses a 27 MHz clock (1 tick = ~37.037 nanoseconds).
    /// </summary>
    class function FromDVB_PCR(pcr: Int64): TGpTimestamp; static;

    /// <summary>
    /// Creates a timestamp from a DVB PTS (Presentation Time Stamp) value.
    /// PTS uses a 90 kHz clock (1 tick = ~11111.111 nanoseconds).
    /// </summary>
    class function FromDVB_PTS(pts: Int64): TGpTimestamp; static;

    /// <summary>
    /// Creates a timestamp with a custom timebase and value.
    /// </summary>
    class function FromCustom(aTimeBase: Int64; aValue_ns: Int64): TGpTimestamp; static;

    /// <summary>
    /// Creates a timestamp with explicit time source, timebase, and value.
    /// </summary>
    class function Create(aTimeSource: TTimeSource; aTimeBase: Int64; aValue_ns: Int64): TGpTimestamp; static;

    /// <summary>
    /// Creates a timestamp from TDateTime value.
    /// Uses tsCustom with Delphi's TDateTime epoch (1899-12-30) as timebase.
    /// All TDateTime-based timestamps are compatible with each other.
    /// </summary>
    class function FromDateTime(dt: TDateTime): TGpTimestamp; static;

    /// <summary>
    /// Creates a timestamp from Unix time (seconds since January 1, 1970, 00:00:00 UTC).
    /// Uses tsCustom with Unix epoch (1970-01-01) as timebase.
    /// All Unix time-based timestamps are compatible with each other.
    /// </summary>
    class function FromUnixTime(unixTime: Int64): TGpTimestamp; static;

    /// <summary>
    /// Returns a zero timestamp for the specified time source.
    /// </summary>
    class function Zero(source: TTimeSource): TGpTimestamp; static;

    /// <summary>
    /// Returns an invalid timestamp (tsNone).
    /// </summary>
    class function Invalid: TGpTimestamp; static;

    /// <summary>
    /// Returns the earlier of two timestamps.
    /// Raises an exception if timestamps are incompatible.
    /// </summary>
    class function Min(const a, b: TGpTimestamp): TGpTimestamp; static;

    /// <summary>
    /// Returns the later of two timestamps.
    /// Raises an exception if timestamps are incompatible.
    /// </summary>
    class function Max(const a, b: TGpTimestamp): TGpTimestamp; static;

    /// <summary>
    /// Returns the absolute value of a duration in nanoseconds.
    /// </summary>
    class function Abs(duration_ns: Int64): Int64; static; inline;

    /// <summary>
    /// Returns the time value in milliseconds.
    /// </summary>
    function ToMilliseconds: Int64; inline;

    /// <summary>
    /// Returns the time value in microseconds.
    /// </summary>
    function ToMicroseconds: Int64; inline;

    /// <summary>
    /// Returns the time value in nanoseconds.
    /// Note: Precision depends on the time source, this is just a unit conversion.
    /// </summary>
    function ToNanoseconds: Int64; inline;

    /// <summary>
    /// Returns the time value in seconds as a floating-point number.
    /// </summary>
    function ToSeconds: Double; inline;

    /// <summary>
    /// Converts the timestamp to a DVB PCR (Program Clock Reference) value.
    /// PCR uses a 27 MHz clock (1 tick = ~37.037 nanoseconds).
    /// </summary>
    function ToPCR: Int64; inline;

    /// <summary>
    /// Converts the timestamp to a DVB PTS (Presentation Time Stamp) value.
    /// PTS uses a 90 kHz clock (1 tick = ~11111.111 nanoseconds).
    /// </summary>
    function ToPTS: Int64; inline;

    /// <summary>
    /// Converts the timestamp to TDateTime.
    /// Note: This returns a relative time value, not an absolute date/time.
    /// </summary>
    function ToDateTime: TDateTime; inline;

    /// <summary>
    /// Returns a human-readable string representation of the timestamp.
    /// Format: "1.234567s [QPC]" or "123.456ms [TickCount]"
    /// </summary>
    function ToString: string;

    /// <summary>
    /// Returns a detailed debug string with all internal fields.
    /// Format: "Source=QPC, Base=0, Value=1234567890ns"
    /// </summary>
    function ToDebugString: string;

    /// <summary>
    /// Returns true if the timestamp is valid (has a time source assigned).
    /// </summary>
    function IsValid: Boolean; inline;

    /// <summary>
    /// Returns true if the timestamp represents a duration (tsDuration source).
    /// </summary>
    function IsDuration: Boolean; inline;

    /// <summary>
    /// Checks if the specified timeout has elapsed since this timestamp.
    /// Automatically uses the same time source for the comparison.
    /// </summary>
    function HasElapsed(timeout_ms: Int64): Boolean;

    /// <summary>
    /// Subtracts two timestamps and returns a duration (tsDuration).
    /// Raises an exception if the timestamps have incompatible timebases.
    /// Can also subtract durations: duration - duration = duration.
    /// Cannot subtract timestamp from duration (raises exception).
    /// </summary>
    class operator Subtract(const a, b: TGpTimestamp): TGpTimestamp;

    /// <summary>
    /// Adds two timestamps/durations.
    /// timestamp + duration = timestamp (with timestamp's source)
    /// duration + timestamp = timestamp (with timestamp's source)
    /// duration + duration = duration
    /// timestamp + timestamp raises an exception (invalid operation)
    /// </summary>
    class operator Add(const a, b: TGpTimestamp): TGpTimestamp;

    /// <summary>
    /// Compares two timestamps. Raises an exception if timebases are incompatible.
    /// </summary>
    class operator GreaterThan(const a, b: TGpTimestamp): Boolean;
    class operator LessThan(const a, b: TGpTimestamp): Boolean;
    class operator GreaterThanOrEqual(const a, b: TGpTimestamp): Boolean;
    class operator LessThanOrEqual(const a, b: TGpTimestamp): Boolean;
    class operator Equal(const a, b: TGpTimestamp): Boolean;
    class operator NotEqual(const a, b: TGpTimestamp): Boolean;

    /// <summary>
    /// The time source used for this timestamp.
    /// </summary>
    property TimeSource: TTimeSource read FTimeSource;

    /// <summary>
    /// The reference timebase (0 for source's natural origin).
    /// </summary>
    property TimeBase: Int64 read FTimeBase;

    /// <summary>
    /// The time value in nanoseconds.
    /// </summary>
    property Value_ns: Int64 read FValue;
  end;

const
  /// <summary>
  /// Timebase constant representing the Delphi TDateTime epoch (December 30, 1899).
  /// All TDateTime-based timestamps share this timebase for compatibility.
  /// Value is the epoch date in YYYYMMDD format.
  /// </summary>
  CDelphiDateTimeEpoch: Int64 = 18991230;

  /// <summary>
  /// Timebase constant representing the Unix epoch (January 1, 1970, 00:00:00 UTC).
  /// All Unix time-based timestamps share this timebase for compatibility.
  /// Value is the epoch date in YYYYMMDD format.
  /// </summary>
  CUnixTimeEpoch: Int64 = 19700101;

implementation

uses
  System.Diagnostics
  {$IFDEF MSWINDOWS}
  ,Winapi.Windows
  ,DSiWin32
  {$ENDIF}
  ;

const
  // Time conversion constants
  CNanosecondsPerMicrosecond = 1000;
  CNanosecondsPerMillisecond = 1000000;
  CNanosecondsPerSecond = 1000000000;
  CNanosecondsPerDay = Int64(86400000000000);  // 24 * 60 * 60 * 1000000000

  // DVB timestamp conversion constants
  CDVB_PCR_Frequency_MHz = 27;   // DVB PCR uses 27 MHz clock
  CDVB_PTS_Frequency_kHz = 90;   // DVB PTS uses 90 kHz clock

{ TGpTimestamp }

procedure TGpTimestamp.CheckCompatible(const other: TGpTimestamp);
begin
  // Rule 0: Duration is compatible with everything
  if (FTimeSource = tsDuration) or (other.FTimeSource = tsDuration) then
    Exit;  // Compatible!

  // Rule 1: Same source type is always compatible
  //   (e.g., all FromTickCount calls are compatible)
  if (FTimeSource <> tsNone) and (FTimeSource = other.FTimeSource) and
     (FTimeSource <> tsCustom) then
    Exit;  // Compatible!

  // Rule 2: Same custom timebase is compatible
  if (FTimeSource = tsCustom) and (other.FTimeSource = tsCustom) and
     (FTimeBase <> 0) and (FTimeBase = other.FTimeBase) then
    Exit;  // Compatible!

  // Otherwise: incompatible
  raise EInvalidOpException.CreateFmt(
    'Cannot mix incompatible time measurements: [Source=%d, TimeBase=%d] vs [Source=%d, TimeBase=%d]',
    [Ord(FTimeSource), FTimeBase, Ord(other.FTimeSource), other.FTimeBase]);
end;

class function TGpTimestamp.GetPerformanceFrequency: Int64;
{$IFDEF MSWINDOWS}
var
  freq: Int64;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  if not QueryPerformanceFrequency(freq) then
    raise Exception.Create('QueryPerformanceFrequency failed');
  Result := freq;
  {$ELSE}
  Result := TStopwatch.Frequency;
  {$ENDIF}
end;

class function TGpTimestamp.FromTickCount: TGpTimestamp;
begin
  Result.FTimeSource := tsTickCount;
  Result.FTimeBase := 0;
  {$IFDEF MSWINDOWS}
  Result.FValue := GetTickCount64 * CNanosecondsPerMillisecond;  // Convert milliseconds to nanoseconds
  {$ELSE}
  // Fallback to TStopwatch on non-Windows platforms
  Result.FValue := Round(TStopwatch.GetTimeStamp / TStopwatch.Frequency * CNanosecondsPerSecond);
  {$ENDIF}
end;

class function TGpTimestamp.FromQueryPerformanceCounter: TGpTimestamp;
{$IFDEF MSWINDOWS}
var
  counter: Int64;
  freq: Int64;
{$ENDIF}
begin
  Result.FTimeSource := tsQueryPerformanceCounter;
  Result.FTimeBase := 0;
  {$IFDEF MSWINDOWS}
  if not QueryPerformanceCounter(counter) then
    raise Exception.Create('QueryPerformanceCounter failed');
  freq := GetPerformanceFrequency;
  // Convert to nanoseconds: (counter / frequency) * CNanosecondsPerSecond
  Result.FValue := Round(counter / freq * CNanosecondsPerSecond);
  {$ELSE}
  Result.FValue := Round(TStopwatch.GetTimeStamp / TStopwatch.Frequency * CNanosecondsPerSecond);
  {$ENDIF}
end;

{$IFDEF MSWINDOWS}
class function TGpTimestamp.FromTimeGetTime: TGpTimestamp;
begin
  Result.FTimeSource := tsTimeGetTime;
  Result.FTimeBase := 0;
  // DSiTimeGetTime64 returns milliseconds, convert to nanoseconds
  Result.FValue := DSiTimeGetTime64 * CNanosecondsPerMillisecond;
end;
{$ENDIF}

class function TGpTimestamp.FromStopwatch: TGpTimestamp;
begin
  Result.FTimeSource := tsStopwatch;
  Result.FTimeBase := 0;
  Result.FValue := Round(TStopwatch.GetTimeStamp / TStopwatch.Frequency * CNanosecondsPerSecond);
end;

class function TGpTimestamp.FromDVB_PCR(pcr: Int64): TGpTimestamp;
begin
  Result.FTimeSource := tsDVB;
  Result.FTimeBase := 0;
  // PCR is 27 MHz clock: 1 tick = 1000/27 nanoseconds
  Result.FValue := Round(pcr * CNanosecondsPerMicrosecond / CDVB_PCR_Frequency_MHz);
end;

class function TGpTimestamp.FromDVB_PTS(pts: Int64): TGpTimestamp;
begin
  Result.FTimeSource := tsDVB;
  Result.FTimeBase := 0;
  // PTS is 90 kHz clock: 1 tick = 100000/9 nanoseconds
  Result.FValue := Round(pts * CNanosecondsPerMillisecond / CDVB_PTS_Frequency_kHz);
end;

class function TGpTimestamp.FromCustom(aTimeBase: Int64; aValue_ns: Int64): TGpTimestamp;
begin
  Result.FTimeSource := tsCustom;
  Result.FTimeBase := aTimeBase;
  Result.FValue := aValue_ns;
end;

class function TGpTimestamp.Create(aTimeSource: TTimeSource; aTimeBase: Int64; aValue_ns: Int64): TGpTimestamp;
begin
  Result.FTimeSource := aTimeSource;
  Result.FTimeBase := aTimeBase;
  Result.FValue := aValue_ns;
end;

class function TGpTimestamp.FromDateTime(dt: TDateTime): TGpTimestamp;
begin
  Result.FTimeSource := tsCustom;
  Result.FTimeBase := CDelphiDateTimeEpoch;
  // TDateTime is in days, convert to nanoseconds
  Result.FValue := Round(dt * CNanosecondsPerDay);
end;

class function TGpTimestamp.FromUnixTime(unixTime: Int64): TGpTimestamp;
begin
  Result.FTimeSource := tsCustom;
  Result.FTimeBase := CUnixTimeEpoch;
  // Unix time is in seconds, convert to nanoseconds
  Result.FValue := unixTime * CNanosecondsPerSecond;
end;

class function TGpTimestamp.Zero(source: TTimeSource): TGpTimestamp;
begin
  Result.FTimeSource := source;
  Result.FTimeBase := 0;
  Result.FValue := 0;
end;

class function TGpTimestamp.Invalid: TGpTimestamp;
begin
  Result.FTimeSource := tsNone;
  Result.FTimeBase := 0;
  Result.FValue := 0;
end;

class function TGpTimestamp.Min(const a, b: TGpTimestamp): TGpTimestamp;
begin
  a.CheckCompatible(b);
  if a.FValue <= b.FValue then
    Result := a
  else
    Result := b;
end;

class function TGpTimestamp.Max(const a, b: TGpTimestamp): TGpTimestamp;
begin
  a.CheckCompatible(b);
  if a.FValue >= b.FValue then
    Result := a
  else
    Result := b;
end;

class function TGpTimestamp.Abs(duration_ns: Int64): Int64;
begin
  if duration_ns < 0 then
    Result := -duration_ns
  else
    Result := duration_ns;
end;

function TGpTimestamp.ToMilliseconds: Int64;
begin
  Result := FValue div CNanosecondsPerMillisecond;
end;

function TGpTimestamp.ToMicroseconds: Int64;
begin
  Result := FValue div CNanosecondsPerMicrosecond;
end;

function TGpTimestamp.ToNanoseconds: Int64;
begin
  Result := FValue;
end;

function TGpTimestamp.ToSeconds: Double;
begin
  Result := FValue / CNanosecondsPerSecond;
end;

function TGpTimestamp.ToPCR: Int64;
begin
  // Convert nanoseconds to 27 MHz PCR clock
  Result := Round(FValue * CDVB_PCR_Frequency_MHz / CNanosecondsPerMicrosecond);
end;

function TGpTimestamp.ToPTS: Int64;
begin
  // Convert nanoseconds to 90 kHz PTS clock
  Result := Round(FValue * CDVB_PTS_Frequency_kHz / CNanosecondsPerMillisecond);
end;

function TGpTimestamp.ToDateTime: TDateTime;
begin
  // Convert nanoseconds to days (TDateTime unit)
  Result := FValue / CNanosecondsPerDay;
end;

function TGpTimestamp.ToString: string;
const
  SourceNames: array[TTimeSource] of string = (
    'None', 'TickCount', 'QPC', 'TimeGetTime', 'Stopwatch', 'Custom', 'DVB', 'Duration'
  );
var
  absValue: Int64;
  seconds, milliseconds: Double;
  fs: TFormatSettings;
begin
  if FTimeSource = tsNone then
    Exit('Invalid');

  fs := TFormatSettings.Create;
  fs.DecimalSeparator := '.';

  absValue := System.Abs(FValue);
  seconds := absValue / CNanosecondsPerSecond;
  milliseconds := absValue / CNanosecondsPerMillisecond;

  if absValue >= CNanosecondsPerSecond then  // >= 1 second
  begin
    if FValue < 0 then
      Result := Format('-%1.6fs [%s]', [seconds, SourceNames[FTimeSource]], fs)
    else
      Result := Format('%1.6fs [%s]', [seconds, SourceNames[FTimeSource]], fs);
  end
  else  // < 1 second
  begin
    if FValue < 0 then
      Result := Format('-%1.3fms [%s]', [milliseconds, SourceNames[FTimeSource]], fs)
    else
      Result := Format('%1.3fms [%s]', [milliseconds, SourceNames[FTimeSource]], fs);
  end;
end;

function TGpTimestamp.ToDebugString: string;
const
  SourceNames: array[TTimeSource] of string = (
    'None', 'TickCount', 'QPC', 'TimeGetTime', 'Stopwatch', 'Custom', 'DVB', 'Duration'
  );
begin
  Result := Format('Source=%s, Base=%d, Value=%dns',
    [SourceNames[FTimeSource], FTimeBase, FValue]);
end;

function TGpTimestamp.IsValid: Boolean;
begin
  Result := FTimeSource <> tsNone;
end;

function TGpTimestamp.IsDuration: Boolean;
begin
  Result := FTimeSource = tsDuration;
end;

function TGpTimestamp.HasElapsed(timeout_ms: Int64): Boolean;
var
  currentTime: TGpTimestamp;
begin
  // Get current time from same source
  case FTimeSource of
    tsTickCount: currentTime := FromTickCount;
    tsQueryPerformanceCounter: currentTime := FromQueryPerformanceCounter;
    {$IFDEF MSWINDOWS}
    tsTimeGetTime: currentTime := FromTimeGetTime;
    {$ENDIF}
    tsStopwatch: currentTime := FromStopwatch;
  else
    raise EInvalidOpException.CreateFmt(
      'HasElapsed not supported for time source: %d', [Ord(FTimeSource)]);
  end;

  Result := (currentTime.FValue - FValue) >= (timeout_ms * CNanosecondsPerMillisecond);
end;

class operator TGpTimestamp.Subtract(const a, b: TGpTimestamp): TGpTimestamp;
begin
  a.CheckCompatible(b);

  // duration - timestamp is invalid
  if (a.FTimeSource = tsDuration) and (b.FTimeSource <> tsDuration) then
    raise EInvalidOpException.Create('Cannot subtract timestamp from duration');

  // Result is always a duration
  Result.FTimeSource := tsDuration;
  Result.FTimeBase := 0;
  Result.FValue := a.FValue - b.FValue;
end;

class operator TGpTimestamp.Add(const a, b: TGpTimestamp): TGpTimestamp;
begin
  a.CheckCompatible(b);

  // timestamp + timestamp is invalid
  if (a.FTimeSource <> tsDuration) and (b.FTimeSource <> tsDuration) then
    raise EInvalidOpException.Create('Cannot add two timestamps; only timestamp + duration is valid');

  // duration + duration = duration
  if (a.FTimeSource = tsDuration) and (b.FTimeSource = tsDuration) then
  begin
    Result.FTimeSource := tsDuration;
    Result.FTimeBase := 0;
    Result.FValue := a.FValue + b.FValue;
  end
  // timestamp + duration = timestamp (preserve timestamp's source)
  else if a.FTimeSource <> tsDuration then
  begin
    Result := a;
    Result.FValue := a.FValue + b.FValue;
  end
  // duration + timestamp = timestamp (preserve timestamp's source)
  else
  begin
    Result := b;
    Result.FValue := a.FValue + b.FValue;
  end;
end;

class operator TGpTimestamp.GreaterThan(const a, b: TGpTimestamp): Boolean;
begin
  a.CheckCompatible(b);
  Result := a.FValue > b.FValue;
end;

class operator TGpTimestamp.LessThan(const a, b: TGpTimestamp): Boolean;
begin
  a.CheckCompatible(b);
  Result := a.FValue < b.FValue;
end;

class operator TGpTimestamp.GreaterThanOrEqual(const a, b: TGpTimestamp): Boolean;
begin
  a.CheckCompatible(b);
  Result := a.FValue >= b.FValue;
end;

class operator TGpTimestamp.LessThanOrEqual(const a, b: TGpTimestamp): Boolean;
begin
  a.CheckCompatible(b);
  Result := a.FValue <= b.FValue;
end;

class operator TGpTimestamp.Equal(const a, b: TGpTimestamp): Boolean;
begin
  a.CheckCompatible(b);
  Result := a.FValue = b.FValue;
end;

class operator TGpTimestamp.NotEqual(const a, b: TGpTimestamp): Boolean;
begin
  a.CheckCompatible(b);
  Result := a.FValue <> b.FValue;
end;

end.
