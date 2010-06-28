(*:Main unit for the GpSysHookDLL. Implements system-wide keyboard, mouse,
   shell, and CBT hooks. Supports multiple listeners, automatic unhooking on
   process detach, and only installs the hooks that are needed. Supports
   notification listeners and filter listeners (should be used with care because
   SendMessage used for filtering can effectively block the whole system if
   listener is not processing messages). Each listener can only listen to one
   hook because hook code is sent as a message ID. All internal IDs are
   generated from the module name so you only have to rename the DLL to make it
   peacefully coexist with another GpSysHookDLL DLL. Designed to work with (but
   not limited to) GpSysHookComps. 

   @author Primoz Gabrijelcic
   @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2005, Primoz Gabrijelcic
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
   Creation date     : 2001-09-25
   Last modification : 2005-04-18
   Version           : 1.03a
   Defines           : Debug_GpSysHook enables logging of important events
                       and states into file c:\GpSysHook.log. This define
                       causes SysUtils to be loaded and should not be used in
                       the production version.
</pre>*)(*
   History:
     1.03a: 2005-04-18
       - Changed mutex and file mapping security descriptors to allow for cross-desktop
         process cooperation.
     1.03: 2001-11-08
       - Added support for filtering listeners.
     1.02: 2001-10-10
       - Added support for the Computer-based training (CBT) hook.
     1.01: 2001-10-06
       - Modified to work with more than on listener.
       - Internals simplified and modularized.
     1.0: 2001-09-25
       - Created and released.
*)

{$IFDEF VER90 }'Use Delphi 5 or newer to compile this DLL!'{$ENDIF VER90 }//Delphi 2
{$IFDEF VER100}'Use Delphi 5 or newer to compile this DLL!'{$ENDIF VER100}//Delphi 3
{$IFDEF VER120}'Use Delphi 5 or newer to compile this DLL!'{$ENDIF VER120}//Delphi 4

unit GpSysHook;

interface

uses
  Windows,
  Messages,
  GpSysHookCommon;
  // !!!NEVER!!! use SysUtils or other Delphi units

  {:Process has attached to the DLL. Not exported.
  }
  procedure ProcessAttached;

  {:Process has detached from the DLL. Not exported.
  }
  procedure ProcessDetached;

//exports

  {:Attach the window handle to the hook. Returns error code (see
    GpSysHookCommon for more information). Exported.
  }
  function AttachReceiver(hookType: TGpHookType; receiver: THandle;
    isFiltering: boolean): integer; stdcall;

  {:Detach the window handle from the hook. Returns error code (see
    GpSysHookCommon for more information). Exported.
  }
  function DetachReceiver(hookType: TGpHookType; receiver: THandle): integer; stdcall;

  {:Return error status of the first problematic wrapper or NO_ERROR if all
    wrappers were installed without a problem. Exported.
  }
  function LastError: DWORD; stdcall;

implementation

uses
{$IFDEF Debug_GpSysHook}
  SysUtils,
{$ENDIF Debug_GpSysHook}
  GpSecurity;

const
  //:Maximum number of receivers attached to each hook.
  CMaxReceivers = 128;

type
  {:Receiver.
  }
  TGpHookReceiver = record
    Filtering: boolean;
    Handle   : THandle;
  end; { TGpHookReceiver }

  {:Receiver list.
  }
  TGpHookReceivers = record
    Count    : integer;
    Receivers: array [0..CMaxReceivers-1] of TGpHookReceiver;
  end; { TGpHookReceivers }

  {:Dynamic hook data.
  }
  TGpSharedHookData = record
    HookCallback : HHOOK;
    Receivers    : TGpHookReceivers;
  end; { TGpSharedHookData }
  PGpSharedHookData = ^TGpSharedHookData;

  {:Static hook data (hook descriptors).
  }
  TGpStaticHookData = record
    HookType    : integer;
    HookCallback: TFNHookProc;
  end; { TGpStaticHookData }

