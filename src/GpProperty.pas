(*:Simplified access to the published properties.
   @author Primoz Gabrijelcic
   @desc <pre>
   (c) 2017 Primoz Gabrijelcic
   Free for personal and commercial use. No rights reserved.

   Author            : Primoz Gabrijelcic
   Creation date     : 2003-12-03
   Last modification : 2017-05-25
   Version           : 1.11a
</pre>*)(*
   History:
     1.11a: 2017-05-25
       - Patched SetFloatProp to work in Win64 mode.
     1.11: 2010-11-26
       - Added support for tkUString properties.
     1.10: 2010-05-13
       - Overloaded CreateGpProperty creates property list for one of base classes.
     1.09: 2009-04-27
       - Caller must pass set size (in bytes) to the SetToString function.
     1.08: 2009-02-13
       - Delphi 2009 compatible.
     1.07: 2006-09-22
       - StringToSet can now optionally ignore unknown set elements.
     1.06: 2006-04-03
       - Added method IndexOf.
     1.05: 2004-07-29
       - Added method StringToSet.
     1.04a: 2004-02-08
       - Fixed VariantValue to work with booleans.
     1.04: 2004-01-26
       - Added function SetToString.
     1.03a: 2004-01-13
       - Works in D6 and D7.
       - Fixed problems with setting large negative integer properties.
     1.03: 2004-01-07
       - Added Int64Value indexed property.
       - Added WideStringValue indexed property.
       - Added IntegerValue indexed property.
       - Added BooleanValue indexed property.
       - Added EnumValue indexed property.
     1.02: 2004-01-05
       - Copied Get/SetFloatProp from Delphi 7 because Delphi 5 version sucks.
       - Copied Get/SetWideStrProp from implementation part of Delphi 5's
         TypInfo.pas.
     1.01: 2003-12-30
       - Added TypeInfo property.
       - Added TypeData property.
       - Added ExtendedValue property.
     1.0: 2003-12-11
       - Released.
*)

{$R-} // do not remove!

{$DEFINE NeedsVariants}
{$DEFINE HasWideStrProp}
{$DEFINE HasSetToString}
{D2} {$IFDEF VER90}{$UNDEF NeedsVariants}{$UNDEF HasWideStrProp}{$UNDEF HasSetToString}{$ENDIF VER90}
{D3} {$IFDEF VER100}{$UNDEF NeedsVariants}{$UNDEF HasWideStrProp}{$UNDEF HasSetToString}{$ENDIF VER100}
{D4} {$IFDEF VER120}{$UNDEF NeedsVariants}{$UNDEF HasWideStrProp}{$UNDEF HasSetToString}{$ENDIF VER120}
{D5} {$IFDEF VER130}{$UNDEF NeedsVariants}{$UNDEF HasWideStrProp}{$UNDEF HasSetToString}{$ENDIF VER130}
{D6} {$IFDEF Ver140}{$UNDEF HasWideStrProp}{$UNDEF HasSetToString}{$ENDIF VER140}

unit GpProperty;

interface

uses
  Classes,
  {$IFDEF NeedsVariants}Variants,{$ENDIF NeedsVariants}
  TypInfo;

