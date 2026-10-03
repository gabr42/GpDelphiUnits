program testGpEventBus;

uses
  Vcl.Forms,
  testGpEventBusMain in 'testGpEventBusMain.pas' {frmEventBusTest},
  GpEventBus in '..\GpEventBus.pas';

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmEventBusTest, frmEventBusTest);
  Application.Run;
end.
