#version 440

// Phase 2 placeholder transition — a plain cross-dissolve between the
// outgoing (source1) and incoming (source2) wallpaper, driven by
// `progress` (0 = fully source1, 1 = fully source2). This exists to
// prove the WallpaperService -> WallpaperLayer -> ShaderEffect wiring
// end-to-end before Phase 3 replaces it with the real Sekai
// diamond-wipe / rhythm-sweep shape. Swapping shaders later is a
// one-line change in WallpaperLayer.qml's ShaderEffect
// (fragmentShader/vertexShader) plus a new pair of source files here
// — this file's uniform layout is the template to copy.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
} ubuf;

layout(binding = 1) uniform sampler2D source1; // outgoing wallpaper
layout(binding = 2) uniform sampler2D source2; // incoming wallpaper

void main() {
    vec4 fromColor = texture(source1, qt_TexCoord0);
    vec4 toColor = texture(source2, qt_TexCoord0);
    fragColor = mix(fromColor, toColor, clamp(ubuf.progress, 0.0, 1.0)) * ubuf.qt_Opacity;
}
