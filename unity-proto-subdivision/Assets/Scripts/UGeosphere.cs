using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.Threading;

public class TGeoNode
{
	public Vector3 position;
	public Vector3 normal;
	public float radius;
	public List<int[]> adjacency;
	
	public TGeoNode()
	{
		adjacency = new List<int[]>();
	}
}

public class TGeoTriTreeNode
{
	public int[] vertices;
	public int[] children;
}

public class TMutableGeoMesh
{
	public List<int> indexes;
	public List<int> triangles;
	
	public TMutableGeoMesh()
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
	public int[] triangles;
	
	public Mesh MakeMesh()
	{
		Mesh mesh = new Mesh();
		mesh.vertices = vertices;
		mesh.normals = normals;
		mesh.triangles = triangles;
		return mesh;
	}
}

public class TGeosphere {
	
	// -------------------------------------------------------
	public TGeosphere(int seed = 0)
	{
		xSeed = seed;
		xPerlinNoise = new TPerlin3DNoise(xSeed);
	}
	
	public void Clear()
	{
		xNodes.Clear();
		xTriTree.Clear();
		xSubdivisionLevel = 0;
	}
	
	public int SubdivisionLevel
	{
		get { return xSubdivisionLevel; }
	}
	
	public int Seed
	{
		get { return xSeed; }
	}

