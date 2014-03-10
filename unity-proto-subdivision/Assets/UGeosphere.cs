using UnityEngine;
using System.Collections;
using System.Collections.Generic;
//using TGeosphereNodeAdjacency = int;

struct TGeoNode
{
	Vector3 position;
	Vector3 normal;
	float radius;
	int[][] adjacency;
}

struct TGeoTriTreeNode
{
	int[] vertices;
	int[] children;
}

public class TGeosphere {
	
	// -------------------------------------------------------
	public TGeosphere()
	{
	}

	public TGeosphere(TGeosphere sourceGeo)
	{
		
	}

	public void BuildIcosahedron()
	{
	}

	public void Subdivide(int depth = 1)
	{
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
	
	
}

public class UGeosphere : MonoBehaviour {
	
	void Start () {
	
	}
	
	void Update () {
	
	}
}
