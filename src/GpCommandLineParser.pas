///<summary>Attribute based command line parser.</summary>
///<author>Primoz Gabrijelcic</author>
///<remarks><para>
///   (c) 2018 Primoz Gabrijelcic
///   Free for personal and commercial use. No rights reserved.
///
///   Author            : Primoz Gabrijelcic
///   Creation date     : 2014-05-25
///   Last modification : 2018-02-20
///   Version           : 1.04
///</para><para>
///   History:
///     1.04: 2018-02-20
///       - Added parameter `wrapAtColumn` to IGpCommandLineParser.Usage. Use value <= 0
///         to disable wrapping.
///     1.03: 2015-02-02
///       - Multiple long names can be assigned to a single entity.
///     1.02: 2015-01-29
///       - Added option opIgnoreUnknownSwitches which causes parser not to
///         trigger an error when it encounters an unknown switch.
///     1.01a: 2015-01-28
///       - String comparer is no longer destroyed (as it is just a reference to
///         the global singleton).
///     1.01: 2014-08-21
///       - A short form of a long name can be provided.
///       - Fixed a small memory leak.
///     1.0a: 2014-07-03
///       - Fixed processing of quoted positional parameters.
///     1.0: 2014-06-22
///       - Released
///</para></remarks>

// example parameter configuration
//  TCommandLine = class
//  strict private
//    FAutoTest  : boolean;
//    FExtraFiles: string;
//    FFromDate  : string;
//    FImportDir : string;
//    FInputFile : string;
//    FNumDays   : integer;
//    FOutputFile: string;
//    FPrecision : string;
//    FToDateTime: string;
//  public
//    [CLPLongName('ToDate'), CLPDescription('Set ending date/time', '<dt>')]
//    property ToDateTime: string read FToDateTime write FToDateTime;
//
//    [CLPDescription('Set precision'), CLPDefault('3.14')]
//    property Precision: string read FPrecision write FPrecision;
//
//    [CLPName('i'), CLPLongName('ImportDir'), CLPDescription('Set import folder', '<path>')]
//    property ImportDir: string read FImportDir write FImportDir;
//
//    [CLPName('a'), CLPLongName('AutoTest', 'Auto'), CLPDescription('Enable autotest mode. And now some long text for testing word wrap in Usage.')]
//    property AutoTest: boolean read FAutoTest write FAutoTest;
//
//    [CLPName('f'), CLPLongName('FromDate'), CLPDescription('Set starting date', '<dt>'), CLPRequired]
//    property FromDate: string read FFromDate write FFromDate;
//
//    [CLPName('n'), CLPDescription('Set number of days', '<days>'), CLPDefault('100')]
//    property NumDays: integer read FNumDays write FNumDays;
//
//    [CLPPosition(1), CLPDescription('Input file'), CLPLongName('input_file'), CLPRequired]
//    property InputFile: string read FInputFile write FInputFile;
//
//    [CLPPosition(2), CLPDescription('Output file'), CLPRequired]
//    property OutputFile: string read FOutputFile write FOutputFile;
//
//    [CLPPositionRest, CLPDescription('Extra files'), CLPName('extra_files')]
//    property ExtraFiles: string read FExtraFiles write FExtraFiles;
//  end;

unit GpCommandLineParser;

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.RTTI;

