{:Enhanced synchronisation primitives.
  @author Primoz Gabrijelcic
  @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2018, Primoz Gabrijelcic
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
  Creation date    : 2002-04-17
  Last modification: 2018-04-18
  Version          : 1.25a

  </pre>}{

  History:
    1.24a: 2018-04-18
      - Fixed pointer manipulation in 64-bit code.
    1.24: 2013-02-12
      - Implemented TGpMessageQueue.AsString.
    1.23a: 2013-01-20
      - Message queue count in TGpMessageQueue.Create is correctly initialized.
    1.23: 2010-04-23
       - Message queue works with Unicode Delphi, backwards compatible.
    1.22a: 2009-12-11
      - Unicode fixes.
    1.22: 2009-02-11
      - Implemented TGpSWMR.AttachToThread.
    1.21a: 2008-11-21
      - Added internal check to ensure that TGpSWMR.WaitToRead/WaitToWrite/Done are called
        from one thread only.
    1.21: 2008-07-02
      - Added optional external message counter to the message queue.
    1.20: 2007-01-04
      - New class TGpCircularBuffer.
    1.19a: 2006-10-24
      - Raise exception if caller tries to post a message that is larger than the message
        queue.
    1.19: 2006-05-30
      - Implemented AttachToThread.
    1.18: 2006-05-13
      - Added internal check to ensure that TGpMessageQueueReader.GetMessage is called
        from one thread only.
    1.17: 2004-11-03
      - Added readonly property TGpMessageQueue.Size.
    1.16: 2004-06-20
      - Logs message queue calls and internals if compiled with LogGpMessageQueue
        conditional define.
    1.15: 2004-02-10
      - Added classes TGpCounter and TGpCounterList. 
      - Fixed memory leak in TGpMessageQueueReaderThread. TGpMessageQueueReader leaked one
        thread handle on Destroy.
    1.14: 2003-09-16
      - Added function TGpMessageQueue.BytesFree.
    1.13a: 2003-05-22
      - Fixed typo mqpQueueEmpty -> mqgQueueEmpty.
    1.13: 2002-12-13
      - Added TGpFlag class.
    1.12: 2002-12-08
      - Added overloaded version of TGpToken.GenerateToken.
    1.11: 2002-12-01
      - Added method TGpMessageQueueWriter.IsReaderAlive.
    1.10: 2002-11-09
      - Moved posting functionality from TGpMessageQueueWriter to
        TGpMessageQueue so that Reader can post to itself.
    1.09: 2002-10-23
      - Added TGpMessageQueueReader and TGpMessageQueueWriter classes.
    1.08: 2002-10-16
      - Changed protection on all kernel primitives to 'allow everyone' (needed
        to work with services).
      - wasLastMember parameter was not set correctly in TGroup.Leave if object
        has Joined more than once.
    1.07: 2002-10-02
      - All string constants moved into resourcestring section.
    1.06a: 2002-09-25
      - Fixed bugs in TGpCountedGroupList.Extract and TGpSWMRList.Extract.
    1.06: 2002-08-30
      - TGpGroup modified to allow nested Join/Leave calls.
    1.05: 2002-07-16
      - Global function GenerateToken changed into class function of the
        TGpToken class.
      - Class function TGpToken.IsValidToken renamed to IsTokenPublished.
    1.04: 2002-06-28
      - Added corresponding *List classes for all public classes.
      - Fixed bug in TGpToken.Revoke.
    1.03: 2002-06-10
      - Added function GenerateToken.
    1.02: 2002-05-14
      - Added TGpToken class.
      - Added TGpSWMR class.
    1.01: 2002-05-09
      - TGpGroup renamed to TGpCountedGroup. Created safer TGpGroup. Reason:
        Win32 doesn't update a semaphore count if its owner dies and that makes
        TGpCountedGroup slightly less safe than the TGpGroup.
    1.0a: 2002-05-01
      - Safer NumMembers and Leave methods.
    1.0: 2002-04-18
      - Released.
}

unit GpSync;

interface

uses
  Windows,
  SysUtils,
  DSiWin32,
  {$IFDEF LogGpMessageQueue}
  GpLogger,
  {$ENDIF LogGpMessageQueue}
  Classes,
  Contnrs;

// TODO 1 -oPrimoz Gabrijelcic: Implement safe counted group (using shared memory and tokens)
// TODO 1 -oPrimoz Gabrijelcic: Implement waitable versions (background thread?)
// TODO 1 -oPrimoz Gabrijelcic: Implement WaitForMultipleExpressions

