using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.Threading;


public class GeoNode
{
	public Vector3 position;
	public Vector3 normal;
	public float elevation;
	public List<int[]> adjacency;
	public bool transformed = false;
	
	public GeoNode()
	{
		adjacency = new List<int[]>();
	}
}


public class GeoTriTreeNode
{
	public int[] vertices;
	public int[] children;
	public byte level;
}


public class MutableGeoMesh
{
	public List<int> indexes;
	public List<int> triangles;
	
	public MutableGeoMesh()
	{
		indexes = new List<int>();
		triangles = new List<int>();
	}
	
	public void AddVertex(int nodeIndex)
	{
		if (indexes.Count == 0)
			indexes.Add(nodeIndex);
		else
		{
			int subIndex = indexes.BinarySearch(nodeIndex);
			if (subIndex < 0)
			{
				subIndex = ~subIndex;
				indexes.Insert(subIndex, nodeIndex);
			}
			
		}
		triangles.Add(nodeIndex);
	}
	
	public void IndexTriangles()
	{
		for (int i = 0; i < triangles.Count; i++)
			triangles[i] = indexes.BinarySearch(triangles[i]);
	}
}


public class MeshContainer
{
	public Vector3[] vertices;
	public Vector3[] normals;
	public Vector2[] uv;
	public int[] triangles;
	
	public Mesh MakeMesh()
	{
		Mesh mesh = new Mesh();
		mesh.vertices = vertices;
		mesh.normals = normals;
		mesh.triangles = triangles;
		mesh.uv = uv;
		return mesh;
	}
}


public class DummyNoiseGenerator : ISpatialNoiseGenerator
{
	private int pointsNumber = -1;
	
	public void Start(Vector3[] points, int steps)
	{
		pointsNumber = points.Length;
	}
	
	public bool Update()
	{
		return Done;
	}
	
	public float[] Output()
	{
		Debug.Log("pointsNumber = " + pointsNumber);
		float[] output = new float[pointsNumber];
		for (int i = 0; i < output.Length; i++)
			output[i] = 0f;
		return output;
	}
	
	public bool Done { get { return (pointsNumber >= 0); } }
	public bool Started { get { return (pointsNumber >= 0); } }
	
	public void Reset()
	{
		pointsNumber = -1;
	}
}


public class GeoSurface
{
	protected List<GeoNode> nodes;
	protected List<GeoTriTreeNode> tritree; 
	protected int triTreeRootSize = 0; // number of first basic TriTree nodes
	protected List<MeshContainer> meshContainers;
	protected List<Color[]> textures;
	
	protected int[][] trianglePairs;
	protected int[] triangleToPairsMap;
	
	public ISpatialNoiseGenerator Noise;
	public ISpatialNoiseGenerator[] TexNoises;
	public int TargetSubdivisionLevel = 0;
	public int NoiseGenFrames = 32;
	public float NoiseScale = 1f;
	public float NoiseSpaceScale = 1f;
	public int TextureSize = 1024;
	public int TexNoiseGenFrames = 32;
	
	private Thread subdivideThread;
	private Thread applyNoiseThread;
	private Thread buildMeshThread;
	private Thread texLoadGeneratorThread;
	private Thread texColorizeThread;

	private bool subdivided = false;
	private bool noiseApplied = false;
	private bool meshBuilt = false;
	private int texGeneratorLoaded = -1;
	private int texGeneratorDone = -1;
	private int texColorized = -1;
	private bool texturesGenerated = false;
	
	private bool threadsShouldStop = false;
	
	private List<Vector3> noiseInput;
	private float[] noiseOutput;
	
	private Vector3[] texNoiseInput;
	private float[][] texNoiseOutput;

	public GeoSurface()
	{
		nodes = new List<GeoNode>();
		tritree = new List<GeoTriTreeNode>();
		meshContainers = new List<MeshContainer>();
		Noise = new DummyNoiseGenerator();
		TexNoises = new ISpatialNoiseGenerator[1] { new DummyNoiseGenerator() };
		subdivideThread = new Thread(this.SubdivideThreadProc);
		applyNoiseThread = new Thread(this.ApplyNoiseThreadProc);
		buildMeshThread = new Thread(this.BuildMeshThreadProc);
		texLoadGeneratorThread = new Thread(this.TexLoadGeneratorThreadProc);
		texColorizeThread = new Thread(this.TexColorizeThreadProc);
		textures = new List<Color[]>();
	}
	
