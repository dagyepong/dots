#version 440

// The halftone in the light outer stroke of the SekaiPop logo (WelcomeLogo.qml).
//
// It is a shading that wraps round the letters: the dots are biggest right
// beside the letters and shrink to nothing before the stroke's outer edge, so
// the stroke is never cut through its dots. How close the letters are comes from
// `field`, a blurred picture of the logo's silhouette (alpha 1 on the letters,
// fading out with the distance). The field is read a little up and to the left
// (`shadeOffset`), so the dots swell on the lower right side of every letter: a
// shadow thrown down and right, not an even ring.
//
//   shade   0..1, how strong the shading is (the stroke's halftone comes up)
//   matte   a soft diagonal band that crosses the picture once (-1 = not
//           running); under it the dots swell, still fading toward the edge
//   drift   0..1 slides the lattice by one period (seamless loop)
//
// The lattice is turned 45 degrees, as in welcome_dots.frag. Output is
// premultiplied; `dotColor` is opaque (the strength is `amount`).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 dotColor;
    vec2 size;
    vec2 shadeOffset;
    float spacing;
    float shade;
    float matte;
    float drift;
    float amount;
} ubuf;

layout(binding = 1) uniform sampler2D field;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = uv * ubuf.size;
    float s = max(ubuf.spacing, 2.0);

    const float c = 0.70710678;
    vec2 q = vec2(c * p.x + c * p.y, -c * p.x + c * p.y);
    q += vec2(ubuf.drift * s);
    vec2 cell = fract(q / s) - 0.5;
    float d = length(cell) * s;

    // closeness of the letters: 1 on them, falling to 0 a stroke's width away
    float f = texture(field, uv - ubuf.shadeOffset).a;
    float near = smoothstep(0.12, 0.85, f);
    float r = 0.48 * near * clamp(ubuf.shade, 0.0, 1.0);

    if (ubuf.matte >= 0.0) {
        float m = (uv.x + uv.y) * 0.5;
        float centre = mix(-0.3, 1.3, clamp(ubuf.matte, 0.0, 1.0));
        float band = 1.0 - smoothstep(0.0, 0.26, abs(m - centre));
        r = max(r, 0.50 * band * smoothstep(0.06, 0.55, f));
    }

    r *= s;
    float aa = 0.75;
    float a = (1.0 - smoothstep(r - aa, r + aa, d)) * step(0.9, r) * clamp(ubuf.amount, 0.0, 1.0);

    fragColor = vec4(ubuf.dotColor.rgb * a, a) * ubuf.qt_Opacity;
}
