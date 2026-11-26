"""Lively Mystic idles from one drawn frame each (1200 px, 8 frames, 2 rows x 4), for the
Mystics drawn anew as stills (mystic_stills/). The same pass as the Manes' (manes2_build.py):
the element's own material moves by itself, rooted at the body and strongest at its tips,
and what gives light glows. The body rig is its own, since a Mystic may face the viewer, hover
or carry its tail high: breath over planted feet (or a hover), the head turned about its neck,
the tail swung from its root, a wave running out along it.

usage: venv/bin/python mystics_build.py <scratch> overlay|build [ids...]
(<scratch> holds a copy of manes2_build.py; the sheets go to <scratch>/mystics)
"""
import sys, os, math, re, json
import numpy as np
from scipy import ndimage as ndi
from PIL import Image, ImageDraw, ImageFont
S, MODE, ONLY = sys.argv[1], sys.argv[2], sys.argv[3:]
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
U = HERE + '/mystic_stills/'
O = S + '/mystics'
os.makedirs(O, exist_ok=True)
N, DUR, F = 8, 120, 1200
BG = (14, 14, 18)
font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 22)
YY, XX = np.mgrid[0:F, 0:F].astype(np.float32)

# the Manes' material, glow and frame machinery
ns = dict(np=np, ndi=ndi, Image=Image, ImageDraw=ImageDraw, ImageFont=ImageFont, math=math,
          F=F, N=N, DUR=DUR, BG=BG, font=font, YY=YY, XX=XX, O=O, U=U)
_src = open(S + '/manes2_build.py').read()
exec(_src[_src.index('def poly('):_src.index('\nids = ONLY')], ns)
poly, ell, sm, c_all = ns['poly'], ns['ell'], ns['sm'], ns['c_all']

# body: head = the head's outline (it turns about neck), foot = where it stands (nothing
# below moves), hip = where the breath starts, cx = the chest's middle, tail = (root, outline)
# swung from its root, hover = a flyer's bob instead of planted feet
P = {
    'MYS01': dict(n='firemystic', head=[(425, 330), (600, 330), (615, 520), (480, 565), (415, 470)], neck=(505, 570), cx=505,
                  hip=880, foot=1060, breath=2.5),
    'MYS02': dict(n='watermystic', head=[(395, 300), (700, 300), (725, 470), (630, 530), (470, 505), (395, 425)], neck=(625, 640), cx=640,
                  hip=720, foot=1100),
    'MYS03': dict(n='earthmystic', head=[(255, 515), (705, 515), (710, 770), (560, 810), (330, 800), (245, 700)], neck=(475, 820), cx=480,
                  hip=900, foot=1060, nod=0.8),
    'MYS04': dict(n='airmystic', head=[(415, 330), (645, 330), (655, 485), (560, 535), (450, 515), (405, 440)], neck=(540, 570), cx=545,
                  hip=820, foot=990),
    'MYS05': dict(n='steammystic', head=[(165, 540), (665, 540), (665, 725), (500, 765), (250, 745), (165, 645)], neck=(560, 770), cx=520,
                  hip=880, foot=1080),
    'MYS06': dict(n='lavamystic', head=[(125, 375), (485, 375), (505, 700), (380, 765), (200, 725), (115, 620)], neck=(440, 700), cx=560,
                  hip=870, foot=1050,
                  tail=((895, 610), [(630, 95), (1150, 95), (1150, 650), (935, 650), (880, 575), (845, 335), (700, 335), (630, 255)])),
    'MYS07': dict(n='lightningmystic', head=[(115, 435), (425, 435), (425, 805), (300, 805), (145, 765), (105, 660)], neck=(410, 700), cx=520,
                  hip=860, foot=1030,
                  tail=((865, 455), [(790, 95), (1155, 95), (1155, 335), (900, 480), (800, 480)])),
    'MYS08': dict(n='mudmystic', head=[(275, 515), (600, 515), (625, 700), (565, 785), (330, 785), (265, 650)], neck=(610, 700), cx=640,
                  hip=820, foot=980, nod=0.8),
    'MYS09': dict(n='icemystic', head=[(110, 25), (705, 25), (705, 176), (618, 198), (615, 385), (335, 410), (200, 385), (110, 300)], neck=(285, 470), cx=420,
                  hip=880, foot=1100,
                  tail=((835, 650), [(700, 140), (1085, 140), (1085, 690), (850, 690), (805, 575), (815, 445), (700, 420)])),
}

FIRE_GLOW = [dict(of='parts', col=(255, 130, 50), halo=0.55, lift=0.10, pat='flick2'),
             dict(test=lambda r, g, b: (r > 235) & (g > 185) & (b < 170), col=(255, 205, 90), halo=0.45, lift=0.22, pat='flick')]

# parts: add/sub (shapes), col (a colour test the part is also held to, grown by `grow` px to take its
# outline), mode, amp px (degrees for rock), reach px (how far from the body it moves in full)
M = {
    'MYS01': dict(parts=[
        dict(add=[poly((50, 15), (480, 15), (470, 300), (412, 345), (400, 560), (330, 625), (190, 560), (50, 330)),
                  poly((605, 15), (1125, 15), (1125, 640), (760, 645), (640, 600), (612, 540), (612, 330))], mode='flame', amp=7, reach=190),
        dict(add=[poly((430, 165), (605, 165), (605, 328), (430, 328))], mode='flame', amp=6, reach=80),
        dict(add=[poly((620, 735), (995, 735), (995, 1035), (700, 1035), (640, 900))], mode='flame', amp=9, reach=160),
        dict(add=[poly((185, 560), (405, 560), (420, 800), (380, 1000), (330, 1100), (185, 1100))], mode='flame', amp=8, reach=170),
        dict(add=[poly((330, 1065), (900, 1030), (900, 1145), (330, 1145))], mode='flame', amp=4, reach=120)],
        glow=FIRE_GLOW, body=1.2),
    'MYS02': dict(parts=[
        dict(add=[poly((440, 105), (835, 105), (835, 565), (720, 565), (700, 335), (600, 285), (450, 300))], mode='sway', amp=6, reach=200),
        dict(add=[poly((95, 375), (425, 375), (425, 860), (385, 1065), (95, 1065))], mode='sway', amp=9, reach=260),
        dict(add=[poly((755, 575), (925, 575), (925, 825), (755, 825))], mode='sway', amp=5, reach=100),
        dict(add=[poly((825, 995), (1065, 995), (1065, 1125), (825, 1125))], mode='sway', amp=6, reach=130)],
        glow=[dict(of='sil', col=(120, 220, 255), halo=0.18, lift=0.0, pat='pulse')],
        glint=dict(test=lambda r, g, b: (g > 200) & (b > 225), box=(250, 120, 1070, 1120)), body=1.5),
    'MYS03': dict(parts=[
        dict(add=[poly((35, 145), (335, 145), (335, 525), (250, 560), (240, 800), (330, 950), (335, 1095), (35, 1095))], mode='rock', amp=1.3, pivot=(200, 1085)),
        dict(add=[poly((640, 145), (1115, 145), (1115, 1100), (650, 1100), (650, 820), (712, 780), (705, 525), (640, 525))], mode='rock', amp=-1.3, pivot=(900, 1090)),
        dict(add=[poly((335, 255), (640, 255), (640, 525), (335, 525))], mode='rock', amp=1.6, pivot=(480, 560))],
        glow=[dict(test=lambda r, g, b: (r > 215) & (g > 175) & (b < 150) & (r - b > 80), col=(255, 205, 110), halo=0.55, lift=0.3, pat='pulse')],
        body=1.8),
    'MYS04': dict(parts=[
        dict(add=[poly((125, 115), (425, 115), (445, 330), (412, 525), (370, 705), (195, 705), (125, 500)),
                  poly((765, 95), (1115, 95), (1115, 565), (955, 705), (760, 705), (700, 565), (722, 450), (765, 330))], mode='puff', amp=5, reach=90),
        dict(add=[poly((500, 135), (785, 135), (785, 455), (700, 455), (680, 305), (560, 300), (540, 330), (500, 330))], mode='sway', amp=8, reach=150),
        dict(add=[poly((105, 715), (515, 715), (515, 1045), (105, 1045))], mode='puff', amp=6, reach=80, drift=True),
        dict(add=[poly((545, 1000), (1015, 865), (1015, 1115), (545, 1115))], mode='sway', amp=7, reach=200)],
        glow=[dict(of='sil', col=(205, 230, 255), halo=0.16, lift=0.0, pat='pulse')], body=1.5),
    'MYS05': dict(parts=[
        dict(add=[poly((175, 115), (885, 115), (885, 480), (1105, 555), (1105, 885), (985, 905), (925, 705), (705, 685), (640, 565), (175, 565))],
             col=lambda r, g, b: (r > 170) & (g > 185) & (np.abs(r - b) < 40), grow=7, mode='flame', amp=6, reach=210)],
        glow=[dict(test=lambda r, g, b: (r > 200) & (r - b > 60) & (g > 110), col=(255, 165, 70), halo=0.8, lift=0.4, pat='pulse')], body=1.5),
    'MYS06': dict(parts=[
        dict(add=[poly((640, 95), (885, 95), (885, 320), (640, 320))], mode='flame', amp=8, reach=80),
        dict(add=[poly((185, 690), (365, 690), (365, 945), (185, 945))], mode='ooze', amp=6, reach=100)],
        glow=[dict(test=lambda r, g, b: (r > 135) & (r - g > 55), col=(255, 80, 20), halo=0.95, lift=0.2, pat='pulse')], body=1.6),
    'MYS07': dict(parts=[
        dict(add=[poly((790, 95), (1155, 95), (1155, 335), (900, 480), (800, 480))], mode='jitter', amp=4, reach=150)],
        glow=[dict(test=lambda r, g, b: (b > 220) & (g > 200) & (r < 200), col=(120, 230, 255), halo=0.9, lift=0.5, pat='flick')], body=1.5),
    'MYS08': dict(parts=[
        dict(add=[poly((520, 225), (825, 225), (825, 565), (700, 665), (560, 645), (520, 500))], mode='sway', amp=4, reach=200),
        dict(add=[poly((215, 215), (285, 215), (285, 385), (215, 385))], mode='rock', amp=2.0, pivot=(255, 385))],
        glow=[dict(test=lambda r, g, b: (r > 215) & (g > 135) & (b < 100), col=(255, 180, 80), halo=0.6, lift=0.3, pat='pulse')], body=1.8,
        # mud bubbling up in two of the craters on its back: (x, y, size, the frame it starts to swell)
        steam=dict(hid='MYS08', bubbles=[(780, 511, 24, 0), (875, 442, 20, 4)])),
    'MYS09': dict(parts=[
        dict(add=[poly((300, 105), (575, 105), (575, 335), (330, 335))], mode='rock', amp=1.5, pivot=(330, 265))],
        glow=[dict(of='sil', col=(150, 235, 255), halo=0.22, lift=0.0, pat='pulse'),
              dict(test=lambda r, g, b: (b > 190) & (r < 90) & (g < 175), col=(80, 170, 255), halo=0.5, lift=0.3, pat='pulse2')],
        glint=dict(test=c_all, box=(125, 105, 1085, 1110)), body=1.6),
}


