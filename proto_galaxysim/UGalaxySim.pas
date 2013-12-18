unit UGalaxySim;

interface

uses Math, VectorTypes, VectorGeometry;

const
     GravEpsilon = 0.1;
     GravConstant = 0.1;

type

     TMassPoint = class

          constructor Create(aMass : single; aPosition : TVector3f; aVelocity : TVector3f);

          function PrevPosition : TVector3f;
          function Position : TVector3f;
          function Velocity : TVector3f;
          function Mass : single;

          procedure AddForce(Force : TVector3f);
          procedure SetVelocity(newVelocity : TVector3f);
          procedure Impulse(deltaTime : single);

          private
               xMass : single;
               xPosition, xVelocity, xAcceleration, xPrevPosition : TVector3f;

     end;

     TMassSphereSystem = class;

     TGravityField = class

     end;

     TMassSphereSystem = class

          constructor Create;

          procedure GenerateSphere(aCount : integer; aMassSigma, aRadius : single);
         // procedure GenerateStable(aCount : integer; aMassSigma, aRadius : single);

          procedure Impulse(deltaTime : single);
          procedure UpdateGravity(deltaTime : single);

          function Count : integer;
          function GetPoint(Index : integer) : TMassPoint;

          private
               xPoints : array of TMassPoint;
               xAxis : TVector3f;
     end;


implementation

     constructor TMassPoint.Create(aMass : single; aPosition : TVector3f; aVelocity : TVector3f);
     begin
          xMass:= aMass;
          xPosition:= aPosition;
          xVelocity:= aVelocity;
          xAcceleration:= AffineVectorMake(0, 0, 0);
          xPrevPosition:= xPosition;
     end;

     function TMassPoint.Position : TVector3f;
     begin
          Result:= xPosition;
     end;

     function TMassPoint.PrevPosition : TVector3f;
     begin
          Result:= xPrevPosition;
     end;

     function TMassPoint.Velocity : TVector3f;
     begin
          Result:= xVelocity;
     end;

     function TMassPoint.Mass : single;
     begin
          Result:= xMass;
     end;

     procedure TMassPoint.AddForce(Force : TVector3f);
     begin
          AddVector(xAcceleration, VectorScale(Force, xMass));
     end;

     procedure TMassPoint.SetVelocity(newVelocity : TVector3f);
     begin
          xVelocity:= newVelocity;
     end;

     procedure TMassPoint.Impulse(deltaTime : single);
     begin
          xPrevPosition:= xPosition;
          AddVector(xPosition, VectorScale(xVelocity, deltaTime));
          AddVector(xPosition, VectorScale(xAcceleration, deltaTime*deltaTime*0.5));
          AddVector(xVelocity, VectorScale(xAcceleration, deltaTime));
     end;


     constructor TMassSphereSystem.Create;
     begin
     end;

     procedure TMassSphereSystem.GenerateSphere(aCount : integer; aMassSigma, aRadius : single);
     var i : integer;
         phi, theta, rad, mass : single;
         pos, vel : TVector3f;

     begin
          setlength(xPoints, aCount);
          xAxis:= AffineVectorMake(0, 0, 1);

          for i:= 0 to high(xPoints) do begin
               rad:= sqrt(Random)*aRadius;
               theta:= 2*pi*Random;
               phi:= 2*arcsin(sqrt(Random));

               mass:= aMassSigma;//exp(RandG(0, ln(aMassSigma)));
               pos[0]:= sin(phi)*cos(theta);
               pos[1]:= sin(phi)*sin(theta);
               pos[2]:= cos(phi);
               ScaleVector(pos, rad);

               vel:= pos;
              // NormalizeVector(vel);
               ScaleVector(vel, 0.5);
               vel:= VectorCrossProduct(vel, xAxis);

               xPoints[i]:= TMassPoint.Create(mass, pos, vel);
          end;
     end;

     procedure TMassSphereSystem.Impulse(deltaTime : single);
     var i : integer;

     begin
          UpdateGravity(deltaTime);
          for i:= 0 to high(xPoints) do begin
               xPoints[i].Impulse(deltaTime);
          end;
     end;

     procedure TMassSphereSystem.UpdateGravity(deltaTime : single);
     var i, j : integer;
         force, diff, antivel: TVector3f;
         dist, difflen, sign, maxgrav : single;

     begin
          for i:= 1 to high(xPoints) do begin

               with xPoints[i] do begin
                    force:= Position;
                    force[2]:= 0;
                    ScaleVector(force, -VectorDotProduct(force, Velocity)*0.001);
                    AddForce(force);

                    force:= AffineVectorMake(0, 0, -Velocity[2]*0.1);
                    ScaleVector(force, VectorLength(force));
                    AddForce(force);
               end;

               for j:= 0 to i-1 do begin
                    diff:= VectorSubtract(xPoints[i].Position, xPoints[j].Position);
                    dist:= VectorLength(diff);

                    sign:= 1;
                   { if dist < GravEpsilon then begin
                         sign:= -1;
                    end;}

                    //if dist > GravEpsilon then begin

                         NormalizeVector(diff);
                         maxgrav:= GravConstant * xPoints[i].Mass*xPoints[j].Mass;
                         force:= VectorScale(diff, maxgrav / (sqr(dist)+1));

                        // if dist < GravEpsilon then
                        //      AddVector(force, VectorScale(diff, -maxgrav*Power((GravEpsilon-dist)/GravEpsilon, 0.1)));

                         xPoints[i].AddForce(VectorNegate(force));
                         xPoints[j].AddForce(force);

                    //end else begin
                    if dist < GravEpsilon then begin

                        {if dist < 0.0001 then begin
                              diff:= AffineVectorMake(0, 0, GravEpsilon);
                              dist:= GravEpsilon;
                         end;

                         ScaleVector(diff, -1/dist);

                         antivel:= VectorScale(diff, VectorDotProduct(xPoints[j].Velocity, diff));
                         xPoints[j].SetVelocity(VectorSubtract(xPoints[j].Velocity, antivel));

                         antivel:= VectorScale(diff, VectorDotProduct(xPoints[i].Velocity, diff));
                         xPoints[i].SetVelocity(VectorSubtract(xPoints[i].Velocity, antivel));}
                    end;

               end;
          end;
     end;

     function TMassSphereSystem.Count : integer;
     begin
          Result:= length(xPoints);
     end;

     function TMassSphereSystem.GetPoint(Index : integer) : TMassPoint;
     begin
          Result:= xPoints[Index];
     end;


end.
