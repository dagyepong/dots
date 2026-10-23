#version 440
// The bottom of the screen as a cloth: vertices near the bottom edge and near
// cx are pulled up, the more the closer they are, so the lower part bunches up
// like fabric lifted by a hand. With `push` it slides aside instead, like a
// curtain drawn back at the bottom.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 vTex;
layout(location = 1) out float vFold;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float lift;     // px the bottom edge rises at cx
    float cx;       // px
    float spread;   // px, half width of the bulge
    float edge;     // px, y of the bottom edge
    float push;     // px the cloth moves sideways at cx (curtain), signed
};

void main() {
    vTex = qt_MultiTexCoord0;
    vec4 p = qt_Vertex;
    float dx = (p.x - cx) / spread;
    float across = exp(-dx * dx);
    float reach = lift * 2.4 + 30.0;
    float t = clamp((p.y - (edge - reach)) / reach, 0.0, 1.0);
    float up = lift * across * t * t * (3.0 - 2.0 * t);
    p.y -= up;
    // as a curtain: the lower part near cx slides aside, most at the bottom
    float reachSide = 260.0;
    float ts = clamp((p.y - (edge - reachSide)) / reachSide, 0.0, 1.0);
    float side = push * across * ts * ts;
    p.x += side;
    vFold = max(across * t * clamp(lift / 50.0, 0.0, 1.0), across * ts * clamp(abs(push) / 60.0, 0.0, 1.0));
    gl_Position = qt_Matrix * p;
}
