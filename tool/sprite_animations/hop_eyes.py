"""Every creature's face at the top of its hop (eyes shut), beside its open-eyed rest frame."""
import sys, io, json, subprocess, os
from PIL import Image, ImageDraw, ImageFont
S, FAM = sys.argv[1], sys.argv[2]
ONLY = sys.argv[3].split(',') if len(sys.argv) > 3 else None
J = {c['id']: c for c in json.load(open('assets/data/alchemons_creatures.json'))['creatures']}
font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 18)
ids = ONLY or sorted(i for i in J if i.startswith(FAM) and os.path.exists('%s/actions/%s_fire_spritesheet.png' % (S, i)))
W, COLS = 220, 6
rows = -(-len(ids) // COLS)
out = Image.new('RGB', (COLS * (2 * W + 12), rows * (W + 26)), (14, 14, 18))
d = ImageDraw.Draw(out)
for j, hid in enumerate(ids):
    ep = 'assets/images/' + J[hid]['image'].replace('.png', '_albino_eyes.png')
    try:
        ov = Image.open(ep).convert('RGBA')
        E = ov.size[0] // 4
        bb = ov.crop((0, 0, E, E)).getbbox()
        cx, cy = (bb[0] + bb[2]) / 2 / E, (bb[1] + bb[3]) / 2 / E
    except Exception:
        cx, cy = 0.42, 0.47
    s = Image.open('%s/actions/%s_hop_spritesheet.png' % (S, hid)).convert('RGBA')
    F = s.size[0] // 4
    x0, y0 = (j % COLS) * (2 * W + 12), (j // COLS) * (W + 26)
    for i, k in enumerate((0, 6)):
        f = s.crop(((k % 4) * F, (k // 4) * F, (k % 4 + 1) * F, (k // 4 + 1) * F))
        h = int(F * 0.17)
        lift = 0 if k == 0 else int(F * 0.043)
        x, y = int(cx * F), int(cy * F) - lift + int(F * 0.02)
        c = Image.new('RGBA', (2 * h, 2 * h), (14, 14, 18, 255))
        c.alpha_composite(f.crop((x - h, y - h, x + h, y + h)))
        out.paste(c.convert('RGB').resize((W, W), Image.LANCZOS), (x0 + i * W, y0 + 24))
    d.text((x0 + 4, y0 + 2), J[hid]['name'] if hid != 'MAN18' else 'Earthmane (stones)', fill=(200, 170, 110), font=font)
out.save('%s/actions/hopeyes_%s.png' % (S, FAM))
print(out.size)
