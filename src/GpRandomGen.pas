(*:RANMAR pseudo-random number generator
 This random number generator originally appeared in "Toward a Universal
 Random Number Generator" by George Marsaglia and Arif Zaman.
 Florida State University Report: FSU-SCRI-87-50 (1987)

 It was later modified by F. James and published in "A Review of Pseudo-
 random Number Generators"

 THIS IS THE BEST KNOWN RANDOM NUMBER GENERATOR AVAILABLE.
       (However, a newly discovered technique can yield
         a period of 10^600. But that is still in the development stage.)

 It passes ALL of the tests for random number generators and has a period
   of 2^144, is completely portable (gives bit identical results on all
   machines with at least 24-bit mantissas in the floating point
   representation).

 The algorithm is a combination of a Fibonacci sequence (with lags of 97
   and 33, and operation "subtraction plus one, modulo one") and an
   "arithmetic sequence" (using subtraction).
========================================================================
C language version was written by Jim Butler, and was based on a
FORTRAN program posted by David LaSalle of Florida State University.

Adapted for Delphi by Anton Zhuchkov (fireton@mail.ru) in February, 2002.

Converted into a class by Primoz Gabrijelcic (gabr@17slon.com) in November, 2002.

   @desc <pre>
   Free for personal and commercial use. No rights reserved.

   Programming       : Primoz Gabrijelcic
   Creation date     : 2002-11-17
   Last modification : 2018-01-15
   Version           : 2.0
</pre>*)(*
   History:
     2.0: 2018-01-15
       - Global functions are now threadsafe.
       - Microsoft Crypto API: Next Generation is used in Randomize.
     1.01: 2004-04-01
       - Added protected functions SaveState and RestoreState.
     1.0: 2002-11-17
       - Released.
*)

unit GpRandomGen;

interface

uses
  Classes;

const
  MaxRnd = 1073741822;

type
  TGpRandom = class
  private
    u: array [0..97] of double;
    c, cd, cm: double;
    i97, j97: integer;
  protected
    // intentionally hard to reach ...
    function  RestoreState(stream: TStream): boolean;
    procedure SaveState(stream: TStream);
  public
    //:Create and initialize with known seed.
    constructor Create(seed1, seed2: longint); overload;
    //:Create and initialize with pseudo-random seed (from the Delphi's generator).
    constructor Create; overload;
    //:Initialize generator with known seeds.
    procedure Randomize(seed1, seed2: longint); overload;
    //:Initialize generator with pseudo-random seeds (from the Delphi's generator).
    procedure Randomize; overload;
    //:Wrapper around Random that returns longwords.
    function  Rnd: longword;
    //:Wrapper around Random that returns int64s.
    function  Rnd64: int64;
    {:This is the random number generator proposed by George Marsaglia in
      Florida State University Report: FSU-SCRI-87-50}
    function  Random: double;
  end; { TGpRandom }

  procedure GpRandomize(seed1, seed2: longint); overload;
  procedure GpRandomize; overload;
  function  GpRnd: longword;
  function  GpRnd64: int64;
  function  GpRandom: double;

implementation

uses
  SysUtils,
  JwaBCrypt;

var
  GGpRandom: TGpRandom;

procedure GpRandomize(seed1, seed2: longint);
begin
  TMonitor.Enter(GGpRandom);
  try
    GGpRandom.Randomize(seed1, seed2);
  finally
    TMonitor.Exit(GGpRandom);
  end;
end; { GpRandomize }

procedure GpRandomize;
begin
  TMonitor.Enter(GGpRandom);
  try
    GGpRandom.Randomize;
  finally
    TMonitor.Exit(GGpRandom);
  end;
end; { GpRandomize }

function GpRnd: longword;
begin
  TMonitor.Enter(GGpRandom);
  try
    Result := GGpRandom.Rnd;
  finally
    TMonitor.Exit(GGpRandom);
  end;
end; { GpRnd }

function GpRnd64: int64;
begin
  TMonitor.Enter(GGpRandom);
  try
    Result := GGpRandom.Rnd64;
  finally
    TMonitor.Exit(GGpRandom);
  end;
end; { GpRnd64 }

function GpRandom: double;
begin
  TMonitor.Enter(GGpRandom);
  try
    Result := GGpRandom.Random;
  finally
    TMonitor.Exit(GGpRandom);
  end;
end; { GpRandom }

{ TGpRandom }

constructor TGpRandom.Create(seed1, seed2: Integer);
begin
  Randomize(seed1, seed2);
end; { TGpRandom.Create }

constructor TGpRandom.Create;
begin
  Randomize;
end; { TGpRandom.Create }

function TGpRandom.Random: double;
begin
  Result := u[i97] - u[j97];
  if (Result < 0.0) then
    Result := Result + 1.0;
  u[i97] := Result;
  Dec(i97);
  if i97 = 0 then
    i97 := 97;
  dec(j97);
  if j97 = 0 then
    j97 := 97;
  c := c - cd;
  if c < 0.0 then
    c := c + cm;
  Result := Result - c;
  if Result < 0.0 then
    Result := Result + 1.0;
