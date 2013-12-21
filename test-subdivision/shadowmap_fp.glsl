#version 120
uniform sampler2DShadow ShadowMap;

uniform bool Softly;
uniform float Scale;
//uniform vec4 LightPosition;

varying vec3 fragNormal;
varying vec3 fragPosition;

float rand(vec2 co){
    return fract(sin(dot(co.xy, vec2(12.9898,78.233))) * 43758.5453);
}

float saturate(float x, float p)
{
	if (x < 0.5)
		return 0.5*pow(2.0*x, p);
	else
		return 1 - 0.5*pow(2.0*(1.0-x), p);
}

void main()
{
  float shadow = shadow2DProj(ShadowMap, gl_TexCoord[1]).r;

  if (Softly)
  {
    int f = 6;
	shadow = 0.0;
	float acc = 0.0;
	float k = 0.0;
	vec2 co;
    for (int ix = -f; ix <= f; ix++) 
    {
      for (int iy = -f; iy <= f; iy++) 
      {
		k = 1.0 - abs(ix + iy) / (2.0*f);
		co = vec2(0.00024*ix, 0.00024*iy)*Scale;
		//co += 0.1*vec2(rand(co)-0.5, rand(co)-0.5);
		shadow += shadow2DProj(ShadowMap, gl_TexCoord[1] + vec4(co.x, co.y, 0.0, 0.0)).r * k;
		acc += k;
      }
    }
	shadow /= acc;
  }
  
  shadow = saturate(pow(shadow, 0.8), 5.0);
  //shadow = pow(shadow, 5.0);
  //if (shadow > 0.1) shadow = 0.1 + pow(shadow-0.1, 0.1);
  
  vec3 L = normalize(gl_LightSource[0].position.xyz - fragPosition);
  vec4 Idiff = vec4(1.0, 1.0, 1.0, 1.0) * max(dot(fragNormal, L), 0.0);
  Idiff = clamp(Idiff, 0.0, 1.0);
  
  gl_FragColor = clamp(1.2 * Idiff * clamp(shadow, 0.0, 1.0), 0.0, 1.0);//vec4(mix(shadow, 1.0, 0.2));
  gl_FragColor.a = 1.0;
}
