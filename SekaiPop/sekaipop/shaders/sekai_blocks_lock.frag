#version 440

// Sekai staircase blocks, lockscreen edition: the same maths as sekai_blocks.frag, but it
// takes ONE texture (the lockscreen picture, premultiplied) and outputs
// premultiplied ALPHA instead of blending two wallpapers, so the live
// desktop behind the overlay window shows through wherever it is
// transparent. Only LockRing.qml loads it (as `sekai_blocks_lock`), picked by the
// wallpaper's transition style.
//
//   unlocking = 0   locking:   the desktop is the "old" side, the
//                   lockscreen is the "new" side
//   unlocking = 1   unlocking: the lockscreen is the "old" side, the
//                   desktop is the "new" side
//
// The staircase covers the whole screen in colour, then uncovers the lockscreen
// (locking) or the desktop (unlocking), exactly like the wallpaper version.
// Shares its uniform block with sekai_blocks_lock.vert (mandatory, see
// shaders/README.md). Compile with shaders/compile-shaders.sh.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;        // 0..1, driven Linear from QML
    float aspect;          // width / height
    float bandThickness;   // delay between one band's edge and the next, share of the transition (0.2; kept >= 1/6 so the screen is fully covered)
    float blockSize;       // height of one step (one row), in screen heights (~0.34 = 3 steps)
    float stagger;         // how far each step is set back (1 = default, 0 = no stairs, one straight wipe)
    vec2 direction;        // only its signs count: x < 0 wipes to the left, y < 0 starts at the bottom, e.g. (-1, -1)
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

const float AA = 0.0022;   // edge softness, in screen heights (~2px at 1080p)

// How far one step is set back at stagger = 1, in screen heights.
const float STEP_BACK = 0.28;

// One easing for every edge: a gentle ease in and out, so each edge picks up
// speed smoothly, never stops dead and settles as it leaves.
float easeEdge(float q) {
    float s = q * q * (3.0 - 2.0 * q);
    return mix(q, s, 0.6);
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

    // ===== the staircase =====
    // The wipe runs sideways (to the left for a negative direction.x) and the
    // screen is cut into horizontal rows. Each row is one step: its edges sit
    // `stepW` further back than the row before it.
    float u = min(1.0, ubuf.aspect);
    float sx = ubuf.direction.x > 0.01 ? 1.0 : -1.0;
    float sy = ubuf.direction.y > 0.01 ? 1.0 : (ubuf.direction.y < -0.01 ? -1.0 : 0.0);

    float rowH = max(ubuf.blockSize * u, 0.05);
    float rows = max(1.0, floor(1.0 / rowH + 0.5));
    float row = min(floor(uv.y * rows), rows - 1.0);
    // 0 for the row the wipe starts in, rows-1 for the last one.
    float rr = sy > 0.0 ? row : (sy < 0.0 ? rows - 1.0 - row : 0.0);

    float stepW = max(ubuf.stagger, 0.0) * STEP_BACK * u;

    float xs = sx > 0.0 ? uv.x * ubuf.aspect : (1.0 - uv.x) * ubuf.aspect;
    float xb = xs + rr * stepW;

    // ===== where the four edges are =====
    // Edge 0 (old | pink) crosses first and buries the old picture, edges 1
    // and 2 follow it, edge 3 (white | new) only starts once the screen is
    // covered. Same timing as sekai_blocks.frag.
    float lag = clamp(ubuf.bandThickness, 0.17, 0.3);
    float span = 1.0 - 3.0 * lag;
    float Xend = ubuf.aspect + (rows - 1.0) * stepW + 2.0 * AA;

    float f0 = Xend * easeEdge(clamp( p              / span, 0.0, 1.0)) - AA;  // old  | pink
    float f1 = Xend * easeEdge(clamp((p - lag)       / span, 0.0, 1.0)) - AA;  // pink | cyan
    float f2 = Xend * easeEdge(clamp((p - 2.0 * lag) / span, 0.0, 1.0)) - AA;  // cyan | white
    float f3 = Xend * easeEdge(clamp((p - 3.0 * lag) / span, 0.0, 1.0)) - AA;  // white | new

    vec4 newSide = leaving ? vec4(0.0) : lockC;
    vec4 oldSide = leaving ? lockC : vec4(0.0);

    // The colours are opaque and cover everything between the two halves, so
    // the sides never need swapping.
    vec4 col = oldSide;
    col = over(pink,  1.0 - smoothstep(f0 - AA, f0 + AA, xb), col);
    col = over(cyan,  1.0 - smoothstep(f1 - AA, f1 + AA, xb), col);
    col = over(white, 1.0 - smoothstep(f2 - AA, f2 + AA, xb), col);
    col = mix(col, newSide, 1.0 - smoothstep(f3 - AA, f3 + AA, xb));

    fragColor = col * ubuf.qt_Opacity;
}
