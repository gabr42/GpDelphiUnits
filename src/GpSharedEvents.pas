(*:Distributed multicast event manager - object and component wrapper.
   @author Primoz Gabrijelcic
   @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2006, Primoz Gabrijelcic
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
   Last modification : 2006-04-05
   Version           : 1.03
</pre>*)(*
   History:
     1.03: 2006-04-05
       - Don't activate producer in SetNamespace if it was not previously active.
     1.02: 2003-07-28
       - Made some more string parameters 'const'.
       - 'Data' parameter in BroadcastEvent and SendEvent is now optional (defaults to
         empty string).
       - Added TGpSharedEventProducer property ProducerHandle and TGpSharedEventListener
         property ListenerHandle.
     1.01a: 2003-01-15
       - Fixed runtime error occuring in special conditions.
     1.01: 2002-10-17
       - Event manager now works from non-interactive service running under system
         account.
     1.0: 2002-10-03
       - Released.
     0.1: 2001-07-17
       - Created.
*)

unit GpSharedEvents;

interface

uses
  Classes,
  GpManagedClass,
  GpSharedEventsImpl;

resourcestring
  sCantCreateEventManager        = 'Shared event manager failed to create namespace %s. Error was: %s.';
  sNamespaceNotSpecified         = 'Namespace is not set.';
  sSharedEventManagerIsNotActive = 'Shared event manager is not active';