type
  ///	<summary>
  ///	  Specifies short (one letter) name for the switch.
  ///	</summary>
  CLPNameAttribute = class(TCustomAttribute)
  strict private
    FName: string;
  public
    constructor Create(const name: string);
    property Name: string read FName;
  end; { CLPNameAttribute }

  ///	<summary>
  ///	  Specifies long name for the switch. If not set, property name is used
  ///	  for long name.
  ///   A short form of the long name can also be provided which must match the beginning
  ///   of the long form. In this case, parser will accept shortened versions of the
  ///   long name, but no shorter than the short form.
  ///   An example: if 'longName' = 'autotest' and 'shortForm' = 'auto' then the parser
  ///   will accept 'auto', 'autot', 'autote', 'autotes' and 'autotest', but not 'aut',
  ///   'au' and 'a'.
  ///   Multiple long names (alternate switches) can be provided for one entity.
  ///	</summary>
  CLPLongNameAttribute = class(TCustomAttribute)
  strict private
    FLongName : string;
    FShortForm: string;
  public
    constructor Create(const longName: string; const shortForm: string = '');
    property LongName: string read FLongName;
    property ShortForm: string read FShortForm;
  end; { CLPNameAttribute }

  ///	<summary>
  ///	  Specifies default value which will be used if switch is not found on
  ///	  the command line.
  ///	</summary>
  CLPDefaultAttribute = class(TCustomAttribute)
  strict private
    FDefaultValue: string;
  public
    constructor Create(const value: string); overload;
    property DefaultValue: string read FDefaultValue;
  end; { CLPDefaultAttribute }

  ///	<summary>
  ///	  Provides switch description, used for the Usage function.
  ///	</summary>
  CLPDescriptionAttribute = class(TCustomAttribute)
  strict private
    FDescription: string;
    FParamName  : string;
  public
    const DefaultValue = 'value';
    constructor Create(const description: string; const paramName: string = '');
    property Description: string read FDescription;
    property ParamName: string read FParamName;
  end; { CLPDescriptionAttribute }

  ///	<summary>
  ///	  When present, specifies that the switch is required.
  ///	</summary>
  CLPRequiredAttribute = class(TCustomAttribute)
  public
  end; { CLPRequiredAttribute }

  ///	<summary>
  ///	  Specifies position of a positional (unnamed) switch. First positional
  ///	  switch has position 1.
  ///	</summary>
  CLPPositionAttribute = class(TCustomAttribute)
  strict private
    FPosition: integer;
  public
    constructor Create(position: integer);
    property Position: integer read FPosition;
  end; { CLPPositionAttribute }

  ///	<summary>
  ///	  Specifies switch that will receive a #13-delimited list of all
  ///	  positional parameters for which switch definitions don't exist.
  ///	</summary>
  CLPPositionRestAttribute = class(TCustomAttribute)
  public
  end; { CLPPositionRestAttribute }

  TCLPErrorKind = (
    //configuration error, will result in exception
    ekPositionalsBadlyDefined, ekNameNotDefined, ekShortNameTooLong, ekLongFormsDontMatch,
    //user data error, will result in error result
    ekMissingPositional, ekExtraPositional, ekMissingNamed, ekUnknownNamed, ekInvalidData);

  TCLPErrorDetailed = (
    edBooleanWithData,             // SBooleanSwitchCannotAcceptData
    edCLPPositionRestNotString,    // STypeOfACLPPositionRestPropertyMu
    edExtraCLPPositionRest,        // SOnlyOneCLPPositionRestPropertyIs
    edInvalidDataForSwitch,        // SInvalidDataForSwitch
    edLongFormsDontMatch,          // SLongFormsDontMatch
    edMissingNameForProperty,      // SMissingNameForProperty
    edMissingPositionalDefinition, // SMissingPositionalParameterDefini
    edMissingRequiredSwitch,       // SRequiredSwitchWasNotProvided
    edPositionNotPositive,         // SPositionMustBeGreaterOrEqualTo1
    edRequiredAfterOptional,       // SRequiredPositionalParametersMust
    edShortNameTooLong,            // SShortNameMustBeOneLetterLong
    edTooManyPositionalArguments,  // STooManyPositionalArguments
    edUnknownSwitch,               // SUnknownSwitch
    edUnsupportedPropertyType,     // SUnsupportedPropertyType
    edMissingRequiredParameter     // SRequiredParameterWasNotProvided
  );

  TCLPErrorInfo = record
    IsError   : boolean;
    Kind      : TCLPErrorKind;
    Detailed  : TCLPErrorDetailed;
    Position  : integer;
    SwitchName: string;
    Text      : string;
  end; { TCLPErrorInfo }

  TCLPOption = (opIgnoreUnknownSwitches);
  TCLPOptions = set of TCLPOption;

  IGpCommandLineParser = interface ['{C9B729D4-3706-46DB-A8A2-1E07E04F497B}']
    function  GetErrorInfo: TCLPErrorInfo;
    function  GetOptions: TCLPOptions;
    procedure SetOptions(const value: TCLPOptions);
  //
    function  Usage(wrapAtColumn: integer = 80): TArray<string>;
    function  Parse(commandData: TObject): boolean; overload;
    function  Parse(const commandLine: string; commandData: TObject): boolean; overload;
    property ErrorInfo: TCLPErrorInfo read GetErrorInfo;
    property Options: TCLPOptions read GetOptions write SetOptions;
  end; { IGpCommandLineParser }

  ECLPConfigurationError = class(Exception)
    ErrorInfo: TCLPErrorInfo;
    constructor Create(const errInfo: TCLPErrorInfo);
  end; { ECLPConfigurationError }

///	<summary>
///	  Returns global parser instance. Not thread-safe.
///	</summary>
function CommandLineParser: IGpCommandLineParser;

///	<summary>
///	  Create new command line parser instance. Thread-safe.
///	</summary>
function CreateCommandLineParser: IGpCommandLineParser;

implementation

uses
  System.StrUtils,
  System.Classes,
  System.Generics.Defaults,
  System.Generics.Collections;

resourcestring
  SBooleanSwitchCannotAcceptData    = 'Boolean switch cannot accept data.';
  SDefault                          = ', default: ';
  SInvalidDataForSwitch             = 'Invalid data for switch.';
  SLongFormsDontMatch               = 'Short version of the long name must match beginning of the long name';
  SMissingNameForProperty           = 'Missing name for property.';
  SMissingPositionalParameterDefini = 'Missing positional parameter definition.';
  SOnlyOneCLPPositionRestPropertyIs = 'Only one CLPPositionRest property is allowed.';
  SOptions                          = '[options]';
  SPositionMustBeGreaterOrEqualTo1  = 'Position must be greater or equal to 1.';
  SRequiredParameterWasNotProvided  = 'Required parameter was not provided.';
  SRequiredPositionalParametersMust = 'Required positional parameters must not appear after optional positional parameters.';
  SRequiredSwitchWasNotProvided     = 'Required switch was not provided.';
  SShortNameMustBeOneLetterLong     = 'Short name must be one letter long';
  STooManyPositionalArguments       = 'Too many positional arguments.';
  STypeOfACLPPositionRestPropertyMu = 'Type of a CLPPositionRest property must be string.';
  SUnknownSwitch                    = 'Unknown switch.';
  SUnsupportedPropertyType          = 'Unsupported property %s type.';

