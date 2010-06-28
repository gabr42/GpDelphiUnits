unit SafeMem;

(*
GetMem/FreeMem wrapper that checks for block overruns.
Written by Primoz Gabrijelcic. Free for personal and commercial use. No rights
reserved. May be freely modified and abused.

Tested with Delphi 3, should work without a change with Delphi 2 and 4.

Note:
If you work with typed pointers you'll have to typecast them to "pointer" like
this: FreeMem(pointer(somePointer));

Program history

  1.2: 1999-03-09
       - Configurable parameters

  1.1: 1998-10-21
       - New procedure: CheckMem (check live block for memory overrun)

  1.0: 1998-09-15
       - First published version
*)

interface

const
  buffer_area: integer = 2;    // number of longints on every side of allocation
  message_box: boolean = true; // show message box on error
  raise_error: boolean = true; // raise exception on error

  procedure GetMem(var p: pointer; size: integer);
  procedure FreeMem(var p: pointer);
  procedure CheckMem(p: pointer);

implementation

uses
  Windows,
  SysUtils;

  procedure Error(msg: string);
  begin
    if message_box then MessageBox(0,PChar(msg),'SafeMem error',MB_OK);
    if raise_error then raise Exception.Create(msg);
  end; { Error }

  procedure GetMem(var p: pointer; size: integer);
  var
    i: integer;
  begin
    Inc(size,4+2*4*buffer_area);
    System.GetMem(p,size);
    integer(p^) := size;
    for i := 1 to buffer_area do
      DWORD(pointer(integer(p)+4*i)^):= $DEAD1234;
    for i := 1 to buffer_area do
      DWORD(pointer(integer(p)+size-4*i)^) := $5678CAFE;
    p := pointer(integer(p)+4+4*buffer_area);
  end; { GetMem }

  procedure FreeMem(var p: pointer);
  begin
    if p = nil then Error('SafeMem: trying to free nil pointer!');
    CheckMem(p);
    System.FreeMem(pointer(integer(p)-4-4*buffer_area));
    p := nil;
  end; { FreeMem }

  procedure CheckMem(p: pointer);
  var
    size: integer;
    i   : integer;
  begin
    p := pointer(integer(p)-4-4*buffer_area);
    for i := 1 to buffer_area do
      if DWORD(pointer(integer(p)+4*i)^) <> $DEAD1234 then Error('SafeMem: block head overrun!');
    size := integer(p^);
    for i := 1 to buffer_area do
      if DWORD(pointer(integer(p)+size-4*i)^) <> $5678CAFE then Error('SafeMem: block tail overrun!');
  end; { CheckMem }

end.
 