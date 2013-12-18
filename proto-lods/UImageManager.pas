unit UImageManager;

interface

uses SysUtils, Math, VectorTypes, VectorGeometry, VectorGeometryEx,
     UImageTree,
     GLScene, GLObjects, BaseClasses, GLCoordinates;

type

     TTOImageManager = class(TTOImageNode)

          Camera : TTOImageNode;

          constructor CreateAsRoot(aSeed : integer; aScene : TGLScene; imageRoot : TGLDummyCube; levelsNumber : integer = 0);

          private
               xScene : TGLScene;
               xLevelContainers : array of TGLDummyCube;
     end;

implementation

constructor TTOImageManager.CreateAsRoot(aSeed : integer; aScene : TGLScene; imageRoot : TGLDummyCube; levelsNumber : integer = 0);
var i : integer;

begin
    { Camera:= nil;

     inherited Create(aSeed);

     xScene:= aScene;
     setlength(xLevelContainers, levelsNumber);

     for i:= 0 to high(xLevelContainers) do begin
          xLevelContainers[i]:= TGLDummyCube(imageRoot.AddNewChild(TGLDummyCube));
     end;}
end;

end.
