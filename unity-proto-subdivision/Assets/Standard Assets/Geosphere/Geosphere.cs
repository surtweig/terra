using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.Threading;

// Bailout
// NoiseScale = 0.005
// NoiseSpaceScale = 3 
// NoiseOctaves = 10
// NoisePersistence = 1.1
// NoiseIterations = 4

public class GeoNode
{
	public Vector3 position;
	public Vector3 normal;
	public float elevation;
	public List<int[]> adjacency;
	public bool transformed = false;
	
	public GeoNode()
	{
		adjacency = new List<int[]>();
	}
}


public class GeoTriTreeNode
{
	public int[] vertices;
	public int[] children;
	public byte level;
}


public class MutableGeoMesh
{
	public List<int> indexes;
	public List<int> triangles;
	
	public MutableGeoMesh()
	{
		indexes = new List<int>();
		triangles = new List<int>();
	}
	
	public void AddVertex(int nodeIndex)
	{
		if (indexes.Count == 0)
			indexes.Add(nodeIndex);
		else
		{
			int subIndex = indexes.BinarySearch(nodeIndex);
			if (subIndex < 0)
			{
				subIndex = ~subIndex;
				indexes.Insert(subIndex, nodeIndex);
			}
			
		}
		triangles.Add(nodeIndex);
	}
	
	public void IndexTriangles()
	{
		for (int i = 0; i < triangles.Count; i++)
			triangles[i] = indexes.BinarySearch(triangles[i]);
	}
}


public class MeshContainer
{
	public Vector3[] vertices;
	public Vector3[] normals;
	public Vector2[] uv;
	public int[] triangles;
	
	public Mesh MakeMesh()
	{
		Mesh mesh = new Mesh();
		mesh.vertices = vertices;
		mesh.normals = normals;
		mesh.triangles = triangles;
		mesh.uv = uv;
		return mesh;
	}
}


public class DummyNoiseGenerator : ISpatialNoiseGenerator
{
	private int pointsNumber = -1;
	
	public void Start(Vector3[] points, int steps)
	{
		pointsNumber = points.Length;
	}
	
	public bool Update()
	{
		return Done;
	}
	
	public float[] Output()
	{
		Debug.Log("pointsNumber = " + pointsNumber);
		float[] output = new float[pointsNumber];
		for (int i = 0; i < output.Length; i++)
			output[i] = 0f;
		return output;
	}
	
	public bool Done { get { return (pointsNumber >= 0); } }
	public bool Started { get { return (pointsNumber >= 0); } }
	
	public void Reset()
	{
		pointsNumber = -1;
	}
}


public struct UVPlaneData
{
	public Vector3 normal;
	
	public Vector3 projA;
	public Vector3 projB;
	public Vector3 projC1;
	public Vector3 projC2;
	
	public Vector3 posA;
	public Vector3 posB;
	public Vector3 posC1;
	public Vector3 posC2;
	
	public Vector3 axisC1A;
	public Vector3 axisC2A;
	
	public float distC1A;
	public float distC2A;
}


public class GeoSurface
{
	protected List<GeoNode> nodes;
	protected List<GeoTriTreeNode> tritree; 
	protected int triTreeRootSize = 0; // number of first basic TriTree nodes
	protected List<MeshContainer> meshContainers;
	protected List<MeshContainer> atmMeshContainers;
	protected List<Color[]> textures;
	protected List<Color[]> normalMaps;
	protected List<Texture2D> exportedTextures;
	protected List<Texture2D> exportedNormalMaps;
	
	protected int[][] trianglePairs;
	protected int[] triangleToPairsMap;
	protected List<UVPlaneData> uvPlanesData;
	
	public ISpatialNoiseGenerator Noise;
	public ISpatialNoiseGenerator[] TexNoises;
	public int TargetSubdivisionLevel = 0;
	public int NoiseGenFrames = 32;
	public float NoiseScale = 1f;
	public float NoiseSpaceScale = 1f;
	public int TextureSize = 1024;
	public int TexNoiseGenFrames = 64;
	public float TexNoiseSpaceScale = 1f;
	public int NormalGenChunkSize = 128;//64;
	public float AtmosphereRadiusRatio = 1.1f;
	public bool BuildAtmosphere = true;
	
	public int TexFilterOverlap = 1;
	public GPUTextureProcessor<Vector3, Vector3> NormalMapGenerator;
	
	private Thread subdivideThread;
	private Thread applyNoiseThread;
	private Thread buildMeshThread;
	private Thread texLoadGeneratorThread;
	private Thread texColorizeThread;
	private Thread normalMapColorizeThread;

	private volatile bool subdivided = false;
	private volatile bool noiseApplied = false;
	private volatile bool meshBuilt = false;
	private volatile int texGeneratorLoaded = -1;
	private volatile int texGeneratorDone = -1;
	private volatile int texColorized = -1;
	private volatile bool texturesGenerated = false;
	private volatile int normalMapsGenerated = -1;
	private volatile int normalMapsColorized = -1;
	private volatile bool allNormalMapsDone = false;
	
	private bool threadsShouldStop = false;
	
	private List<Vector3> noiseInput;
	private float[] noiseOutput;
	
	private Vector3[] texNoiseInput;
	private List<Vector3[]> texNoiseInputCache;
	private float[][] texNoiseOutput;
	private List<Vector3[]> heightMapsCache;
	private Vector3[] normalMapGeneratorOutput;
	
	private Utils.StopWatch buildingStopWatch = null;
	
