unit FMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, GLWin32Viewer, GLMaterial, GLCadencer, GLCrossPlatform, GLRenderContextInfo,
  BaseClasses, GLScene, GLCoordinates, GLObjects, GLFeedback, OpenGL1x;

type
  TMainForm = class(TForm)
    Scene: TGLScene;
    Cadencer: TGLCadencer;
    MaterialLibrary: TGLMaterialLibrary;
    Viewer: TGLSceneViewer;
    Camera: TGLCamera;
    Cube1: TGLCube;
    Cube2: TGLCube;
    Cube3: TGLCube;
    DGLClearBuffer: TGLDirectOpenGL;
    procedure DGLClearBufferRender(Sender: TObject;
      var rci: TRenderContextInfo);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.DGLClearBufferRender(Sender: TObject;
  var rci: TRenderContextInfo);
begin
     glClear(GL_DEPTH_BUFFER_BIT);
end;

end.
