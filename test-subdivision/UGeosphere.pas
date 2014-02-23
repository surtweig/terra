unit UGeosphere;

interface

uses
	SysUtils, Math, VectorTypes, VectorGeometry, Classes, Types, PerlinNoise;

const
	IcosahedronTriangles = 20;

	IcosahedronTrianglePairs : array [0..IcosahedronTriangles-1] of TVector2i =
	( (X : 0; Y : 1), (X : 0; Y : 1), (X : 2; Y : 3), (X : 2; Y : 3), (X : 15; Y : 4),
	  (X : 14; Y : 5), (X : 19; Y : 6), (X : 16; Y : 7), (X : 12; Y : 8), (X : 18; Y : 9),
	  (X : 13; Y : 10), (X : 17; Y : 11), (X : 12; Y : 8), (X : 13; Y : 10), (X : 14; Y : 5),
	  (X : 15; Y : 4), (X : 16; Y : 7), (X : 17; Y : 11), (X : 18; Y : 9), (X : 19; Y : 6) );

type
	//TIcosahedronVertexAdjacency = array of integer;

	TGeoNode = packed record
		position, normal : TVector3f;
		radius : single;
		adjacency : array of TIntegerDynArray;
		//index, level : integer;
	end;
	//PGeoNode = ^TGeoNode;

  	TGeoTrianglesTreeNode = record
		vertices : TVector3i;
		childTreeNodes : array [0..3] of integer;
   end;

	TGeoVertex = record
		position, normal : TVector3f;
		uv : TTexPoint;
	end;

	TGeoMesh = array of TGeoVertex;

   TTrianglesList = array of TVector4i; // 0..2 - nodes indexes; 3 - triangle index

	TProgressCallback = procedure (progress : single);

	TGeosphere = class
		PerlinOctaves : integer;
		PerlinPersistence, PerlinLacunarity : single;
      NoiseFactor, IcoNoiseFactor : single;
		NoiseMinOctave, NoiseMaxOctave : integer;
		Scale : TVector3f;
		xAverageRadius : single;

		constructor Create (subdivisions : integer; aNoiseFactor : single; aCratersCount, aMountainsCount, aCanyonsCount : integer; progressCallback : TProgressCallback = nil);

		function GetNode(index : integer) : TGeoNode;
		function GetTriangleNode(index : integer) : TVector3i;
		function NodesCount : integer;
		function FindNodesCommonAdjacency(index1, index2, level : integer) : integer;
		function GetVertex(vi : integer) : TVector3f;
		function GetNormal(vi : integer) : TVector3f;
		function GetTexUV(nodeIndex : integer; triA, triB : integer) : TVector2f;
		function TrianglesCount : integer;
		function GetHeightAtPoint(p : TVector3f) : single;
		procedure GetTriangleAtPoint(p : TVector3f; var ptA, ptB, ptC : TVector3f; depth : integer = -1);
		procedure GetTriangleChildren(parentTriangle : integer; var childTriangles : TIntegerDynArray; depth : integer = -1);
		procedure GenerateMesh(var mesh : TGeoMesh; baseTriangleNode : integer = -1; depth : integer = -1; icoSide : integer = -1);

		private
			xNodes : array of TGeoNode;
			xTriangles : array of TVector4i;
			xTrianglesTreeNodes : array of TGeoTrianglesTreeNode;

			procedure xInitIcosahedron;
			procedure xBuildNormals(sharpness : single);
			procedure xNewellBuildNormals;
			procedure xCalcAverageRadius;

		protected
			xSubdivisionLevel : integer;
			xPerlinNoise : TPerlin3DNoise;
			xPerlinSpectrum : array of single;
			xPerlinSpectrumNorm : single;

			procedure xSubdivide;
			function xAddNode : integer;
			procedure xNodeAddAdjacency(nodeIndex, level, adjNodeIndex : integer);
			procedure xConnectNodes(node1index, node2index, level : integer);
			procedure xSmooth;
			procedure xTransform;
			procedure xApplyPerlinNoise(startOctave : integer = 0; noiseScale : single = 1.0);
			procedure xMakeCrater(centerNodeIndex : integer; craterRadius, craterDepth : single);
			procedure xMakeMountain(startNodeIndex, steps : integer; height : single; dir : TVector3f);
			function xAddTriangleTreeNode(v : TVector4i; parentIndex : integer = -1) : integer;
			function xGetTriangleAtDir(dir : TVector3f; triangle : integer; depth : integer = -1) : integer;
	end;

implementation

var
	debugLog : TStringList;

function VectorsRMS(v1, v2 : TVector3f) : TVector3f;
begin
	Result.x:= sqrt( 0.5*(v1.x*v1.x + v2.x*v2.x) );
	Result.y:= sqrt( 0.5*(v1.y*v1.y + v2.y*v2.y) );
	Result.z:= sqrt( 0.5*(v1.z*v1.z + v2.z*v2.z) );
end;

function VectorMultVector(v, s : TVector3f) : TVector3f;
begin
   Result.X:= v.X * s.X;
   Result.Y:= v.Y * s.Y;
   Result.Z:= v.Z * s.Z;
end;

function VectorDivVector(v, s : TVector3f) : TVector3f;
begin
   Result.X:= v.X / s.X;
   Result.Y:= v.Y / s.Y;
   Result.Z:= v.Z / s.Z;
end;

function SmoothStep(edge0, edge1, x : single) : single;
var t : single;
begin
	t:= max(min((x - edge0) / (edge1 - edge0), 1.0), 0.0);
   Result:= t;//*t*(3-2*t);
end;

procedure WriteLog(s : string; forceSave : boolean = false);
begin
   debugLog.Add(s);
   if forceSave then
		debugLog.SaveToFile('ugeosphere.log');
