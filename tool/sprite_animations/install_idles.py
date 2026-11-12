"""Install the Wing, Pip and Let idles: sheets, frame counts, per-frame costume fits
(one shared move per frame) and albino eye overlays carried through the same motion.
Run from the repo root. Reads the originals from git HEAD."""
import sys, os, re, math, json, glob, io, subprocess, shutil
from PIL import Image

S = sys.argv[1]
REPO = os.getcwd()


def load(script, marker, argv):
    src = open(S + '/' + script).read()
    src = src[:src.index(marker)]
    old = sys.argv
    sys.argv = ['x'] + argv
    ns = {}
    exec(compile(src, script, 'exec'), ns)
    sys.argv = old
    return ns


def head(path):
    return Image.open(io.BytesIO(subprocess.check_output(['git', 'show', 'HEAD:' + path]))).convert('RGBA')


J = json.load(open('assets/data/alchemons_creatures.json'))['creatures']
ENTRY = {c['id']: c for c in J}
FAMS = []
w = load('wings_build.py', "if MODE in ('overlay', 'build'):", [REPO, S + '/wings', 'none'])
FAMS.append(dict(name='wings', ns=w, F=1200, ids=sorted(w['P']), offs={}))
p = load('pips_build.py', "if MODE in ('overlay', 'build'):", [REPO, S + '/pips', 'none'])
FAMS.append(dict(name='pips', ns=p, F=1200, ids=sorted(p['P']), offs=json.load(open(S + '/pips/offs.json'))))
l = load('lets_build.py', "for h in (ONLY or sorted(P)):", [REPO, S + '/lets'])
FAMS.append(dict(name='lets', ns=l, F=512, ids=[i for i in sorted(l['P']) if i not in ('LET08', 'LET12')],
                 offs=json.load(open(S + '/lets/offs.json'))))

MOTION = {}   # id -> (param dict, disp, F, offs)
for fam in FAMS:
    for hid in fam['ids']:
        prm = dict(fam['ns']['P'][hid])
        sheet = 'assets/images/' + ENTRY[hid]['image'].replace('.png', '_spritesheet.png')
        if fam['name'] == 'lets':
            b = head(sheet).crop((0, 0, 512, 512)).getbbox()[3]
            prm['foot'], prm['hip'] = b - 10, b - 52
        offs = [tuple(o) for o in fam['offs'].get(hid, [(0, 0)] * 4)]
        MOTION[hid] = (prm, fam['ns']['disp'], fam['F'], offs, sheet, fam['name'])

# 1. sheets
for hid, (prm, disp, F, offs, sheet, fam) in MOTION.items():
    name = os.path.basename(sheet)[:-16]
    src = '%s/%s/%s_idle_spritesheet.png' % (S, fam, name)
    assert Image.open(src).size == (4 * F, 2 * F), src
    shutil.copyfile(src, sheet)
print('sheets installed', len(MOTION))

# 2. frame counts
pth = 'assets/data/alchemons_creatures.json'
s = open(pth).read()
for hid in MOTION:
    a = s.index('"id": "%s"' % hid)
    b = s.index('"totalFrames": 4,', a)
    assert b - a < 1500, hid
    ind = re.search(r'\n(\s*)"totalFrames": 4,', s[b - 40:b + 20]).group(1)
    s = s[:b] + '"totalFrames": 8,\n' + ind + '"rows": 2,' + s[b + len('"totalFrames": 4,'):]
open(pth, 'w').write(s)
json.load(open(pth))
print('json entries changed', len(MOTION))

# 3. costume fits: one shared move per frame
pth = 'lib/models/costume_fits.dart'
s = open(pth).read()
a = s.index('const _frameFits')
headpart, body = s[:a], s[a:]
pat = re.compile(r"    '([A-Z]{3}\d\d)': \[\n((?:      \(.*\),\n)+)    \],")
tup = re.compile(r'\(([-\d.e]+), ([-\d.e]+), ([-\d.e]+)\)')
old = {}
for m in pat.finditer(body):
    old.setdefault(m.group(1), []).append([tuple(float(x) for x in t) for t in tup.findall(m.group(2))])
