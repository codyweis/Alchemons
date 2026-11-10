"""Labels the enemy roster with the codes the user refers to (A1 ... O4).

Render the raw sheets first, then label them:

  ENEMY_LOOK_OUT=dir flutter test test/enemy_look_preview_test.dart \
    --tags preview --plain-name "every type"
  python3 label_roster.py dir out.png

Rows A-K are every_type.png (columns are elements, or the variants named
under them); M-O are every_boss.png. L is retired: it was the matte elite
mock, kept apart from K until matte became the elite look.
"""
import sys
from PIL import Image, ImageDraw, ImageFont

src, dst = sys.argv[1], sys.argv[2]
F = '/System/Library/Fonts/Supplemental/Arial.ttf'
FB = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'
font = ImageFont.truetype(F, 22)
small = ImageFont.truetype(F, 17)
big = ImageFont.truetype(F, 28)
code = ImageFont.truetype(FB, 22)
gold, grey, bg = (214, 196, 150), (150, 146, 160), (14, 15, 22)
et = Image.open(f'{src}/every_type.png').convert('RGB')
eb = Image.open(f'{src}/every_boss.png').convert('RGB')
C, LW, BC, S = 180, 230, 260, 0.75
els = ['Fire', 'Water', 'Plant', 'Lightning', 'Spirit', 'Dark']
rows = [
    ('Wisp', None), ('Drone: bead', None), ('Drone: sliver', None),
    ('Drone: swarm', None), ('Sentinel', None), ('Phantom', None),
    ('Brute', None), ('Colossus', None), ('Outbreak core', None),
    ('Behaviour marks', ['summoner', 'splitter', 'breaker', 'mender',
                         'breaker (brute)', 'splitter (phantom)']),
    ('Elites', ['sentinel, bulwarked', 'sentinel, vampiric',
                'phantom, relentless', 'phantom, volatile',
                'brute, overclocked', 'colossus, vampiric']),
]
sections = [('Swarm', 0, 6), ('Heavies', 6, 9), ('Variants', 9, 10),
            ('Elites', 10, 11)]
bosses = ['Comet (charger)', 'Singularity (gunner)', 'Ouroboros (skirmisher)',
          'Spire (bulwark)', 'Hive (carrier)', 'Armillary (warden)']
bc = int(BC * S)
W = LW + max(6 * C, 6 * bc)
out = Image.new('RGB', (W, 120 + len(sections) * 38 + len(rows) * C
                        + 90 + 3 * bc + 60), bg)
d = ImageDraw.Draw(out)


def tag(x, y, t):
    tw = d.textlength(t, font=code)
    d.rounded_rectangle((x + 6, y + 6, x + 16 + tw, y + 34), radius=5,
                        fill=(34, 32, 44))
    d.text((x + 11, y + 8), t, fill=(240, 222, 170), font=code)


def centred(x, y, t, f=small, fill=grey):
    d.text((x - d.textlength(t, font=f) / 2, y), t, fill=fill, font=f)


y = 14
d.text((16, y), 'Every enemy type', fill=gold, font=big)
y += 50
for i, e in enumerate(els):
    centred(LW + i * C + C / 2, y, e)
y += 26
for name, a, b in sections:
    d.text((16, y + 6), name.upper(), fill=gold, font=small)
    d.line((LW, y + 16, W - 16, y + 16), fill=(50, 48, 60))
    y += 30
    for r in range(a, b):
        label, cols = rows[r]
        letter = chr(ord('A') + r)
        out.paste(et.crop((0, r * C, 6 * C, (r + 1) * C)), (LW, y))
        d.text((16, y + C / 2 - 12), f'{letter}  {label}', fill=gold,
               font=font)
        for i in range(6):
            tag(LW + i * C, y, f'{letter}{i + 1}')
            if cols:
                centred(LW + i * C + C / 2, y + C - 24, cols[i])
        y += C
    y += 8
y += 20
d.text((16, y), 'BOSSES', fill=gold, font=small)
d.line((LW, y + 10, W - 16, y + 10), fill=(50, 48, 60))
y += 26
for i, n in enumerate(bosses):
    centred(LW + i * bc + bc / 2, y, n)
y += 24
out.paste(eb.resize((int(eb.size[0] * S), int(eb.size[1] * S)),
                    Image.LANCZOS), (LW, y))
for r, lab in enumerate(['Fire', 'Crystal', 'States']):
    letter = chr(ord('M') + r)
    d.text((16, y + r * bc + bc / 2 - 12), f'{letter}  {lab}', fill=gold,
           font=font)
    for i in range(6 if r < 2 else 4):
        tag(LW + i * bc, y + r * bc, f'{letter}{i + 1}')
for i, n in enumerate(['charging', 'shielded', 'enraged',
                       'survival boss, hurt']):
    centred(LW + i * bc + bc / 2, y + 3 * bc - 22, n)
y += 3 * bc + 10
d.text((16, y), 'Boxes over the bosses are their level and name labels: '
       'text draws as boxes in a headless render.', fill=grey, font=small)
out.crop((0, 0, W, y + 34)).save(dst, optimize=True)