def art(hid):
    a = np.array(Image.open(U + hid + '_' + P[hid]['n'] + '.png').convert('RGBA')).astype(np.float32)
    for sx in (slice(0, 40), slice(F - 40, F)):
        for sy in (slice(0, 40), slice(F - 40, F)):
            a[sy, sx] = 0                                   # the corner marks
    return a


def prepare(hid):
    a = art(hid)
    sil = a[..., 3] > 128
    cfg = M[hid]
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    masks = []
    for p in cfg['parts']:
        m = ns['shape_mask'](p['add'])
        if p.get('sub'):
            m &= ~ns['shape_mask'](p['sub'])
        if p.get('col'):                                    # only what is of its colour, and its outline
            c = p['col'](r, g, b) & sil
            c = ndi.binary_opening(c, iterations=2)
            m &= ndi.binary_dilation(c, iterations=p.get('grow', 6))
        masks.append(m & sil)
    union = np.zeros_like(sil)
    for m in masks:
        union |= m
    body = sil & ~union
    return a, sil, cfg, masks, union, body


_W = {}


def weights(p):
    """The head's and the tail's weights: 1 inside the outline, easing to 0 just outside it."""
    if id(p) not in _W:
        def soft(pts, fall):
            m = ns['shape_mask']([poly(*pts)])
            return (1 - sm(ndi.distance_transform_edt(~m) / fall)).astype(np.float32)
        hw = soft(p['head'], p.get('hfall', 70))
        tw = soft(p['tail'][1], 45) if p.get('tail') else None
        _W[id(p)] = (hw, tw)
    return _W[id(p)]


def pose(p, t):
    hw, tw = weights(p)
    s = math.sin
    nx, ny = p['neck']
    foot, hip = p['foot'], p['hip']
    dx = np.zeros((F, F), np.float32)
    dy = np.zeros((F, F), np.float32)
    if p.get('hover'):
        dy += -p['hover'] * s(t)
        dy += -p.get('breath', 5.0) * sm((hip + 120 - YY) / 400) * s(t + 0.6)
    else:
        dy += -p.get('breath', 5.0) * sm((foot - YY) / (foot - hip)) * s(t)
    cy = (ny + hip) / 2.0
    bell = np.exp(-((YY - cy) / 140) ** 2) * (1 - sm((np.abs(XX - p['cx']) - 230) / 90))
    dx += (XX - p['cx']) * 0.012 * bell * s(t + 0.7)
    nod = p.get('nod', 1.0)
    a = math.radians(1.4 * nod * s(t - 1.0))
    rx = (XX - nx) * (math.cos(a) - 1) - (YY - ny) * math.sin(a)
    ry = (XX - nx) * math.sin(a) + (YY - ny) * (math.cos(a) - 1)
    dx += hw * rx
    dy += hw * (ry - 2.5 * nod * s(t - 0.7))
    if tw is not None:
        (tx, ty), _ = p['tail']
        d = np.hypot(XX - tx, YY - ty)
        a = np.radians(p.get('swing', 2.2) * np.sin(t - 1.6 - d / 260))
        rx = (XX - tx) * (np.cos(a) - 1) - (YY - ty) * np.sin(a)
        ry = (XX - tx) * np.sin(a) + (YY - ty) * (np.cos(a) - 1)
        dx += tw * rx
        dy += tw * ry
    return dx, dy


def body_disp(p, k, gain, jelly):
    t = 2 * math.pi * k / N
    ax, ay = pose(p, t)
    bx, by = pose(p, 0.0)
    return (ax - bx) * gain, (ay - by) * gain


MUD_LINE, MUD_FILL, MUD_SHADE, MUD_LIT = (52, 32, 24, 255), (124, 86, 63, 255), (98, 66, 49, 255), (186, 146, 116, 255)


def drawn_layers(im, st, mask, k, ox, oy):
    """What is drawn over the frame rather than moved (called where the Manes draw their steam):
    a bubble of mud swells out of a crater for five frames, bursts (an open rim and drops flung
    up), and the drops fall back."""
    d = ImageDraw.Draw(im)
    ox, oy = body_disp(P[st['hid']], k, M[st['hid']].get('body', 1.5), None)     # (where its back is in this frame)
    for cx, cy, R, s in st.get('bubbles', ()):
        a = (k - s) % N
        x, y = cx + float(ox[cy, cx]), cy + float(oy[cy, cx])
        if a <= 4:
            r = R * (0.35, 0.6, 0.8, 0.95, 1.0)[a]
            by, ry = y - 0.45 * r, 0.9 * r
            d.ellipse((x - r - 3, by - ry - 3, x + r + 3, by + ry + 3), fill=MUD_LINE)
            d.ellipse((x - r, by - ry, x + r, by + ry), fill=MUD_FILL)
            d.ellipse((x - 0.8 * r, by + 0.05 * ry, x + 0.8 * r, by + 0.9 * ry), fill=MUD_SHADE)
            d.ellipse((x - 0.55 * r, by - 0.65 * ry, x - 0.12 * r, by - 0.3 * ry), fill=MUD_LIT)
        elif a <= 6:
            rr = R * (1.15 if a == 5 else 1.3)
            d.arc((x - rr, y - 0.42 * rr, x + rr, y + 0.42 * rr), 180, 360, fill=MUD_LINE, width=4)
            for j, ang in enumerate((-150, -95, -35)):
                out = R * (1.3 if a == 5 else 1.75)
                lift = 0.0 if a == 5 else 0.55 * R
                px = x + math.cos(math.radians(ang)) * out
                py = y - 0.4 * R + math.sin(math.radians(ang)) * out + lift
                pr = R * (0.2 if a == 5 else 0.15) * (1.15 if j == 1 else 1.0)
                d.ellipse((px - pr - 2, py - pr - 2, px + pr + 2, py + pr + 2), fill=MUD_LINE)
                d.ellipse((px - pr, py - pr, px + pr, py + pr), fill=MUD_FILL)
    return im


ns.update(P=P, M=M, art=art, prepare=prepare, body_disp=body_disp, steam_layers=drawn_layers)


