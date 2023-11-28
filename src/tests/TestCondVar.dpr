program TestCondVar;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  {$IFNDEF POSIX}
  Winapi.Windows,
  {$ENDIF }
  System.SysUtils,
  System.SyncObjs,
  GpSync.CondVar in '..\GpSync.CondVar.pas',
  TestGpSync.CondVar in 'TestGpSync.CondVar.pas';

const
  TestResult: array [boolean] of string = ('FAIL', 'OK');

begin
  try
{$IFDEF MSWINDOWS}
    var res1 := TestResult[TTestRTLCriticalSection.Test];
    var res2 := TestResult[TTestCriticalSection.Test];
    var res3 := TestResult[TTestSRWLock.Test];
    var res4 := TestResult[TTestLightweightMREW.Test];
{$ENDIF MSWINDOWS}
{$IFDEF POSIX}
    var res1 := TestResult[TTestPThreadMutex.Test];
    var res2 := TestResult[TTestMutex.Test];
{$ENDIF POSIX}
    var res5 := TestResult[TTestLockConditionVariable.Test];

    Writeln;
{$IFDEF MSWINDOWS}
    Writeln('TRTLCriticalSection', #9, res1);
    Writeln('TCriticalSection', #9, res2);
    Writeln('SRWLock', #9#9#9, res4);
    Writeln('TLightweightMREW', #9, res4);
{$ENDIF MSWINDOWS}
{$IFDEF POSIX}
    Writeln('pthread_mutex_t', #9#9, res1);
    Writeln('TMutex', #9#9#9, res2);
{$ENDIF POSIX}
    Writeln('TLockConditionVariable', #9, res5);
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
