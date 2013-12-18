program proto_galaxygen;

uses
  Forms,
  FMain in 'FMain.pas' {MainForm},
  UGalaxyGen in 'UGalaxyGen.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
