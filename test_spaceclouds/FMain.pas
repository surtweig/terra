unit FMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, GLCoordinates, GLScene, GLWin32Viewer, GLCrossPlatform,
  BaseClasses, GLMaterial, GLCadencer, GLParticleFX, GLObjects, GLPerlinPFX, JPEG, VectorGeometry, Math, OpenGL1x, GLKeyboard,
  GLNavigator, VectorTypes, GLTexture;

const
     SpriteDistDecayStart = 10.0;
     SpriteDistDecayEnd = 2.0;
     FastNearDecayStart = 8.0;

     createDust = True;
     createStars = True;
     createFastNear = True;
     createHalo = True;
     createNucleus = True;

     dustCount = 5000;
     starsCount = 1000;
     fastNearCount = 5000;

     FastNearScale = 2;

     dustAlpha = 0.25;

type
  TForm1 = class(TForm)
    GLScene1: TGLScene;
    GLSceneViewer1: TGLSceneViewer;
    Camera: TGLCamera;
    GLCustomSpritePFXManager1: TGLCustomSpritePFXManager;
    GLCadencer1: TGLCadencer;
    GLMaterialLibrary1: TGLMaterialLibrary;
    DustContainer: TGLDummyCube;
    GLPerlinPFXManager1: TGLPerlinPFXManager;
    GLSprite1: TGLSprite;
    GLNavigator1: TGLNavigator;
    GLUserInterface1: TGLUserInterface;
    StarsContainer: TGLDummyCube;
    FastNearContainer: TGLDummyCube;
    CamAnchor: TGLDummyCube;
    GLNavigator2: TGLNavigator;
    procedure FormCreate(Sender: TObject);
    procedure GLCadencer1Progress(Sender: TObject; const deltaTime,
      newTime: Double);
    procedure GLSceneViewer1Click(Sender: TObject);

    procedure LoadMat(name : string; additive : boolean; modulate : boolean = false);
    procedure UpdateFastNear;
  private
    { Private declarations }
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

function UnitRand : single;
begin
     Result:= Random(100000)*0.00001;
end;

function UnitGauss : single;
begin
     Result:= RandG(0, 1);
end;

function UniformTorRand(vmin, vmax : single) : single;
var sign : single;

begin
     sign:= Random(2)*2-1;
     Result:= sign*(vmin + UnitRand*(vmax-vmin));
end;

function GenSpiral(p : single) : TVector3f;
var
     rad, angle, radV, angleV : single;

begin
     radV:= 10;
     angleV:= 2*pi*5;

     rad:= radV*p*p;
     angle:= angleV*p;

     Result[1]:= UnitGauss*0.25;

     Result[0]:= rad*cos(angle) + UnitGauss*0.3;
     Result[2]:= rad*sin(angle) + UnitGauss*0.3;
end;

