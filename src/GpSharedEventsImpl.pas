(*:Distributed multicast event manager.
   @author Primoz Gabrijelcic
   @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2007, Primoz Gabrijelcic
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
   Creation date     : 2001-07-17
   Last modification : 2007-05-30
   Version           : 1.03a
</pre>*)(*
   History:
     1.03a: 2007-05-30
       - AllocateHwnd and DeallocateHwnd replaced with thread-safe versions.
     1.03: 2003-09-30
       - TGpSEEventQueue changed into TGpSharedTable.
       - TGpSECounters changed into TGpSharedNamedCounters.
     1.02: 2003-07-28
       - Made some more string parameters 'const'.
       - Added readonly property TGpSharedEventManager.SubjectHandle.
     1.01b: 2003-05-14
       - Delphi 7 compatible.
     1.01a: 2003-01-15
       - Fixed runtime error occuring in special conditions.
     1.01: 2002-10-17
       - Event manager now works from non-interactive service running under
         system account.
     1.0: 2002-10-03
       - Released.
     0.1: 2001-07-17
       - Created.
*)

unit GpSharedEventsImpl;

interface

uses
  SysUtils,
  Windows,
  Messages,
  Classes,
  GpManagedClass,
  GpLists,
  GpSync,
  GpSharedMemory,
  GpSharedTable,
  {$IFDEF DebugSEEventQueue}
  GpLogger,
  {$ENDIF DebugSEEventQueue}
  OmniXML,
  OmniXMLUtils,
  OmniXMLProperties,
  OmniXMLShared;

{$IFDEF Linux}{$MESSAGE FATAL 'This unit is for Windows only'}{$ENDIF Linux}
{$IFDEF MSWindows}{$WARN SYMBOL_DEPRECATED OFF}{$ENDIF MSWindows}

type
  EGpSharedEventManager = class(Exception);

  //:Internal handle.
  TGpSEHandle = type cardinal;
  //:String ID (name).
  TGpSEID = type string;
  //:Token name.
  TGpSEToken = type string;

const
  //:Invalid handle.
  CInvalidSEHandle = Low(TGpSEHandle);
  //:Invalid token.
  CInvalidSEToken = '';

  //Fields in the EventQueue table
  CRecHandle       = 0;
  CRecEvent        = 1;
  CRecProducer     = 2;
  CRecData         = 3;
  CRecDataSize     = 4;
  CRecSharedMemory = 5;
  CRecListeners    = 6;

type
  {:Shared events manager errors.
    !!!Keep this enum in sync with GpSharedEvents.TGpSharedEventError!!!
    @enum semErrNoError       No error.
    @enum semErrNotAcquired   Shared memory cannot be acquired.
    @enum semErrNotFound      Handle not found.
    @enum semErrAlreadyExists Item already exists.
    @enum semErrInvalidName   Invalid item name.
    @enum semErrInvalidEvent  Invalid event name.
  }
  TGpSharedEventManagerError = (semErrNoError, semErrNotAcquired,
    semErrNotFound, semErrAlreadyExists, semErrInvalidName, semErrInvalidEvent);

  {:List of handles.
  }
  TGpSEHandleList = class(TGpIntegerList)
  protected
    function  GetItem(idx: integer): TGpSEHandle;
    procedure SetItem(idx: integer; const value: TGpSEHandle);
  public
    constructor Create;
    function  Add(item: TGpSEHandle): integer; reintroduce;
    property Items[idx: integer]: TGpSEHandle read GetItem write SetItem; default;
  end; { TGpSEHandleList }

  {:TGpXMLData descendant implementing shared events-specific setters and
    getters.
  }
  TGpSEXMLData = class(TGpXMLData)
  protected
    //<Bypassing C1537 internal error in Delphi 2005
    function  GetXMLProp(index: integer): string; override;
    procedure SetXMLProp(const index: integer; const value: string); override;
    //>
    function  GetXMLPropSEHandle(index: integer): TGpSEHandle; virtual;
    procedure SetXMLPropSEHandle(const index: integer; const value: TGpSEHandle); virtual;
  end; { TGpSEXMLData }

  {:Subject entry in the Subjects table.
  }
  TGpSESubject = class(TGpSEXMLData)
  public
    constructor Create(subjectNode: IXMLNode); override;
    property Handle    : TGpSEHandle index 0 read GetXMLPropSEHandle write SetXMLPropSEHandle;
    property Name      : string      index 1 read GetXMLProp         write SetXMLProp;
    property Token     : string      index 2 read GetXMLProp         write SetXMLProp;
    property Interest  : integer     index 3 read GetXMLPropInt      write SetXMLPropInt;
    property IsProducer: boolean     index 4 read GetXMLPropBool     write SetXMLPropBool;
  end; { TGpSESubject }

  {:Event entry in the Events table.
  }
  TGpSEEvent = class(TGpSEXMLData)
  public
    constructor Create(eventNode: IXMLNode); override;
    property Handle: TGpSEHandle index 0 read GetXMLPropSEHandle write SetXMLPropSEHandle;
    property Name  : string      index 1 read GetXMLProp         write SetXMLProp;
  end; { TGpSEEvent }

  {:Mapping entry in the SEMappings table.
  }
  TGpSESEMapping = class(TGpSEXMLData)
  public
    constructor Create(seMappingNode: IXMLNode); override;
    property Subject   : TGpSEHandle index 0 read GetXMLPropSEHandle write SetXMLPropSEHandle;
    property Event     : TGpSEHandle index 1 read GetXMLPropSEHandle write SetXMLPropSEHandle;
    property IsProducer: boolean     index 2 read GetXMLPropBool     write SetXMLPropBool;
  end; { TGpSESEMapping }

  {:One listener in the list of listeners.
  }
  TGpSEEventQueueEntryListener = class(TGpSEXMLData)
  private
    function  GetListener: TGpSEHandle;
    procedure SetListener(const value: TGpSEHandle);
  public
    property Listener: TGpSEHandle read GetListener write SetListener;
  end; { TGpSEEventQueueEntryListener }

  {:Queue entry in the EventQueue table.
  }
  TGpSEEventQueueEntry = class(TGpSharedTableEntry)
  private
    eqeListeners: TGpSEHandleList;
  protected
    procedure AfterFetch; override;
    procedure BeforePost; override;
    function  GetFieldHandle(idxField: integer): TGpSEHandle;
    procedure SetFieldHandle(idxField: integer; value: TGpSEHandle);
  public
    constructor Create(owner: TGpBaseSharedTable); override;
    destructor  Destroy; override;
    property Handle: TGpSEHandle index CRecHandle read GetFieldHandle write SetFieldHandle;
    property Event: TGpSEHandle index CRecEvent read GetFieldHandle write SetFieldHandle;
    property Producer: TGpSEHandle index CRecProducer read GetFieldHandle write SetFieldHandle;
    {$IFDEF Unicode}
    property Data: WideString index CRecData read GetFieldWideStr write SetFieldWideStr;
    {$ELSE}
    property Data: string index CRecData read GetFieldStr write SetFieldStr;
    {$ENDIF}
    property DataSize: cardinal index CRecDataSize read GetFieldCardinal write SetFieldCardinal;
    property SharedMemory: cardinal index CRecSharedMemory read GetFieldCardinal write SetFieldCardinal;
    property Listeners: TGpSEHandleList index CRecListeners read eqeListeners;
  end; { TGpSEEventQueueEntry }

  {:Data for the Subjects table.
  }
  TGpSESubjectList = class(TGpXMLDocList)
  private
    function  GetSubject(idx: integer): TGpSESubject;
    function IndexOf(subjectHandle: TGpSEHandle): integer;
  public
    constructor Create; reintroduce;
    function  Add: TGpSESubject; reintroduce;
    procedure CollectInvalidSubjects(subjectList: TGpSEHandleList);
    function  LocateSubject(subjectHandle: TGpSEHandle): TGpSESubject;
    procedure RemoveInvalidSubjects(subjectList: TGpSEHandleList);
    function  Name(subjectHandle: TGpSEHandle): string;
    function  Token(subjectHandle: TGpSEHandle): string;
    property  Items[idx: integer]: TGpSESubject read GetSubject; default;
  end; { TGpSESubjectList }

  {:Data for the Events table.
  }
  TGpSEEventList = class(TGpXMLDocList)
  private
    function  GetEvent(idx: integer): TGpSEEvent;
  public
    constructor Create; reintroduce;
    function  Add: TGpSEEvent; reintroduce;
    function  IndexOf(const eventName: string): integer;
    function  Locate(const eventName: string): TGpSEHandle;
    function  LocateEvent(const eventHandle: TGpSEHandle): integer;
    function  Name(eventHandle: TGpSEHandle): string;
    property  Items[idx: integer]: TGpSEEvent read GetEvent; default;
  end; { TGpSEEventList }

  {:Data for the SEMappings table.
  }
  TGpSESEMappingList = class(TGpXMLDocList)
  private
    function  GetSEMapping(idx: integer): TGpSESEMapping;
  public
    constructor Create; reintroduce;
    function  Add: TGpSESEMapping; reintroduce;
    function  IndexOf(subjectHandle, eventHandle: TGpSEHandle): integer;
    procedure RemoveInvalidSubjects(subjectList: TGpSEHandleList);
    property  Items[idx: integer]: TGpSESEMapping read GetSEMapping; default;
  end; { TGpSESEMappingList }

  {:Counters.
  }
  TGpSECounters = class(TGpSharedNamedCounters)
  public
    constructor Create(namespace: string);
    function  Increment(const counterName: AnsiString): integer;
  end; { TGpSECounters }

  TGpSESEMappings = class;
  TGpSharedEventManager = class;

  {:Table of subjects (producers and listeners).
  }
  TGpSESubjects = class(TGpManagedClass)
  private
    seCounters  : TGpSECounters;
    seManager   : TGpSharedEventManager;
    seSEMappings: TGpSESEMappings;
    seSubjData  : TGpSharedXMLList;
  protected
    function AccessSubjects: TGpSESubjectList;
    function CachedSubjects: TGpSESubjectList;
  public
    constructor Create(namespace: string; counters: TGpSECounters;
      SEMappings: TGpSESEMappings; manager: TGpSharedEventManager);
    destructor  Destroy; override;
    function  CollectInvalidSubjects(subjectList: TGpSEHandleList): boolean;
    procedure FilterSubjects(subjectList: TGpSEHandleList);
    function  GetAllSubjects(interestFlags: integer;
      allSubjects: TGpSEHandleList): boolean;
    function  GetSubjects(subjectsList: TStrings; getProducers,
      getListeners: boolean): boolean;
    function  Name(subjectHandle: TGpSEHandle): string;
    function  NotifyListeners(listeners: TGpSEHandleList): boolean;
    function  RegisterSubject(subjectName: TGpSEID; subjectToken: TGpSEToken;
      subjectIsProducer: boolean): TGpSEHandle;
    function  RemoveInvalidSubjects(subjectList: TGpSEHandleList): boolean;
    function  ResetInterest(subjectHandle: TGpSEHandle; newInterest: integer): boolean;
    function  Token(subjectHandle: TGpSEHandle): string;
    function  UnregisterSubject(subjectHandle: TGpSEHandle): boolean;
  end; { TGpSESubjects }

  {:Table of events.
  }
  TGpSEEvents = class(TGpManagedClass)
  private
    seEventData: TGpSharedXMLList;
  protected
    function  AccessEvents: TGpSEEventList;
    function  CachedEvents: TGpSEEventList;
    function  IndexOf(const eventName: string): integer;
  public
    constructor Create(namespace: string);
    destructor  Destroy; override;
    function  GetEvents(eventsList: TStrings): boolean;
    function  Locate(eventName: string): TGpSEHandle;
    function  MapEventsToNames(eventHandleList: TGpSEHandleList;
      eventNameList: TStrings): boolean;
    function  Name(eventHandle: TGpSEHandle): string;
    function  RegisterEvent(eventName: string): TGpSEHandle;
    function  UnregisterEvent(eventName: string): boolean;
  end; { TGpSEEvents }

  {:Table of Subject-Event mappings.
  }
  TGpSESEMappings = class(TGpManagedClass)
  private
    seSEMappingData: TGpSharedXMLList;
  protected
    function  AccessMappings: TGpSESEMappingList;
    function  CachedMappings: TGpSESEMappingList;
    function  IndexOf(subjectHandle, eventHandle: TGpSEHandle): integer;
  public
    constructor Create(namespace: string);
    destructor  Destroy; override;
    function  AddMapping(subjectHandle, eventHandle: TGpSEHandle; subjectIsProducer:
      boolean): boolean;
    function  DeleteMapping(subjectHandle, eventHandle: TGpSEHandle): boolean;
    function  DeleteAllEvents(subjectHandle: TGpSEHandle): boolean;
    function  GetEvents(subjectHandle: TGpSEHandle; eventList: TGpSEHandleList;
      getProducers, getListeners, getFromCache: boolean): boolean;
    function  GetListeners(eventHandle: TGpSEHandle; listeners: TGpSEHandleList): boolean;
    function  RemoveInvalidSubjects(subjectList: TGpSEHandleList): boolean;
    function  SubjectPublishes(subjectHandle, eventHandle: TGpSEHandle;
      getFromCache: boolean; var publishes: boolean): boolean;
  end; { TGpSESEMappings }

  {:Queue of outstanding broadcast&send requests.
  }
  TGpSEEventQueue = class(TGpManagedClass)
  private
    seCounters      : TGpSECounters;
    seEventQueueData: TGpSharedTable;
    seManager       : TGpSharedEventManager;
    seSubjects      : TGpSESubjects;
    {$IFDEF DebugSEEventQueue}
    seLogger        : IGpLogger;
    {$ENDIF DebugSEEventQueue}
  protected
    function  AccessEventQueue: boolean;
    function  GetItem(idxItem: integer): TGpSEEventQueueEntry;
    function  LocateHandle(eventQueueHandle: TGpSEHandle): integer;
    {$IFDEF DebugSEEventQueue}
    procedure DumpTable;
    {$ENDIF DebugSEEventQueue}
  public
    constructor Create(namespace: string; counters: TGpSECounters;
      subjects: TGpSESubjects; manager: TGpSharedEventManager);
    destructor  Destroy; override;
    function  BeginUpdate: boolean;
    procedure EndUpdate;
    function  EventSent(eventQueueHandle: TGpSEHandle;
      out eventHandle: TGpSEHandle; out sharedMemory: TGpSharedMemory): boolean;
    procedure GetAllEntriesForListener(listener: TGpSEHandle;
      listenerList: TGpIntegerList); 
    function  Insert(eventHandle, subjectHandle: TGpSEHandle; eventData: string;
      eventDataSize: cardinal; eventListeners: TGpSEHandleList;
      eventSharedMemory: TGpSharedMemory; out eventQueueHandle: TGpSEHandle): boolean;
    function  Locate(eventQueueHandle: TGpSEHandle): TGpSEEventQueueEntry;
    function  RemoveInvalidSubjects(subjectList: TGpSEHandleList): boolean;
    function  RemoveListener(eventQueueHandle, subjectHandle: TGpSEHandle;
      out lastListener: boolean): boolean;
    function  RemoveListenerFromAll(subjectHandle: TGpSEHandle): boolean;
    property Items[idxItem: integer]: TGpSEEventQueueEntry read GetItem;
  end; { TGpSEEventQueue }

  {:'Subject registered'/'Subject unregistered' notifier.
  }
  TGpSESubjectLifecycleNotify = procedure(Sender: TObject;
    subjectHandle: TGpSEHandle; const subjectName: string;
    subjectIsProducer: boolean) of object;

  {:'Event received' notifier.
  }
  TGpSEEventReceivedNotify = procedure(Sender: TObject;
    producerHandle: TGpSEHandle; const producerName: string;
    eventHandle: TGpSEHandle; const eventName, eventData: string) of object;

  {:'Event sent' notifier.
  }
  TGpSEEventSentNotify = procedure(Sender: TObject; eventQueueHandle,
    eventHandle: TGpSEHandle; const eventName: string) of object;

  {'Event table was modified' notifier.
  }
  TGpSEEventChangeNotify = procedure(Sender: TObject; subjectHandle: TGpSEHandle;
    const subjectName: string; eventHandle: TGpSEHandle;
    const eventName: string) of object;

  {:Distributed multisink event manager.
  }
  TGpSharedEventManager = class(TGpManagedClass)
  private
    emCounters               : TGpSECounters;
    emEventQueue             : TGpSEEventQueue;
    emEvents                 : TGpSEEvents;
    emIsProducer             : boolean;
    emMessageWindow          : HWND;
    emMsgEventSent           : UINT;
    emMsgNewEventQueueEntry  : UINT;
    emMsgRemoveFromEventQueue: UINT;
    emMsgResendEventSent     : UINT;
    emMsgResetInterest       : UINT;
    emMsgValidityRescan      : UINT;
    emNamespace              : string;
    emNotificationEvent      : THandle;
    emNotificationThread     : TThread;
    emOnEventIgnored         : TGpSEEventChangeNotify;
    emOnEventMonitored       : TGpSEEventChangeNotify;
    emOnEventPublished       : TGpSEEventChangeNotify;
    emOnEventReceived        : TGpSEEventReceivedNotify;
    emOnEventSent            : TGpSEEventSentNotify;
    emOnEventUnpublished     : TGpSEEventChangeNotify;
    emOnSubjectRegistered    : TGpSESubjectLifecycleNotify;
    emOnSubjectUnregistered  : TGpSESubjectLifecycleNotify;
    emPublicName             : string;
    emSEMappings             : TGpSESEMappings;
    emSubjectHandle          : TGpSEHandle;
    emSubjects               : TGpSESubjects;
    emToken                  : TGpToken;
  protected
    class function MakeNotificationEventName(const tokenName: string): string;
    procedure BreakSystemMessage(const encodedMessage: string; out msg: string;
      out handle: TGpSEHandle; out data1, data2: string);
    function  BuildSystemMessage(msg: string; handle: TGpSEHandle;
      data1: string = ''; data2: string = ''): string;
    procedure CreateNotificationThread;
    procedure CreateSharedTables;
    procedure DestroyNotificationThread;
    procedure DestroySharedTables;
    procedure EventSent(eventQueueHandle: TGpSEHandle);
    function  GetActive: boolean;
    function  GetSubjectsEvents(getProducers, getListeners: boolean;
      eventList: TStrings): boolean;
    function  InternalBroadcastEvent(const eventName, eventData: string;
      excludeListener: TGpSEHandle = CInvalidSEHandle;
      sendOnlyTo: TGpSEHandle = CInvalidSEHandle;
      interestFlags: integer = 0): boolean; overload;
    function  InternalBroadcastEvent(out eventQueueHandle: TGpSEHandle;
      const eventName, eventData: string;
      excludeListener: TGpSEHandle = CInvalidSEHandle;
      sendOnlyTo: TGpSEHandle = CInvalidSEHandle;
      interestFlags: integer = 0): boolean; overload;
    procedure InternalProcessAndRemove(eventQueueHandle: TGpSEHandle;
      doProcess: boolean);
    function  InternalSendEvent(out eventQueueHandle: TGpSEHandle;
      recipientHandle: TGpSEHandle; const eventName,
      eventData: string): boolean; overload;
    function  InternalSendEvent(recipientHandle: TGpSEHandle; const eventName,
      eventData: string): boolean; overload;
    procedure NotifyEventSent(eventProducer, eventQueueHandle: TGpSEHandle);
    function  NotifyListeners(listeners: TGpSEHandleList): boolean;
    procedure OffloadLargeMessage(var eventData: string;
      out sharedMemory: TGpSharedMemory);
    function  PopulateListenerList(listeners: TGpSEHandleList;
      const eventName: string; sendOnlyTo, excludeListener: TGpSEHandle;
      interestFlags: integer; out eventHandle: TGpSEHandle): boolean;
    procedure ProcessSystemEvent(const eventData: string;
      producerHandle: TGpSEHandle);
    procedure ProcessUserEvent(eventHandle, producerHandle: TGpSEHandle;
      const eventData: string);
    procedure ReceiveEventQueueEntry(eventQueueHandle: TGpSEHandle);
    procedure RegisterMessages;
    function  RegisterSubject: boolean;
    procedure ReloadLargeMessage(eventQueueEntry: TGpSEEventQueueEntry;
      out eventData: string); 
    procedure RemoveEventFromEventQueue(eventQueueHandle: TGpSEHandle);
    function  RemoveListener(eventQueue: TGpSEEventQueue; eventHandle,
      eventProducer, eventQueueHandle, subjectHandle: TGpSEHandle): boolean;
    procedure ResetInterest;
    procedure SetOnEventIgnored(const Value: TGpSEEventChangeNotify);
    procedure SetOnEventMonitored(const Value: TGpSEEventChangeNotify);
    procedure SetOnEventPublished(const Value: TGpSEEventChangeNotify);
    procedure SetOnSubjectRegistered(
      const Value: TGpSESubjectLifecycleNotify);
    procedure SetOnSubjectUnregistered(
      const Value: TGpSESubjectLifecycleNotify);
    procedure Trigger(msg: UINT; param1: WPARAM; param2: LPARAM);
    procedure TriggerValidityRescan;
    function  UnregisterSubject: boolean;
    procedure ValidityRescan;
    procedure WndProc(var msg: TMessage);
  public
    constructor Create(namespace, publicName: string; isProducer: boolean);
    destructor  Destroy; override;
    function  BroadcastEvent(const eventName, eventData: string;
      out eventQueueHandle: TGpSEHandle): boolean;
    function  GetEvents(events: TStrings): boolean;
    function  GetMonitoredEvents(eventList: TStrings): boolean;
    function  GetPublishedEvents(eventList: TStrings): boolean;
    function  GetSubjects(subjects: TStrings; getProducers, getListeners: boolean): boolean;
    function  IgnoreEvent(const eventName: string): boolean;
    function  MonitorEvent(const eventName: string): boolean;
    function  PublishEvent(const eventName: string): boolean;
    function  SendEvent(listenerHandle: TGpSEHandle; const eventName,
      eventData: string; out eventQueueHandle: TGpSEHandle): boolean;
    function  UnpublishEvent(const eventName: string): boolean; 
  {properties}
    property Active: boolean read GetActive;
    property PublicName: string read emPublicName;
    property SubjectHandle: TGpSEHandle read emSubjectHandle;
  {event handlers}
    property OnEventIgnored: TGpSEEventChangeNotify
      read emOnEventIgnored write SetOnEventIgnored;
    property OnEventMonitored: TGpSEEventChangeNotify
      read emOnEventMonitored write SetOnEventMonitored;
    property OnEventPublished: TGpSEEventChangeNotify
      read emOnEventPublished write SetOnEventPublished;
    property OnEventReceived: TGpSEEventReceivedNotify
      read emOnEventReceived write emOnEventReceived;
    property OnEventSent: TGpSEEventSentNotify
      read emOnEventSent write emOnEventSent;
    property OnEventUnpublished: TGpSEEventChangeNotify
      read emOnEventUnpublished write emOnEventUnpublished;
    property OnSubjectRegistered: TGpSESubjectLifecycleNotify
      read emOnSubjectRegistered write SetOnSubjectRegistered;
    property OnSubjectUnregistered: TGpSESubjectLifecycleNotify
      read emOnSubjectUnregistered write SetOnSubjectUnregistered;
  end; { TGpSharedEventManager }

