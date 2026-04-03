#version 330 core

in vec2 texCoord;
out vec4 fragColor;

uniform sampler2D tex;
uniform float time;

void main() {
    vec4 color = texture(tex, texCoord);
    float glow = sin(time * 0.3) * 0.2 + 0.2;  // ← tweak this number (0.1 = subtle, 0.3 = intense)
    fragColor = color + vec4(glow, glow * 0.5, 0.0, 0.0);
}