type
  {:Flag with a user-chosen name that is automatically cleared if process dies.
    Uses a mutex with the user-chose name. Two processes cannot set the same
    flag - use a TGpGroup to cover that case.
  }
  TGpFlag = class
  private
    gfMutex       : THandle{CreateMutex};
    gfCreateFailed: boolean;
    gfFlagName    : string;
  protected
    function GetIsSet: boolean; virtual;
  public
    class function IsFlagSet(const flagName: string): boolean;
    constructor Create(const flagName: string);
    destructor  Destroy; override;
    procedure ClearFlag;
    function  SetFlag: boolean;
    property CreateFailed: boolean read gfCreateFailed;
    property FlagName: string read gfFlagName;
    property IsSet: boolean read GetIsSet;
  end; { TGpFlag }

  {:A list of TGpFlag objects.
  }
  TGpFlagList = class(TObjectList)
  protected
    function  GetItem(idx: integer): TGpFlag;
    procedure SetItem(idx: integer; const Value: TGpFlag);
  public
    function  Add(gpFlag: TGpFlag): integer; reintroduce;
    function  AddNew(const flagName: string): TGpFlag;
    function  Extract(gpFlag: TGpFlag): TGpFlag; reintroduce;
    function  IndexOf(gpFlag: TGpFlag): integer; reintroduce;
    procedure Insert(idx: integer; gpFlag: TGpFlag); reintroduce;
    function  Remove(gpFlag: TGpFlag): integer; reintroduce;
    property Items[idx: integer]: TGpFlag read GetItem write SetItem; default;
  end; { TGpFlagList }

  {:Token with a unique name that is automatically revoked if process dies.
    Uses a mutex with name [CGpTokenPrefix]+[generated GUID].
  }
  TGpToken = class
  private
    gtToken    : THandle{CreateMutex};
    gtTokenName: string;
  public
    class function IsTokenPublished(token: string): boolean;
    class function GenerateToken: string; overload;
    class function GenerateToken(withPrefix: string): string; overload;
    constructor Create; overload;
    constructor Create(withPrefix: string); overload;
    destructor  Destroy; override;
    function  IsPublished: boolean;
    procedure Publish; //called automatically from constructor
    procedure Revoke; //called automatically from destructor
    property Token: string read gtTokenName;
  end; { TGpToken }

  {:A list of TGpToken objects.
  }
  TGpTokenList = class(TObjectList)
  protected
    function  GetItem(idx: integer): TGpToken;
    procedure SetItem(idx: integer; const Value: TGpToken);
  public
    function  Add(gpToken: TGpToken): integer; reintroduce;
    function  AddNew: TGpToken;
    function  Extract(gpToken: TGpToken): TGpToken; reintroduce;
    function  IndexOf(gpToken: TGpToken): integer; reintroduce;
    procedure Insert(idx: integer; gpToken: TGpToken); reintroduce;
    function  Remove(gpToken: TGpToken): integer; reintroduce;
    property Items[idx: integer]: TGpToken read GetItem write SetItem; default;
  end; { TGpTokenList }

  {:Counter with a unique name and synchronized access. Can count from
    -(High(integer) div 2) to +(High(integer) div 2).
    Uses a semaphore with name [counterName]$SEM$Counter.
  }
  TGpCounter = class
  private
    gcCounter: THandle{CreateSemaphore};
    gcName   : string;
  protected
    function SemaphoreToCounter(semValue: integer): integer;
    function CounterToSemaphore(cntValue: integer): integer;
  public
    class procedure Decrement(const counterName: string; decrement: integer = 1);
    class procedure Increment(const counterName: string; increment: integer = 1);
    constructor Create(counterName: string; initialValue: integer = 0); overload;
    destructor  Destroy; override;
    procedure Dec(decrement: integer = 1);
    procedure Inc(increment: integer = 1);
    function  Value: integer;
    property Name: string read gcName;
  end; { TGpCounter }

  {:A list of TGpCounter objects.
  }
  TGpCounterList = class(TObjectList)
  protected
    function  GetItem(idx: integer): TGpCounter;
    procedure SetItem(idx: integer; const Value: TGpCounter);
  public
    function  Add(gpCounter: TGpCounter): integer; reintroduce;
    function  AddNew(counterName: string; initialValue: integer = 0): TGpCounter;
    function  Extract(gpCounter: TGpCounter): TGpCounter; reintroduce;
    function  IndexOf(gpCounter: TGpCounter): integer; reintroduce;
    procedure Insert(idx: integer; gpCounter: TGpCounter); reintroduce;
    function  Remove(gpCounter: TGpCounter): integer; reintroduce;
    property Items[idx: integer]: TGpCounter read GetItem write SetItem; default;
  end; { TGpCounterList }

  {:A safe group without member counting. If process terminates abnormally,
    it will automatically leave the group. Process can enter the group only
    once.
    Uses two mutexes with names [groupName]$MTX$Sync and [groupName]$MTX$Member.
  }
  TGpGroup = class
  private
    grMemberMutex: THandle{CreateMutex};
    grName       : string;
    grSyncMutex  : THandle{CreateMutex};
    grTimesMember: integer;
  protected
    function  MemberMutexName: string;
  public
    constructor Create(groupName: string); reintroduce;
    destructor  Destroy; override;
    function  IsEmpty: boolean;
    function  IsMember: boolean;
    procedure Join(var isFirstMember: boolean); overload;
    procedure Join; overload;
    procedure Leave(var wasLastMember: boolean); overload;
    procedure Leave; overload;
    property Name: string read grName;
  end; { TGpGroup }

  {:A list of TGpGroup objects.
  }
  TGpGroupList = class(TObjectList)
  protected
    function  GetItem(idx: integer): TGpGroup;
    procedure SetItem(idx: integer; const Value: TGpGroup);
  public
    function  Add(gpGroup: TGpGroup): integer; reintroduce;
    function  AddNew(groupName: string): TGpGroup;
    function  Extract(gpGroup: TGpGroup): TGpGroup; reintroduce;
    function  IndexOf(gpGroup: TGpGroup): integer; reintroduce;
    procedure Insert(idx: integer; gpGroup: TGpGroup); reintroduce;
    function  Remove(gpGroup: TGpGroup): integer; reintroduce;
    property Items[idx: integer]: TGpGroup read GetItem write SetItem; default;
  end; { TGpGroupList }

  {:An unsafe group with member counting. If process terminates abnormally (due
    to a TerminateThread od TerminateProcess or simply because owner fails to
    call the Leave method), it will _not_ automatically leave the group. Process
    can enter the group more than once.
    Uses semaphore with name [groupName]$SEM and mutex with name
    [groupName]$MTX.
  }
  TGpCountedGroup = class
  private
    cgrMaxMembers : integer;
    cgrMutex      : THandle{CreateMutex};
    cgrName       : string;
    cgrSemaphore  : THandle{CreateSemaphore};
    cgrTimesMember: integer;
  protected
    function  UnprotectedNumMembers: integer;
  public
    constructor Create(groupName: string; memberLimit: integer = MaxInt); reintroduce;
    destructor  Destroy; override;
    function  IsEmpty: boolean;
    function  IsMember: boolean;
    function  Join(timeout: DWORD; var isFirstMember: boolean): boolean; overload;
    function  Join(timeout: DWORD): boolean; overload;
    procedure Leave(var wasLastMember: boolean); overload;
    procedure Leave; overload;
    function  NumMembers: integer;
    property MemberLimit: integer read cgrMaxMembers;
    property Name: string read cgrName;
  end; { TGpCountedGroup }

  {:A list of TGpCountedGroup objects.
  }
  TGpCountedGroupList = class(TObjectList)
  protected
    function  GetItem(idx: integer): TGpCountedGroup;
    procedure SetItem(idx: integer; const Value: TGpCountedGroup);
  public
    function  Add(gpCountedGroup: TGpCountedGroup): integer; reintroduce;
    function  AddNew(groupName: string; memberLimit: integer = MaxInt): TGpCountedGroup;
    function  Extract(gpCountedGroup: TGpCountedGroup): TGpCountedGroup; reintroduce;
    function  IndexOf(gpCountedGroup: TGpCountedGroup): integer; reintroduce;
    procedure Insert(idx: integer; gpCountedGroup: TGpCountedGroup); reintroduce;
    function  Remove(gpCountedGroup: TGpCountedGroup): integer; reintroduce;
    property Items[idx: integer]: TGpCountedGroup read GetItem write SetItem; default;
  end; { TGpCountedGroupList }

  TGpSWMRAccess = (swmrAccNone, swmrAccRead, swmrAccWrite);

  {:Single Writer, Multiple Readers. Adapted from the book "Advanced Windows"
    (3rd edition) by Jeffrey Richter, pg. 369.
    Uses semaphore with name [swmrName]$SEM, mutex with name [swmrName]$MTX, and
    event with name [swmrName]$EVT.
    Unnamed (inter-process) use is _not_ supported. Use
    TJclMultiReadExclusiveWrite from JEDI Code Library (JCL) instead.
    Allows nested locking (Write over Write, Read over Read, Read over Write).
    Read lock cannot be upgraded to the Write lock.
    Each successfull lock must be matched by a call to the Done method.
  }
  TGpSWMR = class
  private
    gwrAccess        : TGpSWMRAccess;
    gwrEventNoReaders: THandle;
    gwrMutexNoWriter : THandle;
    gwrName          : string;
    gwrOwningThread  : DWORD;
    gwrSemNumReaders : THandle;
    gwrTimesMember   : integer;
  protected
    procedure CheckOwner(const methodName: string);
    procedure DoneReading; virtual;
    procedure DoneWriting; virtual;
  public
    constructor Create(swmrName: string);
    destructor  Destroy; override;
    procedure AttachToThread;
    procedure Done; virtual;
    function  WaitToRead(timeout: DWORD): boolean; virtual;  // true if allowed
    function  WaitToWrite(timeout: DWORD): boolean; virtual; // true if allowed
    property Access: TGpSWMRAccess read gwrAccess;
    property Name: string read gwrName;
  end; { TGpSWMR }

  {:A list of TGpSWMR objects.
  }
  TGpSWMRList = class(TObjectList)
  protected
    function  GetItem(idx: integer): TGpSWMR;
    procedure SetItem(idx: integer; const Value: TGpSWMR);
  public
    function  Add(gpSWMR: TGpSWMR): integer; reintroduce;
    function  AddNew(swmrName: string): TGpSWMR;
    function  Extract(gpSWMR: TGpSWMR): TGpSWMR; reintroduce;
    function  IndexOf(gpSWMR: TGpSWMR): integer; reintroduce;
    procedure Insert(idx: integer; gpSWMR: TGpSWMR); reintroduce;
    function  Remove(gpSWMR: TGpSWMR): integer; reintroduce;
    property Items[idx: integer]: TGpSWMR read GetItem write SetItem; default;
  end; { TGpSWMRList }

  {:All possible parts of a message.
    @enum mqfHasMsg    Message contains 'msg: UINT' part.
    @enum mqfHasWParam Message contains 'wParam: WPARAM' part.
    @enum mqfHasLParam Message contains 'lParam: LPARAM' part.
    @enum mqfHasData   Message contains 'msgData: string' part.
  }
  TGpMQMessageFlag = (mqfHasMsg, mqfHasWParam, mqfHasLParam, mqfHasData);

  {:Flags describing one message.
  }
  TGpMQMessageFlags = set of TGpMQMessageFlag;

  {:Possible return values for message retrieving.
    @enum    mqgOK         Message was retrieved.
    @enum    mqgTimeout    Queue cannot be acquired.
    @enum    mqgQueueEmpty Queue is empty.
    @enum    mqgSkipped    Message was skipped because it contained fields that
                           called didn't want to retrieve.
    @since   2002-10-23
  }
  TGpMQGetStatus = (mqgOK, mqgTimeout, mqgQueueEmpty, mqgSkipped);

  {:All possible return values for message posting.
    @enum    mqpOK        Message was posted.
    @enum    mqpTimeout   Queue cannot be acquired.
    @enum    mqpQueueFull Queue is full.
    @since   2002-10-23
  }
  TGpMQPostStatus = (mqpOK, mqpTimeout, mqpQueueFull);

  {:Semi-abstract message queue implementation that can send messages across
    desktops (for example from interactive process to the service running in
    LocalSystem account).
    Message queue is implemented as a ring buffer with two pointers - one
    pointing to the first message, the other pointing to the free space. If
    they are pointing to the same location, the buffer is empty.
    Do not use directly. Use TGpMessageQueueReader and TGpMessageQueueWriter
    instead.
    Uses shared memory [message queue name]$MessageQueueShm and event
    [message queue name]$NewMessageEvt.
    @since   2002-10-22
  }
  TGpMessageQueue = {abstract} class
  private
    mqInitMutex   : THandle{CreateMutex};
    mqMessageCount: PCardinal;
    mqMessageQueue: TObject; // actually, TGpSharedMemory, but to declare it here would create cyclic reference
    mqName        : AnsiString;
    mqNewMessage  : THandle{CreateEvent};
    mqSize        : cardinal;
    {$IFDEF LogGpMessageQueue}
    mqLogger      : IGpLogger;
    {$ENDIF LogGpMessageQueue}
  protected
    constructor Create(messageQueueName: AnsiString; messageQueueSize: cardinal;
      queueMessageCount: PCardinal = nil); virtual;
    function  AppendMessage(flags: TGpMQMessageFlags; msg: UINT; wParam: WPARAM;
      lParam: LPARAM; const msgData: AnsiString): TGpMQPostStatus;
    procedure Cleanup; virtual; abstract;
    procedure Initialize; virtual; abstract;
    function  InternalBytesFree: cardinal;
    function  IsEmpty: boolean;
    function  ReaderMutexName: AnsiString;
    function  RetrieveMessage(removeFromQueue: boolean; var flags: TGpMQMessageFlags;
      var msg: UINT; var wParam: WPARAM; var lParam: LPARAM;
      var msgData: AnsiString): TGpMQGetStatus;
    procedure WrappedRetrieve(var buf; bufLen: cardinal);
    procedure WrappedStore(const buf; bufLen: cardinal);
    property InitializationMtx: THandle{CreateMutex} read mqInitMutex;
    property MQ: TObject read mqMessageQueue;
    property NewMessageEvt: THandle{CreateEvent} read mqNewMessage;
  public
    destructor  Destroy; override;
    function  AsString(timeout: DWORD): string;
    procedure AttachToThread; virtual;
    function  BytesFree(timeout: DWORD): cardinal;
    function  PostMessage(timeout: DWORD; const msgData: AnsiString): TGpMQPostStatus;
      overload;
    function  PostMessage(timeout: DWORD; flags: TGpMQMessageFlags; msg: UINT; wParam: WPARAM;
      lParam: LPARAM; const msgData: AnsiString): TGpMQPostStatus; overload;
    function  PostMessage(timeout: DWORD; msg: UINT; const msgData: AnsiString):
      TGpMQPostStatus; overload;
    function  PostMessage(timeout: DWORD; msg: UINT; wParam: WPARAM;
      lParam: LPARAM): TGpMQPostStatus; overload;
    property Name: AnsiString read mqName;
    property Size: cardinal read mqSize;
  end; { TGpMessageQueue }

  {:Message queue reader attaches to the message queue and reads messages. There
    can only be one reader attached to one message queue.
    Uses mutex [message queue name]$SingleReaderMtx.
    @since   2002-10-22
  }
  TGpMessageQueueReader = class(TGpMessageQueue)
  private
    mqrNewMessageEvent       : THandle{CreateEvent};
    mqrNewMessageMessage     : UINT;
    mqrNewMessageWindowHandle: HWND;
    mqrOwningThread          : DWORD;
    mqrReaderThread          : TThread;
    mqrSingleReader          : THandle{CreateMutex};
  protected
    procedure Cleanup; override;
    procedure Initialize; override;
  public
    constructor Create(messageQueueName: AnsiString; messageQueueSize: cardinal;
      newMessageEvent: THandle{CreateEvent}; queueMessageCount: PCardinal = nil);
      reintroduce; overload;
    constructor Create(messageQueueName: AnsiString; messageQueueSize: cardinal;
      newMessageWindowHandle: HWND; newMessageMessage: UINT; queueMessageCount: PCardinal =
      nil); reintroduce; overload;
    procedure AttachToThread; override;
    function  GetMessage(timeout: DWORD; var flags: TGpMQMessageFlags; var msg: UINT; var
      wParam: WPARAM; var lParam: LPARAM; var msgData: AnsiString): TGpMQGetStatus; overload;
    function  GetMessage(timeout: DWORD; var msg: UINT; var msgData: AnsiString):
      TGpMQGetStatus; overload;
    function  GetMessage(timeout: DWORD; var msg: UINT; var wParam: WPARAM;
      var lParam: LPARAM): TGpMQGetStatus; overload;
    function  GetMessage(timeout: DWORD; var msgData: AnsiString): TGpMQGetStatus; overload;
    function  PeekMessage(timeout: DWORD; var flags: TGpMQMessageFlags; var msg: UINT; var
      wParam: WPARAM; var lParam: LPARAM; var msgData: AnsiString): TGpMQGetStatus; overload;
    function  PeekMessage(timeout: DWORD; var msg: UINT; var msgData: AnsiString):
      TGpMQGetStatus; overload;
    function  PeekMessage(timeout: DWORD; var msg: UINT; var wParam: WPARAM;
      var lParam: LPARAM): TGpMQGetStatus; overload;
    function  PeekMessage(timeout: DWORD; var msgData: AnsiString): TGpMQGetStatus; overload;
  end; { TGpMessageQueueReader }

  {:Message queue writer attaches to the message queue and writes messages.
    There can be more than one writer attached to one message queue.
    @since   2002-10-22
  }
  TGpMessageQueueWriter = class(TGpMessageQueue)
  protected
    procedure Cleanup; override;
    procedure Initialize; override;
  public
    constructor Create(messageQueueName: AnsiString; messageQueueSize: cardinal;
      queueMessageCount: PCardinal = nil); override;
    function  IsReaderAlive: boolean;
  end; { TGpMessageQueueWriter }

  TGpMessageQueueList = class(TObjectList)
  protected
    function  GetItem(idx: integer): TGpMessageQueue;
    procedure SetItem(idx: integer; const Value: TGpMessageQueue);
  public
    function  Add(gpMessageQueue: TGpMessageQueue): integer; reintroduce;
    function AddNewReader(messageQueueName: AnsiString; messageQueueSize: cardinal):
      TGpMessageQueue;
    function  AddNewWriter(messageQueueName: AnsiString; messageQueueSize: cardinal):
      TGpMessageQueue;
    function  Extract(gpMessageQueue: TGpMessageQueue): TGpMessageQueue; reintroduce;
    function  IndexOf(gpMessageQueue: TGpMessageQueue): integer; reintroduce;
    procedure Insert(idx: integer; gpMessageQueue: TGpMessageQueue); reintroduce;
    function  Remove(gpMessageQueue: TGpMessageQueue): integer; reintroduce;
    property Items[idx: integer]: TGpMessageQueue read GetItem write SetItem; default;
  end; { TGpMessageQueueList }

  {:A circular buffer of pointers. One instance of this class can be shared between one
    reader and one writer. A semaphore is used for synchronisation. Writes can
    automatically wait on empty place if buffer is full. Reads can automatically wait
    on data if buffer is empty.
    @since   2007-01-03
  }
  TGpCircularBuffer = class
  private
    cbBuffer    : array of pointer;
    cbDataCount : TDSiSemaphoreHandle;
    cbEmptyCount: TDSiSemaphoreHandle;
    cbHead      : integer;
    cbTail      : integer;
  protected
    procedure WrapIncrement(var bufferPointer: integer);
  public
    constructor Create(bufferSize: integer);
    destructor  Destroy; override;
    function  Dequeue(timeout_ms: DWORD = 0): pointer;
    function  DequeueAllocated: pointer;
    function  Enqueue(const buffer: pointer; timeout_ms: DWORD = 0): boolean;
    function  EnqueueAllocated(const buffer: pointer): boolean;
    property AllocateRead: TDSiSemaphoreHandle read cbDataCount;
    property AllocateWrite: TDSiSemaphoreHandle read cbEmptyCount;
  end; { TGpCircularBuffer }

  {:Class for exceptions thrown in this unit.
  }
  EGpSync = class(Exception);