type
  TGpSEHandle = GpSharedEventsImpl.TGpSEHandle;

  {:Shared events manager errors.
    !!!Keep this enum in sync with GpSharedEventsImpl.TGpSharedEventManagerError!!!
    // manager errors
    @enum seErrNoError       No error.
    @enum seErrNotAcquired   Shared memory cannot be acquired.
    @enum seErrNotFound      Handle not found.
    @enum seErrAlreadyExists Item already exists.
    @enum seErrInvalidName   Invalid item name.
    @enum seErrInvalidEvent  Invalid event name.
    // component errors
    @enum seNamespaceNotSet  Namespace is not specified.
    @enum seNotActive        Shared event manager is not active.
  }
  TGpSharedEventError = (
    // manager errors
    seErrNoError, seErrNotAcquired, seErrNotFound, seErrAlreadyExists,
    seErrInvalidName, seErrInvalidEvent,
    // component errors
    seNamespaceNotSet, seNotActive
  );

  {:Shared event error.
  }
  TGpSharedEventErrorEvent = procedure(Sender: TObject;
    error: TGpSharedEventError; errorDescription: string) of object;

  {:Subject lifecycle notification.
  }
  TGpSESubjectRegistrationNotify = procedure(Sender: TObject;
    subjectHandle: TGpSEHandle; const subjectName: string) of object;

  {:Event received notification.
  }
  TGpSEEventReceivedNotify = procedure(Sender: TObject;
    producerHandle: TGpSEHandle; const producerName, eventName,
    eventData: string) of object;

  {:Event sent notification.
  }
  TGpSEEventSentNotify = procedure(Sender: TObject; sendHandle: TGpSEHandle;
    const eventName: string) of object;

  {:Event table modified notification.
  }
  TGpSEEventChangeListenerNotify = procedure(Sender: TObject;
    listenerHandle: TGpSEHandle; const listenerName: string;
    eventHandle: TGpSEHandle; const eventName: string) of object;
  TGpSEEventChangeProducerNotify = procedure(Sender: TObject;
    producerHandle: TGpSEHandle; const producerName: string;
    eventHandle: TGpSEHandle; const eventName: string) of object;

  {:Subject in the shared event system. Either Producer or Listener.
  }
  TCustomGpSharedEventSubject = class(TComponent)
  private
    esActive                : boolean;
    esEvents                : TStringList;
    esLastError             : TGpManagedError;
    esListeners             : TStringList;
    esManager               : TGpSharedEventManager;
    esMonitoredEvents       : TStringList;
    esMonitoredEventsDirty  : boolean;
    esNamespace             : string;
    esOnError               : TGpSharedEventErrorEvent;
    esOnEventIgnored        : TGpSEEventChangeListenerNotify;
    esOnEventMonitored      : TGpSEEventChangeListenerNotify;
    esOnEventPublished      : TGpSEEventChangeProducerNotify;
    esOnEventReceived       : TGpSEEventReceivedNotify;
    esOnEventSent           : TGpSEEventSentNotify;
    esOnEventUnpublished    : TGpSEEventChangeProducerNotify;
    esOnListenerRegistered  : TGpSESubjectRegistrationNotify;
    esOnListenerUnregistered: TGpSESubjectRegistrationNotify;
    esOnProducerRegistered  : TGpSESubjectRegistrationNotify;
    esOnProducerUnregistered: TGpSESubjectRegistrationNotify;
    esProducers             : TStringList;
    esPublicName            : string;
    esPublishedEvents       : TStringList;
    esPublishedEventsDirty  : boolean;
  protected
    class function IsProducer: boolean; virtual; abstract;
    function  BroadcastEvent(const event: string; const data: string = ''): TGpSEHandle; virtual;
    function  ClearError: boolean;
    procedure DoEventIgnored(subjectHandle: TGpSEHandle;
      const subjectName: string; eventHandle: TGpSEHandle;
      const eventName: string); virtual;
    procedure DoEventMonitored(subjectHandle: TGpSEHandle;
      const subjectName: string; eventHandle: TGpSEHandle;
      const eventName: string); virtual;
    procedure DoEventPublished(subjectHandle: TGpSEHandle;
      const subjectName: string; eventHandle: TGpSEHandle;
      const eventName: string); virtual;
    procedure DoEventReceived(producerHandle: TGpSEHandle; const producerName,
      eventName, eventData: string); virtual;
    procedure DoEventSent(eventQueueHandle: TGpSEHandle;
      const eventName: string); virtual;
    procedure DoEventUnpublished(subjectHandle: TGpSEHandle;
      const subjectName: string; eventHandle: TGpSEHandle;
      const eventName: string); virtual;
    procedure DoListenerRegistered(listenerHandle: TGpSEHandle;
      const listenerName: string); virtual;
    procedure DoListenerUnregistered(listenerHandle: TGpSEHandle;
      const listenerName: string); virtual;
    procedure DoOnError; virtual;
    procedure DoProducerRegistered(producerHandle: TGpSEHandle;
      const producerName: string); virtual;
    procedure DoProducerUnregistered(producerHandle: TGpSEHandle;
      const producerName: string); virtual;
    function  GetActive: boolean; virtual;
    function  GetEvents: TStrings; virtual;
    function  GetLastError: TGpSharedEventError; virtual;
    function  GetLastErrorMsg: string; virtual;
    function  GetListeners: TStrings; virtual;
    function  GetMonitoredEvents: TStringList; virtual;
    function  GetProducers: TStrings; virtual;
    function  GetPublishedEvents: TStringList; virtual;
    function  IgnoreEvent(const event: string): boolean; virtual;
    procedure ManagerOnEventIgnored(Sender: TObject;
      subjectHandle: TGpSEHandle; const subjectName: string;
      eventHandle: TGpSEHandle; const eventName: string); virtual;
    procedure ManagerOnEventMonitored(Sender: TObject;
      subjectHandle: TGpSEHandle; const subjectName: string;
      eventHandle: TGpSEHandle; const eventName: string); virtual;
    procedure ManagerOnEventPublished(Sender: TObject;
      subjectHandle: TGpSEHandle; const subjectName: string;
      eventHandle: TGpSEHandle; const eventName: string); virtual;
    procedure ManagerOnEventReceived(Sender: TObject;
      producerHandle: TGpSEHandle; const producerName: string;
      eventHandle: TGpSEHandle; const eventName, eventData: string); virtual;
    procedure ManagerOnEventSent(Sender: TObject; eventQueueHandle,
      eventHandle: TGpSEHandle; const eventName: string); virtual;
    procedure ManagerOnEventUnpublished(Sender: TObject;
      subjectHandle: TGpSEHandle; const subjectName: string;
      eventHandle: TGpSEHandle; const eventName: string); virtual;
    procedure ManagerOnSubjectRegistered(Sender: TObject;
      subjectHandle: TGpSEHandle; const subjectName: string;
      subjectIsProducer: boolean); virtual;
    procedure ManagerOnSubjectUnregistered(Sender: TObject;
      subjectHandle: TGpSEHandle; const subjectName: string;
      subjectIsProducer: boolean); virtual;
    function  MonitorEvent(const event: string): boolean; virtual;
    function  PublishEvent(const event: string): boolean; virtual;
    function  SendEvent(listenerHandle: TGpSEHandle;
      const event: string; const data: string = ''): TGpSEHandle; virtual;
    procedure SetActive(const Value: boolean); virtual;
    function  SetError(errorCode: TGpSharedEventError;
      const errorMessage: string): boolean; overload; virtual;
    function  SetError(managerResult: boolean): boolean; overload; virtual;
    procedure SetHookedEventHandlers; virtual;
    procedure SetMonitoredEvents(const Value: TStringList); virtual;
    procedure SetNamespace(const Value: string); virtual;
    procedure SetOnEventIgnored(
      const Value: TGpSEEventChangeListenerNotify); virtual;
    procedure SetOnEventMonitored(
      const Value: TGpSEEventChangeListenerNotify); virtual;
    procedure SetOnEventPublished(
      const Value: TGpSEEventChangeProducerNotify); virtual;
    procedure SetOnEventUnpublished(
      const Value: TGpSEEventChangeProducerNotify); virtual;
    procedure SetOnListenerRegistered(
      const Value: TGpSESubjectRegistrationNotify); virtual;
    procedure SetOnListenerUnregistered(
      const Value: TGpSESubjectRegistrationNotify); virtual;
    procedure SetOnProducerRegistered(
      const Value: TGpSESubjectRegistrationNotify); virtual;
    procedure SetOnProducerUnregistered(
      const Value: TGpSESubjectRegistrationNotify); virtual;
    procedure SetPublicName(const Value: string); virtual;
    procedure SetPublishedEvents(const Value: TStringList); virtual;
    procedure StringListChanged(Sender: TObject); virtual;
    function  UnpublishEvent(const event: string): boolean; virtual;
  {properties}
    //:True when manager is active.
    property Active: boolean read GetActive write SetActive;
    //:All events.
    property Events: TStrings read GetEvents;
    //:Last error code.
    property LastError: TGpSharedEventError read GetLastError;
    //:Last error message.
    property LastErrorMsg: string read GetLastErrorMsg;
    //:All listeners.
    property Listeners: TStrings read GetListeners;
    //:Events monitored by the object.
    property MonitoredEvents: TStringList
      read GetMonitoredEvents write SetMonitoredEvents;
    //:Namespace for this subject.
    property Namespace: string read esNamespace write SetNamespace;
    //:All producers.
    property Producers: TStrings read GetProducers;
    //:Public name of this subject.
    property PublicName: string read esPublicName write SetPublicName;
    //:Events published by the object.
    property PublishedEvents: TStringList
      read GetPublishedEvents write SetPublishedEvents;
  {event handlers}
    //:Error handler
    property OnError: TGpSharedEventErrorEvent
      read esOnError write esOnError;
    //:Listener is ignoring event.
    property OnEventIgnored: TGpSEEventChangeListenerNotify
      read esOnEventIgnored write SetOnEventIgnored;
    //:Listener is monitoring event.
    property OnEventMonitored: TGpSEEventChangeListenerNotify
      read esOnEventMonitored write SetOnEventMonitored;
    //:Producer has published an event.
    property OnEventPublished: TGpSEEventChangeProducerNotify
      read esOnEventPublished write SetOnEventPublished;
    //:Event was received.
    property OnEventReceived: TGpSEEventReceivedNotify
      read esOnEventReceived write esOnEventReceived;
    //:Producer has unpublished an event.
    property OnEventUnpublished: TGpSEEventChangeProducerNotify
      read esOnEventUnpublished write SetOnEventUnpublished;
    //:Event was sent to all recipients.
    property OnEventSent: TGpSEEventSentNotify
      read esOnEventSent write esOnEventSent;
    //:Listener was registered.
    property OnListenerRegistered: TGpSESubjectRegistrationNotify
      read esOnListenerRegistered write SetOnListenerRegistered;
    //:Listener was unregistered.
    property OnListenerUnregistered: TGpSESubjectRegistrationNotify
      read esOnListenerUnregistered write SetOnListenerUnregistered;
    //:Producer was registered.
    property OnProducerRegistered: TGpSESubjectRegistrationNotify
      read esOnProducerRegistered write SetOnProducerRegistered;
    //:Producer was unregistered.
    property OnProducerUnregistered: TGpSESubjectRegistrationNotify
      read esOnProducerUnregistered write SetOnProducerUnregistered;
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
    procedure ReportError; virtual;
    function  Start: boolean; virtual;
    function  Stop: boolean; virtual;
  end; { TCustomGpSharedEventSubject }

  TGpSharedEventSubject = class(TCustomGpSharedEventSubject)
  public
    property Events;
    property LastError;
    property LastErrorMsg;
    property Listeners;
    property Producers;
  published
    property Namespace;
    property PublicName;
    property OnError;
    property OnEventIgnored;
    property OnEventMonitored;
    property OnListenerRegistered;
    property OnListenerUnregistered;
    property OnEventPublished;
    property OnProducerRegistered;
    property OnEventUnpublished;
    property OnProducerUnregistered;
    property Active; // must be published last
  end; { TGpSharedEventSubject }

  {:Multicast event producer component.
  }
  TGpSharedEventProducer = class(TGpSharedEventSubject)
  protected
    class function IsProducer: boolean; override;
  public
    function  BroadcastEvent(const event: string; const data: string = ''): TGpSEHandle; override;
    function  ProducerHandle: TGpSEHandle;
    function  PublishEvent(const event: string): boolean; override;
    function  SendEvent(listenerHandle: TGpSEHandle; const event: string;
      const data: string = ''): TGpSEHandle; override;
    function  UnpublishEvent(const event: string): boolean; override;
  published
    property PublishedEvents;
    property OnEventSent;
  end; { TGpSharedEventProducer }

  {:Multicast event listener component.
  }
  TGpSharedEventListener = class(TGpSharedEventSubject)
  protected
    class function IsProducer: boolean; override;
  public
    function  IgnoreEvent(const event: string): boolean; override;
    function  ListenerHandle: TGpSEHandle;
    function  MonitorEvent(const event: string): boolean; override;
  published
    property MonitoredEvents;
    property OnEventReceived;
  end; { TGpSharedEventListener }

