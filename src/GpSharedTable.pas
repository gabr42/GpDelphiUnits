(*:Shared table stored in shared memory block with SWMR access.
   @author Primoz Gabrijelcic
   @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2026, Primoz Gabrijelcic
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
   Creation date     : 2003-09-23
   Last modification : 2026-02-05
   Version           : 1.08b
</pre>*)(*
   History:
     1.08b: 2026-02-05
       - Fixed TGpBaseSharedTable.ToString not to crash if the table is locked.
     1.08a: 2014-05-20
       - Internal cache was not invalidated in Clear and RecreateListHeaders.
     1.08: 2014-01-06
       - 'Table full' exception message raised from AppendRow contains table contents
         if the application is compiled in DEBUG mode.
     1.07: 2010-02-17
       - DumpTable is working again and its output is easier to understand.
       - TGpBaseSharedTableEntry class contains virtual function Description which
         can be overridden in the descended class to provide nicer table dump.
       - AllocateRow correctly handles 'out of memory' condition.
       - If allocation fails, force defragmentation and retry.
       - TGpBaseSharedTable.Defragment made public.
     1.06: 2009-03-13
       - Added GetFieldBool and SetFieldBool helpers.
     1.05: 2007-10-26
       - Added overload for TGpBaseSharedTable.Read which returns flag signalling if the
         table was modified since the last access.
     1.04: 2006-05-03
       - Added TGpSharedNamedCounters.IndexOf public method.     
     1.03a: 2004-10-22
       - Setting a key to an empty string failed to update the shared data. Fixed.
     1.03: 2004-09-13
       - Added TGpSharedNamedValues class.
     1.02: 2004-03-17
       - Modified TGpSharedNamedCounters to remove Read, BeginUpdate, EndUpdate. All
         waits are implicit and INFINITE.
     1.01: 2004-03-16
       - Added method TGpSharedNamedCounters.Decrement.
     1.0: 2003-09-27
       - Released.
*)

unit GpSharedTable;

interface

uses
  Windows,
  SysUtils,
  Contnrs,
  Classes,
  GpSharedMemory,
  GpLists;

{$B-}
{$UNDEF EnableEnumerators}
{$IFDEF ConditionalExpressions}
  {$IF CompilerVersion >= 17}
    {$DEFINE EnableEnumerators}
  {$IFEND}
{$ENDIF ConditionalExpressions}

type
  EGpSharedTable = class(Exception);
  EGpSharedNamedCounters = class(Exception); 
  
  TGpSharedTableEntryStatus = (tesEmpty, tesNew, tesCopy);

  TGpBaseSharedTable = class;

  {:One entry (row) in the TGpSharedTable.
    Field layout:
      <field length:4><field data:*>
      ...
      <-1:4>
    @since   2003-09-23
  }
  TGpBaseSharedTableEntry = class
  private
    steFields  : TObjectList;
    steIndex   : integer;
    steModified: boolean;
    steOwner   : TGpBaseSharedTable;
    steStatus  : TGpSharedTableEntryStatus;
  protected
    function  AccessField(fieldIndex: integer): TMemoryStream;
    procedure AfterFetch; virtual;
    procedure BeforePost; virtual;
    procedure ClearField(fieldIndex: integer);
    function  FieldSize(fieldIndex: integer): integer;
    function  GetFieldOffset(rowStream: TStream; fieldIndex: integer;
      var fieldOffset, fieldLength: integer): boolean;
    procedure InternalClear(tableEntryStatus: TGpSharedTableEntryStatus;
      rowIndex: integer);
    property Field[fieldIndex: integer]: TMemoryStream read AccessField;
  public
    constructor Create(owner: TGpBaseSharedTable); virtual;
    destructor  Destroy; override;
    procedure Clear;
    function  EqualsField(fieldIndex, fieldSize: integer;
      const value): boolean;
    procedure Flush;
    procedure GetField(fieldIndex, fieldSize: integer; var buffer);
    procedure GetFieldStream(fieldIndex: integer; fieldStream: TStream);
    procedure New;
    procedure Reload(rowIndex: integer; rowStream: TStream);
    procedure SetField(fieldIndex, fieldSize: integer; const buffer);
    procedure SetFieldStream(fieldIndex: integer; fieldStream: TStream);
    property Index: integer read steIndex;
  end; { TGpBaseSharedTableEntry }

  {:Pretty face around TGpSharedTableEntry.
    @since   2003-09-24
  }
  TGpSharedTableEntry = class(TGpBaseSharedTableEntry)
  protected
    function  Description: string; virtual;
  public
    function  GetFieldAnsiStr(fieldIndex: integer): AnsiString;
    function  GetFieldBool(fieldIndex: integer): boolean;
    function  GetFieldByte(fieldIndex: integer): byte;
    function  GetFieldCardinal(fieldIndex: integer): cardinal;
    function  GetFieldDateTime(fieldIndex: integer): TDateTime;
    function  GetFieldInt(fieldIndex: integer): integer;
    function  GetFieldInt64(fieldIndex: integer): int64;
    function  GetFieldReal(fieldIndex: integer): real;
    function  GetFieldStr(fieldIndex: integer): string;
    function  GetFieldWideStr(fieldIndex: integer): WideString;
    procedure SetFieldAnsiStr(fieldIndex: integer; const value: AnsiString);
    procedure SetFieldBool(fieldIndex: integer; value: boolean);
    procedure SetFieldByte(fieldIndex: integer; value: byte);
    procedure SetFieldCardinal(fieldIndex: integer; value: cardinal);
    procedure SetFieldDateTime(fieldIndex: integer; value: TDateTime);
    procedure SetFieldInt(fieldIndex: integer; value: integer);
    procedure SetFieldInt64(fieldIndex: integer; value: int64);
    procedure SetFieldReal(fieldIndex: integer; value: real);
    procedure SetFieldStr(fieldIndex: integer; const value: string);
    procedure SetFieldWideStr(fieldIndex: integer; const value: WideString);
  end; { TGpSharedTableEntry }

  {:Cache mapping row indices into row base addresses.
    @since   2003-09-23
  }
  TGpSharedTableItemCache = class
  private
    icCache: TGpIntegerObjectList;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure Clear;
    procedure Delete(rowIndex: integer);
    procedure Insert(rowIndex, rowBaseAddress: integer);
    function  RetrieveBase(rowIndex: integer; var rowBaseAddress,
      lastLowestRow: integer): boolean;
    function  ToString: string; {$IFDEF Unicode}override;{$ENDIF}
    procedure Update(rowIndex, rowBaseAddress: integer);
  end; { TGpSharedTableItemCache }

  TGpSharedTableEntryClass = class of TGpSharedTableEntry;

  {:Table stored in shared memory.
    Memory layout:
      [ 0]   <signature:8>
      [ 8]   <number of entries:4>
      [12]   <alignment filler:4>
      [16]   <free list header:16>
      [48]   <used list header:16>
      [80]   <list entry header:8><data length:4><data:*>
             ...
    @since   2003-09-23
  }
  TGpBaseSharedTable = class(TGpSharedMemoryCandy)
  private
    stEntryClass: TGpSharedTableEntryClass;
    stFreeList  : TGpSharedLinkedList;
    stInstance  : TGpSharedTableEntry;
    stItemCache : TGpSharedTableItemCache;
    stLastError : string;
    stMaxSize   : integer;
    stMemory    : TGpSharedMemory;
    stName      : string;
    stReadCopy  : TGpSharedSnapshot;
    stSize      : integer;
    stUsedList  : TGpSharedLinkedList;
    {$IFDEF DebugSharedTable}
    stLogger    : IInterface {IGpLogger};
    {$ENDIF DebugSharedTable}
  protected
    {$IFDEF DebugSharedTable}
    procedure DumpTable;
    {$ENDIF DebugSharedTable}
  protected
    function  AllocateRow(dataSize: integer): integer;
    function  AppendRow(rowStream: TStream): integer;
    function  FindSmallestFreeBlock(dataSize: integer): integer;
    function  GetItem(idxItem: integer): TGpSharedTableEntry;
    function  LocateBase(rowIndex: integer): integer;
    function  Memory: TGpBaseSharedMemory; override;
    procedure RecreateListHeaders;
    procedure ReloadSnapshot;
    function  SplitEntry(baseAddress, dataSize: integer): integer;
    procedure UpdateRow(rowIndex: integer; rowStream: TStream);
    property DataAddress[baseAddress: integer]: pointer index 12 read GetBaseAddress;
    property DataLength[baseAddress: integer]: integer index 8 read GetBaseInt write SetBaseInt;
    property NumberOfEntries: integer index 8 read GetInt write SetInt;
    property Signature: int64 index 0 read GetHuge write SetHuge;
  public
    constructor Create(const sharedTableName: string;
      entryClass: TGpSharedTableEntryClass; sharedTableSize: integer;
      sharedTableMaxSize: integer = 0); overload;
    constructor Create(const sharedTableName: string;
      sharedTableSize: integer; sharedTableMaxSize: integer = 0); overload;
    destructor  Destroy; override;
    function  Add: TGpSharedTableEntry; virtual;
    function  Base64Dump: string;
    function  BeginUpdate(timeout: cardinal): boolean;
    procedure Clear;
    function  Count: integer;
    procedure Defragment(force: boolean = false);
    procedure Delete(rowIndex: integer); virtual;
    procedure EndUpdate;
    procedure Flush;
    function  Initialize(timeout: cardinal): boolean;
    function  Locate(fieldIndex, fieldSize: integer; const value): integer;
    function  Read(timeout: cardinal): boolean; overload;
    function  Read(timeout: cardinal; var modified: boolean): boolean; overload;
    function  ToString: string; override;
    property Items[idxItem: integer]: TGpSharedTableEntry read GetItem; default;
    property LastError: string read stLastError;
    property Name: string read stName;
  end; { TGpBaseSharedTable }

  {:Pretty face around TGpBaseSharedTable.
    @since   2003-09-24
  }
  TGpSharedTable = class(TGpBaseSharedTable)
  public
    function  LocateByte(fieldIndex: integer; value: byte): integer;
    function  LocateCardinal(fieldIndex: integer; value: cardinal): integer;
    function  LocateDateTime(fieldIndex: integer; value: TDateTime): integer;
    function  LocateInt(fieldIndex: integer; value: integer): integer;
    function  LocateInt64(fieldIndex: integer; value: int64): integer;
    function  LocateReal(fieldIndex: integer; value: real): integer;
    function  LocateStr(fieldIndex: integer; const value: AnsiString): integer;
  end; { TGpSharedTable }

