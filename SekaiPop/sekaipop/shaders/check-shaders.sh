#!/usr/bin/env bash
# Lists every shader source here that has no compiled .qsb. (It cannot tell a
# stale .qsb from a fresh one: unzipping gives files arbitrary times. After editing
# a shader source, always re-run compile-shaders.sh.)
# Lock transitions for every style other than the ring need their *_lock.qsb;
# without one, LockRing.qml plays the ring instead.
#   ./shaders/check-shaders.sh        (then ./shaders/compile-shaders.sh if it lists anything)
cd "$(dirname "$0")"
bad=0
for src in *.vert *.frag; do
    [ -e "$src" ] || continue
    if [ ! -e "$src.qsb" ]; then
        echo "missing: $src.qsb"; bad=1
    fi
done
if [ "$bad" = 0 ]; then echo "every shader source has a .qsb"; else echo; echo "run: ./shaders/compile-shaders.sh   (needs qsb: pacman -S qt6-shadertools)"; fi
exit $bad
