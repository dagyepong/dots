#version 440

// album_glow.frag — SDF inner glow for the expanded album bg.
// Same SDF pattern as pill.frag, but the glow intensity is weighted toward
// the bottom of the frame so the bottom edge reads strongest.
//
// Compile with:
//   /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 \
//     -o album_glow.frag.qsb album_glow.frag

layout(location = 0) in  vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;

    vec2  iSize;
    float cornerRadius;
    vec4  glowColor;      // dominant album color
    float glowRadius;     // pixels from the edge inward
    float glowIntensity;  // 0..1 overall multiplier
    float topWeight;      // multiplier applied to the top edge (0..1)
} ubuf;

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void main() {
    vec2 uv  = qt_TexCoord0;
    vec2 pos = (uv - 0.5) * ubuf.iSize;

    vec2 halfSize = ubuf.iSize * 0.5;
    float d = sdRoundedBox(pos, halfSize, ubuf.cornerRadius);

    float pillAlpha = smoothstep(1.0, -1.0, d);
    if (pillAlpha < 0.001) discard;

    // Distance from the edge, inward (0 at edge, grows as we move inside)
    float innerDist = max(-d, 0.0);
    float glowT = smoothstep(ubuf.glowRadius, 0.0, innerDist) * ubuf.glowIntensity;

    // Vertical weight — top is dimmed, bottom is full intensity.
    // uv.y = 0 at top, 1 at bottom. mix(topWeight, 1.0, uv.y).
    float vWeight = mix(ubuf.topWeight, 1.0, uv.y);
    glowT *= vWeight;

    vec4 color = ubuf.glowColor * glowT;
    color = clamp(color, 0.0, 1.0);

    fragColor = color * pillAlpha * ubuf.qt_Opacity;
}