type
  TCLPSwitchType = (stString, stInteger, stBoolean);

  TCLPSwitchOption = (soRequired, soPositional, soPositionRest);
  TCLPSwitchOptions = set of TCLPSwitchOption;

  TCLPLongName = record
    LongForm : string;
    ShortForm: string;
    constructor Create(const ALongForm, AShortForm: string);
  end; { TCLPLongName }

  TCLPLongNames = TArray<TCLPLongName>;

  TSwitchData = class
  strict private
    FDefaultValue : string;
    FDescription  : string;
    FInstance     : TObject;
    FLongNames    : TCLPLongNames;
    FName         : string;
    FOptions      : TCLPSwitchOptions;
    FParamDesc    : string;
    FPosition     : integer;
    FPropertyName : string;
    FProvided     : boolean;
    FShortLongForm: string;
    FSwitchType   : TCLPSwitchType;
  strict protected
    function  Quote(const value: string): string;
  public
    constructor Create(instance: TObject; const propertyName, name: string;
      const longNames: TCLPLongNames; switchType: TCLPSwitchType; position: integer;
      options: TCLPSwitchOptions; const defaultValue, description, paramName: string);
    function  AppendValue(const value, delim: string; doQuote: boolean): boolean;
    procedure Enable;
    function  GetValue: string;
    function  SetValue(const value: string): boolean;
    property DefaultValue: string read FDefaultValue;
    property Description: string read FDescription;
    property LongNames: TCLPLongNames read FLongNames;
    property Name: string read FName;
    property Options: TCLPSwitchOptions read FOptions;
    property ParamName: string read FParamDesc;
    property Position: integer read FPosition write FPosition;
    property PropertyName: string read FPropertyName;
    property Provided: boolean read FProvided;
    property ShortLongForm: string read FShortLongForm;
    property SwitchType: TCLPSwitchType read FSwitchType;
  end; { TSwitchData }

  TGpCommandLineParser = class(TInterfacedObject, IGpCommandLineParser)
  strict private
  const
    FSwitchDelims: array [1..3] of string = ('/', '--', '-'); //-- must be checked before -
    FParamDelims : array [1..2] of char = (':', '=');
  var
    FErrorInfo     : TCLPErrorInfo;
    FOptions       : TCLPOptions;
    FPositionals   : TArray<TSwitchData>;
    FSwitchComparer: TStringComparer;
    FSwitchDict    : TDictionary<string,TSwitchData>;
    FSwitchList    : TObjectList<TSwitchData>;
  strict protected
    procedure AddSwitch(instance: TObject; const propertyName, name: string; const longNames:
      TCLPLongNames; switchType: TCLPSwitchType; position: integer; options:
      TCLPSwitchOptions; const defaultValue, description, paramName: string);
    function  CheckAttributes: boolean;
    function  GetCommandLine: string;
    function  GetErrorInfo: TCLPErrorInfo; inline;
    function  GetOptions: TCLPOptions;
    function  GrabNextElement(var s, el: string): boolean;
    function  IsSwitch(const el: string; var param: string; var data: TSwitchData): boolean;
    function  MapPropertyType(const prop: TRttiProperty): TCLPSwitchType;
    procedure ProcessAttributes(instance: TObject; const prop: TRttiProperty);
    function  ProcessCommandLine(commandData: TObject; const commandLine: string): boolean;
    procedure ProcessDefinitionClass(commandData: TObject);
    function  SetError(kind: TCLPErrorKind; detail: TCLPErrorDetailed; const text: string;
      position: integer = 0; switchName: string = ''): boolean;
    procedure SetOptions(const value: TCLPOptions);
  protected // used in TGpUsageFormatter
    property Positionals: TArray<TSwitchData> read FPositionals;
    property SwitchList: TObjectList<TSwitchData> read FSwitchList;
  public
    constructor Create;
    destructor  Destroy; override;
    function  Parse(const commandLine: string; commandData: TObject): boolean; overload;
    function  Parse(commandData: TObject): boolean; overload;
    function  Usage(wrapAtColumn: integer = 80): TArray<string>;
    property ErrorInfo: TCLPErrorInfo read GetErrorInfo;
    property Options: TCLPOptions read GetOptions write SetOptions;
  end; { TGpCommandLineParser }

  TGpUsageFormatter = class
  private
    function  AddParameter(const name, delim: string; const data: TSwitchData): string;
    procedure AlignAndWrap(sl: TStringList; wrapAtColumn: integer);
    function  Wrap(const name: string; const data: TSwitchData): string;
    function  LastSpaceBefore(const s: string; startPos: integer): integer;
  public
    procedure Usage(parser: TGpCommandLineParser; wrapAtColumn: integer;
      var usageList: TArray<string>);
  end; { TGpUsageFormatter }

