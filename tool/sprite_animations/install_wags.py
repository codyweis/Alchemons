"""Install the Manes', Horns', Wings' and Pips' wag sheets beside each idle sheet (<base>_wag.png): the tail wag
(or, with no tail to wag, the shimmy). Also their albino eye layers (<base>_wag_albino_eyes.png),
the species list in lib/widgets/creature_actions.dart, and each one's head track for the
costumes, as a fourth list (hop, sleep, attack, wag) in lib/models/costume_action_tracks.dart.
Manes keep full colour for their glow; Horns, Wings and Pips take a 256-colour palette, as their hops
do.

Made by `ANIMS=wag KEEP=1 actions_build.py <scratch> MAN|HOR|WNG|PIP` (each species' head track is taken
from the latest run that made it, a full run or an ONLY= one). Run from the repo root with the scratch venv:

  install_wags.py <scratch>
"""
import sys, os, json, glob, re
from PIL import Image

S = sys.argv[1]
J = {c['id']: c for c in json.load(open('assets/data/alchemons_creatures.json'))['creatures']}
done, total = [], 0
for p in sorted(glob.glob(S + '/actions/*_wag_spritesheet.png')):
    hid = os.path.basename(p)[:5]
    if hid not in J:
        continue
    im = Image.open(p).convert('RGBA')
    assert im.size[0] == 4 * (im.size[0] // 4) and im.size[1] == im.size[0], (hid, im.size)
    out = 'assets/images/' + J[hid]['image'].replace('.png', '_wag.png')
    if hid.startswith('MAN'):
        im.save(out, optimize=True)
    else:
        im.quantize(256, method=Image.FASTOCTREE, dither=Image.NONE).save(out, optimize=True)
    total += os.path.getsize(out)
    done.append(hid)
    # its albino eye layer, through the same motion (512 px a frame: the size an albino is baked at)
    ep = p.replace('_spritesheet.png', '_eyes.png')
    eo = out.replace('.png', '_albino_eyes.png')
    if os.path.exists(ep):
        e = Image.open(ep).convert('RGBA')
        n = e.size[0] // 4
        k = min(1.0, 512 / n)
        e.convert('RGBa').resize((int(e.size[0] * k), int(e.size[1] * k)), Image.LANCZOS).convert('RGBA').save(eo, optimize=True)
        total += os.path.getsize(eo)
    elif os.path.exists(eo):
        os.remove(eo)

# the species list
pth = 'lib/widgets/creature_actions.dart'
s = open(pth).read()
a, b = s.index('  // GENERATED: wag species\n'), s.index('  // END GENERATED: wag')
rows = [done[i:i + 6] for i in range(0, len(done), 6)]
s = s[:a] + '  // GENERATED: wag species\n' + ''.join('  ' + ', '.join("'%s'" % h for h in r) + ',\n' for r in rows) + s[b:]
open(pth, 'w').write(s)

# the head tracks: a fourth list per species
T = {}
for p in sorted(glob.glob(S + '/actions/tracks_*.json'), key=os.path.getmtime):      # the latest run wins
    for hid, per in json.load(open(p)).items():
        if 'wag' in per:
            T[hid] = per['wag']
pth = 'lib/models/costume_action_tracks.dart'
s = open(pth).read()


def row(tr):
    return '    [' + ', '.join('(%d, %s, %s, %s)' % (f[0], repr(float(f[1])), repr(float(f[2])), repr(float(f[3]))) for f in tr) + '],\n'


for hid in sorted(T):
    if hid not in done:
        continue
    m = re.search(r"  '%s': \[\n((?:    \[.*\],\n)+)  \],\n" % hid, s)
    if m is None:                                         # a species with no costume track yet
        a = s.index('};\n// dart format on')
        s = s[:a] + "  '%s': [\n    [],\n    [],\n    [],\n%s  ],\n" % (hid, row(T[hid])) + s[a:]
        continue
    lists = m.group(1).splitlines(keepends=True)[:3]
    s = s[:m.start(1)] + ''.join(lists) + row(T[hid]) + s[m.end(1):]
s = s.replace("// head moves through its hop, sleep and attack, for the costumes on it.",
              "// head moves through its hop, sleep, attack and wag, for the costumes on it.")
s = s.replace("// By species, then action (hop, sleep, attack), then frame",
              "// By species, then action (hop, sleep, attack, wag), then frame")
open(pth, 'w').write(s)
print(len(done), 'wag sheets,', total // (1024 * 1024), 'MB;', len([h for h in T if h in done]), 'tracks')
