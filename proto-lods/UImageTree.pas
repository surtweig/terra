unit UImageTree;

interface

{$DEFINE InvalidBasisException}
{$DEFINE ImageLevelException}

uses SysUtils, Math, VectorTypes, VectorGeometry, VectorGeometryEx,
     GLScene, GLObjects, BaseClasses, GLCoordinates;

     
//---------------------------------------------------------------------------
const
     LevelScale = 0.01;

     
//---------------------------------------------------------------------------
type

     //----------------------------------------------------------------------

     TTOImageID = array of integer;
     TTOImageContainer = TGLDummyCube;
     TTOImageContainersList = array of TTOImageContainer;
     TTOImageNode = class;

     //----------------------------------------------------------------------
     TTORelativeScalar = record
          value : TTOFloat;
          basis : TTOImageNode;
     end;

     TTORelativeVector = record
          vector : TTOVector;
          basis : TTOImageNode;
     end;

     //----------------------------------------------------------------------
     TTORootNode = class;

     //----------------------------------------------------------------------
     TTOImageNode = class

          constructor Create(aParent : TTOImageNode);

          function Position : TTOVector;
          function Scale : TTOFloat;
          function ID : TTOImageID;
          function Index : integer;
          function Level : integer;
          function Parent : TTOImageNode;
          function Root : TTORootNode;
          function Seed : integer;
          function BoundingSphereRadius : TTOFloat;
          function ScreenSizeRaw(cameraPoint : TTOVector) : TTOFloat;

          procedure SetPosition(aPosition : TTOVector); overload;
          procedure SetPosition(x, y, z : TTOFloat); overload;
          procedure SetScale(aScale : TTOFloat);
          procedure SetBoundingSphereRadius(aRadius : TTOFloat);

          function ChildrenCount : integer;
          function GetChild(childIndex : integer) : TTOImageNode;
          function GetNode(nodeID : TTOImageID) : TTOImageNode;
          function FindCommonAncestor(nodeID : TTOImageID) : TTOImageNode;
          function IsAncestorOf(node : TTOImageNode) : boolean;

          procedure CreateChildren;
          procedure FreeChildren;
          function ChildrenCreated : boolean;

          procedure BuildImage;
          procedure UpdateImage;
          procedure FreeImage;
          function Image : TTOImageContainer;

          function ScreenSize(Camera : TTOImageNode) : TTORelativeScalar;
          function PositionIn(basis : TTOImageNode) : TTORelativeVector;
          function SizeIn(basis : TTOImageNode) : TTORelativeScalar;
          function VectorTo(node : TTOImageNode) : TTORelativeVector;
          function DistanceTo(node : TTOImageNode) : TTORelativeScalar;

          private
               xSeed : integer;
               xPosition : TTOVector;
               xScale : TTOFloat;
               xParent : TTOImageNode;
               xRoot : TTORootNode;
               xID : TTOImageID;
               xBoundingSphereRadius : TTOFloat;

               xChildren : array of TTOImageNode;
               xChildrenCreated : boolean;

               xImage : TTOImageContainer;

          protected
               procedure xCreateChildren; virtual;
               procedure xBuildImage; virtual;
               procedure xFreeImage; virtual;
               procedure xUpdateImage; virtual;
     end;

     //----------------------------------------------------------------------
     TTORootNode = class(TTOImageNode)

          ObserverNode : TTOImageNode;

          constructor Create(aSeed : integer; aLevelContainers : TTOImageContainersList);
          function LevelContainer(LevelIndex : integer) : TTOImageContainer;

          private
               xLevelContainers : TTOImageContainersList;
     end;

     //----------------------------------------------------------------------
     TTOVisibleNode = class(TTOImageNode)

          protected
               procedure xUpdateImage; override;
               procedure xBuildImage; override;
               procedure xFreeImage; override;
     end;

     //----------------------------------------------------------------------
     TTOTransportNode = class(TTOImageNode)

          Velocity : TTORelativeVector;

          constructor Create(aParent : TTOImageNode; aLevelScale, aLevelBound : TTOFloat; aUpperLevel : integer);

          function Transit(aParent : TTOImageNode) : boolean;
          procedure Move(step : TTORelativeVector);
          procedure UpdatePosition(deltaTime : TTOFloat);
          function Passenger : TTOImageNode;

          private
               xLevelScale, xLevelBound : TTOFloat;
               xUpperLevel : integer;
               xPassenger : TTOImageNode;

          protected
               procedure xCreateChildren; override;


     end;


