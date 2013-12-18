unit FMain;

interface

uses
	Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
	Dialogs, GLScene, GLMesh, GLCoordinates, GLCadencer, GLWin32Viewer,
	GLCrossPlatform, BaseClasses, VectorTypes, VectorGeometry, GLState, Math,
   GLMaterial, UGeosphere, GLzBuffer, GLKeyboard, GLObjects, JPEG,
   GLCustomShader, GLSLShader, GLFBORenderer, GLContext, GLRenderContextInfo, OpenGLTokens, GLUtils;

const
	A = 0.5;
	B = 0.30901699437; // 1/(1+Sqrt(5))

	Vertices: array [0 .. 11] of TAffineVector = ((X: 0; Y: - B; Z: - A),
		(X: 0; Y: - B; Z: A), (X: 0; Y: B; Z: - A), (X: 0; Y: B; Z: A), (X: - A;
		Y: 0; Z: - B), (X: - A; Y: 0; Z: B), (X: A; Y: 0; Z: - B), (X: A; Y: 0;
		Z: B), (X: - B; Y: - A; Z: 0), (X: - B; Y: A; Z: 0), (X: B; Y: - A; Z: 0),
		(X: B; Y: A; Z: 0));
	Triangles: array [0 .. 19] of array [0 .. 2]
		of Byte = ((2, 9, 11), (3, 11, 9), (3, 5, 1), (3, 1, 7), (2, 6, 0),
		(2, 0, 4), (1, 8, 10), (0, 10, 8), (9, 4, 5), (8, 5, 4), (11, 7, 6),
		(10, 6, 7), (3, 9, 5), (3, 7, 11), (2, 4, 9), (2, 11, 6), (0, 8, 4),
		(0, 6, 10), (1, 5, 8), (1, 10, 7));

type
	TMainForm = class(TForm)
		Scene: TGLScene;
		Viewer: TGLSceneViewer;
		Cadencer: TGLCadencer;
		Camera: TGLCamera;
		Mesh: TGLMesh;
		Light: TGLLightSource;
    Matlib: TGLMaterialLibrary;
    Walker: TGLDummyCube;
    WalkerCamera: TGLCamera;
    ShadowShader: TGLSLShader;
    ShadowFBORenderer: TGLFBORenderer;
    Root: TGLDummyCube;
    PrepareShadowMapping: TGLDirectOpenGL;
    ShadowCamera: TGLCamera;
		procedure FormCreate(Sender: TObject);
		procedure CadencerProgress(Sender: TObject; const deltaTime,
			newTime: Double);
    procedure ShadowShaderApply(Shader: TGLCustomGLSLShader);
    procedure PrepareShadowMappingRender(Sender: TObject;
      var rci: TRenderContextInfo);
    procedure ShadowShaderInitialize(Shader: TGLCustomGLSLShader);
    procedure ShadowFBORendererBeforeRender(Sender: TObject;
      var rci: TRenderContextInfo);
    procedure ShadowFBORendererAfterRender(Sender: TObject;
      var rci: TRenderContextInfo);
	private
    FBiasMatrix: TMatrix;
    FLightModelViewMatrix: TMatrix;
    FLightProjMatrix: TMatrix;
    FInvCameraMatrix: TMatrix;
    FEyeToLightMatrix: TMatrix;
	public
		{ Public declarations }
	end;

var
	MainForm: TMainForm;
	subvert : array of TVector3f;
	geo : TGeosphere;

implementation

{$R *.dfm}

function transform(v : TVector3f) : TVector3f;
var phi, theta : single;
begin
	theta:= arctan(sqrt(v.X*v.X + v.Y*v.Y) / v.Z);
	phi:= arctan(v.Y/v.X);
	//RandSeed:= round(v.X*100) * round(v.Y*100) * round(v.Z*100) + round(v.X*100) + round(v.Y*100) + round(v.Z*100);
	Result:= v;//VectorScale(v, 1 + 0.02*sin(theta*30));
end;

procedure subdivide(a, b, c : TVector3f; level : integer);
var i : integer;
    ab, bc, ca : TVector3f;
begin
   if level = 0 then begin
		i:= length(subvert);
	   setlength(subvert, i+3);
   	subvert[i]:= transform(a);
	   subvert[i+1]:= transform(b);
   	subvert[i+2]:= transform(c);
	end;

   if level > 0 then begin
		ab:= VectorAdd(a, b);
      NormalizeVector(ab);
     // ScaleVector(ab, 1.3);

		bc:= VectorAdd(b, c);
      NormalizeVector(bc);
      //ScaleVector(bc, 1.3);

		ca:= VectorAdd(c, a);
      NormalizeVector(ca);
      //ScaleVector(ca, 1.3);

      subdivide(a, ab, ca, level-1);
      subdivide(b, bc, ab, level-1);
      subdivide(c, ca, bc, level-1);
      subdivide(ab, bc, ca, level-1);
   end;
end;

procedure TMainForm.CadencerProgress(Sender: TObject; const deltaTime,
  newTime: Double);
