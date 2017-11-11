unit GpEasing;

// Easing functions: http://www.timotheegroleau.com/Flash/experiments/easing_function_generator.htm
// Robert Penner, Tweening: http://robertpenner.com/easing/penner_chapter7_tweening.pdf

interface

uses
  System.SysUtils;

type
  IEasing = interface ['{97B451B6-FBAB-45DE-9979-7A740CDC3AFA}']
    procedure Complete;
  end; { IEasing }

  Easing = class
    class function InOutCubic(start, stop: integer; duration_ms, tick_ms: integer;
      updater: TProc<integer>): IEasing; static;
    class function InOutQuintic(start, stop: integer; duration_ms, tick_ms: integer;
      updater: TProc<integer>): IEasing; static;
    class function Linear(start, stop: integer; duration_ms, tick_ms: integer;
      updater: TProc<integer>): IEasing; static;
  end; { Easing }

implementation

uses
  Vcl.ExtCtrls,
  DSiWin32;

type
  TEasing = class(TInterfacedObject, IEasing)
  strict private
    FDuration_ms: integer;
    FEasingFunc : TFunc<integer, integer>;
    FStartValue : integer;
    FStopValue  : integer;
    FStart_ms   : int64;
    FTick_ms    : integer;
    FTimer      : TTimer;
    FUpdater    : TProc<integer>;
    FValueDiff  : integer;
  strict protected
    function  InOutCubicEasing(delta_ms: integer): integer;
    function  InOutQuinticEasing(delta_ms: integer): integer;
    function  LinearEasing(delta_ms: integer): integer;
    procedure StartTimer;
    procedure UpdateValue(sender: TObject);
  public
    destructor Destroy; override;
    procedure Complete;
    procedure InOutCubic;
    procedure InOutQuintic;
    procedure Linear;
    property Duration_ms: integer read FDuration_ms write FDuration_ms;
    property StartValue: integer read FStartValue write FStartValue;
    property StopValue: integer read FStopValue write FStopValue;
    property Tick_ms: integer read FTick_ms write FTick_ms;
    property Updater: TProc<integer> read FUpdater write FUpdater;
  end; { TEasing }

{ Easing }

function CreateEasing(start, stop, duration_ms, tick_ms: integer;
  updater: TProc<integer>): IEasing;
var
  easing: TEasing;
begin
  Result := TEasing.Create;
  easing := TEasing(Result);
  easing.StartValue := start;
  easing.StopValue := stop;
  easing.Duration_ms := duration_ms;
  easing.Tick_ms := tick_ms;
  easing.Updater := updater;
end; { CreateEasing }

class function Easing.InOutCubic(start, stop: integer; duration_ms, tick_ms: integer;
  updater: TProc<integer>): IEasing;
begin
  Result := CreateEasing(start, stop, duration_ms, tick_ms, updater);
  TEasing(Result).InOutCubic;
end; { Easing.InOutCubic }

class function Easing.InOutQuintic(start, stop: integer; duration_ms, tick_ms: integer;
  updater: TProc<integer>): IEasing;
begin
  Result := CreateEasing(start, stop, duration_ms, tick_ms, updater);
  TEasing(Result).InOutQuintic;
end;

class function Easing.Linear(start, stop, duration_ms, tick_ms: integer;
  updater: TProc<integer>): IEasing;
begin
  Result := CreateEasing(start, stop, duration_ms, tick_ms, updater);
  TEasing(Result).Linear;
end; { Easing }

{ TEasing }

destructor TEasing.Destroy;
begin
  FreeAndNil(FTimer);
  inherited;
end; { TEasing }

procedure TEasing.Complete;
begin
  updater(StopValue);
  FTimer := nil;
end; { TEasing.Complete }

procedure TEasing.InOutCubic;
begin
  FEasingFunc := InOutCubicEasing;
  StartTimer;
end; { TEasing.InOutCubic }

function TEasing.InOutCubicEasing(delta_ms: integer): integer;
var
  t : real;
  ts: real;
begin
  t := delta_ms/Duration_ms;
  ts := t*t;
  Result := FStartValue + Round(FValueDiff * (-2 * ts * t + 3 * ts));
end; { TEasing.InOutCubicEasing }

procedure TEasing.InOutQuintic;
begin
  FEasingFunc := InOutQuinticEasing;
  StartTimer;
end; { TEasing.InOutQuintic }

function TEasing.InOutQuinticEasing(delta_ms: integer): integer;
var
  t: real;
begin
  t := delta_ms/Duration_ms;
  Result := FStartValue + Round(FValueDiff * t * t * t * t);
end;

procedure TEasing.Linear;
begin
  FEasingFunc := LinearEasing;
  StartTimer;
end; { TEasing.Linear }

function TEasing.LinearEasing(delta_ms: integer): integer;
begin
  Result := FStartValue + Round(FValueDiff / Duration_ms * delta_ms);
end; { TEasing.LinearEasing }

procedure TEasing.StartTimer;
begin
  FValueDiff := FStopValue - FStartValue;
  FTimer := TTimer.Create(nil);
  FTimer.Interval := Tick_ms;
  FTimer.OnTimer := UpdateValue;
  FStart_ms := DSiTimeGetTime64;
end; { TEasing.StartTimer }

procedure TEasing.UpdateValue(sender: TObject);
var
  delta_ms: int64;
  newValue: integer;
begin
  delta_ms := DSiElapsedTime64(FStart_ms);

  if delta_ms >= Duration_ms then
    newValue := StopValue
  else
    newValue := FEasingFunc(delta_ms);

  updater(newValue);

  if newValue = StopValue then
    FTimer.Enabled := false;
end; { TEasing.UpdateValue }

end.