end; { TGpRandom.Random }

procedure TGpRandom.Randomize;

  function CNGRandomize: boolean;
  const
    BCRYPT_USE_SYSTEM_PREFERRED_RNG = 2;
  var
    seed1: word;
    seed2: word;
  begin
    repeat
      if BCryptGenRandom(0, @seed1, SizeOf(seed1), BCRYPT_USE_SYSTEM_PREFERRED_RNG) <> 0 then
        Exit(false);
    until seed1 < 31329;
    repeat
      if BCryptGenRandom(0, @seed2, SizeOf(seed2), BCRYPT_USE_SYSTEM_PREFERRED_RNG) <> 0 then
        Exit(false);
    until seed2 < 30082;
    Randomize(seed1, seed2);
    Result := true;
  end; { CNGRandomize }

begin
  if not CNGRandomize then
    Randomize(System.Random(31329), System.Random(30082));
end; { TGpRandom.Randomize }

{:This is the initialization routine for the random number generator RANMAR()
  NOTE: The seed variables can have values between:    0 <= seed1 <= 31328
                                                       0 <= seed2 <= 30081
  The random number sequences created by these two seeds are of sufficient
  length to complete an entire calculation with. For example, if several
  different groups are working on different parts of the same calculation,
  each group could be assigned its own seed1 seed. This would leave each group
  with 30000 choices for the second seed. That is to say, this random
  number generator can create 900 million different subsequences -- with
  each subsequence having a length of approximately 10^30.

  Use seed1 = 1802 & seed2 = 9373 to test the random number generator. The
  subroutine RANMAR should be used to generate 20000 random numbers.
  Then display the next six random numbers generated multiplied by 4096*4096
  If the random number generator is working properly, the random numbers
  should be:
            6533892.0  14220222.0  7275067.0
            6172232.0  8354498.0   10633180.0
}
procedure TGpRandom.Randomize(seed1, seed2: integer);
var
  i, j, k, l, ii, jj, m : integer;
  s, t : double;
begin
  if (seed1<0) or (seed1>31328) or (seed2<0) or (seed2>30081) then
    raise Exception.Create('Random generator seed not within the valid range!');

  i := (seed1 div 177) mod 177 + 2;
  j := seed1 mod 177 + 2;
  k := (seed2 div 169) mod 178 + 1;
  l := seed2 mod 169;

  for ii := 1 to 97 do begin
    s := 0.0;
    t := 0.5;
    for jj := 1 to 24 do begin
      m := (((i*j) mod 179)*k) mod 179;
      i := j;
      j := k;
      k := m;
      l := (53*l + 1) mod 169;
      if ((l*m) mod 64 >= 32) then
        s := s + t;
      t := t*0.5;
    end;
    u[ii] := s;
  end;

  c := 362436.0 / 16777216.0;
  cd := 7654321.0 / 16777216.0;
  cm := 16777213.0 / 16777216.0;

  i97 := 97;
  j97 := 33;
end; { TGpRandom.Randomize }

{:Restores random generator internal state from the stream.
  @returns False if stream was too short.
  @since   2004-04-01
}        
function TGpRandom.RestoreState(stream: TStream): boolean;
begin
  Result := false;
  if stream.Read(u, Length(u)*SizeOf(double)) <> Length(u)*SizeOf(double) then Exit;
  if stream.Read(c, SizeOf(double)) <> SizeOf(double) then Exit;
  if stream.Read(cd, SizeOf(double)) <> SizeOf(double) then Exit;
  if stream.Read(cm, SizeOf(double)) <> SizeOf(double) then Exit;
  if stream.Read(i97, SizeOf(integer)) <> SizeOf(integer) then Exit;
  if stream.Read(j97, SizeOf(integer)) <> SizeOf(integer) then Exit;
  Result := true;
end; { TGpRandom.RestoreState }

function TGpRandom.Rnd: longword;
begin
  Result :=
    (Trunc((High(Word)+1)*Random) SHL 16) OR
     Trunc((High(Word)+1)*Random);
end; { TGpRandom.Rnd }

function TGpRandom.Rnd64: int64;
var
  r32: longword;
  r64: int64;
begin
  r32 := Rnd;
  Move(r32, r64, 4);
  r32 := Rnd;
  Move(r32, pointer(cardinal(@r64)+4)^, 4);
  Result := r64;
end; { TGpRandom.Rnd64 }

{:Saves random generator internal state to the stream.
  @since   2004-04-01
}        
procedure TGpRandom.SaveState(stream: TStream);
begin
  stream.Write(u, Length(u)*SizeOf(double));
  stream.Write(c, SizeOf(double));
  stream.Write(cd, SizeOf(double));
  stream.Write(cm, SizeOf(double));
  stream.Write(i97, SizeOf(integer));
  stream.Write(j97, SizeOf(integer));
end; { TGpRandom.SaveState }

initialization
  Randomize;
  GGpRandom := TGpRandom.Create;
finalization
  FreeAndNil(GGpRandom);
end.
