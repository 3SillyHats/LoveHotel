#version 330
uniform mat4 projection_matrix;
uniform mat4 modelview_matrix;

in vec3 a_position;
void main() {
	gl_Position = projection_matrix * modelview_matrix * vec4(a_position, 1.0f);
}
