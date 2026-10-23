#version 440
// The chat card and him melted into its corner: a rounded box and a circle,
// joined by a soft fillet (the same circular blend DMS uses for its frame),
// filled, with a thin line along the outline.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // of this item, px
    vec4 box;       // card: x, y, w, h (px, in this item)
    float radius;   // card corner
    vec4 circ;      // him: centre x, y, radius, unused
    float k;        // fillet
    vec4 fill;
    vec4 line;
    float lineW;
};

float sdRoundBox(vec2 p, vec2 c, vec2 h, float r) {
    r = min(r, min(h.x, h.y));
    vec2 q = abs(p - c) - h + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

float smin(float a, float b, float k) {
    if (k <= 0.0)
        return min(a, b);
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float d = sdRoundBox(p, box.xy + box.zw * 0.5, box.zw * 0.5, radius);
    if (circ.z > 0.0)
        d = smin(d, length(p - circ.xy) - circ.z, k);
    float cov = 1.0 - smoothstep(-0.75, 0.75, d);
    float edge = 1.0 - smoothstep(lineW * 0.5 - 0.6, lineW * 0.5 + 0.6, abs(d + lineW * 0.5));
    vec3 col = mix(fill.rgb, line.rgb, edge * line.a);
    float a = mix(fill.a, 1.0, edge * line.a);
    fragColor = vec4(col * a, a) * cov * qt_Opacity;
}
