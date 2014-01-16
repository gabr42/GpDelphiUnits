(*:A simple form with some enhancements.
   @author Primoz Gabrijelcic
   @desc <pre>
   (c) 2014 Primoz Gabrijelcic
   Free for personal and commercial use. No rights reserved.

   Author            : Primoz Gabrijelcic
   Creation date     : 2004-06-21
   Last modification : 2014-01-15
   Version           : 1.07
</pre>*)(*
   History:
     1.07: 2014-01-15
       - Uses GpAutoCreate to manage internal fields.
     1.06a: 2009-10-20
       - Correctly log multiline messages.
     1.06: 2008-07-17
       - Added AutoApplicationProcessMessages property. Setting it to True forces each
         Log operation to call Application.ProcessMessages.
     1.05b: 2008-07-02
       - Don't log messages if form is being destroyed.
     1.05a: 2007-10-26
       - Don't automatically hook listbox on startup if listbox was already assigned.
     1.05: 2007-07-25
       - Added two Log overloads for logging into non-default listbox.
     1.04: 2007-03-21
       - Automatically enable double-buffering for the log listbox.
       - Added property AutoSelectLastLogItem.
     1.03a: 2007-03-09
       - Fixed initialization order.
     1.03: 2007-02-23
       - Automatically virtualize logging listbox.
     1.02: 2006-07-18
       - Automatically locate logging listbox during creation.
     1.01: 2004-07-16
       - Added DoPostCreate protected virtual method and OnPostCreate published event.
     1.0: 2004-06-21
       - Released.
*)
                           
unit GpForm;

interface

uses
  Messages,
  Classes,
  Controls,
  StdCtrls,
  Forms;

type
  TStringsAccessor = class(TStringList);

  TGpForm = class(TForm)
  private
    gfAutoAPM              : boolean;
    gfAutoSelectLastLogItem: boolean;
    gfLog                  : TListBox;
    gfLogData              : TStringList;
    gfOnPostCreate         : TNotifyEvent;
    gfSavedLogData         : TLBGetDataEvent;
    gfSavedLogDataFind     : TLBFindDataEvent;
    gfSavedLogDataObject   : TLBGetDataObjectEvent;
    gfSavedLogDoubleBuf    : boolean;
    gfSavedLogStyle        : TListBoxStyle;
  protected
    procedure DoCreate; override;
    procedure DoDestroy; override;
    procedure DoPostCreate; virtual;
    procedure FindLog;
    function  FindLogData(control: TWinControl; findString: string): integer;
    procedure GetLogObject(control: TWinControl; index: integer; var dataObject: TObject);
    procedure ProvideLogData(control: TWinControl; index: integer; var data: string);
    procedure SetLogListbox(const value: TListBox);
    procedure WndProc(var Message: TMessage); override;
  public
    procedure BeginLogUpdate;
    procedure ClearLog;
    procedure EndLogUpdate;
    procedure Log(const msg: string); overload; virtual;
    procedure Log(const msg: string; params: array of const); overload;
    procedure Log(listBox: TListBox; const msg: string); overload; virtual;
    procedure Log(listBox: TListBox; const msg: string; params: array of const); overload;
    procedure LogA(const msg: AnsiString); overload; virtual;
    procedure LogA(const msg: AnsiString; params: array of const); overload;
    function  LogUpdateCount: integer;
    property LogData: TStringList read gfLogData;
  published
    property AutoApplicationProcessMessages: boolean read gfAutoAPM
      write gfAutoAPM;
    property AutoSelectLastLogItem: boolean read gfAutoSelectLastLogItem write
      gfAutoSelectLastLogItem;
    property LogListbox: TListBox read gfLog write SetLogListbox;
    property OnPostCreate: TNotifyEvent read gfOnPostCreate write gfOnPostCreate;
  end; { TGpForm }

implementation

uses
  Windows,
  SysUtils,
  GpAutoCreate;

var
  GMsgPostCreate: cardinal;

{ TGpForm }

procedure TGpForm.BeginLogUpdate;
begin
  gfLogData.BeginUpdate;
end; { TGpForm.BeginLogUpdate }

procedure TGpForm.ClearLog;
begin
  gfLogData.Clear;
  if assigned(gfLog) and (LogUpdateCount = 0) then
    gfLog.Count := 0;
end; { TGpForm.ClearLog }

procedure TGpForm.DoCreate;
begin
  gfLogData := TStringList.Create;
  inherited;
  TGpManaged.CreateManagedChildren(Self);
  PostMessage(Handle, GMsgPostCreate, 0, 0);
end; { TGpForm.DoCreate }

