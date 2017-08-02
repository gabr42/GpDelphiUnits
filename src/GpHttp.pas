///<summary>Synchronous GET/POST using ICS and OmniThreadLibrary.///</summary>
///<author>Primoz Gabrijelcic</author>
///<remarks><para>
///   (c) 2017 Primoz Gabrijelcic
///   Free for personal and commercial use. No rights reserved.
///
///   Author            : Primoz Gabrijelcic
///   Creation date     : 2008-06-29
///   Last modification : 2017-01-19
///   Version           : 1.05
///</para><para>
///   History:
///     1.05: 2017-01-19
///       - Both http calls return False on socket error.
///     1.04b: 2015-10-16
///       - Fixed memory leak in GpHttpRequest.
///     1.04a: 2015-08-20
///       - GpHttpGet/GpHttpPost work if `extraHeader` parameter is not used.
///     1.04: 2015-07-27
///       - Added `extraHeaders` parameter to GpHttpGet and GpHttpPost.
///     1.03: 2015-07-24
///       - Added `terminateEvent` parameter to GpHttpGet and GpHttpPost.
///     1.02: 2015-07-23
///       - Added `timeout` parameter to GpHttpGet and GpHttpPost.
///       - Fixed Unicode issues.
///     1.01: 2008-08-29
///       - Fixed to work with OmniThreadLibrary 1.0.
///       - Simplified.
///</para></remarks>

unit GpHttp;

interface

uses
  Classes;

function GpHttpGet(const url, username, password: string; var statusCode: integer; var
  statusText: string; var pageContents: RawByteString; timeout_sec: integer = 30;
  terminateEvent: THandle = 0; extraHeaders: TStrings = nil): boolean;

function GpHttpPost(const url, username, password: string; const postData: RawByteString;
  var statusCode: integer; var statusText: string; var pageContents: RawByteString;
  timeout_sec: integer = 30; terminateEvent: THandle = 0; extraHeaders: TStrings = nil): boolean;

implementation

uses
  Windows,
  SysUtils,
  StrUtils,
  GpString,
  GpStreams,
  OtlTask,
  OtlTaskControl,
  OverbyteIcsWSocket,
  OverbyteIcsHttpProt;

type
  TGpHttpRequest = class(TOmniWorker)
  strict private
    hrConnected   : boolean;
    hrExtraHeaders: TStringList;
    hrHttpClient  : THttpCli;
    hrPageContents: RawByteString;
    hrPassword    : string;
    hrPostData    : RawByteString;
    hrRequest     : string;
    hrStatusCode  : integer;
    hrStatusText  : string;
    hrURL         : string;
    hrUsername    : string;
  strict protected
    procedure HandleRequestDone(sender: TObject; rqType: THttpRequest; error: word);
    procedure HandleBeforeHeaderSend(sender: TObject; const method: string; headers:
      TStrings);
  public
    constructor Create(const url, username, password, request: string; const postData:
      RawByteString; extraHeaders: TStrings);
    destructor  Destroy; override;
    procedure Cleanup; override;
    function  Initialize: boolean; override;
    property Connected: boolean read hrConnected;
    property PageContents: RawByteString read hrPageContents;
    property Password: string read hrPassword;
    property PostData: RawByteString read hrPostData;
    property Request: string read hrRequest;
    property StatusCode: integer read hrStatusCode;
    property StatusText: string read hrStatusText;
    property URL: string read hrURL;
    property Username: string read hrUsername;
  end; { TGpHttpRequest }

{ globals }

function GpHttpRequest(const url, username, password, request: string; const postData:
  RawByteString; var statusCode: integer; var statusText: string; var pageContents:
  RawByteString; timeout_sec: integer; terminateEvent: THandle; extraHeaders: TStrings): boolean;
var
  task  : IOmniTaskControl;
  worker: IOmniWorker;
begin
  worker := TGpHttpRequest.Create(url, username, password, request, postData, extraHeaders);
  task := CreateTask(worker, 'GpHttpRequest').MsgWait.Run;
  try
    if terminateEvent <> 0 then
      task.TerminateWhen(terminateEvent);
    Result := task.WaitFor(timeout_sec * 1000);
    Result := Result and TGpHttpRequest(worker.Implementor).Connected;
    if Result then begin
      statusCode := TGpHttpRequest(worker.Implementor).StatusCode;
      statusText := TGpHttpRequest(worker.Implementor).StatusText;
      pageContents := TGpHttpRequest(worker.Implementor).PageContents;
    end;
  finally task.Terminate; end;
end; { GpHttpRequest }