const
  CCountersFieldName  = 0;
  CCountersFieldValue = 1;

type
  {:An entry in the TGpSharedNamedCounters table.
    @since   2003-09-27
  }
  TGpSharedNamedCountersEntry = class(TGpSharedTableEntry)
  public
    property Name: AnsiString index CCountersFieldName read GetFieldAnsiStr write SetFieldAnsiStr;
    property Value: integer index CCountersFieldValue read GetFieldInt write SetFieldInt;
  end; { TGpSharedNamedCountersEntry }

  {:TGpSharedTable-based named counters (string and associated integer).
    At the same time serves as an example of using TGpSharedTable in a real-world application.
    Accessors are simplified - all waits are implicit and INFINITE.
    @since   2003-09-26
  }
  TGpSharedNamedCounters = class
  private
    sncTable: TGpSharedTable;
  protected
    function  GetCounter(const counterName: AnsiString): integer;
    function  GetCounterName(idxCounter: integer): AnsiString;
    function  GetItem(idxItem: integer): TGpSharedNamedCountersEntry;
    function  GetLastError: string;
    function  GetName: string;
    function  Locate(const counterName: AnsiString): integer;
    procedure SetCounter(const counterName: AnsiString; const value: integer);
    procedure SetCounterName(idxCounter: integer; const value: AnsiString);
    property Items[idxItem: integer]: TGpSharedNamedCountersEntry read GetItem;
  public
    constructor Create(const sharedCountersName: string; sharedCountersSize: integer;
      sharedCountersMaxSize: integer = 0);
    destructor  Destroy; override;
    function  Add(const counterName: AnsiString): integer;
    function  Count: integer;
    function  Decrement(const counterName: AnsiString): integer;
    procedure Delete(const counterName: AnsiString);
    function  Increment(const counterName: AnsiString): integer;
    function  IndexOf(const counterName: AnsiString): integer;
    function  Initialize: boolean;
    property Counter[const counterName: AnsiString]: integer
       read GetCounter write SetCounter; default;
    property CounterName[idxCounter: integer]: AnsiString
      read GetCounterName write SetCounterName;
    property LastError: string read GetLastError;
    property Name: string read GetName;
  end; { TGpSharedNamedCounters }

const
  CValuesFieldKey   = 0;
  CValuesFieldValue = 1;

type
  {:An entry in the TGpSharedNamedValues table.
    @since   2004-09-13
  }
  TGpSharedNamedValuesEntry = class(TGpSharedTableEntry)
  public
    property Name: AnsiString index CValuesFieldKey read GetFieldAnsiStr write SetFieldAnsiStr;
    property Value: AnsiString index CValuesFieldValue read GetFieldAnsiStr write SetFieldAnsiStr;
  end; { TGpSharedNamedValuesEntry }

  {$IFDEF EnableEnumerators}
  TGpSharedNamedValuesEnumerator = class
  private
    snveCurrentIdx: integer;
    snveKeyNames  : TStringList;
  protected
    property KeyNames: TStringList read snveKeyNames;
  public
    constructor Create;
    destructor  Destroy; override;
    function MoveNext: boolean; inline;
    function GetCurrent: string;
    property Current: string read GetCurrent;
  end; { TGpSharedNamedValuesEnumerator }
  {$ENDIF EnableEnumerators}

  {:TGpSharedTable-based named values (string key and associated string value).
    At the same time serves as an example of using TGpSharedTable in a real-world application.
    Accessors are simplified - all waits are implicit and INFINITE.
    @since   2004-09-13
  }
  TGpSharedNamedValues = class
  private
    snvTable: TGpSharedTable;
  protected
    function  Add(const key: AnsiString): integer;
    function  GetValue(const key: AnsiString): AnsiString;
    function  GetItem(idxItem: integer): TGpSharedNamedValuesEntry;
    function  GetLastError: string;
    function  GetName: string;
    function  Locate(const key: AnsiString): integer;
    procedure SetValue(const key, value: AnsiString);
    property Items[idxItem: integer]: TGpSharedNamedValuesEntry read GetItem;
  public
    constructor Create(const sharedValuesName: string; sharedValuesSize: integer;
      sharedValuesMaxSize: integer = 0);
    destructor  Destroy; override;
    procedure DeleteKey(const key: AnsiString);
    {$IFDEF EnableEnumerators}
    function  GetEnumerator: TGpSharedNamedValuesEnumerator;
    {$ENDIF EnableEnumerators}
    function  Initialize: boolean;
    property Value[const key: AnsiString]: AnsiString read GetValue write SetValue; default;
    property LastError: string read GetLastError;
    property Name: string read GetName;
  end; { TGpSharedNamedValues }

implementation

uses
  Math,
  {$IFDEF DebugSharedTable}
  GpLogger,
  {$ENDIF DebugSharedTable}
  GpString,
  GpStuff,
  GpStreams,
  OmniXMLUtils;

const
  CGpSharedTableSignature = $0DF86D7F64BCD82E; // random 8-byte value
  CListsBeginAt = 16;
  CEntryHeaderSize = 12;

{ TGpBaseSharedTableEntry }

function TGpBaseSharedTableEntry.AccessField(
  fieldIndex: integer): TMemoryStream;
begin
  while steFields.Count <= fieldIndex do
    steFields.Add(TMemoryStream.Create);
  Result := TMemoryStream(steFields[fieldIndex]);
end; { TGpBaseSharedTableEntry.AccessField }

procedure TGpBaseSharedTableEntry.AfterFetch;
begin
  // empty
end; { TGpBaseSharedTableEntry.AfterFetch }

procedure TGpBaseSharedTableEntry.BeforePost;
begin
  // empty
end; { TGpBaseSharedTableEntry.BeforePost }

