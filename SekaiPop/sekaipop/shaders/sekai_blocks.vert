#version 440

// Vertex stage for sekai_blocks.frag. Does nothing special — the uniform
// block below MUST stay identical (same members, same order) to the one
// in sekai_blocks.frag, even though only qt_Matrix is used here. See
// shaders/README.md, "Uniform layout".

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float aspect;
    float bandThickness;
    float blockSize;
    float stagger;
    vec2 direction;
    vec4 colorWhite;
    vec4 colorCyan;
    vec4 colorPink;
} ubuf;

out gl_PerVertex {
    vec4 gl_Position;
};

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = ubuf.qt_Matrix * qt_Vertex;
}