const
  CInvalidSEHandle = GpSharedEventsImpl.CInvalidSEHandle;

  procedure Register;

implementation

uses
  Windows,
  SysUtils;

procedure Register;
begin
  RegisterComponents('Gp', [TGpSharedEventProducer, TGpSharedEventListener]);
end; { Register }

{ TGpSharedEventSubject }

{:Broadcast event to all registered listeners.
  @returns Handle of the Event Queue entry uniquely identifying this instance of
           the event or CInvalidSEHandle if BroadcastEvent failed.
}
function TCustomGpSharedEventSubject.BroadcastEvent(const event,
  data: string): TGpSEHandle;
begin
  Result := CInvalidSEHandle;
  if not Active then
    SetError(seNotActive,sSharedEventManagerIsNotActive)
  else
    SetError(esManager.BroadcastEvent(event, data, Result));
end; { TCustomGpSharedEventSubject.BroadcastEvent }

{:Clear error code.
  @since   2002-09-26
}
function TCustomGpSharedEventSubject.ClearError: boolean;
begin
  Result := esLastError.ClearError;
end; { TCustomGpSharedEventSubject.ClearError }

{:Set/clear error code according to the result of the esManager operation.
}
{:Create shared event subject.
}
constructor TCustomGpSharedEventSubject.Create(AOwner: TComponent);
begin
  inherited;
  esLastError := TGpManagedError.Create;
  esMonitoredEvents := TStringList.Create;
  esMonitoredEvents.OnChange := StringListChanged;
  esPublishedEvents := TStringList.Create;
  esPublishedEvents.OnChange := StringListChanged;
  esListeners := TStringList.Create;
  esProducers := TStringList.Create;
  esEvents := TStringList.Create;