procedure TGpBaseSharedTableEntry.Clear;
begin
  InternalClear(tesEmpty, -1);
end; { TGpBaseSharedTableEntry.Clear }

procedure TGpBaseSharedTableEntry.ClearField(fieldIndex: integer);
begin
  Field[fieldIndex].Size := 0;
  steModified := true;
end; { TGpBaseSharedTableEntry.ClearField }

constructor TGpBaseSharedTableEntry.Create(owner: TGpBaseSharedTable);
begin
  inherited Create;
  steOwner := owner;
  steFields := TObjectList.Create;
end; { TGpBaseSharedTableEntry.Create }

destructor TGpBaseSharedTableEntry.Destroy;
begin
  FreeAndNil(steFields);
  inherited;
end; { TGpBaseSharedTableEntry.Destroy }

function TGpBaseSharedTableEntry.EqualsField(fieldIndex, fieldSize: integer;
  const value): boolean;
begin
  Result :=
    (Field[fieldIndex].Size = fieldSize) and
    CompareMem(Field[fieldIndex].Memory, @value, fieldSize);
end; { TGpBaseSharedTableEntry.EqualsField }

function TGpBaseSharedTableEntry.FieldSize(fieldIndex: integer): integer;
begin
  Result := Field[fieldIndex].Size;
end; { TGpBaseSharedTableEntry.FieldSize }

procedure TGpBaseSharedTableEntry.Flush;
var
  fieldLength: integer;
  iField     : integer;
  rowStream  : TMemoryStream;
begin
  if not assigned(steOwner) then begin
    steModified := false;
    Exit;
  end;
  if steStatus <> tesEmpty then begin
    BeforePost;
    if steModified then begin
      rowStream := TMemoryStream.Create;
      try
        for iField := 0 to steFields.Count-1 do begin
          fieldLength := Field[iField].Size;
          rowStream.Write(fieldLength, 4);
          if fieldLength > 0 then
            rowStream.CopyFrom(Field[iField], 0);
        end; //for
        fieldLength := -1;
        rowStream.Write(fieldLength, 4);
        if steStatus = tesNew then
          steIndex := steOwner.AppendRow(rowStream)
        else
          steOwner.UpdateRow(steIndex, rowStream);
        steModified := false;
        steStatus := tesCopy;
      finally FreeAndNil(rowStream); end;
    end;
  end;
end; { TGpBaseSharedTableEntry.Flush }

procedure TGpBaseSharedTableEntry.GetField(fieldIndex, fieldSize: integer;
  var buffer);
begin
  Field[fieldIndex].Position := 0;
  Field[fieldIndex].Read(buffer, fieldSize);
end; { TGpBaseSharedTableEntry.GetField }

function TGpBaseSharedTableEntry.GetFieldOffset(rowStream: TStream;
  fieldIndex: integer; var fieldOffset, fieldLength: integer): boolean;
begin
  while (fieldIndex >= 0) and (rowStream.Read(fieldLength, 4) = 4) and (fieldLength >= 0) do begin
    fieldOffset := rowStream.Position;
    rowStream.Position := rowStream.Position + fieldLength;
    Dec(fieldIndex);
  end;
  Result := (fieldLength >= 0);
end; { TGpBaseSharedTableEntry.GetFieldOffset }

procedure TGpBaseSharedTableEntry.GetFieldStream(fieldIndex: integer;
  fieldStream: TStream);
begin
  fieldStream.Size := 0;
  fieldStream.CopyFrom(Field[fieldIndex], 0);
end; { TGpBaseSharedTableEntry.GetFieldStream }

procedure TGpBaseSharedTableEntry.InternalClear(
  tableEntryStatus: TGpSharedTableEntryStatus; rowIndex: integer);
begin
  Flush;
  steStatus := tableEntryStatus;
  steIndex := rowIndex;
  steFields.Clear;
end; { TGpBaseSharedTableEntry.InternalClear }

procedure TGpBaseSharedTableEntry.New;
begin
  InternalClear(tesNew, -1);
  AfterFetch;
end; { TGpBaseSharedTableEntry.New }

procedure TGpBaseSharedTableEntry.Reload(rowIndex: integer; rowStream: TStream);
var
  fieldLength: integer;
begin
  InternalClear(tesCopy, rowIndex);
  while (rowStream.Read(fieldLength, 4) = 4) and (fieldLength >= 0) do
    if fieldLength > 0 then
      Field[steFields.Count].CopyFrom(rowStream, fieldLength)
    else
      Field[steFields.Count]; // touch to create
  AfterFetch;
end; { TGpBaseSharedTableEntry.Reload }

procedure TGpBaseSharedTableEntry.SetField(fieldIndex, fieldSize: integer;
  const buffer);
begin
  Field[fieldIndex].Size := 0;
  Field[fieldIndex].Write(buffer, fieldSize);
  steModified := true;
end; { TGpBaseSharedTableEntry.SetField }

procedure TGpBaseSharedTableEntry.SetFieldStream(fieldIndex: integer;
  fieldStream: TStream);
begin
  Field[fieldIndex].Size := 0;
  Field[fieldIndex].CopyFrom(fieldStream, 0);
  steModified := true;
end; { TGpBaseSharedTableEntry.SetFieldStream }

function TGpSharedTableEntry.Description: string;
begin
  Result := '';
end; { TGpSharedTableEntry.Description }

function TGpSharedTableEntry.GetFieldAnsiStr(fieldIndex: integer): AnsiString;
begin
  SetLength(Result, FieldSize(fieldIndex));
  if Result <> '' then
    GetField(fieldIndex, Length(Result), Result[1]);
end; { TGpSharedTableEntry.GetFieldAnsiStr }

{ TGpSharedTableEntry }

function TGpSharedTableEntry.GetFieldBool(fieldIndex: integer): boolean;
begin
  GetField(fieldIndex, SizeOf(Result), Result);
end; { TGpSharedTableEntry.GetFieldBool }

function TGpSharedTableEntry.GetFieldByte(fieldIndex: integer): byte;
begin
  GetField(fieldIndex, SizeOf(Result), Result);
end; { TGpSharedTableEntry.GetFieldByte }

function TGpSharedTableEntry.GetFieldCardinal(fieldIndex: integer): cardinal;
begin
  GetField(fieldIndex, SizeOf(Result), Result);
end; { TGpSharedTableEntry.GetFieldCardinal }

function TGpSharedTableEntry.GetFieldDateTime(
  fieldIndex: integer): TDateTime;
begin
  GetField(fieldIndex, SizeOf(Result), Result);
end; { TGpSharedTableEntry.GetFieldDateTime }

function TGpSharedTableEntry.GetFieldInt(fieldIndex: integer): integer;
begin
  GetField(fieldIndex, SizeOf(Result), Result);
end; { TGpSharedTableEntry.GetFieldInt }

function TGpSharedTableEntry.GetFieldInt64(fieldIndex: integer): int64;
begin
  GetField(fieldIndex, SizeOf(Result), Result);
end; { TGpSharedTableEntry.GetFieldReal }

function TGpSharedTableEntry.GetFieldReal(fieldIndex: integer): real;
begin
  GetField(fieldIndex, SizeOf(Result), Result);
end; { TGpSharedTableEntry.GetFieldReal }

function TGpSharedTableEntry.GetFieldStr(fieldIndex: integer): string;
begin
  {$IFDEF Unicode}
  Result := GetFieldWideStr(fieldIndex);
  {$ELSE}
  Result := GetFieldAnsiStr(fieldIndex);
  {$ENDIF}
end; { TGpSharedTableEntry.GetFieldStr }

function TGpSharedTableEntry.GetFieldWideStr(fieldIndex: integer): WideString;
begin
  SetLength(Result, FieldSize(fieldIndex) div SizeOf(WideChar));
  if Result <> '' then
    GetField(fieldIndex, Length(Result) * SizeOf(WideChar), Result[1]);
end; { TGpSharedTableEntry.GetFieldWideStr }

procedure TGpSharedTableEntry.SetFieldAnsiStr(fieldIndex: integer;
  const value: AnsiString);
begin
  if value = '' then
    ClearField(fieldIndex)
  else
    SetField(fieldIndex, Length(value), value[1]);