//---------------------------------------------------------------------------
function MakeRelScalar(aValue : TTOFloat; aBasis : TTOImageNode) : TTORelativeScalar;
function MakeRelVector(aVector : TTOVector; aBasis : TTOImageNode) : TTORelativeVector;
function IDToStr(aID : TTOImageID) : string;

//---------------------------------------------------------------------------
implementation

function MakeRelScalar(aValue : TTOFloat; aBasis : TTOImageNode) : TTORelativeScalar;
begin
     Result.value:= aValue;
     Result.basis:= aBasis;
end;

function MakeRelVector(aVector : TTOVector; aBasis : TTOImageNode) : TTORelativeVector;
begin
     Result.vector:= aVector;
     Result.basis:= aBasis;
end;

function IDToStr(aID : TTOImageID) : string;
var i : integer;

begin
     Result:= '';
     if length(aID) > 0 then begin
          for i:= 0 to high(aID) do begin
               Result:= Result + IntToStr(aID[i]);
               if i < high(aID) then
                    Result:= Result + '.';
          end;
     end;
end;


//---------------------------------------------------------------------------
//                                                                          -
// TTORootNode                                                              -
//                                                                          -
//---------------------------------------------------------------------------
constructor TTORootNode.Create(aSeed : integer; aLevelContainers : TTOImageContainersList);
begin
     xParent:= nil;
     xRoot:= self;
     setlength(xChildren, 0);
     setlength(xID, 0);
     xChildrenCreated:= false;
     MakeAffineVector(xPosition, 0, 0, 0);
     xScale:= 1;
     xBoundingSphereRadius:= 0;
     xImage:= nil;
     xSeed:= aSeed;
     xLevelContainers:= aLevelContainers;
     ObserverNode:= nil;
end;

//---------------------------------------------------------------------------
function TTORootNode.LevelContainer(LevelIndex : integer) : TTOImageContainer;
begin
     if (LevelIndex >= 0) and (LevelIndex < length(xLevelContainers)) then
          Result:= xLevelContainers[LevelIndex]
     else
          Result:= nil;
end;


//---------------------------------------------------------------------------
//                                                                          -
// TTOImageNode                                                             -
//                                                                          -
//---------------------------------------------------------------------------
constructor TTOImageNode.Create(aParent : TTOImageNode);
var n : integer;

begin
     xParent:= aParent;
     setlength(xChildren, 0);
     xChildrenCreated:= false;
     xImage:= nil;

     if xParent <> nil then begin

          n:= length(xParent.xChildren);
          setlength(xParent.xChildren, n+1);
          xParent.xChildren[n]:= self;

          xRoot:= xParent.Root;

          setlength(xID, length(xParent.xID)+1);
          for n:= 0 to high(xParent.xID) do
               xID[n]:= xParent.xID[n];
          xID[high(xID)]:= xParent.ChildrenCount-1;

          RandSeed:= xParent.Seed;
          xSeed:= Random(MaxInt);
     end else
          raise Exception.Create('ImageNode.Create: aParent = nil');

     MakeAffineVector(xPosition, 0, 0, 0);
     xScale:= 1;
     xBoundingSphereRadius:= 0;
end;

//---------------------------------------------------------------------------
function TTOImageNode.Position : TTOVector;
begin
     Result:= xPosition;
end;

//---------------------------------------------------------------------------
function TTOImageNode.Scale : TTOFloat;
begin
     Result:= xScale;
end;

//---------------------------------------------------------------------------
function TTOImageNode.ID : TTOImageID;
begin
     Result:= xID;
end;

//---------------------------------------------------------------------------
function TTOImageNode.Index : integer;
begin
     Result:= xID[high(xID)];
end;

//---------------------------------------------------------------------------
function TTOImageNode.Level : integer;
begin
     Result:= length(xID);
end;

//---------------------------------------------------------------------------
function TTOImageNode.Parent : TTOImageNode;
begin
     Result:= xParent;
end;

//---------------------------------------------------------------------------
function TTOImageNode.Root : TTORootNode;
begin
     Result:= xRoot;
end;

//---------------------------------------------------------------------------
function TTOImageNode.Seed : integer;
begin
     Result:= xSeed;
end;

