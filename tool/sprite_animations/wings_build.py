"""Wing idles: keep each original's four drawn flap frames exactly as they sit (their rise
with the flap included) and add a slow layer over two flaps: a hover, a head nod and a
tail swing. Frame 0 is the original frame 0 at the head. 8 frames (2 rows x 4).

usage: wings_build.py <repo> <out> overlay|build [ids...]
"""
import sys, os, math, glob, json
from PIL import Image, ImageDraw, ImageFont

REPO, O, MODE = sys.argv[1], sys.argv[2], sys.argv[3]
ONLY = sys.argv[4:]
N, CELL = 8, 10

# neck pivot, head x range, tail side boundary xb(y) as (y, x), tail pivot, tail top y
P = {
    'WNG01': dict(neck=(545, 600), hx=(310, 750), xb=[(700, 740), (1100, 740)], tail=(720, 960), ttop=800),
    'WNG02': dict(neck=(445, 564), hx=(250, 650), xb=[(700, 720), (860, 720), (920, 650)], tail=(650, 920), ttop=690),
    'WNG03': dict(neck=(580, 690), hx=(230, 715), xb=[(600, 850), (1100, 850)], tail=(850, 870), ttop=690),
    'WNG05': dict(neck=(445, 545), hx=(240, 735), xb=[(660, 790), (800, 780), (900, 740)], tail=(760, 860), ttop=660),
    'WNG06': dict(neck=(455, 550), hx=(240, 690), xb=[(780, 740), (900, 700), (960, 670)], tail=(690, 920), ttop=770),
    'WNG07': dict(neck=(445, 582), hx=(240, 680), xb=[(740, 720), (880, 690), (950, 660)], tail=(670, 900), ttop=735),
    'WNG08': dict(neck=(418, 573), hx=(200, 635), xb=[(820, 700), (900, 650), (980, 640)], tail=(650, 915), ttop=825),
    'WNG09': dict(neck=(436, 564), hx=(240, 715), xb=[(760, 700), (880, 640), (960, 600)], tail=(600, 900), ttop=750),
    'WNG10': dict(neck=(455, 555), hx=(256, 705), xb=[(790, 700), (900, 680)], tail=(680, 910), ttop=790),
    'WNG11': dict(neck=(418, 600), hx=(210, 635), xb=[(770, 760), (900, 700), (970, 660)], tail=(665, 930), ttop=765),
    'WNG12': dict(neck=(436, 545), hx=(250, 660), xb=[(760, 720), (880, 650), (960, 610)], tail=(600, 900), ttop=745),
    'WNG13': dict(neck=(482, 582), hx=(250, 705), xb=[(770, 790), (870, 740), (960, 680)], tail=(665, 915), ttop=765),
    'WNG14': dict(neck=(464, 573), hx=(250, 690), xb=[(830, 740), (900, 700), (960, 690)], tail=(700, 890), ttop=830),
    'WNG15': dict(neck=(445, 582), hx=(220, 715), xb=[(730, 770), (860, 740), (950, 690)], tail=(690, 900), ttop=715),
    'WNG16': dict(neck=(464, 564), hx=(240, 700), xb=[(790, 720), (880, 650), (960, 610)], tail=(600, 915), ttop=780),
    'WNG17': dict(neck=(409, 591), hx=(200, 635), xb=[(750, 740), (880, 670), (960, 630)], tail=(630, 930), ttop=745),
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
    h0, h1 = p['hx']
    return sm((ny + 40 - y) / 130) * sm((x - h0 + 60) / 60) * (1 - sm((x - h1) / 60))


def tail_w(p, x, y):
    return sm((x - xb(p, y)) / 50) * sm((y - p['ttop']) / 60)


def disp(p, x, y, ph):
    s = math.sin
    nx, ny = p['neck']
    dx, dy = 0.0, -4.0 * s(ph)                      # hover: the whole creature drifts
    bell = math.exp(-((y - ny - 190) / 130) ** 2) * (1 - sm((abs(x - nx - 40) - 170) / 80))
    dx += (x - nx - 40) * 0.012 * bell * s(ph)       # chest
    hw = head_w(p, x, y)
    if hw > 0:
        rx, ry = rot(x, y, nx, ny, 1.3 * s(ph))      # nod about the neck
        dx += hw * rx
        dy += hw * ry
    tw = tail_w(p, x, y)
    if tw > 0:
        tx, ty = p['tail']
        d = math.hypot(x - tx, y - ty)
        rx, ry = rot(x, y, tx, ty, 2.4 * s(ph - 0.8 - d / 220))
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
    oc, nc, g = [cell(f, n) for f in orig], [cell(f, n) for f in out], []
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
    chk.paste(cell(out[3], 400), (0, 0))     # wings up, near the top of the hover
    chk.paste(cell(out[6], 400), (400, 0))   # bottom of the hover
    chk.save('%s/%s_check.png' % (O, hid))
    same0 = out[0].tobytes() == orig[0].tobytes()
    print(hid, name[6:], 'hard edges' if hard else 'soft edges', 'frame bboxes', out[3].getbbox(), out[6].getbbox(), flush=True)


def overlay(ids):
    S = Image.new('RGB', (6 * 330, 3 * 330), (60, 60, 70))
    for k, hid in enumerate(ids):
        p = P[hid]
        fr = frames_of(hid)
        c = Image.new('RGBA', (1200, 1200), (60, 60, 70, 255))
        ghost = fr[3].copy()
        ghost.putalpha(ghost.getchannel('A').point(lambda v: v // 3))
        c.alpha_composite(ghost)
        c.alpha_composite(fr[0])
        d = ImageDraw.Draw(c)
        d.line([(xb(p, y), y) for y in range(p['ttop'], 1150, 10)], fill=(0, 255, 0, 255), width=6)
        d.line((xb(p, p['ttop']), p['ttop'], 1150, p['ttop']), fill=(0, 255, 0, 255), width=6)
        nx, ny = p['neck']
        d.rectangle((p['hx'][0], 60, p['hx'][1], ny + 40), outline=(255, 255, 0, 255), width=4)
        for (x, y), col in ((p['neck'], (255, 0, 255, 255)), (p['tail'], (0, 255, 255, 255))):
            d.ellipse((x - 16, y - 16, x + 16, y + 16), fill=col)
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