# ---- wings that beat, stone arms that lift ----------------------------------------------------
# A wing bends: it stays where it meets the body and turns further the further out it is
# (ramp = (px from the body where it starts to turn, px over which it comes to turn in full);
# anchor = the part of the body it is joined to, when it only lies near the rest across a gap;
# cut_dark = (y0, y1, x0, x1): in those rows the wing ends at the first dark outline pixel met
# going right from x0, where it is drawn against the head with no gap, so the head keeps its edge),
# about its shoulder; down = the turn that lowers it (+1 clockwise). Its outline follows the
# gaps in the art, so the crest's flames and the trailing flames stay with the body.
WINGS = {
    'MYS01': dict(lw=dict(poly=[(30, 10), (470, 10), (475, 300), (478, 560), (400, 575), (300, 565), (180, 520), (30, 330)], pivot=(445, 555), down=-1, ramp=(6, 70),
                          anchor=[(430, 480), (560, 480), (560, 720), (430, 720)], cut_dark=(296, 580, 440, 520)),
                  rw=dict(poly=[(790, 10), (1135, 10), (1135, 650), (760, 655), (690, 625), (645, 580), (635, 535), (680, 505), (745, 462), (790, 362), (808, 250)],
                          pivot=(650, 548), down=1, ramp=(6, 70), anchor=[(560, 470), (700, 470), (710, 720), (560, 720)])),
    'MYS04': dict(lw=dict(poly=[(125, 115), (425, 115), (445, 330), (412, 525), (370, 705), (195, 705), (125, 500)], pivot=(425, 545), down=-1, ramp=(8, 170)),
                  rw=dict(poly=[(765, 95), (1115, 95), (1115, 565), (955, 705), (760, 705), (700, 565), (722, 450), (765, 330)], pivot=(700, 535), down=1, ramp=(8, 170))),
}
# the idle beat: how far down each wing goes at its tip (degrees), its span at the bottom
# (foreshortened), how flat it is drawn there (flat: its height about the shoulder, as a wing
# sweeping toward the viewer looks; this, not a far turn, makes a deep stroke without crushing the
# art), and how far the body lifts on the downstroke
# (lag: how far a frame behind the shoulder its tip follows, 0..1, so the tips trail the stroke)
WINGS_IDLE = {'MYS01': dict(amp=38, span=0.82, flat=0.82, bob=26, lag=0.45), 'MYS04': dict(amp=24, span=0.88, bob=12)}
FLAP = [0.0, 0.5, 0.92, 1.0, 0.78, 0.5, 0.25, 0.07]       # down fast, up slow

# A long tail that trails the beat, cut out and laid behind the body: all of the drawing joined
# to [seed] once the body (core: torso, legs, talons, cut across where the tail leaves the lower
# back) and the wings are taken away, so the cut follows the gaps the art already has. It swings
# from its root a beat behind the body (swing, degrees) and a wave runs down its line from the
# root to the tip (amp px at the tip, waves along it). Simurgh's is one streamer: it fans from the
# lower back, sweeps under the talons and climbs the left side into the flames there.
TAILS = {
    'MYS01': dict(seed=(520, 1112),
                  core=[(430, 300), (700, 300), (700, 760), (690, 800), (705, 880), (712, 1000), (712, 1094), (580, 1094), (545, 1078), (515, 1040), (470, 1012), (432, 1000), (440, 640)],
                  root=(690, 790),
                  line=[(690, 790), (740, 880), (770, 980), (740, 1060), (640, 1110), (520, 1115), (410, 1085), (320, 1020),
                        (270, 930), (260, 830), (280, 730), (310, 640), (320, 560)],
                  swing=5, amp=22, waves=0.9),
}

_SET = {}


def setup(hid):
    if hid not in _SET:
        a, sil, cfg, masks, union, body = prepare(hid)
        fl, d, nx, ny = ns['fields'](cfg, masks, body, sil)
        pm = a.copy()
        pm[..., :3] *= pm[..., 3:4] / 255
        pm = np.dstack([pm, union.astype(np.float32) * 255])      # (a 5th channel: where the moving parts are, for their glow)
        wings = {}
        wm = {name: ns['shape_mask']([poly(*W['poly'])]) & sil for name, W in WINGS.get(hid, {}).items()}
        for name, W in WINGS.get(hid, {}).items():
            if W.get('cut_dark'):
                y0, y1, x0, x1 = W['cut_dark']
                dark = (a[..., 3] > 128) & (a[..., 0] < 200) & (a[..., 1] < 80) & (a[..., 2] < 80)
                for y in range(y0, y1):
                    xs = np.nonzero(dark[y, x0:x1])[0]
                    if len(xs):
                        wm[name][y, x0 + xs[0]:] = False
        if wm:
            rest = sil.copy()
            for m in wm.values():
                rest &= ~m
            near = ndi.distance_transform_edt(~rest).astype(np.float32)
            for name, m in wm.items():
                W = WINGS[hid][name]
                ys, xs = np.nonzero(m)
                k0, R = W['ramp']
                dn = near
                if W.get('anchor'):
                    dn = ndi.distance_transform_edt(~(rest & ns['shape_mask']([poly(*W['anchor'])]))).astype(np.float32)
                w = sm((dn - k0) / R)                    # (how far it turns: nothing at its root, all of it past the ramp)
                wings[name] = (m.astype(np.float32), w.astype(np.float32), (xs.mean() - W['pivot'][0], ys.mean() - W['pivot'][1]))
        tail = None
        T = TAILS.get(hid)
        if T:
            m = sil & ~ns['shape_mask']([poly(*T['core'])])
            for wmask, _, _ in wings.values():
                m &= wmask < 0.5
            lab, _ = ndi.label(m)
            ys, xs = np.nonzero(lab)                       # (the drawn pixel nearest the seed: the streamer is thin)
            i = np.argmin((xs - T['seed'][0]) ** 2 + (ys - T['seed'][1]) ** 2)
            m = lab == lab[ys[i], xs[i]]
            tail = dict(m=m.astype(np.float32), **tail_line(T['line']))
        _SET[hid] = dict(cfg=cfg, fl=fl, d=d, nx=nx, ny=ny, pm=pm, wings=wings, tail=tail)
    return _SET[hid]


def tail_line(pts):
    """For every pixel, the nearest point of the line [pts]: how far along it (0 at the root, 1 at the
    tip) and the line's normal there, blended between its corners so neither jumps."""
    P_ = np.array(pts, np.float32)
    seg = P_[1:] - P_[:-1]
    L = np.hypot(seg[:, 0], seg[:, 1])
    cum = np.concatenate([[0], np.cumsum(L)])
    nrm = np.stack([-seg[:, 1] / L, seg[:, 0] / L], -1)
    vn = np.vstack([nrm[:1], (nrm[:-1] + nrm[1:]) / 2, nrm[-1:]])
    vn /= np.hypot(vn[:, 0], vn[:, 1])[:, None]
    best = np.full((F, F), 1e9, np.float32)
    U = np.zeros((F, F), np.float32)
    NX = np.zeros((F, F), np.float32)
    NY = np.zeros((F, F), np.float32)
    for i in range(len(seg)):
        t = np.clip(((XX - P_[i, 0]) * seg[i, 0] + (YY - P_[i, 1]) * seg[i, 1]) / (L[i] ** 2), 0, 1)
        dd = np.hypot(XX - P_[i, 0] - t * seg[i, 0], YY - P_[i, 1] - t * seg[i, 1])
        on = dd < best
        best = np.where(on, dd, best)
        U = np.where(on, (cum[i] + t * L[i]) / cum[-1], U)
        nx_ = vn[i, 0] * (1 - t) + vn[i + 1, 0] * t
        ny_ = vn[i, 1] * (1 - t) + vn[i + 1, 1] * t
        nl = np.hypot(nx_, ny_) + 1e-6
        NX = np.where(on, nx_ / nl, NX)
        NY = np.where(on, ny_ / nl, NY)
    return dict(U=ndi.gaussian_filter(U, 6), NX=ndi.gaussian_filter(NX, 8), NY=ndi.gaussian_filter(NY, 8))


def tail_field(hid, swing, phase, scale=1.0):
    """Where each point of the tail goes: swung [swing] degrees about its root (more the further
    out), and a wave at [phase] running down it from the root to the tip."""
    T, t = TAILS[hid], setup(hid)['tail']
    rx, ry = T['root']
    X, Y = XX - rx, YY - ry
    a = np.radians(swing) * sm(np.hypot(X, Y) / 260)
    ca, sa = np.cos(a), np.sin(a)
    wave = T['amp'] * scale * t['U'] ** 1.3 * np.sin(phase - 2 * math.pi * T['waves'] * t['U'])
    return X * ca - Y * sa - X + wave * t['NX'], X * sa + Y * ca - Y + wave * t['NY']