implementation

uses
  {$IF CompilerVersion >= 26}
  System.Types,
  {$IFEND}
  ComObj,
  ActiveX,
  {$IFDEF Unicode}
  AnsiStrings,
  {$ENDIF}
  GpSecurity,
  GpSharedMemory;

resourcestring
  sAlreadyJoined            = 'Already a member: %s';
  sAlreadyPublished         = 'Already published: %s';
  sAlreadyReadlocked        = 'Already locked for read access: %s';
  sAlreadySet               = 'Already set: %s';
  sInvalidFlag              = 'Invalid flag name: %s';
  sInvalidToken             = 'Invalid token name: %s';
  sNameNotSet               = 'Name is not set';
  sNotJoined                = 'Not a member: %s';
  sNotLocked                = 'Not locked: %s';
  sNotPublished             = 'Not published: %s';
  sQueueReaderAlreadyExists = 'Another reader for message queue %s already exists';
  sTokenAlreadyExists       = 'Token with this name already exists: %s';

const
  Hex_Chars: array [0..15] of char = '0123456789ABCDEF';

type
  TGpMessageQueueReaderThread = class(TThread)
  private
    mqrtNewMessageEvt     : THandle{CreateEvent};
    mqrtNotifyEvent       : THandle{CreateEvent};
    mqrtNotifyMessage     : UINT;
    mqrtNotifyWindowHandle: HWND;
    mqrtParent            : TGpMessageQueueReader;
    mqrtTerminateEvt      : THandle{CreateEvent};
  public
    constructor Create(newMessageEvent: THandle{CreateEvent};
      notifyEvent: THandle{CreateEvent}; notifyWindowHandle: HWND;
      notifyMessage: UINT; parent: TGpMessageQueueReader);
    destructor  Destroy; override;
    procedure Execute; override;
    procedure Terminate;
  end; { TGpMessageQueueReaderThread }

function IFF(condition: boolean; const value1, value2: string): string;
begin
  if condition then
    Result := value1
  else
    Result := value2;
end; { IFF }

{:Offset pointer by specified ammount.
}        
function Ofs(p: pointer; offset: NativeUInt): pointer;
begin
  Result := pointer(NativeUInt(p)+offset);
end; { Ofs }

function HexStr (var num; byteCount: Longint): string;
var
  i   : integer;
  pB  : PByte;
  pRes: PChar;
  res : string;
begin
  pB := @num;
  SetLength(res, 2*byteCount);
  if byteCount > 1 then 
    Inc(pB, byteCount-1);
  pRes := @res[1];
  for i := byteCount downto 1 do begin
    pRes^ := char(Hex_Chars[pB^ div 16]); Inc(pRes);
    pRes^ := char(Hex_Chars[pB^ mod 16]); Inc(pRes);
    dec (pB);
  end;
  Result := res;
end; { HexStr }

{ TGpFlag }

procedure TGpFlag.ClearFlag;
begin
  if IsSet then begin
    DSiCloseHandleAndNull(gfMutex);
  end;
end; { TGpFlag.ClearFlag }

{:Create and set the flag.
  @since   2002-12-13
}
constructor TGpFlag.Create(const flagName: string);
begin
  gfFlagName := flagName;
  gfCreateFailed := not SetFlag;
end; { TGpFlag.Create }

destructor TGpFlag.Destroy;
begin
  ClearFlag;
  inherited;
end; { TGpFlag.Destroy }

function TGpFlag.GetIsSet: boolean;
begin
  Result := (gfMutex <> 0);
end; { TGpFlag.GetIsSet }

class function TGpFlag.IsFlagSet(const flagName: string): boolean;
var
  flag: TGpFlag;
begin
  flag := TGpFlag.Create(flagName);
  try
    Result := flag.CreateFailed;
  finally FreeAndNil(flag); end;
end; { TGpFlag.IsFlagSet }

function TGpFlag.SetFlag: boolean;
begin
  Result := false;
  gfMutex := CreateMutex_AllowEveryone(false, gfFlagName);
  if gfMutex = 0 then
    raise EGpSync.CreateFmt(sInvalidFlag, [gfFlagName])
  else begin
    if GetLastError = NO_ERROR then
      Result := true
    else 
      DSiCloseHandleAndNull(gfMutex);
  end;
end; { TGpFlag.SetFlag }

{ TGpFlagList }

function TGpFlagList.Add(gpFlag: TGpFlag): integer;
begin
  Result := inherited Add(gpFlag);
end; { TGpFlagList.Add }

function TGpFlagList.AddNew(const flagName: string): TGpFlag;
begin
  Result := TGpFlag.Create(flagName);
  if Result.CreateFailed then
    FreeAndNil(Result)
  else
    Add(Result);
end; { TGpFlagList.AddNew }

function TGpFlagList.Extract(gpFlag: TGpFlag): TGpFlag;
begin
  Result := TGpFlag(inherited Extract(gpFlag));
end; { TGpFlagList.Extract }

function TGpFlagList.GetItem(idx: integer): TGpFlag;
begin
  Result := (inherited GetItem(idx)) as TGpFlag;
end; { TGpFlagList.GetItem }

function TGpFlagList.IndexOf(gpFlag: TGpFlag): integer;
begin
  Result := inherited IndexOf(gpFlag);
end; { TGpFlagList.IndexOf }

procedure TGpFlagList.Insert(idx: integer; gpFlag: TGpFlag);
begin
  inherited Insert(idx, gpFlag);
end; { TGpFlagList.Insert }

function TGpFlagList.Remove(gpFlag: TGpFlag): integer;
begin
  Result := inherited Remove(gpFlag);
end; { TGpFlagList.Remove }

procedure TGpFlagList.SetItem(idx: integer; const Value: TGpFlag);
begin
  inherited SetItem(idx, Value);
end; { TGpFlagList.SetItem }

{ TGpToken }

const
  CGpTokenPrefix = 'Gp/GpToken/04DC5A63-86AA-4439-8E9D-BC75C276968E/';

{:Create a token that is unique for this computer, then publish it.
  @since   2002-05-13
}
constructor TGpToken.Create;
begin
  Create(CGpTokenPrefix);
end; { TGpToken.Create }

{:Create a token with a custom prefix, then publish it.
  @since   2002-05-13
}
constructor TGpToken.Create(withPrefix: string);
var
  guid: TGUID;
begin
  CoCreateGuid(guid);
  gtTokenName := GUIDToString(guid);
  gtTokenName := withPrefix + Copy(gtTokenName, 2, Length(gtTokenName)-2);
  Publish;
end; { TGpToken.Create }

{:Revoke the token (if needed), then destroy the object.
  @since   2002-05-13
}
destructor TGpToken.Destroy;
begin
  if IsPublished then
    Revoke;
  inherited;
end; { TGpToken.Destroy }

{:Generate unique token string.
  @since   2002-07-16
}
class function TGpToken.GenerateToken: string;
begin
  with TGpToken.Create do begin
    Result := Token;
    Free;
  end; //with
end; { TGpToken.GenerateToken }

{:Generate unique token string with a custom prefix.
  @since   2002-12-08
}        
class function TGpToken.GenerateToken(withPrefix: string): string;
begin
  with TGpToken.Create(withPrefix) do begin
    Result := Token;
    Free;
  end; //with
end; { TGpToken.GenerateToken }

function TGpToken.IsPublished: boolean;
begin
  Result := (gtToken <> 0);
end; { TGpToken.IsPublished }

{:Check whether the token is still valid (was not revoked - automatically or
  manually).
  @since   2002-05-13
}
class function TGpToken.IsTokenPublished(token: string): boolean;
var
  testToken: THandle{CreateMutex};
begin
  testToken := CreateMutex_AllowEveryone(false, PChar(token));
  if testToken = 0 then
    raise EGpSync.CreateFmt(sInvalidToken, [token])
  else begin
    try
      Result := (GetLastError = ERROR_ALREADY_EXISTS);
    finally
      if not CloseHandle(testToken) then
        RaiseLastOSError;
    end;
  end;
end; { TGpToken.IsTokenPublished }

{:Publish auto-revokable token.
}
procedure TGpToken.Publish;
begin
  if IsPublished then
    raise EGpSync.CreateFmt(sAlreadyPublished, [Token]);
  gtToken := CreateMutex_AllowEveryone(false, PChar(Token));
  if gtToken = 0 then
    RaiseLastOSError
  else if GetLastError = ERROR_ALREADY_EXISTS then begin
    DSiCloseHandleAndNull(gtToken);
    raise EGpSync.CreateFmt(sTokenAlreadyExists, [Token]);
  end;
end; { TGpToken.Publish }

{:Revoke the token.
}
procedure TGpToken.Revoke;
begin
  if not IsPublished then
    raise EGpSync.CreateFmt(sNotPublished, [Token]);
  DSiCloseHandleAndNull(gtToken);
end; { TGpToken.Revoke }

{ TGpTokenList }

function TGpTokenList.Add(gpToken: TGpToken): integer;
begin
  Result := inherited Add(gpToken);
end; { TGpTokenList.Add }

function TGpTokenList.AddNew: TGpToken;
begin
  Result := TGpToken.Create;
  Add(Result);
end; { TGpTokenList.AddNew }

function TGpTokenList.Extract(gpToken: TGpToken): TGpToken;
begin
  Result := TGpToken(inherited Extract(gpToken));
end; { TGpTokenList.Extract }

function TGpTokenList.GetItem(idx: integer): TGpToken;
begin
  Result := (inherited GetItem(idx)) as TGpToken;
end; { TGpTokenList.GetItem }

function TGpTokenList.IndexOf(gpToken: TGpToken): integer;
begin
  Result := inherited IndexOf(gpToken);
end; { TGpTokenList.IndexOf }

procedure TGpTokenList.Insert(idx: integer; gpToken: TGpToken);
begin
  inherited Insert(idx, gpToken);
end; { TGpTokenList.Insert }

function TGpTokenList.Remove(gpToken: TGpToken): integer;
begin
  Result := inherited Remove(gpToken);
end; { TGpTokenList.Remove }

procedure TGpTokenList.SetItem(idx: integer; const Value: TGpToken);
begin
  inherited SetItem(idx, Value);
end; { TGpTokenList.SetItem }

{ TGpCounter }

const
  CGpCounterZero = High(integer) div 2;

function TGpCounter.CounterToSemaphore(cntValue: integer): integer;
begin
  Result := cntValue + CGpCounterZero;
end; { TGpCounter.CounterToSemaphore }

