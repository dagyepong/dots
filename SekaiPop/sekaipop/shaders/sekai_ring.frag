#version 440

// Sekai ring — an expanding 2D "emblem ring" wallpaper transition.
//
// Not a plain circle wipe: a solid, layered ring of colour travels
// outward from `center`. The OLD wallpaper stays outside the ring, the
// NEW wallpaper appears inside it, and the ring itself covers the seam.
//
// Ring layout, from the inner edge (next to the new wallpaper) to the
// leading outer edge (next to the old one):
//
//     new wallpaper | CYAN | PINK | WHITE | old wallpaper
//
//   * Only three colours are ever used: white, cyan, pink (plus tints
//     of them toward white). Nothing else.
//   * The cyan/pink and pink/white borders are wavy, and the waves
//     travel around the ring, so the bands flow along the edge instead
//     of sitting still like concentric circles.
//   * The white band flares wide early on (the "flash" on the leading
//     edge), then relaxes to a thin bright rim.
//   * The outer and inner edges wobble with slow angular waves, out of
//     step with each other, so the ring's thickness breathes a little.
//     Whole-number harmonics only, so it is seamless all the way round
//     and never looks like noise.
//   * At the start the ring is squeezed into a filled bullseye (cyan
//     middle, pink, white rim). The hole opens once the radius passes
//     the ring width.
//
// Easing is done in here (fast start, gentle slow-down at the end), so
// WallpaperLayer.qml drives `progress` Linear. At progress 0 the old
// wallpaper is returned untouched; at progress 1 the new one is, and
// the ring has already left the screen by then, so there is no seam.
//
// transitionStyle:
//   0  ring   — the default described above
//   1  petal  — 6-lobed edge, like a rotating flower emblem
//   2  echo   — ring + two thin trailing rings over the new wallpaper
//   3  swirl  — the colour bands twist into spiral arms
//
// Cost: two texture reads and one atan(), no loops, no derivatives.
// Shares its uniform block with sekai_ring.vert (mandatory, see
// shaders/README.md).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;        // 0..1, driven Linear from QML
    float aspect;          // width / height, keeps the ring round
    int transitionStyle;   // 0 ring, 1 petal, 2 echo, 3 swirl
    float distortion;      // edge wobble strength, 1.0 = default, 0 = none
    float colorIntensity;  // 0 = no bands, 1 = normal, >1 = stronger glow
    float speed;           // speed of the wobble and the band flow, 1.0 = default
    float ringWidth;       // ring thickness in screen heights, ~0.44
    vec2 center;           // origin in uv, (0.5, 0.5) = middle
    vec4 colorWhite;
    vec4 colorCyan;
    vec4 colorPink;
} ubuf;

layout(binding = 1) uniform sampler2D source1; // outgoing wallpaper
layout(binding = 2) uniform sampler2D source2; // incoming wallpaper

const float AA = 0.0022;      // edge softness, in screen heights (~2px at 1080p)
const float GLOW_LEN = 0.05;  // how far the soft halos reach
const float TAIL = 0.096;     // ring width at the very end. Fixed, so the travel of the

                              // leading edge (the speed) never depends on ringWidth.

// Fast start, gentle slow-down: mostly ease-out, kept a little linear
// so the ring never stalls before it has left the screen.
float easeRing(float p) {
    float o = 1.0 - pow(1.0 - p, 3.0);
    return mix(p, o, 0.72);
}

