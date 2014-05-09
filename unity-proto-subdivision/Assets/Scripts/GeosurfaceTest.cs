using UnityEngine;
using System.Collections;
using System.Collections.Generic;

public class GeosurfaceTest : MonoBehaviour {
	
	public int SubdivisionLevel;
	public ComputeShader FBMGPUProgram;
	public string MethodName;
	public float NoiseScale;
	public float NoiseSpaceScale;
	public int NoiseGenFrames;
	public GameObject GeosphereRegionPrefab;
	
	private GeoSphere geo;
	private FBMGPU fbmgpu;
	private bool imageBuilt = false;
	private List<GameObject> regions = new List<GameObject>();
	
	void Start ()
	{
		geo = new GeoSphere();
		fbmgpu = new FBMGPU(FBMGPUProgram, MethodName);
		fbmgpu.Setup(10, 1.1f);
		fbmgpu.Iterations = 3;
		
		geo.Noise = fbmgpu;
		geo.NoiseScale = NoiseScale;
		geo.NoiseGenFrames = NoiseGenFrames;
		geo.TargetSubdivisionLevel = SubdivisionLevel;
		geo.NoiseSpaceScale = NoiseSpaceScale;
		
		geo.StartBuilding();
	}
	
	void Update ()
	{
		if (!imageBuilt)
			if (geo.Update())
			{
				for (int meshIndex = 0; meshIndex < geo.MeshesCount; meshIndex++)
				{
					GameObject regionObject = Instantiate(GeosphereRegionPrefab, transform.position, transform.rotation) as GameObject;
					regionObject.GetComponent<MeshFilter>().mesh = geo.GetMesh(meshIndex);
					regionObject.transform.parent = transform;
					regions.Add(regionObject);
				}
				imageBuilt = true;
			}
	}
	
	void OnApplicationQuit()
	{
		geo.StopThreads();
	}
}
