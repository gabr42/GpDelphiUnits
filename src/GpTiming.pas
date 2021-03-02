unit GpTiming;

interface

uses
  Windows,
  SysUtils,
  Classes,
  GpAutoCreate;

type
  Profile = class
    class function  DebugStart(const name: string): int64;
    class function  DebugStop(const name: string; timeLimit: cardinal = INFINITE; const errMsg: string = ''; logOnly: boolean = false): int64;
    class procedure Checkpoint(const name: string; id: integer); overload;
    class procedure Checkpoint(const name: string; const descr: string); overload;
    class function  Description(threadID: cardinal; const name: string): string; // careful - volatile and no locking
    class function  Start(const name: string): int64;
    class function  Stop(const name: string; timeLimit: cardinal = INFINITE; const errMsg: string = ''; logOnly: boolean = false): int64;
  end; { Profile }

  //Simple interval timer, NOT thread-safe!
  TIntervalTimer = class(TGpManaged)
  public const
    CHighestTimer = 256;
  strict private
    FCount   : array [1..CHighestTimer] of integer;
    FDuration: array [1..CHighestTimer] of int64;
    FHigh    : integer;
    FMax     : array [1..CHighestTimer] of int64;
    FMicroSec: boolean;
    FMin     : array [1..CHighestTimer] of int64;
    FNow     : TFunc<int64>;
    FStart   : array [1..CHighestTimer] of int64;
    FUnits   : string;
    [GpManaged]
    FLog     : TStringList;
  public
    procedure Initialize(useMicroseconds: boolean = false);
    procedure Log(const msg: string); overload;
    procedure Log(const msg: string; const params: array of const); overload;
    function  Report(showCounters: boolean = false; showNonzeroOnly: boolean = false;
                reportOnlyTimers: TArray<integer> = nil): string;
    procedure Restart(interval: integer); inline;
    procedure Start(interval: integer); overload; inline;
    procedure Start(const intervals: array of integer); overload;
    procedure Stop(interval: integer); inline;
  end; { IntervalTimer }

var
  IntervalTimer: TIntervalTimer;

implementation

uses
  GpStuff,
  GpTime,
  GpLists,
  GpStringHash,
  DSiWin32,
  OtlSync;

type
  TGpTimingData = class
  strict private
    FCheckpoints  : TStringList;
    FInternalDelay: int64;
    FStarted      : boolean;
    FStartTime    : int64;
    FStopTime     : int64;
  public
    destructor  Destroy; override;
    procedure AddCheckpoint(const descr: string; time: int64);
    procedure AddInternalDelay(time: int64); inline;
    function  CheckpointDescr: string;
    function  Duration: int64;
    function  HasDuration: boolean; inline;
    procedure Start(time: int64);
    procedure Stop(time: int64);
    property InternalDelay: int64 read FInternalDelay;
    property IsStarted: boolean read FStarted;
    property StartTime: int64 read FStartTime;
    property StopTime: int64 read FStopTime;
  end; { TGpTimingData }

  TGpTiming = class
  strict private
    FLock      : TOmniCS;
    FTimingData: TGpStringObjectHash;
  strict protected
    function  Access(const name: string; canCreate: boolean = false): TGpTimingData;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure Checkpoint(const name, descr: string; time: int64);
    function  Description(const name: string): string;
    function  Start(const name: string): int64;
    function  Stop(const name: string; time: int64; timeLimit: cardinal = INFINITE;
      const errMsg: string = ''; logOnly: boolean = false): int64;
  end; { TGpTiming }

  TGpTimingPool = class
  strict private
    FPool    : TGpIntegerObjectList;
    FPoolLock: TOmniCS;
  strict protected
    function  GetGpTiming(threadID: cardinal): TGpTiming;
  public
    constructor Create;
    destructor  Destroy; override;
    property Timing[threadID: cardinal]: TGpTiming read GetGpTiming; default;
  end; { TGpTimingPool }

var
  GGpTiming: TGpTimingPool;

const
  FMaxCheckpoints = 20;

{ TGpTimingData }