type
  {:Interface specifying simplified access to published properties.
    @since   2003-12-03
  }
  IGpProperty = interface['{55BBB4F5-0DD5-4532-96D0-19E677B4E249}']
  //accessors
    function  GetPropAnsiStringValue(idxProperty: integer): AnsiString;
    function  GetPropBooleanValue(idxProperty: integer): boolean;
    function  GetPropEnumValue(idxProperty: integer): string;
    function  GetPropExtendedValue(idxProperty: integer): extended;
    function  GetPropInfo(idxProperty: integer): PPropInfo;
    function  GetPropInt64Value(idxProperty: integer): int64;
    function  GetPropIntegerValue(idxProperty: integer): integer;
    function  GetPropName(idxProperty: integer): string;
    function  GetPropStringValue(idxProperty: integer): string;
    function  GetPropVariantValue(idxProperty: integer): Variant;
    function  GetPropWideStringValue(idxProperty: integer): WideString;
    function  GetTypeData(idxProperty: integer): PTypeData;
    function  GetTypeInfo(idxProperty: integer): PTypeInfo;
    procedure SetPropAnsiStringValue(idxProperty: integer; const value: AnsiString);
    procedure SetPropBooleanValue(idxProperty: integer; const value: boolean);
    procedure SetPropEnumValue(idxProperty: integer; const value: string);
    procedure SetPropExtendedValue(idxProperty: integer; const value: extended);
    procedure SetPropInt64Value(idxProperty: integer; const value: int64);
    procedure SetPropIntegerValue(idxProperty: integer; const value: integer);
    procedure SetPropStringValue(idxProperty: integer; const value: string);
    procedure SetPropVariantValue(idxProperty: integer; const value: Variant);
    procedure SetPropWideStringValue(idxProperty: integer; const value: WideString);
  //public
    procedure Access(instance: TPersistent); overload;
    procedure Access(instance: TPersistent; classInfo: pointer); overload;
    function  Count: integer;
    function  IndexOf(const propName: string): integer;
    property AnsiStringValue[idxProperty: integer]: AnsiString
      read GetPropAnsiStringValue write SetPropAnsiStringValue;
    property BooleanValue[idxProperty: integer]: boolean
      read GetPropBooleanValue write SetPropBooleanValue;
    property EnumValue[idxProperty: integer]: string
      read GetPropEnumValue write SetPropEnumValue;
    property ExtendedValue[idxProperty: integer]: extended
      read GetPropExtendedValue write SetPropExtendedValue;
    property Int64Value[idxProperty: integer]: int64
      read GetPropInt64Value write SetPropInt64Value;
    property IntegerValue[idxProperty: integer]: integer
      read GetPropIntegerValue write SetPropIntegerValue;
    property Name[idxProperty: integer]: string read GetPropName;
    property PropInfo[idxProperty: integer]: PPropInfo read GetPropInfo; default;
    property StringValue[idxProperty: integer]: string
      read GetPropStringValue write SetPropStringValue;
    property TypeData[idxProperty: integer]: PTypeData read GetTypeData;
    property TypeInfo[idxProperty: integer]: PTypeInfo read GetTypeInfo;
    property VariantValue[idxProperty: integer]: Variant
      read GetPropVariantValue write SetPropVariantValue;
    property WideStringValue[idxProperty: integer]: WideString
      read GetPropWideStringValue write SetPropWideStringValue;
  end; { IGpProperty }

function CreateGpProperty(instance: TPersistent): IGpProperty; overload;
function CreateGpProperty(instance: TPersistent; classInfo: pointer): IGpProperty; overload;

{:GetFloatProp from D7.
}
function GetFloatProp(Instance: TObject; PropInfo: PPropInfo): Extended;

{:SetFloatProp from D7.
  @since   2004-01-05
}        
procedure SetFloatProp(Instance: TObject; PropInfo: PPropInfo;
  const Value: Extended);

{$IFNDEF HasWideStrProp}
{:Copied from implementation part of D5's TypInfo.
  @since   2004-01-05
}
procedure GetWideStrProp(Instance: TObject; PropInfo: PPropInfo;
  var Value: WideString); assembler; overload;
{$ENDIF HasWideStrProp}

function GetWideStrProp(Instance: TObject;
  const PropName: string): WideString; overload;

{$IFNDEF HasWideStrProp}
{:Copied from implementation part of D5's TypInfo.
  @since   2004-01-05
}
procedure SetWideStrProp(Instance: TObject; PropInfo: PPropInfo;
  const Value: WideString); assembler; overload;
{$ENDIF HasWideStrProp}

procedure SetWideStrProp(Instance: TObject; const PropName: string;
  const value: WideString); overload;

{:Converts a set to a string representation. Valid only for "register sets" - sets with
  fewer than Sizeof(Integer) * 8 elements.
  @author  Constantine Yannakopoulos
  @since   2004-01-26
}
function SetToString(const aSet; TypeInfo: PTypeInfo; setSize: integer;
  brackets: boolean = true): string;

{:Converts a string to the set. Based on the code taken from Delphi 7's TypInfo.pas.
  Valid only for "register sets" - sets with fewer than Sizeof(Integer) * 8 elements.
  value to/from your set type.
}
function StringToSet(TypeInfo: PTypeInfo; const value: string; ignoreUnknown: boolean = false): integer;

implementation

uses
  Windows,
  SysUtils,
  DSiWin32;

