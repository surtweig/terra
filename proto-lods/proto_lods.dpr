program proto_lods;

uses
  Forms,
  FMain in 'FMain.pas' {MainForm},
  UImageTree in 'UImageTree.pas',
  ULargeGeometry in 'ULargeGeometry.pas',
  VectorGeometryEx in 'VectorGeometryEx.pas',
  UImageManager in 'UImageManager.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
