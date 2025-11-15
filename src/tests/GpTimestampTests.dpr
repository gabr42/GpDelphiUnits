program GpTimestampTests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  {$ENDIF }
  DUnitX.TestFramework,
  GpTimestamp in '..\GpTimestamp.pas',
  GpTimestamp.UnitTests in '..\GpTimestamp.UnitTests.pas';

{$IFNDEF TESTINSIGHT}
var
  runner: ITestRunner;
  results: IRunResults;
  logger: ITestLogger;
{$ENDIF}

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  try
    // Create the test runner
    runner := TDUnitX.CreateRunner;

    // Create console logger
    logger := TDUnitXConsoleLogger.Create(True);
    runner.AddLogger(logger);

    // Run tests
    WriteLn('Running GpTimestamp Unit Tests');
    WriteLn('==============================');
    WriteLn;

    results := runner.Execute;

    // Display results
    WriteLn;
    WriteLn('Tests completed.');
    WriteLn('Total:  ', results.TestCount);
    WriteLn('Passed: ', results.PassCount);
    WriteLn('Failed: ', results.FailureCount);
    WriteLn('Errors: ', results.ErrorCount);

    if results.FailureCount > 0 then
    begin
      WriteLn;
      WriteLn('FAILURES:');
      WriteLn(results.ToString);
    end;

    // Keep console window open
    WriteLn;
    WriteLn('Press ENTER to exit...');
    ReadLn;

    // Set exit code based on test results
    if results.FailureCount > 0 then
      ExitCode := 1
    else
      ExitCode := 0;

  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: ', E.ClassName, ': ', E.Message);
      ReadLn;
      ExitCode := 2;
    end;
  end;
{$ENDIF}
end.