{:TGpCounter constructor. Creates a semaphore with name [counterName]$SEM$Counter 2and
  [groupName]$MTX$Member.
  @param   counterName  Name of the counter. Can be empty.
  @param   initialValue Initial value for the counter. Will only be used if counter
                        doesn't already exist.
  @since   2004-02-10
}
constructor TGpCounter.Create(counterName: string; initialValue: integer);
begin
  inherited Create;
  gcName := counterName;
  if counterName <> '' then
    counterName := counterName + '$SEM$Counter';
  gcCounter := CreateSemaphore_AllowEveryone(CounterToSemaphore(initialValue),
    High(integer), counterName);
  if gcCounter = 0 then
    RaiseLastOSError;
end; { TGpCounter.Create }

{:Decrements the counter.
  @since   2004-02-10
}        
procedure TGpCounter.Dec(decrement: integer);
var
  iDec: integer;
begin
  if CounterToSemaphore(Value) < decrement then
    raise Exception.CreateFmt('Counter underflow: %s', [Name]);
  for iDec := 1 to decrement do
    WaitForSingleObject(gcCounter, 0);
end; { TGpCounter.Dec }

class procedure TGpCounter.Decrement(const counterName: string;
  decrement: integer);
var
  counter: TGpCounter;
begin
  counter := TGpCounter.Create(counterName);
  try
    counter.Dec(decrement);
  finally counter.Free; end;
end; { TGpCounter.Decrement }

destructor TGpCounter.Destroy;
begin
  DSiCloseHandleAndNull(gcCounter);
  inherited;
end; { TGpCounter.Destroy }

{:Increments the counter.
  @since   2004-02-10
}
procedure TGpCounter.Inc(increment: integer);
begin
  if CounterToSemaphore(Value) > (High(integer)-increment) then
    raise Exception.CreateFmt('Counter overflow: %s', [Name]);
  ReleaseSemaphore(gcCounter, increment, nil);
end; { TGpCounter.Inc }

class procedure TGpCounter.Increment(const counterName: string;
  increment: integer);
var
  counter: TGpCounter;
begin
  counter := TGpCounter.Create(counterName);
  try
    counter.Inc(increment);
  finally counter.Free; end;
end; { TGpCounter.Increment }

function TGpCounter.SemaphoreToCounter(semValue: integer): integer;
begin
  Result := semValue - CGpCounterZero;
end; { TGpCounter.SemaphoreToCounter }

{:Returns current counter value.
  @since   2004-02-10
}
function TGpCounter.Value: integer;
begin
  if WaitForSingleObject(gcCounter, 0) <> WAIT_OBJECT_0 then //program dying or counter underflow
    Result := SemaphoreToCounter(0)
  else begin
    ReleaseSemaphore(gcCounter, 1, @Result);
    Result := SemaphoreToCounter(Result) + 1;
  end;
end; { TGpCounter.Value }

{ TGpCounterList }

function TGpCounterList.Add(gpCounter: TGpCounter): integer;
begin
  Result := inherited Add(gpCounter);
end; { TGpCounterList.Add }

function TGpCounterList.AddNew(counterName: string; initialValue: integer): TGpCounter;
begin
  Result := TGpCounter.Create(counterName, initialValue);
  Add(Result);
end; { TGpCounterList.AddNew }

function TGpCounterList.Extract(gpCounter: TGpCounter): TGpCounter;
begin
  Result := TGpCounter(inherited Extract(gpCounter));
end; { TGpCounterList.Extract }

function TGpCounterList.GetItem(idx: integer): TGpCounter;
begin
  Result := (inherited GetItem(idx)) as TGpCounter;
end; { TGpCounterList.GetItem }

function TGpCounterList.IndexOf(gpCounter: TGpCounter): integer;
begin
  Result := inherited IndexOf(gpCounter);
end; { TGpCounterList.IndexOf }

procedure TGpCounterList.Insert(idx: integer; gpCounter: TGpCounter);
begin
  inherited Insert(idx, gpCounter);
end; { TGpCounterList.Insert }

function TGpCounterList.Remove(gpCounter: TGpCounter): integer;
begin
  Result := inherited Remove(gpCounter);
end; { TGpCounterList.Remove }

procedure TGpCounterList.SetItem(idx: integer; const Value: TGpCounter);
begin
  inherited SetItem(idx, Value);
end; { TGpCounterList.SetItem }

{ TGpGroup }

{:TGpGroup constructor. Creates two mutexes with names [groupName]$MTX$Sync and
  [groupName]$MTX$Member.
  @param   Name of the group. Must not be empty.
}
constructor TGpGroup.Create(groupName: string);
begin
  if Trim(groupName) = '' then
    raise EGpSync.Create(sNameNotSet);
  grName := groupName;
  grSyncMutex := CreateMutex_AllowEveryone(false, PChar(groupName+'$MTX$Sync'));
  if grSyncMutex = 0 then
    RaiseLastOSError;
end; { TGpGroup.Create }

{:TGpGroup destructor. Leaves the group before destroying it.
}
destructor TGpGroup.Destroy;
begin
  while IsMember do
    Leave;
  DSiCloseHandleAndNull(grMemberMutex);
  DSiCloseHandleAndNull(grSyncMutex);
  inherited;
end; { TGpGroup.Destroy }

function TGpGroup.IsEmpty: boolean;
begin
  Result := false;
  if not IsMember then begin
    WaitForSingleObject(grSyncMutex, INFINITE);
    try
      grMemberMutex := CreateMutex_AllowEveryone(false, PChar(MemberMutexName));
      if grMemberMutex = 0 then
        RaiseLastOSError
      else begin
        Result := (GetLastError = 0);
        DSiCloseHandleAndNull(grMemberMutex);
      end;
    finally ReleaseMutex(grSyncMutex); end;
  end;
end; { TGpGroup.IsEmpty }

function TGpGroup.IsMember: boolean;
begin
  Result := (grTimesMember > 0);
end; { TGpGroup.IsMember }

procedure TGpGroup.Join(var isFirstMember: boolean);
begin
  if not IsMember then begin
    WaitForSingleObject(grSyncMutex, INFINITE);
    try
      grMemberMutex := CreateMutex_AllowEveryone(false, PChar(MemberMutexName));
      if grMemberMutex = 0 then
        RaiseLastOSError
      else begin
        isFirstMember := (GetLastError = 0);
      end;
    finally ReleaseMutex(grSyncMutex); end;
  end;
  Inc(grTimesMember);
end; { TGpGroup.Join }

procedure TGpGroup.Join; 
var
  isFirstMember: boolean;
begin
  Join(isFirstMember);
end; { TGpGroup.Join }

procedure TGpGroup.Leave(var wasLastMember: boolean);
begin
  if not IsMember then
    raise EGpSync.CreateFmt(sNotJoined, [Name]);
  Dec(grTimesMember);
  if grTimesMember > 0 then
    wasLastMember := false
  else begin
    WaitForSingleObject(grSyncMutex, INFINITE);
    try
      CloseHandle(grMemberMutex);
      grMemberMutex := CreateMutex_AllowEveryone(false, PChar(MemberMutexName));
      if grMemberMutex = 0 then
        RaiseLastOSError
      else begin
        wasLastMember := (GetLastError = 0);
        DSiCloseHandleAndNull(grMemberMutex);
      end;
    finally ReleaseMutex(grSyncMutex); end;
  end;
end; { TGpGroup.Leave }

procedure TGpGroup.Leave;
var
  wasLastMember: boolean;
begin
  Leave(wasLastMember);
end; { TGpGroup.Leave }

function TGpGroup.MemberMutexName: string;
begin
  Result := Name+'$MTX$Member';
end; { TGpGroup.MemberMutexName }

{ TGpGroupList }

function TGpGroupList.Add(gpGroup: TGpGroup): integer;
begin
  Result := inherited Add(gpGroup);
end; { TGpGroupList.Add }

function TGpGroupList.AddNew(groupName: string): TGpGroup;
begin
  Result := TGpGroup.Create(groupName);
  Add(Result);
end; { TGpGroupList.AddNew }

function TGpGroupList.Extract(gpGroup: TGpGroup): TGpGroup;
begin
  Result := TGpGroup(inherited Extract(gpGroup));
end; { TGpGroupList.Extract }

function TGpGroupList.GetItem(idx: integer): TGpGroup;
begin
  Result := (inherited GetItem(idx)) as TGpGroup;
end; { TGpGroupList.GetItem }

function TGpGroupList.IndexOf(gpGroup: TGpGroup): integer;
begin
  Result := inherited IndexOf(gpGroup);
end; { TGpGroupList.IndexOf }

procedure TGpGroupList.Insert(idx: integer; gpGroup: TGpGroup);
begin
  inherited Insert(idx, gpGroup);
end; { TGpGroupList.Insert }

function TGpGroupList.Remove(gpGroup: TGpGroup): integer;
begin
  Result := inherited Remove(gpGroup);
end; { TGpGroupList.Remove }

procedure TGpGroupList.SetItem(idx: integer; const Value: TGpGroup);
begin
  inherited SetItem(idx, Value);
end; { TGpGroupList.SetItem }

{ TGpCountedGroup }

{:TGpCountedGroup constructor. Creates semaphore with name [groupName]$SEM and
  mutex with name [groupName]$MTX.
  @param   Name of the group. Must not be empty.
}
constructor TGpCountedGroup.Create(groupName: string; memberLimit: integer);
begin
  if Trim(groupName) = '' then
    raise EGpSync.Create(sNameNotSet);
  cgrName := groupName;
  cgrMaxMembers := memberLimit;
  cgrSemaphore := CreateSemaphore_AllowEveryone(MemberLimit, MemberLimit, PChar(groupName+'$SEM'));
  if cgrSemaphore = 0 then
    RaiseLastOSError;
  cgrMutex := CreateMutex_AllowEveryone(false, PChar(groupName+'$MTX'));
  if cgrMutex = 0 then
    RaiseLastOSError;
end; { TGpCountedGroup.Create }

{:TGpCountedGroup destructor. Leaves the group before destroying it.
}
destructor TGpCountedGroup.Destroy;
begin
  while IsMember do
    Leave;
  DSiCloseHandleAndNull(cgrMutex);
  DSiCloseHandleAndNull(cgrSemaphore);
  inherited;
end; { TGpCountedGroup.Destroy }

{:Checks whether the groop is empty. Can be called from non-members, too.
}        
function TGpCountedGroup.IsEmpty: boolean;
begin
  Result := (NumMembers = 0);
end; { TGpCountedGroup.IsEmpty }

{:Checks if the owner belongs to group.
}
function TGpCountedGroup.IsMember: boolean;
begin
  Result := (cgrTimesMember > 0);
end; { TGpCountedGroup.IsMember }

{:Joins the group and returns status indicating if this is the first process
  in the group.
  @param   timeout       Timeout in milliseconds. 0 and INFINITE are supported.
  @param   isFirstMember (out) Set to true if this is first member of the
                         group. Defined only if function returns true.
  @returns False if process failed to enter the group because it is full.
  @raises  EWin32Error on unexpected Windows error.
}
function TGpCountedGroup.Join(timeout: DWORD; var isFirstMember: boolean): boolean;
var
  handles: array [0..1] of THandle;
  waitRes: DWORD;
