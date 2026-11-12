"""Install the hop sheets beside each idle sheet (<base>_hop.png) and list their species
in lib/widgets/creature_actions.dart. Hard-edged families are saved with a 256-colour
palette (a quarter of the size, no visible change); Manes keep full colour for their glow.
Run from the repo root with the scratch venv."""
import sys, os, json, glob, re
from PIL import Image
S = sys.argv[1]
J = {c['id']: c for c in json.load(open('assets/data/alchemons_creatures.json'))['creatures']}
done, total = [], 0
for p in sorted(glob.glob(S + '/actions/' + (sys.argv[2] if len(sys.argv) > 2 else '') + '*_hop_spritesheet.png')):
    hid = os.path.basename(p)[:5]
    if hid not in J:
        continue
    im = Image.open(p).convert('RGBA')
    assert im.size[0] == im.size[1] and im.size[0] % 4 == 0, (hid, im.size)
    out = 'assets/images/' + J[hid]['image'].replace('.png', '_hop.png')
    if hid.startswith('MAN'):
        im.save(out, optimize=True)
    else:
        im.quantize(256, method=Image.FASTOCTREE, dither=Image.NONE).save(out, optimize=True)
    total += os.path.getsize(out)
    done.append(hid)
    # its albino eye layer, through the same motion (512 px a frame: the size an albino is baked at)
    ep = p.replace('_spritesheet.png', '_eyes.png')
    eo = out.replace('.png', '_albino_eyes.png')
    if os.path.exists(ep) and hid != 'LET15':
        e = Image.open(ep).convert('RGBA')
        n = e.size[0] // 4
        k = min(1.0, 512 / n)
        e.convert('RGBa').resize((int(e.size[0] * k), int(e.size[1] * k)), Image.LANCZOS).convert('RGBA').save(eo, optimize=True)
        total += os.path.getsize(eo)
    elif os.path.exists(eo):
        os.remove(eo)
pth = 'lib/widgets/creature_actions.dart'
s = open(pth).read()
a, b = s.index('  // GENERATED: hop species\n'), s.index('  // END GENERATED: hop')
rows = [done[i:i + 6] for i in range(0, len(done), 6)]
body = ''.join('  ' + ', '.join("'%s'" % h for h in r) + ',\n' for r in rows)
s = s[:a] + '  // GENERATED: hop species\n' + body + s[b:]
open(pth, 'w').write(s)
print(len(done), 'hop sheets,', total // (1024 * 1024), 'MB')