type
  {:Class implementing simplified access to published properties.
    @since   2003-12-03
  }
  TGpProperty = class(TInterfacedObject, IGpProperty)
  private
    gpInstance     : TPersistent;
    gpNumProperties: integer;
    gpPropList     : PPropList;
  protected
    procedure Cleanup;
    function  GetPropAnsiStringValue(idxProperty: integer): AnsiString;
    function  GetPropBooleanValue(idxProperty: integer): boolean;
    function  GetPropEnumValue(idxProperty: integer): string;
    function  GetPropExtendedValue(idxProperty: integer): extended;
    function  GetPropInfo(idxProperty: integer): PPropInfo;
    function  GetPropInt64Value(idxProperty: integer): int64;
    function  GetPropIntegerValue(idxProperty: integer): integer;
    function  GetPropName(idxProperty: integer): string;
    function  GetPropStringValue(idxProperty: integer): string;
    function  GetPropValue(Instance: TObject; const PropName: string;
      PreferStrings: Boolean): Variant;
    function  GetPropVariantValue(idxProperty: integer): Variant;
    function  GetPropWideStringValue(idxProperty: integer): WideString;
    function  GetTypeData(idxProperty: integer): PTypeData;
    function  GetTypeInfo(idxProperty: integer): PTypeInfo;
    procedure PropertyNotFound(const Name: string);
    procedure SetPropAnsiStringValue(idxProperty: integer; const value: AnsiString);
    procedure SetPropBooleanValue(idxProperty: integer; const value: boolean);
    procedure SetPropEnumValue(idxProperty: integer; const value: string);
    procedure SetPropExtendedValue(idxProperty: integer; const value: extended);
    procedure SetPropInt64Value(idxProperty: integer; const value: int64);
    procedure SetPropIntegerValue(idxProperty: integer; const value: integer);
    procedure SetPropStringValue(idxProperty: integer; const value: string);
    procedure SetPropValue(Instance: TObject; const PropName: string;
      Value: Variant);
    procedure SetPropVariantValue(idxProperty: integer; const value: Variant);
    procedure SetPropWideStringValue(idxProperty: integer; const value: WideString);
  public
    destructor Destroy; override;
    procedure Access(instance: TPersistent); overload;
    procedure Access(instance: TPersistent; classInfo: pointer); overload;
    function  Count: integer;
    function  IndexOf(const propName: string): integer;
    property AnsiStringValue[idxProperty: integer]: AnsiString
      read GetPropAnsiStringValue write SetPropAnsiStringValue;
    property BooleanValue[idxProperty: integer]: boolean
      read GetPropBooleanValue write SetPropBooleanValue;
    property EnumValue[idxProperty: integer]: string
      read GetPropEnumValue write SetPropEnumValue;
    property ExtendedValue[idxProperty: integer]: extended
      read GetPropExtendedValue write SetPropExtendedValue;
    property Int64Value[idxProperty: integer]: int64
      read GetPropInt64Value write SetPropInt64Value;
    property IntegerValue[idxProperty: integer]: integer
      read GetPropIntegerValue write SetPropIntegerValue;
    property Name[idxProperty: integer]: string read GetPropName;
    property PropInfo[idxProperty: integer]: PPropInfo read GetPropInfo; default;
    property StringValue[idxProperty: integer]: string
      read GetPropStringValue write SetPropStringValue;
    property TypeData[idxProperty: integer]: PTypeData read GetTypeData;
    property TypeInfo[idxProperty: integer]: PTypeInfo read GetTypeInfo;
    property VariantValue[idxProperty: integer]: Variant
      read GetPropVariantValue write SetPropVariantValue;
    property WideStringValue[idxProperty: integer]: WideString
      read GetPropWideStringValue write SetPropWideStringValue;
  end; { TGpProperty }

{:Creates IGpProperty-implementing object and initializes it with the instance.
  @since   2003-12-03
}
function CreateGpProperty(instance: TPersistent): IGpProperty;
begin
  Result := TGpProperty.Create;
  Result.Access(instance);
end; { CreateGpProperty }

function CreateGpProperty(instance: TPersistent; classInfo: pointer): IGpProperty;
begin
  Result := TGpProperty.Create;
  Result.Access(instance, classInfo);
end; { CreateGpProperty }

type
  PComp = ^comp;

{:@since   2004-01-05
}        
function GetFloatProp(Instance: TObject; PropInfo: PPropInfo): Extended;
type
  TFloatGetProc = function :Extended of object;
  TFloatIndexedGetProc = function (Index: Integer): Extended of object;
var
  P: Pointer;
  M: TMethod;
  Getter: Longint;
begin
  Getter := Longint(PropInfo^.GetProc);
  if (Getter and $FF000000) = $FF000000 then
  begin  // field - Getter is the field's offset in the instance data
    P := Pointer(Integer(Instance) + (Getter and $00FFFFFF));
    case GetTypeData(PropInfo^.PropType^).FloatType of
      ftSingle:    Result := PSingle(P)^;
      ftDouble:    Result := PDouble(P)^;
      ftExtended:  Result := PExtended(P)^;
      ftComp:      Result := PComp(P)^;
      ftCurr:      Result := PCurrency(P)^;
    else
      Result := 0;
    end;
  end
  else
  begin
    if (Getter and $FF000000) = $FE000000 then
      // virtual method  - Getter is a signed 2 byte integer VMT offset
      M.Code := Pointer(PInteger(PInteger(Instance)^ + SmallInt(Getter))^)
    else
      // static method - Getter is the actual address
      M.Code := Pointer(Getter);

    M.Data := Instance;
    if PropInfo^.Index = Integer($80000000) then  // no index
      Result := TFloatGetProc(M)()
    else
      Result := TFloatIndexedGetProc(M)(PropInfo^.Index);

    if GetTypeData(PropInfo^.PropType^).FloatType = ftCurr then
      Result := Result / 10000;
  end;
