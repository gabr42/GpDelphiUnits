(*:Shared memory implementation.
   @author Primoz Gabrijelcic
   @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2016, Primoz Gabrijelcic
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
   Creation date     : 2001-06-12
   Last modification : 2016-03-16
   Version           : 4.13
   Tested OS         : Windows 95, 98, NT 4, 2000, XP, 7
</pre>*)(*
   History:
     4.13: 2016-03-16
       - Added 'silentFail' parameter to TGpSharedMemory.Create. If set to True,
         OpenMemory will set LastError property instead of raising an EGpSharedMemory
         exception.
     4.12b: 2014-05-19
       - Fixed writing to TGpShareMemory with the stream interface - it was not possible
         to write into the last byte.
     4.12a: 2010-12-25
       - Units ExtCtrls and Forms are referenced only on pre-2007 Delphis (for
         compatibility).
     4.12: 2009-02-17
       - Compatible with Delphi 2009.
     4.11b: 2009-02-11
       - AttachToThread must update synchronizer's owner thread.
     4.11a: 2007-05-30
       - AllocateHwnd and DeallocateHwnd replaced with thread-safe versions.
       - TTimer replaced with thread-safer TDSiTimer.
     4.11: 2006-05-30
       - Implemented AttachToThread.
     4.10: 2006-05-13
       - Added internal check to ensure that TGpSharedMemory.AcquireMemory is called from
         one thread only.
     4.09: 2003-09-27
       - Added Int[] property to the TGpBaseSharedMemory class.
     4.08: 2003-09-25
       - New class TGpSharedLinkedList implementing double-linked list.
       - New class TGpSharedMemoryCandy created to simplify creation of memory-
         accessing properties.
     4.07a: 2003-05-29
       - Fixed in the resizing logic of the TGpSharedMemoryReader.
     4.07: 2003-01-15
       - Modified TGpSharedMemory.AcquireMemory to allow nested AcquireMemory/
         ReleaseMemory calls (which must not elevate access - IOW read access
         cannot be changed to write access).
     4.06: 2002-11-11
       - Fixed shared memory pool to work in a service.
     4.05: 2002-10-22
       - Added indexed property Address to the TGpBaseSharedMemory returning
         address of the byte at specified index.
     4.04: 2002-10-16
       - Changed protection on all kernel primitives to 'allow everyone' (needed
         to work with services). TGpSharedMemoryPool, however, does not yet work
         with non-interactive services (but it _should_ (completely untested)
         work with interactive service).                                                
     4.03a: 2002-09-26
       - Fixed bug in shared memory area creation.
     4.03: 2002-09-25
       - Added list classes: TGpSharedStreamList, TGpBaseSharedMemoryList,
         TGpSharedSnapshotList, TGpSharedMemoryList
     4.02a: 2002-06-26
       - Fixed double free in TGpSharedPoolReader.MessageMain.
     4.02: 2002-06-19
       - Property TGpBaseSharedMemory.DataPointer made public and readonly.
     4.01a: 2002-06-13
       - Event TGpSharedPoolReader.MessagesWaitingEvent removed as it is not
         really needed.
     4.01: 2002-06-11
       - Method TGpSharedPoolReader.MessagePump added.
       - Event TGpSharedPoolReader.DataReceivedEvent added.
       - Event TGpSharedPoolReader.MessagesWaitingEvent added.
     4.0: 2002-06-11
       - TGpSharedPool completed.
     3.99: 2002-05-28
       - Started work on TGpSharedPool.
       - Reintroduced dependency on GpSync.
     3.01: 2002-05-15
       - New property TGpSharedMemory.Modified. Valid only when memory is
         acquired.
     3.0: 2002-05-09
       - Removed non-working TGpResizableSharedMemory class and merged resizing
         functionality into TGpSharedMemory.
       - Removed dependency on GpSync.
     2.01b: 2002-05-01
       - Fixed bug where TGpSharedStream.Read raised exception when it should
         just return 0.
     2.01a: 2002-04-18
       - Fixed bug where shared resizable memory area was freed even when it
         was still in use.
     2.01: 2001-08-29
       - Added memory access properties [Byte*, Word*, Long*, Word*] to
         TGpSharedMemory and TGpResizableSharedMemory.
       - Created abstract base shared memory class TGpBaseSharedMemory.
       - Added methods MakeSnapshot to TGpSharedMemory and
         TGpResizableSharedMemory. Created TGpSharedSnapshot class.
     2.0: 2001-07-24
       - TGpSharedMemory object now *requires* a name.
       - Added resourceProtection parameter to the TGpSharedMemory constructor.
       - Added readonly property TGpSharedMemory.Size.
       - Added TGpResizableSharedMemory class.
     1.0a: 2001-07-17
       - Bug fixed: 'timeout' paramter in the AcquireMemory method was declared
         as integer instead of DWORD.
     1.0: 2001-06-13
       - Released.
     0.1: 2001-06-12
       - Created.
*)

{$J+} // Required!

{$IFDEF Linux}{$MESSAGE FATAL 'This unit is for Windows only'}{$ENDIF Linux}
{$IFDEF MSWindows}{$WARN SYMBOL_DEPRECATED OFF}{$ENDIF MSWindows}

unit GpSharedMemory;

interface

{$DEFINE NeedExtCtrls}
{$IFDEF ConditionalExpressions}
  {$IF RTLVersion >= 18}{$UNDEF NeedExtCtrls}{$IFEND}
{$ENDIF}

uses
  {$IFDEF Testing}GpTestEnvironment, GpStuff,{$ENDIF Testing}
  Windows,
  Messages,
  SysUtils,
  SyncObjs,
  Classes,
  Contnrs,
  GpSync;

type
  {:Shared memory specific exceptions.
  }
  EGpSharedMemory = class(Exception);

  {Forward class references.
  }
  TGpSharedSnapshot = class;
  TGpBaseSharedMemory = class;

  {:Stream access to the acquired shared memory block. Resizable if underlying
    storage supports resizing.
    @since   2001-08-27
  }
  TGpSharedStream = class(TStream)
  private
    ssCopyStream: TMemoryStream;
    ssMemory    : TGpBaseSharedMemory;
    ssMemoryPos : cardinal;
    ssModified  : boolean;
  protected
    procedure CopyOnWrite; virtual;
    function  GetCurrentData: pointer; virtual;
    function  GetUseStream: boolean; virtual;
    procedure SetMemoryPos(newPos: int64); virtual;
  {properties}
    //:Internal memory stream.
    property CopyStream: TMemoryStream read ssCopyStream;
    //:Pointer to the current position inside shared memory object.
    property CurrentData: pointer read GetCurrentData;
    //:Shared memory owner.
    property Memory: TGpBaseSharedMemory read ssMemory;
    //:Position (offset) in the shared memory object.
    property MemoryPos: cardinal read ssMemoryPos write ssMemoryPos;
    //:Indicates whether internal memory stream (CopyStream) is allocated.
    property UseStream: boolean read GetUseStream;
  public
    constructor Create(memory: TGpBaseSharedMemory);
    destructor  Destroy; override;
    function  Read(var buffer; count: longint): longint; override;
    function  Seek(offset: longint; origin: word): longint; override;
    procedure SetSize(newSize: longint); override;
    function  Write(const buffer; count: longint): longint; override;
  {properties}
    //:Indicates whether data in the stream was written to.
    property IsModified: boolean read ssModified;
  end; { TGpSharedStream }

  {:A list of TGpSharedStream objects.
  }
  TGpSharedStreamList = class(TObjectList)
  protected
    function  GetItem(idx: integer): TGpSharedStream;
    procedure SetItem(idx: integer; const Value: TGpSharedStream);
  public
    function  Add(gpSharedStream: TGpSharedStream): integer; reintroduce;
    function  AddNew(memory: TGpBaseSharedMemory): TGpSharedStream;
    function  Extract(gpSharedStream: TGpSharedStream): TGpSharedStream; reintroduce;
    function  IndexOf(gpSharedStream: TGpSharedStream): integer; reintroduce;
    procedure Insert(idx: integer; gpSharedStream: TGpSharedStream); reintroduce;
    function  Remove(gpSharedStream: TGpSharedStream): integer; reintroduce;
    property Items[idx: integer]: TGpSharedStream read GetItem write SetItem; default;
  end; { TGpSharedStreamList }

  {:Abstract base shared memory class.
    @since   2001-08-24
  }
  TGpBaseSharedMemory = class
  private
    gbsmDataPointer: pointer;
    gbsmIsWriting  : boolean;
    gbsmMaxSize    : cardinal;
    gbsmObjectName : string;
    gbsmSize       : cardinal;
    gbsmStream     : TGpSharedStream;
    gbsmWasCreated : boolean;
    function  GetAddress(byteOffset: integer): pointer;
    function  GetByte(byteOffset: integer): byte;
    function  GetByteIdx(idx: integer): byte;
    function  GetHuge(byteOffset: integer): int64;
    function  GetHugeIdx(idx: integer): int64;
    function  GetInt(byteOffset: integer): integer;
    function  GetIntIdx(idx: integer): integer;
    function  GetLong(byteOffset: integer): longword;
    function  GetLongIdx(idx: integer): longword;
    function  GetWord(byteOffset: integer): word;
    function  GetWordIdx(idx: integer): word;
    procedure SetByte(byteOffset: integer; Value: byte);
    procedure SetByteIdx(idx: integer; Value: byte);
    procedure SetHuge(byteOffset: integer; Value: int64);
    procedure SetHugeIdx(idx: integer; Value: int64);
    procedure SetInt(byteOffset: integer; Value: integer);
    procedure SetIntIdx(idx: integer; Value: integer);
    procedure SetLong(byteOffset: integer; Value: longword);
    procedure SetLongIdx(idx: integer; Value: longword);
    procedure SetWord(byteOffset: integer; Value: word);
    procedure SetWordIdx(idx: integer; Value: word);
  protected
    procedure CheckBoundaries(offset, size: cardinal); virtual;
    procedure CheckDMA; virtual;
    procedure FreeStream; virtual;
    function  GetAsStream: TGpSharedStream; virtual;
    function  GetAsString: string; virtual;
    function  GetCreated: boolean; virtual;
    procedure GetData(offset, size: cardinal; out buffer); virtual; abstract;
    function  GetIsWriting: boolean; virtual;
    function  GetName: string; virtual;
    function  GetSize: cardinal; virtual;
    function  GetUpperSize: cardinal; virtual;
    function  HaveStream: boolean; virtual;
    procedure ResizeMemory(const newSize: cardinal); virtual;
    procedure SetAsString(const Value: string); virtual;
    procedure SetCreated(const newCreated: boolean); virtual;
    procedure SetData(offset, size: cardinal; var buffer); virtual; abstract;
    procedure SetDataPointer(const Value: pointer); virtual;
    procedure SetIsWriting(const newIsWriting: boolean); virtual;
    procedure SetMaxSize(const newMaxSize: cardinal); virtual;
    procedure SetName(const newName: string); virtual;
    procedure SetSize(const newSize: cardinal); virtual;
    function  SupportsResize: boolean; virtual;
  {properties}
    //:Read-only access to the underlying stream object (valid only when HaveStream returns True).
    property CopyStream: TGpSharedStream read gbsmStream;
    //:Size of the shared memory block.
    property MemorySize: cardinal read gbsmSize;
  public
    function  Acquired: boolean; virtual;
    function  AcquireMemory(forWriting: boolean; timeout: DWORD): pointer; virtual; abstract;
    function  MakeSnapshot: TGpSharedSnapshot; virtual; abstract;
    procedure ReleaseMemory; virtual;
  {properties}
    //:True if memory is resizable.
    property IsResizable: boolean read SupportsResize;
    //:True is memory is acquired for writing.
    property IsWriting: boolean read GetIsWriting;
    //:Maximum size of the shared memory.
    property MaxSize: cardinal read gbsmMaxSize;
    //:Shared memory name.
    property Name: string read GetName;
    //:Shared memory size.
    property Size: cardinal read GetSize;
    //:String interface
    property AsString: string read GetAsString write SetAsString;
    //:True if shared memory was created in the constructor.
    property WasCreated: boolean read GetCreated;
  {pointer interface}
    //:Pointer to the specific byte;
    property Address[byteOffset: integer]: pointer read GetAddress;
    //:Pointer to the shared memory (when acquired).
    property DataPointer: pointer read gbsmDataPointer;
  {direct memory access}
    //:8-bit integer (unsigned) at specified offset (0-based).
    property Byte[byteOffset: integer]: byte read GetByte write SetByte;
    //:Idx-th (0-based) 8-bit integer (unsigned). Same as 'Byte'.
    property ByteIdx[idx: integer]: byte read GetByteIdx write SetByteIdx;
    //:64-bit integer (signed) at specified offset (0-based).
    property Huge[byteOffset: integer]: int64 read GetHuge write SetHuge;
    //:Idx-th (0-based) 64-bit integer (signed). Same as Huge[idx*SizeOf(int64)].
    property HugeIdx[idx: integer]: int64 read GetHugeIdx write SetHugeIdx;
    //:32-bit integer (signed) at specified offset (0-based).
    property Int[byteOffset: integer]: integer read GetInt write SetInt;
    //:Idx-th (0-based) 32-bit integer (signed). Same as Long[idx*SizeOf(longword)].
    property IntIdx[idx: integer]: integer read GetIntIdx write SetIntIdx;
    //:32-bit integer (unsigned) at specified offset (0-based).
    property Long[byteOffset: integer]: longword read GetLong write SetLong;
    //:Idx-th (0-based) 32-bit integer (unsigned). Same as Long[idx*SizeOf(longword)].
    property LongIdx[idx: integer]: longword read GetLongIdx write SetLongIdx;
    //:16-bit integer (unsigned) at specified offset (0-based).
    property Word[byteOffset: integer]: word read GetWord write SetWord;
    //:Idx-th (0-based) 16-bit integer (unsigned). Same as Word[idx*SizeOf(word)].
    property WordIdx[idx: integer]: word read GetWordIdx write SetWordIdx;
  {stream interface}
    property AsStream: TGpSharedStream read GetAsStream;
  end; { TGpBaseSharedMemory }

  {:A list of TGpBaseSharedMemory objects.
  }
  TGpBaseSharedMemoryList = class(TObjectList)
  protected
    function  GetItem(idx: integer): TGpBaseSharedMemory;
    procedure SetItem(idx: integer; const Value: TGpBaseSharedMemory);
  public
    function  Add(gpBaseSharedMemory: TGpBaseSharedMemory): integer; reintroduce;
    function  Extract(gpBaseSharedMemory: TGpBaseSharedMemory): TGpBaseSharedMemory; reintroduce;
    function  IndexOf(gpBaseSharedMemory: TGpBaseSharedMemory): integer; reintroduce;
    procedure Insert(idx: integer; gpBaseSharedMemory: TGpBaseSharedMemory); reintroduce;
    function  Remove(gpBaseSharedMemory: TGpBaseSharedMemory): integer; reintroduce;
    property Items[idx: integer]: TGpBaseSharedMemory read GetItem write SetItem; default;
  end; { TGpBaseSharedMemoryList }

  {:Shared memory snapshot. Based on TGpBaseSharedMemory to allow indexed access
    (Byte/Word/Long/Huge properties).
    @since   2001-08-24
  }
  TGpSharedSnapshot = class(TGpBaseSharedMemory)
  private
  protected
    procedure GetData(offset, size: cardinal; out buffer); override;
    function  GetIsWriting: boolean; override;
    procedure SetData(offset, size: cardinal; var buffer); override;
  public
    constructor Create(sharedMemoryName: string; memoryStart: pointer;
      size: cardinal);
    destructor  Destroy; override;
    function  Acquired: boolean; override;
    function  AcquireMemory(forWriting: boolean; timeout: DWORD): pointer; override;
    function  MakeSnapshot: TGpSharedSnapshot; override;
  end; { TGpSharedSnapshot }

  {:A list of TGpSharedSnapshot objects.
  }
  TGpSharedSnapshotList = class(TObjectList)
  protected
    function  GetItem(idx: integer): TGpSharedSnapshot;
    procedure SetItem(idx: integer; const Value: TGpSharedSnapshot);
  public
    function  Add(gpSharedSnapshot: TGpSharedSnapshot): integer; reintroduce;
    function  AddNew(sharedMemoryName: string; memoryStart: pointer;
      size: cardinal): TGpSharedSnapshot;
    function  Extract(gpSharedSnapshot: TGpSharedSnapshot): TGpSharedSnapshot; reintroduce;
    function  IndexOf(gpSharedSnapshot: TGpSharedSnapshot): integer; reintroduce;
    procedure Insert(idx: integer; gpSharedSnapshot: TGpSharedSnapshot); reintroduce;
    function  Remove(gpSharedSnapshot: TGpSharedSnapshot): integer; reintroduce;
    property Items[idx: integer]: TGpSharedSnapshot read GetItem write SetItem; default;
  end; { TGpSharedSnapshotList }

  {:Shared memory implementation. Access to the shared memory is protected with
    the single-writer-multiple-readers object. Creation and initialization of
    the shared memory is protected with the mutex. Uses mutex [objectName]$MTX,
    mutex SWMRMutexNoWriter[objectName]$SWMR,
    event SWMREventNoReaders[objectName]$SWMR,
    semaphore SWMRSemNumReaders[objectName]$SWMR, and file mapping [objectName].
    Shared memory is initialized to 0 when created or when growing.
    Memory layout:
      [mapped ptr]
        header: TGpSharedMemoryHeader
      [application ptr]
        application data
      [end of allocated area]
  }
  TGpSharedMemory = class(TGpBaseSharedMemory)
  private
    grmFileView     : pointer{MapViewOfFile};
    gsmDesiredAccess: DWORD;
    gsmFileMapping  : THandle{CreateFileMapping};
    gsmInitializer  : THandle{CreateMutex};
    gsmLastError    : cardinal;
    gsmModifiedCount: int64;
    gsmOwningThread : DWORD;
    gsmSynchronizer : TGpSWMR;
    gsmTimesMember  : integer;
  protected
    procedure GetData(offset, size: cardinal; out buffer); override;
    function  GetModified: boolean; virtual;
    function  MapView(mappingObject: THandle; desiredAccess: DWORD;
      mappingSize: DWORD = 0; getFromHeader: boolean = true;
      initialize: boolean = false): pointer; virtual;
    function  OpenMemory(silentFail: boolean = false): boolean; virtual;
    procedure ResizeMemory(const newSize: cardinal); override;
    procedure SetData(offset, size: cardinal; var buffer); override;
    procedure SetSize(const newSize: cardinal); override;
    procedure UnmapView(var baseAddress: pointer); virtual;
  public
    constructor Create(objectName: string; size: cardinal;
      maxSize: cardinal = 0; resourceProtection: boolean = true;
      silentFail: boolean = false);
    destructor  Destroy; override;
    function  AcquireMemory(forWriting: boolean; timeout: DWORD): pointer; override;
    procedure AttachToThread;
    function  MakeSnapshot: TGpSharedSnapshot; override;
    procedure ReleaseMemory; override;
    //:Was shared memory modified since last access?
    property Modified: boolean read GetModified;
    //:Shared memory size.
    property Size: cardinal read GetSize write SetSize;
    //:Error code set in Create if silentFail is True and memory cannot be opened.
    property LastError: cardinal read gsmLastError;
  end; { TGpSharedMemory }

  {:A list of TGpSharedMemory objects.
  }
  TGpSharedMemoryList = class(TObjectList)
  protected
    function  GetItem(idx: integer): TGpSharedMemory;
    procedure SetItem(idx: integer; const Value: TGpSharedMemory);
  public
    function  Add(gpSharedMemory: TGpSharedMemory): integer; reintroduce;
    function  AddNew(objectName: string; size: cardinal; maxSize: cardinal = 0;
      resourceProtection: boolean = true): TGpSharedMemory;
    function  Extract(gpSharedMemory: TGpSharedMemory): TGpSharedMemory; reintroduce;
    function  IndexOf(gpSharedMemory: TGpSharedMemory): integer; reintroduce;
    procedure Insert(idx: integer; gpSharedMemory: TGpSharedMemory); reintroduce;
    function  Remove(gpSharedMemory: TGpSharedMemory): integer; reintroduce;
    property Items[idx: integer]: TGpSharedMemory read GetItem write SetItem; default;
  end; { TGpSharedMemoryList }

  {:Abstract wrapper for simple creation of indexed properties.
    @since   2003-09-25
  }
  TGpSharedMemoryCandy = class
  protected
    function  GetAddress(baseAddress: integer): pointer;
    function  GetBaseAddress(baseAddress: integer; offset: integer): pointer;
    function  GetBaseByte(baseAddress: integer; offset: integer): byte;
    function  GetBaseHuge(baseAddress: integer; offset: integer): int64;
    function  GetBaseInt(baseAddress: integer; offset: integer): integer;
    function  GetBaseLong(baseAddress: integer; offset: integer): longword;
    function  GetBaseWord(baseAddress: integer; offset: integer): word;
    function  GetByte(baseAddress: integer): byte;
    function  GetHuge(baseAddress: integer): int64;
    function  GetInt(baseAddress: integer): integer;
    function  GetLong(baseAddress: integer): longword;
    function  GetWord(baseAddress: integer): word;
    function  Memory: TGpBaseSharedMemory; virtual; abstract;
    procedure SetBaseByte(baseAddress: integer; offset: integer; value: byte);
    procedure SetBaseHuge(baseAddress: integer; offset: integer; value: int64);
    procedure SetBaseInt(baseAddress: integer; offset: integer; value: integer);
    procedure SetBaseLong(baseAddress: integer; offset: integer; value: longword);
    procedure SetBaseWord(baseAddress: integer; offset: integer; value: word);
    procedure SetByte(baseAddress: integer; value: byte);
    procedure SetHuge(baseAddress: integer; value: int64);
    procedure SetInt(baseAddress: integer; value: integer);
    procedure SetLong(baseAddress: integer; value: longword);
    procedure SetWord(baseAddress: integer; value: word);
  end; { TGpSharedMemoryCandy }

  {:Implements doubly linked list stored inside shared memory. Keeps count of
    linked entries without offering direct access to an entry (except the first
    and the last, of course).
    Memory layout:
      [ 0]   <signature:8>
      [ 8]   <number of entries:4>
      [12]   <alignment filler:4>
      [16]   <head next:4>
      [20]   <head prev:4>
      [24]   <tail next:4>
      [28]   <tail prev:4>
    @since   2003-09-25
  }
  TGpSharedLinkedList = class(TGpSharedMemoryCandy)
  private
    sllBaseAddress    : integer;
    sllEntryHeaderSize: integer;
    sllHeaderSize     : integer;
    sllListHead       : integer;
    sllListTail       : integer;
    sllMemory         : TGpBaseSharedMemory;
  protected
    procedure Initialize;
    function  Memory: TGpBaseSharedMemory; override;
    property NextInList[baseAddress: integer]: integer index 0 read GetBaseInt write SetBaseInt;
    property NumberOfEntries[baseAddress: integer]: integer index 8 read GetBaseInt write SetBaseInt;
    property PrevInList[baseAddress: integer]: integer index 4 read GetBaseInt write SetBaseInt;
    property Signature[baseAddress: integer]: int64 index 0 read GetBaseHuge write SetBaseHuge;
  public
    constructor Create(memory: TGpBaseSharedMemory; baseAddress: integer);
    procedure Clear;
    function  Count: integer;
    procedure Dequeue(entryAddress: integer);
    procedure EnqueueAfter(existingEntry, entryAddress: integer);
    procedure EnqueueBefore(existingEntry, entryAddress: integer);
    procedure EnqueueHead(entryAddress: integer);
    procedure EnqueueTail(entryAddress: integer);
    function  Head: integer;
    function  IsEmpty: boolean;
    function  Next(entryAddress: integer): integer;
    function  Prev(entryAddress: integer): integer;
    function  Tail: integer;
    property EntryHeaderSize: integer read sllEntryHeaderSize;
    property HeaderSize: integer read sllHeaderSize;
  end; { TGpSharedLinkedList }

  {:Shared pool access errors.
    @enum speOK                 No error.
    @enum speInvalidVersion     Invalid reader version.
    @enum speIncompatibleHeader Incompatible header found.
    @enum speNoReader           No reader available.
    @enum spePoolFull           Pool is full.
    @enum speAlreadyActive      Another reader already owns this pool.
    @enum speBufferTooBig       Buffer doesn't belong to the pool and is too big
                                to be copied in one peace.
    @enum speTimeout            Access to the pool is blocked.
    @enum speWin32Error         Win32 error. Check Windows.GetLastError for more
                                information.
  //internal
    @enum speNotOwner           Memory block is not owned by the pool.
    @enum speInternalError      Internal prograaming error.
  }
  TGpSharedPoolError = (speOK, speInvalidVersion, speIncompatibleHeader,
    speNoReader, spePoolFull, speAlreadyActive, speBufferTooBig, speTimeout,
    speWin32Error, speNotOwner, speInternalError);

