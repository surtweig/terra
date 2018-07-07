Shader "Custom/atmosphere" {
	Properties {
		_DensityFactor ("DensityFactor", Float) = 5.0
		_SpecPower ("SpecPower", Float) = 0.0
		_PlanetRadius ("PlanetRadius", Float) = 0.0
		_AtmosphereRadius ("AtmosphereRadius", Float) = 0.0
		_CamHeight ("CamHeight", Float) = 0.0
		//_CamPosition ("CamPosition", Vector) = (1, 1, 1, 1)
		_LowColor ("LowColor", Color) = (1, 1, 1, 1)
		_HighColor ("HighColor", Color) = (1, 1, 1, 1)
		_DuskColor ("DuskColor", Color) = (1, 1, 1, 1)
	}
	SubShader {
		Tags { "Queue"="Transparent" "RenderType"="Transparent" }
		Blend SrcAlpha One
		
		Pass {
			Tags { "LightMode" = "ForwardBase" }
			Lighting Off
			ZWrite Off
			Cull Front
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
	
			#include "UnityCG.cginc"
	
			static const float PI = 3.14159265f;
	
			uniform float _SpecPower;
			uniform float _PlanetRadius;
			uniform float _AtmosphereRadius;
			uniform float _CamHeight;
			uniform float _DensityFactor;
			
			//uniform float4 _CamPosition;
			uniform float4 _LowColor;
			uniform float4 _HighColor;
			uniform float4 _DuskColor;			
			
            struct vertexInput {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
            };

            struct vertexOutput {
				float4 pos : SV_POSITION;
				float3 normal : NORMAL;
				float4 fpos : TEXCOORD0;
				float3 lightDir : TEXCOORD1;
				float3 fnormal : TEXCOORD2;
				float3 worldvertpos : TEXCOORD3;
            };
			
			vertexOutput vert(vertexInput v)
			{
				vertexOutput o;

				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.fpos = v.vertex;
				o.lightDir = normalize(ObjSpaceLightDir(v.vertex));
				o.fnormal = normalize(v.normal).xyz;
				o.normal =  mul((float3x3)_Object2World, normalize(v.normal.xyz));
				o.worldvertpos = mul(_Object2World, v.vertex);
				return o; 
			}
			
			float4 frag(vertexOutput i) : COLOR
			{
				float3 CamPosition = i.worldvertpos-_WorldSpaceCameraPos;
				float h = length(CamPosition);
				CamPosition /= h;
				h = length(mul(_World2Object, _WorldSpaceCameraPos));
				float camnorm = dot(CamPosition, i.normal);
				float dayfactor = clamp(dot(i.fnormal, -i.lightDir), 0.0, 1.0);
				
				float4 color1 = _LowColor;
				float4 color2 = _HighColor;

				float theta1 = asin(_PlanetRadius/h) + asin(_PlanetRadius/_AtmosphereRadius);
				float theta2 = PI;	

				if (h > _AtmosphereRadius) theta2 = asin(_AtmosphereRadius/h) + PI*0.5;
				
				if (camnorm > (cos(theta1)+0.01)) clip(-1.0);
				
				color1 = lerp(color1, color2, clamp(0.5*(h-_AtmosphereRadius)/_AtmosphereRadius, 0.0, 0.5));
				color1.a = 1.0;
				
				float4 fragcolor = lerp(color2, color1, pow(smoothstep(cos(theta2), cos(theta1), camnorm), _DensityFactor))*(1.0-dayfactor);
				
				if (h < _AtmosphereRadius) fragcolor.a = (1.0-dayfactor)*lerp(fragcolor.a, (1.0-dayfactor), pow(1.0-(h-_PlanetRadius)/(_AtmosphereRadius-_PlanetRadius), 1.0));
				
				return fragcolor;
			}
			
			ENDCG
		}
	} 
	FallBack "Diffuse"
}
