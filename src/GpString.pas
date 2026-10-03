unit GpString;

interface

uses
  System.SysUtils;

type
  TCharSet = set of ansichar;
  TDelimiters = array of integer;
  TElements = array of string;

function  MakeBackslash      (s: string): string;
function  MakeSmartBackslash (s: string): string;
function  StripBackslash     (s: string): string;
function  StripSmartBackslash(s: string): string;
procedure GpParseURL(const url : String; var Proto, User, Pass, Host, Port, Path : String);

function  NthEl        (x: string; elem: Integer; delim: char; checkQuote: integer): string;
function  NumElements  (x: string; delim: char; checkQuote: integer): Integer;
function  FirstEl      (x: string; delim: char; checkQuote: integer): string;
function  LastEl       (x: string; delim: char; checkQuote: integer): string;
function  ButFirstEl   (x: string; delim: char; checkQuote: integer): string;
function  ButLastEl    (x: string; delim: char; checkQuote: integer): string;
function  FirstNEl     (x: string; elem: Integer; delim: char; checkQuote: integer): string;
function  LastNEl      (x: string; elem: Integer; delim: char; checkQuote: integer): string;
function  ButFirstNEl  (x: string; elem: Integer; delim: char; checkQuote: integer): string;
function  ButLastNEl   (x: string; elem: Integer; delim: char; checkQuote: integer): string;
function  PosNthDelim  (x: string; elem: Integer; delim: char; checkQuote: integer): integer;
procedure SplitAtNthEl (x: string; elem: Integer; delim: char; checkQuote: integer;
  var el1,el2: string);
procedure GetDelimiters(x: string; delim: char; checkQuote: integer;
  addTerminators: boolean; var delimiters: TDelimiters); overload;
procedure GetDelimiters(x: string; delim: TCharSet; checkQuote: integer;
  addTerminators: boolean; var delimiters: TDelimiters); overload;
procedure Split(const x: string; delim: char; checkQuote: integer; var elements:
  TElements); overload;
procedure Split(const x: string; delim: TCharSet; checkQuote: integer; var elements:
  TElements); overload;
procedure Split(const x: string; const delim: TDelimiters; var elements: TElements); overload;

function  Compress     (const s: string): string;
function  TrimR        (x: string) : string;
function  TrimL        (x: string) : string;
function  ReplaceAll   (x: string; chOrig, chNew: char): string;
function  ReplaceAllSet(x: string; chOrig: TCharSet; chNew: char): string;
function  Replace      (x: string; before: string; after: string): string;
function  First        (x: string; num: integer): string;
function  Last         (x: string; num: integer): string;
function  ButFirst     (x: string; num: integer): string;
function  ButLast      (x: string; num: integer): string;
function  MidFT        (x: string; iFrom, iTo: integer): string;
function  MidFTA       (x: AnsiString; iFrom, iTo: integer): AnsiString;

function  PosR         (subs, s: string): integer;
function  HexStr (var num; byteCount : byte): string;
function  HexStrA (var num; byteCount : byte): AnsiString;

{$IFNDEF Win64}
function  StrLCopyW(Dest: PWideChar; const Source: PWideChar; MaxLen: Cardinal): PWideChar; assembler;
{$ENDIF ~Win64}

implementation

const
  Hex_Chars: array [0..15] of char = '0123456789ABCDEF';
  Hex_CharsA: array [0..15] of AnsiChar = '0123456789ABCDEF';

function MakeBackslash (s: String): String;
var
  w: integer;