begin
  handles[0] := cgrSemaphore;
  handles[1] := cgrMutex;
  waitRes := WaitForMultipleObjects(2,@handles,true,timeout);
  if (waitRes <> WAIT_OBJECT_0) and (waitRes <> (WAIT_OBJECT_0+1)) then
    Result := false
  else begin
    try
      Inc(cgrTimesMember);
      isFirstMember := (UnprotectedNumMembers = (MemberLimit-1));
    finally
      if not ReleaseMutex(cgrMutex) then
        RaiseLastOSError; { this really shouldn't happen }
    end;
    Result := true;
  end;
end; { TGpCountedGroup.Join }

function TGpCountedGroup.Join(timeout: DWORD): boolean; 
var
  isFirstMember: boolean;
begin
  Result := Join(timeout,isFirstMember);
end; { TGpCountedGroup.Join }

{:Leaves the group.
  @param   wasLastMember (out) Set to true if this was last process in the
                         group.
}
procedure TGpCountedGroup.Leave(var wasLastMember: boolean);
var
  memberCount  : integer;
  shouldRelease: boolean;
begin
  if not IsMember then
    raise EGpSync.CreateFmt(SNotJoined,[Name]);
  Dec(cgrTimesMember);
  shouldRelease := (WaitForSingleObject(cgrMutex, INFINITE) = WAIT_OBJECT_0);
  try
    if not ReleaseSemaphore(cgrSemaphore,1,@memberCount) then
      RaiseLastOSError; { this really shouldn't happen }
  finally
    if shouldRelease then
      if not ReleaseMutex(cgrMutex) then
        RaiseLastOSError; { this really shouldn't happen }
  end;
  wasLastMember := (memberCount = (MemberLimit-1));
end; { TGpCountedGroup.Leave }

procedure TGpCountedGroup.Leave;
var
  wasLastMember: boolean;
begin
  Leave(wasLastMember);
end; { TGpCountedGroup.Leave }

{:Returns number of group members. Can be called from non-members, too.
  @raises EWin32Error on unexpected Windows error.
}
function TGpCountedGroup.NumMembers: integer;
begin
  if WaitForSingleObject(cgrMutex, INFINITE) <> WAIT_OBJECT_0 then
    Result := MemberLimit // error, report group full
  else begin
    try
      Result := UnprotectedNumMembers;
    finally
      if not ReleaseMutex(cgrMutex) then
        RaiseLastOSError; { this really shouldn't happen }
    end;
  end;
end; { TGpCountedGroup.NumMembers }

{:Internal function that returns number of members without access protection.
  Expects to be called form the wrapper that already implemented access
  protection.
  @since   2002-05-01
}
function TGpCountedGroup.UnprotectedNumMembers: integer;
var
  memberCount: integer;
begin
  if WaitForSingleObject(cgrSemaphore,0) <> WAIT_OBJECT_0 then
    Result := MemberLimit
  else begin
    if not ReleaseSemaphore(cgrSemaphore,1,@memberCount) then
      RaiseLastOSError; { this really shouldn't happen }
    Result := (MemberLimit - (memberCount+1));
  end;
end; { TGpCountedGroup.UnprotectedNumMembers }

{ TGpCountedGroupList }

function TGpCountedGroupList.Add(gpCountedGroup: TGpCountedGroup): integer;
begin
  Result := inherited Add(gpCountedGroup);
end; { TGpCountedGroupList.Add }

function TGpCountedGroupList.AddNew(groupName: string;
  memberLimit: integer): TGpCountedGroup;
begin
  Result := TGpCountedGroup.Create(groupName, memberLimit);
  Add(Result);
end; { TGpCountedGroupList.AddNew }

function TGpCountedGroupList.Extract(
  gpCountedGroup: TGpCountedGroup): TGpCountedGroup;
begin
  Result := TGpCountedGroup(inherited Extract(gpCountedGroup));
end; { TGpCountedGroupList.Extract }

function TGpCountedGroupList.GetItem(idx: integer): TGpCountedGroup;
begin
  Result := (inherited GetItem(idx)) as TGpCountedGroup;
end; { TGpCountedGroupList.GetItem }

function TGpCountedGroupList.IndexOf(gpCountedGroup: TGpCountedGroup): integer;
begin
  Result := inherited IndexOf(gpCountedGroup);
end; { TGpCountedGroupList.IndexOf }

procedure TGpCountedGroupList.Insert(idx: integer;
  gpCountedGroup: TGpCountedGroup);
begin
  inherited Insert(idx, gpCountedGroup);
end; { TGpCountedGroupList.Insert }

function TGpCountedGroupList.Remove(gpCountedGroup: TGpCountedGroup): integer;
begin
  Result := inherited Remove(gpCountedGroup);
end; { TGpCountedGroupList.Remove }

procedure TGpCountedGroupList.SetItem(idx: integer;
  const Value: TGpCountedGroup);
begin
  inherited SetItem(idx, Value);
end; { TGpCountedGroupList.SetItem }

{ TGpSWMR }

constructor TGpSWMR.Create(swmrName: string);
begin
  inherited Create;
  if Trim(swmrName) = '' then
    raise EGpSync.Create(sNameNotSet);
  gwrAccess := swmrAccNone;
  gwrName   := swmrName;
  gwrMutexNoWriter := 0;
  gwrEventNoReaders:= 0;
  gwrSemNumReaders := 0;
  gwrMutexNoWriter := CreateMutex_AllowEveryone(false, PChar(swmrName+'$MTX'));
  if gwrMutexNoWriter = 0 then
    RaiseLastOSError;
  gwrEventNoReaders:= CreateEvent_AllowEveryone(true, true, PChar(swmrName+'$EVT'));
  if gwrEventNoReaders = 0 then
    RaiseLastOSError;
  gwrSemNumReaders := CreateSemaphore_AllowEveryone(0, MaxLongint, PChar(swmrName+'$SEM'));
  if gwrSemNumReaders = 0 then
    RaiseLastOSError;
end; { TGpSWMR.Create }

destructor TGpSWMR.Destroy;
begin
  while Access <> swmrAccNone do
    Done;
  DSiCloseHandleAndNull(gwrMutexNoWriter);
  DSiCloseHandleAndNull(gwrEventNoReaders);
  DSiCloseHandleAndNull(gwrSemNumReaders);
  inherited;
end; { TGpSWMR.Destroy }

procedure TGpSWMR.AttachToThread;
begin
  gwrOwningThread := GetCurrentThreadID;
end; { TGpSWMR.AttachToThread }

procedure TGpSWMR.CheckOwner(const methodName: string);
begin
  if gwrOwningThread = 0 then
    gwrOwningThread := GetCurrentThreadID
  else if gwrOwningThread <> GetCurrentThreadID then
    raise Exception.CreateFmt(
      'TGpSWMR<%s>.%s called from two threads: %d and %d',
      [Name, methodName, gwrOwningThread, GetCurrentThreadID]);
end; { TGpSWMR.CheckOwner }

procedure TGpSWMR.Done;
begin
  CheckOwner('Done');
  if gwrTimesMember <= 0 then
    raise EGpSync.CreateFmt(sNotLocked, [Name])
  else begin
    if gwrTimesMember = 1 then begin
      case Access of
        swmrAccRead : DoneReading;
        swmrAccWrite: DoneWriting;
      end; //case
    end;
    Dec(gwrTimesMember);
  end;
end; { TGpSWMR.Done }

procedure TGpSWMR.DoneReading;
var
  handles: array [1..2] of THandle;
begin
  handles[1] := gwrMutexNoWriter;
  handles[2] := gwrSemNumReaders;
  WaitForMultipleObjects(2, @handles, true, INFINITE);
  if WaitForSingleObject(gwrSemNumReaders, 0) = WAIT_TIMEOUT then
    SetEvent(gwrEventNoReaders) // last reader
  else
    ReleaseSemaphore(gwrSemNumReaders, 1, nil);
  ReleaseMutex(gwrMutexNoWriter);
  gwrAccess := swmrAccNone;
end; { TGpSWMR.DoneReading }

procedure TGpSWMR.DoneWriting;
begin
  ReleaseMutex(gwrMutexNoWriter);
  gwrAccess := swmrAccNone;
end; { TGpSWMR.DoneWriting }

function TGpSWMR.WaitToRead(timeout: DWORD): boolean;
var
  prevCount: longint;
begin
  CheckOwner('WaitToRead');
  if gwrTimesMember > 0 then
    Result := true
  else if WaitForSingleObject(gwrMutexNoWriter, timeout) <> WAIT_TIMEOUT then begin
    ReleaseSemaphore(gwrSemNumReaders, 1, @prevCount);
    if prevCount = 0 then
      ResetEvent(gwrEventNoReaders);
    ReleaseMutex(gwrMutexNoWriter);
    Result := true;
  end
  else
    Result := false;
  if Result then begin
    if gwrTimesMember = 0 then
      gwrAccess := swmrAccRead;
    Inc(gwrTimesMember);
  end
  else
    gwrAccess := swmrAccNone;
end; { TGpSWMR.WaitToRead }

function TGpSWMR.WaitToWrite(timeout: DWORD): boolean;
var
  handles: array [1..2] of THandle;
begin
  CheckOwner('WaitToWrite');
  if gwrAccess = swmrAccRead then
    raise EGpSync.CreateFmt(sAlreadyReadlocked, [Name])
  else if gwrTimesMember > 0 then
    Result := true
  else begin
    handles[1] := gwrMutexNoWriter;
    handles[2] := gwrEventNoReaders;
    Result := (WaitForMultipleObjects(2, @handles, true, timeout) <> WAIT_TIMEOUT);
  end;
  if Result then begin
    if gwrTimesMember = 0 then
      gwrAccess := swmrAccWrite;
    Inc(gwrTimesMember);
  end
  else
    gwrAccess := swmrAccNone;
end; { TGpSWMR.WaitToWrite }

{ TGpSWMRList }

function TGpSWMRList.Add(gpSWMR: TGpSWMR): integer;
begin
  Result := inherited Add(gpSWMR);
end; { TGpSWMRList.Add }

function TGpSWMRList.AddNew(swmrName: string): TGpSWMR;
begin
  Result := TGpSWMR.Create(swmrName);
  Add(Result);
end; { TGpSWMRList.AddNew }

function TGpSWMRList.Extract(gpSWMR: TGpSWMR): TGpSWMR;
begin
  Result := TGpSWMR(inherited Extract(gpSWMR));
end; { TGpSWMRList.Extract }

function TGpSWMRList.GetItem(idx: integer): TGpSWMR;
begin
  Result := (inherited GetItem(idx)) as TGpSWMR;
end; { TGpSWMRList.GetItem }

function TGpSWMRList.IndexOf(gpSWMR: TGpSWMR): integer;
begin
  Result := inherited IndexOf(gpSWMR);
end; { TGpSWMRList.IndexOf }

procedure TGpSWMRList.Insert(idx: integer; gpSWMR: TGpSWMR);
begin
  inherited Insert(idx, gpSWMR);
end; { TGpSWMRList.Insert }

function TGpSWMRList.Remove(gpSWMR: TGpSWMR): integer;
begin
  Result := inherited Remove(gpSWMR);
end; { TGpSWMRList.Remove }

procedure TGpSWMRList.SetItem(idx: integer; const Value: TGpSWMR);
begin
  inherited SetItem(idx, Value);
end; { TGpSWMRList.SetItem }

{ TGpMessageQueue }

const
  CGpMQDataIdx = 0;
  CGpMQFreeIdx = 1;

  CGpMQHeaderSize = SizeOf(longword) + SizeOf(longword);

function Shm(mq: TObject): TGpSharedMemory;
begin
  Result := (mq as TGpSharedMemory);
end; { Shm }

{:Append message to the message queue. Message queue must already be acquired.
  @returns False if there is not enough place for message in message queue.
  @since   2002-10-22
}
function TGpMessageQueue.AppendMessage(flags: TGpMQMessageFlags; msg: UINT;
  wParam: WPARAM; lParam: LPARAM; const msgData: AnsiString): TGpMQPostStatus;
var
  dataLen  : integer;
  flagsInt : byte;
  totalSize: cardinal;
begin
  totalSize := 1;
  if mqfHasMsg in flags then
    Inc(totalSize, SizeOf(UINT));
  if mqfHasWParam in flags then
    Inc(totalSize, SizeOf(WPARAM));
  if mqfHasLParam in flags then
    Inc(totalSize, SizeOf(LPARAM));
  if mqfHasData in flags then
    Inc(totalSize, 4+Length(msgData)*SizeOf(AnsiChar));
  if totalSize >= Size then
    raise EGpSync.CreateFmt('TGpMessageQueue.AppendMessage[%s]: Trying to send message ' +
      'of length %d, which is larger than the queue size %d', [Name, totalSize, Size])
  else if InternalBytesFree <= totalSize then
    Result := mqpQueueFull
  else begin
    flagsInt := PByte(@flags)^;
    WrappedStore(flagsInt, 1);
    if mqfHasMsg in flags then
      WrappedStore(msg, SizeOf(UINT));
    if mqfHasWParam in flags then
      WrappedStore(wParam, SizeOf(WPARAM));
    if mqfHasLParam in flags then
      WrappedStore(lParam, SizeOf(LPARAM));
    if mqfHasData in flags then begin
      dataLen := Length(msgData)*SizeOf(AnsiChar);
      WrappedStore(dataLen, SizeOf(dataLen));
      if dataLen > 0 then
        WrappedStore(msgData[1], dataLen);
    end;
    Result := mqpOK;
  end;
end; { TGpMessageQueue.AppendMessage }

{:Returns number of free bytes in the queue. If queue cannot be acquired in
  timeout milliseconds, returns cardinal(-1).
}
function TGpMessageQueue.BytesFree(timeout: DWORD): cardinal;
begin
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]:=> BytesFree; %d', [mqName, timeout]);
  try try
  {$ENDIF LogGpMessageQueue}
  if Shm(MQ).AcquireMemory(false, timeout) = nil then
    Result := cardinal(-1)
  else try
    Result := InternalBytesFree;
  finally Shm(MQ).ReleaseMemory; end;
  {$IFDEF LogGpMessageQueue}
  except on E: Exception do begin mqLogger.Log('mq[%s]: Exception %s', [mqName, E.Message]); raise; end; end;
  finally mqLogger.Log('mq[%s]:<= BytesFree, Result = %d', [mqName, Result]); end;
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueue.BytesFree }

{:Create message queue object.
  @param   messageQueueName Base name for various primitives used.
  @param   messageQueueSize Maximum size of the shared memory used to store
                            message queue data.
                            Messages are stored as:
                              flag:byte[msg:UINT][wParam:WPARAM][lParam:LPARAM][Length(msgData)/DWORD msgData/chars]
                            msgData message uses 5 + Length(msgData) bytes
                            msg/msgData message uses 9 + Length(msgData) bytes
                            msg/wParam/lParam message uses 13 bytes
  @since   2002-10-22
}
constructor TGpMessageQueue.Create(messageQueueName: AnsiString; messageQueueSize:
  cardinal; queueMessageCount: PCardinal = nil);
begin
  {$IFDEF LogGpMessageQueue}
  mqLogger := CreateGpLogger(ExtractFilePath(ParamStr(0))+'MessageQueue.log');
  mqLogger.Log('Creating message queue %s/%d', [messageQueueName, messageQueueSize]);
  {$ENDIF LogGpMessageQueue}
  if Trim(messageQueueName) = '' then
    raise EGpSync.Create(sNameNotSet);
  mqName := messageQueueName;
  // If shared memory is created in next call, it will be initialized to 0.
  // Data and tail pointer will both be 0 meaning that message queue will be
  // considered empty.
  mqMessageQueue := TGpSharedMemory.Create(string(Name+'$MessageQueueShm'),
    messageQueueSize + SizeOf(longword) {head pointer} + SizeOf(longword) {tail pointer} + 1 {keep buffer from filling up},
    0);
  mqMessageCount := queueMessageCount;
  mqSize := Shm(mqMessageQueue).Size;
  mqNewMessage := CreateEvent_AllowEveryone(false, false, string(Name+'$NewMessageEvt'));
  if mqNewMessage = 0 then
    RaiseLastOSError;
  mqInitMutex := CreateMutex_AllowEveryone(false, string(Name+'$InitializationMtx'));
  if mqInitMutex = 0 then
    RaiseLastOSError;
  try
    Initialize;
  except
    Cleanup;
    raise;
  end;
end; { TGpMessageQueue.Create }

{:Destroy message queue object.
  @since   2002-10-22
}
destructor TGpMessageQueue.Destroy;
begin
  Cleanup;
  DSiCloseHandleAndNull(mqNewMessage);
  DSiCloseHandleAndNull(mqInitMutex);
  FreeAndNil(mqMessageQueue);
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('Message queue %s destroyed', [mqName]);
  {$ENDIF LogGpMessageQueue}
  inherited;
end; { TGpMessageQueue.Destroy }

function TGpMessageQueue.AsString(timeout: DWORD): string;
begin
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]:=> AsString');
  try try
  {$ENDIF LogGpMessageQueue}
  if Shm(MQ).AcquireMemory(true, timeout) = nil then
    Result := 'timeout'
  else begin
    try
      Result := HexStr(Shm(MQ).DataPointer^, Shm(MQ).Size);
    finally Shm(MQ).ReleaseMemory; end;
  end;
  {$IFDEF LogGpMessageQueue}
  except on E: Exception do begin mqLogger.Log('mq[%s]: Exception %s', [mqName, E.Message]); raise; end; end;
  finally mqLogger.Log('mq[%s]:<= AsString, Result = %s', [mqName, Result]); end;
  {$ENDIF LogGpMessageQueue}
end;

procedure TGpMessageQueue.AttachToThread;
begin
  Shm(MQ).AttachToThread;
end; { TGpMessageQueue.AttachToThread }

{:Returns number of free bytes in the queue. Queue must already be acquired.
  @since   2002-10-22
}
function TGpMessageQueue.InternalBytesFree: cardinal;
var
  ptrData: longword;
  ptrFree: longword;
begin
  ptrData := Shm(MQ).LongIdx[CGpMQDataIdx];
  ptrFree := Shm(MQ).LongIdx[CGpMQFreeIdx];
  if ptrData > ptrFree then
    Result := ptrData-ptrFree
  else
    Result := ptrData+Shm(MQ).Size-ptrFree - CGpMQHeaderSize;
end; { TGpMessageQueue.InternalBytesFree }

{:Check if queue is empty. Queue must already be acquired.
  @since   2002-10-23
}
function TGpMessageQueue.IsEmpty: boolean;
begin
  Result := (Shm(MQ).LongIdx[CGpMQDataIdx] = Shm(MQ).LongIdx[CGpMQFreeIdx]);
end; { TGpMessageQueue.IsEmpty }

{:Post message into message queue.
  @since   2002-10-22
}
function TGpMessageQueue.PostMessage(timeout: DWORD; flags: TGpMQMessageFlags; msg: UINT;
  wParam: WPARAM; lParam: LPARAM; const msgData: AnsiString): TGpMQPostStatus;
begin
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]:=> PostMessage; %d/%d/%d/%d/%d/%s', [mqName, timeout, byte(flags), msg, wParam, lParam, msgData]);
  try try
  {$ENDIF LogGpMessageQueue}
  if Shm(MQ).AcquireMemory(true, timeout) = nil then 
    Result := mqpTimeout
  else begin
    try
      Result := AppendMessage(flags, msg, wParam, lParam, msgData);
      if Result = mqpOK then begin
        if assigned(mqMessageCount) then
          mqMessageCount^ := mqMessageCount^ + 1;
        if not SetEvent(NewMessageEvt) then
          ;
      end;
    finally Shm(MQ).ReleaseMemory; end;
  end;
  {$IFDEF LogGpMessageQueue}
  except on E: Exception do begin mqLogger.Log('mq[%s]: Exception %s', [mqName, E.Message]); raise; end; end;
  finally mqLogger.Log('mq[%s]:<= PostMessage, Result = %d', [mqName, Ord(Result)]); end;
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueue.PostMessage }

