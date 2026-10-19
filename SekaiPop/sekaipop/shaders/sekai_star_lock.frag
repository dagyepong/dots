#version 440

// Sekai star, lockscreen edition: the same maths as sekai_star.frag, but it
// takes ONE texture (the lockscreen picture, premultiplied) and outputs
// premultiplied ALPHA instead of blending two wallpapers, so the live
// desktop behind the overlay window shows through wherever it is
// transparent. Only LockRing.qml loads it (as `sekai_star_lock`), picked by the
// wallpaper's transition style.
//
//   unlocking = 0   locking:   the desktop is the "old" side, the
//                   lockscreen is the "new" side
//   unlocking = 1   unlocking: the lockscreen is the "old" side, the
//                   desktop is the "new" side
//
// The four-point sparkle opens the lockscreen (locking) or the desktop (unlocking).
// Shares its uniform block with sekai_star_lock.vert (mandatory, see
// shaders/README.md). Compile with shaders/compile-shaders.sh.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;        // 0..1, driven Linear from QML
    float aspect;          // width / height, keeps the star's proportions
    float thickness;       // delay between one band's edge and the next, share of the transition (0.2; kept >= 1/6 so the screen is fully covered)
    float pointLength;     // tip reach relative to the body: 2 = astroid, 3 = long, 4+ = needles
    float curvature;       // extra hollowing of the concave sides, 1.0 = default
    float colorIntensity;  // 0 = no bands, 1 = normal, >1 = more saturated colours
    float elastic;         // stretch/contract of the points, 1.0 = default, 0 = none
    float spin;            // turns the star makes over the whole transition, clockwise (0.5 = half a turn, 0 = no spin)
    vec2 center;           // origin in uv, (0.5, 0.5) = middle
    vec4 colorWhite;
    vec4 colorCyan;
    vec4 colorPink;
    int unlocking;         // 0 = locking (lockscreen inside / arriving), 1 = unlocking (lockscreen outside / leaving)
} ubuf;

layout(binding = 1) uniform sampler2D source1; // the lockscreen picture (premultiplied)

// Premultiplied "colour c at coverage a, over base".
vec4 over(vec3 c, float a, vec4 base) {
    a = clamp(a, 0.0, 1.0);
    return vec4(c * a + base.rgb * (1.0 - a), a + base.a * (1.0 - a));
}

const float AA = 0.0022;        // edge softness, in screen heights (~2px at 1080p)
const float GRAD_EPS = 0.002;   // keeps the edge-width estimate finite right on the axes
const float MARGIN = 0.02;      // extra travel so the last band is clear of the corner

// One easing for every edge: a gentle ease in and out, so each edge picks up
// speed smoothly, never stops dead and settles as it leaves.
float easeEdge(float q) {
    float s = q * q * (3.0 - 2.0 * q);
    return mix(q, s, 0.6);
}

// Exponent n from the wanted tip:waist ratio. Solving the star's own
// geometry for n gives 1/n = 0.5 + log2(ratio); `curvature` scales that,
// so >1 hollows the sides out further (longer, thinner points).
float starExponent(float pl, float curv) {
    float n = 1.0 / ((0.5 + log2(max(pl, 1.05))) * max(curv, 0.2));
    return clamp(n, 0.25, 0.98);
}

// Waist reach per unit of tip reach.
float waistPerTip(float n) {
    return 1.41421356 * exp2(-1.0 / n);
}

// F(q), plus the size of its gradient. The gradient is only used to turn
// "F minus level" into a distance in screen heights, for antialiasing.
float starF(vec2 q, float n, out float grad) {
    vec2 a  = max(abs(q), vec2(1e-5));
    vec2 pw = pow(a, vec2(n));
    float S = pw.x + pw.y;
    float F = pow(S, 1.0 / n);
    grad = length((F / S) * pw / max(a, vec2(GRAD_EPS)));
    return F;
}

// Antialiased "inside the star of reach f" in 0..1.
float inside(float F, float f, float grad) {
    return 1.0 - smoothstep(-AA, AA, (F - f) / grad);
}