end; { TCustomGpSharedEventSubject.Create }

{:Destroy shared event subject. Logout from the shared event system first.
}
destructor TCustomGpSharedEventSubject.Destroy;
begin
  FreeAndNil(esEvents);
  FreeAndNil(esProducers);
  FreeAndNil(esListeners);
  FreeAndNil(esPublishedEvents);
  FreeAndNil(esMonitoredEvents);
  FreeAndNil(esLastError);
  Active := false;
  inherited;
end; { TCustomGpSharedEventSubject.Destroy }

procedure TCustomGpSharedEventSubject.DoEventReceived(producerHandle: TGpSEHandle;
  const producerName, eventName, eventData: string);
begin
  if assigned(esOnEventReceived) then
    esOnEventReceived(Self, producerHandle, producerName, eventName, eventData);
end; { TCustomGpSharedEventSubject.DoEventReceived }

procedure TCustomGpSharedEventSubject.DoEventSent(eventQueueHandle: TGpSEHandle;
  const eventName: string);
begin
  if assigned(esOnEventSent) then
    esOnEventSent(Self, eventQueueHandle, eventName);
end; { TCustomGpSharedEventSubject.DoEventSent }

procedure TCustomGpSharedEventSubject.DoEventIgnored(
  subjectHandle: TGpSEHandle; const subjectName: string;
  eventHandle: TGpSEHandle; const eventName: string);
begin
  if assigned(esOnEventIgnored) then
    esOnEventIgnored(Self, subjectHandle, subjectName, eventHandle, eventName);
end; { TCustomGpSharedEventSubject.DoEventIgnored }

procedure TCustomGpSharedEventSubject.DoEventMonitored(
  subjectHandle: TGpSEHandle; const subjectName: string;
  eventHandle: TGpSEHandle; const eventName: string);
begin
  if assigned(esOnEventMonitored) then
    esOnEventMonitored(Self, subjectHandle, subjectName, eventHandle, eventName);
end; { TCustomGpSharedEventSubject.DoEventMonitored }

procedure TCustomGpSharedEventSubject.DoListenerRegistered(
  listenerHandle: TGpSEHandle; const listenerName: string);
begin
  if assigned(esOnListenerRegistered) then
    esOnListenerRegistered(Self, listenerHandle, listenerName);
end; { TCustomGpSharedEventSubject.DoListenerRegistered }

procedure TCustomGpSharedEventSubject.DoListenerUnregistered(
  listenerHandle: TGpSEHandle; const listenerName: string);
begin
  if assigned(esOnListenerUnregistered) then
    esOnListenerUnregistered(Self, listenerHandle, listenerName);
end; { TCustomGpSharedEventSubject.DoListenerUnregistered }

procedure TCustomGpSharedEventSubject.DoOnError;
begin
  if assigned(esOnError) then
    esOnError(self, TGpSharedEventError(esLastError.LastError), esLastError.LastErrorMsg);
end; { TCustomGpSharedEventSubject.DoOnError }

procedure TCustomGpSharedEventSubject.DoEventPublished(
  subjectHandle: TGpSEHandle; const subjectName: string;
  eventHandle: TGpSEHandle; const eventName: string);
begin
  if assigned(esOnEventPublished) then
    esOnEventPublished(Self, subjectHandle, subjectName, eventHandle, eventName);
end; { TCustomGpSharedEventSubject.DoEventPublished }

procedure TCustomGpSharedEventSubject.DoProducerRegistered(
  producerHandle: TGpSEHandle; const producerName: string);
begin
  if assigned(esOnProducerRegistered) then
    esOnProducerRegistered(Self, producerHandle, producerName);
end; { TCustomGpSharedEventSubject.DoProducerRegistered }

procedure TCustomGpSharedEventSubject.DoEventUnpublished(
  subjectHandle: TGpSEHandle; const subjectName: string;
  eventHandle: TGpSEHandle; const eventName: string);
begin
  if assigned(esOnEventUnpublished) then
    esOnEventUnpublished(Self, subjectHandle, subjectName, eventHandle, eventName);
end; { TCustomGpSharedEventSubject.DoEventUnpublished }

procedure TCustomGpSharedEventSubject.DoProducerUnregistered(
  producerHandle: TGpSEHandle; const producerName: string);
begin
  if assigned(esOnProducerUnregistered) then
    esOnProducerUnregistered(Self, producerHandle, producerName);
end; { TCustomGpSharedEventSubject.DoProducerUnregistered }

function TCustomGpSharedEventSubject.GetActive: boolean;
begin
  if csDesigning in ComponentState then
    Result := esActive
  else
    Result := assigned(esManager);
end; { TCustomGpSharedEventSubject.GetActive }

