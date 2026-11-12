"""Horn idles: keep each original's four drawn frames, steady the body, add a breath,
a head nod and a tail swing as one smooth displacement field. 8 frames (2 rows x 4).

usage: horns_build.py <repo> <out> overlay|build [ids...]
"""
import sys, os, math, glob, json
from PIL import Image, ImageChops, ImageStat, ImageDraw, ImageFont

REPO, O, MODE = sys.argv[1], sys.argv[2], sys.argv[3]
ONLY = sys.argv[4:]
N, CELL = 8, 10

# neck pivot, tail side boundary xb(y) as (y, x) points, tail pivot, hip y, foot y
P = {
    'HOR01': dict(neck=(560, 705), xb=[(300, 820), (650, 820), (780, 860), (1000, 870)], tail=(850, 950), hip=875, foot=985,
                  arm=(415, 725, 440, 735, 915)),
    'HOR02': dict(neck=(570, 720), xb=[(300, 820), (560, 820), (900, 770), (1000, 760)], tail=(770, 860), hip=930, foot=1010),
    'HOR03': dict(neck=(500, 720), xb=[(300, 850), (1000, 850)], tail=(840, 880), hip=900, foot=975, hx=690),
    'HOR04': dict(neck=(540, 725), xb=[(380, 790), (640, 790), (760, 690), (950, 660)], tail=(670, 880), hip=940, foot=1020),
    'HOR05': dict(neck=(545, 715), xb=[(300, 880), (560, 880), (700, 800), (900, 770)], tail=(790, 880), hip=935, foot=1010),
    'HOR06': dict(neck=(560, 710), xb=[(300, 870), (640, 870), (760, 830), (950, 800)], tail=(810, 870), hip=915, foot=985),
    'HOR07': dict(neck=(570, 700), xb=[(250, 830), (520, 830), (700, 840), (950, 800)], tail=(810, 860), hip=900, foot=980),
    'HOR08': dict(neck=(530, 715), xb=[(300, 780), (700, 780), (800, 760), (950, 740)], tail=(750, 880), hip=950, foot=1030),
    'HOR09': dict(neck=(575, 700), xb=[(200, 800), (640, 800), (760, 780), (1000, 740)], tail=(740, 920), hip=955, foot=1045),
    'HOR10': dict(neck=(545, 709), xb=[(300, 790), (600, 790), (760, 770), (1000, 740)], tail=(760, 860), hip=945, foot=1020),
    'HOR11': dict(neck=(545, 715), xb=[(300, 800), (640, 800), (900, 770), (1000, 760)], tail=(790, 850), hip=950, foot=1025),
    'HOR12': dict(neck=(560, 720), xb=[(300, 790), (740, 790), (850, 760), (1000, 730)], tail=(735, 950), hip=960, foot=1030),
    'HOR13': dict(neck=(570, 705), xb=[(300, 830), (530, 840), (700, 850), (950, 810)], tail=(815, 870), hip=900, foot=980),
    'HOR14': dict(neck=(540, 715), xb=[(300, 800), (700, 800), (780, 680), (1014, 640)], tail=(660, 950), hip=1200, foot=1300),
    'HOR15': dict(neck=(575, 715), xb=[(300, 800), (500, 800), (650, 810), (950, 790)], tail=(800, 880), hip=880, foot=955),
    'HOR16': dict(neck=(582, 700), xb=[(300, 1100), (720, 1100), (780, 760), (1050, 720)], tail=(740, 960), hip=940, foot=1015),
    'HOR17': dict(neck=(580, 710), xb=[(300, 800), (560, 800), (700, 840), (820, 840), (950, 790)], tail=(790, 870), hip=870, foot=950),
}


