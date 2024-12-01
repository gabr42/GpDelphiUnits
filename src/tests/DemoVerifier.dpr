program DemoVerifier;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  GpCommandLineParser in '..\GpCommandLineParser.pas';

type
  TOtherwiseInvalidType = String;

  TCommandLine = class
  strict private
    FMandatoryParam1      : String;
    FOptionalParam2       : String;
    FMode                 : String;
    FIgnoredValue         : TOtherwiseInvalidType;
    FValue1               : String;
    FValue2               : String;

    function CalculateSomeValue : String;
    function CLPVerifier: String;
  public
    [CLPPosition(1), CLPDescription('First parameter (mandatory)'), CLPRequired]
    property MandatoryParam: string read FMandatoryParam1 write FMandatoryParam1;

    [CLPPosition(2), CLPDescription('Second parameter (optional)')]
    property OptionalParam: string read FOptionalParam2 write FOptionalParam2;

    [CLPName('m'), CLPLongName('mode'), CLPDescription('A mode parameter ["mode1","mode2"]'), CLPDefault('mode1')]
    property Mode : String read FMode write FMode;

    [CLPName('1'), CLPLongName('value1'), CLPDescription('first custom value')]
    property Param1 : String read FValue1 write FValue1;

    [CLPName('2'), CLPLongName('value2'), CLPDescription('second custom value')]
    property Param2 : String read FValue2 write FValue2;

    // a [CLPVerifier] is called after the CommandLine object is populated and
    // allows to enforce rules based on the command line parameters.
    // Verifiers return some error description in case of error or '' if
    // everything is okay
    [CLPVerifier]
    property Verifier: String read CLPVerifier;

    // if not ignored, GpCommandLine would raise an exception because the return
    // type is invalid. Use [CLPIgnored] to do stuff with your parameters.
    [CLPIgnored]
    property IgnoredValue: TOtherwiseInvalidType read CalculateSomeValue;

  end;

function TCommandLine.CalculateSomeValue: TOtherwiseInvalidType;
begin
  Result := Format('Mode %s set with parameters 1: %s and 2: %s',
      [Mode, Param1, Param2]);
end;

// the Verifier returns a non-empty string in case of error and an empty
// string otherwise. Here are some examples:
function TCommandLine.CLPVerifier : String;
begin
  Result := '';

  // only "mode1" or "mode2" is allowed for /mode
  if(Mode <> 'mode1') and (Mode <> 'mode2') then
    Exit(Format('only "mode1" or "mode2" is allowed for /mode, "%s" given', [Mode]));

  // if mode is "mode1" we require the optional parameter
  if(Mode = 'mode1') and (OptionalParam = '') then
    Exit('"mode1" needs the optional parameter at position 2');

  // if mode is "mode2" we require both values but not the optional parameter
  if(Mode = 'mode2') then
  begin
    if(Param1 = '') or (Param2 = '') then
      Exit('"mode2" needs both /value1 and /value2');
    if(OptionalParam <> '') then
      Exit('"mode2" cannot have the optional parameter at position 2');
  end;

  // I think you get the idea :)
end;

VAR cl : TCommandLine;
begin
  try
    cl := TCommandLine.Create;
    try
        { Parse command line }
      if not CommandLineParser.Parse(cl) then
      Begin
        for var s : String in CommandLineParser.Usage do
          Writeln(s);

        WriteLn;
          // in this example the IgnoredValue is of type String but you can use any type
        WriteLn('Some ignored property: ' + cl.IgnoredValue);
          // here's the error information from the Validator(s)
        WriteLn('FAILED: ' + CommandLineParser.ErrorInfo.Text);
        WriteLn('Press Return...');
        ReadLn;
      End;
    finally
      cl.Free;
    end;

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.

