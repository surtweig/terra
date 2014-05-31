#define THREADGROUPSIZE 64
#define SPECTRUM_MAX_LENGTH 16

//#define RNDMETHOD_SIMPLE
#define RNDMETHOD_POHORESKI

#define KERNEL(func)                [numthreads(THREADGROUPSIZE,1,1)] void k_##func (uint3 id : SV_DispatchThreadID) { values[id.x].val = func(points[id.x].pos, baseOctaves, baseSpectrum); } 
#define KERNEL_P1(func, p1)         [numthreads(THREADGROUPSIZE,1,1)] void k_##func (uint3 id : SV_DispatchThreadID) { values[id.x].val = func(points[id.x].pos, baseOctaves, baseSpectrum, p1); } 
#define KERNEL_P2(func, p1, p2)     [numthreads(THREADGROUPSIZE,1,1)] void k_##func (uint3 id : SV_DispatchThreadID) { values[id.x].val = func(points[id.x].pos, baseOctaves, baseSpectrum, p1, p2); } 
#define KERNEL_P3(func, p1, p2, p3) [numthreads(THREADGROUPSIZE,1,1)] void k_##func (uint3 id : SV_DispatchThreadID) { values[id.x].val = func(points[id.x].pos, baseOctaves, baseSpectrum, p1, p2, p3); } 

typedef RWStructuredBuffer<float> SPECTRUM;

struct PointInput
{
	float3 pos;
};

struct PerlinOutput
{
	float val;
};

struct SpectrumStruct
{
	float values[SPECTRUM_MAX_LENGTH];
	int octaves;
};

RWStructuredBuffer<PointInput> points;
RWStructuredBuffer<PerlinOutput> values;

int baseOctaves;
float gamma;
SPECTRUM baseSpectrum;

#ifdef RNDMETHOD_SIMPLE
float rand (float3 pos)
{
      return 0.5+(frac(sin(dot(pos, float3(12.9898, 78.233, -47.2937))) * 43758.5453))*0.5;
}
#endif

#ifdef RNDMETHOD_POHORESKI
// Input: It uses texture coords as the random number seed.
// Output: Random number: [0,1), that is between 0.0 and 0.999999... inclusive.
// Author: Michael Pohoreski
// Copyright: Copyleft 2012 :-)
float rand (float3 pos)
{
  // We need irrationals for pseudo randomness.
  // Most (all?) known transcendental numbers will (generally) work.
  const float3 r = float3(
    23.1406926327792690, // e^pi (Gelfond's constant)
    2.6651441426902251,  // 2^sqrt(2) (Gelfond–Schneider constant)
	3.1415926535897932); 
  return frac( cos( fmod( 123456789.0, 1e-7 + 256.0 * dot(pos, r) ) ) );  
}
#endif

float3 rand3 (float3 pos)
{
	return float3( rand(pos.xyz), rand(pos.yzx), rand(pos.zxy) );
}

static float3 rndvector = float3(28.9017903, 53.7600885, 49.0959582);

static uint permutation4[128] = {
1535746199, 226692954, 895508425, 3775392194, 510076044, 1661505093, 169209893, 2483469847,
1273657591, 1053104640, 3420191838, 537600885, 1478603065, 1463326189, 2289898670, 2940512427,
2252842314, 2786799755, 3885929037, 2061856595, 3867530044, 693922268, 687156791, 915367668,
2705267009, 1230034945, 3146009809, 2836552144, 2189935816, 1453309044, 3329057956, 1073986221,
4209170740, 3389356924, 2121700134, 3562361599, 3812347599, 289017903, 706526646, 3584735199,
43579511, 1185126956, 2607127005, 162278311, 4247197313, 1852596755, 3907023183, 1752218034,
3831625434, 3253871355, 210817774, 4053971903, 3952161617, 1810829049, 534167601, 2641020853,
2966181048, 758282611, 4271244415, 1573776522, 490959582, 2381531160, 1112458112, 3030138327,

1535746199, 226692954, 895508425, 3775392194, 510076044, 1661505093, 169209893, 2483469847,
1273657591, 1053104640, 3420191838, 537600885, 1478603065, 1463326189, 2289898670, 2940512427,
2252842314, 2786799755, 3885929037, 2061856595, 3867530044, 693922268, 687156791, 915367668,
2705267009, 1230034945, 3146009809, 2836552144, 2189935816, 1453309044, 3329057956, 1073986221,
4209170740, 3389356924, 2121700134, 3562361599, 3812347599, 289017903, 706526646, 3584735199,
43579511, 1185126956, 2607127005, 162278311, 4247197313, 1852596755, 3907023183, 1752218034,
3831625434, 3253871355, 210817774, 4053971903, 3952161617, 1810829049, 534167601, 2641020853,
2966181048, 758282611, 4271244415, 1573776522, 490959582, 2381531160, 1112458112, 3030138327
};

	
float fade (float t)
{
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}
	
