using UnityEngine;
using System.Collections.Generic;
using System.Threading;
using System;

public class FBMGPU
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

	public void Start(Vector3[] points, int steps = 1)
	{
		inputPoints = points;
		outputValues = new float[inputPoints.Length];
		
		stepsCount = steps;
		if (stepsCount < 0) stepsCount = 1;
		if (stepsCount > inputPoints.Length) stepsCount = inputPoints.Length;
		stepIndex = 0;
	}
	
	public bool Done { get { return (stepIndex >= stepsCount); } }
	public int StepIndex { get { return stepIndex; } }
	public int StepsCount { get { return stepsCount; } }
	
	public bool Update()
	{
		if (!Done)
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
		Vector3[] stepPoints = new Vector3[ (inputPoints.Length - stepIndex) / stepsCount ];
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
		//Debug.Log("baseOctaves = " + baseSpectrum.Length);
		//for (int i = 0; i < baseSpectrum.Length; i++)
		//	Debug.Log("   spec["+ i + "] = " + baseSpectrum[i]);

		gpuProgram.Dispatch(method, currentStepSize/THREADGROUPSIZE, 1, 1);
		
		float[] stepValues = new float[currentStepSize];
		outputValuesBuffer.GetData(stepValues);
		for (int i = 0; i < currentStepSize; i++)
			outputValues[stepIndex + i*stepsCount] = stepValues[i];
	}
	
	protected int method = 0;
	protected ComputeShader gpuProgram;
	protected int THREADGROUPSIZE = 64; // must be the same as THREADGROUPSIZE in fbmgpu_base.cginc
	
	protected int stepIndex = 0;
	protected int stepsCount;
	protected int currentStepSize;
	
	protected Vector3[] inputPoints;
	protected float[] outputValues;
	protected float[] baseSpectrum;
	
	protected static int SPECTRUM_MAX_LENGTH = 16; // must be the same as SPECTRUM_MAX_LENGTH in fbmgpu_base.cginc

	protected ComputeBuffer inputPointsBuffer;
	protected ComputeBuffer outputValuesBuffer;
	protected ComputeBuffer baseSpectrumBuffer;
}

