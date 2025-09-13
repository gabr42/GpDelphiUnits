///<summary>Simple console writer with support for foreground/background colors.</summary>
///<author>Primoz Gabrijelcic</author>
///<remarks><para>
///   (c) 2019 Primoz Gabrijelcic
///   Free for personal and commercial use. No rights reserved.
///
///   Author            : Primoz Gabrijelcic
///   Creation date     : 2017-08-24
///   Last modification : 2025-01-31
///   Version           : 1.04
///</para><para>
///   History:
///     1.04: 2025-01-31
///       - OnLineEnd event now receives last line as a parameter.
///     1.03: 2019-09-09
///       - Removed dependency on OTL.
///     1.02: 2019-08-22
///       - Implemented Console.Acquire and .Release.
///     1.01b: 2018-06-22
///	      - Pointers are output correctly.
///     1.01a: 2017-12-04
///       - More thread-safe.
///     1.01: 2017-11-30
///       - Thread-friendly.
///     1.0: 2017-08-24
///       - Created.
///</para></remarks>

unit GpConsole;

// Examples:
//    Console.OnLineBegin := procedure begin
//      Console.Write(FormatDateTime('ss.zzz ', Now));
//    end;
//   Console.Writeln('default {red on green}red on green{} default {on blue}on blue' + Console.DEFAULT + ' and on black');
//   Console.Writeln('{red on green}XXXX{} {bright red on green}XXXX{} {red on bright green}XXXX{} {bright red on bright green}XXXX{}');
//   Console.Writeln(['And the answer is ', '{bright red on bright yellow}', 42, '{}', '!']);
//   Console.Writeln('{bright red on green}green{on yellow}yellow{on bright cyan}bright cyan{on green}green{}');

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.SyncObjs,
  System.StrUtils,
  System.AnsiStrings;

type
  {$SCOPEDENUMS ON}
  ConsoleColor = (Black, Blue, Green, Cyan, Red, Purple, Yellow, White);
  {$SCOPEDENUMS OFF}

  TConsole = record
  strict private const
    CLineAlloc = 160;
  strict private type
    TColorMap = record
      Name  : string;
      Color : ConsoleColor;
      FgAttr: word;
      BkAttr: word;
    end; { TColorMap }
    TStates = (stSkipLineEndProc);
    TState = set of TStates;
  var
    FAllocated   : boolean;
    FBackground  : ConsoleColor;
    FBkAttr      : word;
    FBkBrightAttr: word;
    FDisabled    : boolean;
    FFgAttr      : word;
    FFgBrightAttr: word;
    FForeground  : ConsoleColor;
    FLine        : TArray<char>;
    FLineEnd     : integer;
    FLineStart   : boolean;
    FMappings    : TArray<TColorMap>;
    FOnLineBegin : TProc;
    FOnLineEnd   : TProc<string>;
    FState       : TState;
  private
    procedure Allocate;
    function  FindColorMapping(color: ConsoleColor): TColorMap; overload;
    function  FindColorMapping(const name: string; var map: TColorMap): boolean; overload;
    function  GetBackground: ConsoleColor;
    function  GetForeground: ConsoleColor;
    function  GetOutputHandle: THandle;
    function  GetToken(const s: string; var idx: integer; var token: string): boolean;
    function  LineToString: string;
    procedure SetBackground(const value: ConsoleColor);
    procedure SetBackgroundAttr(attr: word);
    function  SetColor(const s: string): boolean;
    procedure SetForeground(const value: ConsoleColor);
    procedure SetForegroundAttr(attr: word);
  public const
    CMD_ON          = 'on';
    CMD_BRIGHT      = 'bright';
    COL_NAME_BLACK  = 'black';
    COL_NAME_BLUE   = 'blue';
    COL_NAME_CYAN   = 'cyan';
    COL_NAME_GREEN  = 'green';
    COL_NAME_PURPLE = 'purple';
    COL_NAME_RED    = 'red';
    COL_NAME_WHITE  = 'white';
    COL_NAME_YELLOW = 'yellow';
    TEXT_BLACK   = '{' + COL_NAME_BLACK  + '}';
    TEXT_BLUE    = '{' + COL_NAME_BLUE   + '}';
    TEXT_GREEN   = '{' + COL_NAME_GREEN  + '}';
    TEXT_CYAN    = '{' + COL_NAME_CYAN   + '}';
    TEXT_RED     = '{' + COL_NAME_RED    + '}';
    TEXT_PURPLE  = '{' + COL_NAME_PURPLE + '}';
    TEXT_YELLOW  = '{' + COL_NAME_YELLOW + '}';
    TEXT_WHITE   = '{' + COL_NAME_WHITE  + '}';
    BACK_BLACK   = '{' + CMD_ON + ' ' + COL_NAME_BLACK  + '}';
    BACK_BLUE    = '{' + CMD_ON + ' ' + COL_NAME_BLUE   + '}';
    BACK_GREEN   = '{' + CMD_ON + ' ' + COL_NAME_GREEN  + '}';
    BACK_CYAN    = '{' + CMD_ON + ' ' + COL_NAME_CYAN   + '}';
    BACK_RED     = '{' + CMD_ON + ' ' + COL_NAME_RED    + '}';
    BACK_PURPLE  = '{' + CMD_ON + ' ' + COL_NAME_PURPLE + '}';
    BACK_YELLOW  = '{' + CMD_ON + ' ' + COL_NAME_YELLOW + '}';
    BACK_WHITE   = '{' + CMD_ON + ' ' + COL_NAME_WHITE  + '}';
    DEFAULT      = '{}'; // normal white on black

    procedure Acquire;
    procedure Release;
    function  Timestamp: string;
    procedure Write(const s: string); overload;
    procedure Write(const values: array of const); overload;
    procedure Writeln(const s: string = ''); overload;
    procedure Writeln(const values: array of const); overload;
    property Disabled: boolean read FDisabled write FDisabled;
    property Foreground: ConsoleColor read GetForeground write SetForeground;
    property Background: ConsoleColor read GetBackground write SetBackground;
    property OnLineBegin: TProc read FOnLineBegin write FOnLineBegin;
    property OnLineEnd: TProc<string> read FOnLineEnd write FOnLineEnd;
    property OutputHandle: THandle read GetOutputHandle;
  end; { TConsole }

