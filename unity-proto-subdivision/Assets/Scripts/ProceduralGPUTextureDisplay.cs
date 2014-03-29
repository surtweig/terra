using UnityEngine;
using System.Collections;

public class ProceduralGPUTextureDisplay : MonoBehaviour {

	public ComputeShader PerlinGPU;
	public int Width;
	public int Height;
	
	private ComputeBuffer inputPoints;
	private ComputeBuffer outputValues;
	private int csKernel;
	private const int csThreadGroupSize = 128;
	
	void Start () {
		csKernel = PerlinGPU.FindKernel("kFBM");
		CreateBuffers();
		DispatchCS();

		float[] values = new float[Width*Height];
		outputValues.GetData(values);
		Color[] TexPixels = new Color[Width*Height];
		float fmin = 1001f;
		float fmax = -1001f;
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
			TexPixels[i] = new Color(c, c, c);
		}
		Debug.Log(fmin);
		Debug.Log(fmax);
		
		Texture2D tex = new Texture2D(Width, Height, TextureFormat.RGB24, false);
		renderer.material.mainTexture = tex;
		tex.SetPixels(TexPixels);
		tex.Apply();
	}
	
	private void OnDisable()
	{
		ReleaseBuffers();
	}
	
	private void CreateBuffers()
	{
		inputPoints = new ComputeBuffer(Width*Height, 12); // 3x4 byte float in float3
		
		Vector3[] points = new Vector3[Width*Height];
		for (int ix = 0; ix < Width; ix++)
			for (int iy = 0; iy < Height; iy++)
				points[ix + iy*Height] = new Vector3(ix*0.004f, iy*0.004f, 0f);
		
		inputPoints.SetData(points);
		
		outputValues = new ComputeBuffer(Width*Height, 4); // 4 byte float
	}
	
	private void DispatchCS()
	{
		PerlinGPU.SetBuffer(csKernel, "points", inputPoints);
		PerlinGPU.SetBuffer(csKernel, "values", outputValues);
		PerlinGPU.Dispatch(csKernel, Width*Height/csThreadGroupSize, 1, 1);
	}

	private void ReleaseBuffers()
	{
		inputPoints.Release();
		outputValues.Release();
	}
	
}