implementation

uses
  Forms, // to allocate and deallocate message window; this could be removed if it is found to be too restrictive
  DSiWin32,
  GpStuff,
  GpSecurity;

const
  CSystemEvent = '';
  CSysMsgEventModified       = 'EventModified';
  CSysMsgEventSent           = 'EventSent';
  CSysMsgSubjectRegistered   = 'SubjectRegistered';
  CSysMsgSubjectUnregistered = 'SubjectUnregistered';

  CModEventIgnored     = 'Ignored';
  CModEventMonitored   = 'Monitored';
  CModEventPublished   = 'Published';
  CModEventUnpublished = 'Unpublished';

  CWantEventIgnored        =  1;
  CWantEventMonitored      =  2;
  CWantEventPublished      =  4;
  CWantEventUnpublished    =  8;
  CWantSubjectRegistered   = 16;
  CWantSubjectUnregistered = 32;

  CDelim = '/';

  CLargestFastEvent = 1*1024; {1 KB} // Messages over 1 KB are sent using shared memory areas.

  CCountersTable        = 'Counters';
  CCountersTimeout      = 30000 {ms};  // Must never fail!
  CCountersMaxTableSize = 1024 {1 KB}; // Plenty of counters ...
  (*
  <CountersTable>
    <Counters>
      <Counter>
        <Name/>
        <Value/>
      </Counter>
      <Counter/>
    </Counters>
  </CountersTable>
  *)
  XML_COUNTERS_ROOT = 'CountersTable';
  XML_COUNTERS      = 'Counters';
  XML_COUNTER       = 'Counter';
  XML_COUNTER_NAME  = 'Name';
  XML_COUNTER_VALUE = 'Value';

  CSubjectsTable        = 'Subjects';
  CSubjectsTimeout      = 10000 {ms};
  CSubjectsMaxTableSize = 640*1024 {640 KB};
  (*
  <SubjectsTable>
    <Subjects>
      <Subject>
        <Handle/>
        <Name/>
        <Token/>
        <Interest/>
        <IsProducer/>
      </Subject>
      <Subject/>
    </Subjects>
  </SubjectsTable>
  *)
  XML_SUBJECTS_ROOT       = 'SubjectsTable';
  XML_SUBJECTS            = 'Subjects';
  XML_SUBJECT             = 'Subject';
  XML_SUBJECT_HANDLE      = 'Handle';
  XML_SUBJECT_NAME        = 'Name';
  XML_SUBJECT_TOKEN       = 'Token';
  XML_SUBJECT_INTEREST    = 'Interest';
  XML_SUBJECT_IS_PRODUCER = 'IsProducer';

  CEventsTable        = 'Events';
  CEventsTimeout      = 10000 {ms};
  CEventsMaxTableSize = 256*1024 {256 KB};
  (*
  <EventsTable>
    <Events>
      <Event>
        <Handle/>
        <Name/>
      </Event>
      <Event/>
    </Events>
  </EventsTable>
  *)
  XML_EVENTS_ROOT  = 'EventsTable';
  XML_EVENTS       = 'Events';
  XML_EVENT        = 'Event';
  XML_EVENT_HANDLE = 'Handle';
  XML_EVENT_NAME   = 'Name';

  CSEMappingsTable        = 'SEMappings';
  CSEMappingsTimeout      = 10000 {ms};
  CSEMappingsMaxTableSize = 640*1024 {640 KB};
  (*
  <SEMapTable>
    <SEMappings>
      <SEMapping>
        <SubjectHandle/>
        <EventHandle/>
        <IsProducer/>
      </SEMapping>
      <SEMapping/>
    </SEMappings>
  </SEMapTable>
  *)
  XML_SEMAPPINGS_ROOT       = 'SEMapTable';
  XML_SEMAPPINGS            = 'SEMappings';
  XML_SEMAPPING             = 'SEMapping';
  XML_SEMAPPING_SUBJECT     = 'SubjectHandle';
  XML_SEMAPPING_EVENT       = 'EventHandle';
  XML_SEMAPPING_IS_PRODUCER = 'IsProducer';

  CEventQueueTable        = 'EventQueue';
  CEventQueueTimeout      = 10000 {ms};
  CEventQueueMaxTableSize = CLargestFastEvent*100{1600 KB}; // Room for 100 outstanging messages of maximum size
  (* Stored as a shared table, no XML. *)
  XML_EVENTQUEUE = 'EventQueue';

  // System events
  (*
  <System>
    <Message/>
    <Handle/>
    <Data/>
    <Data/>
  </System>
  *)
  {$IFDEF undef} //long versions for debugging purposes
  XML_SYSTEM_ROOT    = 'System';
  XML_SYSTEM_MESSAGE = 'Message';
  XML_SYSTEM_HANDLE  = 'Handle';
  XML_SYSTEM_DATA    = 'Data';
  {$ELSE} //short versions for speed
  XML_SYSTEM_ROOT    = 'S';
  XML_SYSTEM_MESSAGE = 'M';
  XML_SYSTEM_HANDLE  = 'H';
  XML_SYSTEM_DATA    = 'D';
  {$ENDIF}

type
  TGpSharedEventManagerNotificationThread = class(TThread)
  private
    seNotificationEvent  : THandle;
    seNotificationMessage: UINT;
    seNotificationWindow : THandle;
  public
    TerminateEvent: THandle;
    constructor Create(notificationEvent, notificationWindow: THandle;
      notificationMessage: UINT);
    destructor  Destroy; override;
    procedure Execute; override;
    procedure Terminate;
  end; { TGpSharedEventManagerNotificationThread }

resourcestring
  sActiveSubjectAlreadyExists           = 'Subject %1:s already exists in the table %0:s';
  sCannotInitializeCountersTable        = 'Cannot initialize counters table %s. %s';
  sFailedToAcquiredSharedMemory         = 'Failed to acquire shared memory %s in %d milliseconds.';
  sFailedToCreateSubjectsTable          = 'Failed to create shared memory %s';
  sHandleNotFound                       = 'Handle %1:d not found in table %0:s.';
  sInvalidItemName                      = 'Invalid name %s.';
  sMalformedInternalMessage             = 'Shared event manager received malformed internal message %s.';
  sSubjectDoesNotExist                  = 'Subject %d does not exist';
  sSubjectDoesntPublishEvent            = 'Subject doesn''t publish event %s (%d)';
  sTryingToRemoveListenerFromUnexisting = 'Trying to remove a listener from unexisting event queue entry.';
  sTryingToRemoveUnexistingEventQueue   = 'Trying to remove unexisting event queue entry %d.';
  sTryingToRemoveUnexistingListener     = 'Trying to remove unexisting listener from the event queue entry.';
  sTryingToRetrieveNameForInvalidHandle = 'Trying to retrieve name for invalid handle %d';