//---------------------------------------------------------------------------
function TTOImageNode.BoundingSphereRadius : TTOFloat;
begin
     Result:= xBoundingSphereRadius;
end;

//---------------------------------------------------------------------------
function TTOImageNode.ScreenSizeRaw(cameraPoint : TTOVector) : TTOFloat;
begin
     Result:= 2.0*SphereVisibleRadius(VectorLength(VectorSubtract(cameraPoint, Position)), BoundingSphereRadius*0.5);
end;

//---------------------------------------------------------------------------
procedure TTOImageNode.SetPosition(aPosition : TTOVector);
begin
     xPosition:= aPosition;
     UpdateImage;
end;

//---------------------------------------------------------------------------
procedure TTOImageNode.SetPosition(x, y, z : TTOFloat);
begin
     xPosition[0]:= x;
     xPosition[1]:= y;
     xPosition[2]:= z;
     UpdateImage;
end;

//---------------------------------------------------------------------------
procedure TTOImageNode.SetScale(aScale : TTOFloat);
begin
     xScale:= aScale;
     UpdateImage;
end;

//---------------------------------------------------------------------------
procedure TTOImageNode.SetBoundingSphereRadius(aRadius : TTOFloat);
begin
     xBoundingSphereRadius:= aRadius;
     UpdateImage;
end;

//---------------------------------------------------------------------------
function TTOImageNode.ChildrenCount : integer;
begin
     Result:= length(xChildren);
end;

//---------------------------------------------------------------------------
function TTOImageNode.GetChild(childIndex : integer) : TTOImageNode;
begin
     if (childIndex >= 0) and (childIndex < length(xChildren)) then
          Result:= xChildren[childIndex]
     else
          Result:= nil;
end;

//---------------------------------------------------------------------------
function TTOImageNode.GetNode(nodeID : TTOImageID) : TTOImageNode;
var i : integer;

begin
     Result:= Root;

     if length(nodeID) = 0 then Exit;

     for i:= 0 to high(nodeID) do begin
          Result:= Result.GetChild(nodeID[i]);
          if Result = nil then Break;
     end;
end;

//---------------------------------------------------------------------------
function TTOImageNode.FindCommonAncestor(nodeID : TTOImageID) : TTOImageNode;
var i : integer;

begin
     Result:= Root;
     if (length(nodeID) = 0) or (length(ID) = 0) then Exit;

     for i:= 0 to min(high(nodeID), high(ID)) do begin
          if nodeID[i] = ID[i] then
               Result:= Result.GetChild(nodeID[i])
          else
               Break;
     end;
end;

//---------------------------------------------------------------------------
function TTOImageNode.IsAncestorOf(node : TTOImageNode) : boolean;
var i : integer;

begin
     Result:= false;
     if length(xID) <= length(node.ID) then begin
          Result:= true;

          if length(xID) = 0 then
               Exit;

          for i:= 0 to high(xID) do
               if xID[i] <> node.ID[i] then begin
                    Result:= false;
                    Break;
               end;
     end;
end;

//---------------------------------------------------------------------------
procedure TTOImageNode.CreateChildren;
begin
     if not xChildrenCreated then begin
          RandSeed:= xSeed;
          xCreateChildren;
     end;
end;

//---------------------------------------------------------------------------
procedure TTOImageNode.FreeChildren;
var i : integer;
begin
     if xChildrenCreated then
          for i:= 0 to high(xChildren) do
               xChildren[i].Free;
end;

//---------------------------------------------------------------------------
function TTOImageNode.ChildrenCreated : boolean;
begin
     Result:= xChildrenCreated;
end;

//---------------------------------------------------------------------------
procedure TTOImageNode.BuildImage;
begin
     if xImage = nil then begin
          RandSeed:= xSeed;
          xBuildImage;
     end;
end;

//---------------------------------------------------------------------------
procedure TTOImageNode.UpdateImage;
var i : integer;

begin
     if xImage <> nil then
          xUpdateImage;

     if length(xChildren) > 0 then
          for i:= 0 to high(xChildren) do
               xChildren[i].UpdateImage;
end;

//---------------------------------------------------------------------------
procedure TTOImageNode.FreeImage;
begin
     if xImage <> nil then begin
          xFreeImage;
          xImage:= nil;
     end;
end;

//---------------------------------------------------------------------------
function TTOImageNode.Image : TTOImageContainer;
begin
     Result:= xImage;
