#version 440

// Sekai iris — "onion" layer drop-through.
//
// Rebuilt from a frame-by-frame measurement of the reference clip's
// target transition (30fps, every ring's edges tracked). What it does:
//
//   * FOUR nested discs, sizes fixed (in screen-height units):
//       outer 1.036, then 0.690, 0.446, 0.272 — the outer one is just
//       big enough to cover the whole screen when centred, the rest
//       are the visible rings of the onion.
//   * they drop in from above one after another, NOT together: each
//     inner disc starts later than the one outside it, so while they
//     fall you see eccentric crescents of every layer, then they all
//     settle onto the same centre (the bullseye) at about the same
//     moment (~50% of the transition).
//   * they leave the same way in reverse order of size: the INNERMOST
//     disc drops out first, then the next, and the outer disc leaves
//     last, peeling the onion away downward and revealing the new
//     wallpaper above it.
//   * entry uses ease-out (fast then settling), exit uses ease-in
//     (slow then dropping away); the outer disc uses ease-in-out both
//     ways since it's the big slow-moving one.
//
// Layer colours, outside in: green, pink, white, green (three colours,
// four layers — swap the four `layerColor` picks in main() to taste).
//
// The wallpaper swaps at progress 0.5, when the outer disc is centred
// and covering every corner, so the cut is hidden.
//
// All the timing below is fractions of progress, taken from the clip's
// 1.6s span (progress 0 = clip 1.40s, progress 1 = clip 3.00s).
// WallpaperLayer.qml forces `duration: 2000` + Linear for sekaiIris,
// so the clip is played back ~1.25x slower than the original.
//
// Shares its uniform block with sekai_iris.vert (mandatory for a
// ShaderEffect pair, see shaders/README.md).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;    // 0..1, overall transition position
    float aspect;       // width / height, for true (unsquashed) discs
    vec4 colorWhite;
    vec4 colorPink;
    vec4 colorGreen;
} ubuf;

layout(binding = 1) uniform sampler2D source1; // outgoing wallpaper
layout(binding = 2) uniform sampler2D source2; // incoming wallpaper

float easeOutQuad(float s)   { return 1.0 - (1.0 - s) * (1.0 - s); }
float easeInQuad(float s)    { return s * s; }
float easeInOutQuad(float s) { return s < 0.5 ? 2.0 * s * s : 1.0 - 2.0 * (1.0 - s) * (1.0 - s); }
float easeInOutCubic(float s) {
    return s < 0.5 ? 4.0 * s * s * s : 1.0 - 4.0 * (1.0 - s) * (1.0 - s) * (1.0 - s);
}

float span(float p, float a, float b) {
    return clamp((p - a) / (b - a), 0.0, 1.0);
}

// 1 inside the disc, 0 outside (antialiased edge).
float disc(vec2 uv, float cy, float R, float aa) {
    vec2 q = vec2((uv.x - 0.5) * ubuf.aspect, uv.y - cy);
    return 1.0 - smoothstep(R - aa, R + aa, length(q));
}

void main() {
    vec2 uv = qt_TexCoord0;
    float p = clamp(ubuf.progress, 0.0, 1.0);
    float aa = 0.003;

    // centre-y of each disc (uv units, 0 = top of screen, 0.5 = centred)
    float cyA, cyB, cyC, cyD;

    // A — outer, radius 1.036. Slow in, slow out.
    if (p < 0.625) cyA = mix(-1.05, 0.5, easeInOutQuad(span(p, 0.0, 0.34375)));
    else           cyA = mix(0.5, 2.06, easeInOutCubic(span(p, 0.625, 1.0)));

    // B — radius 0.690.
    if (p < 0.5) cyB = mix(-0.71, 0.5, easeOutQuad(span(p, 0.1125, 0.40625)));
    else         cyB = mix(0.5, 1.76, easeInQuad(span(p, 0.5, 0.83125)));

    // C — radius 0.446.
    if (p < 0.5) cyC = mix(-0.47, 0.5, easeOutQuad(span(p, 0.15625, 0.45625)));
    else         cyC = mix(0.5, 1.52, easeInQuad(span(p, 0.5, 0.81875)));

    // D — inner, radius 0.272. Arrives last, leaves first.
    if (p < 0.5) cyD = mix(-0.29, 0.5, easeOutQuad(span(p, 0.2, 0.5)));
    else         cyD = mix(0.5, 1.32, easeInQuad(span(p, 0.5, 0.8)));

    vec4 result = (p < 0.5) ? texture(source1, uv) : texture(source2, uv);

    vec4 layerColorA = vec4(ubuf.colorGreen.rgb, 1.0);
    vec4 layerColorB = vec4(ubuf.colorPink.rgb, 1.0);
    vec4 layerColorC = vec4(ubuf.colorWhite.rgb, 1.0);
    vec4 layerColorD = vec4(ubuf.colorGreen.rgb, 1.0);

    result = mix(result, layerColorA, disc(uv, cyA, 1.036, aa));
    result = mix(result, layerColorB, disc(uv, cyB, 0.690, aa));
    result = mix(result, layerColorC, disc(uv, cyC, 0.446, aa));
    result = mix(result, layerColorD, disc(uv, cyD, 0.272, aa));

    fragColor = result * ubuf.qt_Opacity;
}
