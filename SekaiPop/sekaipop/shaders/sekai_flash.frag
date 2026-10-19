#version 440

// Sekai flash: fades the outgoing wallpaper down to a solid colour,
// then fades the incoming wallpaper back up from that same colour —
// a "flash to colour and back" cut, timed as two even halves of the
// switch, rather than fade.frag's single straight crossfade between
// the two images. Uses `accentColor` so the flash colour matches the
// rest of the shell instead of a hardcoded white/black flash.
//
// Shares its uniform block with sekai_flash.vert (mandatory for a
// ShaderEffect pair, see shaders/README.md).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;   // 0..1, overall transition position
    vec4 accentColor; // colour the screen flashes through at progress == 0.5
} ubuf;

layout(binding = 1) uniform sampler2D source1; // outgoing wallpaper
layout(binding = 2) uniform sampler2D source2; // incoming wallpaper

void main() {
    vec2 uv = qt_TexCoord0;
    float t = clamp(ubuf.progress, 0.0, 1.0);

    vec4 fromColor = texture(source1, uv);
    vec4 toColor = texture(source2, uv);
    vec4 flash = vec4(ubuf.accentColor.rgb, 1.0);

    // First half: outgoing wallpaper -> flash colour.
    // Second half: flash colour -> incoming wallpaper.
    // A cubic ease on each half's own local t so the flash colour
    // genuinely holds near the midpoint instead of being one
    // instantaneous frame between two linear ramps.
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
