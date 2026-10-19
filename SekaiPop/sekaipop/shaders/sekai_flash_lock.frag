#version 440

// Sekai flash, lockscreen edition: the same maths as sekai_flash.frag, but it
// takes ONE texture (the lockscreen picture, premultiplied) and outputs
// premultiplied ALPHA instead of blending two wallpapers, so the live
// desktop behind the overlay window shows through wherever it is
// transparent. Only LockRing.qml loads it (as `sekai_flash_lock`), picked by the
// wallpaper's transition style.
//
//   unlocking = 0   locking:   the desktop is the "old" side, the
//                   lockscreen is the "new" side
//   unlocking = 1   unlocking: the lockscreen is the "old" side, the
//                   desktop is the "new" side
//
// The desktop (or lockscreen) fades to the accent colour, then the other side fades back up from it.
// Shares its uniform block with sekai_flash_lock.vert (mandatory, see
// shaders/README.md). Compile with shaders/compile-shaders.sh.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;   // 0..1, overall transition position
    vec4 accentColor; // colour the screen flashes through at progress == 0.5
    int unlocking;         // 0 = locking (lockscreen inside / arriving), 1 = unlocking (lockscreen outside / leaving)
} ubuf;

layout(binding = 1) uniform sampler2D source1; // the lockscreen picture (premultiplied)

// Premultiplied "colour c at coverage a, over base".
vec4 over(vec3 c, float a, vec4 base) {
    a = clamp(a, 0.0, 1.0);
    return vec4(c * a + base.rgb * (1.0 - a), a + base.a * (1.0 - a));
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = clamp(ubuf.progress, 0.0, 1.0);
    vec4 lockC = texture(source1, uv);
    bool leaving = ubuf.unlocking != 0;

    // Transparent = the live desktop.
    vec4 fromColor = leaving ? lockC : vec4(0.0);
    vec4 toColor = leaving ? vec4(0.0) : lockC;
    vec4 flash = vec4(ubuf.accentColor.rgb, 1.0);

    vec4 base;
    if (t < 0.5) {
        float localT = t / 0.5;
        localT = localT * localT * (3.0 - 2.0 * localT);
        base = mix(fromColor, flash, localT);
    } else {
        float localT = (t - 0.5) / 0.5;
        localT = localT * localT * (3.0 - 2.0 * localT);
        base = mix(flash, toColor, localT);
    }

    fragColor = base * ubuf.qt_Opacity;
}
