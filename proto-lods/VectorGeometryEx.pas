unit VectorGeometryEx;

interface

uses Math, SysUtils, VectorTypes, VectorGeometry;

{$DEFINE FloatPrecision32}
{.$DEFINE FloatPrecision64}

procedure MakeAffineVector(var v : TVector3d; x, y, z : double); overload;
procedure MakeAffineVector(var v : TVector3f; x, y, z : single); overload;

procedure AddVector(var v1 : TVector3d; const v2 : TVector3d); overload;
procedure ScaleVector(var v : TVector3d; factor : double); overload;
procedure NegateVector(var v : TVector3d); overload;
procedure NormalizeVector(var v : TVector3d); overload;
procedure VectorNormLength(const v : TVector3d; var norm : TVector3d; var len : double); overload;
procedure VectorNormLength(const v : TVector3f; var norm : TVector3f; var len : single); overload;

function VectorNorm(const v : TVector3d) : double; overload;
function RSqrt(v : double) : double; overload;

function AffineVectorMake(const v : TVector3d) : TVector3f; overload;
function AffineVectorMake(const v : TVector3f) : TVector3f; overload;
function AffineDoubleVectorMake(x, y, z : double) : TVector3d;
function VectorAdd(const v1, v2 : TVector3d) : TVector3d; overload;
function VectorSubtract(const v1, v2 : TVector3d) : TVector3d; overload;
function VectorNegate(const v : TVector3d) : TVector3d; overload;
function VectorScale(const v : TVector3d; factor : double) : TVector3d; overload;
function VectorLength(const v : TVector3d) : double; overload;
function VectorDotProduct(const v1, v2 : TVector3d) : double; overload;
function VectorNormalize(const v : TVector3d) : TVector3d; overload;

function SphereVisibleRadius(distance, radius : double) : double; overload;

type
     {$IFDEF FloatPrecision64}
     TTOFloat = double;
     TTOVector = TVector3d;
     TTOMatrix = TMatrix4d;
     {$ENDIF}

     {$IFDEF FloatPrecision32}
     TTOFloat = single;
     TTOVector = TVector3f;
     TTOMatrix = TMatrix4f;
     {$ENDIF}

     TTOTransformation = class

          constructor Create;

          function Translation : TTOVector;
          function Scale : TTOVector;
          function Direction : TTOVector;
          function UpVector : TTOVector;
          function LeftVector : TTOVector;

          procedure SetTranslation(const T : TTOVector);
          procedure SetScale(const S : TTOVector);
          procedure SetDirection(const D : TTOVector);
          procedure SetUpVector(const U : TTOVector);

          procedure AddTranslation(const dT : TTOVector);
          procedure Rotate(const axis : TTOVector; angle : TTOFloat);

          private
               xMatrix : TTOMatrix;
               xTranslationMatrix, xScaleMatrix, xRotationMatrix : TTOMatrix;
               xTranslation, xScale, xDirection, xUpVector : TTOVector;

               procedure xUpdateMatrix;

     end;

implementation


procedure MakeAffineVector(var v : TVector3d; x, y, z : double);
begin
     v[0]:= x;
     v[1]:= y;
     v[2]:= z;
end;

procedure MakeAffineVector(var v : TVector3f; x, y, z : single);
begin
     v[0]:= x;
     v[1]:= y;
     v[2]:= z;
end;

function AffineVectorMake(const v : TVector3d) : TVector3f;
begin
     Result[0]:= v[0];
     Result[1]:= v[1];
     Result[2]:= v[2];
end;

function AffineVectorMake(const v : TVector3f) : TVector3f;
begin
     Result:= v;
end;

function AffineDoubleVectorMake(x, y, z : double) : TVector3d;
begin
     Result[0]:= x;
     Result[1]:= y;
     Result[2]:= z;
end;

procedure AddVector(var v1 : TVector3d; const v2 : TVector3d);
begin
     v1[0]:= v1[0] + v2[0];
     v1[1]:= v1[1] + v2[1];
     v1[2]:= v1[2] + v2[2];
end;

procedure NegateVector(var v : TVector3d);
begin
     v[0]:= -v[0];
     v[1]:= -v[1];
     v[2]:= -v[2];
end;

procedure ScaleVector(var v : TVector3d; factor : double);
begin
     v[0]:= v[0]*factor;
     v[1]:= v[1]*factor;
     v[2]:= v[2]*factor;
end;