end;

constructor TGeosphere.Create(subdivisions : integer; aNoiseFactor : single; aCratersCount, aMountainsCount, aCanyonsCount : integer; progressCallback : TProgressCallback);
var i : integer;
    crSize : single;
begin
	xPerlinNoise:= TPerlin3DNoise.Create(0);
	PerlinOctaves:= 12;
	PerlinPersistence:= 1.5;
	PerlinLacunarity:= 2;

	setlength(xPerlinSpectrum, PerlinOctaves);
	xPerlinSpectrumNorm:= 0;
	for i:= 0 to high(xPerlinSpectrum) do begin
		xPerlinSpectrum[i]:= Power( IntPower(PerlinLacunarity, i), -PerlinPersistence );
		xPerlinSpectrumNorm:= xPerlinSpectrumNorm + xPerlinSpectrum[i];
	end;
	xPerlinSpectrumNorm:= 1/xPerlinSpectrumNorm;

	setlength(xNodes, 0);
	setlength(xTriangles, 0);
	setlength(xTrianglesTreeNodes, 0);

	Scale:= AffineVectorMake(1, 1, 1);

	IcoNoiseFactor:= 0.0;
	xInitIcosahedron;

   xSubdivisionLevel:= 0;
	NoiseFactor:= aNoiseFactor;//10.0;
	NoiseMinOctave:= 1;
	NoiseMaxOctave:= 4;

   progressCallback(0.0);

	for i:= 1 to subdivisions do begin
		xSubdivide;
		xSubdivisionLevel:= i;

	  //	if i mod 1 = 0 then xSmooth;
	end;

	//xSmooth;

 (*  progressCallback(0.25);

  	for i:= 1 to aMountainsCount{100} do begin
      xMakeMountain(Random(length(xNodes)), 2000, 0.0025, VectorNormalize(AffineVectorMake(Random-0.5, Random-0.5, Random-0.5)));
		if i mod 40 = 0 then
			xSmooth;
   end;

   progressCallback(0.5);

  	for i:= 1 to aCanyonsCount{100} do begin
      xMakeMountain(Random(length(xNodes)), 2000, -0.00125, VectorNormalize(AffineVectorMake(Random-0.5, Random-0.5, Random-0.5)));
		if i mod 40 = 0 then
			xSmooth;
   end;      *)


 (*	for i:= 1 to 3 do
		xSmooth;

	xTransform;

  //	for i:= 1 to 3 do
//	   xSmooth; *)

	//xApplyPerlinNoise;

	progressCallback(0.75);

   for i:= 1 to aCratersCount{2000} do begin
		crSize:= exp(RandG(0, 1))*0.08;
		if crSize > 2.5 then crSize:= 2.5;
		xMakeCrater(Random(length(xNodes)), 0.005+crSize*0.15, 0.005+crSize*0.035);
		if i mod 201 = 0 then
			xSmooth;
	end;

	//xApplyPerlinNoise(4, 1.1);

	//for i:= 1 to 10 do
	//	xSmooth;

	progressCallback(1.0);

	//xBuildNormals(0.075);
	xNewellBuildNormals;

	xCalcAverageRadius;
end;

function TGeosphere.GetNode(index : integer) : TGeoNode;
begin
	Result:= xNodes[index];
end;

function TGeosphere.NodesCount : integer;
begin
   Result:= length(xNodes);
end;

function TGeosphere.FindNodesCommonAdjacency(index1, index2, level : integer) : integer;
var //xNode1, xNode2 : PGeoNode;
	 i, j : integer;

begin
	//xNode1:= @xNodes[index1];
	//xNode2:= @xNodes[index2];
	Result:= -1;

	if (length(xNodes[index1].adjacency) <= level) or (length(xNodes[index2].adjacency) <= level) then
		Exit;

	for i := 0 to high(xNodes[index1].adjacency[level]) do
		for j := 0 to high(xNodes[index2].adjacency[level]) do
			if xNodes[index1].adjacency[level][i] = xNodes[index2].adjacency[level][j] then begin
				Result:= xNodes[index1].adjacency[level][i];
				Exit;
         end;
end;

function TGeosphere.xAddNode : integer;
var i : integer;

begin
	i:= length(xNodes);
	setlength(xNodes, i+1);
	//xNodes[i].index:= i;
	//xNodes[i].level:= 0;
	xNodes[i].radius:= 1;
	setlength(xNodes[i].adjacency, 0);
	Result:= i;//@xNodes[i];
end;

procedure TGeosphere.xNodeAddAdjacency(nodeIndex, level, adjNodeIndex : integer);
var i, h : integer;
	 //node : PGeoNode;

begin
	//node:= @xNodes[nodeIndex];
	h:= length(xNodes[nodeIndex].adjacency)-1;
	if h < level then begin
		setlength(xNodes[nodeIndex].adjacency, level+1);
		for i := h+1 to level do
			setlength(xNodes[nodeIndex].adjacency[i], 0);
	end;

	h:= length(xNodes[nodeIndex].adjacency[level]);
	setlength(xNodes[nodeIndex].adjacency[level], h+1);
	xNodes[nodeIndex].adjacency[level][h]:= adjNodeIndex;
end;

procedure TGeosphere.xConnectNodes(node1index, node2index, level : integer);
begin
	xNodeAddAdjacency(node1index, level, node2index);
	xNodeAddAdjacency(node2index, level, node1index);
end;

function TGeosphere.GetVertex(vi : integer) : TVector3f;
var tri, i : integer;

begin
	tri:= vi div 3;
	i:= vi mod 3;
	Result:= xNodes[xTriangles[tri].v[i]].position;
end;

function TGeosphere.GetNormal(vi : integer) : TVector3f;
var tri, i : integer;

begin
	tri:= vi div 3;
	i:= vi mod 3;
	Result:= xNodes[xTriangles[tri].v[i]].normal;
end;

(*
float saturate(float x, float p)
{
	if (x < 0.5)
		return 0.5*pow(2.0*x, p);
	else
		return 1 - 0.5*pow(2.0*(1.0-x), p);
}
*)
function saturate(x, p : single) : single;
begin
	if x < 0.5 then
		Result:= 0.5*Power(2.0*x, p)
	else
		Result:= 1 - 0.5*Power(2.0*(1.0-x), p);
end;

function TGeosphere.GetTexUV(nodeIndex : integer; triA, triB : integer) : TVector2f;
var vA, vB, vC1, vC2, p : TVector3f;
    iA, iB, iC1, iC2, i, j : integer;
	 alpha1, alpha2, beta1, beta2, u2, v2, u, v, thetaA, thetaB, theta1, theta2, area, s, lrp : single;
	 comm : boolean;

begin
	iC1:= -1;
	iC2:= -1;
	iA:= -1;
	iB:= -1;
{	for i:= 0 to 2 do begin
		for j:= 0 to 2 do begin
			if xTrianglesTreeNodes[triA].vertices.v[i] = xTrianglesTreeNodes[triB].vertices.v[j] then begin
				if (xTriangles[triA].v[i] <> iC1) and (xTriangles[triA].v[i] <> iC2) then begin
					if (iC1 = -1) then
						iC1:= xTrianglesTreeNodes[triA].vertices.v[i]
					else
						iC2:= xTrianglesTreeNodes[triA].vertices.v[i]
				end;
			end;
		end;
	end;}

	for i:= 0 to 2 do begin
		comm:= false;
		for j:= 0 to 2 do begin
			if xTrianglesTreeNodes[triA].vertices.v[i] = xTrianglesTreeNodes[triB].vertices.v[j] then
				comm:= true;
		end;
		if comm then begin
			if iC1 = -1 then
				iC1:= xTrianglesTreeNodes[triA].vertices.v[i]
			else
				iC2:= xTrianglesTreeNodes[triA].vertices.v[i];
		end else
			iA:= xTrianglesTreeNodes[triA].vertices.v[i];
	end;

	for j:= 0 to 2 do
		if (xTrianglesTreeNodes[triB].vertices.v[j] <> iC1) and (xTrianglesTreeNodes[triB].vertices.v[j] <> iC2) then begin
			iB:= xTrianglesTreeNodes[triB].vertices.v[j];
			Break;
		end;

	//iA:= xTrianglesTreeNodes[triA].vertices.v[0] + xTrianglesTreeNodes[triA].vertices.v[1] + xTrianglesTreeNodes[triA].vertices.v[2] - iC1 - iC2;
  //	iB:= xTrianglesTreeNodes[triB].vertices.v[0] + xTrianglesTreeNodes[triB].vertices.v[1] + xTrianglesTreeNodes[triB].vertices.v[2] - iC1 - iC2;

	vA:= VectorNormalize(xNodes[iA].position);
	vB:= VectorNormalize(xNodes[iB].position);
	vC1:= VectorNormalize(xNodes[iC1].position);
	vC2:= VectorNormalize(xNodes[iC2].position);
	p:= VectorNormalize(xNodes[nodeIndex].position);

	alpha1:= 2*Math.ArcSin(0.5*VectorLength(VectorSubtract(vA, vC1)));
	alpha2:= 2*Math.ArcSin(0.5*VectorLength(VectorSubtract(vA, vC2)));
	thetaA:= 2*Math.ArcSin(0.5*VectorLength(VectorSubtract(vA, p)));
	theta1:= 2*Math.ArcSin(0.5*VectorLength(VectorSubtract(vC1, p)));
	theta2:= 2*Math.ArcSin(0.5*VectorLength(VectorSubtract(vC2, p)));

	// A
	s:= (alpha1+thetaA+theta1)*0.5;
	area:= sqrt( s * (s-thetaA) * (s-theta1) * (s-alpha1) );

	//area = 0.5*alpha1*u
	u:= 2*area/alpha1;

	s:= (alpha2+thetaA+theta2)*0.5;
	area:= sqrt( s * (s-thetaA) * (s-theta2) * (s-alpha2) );

	v:= 2*area/alpha2;

	// B
	beta1:= 2*Math.ArcSin(0.5*VectorLength(VectorSubtract(vB, vC1)));
	beta2:= 2*Math.ArcSin(0.5*VectorLength(VectorSubtract(vB, vC2)));
	thetaB:= 2*Math.ArcSin(0.5*VectorLength(VectorSubtract(vB, p)));
	theta1:= 2*Math.ArcSin(0.5*VectorLength(VectorSubtract(vC1, p)));
	theta2:= 2*Math.ArcSin(0.5*VectorLength(VectorSubtract(vC2, p)));

	s:= (beta1+thetaB+theta1)*0.5;
	area:= sqrt( s * (s-thetaB) * (s-theta1) * (s-beta1) );

	//area = 0.5*alpha1*u
	u2:= 2*area/beta1;

	s:= (beta2+thetaB+theta2)*0.5;
	area:= sqrt( s * (s-thetaB) * (s-theta2) * (s-beta2) );

	v2:= 2*area/beta2;

	debugLog.Add(FloatToStr(u2) + #9 + FloatToStr(u));

	{if (thetaA < thetaB) then begin
		Result.X:= u;
		Result.Y:= v;
	end else begin
		Result.X:= 1-v2;
		Result.Y:= 1-u2;
	end;}

	lrp:= saturate(thetaA/(thetaA+thetaB), 16.0);
	Result.X:= Lerp(u, 1-v2, lrp);
	Result.Y:= Lerp(v, 1-u2, lrp);
end;

function TGeosphere.GetTriangleNode(index : integer) : TVector3i;
begin
	Result:= xTrianglesTreeNodes[index].vertices;
end;

function TGeosphere.TrianglesCount : integer;
begin
	Result:= length(xTriangles);
end;

procedure TGeosphere.xInitIcosahedron;
const
	A = 0.5;
	B = 0.30901699437; // 1/(1+Sqrt(5))

	icoverts: array [0 .. 11] of TAffineVector = ((X: 0; Y: - B; Z: - A),
		(X: 0; Y: - B; Z: A), (X: 0; Y: B; Z: - A), (X: 0; Y: B; Z: A), (X: - A;
		Y: 0; Z: - B), (X: - A; Y: 0; Z: B), (X: A; Y: 0; Z: - B), (X: A; Y: 0;
		Z: B), (X: - B; Y: - A; Z: 0), (X: - B; Y: A; Z: 0), (X: B; Y: - A; Z: 0),
		(X: B; Y: A; Z: 0));
	icotris: array [0 .. 19] of array [0 .. 2] of integer =
		((2, 9, 11), (3, 11, 9), (3, 5, 1), (3, 1, 7), (2, 6, 0),
		(2, 0, 4), (1, 8, 10), (0, 10, 8), (9, 4, 5), (8, 5, 4), (11, 7, 6),
		(10, 6, 7), (3, 9, 5), (3, 7, 11), (2, 4, 9), (2, 11, 6), (0, 8, 4),
		(0, 6, 10), (1, 5, 8), (1, 10, 7));
	icoadj: array [0 .. 11] of array [0..4] of integer =
		((8, 2, 4, 10, 6), (8, 10, 3, 5, 7), (0, 9, 11, 4, 6), (7, 9, 11, 5, 1),
		(0, 9, 2, 5, 8), (8, 1, 3, 4, 9), (0, 2, 11, 10, 7), (11, 1, 10, 3, 6),
		(0, 1, 10, 4, 5), (3, 2, 11, 4, 5), (8, 1, 6, 0, 7), (9, 2, 3, 6, 7));

var
	i, j, n : integer;

begin
	setlength(xNodes, length(icoverts));
	for i := 0 to high(xNodes) do begin
		xNodes[i].position:= VectorAdd(VectorNormalize(icoverts[i]), VectorScale(AffineVectorMake(Random-0.5, Random-0.5, Random-0.5), IcoNoiseFactor));
      //xNodes[i].position.X:= xNodes[i].position.X * 0.25;
		xNodes[i].radius:= VectorLength(xNodes[i].position);
	  //	xNodes[i].radius:= xNodes[i].radius;// + Random*0.2;
	  //	ScaleVector(xNodes[i].position, xNodes[i].radius);

		setlength(xNodes[i].adjacency, 1);
		setlength(xNodes[i].adjacency[0], 5);
		for j := 0 to 4 do
			xNodes[i].adjacency[0][j]:= icoadj[i][j];
		//xNodes[i].index:= i;
	  	//xNodes[i].level:= 0;

	end;

	setlength(xTriangles, length(icotris));
	for i := 0 to high(xTriangles) do begin
		xTriangles[i]:= Vector4iMake(icotris[i][0], icotris[i][1], icotris[i][2], i);
      xAddTriangleTreeNode(xTriangles[i]);
   end;
end;

procedure TGeosphere.xSubdivide;
var tri, i, j, range, acc, treeNodeIndex : integer;
    //Nab, Nbc, Nca : integer;
    Na, Nb, Nc, N1, N2, N12 : integer;
    newNs : array [0..2] of integer;
begin
	range:= high(xTriangles);
	for tri := 0 to range do begin
		Na:= xTriangles[tri].v[0];
		Nb:= xTriangles[tri].v[1];
		Nc:= xTriangles[tri].v[2];
		//ForceLog('tri = ' + IntToStr(tri) + '; xTri[tri] = ' + IntToStr(xTriangles[tri].v[0]) + ', ' + IntToStr(xTriangles[tri].v[1]) + ', ' + IntToStr(xTriangles[tri].v[2]));

		for i:= 0 to 2 do begin
         N1:= xTriangles[tri].v[i];
			N2:= xTriangles[tri].v[(i+1) mod 3];
			N12:= FindNodesCommonAdjacency(N1, N2, xSubdivisionLevel+1);
			if N12 = -1 then begin
				N12:= xAddNode;
				//xNodes[N12].level:= xSubdivisionLevel+1;
         	xNodes[N12].position:= VectorNormalize(VectorAdd(xNodes[N1].position, xNodes[N2].position));

				//xNodes[N12].position:= VectorScale(VectorAdd(xNodes[N1].position, xNodes[N2].position), 0.5);
				xNodes[N12].radius:= (xNodes[N1].radius+xNodes[N2].radius)*0.5;
				ScaleVector(xNodes[N12].position, xNodes[N12].radius);

				{if xSubdivisionLevel >= 0 then begin
					acc:= 0;
					xNodes[N12].radius:= 0;
					for j:= 0 to high(xNodes[N1].adjacency[xSubdivisionLevel]) do begin
         	   	xNodes[N12].radius:= xNodes[N12].radius + xNodes[xNodes[N1].adjacency[xSubdivisionLevel][j]].radius;
						acc:= acc + 1;
	            end;
					for j:= 0 to high(xNodes[N2].adjacency[xSubdivisionLevel]) do begin
      	      	xNodes[N12].radius:= xNodes[N12].radius + xNodes[xNodes[N2].adjacency[xSubdivisionLevel][j]].radius;
						acc:= acc + 1;
            	end;
					xNodes[N12].radius:= xNodes[N12].radius/acc;
            end; }

				{if (xSubdivisionLevel >= NoiseMinOctave) and (xSubdivisionLevel <= NoiseMaxOctave) then begin
            	xNodes[N12].radius:= xNodes[N12].radius + Random*NoiseFactor*0.1/power(xSubdivisionLevel, 2);
					//AddVector(xNodes[N12].position, VectorScale(AffineVectorMake(Random-0.5, Random-0.5, Random-0.5), 0.2/(xSubdivisionLevel+1)));
	            //xNodes[N12].radius:= VectorLength(xNodes[N12].position);
            end;
            ScaleVector(xNodes[N12].position, xNodes[N12].radius);}

				xConnectNodes(N12, N1, xSubdivisionLevel+1);
				xConnectNodes(N12, N2, xSubdivisionLevel+1);
			end;
			newNs[i]:= N12;
      end;

      xConnectNodes(newNs[0], newNs[1], xSubdivisionLevel+1);
      xConnectNodes(newNs[1], newNs[2], xSubdivisionLevel+1);
      xConnectNodes(newNs[2], newNs[0], xSubdivisionLevel+1);

		i:= length(xTriangles);
		setlength(xTriangles, i+3);
		j:= xTriangles[tri].W;

		xTriangles[tri]:= Vector4iMake(Na, newNs[0], newNs[2]);
		treeNodeIndex:= xAddTriangleTreeNode(xTriangles[tri], j);
		xTriangles[tri].W:= treeNodeIndex;

		xTriangles[i]:= Vector4iMake(Nb, newNs[1], newNs[0]);
		treeNodeIndex:= xAddTriangleTreeNode(xTriangles[i], j);
		xTriangles[i].W:= treeNodeIndex;

		xTriangles[i+1]:= Vector4iMake(Nc, newNs[2], newNs[1]);
		treeNodeIndex:= xAddTriangleTreeNode(xTriangles[i+1], j);
		xTriangles[i+1].W:= treeNodeIndex;

		xTriangles[i+2]:= Vector4iMake(newNs[0], newNs[1], newNs[2]);
		treeNodeIndex:= xAddTriangleTreeNode(xTriangles[i+2], j);
		xTriangles[i+2].W:= treeNodeIndex;

		{Nab:= FindNodesCommonAdjacency(Na, Nb, xSubdivisionLevel+1);
		if Nab = -1 then begin
			Nab:= xAddNode;
			xNodes[Nab].level:= xSubdivisionLevel+1;
         xNodes[Nab].position:= VectorNormalize(VectorAdd(xNodes[Na].position, xNodes[Nb].position));
         //xNodes[Nab].position:= VectorsRMS(xNodes[Na].position, xNodes[Nb].position);
			xConnectNodes(Nab, Na, xSubdivisionLevel+1);
			xConnectNodes(Nab, Nb, xSubdivisionLevel+1);
		end;

		Nbc:= FindNodesCommonAdjacency(Nb, Nc, xSubdivisionLevel+1);
		if Nbc = -1 then begin
			Nbc:= xAddNode;
			xNodes[Nbc].level:= xSubdivisionLevel+1;
         xNodes[Nbc].position:= VectorNormalize(VectorAdd(xNodes[Nb].position, xNodes[Nc].position));
         //xNodes[Nbc].position:= VectorsRMS(xNodes[Nb].position, xNodes[Nc].position);
			xConnectNodes(Nbc, Nb, xSubdivisionLevel+1);
			xConnectNodes(Nbc, Nc, xSubdivisionLevel+1);
		end;

		Nca:= FindNodesCommonAdjacency(Nc, Na, xSubdivisionLevel+1);
		if Nca = -1 then begin
			Nca:= xAddNode;
			xNodes[Nca].level:= xSubdivisionLevel+1;
         xNodes[Nca].position:= VectorNormalize(VectorAdd(xNodes[Nc].position, xNodes[Na].position));
         //xNodes[Nca].position:= VectorsRMS(xNodes[Nc].position, xNodes[Na].position);
			xConnectNodes(Nca, Nc, xSubdivisionLevel+1);
			xConnectNodes(Nca, Na, xSubdivisionLevel+1);
		end;}

      {xConnectNodes(Nab, Nbc, xSubdivisionLevel+1);
      xConnectNodes(Nbc, Nca, xSubdivisionLevel+1);
      xConnectNodes(Nca, Nab, xSubdivisionLevel+1);

		i:= length(xTriangles);
		setlength(xTriangles, i+3);
		xTriangles[tri]:= Vector3iMake(Na, Nab, Nca);
		xTriangles[i]:=   Vector3iMake(Nb, Nbc, Nab);
		xTriangles[i+1]:= Vector3iMake(Nc, Nca, Nbc);
		xTriangles[i+2]:= Vector3iMake(Nab, Nbc, Nca);}
	end;
end;

procedure TGeosphere.xBuildNormals(sharpness : single);
var i, j, lev, adjI : integer;
    n, nPos, adjNPos, offset  : TVector3f;
    hN, hAdj : single;

begin
	for i:= 0 to high(xNodes) do begin
		nPos:= VectorNormalize(xNodes[i].position);
      hN:= VectorLength(xNodes[i].position);
		n:= nPos;
		lev:= high(xNodes[i].adjacency);

		for j:= 0 to high(xNodes[i].adjacency[lev]) do begin
			adjI:= xNodes[i].adjacency[lev][j];
      	adjNPos:= VectorNormalize(xNodes[adjI].position);
			hAdj:= VectorLength(xNodes[adjI].position);
			offset:= VectorSubtract(adjNPos, nPos);
			ScaleVector(offset, (hN-hAdj)*sharpness/sqr(VectorLength(offset)));
			AddVector(n, offset);
      end;

		NormalizeVector(n);
      xNodes[i].normal:= n;
   end;
end;

procedure TGeosphere.xNewellBuildNormals;
var i, j, k, highlev, icurrent, inext, ifirst : integer;
    vcurrent, vnext : TVector3f;
    bnext : boolean;
    n : TVector3f;

begin
    for i:= 0 to high(xNodes) do begin
		n:= NullVector;
		highlev:= high(xNodes[i].adjacency);
		vcurrent:= xNodes[i].position;
      icurrent:= -1;
      inext:= xNodes[i].adjacency[highlev][0];
      vnext:= xNodes[inext].position;
      ifirst:= inext;

      repeat
         n.X:= n.X + (vcurrent.Y-vnext.Y) * (vcurrent.Z+vnext.Z);
         n.Y:= n.Y + (vcurrent.Z-vnext.Z) * (vcurrent.X+vnext.X);
         n.Z:= n.Z + (vcurrent.X-vnext.X) * (vcurrent.Y+vnext.Y);

         bnext:= false;
         for j:= 0 to high(xNodes[i].adjacency[highlev]) do begin
         	for k:= 0 to high(xNodes[inext].adjacency[highlev]) do begin
               if xNodes[i].adjacency[highlev][j] = xNodes[inext].adjacency[highlev][k] then
               	if xNodes[i].adjacency[highlev][j] <> icurrent then begin
                     icurrent:= inext;
                     inext:= xNodes[i].adjacency[highlev][j];
                     bnext:= true;
                     break;
                  end;
            end;
            if bnext then break;
         end;

         vcurrent:= vnext;
         vnext:= xNodes[inext].position;

      until inext = ifirst;

    	{for j:= 0 to high(xNodes[i].adjacency[highlev]) do begin
      	vnext:= xNodes[xNodes[i].adjacency[highlev][j]].position;

         n.X:= n.X + (vcurrent.Y-vnext.Y) * (vcurrent.Z+vnext.Z);
         n.Y:= n.Y + (vcurrent.Z-vnext.Z) * (vcurrent.X+vnext.X);
         n.Z:= n.Z + (vcurrent.X-vnext.X) * (vcurrent.Y+vnext.Y);

         vcurrent:= vnext;
		end;}

      vnext:= xNodes[i].position;
      n.X:= n.X + (vcurrent.Y-vnext.Y) * (vcurrent.Z+vnext.Z);
      n.Y:= n.Y + (vcurrent.Z-vnext.Z) * (vcurrent.X+vnext.X);
      n.Z:= n.Z + (vcurrent.X-vnext.X) * (vcurrent.Y+vnext.Y);

      NormalizeVector(n);

		if VectorDotProduct(n, VectorNormalize(xNodes[i].position)) < 0 then
      	NegateVector(n);

      xNodes[i].normal:= n;
	end;
end;

procedure TGeosphere.xSmooth;
var i, j, lev : integer;
    acc : single;

begin
	for i:= 0 to high(xNodes) do begin
		acc:= xNodes[i].radius;
		lev:= high(xNodes[i].adjacency);
		for j:= 0 to high(xNodes[i].adjacency[lev]) do begin
			acc:= acc + xNodes[xNodes[i].adjacency[lev][j]].radius;
      end;
		acc:= acc / (length(xNodes[i].adjacency[lev])+1);
		xNodes[i].radius:= acc;
   end;

   for i:= 0 to high(xNodes) do begin
   	xNodes[i].position:= VectorScale(VectorNormalize(xNodes[i].position), xNodes[i].radius);
   end;
end;

procedure TGeosphere.xTransform;
var i : integer;
    minr, maxr, avgr, r : single;
begin
	avgr:= 0;
   minr:= xNodes[0].radius;
   maxr:= 0;
	for i:= 0 to high(xNodes) do begin
		avgr:= avgr + xNodes[i].radius;
		if xNodes[i].radius < minr then
			minr:= xNodes[i].radius;
      if xNodes[i].radius > maxr then
      	maxr:= xNodes[i].radius;
   end;

	avgr:= avgr / length(xNodes);

	for i:= 0 to high(xNodes) do begin
		r:= xNodes[i].radius;

      //r:= minr + abs(r - avgr);
      //r:= r + sin(r*20)*0.032 + sin(r*10)*0.064;
		//r:= r - abs(sin(r*10)*0.58 + sin(r*10)*0.08);
		//r:= r - abs(sin(r*700)*0.005 + sin(r*100)*0.001);

		//r:= minr + Power((r-minr)/(maxr-minr), 4.0)*(maxr-minr);
      r:= maxr - abs(r-avgr);

		xNodes[i].radius:= r;
		xNodes[i].position:= VectorScale(VectorNormalize(xNodes[i].position), xNodes[i].radius);
	end;
end;

procedure TGeosphere.xApplyPerlinNoise(startOctave : integer = 0; noiseScale : single = 1.0);
var i, j : integer;
	 noisevalue, accum : single;
	 p : TVector3f;

begin
	for i:= 0 to high(xNodes) do begin
		noisevalue:= 0;

  //		accum:= 0;
		for j:= startOctave to high(xPerlinSpectrum) do begin
			p:= VectorScale(xNodes[i].position, IntPower(PerlinLacunarity, j));
//			accum:= accum + xPerlinSpectrum[j];
			if noiseScale > 1.0 then
				noisevalue:= noisevalue + 2*(0.5-abs(xPerlinNoise.Noise(p))) * xPerlinSpectrum[j]
			else
				noisevalue:= noisevalue + xPerlinNoise.Noise(p) * xPerlinSpectrum[j];
		end;
		noisevalue:= noisevalue / xPerlinSpectrumNorm;

		//xNodes[i].radius:= xNodes[i].radius * (1 + 0.8*noisevalue);

	  	//noisevalue:= xPerlinNoise.Noise(VectorScale(xNodes[i].position, 1));

		xNodes[i].radius:= xNodes[i].radius + 0.3*noisevalue*noiseScale;
		//xNodes[i].radius:= xNodes[i].radius + 0.1*exp(Power(noisevalue, 8.0))*noiseScale;
		xNodes[i].position:= VectorScale(VectorNormalize(xNodes[i].position), xNodes[i].radius);
	end;

end;


procedure TGeosphere.xCalcAverageRadius;
var i : integer;
begin
	xAverageRadius:= 0;
	for i:= 0 to high(xNodes) do
		xAverageRadius:= xAverageRadius + xNodes[i].radius;
	xAverageRadius:= xAverageRadius/length(xNodes);
end;

procedure TGeosphere.xMakeCrater(centerNodeIndex : integer; craterRadius, craterDepth : single);
var
	visitedNodes : array of boolean;
   i : integer;
	ejectaWidth, ejectaHeight, r : single;
	centerPosition : TVector3f;

	procedure processNode(nodeIndex : integer);
   var dist : single;
		 adjI, lev, adjNodeIndex : integer;
		 newDepth, nD : single;
	begin
   	dist:= VectorLength(VectorSubtract(xNodes[nodeIndex].position, centerPosition)) * (Random*0.05+0.975);
		if dist < craterRadius then begin
         nD:= dist/craterRadius;
			if nD < 0.7 then
				newDepth:= craterDepth*(0.8-sqr(nD/0.7))
		  	else
			 	newDepth:= -craterDepth*0.2*exp((0.7-nD)*10);

			//WriteLog(FloatToStr(newDepth));
			//ScaleVector(xNodes[nodeIndex].position, 1.0 - newDepth/xNodes[nodeIndex].radius);

			r:= xNodes[nodeIndex].radius;
			xNodes[nodeIndex].radius:= r-newDepth;//0.8 + 0.3*SmoothStep(0.8, 1.1, r - newDepth);
        	xNodes[nodeIndex].position:= VectorScale(VectorNormalize(xNodes[nodeIndex].position), xNodes[nodeIndex].radius);
			visitedNodes[nodeIndex]:= true;

			lev:= high(xNodes[nodeIndex].adjacency);
			for adjI:= 0 to high(xNodes[nodeIndex].adjacency[lev]) do begin
      	   adjNodeIndex:= xNodes[nodeIndex].adjacency[lev][adjI];
         	if not visitedNodes[adjNodeIndex] then
					processNode(adjNodeIndex);
	      end;
      end;

   end;

begin
	//WriteLog('crater');
	ejectaWidth:= 0.3;
	ejectaHeight:= 0.4;

	setlength(visitedNodes, length(xNodes));
	for i:= 0 to high(visitedNodes) do
   	visitedNodes[i]:= false;
   centerPosition:= xNodes[centerNodeIndex].position;

	processNode(centerNodeIndex);
end;


function TGeosphere.xAddTriangleTreeNode(v : TVector4i; parentIndex : integer) : integer;
var n, i : integer;

begin
	n:= length(xTrianglesTreeNodes);
   setlength(xTrianglesTreeNodes, n+1);
	with xTrianglesTreeNodes[n] do begin
      vertices:= Vector3iMake(v);
		//v.W:= n;
      for i:= 0 to high(childTreeNodes) do
			childTreeNodes[i]:= -1;
   end;

	if parentIndex >= 0 then
      with xTrianglesTreeNodes[parentIndex] do begin
         for i:= 0 to high(childTreeNodes) do
				if childTreeNodes[i] = -1 then begin
					childTreeNodes[i]:= n;
					Break;
            end;
      end;

	Result:= n;
end;

procedure TGeosphere.xMakeMountain(startNodeIndex, steps : integer; height : single; dir : TVector3f);
var nodeIndex, lev, i, j, adjI, nextNodeIndex : integer;
    maxDot, dot : single;
begin
	nodeIndex:= startNodeIndex;
	//WriteLog('');
  //	WriteLog('   mountain');
  //	WriteLog('');
	for i:= 1 to steps do begin
		xNodes[nodeIndex].radius:= xNodes[nodeIndex].radius + height;
   	xNodes[nodeIndex].position:= VectorScale(VectorNormalize(xNodes[nodeIndex].position), xNodes[nodeIndex].radius);
      lev:= high(xNodes[nodeIndex].adjacency);
		maxDot:= -1;
		nextNodeIndex:= xNodes[nodeIndex].adjacency[lev][0];
		//WriteLog('');
	  {	for j:= 0 to high(xNodes[nodeIndex].adjacency[lev]) do begin
         adjI:= xNodes[nodeIndex].adjacency[lev][j];
			dot:= VectorDotProduct(dir, VectorNormalize(VectorSubtract(xNodes[adjI].position, xNodes[nodeIndex].position)));
         if dot > maxDot then begin
				nextNodeIndex:= adjI;
				maxDot:= dot;

         end;
         //WriteLog(FloatToStr(dot));
      end;
		nodeIndex:= nextNodeIndex;
		WriteLog(IntToStr(nodeIndex));}
		nodeIndex:= xNodes[nodeIndex].adjacency[lev][Random(length(xNodes[nodeIndex].adjacency[lev]))];
   end;
end;

function TGeosphere.GetHeightAtPoint(p : TVector3f) : single;
var tri, i : integer;
    intersection, dir, ptA, ptB, ptC : TVector3f;

begin
	dir:= VectorNegate(VectorNormalize(p));
	//dir:= VectorNormalize(p);

	for i:= 0 to IcosahedronTriangles-1 do begin
		tri:= xGetTriangleAtDir(dir, i);
		if tri >= 0 then
			Break;
	end;

	intersection:= NullVector;
   if tri >= 0 then begin
		ptA:= xNodes[ xTrianglesTreeNodes[tri].vertices.v[0] ].position;
		ptB:= xNodes[ xTrianglesTreeNodes[tri].vertices.v[1] ].position;
		ptC:= xNodes[ xTrianglesTreeNodes[tri].vertices.v[2] ].position;
		PointTriangleProjection(NullVector, dir, ptA, ptB, ptC, intersection, False);

		Result:= VectorLength(intersection);
   end else
		Result:= -1;
end;

function TGeosphere.xGetTriangleAtDir(dir : TVector3f; triangle : integer; depth : integer = -1) : integer;
var ptA, ptB, ptC : TVector3f;
    isInside : boolean;
	 i, childRes : integer;

begin
	ptA:= xNodes[ xTrianglesTreeNodes[triangle].vertices.v[0] ].position;
	ptB:= xNodes[ xTrianglesTreeNodes[triangle].vertices.v[1] ].position;
	ptC:= xNodes[ xTrianglesTreeNodes[triangle].vertices.v[2] ].position;
	isInside:= IsLineIntersectTriangle(NullVector, dir, ptA, ptB, ptC);
	if VectorDotProduct(VectorNormalize(ptA), dir) > 0 then isInside:= false;

	if isInside then begin

		if depth = 0 then
			Result:= triangle
   	else
		begin
      	if xTrianglesTreeNodes[triangle].childTreeNodes[0] >= 0 then begin
				Result:= -1;
         	for i:= 0 to 3 do begin
               childRes:= xGetTriangleAtDir(dir, xTrianglesTreeNodes[triangle].childTreeNodes[i], depth-1);
					if childRes >= 0 then begin
                  Result:= childRes;
						Break;
               end;
            end;

         end else begin
				Result:= triangle;
            //WriteLog(IntToStr(depth));
         end;
      end;

   end else
		Result:= -1;
end;

procedure TGeosphere.GetTriangleAtPoint(p : TVector3f; var ptA, ptB, ptC : TVector3f; depth : integer);
var tri, i : integer;
    dir : TVector3f;

begin
	dir:= VectorNegate(VectorNormalize(p));
	//dir:= VectorNormalize(p);

	for i:= 0 to IcosahedronTriangles-1 do begin
		tri:= xGetTriangleAtDir(dir, i, depth);
		if tri >= 0 then
			Break;
   end;

   if tri >= 0 then begin
		ptA:= xNodes[ xTrianglesTreeNodes[tri].vertices.v[0] ].position;
		ptB:= xNodes[ xTrianglesTreeNodes[tri].vertices.v[1] ].position;
		ptC:= xNodes[ xTrianglesTreeNodes[tri].vertices.v[2] ].position;
   end;
end;

procedure TGeosphere.GetTriangleChildren(parentTriangle : integer; var childTriangles : TIntegerDynArray; depth : integer = -1);
var i, n : integer;
begin
	if depth = 0 then begin
		n:= length(childTriangles);
		setlength(childTriangles, n+1);
		childTriangles[n]:= parentTriangle;
	end else begin
		if xTrianglesTreeNodes[parentTriangle].childTreeNodes[0] >= 0 then begin
			for i:= 0 to 3 do
				GetTriangleChildren(xTrianglesTreeNodes[parentTriangle].childTreeNodes[i], childTriangles, depth-1);
		end else begin
			n:= length(childTriangles);
			setlength(childTriangles, n+1);
			childTriangles[n]:= parentTriangle;
		end;
	end;
end;

procedure TGeosphere.GenerateMesh(var mesh : TGeoMesh; baseTriangleNode : integer = -1; depth : integer = -1; icoSide : integer = -1);
var i, n, nodeIndex : integer;
    uv : TVector2f;
begin
	if baseTriangleNode = -1 then begin
		for i:= 0 to IcosahedronTriangles-1 do
			GenerateMesh(mesh, i, depth, i);

   end else begin
		if depth = 0 then begin
			n:= length(mesh);
			setlength(mesh, n+3);
			for i:= 0 to 2 do begin
				nodeIndex:= xTrianglesTreeNodes[baseTriangleNode].vertices.V[i];
				with xNodes[ nodeIndex ] do begin
					mesh[n+i].position:= position;
					mesh[n+i].normal:= normal;
					uv := GetTexUV(nodeIndex, IcosahedronTrianglePairs[icoSide].X, IcosahedronTrianglePairs[icoSide].Y);
					mesh[n+i].uv.S:= uv.X;
					mesh[n+i].uv.T:= uv.Y;
				end;
			end;
		end else begin
			if xTrianglesTreeNodes[baseTriangleNode].childTreeNodes[0] >= 0 then begin
				for i:= 0 to 3 do
					GenerateMesh(mesh, xTrianglesTreeNodes[baseTriangleNode].childTreeNodes[i], depth-1, icoSide);
			end else begin
				n:= length(mesh);
				setlength(mesh, n+3);
				for i:= 0 to 2 do begin
					nodeIndex:= xTrianglesTreeNodes[baseTriangleNode].vertices.V[i];
					with xNodes[ nodeIndex ] do begin
						mesh[n+i].position:= position;
						mesh[n+i].normal:= normal;
						uv := GetTexUV(nodeIndex, IcosahedronTrianglePairs[icoSide].X, IcosahedronTrianglePairs[icoSide].Y);
						mesh[n+i].uv.S:= uv.X;
						mesh[n+i].uv.T:= uv.Y;
					end;
				end;
         end;
      end;
   end;
end;

initialization
	debugLog:= TStringList.Create;

finalization
	debugLog.SaveToFile('ugeosphere.adv');

end.
