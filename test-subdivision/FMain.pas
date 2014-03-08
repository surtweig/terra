unit FMain;

interface

uses
	Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
	Dialogs, GLScene, GLMesh, GLCoordinates, GLCadencer, GLWin32Viewer,
	GLCrossPlatform, BaseClasses, VectorTypes, VectorGeometry, GLState, Math,
   GLMaterial, UGeosphere, GLzBuffer, GLKeyboard, GLObjects, JPEG,
   GLCustomShader, GLSLShader, GLFBORenderer, GLContext, GLRenderContextInfo, OpenGLTokens, GLUtils,
  GLNavigator, ExtCtrls, StdCtrls, ComCtrls, Types, GLColor, GLAsmShader,
  GLPhongShader, GLSLDiffuseSpecularShader, GLTexture, GR32, GR32_Image;

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
    WalkerSphere: TGLSphere;
    SphereA: TGLSphere;
    SphereB: TGLSphere;
    SphereC: TGLSphere;
    Stars: TGLDummyCube;
    Sun: TGLSprite;
    Navigator: TGLNavigator;
    UserInterface: TGLUserInterface;
    ConfigPanel: TPanel;
    ShadowsComboBox: TComboBox;
    Label1: TLabel;
    Label2: TLabel;
    TerrainComboBox: TComboBox;
    CratersComboBox: TComboBox;
    Label3: TLabel;
    Label4: TLabel;
    MountainsComboBox: TComboBox;
    NoiseComboBox: TComboBox;
    Label5: TLabel;
    StartBtn: TButton;
    Label6: TLabel;
    CanyonsComboBox: TComboBox;
    ProgressBar: TProgressBar;
    GeoContainer: TGLDummyCube;
    GLSLDiffuseSpecularShader1: TGLSLDiffuseSpecularShader;
    ProgressMemo: TMemo;
		procedure FormCreate(Sender: TObject);
		procedure CadencerProgress(Sender: TObject; const deltaTime,
			newTime: Double);
    procedure PrepareShadowMappingRender(Sender: TObject;
      var rci: TRenderContextInfo);
    procedure ShadowFBORendererBeforeRender(Sender: TObject;
      var rci: TRenderContextInfo);
    procedure ShadowFBORendererAfterRender(Sender: TObject;
      var rci: TRenderContextInfo);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure WalkerProgress(Sender: TObject; const deltaTime, newTime: Double);
    procedure StartBtnClick(Sender: TObject);
    procedure ShadowShaderApplyEx(Shader: TGLCustomGLSLShader; Sender: TObject);
    procedure ShadowShaderInitializeEx(Shader: TGLCustomGLSLShader;
      Sender: TObject);
	private
    FBiasMatrix: TMatrix;
    FLightModelViewMatrix: TMatrix;
    FLightProjMatrix: TMatrix;
    FInvCameraMatrix: TMatrix;
    FEyeToLightMatrix: TMatrix;
	public
		procedure CreateGeo;
		procedure CreateStars;
	end;

var
	MainForm: TMainForm;
	subvert : array of TVector3f;
	geo : TGeosphere;
	submeshes : array of TGLMesh;

	Subdivisions, CratersCount, MountainsCount, CanyonsCount : integer;
	NoiseFactor : single;

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

procedure geoProgress(progress : single; msg : string);
begin
	MainForm.ProgressBar.Position:= round(progress*100);
	MainForm.ProgressMemo.Lines.Add(msg);
	Application.ProcessMessages;
end;

procedure TMainForm.CadencerProgress(Sender: TObject; const deltaTime,
  newTime: Double);