	public void BuildIcosahedron()
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
			TGeoNode node = new TGeoNode();
			node.position = icoverts[i].normalized;
			node.radius = 1f;
			node.adjacency.Add(icoadj[i]);
			xNodes.Add(node);
		}
		
		for (int i = 0; i < icotris.Length; i++)
			xAddTriTreeNode(icotris[i]);
	}

	public void Subdivide(int depth = 1)
	{
		
		for (int iter = 0; iter < depth; iter++)
		{
			for (int i = 0; i < IcosahedronTriangles; i++)
				xSubdivide(i);
			
			xSubdivisionLevel++;
		}
	}
	
	public bool SubdivideThreaded(int targetSubdivisionLevel = 1)
	{
		if (xSubdivisionLevel < targetSubdivisionLevel && !xSubdivisionThreadIsRunning)
		{
			Thread thread = new Thread(TGeosphere.SubdivisionThread);
			xSubdivisionThreadIsRunning = true;
			thread.Start(this);
			return true;
		}
		else return false;
	}
	
	public MeshContainer GenerateMesh(int region = -1, bool generateUV = false, int depth = -1)
	{
		TMutableGeoMesh geomesh = new TMutableGeoMesh();
		xCollectVertexes(geomesh, region, depth);
		geomesh.IndexTriangles();
		
		BuildNormals();
		
		List<Vector3> vertices = new List<Vector3>();
		List<Vector3> normals = new List<Vector3>();
		List<Vector2> uv = new List<Vector2>();
		
		foreach (int nodeIndex in geomesh.indexes)
		{
			vertices.Add(xNodes[nodeIndex].position);
			normals.Add(xNodes[nodeIndex].normal);
		}
		
		//Debug.Log(vertices.Count);
		//Debug.Log(geomesh.triangles.Count);

		/*Mesh mesh = new Mesh();
		mesh.vertices = vertices.ToArray();
		mesh.normals = normals.ToArray();
		mesh.triangles = geomesh.triangles.ToArray();
		return mesh;*/
		
		MeshContainer meshContainer = new MeshContainer();
		meshContainer.vertices = vertices.ToArray();
		meshContainer.normals = normals.ToArray();
		meshContainer.triangles = geomesh.triangles.ToArray();
		
		return meshContainer;
	}
	
	public void BuildNormals()
	{
		for (int i = 0; i < xNodes.Count; i++)
		{
			float nx = 0f;
			float ny = 0f;
			float nz = 0f;
			
			int highlev = xNodes[i].adjacency.Count-1;
			
			int icurrent = -1;
			Vector3 vcurrent = xNodes[i].position;

			int inext = xNodes[i].adjacency[highlev][0];
			Vector3 vnext = xNodes[inext].position;
			
			int ifirst = inext;
			
			while (true)
			{
				nx += (vcurrent.y - vnext.y) * (vcurrent.z + vnext.z);
				ny += (vcurrent.z - vnext.z) * (vcurrent.x + vnext.x);
				nz += (vcurrent.x - vnext.x) * (vcurrent.y + vnext.y);
				
				// finding next node as common adjacent of center and current node, but not previous
				bool nextfound = false;
				for (int j = 0; j < xNodes[i].adjacency[highlev].Length; j++)
				{
					for (int k = 0; k < xNodes[inext].adjacency[highlev].Length; k++)
						if (xNodes[i].adjacency[highlev][j] == xNodes[inext].adjacency[highlev][k])
							if (xNodes[i].adjacency[highlev][j] != icurrent)
							{
								icurrent = inext;
								inext = xNodes[i].adjacency[highlev][j];
								nextfound = true;
								break;
							}
					
					if (nextfound)
						break;
				}
				
				vcurrent = vnext;
				vnext = xNodes[inext].position;
				
				if (inext == ifirst)
					break;
			}
			
			vnext = xNodes[i].position;
			nx += (vcurrent.y - vnext.y) * (vcurrent.z + vnext.z);
			ny += (vcurrent.z - vnext.z) * (vcurrent.x + vnext.x);
			nz += (vcurrent.x - vnext.x) * (vcurrent.y + vnext.y);
			
			Vector3 normal = new Vector3(nx, ny, nz).normalized;
			
			if (Vector3.Dot(normal, vnext.normalized) < 0)
				normal = -normal;
			
			xNodes[i].normal = normal;
		}
	}
	
	public void ApplyPerlinNoise()//(int method, float scale, int startOctave, int finishOctave, float[] spectrum)
	{
		foreach (TGeoNode node in xNodes)
		{
			node.position = node.position.normalized * (1f + xPerlinNoise.Noise( node.position.normalized * 10f ) * 0.1f);
			node.radius = node.position.magnitude;
		}
	}

	protected void xCollectVertexes(TMutableGeoMesh mesh, int baseTriangleNode = -1, int depth = -1)
	{
		if (baseTriangleNode < 0)
		{
			for (int i = 0; i < IcosahedronTriangles; i++)
				xCollectVertexes(mesh, i, depth);
		}
		else
		{
			if (depth == 0 || xTriTree[baseTriangleNode].children[0] < 0)
			{
				for (int i = 0; i < 3; i++)
					mesh.AddVertex(xTriTree[baseTriangleNode].vertices[i]);
			}
			else
			{
				for (int i = 0; i < 4; i++)
					xCollectVertexes(mesh, xTriTree[baseTriangleNode].children[i], depth-1);
			}
		}
	}
	
	protected void xSubdivide(int treeNodeIndex)
	{
		if (xTriTree[treeNodeIndex].children[0] < 0)
		{
			int[] subNodes = new int[3];
			
			for (int i = 0; i < 3; i++)
			{
				int v1 = xTriTree[treeNodeIndex].vertices[i];
				int v2 = xTriTree[treeNodeIndex].vertices[(i+1) % 3];
				
				int v12 = xFindNodesCommonAdjacency(v1, v2, xSubdivisionLevel+1);
				
				if (v12 < 0)
				{
					TGeoNode newnode = new TGeoNode();
					newnode.position = (xNodes[v1].position + xNodes[v2].position).normalized;
					newnode.radius = 1f;
					newnode.adjacency = new List<int[]>();
					v12 = xAddNode(newnode);
					
					xConnectNodes(v12, v1, xSubdivisionLevel+1);
					xConnectNodes(v12, v2, xSubdivisionLevel+1);
				}
				
				subNodes[i] = v12;
			}
			
			xConnectNodes(subNodes[0], subNodes[1], xSubdivisionLevel+1);
			xConnectNodes(subNodes[1], subNodes[2], xSubdivisionLevel+1);
			xConnectNodes(subNodes[2], subNodes[0], xSubdivisionLevel+1);
			
			//      /\
			//     /  \
			//    /----\
			//   / \  / \
			//  /___\/___\
			
			xAddTriTreeNode( new int[3] { xTriTree[treeNodeIndex].vertices[0], subNodes[0], subNodes[2] }, treeNodeIndex );
			xAddTriTreeNode( new int[3] { xTriTree[treeNodeIndex].vertices[1], subNodes[1], subNodes[0] }, treeNodeIndex );
			xAddTriTreeNode( new int[3] { xTriTree[treeNodeIndex].vertices[2], subNodes[2], subNodes[1] }, treeNodeIndex );
			xAddTriTreeNode( new int[3] { subNodes[0], subNodes[1], subNodes[2] }, treeNodeIndex );
		}
		else
			foreach (int childNode in xTriTree[treeNodeIndex].children)
				xSubdivide(childNode);
	}
	
	// -------------------------------------------------------
	public const int IcosahedronTriangles = 20;
	
	public static int[,] IcosahedronTrianglePairs = new int[IcosahedronTriangles/2, 2]
		{ {0, 1}, {2, 3}, {15, 4}, {14, 5}, {19, 6}, {16, 7}, {12, 8}, {18, 9}, {13, 10}, {17, 11} };
	
	public static int[] IcosahedronTriangleToPairsMap = new int[IcosahedronTriangles]
		{ 0, 0, 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 6, 8, 3, 2, 5, 9, 7, 4 };
	
	// -------------------------------------------------------
	private List<TGeoNode> xNodes = new List<TGeoNode>();
	private List<TGeoTriTreeNode> xTriTree = new List<TGeoTriTreeNode>();
	private int xSubdivisionLevel = 0;
	private int xSeed;
	private TPerlin3DNoise xPerlinNoise;
	protected bool xSubdivisionThreadIsRunning = false;
	public MeshContainer[] RegionsMeshes = new MeshContainer[IcosahedronTriangles];
	
	private int xAddNode(TGeoNode node)
	{
		int i = xNodes.Count;
		xNodes.Add(node);
		return i;
	}
	
	private int xAddTriTreeNode(int[] vertices, int parentNode = -1)
	{
		TGeoTriTreeNode newNode = new TGeoTriTreeNode();
		newNode.vertices = vertices;
		newNode.children = new int[4] { -1, -1, -1, -1 };
		int newNodeIndex = xTriTree.Count;
		xTriTree.Add(newNode);
		if (parentNode >= 0)
			for (int i = 0; i < 4; i++)
				if (xTriTree[parentNode].children[i] == -1)
				{
					xTriTree[parentNode].children[i] = newNodeIndex;
					break;
				}
		return newNodeIndex;
	}
	
	private void xAddNodeAdjacency(int nodeIndex, int level, int adjNodeIndex)
	{
		int maxLevel = xNodes[nodeIndex].adjacency.Count-1;
		if (maxLevel < level)
			for (int i = maxLevel; i < level; i++)
				xNodes[nodeIndex].adjacency.Add(new int[] {});
		
		int[] adj = new int[xNodes[nodeIndex].adjacency[level].Length+1];
		xNodes[nodeIndex].adjacency[level].CopyTo(adj, 0);
		adj[adj.Length-1] = adjNodeIndex;
		xNodes[nodeIndex].adjacency[level] = adj;
	}
	
	private void xConnectNodes(int node1, int node2, int level)
	{
		xAddNodeAdjacency(node1, level, node2);
		xAddNodeAdjacency(node2, level, node1);
	}
	
	private int xFindNodesCommonAdjacency(int node1, int node2, int level)
	{
		if (xNodes[node1].adjacency.Count <= level || xNodes[node2].adjacency.Count <= level)
			return -1;
		foreach (int adj1 in xNodes[node1].adjacency[level])
			foreach (int adj2 in xNodes[node2].adjacency[level])
				if (adj1 == adj2)
					return adj1;
		return -1;
	}
	
	public static void SubdivisionThread(object thisGeo)
	{
		(thisGeo as TGeosphere).Subdivide();
		(thisGeo as TGeosphere).ApplyPerlinNoise();
		for (int region = 0; region < IcosahedronTriangles; region++)
			(thisGeo as TGeosphere).RegionsMeshes[region] = (thisGeo as TGeosphere).GenerateMesh(region);
		(thisGeo as TGeosphere).xSubdivisionThreadIsRunning = false;
	}
	
}


