program test_audiogen;

uses
  Forms,
  FMain in 'FMain.pas' {MainForm},
  UPrimes in 'UPrimes.pas',
  UMathEx in 'UMathEx.pas',
  UNoiseGenerators in 'UNoiseGenerators.pas',
  USignalPipeline in 'USignalPipeline.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
