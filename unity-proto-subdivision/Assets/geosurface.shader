Shader "Custom/geosurface" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		#pragma surface surf Geo

		sampler2D _MainTex;

		struct Input {
			float2 uv_MainTex;
		};

		half4 LightingGeo (SurfaceOutput s, half3 lightDir, half atten)
		{
			half NdotL = max(0, dot (s.Normal, lightDir));
			half diff = pow(NdotL, 0.5);
			half4 c;
			c.rgb = s.Albedo * _LightColor0.rgb * diff;
			c.a = 0.5;
			return c;
		}

		
		void surf (Input IN, inout SurfaceOutput o) {
			half4 c = tex2D (_MainTex, IN.uv_MainTex);
			o.Albedo = c.rgb;
			o.Alpha = c.a;
		}
		ENDCG
	} 
	
	FallBack "Diffuse"
}