	public GeoSurface()
	{
		nodes = new List<GeoNode>();
		tritree = new List<GeoTriTreeNode>();
		meshContainers = new List<MeshContainer>();
		atmMeshContainers = new List<MeshContainer>();
		Noise = new DummyNoiseGenerator();
		TexNoises = new ISpatialNoiseGenerator[1] { new DummyNoiseGenerator() };
		subdivideThread = new Thread(this.SubdivideThreadProc);
		applyNoiseThread = new Thread(this.ApplyNoiseThreadProc);
		buildMeshThread = new Thread(this.BuildMeshThreadProc);
		texLoadGeneratorThread = new Thread(this.TexLoadGeneratorThreadProc);
		texColorizeThread = new Thread(this.TexColorizeThreadProc);
		textures = new List<Color[]>();
		heightMapsCache = new List<Vector3[]>();
		texNoiseInputCache = new List<Vector3[]>();
		//hmtestcache = new List<Vector3>();
		NormalMapGenerator = null;
		normalMaps = new List<Color[]>();
		normalMapColorizeThread = new Thread(this.NormalMapsColorizeThreadProc);
		
		exportedTextures = new List<Texture2D>();
		exportedNormalMaps = new List<Texture2D>();
		
		uvPlanesData = new List<UVPlaneData>();
	}
	
	~GeoSurface()
	{
		StopThreads();
	}
	
	public void StopThreads()
	{
		/*if (subdivideThread.IsAlive)
			subdivideThread.Interrupt();
		if (applyNoiseThread.IsAlive)
			applyNoiseThread.Interrupt();
		if (buildMeshThread.IsAlive)
			buildMeshThread.Interrupt();
		if (generateUVThread.IsAlive)
			generateUVThread.Interrupt();*/
		threadsShouldStop = true;
	}
	
	public bool StartBuilding()
	{
		Debug.Log("GeoSurface.StartBulding");
		buildingStopWatch = new Utils.StopWatch("Geosphere.Build");
		
		cacheUVPlanesData();
			
		if (IsInProgress)
			return false;
		
		subdivideThread.Start();
		
		return true;
	}
	
	public int MeshesCount { get { return meshContainers.Count; } }
	
	public Mesh GetMesh(int meshIndex)
	{
		if (meshIndex < 0 || meshIndex >= meshContainers.Count)
			return null;
		return meshContainers[meshIndex].MakeMesh();
	}

	public Mesh GetAtmoMesh(int meshIndex)
	{
		if (meshIndex < 0 || meshIndex >= atmMeshContainers.Count)
			return null;
		return atmMeshContainers[meshIndex].MakeMesh();
	}
	
	public Texture2D GetTexture(int meshIndex)
	{
		if (meshIndex < 0 || meshIndex >= meshContainers.Count)
			return null;
		
		if (exportedTextures.Count == 0)
			for (int tex = 0; tex < trianglePairs.Length; tex++)
				exportedTextures.Add(null);

		int texIndex = triangleToPairsMap[meshIndex];
		if (exportedTextures[texIndex] == null)
		{
			Texture2D tex = new Texture2D(TextureSize, TextureSize, TextureFormat.RGB24, true, true);
			tex.SetPixels(textures[texIndex]);
			tex.wrapMode = TextureWrapMode.Clamp;
			exportedTextures[texIndex] = tex;
		}
		return exportedTextures[texIndex];
	}
	
	public Texture2D GetNormalMap(int meshIndex)
	{
		if (meshIndex < 0 || meshIndex >= meshContainers.Count)
			return null;
		
		if (exportedNormalMaps.Count == 0)
			for (int tex = 0; tex < trianglePairs.Length; tex++)
				exportedNormalMaps.Add(null);

		int texIndex = triangleToPairsMap[meshIndex];
		if (exportedNormalMaps[texIndex] == null)
		{
			Texture2D tex = new Texture2D(TextureSize, TextureSize, TextureFormat.RGB24, true, true);
			tex.SetPixels(normalMaps[texIndex]);
			tex.wrapMode = TextureWrapMode.Clamp;
			exportedNormalMaps[texIndex] = tex;
		}
		return exportedNormalMaps[texIndex];
	}
	
	public int debug_surfacegpuloaded
		{ get { return Noise.Started && !Noise.Done ? 1 : 0; } }
	
	public int debug_colorgpuloaded
		{ get { return TexNoises[0].Started ? 1 : 0; } }
	
	public int debug_normalgpuloaded
		{ get { return NormalMapGenerator.IsStarted ? 1 : 0; } }
	
	public virtual bool IsInProgress
		{ get { return subdivideThread.IsAlive || applyNoiseThread.IsAlive || texColorizeThread.IsAlive || texLoadGeneratorThread.IsAlive || normalMapColorizeThread.IsAlive || (Noise.Started && !Noise.Done); } }
	
	public virtual bool Done { get { return !IsInProgress && subdivided && noiseApplied && meshBuilt && texturesGenerated && allNormalMapsDone; } }
	
	public virtual float TexturesProgress { get { return (float)texColorized/(float)(trianglePairs.Length); } }

	public int GetTopologySize()
	{
		int cnt = 0;
		for (int i = 0; i < nodes.Count; i++)
		{
			//public Vector3 position;
			//public Vector3 normal;
			//public float elevation;
			//public List<int[]> adjacency;
			//public bool transformed = false;
			cnt += 4 * (3 + 3 + 1) + 1;
			for (int j = 0; j < nodes[i].adjacency.Count; j++)
				cnt += nodes[i].adjacency[j].Length * 4;
		}
		for (int i = 0; i < tritree.Count; i++)
		{
			cnt += 1;
			cnt += tritree[i].vertices.Length * 4;
			cnt += tritree[i].children.Length * 4;
		}

		//public Vector3[] vertices;
		//public Vector3[] normals;
		//public Vector2[] uv;
		//public int[] triangles;		
		for (int i = 0; i < meshContainers.Count; i++)
		{
			cnt += meshContainers[i].triangles.Length * 4;
			cnt += meshContainers[i].vertices.Length * 3 * 4;
			cnt += meshContainers[i].normals.Length * 3 * 4;
			cnt += meshContainers[i].uv.Length * 2 * 4;
		}

		return cnt;
	}

	public virtual Vector3 NormalizePoint(Vector3 point)
	{
		return point;
	}
	
	public virtual Vector3 ElevatePoint(Vector3 point, float elevation)
	{
		return point;
	}
	
