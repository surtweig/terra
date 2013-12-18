program test_subdivision;

uses
  Forms,
  FMain in 'FMain.pas' {MainForm},
  UGeosphere in 'UGeosphere.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
