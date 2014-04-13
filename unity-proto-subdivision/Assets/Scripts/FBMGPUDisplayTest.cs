using UnityEngine;
using System.Collections;
using System.Threading;

public class FBMGPUDisplayTest : MonoBehaviour {
	
	public ComputeShader FBMGPUProgram;
	public int Width;
	public int Height;
	public float Scale;
	public string MethodName;
	public int Octaves;
	public float Persistence;
	
	private FBMGPU fbmgpu;
	private Color[] texPixels;
	private bool colorsDone = false;
	private bool texDone = false;
	
	void Start () {
		fbmgpu = new FBMGPU(FBMGPUProgram, MethodName);
		
		Vector3[] points = new Vector3[Width*Height];
		for (int x = 0; x < Width; x++)
			for (int y = 0; y < Height; y++)
				points[x + y*Height] = new Vector3((x/(float)(Width))*Scale, (y/(float)(Height))*Scale, 0f);
		
		fbmgpu.Start(points, 64);
		fbmgpu.Setup(Octaves, Persistence);
	}
	
	void Update () {
		if (!fbmgpu.Done)
			if (fbmgpu.Update())
				OnFBMGenerated();
		
		if (!texDone && colorsDone)
			OnTextureGenerated();
		
		transform.Rotate( new Vector3(0f, 0f, 1f), 10f*Time.deltaTime );
	}
	
	void OnFBMGenerated ()
	{
		Thread texThread = new Thread(BuildTex);
		texThread.Start();
	}
	
	protected void BuildTex()
	{
		texPixels = new Color[Width*Height];
		float fmin = 1001f;
		float fmax = -1001f;
		float[] values = fbmgpu.Output();
		
		for (int i = 0; i < values.Length; i++)
		{
			if (values[i] < fmin)
				fmin = values[i];
			if (values[i] > fmax)
				fmax = values[i];
		}

		for (int i = 0; i < values.Length; i++)
		{
			float c = (values[i]-fmin)/(fmax-fmin);
			texPixels[i] = new Color(c, c, c);
		}
		Debug.Log("fmin = " + fmin);
		Debug.Log("fmax = " + fmax);		
		
		colorsDone = true;
	}
	
	void OnTextureGenerated()
	{
		Texture2D tex = new Texture2D(Width, Height, TextureFormat.RGB24, false);
		renderer.material.mainTexture = tex;
		tex.SetPixels(texPixels);
		tex.Apply();
		texDone = true;
	}
}