	protected virtual void SubdivideThreadProc()
	{
		subdivided = false;
		//Debug.Log("GeoSurface.Subdivide thread start");
		Utils.StopWatch subdivideStopWatch = new Utils.StopWatch("SubdivideThreadProc");
		
		// Subdividing
		for (int triTreeNode = 0; triTreeNode < triTreeRootSize; triTreeNode++)
		{
			Subdivide(triTreeNode, TargetSubdivisionLevel);
			
			if (threadsShouldStop)
			{
				Debug.Log("GeoSurface.Subdivide thread abort !!!");
				return;
			}
		}

		if (BuildAtmosphere)
			BuildAtmosphereProc();
		
		// Collecting points
		noiseInput = new List<Vector3>();
		foreach (GeoNode node in nodes)
		{
			if (!node.transformed)
				noiseInput.Add(node.position * NoiseSpaceScale);
			
			if (threadsShouldStop)
			{
				Debug.Log("GeoSurface.Subdivide thread abort !!!");
				return;
			}
		}
		
		//Debug.Log("GeoSurface.Subdivide thread finish <<");
		subdivideStopWatch.Stop();
		subdivided = true;
	}

	protected virtual void ApplyNoiseThreadProc()
	{
		noiseApplied = false;
		//Debug.Log("GeoSurface.ApplyNoise thread start");
		Utils.StopWatch applyNoiseStopWatch = new Utils.StopWatch("ApplyNoiseThreadProc");

		// Applying generated noise
		for (int i = 0; i < nodes.Count; i++)
		{
			if ( !nodes[i].transformed )
			{
				nodes[i].elevation = noiseOutput[i]*NoiseScale;
				nodes[i].position = ElevatePoint(nodes[i].position, nodes[i].elevation);
				nodes[i].transformed = true;
			}
			
			if (threadsShouldStop)
			{
				Debug.Log("GeoSurface.ApplyNoise thread abort !!!");
				return;
			}
		}
		
		noiseInput.Clear();
		noiseOutput = new float[0] {};
		
		//Debug.Log("GeoSurface.ApplyNoise thread finish <<");
		applyNoiseStopWatch.Stop();
		noiseApplied = true;
	}

	protected virtual void BuildAtmosphereProc()
	{
		BuildNormals();
		atmMeshContainers.Clear();
		for (int triTreeNode = 0; triTreeNode < triTreeRootSize; triTreeNode++)
		{
			atmMeshContainers.Add(BuildTriTreeNodeMesh(triTreeNode, AtmosphereRadiusRatio));

			if (threadsShouldStop)
			{
				Debug.Log("GeoSurface.BuildAtmosphereProc thread abort !!!");
				return;
			}
		}
	}

	protected virtual void BuildMeshThreadProc()
	{
		meshBuilt = false;
		//Debug.Log("GeoSurface.BuildMesh thread start");
		Utils.StopWatch buildMeshStopWatch = new Utils.StopWatch("BuildMeshThreadProc");
		
		// Calculating normals
		BuildNormals();
		
		// Building mesh containers
		meshContainers.Clear();
		for (int triTreeNode = 0; triTreeNode < triTreeRootSize; triTreeNode++)
		{
			meshContainers.Add(BuildTriTreeNodeMesh(triTreeNode));

			if (threadsShouldStop)
			{
				Debug.Log("GeoSurface.BuildMesh thread abort !!!");
				return;
			}
		}
		
		//Debug.Log("GeoSurface.BuildMesh thread finish <<");
		buildMeshStopWatch.Stop();
		meshBuilt = true;
	}
	
	protected virtual void TexLoadGeneratorThreadProc()
	{
		//Debug.Log("GeoSurface.TexLoadGenerator thread start");
		Utils.StopWatch texLoadGeneratorStopWatch = new Utils.StopWatch("TexLoadGeneratorThreadProc");
		
		if (TexNoises.Length > 0)
		{
			int widthWithOverlap = TextureSize + 2*TexFilterOverlap;
			int sizeWithOverlap = widthWithOverlap*widthWithOverlap;
			
			texNoiseInput = new Vector3[sizeWithOverlap];
			/*int[] tripair =  trianglePairs[texGeneratorLoaded+1];
			int tri_iA;
			int tri_iB;
			int tri_iC1;
			int tri_iC2;
			GetQuadVertices(tripair[0], tripair[1], out tri_iA, out tri_iB, out tri_iC1, out tri_iC2);*/
	
			int subthreadsFinished = 0;
			int subthreadsCount = 8;
			Thread[] subthreads = new Thread[subthreadsCount];
			
			for (int ti = 0; ti < subthreads.Length; ti++)
			{
				subthreads[ti] = new Thread(
					delegate(object subthreadIndex)
					{
						for (int i = 0; i < sizeWithOverlap/subthreadsCount; i++)
						{
							if (threadsShouldStop)
								break;
							int pos = i*subthreadsCount + (int)subthreadIndex;
							int x = pos % widthWithOverlap;
							int y = pos / widthWithOverlap;
							texNoiseInput[pos] = //new Vector3(0f, 0f, 0f);
								TexNoiseSpaceScale * GetVertexPositionFromUV(new Vector2((float)(x-TexFilterOverlap)/(float)TextureSize, (float)(y-TexFilterOverlap)/(float)TextureSize), texGeneratorLoaded+1);
						}
						subthreadsFinished++;
					}
				);
				subthreads[ti].Start( ti );
			}
			
			while (subthreadsFinished < subthreadsCount)
			{
				if (threadsShouldStop)
				{
					Debug.Log("GeoSurface.TexLoadGenerator thread abort !!!");
					return;
				}
			}

			texNoiseInputCache.Add(texNoiseInput);
			texGeneratorLoaded++;
		}
		//Debug.Log("GeoSurface.TexLoadGenerator thread finish <<");
		texLoadGeneratorStopWatch.Stop();
	}
	
