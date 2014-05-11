using UnityEngine;
using System.Collections;
using System.Collections.Generic;

public class GeosurfaceTest : MonoBehaviour {
	
	public int SubdivisionLevel;
	public ComputeShader FBMGPUProgram;
	public string MethodName;
	public float NoiseScale;
	public float NoiseSpaceScale;
	public int NoiseOctaves;
	public float NoisePersistence;
	public int NoiseIterations;
	public int NoiseGenFrames;
	public int TextureSize;
	public string TexMethodName;
	public GameObject GeosphereRegionPrefab;
	
	private GeoSphere geo;
	private FBMGPU fbmgpu;
	private FBMGPU texfbmgpu;
	private bool imageBuilt = false;
	private List<GameObject> regions = new List<GameObject>();

	private GUIText ProgressText;
	
	void Start ()
	{
		fbmgpu = new FBMGPU(FBMGPUProgram, MethodName);
		fbmgpu.Setup(NoiseOctaves, NoisePersistence);
		fbmgpu.Iterations = NoiseIterations;
		
		texfbmgpu = new FBMGPU(FBMGPUProgram, TexMethodName);
		texfbmgpu.Setup(NoiseOctaves, NoisePersistence);
		texfbmgpu.Iterations = NoiseIterations;

		geo = new GeoSphere();
		geo.Noise = fbmgpu;
		geo.NoiseScale = NoiseScale;
		geo.NoiseGenFrames = NoiseGenFrames;
		geo.TargetSubdivisionLevel = SubdivisionLevel;
		geo.NoiseSpaceScale = NoiseSpaceScale;
		
		geo.TexNoises[0] = texfbmgpu;
		geo.TextureSize = TextureSize;
		
		ProgressText = GameObject.Find("ProgressText").GetComponent<GUIText>() as GUIText;
		
		geo.StartBuilding();
	}
	
	void Update ()
	{
		if (!imageBuilt)
		{
			if (geo.Update())
			{
				imageBuilt = true;
				for (int meshIndex = 0; meshIndex < geo.MeshesCount; meshIndex++)
				{
					GameObject regionObject = Instantiate(GeosphereRegionPrefab, transform.position, transform.rotation) as GameObject;
					regionObject.GetComponent<MeshFilter>().mesh = geo.GetMesh(meshIndex);
				
					Texture2D mainTex = geo.GetTexture(meshIndex);
					regionObject.renderer.material.mainTexture = mainTex;
					mainTex.Apply();
				
					regionObject.transform.parent = transform;
					regions.Add(regionObject);
				}
			}
			
			if (geo.TexturesProgress > 0f)
				ProgressText.text = ((int)(geo.TexturesProgress*100f)).ToString() + "%";
		}
		else
			ProgressText.text = "Done";
		
		transform.RotateAround(new Vector3(0f, 1f, 0f), Time.deltaTime*0.1f);
	}
	
	void OnApplicationQuit()
	{
		geo.StopThreads();
	}
}