type
  {:Generic hook wrapper class.
  }
  TGpHookWrapper = class
  private
    wrpHookMutex: THandle;
    wrpLastError: DWORD;
    wrpMemFile  : THandle;
    wrpReceivers: TGpHookReceivers;  // per-process list of receivers
    wrpShared   : PGpSharedHookData; // memory mapped file
    wrpStatic   : TGpStaticHookData;
    {$IFDEF Debug_GpSysHook}
    wrpBaseName : string;
    {$ENDIF Debug_GpSysHook}
  protected
    function  Hook: integer; virtual;
    function  Unhook: integer; virtual;
  public
    constructor Create(baseName: string; hookType: integer;
      hookCallback: TFNHookProc);
    destructor  Destroy; override;
    function  AttachReceiver(receiver: THandle; isFiltering: boolean): integer;
    function  DetachReceiver(receiver: THandle): integer;
    procedure Broadcast(code: integer; wParam: WPARAM; lParam: LPARAM; var Result: LRESULT);
    procedure CallNextHook(code: integer; wParam: WPARAM; lParam: LPARAM; var Result: LRESULT);
    property  LastError: DWORD read wrpLastError;
  end; { TGpHookWrapper }

  {:Generic class wrapping all implemented hooks (actually, their wrapper
    classes).
  }
  TGpHookWrappers = class
  private
    wrpWrappers: array [TGpHookType] of TGpHookWrapper;
  protected
    function GetItems(idx: TGpHookType): TGpHookWrapper; virtual;
  public
    constructor Create;
    destructor  Destroy; override;
    function  AttachReceiver(hookType: TGpHookType; receiver: THandle; isFiltering: boolean): integer;
    function  DetachReceiver(hookType: TGpHookType; receiver: THandle): integer;
    procedure Broadcast(hookType: TGpHookType; code: integer; wParam: WPARAM; lParam: LPARAM; var Result: LRESULT);
    procedure CallNextHook(hookType: TGpHookType; code: integer; wParam: WPARAM; lParam: LPARAM; var Result: LRESULT);
    function  LastError: DWORD;
    property  Items[idx: TGpHookType]: TGpHookWrapper read GetItems; default;
  end; { TGpHookWrappers }

var
  //:Wrappers for all implemented hooks.
  Wrappers: TGpHookWrappers;

