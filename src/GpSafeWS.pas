(*
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
*)

unit GpSafeWS;

interface

uses
  ScktComp;

type
  TSafeWinSocketStream = class(TWinSocketStream)
    constructor Create(ASocket: TCustomWinSocket; TimeOut: longint);
    destructor  Destroy; override;
    function    SafeRead(var Buffer; Count: longint): longint;
    function    SafeWrite(const Buffer; Count: longint): longint;
  private
    swsFailed: boolean;
    swsBuffer: pointer;
    swsBufferSize: longint;
    procedure PrepWriteBuffer (Count: longint);
  {$IFDEF DebugSockets}
    function  FormatBuffer(var buffer; countExp, countReal: integer): string;
  {$ENDIF DebugSockets}
  end;

implementation

{$IFDEF DebugSockets}
uses
  SysUtils,
  uDbg,
  uDbgintf;
{$ENDIF DebugSockets}

const
  CSmallBlockSize = 2048;
  CMaxBlockSize = 16384;

  constructor TSafeWinSocketStream.Create(ASocket: TCustomWinSocket; TimeOut: longint);
  begin
    swsFailed := false;
    swsBufferSize := CSmallBlockSize;
    GetMem(swsBuffer,swsBufferSize);
    inherited Create(ASocket, TimeOut);
  {$IFDEF DebugSockets}
    Debugger.LogFmtMsg('[Sckt] Create: %p', [pointer(Self)]);
  {$ENDIF DebugSockets}
  end; { TSafeWinSocketStream.Create }

  destructor TSafeWinSocketStream.Destroy;
  begin
  {$IFDEF DebugSockets}
    Debugger.LogFmtMsg('[Sckt] Destroy: %p', [pointer(Self)]);
  {$ENDIF DebugSockets}
    inherited Destroy;
    FreeMem(swsBuffer);
  end; { TSafeWinSocketStream.Destroy }

{$IFDEF DebugSockets}
  function TSafeWinSocketStream.FormatBuffer(var buffer; countExp, countReal: longint): string;
  var
    i: integer;
    s: shortstring;
    p: ^byte;
  begin
    s := Format('(%d,%d):',[countExp,countReal]);
    p := @buffer;
    for i := 0 to countReal-1 do begin
      if i > 0 then s := s + ',';
      s := s + IntToStr(p^);
      Inc(p);
      if (i < (countReal-1)) and (Length(s) > 251) then begin
        s := s + '...';
        break;
      end;
    end; //for
    Result := s;
  end; { TSafeWinSocketStream.FormatBuffer }
{$ENDIF DebugSockets}

  procedure TSafeWinSocketStream.PrepWriteBuffer (Count: longint);
  var
    PrevBufsize: longint;
  begin
    if swsBufferSize = Count then
      Exit;
    PrevBufsize := swsBufferSize;
    swsBufferSize := ((Count div CSmallBlockSize) + 1) * CSmallBlockSize;
    if swsBufferSize > CMaxBlockSize then
      swsBufferSize := CMaxBlockSize;
    if PrevBufsize <> swsBufferSize then begin
      if assigned(swsBuffer) then
        FreeMem(swsBuffer);
      GetMem(swsBuffer,swsBufferSize);
    end;
  end;

  function TSafeWinSocketStream.SafeRead(var buffer; count: longint): longint;
  var
    numb,lread: integer;
    pb: PByte;
  begin
    if swsFailed then Result := 0
    else begin
      try
        numb := 0;
        lread := 1;
        pb := @buffer;
        while (lread > 0) and (numb < count) do begin
          lread := count-numb;
          if lread > swsBufferSize then lread := swsBufferSize; {use blocks}
          if not inherited WaitForData(TimeOut) then lread := 0
          else lread := inherited Read(swsBuffer^,lread);
          if lread > 0 then begin
            Move(swsBuffer^,pb^,lread);
            inc (pb, lread);
            inc (numb, lread);
          end;
        end;
        Result := numb;
      except Result := 0; end;
      swsFailed := (Result <> count);
    end;
  {$IFDEF DebugSockets}
    Debugger.LogFmtMsg('[Sckt] %p >> %s', [pointer(Self),FormatBuffer(Buffer,Count,Result)]);
  {$ENDIF DebugSockets}
  end; { TSafeWinSocketStream.SafeRead }

  function TSafeWinSocketStream.SafeWrite(const buffer; count: longint): longint;
  var
    numb,lwrite: integer;
    pb: PByte;
  begin
    if swsFailed then Result := 0
    else begin
      try
        PrepWriteBuffer(Count);
        numb := 0;
        lwrite := 1;
        pb := @buffer;
        while (lwrite > 0) and (numb < count) do begin
          lwrite := count-numb;
          if lwrite > swsBufferSize then lwrite := swsBufferSize; {use blocks}
          Move(pb^,swsBuffer^,lwrite);
          lwrite := inherited Write(swsBuffer^,lwrite);
          if lwrite > 0 then begin
            inc (pb, lwrite);
            inc (numb, lwrite);
          end;
        end;
        Result := numb;
      except Result := 0; end;
      swsFailed := (Result <> count);
    end;
  {$IFDEF DebugSockets}
    Debugger.LogFmtMsg('[Sckt] %p << %s', [pointer(Self),FormatBuffer((@buffer)^,count,result)]);
  {$ENDIF DebugSockets}
  end; { TSafeWinSocketStream.SafeWrite }

{$IFDEF DebugSockets}
initialization
  NxStartDebug;
{$ENDIF DebugSockets}
end.
