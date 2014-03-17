// Upgrade NOTE: replaced 'PositionFog()' with multiply of UNITY_MATRIX_MVP by position
// Upgrade NOTE: replaced 'V2F_POS_FOG' with 'float4 pos : SV_POSITION'

Shader "Custom/attenuation" {
Properties {
    _Color ("Main Color", Color) = (1,1,1,0.5)
}

Category {
    /* Upgrade NOTE: commented out, possibly part of old style per-pixel lighting: Blend AppSrcAdd AppDstAdd */
    Fog { Color [_AddFog] }

    // Fragment program cards
    #warning Upgrade NOTE: SubShader commented out; uses Unity 2.x per-pixel lighting. You should rewrite shader into a Surface Shader.
/*SubShader {
        // Ambient pass
        Pass {
            Tags {"LightMode" = "Always" /* Upgrade NOTE: changed from PixelOrNone to Always */}
            Color [_PPLAmbient]
            SetTexture [_Dummy] {constantColor [_Color] Combine primary DOUBLE, constant}
        }
        // Vertex lights
        Pass {
            Tags {"LightMode" = "Vertex"}
            Lighting On
            Material {
                Diffuse [_Color]
                Emission [_PPLAmbient]
            }
            SetTexture [_Dummy] {constantColor [_Color] Combine primary DOUBLE, constant}
        }
        // Pixel lights
        Pass {
            Tags { "LightMode" = "Pixel" }
CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#pragma multi_compile_builtin
#pragma fragmentoption ARB_fog_exp2
#pragma fragmentoption ARB_precision_hint_fastest
#include "UnityCG.cginc"
#include "AutoLight.cginc"

// Define the structure
struct v2f {
    float4 pos : SV_POSITION;
    LIGHTING_COORDS // <= note no semicolon!
    float4 color : COLOR0;
};

// Vertex program
v2f vert (appdata_base v)
{
    v2f o;
    o.pos = mul (UNITY_MATRIX_MVP, v.vertex);

    // compute a simple diffuse per-vertex
    float3 ldir = normalize( ObjSpaceLightDir( v.vertex ) );
    float diffuse = pow(dot( v.normal, ldir ), 10.5);
    o.color = diffuse * _ModelLightColor0;

    // compute&pass data for attenuation/shadows
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}

// Fragment program
float4 frag (v2f i) : COLOR
{
    // Just multiply interpolated color with attenuation
    return i.color;// * LIGHT_ATTENUATION(i) * 2;
}
ENDCG
        }
    }*/
}

Fallback "VertexLit"
}