program testGpCommandLineParser;

uses
  FastMM4,
  Vcl.Forms,
  testGpCommandLineParser1 in 'testGpCommandLineParser1.pas' {frmTestGpCommandLineParser},
  GpCommandLineParser in '..\GpCommandLineParser.pas';

{$R *.res}

begin
  Application.ModalPopupMode := pmAuto;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmTestGpCommandLineParser, frmTestGpCommandLineParser);
  Application.Run;
end.