{:Post message into message queue.
  @since   2002-10-22
}
function TGpMessageQueue.PostMessage(timeout: DWORD; const msgData: AnsiString):
  TGpMQPostStatus;
begin
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]:=> PostMessage; %d/%s', [mqName, timeout, msgData]);
  try try
  {$ENDIF LogGpMessageQueue}
  Result := PostMessage(timeout, [mqfHasData], 0, 0, 0, msgData);
  {$IFDEF LogGpMessageQueue}
  except on E: Exception do begin mqLogger.Log('mq[%s]: Exception %s', [mqName, E.Message]); raise; end; end;
  finally mqLogger.Log('mq[%s]:<= PostMessage, Result = %d', [mqName, Ord(Result)]); end;
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueue.PostMessage }

{:Post message into message queue.
  @since   2002-10-22
}
function TGpMessageQueue.PostMessage(timeout: DWORD; msg: UINT;
  wParam: WPARAM; lParam: LPARAM): TGpMQPostStatus;
begin
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]:=> PostMessage; %d/%d/%d/%d', [mqName, timeout, msg, wParam, lParam]);
  try try
  {$ENDIF LogGpMessageQueue}
  Result := PostMessage(timeout,
    [mqfHasMsg, mqfHasWParam, mqfHasLParam], msg, wParam, lParam, '');
  {$IFDEF LogGpMessageQueue}
  except on E: Exception do begin mqLogger.Log('mq[%s]: Exception %s', [mqName, E.Message]); raise; end; end;
  finally mqLogger.Log('mq[%s]:<= PostMessage, Result = %d', [mqName, Ord(Result)]); end;
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueue.PostMessage }

{:Post message into message queue.
  @since   2002-10-22
}
function TGpMessageQueue.PostMessage(timeout: DWORD; msg: UINT; const msgData:
  AnsiString): TGpMQPostStatus;
begin
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]:=> PostMessage; %d/%d/%s', [mqName, timeout, msg, msgData]);
  try try
  {$ENDIF LogGpMessageQueue}
  Result := PostMessage(timeout, [mqfHasMsg, mqfHasData], msg, 0, 0, msgData);
  {$IFDEF LogGpMessageQueue}
  except on E: Exception do begin mqLogger.Log('mq[%s]: Exception %s', [mqName, E.Message]); raise; end; end;
  finally mqLogger.Log('mq[%s]:<= PostMessage, Result = %d', [mqName, Ord(Result)]); end;
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueue.PostMessage }

{:Return name of the reader's mutex.
  @since   2002-12-01
}
function TGpMessageQueue.ReaderMutexName: AnsiString;
begin
  Result := Name+'$SingleReaderMtx';
end; { TGpMessageQueue.ReaderMutexName }

{:Retrieve data from the message queue and optionally move Data pointer to the
  next message.
  @since   2002-10-23
}
function TGpMessageQueue.RetrieveMessage(removeFromQueue: boolean;
  var flags: TGpMQMessageFlags; var msg: UINT; var wParam: WPARAM; var lParam: LPARAM;
  var msgData: AnsiString): TGpMQGetStatus;
var
  dataLen   : integer;
  flagsInt  : byte;
  oldDataIdx: longword;
begin
  if IsEmpty then
    Result := mqgQueueEmpty
  else begin
    oldDataIdx := Shm(MQ).LongIdx[CGpMQDataIdx];
    WrappedRetrieve(flagsInt, 1);
    PByte(@flags)^ := flagsInt;
    if mqfHasMsg in flags then
      WrappedRetrieve(msg, SizeOf(UINT));
    if mqfHasWParam in flags then
      WrappedRetrieve(wParam, SizeOf(WPARAM));
    if mqfHasLParam in flags then
      WrappedRetrieve(lParam, SizeOf(LPARAM));
    if mqfHasData in flags then begin
      dataLen := Length(msgData);
      WrappedRetrieve(dataLen, SizeOf(dataLen));
      SetLength(msgData, dataLen div SizeOf(AnsiChar));
      if dataLen > 0 then
        WrappedRetrieve(msgData[1], dataLen);
    end;
    if not removeFromQueue then
      Shm(MQ).LongIdx[CGpMQDataIdx] := oldDataIdx
    else if assigned(mqMessageCount) then
      mqMessageCount^ := mqMessageCount^ - 1;
    Result := mqgOK;
  end;
end; { TGpMessageQueue.RetrieveMessage }