function TCustomGpSharedEventSubject.GetEvents: TStrings;
begin
  esEvents.Clear;
  if assigned(esManager) then
    SetError(esManager.GetEvents(esEvents));
  Result := esEvents;
end; { TCustomGpSharedEventSubject.GetEvents }

function TCustomGpSharedEventSubject.GetLastError: TGpSharedEventError;
begin
  Result := TGpSharedEventError(esLastError.LastError);
end;  { TCustomGpSharedEventSubject.GetLastError }

function TCustomGpSharedEventSubject.GetLastErrorMsg: string;
begin
  Result := esLastError.LastErrorMsg;
end; { TCustomGpSharedEventSubject.GetLastErrorMsg }

function TCustomGpSharedEventSubject.GetListeners: TStrings;
begin
  esListeners.Clear;
  if assigned(esManager) then
    esManager.GetSubjects(esListeners, false, true);
  Result := esListeners;
end; { TCustomGpSharedEventSubject.GetListeners }

function TCustomGpSharedEventSubject.GetMonitoredEvents: TStringList;
begin
  if esMonitoredEventsDirty and assigned(esManager) then begin
    esMonitoredEvents.OnChange := nil;
    esManager.GetMonitoredEvents(esMonitoredEvents);
    esMonitoredEvents.OnChange := StringListChanged;
    esMonitoredEventsDirty := false;
  end;
  Result := esMonitoredEvents;
end; { TCustomGpSharedEventSubject.GetMonitoredEvents }

function TCustomGpSharedEventSubject.GetProducers: TStrings;
begin
  esProducers.Clear;
  if assigned(esManager) then
    esManager.GetSubjects(esProducers, true, false);
  Result := esProducers;
end; { TCustomGpSharedEventSubject.GetProducers }

function TCustomGpSharedEventSubject.GetPublishedEvents: TStringList;
begin
  if esPublishedEventsDirty and assigned(esManager) then begin
    esPublishedEvents.OnChange := nil;
    esManager.GetPublishedEvents(esPublishedEvents);
    esPublishedEvents.OnChange := StringListChanged;
    esPublishedEventsDirty := false;
  end;
  Result := esPublishedEvents;
end; { TCustomGpSharedEventSubject.GetPublishedEvents }

{:Notify manager that event doesn't interest us anymore.
}
function TCustomGpSharedEventSubject.IgnoreEvent(const event: string): boolean;
begin
  if not Active then
    Result := SetError(seNotActive,sSharedEventManagerIsNotActive)
  else begin
    Result := SetError(esManager.IgnoreEvent(event));
    esMonitoredEventsDirty := true;
  end;
end; { TCustomGpSharedEventSubject.IgnoreEvent }

{:TGpSharedEventManager.OnEventIgnored handler.
  @since   2002-09-24
}
procedure TCustomGpSharedEventSubject.ManagerOnEventIgnored(
  Sender: TObject; subjectHandle: TGpSEHandle; const subjectName: string;
  eventHandle: TGpSEHandle; const eventName: string);
begin
  DoEventIgnored(subjectHandle, subjectName, eventHandle, eventName);
end; { TCustomGpSharedEventSubject.ManagerOnEventIgnored }

{:TGpSharedEventManager.OnEventMonitored handler.
  @since   2002-09-24
}
procedure TCustomGpSharedEventSubject.ManagerOnEventMonitored(
  Sender: TObject; subjectHandle: TGpSEHandle; const subjectName: string;
  eventHandle: TGpSEHandle; const eventName: string);
begin
  DoEventMonitored(subjectHandle, subjectName, eventHandle, eventName);
end; { TCustomGpSharedEventSubject.ManagerOnEventMonitored }

{:TGpSharedEventManager.OnEventPublished handler.
  @since   2002-09-24
}
procedure TCustomGpSharedEventSubject.ManagerOnEventPublished(
  Sender: TObject; subjectHandle: TGpSEHandle; const subjectName: string;
  eventHandle: TGpSEHandle; const eventName: string);
begin
  DoEventPublished(subjectHandle, subjectName, eventHandle, eventName);
end; { TCustomGpSharedEventSubject.ManagerOnEventPublished }

{:TGpSharedEventManager.OnEventReceived handler.
  @since   2002-09-24
}
procedure TCustomGpSharedEventSubject.ManagerOnEventReceived(Sender: TObject;
  producerHandle: TGpSEHandle; const producerName: string;
  eventHandle: TGpSEHandle; const eventName, eventData: string);
begin
  DoEventReceived(producerHandle, producerName, eventName, eventData);
end; { TCustomGpSharedEventSubject.ManagerOnEventReceived }

{:TGpSharedEventManager.OnEventSent handler.
  @since   2002-09-24
}
procedure TCustomGpSharedEventSubject.ManagerOnEventSent(Sender: TObject;
  eventQueueHandle, eventHandle: TGpSEHandle; const eventName: string);
begin
  DoEventSent(eventQueueHandle, eventName);
end; { TCustomGpSharedEventSubject.ManagerOnEventSent }

{:TGpSharedEventManager.OnSubjectRegistered handler.
  @since   2002-09-24
}
procedure TCustomGpSharedEventSubject.ManagerOnSubjectRegistered(
  Sender: TObject; subjectHandle: TGpSEHandle; const subjectName: string;
  subjectIsProducer: boolean);
