using UnityEngine;
using System.Collections;
using System.Threading;

public class ProceduralTextureDisplay : MonoBehaviour {
	
	public int Width;
	public int Height;
	
	protected bool ThreadFinished = false;
	protected Color[] TexPixels;
	protected FBM fbm;
	
	void Start () {
		//fbm = new FBM(new TPerlin3DNoise());
		//fbm = new OaxoaSubtractiveFBM(new TPerlin3DNoise(), 10);
		fbm = new DomainWarpingFBM(new TPerlin3DNoise(), 2);
		fbm.SetSpectrum(7, 0.75f);
		Thread generateThread = new Thread(GenerateTexutre);
		generateThread.Start(this);
	}
	
	void Update () {
		if (ThreadFinished)
		{
			ThreadFinished = false;
			Texture2D tex = new Texture2D(Width, Height, TextureFormat.RGB24, false);
			renderer.material.mainTexture = tex;
			tex.SetPixels(TexPixels);
			tex.Apply();
		}
	}
	
	public static void GenerateTexutre(object thisTex)
	{
		int w = (thisTex as ProceduralTextureDisplay).Width;
		int h = (thisTex as ProceduralTextureDisplay).Height;

		float[] field;
		float fmin = 1000f;
		float fmax = -1000f;
		
		FBMBatchTask calcFieldTask = new FBMBatchTask((thisTex as ProceduralTextureDisplay).fbm, 4);
		Vector3[] points = new Vector3[w*h];
		for (int x = 0; x < w; x++)
			for (int y = 0; y < h; y++)
				points[y*h + x] = new Vector3( (float)x/(float)w, (float)y/(float)h, 0f );
		
		calcFieldTask.Start(points);
		
		// wait
		while ( !calcFieldTask.Done() ) {};
		
		field = calcFieldTask.Output();
		
		for (int x = 0; x < w; x++)
			for (int y = 0; y < h; y++)
			{
				//float f = (thisTex as ProceduralTextureDisplay).fbm.Value(new Vector3( (float)x/(float)w, (float)y/(float)h, 0f ));
				
				float f = field[y*h + x];
				if (f < fmin)
					fmin = f;
				if (f > fmax)
					fmax = f;
			}

		(thisTex as ProceduralTextureDisplay).TexPixels = new Color[w*h];

		for (int x = 0; x < w; x++)
			for (int y = 0; y < h; y++)
			{
				float f = (field[y*h + x]-fmin)/(fmax-fmin);
				(thisTex as ProceduralTextureDisplay).TexPixels[y*h + x] = new Color(f, f, f);		
			}
		(thisTex as ProceduralTextureDisplay).ThreadFinished = true;
		
		Debug.Log(fmin);
		Debug.Log(fmax);
	}
}
