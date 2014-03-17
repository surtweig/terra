Shader "Custom/defferedprepass" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		#pragma surface surf Geo
		#include "UnityCG.cginc"
		
		inline half4 LightingGeo_PrePass (SurfaceOutput s, half4 light)
		{
			//half spec = light.a * s.Gloss;
			//half d = Luminance(light.rgb)*0.5;
			half4 c;
			c.rgb = s.Albedo * pow(light.rgb, 0.6);
			c.a = 1;
			return c;
		}

		/*half4 LightingGeo (SurfaceOutput s, half3 lightDir, half atten)
		{
			half NdotL = max(0, dot (s.Normal, lightDir));
			half diff = pow(NdotL, 0.5);
			half4 c;
			c.rgb = s.Albedo * _LightColor0.rgb * diff;
			c.a = 1;
			return c;
		}*/
		
		sampler2D _MainTex;

		struct Input {
			float2 uv_MainTex;
		};

		void surf (Input IN, inout SurfaceOutput o) {
			half4 c = tex2D (_MainTex, IN.uv_MainTex);
			o.Albedo = c.rgb;
			//o.Emission = half4(0, 1, 0, 1);
			o.Alpha = c.a;
		}
		ENDCG
	} 
	FallBack "Diffuse"
}
