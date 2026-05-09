#version 440

// pill.frag — SDF fill + inner glow for the clock pill
// Compile with:
//   /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 \
//     -o pill.frag.qsb pill.frag

layout(location = 0) in  vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;

    vec2  iSize;
    float cornerRadius;

    vec4  fillColor1;      // premultiplied
    vec4  fillColor2;      // premultiplied

    vec4  glowAmber;       // premultiplied
    vec4  glowWhite;       // premultiplied
    float glowRadius;      // pixels
    float glowIntensity;   // 0..1, animates hover in/out
} ubuf;

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void main() {
    vec2 uv  = qt_TexCoord0;
    vec2 pos = (uv - 0.5) * ubuf.iSize;

    vec2 halfSize = ubuf.iSize * 0.5;
    float r = ubuf.cornerRadius;

    float d = sdRoundedBox(pos, halfSize, r);

    float pillAlpha = smoothstep(1.0, -1.0, d);
    if (pillAlpha < 0.001) discard;

    // Fill gradient — diagonal, matching the original 0.768/0.027 → 0.646/1.164
    // direction vector in UV space (dx=-0.122, dy=1.137, len≈1.144).
    vec2 gDir = vec2(-0.122, 1.137) / 1.144;
    float t0  = dot(vec2(0.768, 0.027), gDir);
    float t1  = dot(vec2(0.646, 1.164), gDir);
    float t   = clamp((dot(uv, gDir) - t0) / (t1 - t0), 0.0, 1.0);
    vec4 fill = mix(ubuf.fillColor1, ubuf.fillColor2, t);

    // Inner glow — distance in pixels from the edge, inward
    float innerDist = max(-d, 0.0);

    float amberT  = smoothstep(ubuf.glowRadius, 0.0, innerDist) * ubuf.glowIntensity;
    vec4  amberGlow = ubuf.glowAmber * amberT;

    float whiteT  = smoothstep(ubuf.glowRadius * 0.65, 0.0, innerDist) * ubuf.glowIntensity;
    vec4  whiteGlow = ubuf.glowWhite * whiteT;

    // Composite — all premultiplied, additive
    vec4 color = fill;
    color.rgb += amberGlow.rgb;
    color.a    = max(color.a, amberGlow.a);
    color.rgb += whiteGlow.rgb;
    color.a    = max(color.a, whiteGlow.a);

    color = clamp(color, 0.0, 1.0);

    fragColor = color * pillAlpha * ubuf.qt_Opacity;
}