	~GeoSurface()
	{
		StopThreads();
	}
	
	public void StopThreads()
	{
		/*if (subdivideThread.IsAlive)
			subdivideThread.Interrupt();
		if (applyNoiseThread.IsAlive)
			applyNoiseThread.Interrupt();
		if (buildMeshThread.IsAlive)
			buildMeshThread.Interrupt();
		if (generateUVThread.IsAlive)
			generateUVThread.Interrupt();*/
		threadsShouldStop = true;
	}
	
	public bool StartBuilding()
	{
		Debug.Log("GeoSurface.StartBulding");
		
		if (IsInProgress)
			return false;
		
		subdivideThread.Start();
		
		return true;
	}
	
	public int MeshesCount { get { return meshContainers.Count; } }
	
	public Mesh GetMesh(int meshIndex)
	{
		if (meshIndex < 0 || meshIndex >= meshContainers.Count)
			return null;
		return meshContainers[meshIndex].MakeMesh();
	}
	
	public Texture2D GetTexture(int meshIndex)
	{
		if (meshIndex < 0 || meshIndex >= meshContainers.Count)
			return null;
		int texIndex = triangleToPairsMap[meshIndex];
		Texture2D tex = new Texture2D(TextureSize, TextureSize);
		tex.SetPixels(textures[texIndex]);
		tex.wrapMode = TextureWrapMode.Clamp;
		return tex;
	}
	
	public virtual bool IsInProgress
		{ get { return subdivideThread.IsAlive || applyNoiseThread.IsAlive || texColorizeThread.IsAlive || texLoadGeneratorThread.IsAlive || (Noise.Started && !Noise.Done); } }
	
	public virtual bool Done { get { return !IsInProgress && subdivided && noiseApplied && meshBuilt && texturesGenerated; } }
	
	public virtual float TexturesProgress { get { return (float)texColorized/(float)(trianglePairs.Length); } }
	
	public virtual Vector3 NormalizePoint(Vector3 point)
	{
		return point;
	}
	
	public virtual Vector3 ElevatePoint(Vector3 point, float elevation)
	{
		return point;
	}
	
	protected virtual void SubdivideThreadProc()
	{
		subdivided = false;
		Debug.Log("GeoSurface.Subdivide thread start");
		// Subdividing
		for (int triTreeNode = 0; triTreeNode < triTreeRootSize; triTreeNode++)
		{
			Subdivide(triTreeNode, TargetSubdivisionLevel);
			
			if (threadsShouldStop)
			{
				Debug.Log("!!! GeoSurface.Subdivide thread abort");
				return;
			}
		}
		
		// Collecting points
		noiseInput = new List<Vector3>();
		foreach (GeoNode node in nodes)
		{
			if (!node.transformed)
				noiseInput.Add(node.position * NoiseSpaceScale);
			
			if (threadsShouldStop)
			{
				Debug.Log("!!! GeoSurface.Subdivide thread abort");
				return;
			}
		}
		
		Debug.Log(">> GeoSurface.Subdivide thread finish");
		subdivided = true;
	}

	protected virtual void ApplyNoiseThreadProc()
	{
		noiseApplied = false;
		Debug.Log("GeoSurface.ApplyNoise thread start");

		// Applying generated noise
		for (int i = 0; i < nodes.Count; i++)
		{
			if ( !nodes[i].transformed )
			{
				nodes[i].elevation = noiseOutput[i]*NoiseScale;
				nodes[i].position = ElevatePoint(nodes[i].position, nodes[i].elevation);
				nodes[i].transformed = true;
			}
			
			if (threadsShouldStop)
			{
				Debug.Log("!!! GeoSurface.ApplyNoise thread abort");
				return;
			}
		}
		
		noiseInput.Clear();
		noiseOutput = new float[0] {};
		
		Debug.Log(">> GeoSurface.ApplyNoise thread finish");
		noiseApplied = true;
	}
	
