"""Let idles (512 px frames, front-facing, no tail): keep each original's four drawn
frames, steady the body, and add a breath: feet planted, the body rides up and swells a
little, the head trails it. The two that float (Spiritlet, Lightlet) hover instead.
Frame 0 is the original frame 0. 8 frames (2 rows x 4). Darklet is left alone.

usage: lets_build.py <repo> <out> [ids...]
"""
import sys, os, math, json
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageStat

REPO, O = sys.argv[1], sys.argv[2]
ONLY = sys.argv[3:]
N, CELL, F = 8, 8, 512

# neck y (where the head meets the body); floats = no planted feet
P = {
    'LET01': dict(neck=322), 'LET02': dict(neck=322), 'LET03': dict(neck=345), 'LET04': dict(neck=311),
    'LET05': dict(neck=345), 'LET06': dict(neck=322), 'LET07': dict(neck=300), 'LET08': dict(neck=345),
    'LET09': dict(neck=322), 'LET10': dict(neck=311), 'LET11': dict(neck=322), 'LET12': dict(neck=311),
    'LET13': dict(neck=300), 'LET14': dict(neck=311, floats=True), 'LET16': dict(neck=345, floats=True),
    'LET17': dict(neck=300),
}


def sm(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def disp(p, x, y, ph):
    s = math.sin
    if p.get('floats'):
        dy = -3.0 * s(ph)
    else:
        dy = -3.0 * sm((p['foot'] - y) / (p['foot'] - p['hip'])) * s(ph)   # breath: the legs give
    # the body swells a little ahead of the rise; the head keeps its shape
    cy = (p['neck'] + p['hip']) / 2
    bell = math.exp(-((y - cy) / 45) ** 2)
    dx = (x - 256) * 0.02 * bell * (s(ph + 0.7) - s(0.7))
    # the head trails the body; at rest in frame 0
    dy += -1.6 * sm((p['neck'] + 15 - y) / 50) * (s(ph - 0.8) - s(-0.8))
    return dx, dy


def entry(hid):
    J = json.load(open(REPO + '/assets/data/alchemons_creatures.json'))['creatures']
    return next(c for c in J if c['id'] == hid)


def sheet_path(hid):
    return REPO + '/assets/images/' + entry(hid)['image'].replace('.png', '_spritesheet.png')


BG = (14, 14, 18, 255)
font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 22)


def cell(f, n):
    c = Image.new('RGBA', f.size, BG)
    c.alpha_composite(f)
    return c.resize((n, n), Image.LANCZOS).convert('RGB')


def build(hid):
    p = dict(P[hid])
    a = Image.open(sheet_path(hid)).convert('RGBA')
    assert a.size == (4 * F, F), (hid, a.size)
    raw = [a.crop((i * F, 0, (i + 1) * F, F)) for i in range(4)]
    b = raw[0].getbbox()[3]
    p['foot'], p['hip'] = b - 10, b - 52
    box = (140, p['neck'] + 10, 372, min(F, b + 6))
    ref, orig, offs = raw[0].crop(box), [raw[0]], [(0, 0)]
    for i in (1, 2, 3):
        if p.get('floats'):
            box_i = (140, p['neck'] - 120, 372, p['neck'] + 40)     # a floater is matched by its head
            r = raw[0].crop(box_i)
        else:
            box_i, r = box, ref
        best = min((sum(ImageStat.Stat(ImageChops.difference(r, raw[i].crop((box_i[0] - dx, box_i[1] - dy, box_i[2] - dx, box_i[3] - dy)))).sum), dx, dy)
                   for dy in range(-16, 17) for dx in range(-16, 17))
        offs.append(best[1:])
        moved = Image.new('RGBA', (F, F))
        moved.paste(raw[i], (best[1], best[2]))
        orig.append(moved)
    _p = O + '/offs.json'
    _d = json.load(open(_p)) if os.path.exists(_p) else {}
    _d[hid] = offs
    json.dump(_d, open(_p, 'w'))
    out = []
    for i in range(N):
        ph = 2 * math.pi * i / N
        g = {}
        for gy in range(0, F + 1, CELL):
            for gx in range(0, F + 1, CELL):
                dx, dy = disp(p, gx, gy, ph)
                g[gx, gy] = (gx - dx, gy - dy)
        mesh = [((x0, y0, x0 + CELL, y0 + CELL), g[x0, y0] + g[x0, y0 + CELL] + g[x0 + CELL, y0 + CELL] + g[x0 + CELL, y0])
                for y0 in range(0, F, CELL) for x0 in range(0, F, CELL)]
        out.append(orig[i % 4].convert('RGBa').transform((F, F), Image.MESH, mesh, Image.BICUBIC).convert('RGBA'))
    name = os.path.basename(sheet_path(hid))[:-16]
    sheet = Image.new('RGBA', (4 * F, 2 * F))
    for i, f in enumerate(out):
        sheet.paste(f, ((i % 4) * F, (i // 4) * F))
    sheet.save('%s/%s_idle_spritesheet.png' % (O, name), optimize=True)
    n = 440
    oc, nc, g = [cell(f, n) for f in raw], [cell(f, n) for f in out], []
    for k in range(N):
        c = Image.new('RGB', (2 * n + 20, n + 44), BG[:3])
        c.paste(oc[k % 4], (0, 44))
        c.paste(nc[k], (n + 20, 44))
        d = ImageDraw.Draw(c)
        d.text((16, 10), name[6:].upper() + '  ORIGINAL', fill=(200, 170, 110), font=font)
        d.text((n + 36, 10), 'NEW', fill=(200, 170, 110), font=font)
        g.append(c)
    g[0].save('%s/%s_side_by_side.gif' % (O, name), save_all=True, append_images=g[1:],
              duration=entry(hid)['spriteData']['frameDurationMs'], loop=0, optimize=True)
    chk = Image.new('RGB', (600, 300), BG[:3])
    chk.paste(cell(out[2], 300), (0, 0))
    chk.paste(cell(out[6], 300), (300, 0))
    chk.save('%s/%s_check.png' % (O, hid))
    print(hid, name[6:], 'floats' if p.get('floats') else 'stands', 'body offsets removed', offs[1:],
          'frame 0 unchanged:', ImageChops.difference(out[0], raw[0]).getbbox() is None,
          'bottoms', [f.getbbox()[3] for f in out], flush=True)


for h in (ONLY or sorted(P)):
    build(h)