begin
  if (Length (s) = 0) or (s[Length(s)] <> '\') then MakeBackslash := s + '\'
  else
  begin
    w := Length (s)-1;
    while (w > 0) and (s[w] = '\') do
    begin
      SetLength (s, w);
      dec (w);
    end;
    MakeBackslash := s;
  end;
end;

function MakeSmartBackslash (s: String): String;
begin
  if (Length (s) > 0) and (s[Length (s)] <> ':') then
    MakeSmartBackslash := MakeBackslash (s)
  else MakeSmartBackslash := s;
end;

function NthEl (x : string; elem: Integer; delim: char; checkQuote: integer): string;
label
  endFor;
var
  skip   : boolean;
  i      : integer;
  p1     : integer;
  p2     : integer;
  element: Integer;
  chk    : boolean;
  quote  : string;
begin
  skip    := false;
  element := 1;
  p1      := 0;
  p2      := -1;
  if (Length(x) >= 1) and (x[1] = delim) then
    if elem = 1 then p1 := 1;
  for i := 1 to Length(x) do begin
    if checkQuote = -1 then chk := false
    else begin
      chk   := true;
      quote := Chr(checkQuote);
    end;
    if chk and (x[i] = quote) then skip := not skip
    else if not skip then
      if x[i] = delim then begin
        Inc(element);
        if element = elem then p1 := i;
        if element = (elem+1) then begin
          p2 := i;
          goto endFor;
        end;
      end;
  end;
endFor:
  if (p1 = 0) and (p2 = -1) and (elem > 1) then begin
    NthEl := '';
    Exit;
  end;
  if p2 = -1 then p2 := Length(x)+1;
  Inc (p1);
  Dec (p2);
  quote := Copy(x,p1,p2-p1+1);
  if (checkQuote <> -1) and (Length (quote) > 1) and (quote[1] = chr (checkQuote)) and
    (quote[Length (quote)] = chr (checkQuote)) then
  begin
    Delete (quote, 1, 1);
    Delete (quote, Length (quote), 1);
  end;
  NthEl := quote;
end; { function NthEl }

function NumElements (x: string; delim: char; checkQuote: integer): Integer;
var
  i    : integer;
  cElem: Integer;
  skip : boolean;
  chk  : boolean;
  quote: string;
begin
  if Length(x) = 0 then NumElements := 0
  else begin
    if checkQuote = -1 then chk := false
    else begin
      chk   := true;
      quote := Chr(checkQuote);
    end;
    cElem := 1;
    skip  := false;
    for i := 1 to Length(x) do begin
      if chk and (x[i] = quote) then skip := not skip
      else if not skip then
        if x[i] = delim then Inc (cElem);
    end;
    NumElements := cElem;
  end;
end; { function NumElements }

function FirstEl (x: string; delim: char; checkQuote: integer): string;
begin
  FirstEl := NthEl (x,1,delim,checkQuote);
end; { function FirstEl }

function LastEl (x: string; delim: char; checkQuote: integer): string;
begin
  LastEl := NthEl (x,NumElements(x,delim,checkQuote),delim,checkQuote);
end; { function LastEl }

function ButFirstEl (x: string; delim: char; checkQuote: integer): string;
begin
  ButFirstEl := Copy (x,Length(FirstEl(x,delim,checkQuote))+2, Length (x));
end; { function ButFirstEl }

function ButLastEl (x: string; delim: char; checkQuote: integer): string;
begin
  ButLastEl := Copy (x,1,Length(x)-Length(LastEl(x,delim,checkQuote))-1);
end; { function ButLastEl }

function PosNthDelim (x: string; elem: Integer; delim: char; checkQuote: integer): integer;
var
  skip   : boolean;
  i      : integer;
  element: Integer;
  chk    : boolean;
  quote  : string;
begin
  skip    := false;
  element := 0;
  for i := 1 to Length(x) do begin
    if checkQuote = -1 then chk := false
    else begin
      chk   := true;
      quote := Chr(checkQuote);
    end;
    if chk and (x[i] = quote) then skip := not skip
    else if not skip then
      if x[i] = delim then begin
        Inc(element);
        if element = elem then begin
          PosNthDelim := i;
          Exit;
        end;
      end;
  end;
  PosNthDelim := 0;
end; { function PosNthDelim }

function FirstNEl (x: string; elem: Integer; delim: char; checkQuote: integer): string;
var
  p: integer;
begin
  p := PosNthDelim (x,elem,delim,checkQuote);
  if p = 0 then FirstNEl := x
           else FirstNEl := Copy (x,1,p-1);
end; { function FirstNEl }

function LastNEl (x: string; elem: Integer; delim: char; checkQuote: integer): string;
var
  p: integer;
begin
  p := PosNthDelim (x,NumElements(x,delim,checkQuote)-elem,delim,checkQuote);
  if p = 0 then LastNEl := ''
           else LastNEl := Copy (x,p+1,Length (x));
end; { function LastNEl }

function ButFirstNEl (x: string; elem: Integer; delim: char; checkQuote: integer): string;
var
  p: integer;
begin
  p := PosNthDelim (x,elem,delim,checkQuote);
  if p = 0 then ButFirstNEl := ''
           else ButFirstNEl := Copy (x,p+1,Length (x));
end; { function ButFirstNEl }

function ButLastNEl (x: string; elem: Integer; delim: char; checkQuote: integer): string;
begin
  ButLastNEl := FirstNEl (x,NumElements(x,delim,checkQuote)-elem,delim,checkQuote);
end; { function ButLastNEl }

procedure SplitAtNthEl (x: string; elem: Integer; delim: char; checkQuote: integer;
                        var el1,el2: string);
var
  p: integer;
begin
  p := PosNthDelim (x,elem,delim,checkQuote);
  if p = 0 then begin
    el1 := x;
    el2 := '';
  end
  else begin
    el1 := Copy(x,1,p-1);
    el2 := Copy(x,p+1,Length (x));
  end;
end; { procedure SplitAtNthEl }

(*function Compress (x: string): string;
var
  xLen: integer;
  j,i : integer;
begin
  x := Replace(x,#9,#32);
  i := 1;
  xLen := Length (x);
  while i < xLen do
  begin
    if x[i] = ' ' then
    begin
      j := i+1;
      while (j <= xLen) and (x[j] = ' ') do Inc(j);
      if j > (i+1) then Delete (x,i+1,j-i-1);
    end;
    Inc (i);
    xLen := Length (x);
  end;
  Compress := TrimL(TrimR(x));
end; { function Compress }*)

function Compress(const s: string): string;
var
  xLen: integer;
  j,i : integer;
begin
  i := 1;
  Result := s;
  xLen := Length(Result);
  while i < xLen do begin
    if (Result[i] = ' ') or (Result[i] = #9) then begin
      j := i + 1;
      while (j <= xLen) and ((Result[j] = ' ') or (Result[j] = #9)) do
        Inc(j);
      if j > (i+1) then
        Delete(Result, i+1, j-i-1);
      Result[i] := ' ';
    end;
    Inc(i);
    xLen := Length(Result);
  end;
  if (xLen > 0) and ((Result[1] = ' ') or (Result[1] = #9)) then begin
    Delete(Result, 1, 1);
    xLen := Length(Result);
  end;
  if (xLen > 0) and ((Result[xLen] = ' ') or (Result[xLen] = #9)) then
    Delete(Result, xLen, 1);
  Result := Result;
end; { function Compress }

function Replace (x: string; before: string; after: string): string;
var
  p: integer;
begin
  p := 1;
  while p <= Length(x) do begin
    if Copy(x,p,Length(before)) = before then begin
      Delete (x,p,Length(before));
      Insert (after,x,p);
      Inc (p,Length(after)-Length(before)+1);
    end
    else Inc(p);
  end;
  Replace := x;
end; { function Replace }

function ReplaceAll (x: string; chOrig, chNew: char): string;
var
  i: integer;
begin
  for i := 1 to Length(x) do
    if x[i] = chOrig then x[i] := chNew;
  ReplaceAll := x;
end; { function ReplaceAll }

function ReplaceAllSet(x: string; chOrig: TCharSet; chNew: char): string;
var
  i: integer;
begin
  for i := 1 to Length (x) do
    if ansichar(x[i]) in chOrig then x[i] := chNew;
  ReplaceAllSet := x;
end; { function ReplaceAllSet }

function TrimR (x : string): string;
var
  lenx : Integer;
begin
  lenx := Length (x);
  while (lenx > 0) and (x[lenx] = ' ') do Dec(lenx);
  SetLength (x, lenx);
  TrimR := x;
end; { function TrimR }

function TrimL (x : string): string;
var
  lenx : integer;
  i: integer;
begin
  lenx := Length (x);
  i := 1;
  while (i <= lenx) and (x[i] = ' ') do Inc(i);
  TrimL := Copy (x, i, Length (x));
end; { function TrimL }

function First (x: string; num: integer): string;
begin
  if Length(x) <= num then First := x
  else First := Copy (x,1,num);
end; { function First }

function Last (x: string; num: integer): string;
begin
  if Length(x) <= num then Last := x
  else Last := Copy (x,Length(x)-num+1,num);
end; { function Last }

function ButFirst (x: string; num: integer): string;
begin
  if Length(x) <= num then ButFirst := ''
  else ButFirst := Copy (x,num+1,Length (x));
end; { function ButFirst }

function ButLast (x: string; num: integer): string;
begin
  if Length(x) <= num then ButLast := ''
  else ButLast := Copy (x,1,Length(x)-num);
end; { function ButLast }

function MidFT(x: string; iFrom, iTo: integer): string;
begin
  Result := Copy(x, iFrom, iTo - iFrom + 1);
end; { MidFT }

function MidFTA(x: AnsiString; iFrom, iTo: integer): AnsiString;
begin
  Result := Copy(x, iFrom, iTo - iFrom + 1);
end; { MidFTA }

function PosR(subs, s: string): integer;
var
  i: integer;
  ls: integer;
begin
  ls := Length(subs);
  if ls <= Length(s) then begin
    for i := Length(s)-ls+1 downto 1 do begin
      if Copy(s,i,ls) = subs then begin
        PosR := i;
        Exit;
      end;
    end;
  end;
  PosR := 0;
end; { PosR }

function HexStr (var num; byteCount : byte): string;
var
  cast : array [1..256] of byte absolute num;
  i,b  : integer;
  res  : string;
begin
  res := '';
  for i := byteCount downto 1 do
  begin
    b := cast[i] div 16;
    if b >= 16 then b := 0;
    res := res + Hex_Chars[b];
    b := cast[i] mod 16;
    if b >= 16 then b := 0;
    res := res + Hex_Chars[b];
  end;
  SetLength (res, 2*byteCount);
  HexStr := res;
end; { function HexStr }

function HexStrA (var num; byteCount : byte): AnsiString;
var
  cast : array [1..256] of byte absolute num;
  i,b  : integer;
  res  : AnsiString;
begin
  res := '';
  for i := byteCount downto 1 do
  begin
    b := cast[i] div 16;
    if b >= 16 then b := 0;
    res := res + Hex_CharsA[b];
    b := cast[i] mod 16;
    if b >= 16 then b := 0;
    res := res + Hex_CharsA[b];
  end;
  SetLength (res, 2*byteCount);
  HexStrA := res;
end; { function HexStrA }

procedure GetDelimiters(x: string; delim: char; checkQuote: integer;
  addTerminators: boolean; var delimiters: TDelimiters);
var
  skip   : boolean;
  i      : integer;
  chk    : boolean;
  quote  : string;
  idx    : integer;
begin
  SetLength(delimiters,Length(x)+2); // leave place for terminators
  idx := 0;
  if addTerminators then begin
    delimiters[idx] := 0;
    Inc(idx);
  end;
  skip := false;
  if checkQuote = -1 then chk := false
  else begin
    chk   := true;
    quote := Chr(checkQuote);
  end;
  for i := 1 to Length(x) do begin
    if chk and (x[i] = quote) then skip := not skip
    else if not skip then begin
      if x[i] = delim then begin
        delimiters[idx] := i;
        Inc(idx);
      end;
    end;
  end; //for
  if addTerminators then begin
    delimiters[idx] := Length(x)+1;
    Inc(idx);
  end;
  SetLength(delimiters,idx);
end; { GetDelimiters }

procedure GetDelimiters(x: string; delim: TCharSet; checkQuote: integer;
  addTerminators: boolean; var delimiters: TDelimiters);
var
  skip   : boolean;
  i      : integer;
  chk    : boolean;
  quote  : string;
  idx    : integer;
begin
  SetLength(delimiters,Length(x)+2); // leave place for terminators
  idx := 0;
  if addTerminators then begin
    delimiters[idx] := 0;
    Inc(idx);
  end;
  skip := false;
  if checkQuote = -1 then chk := false
  else begin
    chk   := true;
    quote := Chr(checkQuote);
  end;
  for i := 1 to Length(x) do begin
    if chk and (x[i] = quote) then skip := not skip
    else if not skip then begin
      if ansichar(x[i]) in delim then begin
        delimiters[idx] := i;
        Inc(idx);
      end;
    end;
  end; //for
  if addTerminators then begin
    delimiters[idx] := Length(x)+1;
    Inc(idx);
  end;
  SetLength(delimiters,idx);
end; { GetDelimiters }

procedure Split(const x: string; delim: char; checkQuote: integer; var elements:
  TElements);
var
  delimiters: TDelimiters;
begin
  GetDelimiters(x, delim, checkQuote, true, delimiters);
  Split(x, delimiters, elements);
end; { Split }

procedure Split(const x: string; delim: TCharSet; checkQuote: integer; var elements:
  TElements);
var
  delimiters: TDelimiters;
begin
  GetDelimiters(x, delim, checkQuote, true, delimiters);
  Split(x, delimiters, elements);
end; { Split }

procedure Split(const x: string; const delim: TDelimiters; var elements: TElements);
var
  iDelim: integer;
begin
  SetLength(elements, Length(delim) - 1);
  for iDelim := Low(delim) to High(delim) - 1 do
    elements[iDelim] := MidFT(x, delim[iDelim]+1, delim[iDelim+1]-1);
end; { Split }

function StripBackslash (s: String): String;
begin
  if (Length (s) > 0) and (s[Length(s)] = '\') then StripBackslash := Copy (s, 1, Length (s)-1)
  else StripBackslash := s;
end;

function StripSmartBackslash (s: String): String;
begin
  if (Length (s) > 1) and (s[Length(s)] = '\') and (s[Length (s)-1] <> ':') then
    StripSmartBackslash := Copy (s, 1, Length (s)-1)
  else StripSmartBackslash := s;
end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ Find the count'th occurence of the s string in the t string.              }
{ If count < 0 then look from the back                                      }
function Posn(const s , t : String; Count : Integer) : Integer;
var
    i, h, Last : Integer;
    u          : String;
begin
    u := t;
    if Count > 0 then begin
        Result := Length(t);
        for i := 1 to Count do begin
            h := Pos(s, u);
            if h > 0 then
                u := Copy(u, h + 1, Length(u))
            else begin
                u := '';
                Inc(Result);
            end;
        end;
        Result := Result - Length(u);
    end
    else if Count < 0 then begin
        Last := 0;
        for i := Length(t) downto 1 do begin
            u := Copy(t, i, Length(t));
            h := Pos(s, u);
            if (h <> 0) and ((h + i) <> Last) then begin
                Last := h + i - 1;
                Inc(count);
                if Count = 0 then
                    break;
            end;
        end;
        if Count = 0 then
            Result := Last
        else
            Result := 0;
    end
    else
        Result := 0;
end;

const
  UriProtocolSchemeAllowedChars : TCharSet = ['a'..'z','0'..'9','+','-','.'];

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ Syntax of an URL: protocol://[user[:password]@]server[:port]/path         }
procedure GpParseURL(
    const url : String;
    var Proto, User, Pass, Host, Port, Path : String);
var
    p, q, i : Integer;
    s       : String;
    CurPath : String;
begin
    CurPath := Path;
    proto   := '';
    User    := '';
    Pass    := '';
    Host    := '';
    Port    := '';
    Path    := '';

    if Length(url) < 1 then
        Exit;

    { Handle path beginning with "./" or "../".          }
    { This code handle only simple cases !               }
    { Handle path relative to current document directory }
    if (Copy(url, 1, 2) = './') then begin
        p := Posn('/', CurPath, -1);
        if p > Length(CurPath) then
            p := 0;
        if p = 0 then
            CurPath := '/'
        else
            CurPath := Copy(CurPath, 1, p);
        Path := CurPath + Copy(url, 3, Length(url));
        Exit;
    end
    { Handle path relative to current document parent directory }
    else if (Copy(url, 1, 3) = '../') then begin
        p := Posn('/', CurPath, -1);
        if p > Length(CurPath) then
            p := 0;
        if p = 0 then
            CurPath := '/'
        else
            CurPath := Copy(CurPath, 1, p);

        s := Copy(url, 4, Length(url));
        { We could have several levels }
        while TRUE do begin
            CurPath := Copy(CurPath, 1, p-1);
            p := Posn('/', CurPath, -1);
            if p > Length(CurPath) then
                p := 0;
            if p = 0 then
                CurPath := '/'
            else
                CurPath := Copy(CurPath, 1, p);
            if (Copy(s, 1, 3) <> '../') then
                break;
            s := Copy(s, 4, Length(s));
        end;

        Path := CurPath + Copy(s, 1, Length(s));
        Exit;
    end;

    p := pos('://', url);
    q := p;
    if p <> 0 then begin
        S := LowerCase(Copy(url, 1, p - 1));
        for i := 1 to Length(S) do begin
            if not (AnsiChar(S[i]) in UriProtocolSchemeAllowedChars) then begin
                q := i;
                Break;
            end;
        end;
        if q < p then begin
            p     := 0;
            proto := 'http';
        end;
    end;
    if p = 0 then begin
        if (url[1] = '/') then begin
            { Relative path without protocol specified }
            proto := 'http';
            //p     := 1;     { V6.05 }
            if (Length(url) > 1) then begin
                if (url[2] <> '/') then begin
                    { Relative path }
                    Path := Copy(url, 1, Length(url));
                    Exit;
                end
                else
                    p := 2;   { V6.05 }
            end
            else begin        { V6.05 }
                Path := '/';  { V6.05 }
                Exit;         { V6.05 }
            end;
        end
        else if LowerCase(Copy(url, 1, 5)) = 'http:' then begin
            proto := 'http';
            p     := 6;
            if (Length(url) > 6) and (url[7] <> '/') then begin
                { Relative path }
                Path := Copy(url, 6, Length(url));
                Exit;
            end;
        end
        else if LowerCase(Copy(url, 1, 7)) = 'mailto:' then begin
            proto := 'mailto';
            p := pos(':', url);
        end;
    end
    else begin
        proto := LowerCase(Copy(url, 1, p - 1));
        inc(p, 2);
    end;
    s := Copy(url, p + 1, Length(url));

    p := pos('/', s);
    q := pos('?', s);
    if (q > 0) and ((q < p) or (p = 0)) then
        p := q;
    if p = 0 then
        p := Length(s) + 1;
    Path := Copy(s, p, Length(s));
    s    := Copy(s, 1, p-1);

    { IPv6 URL notation, for instance "[2001:db8::3]" }
    p := Pos('[', s);
    q := Pos(']', s);
    if (p = 1) and (q > 1) then
    begin
        Host := Copy(s, 2, q - 2);
        s := Copy(s, q + 1, Length(s));
    end;

    p := Posn(':', s, -1);
    if p > Length(s) then
        p := 0;
    q := Posn('@', s, -1);
    if q > Length(s) then
        q := 0;
    if (p = 0) and (q = 0) then begin   { no user, password or port }
        if Host = '' then
            Host := s;
        Exit;
    end
    else if q < p then begin  { a port given }
        Port := Copy(s, p + 1, Length(s));
        if Host = '' then
            Host := Copy(s, q + 1, p - q - 1);
        if q = 0 then
            Exit; { no user, password }
        s := Copy(s, 1, q - 1);
    end
    else begin
        if Host = '' then
            Host := Copy(s, q + 1, Length(s));
        s := Copy(s, 1, q - 1);
    end;
    p := pos(':', s);
    if p = 0 then
        User := s
    else begin
        User := Copy(s, 1, p - 1);
        Pass := Copy(s, p + 1, Length(s));
    end;
end;

{$IFNDEF Win64}
function StrLCopyW(Dest: PWideChar; const Source: PWideChar; MaxLen: Cardinal): PWideChar; assembler;
asm
        PUSH    EDI
        PUSH    ESI
        PUSH    EBX
        MOV     ESI,EAX
        MOV     EDI,EDX
        MOV     EBX,ECX
        XOR     AX,AX
        TEST    ECX,ECX
        JZ      @@1
        REPNE   SCASW
        JNE     @@1
        INC     ECX
@@1:    SUB     EBX,ECX
        MOV     EDI,ESI
        MOV     ESI,EDX
        MOV     EDX,EDI
        MOV     ECX,EBX
        REP     MOVSD
        MOV     ECX,EBX
        AND     ECX,3
        REP     MOVSB
        STOSB
        MOV     EAX,EDX
        POP     EBX
        POP     ESI
        POP     EDI
end;
{$ENDIF ~Win64}

end.