var
  GGpCommandLineParser: IGpCommandLineParser;

{ exports }

function CommandLineParser: IGpCommandLineParser;
begin
  if not assigned(GGpCommandLineParser) then
    GGpCommandLineParser := CreateCommandLineParser;
  Result := GGpCommandLineParser;
end; { CommandLineParser }

function CreateCommandLineParser: IGpCommandLineParser;
begin
  Result := TGpCommandLineParser.Create;
end; { CreateCommandLineParser }

{ CLPNameAttribute }

constructor CLPNameAttribute.Create(const name: string);
begin
  inherited Create;
  FName := name;
end; { CLPNameAttribute.Create }

{ CLPLongNameAttribute }

constructor CLPLongNameAttribute.Create(const longName, shortForm: string);
begin
  inherited Create;
  FLongName := longName;
  FShortForm := shortForm;
end; { CLPLongNameAttribute.Create }

{ CLPDefaultAttribute }

constructor CLPDefaultAttribute.Create(const value: string);
begin
  inherited Create;
  FDefaultValue := value;
end; { CLPDefaultAttribute.Create }

{ CLPDescriptionAttribute }

constructor CLPDescriptionAttribute.Create(const description: string; const paramName: string);
begin
  inherited Create;
  FDescription := description;
  if paramName <> '' then
    FParamName := paramName
  else
    FParamName := DefaultValue;
end; { CLPDescriptionAttribute.Create }

{ CLPPositionAttribute }

constructor CLPPositionAttribute.Create(position: integer);
begin
  inherited Create;
  FPosition := position;
end; { CLPPositionAttribute.Create }

{ TCLPLongName }

constructor TCLPLongName.Create(const ALongForm, AShortForm: string);
begin
  LongForm := ALongForm;
  ShortForm := AShortForm;
end; { TCLPLongName.Create }

{ TSwitchData }

constructor TSwitchData.Create(instance: TObject; const propertyName, name: string; const
  longNames: TCLPLongNames; switchType: TCLPSwitchType; position: integer; options:
  TCLPSwitchOptions; const defaultValue, description, paramName: string);
begin
  inherited Create;
  FInstance := instance;
  FPropertyName := propertyName;
  FName := name;
  FLongNames := longNames;
  FShortLongForm := shortLongForm;
  FSwitchType := switchType;
  FPosition := position;
  FOptions := options;
  FDefaultValue := defaultValue;
  FDescription := description;
  FParamDesc := paramName;
end; { TSwitchData.Create }

function TSwitchData.AppendValue(const value, delim: string; doQuote: boolean): boolean;
var
  s: string;
begin
  s := GetValue;
  if s <> '' then
    s := s + delim;
  if doQuote then
    s := s + Quote(value)
  else
    s := s + value;
  Result := SetValue(s);
end; { TSwitchData.AppendValue }

procedure TSwitchData.Enable;
var
  ctx : TRttiContext;
  prop: TRttiProperty;
  typ : TRttiType;
begin
  if SwitchType <> stBoolean then
    raise Exception.Create('TSwitchData.Enable: Not supported');

  ctx := TRttiContext.Create;
  typ := ctx.GetType(FInstance.ClassType);
  prop := typ.GetProperty(FPropertyName);
  prop.SetValue(FInstance, true);
  FProvided := true;
end; { TSwitchData.Enable }

function TSwitchData.GetValue: string;
var
  ctx : TRttiContext;
  prop: TRttiProperty;
  typ : TRttiType;
begin
  ctx := TRttiContext.Create;
  typ := ctx.GetType(FInstance.ClassType);
  prop := typ.GetProperty(FPropertyName);
  Result := prop.GetValue(FInstance).AsString;
end; { TSwitchData.GetValue }

function TSwitchData.Quote(const value: string): string;
begin
  if (Pos(' ', value) > 0) or (Pos('"', value) > 0) then
    Result := '"' + StringReplace(value, '"', '""', [rfReplaceAll]) + '"'
  else
    Result := value;
end; { TSwitchData.Quote }

function TSwitchData.SetValue(const value: string): boolean;
var
  c     : integer;
  ctx   : TRttiContext;
  iValue: integer;
  prop  : TRttiProperty;
  typ   : TRttiType;
begin
  Result := true;
  ctx := TRttiContext.Create;
  typ := ctx.GetType(FInstance.ClassType);
  prop := typ.GetProperty(FPropertyName);

  case SwitchType of
    stString:
      prop.SetValue(FInstance, value);
    stInteger:
      begin
        Val(value, iValue, c);
        if c <> 0 then
          Exit(false);
        prop.SetValue(FInstance, iValue);
      end;
    else
      raise Exception.Create('TSwitchData.SetValue: Not supported');
  end;
  FProvided := true;