begin
  if subjectIsProducer then
    DoProducerRegistered(subjectHandle, subjectName)
  else
    DoListenerRegistered(subjectHandle, subjectName);
end; { TCustomGpSharedEventSubject.ManagerOnSubjectRegistered }

{:TGpSharedEventManager.OnEventUnpublished handler.
  @since   2002-09-24
}
procedure TCustomGpSharedEventSubject.ManagerOnEventUnpublished(
  Sender: TObject; subjectHandle: TGpSEHandle; const subjectName: string;
  eventHandle: TGpSEHandle; const eventName: string);
begin
  DoEventUnpublished(subjectHandle, subjectName, eventHandle, eventName);
end; { TCustomGpSharedEventSubject.ManagerOnEventUnpublished }

{:TGpSharedEventManager.OnSubjectUnregistered handler.
  @param subjectHandle WARNING Handle is not valid at that moment anymore!
  @since   2002-09-24
}
procedure TCustomGpSharedEventSubject.ManagerOnSubjectUnregistered(
  Sender: TObject; subjectHandle: TGpSEHandle; const subjectName: string;
  subjectIsProducer: boolean);
begin
  if subjectIsProducer then
    DoProducerUnregistered(subjectHandle, subjectName)
  else
    DoListenerUnregistered(subjectHandle, subjectName);
end; { ManagerOnSubjectUnregistered }

procedure TCustomGpSharedEventSubject.ReportError;
begin
  DoOnError;
end; { TCustomGpSharedEventSubject.ReportError }

{:Notify manager that we wan't to receive specified event.
}
function TCustomGpSharedEventSubject.MonitorEvent(const event: string): boolean;
begin
  if not Active then
    Result := SetError(seNotActive,sSharedEventManagerIsNotActive)
  else begin
    Result := SetError(esManager.MonitorEvent(event));
    esMonitoredEventsDirty := true;
  end;
end; { TCustomGpSharedEventSubject.MonitorEvent }

{:Register published event.
  @param   event Event name.
}
function TCustomGpSharedEventSubject.PublishEvent(const event: string): boolean;
begin
  if not Active then
    Result := SetError(seNotActive,sSharedEventManagerIsNotActive)
  else begin
    Result := SetError(esManager.PublishEvent(event));
    esPublishedEventsDirty := true;
  end;
end; { TCustomGpSharedEventSubject.PublishEvent }

{:Send event to a listener.
  @returns Handle of the Event Queue entry uniquely identifying this instance of
           the event or CInvalidSEHandle if BroadcastEvent failed.
}
function TCustomGpSharedEventSubject.SendEvent(listenerHandle: TGpSEHandle;
  const event, data: string): TGpSEHandle;
begin
  Result := CInvalidSEHandle;
  if not Active then
    SetError(seNotActive,sSharedEventManagerIsNotActive)
  else
    SetError(esManager.SendEvent(listenerHandle, event, data, Result));
end; { TCustomGpSharedEventSubject.SendEvent }

{:Set event manager status. Start/stop event manager.
}
procedure TCustomGpSharedEventSubject.SetActive(const Value: boolean);
begin
  if Value <> Active then begin
    if csDesigning in ComponentState then
      esActive := Value
    else if Value then begin
      if not Start then
        DoOnError
    end
    else begin
      if not Stop then
        DoOnError;
    end;
  end;
end; { TCustomGpSharedEventSubject.SetActive }

function TCustomGpSharedEventSubject.SetError(
  managerResult: boolean): boolean;
begin
  Result := managerResult;
  if Result then
    ClearError
  else
    SetError(TGpSharedEventError(esManager.LastError), esManager.LastErrorMsg);
end; { TCustomGpSharedEventSubject.SetError }

{:Set error code.
  @since   2002-09-24
}
function TCustomGpSharedEventSubject.SetError(
  errorCode: TGpSharedEventError; const errorMessage: string): boolean;
begin
  esLastError.SetError(Ord(errorCode), errorMessage);
  if csDesigning in ComponentState then
    raise Exception.Create(errorMessage)
  else
    DoOnError;
  Result := false;
end; { TCustomGpSharedEventSubject.SetError }

procedure TCustomGpSharedEventSubject.SetHookedEventHandlers;
begin
  if assigned(esManager) then begin
    if assigned(esOnEventIgnored) then
      esManager.OnEventIgnored := ManagerOnEventIgnored
    else
      esManager.OnEventIgnored := nil;
    if assigned(esOnEventMonitored) then
      esManager.OnEventMonitored := ManagerOnEventMonitored
    else
      esManager.OnEventMonitored := nil;
    if assigned(esOnEventPublished) then
      esManager.OnEventPublished := ManagerOnEventPublished
    else
      esManager.OnEventPublished := nil;
    if assigned(esOnEventUnpublished) then
      esManager.OnEventUnpublished := ManagerOnEventUnpublished
    else
      esManager.OnEventUnpublished := nil;
    if assigned(esOnListenerRegistered) or assigned(esOnProducerRegistered) then
      esManager.OnSubjectRegistered := ManagerOnSubjectRegistered
    else
      esManager.OnSubjectRegistered := nil;
    if assigned(esOnListenerUnregistered) or assigned(esOnProducerUnregistered) then
      esManager.OnSubjectUnregistered := ManagerOnSubjectUnregistered
    else
      esManager.OnSubjectUnregistered := nil;
  end;
