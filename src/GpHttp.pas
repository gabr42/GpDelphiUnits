///<summary>Short description<para>
///Optional longer description</para>
///</summary>
///<author>Primoz Gabrijelcic</author>
///<remarks><para>
///   (c) 2008 Primoz Gabrijelcic
///   Free for personal and commercial use. No rights reserved.
///
///   Author            : Primoz Gabrijelcic
///   Creation date     : 2008-06-29
///   Last modification : 2008-08-29
///   Version           : 1.01
///</para><para>
///   History:
///     1.01: 2008-08-29
///       - Fixed to work with OmniThreadLibrary 1.0.
///       - Simplified.
///</para></remarks>

unit GpHttp;

interface

function GpHttpGet(const url, username, password: string; var statusCode: integer; var
  statusText, pageContents: string): boolean;

function GpHttpPost(const url, username, password, postData: string; var statusCode:
  integer; var statusText, pageContents: string): boolean;

implementation

uses
  Windows,
  SysUtils,
  Classes,
  OtlTask,
  OtlTaskControl,
  OverbyteIcsWSocket,
  OverbyteIcsHttpProt;

const
  CGpHttpRequestTimeout_sec = 30; 

type
  TGpHttpRequest = class(TOmniWorker)
  strict private
    hrHttpClient  : THttpCli;
    hrPageContents: string;
    hrPassword    : string;
    hrPostData    : string;
    hrRequest     : string;
    hrStatusCode  : integer;
    hrStatusText  : string;
    hrURL         : string;
    hrUsername    : string;
  strict protected
    procedure HandleRequestDone(sender: TObject; rqType: THttpRequest; error: word);
  public
    constructor Create(const url, username, password, request, postData: string);
    procedure Cleanup; override;
    function  Initialize: boolean; override;
    property PageContents: string read hrPageContents;
    property Password: string read hrPassword;
    property PostData: string read hrPostData;
    property Request: string read hrRequest;
    property StatusCode: integer read hrStatusCode;
    property StatusText: string read hrStatusText;
    property URL: string read hrURL;
    property Username: string read hrUsername;
  end; { TGpHttpRequest }

{ globals }

function GpHttpRequest(const url, username, password, request, postData: string; var
  statusCode: integer; var statusText, pageContents: string): boolean;
var
  task  : IOmniTaskControl;
  worker: IOmniWorker;
begin
  worker := TGpHttpRequest.Create(url, username, password, request, postData);
  task := CreateTask(worker, 'GpHttpRequest').MsgWait.Run;
  Result := task.WaitFor(CGpHttpRequestTimeout_sec * 1000);
  if not Result then
    task.Terminate
  else begin
    statusCode := TGpHttpRequest(worker.Implementor).StatusCode;
    statusText := TGpHttpRequest(worker.Implementor).StatusText;
    pageContents := TGpHttpRequest(worker.Implementor).PageContents;
  end;
end; { GpHttpRequest }

{ exports }

function GpHttpGet(const url, username, password: string; var statusCode: integer; var
  statusText, pageContents: string): boolean;
begin
  Result := GpHttpRequest(url, username, password, 'GET', '', statusCode, statusText, pageContents);
end; { GpHttpGet }

function GpHttpPost(const url, username, password, postData: string; var statusCode:
  integer; var statusText, pageContents: string): boolean;
begin
  Result := GpHttpRequest(url, username, password, 'POST', postData, statusCode, statusText, pageContents);
end; { GpHttpPost }

{ TGpHttpRequest }

constructor TGpHttpRequest.Create(const url, username, password, request, postData:
  string);
begin
  inherited Create;
  hrURL := url;
  hrUsername := username;
  hrPassword := password;
  hrPostData := postData;
  hrRequest := request;
end; { TGpHttpRequest.Create }

procedure TGpHttpRequest.Cleanup;
begin
  if assigned(hrHttpClient) then begin
    hrHttpClient.RcvdStream.Free;
    hrHttpClient.SendStream.Free;
    FreeAndNil(hrHttpClient);
  end;
end; { TGpHttpRequest.Cleanup }

procedure TGpHttpRequest.HandleRequestDone(sender: TObject; rqType: THttpRequest; error:
  word);
begin
  if error <> 0 then begin
    hrStatusCode := error;
    hrStatusText := 'Socket error';
  end
  else begin
    hrPageContents := TStringStream(hrHttpClient.RcvdStream).DataString;
    hrStatusCode := hrHttpClient.StatusCode;
    hrStatusText := hrHttpClient.ReasonPhrase;
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
    hrHttpClient.SendStream := TStringStream.Create(hrPostData);
    hrHttpClient.RcvdStream := TStringStream.Create('');
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
