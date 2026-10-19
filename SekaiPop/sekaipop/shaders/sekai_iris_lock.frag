#version 440

// Sekai iris, lockscreen edition: the same maths as sekai_iris.frag, but it
// takes ONE texture (the lockscreen picture, premultiplied) and outputs
// premultiplied ALPHA instead of blending two wallpapers, so the live
// desktop behind the overlay window shows through wherever it is
// transparent. Only LockRing.qml loads it (as `sekai_iris_lock`), picked by the
// wallpaper's transition style.
//
//   unlocking = 0   locking:   the desktop is the "old" side, the
//                   lockscreen is the "new" side
//   unlocking = 1   unlocking: the lockscreen is the "old" side, the
//                   desktop is the "new" side
//
// The four-disc onion drops through; the picture swaps at 50% while the outer disc covers every corner.
// Shares its uniform block with sekai_iris_lock.vert (mandatory, see
// shaders/README.md). Compile with shaders/compile-shaders.sh.

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
    int unlocking;         // 0 = locking (lockscreen inside / arriving), 1 = unlocking (lockscreen outside / leaving)
} ubuf;

layout(binding = 1) uniform sampler2D source1; // the lockscreen picture (premultiplied)

// Premultiplied "colour c at coverage a, over base".
vec4 over(vec3 c, float a, vec4 base) {
    a = clamp(a, 0.0, 1.0);
    return vec4(c * a + base.rgb * (1.0 - a), a + base.a * (1.0 - a));
}

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

    vec4 lockC = texture(source1, uv);
    bool leaving = ubuf.unlocking != 0;

    // Swap at the midpoint, hidden under the outer disc. Transparent = the live desktop.
    vec4 oldSide = leaving ? lockC : vec4(0.0);
    vec4 newSide = leaving ? vec4(0.0) : lockC;
    vec4 result = (p < 0.5) ? oldSide : newSide;

    result = over(ubuf.colorGreen.rgb, disc(uv, cyA, 1.036, aa), result);
    result = over(ubuf.colorPink.rgb,  disc(uv, cyB, 0.690, aa), result);
    result = over(ubuf.colorWhite.rgb, disc(uv, cyC, 0.446, aa), result);
    result = over(ubuf.colorGreen.rgb, disc(uv, cyD, 0.272, aa), result);

    fragColor = result * ubuf.qt_Opacity;
}
