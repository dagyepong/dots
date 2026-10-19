#version 440

// The wave pass over the whole SekaiPop logo (WelcomeLogo.qml): the logo is
// drawn into a texture and shown on a fine grid, and this shader moves the
// grid's points with a travelling sine, so the assembled word ripples like
// elastic. Strength 0 draws it exactly as it is. The fragment shader of the
// pair adds the light sweep. Both declare the same uniform block.

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

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

out gl_PerVertex { vec4 gl_Position; };

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    vec4 v = qt_Vertex;
    float a = ubuf.amount;
    float w = sin(v.x * ubuf.freq - ubuf.phase);
    // mostly up and down, a little sideways: the word stretches as the wave goes by
    v.y += a * w;
    v.x += a * 0.3 * sin(v.y * ubuf.freq * 0.8 - ubuf.phase * 0.7 + 1.3);
    gl_Position = ubuf.qt_Matrix * v;
}
