"""Install sleep sheets (<base>_sleep.png): every other frame of the 16-frame trial, so 8
frames in 2 rows of 4. Hard-edged families get a 256-colour palette; Manes keep full colour."""
import sys, os, json, glob
from PIL import Image
S = sys.argv[1]
J = {c['id']: c for c in json.load(open('assets/data/alchemons_creatures.json'))['creatures']}
done, total = [], 0
for p in sorted(glob.glob(S + '/actions/*_sleep_spritesheet.png')):
    hid = os.path.basename(p)[:5]
    if hid not in J:
        continue
    im = Image.open(p).convert('RGBA')
    F = im.size[0] // 4
    assert im.size == (4 * F, 4 * F), (hid, im.size)
    out_im = Image.new('RGBA', (4 * F, 2 * F))
    for j, k in enumerate(range(0, 16, 2)):
        out_im.paste(im.crop(((k % 4) * F, (k // 4) * F, (k % 4 + 1) * F, (k // 4 + 1) * F)), ((j % 4) * F, (j // 4) * F))
    out = 'assets/images/' + J[hid]['image'].replace('.png', '_sleep.png')
    if hid.startswith('MAN'):
        out_im.save(out, optimize=True)
    else:
        out_im.quantize(256, method=Image.FASTOCTREE, dither=Image.NONE).save(out, optimize=True)
    total += os.path.getsize(out)
    done.append(hid)
pth = 'lib/widgets/creature_actions.dart'
s = open(pth).read()
a, b = s.index('  // GENERATED: sleep species\n'), s.index('  // END GENERATED: sleep')
rows = [done[i:i + 6] for i in range(0, len(done), 6)]
s = s[:a] + '  // GENERATED: sleep species\n' + ''.join('  ' + ', '.join("'%s'" % h for h in r) + ',\n' for r in rows) + s[b:]
open(pth, 'w').write(s)
print(len(done), 'sleep sheets,', total // (1024 * 1024), 'MB')
