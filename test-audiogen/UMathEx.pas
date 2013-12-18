unit UMathEx;

interface

uses Math, SysUtils;

const
	invSqrt2Pi = 1.0/2.506628274631;

function SmoothStep(edge0, edge1, x : single) : single;
function CosineInterpolation(y1, y2, t : single) : single;
function GaussianKernel(x, sigma : single) : single;

implementation

function SmoothStep(edge0, edge1, x : single) : single;
var t : single;
begin
	t:= max(min((x - edge0) / (edge1 - edge0), 1.0), 0.0);
   Result:= t*t*(3-2*t);
end;

function CosineInterpolation(y1, y2, t : single) : single;
var tc : single;
begin
	tc:= (1.0-cos(t*pi))*0.5;
   Result:= y1*(1.0-tc) + y2*tc;
end;

function GaussianKernel(x, sigma : single) : single;
begin
	Result:= invSqrt2Pi/sigma * exp(-x*x*0.5/(sigma*sigma));
end;

end.