var
  Console: TConsole;

implementation

var
  GConsoleLock: TCriticalSection;

{ TConsole }

procedure TConsole.Acquire;
begin
  GConsoleLock.Acquire;
end; { TConsole.Acquire }

procedure TConsole.Allocate;

  procedure AddMapping(const name: string; color: ConsoleColor; r, g, b: boolean);
  var
    map: TColorMap;
  begin
    map.Name := name;
    map.Color := color;
    map.FgAttr := 0;
    map.BkAttr := 0;
    if r then begin
      map.FgAttr := map.FgAttr OR FOREGROUND_RED;
      map.BkAttr := map.BkAttr OR BACKGROUND_RED;
    end;
    if g then begin
      map.FgAttr := map.FgAttr OR FOREGROUND_GREEN;
      map.BkAttr := map.BkAttr OR BACKGROUND_GREEN;
    end;
    if b then begin
      map.FgAttr := map.FgAttr OR FOREGROUND_BLUE;
      map.BkAttr := map.BkAttr OR BACKGROUND_BLUE;
    end;
    SetLength(FMappings, Length(FMappings) + 1);
    FMappings[High(FMappings)] := map;
  end; { AddMapping }

begin { TConsole.Allocate }
  if FAllocated then
    Exit;

  AllocConsole;

  AddMapping(COL_NAME_BLACK,  ConsoleColor.Black,  false, false, false);
  AddMapping(COL_NAME_BLUE,   ConsoleColor.Blue,   false, false, true);
  AddMapping(COL_NAME_GREEN,  ConsoleColor.Green,  false, true,  false);
  AddMapping(COL_NAME_CYAN,   ConsoleColor.Cyan,   false, true,  true);
  AddMapping(COL_NAME_RED,    ConsoleColor.Red,    true,  false, false);
  AddMapping(COL_NAME_PURPLE, ConsoleColor.Purple, true,  false, true);
  AddMapping(COL_NAME_YELLOW, ConsoleColor.Yellow, true,  true,  false);
  AddMapping(COL_NAME_WHITE,  ConsoleColor.White,  true,  true,  true);

  FForeground   := ConsoleColor.White;
  FFgAttr       := FindColorMapping(FForeground).FgAttr;
  FFgBrightAttr := 0;
  FBackground   := ConsoleColor.Black;
  FBkAttr       := FindColorMapping(FBackground).BkAttr;
  FBkBrightAttr := 0;

  FLineStart := true;
  FAllocated := true;
end; { TConsole.Allocate }

function TConsole.FindColorMapping(color: ConsoleColor): TColorMap;
var
  map: TColorMap;
