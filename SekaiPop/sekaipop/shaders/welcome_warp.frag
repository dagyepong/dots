#version 440

// Fragment half of the wave pass (see welcome_warp.vert): the picture of the
// logo, plus a light sweep. The sweep is a hard bright band with a soft glow
// round it, slanted, crossing the picture from left to right; it only lights
// what is there (its strength follows the picture's alpha), so it reads as the
// light moving over the letters and their stroke, not as a stripe on the page.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float amount;
    float phase;
    float freq;
    float sweep;
    float sweepWidth;
    float sweepStrength;
    vec2 size;
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 c = texture(source, qt_TexCoord0);

    vec2 dir = normalize(vec2(0.92, 0.38));
    float m = dot(qt_TexCoord0 * ubuf.size, dir) / dot(ubuf.size, dir);
    float d = m - ubuf.sweep;
    float w = max(ubuf.sweepWidth, 0.001);
    float core = 1.0 - smoothstep(w * 0.42, w * 0.5, abs(d));
    float glow = exp(-(d * d) / (w * w * 4.0));
    float k = clamp((core * 0.40 + glow * 0.24) * ubuf.sweepStrength, 0.0, 1.0);

    // toward white in proportion to alpha (the texture is premultiplied)
    vec3 rgb = c.rgb + (vec3(c.a) - c.rgb) * k;
    fragColor = vec4(rgb, c.a) * ubuf.qt_Opacity;
}
