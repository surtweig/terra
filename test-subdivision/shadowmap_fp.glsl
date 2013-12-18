#version 120
uniform sampler2DShadow ShadowMap;

uniform bool Softly;
uniform float Scale;
//uniform vec4 LightPosition;

varying vec3 fragNormal;
varying vec3 fragPosition;

void main()
{
  float shadow = shadow2DProj(ShadowMap, gl_TexCoord[1]).r;

  if (Softly)
  {
    int f = 4;
	shadow = 0.0;
	float acc = 0.0;
	float k = 0.0;
    for (int ix = -f; ix <= f; ix++) 
    {
      for (int iy = -f; iy <= f; iy++) 
      {
		k = 1.0 - abs(ix * iy) / (f*f);
		shadow += shadow2DProj(ShadowMap, gl_TexCoord[1] + vec4(0.00024*ix, 0.00024*iy, 0.0, 0.0)*Scale).r * k;
		acc += k;
      }
    }
	shadow /= acc;
  }

  
  vec3 L = normalize(gl_LightSource[0].position.xyz - fragPosition);
  vec4 Idiff = vec4(1.0, 1.0, 1.0, 1.0) * max(dot(fragNormal, L), 0.0);
  Idiff = clamp(Idiff, 0.0, 1.0);
  
  gl_FragColor = Idiff * clamp(shadow, 0.0, 1.0);//vec4(mix(shadow, 1.0, 0.2));
  gl_FragColor.a = 1.0;
}
