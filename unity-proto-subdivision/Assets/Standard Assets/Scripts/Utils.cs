using UnityEngine;
using System.Collections;

public static class Utils
{
	public static float saturate(float x, float p)
	{
		if (x < 0.5f)
			return 0.5f*Mathf.Pow(2f*x, p);
		else
			return 1 - 0.5f*Mathf.Pow(2f*(1f-x), p);
	}
}
