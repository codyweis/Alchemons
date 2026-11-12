"""Lively Mane idles from one drawn frame each (1200 px).
Body: breath with planted feet, head nod, tail swing (the Horn rig).
Mane material: its own motion, rooted where it meets the body and strongest at the tips:
flame (licks outward), puff (cloud swell), sway (leaves, fins), rock (stones), spin (orb).
Glow: a pulsing halo under the sprite and a lift inside, where the element gives light.
8 frames (2 rows x 4).

usage: venv/bin/python manes2_build.py <scratch> overlay|build [ids...]
"""
import sys, os, math
import numpy as np
from scipy import ndimage as ndi
from PIL import Image, ImageDraw, ImageFont
S, MODE, ONLY = sys.argv[1], sys.argv[2], sys.argv[3:]
src = open(S + '/manes_build.py').read()
ns = dict(S=S, math=math)
exec(src[src.index("src = open"):src.index('BG = ')].replace("O = S + '/manes'", ''), ns)
P, U, disp = ns['P'], ns['U'], ns['disp']
O = S + '/manes'
N, DUR, F = 8, 120, 1200
BG = (14, 14, 18)
font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 22)
YY, XX = np.mgrid[0:F, 0:F].astype(np.float32)


def poly(*pts):
    return ('poly', pts)


def ell(cx, cy, rx, ry):
    return ('ell', (cx, cy, rx, ry))


def shape_mask(shapes):
    im = Image.new('L', (F, F), 0)
    d = ImageDraw.Draw(im)
    for kind, v in shapes:
        if kind == 'poly':
            d.polygon(v, fill=255)
        else:
            d.ellipse((v[0] - v[2], v[1] - v[3], v[0] + v[2], v[1] + v[3]), fill=255)
    return np.array(im) > 0


# ---- colour tests for glow (on float rgb 0..255) -----------------------------------------
def c_all(r, g, b):
    return np.ones_like(r, bool)


FLICK = [1.0, 0.45, 0.85, 0.3, 0.95, 0.55, 0.75, 0.35]

