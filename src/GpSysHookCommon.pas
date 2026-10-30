(*:Common constants, variables, and types for the GpSysHook DLL and component
   wrappers.

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
   Creation date     : 2001-09-25
   Last modification : 2001-10-10
   Version           : 1.02
</pre>*)(*
   History:
     1.02: 2001-10-10
       - Added CBT hook to the list of supported hooks.
     1.01: 2001-10-06
       - Documented.
     1.0: 2001-09-25
       - Created and released.
*)

unit GpSysHookCommon;

interface

uses
  Windows;

{Error codes returned from GpSysHook.AttachReceiver, GpSysHook.DetachReceiver,
  and GpSysHookLoader.LoadHookDLL.
}
const
  GPHOOK_FIRST_ERROR = 0;

  //:No error.
  GPHOOK_ERR_NO_ERROR
    = GPHOOK_FIRST_ERROR;
  //:DLL doesn't export all required functions.
  GPHOOK_ERR_NO_EXPORTS
    = GPHOOK_ERR_NO_ERROR-1;
  //:Receiver already registered.
  GPHOOK_ERR_ALREADY_REGISTERED
    = GPHOOK_ERR_NO_EXPORTS-1;
  //:Receiver not registered.
  GPHOOK_ERR_NOT_REGISTERED
    = GPHOOK_ERR_ALREADY_REGISTERED-1;
  //:Too many receivers.
  GPHOOK_ERR_TOO_MANY_RECEIVERS
    = GPHOOK_ERR_NOT_REGISTERED-1;
  //:System hook already installed.
  GPHOOK_ERR_ALREADY_HOOKED
    = GPHOOK_ERR_TOO_MANY_RECEIVERS-1;

  GPHOOK_LAST_ERROR = GPHOOK_ERR_ALREADY_HOOKED;

var
  //:Error codes for the correcsponding error messages.
  GpHookErrors: array [GPHOOK_LAST_ERROR..GPHOOK_FIRST_ERROR] of string;

type
  //:Implemented hooks.
  TGpHookType = (htShell, htKeyboard, htMouse, htCBT);

implementation

resourcestring
  sNoError           = 'No error.';
  sNoExports         = 'DLL doesn''t export all required functions.';
  sAlreadyRegistered = 'Receiver already registered.';
  sNotRegistered     = 'Receiver not registered.';
  sTooManyReceivers  = 'Too many receivers.';
  sAlreadyHooked     = 'System hook already installed.';

initialization
  GpHookErrors[GPHOOK_ERR_NO_ERROR]           := sNoError;
  GpHookErrors[GPHOOK_ERR_NO_EXPORTS]         := sNoExports;
  GpHookErrors[GPHOOK_ERR_ALREADY_REGISTERED] := sAlreadyRegistered;
  GpHookErrors[GPHOOK_ERR_NOT_REGISTERED]     := sNotRegistered;
  GpHookErrors[GPHOOK_ERR_TOO_MANY_RECEIVERS] := sTooManyReceivers;
  GpHookErrors[GPHOOK_ERR_ALREADY_HOOKED]     := sAlreadyHooked;
end.
