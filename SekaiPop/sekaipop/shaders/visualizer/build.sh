#!/bin/sh
cd "$(dirname "$0")" || exit 1
QSB=$(command -v qsb || command -v qsb6 || ls /usr/lib/qt6/bin/qsb /usr/lib64/qt6/bin/qsb 2>/dev/null | head -n 1)
if [ -z "$QSB" ]; then
    echo "qsb not found: install qt6-shadertools (Arch) / qt6-qtshadertools (Fedora)" >&2
    exit 1
fi
status=0
for f in tide ribbons scope pulse; do
    [ -f "$f.frag" ] || continue
    if "$QSB" --qt6 -o "$f.frag.qsb" "$f.frag"; then
        echo "wrote $f.frag.qsb"
    else
        echo "FAILED: $f.frag" >&2
        status=1
    fi
done
exit $status