begin
  for map in FMappings do
    if map.Color = color then
      Exit(map);
  raise Exception.CreateFmt('TConsole.FindColorMapping: Color not found %d', [Ord(color)]);
end; { TConsole.FindColorMapping }

function TConsole.FindColorMapping(const name: string; var map: TColorMap): boolean;
var
  map1: TColorMap;
begin
  Result := false;
  for map1 in FMappings do
    if SameText(map1.Name, name) then begin
      map := map1;
      Exit(true);
    end;
end; { TConsole.FindColorMapping }

function TConsole.GetBackground: ConsoleColor;
begin
  GConsoleLock.Acquire;
  try
    Allocate;
    Result := FBackground;
  finally GConsoleLock.Release; end;
end; { TConsole.GetBackground }

function TConsole.GetForeground: ConsoleColor;
begin
  GConsoleLock.Acquire;
  try
    Allocate;
    Result := FForeground;
  finally GConsoleLock.Release; end;
end; { TConsole.GetForeground }

function TConsole.GetOutputHandle: THandle;
begin
  GConsoleLock.Acquire;
  try
    Allocate;
    Result := GetStdHandle(STD_OUTPUT_HANDLE);
  finally GConsoleLock.Release; end;
end; { TConsole.GetOutputHandle }

function TConsole.GetToken(const s: string; var idx: integer; var token: string): boolean;
var
  p : integer;
  p1: integer;
begin
  p := PosEx('{', s, idx);
  if p = 0 then
    token := Copy(s, idx, Length(s) - idx + 1)
  else if p = idx then begin
    p1 := Pos('}', s, p + 1);
    if p1 > 0 then
      token := Copy(s, p, p1 - p + 1)
    else
      token := Copy(s, idx, Length(s) - idx + 1);
  end
  else {p > idx}
    token := Copy(s, idx, p - idx);

  Inc(idx, Length(token));
  Result := (token <> '');
end; { TConsole.GetToken }

function TConsole.LineToString: string;
begin
  SetLength(Result, FLineEnd + 1);
  for var i := 0 to FLineEnd do
    Result[i+1] := FLine[i];
end; { TConsole.LineToString }

procedure TConsole.Release;
begin
  GConsoleLock.Release;
end; { TConsole.Release }

procedure TConsole.SetBackground(const value: ConsoleColor);
begin
  GConsoleLock.Acquire;
  try
    Allocate;
    SetBackgroundAttr(FindColorMapping(value).BkAttr);
  finally GConsoleLock.Release; end;
end; { TConsole.SetBackground }

procedure TConsole.SetBackgroundAttr(attr: word);
begin
  GConsoleLock.Acquire;
  try
    FBkAttr := attr;
    SetConsoleTextAttribute(OutputHandle, FBkAttr OR FFgAttr OR FBkBrightAttr OR FFgBrightAttr);
  finally GConsoleLock.Release; end;
end; { TConsole.SetBackgroundAttr }

function TConsole.SetColor(const s: string): boolean;
var
  cmd     : string;
  cmds    : TArray<string>;
  fgBright: word;
  fore    : boolean;
  map     : TColorMap;
begin
  GConsoleLock.Acquire;
  try
    Result := true;

    cmds := s.Split([' ']);

    // check validity
    for cmd in cmds do
      if not (SameText(cmd, CMD_ON) or SameText(cmd, CMD_BRIGHT) or FindColorMapping(cmd, map)) then
        Exit(false);

    // handle {}
    if Length(cmds) = 0 then begin
      FBkBrightAttr := 0;
      FFgBrightAttr := 0;
      Foreground := ConsoleColor.White;
      Background := ConsoleColor.Black;
      Exit;
    end;

    // set colors
    fore := true;
    fgBright := 0;
    for cmd in cmds do begin
      if SameText(cmd, CMD_ON) then begin
        fore := false;
        FBkBrightAttr := 0;
      end
      else if SameText(cmd, CMD_BRIGHT) then begin
        if fore then
          fgBright := FOREGROUND_INTENSITY
        else
          FBkBrightAttr := BACKGROUND_INTENSITY;
      end
      else begin
        FindColorMapping(cmd, map);
        if fore then begin
          FFgBrightAttr := fgBright;
          SetForegroundAttr(map.FgAttr);
        end
        else
          SetBackgroundAttr(map.BkAttr);
      end;
    end;
  finally GConsoleLock.Release; end;
end; { TConsole.SetColor }