	protected virtual void BuildMeshThreadProc()
	{
		meshBuilt = false;
		Debug.Log("GeoSurface.BuildMesh thread start");
		
		// Calculating normals
		BuildNormals();
		
		// Building mesh containers
		meshContainers.Clear();
		for (int triTreeNode = 0; triTreeNode < triTreeRootSize; triTreeNode++)
		{
			meshContainers.Add(BuildTriTreeNodeMesh(triTreeNode));

			if (threadsShouldStop)
			{
				Debug.Log("!!! GeoSurface.BuildMesh thread abort");
				return;
			}
		}
		
		Debug.Log(">> GeoSurface.BuildMesh thread finish");
		meshBuilt = true;
	}
	
	protected virtual void TexLoadGeneratorThreadProc()
	{
		Debug.Log("GeoSurface.TexLoadGenerator thread start");
		if (TexNoises.Length > 0)
		{
			texNoiseInput = new Vector3[TextureSize*TextureSize];
			int[] tripair =  trianglePairs[texGeneratorLoaded+1];
			for (int x = 0; x < TextureSize; x++)
			{
				if (threadsShouldStop)
				{
					Debug.Log("!!! GeoSurface.TexLoadGenerator thread abort");
					return;
				}
				for (int y = 0; y < TextureSize; y++)
					texNoiseInput[y*TextureSize + x] = GetVertexPositionFromUV(new Vector2((float)x/(float)TextureSize, (float)y/(float)TextureSize), tripair[0], tripair[1]);
			}
			texGeneratorLoaded++;
		}
		Debug.Log(">> GeoSurface.TexLoadGenerator thread finish");
	}
	
	protected virtual void TexColorizeThreadProc()
	{
		Debug.Log("GeoSurface.TexColorize thread start");
		if (TexNoises.Length > 0)
		{
			Color[] tex = new Color[TextureSize*TextureSize];
			for (int i = 0; i < TextureSize*TextureSize; i++)
			{
				float[] values = new float[texNoiseOutput.Length];
				for (int j = 0; j < texNoiseOutput.Length; j++)
					values[j] = texNoiseOutput[j][i];
				tex[i] = Colorize(values);
				if (threadsShouldStop)
				{
					Debug.Log("!!! GeoSurface.TexColorize thread abort");
					return;
				}
			}
			textures.Add(tex);
			texColorized++;
			Debug.Log("texColorized = " + texColorized);
		}
		Debug.Log(">> GeoSurface.TexColorize thread finish");
	}
	
	protected virtual Color Colorize(float[] noiseValues)
	{
		float c = Mathf.Clamp( (noiseValues[0]+1f)*0.5f, 0f, 1f);
		return new Color(c, c, c);
	}

