using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.Threading;


public class GeoNode
{
	public Vector3 position;
	public Vector3 normal;
	public float radius;
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
	private int pointsNumber;
	
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
}

public interface IGeoSurfaceConsumer
{
	void OnMeshReady(GeoSurface sender, MeshContainer meshContainer);
}

public class GeoSurface
{
	protected List<GeoNode> nodes;
	protected List<GeoTriTreeNode> tritree;
	protected int xSubdivisionLevel;
	
	public IGeoSurfaceConsumer Consumer = null;
	public ISpatialNoiseGenerator Noise;
	
	public GeoSurface()
	{
		nodes = new List<GeoNode>();
		tritree = new List<GeoTriTreeNode>();
		Noise = new DummyNoiseGenerator();
	}
	
	public virtual Vector3 NormalizePoint(Vector3 point)
	{
		return point;
	}
	
	public virtual Vector3 ElevatePoint(Vector3 point, float elevation)
	{
		return point;
	}
	
	public void BuildNormals()
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
	
	private int xAddNode(GeoNode node)
	{
		int i = nodes.Count;
		nodes.Add(node);
		return i;
	}
	
	private int xAddTriTreeNode(int[] vertices, int parentNode = -1)
	{
		GeoTriTreeNode newNode = new GeoTriTreeNode();
		newNode.vertices = vertices;
		newNode.children = new int[4] { -1, -1, -1, -1 };
		int newNodeIndex = tritree.Count;
		tritree.Add(newNode);
		if (parentNode >= 0)
			for (int i = 0; i < 4; i++)
				if (tritree[parentNode].children[i] == -1)
				{
					tritree[parentNode].children[i] = newNodeIndex;
					break;
				}
		return newNodeIndex;
	}
	
	private void xAddNodeAdjacency(int nodeIndex, int level, int adjNodeIndex)
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
	
	private void xConnectNodes(int node1, int node2, int level)
	{
		xAddNodeAdjacency(node1, level, node2);
		xAddNodeAdjacency(node2, level, node1);
	}
	
	private int xFindNodesCommonAdjacency(int node1, int node2, int level)
	{
		if (nodes[node1].adjacency.Count <= level || nodes[node2].adjacency.Count <= level)
			return -1;
		foreach (int adj1 in nodes[node1].adjacency[level])
			foreach (int adj2 in nodes[node2].adjacency[level])
				if (adj1 == adj2)
					return adj1;
		return -1;
	}	
	
	protected void xCollectVertexes(MutableGeoMesh mesh, int baseTriangleNode, int depth = -1)
	{
		if (depth == 0 || tritree[baseTriangleNode].children[0] < 0)
		{
			for (int i = 0; i < 3; i++)
				mesh.AddVertex(tritree[baseTriangleNode].vertices[i]);
		}
		else
		{
			for (int i = 0; i < 4; i++)
				xCollectVertexes(mesh, tritree[baseTriangleNode].children[i], depth-1);
		}
	}
	
	protected void xSubdivide(int treeNodeIndex)
	{
		if (tritree[treeNodeIndex].children[0] < 0)
		{
			int[] subNodes = new int[3];
			for (int i = 0; i < 3; i++)
			{
				int v1 = tritree[treeNodeIndex].vertices[i];
				int v2 = tritree[treeNodeIndex].vertices[(i+1) % 3];
				
				int v12 = xFindNodesCommonAdjacency(v1, v2, xSubdivisionLevel+1);
				
				if (v12 < 0)
				{
					GeoNode newnode = new GeoNode();
					newnode.position = (nodes[v1].position + nodes[v2].position).normalized;
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
			
			xAddTriTreeNode( new int[3] { tritree[treeNodeIndex].vertices[0], subNodes[0], subNodes[2] }, treeNodeIndex );
			xAddTriTreeNode( new int[3] { tritree[treeNodeIndex].vertices[1], subNodes[1], subNodes[0] }, treeNodeIndex );
			xAddTriTreeNode( new int[3] { tritree[treeNodeIndex].vertices[2], subNodes[2], subNodes[1] }, treeNodeIndex );
			xAddTriTreeNode( new int[3] { subNodes[0], subNodes[1], subNodes[2] }, treeNodeIndex );
		}
		else
			foreach (int childNode in tritree[treeNodeIndex].children)
				xSubdivide(childNode);
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