end; { TSwitchData.SetValue }

{ TGpCommandLineParser }

constructor TGpCommandLineParser.Create;
begin
  inherited Create;
  FSwitchList := TObjectList<TSwitchData>.Create;
  FSwitchComparer := TIStringComparer.Ordinal; //don't destroy, Ordinal returns a global singleton
  FSwitchDict := TDictionary<string,TSwitchData>.Create(FSwitchComparer);
end; { TGpCommandLineParser.Create }

destructor TGpCommandLineParser.Destroy;
begin
  FreeAndNil(FSwitchDict);
  FreeAndNil(FSwitchList);
  inherited Destroy;
end; { TGpCommandLineParser.Destroy }

procedure TGpCommandLineParser.AddSwitch(instance: TObject; const propertyName, name:
  string; const longNames: TCLPLongNames; switchType: TCLPSwitchType; position: integer;
  options: TCLPSwitchOptions; const defaultValue, description, paramName: string);
var
  data    : TSwitchData;
  i       : integer;
  longName: TCLPLongName;
begin
  data := TSwitchData.Create(instance, propertyName, name, longNames, switchType,
    position, options, defaultValue, description, paramName);
  FSwitchList.Add(data);
  if name <> '' then
    FSwitchDict.Add(name, data);
  for longName in longNames do begin
    FSwitchDict.Add(longName.LongForm, data);
    if longName.ShortForm <> '' then begin
      for i := Length(longName.ShortForm) to Length(longName.LongForm) - 1 do
        FSwitchDict.AddOrSetValue(Copy(longName.LongForm, 1, i), data);
    end;
  end;
end; { TGpCommandLineParser.AddSwitch }

///	<summary>
///	  Verifies attribute consistency.
///
///   For positional attributes there must be no 'holes' (i.e. positional attributes must
///   be numbere 1,2,...N) and there must be no 'required' attributes after 'optional'
///   attributes.
///
///   There must be at most one 'Rest' positional attribute.
///
///   Each switch attribute must have a long or short name. (That is actually enforced in
///   in the current implementation as long name is set to property name by default,
///   but the test is still left in for future proofing.)
///
///   Short names (when provided) must be one letter long.
///
///   At the same time creates an array of references to positional attributes,
///   FPositionals.
///	</summary>
function TGpCommandLineParser.CheckAttributes: boolean;
var
  data        : TSwitchData;
  hasOptional : boolean;
  highPos     : integer;
  i           : integer;
  longName    : TCLPLongName;
  positionRest: TSwitchData;
begin
  Result := true;

  highPos := 0;
  hasOptional := false;
  positionRest := nil;
  for data in FSwitchList do
    if soPositional in data.Options then begin
      if soPositionRest in data.Options then begin
        if assigned(positionRest) then
          Exit(SetError(ekPositionalsBadlyDefined, edExtraCLPPositionRest, SOnlyOneCLPPositionRestPropertyIs, 0, data.PropertyName))
        else if data.SwitchType <> stString then
          Exit(SetError(ekPositionalsBadlyDefined, edCLPPositionRestNotString, STypeOfACLPPositionRestPropertyMu, 0, data.PropertyName))
        else
          positionRest := data;
      end
      else begin
        if data.Position <= 0 then
          Exit(SetError(ekPositionalsBadlyDefined, edPositionNotPositive, SPositionMustBeGreaterOrEqualTo1, data.Position))
        else if data.Position > highPos then
          highPos := data.Position;
      end;
      if not (soRequired in data.Options) then
        hasOptional := false
      else if hasOptional then
        Exit(SetError(ekPositionalsBadlyDefined, edRequiredAfterOptional, SRequiredPositionalParametersMust, data.Position));
    end;

  if assigned(positionRest) then begin
    Inc(highPos);
    positionRest.Position := highPos;
  end;
  if highPos = 0 then
    Exit(true);

  SetLength(FPositionals, highPos);
  for i := Low(FPositionals) to High(FPositionals) do
    FPositionals[i] := nil;

  for data in FSwitchList do
    if soPositional in data.Options then
      FPositionals[data.Position-1] := data;

  for i := Low(FPositionals) to High(FPositionals) do
    if FPositionals[i] = nil then
      Exit(SetError(ekPositionalsBadlyDefined, edMissingPositionalDefinition, SMissingPositionalParameterDefini, i+1));

  for data in FSwitchList do
    if not (soPositional in data.Options) then
      if (data.Name = '') and (Length(data.LongNames) = 0) then
        Exit(SetError(ekNameNotDefined, edMissingNameForProperty, SMissingNameForProperty, 0, data.PropertyName))
      else if (data.Name <> '') and (Length(data.Name) <> 1) then
        Exit(SetError(ekShortNameTooLong, edShortNameTooLong, SShortNameMustBeOneLetterLong, 0, data.Name))
      else for longName in data.LongNames do
        if (longName.ShortForm <> '') and (not StartsText(longName.ShortForm, longName.LongForm)) then
          Exit(SetError(ekLongFormsDontMatch, edLongFormsDontMatch, SLongFormsDontMatch, 0, longName.LongForm));