procedure TConsole.SetForeground(const value: ConsoleColor);
begin
  GConsoleLock.Acquire;
  try
    Allocate;
    SetForegroundAttr(FindColorMapping(value).FgAttr);
  finally GConsoleLock.Release; end;
end; { TConsole.SetForeground }

procedure TConsole.SetForegroundAttr(attr: word);
begin
  GConsoleLock.Acquire;
  try
    FFgAttr := attr;
    SetConsoleTextAttribute(OutputHandle, FBkAttr OR FFgAttr  OR FBkBrightAttr OR FFgBrightAttr);
  finally GConsoleLock.Release; end;
end; { TConsole.SetForegroundAttr }

function TConsole.Timestamp: string;
begin
  Result := FormatDateTime('hh:nn:ss.zzz', Now);
end; { TConsole.Timestamp }

procedure TConsole.Write(const s: string);
var
  i    : integer;
  token: string;
begin
  if FDisabled then
    Exit;

  GConsoleLock.Acquire;
  try
    Allocate;

    if FLineStart and (not (stSkipLineEndProc in FState)) and assigned(OnLineBegin) then begin
      Include(FState, stSkipLineEndProc);
      try
        OnLineBegin();
        if High(FLine) = 0 then
          SetLength(FLine, CLineAlloc);
        FLineEnd := -1;
      finally Exclude(FState, stSkipLineEndProc) end;
    end;
    FLineStart := false;

    i := 1;
    while GetToken(s, i, token) do
      if not (token.StartsWith('{') and token.EndsWith('}') and SetColor(Copy(token, 2, Length(token) - 2))) then begin
        System.Write(token);
        for var c in token do begin
          Inc(FLineEnd);
          if FLineEnd > High(FLine) then
            SetLength(FLine, Length(FLine) + CLineAlloc);
          FLine[FLineEnd] := c;
        end;
      end;
  finally GConsoleLock.Release; end;
end; { TConsole.Write }

procedure TConsole.Write(const values: array of const);
var
  i  : integer;
begin
  if FDisabled then
    Exit;

  GConsoleLock.Acquire;
  try
    Allocate;

    for i := Low(values) to High(values) do begin
      with values[i] do begin
        case VType of
          vtInteger:       Write(IntToStr(VInteger));
          vtBoolean:       if VBoolean then Write('TRUE') else Write('FALSE');
          vtExtended:      Write(FloatToStr(VExtended^));
          vtPointer:       Write(Format('%p', [VPointer]));
          vtCurrency:      Write(CurrToStr(VCurrency^));
          vtObject:        Write(Format('[%.8x %s]', [pointer(VObject), VObject.ClassName]));
          vtInterface:     Write(Format('[%.8x I]', [VInterface]));
          vtInt64:         Write(IntToStr(VInt64^));
          vtUnicodeString: Write(string(VUnicodeString));
          vtChar:          Write(string(VChar));
          vtWideChar:      Write(string(VWideChar));
          vtString:        Write(string(VString^));
          vtAnsiString:    Write(string(AnsiString(VAnsiString)));
          vtWideString:    Write(WideString(VWideString));
          vtPChar:         Write(string(System.AnsiStrings.StrPas(VPChar)));
          vtPWideChar:     Write(string(StrPas(VPWideChar)));
        else
          raise Exception.Create ('TOmniValue.Create: invalid data type')
        end; //case
      end; //with
    end; //for i
  finally GConsoleLock.Release; end;
end; { TConsole.Write }

procedure TConsole.Writeln(const s: string);
begin
  if FDisabled then
    Exit;

  GConsoleLock.Acquire;
  try
    Allocate;

    if s <> '' then
      Write(s);

    if (not (stSkipLineEndProc in FState)) and assigned(OnLineEnd) then begin
      Include(FState, stSkipLineEndProc);
      try
        OnLineEnd(LineToString);
      finally Exclude(FState, stSkipLineEndProc) end;
    end;

    System.Writeln;
    FLineStart := true;
  finally GConsoleLock.Release; end;
end; { TConsole.Writeln }

procedure TConsole.Writeln(const values: array of const);
begin
  if FDisabled then
    Exit;

  GConsoleLock.Acquire;
  try
    Allocate;

    Write(values);
    Writeln;
  finally GConsoleLock.Release; end;
end; { TConsole.Writeln }

initialization
  Console := Default(TConsole);
  GConsoleLock := TCriticalSection.Create;
finalization
  FreeAndNil(GConsoleLock);
end.