	protected virtual void TexColorizeThreadProc()
	{
		//Debug.Log("GeoSurface.TexColorize thread start");
		Utils.StopWatch texColorizeStopWatch = new Utils.StopWatch("TexColorizeThreadProc");
		
		if (TexNoises.Length > 0)
		{
			Color[] tex = new Color[TextureSize*TextureSize];
			
			int widthWithOverlap = TextureSize + 2*TexFilterOverlap;
			int sizeWithOverlap = widthWithOverlap*widthWithOverlap;
			Vector3[] heightMap = new Vector3[sizeWithOverlap];
			float[] hmtest = new float[TextureSize*TextureSize];
			
			/*for (int i = 0; i < sizeWithOverlap; i++)
			{
				float h;
				float[] values = new float[texNoiseOutput.Length];
				for (int j = 0; j < texNoiseOutput.Length; j++)
					values[j] = texNoiseOutput[j][i];
				
				if (i < tex.Length)
					tex[i] = new Color(1f, 0f, 1f);
				
				int x = i % widthWithOverlap;
				int y = i / widthWithOverlap;
				
				if (x >= TexFilterOverlap && x < TextureSize+TexFilterOverlap &&
					y >= TexFilterOverlap && y < TextureSize+TexFilterOverlap)
				{
					tex[ (x-TexFilterOverlap) + (y-TexFilterOverlap)*TextureSize ] = Colorize(values);
					//hmtest[ (x-TexFilterOverlap) + (y-TexFilterOverlap)*TextureSize ] = HeightMap(values);
					h = HeightMap(values);
				}
				else
					h = 0f;
				
				h = HeightMap(values);
				heightMap[i] = texNoiseInputCache[texColorized+1][i].normalized * (1f + h*NoiseScale);
				
				if (threadsShouldStop)
				{
					Debug.Log("GeoSurface.TexColorize thread abort !!!");
					return;
				}
			}*/
			
			int subthreadsFinished = 0;
			int subthreadsCount = 8;
			Thread[] subthreads = new Thread[subthreadsCount];
			
			for (int ti = 0; ti < subthreads.Length; ti++)
			{
				subthreads[ti] = new Thread(
					delegate(object subthreadIndex)
					{
						for (int i = 0; i < sizeWithOverlap/subthreadsCount; i++)
						{
							if (threadsShouldStop)
								break;
							int pos = i*subthreadsCount + (int)subthreadIndex;
						
							float h;
							float[] values = new float[texNoiseOutput.Length];
							for (int j = 0; j < texNoiseOutput.Length; j++)
								values[j] = texNoiseOutput[j][pos];
							
							//if (pos < tex.Length)
							//	tex[pos] = new Color(1f, 0f, 1f);
							
							int x = pos % widthWithOverlap;
							int y = pos / widthWithOverlap;
							
							if (x >= TexFilterOverlap && x < TextureSize+TexFilterOverlap &&
								y >= TexFilterOverlap && y < TextureSize+TexFilterOverlap)
							{
								tex[ (x-TexFilterOverlap) + (y-TexFilterOverlap)*TextureSize ] = Colorize(values);
								//hmtest[ (x-TexFilterOverlap) + (y-TexFilterOverlap)*TextureSize ] = HeightMap(values);
								h = HeightMap(values);
							}
							else
								h = 0f;
							
							h = HeightMap(values);
							heightMap[pos] = texNoiseInputCache[texColorized+1][pos].normalized * (1f + h*NoiseScale);
						}
						subthreadsFinished++;
					}
				);
				subthreads[ti].Start( ti );
			}
			
			while (subthreadsFinished < subthreadsCount)
			{
				if (threadsShouldStop)
				{
					Debug.Log("GeoSurface.TexColorize thread abort !!!");
					return;
				}
			}
			
			heightMapsCache.Add(heightMap);
			//hmtestcache.Add(hmtest);
			textures.Add(tex);
			texColorized++;
			//Debug.Log("texColorized = " + texColorized);
			
		}
		//Debug.Log("GeoSurface.TexColorize thread finish <<");
		texColorizeStopWatch.Stop();
	}
	
	protected virtual void NormalMapsColorizeThreadProc()
	{
		//Debug.Log("GeoSurface.NormalMapsColorize thread start normalMapGeneratorOutput: " + normalMapGeneratorOutput.Length + " nmap: " + (TextureSize*TextureSize) );
		Utils.StopWatch normalMapsColorizeStopWatch = new Utils.StopWatch("NormalMapsColorizeThreadProc");
		
		Color[] nmap = new Color[TextureSize*TextureSize];
		for (int i = 0; i < nmap.Length; i++)
		{
			//Vector3 n = new Vector3(normalMapGeneratorOutput[i], normalMapGeneratorOutput[i*3+1], normalMapGeneratorOutput[i*3+2]);
			nmap[i] = ColorizeNormal(normalMapGeneratorOutput[i]);
			//float c = hmtest[i];
			//nmap[i] = Colorize(new float[1] { c });
			//nmap[i] *= 0.5f;
			if (threadsShouldStop)
			{
				Debug.Log("GeoSurface.NormalMapsColorize thread abort !!!");
				return;
			}
		}
		normalMaps.Add(nmap);
		normalMapsColorized++;
		//Debug.Log("GeoSurface.NormalMapsColorize thread finish << normalMapsColorized = " + normalMapsColorized);
		normalMapsColorizeStopWatch.Stop();
	}
	
	protected virtual Color Colorize(float[] noiseValues)
	{
		float c = Mathf.Clamp( (noiseValues[0]+1f)*0.5f, 0f, 1f);
		return new Color(c, c, c);
	}
	
	protected virtual float HeightMap(float[] noiseValues)
	{
		return noiseValues[0];
	}
	
	protected virtual Color ColorizeNormal(Vector3 normal)
	{
		return new Color(normal.x*0.5f + 0.5f, normal.y*0.5f + 0.5f, normal.z*0.5f + 0.5f);
	}