{:Retrieve data from message queue buffer. Wrap at the end. Buffer has already
  been acquired.
  @since   2002-10-22
}
procedure TGpMessageQueue.WrappedRetrieve(var buf; bufLen: cardinal);
var
  bufOffs : cardinal;
  dataLeft: cardinal;
  dataPtr : longword;
begin
  dataPtr := Shm(MQ).LongIdx[CGpMQDataIdx] + CGpMQHeaderSize;
  dataLeft := mqSize - dataPtr;
  bufOffs := 0;
  if dataLeft <= bufLen then begin
    Move(Shm(MQ).Address[dataPtr]^, buf, dataLeft);
    dataPtr := CGpMQHeaderSize;
    bufOffs := dataLeft;
    Dec(bufLen, dataLeft);
  end;
  if bufLen > 0 then begin
    Move(Shm(MQ).Address[dataPtr]^, Ofs(@buf, bufOffs)^, bufLen);
    Inc(dataPtr, bufLen);
  end;
  Shm(MQ).LongIdx[CGpMQDataIdx] := dataPtr - CGpMQHeaderSize;
end; { TGpMessageQueue.WrappedRetrieve }

{:Store data into message queue buffer. Wrap at the end. Caller already checked
  that there is enough place for the data in the buffer. Buffer has already been
  acquired.
  @since   2002-10-22
}
procedure TGpMessageQueue.WrappedStore(const buf; bufLen: cardinal);
var
  bufOffs  : cardinal;
  freePtr  : longword;
  placeLeft: longword;
begin
  freePtr := Shm(MQ).LongIdx[CGpMQFreeIdx] + CGpMQHeaderSize;
  placeLeft := mqSize - freePtr;
  bufOffs := 0;
  if placeLeft <= bufLen then begin
    Move(buf, Shm(MQ).Address[freePtr]^, placeLeft);
    freePtr := CGpMQHeaderSize;
    bufOffs := placeLeft;
    Dec(bufLen, placeLeft);
  end;
  if bufLen > 0 then begin
    Move(Ofs(@buf, bufOffs)^, Shm(MQ).Address[freePtr]^, bufLen);
    Inc(freePtr, bufLen);
  end;
  Shm(MQ).LongIdx[CGpMQFreeIdx] := freePtr - CGpMQHeaderSize;
end; { TGpMessageQueue.WrappedStore }

{ TGpMessageQueueReaderThread }

{:Create message queue monitoring thread.
  @param   newMessageEvent    Event that will be signalled when new message was
                              posted to the queue.
  @param   notifyEvent        Thread must signal this event when new message is
                              received.
  @param   notifyWindowHandle Thread must notify this window handle when new
                              message is received.
  @param   notifyMessage      Thread must send this message to the window handle
                              when new message is received.
  @since   2002-10-22
}
constructor TGpMessageQueueReaderThread.Create(newMessageEvent: THandle;
  notifyEvent: THandle{CreateEvent}; notifyWindowHandle: HWND;
  notifyMessage: UINT; parent: TGpMessageQueueReader);
begin
  mqrtParent := parent;
  mqrtNewMessageEvt := newMessageEvent;
  mqrtNotifyEvent := notifyEvent;
  mqrtNotifyWindowHandle := notifyWindowHandle;
  mqrtNotifyMessage := notifyMessage;
  mqrtTerminateEvt := CreateEvent(nil, false, false, PChar(TGpToken.GenerateToken));
  if mqrtTerminateEvt = 0 then
    RaiseLastOSError;
  inherited Create(false);
end; { TGpMessageQueueReaderThread.Create }

{:Destroy message queue monitor.
  @since   2002-10-22
}        
destructor TGpMessageQueueReaderThread.Destroy;
begin
  DSiCloseHandleAndNull(mqrtTerminateEvt);
  inherited;
end; { TGpMessageQueueReaderThread.Destroy }

{:Monitor message queue for new messages.
  @since   2002-10-22
}
procedure TGpMessageQueueReaderThread.Execute;
var
  awaited: DWORD;
  handles: array [0..1] of THandle;
  {$IFDEF LogGpMessageQueue}
  logger : IGpLogger;
  {$ENDIF LogGpMessageQueue}
begin
  {$IFDEF LogGpMessageQueue}
  logger := CreateGpLogger(ExtractFilePath(ParamStr(0))+'MessageQueue.log');
  logger.Log('mqrt: Starting');
  try try
  {$ENDIF LogGpMessageQueue}
  handles[0] := mqrtNewMessageEvt;
  handles[1] := mqrtTerminateEvt;
  while true do begin
    awaited := WaitForMultipleObjects(2, @handles, false, INFINITE);
    {$IFDEF LogGpMessageQueue}
    logger.Log('mqrt: awaited %d', [awaited]);
    {$ENDIF LogGpMessageQueue}
    if awaited <> WAIT_OBJECT_0 then
      break; //while
    if mqrtNotifyEvent <> 0 then
      SetEvent(mqrtNotifyEvent);
    if mqrtNotifyWindowHandle <> 0 then
      PostMessage(mqrtNotifyWindowHandle, mqrtNotifyMessage, WPARAM(mqrtParent), 0);
  end; //while
  {$IFDEF LogGpMessageQueue}
  except on E: Exception do begin logger.Log('mqrt: Exception %s', [E.Message]); raise; end; end;
  finally logger.Log('mqrt: Terminating'); end;
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueueReaderThread.Execute }

{:Terminate message queue monitoring thread.
  @since   2002-10-22
}        
procedure TGpMessageQueueReaderThread.Terminate;
begin
  SetEvent(mqrtTerminateEvt);
  inherited;
end; { TGpMessageQueueReaderThread.Terminate }

{ TGpMessageQueueReader }

procedure TGpMessageQueueReader.AttachToThread;
begin
  inherited;
  mqrOwningThread := GetCurrentThreadID;
end; { TGpMessageQueueReader.AttachToThread }

{:Prepare message queue reader for destruction.
  @since   2002-10-22
}
procedure TGpMessageQueueReader.Cleanup;
begin
  if assigned(mqrReaderThread) then begin
    (mqrReaderThread as TGpMessageQueueReaderThread).Terminate;
    mqrReaderThread.WaitFor;
    FreeAndNil(mqrReaderThread);
  end;
  DSiCloseHandleAndNull(mqrSingleReader);
end; { TGpMessageQueueReader.Cleanup }

{:Initialize message queue reader. Object will notify the owner by signalling
  the event.
  @since   2002-10-22
}        
constructor TGpMessageQueueReader.Create(messageQueueName: AnsiString; messageQueueSize:
  cardinal; newMessageEvent: THandle{CreateEvent}; queueMessageCount: PCardinal = nil);
begin
  mqrNewMessageEvent := newMessageEvent;
  inherited Create(messageQueueName, messageQueueSize, queueMessageCount);
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]: Reader created, notification via event', [mqName]);
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueueReader.Create }

{:Initialize message queue reader. Object will notify the owner by sending
  the message to the specified window.
  @since   2002-10-22
}
constructor TGpMessageQueueReader.Create(messageQueueName: AnsiString; messageQueueSize:
  cardinal; newMessageWindowHandle: HWND; newMessageMessage: UINT; queueMessageCount:
  PCardinal = nil);
begin
  mqrNewMessageWindowHandle := newMessageWindowHandle;
  mqrNewMessageMessage := newMessageMessage;
  inherited Create(messageQueueName, messageQueueSize, queueMessageCount);
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]: Reader created, notification via handle', [mqName]);
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueueReader.Create }

function TGpMessageQueueReader.GetMessage(timeout: DWORD; var msg: UINT;
  var wParam: WPARAM; var lParam: LPARAM): TGpMQGetStatus;
var
  flags  : TGpMQMessageFlags;
  msgData: AnsiString;
begin
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]:=> GetMessage; %d/%d/%d/%d', [mqName, timeout, msg, wParam, lParam]);
  try try
  {$ENDIF LogGpMessageQueue}
  Result := GetMessage(timeout, flags, msg, wParam, lParam, msgData);
  if (Result = mqgOK) and (flags <> [mqfHasMsg, mqfHasWParam, mqfHasLParam]) then
    Result := mqgSkipped;
  {$IFDEF LogGpMessageQueue}
  except on E: Exception do begin mqLogger.Log('mq[%s]: Exception %s', [mqName, E.Message]); raise; end; end;
  finally mqLogger.Log('mq[%s]:<= GetMessage, Result = %d', [mqName, Ord(Result)]); end;
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueueReader.GetMessage }

function TGpMessageQueueReader.GetMessage(timeout: DWORD; var msgData: AnsiString):
  TGpMQGetStatus;
var
  flags  : TGpMQMessageFlags;
  lParam : Windows.LPARAM;
  msg    : UINT;
  wParam : Windows.WPARAM;
begin
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]:=> GetMessage; %d/%s', [mqName, timeout, msgData]);
  try try
  {$ENDIF LogGpMessageQueue}
  Result := GetMessage(timeout, flags, msg, wParam, lParam, msgData);
  if (Result = mqgOK) and (flags <> [mqfHasData]) then
    Result := mqgSkipped;
  {$IFDEF LogGpMessageQueue}
  except on E: Exception do begin mqLogger.Log('mq[%s]: Exception %s', [mqName, E.Message]); raise; end; end;
  finally mqLogger.Log('mq[%s]:<= GetMessage, Result = %d', [mqName, Ord(Result)]); end;
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueueReader.GetMessage }

function TGpMessageQueueReader.GetMessage(timeout: DWORD; var flags: TGpMQMessageFlags;
  var msg: UINT; var wParam: WPARAM; var lParam: LPARAM; var msgData: AnsiString):
  TGpMQGetStatus;
begin
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]:=> GetMessage; %d/%d/%d/%d/%d/%s', [mqName, timeout, byte(flags), msg, wParam, lParam, msgData]);
  try try
  {$ENDIF LogGpMessageQueue}
  if mqrOwningThread = 0 then
    mqrOwningThread := GetCurrentThreadID
  else if mqrOwningThread <> GetCurrentThreadID then
    raise Exception.CreateFmt(
      'TGpMessageQueueReader<%s>.GetMessage called from two threads: %d and %d',
      [Name, mqrOwningThread, GetCurrentThreadID]);
  if Shm(MQ).AcquireMemory(true, timeout) = nil then
    Result := mqgTimeout
  else begin
    try
      Result := RetrieveMessage(true, flags, msg, wParam, lParam, msgData);
    finally Shm(MQ).ReleaseMemory; end;
  end;
  {$IFDEF LogGpMessageQueue}
  except on E: Exception do begin mqLogger.Log('mq[%s]: Exception %s', [mqName, E.Message]); raise; end; end;
  finally mqLogger.Log('mq[%s]:<= GetMessage, Result = %d', [mqName, Ord(Result)]); end;
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueueReader.GetMessage }

function TGpMessageQueueReader.GetMessage(timeout: DWORD; var msg: UINT; var msgData:
  AnsiString): TGpMQGetStatus;
var
  flags : TGpMQMessageFlags;
  lParam: Windows.LPARAM;
  wParam: Windows.WPARAM;
begin
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]:=> GetMessage; %d/%d/%s', [mqName, timeout, msg, msgData]);
  try try
  {$ENDIF LogGpMessageQueue}
  Result := GetMessage(timeout, flags, msg, wParam, lParam, msgData);
  if (Result = mqgOK) and (flags <> [mqfHasMsg, mqfHasData]) then
    Result := mqgSkipped;
  {$IFDEF LogGpMessageQueue}
  except on E: Exception do begin mqLogger.Log('mq[%s]: Exception %s', [mqName, E.Message]); raise; end; end;
  finally mqLogger.Log('mq[%s]:<= GetMessage, Result = %d', [mqName, Ord(Result)]); end;
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueueReader.GetMessage }

