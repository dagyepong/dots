"""Package extension/src into the zip uploaded to the Chrome Web Store.

    python pack.py        -> ../dist/web-crawlers-<version>.zip

Checks before zipping: manifest parses, every file it references exists, the
icons are the right sizes, locales have every key the manifest/popup use, and
no test-only permission (host_permissions) slipped in.
"""
import json
import os
import re
import struct
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(HERE, '..', 'src'))
DIST = os.path.normpath(os.path.join(HERE, '..', 'dist'))


def fail(msg):
    print('ERROR:', msg)
    sys.exit(1)


def png_size(path):
    with open(path, 'rb') as f:
        head = f.read(24)
    if head[:8] != b'\x89PNG\r\n\x1a\n':
        fail(f'{path} is not a PNG')
    return struct.unpack('>II', head[16:24])


man = json.load(open(os.path.join(SRC, 'manifest.json'), encoding='utf-8'))
if man.get('manifest_version') != 3:
    fail('manifest_version must be 3')
if 'host_permissions' in man:
    fail('host_permissions present — that is the test build, not the store build')
if set(man.get('permissions', [])) - {'activeTab', 'scripting', 'storage'}:
    fail(f'unexpected permissions: {man["permissions"]}')

refs = [man['background']['service_worker'], man['action']['default_popup']]
for size, rel in {**man.get('icons', {}), **man['action'].get('default_icon', {})}.items():
    p = os.path.join(SRC, rel)
    if not os.path.exists(p):
        fail(f'missing icon {rel}')
    if png_size(p) != (int(size), int(size)):
        fail(f'{rel} is {png_size(p)}, expected {size}x{size}')
    refs.append(rel)
html = open(os.path.join(SRC, 'popup.html'), encoding='utf-8').read()
refs += re.findall(r'(?:src|href)="([^"]+)"', html) + ['spider.js']
for rel in refs:
    if not os.path.exists(os.path.join(SRC, rel)):
        fail(f'missing file {rel}')

keys = set(re.findall(r'__MSG_(\w+)__', json.dumps(man)))
keys |= set(re.findall(r'data-i18n="(\w+)"', html))
keys |= set(re.findall(r"(?<![\w.])t\('(\w+)'\)", open(os.path.join(SRC, 'popup.js'), encoding='utf-8').read()))
for loc in os.listdir(os.path.join(SRC, '_locales')):
    msgs = json.load(open(os.path.join(SRC, '_locales', loc, 'messages.json'), encoding='utf-8'))
    missing = keys - set(msgs)
    if missing:
        fail(f'locale {loc} is missing {sorted(missing)}')
    if len(msgs['extDesc']['message']) > 132:
        fail(f'locale {loc}: description longer than 132 characters')

os.makedirs(DIST, exist_ok=True)
out = os.path.join(DIST, f'web-crawlers-{man["version"]}.zip')
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(SRC):
        for name in sorted(files):
            full = os.path.join(root, name)
            z.write(full, os.path.relpath(full, SRC).replace(os.sep, '/'))
print(f'ok: {out} ({os.path.getsize(out)} bytes, {len(zipfile.ZipFile(out).namelist())} files)')
