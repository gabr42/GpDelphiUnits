{$B-,H+,J+,Q-,T-,X+}

unit GpTextStream;

(*:Stream wrapper class that automatically converts another stream (containing
   text data) into a Unicode stream. Underlying stream can contain 8-bit text
   (in any codepage) or 16-bit text (in 16-bit or UTF8 encoding).
   @author Primoz Gabrijelcic
   @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2012, Primoz Gabrijelcic
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
   Creation date    : 2001-07-17
   Last modification: 2012-03-12
   Version          : 1.10
   </pre>
*)(*
   History:
     1.10: 2012-03-12
       - Implemented TGpTextMemoryStream.
     1.09a: 2011-01-01
       - [Erik Berry] 'Size' property has changed to int64 in Delphi 6.
       - [Erik Berry] EnumLines is only compiled if compiler supports enumerators.
     1.09: 2010-07-20
       - Reversed Unicode streams were improperly read from.
     1.08: 2010-05-25
       - Implemented 'lines in a text stream' enumerator EnumLines.
     1.07: 2010-01-25
       - Implemented TGpTextStream.EOF.
       - Implemented text stream filter FilterTxt.
     1.06: 2008-05-26
       - Changed Char -> AnsiChar in preparation for the Unicode Delphi. 
     1.05: 2008-05-05
       - Exported StringToWideString, WideStringToString, and GetDefaultAnsiCodepage.
     1.04a: 2006-08-30
       - Bug fixed: When cfUseLF was set, /CR/ was used as line delimiter in Writeln (/LF/
         should be used).
     1.04: 2006-02-06
       - Added support for UCS-4 encoding in a very primitive form - all high-word values
         are stripped away on read and set to 0 on write.
       - Added CP_UNICODE32 UCS-4 pseudo-codepage constant.
     1.03: 2004-05-12
       - Added Turkish codepage ISO_8859_9.
     1.02: 2003-05-16
       - Compatible with Delphi 7.
     1.01: 2002-04-24
       - Added TGpTSCreateFlag flag tscfCompressed to keep this enum in sync
         with GpTextFile.TCreateFlag.
     1.0b: 2001-12-15
       - Updated to compile with Delphi 6 (thanks to Artem Khassanov).
     1.0a: 2001-10-06
       - Fixed error in GpTextStream.Read that could cause exception to be
         raised unnecessary.
     1.0: 2001-07-17
       - Created from GpTextFile 3.0b (thanks to Miha Remec).
       - Fix UTF 8 decoding error in TGpTextStream.Read.
*)

{$IFDEF VER100}{$DEFINE D3PLUS}{$ENDIF}
{$IFDEF VER120}{$DEFINE D3PLUS}{$DEFINE D4PLUS}{$ENDIF}
{$IFDEF VER130}{$DEFINE D3PLUS}{$DEFINE D4PLUS}{$ENDIF}
{$IFDEF CONDITIONALEXPRESSIONS}
  {$DEFINE D3PLUS}
  {$DEFINE D4PLUS}
  {$IF (RTLVersion >= 14)} // Delphi 6.0 or newer
    {$DEFINE D6PLUS}
  {$IFEND}
  {$IF (RTLVersion >= 15)} // Delphi 7.0 or newer
    {$DEFINE D7PLUS}
  {$IFEND}
  {$IF CompilerVersion >= 18} // Delphi 2006 or newer
    {$DEFINE GTS_AdvRec}
  {$IFEND}
  {$IF CompilerVersion >= 20} // Delphi 2009 or newer
    {$DEFINE GTS_Anonymous}
  {$IFEND}
{$ENDIF}

interface

uses
  Windows,
  SysUtils,
  Classes,
  GpStreamWrapper;

// HelpContext values for all raised exceptions.
const
  //:Windows error.
  hcTFWindowsError            = 3001;
  //:Unknown Windows error.
  hcTFUnknownWindowsError     = 3002;
  //:Cannot append reversed Unicode stream - not supported.
  hcTFCannotAppendReversed    = 3003;
  //:Cannot write to reversed Unicode stream - not supported.
  hcTFCannotWriteReversed     = 3004;
  //:Cannot convert odd number of bytes.
  hcTFCannotConvertOdd        = 3005;

const
{$IFNDEF D3plus}
  CP_UTF8 = 65001;    // UTF-8 pseudo-codepage, defined in Windows.pas in Delphi 3 and newer.
{$ENDIF}

  CP_UNICODE   =  1200; // Unicode UCS-2 Little-Endian pseudo-codepage
  CP_UNICODE32 = 12000; // Unicode UCS-4 Little-Endian pseudo-codepage
  ISO_8859_1 = 28591; // Western Alphabet (ISO)
  ISO_8859_2 = 28592; // Central European Alphabet (ISO)
  ISO_8859_3 = 28593; // Latin 3 Alphabet (ISO)
  ISO_8859_4 = 28594; // Baltic Alphabet (ISO)
  ISO_8859_5 = 28595; // Cyrillic Alphabet (ISO)
  ISO_8859_6 = 28596; // Arabic Alphabet (ISO)
  ISO_8859_7 = 28597; // Greek Alphabet (ISO)
  ISO_8859_8 = 28598; // Hebrew Alphabet (ISO)
  ISO_8859_9 = 28599; // Turkish Alphabet (ISO)