end; { TGpCommandLineParser.CheckAttributes }

function TGpCommandLineParser.GetCommandLine: string;
var
  i: integer;
begin
  Result := '';
  for i := 1 to ParamCount do begin
    if i > 1 then
      Result := Result + ' ';
    if Pos(' ', ParamStr(i)) > 0 then
      Result := Result + '"' + ParamStr(i) + '"'
    else
      Result := Result + ParamStr(i);
  end;
end; { TGpCommandLineParser.GetCommandLine }

function TGpCommandLineParser.GetErrorInfo: TCLPErrorInfo;
begin
  Result := FErrorInfo;
end; { TGpCommandLineParser.GetErrorInfo }

function TGpCommandLineParser.GetOptions: TCLPOptions;
begin
  Result := FOptions;
end; { TGpCommandLineParser.GetOptions }

function TGpCommandLineParser.GrabNextElement(var s, el: string): boolean;
var
  p: integer;
begin
  el := '';
  s := TrimLeft(s);
  if s = '' then
    Exit(false);

  if s[1] = '"' then begin
    repeat
      p := PosEx('"', s, 2);
      if p <= 0 then //unterminated quote
        p := Length(s);
      el := el + Copy(s, 1, p);
      Delete(s, 1, p);
    until (s = '') or (s[1] <> '"');
    Delete(el, 1, 1);
    if el[Length(el)] = '"' then
      Delete(el, Length(el), 1);
    el := StringReplace(el, '""', '"', [rfReplaceAll]);
  end
  else begin
    p := Pos(' ', s);
    if p <= 0 then //last element
      p := Length(s) + 1;
    el := Copy(s, 1, p-1);
    Delete(s, 1, p);
  end;
  Result := true;
end; { TGpCommandLineParser.GrabNextElement }

function TGpCommandLineParser.IsSwitch(const el: string; var param: string;
  var data: TSwitchData): boolean;
var
  delimPos: integer;
  minPos  : integer;
  name    : string;
  pd      : char;
  sd      : string;
  trimEl  : string;
begin
  Result := false;
  param := '';

  trimEl := el;
  for sd in FSwitchDelims do
    if StartsStr(sd, trimEl) then begin
      trimEl := el;
      Delete(trimEl, 1, Length(sd));
      if trimEl <> '' then
        Result := true;
      break; //for sd
    end;

  if Result then begin //try to extract parameter data
    name := trimEl;
    minPos := 0;
    for pd in FParamDelims do begin
      delimPos := Pos(pd, name);
      if (delimPos > 0) and ((minPos = 0) or (delimPos < minPos)) then
        minPos := delimPos;
    end;

    if minPos > 0 then begin
      param := name;
      Delete(param, 1, minPos);
      name := Copy(name, 1, minPos - 1);
    end;

    FSwitchDict.TryGetValue(name, data);

    if not assigned(data) then begin //try short name
      if FSwitchDict.TryGetValue(trimEl[1], data) then begin
        param := trimEl;
        Delete(param, 1, 1);
        if (param <> '') and (data.SwitchType = stBoolean) then //misdetection, boolean switch cannot accept data
          data := nil;
      end;
    end;
  end;
end; { TGpCommandLineParser.IsSwitch }

function TGpCommandLineParser.MapPropertyType(const prop: TRttiProperty): TCLPSwitchType;
begin
  case prop.PropertyType.TypeKind of
    tkInteger, tkInt64:
      Result := stInteger;
    tkEnumeration:
      if prop.PropertyType.Handle = TypeInfo(Boolean) then
        Result := stBoolean
      else
        raise Exception.CreateFmt(SUnsupportedPropertyType, [prop.Name]);
    tkString, tkLString, tkWString, tkUString:
      Result := stString;
    else
      raise Exception.CreateFmt(SUnsupportedPropertyType, [prop.Name]);
  end;
end; { TGpCommandLineParser.MapPropertyType }

function TGpCommandLineParser.Parse(const commandLine: string; commandData: TObject): boolean;
begin
  FSwitchDict.Clear;
  SetLength(FPositionals, 0);
  FSwitchList.Clear;

  ProcessDefinitionClass(commandData);
  Result := CheckAttributes;
  if not Result then
    raise ECLPConfigurationError.Create(ErrorInfo)
  else
    Result := ProcessCommandLine(commandData, commandLine);
end; { TGpCommandLineParser.Parse }

function TGpCommandLineParser.Parse(commandData: TObject): boolean;
begin
  Result := Parse(GetCommandLine, commandData);
end; { TGpCommandLineParser.Parse }

procedure TGpCommandLineParser.ProcessAttributes(instance: TObject; const prop: TRttiProperty);
var
  attr       : TCustomAttribute;
  default    : string;
  description: string;
  longNames  : TCLPLongNames;
  name       : string;
  options    : TCLPSwitchOptions;
  paramName  : string;
  position   : integer;

  procedure AddLongName(const longForm, shortForm: string);
  begin
    SetLength(longNames, Length(longNames) + 1);
    longNames[High(longNames)] := TCLPLongName.Create(longForm, shortForm);
  end; { AddLongName }