{ TGpSharedEventManagerNotificationThread }

{:Create notification thread that is waiting on notification event and sending
  notification messages to the message window.
  @since   2002-10-17
}
constructor TGpSharedEventManagerNotificationThread.Create(notificationEvent,
  notificationWindow: THandle; notificationMessage: UINT);
begin
  seNotificationEvent := notificationEvent;
  seNotificationWindow := notificationWindow;
  seNotificationMessage := notificationMessage;
  TerminateEvent := CreateEvent(nil, true, false, nil);
  inherited Create(false);
end; { TGpSharedEventManagerNotificationThread.Create }

{:Destroy notification thread.
  @since   2002-10-17
}        
destructor TGpSharedEventManagerNotificationThread.Destroy;
begin
  if TerminateEvent <> 0 then begin
    CloseHandle(TerminateEvent);
    TerminateEvent := 0;
  end;
end; { TGpSharedEventManagerNotificationThread.Destroy }

{:Wait on notification event, then send notification message to the notification
  window.
  @since   2002-10-17
}        
procedure TGpSharedEventManagerNotificationThread.Execute;
var
  handles: array [0..1] of THandle;
begin
  handles[0] := seNotificationEvent;
  handles[1] := TerminateEvent;
  while WaitForMultipleObjects(2, @handles, false, INFINITE) = WAIT_OBJECT_0 do begin
    ResetEvent(seNotificationEvent);
    PostMessage(seNotificationWindow, seNotificationMessage, 0, 0);
  end; //while
end; { TGpSharedEventManagerNotificationThread.Execute }

{:Terminate notification thread.
  @since   2002-10-17
}        
procedure TGpSharedEventManagerNotificationThread.Terminate;
begin
  inherited Terminate;
  SetEvent (TerminateEvent);
end; { TGpSharedEventManagerNotificationThread.Terminate }

{ TGpSEHandleList }

function TGpSEHandleList.Add(item: TGpSEHandle): integer;
begin
  Result := inherited Add(integer(item));
end; { TGpSEHandleList.Add }

constructor TGpSEHandleList.Create;
begin
  inherited Create;
  Sorted := true;
  Duplicates := dupIgnore;
end; { TGpSEHandleList.Create }

function TGpSEHandleList.GetItem(idx: integer): TGpSEHandle;
begin
  Result := TGpSEHandle(GetItems(idx));
end; { TGpSEHandleList.GetItem }

procedure TGpSEHandleList.SetItem(idx: integer; const value: TGpSEHandle);
begin
  SetItems(idx, integer(value));
end; { TGpSEHandleList.SetItem }

{ TGpSEXMLData }

function TGpSEXMLData.GetXMLProp(index: integer): string;
begin
  Result := inherited GetXMLProp(index);
end; { TGpSEXMLData.GetXMLProp }

function TGpSEXMLData.GetXMLPropSEHandle(index: integer): TGpSEHandle;
begin
  Result := TGpSEHandle(GetXMLPropCardinal(index));
end; { TGpSEXMLData.GetXMLPropSEHandle }

procedure TGpSEXMLData.SetXMLProp(const index: integer; const value: string);
begin
  inherited;
end; { TGpSEXMLData.SetXMLProp }

procedure TGpSEXMLData.SetXMLPropSEHandle(const index: integer; const value: TGpSEHandle);
begin
  SetXMLPropCardinal(index, cardinal(value));
end; { TGpSEXMLData.SetXMLPropSEHandle }

{ TGpSESubject }

constructor TGpSESubject.Create(subjectNode: IXMLNode);
begin
  inherited Create(subjectNode);
  InitChildNodes(
    [XML_SUBJECT_HANDLE,        XML_SUBJECT_NAME, XML_SUBJECT_TOKEN, XML_SUBJECT_INTEREST, XML_SUBJECT_IS_PRODUCER],
    [integer(CInvalidSEHandle), '',               CInvalidSEToken,   0,                    false]);
end; { TGpSESubject.Create }

{ TGpSEEvent }

constructor TGpSEEvent.Create(eventNode: IXMLNode);
begin
  inherited Create(eventNode);
  InitChildNodes(
    [XML_SUBJECT_HANDLE,        XML_SUBJECT_NAME],
    [integer(CInvalidSEHandle), '']);
end; { TGpSEEvent.Create }

{ TGpSESEMappings }

constructor TGpSESEMapping.Create(seMappingNode: IXMLNode);
begin
  inherited Create(seMappingNode);
  InitChildNodes(
    [XML_SEMAPPING_SUBJECT,     XML_SEMAPPING_EVENT,       XML_SEMAPPING_IS_PRODUCER],
    [integer(CInvalidSEHandle), integer(CInvalidSEHandle), false]);
end; { TGpSESEMapping.Create }

{ TGpSEEventQueueEntryListener }

function TGpSEEventQueueEntryListener.GetListener: TGpSEHandle;
begin
  Result := TGpSEHandle(StrToInt(Text));
end; { TGpSEEventQueueEntryListener.GetListener }

procedure TGpSEEventQueueEntryListener.SetListener(const value: TGpSEHandle);
begin
  Text := IntToStr(value);
end; { TGpSEEventQueueEntryListener.SetListener }

{ TGpSEEventQueueEntry }

procedure TGpSEEventQueueEntry.AfterFetch;
var
  strListeners: TMemoryStream;
begin
  inherited;
  strListeners := TMemoryStream.Create;
  try
    GetFieldStream(CRecListeners, strListeners);
    strListeners.Position := 0;
    eqeListeners.LoadFromStream(strListeners);
  finally FreeAndNil(strListeners); end;
end; { TGpSEEventQueueEntry.AfterFetch }

procedure TGpSEEventQueueEntry.BeforePost;
var
  strListeners: TMemoryStream;
begin
  strListeners := TMemoryStream.Create;
  try
    eqeListeners.SaveToStream(strListeners);
    if not EqualsField(CRecListeners, strListeners.Size, strListeners.Memory^) then begin
      strListeners.Position := 0;
      SetFieldStream(CRecListeners, strListeners);
    end;
  finally FreeAndNil(strListeners); end;
  inherited;
end; { TGpSEEventQueueEntry.BeforePost }

constructor TGpSEEventQueueEntry.Create(owner: TGpBaseSharedTable);
begin
  inherited;
  eqeListeners := TGpSEHandleList.Create;
end; { TGpSEEventQueueEntry.Create }

destructor TGpSEEventQueueEntry.Destroy;
begin
  FreeAndNil(eqeListeners);
  inherited;
end; { TGpSEEventQueueEntry.Destroy }

function TGpSEEventQueueEntry.GetFieldHandle(idxField: integer): TGpSEHandle;
begin
  Result := TGpSEHandle(GetFieldCardinal(idxField));
end; { TGpSEEventQueueEntry.GetFieldHandle }

procedure TGpSEEventQueueEntry.SetFieldHandle(idxField: integer; value: TGpSEHandle);
begin
  SetFieldCardinal(idxField, cardinal(value));
end; { TGpSEEventQueueEntry.SetFieldHandle }

{ TGpSESubjectList }

function TGpSESubjectList.Add: TGpSESubject;
begin
  Result := (inherited Add) as TGpSESubject;
end;  { TGpSESubjectList.Add }

{:Collect handles of dead subjects into a list.
  @since   2002-10-01
}        
procedure TGpSESubjectList.CollectInvalidSubjects(subjectList: TGpSEHandleList);
var
  iSubject: integer;
begin
  subjectList.Clear;
  for iSubject := 0 to Count-1 do
    if not TGpToken.IsTokenPublished(Items[iSubject].Token) then
      subjectList.Add(Items[iSubject].Handle);
end; { TGpSESubjectList.CollectInvalidSubjects }

constructor TGpSESubjectList.Create;
begin
  inherited Create(XML_SUBJECTS_ROOT, XML_SUBJECTS, XML_SUBJECT, TGpSESubject);
end; { TGpSESubjectList.Create }

function TGpSESubjectList.GetSubject(idx: integer): TGpSESubject;
begin
  Result := (Get(idx) as TGpSESubject);
end; { TGpSESubjectList.GetSubject }

{:Return list position of the specified subject handle.
}
function TGpSESubjectList.IndexOf(subjectHandle: TGpSEHandle): integer;
begin
  for Result := 0 to Count-1 do
    if Items[Result].Handle = subjectHandle then
      Exit;
  Result := -1;
end; { TGpSESubjectList.IndexOf }

{:Locate subject by handle.
  @since   2002-09-24
}        
function TGpSESubjectList.LocateSubject(subjectHandle: TGpSEHandle): TGpSESubject;
var
  iSubject: integer;
begin
  isubject := indexof(subjectHandle);
  if isubject < 0 then
    result := nil
  else
    Result := Items[iSubject];
end; { TGpSESubjectList.LocateSubject }

function TGpSESubjectList.Name(subjectHandle: TGpSEHandle): string;
var
  iSubject: integer;
begin
  iSubject := IndexOf(subjectHandle);
  if iSubject < 0 then
    Result := ''
  else
    Result := Items[iSubject].Name;
end; { TGpSESubjectList.Name }

{:Remove dead subjects from the list.
  @since   2002-10-01
}        
procedure TGpSESubjectList.RemoveInvalidSubjects(subjectList: TGpSEHandleList);
var
  iSubject: integer;
begin
  iSubject := 0;
  while iSubject < Count do begin
    if subjectList.IndexOf(Items[iSubject].Handle) >= 0 then
      Delete(Items[iSubject])
    else
      Inc(iSubject);
  end; //while
end; { TGpSESubjectList.RemoveInvalidSubjects }

function TGpSESubjectList.Token(subjectHandle: TGpSEHandle): string;
var
  iSubject: integer;
begin
  iSubject := IndexOf(subjectHandle);
  if iSubject < 0 then
    Result := ''
  else
    Result := Items[iSubject].Token;
end; { TGpSESubjectList.Token }

{ TGpSEEventsList }

function TGpSEEventList.Add: TGpSEEvent;
begin
  Result := (inherited Add) as TGpSEEvent;
end; { TGpSEEventList.Add }

constructor TGpSEEventList.Create;
begin
  inherited Create(XML_EVENTS_ROOT, XML_EVENTS, XML_EVENT, TGpSEEvent);
end; { TGpSEEventList.Create }

function TGpSEEventList.GetEvent(idx: integer): TGpSEEvent;
begin
  Result := (Get(idx) as TGpSEEvent);
end; { TGpSEEventList.GetEvent }

{:Return list position of the specified event.
}
function TGpSEEventList.IndexOf(const eventName: string): integer;
begin
  for Result := 0 to Count-1 do
    if AnsiSameText(Items[Result].Name, eventName) then
      Exit;
  Result := -1;
end; { TGpSEEventList.IndexOf }

{:Return handle of the specified event.
  @since   2002-09-24
}
function TGpSEEventList.Locate(const eventName: string): TGpSEHandle;
var
  iEvent: integer;
begin
  iEvent := IndexOf(eventName);
  if iEvent < 0 then
    Result := CInvalidSEHandle
  else
    Result := Items[iEvent].Handle;
end; { TGpSEEventList.Locate }

{:Return index of the specified handle.
  @since   2002-09-29
}        
function TGpSEEventList.LocateEvent(const eventHandle: TGpSEHandle): integer;
begin
  for Result := 0 to Count-1 do
    if Items[Result].Handle = eventHandle then
      Exit;
  Result := -1;
end; { TGpSEEventList.LocateEvent }

{:Return name of the specified handle.
  @since   2002-09-24
}
function TGpSEEventList.Name(eventHandle: TGpSEHandle): string;
var
  iEvent: integer;
begin
  Result := '';
  for iEvent := 0 to Count-1 do
    if Items[iEvent].Handle = eventHandle then begin
      Result := Items[iEvent].Name;
      break; //for iEvent
    end;
end; { TGpSEEventList.Name }

{ TGpSESEMappingList }

function TGpSESEMappingList.Add: TGpSESEMapping;
begin
  Result := (inherited Add) as TGpSESEMapping;
end; { TGpSESEMappingList.Add }

constructor TGpSESEMappingList.Create;
begin
  inherited Create(XML_SEMAPPINGS_ROOT, XML_SEMAPPINGS, XML_SEMAPPING, TGpSESEMapping);
end; { TGpSESEMappingList.Create }

function TGpSESEMappingList.GetSEMapping(idx: integer): TGpSESEMapping;
begin
  Result := (Get(idx) as TGpSESEMapping);
end; { TGpSESEMappingList.GetSEMapping }

function TGpSESEMappingList.IndexOf(subjectHandle,
  eventHandle: TGpSEHandle): integer;
begin
  for Result := 0 to Count-1 do
    if (Items[Result].Subject = subjectHandle) and
       (Items[Result].Event = eventHandle)
    then
      Exit;
  Result := -1;
end; { TGpSESEMappingList.IndexOf }

{:Remove mappings for the dead subjects from the table.
  @since   2002-10-01
}        
procedure TGpSESEMappingList.RemoveInvalidSubjects(subjectList: TGpSEHandleList);
var
  iMapping: integer;
begin
  iMapping := 0;
  while iMapping < Count do begin
    if subjectList.IndexOf(Items[iMapping].Subject) < 0 then
      Delete(Items[iMapping])
    else
      Inc(iMapping);
  end; //while
end; { TGpSESEMappingList.RemoveInvalidSubjects }

{ TGpSECounters }

constructor TGpSECounters.Create(namespace: string);
begin
  inherited Create(namespace+CDelim+CCountersTable, 0, CCountersMaxTableSize);
  if not Initialize then
    raise EGpSharedEventManager.CreateFmt(sCannotInitializeCountersTable,
      [Name, LastError]);
end; { TGpSECounters.Create }

function TGpSECounters.Increment(const counterName: AnsiString): integer;
begin
  Result := inherited Increment(counterName);
end; { TGpSECounters.Increment }

{ TGpSESubjects }

{:Read-access Subjects table.
  @since   2002-09-24
}
function TGpSESubjects.AccessSubjects: TGpSESubjectList;
begin
  Result := seSubjData.XML as TGpSESubjectList;
  if not assigned(Result) then
    Result := seSubjData.Read(CSubjectsTimeout) as TGpSESubjectList;
end; { TGpSESubjects.AccessSubjects }

{:Access cached copy of the Subjects table.
  @since   2002-09-24
}
function TGpSESubjects.CachedSubjects: TGpSESubjectList;
begin
  Result := seSubjData.CachedXML as TGpSESubjectList;
end; { TGpSESubjects.CachedSubjects }

{:Collect handles of all dead subjects into a list.
  @since   2002-10-01
}        
function TGpSESubjects.CollectInvalidSubjects(subjectList: TGpSEHandleList): boolean;
var
  subjects: TGpSESubjectList;
begin
  subjects := AccessSubjects;
  if not assigned(subjects) then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seSubjData.Name, CSubjectsTimeout])
  else begin
    subjects.CollectInvalidSubjects(subjectList);
    Result := ClearError;
  end;
end; { TGpSESubjects.CollectInvalidSubjects }