	public virtual bool Update()
	{
		if (subdivided)
		{
			// start surface noise
			if ( !Noise.Started )
				Noise.Start(noiseInput.ToArray(), NoiseGenFrames);
			
			// proceed surface noise
			if ( Noise.Update() && !applyNoiseThread.IsAlive && !noiseApplied )
			{
				// start applying noise to the geometry
				noiseOutput = Noise.Output();
				applyNoiseThread.Start();
			}
			
			// Textures generating //
			if (TexNoises.Length > 0 && texColorized < (trianglePairs.Length-1) )
			{
				// create input points for FBMGPU generators
				if ( texGeneratorLoaded <= texColorized && texGeneratorLoaded < (trianglePairs.Length-1) && !texLoadGeneratorThread.IsAlive )
				{
					texLoadGeneratorThread = new Thread(this.TexLoadGeneratorThreadProc);
					texLoadGeneratorThread.Start();
				}
				
				// start FBMGPUs if loaded
				if ( texGeneratorLoaded > texColorized && texGeneratorLoaded > texGeneratorDone)
				{
					foreach (ISpatialNoiseGenerator texNoise in TexNoises)
						if (!texNoise.Started)
							texNoise.Start(texNoiseInput, TexNoiseGenFrames);
				}
			
				// update FBMGPUs
				bool allTexNoiseDone = true;
				foreach (ISpatialNoiseGenerator texNoise in TexNoises)
					if ( !texNoise.Update() )
						allTexNoiseDone = false;
				
				// take FBMGPUs output if they're done and previous texture has been colorized
				if (allTexNoiseDone && !texColorizeThread.IsAlive)
				{
					texNoiseOutput = new float[TexNoises.Length][];
					for (int i = 0; i < TexNoises.Length; i++)
					{
						texNoiseOutput[i] = TexNoises[i].Output();
						TexNoises[i].Reset();
					}
					
					texGeneratorDone++;
					texColorizeThread = new Thread(this.TexColorizeThreadProc);
					texColorizeThread.Start();
				}
			}
			
			if (texColorized == (trianglePairs.Length-1))
				texturesGenerated = true;
		}
		
		if (noiseApplied)
		{
			if ( !buildMeshThread.IsAlive && !meshBuilt )
				buildMeshThread.Start();
		}
		
		return Done;
	}
	
	public MeshContainer BuildTriTreeNodeMesh(int triTreeNode)
	{
		MutableGeoMesh mutablemesh = new MutableGeoMesh();
		CollectVertexes(mutablemesh, triTreeNode);
		mutablemesh.IndexTriangles();
		
		List<Vector3> vertices = new List<Vector3>();
		List<Vector2> uv = new List<Vector2>();
		List<Vector3> normals = new List<Vector3>();
		
		int[] triTreeNodesPair = GetTriTreeNodePair(triTreeNode);
		
		foreach (int nodeIndex in mutablemesh.indexes)
		{
			vertices.Add(nodes[nodeIndex].position);
			normals.Add(nodes[nodeIndex].normal);
			uv.Add(GetVertexUV(nodes[nodeIndex].position, triTreeNodesPair[0], triTreeNodesPair[1]));
		}
		
		MeshContainer meshContainer = new MeshContainer();
		meshContainer.vertices = vertices.ToArray();
		meshContainer.normals = normals.ToArray();
		meshContainer.triangles = mutablemesh.triangles.ToArray();
		meshContainer.uv = uv.ToArray();
		
		return meshContainer;
	}
	
	protected void BuildNormals()
	{
		for (int i = 0; i < nodes.Count; i++)
		{
			float nx = 0f;
			float ny = 0f;
			float nz = 0f;
			
			int highlev = nodes[i].adjacency.Count-1;
			
			int icurrent = -1;
			Vector3 vcurrent = nodes[i].position;

			int inext = nodes[i].adjacency[highlev][0];
			Vector3 vnext = nodes[inext].position;
			
			int ifirst = inext;
			
			while (true)
			{
				nx += (vcurrent.y - vnext.y) * (vcurrent.z + vnext.z);
				ny += (vcurrent.z - vnext.z) * (vcurrent.x + vnext.x);
				nz += (vcurrent.x - vnext.x) * (vcurrent.y + vnext.y);
				
				// finding next node as common adjacent of center and current node, but not previous
				bool nextfound = false;
				for (int j = 0; j < nodes[i].adjacency[highlev].Length; j++)
				{
					for (int k = 0; k < nodes[inext].adjacency[highlev].Length; k++)
						if (nodes[i].adjacency[highlev][j] == nodes[inext].adjacency[highlev][k])
							if (nodes[i].adjacency[highlev][j] != icurrent)
							{
								icurrent = inext;
								inext = nodes[i].adjacency[highlev][j];
								nextfound = true;
								break;
							}
					
					if (nextfound)
						break;
				}
				
				vcurrent = vnext;
				vnext = nodes[inext].position;
				
				if (inext == ifirst)
					break;
			}
			
			vnext = nodes[i].position;
			nx += (vcurrent.y - vnext.y) * (vcurrent.z + vnext.z);
			ny += (vcurrent.z - vnext.z) * (vcurrent.x + vnext.x);
			nz += (vcurrent.x - vnext.x) * (vcurrent.y + vnext.y);
			
			Vector3 normal = new Vector3(nx, ny, nz).normalized;
			
			if (Vector3.Dot(normal, vnext.normalized) < 0)
				normal = -normal;
			
			nodes[i].normal = normal;
		}
	}
	
