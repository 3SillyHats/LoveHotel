#version 150
uniform mat4 projection_matrix;
uniform mat4 modelview_matrix;

attribute vec3 a_position;

void main(void) {
	gl_Position = projection_matrix * modelview_matrix * vec4(a_position, 1.0);
}
