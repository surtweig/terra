unit UGalaxyGen;

interface

uses Math, VectorTypes, VectorGeometry;

type

     TGalaxyRootNode = class;

     TGalaxyAbstractNode = class

          fNoise : single;

          constructor Create(aParent : TGalaxyAbstractNode; aLevel : integer = 0);

          function Level : integer;
          function Parent : TGalaxyAbstractNode;
          function Root : TGalaxyRootNode;
          function Position : TVector3f;

          procedure ApplyOffset(Offset : TVector3f);
          procedure AddChild(Child : TGalaxyAbstractNode);
          function GetChild(Index : integer) : TGalaxyAbstractNode;
          function Count : integer;

          procedure Procreate(aCount : integer = 0); virtual; abstract;
          procedure Shake(aAmount : single);

          protected
               xLevel : integer;
               xParent : TGalaxyAbstractNode;
               xRoot : TGalaxyRootNode;
               xPosition : TVector3f;
               xChildren : array of TGalaxyAbstractNode;
     end;

     TGalaxyRootNode = class(TGalaxyAbstractNode)

          ArmsNumber, ArmNodesNumber : integer;
          Axis : TVector3f;

          fCurvature, fDistance,
          fCurvatureMult, fDistanceMult,
          fEclipticPersistence

                : single;

          constructor Create;

          procedure Procreate(aCount : integer = 0); override;

     end;

     TGalaxyArmNode = class(TGalaxyAbstractNode)
          NodesNumber : integer;
          fCurvature, fDistance : single;

          procedure Procreate(aCount : integer = 0); override;
     end;

implementation

     constructor TGalaxyAbstractNode.Create(aParent : TGalaxyAbstractNode; aLevel : integer);
     begin
          xParent:= aParent;
          xLevel:= aLevel;

          if xParent <> nil then begin
               xPosition:= xParent.Position;
               xRoot:= xParent.Root;
          end else begin
               xPosition:= AffineVectorMake(0, 0, 0);
               xRoot:= TGalaxyRootNode(self);
          end;

          setlength(xChildren, 0);
     end;

     function TGalaxyAbstractNode.Level : integer;
     begin
          Result:= xLevel;
     end;

     function TGalaxyAbstractNode.Parent : TGalaxyAbstractNode;
     begin
          Result:= xParent;
     end;

     function TGalaxyAbstractNode.Root : TGalaxyRootNode;
     begin
          Result:= xRoot;
     end;

     function TGalaxyAbstractNode.Position : TVector3f;
     begin
          Result:= xPosition;
     end;

     procedure TGalaxyAbstractNode.ApplyOffset(Offset : TVector3f);
     begin
          AddVector(xPosition, Offset);
     end;

     procedure TGalaxyAbstractNode.AddChild(Child : TGalaxyAbstractNode);
     var n : integer;

     begin
          n:= length(xChildren);
          setlength(xChildren, n+1);
          xChildren[n]:= Child;
     end;

     function TGalaxyAbstractNode.GetChild(Index : integer) : TGalaxyAbstractNode;
     begin
          Result:= xChildren[Index];
     end;

     function TGalaxyAbstractNode.Count : integer;
     begin
          Result:= length(xChildren);
     end;

     procedure TGalaxyAbstractNode.Shake(aAmount : single);
     var i : integer;
         offset : TVector3f;
         rad : single;
     begin
          offset:= AffineVectorMake(0, 0, 0);
          rad:= max(abs(VectorLength(Position)-10), 10);
          if Level > 0 then begin
               offset:= AffineVectorMake(
                    RandG(0, aAmount)*rad,
                    RandG(0, aAmount)*rad,
                    RandG(0, aAmount)*20/power(rad+10, 0.1));

               ApplyOffset(offset);
          end;

          for i:= 0 to high(xChildren) do begin
               xChildren[i].ApplyOffset(offset);
               xChildren[i].Shake(aAmount);
          end;
     end;

     constructor TGalaxyRootNode.Create;
     begin
          inherited Create(nil);

          fCurvature:= 0.2;
          fDistance:= 1.01;
          fCurvatureMult:= 0.999;
          fDistanceMult:= 1.001;
          fEclipticPersistence:= 1;
          xLevel:= 0;
          fNoise:= 0.010;

          ArmsNumber:= 2;
          ArmNodesNumber:= 50;

          Axis:= AffineVectorMake(0, 0, 1);
     end;

     procedure TGalaxyRootNode.Procreate(aCount : integer = 0);
     var i : integer;
         arm : TGalaxyArmNode;
         pos : TVector3f;
         alpha : single;

     begin
          for i:= 1 to ArmsNumber do begin
               alpha:= (i/ArmsNumber)*2*pi;
               pos:= AffineVectorMake(cos(alpha), sin(alpha), 0);
               ScaleVector(pos, fDistance);

               arm:= TGalaxyArmNode.Create(self, 1);
               arm.NodesNumber:= ArmNodesNumber;
               arm.fCurvature:= fCurvature;
               arm.fDistance:= fDistance;
               arm.ApplyOffset(pos);

               AddChild(arm);
               arm.Procreate(ArmNodesNumber);
          end;

          for i:= 1 to 500 do begin
               pos:= AffineVectorMake(RandG(0, 1.5), RandG(0, 1.5), RandG(0, 2));
               arm:= TGalaxyArmNode.Create(self, 1);
               arm.ApplyOffset(pos);
               AddChild(arm);
          end;
     end;


     procedure TGalaxyArmNode.Procreate(aCount : integer = 0);
     var i : integer;
         next, sub : TGalaxyArmNode;
         pos : TVector4f;
         phi, rad : single;

     begin
          if aCount > 0 then begin
               next:= TGalaxyArmNode.Create(self, Level);

               pos:= VectorMake(VectorSubtract(self.Position, Parent.Position));
               rad:= VectorLength(VectorSubtract(Position, Root.Position));
               NormalizeVector(pos);
               RotateVector(pos, Root.Axis, fCurvature + RandG(0, Root.fNoise));
               //RotateVector(pos, Root.Axis, fCurvature + (Random(10000)*0.0002 - 0.5)*Root.fNoise);
               ScaleVector(pos, rad*sin(fCurvature)*fDistance);

               next.ApplyOffset(AffineVectorMake(pos));

               AddChild(next);
               next.fCurvature:= fCurvature*Root.fCurvatureMult;
               next.fDistance:= fDistance*Root.fDistanceMult;
               next.Procreate(aCount-1);

               if Level < 3 then begin
                    for i:= 1 to 1{(2-Level)*3} do begin
                         sub:= TGalaxyArmNode.Create(self, Level+1);
                         pos:= VectorMake(VectorSubtract(self.Position, Parent.Position));
                         NormalizeVector(pos);
                         RotateVector(pos, Root.Axis, 1.25*fCurvature*RandG(0, 50*Root.fNoise));
                         ScaleVector(pos, fDistance*0.8);
                         sub.fCurvature:= fCurvature*0.5;
                         sub.fDistance:= fDistance*0.8;
                         sub.fNoise:= fNoise * 5;
                         sub.ApplyOffset(AffineVectorMake(pos));
                         AddChild(sub);
                         sub.Procreate(10);
                    end;
               end;
          end;
     end;

end.
