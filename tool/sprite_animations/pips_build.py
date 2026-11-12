"""Wing idles: keep each original's four drawn flap frames exactly as they sit (their rise
with the flap included) and add a slow layer over two flaps: a hover, a head nod and a
tail swing. Frame 0 is the original frame 0 at the head. 8 frames (2 rows x 4).

usage: wings_build.py <repo> <out> overlay|build [ids...]
"""
import sys, os, math, glob, json
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageStat

REPO, O, MODE = sys.argv[1], sys.argv[2], sys.argv[3]
ONLY = sys.argv[4:]
N, CELL = 8, 10

# neck pivot, head x range, tail side boundary xb(y) as (y, x), tail pivot, tail top y
P = {
    'PIP01': dict(neck=(600, 680), hx=620, hy=760, xb=[(200, 830), (600, 830), (700, 860), (800, 900)], tail=(900, 760), hip=830, foot=930),
    'PIP02': dict(neck=(600, 660), hx=600, hy=780, xb=[(300, 840), (600, 840), (720, 880)], tail=(890, 700), hip=830, foot=930),
    'PIP03': dict(neck=(590, 650), hx=580, hy=790, xb=[(300, 860), (1000, 860)], tail=(860, 700), hip=840, foot=940),
    'PIP04': dict(neck=(640, 640), hx=640, hy=770, xb=[(300, 760), (500, 800), (640, 850), (720, 880)], tail=(880, 640), hip=820, foot=920),
    'PIP05': dict(neck=(640, 650), hx=630, hy=780, xb=[(300, 900), (700, 900)], tail=(900, 700), hip=820, foot=920),
    'PIP06': dict(neck=(670, 700), hx=660, hy=820, xb=[(300, 860), (700, 860), (760, 880)], tail=(880, 720), hip=860, foot=950),
    'PIP07': dict(neck=(640, 660), hx=640, hy=770, xb=[(300, 850), (640, 830), (740, 850)], tail=(860, 720), hip=830, foot=930),
    'PIP08': dict(neck=(660, 690), hx=650, hy=800, xb=[(300, 810), (1000, 810)], tail=(810, 700), hip=830, foot=930),
    'PIP09': dict(neck=(650, 660), hx=640, hy=760, xb=[(300, 790), (560, 790), (700, 810)], tail=(840, 715), hip=830, foot=930),
    'PIP10': dict(neck=(630, 670), hx=620, hy=780, xb=[(300, 850), (1000, 850)], tail=(870, 715), hip=825, foot=920),
    'PIP11': dict(neck=(650, 680), hx=640, hy=770, xb=[(300, 830), (600, 830), (720, 850)], tail=(890, 760), hip=830, foot=930),
    'PIP12': dict(neck=(660, 690), hx=650, hy=790, xb=[(300, 790), (640, 790), (740, 830)], tail=(860, 730), hip=830, foot=930),
    'PIP13': dict(neck=(650, 680), hx=640, hy=790, xb=[(250, 760), (500, 800), (640, 840), (720, 860)], tail=(890, 715), hip=830, foot=930),
    'PIP14': dict(neck=(630, 650), hx=620, hy=770, xb=[(300, 880), (1000, 880)], tail=(900, 700), hip=825, foot=920),
    'PIP15': dict(neck=(670, 690), hx=660, hy=800, xb=[(300, 860), (1000, 860)], tail=(890, 740), hip=830, foot=930),
    'PIP16': dict(neck=(670, 680), hx=660, hy=790, xb=[(300, 850), (1000, 850)], tail=(910, 660), hip=820, foot=915),
    'PIP17': dict(neck=(650, 690), hx=640, hy=790, xb=[(300, 810), (1000, 810)], tail=(860, 715), hip=830, foot=930),
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
    return (1 - sm((x - p['hx'] + 80) / 80)) * sm((p['hy'] - y) / 100)


def tail_w(p, x, y):
    return sm((x - xb(p, y)) / 50) * (1 - sm((y - p['tail'][1] - 20) / 60))


def disp(p, x, y, ph):
    s = math.sin
    nx, ny = p['neck']
    dx = 0.0
    dy = -4.0 * sm((p['foot'] - y) / (p['foot'] - p['hip'])) * s(ph)   # breath: the legs give
    hw = head_w(p, x, y)
    if hw > 0:
        # the head trails the body and nods about the neck; both are at rest in frame 0
        dy += -2.5 * hw * (s(ph - 0.7) - s(-0.7))
        rx, ry = rot(x, y, nx, ny, 1.3 * (s(ph - 1.0) - s(-1.0)))
        dx += hw * rx
        dy += hw * ry
    tw = tail_w(p, x, y)
    if tw > 0:
        tx, ty = p['tail']
        d = math.hypot(x - tx, y - ty)
        rx, ry = rot(x, y, tx, ty, 2.2 * s(ph - 1.6 - d / 240))
        dx += tw * rx
        dy += tw * ry
    return dx, dy


def entry(hid):
    J = json.load(open(REPO + '/assets/data/alchemons_creatures.json'))['creatures']
    return next(c for c in J if c['id'] == hid)


def sheet_path(hid):
    return REPO + '/assets/images/' + entry(hid)['image'].replace('.png', '_spritesheet.png')


def frames_of(hid):
    a = Image.open(sheet_path(hid)).convert('RGBA')
    assert a.size == (4800, 1200), (hid, a.size)
    return [a.crop((i * 1200, 0, (i + 1) * 1200, 1200)) for i in range(4)]


BG = (14, 14, 18, 255)
font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 22)