const
  //:English error messages.
  CGpSharedPoolErrorMessagesEN: array [TGpSharedPoolError] of string = (
    'No error.',
    'Incompatible Reader version.',
    'Header with incompatible parameters already exists.',
    'No Reader available.',
    'Pool is full.',
    'Another Reader already owns this pool.',
    'Buffer is too big.',
    'Timeout.',
    'Win32 error.',
    'INTERNAL Not an owner.',
    'INTERNAL Programming error.'
  );

type
  {:Header part of the shared pool index block.
  }
  TGpSharedPoolHeader = packed record
  //static
    sphSignature        : int64;                  // "magic" signature
    sphVersion          : cardinal;               // version; currently always 1
    sphInitialBufferSize: cardinal;               // initial size of shared memory buffers
    sphMaxBufferSize    : cardinal;               // maximum size of shared memory buffers
    sphMinBuffers       : cardinal;               // minimum number of memory buffers
    sphMaxBuffers       : cardinal;               // maximum number of memory buffers
    sphSweepTimeoutSec  : cardinal;               // number of seconds buffer must be left untouched before it is disposed
    sphResizeIncrement  : cardinal;               // number of buffers to be allocated when resizing
    sphResizeThreshold  : cardinal;               // number of free buffers when resize should be triggered
    sphOwnersToken      : array [0..263] of char; // name of the owner's token; used to generate shared memory buffer names
    sphIndexEntrySize   : cardinal;               // size of the index entry
    sphNumEntries       : cardinal;               // number of entries in the directory
  //dynamic
    sphNumBuffers       : cardinal;               // number of memory buffers
    sphFreeBuffers      : cardinal;               // number of free memory buffers
  //list headers
    sphFreeList         : cardinal;               // index of the last used free entry
    sphQueuedList       : cardinal;               // index of the first queue entry
    sphDisposedList     : cardinal;               // index of the first disposed entry
  end; { TGpSharedPoolHeader }
  PGpSharedPoolHeader = ^TGpSharedPoolHeader;

  {:Pool index entry status.
    @enum iesFree      Block is ready to be used.
    @enum iesAllocated Block is in use.
    @enum iesQueued    Block is queued for the reader.
    @enum iesDisposed  Block was disposed.
  }
  TGpSharedPoolIndexEntryStatus = (iesFree, iesAllocated, iesQueued, iesDisposed);

  {:Index entry in the shared pool index block. Describes one shared memory
    buffer.
  }
  TGpSharedPoolIndexEntry = packed record
    spieStatus    : integer;         // status (free, allocated, queued, disposed)
    spieReleasedAt: TDateTime;       // time then buffer was released
  //links
    spiePrevious  : cardinal;        // link to the previous entry with the same status
    spieNext      : cardinal;        // link to the next entry with the same status
  //internals
    spieHandle    : TGpSharedMemory; // pointer to the shared memory buffer !_on the reader_!
  end; { TGpSharedPoolIndexEntry }
  PGpSharedPoolIndexEntry = ^TGpSharedPoolIndexEntry;

  {:Signature of the method that will forward data block to the recipient.
  }
  TGpSharedPoolDataForwarder = procedure(shm: TGpSharedMemory) of object;

  {:Index of the pooled shared memory areas.
    @since   2002-05-28
  }
  TGpSharedPoolIndex = class
  private
    spiDirectoryBlock: TGpSharedMemory;
    spiHeaderBlock   : TGpSharedMemory;
    spiIsReader      : boolean;
    spiPoolName      : string;
  protected
    function  BufferInitialSize: cardinal;
    function  BufferMaxSize: cardinal;
    function  GetEntry(idx: cardinal): PGpSharedPoolIndexEntry;
    function  GetEntryIndex(name: string): cardinal;
    function  GetEntryName(idx: cardinal): string;
    function  InitializeDirectory: boolean;
    procedure Link(entryIdx: cardinal; var listHead: cardinal);
    function  MaxBuffers: cardinal;
    function  NumBuffers: cardinal;
    function  NumEntries: cardinal;
    function  ResizeThreshold: cardinal;
    function  SafeGetHeader(methodName: string; checkIfInitialized: boolean = true): PGpSharedPoolHeader;
    procedure Unlink(entryIdx: cardinal; var listHead: cardinal);
    property Entry[idx: cardinal]: PGpSharedPoolIndexEntry read GetEntry;
  public
    constructor Create(poolName: string; isReader: boolean);
    destructor  Destroy; override;
    function  Acquire(timeout: DWORD): boolean;
    function  CanResize: boolean;
    function  FreeBuffer(var buffer: TGpSharedMemory): boolean;
    function  FreeBuffers: cardinal;
    function  GetFreeBuffer: TGpSharedMemory;
    function  Initialize(initialBufferSize, maxBufferSize, startNumBuffers,
      maxNumBuffers, resizeIncrement, resizeThreshold, minNumBuffers,
      sweepTimeoutSec: cardinal; ownersToken: string): TGpSharedPoolError;
    function  IsInitialized: boolean;
    function  PrepareToSend(var buffer: TGpSharedMemory): TGpSharedPoolError;
    procedure ReadData(dataForwarder: TGpSharedPoolDataForwarder);
    procedure Release;
    function  ShouldResize: boolean;
    function  SupportedVersion: boolean;
    procedure Sweep;
    function  TryToResize(numBuffers: cardinal = 0): TGpSharedPoolError;
    function  Version: cardinal;
  end; { TGpSharedPoolIndex }

  {:Pool of shared memory objects combined with a Reader/Writers mechanism.
    Abstract base class.
    Owned shared memory objects have _no_ access protection!
    In addition to owned shared memory areas (named [owner's TGpToken]/Pool/%d)
    uses shared memories [objectName]/Header and [objectName]/Directory.
  }
  TGpBaseSharedPool = class
  private
    bspAcquiredList: TList{TGpSharedMemory};
    bspIndex       : TGpSharedPoolIndex;
    bspLastError   : TGpSharedPoolError;
    bspName        : AnsiString;
  protected
    function  AcquireIndex(checkIfInitialized: boolean = true): boolean; virtual;
    function  ClearError: boolean; virtual;
    function  GetMessageQueue: TGpMessageQueue; virtual; abstract;
    function  InternalAcquireBuffer(timeout: DWORD;
      doAcquireIndex: boolean): TGpSharedMemory; virtual;
    function  InternalAcquireCopy(shm: TGpSharedMemory; timeout: DWORD;
      doAcquireIndex: boolean): TGpSharedMemory; virtual;
    function  IsReader: boolean; virtual; abstract;
    function  IsReaderAlive: boolean; virtual;
    function  ReaderMessageQueueName: AnsiString; virtual;
    function  ReaderMutexName: AnsiString; virtual;
    procedure ReleaseIndex; virtual;
    function  SetError(errorCode: TGpSharedPoolError): boolean; virtual;
    function TokenPrefix: AnsiString;
    function  UnprotectedTryToResize: boolean; virtual;
    //:List of acquired buffers.
    property AcquiredList: TList read bspAcquiredList;
    //:Index object.
    property Index: TGpSharedPoolIndex read bspIndex;
    //:Message queue object.
    property MessageQueue: TGpMessageQueue read GetMessageQueue;
  public
    constructor Create(objectName: AnsiString); virtual;
    destructor  Destroy; override;
    function  AcquireBuffer(timeout: DWORD): TGpSharedMemory;
    function  AcquireCopy(shm: TGpSharedMemory; timeout: DWORD): TGpSharedMemory;
    procedure ReleaseBuffer(var shm: TGpSharedMemory);
    function  SendBuffer(var shm: TGpSharedMemory): boolean;
    //:Last error code.
    property LastError: TGpSharedPoolError read bspLastError;
    //:Shared pool name.
    property Name: AnsiString read bspName;
  end; { TGpBaseSharedPool }

const
  //:Default resize increment. Zero means 'allocate another bunch of [initial size] buffers'.
  CDefResizeIncrement = 0;
  //:Default resize threshold (number of free buffers when resize is triggered). Zero means 'calculate automagically'. Automatically calculated threshold lies in range CMinAutoThreshold..CMaxAutoThreshold.
  CDefResizeThreshold = 0;
  //:Default minimum number of buffers. Zero means 'same as initial size'.
  CDefMinNumBuffers   = 0;
  //:Default number seconds between inactive buffer sweeping.
  CDefSweepTimeoutSec = 15;
  //:Use this value as a sweep timeout to disable sweeping.
  CDisableSweep       = cardinal($FFFFFFFFF);

  //:How soon shoud the Reader wake up if some important processing fails.
  CFailedProcessingWakeup = 100 {ms};

  //:Lowest resize threshold when calculated automagically.
  CMinAutoThreshold = 3;
  //:Highest resize threshold when calculated automagically.
  CMaxAutoThreshold = 10;

type
  {:Shared pool reader data notification event.
    @param shm Shared memory block containing received data. Must be released
               (in the event handler or later) with
               TGpSharedPool(Sender).ReleaseMemory(shm).
  }
  TGpSharedPoolDataReceivedNotify = procedure(Sender: TObject;
    shm: TGpSharedMemory) of object;

  {:Shared pool resize data notification event.
    @param oldSize Number of shared memory buffers in the pool before resize.
    @param newSize Number of shared memory buffers in the pool after resize.
  }
  TGpSharedPoolResizedNotify = procedure(Sender: TObject; oldSize,
    newSize: cardinal) of object;

  {:Shared pool reader/owner. Only one reader per pool is permitted.
    In addition to kernel objects used by the parent, uses mutex
    [objectName]/Reader and message queue [objectName]/MQ.

    Example: How to use reader from a thread

      procedure TTestThread.SafeExecute;
      var
        handles: array [0..1] of THandle;
        reader : TGpSharedPoolReader;
        shm    : TGpSharedMemory;
        waitRes: DWORD;
      begin
        reader := TGpSharedPoolReader.Create('test');
        reader.Initialize(1024,10240,2,4);
        handles[0] := TerminateEvent;
        handles[1] := reader.DataReceivedEvent;
        repeat 
          waitRes := MsgWaitForMultipleObjects(Length(handles), handles, false, INFINITE, QS_ALLINPUT);
          if waitRes = (WAIT_OBJECT_0+1) then begin
            repeat
              shm := reader.GetNextReceived;
              if not assigned(shm) then
                break; //repeat
              // do something with the buffer
              reader.ReleaseBuffer(shm);
            until false;
          end
          else if waitRes = (WAIT_OBJECT_0+2) then
            // do nothing
          else
            break; //repeat
          reader.ProcessMessages
        until false;
        reader.Free;
      end;
  }
  TGpSharedPoolReader = class(TGpBaseSharedPool)
  private
    sprDataReceivedEvent : THandle{CreateEvent};
    sprFailedReadData    : boolean;
    sprFailedResize      : boolean;
    sprLiveTimers        : TObjectList{of TDSiTimer};
    sprMessageQueueReader: TGpMessageQueueReader;
    sprMessageWindow     : THandle{AllocateHwnd};
    sprOnDataReceived    : TGpSharedPoolDataReceivedNotify;
    sprOnResized         : TGpSharedPoolResizedNotify;
    sprReaderMutex       : THandle{CreateMutex};
    sprReceivedDataList  : TList{of TGpSharedMemory};
    sprSweepTimeoutSec   : cardinal;
  protected
    procedure DoDataReceived(shm: TGpSharedMemory); virtual;
    procedure DoResized(oldSize, newSize: cardinal); virtual;
    function  GetMessageQueue: TGpMessageQueue; override;
    function  IsReader: boolean; override;
    procedure MessageMain(var Message: TMessage); virtual;
    procedure ProcessTimer(Sender: TObject); virtual;
    function  ReadData: boolean; virtual;
    procedure StoreReceivedData(shm: TGpSharedMemory); virtual;
    function  Sweep: boolean; virtual;
    procedure TriggerWakeup(afterms, messageNum: cardinal); virtual;
    function  TryToResize: boolean; virtual;
    function  UnprotectedTryToResize: boolean; override;
  public
    constructor Create(objectName: AnsiString); override;
    destructor  Destroy; override;
    function  GetNextReceived: TGpSharedMemory;
    function  Initialize(initialBufferSize, maxBufferSize, startNumBuffers,
      maxNumBuffers: cardinal;
      resizeIncrement: cardinal = CDefResizeIncrement;
      resizeThreshold: cardinal = CDefResizeThreshold;
      minNumBuffers: cardinal = CDefMinNumBuffers;
      sweepTimeoutSec: cardinal = CDefSweepTimeoutSec): boolean;
    procedure ProcessMessages;
    //:Auto-reset event that is set when data is received.
    property DataReceivedEvent: THandle read sprDataReceivedEvent;
    //:Called when data buffer is received.
    property OnDataReceived: TGpSharedPoolDataReceivedNotify
      read sprOnDataReceived write sprOnDataReceived;
    //:Called when data buffer is resized.
    property OnResized: TGpSharedPoolResizedNotify
      read sprOnResized write sprOnResized;
  end; { TGpSharedPoolReader }

  {:Shared pool writer. Multiple writers are permitted.
  }
  TGpSharedPoolWriter = class(TGpBaseSharedPool)
  private
    sprMessageQueue: TGpMessageQueueWriter;
  protected
    function  GetMessageQueue: TGpMessageQueue; override;
    function  IsReader: boolean; override;
  public
    constructor Create(objectName: AnsiString); override;
    destructor  Destroy; override;
  end; { TGpSharedPoolWriter }

  {$IFDEF Testing}
  {:TGpSharedMemory testing class.
    @since   2001-08-24
  }
  TGpTestSharedMemory = class(TGpTest)
  private
    tsmData    : pointer;
    tsmMemory  : TGpBaseSharedMemory;
    tsmSnapshot: TGpSharedSnapshot;
  protected
    procedure DoResize(newSize: cardinal);
    procedure RunAcquired(acquireForWriting, shouldSucceed: boolean); virtual;
    procedure RunCheckSize(expectedSize: cardinal); virtual;
    procedure RunCheckState(expectedAcquired, expectedIsWriting: boolean); virtual;
    procedure RunCreate(expectedWasCreated: boolean; createResizable: boolean); virtual;
    procedure RunDestroy; virtual;
    procedure RunFreeSnapshot; virtual;
    procedure RunMakeSnapshot; virtual;
    procedure RunMemAccess(testWriteAccess: boolean; testValue: cardinal); virtual;
    procedure RunRelease; virtual;
    procedure RunSizeStream; virtual;
    procedure RunTestSnapshot(testWriteAccess: boolean; testValue: cardinal); virtual;
    procedure RunTestStream(testWriteAccess: boolean; testValue: longword;
      readWritePastEnd: boolean); virtual;
    procedure TestMemAccess(memory: TGpBaseSharedMemory; testWriteAccess: boolean;
      testValue: longword); virtual;
    procedure TestStreamAccess(memory: TGpBaseSharedMemory;
      testWriteAccess: boolean; testValue: longword; readWritePastEnd: boolean); virtual;
  public
    procedure RunCommand; override;
    function  RunTest: boolean; override;
  end; { TGpTestSharedMemory }

  {:TGpSharedPool* testing class.
    @since   2002-06-06
  }
  TGpTestSharedPool = class(TGpTest)
  private
    tspPool   : TGpBaseSharedPool;
    tspShmList: TList;
  protected
    procedure RunAcquire(timeout, expectedRetCode: integer); virtual;
    procedure RunAcquireForeign; virtual;
    procedure RunCreateReader(expectedRetCode, initialSize, maxSize, initialNumBuf, maxNumBuf: integer); virtual;
    procedure RunCreateWriter; virtual;
    procedure RunDestroy; virtual;
    procedure RunReadData; virtual;
    procedure RunRelease; virtual;
    procedure RunSend(expectedStatus: boolean); virtual;
    procedure RunSweep; virtual;
  public
    constructor Create; override;
    destructor  Destroy; override;
    procedure RunCommand; override;
    function  RunTest: boolean; override;
  end; { TGpTestSharedPool }
  {$ENDIF Testing}

implementation

uses
{$IF CompilerVersion >= 26}
  System.Types,
{$IFEND}
{$IFDEF NeedExtCtrls}
  ExtCtrls,
  Forms,
{$ENDIF NeedExtCtrls}
  Math,
  DSiWin32,
  GpSecurity;

var
  CPageSize: DWORD; // page size; initialized in unit initialization section

const
  // Reader-Writer and communication
  //:Sent from message queue when messages are waiting.
  WM_MQ_MESSAGE = WM_USER;
  //:Sent from Writer to Reader when running out of pool space.
  WM_PLEASE_RESIZE = WM_USER+1;
  //:Sent from Writer to Reader when buffer is sent.
  WM_DATA_SENT = WM_USER+2;
  //:Sent from Reader to itself when Sweeper should execute.
  WM_SWEEP = WM_USER+3;
  //:Sent from Reader to itself when failed processing should continue.
  WM_CONTINUE = WM_USER+4;
  //:Sent from Reader to itself when TDSiTimer must be destroyed.
  WM_KILL_TIMER = WM_USER+5;

  //:Size of the shared pool message queue.
  CGpSharedPoolMessageQueueSize = 1024;

  //:Shared pool message queue write timeout (in milliseconds).
  CGpSharedPoolMessageQueueWriteTimeout = 5000;

  //:Shared pool messge queue read timeout (in milliseconds).
  CGpSharedPoolMessageQueueReadTimeout = 250;

  //:Shared memory header signature.
  CGpSharedMemorySignature: int64 = $7E2D81FEF4E0BC22; { random-generated }

  //:Shared pool header signature.
  CGpSharedPoolSignature: int64 = $45269477E4F5A3FE; { random-generated }

  //:Shared linked list signature.
  CGpSharedLinkedListSignature: int64 = int64($DC19EFBF46102CEA); { random-generated }

  //:Shared pool access watchdog timeout (in seconds).
  CSharedPoolWatchdogTimeoutSec = 15;

  //:Shared pool send buffer timeout (in seconds). Used only when application tries to send non-pool buffer.
  CSharedPoolForeignSendTimeoutSec = 5;

  //:Max time shared memory creation will wait on the intialization mutex (in seconds).
  CInitializationTimeout = 10;

  Card_INVALID_HANDLE_VALUE = cardinal(-1);

type
  {:Header of the shared memory block.
  }
  TGpSharedMemoryHeader = packed record
    gsmhGuard1       : int64;
    gsmhVersion      : cardinal; //Always 1. Used for possible future modifications of the header structure.
    gsmhSize         : cardinal; //Current (application) size of the shared memory.
    gsmhMaxSize      : cardinal; //Maximum (application) size of the shared memory.
    gsmhAllocated    : cardinal; //Size of the allocated memory.
    gsmhModifiedCount: int64;    //Counter showing how many times shared memory was modified.
    gsmhGuard2       : int64;
  end; { TGpSharedMemoryHeader }

  PGpSharedMemoryHeader = ^TGpSharedMemoryHeader;

resourcestring
  sCannotAcquireSnapshotForWrite        = 'Snapshot %s: Snapshot cannot be acquired for writing';
  sCannotResizePastMax                  = 'Shared memory %s: Requested size %d is greater than maximum size %d';
  sCannotUpgradeReadAccessToWriteAccess = 'Shared memory %s: Cannot upgrade read access to write access';
  sCleanupError                         = 'Shared memory %s: Error during cleanup';
  sCleanupTimeout                       = 'Shared memory %s: Timeout waiting on the cleanup mutex. %s';
  sDMADisabled                          = 'Shared memory %s: Direct memory access is disabled because stream access is active';
  sFailedToAccessSharedData             = 'Shared memory %s: Failed to access shared data';
  sIndexOutOfRange                      = 'Shared memory %s: Index out of range (%d-%d)';
  sInitializationTimeout                = 'Shared memory %s: Timeout waiting on the initialization mutex. %s';
  sInvalidHeaderVersion                 = 'Shared memory %s: Invalid version %d found in the shared memory header';
  sInvalidSharedMemorySize              = 'Shared memory %s: Invalid shared memory size %d';
  sInvalidStreamPosition                = 'Shared memory %s: Invalid stream position %d';
  sMemoryBlockCorrupted                 = 'Shared memory %s: Shared memory block is corrupted';
  sMissingReleaseMemory                 = 'Shared memory %s: Previous AcquireMemory was not followed with the ReleaseMemory';
  sNameRequired                         = 'Shared memory object requires a name';
  sNotAcquired                          = 'Shared memory %s: Not acquired';
  sNotAcquiredForWriting                = 'Shared memory %s: Not acquired for writing';
  sNotResizable                         = 'Shared memory %s: Not resizable';
  sSharedDataNameInUse                  = 'Shared memory %s: Shared data name is already in use';
  sSizeMustBeSmallerThanMaxSize         = 'Shared memory %s: Size (%d) must be smaller than MaxSize (%d)';
  sSMAlreadyExistsMaxSizeDiffers        = 'Shared memory %s: Already exists with a different maximum size (%d; tried to open with maximum size %d)';
  sSMAlreadyExistsSizeDiffers           = 'Shared memory %s: Already exists with a different size (%d; tried to open with size %d)';
  sSnapshotCannotBeModified             = 'Snapshot %s: Snapshot cannot be modified';
  sStringIsTooLong                      = 'Shared memory %s: String is too long to fit into shared memory block (size = %d)';
  sTryingToAcquireNoninitialized        = 'Shared memory %s: Trying to acquire non-initialized shared memory object';
  sWriteOverflow                        = 'Shared memory %s: Trying to write past the end of shared memory block';

{:Checks if more than 'timeout' time has elapsed since 'start'. Supports
  INFINITE.
}
function Elapsed(start: int64; timeout: DWORD): boolean;
var
  stop: int64;
begin
  if timeout = 0 then
    Result := true
  else if timeout = INFINITE then
    Result := false
  else begin
    stop := GetTickCount;
    {$IFNDEF Linux}
    if stop < start then
      stop := stop + $100000000;
    {$ENDIF}
    Result := ((stop-start) > timeout);
  end;
end; { Elapsed }

{:Offset pointer by specified ammount.
}        
function Ofs(p: pointer; offset: cardinal): pointer;
begin
  Result := pointer(cardinal(p)+offset);
end; { Ofs }

{:Round address to the next page boundary.
}        
function RoundToNextPage(addr: cardinal): cardinal;
begin
  if addr = 0 then
    Result := 0
  else
    Result := (((addr-1) div CPageSize)+1) * CPageSize;
end; { RoundToNextPage }

{ TGpSharedStream }

{:Copy data from resizable shared memory object to the internal memory stream
  (because write operation in progress would overflow shared memory).
}
procedure TGpSharedStream.CopyOnWrite;
var
  memSize: cardinal;
begin
  //Must get shared memory size before stream is created - because after that
  //TGpResizableSharedMemory returns stream size as its size.
  memSize := Memory.Size;
  ssCopyStream := TMemoryStream.Create;
  CopyStream.Write(Memory.DataPointer^, memSize);
  CopyStream.Position := MemoryPos;
end; { TGpSharedStream.CopyOnWrite }

{:Create shared memory stream object.
}
constructor TGpSharedStream.Create(memory: TGpBaseSharedMemory);
begin
  ssMemory := memory;
end; { TGpSharedStream.Create }

{:Destroy shared memory stream object. Destroy internal memory stream if it was
  created.
}
destructor TGpSharedStream.Destroy;
begin
  FreeAndNil(ssCopyStream);
  inherited;
end; { TGpSharedStream.Destroy }

{:Get pointer to the current offset of the shared memory data.
}
function TGpSharedStream.GetCurrentData: pointer;
begin
  Result := Ofs(Memory.DataPointer,MemoryPos);
end; { TGpSharedStream.GetCurrentData }

{:Getter for the UseStream property.
  @returns True if internal memory stream is used.
}
function TGpSharedStream.GetUseStream: boolean;
begin
  Result := assigned(CopyStream);
end; { TGpSharedStream.GetUseStream }

{:Read data from internal memory stream or from shared memory object.
}
function TGpSharedStream.Read(var buffer; count: integer): longint;
var
  remaining: integer;
begin
  if UseStream then
    Result := CopyStream.Read(buffer, count)
  else if MemoryPos < Memory.Size then begin
    remaining := Memory.Size-MemoryPos;
    if remaining > count then
      remaining := count;
    Move(CurrentData^, buffer, remaining);
    MemoryPos := MemoryPos + cardinal(remaining);
    Result := remaining;
  end
  else
    Result := 0;
end; { TGpSharedStream.Read }

{:Change position in the internal memory stream or in the shared memory object.
}
function TGpSharedStream.Seek(offset: integer; origin: word): longint;
begin
  if UseStream then
    Result := CopyStream.Seek(offset, origin)
  else begin
    case origin of
      soFromBeginning:
        SetMemoryPos(offset);
      soFromCurrent:
        SetMemoryPos(int64(MemoryPos) + int64(offset));
      soFromEnd:
        SetMemoryPos(int64(Memory.Size) - int64(offset));
    end; //case
    Result := MemoryPos;
  end;
end; { TGpSharedStream.Seek }

{:Set position in the shared memory object with range checking.
}
procedure TGpSharedStream.SetMemoryPos(newPos: int64);
begin
  if (newPos < 0) or (newPos > Memory.Size) then
    raise Exception.CreateFmt(sInvalidStreamPosition, [Memory.Name, newPos]);
  MemoryPos := cardinal(newPos);
end; { TGpSharedStream.SetMemoryPos }

{:Set size of the internal memory stream or of the shared memory object. Copy
  data to the internal memory stream first if it is still in the shared memory
  object. 
}
procedure TGpSharedStream.SetSize(newSize: integer);
begin
  if not Memory.IsWriting then
    raise EGpSharedMemory.CreateFmt(sNotAcquiredForWriting, [Memory.Name]);
  if not Memory.SupportsResize then
    raise EGpSharedMemory.CreateFmt(sNotResizable, [Memory.Name]);
  if UseStream then
    CopyStream.SetSize(newSize)
  else begin
    CopyOnWrite;
    SetSize(newSize);
  end;
end; { TGpSharedStream.SetSize }

{:Write data to the internal memory stream or to the shared memory object. When
  shared memory overflows and resizing is supported, copy data to the internal
  memory stream.
}
function TGpSharedStream.Write(const buffer; count: integer): longint;
var
  remaining: integer;
begin
  if not Memory.IsWriting then
    raise EGpSharedMemory.CreateFmt(sNotAcquiredForWriting, [Memory.Name]);
  ssModified := true;
  if UseStream then
    Result := CopyStream.Write(buffer, count)
  else begin
    remaining := int64(Memory.Size)-int64(MemoryPos){-1};
    if remaining > count then
      remaining := count;
    if (remaining < count) and Memory.SupportsResize then begin
      CopyOnWrite;
      Result := Write(buffer, count);
    end
    else begin
      Move(buffer, CurrentData^, remaining);
      SetMemoryPos(int64(MemoryPos) + int64(remaining));
      Result := remaining;
    end;
  end;
end; { TGpSharedStream.Write }

{ TGpSharedStreamList }

function TGpSharedStreamList.Add(gpSharedStream: TGpSharedStream): integer;
begin
  Result := inherited Add(gpSharedStream);
end; { TGpSharedStreamList.Add }                                     

function TGpSharedStreamList.AddNew(
  memory: TGpBaseSharedMemory): TGpSharedStream;
begin
  Result := TGpSharedStream.Create(memory);
  Add(Result);
end; { TGpSharedStreamList.AddNew }

function TGpSharedStreamList.Extract(
  gpSharedStream: TGpSharedStream): TGpSharedStream;
begin
  Result := TGpSharedStream(inherited Extract(gpSharedStream));
end; { TGpSharedStreamList.Extract }

function TGpSharedStreamList.GetItem(idx: integer): TGpSharedStream;
begin
  Result := (inherited GetItem(idx)) as TGpSharedStream;
end; { TGpSharedStreamList.GetItem }

function TGpSharedStreamList.IndexOf(gpSharedStream: TGpSharedStream): integer;
begin
  Result := inherited IndexOf(gpSharedStream);
end; { TGpSharedStreamList.IndexOf }

procedure TGpSharedStreamList.Insert(idx: integer;
  gpSharedStream: TGpSharedStream);
begin
  inherited Insert(idx, gpSharedStream);
end; { TGpSharedStreamList.Insert }

function TGpSharedStreamList.Remove(gpSharedStream: TGpSharedStream): integer;
begin
  Result := inherited Remove(gpSharedStream);
end; { TGpSharedStreamList.Remove }

procedure TGpSharedStreamList.SetItem(idx: integer;
  const Value: TGpSharedStream);
begin
  inherited SetItem(idx, Value);
end; { TGpSharedStreamList.SetItem }

{ TGpBaseSharedMemory }

{:Check if shared memory is acquired.
  @returns True if shared memory is acquired.
}
function TGpBaseSharedMemory.Acquired: boolean;
begin
  Result := assigned(DataPointer)
end; { TGpBaseSharedMemory.Acquired }

{:Check if data lies completely inside shared memory block.
  @param   offset Offset (0-based) of first data byte.
  @param   size   Size of data (in bytes).
  @raises  EGpSharedMemory if data doesn't lie inside shared memory block.
}
procedure TGpBaseSharedMemory.CheckBoundaries(offset, size: cardinal);
begin
  if (offset+size) > GetSize then begin
    if IsWriting and ((offset+size) <= GetUpperSize) then begin
      ResizeMemory(offset+size);
      Exit;
    end;
    raise EGpSharedMemory.CreateFmt(sIndexOutOfRange,
      [Name, offset, offset+size-1]);
  end;
end; { TGpBaseSharedMemory.CheckBoundaries }

{:Check if direct memory access is enabled.
  @raises EGpSharedMemory if DMA is not enabled (for example after AsStream).
}
procedure TGpBaseSharedMemory.CheckDMA;
begin
  if HaveStream then
    raise EGpSharedMemory.CreateFmt(sDMADisabled, [Name]);
end; { TGpBaseSharedMemory.CheckDMA }

{:Free stream interface to the shared memory.
}
procedure TGpBaseSharedMemory.FreeStream;
begin
  FreeAndNil(gbsmStream);
end; { TGpBaseSharedMemory.FreeStream }

function TGpBaseSharedMemory.GetAddress(byteOffset: integer): pointer;
begin
  CheckDMA;
  if not Acquired then
    raise EGpSharedMemory.CreateFmt(sNotAcquired, [Name]);
  CheckBoundaries(byteOffset, 1);
  Result := Ofs(DataPointer, byteOffset);
end; { TGpBaseSharedMemory.GetAddress }

{:Get stream interface to the shared memory.
}
function TGpBaseSharedMemory.GetAsStream: TGpSharedStream;
begin
  if not Acquired then
    raise EGpSharedMemory.CreateFmt(sNotAcquired, [Name]);
  if not HaveStream then
    gbsmStream := TGpSharedStream.Create(Self);
  Result := gbsmStream;
end; { TGpBaseSharedMemory.GetAsStream }

{:Return contents of the shared memory as a string. Take special care to copy
  max Size characters (if memory somehow got corrupt and there is no #0 at the
  end of the memory block).
  @raises  EGpSharedMemory if memory is not acquired.
  @since   2002-05-08
}
function TGpBaseSharedMemory.GetAsString: string;
begin
  if not Acquired then
    raise EGpSharedMemory.CreateFmt(sNotAcquired, [Name]);
  SetLength(Result, Size div SizeOf(char) + 1);
  StrLCopy(PChar(@Result[1]), DataPointer, Size div SizeOf(char));
  Result[Size div SizeOf(char) + 1] := #0;
  SetLength(Result, StrLen(PChar(Result)));
end; { TGpBaseSharedMemory.GetAsString }

function TGpBaseSharedMemory.GetByte(byteOffset: integer): byte;
begin
  CheckDMA;
  GetData(byteOffset, SizeOf(Result), Result);
end; { TGpBaseSharedMemory.GetByte }

function TGpBaseSharedMemory.GetByteIdx(idx: integer): byte;
begin
  CheckDMA;
  GetData(idx*SizeOf(Result), SizeOf(Result), Result);
end; { TGpBaseSharedMemory.GetByteIdx }

{:Getter for the WasCreated property.
}
function TGpBaseSharedMemory.GetCreated: boolean;
begin
  Result := gbsmWasCreated;
end; { TGpBaseSharedMemory.GetCreated }

function TGpBaseSharedMemory.GetHuge(byteOffset: integer): int64;
begin
  CheckDMA;
  GetData(byteOffset, SizeOf(Result), Result);
end; { TGpBaseSharedMemory.GetHuge }

function TGpBaseSharedMemory.GetHugeIdx(idx: integer): int64;
begin
  CheckDMA;
  GetData(idx*SizeOf(Result), SizeOf(Result), Result);
end; { TGpBaseSharedMemory.GetHugeIdx }

function TGpBaseSharedMemory.GetInt(byteOffset: integer): integer;
begin
  CheckDMA;
  GetData(byteOffset, SizeOf(Result), Result);
end; { TGpBaseSharedMemory.GetInt }

function TGpBaseSharedMemory.GetIntIdx(idx: integer): integer;
begin
  CheckDMA;
  GetData(idx*SizeOf(Result), SizeOf(Result), Result);
end; { TGpBaseSharedMemory.GetIntIdx }

{:Getter for the IsWriting property.
}
function TGpBaseSharedMemory.GetIsWriting: boolean;
begin
  Result := gbsmIsWriting;
end; { TGpBaseSharedMemory.GetIsWriting }

function TGpBaseSharedMemory.GetLong(byteOffset: integer): longword;
begin
  CheckDMA;
  GetData(byteOffset, SizeOf(Result), Result);
end; { TGpBaseSharedMemory.GetLong }

function TGpBaseSharedMemory.GetLongIdx(idx: integer): longword;
begin
  CheckDMA;
  GetData(idx*SizeOf(Result), SizeOf(Result), Result);
end; { TGpBaseSharedMemory.GetLongIdx }

function TGpBaseSharedMemory.GetName: string;
begin
  Result := gbsmObjectName;
end; { TGpBaseSharedMemory.GetName }

function TGpBaseSharedMemory.GetSize: cardinal;
begin
  if IsWriting and HaveStream and AsStream.UseStream then
    Result := AsStream.Size
  else
    Result := gbsmSize;
end; { TGpBaseSharedMemory.GetSize }

function TGpBaseSharedMemory.GetUpperSize: cardinal;
begin
  if IsResizable then
    Result := gbsmMaxSize
  else
    Result := Size;
end; { TGpBaseSharedMemory.GetUpperSize }

function TGpBaseSharedMemory.GetWord(byteOffset: integer): word;
begin
  CheckDMA;
  GetData(byteOffset, SizeOf(Result), Result);
end; { TGpBaseSharedMemory.GetWord }

function TGpBaseSharedMemory.GetWordIdx(idx: integer): word;
begin
  CheckDMA;
  GetData(idx*SizeOf(Result), SizeOf(Result), Result);
end; { TGpBaseSharedMemory.GetWordIdx }

{:Check if stream interface is assigned.
}
function TGpBaseSharedMemory.HaveStream: boolean;
begin
  Result := assigned(gbsmStream);
end; { TGpBaseSharedMemory.HaveStream }

{:Free stream interface when memory is released.
}
procedure TGpBaseSharedMemory.ReleaseMemory;
begin
  FreeStream;
end; { TGpBaseSharedMemory.ReleaseMemory }

procedure TGpBaseSharedMemory.ResizeMemory(const newSize: cardinal);
begin
  raise EGpSharedMemory.CreateFmt(sNotResizable, [Name]);
end; { TGpBaseSharedMemory.ResizeMemory }

{:Assign contents of the string to the shared memory.
  @raises  EGpSharedMemory if memory is not acquired for writing.
  @since   2002-05-08
}        
procedure TGpBaseSharedMemory.SetAsString(const Value: string);
begin
  if not Acquired then
    raise EGpSharedMemory.CreateFmt(sNotAcquired, [Name]);
  if not IsWriting then
    raise EGpSharedMemory.CreateFmt(sNotAcquiredForWriting, [Name]);
  if cardinal(Length(Value)) >= GetUpperSize then
    raise EGpSharedMemory.CreateFmt(sStringIsTooLong, [Name, GetUpperSize]);
  if IsResizable then 
    ResizeMemory((Length(Value)+1)*SizeOf(char));
  StrPCopy(DataPointer, Value);
end; { TGpBaseSharedMemory.SetAsString }

procedure TGpBaseSharedMemory.SetByte(byteOffset: integer; Value: byte);
begin
  CheckDMA;
  SetData(byteOffset, SizeOf(Value), Value);
end; { TGpBaseSharedMemory.SetByte }

procedure TGpBaseSharedMemory.SetByteIdx(idx: integer; Value: byte);
begin
  CheckDMA;
  SetData(idx*SizeOf(Value), SizeOf(Value), Value);
end; { TGpBaseSharedMemory.SetByteIdx }

{:Setter for the WasCreated property.
}
procedure TGpBaseSharedMemory.SetCreated(const newCreated: boolean);
begin
  gbsmWasCreated := newCreated;
end; { TGpBaseSharedMemory.SetCreated }

{:Setter for the DataPointer property. Setting data pointer enables DMA access.
}
procedure TGpBaseSharedMemory.SetDataPointer(const Value: pointer);
begin
  gbsmDataPointer := Value;
end; { TGpBaseSharedMemory.SetDataPointer }

procedure TGpBaseSharedMemory.SetHuge(byteOffset: integer; Value: int64);
begin
  CheckDMA;
  SetData(byteOffset, SizeOf(Value), Value);
end; { TGpBaseSharedMemory.SetHuge }

procedure TGpBaseSharedMemory.SetHugeIdx(idx: integer; Value: int64);
begin
  CheckDMA;
  SetData(idx*SizeOf(Value), SizeOf(Value), Value);
end; { TGpBaseSharedMemory.SetHugeIdx }

procedure TGpBaseSharedMemory.SetInt(byteOffset, Value: integer);
begin
  CheckDMA;
  SetData(byteOffset, SizeOf(Value), Value);
end; { TGpBaseSharedMemory.SetInt }

procedure TGpBaseSharedMemory.SetIntIdx(idx, Value: integer);
begin
  CheckDMA;
  SetData(idx*SizeOf(Value), SizeOf(Value), Value);
end; { TGpBaseSharedMemory.SetIntIdx }

{:Set IsWriting property.
}
procedure TGpBaseSharedMemory.SetIsWriting(const newIsWriting: boolean);
begin
  gbsmIsWriting := newIsWriting;
end; { TGpBaseSharedMemory.SetIsWriting }

procedure TGpBaseSharedMemory.SetLong(byteOffset: integer; Value: longword);
begin
  CheckDMA;
  SetData(byteOffset, SizeOf(Value), Value);
end; { TGpBaseSharedMemory.SetLong }

procedure TGpBaseSharedMemory.SetLongIdx(idx: integer; Value: longword);
begin
  CheckDMA;
  SetData(idx*SizeOf(Value), SizeOf(Value), Value);
end; { TGpBaseSharedMemory.SetLongIdx }

procedure TGpBaseSharedMemory.SetMaxSize(const newMaxSize: cardinal);
begin
  gbsmMaxSize := newMaxSize;
end; { TGpBaseSharedMemory.SetMaxSize }

procedure TGpBaseSharedMemory.SetName(const newName: string);
begin
  gbsmObjectName := newName;
end; { TGpBaseSharedMemory.SetName }

procedure TGpBaseSharedMemory.SetSize(const newSize: cardinal);
begin
  gbsmSize := newSize;
end; { TGpBaseSharedMemory.SetSize }

procedure TGpBaseSharedMemory.SetWord(byteOffset: integer; Value: word);
begin
  CheckDMA;
  SetData(byteOffset, SizeOf(Value), Value);
end; { TGpBaseSharedMemory.SetWord }

procedure TGpBaseSharedMemory.SetWordIdx(idx: integer; Value: word);
begin
  CheckDMA;
  SetData(idx*SizeOf(Value), SizeOf(Value), Value);
end; { TGpBaseSharedMemory.SetWordIdx }

{:Returns True if shared memory object supports resizing.
  @returns False
}
function TGpBaseSharedMemory.SupportsResize: boolean;
begin
  Result := (MaxSize > 0);
end; { TGpBaseSharedMemory.SupportsResize }

{ TGpBaseSharedMemoryList }

function TGpBaseSharedMemoryList.Add(
  gpBaseSharedMemory: TGpBaseSharedMemory): integer;
begin
  Result := inherited Add(gpBaseSharedMemory);
end; { TGpBaseSharedMemoryList.Add }

function TGpBaseSharedMemoryList.Extract(
  gpBaseSharedMemory: TGpBaseSharedMemory): TGpBaseSharedMemory;
begin
  Result := TGpBaseSharedMemory(inherited Extract(gpBaseSharedMemory));
end; { TGpBaseSharedMemoryList.Extract }

function TGpBaseSharedMemoryList.GetItem(
  idx: integer): TGpBaseSharedMemory;
begin
  Result := (inherited GetItem(idx)) as TGpBaseSharedMemory;
end; { TGpBaseSharedMemoryList.GetItem }

function TGpBaseSharedMemoryList.IndexOf(
  gpBaseSharedMemory: TGpBaseSharedMemory): integer;
begin
  Result := inherited IndexOf(gpBaseSharedMemory);
end; { TGpBaseSharedMemoryList.IndexOf }

procedure TGpBaseSharedMemoryList.Insert(idx: integer;
  gpBaseSharedMemory: TGpBaseSharedMemory);
begin
  inherited Insert(idx, gpBaseSharedMemory);
end; { TGpBaseSharedMemoryList.Insert }

function TGpBaseSharedMemoryList.Remove(
  gpBaseSharedMemory: TGpBaseSharedMemory): integer;
begin
  Result := inherited Remove(gpBaseSharedMemory);
end; { TGpBaseSharedMemoryList.Remove }

procedure TGpBaseSharedMemoryList.SetItem(idx: integer;
  const Value: TGpBaseSharedMemory);
begin
  inherited SetItem(idx, Value);
end; { TGpBaseSharedMemoryList.SetItem }

{ TGpSharedSnapshot }

{:Check if snapshot memory is acquired.
  @returns Always True.
  @seeAlso GetIsWriting
}
function TGpSharedSnapshot.Acquired: boolean;
begin
  Result := true;
end; { TGpSharedSnapshot.Acquired }

{:Acquire snapshot. Basically just checks if read access is acquired and returns
  pointer to the memory.
  @param   forWriting If True, exception will be raised (snapshot doesn't allow
                      write access). If False, read access will be acquired.
  @param   timeout    Max time (in milliseconds) process will try to acquire the
                      shared memory. Ignored - snapshot can always be acquired.
  @returns Pointer to the shared memory.
  @raises  EGpSharedMemory if write access was acquired.
  @seealso ReleaseMemory
}
function TGpSharedSnapshot.AcquireMemory(forWriting: boolean;
  timeout: DWORD): pointer;
begin
  if forWriting then
    raise EGpSharedMemory.CreateFmt(sCannotAcquireSnapshotForWrite, [Name]);
  Result := DataPointer;
end; { TGpSharedSnapshot.AcquireMemory }

{:Create snapshot object.
  @param   sharedMemoryName Name of shared memory snapshot was created from.
  @param   memoryStart      Pointer to the (read-acquired) shared memory.
  @param   size             Size of the shared memory.
}
constructor TGpSharedSnapshot.Create(sharedMemoryName: string;
  memoryStart: pointer; size: cardinal);
var
  p: pointer;
begin
  SetName('+'+sharedMemoryName);
  SetSize(size);
  SetMaxSize(0); // snapshots are not resizable
  GetMem(p, size);
  SetDataPointer(p);
  Move(memoryStart^, DataPointer^, size);
end; { TGpSharedSnapshot.Create }

{:Destroy snapshot object.
}
destructor TGpSharedSnapshot.Destroy;
begin
  FreeMem(DataPointer);
  FreeStream; // just in case - maybe ReleaseMemory wasn't called
  inherited;
end; { TGpSharedSnapshot.Destroy }

{:Get data from the specified byte offset (0-based). Check if required data lies
  completely inside shared memory block.
  @param   offset Offset (0-based) of first data byte.
  @param   size   Size of data (in bytes).
  @param   buffer (out) Copy of shared memory data.
  @raises  EGpSharedMemory if data doesn't lie inside shared memory block.
}
procedure TGpSharedSnapshot.GetData(offset, size: cardinal; out buffer);
begin
  CheckBoundaries(offset, size);
  Move(Ofs(DataPointer,offset)^, buffer, size);
end; { TGpSharedSnapshot.GetData }

{:Check if snapshot memory is acquired for writing.
  @returns False (snapshot cannot be acquired for writing).
  @seeAlso Acquired
}
function TGpSharedSnapshot.GetIsWriting: boolean;
begin
  Result := false;
end; { TGpSharedSnapshot.GetIsWriting }

{:Create copy of the snapshot.
  @returns Snapshot object. Caller is responsible for freeing it.
}
function TGpSharedSnapshot.MakeSnapshot: TGpSharedSnapshot;
begin
  Result := TGpSharedSnapshot.Create(Copy(Name, 2, Length(Name)-1), DataPointer, Size);
end; { TGpSharedSnapshot.MakeSnapshot }

{:Raise exception - snapshot cannot be modified.
  @raises  EGpSharedMemory
}
procedure TGpSharedSnapshot.SetData(offset, size: cardinal; var buffer);
begin
  raise EGpSharedMemory.CreateFmt(sSnapshotCannotBeModified, [Name]);
end; { TGpSharedSnapshot.SetData }

{ TGpSharedSnapshotList }

function TGpSharedSnapshotList.Add(
  gpSharedSnapshot: TGpSharedSnapshot): integer;
begin
  Result := inherited Add(gpSharedSnapshot);
end; { TGpSharedSnapshotList.Add }

function TGpSharedSnapshotList.AddNew(sharedMemoryName: string;
  memoryStart: pointer; size: cardinal): TGpSharedSnapshot;
begin
  Result := TGpSharedSnapshot.Create(sharedMemoryName, memoryStart, size);
  Add(Result);
end; { TGpSharedSnapshotList.AddNew }

function TGpSharedSnapshotList.Extract(
  gpSharedSnapshot: TGpSharedSnapshot): TGpSharedSnapshot;
begin
  Result := TGpSharedSnapshot(inherited Extract(gpSharedSnapshot));
end; { TGpSharedSnapshotList.Extract }

function TGpSharedSnapshotList.GetItem(idx: integer): TGpSharedSnapshot;
begin
  Result := (inherited GetItem(idx)) as TGpSharedSnapshot;
end; { TGpSharedSnapshotList.GetItem }

function TGpSharedSnapshotList.IndexOf(
  gpSharedSnapshot: TGpSharedSnapshot): integer;
begin
  Result := inherited IndexOf(gpSharedSnapshot);
end; { TGpSharedSnapshotList.IndexOf }

procedure TGpSharedSnapshotList.Insert(idx: integer;
  gpSharedSnapshot: TGpSharedSnapshot);
begin
  inherited Insert(idx, gpSharedSnapshot);
end; { TGpSharedSnapshotList.Insert }

function TGpSharedSnapshotList.Remove(
  gpSharedSnapshot: TGpSharedSnapshot): integer;
begin
  Result := inherited Remove(gpSharedSnapshot);
end; { TGpSharedSnapshotList.Remove }

procedure TGpSharedSnapshotList.SetItem(idx: integer;
  const Value: TGpSharedSnapshot);
begin
  inherited SetItem(idx, Value);
end; { TGpSharedSnapshotList.SetItem }

{ TGpSharedMemory }

{:Acquire shared memory. If acquired for writing, process is exclusive owner of the shared
  memory when function returns and can write to it. If acquired for reading, other readers
  may exist at the same time and process must only read from the shared memory. In any
  case, shared memory should be released as soon as possible with the call to the
  ReleaseMemory.
  @param   forWriting If True, write access will be acquired. If False, read access will
                      be acquired.
  @param   timeout    Max time (in milliseconds) process will try to acquire the shared
                      memory. INFINITE is supported.
  @returns Pointer to the shared memory or Nil if shared memory could not be acquired
           (timeout period was exceeded).
  @raises  EGpSharedMemory if shared memory was not initialized (OpenMemory was not called
           yet).
  @raises  EWin32Error if shared memory cannot be mapped (MapViewOfFile failed).
  @seealso OpenMemory, ReleaseMemory
}
function TGpSharedMemory.AcquireMemory(forWriting: boolean; timeout: DWORD): pointer;
var
  gotAccess: boolean;
begin 
  if gsmOwningThread = 0 then
    gsmOwningThread := GetCurrentThreadID
  else if gsmOwningThread <> GetCurrentThreadID then
    raise Exception.CreateFmt(
      'TGpSharedMemory<%s>.AcquireMemory called from two threads: %d and %d',
      [Name, gsmOwningThread, GetCurrentThreadID]);
  if gsmFileMapping = 0 then
    raise EGpSharedMemory.CreateFmt(sTryingToAcquireNoninitialized, [Name])
  else begin
    if not assigned(gsmSynchronizer) then
      gotAccess := true
    else if not forWriting then
      gotAccess := gsmSynchronizer.WaitToRead(timeout)
    else if gsmSynchronizer.Access <> swmrAccRead then
      gotAccess := gsmSynchronizer.WaitToWrite(timeout)
    else
      raise EGpSharedMemory.CreateFmt(sCannotUpgradeReadAccessToWriteAccess, [Name]);
    if not gotAccess then
      Result := nil
    else begin
      if gsmTimesMember = 0 then begin
        SetIsWriting(forWriting);
        if forWriting then
          gsmDesiredAccess := FILE_MAP_WRITE
        else
          gsmDesiredAccess := FILE_MAP_READ;
        grmFileView := MapView(gsmFileMapping, gsmDesiredAccess);
      end;
      Result := DataPointer;
      if assigned(Result) then
        Inc(gsmTimesMember)
      else begin
        gsmSynchronizer.Done;
        RaiseLastWin32Error;
      end;
    end;
  end;
end; { TGpSharedMemory.AcquireMemory }

{:Store initialization parameters, create the synchronizer object, open the shared memory.
  @param   objectName         Named of the shared memory. Required.
  @param   size               Shared memory size. Must be > 0.
  @param   maxSize            Maximum shared memory size. If 0, shared memory will not be
                              resizable.
  @param   resourceProtection If True (default) internal single-writer-multiple-readers
                              object is used to protect shared memory. If False, external
                              code must ensure that access to the shared memory is
                              protected. Creation and initialization is *always* protected
                              with the internal mutex.
  @raises  EGpSharedMemory if shared memory size is <= 0 (and 'silentFail' parameter is False).
  @raises  EWin32Error if initialization mutex cannot be created.
}
constructor TGpSharedMemory.Create(objectName: string; size, maxSize: cardinal;
  resourceProtection, silentFail: boolean);
begin
  inherited Create;
  if objectName = '' then
    raise EGpSharedMemory.Create(sNameRequired);
  SetName(objectName);
  inherited SetSize(size);
  if (size = 0) and (maxSize = 0) then
    raise EGpSharedMemory.CreateFmt(sInvalidSharedMemorySize, [Name, Size]);
  SetMaxSize(maxSize);
  if (maxSize > 0) and (size > maxSize) then
    raise EGpSharedMemory.CreateFmt(sSizeMustBeSmallerThanMaxSize, [Name, size, maxSize]);
  if resourceProtection then
    gsmSynchronizer := TGpSWMR.Create(Name+'$SWMR');
  gsmInitializer := CreateMutex_AllowEveryone(false, PChar(Name+'$MTX'));
  if gsmInitializer = 0 then
    RaiseLastWin32Error;
  SetCreated(OpenMemory(silentFail));
end; { TGpSharedMemory.Create }

{:Close mapping (if open) and destroy the synchronizer object.
}
destructor TGpSharedMemory.Destroy;
begin
  if Acquired then
    ReleaseMemory;
  if gsmFileMapping <> 0 then begin
    CloseHandle(gsmFileMapping);
    gsmFileMapping := 0;
  end;
  if gsmInitializer <> 0 then begin
    CloseHandle(gsmInitializer);
    gsmInitializer := 0;
  end;
  FreeAndNil(gsmSynchronizer);
  inherited;
end; { TGpSharedMemory.Destroy }

procedure TGpSharedMemory.AttachToThread;
begin
  gsmOwningThread := GetCurrentThreadID;
  gsmSynchronizer.AttachToThread;
end; { TGpSharedMemory.AttachToThread }

{:Get data from the specified byte offset (0-based). Check if memory is acquired
  and if required data lies completely inside shared memory block.
  @param   offset Offset (0-based) of first data byte.
  @param   size   Size of data (in bytes).
  @param   buffer (out) Copy of shared memory data.
  @raises  EGpSharedMemory if memory is not acquired or if data doesn't lie
           inside shared memory block.
}
procedure TGpSharedMemory.GetData(offset, size: cardinal; out buffer);
begin
  if not Acquired then
    raise EGpSharedMemory.CreateFmt(sNotAcquired, [Name]);
  CheckBoundaries(offset, size);
  Move(Ofs(DataPointer,offset)^, buffer, size);
end; { TGpSharedMemory.GetHuge }

{:Get 'was modified' status.
  @raises  EGpSharedMemory if memory is not acquired.
  @since   2002-05-13
}
function TGpSharedMemory.GetModified: boolean;
begin
  if not Acquired then
    raise EGpSharedMemory.CreateFmt(sNotAcquired, [Name]);
  Result := (gsmModifiedCount <> PGpSharedMemoryHeader(grmFileView)^.gsmhModifiedCount);
end; { TGpSharedMemory.GetModified }

{:Create read-only snapshot of the shared memory. Memory must be acquired.
  @returns Snapshot object. Caller is responsible for freeing it.
  @raises  EGpSharedMemory if memory is not acquired.
}
function TGpSharedMemory.MakeSnapshot: TGpSharedSnapshot;
begin
  if not Acquired then
    raise EGpSharedMemory.CreateFmt(sNotAcquired, [Name]);
  Result := TGpSharedSnapshot.Create(Name, DataPointer, Size);
end; { TGpSharedMemory.MakeSnapshot }

{:Map view of file (optionally including header area), check header integrity
  (if not initializing), alloc or free memory as needed, then return pointer to
  the data.
  @param   mappingObject File mapping object.
  @param   desiredAccess Desired access to the data.
  @param   mappingSize   Size to be mapped (not including header size). Ignored
                         if getFromHeader is True.
  @param   getFromHeader If True, retrieve Size from header (and run
                         consistency checks).
  @param   initialize    If True, initialize header. Initialize and
                         getFromHeader are mutually exclusive.
  @returns Pointer to the mapped data.
  @raises  EGpSharedMemory if memory header signature is not valid.
  @raises  EWin32Error if Win32 API functions fail.
  @since   2002-05-07
}
function TGpSharedMemory.MapView(mappingObject: THandle; desiredAccess: DWORD;
  mappingSize: DWORD; getFromHeader: boolean; initialize: boolean): pointer;
var
  allocSize: DWORD;
  header   : PGpSharedMemoryHeader;
  totalSize: cardinal;
begin
  if initialize and getFromHeader then
    raise Exception.Create('GpSharedMemory: Internal error. Initialize and getFromHeader are both True in MapView.'); //DNT
  totalSize := mappingSize + SizeOf(TGpSharedMemoryHeader);
  Result := MapViewOfFile(mappingObject, desiredAccess, 0, 0, totalSize);
  if not assigned(Result) then
    RaiseLastWin32Error;
  header := PGpSharedMemoryHeader(Result);
  if initialize then begin
    if not IsResizable then
      allocSize := 0
    else begin
      allocSize := totalSize;
      if VirtualAlloc(header, allocSize, MEM_COMMIT, PAGE_READWRITE) = nil then
        RaiseLastWin32Error;
    end;
    header^.gsmhGuard1    := CGpSharedMemorySignature;
    header^.gsmhVersion   := 1;
    header^.gsmhSize      := mappingSize;
    header^.gsmhMaxSize   := MaxSize;
    header^.gsmhAllocated := RoundToNextPage(allocSize);
    header^.gsmhGuard2    := CGpSharedMemorySignature;
  end
  else begin
    if (header^.gsmhGuard1 <> CGpSharedMemorySignature) or
       (header^.gsmhGuard2 <> CGpSharedMemorySignature) then
      raise EGpSharedMemory.CreateFmt(sMemoryBlockCorrupted, [Name])
    else if header^.gsmhVersion <> 1 then
      raise EGpSharedMemory.CreateFmt(sInvalidHeaderVersion, [Name, header^.gsmhVersion]);
    if not getFromHeader then
      header^.gsmhSize := mappingSize
    else begin
      if header^.gsmhMaxSize <> MaxSize then
        raise EGpSharedMemory.CreateFmt(sSMAlreadyExistsMaxSizeDiffers, [Name, header^.gsmhMaxSize, MaxSize])
      else if (MaxSize = 0) and (header^.gsmhSize <> Size) then
        raise EGpSharedMemory.CreateFmt(sSMAlreadyExistsSizeDiffers, [Name, header^.gsmhSize, Size]);
      inherited SetSize(header^.gsmhSize);
      inherited SetMaxSize(header^.gsmhMaxSize);
      if mappingSize <> Size then begin
        UnmapView(Result);
        mappingSize := Size;
        totalSize := mappingSize + SizeOf(TGpSharedMemoryHeader);
        Result := MapViewOfFile(mappingObject, desiredAccess, 0, 0, totalSize);
        if not assigned(Result) then
          RaiseLastWin32Error;
        header := PGpSharedMemoryHeader(Result);
      end;
    end;
  end;
  if IsResizable then begin
    if totalSize > header^.gsmhAllocated then begin
      if VirtualAlloc(Ofs(header, header^.gsmhAllocated),
           totalSize - header^.gsmhAllocated,
           MEM_COMMIT, PAGE_READWRITE) = nil then
        RaiseLastWin32Error;
      header^.gsmhAllocated := RoundToNextPage(totalSize);
    end;
  end;
  SetDataPointer(Ofs(Result, SizeOf(TGpSharedMemoryHeader)));
end; { TGpSharedMemory.MapView }

{:Create file mapping with the specified name and size. If mapping already
  exists, check if it was created with the same size. If mapping was created,
  initializes its content to 0.
  @returns True if shared memory was created, false if existing shared memory
           was open.
  @raises  EGpSharedMemory if shared memory was already created and requested
           size differs from the original size (and 'silentFail' is False).
  @raises  EWin32Error if file mapping cannot be created.
}
function TGpSharedMemory.OpenMemory(silentFail: boolean): boolean;
var
  fPtr           : pointer;
  protectionFlags: DWORD;
begin
  Result := false; // to keep Delphi happy
  gsmLastError := 0;
  if WaitForSingleObject(gsmInitializer, CInitializationTimeout*1000) <> WAIT_OBJECT_0 then
    raise EGpSharedMemory.CreateFmt(sInitializationTimeout, [Name, SysErrorMessage(GetLastError)])
  else begin
    try
      protectionFlags := PAGE_READWRITE;
      if IsResizable then
        protectionFlags := protectionFlags OR SEC_RESERVE;
      gsmFileMapping := CreateFileMapping_AllowEveryone(INVALID_HANDLE_VALUE,
        protectionFlags, 0, SizeOf(TGpSharedMemoryHeader)+GetUpperSize, PChar(Name));
      if gsmFileMapping = 0 then begin
        if silentFail then
          gsmLastError := GetLastError
        else
          RaiseLastWin32Error
      end
      else begin
        if GetLastError = NO_ERROR then begin
          // first owner, initialize to 0 and write header
          fPtr := MapView(gsmFileMapping, FILE_MAP_WRITE, Size, false, true);
          UnmapView(fPtr);
          Result := true;
        end
        else if GetLastError = ERROR_ALREADY_EXISTS then begin
          // not first owner, check size if not resizable
          fPtr := MapView(gsmFileMapping, FILE_MAP_READ);
          UnmapView(fPtr);
          Result := false;
        end
        else // not (GetLastError in [NO_ERROR,ERROR_ALREADY_EXISTS])
          if silentFail then
            gsmLastError := GetLastError
          else
            RaiseLastWin32Error;
      end; //else gsmFileMapping = 0
    finally ReleaseMutex(gsmInitializer); end;
  end; //else WaitForSingleObject()
end; { TGpSharedMemory.OpenMemory }

{:Releases memory previously acquired with a call to the AcquireMemory.
  @raises EWin32Error if memory cannot be unmapped.
}
procedure TGpSharedMemory.ReleaseMemory;
begin
  if not Acquired then
    raise EGpSharedMemory.CreateFmt(sNotAcquired, [Name])
  else begin
    try
      if gsmTimesMember = 1 then begin
        if IsWriting and HaveStream then begin
          ResizeMemory(CopyStream.Size);
          CopyStream.Position := 0;
          CopyStream.Read(DataPointer^,Size);
          FreeStream;
        end;
        if IsWriting then
          Inc(PGpSharedMemoryHeader(grmFileView)^.gsmhModifiedCount);
        gsmModifiedCount := PGpSharedMemoryHeader(grmFileView)^.gsmhModifiedCount;
        UnmapView(grmFileView);
      end;
      Dec(gsmTimesMember);
    finally
      if assigned(gsmSynchronizer) then
        gsmSynchronizer.Done;
    end;
  end;
  inherited;
end; { TGpSharedMemory.ReleaseMemory }

{:Resize shared memory block and set internal Size field.
  @param   newSize Size of the new memory block.
  @since   2002-05-08
}
procedure TGpSharedMemory.ResizeMemory(const newSize: cardinal);
begin
  if newSize = MemorySize then
    Exit;
  if not IsResizable then
    raise EGpSharedMemory.CreateFmt(sNotResizable, [Name])
  else if newSize > GetUpperSize then
    raise EGpSharedMemory.CreateFmt(sCannotResizePastMax, [Name, newSize, GetUpperSize]);
  UnmapView(grmFileView);
  grmFileView := MapView(gsmFileMapping, gsmDesiredAccess, newSize, false);
  inherited SetSize(newSize);
end; { TGpSharedMemory.ResizeMemory }

{:Set data at the specified byte offset (0-based). Check if memory is acquired
  for writing and if data will lie completely inside shared memory block.
  @param   offset Offset (0-based) of first data byte.
  @param   size   Size of data (in bytes).
  @param   buffer Data to be written to the shared memory.
  @raises  EGpSharedMemory if memory is not acquired for writing or if data
           wouldn't lie inside shared memory block.
}
procedure TGpSharedMemory.SetData(offset, size: cardinal; var buffer);
begin
  if not Acquired then
    raise EGpSharedMemory.CreateFmt(sNotAcquired, [Name]);
  if not IsWriting then
    raise EGpSharedMemory.CreateFmt(sNotAcquiredForWriting, [Name]);
  CheckBoundaries(offset, size);
  Move(buffer, Ofs(DataPointer,offset)^, size);
end; { TGpSharedMemory.SetData }

{:Resize shared memory. Check if memory is acquired for writing.
  @param   newSize New shared memory size.
  @raises  EGpSharedMemory if memory is not acquired for writing.
}
procedure TGpSharedMemory.SetSize(const newSize: cardinal);
begin
  if not IsWriting then
    raise EGpSharedMemory.CreateFmt(sNotAcquiredForWriting, [Name])
  else if not IsResizable then
    raise EGpSharedMemory.CreateFmt(sNotResizable, [Name])
  else if HaveStream then // Stream interface is active. Set new stream size and ReleaseMemory will take care of the resize.
    AsStream.Size := newSize
  else 
    ResizeMemory(newSize);
end; { TGpSharedMemory.SetSize }

{:Unmap view of file. Do nothing if parameter is nil.
  @param   baseAddress (in)  Address of the mapped view.
                       (out) Nil.
  @raises  EWin32Error if UnmapViewOfFile fails.
  @since   2002-05-07
}
procedure TGpSharedMemory.UnmapView(var baseAddress: pointer);
begin
  if assigned(baseAddress) then begin
    if not UnmapViewOfFile(baseAddress) then
      RaiseLastWin32Error;
    baseAddress := nil;
    SetDataPointer(nil);
  end;
end; { TGpSharedMemory.UnmapView }

{ TGpSharedMemoryList }

function TGpSharedMemoryList.Add(gpSharedMemory: TGpSharedMemory): integer;
begin
  Result := inherited Add(gpSharedMemory);
end;

function TGpSharedMemoryList.AddNew(objectName: string; size,
  maxSize: cardinal; resourceProtection: boolean): TGpSharedMemory;
begin
  Result := TGpSharedMemory.Create(objectName, size, maxSize, resourceProtection);
  Add(Result);
end; { TGpSharedMemoryList.AddNew }

function TGpSharedMemoryList.Extract(
  gpSharedMemory: TGpSharedMemory): TGpSharedMemory;
begin
  Result := TGpSharedMemory(inherited Extract(gpSharedMemory));
end; { TGpSharedMemoryList.Extract }

function TGpSharedMemoryList.GetItem(idx: integer): TGpSharedMemory;
begin
  Result := (inherited GetItem(idx)) as TGpSharedMemory;
end; { TGpSharedMemoryList.GetItem }

function TGpSharedMemoryList.IndexOf(
  gpSharedMemory: TGpSharedMemory): integer;
begin
  Result := inherited IndexOf(gpSharedMemory);
end; { TGpSharedMemoryList.IndexOf }

procedure TGpSharedMemoryList.Insert(idx: integer;
  gpSharedMemory: TGpSharedMemory);
begin
  inherited Insert(idx, gpSharedMemory);
end; { TGpSharedMemoryList.Insert }

function TGpSharedMemoryList.Remove(
  gpSharedMemory: TGpSharedMemory): integer;
begin
  Result := inherited Remove(gpSharedMemory);
end; { TGpSharedMemoryList.Remove }

procedure TGpSharedMemoryList.SetItem(idx: integer;
  const Value: TGpSharedMemory);
begin
  inherited SetItem(idx, Value);
end; { TGpSharedMemoryList.SetItem }
                          
{ TGpSharedMemoryCandy }

function TGpSharedMemoryCandy.GetAddress(baseAddress: integer): pointer;
begin
  Result := Memory.Address[baseAddress];
end; { TGpSharedMemoryCandy.GetAddress }

function TGpSharedMemoryCandy.GetBaseAddress(baseAddress,
  offset: integer): pointer;
begin
  Result := GetAddress(baseAddress + offset);
end; { TGpSharedMemoryCandy.GetBaseAddress }

function TGpSharedMemoryCandy.GetBaseByte(baseAddress,
  offset: integer): byte;
begin
  Result := GetByte(baseAddress + offset);
end; { TGpSharedMemoryCandy.GetBaseByte }

function TGpSharedMemoryCandy.GetBaseHuge(baseAddress,
  offset: integer): int64;
begin
  Result := GetHuge(baseAddress + offset);
end; { TGpSharedMemoryCandy.GetBaseHuge }

function TGpSharedMemoryCandy.GetBaseInt(baseAddress,
  offset: integer): integer;
begin
  Result := GetInt(baseAddress + offset);
end; { TGpSharedMemoryCandy.GetBaseInt }

function TGpSharedMemoryCandy.GetBaseLong(baseAddress,
  offset: integer): longword;
begin
  Result := GetLong(baseAddress + offset);
end; { TGpSharedMemoryCandy.GetBaseLong }

function TGpSharedMemoryCandy.GetBaseWord(baseAddress,
  offset: integer): word;
begin
  Result := GetWord(baseAddress + offset);
end; { TGpSharedMemoryCandy.GetBaseWord }

function TGpSharedMemoryCandy.GetByte(baseAddress: integer): byte;
begin
  Result := Memory.Byte[baseAddress];
end; { TGpSharedMemoryCandy.GetByte }

function TGpSharedMemoryCandy.GetHuge(baseAddress: integer): int64;
begin
  Result := Memory.Huge[baseAddress];
end; { TGpSharedMemoryCandy.GetHuge }

function TGpSharedMemoryCandy.GetInt(baseAddress: integer): integer;
begin
  Result := integer(GetLong(baseAddress));
end; { TGpSharedMemoryCandy.GetInt }

function TGpSharedMemoryCandy.GetLong(baseAddress: integer): longword;
begin
  Result := Memory.Long[baseAddress];
end; { TGpSharedMemoryCandy.GetLong }

function TGpSharedMemoryCandy.GetWord(baseAddress: integer): word;
begin
  Result := Memory.Word[baseAddress];
end; { TGpSharedMemoryCandy.GetWord }

procedure TGpSharedMemoryCandy.SetBaseByte(baseAddress, offset: integer;
  value: byte);
begin
  SetByte(baseAddress + offset, value);
end; { TGpSharedMemoryCandy.SetBaseByte }

procedure TGpSharedMemoryCandy.SetBaseHuge(baseAddress, offset: integer;
  value: int64);
begin
  SetHuge(baseAddress + offset, value);
end; { TGpSharedMemoryCandy.SetBaseHuge }

procedure TGpSharedMemoryCandy.SetBaseInt(baseAddress, offset,
  value: integer);
begin
  SetInt(baseAddress + offset, value);
end; { TGpSharedMemoryCandy.SetBaseInt }

procedure TGpSharedMemoryCandy.SetBaseLong(baseAddress, offset: integer;
  value: longword);
begin
  SetLong(baseAddress + offset, value);
end; { TGpSharedMemoryCandy.SetBaseLong }

procedure TGpSharedMemoryCandy.SetBaseWord(baseAddress, offset: integer;
  value: word);
begin
  SetWord(baseAddress + offset, value);
end; { TGpSharedMemoryCandy.SetBaseWord }

procedure TGpSharedMemoryCandy.SetByte(baseAddress: integer; value: byte);
begin
  Memory.Byte[baseAddress] := value;
end; { TGpSharedMemoryCandy.SetByte }

procedure TGpSharedMemoryCandy.SetHuge(baseAddress: integer; value: int64);
begin
  Memory.Huge[baseAddress] := value;
end; { TGpSharedMemoryCandy.SetHuge }

procedure TGpSharedMemoryCandy.SetInt(baseAddress, value: integer);
begin
  SetLong(baseAddress, longword(value));
end; { TGpSharedMemoryCandy.SetInt }

procedure TGpSharedMemoryCandy.SetLong(baseAddress: integer; value: longword);
begin
  Memory.Long[baseAddress] := value;
end; { TGpSharedMemoryCandy.SetLong }

procedure TGpSharedMemoryCandy.SetWord(baseAddress: integer; value: word);
begin
  Memory.Word[baseAddress] := value;
end; { TGpSharedMemoryCandy.SetWord }

{ TGpSharedLinkedList }

{:Initializes list header to empty list.
  @since   2003-09-25
}
procedure TGpSharedLinkedList.Clear;
begin
  NumberOfEntries[sllBaseAddress] := 0;
  NextInList[sllListHead] := sllListTail;
  PrevInList[sllListHead] := 0;
  NextInList[sllListTail] := 0;
  PrevInList[sllListTail] := sllListHead;
end; { TGpSharedLinkedList.Clear }

function TGpSharedLinkedList.Count: integer;
begin
  Result := NumberOfEntries[sllBaseAddress];
end; { TGpSharedLinkedList.Count }

{:Creates shared linked list object. If list is not initialised yet, uses
  16 bytes starting at 'baseAddress' to initialise list header (raising
  exception if memory is not acquired for writing).
  @since   2003-09-25
}
constructor TGpSharedLinkedList.Create(memory: TGpBaseSharedMemory;
  baseAddress: integer);
begin
  inherited Create;
  sllMemory := memory;
  sllBaseAddress := baseAddress;
  sllEntryHeaderSize := 8;
  sllHeaderSize := 8 + 4 + 4;
  sllListHead := baseAddress + sllHeaderSize; Inc(sllHeaderSize, sllEntryHeaderSize);
  sllListTail := baseAddress + sllHeaderSize; Inc(sllHeaderSize, sllEntryHeaderSize);
  if Signature[sllBaseAddress] = 0 then
    Initialize
  else if Signature[sllBaseAddress] <> CGpSharedLinkedListSignature then
    raise EGpSharedMemory.Create('TGpSharedLinkedList: invalid signature found in list header');
end; { TGpSharedLinkedList.Create }

{:Removes entry from the list.
  @since   2003-09-25
}
procedure TGpSharedLinkedList.Dequeue(entryAddress: integer);
begin
  NextInList[PrevInList[entryAddress]] := NextInList[entryAddress];
  PrevInList[NextInList[entryAddress]] := PrevInList[entryAddress];
  NextInList[entryAddress] := 0;
  PrevInList[entryAddress] := 0;
  NumberOfEntries[sllBaseAddress] := NumberOfEntries[sllBaseAddress] - 1;
end; { TGpSharedLinkedList.Dequeue }

{:Inserts entry after existing entry.
  @since   2003-09-25
}
procedure TGpSharedLinkedList.EnqueueAfter(existingEntry,
  entryAddress: integer);
var
  oldNext: integer;
begin
  oldNext := NextInList[existingEntry];
  NextInList[entryAddress] := oldNext;
  PrevInList[entryAddress] := existingEntry;
  NextInList[existingEntry] := entryAddress;
  PrevInList[oldNext] := entryAddress;
  NumberOfEntries[sllBaseAddress] := NumberOfEntries[sllBaseAddress] + 1;
end; { TGpSharedLinkedList.EnqueueAfter }

{:Insert entry before existing entry.
  @since   2003-09-25
}        
procedure TGpSharedLinkedList.EnqueueBefore(existingEntry,
  entryAddress: integer);
begin
  EnqueueAfter(PrevInList[existingEntry], entryAddress);
end; { TGpSharedLinkedList.EnqueueBefore }

{:Inserts entry at head.
  @since   2003-09-25
}
procedure TGpSharedLinkedList.EnqueueHead(entryAddress: integer);
begin
  EnqueueAfter(sllListHead, entryAddress);
end; { TGpSharedLinkedList.EnqueueHead }

{:Inserts entry at tail.
  @since   2003-09-25
}
procedure TGpSharedLinkedList.EnqueueTail(entryAddress: integer);
begin
  EnqueueBefore(sllListTail, entryAddress);
end; { TGpSharedLinkedList.EnqueueTail }

{:Returns base address of the first element in the list or 0 if list is empty.
  @since   2003-09-25
}        
function TGpSharedLinkedList.Head: integer;
begin
  if IsEmpty then
    Result := 0
  else
    Result := NextInList[sllListHead];
end; { TGpSharedLinkedList.Head }

{:Initializes list header. Raises exception if memory is not acquired for
  writing.
  @since   2003-09-25
}
procedure TGpSharedLinkedList.Initialize;
begin
  Signature[sllBaseAddress] := CGpSharedLinkedListSignature;
  Clear;
end; { TGpSharedLinkedList.Initialize }

{:Checks whether the list is empty.
  @since   2003-09-25
}        
function TGpSharedLinkedList.IsEmpty: boolean;
begin
  Result := NextInList[sllListHead] = sllListTail;
end; { TGpSharedLinkedList.IsEmpty }

{:Returns next entry in the list or 0 if this is the last entry.
  @since   2003-09-25
}        
function TGpSharedLinkedList.Memory: TGpBaseSharedMemory;
begin
  Result := sllMemory;
end; { TGpSharedLinkedList.Memory }

function TGpSharedLinkedList.Next(entryAddress: integer): integer;
begin
  Result := NextInList[entryAddress];
  if Result = sllListTail then
    Result := 0;
end; { TGpSharedLinkedList.Next }

{:Returns previous entry in the list or 0 if this is the last entry.
  @since   2003-09-25
}
function TGpSharedLinkedList.Prev(entryAddress: integer): integer;
begin
  Result := PrevInList[entryAddress];
  if Result = sllListHead then
    Result := 0;
end; { TGpSharedLinkedList.Prev }

{:Returns base address of the last element in the list or 0 if list is empty.
  @since   2003-09-25
}        
function TGpSharedLinkedList.Tail: integer;
begin
  if IsEmpty then
    Result := 0
  else
    Result := NextInList[sllListHead];
end; { TGpSharedLinkedList.Tail }

{ TGpSharedPoolIndex }

{:Acquire index.
  @since   2002-05-29
}        
function TGpSharedPoolIndex.Acquire(timeout: DWORD): boolean;
begin
  Result :=
    assigned(spiHeaderBlock.AcquireMemory(true, timeout)) and
    InitializeDirectory;
  if (not Result) and spiHeaderBlock.Acquired then
    spiHeaderBlock.ReleaseMemory;
end; { TGpSharedPoolIndex.Acquire }

{:Return BufferInitialSize header parameter.
  @since   2002-05-28
}
function TGpSharedPoolIndex.BufferInitialSize: cardinal;
begin
  Result := SafeGetHeader('BufferInitialSize')^.sphInitialBufferSize;
end; { TGpSharedPoolIndex.BufferInitialSize }

{:Return BufferMaxSize header parameter.
  @since   2002-05-28
}
function TGpSharedPoolIndex.BufferMaxSize: cardinal;
begin
  Result := SafeGetHeader('BufferMaxSize')^.sphMaxBufferSize;
end; { TGpSharedPoolIndex.BufferMaxSize }

{:Check whether index can be resized.
  @since   2002-05-28
}
function TGpSharedPoolIndex.CanResize: boolean;
begin
  Result := (NumEntries < MaxBuffers) or
            (SafeGetHeader('CanResize')^.sphDisposedList <> Card_INVALID_HANDLE_VALUE);
end; { TGpSharedPoolIndex.CanResize }

{:Create shared pool index object.
  @param   poolName Name of the shared memory pool associated with the index.
  @since   2002-05-28
}
constructor TGpSharedPoolIndex.Create(poolName: string; isReader: boolean);
begin
  inherited Create;
  spiPoolName   := poolName;
  spiIsReader   := isReader;
  spiHeaderBlock := TGpSharedMemory.Create(spiPoolName+'/Header',SizeOf(TGpSharedPoolHeader));
end; { TGpSharedPoolIndex.Create }

{:Destroy shared pool index object.
  @since   2002-05-28
}
destructor TGpSharedPoolIndex.Destroy;
var
  iEntry: cardinal;
begin 
  if (spiIsReader) and
     assigned(spiHeaderBlock) and assigned(spiDirectoryBlock) and
     Acquire(CSharedPoolWatchdogTimeoutSec*1000) then
  begin
    try
      for iEntry := 0 to NumEntries-1 do begin
        if Entry[iEntry].spieStatus <> Ord(iesDisposed) then begin
          TGpSharedMemory(Entry[iEntry].spieHandle).Free;
          Entry[iEntry].spieHandle := nil;
        end;
      end; //for
    finally Release; end;
  end;
  FreeAndNil(spiDirectoryBlock);
  FreeAndNil(spiHeaderBlock);
  inherited;
end; { TGpSharedPoolIndex.Destroy }

{:Mark shared buffer "free" and destroy shared memory object representing that
  buffer.
  @returns False if buffer was not allocated from the. Shared memory object is
           destroy nevertheless.
  @raises
  @since   2002-05-31
}
function TGpSharedPoolIndex.FreeBuffer(var buffer: TGpSharedMemory): boolean;
var
  header: PGpSharedPoolHeader;
  idx   : cardinal;
begin
  Result := false;
  header := SafeGetHeader('FreeBuffer');
  idx := GetEntryIndex(buffer.Name);
  if idx <> Card_INVALID_HANDLE_VALUE then begin
    if Entry[idx].spieStatus <> Ord(iesAllocated) then
      raise Exception.Create('GpSharedMemory/TGpSharedPoolIndex.FreeBuffer: trying to free buffer with status '+IntToStr(Entry[idx].spieStatus));
    Entry[idx].spieStatus := Ord(iesFree);
    Entry[idx].spieReleasedAt := Now;
    Link(idx,header^.sphFreeList);
    Inc(header^.sphFreeBuffers);
    Result := true;
  end;
  FreeAndNil(buffer);
end; { TGpSharedPoolIndex.FreeBuffer }

{:Return number of free buffers.
  @since   2002-05-28
}
function TGpSharedPoolIndex.FreeBuffers: cardinal;
begin
  Result := SafeGetHeader('FreeBuffers')^.sphFreeBuffers;
end; { TGpSharedPoolIndex.FreeBuffers }

{:Get pointer to the idx-th (0-based) index entry.
  @since   2002-05-30
}        
function TGpSharedPoolIndex.GetEntry(idx: cardinal): PGpSharedPoolIndexEntry;
var
  header: PGpSharedPoolHeader;
begin
  header := SafeGetHeader('GetEntry');
  if not assigned(spiDirectoryBlock.DataPointer) then
    raise Exception.Create('GpSharedMemory/TGpSharedPoolIndex.GetEntry: directory block does not exist');
  Result := PGpSharedPoolIndexEntry(
    cardinal(spiDirectoryBlock.DataPointer) + idx*header^.sphIndexEntrySize);
end; { TGpSharedPoolIndex.GetEntry }

{:Extract index number from the shared memory buffer name.
  @returns Index number (in range 0..NumBuffers-1) or INVALID_HANDLE_VALUE if
           name is not valid or if index number lies out of range.
  @since   2002-05-30
}
function TGpSharedPoolIndex.GetEntryIndex(name: string): cardinal;
var
  namePrefix: string;
begin
  Result := Card_INVALID_HANDLE_VALUE;
  namePrefix := GetEntryName(Card_INVALID_HANDLE_VALUE);
  if StrLIComp(PChar(name),PChar(namePrefix),Length(namePrefix)) = 0 then begin
    Delete(name,1,Length(namePrefix));
    Result := cardinal(StrToIntDef(name,integer(Card_INVALID_HANDLE_VALUE)));
  end;
end; { TGpSharedPoolIndex.GetEntryIndex }

{:Generate name for the idx-th shared memory buffer. If index is
  INVALID_HANDLE_VALUE, generates only the common prefix without the index.
  @since   2002-05-30
}
function TGpSharedPoolIndex.GetEntryName(idx: cardinal): string;
begin
  Result := SafeGetHeader('GetEntryName')^.sphOwnersToken+'/Pool/';
  if idx <> Card_INVALID_HANDLE_VALUE then
    Result := Result + IntToStr(idx);
end; { TGpSharedPoolIndex.GetEntryName }

{:Get free shared memory block in the acquired state.
  @since   2002-05-28
}
function TGpSharedPoolIndex.GetFreeBuffer: TGpSharedMemory;
var
  freeBuffer: cardinal;
  header    : PGpSharedPoolHeader;
begin
  if FreeBuffers = 0 then
    raise Exception.Create('GpSharedMemory/TGpSharedPoolIndex.GetFreeBuffer: no free buffers');
  header := SafeGetHeader('GetFreeBuffer');
  freeBuffer := header^.sphFreeList;
  Unlink(freeBuffer,header^.sphFreeList);
  Dec(header^.sphFreeBuffers);
  Entry[freeBuffer].spieStatus := Ord(iesAllocated);
  Result := TGpSharedMemory.Create(GetEntryName(freeBuffer),
    BufferInitialSize, BufferMaxSize, false);
  Result.AcquireMemory(true, 0);
end; { TGpSharedPoolIndex.GetFreeBuffer }

{:Set index parameters and initialize shared memory area.
  @errors  speIncompatibleHeader, speWin32Error
  @since   2002-06-05
}
function TGpSharedPoolIndex.Initialize(initialBufferSize,
  maxBufferSize, startNumBuffers, maxNumBuffers, resizeIncrement,
  resizeThreshold, minNumBuffers, sweepTimeoutSec: cardinal;
  ownersToken: string): TGpSharedPoolError;
var
  header: PGpSharedPoolHeader;
begin
  if not spiIsReader then
    raise Exception.Create('GpSharedMemory/TGpSharedPoolIndex.Initialize: writer tried to initialize shared memory pool');
  if minNumBuffers = CDefMinNumBuffers then
    minNumBuffers := startNumBuffers;
  if resizeIncrement = CDefResizeIncrement then
    resizeIncrement := startNumBuffers;
  if resizeThreshold = CDefResizeThreshold then
    resizeThreshold := Min(Min(Max(initialBufferSize div 10,CMinAutoThreshold),CMaxAutoThreshold),maxNumBuffers div 2);
  if Length(ownersToken) >= SizeOf(header^.sphOwnersToken) then
    raise Exception.Create('GpSharedMemory/TGpSharedPoolIndex.Initialize: ownersToken is too long');
  header := SafeGetHeader('Initialize',false);
  if (not spiHeaderBlock.WasCreated) and
     (header^.sphSignature = CGpSharedPoolSignature) and
     ( (header^.sphMaxBuffers <> maxNumBuffers) or
       (header^.sphIndexEntrySize <> SizeOf(TGpSharedPoolIndexEntry))) then
    Result := speIncompatibleHeader
  else begin
    header^.sphSignature        := CGpSharedPoolSignature;
    header^.sphVersion          := 1;
    header^.sphInitialBufferSize:= initialBufferSize;
    header^.sphMaxBufferSize    := maxBufferSize;
    header^.sphMinBuffers       := minNumBuffers;
    header^.sphMaxBuffers       := maxNumBuffers;
    header^.sphSweepTimeoutSec  := sweepTimeoutSec;
    header^.sphIndexEntrySize   := SizeOf(TGpSharedPoolIndexEntry);
    header^.sphNumBuffers       := 0;
    header^.sphFreeBuffers      := 0;
    header^.sphNumEntries       := 0;
    header^.sphFreeList         := Card_INVALID_HANDLE_VALUE;
    header^.sphQueuedList       := Card_INVALID_HANDLE_VALUE;
    header^.sphDisposedList     := Card_INVALID_HANDLE_VALUE;
    header^.sphResizeIncrement  := resizeIncrement;
    header^.sphResizeThreshold  := resizeThreshold;
    StrPCopy(header^.sphOwnersToken, ownersToken);
    if not InitializeDirectory then
      raise Exception.Create('GpSharedMemory/TGpSharedPoolIndex.Initialize: failed to initialize directory');
    Result := TryToResize(startNumBuffers);
  end;
end; { TGpSharedPoolIndex.Initialize }

{:Initialize shared pool directory.
  @since   2002-06-06
}
function TGpSharedPoolIndex.InitializeDirectory: boolean;
var
  header: PGpSharedPoolHeader;
begin
  header := SafeGetHeader('InitializeDirectory', false);
  if (not IsInitialized) then
    Result := spiIsReader
  else begin
    if not assigned(spiDirectoryBlock) then begin
      spiDirectoryBlock := TGpSharedMemory.Create(spiPoolName+'/Directory', 0,
        SizeOf(TGpSharedPoolHeader) + header^.sphMaxBuffers*header^.sphIndexEntrySize, false);
    end;
    if spiDirectoryBlock.Acquired then
      Result := true
    else
      Result := assigned(spiDirectoryBlock.AcquireMemory(true,0));
  end;
end; { TGpSharedPoolIndex.InitializeIndex }

{:Check whether the index block has been initialized.
  @since   2002-05-29
}
function TGpSharedPoolIndex.IsInitialized: boolean;
var
  header: PGpSharedPoolHeader;
begin
  header := SafeGetHeader('IsInitialized', false);
  Result :=
    (spiHeaderBlock.Size >= SizeOf(TGpSharedPoolHeader)) and
    (header^.sphSignature = CGpSharedPoolSignature);
end; { TGpSharedPoolIndex.IsInitialized }

{:Insert entry at front.
  @since   2002-05-30
}
procedure TGpSharedPoolIndex.Link(entryIdx: cardinal;
  var listHead: cardinal);
begin
  if entryIdx = Card_INVALID_HANDLE_VALUE then
    raise Exception.Create('GpSharedMemory/TGpSharedPoolIndex.Link: trying to link nil pointer');
  Entry[entryIdx].spieNext := listHead;
  Entry[entryIdx].spiePrevious := Card_INVALID_HANDLE_VALUE;
  if listHead <> Card_INVALID_HANDLE_VALUE then
    Entry[listHead].spiePrevious := entryIdx;
  listHead := entryIdx;
end; { TGpSharedPoolIndex.Link }

{:Return MaxBuffer header parameter.
  @since   2002-05-28
}
function TGpSharedPoolIndex.MaxBuffers: cardinal;
begin
  Result := SafeGetHeader('MaxBuffers')^.sphMaxBuffers;
end; { TGpSharedPoolIndex.MaxBuffers }

{:Return NumBuffers header parameter.
  @since   2002-05-28
}
function TGpSharedPoolIndex.NumBuffers: cardinal;
begin
  Result := SafeGetHeader('NumBuffers')^.sphNumBuffers;
end; { TGpSharedPoolIndex.NumBuffers }

{:Return NumEntries header parameters.
  @since   2002-06-11
}        
function TGpSharedPoolIndex.NumEntries: cardinal;
begin
  Result := SafeGetHeader('NumEntries')^.sphNumEntries;
end; { TGpSharedPoolIndex.NumEntries }

{:Send buffer from Writer to Reader.
  @since   2002-06-03
}
function TGpSharedPoolIndex.PrepareToSend(
  var buffer: TGpSharedMemory): TGpSharedPoolError;
var
  header: PGpSharedPoolHeader;
  idx   : cardinal;
begin
  header := SafeGetHeader('FreeBuffer');
  idx := GetEntryIndex(buffer.Name);
  if idx = Card_INVALID_HANDLE_VALUE then
    Result := speNotOwner
  else begin
    if Entry[idx].spieStatus <> Ord(iesAllocated) then
      raise Exception.Create('GpSharedMemory/TGpSharedPoolIndex.PrepareToSend: trying to send buffer with status '+IntToStr(Entry[idx].spieStatus));
    Entry[idx].spieStatus := Ord(iesQueued);
    Link(idx,header^.sphQueuedList);
    Result := speOK;
    FreeAndNil(buffer);
  end;
end; { TGpSharedPoolIndex.PrepareToSend }

{:Take ownership of queued data and forward it to the recipient.
  @since   2002-06-04
}        
procedure TGpSharedPoolIndex.ReadData(
  dataForwarder: TGpSharedPoolDataForwarder); 
var
  bufList: TList{cardinal};
  header : PGpSharedPoolHeader;
  iBuf   : integer;
  idx    : cardinal;
  shm    : TGpSharedMemory;
begin
  header := SafeGetHeader('ReadData');
  bufList := TList.Create;
  try
    while header^.sphQueuedList <> Card_INVALID_HANDLE_VALUE do begin
      idx := header^.sphQueuedList;
      Unlink(idx, header^.sphQueuedList);
      if Entry[idx].spieStatus <> Ord(iesQueued) then
        raise Exception.Create('GpSharedMemory/TGpSharedPoolIndex.ReadData: trying to receive buffer with status '+IntToStr(Entry[idx].spieStatus));
      if not assigned(dataForwarder) then begin
        Entry[idx].spieStatus := Ord(iesFree);
        Link(idx,header^.sphFreeList);
        Inc(header^.sphFreeBuffers);
      end
      else begin
        Entry[idx].spieStatus := Ord(iesAllocated);
        bufList.Add(pointer(idx));
      end;
    end; //while
    for iBuf := 0 to bufList.Count-1 do begin
      shm := TGpSharedMemory.Create(GetEntryName(cardinal(bufList[iBuf])),
        BufferInitialSize, BufferMaxSize, false);
      shm.AcquireMemory(true, 0);
      dataForwarder(shm);
    end;
  finally FreeAndNil(bufList); end;
end; { TGpSharedPoolIndex.ReadData }

{:Release index block.
  @since   2002-05-30
}
procedure TGpSharedPoolIndex.Release;
begin
  if assigned(spiDirectoryBlock) and spiDirectoryBlock.Acquired then
    spiDirectoryBlock.ReleaseMemory;
  spiHeaderBlock.ReleaseMemory;
end; { TGpSharedPoolIndex.Release }

{:Return ResizeThreshold header parameter.
  @since   2002-05-28
}
function TGpSharedPoolIndex.ResizeThreshold: cardinal;
begin
  Result := SafeGetHeader('ResizeThreshold')^.sphResizeThreshold;
end; { TGpSharedPoolIndex.ResizeThreshold }

{:Check if index block is acquired and initialized, then return pointer to the
  header.
  @since   2002-05-30
}
function TGpSharedPoolIndex.SafeGetHeader(methodName: string;
  checkIfInitialized: boolean): PGpSharedPoolHeader;
begin
  if not spiHeaderBlock.Acquired then
    raise Exception.Create('GpSharedMemory/TGpSharedPoolIndex.'+methodName+': index block is not acquired');
  if checkIfInitialized and (not IsInitialized) then
    raise Exception.Create('GpSharedMemory/TGpSharedPoolIndex.'+methodName+': index block is not initialized');
  Result := PGpSharedPoolHeader(spiHeaderBlock.DataPointer);
end; { TGpSharedPoolIndex.SafeGetHeader }

{:Check whether index should be resized.
  @since   2002-05-28
}
function TGpSharedPoolIndex.ShouldResize: boolean;
begin
  Result := (FreeBuffers < ResizeThreshold) and CanResize;
end; { TGpSharedPoolIndex.ShouldResize }

{:Check if version of the index block is supported.
  @since   2002-05-31
}        
function TGpSharedPoolIndex.SupportedVersion: boolean;
begin
  Result := (Version = 1);
end; { TGpSharedPoolIndex.SupportedVersion }

{:Dispose shared memory areas that were not used for long time.
  @since   2002-05-31
}
procedure TGpSharedPoolIndex.Sweep;
var
  header     : PGpSharedPoolHeader;
  idx        : cardinal;
  iEntry     : integer;
  iList      : integer;
  releaseList: TList{cardinal};
begin
  header := SafeGetHeader('Sweep');
  releaseList := TList.Create;
  try
    idx := header^.sphFreeList;
    while (idx <> Card_INVALID_HANDLE_VALUE) and
          (header^.sphNumBuffers > (header^.sphMinBuffers+cardinal(releaseList.Count))) do
    begin
      if (Entry[idx].spieStatus = Ord(iesFree)) and
         ((Now-Entry[idx].spieReleasedAt)*SecsPerDay > header^.sphSweepTimeoutSec)
      then
        releaseList.Add(pointer(idx));
      idx := Entry[idx].spieNext;
    end; //while
    for iList := 0 to releaseList.Count-1 do begin
      iEntry := cardinal(releaseList[iList]);
      TGpSharedMemory(Entry[iEntry].spieHandle).Free;
      TGpSharedMemory(Entry[iEntry].spieHandle) := nil;
      Entry[iEntry].spieStatus := Ord(iesDisposed);
      Unlink(iEntry, header^.sphFreeList);
      Link(iEntry, header^.sphDisposedList);
      Dec(header^.sphNumBuffers);
      Dec(header^.sphFreeBuffers);
    end; //for
  finally FreeAndNil(releaseList); end;
end; { TGpSharedPoolIndex.Sweep }

{:Try to resize index and allocate more buffers.
  @param   numBuffers Number of buffers to allocate. If 0,
                      header^.sphResizeIncrement buffers are allocated.
  @returns False if buffer cannot be allocated. Caller should check
           Windows.GetLastError for more information.
  @errors  speWin32Error
  @since   2002-05-28
}
function TGpSharedPoolIndex.TryToResize(numBuffers: cardinal): TGpSharedPoolError;

  function CreateMemory(idx: cardinal): boolean;
  begin
    try
      Entry[idx].spieHandle := TGpSharedMemory.Create(GetEntryName(idx),BufferInitialSize,BufferMaxSize,false);
      Result := true;
    except
      Result := false;
    end;
  end; { CreateMemory }

var
  header: PGpSharedPoolHeader;
  iEntry: integer;
begin
  Result := speWin32Error;
  if not spiIsReader then
    raise Exception.Create('GpSharedMemory/TGpSharedPoolIndex.TryToResize: writer tried to resize shared memory pool');
  if not assigned(spiDirectoryBlock) then
    raise Exception.Create('GpSharedMemory/TGpSharedPoolIndex.TryToResize: directory does not exist');
  header := SafeGetHeader('TryToResize');
  if numBuffers = 0 then
    numBuffers := header^.sphResizeIncrement;
  while (numBuffers > 0) and (header^.sphDisposedList <> Card_INVALID_HANDLE_VALUE) do begin
    iEntry := header^.sphDisposedList;
    Unlink(iEntry, header^.sphDisposedList);
    if not CreateMemory(iEntry) then
      Exit;
    Entry[iEntry].spieStatus := Ord(iesFree);
    Link(iEntry, header^.sphFreeList);
    Dec(numBuffers);
    Inc(header^.sphNumBuffers);
    Inc(header^.sphFreeBuffers);
  end; //while
  if (header^.sphNumEntries + numBuffers) > header^.sphMaxBuffers then
    numBuffers := header^.sphMaxBuffers - header^.sphNumEntries;
  if numBuffers > 0 then begin
    spiDirectoryBlock.Size := spiDirectoryBlock.Size + numBuffers*SizeOf(header^.sphIndexEntrySize);
    for iEntry := header^.sphNumEntries+numBuffers-1 downto header^.sphNumEntries do begin
      if not CreateMemory(iEntry) then
        Exit;
      Entry[iEntry].spieStatus := Ord(iesFree);
      Link(iEntry, header^.sphFreeList);
    end; //for iEntry
    Inc(header^.sphNumBuffers, numBuffers);
    Inc(header^.sphFreeBuffers, numBuffers);
    Inc(header^.sphNumEntries, numBuffers);
  end;
  Result := speOK;
end; { TGpSharedPoolIndex.TryToResize }

{:Unlink entry from the list.
  @since   2002-05-30
}
procedure TGpSharedPoolIndex.Unlink(entryIdx: cardinal; var listHead: cardinal);
begin
  if entryIdx = Card_INVALID_HANDLE_VALUE then
    raise Exception.Create('GpSharedMemory/TGpSharedPoolIndex.Unlink: trying to unlink nil pointer');
  if Entry[entryIdx].spiePrevious <> Card_INVALID_HANDLE_VALUE then
    Entry[Entry[entryIdx].spiePrevious].spieNext := Entry[entryIdx].spieNext;
  if Entry[entryIdx].spieNext <> Card_INVALID_HANDLE_VALUE then
    Entry[Entry[entryIdx].spieNext].spiePrevious := Entry[entryIdx].spiePrevious;
  if listHead = entryIdx then
    listHead := Entry[entryIdx].spieNext;
end; { TGpSharedPoolIndex.Unlink }

{:Return Version header parameter.
  @since   2002-05-30
}        
function TGpSharedPoolIndex.Version: cardinal;
begin
  Result := SafeGetHeader('Version')^.sphVersion;
end; { TGpSharedPoolIndex.Version }

{ TGpBaseSharedPool }

{:Acquire index block.
  @returns False if index has not been initialized yet, if reader is not alive,
           or if index cannot be acquired in CSharedPoolWatchdogTimeoutSec
           seconds.
  @since   2002-05-28
}
function TGpBaseSharedPool.AcquireIndex(checkIfInitialized: boolean): boolean;
begin
  Result := bspIndex.Acquire(CSharedPoolWatchdogTimeoutSec*1000);
  if Result and checkIfInitialized and (not (Index.IsInitialized and IsReaderAlive)) then begin
    ReleaseIndex;
    Result := false;
  end;
end; { TGpBaseSharedPool.AcquireIndex }

{:Acquire shared memory block from the pool. Returned memory block does not have
  access protection and is returned in the acquired state.
  @param   timeout Max time (in milliseconds) process will try to acquire the
                   pool memory. INFINITE is supported.
  @returns Nil if memory cannot be acquired. Application should check LastError
           property for more information.
  @errors  speNoReader, spePoolFull, speInvalidVersion
  @since   2002-05-28
}
function TGpBaseSharedPool.AcquireBuffer(timeout: DWORD): TGpSharedMemory;
begin
  Result := InternalAcquireBuffer(timeout, true);
end; { TGpBaseSharedPool.AcquireBuffer }

function TGpBaseSharedPool.InternalAcquireBuffer(timeout: DWORD;
  doAcquireIndex: boolean): TGpSharedMemory;
var
  start: int64;
begin
  Result := nil;
  SetError(speOK);
  start := GetTickCount;
  repeat
    if doAcquireIndex and (not AcquireIndex) then
      SetError(speNoReader)
    else begin
      try
        if not Index.SupportedVersion then
          SetError(speInvalidVersion)
        else begin
          if IsReader and (Index.FreeBuffers = 0) then
            UnprotectedTryToResize;
          if Index.FreeBuffers > 0 then begin
            Result := Index.GetFreeBuffer;
            if Index.ShouldResize then
              if IsReader then
                UnprotectedTryToResize
              else
                MessageQueue.PostMessage(CGpSharedPoolMessageQueueWriteTimeout, WM_PLEASE_RESIZE, 0, 0);
          end
          else if Index.CanResize then begin
            assert(not IsReader,'GpSharedMemory/TGpBaseSharedPool.AcquireMemory: IsReader and Index.CanResize');
            MessageQueue.PostMessage(CGpSharedPoolMessageQueueWriteTimeout, WM_PLEASE_RESIZE, 0, 0);
          end;
        end;
      finally
        if doAcquireIndex then
          ReleaseIndex;
      end;
    end; //else not AcquireIndex
    if assigned(Result) or Elapsed(start, timeout) then
      break; //repeat
    Sleep(0);
  until false;
  if (not assigned(Result)) and (LastError = speOK) then
    SetError(spePoolFull);
  if assigned(Result) then
    bspAcquiredList.Add(Result);
end; { TGpBaseSharedPool.InternalAcquireBuffer }

{:Acquire shared memory block from the pool, copy data from existing buffer into
  it and return object representing new buffer. Returned memory block does not
  have access protection and is returned in the acquired state. AcquireCopy will
  return error speBufferTooBig if source buffer is larger than maximum pool
  buffer size.
  @param   shm     Shared memory object containing data.
  @param   timeout Max time (in milliseconds) process will try to acquire the
                   pool memory. INFINITE is supported.
  @returns Nil if memory cannot be acquired. Application should check LastError
           property for more information.
  @errors  speBufferTooBig, speNoReader, spePoolFull, speInvalidVersion
  @seeAlso AcquireBuffer
  @since   2002-05-28
}
function TGpBaseSharedPool.AcquireCopy(shm: TGpSharedMemory;
  timeout: DWORD): TGpSharedMemory;
begin
  Result := InternalAcquireCopy(shm, timeout, true);
end; { TGpBaseSharedPool.AcquireCopy }

function TGpBaseSharedPool.InternalAcquireCopy(shm: TGpSharedMemory;
  timeout: DWORD; doAcquireIndex: boolean): TGpSharedMemory;
begin
  Result := nil;
  if shm.Size > Index.BufferMaxSize then
    SetError(speBufferTooBig)
  else begin
    Result := InternalAcquireBuffer(timeout, doAcquireIndex);
    if assigned(Result) then begin
      Result.Size := shm.Size;
      Move(shm.DataPointer^, Result.DataPointer^, shm.Size);
    end;
  end;
end; { TGpBaseSharedPool.InternalAcquireCopy }

{:Set error code to speOK.
  @returns True.
  @since   2002-05-28
}        
function TGpBaseSharedPool.ClearError: boolean;
begin
  SetError(speOK);
  Result := true;
end; { TGpBaseSharedPool.ClearError }

{:Create shared pool object.
  @since   2002-05-29
}        
constructor TGpBaseSharedPool.Create(objectName: AnsiString);
begin
  inherited Create;
  bspAcquiredList := TList.Create;
  bspName := objectName;
  bspIndex := TGpSharedPoolIndex.Create(string(objectName), IsReader);
end; { TGpBaseSharedPool.Create }

{:Destroy shared pool object.
  @since   2002-05-29
}
destructor TGpBaseSharedPool.Destroy;
var
  shm: TGpSharedMemory;
begin
  if assigned(bspAcquiredList) then begin
    while bspAcquiredList.Count > 0 do begin
      shm := TGpSharedMemory(bspAcquiredList[0]);
      ReleaseBuffer(shm); // will also remove buffer from bspAcquiredList
    end; // while
    FreeAndNil(bspAcquiredList);
  end;
  FreeAndNil(bspIndex);
  inherited;
end; { TGpBaseSharedPool.Destroy }

{:Check whether the reader is alive.
  @since   2002-05-29
}
function TGpBaseSharedPool.IsReaderAlive: boolean;
var
  testMutex: THandle{CreateMutex};
begin
  Result := true; // to keep Delphi happy
  testMutex := CreateMutex_AllowEveryone(false, string(ReaderMutexName));
  if testMutex = 0 then
    RaiseLastWin32Error
  else begin
    Result := (GetLastError = ERROR_ALREADY_EXISTS);
    CloseHandle(testMutex);
  end;
end; { TGpBaseSharedPool.IsReaderAlive }

{:Generate the name of the Reader's message queue.
  @since   2002-11-10
}
function TGpBaseSharedPool.ReaderMessageQueueName: AnsiString;
begin
  Result := Name + '/MQ';
end; { TGpBaseSharedPool.ReaderMessageQueueName }

{:Generate the name of the Reader's mutex.
  @since   2002-06-06
}
function TGpBaseSharedPool.ReaderMutexName: AnsiString;
begin
  Result := Name + '/Reader';
end; { TGpBaseSharedPool.ReaderMutexName }

{:Release index block.
  @since   2002-05-28
}
procedure TGpBaseSharedPool.ReleaseIndex;
begin
  bspIndex.Release;
end; { TGpBaseSharedPool.ReleaseIndex }

{:Release shared memory block back to the pool.
  @since   2002-05-28
}
procedure TGpBaseSharedPool.ReleaseBuffer(var shm: TGpSharedMemory);
begin
  bspAcquiredList.Remove(shm);
  if AcquireIndex then begin
    try
      if Index.SupportedVersion then
        Index.FreeBuffer(shm); // ignore errors
    finally ReleaseIndex; end;
  end;
  FreeAndNil(shm); // just in case AcquireIndex failed
end; { TGpBaseSharedPool.ReleaseBuffer }

{:Set error code.
  @returns False on error, True on success.
  @since   2002-05-28
}
function TGpBaseSharedPool.SetError(errorCode: TGpSharedPoolError): boolean;
begin
  bspLastError := errorCode;
  Result := (bspLastError = speOK);
end; { TGpBaseSharedPool.SetError }

{:Send shared buffer to the reader and release the object.
  @returns False if memory cannot be acquired. Application should check
           LastError property for more information.
  @errors  speNoReader
           (only when trying to send non-pool buffer): speBufferTooBig,
           speNoReader, spePoolFull, speInvalidVersion
  @since   2002-05-29
}
function TGpBaseSharedPool.SendBuffer(var shm: TGpSharedMemory): boolean;
var
  tempBuf: TGpSharedMemory;
begin
  if not AcquireIndex then
    Result := SetError(speNoReader)
  else begin
    try
      if not Index.SupportedVersion then
        Result := SetError(speInvalidVersion)
      else begin
        tempBuf := shm;
        Result := SetError(Index.PrepareToSend(shm));
        if Result then
          bspAcquiredList.Remove(tempBuf)
        else if LastError = speNotOwner then begin
          tempBuf := InternalAcquireCopy(shm, CSharedPoolForeignSendTimeoutSec*1000, false);
          Result := assigned(tempBuf);
          if Result then begin
            bspAcquiredList.Remove(shm);
            FreeAndNil(shm);
            shm := tempBuf;
            Result := SetError(Index.PrepareToSend(shm));
            if Result then
              bspAcquiredList.Remove(tempBuf);
          end;
        end; //if Result = speNotOwner
        if Result then
          MessageQueue.PostMessage(CGpSharedPoolMessageQueueWriteTimeout, WM_DATA_SENT, 0, 0);
      end;
    finally ReleaseIndex; end;
  end;
end; { TGpBaseSharedPool.SendBuffer }

function TGpBaseSharedPool.UnprotectedTryToResize: boolean;
begin
  Result := SetError(speInternalError);
end; { TGpBaseSharedPool.UnprotectedTryToResize }

function TGpBaseSharedPool.TokenPrefix: AnsiString;
begin
  Result := Name + '/Token/';
end; { TGpBaseSharedPool.TokenPrefix }

{ TGpSharedPoolReader }

{:Create shared pool reader object and create message queue.
  @since   2002-06-04
}
constructor TGpSharedPoolReader.Create(objectName: AnsiString);
begin
  inherited Create(objectName);
  sprMessageWindow := DSiAllocateHwnd(MessageMain);
  if sprMessageWindow = 0  then
    RaiseLastWin32Error;
  sprDataReceivedEvent := CreateEvent_AllowEveryone(false, false, '');
  if sprDataReceivedEvent = 0 then
    RaiseLastWin32Error;
  sprReceivedDataList := TList.Create{TGpSharedMemory};
  sprLiveTimers := TObjectList.Create{TDSiTimer};
end; { TGpSharedPoolReader.Create }

{:Destroy shared pool reader object.
  @since   2002-05-29
}
destructor TGpSharedPoolReader.Destroy;
begin
  FreeAndNil(sprLiveTimers);
  FreeAndNil(sprReceivedDataList);
  if sprDataReceivedEvent <> 0 then begin
    CloseHandle(sprDataReceivedEvent);
    sprDataReceivedEvent := 0; 
  end;
  FreeAndNil(sprMessageQueueReader);
  if sprReaderMutex <> 0 then begin
    CloseHandle(sprReaderMutex);
    sprReaderMutex := 0;
  end;
  if sprMessageWindow <> 0 then begin
    DSiDeallocateHwnd(sprMessageWindow);
    sprMessageWindow := 0;
  end;
  inherited Destroy;
end; { TGpSharedPoolReader.Destroy }

procedure TGpSharedPoolReader.DoDataReceived(shm: TGpSharedMemory);
begin
  if assigned(sprOnDataReceived) then
    sprOnDataReceived(self, shm);
end; { TGpSharedPoolReader.DoDataReceived }

procedure TGpSharedPoolReader.DoResized(oldSize, newSize: cardinal);
begin
  if assigned(sprOnResized) and (oldSize <> newSize) then
    sprOnResized(self, oldSize, newSize);
end; { TGpSharedPoolReader.DoResized }

{:Get next received buffer or nil if no buffers are waiting to be processed.
  Owner must release those buffers with a call to ReleaseBuffer.
  This function is only useful if OnDataReceived event is not specified.
  @since   2002-06-11
}
function TGpSharedPoolReader.GetMessageQueue: TGpMessageQueue;
begin
  Result := sprMessageQueueReader;
end; { TGpSharedPoolReader.GetMessageQueue }

function TGpSharedPoolReader.GetNextReceived: TGpSharedMemory;
begin
  if sprReceivedDataList.Count <= 0 then
    Result := nil
  else begin
    Result := TGpSharedMemory(sprReceivedDataList[0]);
    sprReceivedDataList.Delete(0);
  end;
end; { TGpSharedPoolReader.GetNextReceived }

{:Initializes shared pool.
  @returns False on error. For more information see LastError.
  @errors  speIncompatibleHeader, speAlreadyActive, speWin32Error, speTimeout
  @since   2002-05-29
}
function TGpSharedPoolReader.Initialize(initialBufferSize, maxBufferSize,
  startNumBuffers, maxNumBuffers, resizeIncrement, resizeThreshold,
  minNumBuffers, sweepTimeoutSec: cardinal): boolean;
begin
  if not AcquireIndex(false) then
    Result := SetError(speTimeout)
  else begin
    try
      if Index.IsInitialized and IsReaderAlive then
        Result := SetError(speAlreadyActive)
      else begin
        Result := SetError(Index.Initialize(initialBufferSize, maxBufferSize,
          startNumBuffers, maxNumBuffers, resizeIncrement, resizeThreshold,
          minNumBuffers, sweepTimeoutSec, TGpToken.GenerateToken(string(TokenPrefix))));
        if Result then begin
          sprReaderMutex := CreateMutex_AllowEveryone(false, string(ReaderMutexName));
          if sprReaderMutex = 0 then
            RaiseLastWin32Error;
          sprMessageQueueReader := TGpMessageQueueReader.Create(ReaderMessageQueueName,
            CGpSharedPoolMessageQueueSize, sprMessageWindow, WM_MQ_MESSAGE);
          sprSweepTimeoutSec := sweepTimeoutSec;
          if sprSweepTimeoutSec <> CDisableSweep then
            TriggerWakeup(sprSweepTimeoutSec*1000, WM_SWEEP);
        end;
      end; //if Result = speOK
    finally ReleaseIndex; end;
  end;
end; { TGpSharedPoolReader.Initialize }

function TGpSharedPoolReader.IsReader: boolean;
begin
  Result := true;
end; { TGpSharedPoolReader.IsReader }

{:Main message loop.
  @since   2002-06-04
}
procedure TGpSharedPoolReader.MessageMain(var Message: TMessage);
var
  getStatus: TGpMQGetStatus;
  lParam   : Windows.LPARAM;
  msg      : DWORD;
  wParam   : Windows.WPARAM;
begin
  if Message.Msg < WM_USER then
    with Message do
      Result := DefWindowProc(sprMessageWindow, Msg, wParam, lParam)
  else if Message.Msg = WM_MQ_MESSAGE then begin // reposted message from the TGpMessageQueueReader
    repeat
      getStatus := sprMessageQueueReader.GetMessage(CGpSharedPoolMessageQueueReadTimeout, msg, wParam, lParam);
      if getStatus = mqgOK then
        PostMessage(sprMessageWindow, msg, wParam, lParam)
      else if getStatus = mqgTimeout then
        PostMessage(sprMessageWindow, WM_MQ_MESSAGE, 0, 0);
    until getStatus <> mqgOK;
  end
  else if Message.Msg = WM_KILL_TIMER then
    sprLiveTimers.Remove(TDSiTimer(Message.WParam))
  else begin
    if sprFailedResize or (Message.Msg = WM_PLEASE_RESIZE) then
      sprFailedResize := not TryToResize;
    if sprFailedReadData or (Message.Msg = WM_DATA_SENT) then
      sprFailedReadData := not ReadData;
    if Message.Msg = WM_SWEEP then begin
      Sweep;
      TriggerWakeup(sprSweepTimeoutSec*1000, WM_SWEEP);
    end;
    if sprFailedResize or sprFailedReadData then
      TriggerWakeup(CFailedProcessingWakeup, WM_CONTINUE);
  end;
end; { TGpSharedPoolReader.MessageMain }

{:If object is not created in main thread, owner should periodically call
  MessagePump function to process window events.
  @since   2002-06-11
}
procedure TGpSharedPoolReader.ProcessMessages;
var
  msg: TMsg;
begin
  while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) and (Msg.Message <> WM_QUIT) do begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
  end;
end; { TGpSharedPoolReader.ProcessMessages }

{:Process internal timer message and destroy the timer.
  @since   2002-06-10
}
procedure TGpSharedPoolReader.ProcessTimer(Sender: TObject);
begin
  with Sender as TDSiTimer do begin
    Enabled := false;
    PostMessage(sprMessageWindow, Tag, 0, 0);
  end; //with
  PostMessage(sprMessageWindow, WM_KILL_TIMER, WPARAM(Sender), 0);
end; { TGpSharedPoolReader.ProcessTimer }

{:Called from the message loop when data is waiting to be read.
  @since   2002-06-04
}
function TGpSharedPoolReader.ReadData: boolean;
var
  iData: integer;
begin
  if not AcquireIndex then
    Result := false
  else begin
    try
      Index.ReadData(StoreReceivedData);
    finally ReleaseIndex; end;
    if assigned(sprOnDataReceived) then begin
      for iData := 0 to sprReceivedDataList.Count-1 do
        DoDataReceived(TGpSharedMemory(sprReceivedDataList[iData]));
      sprReceivedDataList.Clear;
    end;
    //else wait for owner to read data explicitely via GetNextReceived
    SetEvent(sprDataReceivedEvent);
    Result := true;
  end;
end; { TGpSharedPoolReader.ReadData }

{:Index callback procedure that stores received buffer into internal list.
  @since   2002-06-10
}
procedure TGpSharedPoolReader.StoreReceivedData(shm: TGpSharedMemory);
begin
  sprReceivedDataList.Add(shm);
  AcquiredList.Add(shm);
end; { TGpSharedPoolReader.StoreReceivedData }

{:Called from the message loop when pool should be sweeped.
  @since   2002-06-06
}
function TGpSharedPoolReader.Sweep: boolean;
var
  oldNum: cardinal;
begin
  if not AcquireIndex then
    Result := SetError(speTimeout)
  else begin
    try
      oldNum := Index.NumBuffers;
      Index.Sweep;
      DoResized(oldNum, Index.NumBuffers);
      Result := ClearError;
    finally ReleaseIndex; end;
  end;
end; { TGpSharedPoolReader.Sweep }

{:Set up timer to wake up after specified time.
  @param   afterms    Timeout in ms.
  @param   messageNum Message to be sent to sprMessageWindow after specified
                      timeout is expired.
  @since   2002-06-09
}
procedure TGpSharedPoolReader.TriggerWakeup(afterms, messageNum: cardinal);
var
  timer: TDSiTimer;
begin
  timer := TDSiTimer.Create(true, afterms, ProcessTimer, messageNum);
  sprLiveTimers.Add(timer);
end; { TGpSharedPoolReader.TriggerWakeup }

{:Called from the message loop when pool should be resized.
  @since   2002-06-06
}
function TGpSharedPoolReader.TryToResize: boolean;
begin
  if not AcquireIndex then
    Result := SetError(speTimeout)
  else begin
    try
      Result := UnprotectedTryToResize;
    finally ReleaseIndex; end;
  end;
end; { TGpSharedPoolReader.TryToResize }

function TGpSharedPoolReader.UnprotectedTryToResize: boolean;
var
  oldSize: cardinal;
begin
  oldSize := Index.NumBuffers;
  Result := SetError(Index.TryToResize);
  if Result then
    DoResized(oldSize, Index.NumBuffers);
end; { TGpSharedPoolReader.UnprotectedTryToResize }

{ TGpSharedPoolWriter }

{:Create message queue writer.
  @since   2002-11-10
}        
constructor TGpSharedPoolWriter.Create(objectName: AnsiString);
begin
  inherited Create(objectName);
  sprMessageQueue := TGpMessageQueueWriter.Create(ReaderMessageQueueName,
    CGpSharedPoolMessageQueueSize);
end; { TGpSharedPoolWriter.Create }

destructor TGpSharedPoolWriter.Destroy;
begin
  FreeAndNil(sprMessageQueue);
  inherited;
end; { TGpSharedPoolWriter.Destroy }

function TGpSharedPoolWriter.GetMessageQueue: TGpMessageQueue;
begin
  Result := sprMessageQueue;
end; { TGpSharedPoolWriter.GetMessageQueue }

function TGpSharedPoolWriter.IsReader: boolean;
begin
  Result := false;
end; { TGpSharedPoolWriter.IsReader }

{$IFDEF Testing}

{ TGpTestSharedMemory }

procedure TGpTestSharedMemory.DoResize(newSize: cardinal);
begin
  assert(assigned(tsmMemory), 'resize: object doesn''t exist');
  assert(assigned(tsmData), 'resize: memory is not acquired');
  (tsmMemory as TGpSharedMemory).Size := newSize;
  assertEQ(tsmMemory.Size, newSize, 'resize: size mismatch');
  assert(assigned(tsmData), 'resize: memory is not acquired');
end; { TGpTestSharedMemory.DoResize }

procedure TGpTestSharedMemory.RunAcquired(acquireForWriting,
  shouldSucceed: boolean);
begin
  assert(assigned(tsmMemory), 'object doesn''t exist');
  tsmData := tsmMemory.AcquireMemory(acquireForWriting, 500);
  assertEQ(assigned(tsmData), shouldSucceed,
    'AcquireMemory returned wrong result');
end; { TGpTestSharedMemory.RunAcquired }

procedure TGpTestSharedMemory.RunCheckSize(expectedSize: cardinal);
begin
  assert(assigned(tsmMemory), 'object doesn''t exist');
  assertEQ(tsmMemory.Size, LongParam(1), 'invalid size');
end; { TGpTestSharedMemory.RunCheckSize }

procedure TGpTestSharedMemory.RunCheckState(expectedAcquired,
  expectedIsWriting: boolean);
begin
  assert(assigned(tsmMemory), 'object doesn''t exist');
  assertEQ(tsmMemory.Acquired, expectedAcquired,
    'Acquired is in wrong state');
  assertEQ(tsmMemory.IsWriting, expectedIsWriting,
    'IsWriting is in wrong state');
end; { TGpTestSharedMemory.RunCheckState }

procedure TGpTestSharedMemory.RunCommand;
begin
  if Command = 'create' then
    // <bool> - expected state of the WasCreated property
    // [bool] - resizable(T) or fixed-size(F); optional; default F
    RunCreate(BoolParam(1), OptBoolParam(2, false))
  else if Command = 'destroy' then
    // no parameters
    RunDestroy
  else if Command = 'acquire' then
    // (W|R) - require for write or read
    // <bool> - expected return from the AcquireMemory call
    RunAcquired(UCParam(1)='W', BoolParam(2))
  else if Command = 'release' then
    // no parameters
    RunRelease
  else if Command = 'checkstate' then
    // <bool> - expected return of the Acquired function
    // <bool> - expected state of the IsWriting property
    RunCheckState(BoolParam(1), BoolParam(2))
  else if Command = 'memaccess' then
    // (W|R) - test write or read
    // [dword] - value to be written/read; optional
    RunMemAccess(UCParam(1)='W', OptLongParam(2))
  else if Command = 'makesnapshot' then
    // no parameters
    RunMakeSnapshot
  else if Command = 'testsnapshot' then
    // (W|R) - test write or read
    // [dword] - value to be written/read; optional
    RunTestSnapshot(UCParam(1)='W', OptLongParam(2))
  else if Command = 'freesnapshot' then
    // no parameters
    RunFreeSnapshot
  else if Command = 'checksize' then
    // <dword> - expected size of the shared memory object
    RunCheckSize(LongParam(1))
  else if Command = 'teststream' then
    // (W|R) - test write or read
    // <dword> - value to be written/read
    // <bool> - read/write past end
    RunTestStream(UCParam(1)='W', LongParam(2), BoolParam(3))
  else if Command = 'sizestream' then
    // no parameters
    RunSizeStream
  else if Command = 'resize' then
    // [value] - new size for the shared memory object
    // (T|F) - expected return from the AcquireMemory call
    DoResize(LongParam(1))
  else
    Assert(false, 'unknown command');
end; { TGpTestSharedMemory.RunCommand }

procedure TGpTestSharedMemory.RunCreate(expectedWasCreated: boolean; createResizable: boolean);
begin
  assert(not assigned(tsmMemory), 'object already exists');
  tsmMemory := TGpSharedMemory.Create('TEST_SM', 1023, IFF(createResizable,102300,0));
  assertEQ(tsmMemory.WasCreated, expectedWasCreated,
    'WasCreated if in wrong state');
end; { TGpTestSharedMemory.RunCreate }

procedure TGpTestSharedMemory.RunDestroy;
begin
  assert(assigned(tsmMemory), 'object doesn''t exist');
  FreeAndNil(tsmMemory);
  tsmData := nil;
  assert(not assigned(tsmMemory), 'failed');
end; { TGpTestSharedMemory.RunDestroy }

procedure TGpTestSharedMemory.RunFreeSnapshot;
begin
  assert(assigned(tsmMemory), 'object doesn''t exist');
  assert(assigned(tsmSnapshot), 'snapshot doesn''t exist');
  FreeAndNil(tsmSnapshot);
  assert(not assigned(tsmSnapshot), 'snapshot still exists');
end; { TGpTestSharedMemory.RunFreeSnapshot }

procedure TGpTestSharedMemory.RunMakeSnapshot;
begin
  assert(assigned(tsmMemory), 'object doesn''t exist');
  assert(not assigned(tsmSnapshot), 'snapshot already exists');
  tsmSnapshot := tsmMemory.MakeSnapshot;
end; { TGpTestSharedMemory.RunMakeSnapshot }

procedure TGpTestSharedMemory.RunMemAccess(testWriteAccess: boolean;
  testValue: cardinal);
begin
  assert(assigned(tsmMemory), 'object doesn''t exist');
  // DNT: assert(assigned(tsmData), 'memaccess: memory is not acquired');
  TestMemAccess(tsmMemory, testWriteAccess, testValue);
end; { TGpTestSharedMemory.RunMemAccess }

procedure TGpTestSharedMemory.RunRelease;
begin
  assert(assigned(tsmMemory), 'object doesn''t exist');
  tsmMemory.ReleaseMemory;
  assert(true);
end; { TGpTestSharedMemory.RunRelease }

procedure TGpTestSharedMemory.RunSizeStream;
begin
  tsmMemory.AsStream.Size := tsmMemory.AsStream.Size div 2;
end; { TGpTestSharedMemory.RunSizeStream }

function TGpTestSharedMemory.RunTest: boolean;
begin
  Result := ExecuteScript(
    '#Creation and WasCreated                                                                 '#13#10+
    '1:create(T)                # Create first object; must return [created]                  '#13#10+
    '2:create(F)                # Create second object; must return [-created]                '#13#10+
    '2:destroy                  # Destroy second object                                       '#13#10+
    '2:create(F)                # Create second object; must return [-created]                '#13#10+
    '2:destroy                  # Destroy second object                                       '#13#10+
    '1:destroy                  # Destroy first object                                        '#13#10+
    '2:create(T)                # Create second object; must return [created]                 '#13#10+
    '1:create(F)                # Create first object; must return [-created]                 '#13#10+

    '#Acquire for write and check state                                                       '#13#10+
    '1:acquire(W,T)             # Acquire first object for writing; must succeed              '#13#10+
    '1:checkstate(T,T)          # Check first object''s state; must be [acquired],[writing]   '#13#10+

    '#Try to acquire second object                                                            '#13#10+
    '2:acquire(W,F)             # Try to acquire second object for writing; must fail         '#13#10+
    '2:memaccess(W)/E           # Try to write to second object; must raise exception         '#13#10+
    '2:acquire(R,F)             # Try to acquire second object for reading; must fail         '#13#10+
    '2:memaccess(R)/E           # Try to read from second object; must raise exception        '#13#10+
    '2:checkstate(F,F)          # Check second object''s state; must be [-acquired],[-writing]'#13#10+
    '2:release/E                # Try to release second object; must raise exception          '#13#10+

    '#Write data and release                                                                  '#13#10+
    '1:memaccess(W,$55AA00FF)   # Try to write to first object; must succeed                  '#13#10+
    '1:memaccess(R,$55AA00FF)   # Try to read from first object; must succeed                 '#13#10+
    '1:makesnapshot             # Create snapshot of the first object; must succeed           '#13#10+
    '1:release                  # Try to release first object; must succeed                   '#13#10+
    '1:release/E                # Try to release first object; must raise exception           '#13#10+

    '#Acquire second for write, check state, check data                                       '#13#10+
    '2:acquire(W,T)             # Try to acquire second object for writing; must succeed      '#13#10+
    '1:acquire(W,F)             # Try to acquire first object for writing; must fail          '#13#10+
    '1:acquire(R,F)             # Try to acquire first object for reading; must fail          '#13#10+
    '2:checkstate(T,T)          # Check second object''s state; must be [acquired],[writing]  '#13#10+
    '2:memaccess(R,$55AA00FF)   # Try to read and check value; must succeed                   '#13#10+
    '2:memaccess(W,$AA00FF55)   # Try to write; must succeed                                  '#13#10+
    '2:release                  # Release                                                     '#13#10+
    '2:acquire(R,T)             # Acquire immediately for reading, must succeed               '#13#10+
    '2:memaccess(R,$AA00FF55)   # Read, check data                                            '#13#10+
    '1:acquire(R,T)             # Acquire first object; must succeed                          '#13#10+
    '1:memaccess(R,$AA00FF55)   # Read, check data                                            '#13#10+
    '1:testsnapshot(R,$55AA00FF)# Check snapshot; value must still be $55AA00FF               '#13#10+
    '1:testsnapshot(W)/E        # Try to write to snapshot, must raise exception              '#13#10+
    '1:freesnapshot             # Free snapshot                                               '#13#10+
    '1:memaccess(W)/E           # Try to write; must raise exception                          '#13#10+
    '2:memaccess(W)/E           # Try to write to second object; must raise exception         '#13#10+

    '#Stream functions                                                                        '#13#10+
    '1:release                  # Release                                                     '#13#10+
    '2:release                  # Release                                                     '#13#10+
    '1:acquire(W,T)             # Acquire first object for writing; must succeed              '#13#10+
    '1:teststream(W,$55AA00FF,F)    # Write $55AA00FF to stream, don''t expand                '#13#10+
    '1:teststream(R,$55AA00FF,T)    # Read from stream, read past end                         '#13#10+
    '1:teststream(W,$55AA00FF,T)/E  # Write $55AA00FF to stream, try to expand; must raise    '#13#10+
    '1:teststream(R,$55AA00FF,F)    # Read from stream, don''t read past end                  '#13#10+
    '1:checksize(1023)          # Check if size is still right                                '#13#10+
    '1:memaccess(R)/E           # Read; must raise exception                                  '#13#10+
    '1:sizestream/E             # Set size; must raise exception                              '#13#10+
    '1:checksize(1023)          # Check if AsStream.Size was ignored                          '#13#10+
    '1:memaccess(R)/E           # Read must still not work; must raise exception              '#13#10+
    '1:release                  # Release                                                     '#13#10+
    '2:acquire(R,T)             # Acquire immediately for reading, must succeed               '#13#10+
    '1:acquire(R,T)             # Acquire first object; must succeed                          '#13#10+
    '2:teststream(W,$FFAA0055,F)/E  # Write $FFAA0055 to stream; must raise exception         '#13#10+
    '2:teststream(R,$55AA00FF,F)    # Read from stream, don''t read past end                  '#13#10+
    '1:teststream(R,$55AA00FF,F)    # Read from stream, don''t read past end                  '#13#10+
    '1:sizestream/E             # Set size; must raise exception                              '#13#10+
    '1:checksize(1023)          # Check if AsStream.Size was ignored                          '#13#10+
    '1:memaccess(R)/E           # Read must still not work; must raise exception              '#13#10+

    '#Release, test access functions                                                          '#13#10+
    '1:release                  # Release                                                     '#13#10+
    '2:release                  # Release                                                     '#13#10+
    '2:memaccess(R)/E           # Try to read to second object; must raise exception          '#13#10+
    '2:memaccess(W)/E           # Try to write to second object; must raise exception         '#13#10+
    '1:makesnapshot/E           # Create snapshot of the first object; must raise exception   '#13#10+

    '#Cleanup                                                                                 '#13#10+
    '2:destroy                  # Destroy second object                                       '#13#10+
    '1:destroy                  # Destroy first object                                        '#13#10+

    '#Create resizable                                                                        '#13#10+
    '1:create(T,T)              # Create first object; must return [created]                  '#13#10+
    '2:create(F,T)              # Create second object; must return [-created]                '#13#10+

    '#Acquire for write and check state                                                       '#13#10+
    '1:acquire(W,T)             # Acquire first object for writing; must succeed              '#13#10+
    '1:checkstate(T,T)          # Check first object''s state; must be [acquired],[writing]   '#13#10+

    '#Resize, check state                                                                     '#13#10+
    '1:checksize(1023)          # Check size, must be 1023                                    '#13#10+
    '1:resize(2047)             # Resize, must succeed                                        '#13#10+
    '1:checksize(2047)          # Check size, must be 2047                                    '#13#10+
    '1:checkstate(T,T)          # Check first object''s state; must be [acquired],[writing]   '#13#10+
    '1:memaccess(W,$55AA00FF)   # Try to write to first object; must succeed                  '#13#10+
    '1:memaccess(R,$55AA00FF)   # Try to read from first object; must succeed                 '#13#10+
    '1:resize(65544)            # Resize over 64 KB boundary                                  '#13#10+
    '1:checksize(65544)         # Check size, must be 65544                                   '#13#10+
    '1:memaccess(W,$55AA00FF)   # Try to write to first object; must succeed                  '#13#10+
    '1:memaccess(R,$55AA00FF)   # Try to read from first object; must succeed                 '#13#10+
    '1:resize(2047)             # Resize back to small size                                   '#13#10+
    '1:checksize(2047)          # Check size, must be 2047                                    '#13#10+
    '1:memaccess(W,$55AA00FF)   # Try to write to first object; must succeed                  '#13#10+
    '1:memaccess(R,$55AA00FF)   # Try to read from first object; must succeed                 '#13#10+
    '1:resize(65544)            # Resize over 64 KB boundary                                  '#13#10+
    '1:checksize(65544)         # Check size, must be 65544                                   '#13#10+
    '1:memaccess(W,$55AA00FF)   # Try to write to first object; must succeed                  '#13#10+
    '1:memaccess(R,$55AA00FF)   # Try to read from first object; must succeed                 '#13#10+
    '1:resize(2047)             # Resize back to small size                                   '#13#10+
    '1:checksize(2047)          # Check size, must be 2047                                    '#13#10+
    '1:memaccess(W,$55AA00FF)   # Try to write to first object; must succeed                  '#13#10+
    '1:memaccess(R,$55AA00FF)   # Try to read from first object; must succeed                 '#13#10+
    '1:release                  # Release first object                                        '#13#10+

    '#Acquire second for read, check state                                                    '#13#10+
    '2:acquire(R,T)             # Try to acquire second object for reading; must succeed      '#13#10+
    '2:checkstate(T,F)          # Check second object''s state; must be [acquired],[-writing] '#13#10+
    '2:memaccess(R,$55AA00FF)   # Try to read and check value; must succeed                   '#13#10+
    '2:resize(1023)/E           # Resize, must raise exception                                '#13#10+
    '2:checksize(2047)          # Check size, must be 2047                                    '#13#10+ 

    '#Stream functions (resizable)                                                            '#13#10+
    '2:release                  # Release                                                     '#13#10+
    '1:acquire(W,T)             # Acquire first object for writing; must succeed              '#13#10+
    '1:resize(1020)             # Resize                                                      '#13#10+
    '1:teststream(W,$55AA00FF,F)    # Write $55AA00FF to stream, don''t expand                '#13#10+
    '1:teststream(R,$55AA00FF,T)    # Read from stream, read past end                         '#13#10+
    '1:teststream(W,$55AA00FF,T)    # Write $55AA00FF to stream, try to expand                '#13#10+
    '1:teststream(R,$55AA00FF,T)    # Read from stream, dont''t read past end                 '#13#10+
    '1:checksize(1024)          # Check if new size is right                                  '#13#10+
    '1:memaccess(R)/E           # Read; must raise exception                                  '#13#10+
    '1:sizestream               # Set size; must work                                         '#13#10+
    '1:checksize(512)           # Check if AsStream.Size is right                             '#13#10+
    '1:memaccess(R)/E           # Read must still not work; must raise exception              '#13#10+
    '1:release                  # Release                                                     '#13#10+
    '2:acquire(R,T)             # Acquire immediately for reading, must succeed               '#13#10+
    '2:checksize(512)           # Again check if size is right                                '#13#10+
    '1:acquire(R,T)             # Acquire first object; must succeed                          '#13#10+
    '2:teststream(W,$FFAA0055,F)/E  # Write $FFAA0055 to stream; must raise exception         '#13#10+
    '2:teststream(R,$55AA00FF,F)    # Read from stream, don''t read past end                  '#13#10+
    '1:teststream(R,$55AA00FF,F)    # Read from stream, don''t read past end                  '#13#10+
    '1:sizestream/E             # Set size; must raise exception                              '#13#10+
    '1:checksize(512)           # Check if AsStream.Size was ignored                          '#13#10+
    '1:memaccess(R)/E           # Read must still not work; must raise exception              '#13#10+

    '#Cleanup                                                                                 '#13#10+
    '2:destroy                  # Destroy second object                                       '#13#10+
    '1:destroy                  # Destroy first object                                        '#13#10+

    '#Bug (fixed in 2.01a)                                                                    '#13#10+
    '1:create(T,T)              # Create first object; must return [created]                  '#13#10+
    '2:create(F,T)              # Create second object; must return [-created]                '#13#10+
    '1:acquire(W,T)             # Acquire first object for writing; must succeed              '#13#10+
    '1:checkstate(T,T)          # Check first object''s state; must be [acquired],[writing]   '#13#10+
    '1:checksize(1023)          # Check size, must be 1023                                    '#13#10+
    '1:resize(2047)             # Resize, must succeed                                        '#13#10+
    '1:checksize(2047)          # Check size, must be 2047                                    '#13#10+
    '1:checkstate(T,T)          # Check first object''s state; must be [acquired],[writing]   '#13#10+
    '1:release                  # Release first object                                        '#13#10+
    '1:destroy                  # Destroy first object                                        '#13#10+
    '2:acquire(R,T)             # Bug: program crashed here.                                  '#13#10+
    '2:checkstate(T,F)          # Check first object''s state; must be [acquired],[-writing]  '#13#10+
    '2:release                  # Release second object                                       '#13#10+
    '2:destroy                  # Destroy second object                                       '#13#10+

    '#AcquireMemory/ReleaseMemory nesting (added in 4.07)                                     '#13#10+
    '1:create(T,T)              # Create first object; must return [created]                  '#13#10+
    '2:create(F,T)              # Create second object; must return [-created]                '#13#10+
    '#  Write after write                                                                     '#13#10+
    '1:acquire(W,T)             # Acquire first object for writing; must succeed              '#13#10+
    '1:memaccess(R)             # Read must work                                              '#13#10+
    '1:memaccess(W)             # Write must work                                             '#13#10+
    '1:acquire(W,T)             # Acquire first object for writing again; must succeed        '#13#10+
    '1:memaccess(R)             # Read must work                                              '#13#10+
    '1:memaccess(W)             # Write must work                                             '#13#10+
    '2:acquire(W,F)             # Acquire second object for writing; must fail                '#13#10+
    '1:release                  # Release first object                                        '#13#10+
    '2:acquire(W,F)             # Acquire second object for writing; must fail                '#13#10+
    '1:release                  # Release first object                                        '#13#10+
    '2:acquire(W,T)             # Acquire second object for writing; must succeed             '#13#10+
    '2:memaccess(W)             # Write must work                                             '#13#10+
    '2:release                  # Release first object                                        '#13#10+
    '#  Read after read                                                                       '#13#10+
    '1:acquire(R,T)             # Acquire first object for reading; must succeed              '#13#10+
    '1:memaccess(R)             # Read must work                                              '#13#10+
    '1:memaccess(W)/E           # Write must fail                                             '#13#10+
    '1:acquire(R,T)             # Acquire first object for reading again; must succeed        '#13#10+
    '1:memaccess(R)             # Read must work                                              '#13#10+
    '1:memaccess(W)/E           # Write must fail                                             '#13#10+
    '2:acquire(W,F)             # Acquire second object for writing; must fail                '#13#10+
    '1:release                  # Release first object                                        '#13#10+
    '2:acquire(W,F)             # Acquire second object for writing; must fail                '#13#10+
    '1:release                  # Release first object                                        '#13#10+
    '2:acquire(W,T)             # Acquire second object for writing; must succeed             '#13#10+
    '2:memaccess(W)             # Write must work                                             '#13#10+
    '2:release                  # Release first object                                        '#13#10+
    '#  Read after write                                                                      '#13#10+
    '1:acquire(W,T)             # Acquire first object for writing; must succeed              '#13#10+
    '1:memaccess(R)             # Read must work                                              '#13#10+
    '1:memaccess(W)             # Write must work                                             '#13#10+
    '1:acquire(R,T)             # Acquire first object for reading; must succeed              '#13#10+
    '1:memaccess(R)             # Read must work                                              '#13#10+
    '1:memaccess(W)             # Write must work                                             '#13#10+
    '2:acquire(W,F)             # Acquire second object for writing; must fail                '#13#10+
    '1:release                  # Release first object                                        '#13#10+
    '2:acquire(W,F)             # Acquire second object for writing; must fail                '#13#10+
    '1:release                  # Release first object                                        '#13#10+
    '2:acquire(W,T)             # Acquire second object for writing; must succeed             '#13#10+
    '2:memaccess(W)             # Write must work                                             '#13#10+
    '2:release                  # Release first object                                        '#13#10+
    '#  Write after read                                                                      '#13#10+
    '1:acquire(R,T)             # Acquire first object for reading; must succeed              '#13#10+
    '1:memaccess(R)             # Read must work                                              '#13#10+
    '1:memaccess(W)/E           # Write must fail                                             '#13#10+
    '1:acquire(W,F)/E           # Acquire first object for writing; must fail with exception  '#13#10+
    '1:memaccess(R)             # Read must work                                              '#13#10+
    '1:memaccess(W)/E           # Write must work                                             '#13#10+
    '2:acquire(W,F)             # Acquire second object for writing; must fail                '#13#10+
    '1:release                  # Release first object                                        '#13#10+
    '1:release/E                # Release first object again; must fail                       '#13#10+
    '2:acquire(W,T)             # Acquire second object for writing; must succeed             '#13#10+
    '2:memaccess(W)             # Write must work                                             '#13#10+
    '2:release                  # Release first object                                        '#13#10+
    '1:destroy                  # Destroy first object                                        '#13#10+
    '2:destroy                  # Destroy second object                                       '
  );
end; { TGpTestSharedMemory.RunTest }

procedure TGpTestSharedMemory.RunTestSnapshot(testWriteAccess: boolean;
  testValue: cardinal);
begin
  assert(assigned(tsmMemory), 'object doesn''t exist');
  assert(assigned(tsmSnapshot), 'snapshot doesn''t exist');
  TestMemAccess(tsmSnapshot, testWriteAccess, testValue);
  TestStreamAccess(tsmSnapshot, testWriteAccess, testValue, false);
  TestStreamAccess(tsmSnapshot, testWriteAccess, testValue, true);
end; { TGpTestSharedMemory.RunTestSnapshot }

procedure TGpTestSharedMemory.RunTestStream(testWriteAccess: boolean;
  testValue: longword; readWritePastEnd: boolean);
begin
  assert(assigned(tsmMemory), 'object doesn''t exist');
  TestStreamAccess(tsmMemory, testWriteAccess, testValue, readWritePastEnd);
end; { TGpTestSharedMemory.RunTestStream }

procedure TGpTestSharedMemory.TestMemAccess(memory: TGpBaseSharedMemory;
  testWriteAccess: boolean; testValue: longword);
var
  int64Value: int64;
  intIdx    : integer;
  offset    : integer;
begin
  Int64Rec(int64Value).Lo := testValue;
  Int64Rec(int64Value).Hi := testValue;
  for intIdx := 0 to (memory.Size div SizeOf(integer))-1 do begin
    if testWriteAccess then begin
      case intIdx mod 4 of
        0  : memory.HugeIdx[intIdx div 2] := int64Value;
        2,3: memory.LongIdx[intIdx] := testValue;
      end; //case
      memory.WordIdx[2*intIdx] := LongRec(testValue).Lo;
      memory.ByteIdx[4*intIdx+1] := WordRec(LongRec(testValue).Lo).Hi;
    end
    else begin
      case intIdx mod 4 of
        0  : assertEQ(memory.HugeIdx[intIdx div 2], int64Value, 'invalid huge value stored at index '+IntToStr(intIdx div 2));
        2,3: assertEQ(memory.LongIdx[intIdx], testValue, 'invalid long value stored at index '+IntToStr(intIdx));
      end; //case
      assertEQ(memory.WordIdx[2*intIdx], LongRec(testValue).Lo, 'invalid word value stored at index '+IntToStr(2*intIdx));
      assertEQ(memory.ByteIdx[4*intIdx+1], WordRec(LongRec(testValue).Lo).Hi, 'invalid byte value stored at index '+IntToStr(4*intIdx+1));
    end;
  end; //for
  for intIdx := 0 to (memory.Size div SizeOf(integer))-1 do begin
    offset := intIdx*4;
    if testWriteAccess then begin
      case intIdx mod 4 of
        0  : memory.Huge[offset] := int64Value;
        2,3: memory.Long[offset] := testValue;
      end; //case
      memory.Word[offset] := LongRec(testValue).Lo;
      memory.Byte[offset+2] := WordRec(LongRec(testValue).Hi).Lo;
    end
    else begin
      case intIdx mod 4 of
        0  : assertEQ(memory.Huge[offset], int64Value, 'invalid huge value stored at offset '+IntToStr(offset));
        2,3: assertEQ(memory.Long[offset], testValue, 'invalid long value stored at offset '+IntToStr(offset));
      end; //case
      assertEQ(memory.Word[offset], LongRec(testValue).Lo, 'invalid word value stored at offset '+IntToStr(offset));
      assertEQ(memory.Byte[offset+2], WordRec(LongRec(testValue).Hi).Lo, 'invalid byte value stored at offset'+IntToStr(offset+2));
    end;
  end; //for
end; { TGpTestSharedMemory.TestMemAccess }

procedure TGpTestSharedMemory.TestStreamAccess(memory: TGpBaseSharedMemory;
  testWriteAccess: boolean; testValue: longword; readWritePastEnd: boolean);
var
  compValue: longword;
  intIdx   : integer;
  stream   : TGpSharedStream;
begin
  stream := memory.AsStream;
  stream.Position := 0;
  for intIdx := 0 to (stream.Size div SizeOf(testValue))-1 do begin
    assertEQ(stream.Position, intIdx*SizeOf(testValue), 'invalid stream position before access');
    if testWriteAccess then
      assertEQ(stream.Write(testValue, SizeOf(testValue)), SizeOf(testValue),
        'invalid number of bytes written; index = '+IntToStr(intIdx))
    else begin
      assertEQ(stream.Read(compValue, SizeOf(compValue)), SizeOf(compValue),
        'invalid number of bytes read; index = '+IntToStr(intIdx));
      assertEQ(compValue, testValue, 'invalid value stored at position '+IntToStr(stream.Position));
    end;
    assertEQ(stream.Position, intIdx*SizeOf(testValue)+SizeOf(testValue),
      'invalid stream position after access');
  end; //for
  if readWritePastEnd then
    if testWriteAccess then
      assertEQ(stream.Write(testValue, SizeOf(testValue)), SizeOf(testValue),
        'invalid number of bytes written')
    else
      assertEQ(stream.Read(compValue, SizeOf(compValue)),
        stream.Size mod SizeOf(testValue),
        'invalid number of bytes read');
end; { TGpTestSharedMemory.TestStreamAccess }

{ TGpTestSharedPool }

constructor TGpTestSharedPool.Create;
begin
  inherited;
  tspShmList := TList.Create;
end; { constructor TGpTestSharedPool.Create }

destructor TGpTestSharedPool.Destroy;
begin
  FreeAndNil(tspShmList);
  inherited
end; { TGpTestSharedPool.Destroy }

procedure TGpTestSharedPool.RunAcquire(timeout, expectedRetCode: integer);
var
  shm: TGpSharedMemory;
begin
  assert(assigned(tspPool), 'object doesn''t exists');
  shm := tspPool.AcquireBuffer(timeout);
  if assigned(shm) then
    tspShmList.Add(shm);
  assertEQ(Ord(tspPool.LastError), expectedRetCode, 'unexpected error code');
end; { TGpTestSharedPool.RunAcquire }

procedure TGpTestSharedPool.RunAcquireForeign;
var
  shm: TGpSharedMemory;
begin
  assert(assigned(tspPool), 'object doesn''t exists');
  shm := TGpSharedMemory.Create('test',512);
  shm.AcquireMemory(true,0);
  tspShmList.Add(shm);
end; { TGpTestSharedPool.RunAcquireForeign }

procedure TGpTestSharedPool.RunCommand;
begin
  if Command= 'create' then begin
    // (R|W) - create Reader or Writer
    // R:
    // <int> - expected result code
    // <int> - minimum buffer size
    // <int> - maximum buffer size
    // <int> - initial number of buffers
    // <int> - maximum number of buffers
    if UCParam(1)='W' then
      RunCreateWriter
    else
      RunCreateReader(IntParam(2), IntParam(3), IntParam(4), IntParam(5), IntParam(6));
  end
  else if Command = 'destroy' then
    RunDestroy
  else if Command = 'acquire' then
    RunAcquire(IntParam(1), IntParam(2))
  else if Command = 'release' then
    RunRelease
  else if Command = 'send' then
    RunSend(BoolParam(1))
  else if Command = 'sweep' then
    RunSweep
  else if Command = 'readdata' then
    RunReadData
  else if Command = 'acquireforeign' then
    RunAcquireForeign
  else
    Assert(false, 'unknown command');
end; { TGpTestSharedPool.RunCommand }

procedure TGpTestSharedPool.RunCreateReader(expectedRetCode, initialSize,
  maxSize, initialNumBuf, maxNumBuf: integer);
begin
  assert(not assigned(tspPool), 'object already exists');
  tspPool := TGpSharedPoolReader.Create('TEST_SP');
  (tspPool as TGpSharedPoolReader).Initialize(initialSize, maxSize, initialNumBuf, maxNumBuf);
  assert(assigned(tspPool), 'failed');
  assertEQ(Ord(tspPool.LastError), expectedRetCode, 'unexpected error code');
end; { TGpTestSharedPool.RunCreateReader }

procedure TGpTestSharedPool.RunCreateWriter;
begin
  assert(not assigned(tspPool), 'object already exists');
  tspPool := TGpSharedPoolWriter.Create('TEST_SP');
  assert(assigned(tspPool), 'failed');
  assertEQ(Ord(tspPool.LastError), 0, 'unexpected error code');
end; { TGpTestSharedPool.RunCreateWriter }

procedure TGpTestSharedPool.RunDestroy;
begin
  assert(assigned(tspPool), 'object doesn''t exist');
  FreeAndNil(tspPool);
  tspPool:= nil;
  assert(not assigned(tspPool), 'failed');
end; { TGpTestSharedPool.RunDestroy }

procedure TGpTestSharedPool.RunReadData;
var
  shm: TGpSharedMemory;
begin
  assert(assigned(tspPool), 'object doesn''t exists');
  assertEQ((tspPool as TGpSharedPoolReader).ReadData, true, 'failed');
  repeat
    shm := (tspPool as TGpSharedPoolReader).GetNextReceived;
    if assigned(shm) then
      tspPool.ReleaseBuffer(shm);
  until not assigned(shm);
end; { TGpTestSharedPool.RunReadData }

procedure TGpTestSharedPool.RunRelease;
var
  shm: TGpSharedMemory;
begin
  assert(assigned(tspPool), 'object doesn''t exists');
  assert(tspShmList.Count > 0, 'no buffers acquired');
  shm := TGpSharedMemory(tspShmList[tspShmList.Count-1]);
  tspShmList.Delete(tspShmList.Count-1);
  tspPool.ReleaseBuffer(shm);
end;

procedure TGpTestSharedPool.RunSend(expectedStatus: boolean);
var
  shm: TGpSharedMemory;
begin
  assert(assigned(tspPool), 'object doesn''t exists');
  assert(tspShmList.Count > 0, 'no buffers acquired');
  shm := TGpSharedMemory(tspShmList[tspShmList.Count-1]);
  tspShmList.Delete(tspShmList.Count-1);
  assertEQ(tspPool.SendBuffer(shm), expectedStatus, 'unexpected SendBuffer result');
end;

procedure TGpTestSharedPool.RunSweep;
begin
  assert(assigned(tspPool), 'object doesn''t exists');
  (tspPool as TGpSharedPoolReader).Sweep;
end;

function TGpTestSharedPool.RunTest: boolean;
begin
  Result := ExecuteScript(
    '#Creation and destruction                                                                '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+
    '1:create(W)                    # Create writer                                           '#13#10+
    '1:destroy                      # Destroy writer                                          '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '2:create(W)                    # Create writer                                           '#13#10+
    '2:destroy                      # Destroy writer                                          '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '2:create(W)                    # Create writer                                           '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+
    '2:destroy                      # Destroy writer                                          '#13#10+
    '2:create(W)                    # Create writer                                           '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+
    '2:destroy                      # Destroy writer                                          '#13#10+
    '2:create(W)                    # Create writer                                           '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '2:destroy                      # Destroy writer                                          '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '2:create(R,5,0,1024,2,4)       # Create second reader, must fail with speAlreadyActive   '#13#10+
    '2:destroy                      # Destroy second reader                                   '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '2:create(R,5,0,1024,2,4)       # Create second reader, must fail with speAlreadyActive   '#13#10+
    '2:destroy                      # Destroy second reader                                   '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+
    '2:create(R,0,0,1024,2,4)       # Create second reader                                    '#13#10+
    '2:destroy                      # Destroy second reader                                   '#13#10+
    '1:create(W)                    # Create writer                                           '#13#10+
    '2:create(W)                    # Create second writer                                    '#13#10+
    '2:destroy                      # Destroy second writer                                   '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+
    '1:create(W)                    # Create writer                                           '#13#10+
    '2:create(W)                    # Create second writer                                    '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+
    '2:destroy                      # Destroy second writer                                   '#13#10+

    '#Acquisition                                                                             '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '1:acquire(0,0)                 # Acquire without waiting, must succeed                   '#13#10+
    '1:release                      # Release                                                 '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+
    '1:create(W)                    # Create writer                                           '#13#10+
    '1:acquire(0,3)                 # Acquire, must fail with speNoReader                     '#13#10+
    '1:acquire(500,3)               # Acquire, must fail with speNoReader                     '#13#10+
    '1:destroy                      # Destroy writer                                          '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '2:create(W)                    # Create writer                                           '#13#10+
    '2:acquire(0,0)                 # Acquire, must succeed                                   '#13#10+
    '2:release                      # Release                                                 '#13#10+
    '2:destroy                      # Destroy writer                                          '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '2:create(W)                    # Create writer                                           '#13#10+
    '2:acquire(0,0)                 # Acquire in writer, must succeed                         '#13#10+
    '1:acquire(0,0)                 # Acquire in reader, must succeed                         '#13#10+
    '1:release                      # Release reader                                          '#13#10+
    '2:release                      # Release writer                                          '#13#10+
    '2:destroy                      # Destroy writer                                          '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '2:create(W)                    # Create writer                                           '#13#10+
    '1:acquire(0,0)                 # Acquire in reader, must succeed                         '#13#10+
    '2:acquire(0,0)                 # Acquire in writer, must succeed                         '#13#10+
    '2:release                      # Release writer                                          '#13#10+
    '2:destroy                      # Destroy writer                                          '#13#10+
    '1:release                      # Release reader                                          '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+

    '#Bug #1                                                                                  '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '1:acquire(0,0)                 # Acquire without waiting, must succeed                   '#13#10+
    '1:acquire(0,0)                 # Acquire again, must succeed                             '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+

    '#Bug #2                                                                                  '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '1:acquire(0,0)                 # Acquire without waiting, must succeed                   '#13#10+
    '1:acquire(0,0)                 # Acquire again, must succeed                             '#13#10+
    '1:send(T)                      # Send, must succeed                                      '#13#10+
    '1:send(T)                      # Send again                                              '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+

    '#Bug #3                                                                                  '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '1:acquire(0,0)                 # Acquire without waiting, must succeed                   '#13#10+
    '1:acquire(0,0)                 # Acquire again, must succeed                             '#13#10+
    '1:send(T)                      # Send, must succeed                                      '#13#10+
    '1:send(T)                      # Send again                                              '#13#10+
    '1:readdata                     # (read data)                                             '#13#10+
    '1:sweep                        # (sweep)                                                 '#13#10+
    '1:acquire(0,0)                 # Acquire without waiting, must succeed                   '#13#10+
    '1:acquire(0,0)                 # Acquire without waiting, must succeed                   '#13#10+
    '1:acquire(0,0)                 # Acquire without waiting, must succeed                   '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+

    '#Foreign buffers                                                                         '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '1:acquireForeign               # Acquire foreign buffer                                  '#13#10+
    '1:release                      # Release foreign buffer                                  '#13#10+
    '1:acquireForeign               # Acquire foreign buffer again                            '#13#10+
    '1:send(T)                      # Send, must succeed                                      '#13#10+
    '1:readdata                     # (read data)                                             '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+

    '#Reader restart                                                                          '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '2:create(W)                    # Create writer                                           '#13#10+
    '2:acquire(0,0)                 # Acquire without waiting, must succeed                   '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+
    '1:create(R,0,0,1024,2,4)       # Recreate reader                                         '#13#10+
    '2:send(T)                      # Send (buffer is now foreign), must succeed              '#13#10+
    '1:readdata                     # (read data)                                             '#13#10+
    '2:destroy                      # Destroy writer                                          '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10+

    '#Resizing                                                                                '#13#10+
    '1:create(R,0,0,1024,2,4)       # Create reader                                           '#13#10+
    '1:acquire(0,0)                 # Acquire; triggers resize                                '#13#10+
    '1:release                      # Release                                                 '#13#10+
    '1:sweep                        # Sweep; triggers resize                                  '#13#10+
    '1:acquire(0,0)                 # Acquire; triggers resize                                '#13#10+
    '1:acquire(0,0)                 # Acquire                                                 '#13#10+
    '1:acquire(0,0)                 # Acquire                                                 '#13#10+
    '1:acquire(0,0)                 # Acquire                                                 '#13#10+
    '1:destroy                      # Destroy reader                                          '#13#10
  );
end; { TGpTestSharedPool.RunTest }
{$ENDIF Testing}

var
  si: TSystemInfo;

initialization
  GetSystemInfo(si);
  CPageSize := si.dwPageSize;
end.

