unit FMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, UGalaxyGen, GLScene, GLObjects, GLCoordinates, GLCadencer,
  GLWin32Viewer, GLCrossPlatform, BaseClasses, JPEG, GLMaterial, GLImposter;

type
  TMainForm = class(TForm)
    Scene: TGLScene;
    Viewer: TGLSceneViewer;
    Cadencer: TGLCadencer;
    Camera: TGLCamera;
    Galaxy: TGLDummyCube;
    GLLines1: TGLLines;
    GLCamera1: TGLCamera;
    GLMaterialLibrary1: TGLMaterialLibrary;
    procedure FormCreate(Sender: TObject);
    procedure CadencerProgress(Sender: TObject; const deltaTime,
      newTime: Double);
  private
    { Private declarations }
  public
    procedure BuildGalaxyNode(node : TGalaxyAbstractNode);
  end;

var
  MainForm: TMainForm;
  groot : TGalaxyRootNode;
  starsCounter : integer = 0;

implementation

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
begin
     Randomize;
     groot:= TGalaxyRootNode.Create;
     groot.Procreate;
     groot.Shake(0.03);

     BuildGalaxyNode(groot);
end;

procedure TMainForm.BuildGalaxyNode(node : TGalaxyAbstractNode);
var i : integer;
    c : single;
begin
     for i:= 0 to node.Count-1 do
          BuildGalaxyNode(node.GetChild(i));

     if node.Parent <> nil then begin
        {  with TGLLines(Galaxy.AddNewChild(TGLLines)) do begin
               Antialiased:= true;
               NodesAspect:= lnaInvisible;
               //NodesAspect:= lnaCube;
               c:= 1.0/node.Level;
               LineColor.SetColor(c, c, c);
               Nodes.AddNode(node.Parent.Position);
               NodeColor.SetColor(1, 1, 0);
               NodeSize:= 0.25;
              // TGLLinesNode(Nodes.Items[0]).Color.SetColor(0, 0, 0, 0);
               Nodes.AddNode(node.Position);
              // TGLLinesNode(Nodes.Items[1]).Color.SetColor(1, 1, 0);
          end;}
          with TGLSprite(Galaxy.AddNewChild(TGLSprite)) do begin
               Material.MaterialLibrary:= GLMaterialLibrary1;
               if node.Level <= 2 then
                    Material.LibMaterialName:= 'star-red';
               if node.Level = 3 then
                    Material.LibMaterialName:= 'star';
               if node.Level = 4 then
                    Material.LibMaterialName:= 'star';
               Width:= 1/node.Level;
               Height:= 1/node.Level;
               Position.SetPoint(node.Position);

               starsCounter:= starsCounter + 1;
          end;
     end;
     
     Caption:= IntToStr(starsCounter);
end;

procedure TMainForm.CadencerProgress(Sender: TObject; const deltaTime,
  newTime: Double);
begin
   //  Galaxy.Pitch(deltaTime*10);
end;

end.