begin { TGpCommandLineParser.ProcessAttributes }
  name := '';
  description := '';
  paramName := CLPDescriptionAttribute.DefaultValue;
  options := [];
  position := 0;
  SetLength(longNames, 0);
  for attr in prop.GetAttributes do begin
    if attr is CLPNameAttribute then
      name := CLPNameAttribute(attr).Name
    else if attr is CLPLongNameAttribute then begin
      AddLongName(CLPLongNameAttribute(attr).LongName,
                  CLPLongNameAttribute(attr).ShortForm);
    end
    else if attr is CLPDefaultAttribute then
      default := CLPDefaultAttribute(attr).DefaultValue
    else if attr is CLPDescriptionAttribute then begin
      description := CLPDescriptionAttribute(attr).Description;
      paramName := CLPDescriptionAttribute(attr).paramName;
    end
    else if attr is CLPRequiredAttribute then
      Include(options, soRequired)
    else if attr is CLPPositionAttribute then begin
      position := CLPPositionAttribute(attr).Position;
      Include(options, soPositional);
    end
    else if attr is CLPPositionRestAttribute then begin
      Include(options, soPositional);
      Include(options, soPositionRest);
    end;
  end; //for attr

  if (Length(longNames) = 0) and (not SameText(prop.Name, Trim(name))) then
    AddLongName(prop.Name, '');

  AddSwitch(instance, prop.Name, Trim(name), longNames, MapPropertyType(prop), position,
    options, default, Trim(description), Trim(paramName));
end; { TGpCommandLineParser.ProcessAttributes }

function TGpCommandLineParser.ProcessCommandLine(commandData: TObject; const commandLine:
  string): boolean;
var
  data    : TSwitchData;
  el      : string;
  param   : string;
  position: integer;
  s       : string;