	protected virtual Vector2 GetVertexUV(Vector3 position, int triA, int triB)
	{
		return new Vector2(0f, 0f);
	}
	
	protected virtual Vector3 GetVertexPositionFromUV(Vector2 uv, int triA, int triB)
	{
		return new Vector3(0f, 0f, 0f);
	}
	
	// This function should return an ordered pair of TriTree nodes indexes, which share one texture
	protected virtual int[] GetTriTreeNodePair(int triTreeNode)
	{
		Utils.Assert(triTreeNode < triTreeRootSize, "GeoSurface.GetTriTreeNodePair: triangle pair can be generated for a root triangle only");
		return trianglePairs[triangleToPairsMap[triTreeNode]];
	}
	
	//    iC1_________iB
	//      /\        /
	//     /  \ triB /
	//    /    \    /
	//   / triA \  /
	//  /________\/
	// iA        iC2
	protected void GetQuadVertices(int triA, int triB, out int iA, out int iB, out int iC1, out int iC2)
	{
		List<int> C1C2 = new List<int>();
		
		iA = -1;
		iB = -1;
		
		bool comm;
		for (int i = 0; i < 3; i++)
		{
			comm = false;
			
			for (int j = 0; j < 3; j++)
			{
				if (tritree[triA].vertices[i] == tritree[triB].vertices[j])
				{
					comm = true;
					break;
				}
			}

			if (comm)
				C1C2.Add(tritree[triA].vertices[i]);
			else
				iA = tritree[triA].vertices[i];
		}
		
		for (int i = 0; i < 3; i++)
			if ( !C1C2.Contains(tritree[triB].vertices[i]) )
				iB = tritree[triB].vertices[i];
		
		if (C1C2.Count == 2)
		{
			iC1 = C1C2[0];
			iC2 = C1C2[1];
		}
		else
		{
			iC1 = -1;
			iC2 = -1;
		}
	}
	
	protected int xAddNode(GeoNode node)
	{
		int i = nodes.Count;
		nodes.Add(node);
		return i;
	}
	
	protected int xAddTriTreeNode(int[] vertices, int parentNode = -1)
	{
		GeoTriTreeNode newNode = new GeoTriTreeNode();
		newNode.vertices = vertices;
		newNode.children = new int[4] { -1, -1, -1, -1 };
		
		bool addedToChildren = false;
		int newNodeIndex = tritree.Count;
		if (parentNode >= 0)
		{
			newNode.level = (byte)(tritree[parentNode].level + 1);
			for (int i = 0; i < 4; i++)
				if (tritree[parentNode].children[i] == -1)
				{
					tritree[parentNode].children[i] = newNodeIndex;
					addedToChildren = true;
					break;
				}
		}
		else
			newNode.level = 0;
		
		Utils.Assert( addedToChildren || parentNode < 0, "Geosphere.GeoSurface.xAddTriTreeNode : can't add new tritree node to parentNode " + parentNode + " - it has 4 children already");
		
		tritree.Add(newNode);
		return newNodeIndex;
	}
	
	protected void xAddNodeAdjacency(int nodeIndex, int level, int adjNodeIndex)
	{
		int maxLevel = nodes[nodeIndex].adjacency.Count-1;
		if (maxLevel < level)
			for (int i = maxLevel; i < level; i++)
				nodes[nodeIndex].adjacency.Add(new int[] {});
		
		int[] adj = new int[nodes[nodeIndex].adjacency[level].Length+1];
		nodes[nodeIndex].adjacency[level].CopyTo(adj, 0);
		adj[adj.Length-1] = adjNodeIndex;
		nodes[nodeIndex].adjacency[level] = adj;
	}
	
