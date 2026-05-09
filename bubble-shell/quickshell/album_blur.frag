#version 440

// album_blur.frag — progressive gaussian-ish blur driven by uv.y.
// Blur radius is 0 above `blurStart` and grows smoothly to `maxBlur` at uv.y=1.
//
// Compile with:
//   /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 \
//     -o album_blur.frag.qsb album_blur.frag

layout(location = 0) in  vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  iSize;
    float maxBlur;    // max blur radius in pixels
    float blurStart;  // uv.y where blur begins (0..1)
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = 1.0 / ubuf.iSize;

    float t = smoothstep(ubuf.blurStart, 1.0, uv.y);
    float r = t * ubuf.maxBlur;

    if (r < 0.5) {
        fragColor = texture(source, uv) * ubuf.qt_Opacity;
        return;
    }

    // 7x7 kernel with triangular (Pascal-ish) weights
    vec4  sum   = vec4(0.0);
    float total = 0.0;
    for (int y = -3; y <= 3; y++) {
        for (int x = -3; x <= 3; x++) {
            vec2 off = vec2(float(x), float(y)) * (r / 3.0) * px;
            float w  = (4.0 - abs(float(x))) * (4.0 - abs(float(y)));
            sum   += texture(source, uv + off) * w;
            total += w;
        }
    }
    fragColor = (sum / total) * ubuf.qt_Opacity;
}