type
{$IFNDEF D6PLUS}
  UCS4Char = type LongWord;
{$ENDIF}

  {:Base exception class for exceptions created in TGpTextStream.
  }
  EGpTextStream = class(Exception);

  {:Text stream creation flags. Copied from GpTextFile.TCreateFlag. Must be kept
    in sync!
    @enum tscfUnicode          Create Unicode stream.
    @enum tscfReverseByteOrder Create unicode stream with reversed byte order
                               (Motorola format). Used only in Read access,
                               not valid in Write access.
    @enum tscfUse2028          Use standard /2028/ instead of /000D/000A/ for
                               line delimiter (MS Notepad and MS Word do not
                               understand $2028 delimiter). Applies to Unicode
                               streams only.
    @enum tscfUseLF            Use /LF/ instead of /CR/LF/ for line delimiter.
                               Applies to 8-bit streams only.
    @enum tscfWriteUTF8BOM     Write UTF-8 Byte Order Mark to the beginning of
                               stream.
    @enum tscfCompressed       Will try to set the "compressed" attribute (when
                               running on NT and file is on NTFS drive).
  }
  TGpTSCreateFlag = (tscfUnicode, tscfReverseByteOrder, tscfUse2028, tscfUseLF,
    tscfWriteUTF8BOM, tscfCompressed);

  {:Set of all creation flags.
  }
  TGpTSCreateFlags = set of TGpTSCreateFlag;

  {:Line delimiters.
    @enum tstsldCR       Carriage return (Mac style).
    @enum tstsldLF       Line feed (Unix style).
    @enum tstsldCRLF     Carriage return + Line feed (DOS style).
    @enum tstsldLFCR     Line feed + Carriage return (very unusual combination).
    @enum tstsld2028     /2028/ Unicode delimiter.
    @enum tstsld000D000A /000D/000A/ Windows-style Unicode delimiter.
  }
  TGpTSLineDelimiter = (tsldCR, tsldLF, tsldCRLF, tsldLFCR, tsld2028, tsld000D000A);

  {:Set of all line delimiters.
  }
  TGpTSLineDelimiters = set of TGpTSLineDelimiter;

  {:All possible ways to access TGpTextStream. Copied from GpHugeF. Must be kept
    in sync!
    @enum tstsaccRead      Read access.
    @enum tstsaccWrite     Write access.
    @enum tstsaccReadWrite Read and write access.
    @enum tstsaccAppend    Same as tsaccReadWrite, just that Position is set
                           immediatly after the end of stream.
  }
  TGpTSAccess = (tsaccRead, tsaccWrite, tsaccReadWrite, tsaccAppend);

  {:Unified 8/16-bit text stream access. All strings passed as Unicode,
    conversion to/from 8-bit is done automatically according to specified code
    page.
  }
  TGpTextStream = class(TGpStreamWrapper)
  private
    tsAccess      : TGpTSAccess;
    tsCodePage    : word;
    tsCreateFlags : TGpTSCreateFlags;
    tsLineDelims  : TGpTSLineDelimiters;
    tsReadlnBuf   : TMemoryStream;
    tsSmallBuf    : pointer;
    tsWindowsError: DWORD;
  protected
    function  AllocBuffer(size: integer): pointer; virtual;
    procedure FreeBuffer(var buffer: pointer); virtual;
    function  GetWindowsError: DWORD; virtual;
    function  IsUnicodeCodepage(codepage: word): boolean;
    procedure PrepareStream; virtual;
    procedure SetCodepage(cp: word); virtual;
    function  StreamName(param: string = ''): string; virtual;
    procedure Win32Check(condition: boolean; method: string);
  public
    constructor Create(
      dataStream: TStream; access: TGpTSAccess;
      createFlags: TGpTSCreateFlags {$IFDEF D4plus}= []{$ENDIF};
      codePage: word                {$IFDEF D4plus}= 0{$ENDIF}
      );
    destructor  Destroy; override;
    function  EOF: boolean;
    function  Is16bit: boolean;
    function  Is32bit: boolean;
    function  IsUnicode: boolean;
    function  Read(var buffer; count: longint): longint; override;
    function  Readln: WideString;
    function  Write(const buffer; count: longint): longint; override;
    function  Writeln(const ln: WideString{$IFDEF D4plus}= ''{$ENDIF}): boolean;
    function  WriteString(const ws: WideString): boolean;
    {:Accepted line delimiters (CR, LF or any combination).
    }
    property AcceptedDelimiters: TGpTSLineDelimiters read tsLineDelims
      write tsLineDelims;
    {:Code page used to convert 8-bit stream to Unicode and back. May be changed
      while stream is open (and even partially read). If set to 0, current
      default code page will be used.
    }
    property  Codepage: word read tsCodePage write SetCodepage;
    {:Stream size. Reintroduced to override GetSize (static in TStream) with
      faster version.
    }
    property  Size: {$IFDEF D6PLUS}int64{$ELSE}longint{$ENDIF D6PLUS} read GetSize write SetSize;
    {:Last Windows error code.
    }
    property  WindowsError: DWORD read GetWindowsError;
  end; { TGpTextStream }

  TGpTextMemoryStream = class(TGpTextStream)
  private
    tmsStream: TMemoryStream;
  public
    constructor Create(
      access: TGpTSAccess;
      createFlags: TGpTSCreateFlags {$IFDEF D4plus}= []{$ENDIF};
      codePage: word                {$IFDEF D4plus}= 0{$ENDIF}
      );
    destructor  Destroy; override;
    property Stream: TMemoryStream read tmsStream;
  end; { TGpTextMemoryStream }

  TGpWideString = {$IFDEF Unicode}string{$ELSE}WideString{$ENDIF};

  TGpTextStreamEnumerator = class
  private
    tseCurrent: TGpWideString;
    tseStream : TGpTextStream;
  public
    constructor Create(txtStream: TStream);
    destructor  Destroy; override;
    function  GetCurrent: TGpWideString;
    function  MoveNext: boolean;
    property Current: TGpWideString read GetCurrent;
  end; { TGpTextStreamEnumerator }

  {$IFDEF GTS_AdvRec}
  TGpTextStreamEnumeratorFactory = record
  private
    tsefStream: TStream;
  public
    constructor Create(txtStream: TStream);
    function  GetEnumerator: TGpTextStreamEnumerator;
  end; { TGpTextStreamEnumeratorFactory }
  {$ENDIF}

function StringToWideString(const s: AnsiString; codePage: word = 0): WideString;
function WideStringToString (const ws: WideString; codePage: Word = 0): AnsiString;
function GetDefaultAnsiCodepage(LangID: LCID; defCP: integer): word;

{$IFDEF GTS_AdvRec}
function EnumLines(strStream: TStream): TGpTextStreamEnumeratorFactory;
{$ENDIF}

{$IFDEF GTS_Anonymous}
type
  TFilterProc = reference to function(const srcLine: string): string;

procedure FilterTxt(srcStream, dstStream: TStream; isUnicode: boolean; filter: TFilterProc); overload;
procedure FilterTxt(srcStream, dstStream: TGpTextStream; filter: TFilterProc); overload;
{$ENDIF GTS_Anonymous}

implementation

uses
  SysConst;

