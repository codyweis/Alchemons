"""Face close-ups of every creature's hop (eyes shut), attack (lid) and sleep, one row each."""
import sys, io, json, subprocess, os
from PIL import Image, ImageDraw, ImageFont
S, FAM = sys.argv[1], sys.argv[2]
J = {c['id']: c for c in json.load(open('assets/data/alchemons_creatures.json'))['creatures']}
font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 16)
ids = sorted(i for i in J if i.startswith(FAM) and os.path.exists('%s/actions/%s_fire_spritesheet.png' % (S, i)))
W = 150
out = Image.new('RGB', (len(ids) * W, 3 * W + 20), (14, 14, 18))
d = ImageDraw.Draw(out)
for j, hid in enumerate(ids):
    try:
        ov = Image.open(io.BytesIO(subprocess.check_output(['git', 'show', 'HEAD:assets/images/' + J[hid]['image'].replace('.png', '_albino_eyes.png')], stderr=subprocess.DEVNULL))).convert('RGBA')
        E = ov.size[1] if ov.size[0] >= 4 * ov.size[1] else ov.size[0] // 4
        bb = ov.crop((0, 0, E, E)).getbbox()
        cx, cy = (bb[0] + bb[2]) / 2 / E, (bb[1] + bb[3]) / 2 / E
    except Exception:
        cx, cy = 0.42, 0.45
    for r, (n, k) in enumerate((('hop', 9), ('fire', 3), ('sleep', 4))):
        s = Image.open('%s/actions/%s_%s_spritesheet.png' % (S, hid, n)).convert('RGBA')
        F = s.size[0] // 4
        f = s.crop(((k % 4) * F, (k // 4) * F, (k % 4 + 1) * F, (k // 4 + 1) * F))
        h = int(F * 0.16)
        x, y = int(cx * F), int(cy * F) + int(F * (0.03 if n != 'hop' else 0.02))
        c = Image.new('RGBA', (2 * h, 2 * h), (14, 14, 18, 255))
        c.alpha_composite(f.crop((x - h, y - h, x + h, y + h)))
        out.paste(c.convert('RGB').resize((W, W), Image.LANCZOS), (j * W, 20 + r * W))
    d.text((j * W + 4, 2), J[hid]['name'], fill=(200, 170, 110), font=font)
out.save('%s/actions/eyes_%s.png' % (S, FAM))
print(out.size)