end; { TCustomGpSharedEventSubject.SetHookedEventHandlers }

procedure TCustomGpSharedEventSubject.SetMonitoredEvents(
  const Value: TStringList);
var
  iEvent         : integer;
  ignoreList     : TStringList;
  monitoredEvents: TStringList;
  monitorList    : TStringList;
begin
  if not assigned(esManager) then begin
    if esMonitoredEvents <> Value then begin
      esMonitoredEvents.OnChange := nil;
      esMonitoredEvents.Assign(Value);
      esMonitoredEvents.OnChange := StringListChanged;
    end;
  end
  else begin
    monitoredEvents := TStringList.Create;
    try
      ignoreList := TStringList.Create;
      try
        monitorList := TStringList.Create;
        try
          esManager.GetMonitoredEvents(monitoredEvents);
          for iEvent := 0 to Value.Count-1 do
            if monitoredEvents.IndexOf(Value[iEvent]) < 0 then
              monitorList.Add(Value[iEvent]);
          for iEvent := 0 to monitoredEvents.Count-1 do
            if Value.IndexOf(monitoredEvents[iEvent]) < 0 then
              ignoreList.Add(monitoredEvents[iEvent]);
          for iEvent := 0 to monitorList.Count-1 do
            MonitorEvent(monitorList[iEvent]);
          for iEvent := 0 to ignoreList.Count-1 do
            IgnoreEvent(ignoreList[iEvent]);
        finally FreeAndNil(monitorList); end;
      finally FreeAndNil(ignoreList); end;
    finally FreeAndNil(monitoredEvents); end;
  end;
end; { TCustomGpSharedEventSubject.SetMonitoredEvents }

procedure TCustomGpSharedEventSubject.SetNamespace(const Value: string);
var
  oldActive: boolean;
begin
  if esNamespace <> Value then begin
    oldActive := Active;
    Active := false;
    esNamespace := Value;
    if (not (csLoading in ComponentState)) and oldActive then
      Active := (esNamespace <> '');
  end;
end; { TCustomGpSharedEventSubject.SetNamespace }

procedure TCustomGpSharedEventSubject.SetOnEventIgnored(
  const Value: TGpSEEventChangeListenerNotify);
begin
  esOnEventIgnored := Value;
  SetHookedEventHandlers;
end; { TCustomGpSharedEventSubject.SetOnEventIgnored }

procedure TCustomGpSharedEventSubject.SetOnEventMonitored(
  const Value: TGpSEEventChangeListenerNotify);
begin
  esOnEventMonitored := Value;
  SetHookedEventHandlers;
end; { TCustomGpSharedEventSubject.SetOnEventMonitored }

procedure TCustomGpSharedEventSubject.SetOnEventPublished(
  const Value: TGpSEEventChangeProducerNotify);
begin
  esOnEventPublished := Value;
  SetHookedEventHandlers;
end; { TCustomGpSharedEventSubject.SetOnEventPublished }

procedure TCustomGpSharedEventSubject.SetOnEventUnpublished(
  const Value: TGpSEEventChangeProducerNotify);
begin
  esOnEventUnpublished := Value;
  SetHookedEventHandlers;
end; { TCustomGpSharedEventSubject.SetOnEventUnpublished }

procedure TCustomGpSharedEventSubject.SetOnListenerRegistered(
  const Value: TGpSESubjectRegistrationNotify);
begin
  esOnListenerRegistered := Value;
  SetHookedEventHandlers;
end; { TCustomGpSharedEventSubject.SetOnListenerRegistered }

procedure TCustomGpSharedEventSubject.SetOnListenerUnregistered(
  const Value: TGpSESubjectRegistrationNotify);
begin
  esOnListenerUnregistered := Value;
  SetHookedEventHandlers;
end; { TCustomGpSharedEventSubject.SetOnListenerUnregistered }

procedure TCustomGpSharedEventSubject.SetOnProducerRegistered(
  const Value: TGpSESubjectRegistrationNotify);
begin
  esOnProducerRegistered := Value;
  SetHookedEventHandlers;
end; { TCustomGpSharedEventSubject.SetOnProducerRegistered }

procedure TCustomGpSharedEventSubject.SetOnProducerUnregistered(
  const Value: TGpSESubjectRegistrationNotify);
begin
  esOnProducerUnregistered := Value;
  SetHookedEventHandlers;
end; { TCustomGpSharedEventSubject.SetOnProducerUnregistered }

{:Set PublicName property. Update event manager.
}
procedure TCustomGpSharedEventSubject.SetPublicName(const Value: string);
var
  reactivate: boolean;
begin
  if esPublicName <> Value then begin
    reactivate := Active;
    Active := false;
    esPublicName := Value;
    Active := reactivate;
  end;
end; { TCustomGpSharedEventSubject.SetPublicName }

procedure TCustomGpSharedEventSubject.SetPublishedEvents(
  const Value: TStringList);
var
  iEvent         : integer;
  publishedEvents: TStringList;
  publishList    : TStringList;
  unpublishList  : TStringList;
