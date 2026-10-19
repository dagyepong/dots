#version 440

// ===== How it works =====
//
// A staircase wipe that COVERS the whole screen, then reveals the new picture.
//
// The screen is cut into a few horizontal rows (steps), each set back a little
// from the one below it, so every edge below makes a staircase. Four edges
// sweep sideways across the screen, one after another:
//
//     new wallpaper | WHITE | CYAN | PINK | old wallpaper
//          edge 3        edge 2   edge 1   edge 0
//
// Edge 0 (old | pink) goes first and runs all the way across, so the old
// wallpaper is buried under colour. Edges 1 and 2 follow it, each starting a
// little later (`bandThickness` is that delay, as a share of the whole
// transition). Edge 3 (white | new) only starts once the screen is covered,
// and it uncovers the new wallpaper behind it. The bands stretch as they cross
// and squeeze again as they leave, so there are always the three colours.
//
// While the screen is fully covered (about p = 0.4 .. 0.6 at the default) the
// picture underneath is swapped; nothing of either wallpaper shows then.
//
// The three colours are colorWhite / colorCyan / colorPink; blockSize is the
// height of a step (0.34 = 3 steps), stagger how far each step is set back,
// direction which way it goes.

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
} ubuf;

layout(binding = 1) uniform sampler2D source1; // outgoing wallpaper
layout(binding = 2) uniform sampler2D source2; // incoming wallpaper

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

    // Ends of the transition: plain wallpaper, no maths, one read.
    if (p <= 0.0) {
        fragColor = texture(source1, uv) * ubuf.qt_Opacity;
        return;
    }
    if (p >= 1.0) {
        fragColor = texture(source2, uv) * ubuf.qt_Opacity;
        return;
    }

    vec3 white = ubuf.colorWhite.rgb;
    vec3 cyan  = ubuf.colorCyan.rgb;
    vec3 pink  = ubuf.colorPink.rgb;

    // ===== the staircase =====
    // The wipe runs sideways (to the left for a negative direction.x) and the
    // screen is cut into horizontal rows. Each row is one step: its edges sit
    // `stepW` further back than the row before it. Inside a row the bands are
    // plain vertical cuts, so each step shows flat horizontal bars.
    float u = min(1.0, ubuf.aspect);
    float sx = ubuf.direction.x > 0.01 ? 1.0 : -1.0;
    float sy = ubuf.direction.y > 0.01 ? 1.0 : (ubuf.direction.y < -0.01 ? -1.0 : 0.0);

    float rowH = max(ubuf.blockSize * u, 0.05);
    float rows = max(1.0, floor(1.0 / rowH + 0.5));
    float row = min(floor(uv.y * rows), rows - 1.0);
    // 0 for the row the wipe starts in, rows-1 for the last one.
    float rr = sy > 0.0 ? row : (sy < 0.0 ? rows - 1.0 - row : 0.0);

    float stepW = max(ubuf.stagger, 0.0) * STEP_BACK * u;

    // Distance travelled from the starting side, in screen heights, plus the
    // row's set-back: the same number is the edges' position for the row.
    float xs = sx > 0.0 ? uv.x * ubuf.aspect : (1.0 - uv.x) * ubuf.aspect;
    float xb = xs + rr * stepW;

    // ===== where the four edges are =====
    // Each edge starts just clear of the screen and ends just past the last
    // step. Edge i starts i * lag later than edge 0, and each one takes `span`
    // of the transition to cross. With lag >= 1/6, edge 0 has left the screen
    // before edge 3 has started, so for a while the screen is fully covered.
    float lag = clamp(ubuf.bandThickness, 0.17, 0.3);
    float span = 1.0 - 3.0 * lag;
    float Xend = ubuf.aspect + (rows - 1.0) * stepW + 2.0 * AA;

    float f0 = Xend * easeEdge(clamp( p              / span, 0.0, 1.0)) - AA;  // old  | pink
    float f1 = Xend * easeEdge(clamp((p - lag)       / span, 0.0, 1.0)) - AA;  // pink | cyan
    float f2 = Xend * easeEdge(clamp((p - 2.0 * lag) / span, 0.0, 1.0)) - AA;  // cyan | white
    float f3 = Xend * easeEdge(clamp((p - 3.0 * lag) / span, 0.0, 1.0)) - AA;  // white | new

    // Whichever wallpaper is under the colour: the old one until the screen
    // is covered, the new one after. The swap happens under full cover.
    vec3 rgb = (p < 0.5) ? texture(source1, uv).rgb : texture(source2, uv).rgb;
    rgb = mix(rgb, pink,  1.0 - smoothstep(f0 - AA, f0 + AA, xb));
    rgb = mix(rgb, cyan,  1.0 - smoothstep(f1 - AA, f1 + AA, xb));
    rgb = mix(rgb, white, 1.0 - smoothstep(f2 - AA, f2 + AA, xb));
    rgb = mix(rgb, texture(source2, uv).rgb, 1.0 - smoothstep(f3 - AA, f3 + AA, xb));

    fragColor = vec4(rgb, 1.0) * ubuf.qt_Opacity;
}
