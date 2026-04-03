#version 330 core

in vec2 texCoord;
out vec4 fragColor;

uniform sampler2D tex;
uniform float time;

void main() {
    vec4 color = texture(tex, texCoord);
    float glow = sin(time * 0.4) * 0.15 + 0.15;  // ← tweak this number
    fragColor = color + vec4(0.0, glow, glow * 0.8, 0.0);
}