	protected void xConnectNodes(int node1, int node2, int level)
	{
		xAddNodeAdjacency(node1, level, node2);
		xAddNodeAdjacency(node2, level, node1);
	}
	
	protected int xFindNodesCommonAdjacency(int node1, int node2, int level)
	{
		if (nodes[node1].adjacency.Count <= level || nodes[node2].adjacency.Count <= level)
			return -1;
		foreach (int adj1 in nodes[node1].adjacency[level])
			foreach (int adj2 in nodes[node2].adjacency[level])
				if (adj1 == adj2)
					return adj1;
		return -1;
	}
	
	protected void CollectVertexes(MutableGeoMesh mesh, int baseTriangleNode, int depth = -1)
	{
		if (depth == 0 || tritree[baseTriangleNode].children[0] < 0)
		{
			for (int i = 0; i < 3; i++)
				mesh.AddVertex(tritree[baseTriangleNode].vertices[i]);
		}
		else
		{
			for (int i = 0; i < 4; i++)
				CollectVertexes(mesh, tritree[baseTriangleNode].children[i], depth-1);
		}
	}
	
	protected void Subdivide(int treeNodeIndex, int levelLimit, int _callLevel = 0)
	{
		Utils.Assert(treeNodeIndex >= 0, "Geosphere.GeoSurface.Subdivide: treeNodeIndex must be >= 0");
		
		if (tritree[treeNodeIndex].children[0] < 0)
		{
			int[] subNodes = new int[3];
			int subdivisionLevel = tritree[treeNodeIndex].level;
			
			if (subdivisionLevel >= levelLimit)
				return;
			
			for (int i = 0; i < 3; i++)
			{
				int v1 = tritree[treeNodeIndex].vertices[i];
				int v2 = tritree[treeNodeIndex].vertices[(i+1) % 3];
				
				int v12 = xFindNodesCommonAdjacency(v1, v2, subdivisionLevel+1);
				
				if (v12 < 0)
				{
					GeoNode newnode = new GeoNode();
					newnode.position = NormalizePoint( 0.5f*(nodes[v1].position + nodes[v2].position) );
					newnode.elevation = 0f;
					newnode.adjacency = new List<int[]>();
					v12 = xAddNode(newnode);
					
					xConnectNodes(v12, v1, subdivisionLevel+1);
					xConnectNodes(v12, v2, subdivisionLevel+1);
				}
				
				subNodes[i] = v12;
			}
			
			xConnectNodes(subNodes[0], subNodes[1], subdivisionLevel+1);
			xConnectNodes(subNodes[1], subNodes[2], subdivisionLevel+1);
			xConnectNodes(subNodes[2], subNodes[0], subdivisionLevel+1);
			
			//      /\
			//     /  \
			//    /----\
			//   / \  / \
			//  /___\/___\
			
			xAddTriTreeNode( new int[3] { tritree[treeNodeIndex].vertices[0], subNodes[0], subNodes[2] }, treeNodeIndex );
			xAddTriTreeNode( new int[3] { tritree[treeNodeIndex].vertices[1], subNodes[1], subNodes[0] }, treeNodeIndex );
			xAddTriTreeNode( new int[3] { tritree[treeNodeIndex].vertices[2], subNodes[2], subNodes[1] }, treeNodeIndex );
			xAddTriTreeNode( new int[3] { subNodes[0], subNodes[1], subNodes[2] }, treeNodeIndex );
		}
		
		Utils.Assert(_callLevel+1 <= levelLimit, "Geosphere.GeoSurface.Subdivide: Recoursive call level ("+(_callLevel+1)+") can't be greater than levelLimit ("+levelLimit+")");
		foreach (int childNode in tritree[treeNodeIndex].children)
			Subdivide(childNode, levelLimit, _callLevel+1);
	}
}


public class GeoSphere : GeoSurface
{
	public GeoSphere() : base()
	{
		triTreeRootSize = IcosahedronTriangles;
		trianglePairs = IcosahedronTrianglePairs;
		triangleToPairsMap = IcosahedronTriangleToPairsMap;
		BuildIcosahedron();
	}
	