procedure NormalizeVector(var v : TVector3d);
var
     invLen : double;
     vn : double;

begin
     vn:= VectorNorm(v);
     if vn > 0 then begin
          invLen:= RSqrt(vn);
          v[0]:= v[0]*invLen;
          v[1]:= v[1]*invLen;
          v[2]:= v[2]*invLen;
     end;
end;

procedure VectorNormLength(const v : TVector3d; var norm : TVector3d; var len : double);
begin
     len:= VectorLength(v);
     norm:= v;
     if len > 0 then
          ScaleVector(norm, 1/len);
end;

procedure VectorNormLength(const v : TVector3f; var norm : TVector3f; var len : single); overload;
begin
     len:= VectorLength(v);
     norm:= v;
     if len > 0 then
          ScaleVector(norm, 1/len);
end;

function VectorNorm(const v : TVector3d) : double; 
begin
     Result:= v[0]*v[0]+v[1]*v[1]+v[2]*v[2];
end;

function RSqrt(v : double) : double;
begin
     Result:= 1/sqrt(v);
end;

function VectorAdd(const v1, v2 : TVector3d) : TVector3d;
begin
     Result[0]:= v1[0] + v2[0];
     Result[1]:= v1[1] + v2[1];
     Result[2]:= v1[2] + v2[2];
end;

function VectorSubtract(const v1, v2 : TVector3d) : TVector3d;
begin
     Result[0]:= v1[0] - v2[0];
     Result[1]:= v1[1] - v2[1];
     Result[2]:= v1[2] - v2[2];
end;

function VectorNegate(const v : TVector3d) : TVector3d;
begin
     Result[0]:= -v[0];
     Result[1]:= -v[1];
     Result[2]:= -v[2];
end;

function VectorLength(const v : TVector3d) : double;
begin
     Result:= Sqrt(VectorNorm(v));
end;

function VectorDotProduct(const v1, v2 : TVector3d): double;
begin
     Result:= v1[0]*v2[0] + v1[1]*v2[1] + v1[2]*v2[2];
end;

function VectorScale(const v : TVector3d; factor : double) : TVector3d;
begin
     Result[0]:= v[0]*factor;
     Result[1]:= v[1]*factor;
     Result[2]:= v[2]*factor;
end;

function VectorNormalize(const v : TVector3d) : TVector3d; overload;
begin
     Result:= v;
     NormalizeVector(Result);
end;

function SphereVisibleRadius(distance, radius : double) : double;
var
   d2, r2, ir, tr : double;

begin
   d2:= distance*distance;
   r2:= radius*radius;
   ir:= Sqrt(d2 - r2);
   tr:= (d2 + r2 - ir*ir) / (2*ir);

   Result:= Sqrt(r2 + tr*tr);
end;


constructor TTOTransformation.Create;
begin
     xTranslationMatrix:= IdentityHmgMatrix;
     xScaleMatrix:= IdentityHmgMatrix;
     xRotationMatrix:= IdentityHmgMatrix;

     SetTranslation(AffineVectorMake(0, 0, 0));
     SetScale(AffineVectorMake(1, 1, 1));
end;

function TTOTransformation.Translation : TVector3f;
begin
     Result:= xTranslation;
end;

function TTOTransformation.Scale : TVector3f;
begin
     Result:= xScale;
end;

function TTOTransformation.Direction : TVector3f;
begin
     Result:= xDirection;
end;

function TTOTransformation.UpVector : TVector3f;
begin
     Result:= xUpVector;
end;

function TTOTransformation.LeftVector : TVector3f;
begin
     Result:= VectorCrossProduct(xDirection, xUpVector);
end;

procedure TTOTransformation.SetTranslation(const T : TVector3f);
begin
     xTranslation:= T;
     xTranslationMatrix:= CreateTranslationMatrix(xTranslation)
     xUpdateMatrix;
end;

procedure TTOTransformation.SetScale(const S : TVector3f);
begin
     xScale:= S;
     xScaleMatrix:= CreateScaleMatrix(xScale);
end;

procedure TTOTransformation.SetDirection(const D : TTOVector);
begin
end;

procedure TTOTransformation.SetUpVector(const U : TTOVector);
begin
end;

procedure TTOTransformation.AddTranslation(const dT : TVector3f);
begin
end;

procedure TTOTransformation.Rotate(const axis : TTOVector; angle : TTOFloat);
begin
end;

procedure TTOTransformation.xUpdateMatrix;
begin
end;

end.