end;

//---------------------------------------------------------------------------
function TTOImageNode.ScreenSize(Camera : TTOImageNode) : TTORelativeScalar;
var dist, size : TTORelativeScalar;

begin
     Result.basis:= FindCommonAncestor(Camera.ID);

     dist.value:= VectorLength(VectorSubtract(Camera.PositionIn(Result.basis).vector, PositionIn(Result.basis).vector));
     size:= SizeIn(Result.basis);

     Result.value:= 2*SphereVisibleRadius(dist.value, size.value*0.5);
end;

//---------------------------------------------------------------------------
function TTOImageNode.PositionIn(basis : TTOImageNode) : TTORelativeVector;
var i : integer;
    localNode : TTOImageNode;
begin
     Result.basis:= self;
     Result.vector:= Position;
     if basis.IsAncestorOf(self) then begin
          Result.basis:= basis;

          i:= Level;
          localNode:= self;
          while i < basis.Level do begin
               localNode:= localNode.Parent;
               ScaleVector(Result.vector, localNode.Scale);
               AddVector(Result.vector, localNode.Position);
               i:= i + 1;
          end;

     end else begin
          {$IFDEF InvalidBasisException}
          raise Exception.Create('TTOImageNode.PositionIn: Basis must be an ancestor.');
          {$ENDIF}
     end;
end;

//---------------------------------------------------------------------------
function TTOImageNode.SizeIn(basis : TTOImageNode) : TTORelativeScalar;
var i : integer;
    localNode : TTOImageNode;
begin
     Result.basis:= self;
     Result.value:= 2*BoundingSphereRadius;
     if basis.IsAncestorOf(self) then begin
          Result.basis:= basis;

          i:= Level;
          localNode:= self;
          while i < basis.Level do begin
               localNode:= localNode.Parent;
               Result.value:= Result.value * localNode.Scale;
               i:= i + 1;
          end;

     end else begin
          {$IFDEF InvalidBasisException}
          raise Exception.Create('TTOImageNode.SizeIn: Basis must be an ancestor.');
          {$ENDIF}
     end;
end;

//---------------------------------------------------------------------------
function TTOImageNode.VectorTo(node : TTOImageNode) : TTORelativeVector;
begin
     Result.basis:= FindCommonAncestor(node.ID);
     Result.vector:= VectorSubtract(node.PositionIn(Result.basis).vector, PositionIn(Result.basis).vector);
end;

//---------------------------------------------------------------------------
function TTOImageNode.DistanceTo(node : TTOImageNode) : TTORelativeScalar;
var relVec : TTORelativeVector;

begin
     relVec:= VectorTo(node);
     Result.value:= VectorLength(relVec.vector);
     Result.basis:= relVec.basis;
end;

//---------------------------------------------------------------------------
procedure TTOImageNode.xCreateChildren;
begin
end;

//---------------------------------------------------------------------------
procedure TTOImageNode.xBuildImage;
begin
end;

//---------------------------------------------------------------------------
procedure TTOImageNode.xUpdateImage;
begin

end;

//---------------------------------------------------------------------------
procedure TTOImageNode.xFreeImage;
begin
end;


//---------------------------------------------------------------------------
//                                                                          -
// TTOVisibleNode                                                           -
//                                                                          -
//---------------------------------------------------------------------------
procedure TTOVisibleNode.xBuildImage;
begin
     xImage:= TGLDummyCube(Root.LevelContainer(Level).AddNewChild(TGLDummyCube));
     UpdateImage;
end;

//---------------------------------------------------------------------------
procedure TTOVisibleNode.xUpdateImage;
var
     lev : integer;
     com, observerAncestor, imageAncestor : TTOImageNode;
     pos, addPos : TTOVector;
     vecTo : TTORelativeVector;