{:Create Subjects table in the specified namespace.
}
constructor TGpSESubjects.Create(namespace: string; counters: TGpSECounters;
  SEMappings: TGpSESEMappings; manager: TGpSharedEventManager);
begin
  inherited Create;
  seCounters := counters;
  seManager := Manager;
  seSEMappings := SEMappings;
  seSubjData := TGpSharedXMLList.Create(namespace+CDelim+CSubjectsTable,
    TGpSESubjectList.Create, CSubjectsMaxTableSize);
end; { TGpSESubjects.Create }

{:Destroy Subjects table.
}
destructor TGpSESubjects.Destroy;
begin
  FreeAndNil(seSubjData);
  inherited;
end; { TGpSESubjects.Destroy }

{:Remove dead entries from the Subjects table.
  @since   2002-09-25
}
procedure TGpSESubjects.FilterSubjects(subjectList: TGpSEHandleList);
var
  haveInvalidSubject: boolean;
  iSubject          : integer;
  iSubjectList      : integer;
  isWriting         : boolean;
  subjects          : TGpSESubjectList;
begin
  subjects := AccessSubjects;
  if assigned(subjects) then begin
    isWriting := false;
    try
      haveInvalidSubject := false;
      iSubjectList := 0;
      while iSubjectList < subjectList.Count do begin
        iSubject := subjects.IndexOf(subjectList[iSubjectList]);
        if (iSubject < 0) or (not TGpToken.IsTokenPublished(subjects[iSubject].Token)) then
        begin
          if not isWriting then begin
            subjects := seSubjData.BeginUpdate(CSubjectsTimeout) as TGpSESubjectList;
            if not assigned(subjects) then
              Exit;
            isWriting := true;
          end;
          if iSubject >= 0 then begin
            seSEMappings.DeleteAllEvents(subjects[iSubject].Handle);
            subjects.Delete(subjects[iSubject]);
          end;
          subjectList.Delete(iSubjectList);
          haveInvalidSubject := true;
        end
        else
          Inc(iSubjectList);
      end; //while
      if haveInvalidSubject then
        seManager.TriggerValidityRescan;
    finally
      if isWriting then
        seSubjData.EndUpdate;
    end;
  end;
end; { TGpSESubjects.FilterSubjects }

{:Retrieve all listeners.
  @param   interestFlags Required Interest flags.
  @param   subjects      (out) List of all registered subjects.
  @since   2002-09-23
}
function TGpSESubjects.GetAllSubjects(interestFlags: integer;
  allSubjects: TGpSEHandleList): boolean;
var
  iSubject: integer;
  subjects: TGpSESubjectList;
begin
  allSubjects.Clear;
  subjects := AccessSubjects;
  if not assigned(subjects) then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seSubjData.Name, CSubjectsTimeout])
  else begin
    for iSubject := 0 to subjects.Count-1 do
      if (interestFlags = 0) or
         ((interestFlags AND subjects[iSubject].Interest) = interestFlags) then
        allSubjects.Add(subjects[iSubject].Handle);
    Result := ClearError;
  end;
end; { TGpSESubjects.GetAllSubjects }

{:Retrieve names of all producers and/or listeners.
  @since   2002-10-03
}
function TGpSESubjects.GetSubjects(subjectsList: TStrings; getProducers,
  getListeners: boolean): boolean;
var
  iSubject: integer;
  subjects: TGpSESubjectList;
begin
  subjectsList.Clear;
  subjects := AccessSubjects;
  if not assigned(subjects) then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seSubjData.Name, CSubjectsTimeout])
  else begin
    for iSubject := 0 to subjects.Count-1 do
      if (getProducers and subjects[iSubject].IsProducer) or
         (getListeners and (not subjects[iSubject].IsProducer)) then
        subjectsList.Add(subjects[iSubject].Name);
    Result := ClearError;
  end;
end; { TGpSESubjects.GetSubjects }

{:Retrieve subject's name.
  @since   2002-09-24
}
function TGpSESubjects.Name(subjectHandle: TGpSEHandle): string;
var
  subjects: TGpSESubjectList;
begin
  Result := '';
  subjects := CachedSubjects;
  if assigned(subjects) then
    Result := subjects.Name(subjectHandle);
  if Result = '' then begin
    subjects := AccessSubjects;
    if assigned(subjects) then
      Result := subjects.Name(subjectHandle);
  end;
end; { TGpSESubjects.Name }

{:Notify all listeners in the list that new event is awaiting them in the event
  queue.
  @param   listeners  List of the listeners (handles).
  @since   2002-09-23
}
function TGpSESubjects.NotifyListeners(listeners: TGpSEHandleList): boolean;
var
  iListener        : integer;
  iSubject         : integer;
  notificationEvent: THandle{CreateEvent};
  subjects         : TGpSESubjectList;
begin
  subjects := AccessSubjects;
  if not assigned(subjects) then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seSubjData.Name, CSubjectsTimeout])
  else begin
    for iListener := 0 to listeners.Count-1 do begin
      iSubject := subjects.IndexOf(listeners[iListener]);
      if iSubject >= 0 then begin
        notificationEvent := OpenEvent(EVENT_MODIFY_STATE, false,
          PChar(TGpSharedEventManager.MakeNotificationEventName(subjects[iSubject].Token)));
        try
          if notificationEvent <> 0 then
            SetEvent(notificationEvent);
        finally CloseHandle(notificationEvent); end;
      end;
    end; //for
    Result := ClearError;
  end;
end; { TGpSESubjects.NotifyListeners }

{:Insert subject into the table. If same (subjectName, subjectToken) already
  exists in the table, return its handle. Otherwise insert the data into the
  table.
  @param   subjectName   Name of the subject to be registered.
  @param   subjectToken  Subject's token.
  @returns Handle of the registered subject.
}
function TGpSESubjects.RegisterSubject(subjectName: TGpSEID;
  subjectToken: TGpSEToken; subjectIsProducer: boolean): TGpSEHandle;
var
  iSubject: integer;
  subjects: TGpSESubjectList;
begin
  subjects := seSubjData.BeginUpdate(CSubjectsTimeout) as TGpSESubjectList;
  if not assigned(subjects) then begin
    SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seSubjData.Name, CSubjectsTimeout]);
    Result := CInvalidSEHandle;
  end
  else begin
    try
      for iSubject := 0 to subjects.Count-1 do begin
        if AnsiSameText(subjects[iSubject].Name, subjectName) and
           (subjects[iSubject].Token = subjectToken) then
        begin
          // Exact match - this producer has been already registered
          Result := subjects[iSubject].Handle;
          ClearError;
          Exit;
        end;
      end; //for
      // Subject not found, insert it.
      with subjects.Add do begin
        Handle     := seCounters.Increment(XML_SUBJECTS);
        Name       := subjectName;
        Token      := subjectToken;
        IsProducer := subjectIsProducer;
      end; //with
      Result := subjects[subjects.Count-1].Handle;
      ClearError;
    finally seSubjData.EndUpdate; end;
  end;
end; { TGpSESubjects.RegisterSubject }

{:Remove dead subjects from the table.
  @since   2002-10-01
}
function TGpSESubjects.RemoveInvalidSubjects(subjectList: TGpSEHandleList): boolean;
var
  subjects: TGpSESubjectList;
begin
  subjects := seSubjData.BeginUpdate(CSubjectsTimeout) as TGpSESubjectList;
  if not assigned(subjects) then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seSubjData.Name, CSubjectsTimeout])
  else begin
    try
      subjects.RemoveInvalidSubjects(subjectList);
      Result := ClearError;
    finally seSubjData.EndUpdate; end;
  end;
end; { TGpSESubjects.RemoveInvalidSubjects }

{:Change subject's interest flags.
  @since   2002-10-01
}
function TGpSESubjects.ResetInterest(subjectHandle: TGpSEHandle;
  newInterest: integer): boolean;
var
  iSubject: integer;
  subjects: TGpSESubjectList;
begin
  subjects := seSubjData.BeginUpdate(CSubjectsTimeout) as TGpSESubjectList;
  if not assigned(subjects) then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seSubjData.Name, CSubjectsTimeout])
  else begin
    try
      iSubject := subjects.IndexOf(subjectHandle);
      if iSubject < 0 then
        raise EGpSharedEventManager.CreateFmt(sSubjectDoesNotExist,[subjectHandle]);
      subjects[iSubject].Interest := newInterest;
    finally seSubjData.EndUpdate; end;
    Result := ClearError;
  end;
end; { TGpSESubjects.ResetInterest }

{:Retrieve subject's name.
  @since   2002-09-26
}
function TGpSESubjects.Token(subjectHandle: TGpSEHandle): string;
var
  subjects: TGpSESubjectList;
begin
  Result := '';
  subjects := CachedSubjects;
  if assigned(subjects) then
    Result := subjects.Token(subjectHandle);
  if Result = '' then begin
    subjects := AccessSubjects;
    if assigned(subjects) then
      Result := subjects.Token(subjectHandle);
  end;
end; { TGpSESubjects.Token }

{:Remove subject from the table.
  @returns False if table cannot be acquired.
}
function TGpSESubjects.UnregisterSubject(subjectHandle: TGpSEHandle): boolean;
var
  iSubject: integer;
  subjects: TGpSESubjectList;
begin
  subjects := seSubjData.BeginUpdate(CSubjectsTimeout) as TGpSESubjectList;
  if not assigned(subjects) then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seSubjData.Name, CSubjectsTimeout])
  else begin
    try
      iSubject := subjects.IndexOf(subjectHandle);
      if iSubject >= 0 then
        subjects.Delete(subjects[iSubject]);
      Result := ClearError;
    finally seSubjData.EndUpdate; end;
  end;
end; { TGpSESubjects.UnregisterSubject }

{ TGpSEEvents }

{:Read-access Events table.
  @since   2002-09-24
}        
function TGpSEEvents.AccessEvents: TGpSEEventList;
begin
  Result := seEventData.XML as TGpSEEventList;
  if not assigned(Result) then
    Result := seEventData.Read(CEventsTimeout) as TGpSEEventList;
end; { TGpSEEvents.AccessEvents }

{:Access cached copy of the Events table.
  @since   2002-09-24
}
function TGpSEEvents.CachedEvents: TGpSEEventList;
begin
  Result := seEventData.CachedXML as TGpSEEventList;
end; { TGpSEEvents.CachedEvents }

{:Create Events table in the specified namespace.
}
constructor TGpSEEvents.Create(namespace: string);
begin
  inherited Create;
  seEventData := TGpSharedXMLList.Create(namespace+CDelim+CEventsTable,
    TGpSEEventList.Create, CEventsMaxTableSize);
end; { TGpSEEvents.Create }

{:Destroy Events table.
}
destructor TGpSEEvents.Destroy;
begin
  FreeAndNil(seEventData);
  inherited;
end; { TGpSEEvents.Destroy }

{:Retrieve names of all events.
  @since   2002-10-03
}        
function TGpSEEvents.GetEvents(eventsList: TStrings): boolean;
var
  events: TGpSEEventList;
  iEvent: integer;
begin
  eventsList.Clear;
  events := AccessEvents;
  if not assigned(events) then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seEventData.Name, CEventsTimeout])
  else begin
    for iEvent := 0 to events.Count-1 do
      eventsList.Add(events[iEvent].Name);
    Result := ClearError;
  end;
end; { TGpSEEvents.GetEvents }

{:Return list position of the specified event.
}
function TGpSEEvents.IndexOf(const eventName: string): integer;
var
  events: TGpSEEventList;
begin
  Result := -1;
  events := CachedEvents;
  if assigned(events) then
    Result := events.IndexOf(eventName);
  if Result < 0 then begin
    events := AccessEvents;
    if assigned(events) then
      Result := events.IndexOf(eventName);
  end;
end; { TGpSEEvents.IndexOf }

{:Locate the event by its name and return its handle.
}
function TGpSEEvents.Locate(eventName: string): TGpSEHandle;
var
  events: TGpSEEventList;
begin
  Result := CInvalidSEHandle;
  events := CachedEvents;
  if assigned(events) then
    Result := events.Locate(eventName);
  if Result = CInvalidSEHandle then begin
    events := AccessEvents;
    if assigned(events) then
      Result := events.Locate(eventName);
  end;
end; { TGpSEEvents.Locate }

{:Map event handles to event names.
  @since   2002-09-29
}
function TGpSEEvents.MapEventsToNames(eventHandleList: TGpSEHandleList;
  eventNameList: TStrings): boolean;
var
  events      : TGpSEEventList;
  iEvent      : integer;
  iEventHandle: integer;
begin
  events := CachedEvents;
  if not assigned(events) then
    events := AccessEvents;
  if not assigned(events) then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seEventData.Name, CEventsTimeout])
  else begin
    eventNameList.Clear;
    for iEvent := 0 to eventHandleList.Count-1 do begin
      iEventHandle := events.LocateEvent(eventHandleList[iEvent]);
      if iEventHandle < 0 then
        raise EGpSharedEventManager.CreateFmt(sTryingToRetrieveNameForInvalidHandle,[eventHandleList[iEvent]]);
      eventNameList.Add(events[iEventHandle].Name);
    end; //for
    Result := ClearError;
  end;
end; { TGpSEEvents.MapEventsToNames }

{:Locate the event by its handle and return its name.
}
function TGpSEEvents.Name(eventHandle: TGpSEHandle): string;
var
  events: TGpSEEventList;
begin
  Result := '';
  events := CachedEvents;
  if assigned(events) then
    Result := events.Name(eventHandle);
  if Result = '' then begin
    events := AccessEvents;
    if assigned(events) then
      Result := events.Name(eventHandle);
  end;
end; { TGpSEEvents.Name }

{:Insert event into the table.
  @returns Event handle or CInvalidSEHandle if table cannot be acquired.
}
function TGpSEEvents.RegisterEvent(eventName: string): TGpSEHandle;
var
  events        : TGpSEEventList;
  iEvent        : integer;
  maxEventHandle: cardinal;
begin
  events := seEventData.BeginUpdate(CEventsTimeout) as TGpSEEventList;
  if not assigned(events) then begin
    SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seEventData.Name, CEventsTimeout]);
    Result := CInvalidSEHandle;
  end
  else begin
    try
      iEvent := events.IndexOf(eventName);
      if iEvent >= 0 then
        Result := events[iEvent].Handle
      else begin
        // Event not found, insert it.
        // TODO 3 -oPrimoz Gabrijelcic: This should probably use Counters table
        maxEventHandle := Low(TGpSEHandle);
        for iEvent := 0 to events.Count-1 do
          if events[iEvent].Handle > maxEventHandle then
            maxEventHandle := events[iEvent].Handle;
        Inc(maxEventHandle);
        with events.Add do begin
          Handle := maxEventHandle;
          Name   := eventName;
        end; //with
        Result := events[events.Count-1].Handle;
      end;
      ClearError;
    finally seEventData.EndUpdate; end;
  end;
end; { TGpSEEvents.RegisterEvent }

{:Remove event from the table.
  @returns False if table cannot be acquired.
}
function TGpSEEvents.UnregisterEvent(eventName: string): boolean;
var
  events: TGpSEEventList;
  iEvent: integer;