def sm(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def rot(x, y, px, py, deg):
    a = math.radians(deg)
    dx, dy = x - px, y - py
    return (dx * math.cos(a) - dy * math.sin(a) - dx, dx * math.sin(a) + dy * math.cos(a) - dy)


def xb(p, y):
    pts = p['xb']
    if y <= pts[0][0]:
        return pts[0][1]
    for (y0, x0), (y1, x1) in zip(pts, pts[1:]):
        if y <= y1:
            return x0 + (x1 - x0) * (y - y0) / (y1 - y0)
    return pts[-1][1]


def head_w(p, x, y):
    nx, ny = p['neck']
    top = min(xb(p, y) - 60, p.get('hx', 9999))
    low = min(top, nx + 140)
    lim = top + (low - top) * sm((y - (ny - 150)) / 90)
    return sm((ny + 40 - y) / 130) * (1 - sm((x - lim) / 60))


def disp(p, x, y, ph):
    s = math.sin
    nx, ny = p['neck']
    dx = dy = 0.0
    dy += -5.0 * sm((p['foot'] - y) / (p['foot'] - p['hip'])) * s(ph)
    cy = (ny + min(p['hip'], 960)) / 2 + 20
    bell = math.exp(-((y - cy) / 130) ** 2) * (1 - sm((abs(x - nx - 30) - 190) / 80))
    dx += (x - nx - 30) * 0.014 * bell * s(ph + 0.7)
    hw = head_w(p, x, y)
    if hw > 0:
        dy += -2.5 * hw * s(ph - 0.7)
        rx, ry = rot(x, y, nx, ny, 1.4 * s(ph - 1.0))
        dx += hw * rx
        dy += hw * ry
    tw = sm((x - xb(p, y)) / 50) * (1 - sm((y - p['tail'][1] - 50) / 60))  # legs under the tail root stay put
    if tw > 0:
        tx, ty = p['tail']
        d = math.hypot(x - tx, y - ty)
        rx, ry = rot(x, y, tx, ty, 1.9 * s(ph - 1.6 - d / 260))
        dx += tw * rx
        dy += tw * ry
    if 'arm' in p:
        ax, ay, xe, y0, y1 = p['arm']
        aw = (1 - sm((x - xe) / 30)) * sm((y - y0) / 30) * (1 - sm((y - y1) / 30))
        if aw > 0:
            rx, ry = rot(x, y, ax, ay, 1.6 * s(ph - 1.3))
            dx += aw * rx
            dy += aw * ry
    return dx, dy


def sheet_path(hid):
    return glob.glob(REPO + '/assets/images/creatures/rare/%s_*_spritesheet.png' % hid)[0]


def frames_of(hid):
    a = Image.open(sheet_path(hid)).convert('RGBA')
    return [a.crop((i * 1200, 0, (i + 1) * 1200, 1200)) for i in range(4)]


def dur(hid):
    J = json.load(open(REPO + '/assets/data/alchemons_creatures.json'))
    cs = J if isinstance(J, list) else J.get('creatures', J)
    for c in cs:
        if c.get('id') == hid:
            return c['spriteData']['frameDurationMs']


BG = (14, 14, 18, 255)
font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 22)


def cell(f, n):
    c = Image.new('RGBA', (1200, 1200), BG)
    c.alpha_composite(f)
    return c.resize((n, n), Image.LANCZOS).convert('RGB')


