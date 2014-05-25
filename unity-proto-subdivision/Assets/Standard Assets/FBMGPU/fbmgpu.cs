using UnityEngine;
using System.Collections.Generic;
using System.Threading;
using System;

public interface ISpatialNoiseGenerator
{
	void Start(Vector3[] points, int steps);
	bool Update();
	float[] Output();
	void Reset();
	bool Done { get; }
	bool Started { get; }
}

public class FBMGPU : ISpatialNoiseGenerator
{
	public FBMGPU (ComputeShader program, string methodName)
	{
		gpuProgram = program;
		method = gpuProgram.FindKernel("k_"+methodName);
	}
	
	public void Setup(float[] baseSpectrum)
	{
		this.baseSpectrum = baseSpectrum;
	}

	public void Setup(int octaves, float persistence)
	{
		float[] spectrum = new float[octaves];
		for (int octave = 0; octave < octaves; octave++)
			spectrum[octave] = Mathf.Pow(2f, -(float)(octave)*persistence);
		Setup(spectrum);
	}
	
	public float Gamma = 1f;
	public int Iterations = 1;

	public void Start(Vector3[] points, int steps)
	{
		inputPoints = points;
		outputValues = new float[inputPoints.Length];
		
		stepsCount = steps;
		if (stepsCount < 0) stepsCount = 1;
		if (stepsCount > inputPoints.Length) stepsCount = inputPoints.Length;
		stepIndex = 0;
	}
	
	public bool Done { get { return (stepIndex >= stepsCount); } }
	public bool Started { get { return (stepIndex >= 0); } }
	public int StepIndex { get { return stepIndex; } }
	public int StepsCount { get { return stepsCount; } }
	
	public bool Update()
	{
		if (!Done && Started)
		{
			PrepareBuffers();
			Dispatch();
			ReleaseBuffers();
		
			stepIndex++;
		}
		return Done;
	}
	
	public float[] Output()
	{
		if (Done) return outputValues;
		else return (new float[0] {});
	}
	
	protected virtual void PrepareBuffers()
	{
		Vector3[] stepPoints = new Vector3[ (inputPoints.Length) / stepsCount ];
		for (int i = 0; i < stepPoints.Length; i++)
			stepPoints[i] = inputPoints[stepIndex + i*stepsCount];
		currentStepSize = stepPoints.Length;
		
		inputPointsBuffer = new ComputeBuffer(stepPoints.Length, 12); // 3floats x 4bytes
		outputValuesBuffer = new ComputeBuffer(stepPoints.Length, 4); // 4bytes
		baseSpectrumBuffer = new ComputeBuffer(baseSpectrum.Length, 4);
		
		inputPointsBuffer.SetData(stepPoints);
		baseSpectrumBuffer.SetData(baseSpectrum);
	}
	
	protected virtual void ReleaseBuffers()
	{
		inputPointsBuffer.Release();
		outputValuesBuffer.Release();
		baseSpectrumBuffer.Release();
	}
	
	protected virtual void Dispatch()
	{
		gpuProgram.SetBuffer(method, "points", inputPointsBuffer);
		gpuProgram.SetBuffer(method, "values", outputValuesBuffer);
		gpuProgram.SetBuffer(method, "baseSpectrum", baseSpectrumBuffer);
		gpuProgram.SetInt("baseOctaves", baseSpectrum.Length);
		gpuProgram.SetFloat("gamma", Gamma);
		gpuProgram.SetInt("iterations", Iterations);

		gpuProgram.Dispatch(method, currentStepSize/THREADGROUPSIZE, 1, 1);
		
		float[] stepValues = new float[currentStepSize];
		outputValuesBuffer.GetData(stepValues);
		for (int i = 0; i < currentStepSize; i++)
			outputValues[stepIndex + i*stepsCount] = stepValues[i];
	}
	
	public virtual void Reset()
	{
		stepIndex = -1;
		inputPoints = new Vector3[0] {};
		outputValues = new float[0] {};
	}
	
	protected int method = 0;
	protected ComputeShader gpuProgram;
	protected int THREADGROUPSIZE = 64; // must be the same as THREADGROUPSIZE in fbmgpu_base.cginc
	
	protected int stepIndex = -1;
	protected int stepsCount = 1;
	protected int currentStepSize;
	
	protected Vector3[] inputPoints;
	protected float[] outputValues;
	protected float[] baseSpectrum;
	
	protected ComputeBuffer inputPointsBuffer;
	protected ComputeBuffer outputValuesBuffer;
	protected ComputeBuffer baseSpectrumBuffer;
}

