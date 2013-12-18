unit FMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, GLWin32Viewer, GLCadencer, GLCrossPlatform, BaseClasses, GLScene,
  GLCoordinates, ULargeGeometry, XPMan, StdCtrls, Math, DateUtils, UImageTree,
  GLObjects, OpenGL1x, GLRenderContextInfo, VectorGeometryEx, VectorGeometry,
  GLKeyboard, GLPolyhedron;

type
  TMainForm = class(TForm)
    Scene: TGLScene;
    Cadencer: TGLCadencer;
    Viewer: TGLSceneViewer;
    Camera: TGLCamera;
    XPManifest1: TXPManifest;
    LevelsContainer: TGLDummyCube;
    LightSource1: TGLLightSource;
    Memo1: TMemo;
    Label1: TLabel;
    GLIcosahedron1: TGLIcosahedron;
    procedure FormCreate(Sender: TObject);
    procedure CadencerProgress(Sender: TObject; const deltaTime,
      newTime: Double);
  private
    { Private declarations }
  public
    procedure ClearZBuffer(Sender: TObject; var rci: TRenderContextInfo);
    procedure GenerateUniverse;
    procedure BuildSphere(container : TTOImageContainer; position : TTOVector; radius : single);
    procedure BuildSpheresTree(node : TTOImageNode; levelsLeft : integer);

    procedure UpdateDebugLabel;
  end;

var
  MainForm: TMainForm;
  universe : TTORootNode;
  transport : TTOTransportNode;

implementation

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
var conList : TTOImageContainersList;
    i : integer;

begin
     setlength(conList, 7);
     for i:= 0 to high(conList) do begin
          conList[i]:= TTOImageContainer(LevelsContainer.AddNewChild(TTOImageContainer));
          TGLDirectOpenGL(LevelsContainer.AddNewChild(TGLDirectOpenGL)).OnRender:= ClearZBuffer;
     end;

     universe:= TTORootNode.Create(0, conList);
     universe.SetBoundingSphereRadius(100);
     transport:= TTOTransportNode.Create(universe, LevelScale, 10, 3);
     transport.CreateChildren;
     universe.ObserverNode:= transport.Passenger;

     transport.SetPosition(4, 0, 0);
     GenerateUniverse;
     universe.UpdateImage;
end;

procedure TMainForm.GenerateUniverse;
var i: integer;
    vNode : TTOVisibleNode;

begin
     vNode:= TTOVisibleNode.Create(universe);
     //vNode.BuildImage;
     //BuildSphere(vNode.Image, AffineDoubleVectorMake(0, 0, 0), 3);
     try
          BuildSpheresTree(vNode, 3);
     except
     end;
end;

procedure TMainForm.BuildSphere(container : TTOImageContainer; position : TTOVector; radius : single);
var s : TGLSphere;

begin
     s:= TGLSphere(container.AddNewChild(TGLSphere));
     s.Position.SetPoint(AffineVectorMake(position));
     s.Radius:= radius;
     s.Slices:= 32;
     s.Stacks:= 32;
    // s.ShowAxes:= true;
end;

procedure TMainForm.BuildSpheresTree(node : TTOImageNode; levelsLeft : integer);
var i: integer;
    newNode : TTOVisibleNode;
    d : double;

begin
     Memo1.Lines.Add('BuildSpheresTree : levelsLeft = ' + IntToStr(levelsLeft));
     if levelsLeft > 0 then begin
          node.BuildImage;
          BuildSphere(node.Image, AffineVectorMake(0, 0, 0), 1);

          d:= 6;
          for i:= 1 to 30 do begin
               newNode:= TTOVisibleNode.Create(node);
               newNode.SetScale(LevelScale);
               newNode.SetPosition(15+i*10, 0, 0);
               BuildSpheresTree(newNode, levelsLeft-1);
          end;
     end;
end;

procedure TMainForm.ClearZBuffer(Sender: TObject; var rci: TRenderContextInfo);
begin
     glClear(GL_DEPTH_BUFFER_BIT);
end;

procedure TMainForm.CadencerProgress(Sender: TObject; const deltaTime, newTime: Double);
var pos : TTOVector;
    step : TTORelativeVector;
    speed : TTOFloat;
    i : integer;

begin
     pos:= transport.Position;

     if IsKeyDown(VK_LSHIFT) then begin
          step.basis:= transport.Passenger.Parent.Parent;
          speed:= 1;
     end else begin
          step.basis:= transport;
          speed:= 0.1;
     end;

     step.vector:= AffineVectorMake(0, 0, 0);

     if IsKeyDown(VK_UP) then
          //pos[0]:= pos[0] - 0.1*deltaTime;
          step.vector[0]:= -speed*deltaTime;

     if IsKeyDown(VK_DOWN) then
          //pos[0]:= pos[0] + 0.1*deltaTime;
          step.vector[0]:= speed*deltaTime;

     if IsKeyDown(VK_LEFT) then
          //pos[2]:= pos[2] + 0.1*deltaTime;
          step.vector[2]:= speed*deltaTime;

     if IsKeyDown(VK_RIGHT) then
          //pos[2]:= pos[2] - 0.1*deltaTime;
          step.vector[2]:= -speed*deltaTime;

     //transport.SetPosition(pos);
     transport.Move(step);

     UpdateDebugLabel;

     universe.UpdateImage;
     Viewer.Invalidate;
end;


procedure TMainForm.UpdateDebugLabel;
var node : TTOImageNode;
    s : string;

begin
     s:= '';
     node:= transport.Passenger;
     while node.Level >= transport.Level do begin
          s:= s + FloatToStr(node.Position[0]) + '   ';
          node:= node.Parent;
     end;
     Label1.Caption:= s;
end;

end.