def wing_field(hid, name, ang, span, tip=None, flat=1.0):
    """Where each point of a wing goes at (degrees, span): turned about the shoulder by the angle
    times how far out it is, its span drawn in along the wing, its height about the shoulder
    scaled by [flat]. [tip]: the angle its tip is at, when the tip trails the shoulder (blended in
    toward the tip)."""
    _, w, u = setup(hid)['wings'][name]
    cx, cy = WINGS[hid][name]['pivot']
    un = np.array(u, float) / np.linalg.norm(u)
    X, Y = XX - cx, YY - cy
    sw = 1 + (span - 1) * w
    pr = X * un[0] + Y * un[1]
    vx, vy = X + (sw - 1) * pr * un[0], Y + (sw - 1) * pr * un[1]
    vy = vy * (1 + (flat - 1) * w)
    a = np.radians(ang * w + ((ang if tip is None else tip) - ang) * w * w)
    ca, sa = np.cos(a), np.sin(a)
    return vx * ca - vy * sa - X, vx * sa + vy * ca - Y


def inv_warp(img, Dx, Dy, iters=6):
    """[img] with each point moved by (Dx, Dy) (given where the point starts): each drawn pixel is
    traced back to where it came from, so a wing turned far still holds together."""
    sx, sy = XX - Dx, YY - Dy
    for _ in range(iters):
        ex = ndi.map_coordinates(Dx, [sy, sx], order=1, mode='nearest')
        ey = ndi.map_coordinates(Dy, [sy, sx], order=1, mode='nearest')
        sx, sy = XX - ex, YY - ey
    if img.ndim == 2:
        return ndi.map_coordinates(img, [sy, sx], order=1, mode='constant')
    return np.stack([ndi.map_coordinates(img[..., c], [sy, sx], order=1, mode='constant') for c in range(img.shape[2])], -1)


def over(top, bottom):
    return top + bottom * (1 - top[..., 3:4] / 255)


