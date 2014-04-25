///<summary>Queue anonymous procedure to a hidden window executing in a main thread.
///</summary>
///<author>Primoz Gabrijelcic</author>
///<remarks><para>
///   (c) 2013 Primoz Gabrijelcic
///   Free for personal and commercial use. No rights reserved.
///
///   Author            : Primoz Gabrijelcic
///   Creation date     : 2013-07-18
///   Last modification : 2013-07-18
///   Version           : 1.0
///</para><para>
///   History:
///     1.0: 2013-07-18
///       - Created.
///</para></remarks>

unit GpQueueExec;

interface

uses
  SysUtils;

  procedure Queue(proc: TProc);

implementation

uses
  Windows,
  Messages,
  DSiWin32;

const
  WM_EXECUTE = WM_USER;

type
  TQueueProc = class
    Proc: TProc;
  end;

  TQueueExec = class
  strict private
    FHWindow: HWND;
  strict protected
    procedure WndProc(var Message: TMessage);
  public
    constructor Create;
    destructor  Destroy; override;
    procedure Queue(proc: TProc);
  end;

{ TQueueExec }

constructor TQueueExec.Create;
begin
  inherited Create;
  FHWindow := DSiAllocateHWnd(WndProc);
end; { TQueueExec.Create }

destructor TQueueExec.Destroy;
begin
  DSiDeallocateHWnd(FHWindow);
  inherited;
end; { TQueueExec.Destroy }

procedure TQueueExec.Queue(proc: TProc);
var
  procObj: TQueueProc;
begin
  procObj := TQueueProc.Create;
  procObj.Proc := proc;
  PostMessage(FHWindow, WM_EXECUTE, WParam(procObj), 0);
end;

procedure TQueueExec.WndProc(var Message: TMessage);
var
  procObj: TQueueProc;
begin
  if Message.Msg = WM_EXECUTE then begin
    procObj := TQueueProc(Message.WParam);
    procObj.Proc();
    procObj.Free;
  end
  else
    Message.Result := DefWindowProc(FHWindow, Message.Msg, Message.WParam, Message.LParam);
end;

var
  FQueueExec: TQueueExec;

procedure Queue(proc: TProc);
begin
  FQueueExec.Queue(proc);
end;

initialization
  FQueueExec := TQueueExec.Create;
finalization
  FreeAndNil(FQueueExec);
end.
