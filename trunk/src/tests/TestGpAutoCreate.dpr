program TestGpAutoCreate;

uses
  Vcl.Forms,
  testGpAutoCreate1 in 'testGpAutoCreate1.pas' {frmTestGpAutoCreate},
  GpAutoCreate in '..\GpAutoCreate.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := true;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmTestGpAutoCreate, frmTestGpAutoCreate);
  Application.Run;
end.
