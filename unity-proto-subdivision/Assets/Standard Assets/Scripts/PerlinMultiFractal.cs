using UnityEngine;
using System.Collections;
using System.Threading;

// Fractional Brownian motion
public class FBM
{
	public float Scale = 1f;
	public float Lacunarity = 2f;
	public float[] Spectrum;
	
	protected TPerlin3DNoise xNoise;
	protected bool xSpectrumAutoNormalize = true;
	
	public FBM(TPerlin3DNoise noise)
	{
		xNoise = noise;
	}
	
	public int Octaves
	{
		get { return Spectrum.Length; }
	}
	
	public virtual void SetSpectrum(int octaves, float persistence = 0f)
	{
		Spectrum = new float[octaves];
		for (int i = 0; i < octaves; i++)
		{
			Spectrum[i] = Mathf.Pow(Lacunarity, -i*persistence);
		}
		if (xSpectrumAutoNormalize)
			NormalizeSpectrum();
	}
	
	public void NormalizeSpectrum()
	{
		float accum = 0f;
		foreach (float freq in Spectrum)
			accum += freq;
		for (int i = 0; i < Octaves; i++)
			Spectrum[i] /= accum;
	}
	
	protected virtual float TransformOctave(float v)
	{
		return v;
	}
	
	public virtual float Value(Vector3 position)
	{
		float v = 0f;
		Vector3 p = position;		
		
		for (int i = 0; i < Octaves; i++)
		{
			v += xNoise.Noise(p) * Spectrum[i];
			p *= Lacunarity;
		}
		
		return v;
	}
}

public class RidgedFBM : FBM
{
	public RidgedFBM(TPerlin3DNoise noise) : base(noise)
	{
	}
	
	protected override float TransformOctave(float n)
	{
		return 2f * (0.5f - Mathf.Abs(n));
	}
}

public class OaxoaSubtractiveFBM : FBM
{
	public int Iterations;
	private FBM xFBM;
	
	public OaxoaSubtractiveFBM(TPerlin3DNoise noise, int iterations) : base(noise)
	{
		Iterations = iterations;
		xFBM = new FBM(noise);
	}

	public override void SetSpectrum(int octaves, float persistence)
	{
		xFBM.SetSpectrum(octaves, persistence);
	}
	
	public override float Value(Vector3 position)
	{
		float v = Mathf.Abs(xFBM.Value(position*Scale));
		//v = 2f*(v-0.5f);
		
		float a;
		for (int i = 0; i < Iterations; i++)
		{
			v = Mathf.Abs( v - xFBM.Value(position*Scale + 2f*Scale*(new Vector3(i+1, i+1, i+1))) );
			//v = 2f*(v-0.5f);
		}
		return v;
	}
}

public class DomainWarpingFBM : FBM
{
	public int Iterations;
	private FBM xFBM;
	
	public DomainWarpingFBM(TPerlin3DNoise noise, int iterations = 2) : base(noise)
	{
		Iterations = iterations;
		xFBM = new FBM(noise);
		xFBM.SetSpectrum(10, 2f);
	}
	
	public override void SetSpectrum(int octaves, float persistence)
	{
		xFBM.SetSpectrum(octaves, persistence);
	}
	
	protected Vector3 VectorValue(Vector3 position, Vector3 offset)
	{
		return new Vector3( xFBM.Value(position + offset), xFBM.Value(position + 2f*offset), xFBM.Value(position + 3f*offset) );
	}
	
	public override float Value(Vector3 position)
	{
		Vector3 p = position*Scale;
		Vector3 offset = position*Scale;
		
		for (int i = 0; i < Iterations; i++)
		{
			p = VectorValue(p, offset);
			offset += 3f*position*Scale;
		}
		
		return xFBM.Value(position*Scale + p);
		
		//return xFBM.Value( position + 4f*VectorValue(position, new Vector3(1.23f, 2.34f, 3.45f)) );
	}
}

public class HybridFBM : FBM
{
	public HybridFBM(TPerlin3DNoise noise) : base(noise)
	{
		xSpectrumAutoNormalize = false;
	}
	
	public override float Value(Vector3 position)
	{
		Vector3 p = position*Scale;
		float v = (1f - Mathf.Abs(xNoise.Noise(p))) * Spectrum[0];
		float weight = v;
		
		for (int octave = 1; octave < Octaves; octave++)
		{
			if (weight > 1f) weight = 1f;
			
			float a = (1f - Mathf.Abs(xNoise.Noise(p))) * Spectrum[octave];
			v += weight*a;
			weight *= a;
			
			p *= Lacunarity;
		}
		
		return v;
	}
}

public class FBMBatchTask
{
	public FBMBatchTask(FBM fbm, int maxThreads)
	{
		threadsCount = maxThreads;
		if (threadsCount < 1)
			threadsCount = 1;
		if (threadsCount > System.Environment.ProcessorCount)
			threadsCount = System.Environment.ProcessorCount;

		xFBM = fbm;
	}
	
	public bool Start(Vector3[] points)
	{
		if (threadsFinished == threads.Length)
		{
			input = points;
			output = new float[input.Length];
			threadsFinished = 0;
			threads = new Thread[threadsCount];
			for (int i = 0; i < threadsCount; i++)
			{
				threads[i] = new Thread(ThreadProc);
				threads[i].Start(i);
			}
			return true;
		}
		return false;
	}
	
	public bool Done()
	{
		if (threadsFinished == threads.Length)
		{
			input = new Vector3[] {};
			threads = new Thread[] {};
			threadsFinished = 0;
			return true;
		}
		else
			return false;
	}
	
	public float[] Output()
	{
		if ( Done() )
			return output;
		else
			return (new float[] {});
	}
	
	private void ThreadProc(object threadIndex)
	{
		int pos = (int)threadIndex;
		while (pos < output.Length)
		{
			output[pos] = xFBM.Value(input[pos]);
			pos += threadsCount;
		}
		
		Interlocked.Increment(ref threadsFinished);
	}
	
	private int threadsCount;
	private FBM xFBM;
	private Thread[] threads = new Thread[] {};
	private float[] output;
	private Vector3[] input;
	private int threadsFinished = 0; // Interlocked.Increment(ref threadsFinished)
}