begin

	//Mesh.Turn(deltaTime*1);
	//Mesh.Pitch(deltaTime);

	if IsKeyDown(VK_LEFT) then
		GeoContainer.Turn(deltaTime*30);

	if IsKeyDown(VK_RIGHT) then
		GeoContainer.Turn(-deltaTime*30);

	if IsKeyDown(VK_UP) then
		GeoContainer.Pitch(deltaTime*30);

	if IsKeyDown(VK_DOWN) then
		GeoContainer.Pitch(-deltaTime*30);

   if Viewer.Camera = Camera then begin
	 	if IsKeyDown('w') then
   	   Camera.Translate(0, 0, 10*deltaTime);

		if IsKeyDown('s') then
   	   Camera.Translate(0, 0, -10*deltaTime);
   end;

	if IsKeyDown('1') then begin
		Viewer.Camera:= WalkerCamera;
		UserInterface.MouseLookActivate;
		WalkerSphere.Visible:= false;
   end;

	if IsKeyDown('2') then begin
		Viewer.Camera:= Camera;
		UserInterface.MouseLookDeactivate;
		WalkerSphere.Visible:= true;
   end;

	//Caption:= FloatToStr(geo.GetHeightAtPoint(AffineVectorMake(mesh.AbsoluteToLocal(Camera.Position.AsVector))));

   Viewer.Invalidate;
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
// 	Matlib.Materials.GetLibMaterialByName('shadow').Material.Texture.Image.AsBitmap.SaveToFile('shadowmap.bmp');
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
	n : TVector3f;

begin

	FBiasMatrix := CreateScaleAndTranslationMatrix(VectorMake(0.5, 0.5, 0.5), VectorMake(0.5, 0.5, 0.5));

	Sun.Position:= ShadowCamera.Position;
end;

procedure TMainForm.CreateGeo;
var vi, ti, mi, i : integer;
	 geomesh : TGeoMesh;
	 submesh :TGLMesh;
	 vd : TVertexData;

	 blankmat : TGLMaterial;
	 bmp32 : TBitmap32;
