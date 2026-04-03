#version 330 core

in vec2 texCoord;
out vec4 fragColor;

uniform sampler2D tex;
uniform float time;

void main() {
    vec4 color = texture(tex, texCoord);
    float glow = sin(time * 0.5) * 0.1 + 0.1;
    fragColor = color + vec4(glow, glow, glow, 0.0);
}
