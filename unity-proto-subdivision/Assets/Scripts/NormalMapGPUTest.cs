using UnityEngine;
using System.Collections;
using System.Threading;

public class NormalMapGPUTest : MonoBehaviour {
	
	public ComputeShader SignalProcessingGPUProgram;
	public int Width;
	public string MethodName;
	
	private GPUSignalProcessor<Vector3, Vector3> spgpu;
	private Color[] texPixels;
	private bool colorsDone = false;
	private bool texDone = false;
	
	void Start () {
		spgpu = new GPUTextureProcessor<Vector3, Vector3>(SignalProcessingGPUProgram, MethodName, 1, 3, 3);
		
		Vector3[] points = new Vector3[(Width+2)*(Width+2)];
		for (int x = 0; x < Width+2; x++)
			for (int y = 0; y < Width+2; y++)
			{
				//float c = 0f;
				//if (x % 27 == 0 || y % 27 == 0)
				//	c = 1f;
				points[x + y*(Width+2)] = (1f + Mathf.Sin( (float)x*0.1f ) * Mathf.Sin( (float)y*0.1f )) * new Vector3( (float)x*0.1f, (float)y*0.1f, 0f );
			}
		
		spgpu.SetInput(points, 128);
		spgpu.Start();
	}
	
	void Update ()
	{
		if (!spgpu.Done)
			if (spgpu.Update())
				OnSPGenerated();
		
		if (!texDone && colorsDone)
			OnTextureGenerated();
		
		//transform.Rotate( new Vector3(0f, 0f, 1f), 10f*Time.deltaTime );
	}
	
	void OnSPGenerated ()
	{
		Debug.Log("OnSPGenerated");
		Thread texThread = new Thread(BuildTex);
		texThread.Start();
	}
	
	protected void BuildTex()
	{
		Debug.Log("BuildTex");
		texPixels = new Color[Width*Width];
		Vector3[] values = spgpu.GetOutput();
		for (int i = 0; i < texPixels.Length; i++)
		{
			texPixels[i] = new Color(values[i].x, values[i].y, values[i].z);
		}
		colorsDone = true;
	}
	
	void OnTextureGenerated()
	{
		Debug.Log("OnTextureGenerated");
		Texture2D tex = new Texture2D(Width, Width, TextureFormat.RGB24, true, true);
		renderer.material.mainTexture = tex;
		tex.wrapMode = TextureWrapMode.Clamp;
		tex.SetPixels(texPixels);
		tex.Apply();
		texDone = true;
	}		
}
