"""Install fire sheets (<base>_fire.png): the 10 trial frames in a 4x3 grid at half the
trial's size (combat draws creatures small). Hard-edged families get a 256-colour palette."""
import sys, os, json, glob
from PIL import Image
S = sys.argv[1]
J = {c['id']: c for c in json.load(open('assets/data/alchemons_creatures.json'))['creatures']}
done, total = [], 0
for p in sorted(glob.glob(S + '/actions/*_fire_spritesheet.png')):
    hid = os.path.basename(p)[:5]
    if hid not in J:
        continue
    im = Image.open(p).convert('RGBA')
    F = im.size[0] // 4
    assert im.size == (4 * F, 3 * F), (hid, im.size)
    pm = im          # at the trial's own size: sharp where a battle draws creatures large
    out = 'assets/images/' + J[hid]['image'].replace('.png', '_fire.png')
    if hid.startswith('MAN'):
        pm.save(out, optimize=True)
    else:
        pm.quantize(256, method=Image.FASTOCTREE, dither=Image.NONE).save(out, optimize=True)
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
a, b = s.index('  // GENERATED: fire species\n'), s.index('  // END GENERATED: fire')
rows = [done[i:i + 6] for i in range(0, len(done), 6)]
s = s[:a] + '  // GENERATED: fire species\n' + ''.join('  ' + ', '.join("'%s'" % h for h in r) + ',\n' for r in rows) + s[b:]
open(pth, 'w').write(s)
print(len(done), 'fire sheets,', total // (1024 * 1024), 'MB')