def build(hid):
    p = P[hid]
    orig = frames_of(hid)
    nx, ny = p['neck']
    bottom = orig[0].getbbox()[3]
    box = (nx - 200, ny, nx + 250, min(1200, bottom + 5))
    ref = orig[0].crop(box)
    l, t, r, b = orig[0].getbbox()
    keep = Image.new('L', (1200, 1200), 0)
    keep.paste(255, (max(0, l - 150), max(0, t - 150), min(1200, r + 150), min(1200, b + 150)))
    orig_clean = [Image.composite(f, Image.new('RGBA', f.size), keep) for f in orig]   # drop stray specks far from the body
    orig, orig_raw = orig_clean, orig
    bases, offs = [orig[0].convert('RGBa')], [(0, 0)]
    for i in (1, 2, 3):
        def err(dx, dy, sc=1):
            c = orig[i].crop((box[0] - dx, box[1] - dy, box[2] - dx, box[3] - dy))
            r = ref
            if sc > 1:
                c, r = c.reduce(sc), ref_small
            return sum(ImageStat.Stat(ImageChops.difference(r, c)).sum)
        ref_small = ref.reduce(2)
        best = min((err(dx, dy, 2), dx, dy) for dy in range(-30, 31, 2) for dx in range(-30, 31, 2))
        best = min((err(dx, dy), dx, dy) for dy in range(best[2] - 2, best[2] + 3) for dx in range(best[1] - 2, best[1] + 3))
        offs.append(best[1:])
        moved = Image.new('RGBA', (1200, 1200))
        moved.paste(orig[i], (best[1], best[2]))
        bases.append(moved.convert('RGBa'))
    out = []
    for i in range(N):
        ph = 2 * math.pi * i / N
        g = {}
        for gy in range(0, 1201, CELL):
            for gx in range(0, 1201, CELL):
                dx, dy = disp(p, gx, gy, ph)
                g[gx, gy] = (gx - dx, gy - dy)
        mesh = [((x0, y0, x0 + CELL, y0 + CELL), g[x0, y0] + g[x0, y0 + CELL] + g[x0 + CELL, y0 + CELL] + g[x0 + CELL, y0])
                for y0 in range(0, 1200, CELL) for x0 in range(0, 1200, CELL)]
        f = bases[i % 4].transform((1200, 1200), Image.MESH, mesh, Image.BICUBIC).convert('RGBA')
        src_a = orig[i % 4].getchannel('A').histogram()
        if sum(src_a[1:255]) < 2000:   # hard-edged art stays hard-edged
            f.putalpha(f.getchannel('A').point(lambda v: 255 if v >= 128 else 0))
        out.append(f)
    name = os.path.basename(sheet_path(hid))[:-16]
    sheet = Image.new('RGBA', (4800, 2400))
    for i, f in enumerate(out):
        sheet.paste(f, ((i % 4) * 1200, (i // 4) * 1200))
    sheet.save('%s/%s_idle_spritesheet.png' % (O, name), optimize=True)
    n = 500
    oc, nc, g = [cell(f, n) for f in orig_raw], [cell(f, n) for f in out], []
    for k in range(N):
        c = Image.new('RGB', (2 * n + 20, n + 44), BG[:3])
        c.paste(oc[k % 4], (0, 44))
        c.paste(nc[k], (n + 20, 44))
        d = ImageDraw.Draw(c)
        d.text((16, 10), name[6:].upper() + '  ORIGINAL', fill=(200, 170, 110), font=font)
        d.text((n + 36, 10), 'NEW', fill=(200, 170, 110), font=font)
        g.append(c)
    g[0].save('%s/%s_side_by_side.gif' % (O, name), save_all=True, append_images=g[1:], duration=dur(hid), loop=0, optimize=True)
    # check cell: frame 2 (top of the breath) and frame 6 (bottom)
    chk = Image.new('RGB', (800, 400), BG[:3])
    chk.paste(cell(out[2], 400), (0, 0))
    chk.paste(cell(out[6], 400), (400, 0))
    chk.save('%s/%s_check.png' % (O, hid))
    print(hid, name[6:], 'body offsets removed:', offs[1:], 'frames bbox', out[2].getbbox(), out[6].getbbox(), flush=True)


def overlay(ids):
    S = Image.new('RGB', (6 * 330, 3 * 330), (60, 60, 70))
    for k, hid in enumerate(ids):
        p = P[hid]
        f = frames_of(hid)[0]
        c = Image.new('RGBA', (1200, 1200), (60, 60, 70, 255))
        c.alpha_composite(f)
        d = ImageDraw.Draw(c)
        pts = [(xb(p, y), y) for y in range(100, 1150, 10)]
        d.line(pts, fill=(0, 255, 0, 255), width=6)
        hp = [(xb(p, y) - 60 + (min(xb(p, y) - 60, p['neck'][0] + 140) - (xb(p, y) - 60)) * sm((y - (p['neck'][1] - 150)) / 90), y)
              for y in range(100, p['neck'][1] + 40, 10)]
        d.line(hp, fill=(255, 255, 0, 255), width=4)
        for (x, y), col in ((p['neck'], (255, 0, 255, 255)), (p['tail'], (0, 255, 255, 255))):
            d.ellipse((x - 16, y - 16, x + 16, y + 16), fill=col)
        d.line((150, p['neck'][1] + 40, 1050, p['neck'][1] + 40), fill=(255, 0, 255, 255), width=3)
        for yy in (p['hip'], p['foot']):
            d.line((150, yy, 1050, yy), fill=(255, 255, 255, 255), width=4)
        d.text((20, 20), hid, fill='white', font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 60))
        S.paste(c.resize((330, 330), Image.LANCZOS).convert('RGB'), ((k % 6) * 330, (k // 6) * 330))
    S.save(O + '/overlay.png')


ids = ONLY or sorted(P)
if MODE == 'overlay':
    overlay(ids)
else:
    for h in ids:
        build(h)
