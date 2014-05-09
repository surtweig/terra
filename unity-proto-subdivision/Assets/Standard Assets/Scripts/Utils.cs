using UnityEngine;
using System.Collections;
using System.Runtime.InteropServices;

public static class Utils
{
	public static float saturate(float x, float p)
	{
		if (x < 0.5f)
			return 0.5f*Mathf.Pow(2f*x, p);
		else
			return 1 - 0.5f*Mathf.Pow(2f*(1f-x), p);
	}
	
	[StructLayout(LayoutKind.Explicit)] 
	public struct FloatInt32
	{
    	[FieldOffset(0)] public float f32;
    	[FieldOffset(0)] public int i32;
		
		public FloatInt32(float asFloat32) : this()
		{
			f32 = asFloat32;
		}

		public FloatInt32(int asInt32) : this()
		{
			i32 = asInt32;
		}
	}
	
	public static void Assert(bool condition, string message)
	{
		if (!condition)
		{
			Debug.LogError("Assertion failed: " + message);
			Debug.Break();
		}
	}
}