# parts: add (shapes), sub (shapes), mode, amp px, reach px (distance from the body at which it moves in full)
M = {
    'MAN01': dict(parts=[
        dict(add=[poly((190, 40), (900, 40), (900, 640), (745, 650), (650, 705), (600, 690), (608, 600), (590, 520), (604, 440), (580, 405), (480, 470),
                       (380, 490), (285, 438), (283, 560), (325, 700), (200, 700))], mode='flame', amp=11, reach=190),
        dict(add=[poly((775, 570), (960, 570), (960, 880), (845, 880), (795, 830))], mode='flame', amp=9, reach=110)],
        glow=[dict(of='parts', col=(255, 130, 50), halo=0.55, lift=0.10, pat='flick2')], body=1.5),
    'MAN02': dict(parts=[
        dict(add=[poly((170, 110), (910, 110), (910, 560), (770, 730), (700, 640), (650, 500), (560, 430), (440, 440), (300, 480), (285, 560), (300, 700),
                       (255, 745), (180, 560))], mode='sway', amp=7, reach=220),
        dict(add=[poly((790, 570), (935, 570), (935, 935), (805, 900))], mode='sway', amp=8, reach=160)],
        glow=[dict(of='sil', col=(120, 220, 255), halo=0.18, lift=0.0, pat='pulse')], body=1.5),
    'MAN03': dict(parts=[
        dict(add=[poly((640, 350), (830, 350), (830, 650), (705, 650), (650, 520))], mode='sway', amp=6, reach=110),
        dict(add=[poly((780, 580), (980, 580), (980, 800), (800, 800))], mode='rock', amp=3.0, pivot=(840, 770))],
        glow=[], glint=dict(test=lambda r, g, b: (r > 150) & (r - b > 35) & (b < 215), box=(250, 130, 990, 800)), body=1.7),
    'MAN04': dict(parts=[
        dict(add=[poly((330, 170), (640, 170), (655, 420), (560, 455), (400, 430), (330, 370))], mode='puff', amp=7, reach=90),
        dict(add=[poly((90, 240), (292, 240), (292, 545), (200, 525), (90, 400))], mode='rock', amp=5.0, pivot=(285, 470)),
        dict(add=[poly((600, 240), (935, 240), (935, 565), (700, 545), (600, 470))], mode='rock', amp=-5.0, pivot=(640, 470)),
        dict(add=[poly((722, 575), (905, 575), (905, 865), (780, 865), (732, 720))], mode='puff', amp=7, reach=90)],
        glow=[], body=1.5),
    'MAN05': dict(parts=[
        dict(add=[poly((150, 40), (930, 40), (930, 690), (150, 690))], sub=[ell(492, 517, 232, 226), poly((560, 620), (930, 690), (560, 690))],
             mode='ray', amp=3, reach=75)],
        glow=[], body=1.5, steam=dict(centre=(492, 517),
                                      jets=[((420, 320), (400, 276)), ((550, 330), (576, 270)), ((644, 420), (700, 380)), ((664, 590), (730, 586))])),
    'MAN06': dict(parts=[],
                  glow=[dict(test=lambda r, g, b: (r > 135) & (r - g > 55), col=(255, 80, 20), halo=1.0, lift=0.55, pat='pulse')], body=1.7),
    'MAN07': dict(parts=[
        dict(add=[ell(903, 640, 68, 68)], mode='spin'),
        dict(add=[poly((270, 60), (830, 60), (830, 600), (700, 560), (640, 420), (520, 320), (400, 380), (370, 470), (285, 330))], mode='jitter', amp=3.5, reach=150)],
        glow=[dict(test=lambda r, g, b: (r > 215) & (g > 200) & (b < r - 35), col=(255, 235, 120), halo=0.9, lift=0.5, pat='flick')], body=1.5),
    'MAN08': dict(parts=[
        dict(add=[poly((255, 185), (825, 185), (825, 790), (705, 790), (690, 640), (680, 520), (600, 480), (420, 490), (285, 470))], mode='ooze', amp=6, reach=170)],
        glow=[], body=1.7),
    'MAN09': dict(parts=[dict(add=[poly((780, 610), (935, 610), (935, 835), (790, 835))], mode='rock', amp=2.5, pivot=(830, 860))],
                  glow=[dict(of='sil', col=(150, 235, 255), halo=0.22, lift=0.0, pat='pulse')],
                  glint=dict(test=c_all, box=(180, 170, 940, 660)), body=1.6),
    'MAN10': dict(parts=[
        dict(add=[poly((215, 70), (795, 70), (795, 660), (705, 705), (665, 560), (600, 480), (400, 470), (300, 540), (290, 690), (215, 690))], mode='puff', amp=8, reach=150, drift=True),
        dict(add=[poly((560, 70), (720, 70), (720, 330), (560, 330))], mode='flame', amp=8, reach=120),
        dict(add=[poly((722, 785), (825, 785), (825, 915), (722, 915))], mode='puff', amp=5, reach=50)],
        glow=[], body=1.6),
    'MAN11': dict(parts=[],
                  glow=[dict(test=lambda r, g, b: (r > 215) & (b > 215) & (g > 140) & (g < 232), col=(250, 160, 255), halo=0.5, lift=0.25, pat='pulse')],
                  glint=dict(test=lambda r, g, b: (b > 215) & (r > 175) & (g < 232), box=(250, 70, 960, 1000)), body=1.7),
    'MAN12': dict(parts=[
        dict(add=[poly((200, 90), (875, 90), (875, 625), (705, 645), (640, 560), (560, 470), (430, 480), (350, 460), (285, 500), (280, 615), (215, 645))], mode='sway', amp=9, reach=230),
        dict(add=[poly((805, 605), (955, 605), (955, 855), (850, 855), (812, 790))], mode='sway', amp=8, reach=130)],
        glow=[], body=1.6),
    'MAN13': dict(parts=[],
                  glow=[dict(test=lambda r, g, b: (r > 165) & (b > 195) & (g < 195), col=(225, 90, 255), halo=0.6, lift=0.3, pat='pulse')], body=1.8),
    'MAN14': dict(parts=[
        dict(add=[poly((380, 50), (810, 50), (810, 570), (705, 570), (640, 330), (420, 255))], mode='flame', amp=10, reach=170),
        dict(add=[poly((575, 760), (815, 760), (815, 985), (560, 985), (560, 880))], mode='flame', amp=9, reach=120)],
        glow=[dict(test=lambda r, g, b: (r < 140) & (g > 215) & (b > 215), col=(90, 245, 255), halo=1.0, lift=0.5, pat='pulse'),
              dict(of='sil', col=(170, 245, 250), halo=0.30, lift=0.0, pat='pulse2')], body=1.6),
    'MAN15': dict(parts=[
        dict(add=[poly((270, 70), (795, 70), (795, 705), (705, 695), (690, 560), (640, 440), (560, 420), (400, 480), (300, 400))], mode='flame', amp=7, reach=170),
        dict(add=[poly((805, 450), (1055, 450), (1055, 855), (880, 855), (832, 765))], mode='flame', amp=9, reach=130)],
        glow=[dict(test=lambda r, g, b: (b > 215) & (r < 170), col=(110, 125, 255), halo=0.9, lift=0.45, pat='pulse'),
              dict(of='parts', col=(95, 60, 190), halo=0.45, lift=0.0, pat='pulse2')], body=1.6),
    'MAN16': dict(parts=[
        dict(add=[poly((180, 100), (820, 100), (820, 760), (180, 760))], sub=[ell(490, 480, 205, 215), poly((330, 690), (680, 690), (760, 760), (330, 760))],
             mode='ray', amp=9, reach=110)],
        glow=[dict(of='sil', col=(255, 238, 160), halo=0.85, lift=0.22, pat='pulse')], body=1.6),
    'MAN17': dict(parts=[
        dict(add=[poly((540, 80), (830, 80), (830, 440), (640, 300))], mode='sway', amp=10, reach=200)],
        glow=[], jelly=True, body=1.8),
    'MAN18': dict(parts=[
        dict(add=[poly((295, 185), (665, 185), (665, 335), (520, 335), (480, 300), (300, 345))], mode='rock', amp=2.2, pivot=(480, 335)),
        dict(add=[poly((790, 535), (955, 535), (955, 765), (790, 765))], mode='rock', amp=3.2, pivot=(872, 770))],
        glow=[], body=1.8),
}


