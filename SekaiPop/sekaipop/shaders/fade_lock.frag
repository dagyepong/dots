#version 440

// Fade (cross-dissolve), lockscreen edition: the same maths as fade.frag, but it
// takes ONE texture (the lockscreen picture, premultiplied) and outputs
// premultiplied ALPHA instead of blending two wallpapers, so the live
// desktop behind the overlay window shows through wherever it is
// transparent. Only LockRing.qml loads it (as `fade_lock`), picked by the
// wallpaper's transition style.
//
//   unlocking = 0   locking:   the desktop is the "old" side, the
//                   lockscreen is the "new" side
//   unlocking = 1   unlocking: the lockscreen is the "old" side, the
//                   desktop is the "new" side
//
// Plain cross-dissolve between the desktop and the lockscreen.
// Shares its uniform block with fade_lock.vert (mandatory, see
// shaders/README.md). Compile with shaders/compile-shaders.sh.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    int unlocking;         // 0 = locking (lockscreen inside / arriving), 1 = unlocking (lockscreen outside / leaving)
} ubuf;

layout(binding = 1) uniform sampler2D source1; // the lockscreen picture (premultiplied)

// Premultiplied "colour c at coverage a, over base".
vec4 over(vec3 c, float a, vec4 base) {
    a = clamp(a, 0.0, 1.0);
    return vec4(c * a + base.rgb * (1.0 - a), a + base.a * (1.0 - a));
}

void main() {
    vec4 lockC = texture(source1, qt_TexCoord0);
    float t = clamp(ubuf.progress, 0.0, 1.0);
    bool leaving = ubuf.unlocking != 0;
    // Locking: the lockscreen fades in over the desktop. Unlocking: it fades out.
    fragColor = lockC * (leaving ? 1.0 - t : t) * ubuf.qt_Opacity;
}
