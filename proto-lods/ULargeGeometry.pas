unit ULargeGeometry;

interface

{$DEFINE LG_FLOAT64}
{.$DEFINE LG_OVERFLOW_EXCEPTION}

uses SysUtils, Math, VectorTypes, VectorGeometry;

const
     LG_Levels = 3;
     LG_Toplevel = LG_Levels-1;

     LG_BaseIntLog10 = 9;
     LG_BaseMult = 4;
     LG_TopDigit = 2000000000;

     {$IFDEF LG_FLOAT64}
     LG_MaxFloat = MaxDouble;
     {$ELSE}
     LG_MaxFloat = MaxSingle;
     {$ENDIF}

type
     // N = n[0] + n[1]*(2*MaxInt+2) + ... + n[i]*(2*MaxInt+2)^i
     LG_Number = array [0..LG_toplevel] of integer;

     LG_Vector2 = array [0..1] of LG_Number;
     LG_Vector3 = array [0..2] of LG_Number;

     PLG_Number = ^LG_Number;
     PLG_Vector2 = ^LG_Vector2;
     PLG_Vector3 = ^LG_Vector3;

     {$IFDEF LG_FLOAT64}
     LG_Float = double;
     {$ELSE}
     LG_Float = single;
     {$ENDIF}

procedure LG_MakeZero         (var n : LG_Number);
procedure LG_MakeNumber       (var n : LG_Number; f : LG_Float); overload;
procedure LG_MakeNumber       (var n : LG_Number; i : integer); overload;
procedure LG_MakeNumber       (var n : LG_Number; n2 : PLG_Number); overload;
procedure LG_NegateNumber     (var n : LG_Number);
procedure LG_AddNumber        (var n : LG_Number; add : PLG_Number);
procedure LG_SubtractNumber   (var n : LG_Number; subtract : PLG_Number);
procedure LG_AddFloat         (var n : LG_Number; f : LG_Float);
procedure LG_AddInteger       (var n : LG_Number; i : integer);

function LG_NumberMake        (f : LG_Float) : LG_Number; overload;
function LG_NumberMake        (i : integer) : LG_Number; overload;
function LG_NumberMake        (n : PLG_Number) : LG_Number; overload;
function LG_NumberNegate      (n : PLG_Number) : LG_Number;
function LG_NumberAdd         (n, add : PLG_Number) : LG_Number;
function LG_NumberSubtract    (n, subtract : PLG_Number) : LG_Number;

function LG_ToStr(n : PLG_Number; delim : string = '  .  ') : string;

// N*10^p = n[0]*10^p + n[1]*10^(LG_BaseLog10 + p) + ... + n[i]*10^(LG_BaseLog10*i + p)
function LG_ToFloat(n : PLG_Number; decExponent : LG_Float = 0.0) : LG_Float;

implementation


     procedure LG_MakeZero(var n : LG_Number);
     var i : integer;
     begin
          for i:= 0 to LG_toplevel do
               n[i]:= 0;
     end;

     procedure LG_MakeNumber(var n : LG_Number; f : LG_Float);
     begin
          LG_MakeZero(n);
          n[0]:= round(f);
     end;

     procedure LG_MakeNumber(var n : LG_Number; i : integer);
     begin
          LG_MakeZero(n);
          n[0]:= i;
     end;

     procedure LG_MakeNumber(var n : LG_Number; n2 : PLG_Number);
     var i : integer;
     begin
          for i:= 0 to LG_toplevel do
               n[i]:= n2[i];
     end;

     procedure LG_NegateNumber(var n : LG_Number);
     var i : integer;
     begin
          for i:= 0 to LG_toplevel do
               n[i]:= -n[i];
     end;

     procedure LG_AddNumber(var n : LG_Number; add : PLG_Number);
     var i, rem, radd : integer;
         res64 : Int64;
     begin
          rem:= 0;
          for i:= 0 to LG_toplevel do begin
               //radd:= rem + add[i];
               res64:= n[i] + rem + add[i];
               rem:= 0;

               if res64 >= LG_TopDigit then begin
                    n[i]:= res64 - LG_TopDigit - LG_TopDigit;
                    rem:= 1;
                    continue;
               end;

               if res64 < -LG_TopDigit then begin
                    n[i]:= res64 + LG_TopDigit + LG_TopDigit;
                    rem:= -1;
                    continue;
               end;

               if rem = 0 then
                    n[i]:= res64;

          end;

          {$IFDEF LG_OVERFLOW_EXCEPTION}
          if rem <> 0 then raise Exception.Create('ULargeGeometry.LG_AddNumber: large number overflow!');
          {$ENDIF}
     end;

     procedure LG_SubtractNumber(var n : LG_Number; subtract : PLG_Number);
     var add : LG_Number;
     begin
          add:= LG_NumberNegate(subtract);
          LG_AddNumber(n, @add);
     end;

     procedure LG_AddFloat(var n : LG_Number; f : LG_Float);
     var add : LG_Number;
     begin
          add:= LG_NumberMake(f);
          LG_AddNumber(n, @add);
     end;

     procedure LG_AddInteger(var n : LG_Number; i : integer);
     var add : LG_Number;
     begin
          add:= LG_NumberMake(i);
          LG_AddNumber(n, @add);
     end;

     function LG_NumberMake(f : LG_Float) : LG_Number;
     begin
          LG_MakeNumber(Result, f);
     end;

     function LG_NumberMake(i : integer) : LG_Number;
     begin
          LG_MakeNumber(Result, i);
     end;

     function LG_NumberMake(n : PLG_Number) : LG_Number;
     begin
          LG_MakeNumber(Result, n);
     end;

     function LG_NumberNegate(n : PLG_Number) : LG_Number;
     begin
          Result:= n^;
          LG_NegateNumber(Result);
     end;

     function LG_NumberAdd(n, add : PLG_Number) : LG_Number;
     begin
          Result:= n^;
          LG_AddNumber(Result, add);
     end;

     function LG_NumberSubtract(n, subtract : PLG_Number) : LG_Number;
     begin
          Result:= n^;
          LG_SubtractNumber(Result, subtract);
     end;

     function LG_ToStr(n : PLG_Number; delim : string) : string;
     var i : integer;

     begin
          Result:= '';
          for i:= 0 to LG_toplevel do begin
               Result:= Result + IntToStr(n[i]);
               if i < LG_toplevel then
                    Result:= Result + delim;
          end;     
     end;

     // N*10^p = n[0]*10^p + n[1]*10^(LG_BaseLog10 + p) + ... + n[i]*10^(LG_BaseLog10*i + p)
     function LG_ToFloat(n : PLG_Number; decExponent : LG_Float = 0.0) : LG_Float;
     var i : integer;

     begin
          Result:= 0;
          for i:= 0 to LG_toplevel do
               Result:= Result + n^[i] * Power(LG_BaseMult, i) * Power(10, LG_BaseIntLog10*i + decExponent);
     end;


initialization

end.
