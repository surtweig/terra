uniform float LightIntensity;
uniform float SpecPower;
uniform float PlanetRadius;
uniform float AtmosphereRadius;
uniform float CamHeight;
uniform vec3 CamPosition;
uniform vec4 LowColor;
uniform vec4 HighColor;
uniform vec4 DuskColor;
uniform float DensityFactor;

varying vec3 Normal;
varying vec3 LightVector;
varying vec3 CameraVector;
varying vec3 VNormal; 

void main(void) {

	vec4 AtmColor = LowColor;
	vec4 AtmColor2 = HighColor;

	vec3 reflect_vec = reflect(CameraVector, Normal);
	float Temp = dot(reflect_vec, LightVector);
	float camnorm = dot(CamPosition, VNormal);
//	float dayfactor = pow(0.5*(1+dot(Normal, LightVector)), 2.0);
	float dayfactor = min(max(dot(Normal, LightVector), 0.0), 1.0);
	vec4 SpecContrib = gl_LightSource[0].specular * clamp(pow(Temp, SpecPower), 0.0, 0.95);

	vec4 color1 = AtmColor;
	vec4 color2 = AtmColor2;

	float h = CamHeight;

	float theta1 = asin(PlanetRadius/h) + asin(PlanetRadius/AtmosphereRadius);
	float theta2 = radians(180.0);
	if (h > AtmosphereRadius) theta2 = asin(AtmosphereRadius/h) + radians(90.0);

	if (camnorm > (cos(theta1)+0.01)) discard;	

	color1 = mix(color1, color2, max(min(0.5*(h-AtmosphereRadius)/AtmosphereRadius, 0.5), 0.0));
	color1.a = 1.0;

	gl_FragColor = mix(color2, color1, pow(smoothstep(cos(theta2), cos(theta1), camnorm), 7.0))*(1-dayfactor);
	//gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0)*(1-pow(dayfactor, 0.2));

	//if (h < AtmosphereRadius) gl_FragColor.a = mix(gl_FragColor.a, 0.5*(1+dot(CamPosition, -VNormal))*(1-dayfactor), pow(1-(h-PlanetRadius)/(AtmosphereRadius-PlanetRadius), 4.0));
	if (h < AtmosphereRadius) gl_FragColor.a = (1-dayfactor)*mix(gl_FragColor.a, (1-dayfactor), pow(1-(h-PlanetRadius)/(AtmosphereRadius-PlanetRadius), 1.0));
}