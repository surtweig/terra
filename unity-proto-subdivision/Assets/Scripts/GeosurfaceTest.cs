﻿using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.IO;

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
	public int TexNoiseOctaves;
	public float TexNoisePersistence;
	public int TexNoiseIterations;
	public float TexNoiseSpaceScale;
	public GameObject GeosphereRegionPrefab;
	public GameObject AtmosphereRegionPrefab;
	public ComputeShader NormalMapGPUProgram;
	public bool SaveTextures;
	public bool UseNormalMap;
	public bool BuildAtmosphere;
	
	private GeoSphere geo;
	private FBMGPU fbmgpu;
	private FBMGPU texfbmgpu;
	private GPUTextureProcessor<Vector3, Vector3> nmapgpu;
	private bool imageBuilt = false;
	private List<GameObject> regions = new List<GameObject>();
	
	private string debug_out = "#deltaTime\tsurfacegpu\tcolorgpu\tnormalgpu\r\n";

	private GUIText ProgressText;
	
	void Start ()
	{
		/*switch (QualitySettings.GetQualityLevel())
		{
			case 0:
				TextureSize = 512;
				SubdivisionLevel = 6;
				break;
			case 1:
				TextureSize = 512;
				SubdivisionLevel = 7;
				break;
			case 2:
				TextureSize = 1024;
				SubdivisionLevel = 7;
				break;
		}*/
		
		fbmgpu = new FBMGPU(FBMGPUProgram, MethodName);
		fbmgpu.Setup(NoiseOctaves, NoisePersistence);
		fbmgpu.Iterations = NoiseIterations;
		fbmgpu.Gamma = 2f;
		
		texfbmgpu = new FBMGPU(FBMGPUProgram, TexMethodName);
		texfbmgpu.Setup(TexNoiseOctaves, TexNoisePersistence);
		texfbmgpu.Iterations = TexNoiseIterations;
		texfbmgpu.Gamma = 2f;
		
		nmapgpu = new GPUTextureProcessor<Vector3, Vector3>(NormalMapGPUProgram, "NormalMap3x3", 1, 3, 3);

		geo = new GeoSphere();
		geo.Noise = fbmgpu;
		geo.NoiseScale = NoiseScale;
		geo.NoiseGenFrames = NoiseGenFrames;
		geo.TargetSubdivisionLevel = SubdivisionLevel;
		geo.NoiseSpaceScale = NoiseSpaceScale;
		geo.TexNoiseSpaceScale = TexNoiseSpaceScale;
		geo.BuildAtmosphere = BuildAtmosphere;
		
		geo.TexNoises[0] = texfbmgpu;
		geo.TextureSize = TextureSize;
		
		geo.NormalMapGenerator = nmapgpu;
		
		ProgressText = GameObject.Find("ProgressText").GetComponent<GUIText>() as GUIText;
		
		geo.StartBuilding();
	}
	
	void Update ()
	{
		
		//debug_out += Time.deltaTime.ToString() + "\t" + geo.debug_surfacegpuloaded + "\t" + (int)geo.debug_colorgpuloaded + "\t" + (int)geo.debug_normalgpuloaded + "\r\n";
			
		if (!imageBuilt)
		{
			if (geo.Update())
			{
				
				imageBuilt = true;
				for (int meshIndex = 0; meshIndex < geo.MeshesCount; meshIndex++)
				{
					GameObject regionObject = Instantiate(GeosphereRegionPrefab, transform.position, transform.rotation) as GameObject;
					regionObject.GetComponent<MeshFilter>().mesh = geo.GetMesh(meshIndex);
					Debug.Log("Verices count:" + regionObject.GetComponent<MeshFilter>().mesh.vertexCount);

					if (BuildAtmosphere)
					{
						GameObject atmRegionObject = Instantiate(AtmosphereRegionPrefab, transform.position, transform.rotation) as GameObject;
						atmRegionObject.GetComponent<MeshFilter>().mesh = geo.GetAtmoMesh(meshIndex);
						atmRegionObject.transform.parent = transform;
					}

					Texture2D mainTex = geo.GetTexture(meshIndex);
					regionObject.renderer.material.mainTexture = mainTex;
					mainTex.Apply();
					
					if (UseNormalMap)
					{
						Texture2D normalMap = geo.GetNormalMap(meshIndex);
						regionObject.renderer.material.SetTexture("_NormalTexture", normalMap);
						normalMap.Apply();
						if (SaveTextures)
						{
							byte[] png = normalMap.EncodeToPNG();
							File.WriteAllBytes(Application.dataPath + "/../Output/normal" + meshIndex + ".png", png);
						}
					}
				
					if (SaveTextures)
					{
						byte[] png = mainTex.EncodeToPNG();
						File.WriteAllBytes(Application.dataPath + "/../Output/diffuse" + meshIndex + ".png", png);
					}

					regionObject.transform.parent = transform;
					
					regions.Add(regionObject);
				}

				Debug.Log("topo size = " + geo.GetTopologySize());
			}
			
			if (geo.TexturesProgress > 0f)
				ProgressText.text = ((int)(geo.TexturesProgress*100f)).ToString() + "%";
		}
		else
			ProgressText.text = "Done";
		
		transform.RotateAround(new Vector3(0f, 1f, 0f), Time.deltaTime*0.1f);
	}
	
	public void SaveDebugFile()
	{
		StreamWriter writer = new StreamWriter(Application.dataPath + "/../Output/debug_out.adv");
		writer.Write(debug_out);
		writer.Close();
	}
	
	void OnApplicationQuit()
	{
		geo.StopThreads();
		SaveDebugFile();
	}
}
