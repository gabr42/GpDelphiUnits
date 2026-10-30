(*:Dynamic loader for the GpSysHook DLL.
   @author Primoz Gabrijelcic
   @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2003, Primoz Gabrijelcic
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
   Creation date     : 2001-10-06
   Last modification : 2001-10-06
   Version           : 1.0
</pre>*)(*
   History:
     1.0: 2001-10-06
       - Created & released.
*)

unit GpSysHookLoader;

interface

uses
  Windows,
  GpSysHookCommon;

type
  //:Signature of the AttachReceiver function.
  TFNAttachReceiver = function (hookType: TGpHookType; receiver: THandle;
                        isFiltering: boolean): integer; stdcall;
  //:Signature of the DetachReceiver function.
  TFNDetachReceiver = function (hookType: TGpHookType;
                        receiver: THandle): integer; stdcall;
  //:Signature of the LastError function.
  TFNLastError      = function (): DWORD; stdcall;

var
  //:Pointer to the loaded AttachReceiver function.
  fnAttachReceiver: TFNAttachReceiver;
  //:Pointer to the loaded DetachReceiver function.
  fnDetachReceiver: TFNDetachReceiver;
  //:Pointer to the loaded LoastError function.
  fnLastError     : TFNLastError;

  {:Load hook DLL and bind fn* variables to the appropriate exports.
    @returns 0 on error
             >0 (= GetLastError) if DLL cannot be loaded
             <0 (= GpSysHookCommon error) if DLL was loaded but GetLastError
                export indicates error
  }
  function  LoadHookDLL(dllName: string): integer;

  {:Unload hook DLL.
  }
  procedure UnloadHookDLL;

  {:Convert value returned from the LoadHookDLL function to error message.
  }
  function  HookErrorToStr(errorCode: integer): string;

implementation

uses
  SysUtils;

resourcestring
  sUnknownError = 'Unknown error %d';

var
  dllHandle: HINST;
  dllCount : integer;

  function LoadHookDLL(dllName: string): integer;
  begin
    if dllHandle = 0 then begin
      dllHandle := LoadLibrary(PChar(dllName));
      if (dllHandle = 0) and (not SameText(ExtractFileExt(dllName),'.dll')) then
        dllHandle := LoadLibrary(PChar(ChangeFileExt(dllName,'.dll')));
      if dllHandle = 0 then
        Result := GetLastError
      else begin
        Inc(dllCount);
        @fnAttachReceiver := GetProcAddress(dllHandle,'AttachReceiver');
        @fnDetachReceiver := GetProcAddress(dllHandle,'DetachReceiver');
        @fnLastError      := GetProcAddress(dllHandle,'LastError');
        if (@fnAttachReceiver = nil) or
           (@fnDetachReceiver = nil) or
           (@fnLastError = nil) then
        begin                            
          Result := GPHOOK_ERR_NO_EXPORTS;
          UnloadHookDLL;
        end
        else
          Result := 0;
      end;
    end
    else begin
      Inc(dllCount);
      Result := 0;
    end;
  end; { LoadHookDLL }

  procedure UnloadHookDLL;
  begin
    if dllHandle <> 0 then begin
      Dec(dllCount);
      if dllCount <= 0 then begin
        FreeLibrary(dllHandle);
        dllHandle := 0;
        dllCount := 0;
        @fnAttachReceiver := nil;
        @fnDetachReceiver := nil;
        @fnLastError      := nil;
      end;
    end;
  end; { UnloadHookDLL }

  function HookErrorToStr(errorCode: integer): string;
  begin
    if errorCode > 0 then
      Result := SysErrorMessage(errorCode)
    else if (errorCode >= Low(GpHookErrors)) and
            (errorCode <= High(GpHookErrors)) then
      Result := GpHookErrors[errorCode]
    else
      Result := Format(sUnknownError,[errorCode]);
  end; { HookErrorToStr }
  
initialization
  dllHandle := 0;
  dllCount := 0;
  fnAttachReceiver := nil;
  fnDetachReceiver := nil;
  fnLastError      := nil;
finalization
  if dllHandle <> 0 then
    MessageBox(0, 'GpSysHook DLL was not unloaded!', 'GpSysHookLoader', MB_OK + MB_ICONWARNING);
end.