end; { TGpSharedTableEntry.SetFieldAnsiStr }

procedure TGpSharedTableEntry.SetFieldBool(fieldIndex: integer; value: boolean);
begin
  SetField(fieldIndex, SizeOf(value), value);
end; { TGpSharedTableEntry.SetFieldBool }

procedure TGpSharedTableEntry.SetFieldByte(fieldIndex: integer; value: byte);
begin
  SetField(fieldIndex, SizeOf(value), value);
end; { TGpSharedTableEntry.SetFieldByte }

procedure TGpSharedTableEntry.SetFieldCardinal(fieldIndex: integer;
  value: cardinal);
begin
  SetField(fieldIndex, SizeOf(value), value);
end; { TGpSharedTableEntry.SetFieldCardinal }

procedure TGpSharedTableEntry.SetFieldDateTime(fieldIndex: integer;
  value: TDateTime);
begin
  SetField(fieldIndex, SizeOf(value), value);
end; { TGpSharedTableEntry.SetFieldDateTime }

procedure TGpSharedTableEntry.SetFieldInt(fieldIndex, value: integer);
begin
  SetField(fieldIndex, SizeOf(value), value);
end; { TGpSharedTableEntry.SetFieldInt }

procedure TGpSharedTableEntry.SetFieldInt64(fieldIndex: integer;
  value: int64);
begin
  SetField(fieldIndex, SizeOf(value), value);
end; { TGpSharedTableEntry.SetFieldInt64 }

procedure TGpSharedTableEntry.SetFieldReal(fieldIndex: integer; value: real);
begin
  SetField(fieldIndex, SizeOf(value), value);
end; { TGpSharedTableEntry.SetFieldReal }

procedure TGpSharedTableEntry.SetFieldStr(fieldIndex: integer; const value: string);
begin
  {$IFDEF Unicode}
  SetFieldWideStr(fieldIndex, value);
  {$ELSE}
  SetFieldAnsiStr(fieldIndex, value);
  {$ENDIF}
end; { TGpSharedTableEntry.SetFieldStr }

procedure TGpSharedTableEntry.SetFieldWideStr(fieldIndex: integer;
  const value: WideString);
begin
  if value = '' then
    ClearField(fieldIndex)
  else
    SetField(fieldIndex, Length(value)*SizeOf(WideChar), value[1]);
end; { TGpSharedTableEntry.SetFieldWideStr }

{ TGpSharedTableItemCache }

procedure TGpSharedTableItemCache.Clear;
begin
  icCache.Clear;
end; { TGpSharedTableItemCache.Clear }

constructor TGpSharedTableItemCache.Create;
begin
  inherited Create;
  icCache := TGpIntegerObjectList.Create(false);
  icCache.Sorted := true;
end; { TGpSharedTableItemCache.Create }

{:Deletes rowIndex from the cache and updates all entries with higher row
  indices.
  @since   2003-09-27
}
procedure TGpSharedTableItemCache.Delete(rowIndex: integer);
var
  idxRow: integer;
  iRow  : integer;
begin
  idxRow := icCache.IndexOf(rowIndex);
  if idxRow >= 0 then begin
    icCache.Delete(idxRow);
    for iRow := idxRow to icCache.Count-1 do
      icCache[iRow] := icCache[iRow] - 1;
  end;
end; { TGpSharedTableItemCache.Delete }

destructor TGpSharedTableItemCache.Destroy;
begin
  FreeAndNil(icCache);
  inherited;
end; { TGpSharedTableItemCache.Destroy }

procedure TGpSharedTableItemCache.Insert(rowIndex,
  rowBaseAddress: integer);
begin
  icCache.AddObject(rowIndex, TObject(rowBaseAddress));
end; { TGpSharedTableItemCache.Insert }

{:Retrieves base address of the rowIndex row from the cache.
  If row is found, base address is returned in the rowBaseAddress, lastLowestRow
  is undefined, and result is True.
  if row is not found, highest cached row index below rowIndex is returned in
  the lastLowestRow, address of that row is returned in rowBaseAddress, and
  lastLowestRow is False.
  @since   2003-09-24
}
function TGpSharedTableItemCache.RetrieveBase(rowIndex: integer;
  var rowBaseAddress, lastLowestRow: integer): boolean;
begin
  Result := icCache.Find(rowIndex, lastLowestRow);
  if not Result then
    Dec(lastLowestRow);
  if lastLowestRow < 0 then
    rowBaseAddress := 0
  else
    rowBaseAddress := integer(icCache.Objects[lastLowestRow]);
end; { TGpSharedTableItemCache.RetrieveBase }

function TGpSharedTableItemCache.ToString: string;
var
  i: integer;
begin
  Result := '';
  for i := 0 to icCache.Count - 1 do begin
    if i > 0 then
      Result := Result + #13#10;
    Result := Result + Format('%d: %d / %d', [i, icCache[i], NativeInt(icCache.Objects[i])]);
  end;
end; { TGpSharedTableItemCache.ToString }

procedure TGpSharedTableItemCache.Update(rowIndex,
  rowBaseAddress: integer);
var
  idxCache: integer;
begin
  idxCache := icCache.IndexOf(rowIndex);
  if idxCache < 0 then
    Insert(rowIndex, rowBaseAddress)
  else
    icCache.Objects[idxCache] := TObject(rowBaseAddress);
end; { TGpSharedTableItemCache.Update }

{ TGpBaseSharedTable }

function TGpBaseSharedTable.Add: TGpSharedTableEntry;
begin
  stInstance.New;
  Result := stInstance;
end; { TGpBaseSharedTable.Add }

{:Allocates row for dataSize bytes from the free memory, sets its data length
  field and returns its base address. Returned memory block is orphaned - caller
  is responsible for enqueueing it into the used list.
  To reduce the fragmentation, following steps are applied to each allocation:
  - Allocation size (including entry header and data length) is round up to the
    nearest multiplier of 16.
  - If less then 20 bytes would be left in the memory block after the
    allocation, whole block is allocated.
  @since   2003-09-25
}
function TGpBaseSharedTable.AllocateRow(dataSize: integer): integer;
begin
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('AllocateRow(data size = %d)', [dataSize]);
  {$ENDIF DebugSharedTable}
  dataSize := ((dataSize + CEntryHeaderSize - 1) div 16 + 1) * 16 - CEntryHeaderSize;
  Result := FindSmallestFreeBlock(dataSize);
  if Result < 0 then begin
    Defragment(true);
    Result := FindSmallestFreeBlock(dataSize);
  end;
  if Result < 0 then
    raise EGpSharedTable.Create('Cannot allocate free block');
  if (DataLength[Result] - dataSize) >= (16 - CEntryHeaderSize + 16) then
    stFreeList.EnqueueAfter(Result, SplitEntry(Result, dataSize));
  stFreeList.Dequeue(Result);
  {$IFDEF DebugSharedTable}
  DumpTable;
  (stLogger as IGpLogger).Log('AllocateRow => %d', [Result]);
  {$ENDIF DebugSharedTable}
end; { TGpBaseSharedTable.AllocateRow }

function TGpBaseSharedTable.AppendRow(rowStream: TStream): integer;
var
  baseAddress: integer;
begin
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('AppendRow(stream size = %d)', [rowStream.Size]);
  {$ENDIF DebugSharedTable}
  baseAddress := AllocateRow(rowStream.Size);
  if baseAddress = 0 then
    raise EGpSharedTable.CreateFmt('Shared memory %s is full.'#13#10
      {$IFDEF DEBUG}+ 'Table content: %s'{$ENDIF},
      [Name {$IFDEF DEBUG}, ToString{$ENDIF}]);
  rowStream.Position := 0;
  rowStream.Read(DataAddress[baseAddress]^, rowStream.Size);
  stUsedList.EnqueueTail(baseAddress);
  Result := NumberOfEntries;
  NumberOfEntries := NumberOfEntries + 1;
  {$IFDEF DebugSharedTable}
  DumpTable;
  (stLogger as IGpLogger).Log('AppendRow => %d', [Result]);
  {$ENDIF DebugSharedTable}
end; { TGpBaseSharedTable.AppendRow }

function TGpBaseSharedTable.Base64Dump: string;
var
  isAcquired: boolean;
