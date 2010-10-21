program testGpStringHash;

uses
  FastMM4,
  Forms,
  testGpStringHash1 in 'testGpStringHash1.pas' {frmTestGpStringHash};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmTestGpStringHash, frmTestGpStringHash);
  Application.Run;
end.