float grad (int hash, float x, float y, float z)
{
	int h = hash & 15;
	float u = h<8 ? x : y;
	float v = h<4 ? y : h==12||h==14 ? x : z;
	return ((h&1) == 0 ? u : -u) + ((h&2) == 0 ? v : -v);
}

uint p4i (uint index)
{
	uint u = index / 4;
	uint b = index % 4;
	return (permutation4[u] & (255 << b*8)) >> b*8;
}
	
float perlin (float3 p)
{
	uint3 i = uint3( int(floor(p.x)) & 255, int(floor(p.y)) & 255, int(floor(p.z)) & 255 );

	float3 f = p-floor(p);
	
	float u = fade(f.x);
	float v = fade(f.y);
	float w = fade(f.z);
	
	uint A  = (p4i(i.x) + i.y);
	uint AA = (p4i(A) + i.z);
	uint AB = (p4i(A+1) + i.z);
	uint B  = (p4i( i.x+1 ) + i.y);
	uint BA = (p4i(B) + i.z);
	uint BB = (p4i( B+1 ) + i.z);
	
	return lerp(lerp(lerp(grad(p4i(AA), f.x  , f.y  , f.z   ),  
                          grad(p4i(BA), f.x-1.0, f.y  , f.z   ),
						  u), 
                     lerp(grad(p4i(AB), f.x  , f.y-1.0, f.z   ),  
                          grad(p4i(BB), f.x-1.0, f.y-1.0, f.z   ),
						  u),
					 v),
                lerp(lerp(grad(p4i(AA+1), f.x  , f.y  , f.z-1.0 ),  
                          grad(p4i(BA+1), f.x-1.0, f.y  , f.z-1.0 ),
						  u), 
                     lerp(grad(p4i(AB+1), f.x  , f.y-1.0, f.z-1.0 ),
                          grad(p4i(BB+1), f.x-1.0, f.y-1.0, f.z-1.0 ),
						  u),
				     v),
				w);	
}

float FBM (float3 p, int octaves, SPECTRUM spectrum)
{
	float v = 0.0;
	float3 t = p;
	
	for (int octave = 0; octave < octaves; octave++)
	{
		v += perlin(t)*spectrum[octave];
		t *= 2.0;
	}
	
	/*v = 0.0;
	int i;
	if (p.y < 0.1)
	{	
		i = (int)(p.x);
		if (i < 0) i = 0;
		if (i >= 16) i = 15;
		v = pow(2.0, -i*0.5);
	}
	if (p.y >= 0.2 && p.y < 0.3)
	{	
		i = (int)(p.x);
		if (i < 0) i = 0;
		if (i >= 16) i = 15;
		v = spectrum[i];
	}*/

	return v;
}


float3 FBMVector (float3 p, int octaves, SPECTRUM spectrum)
{
	return float3(FBM(p, octaves, spectrum), FBM(p+rndvector, octaves, spectrum), FBM(p+2.0*rndvector, octaves, spectrum));
}


float One(float3 p, int octaves, SPECTRUM spectrum)
{
	return 1.0;
}

float Zero(float3 p, int octaves, SPECTRUM spectrum)
{
	return 0.0;
}