destructor TGpTimingData.Destroy;
begin
  if assigned(FCheckpoints) then begin
    FCheckpoints.FreeObjects;
    FreeAndNil(FCheckpoints);
  end;
  inherited Destroy;
end; { TGpTimingData.Destroy }

procedure TGpTimingData.AddCheckpoint(const descr: string; time: int64);
begin
  if not assigned(FCheckpoints) then
    FCheckpoints := TStringList.Create;
  FCheckpoints.AddObject(descr, TGpInt64.Create(time - InternalDelay));
  if FCheckpoints.Count > FMaxCheckpoints then
    FCheckpoints.Delete(0);
end; { TGpTimingData.AddCheckpoint }

procedure TGpTimingData.AddInternalDelay(time: int64);
begin
  Inc(FInternalDelay, time);
end; { TGpTimingData.AddInternalDelay }

function TGpTimingData.CheckpointDescr: string;
var
  iCheckpoint: integer;
begin
  Result := '';
  if assigned(FCheckpoints) then
    for iCheckpoint := 0 to FCheckpoints.Count - 1 do begin
      if Result <> '' then
        Result := Result + ', ';
//      if IsStarted then
        Result := Result + Format('%s d%d',
          [FCheckpoints[iCheckpoint], TGpInt64(FCheckpoints.Objects[iCheckpoint]).Value - StartTime])
//      else
//        Result := Result + FCheckpoints[iCheckpoint];
    end;
end; { TGpTimingData.CheckpointDescr }

function TGpTimingData.Duration: int64;
begin
  Assert(StartTime > 0);
  Assert(StopTime > 0);
  Assert(not IsStarted);
  Result := StopTime - StartTime;
end; { TGpTimingData.Duration }

function TGpTimingData.HasDuration: boolean;
begin
  Result := (FStartTime > 0) and (FStopTime > 0);
end; { TGpTimingData.HasDuration }

procedure TGpTimingData.Stop(time: int64);
begin
  Assert(IsStarted);
  FStopTime := time;
  FStarted := false;
end; { TGpTimingData.Stop }

procedure TGpTimingData.Start(time: int64);
begin
  Assert(not IsStarted);
  FStartTime := time;
  FStopTime := 0;
  FStarted := true;
  if assigned(FCheckpoints) then
    FCheckpoints.Clear;
end; { TGpTimingData.Start }

{ TGpTiming }

constructor TGpTiming.Create;
begin
  inherited Create;
  FTimingData := TGpStringObjectHash.Create(100, true, true);
end; { TGpTiming.Create }

destructor TGpTiming.Destroy;
begin
  FreeAndNil(FTimingData);
  inherited Destroy;
end; { TGpTiming.Destroy }

function TGpTiming.Access(const name: string; canCreate: boolean): TGpTimingData;
var
  timingObj: TObject;
begin
  if not FTimingData.Find(name, timingObj) then begin
    if canCreate then begin
      timingObj := TGpTimingData.Create;
      FTimingData.Add(name, timingObj);
    end
    else
      raise Exception.CreateFmt('TGpTiming: No timing info for entity %s', [name]);
  end;
  Result := TGpTimingData(timingObj);
end; { TGpTiming.Access }

procedure TGpTiming.Checkpoint(const name, descr: string; time: int64);
var
  timingData: TGpTimingData;
begin
  FLock.Acquire;
  try
    timingData := Access(name, true);
    timingData.AddCheckpoint(descr, time);
    timingData.AddInternalDelay(Now64 - time);
  finally FLock.Release; end;
end; { TGpTiming.Checkpoint }

function TGpTiming.Description(const name: string): string;
var
  timingData: TGpTimingData;
begin
  FLock.Acquire;
  try
    timingData := Access(name);
    if timingData.IsStarted then
      Result := Format('Started, start time = %d (+%d), checkpoints = %s',
        [timingData.StartTime, Now64 - timingData.StartTime, timingData.CheckpointDescr])
    else if not timingData.HasDuration then
      Result := Format('Not started, checkpoints = %s', [timingData.CheckpointDescr])
    else
      Result := Format('Stopped, start time = %d (+%d), stop time = %d (+%d), duration = %d, checkpoints = %s',
        [timingData.StartTime, Now64 - timingData.StartTime,
         timingData.StopTime, Now64 - timingData.StopTime,
         timingData.Duration, timingData.CheckpointDescr]);
  finally FLock.Release; end;