const
  {:Header for 'normal' Unicode UCS-4 stream (Intel format).
  }
  CUnicode32Normal: UCS4Char = UCS4Char($0000FEFF);

  {:Header for 'reversed' Unicode UCS-4 stream (Motorola format).
  }
  CUnicode32Reversed: UCS4Char = UCS4Char($0000FFFE);

  {:Header for big-endian (Motorola) Unicode stream.
  }
  CUnicodeNormal: WideChar = WideChar($FEFF);

  {:Header for little-endian (Intel) Unicode stream.
  }
  CUnicodeReversed: WideChar = WideChar($FFFE);

  {:First two bytes of UTF-8 BOM.
  }
  CUTF8BOM12: WideChar = WideChar($BBEF);

  {:Third byte of UTF-8 BOM.
  }
  CUTF8BOM3: AnsiChar = AnsiChar($BF);

  {:Size of preallocated buffer used for 8 to 16 to 8 bit conversions in
    TGpTextStream.
  }
  CtsSmallBufSize = 2048; // 1024 WideChars

{$IFDEF D3plus}
resourcestring
{$ELSE}
const
{$ENDIF}
  sCannotAppendReversedUnicodeStream = '%s:Cannot append reversed Unicode stream.';
  sCannotConvertOddNumberOfBytes     = '%s:Cannot convert odd number of bytes: %d';
  sCannotWriteReversedUnicodeStream  = '%s:Cannot write to reversed Unicode stream.';
  sStreamFailed                      = '%s failed. ';

{:Returns Locale String.
  @param   Locale
  @param   LCType
  @returns string.
}
function GetLocaleString (Locale, LCType: DWORD): String;
var
  p: array[0..255] of Char;
begin
  if GetLocaleInfo (Locale, LCType, p, High (p)) > 0 then Result := p
  else Result := '';
end;

{:Converts Ansi string to Unicode string using specified code page.
  @param   s        Ansi string.
  @param   codePage Code page to be used in conversion.
  @returns Converted wide string.
}
function StringToWideString(const s: AnsiString; codePage: word = 0): WideString;
var
  l: integer;
begin
  if s = '' then
    Result := ''
  else begin
    if codePage = 0 then
    begin
      codepage := StrToIntDef (GetLocaleString (GetUserDefaultLCID, LOCALE_IDEFAULTANSICODEPAGE), 0);
      if codePage = 0 then
        codePage := StrToIntDef (GetLocaleString (GetSystemDefaultLCID, LOCALE_IDEFAULTANSICODEPAGE), 0);
      if codePage = 0 then
        codePage := 1252;
    end;
    l := MultiByteToWideChar(codePage, MB_PRECOMPOSED, PAnsiChar(@s[1]), -1, nil, 0);
    SetLength(Result, l-1);
    if l > 1 then
      MultiByteToWideChar(CodePage, MB_PRECOMPOSED, PAnsiChar(@s[1]), -1, PWideChar(@Result[1]), l-1);
  end;
end; { StringToWideString }

{:Converts Unicode string to Ansi string using specified code page.
  @param   ws       Unicode string.
  @param   codePage Code page to be used in conversion.
  @returns Converted ansi string.
}
function WideStringToString (const ws: WideString; codePage: Word = 0): AnsiString;
var
  l: integer;
begin
  if ws = '' then
    Result := ''
  else begin
    if codePage = 0 then
    begin
      codepage := StrToIntDef (GetLocaleString (GetUserDefaultLCID, LOCALE_IDEFAULTANSICODEPAGE), 0);
      if codePage = 0 then
        codePage := StrToIntDef (GetLocaleString (GetSystemDefaultLCID, LOCALE_IDEFAULTANSICODEPAGE), 0);
      if codePage = 0 then
        codePage := 1252;
    end;
    l := WideCharToMultiByte(codePage,
           WC_COMPOSITECHECK or WC_DISCARDNS or WC_SEPCHARS or WC_DEFAULTCHAR,
           @ws[1], -1, nil, 0, nil, nil);
    SetLength(Result, l-1);
    if l > 1 then
      WideCharToMultiByte(codePage,
        WC_COMPOSITECHECK or WC_DISCARDNS or WC_SEPCHARS or WC_DEFAULTCHAR,
        @ws[1], -1, @Result[1], l-1, nil, nil);
  end;
end; { WideStringToString }