vec3 boost(vec3 c, float v) {
    float l = dot(c, vec3(0.299, 0.587, 0.114));
    return clamp(mix(vec3(l), c, 1.0 + 0.7 * v), 0.0, 1.0);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float p = clamp(ubuf.progress, 0.0, 1.0);
    vec4 lockC = texture(source1, uv);
    bool leaving = ubuf.unlocking != 0;

    // Ends of the transition, no maths. Locking starts as pure desktop and
    // ends as the full lockscreen; unlocking is the other way round.
    if (p <= 0.0) {
        fragColor = (leaving ? lockC : vec4(0.0)) * ubuf.qt_Opacity;
        return;
    }
    if (p >= 1.0) {
        fragColor = (leaving ? vec4(0.0) : lockC) * ubuf.qt_Opacity;
        return;
    }

    vec3 white = ubuf.colorWhite.rgb;
    vec3 cyan  = ubuf.colorCyan.rgb;
    vec3 pink  = ubuf.colorPink.rgb;

    // ===== geometry =====
    vec2 asp = vec2(ubuf.aspect, 1.0);
    vec2 q = (uv - ubuf.center) * asp;

    // ===== spin =====
    // The whole star turns clockwise about `center`: fast while it grows, then
    // slowing as the new picture opens (the angle eases out). The star looks
    // the same every quarter turn, so even a small `spin` is easy to see.
    float turn = 6.28318531 * ubuf.spin * (1.0 - (1.0 - p) * (1.0 - p));
    float cs = cos(turn);
    float sn = sin(turn);
    q = vec2(cs * q.x + sn * q.y, -sn * q.x + cs * q.y);

    // ===== final size =====
    // The star shape settles by p = 0.4 (grow below). The star is spinning, so
    // the farthest corner can end up anywhere relative to its points; its
    // weakest direction is the diagonal (the waist), so the reach is the one
    // that holds the corner there, with a little spare for the early wobble's
    // last ripples. That holds every point of the screen at any angle.
    float nEnd = starExponent(ubuf.pointLength, ubuf.curvature);
    vec2 farV = max(abs(ubuf.center), abs(1.0 - ubuf.center)) * asp;
    float Fend = exp2(1.0 / nEnd) * length(farV) * 0.70710678 * 1.05 + MARGIN;

    // ===== shape motion =====
    float wob  = ubuf.elastic * exp(-5.5 * p) * sin(17.0 * p) * smoothstep(0.0, 0.06, p);
    float grow = mix(0.62, 1.0, smoothstep(0.0, 0.4, p));
    float pl   = ubuf.pointLength * grow * (1.0 + 0.15 * wob);

    float n = starExponent(pl, ubuf.curvature);

    // ===== where the four edges are =====
    // Four nested stars, outside in: old | pink | white | cyan | new.
    // Edge 0 (old | pink) grows first and passes the corners, so the old
    // wallpaper is buried under colour. Edges 1 and 2 follow it, each `lag`
    // later. Edge 3 (cyan | new) only starts once the screen is covered, and
    // it opens the new wallpaper in the middle. With lag >= 1/6, edge 0 has
    // passed the corners before edge 3 has started.
    float lag  = clamp(ubuf.thickness, 0.17, 0.3);
    float span = 1.0 - 3.0 * lag;

    float f0 = Fend * easeEdge(clamp( p              / span, 0.0, 1.0));
    float f1 = Fend * easeEdge(clamp((p - lag)       / span, 0.0, 1.0));
    float f2 = Fend * easeEdge(clamp((p - 2.0 * lag) / span, 0.0, 1.0));
    float f3 = Fend * easeEdge(clamp((p - 3.0 * lag) / span, 0.0, 1.0));

    float g;
    float F = starF(q, n, g);

    float c0 = inside(F, f0, g);
    float c1 = inside(F, f1, g);
    float c2 = inside(F, f2, g);
    float c3 = inside(F, f3, g);

    // ===== colours =====
    float ci   = ubuf.colorIntensity;
    float k    = clamp(ci, 0.0, 1.0);               // opacity of the bands
    float vivid = clamp(ci - 1.0, 0.0, 1.0);        // >1: stronger colours, not glow
    pink  = boost(pink,  vivid);
    cyan  = boost(cyan,  vivid);

    // The picture under the colour changes from old to new while the screen
    // is covered (p = span .. 3 lag, 0.4 .. 0.6 by default). At full band
    // opacity nothing of it shows then; below that the change is a soft fade.
    float sw = smoothstep(span, 3.0 * lag, p);

    vec4 newSide = leaving ? vec4(0.0) : lockC;
    vec4 oldSide = leaving ? lockC : vec4(0.0);
    vec4 base = mix(oldSide, newSide, sw);

    // ===== the bands =====
    vec4 col = base;
    col = over(pink,  c0 * k, col);
    col = over(white, c1 * k, col);
    col = over(cyan,  c2 * k, col);
    // Open the inner side in the middle.
    col = mix(col, newSide, c3);

    fragColor = col * ubuf.qt_Opacity;
}