def sm(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def art(hid):
    a = np.array(Image.open(U + P[hid]['f'] + '-image.png').convert('RGBA')).astype(np.float32)
    for sx in (slice(0, 40), slice(F - 40, F)):
        for sy in (slice(0, 40), slice(F - 40, F)):
            a[sy, sx] = 0
    return a


def prepare(hid):
    a = art(hid)
    sil = a[..., 3] > 128
    cfg = M[hid]
    masks = []
    for p in cfg['parts']:
        m = shape_mask(p['add'])
        if p.get('sub'):
            m &= ~shape_mask(p['sub'])
        masks.append(m & sil)
    union = np.zeros_like(sil)
    for m in masks:
        union |= m
    body = sil & ~union
    return a, sil, cfg, masks, union, body


def fields(cfg, masks, body, sil):
    """Per part: weight w (0 at the root, 1 at the tips), outward normal, distance."""
    out = []
    d_body = ndi.distance_transform_edt(~body).astype(np.float32)
    ds = ndi.gaussian_filter(d_body, 18)
    gy, gx = np.gradient(ds)
    gn = np.hypot(gx, gy) + 1e-3
    nx, ny = gx / gn, gy / gn
    for p, m in zip(cfg['parts'], masks):
        near = np.clip(ndi.gaussian_filter(ndi.binary_dilation(m, iterations=14).astype(np.float32), 9) * 1.5, 0, 1)
        if p['mode'] in ('rock', 'spin'):
            w = np.clip(ndi.gaussian_filter(ndi.binary_dilation(m, iterations=5).astype(np.float32), 4) * 1.6 - 0.3, 0, 1)
            # a rigid part: rooted only where it joins the body
            w = w * sm(d_body / 14) if p['mode'] == 'rock' else w
        else:
            w = sm(d_body / p['reach']) * near
        ys, xs = np.nonzero(m)
        c = (xs.mean(), ys.mean()) if len(xs) else (600, 600)
        out.append(dict(w=w.astype(np.float32), c=c))
    return out, d_body, nx, ny


def material_disp(cfg, fl, d, nx, ny, k):
    t = 2 * math.pi * k / N
    dx = np.zeros((F, F), np.float32)
    dy = np.zeros((F, F), np.float32)
    lx, ly = -ny, nx
    for p, f in zip(cfg['parts'], fl):
        w, mode, A = f['w'], p['mode'], p.get('amp', 0)
        cx, cy = f['c']
        if mode == 'flame':
            a1 = A * np.sin(t - d / 150 * 2 * math.pi + XX / 170)
            a2 = 0.45 * A * np.sin(2 * t - d / 85 * 2 * math.pi - XX / 60)
            s1 = 0.7 * A * np.sin(t - d / 210 * 2 * math.pi + 1.2 + XX / 110)       # the tongues lengthen and shorten
            dx += w * ((a1 + a2) * lx + s1 * nx)
            dy += w * ((a1 + a2) * ly + s1 * ny)
        elif mode == 'jitter':
            j = [0, 1, -0.6, 0.8, -1, 0.4, -0.3, 0.7][k]
            dx += w * A * j * nx
            dy += w * A * j * ny
        elif mode in ('puff', 'ray'):
            th = np.arctan2(YY - cy, XX - cx)
            lobes = 2 if mode == 'ray' else 3
            a1 = A * (0.55 * np.sin(t - lobes * th) + 0.45 * np.sin(t + 0.8))
            if mode == 'ray':
                a1 = A * (0.75 * np.sin(t) + 0.25 * np.sin(2 * t - 5 * th))
            dx += w * a1 * nx
            dy += w * a1 * ny
            if p.get('drift'):
                dx += w * 0.5 * A * np.sin(t - th * 2 + 1.0) * lx
                dy += w * 0.5 * A * np.sin(t - th * 2 + 1.0) * ly
        elif mode == 'boil':                      # steam: every puff swells in its own time, the whole cloud lifts on its jets and rolls round
            bx_, by_ = p['centre']
            R = np.hypot(XX - bx_, YY - by_) + 1e-3
            ux, uy = (XX - bx_) / R, (YY - by_) / R
            th = np.arctan2(YY - by_, XX - bx_)
            rad = A * (0.55 * np.sin(t + 0.4) + 0.75 * np.sin(2 * t - 7 * th) + 0.6 * np.sin(t + 5 * th + 1.0))
            tan = A * (0.9 * np.sin(t - 3 * th + 0.5) + 0.35 * np.sin(2 * t + 9 * th))
            dx += w * (rad * ux - tan * uy)
            dy += w * (rad * uy + tan * ux)
        elif mode == 'sway':
            a1 = A * np.sin(t - d / 420 * 2 * math.pi - 0.6) + 0.3 * A * np.sin(2 * t - d / 160 * 2 * math.pi + YY / 90)
            dx += w * a1
            dy += w * 0.25 * a1 * np.sign(XX - cx)
        elif mode == 'ooze':
            a1 = A * np.sin(t - YY / 260 * 2 * math.pi)
            dx += w * 0.5 * a1 * nx
            dy += w * (0.5 * a1 * ny + 0.6 * A * np.clip(np.sin(t - XX / 200), 0, 1))
        elif mode == 'rock':
            px, py = p['pivot']
            ang = math.radians(A * math.sin(t - 0.9))
            rx = (XX - px) * (math.cos(ang) - 1) - (YY - py) * math.sin(ang)
            ry = (XX - px) * math.sin(ang) + (YY - py) * (math.cos(ang) - 1)
            dx += w * rx
            dy += w * ry
    return dx, dy


def body_disp(p, k, gain, jelly):
    t = 2 * math.pi * k / N
    C = 20
    n = F // C + 1
    gx = np.zeros((n, n), np.float32)
    gy = np.zeros((n, n), np.float32)
    for j in range(n):
        for i in range(n):
            a = disp(p, i * C, j * C, t)
            b = disp(p, i * C, j * C, 0.0)
            gx[j, i], gy[j, i] = a[0] - b[0], a[1] - b[1]
    z = F / (n - 1)
    dx = ndi.zoom(gx, z, order=1)[:F, :F] * gain
    dy = ndi.zoom(gy, z, order=1)[:F, :F] * gain
    if jelly:
        foot = p['foot']
        s = 0.012 * math.sin(t + 0.5)
        dx += (XX - p['neck'][0]) * s * sm((foot - YY) / 500)
        dy += -(foot - YY) * s * 0.9
    return dx, dy


def warp(img, dx, dy, order=1):
    coords = np.array([YY - dy, XX - dx])
    if img.ndim == 2:
        return ndi.map_coordinates(img, coords, order=order, mode='constant')
    return np.stack([ndi.map_coordinates(img[..., c], coords, order=order, mode='constant') for c in range(img.shape[2])], -1)


def pat(name, k):
    t = 2 * math.pi * k / N
    if name == 'flick':
        return FLICK[k]
    if name == 'flick2':
        return 0.62 + 0.25 * math.sin(t) + 0.13 * math.sin(2 * t + 1.0)
    if name == 'pulse2':
        return 0.5 + 0.5 * math.sin(t + 2.0)
    return 0.5 + 0.5 * math.sin(t)


ST_FILL, ST_SHADE, ST_LINE = (222, 243, 253, 255), (196, 229, 251, 255), (150, 200, 245, 255)


def puff(d, x, y, r, turn=0.0):
    """A small cloud: four overlapping rounds under one outline, lit from the upper left."""
    if r < 9:
        return
    parts = []
    for ax, ay, rr in ((0, 0, 1.0), (-0.72, 0.28, 0.62), (0.68, 0.3, 0.66), (0.12, -0.6, 0.6)):
        c, sn = math.cos(turn), math.sin(turn)
        parts.append((x + (ax * c - ay * sn) * r, y + (ax * sn + ay * c) * r, rr * r))
    for px, py, pr in parts:
        d.ellipse((px - pr - 4, py - pr - 4, px + pr + 4, py + pr + 4), fill=ST_LINE)
    for px, py, pr in parts:
        d.ellipse((px - pr, py - pr, px + pr, py + pr), fill=ST_SHADE)
    for px, py, pr in parts:
        q = 0.8 * pr
        d.ellipse((px - 0.22 * pr - q, py - 0.22 * pr - q, px - 0.22 * pr + q, py - 0.22 * pr + q), fill=ST_FILL)


_edge = {}


def steam_layers(im, st, cloud, k, ox, oy):
    """Steam that comes out: puffs shoot along each jet, the cloud pushes out new lobes one
    after another, and small puffs break off the top, rise and thin away. Nothing is bent."""
    cx, cy = st['centre']
    if 'e' not in _edge:                           # the cloud's outer edge, by angle round the head
        e = []
        for deg in range(-205, 25, 19):
            a = math.radians(deg)
            r = 420
            while r > 150 and not cloud[int(cy + r * math.sin(a)), int(cx + r * math.cos(a))]:
                r -= 2
            if r > 200:
                e.append((a, r))
        _edge['e'] = e
    back = Image.new('RGBA', im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(back)
    u0 = k / N
    for i, (a, r) in enumerate(_edge['e']):
        ph = (i * 0.37) % 1.0
        g = 0.5 - 0.5 * math.cos(2 * math.pi * (u0 + ph))          # each lobe swells out and sinks back in its own time
        rl = 30 + 9 * ((i * 7) % 3)
        rr = r - rl * 0.75 + g * rl * 0.85
        puff(d, cx + ox + rr * math.cos(a), cy + oy + rr * math.sin(a), rl * (0.8 + 0.3 * g), a + i)
    for i, (deg, ph, rise) in enumerate(((-120, 0.0, 120), (-62, 0.5, 130))):
        a = math.radians(deg)                                       # puffs that leave the cloud
        r = max(rr_ for aa, rr_ in _edge['e'] if abs(aa - a) < 0.5)
        u = (u0 + ph) % 1.0
        x = cx + ox + (r - 22 + u * rise) * math.cos(a) + 14 * math.sin(2 * math.pi * u + i)
        y = cy + oy + (r - 22 + u * rise) * math.sin(a) - 30 * u
        puff(d, x, y, 30 * (1 - u) ** 0.6 if u < 0.85 else 0, i + 2 * u)
    back.alpha_composite(im)
    d = ImageDraw.Draw(back)
    for i, ((x0, y0), (x1, y1)) in enumerate(st['jets']):          # steam shooting out of each vent
        L = math.hypot(x1 - x0, y1 - y0)
        ux, uy = (x1 - x0) / L, (y1 - y0) / L
        for j in range(2):                                          # streaks rushing along the jet
            u = (u0 + i * 0.29 + j * 0.5) % 1.0
            a0, a1 = 4 + u * (L + 14), 4 + u * (L + 14) + 20
            for side in (-5, 4):
                d.line((x0 + ox + ux * a0 - uy * side * (0.6 + u), y0 + oy + uy * a0 + ux * side * (0.6 + u),
                        x0 + ox + ux * a1 - uy * side * (0.6 + u), y0 + oy + uy * a1 + ux * side * (0.6 + u)), fill=(250, 254, 255, 255), width=4)
    return back


def build(hid):
    a, sil, cfg, masks, union, body = prepare(hid)
    fl, d, nx, ny = fields(cfg, masks, body, sil)
    pm = a.copy()
    pm[..., :3] *= pm[..., 3:4] / 255
    unionf = union.astype(np.float32)
    spin = [(p, m) for p, m in zip(cfg['parts'], masks) if p['mode'] == 'spin']
    frames = []
    for k in range(N):
        src_k = pm
        if spin:                                   # the orb's own lightning turns inside it
            src_k = pm.copy()
            for p, m in spin:
                cx, cy, r, _ = p['add'][0][1]
                ang = math.radians([0, 140, 40, 250, 90, 300, 200, 330][k])
                X, Y = XX - cx, YY - cy
                inside = (np.hypot(X, Y) < r - 6)
                sx = cx + X * math.cos(ang) - Y * math.sin(ang)
                sy = cy + X * math.sin(ang) + Y * math.cos(ang)
                rot = np.stack([ndi.map_coordinates(pm[..., c], [sy, sx], order=1) for c in range(4)], -1)
                src_k[inside] = rot[inside]
        bx, by = body_disp(P[hid], k, cfg.get('body', 1.5), cfg.get('jelly'))
        mx, my = material_disp(cfg, fl, d, nx, ny, k)
        dx, dy = bx + mx, by + my
        f = warp(src_k, dx, dy)
        al = f[..., 3]
        hard = al >= 128
        rgb = np.where(hard[..., None], f[..., :3] / np.maximum(al[..., None], 1) * 255, 0)
        rgb = np.clip(rgb, 0, 255)
        alpha = hard.astype(np.float32)
        parts_w = warp(unionf, dx, dy) > 0.5
        halo = np.zeros((F, F), np.float32)
        hcol = np.zeros((F, F, 3), np.float32)
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        for gl in cfg['glow']:
            if gl.get('of') == 'parts':
                G = parts_w & hard
            elif gl.get('of') == 'sil':
                G = hard
            else:
                G = gl['test'](r, g, b) & hard
            Gf = G.astype(np.float32)
            pk = pat(gl['pat'], k)
            if gl['lift']:
                soft = np.clip(ndi.gaussian_filter(Gf, 2.0) * 1.3, 0, 1)[..., None]
                rgb = rgb + (255 - rgb) * soft * gl['lift'] * pk * hard[..., None]
            h = np.clip(ndi.gaussian_filter(Gf, 26) * 2.2 + ndi.gaussian_filter(Gf, 9) * 0.6, 0, 1) * gl['halo'] * (0.45 + 0.55 * pk)
            hcol = np.where((h > halo)[..., None], np.array(gl['col'], np.float32), hcol)
            halo = np.maximum(halo, h)
        gt = cfg.get('glint')
        if gt:                                     # a band of light crossing the facets
            x0, y0, x1, y1 = gt['box']
            u = (XX + YY) / math.sqrt(2)
            u0, u1 = (x0 + y0) / math.sqrt(2) - 80, (x1 + y1) / math.sqrt(2) + 80
            c = u0 + (u1 - u0) * (k / 5.0)         # crosses in the first six frames, then rests
            band = np.exp(-((u - c) / 34) ** 2) * (k < 6)
            G = gt['test'](r, g, b) & hard & (XX > x0) & (XX < x1) & (YY > y0) & (YY < y1)
            rgb = rgb + (255 - rgb) * (band * G * 0.75)[..., None]
        halo = np.clip(halo, 0, 0.9)
        oa = alpha + (1 - alpha) * halo
        orgb = np.where(hard[..., None], rgb, hcol)
        out = np.dstack([orgb, oa * 255]).clip(0, 255).astype(np.uint8)
        im = Image.fromarray(out, 'RGBA')
        if cfg.get('steam'):
            im = steam_layers(im, cfg['steam'], masks[0], k, float(bx[517, 492]), float(by[517, 492]))
        hb = Image.fromarray((hard * 255).astype(np.uint8)).getbbox()
        assert hb[0] > 2 and hb[1] > 2 and hb[2] < F - 2 and hb[3] < F - 2, (hid, k, hb)
        frames.append(im)
    name = hid + '_' + P[hid]['n']
    sheet = Image.new('RGBA', (4 * F, 2 * F))
    for i, f in enumerate(frames):
        sheet.paste(f, ((i % 4) * F, (i // 4) * F))
    sheet.save('%s/%s_idle2_spritesheet.png' % (O, name))
    still = Image.fromarray(a.astype(np.uint8), 'RGBA')
    n = 320
    g = []
    for k in range(N):
        c = Image.new('RGB', (2 * n + 10, n + 34), BG)
        c.paste(cell(still, n), (0, 34))
        c.paste(cell(frames[k], n), (n + 10, 34))
        dd = ImageDraw.Draw(c)
        dd.text((10, 6), P[hid]['n'].upper() + '  STILL', fill=(200, 170, 110), font=font)
        dd.text((n + 20, 6), 'IDLE', fill=(200, 170, 110), font=font)
        g.append(c)
    chk = Image.new('RGB', (4 * 450, 450), BG)
    for i, k in enumerate((0, 2, 4, 6)):
        chk.paste(cell(frames[k], 450), (i * 450, 0))
    chk.save('%s/%s_chk2.png' % (O, hid))
    g[0].save('%s/%s_idle2.gif' % (O, name), save_all=True, append_images=g[1:], duration=DUR, loop=0)
    print(hid, P[hid]['n'], flush=True)
    return g


def cell(f, n):
    c = Image.new('RGBA', f.size, BG + (255,))
    c.alpha_composite(f)
    return c.resize((n, n), Image.LANCZOS).convert('RGB')


def overlay(ids):
    Sx = Image.new('RGB', (6 * 400, 3 * 400), (60, 60, 70))
    for j, hid in enumerate(ids):
        a, sil, cfg, masks, union, body = prepare(hid)
        fl, d, nx, ny = fields(cfg, masks, body, sil)
        rgb = a[..., :3].copy()
        rgb[~sil] = (60, 60, 70)
        for f, col in zip(fl, [(255, 0, 255), (0, 255, 255), (255, 255, 0), (0, 255, 0)]):
            w = (f['w'] * sil)[..., None] * 0.75
            rgb = rgb * (1 - w) + np.array(col, np.float32) * w
        im = Image.fromarray(rgb.astype(np.uint8)).resize((400, 400), Image.LANCZOS)
        ImageDraw.Draw(im).text((8, 8), hid, fill='white', font=font)
        Sx.paste(im, ((j % 6) * 400, (j // 6) * 400))
    Sx.save(O + '/overlay2.png')


ids = ONLY or sorted(P)
if MODE == 'overlay':
    overlay(ids)
else:
    cells = [build(h) for h in ids]
    if not ONLY:
        cols = 3
        rows = -(-len(cells) // cols)
        w, h = cells[0][0].size
        fr = []
        for k in range(N):
            c = Image.new('RGB', (cols * (w + 16), rows * (h + 10)), BG)
            for j, g in enumerate(cells):
                c.paste(g[k], ((j % cols) * (w + 16), (j // cols) * (h + 10)))
            fr.append(c)
        fr[0].save(O + '/manes_lively_side_by_side.gif', save_all=True, append_images=fr[1:], duration=DUR, loop=0)