	public virtual bool Update()
	{
		if (subdivided)
		{
			// start surface noise
			if (!Noise.Started)
			{
				Noise.Start(noiseInput.ToArray(), NoiseGenFrames);
				Debug.Log("noiseInput.count = " + noiseInput.Count);
			}
			
			// proceed surface noise
			if ( Noise.Update() && !applyNoiseThread.IsAlive && !noiseApplied )
			{
				// start applying noise to the geometry
				noiseOutput = Noise.Output();
				applyNoiseThread.Start();
			}
			
			// Textures generating //
			if (TexNoises.Length > 0 && texColorized < (trianglePairs.Length-1) )
			{
				// create input points for FBMGPU generators
				if ( texGeneratorLoaded <= texColorized && texGeneratorLoaded < (trianglePairs.Length-1) && !texLoadGeneratorThread.IsAlive )
				{
					texLoadGeneratorThread = new Thread(this.TexLoadGeneratorThreadProc);
					texLoadGeneratorThread.Start();
				}
				
				// start FBMGPUs if loaded
				if ( texGeneratorLoaded > texColorized && texGeneratorLoaded > texGeneratorDone)
				{
					foreach (ISpatialNoiseGenerator texNoise in TexNoises)
						if (!texNoise.Started)
							texNoise.Start(texNoiseInput, TexNoiseGenFrames);
				}
			
				// update FBMGPUs
				bool allTexNoiseDone = true;
				foreach (ISpatialNoiseGenerator texNoise in TexNoises)
					if ( !texNoise.Update() )
						allTexNoiseDone = false;
				
				// take FBMGPUs output if they're done and previous texture has been colorized
				if (allTexNoiseDone && !texColorizeThread.IsAlive)
				{
					texNoiseOutput = new float[TexNoises.Length][];
					for (int i = 0; i < TexNoises.Length; i++)
					{
						texNoiseOutput[i] = TexNoises[i].Output();
						TexNoises[i].Reset();
					}
					
					texGeneratorDone++;
					texColorizeThread = new Thread(this.TexColorizeThreadProc);
					texColorizeThread.Start();
				}
			}
			
			if (texColorized == (trianglePairs.Length-1))
				texturesGenerated = true;
			
			// Normal maps generating //
			if (NormalMapGenerator != null && normalMapsColorized < texColorized)
			{
				// Start normal map generator
				if (normalMapsGenerated < texColorized && !NormalMapGenerator.IsStarted)
				{
					NormalMapGenerator.SetInput(heightMapsCache[normalMapsGenerated+1], NormalGenChunkSize);
					NormalMapGenerator.Start();
				}
				
				// Update normal map generator
				if ( NormalMapGenerator.Update() )
				{
					// Start colorizing normal map if NormalMapGenerator is done
					if (!normalMapColorizeThread.IsAlive)
					{
						normalMapsGenerated++;
						normalMapGeneratorOutput = NormalMapGenerator.GetOutput();
						//hmtest = hmtestcache[normalMapsGenerated];
						normalMapColorizeThread = new Thread(this.NormalMapsColorizeThreadProc);
						normalMapColorizeThread.Start();
						NormalMapGenerator.Reset();
					}
				}
			}
			
			if (normalMapsColorized == (trianglePairs.Length-1) || NormalMapGenerator == null)
				allNormalMapsDone = true;
		}
		
		if (noiseApplied)
		{
			if ( !buildMeshThread.IsAlive && !meshBuilt )
				buildMeshThread.Start();
		}
		
		if (buildingStopWatch != null && Done)
		{
			buildingStopWatch.Stop();
			buildingStopWatch = null;
		}
		
		return Done;
	}
	
	public MeshContainer BuildTriTreeNodeMesh(int triTreeNode, float scale = 1f)
	{
		MutableGeoMesh mutablemesh = new MutableGeoMesh();
		CollectVertexes(mutablemesh, triTreeNode);
		mutablemesh.IndexTriangles();
		
		List<Vector3> vertices = new List<Vector3>();
		List<Vector2> uv = new List<Vector2>();
		List<Vector3> normals = new List<Vector3>();
		
		int[] triTreeNodesPair = GetTriTreeNodePair(triTreeNode);
		
		foreach (int nodeIndex in mutablemesh.indexes)
		{
			vertices.Add(nodes[nodeIndex].position * scale);
			normals.Add(nodes[nodeIndex].normal);
			uv.Add(GetVertexUV(nodes[nodeIndex].position, triangleToPairsMap[triTreeNode]));
		}
		
		MeshContainer meshContainer = new MeshContainer();
		meshContainer.vertices = vertices.ToArray();
		meshContainer.normals = normals.ToArray();
		meshContainer.triangles = mutablemesh.triangles.ToArray();
		meshContainer.uv = uv.ToArray();
		
		return meshContainer;
	}
	
	protected void BuildNormals()
	{
		for (int i = 0; i < nodes.Count; i++)
		{
			float nx = 0f;
			float ny = 0f;
			float nz = 0f;
			
			int highlev = nodes[i].adjacency.Count-1;
			
			int icurrent = -1;
			Vector3 vcurrent = nodes[i].position;

			int inext = nodes[i].adjacency[highlev][0];
			Vector3 vnext = nodes[inext].position;
			
			int ifirst = inext;
			
			while (true)
			{
				nx += (vcurrent.y - vnext.y) * (vcurrent.z + vnext.z);
				ny += (vcurrent.z - vnext.z) * (vcurrent.x + vnext.x);
				nz += (vcurrent.x - vnext.x) * (vcurrent.y + vnext.y);
				
				// finding next node as common adjacent of center and current node, but not previous
				bool nextfound = false;
				for (int j = 0; j < nodes[i].adjacency[highlev].Length; j++)
				{
					for (int k = 0; k < nodes[inext].adjacency[highlev].Length; k++)
						if (nodes[i].adjacency[highlev][j] == nodes[inext].adjacency[highlev][k])
							if (nodes[i].adjacency[highlev][j] != icurrent)
							{
								icurrent = inext;
								inext = nodes[i].adjacency[highlev][j];
								nextfound = true;
								break;
							}
					
					if (nextfound)
						break;
				}
				
				vcurrent = vnext;
				vnext = nodes[inext].position;
				
				if (inext == ifirst)
					break;
			}
			
			vnext = nodes[i].position;
			nx += (vcurrent.y - vnext.y) * (vcurrent.z + vnext.z);
			ny += (vcurrent.z - vnext.z) * (vcurrent.x + vnext.x);
			nz += (vcurrent.x - vnext.x) * (vcurrent.y + vnext.y);
			
			Vector3 normal = new Vector3(nx, ny, nz).normalized;
			
			if (Vector3.Dot(normal, vnext.normalized) < 0)
				normal = -normal;
			
			nodes[i].normal = normal;
		}
	}
	
