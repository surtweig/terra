uniform float LightIntensity;
uniform float SpecPower;
uniform sampler2D MainTexture;
uniform sampler2D Texture2;
uniform sampler2D Texture3;
uniform sampler2D LandscapeMap;
uniform vec4 FogColor;
uniform float DensityFactor;
uniform float AmbientLevel;
uniform vec3 CamPosition;
uniform float CamHeight;
uniform float PlanetRadius;
uniform float AtmosphereRadius;
uniform float WaterLevel;

varying vec3 Normal;
varying vec3 LightVector;
varying vec3 CameraVector;
varying vec3 VNormal;
varying vec3 VPosition;

void main(void) {

	float t1 = 0.33;
	float t2 = 0.33;
	float t3 = 0.33;

	
/*	float thetac = acos(CamPosition.z);
	float phic =  atan(CamPosition.y, CamPosition.x);
	float thetav = acos(VPosition.z);
	float phiv =  atan(VPosition.y, VPosition.x);

	if ((abs(thetac-thetav) < 0.1) && (abs(phic-phiv) < 0.1)) discard;*/
	

//        vec4 TextureContrib = t1*texture2D(MainTexture, gl_TexCoord[0].xy) + t2*texture2D(Texture2, 10000.0*gl_TexCoord[0].xy) + t3*texture2D(Texture3, 100.0*gl_TexCoord[0].xy);
//        vec4 TextureContrib = texture2D(MainTexture, gl_TexCoord[0].xy)*mix(length(texture2D(Texture2, 10000.0*gl_TexCoord[0].xy)), length(texture2D(Texture3, 10000.0*gl_TexCoord[0].xy)), texture2D(LandscapeMap, gl_TexCoord[0].xy).g);
        vec4 TextureContrib = texture2D(MainTexture, gl_TexCoord[0].xy)*mix(texture2D(Texture2, 10000.0*gl_TexCoord[0].xy), texture2D(Texture3, 10000.0*gl_TexCoord[0].xy), smoothstep(0.4, 0.6, texture2D(LandscapeMap, gl_TexCoord[0].xy).g));
        
	float x1 = gl_TexCoord[0].x*1024.0-fract(gl_TexCoord[0].x*1024.0);
	float y1 = gl_TexCoord[0].y*512.0-fract(gl_TexCoord[0].y*512.0);
	float x2 = x1+1.0;
	float y2 = y1+1.0;
//	float dx = fract(gl_TexCoord[0].x*1024.0);
//	float dy = fract(gl_TexCoord[0].y*512.0);
	float dx = 0.5*(1-cos(3.14159*fract(gl_TexCoord[0].x*1024.0)));
	float dy = 0.5*(1-cos(3.14159*fract(gl_TexCoord[0].y*512.0)));

	x1 = x1/1024.0;
	x2 = x2/1024.0;
	y1 = y1/512.0;
	y2 = y2/512.0;

//	float h11 = 0.25*(texture2D(LandscapeMap, vec2(x1, y1)).r + texture2D(LandscapeMap, vec2(x1-1.0, y1)).r + texture2D(LandscapeMap, vec2(x1, y1-1.0)).r + texture2D(LandscapeMap, vec2(x1-1.0, y1-1.0)).r);
//	float h21 = 0.25*(texture2D(LandscapeMap, vec2(x2, y1)).r + texture2D(LandscapeMap, vec2(x2+1.0, y1)).r + texture2D(LandscapeMap, vec2(x2, y1-1.0)).r + texture2D(LandscapeMap, vec2(x2+1.0, y1-1.0)).r);
//	float h12 = 0.25*(texture2D(LandscapeMap, vec2(x1, y2)).r + texture2D(LandscapeMap, vec2(x1-1.0, y2)).r + texture2D(LandscapeMap, vec2(x1, y2+1.0)).r + texture2D(LandscapeMap, vec2(x1-1.0, y2+1.0)).r);
//	float h22 = 0.25*(texture2D(LandscapeMap, vec2(x2, y2)).r + texture2D(LandscapeMap, vec2(x2+1.0, y2)).r + texture2D(LandscapeMap, vec2(x2, y2+1.0)).r + texture2D(LandscapeMap, vec2(x2+1.0, y2+1.0)).r);

//	float r = (1.0-dy)*( (1.0-dx)*h11 + dx*h21 ) +
//		 + dy*( (1.0-dx)*h12 + dx*h22 );
	float r = (1.0-dy)*( (1.0-dx)*texture2D(LandscapeMap, vec2(x1, y1)).r + dx*texture2D(LandscapeMap, vec2(x2, y1)).r ) +
		 + dy*( (1.0-dx)*texture2D(LandscapeMap, vec2(x1, y2)).r + dx*texture2D(LandscapeMap, vec2(x2, y2)).r );

	if (r <= WaterLevel) discard;

	TextureContrib = mix(vec4(0.0, 0.05, 0.4, 1.0), TextureContrib, smoothstep(WaterLevel, WaterLevel+0.002, r));

	vec4 DiffuseContrib = clamp(gl_LightSource[0].diffuse * dot(LightVector, Normal), 0.0, 1.0);
//	float dayfactor = pow(max(dot(LightVector, Normal), 0.0), 0.5);
	float dayfactor = max(min(0.5+dot(LightVector, Normal), 1.0), 0.0);
	vec4 AtmColor = FogColor;

	float h = CamHeight;

	float theta1 = 1.57-asin(PlanetRadius/CamHeight);
	float theta2 = 0.0;

	vec3 reflect_vec = reflect(CameraVector, -Normal);
	float Temp = dot(reflect_vec, LightVector);
//	float atmfog = smoothstep(cos(theta2), cos(theta1), dot(CamPosition, VPosition))*(1-1/(1+100.0*length(CamPosition-VPosition)));
	float atmfog = pow(smoothstep(cos(theta2), cos(theta1), dot(CamPosition, VPosition)), 2.0);
	vec4 SpecContrib = gl_LightSource[0].specular * clamp(pow(Temp, SpecPower), 0.0, 0.95);

	
//	gl_FragColor = 0.5*(1.0+dot(LightVector, Normal))*mix(AtmColor, TextureContrib * LightIntensity * (gl_LightSource[0].ambient + DiffuseContrib), 1-atmfog) + TextureContrib*0.1;
	gl_FragColor = mix(dayfactor*AtmColor, TextureContrib*0.3+(1-0.3)*TextureContrib * LightIntensity * (gl_LightSource[0].ambient + DiffuseContrib), (1-atmfog));
//	gl_FragColor = AtmColor;
}