end; { GetFloatProp }

{:@since   2004-01-05
}        
procedure SetFloatProp(Instance: TObject; PropInfo: PPropInfo;
  const Value: Extended);
type
  TSingleSetProc = procedure (const Value: Single) of object;
  TDoubleSetProc = procedure (const Value: Double) of object;
  TExtendedSetProc = procedure (const Value: Extended) of object;
  TCompSetProc = procedure (const Value: Comp) of object;
  TCurrencySetProc = procedure (const Value: Currency) of object;
  TSingleIndexedSetProc = procedure (Index: Integer;
                                        const Value: Single) of object;
  TDoubleIndexedSetProc = procedure (Index: Integer;
                                        const Value: Double) of object;
  TExtendedIndexedSetProc = procedure (Index: Integer;
                                        const Value: Extended) of object;
  TCompIndexedSetProc = procedure (Index: Integer;
                                        const Value: Comp) of object;
  TCurrencyIndexedSetProc = procedure (Index: Integer;
                                        const Value: Currency) of object;
var
  P: Pointer;
  M: TMethod;
  Setter: Longint;
  FloatType: TFloatType;
begin
  Setter := Longint(PropInfo^.SetProc);
  FloatType := GetTypeData(PropInfo^.PropType^).FloatType;

  if ((Setter and $FF000000) = $FF000000) {$IFDEF CPUx64} or ((Setter and $FF000000) = $00000000) {$ENDIF} then
  begin  // field - Setter is the field's offset in the instance data
    P := Pointer(Integer(Instance) + (Setter and $00FFFFFF));
    case FloatType of
      ftSingle:    PSingle(P)^ := Value;
      ftDouble:    PDouble(P)^ := Value;
      ftExtended:  PExtended(P)^ := Value;
      ftComp:      PComp(P)^ := Value;
      ftCurr:      PCurrency(P)^ := Value;
    end;
  end
  else
  begin
    if (Setter and $FF000000) = $FE000000 then
      // virtual method  - Setter is a signed 2 byte integer VMT offset
      M.Code := Pointer(PInteger(PInteger(Instance)^ + SmallInt(Setter))^)
    else
      // static method - Setter is the actual address
      M.Code := Pointer(Setter);

    M.Data := Instance;
    if PropInfo^.Index = Integer($80000000) then  // no index
    begin
      case FloatType of
        ftSingle  :  TSingleSetProc(M)(Value);
        ftDouble  :  TDoubleSetProc(M)(Value);
        ftExtended:  TExtendedSetProc(M)(Value);
        ftComp    :  TCompSetProc(M)(Value);
        ftCurr    :  TCurrencySetProc(M)(Value);
      end;
    end
    else  // indexed
    begin
      case FloatType of
        ftSingle  :  TSingleIndexedSetProc(M)(PropInfo^.Index, Value);
        ftDouble  :  TDoubleIndexedSetProc(M)(PropInfo^.Index, Value);
        ftExtended:  TExtendedIndexedSetProc(M)(PropInfo^.Index, Value);
        ftComp    :  TCompIndexedSetProc(M)(PropInfo^.Index, Value);
        ftCurr    :  TCurrencyIndexedSetProc(M)(PropInfo^.Index, Value);
      end;
    end
  end;
end; { SetFloatProp }

procedure AssignWideStr(var Dest: WideString; const Source: WideString);
begin
  Dest := Source;
end; { AssignWideStr }

{$IFNDEF HasWideStrProp}
procedure GetWideStrProp(Instance: TObject; PropInfo: PPropInfo;
  var Value: WideString); assembler;
asm
        { ->    EAX Pointer to instance         }
        {       EDX Pointer to property info    }
        {       ECX Pointer to result string    }

        PUSH    ESI
        PUSH    EDI
        MOV     EDI,EDX

        MOV     EDX,[EDI].TPropInfo.Index       { pass index in EDX }
        CMP     EDX,$80000000
        JNE     @@hasIndex
        MOV     EDX,ECX                         { pass value in EDX }
