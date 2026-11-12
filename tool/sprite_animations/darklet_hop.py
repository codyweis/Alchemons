"""Darklet's hop (724 px frames): squash and stretch about its feet, a lift, eyes shut in
happy arcs while it is in the air. Prints the head centre per frame for its ring."""
import sys
from PIL import Image, ImageDraw, ImageFilter
S = sys.argv[1]
F, C, PX, PY, SS = 724, 4, 361, 548, 4
sheet = Image.open('assets/images/creatures/uncommon/LET15_darklet_spritesheet.png').convert('RGBA')
HEAD = [315, 319, 323, 319]
base = []
for i in range(4):
    f = sheet.crop((i * F, 0, (i + 1) * F, F))
    m = Image.new('RGBA', (F, F))
    m.paste(f, (0, 315 - HEAD[i]))          # the sheet's own bob, taken out
    base.append(m)
SY = [1.00, 0.95, 0.86, 1.06, 1.04, 1.00, 1.00, 1.03, 0.93, 0.84, 1.05, 0.96, 1.02, 0.99, 1.00, 1.00]
SX = [1.00, 1.03, 1.09, 0.95, 0.97, 1.00, 1.00, 0.98, 1.05, 1.11, 0.96, 1.03, 0.99, 1.01, 1.00, 1.00]
H = [v * F / 512 for v in [0, 0, 0, 6, 16, 22, 22, 14, 0, 0, 0, 0, 0, 0, 0, 0]]
SHUT = [0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0]
EYES = [(304, 308, 17, 25), (378, 306, 17, 25)]
SKIN = base[0].getpixel((340, 370))
INK = (205, 200, 240, 255)


def shut(img):
    mask = Image.new('L', (F * SS, F * SS), 0)
    d = ImageDraw.Draw(mask)
    for x, y, rx, ry in EYES:
        d.ellipse(((x - rx - 12) * SS, (y - ry - 12) * SS, (x + rx + 12) * SS, (y + ry + 12) * SS), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(2 * SS)).resize((F, F), Image.LANCZOS)
    out = Image.composite(Image.new('RGBA', (F, F), SKIN), img, mask)
    lay = Image.new('RGBA', (F * SS, F * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for x, y, rx, ry in EYES:
        r = rx + 3
        d.arc(((x - r) * SS, (y - r * 0.5) * SS, (x + r) * SS, (y + r * 1.5) * SS), 200, 340, fill=INK, width=int(5.5 * SS))
    out.alpha_composite(lay.resize((F, F), Image.LANCZOS))
    return out


frames, heads = [], []
for k in range(16):
    src = base[k % 4]
    if SHUT[k]:
        src = shut(src)
    sx, sy, h = SX[k], SY[k], H[k]
    g = {}
    for gy in range(0, F + 1, C):
        for gx in range(0, F + 1, C):
            g[gx, gy] = (PX + (gx - PX) / sx, PY + (gy + h - PY) / sy)
    mesh = [((x, y, x + C, y + C), g[x, y] + g[x, y + C] + g[x + C, y + C] + g[x + C, y]) for y in range(0, F, C) for x in range(0, F, C)]
    f = src.convert('RGBa').transform((F, F), Image.MESH, mesh, Image.BICUBIC).convert('RGBA')
    bb = f.getbbox()
    assert bb[1] > 0 and bb[0] > 0 and bb[2] < F, (k, bb)
    frames.append(f)
    heads.append(round(PY + (315 - PY) * sy - h, 1))
out = Image.new('RGBA', (4 * F, 4 * F))
for k, f in enumerate(frames):
    out.paste(f, ((k % 4) * F, (k // 4) * F))
out.save('assets/images/creatures/uncommon/LET15_darklet_hop.png', optimize=True)
print('head centre per hop frame:', heads)
strip = Image.new('RGB', (8 * 300, 300), (60, 60, 90))
for i, k in enumerate((0, 2, 3, 5, 7, 9, 10, 12)):
    b = Image.new('RGBA', (F, F), (60, 60, 90, 255))
    b.alpha_composite(frames[k])
    strip.paste(b.convert('RGB').crop((112, 112, 612, 612)).resize((300, 300), Image.LANCZOS), (i * 300, 0))
strip.save(S + '/actions/darklet_hop_strip.png')
