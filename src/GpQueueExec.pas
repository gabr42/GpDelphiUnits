///<summary>Queue anonymous procedure to a hidden window executing in a main thread.
///</summary>
///<author>Primoz Gabrijelcic</author>
///<remarks><para>
///   (c) 2014 Primoz Gabrijelcic
///   Free for personal and commercial use. No rights reserved.
///
///   Author            : Primoz Gabrijelcic
///   Creation date     : 2013-07-18
///   Last modification : 2014-08-26
///   Version           : 1.01
///</para><para>
///   History:
///     1.01: 2014-08-26
///       - Implemented After function.
///     1.0: 2013-07-18
///       - Created.
///</para></remarks>

unit GpQueueExec;

interface

uses
  SysUtils;

  procedure After(timeout_ms: integer; proc: TProc);
  procedure Queue(proc: TProc);

implementation

uses
  Windows,
  Messages,
  Generics.Collections,
  DSiWin32;

const
  WM_EXECUTE = WM_USER;

type
  TQueueProc = class
    Proc: TProc;
  end;

  TQueueExec = class
  strict private type
    TTimerData = TPair<NativeUInt, TProc>;
  strict private
    FHWindow  : HWND;
    FTimerID  : NativeUInt;
    FTimerData: TList<TTimerData>;
  strict protected
    procedure WndProc(var Message: TMessage);
  protected
    function FindTimer(timerID: NativeUInt): integer;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure After(timeout_ms: integer; proc: TProc);
    procedure Queue(proc: TProc);
  end;

{ TQueueExec }

constructor TQueueExec.Create;
begin
  inherited Create;
  FTimerData := TList<TTimerData>.Create;
  FHWindow := DSiAllocateHWnd(WndProc);
end; { TQueueExec.Create }

destructor TQueueExec.Destroy;
var
  kv: TTimerData;
begin
  for kv in FTimerData do
    KillTimer(FHWindow, kv.Key);
  DSiDeallocateHWnd(FHWindow);
  FreeAndNil(FTimerData);
  inherited;
end; { TQueueExec.Destroy }

procedure TQueueExec.After(timeout_ms: integer; proc: TProc);
begin
  Inc(FTimerID);
  FTimerData.Add(TTimerData.Create(FTimerID , proc));
  SetTimer(FHWindow, FTimerID, timeout_ms, nil);
end; { TQueueExec.After }

function TQueueExec.FindTimer(timerID: NativeUInt): integer;
begin
  for Result := 0 to FTimerData.Count - 1 do
    if FTimerData[Result].Key = timerID then
      Exit;

  Result := -1;
end; { TQueueExec.FindTimer }

procedure TQueueExec.Queue(proc: TProc);
var
  procObj: TQueueProc;
begin
  procObj := TQueueProc.Create;
  procObj.Proc := proc;
  PostMessage(FHWindow, WM_EXECUTE, WParam(procObj), 0);
end; { TQueueExec.Queue }

procedure TQueueExec.WndProc(var Message: TMessage);
var
  idx    : integer;
  procObj: TQueueProc;
begin
  if Message.Msg = WM_EXECUTE then begin
    procObj := TQueueProc(Message.WParam);
    procObj.Proc();
    procObj.Free;
  end
  else if Message.Msg = WM_TIMER then begin
    idx := FindTimer(TWMTimer(Message).TimerID);
    if idx >= 0 then begin
      KillTimer(FHWindow, FTimerData[idx].Key);
      FTimerData[idx].Value();
      FTimerData.Delete(idx);
    end;
  end
  else
    Message.Result := DefWindowProc(FHWindow, Message.Msg, Message.WParam, Message.LParam);
end; { TQueueExec.WndProc }

var
  FQueueExec: TQueueExec;

procedure Queue(proc: TProc);
begin
  FQueueExec.Queue(proc);
end;

procedure After(timeout_ms: integer; proc: TProc);
begin
  FQueueExec.After(timeout_ms, proc);
end;

initialization
  FQueueExec := TQueueExec.Create;
finalization
  FreeAndNil(FQueueExec);
end.
