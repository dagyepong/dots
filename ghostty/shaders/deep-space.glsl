#version 330 core

in vec2 texCoord;
out vec4 fragColor;

uniform sampler2D tex;
uniform float time;

void main() {
    vec4 color = texture(tex, texCoord);
    float glow = sin(time * 0.2) * 0.1 + 0.1;  // ← tweak this number
    fragColor = color + vec4(glow * 0.3, 0.0, glow, 0.0);
}