end; { TGpTiming.Description }

function TGpTiming.Start(const name: string): int64;
var
  timingData: TGpTimingData;
begin
  FLock.Acquire;
  try
    timingData := Access(name, true);
    Result := Now64;
    timingData.Start(Result);
  finally FLock.Release; end;
end; { TGpTiming.Start }

function TGpTiming.Stop(const name: string; time: int64; timeLimit: cardinal;
  const errMsg: string; logOnly: boolean): int64;
var
  doLog       : boolean;
  sCheckpoints: string;
  timingData  : TGpTimingData;
begin
  sCheckpoints := '';
  doLog := false;
  FLock.Acquire;
  try
    timingData := Access(name);
    timingData.Stop(time);
    Result := timingData.Duration - timingData.InternalDelay;
    if (timeLimit <> INFINITE) and (Result >= timeLimit) then begin
      sCheckpoints := timingData.CheckpointDescr;
      doLog := true;
    end;
  finally FLock.Release; end;
  if doLog then begin
    if sCheckpoints <> '' then
      sCheckpoints := '; ' + sCheckpoints;
    if logOnly then
      OutputDebugString(PChar(Format('TGpTiming.Stop: Duration(%s) = %d > %d%s%s',
        [name, Result, timeLimit, sCheckpoints, IFF(errMsg <> '', '; ' + errMsg, '')])))
    else
      raise Exception.CreateFmt('TGpTiming.Stop: Duration(%s) = %d > %d%s%s',
        [name, Result, timeLimit, sCheckpoints, IFF(errMsg <> '', '; ' + errMsg, '')]);
  end;
end; { TGpTiming.Stop }

{ TGpTimingPool }

constructor TGpTimingPool.Create;
begin
  inherited Create;
  FPool := TGpIntegerObjectList.Create;
end; { TGpTimingPool.Create }

destructor TGpTimingPool.Destroy;
begin
  FreeAndNil(FPool);
  inherited;
end; { TGpTimingPool.Destroy }

function TGpTimingPool.GetGpTiming(threadID: cardinal): TGpTiming;
begin
  FPoolLock.Acquire;
  try
    Result := TGpTiming(FPool.FetchObject(integer(threadID)));
    if not assigned(Result) then begin
      Result := TGpTiming.Create;
      FPool.AddObject(integer(threadID), Result);
    end;
  finally FPoolLock.Release; end;
end; { TGpTimingPool.GetGpTiming }

{ Profile }

class procedure Profile.Checkpoint(const name: string; id: integer);
var
  time: int64;
begin
  time := Now64;
  GGpTiming[GetCurrentThreadID].Checkpoint(name, '#' + IntToStr(id), time);
end; { Profile.Checkpoint }

class procedure Profile.Checkpoint(const name: string; const descr: string);
var
  time: int64;
begin
  time := Now64;
  GGpTiming[GetCurrentThreadID].Checkpoint(name, descr, time);
end; { Profile.Checkpoint }

class function Profile.DebugStart(const name: string): int64;
begin
  {$IFDEF DEBUG}
  Result := Start(name);
  {$ELSE}
  Result := 0;
  {$ENDIF DEBUG}
end; { Profile.DebugStart }

class function Profile.DebugStop(const name: string; timeLimit: cardinal;
  const errMsg: string; logOnly: boolean): int64;
begin
  {$IFDEF DEBUG}
  Result := Stop(name, timeLimit, errMsg, logOnly);
  {$ELSE}
  Result := 0;
  {$ENDIF DEBUG}
end; { Profile.DebugStop }

class function Profile.Description(threadID: cardinal; const name: string): string;
begin
  Result := GGpTiming[threadID].Description(name);
end; { Profile.Description }

class function Profile.Start(const name: string): int64;
begin
  Result := GGpTiming[GetCurrentThreadID].Start(name);
end; { Profile.Start }