begin
  events := seEventData.BeginUpdate(CEventsTimeout) as TGpSEEventList;
  if not assigned(events) then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seEventData.Name, CEventsTimeout])
  else begin
    try
      iEvent := events.IndexOf(eventName);
      if iEvent >= 0 then
        events.Delete(events[iEvent]);
      Result := ClearError;
    finally seEventData.EndUpdate; end;
  end;
end; { TGpSEEvents.UnregisterEvent }

{ TGpSESEMappings }

{:Read-access Subjects-Events Mappings table.
  @since   2002-09-24
}
function TGpSESEMappings.AccessMappings: TGpSESEMappingList;
begin
  Result := seSEMappingData.XML as TGpSESEMappingList;
  if not assigned(Result) then
    Result := seSEMappingData.Read(CEventsTimeout) as TGpSESEMappingList;
end; { TGpSESEMappings.AccessMappings }

{:Insert subject-event mapping into the table.
  @returns False if table cannot be acquired.
}
function TGpSESEMappings.AddMapping(subjectHandle, eventHandle: TGpSEHandle;
  subjectIsProducer: boolean): boolean;
var
  seMappings: TGpSESEMappingList;
begin
  seMappings := seSEMappingData.BeginUpdate(CSEMappingsTimeout) as TGpSESEMappingList;
  if not assigned(seMappings) then begin
    SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seSEMappingData.Name, CSEMappingsTimeout]);
    Result := false
  end
  else begin
    try
      if IndexOf(subjectHandle, eventHandle) < 0 then begin
        // Mapping not found, insert it.
        with seMappings.Add do begin
          Subject    := subjectHandle;
          Event      := eventHandle;
          IsProducer := subjectIsProducer;
        end; //with
      end;
      Result := ClearError;
    finally seSEMappingData.EndUpdate; end;
  end;
end; { TGpSESEMappings.AddMapping }

{:Access cached copy of the Subjects-Events Mappings table.
  @since   2002-09-29
}
function TGpSESEMappings.CachedMappings: TGpSESEMappingList;
begin
  Result := seSEMappingData.CachedXML as TGpSESEMappingList;
end; { TGpSESEMappings.CachedMappings }

{:Create Subjects-Events Mappings table in the specified namespace.
}
constructor TGpSESEMappings.Create(namespace: string);
begin
  inherited Create;
  seSEMappingData := TGpSharedXMLList.Create(namespace+CDelim+CSEMappingsTable,
    TGpSESEMappingList.Create, CSEMappingsMaxTableSize);
end; { TGpSESEMappings.Create }

{:Remove all subject-event mappings for the specified subject.
  @returns False if table cannot be acquired.
}
function TGpSESEMappings.DeleteAllEvents(subjectHandle: TGpSEHandle): boolean;
var
  iSEMapping: integer;
  seMappings: TGpSESEMappingList;
begin
  seMappings := seSEMappingData.BeginUpdate(CSEMappingsTimeout) as TGpSESEMappingList;
  if not assigned(seMappings) then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seSEMappingData.Name, CSEMappingsTimeout])
  else begin
    try
      iSEMapping := 0;
      while iSEMapping < seMappings.Count do begin
        if seMappings[iSEMapping].Subject = subjectHandle then
          seMappings.Delete(seMappings[iSEMapping])
        else
          Inc(iSEMapping);
      end; //while
      Result := ClearError;
    finally seSEMappingData.EndUpdate; end;
  end;
end; { TGpSESEMappings.DeleteAllEvents }

{:Remove subject-event mapping from the table.
  @returns False if table cannot be acquired.
}
function TGpSESEMappings.DeleteMapping(subjectHandle, eventHandle: TGpSEHandle): boolean;
var
  iSEMapping: integer;
  seMappings: TGpSESEMappingList;
begin
  seMappings := seSEMappingData.BeginUpdate(CSEMappingsTimeout) as TGpSESEMappingList;
  if not assigned(seMappings) then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seSEMappingData.Name, CSEMappingsTimeout])
  else begin
    try
      iSEMapping := IndexOf(subjectHandle, eventHandle);
      if iSEMapping >= 0 then
        seMappings.Delete(seMappings[iSEMapping]);
      Result := ClearError;
    finally seSEMappingData.EndUpdate; end;
  end;
end; { TGpSESEMappings.DeleteMapping }

{:Destroy Events table.
}
destructor TGpSESEMappings.Destroy;
begin
  FreeAndNil(seSEMappingData);
  inherited;
end; { TGpSESEMappings.Destroy }

{:Retrieve all subjects that have registered interest in the specified event.
  @since   2002-09-29
}
function TGpSESEMappings.GetEvents(subjectHandle: TGpSEHandle; eventList: TGpSEHandleList;
  getProducers, getListeners, getFromCache: boolean): boolean;
var
  iMapping  : integer;
  seMappings: TGpSESEMappingList;
begin
  eventList.Clear;
  seMappings := nil;
  if getFromCache then
    seMappings := CachedMappings;
  if not assigned(seMappings) then
    seMappings := AccessMappings;
  if not assigned(seMappings) then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seSEMappingData.Name, CEventsTimeout])
  else begin
    for iMapping := 0 to seMappings.Count-1 do
      if (seMappings[iMapping].Subject = subjectHandle) and
         ((getProducers and seMappings[iMapping].IsProducer) or
          (getListeners and (not seMappings[iMapping].IsProducer)))
      then
        eventList.Add(seMappings[iMapping].Event);
    Result := ClearError;
  end;
end; { TGpSESEMappings.GetEvents }

{:Retrieve all listeners that have registered interest in the specified event.
  @param   eventHandle Handle of the event in interest.
  @param   listeners   (out) List of the registered listeners for this event.
                       Must already exist.
  @since   2002-05-31
}
function TGpSESEMappings.GetListeners(eventHandle: TGpSEHandle; listeners:
  TGpSEHandleList): boolean;
var
  iMapping  : integer;
  seMappings: TGpSESEMappingList;
begin
  seMappings := AccessMappings;
  if not assigned(seMappings) then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seSEMappingData.Name, CEventsTimeout])
  else begin
    for iMapping := 0 to seMappings.Count-1 do
      if (seMappings[iMapping].Event = eventHandle) and
         (not seMappings[iMapping].IsProducer)
      then
        listeners.Add(seMappings[iMapping].Subject);
    Result := ClearError;
  end;
end; { TGpSESEMappings.GetListeners }

{:Return list position of the specified mapping
}
function TGpSESEMappings.IndexOf(subjectHandle, eventHandle: TGpSEHandle): integer;
var
  seMappings: TGpSESEMappingList;
begin
  seMappings := AccessMappings;
  Result := seMappings.IndexOf(subjectHandle, eventHandle);
end; { TGpSESEMappings.IndexOf }

{:Remove mappings for dead subjects from the table.
  @since   2002-10-01
}        
function TGpSESEMappings.RemoveInvalidSubjects(subjectList: TGpSEHandleList): boolean;
var
  seMappings: TGpSESEMappingList;
begin
  seMappings := seSEMappingData.BeginUpdate(CSEMappingsTimeout) as TGpSESEMappingList;
  if not assigned(seMappings) then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seSEMappingData.Name, CSEMappingsTimeout])
  else begin
    try
      seMappings.RemoveInvalidSubjects(subjectList);
      Result := ClearError;
    finally seSEMappingData.EndUpdate; end;
  end;
end; { TGpSESEMappings.RemoveInvalidSubjects }

{:Check whether subject publishes specified event.
}
function TGpSESEMappings.SubjectPublishes(subjectHandle, eventHandle: TGpSEHandle;
  getFromCache: boolean; var publishes: boolean): boolean;
var
  seMappings: TGpSESEMappingList;
begin
  Result := ClearError;
  seMappings := nil;
  if getFromCache then
    seMappings := CachedMappings;
  if not assigned(seMappings) then
    seMappings := AccessMappings;
  if not assigned(seMappings) then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seSEMappingData.Name, CEventsTimeout])
  else
    publishes := (seMappings.IndexOf(subjectHandle, eventHandle) >= 0);
end; { TGpSESEMappings.SubjectPublishes }

{ TGpSEEventQueue }

{:Read-access Event Queue table.
  @since   2002-09-24
}
function TGpSEEventQueue.AccessEventQueue: boolean;
begin
  Result := seEventQueueData.Read(CEventQueueTimeout);
end; { TGpSEEventQueue.AccessEventQueue }

{:Write-access the event queue.
  @since   2002-09-26
}
function TGpSEEventQueue.BeginUpdate: boolean;
begin
  Result := seEventQueueData.BeginUpdate(CEventQueueTimeout);
end; { TGpSEEventQueue.BeginUpdate }

{:Create Event Queue table in the specified namespace.
}
constructor TGpSEEventQueue.Create(namespace: string; counters: TGpSECounters;
  subjects: TGpSESubjects; manager: TGpSharedEventManager);
begin
  inherited Create;
  {$IFDEF DebugSEEventQueue}
  seLogger := CreateGpLogger(ExtractFilePath(ParamStr(0))+'eventqueue.log',
    [loLogTime, loLogProcessID]);
  {$ENDIF DebugSEEventQueue}
  seCounters := counters;
  seSubjects := subjects;
  seManager := manager;
  seEventQueueData := TGpSharedTable.Create(namespace+CDelim+CEventQueueTable,
    TGpSEEventQueueEntry, 0, CEventQueueMaxTableSize);
  {$IFDEF DebugSEEventQueue}
  seLogger.Log('Initializing event queue %s', [seEventQueueData.Name]);
  {$ENDIF DebugSEEventQueue}
  if not seEventQueueData.Initialize(CEventQueueTimeout) then
    raise EGpSharedEventManager.CreateFmt('Failed to initialize EventQueue shared table. %s', [seEventQueueData.LastError]);
  {$IFDEF DebugSEEventQueue}
  if BeginUpdate then try
    DumpTable;
  finally EndUpdate; end;
  {$ENDIF DebugSEEventQueue}
end; { TGpSEEventQueue.Create }

{:Destroy Event Queue table.
}
destructor TGpSEEventQueue.Destroy;
begin
  FreeAndNil(seEventQueueData);
  inherited;
end; { TGpSEEventQueue.Destroy }

{$IFDEF DebugSEEventQueue}
procedure TGpSEEventQueue.DumpTable;
var
  iEntry: integer;
begin
  seLogger.Log('Handle'#9'Event'#9'Produc.'#9'Listen.'#9'Data');
  for iEntry := 0 to seEventQueueData.Count-1 do
    with Items[iEntry] do
      seLogger.Log(Format('%d'#9'%d'#9'%d'#9'%s'#9'%s',
        [Handle, Event, Producer, Listeners.AsDelimitedText('/'), Data]));
end; { TGpSEEventQueue.DumpTable }
{$ENDIF DebugSEEventQueue}

{:Release event queue.
  @since   2002-09-26
}
procedure TGpSEEventQueue.EndUpdate;
begin
  {$IFDEF DebugSEEventQueue}DumpTable;{$ENDIF DebugSEEventQueue}
  seEventQueueData.EndUpdate;
end; { TGpSEEventQueue.EndUpdate }

{:Process event that was fully sent. Remove it from the event queue and return
  its message handle and its shared memory object.
  @returns False if event queue cannot be acquired.
  @since   2002-09-25
}
function TGpSEEventQueue.EventSent(eventQueueHandle: TGpSEHandle;
  out eventHandle: TGpSEHandle;
  out sharedMemory: TGpSharedMemory): boolean;
var
  iEvent: integer;
begin
  {$IFDEF DebugSEEventQueue}
  seLogger.Log('EventSent(queue handle = %d)', [eventQueueHandle]);
  {$ENDIF DebugSEEventQueue}
  Result := ClearError;
  if not BeginUpdate then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seEventQueueData.Name, CEventsTimeout])
  else try
    iEvent := LocateHandle(eventQueueHandle);
    if iEvent < 0 then
      raise EGpSharedEventManager.CreateFmt(sTryingToRemoveUnexistingEventQueue, [eventQueueHandle]);
    eventHandle := Items[iEvent].Event;
    sharedMemory := TGpSharedMemory(Items[iEvent].SharedMemory);
    seEventQueueData.Delete(iEvent);
  finally EndUpdate; end;
  {$IFDEF DebugSEEventQueue}
  seLogger.Log('  => %s; event handle = %d, shared memory = %.8x',
    [IFF(Result, 'T', 'F'), eventHandle, cardinal(sharedMemory)]);
  {$ENDIF DebugSEEventQueue}
end; { TGpSEEventQueue.EventSent }

{:Collect indices of all entries that contain 'listener' in Listeners list.
  @since   2002-09-26
}
procedure TGpSEEventQueue.GetAllEntriesForListener(listener: TGpSEHandle;
  listenerList: TGpIntegerList);
var
  iEntry: integer;
begin
  {$IFDEF DebugSEEventQueue}
  seLogger.Log('GetAllEntriesForListener(listener = %d)', [listener]);
  DumpTable;
  {$ENDIF DebugSEEventQueue}
  listenerList.Clear;
  for iEntry := 0 to seEventQueueData.Count-1 do
    if Items[iEntry].Listeners.IndexOf(listener) >= 0 then
      listenerList.Add(Items[iEntry].Handle);
  {$IFDEF DebugSEEventQueue}
  seLogger.Log('  => listener list = %s', [listenerList.AsDelimitedText('/')]);
  {$ENDIF DebugSEEventQueue}
end; { TGpSEEventQueue.GetAllEntriesForListener }

function TGpSEEventQueue.GetItem(idxItem: integer): TGpSEEventQueueEntry;
begin
  Result := seEventQueueData[idxItem] as TGpSEEventQueueEntry;
end; { TGpSEEventQueue.GetItem }

{:Insert event into an event queue and return the handle of the event queue
  entry.
  @param   eventHandle      Handle of the event.
  @param   subjectHandle    Handle of the subject (producer or listener).
  @param   eventData        Data for the event.
  @param   eventDataSize    Size of the data.
  @param   eventListeners   List of the listeners that must receive the event.
  @param   isLargeMessage   If true, eventData contains name of the shared
                            memory where message data is kept.
  @param   eventQueueHandle (out) Handle of the created event queue entry.
  @since   2002-09-22
}
function TGpSEEventQueue.Insert(eventHandle, subjectHandle: TGpSEHandle;
  eventData: string; eventDataSize: cardinal; eventListeners: TGpSEHandleList;
  eventSharedMemory: TGpSharedMemory; out eventQueueHandle: TGpSEHandle): boolean;
var
  entry: TGpSEEventQueueEntry;