{:Shell hook callback.
}
function ShellHookCallback(code: integer; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  wrapper: TGpHookWrapper;
begin
  wrapper := Wrappers[htShell];
  Result := 0;
  if assigned(wrapper) and assigned(wrapper.wrpShared) then begin
    WaitForSingleObject(wrapper.wrpHookMutex, INFINITE);
    try
      if code >= 0 then
        Wrappers.Broadcast(htShell,code,wParam,lParam,Result);
    finally ReleaseMutex(wrapper.wrpHookMutex); end;
      Wrappers.CallNextHook(htShell,code,wParam,lParam,Result);
  end;
end; { ShellHookCallback }

{:Keyboard hook callback.
}
function KbdHookCallback(code: integer; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  wrapper: TGpHookWrapper;
begin
  wrapper := Wrappers[htKeyboard];
  Result := 0;
  if assigned(wrapper) and assigned(wrapper.wrpShared) then begin
    WaitForSingleObject(wrapper.wrpHookMutex, INFINITE);
    try
      if code = HC_ACTION then
        Wrappers.Broadcast(htKeyboard,code,wParam,lParam,Result);
    finally ReleaseMutex(wrapper.wrpHookMutex); end;
      Wrappers.CallNextHook(htKeyboard,code,wParam,lParam,Result);
  end;
end; { KbdHookCallback }

{:Mouse hook callback.
}
function MouseHookCallback(code: integer; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  pMouseHook: PMouseHookStruct;
  wrapper   : TGpHookWrapper;
begin
  wrapper := Wrappers[htMouse];
  Result := 0;
  if assigned(wrapper) and assigned(wrapper.wrpShared) then begin
    WaitForSingleObject(wrapper.wrpHookMutex, INFINITE);
    try
      if code = HC_ACTION then begin
        pMouseHook := PMouseHookStruct(lParam);
        Wrappers.Broadcast(htMouse,wParam,
          (pMouseHook^.pt.x and $FFFF) or (pMouseHook^.pt.y shl 16),
          pMouseHook^.hwnd, Result);
      end;
    finally ReleaseMutex(wrapper.wrpHookMutex); end;
      Wrappers.CallNextHook(htMouse,code,wParam,lParam,Result);
  end;
end; { MouseHookCallback }

{:CBT hook callback.
}
function CBTHookCallback(code: integer; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  wrapper: TGpHookWrapper;
begin
  wrapper := Wrappers[htCBT];
  Result := 0;
  if assigned(wrapper) and assigned(wrapper.wrpShared) then begin
    WaitForSingleObject(wrapper.wrpHookMutex, INFINITE);
    try
      if code = HCBT_ACTIVATE then
        Wrappers.Broadcast(htCBT,code,wParam,PCBTActivateStruct(lParam)^.hWndActive,Result)
      else if code = HCBT_CLICKSKIPPED then
        Wrappers.Broadcast(htCBT,code,wParam,PMouseHookStruct(lParam)^.hwnd,Result)
      else if code >=0 then
        Wrappers.Broadcast(htCBT,code,wParam,lParam,Result);
    finally ReleaseMutex(wrapper.wrpHookMutex); end;
      Wrappers.CallNextHook(htCBT,code,wParam,lParam,Result);
  end;
end; { CBTHookCallback }

(*Copied from the SysUtils to prevent exception handling etc from being loaded.*)
function StrScan(const Str: PChar; Chr: Char): PChar; assembler;
asm
        PUSH    EDI
        PUSH    EAX
        MOV     EDI,Str
        MOV     ECX,0FFFFFFFFH
        XOR     AL,AL
        REPNE   SCASB
        NOT     ECX
        POP     EDI
        MOV     AL,Chr
        REPNE   SCASB
        MOV     EAX,0
        JNE     @@1
        MOV     EAX,EDI
        DEC     EAX
@@1:    POP     EDI
end;

function LastDelimiter(const Delimiters, S: string): Integer;
var
  P: PChar;
begin
  Result := Length(S);
  P := PChar(Delimiters);
  while Result > 0 do begin
    if (S[Result] <> #0) and (StrScan(P, S[Result]) <> nil) then
      Exit;
    Dec(Result);
  end;
end;

function ExtractFileName(const FileName: string): string;
var
  I: Integer;
begin
  I := LastDelimiter('\:', FileName);
  Result := Copy(FileName, I + 1, MaxInt);
end;

function ChangeFileExt(const FileName, Extension: string): string;
var
  I: Integer;
begin
  I := LastDelimiter('.\:',Filename);
  if (I = 0) or (FileName[I] <> '.') then I := MaxInt;
  Result := Copy(FileName, 1, I - 1) + Extension;
end;
(*End of SysUtils functions.*)

{$IFDEF Debug_GpSysHook}
{ Debugging }

{:Debug logger. Sends one line to the c:\GpSysHook.log file.
  @param   msg Message to be written to the debug file.
}        
procedure DebugLog(msg: string);
var
  f: textfile;
begin
  Assign(f,'c:\GpSysHook.log');
  if not FileExists('c:\GpSysHook.log') then
    Rewrite(f)
  else
    Append(f);
  Writeln(f,FormatDateTime('yyyy-mm-dd"T"hh:mm:ss',Now)+' '+msg);
  Close(f);
end; { DebugLog }
{$ENDIF Debug_GpSysHook}

{ TGpHookReceivers class-like interface }

{:Returns index of the receiver or -1 if not found.
}
function Receivers_IndexOf(var receivers: TGpHookReceivers; receiver: THandle): integer;
begin
  for Result := 0 to receivers.Count-1 do
    if receivers.Receivers[Result].Handle = receiver then
      Exit;
  Result := -1;
end; { Receivers_IndexOf }

{:Adds receiver to the receiver list and returns its index. Returns -1 if list
  is full.
}
function Receivers_Add(var receivers: TGpHookReceivers; receiver: THandle;
  isFiltering: boolean): integer;
begin
  if receivers.Count >= (CMaxReceivers-1) then
    Result := -1
  else begin
    Inc(receivers.Count);
    Result := receivers.Count-1;
    with receivers.Receivers[Result] do begin
      Handle    := receiver;
      Filtering := isFiltering;
    end; //with
  end;
end; { Receivers_Add }

{:Returns number of receivers in the list.
}
function Receivers_Count(var receivers: TGpHookReceivers): integer;
begin
  Result := receivers.Count;
end; { Receivers_Count }

{:Clears receiver list.
}
procedure Receivers_Clear(var receivers: TGpHookReceivers);
begin
  receivers.Count := 0;
end; { Receivers_Clear }

{:Deletes receiver from the list. If receiver is not found in the list, nothing
  happens.
}
procedure Receivers_Delete(var receivers: TGpHookReceivers; position: integer);
begin
  if (position >= 0) and (position < receivers.Count) then begin
    if position <> (receivers.Count-1) then
      receivers.Receivers[position] := receivers.Receivers[receivers.Count-1];
    Dec(receivers.Count);
  end;
end; { Receivers_Delete }

{:Returns index-th (0-based) item from the list.
}
function Receivers_Item(var receivers: TGpHookReceivers; index: integer): TGpHookReceiver;
begin
  Result := receivers.Receivers[index];
end; { Receivers_Item }

{ Exports }

{:Called from the DLL whenever a new process is attached. Creates local instance
  of hook wrappers.
}
procedure ProcessAttached;
begin
  wrappers := TGpHookWrappers.Create;
  {$IFDEF Debug_GpSysHook}
  DebugLog(Format('ProcessAttached: %d',[GetCurrentProcessID]));
  {$ENDIF Debug_GpSysHook}
end; { ProcessAttached }

{:Called from the DLL whenever a process is detached. Frees local instance of
  hook wrappers, removing all leftover hooks for that process in the process.
}
procedure ProcessDetached;
begin
  {$IFDEF Debug_GpSysHook}
  DebugLog(Format('ProcessDetached: %d',[GetCurrentProcessID]));
  {$ENDIF Debug_GpSysHook}
  wrappers.Free;
  wrappers := nil;
end; { ProcessDetached }

{:Attaches receiver to the specified hook. Installs hook if needed.
}
function AttachReceiver(hookType: TGpHookType; receiver: THandle;
  isFiltering: boolean): integer; stdcall;
begin
  {$IFDEF Debug_GpSysHook}
  DebugLog(Format('AttachReceiver: %d %d',[Ord(hookType),receiver]));
  {$ENDIF Debug_GpSysHook}
  Result := Wrappers.AttachReceiver(hookType,receiver,isFiltering);
end; { AttachReceiver }

{:Detaches receiver from the specified hook. Removes hook if nobody listens to
  it anymore.
}
function DetachReceiver(hookType: TGpHookType; receiver: THandle): integer; stdcall;
begin
  {$IFDEF Debug_GpSysHook}
  DebugLog(Format('DetachReceiver: %d %d',[Ord(hookType),receiver]));
  {$ENDIF Debug_GpSysHook}
  Result := Wrappers.DetachReceiver(hookType,receiver);
end; { DetachReceiver }

{:Returns last error code.
}
function LastError: DWORD; stdcall;
begin
  Result := Wrappers.LastError;
end; { LastError }

{ TGpHookWrapper }

{:Attaches receiver to the list and installs the hook if it was not installed
  before.
  @param    isFiltering If True, DLL will use SendMessage to send notifications
                        to the listener. Result of the SendMessage call will be
                        returned as the hook procedure result.
                        If False, DLL will use PostMessage to send notifications
                        to the listener.
}
function TGpHookWrapper.AttachReceiver(receiver: THandle;
  isFiltering: boolean): integer;
var
  iReceiver: integer;
begin
  {$IFDEF Debug_GpSysHook}
  DebugLog(Format('AttachReceiver: %d',[receiver]));
  {$ENDIF Debug_GpSysHook}
  Result := 0;
  if not assigned(wrpShared) then
    Exit;
  WaitForSingleObject(wrpHookMutex, INFINITE);
  try
    iReceiver := Receivers_IndexOf(wrpShared^.Receivers,receiver);
    {$IFDEF Debug_GpSysHook}
    DebugLog(Format('  IndexOf: %d',[iReceiver]));
    {$ENDIF Debug_GpSysHook}
    if iReceiver >= 0 then // already registered
      Result := GPHOOK_ERR_ALREADY_REGISTERED
    else begin
      // Add receiver into the global list
      if Receivers_Add(wrpShared^.Receivers,receiver,isFiltering) < 0 then
        Result := GPHOOK_ERR_TOO_MANY_RECEIVERS;
      // Add receiver into a per-process list
      Receivers_Add(wrpReceivers,receiver,isFiltering);
      {$IFDEF Debug_GpSysHook}
      DebugLog(Format('  Count: %d',[Receivers_Count(wrpShared^.Receivers)]));
      DebugLog(Format('  Per-process count: %d',[Receivers_Count(wrpReceivers)]));
      {$ENDIF Debug_GpSysHook}
      if Receivers_Count(wrpShared^.Receivers) = 1 then // first receiver - install the hook
        Result := Hook
      else
        Result := GPHOOK_ERR_NO_ERROR;
    end;
  finally ReleaseMutex(wrpHookMutex); end;
end; { TGpHookWrapper.AttachReceiver }

{:Sends a message to all listeners and set hook result.
}
procedure TGpHookWrapper.Broadcast(code: integer; wParam: WPARAM;
  lParam: LPARAM; var Result: LRESULT);
var
  iReceiver: integer;
  msgRes   : DWORD;
  receiver : TGpHookReceiver;
  sentOK   : boolean;
begin
  iReceiver := 0;
  while iReceiver < Receivers_Count(wrpShared^.Receivers) do begin
    receiver := Receivers_Item(wrpShared^.Receivers,iReceiver);
    if receiver.Filtering then begin
      sentOK := SendMessageTimeout(receiver.Handle, WM_USER+code, wParam, lParam,
           SMTO_ABORTIFHUNG OR SMTO_BLOCK, 5000{ms}, msgRes) <> 0;
      if Result = 0 then
        Result := msgRes;
    end
    else 
      sentOK := PostMessage(receiver.Handle,WM_USER+code, wParam, lParam) or
        (GetLastError <> ERROR_INVALID_WINDOW_HANDLE);
    if sentOK then
      Inc(iReceiver)
    else
      Receivers_Delete(wrpShared^.Receivers,iReceiver);
  end;
end; { TGpHookWrapper.Broadcast }

{:Call next hook procedure and set hook result.
}
procedure TGpHookWrapper.CallNextHook(code: integer; wParam: WPARAM;
  lParam: LPARAM; var Result: LRESULT);
var
  res: LRESULT;
begin
  res := CallNextHookEx(wrpShared^.HookCallback, code, wParam, lParam);
  if Result = 0 then
    Result := res;
end; { TGpHookWrapper.CallNextHook }

{:Creates a hook wrapper. Creates synchronisation mutex and creates or attaches
  to the global hook data area (shared memory file).
}
constructor TGpHookWrapper.Create(baseName: string; hookType: integer;
  hookCallback: TFNHookProc);
var
  wasCreated: boolean;
begin
  {$IFDEF Debug_GpSysHook}
  wrpBaseName := baseName;
  {$ENDIF Debug_GpSysHook}
  wrpStatic.HookType := hookType;
  wrpStatic.HookCallback := hookCallback;
  Receivers_Clear(wrpReceivers);
  wrpHookMutex := CreateMutex_AllowEveryone(true, PChar(baseName + 'Mutex'));
  if wrpHookMutex = 0 then
    wrpLastError := GetLastError
  else begin
    try
      wrpMemFile := CreateFileMapping_AllowEveryone(INVALID_HANDLE_VALUE, PAGE_READWRITE,
        0, SizeOf(TGpSharedHookData), PChar(baseName + 'Shared'));
      if wrpMemFile = 0 then
        wrpLastError := GetLastError
      else begin
        wasCreated := (GetLastError = NO_ERROR);
        wrpShared := MapViewOfFile(wrpMemFile, FILE_MAP_WRITE, 0, 0, 0);
        if wrpShared = nil then
          wrpLastError := GetLastError
        else if wasCreated then
          FillChar(wrpShared^, SizeOf(TGpSharedHookData), 0);
      end;
    finally ReleaseMutex(wrpHookMutex); end;
  end;
end; { TGpHookWrapper.Create }

{:Destroys hook wrapper object. If any listener in this process is still in the
  list, removes it. If global list of listeners is empty at the end, removes
  the hook.
}
destructor TGpHookWrapper.Destroy;
var
  iReceiver: integer;
begin
  // Unhook still hooked receivers in this process.
  for iReceiver := Receivers_Count(wrpReceivers)-1 downto 0 do begin
    {$IFDEF Debug_GpSysHook}
    DebugLog(Format('Removing still attached receiver: %d',
      [Receivers_Item(wrpReceivers,iReceiver).Handle]));
    {$ENDIF Debug_GpSysHook}
    DetachReceiver(Receivers_Item(wrpReceivers,iReceiver).Handle);
  end;
  UnmapViewOfFile(wrpShared);
  CloseHandle(wrpMemFile);
  CloseHandle(wrpHookMutex);
  inherited;
end; { TGpHookWrapper.Destroy }

{:Detaches receiver from the specified hook. Removes hook if nobody listens to it
  anymore.
}
function TGpHookWrapper.DetachReceiver(receiver: THandle): integer;
var
  iReceiver: integer;
begin
  {$IFDEF Debug_GpSysHook}
  DebugLog(Format('DetachReceiver: %d',[receiver]));
  {$ENDIF Debug_GpSysHook}
  Result := 0;
  if not assigned(wrpShared) then
    Exit;
  WaitForSingleObject(wrpHookMutex, INFINITE);
  try
    iReceiver := Receivers_IndexOf(wrpShared^.Receivers,receiver);
    {$IFDEF Debug_GpSysHook}
    DebugLog(Format('  IndexOf: %d',[iReceiver]));
    {$ENDIF Debug_GpSysHook}
    if iReceiver < 0 then // not registered
      Result := GPHOOK_ERR_NOT_REGISTERED
    else begin
      // Remove receiver from a per-process list
      Receivers_Delete(wrpReceivers,Receivers_IndexOf(wrpReceivers,receiver));
      // Remove receiver from the global list
      Receivers_Delete(wrpShared^.Receivers,iReceiver);
      {$IFDEF Debug_GpSysHook}
      DebugLog(Format('  Count: %d',[Receivers_Count(wrpShared^.Receivers)]));
      DebugLog(Format('  Per-process count: %d',[Receivers_Count(wrpReceivers)]));
      {$ENDIF Debug_GpSysHook}
      if Receivers_Count(wrpShared^.Receivers) = 0 then // last receiver - unhook
        Result := Unhook
      else
        Result := 0;
    end;
  finally ReleaseMutex(wrpHookMutex); end;
end; { TGpHookWrapper.DetachReceiver }

{:Installs systemwide hook.
}
function TGpHookWrapper.Hook: integer;
begin
  Result := 0;
  if not assigned(wrpShared) then
    Exit;
  WaitForSingleObject(wrpHookMutex, INFINITE);
  try
    if wrpShared^.HookCallback <> 0 then
      Result := GPHOOK_ERR_ALREADY_HOOKED
    else begin
      {$IFDEF Debug_GpSysHook}
      DebugLog('Hooking '+wrpBaseName);
      {$ENDIF Debug_GpSysHook}
      wrpShared^.HookCallback :=
        SetWindowsHookEx(wrpStatic.HookType,wrpStatic.HookCallback,HInstance,0);
      if wrpShared^.HookCallback = 0 then
        Result := GetLastError;
    end;
  finally ReleaseMutex(wrpHookMutex); end;
end; { TGpHookWrapper.Hook }

{:Removes systemwide hook.
}
function TGpHookWrapper.Unhook: integer;
begin
  Result := 0;
  if not assigned(wrpShared) then
    Exit;
  WaitForSingleObject(wrpHookMutex, INFINITE);
  try
    if wrpShared^.HookCallback <> 0 then begin
      {$IFDEF Debug_GpSysHook}
      DebugLog('Unhooking '+wrpBaseName);
      {$ENDIF Debug_GpSysHook}
      if not UnhookWindowsHookEx(wrpShared^.HookCallback) then
        Result := GetLastError;
      wrpShared^.HookCallback := 0;
    end;
    Receivers_Clear(wrpShared^.Receivers);
  finally ReleaseMutex(wrpHookMutex); end;
end; { TGpHookWrapper.Unhook }

{ TGpHookWrappers }

{:Attaches receiver to the specified hook. Installs hook if needed.
}
function TGpHookWrappers.AttachReceiver(hookType: TGpHookType;
  receiver: THandle; isFiltering: boolean): integer;
begin
  Result := wrpWrappers[hookType].AttachReceiver(receiver,isFiltering);
end; { TGpHookWrappers.AttachReceiver }

{:Sends a message to all listeners and set hook result.
}
procedure TGpHookWrappers.Broadcast(hookType: TGpHookType; code: integer;
  wParam: WPARAM; lParam: LPARAM; var Result: LRESULT);
begin
  if assigned(wrpWrappers[hookType]) then
    wrpWrappers[hookType].Broadcast(code,wParam,lParam,Result);
end; { TGpHookWrappers.Broadcast }

{:Call next hook procedure for the specified hook and set hook result.
}
procedure TGpHookWrappers.CallNextHook(hookType: TGpHookType;
  code: integer; wParam: WPARAM; lParam: LPARAM; var Result: LRESULT);
begin
  if assigned(wrpWrappers[hookType]) then
    wrpWrappers[hookType].CallNextHook(code,wParam,lParam,Result);
end; { TGpHookWrappers.CallNextHook }

{:Creates wrappers for all supported hooks.
}
constructor TGpHookWrappers.Create;
var
  gshBaseName: array [0..MAX_PATH] of char;
  strBaseName: string;
begin
  if GetModuleFileName(HInstance, gshBaseName, SizeOf(gshBaseName)-1)= 0 then begin
    MessageBox(0,'GpSysHook','Failed to retrieve own module name!',MB_OK);
    Halt;
  end;
  strBaseName := 'GP_SYS_HOOK_'+ChangeFileExt(ExtractFileName(gshBaseName),'')+'_';
  wrpWrappers[htShell] :=
    TGpHookWrapper.Create(strBaseName+'SHELL', WH_SHELL, @ShellHookCallback);
  wrpWrappers[htKeyboard] :=
    TGpHookWrapper.Create(strBaseName+'KEYBOARD', WH_KEYBOARD, @KbdHookCallback);
  wrpWrappers[htMouse] :=
    TGpHookWrapper.Create(strBaseName+'MOUSE', WH_MOUSE, @MouseHookCallback);
  wrpWrappers[htCBT] :=
    TGpHookWrapper.Create(strBaseName+'CBT', WH_CBT, @CBTHookCallback);
end; { TGpHookWrappers.Create }

{:Destroys wrappers for all supported hooks, removing all active listeners from
  this process in the process.
}
destructor TGpHookWrappers.Destroy;
var
  iWrapper: TGpHookType;
begin
  for iWrapper := Low(TGpHookType) to High(TGpHookType) do begin
    wrpWrappers[iWrapper].Free;
    wrpWrappers[iWrapper] := nil;
  end;
end; { TGpHookWrappers.Destroy }

{:Detaches receiver from the specified hook. Removes hook if nobody listens to
  it anymore.
}
function TGpHookWrappers.DetachReceiver(hookType: TGpHookType;
  receiver: THandle): integer;
begin
  Result := wrpWrappers[hookType].DetachReceiver(receiver);
end; { TGpHookWrappers.DetachReceiver }

{:Returns specified hook wrapper.
}
function TGpHookWrappers.GetItems(idx: TGpHookType): TGpHookWrapper;
begin
  Result := wrpWrappers[idx];
end; { TGpHookWrappers.GetItems }

{:Returns last error code of the first wrapper that is in the error state.
}
function TGpHookWrappers.LastError: DWORD;
var
  iWrapper: TGpHookType;
begin
  Result := 0;
  for iWrapper := Low(TGpHookType) to High(TGpHookType) do
    if wrpWrappers[iWrapper].LastError <> NO_ERROR then begin
      Result := wrpWrappers[iWrapper].LastError;
      break; //for
    end;
end; { TGpHookWrappers.LastError }

end.
