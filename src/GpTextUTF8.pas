(* UTF8 conversion logic that support Unicode plane 1. Shared between GpTextFile
   and GpTextStream.
   @author Primoz Gabrijelcic
   @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2025, Primoz Gabrijelcic
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

   Author           : Primoz Gabrijelcic
   Creation date    : 2025-07-18
   Last modification: 2025-07-18
   Version          : 1.0
   </pre>
*)(*
   History:
     1.0: 2025-07-18
       - Released.
*)

unit GpTextUTF8;

interface

function UTF8BufToWideCharBuf(const utf8Buf; utfByteCount: integer;
  var unicodeBuf; var leftUTF8, readAhead: integer): integer;

function WideCharBufToUTF8Buf(const unicodeBuf; uniByteCount: integer;
  var utf8Buf): integer;

implementation

type
  dword = cardinal;

{:Converts UTF-8 encoded buffer into WideChars (UTF-16). Target buffer must be
  pre-allocated and large enough (at most utfByteCount number of WideChars will
  be generated).                                                                 <br>
  RFC 2279 (http://www.ietf.org/rfc/rfc2279.txt) describes the conversion:       <br>
  $00..$7F => $0000..$007F                                                       <br>
  110[bit10..bit6] 10[bit5..bit0] => $0080..$07FF                                <br>
  1110[bit15..bit12] 10[bit11..bit6] 10[bit5..bit0] => $0800..$FFFF              <br>
  11110[bit20..bit18] 10[bit17..bit12] 10[bit11..bit6] 10[bit5..bit0] => $010000..$10FFFF
  @param   utf8Buf      UTF-8 encoded buffer.
  @param   utfByteCount Size of utf8Buf, in bytes.
  @param   unicodeBuf   Pre-allocated buffer for WideChars.
  @param   leftUTF8     Number of bytes left in utf8Buf after conversion (0, 1,
                        or 2).
  @param   readAhead    Number of bytes read too far because of broken UTF-8.
  @returns Number of bytes used in unicodeBuf buffer.
  @since   2.01
}
function UTF8BufToWideCharBuf(const utf8Buf; utfByteCount: integer;
  var unicodeBuf; var leftUTF8, readAhead: integer): integer;
var
  c1,c2   : byte;
  ch      : dword;
  invalid : boolean;
  numExtra: integer;
  pch     : PAnsiChar;
  pwc     : PWideChar;
begin
  pch := @utf8Buf;
  pwc := @unicodeBuf;
  leftUTF8 := utfByteCount;
  invalid := false;
  readAhead := 0;
  while (leftUTF8 > 0) and (not invalid) do begin
    c1 := byte(pch^);
    c2 := c1;
    Inc(pch);

    if (c1 AND $80) = 0 then begin
      ch := c1;
      numExtra := 0;
    end
    else if (c1 AND $E0) = $C0 then begin
      ch := c1 AND $1F;
      numExtra := 1;
    end
    else if (c1 AND $F0) = $E0 then begin
      ch := c1 AND $0F;
      numExtra := 2;
    end
    else if (c1 AND $F8) = $F0 then begin
      ch := c1 AND $07;
      numExtra := 3;
    end
    else begin // invalid UTF-8 character
      ch := Ord(' ');
      numExtra := 0;
    end;

    if leftUTF8 <= numExtra then
      break; // not enough data in the buffer

    Dec(leftUTF8);
    for var iExtra := 1 to numExtra do begin
      c1 := byte(pch^);
      if (c1 AND $80) <> $80 then begin // invalid sequence
        if iExtra = 1 then
          ch := c2
        else
          ch := Ord(' ');
        readAhead := numExtra - iExtra + 1;
        invalid := true;
        break; // for
      end
      else begin
        ch := (ch SHL 6) OR (word(c1 AND $3F));
        Inc(pch);
        Dec(leftUTF8);
      end;
    end; // for

    if ch < $10000 then begin
      word(pwc^) := ch;
      Inc(pwc);
    end
    else begin
      Dec(ch, $10000);
      word(pwc^) :=
        $D800 OR
        ((ch AND $FFC00) SHR 10);
      Inc(pwc);
      word(pwc^) :=
        $DC00 OR
        (ch AND $3FF);
      Inc(pwc);
    end;
  end; //while
  Result := integer(pwc)-integer(@unicodeBuf);
end; { UTF8BufToWideCharBuf }

{:Convers buffer of WideChars (UTF-16) into UTF-8 encoded form. Target buffer must be
  pre-allocated and large enough (each WideChar will use at most four bytes
  in UTF-8 encoding).                                                            <br>
  RFC 2279 (http://www.ietf.org/rfc/rfc2279.txt) describes the conversion:       <br>
  $0000..$007F => $00..$7F                                                       <br>
  $0080..$07FF => 110[bit10..bit6] 10[bit5..bit0]                                <br>
  $0800..$FFFF => 1110[bit15..bit12] 10[bit11..bit6] 10[bit5..bit0]              <br>
  $010000..$10FFFF => 11110[bit20..bit18] 10[bit17..bit12] 10[bit11..bit6] 10[bit5..bit0]
  @param   unicodeBuf   Buffer of WideChars.
  @param   uniByteCount Size of unicodeBuf, in bytes.
  @param   utf8Buf      Pre-allocated buffer for UTF-8 encoded result.
  @returns Number of bytes used in utf8Buf buffer.
  @since   2.01
}
function WideCharBufToUTF8Buf(const unicodeBuf; uniByteCount: integer;
  var utf8Buf): integer;
var
  iwc: integer;
  pch: PAnsiChar;
  pwc: PWideChar;
  dwc: dword;

  procedure AddByte(b: byte);
  begin
    pch^ := ansichar(b);
    Inc(pch);
  end; { AddByte }

begin { WideCharBufToUTF8Buf }
  pwc := @unicodeBuf;
  pch := @utf8Buf;
  iwc := 1;
  while iwc <= (uniByteCount div SizeOf(WideChar)) do begin
    dwc := Ord(pwc^);
    Inc(pwc);
    var skipChar := false;
    if (dwc AND $FC00) = $DC00 then skipChar := true {second UTF-16 code cannot be first}
    else if (dwc AND $FC00) = $D800 then begin
      if iwc = (uniByteCount div SizeOf(WideChar)) then skipChar := true {no space for second UTF-16 char}
      else if (Ord(pwc^) AND $FC00) <> $DC00 then begin
        skipChar := true; {second UTF-16 code invalid}
        Inc(pwc);
        Inc(iwc);
      end
      else begin
        dwc := (dword(dwc AND $3FF) SHL 10) OR
               (Ord(pwc^) AND $3FF);
        Inc(dwc, $10000);
        Inc(pwc);
        Inc(iwc);
      end;
    end;
    if not skipChar then begin
      if (dwc >= $0000) and (dwc <= $007F) then begin
        AddByte(dwc AND $7F);
      end
      else if (dwc >= $0080) and (dwc <= $07FF) then begin
        AddByte($C0 OR ((dwc SHR 6) AND $1F));
        AddByte($80 OR (dwc AND $3F));
      end
      else if (dwc >= $0800) and (dwc <= $FFFF) then begin
        AddByte($E0 OR ((dwc SHR 12) AND $0F));
        AddByte($80 OR ((dwc SHR 6) AND $3F));
        AddByte($80 OR (dwc AND $3F));
      end
      else if (dwc >= $010000) and (dwc <= $10FFFF) then begin
        AddByte($F0 OR ((dwc SHR 18) AND $07));
        AddByte($80 OR ((dwc SHR 12) AND $3F));
        AddByte($80 OR ((dwc SHR 6) AND $3F));
        AddByte($80 OR (dwc AND $3F));
      end;
    end;
    Inc(iwc);
  end; //while
  Result := NativeUInt(pch)-NativeUInt(@utf8Buf);
end; { WideCharBufToUTF8Buf }

end.
