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
		return true;
	}
	
	public float[] Output()
	{
		float[] output = new float[pointsNumber];
		for (int i = 0; i < output.Length; i++)
			output[i] = 0f;
		return output;
	}
	
	public bool Done { get { return true; } }
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
	
	public ISpatialNoiseGenerator Noise;
	public int TargetSubdivisionLevel = 0;
	public int NoiseGenFrames = 32;
	public float NoiseScale = 1f;
	public float NoiseSpaceScale = 1f;
	
	private Thread subdivideThread;
	private Thread applyNoiseThread;
	private Thread buildMeshThread;

	private bool subdivided = false;
	private bool noiseApplied = false;
	private bool meshBuilt = false;
	
	private List<Vector3> noiseInput;
	private float[] noiseOutput;

	public GeoSurface()
	{
		nodes = new List<GeoNode>();
		tritree = new List<GeoTriTreeNode>();
		meshContainers = new List<MeshContainer>();
		Noise = new DummyNoiseGenerator();
		subdivideThread = new Thread(this.SubdivideThreadProc);
		applyNoiseThread = new Thread(this.ApplyNoiseThreadProc);
		buildMeshThread = new Thread(this.BuildMeshThreadProc);
	}
	
	~GeoSurface()
	{
		StopThreads();
	}
	
	public void StopThreads()
	{
		if (subdivideThread.IsAlive)
			subdivideThread.Interrupt();
		if (applyNoiseThread.IsAlive)
			applyNoiseThread.Interrupt();
		if (buildMeshThread.IsAlive)
			buildMeshThread.Interrupt();
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
		if (meshIndex >= 0 && meshIndex < meshContainers.Count)
			return meshContainers[meshIndex].MakeMesh();
		else
			return null;
	}
	
	public virtual bool IsInProgress { get { return subdivideThread.IsAlive || applyNoiseThread.IsAlive || (Noise.Started && !Noise.Done); } }
	
	public virtual bool Done { get { return !IsInProgress && subdivided && noiseApplied && meshBuilt; } }
	
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
			Subdivide(triTreeNode, TargetSubdivisionLevel);
		
		// Collecting points
		noiseInput = new List<Vector3>();
		foreach (GeoNode node in nodes)
			if (!node.transformed)
				noiseInput.Add(node.position * NoiseSpaceScale);
		
		Debug.Log("  GeoSurface.Subdivide thread finish");
		subdivided = true;
	}

	protected virtual void ApplyNoiseThreadProc()
	{
		noiseApplied = false;
		Debug.Log("GeoSurface.ApplyNoise thread start");

		// Applying generated noise
		for (int i = 0; i < nodes.Count; i++)
			if ( !nodes[i].transformed )
			{
				nodes[i].elevation = noiseOutput[i]*NoiseScale;
				nodes[i].position = ElevatePoint(nodes[i].position, nodes[i].elevation);
				nodes[i].transformed = true;
			}
		
		noiseInput.Clear();
		noiseOutput = new float[0] {};
		
		Debug.Log("  GeoSurface.ApplyNoise thread finish");
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
			MutableGeoMesh mutablemesh = new MutableGeoMesh();
			CollectVertexes(mutablemesh, triTreeNode);
			mutablemesh.IndexTriangles();
			
			List<Vector3> vertices = new List<Vector3>();
			List<Vector2> uv = new List<Vector2>();
			List<Vector3> normals = new List<Vector3>();
			
			foreach (int nodeIndex in mutablemesh.indexes)
			{
				vertices.Add(nodes[nodeIndex].position);
				normals.Add(nodes[nodeIndex].normal);
			}
			
			MeshContainer meshContainer = new MeshContainer();
			meshContainer.vertices = vertices.ToArray();
			meshContainer.normals = normals.ToArray();
			meshContainer.triangles = mutablemesh.triangles.ToArray();
			
			meshContainers.Add(meshContainer);
		}
		
		Debug.Log("  GeoSurface.BuildMesh thread finish");
		meshBuilt = true;
	}
	
	public virtual bool Update()
	{
		if (subdivided)
		{
			if ( !Noise.Started )
				Noise.Start(noiseInput.ToArray(), NoiseGenFrames);

			if ( Noise.Update() && !applyNoiseThread.IsAlive && !noiseApplied )
			{
				noiseOutput = Noise.Output();
				applyNoiseThread.Start();
			}
		}
		if (noiseApplied)
		{
			if ( !buildMeshThread.IsAlive && !meshBuilt )
				buildMeshThread.Start();
		}
		return Done;
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
		
		//if (!addedToChildren && parentNode >= 0)
		//	Debug.LogError("Geosphere.GeoSurface.xAddTriTreeNode : can't add new tritree node to parentNode " + parentNode + " - it has 4 children already");
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
	
	public static int[,] IcosahedronTrianglePairs = new int[IcosahedronTriangles/2, 2]
		{ {0, 1}, {2, 3}, {15, 4}, {14, 5}, {19, 6}, {16, 7}, {12, 8}, {18, 9}, {13, 10}, {17, 11} };
	
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