begin
	setlength(subvert, 0);
	geo:= TGeosphere.Create(Subdivisions, NoiseFactor, CratersCount, MountainsCount, CanyonsCount, geoProgress);
	{setlength(subvert, geo.TrianglesCount*3);
	for vi:= 0 to high(subvert) do
		subvert[vi]:= geo.GetVertex(vi);

	Mesh.Vertices.Clear;
	for vi := 0 to high(subvert) do
		Mesh.Vertices.AddVertex(subvert[vi], geo.GetNormal(vi));}

	//for i:= 0 to UGeosphere.IcosahedronTriangles-1 do begin
	//end;

	//Mesh.Vertices.Clear;
	for i:= 0 to high(IcosahedronTrianglePairs) do begin
		with Matlib.Materials.Add do begin
			Name:= 'tripair'+IntToStr(i);
			Material.Texture.ImageClassName:= 'TGLBlankImage';
			TGLBlankImage(Material.Texture.Image).Height:= 1024;
			TGLBlankImage(Material.Texture.Image).Width:= 1024;
			Material.Texture.Disabled:= false;
			Material.Texture.Image.GetBitmap32.Assign(geo.GetTexture(i));
			Material.Texture.TextureWrap:= twNone;
			Shader:= ShadowShader;
		end;
	end;

	ShadowShader.VertexProgram.LoadFromFile('shadowmap_vp.glsl');
	ShadowShader.FragmentProgram.LoadFromFile('shadowmap_fp.glsl');
	ShadowShader.Enabled := true;

	setlength(submeshes, IcosahedronTriangles);
	for mi:= 0 to IcosahedronTriangles-1 do begin
		submesh:= GeoContainer.AddNewChild(TGLMesh) as TGLMesh;
		submesh.Vertices.Clear;

		submesh.VertexMode:= vmVNT;
		submesh.Mode:= mmTriangles;
		submesh.Material.MaterialLibrary:= Matlib;
		submesh.Material.LibMaterialName:= 'tripair' + IntToStr(IcosahedronTriangleToPairsMap[mi]);//'gray';
	  {	case mi of
			0, 1 : submesh.Material.FrontProperties.Diffuse.SetColor(1, 0, 0);
			2, 3 : submesh.Material.FrontProperties.Diffuse.SetColor(0, 1, 0);
			12, 8 : submesh.Material.FrontProperties.Diffuse.SetColor(0, 0, 1);
			13, 10 : submesh.Material.FrontProperties.Diffuse.SetColor(1, 1, 0);
			14, 5 : submesh.Material.FrontProperties.Diffuse.SetColor(0, 1, 1);
			15, 4 : submesh.Material.FrontProperties.Diffuse.SetColor(1, 0, 1);
			16, 7 : submesh.Material.FrontProperties.Diffuse.SetColor(1, 1, 1);
			17, 11 : submesh.Material.FrontProperties.Diffuse.SetColor(1, 0.5, 0);
			18, 9 : submesh.Material.FrontProperties.Diffuse.SetColor(0.5, 0.5, 0.5);
			19, 6 : submesh.Material.FrontProperties.Diffuse.SetColor(0, 1, 0.5);
		end;      }
	  //	submesh.Material.FrontProperties.Ambient:= submesh.Material.FrontProperties.Diffuse;
		setlength(geomesh, 0);
		geo.GenerateMesh(geomesh, mi, -1, mi);
		for i:= 0 to high(geomesh) do begin
			vd.coord:= geomesh[i].position;
			vd.normal:= geomesh[i].normal;
			vd.textCoord:= geomesh[i].uv;
			//vd.textCoord.S:= Random;
			//vd.textCoord.T:= Random;
			submesh.Vertices.AddVertex(vd);
			//submesh.Vertices.AddVertex(geomesh[i].position, geomesh[i].normal);
		end;
			//submesh.Vertices.AddVertex(geomesh[i].position, geomesh[i].normal, clrRed, geomesh[i].uv);
		submeshes[mi]:= submesh;
	end;

   Caption:= 'tris:'+IntToStr(length(subvert) div 3) + ' nodes:' + IntToStr(geo.NodesCount) + ' r:' + FloatToStr(geo.AverageRadius);
	//geo.Free;
	setlength(subvert, 0);

	{bmp32:= TBitmap32.Create;
	bmp32.SetSize(1024, 1024);
	bmp32.FillRect(0, 0, 1024, 1024, clRed32);

	blankmat:= Matlib.Materials.GetLibMaterialByName('blank').Material;
	blankmat.Texture.Image.GetBitmap32.Assign(bmp32);}
end;

procedure TMainForm.CreateStars;
var phi, theta, r, size : single;
    i : integer;

begin
   for i:= 0 to 1000 do begin
   	//theta:= Random*pi;
		//phi:= 2.0*Math.Arcsin(2*Random-1);

		//theta:= Random*pi;
		//phi:= Random*2*pi - pi;

		theta:= Math.arccos(2*Random-1);
		phi:= 2*pi*Random;

		r:= 100;
		size:= exp(RandG(2, 0.5))*0.1;
		with TGLSprite(Stars.AddNewChild(TGLSprite)) do begin
         Material.MaterialLibrary:= Matlib;
			Material.LibMaterialName:= 'star' + IntToStr(1+Random(2));
			Position.X:= sin(theta)*cos(phi)*r;
			Position.Y:= sin(theta)*sin(phi)*r;
			Position.Z:= cos(theta)*r;
			Scale.SetVector(size, size, size);
      end;
   end;
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
	 PolygonOffsetFactor := 4;
	 PolygonOffsetUnits := 4;
  end;
end;

procedure TMainForm.ShadowShaderApplyEx(Shader: TGLCustomGLSLShader; Sender: TObject);
begin
  with Shader, Matlib do
  begin
	 Param['ShadowMap'].AsTexture2D[0] := TextureByName(ShadowFBORenderer.DepthTextureName);
	 Param['MainTexture'].AsTexture2D[1] := TGLLibMaterial(Sender).Material.Texture;//TextureByName('tex1024');
	 Param['Scale'].AsFloat := 200.0;
