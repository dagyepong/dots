#!/usr/bin/env python3
"""Cuts the tile pictures from thumbs.qml (420 × 420) to one frame for all
(340 × 242, figure in the middle, feet at the bottom) and checks that nothing
reaches past it. Run after `qs -p shell/thumbs.qml`."""
import glob
import sys
from pathlib import Path

from PIL import Image

B = Path(__file__).resolve().parent.parent / "shell" / "thumbs"
BOX = (40, 150, 380, 392)
bad = []
for f in sorted(glob.glob(str(B / "*" / "*.png"))):
    im = Image.open(f)
    if im.size != (420, 420):
        continue
    bb = im.getchannel("A").getbbox()
    if not bb or bb[0] < BOX[0] or bb[1] < BOX[1] or bb[2] > BOX[2] or bb[3] > BOX[3]:
        bad.append((f.split("thumbs/")[1], bb))
    im.crop(BOX).save(f, optimize=True)
print("zugeschnitten; über den Rahmen:", bad or "keins")
sys.exit(1 if bad else 0)