begin
  {$IFDEF DebugSEEventQueue}
  seLogger.Log('Insert(event handle = %d, subject handle = %d, event data = %s, '+
    'event data size = %d, event listeners = %s, event shared memory = %.8x',
    [eventHandle, subjectHandle, eventData, eventDataSize,
     eventListeners.AsDelimitedText('/'), cardinal(eventSharedMemory)]);
  {$ENDIF DebugSEEventQueue}
  Result := ClearError;
  eventQueueHandle := CInvalidSEHandle;
  if not BeginUpdate then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seEventQueueData.Name, CEventsTimeout])
  else try
    eventQueueHandle := seCounters.Increment(XML_EVENTQUEUE);
    entry := seEventQueueData.Add as TGpSEEventQueueEntry;
    with entry do begin
      Handle       := eventQueueHandle;
      Event        := eventHandle;
      Producer     := subjectHandle;
      Data         := eventData;
      DataSize     := eventDataSize;
      SharedMemory := cardinal(eventSharedMemory);
      Listeners.Assign(eventListeners);
    end; //with eventQueue.Add
  finally EndUpdate; end;
  {$IFDEF DebugSEEventQueue}
  seLogger.Log('  => %s; event queue handle = %d',
    [IFF(Result, 'T', 'F'), eventQueueHandle]);
  {$ENDIF DebugSEEventQueue}
end; { TGpSEEventQueue.Insert }

{:Locate event queue entry in the table (by handle) and return it.
  @param   eventQueueHandle Handle of the event queue entry to be located.
  @returns Event queue entry or nil if such entry doesn't exist in the table.
}
function TGpSEEventQueue.Locate(eventQueueHandle: TGpSEHandle): TGpSEEventQueueEntry;
var
  iEntry: integer;
begin
  {$IFDEF DebugSEEventQueue}
  seLogger.Log('Locate(event queue handle = %d)', [eventQueueHandle]);
  {$ENDIF DebugSEEventQueue}
  Result := nil;
  SetError(Ord(semErrNotFound), sHandleNotFound, [seEventQueueData.Name, eventQueueHandle]);
  if not AccessEventQueue then
    SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seEventQueueData.Name, CEventQueueTimeout])
  else begin
    iEntry := LocateHandle(eventQueueHandle);
    if iEntry >= 0 then begin
      Result := Items[iEntry];
      ClearError;
    end;
  end;
  {$IFDEF DebugSEEventQueue}
  seLogger.Log('  => %.8x(handle = %d, event = %d, producer = %d, data = %s, '+
    'data size = %d, shared memory = %.8x, listeners = %s)',
    [cardinal(Result), Result.Handle, Result.Event,
     Result.Producer, Result.Data, Result.DataSize,
     cardinal(Result.SharedMemory), Result.Listeners.AsDelimitedText('/')]);
  {$ENDIF DebugSEEventQueue}
end; { TGpSEEventQueue.Locate }

function TGpSEEventQueue.LocateHandle(eventQueueHandle: TGpSEHandle): integer;
begin
  Result := seEventQueueData.LocateCardinal(CRecHandle, eventQueueHandle);
end; { TGpSEEventQueue.LocateHandle }

{:Remove dead subjects from the table.
  @since   2002-10-01
}
function TGpSEEventQueue.RemoveInvalidSubjects(
  subjectList: TGpSEHandleList): boolean;
var
  iEntry   : integer;
  iListener: integer;
  iSubject : integer;
begin
  {$IFDEF DebugSEEventQueue}
  seLogger.Log('RemoveInvalidSubjects(%s)', [subjectList.AsDelimitedText('/')]);
  {$ENDIF DebugSEEventQueue}
  Result := ClearError;
  if not BeginUpdate then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seEventQueueData.Name, CEventQueueTimeout])
  else try
    for iEntry := 0 to seEventQueueData.Count-1 do
      for iSubject := 0 to subjectList.Count-1 do begin
        iListener := Items[iEntry].Listeners.IndexOf(subjectList[iSubject]);
        if iListener >= 0 then
          Items[iEntry].Listeners.Delete(iListener);
      end;
    iEntry := 0;
    while iEntry < seEventQueueData.Count do begin
      if (subjectList.IndexOf(Items[iEntry].Producer) >= 0) and
         (Items[iEntry].Listeners.Count = 0) then
        seEventQueueData.Delete(iEntry)
      else
        Inc(iEntry);
    end; //while
  finally seEventQueueData.EndUpdate; end;
  {$IFDEF DebugSEEventQueue}
  seLogger.Log('  => %s', [IFF(Result, 'T', 'F')]);
  {$ENDIF DebugSEEventQueue}
end; { TGpSEEventQueue.RemoveInvalidSubjects }

{:Remove the listener from the list of the event queue entry listeners. If this
  is the last listener, remove event queue entry entirely.
  @since   2002-09-24
}
function TGpSEEventQueue.RemoveListener(eventQueueHandle,
  subjectHandle: TGpSEHandle; out lastListener: boolean): boolean;
var
  iEntry    : integer;
  iListener : integer;
begin
  {$IFDEF DebugSEEventQueue}
  seLogger.Log('RemoveListener(event queue handle = %d, subject handle = %d)',
    [eventQueueHandle, subjectHandle]);
  {$ENDIF DebugSEEventQueue}
  Result := ClearError;
  if not BeginUpdate then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seEventQueueData.Name, CEventQueueTimeout])
  else try
    iEntry := LocateHandle(eventQueueHandle);
    if iEntry < 0 then
      raise EGpSharedEventManager.Create(sTryingToRemoveListenerFromUnexisting);
    iListener := Items[iEntry].Listeners.IndexOf(subjectHandle);
    if iListener < 0 then
      raise EGpSharedEventManager.Create(sTryingToRemoveUnexistingListener);
    Items[iEntry].Listeners.Delete(iListener);
    lastListener := (Items[iEntry].Listeners.Count = 0);
  finally EndUpdate; end;
  {$IFDEF DebugSEEventQueue}
  seLogger.Log('  => %s; last listener = %s',
    [IFF(Result, 'T', 'F'), IFF(lastListener, 'T', 'F')]);
  {$ENDIF DebugSEEventQueue}
end; { TGpSEEventQueue.RemoveListener }

{:Remove subject from all events where it is present in the Listeners list.
  @since   2002-09-26
}
function TGpSEEventQueue.RemoveListenerFromAll(subjectHandle: TGpSEHandle): boolean;
var
  eqEntries      : TGpSEHandleList;
  eventQueueEntry: TGpSEEventQueueEntry;
  iEntry         : integer;
  iEventQueue    : integer;
begin
  {$IFDEF DebugSEEventQueue}
  seLogger.Log('RemoveListenerFromAll(subject handle %d)', [subjectHandle]);
  {$ENDIF DebugSEEventQueue}
  Result := ClearError;
  if not BeginUpdate then
    Result := SetError(Ord(semErrNotAcquired), sFailedToAcquiredSharedMemory,
      [seEventQueueData.Name, CEventQueueTimeout])
  else try
    eqEntries := TGpSEHandleList.Create;
    try
      GetAllEntriesForListener(subjectHandle, eqEntries);
      for iEventQueue := 0 to eqEntries.Count-1 do begin
        iEntry := LocateHandle(eqEntries[iEventQueue]);
        if iEntry < 0 then
          eventQueueEntry := nil
        else
          eventQueueEntry := Items[iEntry];
        seManager.RemoveListener(self, eventQueueEntry.Event,
          eventQueueEntry.Producer, eventQueueEntry.Handle, subjectHandle);
      end; //for iEventQueue
    finally FreeAndNil(eqEntries); end;
  finally EndUpdate; end;
  {$IFDEF DebugSEEventQueue}
  seLogger.Log('  => %s', [IFF(Result, 'T', 'F')]);
  {$ENDIF DebugSEEventQueue}
end; { TGpSEEventQueue.RemoveListenerFromAll }

{ TGpSharedEventManager }

{:Break apart internal message.
  @raises  EGpSharedEventManager on malformed message.
  @since   2002-09-24
}
procedure TGpSharedEventManager.BreakSystemMessage(
  const encodedMessage: string; out msg: string; out handle: TGpSEHandle;
  out data1, data2: string);
var
  dataTexts: TStringList;
  rootNode : IXMLNode;
  xmlDoc   : IXMLDocument;
begin
  xmlDoc := CreateXMLDoc;
  XMLLoadFromString(xmlDoc, encodedMessage);
  rootNode := FindNode(xmlDoc, XML_SYSTEM_ROOT);
  if not assigned(rootNode) then
    raise EGpSharedEventManager.CreateFmt(sMalformedInternalMessage,[encodedMessage]);
  msg := GetNodeTextStr(rootNode, XML_SYSTEM_MESSAGE, '');
  handle := GetNodeTextInt(rootNode, XML_SYSTEM_HANDLE, CInvalidSEHandle);
  dataTexts := TStringList.Create;
  try
    GetNodesText(rootNode, XML_SYSTEM_DATA, dataTexts);
    dataTexts.Add('');
    dataTexts.Add('');
    data1 := dataTexts[0];
    data2 := dataTexts[1];
  finally FreeAndNil(dataTexts); end;
end; { TGpSharedEventManager.BreakSystemMessage }

{:Broadcast event to all registered listeners. If size of the event data is
  less than the threshold (CLargestFastEvent), event is sent using event queue,
  otherwise, separated shared memory is created to hold event data.
}
function TGpSharedEventManager.BroadcastEvent(const eventName,
  eventData: string; out eventQueueHandle: TGpSEHandle): boolean;
begin
  if Trim(eventName) = '' then
    Result := SetError(Ord(semErrInvalidName), sInvalidItemName, [eventName])
  else
    Result := InternalBroadcastEvent(eventQueueHandle, eventName, eventData);
end; { TGpSharedEventManager.BroadcastEvent }

{:Build internal message.
  @since   2002-09-23
}
function TGpSharedEventManager.BuildSystemMessage(msg: string;
  handle: TGpSEHandle; data1, data2: string): string;
var
  rootNode: IXMLNode;
  xmlDoc  : IXMLDocument;
