#version 440

// Phase 2 placeholder transition — a plain cross-dissolve. Standard
// Qt Quick ShaderEffect vertex boilerplate: nothing here actually
// varies per-pixel, so it just forwards texture coordinates. See
// fade.frag for the actual blend, and shaders/README.md before
// writing the Phase 3 Sekai shader — the uniform block layout below
// (qt_Matrix, qt_Opacity, then custom properties in QML declaration
// order) is not optional, it's how Qt binds ShaderEffect properties.

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress; // unused here, kept so both stages share one layout
} ubuf;

out gl_PerVertex { vec4 gl_Position; };

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = ubuf.qt_Matrix * qt_Vertex;
}