	protected virtual Vector2 GetVertexUV(Vector3 position, int tripairIndex)
	{
		return new Vector2(0f, 0f);
	}
	
	protected virtual Vector3 GetVertexPositionFromUV(Vector2 uv, int tripairIndex)
	{
		return new Vector3(0f, 0f, 0f);
	}
	
	// This function should return an ordered pair of TriTree nodes indexes, which share one texture
	protected virtual int[] GetTriTreeNodePair(int triTreeNode)
	{
		Utils.Assert(triTreeNode < triTreeRootSize, "GeoSurface.GetTriTreeNodePair: triangle pair can be generated for a root triangles only");
		return trianglePairs[triangleToPairsMap[triTreeNode]];
	}
	
	//    iC1_________iB
	//      /\        /
	//     /  \ triB /
	//    /    \    /
	//   / triA \  /
	//  /________\/
	// iA        iC2
	protected void GetQuadVertices(int triA, int triB, out int iA, out int iB, out int iC1, out int iC2)
	{
		List<int> C1C2 = new List<int>();
		
		iA = -1;
		iB = -1;
		
		bool comm;
		for (int i = 0; i < 3; i++)
		{
			comm = false;
			
			for (int j = 0; j < 3; j++)
			{
				if (tritree[triA].vertices[i] == tritree[triB].vertices[j])
				{
					comm = true;
					break;
				}
			}

			if (comm)
				C1C2.Add(tritree[triA].vertices[i]);
			else
				iA = tritree[triA].vertices[i];
		}
		
		for (int i = 0; i < 3; i++)
			if ( !C1C2.Contains(tritree[triB].vertices[i]) )
				iB = tritree[triB].vertices[i];
		
		if (C1C2.Count == 2)
		{
			iC1 = C1C2[0];
			iC2 = C1C2[1];
		}
		else
		{
			iC1 = -1;
			iC2 = -1;
		}
	}
	
	protected virtual UVPlaneData GetUVPlaneData(int triA, int triB)
	{
		UVPlaneData data = new UVPlaneData();
		
		int iA;
		int iB;
		int iC1;
		int iC2;
		GetQuadVertices(triA, triB, out iA, out iB, out iC1, out iC2);
		Utils.Assert(iA >= 0 && iB >= 0 && iC1 >= 0 && iC2 >= 0, "GeoSurface.GetUVPlaneData: triA ("+triA+") and triB ("+triB+") must have exactly one common side");
		
		Vector3 vA =  NormalizePoint(nodes[iA].position);
		Vector3 vB =  NormalizePoint(nodes[iB].position);
		Vector3 vC1 = NormalizePoint(nodes[iC1].position);
		Vector3 vC2 = NormalizePoint(nodes[iC2].position);
		
		Plane planeA = new Plane(vA, vC1, vC2);
		Plane planeB = new Plane(vB, vC2, vC1);

		Vector3 nA = planeA.normal;
		Vector3 nB = planeB.normal;
		
		if (Vector3.Dot(nA, vA) < 0f)
		{
			nA = -nA;
			nB = -nB;
		}
		
		Vector3 nAB = (nA+nB).normalized;
		
		Vector3 pA = Math3d.ProjectPointOnPlane(nAB, vA, vA, vA);
		Vector3 pB = Math3d.ProjectPointOnPlane(nAB, vA, vB, vB);
		Vector3 pC1 = Math3d.ProjectPointOnPlane(nAB, vA, vC1, vC1);
		Vector3 pC2 = Math3d.ProjectPointOnPlane(nAB, vA, vC2, vC2);
		
		data.normal = nAB;
		
		data.posA = vA;
		data.posB = vB;
		data.posC1 = vC1;
		data.posC2 = vC2;
		
		data.projA = pA;
		data.projB = pB;
		data.projC1 = pC1;
		data.projC2 = pC2;
		
		data.axisC1A = (pC1-pA).normalized;
		data.axisC2A = (pC2-pA).normalized;

		data.distC1A = (pC1-pA).magnitude;
		data.distC2A = (pC2-pA).magnitude;
		
		return data;
	}
	
	protected void cacheUVPlanesData()
	{
		uvPlanesData.Clear();
		foreach (int[] tripair in trianglePairs)
			uvPlanesData.Add( GetUVPlaneData(tripair[0], tripair[1]) );
	}
	
	protected int xAddNode(GeoNode node)
	{
		int i = nodes.Count;
		nodes.Add(node);
		return i;
	}
	
	protected int xAddTriTreeNode(int[] vertices, int parentNode = -1)
	{
		GeoTriTreeNode newNode = new GeoTriTreeNode();
		newNode.vertices = vertices;
		newNode.children = new int[4] { -1, -1, -1, -1 };
		
		bool addedToChildren = false;
		int newNodeIndex = tritree.Count;
		if (parentNode >= 0)
		{
			newNode.level = (byte)(tritree[parentNode].level + 1);
			for (int i = 0; i < 4; i++)
				if (tritree[parentNode].children[i] == -1)
				{
					tritree[parentNode].children[i] = newNodeIndex;
					addedToChildren = true;
					break;
				}
		}
		else
			newNode.level = 0;
		
		Utils.Assert( addedToChildren || parentNode < 0, "Geosphere.GeoSurface.xAddTriTreeNode : can't add new tritree node to parentNode " + parentNode + " - it has 4 children already");
		
		tritree.Add(newNode);
		return newNodeIndex;
	}
	
	protected void xAddNodeAdjacency(int nodeIndex, int level, int adjNodeIndex)
	{
		int maxLevel = nodes[nodeIndex].adjacency.Count-1;
		if (maxLevel < level)
			for (int i = maxLevel; i < level; i++)
				nodes[nodeIndex].adjacency.Add(new int[] {});
		
		int[] adj = new int[nodes[nodeIndex].adjacency[level].Length+1];
		nodes[nodeIndex].adjacency[level].CopyTo(adj, 0);
		adj[adj.Length-1] = adjNodeIndex;
		nodes[nodeIndex].adjacency[level] = adj;
	}
	
