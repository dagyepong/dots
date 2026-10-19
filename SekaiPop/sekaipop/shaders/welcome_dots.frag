#version 440

// The halftone on the SekaiPop logo's letters (WelcomeLetter.qml), the way the
// reference builds it: rows of dots whose size is cut by a moving matte.
//
//   shade   the dots that stay: biggest in the lower right corner, gone before the
//           middle (the video's dots are a shading); `falloff` is how far from the
//           corner they reach, as a fraction of the item's width (0.78 for a letter,
//           more for a whole word)
//   matte   a soft diagonal band that crosses the letter once (-1 = not running):
//           under it the dots swell, then shrink back as it moves on
//   drift   0..1 slides the whole lattice by one period, so the dots travel
//           and the loop is seamless
//
// The lattice is turned 45 degrees (the usual printed-halftone angle). Output is
// premultiplied; `dotColor` is opaque (the strength is `amount`).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 dotColor;
    vec2 size;
    float spacing;
    float shade;
    float matte;
    float drift;
    float amount;
    float falloff;
} ubuf;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = uv * ubuf.size;
    float s = max(ubuf.spacing, 2.0);

    const float c = 0.70710678;
    vec2 q = vec2(c * p.x + c * p.y, -c * p.x + c * p.y);
    q += vec2(ubuf.drift * s);
    vec2 cell = fract(q / s) - 0.5;
    float d = length(cell) * s;

    // the shading that stays: dots shrink away from the lower right corner
    float corner = clamp(1.0 - distance(uv, vec2(1.0, 1.0)) / max(ubuf.falloff, 0.1), 0.0, 1.0);
    float rShade = 0.46 * corner * clamp(ubuf.shade, 0.0, 1.0);

    // the matte: a soft band along the diagonal, from top left to bottom right
    float rPass = 0.0;
    if (ubuf.matte >= 0.0) {
        float m = (uv.x + uv.y) * 0.5;
        float centre = mix(-0.3, 1.3, clamp(ubuf.matte, 0.0, 1.0));
        float band = 1.0 - smoothstep(0.0, 0.26, abs(m - centre));
        rPass = 0.50 * band;
    }

    float r = max(rShade, rPass) * s;
    float aa = 0.75;
    float a = (1.0 - smoothstep(r - aa, r + aa, d)) * step(0.9, r) * clamp(ubuf.amount, 0.0, 1.0);

    fragColor = vec4(ubuf.dotColor.rgb * a, a) * ubuf.qt_Opacity;
}