begin
  if not assigned(esManager) then begin
    if esPublishedEvents <> Value then begin
      esPublishedEvents.OnChange := nil;
      esPublishedEvents.Assign(Value);
      esPublishedEvents.OnChange := StringListChanged;
    end;
  end
  else begin
    publishedEvents := TStringList.Create;
    try
      unpublishList := TStringList.Create;
      try
        publishList := TStringList.Create;
        try
          esManager.GetPublishedEvents(publishedEvents);
          for iEvent := 0 to Value.Count-1 do
            if publishedEvents.IndexOf(Value[iEvent]) < 0 then
              publishList.Add(Value[iEvent]);
          for iEvent := 0 to publishedEvents.Count-1 do
            if Value.IndexOf(publishedEvents[iEvent]) < 0 then
              unpublishList.Add(publishedEvents[iEvent]);
          for iEvent := 0 to publishList.Count-1 do
            PublishEvent(publishList[iEvent]);
          for iEvent := 0 to unpublishList.Count-1 do
            UnpublishEvent(unpublishList[iEvent]);
        finally FreeAndNil(publishList); end;
      finally FreeAndNil(unpublishList); end;
    finally FreeAndNil(publishedEvents); end;
  end;
end; { TCustomGpSharedEventSubject.SetPublishedEvents }

{:Start shared event manager and login into the shared event system.
  @Returns false on error.
}
function TCustomGpSharedEventSubject.Start: boolean;
begin
  Result := false;
  if not Stop then
    Exit;
  if Trim(esNamespace) = '' then
    SetError(seNamespaceNotSet, sNamespaceNotSpecified)
  else begin
    esManager := TGpSharedEventManager.Create(esNamespace, esPublicName, IsProducer);
    if esManager.Active then begin
      if IsProducer then
        SetPublishedEvents(esPublishedEvents)
      else
        SetMonitoredEvents(esMonitoredEvents);
      SetHookedEventHandlers;
      esManager.OnEventReceived := ManagerOnEventReceived;
      esManager.OnEventSent     := ManagerOnEventSent;
      Result := ClearError;
    end
    else begin
      SetError(false);
      Stop;
    end;
  end;
end; { TCustomGpSharedEventSubject.Start }

{:Stop shared event manager and logout from the shared event system.
  @returns True.
}
function TCustomGpSharedEventSubject.Stop : boolean;
begin
  FreeAndNil(esManager);
  Result := true;
end; { TCustomGpSharedEventSubject.Stop }

procedure TCustomGpSharedEventSubject.StringListChanged(Sender: TObject);
begin
  (Sender as TStringList).OnChange := nil;
  try
    if Sender = esMonitoredEvents then begin
      SetMonitoredEvents(TStringList(Sender));
      Sender := esMonitoredEvents;
    end
    else if Sender = esPublishedEvents then begin
      SetPublishedEvents(TStringList(Sender));
      Sender := esPublishedEvents;
    end
    else
      raise Exception.Create('Internal error in TCustomGpSharedEventSubject.StringListChanged: invalid list');
  finally TStringList(Sender).OnChange := StringListChanged; end;
end; { TCustomGpSharedEventSubject.StringListChanged }

{:Unregister published event.
  @param   event Event name.
}
function TCustomGpSharedEventSubject.UnpublishEvent(const event: string): boolean;
begin
  if not Active then
    Result := SetError(seNotActive,sSharedEventManagerIsNotActive)
  else begin
    Result := SetError(esManager.UnpublishEvent(event));
    esPublishedEventsDirty := true;
  end;
end; { TCustomGpSharedEventSubject.UnpublishEvent }

{ TGpSharedEventProducer }

function TGpSharedEventProducer.BroadcastEvent(const event, data: string): TGpSEHandle;
begin
  Result := inherited BroadcastEvent(event, data);
end; { TGpSharedEventProducer.BroadcastEvent }

class function TGpSharedEventProducer.IsProducer: boolean;
begin
  Result := true;
end; { TGpSharedEventProducer.IsProducer }

function TGpSharedEventProducer.ProducerHandle: TGpSEHandle;
begin
  Result := esManager.SubjectHandle;
end; { TGpSharedEventProducer.ProducerHandle }

function TGpSharedEventProducer.PublishEvent(const event: string): boolean;
begin
  Result := inherited PublishEvent(event);
end; { TGpSharedEventProducer.PublishEvent }

function TGpSharedEventProducer.SendEvent(listenerHandle: TGpSEHandle;
  const event, data: string): TGpSEHandle;
begin
  Result := inherited SendEvent(listenerHandle, event, data);
end; { TGpSharedEventProducer.SendEvent }

function TGpSharedEventProducer.UnpublishEvent(const event: string): boolean;
begin
  Result := inherited UnpublishEvent(event);
end; { TGpSharedEventProducer.UnpublishEvent }

{ TGpSharedEventListener }

function TGpSharedEventListener.IgnoreEvent(const event: string): boolean;
begin
  Result := inherited IgnoreEvent(event);
end; { TGpSharedEventListener.IgnoreEvent }

class function TGpSharedEventListener.IsProducer: boolean;
begin
  Result := false;
end; { TGpSharedEventListener.IsProducer }

function TGpSharedEventListener.ListenerHandle: TGpSEHandle;
begin
  Result := esManager.SubjectHandle;
end; { TGpSharedEventListener.ListenerHandle }

function TGpSharedEventListener.MonitorEvent(const event: string): boolean;
begin
  Result := inherited MonitorEvent(event);
end; { TGpSharedEventListener.MonitorEvent }

end.