	public override Vector3 NormalizePoint(Vector3 point)
	{
		return point.normalized;
	}
	
	public override Vector3 ElevatePoint(Vector3 point, float elevation)
	{
		return point * (1f+elevation);
	}	
	
	// -------------------------------------------------------
	public const int IcosahedronTriangles = 20;
	
	public static int[][] IcosahedronTrianglePairs = new int[IcosahedronTriangles/2][]
		{ new int[2] {0, 1}, new int[2] {2, 3}, new int[2] {15, 4}, new int[2] {14, 5}, new int[2] {19, 6}, 
		  new int[2] {16, 7}, new int[2] {12, 8}, new int[2] {18, 9}, new int[2] {13, 10}, new int[2] {17, 11} };
	
	public static int[] IcosahedronTriangleToPairsMap = new int[IcosahedronTriangles]
		{ 0, 0, 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 6, 8, 3, 2, 5, 9, 7, 4 };

	protected void BuildIcosahedron()
	{
		const float A = 0.5f;
		const float B = 0.30901699437f; // 1/(1+Sqrt(5))
		
		Vector3[] icoverts = new Vector3[12]
			{ new Vector3(0f, -B, -A), new Vector3(0f, -B, A), new Vector3(0f, B, -A), new Vector3(0f, B, A),
			  new Vector3(-A, 0f, -B), new Vector3(-A, 0f, B), new Vector3(A, 0f, -B), new Vector3(A, 0f, B),
			  new Vector3(-B, -A, 0f), new Vector3(-B, A, 0f), new Vector3(B, -A, 0f), new Vector3(B, A, 0f) };
			
		int[][] icotris = new int[20][]
			{ new int[3] {2, 9, 11}, new int[3] {3, 11, 9}, new int[3] {3, 5, 1},  new int[3] {3, 1, 7},  new int[3] {2, 6, 0},
			  new int[3] {2, 0, 4},  new int[3] {1, 8, 10}, new int[3] {0, 10, 8}, new int[3] {9, 4, 5},  new int[3] {8, 5, 4},
			  new int[3] {11, 7, 6}, new int[3] {10, 6, 7}, new int[3] {3, 9, 5},  new int[3] {3, 7, 11}, new int[3] {2, 4, 9},
			  new int[3] {2, 11, 6}, new int[3] {0, 8, 4},  new int[3] {0, 6, 10}, new int[3] {1, 5, 8},  new int[3] {1, 10, 7} };
		
		int[][] icoadj = new int[12][]
			{ new int[5] {8, 2, 4, 10, 6}, new int[5] {8, 10, 3, 5, 7}, new int[5] {0, 9, 11, 4, 6},  new int[5] {7, 9, 11, 5, 1},
			  new int[5] {0, 9, 2, 5, 8},  new int[5] {8, 1, 3, 4, 9},  new int[5] {0, 2, 11, 10, 7}, new int[5] {11, 1, 10, 3, 6},
			  new int[5] {0, 1, 10, 4, 5}, new int[5] {3, 2, 11, 4, 5}, new int[5] {8, 1, 6, 0, 7},   new int[5] {9, 2, 3, 6, 7} };		
		
		for (int i = 0; i < icoverts.Length; i++)
		{
			GeoNode node = new GeoNode();
			node.position = icoverts[i].normalized;
			node.adjacency.Add(icoadj[i]);
			nodes.Add(node);
		}
		
		for (int i = 0; i < icotris.Length; i++)
			xAddTriTreeNode(icotris[i]);
	}
	