begin
  Result := true;

  for data in FSwitchList do
    if data.DefaultValue <> '' then
      data.SetValue(data.DefaultValue);

  position := 1;
  s := commandLine;
  while GrabNextElement(s, el) do begin
    if IsSwitch(el, param, data) then begin
      if not assigned(data) then
        if opIgnoreUnknownSwitches in FOptions then
          continue //while
        else
          Exit(SetError(ekUnknownNamed, edUnknownSwitch, SUnknownSwitch, 0, el));
      if data.SwitchType = stBoolean then begin
        if param = '' then
          data.Enable
        else
          Exit(SetError(ekInvalidData, edBooleanWithData, SBooleanSwitchCannotAcceptData, 0, el));
      end
      else if param <> '' then
        if not data.SetValue(param) then
          Exit(SetError(ekInvalidData, edInvalidDataForSwitch, SInvalidDataForSwitch, 0, el));
    end
    else begin
      if (position-1) > High(FPositionals) then
        Exit(SetError(ekExtraPositional, edTooManyPositionalArguments, STooManyPositionalArguments, 0, el));
      data := FPositionals[position-1];
      if soPositionRest in data.Options then begin
        if not data.AppendValue(el, #13, false) then
          Exit(SetError(ekInvalidData, edInvalidDataForSwitch, SInvalidDataForSwitch, 0, el));
      end
      else begin
        if not data.SetValue(el) then
          Exit(SetError(ekInvalidData, edInvalidDataForSwitch, SInvalidDataForSwitch, 0, el));
        Inc(position);
      end;
    end;
  end; //while s <> ''

  for data in FPositionals do
    if (soRequired in data.Options) and (not data.Provided) then
      Exit(SetError(ekMissingPositional, edMissingRequiredParameter, SRequiredParameterWasNotProvided, data.Position, data.LongNames[0].LongForm));

  for data in FSwitchlist do
    if (soRequired in data.Options) and (not data.Provided) then
      Exit(SetError(ekMissingNamed, edMissingRequiredSwitch, SRequiredSwitchWasNotProvided, 0, data.LongNames[0].LongForm));
end; { TGpCommandLineParser.ProcessCommandLine }

procedure TGpCommandLineParser.ProcessDefinitionClass(commandData: TObject);
var
  ctx : TRttiContext;
  prop: TRttiProperty;
  typ : TRttiType;
begin
  ctx := TRttiContext.Create;
  typ := ctx.GetType(commandData.ClassType);
  for prop in typ.GetProperties do
    if prop.Parent = typ then
      ProcessAttributes(commandData, prop);
end; { TGpCommandLineParser.ProcessDefinitionClass }

function TGpCommandLineParser.SetError(kind: TCLPErrorKind; detail: TCLPErrorDetailed;
  const text: string; position: integer; switchName: string): boolean;
begin
  FErrorInfo.Kind := kind;
  FErrorInfo.Detailed := detail;
  FErrorInfo.Text := text;
  FErrorInfo.Position := position;
  FErrorInfo.SwitchName := switchName;
  FErrorInfo.IsError := true;
  Result := false;
end; { TGpCommandLineParser.SetError }

procedure TGpCommandLineParser.SetOptions(const value: TCLPOptions);
begin
  FOptions := value;
end; { TGpCommandLineParser.SetOptions }

function TGpCommandLineParser.Usage(wrapAtColumn: integer): TArray<string>;
var
  formatter: TGpUsageFormatter;
begin
  formatter := TGpUsageFormatter.Create;
  try
    formatter.Usage(Self, wrapAtColumn, Result);
  finally FreeAndNil(formatter); end;
end; { TGpCommandLineParser.Usage }

{ TGpUsageFormatter }

function TGpUsageFormatter.AddParameter(const name, delim: string; const data: TSwitchData): string;
begin
  if data.SwitchType = stBoolean then
    Result := name
  else
    Result := name + delim + data.ParamName;

  if delim = '' then
    Result := '-' + Result
  else
    Result := '/' + Result;
end; { TGpUsageFormatter.AddParameter }

procedure TGpUsageFormatter.AlignAndWrap(sl: TStringList; wrapAtColumn: integer);
var
  i     : integer;
  maxPos: integer;
  posDel: integer;
  s     : string;
begin
  maxPos := 0;

  for s in sl do begin
    posDel := Pos(' -', s);
    if posDel > maxPos then
      maxPos := posDel;
  end;

  i := 0;
  while i < sl.Count do begin
    s := sl[i];
    posDel := Pos(' -', s);
    if (posDel > 0) and (posDel < maxPos) then begin
      Insert(StringOfChar(' ', maxPos - posDel), s, posDel);
      sl[i] := s;
    end;
    if Length(s) >= wrapAtColumn then begin
      posDel := LastSpaceBefore(s, wrapAtColumn);
      if posDel > 0 then begin
        sl.Insert(i+1, StringOfChar(' ', maxPos + 2) + Copy(s, posDel + 1, Length(s) - posDel));
        sl[i] := Copy(s, 1, posDel-1);
        Inc(i);
      end;
    end;

    Inc(i);
  end; //while
end; { TGpUsageFormatter.Align }

function TGpUsageFormatter.LastSpaceBefore(const s: string; startPos: integer): integer;
begin
  Result := startPos-1;
  while (Result > 0) and (s[Result] <> ' ') do
    Dec(Result);
end; { TGpUsageFormatter.LastSpaceBefore }

procedure TGpUsageFormatter.Usage(parser: TGpCommandLineParser; wrapAtColumn: integer;
  var usageList: TArray<string>);
var
  addedOptions: boolean;
  cmdLine     : string;
  data        : TSwitchData;
  help        : TStringList;
  longName    : TCLPLongName;
  name        : string;
  name2       : string;
begin { TGpCommandLineParser.Usage }
  help := TStringList.Create;
  try
    cmdLine := ExtractFileName(ParamStr(0));

    for data in parser.Positionals do begin
      if not assigned(data) then //error in definition class
        help.Add('***missing***')
      else begin
        if data.Name <> '' then
          name := data.Name
        else if Length(data.LongNames) <> 0 then
          name := data.LongNames[0].LongForm
        else
          name := IntToStr(data.Position);
        cmdLine := cmdLine + ' ' + Wrap(name, data);
        help.Add(Format('%s - %s', [Wrap(name, data), data.Description]));
      end;
    end; //for data in FPositionals

    addedOptions := false;
    for data in parser.SwitchList do begin
      if not (soPositional in data.Options) then begin
        if not addedOptions then begin
          cmdLine := cmdLine + ' ' + SOptions;
          addedOptions := true;
        end;
        name := '';
        if data.Name <> '' then
          name := Wrap(AddParameter(data.Name, '', data), data);
        for longName in data.LongNames do begin
          name2 := Wrap(AddParameter(longName.LongForm, ':', data), data);
          if name <> '' then
            name := name + ', ';
          name := name + name2;
        end;
        name := name + ' - ' + data.Description;
        if data.DefaultValue <> '' then
          name := name + SDefault + data.DefaultValue;
        help.Add(name);
      end;
    end; //for data in FSwitchList

    if wrapAtColumn > 0 then
      AlignAndWrap(help, wrapAtColumn);
    help.Insert(0, cmdLine);
    help.Insert(1, '');

    usageList := help.ToStringArray;
  finally FreeAndNil(help); end;
end; { TGpUsageFormatter.Usage }

function TGpUsageFormatter.Wrap(const name: string; const data: TSwitchData): string;
begin
  if not (soRequired in data.Options) then
    Result := '[' + name + ']'
  else if soPositional in data.Options then
    Result := '<' + name + '>'
  else
    Result := name;
end; { TGpUsageFormatter.Wrap }

{ ECLPConfigurationError }

constructor ECLPConfigurationError.Create(const errInfo: TCLPErrorInfo);
begin
  inherited Create(errInfo.Text);
  ErrorInfo := errInfo;
end; { ECLPConfigurationError.Create }

end.