begin
  isAcquired := Memory.Acquired;
  if (not isAcquired) and (Memory.AcquireMemory(false, 10*1000) = nil) then
    Result := 'Timeout'
  else try
    Result := Base64Encode(Memory.AsStream);
  finally
    if not isAcquired then
      Memory.ReleaseMemory;
  end;
end; { TGpBaseSharedTable.Base64Dump }

function TGpBaseSharedTable.BeginUpdate(timeout: cardinal): boolean;
begin
  Result := assigned(stMemory.AcquireMemory(true, timeout));
  if Result then
    RecreateListHeaders;
end; { TGpBaseSharedTable.BeginUpdate }

{:Removes all data from the table.
  @since   2003-09-27
}        
procedure TGpBaseSharedTable.Clear;
var
  freeListEntry: integer;
begin
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('Clear');
  {$ENDIF DebugSharedTable}
  NumberOfEntries := 0;
  stFreeList.Clear;
  stUsedList.Clear;
  stItemCache.Clear;
  freeListEntry := CListsBeginAt + stFreeList.HeaderSize + stUsedList.HeaderSize;
  DataLength[freeListEntry] := IFF(stMaxSize = 0, stSize, stMaxSize) - freeListEntry - CEntryHeaderSize;
  stFreeList.EnqueueHead(freeListEntry);
  {$IFDEF DebugSharedTable}
  DumpTable;
  {$ENDIF DebugSharedTable}
end; { TGpBaseSharedTable.Clear }

function TGpBaseSharedTable.Count: integer;
begin
  stInstance.Flush;
  Result := NumberOfEntries;
end; { TGpBaseSharedTable.Count }

constructor TGpBaseSharedTable.Create(const sharedTableName: string;
  entryClass: TGpSharedTableEntryClass; sharedTableSize,
  sharedTableMaxSize: integer);
begin
  inherited Create;
  {$IFDEF DebugSharedTable}
  stLogger := CreateGpLogger(ExtractFilePath(ParamStr(0))+'sharedtable.log',
    [loLogTime, loLogProcessID]);
  {$ENDIF DebugSharedTable}
  stName := sharedTableName;
  stSize := sharedTableSize;
  stMaxSize := sharedTableMaxSize;
  stEntryClass := entryClass;
  stInstance := entryClass.Create(Self);
  stItemCache := TGpSharedTableItemCache.Create;
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('Creating shared table %s', [sharedTableName]);
  {$ENDIF DebugSharedTable}
end; { TGpBaseSharedTable.Create }

constructor TGpBaseSharedTable.Create(const sharedTableName: string;
  sharedTableSize, sharedTableMaxSize: integer);
begin
  Create(sharedTableName, TGpSharedTableEntry, sharedTableSize,
    sharedTableMaxSize);
end; { TGpBaseSharedTable.Create }

{:If there are too many free blocks, compress them into one free block.
  Required, because .Delete doesn't merge free blocks.
  Database is deemed 'too fragmented' if the average size of free blocks is less
  than twice the average size of used blocks.
  @since   2003-09-25
}
procedure TGpBaseSharedTable.Defragment(force: boolean);
var
  currentBase   : integer;
  freeBase      : integer;
  freeSize      : integer;
  iUsed         : integer;
  sortedUsedList: TGpIntegerList;
  usedBase      : integer;
begin
  if (stUsedList.Count = 0) and (stFreeList.Count > 1) then begin
    Clear;
    Exit;
  end
  else if (stFreeList.Count <= 1) or (stUsedList.Count = 0) then
    Exit;
  if not force then begin
    freeSize := 0;
    freeBase := stFreeList.Head;
    while freeBase <> 0 do begin
      Inc(freeSize, DataLength[freeBase] + CEntryHeaderSize);
      freeBase := stFreeList.Next(freeBase);
    end; //while
    if freeSize/stFreeList.Count > 2*(IFF(stMaxSize=0,stSize,stMaxSize)-freeSize)/stUsedList.Count then
      Exit;
  end;
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('Defragment');
  {$ENDIF DebugSharedTable}
  stItemCache.Clear;
  sortedUsedList := TGpIntegerList.Create;
  try
    sortedUsedList.Sorted := true;
    usedBase := stUsedList.Head;
    while usedBase <> 0 do begin
      sortedUsedList.Add(usedBase);
      usedBase := stUsedList.Next(usedBase);
    end; //while
    currentBase := CListsBeginAt + stFreeList.HeaderSize + stUsedList.HeaderSize;
    stUsedList.Clear;
    for iUsed := 0 to sortedUsedList.Count-1 do begin
      if sortedUsedList[iUsed] <> currentBase then
        Move(Memory.Address[sortedUsedList[iUsed]]^, Memory.Address[currentBase]^,
          DataLength[sortedUsedList[iUsed]] + CEntryHeaderSize);
      stItemCache.Insert(iUsed, currentBase);
      stUsedList.EnqueueTail(currentBase);
      Inc(currentBase, DataLength[currentBase] + CEntryHeaderSize);
    end; //for
    stFreeList.Clear;
    DataLength[currentBase] := IFF(stMaxSize = 0, stSize, stMaxSize) - currentBase - CEntryHeaderSize;
    stFreeList.EnqueueHead(currentBase);
  finally FreeAndNil(sortedUsedList); end;
  {$IFDEF DebugSharedTable}
  DumpTable;
  {$ENDIF DebugSharedTable}
end; { TGpBaseSharedTable.Defragment }

procedure TGpBaseSharedTable.Delete(rowIndex: integer);
var
  rowBase: integer;
begin
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('Delete(row index = %d)', [rowIndex]);
  {$ENDIF DebugSharedTable}
  if rowIndex = stInstance.Index then
    stInstance.Clear;
  rowBase := LocateBase(rowIndex);
  if rowBase <= 0 then
    Exit;
  stItemCache.Delete(rowIndex);
  stUsedList.Dequeue(rowBase);
  stFreeList.EnqueueHead(rowBase);
  NumberOfEntries := NumberOfEntries - 1;
  {$IFDEF DebugSharedTable}
  DumpTable;
  {$ENDIF DebugSharedTable}
end; { TGpBaseSharedTable.Delete }

destructor TGpBaseSharedTable.Destroy;
begin
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('Destroying shared table %s', [Name]);
  {$ENDIF DebugSharedTable}
  FreeAndNil(stItemCache);
  FreeAndNil(stInstance);
  FreeAndNil(stReadCopy);
  FreeAndNil(stMemory);
  FreeAndNil(stFreeList);
  FreeAndNil(stUsedList);
  inherited;
end; { TGpBaseSharedTable.Destroy }

{$IFDEF DebugSharedTable}
procedure TGpBaseSharedTable.DumpTable;
begin
  (stLogger as IGpLogger).Log(ToString);
end; { TGpBaseSharedTable.DumpTable }
{$ENDIF DebugSharedTable}

procedure TGpBaseSharedTable.EndUpdate;
begin
  if stMemory.Acquired then begin
    {$IFDEF DebugSharedTable}
    (stLogger as IGpLogger).Log('EndUpdate');
    {$ENDIF DebugSharedTable}
    stInstance.Flush;
    Defragment;
    ReloadSnapshot;
    {$IFDEF DebugSharedTable}
    DumpTable;
    {$ENDIF DebugSharedTable}
    stMemory.ReleaseMemory;
  end;
end; { TGpBaseSharedTable.EndUpdate }

{:Locates smallest free block that can accomodate dataSize data bytes.
  @since   2003-09-25
}        
function TGpBaseSharedTable.FindSmallestFreeBlock(
  dataSize: integer): integer;
var
  freeAddr: integer;
  freeSize: integer;
  minSize : integer;
begin
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('FindSmallestFreeBlock(data size = %d)', [dataSize]);
  {$ENDIF DebugSharedTable}
  Result := -1;
  minSize := High(minSize); //to keep Delphi happy
  freeAddr := stFreeList.Head;
  while freeAddr <> 0 do begin
    freeSize := DataLength[freeAddr];
    if (freeSize >= dataSize) and ((Result = 0) or (freeSize < minSize)) then begin
      minSize := freeSize;
      Result := freeAddr;
    end;
    freeAddr := stFreeList.Next(freeAddr);
  end; //while
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('FindSmallestFreeBlock => %d', [Result]);
  {$ENDIF DebugSharedTable}