def finish(f, cfg, k, gain=1.0):
    """The frame made solid, its glow laid round it (as manes2_build does), [gain] times as bright."""
    al = f[..., 3]
    hard = al >= 128
    rgb = np.clip(np.where(hard[..., None], f[..., :3] / np.maximum(al[..., None], 1) * 255, 0), 0, 255)
    alpha = hard.astype(np.float32)
    parts_w = (f[..., 4] / 255) > 0.5
    halo = np.zeros((F, F), np.float32)
    hcol = np.zeros((F, F, 3), np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    for gl in cfg['glow']:
        G = (parts_w & hard) if gl.get('of') == 'parts' else hard if gl.get('of') == 'sil' else (gl['test'](r, g, b) & hard)
        Gf = G.astype(np.float32)
        pk = ns['pat'](gl['pat'], k % N)
        if gl['lift']:
            soft = np.clip(ndi.gaussian_filter(Gf, 2.0) * 1.3, 0, 1)[..., None]
            rgb = rgb + (255 - rgb) * soft * min(0.85, gl['lift'] * pk * gain) * hard[..., None]
        h = np.clip(ndi.gaussian_filter(Gf, 26) * 2.2 + ndi.gaussian_filter(Gf, 9) * 0.6, 0, 1) * gl['halo'] * (0.45 + 0.55 * pk) * gain
        hcol = np.where((h > halo)[..., None], np.array(gl['col'], np.float32), hcol)
        halo = np.maximum(halo, h)
    gt = cfg.get('glint')
    if gt and k % N < 6:
        x0, y0, x1, y1 = gt['box']
        u = (XX + YY) / math.sqrt(2)
        u0, u1 = (x0 + y0) / math.sqrt(2) - 80, (x1 + y1) / math.sqrt(2) + 80
        band = np.exp(-((u - (u0 + (u1 - u0) * (k % N / 5.0))) / 34) ** 2)
        G = gt['test'](r, g, b) & hard & (XX > x0) & (XX < x1) & (YY > y0) & (YY < y1)
        rgb = rgb + (255 - rgb) * (band * G * 0.75)[..., None]
    halo = np.clip(halo, 0, 0.9)
    oa = alpha + (1 - alpha) * halo
    orgb = np.where(hard[..., None], rgb, hcol)
    return Image.fromarray(np.dstack([orgb, oa * 255]).clip(0, 255).astype(np.uint8), 'RGBA')


def render(hid, kmat, bdx, bdy, beats=None, tail=None, gain=1.0, shake=(0, 0)):
    """One frame: the still moved by the body and its material at idle phase [kmat]; each wing in
    [beats] ({name: (degrees, span[, tip degrees])}) cut out, bent by wing_field and laid behind the
    body; the tail, with [tail] = (swing, phase, scale), cut out, moved by tail_field and laid behind
    it too; then its glow. Returns the frame and where things went (the body's field, each wing's)."""
    st = setup(hid)
    mx, my = ns['material_disp'](st['cfg'], st['fl'], st['d'], st['nx'], st['ny'], kmat % N)
    Dx, Dy = bdx + mx, bdy + my
    wf = {}
    if beats or tail:
        cut = np.zeros((F, F), np.float32)
        for name in beats or {}:
            cut = np.maximum(cut, st['wings'][name][0])
        if tail:
            cut = np.maximum(cut, st['tail']['m'])
        f = inv_warp(st['pm'] * (1 - cut)[..., None], Dx, Dy)
        back = np.zeros_like(f)
        if tail:
            tx, ty = tail_field(hid, *tail)
            back = inv_warp(st['pm'] * st['tail']['m'][..., None], Dx + tx, Dy + ty)
        for name, b in (beats or {}).items():
            wx, wy = wing_field(hid, name, *b)
            wf[name] = (Dx + wx, Dy + wy)
            back = over(inv_warp(st['pm'] * st['wings'][name][0][..., None], Dx + wx, Dy + wy), back)
        f = over(f, back)
    else:
        f = inv_warp(st['pm'], Dx, Dy)
    if shake != (0, 0):
        f = ndi.shift(f, (shake[1], shake[0], 0), order=1)
    return finish(f, st['cfg'], kmat, gain), dict(base=(Dx, Dy), wings=wf)


def save_idle(hid, frames):
    name = hid + '_' + P[hid]['n']
    sheet = Image.new('RGBA', (4 * F, 2 * F))
    for i, f in enumerate(frames):
        sheet.paste(f, ((i % 4) * F, (i // 4) * F))
    sheet.save('%s/%s_idle2_spritesheet.png' % (O, name))
    still = Image.fromarray(art(hid).astype(np.uint8), 'RGBA')
    n = 320
    g = []
    for k in range(N):
        c = Image.new('RGB', (2 * n + 10, n + 34), BG)
        c.paste(ns['cell'](still, n), (0, 34))
        c.paste(ns['cell'](frames[k], n), (n + 10, 34))
        dd = ImageDraw.Draw(c)
        dd.text((10, 6), P[hid]['n'].upper() + '  STILL', fill=(200, 170, 110), font=font)
        dd.text((n + 20, 6), 'IDLE', fill=(200, 170, 110), font=font)
        g.append(c)
    g[0].save('%s/%s_idle2.gif' % (O, name), save_all=True, append_images=g[1:], duration=DUR, loop=0)
    print(hid, P[hid]['n'], 'flap', flush=True)
    return g


def build_flap(hid):
    """A flyer's idle: its wings beat once a loop, down fast and up slow, bending from the
    shoulder and foreshortened at the bottom, and the body lifts on each downstroke."""
    W, cfg = WINGS_IDLE[hid], M[hid]
    frames = []
    for k in range(N):
        bdx, bdy = body_disp(P[hid], k, cfg.get('body', 1.5), None)
        bdy = bdy - W['bob'] * (FLAP[(k - 1) % N] - FLAP[N - 1])
        f_ = FLAP[k]
        lag = (1 - W.get('lag', 0)) * f_ + W.get('lag', 0) * FLAP[(k - 1) % N]
        beats = {nm: (Wg['down'] * W['amp'] * f_, 1 - (1 - W['span']) * f_, Wg['down'] * W['amp'] * lag, 1 - (1 - W.get('flat', 1.0)) * f_)
                 for nm, Wg in WINGS[hid].items()}
        tail = (TAILS[hid]['swing'] * math.sin(2 * math.pi * (k - 2) / N), 2 * math.pi * k / N) if hid in TAILS else None
        im = render(hid, k, bdx, bdy, beats=beats, tail=tail)[0]
        bb = im.getchannel('A').point(lambda v: 255 if v >= 250 else 0).getbbox()
        assert bb[0] > 2 and bb[1] > 2 and bb[2] < F - 2 and bb[3] < F - 2, (hid, k, bb)
        frames.append(im)
    return save_idle(hid, frames)


# ---- the attack: a wind-up, one strike held a beat, the element thrown, the settle -----------
# 10 frames at the game's attack timings (creature_actions.dart _fireSteps): the strike lands on
# frame 4, 180 ms in. Drawn at 1200 px and kept at 600 (as every 1200 px idle's actions are).
FIRE_MS = [20, 50, 50, 60, 50, 60, 60, 60, 70, 80]
T_MS = [sum(FIRE_MS[:k]) for k in range(10)]
STRIKE = 4
POSE = [0.0, -0.45, -0.85, -1.0, 1.0, 0.95, 0.8, 0.5, 0.2, 0.0]       # -1 wound up .. 1 struck
GAIN = [1.0, 1.08, 1.2, 1.3, 2.0, 1.9, 1.65, 1.35, 1.12, 1.0]        # how bright what glows on it is

FIRE_C = [(255, 238, 160), (255, 196, 90), (255, 140, 45), (238, 86, 32)]
WATER_C = [(225, 250, 255), (160, 232, 255), (95, 205, 245), (60, 170, 232)]
STONE_C = [(178, 162, 150), (146, 130, 120), (116, 101, 92), (88, 76, 69)]
LAVA_C = [(255, 236, 150), (255, 186, 70), (255, 120, 32), (226, 70, 22)]
SPARK_C = [(235, 250, 255), (190, 240, 255), (125, 222, 255)]
MUD_C = [(150, 108, 80), (124, 86, 63), (98, 66, 49), (74, 50, 37)]
FROST_C = [(240, 252, 255), (200, 242, 255), (155, 226, 255)]
CLOUD_P = ((150, 196, 242), (208, 230, 252), (238, 248, 255))        # (outline, shade, fill)
STEAM_P = ((140, 160, 150), (196, 209, 201), (224, 232, 224))
DUST_P = ((92, 80, 72), (128, 114, 104), (150, 136, 126))

# kind: lunge (side on: lean, rear the head back, then drive it forward), wings (raise them, then
# beat down hard), slam (lift both stone arms, bring them down). fx: what it throws at the strike:
# grains (at: points it leaves from, dir/cone in degrees with y down, speed px/ms, grav, size, n,
# life ms, cols), puffs (drawn clouds that grow and thin), bolts (lightning arcs), glints.
ATK = {
    'MYS01': dict(kind='wings', up=0, down=36, span=0.86, flat=0.55, lift=24, sink=18,
                  fx=[dict(t='grains', on=['lw', 'rw'], at=[(130, 60), (90, 200), (150, 330), (230, 120), (300, 40), (250, 480),
                                                             (1040, 60), (1100, 240), (1000, 400), (900, 150), (960, 100), (820, 520)],
                           out=True, down=40, cone=50, speed=1.5, grav=-0.002, size=12, n=140, life=270, cols=FIRE_C, seed=1)]),
    'MYS02': dict(kind='lunge', lean=52, crouch=18, rear=11, strike=9, thrust=48,
                  fx=[dict(t='grains', at=[(415, 505)], jit=16, dir=196, cone=50, speed=2.0, grav=0.005, size=14, n=110, life=300, cols=WATER_C, seed=2),
                      dict(t='grains', at=[(415, 505)], jit=12, dir=188, cone=30, speed=2.6, grav=0.002, size=7, n=90, life=240, cols=WATER_C[:2], seed=3)]),
    'MYS03': dict(kind='slam', rise=40, squash=16, widen=0.03, shake=[(0, 0)] * 4 + [(8, -3), (-5, 2), (2, -1)] + [(0, 0)] * 3,
                  fx=[dict(t='grains', at=[(120, 1080), (220, 1088), (300, 1085)], jit=22, dir=215, cone=70, speed=1.6, grav=0.012, size=15, n=42, life=290, cols=STONE_C, seed=4),
                      dict(t='grains', at=[(820, 1088), (920, 1092), (1020, 1088)], jit=22, dir=325, cone=70, speed=1.6, grav=0.012, size=15, n=42, life=290, cols=STONE_C, seed=5),
                      dict(t='grains', at=[(470, 1060), (560, 1065), (660, 1060)], jit=30, dir=270, cone=90, speed=1.2, grav=0.012, size=11, n=26, life=260, cols=STONE_C, seed=20),
                      dict(t='puffs', at=[(170, 1075), (950, 1080), (560, 1060)], dirs=[195, 345, 270], speed=0.6, size=38, n=12, life=330, pal=DUST_P, seed=6)]),
    'MYS04': dict(kind='wings', up=6, down=30, span=0.84, lift=16, sink=12,
                  fx=[dict(t='puffs', on=['lw', 'rw'], at=[(220, 690), (150, 520), (300, 700), (920, 700), (1080, 540), (1000, 660)],
                           dirs=[130, 160, 105, 50, 20, 75], speed=0.8, size=40, n=14, life=330, pal=CLOUD_P, seed=7),
                      dict(t='grains', on=['lw', 'rw'], at=[(200, 650), (140, 480), (960, 650), (1090, 480)], out=True, down=60, cone=40,
                           speed=2.0, grav=0.0, size=7, n=70, life=230, cols=[(240, 248, 255), (205, 228, 250)], seed=8)]),
    'MYS05': dict(kind='lunge', lean=36, crouch=16, rear=9, strike=8, thrust=32,
                  fx=[dict(t='puffs', at=[(300, 430), (430, 400), (230, 500), (520, 420)], dirs=[230, 255, 205, 280], speed=1.15, size=54, n=16, life=360, pal=STEAM_P, seed=9),
                      dict(t='puffs', at=[(650, 540), (720, 640), (820, 760), (1000, 860)], dirs=[275, 280, 270, 265], speed=0.85, size=36, n=8, life=320, pal=STEAM_P, seed=10)]),
    'MYS06': dict(kind='lunge', lean=50, crouch=20, rear=5, strike=6, thrust=40,
                  fx=[dict(t='grains', at=[(245, 700)], jit=18, dir=196, cone=60, speed=1.7, grav=0.002, size=11, n=100, life=250, cols=LAVA_C, seed=11),
                      dict(t='grains', at=[(260, 740)], jit=14, dir=205, cone=40, speed=1.1, grav=0.012, size=15, n=22, life=270, cols=LAVA_C[1:], seed=12),
                      dict(t='grains', at=[(520, 560), (640, 520), (760, 600), (860, 700), (600, 700)], jit=60, dir=270, cone=70, speed=0.7, grav=-0.001, size=8, n=50, life=270, cols=LAVA_C[:3], seed=13)]),
    'MYS07': dict(kind='lunge', lean=52, crouch=22, rear=10, strike=10, thrust=40,
                  fx=[dict(t='bolts', frm=(225, 735), to=[(45, 640), (60, 790), (95, 880)], arcs=[((330, 620), (470, 470)), ((520, 560), (690, 420)), ((700, 470), (720, 620))], seed=14),
                      dict(t='grains', at=[(225, 735)], jit=16, dir=188, cone=80, speed=1.9, grav=0.003, size=7, n=60, life=180, cols=SPARK_C, seed=15)]),
    'MYS08': dict(kind='lunge', lean=42, crouch=24, rear=9, strike=10, thrust=34, shake=[(0, 0)] * 4 + [(7, -3), (-4, 2), (2, 0)] + [(0, 0)] * 3,
                  fx=[dict(t='grains', at=[(120, 965), (250, 970), (380, 975), (520, 985), (650, 985)], jit=26, dir=250, cone=100, speed=1.5, grav=0.012, size=16, n=70, life=290, cols=MUD_C, seed=16),
                      dict(t='grains', at=[(780, 511), (875, 442), (480, 325)], jit=12, dir=270, cone=120, speed=0.9, grav=0.01, size=12, n=30, life=270, cols=MUD_C, seed=17)]),
    'MYS09': dict(kind='lunge', lean=24, crouch=18, rear=6, strike=5, thrust=16, shake=[(0, 0)] * 4 + [(5, -2), (-3, 1), (1, 0)] + [(0, 0)] * 3,
                  fx=[dict(t='grains', at=[(230, 1100), (330, 1105), (450, 1100), (600, 1100)], jit=24, dir=262, cone=80, speed=1.4, grav=0.006, size=11, n=80, life=290, cols=FROST_C, seed=18),
                      dict(t='grains', at=[(260, 1100), (420, 1100)], jit=30, dir=265, cone=60, speed=1.7, grav=0.011, size=17, n=20, life=280, cols=FROST_C[1:], seed=19),
                      dict(t='grains', at=[(150, 310)], jit=10, dir=118, cone=30, speed=1.1, grav=0.0, size=9, n=45, life=230, cols=FROST_C, seed=21),
                      dict(t='glints', at=[(555, 150), (885, 315), (780, 145), (720, 440), (450, 355)])]),
}


def attack_pose(hid, A, P_, fit):
    """The body's displacement at pose P_ (-1 wound up .. 1 struck), and the wings' beat."""
    p = P[hid]
    hw, tw = weights(p)
    pos, neg = max(P_, 0.0) * fit, max(-P_, 0.0) * fit
    wl = sm((p['foot'] - YY) / (p['foot'] - p['hip']))
    dx = np.zeros((F, F), np.float32)
    dy = np.zeros((F, F), np.float32)
    beats = {}
    nx, ny = p['neck']
    kind = A['kind']
    if kind == 'lunge':                                    # all of these face left
        lean = A['lean'] * (pos - 0.55 * neg)
        dx += -lean * wl
        dy += (A['crouch'] * neg - 6 * pos) * wl
        a = math.radians(A['rear'] * neg - A['strike'] * pos)
        rx = (XX - nx) * (math.cos(a) - 1) - (YY - ny) * math.sin(a)
        ry = (XX - nx) * math.sin(a) + (YY - ny) * (math.cos(a) - 1)
        dx += hw * (rx - A['thrust'] * pos + 0.4 * A['thrust'] * neg)
        dy += hw * ry
        if tw is not None:
            (tx, ty), _ = p['tail']
            b = math.radians(-7 * (pos - neg))
            dx += tw * ((XX - tx) * (math.cos(b) - 1) - (YY - ty) * math.sin(b))
            dy += tw * ((XX - tx) * math.sin(b) + (YY - ty) * (math.cos(b) - 1))
    elif kind == 'wings':
        dy += A['sink'] * neg - A['lift'] * pos
        dy += hw * (6 * neg - 8 * pos)
        for nm, W in WINGS[hid].items():
            beats[nm] = (W['down'] * (A['down'] * pos - A['up'] * neg), 1 - (1 - A['span']) * pos + 0.03 * neg, None, 1 - (1 - A.get('flat', 1.0)) * pos)
    else:                                                  # slam: it rises over its planted fists and feet, then comes down hard
        dy += (-A['rise'] * neg + A['squash'] * pos) * wl
        dx += (XX - p['cx']) * A.get('widen', 0.0) * pos * wl
        dy += hw * (-12 * neg + 16 * pos)
    return dx, dy, beats


def stamp(acc, x, y, r, col, a):
    """A soft round dot laid over [acc] (premultiplied RGBA, 0..1)."""
    if a <= 0.004 or r <= 0.3:
        return
    x0, x1 = int(max(0, x - r - 2)), int(min(F, x + r + 3))
    y0, y1 = int(max(0, y - r - 2)), int(min(F, y + r + 3))
    if x0 >= x1 or y0 >= y1:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    cov = np.clip(r + 0.5 - np.hypot(xx - x, yy - y), 0, 1) * a
    sub = acc[y0:y1, x0:x1]
    c = np.array(col, np.float32) / 255
    sub[..., :3] = sub[..., :3] * (1 - cov[..., None]) + c * cov[..., None]
    sub[..., 3] = sub[..., 3] * (1 - cov) + cov


def puff_stamp(acc, x, y, r, pal, a, turn):
    """A small cloud: overlapping rounds under one outline, lit from the upper left."""
    parts = []
    for ax, ay, rr in ((0, 0, 1.0), (-0.72, 0.28, 0.62), (0.68, 0.3, 0.66), (0.12, -0.6, 0.6)):
        c, sn = math.cos(turn), math.sin(turn)
        parts.append((x + (ax * c - ay * sn) * r, y + (ax * sn + ay * c) * r, rr * r))
    for px, py, pr in parts:
        stamp(acc, px, py, pr + 4, pal[0], a)
    for px, py, pr in parts:
        stamp(acc, px, py, pr, pal[1], a)
    for px, py, pr in parts:
        stamp(acc, px - 0.22 * pr, py - 0.22 * pr, 0.8 * pr, pal[2], a)


def fx_layer(hid, A, k, D):
    """What it throws at the strike, [k]'s moment of it, as an RGBA layer over the frame."""
    t = T_MS[k] - T_MS[STRIKE]
    if t < -30:
        return None
    acc = np.zeros((F, F, 4), np.float32)
    glow = np.zeros((F, F, 4), np.float32)
    def origin(e, j, x, y):                                # where that point of it is drawn now
        Dx, Dy = D['base']
        if e.get('on'):
            Dx, Dy = D['wings'].get(e['on'][0] if x < 600 else e['on'][-1], D['base'])
        return x + float(Dx[int(y), int(x)]), y + float(Dy[int(y), int(x)])

    for e in A['fx']:
        rng = np.random.RandomState(e.get('seed', 0))
        if e['t'] == 'grains':
            n = e['n']
            born = -20 + rng.rand(n) ** 1.6 * 70
            life = e['life'] * (0.6 + 0.8 * rng.rand(n))
            idx = rng.randint(len(e['at']), size=n)
            jit = e.get('jit', 16)
            jx, jy = (rng.rand(n) - 0.5) * 2 * jit, (rng.rand(n) - 0.5) * 2 * jit
            spread = (rng.rand(n) ** 1.3 - 0.4) * e['cone']          # lopsided
            spd = e['speed'] * (0.45 + 0.9 * rng.rand(n))
            size = e['size'] * (0.55 + 0.9 * rng.rand(n))
            ci = rng.randint(len(e['cols']), size=n)
            drag, g = 0.004, e.get('grav', 0.0)
            for i in range(n):
                age = t - born[i]
                if age < 0 or age > life[i]:
                    continue
                sx, sy = e['at'][idx[i]]
                ox, oy = origin(e, i, sx, sy)
                ox, oy = ox + jx[i], oy + jy[i]
                if e.get('out'):                           # outward from the wing's pivot, swept down
                    nm = e['on'][0] if sx < 600 else e['on'][-1]
                    W = WINGS[hid][nm]
                    base = math.degrees(math.atan2(sy - W['pivot'][1], sx - W['pivot'][0]))
                    ang = math.radians(base + W['down'] * e['down'] + spread[i])
                else:
                    ang = math.radians(e['dir'] + spread[i])

                def at(a_):
                    s_ = spd[i] * (1 - math.exp(-drag * a_)) / drag
                    return ox + math.cos(ang) * s_, oy + math.sin(ang) * s_ + 0.5 * g * a_ * a_
                u = age / life[i]
                al = min(1.0, (age + 20) / 30) * (1 - u) ** 1.3
                r = size[i] * (1 - 0.4 * u)
                col = e['cols'][ci[i]]
                for j in (3, 2, 1):                        # a short trail
                    if age - j * 14 >= 0:
                        tx_, ty_ = at(age - j * 14)
                        stamp(acc, tx_, ty_, r * (1 - 0.18 * j), col, al * (0.5 - 0.13 * j))
                x, y = at(age)
                stamp(acc, x, y, r, col, al)
                stamp(glow, x, y, r * 2.2, col, al * 0.5)
        elif e['t'] == 'puffs':
            n = e['n']
            for i in range(n):
                j = i % len(e['at'])
                born = -10 + (i // len(e['at'])) * 35 + rng.rand() * 20
                life = e['life'] * (0.75 + 0.5 * rng.rand())
                age = t - born
                if age < 0 or age > life:
                    continue
                ox, oy = origin(e, i, *e['at'][j])
                ang = math.radians(e['dirs'][j] + (rng.rand() - 0.5) * 30)
                s_ = e['speed'] * (0.7 + 0.6 * rng.rand()) * (1 - math.exp(-0.005 * age)) / 0.005
                u = age / life
                r = e['size'] * (0.55 + 0.5 * rng.rand()) * (0.5 + 0.8 * u)
                puff_stamp(acc, ox + math.cos(ang) * s_, oy + math.sin(ang) * s_, r, e['pal'], min(1.0, (age + 10) / 25) * (1 - u) ** 1.5, i * 1.7)
        elif e['t'] == 'bolts' and 0 <= t <= 120:
            r2 = np.random.RandomState(e['seed'] + k)
            fade = 1.0 if t < 60 else 0.5
            fx_, fy_ = origin(e, 0, *e['frm'])
            segs = [((fx_, fy_), to) for to in e['to'][:3 if t < 60 else 2]]
            segs += [(origin(e, 0, *a_), origin(e, 0, *b_)) for a_, b_ in e['arcs']]
            for (x0, y0), (x1, y1) in segs:
                pts = [(x0, y0)]
                L_ = math.hypot(x1 - x0, y1 - y0)
                m = max(4, int(L_ / 22))
                for q in range(1, m):
                    u = q / m
                    off = (r2.rand() - 0.5) * 0.9 * L_ / math.sqrt(m)
                    pts.append((x0 + (x1 - x0) * u - (y1 - y0) / L_ * off, y0 + (y1 - y0) * u + (x1 - x0) / L_ * off))
                pts.append((x1, y1))
                for (ax, ay), (bx_, by_) in zip(pts, pts[1:]):
                    steps = int(math.hypot(bx_ - ax, by_ - ay) / 2) + 1
                    for q in range(steps + 1):
                        u = q / steps
                        x, y = ax + (bx_ - ax) * u, ay + (by_ - ay) * u
                        stamp(glow, x, y, 14, (120, 220, 255), 0.35 * fade)
                        stamp(acc, x, y, 4.0, (240, 252, 255), 0.95 * fade)
        elif e['t'] == 'glints' and 0 <= t <= 130:
            a_ = 1.0 - t / 130
            for j, (gx, gy) in enumerate(e['at']):
                x, y = origin(e, j, gx, gy)
                R_ = (16 + 6 * (j % 3)) * (0.6 + 0.4 * a_)
                for q in range(-int(R_), int(R_) + 1, 2):
                    w = 1 - abs(q) / R_
                    stamp(acc, x + q, y, 2.2 * w + 0.6, (235, 250, 255), a_ * w)
                    stamp(acc, x, y + q, 2.2 * w + 0.6, (235, 250, 255), a_ * w)
                stamp(glow, x, y, R_ * 0.9, (170, 235, 255), a_ * 0.5)
    g = np.stack([ndi.gaussian_filter(glow[..., c], 6) for c in range(4)], -1) * 0.8
    out = acc + g * (1 - acc[..., 3:4])
    a_ = np.clip(out[..., 3], 0, 1)
    rgb = np.where(a_[..., None] > 1e-4, out[..., :3] / np.maximum(a_[..., None], 1e-4), 0)
    return Image.fromarray(np.dstack([np.clip(rgb * 255, 0, 255), a_ * 255]).astype(np.uint8), 'RGBA')


def build_attack(hid):
    """The attack's ten frames (1200 px): the pose, the glow flaring, what it throws."""
    A = ATK[hid]
    fit = 1.0
    for attempt in range(6):
        frames = []
        hit = False
        for k in range(10):
            bdx, bdy, beats = attack_pose(hid, A, POSE[k], fit)
            shake = A.get('shake', [(0, 0)] * 10)[k]
            tail = (-1.6 * TAILS[hid]['swing'] * POSE[max(k - 1, 0)] * fit, 2 * math.pi * k / 10 * 1.2, 0.6 + 0.7 * abs(POSE[k])) if hid in TAILS else None
            im, D = render(hid, k, bdx, bdy, beats=beats, tail=tail, gain=GAIN[k], shake=shake)
            bb = im.getchannel('A').point(lambda v: 255 if v >= 250 else 0).getbbox()
            hit |= bb[0] < 3 or bb[1] < 3 or bb[2] > F - 3 or bb[3] > F - 3
            fl = fx_layer(hid, A, k, D)
            if fl is not None:
                im.alpha_composite(fl)
            frames.append(im)
        if not hit:
            break
        fit *= 0.82
    print(hid, P[hid]['n'], 'attack', 'fit x%.2f' % fit if fit < 1 else '', flush=True)
    fits = {}
    try:
        fits = json.load(open(O + '/attack_fit.json'))
    except (OSError, ValueError):
        pass
    fits[hid] = fit                                        # (for the costumes' attack tracks)
    json.dump(fits, open(O + '/attack_fit.json', 'w'))
    return frames


# ---- costumes: a hat (and the crown on it), a nose, sunglasses (and the monocle on them) ------
# Placed by hand on the still (px): glasses = the point between the eyes and the eye-to-eye
# spacing, or (a head side on) the one eye that shows and the lens's size; hat = its crown and
# width; nose = its centre and radius; tilts in radians, clockwise. Every idle and attack frame
# then moves them with the head, by the same fields that drew the frame.
COSTUME = {
    'MYS01': dict(view='profile', eyes=[(527, 420)], glasses=0.06, hat=(522, 318, 0.13), nose=(497, 452, 0.022)),
    'MYS02': dict(view='profile', eyes=[(550, 443)], glasses=0.07, hat=(520, 300, 0.14), nose=(436, 506, 0.024), hat_tilt=-0.2),
    'MYS03': dict(view='front', eyes=[(383, 670), (563, 677)], hat=(476, 380, 0.15), nose=(472, 722, 0.03), glasses_tilt=0.04),
    'MYS04': dict(view='front', eyes=[(457, 507), (509, 505)], hat=(500, 334, 0.12), nose=(481, 542, 0.02)),
    'MYS05': dict(view='threeQuarter', eyes=[(217, 620), (413, 617)], hat=(330, 548, 0.15), nose=(258, 678, 0.028)),
    'MYS06': dict(view='profile', eyes=[(290, 597)], glasses=0.075, hat=(300, 452, 0.15), nose=(158, 650, 0.026), hat_tilt=-0.15),
    'MYS07': dict(view='threeQuarter', eyes=[(173, 627), (287, 627)], hat=(240, 540, 0.13), nose=(140, 660, 0.024)),
    'MYS08': dict(view='profile', eyes=[(443, 637)], glasses=0.07, hat=(452, 522, 0.13), nose=(372, 712, 0.026), hat_tilt=-0.1),
    'MYS09': dict(view='profile', eyes=[(313, 277)], glasses=0.07, hat=(292, 248, 0.13), nose=(165, 338, 0.024), hat_tilt=-0.25),
}


def idle_field(hid, k):
    """Where each point of the still is drawn in idle frame [k] (the wings aside)."""
    cfg, st = M[hid], setup(hid)
    bdx, bdy = body_disp(P[hid], k, cfg.get('body', 1.5), None)
    if hid in WINGS_IDLE:
        W = WINGS_IDLE[hid]
        bdy = bdy - W['bob'] * (FLAP[(k - 1) % N] - FLAP[N - 1])
    mx, my = ns['material_disp'](st['cfg'], st['fl'], st['d'], st['nx'], st['ny'], k % N)
    return bdx + mx, bdy + my


def attack_field(hid, k, fit):
    """Where each point of the still is drawn in attack frame [k] (its shake included)."""
    st = setup(hid)
    bdx, bdy, _ = attack_pose(hid, ATK[hid], POSE[k], fit)
    mx, my = ns['material_disp'](st['cfg'], st['fl'], st['d'], st['nx'], st['ny'], k % N)
    sx, sy = ATK[hid].get('shake', [(0, 0)] * 10)[k]
    return bdx + mx + sx, bdy + my + sy


def moved(D, x, y):
    return x + float(D[0][int(y), int(x)]), y + float(D[1][int(y), int(x)])


def turn(D, x, y, r=60):
    """How far the head about (x, y) is turned by D (radians, clockwise)."""
    ax, ay = moved(D, x - r, y)
    bx, by = moved(D, x + r, y)
    return math.atan2(by - ay, bx - ax)


def costume_fits(hid):
    """(placements, per-frame fits, tilts, the attack's head track) for one species."""
    c = COSTUME[hid]
    eyes = c['eyes']
    if len(eyes) == 2:
        (ax, ay), (bx, by) = eyes
        gx, gy, gs = (ax + bx) / 2, (ay + by) / 2, math.hypot(bx - ax, by - ay) / F
    else:
        (gx, gy), gs = eyes[0], c['glasses']
    pts = {'sunglasses': (gx, gy, gs), 'partyHat': (c['hat'][0], c['hat'][1], c['hat'][2]), 'nose': c['nose']}
    idle = [idle_field(hid, k) for k in range(N)]
    place, frames = {}, {k: [] for k in pts}
    for k in range(N):
        mv = [(moved(idle[k], x, y)[0] - x, moved(idle[k], x, y)[1] - y) for x, y, _ in pts.values()]
        mx_, my_ = sum(m[0] for m in mv) / 3, sum(m[1] for m in mv) / 3        # one move: they travel together
        rot = turn(idle[k], gx, gy) - turn(idle[0], gx, gy)
        for name, (x, y, s) in pts.items():
            frames[name].append((round((x + mx_) / F, 4), round((y + my_) / F, 4), round(rot, 4)))
    for name, (x, y, s) in pts.items():
        place[name] = (frames[name][0][0], frames[name][0][1], round(s, 4))
        frames[name] = [(f[0], f[1], round(f[2] - frames[name][0][2], 4)) for f in frames[name]]
    tilts = {'partyHat': c.get('hat_tilt', 0.0), 'sunglasses': c.get('glasses_tilt', 0.0)}
    fit = 1.0
    try:
        fit = json.load(open(O + '/attack_fit.json')).get(hid, 1.0)
    except (OSError, ValueError):
        pass
    e0 = moved(idle[0], gx, gy)
    r0 = turn(idle[0], gx, gy)
    track = []
    for k in range(10):
        D = attack_field(hid, k, fit)
        e = moved(D, gx, gy)
        track.append((0, round((e[0] - e0[0]) / F, 4), round((e[1] - e0[1]) / F, 4), round(turn(D, gx, gy) - r0, 4)))
    return place, frames, tilts, track


def write_costumes(ids):
    """The MYS rows of costume_fits.dart, costume_action_tracks.dart and the glasses' views."""
    all_ = {h: costume_fits(h) for h in ids}
    pth = REPO + '/lib/models/costume_fits.dart'
    s = open(pth).read()
    for h in ids:
        s = re.sub(r"    '%s': \([-\d., e]+\),\n" % h, '', s)
        s = re.sub(r"    '%s': \[\n(?:      \(.*\),\n)+    \],\n" % h, '', s)
        s = re.sub(r"    '%s': -?[\d.]+,\n" % h, '', s)
    a, b = s.index('const _tilts'), s.index('const _frameFits')
    head, tilts, tail = s[:a], s[a:b], s[b:]
    for name in ('partyHat', 'nose', 'sunglasses'):
        key = '  FamilyCostume.%s: {\n' % name
        rows = ''.join("    '%s': (%r, %r, %r),\n" % ((h,) + all_[h][0][name]) for h in ids)
        i = head.index(key) + len(key)
        head = head[:i] + rows + head[i:]
        rows = ''.join("    '%s': [\n%s    ],\n" % (h, ''.join('      (%r, %r, %r),\n' % f for f in all_[h][1][name])) for h in ids)
        i = tail.index(key) + len(key)
        tail = tail[:i] + rows + tail[i:]
    one = re.search(r"  FamilyCostume\.partyHat: \{([^\n]*)\},\n", tilts)
    if one:                                                # (the hat's tilts on one line: opened out)
        items = [x.strip() for x in one.group(1).split(',') if x.strip()]
        tilts = tilts.replace(one.group(0), '  FamilyCostume.partyHat: {\n' + ''.join('    %s,\n' % x for x in items) + '  },\n')
    for name in ('partyHat', 'sunglasses'):
        key = '  FamilyCostume.%s: {\n' % name
        i = tilts.index(key)
        j = tilts.index('\n  },\n', i) + 1
        rows = ''.join("    '%s': %r,\n" % (h, all_[h][2][name]) for h in ids if all_[h][2][name])
        tilts = tilts[:j] + rows + tilts[j:]
    open(pth, 'w').write(head + tilts + tail)
    pth = REPO + '/lib/models/costume_action_tracks.dart'
    s = open(pth).read()
    for h in ids:
        s = re.sub(r"  '%s': \[\n(?:    \[.*\],\n){4}  \],\n" % h, '', s)
    blocks = ''.join("  '%s': [\n    [],\n    [],\n    [%s],\n    [],\n  ],\n" % (
        h, ', '.join('(%d, %r, %r, %r)' % f for f in all_[h][3])) for h in ids)
    i = s.index("  'PIP01': [\n")
    s = s[:i] + blocks + s[i:]
    open(pth, 'w').write(s)
    pth = REPO + '/lib/widgets/fx/alchemical_sunglasses.dart'
    s = open(pth).read()
    for h in ids:
        s = re.sub(r"    '%s': \w+,\n" % h, '', s)
    rows = ''.join("    '%s': %s,\n" % (h, COSTUME[h]['view']) for h in ids if COSTUME[h]['view'] != 'threeQuarter')
    key = "    'WNG15': threeQuarter,\n"
    i = s.index(key) + len(key)
    s = s[:i] + ('    // The Mystics drawn anew: side on, or face on.\n' if rows and '// The Mystics drawn anew' not in s else '') + rows + s[i:]
    open(pth, 'w').write(s)
    for h in ids:
        print(h, 'costumes', all_[h][0], 'attack track', [f[1:3] for f in all_[h][3]][4])


def overlay(ids):
    """The parts (coloured by their weight), the head (magenta) and tail (cyan) outlines."""
    cols = [(255, 0, 255), (0, 255, 255), (255, 255, 0), (0, 255, 0), (255, 128, 0), (128, 128, 255), (255, 80, 80)]
    Sx = Image.new('RGB', (5 * 420, 2 * 420), (60, 60, 70))
    for j, hid in enumerate(ids):
        a, sil, cfg, masks, union, body = prepare(hid)
        fl, d, nx, ny = ns['fields'](cfg, masks, body, sil)
        rgb = a[..., :3].copy()
        rgb[~sil] = (60, 60, 70)
        for f, col in zip(fl, cols):
            w = (f['w'] * sil)[..., None] * 0.7
            rgb = rgb * (1 - w) + np.array(col, np.float32) * w
        im = Image.fromarray(rgb.astype(np.uint8))
        dd = ImageDraw.Draw(im)
        p = P[hid]
        dd.polygon(p['head'], outline=(255, 0, 255), width=5)
        dd.ellipse((p['neck'][0] - 14, p['neck'][1] - 14, p['neck'][0] + 14, p['neck'][1] + 14), fill=(255, 0, 255))
        if p.get('tail'):
            dd.polygon(p['tail'][1], outline=(0, 255, 255), width=5)
            tx, ty = p['tail'][0]
            dd.ellipse((tx - 14, ty - 14, tx + 14, ty + 14), fill=(0, 255, 255))
        for yy in (p['hip'], p['foot']):
            dd.line((0, yy, F, yy), fill=(255, 255, 255), width=3)
        im = im.resize((420, 420), Image.LANCZOS)
        ImageDraw.Draw(im).text((8, 8), hid, fill='white', font=font)
        Sx.paste(im, ((j % 5) * 420, (j // 5) * 420))
    Sx.save(O + '/overlay.png')


def save_attack(hid, frames, name='fire_spritesheet'):
    """The sheet as the game takes it (600 px frames, 4 x 3), into <scratch>/actions for install_fires.py."""
    os.makedirs(S + '/actions', exist_ok=True)
    half = 600
    sheet = Image.new('RGBA', (4 * half, 3 * half))
    for k, f in enumerate(frames):
        sheet.paste(f.convert('RGBa').resize((half, half), Image.LANCZOS).convert('RGBA'), ((k % 4) * half, (k // 4) * half))
    sheet.save('%s/actions/%s_%s.png' % (S, hid, name), optimize=True)


def attack_eyes(hid):
    """The albino's red eyes through the attack: the idle's eye layer (built by
    test/albino_eyes_build_test.dart beside the idle sheet) for its first frame, carried
    through the same fields that draw each attack frame. None if the species has none."""
    p = '%s/assets/images/creatures/mystic/%s_%s_albino_eyes.png' % (REPO, hid, P[hid]['n'])
    if not os.path.exists(p):
        return None
    ov = Image.open(p).convert('RGBA')
    e = ov.size[0] // 4
    src = np.array(ov.crop((0, 0, e, e)).convert('RGBa').resize((F, F), Image.BICUBIC)).astype(np.float32)
    fit = json.load(open(O + '/attack_fit.json')).get(hid, 1.0)
    out = []
    for k in range(10):
        Dx, Dy = attack_field(hid, k, fit)
        f = np.clip(inv_warp(src, Dx, Dy), 0, 255)
        out.append(Image.fromarray(f.astype(np.uint8), 'RGBa').convert('RGBA'))
    return out


ids = ONLY or sorted(P)
if MODE == 'overlay':
    overlay(ids)
elif MODE == 'costumes':                                   # the costumes' fits and tracks, written into the game
    write_costumes(ids)
elif MODE == 'attack_eyes':                                # only the albino eyes through the attack (after the idle's are rebuilt)
    for h in ids:
        eyes = attack_eyes(h)
        if eyes:
            save_attack(h, eyes, 'fire_eyes')
            print(h, 'attack eyes', flush=True)
elif MODE == 'attack':                                     # the attacks, and a sheet and a GIF of them to look at
    C2 = 220
    rows = []
    for h in ids:
        fr = build_attack(h)
        save_attack(h, fr)
        eyes = attack_eyes(h)
        if eyes:                                           # (install_fires.py lays it beside the attack)
            save_attack(h, eyes, 'fire_eyes')
        rows.append((h, [ns['cell'](f, C2) for f in fr]))
    cs = Image.new('RGB', (110 + 10 * C2, len(rows) * C2), BG)
    d = ImageDraw.Draw(cs)
    for j, (h, cells) in enumerate(rows):
        for k, c in enumerate(cells):
            cs.paste(c, (110 + k * C2, j * C2))
        d.text((8, j * C2 + 90), h, fill=(230, 210, 160), font=font)
    tag = '_'.join(ONLY) if ONLY else 'all'
    cs.save('%s/attack_%s_contact.png' % (O, tag))
else:
    cells = [build_flap(h) if h in WINGS_IDLE else ns['build'](h) for h in ids]
    cols = 3
    rows = -(-len(cells) // cols)
    w, h = cells[0][0].size
    fr = []
    for k in range(N):
        c = Image.new('RGB', (cols * (w + 16), rows * (h + 10)), BG)
        for j, g in enumerate(cells):
            c.paste(g[k], ((j % cols) * (w + 16), (j // cols) * (h + 10)))
        fr.append(c)
    tag = '_'.join(ONLY) if ONLY else 'all'
    fr[0].save('%s/mystics_%s_side_by_side.gif' % (O, tag), save_all=True, append_images=fr[1:], duration=DUR, loop=0)
