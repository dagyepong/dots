#version 440

// Sekai flash — fade to a solid colour and back. Shares its uniform
// block with sekai_flash_lock.frag (mandatory for a ShaderEffect pair —
// see shaders/README.md); this stage doesn't use any of the custom
// members, it just forwards texture coordinates.

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec4 accentColor;
    int unlocking;
} ubuf;

out gl_PerVertex { vec4 gl_Position; };

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = ubuf.qt_Matrix * qt_Vertex;
}