end; { TGpBaseSharedTable.FindSmallestFreeBlock }

procedure TGpBaseSharedTable.Flush;
begin
  stInstance.Flush;
end; { TGpBaseSharedTable.Flush }

function TGpBaseSharedTable.GetItem(idxItem: integer): TGpSharedTableEntry;
var
  baseAddress: integer;
  rowStream  : TGpFixedMemoryStream;
begin
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('GetItem(idx item = %d)', [idxItem]);
  {$ENDIF DebugSharedTable}
  if stInstance.Index <> idxItem then begin
    baseAddress := LocateBase(idxItem);
    if baseAddress <> 0 then begin
      rowStream := TGpFixedMemoryStream.Create(DataAddress[baseAddress]^,
        DataLength[baseAddress]);
      try
        stInstance.Reload(idxItem, rowStream);
      finally FreeAndNil(rowStream); end;
    end;
    {$IFDEF DebugSharedTable}
    DumpTable;
    (stLogger as IGpLogger).Log('GetItem => base address = %d', [baseAddress]);
    {$ENDIF DebugSharedTable}
  end;
  Result := stInstance;
end; { TGpBaseSharedTable.GetItem }

function TGpBaseSharedTable.Initialize(timeout: cardinal): boolean;
begin
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('Initialize(timeout = %d)', [timeout]);
  {$ENDIF DebugSharedTable}
  Result := true;
  try
    stMemory := TGpSharedMemory.Create(stName, stSize, stMaxSize);
    if BeginUpdate(timeout) then try
      if Signature = 0 then begin
        Signature := CGpSharedTableSignature;
        Clear;
      end
      else if Signature <> CGpSharedTableSignature then begin
        stLastError := 'Invalid signature found in shared memory block';
        Result := false;
      end;
      {$IFDEF DebugSharedTable}
      DumpTable;
      {$ENDIF DebugSharedTable}
    finally EndUpdate; end;
  except
    on E: EGpSharedMemory do begin
      stLastError := E.Message;
      Result := false;
    end;
  end;
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('Initialize => %s', [IFF(Result, 'T', 'F')]);
  {$ENDIF DebugSharedTable}
end; { TGpBaseSharedTable.Initialize }

function TGpBaseSharedTable.Locate(fieldIndex, fieldSize: integer;
  const value): integer;
var
  baseAddress: integer;
  fieldLength: integer;
  fieldOffset: integer;
  instLocate : TGpSharedTableEntry;
  rowStream  : TGpFixedMemoryStream;
begin                  
  {$IFDEF DebugSharedTable}
  Result := -1; // to keep Delphi happy 
  (stLogger as IGpLogger).Log('Locate(field index = %d, field size = %d)', [fieldIndex, fieldSize]);
  try
  {$ENDIF DebugSharedTable}                  
  instLocate := TGpSharedTableEntry.Create(nil);
  try
    Result := 0;
    baseAddress := stUsedList.Head;
    while baseAddress <> 0 do begin
      rowStream := TGpFixedMemoryStream.Create(DataAddress[baseAddress]^,
        DataLength[baseAddress]);
      try
        if instLocate.GetFieldOffset(rowStream, fieldIndex, fieldOffset, fieldLength) and
           (fieldLength = fieldSize) and
           CompareMem(@value, pointer(NativeUInt(rowStream.Memory)+NativeUInt(fieldOffset)), fieldLength)
        then
          Exit;
      finally FreeAndNil(rowStream); end;
      baseAddress := stUsedList.Next(baseAddress);
      Inc(Result);
    end; //while
  finally FreeAndNil(instLocate); end;
  Result := -1;
  {$IFDEF DebugSharedTable}
  finally (stLogger as IGpLogger).Log('Locate => %d', [Result]); end;
  {$ENDIF DebugSharedTable}
end; { TGpBaseSharedTable.Locate }

{:Locates row with a specified index and returns its base address.
  @since   2003-09-24
}
function TGpBaseSharedTable.LocateBase(rowIndex: integer): integer;
var
  lastLowestItem: integer;
begin
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('LocateBase(row index = %d)', [rowIndex]);
  {$ENDIF DebugSharedTable}
  if not stItemCache.RetrieveBase(rowIndex, Result, lastLowestItem) then begin
    while lastLowestItem < rowIndex do begin
      if lastLowestItem < 0 then
        Result := stUsedList.Head
      else
        Result := stUsedList.Next(Result);
      Inc(lastLowestItem);
      if Result = 0 then
        break // while
      else
        stItemCache.Insert(lastLowestItem, Result);
    end; //while
  end;
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('LocateBase => %d', [Result]);
  {$ENDIF DebugSharedTable}
end; { TGpBaseSharedTable.LocateBase }

function TGpBaseSharedTable.Memory: TGpBaseSharedMemory;
begin
  if not assigned(stMemory) then
    raise EGpSharedTable.Create('TGpBaseSharedTable: memory is not created')
  else if stMemory.IsWriting then
    Result := stMemory
  else if not assigned(stReadCopy) then
    raise EGpSharedTable.Create('TGpBaseSharedTable: read snapshot does not exist')
  else
    Result := stReadCopy;
end; { TGpBaseSharedTable.Memory }

function TGpBaseSharedTable.Read(timeout: cardinal): boolean;
var
  modified: boolean;
begin
  Result := Read(timeout, modified);
end; { TGpBaseSharedTable.Read }

function TGpBaseSharedTable.Read(timeout: cardinal; var modified: boolean): boolean;
begin
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('Read');
  {$ENDIF DebugSharedTable}
  Result := false;
  modified := false;
  if assigned(stMemory.AcquireMemory(false, timeout)) then try
    if stMemory.Modified then begin
      ReloadSnapshot;
      modified := true;
    end;
    RecreateListHeaders;
    Result := true;
    {$IFDEF DebugSharedTable}
    DumpTable;
    {$ENDIF DebugSharedTable}
  finally stMemory.ReleaseMemory; end;
end; { TGpBaseSharedTable.Read }

procedure TGpBaseSharedTable.RecreateListHeaders;
begin
  FreeAndNil(stFreeList);
  FreeAndNil(stUsedList);
  stFreeList := TGpSharedLinkedList.Create(Memory, CListsBeginAt);
  stUsedList := TGpSharedLinkedList.Create(Memory, CListsBeginAt + stFreeList.HeaderSize);
  stItemCache.Clear;
end; { TGpBaseSharedTable.RecreateListHeaders }

procedure TGpBaseSharedTable.ReloadSnapshot;
begin
  FreeAndNil(stReadCopy);
  stReadCopy := stMemory.MakeSnapshot;
  stItemCache.Clear;
  stInstance.Clear;
  RecreateListHeaders;
end; { TGpBaseSharedTable.ReloadSnapshot }

{:Shrinks the entry so that its data length is equal to data size and creates
  new orphaned entry in the space left.
  @returns Base address of the new orphaned entry.
  @since   2003-09-25
}
function TGpBaseSharedTable.SplitEntry(baseAddress, dataSize: integer): integer;
var
  leftover: integer;
begin
  {$IFDEF DebugSharedTable}
  Result := 0; // to keep compiler happy
  (stLogger as IGpLogger).Log('SplitEntry(base address = %d, data size = %d)', [baseAddress, dataSize]);
  try
  {$ENDIF DebugSharedTable}
  leftover := DataLength[baseAddress] - dataSize;
  if leftover < CEntryHeaderSize then
    raise EGpSharedTable.Create('Cannot split entry');
  DataLength[baseAddress] := dataSize;
  Result := baseAddress + CEntryHeaderSize + dataSize;
  DataLength[Result] := leftover - CEntryHeaderSize;
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('SplitEntry will dump table');
  DumpTable;
  finally (stLogger as IGpLogger).Log('SplitEntry => %d', [Result]); end;
  {$ENDIF DebugSharedTable}
end; { TGpBaseSharedTable.SplitEntry }