@@hasIndex:
        MOV     ESI,[EDI].TPropInfo.GetProc
        CMP     [EDI].TPropInfo.GetProc.Byte[3],$FE
        JA      @@isField
        JB      @@isStaticMethod

@@isVirtualMethod:
        MOVSX   ESI,SI                          { sign extend slot offset }
        ADD     ESI,[EAX]                       { vmt + slot offset }
        CALL    DWORD PTR [ESI]
        JMP     @@exit

@@isStaticMethod:
        CALL    ESI
        JMP     @@exit

@@isField:
  AND  ESI,$00FFFFFF
  MOV  EDX,[EAX+ESI]
  MOV  EAX,ECX
  CALL  AssignWideStr

@@exit:
        POP     EDI
        POP     ESI
end; { GetWideStrProp }
{$ENDIF HasWideStrProp}

function GetWideStrProp(Instance: TObject;
  const PropName: string): WideString; 
var
  propInfo: PPropInfo;
begin
  propInfo := GetPropInfo(Instance, PropName);
{$IFNDEF HasWideStrProp}
  GetWideStrProp(Instance, propInfo, Result);
{$ELSE}
  {$IFDEF Unicode}
  if propInfo^.PropType^^.Kind = tkUString then
    Result := GetUnicodeStrProp(Instance, propInfo)
  else
  {$ENDIF Unicode}
    Result := GetWideStrProp(Instance, propInfo);
{$ENDIF HasWideStrProp}
end; { GetWideStrProp }

{$IFNDEF HasWideStrProp}
procedure SetWideStrProp(Instance: TObject; PropInfo: PPropInfo;
  const Value: WideString); assembler;
asm
        { ->    EAX Pointer to instance         }
        {       EDX Pointer to property info    }
        {       ECX Pointer to string value     }

        PUSH    ESI
        PUSH    EDI
        MOV     ESI,EDX

        MOV     EDX,[ESI].TPropInfo.Index       { pass index in EDX }
        CMP     EDX,$80000000
        JNE     @@hasIndex
        MOV     EDX,ECX                         { pass value in EDX }
@@hasIndex:
        MOV     EDI,[ESI].TPropInfo.SetProc
        CMP     [ESI].TPropInfo.SetProc.Byte[3],$FE
        JA      @@isField
        JB      @@isStaticMethod

@@isVirtualMethod:
        MOVSX   EDI,DI
        ADD     EDI,[EAX]
        CALL    DWORD PTR [EDI]
        JMP     @@exit

@@isStaticMethod:
        CALL    EDI
        JMP     @@exit

@@isField:
        AND  EDI,$00FFFFFF
        ADD  EAX,EDI
        MOV  EDX,ECX
        CALL  AssignWideStr

@@exit:
        POP     EDI
        POP     ESI
end; { SetWideStrProp }
{$ENDIF HasWideStrProp}

procedure SetWideStrProp(Instance: TObject; const PropName: string;
  const value: WideString);
var
  propInfo: PPropInfo;
begin
  propInfo := GetPropInfo(Instance, PropName);
  {$IFNDEF Unicode}
  SetWideStrProp(Instance, propInfo, Value);
  {$ELSE}
  if propInfo^.PropType^^.Kind = tkUString then
    SetUnicodeStrProp(Instance, propInfo, value)
  else
    TypInfo.SetWideStrProp(Instance, propInfo, value);
  {$ENDIF Unicode}
end; { SetWideStrProp }

function SetToString(const aSet; TypeInfo: PTypeInfo; setSize: integer;
  brackets: boolean): string;
var
  eltTypeInfo: PTypeInfo;
  i          : integer;
  S          : TIntegerSet;
begin
  Result := '';
  integer(S) := integer(aSet) AND ($FFFFFFFF shr ((4-setSize)*8));
  eltTypeInfo := GetTypeData(TypeInfo).CompType^;
  for I := 0 to SizeOf(Integer) * 8 - 1 do
    if i in S then begin
      if Result <> '' then
        Result := Result + ',';
      Result := Result + GetEnumName(eltTypeInfo, i);
    end;
   if brackets then
    Result := '[' + Result + ']';
end; { SetToString }

