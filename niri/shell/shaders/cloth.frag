#version 440
layout(location = 0) in vec2 vTex;
layout(location = 1) in float vFold;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float lift;
    float cx;
    float spread;
    float edge;
    float push;
};
layout(binding = 1) uniform sampler2D src;

void main() {
    vec4 c = texture(src, vTex);
    // bunched fabric is darker, with a faint sheen on the fold
    float shade = 1.0 - 0.38 * vFold + 0.08 * sin(vFold * 9.0) * vFold;
    fragColor = vec4(c.rgb * shade, c.a) * qt_Opacity;
}