public class UGeosphere : MonoBehaviour {
	
	public GameObject GeosphereRegionPrefab;
	
	private TGeosphere geo;
	private int currentSubdivisionLevel = 0;
	private List<GameObject> regions = new List<GameObject>();
	
	void Start () {
		geo = new TGeosphere();
		geo.BuildIcosahedron();
		
		//geo.Subdivide(6);
		//geo.ApplyPerlinNoise();
		
		//GetComponent<MeshFilter>().mesh = geo.GenerateMesh();
		
		for (int region = 0; region < TGeosphere.IcosahedronTriangles; region++)
		{
			GameObject regionObject = Instantiate(GeosphereRegionPrefab, transform.position, transform.rotation) as GameObject;
			//regionObject.GetComponent<MeshFilter>().mesh = geo.GenerateMesh(region);
			regionObject.transform.parent = transform;
			regions.Add(regionObject);
		}
		
	}
	
	void Update () {
		transform.RotateAround(new Vector3(0f, 1f, 0f), Time.deltaTime*0.1f);
		
		if (currentSubdivisionLevel != geo.SubdivisionLevel)
		{
			for (int region = 0; region < regions.Count; region++)
			{
				regions[region].GetComponent<MeshFilter>().mesh = geo.RegionsMeshes[region].MakeMesh();//GenerateMesh(region);
			}
			currentSubdivisionLevel = geo.SubdivisionLevel;
		}
		
		geo.SubdivideThreaded(7);
	}
}
