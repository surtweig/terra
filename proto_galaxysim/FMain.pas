unit FMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, GLScene, GLObjects, GLCoordinates, GLWin32Viewer, GLCadencer,
  GLCrossPlatform, BaseClasses, VectorGeometry, VectorTypes, UGalaxySim;

type
  TMainForm = class(TForm)
    Scene: TGLScene;
    Cadencer: TGLCadencer;
    Viewer: TGLSceneViewer;
    Camera: TGLCamera;
    MassSystem: TGLDummyCube;
    GLLines1: TGLLines;
    Points: TGLPoints;
    procedure FormCreate(Sender: TObject);
    procedure CadencerProgress(Sender: TObject; const deltaTime,
      newTime: Double);
  private
    { Private declarations }
  public
    procedure UpdateImage;
  end;

var
  MainForm: TMainForm;
  msys : TMassSphereSystem;

  DrawTraces : boolean = false;
  traj : array of TGLLines;

implementation

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
var i : integer;
    pt : TMassPoint;
begin
     msys:= TMassSphereSystem.Create;
     msys.GenerateSphere(1000, 1, 25);

     if DrawTraces then
          setlength(traj, msys.Count);

     Points.Positions.Count:= msys.Count;
     Points.Colors.Count:= msys.Count;

     for i:= 0 to msys.Count-1 do begin
          pt:= msys.GetPoint(i);
          
          if DrawTraces then begin
               traj[i]:= TGLLines(MassSystem.AddNewChild(TGLLines));

               with traj[i] do begin
                    Antialiased:= false;
                    NodesAspect:= lnaInvisible;
                    AddNode(pt.PrevPosition);
                    AddNode(pt.Position);
               end;
          end;

          Points.Positions.Items[i]:= pt.Position;
          Points.Colors.Items[i]:= VectorMake(1, 1, 1, 1);//ln(pt.Mass));
     end;
end;

procedure TMainForm.UpdateImage;
var i : integer;
    pt : TMassPoint;

begin
     for i:= 0 to msys.Count-1 do begin
          pt:= msys.GetPoint(i);

          if DrawTraces then begin
               traj[i].Nodes.Items[0].AsAffineVector:= pt.PrevPosition;
               traj[i].Nodes.Items[1].AsAffineVector:= pt.Position;
          end;

          Points.Positions.Items[i]:= pt.Position;
     end;
end;

procedure TMainForm.CadencerProgress(Sender: TObject; const deltaTime, newTime: Double);
begin
     msys.Impulse(0.01);
     UpdateImage;
     Viewer.Invalidate;
end;

end.