function StringToSet(TypeInfo: PTypeInfo; const value: string; ignoreUnknown: boolean): integer;
var
  enumInfo : PTypeInfo;
  enumName : string;
  enumValue: longint;
  P        : PChar;

  // grab the next enum name
  function NextWord(var P: PChar): string;
  var
    i: integer;
  begin
    i := 0;
    while not (ansichar(P[i]) in [',', ' ', #0,']']) do
      Inc(i);
    SetString(Result, P, i);
    while ansichar(P[i]) in [',', ' ',']'] do
      Inc(i);
    Inc(P, i);
  end; { NextWord }

begin
  Result := 0;
  if value = '' then
    Exit;
  P := PChar(value);
  while ansichar(P^) in ['[',' '] do
    Inc(P);
  enumInfo := GetTypeData(TypeInfo).CompType^;
  enumName := NextWord(P);
  while enumName <> '' do begin
    enumValue := GetEnumValue(enumInfo, enumName);
    if enumValue >= 0 then
      Include(TIntegerSet(Result), enumValue)
    else if not ignoreUnknown then
      raise EPropertyConvertError.CreateFmt('Invalid property element: %s', [EnumName]);
    enumName := NextWord(P);
  end;
end; { StringToSet }

{ TGpProperty }

destructor TGpProperty.Destroy;
begin
  Cleanup;
  inherited;
end; { TGpProperty.Destroy }

procedure TGpProperty.Access(instance: TPersistent);
begin
  Access(instance, instance.ClassInfo);
end; { TGpProperty.Access }

procedure TGpProperty.Access(instance: TPersistent; classInfo: pointer);
begin
  Cleanup;
  gpInstance := instance;
  gpNumProperties := TypInfo.GetTypeData(classInfo)^.PropCount;
  if gpNumProperties > 0 then begin
    GetMem(gpPropList, Count*SizeOf(pointer));
    GetPropInfos(classInfo, gpPropList);
  end;
end; { TGpProperty.Access }

procedure TGpProperty.Cleanup;
begin
  DSiFreeMemAndNil(pointer(gpPropList));
end; { TGpProperty.Cleanup }

function TGpProperty.Count: integer;
begin
  Result := gpNumProperties;
end; { TGpProperty.Count }

function TGpProperty.GetPropAnsiStringValue(idxProperty: integer): AnsiString;
begin
  Result := AnsiString(GetPropValue(gpInstance, Name[idxProperty], true));
end; { TGpProperty.GetPropAnsiStringValue }

function TGpProperty.GetPropBooleanValue(idxProperty: integer): boolean;
begin
  Result := boolean(IntegerValue[idxProperty]);
end; { TGpProperty.GetPropBooleanValue }

function TGpProperty.GetPropEnumValue(idxProperty: integer): string;
begin
  Result := GetEnumProp(gpInstance, PropInfo[idxProperty]);
end; { TGpProperty.GetPropEnumValue }

function TGpProperty.GetPropExtendedValue(idxProperty: integer): extended;
begin
  Result := TypInfo.GetFloatProp(gpInstance, PropInfo[idxProperty]);
end; { TGpProperty.GetPropExtendedValue }

function TGpProperty.GetPropInfo(idxProperty: integer): PPropInfo;
begin
  Result := nil;
  if assigned(gpPropList) then
    Result := gpPropList^[idxProperty];
end; { TGpProperty.GetPropInfo }

function TGpProperty.GetPropInt64Value(idxProperty: integer): int64;
begin
  Result := GetInt64Prop(gpInstance, PropInfo[idxProperty]);
end; { TGpProperty.GetPropInt64Value }

function TGpProperty.GetPropIntegerValue(idxProperty: integer): integer;
begin
  Result := GetOrdProp(gpInstance, PropInfo[idxProperty]);
end; { TGpProperty.GetPropIntegerValue }

function TGpProperty.GetPropName(idxProperty: integer): string;
begin
  Result := string(PropInfo[idxProperty]^.Name);
end; { TGpProperty.GetPropName }

function TGpProperty.GetPropStringValue(idxProperty: integer): string;
begin
  Result := GetPropValue(gpInstance, Name[idxProperty], true);
end; { TGpProperty.GetPropStringValue }

{:Copied from the D7 TypInfo.pas because the D5 version is broken.
  @since   2003-12-29
}
function TGpProperty.GetPropValue(Instance: TObject;
  const PropName: string; PreferStrings: Boolean): Variant;
var
  PropInfo: PPropInfo;
begin
  // assume failure
  Result := Null;

  // get the prop info
  PropInfo := TypInfo.GetPropInfo(Instance, PropName);
  if PropInfo = nil then
    PropertyNotFound(PropName)
  else
  begin
    // return the right type
    case PropInfo^.PropType^^.Kind of
      tkInteger, tkChar, tkWChar, tkClass:
        Result := GetOrdProp(Instance, PropInfo);
      tkEnumeration:
        if PreferStrings then
          Result := GetEnumProp(Instance, PropInfo)
        else if TypInfo.GetTypeData(PropInfo^.PropType^)^.BaseType^ = System.TypeInfo(Boolean) then
          Result := Boolean(GetOrdProp(Instance, PropInfo))
        else
          Result := GetOrdProp(Instance, PropInfo);
      tkSet:
        if PreferStrings then
          Result := GetSetProp(Instance, PropInfo)
        else
          Result := GetOrdProp(Instance, PropInfo);
      tkFloat:
          Result := GetFloatProp(Instance, PropInfo);
      tkMethod:
        Result := PropInfo^.PropType^.Name;
      tkString, tkLString :
        Result := {$IFDEF Unicode}GetAnsiStrProp{$ELSE}GetStrProp{$ENDIF}(Instance, PropInfo);
      tkWString {$IFDEF Unicode}, tkUString{$ENDIF}:
        Result := GetStrProp(Instance, PropInfo);
      tkVariant:
        Result := GetVariantProp(Instance, PropInfo);
      tkDynArray:
  DynArrayToVariant(Result, Pointer(GetOrdProp(Instance, PropInfo)), PropInfo^.PropType^);
    else
      raise EPropertyConvertError.CreateFmt(
              'TGpProperty.GetPropValue: Invalid property type: %s',
              [PropInfo.PropType^^.Name]);
    end;
  end;
end; { TGpProperty.GetPropValue }

function TGpProperty.GetPropVariantValue(idxProperty: integer): Variant;
begin
  Result := GetPropValue(gpInstance, Name[idxProperty],
    (TypeInfo[idxProperty]^.Kind <> tkEnumeration) or
    (TypInfo.GetTypeData(TypeInfo[idxProperty]) ^.BaseType^ <> System.TypeInfo(boolean)));
end; { TGpProperty.GetPropVariantValue }

function TGpProperty.GetPropWideStringValue(idxProperty: integer): WideString;
begin
{$IFNDEF HasWideStrProp}
  GetWideStrProp(gpInstance, PropInfo[idxProperty], Result);
{$ELSE}
  {$IFDEF Unicode}
  if TypeInfo[idxProperty]^.Kind = tkUString then
    Result := GetUnicodeStrProp(gpInstance, PropInfo[idxProperty])
  else
  {$ENDIF Unicode}
    Result := GetWideStrProp(gpInstance, PropInfo[idxProperty]);
{$ENDIF HasWideStrProp}
end; { TGpProperty.GetPropWideStringValue }

function TGpProperty.GetTypeData(idxProperty: integer): PTypeData;
begin
  Result := TypInfo.GetTypeData(TypeInfo[idxProperty]);
end; { TGpProperty.GetTypeData }

function TGpProperty.GetTypeInfo(idxProperty: integer): PTypeInfo;
begin
  Result := PropInfo[idxProperty]^.PropType^
end; { TGpProperty.GetTypeInfo }

function TGpProperty.IndexOf(const propName: string): integer;
begin
  for Result := 0 to Count - 1 do
    if SameText(Name[Result], propName) then
      Exit;
  Result := -1;
end; { TGpProperty.IndexOf }

procedure TGpProperty.PropertyNotFound(const Name: string);
begin
  raise EPropertyError.CreateFmt('TGpProperty.PropertyNotFound: Unknown property: %s', [Name]);
end; { TGpProperty.PropertyNotFound }

procedure TGpProperty.SetPropAnsiStringValue(idxProperty: integer; const value:
  AnsiString);
begin
  SetPropValue(gpInstance, Name[idxProperty], value);
end; { TGpProperty.SetPropAnsiStringValue }

procedure TGpProperty.SetPropBooleanValue(idxProperty: integer;
  const Value: boolean);
begin
  IntegerValue[idxProperty] := Ord(Value);
end; { TGpProperty.SetPropBooleanValue }

procedure TGpProperty.SetPropEnumValue(idxProperty: integer;
  const value: string);
begin
  SetEnumProp(gpInstance, PropInfo[idxProperty], value);
end; { TGpProperty.SetPropEnumValue }

procedure TGpProperty.SetPropExtendedValue(idxProperty: integer;
  const value: extended);
begin
  SetFloatProp(gpInstance, PropInfo[idxProperty], value);
end; { TGpProperty.SetPropExtendedValue }

procedure TGpProperty.SetPropInt64Value(idxProperty: integer;
  const value: int64);
begin
  TypInfo.SetInt64Prop(gpInstance, PropInfo[idxProperty], value);
end; { TGpProperty.SetPropInt64Value }

procedure TGpProperty.SetPropIntegerValue(idxProperty: integer;
  const value: integer);
begin
  SetOrdProp(gpInstance, PropInfo[idxProperty], value);
end; { TGpProperty.SetPropIntegerValue }

procedure TGpProperty.SetPropStringValue(idxProperty: integer;
  const value: string);
begin
  SetPropValue(gpInstance, Name[idxProperty], value);
end; { TGpProperty.SetPropStringValue }

{:Copied from the D7 TypInfo.pas because the D5 version is broken. Modified to work with
  big negative integers.
  @since   2003-12-29
}
procedure TGpProperty.SetPropValue(Instance: TObject;
  const PropName: string; Value: Variant);

  function RangedValue(const AMin, AMax: Int64): Int64;
  begin
    Result := Trunc(Value);
    if (Result < AMin) or (Result > AMax) then
      raise ERangeError.Create('TGpProperty.SetPropValue: Property range error');
  end;

  function RangedValueU(const AMin, AMax: Int64; value: cardinal): Int64;
  begin
    Result := Value;
    if (Result < AMin) or (Result > AMax) then
      raise ERangeError.Create('TGpProperty.SetPropValue: Property range error');
  end;

var
  DynArray: Pointer;
  PropInfo: PPropInfo;
  strVal  : string;
  TypeData: PTypeData;
  
begin { TGpProperty.SetPropValue }
  // get the prop info
  PropInfo := TypInfo.GetPropInfo(Instance, PropName);
  if PropInfo = nil then
    PropertyNotFound(PropName)
  else begin
    TypeData := TypInfo.GetTypeData(PropInfo^.PropType^);

    // set the right type
    case PropInfo.PropType^^.Kind of
      tkInteger, tkChar, tkWChar:
        if TypeData^.MinValue < TypeData^.MaxValue then
          SetOrdProp(Instance, PropInfo, RangedValue(TypeData^.MinValue,
            TypeData^.MaxValue))
        else begin
          // Unsigned type
          SetOrdProp(Instance, PropInfo,
            RangedValueU(LongWord(TypeData^.MinValue),
            LongWord(TypeData^.MaxValue), cardinal(Value)));
        end;
      tkEnumeration:
        if VarType(Value) = varString then
          SetEnumProp(Instance, PropInfo, VarToStr(Value))
        else if VarType(Value) = varBoolean then
          // Need to map variant boolean values -1,0 to 1,0
          SetOrdProp(Instance, PropInfo, Abs(Trunc(Value)))
        else
          SetOrdProp(Instance, PropInfo, RangedValue(TypeData^.MinValue,
            TypeData^.MaxValue));
      tkSet:
        if VarType(Value) = varInteger then
          SetOrdProp(Instance, PropInfo, Value)
        else begin
          strVal := VarToStr(Value);
          if strVal = '' then
            strVal := '[]';
          SetSetProp(Instance, PropInfo, strVal);
        end;
      tkFloat:
        SetFloatProp(Instance, PropInfo, Value);
      tkString, tkLString:
        {$IFDEF Unicode}SetAnsiStrProp{$ELSE}SetStrProp{$ENDIF}(Instance, PropInfo, AnsiString(VarToStr(Value)));
      tkWString {$IFDEF Unicode}, tkUstring{$ENDIF}:
        SetStrProp(Instance, PropInfo, VarToStr(Value));
      tkVariant:
        SetVariantProp(Instance, PropInfo, Value);
      tkDynArray:
        begin
          DynArrayFromVariant(DynArray, Value, PropInfo^.PropType^);
          SetOrdProp(Instance, PropInfo, Integer(DynArray));
        end;
      else
        raise EPropertyConvertError.CreateFmt(
          'TGpProperty.SetPropValue: Invalid property type: %s',
          [PropInfo.PropType^^.Name]);
    end;
  end;
end; { TGpProperty.SetPropValue }

procedure TGpProperty.SetPropVariantValue(idxProperty: integer;
  const value: Variant);
begin
  if (TypeInfo[idxProperty]^.Kind = tkEnumeration) and
     (TypInfo.GetTypeData(TypeInfo[idxProperty]) ^.BaseType^ = System.TypeInfo(boolean))
  then
    SetOrdProp(gpInstance, Name[idxProperty], Ord(value <> 0))
  else
    SetPropValue(gpInstance, Name[idxProperty], value);
end; { TGpProperty.SetPropVariantValue }

procedure TGpProperty.SetPropWideStringValue(idxProperty: integer;
  const value: WideString);
begin
  {$IFDEF Unicode}
  if TypeInfo[idxProperty]^.Kind = tkUString then
    SetUnicodeStrProp(gpInstance, PropInfo[idxProperty], value)
  else
  {$ENDIF Unicode}
    SetWideStrProp(gpInstance, PropInfo[idxProperty], value);
end; { TGpProperty.SetPropWideStringValue }

end.


