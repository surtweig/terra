﻿Shader "Custom/peter" {
	Properties
	{
		_MainTex ("Base (RGB)", 2D) = "white" {}
	}
 
	CGINCLUDE
 
	#include "UnityCG.cginc"
	#include "AutoLight.cginc"
	#include "Lighting.cginc"
 
	uniform sampler2D _MainTex;
 
	ENDCG
 
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 200
 
		Pass
		{
			Lighting On
 
			Tags {"LightMode" = "ForwardBase"}
 
			CGPROGRAM
 
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase
 
			struct VSOut
			{
				float4 pos : SV_POSITION;
				float3 norm;
				float2 uv : TEXCOORD1;
				LIGHTING_COORDS(3,4)
			};
 
			VSOut vert(appdata_tan v)
			{
				VSOut o;
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.norm = mul((float3x3)_Object2World, v.normal);
				o.uv = v.texcoord.xy;
 
				TRANSFER_VERTEX_TO_FRAGMENT(o);
 
				return o;
			}
 
			float4 frag(VSOut i) : COLOR
			{
				float3 lightColor = _LightColor0.rgb;
				float3 lightDir = _WorldSpaceLightPos0;
				float4 colorTex = tex2D(_MainTex, i.uv.xy);
				float atten = LIGHT_ATTENUATION(i);
				float3 N = i.norm;
				float NL = pow(max(dot(N, lightDir)-0.01, 0), 0.5);
 
				float3 color = colorTex.rgb * lightColor * NL * atten;
				return float4(color, colorTex.a);
			}
 
			ENDCG
		}
	}
	FallBack "Diffuse"
}