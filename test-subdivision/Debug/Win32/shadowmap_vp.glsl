#version 120
uniform mat4 EyeToLightMatrix;

varying vec3 fragNormal;
varying vec3 fragPosition;

void main()
{

  fragPosition = vec3(gl_ModelViewMatrix * gl_Vertex);
  fragNormal = normalize(gl_NormalMatrix * gl_Normal);

  gl_Position = ftransform();
  vec4 Pe = gl_ModelViewMatrix * gl_Vertex;

  gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
  gl_TexCoord[1] =  EyeToLightMatrix * Pe;
}