	protected override Vector2 GetVertexUV (Vector3 position, int triA, int triB)
	{
		int iA;
		int iB;
		int iC1;
		int iC2;
		GetQuadVertices(triA, triB, out iA, out iB, out iC1, out iC2);
		Utils.Assert(iA >= 0 && iB >= 0 && iC1 >= 0 && iC2 >= 0, "GeoSphere.GetVertexUV: triA ("+triA+") and triB ("+triB+") must have exactly one common side");
		
		Vector3 vA =  NormalizePoint(nodes[iA].position);
		Vector3 vB =  NormalizePoint(nodes[iB].position);
		Vector3 vC1 = NormalizePoint(nodes[iC1].position);
		Vector3 vC2 = NormalizePoint(nodes[iC2].position);
		Vector3 p =   NormalizePoint(position);		
		
		Plane planeA = new Plane(vA, vC1, vC2);
		Plane planeB = new Plane(vB, vC2, vC1);

		Vector3 nA = planeA.normal;
		Vector3 nB = planeB.normal;
		
		if (Vector3.Dot(nA, vA) < 0f)
		{
			nA = -nA;
			nB = -nB;
		}
		
		//Plane planeUV = new Plane( (nA+nB).normalized, vA );
		Vector3 nAB = (nA+nB).normalized;
		
		Vector3 pA = Math3d.ProjectPointOnPlane(nAB, vA, vA, vA);
		//Vector3 pB = Math3d.ProjectPointOnPlane(nAB, vA, vB, vB);
		Vector3 pC1 = Math3d.ProjectPointOnPlane(nAB, vA, vC1, vC1);
		Vector3 pC2 = Math3d.ProjectPointOnPlane(nAB, vA, vC2, vC2);
		Vector3 pP = Math3d.ProjectPointOnPlane(nAB, vA, p, p);
		
		float u = Math3d.PointLineDistance(pP, pA, (pC1-pA).normalized) / (pA-pC2).magnitude;
		float v = Math3d.PointLineDistance(pP, pA, (pC2-pA).normalized) / (pA-pC1).magnitude;
		
		return new Vector2(u*1.5f, v*1.5f); // i have no idea why 1.5 works
	}

	protected override Vector3 GetVertexPositionFromUV(Vector2 uv, int triA, int triB)
	{
		int iA;
		int iB;
		int iC1;
		int iC2;
		GetQuadVertices(triA, triB, out iA, out iB, out iC1, out iC2);
		Utils.Assert(iA >= 0 && iB >= 0 && iC1 >= 0 && iC2 >= 0, "GeoSphere.GetVertexPositionFromUV: triA ("+triA+") and triB ("+triB+") must have exactly one common side");
		
		Vector3 vA =  NormalizePoint(nodes[iA].position);
		Vector3 vB =  NormalizePoint(nodes[iB].position);
		Vector3 vC1 = NormalizePoint(nodes[iC1].position);
		Vector3 vC2 = NormalizePoint(nodes[iC2].position);
		
		float u = uv.x;
		float v = uv.y;
		
		Plane planeA = new Plane(vA, vC1, vC2);
		Plane planeB = new Plane(vB, vC2, vC1);

		Vector3 nA = planeA.normal;
		Vector3 nB = planeB.normal;
		
		if (Vector3.Dot(nA, vA) < 0f)
		{
			nA = -nA;
			nB = -nB;
		}
		
		Vector3 nAB = (nA+nB).normalized;
		
		Vector3 pA = Math3d.ProjectPointOnPlane(nAB, vA, vA, vA);
		Vector3 pB = Math3d.ProjectPointOnPlane(nAB, vA, vB, vB);
		Vector3 pC1 = Math3d.ProjectPointOnPlane(nAB, vA, vC1, vC1);
		Vector3 pC2 = Math3d.ProjectPointOnPlane(nAB, vA, vC2, vC2);
		
		Vector3 pAC1 = Vector3.Lerp(pA, pC1, v);
		Vector3 pC2B = Vector3.Lerp(pC2, pB, v);
		
		return Vector3.Lerp(pAC1, pC2B, u).normalized;
	}
	
	protected override Color Colorize(float[] noiseValues)
	{
		float c = Mathf.Clamp( noiseValues[0], 0f, 2.5f) / 2.5f;
		return new Color(c, c, c);
	}
}


public class GeoQuad : GeoSurface
{
	
	//     C1__________B
	//      /\        /
	//     /  \      /
	//    /    \    /
	//   /      \  /
	//  /________\/
	//  A         C2
	
	public GeoQuad(Vector3 pA, Vector3 pB, Vector3 pC1, Vector3 pC2) : base()
	{
	}
}