{:Initialize message queue reader.
  @since   2002-10-22
}
procedure TGpMessageQueueReader.Initialize;
begin
  WaitForSingleobject(InitializationMtx, INFINITE); // prevent race condition with Writer's IsReaderAlive
  try
    mqrSingleReader := CreateMutex_AllowEveryone(false, string(ReaderMutexName));
    if mqrSingleReader = 0 then
      RaiseLastOSError
    else if GetLastError = ERROR_ALREADY_EXISTS then begin
      DSiCloseHandleAndNull(mqrSingleReader);
      raise EGpSync.CreateFmt(sQueueReaderAlreadyExists, [Name]);
    end;
  finally ReleaseMutex(InitializationMtx); end;
  mqrReaderThread := TGpMessageQueueReaderThread.Create(NewMessageEvt,
    mqrNewMessageEvent, mqrNewMessageWindowHandle, mqrNewMessageMessage,
    self);
end; { TGpMessageQueueReader.Initialize }

function TGpMessageQueueReader.PeekMessage(timeout: DWORD; var msg: UINT;
  var wParam: WPARAM; var lParam: LPARAM): TGpMQGetStatus;
var
  flags  : TGpMQMessageFlags;
  msgData: AnsiString;
begin
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]:=> PeekMessage; %d/%d/%d/%d', [mqName, timeout, msg, wParam, lParam]);
  try try
  {$ENDIF LogGpMessageQueue}
  Result := PeekMessage(timeout, flags, msg, wParam, lParam, msgData);
  if (Result = mqgOK) and (flags <> [mqfHasMsg, mqfHasWParam, mqfHasLParam]) then
    Result := mqgSkipped;
  {$IFDEF LogGpMessageQueue}
  except on E: Exception do begin mqLogger.Log('mq[%s]: Exception %s', [mqName, E.Message]); raise; end; end;
  finally mqLogger.Log('mq[%s]:<= PeekMessage, Result = %d', [mqName, Ord(Result)]); end;
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueueReader.PeekMessage }

function TGpMessageQueueReader.PeekMessage(timeout: DWORD; var msgData: AnsiString):
  TGpMQGetStatus;
var
  flags : TGpMQMessageFlags;
  lParam: Windows.LPARAM;
  msg   : UINT;
  wParam: Windows.WPARAM;
begin
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]:=> PeekMessage; %d/%s', [mqName, timeout, msgData]);
  try try
  {$ENDIF LogGpMessageQueue}
  Result := PeekMessage(timeout, flags, msg, wParam, lParam, msgData);
  if (Result = mqgOK) and (flags <> [mqfHasData]) then
    Result := mqgSkipped;
  {$IFDEF LogGpMessageQueue}
  except on E: Exception do begin mqLogger.Log('mq[%s]: Exception %s', [mqName, E.Message]); raise; end; end;
  finally mqLogger.Log('mq[%s]:<= PeekMessage, Result = %d', [mqName, Ord(Result)]); end;
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueueReader.PeekMessage }

function TGpMessageQueueReader.PeekMessage(timeout: DWORD; var flags: TGpMQMessageFlags;
  var msg: UINT; var wParam: WPARAM; var lParam: LPARAM; var msgData: AnsiString):
  TGpMQGetStatus;
begin
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]:=> PeekMessage; %d/%d/%d/%d/%d/%s', [mqName, timeout, byte(flags), msg, wParam, lParam, msgData]);
  try try
  {$ENDIF LogGpMessageQueue}
  if Shm(MQ).AcquireMemory(true, timeout) = nil then
    Result := mqgTimeout
  else begin
    try
      Result := RetrieveMessage(false, flags, msg, wParam, lParam, msgData);
    finally Shm(MQ).ReleaseMemory; end;
  end;
  {$IFDEF LogGpMessageQueue}
  except on E: Exception do begin mqLogger.Log('mq[%s]: Exception %s', [mqName, E.Message]); raise; end; end;
  finally mqLogger.Log('mq[%s]:<= PeekMessage, Result = %d', [mqName, Ord(Result)]); end;
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueueReader.PeekMessage }

function TGpMessageQueueReader.PeekMessage(timeout: DWORD; var msg: UINT; var msgData:
  AnsiString): TGpMQGetStatus;
var
  flags : TGpMQMessageFlags;
  lParam: Windows.LPARAM;
  wParam: Windows.WPARAM;
begin
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]:=> PeekMessage; %d/%d/%s', [mqName, timeout, msg, msgData]);
  try try
  {$ENDIF LogGpMessageQueue}
  Result := PeekMessage(timeout, flags, msg, wParam, lParam, msgData);
  if (Result = mqgOK) and (flags <> [mqfHasMsg, mqfHasData]) then
    Result := mqgSkipped;
  {$IFDEF LogGpMessageQueue}
  except on E: Exception do begin mqLogger.Log('mq[%s]: Exception %s', [mqName, E.Message]); raise; end; end;
  finally mqLogger.Log('mq[%s]:<= PeekMessage, Result = %d', [mqName, Ord(Result)]); end;
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueueReader.PeekMessage }

{ TGpMessageQueueWriter }

{:Prepare message queue writer for destruction.
  @since   2002-10-22
}
procedure TGpMessageQueueWriter.Cleanup;
begin
  // Do nothing.
end; { TGpMessageQueueWriter.Cleanup }

{:Create message queue writer.
  @since   2002-10-23
}        
constructor TGpMessageQueueWriter.Create(messageQueueName: AnsiString; messageQueueSize:
  cardinal; queueMessageCount: PCardinal = nil);
begin
  inherited;
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mq[%s]: Writer created', [mqName]);
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueueWriter.Create }

{:Initialize message queue reader.
  @since   2002-10-22
}
procedure TGpMessageQueueWriter.Initialize;
begin
  // Do nothing.
end; { TGpMessageQueueWriter.Initialize }

function TGpMessageQueueWriter.IsReaderAlive: boolean;
var
  mtxSingleReader: THandle;
begin
  {$IFDEF LogGpMessageQueue}
  mqLogger.Log('mqw[%s]:=> IsReaderAlive', [mqName]);
  try try
  {$ENDIF LogGpMessageQueue}
  WaitForSingleobject(InitializationMtx, INFINITE); // prevent race condition with Writer's IsReaderAlive
  try
    mtxSingleReader := CreateMutex_AllowEveryone(false, string(ReaderMutexName));
    try
      Result := (mtxSingleReader <> 0) and (GetLastError = ERROR_ALREADY_EXISTS);
    finally CloseHandle(mtxSingleReader); end;
  finally ReleaseMutex(InitializationMtx); end;
  {$IFDEF LogGpMessageQueue}
  except on E: Exception do begin mqLogger.Log('mqw[%s]: Exception %s', [mqName, E.Message]); raise; end; end;
  finally mqLogger.Log('mqw[%s]:<= IsReaderAlive, Result = %d', [mqName, Ord(Result)]); end;
  {$ENDIF LogGpMessageQueue}
end; { TGpMessageQueueWriter.IsReaderAlive }

{ TGpMessageQueueList }

function TGpMessageQueueList.Add(gpMessageQueue: TGpMessageQueue): integer;
begin
  Result := inherited Add(gpMessageQueue);
end; { TGpMessageQueueList.Add }

function TGpMessageQueueList.AddNewReader(messageQueueName: AnsiString; messageQueueSize:
  cardinal): TGpMessageQueue;
begin
  Result := TGpMessageQueueReader.Create(messageQueueName, messageQueueSize);
  Add(Result);
end; { TGpMessageQueueList.AddNewReader }

function TGpMessageQueueList.AddNewWriter(messageQueueName: AnsiString; messageQueueSize:
  cardinal): TGpMessageQueue;
begin
  Result := TGpMessageQueueWriter.Create(messageQueueName, messageQueueSize);
  Add(Result);
end; { TGpMessageQueueList.AddNewWriter }

function TGpMessageQueueList.Extract(
  gpMessageQueue: TGpMessageQueue): TGpMessageQueue;
begin
  Result := TGpMessageQueue(inherited Extract(gpMessageQueue));
end; { TGpMessageQueueList.Extract }

function TGpMessageQueueList.GetItem(idx: integer): TGpMessageQueue;
begin
  Result := (inherited GetItem(idx)) as TGpMessageQueue;
end; { TGpMessageQueueList.GetItem }

function TGpMessageQueueList.IndexOf(gpMessageQueue: TGpMessageQueue): integer;
begin
  Result := inherited IndexOf(gpMessageQueue);
end; { TGpMessageQueueList.IndexOf }

procedure TGpMessageQueueList.Insert(idx: integer;
  gpMessageQueue: TGpMessageQueue);
begin
  inherited Insert(idx, gpMessageQueue);
end; { TGpMessageQueueList.Insert }

function TGpMessageQueueList.Remove(gpMessageQueue: TGpMessageQueue): integer;
begin
  Result := inherited Remove(gpMessageQueue);
end; { TGpMessageQueueList.Remove }

procedure TGpMessageQueueList.SetItem(idx: integer;
  const Value: TGpMessageQueue);
begin
  inherited SetItem(idx, Value);
end; { TGpMessageQueueList.SetItem }

{ TGpCircularBuffer }

constructor TGpCircularBuffer.Create(bufferSize: integer);
begin
  SetLength(cbBuffer, bufferSize);
  cbHead := Low(cbBuffer);
  cbTail := Low(cbBuffer);
  cbEmptyCount := CreateSemaphore(nil, bufferSize, bufferSize, nil);
  if cbEmptyCount = 0 then
    raise Exception.Create('TGpCircularBuffer.Create: Failed to acquire ''empty count'' semaphore');
  cbDataCount := CreateSemaphore(nil, 0, bufferSize, nil);
  if cbDataCount = 0 then
    raise Exception.Create('TGpCircularBuffer.Create: Failed to acquire ''data count'' semaphore');
end; { TGpCircularBuffer.Create }

destructor TGpCircularBuffer.Destroy;
begin
  DSiCloseHandleAndNull(cbEmptyCount);
end; { TGpCircularBuffer.Destroy }

{:Dequeues a pointer. Waits up to timeout_ms milliseconds on data.
  @returns false if buffer is empty.
  @since   2007-01-03
}
function TGpCircularBuffer.Dequeue(timeout_ms: DWORD = 0): pointer;
begin
  Result := nil;
  if WaitForSingleObject(cbDataCount, timeout_ms) = WAIT_OBJECT_0 then 
    Result := DequeueAllocated;
end; { TGpCircularBuffer.Dequeue }

{:Dequeues a pointer from an already allocated tail.
  @since   2007-01-03
}
function TGpCircularBuffer.DequeueAllocated: pointer;
begin
  WrapIncrement(cbTail);
  Result := cbBuffer[cbTail];
  ReleaseSemaphore(cbEmptyCount, 1, nil);
end; { TGpCircularBuffer.DequeueAllocated }

{:Enqueues a pointer. Waits up to timeout_ms milliseconds for a place in the buffer.
  @returns false if buffer is full.
  @since   2007-01-03
}
function TGpCircularBuffer.Enqueue(const buffer: pointer; timeout_ms: DWORD = 0): boolean;
begin
  Result := false;
  if WaitForSingleObject(cbEmptyCount, timeout_ms) = WAIT_OBJECT_0 then 
    Result := EnqueueAllocated(buffer);
end; { TGpCircularBuffer.Enqueue }

{:Enqueues a pointer to an already allocated head.
  @since   2007-01-03
}
function TGpCircularBuffer.EnqueueAllocated(const buffer: pointer): boolean;
begin
  WrapIncrement(cbHead);
  cbBuffer[cbHead] := buffer;
  ReleaseSemaphore(cbDataCount, 1, nil);
  Result := true;
end; { TGpCircularBuffer.EnqueueAllocated }

procedure TGpCircularBuffer.WrapIncrement(var bufferPointer: integer);
begin
  Inc(bufferPointer);
  if bufferPointer > High(cbBuffer) then
    bufferPointer := Low(cbBuffer);
end; { TGpCircularBuffer.WrapIncrement }

end.