{:Convers buffer of WideChars into UTF-8 encoded form. Target buffer must be
  pre-allocated and large enough (each WideChar will use at most three bytes
  in UTF-8 encoding).                                                            <br>
  RFC 2279 (http://www.ietf.org/rfc/rfc2279.txt) describes the conversion:       <br>
  $0000..$007F => $00..$7F                                                       <br>
  $0080..$07FF => 110[bit10..bit6] 10[bit5..bit0]                                <br>
  $0800..$FFFF => 1110[bit15..bit12] 10[bit11..bit6] 10[bit5..bit0]
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
  wc : word;

  procedure AddByte(b: byte);
  begin
    pch^ := AnsiChar(b);
    Inc(pch);
  end; { AddByte }

begin { WideCharBufToUTF8Buf }
  pwc := @unicodeBuf;
  pch := @utf8Buf;
  for iwc := 1 to uniByteCount div SizeOf(WideChar) do begin
    wc := Ord(pwc^);
    Inc(pwc);
    if (wc >= $0001) and (wc <= $007F) then begin
      AddByte(wc AND $7F);
    end
    else if (wc >= $0080) and (wc <= $07FF) then begin
      AddByte($C0 OR ((wc SHR 6) AND $1F));
      AddByte($80 OR (wc AND $3F));
    end
    else begin // (wc >= $0800) and (wc <= $FFFF)
      AddByte($E0 OR ((wc SHR 12) AND $0F));
      AddByte($80 OR ((wc SHR 6) AND $3F));
      AddByte($80 OR (wc AND $3F));
    end;
  end; //for
  Result := integer(pch)-integer(@utf8Buf);
end; { WideCharBufToUTF8Buf }

{:Converts UTF-8 encoded buffer into WideChars. Target buffer must be
  pre-allocated and large enough (at most utfByteCount number of WideChars will
  be generated).                                                                 <br>
  RFC 2279 (http://www.ietf.org/rfc/rfc2279.txt) describes the conversion:       <br>
  $00..$7F => $0000..$007F                                                       <br>
  110[bit10..bit6] 10[bit5..bit0] => $0080..$07FF                                <br>
  1110[bit15..bit12] 10[bit11..bit6] 10[bit5..bit0] => $0800..$FFFF
  @param   utf8Buf      UTF-8 encoded buffer.
  @param   utfByteCount Size of utf8Buf, in bytes.
  @param   unicodeBuf   Pre-allocated buffer for WideChars.
  @param   leftUTF8     Number of bytes left in utf8Buf after conversion (0, 1,
                        or 2).
  @returns Number of bytes used in unicodeBuf buffer.
  @since   2.01
}
function UTF8BufToWideCharBuf(const utf8Buf; utfByteCount: integer;
 var unicodeBuf; var leftUTF8: integer): integer;
var
  c1 : byte;
  c2 : byte;
  ch : byte;
  pch: PAnsiChar;
  pwc: PWideChar;
begin
  pch := @utf8Buf;
  pwc := @unicodeBuf;
  leftUTF8 := utfByteCount;
  while leftUTF8 > 0 do begin
    ch := byte(pch^);
    Inc(pch);
    if (ch AND $80) = 0 then begin // 1-byte code
      word(pwc^) := ch;
      Inc(pwc);
      Dec(leftUTF8);
    end
    else if (ch AND $E0) = $C0 then begin // 2-byte code
      if leftUTF8 < 2 then
        break;
      c1 := byte(pch^);
      Inc(pch);
      word(pwc^) := (word(ch AND $1F) SHL 6) OR (c1 AND $3F);
      Inc(pwc);
      Dec(leftUTF8,2);
    end
    else begin // 3-byte code
      if leftUTF8 < 3 then
        break;
      c1 := byte(pch^);
      Inc(pch);
      c2 := byte(pch^);
      Inc(pch);
      word(pwc^) :=
        (word(ch AND $0F) SHL 12) OR
        (word(c1 AND $3F) SHL 6) OR
        (c2 AND $3F);
      Inc(pwc);
      Dec(leftUTF8,3);
    end;
  end; //while
  Result := integer(pwc)-integer(@unicodeBuf);
end; { UTF8BufToWideCharBuf }

{:Returns default Ansi codepage for LangID or 'defCP' in case of error (LangID
  does not specify valid language ID).
  @param   LangID Language ID.
  @param   defCP  Default value that is to be returned if LangID doesn't specify
                  a valid language ID.
  @returns Default Ansi codepage for LangID or 'defCP' in case of error.
}
function GetDefaultAnsiCodepage(LangID: LCID; defCP: integer): word;
var
  p: array [0..255] of char;
begin
  if GetLocaleInfo(LangID, 4100, p, High (p)) > 0 then
    Result := StrToIntDef(p,defCP)
  else
    Result := defCP;
end; { GetDefaultAnsiCodepage }

{$IFDEF GTS_AdvRec}
function EnumLines(strStream: TStream): TGpTextStreamEnumeratorFactory;
begin
  Result := TGpTextStreamEnumeratorFactory.Create(strStream);
end; { EnumLines }
{$ENDIF}

{$IFDEF GTS_Anonymous}
procedure FilterTxt(srcStream, dstStream: TStream; isUnicode: boolean; filter: TFilterProc);
var
  dstText: TGpTextStream;
  flags  : TGpTSCreateFlags;
  srcText: TGpTextStream;
begin
  flags := [];
  if isUnicode then
    flags := [tscfUnicode];
  srcText := TGpTextStream.Create(srcStream, tsaccRead, flags);
  try
    dstText := TGpTextStream.Create(dstStream, tsaccWrite, flags);
    try
      FilterTxt(srcText, dstText, filter);
    finally FreeAndNil(dstText); end;
  finally FreeAndNil(srcText); end;
end; { FilterTxt }

procedure FilterTxt(srcStream, dstStream: TGpTextStream; filter: TFilterProc);
begin
  while not srcStream.EOF do
    dstStream.Writeln(filter(srcStream.Readln));
end; { FilterTxt }
{$ENDIF GTS_Anonymous}

{ TGpTextStream }

{:Allocates buffer for 8/16/8 bit conversions. If requested size is small
  enough, returns pre-allocated buffer, otherwise allocates new buffer.
  @param   size Requested size in bytes.
  @returns Pointer to buffer.
}
function TGpTextStream.AllocBuffer(size: integer): pointer;
begin
  if size <= CtsSmallBufSize then
    Result := tsSmallBuf
  else
    GetMem(Result,size);
end; { TGpTextStream.AllocBuffer }

{:Initializes stream and opens it in required access mode.
  @param   dataStream  Wrapped (physical) stream used for data access.
  @param   access      Required access mode.
  @param   openFlags   Open flags (used when access mode is accReset).
  @param   createFlags Create flags (used when access mode is accRewrite or
                       tsaccAppend).
  @param   codePage    Code page to be used for 8/16/8 bit conversions. If set
                       to 0, current default code page will be used.
}
constructor TGpTextStream.Create(dataStream: TStream;
  access: TGpTSAccess; createFlags: TGpTSCreateFlags; codePage: word);
begin
  inherited Create(dataStream);
  if (tscfUnicode in createFlags) and (codePage <> CP_UTF8) and (codePage <> CP_UNICODE32) then
    codePage := CP_UNICODE;
  tsAccess := access;
  tsCreateFlags := createFlags;
  SetCodepage(codePage);
  GetMem(tsSmallBuf,CtsSmallBufSize);
  PrepareStream;
end; { TGpTextStream.Create }

{:Cleanup. 
}
destructor TGpTextStream.Destroy;
begin
  FreeMem(tsSmallBuf);
  tsReadlnBuf.Free;
  tsReadlnBuf := nil;
  inherited Destroy;
end; { TGpTextStream.Destroy }

function TGpTextStream.EOF: boolean;
begin
  Result := (Position >= Size);
end; { TGpTextStream.EOF }

{:Frees buffer for 8/16/8 bit conversions. If pre-allocated buffer is passed,
  nothing will be done.
  @param   buffer Conversion buffer.
}
procedure TGpTextStream.FreeBuffer(var buffer: pointer);
begin
  if buffer <> tsSmallBuf then begin
    FreeMem(buffer);
    buffer := nil;
  end;
end; { TGpTextStream.FreeBuffer }

{:Checks if stream is 16-bit Unicode.
  @returns True if stream is 16-bit Unicode.
  @since   2.01
}
function TGpTextStream.GetWindowsError: DWORD;
begin
  if tsWindowsError <> 0 then
    Result := tsWindowsError
  else
    Result := 0;
end; { TGpTextStream.GetWindowsError }

{:Checks if stream contains 16-bit characters.
}
function TGpTextStream.Is16bit: boolean;
begin
  Result := IsUnicode and (Codepage = CP_UNICODE);
end; { TGpTextStream.Is16bit }

{:Checks if stream contains 32-bit characters.
}
function TGpTextStream.Is32bit: boolean;
begin
  Result := IsUnicode and (Codepage = CP_UNICODE32);
end; { TGpTextStream.Is32bit }

{:Checks if stream is Unicode (UTF-8 or UCS-2 or UCS-4 encoding).
  @returns True if stream is Unicode.
}
function TGpTextStream.IsUnicode: boolean;
begin
  Result := (tscfUnicode in tsCreateFlags);
end; { TGpTextStream.IsUnicode }

{:Checks is codepage is one of the supported Unicode codepages.
  @since   2006-02-06
}
function TGpTextStream.IsUnicodeCodepage(codepage: word): boolean;
begin
  Result := (codepage = CP_UTF8) or (codepage = CP_UNICODE) or (codepage = CP_UNICODE32);
end; { TGpTextStream.IsUnicodeCodepage }

{:Prepares stream for read or write operation.
  @raises EGpTextStream if caller tries to rewrite or append 'reverse'
          Unicode stream.
}
procedure TGpTextStream.PrepareStream;
var
  marker : WideChar;
  marker3: AnsiChar;
  marker4: UCS4Char;
begin
  case tsAccess of
    tsaccRead:
      begin
        tsCreateFlags := [];
        if WrappedStream.Size >= SizeOf(UCS4Char) then begin
          WrappedStream.Position := 0;
          WrappedStream.Read(marker4, SizeOf(UCS4Char));
          if marker4 = CUnicode32Normal then begin
            tsCreateFlags := tsCreateFlags + [tscfUnicode];
            Codepage := CP_UNICODE32;
          end
          else if marker4 = CUnicode32Reversed then begin
            tsCreateFlags := tsCreateFlags + [tscfUnicode, tscfReverseByteOrder];
            Codepage := CP_UNICODE32;
          end;
        end;
        if (WrappedStream.Size >= SizeOf(WideChar)) and (Codepage <> CP_UNICODE32) then begin
          WrappedStream.Position := 0;
          WrappedStream.Read(marker, SizeOf(WideChar));
          if marker = CUnicodeNormal then begin
            tsCreateFlags := tsCreateFlags + [tscfUnicode];
            Codepage := CP_UNICODE;
          end
          else if marker = CUnicodeReversed then begin
            tsCreateFlags := tsCreateFlags + [tscfUnicode, tscfReverseByteOrder];
            Codepage := CP_UNICODE;
          end
          else if (marker = CUTF8BOM12) and (WrappedStream.Size >= 3) then begin
            WrappedStream.Read(marker3, SizeOf(AnsiChar));
            if marker3 = CUTF8BOM3 then begin
              tsCreateFlags := tsCreateFlags + [tscfUnicode];
              Codepage := CP_UTF8;
            end;
          end;
        end;
        if not IsUnicode then
          WrappedStream.Position := 0;
        if (not IsUnicode) and IsUnicodeCodepage(Codepage) then
          tsCreateFlags := [tscfUnicode];
      end; //tsaccRead
    tsaccWrite:
      begin
        if IsUnicodeCodepage(Codepage) then
          tsCreateFlags := tsCreateFlags + [tscfUnicode];
        if tsCreateFlags * [tscfUnicode, tscfReverseByteOrder] = [tscfUnicode, tscfReverseByteOrder] then
          raise EGpTextStream.CreateFmtHelp(sCannotWriteReversedUnicodeStream, [StreamName], hcTFCannotWriteReversed);
        WrappedStream.Size := 0;
        if IsUnicode then begin
          if Codepage = CP_UNICODE32 then
            WrappedStream.Write(CUnicode32Normal,SizeOf(UCS4Char))
          else if Codepage <> CP_UTF8 then
            WrappedStream.Write(CUnicodeNormal,SizeOf(WideChar))
          else if tscfWriteUTF8BOM in tsCreateFlags then begin
            WrappedStream.Write(CUTF8BOM12,SizeOf(WideChar));
            WrappedStream.Write(CUTF8BOM3,SizeOf(AnsiChar));
          end;
        end;
      end; //tsaccWrite
    tsaccReadWrite:
      begin
        if IsUnicodeCodepage(Codepage) then
          tsCreateFlags := tsCreateFlags + [tscfUnicode];
        if tsCreateFlags * [tscfUnicode, tscfReverseByteOrder] = [tscfUnicode, tscfReverseByteOrder] then
          raise EGpTextStream.CreateFmtHelp(sCannotAppendReversedUnicodeStream, [StreamName], hcTFCannotAppendReversed);
        if (WrappedStream.Size = 0) and IsUnicode then begin
          if Codepage = CP_UNICODE32 then
            WrappedStream.Write(CUnicode32Normal,SizeOf(UCS4Char))
          else if Codepage <> CP_UTF8 then
            WrappedStream.Write(CUnicodeNormal,SizeOf(WideChar))
          else if tscfWriteUTF8BOM in tsCreateFlags then begin
            WrappedStream.Write(CUTF8BOM12,SizeOf(WideChar));
            WrappedStream.Write(CUTF8BOM3,SizeOf(AnsiChar));
          end;
        end;
      end; //tsaccReadWrite
    tsaccAppend:
      begin
        tsCreateFlags := [];
        if WrappedStream.Size >= SizeOf(UCS4Char) then begin
          WrappedStream.Position := 0;
          WrappedStream.Read(marker4, SizeOf(UCS4Char));
          if marker4 = CUnicode32Normal then begin
            tsCreateFlags := tsCreateFlags + [tscfUnicode];
            Codepage := CP_UNICODE32;
          end
          else if marker4 = CUnicode32Reversed then begin
            tsCreateFlags := tsCreateFlags + [tscfUnicode, tscfReverseByteOrder];
            Codepage := CP_UNICODE32;
          end;
        end;
        if (WrappedStream.Size >= SizeOf(WideChar)) and (Codepage <> CP_UNICODE32) then begin
          WrappedStream.Position := 0;
          WrappedStream.Read(marker,SizeOf(WideChar));
          if marker = CUnicodeNormal then begin
            tsCreateFlags := tsCreateFlags + [tscfUnicode];
            Codepage := CP_UNICODE;
          end
          else if marker = CUnicodeReversed then begin
            tsCreateFlags := tsCreateFlags + [tscfUnicode,tscfReverseByteOrder];
            Codepage := CP_UNICODE;
          end
          else if (marker = CUTF8BOM12) and (WrappedStream.Size >= 3) then begin
            WrappedStream.Read(marker3,SizeOf(AnsiChar));
            if marker3 = CUTF8BOM3 then begin
              tsCreateFlags := tsCreateFlags + [tscfUnicode];
              Codepage := CP_UTF8;
            end;
          end;
        end
        else if (WrappedStream.Size = 0) and IsUnicode then begin
          if Codepage <> CP_UTF8 then
            WrappedStream.Write(CUnicodeNormal,SizeOf(WideChar))
          else if tscfWriteUTF8BOM in tsCreateFlags then begin
            WrappedStream.Write(CUTF8BOM12,SizeOf(WideChar));
            WrappedStream.Write(CUTF8BOM3,SizeOf(AnsiChar));
          end;
        end;
        WrappedStream.Position := WrappedStream.Size;
        if (not IsUnicode) and IsUnicodeCodepage(Codepage) then
          tsCreateFlags := tsCreateFlags + [tscfUnicode];
        if tsCreateFlags * [tscfUnicode, tscfReverseByteOrder] = [tscfUnicode, tscfReverseByteOrder] then
          raise EGpTextStream.CreateFmtHelp(sCannotAppendReversedUnicodeStream,[StreamName],hcTFCannotAppendReversed);
      end; //tsaccAppend
  end; //case
end; { TGpTextStream.PrepareStream }

{:Reads 'count' number of bytes from stream. 'Count' must be an even number as
  data is always returned in Unicode format (two bytes per character).
  If stream is 8-bit, data is converted to Unicode according to code page specified in
  constructor.
  If stream is 32-bit, high-order word of every UCS-4 char is stripped away.
  @param   buffer Buffer for read data.
  @param   count  Number of bytes to be read.
  @returns Number of bytes actually read.
  @raises  EGpTextStream if 'count' is odd.
  @raises  EGpTextStream if conversion from 8-bit to Unicode failes.
}
function TGpTextStream.Read(var buffer; count: longint): longint;
var
  bufPtr   : PByte;
  bytesConv: integer;
  bytesLeft: integer;
  bytesRead: integer;
  numChar  : integer;
  tmpBuf   : pointer;
  tmpPtr   : PByte;
begin
  DelayedSeek;
  if IsUnicode then begin
    if Codepage = CP_UTF8 then begin
      numChar := count div SizeOf(WideChar);
      tmpBuf := AllocBuffer(numChar);
      try
        bufPtr := @buffer;
        Result := 0;
        bytesLeft := 0;
        repeat
          // at least numChar UTF-8 bytes are needed for numChar WideChars
          bytesRead := WrappedStream.Read(pointer(integer(tmpBuf)+bytesLeft)^, numChar);
          bytesConv := UTF8BufToWideCharBuf(tmpBuf^, bytesRead+bytesLeft, bufPtr^, bytesLeft);
          Result := Result + bytesConv;
          if bytesRead <> numChar then // end of stream
            break;
          numChar := numChar - (bytesConv div SizeOf(WideChar));
          Inc(bufPtr, bytesConv);
          if (bytesLeft > 0) and (bytesLeft < bytesRead) then
            Move(pointer(integer(tmpBuf)+bytesRead-bytesLeft)^, tmpBuf^, bytesLeft);
        until numChar = 0;
      finally FreeBuffer(tmpBuf); end;
    end
    else if Codepage = CP_UNICODE32 then begin
      tmpBuf := AllocBuffer(count*2);
      try
        Result := WrappedStream.Read(tmpBuf^, count*2) div 2;
        bufPtr := @buffer;
        tmpPtr := tmpBuf;
        for bytesRead := 1 to Result div 2 do begin
          PWord(bufPtr)^ := PWord(tmpPtr)^;
          Inc(tmpPtr, SizeOf(WideChar)*2);
          Inc(bufPtr, SizeOf(WideChar));
        end;
      finally FreeBuffer(tmpBuf); end;
    end
    else
      Result := WrappedStream.Read(buffer, count);
  end
  else begin
    if Odd(count) then
      raise EGpTextStream.CreateFmtHelp(sCannotConvertOddNumberOfBytes,
        [StreamName, count], hcTFCannotConvertOdd)
    else begin
      numChar := count div SizeOf(WideChar);
      tmpBuf := AllocBuffer(numChar);
      try
        bytesRead := WrappedStream.Read(tmpBuf^,numChar);
        numChar := MultiByteToWideChar(tsCodePage, MB_PRECOMPOSED,
          PAnsiChar(tmpBuf), bytesRead, PWideChar(@buffer), numChar);
        Result := numChar * SizeOf(WideChar);
      finally FreeBuffer(tmpBuf); end;
    end;
  end;
end; { TGpTextStream.Read }

{:Reads one text line stream. If stream is 8-bit, LF, CR, CRLF, and LFCR are
  considered end-of-line terminators (if included in AcceptedDelimiters). If
  stream is 16-bit, both /000D/000A/ and /2028/ are considered end-of-line
  terminators (if included in AcceptedDelimiters). If stream is 8-bit, line is
  converted to Unicode according to code page specified in constructor.
  <b>This function is quite slow.</b>
  @returns One line of text.
  @raises  EGpTextStream if conversion from 8-bit to Unicode failes.
}
function TGpTextStream.Readln: WideString;
var
  lastCh  : WideChar;
  numCh   : integer;
  wch     : WideChar;

  function Reverse(w: word): word;
  var
    tmp: byte;
  begin
    if tscfReverseByteOrder in tsCreateFlags then begin
      tmp := WordRec(Result).Hi;
      WordRec(Result).Hi := WordRec(w).Lo;
      WordRec(Result).Lo := tmp;
    end
    else
      Result := w;
  end; { Readln }

  procedure ReverseResult;
  var
    ich: integer;
    pwc: PWord;
    tmp: byte;
  begin
    if tscfReverseByteOrder in tsCreateFlags then begin
      pwc := @Result[1];
      for ich := 1 to Length(Result) do begin
        tmp := WordRec(pwc^).Hi;
        WordRec(pwc^).Hi := WordRec(pwc^).Lo;
        WordRec(pwc^).Lo := tmp;
        Inc(pwc);
      end; //for
    end;
  end; { ReverseBlock }

begin { TGpTextStream.Readln }
  if assigned(tsReadlnBuf) then
    tsReadlnBuf.Clear
  else
    tsReadlnBuf := TMemoryStream.Create;
  lastCh := #0;
  numCh := 0;
  repeat
    if Read(wch,SizeOf(WideChar)) <> SizeOf(WideChar) then
      break; // EOF
    if (((AcceptedDelimiters = []) or ([tsldLF, tsldCRLF]*AcceptedDelimiters <> [])) or
        (IsUnicode and ((AcceptedDelimiters = []) or (tsld000D000A in AcceptedDelimiters)))) and
       (wch = WideChar(Reverse($000A))) then begin
      if (((AcceptedDelimiters = []) or ([tsldLFCR]*AcceptedDelimiters <> [])) or
          (IsUnicode and ((AcceptedDelimiters = []) or (tsld000D000A in AcceptedDelimiters)))) and
         (lastCh = WideChar(Reverse($000D))) then
        numCh := 1;
      break;
    end
    else if (([tsldCR, tsldLFCR]*AcceptedDelimiters <> [])) and
             (wch = WideChar(Reverse($000D))) then begin
      if (([tsldLFCR]*AcceptedDelimiters <> [])) and
          (lastCh = WideChar(Reverse($000A))) then
        numCh := 1;
      break;
    end
    else if IsUnicode and
            ((AcceptedDelimiters = []) or (tsld2028 in AcceptedDelimiters)) and
            (wch = WideChar(Reverse($2028))) then
      break;
    tsReadlnBuf.Write(wch,SizeOf(WideChar));
    lastCh := wch;
  until false;
  SetLength(Result,(tsReadlnBuf.Size-numCh*SizeOf(WideChar)) div SizeOf(WideChar));
  if Result <> '' then
    Move(tsReadlnBuf.Memory^,Result[1],tsReadlnBuf.Size-numCh*SizeOf(WideChar));
  ReverseResult;
end; { TGpTextStream.Readln }

{:Internal method that sets current code page or locates default code page if
  0 is passed as a parameter.
  @param   cp Code page number or 0 for default code page.
}
procedure TGpTextStream.SetCodepage(cp: word);
begin
  if (cp = CP_UTF8) or (cp = CP_UNICODE) or (cp = CP_UNICODE32) then begin
    tsCodePage := cp;
    tsCreateFlags := tsCreateFlags + [tscfUnicode];
  end
  else begin
    if (cp = 0) and (not IsUnicode) then
      tsCodePage := GetDefaultAnsiCodepage(GetKeyboardLayout(GetCurrentThreadId) and $FFFF, 1252)
    else
      tsCodePage := cp;
    if not ((tsCodePage = 0) or IsUnicodeCodepage(tsCodePage)) then
      tsCreateFlags := tsCreateFlags - [tscfUnicode];
  end;
end; { TGpTextStream.SetCodepage }

{:Returns error message prefix.
  @param   param Optional parameter to be added to the message prefix.
  @returns Error message prefix.
  @since   2001-05-15 (3.0)
}
function TGpTextStream.StreamName(param: string): string;
begin
  Result := 'TGpTextStream';
  if param <> '' then
    Result := Result + '.' + param;
end; { TGpTextStream.StreamName }

{:Checks condition and creates appropriately formatted EGpTextStream
  exception.
  @param   condition If false, Win32Check will generate an exception.
  @param   method    Name of TGpTextStream method that called Win32Check.
  @raises  EGpTextStream if (not condition).
}
procedure TGpTextStream.Win32Check(condition: boolean; method: string);
var
  Error: EGpTextStream;
begin
  if not condition then begin
    tsWindowsError := GetLastError;
    if tsWindowsError <> ERROR_SUCCESS then
      Error := EGpTextStream.CreateFmtHelp(sStreamFailed+
        {$IFNDEF D6PLUS}SWin32Error{$ELSE}SOSError{$ENDIF},
        [StreamName(method),tsWindowsError,SysErrorMessage(tsWindowsError)],
        hcTFWindowsError)
    else
      Error := EGpTextStream.CreateFmtHelp(sStreamFailed+
        {$IFNDEF D6PLUS}SUnkWin32Error{$ELSE}SUnkOSError{$ENDIF},
        [StreamName(method)],hcTFUnknownWindowsError);
    raise Error;
  end;
end; { TGpTextStream.Win32Check }

{:Writes 'count' number of bytes to stream. 'Count' must be an even number as
  data is always expected in Unicode format (two bytes per character).
  If stream is 8-bit, data is converted from Unicode according to code page specified in
  constructor.
  If stream is 32-bit, high-order word of every UCS-4 char is set to 0.
  @param   buffer Data to be written.
  @param   count  Number of bytes to be written.
  @returns Number of bytes actually written.
  @raises  EGpTextStream if 'count' is odd.
  @raises  EGpTextStream if conversion from 8-bit to Unicode failes.
}
function TGpTextStream.Write(const buffer; count: longint): longint;
var
  bufPtr    : PByte;
  leftUTF8  : integer;
  numBytes  : integer;
  numChar   : integer;
  tmpBuf    : pointer;
  tmpPtr    : PByte;
  uniBuf    : pointer;
  utfWritten: integer;
begin
  DelayedSeek;
  if IsUnicode then begin
    if Codepage = CP_UTF8 then begin
      numChar := count div SizeOf(WideChar);
      tmpBuf := AllocBuffer(numChar*3); // worst case - 3 bytes per character
      try
        numBytes := WideCharBufToUTF8Buf(buffer,count,tmpBuf^);
        utfWritten := WrappedStream.Write(tmpBuf^,numBytes);
        if utfWritten <> numBytes then begin
          Result := 0; // to keep Delphi from complaining
          // To find out how much data was actually written (in term of Unicode
          // characters) we have to decode written data back to Unicode. Ouch.
          GetMem(uniBuf,count); // decoded data cannot use more space than original Unicode data
          try
            Result := UTF8BufToWideCharBuf(tmpBuf^,Result,uniBuf^,leftUTF8);
          finally FreeMem(uniBuf); end;
        end
        else // everything was written
          Result := count;
      finally FreeBuffer(tmpBuf); end;
    end
    else if Codepage = CP_UNICODE32 then begin
      tmpBuf := AllocBuffer(count*2);
      try
        bufPtr := @buffer;
        tmpPtr := tmpBuf;
        for utfWritten := 1 to count div SizeOf(WideChar) do begin
          PWideChar(tmpPtr)^ := PWideChar(bufPtr)^;
          Inc(tmpPtr, SizeOf(WideChar));
          Inc(bufPtr, SizeOf(WideChar));
          PWord(tmpPtr)^ := 0;
          Inc(tmpPtr, SizeOf(WideChar));
        end;
        Result := WrappedStream.Write(tmpBuf^, count*2) div 2;
      finally FreeBuffer(tmpBuf); end;
    end
    else
      Result := WrappedStream.Write(buffer, count);
  end
  else begin
    if Odd(count) then
      raise EGpTextStream.CreateFmtHelp(sCannotConvertOddNumberOfBytes,[StreamName,count],hcTFCannotConvertOdd)
    else begin
      numChar := count div SizeOf(WideChar);
      tmpBuf := AllocBuffer(numChar);
      try
        numChar := WideCharToMultiByte(tsCodePage,
          WC_COMPOSITECHECK or WC_DISCARDNS or WC_SEPCHARS or WC_DEFAULTCHAR,
          @buffer, numChar, tmpBuf, numChar, nil, nil);
        Win32Check(numChar <> 0,'Write');
        Result := WrappedStream.Write(tmpBuf^,numChar) * SizeOf(WideChar);
      finally FreeBuffer(tmpBuf); end;
    end;
  end;
end; { TGpTextStream.Write }

{:Writes string to stream and terminates it with line delimiter (as set in
  constructor). If stream is 8-bit, data is converted from Unicode according to
  code page specified in constructor.
  @param   ln String to be written.
  @returns True if string was written successfully.
  @raises  EGpTextStream if conversion from 8-bit to Unicode failes.
}
function TGpTextStream.Writeln(const ln: WideString): boolean;
var
  ch: AnsiChar;
  wc: WideChar;
begin
  if ln <> '' then begin
    if not WriteString(ln) then begin
      Result := false;
      Exit;
    end;
  end;
  if IsUnicode then begin
    if tscfUse2028 in tsCreateFlags then begin
      wc := WideChar($2028);
      Result := (Write(wc,SizeOf(WideChar)) = SizeOf(WideChar));
    end
    else begin
      wc := WideChar($000D);
      Result := (Write(wc,SizeOf(WideChar)) = SizeOf(WideChar));
      if Result then begin
        wc := WideChar($000A);
        Result := (Write(wc,SizeOf(WideChar)) = SizeOf(WideChar));
      end;
    end;
  end
  else begin
    if tscfUseLF in tsCreateFlags then begin
      ch := AnsiChar($0A);
      Result := (WrappedStream.Write(ch,SizeOf(AnsiChar)) = SizeOf(AnsiChar));
    end
    else begin
      ch := AnsiChar($0D);
      Result := (WrappedStream.Write(ch,SizeOf(AnsiChar)) = SizeOf(AnsiChar));
      if Result then begin
        ch := AnsiChar($0A);
        Result := (WrappedStream.Write(ch,SizeOf(AnsiChar)) = SizeOf(AnsiChar));
      end;
    end;
  end;
end; { TGpTextStream.Writeln }

{:Writes string to stream. If stream is 8-bit, data is converted from Unicode
  according to code page specified in constructor.
  @param   ws String to be written.
  @returns True if string was written successfully.
  @raises  EGpTextStream if conversion from 8-bit to Unicode failes.
}
function TGpTextStream.WriteString(const ws: WideString): boolean;
begin
  if ws <> '' then
    Result := (Write(ws[1],Length(ws)*SizeOf(WideChar)) = Length(ws)*SizeOf(WideChar))
  else
    Result := true;
end; { TGpTextStream.WriteString }

{ TGpTextMemoryStream }

constructor TGpTextMemoryStream.Create(access: TGpTSAccess; createFlags: TGpTSCreateFlags;
  codePage: word);
begin
  tmsStream := TMemoryStream.Create;
  inherited Create(tmsStream, access, createFlags, codePage);
end; { TGpTextMemoryStream.Create }

destructor TGpTextMemoryStream.Destroy;
begin
  inherited;
  FreeAndNil(tmsStream);
end; { TGpTextMemoryStream.Destroy }

{$IFDEF GTS_AdvRec}
{ TGpTextStreamEnumeratorFactory }

constructor TGpTextStreamEnumeratorFactory.Create(txtStream: TStream);
begin
  tsefStream := txtStream;
end; { TGpTextStreamEnumeratorFactory.Create }

function TGpTextStreamEnumeratorFactory.GetEnumerator: TGpTextStreamEnumerator;
begin
  Result := TGpTextStreamEnumerator.Create(tsefStream);
end; { TGpTextStreamEnumeratorFactory.GetEnumerator }
{$ENDIF}

{ TGpTextStreamEnumerator }

constructor TGpTextStreamEnumerator.Create(txtStream: TStream);
begin
  inherited Create;
  tseStream := TGpTextStream.Create(txtStream, tsaccRead);
end; { TGpTextStreamEnumerator.Create }

destructor TGpTextStreamEnumerator.Destroy;
begin
  FreeAndNil(tseStream);
  inherited;
end; { TGpTextStreamEnumerator }

function TGpTextStreamEnumerator.GetCurrent: TGpWideString;
begin
  Result := tseCurrent;
end; { TGpTextStreamEnumerator.GetCurrent }

function TGpTextStreamEnumerator.MoveNext: boolean;
begin
  Result := not tseStream.EOF;
  if Result then
    tseCurrent := tseStream.Readln;
end; { TGpTextStreamEnumerator.MoveNext }

end.