// Slow angular wobble in [-1, 1]. Whole-number harmonics only, so it
// is seamless where atan() wraps around.
float wave(float a, float t, float ph, int style) {
    if (style == 1) {
        return 0.75 * sin(6.0 * a + t * 0.9 + ph)
             + 0.25 * sin(3.0 * a - t * 1.3 + ph * 1.7 + 1.3);
    }
    return 0.40 * sin(3.0 * a + t + ph)
         + 0.35 * sin(5.0 * a - t * 1.35 + ph * 1.7 + 1.3)
         + 0.25 * sin(7.0 * a + t * 1.9 + ph * 0.6 + 2.1);
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

    int style = ubuf.transitionStyle;
    vec4 oldC = texture(source1, uv);
    vec4 newC = texture(source2, uv);

    vec3 white = ubuf.colorWhite.rgb;
    vec3 cyan  = ubuf.colorCyan.rgb;
    vec3 pink  = ubuf.colorPink.rgb;

    // ===== geometry =====
    vec2 asp = vec2(ubuf.aspect, 1.0);
    vec2 q = (uv - ubuf.center) * asp;
    float r = length(q);
    float a = atan(q.y, q.x);

    // Distance from the origin to the farthest corner: how far the ring
    // must travel before it has fully left the screen.
    vec2 far = max(abs(ubuf.center), abs(1.0 - ubuf.center)) * asp;
    float maxR = length(far);

    // ===== timing =====
    float t = p * 9.0 * ubuf.speed;               // phase of the wobble and the flow
    float fx = (p - 0.20) / 0.16;
    float flash = exp(-fx * fx);                  // white flare on the leading edge

    // ===== ring size =====
    float Wmid = ubuf.ringWidth * min(1.0, ubuf.aspect);
    float Wtail = min(TAIL, Wmid);
    // Full width through the middle of the move, then it narrows so the
    // ring has fully left the screen when progress reaches 1.
    float W = mix(Wmid, Wtail, smoothstep(0.50, 0.93, p));

    float ampScale = (style == 1) ? 1.6 : 1.0;
    float ampMax = ubuf.distortion * 0.015 * ampScale;
    float echoSpan = (style == 2) ? 0.13 : 0.0;

    // Final radius is chosen so that at p = 1 the inner edge (plus wobble,
    // halo and echoes) is already beyond the farthest corner.
    float Rmax = maxR + TAIL + ampMax + GLOW_LEN + echoSpan + 0.01;
    float R = Rmax * easeRing(p);

    // Wobble grows in quickly, stays subtle, and fades out at the end.
    // Also capped by the radius so the first small circle stays round.
    float env = smoothstep(0.0, 0.18, p) * (1.0 - smoothstep(0.72, 1.0, p));
    float amp = min(ampMax * env, 0.2 * R);

    // Outer (leading) and inner edge, each with its own wobble phase.
    float rOut = R + amp * wave(a, t, 0.0, style);
    // Small discs are a filled bullseye; the hole opens as the disc grows,
    // and never takes more than ~40% of the radius until the ring narrows.
    float We = min(W, R * mix(1.0, 0.62, smoothstep(0.02, 0.22, R)));
    float hole = R - We;
    float rIn = max(0.0, hole + amp * wave(a, t, 1.9, style) * smoothstep(0.0, 0.06, hole));

    // ===== position inside the ring =====
    float s = clamp((r - rIn) / max(rOut - rIn, 1e-4), 0.0, 1.0);

    // ===== band borders =====
    float flow = t * 1.6;
    float ang = (style == 3) ? a + 6.0 * s : a;    // swirl: bands twist into spirals
    float ww = mix(0.20, 0.34, flash);             // white band width (share of the ring)
    float shine = pow(0.5 + 0.5 * cos(a - t * 1.2), 8.0); // a bright spot that circles the ring

    // Band waves ease in, so the very first frames are a clean bullseye.
    float bw = smoothstep(0.02, 0.25, p);
    float bCP = 0.38 + bw * (0.09 * sin(2.0 * ang - flow) + 0.04 * sin(5.0 * ang + flow * 1.3));
    float bW = 1.0 - ww - 0.10 * shine * bw + bw * 0.035 * sin(4.0 * ang - flow * 1.1 + 1.0);
    bW = max(bW, bCP + 0.18);

    float sc = 0.05; // softness of band borders
    float toPink  = smoothstep(bCP - sc, bCP + sc, s);
    float toWhite = smoothstep(bW - sc, bW + sc, s);

    // Cyan and pink each lighten toward the border they share with the
    // next band, which gives the bands a soft gradient while keeping
    // the hard cyan | pink split crisp.
    vec3 cyanBand = mix(cyan, white, 0.30 * smoothstep(0.0, bCP, s));
    vec3 pinkBand = mix(pink, white, 0.35 * smoothstep(bCP, bW, s));
    vec3 ringCol = mix(mix(cyanBand, pinkBand, toPink), white, toWhite);

    // ===== coverage of the ring itself =====
    float outerMask = 1.0 - smoothstep(rOut - AA, rOut + AA, r);
    float innerMask = smoothstep(rIn - AA, rIn + AA, r);
    innerMask = max(innerMask, 1.0 - smoothstep(0.0, 2.0 * AA, rIn));
    float ringMask = outerMask * innerMask;

    // ===== wallpapers =====
    float rMid = 0.5 * (rIn + rOut);
    float reveal = 1.0 - smoothstep(rMid - AA, rMid + AA, r);
    vec3 rgb = mix(oldC.rgb, newC.rgb, reveal);

    float k = clamp(ubuf.colorIntensity, 0.0, 1.0);   // opacity of the ring bands
    float glowK = min(ubuf.colorIntensity, 1.5) * smoothstep(0.0, 0.08, R); // strength of the halos, grows in with the ring

    // Soft halos: pinkish-white outside the ring, cyan inside it.
    float dOut = r - rOut;
    float haloOut = 1.0 - smoothstep(0.0, GLOW_LEN, max(dOut, 0.0));
    haloOut *= haloOut * smoothstep(-AA, AA, dOut);
    vec3 haloOutCol = mix(pink, white, 0.35 + 0.40 * flash);
    rgb = mix(rgb, haloOutCol, 0.42 * glowK * haloOut);

    float dIn = rIn - r;
    float haloIn = 1.0 - smoothstep(0.0, GLOW_LEN, max(dIn, 0.0));
    haloIn *= haloIn * smoothstep(-AA, AA, dIn) * smoothstep(0.0, 2.0 * AA, rIn);
    rgb = mix(rgb, cyan, 0.38 * glowK * haloIn);

    // Echo rings (style 2): two thin trailing rings over the new wallpaper.
    if (style == 2) {
        float fade = 1.0 - smoothstep(0.88, 1.0, p);
        float rE1 = rIn - 0.055 + 0.6 * amp * wave(a, t, 3.1, style);
        float rE2 = rIn - 0.110 + 0.6 * amp * wave(a, t, 4.6, style);
        float e1 = (1.0 - smoothstep(0.009 - AA, 0.009 + AA, abs(r - rE1))) * smoothstep(0.04, 0.10, rE1);
        float e2 = (1.0 - smoothstep(0.005 - AA, 0.005 + AA, abs(r - rE2))) * smoothstep(0.04, 0.10, rE2);
        rgb = mix(rgb, pink, e1 * k * fade);
        rgb = mix(rgb, cyan, e2 * k * fade);
    }

    // ===== the ring on top =====
    rgb = mix(rgb, ringCol, ringMask * k);

    fragColor = vec4(rgb, 1.0) * ubuf.qt_Opacity;
}
