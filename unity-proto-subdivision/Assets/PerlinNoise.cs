using UnityEngine;
using System.Collections;

// Ported from GLScene project (http://glscene.org)

// Generates Perlin Noise in the [-1; 1] range. 2D noise requests are taken in the Z=0 slice
class TPerlin3DNoise
{
	public const int cPERLIN_TABLE_SIZE = 256; // must be a power of two
	private const int cMask = cPERLIN_TABLE_SIZE - 1;
	
	private int[] FPermutations = new int[cPERLIN_TABLE_SIZE];
	private float[] FGradients = new float[cPERLIN_TABLE_SIZE*3];
	
	public TPerlin3DNoise(int randomSeed)
	{
		Initialize(randomSeed);
	}
	
	public void Initialize(int randomSeed)
	{
		int seedBackup = Random.seed;
		Random.seed = randomSeed;
		
		// Generate random gradient vectors
		for (int i = 0; i < cPERLIN_TABLE_SIZE; i++)
		{
			float z = 1f - 2f * Random.value;
			float r = Mathf.Sqrt(1f - z*z);
			float alpha = 2f*Mathf.PI * Random.value;
			FGradients[i*3] = r * Mathf.Sin(alpha);
			FGradients[i*3+1] = r * Mathf.Cos(alpha);
			FGradients[i*3+2] = z;
		}
		
		// Initialize permutations table
		for (int i = 0; i < cPERLIN_TABLE_SIZE; i++)
			FPermutations[i] = i;
		
		// Shake up
		for (int i = 0; i < cPERLIN_TABLE_SIZE; i++)
		{
			int j = Random.Range(0, cPERLIN_TABLE_SIZE);
			int t = FPermutations[i];
			FPermutations[i] = FPermutations[j];
			FPermutations[j] = t;
		}
		
		Random.seed = seedBackup;
	}
	
	public float Noise(Vector2 v)
	{
		int ix = Mathf.Floor(v.x);
		float fx0 = v.x - ix;
		float fx1 = fx0 - 1f;
		float wx = Smooth(fx0);

		int iy = Mathf.Floor(v.y);
		float fy0 = v.y - iy;
		float fy1 = fy0 - 1f;
		float wy = Smooth(fy0);
		
		float vy0 = Mathf.Lerp(Lattice(ix, iy, fx0, fy0),
                               Lattice(ix+1, iy, fx1, fy0),
                               wx);
		float vy1 = Mathf.Lerp(Lattice(ix, iy+1, fx0, fy1),
                               Lattice(ix+1, iy+1, fx1, fy1),
                               wx);
		return Mathf.Lerp(vy0, vy1, wy);
	}
	
	public float Noise(Vector3 v)
	{
		int ix = Mathf.Floor(v.x);
		float fx0 = v.x - ix;
		float fx1 = fx0- 1f;
		float wx = Smooth(fx0);
		
		int iy = Mathf.Floor(v.y);
		float fy0 = v.y - iy;
		float fy1 = fy0 - 1f;
		float wy = Smooth(fy0);
		
		int iz = Mathf.Floor(v.z);
		float fz0 = v.z - iz;
		float fz1 = fz0 - 1f;
		float wz = Smooth(fz0);
		
		float vy0 = Mathf.Lerp(Lattice(ix, iy, iz, fx0, fy0, fz0),
		                       Lattice(ix+1, iy, iz, fx1, fy0, fz0),
		                       wx);
		float vy1 = Mathf.Lerp(Lattice(ix, iy+1, iz, fx0, fy1, fz0),
		                       Lattice(ix+1, iy+1, iz, fx1, fy1, fz0),
		                       wx);
		
		float vz0 = Mathf.Lerp(vy0, vy1, wy);
		
		vy0 = Mathf.Lerp(Lattice(ix, iy, iz+1, fx0, fy0, fz1),
		                 Lattice(ix+1, iy, iz+1, fx1, fy0, fz1),
		                 wx);
		vy1 = Mathf.Lerp(Lattice(ix, iy+1, iz+1, fx0, fy1, fz1),
		                 Lattice(ix+1, iy+1, iz+1, fx1, fy1, fz1),
		                 wx);
		float vz1 = Mathf.Lerp(vy0, vy1, wy);
		
		return Mathf.Lerp(vz0, vz1, wz);
	}

	private float Lattice(int ix, int iy, int iz, float fx, float fy, float fz)
	{
		int g = FPermutations[(ix+FPermutations[(iy+FPermutations[iz && cMask]) && cMask]) && cMask]*3;
		return FGradients[g]*fx + FGradients[g+1]*fy + FGradients[g+2]*fz;
	}
	
	private float Lattice(int ix, int iy, float fx, float fy)
	{
		int g = FPermutations[(ix+FPermutations[(iy+FPermutations[0]) && cMask]) && cMask]*3;
		return FGradients[g]*fx + FGradients[g+1]*fy;
	}
	
	private float Smooth(float x)
	{
		return x*x*(3f-2f*x);
	}
}