//	 Param['WaterLevel'].AsFloat := geo.xAverageRadius;
//	 Param['Amplitude'].AsFloat := 0.1;
	 Param['Softly'].AsInteger := 1;
	 Param['EyeToLightMatrix'].AsMatrix4f := FEyeToLightMatrix;
  end;
end;

procedure TMainForm.ShadowShaderInitializeEx(Shader: TGLCustomGLSLShader; Sender: TObject);
begin
  with Shader, Matlib do
  begin
	 Param['ShadowMap'].AsTexture2D[0] := TextureByName(ShadowFBORenderer.DepthTextureName);
	 Param['MainTexture'].AsTexture2D[1] := TGLLibMaterial(Sender).Material.Texture;//TextureByName('tex1024');
	 //Param['LightPosition'].AsVector4f := ShadowCamera.Position.AsVector;
  end;
end;

procedure TMainForm.StartBtnClick(Sender: TObject);
begin
	StartBtn.Visible:= false;
	ProgressBar.Visible:= true;
	NoiseFactor:= StrToFloat(NoiseComboBox.Text);
	CratersCount:= StrToInt(CratersComboBox.Text);
	MountainsCount:= StrToInt(MountainsComboBox.Text);
	CanyonsCount:= StrToInt(CanyonsComboBox.Text);

	case TerrainComboBox.ItemIndex of
		0 : Subdivisions:= 7;
		1 : Subdivisions:= 8;
   end;

	CreateGeo;
	//CreateStars;

	ShadowShader.Enabled:= ShadowsComboBox.ItemIndex > 0;
	ShadowFBORenderer.Active:= ShadowsComboBox.ItemIndex > 0;
	case ShadowsComboBox.ItemIndex of
		//1 : ShadowFBORenderer.Width:= 512;
		//2 : ShadowFBORenderer.Width:= 1024;
		1 : ShadowFBORenderer.Width:= 2048;
   end;
   ShadowFBORenderer.Height:= ShadowFBORenderer.Width;

	ConfigPanel.Visible:= false;
	Viewer.Visible:= true;
	Cadencer.Enabled:= true;
end;

procedure TMainForm.WalkerProgress(Sender: TObject; const deltaTime, newTime: Double);
var h : single;
    ptA, ptB, ptC : TVector3f;
    d, r : TVector4f;

begin
  	h:= geo.GetHeightAtPoint(Walker.Position.AsAffineVector);
	Walker.Up.AsVector:= VectorNormalize(Walker.Position.AsVector);
	//Caption:= FloatToStr(h);
	Walker.Position.SetPoint(VectorNormalize(Walker.Position.AsAffineVector));
	if h > 0 then
		WalkerCamera.Position.Y:= h-1 + 0.01;

	UserInterface.MouseUpdate;
	UserInterface.MouseLook;

	d:= WalkerCamera.AbsoluteDirection;
   r:= WalkerCamera.AbsoluteRight;
	if IsKeyDown('w') then
		Walker.AbsolutePosition:= VectorAdd(Walker.AbsolutePosition, VectorScale(d, deltaTime));
	if IsKeyDown('s') then
		Walker.AbsolutePosition:= VectorAdd(Walker.AbsolutePosition, VectorScale(d, -deltaTime));
	if IsKeyDown('a') then
		Walker.AbsolutePosition:= VectorAdd(Walker.AbsolutePosition, VectorScale(r, deltaTime));
	if IsKeyDown('d') then
   	Walker.AbsolutePosition:= VectorAdd(Walker.AbsolutePosition, VectorScale(r, -deltaTime));

  {	geo.GetTriangleAtPoint(AffineVectorMake(mesh.AbsoluteToLocal(Camera.Position.AsVector)), ptA, ptB, ptC, 4);
	SphereA.Position.SetPoint(ptA);
	SphereB.Position.SetPoint(ptB);
	SphereC.Position.SetPoint(ptC);}
end;

end.