	protected void xConnectNodes(int node1, int node2, int level)
	{
		xAddNodeAdjacency(node1, level, node2);
		xAddNodeAdjacency(node2, level, node1);
	}
	
	protected int xFindNodesCommonAdjacency(int node1, int node2, int level)
	{
		if (nodes[node1].adjacency.Count <= level || nodes[node2].adjacency.Count <= level)
			return -1;
		foreach (int adj1 in nodes[node1].adjacency[level])
			foreach (int adj2 in nodes[node2].adjacency[level])
				if (adj1 == adj2)
					return adj1;
		return -1;
	}
	
	protected void CollectVertexes(MutableGeoMesh mesh, int baseTriangleNode, int depth = -1)
	{
		if (depth == 0 || tritree[baseTriangleNode].children[0] < 0)
		{
			for (int i = 0; i < 3; i++)
				mesh.AddVertex(tritree[baseTriangleNode].vertices[i]);
		}
		else
		{
			for (int i = 0; i < 4; i++)
				CollectVertexes(mesh, tritree[baseTriangleNode].children[i], depth-1);
		}
	}
	
	protected void Subdivide(int treeNodeIndex, int levelLimit, int _callLevel = 0)
	{
		Utils.Assert(treeNodeIndex >= 0, "Geosphere.GeoSurface.Subdivide: treeNodeIndex must be >= 0");
		
		if (tritree[treeNodeIndex].children[0] < 0)
		{
			int[] subNodes = new int[3];
			int subdivisionLevel = tritree[treeNodeIndex].level;
			
			if (subdivisionLevel >= levelLimit)
				return;
			
			for (int i = 0; i < 3; i++)
			{
				int v1 = tritree[treeNodeIndex].vertices[i];
				int v2 = tritree[treeNodeIndex].vertices[(i+1) % 3];
				
				int v12 = xFindNodesCommonAdjacency(v1, v2, subdivisionLevel+1);
				
				if (v12 < 0)
				{
					GeoNode newnode = new GeoNode();
					newnode.position = NormalizePoint( 0.5f*(nodes[v1].position + nodes[v2].position) );
					newnode.elevation = 0f;
					newnode.adjacency = new List<int[]>();
					v12 = xAddNode(newnode);
					
					xConnectNodes(v12, v1, subdivisionLevel+1);
					xConnectNodes(v12, v2, subdivisionLevel+1);
				}
				
				subNodes[i] = v12;
			}
			
			xConnectNodes(subNodes[0], subNodes[1], subdivisionLevel+1);
			xConnectNodes(subNodes[1], subNodes[2], subdivisionLevel+1);
			xConnectNodes(subNodes[2], subNodes[0], subdivisionLevel+1);
			
			//      /\
			//     /  \
			//    /----\
			//   / \  / \
			//  /___\/___\
			
			xAddTriTreeNode( new int[3] { tritree[treeNodeIndex].vertices[0], subNodes[0], subNodes[2] }, treeNodeIndex );
			xAddTriTreeNode( new int[3] { tritree[treeNodeIndex].vertices[1], subNodes[1], subNodes[0] }, treeNodeIndex );
			xAddTriTreeNode( new int[3] { tritree[treeNodeIndex].vertices[2], subNodes[2], subNodes[1] }, treeNodeIndex );
			xAddTriTreeNode( new int[3] { subNodes[0], subNodes[1], subNodes[2] }, treeNodeIndex );
		}
		
		Utils.Assert(_callLevel+1 <= levelLimit, "Geosphere.GeoSurface.Subdivide: Recoursive call level ("+(_callLevel+1)+") can't be greater than levelLimit ("+levelLimit+")");
		foreach (int childNode in tritree[treeNodeIndex].children)
			Subdivide(childNode, levelLimit, _callLevel+1);
	}
}


public class GeoSphere : GeoSurface
{
	public GeoSphere() : base()
	{
		triTreeRootSize = IcosahedronTriangles;
		trianglePairs = IcosahedronTrianglePairs;
		triangleToPairsMap = IcosahedronTriangleToPairsMap;
		BuildIcosahedron();
	}
	
	public override Vector3 NormalizePoint(Vector3 point)
	{
		return point.normalized;
	}
	
	public override Vector3 ElevatePoint(Vector3 point, float elevation)
	{
		return point * (1f+elevation);
	}	
	
	// -------------------------------------------------------
	public const int IcosahedronTriangles = 20;
	
	public static int[][] IcosahedronTrianglePairs = new int[IcosahedronTriangles/2][]
		{ new int[2] {0, 1}, new int[2] {2, 3}, new int[2] {15, 4}, new int[2] {14, 5}, new int[2] {19, 6}, 
		  new int[2] {16, 7}, new int[2] {12, 8}, new int[2] {18, 9}, new int[2] {13, 10}, new int[2] {17, 11} };
	
	public static int[] IcosahedronTriangleToPairsMap = new int[IcosahedronTriangles]
		{ 0, 0, 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 6, 8, 3, 2, 5, 9, 7, 4 };

