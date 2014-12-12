unit testGpCommandLineParser1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, System.StrUtils,
  GpCommandLineParser;

type
  TCommandLine = class
  strict private
    FAutoTest  : boolean;
    FExtraFiles: string;
    FFromDate  : string;
    FImportDir : string;
    FInputFile : string;
    FNumDays   : integer;
    FOutputFile: string;
    FPrecision : string;
    FToDateTime: string;
  public
    [CLPLongName('ToDate'), CLPDescription('Set ending date/time', '<dt>')]
    property ToDateTime: string read FToDateTime write FToDateTime;

    [CLPDescription('Set precision'), CLPDefault('3.14')]
    property Precision: string read FPrecision write FPrecision;

    [CLPName('i'), CLPLongName('ImportDir'), CLPDescription('Set import folder', '<path>')]
    property ImportDir: string read FImportDir write FImportDir;

    [CLPName('a'), CLPLongName('AutoTest', 'Auto'), CLPDescription('Enable autotest mode. And now some long text for testing word wrap in Usage.')]
    property AutoTest: boolean read FAutoTest write FAutoTest;

    [CLPName('f'), CLPLongName('FromDate'), CLPDescription('Set starting date', '<dt>'), CLPRequired]
    property FromDate: string read FFromDate write FFromDate;

    [CLPName('n'), CLPDescription('Set number of days', '<days>'), CLPDefault('100')]
    property NumDays: integer read FNumDays write FNumDays;

    [CLPPosition(1), CLPDescription('Input file'), CLPLongName('input_file'), CLPRequired]
    property InputFile: string read FInputFile write FInputFile;

    [CLPPosition(2), CLPDescription('Output file'), CLPRequired]
    property OutputFile: string read FOutputFile write FOutputFile;

    [CLPPositionRest, CLPDescription('Extra files'), CLPName('extra_files')]
    property ExtraFiles: string read FExtraFiles write FExtraFiles;
  end;

  TfrmTestGpCommandLineParser = class(TForm)
    inpCommandLine: TLabeledEdit;
    btnParse: TButton;
    lbLog: TListBox;
    procedure btnParseClick(Sender: TObject);
  private
  public
  end;

var
  frmTestGpCommandLineParser: TfrmTestGpCommandLineParser;

implementation

uses
  Types;

{$R *.dfm}

procedure TfrmTestGpCommandLineParser.btnParseClick(Sender: TObject);
var
  cl    : TCommandLine;
  parsed: boolean;
begin
  lbLog.Items.Clear;
  cl := TCommandLine.Create;
  try
    try
      parsed := CommandLineParser.Parse(inpCommandLine.Text, cl);
    except
      on E: ECLPConfigurationError do begin
        lbLog.Items.Add('*** Configuration error ***');
        lbLog.Items.Add(Format('%s, position = %d, name = %s',
          [E.ErrorInfo.Text, E.ErrorInfo.Position, E.ErrorInfo.SwitchName]));
        Exit;
      end;
    end;

    if not parsed then begin
      lbLog.Items.Add(Format('%s, position = %d, name = %s',
        [CommandLineParser.ErrorInfo.Text, CommandLineParser.ErrorInfo.Position,
         CommandLineParser.ErrorInfo.SwitchName]));
      lbLog.Items.Add('');
      lbLog.Items.AddStrings(CommandLineParser.Usage);
    end
    else begin
      lbLog.Items.Add('InputFile: ' + cl.InputFile);
      lbLog.Items.Add('OutputFile: ' + cl.OutputFile);
      lbLog.Items.Add('ExtraFiles: ' + StringReplace(cl.ExtraFiles, #13, '/', [rfReplaceAll]));
      lbLog.Items.Add('ImportDir: ' + cl.ImportDir);
      lbLog.Items.Add('AutoTest: ' + BoolToStr(cl.AutoTest, true));
      lbLog.Items.Add('FromDate: ' + cl.FromDate);
      lbLog.Items.Add('ToDateTime: ' + cl.ToDateTime);
      lbLog.Items.Add('NumDays: ' + IntToStr(cl.NumDays));
      lbLog.Items.Add('Precision: ' + cl.Precision);
    end;
  finally cl.Free; end;
end;

end.
