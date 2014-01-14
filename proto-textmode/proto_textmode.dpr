program proto_textmode;

uses
  Forms,
  FMain in 'FMain.pas' {MainForm},
  UTextTerminal in 'UTextTerminal.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
