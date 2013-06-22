#version 150

out vec4 fragColor;
void main(void) {
	if( gl_FrontFacing ) {
		fragColor = vec4(1.0f);
	}else{
		discard;
	}
}
