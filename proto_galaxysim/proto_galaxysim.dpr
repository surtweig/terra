program proto_galaxysim;

uses
  Forms,
  FMain in 'FMain.pas' {MainForm},
  UGalaxySim in 'UGalaxySim.pas',
  TUpdateGravity in 'TUpdateGravity.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
