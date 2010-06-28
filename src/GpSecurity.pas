(*:Windows NT security wrapper.
   @author Primoz Gabrijelcic
   @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2009, Primoz Gabrijelcic
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
   Creation date     : 2002-10-14
   Last modification : 2009-02-17
   Version           : 2.0
</pre>*)(*
   History:
     2.01: 2010-06-10
       - Use JWA in all Delphis as parts of JWA cannot be copied due to licensing issues.
     2.0: 2009-02-17
       - Relevant parts of the JWA library copied into this unit. Used only when compiling
         for Delphi 2009 and newer.
     1.0: 2002-10-16
       - Released.
*)

unit GpSecurity;

interface

uses
  Windows, JwaAclApi, JwaAccCtrl, JwaWinNT, JwaWinBase, JwaWinType;

type
  PSecurityAttributes = LPSECURITY_ATTRIBUTES;

type
  TGpSecurityAttributes = class
  private
    gsaDacl    : PACL;
    gsaSecAttr : TSecurityAttributes;
    gsaSecDescr: TSecurityDescriptor;
    gsaSid     : PSID;
  protected
    function GetSA: PSecurityAttributes;
  public
    constructor AllowAccount(const accountName: string);
    constructor AllowEveryone;
    constructor AllowSID(sid: PSID);
    destructor  Destroy; override;
    property SecurityAttributes: PSecurityAttributes read GetSA;
  end; { TGpSecurityAttributes }

function CreateEvent_AllowAccount(const accountName: string;
  manualReset, initialState: boolean; const eventName: string): THandle;
function CreateEvent_AllowEveryone(manualReset, initialState: boolean;
  const eventName: string): THandle;
function CreateFileMapping_AllowAccount(const accountName: string;
  hFile: THandle; flProtect, dwMaximumSizeHigh, dwMaximumSizeLow: DWORD;
  const fileMappingName: string): THandle;
function CreateFileMapping_AllowEveryone(hFile: THandle; flProtect,
  dwMaximumSizeHigh, dwMaximumSizeLow: DWORD;
  const fileMappingName: string): THandle;
function CreateMutex_AllowAccount(const accountName: string;
  initialOwner: boolean; const mutexName: string): THandle;
function CreateMutex_AllowEveryone(initialOwner: boolean;
  const mutexName: string): THandle;
function CreateSemaphore_AllowAccount(const accountName: string;
  initialCount, maximumCount: longint; const semaphoreName: string): THandle;
function CreateSemaphore_AllowEveryone(initialCount, maximumCount: longint;
  const semaphoreName: string): THandle;

implementation

uses
  SysUtils;

function CreateEvent_AllowAccount(const accountName: string;
  manualReset, initialState: boolean; const eventName: string): THandle;
var
  gsa: TGpSecurityAttributes;
begin
  gsa := TGpSecurityAttributes.AllowAccount(accountName);
  try
    Result := CreateEvent(gsa.SecurityAttributes, manualReset, initialState, PChar(eventName));
  finally FreeAndNil(gsa); end;
end; { TGpSecurityAttributes.CreateEvent_AllowAccount }

function CreateEvent_AllowEveryone(manualReset, initialState: boolean;
  const eventName: string): THandle;
var
  gsa: TGpSecurityAttributes;
begin
  gsa := TGpSecurityAttributes.AllowEveryone;
  try
    Result := CreateEvent(gsa.SecurityAttributes, manualReset, initialState, PChar(eventName));
  finally FreeAndNil(gsa); end;
end; { TGpSecurityAttributes.CreateEvent_AllowEveryone }

function CreateFileMapping_AllowAccount(const accountName: string;
  hFile: THandle; flProtect, dwMaximumSizeHigh, dwMaximumSizeLow: DWORD;
  const fileMappingName: string): THandle;
var
  gsa: TGpSecurityAttributes;
begin
  gsa := TGpSecurityAttributes.AllowAccount(accountName);
  try
    Result := CreateFileMapping(hFile, gsa.SecurityAttributes, flProtect,
      dwMaximumSizeHigh, dwMaximumSizeLow, PChar(fileMappingName)); 
  finally FreeAndNil(gsa); end;
end; { TGpSecurityAttributes.CreateFileMapping_AllowAccount }

function CreateFileMapping_AllowEveryone(hFile: THandle; flProtect,
  dwMaximumSizeHigh, dwMaximumSizeLow: DWORD;
  const fileMappingName: string): THandle;
var
  gsa: TGpSecurityAttributes;
begin
  gsa := TGpSecurityAttributes.AllowEveryone;
  try
    Result := CreateFileMapping(hFile, gsa.SecurityAttributes, flProtect,
      dwMaximumSizeHigh, dwMaximumSizeLow, PChar(fileMappingName)); 
  finally FreeAndNil(gsa); end;
end; { TGpSecurityAttributes.CreateFileMapping_AllowEveryone }

function CreateMutex_AllowAccount(const accountName: string;
  initialOwner: boolean; const mutexName: string): THandle;
var
  gsa: TGpSecurityAttributes;
begin
  gsa := TGpSecurityAttributes.AllowAccount(accountName);
  try
    Result := CreateMutex(gsa.SecurityAttributes, initialOwner, PChar(mutexName));
  finally FreeAndNil(gsa); end;
