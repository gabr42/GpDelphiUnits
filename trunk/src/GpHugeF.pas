{$B-,H+,J+,Q-,T-,X+}

unit GPHugeF;

(*:Interface to 64-bit file functions with some added functionality.
   @author Primoz Gabrijelcic
   @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2010, Primoz Gabrijelcic
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
   Creation date    : 1998-09-15
   Last modification: 2010-03-09
   Version          : 6.02a
</pre>*)(*
   History:
     6.02a: 2010-07-05
       - Compiles with OTL 2.0 pre-alpha.
     6.02: 2010-03-09
       - TGpHugeFileStream.Create and .CreateW got parameters waitObject and
         numPrefetchBuffers which are passed to ResetEx/RewriteEx.
     6.01: 2009-10-26
       - Number of buffers to prefetch can be set with a ResetEx parameter (defaults to 20).
     6.0d: 2009-08-18
       - Refactored TGpHugeFile.Fetch in an attempt to completely fix prefetcher problems.
     6.0c: 2009-08-02
       - Reduced number of Seek commands sent to the prefetcher.
       - Fixed a bug in prefetcher where internal state got out of sync with file position.
     6.0b: 2009-06-08
       - Due to a missing semicolon, data was not always moved into the prefetch cache
         when LogPrefetch was *not* defined.
       - Number of read bytes was sometimes returned incorrectly in prefetch mode.
     6.0a: 2009-05-14
       - Allow THFPrefetcher.Seek to fail silently.
     6.0: 2009-05-11
       - Implemented read prefetch, activated by setting hfoPrefetch option flag.
     5.05a: 2008-03-31
       - Optimization: Under some circumstances, lots of unnecessary SetFilePointer calls
         were made. Fixed.
     5.05: 2008-02-08
       - Delphi 2007 changed the implementation of CreateFmtHelp so that it clears the
         Win32 'last error'. Therefore, it was impossible to detect windows error in
         detection handler when EGpHugeFile help context was hcHFWindowsError.
         To circumvent the problem, all EGpHugeFile help contexts were changed to a
         negative value. HcHFWindowsError constant was removed. All Win32 API errors are
         passed in the HelpContext unchanged. IOW, if HelpContext > 0, it contains an
         Win32 API error code, otherwise it contains one of hcHF constants.
       - Added method TGpHugeFile.GetTime and property TGpHugeFile.FileTime.
     5.04a: 2007-10-10
       - GetFileSize Win32 call was incorrectly raising exception when file was
         $FFFFFFFF bytes long.
       - SetFilePointer Win32 call was incorrectly raising exception when position was
         set to $FFFFFFFF absolute.
     5.04: 2007-10-08
       - Added optional logging of all Win32 calls to the TGpHugeFile
         (enabled with /dLogWin32Calls).
     5.03: 2007-09-27
       - Added a way to disable buffering on the fly in both TGpHugeFile and
         TGpHugeFileStream.
       - Added thread concurrency debugging support to TGpHugeFileStream when compiled
         with /dDEBUG.
     5.02b: 2007-09-24
       - Better error reporting when application tries to read/write <= 0 bytes.
     5.02a: 2007-06-26
       - Don't call MsgWait... in Close if file access is not asynchronous as that causes
         havoc with MS thread pool execution.
     5.02: 2007-06-06
       - Added TGpHugeFileStream.Flush method.
       - Added bunch of missing Win32Check checks.
     5.01a: 2007-04-12
       - Fixed a bug where internal and external file pointer got out of sync in buffered
         write mode.
     5.01: 2007-01-11
       - Exposed underlying file's handle as a Handle property from the TGpHugeFileStream
         class.
     5.0: 2007-01-04
       - Added support for asynchronous writing.
     4.0b: 2006-10-31
       - Fixed compilation problems under D6.
     4.0a: 2006-08-17
       - Fixed compilation problems under D6-D2005.
     4.0: 2006-08-14
       - TGpHugeFile
         - Added new constructors CreateW and CreateExW that use Unicode encoding for the
           file name.
         - FileName property changed to WideString.
       - TGpHugeFileStream
         - Added new constructor CreateW that uses Unicode encoding for the file name.
         - FileName property changed to WideString.
     3.12a: 2006-04-25
       - Don't use FileDateToDateTime on Delphi 2006 and newer.
     3.12: 2004-03-24
       - Added parameters diskLockTimeout and diskRetryDelay to the TGpHugeFileStream
         constructor. Those parameters are passed to the TGpHugeFile.RewriteEx/ResetEx.
         Default value for those parameters - 0 - is the same that was previously sent to
         the RewriteEx/ResetEx.
     3.11: 2003-11-21
       - TGpHugeFileStream.Create constructor got parameter desiredShareMode, which is
         passed to the nested TGpHugeFile.CreateEx. Default value for this parameter -
         $FFFF - is the same that was previously sent to the CreateEx. Therefore, no old
         code should become broken because of this change.
     3.10: 2003-05-14
       - Compatible with Delphi 7.
     3.09a: 2003-02-12
       - Faster TGpHugeFile.EOF.
     3.09: 2003-02-12
       - EOF function added.
       - Seek in buffered write mode was not working. Fixed.
     3.08a: 2002-10-14
       - TGpHugeFileStream.Create failed when append mode was used and file did not exist.
         Fixed.
     3.08: 2002-04-24
       - File handle exposed through the Handle property.
       - Added THFOpenOption hfoCompressed.
     3.07a: 2001-12-15
       - Updated to compile with Delphi 6.
     3.07: 2001-07-02
       - Added TGpHugeFile.FileDate setter.
     3.06b: 2001-06-27
       - TGpHugeFile.FileSize function was returning wrong result when file was open for
         buffered write access.
     3.06a: 2001-06-24
       - Modified CreateEx behaviour - if DesiredShareMode is not set and file is open in
         GENERIC_READ mode, sharing will be set to FILE_SHARE_READ.
     3.06: 2001-06-22
       - Added parameter DesiredShareMode to the CreateEx constructor.
     3.05: 2001-02-27
       - Modified Reset and Rewrite methods to open file in buffered mode by default.
     3.04: 2001-01-31
       - All raised exceptions now have HelpContext set. All possible HelpContext values
         are enumerated in 'const' section at the very beginning of the unit. Thanks to
         Peter Evans for the suggestion.
     3.03: 2000-10-18
       - Fixed bugs in hfoCloseOnEOF support in TGpHugeFile.
     3.02: 2000-10-12
       - Fixed bugs in hfoCloseOnEOF support in TGpHugeFileStream.
     3.01: 2000-10-06
       - TGpHugeFileStream constructor now accepts THFOpenOptions parameter, which is
         passed to TGpHugeFile ResetEx/RewriteEx. Default open mode for stream files is
         now hfoBuffered.
       - TGpHugeFileStream constructor parameters are simpler - FlagsAndAttributes and
         DesiredAccess parameters are no longer present.
       - Added TGpHugeFileStream.CreateFromHandle constructor accepting instance of
         TGpHugeFile, which is then used for all stream access. This TGpHugeFile instance
         must already be created and open (Reset, Rewrite). It will not be destroyed in
         TGpHugeFileStream destructor.
       - Added read-only property TGpHugeFileStream.FileName.
       - Added read-only property TGpHugeFileStream.WindowsError.
       - Fully documented.
       - All language-dependant string constants moved to resourcestring section.
     3.0: 2000-10-03
       - Created TGpHugeFileStream - descendant of TStream that wraps TGpHugeFile.
         Although it does not support huge files fully (because of TStream limitations),
         you could still use it as a buffered file stream.
     2.33: 2000-09-04
       - TGpHugeFile now exposes WindowsError property, which is set to last Windows error
         wherever it is checked for.
     2.32: 2000-08-01
       - All raised exceptions converted to EGpHugeFile exceptions.
       - All windows exceptions are now caught and converted to EGpHugeFile exceptions.
       - If file is open in read buffered mode *and* is then seeked past EOF
         (Seek(FileSize)) *and* is then written into, it will switch to write buffered
         mode (previous versions of GpHugeFile raised exception under those conditions).
     2.31: 2000-05-15
       - Call to Truncate is now allowed in buffered write mode. It will cause buffer to
         be flushed, though.
     2.30a: 2000-05-15
       - Fix introduced in 2.29a sometimes caused BlockRead to return error even when
         there was some data present. This only happened when file was open for reading
         (via Reset) and then extended with BlockWrite.
     2.30: 2000-05-12
       - New property: IsBuffered. Returns true if file is open in buffered mode.
     2.29a: 2000-05-02
       - While reading near end of (buffered) file, ReadFile API was called much too
         often. Fixed.
     2.29: 2000-04-14
       - Added new ResetEx/RewriteEx parameter - waitObject. If not equal to zero,
         TGpHugeFile will check it periodically in the wait loop. If object becomes
         signalled, TGpHugeFile will stop trying to open the file and will return an
         error.
     2.28: 2000-04-12
       - Added new THFOpenOption: hfoCanCreate. Set it to allow ResetEx to create file
         when it does not exist.
     2.27: 2000-04-02
       - Added property FileDate.
     2.26a: 2000-03-07
       - Fixed bug in hfoCloseOnEOF processing.
     2.26: 2000-03-03
       - Added THFOpenOption hfoCloseOnEOF. If specified in a call to ResetEx TGpHugeFile
         will close file handle as soon as last block is read from the file. This will
         free file for other programs while main program may still read data from
         TGpHugeFile's buffer. {*}
         After the end of file is reached (and handle is closed):
           - FilePos may be used.
           - FileSize may be used.
           - Seek and BlockRead may be used as long as the request can be fulfilled from
             the buffer.
         Use of this option is not recommended when access to the file is random. {*}
         It was designed to use with sequential access to the file. hfoCloseOnEOF is
         ignored if hfoBuffered is not set. hfoCloseOnEOF is ignored if used in RewriteEx.
         {*} hfoCloseOnEOF can cope with a program that alternately calls BlockRead and
         Seek requests. When BlockRead reaches EOF, this condition will be marked but file
         handle will not be closed yet. Only when BlockRead is called again, file will be
         closed, but only if between those calls Seek did not invalidate the buffer (Seek
         that can be fulfilled from the buffer is OK). This works with programs that load
         a small buffer and then Seek somewhere in the middle of this buffer (like Readln
         function in TGpTextFile class).
     2.25a: 2000-02-19
       - Fixed bug where TGpHugeFile.Reset would create a file if file did not exist
         before. Thanks to Peter Evans for finding the bug and solution.
     2.25: 1999-12-29
       - Changed implementation of TGpHugeFile.ResetEx and TGpHugeFile.RewriteEx (called
         from all Reset* and Rewrite* functions). Before the change, they were closing and
         reopening the file - not a very good idea if you share a file between
         applications.
     2.24e: 1999-12-22
       - Fixed broken TGpHugeFile.IsOpen. Thanks for Phil Hodgson for finding this bug.
     2.24d: 1999-11-22
       - Fixed small problem in file access routines. They would continue trying to access
         a file event if returned error was not sharing or locking error.
     2.24c: 1999-11-20
       - Behaviour changed. If you open file with GENERIC_READ access, sharing mode will
         be set to FILE_SHARE_READ. 2.24b and older set sharing mode to 0 in all
         occasions.
     2.24b: 1999-11-06
       - Added (again) ResetBuffered and RewriteBuffered;
     2.24a: 1999-11-03
       - Fixed Reset and Rewrite.
     2.24: 1999-11-02
       - ResetBuffered and RewriteBuffered renamed to ResetEx and RewriteEx.
       - Parameters diskLockTimeout and diskRetryDelay added to ResetEx and RewriteEx.
     2.23: 1999-10-28
       - Compiles with D5.
     2.22: 1999-06-14
       - Better error reporting.
     2.21: 1998-12-21
       - Better error checking.
     2.2: 1998-12-14
       - New function IsOpen.
       - Lots of SetLastError(0) calls added.
     2.12: 1998-10-28
       - CreateEx enhanced.
     2.11: 1998-10-14
       - Error reporting in Block*Unsafe enhanced.
     2.1: 1998-10-13
       - FilePos works in buffered mode.
       - Faster FilePos in unbuffered mode.
       - Seek works in read buffered mode.
         - In FILE_FLAG_NO_BUFFERING mode Seek works only when offset is on a sector
           boundary.
         - Truncate works in read buffered mode (untested).
         - Dependance on MSString removed.
     2.0: 1998-10-08
       - Win32 API error checking.
       - Sequential access buffering (ResetBuffered, RewriteBuffered).
       - Buffered files can be safely accessed in FILE_FLAG_NO_BUFFERING mode.
       - New procedures BlockReadUnsafe, BlockWriteUnsafe.
     1.1: 1998-10-05
       - CreateEx constructor added.
         - can specify attributes (for example FILE_FLAG_SEQUENTIAL_SCAN)
       - D4 compatible.
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
  {$IF (RTLVersion >= 18)} // Delphi 2006 or newer
    {$DEFINE D10PLUS}
  {$IFEND}
  {$IF (CompilerVersion >= 18.5)} // Delphi 2007 or newer
    {$DEFINE D11PLUS}
  {$IFEND}
{$ENDIF}

{$UNDEF EnablePrefetchSupport}
{$IFDEF D11PLUS}{$DEFINE EnablePrefetchSupport}{$ENDIF}

{.$DEFINE LogWin32Calls} //enable to log Win32 API calls in TGpHugeFile
{$IFDEF LogWin32Calls}
  {$IFDEF CONDITIONALEXPRESSIONS}
    {$MESSAGE WARN 'TGpHugeFile Win32 API logging enabled'}
  {$ENDIF}
{$ENDIF LogWin32Calls}

{$IFDEF LogPrefetch}
  {$DEFINE UseLogger}
{$ENDIF LogPrefetch}

interface

uses
  SysUtils,
  Windows,
  Classes
  {$IFDEF EnablePrefetchSupport},
  OtlCommon,
  OtlComm,
  OtlTask,
  OtlTaskControl
  {$ENDIF EnablePrefetchSupport};

// HelpContext values for all raised exceptions
const
  //:Exception was handled and converted to EGpHugeFile but was not expected and is not categorised.
  hcHFUnexpected                         = -1000;
  //:Windows error.
//  hcHFWindowsError                     = -1001; // was replaced with actual Windows errors
  //:Unknown Windows error.
  hcHFUnknownWindowsError                = -1002;
  //:Invalid block size.
  hcHFInvalidBlockSize                   = -1003;
  //:Invalid file handle.
  hcHFInvalidHandle                      = -1004;
  //:Failed to allocate buffer.
  hcHFFailedToAllocateBuffer             = -1005;
  //:Write operation encountered while in buffered read mode.
  hcHFWriteInBufferedReadMode            = -1006;
  //:Read operation encountered while in buffered write mode.
  hcHFReadInBufferedWriteMode            = -1007;
  //:Unexpected end of file.
  hcHFUnexpectedEOF                      = -1008;
  //:Write failed - not all data was saved.
  hcHFWriteFailed                        = -1009;
  //:Invalid 'mode' parameter passed to Seek function.
  hcHFInvalidSeekMode                    = -1010;
  //:Asynchronous access only works in buffered write mode.
  hcHFAsyncWhileNotInBufferedWriteMode   = -1011;
  //:Trying to read <= 0 bytes.
  hcHFTryingToReadEmptyBuffer            = -1012;
  //:Trying to write <= 0 bytes.
  hcHFTryingToWriteEmptyBuffer           = -1013;
  //:Prefetch only works in buffered read mode.
  hcHFPrefetchWhileNotInBufferedReadMode = -1014;
  //:Prefetch is only supported in D2007+
  hcHFPrefetchNotSupported               = -1015;
  //:Cannot reopen file in prefetch mode.
  hcCannotReopenWithPrefetch             = -1016;

  CAutoShareMode = $FFFF;

type
  {:Alias for int64 so it is Delphi-version-independent (as much as that is
    possible at all).
  }
  HugeInt = LONGLONG;

{$IFDEF D4plus}
  {:D4 and newer define TLargeInteger as int64.
  }
  TLargeInteger = LARGE_INTEGER;
{$ENDIF}

  {:Base exception class for all exceptions raised in TGpHugeFile and
    descendants.
  }
  EGpHugeFile       = class(Exception);

  {:Base exception class for exceptions created in TGpHugeFileStream.
  }
  EGpHugeFileStream = class(EGpHugeFile);

  TGpHugeFile = class;

  {:Asynchronous file operation descriptor.
    @since   2006-12-21
  }
  TGpHFAsyncDescriptor = class
  private
    adBuffer    : pointer;
    adBufferSize: integer;
    adOverlapped: POverlapped;
    adOwner     : TGpHugeFile;
  public
    constructor Create(owner: TGpHugeFile; buffer: pointer; bufferSize: integer;
      filePosition: int64);
    destructor  Destroy; override;
    property Buffer: pointer read adBuffer;
    property BufferSize: integer read adBufferSize;
    property Overlapped: POverlapped read adOverlapped;
    property Owner: TGpHugeFile read adOwner;
  end; { TGpHFAsyncDescriptor }

  {:Prefetch cache interface.
  }
  IHFPrefetchCache = interface ['{CC1C78F5-7784-4728-BCBD-A546129A52BB}']
    procedure CancelIsReading(offset: HugeInt);
    function  ContainsBlock(offset: HugeInt): boolean;
    function  GetBlock(offset: HugeInt; outBuffer: pointer; var dataSize: cardinal): boolean;
    procedure InsertBlock(buffer: pointer; numberOfBytes: cardinal; offset: HugeInt);
    function  IsReadingBlock(offset: HugeInt): boolean;
    procedure NotifyIsReading(offset: HugeInt);
  end; { IHFPrefetchCache }

  {:Prefetch worker interface.
  }
  IHFPrefetcher = interface ['{BB0FA2F3-7426-4D4B-93C0-8E3043CFB120}']
    procedure Seek(offset: HugeInt);
  end; { IHFPrefetcher }

  {:Result of TGpHugeFile reset and rewrite methods.
    @enum hfOK         File opened successfully.
    @enum hfFileLocked Access to file failed because it is already open and
                       compatible sharing is not allowed.
    @enum hfError      Other file access errors (file/path not found...).
   }
  THFError = (hfOK, hfFileLocked, hfError);

  {:TGpHugeFile reset/rewrite options.
    @enum hfoBuffered     Open file in buffered mode. Buffer size is either default
                          (BUF_SIZE, currently 64 KB) or specified by the caller in
                          ResetEx or RewriteEx methods.
    @enum hfoLockBuffer   Buffer must be locked (Windows require that for direct access
                          files (FILE_FLAG_NO_BUFFERING) to work correctly).
    @enum hfoCloseOnEOF   Valid only when file is open for reading. If set, TGpHugeFile
                          will close file handle as soon as last block is read from the
                          file. This will free file for other programs while main program
                          may still read data from TGpHugeFile's buffer. (*)              <br>
                          After the end of file is reached (and handle is closed):        <ul><li>
                            FilePos may be used.                                          </li><li>
                            FileSize may be used.                                         </li><li>
                            Seek and BlockRead may be used as long as the request can be
                            fulfilled from the buffer.                                    </li></ul><br>
                          Use of this option is not recommended when access to the file is
                          random. (*) It was designed to use with sequential or almost
                          sequential access to the file. hfoCloseOnEOF is ignored if
                          hfoBuffered is not set. hfoCloseOnEOF is ignored if used in
                          RewriteEx.                                                      <br>
                          (*) hfoCloseOnEOF can cope with a program that alternately calls
                          BlockRead and Seek. When BlockRead reaches EOF, this condition
                          will be marked but file handle will not be closed yet. When
                          BlockRead is called again, file will be closed, but only if
                          between those calls Seek did not invalidate the buffer (Seek
                          that can be fulfilled from the buffer is OK). This works with
                          programs that load a small buffer and then Seek somewhere in the
                          middle of this buffer (like Readln function in TGpTextFile class
                          does).
    @enum hfoCanCreate    Reset is allowed to create a file if it doesn't exist.          <br>
    @enum hfoCompressed   Valid only when file is opened for writing. Will try
                          to set the "compressed" attribute (when running on NT
                          and file is on NTFS drive).                                     <br>
    @enum hfoAsynchronous Valid only when file is opened in buffered mode for writing.
                          All writes are executed asynchronously.                         <br>
    @enum hfoPrefetch     Valid only when file is opened in buffered mode for reading.
                          Background thread tries to sequentially prefetch data that will
                          be used to fill the cache.
  }
  THFOpenOption  = (hfoBuffered, hfoLockBuffer, hfoCloseOnEOF, hfoCanCreate,
                    hfoCompressed, hfoAsynchronous, hfoPrefetch);

  {:Set of all TGpHugeFile reset/rewrite options.
  }
  THFOpenOptions = set of THFOpenOption;

  {:Encapsulation of 64-bit file functions, supporting normal, buffered, and
    direct access with some additional twists.
  }
  TGpHugeFile = class
  private
    hfAsynchronous    : boolean;
    hfBlockSize       : DWORD;
    hfBuffer          : pointer;
    hfBuffered        : boolean;
    hfBufferSize      : DWORD;
    hfBufFileOffs     : HugeInt;
    hfBufFilePos      : HugeInt;
    hfBufOffs         : DWORD;
    hfBufSize         : DWORD;
    hfBufWrite        : boolean;
    hfCachedSize      : HugeInt;
    hfCanCreate       : boolean;
    hfCloseOnEOF      : boolean;
    hfCloseOnNext     : boolean;
    hfCompressed      : boolean;
    hfDesiredAcc      : DWORD;
    hfDesiredShareMode: DWORD;
    hfFlagNoBuf       : boolean;
    hfFlags           : DWORD;
    hfHalfClosed      : boolean;
    hfHandle          : THandle;
    hfIsOpen          : boolean;
    hfLastSize        : integer;
    hfLockBuffer      : boolean;
    hfName            : WideString;
    hfNameA           : string;
    hfPrefetch        : boolean;
    hfPrefetchCache   : IHFPrefetchCache;
    hfPrefetcher      : IHFPrefetcher;
    hfReading         : boolean;
    hfShareModeSet    : boolean;
    hfWin32LogLock    : THandle;
    hfWindowsError    : DWORD;
  protected
    function  _FilePos: HugeInt; virtual;
    function  _FileSize: HugeInt; virtual;
    procedure _Seek(offset: HugeInt; movePointer: boolean); virtual;
    function  AccessFile(blockSize: integer; reset: boolean; diskLockTimeout: integer;
      diskRetryDelay: integer; waitObject: THandle; numPrefetchBuffers: integer): THFError;
      virtual;
    procedure AllocBuffer; virtual;
    procedure AsyncWriteCompletion(errorCode, numberOfBytes: DWORD; asyncDescriptor:
      TGpHFAsyncDescriptor);
    procedure CheckHandle; virtual;
    function  Compress: boolean;
    procedure Fetch(var buf; count: DWORD; var transferred: DWORD);
    function  FixBufferSize(bufferSize: integer): DWORD;
    function  FlushBuffer: boolean; virtual;
    procedure FreeBuffer; virtual;
    function  GetDate: TDateTime; virtual;
    function  GetTime: int64; virtual;
    function  GetFileName: WideString;
    function  HFGetFileSize(handle: THandle; var size: TLargeInteger): boolean;
    function  HFSetFilePointer(handle: THandle; var distanceToMove: TLargeInteger;
      moveMethod: DWORD): boolean;
    procedure InitReadBuffer; virtual;
    procedure InitWriteBuffer; virtual;
    procedure InternalCreateEx(FlagsAndAttributes: DWORD; DesiredAccess: DWORD;
      DesiredShareMode: DWORD);
    function  IsUnicodeMode: boolean;
    function  LoadedToTheEOF: boolean; virtual;
    procedure Log32(const msg: string);
    function  ReadBlockFromPrefetch(var bufp: pointer; var count, transferred: DWORD): boolean;
    function  RoundToPageSize(bufSize: DWORD): DWORD; virtual;
    procedure SetDate(const value: TDateTime); virtual;
    procedure Transmit(const buf; count: DWORD; var transferred: DWORD); virtual;
    procedure Win32Check(condition: boolean; method: string); virtual;
  public
    constructor Create(fileName: string);
    constructor CreateEx(fileName: string;
      FlagsAndAttributes: DWORD {$IFDEF D4plus}= FILE_ATTRIBUTE_NORMAL{$ENDIF};
      DesiredAccess: DWORD      {$IFDEF D4plus}= GENERIC_READ+GENERIC_WRITE{$ENDIF};
      DesiredShareMode: DWORD   {$IFDEF D4plus}= CAutoShareMode{$ENDIF});
    constructor CreateExW(fileName: WideString;
      FlagsAndAttributes: DWORD {$IFDEF D4plus}= FILE_ATTRIBUTE_NORMAL{$ENDIF};
      DesiredAccess: DWORD      {$IFDEF D4plus}= GENERIC_READ+GENERIC_WRITE{$ENDIF};
      DesiredShareMode: DWORD   {$IFDEF D4plus}= CAutoShareMode{$ENDIF});
    constructor CreateW(fileName: WideString);
    procedure   Reset(blockSize: integer {$IFDEF D4plus}= 1{$ENDIF});
    procedure   Rewrite(blockSize: integer {$IFDEF D4plus}= 1{$ENDIF});
    procedure   ResetBuffered(
      blockSize: integer  {$IFDEF D4plus}= 1{$ENDIF};
      bufferSize: integer {$IFDEF D4plus}= 0{$ENDIF};
      lockBuffer: boolean {$IFDEF D4plus}= false{$ENDIF});
    procedure   RewriteBuffered(
      blockSize: integer  {$IFDEF D4plus}= 1{$ENDIF};
      bufferSize: integer {$IFDEF D4plus}= 0{$ENDIF};
      lockBuffer: boolean {$IFDEF D4plus}= false{$ENDIF});
    function    ResetEx(
      blockSize: integer          {$IFDEF D4plus}= 1{$ENDIF};
      bufferSize: integer         {$IFDEF D4plus}= 0{$ENDIF};
      diskLockTimeout: integer    {$IFDEF D4plus}= 0{$ENDIF};
      diskRetryDelay: integer     {$IFDEF D4plus}= 0{$ENDIF};
      options: THFOpenOptions     {$IFDEF D4plus}= []{$ENDIF};
      waitObject: THandle         {$IFDEF D4plus}= 0{$ENDIF};
      numPrefetchBuffers: integer {$IFDEF D4plus}= 20{$ENDIF}): THFError;
    function    RewriteEx(
      blockSize: integer          {$IFDEF D4plus}= 1{$ENDIF};
      bufferSize: integer         {$IFDEF D4plus}= 0{$ENDIF};
      diskLockTimeout: integer    {$IFDEF D4plus}= 0{$ENDIF};
      diskRetryDelay: integer     {$IFDEF D4plus}= 0{$ENDIF};
      options: THFOpenOptions     {$IFDEF D4plus}= []{$ENDIF};
      waitObject: THandle         {$IFDEF D4plus}= 0{$ENDIF}): THFError;
    destructor  Destroy; override;
    procedure BlockRead(var buf; count: DWORD; var transferred: DWORD);
    procedure BlockReadUnsafe(var buf; count: DWORD);
    procedure BlockWrite(const buf; count: DWORD; var transferred: DWORD);
    procedure BlockWriteUnsafe(const buf; count: DWORD);
    procedure Close;
    procedure DisableBuffering;
    function  EOF: boolean;
    function  FileExists: boolean;
    function  FilePos: HugeInt;
    function  FileSize: HugeInt;
    procedure Flush;
    function  IsOpen: boolean;
    procedure Seek(offset: HugeInt);
    procedure Truncate;
    //:File date/time.
    property FileDate: TDateTime read GetDate write SetDate;
    //:File date/time.
    property FileTime: int64 read GetTime;
    //:File name.
    property FileName: WideString read GetFileName;
    //:File handle.
    property Handle: THandle read hfHandle;
    //:True if access to file is buffered.
    property IsBuffered: boolean read hfBuffered;
    //:Last Windows error code.
    property WindowsError: DWORD read hfWindowsError;
  end; { TGpHugeFile }

  {:All possible ways to access TGpHugeFileStream.
    @enum accRead      Read access.
    @enum accWrite     Write access.
    @enum accReadWrite Read and write access.
    @enum accAppend    Same as accReadWrite, just that Position is set
                       immediatly after the end of file.
  }
  TGpHugeFileStreamAccess = (accRead, accWrite, accReadWrite, accAppend);

  {:TStream descendant, wrapping a TGpHugeFile. Although it does not support
    huge files fully (because of TStream limitations - 'longint' is used instead
    of 'int64' in critical places), you can still use it as a buffered file
    stream.
  }
  TGpHugeFileStream = class(TStream)
  private
    {$IFDEF DEBUG}
    hfsAttachedThread: DWORD;
    {$ENDIF DEBUG}
    hfsExternalHF    : boolean;
    hfsFile          : TGpHugeFile;
    hfsWindowsError  : DWORD;
  protected
    {$IFDEF DEBUG}
    procedure CheckOwner;
    {$ENDIF DEBUG}
    function  GetFileName: WideString; virtual;
    function  GetHandle: THandle;
    function  GetWindowsError: DWORD; virtual;
    procedure SetSize(newSize: longint); override;
    procedure Win32Check(condition: boolean; method: string); virtual;
    {$IFDEF D7PLUS}
    function  GetSize: int64; override;
    procedure SetSize(const newSize: int64); overload; override;
    procedure SetSize64(const newSize: int64);
    {$ELSE}
    function  GetSize: longint; virtual;
    {$ENDIF D7PLUS}
  public
    constructor Create(const fileName: string; access: TGpHugeFileStreamAccess;
      openOptions: THFOpenOptions {$IFDEF D4plus}= [hfoBuffered]{$ENDIF};
      desiredShareMode: DWORD     {$IFDEF D4plus}= CAutoShareMode{$ENDIF};
      diskLockTimeout: integer    {$IFDEF D4plus}= 0{$ENDIF};
      diskRetryDelay: integer     {$IFDEF D4plus}= 0{$ENDIF};
      waitObject: THandle         {$IFDEF D4plus}= 0{$ENDIF};
      numPrefetchBuffers: integer {$IFDEF D4plus}= 20{$ENDIF});
    constructor CreateFromHandle(hf: TGpHugeFile);
    constructor CreateW(const fileName: WideString; access: TGpHugeFileStreamAccess;
      openOptions: THFOpenOptions {$IFDEF D4plus}= [hfoBuffered]{$ENDIF};
      desiredShareMode: DWORD     {$IFDEF D4plus}= CAutoShareMode{$ENDIF};
      diskLockTimeout: integer    {$IFDEF D4plus}= 0{$ENDIF};
      diskRetryDelay: integer     {$IFDEF D4plus}= 0{$ENDIF};
      waitObject: THandle         {$IFDEF D4plus}= 0{$ENDIF};
      numPrefetchBuffers: integer {$IFDEF D4plus}= 20{$ENDIF});
    destructor  Destroy; override;
    {$IFDEF DEBUG}
    procedure AttachToThread;
    {$ENDIF DEBUG}
    procedure DisableBuffering;
    procedure Flush;
    function  Read(var buffer; count: longint): longint; override;
    function  Seek(offset: longint; mode: word): longint; {$IFDEF D7PLUS}overload;{$ENDIF D7PLUS} override;
    {$IFDEF D7PLUS}
    function  Seek(const offset: int64; origin: TSeekOrigin): int64; overload; override;
    {$ENDIF D7PLUS}
    function  Write(const buffer; count: longint): longint; override;
    //:Name of the underlying file.
    property FileName: WideString read GetFileName;
    //:Handle of the underlying file.
    property Handle: THandle read GetHandle;
    //:Stream size. Reintroduced to override GetSize (static in TStream) with faster version.
    {$IFDEF D7PLUS}
    property Size: int64 read GetSize write SetSize64;
    {$ELSE}
    property Size: longint read GetSize write SetSize;
    {$ENDIF D7PLUS}
    //:Last Windows error code.
    property WindowsError: DWORD read GetWindowsError;
  end; { TGpHugeFileStream }

implementation

uses
  SysConst,
  Messages,
  {$IFDEF LogWin32Calls}
  Math,
  {$ENDIF LogWin32Calls}
  DSiWin32,
  SpinLock,
  {$IFDEF UseLogger}
  GpLogger,
  {$ENDIF UseLogger}
  GpLists;

const
  //:Default buffer size. 64 KB, small enough to be VirtualLock'd in NT 4
  BUF_SIZE = 64*1024;

  //:Not defined in D2007 Windows.pas.
  INVALID_SET_FILE_POINTER = DWORD($FFFFFFFF);

{$IFDEF D3plus}
resourcestring
{$ELSE}
const
{$ENDIF}
  sAsyncWhileNotInBufferedWriteMode   = 'TGpHugeFile(%s): Asynchronous access only works in buffered write mode!';
  sBlockSizeMustBeGreaterThanZero     = 'TGpHugeFile(%s): BlockSize must be greater than zero!';
  sCannotReopenWithPrefetch           = 'TGpHugeFile(%s): Cannot reopen file in prefetch mode!';
  sFailedToAllocateBuffer             = 'TGpHugeFile(%s): Failed to allocate buffer!';
  sFileFailed                         = 'TGpHugeFile.%s(%s) failed. ';
  sFileNotOpen                        = 'TGpHugeFile(%s): File not open!';
  sPrefetchNotSupported               = 'TGpHugeFile(%s): Prefetch is supported only in D2007+';
  sPrefetchWhileNotInBufferedReadMode = 'TGpHugeFile(%s): Prefetch only works in buffered read mode';
  sReadWhileInBufferedWriteMode       = 'TGpHugeFile(%s): Read while in buffered write mode';
  sTryingToReadEmptyBuffer            = 'TGpHugeFile(%s) :Trying to read <= 0 bytes.';
  sTryingToWriteEmptyBuffer           = 'TGpHugeFile(%s): Trying to write <= 0 bytes.';
  sWriteFailed                        = 'TGpHugeFile(%s): Write failed!';
  sWriteWhileInBufferedReadMode       = 'TGpHugeFile(%s): Write while in buffered read mode!';

  sInvalidMode                        = 'TGpHugeFileStream(%s): Invalid mode!';
  sStreamFailed                       = 'TGpHugeFileStream.%s(%s) failed. ';

{$IFDEF EnablePrefetchSupport}
const
  WM_SEEK = WM_USER;

type
  TGpHugeFilePrefetch = class(TOmniWorker)
  strict private
    hfpBufferMap : TGpObjectMap;
    hfpBufferSize: cardinal;
    hfpCache     : IHFPrefetchCache;
    hfpHandle    : THandle;
    hfpNumBuffers: integer;
    hfpReadBlocks: integer;
  strict protected
    procedure CancelActiveRequests;
    function  FindNextReadOffset(blkOffset: int64): int64;
    function  OverlappedOffset(const overlapped: TOverlapped): int64; inline;
    procedure StartReadRequest(blkOffset: int64);
  protected
    procedure Cleanup; override;
    function  Initialize: boolean; override;
    procedure ReadCompletion(errorCode, numberOfBytes: DWORD; overlapped: POverlapped);
  public
    constructor Create;
    procedure Seek(var msg: TOmniMessage); message WM_SEEK;
  end; { TGpHugeFilePrefetch }

  THFCachedBlock = class
  strict private
    hfcbData  : pointer;
    hfcbOffset: int64;
    hfcbSize  : integer;
  protected
    procedure SetSize(const value: integer);
  public
    constructor Create(offset: HugeInt; bufferSize: integer);
    destructor  Destroy; override;
    property Data: pointer read hfcbData;
    property Offset: int64 read hfcbOffset write hfcbOffset;
    property Size: integer read hfcbSize write SetSize;
  end; { THFCachedBlock }

  THFPrefetchCache = class(TInterfacedObject, IHFPrefetchCache)
  strict private
    hfpcBufferSize : integer;
    hfpcCache      : TGpObjectRingBuffer;
    hfpcReadingList: TGpInt64List;
    hfpcReadingLock: TSpinLock;
  strict protected
    function  AddBlock(offset: int64): integer;
    function  GetCachedBlock(idxBlock: integer): THFCachedBlock;
    function  FindBlock(offset: int64): integer;
    function  WaitForBlock(offset: int64; wait_ms: integer): boolean;
    property Block[idxBlock: integer]: THFCachedBlock read GetCachedBlock;
  protected
    procedure CancelIsReading(offset: HugeInt);
    function  ContainsBlock(offset: HugeInt): boolean;
    function  GetBlock(offset: HugeInt; outBuffer: pointer; var dataSize: cardinal): boolean;
    procedure InsertBlock(buffer: pointer; numberOfBytes: cardinal; offset: HugeInt);
    function  IsReadingBlock(offset: HugeInt): boolean;
    procedure NotifyIsReading(offset: HugeInt);
  public
    constructor Create(bufferSize, numBuffers: integer);
    destructor  Destroy; override;
  end; { THFPrefetchCache }

  THFPrefetcher = class(TInterfacedObject, IHFPrefetcher)
  strict private
    hfpWorker: IOmniTaskControl;
  protected
    procedure Seek(offset: HugeInt);
  public
    constructor Create(const fileName: string; prefetchHandle: THandle; prefetchCache:
      IHFPrefetchCache; bufferSize: cardinal; numBuffers: integer);
    destructor  Destroy; override;
  end; { THFPrefetcher }

{$ENDIF EnablePrefetchSupport}

{ globals }

function CreatePrefetchCache(bufferSize, numBuffers: integer): IHFPrefetchCache;
begin
  {$IFNDEF EnablePrefetchSupport}
  Result := nil;
  {$ELSE}
  Result := THFPrefetchCache.Create(bufferSize, numBuffers);
  {$ENDIF EnablePrefetchSupport}
end; { CreatePrefetchCache }

function CreatePrefetchWorker(const fileName: string; prefetchHandle: THandle;
  prefetchCache: IHFPrefetchCache; bufferSize: cardinal;
  prefetchNumBuffers: integer): IHFPrefetcher;
begin
  {$IFNDEF EnablePrefetchSupport}
  raise EGpHugeFile.CreateFmtHelp(sPrefetchNotSupported, [fileName], hcHFPrefetchNotSupported);
  {$ELSE}
  Result := THFPrefetcher.Create(fileName, prefetchHandle, prefetchCache, bufferSize,
    prefetchNumBuffers);
  {$ENDIF EnablePrefetchSupport}
end; { CreatePrefetchWorker }

{$UNDEF NeedsHexStr}
{$IFDEF LogWin32Calls}{$DEFINE NeedsHexStr}{$ENDIF}
{$IFDEF LogPrefetch}{$DEFINE NeedsHexStr}{$ENDIF}
{$IFDEF NeedsHexStr}
function HexStr(const num; byteCount: Longint): string;
const
  Hex_Chars: array [0..15] of char = ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F');
var
  i   : integer;
  pRes: PChar;
  pB  : PByte;
  res  : string;
begin
  pB := @num;
  SetLength (res, 2*byteCount);
  if byteCount > 1 then inc (pB, byteCount-1);
  pRes := @res[1];
  for i := byteCount downto 1 do
  begin
    pRes^ := Hex_Chars[pB^ div 16]; Inc(pRes);
    pRes^ := Hex_Chars[pB^ mod 16]; Inc(pRes);
    dec (pB);
  end;
  HexStr := res;
end; { function HexStr }
{$ENDIF NeedsHexStr}

procedure HFAsyncWriteCompletion(errorCode, numberOfBytes: DWORD; overlapped: POverlapped); stdcall;
begin
  TGpHFAsyncDescriptor(overlapped.hEvent).Owner.AsyncWriteCompletion(errorCode,
    numberOfBytes, TGpHFAsyncDescriptor(overlapped.hEvent));
end; { HFAsyncWriteCompletion }

{ TGpHFAsyncDescriptor }

constructor TGpHFAsyncDescriptor.Create(owner: TGpHugeFile; buffer: pointer; bufferSize:
  integer; filePosition: int64);
begin
  inherited Create;
  adBufferSize := bufferSize;
  GetMem(adBuffer, bufferSize);
  Move(buffer^, adBuffer^, bufferSize);
  New(adOverlapped);
  adOverlapped.Offset := TLargeInteger(filePosition).LowPart;
  adOverlapped.OffsetHigh := TLargeInteger(filePosition).HighPart;
  adOverlapped.hEvent := THandle(Self);
  adOwner := owner;
end; { TGpHFAsyncDescriptor.Create }

destructor TGpHFAsyncDescriptor.Destroy;
begin
  FreeMem(adBuffer);
  Dispose(adOverlapped);
  inherited;
end; { TGpHFAsyncDescriptor.Destroy }

{ TGpHugeFile }

{:Standard TGpHugeFile constructor. Prepares file for full, share none, access.
  @param   fileName Name of file to be accessed.
}
constructor TGpHugeFile.Create(fileName: string);
begin
  hfWin32LogLock := CreateMutex(nil, false, '\Gp\TGpHugeFile\Win32Log\0B471316-65A0-44CC-B666-D9A28E4AE40B');
  CreateEx(fileName, FILE_ATTRIBUTE_NORMAL, GENERIC_READ+GENERIC_WRITE, 0);
  hfShareModeSet := false;
end; { TGpHugeFile.Create }

{:Extended TGpHugeFile constructor. Caller can specify desired flags,
  attributes, and access mode.
  @param   fileName           Name of file to be accessed.
  @param   FlagsAndAttributes Flags and attributes, see CreateFile help for more details.
  @param   DesiredAccess      Desired access flags, see CreateFile help for more details.
  @param   DesiredShareMode   Desired share mode. Defaults to 'automagically select a good
                              share mode'.
}
constructor TGpHugeFile.CreateEx(fileName: string; FlagsAndAttributes,
  DesiredAccess, DesiredShareMode: DWORD);
begin
  inherited Create;
  hfNameA := fileName;
  hfName := fileName;
  InternalCreateEx(FlagsAndAttributes, DesiredAccess, DesiredShareMode);
end; { TGpHugeFile.CreateEx }

constructor TGpHugeFile.CreateExW(fileName: WideString; FlagsAndAttributes, DesiredAccess,
  DesiredShareMode: DWORD);
begin
  inherited Create;
  hfNameA := '';
  hfName := fileName;
  InternalCreateEx(FlagsAndAttributes, DesiredAccess, DesiredShareMode);
end; { TGpHugeFile.CreateExW }

constructor TGpHugeFile.CreateW(fileName: WideString);
begin
  CreateExW(fileName, FILE_ATTRIBUTE_NORMAL, GENERIC_READ+GENERIC_WRITE, 0);
  hfShareModeSet := false;
end; { TGpHugeFile.CreateW }

{:TGpHugeFile destructor. Will close file if it is still open.
}
destructor TGpHugeFile.Destroy;
begin
  Close;
  CloseHandle(hfWin32LogLock);
  inherited Destroy;
end; { TGpHugeFile.Destroy }

{:Opens/creates a file. AccessFile centralizes file opening in TGpHugeFile. It
  will set appropriate sharing mode, open or create a file, and even retry in
  a case of locked file (if so required).
  @param   blockSize         Basic unit of access (same as RecSize parameter in Delphi's
                             Reset and Rewrite).
  @param   reset             True if file is to be reset, false if it is to be rewritten.
  @param   diskLockTimeout   Max time (in milliseconds) AccessFile will wait for lock file
                             to become free.
  @param   diskRetryDelay    Delay (in milliseconds) between attempts to open locked file.
  @param   waitObject        Handle of 'terminate' event (semaphore, mutex). If this
                             parameter is specified (not zero) and becomes signalled,
                             AccessFile will stop trying to open locked file and will exit
                             with status 'file locked'.
  @param   numPrefetchBuffer Number of buffers to prefetch (used only if hfoPrefetch
                             option is set).
  @returns Status (ok, file locked, other error).
  @raises  EGpHugeFile if 'blockSize' is less or equal to zero.
  @seeAlso ResetEx, RewriteEx
}
function TGpHugeFile.AccessFile(blockSize: integer; reset: boolean; diskLockTimeout:
  integer; diskRetryDelay: integer; waitObject: THandle; numPrefetchBuffers: integer): THFError;
const
  FILE_SHARING_ERRORS: set of byte = [ERROR_SHARING_VIOLATION, ERROR_LOCK_VIOLATION];
var
  awaited       : boolean;
  creat         : DWORD;
  prefetchHandle: THandle;
  shareMode     : DWORD;
  start         : int64;
begin
  if blockSize <= 0 then
    raise EGpHugeFile.CreateFmtHelp(sBlockSizeMustBeGreaterThanZero, [FileName], hcHFInvalidBlockSize);
  hfBlockSize := blockSize;
  start := GetTickCount;
  repeat
    if reset then begin
      if hfCanCreate then
        creat := OPEN_ALWAYS
      else
        creat := OPEN_EXISTING;
    end
    else
      creat := CREATE_ALWAYS;
    SetLastError(0);
    hfWindowsError := 0;
    if hfShareModeSet then begin
      if hfDesiredShareMode = CAutoShareMode then begin
        if hfDesiredAcc = GENERIC_READ then
          shareMode := FILE_SHARE_READ
        else
          shareMode := 0
      end
      else
        shareMode := hfDesiredShareMode
    end
    else begin                           
      if hfDesiredAcc = GENERIC_READ then
        shareMode := FILE_SHARE_READ
      else
        shareMode := 0;
    end;
    if hfAsynchronous and not (hfBuffered and hfBufWrite) then
      raise EGpHugeFile.CreateFmtHelp(sAsyncWhileNotInBufferedWriteMode, [FileName], hcHFAsyncWhileNotInBufferedWriteMode);
    if hfPrefetch and not (hfBuffered and (not hfBufWrite)) then
      raise EGpHugeFile.CreateFmtHelp(sPrefetchWhileNotInBufferedReadMode, [FileName], hcHFPrefetchWhileNotInBufferedReadMode);
    if hfAsynchronous then
      hfFlags := hfFlags OR FILE_FLAG_OVERLAPPED
    else
      hfFlags := hfFlags AND (NOT FILE_FLAG_OVERLAPPED);
    if hfPrefetch then begin
      shareMode := FILE_SHARE_READ;
      hfDesiredAcc := hfDesiredAcc AND NOT GENERIC_WRITE;
    end;
    if IsUnicodeMode then
      hfHandle := CreateFileW(PWideChar(hfName), hfDesiredAcc, shareMode, nil, creat, hfFlags, 0)
    else
      hfHandle := CreateFile(PChar(hfNameA), hfDesiredAcc, shareMode, nil, creat, hfFlags, 0);
    awaited := false;
    if hfHandle = INVALID_HANDLE_VALUE then begin
      hfWindowsError := GetLastError;
      if (hfWindowsError in FILE_SHARING_ERRORS) and (diskRetryDelay > 0) and (not DSiHasElapsed(start, diskLockTimeout)) then
        if waitObject <> 0 then
          awaited := WaitForSingleObject(waitObject, diskRetryDelay) <> WAIT_TIMEOUT
        else
          Sleep(diskRetryDelay);
    end
    else begin
      hfWindowsError := 0;
      hfIsOpen := true;
    end;
  until (hfWindowsError = 0) or (not (hfWindowsError in FILE_SHARING_ERRORS)) or
        DSiHasElapsed(start, diskLockTimeout) or awaited;
  if (hfWindowsError = 0) and hfCompressed then begin
    if not Compress then
      hfWindowsError := GetLastError;
  end;
  if hfWindowsError = 0 then begin
    Result := hfOK;
  end
  else if hfWindowsError in FILE_SHARING_ERRORS then
    Result := hfFileLocked
  else
    Result := hfError;
  if (Result = hfOK) and hfPrefetch then begin
    if IsUnicodeMode then
      prefetchHandle := CreateFileW(PWideChar(hfName), hfDesiredAcc, shareMode, nil, creat, hfFlags OR FILE_FLAG_OVERLAPPED, 0)
    else
      prefetchHandle := CreateFile(PChar(hfNameA), hfDesiredAcc, shareMode, nil, creat, hfFlags OR FILE_FLAG_OVERLAPPED, 0);
    if prefetchHandle = INVALID_HANDLE_VALUE then begin
      hfWindowsError := GetLastError;
      Result := hfError;
    end
    else begin
      hfPrefetchCache := CreatePrefetchCache(hfBufferSize, numPrefetchBuffers);
      hfPrefetcher := CreatePrefetchWorker(FileName, prefetchHandle, hfPrefetchCache,
        hfBufferSize, numPrefetchBuffers);
    end;
  end;
  if Result = hfOK then
    AllocBuffer;
end; { TGpHugeFile.AccessFile }

procedure TGpHugeFile.DisableBuffering;
var
  position: int64;
begin
  position := FilePos;
  FlushBuffer;
  hfBuffered := false;
  Seek(position);
end; { TGpHugeFile.DisableBuffering }

{:Tests if a specified file exists.
  @returns True if file exists.
}
function TGpHugeFile.FileExists: boolean;
begin
  if IsUnicodeMode then
    FileExists := DSiFileExistsW(FileName)
  else
    FileExists := SysUtils.FileExists(FileName);
end; { TGpHugeFile.FileExists }

{:Simplest form of Reset, emulating Delphi's Reset.
  @param   blockSize Basic unit of access (same as RecSize parameter in Delphi's Reset and
                     Rewrite).
  @raises  EGpHugeFile if file could not be opened.
}
procedure TGpHugeFile.Reset(blockSize: integer);
begin
  Win32Check(ResetEx(blockSize, 0, 0, 0, [hfoBuffered]) = hfOK, 'Reset');
end; { TGpHugeFile.Reset }

{:Simplest form of Rewrite, emulating Delphi's Rewrite.
  @param   blockSize Basic unit of access (same as RecSize parameter in Delphi's Rewrite).
  @raises  EGpHugeFile if file could not be opened.
}
procedure TGpHugeFile.Rewrite(blockSize: integer);
begin
  Win32Check(RewriteEx(blockSize, 0, 0, 0, [hfoBuffered]) = hfOK, 'Rewrite');
end; { TGpHugeFile.Rewrite }

{:Buffered Reset. Caller can specifiy size of buffer and require that buffer is locked in
  memory (Windows require that for direct access files (FILE_FLAG_NO_BUFFERING) to work
  correctly).
  @param   blockSize  Basic unit of access (same as RecSize parameter in Delphi's Reset).
  @param   bufferSize Size of buffer. 0 means default size (BUF_SIZE, currently 64 KB).
  @param   lockBuffer If true, buffer will be locked.
  @raises  EGpHugeFile if file could not be opened.
  @seeAlso BUF_SIZE
}
procedure TGpHugeFile.ResetBuffered(blockSize, bufferSize: integer; lockBuffer: boolean);
var
  options: THFOpenOptions;
begin
  options := [hfoBuffered];
  if lockBuffer then
    Include(options, hfoLockBuffer);
  Win32Check(ResetEx(blockSize, bufferSize, 0, 0, options) = hfOK, 'ResetBuffered');
end; { TGpHugeFile.ResetBuffered }

{:Buffered Rewrite. Caller can specify size of buffer and require that buffer is locked in
  memory (Windows require that for direct access files (FILE_FLAG_NO_BUFFERING) to work
  correctly).
  @param   blockSize  Basic unit of access (same as RecSize parameter in Delphi's Rewrite).
  @param   bufferSize Size of buffer. 0 means default size (BUF_SIZE, currently 64 KB).
  @param   lockBuffer If true, buffer will be locked.
  @raises  EGpHugeFile if file could not be opened.
  @seeAlso BUF_SIZE
}
procedure TGpHugeFile.RewriteBuffered(blockSize, bufferSize: integer; lockBuffer:
  boolean);
var
  options: THFOpenOptions;
begin
  options := [hfoBuffered];
  if lockBuffer then
    Include(options, hfoLockBuffer);
  Win32Check(RewriteEx(blockSize, bufferSize, 0, 0, options) = hfOK, 'RewriteBuffered');
end; { TGpHugeFile.RewriteBuffered }

{:Full form of Reset. Will retry if file is locked by another application (if
  diskLockTimeout and diskRetryDelay are specified). Allows caller to specify additional
  options. Does not raise an exception on error.
  @param   blockSize         Basic unit of access (same as RecSize parameter in Delphi's
                             Reset).
  @param   bufferSize        Size of buffer. 0 means default size (BUF_SIZE, currently
                             64 KB).
  @param   diskLockTimeout   Max time (in milliseconds) AccessFile will wait for lock file
                             to become free.
  @param   diskRetryDelay    Delay (in milliseconds) between attempts to open locked file.
  @param   options           Set of possible open options.
  @param   waitObject        Handle of 'terminate' event (semaphore, mutex). If this
                             parameter is specified (not zero) and becomes signalled,
                             AccessFile will stop trying to open locked file and will exit
                             with status 'file locked'.
  @param   numPrefetchBuffer Number of buffers to prefetch (used only if hfoPrefetch
                             option is set).
  @returns Status (ok, file locked, other error).
}
function TGpHugeFile.ResetEx(blockSize, bufferSize: integer; diskLockTimeout: integer;
  diskRetryDelay: integer; options: THFOpenOptions; waitObject: THandle;
  numPrefetchBuffers: integer): THFError;
begin
  hfWindowsError := 0;
  try
    { There's a reason behind this 'if IsOpen...' behaviour. We definitely don't want to
      release file handle if ResetEx is called twice in a row as that could lead to all
      sorts of sharing problems.
      Delphi does this wrong - if you Reset a file twice in a row, handle will be closed
      and file will be reopened.
    }
    if (hfCloseOnEOF or hfAsynchronous) and IsOpen then
      Close;
    if IsOpen then begin
      if not hfReading then begin
        {$IFDEF LogWin32Calls}Log32('FlushBuffer');{$ENDIF LogWin32Calls}
        Win32Check(FlushBuffer, 'ResetEx');
      end;
      hfBuffered := false;
      Seek(0);
      FreeBuffer;
    end;
    hfBuffered := hfoBuffered in options;
    hfCloseOnEOF := ([hfoCloseOnEOF, hfoBuffered] * options) = [hfoCloseOnEOF, hfoBuffered];
    hfCanCreate := hfoCanCreate in options;
    if hfBuffered then begin
      hfBufferSize := FixBufferSize(bufferSize);
      hfLockBuffer := hfoLockBuffer in options;
    end;
    hfAsynchronous := hfoAsynchronous in options;
    hfPrefetch := hfoPrefetch in options;
    hfBufWrite := false;
    if not IsOpen then
      Result := AccessFile(blockSize, true, diskLockTimeout, diskRetryDelay, waitObject, numPrefetchBuffers)
    else begin
      if hfPrefetch then
        raise EGpHugeFile.CreateFmtHelp(sCannotReopenWithPrefetch, [FileName], hcCannotReopenWithPrefetch); 
      hfBlockSize := blockSize;
      AllocBuffer;
      Result := hfOK;
    end;
    if Result <> hfOK then
      Close
    else begin
      if hfBuffered then
        InitReadBuffer;
      hfBufFilePos := 0;
      hfReading := true;
      hfHalfClosed := false;
    end;
  except
    Result := hfOK;
  end;
end; { TGpHugeFile.ResetEx }

{:Full form of Rewrite. Will retry if file is locked by another application (if
  diskLockTimeout and diskRetryDelay are specified). Allows caller to specify additional
  options. Does not raise an exception on error.
  @param   blockSize       Basic unit of access (same as RecSize parameter in Delphi's Rewrite).
  @param   bufferSize      Size of buffer. 0 means default size (BUF_SIZE, currently 64 KB).
  @param   diskLockTimeout Max time (in milliseconds) AccessFile will wait for lock file
                           to become free.
  @param   diskRetryDelay  Delay (in milliseconds) between attempts to open locked file.
  @param   options         Set of possible open options.
  @param   waitObject      Handle of 'terminate' event (semaphore, mutex). If this
                           parameter is specified (not zero) and becomes signalled,
                           AccessFile will stop trying to open lockedfile and will exit
                           with status 'file locked'.
  @returns Status (ok, file locked, other error).
}
function TGpHugeFile.RewriteEx(blockSize, bufferSize: integer; diskLockTimeout: integer;
  diskRetryDelay: integer; options: THFOpenOptions; waitObject: THandle): THFError;
begin
  hfWindowsError := 0;
  try
    { There's a reason behind this 'if IsOpen...' behaviour. We definitely don't want to
      release file handle if ResetEx is called twice in a row as that could lead to all
      sorts of sharing problems.
      Delphi does this wrong - if you Rewrite file twice in a row, handle will be closed
      and file will be reopened.
    }
    if hfCloseOnEOF and IsOpen then
      Close; //2.26
    if IsOpen then begin
      hfBuffered := false;
      Seek(0);
      Truncate;
      FreeBuffer;
    end;
    hfBuffered := hfoBuffered in options;
    if hfBuffered then begin
      hfBufferSize := FixBufferSize(bufferSize);
      hfLockBuffer := hfoLockBuffer in options;
    end;
    hfCompressed := hfoCompressed in options;
    hfAsynchronous := hfoAsynchronous in options;
    hfPrefetch := hfoPrefetch in options;
    if hfBuffered then
      hfBufWrite := true;
    if not IsOpen then
      Result := AccessFile(blockSize, false, diskLockTimeout, diskRetryDelay, waitObject, 0)
    else begin
      if hfPrefetch then
        raise EGpHugeFile.CreateFmtHelp(sCannotReopenWithPrefetch, [FileName], hcCannotReopenWithPrefetch); 
      hfBlockSize := blockSize;
      AllocBuffer;
      Result := hfOK;
    end;
    if Result <> hfOK then
      Close
    else begin
      if hfBuffered then
        InitWriteBuffer;
      hfBufFilePos := 0;
      hfReading := false;
      hfHalfClosed := false;
    end;
  except
    Result := hfOK;
  end;
end; { TGpHugeFile.RewriteEx }

{:Closes open file. If file is not open, do nothing.
  @raises  EGpHugeFile on Windows errors.
}
procedure TGpHugeFile.Close;
begin
  try
    if IsOpen then begin
      FreeBuffer;
      if hfAsynchronous then
        MsgWaitForMultipleObjectsEx(0, PChar(nil)^, 0, 0, MWMO_ALERTABLE);
      if hfHandle <> INVALID_HANDLE_VALUE then begin // may be freed in BlockRead
        CloseHandle(hfHandle);
        hfHandle := INVALID_HANDLE_VALUE;
      end;
      hfHalfClosed := false;
      hfIsOpen := false;
      hfCloseOnEOF := false;
    end;
    hfPrefetcher := nil;
    hfPrefetchCache := nil;
  except
    on EGpHugeFile do
      raise;
    on E:Exception do
      raise EGpHugeFile.CreateHelp(E.Message, hcHFUnexpected);
  end;
end; { TGpHugeFile.Close }

{:Checks if file is open. Called from various TGpHugeFile methods.
  @raises  EGpHugeFile if file is not open.
}
procedure TGpHugeFile.CheckHandle;
begin
  if hfHandle = INVALID_HANDLE_VALUE then
    raise EGpHugeFile.CreateFmtHelp(sFileNotOpen, [FileName], hcHFInvalidHandle);
end; { TGpHugeFile.CheckHandle }

{:Returns the size of file in 'block size' units (see 'blockSize' parameter to Reset and
  Rewrite methods).
  @returns Size of file in 'block size' units.
  @raises  EGpHugeFile on Windows errors.
  @seeAlso Reset, Rewrite
}
function TGpHugeFile.FileSize: HugeInt;
var
  realSize: HugeInt;
  size    : TLargeInteger;
begin
  try
    if hfHalfClosed then
      Result := hfLastSize //2.26: hfoCloseOnEOF support
    else begin
      CheckHandle;
      {$IFDEF LogWin32Calls}Log32('GetFileSize');{$ENDIF LogWin32Calls}
      SetLastError(0);
      Win32CHeck(HFGetFileSize(hfHandle, size), 'FileSize');
      if hfBufFilePos > size.QuadPart then
        realSize := hfBufFilePos
      else
        realSize := size.QuadPart;
      if hfBlockSize <> 1 then
        Result := {$IFDEF D4plus}Trunc{$ELSE}int{$ENDIF}(realSize/hfBlockSize)
      else
        Result := realSize;
    end;
  except
    on EGpHugeFile do
      raise;
    on E:Exception do
      raise EGpHugeFile.CreateHelp(E.Message,hcHFUnexpected);
  end;
end; { TGpHugeFile.FileSize }

{:Writes 'count' number of 'block size' large units (see 'blockSize' parameter to Reset
  and Rewrite methods) to a file (or buffer if access is buffered).
  @param   buf         Data to be written.
  @param   count       Number of 'block size' large units to be written.
  @param   transferred (out) Number of 'block size' large units actually written.
  @raises  EGpHugeFile on Windows errors.
  @seeAlso Reset, Rewrite
}
procedure TGpHugeFile.BlockWrite(const buf; count: DWORD; var transferred: DWORD);
var
  trans: DWORD;
  {$IFDEF LogWin32Calls}
  oldPos: int64;
  {$ENDIF LogWin32Calls}
begin
  if count = 0 then
    raise EGpHugeFileStream.CreateFmtHelp(sTryingToWriteEmptyBuffer, [FileName],
      hcHFTryingToReadEmptyBuffer);
  try
    CheckHandle;
    if hfBlockSize <> 1 then
      count := count * hfBlockSize;
    if hfBuffered then
      Transmit(buf, count, trans)
    else begin
      {$IFDEF LogWin32Calls}oldPos := int64(_FilePos);{$ENDIF LogWin32Calls}
      SetLastError(0);
      Win32Check(WriteFile(hfHandle, buf, count, trans, nil), 'BlockWrite');
      {$IFDEF LogWin32Calls}Log32(Format('WriteFile|%d|%d|%d|%s', [count, trans, oldPos, HexStr(buf, Min(count, 8))]));{$ENDIF LogWin32Calls}
      hfBufFilePos := hfBufFilePos + trans;
    end;
    if hfBlockSize <> 1 then
      transferred := trans div hfBlockSize
    else
      transferred := trans;
    hfCachedSize := -1;
  except
    on EGpHugeFile do
      raise;
    on E:Exception do
      raise EGpHugeFile.CreateHelp(E.Message, hcHFUnexpected);
  end;
end; { TGpHugeFile.BlockWrite }

{:Reads 'count' number of 'block size' large units (see 'blockSize' parameter to Reset and
  Rewrite methods) from a file (or buffer if access is buffered).
  @param   buf         Buffer for read data.
  @param   count       Number of 'block size' large units to be read.
  @param   transferred (out) Number of 'block size' large units actually read.
  @raises  EGpHugeFile on Windows errors.
  @seeAlso Reset, Rewrite
}
procedure TGpHugeFile.BlockRead(var buf; count: DWORD; var transferred: DWORD);
var
  closeNow  : boolean;
  oldBufSize: DWORD;
  trans     : DWORD;
  {$IFDEF LogWin32Calls}
  oldPos    : int64;
  {$ENDIF LogWin32Calls}
begin
  if count = 0 then
    raise EGpHugeFileStream.CreateFmtHelp(sTryingToReadEmptyBuffer, [FileName],
      hcHFTryingToReadEmptyBuffer);
  try
    if (not hfBuffered) or (not hfHalfClosed) then 
      CheckHandle;
    closeNow := hfCloseOnNext;
    if hfBlockSize <> 1 then
      count := count * hfBlockSize;
    oldBufSize := hfBufSize;
    if hfBuffered then
      Fetch(buf, count, trans)
    else begin
      {$IFDEF LogWin32Calls}oldPos := int64(_FilePos);{$ENDIF LogWin32Calls}
      SetLastError(0);
      Win32Check(ReadFile(hfHandle, buf, count, trans, nil), 'BlockRead');
      {$IFDEF LogWin32Calls}Log32(Format('ReadFile|%d|%d|%d|%s', [count, trans, oldPos, HexStr(buf, Min(count, 8))]));{$ENDIF LogWin32Calls}
      hfBufFilePos := hfBufFilePos + trans;
    end;
    if hfBlockSize <> 1 then
      transferred := trans div hfBlockSize
    else
      transferred := trans;
    if hfCloseOnEOF then begin
      if closeNow then begin
        if _FilePos >= FileSize then begin
          hfLastSize := FileSize;
          CloseHandle(hfHandle);
          hfHandle := INVALID_HANDLE_VALUE;
          hfHalfClosed := true; // allow FilePos to work until TGpHugeFile.Close
          hfCloseOnNext := false;
          //3.03: reset the buffer pointer
          hfBufOffs := hfBufOffs + (oldBufSize - hfBufSize);
          //2.26: rewind the buffer for Seek to work
          hfBufSize := oldBufSize;
        end;
      end
      else
        hfCloseOnNext := (hfHandle <> INVALID_HANDLE_VALUE) and LoadedToTheEOF;
    end;
  except
    on EGpHugeFile do
      raise;
    on E:Exception do
      raise EGpHugeFile.CreateHelp(E.Message, hcHFUnexpected);
  end;
end; { TGpHugeFile.BlockRead }

{:Internal implementation of Seek method. Called from other methods, too. Moves actual
  file pointer only when necessary or required by caller. Handles hfoCloseOnEOF files if
  possible.
  @param   offset      Offset from beginning of file in 'block size' large units (see
                       'blockSize' parameter to Reset and Rewrite methods).
  @param   movePointer If true, Windows file pointer will always be moved. If false, it
                       will only be moved when Seek destination does not lie in the buffer.
  @raises  Various system exceptions.
  @seeAlso Reset, Rewrite
}
procedure TGpHugeFile._Seek(offset: HugeInt; movePointer: boolean);
var
  off: TLargeInteger;
begin
  if (not hfBuffered) or movePointer or (not hfHalfClosed) then
    CheckHandle;
  if hfBlockSize <> 1 then
    off.QuadPart := offset*hfBlockSize
  else
    off.QuadPart := offset;
  if hfBuffered then begin
    if hfBufWrite then begin
      {$IFDEF LogWin32Calls}Log32('FlushBuffer');{$ENDIF LogWin32Calls}
      Win32Check(FlushBuffer, '_Seek');
      //Cope with the delayed seek
      if not hfAsynchronous then begin
        {$IFDEF LogWin32Calls}Log32(Format('SetFilePointer|%d', [int64(off)]));{$ENDIF LogWin32Calls}
         Win32Check(HFSetFilePointer(hfHandle, off, FILE_BEGIN), '_Seek');
      end;
    end
    else begin
      if not movePointer then begin
        if ((off.QuadPart < hfBufFileOffs) and (off.QuadPart >= (hfBufFileOffs-hfBufSize))) or
           ((off.QuadPart = hfBufFileOffs) and (hfBufSize = 0))
        then
          hfBufOffs := {$IFNDEF D4plus}Trunc{$ENDIF}(off.QuadPart-(hfBufFileOffs-hfBufSize))
        else
          movePointer := true;
      end;
      if movePointer then begin
        if hfHalfClosed then begin
          if off.QuadPart <> hfBufFileOffs then 
            CheckHandle; // bang!
        end
        else begin
          {$IFDEF LogWin32Calls}Log32(Format('SetFilePointer|%d', [int64(off)]));{$ENDIF LogWin32Calls}
          SetLastError(0);
          Win32Check(HFSetFilePointer(hfHandle, off, FILE_BEGIN), '_Seek');
        end;
        if not (hfHalfClosed and (off.QuadPart = hfBufFileOffs)) then begin
          hfBufFileOffs := off.QuadPart;
          hfBufFilePos  := off.QuadPart;
          hfBufOffs     := 0;
          hfBufSize     := 0;
          hfCloseOnNext := false;
        end;
      end
      else if not LoadedToTheEOF then
        hfCloseOnNext := false;
    end;
  end
  else begin
    {$IFDEF LogWin32Calls}Log32(Format('SetFilePointer|%d', [int64(off)]));{$ENDIF LogWin32Calls}
    SetLastError(0);
    Win32Check(HFSetFilePointer(hfHandle, off, FILE_BEGIN), 'Seek');
  end;
  hfBufFilePos := off.QuadPart;
  if movePointer or hfAsynchronous then
    hfBufFileOffs := hfBufFilePos;
end; { TGpHugeFile._Seek }

{:Repositions file pointer. Moves actual file pointer only when necessary.
  @param   offset Offset from beginning of file in 'block size' large units (see
           'blockSize' parameter to Reset and Rewrite methods).
  @raises  EGpHugeFile on Windows errors.
  @seeAlso Reset, Rewrite
}
procedure TGpHugeFile.Seek(offset: HugeInt);
begin
  try
    _Seek(offset, false);
  except
    on EGpHugeFile do
      raise;
    on E:Exception do
      raise EGpHugeFile.CreateHelp(E.Message, hcHFUnexpected);
  end;
end; { TGpHugeFile.Seek }

{:Returns file pointer position in bytes. Used only internally.
  @returns File pointer position in bytes.
  @raises  Various system exceptions.
}
function TGpHugeFile._FilePos: HugeInt;
var
  off: TLargeInteger;
begin
  CheckHandle;
  off.QuadPart := 0;
  off.LowPart := 0;
  Win32Check(HFSetFilePointer(hfHandle, off, FILE_CURRENT), '_FilePos');
  Result := off.QuadPart;
end; { TGpHugeFile. }

{:Truncates file at current position.
  @raises  EGpHugeFile on Windows errors.
}
procedure TGpHugeFile.Truncate;
begin
  try
    CheckHandle;
    if hfBuffered then
      _Seek(FilePos, true);
    {$IFDEF LogWin32Calls}Log32('SetEndOfFile');{$ENDIF LogWin32Calls}
    SetLastError(0);
    Win32Check(SetEndOfFile(hfHandle), 'Truncate');
    hfCachedSize := -1;
  except
    on EGpHugeFile do
      raise;
    on E:Exception do
      raise EGpHugeFile.CreateHelp(E.Message, hcHFUnexpected);
  end;
end; { TGpHugeFile.Truncate }

{:Returns EOF indicator.
  @since   2003-02-12
}
function TGpHugeFile.EOF: boolean;
begin
  if hfFlagNoBuf then
    Result := (FilePos >= FileSize)
  else
    Result := (FilePos >= _FileSize);
end; { TGpHugeFile.EOF }

{:Returns file pointer position in 'block size' large units (see 'blockSize' parameter to
  Reset and Rewrite methods). Position is retrieved from cached value.
  @returns File pointer position in 'block size' large units.
  @raises  EGpHugeFile on Windows errors.
  @seeAlso Reset, Rewrite
}
function TGpHugeFile.FilePos: HugeInt;
begin
  try
    if not hfHalfClosed then
      CheckHandle;
    if hfBlockSize <> 1 then
      Result := {$IFDEF D4plus}Trunc{$ELSE}int{$ENDIF}(hfBufFilePos/hfBlockSize)
    else
      Result := hfBufFilePos;
  except
    on EGpHugeFile do
      raise;
    on E:Exception do
      raise EGpHugeFile.CreateHelp(E.Message, hcHFUnexpected);
  end;
end; { TGpHugeFile.FilePos }

{:Flushed file buffers.
  @raises  EGpHugeFile on Windows errors.
}
procedure TGpHugeFile.Flush;
begin
  CheckHandle;
  {$IFDEF LogWin32Calls}Log32('FlushBuffer');{$ENDIF LogWin32Calls}
  SetLastError(0);
  Win32Check(FlushBuffer, 'Flush');
  {$IFDEF LogWin32Calls}Log32('FlushFileBuffers');{$ENDIF LogWin32Calls}
  SetLastError(0);
  Win32Check(FlushFileBuffers(hfHandle), 'Flush');
end; {  TGpHugeFile.Flush  }

{:Rounds parameter next multiplier of system page size. Used to determine buffer size for
  direct access files (FILE_FLAG_NO_BUFFERING).
  @param   bufSize Initial buffer size.
  @returns bufSize Required buffer size.
}
function TGpHugeFile.RoundToPageSize(bufSize: DWORD): DWORD;
var
  sysInfo: TSystemInfo;
begin
  GetSystemInfo(sysInfo);
  Result := (((bufSize-1) div sysInfo.dwPageSize) + 1) * sysInfo.dwPageSize;
end; { TGpHugeFile.RoundToPageSize }

{:Allocates file buffer (after freeing old buffer if allocated). Calculates correct buffer
  size for direct access files and locks buffer if required. Used only internally.
  @raises Various system exceptions.
}
procedure TGpHugeFile.AllocBuffer;
begin
  FreeBuffer;
  SetLastError(0);
  if not hfBuffered then
    Exit;
  hfBuffer := VirtualAlloc(nil, hfBufferSize, MEM_RESERVE+MEM_COMMIT, PAGE_READWRITE);
  Win32Check(hfBuffer<>nil, 'AllocBuffer');
  if hfLockBuffer then begin
    SetLastError(0);
    Win32Check(VirtualLock(hfBuffer, hfBufferSize), 'AllocBuffer');
    if hfBuffer = nil then
      raise EGpHugeFile.CreateFmtHelp(sFailedToAllocateBuffer, [FileName], hcHFFailedToAllocateBuffer);
  end;
end; { TGpHugeFile.AllocBuffer }

procedure TGpHugeFile.AsyncWriteCompletion(errorCode, numberOfBytes: DWORD;
  asyncDescriptor: TGpHFAsyncDescriptor);
begin
  // TODO 1 -oPrimoz Gabrijelcic : Report error code via event
  if errorCode <> 0 then
    raise Exception.CreateFmt('Async write error %d', [errorCode]);
  //>
  // TODO 1 -oPrimoz Gabrijelcic : Report error via event
  if numberOfBytes <> DWORD(asyncDescriptor.BufferSize) then
    raise Exception.CreateFmt('Invalid number of bytes written %d <> %d',
      [numberOfBytes, asyncDescriptor.BufferSize]);
  //>
  FreeAndNil(asyncDescriptor);
end; { TGpHugeFile.AsyncWriteCompletion }

{:Frees memory buffer if allocated. Used only internally.
  @raises  Various system exceptions.
}
procedure TGpHugeFile.FreeBuffer;
begin
  if hfBuffer <> nil then begin
    SetLastError(0);
    Win32Check(FlushBuffer, 'FreeBuffer');
    if hfLockBuffer then begin
      SetLastError(0);
      Win32Check(VirtualUnlock(hfBuffer, hfBufferSize), 'FreeBuffer');
    end;
    SetLastError(0);
    Win32Check(VirtualFree(hfBuffer, 0, MEM_RELEASE), 'FreeBuffer');
    hfBuffer := nil;
  end;
end; { TGpHugeFile.FreeBuffer }

{:Offsets pointer by a given ammount.
  @param   ptr    Original pointer.
  @param   offset Offset (in bytes).
  @returns New pointer.
}
function OffsetPtr(ptr: pointer; offset: DWORD): pointer;
begin
  Result := pointer(DWORD(ptr)+offset);
end; { OffsetPtr }

{:Writes 'count' number of bytes large units to a file (or buffer if access is buffered).
  @param   buf         Data to be written.
  @param   count       Number of bytes to be written.
  @param   transferred (out) Number of bytes actually written.
  @raises  EGpHugeFile when trying to write while in buffered read mode and file pointer
           is not at end of file.
  @raises  Various system exceptions.
  @seeAlso Reset, Rewrite
}
procedure TGpHugeFile.Transmit(const buf; count: DWORD; var transferred: DWORD);
var
  place  : DWORD;
  bufp   : pointer;
  send   : DWORD;
  written: DWORD;
begin
  if not hfBufWrite then begin
    if FilePos = FileSize then begin
      InitWriteBuffer;
      hfReading := false;
    end
    else
      raise EGpHugeFile.CreateFmtHelp(sWriteWhileInBufferedReadMode, [FileName], hcHFWriteInBufferedReadMode);
  end;
  //cope with the delayed seek
  if (hfBufFilePos <> hfBufFileOffs) and (hfBufOffs = 0) then
    _Seek(hfBufFilePos, true);
  transferred := 0;
  place := hfBufferSize-hfBufOffs;
  if place <= count then begin
    Move(buf, OffsetPtr(hfBuffer, hfBufOffs)^, place); // fill the buffer
    hfBufOffs := hfBufferSize;
    hfBufFilePos := hfBufFileOffs+hfBufOffs;
    {$IFDEF LogWin32Calls}Log32('FlushBuffer');{$ENDIF LogWin32Calls}
    Win32Check(FlushBuffer, 'Transmit');
    transferred := place;
    Dec(count, place);
    bufp := OffsetPtr(@buf, place);
    if count >= hfBufferSize then begin // transfer N*(buffer size)
      send := (count div hfBufferSize)*hfBufferSize;
      if hfAsynchronous then // TODO 1 -oPrimoz Gabrijelcic : implement: TGpHugeFile.Transmit
        raise Exception.Create('TGpHugeFile.Transmit: Not implemented');
      SetLastError(0);
      {$IFDEF LogWin32Calls}Log32(Format('WriteFile|%d', [send]));{$ENDIF LogWin32Calls}
      Win32Check(WriteFile(hfHandle, bufp^, send, written, nil), 'Transmit');
      hfBufFileOffs := hfBufFileOffs+written;
      hfBufFilePos := hfBufFileOffs;
      Inc(transferred, written);
      Dec(count, send);
      bufp := OffsetPtr(bufp, send);
    end;                           
  end
  else
    bufp := @buf;
  if count > 0 then begin // store leftovers
    Move(bufp^, OffsetPtr(hfBuffer, hfBufOffs)^, count);
    Inc(hfBufOffs, count);
    Inc(transferred, count);
    hfBufFilePos := hfBufFileOffs+hfBufOffs;
  end;
end; { TGpHugeFile.Transmit }

{:Reads 'count' number of bytes large units from a file (or buffer if access is
  buffered).
  @param   buf         Buffer for read data.
  @param   count       Number of bytes to be read..
  @param   transferred (out) Number of bytes actually read..
  @raises  EGpHugeFile when trying to read while in buffered write mode.
  @raises  Various system exceptions.
  @seeAlso Reset, Rewrite
}
procedure TGpHugeFile.Fetch(var buf; count: DWORD; var transferred: DWORD);
var
  bufp      : pointer;
  got       : DWORD;
  mustResync: boolean;
  off       : TLargeInteger;
  read      : DWORD;
  trans     : DWORD;
begin
//  if hfPrefetch then
//    GpLog.Log('[H] Fetch %d at %d => %p', [count, hfBufFilePos, pointer(@buf)]);
  if hfBufWrite then
    raise EGpHugeFile.CreateFmtHelp(sReadWhileInBufferedWriteMode, [FileName], hcHFReadInBufferedWriteMode);
  transferred := 0;
  got := hfBufSize-hfBufOffs;
  if got <= count then begin
    if got > 0 then begin // read from buffer
      Move(OffsetPtr(hfBuffer, hfBufOffs)^, buf, got);
      transferred := got;
      Dec(count, got);
      hfBufFilePos := hfBufFileOffs - hfBufSize + hfBufOffs + got;
    end;
    bufp := OffsetPtr(@buf, got);
    hfBufOffs := 0;
    if count >= hfBufferSize then begin // read from prefetch cache
      if hfPrefetch then begin
        if not ReadBlockFromPrefetch(bufp, count, transferred) then begin
          {$IFDEF LogPrefetch}
          GpLog.Log('[F] EOF');
          {$ENDIF LogPrefetch}
          Exit; // EOF
        end;
        {$IFDEF LogPrefetch}
        if count > 0 then
          GpLog.Log('[F] %d bytes not read from the prefetch cache', [count]);
        {$ENDIF LogPrefetch}
      end;
      read := (count div hfBufferSize)*hfBufferSize;
      if read > 0 then begin
        if hfHalfClosed then
          trans := 0
        else begin
          {$IFDEF LogWin32Calls}Log32(Format('ReadFile|%d', [read]));{$ENDIF LogWin32Calls}
          SetLastError(0);
          Win32Check(ReadFile(hfHandle, bufp^, read, trans, nil), 'Fetch 2');
        end;
        hfBufFileOffs := hfBufFileOffs + trans;
        hfBufFilePos := hfBufFileOffs;
        Inc(transferred, trans);
        Dec(count, read);
        bufp := OffsetPtr(bufp, read);
        if trans < read then 
          Exit; // EOF
      end;
    end;
    // fill the buffer
    if not hfHalfClosed then begin
      if LoadedToTheEOF then
        hfBufSize := 0
      else begin
        {$IFDEF LogWin32Calls}Log32(Format('ReadFile|%d', [hfBufferSize]));{$ENDIF LogWin32Calls}
        SetLastError(0);
        mustResync := false;
        if hfPrefetch and hfPrefetchCache.GetBlock(hfBufFileOffs, hfBuffer, trans) and (trans = hfBufSize) then
          mustResync := true
        else begin
          {$IFDEF LogPrefetch}
//          if hfPrefetch then
//            GpLog.Log('[F] file offset = %d', [_FilePos]);
          {$ENDIF LogPrefetch}
          Win32Check(ReadFile(hfHandle, hfBuffer^, hfBufferSize, hfBufSize, nil), 'Fetch');
          {$IFDEF LogPrefetch}
          if hfPrefetch then
            GpLog.Log('[F] read %d (of %d) bytes directly, data = %s', [hfBufSize, hfBufferSize, HexStr(hfBuffer^, 16)]);
          {$ENDIF LogPrefetch}
        end;
        hfBufFileOffs := hfBufFileOffs + hfBufSize;
        if mustResync then begin
          off.QuadPart := hfBufFileOffs;
          HFSetFilePointer(hfHandle, off, FILE_BEGIN)
        end;
      end;
    end
    else begin
      hfBufOffs := hfBufSize;
      Exit;
    end;
    if hfPrefetch then
      hfPrefetcher.Seek(hfBufFileOffs);
  end
  else
    bufp := @buf;
  if count > 0 then begin // read from buffer
    got := hfBufSize-hfBufOffs;
    if got < count then
      count := got;
    if count > 0 then
      Move(OffsetPtr(hfBuffer, hfBufOffs)^, bufp^, count);
    Inc(hfBufOffs, count);
    Inc(transferred, count);
    hfBufFilePos := hfBufFileOffs-hfBufSize+hfBufOffs;
  end;
end; { TGpHugeFile.Fetch }

{:Flushed file buffers (internal implementation).
  @returns False if data could not be written.
}
function TGpHugeFile.FlushBuffer: boolean;
var
  asyncDescriptor: TGpHFAsyncDescriptor;
  written        : DWORD;
begin
  if (hfBufOffs > 0) and hfBufWrite then begin
    if hfFlagNoBuf then
      hfBufOffs := RoundToPageSize(hfBufOffs);
    if hfAsynchronous then begin
      MsgWaitForMultipleObjectsEx(0, PChar(nil)^, 0, 0, MWMO_ALERTABLE);
      asyncDescriptor := TGpHFAsyncDescriptor.Create(Self, hfBuffer, hfBufOffs, hfBufFilePos-hfBufOffs);
      Result := WriteFileEx(hfHandle, asyncDescriptor.Buffer, hfBufOffs,
        asyncDescriptor.Overlapped^, @HFAsyncWriteCompletion);
      if not Result then
        FreeAndNil(asyncDescriptor);
      written := hfBufOffs;
    end
    else
      Result := WriteFile(hfHandle, hfBuffer^, hfBufOffs, written, nil);
    hfBufFileOffs := hfBufFileOffs+written;
    hfBufOffs     := 0;
    hfBufFilePos  := hfBufFileOffs;
    if hfFlagNoBuf then
      FillChar(hfBuffer^, hfBufferSize, 0);
  end
  else
    Result := true;
end; { TGpHugeFile.FlushBuffer }

{:Reads 'count' number of 'block size' large units (see 'blockSize' parameter to Reset and
  Rewrite methods) from a file (or buffer if access is buffered).
  @param   buf         Buffer for read data.
  @param   count       Number of 'block size' large units to be read.
  @raises  EGpHugeFile on Windows errors or if not enough data could be read from file.
  @seeAlso Reset, Rewrite
}
procedure TGpHugeFile.BlockReadUnsafe(var buf; count: DWORD);
var
  transferred: DWORD;
begin
  BlockRead(buf, count, transferred);
  if count <> transferred then begin
    if hfBuffered then
      raise EGpHugeFile.CreateHelp(sEndOfFile, hcHFUnexpectedEOF)
    else
      Win32Check(false, 'BlockReadUnsafe');
  end;
end; { TGpHugeFile.BlockReadUnsafe }

{:Writes 'count' number of 'block size' large units (see 'blockSize' parameter to Reset
  and Rewrite methods) to a file (or buffer if access is buffered).
  @param   buf         Data to be written.
  @param   count       Number of 'block size' large units to be written.
  @raises  EGpHugeFile on Windows errors or if data could not be written completely.
  @seeAlso Reset, Rewrite
}
procedure TGpHugeFile.BlockWriteUnsafe(const buf; count: DWORD);
var
  transferred: DWORD;
begin
  BlockWrite(buf, count, transferred);
  if count <> transferred then begin
    if hfBuffered then
      raise EGpHugeFile.CreateFmtHelp(sWriteFailed, [FileName], hcHFWriteFailed)
    else
      Win32Check(false, 'BlockWriteUnsafe');
  end;
end; { TGpHugeFile.BlockWriteUnsafe }

function TGpHugeFile.Compress: boolean;
begin
  Result := true;
  if (IsUnicodeMode and DSiIsFileCompressedW(hfName)) or
     ((not IsUnicodeMode) and DSiIsFileCompressed(hfNameA))
  then
    Result := DSiCompressFile(hfHandle);
end; { Compress }

function TGpHugeFile.FixBufferSize(bufferSize: integer): DWORD;
begin
  Result := bufferSize;
  if Result = 0 then
     Result := BUF_SIZE;
  // round up buffer size to be the multiplier of page size
  // needed for FILE_FLAG_NO_BUFFERING access, does not hurt in other cases
  Result := RoundToPageSize(Result);
end; { TGpHugeFile.FixBufferSize }

{:Returns true if file is open.
  @returns True if file is open.
}
function TGpHugeFile.IsOpen: boolean;
begin
  Result := hfIsOpen;
end; { TGpHugeFile.IsOpen }

{:Checks condition and creates appropriately formatted EGpHugeFile exception.
  @param   condition If false, Win32Check will generate an exception.
  @param   method    Name of TGpHugeFile method that called Win32Check.
  @raises  EGpHugeFile if (not condition).
}
procedure TGpHugeFile.Win32Check(condition: boolean; method: string);
begin
  if not condition then begin
    hfWindowsError := GetLastError;
    if hfWindowsError <> ERROR_SUCCESS then
      raise EGpHugeFile.CreateFmtHelp(sFileFailed+
        {$IFNDEF D6PLUS}SWin32Error{$ELSE}SOSError{$ENDIF},
        [method, FileName, hfWindowsError, SysErrorMessage(hfWindowsError)],
        hfWindowsError)
    else
      raise EGpHugeFile.CreateFmtHelp(sFileFailed+
        {$IFNDEF D6PLUS}SUnkWin32Error{$ELSE}SUnkOSError{$ENDIF},
        [method, FileName], hcHFUnknownWindowsError);
  end;
end; { TGpHugeFile.Win32Check }

{:Returns file date in Delphi format.
  @returns Returns file date in Delphi format.
  @raises  EGpHugeFile on Windows errors.
}
function TGpHugeFile.GetDate: TDateTime;
begin
  try
    CheckHandle;
    {$IFDEF D10PLUS}
    FileAge(FileName, Result);
    {$ELSE}
    Result := FileDateToDateTime(FileAge(FileName));
    {$ENDIF}
  except
    on EGpHugeFile do
      raise;
    on E:Exception do
      raise EGpHugeFile.CreateHelp(E.Message, hcHFUnexpected);
  end;
end; { TGpHugeFile.GetDate }

function TGpHugeFile.GetTime: int64;
var
  lpat: TFileTime;
  lpct: TFileTime;
  lpwt: TFileTime;
begin
  try
    CheckHandle;
    if not GetFileTime (hfHandle, @lpct, @lpat, @lpwt) then
      Result := 0
    else begin
      Result := 0;
      Move (lpwt, Result, SizeOf (int64));
    end;
  except
    on EGpHugeFile do
      raise;
    on E:Exception do
      raise EGpHugeFile.CreateHelp(E.Message, hcHFUnexpected);
  end;
end; { TGpHugeFile.GetTime }

function TGpHugeFile.GetFileName: WideString;
begin
  if IsUnicodeMode then
    Result := hfName
  else
    Result := hfNameA;
end; { TGpHugeFile.GetFileName }

function TGpHugeFile.HFGetFileSize(handle: THandle; var size: TLargeInteger): boolean;
begin
  size.LowPart := GetFileSize(handle, @size.HighPart);
  Result := (size.LowPart <> INVALID_FILE_SIZE) or (GetLastError = NO_ERROR);
end; { TGpHugeFile.HFGetFileSize }

function TGpHugeFile.HFSetFilePointer(handle: THandle; var distanceToMove: TLargeInteger;
  moveMethod: DWORD): boolean;
begin
  if assigned(hfPrefetcher) and (moveMethod = FILE_BEGIN) then
    hfPrefetcher.Seek(int64(distanceToMove));
  distanceToMove.LowPart := SetFilePointer(handle, longint(distanceToMove.LowPart),
    @distanceToMove.HighPart, moveMethod);
  Result := (distanceToMove.LowPart <> INVALID_SET_FILE_POINTER) or (GetLastError = NO_ERROR);
end; { TGpHugeFile.HFSetFilePointer }

{:Sets file date.
  @param   value new file date.
}
procedure TGpHugeFile.SetDate(const value: TDateTime);
var
  err: integer;
begin
  try
    CheckHandle;
    err := FileSetDate(hfHandle, DateTimeToFileDate(value));
    if err <> 0 then
      raise EGpHugeFile.CreateFmtHelp(sFileFailed+SysErrorMessage(err),
        ['SetDate', FileName], err);
  except
    on EGpHugeFile do
      raise;
    on E:Exception do
      raise EGpHugeFile.CreateHelp(E.Message, hcHFUnexpected);
  end;
end; { TGpHugeFile.SetDate }

{:Returns true if file is loaded into the buffer up to the last byte.
  @returns Returns true if file is loaded into the buffer up to the last byte.
}
function TGpHugeFile.LoadedToTheEOF: boolean;
begin
  Result := (hfBufFileOffs >= (_FileSize*hfBlockSize));
end; { TGpHugeFile.LoadedToTheEOF }

{:Returns file size. If available, returns cached size.
  @returns File size in bytes.
  @raises  EGpHugeFile on Windows errors.
}
function TGpHugeFile._FileSize: HugeInt;
begin
  if hfCachedSize < 0 then
    hfCachedSize := FileSize;
  Result := hfCachedSize;
end; { TGpHugeFile._FileSize }

{:Initializes buffer for writing.
}
procedure TGpHugeFile.InitWriteBuffer;
begin
  hfBufSize     := 0;
  hfBufOffs     := 0;
  hfBufFileOffs := 0;
  hfBufWrite    := true;
end; { TGpHugeFile.InitWriteBuffer }

{:Initializes buffer for reading.
}
procedure TGpHugeFile.InitReadBuffer;
begin
  hfBufOffs     := 0;
  hfBufSize     := 0;
  hfBufFileOffs := 0;
  hfBufWrite    := false;
end; { TGpHugeFile.InitReadBuffer }

procedure TGpHugeFile.InternalCreateEx(FlagsAndAttributes: DWORD; DesiredAccess: DWORD;
  DesiredShareMode: DWORD);
begin
  hfBlockSize        := 1;
  hfBuffer           := nil;
  hfBuffered         := false;
  hfCachedSize       := -1;
  hfDesiredAcc       := DesiredAccess;
  hfDesiredShareMode := DesiredShareMode;
  hfShareModeSet     := true;
  hfFlagNoBuf        := ((FILE_FLAG_NO_BUFFERING AND FlagsAndAttributes) <> 0);
  hfFlags            := FlagsAndAttributes;
  hfHandle           := INVALID_HANDLE_VALUE;
end; { TGpHugeFile.InternalCreateEx }

function TGpHugeFile.IsUnicodeMode: boolean;
begin
  Result := (hfNameA = '');
end; { TGpHugeFile.IsUnicodeMode }

procedure TGpHugeFile.Log32(const msg: string);
{$IFDEF LogWin32Calls}
var
  logFile: THandle;
  logMsg : string;
  written: DWORD;
{$ENDIF LogWin32Calls}
begin
{$IFDEF LogWin32Calls}
  WaitForSingleObject(hfWin32LogLock, INFINITE);
  try
    logFile := CreateFile(
      PChar(IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'gphugef.log'),
      GENERIC_READ + GENERIC_WRITE, FILE_SHARE_READ OR FILE_SHARE_WRITE, nil, OPEN_ALWAYS,
      FILE_ATTRIBUTE_NOT_CONTENT_INDEXED OR FILE_FLAG_WRITE_THROUGH, 0);
    if logFile = INVALID_HANDLE_VALUE then 
      raise Exception.Create('TGpHugeFile: Cannot write to file ' +
        IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'gphugef.log'#13#10 +
        SysErrorMessage(GetLastError));
    SetFilePointer(logFile, 0, nil, FILE_END);
    logMsg := Format('%d|%s|%s'#13#10, [Handle, FileName, msg]);
    WriteFile(logFile, logMsg[1], Length(logMsg), written, nil);
    CloseHandle(logFile);
  finally ReleaseMutex(hfWin32LogLock); end;
{$ENDIF LogWin32Calls}
end; { TGpHugeFile.Log32 }

function TGpHugeFile.ReadBlockFromPrefetch(var bufp: pointer; var count,
  transferred: DWORD): boolean;
var
  mustResync: boolean;
  off       : TLargeInteger;
  trans     : DWORD;
begin
  Result := true;
  mustResync := false;
  while Result and
        (count >= hfBufferSize) and
        hfPrefetchCache.GetBlock(hfBufFileOffs, bufp, trans) do
  begin
    hfBufFileOffs := hfBufFileOffs + trans;
    hfBufFilePos := hfBufFileOffs;
    mustResync := true;
    bufp := OffsetPtr(bufp, trans);
    Dec(count, trans);
    Inc(transferred, trans);
    if trans < hfBufferSize then 
      Result := false; //EOF
  end;
  if mustResync then begin
    off.QuadPart := hfBufFileOffs;
    HFSetFilePointer(hfHandle, off, FILE_BEGIN);
  end;
end; { TGpHugeFile.ReadBlockFromPrefetch }

{ TGpHugeFileStream }

{:Initializes stream and opens file in required access mode.
  @param   fileName    Name of file to be accessed.
  @param   access      Required access mode.
  @param   openOptions Set of possible open options.
}
constructor TGpHugeFileStream.Create(const fileName: string; access:
  TGpHugeFileStreamAccess; openOptions: THFOpenOptions; desiredShareMode: DWORD;
  diskLockTimeout, diskRetryDelay: integer; waitObject: THandle;
  numPrefetchBuffers: integer);
begin
  inherited Create;
  hfsExternalHF := false;
  case access of
    accRead:
      begin
        hfsFile := TGpHugeFile.CreateEx(fileName, FILE_ATTRIBUTE_NORMAL, GENERIC_READ,
          desiredShareMode);
        hfsFile.Win32Check(hfsFile.ResetEx(1, 0, diskLockTimeout, diskRetryDelay,
          openOptions, waitObject, numPrefetchBuffers) = hfOK, 'Reset');
      end; //accRead
    accWrite:
      begin
        hfsFile := TGpHugeFile.CreateEx(fileName, FILE_ATTRIBUTE_NORMAL, GENERIC_WRITE,
          desiredShareMode);
        hfsFile.Win32Check(hfsFile.RewriteEx(1, 0, diskLockTimeout, diskRetryDelay,
          openOptions, waitObject) = hfOK, 'Rewrite');
      end; //accWrite
    accReadWrite:
      begin
        hfsFile := TGpHugeFile.CreateEx(fileName, FILE_ATTRIBUTE_NORMAL,
          GENERIC_READ+GENERIC_WRITE, desiredShareMode);
        hfsFile.Win32Check(hfsFile.ResetEx(1, 0, diskLockTimeout, diskRetryDelay,
          openOptions, waitObject, numPrefetchBuffers) = hfOK, 'Reset');
      end; // accReadWrite
    accAppend:
      begin
        hfsFile := TGpHugeFile.CreateEx(fileName, FILE_ATTRIBUTE_NORMAL,
          GENERIC_READ+GENERIC_WRITE, desiredShareMode);
        hfsFile.Win32Check(hfsFile.ResetEx(1, 0, diskLockTimeout, diskRetryDelay,
          openOptions+[hfoCanCreate], waitObject, numPrefetchBuffers) = hfOK, 'Append');
        hfsFile.Seek(hfsFile.FileSize);
      end; //accAppend
  end; //case
end; { TGpHugeFileStream.Create }

{:Initializes stream and assigns it an already open TGpHugeFile object.
  @param   hf TGpHugeFile object to be used for data storage.
}
constructor TGpHugeFileStream.CreateFromHandle(hf: TGpHugeFile);
begin
  inherited Create;
  hfsExternalHF := true;
  hfsFile := hf;
end; { TGpHugeFileStream.Create/CreateFromHandle }

{:Wide version of the constructor.
  @since   2006-08-14
}
constructor TGpHugeFileStream.CreateW(const fileName: WideString; access:
  TGpHugeFileStreamAccess; openOptions: THFOpenOptions; desiredShareMode: DWORD;
  diskLockTimeout, diskRetryDelay: integer; waitObject: THandle;
  numPrefetchBuffers: integer);
begin
  inherited Create;
  hfsExternalHF := false;
  case access of
    accRead:
      begin
        hfsFile := TGpHugeFile.CreateExW(fileName, FILE_ATTRIBUTE_NORMAL, GENERIC_READ,
          desiredShareMode);
        hfsFile.Win32Check(hfsFile.ResetEx(1, 0, diskLockTimeout, diskRetryDelay,
          openOptions, waitObject, numPrefetchBuffers) = hfOK, 'Reset');
      end; //accRead
    accWrite:
      begin
        hfsFile := TGpHugeFile.CreateExW(fileName, FILE_ATTRIBUTE_NORMAL, GENERIC_WRITE,
          desiredShareMode);
        hfsFile.Win32Check(hfsFile.RewriteEx(1, 0, diskLockTimeout, diskRetryDelay,
          openOptions, waitObject) = hfOK, 'Rewrite');
      end; //accWrite
    accReadWrite:
      begin
        hfsFile := TGpHugeFile.CreateExW(fileName, FILE_ATTRIBUTE_NORMAL,
          GENERIC_READ+GENERIC_WRITE, desiredShareMode);
        hfsFile.Win32Check(hfsFile.ResetEx(1, 0, diskLockTimeout, diskRetryDelay,
          openOptions, waitObject, numPrefetchBuffers) = hfOK, 'Reset');
      end; // accReadWrite
    accAppend:
      begin
        hfsFile := TGpHugeFile.CreateExW(fileName, FILE_ATTRIBUTE_NORMAL,
          GENERIC_READ+GENERIC_WRITE, desiredShareMode);
        hfsFile.Win32Check(hfsFile.ResetEx(1, 0, diskLockTimeout, diskRetryDelay,
          openOptions+[hfoCanCreate], waitObject, numPrefetchBuffers) = hfOK, 'Append');
        hfsFile.Seek(hfsFile.FileSize);
      end; //accAppend
  end; //case
end; { TGpHugeFileStream.CreateW }

{:Destroys stream and file access object (if created in constructor).
}
destructor TGpHugeFileStream.Destroy;
begin
  if (not hfsExternalHF) and assigned(hfsFile) then begin
    hfsFile.Close;
    hfsFile.Free;
    hfsFile := nil;
  end;
  inherited Destroy;
end; { TGpHugeFileStream.Destroy }

{$IFDEF DEBUG}
procedure TGpHugeFileStream.AttachToThread;
begin
  hfsAttachedThread := GetCurrentThreadID;
end; { TGpHugeFileStream.AttachToThread }

procedure TGpHugeFileStream.CheckOwner;
begin
  if (hfsAttachedThread <> 0) and (hfsAttachedThread <> GetCurrentThreadID) then
    raise Exception.Create('TGpHugeFileStream called from invalid thread');
end; { TGpHugeFileStream.CheckOwner }
{$ENDIF DEBUG}

procedure TGpHugeFileStream.DisableBuffering;
begin
  if assigned(hfsFile) then
    hfsFile.DisableBuffering;
end; { TGpHugeFileStream.DisableBuffering }

procedure TGpHugeFileStream.Flush;
begin
  {$IFDEF DEBUG}CheckOwner;{$ENDIF};
  if assigned(hfsFile) then
    hfsFile.Flush;
end; { TGpHugeFileStream.Flush }

{:Returns file name.
  @returns Returns file name or empty string if file is not open.
}
function TGpHugeFileStream.GetFileName: WideString;
begin
  if assigned(hfsFile) then
    Result := hfsFile.FileName
  else
    Result := '';
end; { TGpHugeFileStream.GetFileName }

function TGpHugeFileStream.GetHandle: THandle;
begin
  if assigned(hfsFile) then
    Result := hfsFile.Handle
  else
    Result := INVALID_HANDLE_VALUE;
end; { TGpHugeFileStream.GetHandle }

{:Returns file size. Better compatibility with hfCloseOnEOF files than default
  TStream.GetSize.
  @returns Returns file size in bytes or -1 if file is not open.
}
{$IFDEF D7PLUS}
function TGpHugeFileStream.GetSize: int64;
{$ELSE}
function TGpHugeFileStream.GetSize: longint;
{$ENDIF D7PLUS}
begin
  if assigned(hfsFile) then
    Result := hfsFile.FileSize
  else
    Result := -1;
end; { TGpHugeFileStream.GetSize }

{:Returns last Windows error code.
  @returns Last Windows error code.
}
function TGpHugeFileStream.GetWindowsError: DWORD;
begin
  if hfsWindowsError <> 0 then
    Result := hfsWindowsError
  else if assigned(hfsFile) then
    Result := hfsFile.WindowsError
  else
    Result := 0;
end; { TGpHugeFileStream.GetWindowsError }

{:Reads 'count' number of bytes into buffer.
  @param   buffer Buffer for read data.
  @param   count  Number of bytes to be read.
  @returns Actual number of bytes read.
  @raises  EGpHugeFile on Windows errors.
}
function TGpHugeFileStream.Read(var buffer; count: longint): longint;
var
  bytesRead: cardinal;
begin
  {$IFDEF DEBUG}CheckOwner;{$ENDIF};
  if count <= 0 then
    raise EGpHugeFileStream.CreateFmtHelp(sTryingToReadEmptyBuffer, [FileName],
      hcHFTryingToReadEmptyBuffer);
  hfsFile.BlockRead(Buffer, Count, bytesRead);
  Result := longint(bytesRead);
end; { TGpHugeFileStream.Read }

{:Repositions stream pointer.
  @param   offset Offset from start, current position, or end of stream (as set by the
                  'mode' parameter).
  @param   mode   Specifies starting point for offset calculation (soFromBeginning,
                  soFromCurrent, soFromEnd).
  @returns New position of stream pointer.
  @raises  EGpHugeFile on Windows errors.
  @raises  EGpHugeFileStream on invalid value of 'mode' parameter.
}
function TGpHugeFileStream.Seek(offset: longint; mode: word): longint;
begin
  {$IFDEF DEBUG}CheckOwner;{$ENDIF};
  if mode = soFromBeginning then
    hfsFile.Seek(offset)
  else if mode = soFromCurrent then
    hfsFile.Seek(hfsFile.FilePos+offset)
  else if mode = soFromEnd then
    hfsFile.Seek(hfsFile.FileSize+offset)
  else
    raise EGpHugeFileStream.CreateFmtHelp(sInvalidMode, [FileName], hcHFInvalidSeekMode);
  Result := hfsFile.FilePos;
end; { TGpHugeFileStream.Seek }

{$IFDEF D7PLUS}
{:Delphi 7-compatible seek.
}
function TGpHugeFileStream.Seek(const offset: int64; origin: TSeekOrigin): int64;
begin
  {$IFDEF DEBUG}CheckOwner;{$ENDIF};
  if origin = soBeginning then
    hfsFile.Seek(offset)
  else if origin = soCurrent then
    hfsFile.Seek(hfsFile.FilePos+offset)
  else if origin = soEnd then
    hfsFile.Seek(hfsFile.FileSize+offset)
  else
    raise EGpHugeFileStream.CreateFmtHelp(sInvalidMode, [FileName], hcHFInvalidSeekMode);
  Result := hfsFile.FilePos;
end; { TGpHugeFileStream.Seek }
{$ENDIF D7PLUS}

{:Sets stream size. Truncates underlying file at specified position.
  @param   newSize New stream size.
  @raises  EGpHugeFile on Windows errors.
}
procedure TGpHugeFileStream.SetSize(newSize: longint);
begin
  hfsFile.Seek(newSize);
  hfsFile.Truncate;
end; { TGpHugeFileStream.SetSize }

{$IFDEF D7PLUS}
{:Sets stream size. Truncates underlying file at specified position.
  @param   newSize New stream size.
  @raises  EGpHugeFile on Windows errors.
}
procedure TGpHugeFileStream.SetSize(const newSize: int64);
begin
  SetSize64(newSize);
end; { TGpHugeFileStream.SetSize }

procedure TGpHugeFileStream.SetSize64(const newSize: int64);
begin
  hfsFile.Seek(newSize);
  hfsFile.Truncate;
end; { TGpHugeFileStream.SetSize64 }
{$ENDIF D7PLUS}

{:Checks condition and creates appropriately formatted EGpHugeFileStream exception.
  @param   condition If false, Win32Check will generate an exception.
  @param   method    Name of TGpHugeFileStream method that called Win32Check.
  @raises  EGpHugeFileStream if (not condition).
}
procedure TGpHugeFileStream.Win32Check(condition: boolean; method: string);
begin
  if not condition then begin
    hfsWindowsError := GetLastError;
    if hfsWindowsError <> ERROR_SUCCESS then
      raise EGpHugeFileStream.CreateFmtHelp(
        sStreamFailed+{$IFDEF D6PLUS}SOSError{$ELSE}SWin32Error{$ENDIF},
        [method, FileName, hfsWindowsError, SysErrorMessage(hfsWindowsError)],
        hfsWindowsError)
    else
      raise EGpHugeFileStream.CreateFmtHelp(
        sStreamFailed+{$IFDEF D6PLUS}SUnkOSError{$ELSE}SUnkWin32Error{$ENDIF},
        [method, FileName], hcHFUnknownWindowsError);
  end;
end; { TGpHugeFileStream.Win32Check }

{:Writes 'count' number of bytes to the file.
  @param   buffer Data to be written.
  @param   count  Number of bytes to be written.
  @returns Actual number of bytes written.
  @raises  EGpHugeFile on Windows errors.
}
function TGpHugeFileStream.Write(const buffer; count: longint): longint;
var
  bytesWritten: cardinal;
begin
  {$IFDEF DEBUG}CheckOwner;{$ENDIF};
  if count <= 0 then
    raise EGpHugeFileStream.CreateFmtHelp(sTryingToWriteEmptyBuffer, [FileName],
      hcHFTryingToWriteEmptyBuffer);
  hfsFile.BlockWrite(buffer, count, bytesWritten);
  Result := longint(bytesWritten);
end; { TGpHugeFileStream.Write }

{$IFDEF EnablePrefetchSupport}

procedure HFPAsyncReadCompletion(errorCode, numberOfBytes: DWORD; overlapped: POverlapped); stdcall;
begin
  {$IFDEF LogPrefetch}
  GpLog.Log('[A] %d / %d / %d', [errorCode, numberOfBytes, overlapped.hEvent]);
  {$ENDIF LogPrefetch}  
  TGpHugeFilePrefetch(overlapped.hEvent)
    .ReadCompletion(errorCode, numberOfBytes, overlapped);
end; { HFPAsyncReadCompletion }

{ TGpHugeFilePrefetch }

constructor TGpHugeFilePrefetch.Create;
begin
  inherited;
  hfpHandle := INVALID_HANDLE_VALUE;
end; { TGpHugeFilePrefetch.Create }

procedure TGpHugeFilePrefetch.CancelActiveRequests;
begin
  if (hfpBufferMap.Count > 0) and (hfpHandle <> INVALID_HANDLE_VALUE) then begin
    {$IFDEF LogPrefetch}
    GpLog.Log('[W] CancelIO');
    {$ENDIF LogPrefetch}
    if not CancelIO(hfpHandle) then
      {$IFDEF LogPrefetch}
      GpLog.Log('[W] ==> error %d', [GetLastError])
      {$ENDIF LogPrefetch}
    else
      SleepEx(0, true);
  end;
end; { TGpHugeFilePrefetch.CancelActiveRequests }

procedure TGpHugeFilePrefetch.Cleanup;
begin
  CancelActiveRequests;
  DSiCloseHandleAndInvalidate(hfpHandle);
  FreeAndNil(hfpBufferMap);
  inherited;
end; { TGpHugeFilePrefetch.Cleanup }

function TGpHugeFilePrefetch.FindNextReadOffset(blkOffset: int64): int64;
begin
  while (hfpReadBlocks > 0) and
        (hfpCache.ContainsBlock(blkOffset) or hfpCache.IsReadingBlock(blkOffset)) do
  begin
    {$IFDEF LogPrefetch}
    GpLog.Log('[W] ==> block %d is already in the cache/read queue, trying %d; %d more blocks to prefetch',
      [blkOffset, blkOffset + hfpBufferSize, hfpReadBlocks - 1]);
    {$ENDIF LogPrefetch}
    Dec(hfpReadBlocks);
    Inc(blkOffset, hfpBufferSize);
  end;
  Result := blkOffset;
end; { TGpHugeFilePrefetch.FindNextReadOffset }

function TGpHugeFilePrefetch.Initialize: boolean;
var
  cacheVal: TOmniValue;
begin
  Result := inherited Initialize;
  if Result then begin
    hfpHandle := Task.Param['Handle'];
    cacheVal := Task.Param['Cache'];
    hfpCache := cacheVal.AsInterface as IHFPrefetchCache;
    hfpBufferSize := Task.Param['BufferSize'];
    hfpNumBuffers := Task.Param['NumBuffers'];
    hfpBufferMap := TGpObjectMap.Create(false);
  end;
end; { TGpHugeFilePrefetch.Initialize }

function TGpHugeFilePrefetch.OverlappedOffset(const overlapped: TOverlapped): int64;
begin
  Int64Rec(Result).Lo := overlapped.Offset;
  Int64Rec(Result).Hi := overlapped.OffsetHigh;
end; { TGpHugeFilePrefetch.OverlappedOffset }

procedure TGpHugeFilePrefetch.ReadCompletion(errorCode, numberOfBytes: DWORD; overlapped:
  POverlapped);
var
  blkOffset: int64;
  buffer   : pointer;
begin
  overlapped.hEvent := 0; 
  blkOffset := OverlappedOffset(overlapped^);
  {$IFDEF LogPrefetch}
  GpLog.Log('[W] Read completed, error = %d, bytes read = %d, offset = %d, overlapped = %p',
    [errorCode, numberOfBytes, blkOffset, pointer(overlapped)]);
  {$ENDIF LogPrefetch}
  buffer := pointer(hfpBufferMap[TObject(overlapped)]);
  if not assigned(buffer) then
    {$IFDEF LogPrefetch}
    GpLog.Log('[W] ==> No buffer associated with overlapped %p', [pointer(overlapped)])
    {$ENDIF LogPrefetch}
  else begin
    {$IFDEF LogPrefetch}
    GpLog.Log('[W] ==> buffer = %p, data = %s', [pointer(buffer), HexStr(buffer^, 16)]);
    {$ENDIF LogPrefetch}
    if errorCode <> 0 then
      // Read failed; can't cope with errors so do nothing; main thread will try to fetch
      // the same part of the file and will then decide what to do.
      // It could be just a ERROR_OPERATION_ABORTED anyway.
      hfpCache.CancelIsReading(blkOffset)
    else begin
      hfpCache.InsertBlock(buffer, numberOfBytes, blkOffset);
      if numberOfBytes <> hfpBufferSize then
        hfpReadBlocks := 0
      else begin
        Inc(blkOffset, hfpBufferSize);
        Dec(hfpReadBlocks);
        blkOffset := FindNextReadOffset(blkOffset);
      end;
      if hfpReadBlocks > 0 then
        StartReadRequest(blkOffset)
      else
        {$IFDEF LogPrefetch}
        GpLog.Log('[W] ==> Stop reading, read blocks = %d, read size = %d',
          [hfpReadBlocks, numberOfBytes]);
        {$ENDIF LogPrefetch}
    end;
    DSiFreeMemAndNil(buffer);
  end;
  hfpBufferMap[TObject(overlapped)] := nil;
  Dispose(overlapped);
end; { TGpHugeFilePrefetch.ReadCompletion }

procedure TGpHugeFilePrefetch.Seek(var msg: TOmniMessage);
var
  blkOffset          : int64;
  numParallelPrefetch: integer;
begin
  blkOffset := (int64(msg.MsgData) div hfpBufferSize) * hfpBufferSize;
  {$IFDEF LogPrefetch}
  GpLog.Log('[W] Seek %d', [blkOffset]);
  {$ENDIF LogPrefetch}
  while Task.Comm.Receive(msg) do begin
    blkOffset := (int64(msg.MsgData) div hfpBufferSize) * hfpBufferSize;
    {$IFDEF LogPrefetch}
    GpLog.Log('[W] ==> Seek %d', [blkOffset]);
    {$ENDIF LogPrefetch}
  end;
  hfpReadBlocks := hfpNumBuffers;
  for numParallelPrefetch := 1 to 2 do begin
    blkOffset := FindNextReadOffset(blkOffset);
    if hfpReadBlocks <= 0 then
      break; //for numParallelPrefetch
    if numParallelPrefetch = 1 then
      CancelActiveRequests;
    StartReadRequest(blkOffset);
  end;
end; { TGpHugeFilePrefetch.Seek }

procedure TGpHugeFilePrefetch.StartReadRequest(blkOffset: int64);
var
  buffer    : pointer;
  overlapped: POverlapped;
begin
  hfpCache.NotifyIsReading(blkOffset);
  GetMem(buffer, hfpBufferSize);
  New(overlapped);
  hfpBufferMap[TObject(overlapped)] := TObject(buffer);
  overlapped.Internal := 0;
  overlapped.InternalHigh := 0;
  overlapped.Offset := Int64Rec(blkOffset).Lo;
  overlapped.OffsetHigh := Int64Rec(blkOffset).Hi;
  overlapped.hEvent := cardinal(Self);
  {$IFDEF LogPrefetch}
  GpLog.Log('[W] Start reading from %d, size = %d, buffer = %p, overlapped = %p',
    [blkOffset, hfpBufferSize, pointer(buffer), pointer(overlapped)]);
  {$ENDIF LogPrefetch}
  ReadFileEx(hfpHandle, buffer, hfpBufferSize, overlapped, @HFPAsyncReadCompletion);
end; { TGpHugeFilePrefetch.StartReadRequest }

{ THFPrefetchCache }

constructor THFPrefetchCache.Create(bufferSize, numBuffers: integer);
begin
  Assert(bufferSize > 0);
  hfpcBufferSize := bufferSize;
  hfpcCache := TGpObjectRingBuffer.Create(numBuffers, true, true);
  hfpcReadingLock := TSpinLock.Create;
  hfpcReadingList := TGpInt64List.Create;
  {$IFDEF LogPrefetch}
  GpLog.Log('[C] Created, buffer size = %d, num buffers = %d', [bufferSize, numBuffers]);
  {$ENDIF LogPrefetch}
end; { THFPrefetchCache.Create }

destructor THFPrefetchCache.Destroy;
begin
  {$IFDEF LogPrefetch}
  GpLog.Log('[C] Destroyed');
  {$ENDIF LogPrefetch}
  FreeAndNil(hfpcReadingList);
  FreeAndNil(hfpcReadingLock);
  FreeAndNil(hfpcCache);
  inherited Destroy;
end; { THFPrefetchCache.Destroy }

function THFPrefetchCache.AddBlock(offset: int64): integer;
begin
  if hfpcCache.IsFull then
    hfpcCache.Dequeue.Free;
  {$IFDEF LogPrefetch}
  GpLog.Log('[C] Creating new block at %d, size = %d', [offset, hfpcBufferSize]);
  {$ENDIF LogPrefetch}
  hfpcCache.Enqueue(THFCachedBlock.Create(offset, hfpcBufferSize));
  Result := FindBlock(offset);
end; { THFPrefetchCache.AddBlock }

procedure THFPrefetchCache.CancelIsReading(offset: HugeInt);
begin
  {$IFDEF LogPrefetch}
  GpLog.Log('[C] Cancel IsReading status at %d', [offset]);
  {$ENDIF LogPrefetch}
  hfpcReadingLock.Acquire;
  try
    hfpcReadingList.Remove(offset);
  finally hfpcReadingLock.Release; end;
end; { THFPrefetchCache.CancelIsReading }

function THFPrefetchCache.ContainsBlock(offset: HugeInt): boolean;
begin
  hfpcCache.Lock;
  try
    Result := (FindBlock(offset) >= 0);
    {$IFDEF LogPrefetch}
    GpLog.Log('[C] Contains(%d) = %d', [offset, Ord(Result)]);
    {$ENDIF LogPrefetch}
  finally hfpcCache.Unlock; end;
end; { THFPrefetchCache.ContainsBlock }

function THFPrefetchCache.FindBlock(offset: int64): integer;
begin
  for Result := 0 to hfpcCache.Count - 1 do
    if Block[Result].Offset = offset then
      Exit;
  Result := -1;
end; { THFPrefetchCache.FindBlock }

function THFPrefetchCache.GetBlock(offset: HugeInt; outBuffer: pointer;
  var dataSize: cardinal): boolean;
var
  idxBlock: integer;
begin
  {$IFDEF LogPrefetch}
  GpLog.Log('[C] Get block at %d', [offset]);
  {$ENDIF LogPrefetch}
  Result := false;
  if IsReadingBlock(offset) then begin
    {$IFDEF LogPrefetch}
    GpLog.Log('[C] ==> block is being read, waiting ...');
    {$ENDIF LogPrefetch}
    if not WaitForBlock(offset, 1000{ms}) then begin
      {$IFDEF LogPrefetch}
      GpLog.Log('[C] ==> wait failed');
      {$ENDIF LogPrefetch}
      Exit;
    end;
  end;
  hfpcCache.Lock;
  try
    idxBlock := FindBlock(offset);
    if idxBlock >= 0 then begin
      {$IFDEF LogPrefetch}
      GpLog.Log('[C] ==> fetch %d @ %p => %p', [Block[idxBlock].Size, pointer(Block[idxBlock].Data), pointer(outBuffer)]);
      {$ENDIF LogPrefetch}
      Move(Block[idxBlock].Data^, outBuffer^, Block[idxBlock].Size);
      dataSize := Block[idxBlock].Size;
      {$IFDEF LogPrefetch}
      GpLog.Log('[C] ==> block is in the cache, size = %d, data = %s', [dataSize, HexStr(outBuffer^, 16)]);
      {$ENDIF LogPrefetch}
      Result := true;
    end
    else begin
      {$IFDEF LogPrefetch}
      GpLog.Log('[C] ==> block is not in the cache');
      {$ENDIF LogPrefetch}
    end;
  finally hfpcCache.Unlock; end;
end; { THFPrefetchCache.GetBlock }

function THFPrefetchCache.GetCachedBlock(idxBlock: integer): THFCachedBlock;
begin
  Result := THFCachedBlock(hfpcCache[idxBlock]);
end; { THFPrefetchCache.GetCachedBlock }

procedure THFPrefetchCache.InsertBlock(buffer: pointer; numberOfBytes: cardinal;
  offset: HugeInt);
var
  idxBlock: integer;
begin
  hfpcCache.Lock;
  try
    {$IFDEF LogPrefetch}
    GpLog.Log('[C] Inserting block at %d, size = %d, data = %s', [offset, numberOfBytes, HexStr(buffer^, 16)]);
    {$ENDIF LogPrefetch}
    idxBlock := FindBlock(offset);
    if idxBlock < 0 then begin
      idxBlock := AddBlock(offset);
      {$IFDEF LogPrefetch}
      GpLog.Log('[C] Adding new block');
      {$ENDIF LogPrefetch}
    end
    else begin
      {$IFDEF LogPrefetch}
      GpLog.Log('[C] Reusing existing block, old size = %d', [Block[idxBlock].Size]);
      {$ENDIF LogPrefetch}
    end;
    {$IFDEF LogPrefetch}
    GpLog.Log('[C] ==> store %d @ %p => %p', [numberOfBytes, pointer(buffer), pointer(Block[idxBlock].Data)]);
    {$ENDIF LogPrefetch}
    Move(buffer^, Block[idxBlock].Data^, numberOfBytes);
    Block[idxBlock].Size := numberOfBytes;
    CancelIsReading(offset);
  finally hfpcCache.Unlock; end;
end; { THFPrefetchCache.InsertBlock }

function THFPrefetchCache.IsReadingBlock(offset: HugeInt): boolean;
begin
  hfpcReadingLock.Acquire;
  try
    Result := hfpcReadingList.Contains(offset);
  finally hfpcReadingLock.Release; end;
  {$IFDEF LogPrefetch}
  GpLog.Log('[C] Is reading block at %d = %d', [offset, Ord(Result)]);
  {$ENDIF LogPrefetch}
end; { THFPrefetchCache.IsReadingBlock }

procedure THFPrefetchCache.NotifyIsReading(offset: HugeInt);
begin
  {$IFDEF LogPrefetch}
  GpLog.Log('[C] Notify read operation at %d', [offset]);
  {$ENDIF LogPrefetch}
  hfpcReadingLock.Acquire;
  try
    hfpcReadingList.Ensure(offset);
  finally hfpcReadingLock.Release; end;
end; { THFPrefetchCache.NotifyIsReading }

function THFPrefetchCache.WaitForBlock(offset: int64; wait_ms: integer): boolean;
var
  startTime_ms: int64;
begin
  Result := true;
  startTime_ms := DSiTimeGetTime64;
  while ((DSiTimeGetTime64 - startTime_ms) < wait_ms) do begin
    if not IsReadingBlock(offset) then
      Exit;
    DSiYield;
  end;
  Result := false;
end; { THFPrefetchCache.WaitForBlock }

{ THFPrefetcher }

constructor THFPrefetcher.Create(const fileName: string; prefetchHandle: THandle;
  prefetchCache: IHFPrefetchCache; bufferSize: cardinal; numBuffers: integer);
begin
  Assert(bufferSize > 0);
  hfpWorker :=
    CreateTask(TGpHugeFilePrefetch.Create(), Format('Prefetcher for %s', [fileName]))
      .SetParameter('Handle', prefetchHandle)
      .SetParameter('Cache', prefetchCache)
      .SetParameter('BufferSize', bufferSize)
      .SetParameter('NumBuffers', numBuffers) 
      .Alertable
      .Run;
  Seek(0);
end; { THFPrefetcher.Create }

destructor THFPrefetcher.Destroy;
begin
  if assigned(hfpWorker) then
    hfpWorker.Terminate(30*1000);
  inherited;
end; { THFPrefetcher.Destroy }

procedure THFPrefetcher.Seek(offset: HugeInt);
begin
  {$IFDEF LogPrefetch}
  GpLog.Log('[P] Seek %d', [offset]);
  {$ENDIF LogPrefetch}
  hfpWorker.Comm.SendWait(WM_SEEK, int64(offset), 0);
end; { THFPrefetcher.Seek }

{ THFCachedBlock }

destructor THFCachedBlock.Destroy;
begin
  {$IFDEF LogPrefetch}
  GpLog.Log('[B] Destroy %p at %d', [hfcbData, hfcbOffset]);
  {$ENDIF LogPrefetch}
  DSiFreeMemAndNil(hfcbData);
  inherited;
end; { THFCachedBlock.Destroy }

constructor THFCachedBlock.Create(offset: HugeInt; bufferSize: integer);
begin
  hfcbOffset := offset;
  GetMem(hfcbData, bufferSize);
  {$IFDEF LogPrefetch}
  GpLog.Log('[B] Create %p at %d, memory size = %d', [hfcbData, offset, bufferSize]);
  {$ENDIF LogPrefetch}
end; { THFCachedBlock.Create }

procedure THFCachedBlock.SetSize(const value: integer);
begin
  {$IFDEF LogPrefetch}
  GpLog.Log('[B] Size = %d', [value]);
  {$ENDIF LogPrefetch}
  hfcbSize := value;
end; { THFCachedBlock.SetSize }

{$ENDIF EnablePrefetchSupport}

{$IFDEF UseLogger}
initialization
  GpLog.Log('---');
{$ENDIF UseLogger}
end.

