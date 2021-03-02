{$B-,H+,J+,Q-,T-,X+}

unit GpTextFile;

(*:Interface to 8/16-bit text files and streams. Uses GpHugeF unit for file access.
   @author Primoz Gabrijelcic
   @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2020, Primoz Gabrijelcic
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
   Creation date    : 1999-11-01
   Last modification: 2020-12-11
   Version          : 4.09
   Requires         : GpHugeF 4.0, GpTextStream 1.13
   </pre>
*)(*
   History:
     4.09: 2020-12-11
       - Added an option ofScanEntireFile to scan the complete file when checking for UTF-8.
         Cannot be used together with ofCloseOnEOF, in which case an exception is raised.
     4.08: 2020-12-10
       - IsUTF8 returns true only if a valid UTF8 character was found.
     4.07: 2020-07-31
       - Create flag cfUseLF works for Unicode files.
     4.06: 2020-02-12
       - Implemented open flag ofJSON which autodetects the format of a Unicode
         JSON stream. (UTF-8, UTF-16 LE/BE, UTF-32 LE/BE; all with/without a BOM).
       - Fixed reading from UTF-32 BE streams.
     4.05: 2020-01-29
       - Extended TGpTextFileStream constructor with parameters that are passed
         straight to the TGpHugeFileStream constructor.
       - Implemented TGpTextFileStream.CreateFromHandle.
     4.04: 2017-11-29
       - TGpTextFile.Reset will try to detect whether the file is in UTF-8 format if
         there is no BOM and ofNotUTF8Autodetect TOpenFlag is not set. [#1551]
     4.03a: 2012-10-11
       - TGpTextFile.Write accepts vtUnicodeString.
     4.03: 2010-11-26
       - Unicode files recognize /000A/000D/, /000D/, and /000A/ line delimiters.
       - Unicode files respect ldCR, ldLF, ldCRLF, and ldLFCR AcceptedDelimiter values.
     4.02: 2009-02-16
       - Compatible with Delphi 2009.
     4.01: 2008-10-02
       - Added TGpTextFile.Write(ws: WideString) and TGpTextFile.Writeln(s: string)
         overloads.
       - TGpTextFile.Write[ln] string parameters made 'const'.
       - Bug fixed [found by AKi]: TGpTextFile.Write was not working when using CP_UTF8
         codepage.
     4.0a: 2006-08-30
       - Bug fixed [found by Brian D. Ogilvie]: When cfUseLF was set, /CR/ was used as
         line delimiter in Writeln (/LF/ should be used).
     4.0: 2006-08-14
       - TGpTextFileStream
         - Added new constructor CreateW that uses Unicode encoding for the file name.
         - FileName property changed to WideString.
     3.07a: 2006-03-30
       - Release 3.07 introduced an 'interesting' bug - when file size modulo 2048 was in
         range 1..5, some garbage was generated after last line of file (when reading the
         file with Readln).
     3.07: 2006-02-06
       - Added support for UCS-4 encoding in a very primitive form - all high-word values
         are stripped away on read and set to 0 on write.
     3.06: 2005-12-22
       - File flags exposed through the readonly FileFlags property.
       - Fixed minor memory leak in Rewrite[Safe].
     3.05b: 2005-10-26
       - Opening existing file in UTF8 was completely broken.
     3.05a: 2004-07-16
       - Bug fixed: If Append was called with the [cfUnicode] flag and file did not exist
         before the call, Unicode marker was not written to the newly created file.
     3.05: 2003-05-16
       - Made Delphi 7 compatible.
     3.04c: 2002-11-26
       - Fixed reading of LF-delimited files (broken since 3.04).
     3.04b: 2002-10-16
       - Fixed lots of problems with TGPTextFile.Readln.
     3.04a: 2002-10-15
       - Fixed TGpTextFile.EOF (broken in 3.04).
     3.04: 2002-10-11
       - Faster (two to three times) TGpTextFile.Readln.
       - Faster (10% to 50%) TGpTextFile.Writeln.
     3.03: 2002-06-30
       - Added ofNo8BitCPConversion to TOpenFlags. If set Readln will not perform codepage
         conversion to Unicode on 8 bit text files.
       - Added cfNo8BitCPConversion to TCreateFlags. If set Writeln will not perform
         codepage conversion from Unicode on 8 bit text files.
       - Added public functions StringToWideStringNoCP and WideStringToStringNoCP.
     3.02: 2002-04-24
       - Added TCreateFlag cfCompressed.
     3.01a: 2001-12-15
       - Updated to compile with Delphi 6.
     3.01: 2001-07-17
       - TGpTextStream class moved into a separate unit (GpTextStream).
     3.0b: 2001-06-22
       - WriteString was not always returning a value. Fixed.
     3.0a: 2001-06-18
       - Bug fixed: function WriteString crashed if its argument was empty string.
     3.0: 2001-05-15
       - TGpTextFileStream class split into two classes. Basic functionality (Unicode
         encoding/decoding) was moved into TGpTextStream that can work on any TStream
         descendant. TGpTextFileStream now only opens the file and forwards it to the
         TGpTextStream.
     2.06: 2001-03-22
       - Added overloaded TGpTextFile.Write(s: string), available on D4 and better.
     2.05: 2001-02-27
       - Added property AcceptedDelimiters to TGpTextFile and TGpTextFileStream. You can
         use it do specify what CR-LF combinations should be treated as a line delimiter.
         If not set (or set to []), classes will behave as before - TGpTextFile will use
         CR, LF, CRLF, /2028/, and /000D/000A/ for line delimiters and TGpTextFileStream
         will use LF, CRLF, /2028/, and /000D/000A/ for line delimiters.
     2.04: 2001-01-31
       - All raised exceptions now have HelpContext set. All possible HelpContext values
         are enumerated in 'const' section at the very beginning of the unit. Thanks to
         Peter Evans for the suggestion.
       - TGpTextFileStream.Win32Check made protected (was public by mistake).
     2.03a: 2000-12-11
       - Fixed Append and AppendSafe to create a file if it does not exist.
     2.03: 2000-10-25
       - Removed one FreeAndNil call preventing unit to compile under Delphi 2, 3, and 4.
     2.02: 2000-10-21
       - Added support for Unicode pseudo-codepage 1200 (CP_UNICODE).
     2.01: 2000-10-12
       - Added UTF-8 support (CP_UTF8 codepage) to TGpTextFile and TGpTextFileStream. To
         work with Unicode file in UTF-8 encoding, set cfUnicode flag and CP_UTF8 code
         page at the same time. When working in UTF-8 mode, TGpTextFile doesn't support
         lines longer than 2.147.483.647 bytes.
         - When opening files in unknown format, it is probably best to first Reset it
           with flags=[cfUnicode] and codepage=CP_UTF8. Then you can check if file is
           16-bit Unicode (Is16bit). If it is not, you can change the Codepage to some
           other value (1252, for example) or just leave it at CP_UTF8 (reasonable default
           for processing XML files).
       - UTF-8 support will read and skip Byte Order Mark (EF BB BF) but will only write
         BOM if cfWriteUTF8BOM is specified in flags.
       - New functions TGpTextFile.Is16bit and TGpTextFileStream.Is16bit return true when
         file is Unicode with 16-bit (UCS-2) encoding. IsUnicode returns true when file is
         Unicode with 16-bit (UCS-2) or 8-bit (UTF-8) encoding.
       - Added symbolic constants for ISO code pages not defined in Windows.pas:
         ISO-8859-1, ISO-8859-2, ISO-8859-3, ISO-8859-4, ISO-8859-5, ISO-8859-6,
         ISO-8859-7, ISO-8859-8 (symbols are named ISO_8859_n).
     2.0: 2000-10-06
       - Created TGpTextFileStream class, descendant of TStream, which offers similar
         functionality as TGpTextFile - automatic detection of Unicode files, automatic
         code page remapping etc.
       - TGpTextFile.SetCodepage made public so it is possible to change code page on the
         fly.
       - Added parameters 'flags', 'waitObject', and 'codePage' to TGpTextFile.AppendSafe.
       - Order of 'flags' and 'bufferSize' parameters reversed in most methods.
       - Position of 'diskLockTimeout' and 'diskRetryDelay' parameters changed in all
         methods.
       - Fully documented.
       - All language-dependant string constants moved to resourcestring section.
     1.08: 2000-10-05
       - Added codePage parameter to all Reset and Rewrite functions. Default value of 0
         specifies conversion according to current codepage and any other number specifies
         codepage that should be used for conversion.
     1.07: 2000-08-01
       - All exceptions generated in this unit were converted to EGpTextFile exceptions
         (descendant of EGpHugeFile).
       - All Windows-generated exceptions not caught in TGpHugeFile are now converted to
         EGpTextFile exception.
       - Added parameter bufferSize to Append and AppendSafe.
       - Append* opened file in non-buffered mode. Fixed.
     1.06: 2000-06-22
       - Added overloaded version of Writeln.
     1.05: 2000-05-15
       - Rewrite now opens file in buffered mode.
     1.04: 2000-04-19
       - Added new ResetSafe/RewriteSafe parameter - waitObject. It is forwarded to
         TGpHugeFile.ResetEx/RewriteEx.
     1.03: 2000-03-03
       - Added OpenFlags parameter to Reset and ResetSafe. In D4 or higher its value
         defaults to [] so no source code changes to old applications will be required.
         Currently only supported OpenFlag is opCloseOnEOF, which enables hfoCloseOnEOF
         flag in TGpHugeFile (see GpHugeF.pas for more details).
     1.02: 1999-11-24
       - Added bufferSize parameter to Reset* and Rewrite*. By default (bufferSize = 0),
         64 KB buffer is allocated.
     1.01a: 1999-11-03
       - Append fixed.
     1.01: 1999-11-02
       - Added ResetSafe and RewriteSafe methods.
     1.0: 1999-11-01
       - First published version.
*)

{$IFDEF VER100}{$DEFINE D3PLUS}{$ENDIF}
{$IFDEF VER120}{$DEFINE D3PLUS}{$DEFINE D4PLUS}{$ENDIF}
{$IFDEF VER130}{$DEFINE D3PLUS}{$DEFINE D4PLUS}{$ENDIF}
{$IFDEF CONDITIONALEXPRESSIONS}
  {$DEFINE D3PLUS}
  {$DEFINE D4PLUS}
{$ENDIF}

interface

uses
  Windows,
  Classes,
  GpHugeF,
  GpTextStream;

// HelpContext values for all raised exceptions. All EGpHugeFile exception are
// re-raised without modifying HelpContext (which was already assigned in
// GpHugeF unit).
const
  //:Exception was handled and converted to EGpTextFile but was not expected and is not categorised.
  hcTFUnexpected              = 2000;
  //:Failed to append file.
  hcTFFailedToAppend          = 2003;
  //:Failed to reset file.
  hcTFFailedToReset           = 2004;
  //:Failed to rewrite file.
  hcTFFailedToRewrite         = 2005;
  //:Cannot append reversed Unicode file - not supported.
  hcTFCannotAppendReversed    = 2006;
  //:Cannot write to reversed Unicode file - not supported.
  hcTFCannotWriteReversed     = 2007;
  //:Parameter to Write method is invalid.
  hcTFInvalidParameter        = 2008;

type
  {$IFDEF Unicode}
  WideStr = UnicodeString;
  {$ELSE}
  WideStr = WideString;
  {$ENDIF Unicode}

  {:Base exception class for exceptions created in TGpTextFile and descendants.
  }
  EGpTextFile       = class(EGpHugeFile);

  {:Base exception class for exceptions created in TGpTextFileStream.
  }
  EGpTextFileStream = class(EGpHugeFileStream);

  {:Text file creation flags.
    @enum cfUnicode            Create Unicode file.
    @enum cfReverseByteOrder   Create unicode file with reversed byte order
                               (Motorola format). Set only on Reset, readonly.
                               Currently ignored in Rewrite.
    @enum cfUse2028            Use standard /2028/ instead of /000D/000A/ for
                               line delimiter (MS Notepad and MS Word do not
                               understand $2028 delimiter). Applies to Unicode
                               files only.
    @enum cfUseLF              Use /LF/ instead of /CR/LF/ for line delimiter.
    @enum cfWriteUTF8BOM       Write UTF-8 Byte Order Mark to the beginning of
                               file.
    @enum cfCompressed         Will try to set the "compressed" attribute (when
                               running on NT and file is on NTFS drive).
    @enum cfNo8BitCPConversion Disable 8-bit-to-Unicode conversion on Read and
                               Write.
  }
  TCreateFlag = (cfUnicode, cfReverseByteOrder, cfUse2028, cfUseLF,
    cfWriteUTF8BOM, cfCompressed, cfNo8BitCPConversion);

  {:Set of all creation flags.
  }
  TCreateFlags = set of TCreateFlag;

  {:Text file open (reset) flags.
    @enum ofCloseOnEOF         Remaps to TGpHugeFile hfCloseOnEOF.
    @enum ofNo8BitCPConversion Disable 8-bit-to-Unicode conversion on Read and Write.
    @enum ofNotUTF8Autodetect  Disable UTF-8 autodetection when file has no BOM.
    @enum ofJSON               Input stream contains a JSON data. Allows the
                               reader to auto-detect following formats:
                               - UTF-8 no bom, UTF-8 BOM, UTF-16 LE no BOM, UTF-16 LE,
                                 UTF-16 BE no BOM, UTF-16 BE
    @enum ofScanEntireFile     Scans the entire file when autodetecting UTF-8.
  }
  TOpenFlag = (ofCloseOnEOF, ofNo8BitCPConversion, ofNotUTF8Autodetect, ofJSON, ofScanEntireFile);

  {:Set of all open flags.
  }
  TOpenFlags = set of TOpenFlag;

  {:Line delimiters.
    @enum ldCR       Carriage return (Mac style).
    @enum ldLF       Line feed (Unix style).
    @enum ldCRLF     Carriage return + Line feed (DOS style).
    @enum ldLFCR     Line feed + Carriage return (very unusual combination).
    @enum ld2028     /2028/ Unicode delimiter.
    @enum ld000D000A /000D/000A/ Windows-style Unicode delimiter.
  }
  TLineDelimiter = (ldCR, ldLF, ldCRLF, ldLFCR, ld2028, ld000D000A);

  {:Set of all line delimiters.
  }
  TLineDelimiters = set of TLineDelimiter;

  {:Unified 8/16-bit text file access. All strings passed as Unicode, conversion
    to/from 8-bit is done automatically according to specified code page.
    Access is buffered but direct-access functions (FilePos, Seek) are supported
    nevertheless.
  }
  TGpTextFile = class(TGpHugeFile)
  private
    tfCFlags            : TCreateFlags;
    tfCodePage          : word;
    tfLeof              : boolean;
    tfLineDelimiter     : array [0..7] of byte;
    tfLineDelimiterSize : integer;
    tfLineDelims        : TLineDelimiters;
    tfNo8BitCPConversion: boolean;
    tfOverRead          : integer;
    tfReadlnBuf         : array [1..2048+6] of byte; // size must be even for Unicode; 6 sentinel bytes are used to simplify EOL delimiter detection
    tfReadlnBufPos      : cardinal;
    tfReadlnBufSize     : cardinal;
    tfSmallBuf          : pointer;
  protected
    function  AllocTmpBuffer(size: integer): pointer; virtual;
    procedure AutodetectUTF8(const scanEntireFile: boolean = false);
    procedure AutodetectJSON;
    procedure ConvertCodepage(delimPos, delimLen: cardinal;
      var utf8ln: AnsiString; var wideLn: WideStr);
    procedure FetchBlock(out endOfFile: boolean); virtual;
    procedure FreeTmpBuffer(var buffer: pointer); virtual;
    function  GetAnsiCodePage: integer;
    function  IsAfterEndOfBlock: boolean; virtual;
    function  IsUnicodeCodepage(codepage: word): boolean;
    function  IsUTF8(data: PByte; dataSize: integer): boolean;
    procedure LocateDelimiter(var delimPos, delimLen: cardinal); virtual;
    procedure PrepareBuffer; virtual;
    procedure RebuildNewline; virtual;
    procedure ReverseBlock; virtual;
    procedure SetCodepage(cp: word); virtual;
    procedure WriteString(ws: WideStr); virtual;
  public
    destructor Destroy; override;
    procedure Append(
      flags: TCreateFlags {$IFDEF D4plus}= []{$ENDIF};
      bufferSize: integer {$IFDEF D4plus}= 0{$ENDIF};
      codePage: word      {$IFDEF D4plus}= 0{$ENDIF});
    function  AppendSafe(
      flags: TCreateFlags      {$IFDEF D4plus}= []{$ENDIF};
      bufferSize: integer      {$IFDEF D4plus}= 0{$ENDIF};
      diskLockTimeout: integer {$IFDEF D4plus}= 0{$ENDIF};
      diskRetryDelay: integer  {$IFDEF D4plus}= 0{$ENDIF};
      waitObject: THandle      {$IFDEF D4plus}= 0{$ENDIF};
      codePage: word           {$IFDEF D4plus}= 0{$ENDIF};
      openFlags: TOpenFlags    {$IFDEF D4plus}= []{$ENDIF}): THFError;
    function  EOF: boolean;
    function  Is16bit: boolean;
    function  IsUnicode: boolean;
    function  Readln: WideStr;
    procedure Reset(
      flags: TOpenFlags   {$IFDEF D4plus}= []{$ENDIF};
      bufferSize: integer {$IFDEF D4plus}= 0{$ENDIF};
      codePage: word      {$IFDEF D4plus}= 0{$ENDIF});
    function  ResetSafe(
      flags: TOpenFlags        {$IFDEF D4plus}= []{$ENDIF};
      bufferSize: integer      {$IFDEF D4plus}= 0{$ENDIF};
      diskLockTimeout: integer {$IFDEF D4plus}= 0{$ENDIF};
      diskRetryDelay: integer  {$IFDEF D4plus}= 0{$ENDIF};
      waitObject: THandle      {$IFDEF D4plus}= 0{$ENDIF};
      codePage: word           {$IFDEF D4plus}= 0{$ENDIF}): THFError;
    procedure Rewrite(
      flags: TCreateFlags {$IFDEF D4plus}= []{$ENDIF};
      bufferSize: integer {$IFDEF D4plus}= 0{$ENDIF};
      codePage: word      {$IFDEF D4plus}= 0{$ENDIF});
    function  RewriteSafe(
      flags: TCreateFlags      {$IFDEF D4plus}= []{$ENDIF};
      bufferSize: integer      {$IFDEF D4plus}= 0{$ENDIF};
      diskLockTimeout: integer {$IFDEF D4plus}= 0{$ENDIF};
      diskRetryDelay: integer  {$IFDEF D4plus}= 0{$ENDIF};
      waitObject: THandle      {$IFDEF D4plus}= 0{$ENDIF};
      codePage: word           {$IFDEF D4plus}= 0{$ENDIF}): THFError;
    procedure Write(params: array of const); {$IFDEF D4plus} overload;
    procedure Write(const s: AnsiString); overload;
    procedure Write(const ws: WideStr); overload; {$ENDIF D4plus}
    procedure Writeln(const ln: WideStr {$IFDEF D4plus}= ''{$ENDIF}); {$IFDEF D4plus} overload;
    procedure Writeln(const s: AnsiString); overload;
    function  Is32bit: boolean;
    procedure Writeln(params: array of const); overload; {$ENDIF D4plus}
    //:Accepted line delimiters (CR, LF or any combination).
    property AcceptedDelimiters: TLineDelimiters read tfLineDelims
      write tfLineDelims;
    {:Code page used to convert 8-bit files to Unicode and back. May be changed
      while file is open (and even partially read). If set to 0, current default
      code page will be used.
    }
    property Codepage: word read tfCodepage write SetCodepage;
    {:File flags - as decoded from file structure or as passed to the Rewrite[Safe.]
      @since   2005-12-22
    }
    property FileFlags: TCreateFlags read tfCFlags;
  end; { TGpTextFile }

  {:Wrapper for TGpTextStream that automatically creates TGpHugeFileStream for
    a specified file in the constructor and destroys it in the destructor.
  }
  TGpTextFileStream = class(TGpTextStream)
  private
    tfsStream: TGpHugeFileStream;
  protected
    function  GetFileName: WideStr; virtual;
    function  GetWindowsError: DWORD; override;
    function  StreamName(param: string = ''): string; override;
  public
    constructor Create(
      const fileName: string; access: TGpHugeFileStreamAccess;
      openFlags: TOpenFlags       {$IFDEF D4plus}= []{$ENDIF};
      createFlags: TCreateFlags   {$IFDEF D4plus}= []{$ENDIF};
      codePage: word              {$IFDEF D4plus}= 0{$ENDIF};
      desiredShareMode: DWORD     {$IFDEF D4plus}= CAutoShareMode{$ENDIF};
      diskLockTimeout: integer    {$IFDEF D4plus}= 0{$ENDIF};
      diskRetryDelay: integer     {$IFDEF D4plus}= 0{$ENDIF};
      waitObject: THandle         {$IFDEF D4plus}= 0{$ENDIF});
    constructor CreateFromHandle(hf: TGpHugeFile;
      access: TGpHugeFileStreamAccess;
      createFlags: TCreateFlags   {$IFDEF D4plus}= []{$ENDIF};
      codePage: word              {$IFDEF D4plus}= 0{$ENDIF};
      openFlags: TOpenFlags       {$IFDEF D4plus}= []{$ENDIF});
    constructor CreateW(
      const fileName: WideStr; access: TGpHugeFileStreamAccess;
      openFlags: TOpenFlags       {$IFDEF D4plus}= []{$ENDIF};
      createFlags: TCreateFlags   {$IFDEF D4plus}= []{$ENDIF};
      codePage: word              {$IFDEF D4plus}= 0{$ENDIF};
      desiredShareMode: DWORD     {$IFDEF D4plus}= CAutoShareMode{$ENDIF};
      diskLockTimeout: integer    {$IFDEF D4plus}= 0{$ENDIF};
      diskRetryDelay: integer     {$IFDEF D4plus}= 0{$ENDIF};
      waitObject: THandle         {$IFDEF D4plus}= 0{$ENDIF}
      {$IFDEF D4plus}; dummy_param: boolean = false{$ENDIF});
    destructor  Destroy; override;
    //:Name of underlying file.
    property  FileName: WideStr read GetFileName;
  end; { TGpTextFileStream }

function  StringToWideStringNoCP(const s: AnsiString): WideStr; overload;
procedure StringToWideStringNoCP(const s: AnsiString; var w: WideStr); overload;
procedure StringToWideStringNoCP(const buf; bufLen: integer; var w: WideStr); overload;
function  WideStringToStringNoCP(const s: WideStr): AnsiString;

implementation

uses
  SysUtils,
  SysConst;

const
  {:Header for 'normal' Unicode UCS-4 stream (Intel format).
  }
  CUnicode32Normal: UCS4Char = UCS4Char($0000FEFF);

  {:Header for 'reversed' Unicode UCS-4 stream (Motorola format).
  }
  CUnicode32Reversed: UCS4Char = UCS4Char($FFFE0000);

  {:Header for big-endian (Motorola) Unicode file.
  }
  CUnicodeNormal  : WideChar = WideChar($FEFF);

  {:Header for little-endian (Intel) Unicode file.
  }
  CUnicodeReversed: WideChar = WideChar($FFFE);

  {:First two bytes of UTF-8 BOM.
  }
  CUTF8BOM12: WideChar = WideChar($BBEF);

  {:Third byte of UTF-8 BOM.
  }
  CUTF8BOM3: AnsiChar = AnsiChar($BF);

  {:Size of preallocated buffer used for 8 to 16 to 8 bit conversions in
    TGpTextFile.
  }
  CtsSmallBufSize = 2048; // 1024 WideChars

{$IFDEF D3plus}
resourcestring
{$ELSE}
const
{$ENDIF}
  sCannotAppendReversedUnicodeFile   = 'TGpTextFile(%s):Cannot append reversed Unicode file.';
  sCannotAppendReversedUnicodeStream = '%s:Cannot append reversed Unicode file.';
  sCannotConvertOddNumberOfBytes     = '%s:Cannot convert odd number of bytes: %d';
  sCannotWriteReversedUnicodeFile    = 'TGpTextFile(%s):Cannot write to reversed Unicode file.';
  sCannotWriteReversedUnicodeStream  = '%s:Cannot write to reversed Unicode file.';
  sFailedToAppendFile                = 'TGpTextFile(%s):Failed to append.';
  sFailedToResetFile                 = 'TGpTextFile(%s):Failed to reset file.';
  sFailedToRewriteFile               = 'TGpTextFile(%s):Failed to rewrite file.';
  sInvalidParameter                  = 'TGpTextFile(%s):Invalid parameter!';
  sStreamFailed                      = '%s failed. ';
  sCannotScanEntireFireWithCloseOnEOF = 'TGpTextFile(%s):ofCloseOnEOF and ofScanEntireFile cannot be used together.';

{:Converts Ansi string to Unicode string without code page conversion.
  @param   s        Ansi string.
  @returns Converted wide string.
}
function StringToWideStringNoCP(const s: AnsiString): WideStr; overload;
begin
  Result := '';
  StringToWideStringNoCP(s, Result);
end; { StringToWideStringNoCP }

{:Converts Ansi string to Unicode string without code page conversion.
  @param   s Ansi string.
  @returns w Wide string. New data will be appended to the original contents.
}
procedure StringToWideStringNoCP(const s: AnsiString; var w: WideStr); overload;
begin
  if s <> '' then
    StringToWideStringNoCP(s[1], Length(s), w);
end; { StringToWideStringNoCP }

{:Converts buffer of ansi characters to Unicode string without code page conversion.
  @param   s   Buffer of ansi characters.
  @param   len Length of the buffer.
  @returns w   Wide string. New data will be appended to the original contents.
}
procedure StringToWideStringNoCP(const buf; bufLen: integer; var w: WideStr); overload;
var
  iCh    : integer;
  lResult: integer;
  pOrig  : PByte;
  pResult: PWideChar;
begin
  if bufLen > 0 then begin
    lResult := Length(w);
    SetLength(w, lResult+bufLen);
    pOrig := @buf;
    pResult := @w[lResult+1];
    for iCh := 1 to bufLen do begin
      pResult^ := WideChar(pOrig^);
      Inc(pOrig);
      Inc(pResult);
    end;
  end;
end; { StringToWideStringNoCP }

{:Converts Unicode string to Ansi string without code page conversion.
  @param   s        Ansi string.
  @param   codePage Code page to be used in conversion.
  @returns Converted wide string.
}
function WideStringToStringNoCP(const s: WideStr): AnsiString;
var
  pResult: PByte;
  pOrig: PWord;
  i, l: integer;
begin
  if s = '' then     
    Result := ''
  else begin
    l := Length(s);
    SetLength(Result, l);
    pOrig := @s[1];
    pResult := @Result[1];
    for i := 1 to l do begin
      pResult^ := pOrig^ AND $FF;
      Inc(pResult);
      Inc(pOrig);
    end;
  end;
end; { WideStringToStringNoCP }

{:Converts Ansi string to Unicode string using specified code page.
  @param   s        Ansi string.
  @param   codePage Code page to be used in conversion.
  @param   w        Resulting string. Original contents is preserved (new data
                    is appended).
  @returns Converted wide string.
}
procedure StringToWideString(const s: AnsiString; codePage: word; var w: WideStr); overload;
var
  l: integer;
  lResult: integer;
begin
  if s <> '' then begin
    l := MultiByteToWideChar(codePage, MB_PRECOMPOSED, PAnsiChar(@s[1]), -1, nil, 0);
    Win32Check(l <> 0);
    lResult := Length(w);
    SetLength(w, lResult+l-1); //we don't need the trailing #0
    if l > 1 then begin
      l := MultiByteToWideChar(CodePage, MB_PRECOMPOSED, PAnsiChar(@s[1]), -1,
             PWideChar(@w[lResult+1]), l-1);
      Win32Check((l = 0) and (GetLastError = ERROR_INSUFFICIENT_BUFFER));
    end;
  end;
end; { StringToWideString }

{:Converts Ansi string to Unicode string using specified code page.
  @param   s        Ansi string.
  @param   codePage Code page to be used in conversion.
  @returns Converted wide string.
}
function StringToWideString(const s: AnsiString; codePage: word): WideStr; overload;
begin
  StringToWideString(s, codePage, Result);
end; { StringToWideString }

{:Converts Ansi string to Unicode string using specified code page.
  @param   buf      Buffer containing ansi characters.
  @param   bufLen   Length of the buffer.
  @param   codePage Code page to be used in conversion.
  @param   w        Resulting string. Original contents is preserved (new data
                    is appended).
  @returns Converted wide string.
}
procedure StringToWideString(const buf; bufLen: integer; codePage: word; var w: WideStr); overload;
var
  l      : integer;
  lResult: integer;
  oldChar: AnsiChar;
begin
  if bufLen > 0 then begin
    oldChar := PAnsiChar(NativeUInt(@buf)+NativeUInt(bufLen))^;
    PAnsiChar(NativeUInt(@buf)+NativeUInt(bufLen))^ := #0;
    try
      l := MultiByteToWideChar(codePage, MB_PRECOMPOSED, PAnsiChar(@buf), -1, nil, 0);
      lResult := Length(w);
      SetLength(w, lResult+l-1);
      if l > 1 then
        MultiByteToWideChar(CodePage, MB_PRECOMPOSED, PAnsiChar(@buf), -1, PWideChar(@w[lResult+1]), l-1);
    finally PAnsiChar(NativeUInt(@buf)+NativeUInt(bufLen))^ := oldChar; end;
  end;
end; { StringToWideString }

{:Converts Unicode string to Ansi string using specified code page.
  @param   ws       Unicode string.
  @param   codePage Code page to be used in conversion.
  @returns Converted ansi string.
}
function WideStringToString(const ws: WideStr; codePage: Word): AnsiString;
var
  l: integer;
begin
  if ws = '' then
    Result := ''
  else begin
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
    pch^ := ansichar(b);
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
  Result := NativeUInt(pch)-NativeUInt(@utf8Buf);
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
  Result := NativeUInt(pwc)-NativeUInt(@unicodeBuf);
end; { UTF8BufToWideCharBuf }

{:Returns default Ansi codepage for LangID or 'defCP' in case of error (LangID
  does not specify valid language ID).
  @param   LangID Language ID.
  @param   defCP  Default value that is to be returned if LangID doesn't specify
                  a valid language ID.
  @returns Default Ansi codepage for LangID or 'defCP' in case of error.
}
function GetDefaultAnsiCodepage (LangID: LCID; defCP: integer): word;
var
  p: array [0..255] of char;
begin
  if GetLocaleInfo(LangID, 4100, p, High(p)) > 0 then
    Result := StrToIntDef(p, defCP)
  else
    Result := defCP;
end; { GetDefaultAnsiCodepage }

{ TGpTextFile }

{:Allocates buffer for 8/16/8 bit conversions. If requested size is small
  enough, returns pre-allocated buffer, otherwise allocates new buffer.
  @param   size Requested size in bytes.
  @returns Pointer to buffer.
}
function TGpTextFile.AllocTmpBuffer(size: integer): pointer;
begin
  if size <= CtsSmallBufSize then
    Result := tfSmallBuf
  else
    GetMem(Result,size);
end; { TGpTextFile.AllocTmpBuffer }

{:Convert tfReadlnBuf from (including) tfReadlnBufPos to (not including)
  delimPos and append result to wideLn or utf8ln. Set tfReadlnBufPos to the
  first character after delimiter.
  @since   2002-10-11
}
procedure TGpTextFile.ConvertCodepage(delimPos, delimLen: cardinal;
  var utf8ln: AnsiString; var wideLn: WideStr);
var
  bufPtr  : PByte;
  delimPtr: PByte;
  lResult : cardinal;
begin
  if tfReadlnBufPos < delimPos then
    if IsUnicode then begin
      if Codepage = CP_UTF8 then begin
        lResult := length(utf8Ln);
        SetLength(utf8Ln, lResult + (delimPos-tfReadlnBufPos));
        Move(tfReadlnBuf[tfReadlnBufPos], utf8Ln[lResult+1], delimPos-tfReadlnBufPos);
      end
      else if Codepage = CP_UNICODE32 then begin
        lResult := Length(wideLn);
        SetLength(wideLn, lResult + (delimPos-tfReadlnBufPos+1) div (SizeOf(WideChar)*2));
        bufPtr := @tfReadlnBuf[tfReadlnBufPos];
        delimPtr := @tfReadlnBuf[delimPos];
        while cardinal(bufPtr) < cardinal(delimPtr) do begin
          Inc(lResult);
          wideLn[lResult] := PWideChar(bufPtr)^;
          Inc(bufPtr, 4);
        end;
      end
      else begin
        lResult := Length(wideLn);
        SetLength(wideLn, lResult + (delimPos-tfReadlnBufPos+1) div SizeOf(WideChar));
        Move(tfReadlnBuf[tfReadlnBufPos], wideLn[lResult+1], delimPos-tfReadlnBufPos);
      end;
    end
    else begin
      if tfNo8BitCPConversion then
        StringToWideStringNoCP(tfReadlnBuf[tfReadlnBufPos], delimPos-tfReadlnBufPos, wideLn)
      else
        StringToWideString(tfReadlnBuf[tfReadlnBufPos], delimPos-tfReadlnBufPos, tfCodePage, wideLn);
    end;
  tfReadlnBufPos := delimPos + delimLen;
end; { TGpTextFile.ConvertCodepage }

{:Prefetch next block from the file.
  @since   2002-10-11
}
procedure TGpTextFile.FetchBlock(out endOfFile: boolean);
var
  overshoot: cardinal;
begin
  if tfReadlnBufSize = 0 then begin
    BlockRead(tfReadlnBuf, SizeOf(tfReadlnBuf), tfReadlnBufSize);
    if tfReadlnBufSize > (SizeOf(tfReadlnBuf)-6) then
      tfOverRead := tfReadlnBufSize - (SizeOf(tfReadlnBuf)-6)
    else
      tfOverRead := 0;
    overshoot := 0;
  end
  else if tfReadlnBufSize < (SizeOf(tfReadlnBuf)-6) then begin
    endOfFile := true;
    tfReadlnBufSize := 0;
    Exit;
  end
  else begin
    overshoot := tfReadlnBufPos - (High(tfReadlnBuf)-5);
    if not (cfReverseByteOrder in tfCFlags) then begin
      PDWord(@tfReadlnBuf[1])^ := PDWord(@tfReadlnBuf[tfReadlnBufSize+1])^;
      PWord(@tfReadlnBuf[5])^ := PWord(@tfReadlnBuf[tfReadlnBufSize+5])^;
    end
    else begin
      tfReadlnBuf[1] := tfReadlnBuf[tfReadlnBufSize+2];
      tfReadlnBuf[2] := tfReadlnBuf[tfReadlnBufSize+1];
      tfReadlnBuf[3] := tfReadlnBuf[tfReadlnBufSize+4];
      tfReadlnBuf[4] := tfReadlnBuf[tfReadlnBufSize+3];
      tfReadlnBuf[5] := tfReadlnBuf[tfReadlnBufSize+6];
      tfReadlnBuf[6] := tfReadlnBuf[tfReadlnBufSize+5];
    end;
    if tfOverRead < 6 then begin
      tfReadlnBufSize := tfOverRead;
      tfOverRead := 0;
    end
    else begin
      BlockRead(tfReadlnBuf[7], SizeOf(tfReadlnBuf)-6, tfReadlnBufSize);
      Inc(tfReadlnBufSize, 6);
      if tfReadlnBufSize > (SizeOf(tfReadlnBuf)-6) then
        tfOverRead := tfReadlnBufSize - (SizeOf(tfReadlnBuf)-6)
      else
        tfOverRead := 0;
    end;
  end;
  if cfReverseByteOrder in tfCFlags then
    ReverseBlock;
  endOfFile := (tfReadlnBufSize < (SizeOf(tfReadlnBuf)-6));
  // simplify LocateDelimiter
  if not endOfFile then begin
    if tfReadlnBufSize > (SizeOf(tfReadlnBuf)-6) then
      tfReadlnBufSize := (SizeOf(tfReadlnBuf)-6);
  end
  else begin
    tfReadlnBuf[tfReadlnBufSize+1] := 0;
    tfReadlnBuf[tfReadlnBufSize+2] := 0;
    tfReadlnBuf[tfReadlnBufSize+3] := 0;
    tfReadlnBuf[tfReadlnBufSize+4] := 0;
    tfReadlnBuf[tfReadlnBufSize+5] := 0;
    tfReadlnBuf[tfReadlnBufSize+6] := 0;
  end;
  tfReadlnBufPos := Low(tfReadlnBuf) + overshoot;
  if (tfCodepage = CP_UNICODE32) and (cfReverseByteOrder in tfCFlags) then
    Inc(tfReadlnBufPos, 2);
end; { TGpTextFile.FetchBlock }

{:Frees buffer for 8/16/8 bit conversions. If pre-allocated buffer is passed,
  nothing will be done.
  @param   buffer Conversion buffer.
}
procedure TGpTextFile.FreeTmpBuffer(var buffer: pointer);
begin
  if buffer <> tfSmallBuf then begin
    FreeMem(buffer);
    buffer := nil;
  end;
end; { TGpTextFile.FreeTmpBuffer }

{:Simplest form of Append.
  @param   flags      Create flags. Only cfUse2028, cfUseLF, cfUnicodeUseLF, and cfUnicode flags are used.
  @param   bufferSize Size of buffer. 0 means default size (BUF_SIZE, currently
                      64 KB).
  @param   codePage   Code page to be used for 8/16/8 bit conversion. If 0,
                      default code page for currently used language will be
                      used.
  @raises  EGpTextFile if file could not be appended.
}
procedure TGpTextFile.Append(flags: TCreateFlags; bufferSize: integer;
  codePage: word);
begin
  if AppendSafe(flags,bufferSize,0,0,0,codePage) <> hfOK then
    raise EGpTextFile.CreateFmtHelp(sFailedToAppendFile,[FileName],hcTFFailedToAppend);
end; { TGpTextFile.Append }

{:Full form of Append. Will retry if file is locked by another application (if
  diskLockTimeout and diskRetryDelay are specified). Allows caller to specify
  additional options. Does not raise an exception on error (except appending
  reversed Unicode file).
  @param   flags           Create flags. Only cfUse2028, cfUseLF, cfUnicodeUseLF, and cfUnicode flags are
                           used.
  @param   bufferSize      Size of buffer. 0 means default size (BUF_SIZE,
                           currently 64 KB).
  @param   diskLockTimeout Max time (in milliseconds) AppendSafe will wait for
                           locked file to become free.
  @param   diskRetryDelay  Delay (in milliseconds) between attempts to open
                           locked file.
  @param   waitObject      Handle of 'terminate' event (semaphore, mutex). If
                           this parameter is specified (not zero) and becomes
                           signalled, AppendSafe will stop trying to open locked
                           file and will exit with.
  @param   codePage        Code page to be used for 8/16/8 bit conversion. If 0,
                           default code page for currently used language will be
                           used.
  @param   openFlags       Flags that may determine file parsing. Only ofJSON flag is used.
  @raises  EGpTextFile if file is 'reversed' Unicode file.
}

function TGpTextFile.AppendSafe(flags: TCreateFlags; bufferSize: integer;
  diskLockTimeout, diskRetryDelay: integer; waitObject: THandle;
  codePage: word; openFlags: TOpenFlags): THFError;
var
  marker : WideChar;
  marker3: AnsiChar;
  marker4: UCS4Char;
  options: THFOpenOptions;
begin
  try
    if openFlags * [ofCloseOnEOF, ofScanEntireFile] = [ofCloseOnEOF, ofScanEntireFile] then
      raise EGpTextFile.CreateFmtHelp(sCannotScanEntireFireWithCloseOnEOF, [FileName], hcTFInvalidParameter);

    if (cfUnicode in flags) and (codePage <> CP_UTF8) and (codePage <> CP_UNICODE32) then
      codePage := CP_UNICODE;
    PrepareBuffer;
    SetCodepage(codePage);
    options := [hfoBuffered, hfoCanCreate];
    if cfCompressed in flags then
      Include(options, hfoCompressed);
    Result := ResetEx(1, bufferSize, diskLockTimeout, diskRetryDelay, options, waitObject);
    if Result = hfOK then begin
      tfCFlags := [];
      if FileSize >= SizeOf(UCS4Char) then begin
        Seek(0);
        BlockReadUnsafe(marker4, SizeOf(UCS4Char));
        if marker4 = CUnicode32Normal then
          SetCodepage(CP_UNICODE32)
        else if marker4 = CUnicode32Reversed then begin
          SetCodepage(CP_UNICODE32);
          tfCFlags := tfCFlags + [cfReverseByteOrder];
        end;
      end;
      if (FileSize >= SizeOf(WideChar)) and (Codepage <> CP_UNICODE32) then begin
        Seek(0);
        BlockReadUnsafe(marker,SizeOf(WideChar));
        if marker = CUnicodeNormal then
          SetCodepage(CP_UNICODE)
        else if marker = CUnicodeReversed then begin
          SetCodepage(CP_UNICODE);
          tfCFlags := tfCFlags + [cfReverseByteOrder];
        end
        else if (marker = CUTF8BOM12) and (FileSize >= 3) then begin
          BlockReadUnsafe(marker3, SizeOf(AnsiChar));
          if marker3 = CUTF8BOM3 then
            SetCodepage(CP_UTF8);
        end;
        if (not IsUnicode) and (ofJSON in openFlags) then
          AutodetectJSON;
        if not IsUnicode then begin
          Seek(0);
          if not (ofNotUTF8Autodetect in openFlags) then
            AutodetectUTF8(ofScanEntireFile in openFlags);
        end;
      end
      else if (FileSize = 0) and (cfUnicode in flags) then begin
        if Codepage = CP_UNICODE32 then
          BlockWriteUnsafe(CUnicode32Normal, SizeOf(UCS4Char))
        else if Codepage <> CP_UTF8 then
          BlockWriteUnsafe(CUnicodeNormal, SizeOf(WideChar))
        else if cfWriteUTF8BOM in flags then begin
          BlockWriteUnsafe(CUTF8BOM12, SizeOf(WideChar));
          BlockWriteUnsafe(CUTF8BOM3, SizeOf(AnsiChar));
        end;
      end;
      if (not IsUnicode) and IsUnicodeCodepage(Codepage) then
        tfCFlags := tfCFlags + [cfUnicode];
      if [cfUnicode, cfReverseByteOrder] <= tfCFlags then
        raise EGpTextFile.CreateFmtHelp(sCannotAppendReversedUnicodeFile, [FileName],
          hcTFCannotAppendReversed);
      tfCFlags := tfCFlags + (flags * [cfUse2028, cfUseLF]);
      RebuildNewline;
      Seek(FileSize);
    end;
  except
    on EGpTextFile do
      raise;
    on Exception do
      Result := hfError;
  end;
end; { TGpTextFile.Append }

{:Cleanup.
  @since   2.01
}
destructor TGpTextFile.Destroy;
begin
  if assigned(tfSmallBuf) then begin
    FreeMem(tfSmallBuf);
    tfSmallBuf := nil;
  end;
  inherited;
end; { TGpTextFile.Destroy }

procedure TGpTextFile.AutodetectJSON;
var
  b1: byte;
  b2: byte;
  b3: byte;
  b4: byte;
begin
  // At this point we already know that the wrapped stream contains no BOM

  Seek(0);

  if FileSize >= 2 then begin
    BlockReadUnsafe(b1, 1);
    BlockReadUnsafe(b2, 1);
  end;
  if FileSize >= 4 then begin
    BlockReadUnsafe(b3, 1);
    BlockReadUnsafe(b4, 1);
  end;

  Seek(0);

  if FileSize >= 4 then begin
    if (b2 = 0) and (b3 = 0) and (b4 = 0) then begin
      Codepage := CP_UNICODE32;
      tfCFlags := tfCFlags + [cfUnicode];
      Exit;
    end
    else if (b1 = 0) and (b2 = 0) and (b3 = 0) then begin
      Codepage := CP_UNICODE32;
      tfCFlags := tfCFlags + [cfUnicode, cfReverseByteOrder];
      Exit;
    end;
  end;

  if FileSize >= 2 then begin
    if b2 = 0 then begin
      Codepage := CP_UNICODE;
      tfCFlags := tfCFlags + [cfUnicode];
      Exit;
    end
    else if b1 = 0 then begin
      Codepage := CP_UNICODE;
      tfCFlags := tfCFlags + [cfUnicode, cfReverseByteOrder];
      Exit;
    end;
  end;

  Codepage := CP_UTF8;
  tfCFlags := tfCFlags + [cfUnicode];
end; { TGpTextFile.AutodetectJSON }

procedure TGpTextFile.AutodetectUTF8(const scanEntireFile: boolean = false);
var
  buf    : packed array [1..65536] of byte;
  bufSize: DWORD;
  totalSize: Int64;
begin
  totalSize := FileSize;
  if not scanEntireFile and (totalSize > SizeOf(buf)) then
    totalSize := SizeOf(buf);

  while totalSize > 0 do begin
    BlockRead(buf, SizeOf(buf), bufSize);
    if (bufSize > 0) and IsUTF8(@buf, bufSize) then begin
      SetCodepage(CP_UTF8);
      break;
    end
    else if bufSize = 0 then
      break;
    Dec(totalSize, bufSize);
  end;
  Seek(0);
end; { TGpTextFile.AutodetectUTF8 }

{:Checks if file pointer is at end of file.
  @returns True if file pointer is at end of file.
  @raises  EGpHugeFile on Windows errors.
}
function TGpTextFile.EOF: boolean;
begin
  Result := IsAfterEndOfBlock and (FilePos >= FileSize);
end; { TGpTextFile.EOF }

function TGpTextFile.GetAnsiCodePage: integer;
begin
  if (tfCodePage = CP_UTF7) or (tfCodePage = CP_UTF8) or
     (tfCodePage = CP_UNICODE) or (tfCodePage = CP_UNICODE32)
  then
    Result := GetDefaultAnsiCodepage(GetSystemDefaultLCID and $FFFF, 1252)
  else            
    Result := tfCodePage;
end; { TGpTextFile.GetAnsiCodePage }

{:Checks if file is 16-bit Unicode.
  @since   2.01
}
function TGpTextFile.Is16bit: boolean;
begin
  Result := IsUnicode and (Codepage = CP_UNICODE);
end; { TGpTextFile.Is16bit }

{:Checks if file is 32-bit Unicode.
  @since   2000-10-12
}
function TGpTextFile.Is32bit: boolean;
begin
  Result := IsUnicode and (Codepage = CP_UNICODE32);
end; { TGpTextFile.Is32bit }

{:Checks if readln buffer pointer is positioned after end of block.
  @since   2002-10-15
}
function TGpTextFile.IsAfterEndOfBlock: boolean;
begin
  Result := (tfReadlnBufPos > tfReadlnBufSize) or (tfReadlnBufSize = 0);
end; { TGpTextFile.IsAfterEndOfBlock }

{:Checks if file is Unicode (UCS-2 or UTF-8 encoding).
  @returns True if file is Unicode.
}
function TGpTextFile.IsUnicode: boolean;
begin
  Result := (cfUnicode in tfCFlags);
end; { TGpTextFile.IsUnicode }

{:Checks if codepage is one of supported Unicode codepages.
  @since   2006-02-06
}
function TGpTextFile.IsUnicodeCodepage(codepage: word): boolean;
begin
  Result := (codepage = CP_UTF8) or (codepage = CP_UNICODE) or (codepage = CP_UNICODE32);
end; { TGpTextFile.IsUnicodeCodepage }

function TGpTextFile.IsUTF8(data: PByte; dataSize: integer): boolean;
var
  bits: integer;
  i   : integer;
begin
  Result := false;
  i := 1;
  while i < dataSize do begin
    if data^ > 128 then begin
      Result := true;
      if data^ >= 254 then
        Exit(false)
      else if data^ >= 252 then bits := 6
      else if data^ >= 248 then bits := 5
      else if data^ >= 240 then bits := 4
      else if data^ >= 224 then bits := 3
      else if data^ >= 192 then bits := 2
      else
        Exit(false);
      if (i + bits) > dataSize then
        Exit(false);
      while bits > 1 do begin
        Inc(i);
        Inc(data);
        if (data^ < 128) or (data^ > 191) then
          Exit(false);
        Dec(bits);
      end; //while bits > 1
    end; //if data^ > 128
    Inc(i);
    Inc(data);
  end;
end; { TGpTextFile.IsUTF8 }

{:Locate next delimiter (starting from tfReadlnBufPos) and return its position
  and size. If delimiter is not found, return tfReadlnBufSize+1 and 0.
  @since   2002-10-11
}
procedure TGpTextFile.LocateDelimiter(var delimPos, delimLen: cardinal);
var
  i  : cardinal;
  pb0: PByte;
  pb1: PByte;
  pb2: PByte;
  pb3: PByte;
  pb4: PByte;
  pb5: PByte;
  pb6: PByte;
  pb7: PByte;
begin
  delimPos := tfReadlnBufSize+1;
  delimLen := 0;
  pb0 := @tfReadlnBuf[tfReadlnBufPos];
  pb1 := pb0; Inc(pb1, 1);
  if IsUnicode and (Codepage = CP_UNICODE) then begin
    pb2 := pb0; Inc(pb2, 2);
    pb3 := pb0; Inc(pb3, 3);
    for i := 0 to (tfReadlnBufSize-tfReadlnBufPos) div 2 do begin
      if ((AcceptedDelimiters = []) or (([ld000D000A, ldCRLF] * AcceptedDelimiters) <> [])) and
         ((pb0^ = $0D) and (pb1^ = $00) and
          (pb2^ = $0A) and (pb3^ = $00)) then
      begin
        delimPos := tfReadlnBufPos+2*i;
        delimLen := 4;
        break; //for i
      end
      else if ((AcceptedDelimiters = []) or (ldLFCR in AcceptedDelimiters)) and
              ((pb0^ = $0A) and (pb1^ = $00) and
               (pb2^ = $0D) and (pb3^ = $00)) then
      begin
        delimPos := tfReadlnBufPos+2*i;
        delimLen := 4;
        break; //for i
      end
      else if (((AcceptedDelimiters = []) or (ldCR in AcceptedDelimiters)) and (pb0^ = $0D) and (pb1^ = $00)) or
              (((AcceptedDelimiters = []) or (ldLF in AcceptedDelimiters)) and (pb0^ = $0A) and (pb1^ = $00)) then
      begin
        delimPos := tfReadlnBufPos+2*i;
        delimLen := 2;
        break; //for i
      end
      else if ((AcceptedDelimiters = []) or (ld2028 in AcceptedDelimiters)) and
              ((pb0^ = $28) and (pb1^ = $20)) then
      begin
        delimPos := tfReadlnBufPos+2*i;
        delimLen := 2;
        break; //for i
      end;
      Inc(pb0, 2);
      Inc(pb1, 2);
      Inc(pb2, 2);
      Inc(pb3, 2);
    end; //for
  end
  else if IsUnicode and (Codepage = CP_UNICODE32) then begin
    pb2 := pb0; Inc(pb2, 2);
    pb3 := pb0; Inc(pb3, 3);
    pb4 := pb0; Inc(pb4, 4);
    pb5 := pb0; Inc(pb5, 5);
    pb6 := pb0; Inc(pb6, 6);
    pb7 := pb0; Inc(pb7, 7);
    for i := 0 to (tfReadlnBufSize-tfReadlnBufPos) div 2 do begin
      if ((AcceptedDelimiters = []) or (([ld000D000A, ldCRLF] * AcceptedDelimiters) <> [])) and
         ((pb0^ = $0D) and (pb1^ = $00) and (pb2^ = $00) and(pb3^ = $00) and
          (pb4^ = $0A) and (pb5^ = $00) and (pb6^ = $00) and (pb7^ = $00)) then
      begin
        delimPos := tfReadlnBufPos+2*i;
        delimLen := 8;
        break; //for i
      end
      else if ((AcceptedDelimiters = []) or (ldLFCR in AcceptedDelimiters)) and
              ((pb0^ = $0A) and (pb1^ = $00) and (pb2^ = $00) and(pb3^ = $00) and
               (pb4^ = $0D) and (pb5^ = $00) and (pb6^ = $00) and (pb7^ = $00)) then
      begin
        delimPos := tfReadlnBufPos+2*i;
        delimLen := 8;
        break; //for i
      end
      else if (((AcceptedDelimiters = []) or (ldCR in AcceptedDelimiters)) and (pb0^ = $0D) and (pb1^ = $00) and (pb2^ = $00) and (pb3^ = $00)) or
              (((AcceptedDelimiters = []) or (ldLF in AcceptedDelimiters)) and (pb0^ = $0A) and (pb1^ = $00) and (pb2^ = $00) and (pb3^ = $00)) then
      begin
        delimPos := tfReadlnBufPos+2*i;
        delimLen := 4;
        break; //for i
      end
      else if ((AcceptedDelimiters = []) or (ld2028 in AcceptedDelimiters)) and
              ((pb0^ = $28) and (pb1^ = $20) and (pb3^ = $00) and (pb4^ = $00)) then
      begin
        delimPos := tfReadlnBufPos+2*i;
        delimLen := 4;
        break; //for i
      end;
      Inc(pb0, 2);
      Inc(pb1, 2);
      Inc(pb2, 2);
      Inc(pb3, 2);
      Inc(pb4, 2);
      Inc(pb5, 2);
      Inc(pb6, 2);
      Inc(pb7, 2);
    end; //for
  end
  else begin
    for i := tfReadlnBufPos to tfReadlnBufSize do begin
      if ((AcceptedDelimiters = []) or (ldCRLF in AcceptedDelimiters)) and
         ((pb0^ = $0D) and (pb1^ = $0A)) then
      begin
        delimPos := i;
        delimLen := 2;
        break; //for i
      end
      else if ((AcceptedDelimiters = []) or (ldLFCR in AcceptedDelimiters)) and
               ((pb0^ = $0A) and (pb1^ = $0D)) then
      begin
        delimPos := i;
        delimLen := 2;
        break; //for i
      end
      else if (((AcceptedDelimiters = []) or (ldCR in AcceptedDelimiters)) and (pb0^ = $0D)) or
              (((AcceptedDelimiters = []) or (ldLF in AcceptedDelimiters)) and (pb0^ = $0A)) then
      begin
        delimPos := i;
        delimLen := 1;
        break; //for i
      end;
      Inc(pb0);
      Inc(pb1);
    end; //for
  end;
end; { TGpTextFile.LocateDelimiter }

{:Allocates small buffer if not already allocated.
  @since   2.01
}
procedure TGpTextFile.PrepareBuffer;
begin
  if not assigned(tfSmallBuf) then
    GetMem(tfSmallBuf,CtsSmallBufSize);
  tfReadlnBufPos := 0;
  tfReadlnBufSize := 0;    
end; { TGpTextFile.PrepareBuffer }

{:Create EOL string according to current flags.
  @since   2002-10-11
}        
procedure TGpTextFile.RebuildNewline;
begin
  if IsUnicode then begin
    if Codepage = CP_UTF8 then begin
      if cfUse2028 in tfCFlags then begin
        tfLineDelimiterSize := 3;
        // $2028 in UTF8 encoding
        tfLineDelimiter[0] := $E2;
        tfLineDelimiter[1] := $80;
        tfLineDelimiter[2] := $A8;
      end
      else begin
        tfLineDelimiterSize := 2;
        tfLineDelimiter[0] := $0D;
        tfLineDelimiter[1] := $0A;
      end;
    end
    else if Codepage = CP_UNICODE32 then begin
      if cfUse2028 in tfCFlags then begin
        tfLineDelimiterSize := 4;
        tfLineDelimiter[0] := $28;
        tfLineDelimiter[1] := $20;
        tfLineDelimiter[2] := $00;
        tfLineDelimiter[3] := $00;
      end
      else begin
        tfLineDelimiterSize := 8;
        tfLineDelimiter[0] := $0D;
        tfLineDelimiter[1] := $00;
        tfLineDelimiter[2] := $00;
        tfLineDelimiter[3] := $00;
        tfLineDelimiter[4] := $0A;
        tfLineDelimiter[5] := $00;
        tfLineDelimiter[6] := $00;
        tfLineDelimiter[7] := $00;
      end;
    end
    else begin
      if cfUse2028 in tfCFlags then begin
        tfLineDelimiterSize := 2;
        tfLineDelimiter[0] := $28;
        tfLineDelimiter[1] := $20;
      end
      else if cfUseLF in tfCFlags then begin
        tfLineDelimiterSize := 2;
        tfLineDelimiter[0] := $0A;
        tfLineDelimiter[1] := $00;
      end
      else begin
        tfLineDelimiterSize := 4;
        tfLineDelimiter[0] := $0D;
        tfLineDelimiter[1] := $00;
        tfLineDelimiter[2] := $0A;
        tfLineDelimiter[3] := $00;
      end;
    end;
  end
  else begin
    if cfUseLF in tfCFlags then begin
      tfLineDelimiterSize := 1;
      tfLineDelimiter[0] := $0A;
    end
    else begin
      tfLineDelimiterSize := 2;
      tfLineDelimiter[0] := $0D;
      tfLineDelimiter[1] := $0A;
    end
  end;
end; { TGpTextFile.RebuildNewline }

{:Reads line from file. If file is 8-bit, LF, CR, CRLF, and LFCR are considered
  end-of-line terminators (if included in AcceptedDelimiters).
  If file is 16-bit, both /000D/000A/ and /2028/ are considered end-of-line terminators
  (if included in AcceptedDelimiters).
  If file is 8-bit, line is converted to Unicode according to code page specified in
  Append, Reset or Rewrite.
  If file is 32-bit, high-end word of each character is stripped away.
  @returns Line without terminator characters.
  @raises  EGpHugeFile on Windows errors.
  @seeAlso Append, Reset, Rewrite
}
function TGpTextFile.Readln: WideStr;
var
  delimLen: cardinal;
  delimPos: cardinal;
  leftUtf8: integer;
  uniBytes: integer;
  utf8Ln  : AnsiString;
begin
  try
    if Codepage = CP_UTF8 then
      utf8Ln := ''
    else
      Result := '';
    repeat
      if IsAfterEndOfBlock then
        FetchBlock(tfLeof);
      if tfReadlnBufSize = 0 then
        break; //repeat
      LocateDelimiter(delimPos, delimLen);
      ConvertCodepage(delimPos, delimLen, utf8ln, Result);
    until tfLeof or (delimLen > 0);
    if Codepage = CP_UTF8 then begin
      if utf8Ln = '' then
        Result := ''
      else begin
        SetLength(Result, Length(utf8Ln)); // worst case
        uniBytes := UTF8BufToWideCharBuf(utf8Ln[1], Length(utf8Ln), Result[1], leftUtf8);
        SetLength(Result, uniBytes div SizeOf(WideChar));
      end;
    end;
  except
    on E: EGpTextFile do raise;
    on E: EGpHugeFile do raise;
    on E: Exception   do raise EGpTextFile.CreateHelp(E.Message, hcTFUnexpected);
  end;
end; { TGpTextFile.Readln }

{:Simplest form of Reset.
  @param   bufferSize Size of buffer. 0 means default size (BUF_SIZE, currently
                      64 KB).
  @param   flags      Open flags. 
  @param   codePage   Code page to be used for 8/16/8 bit conversion. If 0,
                      default code page for currently used language will be
                      used.
  @raises  EGpTextFile if file could not be reset.
}
procedure TGpTextFile.Reset(flags: TOpenFlags; bufferSize: integer; 
  codePage: word);
begin
  if ResetSafe(flags,bufferSize,0,0,0,codePage) <> hfOK then
    raise EGpTextFile.CreateFmtHelp(sFailedToResetFile,[FileName],hcTFFailedToReset);
end; { TGpTextFile.Reset }

{:Full form of Reset. Will retry if file is locked by another application (if
  diskLockTimeout and diskRetryDelay are specified). Allows caller to specify
  additional options. Does not raise an exception on error.
  @param   flags           Open flags.
  @param   bufferSize      Size of buffer. 0 means default size (BUF_SIZE,
                           currently 64 KB).
  @param   diskLockTimeout Max time (in milliseconds) Reset will wait for lock
                           file to become free.
  @param   diskRetryDelay  Delay (in milliseconds) between attempts to open
                           locked file.
  @param   waitObject      Handle of 'terminate' event (semaphore, mutex). If
                           this parameter is specified (not zero) and becomes
                           signalled, Reset will stop trying to open locked file
                           and will exit with.
  @param   codePage        Code page to be used for 8/16/8 bit conversion. If 0,
                           default code page for currently used language will be
                           used.
  @raises  EGpHugeFile on Windows errors.
}
function TGpTextFile.ResetSafe(flags: TOpenFlags; bufferSize: integer;
  diskLockTimeout, diskRetryDelay: integer; waitObject: THandle;
  codePage: word): THFError;
var
  marker : WideChar;
  marker3: AnsiChar;
  marker4: UCS4Char;
  options: THFOpenOptions;
begin
  try
    if flags * [ofCloseOnEOF, ofScanEntireFile] = [ofCloseOnEOF, ofScanEntireFile] then
      raise EGpTextFile.CreateFmtHelp(sCannotScanEntireFireWithCloseOnEOF, [FileName], hcTFInvalidParameter);
    SetCodepage(codePage);
    PrepareBuffer;
    options := [hfoBuffered];
    if ofCloseOnEOF in flags then
      options := options + [hfoCloseOnEOF];
    tfNo8BitCPConversion := ofNo8BitCPConversion in flags;
    Result := ResetEx(1, bufferSize, diskLockTimeout, diskRetryDelay, options, waitObject);
    if Result = hfOK then begin
      tfCFlags := [];
      if FileSize >= SizeOf(UCS4Char) then begin
        Seek(0);
        BlockReadUnsafe(marker4, SizeOf(UCS4Char));
        if marker4 = CUnicode32Normal then
          SetCodepage(CP_UNICODE32)
        else if marker4 = CUnicode32Reversed then begin
          SetCodepage(CP_UNICODE32);
          tfCFlags := tfCFlags + [cfReverseByteOrder];
        end;
      end;
      if (FileSize >= SizeOf(WideChar)) and (tfCodepage <> CP_UNICODE32) then begin
        Seek(0);
        BlockReadUnsafe(marker,SizeOf(WideChar));
        if marker = CUnicodeNormal then
          SetCodepage(CP_UNICODE)
        else if marker = CUnicodeReversed then begin
          SetCodepage(CP_UNICODE);
          tfCFlags := tfCFlags + [cfReverseByteOrder];
        end
        else if (marker = CUTF8BOM12) and (FileSize >= 3) then begin
          BlockReadUnsafe(marker3, SizeOf(AnsiChar));
          if marker3 = CUTF8BOM3 then
            SetCodepage(CP_UTF8);
        end;
        if (not IsUnicode) and (ofJSON in flags) then
          AutodetectJSON;
        if not IsUnicode then begin
          Seek(0);
          if not (ofNotUTF8Autodetect in flags) then
            AutodetectUTF8(ofScanEntireFile in flags);
        end;
      end;
      if (not IsUnicode) and IsUnicodeCodepage(Codepage) then
        tfCFlags := tfCFlags + [cfUnicode];
      RebuildNewline;
    end;
  except
    Result := hfError;
  end;
end; { TGpTextFile.ResetSafe }

{:Reverse prefetched block if file is in Motorola format.
  @since   2002-10-11
}
procedure TGpTextFile.ReverseBlock;
var
  i  : cardinal;
  pb : PByte;
  pb1: PByte;
  tmp: byte;
begin
  pb := @tfReadlnBuf[1];
  pb1 := pb;
  Inc(pb1);
  for i := 1 to tfReadlnBufSize div 2 do begin
    tmp := pb^;
    pb^ := pb1^;
    pb1^ := tmp;
    Inc(pb, 2);
    Inc(pb1, 2);
  end; //for
end; { TGpTextFile.ReverseBlock }

{:Simplest form of Rewrite.
  @param   flags      Create flags. 
  @param   bufferSize Size of buffer. 0 means default size (BUF_SIZE, currently
                      64 KB).
  @param   codePage   Code page to be used for 8/16/8 bit conversion. If 0,
                      default code page for currently used language will be
                      used.
  @raises  EGpTextFile if file could not be appended.
}
procedure TGpTextFile.Rewrite(flags: TCreateFlags; bufferSize: integer;
  codePage: word);
begin
  if RewriteSafe(flags,bufferSize,0,0,0,codePage) <> hfOK then
    raise EGpTextFile.CreateFmtHelp(sFailedToRewriteFile,[FileName],hcTFFailedToRewrite);
end; { TGpTextFile.Rewrite }

{:Full form of Rewrite. Will retry if file is locked by another application (if
  diskLockTimeout and diskRetryDelay are specified). Allows caller to specify
  additional options. Does not raise an exception on error.
  @param   flags           Create flags.
  @param   bufferSize      Size of buffer. 0 means default size (BUF_SIZE,
                           currently 64 KB).
  @param   diskLockTimeout Max time (in milliseconds) Rewrite will wait for
                           locked file to become free.
  @param   diskRetryDelay  Delay (in milliseconds) between attempts to open
                           locked file.
  @param   waitObject      Handle of 'terminate' event (semaphore, mutex). If
                           this parameter is specified (not zero) and becomes
                           signalled, Rewrite will stop trying to open locked
                           file and will exit with.
  @param   codePage        Code page to be used for 8/16/8 bit conversion. If 0,
                           default code page for currently used language will be
                           used.
  @raises  EGpTextFile if file is 'reversed' Unicode file.
  @raises  EGpHugeFile on Windows errors.
}
function TGpTextFile.RewriteSafe(flags: TCreateFlags; bufferSize: integer;
  diskLockTimeout, diskRetryDelay: integer; waitObject: THandle;
  codePage: word): THFError;
var
  options: THFOpenOptions;
begin
  if (cfUnicode in flags) and (codePage <> CP_UTF8) and (codePage <> CP_UNICODE32) then
    codePage := CP_UNICODE;
  PrepareBuffer;
  if IsUnicodeCodepage(Codepage) then 
    flags := flags + [cfUnicode];    
  if flags * [cfUnicode, cfReverseByteOrder] = [cfUnicode, cfReverseByteOrder] then
    raise EGpTextFile.CreateFmtHelp(sCannotWriteReversedUnicodeFile, [FileName], hcTFCannotWriteReversed);
  tfNo8BitCPConversion := cfNo8BitCPConversion in flags;
  try
    SetCodepage(codePage);
    options := [hfoBuffered];
    if cfCompressed in flags then
      Include(options,hfoCompressed);
    Result := RewriteEx(1, bufferSize, diskLockTimeout, diskRetryDelay, options, waitObject);
    if Result = hfOK then begin
      Truncate;
      tfCFlags := flags;
      if IsUnicode then begin
        if Codepage = CP_UNICODE32 then
          BlockWriteUnsafe(CUnicode32Normal, SizeOf(UCS4Char))
        else if Codepage <> CP_UTF8 then
          BlockWriteUnsafe(CUnicodeNormal, SizeOf(WideChar))
        else if cfWriteUTF8BOM in flags then begin
          BlockWriteUnsafe(CUTF8BOM12, SizeOf(WideChar));
          BlockWriteUnsafe(CUTF8BOM3, SizeOf(AnsiChar));
        end;
      end;
      RebuildNewline;
    end;
  except
    Result := hfError;
  end;
end; { TGpTextFile.RewriteSafe }

{:Internal method that sets current code page or locates default code page if
  0 is passed as a parameter.
  @param   cp Code page number or 0 for default code page.
}
procedure TGpTextFile.SetCodepage(cp: word);
begin
  if IsUnicodeCodepage(cp) then begin
    tfCodePage := cp;
    tfCFlags := tfCFlags + [cfUnicode];
  end
  else begin
    if (cp = 0) and (not IsUnicode) then
      tfCodePage := GetDefaultAnsiCodepage(GetSystemDefaultLCID and $FFFF, 1252)
    else
      tfCodePage := cp;                   
    if not ((tfCodePage = 0) or IsUnicodeCodepage(tfCodePage)) then
      tfCFlags := tfCFlags - [cfUnicode];
  end;
  RebuildNewline;
end; { TGpTextFile.SetCodepage }

{:Writes string to the text file.
  If file is 8-bit, string is converted according to Codepage property.
  If file is 32-bit, high-end word of each char is set to 0.
  @param   ws String to be written.
  @raises  EGpHugeFile on Windows errors.
}
procedure TGpTextFile.WriteString(ws: WideStr);
var
  ansiLn  : AnsiString;
  numBytes: integer;
  numChar : integer;
  tmpBuf  : pointer;
  tmpPtr  : PByte;
begin
  if ws = '' then
    Exit;
  if IsUnicode then begin
    if Codepage = CP_UTF8 then begin
      numChar := Length(ws);
      tmpBuf := AllocTmpBuffer(numChar*3); // worst case - 3 bytes per character
      try
        numBytes := WideCharBufToUTF8Buf(ws[1], Length(ws)*SizeOf(WideChar), tmpBuf^);
        BlockWriteUnsafe(tmpBuf^, numBytes);
      finally FreeTmpBuffer(tmpBuf); end;
    end
    else if codepage = CP_UNICODE32 then begin
      numBytes := Length(ws)*SizeOf(WideChar)*2;
      tmpBuf := AllocTmpBuffer(numBytes);
      try
        tmpPtr := tmpBuf;
        for numChar := 1 to Length(ws) do begin
          PWideChar(tmpPtr)^ := ws[numChar];
          Inc(tmpPtr, SizeOf(WideChar));
          PWideChar(tmpPtr)^ := #0;
          Inc(tmpPtr, SizeOf(WideChar));
        end;
        BlockWriteUnsafe(tmpBuf^, numBytes);
      finally FreeTmpBuffer(tmpBuf); end;
    end
    else
      BlockWriteUnsafe(ws[1], Length(ws)*SizeOf(WideChar))
  end
  else begin
    if tfNo8BitCPConversion then
      ansiLn := WideStringToStringNoCP(ws)
    else
      ansiLn := WideStringToString(ws, tfCodePage);
    BlockWriteUnsafe(ansiLn[1], Length(ansiLn));
  end;
end; { TGpTextFile.WriteString }

{:Writes array of values to the text file. If file is 8-bit, values are
  converted according to Codepage property.
  @param   Values.
  @raises  EGpTextFile on unsupported parameter.
  @raises  EGpHugeFile on Windows errors.
}
procedure TGpTextFile.Write(params: array of const);
var
  i     : integer;
  wideLn: WideStr;
const
  BoolChars: array [boolean] of char = ('F','T');
begin
  try
    wideLn := '';
    for i := 0 to High(params) do begin
      with params[i] do begin
        case VType of
          vtInteger:    wideLn := wideLn + IntToStr(VInteger);
          vtBoolean:    wideLn := wideLn + BoolChars[VBoolean];
          vtChar:                          StringToWideString(VChar, tfCodePage, wideLn);
          vtExtended:                      StringToWideString(AnsiString(FloatToStr(VExtended^)), tfCodePage, wideLn);
          vtString:                        StringToWideString(VString^, tfCodePage, wideLn);
          vtPointer:    wideLn := wideLn + IntToHex(integer(VPointer),8);
          vtPChar:                         StringToWideString(VPChar, tfCodePage, wideLn);
          vtObject:                        StringToWideString(AnsiString(VObject.ClassName), tfCodePage, wideLn);
          vtClass:                         StringToWideString(AnsiString(VClass.ClassName), tfCodePage, wideLn);
          vtWideChar:   wideLn := wideLn + VWideChar;
          vtPWideChar:  wideLn := wideLn + VPWideChar^;
          vtAnsiString:                    StringToWideString(AnsiString(VAnsiString), tfCodePage, wideLn);
          vtCurrency:                      StringToWideString(AnsiString(CurrToStr(VCurrency^)), tfCodePage, wideLn);
          vtVariant:                       StringToWideString(AnsiString(VVariant^), tfCodePage, wideLn);
          vtWideString: wideLn := wideLn + WideStr(VWideString);
          vtInt64:      wideLn := wideLn + IntToStr(VInt64^);
          {$IFDEF Unicode}
          vtUnicodeString: wideLn := wideLn + WideStr(VUnicodeString);
          {$ENDIF Unicode}
          else raise EGpTextFile.CreateFmtHelp(sInvalidParameter,[FileName],hcTFInvalidParameter);
        end;
      end;
    end;
    WriteString(wideLn);
  except
    on E: EGpTextFile do raise;
    on E: EGpHugeFile do raise;
    on E: Exception   do raise EGpTextFile.CreateHelp(E.Message,hcTFUnexpected);
  end;
end; { TGpTextFile.Write }

{$IFDEF D4plus}
procedure TGpTextFile.Write(const s: AnsiString);
begin
  WriteString(StringToWideString(s, GetAnsiCodePage));
end; { TGpTextFile.Write }

procedure TGpTextFile.Write(const ws: WideStr);
begin
  WriteString(ws);
end; { TGpTextFile.Write }

{:Writes array of values to the text file then terminates the line with line
  delimiter. If file is 8-bit, values are converted according to Codepage
  property. Uses line delimiter set in Rewrite/Append.
  @param   Values.
  @raises  EGpTextFile on unsupported parameter.
  @raises  EGpHugeFile on Windows errors.
  @seeAlso Rewrite, Append
}
procedure TGpTextFile.Writeln(params: array of const);
begin
  Write(params);
  Writeln;
end; { TGpTextFile.Writeln }

procedure TGpTextFile.Writeln(const s: AnsiString);
begin
  Writeln(StringToWideString(s, GetAnsiCodePage));
end; { TGpTextFile.Writeln }
{$ENDIF D4plus}

{:Writes line to the text file. If file is 8-bit, values are converted
  according to Codepage property. Uses line delimiter set in Rewrite/Append.
  @param   ln Line to be written.
  @raises  EGpHugeFile on Windows errors.
  @seeAlso Rewrite, Append
}
procedure TGpTextFile.Writeln(const ln: WideStr);
begin
  try
    WriteString(ln);
    BlockWriteUnsafe(tfLineDelimiter[Low(tfLineDelimiter)], tfLineDelimiterSize);
  except
    on E: EGpTextFile do raise;
    on E: EGpHugeFile do raise;
    on E: Exception   do raise EGpTextFile.CreateHelp(E.Message,hcTFUnexpected);
  end;
end; { TGpTextFile.Writeln }

{ TGpTextFileStream }

{:Opens file in required access mode, then passes the file stream to the
  inherited constructor.
  @param   fileName    Name of file to be accessed.
  @param   access      Required access mode.
  @param   openFlags   Open flags (used when access mode is accReset).
  @param   createFlags Create flags (used when access mode is accRewrite or
                       accAppend).
  @param   codePage    Code page to be used for 8/16/8 bit conversions. If set
                       to 0, current default code page will be used.
}
constructor TGpTextFileStream.Create(const fileName: string; access:
  TGpHugeFileStreamAccess; openFlags: TOpenFlags; createFlags: TCreateFlags;
  codePage: word; desiredShareMode: DWORD; diskLockTimeout: integer;
  diskRetryDelay: integer; waitObject: THandle);
var
  openOptions: THFOpenOptions;
  parseFlags : TGpTSParseFlags;
begin
  openOptions := [hfoBuffered];
  if (access = GpHugeF.accRead) and (ofCloseOnEOF in openFlags) then
    Include(openOptions,hfoCloseOnEOF);
  if cfCompressed in createFlags then
    Include(openOptions,hfoCompressed);
  tfsStream := TGpHugeFileStream.Create(fileName, access, openOptions, desiredShareMode,
    diskLockTimeout, diskRetryDelay, waitObject);
  parseFlags := [];
  if ofJSON in openFlags then
    Include(parseFlags, pfJSON);
  if ofNo8BitCPConversion in openFlags then
    Include(parseFlags, pfNo8BitCPConversion);
  inherited Create(tfsStream, TGpTSAccess(access), TGpTSCreateFlags(createFlags), codePage, parseFlags);
end; { TGpTextFileStream.Create }

constructor TGpTextFileStream.CreateFromHandle(hf: TGpHugeFile;
  access: TGpHugeFileStreamAccess; createFlags: TCreateFlags; codePage: word;
  openFlags: TOpenFlags);
var
  parseFlags : TGpTSParseFlags;
begin
  tfsStream := TGpHugeFileStream.CreateFromHandle(hf);
  parseFlags := [];
  if ofJSON in openFlags then
    Include(parseFlags, pfJSON);
  inherited Create(tfsStream, TGpTSAccess(access), TGpTSCreateFlags(createFlags), codePage, parseFlags);
end; { TGpTextFileStream.CreateFromHandle }

{:Wide version of the constructor.
  @since   2006-08-14
}
constructor TGpTextFileStream.CreateW(const fileName: WideStr; access:
  TGpHugeFileStreamAccess; openFlags: TOpenFlags; createFlags: TCreateFlags;
  codePage: word; desiredShareMode: DWORD; diskLockTimeout: integer;
  diskRetryDelay: integer; waitObject: THandle
  {$IFDEF D4plus}; dummy_param: boolean{$ENDIF});
var
  openOptions: THFOpenOptions;
  parseFlags : TGpTSParseFlags;
begin
  openOptions := [hfoBuffered];
  if (access = GpHugeF.accRead) and (ofCloseOnEOF in openFlags) then
    Include(openOptions,hfoCloseOnEOF);
  if cfCompressed in createFlags then
    Include(openOptions,hfoCompressed);
  tfsStream := TGpHugeFileStream.CreateW(fileName, access, openOptions, desiredShareMode,
    diskLockTimeout, diskRetryDelay, waitObject);
  parseFlags := [];
  if ofJSON in openFlags then
    Include(parseFlags, pfJSON);
  inherited Create(tfsStream, TGpTSAccess(access), TGpTSCreateFlags(createFlags), codePage, parseFlags);
end; { TGpTextFileStream.CreateW }

destructor TGpTextFileStream.Destroy;
begin
  inherited;
  tfsStream.Free;
end; { TGpTextFileStream.Destroy }

{:Returns file name.
  @returns Returns file name or empty string if file is not open.
}
function TGpTextFileStream.GetFileName: WideStr;
begin
  if assigned(tfsStream) then
    Result := tfsStream.FileName
  else
    Result := '';
end; { TGpTextFileStream.GetFileName }

{:Returns last Windows error code.
  @returns Last Windows error code.
}
function TGpTextFileStream.GetWindowsError: DWORD;
begin
  Result := inherited GetWindowsError;
  if (Result = 0) and assigned(tfsStream) then
    Result := tfsStream.WindowsError;
end; { TGpTextFileStream.GetWindowsError }

{:Returns error message prefix.
  @param   param Optional parameter to be added to the message prefix.
  @returns Error message prefix.
  @since   2001-05-15 (3.0)
}
function TGpTextFileStream.StreamName(param: string): string;
begin
  Result := 'TGpTextFileStream';
  if param <> '' then
    Result := Result + '.' + param;
  Result := Result + '(' + FileName + ')';
end; { TGpTextFileStream.StreamName }

end.



