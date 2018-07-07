Shader "Custom/FladderakDiffuse" {
  Properties 
	{
		_NormalTexture ("Normal Texture", 2D) = "white" {}		
		_DiffuseTexture ("Diffuse Texture", 2D) = "white" {}
		_DiffuseTint ( "Diffuse Tint", Color) = (1, 1, 1, 1)

		_PlanetRadius ("PlanetRadius", Float) = 0.0
		_AtmosphereRadius ("AtmosphereRadius", Float) = 0.0
		_LightIntensity ("LightIntensity", Float) = 1.0
		_FogColor ("FogColor", Color) = (1, 1, 1, 1)		
	}

	SubShader 
	{
		Tags { "RenderType"="Opaque" }

		pass
		{		
			Tags { "LightMode"="ForwardBase"}

			CGPROGRAM

			#pragma target 3.0
			#pragma fragmentoption ARB_precision_hint_fastest

			#pragma vertex vertShadow
			#pragma fragment fragShadow
			#pragma multi_compile_fwdbase

			#include "UnityCG.cginc"
			#include "AutoLight.cginc"

			static const float PI = 3.14159265f;
			
			uniform float _PlanetRadius;
			uniform float _AtmosphereRadius;
			uniform float _LightIntensity;
			uniform float4 _FogColor;
			
			sampler2D _MainTex;
			sampler2D _NormalTexture;
			
			float4 _DiffuseTint;
			float4 _LightColor0;

			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 fpos : TEXCOORD5;
				float3 lightDir : TEXCOORD0;
				float3 normal : TEXCOORD1;
				float2 uv : TEXCOORD2;				
				LIGHTING_COORDS(3, 4)
				float3 worldvertpos : TEXCOORD6;
			};

			v2f vertShadow(appdata_base v)
			{
				v2f o;

				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.uv = v.texcoord;
				o.lightDir = normalize(ObjSpaceLightDir(v.vertex));
				o.normal = normalize(v.normal).xyz;
				o.fpos = v.vertex;//mul(UNITY_MATRIX_MVP, v.vertex);
				o.worldvertpos = mul(_Object2World, v.vertex);
				TRANSFER_VERTEX_TO_FRAGMENT(o);

				return o; 
			}

			float4 fragShadow(v2f i) : COLOR
			{					
				float3 texnormal = tex2D(_NormalTexture, i.uv);

				float3 L = normalize(i.lightDir);
				float3 N = normalize(texnormal*2.0 - float3(1.0, 1.0, 1.0));

				float attenuation = LIGHT_ATTENUATION(i);
				float4 ambient = UNITY_LIGHTMODEL_AMBIENT;

				float NdotL = pow(max(dot(N, L)-0.01, 0), 0.7);//saturate(dot(N, L));
				float4 diffuseTerm = NdotL * _LightColor0 * _DiffuseTint * attenuation;

				float4 diffuse = tex2D(_MainTex, i.uv);

				float4 finalColor = diffuseTerm * diffuse;
				
				// TerraObscura atm_planet_surface_frag
				float3 CamPosition = i.worldvertpos-_WorldSpaceCameraPos;
				float h = length(CamPosition);
				CamPosition /= h;
				
				float3 CamPositionLocal = mul(_World2Object, _WorldSpaceCameraPos);
				h = length(CamPositionLocal);
				CamPositionLocal /= h;
				
				float camnorm = dot(-CamPosition, i.worldvertpos);
				float dayfactor = clamp(dot(normalize(i.fpos), i.lightDir), 0.0, 1.0);
				
				float theta1 = PI*0.5-asin(_PlanetRadius/h);
				float theta2 = 0.0;
				
				float atmfog = pow(smoothstep(cos(theta2), cos(theta1), camnorm), 2.0);
				finalColor = lerp(
					pow(dayfactor, 0.3)*_FogColor,
					diffuse * _LightIntensity * (diffuseTerm),
					1.0-atmfog
				);
				
				return finalColor;//atmfog*float4(1,1,1,1);
			}

			ENDCG
		}		

	} 
	FallBack "Diffuse"
}