end; { CreateMutex_AllowAccount }

function CreateMutex_AllowEveryone(initialOwner: boolean;
  const mutexName: string): THandle;
var
  gsa: TGpSecurityAttributes;
begin
  gsa := TGpSecurityAttributes.AllowEveryone;
  try
    Result := CreateMutex(gsa.SecurityAttributes, initialOwner, PChar(mutexName));
  finally FreeAndNil(gsa); end;
end; { CreateMutex_AllowEveryone }

function CreateSemaphore_AllowAccount(const accountName: string;
  initialCount, maximumCount: longint; const semaphoreName: string): THandle;
var
  gsa: TGpSecurityAttributes;
begin
  gsa := TGpSecurityAttributes.AllowAccount(accountName);
  try
    Result := CreateSemaphore(gsa.SecurityAttributes, initialCount, maximumCount, PChar(semaphoreName));
  finally FreeAndNil(gsa); end;
end; { TGpSecurityAttributes.CreateSemaphore_AllowAccount }

function CreateSemaphore_AllowEveryone(initialCount, maximumCount: longint;
  const semaphoreName: string): THandle;
var
  gsa: TGpSecurityAttributes;
begin
  gsa := TGpSecurityAttributes.AllowEveryone;
  try
    Result := CreateSemaphore(gsa.SecurityAttributes, initialCount, maximumCount, PChar(semaphoreName));
  finally FreeAndNil(gsa); end;
end; { TGpSecurityAttributes.CreateSemaphore_AllowEveryone }

{ TGpSecurityAttributes }

constructor TGpSecurityAttributes.AllowAccount(const accountName: string);
var
  domain    : string;
  domainSize: DWORD;
  sid       : PSID;
  sidSize   : DWORD;
  use       : DWORD;
begin
  if Win32Platform <> VER_PLATFORM_WIN32_NT then
    Exit;
  // get the SID for the account name
  domainSize := 0;
  LookupAccountName(nil, PChar(accountName), nil, sidSize, nil, domainSize, use);
  sid := AllocMem(sidSize);
  try
    SetLength(domain, domainSize);
    Win32Check(LookupAccountName(nil, PChar(accountName), sid, sidSize, PChar(domain), domainSize, use));
    AllowSID(sid);
  finally FreeMem(sid); end;
end; { TGpSecurityAttributes.AllowAccount }

constructor TGpSecurityAttributes.AllowEveryone;
var
  siaWorld: SID_IDENTIFIER_AUTHORITY;
  sid     : PSID;
begin
  if Win32Platform <> VER_PLATFORM_WIN32_NT then
    Exit;
  // get the well-known Everyone SID
  siaWorld := SECURITY_WORLD_SID_AUTHORITY;
  sid := AllocMem(GetSidLengthRequired(1));
  try
    Win32Check(InitializeSid(sid, @siaWorld, 1));
    PDWORD(GetSidSubAuthority(sid, 0))^ := SECURITY_WORLD_RID;
    AllowSID(sid);
  finally FreeMem(sid); end;
end; { TGpSecurityAttributes.AllowEveryone }

constructor TGpSecurityAttributes.AllowSID(sid: PSID);
var
  daclSize: integer;
  sidSize : integer;
begin
  if Win32Platform <> VER_PLATFORM_WIN32_NT then
    Exit;
  // copy SID to internal field
  sidSize := GetLengthSid(sid);
  gsaSid := AllocMem(sidSize);
  Move(sid^, gsaSid^, sidSize);
  // create a dacl and add the SID, granting full access
  daclSize := SizeOf(ACL) + SizeOf(ACCESS_ALLOWED_ACE) + GetLengthSid(gsaSid);
  gsaDacl := AllocMem(daclSize);
  Win32Check(InitializeAcl(gsaDacl, daclSize, ACL_REVISION));
  Win32Check(AddAccessAllowedAce(gsaDacl, ACL_REVISION, GENERIC_ALL, gsaSid));
  // create a security descriptor and set the dacl
  Win32Check(InitializeSecurityDescriptor(@gsaSecDescr, SECURITY_DESCRIPTOR_REVISION));
  Win32Check(SetSecurityDescriptorDacl(@gsaSecDescr, true, gsaDacl, false));
  // initialize a security attribute
  FillChar(gsaSecAttr, SizeOf(gsaSecAttr), 0);
  gsaSecAttr.nLength := SizeOf(gsaSecAttr);
  gsaSecAttr.lpSecurityDescriptor := @gsaSecDescr;
end; { TGpSecurityAttributes.AllowSID }

destructor TGpSecurityAttributes.Destroy;
begin
  if assigned(gsaSid) then begin
    FreeMem(gsaSid);
    gsaSid := nil;
  end;
  if assigned(gsaDacl) then begin
    FreeMem(gsaDacl);
    gsaDacl := nil;
  end;
  inherited;
end; { TGpSecurityAttributes.Destroy }

function TGpSecurityAttributes.GetSA: PSecurityAttributes;
begin
  if Win32Platform = VER_PLATFORM_WIN32_NT then
    Result := @gsaSecAttr
  else
    Result := nil;
end; { TGpSecurityAttributes.GetSA }

end.
