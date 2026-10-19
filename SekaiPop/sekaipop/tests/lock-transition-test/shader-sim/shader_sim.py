#!/usr/bin/env python3
# Runs *_lock.frag shaders on the CPU through a tiny C++ shim (shim.h) and prints
# the mean alpha over a pixel grid for progress 0..1, locking and unlocking.
#
#   locking   should go 0 -> 1   (desktop -> lockscreen)
#   unlocking should go 1 -> 0   (lockscreen -> desktop)
#   "!BAD"    = a NaN, or a colour brighter than its alpha (premultiplied output
#               must never do that)
#
# Needs g++. Not a compiler for the real thing (only `qsb` is): it catches type
# errors, bad end states and NaNs, not driver quirks.
#   python3 shader_sim.py ../../../shaders/*_lock.frag
import os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULTS = {
    'qt_Opacity': '1.0f', 'aspect': '16.0f/9.0f', 'thickness': '0.2f', 'pointLength': '3.0f',
    'curvature': '1.0f', 'colorIntensity': '1.0f', 'elastic': '1.0f', 'center': 'vec2(0.5f,0.5f)',
    'colorWhite': 'vec4(1,1,1,1)', 'colorCyan': 'vec4(0.13f,0.9f,0.83f,1)',
    'colorPink': 'vec4(1,0.3f,0.6f,1)', 'colorGreen': 'vec4(0,1,0.8f,1)',
    'accentColor': 'vec4(0.2f,0.8f,1,1)', 'transitionStyle': '0', 'distortion': '1.0f',
    'speed': '1.0f', 'spin': '0.5f', 'ringWidth': '0.44f', 
    'direction': 'vec2(-1,-1)', 'bandThickness': '0.2f', 'blockSize': '0.34f', 'stagger': '1.0f',
}

def simulate(path, tmp):
    t = open(path).read()
    block = re.search(r'uniform buf \{(.*?)\} ubuf;', t, re.S).group(1)
    members = re.findall(r'^\s*(?:float|int|vec2|vec4|mat4)\s+(\w+);', block, re.M)
    setup = ''.join(f'  ubuf.{m} = {DEFAULTS[m]};\n' for m in members if m in DEFAULTS)
    has_unl = 'unlocking' in members
    t = re.sub(r'#version.*\n', '', t)
    t = re.sub(r'layout\(location = 0\) in (\w+) (\w+);', r'\1 \2;', t)
    t = re.sub(r'layout\(location = 0\) out (\w+) (\w+);', r'\1 \2;', t)
    t = t.replace('layout(std140, binding = 0) uniform buf {', 'struct Buf {')
    t = re.sub(r'layout\(binding = \d\) uniform sampler2D (\w+);', r'sampler2D \1;', t)
    t = re.sub(r'\bout float (\w+)', r'float& \1', t)
    t = re.sub(r'\.rgb\b', '.rgb()', t).replace('void main()', 'void glmain()')
    harness = f'''
#include <cstdio>
vec4 g_tex(0.2f, 0.4f, 0.6f, 1.0f);
int main() {{
{setup}
  const int W = 64, H = 36;
  for (int unl = 0; unl < {2 if has_unl else 1}; ++unl) {{
    printf("  %s p: ", unl ? "unlock" : "lock  ");
    for (int k = 0; k <= 10; ++k) {{
      float p = k / 10.0f; ubuf.progress = p; {'ubuf.unlocking = unl;' if has_unl else ''}
      double sum = 0; int bad = 0;
      for (int j = 0; j < H; ++j) for (int i = 0; i < W; ++i) {{
        qt_TexCoord0 = vec2((i + 0.5f) / W, (j + 0.5f) / H); glmain();
        float a = fragColor.a;
        if (!(a == a) || !(fragColor.x == fragColor.x)) bad++;
        if (fragColor.x > a + 1e-3f || fragColor.y > a + 1e-3f || fragColor.z > a + 1e-3f) bad++;
        sum += a;
      }}
      printf("%.1f:%.2f%s ", p, sum / (W * H), bad ? "!BAD" : "");
    }}
    printf("\\n");
  }}
}}
'''
    cpp = os.path.join(tmp, 'sim.cpp'); exe = os.path.join(tmp, 'sim')
    open(cpp, 'w').write('#include "shim.h"\n' + t + harness)
    r = subprocess.run(['g++', '-std=c++17', '-O1', '-I' + HERE, cpp, '-o', exe], capture_output=True, text=True)
    if r.returncode:
        print(os.path.basename(path) + ': DOES NOT COMPILE\n' + r.stderr[:800]); return False
    print(os.path.basename(path))
    print(subprocess.run([exe], capture_output=True, text=True).stdout)
    return True

if __name__ == '__main__':
    with tempfile.TemporaryDirectory() as tmp:
        ok = all([simulate(p, tmp) for p in sys.argv[1:]])
    sys.exit(0 if ok else 1)