begin
     if Root.ObserverNode <> nil then begin
          xImage.Visible:= true;
          if Root.ObserverNode.Level >= self.Level then begin
               com:= Root.ObserverNode.FindCommonAncestor(self.ID);
               observerAncestor:= com;
               imageAncestor:= com;
               MakeAffineVector(pos, 0, 0, 0);


               if com.Level < self.Level then begin
                    for lev:= com.Level to self.Level-1 do begin
                         observerAncestor:= observerAncestor.GetChild(Root.ObserverNode.ID[lev]);
                         imageAncestor:= imageAncestor.GetChild(self.ID[lev]);

                         ScaleVector(pos, 1.0/imageAncestor.Scale);
                         vecTo:= observerAncestor.VectorTo(imageAncestor);
                         AddVector(pos, vecTo.vector);
                    end;

                    if self.Level < Root.ObserverNode.Level then begin
                         MakeAffineVector(addPos, 0, 0, 0);
                         observerAncestor:= Root.ObserverNode;

                         for lev:= Root.ObserverNode.Level-1 downto self.Level do begin

                              SubtractVector(addPos, observerAncestor.Position);
                              observerAncestor:= observerAncestor.Parent;
                              ScaleVector(addPos, observerAncestor.Scale);
                         end;
                         AddVector(pos, addPos);
                    end;
               end;

               xImage.Position.SetPoint(AffineVectorMake(pos));

          end else begin
               {$IFDEF ImageLevelException}
               raise Exception.Create('VisibleNode.xUpdateImage : Image level exceeds observer''s.');
               {$ENDIF}
          end;

     end else
          xImage.Visible:= false;
end;

//---------------------------------------------------------------------------
procedure TTOVisibleNode.xFreeImage;
begin
     xImage.Free;
end;


//---------------------------------------------------------------------------
//                                                                          -
// TTOTransportNode                                                         -
//                                                                          -
//---------------------------------------------------------------------------
constructor TTOTransportNode.Create(aParent : TTOImageNode; aLevelScale, aLevelBound : TTOFloat; aUpperLevel : integer);
begin
     inherited Create(aParent);
     xLevelScale:= aLevelScale;
     xLevelBound:= aLevelBound;
     xUpperLevel:= aUpperLevel;

     xBoundingSphereRadius:= aLevelBound;
     xScale:= aLevelScale;
     xPassenger:= nil;

     MakeAffineVector(Velocity.vector, 0, 0, 0);
     Velocity.basis:= Parent;
end;

//---------------------------------------------------------------------------
function TTOTransportNode.Transit(aParent : TTOImageNode) : boolean;
begin

end;

//---------------------------------------------------------------------------
procedure TTOTransportNode.Move(step : TTORelativeVector);
var
     stepDir, posDir, newPos : TTOVector;
     stepLen, posLen, bsr : TTOFloat;
     moveNode : TTOImageNode;

begin
     if self.IsAncestorOf(step.basis) then begin

          VectorNormLength(step.vector, stepDir, stepLen);
          moveNode:= xPassenger;

          while moveNode.Level >= self.Level do begin

               if stepLen <= 0 then
                    Break;

               if (step.basis.Level >= moveNode.Level) then begin

                    bsr:= moveNode.Parent.BoundingSphereRadius;
                    newPos:= VectorAdd(moveNode.Position, VectorScale(stepDir, stepLen));
                    VectorNormLength(newPos, posDir, posLen);

                    if posLen > bsr then begin
                         moveNode.SetPosition(0, 0, 0);
                         stepLen:= posLen * moveNode.Parent.Scale;
                         stepDir:= posDir;

                    end else begin
                         moveNode.SetPosition(newPos);
                         stepLen:= 0;
                         
                    end;
               end;

               moveNode:= moveNode.Parent;
          end;

     end else begin
          {$IFDEF InvalidBasisException}
          raise Exception.Create('TransportNode.Move : Step basis must be a descendant of the node.');
          {$ENDIF}
     end;
end;

//---------------------------------------------------------------------------
procedure TTOTransportNode.UpdatePosition(deltaTime : TTOFloat);
var step : TTORelativeVector;

begin
     step.vector:= VectorScale(Velocity.vector, deltaTime);
     step.basis:= Velocity.basis;
     Move(step);
end;

//---------------------------------------------------------------------------
procedure TTOTransportNode.xCreateChildren;
var lev : integer;
    node, prevNode : TTOImageNode;

begin
     if xUpperLevel > Level then begin
          prevNode:= self;
          for lev:= Level to xUpperLevel do begin
               node:= TTOImageNode.Create(prevNode);
               node.SetScale(xLevelScale);
               node.SetBoundingSphereRadius(xLevelBound);
               prevNode:= node;
          end;
          xPassenger:= node;
     end;
end;

//---------------------------------------------------------------------------
function TTOTransportNode.Passenger : TTOImageNode;
begin
     Result:= xPassenger;
end;

end.