def cell(f, n):
    c = Image.new('RGBA', (1200, 1200), BG)
    c.alpha_composite(f)
    return c.resize((n, n), Image.LANCZOS).convert('RGB')


def build(hid):
    p = P[hid]
    orig = frames_of(hid)
    l, t, r, b = [v * 16 for v in orig[0].getchannel('A').reduce(16).point(lambda v: 255 if v > 100 else 0).getbbox()]
    keep = Image.new('L', (1200, 1200), 0)
    keep.paste(255, (max(0, l - 150), max(0, t - 150), min(1200, r + 150), min(1200, b + 150)))
    for cx in (0, 1186):
        for cy in (0, 1186):
            keep.paste(0, (cx, cy, cx + 14, cy + 14))   # the sheet's corner marks
    raw = orig
    orig = [Image.composite(f, Image.new('RGBA', f.size), keep) for f in orig]   # drop stray specks far from the body
    box = (p['hx'] - 60, 690, int(xb(p, 800)) + 60, min(1200, b + 8))
    ref, ref_s, offs = orig[0].crop(box), orig[0].crop(box).reduce(2), [(0, 0)]
    for i in (1, 2, 3):
        def err(dx, dy, sc=1):
            c = orig[i].crop((box[0] - dx, box[1] - dy, box[2] - dx, box[3] - dy))
            return sum(ImageStat.Stat(ImageChops.difference(ref_s if sc > 1 else ref, c.reduce(sc) if sc > 1 else c)).sum)
        best = min((err(dx, dy, 2), dx, dy) for dy in range(-40, 41, 2) for dx in range(-40, 41, 2))
        best = min((err(dx, dy), dx, dy) for dy in range(best[2] - 2, best[2] + 3) for dx in range(best[1] - 2, best[1] + 3))
        offs.append(best[1:])
        moved = Image.new('RGBA', (1200, 1200))
        moved.paste(orig[i], (best[1], best[2]))
        orig[i] = moved
    _p = O + '/offs.json'
    _d = json.load(open(_p)) if os.path.exists(_p) else {}
    _d[hid] = offs
    json.dump(_d, open(_p, 'w'))
    hard = sum(sum(f.getchannel('A').histogram()[1:255]) for f in orig) < 8000
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
        f = orig[i % 4].convert('RGBa').transform((1200, 1200), Image.MESH, mesh, Image.BICUBIC).convert('RGBA')
        if hard:
            f.putalpha(f.getchannel('A').point(lambda v: 255 if v >= 128 else 0))
        out.append(f)
    name = os.path.basename(sheet_path(hid))[:-16]
    sheet = Image.new('RGBA', (4800, 2400))
    for i, f in enumerate(out):
        sheet.paste(f, ((i % 4) * 1200, (i // 4) * 1200))
    sheet.save('%s/%s_idle_spritesheet.png' % (O, name), optimize=True)
    n = 500
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
    chk = Image.new('RGB', (800, 400), BG[:3])
    chk.paste(cell(out[2], 400), (0, 0))
    chk.paste(cell(out[6], 400), (400, 0))   # bottom of the hover
    chk.save('%s/%s_check.png' % (O, hid))
    same0 = out[0].tobytes() == orig[0].tobytes()
    print(hid, name[6:], 'hard' if hard else 'soft', 'body offsets removed', offs[1:], 'frame bboxes', out[3].getbbox(), out[6].getbbox(), flush=True)


def overlay(ids):
    S = Image.new('RGB', (6 * 330, 3 * 330), (60, 60, 70))
    for k, hid in enumerate(ids):
        p = P[hid]
        c = Image.new('RGBA', (1200, 1200), (60, 60, 70, 255))
        c.alpha_composite(frames_of(hid)[0])
        d = ImageDraw.Draw(c)
        ty = p['tail'][1]
        d.line([(xb(p, y), y) for y in range(100, ty + 80, 10)], fill=(0, 255, 0, 255), width=6)
        d.line((xb(p, ty + 80), ty + 80, 1150, ty + 80), fill=(0, 255, 0, 255), width=6)
        d.line((p['hx'], 60, p['hx'], p['hy'], 60, p['hy']), fill=(255, 255, 0, 255), width=5)
        for (x, y), col in ((p['neck'], (255, 0, 255, 255)), (p['tail'], (0, 255, 255, 255))):
            d.ellipse((x - 16, y - 16, x + 16, y + 16), fill=col)
        for yy in (p['hip'], p['foot']):
            d.line((100, yy, 1100, yy), fill=(255, 255, 255, 255), width=4)
        d.text((20, 20), hid, fill='white', font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 60))
        S.paste(c.resize((330, 330), Image.LANCZOS).convert('RGB'), ((k % 6) * 330, (k // 6) * 330))
    S.save(O + '/overlay.png')


if MODE in ('overlay', 'build'):
    ids = ONLY or sorted(P)
    if MODE == 'overlay':
        overlay(ids)
    else:
        for h in ids:
            build(h)
