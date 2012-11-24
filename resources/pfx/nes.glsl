/*
    Scanline shader 
    Author: Themaister (Modified by Saxon Douglass)
    This code is hereby placed in the public domain.
*/

// the current texture size (same as input if fullscreen)
uniform vec2 rubyTextureSize;
// the current input size (eg. 320x240)
uniform vec2 rubyInputSize;
// the output size (eg. x2, so 640x480)
uniform vec2 rubyOutputSize;

const float base_brightness = .95;
const vec2 sine_comp = vec2(0.05, 0.15);

vec4 effect(vec4 color, sampler2D texture,
    vec2 texture_coords, vec2 screen_coords)
{
    vec2 omega = vec2(3.1415 * rubyOutputSize.x * rubyTextureSize.x / rubyInputSize.x, 2.0 * 3.1415 * rubyTextureSize.y);
    
    vec4 c11 = texture2D(texture, texture_coords.xy);

    vec4 scanline = c11 * (base_brightness + dot(sine_comp * sin(texture_coords.xy * omega), vec2(1.0)));
    return clamp(scanline, 0.0, 1.0);
}