function TGpBaseSharedTable.ToString: string;
var
  baseAddress   : cardinal;
  entry         : TGpSharedTableEntry;
  idxItem       : integer;
  isAcquired    : boolean;
  rowStream     : TGpFixedMemoryStream;
  sContents     : string;
  sortedUsedList: TGpIntegerList;
  usedBase      : integer;
begin
  try
    isAcquired := Memory.Acquired;
  except
    on E: EGpSharedTable do begin
      Result := E.Message;
      Exit;
    end;
  end;

  if (not isAcquired) and (Memory.AcquireMemory(false, 10*1000) = nil) then
    Result := 'Timeout'
  else try
    Result :=
      Format('%.4d: %.8x', [0, Memory.Huge[0]]) + #13#10 + // signature
      Format('%.4d: %d', [8, Memory.Long[8]]) + #13#10 +   // count
      Format('%.4d: %.8x Free: #%d H:[N@32:%.4d P@36:%.4d] T:[N@40:%.4d P@44:%.4d]',
        [16, Memory.Huge[16], Memory.Long[16+8], Memory.Long[16+16], Memory.Long[16+20], Memory.Long[16+24], Memory.Long[16+28]]) + #13#10 +
      Format('%.4d: %.8x Used: #%d H:[N@64:%.4d P@68:%.4d] T:[N@72:%.4d P@76:%.4d]',
        [48, Memory.Huge[48], Memory.Long[48+8], Memory.Long[48+16], Memory.Long[48+20], Memory.Long[48+24], Memory.Long[48+28]]) + #13#10;
    sortedUsedList := TGpIntegerList.Create;
    try
      sortedUsedList.Sorted := true;
      usedBase := stUsedList.Head;
      while usedBase <> 0 do begin
        sortedUsedList.Add(usedBase);
        usedBase := stUsedList.Next(usedBase);
      end; //while
      baseAddress := 80;
      entry := stEntryClass.Create(nil);
      try
        idxItem := 0;
        repeat
          Result := Result + Format('%.4d: N:%.4d P:%.4d %d',
            [baseAddress, Memory.Long[baseAddress], Memory.Long[baseAddress+4], Memory.Long[baseAddress+8]]) + #13#10;
          if not sortedUsedList.Contains(baseAddress) then
            Result := Result + '      *** empty ***' + #13#10
          else begin
            rowStream := TGpFixedMemoryStream.Create(DataAddress[baseAddress]^,
              DataLength[baseAddress]);
            try
              try
                entry.Reload(idxItem, rowStream);
                sContents := entry.Description;
                if sContents = '' then
                  HexStr(Memory.Address[baseAddress+12]^, Min(32, Memory.Long[baseAddress+8]));
              except
                on E: Exception do
                  sContents := E.Message;
              end;
              Result := Result + Format('      %s', [sContents]) + #13#10;
            finally FreeAndNil(rowStream); end;
          end;
          Inc(idxItem);
          baseAddress := baseAddress + 12 + cardinal(DataLength[baseAddress]);
        until baseAddress >= Memory.Size;
      finally FreeAndNil(entry); end;
    finally FreeAndNil(sortedUsedList); end;
  finally
    if not isAcquired then
      Memory.ReleaseMemory;
  end;
end; { TGpBaseSharedTable.ToString }

{:Updates specified row. If new data is smaller than the old one, keeps the row
  length untouched to minimize the fragmentation. Otherwise, allocates new
  block and inserts it into the list in place of the old block.
  @since   2003-09-25
}
procedure TGpBaseSharedTable.UpdateRow(rowIndex: integer;
  rowStream: TStream);
var
  newBase: integer;
  rowBase: integer;
begin
  {$IFDEF DebugSharedTable}
  (stLogger as IGpLogger).Log('UpdateRow(row index = %d)', [rowIndex]);
  {$ENDIF DebugSharedTable}
  rowBase := LocateBase(rowIndex);
  rowStream.Position := 0;
  if rowStream.Size <= DataLength[rowBase] then
    rowStream.Read(DataAddress[rowBase]^, rowStream.Size)
  else begin
    newBase := AllocateRow(rowStream.Size);
    rowStream.Read(DataAddress[newBase]^, rowStream.Size);
    stUsedList.EnqueueAfter(rowBase, newBase);
    stUsedList.Dequeue(rowBase);
    stFreeList.EnqueueTail(rowBase);
    stItemCache.Update(rowIndex, newBase);
  end;
  {$IFDEF DebugSharedTable}
  DumpTable;
  {$ENDIF DebugSharedTable}
end; { TGpBaseSharedTable.UpdateRow }

{ TGpSharedTable }

function TGpSharedTable.LocateByte(fieldIndex: integer;
  value: byte): integer;
begin
  Result := Locate(fieldIndex, SizeOf(value), value);
end; { TGpSharedTable.LocateByte }

function TGpSharedTable.LocateCardinal(fieldIndex: integer;
  value: cardinal): integer;
begin
  Result := Locate(fieldIndex, SizeOf(value), value);
end; { TGpSharedTable.LocateCardinal }

function TGpSharedTable.LocateDateTime(fieldIndex: integer;
  value: TDateTime): integer;
begin
  Result := Locate(fieldIndex, SizeOf(value), value);
end; { TGpSharedTable.LocateDateTime }

function TGpSharedTable.LocateInt(fieldIndex, value: integer): integer;
begin
  Result := Locate(fieldIndex, SizeOf(value), value);
end; { TGpSharedTable.LocateInt }

function TGpSharedTable.LocateInt64(fieldIndex: integer;
  value: int64): integer;
begin
  Result := Locate(fieldIndex, SizeOf(value), value);
end; { TGpSharedTable.LocateInt64 }

function TGpSharedTable.LocateReal(fieldIndex: integer;
  value: real): integer;
begin
  Result := Locate(fieldIndex, SizeOf(value), value);
end; { TGpSharedTable.LocateReal }

function TGpSharedTable.LocateStr(fieldIndex: integer; const value: AnsiString): integer;
var
  dummy: byte;
begin
  if Length(value) = 0 then
    Result := Locate(fieldIndex, 0, dummy)
  else
    Result := Locate(fieldIndex, Length(value), value[1]);
end; { TGpSharedTable.LocateStr }

{ TGpSharedNamedCounters }

{:Locates the counter and returns its index in the table. If counter is not
  found, creates new counter, adds it to the table and returns its index.
  @since   2003-09-27
}
function TGpSharedNamedCounters.Add(const counterName: AnsiString): integer;
begin
  sncTable.BeginUpdate(INFINITE);
  try
    Result := Locate(counterName);
    if Result < 0 then begin
      with sncTable.Add as TGpSharedNamedCountersEntry do begin
        Name := counterName;
        Value := 0;
      end;
      Result := sncTable.Count-1;
    end;
  finally sncTable.EndUpdate; end;
end; { TGpSharedNamedCounters.Add }

function TGpSharedNamedCounters.Count: integer;
begin
  sncTable.Read(INFINITE);
  Result := sncTable.Count;
end; { TGpSharedNamedCounters.Count }

{:Create table storing shared named counters. Each table row contains two
  fields - counter name and counter value.
  @since   2003-09-26
}
constructor TGpSharedNamedCounters.Create(const sharedCountersName: string;
  sharedCountersSize, sharedCountersMaxSize: integer);
begin
  inherited Create;
  sncTable := TGpSharedTable.Create(sharedCountersName, TGpSharedNamedCountersEntry,
    sharedCountersSize, sharedCountersMaxSize);
end; { TGpSharedNamedCounters.Create }

function TGpSharedNamedCounters.Decrement(const counterName: AnsiString): integer;
var
  idxCounter: integer;
begin
  sncTable.BeginUpdate(INFINITE);
  try
    idxCounter := Add(counterName);
    Items[idxCounter].Value := Items[idxCounter].Value - 1;
    Result := Items[idxCounter].Value;
  finally sncTable.EndUpdate; end;
end; { TGpSharedNamedCounters.Decrement }

procedure TGpSharedNamedCounters.Delete(const counterName: AnsiString);
var
  idxCounter: integer;
begin
  sncTable.BeginUpdate(INFINITE);
  try
    idxCounter := Locate(counterName);
    if idxCounter >= 0 then
      sncTable.Delete(idxCounter);
  finally sncTable.EndUpdate; end;
