"""Install the Mystics drawn anew as stills (mystic_stills/): each one's 8-frame idle sheet
(1200 px, 2 rows of 4, from mystics_build.py), its 512 px still, and its sprite data.
Run from the repo root: install_mystics.py <scratch> [ids...]"""
import sys, os, re, json
from PIL import Image
S, ONLY = sys.argv[1], sys.argv[2:]
HERE = os.path.dirname(os.path.abspath(__file__))
pth = 'assets/data/alchemons_creatures.json'
s = open(pth).read()
J = {c['id']: c for c in json.loads(s)['creatures']}
NEW = '''"spriteData": {
        "frameWidth": 1200,
        "frameHeight": 1200,
        "totalFrames": 8,
        "rows": 2,
        "frameDurationMs": 120
      }'''
stills = sorted(f for f in os.listdir(HERE + '/mystic_stills') if f.endswith('.png'))
total = 0
for f in stills:
    hid = f[:5]
    if ONLY and hid not in ONLY:
        continue
    name = f[6:-4]
    a = s.index('"id": "%s"' % hid)
    b = s.index('"id":', a + 10)
    blk, n = re.subn(r'"spriteData": \{[^}]*\}', NEW, s[a:b])
    assert n == 1, hid
    s = s[:a] + blk + s[b:]
    base = 'assets/images/' + J[hid]['image']
    assert base.endswith('/%s_%s.png' % (hid, name)), (hid, base)
    Image.open('%s/mystics/%s_%s_idle2_spritesheet.png' % (S, hid, name)).save(base.replace('.png', '_spritesheet.png'), optimize=True)
    still = Image.open(HERE + '/mystic_stills/' + f).convert('RGBA')
    for x in (0, 1160):
        for y in (0, 1160):
            still.paste((0, 0, 0, 0), (x, y, x + 40, y + 40))      # the corner marks
    still.resize((512, 512), Image.LANCZOS).save(base, optimize=True)
    total += os.path.getsize(base.replace('.png', '_spritesheet.png')) + os.path.getsize(base)
    print(hid, name, base)
open(pth, 'w').write(s)
print('%.1f MB' % (total / 1048576.0))
