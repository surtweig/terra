using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System;

public class GPUSignalProcessor
{
	public GPUSignalProcessor(ComputeShader program, string methodName, int in_stride, int out_stride)
	{
		gpuProgram = program;
		methodIndex = gpuProgram.FindKernel("k_"+methodName);
		inputSignal = new float[] {};
		outputSignal = new float[] {};
		inputStride = in_stride;
		outputStride = out_stride;
	}
	
	protected ComputeShader gpuProgram;
	protected int methodIndex;
	
	protected float[] inputSignal;
	protected int inputStride = 1;
	protected float[] outputSignal;
	protected int outputStride = 1;

	protected int chunkWidth = 1;
	protected int inputSamplesCount = 0;
	protected int filterOverlapPosX = 0;
	protected int filterOverlapNegX = 0;
	
	protected int currentChunkIndex = -1;
	protected int chunksCount = 0;
	
	protected ComputeBuffer inputBuffer;
	protected ComputeBuffer outputBuffer;

	public virtual void SetInput(float[] signal, int chunkWidth)
	{
		Debug.Log("SetInput: " + signal.Length);
		if (currentChunkIndex < 0)
		{
			this.chunkWidth = chunkWidth;
			Utils.Assert(signal.Length % inputStride == 0, "GPUSignalProcessor.setInput : signal.Length must be n*stride");
			inputSignal = signal;
			inputSamplesCount = inputSignal.Length / inputStride;
			chunksCount = Mathf.CeilToInt( (float)inputSamplesCount/(float)ChunkEffectiveSize );
			outputSignal = new float[ OutputSize*outputStride ];
		}
	}
	
	public virtual float[] GetOutput()
	{
		return outputSignal;
	}
	
	// Default one-dimensional chunk sampler
	protected virtual float[] InputChunkExtract(int chunkIndex)
	{
		int firstPos = chunkIndex*chunkWidth - filterOverlapNegX;
		int lastPos = (chunkIndex+1)*chunkWidth + filterOverlapPosX - 1;
		
		float[] chunk = new float[lastPos - firstPos + 1];
		Array.Clear(chunk, 0, chunk.Length);
		
		return chunk;
	}
	
	protected virtual void OutputChunkMerge(int chunkIndex, float[] chunk)
	{
		
	}
	
	// Number of samples in chunk
	protected virtual int ChunkSize { get { return chunkWidth + filterOverlapNegX + filterOverlapPosX; } }
	
	// Number of samples in chunk, excluding overlap
	protected virtual int ChunkEffectiveSize { get { return chunkWidth; } }
	
	protected virtual int OutputSize { get { return inputSamplesCount - filterOverlapNegX - filterOverlapPosX; } }
	
	protected virtual int THREADGROUPSIZE { get { return 16; } }
	
	protected virtual int ThreadsX { get { return ChunkEffectiveSize/THREADGROUPSIZE; } }
	protected virtual int ThreadsY { get { return 1; } }
	protected virtual int ThreadsZ { get { return 1; } }
	
	public bool Done { get { return currentChunkIndex >= chunksCount; } }
	public bool IsStarted { get { return currentChunkIndex >= 0; } }
	
	// It's better to chunkWidth to be divisible by THREADGROUPSIZE
	public bool Start()
	{
		if (!IsStarted)
		{
			currentChunkIndex = 0;
			return true;
		}
		return false;
	}
	
	public bool Update()
	{
		if (IsStarted && !Done)
		{
			PrepareBuffers();
			Dispatch();
			ReleaseBuffers();
			currentChunkIndex++;
			//Debug.Log("GPUSignalProcessor.Update: currentChunkIndex = " + currentChunkIndex + "/" + chunksCount);
		}
		return Done;
	}
	
	public void Reset()
	{
		currentChunkIndex = -1;
		inputSignal = new float[] {};
		outputSignal = new float[] {};
		chunksCount = 0;
	}
	
	protected virtual void PrepareBuffers()
	{
		inputBuffer = new ComputeBuffer(ChunkSize*inputStride, 4); // 32bit float
		outputBuffer = new ComputeBuffer(ChunkEffectiveSize*outputStride, 4);
		
		float[] chunk = InputChunkExtract(currentChunkIndex);
		inputBuffer.SetData(chunk);
	}
	
	protected virtual void ReleaseBuffers()
	{
		inputBuffer.Release();
		outputBuffer.Release();
	}
	