	protected void BuildIcosahedron()
	{
		const float A = 0.5f;
		const float B = 0.30901699437f; // 1/(1+Sqrt(5))
		
		Vector3[] icoverts = new Vector3[12]
			{ new Vector3(0f, -B, -A), new Vector3(0f, -B, A), new Vector3(0f, B, -A), new Vector3(0f, B, A),
			  new Vector3(-A, 0f, -B), new Vector3(-A, 0f, B), new Vector3(A, 0f, -B), new Vector3(A, 0f, B),
			  new Vector3(-B, -A, 0f), new Vector3(-B, A, 0f), new Vector3(B, -A, 0f), new Vector3(B, A, 0f) };
			
		int[][] icotris = new int[20][]
			{ new int[3] {2, 9, 11}, new int[3] {3, 11, 9}, new int[3] {3, 5, 1},  new int[3] {3, 1, 7},  new int[3] {2, 6, 0},
			  new int[3] {2, 0, 4},  new int[3] {1, 8, 10}, new int[3] {0, 10, 8}, new int[3] {9, 4, 5},  new int[3] {8, 5, 4},
			  new int[3] {11, 7, 6}, new int[3] {10, 6, 7}, new int[3] {3, 9, 5},  new int[3] {3, 7, 11}, new int[3] {2, 4, 9},
			  new int[3] {2, 11, 6}, new int[3] {0, 8, 4},  new int[3] {0, 6, 10}, new int[3] {1, 5, 8},  new int[3] {1, 10, 7} };
		
		int[][] icoadj = new int[12][]
			{ new int[5] {8, 2, 4, 10, 6}, new int[5] {8, 10, 3, 5, 7}, new int[5] {0, 9, 11, 4, 6},  new int[5] {7, 9, 11, 5, 1},
			  new int[5] {0, 9, 2, 5, 8},  new int[5] {8, 1, 3, 4, 9},  new int[5] {0, 2, 11, 10, 7}, new int[5] {11, 1, 10, 3, 6},
			  new int[5] {0, 1, 10, 4, 5}, new int[5] {3, 2, 11, 4, 5}, new int[5] {8, 1, 6, 0, 7},   new int[5] {9, 2, 3, 6, 7} };		
		
		for (int i = 0; i < icoverts.Length; i++)
		{
			GeoNode node = new GeoNode();
			node.position = icoverts[i].normalized;
			node.adjacency.Add(icoadj[i]);
			nodes.Add(node);
		}
		
		for (int i = 0; i < icotris.Length; i++)
			xAddTriTreeNode(icotris[i]);
	}
	
	protected override Vector2 GetVertexUV (Vector3 position, int tripairIndex)
	{

		Vector3 p =   NormalizePoint(position);		
		
		UVPlaneData uvPlane = uvPlanesData[tripairIndex];
		
		Vector3 pP = Math3d.ProjectPointOnPlane(uvPlane.normal, uvPlane.posA, p, p);
		
		float u = Math3d.PointLineDistance(pP, uvPlane.projA, uvPlane.axisC1A) / uvPlane.distC2A;
		float v = Math3d.PointLineDistance(pP, uvPlane.projA, uvPlane.axisC2A) / uvPlane.distC1A;
		
		return new Vector2(u*1.5f, v*1.5f); // i have no idea why 1.5 works
	}

	protected override Vector3 GetVertexPositionFromUV(Vector2 uv, int tripairIndex)
	{	
		float u = uv.x;
		float v = uv.y;
		
		UVPlaneData uvPlane = uvPlanesData[tripairIndex];
		
		Vector3 pAC1 = Utils.VectorLerpUnclamped(uvPlane.projA, uvPlane.projC1, v);
		Vector3 pC2B = Utils.VectorLerpUnclamped(uvPlane.projC2, uvPlane.projB, v);
		
		return Utils.VectorLerpUnclamped(pAC1, pC2B, u).normalized;
	}
	
	protected override Color Colorize(float[] noiseValues)
	{
		float fmin = 0f;
		float fmax = 0.3f; //1.5 waterworld, frozenmars
		float c = (Mathf.Clamp( noiseValues[0], fmin, fmax) - fmin) / (fmax-fmin);
		//Color col = Color.Lerp( new Color(0.49f, 0.378f, 0.6f), new Color(0.65f, 0.46f, 0.33f), 1f-c );
		
		// frozen mars
		//Color col = Color.Lerp( new Color(c, c, c), new Color(0.65f, 0.46f, 0.33f), Mathf.Pow(1f-c, 0.75f) );

		// waterworld
		//Color col = Color.Lerp(new Color(c*0.8f, 0.8f-c*0.2f, c*0.5f), new Color(0.05f, 0.2f, 0.6f), Mathf.Pow(1f - c, 2f));

		// cloudy neptune
		Color col = Color.Lerp(new Color(c, c, c), new Color(0.05f, 0.2f, 0.6f), Mathf.Pow(1f - c, 0.25f));
		
		//Color col = Color.Lerp( new Color(0.7f, 0.7f, 0.7f), new Color(0.9f, 0.7f, 0.5f), 1f-Mathf.Pow(1f-c, 0.75f) );
		//return new Color(c, c, c);
		
		return col;
	}
}


public class GeoQuad : GeoSurface
{
	
	//     C1__________B
	//      /\        /
	//     /  \      /
	//    /    \    /
	//   /      \  /
	//  /________\/
	//  A         C2
	
	protected Vector3 uvPlaneNormal;
	protected Vector3 uvProjA;
	protected Vector3 uvProjB;
	protected Vector3 uvProjC1;
	protected Vector3 uvProjC2;
	
	public GeoQuad(Vector3 pA, Vector3 pB, Vector3 pC1, Vector3 pC2) : base()
	{
		triTreeRootSize = 2;
		trianglePairs = new int[1][] { new int[2] {0, 1} };
		triangleToPairsMap = new int[2] { 0, 0 };
		
		// 0 A
		GeoNode node = new GeoNode();
		node.position = pA;
		node.adjacency.Add( new int[2] {2, 3} );
		nodes.Add(node);
		
		// 1 B
		node = new GeoNode();
		node.position = pB;
		node.adjacency.Add( new int[2] {2, 3} );
		nodes.Add(node);

		// 2 C1
		node = new GeoNode();
		node.position = pC1;
		node.adjacency.Add( new int[3] {0, 1, 3} );
		nodes.Add(node);

		// 3 C2
		node = new GeoNode();
		node.position = pC2;
		node.adjacency.Add( new int[3] {0, 1, 2} );
		nodes.Add(node);

		xAddTriTreeNode( new int[3] {0, 2, 3} );
		xAddTriTreeNode( new int[3] {2, 1, 3} );
	}
	
	protected override Vector2 GetVertexUV (Vector3 position, int tripairIndex)
	{
		return new Vector2(0f, 0f);
	}
	
	protected override Vector3 GetVertexPositionFromUV(Vector2 uv, int tripairIndex)
	{	
		return new Vector3(0f, 0f, 0f);
	}
}