end; { TGpSharedNamedCounters.Delete }

destructor TGpSharedNamedCounters.Destroy;
begin
  FreeAndNil(sncTable);
  inherited;
end; { TGpSharedNamedCounters.Destroy }

function TGpSharedNamedCounters.GetCounter(const counterName: AnsiString): integer;
var
  idxCounter: integer;
begin
  idxCounter := Add(counterName);
  sncTable.Read(INFINITE);
  Result := Items[idxCounter].Value;
end; { TGpSharedNamedCounters.GetCounter }

function TGpSharedNamedCounters.GetCounterName(idxCounter: integer): AnsiString;
begin
  sncTable.Read(INFINITE);
  Result := Items[idxCounter].Name;
end; { TGpSharedNamedCounters.GetCounterName }

function TGpSharedNamedCounters.GetItem(idxItem: integer): TGpSharedNamedCountersEntry;
begin
  Result := sncTable.Items[idxItem] as TGpSharedNamedCountersEntry;
end; { TGpSharedNamedCounters.GetItem }

function TGpSharedNamedCounters.GetLastError: string;
begin
  Result := sncTable.LastError;
end; { TGpSharedNamedCounters.GetLastError }

function TGpSharedNamedCounters.GetName: string;
begin
  Result := sncTable.Name;
end; { TGpSharedNamedCounters.GetName }

function TGpSharedNamedCounters.Increment(const counterName: AnsiString): integer;
var
  idxCounter: integer;
begin
  sncTable.BeginUpdate(INFINITE);
  try
    idxCounter := Add(counterName);
    Items[idxCounter].Value := Items[idxCounter].Value + 1;
    Result := Items[idxCounter].Value;
  finally sncTable.EndUpdate; end;
end; { TGpSharedNamedCounters.Increment }

function TGpSharedNamedCounters.IndexOf(const counterName: AnsiString): integer;
begin
  sncTable.BeginUpdate(INFINITE);
  try
    Result := Locate(counterName);
  finally sncTable.EndUpdate; end;
end; { TGpSharedNamedCounters.IndexOf }

{:Initialises the shared counters table.
  @since   2003-09-26
}
function TGpSharedNamedCounters.Initialize: boolean;
begin
  Result := sncTable.Initialize(INFINITE);
end; { TGpSharedNamedCounters.Initialize }

{:Locates the counter in the table. Returns -1 if the counter was not found.
  @since   2003-09-26
}
function TGpSharedNamedCounters.Locate(const counterName: AnsiString): integer;
begin
  Result := sncTable.LocateStr(CCountersFieldName, counterName);
end; { TGpSharedNamedCounters.Locate }

procedure TGpSharedNamedCounters.SetCounter(const counterName: AnsiString; const value:
  integer);
begin
  sncTable.BeginUpdate(INFINITE);
  try
    Items[Add(counterName)].Value := value;
  finally sncTable.EndUpdate; end;
end; { TGpSharedNamedCounters.SetCounter }

procedure TGpSharedNamedCounters.SetCounterName(idxCounter: integer; const value:
  AnsiString);
begin
  sncTable.BeginUpdate(INFINITE);
  try
    Items[idxCounter].Name := value;
  finally sncTable.EndUpdate; end;
end; { TGpSharedNamedCounters.SetCounterName }

{ TGpSharedNamedValuesEnumerator }

{$IFDEF EnableEnumerators}
constructor TGpSharedNamedValuesEnumerator.Create;
begin
  inherited Create;
  snveKeyNames := TStringList.Create;
  snveCurrentIdx := -1;
end; { TGpSharedNamedValuesEnumerator.Create }

function TGpSharedNamedValuesEnumerator.GetCurrent: string;
begin
  Result := snveKeyNames[snveCurrentIdx]
end; { TGpSharedNamedValuesEnumerator.GetCurrent }

function TGpSharedNamedValuesEnumerator.MoveNext: boolean;
begin
  if snveCurrentIdx < snveKeyNames.Count-1 then begin
    Inc(snveCurrentIdx);
    Result := true;
  end
  else
    Result := false;
end; { TGpSharedNamedValuesEnumerator.MoveNext }

destructor TGpSharedNamedValuesEnumerator.Destroy;
begin
  FreeAndNil(snveKeyNames);
  inherited;
end; { TGpSharedNamedValuesEnumerator.Destroy }
{$ENDIF EnableEnumerators}

{ TGpSharedNamedValues }

{:Locates the key and returns its index in the table. If the key is not found, creates new
  key, adds it to the table and returns its index.
  @since   2004-09-13
}
function TGpSharedNamedValues.Add(const key: AnsiString): integer;
begin
  snvTable.BeginUpdate(INFINITE);
  try
    Result := Locate(key);
    if Result < 0 then begin
      with snvTable.Add as TGpSharedNamedValuesEntry do begin
        Name := key;
        Value := '';
      end;
      Result := snvTable.Count-1;
    end;
  finally snvTable.EndUpdate; end;
end; { TGpSharedNamedValues.Add }

{:Create table storing shared named values. Each table row contains two fields - key and
  value.
  @since   2004-09-13
}
constructor TGpSharedNamedValues.Create(const sharedValuesName: string;
  sharedValuesSize, sharedValuesMaxSize: integer);
begin
  inherited Create;
  snvTable := TGpSharedTable.Create(sharedValuesName, TGpSharedNamedValuesEntry,
    sharedValuesSize, sharedValuesMaxSize);
end; { TGpSharedNamedValues.Create }

procedure TGpSharedNamedValues.DeleteKey(const key: AnsiString);
var
  idxKey: integer;
begin
  snvTable.BeginUpdate(INFINITE);
  try
    idxKey := Locate(key);
    if idxKey >= 0 then
      snvTable.Delete(idxKey); 
  finally snvTable.EndUpdate; end;
end; { TGpSharedNamedValues.DeleteKey }

destructor TGpSharedNamedValues.Destroy;
begin
  FreeAndNil(snvTable);
  inherited;
end; { TGpSharedNamedValues.Destroy }

{$IFDEF EnableEnumerators}
function TGpSharedNamedValues.GetEnumerator: TGpSharedNamedValuesEnumerator;
var
  iKey: integer;
begin
  Result := TGpSharedNamedValuesEnumerator.Create;
  snvTable.Read(INFINITE);
  for iKey := 0 to snvTable.Count-1 do
    Result.KeyNames.Add(string(Items[iKey].Name));
end; { TGpSharedNamedValues.GetEnumerator }
{$ENDIF EnableEnumerators}

function TGpSharedNamedValues.GetItem(idxItem: integer): TGpSharedNamedValuesEntry;
begin
  Result := snvTable.Items[idxItem] as TGpSharedNamedValuesEntry;
end; { TGpSharedNamedValues.GetItem }

function TGpSharedNamedValues.GetLastError: string;
begin
  Result := snvTable.LastError;
end; { TGpSharedNamedValues.GetLastError }

function TGpSharedNamedValues.GetName: string;
begin
  Result := snvTable.Name;
end; { TGpSharedNamedValues.GetName }

function TGpSharedNamedValues.GetValue(const key: AnsiString): AnsiString;
var
  idxKey: integer;
begin
  idxKey := Add(key);
  snvTable.Read(INFINITE);
  Result := Items[idxKey].Value;
end; { TGpSharedNamedValues.GetValue }

function TGpSharedNamedValues.Initialize: boolean;
begin
  Result := snvTable.Initialize(INFINITE);
end; { TGpSharedNamedValues.Initialize }

{:Locates the key in the table. Returns -1 if the key was not found.
  @since   2004-09-13
}
function TGpSharedNamedValues.Locate(const key: AnsiString): integer;
begin
  Result := snvTable.LocateStr(CValuesFieldKey, key);
end; { TGpSharedNamedValues.Locate }

procedure TGpSharedNamedValues.SetValue(const key, value: AnsiString);
begin
  snvTable.BeginUpdate(INFINITE);
  try
    Items[Add(key)].Value := value;
  finally snvTable.EndUpdate; end;
end; { TGpSharedNamedValues.SetValue }

end.