moves, worst = {}, 0
for hid, (prm, disp, F, offs, sheet, fam) in MOTION.items():
    per = []
    for tab in old[hid]:
        assert len(tab) == 4, (hid, len(tab))
        x0, y0 = tab[0][0] * F, tab[0][1] * F
        d0 = disp(prm, x0, y0, 0.0)
        per.append([(tab[k % 4][0] - tab[0][0] + (offs[k % 4][0] + disp(prm, x0, y0, 2 * math.pi * k / 8)[0] - d0[0]) / F,
                     tab[k % 4][1] - tab[0][1] + (offs[k % 4][1] + disp(prm, x0, y0, 2 * math.pi * k / 8)[1] - d0[1]) / F) for k in range(8)])
    mv = [(sum(r[k][0] for r in per) / len(per), sum(r[k][1] for r in per) / len(per)) for k in range(8)]
    for r in per:
        for k in range(8):
            worst = max(worst, abs(r[k][0] - mv[k][0]) * F * 1200 / F, abs(r[k][1] - mv[k][1]) * F * 1200 / F)
    moves[hid] = mv
print('largest gap between a costume\'s exact place and the shared move: %.1f px on a 1200 px frame' % worst)


def fmt(v):
    r = round(v, 3)
    return repr(r if r != 0 else 0.0)


def repl(m):
    hid = m.group(1)
    if hid not in MOTION:
        return m.group(0)
    tab = [tuple(float(x) for x in t) for t in tup.findall(m.group(2))]
    rows = ['      (%s, %s, %s),' % (fmt(tab[0][0] + moves[hid][k][0]), fmt(tab[0][1] + moves[hid][k][1]), fmt(tab[k % 4][2])) for k in range(8)]
    return "    '%s': [\n%s\n    ]," % (hid, '\n'.join(rows))


open(pth, 'w').write(headpart + pat.sub(repl, body))
print('costume tables rewritten', 3 * len(MOTION))

# 4. albino eyes: carry the existing overlay through the same motion
n = 0
for hid, (prm, disp, F, offs, sheet, fam) in MOTION.items():
    ov = sheet.replace('_spritesheet.png', '_albino_eyes.png')
    if not os.path.exists(ov):
        print('no eye overlay for', hid)
        continue
    o = head(ov)
    assert o.size[1] * 4 == o.size[0], (hid, o.size)
    E = o.size[1]
    sc, C = F / E, 8
    out, ar = Image.new('RGBA', (4 * E, 2 * E)), []
    for k in range(8):
        i = k % 4
        fr = o.crop((i * E, 0, (i + 1) * E, E)).convert('RGBa')
        ph = 2 * math.pi * k / 8
        g = {}
        for gy in range(0, E + 1, C):
            for gx in range(0, E + 1, C):
                dx, dy = disp(prm, gx * sc, gy * sc, ph)
                g[gx, gy] = (gx - (dx + offs[i][0]) / sc, gy - (dy + offs[i][1]) / sc)
        mesh = [((x, y, x + C, y + C), g[x, y] + g[x, y + C] + g[x + C, y + C] + g[x + C, y]) for y in range(0, E, C) for x in range(0, E, C)]
        f = fr.transform((E, E), Image.MESH, mesh, Image.BICUBIC).convert('RGBA')
        out.paste(f, ((k % 4) * E, (k // 4) * E))
        ar.append(sum(f.getchannel('A').histogram()[1:]))
    lo, hi = min(ar), max(ar)
    if lo == 0 and hi > 0 or (lo and hi / lo > 1.5):
        print('CHECK', hid, ar)
    out.save(ov, optimize=True)
    n += 1
print('eye overlays rebuilt', n)