procedure TGpForm.DoDestroy;
begin
  TGpManaged.DestroyManagedChildren(Self);
  FreeAndNil(gfLogData);
  inherited;
end; { TGpForm.DoDestroy }

procedure TGpForm.DoPostCreate;
begin
  if assigned(gfOnPostCreate) then
    gfOnPostCreate(Self);
end; { TGpForm.DoPostCreate }

procedure TGpForm.EndLogUpdate;
begin
  gfLogData.EndUpdate;
  if LogUpdateCount = 0 then
    gfLog.Count := gfLogData.Count;
end; { TGpForm.EndLogUpdate }

procedure TGpForm.FindLog;
var
  iControl: integer;
begin
  for iControl := 0 to ControlCount - 1 do
    if Controls[iControl] is TListBox then begin
      LogListbox := TListBox(Controls[iControl]);
      break; //for iControl;
    end;
end; { TGpForm.FindLog }

function TGpForm.FindLogData(control: TWinControl; findString: string): integer;
begin
  Result := gfLogData.IndexOf(findString);
end; { TGpForm.FindLogData }

procedure TGpForm.GetLogObject(control: TWinControl; index: integer;
  var dataObject: TObject);
begin
  dataObject := gfLogData.Objects[index];
end; { TGpForm.GetLogObject }

procedure TGpForm.Log(const msg: string);
var
  idxLog: integer;
  sMsg  : TStringList;
begin
  if csDestroying in ComponentState then
    Exit;
  if Pos(#13#10, msg) <= 0 then
    idxLog := gfLogData.Add(msg)
  else begin
    sMsg := TStringList.Create;
    try
      sMsg.Text := msg;
      gfLogData.AddStrings(sMsg);
      idxLog := gfLogData.Count - 1;
    finally FreeAndNil(sMsg); end;
  end;
  if assigned(gfLog) and (LogUpdateCount = 0) then
    gfLog.Count := gfLogData.Count;
  if AutoSelectLastLogItem then
    gfLog.ItemIndex := idxLog;
  if AutoApplicationProcessMessages then
    Application.ProcessMessages;
end; { TGpForm.Log }

procedure TGpForm.Log(const msg: string; params: array of const);
begin
  Log(Format(msg, params));
end; { TGpForm.Log }

procedure TGpForm.Log(listBox: TListBox; const msg: string);
var
  idxLog: integer;
begin
  idxLog := listBox.Items.Add(msg);
  if AutoSelectLastLogItem then
    listBox.ItemIndex := idxLog;
end; { TGpForm.Log }

procedure TGpForm.Log(listBox: TListBox; const msg: string; params: array of const);
begin
  Log(listBox, Format(msg, params));
end; { TGpForm.Log }

procedure TGpForm.LogA(const msg: AnsiString);
begin
  Log(string(msg));
end; { TGpForm.LogA }

procedure TGpForm.LogA(const msg: AnsiString; params: array of const);
begin
  Log(string(msg), params);
end; { TGpForm.LogA }

function TGpForm.LogUpdateCount: integer;
begin
  Result := TStringsAccessor(gfLogData).UpdateCount;
end; { TGpForm.LogUpdateCount }

procedure TGpForm.ProvideLogData(control: TWinControl; index: integer; var data: string);
begin
  data := gfLogData[index];
end; { TGpForm.ProvideLogData }

procedure TGpForm.SetLogListbox(const value: TListBox);
begin
  if assigned(gfLog) then begin
    gfLog.Style := gfSavedLogStyle;
    gfLog.DoubleBuffered := gfSavedLogDoubleBuf;
  end;
  gfLog := value;
  gfSavedLogStyle := gfLog.Style;
  gfSavedLogDoubleBuf := gfLog.DoubleBuffered;
  gfSavedLogData := gfLog.OnData;
  gfSavedLogDataFind := gfLog.OnDataFind;
  gfLog.Style := lbVirtual;
  gfLog.DoubleBuffered := true;
  gfSavedLogDataObject := gfLog.OnDataObject;
  gfLog.OnData := ProvideLogData;
  gfLog.OnDataFind := FindLogData;
  gfLog.OnDataObject := GetLogObject;
  gfLog.Count := gfLogData.Count;
end; { TGpForm.SetLogListbox }

procedure TGpForm.WndProc(var Message: TMessage);
begin
  if Message.Msg = GMsgPostCreate then begin
    if not assigned(gfLog) then
      FindLog;
    DoPostCreate;
  end
  else
    inherited;
end; { TGpForm.WndProc }

initialization
  GMsgPostCreate := RegisterWindowMessage('42C52D65-4B69-4714-8C59-0B37F29FEB35');
end.
