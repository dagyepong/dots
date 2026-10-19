#!/usr/bin/env python3
"""Tests for scripts/theming/win-cursor.py: builds small Windows cursors of every kind the
converter reads (32-bit alpha, 8-bit + AND mask, 1-bit, PNG inside .cur, animated .ani with
seq/rate, an install.inf, a zip), converts them, and reads the Xcursor files back.

    python3 tests/cursor-test/win_cursor_test.py
"""
import os
import struct
import subprocess
import sys
import tempfile
import zipfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "..", "scripts", "theming", "win-cursor.py")

fails = 0
checks = 0


def check(cond, what):
    global fails, checks
    checks += 1
    if not cond:
        fails += 1
        print("FAIL:", what)


# ---------- building Windows cursors ----------
def dib32(w, h, px):
    """px(x, y) -> (r, g, b, a); top-left first."""
    hdr = struct.pack("<IiiHHIIiiII", 40, w, 2 * h, 1, 32, 0, 0, 0, 0, 0, 0)
    xor = b""
    for y in range(h - 1, -1, -1):
        for x in range(w):
            r, g, b, a = px(x, y)
            xor += bytes((b, g, r, a))
    mask = b"\x00" * (((w + 31) // 32) * 4 * h)
    return hdr + xor + mask


def dib8(w, h, px):
    """px(x, y) -> 0 (transparent), 1 red, 2 white; 8-bit palette + AND mask."""
    pal = [(0, 0, 0), (255, 0, 0), (255, 255, 255)]
    hdr = struct.pack("<IiiHHIIiiII", 40, w, 2 * h, 1, 8, 0, 0, 0, 0, 3, 0)
    palb = b"".join(bytes((b, g, r, 0)) for r, g, b in pal)
    stride = ((w * 8 + 31) // 32) * 4
    xor = b""
    mstride = ((w + 31) // 32) * 4
    mask = b""
    for y in range(h - 1, -1, -1):
        row = bytes(px(x, y) for x in range(w))
        xor += row + b"\x00" * (stride - w)
        bits = 0
        mrow = bytearray(mstride)
        for x in range(w):
            if px(x, y) == 0:
                mrow[x >> 3] |= 0x80 >> (x & 7)
        mask += bytes(mrow)
    return hdr + palb + xor + mask


def dib1(w, h, px):
    """1-bit: px(x,y) -> 0 black, 1 white; AND mask all opaque except x==0."""
    hdr = struct.pack("<IiiHHIIiiII", 40, w, 2 * h, 1, 1, 0, 0, 0, 0, 2, 0)
    palb = bytes((0, 0, 0, 0, 255, 255, 255, 0))
    stride = ((w + 31) // 32) * 4
    xor = b""
    mask = b""
    for y in range(h - 1, -1, -1):
        row = bytearray(stride)
        mrow = bytearray(stride)
        for x in range(w):
            if px(x, y):
                row[x >> 3] |= 0x80 >> (x & 7)
            if x == 0:
                mrow[x >> 3] |= 0x80 >> (x & 7)
        xor += bytes(row)
        mask += bytes(mrow)
    return hdr + palb + xor + mask


def png_rgba(w, h, px):
    raw = b""
    for y in range(h):
        raw += b"\x00" + b"".join(bytes(px(x, y)) for x in range(w))

    def ch(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n" + ch(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + ch(b"IDAT", zlib.compress(raw)) + ch(b"IEND", b""))


def cur(images, typ=2):
    """images: [(w, h, blob, xhot, yhot)]"""
    out = struct.pack("<HHH", 0, typ, len(images))
    off = 6 + 16 * len(images)
    body = b""
    for w, h, blob, xh, yh in images:
        out += struct.pack("<BBBBHHII", w % 256, h % 256, 0, 0, xh, yh, len(blob), off + len(body))
        body += blob
    return out + body


def ani(frames, rates=None, seq=None, disp=6):
    def chunk(i, d):
        return i + struct.pack("<I", len(d)) + d + (b"\x00" if len(d) & 1 else b"")
    n = len(frames)
    nsteps = len(seq) if seq else n
    anih = struct.pack("<9I", 36, n, nsteps, 0, 0, 0, 1, disp, 1 | (2 if seq else 0))
    body = b"ACON" + chunk(b"anih", anih)
    if rates:
        body += chunk(b"rate", struct.pack("<%dI" % len(rates), *rates))
    if seq:
        body += chunk(b"seq ", struct.pack("<%dI" % len(seq), *seq))
    fr = b"fram" + b"".join(chunk(b"icon", f) for f in frames)
    body += chunk(b"LIST", fr)
    return b"RIFF" + struct.pack("<I", len(body)) + body


# ---------- reading Xcursor back ----------
def read_xcursor(path):
    d = open(path, "rb").read()
    assert d[:4] == b"Xcur"
    hs, ver, n = struct.unpack("<III", d[4:16])
    out = []  # (nominal, w, h, xhot, yhot, delay, pixels)
    for i in range(n):
        typ, sub, pos = struct.unpack("<III", d[16 + 12 * i:28 + 12 * i])
        assert typ == 0xFFFD0002
        _, t, nom, ver, w, h, xh, yh, delay = struct.unpack("<IIIIIIIII", d[pos:pos + 36])
        assert nom == sub
        px = struct.unpack("<%dI" % (w * h), d[pos + 36:pos + 36 + 4 * w * h])
        out.append((nom, w, h, xh, yh, delay, px))
    return out


def run(*args):
    return subprocess.run([sys.executable, SCRIPT] + list(args), capture_output=True, text=True)


def main():
    with tempfile.TemporaryDirectory() as t:
        pack = os.path.join(t, "pack")
        os.makedirs(pack)
        red = lambda x, y: (255, 0, 0, 255) if x < 16 and y < 16 else (0, 0, 0, 0)
        # Normal Select: 32-bit alpha, 32 px, hot spot (3, 5), a semi-transparent pixel at 31,31
        def normal(x, y):
            if x == 31 and y == 31:
                return (0, 255, 0, 128)
            return red(x, y)
        open(os.path.join(pack, "Normal Select.cur"), "wb").write(
            cur([(32, 32, dib32(32, 32, normal), 3, 5)]))
        # Link Select: 8-bit with a mask, and a second image of 48 px (the bigger one is used)
        p8 = lambda x, y: 1 if (x + y) % 2 == 0 and x < 20 else (2 if x < 20 else 0)
        open(os.path.join(pack, "Link Select.cur"), "wb").write(
            cur([(32, 32, dib8(32, 32, lambda x, y: p8(x, y)), 9, 1),
                 (48, 48, dib8(48, 48, lambda x, y: p8(x // 2 * 1, y // 2)), 14, 2)]))
        # Text Select: PNG inside a .cur
        open(os.path.join(pack, "Text Select.cur"), "wb").write(
            cur([(32, 32, png_rgba(32, 32, lambda x, y: (0, 0, 255, 255) if x == 16 else (0, 0, 0, 0)),
                  16, 16)]))
        # Help Select: 1-bit
        open(os.path.join(pack, "Help Select.cur"), "wb").write(
            cur([(32, 32, dib1(32, 32, lambda x, y: (x + y) & 1), 0, 0)]))
        # Busy.ani: 3 frames, steps 0,1,2,1 with their own rates
        frames = [cur([(32, 32, dib32(32, 32, lambda x, y, c=c: (c, 0, 0, 255)), 16, 16)]) for c in (50, 120, 200)]
        open(os.path.join(pack, "Busy.ani"), "wb").write(
            ani(frames, rates=[3, 6, 9, 12], seq=[0, 1, 2, 1]))
        # Working in Background.ani: no seq / rate, display rate 10 jiffies
        open(os.path.join(pack, "Working In Background.ani"), "wb").write(
            ani(frames[:2], disp=10))
        # Vertical / Horizontal / Diagonals / Move / Unavailable
        for nm in ("Vertical Resize", "Horizontal Resize", "Diagonal Resize 1",
                   "Diagonal Resize 2", "Move", "Unavailable", "Precision Select",
                   "Alternate Select", "Handwriting"):
            open(os.path.join(pack, nm + ".cur"), "wb").write(
                cur([(32, 32, dib32(32, 32, lambda x, y: (9, 9, 9, 255)), 8, 8)]))

        icons = os.path.join(t, "icons")
        r = run(pack, "-n", "TestPack", "--dest", icons, "--sizes", "24,32,48")
        check(r.returncode == 0, "converter exits 0 (%s)" % r.stderr)
        check(r.stdout.strip() == "TestPack", "last stdout line is the theme name")
        th = os.path.join(icons, "TestPack")
        cd = os.path.join(th, "cursors")
        check(os.path.isfile(os.path.join(th, "index.theme")), "index.theme written")
        check(os.path.isdir(cd), "cursors folder written")

        # roles went to the right Xcursor names
        for role, xname in [("Arrow", "left_ptr"), ("Hand", "hand2"), ("IBeam", "text"),
                            ("Help", "help"), ("Wait", "wait"), ("AppStarting", "left_ptr_watch"),
                            ("SizeNS", "sb_v_double_arrow"), ("SizeWE", "sb_h_double_arrow"),
                            ("SizeNWSE", "bd_double_arrow"), ("SizeNESW", "fd_double_arrow"),
                            ("SizeAll", "fleur"), ("No", "not-allowed"), ("Crosshair", "crosshair"),
                            ("UpArrow", "center_ptr"), ("NWPen", "pencil")]:
            check(os.path.exists(os.path.join(cd, xname)), "%s -> %s exists" % (role, xname))
        for alias, target in [("default", "left_ptr"), ("hand2", "pointer"),
                              ("sb_h_double_arrow", "ew-resize")]:
            p = os.path.join(cd, alias)
            check(os.path.islink(p) and os.path.realpath(p) == os.path.realpath(
                os.path.join(cd, target)) or os.path.islink(p) and os.readlink(p) == target,
                  "%s is a link to %s" % (alias, target))
        check(os.path.exists(os.path.join(cd, "copy")), "copy falls back to the arrow")

        # arrow: sizes, hot spot scaling, alpha
        arr = read_xcursor(os.path.join(cd, "left_ptr"))
        check(sorted({a[0] for a in arr}) == [24, 32, 48], "arrow has sizes 24, 32, 48")
        a32 = [a for a in arr if a[0] == 32][0]
        check((a32[1], a32[2]) == (32, 32), "32 px arrow is 32x32")
        check((a32[3], a32[4]) == (3, 5), "hot spot kept at 32 px (got %s)" % ((a32[3], a32[4]),))
        a48 = [a for a in arr if a[0] == 48][0]
        check((a48[3], a48[4]) == (round(3 * 1.5), round(5 * 1.5)), "hot spot scaled to 48 px")
        a24 = [a for a in arr if a[0] == 24][0]
        check((a24[3], a24[4]) == (round(3 * .75), round(5 * .75)), "hot spot scaled to 24 px")
        px = a32[6]
        check(px[0] == 0xFFFF0000, "opaque red premultiplied ARGB is ff ff 00 00 (got %08x)" % px[0])
        last = px[31 * 32 + 31]
        check((last >> 24) == 128 and ((last >> 8) & 255) == 128 and (last & 255) == 0 and ((last >> 16) & 255) == 0,
              "half-transparent green pixel is premultiplied (got %08x)" % last)
        check(px[20 * 32 + 20] == 0, "transparent stays transparent")
        check(len(arr) == 3, "still cursor: one image per size")

        # 8-bit + mask: the 48 px image was the source; masked pixels are see-through
        hand = read_xcursor(os.path.join(cd, "hand2"))
        h32 = [a for a in hand if a[0] == 32][0]
        check((h32[3], h32[4]) == (round(14 * 32 / 48), round(2 * 32 / 48)), "hand: biggest image used, hot spot scaled")
        check(h32[6][0] >> 24 == 255 and h32[6][30] >> 24 == 0, "8-bit mask: opaque inside, clear outside")

        # PNG-in-cur
        txt = read_xcursor(os.path.join(cd, "text"))
        t32 = [a for a in txt if a[0] == 32][0]
        check(t32[6][16] == 0xFF0000FF, "PNG cursor pixel (got %08x)" % t32[6][16])

        # 1-bit
        hp = [a for a in read_xcursor(os.path.join(cd, "help")) if a[0] == 32][0]
        check(hp[6][0] >> 24 == 0, "1-bit: and=1 xor=0 is see-through")
        check(hp[6][1] == 0xFFFFFFFF, "1-bit: and=0 xor=1 is opaque white (got %08x)" % hp[6][1])
        check(hp[6][2] == 0xFF000000, "1-bit: and=0 xor=0 is opaque black (got %08x)" % hp[6][2])

        # animation: 4 steps per size, delays 3,6,9,12 jiffies -> 50,100,150,200 ms
        busy = read_xcursor(os.path.join(cd, "wait"))
        b32 = [a for a in busy if a[0] == 32]
        check(len(b32) == 4, "busy has 4 steps per size (got %d)" % len(b32))
        check([a[5] for a in b32] == [50, 100, 150, 200], "delays from rate chunk (got %s)" % [a[5] for a in b32])
        check([(a[6][0] >> 16) & 255 for a in b32] == [50, 120, 200, 120], "seq order 0,1,2,1")
        wk = read_xcursor(os.path.join(cd, "left_ptr_watch"))
        w32 = [a for a in wk if a[0] == 32]
        check(len(w32) == 2 and all(a[5] == 167 for a in w32), "no rate chunk: display rate 10 jiffies = 167 ms")

        # a second run refreshes our own theme, but never overwrites a foreign folder
        r = run(pack, "-n", "TestPack", "--dest", icons)
        check(r.returncode == 0, "re-import of our own theme works")
        os.makedirs(os.path.join(icons, "Foreign", "cursors"))
        r = run(pack, "-n", "Foreign", "--dest", icons)
        check(r.returncode == 2 and "already exists" in r.stderr, "a theme not made by us is not overwritten")

        # zip + install.inf: roles from the inf, whatever the file names are
        zp = os.path.join(t, "Fancy Pack.zip")
        inf = '''[Version]
signature="$CHICAGO$"
[DefaultInstall]
CopyFiles = Scheme.Cur, Scheme.Txt
AddReg    = Scheme.Reg
[Scheme.Reg]
HKCU,"Control Panel\\Cursors\\Schemes","%SCHEME_NAME%",0x00020000,"%10%\\%CUR_DIR%\\%pointer%,%10%\\%CUR_DIR%\\%help%,%10%\\%CUR_DIR%\\%work%,%10%\\%CUR_DIR%\\%busy%"
[Strings]
CUR_DIR = "Cursors\\Fancy"
SCHEME_NAME = "Fancy Scheme"
pointer = "a1.cur"
help = "a2.cur"
work = "a3.ani"
busy = "a4.ani"
'''
        with zipfile.ZipFile(zp, "w") as z:
            z.writestr("Fancy/install.inf", inf)
            z.writestr("Fancy/a1.cur", cur([(32, 32, dib32(32, 32, lambda x, y: (1, 2, 3, 255)), 1, 1)]))
            z.writestr("Fancy/a2.cur", cur([(32, 32, dib32(32, 32, lambda x, y: (4, 5, 6, 255)), 2, 2)]))
            z.writestr("Fancy/a3.ani", ani(frames[:2]))
            z.writestr("Fancy/a4.ani", ani(frames))
            z.writestr("../evil.cur", b"nope")
        r = run(zp, "--dest", icons)
        check(r.returncode == 0, "zip with install.inf converts (%s)" % r.stderr)
        check(r.stdout.strip() == "Fancy Scheme", "theme named after the inf's scheme (got %r)" % r.stdout.strip())
        fc = os.path.join(icons, "Fancy Scheme", "cursors")
        check(read_xcursor(os.path.join(fc, "help"))[0][3] == 2, "inf: Help is a2.cur")
        check(len([a for a in read_xcursor(os.path.join(fc, "wait")) if a[0] == 32]) == 3, "inf: Wait is a4.ani (3 frames)")
        check(not os.path.exists(os.path.join(t, "evil.cur")), "zip paths cannot leave the folder")

        # --map overrides, and --dry-run writes nothing
        r = run(pack, "--dry-run", "--dest", os.path.join(t, "dry"), "-n", "X")
        check(r.returncode == 0 and not os.path.exists(os.path.join(t, "dry")), "dry run writes nothing")
        r = run(pack, "-n", "Mapped", "--dest", icons, "--map", "Hand=Move.cur")
        check(r.returncode == 0, "--map accepted")
        mh = read_xcursor(os.path.join(icons, "Mapped", "cursors", "hand2"))
        check(mh[0][6][0] & 0xFFFFFF == 0x090909, "--map Hand=Move.cur used")

        # single file, and a bad file
        one = os.path.join(pack, "Normal Select.cur")
        r = run(one, "-n", "Single", "--dest", icons)
        check(r.returncode == 0 and os.path.exists(os.path.join(icons, "Single", "cursors", "left_ptr")), "single .cur works")
        check(os.path.islink(os.path.join(icons, "Single", "cursors", "pointer")), "single .cur: every other cursor is the arrow")
        bad = os.path.join(t, "bad"); os.makedirs(bad)
        open(os.path.join(bad, "Normal Select.cur"), "wb").write(b"not a cursor at all")
        r = run(bad, "--dest", icons, "-n", "Bad")
        check(r.returncode == 2, "an unreadable arrow is an error, not a broken theme")
        check(not os.path.exists(os.path.join(icons, "Bad")), "nothing left behind")
        r = run(os.path.join(t, "nothing"), "--dest", icons)
        check(r.returncode == 2, "missing input is an error")


        # ---- through icon-cursor.sh (what the shell runs) and the chooser script
        scripts = os.path.join(HERE, "..", "..", "scripts", "theming")
        env = dict(os.environ, XDG_DATA_HOME=os.path.join(t, "data"), HOME=os.path.join(t, "home"))
        os.makedirs(env["HOME"], exist_ok=True)
        r = subprocess.run(["sh", os.path.join(scripts, "icon-cursor.sh"), "import", pack, "ViaShell"],
                           capture_output=True, text=True, env=env)
        check(r.returncode == 0 and r.stdout.strip() == "ViaShell", "icon-cursor.sh import prints the theme name (%s)" % r.stderr[-200:])
        check(os.path.isdir(os.path.join(t, "data", "icons", "ViaShell", "cursors")), "icon-cursor.sh import writes into XDG_DATA_HOME/icons")
        r = subprocess.run(["sh", os.path.join(scripts, "icon-cursor.sh"), "list", "cursors"],
                           capture_output=True, text=True, env=env)
        check("ViaShell" in r.stdout.split("\n"), "the imported theme is in `list cursors` (what Settings shows)")
        r = subprocess.run(["sh", os.path.join(scripts, "icon-cursor.sh"), "import"],
                           capture_output=True, text=True, env=env)
        check(r.returncode == 2, "import without a path is a usage error")

        stub = os.path.join(t, "stubbin")
        os.makedirs(stub)
        chosen = os.path.join(pack, "Busy.ani")
        with open(os.path.join(stub, "zenity"), "w") as fh:
            fh.write("#!/bin/sh\nprintf '%s\\n' \"$STUB_PICK\"\n")
        os.chmod(os.path.join(stub, "zenity"), 0o755)
        penv = dict(env, PATH=stub + os.pathsep + os.environ["PATH"], STUB_PICK=chosen, SEKAIPOP_CHOOSER="zenity")
        r = subprocess.run(["sh", os.path.join(scripts, "pick-cursor-pack.sh"), "pick"],
                           capture_output=True, text=True, env=penv)
        check(r.stdout.strip() == pack, "one .cur / .ani picked out of a folder of cursors gives the folder (got %r)" % r.stdout.strip())
        penv["STUB_PICK"] = zp
        r = subprocess.run(["sh", os.path.join(scripts, "pick-cursor-pack.sh"), "pick"],
                           capture_output=True, text=True, env=penv)
        check(r.stdout.strip() == zp, "a .zip is passed on as it is")
        penv["STUB_PICK"] = ""
        r = subprocess.run(["sh", os.path.join(scripts, "pick-cursor-pack.sh"), "pick"],
                           capture_output=True, text=True, env=penv)
        check(r.returncode == 1 and r.stdout.strip() == "", "cancel prints nothing and exits 1")

    print("%d checks, %d failed" % (checks, fails))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