begin
  xmlDoc := CreateXMLDoc;
  rootNode := SetNodeText(xmlDoc, XML_SYSTEM_ROOT, '');
  SetNodeText(rootNode, XML_SYSTEM_MESSAGE, msg);
  SetNodeTextInt(rootNode, XML_SYSTEM_HANDLE, handle);
  SetNodesText(rootNode, XML_SYSTEM_DATA, data1+#13#10+data2);
  Result := XMLSaveToString(xmlDoc);
end; { TGpSharedEventManager.BuildSystemMessage }

{:Create shared event manager.
  @param   namespace Namespace this event manager is running in.
  @precondition namespace <> ''
  @postcondition assigned(emSubjects)
}
constructor TGpSharedEventManager.Create(namespace, publicName: string;
  isProducer: boolean);
begin
  Precondition('Create', namespace <> '', 'namespace <> ''''');
  inherited Create;
  RegisterMessages;
  emNamespace  := namespace;
  emPublicName := publicName;
  emIsProducer := isProducer;
  emToken := TGpToken.Create;
  CreateSharedTables;
  emMessageWindow := DSiAllocateHWnd(WndProc);
  emNotificationEvent := CreateEvent_AllowEveryone(true, false, MakeNotificationEventName(emToken.Token));
  CreateNotificationThread;
  RegisterSubject;
  Postcondition('Create', assigned(emSubjects), 'assigned(emSubjects)');
end; { TGpSharedEventManager.Create }

{:Create thread monitoring the emNotificationEvent.
  @since   2002-10-17
}        
procedure TGpSharedEventManager.CreateNotificationThread;
begin
  emNotificationThread := TGpSharedEventManagerNotificationThread.Create(
    emNotificationEvent, emMessageWindow, emMsgNewEventQueueEntry
  );
end; { TGpSharedEventManager.CreateNotificationThread }

{:Create owned instance of shared tables.
  @precondition not assigned(emCounters)
  @precondition not assigned(emSubjects)
  @precondition not assigned(emEvents)
  @precondition not assigned(emSEMappings)
  @precondition not assigned(emEventQueue)
  @postcondition assigned(emCounters)
  @postcondition assigned(emSubjects)
  @postcondition assigned(emEvents)
  @postcondition assigned(emSEMappings)
  @postcondition assigned(emEventQueue)
}
procedure TGpSharedEventManager.CreateSharedTables;
begin
  Precondition('CreateSharedTables', not assigned(emCounters), 'not assigned(emCounters)');
  Precondition('CreateSharedTables', not assigned(emSubjects), 'not assigned(emSubjects)');
  Precondition('CreateSharedTables', not assigned(emEvents), 'not assigned(emEvents)');
  Precondition('CreateSharedTables', not assigned(emSEMappings), 'not assigned(emSEMappings)');
  Precondition('CreateSharedTables', not assigned(emEventQueue), 'not assigned(emEventQueue)');
  emCounters   := TGpSECounters.Create(emNamespace);
  emEvents     := TGpSEEvents.Create(emNamespace);
  emSEMappings := TGpSESEMappings.Create(emNamespace);
  emSubjects   := TGpSESubjects.Create(emNamespace, emCounters, emSEMappings, self);
  emEventQueue := TGpSEEventQueue.Create(emNamespace, emCounters, emSubjects, self);
  Postcondition('CreateSharedTables', assigned(emCounters), 'assigned(emCounters)');
  Postcondition('CreateSharedTables', assigned(emSubjects), 'assigned(emSubjects)');
  Postcondition('CreateSharedTables', assigned(emEvents), 'assigned(emEvents)');
  Postcondition('CreateSharedTables', assigned(emSEMappings), 'assigned(emSEMappings)');
  Postcondition('CreateSharedTables', assigned(emEventQueue), 'assigned(emEventQueue)');
end; { TGpSharedEventManager.CreateSharedTables }

{:Destroy shared event manager. Log out of shared event system first.
}
destructor TGpSharedEventManager.Destroy;
begin
  UnregisterSubject;
  DestroyNotificationThread;
  if emNotificationEvent <> 0 then begin
    CloseHandle(emNotificationEvent);
    emNotificationEvent := 0;
  end;
  if emMessageWindow <> 0 then begin
    DSiDeallocateHwnd(emMessageWindow);
    emMessageWindow := 0;
  end;
  DestroySharedTables;
  FreeAndNil(emToken);
  inherited;
end; { TGpSharedEventManager.Destroy }

{:Destroy notification thread.
  @since   2002-10-17
}        
procedure TGpSharedEventManager.DestroyNotificationThread;
begin
  if assigned(emNotificationThread) then begin
    SetEvent((emNotificationThread as TGpSharedEventManagerNotificationThread).TerminateEvent);
    emNotificationThread.WaitFor;
    FreeAndNil(emNotificationThread);
  end;
end; { TGpSharedEventManager.DestroyNotificationThread }

{:Destroy owned instance of shared tables.
  @postcondition not assigned(emSubjects)
  @postcondition not assigned(emEvents)
  @postcondition not assigned(emSEMappings)
  @postcondition not assigned(emEventQueue)
  @postcondition not assigned(emCounters)
}
procedure TGpSharedEventManager.DestroySharedTables;
begin
  FreeAndNil(emSubjects);
  FreeAndNil(emEvents);
  FreeAndNil(emSEMappings);
  FreeAndNil(emEventQueue);
  FreeAndNil(emCounters);
  Postcondition('DestroySharedTables', not assigned(emSubjects), 'not assigned(emSubjects)');
  Postcondition('DestroySharedTables', not assigned(emEvents), 'not assigned(emEvents)');
  Postcondition('DestroySharedTables', not assigned(emSEMappings), 'not assigned(emSEMappings)');
  Postcondition('DestroySharedTables', not assigned(emEventQueue), 'not assigned(emEventQueue)');
  Postcondition('DestroySharedTables', not assigned(emCounters), 'not assigned(emCounters)');
end; { TGpSharedEventManager.DestroySharedTables }

{:Event was completely sent, remove event queue entry from the table and trigger
  event handler.
  @since   2002-09-30
}        
procedure TGpSharedEventManager.EventSent(eventQueueHandle: TGpSEHandle);
var
  eventHandle : TGpSEHandle;
  sharedMemory: TGpSharedMemory;
begin
  if not emEventQueue.EventSent(eventQueueHandle, eventHandle, sharedMemory) then
    // _Must_ close shared memory and remove event queue entry - retry!
    Trigger(emMsgEventSent, WPARAM(eventQueueHandle), 0)
  else begin
    if eventHandle <> CInvalidSEHandle then // ignore system events
      if assigned(emOnEventSent) then
        emOnEventSent(Self, eventQueueHandle, eventHandle, emEvents.Name(eventHandle));
    if assigned(sharedMemory) then
      FreeAndNil(sharedMemory);
  end;
end; { TGpSharedEventManager.EventSent }

function TGpSharedEventManager.GetActive: boolean;
begin
  Result := (emSubjectHandle <> CInvalidSEHandle);
end; { TGpSharedEventManager.GetActive }

{:Get names of events associated with a subject.
  @since   2002-09-29
}        
function TGpSharedEventManager.GetSubjectsEvents(getProducers,
  getListeners: boolean; eventList: TStrings): boolean;
var
  eventHandleList: TGpSEHandleList;
begin
  eventHandleList := TGpSEHandleList.Create;
  try
     Result := SetError(emSEMappings,
      emSEMappings.GetEvents(emSubjectHandle, eventHandleList, getProducers, getListeners, true));
    if Result then
      emEvents.MapEventsToNames(eventHandleList, eventList);
  finally FreeAndNil(eventHandleList); end;
end; { TGpSharedEventManager.GetSubjectsEvents }

{:Retrieve names of all events in the namespace.
  @since   2002-10-03
}        
function TGpSharedEventManager.GetEvents(events: TStrings): boolean;
begin
  Result := emEvents.GetEvents(events);
end; { TGpSharedEventManager.GetEvents }

{:Store all monitored events into the string list.
  @since   2002-09-29
}
function TGpSharedEventManager.GetMonitoredEvents(
  eventList: TStrings): boolean;
begin
  Result := GetSubjectsEvents(false, true, eventList);
end; { TGpSharedEventManager.GetMonitoredEvents }

{:Store all published events into the string list.
  @since   2002-09-29
}
function TGpSharedEventManager.GetPublishedEvents(
  eventList: TStrings): boolean;
begin
  Result := GetSubjectsEvents(true, false, eventList);
end; { TGpSharedEventManager.GetPublishedEvents }

{:Retrieve names of producers and/or listeners.
  @since   2002-10-03
}        
function TGpSharedEventManager.GetSubjects(subjects: TStrings;
  getProducers, getListeners: boolean): boolean;
begin
  Result := emSubjects.GetSubjects(subjects, getProducers, getListeners);
end; { TGpSharedEventManager.GetSubjects }

{:Remove interest for event.
}
function TGpSharedEventManager.IgnoreEvent(const eventName: string): boolean;
var
  eventHandle: TGpSEHandle;
begin
  eventHandle := emEvents.Locate(eventName);
  if eventHandle = CInvalidSEHandle then
    Result := true
  else begin
    Result := SetError(emSEMappings, emSEMappings.DeleteMapping(emSubjectHandle, eventHandle));
    if Result then
      InternalBroadcastEvent(CSystemEvent,
        BuildSystemMessage(CSysMsgEventModified, eventHandle, eventName, CModEventIgnored),
        emSubjectHandle, CInvalidSEHandle, CWantEventIgnored);
  end;
end; { TGpSharedEventManager.IgnoreEvent }

{:Broadcast event to all registered listeners or - if the event is a system
  event (empty eventName) - to all listeners.. If size of the event data is
  less than the threshold (CLargestFastEvent), event is sent using event queue,
  otherwise, separated shared memory is created to hold event data. If
  excludeListener is specified, remove it from the recipient list prior to
  broadcasting. If interestFlags are specified, subject must have those flags
  set to be included in the listeners list.
}
function TGpSharedEventManager.InternalBroadcastEvent(
  out eventQueueHandle: TGpSEHandle; const eventName, eventData: string;
  excludeListener, sendOnlyTo: TGpSEHandle; interestFlags: integer): boolean;
var
  eventDataCopy: string;
  eventDataSize: cardinal;
  eventHandle  : TGpSEHandle;
  listeners    : TGpSEHandleList;
  publishes    : boolean;
  sharedMemory : TGpSharedMemory;
begin
  eventDataCopy := eventData;
  eventDataSize := Length(eventDataCopy);
  listeners := TGpSEHandleList.Create;
  try
    Result := PopulateListenerList(listeners, eventName, sendOnlyTo, excludeListener,
      interestFlags, eventHandle);
    if Result then begin
      publishes := true;
      if (eventName <> CSystemEvent) and
         (not emSEMappings.SubjectPublishes(emSubjectHandle, eventHandle, true, publishes))
      then
        Result := SetError(emSEMappings)
      else if not publishes then
        Result := SetError(Ord(semErrInvalidEvent), sSubjectDoesntPublishEvent, [eventName, eventHandle])
      else begin
        if listeners.Count > 0 then begin
          OffloadLargeMessage(eventDataCopy, sharedMemory);
          if not emEventQueue.Insert(eventHandle, emSubjectHandle, eventDataCopy,
                   eventDataSize, listeners, sharedMemory, eventQueueHandle) then
            Result := SetError(emEventQueue)
          else if NotifyListeners(listeners) then
            Result := ClearError;
        end
        else begin // nothing to do = all done
          if eventName <> CSystemEvent then
            if assigned(emOnEventSent) then
              emOnEventSent(self, eventQueueHandle, eventHandle, eventName);
          Result := ClearError;
        end;
      end;
    end;
  finally FreeAndNil(listeners); end;
end; { TGpSharedEventManager.InternalBroadcastEvent }

function TGpSharedEventManager.InternalBroadcastEvent(const eventName,
  eventData: string; excludeListener, sendOnlyTo: TGpSEHandle;
  interestFlags: integer): boolean;
var
  eventQueueHandle: TGpSEHandle;
begin
  Result := InternalBroadcastEvent(eventQueueHandle, eventName, eventData,
    excludeListener, sendOnlyTo, interestFlags);
end; { TGpSharedEventManager.InternalBroadcastEvent }

{:Optionally process the message; then (always) remove if from the event queue.
  @since   2002-09-24
}
procedure TGpSharedEventManager.InternalProcessAndRemove(
  eventQueueHandle: TGpSEHandle; doProcess: boolean);
var
  eqEntries       : TGpSEHandleList;
  eventData       : string;
  eventHandle     : TGpSEHandle;
  eventProducer   : TGpSEHandle;
  eventQueueEntry : TGpSEEventQueueEntry;
  iEventQueue     : integer;
  iNotification   : integer;
  notificationList: TGpIntegerObjectList;
  sendNotification: boolean;
begin
  if not emEventQueue.BeginUpdate then begin
    if emEventQueue.LastError = Ord(semErrNotAcquired) then
      // Timeout - work around it. We really _must_ remove the listener from the event queue.
      Trigger(emMsgRemoveFromEventQueue, WPARAM(eventQueueHandle), 0)
    else
      raise EGpSharedEventManager.Create('Failed to allocate event queue');
  end
  else begin
    notificationList := TGpIntegerObjectList.Create(false);
    try
      try
        eqEntries := TGpSEHandleList.Create;
        try
          emEventQueue.GetAllEntriesForListener(emSubjectHandle, eqEntries);
          for iEventQueue := 0 to eqEntries.Count-1 do begin
            eventQueueEntry := emEventQueue.Locate(eqEntries[iEventQueue]);
            eventQueueHandle := eventQueueEntry.Handle;
            eventProducer := eventQueueEntry.Producer;
            eventHandle := eventQueueEntry.Event;
            if doProcess then begin
              ReloadLargeMessage(eventQueueEntry, eventData);
              if eventHandle = CInvalidSEHandle then
                ProcessSystemEvent(eventData, eventProducer)
              else
                ProcessUserEvent(eventHandle, eventProducer, eventData);
            end;
            sendNotification := RemoveListener(emEventQueue, eventHandle,
              eventProducer, eventQueueHandle, emSubjectHandle);
            if sendNotification then
              notificationList.AddObject(eventProducer, TObject(eventQueueHandle));
          end; //for iEventQueue
        finally FreeAndNil(eqEntries); end;
      finally emEventQueue.EndUpdate; end;
      for iNotification := 0 to notificationList.Count-1 do
        NotifyEventSent(notificationList[iNotification], TGpSEHandle(notificationList.Objects[iNotification]));
    finally FreeAndNil(notificationList); end;
  end;
end; { TGpSharedEventManager.InternalProcessAndRemove }

{:Send an event to one listener.
}
function TGpSharedEventManager.InternalSendEvent(
  out eventQueueHandle: TGpSEHandle; recipientHandle: TGpSEHandle;
  const eventName, eventData: string): boolean;
begin
  Result := InternalBroadcastEvent(eventQueueHandle, eventName, eventData,
    CInvalidSEHandle, recipientHandle);
end; { TGpSharedEventManager.InternalSendEvent }

function TGpSharedEventManager.InternalSendEvent(recipientHandle: TGpSEHandle;
  const eventName, eventData: string): boolean;
var
  eventQueueHandle: TGpSEHandle;
begin
  Result := InternalSendEvent(eventQueueHandle, recipientHandle, eventName,
    eventData);
end; { TGpSharedEventManager.InternalSendEvent }

{:Create notification event name from token name.
  @since   2002-10-17
}        
class function TGpSharedEventManager.MakeNotificationEventName(
  const tokenName: string): string;
begin
  Result := tokenName + '$NotificationEvent';
end; { TGpSharedEventManager.MakeNotificationEventName }

{:Monitor the event.
}
function TGpSharedEventManager.MonitorEvent(const eventName: string): boolean;
var
  eventHandle: TGpSEHandle;
begin
  if Trim(eventName) = '' then
    Result := SetError(Ord(semErrInvalidName), sInvalidItemName, [eventName])
  else begin
    eventHandle := emEvents.RegisterEvent(eventName);
    Result := SetError(emEvents, eventHandle <> CInvalidSEHandle);
    if Result then
      Result := SetError(emSEMappings, emSEMappings.AddMapping(emSubjectHandle, eventHandle, false));
    if Result then
      InternalBroadcastEvent(CSystemEvent,
        BuildSystemMessage(CSysMsgEventModified, eventHandle, eventName, CModEventMonitored),
        emSubjectHandle, CInvalidSEHandle, CWantEventMonitored);
  end;
end; { TGpSharedEventManager.MonitorEvent }

{:Notify event producer that all listeners had received the event.
  @since   2002-09-30
}        
procedure TGpSharedEventManager.NotifyEventSent(eventProducer,
  eventQueueHandle: TGpSEHandle);
begin
  InternalSendEvent(eventProducer, CSystemEvent,
    BuildSystemMessage(CSysMsgEventSent, eventQueueHandle));
end; { TGpSharedEventManager.NotifyEventSent }

{:Notify all listeners in the list that new event is awaiting them in the event
  queue.
  @param   listeners        List of the listeners (handles).
  @param   eventQueueHandle Handle of the event queue entry.
  @since   2002-09-23
}
function TGpSharedEventManager.NotifyListeners(listeners: TGpSEHandleList): boolean;
begin
  Result := emSubjects.NotifyListeners(listeners);
end; { TGpSharedEventManager.NotifyListeners }

{:Move large messages into shared memory area.
  @since   2002-09-25
}        
procedure TGpSharedEventManager.OffloadLargeMessage(var eventData: string;
  out sharedMemory: TGpSharedMemory);
begin
  sharedMemory := nil;
  if Length(eventData) > CLargestFastEvent then begin
    // TODO 1 -oPrimoz Gabrijelcic: Shared memory name bi lahko sestavil iz tokna od producerja in handla v event queue; potem ni treba shranjevati tega dolgega stringa v EQ in lahko mogoèe offloadamo vsa sporoèila 
    sharedMemory := TGpSharedMemory.Create(TGpToken.GenerateToken, Length(eventData)+1, 0, false);
    if sharedMemory.AcquireMemory(true, 0) = nil then
      raise EGpSharedEventManager.CreateFmt(sFailedToAcquiredSharedMemory,[sharedMemory.Name,0]);
    try
      sharedMemory.AsString := eventData;
    finally sharedMemory.ReleaseMemory; end;
    eventData := sharedMemory.Name;
  end;
end; { TGpSharedEventManager.OffloadLargeMessage }

{:Populate listener list and generate handle for the event.
  @since   2002-09-25
}        
function TGpSharedEventManager.PopulateListenerList(
  listeners: TGpSEHandleList; const eventName: string; sendOnlyTo,
  excludeListener: TGpSEHandle; interestFlags: integer;
  out eventHandle: TGpSEHandle): boolean;
var
  iExcluded: integer;
begin
  Result := ClearError;
  listeners.Clear;
  if sendOnlyTo <> CInvalidSEHandle then
    listeners.Add(sendOnlyTo);
  if eventName = CSystemEvent then begin
    eventHandle := CInvalidSEHandle;
    if listeners.Count = 0 then
      if not emSubjects.GetAllSubjects(interestFlags, listeners) then
        Result := SetError(emSubjects);
  end
  else begin
    eventHandle := emEvents.Locate(eventName);
    if eventHandle = CInvalidSEHandle then
      Result := SetError(Ord(semErrInvalidName), sInvalidItemName, [eventName])
    else begin
      if listeners.Count = 0 then
        if not emSEMappings.GetListeners(eventHandle, listeners) then
          Result := SetError(emSEMappings);
    end;
  end;
  if Result then begin
    emSubjects.FilterSubjects(listeners);
    if excludeListener <> CInvalidSEHandle then begin
      iExcluded := listeners.IndexOf(excludeListener);
      if iExcluded >= 0 then
        listeners.Delete(iExcluded);
    end;
  end;
end; { TGpSharedEventManager.PopulateListenerList }

{:Process internal event.
  @since   2002-09-24
}
procedure TGpSharedEventManager.ProcessSystemEvent(const eventData: string;
  producerHandle: TGpSEHandle);
var
  data1 : string;
  data2 : string;
  handle: TGpSEHandle;
  msg   : string;
begin
  BreakSystemMessage(eventData, msg, handle, data1, data2);
  if msg = CSysMsgEventSent then
    EventSent(TGpSEHandle(handle))
  else if msg = CSysMsgSubjectRegistered then begin
    if assigned(emOnSubjectRegistered) then
      emOnSubjectRegistered(Self, handle, data1, StrToInt(data2)=1);
  end
  else if msg = CSysMsgSubjectUnregistered then begin
    // WARNING Handle is not valid at that moment anymore!
    if assigned(emOnSubjectUnregistered) then
      emOnSubjectUnregistered(Self, handle, data1, StrToInt(data2)=1);
  end
  else if msg = CSysMsgEventModified then begin
    if data2 = CModEventIgnored then begin
      if assigned(emOnEventIgnored) then
        emOnEventIgnored(Self, producerHandle, emSubjects.Name(producerHandle),
          handle, data1);
    end
    else if data2 = CModEventMonitored then begin
      if assigned(emOnEventMonitored) then
        emOnEventMonitored(Self, producerHandle, emSubjects.Name(producerHandle),
          handle, data1);
    end
    else if data2 = CModEventPublished then begin
      if assigned(emOnEventPublished) then
        emOnEventPublished(Self, producerHandle, emSubjects.Name(producerHandle),
          handle, data1);
    end
    else if data2 = CModEventUnpublished then begin
      if assigned(emOnEventUnpublished) then
        emOnEventUnpublished(Self, producerHandle, emSubjects.Name(producerHandle),
          handle, data1);
    end;
  end
  else
    { allow for messages from newer versions that we don't understand } ;
end; { TGpSharedEventManager.ProcessSystemEvent }

{:Forward an event to the user's event handler.
  @since   2002-09-24
}
procedure TGpSharedEventManager.ProcessUserEvent(eventHandle,
  producerHandle: TGpSEHandle; const eventData: string);
begin
  if assigned(emOnEventReceived) then
    emOnEventReceived(Self, producerHandle, emSubjects.Name(producerHandle),
      eventHandle, emEvents.Name(eventHandle), eventData);
end; { TGpSharedEventManager.ProcessUserEvent }

{:Publish the event.
}
function TGpSharedEventManager.PublishEvent(const eventName: string): boolean;
var
  eventHandle: TGpSEHandle;
begin
  if Trim(eventName) = '' then
    Result := SetError(Ord(semErrInvalidName), sInvalidItemName, [eventName])
  else begin
    eventHandle := emEvents.RegisterEvent(eventName);
    Result := SetError(emEvents, eventHandle <> CInvalidSEHandle);
    if Result then
      Result := SetError(emSEMappings, emSEMappings.AddMapping(emSubjectHandle, eventHandle, true));
    if Result then
      InternalBroadcastEvent(CSystemEvent,
        BuildSystemMessage(CSysMsgEventModified, eventHandle, eventName, CModEventPublished),
        emSubjectHandle, CInvalidSEHandle, CWantEventPublished);
  end;
end; { TGpSharedEventManager.PublishEvent }

{:Read and process event queue entry.
  @since   2002-09-23
}
procedure TGpSharedEventManager.ReceiveEventQueueEntry(
  eventQueueHandle: TGpSEHandle);
begin
  InternalProcessAndRemove(eventQueueHandle, true);
end; { TGpSharedEventManager.ReceiveEventQueueEntry }

{:Register messages used for inter-process communication.
  @since   2002-09-23
}
procedure TGpSharedEventManager.RegisterMessages;

  function SEMessageName(messageSuffix: string): string;
  begin
    Result := 'Gp/GpSharedEvents/8457A2B2-0310-4577-B61E-7A2E060CD10C/'+messageSuffix;
  end; { SEMessageName }

  function RegisterMessage(messageSuffix: string): UINT;
  begin
    // TODO 3 -oPrimoz Gabrijelcic: Wouldn't simple WM_USER+xxx suffice?
    Result := RegisterWindowMessage(PChar(SEMessageName(messageSuffix)));
    if Result = 0 then
      RaiseLastWin32Error;
  end; { RegisterMessage }

begin
  emMsgNewEventQueueEntry   := RegisterMessage('NewEventQueueEntry');
  emMsgRemoveFromEventQueue := RegisterMessage('RemoveEventFromQueue');
  emMsgEventSent            := RegisterMessage('EventSent');
  emMsgResendEventSent      := RegisterMessage('ResendEventSent');
  emMsgValidityRescan       := RegisterMessage('ValidityRescan');
  emMsgResetInterest        := RegisterMessage('ResetInterest');
end; { TGpSharedEventManager.RegisterMessages }

{:Register self in the Subjects table with the name PublicName.
}
function TGpSharedEventManager.RegisterSubject: boolean;
begin
  TriggerValidityRescan;
  emSubjectHandle := emSubjects.RegisterSubject(PublicName, emToken.Token, emIsProducer);
  Result := SetError(emSubjects, emSubjectHandle <> CInvalidSEHandle);
  if Result then
    InternalBroadcastEvent(CSystemEvent,
      BuildSystemMessage(CSysMsgSubjectRegistered, emSubjectHandle, PublicName, IntToStr(Ord(emIsProducer))),
      emSubjectHandle, CInvalidSEHandle, CWantSubjectRegistered);
end; { TGpSharedEventManager.RegisterSubject }

procedure TGpSharedEventManager.ReloadLargeMessage(
  eventQueueEntry: TGpSEEventQueueEntry; out eventData: string);
var
  sharedMemory: TGpSharedMemory;
begin
  eventData := eventQueueEntry.Data;
  if eventQueueEntry.SharedMemory <> 0 then begin
    sharedMemory := TGpSharedMemory.Create(eventData, eventQueueEntry.DataSize+1, 0, false);
    try
      if (not sharedMemory.WasCreated) and (sharedMemory.AcquireMemory(false, 0) <> nil) then begin
        try
          eventData := sharedMemory.AsString;
        finally sharedMemory.ReleaseMemory; end;
      end;
    finally FreeAndNil(sharedMemory); end;
  end;
end; { TGpSharedEventManager.ReloadLargeMessage }

{:Remove the event from the event queue.
  @since   2002-09-24
}
procedure TGpSharedEventManager.RemoveEventFromEventQueue(
  eventQueueHandle: TGpSEHandle);
begin
  InternalProcessAndRemove(eventQueueHandle, false);
end; { TGpSharedEventManager.RemoveEventFromEventQueue }

{:Remove subject from the list of listeners.
  @returns True if event sent notification method must be called.
  @since   2002-10-01
}        
function TGpSharedEventManager.RemoveListener(eventQueue: TGpSEEventQueue;
  eventHandle, eventProducer, eventQueueHandle,
  subjectHandle: TGpSEHandle): boolean;
var
  lastListener : boolean;
  producerToken: string;
  sharedMemory : TGpSharedMemory;
begin
  Result := false;
  eventQueue.RemoveListener(eventQueueHandle, subjectHandle, lastListener);
  if lastListener then begin
    producerToken := emSubjects.Token(eventProducer);
    if (producerToken <> '') and (not TGpToken.IsTokenPublished(producerToken)) then begin
      eventQueue.EventSent(eventQueueHandle, eventHandle, sharedMemory);
      TriggerValidityRescan;
    end
    else if eventHandle = CInvalidSEHandle then begin // system event
      eventQueue.EventSent(eventQueueHandle, eventHandle, sharedMemory);
      Result := false;
    end
    else
      Result := true;
  end;
end; { TGpSharedEventManager.RemoveListener }

{:Reset Interest field in the Subject table.
  @since   2002-10-01
}        
procedure TGpSharedEventManager.ResetInterest;
var
  newInterest: integer;
begin
  newInterest :=
    IFF(assigned(emOnEventIgnored),        CWantEventIgnored,        0) +
    IFF(assigned(emOnEventMonitored),      CWantEventMonitored,      0) +
    IFF(assigned(emOnEventPublished),      CWantEventPublished,      0) +
    IFF(assigned(emOnEventUnpublished),    CWantEventUnpublished,    0) +
    IFF(assigned(emOnSubjectRegistered),   CWantSubjectRegistered,   0) +
    IFF(assigned(emOnSubjectUnregistered), CWantSubjectUnregistered, 0);
  if not emSubjects.ResetInterest(emSubjectHandle, newInterest) then
    Trigger(emMsgResetInterest, 0, 0);
end; { TGpSharedEventManager.ResetInterest }

{:Send event to a listener. If size of the event data is less than the threshold
  (CLargestFastEvent), event is sent using event queue, otherwise, separated
  shared memory is created to hold event data.
}
function TGpSharedEventManager.SendEvent(listenerHandle: TGpSEHandle;
  const eventName, eventData: string;
  out eventQueueHandle: TGpSEHandle): boolean;
begin
  if Trim(eventName) = '' then
    Result := SetError(Ord(semErrInvalidName), sInvalidItemName, [eventName])
  else
    Result := InternalSendEvent(eventQueueHandle, listenerHandle, eventName, eventData);
end; { TGpSharedEventManager.SendEvent }

procedure TGpSharedEventManager.SetOnEventIgnored(
  const Value: TGpSEEventChangeNotify);
var
  oldEvent: TGpSEEventChangeNotify;
begin
  oldEvent := emOnEventIgnored;
  emOnEventIgnored := Value;
  if (assigned(oldEvent) xor assigned(emOnEventIgnored)) then
    ResetInterest;
end; { TGpSharedEventManager.SetOnEventIgnored }

procedure TGpSharedEventManager.SetOnEventMonitored(
  const Value: TGpSEEventChangeNotify);
var
  oldEvent: TGpSEEventChangeNotify;
begin
  oldEvent := emOnEventMonitored;
  emOnEventMonitored := Value;
  if (assigned(oldEvent) xor assigned(emOnEventMonitored)) then
    ResetInterest;
end; { TGpSharedEventManager.SetOnEventMonitored }

procedure TGpSharedEventManager.SetOnEventPublished(
  const Value: TGpSEEventChangeNotify);
var
  oldEvent: TGpSEEventChangeNotify;
begin
  oldEvent := emOnEventPublished;
  emOnEventPublished := Value;
  if (assigned(oldevent) xor assigned(emOnEventPublished)) then
    ResetInterest;
end; { TGpSharedEventManager.SetOnEventPublished }

procedure TGpSharedEventManager.SetOnSubjectRegistered(
  const Value: TGpSESubjectLifecycleNotify);
var
  oldEvent: TGpSESubjectLifecycleNotify;
begin
  oldEvent := emOnSubjectRegistered;
  emOnSubjectRegistered := Value;
  if (assigned(oldevent) xor assigned(emOnSubjectRegistered)) then
    ResetInterest;
end; { TGpSharedEventManager.SetOnSubjectRegistered }

procedure TGpSharedEventManager.SetOnSubjectUnregistered(
  const Value: TGpSESubjectLifecycleNotify);
var
  oldEvent: TGpSESubjectLifecycleNotify;
begin
  oldEvent := emOnSubjectUnregistered;
  emOnSubjectUnregistered := Value;
  if (assigned(oldevent) xor assigned(emOnSubjectUnregistered)) then
    ResetInterest;
end; { TGpSharedEventManager.SetOnSubjectUnregistered }

procedure TGpSharedEventManager.Trigger(msg: UINT; param1: WPARAM;
  param2: LPARAM);
begin
  PostMessage(emMessageWindow, msg, param1, param2);
end; { TGpSharedEventManager.Trigger }

procedure TGpSharedEventManager.TriggerValidityRescan;
begin
  Trigger(emMsgValidityRescan, 0, 0);
end; { TGpSharedEventManager.TriggerValidityRescan }

{:Unpublish the event.
}
function TGpSharedEventManager.UnpublishEvent(const eventName: string): boolean;
var
  eventHandle: TGpSEHandle;
begin
  eventHandle := emEvents.Locate(eventName);
  if eventHandle = CInvalidSEHandle then
    Result := true
  else begin
    Result := SetError(emSEMappings, emSEMappings.DeleteMapping(emSubjectHandle, eventHandle));
    if Result then
      InternalBroadcastEvent(CSystemEvent,
        BuildSystemMessage(CSysMsgEventModified, eventHandle, eventName, CModEventUnpublished),
        emSubjectHandle, CInvalidSEHandle, CWantEventUnpublished);
  end;
end; { TGpSharedEventManager.UnpublishEvent }

{:Remove self from the Subjects table. Also remove all (self, *) mappings from
  the Subjects-Events table.
}
function TGpSharedEventManager.UnregisterSubject: boolean;
var
  res1: boolean;
  res2: boolean;
  res3: boolean;
begin
  if emSubjectHandle <> CInvalidSEHandle then begin
    res1 := SetError(emSubjects, emSubjects.UnregisterSubject(emSubjectHandle));
    if res1 then
      InternalBroadcastEvent(CSystemEvent,
        BuildSystemMessage(CSysMsgSubjectUnregistered, emSubjectHandle, PublicName, IntToStr(Ord(emIsProducer))),
        emSubjectHandle, CInvalidSEHandle, CWantSubjectUnregistered);
    res2 := SetError(emSEMappings, emSEMappings.DeleteAllEvents(emSubjectHandle));
    res3 := SetError(emEventQueue, emEventQueue.RemoveListenerFromAll(emSubjectHandle));
    Result := res1 and res2 and res3;
    emSubjectHandle := CInvalidSEHandle;
  end
  else
    Result := ClearError;
end; { TGpSharedEventManager.UnregisterSubject }

{:Rescan tables and remove invalid/unused handles.
  @since   2002-09-30
}        
procedure TGpSharedEventManager.ValidityRescan;
var
  subjectList: TGpSEHandleList;
begin
  subjectList := TGpSEHandleList.Create;
  try
    try
      if not emSubjects.CollectInvalidSubjects(subjectList) then
        Abort;
      if subjectList.Count > 0 then begin
        if not emSEMappings.RemoveInvalidSubjects(subjectList) then
          Abort;
        if not emEventQueue.RemoveInvalidSubjects(subjectList) then
          Abort;
        if not emSubjects.RemoveInvalidSubjects(subjectList) then
          Abort;
        // TODO 1 -oPrimoz Gabrijelcic: This code should generate internal notification for all completely sent events (if the producer is still alive)!
      end;
    except
      on EAbort do
        TriggerValidityRescan;
    end;
  finally FreeAndNil(subjectList); end;
end; { TGpSharedEventManager.ValidityRescan }

{:Message processor.
  @since   2002-09-23
}        
procedure TGpSharedEventManager.WndProc(var msg: TMessage);
begin
  if msg.Msg = emMsgNewEventQueueEntry then
    ReceiveEventQueueEntry(TGpSEHandle(msg.WParam))
  else if msg.Msg = emMsgRemoveFromEventQueue then
    RemoveEventFromEventQueue(TGpSEHandle(msg.WParam))
  else if msg.Msg = emMsgResendEventSent then
    NotifyEventSent(TGpSEHandle(msg.WParam), TGpSEHandle(msg.LParam))
  else if msg.Msg = emMsgEventSent then
    EventSent(TGpSEHandle(msg.WParam))
  else if msg.Msg = emMsgValidityRescan then
    ValidityRescan
  else if msg.Msg = emMsgResetInterest then
    ResetInterest;
  msg.Result := Ord(true);
end; { TGpSharedEventManager.WndProc }

end.