class function Profile.Stop(const name: string; timeLimit: cardinal;
  const errMsg: string; logOnly: boolean): int64;
var
  time: int64;
begin
  time := Now64;
  Result := GGpTiming[GetCurrentThreadID].Stop(name, time, timeLimit, errMsg, logOnly);
end; { Profile.Stop }

{ TIntervalTimer }

procedure TIntervalTimer.Initialize(useMicroseconds: boolean);
var
  i: integer;
begin
  FillChar(FCount, SizeOf(FCount), 0);
  FillChar(FDuration, SizeOf(FDuration), 0);
  FillChar(FStart, SizeOf(FStart), 0);
  FillChar(FMax, SizeOf(FMax), 0);
  for i := Low(FMin) to High(FMin) do
    FMin[i] := $7FFFFFFFFFFFFFFF;
  FHigh := 0;
  FLog.Clear;
  FMicroSec := useMicroseconds;
  if FMicroSec then begin
    FUnits := 'us';
    FNow := DSiQueryPerfCounterAsUS;
  end
  else begin
    FUnits := 'ms';
    FNow := Now64;
  end;
end; { TIntervalTimer.Initialize }

procedure TIntervalTimer.Log(const msg: string);
begin
  FLog.Add(msg);
end; { TIntervalTimer.Log }

procedure TIntervalTimer.Log(const msg: string; const params: array of const);
begin
  Log(Format(msg, params));
end; { TIntervalTimer.Log }

function TIntervalTimer.Report(showCounters, showNonzeroOnly: boolean;
  reportOnlyTimers: TArray<integer>): string;
var
  i: integer;

  function IsReportedTimer(timer: integer): boolean;
  var
    i: integer;
  begin
    Result := false;

    for i := Low(reportOnlyTimers) to High(reportOnlyTimers) do
      if reportOnlyTimers[i] = timer then
        Exit(true);
  end; { IsReportedTimer }

begin
  Result := '';
  for i := 1 to FHigh do begin
    if ((FDuration[i] > 0) or (not showNonzeroOnly))
       and
       ((reportOnlyTimers = nil) or IsReportedTimer(i))
    then begin
      if Result <> '' then
        Result := Result + ', ';
      Result := Result + Format('[%d] %d %s', [i, FDuration[i], FUnits]);
      if showCounters and (FCount[i] > 0) then
        Result := Result + Format(' (%dx, avg = %.1f %s, min = %d %s, max = %d %s)',
          [FCount[i], FDuration[i]/FCount[i], FUnits, FMin[i], FUnits, FMax[i], FUnits]);
    end;
  end;
  if FLog.Count > 0 then begin
    FLog.Delimiter := ';';
    Result := Result + '; ' + FLog.DelimitedText;
  end;
end; { TIntervalTimer.Report }

procedure TIntervalTimer.Restart(interval: integer);
begin
  FDuration[interval] := 0;
  FCount[interval] := 0;
  FMin[interval] := $7FFFFFFFFFFFFFFF;
  FMax[interval] := 0;
  FStart[interval] := FNow();
end; { TIntervalTimer.Restart }

procedure TIntervalTimer.Start(interval: integer);
begin
  FStart[interval] := FNow();
end; { TIntervalTimer.Start }

procedure TIntervalTimer.Start(const intervals: array of integer);
var
  i   : integer;
  time: int64;
begin
  time := FNow();
  for i in intervals do
    FStart[i] := time;
end; { TIntervalTimer.Start }

procedure TIntervalTimer.Stop(interval: integer);
var
  this: int64;
begin
  this := FNow() - FStart[interval];
  FDuration[interval] := FDuration[interval] + this;
  Inc(FCount[interval]);
  if this < FMin[interval] then
    FMin[interval] := this;
  if this > FMax[interval] then
    FMax[interval] := this;
  if interval > FHigh then
    FHigh := interval;
end; { TIntervalTimer.Stop }

initialization
  GGpTiming := TGpTimingPool.Create;
  IntervalTimer := TIntervalTimer.Create;
finalization
  FreeAndNil(GGpTiming);
  FreeAndNil(IntervalTimer);
end.
