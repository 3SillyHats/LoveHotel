#version 150
void main(void) {
	if( gl_FrontFacing ) {
		gl_FragColor = vec4(1.0f);
	}else{
		discard;
	}
}