{ exports }

function GpHttpGet(const url, username, password: string; var statusCode: integer; var
  statusText: string; var pageContents: RawByteString; timeout_sec: integer;
  terminateEvent: THandle; extraHeaders: TStrings): boolean;
begin
  Result := GpHttpRequest(url, username, password, 'GET', '',
              statusCode, statusText, pageContents, timeout_sec, terminateEvent,
              extraHeaders);
end; { GpHttpGet }

function GpHttpPost(const url, username, password: string; const postData: RawByteString;
  var statusCode: integer; var statusText: string; var pageContents: RawByteString;
  timeout_sec: integer; terminateEvent: THandle; extraHeaders: TStrings): boolean;
begin
  Result := GpHttpRequest(url, username, password, 'POST', postData,
              statusCode, statusText, pageContents, timeout_sec, terminateEvent,
              extraHeaders);
end; { GpHttpPost }

{ TGpHttpRequest }

constructor TGpHttpRequest.Create(const url, username, password, request: string; const
  postData: RawByteString; extraHeaders: TStrings);
begin
  inherited Create;
  hrURL := url;
  hrUsername := username;
  hrPassword := password;
  hrPostData := postData;
  hrRequest := request;
  hrExtraHeaders := TStringList.Create;
  if assigned(extraHeaders) then
    hrExtraHeaders.Assign(extraHeaders);
end; { TGpHttpRequest.Create }

destructor TGpHttpRequest.Destroy;
begin
  FreeAndNil(hrExtraHeaders);
  inherited;
end; { TGpHttpRequest.Destroy }

procedure TGpHttpRequest.Cleanup;
begin
  if assigned(hrHttpClient) then begin
    hrHttpClient.RcvdStream.Free;
    hrHttpClient.SendStream.Free;
    FreeAndNil(hrHttpClient);
  end;
end; { TGpHttpRequest.Cleanup }

procedure TGpHttpRequest.HandleBeforeHeaderSend(sender: TObject; const method: string;
  headers: TStrings);
var
  added: boolean;
  hdr  : string;
  i    : integer;
  key  : string;
begin
  for hdr in hrExtraHeaders do begin
    added := false;
    key := FirstEl(hdr, ':', -1) + ':';
    for i := 0 to headers.Count - 1 do begin
      if StartsText(key, headers[i]) then begin
        added := true;
        headers[i] := hdr;
        break; //for i
      end;
    end; //for i
    if not added then
      headers.Add(hdr);
  end; //for hdr
end; { TGpHttpRequest.HandleBeforeHeaderSend }

procedure TGpHttpRequest.HandleRequestDone(sender: TObject; rqType: THttpRequest; error:
  word);
begin
  if error <> 0 then begin
    hrStatusCode := error;
    hrStatusText := 'Socket error';
    hrConnected := false;
  end
  else begin
    hrPageContents := hrHttpClient.RcvdStream.AsAnsiString;
    hrStatusCode := hrHttpClient.StatusCode;
    hrStatusText := hrHttpClient.ReasonPhrase;
    hrConnected := true;
  end;
  Task.Terminate;
end; { TGpHttpRequest.HandleRequestDone }

function TGpHttpRequest.Initialize: boolean;
begin
  hrHttpClient := THttpCli.Create(nil);
  try
    hrHttpClient.NoCache := true;
    hrHttpClient.RequestVer := '1.1';
    hrHttpClient.URL := hrURL;
    hrHttpClient.Username := hrUsername;
    hrHttpClient.Password := hrPassword;
    hrHttpClient.FollowRelocation := true;
    if hrUsername <> '' then
      hrHttpClient.ServerAuth := httpAuthBasic;
    hrHttpClient.SendStream := TMemoryStream.Create;
    hrHttpClient.SendStream.AsAnsiString := hrPostData;
    hrHttpClient.RcvdStream := TMemoryStream.Create;
    hrHttpClient.OnBeforeHeaderSend := HandleBeforeHeaderSend;
    hrHttpClient.OnRequestDone := HandleRequestDone;
    if SameText(hrRequest, 'GET') then
      hrHttpClient.GetASync
    else if SameText(hrRequest, 'POST') then
      hrHttpClient.PostASync
    else
      raise Exception.CreateFmt('TGpHttpRequest.Initialize: Unknown request type %s', [hrRequest]);
    Result := true;
  except
    on E:ESocketException do begin
      hrStatusCode := -1;
      hrStatusText := E.Message;
      Result := false;
    end;
  end;
end; { TGpHttpRequest.Initialize }

end.