begin

	Mesh.Turn(deltaTime*5);
	Mesh.Pitch(deltaTime);

	if IsKeyDown(VK_LEFT) then
		Mesh.Turn(deltaTime*60);

	if IsKeyDown(VK_RIGHT) then
		Mesh.Turn(-deltaTime*60);

	if IsKeyDown(VK_UP) then
		Mesh.Pitch(deltaTime*60);

	if IsKeyDown(VK_DOWN) then
		Mesh.Pitch(-deltaTime*60);

	if IsKeyDown('w') then
      Camera.Translate(0, 0, 10*deltaTime);

	if IsKeyDown('s') then
      Camera.Translate(0, 0, -10*deltaTime);

   Viewer.Invalidate;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
	n : TVector3f;
   vi, ti : integer;

begin
	ShadowShader.VertexProgram.LoadFromFile('shadowmap_vp.glsl');
	ShadowShader.FragmentProgram.LoadFromFile('shadowmap_fp.glsl');
	ShadowShader.Enabled := true;

   FBiasMatrix := CreateScaleAndTranslationMatrix(VectorMake(0.5, 0.5, 0.5), VectorMake(0.5, 0.5, 0.5));

   setlength(subvert, 0);
	{for ti:= 0 to high(Triangles) do begin
   	n:= CalcPlaneNormal(Vertices[Triangles[ti][0]], Vertices[Triangles[ti][1]], Vertices[Triangles[ti][2]]);
      for vi := 0 to 2 do begin
      	//n:= Vertices[Triangles[ti][vi]];
         //NormalizeVector(n);
      	Mesh.Vertices.AddVertex(Vertices[Triangles[ti][vi]], n);
      end;
   end;}

   //for ti := 0 to high(Triangles) do
   //	subdivide(VectorNormalize(Vertices[Triangles[ti][0]]), VectorNormalize(Vertices[Triangles[ti][1]]), VectorNormalize(Vertices[Triangles[ti][2]]), 3);

	geo:= TGeosphere.Create(8);
	setlength(subvert, geo.TrianglesCount*3);
	for vi:= 0 to high(subvert) do
		subvert[vi]:= geo.GetVertex(vi);

	Mesh.Vertices.Clear;
   for vi := 0 to high(subvert) do
      Mesh.Vertices.AddVertex(subvert[vi], geo.GetNormal(vi));

   //Mesh.CalcNormals(fwClockWise);
   Caption:= 'tris:'+IntToStr(length(subvert) div 3) + ' nodes:' + IntToStr(geo.NodesCount);
   setlength(subvert, 0);
end;

procedure TMainForm.PrepareShadowMappingRender(Sender: TObject; var rci: TRenderContextInfo);
begin
  // prepare shadow mapping matrix
  FInvCameraMatrix := rci.PipelineTransformation.InvModelViewMatrix;
  // go from eye space to light's "eye" space
  FEyeToLightMatrix := MatrixMultiply(FInvCameraMatrix, FLightModelViewMatrix);
  // then to clip space
  FEyeToLightMatrix := MatrixMultiply(FEyeToLightMatrix, FLightProjMatrix);
  // and finally make the [-1..1] coordinates into [0..1]
  FEyeToLightMatrix := MatrixMultiply(FEyeToLightMatrix, FBiasMatrix);
end;

procedure TMainForm.ShadowFBORendererAfterRender(Sender: TObject; var rci: TRenderContextInfo);
begin
  rci.GLStates.Disable(stPolygonOffsetFill);
end;

procedure TMainForm.ShadowFBORendererBeforeRender(Sender: TObject; var rci: TRenderContextInfo);
begin
  // get the modelview and projection matrices from the light's "camera"
  with rci.PipelineTransformation do
  begin
    FLightModelViewMatrix := ModelViewMatrix;
    FLightProjMatrix := ProjectionMatrix;
  end;

  // push geometry back a bit, prevents false self-shadowing
  with rci.GLStates do
  begin
    Enable(stPolygonOffsetFill);
    PolygonOffsetFactor := 1;
    PolygonOffsetUnits := 1;
  end;
end;

procedure TMainForm.ShadowShaderApply(Shader: TGLCustomGLSLShader);
begin
  with Shader, Matlib do
  begin
    Param['ShadowMap'].AsTexture2D[0] := TextureByName(ShadowFBORenderer.DepthTextureName);
    Param['Scale'].AsFloat := 300.0;
    Param['Softly'].AsInteger := 1;
    Param['EyeToLightMatrix'].AsMatrix4f := FEyeToLightMatrix;
  end;
end;

procedure TMainForm.ShadowShaderInitialize(Shader: TGLCustomGLSLShader);
begin
  with Shader, Matlib do
  begin
    Param['ShadowMap'].AsTexture2D[0] := TextureByName(ShadowFBORenderer.DepthTextureName);
    //Param['LightPosition'].AsVector4f := ShadowCamera.Position.AsVector;
  end;
end;

end.
