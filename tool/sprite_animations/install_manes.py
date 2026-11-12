"""Install the Manes: new stills, the 8-frame idle sheets (1200 px), sprite data, and the
second Earthmane (MAN18, Rare). Run from the repo root."""
import sys, re, json, shutil
from PIL import Image
S = sys.argv[1]
src = open(S + '/manes_build.py').read()
ns = dict(S=S)
exec(src[src.index("U = '"):src.index('BG = ')].replace("O = S + '/manes'", ''), ns)
P, U = ns['P'], ns['U']
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
for hid in sorted(P):
    if hid == 'MAN18':
        img = 'creatures/rare/MAN18_earthmane.png'
    else:
        img = J[hid]['image']
        a = s.index('"id": "%s"' % hid)
        b = s.index('"id":', a + 10)
        blk, n = re.subn(r'"spriteData": \{[^}]*\}', NEW, s[a:b])
        assert n == 1, hid
        s = s[:a] + blk + s[b:]
    base = 'assets/images/' + img
    shutil.copyfile('%s/manes/%s_%s_idle2_spritesheet.png' % (S, hid, P[hid]['n']), base.replace('.png', '_spritesheet.png'))
    still = Image.open(U + P[hid]['f'] + '-image.png').convert('RGBA')
    for x in (0, 1160):
        for y in (0, 1160):
            still.paste((0, 0, 0, 0), (x, y, x + 40, y + 40))
    still.resize((512, 512), Image.LANCZOS).save(base, optimize=True)
if '"id": "MAN18"' not in s:
    a = s.index('"id": "MAN03"')
    a0 = s.rindex('    {', 0, a)
    b0 = s.index('    {', a)
    blk = s[a0:b0]
    blk = blk.replace('"MAN03"', '"MAN18"').replace('"Uncommon"', '"Rare"').replace('creatures/uncommon/MAN03_earthmane.png', 'creatures/rare/MAN18_earthmane.png')
    blk = re.sub(r'"description": "[^"]*"', '"description": "Flat stones sit stacked along its brow and tail, balanced with the patience of something that has never once been hurried."', blk)
    c = s.index('"id": "MSK01"')
    c0 = s.rindex('    {', 0, c)
    s = s[:c0] + blk + s[c0:]
open(pth, 'w').write(s)
J = {c['id']: c for c in json.loads(s)['creatures']}
print(J['MAN18'])
print(J['MAN05']['spriteData'], len(J))