	protected virtual void Dispatch()
	{
		gpuProgram.SetBuffer(methodIndex, "InputSignal", inputBuffer);
		gpuProgram.SetBuffer(methodIndex, "OutputSignal", outputBuffer);
		gpuProgram.SetInt("InputSampleSize", inputStride);
		gpuProgram.SetInt("OutputSampleSize", outputStride);

		gpuProgram.Dispatch(methodIndex, ThreadsX, ThreadsY, ThreadsZ);
		
		float[] chunkOut = new float[ChunkEffectiveSize*outputStride];
		outputBuffer.GetData(chunkOut);
		OutputChunkMerge(currentChunkIndex, chunkOut);
	}
}


public class GPUTextureProcessor : GPUSignalProcessor
{
	protected int overlapSize;
	protected int texSize;
	
	public GPUTextureProcessor(ComputeShader program, string methodName, int overlapSize, int in_stride, int out_stride) : base(program, methodName, in_stride, out_stride)
	{
		this.overlapSize = overlapSize;
	}
	
	public override void SetInput(float[] signal, int chunkWidth)
	{
		base.SetInput(signal, chunkWidth);
		texSize = (int)(Mathf.Sqrt(inputSamplesCount)) - 2*overlapSize;
		outputSignal = new float[ OutputSize*outputStride ];
	}
	
	protected override int ChunkSize { get { return (chunkWidth + 2*overlapSize)*(chunkWidth + 2*overlapSize); } }
	protected override int ChunkEffectiveSize { get { return chunkWidth*chunkWidth; } }
	protected override int OutputSize { get { return texSize*texSize; } }
	
	protected override int THREADGROUPSIZE { get { return 16; } }
	
	protected override int ThreadsX { get { return chunkWidth/THREADGROUPSIZE; } }
	protected override int ThreadsY { get { return chunkWidth/THREADGROUPSIZE; } }
	
	protected override float[] InputChunkExtract(int chunkIndex)
	{
		int inputTexWidth = texSize + 2*overlapSize;
		int chunksInWidth = Mathf.CeilToInt( (float)texSize/(float)chunkWidth );
		
		int chunkIndexX = chunkIndex % chunksInWidth;
		int chunkIndexY = chunkIndex / chunksInWidth;
		
		int chunkPosX = chunkIndexX * chunkWidth + overlapSize;
		int chunkPosY = chunkIndexY * chunkWidth + overlapSize;
		
		float[] chunk = new float[ ChunkSize * inputStride ];
		
		for (int x = -overlapSize; x < chunkWidth + overlapSize; x++)
		{
			for (int y = -overlapSize; y < chunkWidth + overlapSize; y++)
			{
				int px = chunkPosX + x;
				int py = chunkPosY + y; 
				int inputpos = py*inputTexWidth + px;
				int chunkpos = (y+overlapSize)*(chunkWidth+2*overlapSize) + (x+overlapSize);
					
				if (px >= 0 && px < inputTexWidth && py >= 0 && py < inputTexWidth)
					for (int s = 0; s < inputStride; s++)
					{
						int ci = chunkpos*inputStride + s;
						int ii = inputpos*inputStride + s;
						if (ci >= chunk.Length || ii >= inputSignal.Length || ci < 0 || ii < 0)
						{
							Debug.Log("out of range: ci = " + ci + "/" + chunk.Length + " ii = " + ii + "/" + inputSignal.Length);
						}
						chunk[ci] = inputSignal[ii];
					}
				else
					for (int s = 0; s < inputStride; s++)
						chunk[chunkpos*inputStride+s] = 0f;
			}
		}
		return chunk;
	}
	
	protected override void OutputChunkMerge(int chunkIndex, float[] chunk)
	{
		int chunksInWidth = Mathf.CeilToInt( (float)texSize/(float)chunkWidth );
		
		int chunkIndexX = chunkIndex % chunksInWidth;
		int chunkIndexY = chunkIndex / chunksInWidth;
		
		int chunkPosX = chunkIndexX * chunkWidth;
		int chunkPosY = chunkIndexY * chunkWidth;
		
		for (int i = 0; i < chunk.Length; i++)
		{
			int s = i % outputStride;
			int x = (i/outputStride) % chunkWidth;
			int y = (i/outputStride) / chunkWidth;
			int outputx = chunkPosX + x;
			int outputy = chunkPosY + y;
			float c = 0f;
			if (outputx % 32 == 0 || outputy % 32 == 0)
				c = 1f;
			int outputpos = (outputy*texSize + outputx)*outputStride + s;
			if (outputpos >= 0 && outputpos < outputSignal.Length)
				outputSignal[outputpos] = chunk[i];
		}
	}
	
	protected override void Dispatch()
	{
		gpuProgram.SetInt("TexSize", texSize);
		gpuProgram.SetInt("ChunkWidth", chunkWidth);
		base.Dispatch();
	}
}