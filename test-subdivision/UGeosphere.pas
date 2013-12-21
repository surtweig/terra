unit UGeosphere;

interface

uses
	SysUtils, Math, VectorTypes, VectorGeometry, Classes, Types;

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

	TGeosphere = class
      NoiseFactor : single;
		NoiseMinOctave, NoiseMaxOctave : integer;

		constructor Create (subdivisions : integer);

		function GetNode(index : integer) : TGeoNode;
		function NodesCount : integer;
		function FindNodesCommonAdjacency(index1, index2, level : integer) : integer;
		function GetVertex(vi : integer) : TVector3f;
		function GetNormal(vi : integer) : TVector3f;
		function TrianglesCount : integer;

		private
			xNodes : array of TGeoNode;
			xTriangles : array of TVector4i;
			xTrianglesTreeNodes : array of TGeoTrianglesTreeNode;

			procedure xInitIcosahedron;
			procedure xBuildNormals(sharpness : single);

		protected
			xSubdivisionLevel : integer;

			procedure xSubdivide;
			function xAddNode : integer;
			procedure xNodeAddAdjacency(nodeIndex, level, adjNodeIndex : integer);
			procedure xConnectNodes(node1index, node2index, level : integer);
			procedure xSmooth;
			procedure xMakeCrater(centerNodeIndex : integer; craterRadius, craterDepth : single);
			procedure xMakeMountain(startNodeIndex, steps : integer; height : single; dir : TVector3f);
			function xAddTriangleTreeNode(v : TVector4i; parentIndex : integer = -1) : integer;
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

constructor TGeosphere.Create(subdivisions : integer);
var i : integer;
    crSize : single;
begin
	xInitIcosahedron;

   xSubdivisionLevel:= 0;
	NoiseFactor:= 10.0;
	NoiseMinOctave:= 1;
	NoiseMaxOctave:= 6;
	for i:= 1 to subdivisions do begin
		//WriteLog('subdivide');
		xSubdivide;
		xSubdivisionLevel:= i;

	  	if i mod 1 = 0 then xSmooth;
   end;

	for i:= 1 to 100 do begin
      xMakeMountain(Random(length(xNodes)), 2000, 0.005, VectorNormalize(AffineVectorMake(Random-0.5, Random-0.5, Random-0.5)));
		if i mod 20 = 0 then
			xSmooth;
   end;

   for i:= 1 to 2000 do begin
		crSize:= exp(RandG(0, 1))*0.15;
		if crSize > 0.8 then crSize:= 0.8;
		xMakeCrater(Random(length(xNodes)), 0.005+crSize*0.15, 0.005+crSize*0.025);
		if i mod 501 = 0 then
  			xSmooth;
   end;


  //	for i:= 1 to 1 do
	//	xSmooth;

	xBuildNormals(0.1);
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
				Break;
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
		xNodes[i].position:= VectorAdd(VectorNormalize(icoverts[i]), VectorScale(AffineVectorMake(Random-0.5, Random-0.5, Random-0.5), 0.25));
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
var tri, i, j, range, acc : integer;
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
         	//xNodes[N12].position:= VectorNormalize(VectorAdd(xNodes[N1].position, xNodes[N2].position));
         	xNodes[N12].position:= VectorScale(VectorAdd(xNodes[N1].position, xNodes[N2].position), 0.5);
				xNodes[N12].radius:= (xNodes[N1].radius+xNodes[N2].radius)*0.5;

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

         	if (xSubdivisionLevel >= NoiseMinOctave) and (xSubdivisionLevel <= NoiseMaxOctave) then begin
            	xNodes[N12].radius:= xNodes[N12].radius + Random*NoiseFactor/power(xSubdivisionLevel+1, 3);
					//AddVector(xNodes[N12].position, VectorScale(AffineVectorMake(Random-0.5, Random-0.5, Random-0.5), 0.2/(xSubdivisionLevel+1)));
	            //xNodes[N12].radius:= VectorLength(xNodes[N12].position);
            end;
            ScaleVector(xNodes[N12].position, xNodes[N12].radius);

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
		xAddTriangleTreeNode(xTriangles[tri], j);

		xTriangles[i]:=   Vector4iMake(Nb, newNs[1], newNs[0]);
		xAddTriangleTreeNode(xTriangles[i], j);

		xTriangles[i+1]:= Vector4iMake(Nc, newNs[2], newNs[1]);
		xAddTriangleTreeNode(xTriangles[i+1], j);

		xTriangles[i+2]:= Vector4iMake(newNs[0], newNs[1], newNs[2]);
		xAddTriangleTreeNode(xTriangles[i+2], j);

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
		xNodes[i].position:= VectorScale(VectorNormalize(xNodes[i].position), xNodes[i].radius);
   end;
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
   	dist:= VectorLength(VectorSubtract(xNodes[nodeIndex].position, centerPosition)) * (Random*0.1+0.95);
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
		v.W:= n;
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

initialization
	debugLog:= TStringList.Create;

finalization
	debugLog.SaveToFile('ugeosphere.adv');

end.