procedure TForm1.LoadMat(name : string; additive : boolean; modulate : boolean = false);
begin
     with GLMaterialLibrary1.AddTextureMaterial(name, 'Data\'+name+'.jpg') do begin
          if additive then
               Material.BlendingMode:= bmAdditive
          else
               Material.BlendingMode:= bmTransparency;

          Material.Texture.ImageAlpha:= tiaAlphaFromIntensity;
          Material.Texture.TextureMode:= tmAdd;

          if modulate then begin
               Material.Texture.TextureMode:= tmModulate;
          end;
     end;
end;

procedure TForm1.FormCreate(Sender: TObject);
var i : integer;
    p : single;
begin
     LoadMat('gauss_perlin_darkenonly_256', false);
     LoadMat('gauss_perlin_mult_256', false);
     LoadMat('g128', true);
     LoadMat('g128_blue', true);
     LoadMat('g128_red', true);
     LoadMat('g256', false);
//     LoadMat('g128_yellow', true);
//     GLMaterialLibrary1.AddTextureMaterial('gauss2', 'Data/g64.jpg');

     // Galaxy dust
     if createDust then
     for i:= 1 to dustCount do begin
          with TGLSprite(DustContainer.AddNewChild(TGLSprite)) do begin
               Material.MaterialLibrary:= GLMaterialLibrary1;
               Material.LibMaterialName:= 'g256';//'gauss_perlin_mult_256';
               p:= i/dustCount;
               Position.SetPoint(GenSpiral(p));
               Width:= 1 + p*abs(UnitGauss);
               Height:= Width;
               Rotation:= UnitRand*pi;
               TagFloat:= (1-p)*dustAlpha;
          end;
     end;

     // Stars
     if createStars then
     for i:= 1 to starsCount do begin
          with TGLSprite(StarsContainer.AddNewChild(TGLSprite)) do begin
               Material.MaterialLibrary:= GLMaterialLibrary1;
               case Random(3) of
                    0:Material.LibMaterialName:= 'g128_blue';
                    1:Material.LibMaterialName:= 'g128';
                    2:Material.LibMaterialName:= 'g128_red';
               end;
               p:= i/starsCount;
               Position.SetPoint(GenSpiral(p));
               Width:= 0.015*abs(1+sqr(UnitGauss))/(p*p*p+1);
               Height:= Width;
          end;
     end;

     // Fast near dust
     if createFastNear then
     for i:= 1 to fastNearCount do begin
          with TGLSprite(FastNearContainer.AddNewChild(TGLSprite)) do begin
               Material.MaterialLibrary:= GLMaterialLibrary1;
               Material.LibMaterialName:= 'g128';//'gauss_perlin_mult_256';
               Position.SetPoint(2*SpriteDistDecayStart*(UnitRand*2-1), 2*SpriteDistDecayStart*(UnitRand*2-1), 2*SpriteDistDecayStart*(UnitRand*2-1));
               Width:= FastNearScale;
               Height:= Width;
          end;
     end;


     if createHalo then
     with TGLSprite(StarsContainer.AddNewChild(TGLSprite)) do begin
          Material.MaterialLibrary:= GLMaterialLibrary1;
          Material.LibMaterialName:= 'g128_blue';
          Position.SetPoint(0, 0, 0);
          Width:= 50;
          Height:= 20;
          AlphaChannel:= 0.5;
     end;

     if createNucleus then
     with TGLSprite(StarsContainer.AddNewChild(TGLSprite)) do begin
          Material.MaterialLibrary:= GLMaterialLibrary1;
          Material.LibMaterialName:= 'g128_red';
          Position.SetPoint(0, 0, 0);
          Width:= 5;
          Height:= 3;
          AlphaChannel:= 0.8;
     end;
end;

procedure TForm1.UpdateFastNear;
var i, j : integer;
    dist, density : single;
    camPos, newPos : TVector4f;
begin
     camPos:= Camera.AbsolutePosition;


     for i:= 0 to FastNearContainer.Count-1 do begin
          with TGLSprite(FastNearContainer.Children[i]) do begin
               dist:= VectorLength(VectorSubtract(AbsolutePosition, camPos));

               density:= 1;
               if abs(AbsolutePosition[1]) > 2 then
                    density:= 1/(1+abs(AbsolutePosition[1])-2);

               //dist:= VectorLength(camPos);
               if VectorLength(AbsolutePosition) > 160 then
                    density:= 0;//density / (1+0.2*(dist-150));

               if dist < FastNearDecayStart then
                    AlphaChannel:= ((FastNearDecayStart-dist)/FastNearDecayStart)*0.5*density
               else
                    AlphaChannel:= 0;

               if dist < FastNearDecayStart*0.5 then
                    AlphaChannel:= AlphaChannel * dist / (FastNearDecayStart*0.5);

               if dist >= 2*FastNearDecayStart then begin
                    AlphaChannel:= 0;
                    j:= Random(3);
                    newPos[j]:= UniformTorRand(FastNearDecayStart, 2*FastNearDecayStart);
                    newPos[(j+1) mod 3]:= FastNearDecayStart*(UnitRand*2-1);
                    newPos[(j+2) mod 3]:= FastNearDecayStart*(UnitRand*2-1);
                    newPos:= VectorAdd(camPos, newPos);
                    Position.SetPoint(newPos);
               end;
          end;
     end;
end;

procedure TForm1.GLCadencer1Progress(Sender: TObject; const deltaTime, newTime: Double);
var i : integer;
    dist, speed : single;
begin
     for i:= 0 to DustContainer.Count-1 do begin
          with TGLSprite(DustContainer.Children[i]) do begin
               dist:= VectorLength(VectorSubtract(AbsolutePosition, Camera.AbsolutePosition));
               Rotation:= Rotation + (deltaTime*i)*0.01/Width;
               AlphaChannel:= (lerp(0, 1, (dist-SpriteDistDecayEnd)/(SpriteDistDecayStart-SpriteDistDecayEnd)));
               AlphaChannel:= AlphaChannel*TagFloat;
          end;
     end;

     UpdateFastNear;
     
     if IsKeyDown(VK_ESCAPE) then
          GLUserInterface1.MouseLookDeactivate;

     if IsKeyDown(VK_SHIFT) then
          speed:= 20
     else
          speed:= 2;

     if IsKeyDown('w') then
          GLNavigator1.MoveForward(deltaTime*speed);
     if IsKeyDown('s') then
          GLNavigator1.MoveForward(-deltaTime*speed);
     if IsKeyDown('a') then
          GLNavigator1.StrafeHorizontal(-deltaTime*speed);
     if IsKeyDown('d') then
          GLNavigator1.StrafeHorizontal(deltaTime*speed);

     CamAnchor.Direction.SetVector(Camera.Direction.AsVector);
     CamAnchor.Up.SetVector(Camera.Up.AsVector);
     Camera.Position.SetPoint(VectorLerp(Camera.Position.AsVector, CamAnchor.Position.AsVector, 1-exp(-deltaTime)));

     GLUserInterface1.MouseUpdate;
     GLUserInterface1.MouseLook;
end;

procedure TForm1.GLSceneViewer1Click(Sender: TObject);
begin
     GLUserInterface1.MouseLookActivate;
end;

end.
