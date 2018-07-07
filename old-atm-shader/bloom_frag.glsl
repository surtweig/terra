uniform float LightIntensity;
uniform float SpecPower;
uniform sampler2D MainTexture;
uniform int FilterRadius;
uniform float InvFilterSquare;
uniform float ScreenWidth;
uniform float ScreenHeight;


void main(void) {

	float x;
	float y;
	vec4 tex;

	for (int i = -4; i <= 4; i++) {
		for (int j = -4; j <= 4; j++) {

			x = i*i;
			y = j*j;
			tex = texture2D(MainTexture, vec2(gl_TexCoord[0].x + i/ScreenWidth, gl_TexCoord[0].y + j/ScreenHeight)); 
			gl_FragColor = gl_FragColor + pow(1-min(1.0, (x+y)/49.0), 2.0)*tex;
			//gl_FragColor = gl_FragColor + pow((1-x/49.0), 100.0)*tex;
			//gl_FragColor = gl_FragColor + pow((1-y/49.0), 100.0)*tex;
		}
	}

	gl_FragColor = gl_FragColor * InvFilterSquare;
}