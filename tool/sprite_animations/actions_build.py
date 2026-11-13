"""Hop, fire and sleep for every Let, Horn, Wing and Pip, from each one's original drawn
frames (read from git HEAD) and the rigs placed for the idle pass. Masks, Kin and Mystics
(MSK, KIN, MYS) get a fire (the attack) only, from their rigs in this file: run them at
scale 1, and with numpy (RIG=1 also writes each one's rig, marked on its first frame).

  body  : squash and stretch about the feet, a lift, the head moved/turned about the neck,
          the tail swung about its root (one smooth field, as in the idle pass)
  eyes  : found from the species' albino eye overlay, covered with the skin around them and
          redrawn shut (happy arcs, sleeping curves) or half shut under a lid (aiming)
  drawn : the original's own frames keep cycling, so flames, steam and wings stay alive

  lit   : (Masks, Kin, Mystics) the eyes and the marks that glow on them flare at the snap,
          what burns or grows on the head reaches out, crystal glints

usage (from the repo root): actions_build.py <scratch> <family> [scale]
"""
import sys, os, io, math, json, subprocess
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageStat, ImageChops

S_DIR, FAM = sys.argv[1], sys.argv[2]
R = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
REPO = os.getcwd()
OUT = S_DIR + '/actions'
os.makedirs(OUT, exist_ok=True)
BG = (14, 14, 18, 255)


def sm(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def rot(x, y, px, py, deg):
    a = math.radians(deg)
    dx, dy = x - px, y - py
    return (dx * math.cos(a) - dy * math.sin(a) - dx, dx * math.sin(a) + dy * math.cos(a) - dy)


def load(script, marker, argv):
    src = open(S_DIR + '/' + script).read()
    src = src[:src.index(marker)]
    old = sys.argv
    sys.argv = ['x'] + argv
    ns = {}
    exec(compile(src, script, 'exec'), ns)
    sys.argv = old
    return ns


# The commit that still holds the four drawn frames of every Horn, Wing, Pip and Let (before the
# 8-frame idles went in): what the actions are made from.
ORIG = os.environ.get('ORIG', 'c3c79f89')


def head_img(path):
    return Image.open(io.BytesIO(subprocess.check_output(['git', 'show', ORIG + ':' + path]))).convert('RGBA')


CREATURES = {c['id']: c for c in json.load(io.BytesIO(subprocess.check_output(['git', 'show', ORIG + ':assets/data/alchemons_creatures.json'])))['creatures']}
HORN_OFF = {'HOR01': [(0, 5), (1, -1), (1, 0)], 'HOR02': [(3, 5), (0, 10), (2, 10)], 'HOR03': [(4, 2), (0, 0), (0, 0)], 'HOR04': [(0, 5), (2, 5), (0, 0)],
            'HOR05': [(0, 2), (0, 7), (2, 3)], 'HOR06': [(0, 2), (1, 6), (-1, 3)], 'HOR07': [(-5, 6), (-11, 7), (-2, 4)], 'HOR08': [(0, -10), (0, 0), (0, -10)],
            'HOR09': [(1, 6), (0, 6), (3, 7)], 'HOR10': [(6, 1), (8, 6), (4, 1)], 'HOR11': [(-3, 1), (-7, 6), (0, 2)], 'HOR12': [(0, -17), (0, -5), (0, -10)],
            'HOR13': [(5, 4), (6, 10), (2, 13)], 'HOR14': [(2, 1), (0, 7), (3, 10)], 'HOR15': [(2, 3), (5, 3), (0, 0)], 'HOR16': [(5, 2), (5, 0), (0, 0)],
            'HOR17': [(3, 1), (1, 3), (6, 5)]}


def solid(f):
    return f.getchannel('A').point(lambda v: 255 if v > 128 else 0).getbbox()


MANE_EYES = {
    'MAN01': [(337, 605, 16, 30), (510, 600, 22, 32)], 'MAN02': [(330, 610, 10, 30), (495, 597, 38, 34)],
    'MAN03': [(318, 570, 16, 45), (517, 572, 42, 46)], 'MAN04': [(325, 575, 14, 40), (517, 578, 32, 44)],
    'MAN05': [(340, 515, 30, 20), (458, 512, 34, 20)],
    'MAN06': [(330, 590, 16, 12), (470, 585, 30, 15)], 'MAN07': [(330, 600, 9, 11), (520, 592, 18, 18)],
    'MAN08': [(345, 590, 12, 30), (515, 580, 24, 36)], 'MAN09': [(340, 607, 14, 10), (497, 602, 24, 12)],
    'MAN10': [(333, 612, 10, 18), (522, 605, 16, 26)], 'MAN11': [(340, 600, 12, 28), (510, 598, 28, 30)],
    'MAN12': [(328, 592, 8, 36), (520, 592, 30, 38)], 'MAN13': [(318, 632, 18, 14), (470, 625, 30, 16)],
    'MAN14': [(327, 598, 8, 22), (515, 605, 18, 28)], 'MAN15': [(335, 625, 16, 28), (520, 615, 36, 28)],
    'MAN16': [(333, 620, 10, 22), (513, 610, 20, 24)], 'MAN17': [(330, 605, 9, 18), (515, 605, 18, 22)],
    'MAN18': [(310, 612, 9, 9), (520, 605, 18, 13)],
    # Airlet (512 px frame): its eyes are drawn shut in happy arcs; asleep they rest
    'LET04': [(173, 248, 22, 13), (257, 248, 24, 13)],
}

MANE_INK = {'MAN06': (255, 135, 70, 255), 'MAN14': (40, 105, 122, 255), 'LET11': (84, 62, 150, 255)}
MANE_MODES = {'MAN05': ('sleep',), 'LET04': ('sleep',)}      # Steammane's eyes are drawn squeezed shut already: only relaxed for sleep


# ---- Masks, Kin and Mystics: an attack only --------------------------------------------------
# Their four drawn frames are the idle as it is (512 px, read from the working tree). The attack
# is the same gather and snap as the others', and each one's own material goes with it: its eyes
# and the lit marks on it flare, what burns or grows on its head reaches out, crystal glints.
NEW_FAMS = ('MSK', 'KIN', 'MYS')
FAM_TITLES = {'HOR': 'HORNS', 'WNG': 'WINGS', 'PIP': 'PIPS', 'LET': 'LETS', 'MAN': 'MANES', 'MSK': 'MASKS', 'KIN': 'KIN', 'MYS': 'MYSTICS'}

# the light each element gives off
GLOW = {'Fire': (255, 170, 60), 'Water': (150, 235, 255), 'Earth': (185, 235, 70), 'Air': (205, 230, 255), 'Steam': (255, 232, 195),
        'Lava': (255, 150, 40), 'Lightning': (255, 240, 120), 'Mud': (255, 175, 70), 'Ice': (190, 240, 255), 'Dust': (255, 215, 140),
        'Crystal': (175, 240, 255), 'Plant': (205, 235, 90), 'Poison': (195, 240, 70), 'Spirit': (215, 255, 245), 'Dark': (220, 130, 255),
        'Light': (255, 250, 205), 'Blood': (255, 80, 60)}

# how far what is on the head reaches at the snap, by what it is made of (a cloud is never pulled:
# it only swells a little, whole)
REACH = {'flame': 0.22, 'leaf': 0.10, 'bolt': 0.12, 'solid': 0.05, 'cloud': 0.05, None: 0.0}

# Masks (front on): neck = where the mask's chin meets the body; top = (x, y, material) where
# what is on the head rises from; eyes = (x, y, rx, ry[, 'd' a dark socket | 'b' a lit eye | 'w' all of it]);
# marks = how the lit marks on the mask are told from it ('sv' by colour, 'lum' by light);
# puffs = (x, y, [(direction in degrees, r), ...]): a cloud of steam or dust with (x, y) inside it
# pushes a new puff, r across, out of its edge in each of those directions at the snap.
MSK_P = {
    'MSK01': dict(neck=(256, 345), top=(240, 170, 'flame'), eyes=[(190, 250, 34, 27), (290, 246, 34, 27)], marks='sv'),
    'MSK02': dict(neck=(256, 345), top=(256, 152, 'flame'), eyes=[(207, 253, 24, 32), (317, 253, 24, 32)], marks='lum', pct=95),
    'MSK03': dict(neck=(256, 345), top=(256, 128, 'solid'), eyes=[(190, 230, 30, 32), (300, 225, 32, 32)], marks='sv'),
    'MSK04': dict(neck=(256, 350), top=(256, 178, 'cloud'), eyes=[(190, 255, 25, 33), (315, 255, 25, 33)], marks='sv', tint=(205, 175, 255),
                  puffs=(256, 115, [(-150, 16), (-30, 15), (-178, 13), (-3, 13)])),
    'MSK05': dict(neck=(256, 345), top=(245, 165, 'cloud'), eyes=[(182, 250, 24, 20), (290, 245, 26, 20)], marks='lum',
                  puffs=(250, 95, [(-145, 15), (-38, 15), (175, 13), (5, 13)])),
    'MSK06': dict(neck=(256, 350), top=(250, 170, 'flame'), eyes=[(188, 245, 24, 18), (300, 245, 26, 18)], marks='sv'),
    'MSK07': dict(neck=(240, 340), top=(235, 140, 'bolt'), eyes=[(180, 268, 18, 20), (258, 268, 22, 22)], marks='lum'),
    'MSK08': dict(neck=(256, 345), top=(256, 130, 'solid'), eyes=[(198, 245, 27, 29), (305, 245, 27, 29)], marks='sv'),
    'MSK09': dict(neck=(256, 350), top=(250, 140, 'solid'), eyes=[(203, 255, 25, 29, 'd'), (300, 255, 27, 29, 'd')], marks='lum',
                  glint=[(250, 70), (180, 140), (330, 150)]),
    'MSK10': dict(neck=(250, 355), top=(240, 190, 'cloud'), eyes=[(205, 280, 17, 21), (300, 280, 17, 21)], marks='sv',
                  puffs=(262, 85, [(-160, 14), (-25, 14), (165, 12)])),
    'MSK11': dict(neck=(256, 360), top=(256, 170, 'solid'), eyes=[(213, 270, 25, 25), (302, 270, 25, 25)], marks='lum',
                  glint=[(256, 45), (170, 80), (335, 85), (125, 130), (385, 135)]),
    'MSK12': dict(neck=(256, 350), top=(256, 148, 'leaf'), eyes=[(200, 250, 28, 33), (312, 250, 28, 33)], marks='sv'),
    'MSK13': dict(neck=(240, 345), top=(235, 172, 'flame'), eyes=[(182, 265, 24, 24), (268, 262, 26, 26)], marks='sv'),
    'MSK14': dict(neck=(240, 355), top=(232, 178, 'flame'), eyes=[(175, 268, 19, 28), (262, 268, 21, 28)], marks='lum'),
    'MSK15': dict(neck=(256, 360), top=(256, 190, 'flame'), eyes=[(212, 270, 21, 16), (310, 268, 23, 16)], marks='sv'),
    'MSK16': dict(neck=(256, 322), eyes=[(190, 195, 40, 27), (335, 195, 42, 27)], marks='lum'),
    'MSK17': dict(neck=(256, 305), eyes=[(195, 200, 34, 28), (325, 198, 36, 28)], marks='lum'),
    'MSK18': dict(neck=(256, 320), eyes=[(205, 190, 38, 27), (345, 190, 40, 27)], marks='lum'),
}

# Kin (three-quarter view, facing left): head = (x, y, r) of the round head; eyes = its one eye;
# neck = what the head turns about; xb = the head's and crest's right-hand edge as (y, x) points
# (the tail lies beyond it); tail = what the tail swings about; crest = what the crest is made of.
KIN_P = {
    'KIN01': dict(head=(215, 235, 65), eyes=[(208, 238, 36, 36)], neck=(235, 300), xb=[(0, 345), (215, 335), (245, 285), (275, 262), (512, 262)], tail=(290, 310), crest='flame'),
    'KIN02': dict(head=(233, 230, 58), eyes=[(230, 235, 30, 30)], neck=(240, 290), xb=[(0, 320), (190, 310), (215, 285), (512, 285)], tail=(275, 290), crest='flame', marks='sv'),
    'KIN03': dict(head=(235, 240, 85), eyes=[(213, 248, 44, 44)], neck=(255, 320), xb=[(0, 400), (195, 395), (225, 335), (512, 335)], tail=(345, 330), crest='leaf'),
    'KIN04': dict(head=(190, 205, 75), eyes=[(190, 205, 38, 38)], neck=(225, 280), xb=[(0, 305), (95, 305), (125, 268), (512, 268)], tail=(285, 300), crest='cloud'),
    'KIN05': dict(still=True, head=(220, 240, 110), eyes=[(220, 240, 55, 55)], neck=(235, 330), xb=[(0, 420), (225, 415), (250, 352), (512, 352)], tail=(360, 340), crest=None,
                  puffs=(215, 215, [(-135, 18), (-50, 17), (-178, 15), (-95, 15)])),
    'KIN06': dict(head=(220, 255, 65), eyes=[(196, 255, 37, 37)], neck=(245, 320), xb=[(0, 330), (175, 325), (200, 295), (512, 295)], tail=(325, 320), crest='flame', marks='sv'),
    'KIN07': dict(head=(215, 235, 62), eyes=[(210, 238, 34, 34)], neck=(225, 300), xb=[(0, 400), (255, 395), (272, 270), (512, 270)], tail=(290, 320), crest='bolt', marks='lum'),
    'KIN08': dict(head=(210, 215, 95), eyes=[(208, 215, 55, 55)], neck=(250, 310), xb=[(0, 400), (290, 395), (320, 330), (512, 330)], tail=(380, 390), crest=None),
    'KIN09': dict(head=(195, 215, 65), eyes=[(171, 212, 43, 44)], neck=(225, 280), xb=[(0, 395), (170, 390), (200, 345), (512, 345)], tail=(330, 320), crest='solid',
                  glint=[(248, 28), (160, 92), (334, 48)]),
    'KIN10': dict(still=True, head=(190, 230, 90), eyes=[(194, 235, 47, 47)], neck=(225, 310), xb=[(0, 385), (260, 380), (300, 330), (512, 330)], tail=(345, 385), crest=None,
                  puffs=(240, 95, [(-35, 14), (-150, 13), (-90, 12)])),
    'KIN11': dict(head=(210, 225, 65), eyes=[(210, 228, 42, 42)], neck=(235, 290), xb=[(0, 390), (165, 385), (185, 300), (512, 300)], tail=(300, 310), crest='solid',
                  glint=[(252, 30), (165, 75), (330, 85), (365, 195)]),
    'KIN12': dict(head=(220, 205, 62), eyes=[(202, 211, 40, 46)], neck=(240, 270), xb=[(0, 420), (215, 415), (245, 300), (512, 300)], tail=(320, 330), crest='leaf'),
    'KIN13': dict(head=(235, 215, 80), eyes=[(225, 222, 44, 44)], neck=(250, 300), xb=[(0, 395), (285, 390), (305, 350), (512, 350)], tail=(360, 340), crest='flame'),
    'KIN14': dict(still=True, head=(210, 190, 75), eyes=[(197, 185, 38, 38)], neck=(225, 270), xb=[(0, 266), (512, 266)], tail=(300, 290), crest='flame'),
    'KIN15': dict(still=True, head=(190, 235, 80), eyes=[(165, 242, 42, 42)], neck=(230, 300), xb=[(0, 338), (90, 338), (150, 296), (250, 278), (512, 278)], tail=(310, 310), crest='flame', tint=(255, 240, 210)),
    'KIN16': dict(head=(232, 130, 50), eyes=[(235, 130, 32, 32)], neck=(240, 190), xb=[(0, 330), (512, 330)], tail=(290, 300), crest='flame'),
    'KIN17': dict(head=(190, 215, 60), eyes=[(182, 210, 30, 30)], neck=(225, 270), xb=[(0, 320), (195, 315), (220, 270), (512, 270)], tail=(300, 300), crest='flame', marks='sv'),
}

# Mystics, each its own build: head = (x, y, r) of what moves with the head (None: the body moves
# as one); neck = what it turns about; face = -1 facing left, 1 right, 0 front on; fl = what
# reaches out at the snap, as (x, y, r0, direction, half-width in degrees, how far, material):
# everything further than r0 from (x, y) within that wedge; seq = which drawn frame each of the
# ten is made from (a wing-beat told in its own frames); squash = how much of the crouch it takes.
MYS_P = {
    'MYS01': dict(head=None, face=0, seq=[0, 5, 0, 5, 3, 2, 4, 4, 5, 0], floats=True, squash=0.5, marks='lum'),
    'MYS02': dict(head=(250, 150, 105), neck=(280, 290), face=-1, eyes=[(241, 194, 20, 16)], marks='lum', pct=95, amp=0.7),
    'MYS03': dict(head=(300, 200, 110), neck=(290, 300), face=0, eyes=[(277, 197, 17, 16), (348, 200, 14, 16)], amp=0.7),
    'MYS04': dict(head=(256, 150, 75), neck=(256, 250), face=0, eyes=[(239, 170, 12, 12), (285, 170, 12, 12)],
                  fl=[(256, 290, 80, -145, 40, 0.07, 'solid'), (256, 290, 80, -35, 40, 0.07, 'solid')]),
    'MYS05': dict(head=(125, 250, 75), neck=(190, 300), face=-1, eyes=[(73, 256, 15, 18), (140, 261, 21, 18)], marks='sv', amp=0.7),
    'MYS06': dict(head=(425, 215, 70), neck=(340, 240), face=1, eyes=[(387, 186, 15, 17), (461, 188, 12, 14)], marks='sv', amp=0.7,
                  fl=[(280, 210, 70, -100, 50, 0.14, 'flame')]),
    'MYS07': dict(head=(130, 205, 95), neck=(230, 280), face=-1, eyes=[(109, 214, 13, 19), (191, 214, 22, 21)], marks='sv', amp=0.7),
    'MYS08': dict(head='above', neck=(230, 300), band=(215, 70), face=-1, marks='sv', amp=0.6),
    'MYS09': dict(head=(195, 155, 105), neck=(180, 290), face=1, eyes=[(205, 190, 18, 17)], amp=0.6,
                  fl=[(300, 222, 8, -25, 55, 0.30, 'cloud')], glint=[(193, 22), (75, 130), (110, 45)]),
    'MYS10': dict(head=(115, 185, 75), neck=(150, 290), face=-1, eyes=[(90, 192, 8, 14), (130, 191, 13, 14)], amp=0.8,
                  fl=[(130, 200, 45, -70, 70, 0.10, 'flame')]),
    'MYS11': dict(head=(130, 265, 60), neck=(190, 330), face=-1, eyes=[(130, 280, 24, 24, 'w')], marks='lum', pct=95, amp=0.5,
                  glint=[(90, 45), (195, 40), (310, 60), (345, 165), (55, 190)]),
    'MYS12': dict(head=(160, 170, 120), neck=(215, 300), face=-1, eyes=[(140, 224, 17, 23, 'w'), (191, 132, 20, 22, 'w'), (432, 392, 20, 24, 'w')], amp=0.6),
    'MYS13': dict(head=None, face=0, eyes=[(94, 152, 28, 28, 'w'), (155, 102, 31, 31, 'w'), (228, 150, 30, 30, 'w')], squash=1.15),
    'MYS14': dict(head=(235, 130, 85), neck=(240, 220), face=0, squash=0.6, eyes=[(202, 175, 15, 17, 'd'), (252, 175, 17, 17, 'd')],
                  fl=[(235, 150, 50, -90, 75, 0.16, 'flame')]),
    'MYS15': dict(head=None, face=0, seq=[0, 0, 0, 0, 2, 4, 4, 3, 1, 0], squash=0.6, marks='lum', tint=(225, 230, 255)),
    'MYS16': dict(head=None, face=0, eyes=[(294, 202, 11, 12), (338, 207, 11, 12)], marks='lum',
                  fl=[(310, 200, 55, -90, 130, 0.10, 'flame')]),
    'MYS17': dict(head=(245, 100, 55), neck=(245, 150), face=0, squash=0.6, eyes=[(218, 110, 9, 10), (243, 107, 10, 10)], marks='lum',
                  fl=[(250, 200, 70, -160, 35, 0.06, 'solid'), (250, 200, 70, -20, 35, 0.06, 'solid')]),
}
MYS_TINT = {'MYS07': (150, 215, 255), 'MYS08': (225, 235, 95), 'MYS12': (255, 228, 90), 'MYS03': (205, 245, 80)}
NEW_P = dict(MSK_P, **KIN_P)
NEW_P.update(MYS_P)


def poly_x(pts, y):
    """x of the (y, x) polyline [pts] at height y."""
    if y <= pts[0][0]:
        return pts[0][1]
    for (y0, x0), (y1, x1) in zip(pts, pts[1:]):
        if y <= y1:
            return x0 + (x1 - x0) * (y - y0) / float(y1 - y0)
    return pts[-1][1]


def new_rig(rig, hid):
    """Where a Mask's, a Kin's or a Mystic's parts are."""
    fam, p = hid[:3], NEW_P[hid]
    rig.p = p
    rig.tint = p.get('tint') or MYS_TINT.get(hid) or GLOW[CREATURES[hid]['types'][0]]
    rig.neck, rig.tail = p.get('neck', (256, 300)), p.get('tail')
    rig.px = None
    rig.floats = bool(p.get('floats'))
    rig.tail_w = lambda x, y: 0.0
    nx, ny = rig.neck
    if fam == 'MSK':
        rig.head_w = lambda x, y: sm((ny + 12 - y) / 45)
        rig.side = 0
        tx = p.get('top')
        rig.fl = [('up', tx[0], tx[1], REACH[tx[2]], tx[2])] if tx else []
    elif fam == 'KIN':
        xb = p['xb']
        # (its right-hand edge is softer the higher it is: the head's turn carries a crest furthest there)
        rig.head_w = lambda x, y: sm((ny + 17 - y) / 55) * (1 - sm((x - poly_x(xb, y)) / (26 + 0.24 * max(0.0, ny - y))))
        ty = p['tail'][1]
        if not p.get('still'):                            # (a tail of cloud, or of wisps the head's own lie among, is left be)
            rig.tail_w = lambda x, y: sm((x - poly_x(xb, y)) / 21) * (1 - sm((y - ty - 30) / 30))
        rig.side = -1
        hx, hy, hr = p['head']
        rig.fl = [('out', hx, hy, hr * 0.95, -90, 80, REACH[p.get('crest')], p.get('crest'))] if p.get('crest') else []
    else:
        h = p.get('head')
        if h == 'above':                                  # (Bogdrya's three heads: all that stands above its back)
            by, bs = p['band']
            rig.head_w = lambda x, y: sm((by - y) / bs)
        elif h:
            hx, hy, hr = h
            rig.head_w = lambda x, y: 1 - sm((math.hypot(x - hx, y - hy) - hr) / (0.7 * hr))
        else:
            rig.head_w = lambda x, y: 0.0
        rig.side = p.get('face', 0)
        rig.fl = [('out',) + tuple(f[:5]) + (f[5], f[6]) for f in p.get('fl', [])]


def reach_fn(rig, t, amp):
    """What is on the head (a flame, leaves, a breath) reaching out by [t] (-1 drawn in .. 1 at the
    snap): where each drawn point is read from. A wedge, or all above a line, is scaled away from
    its root, so nothing is bent."""
    ops = []
    for f in rig.fl:
        a = f[-2] * amp * (t if t > 0 else 0.45 * t)
        if abs(a) > 1e-4:
            ops.append((f, 1 + a))
    if not ops:
        return None

    def fn(x, y):
        for f, s in ops:
            if f[0] == 'up':                              # all above the line ty, about (tx, ty)
                _, tx, ty = f[:3]
                w = sm((ty - y) / 14)
                if w > 0:
                    y = y - w * (y - ty) * (1 - 1 / s)
                    x = x - w * (x - tx) * (1 - 1 / (1 + 0.35 * (s - 1)))
            else:
                _, cx, cy, r0, ang, half = f[:6]
                d = math.hypot(x - cx, y - cy)
                if d > r0:
                    da = abs((math.degrees(math.atan2(y - cy, x - cx)) - ang + 180) % 360 - 180)
                    w = (1 - sm((da - half) / 22)) * sm((d - r0) / 10)
                    if rig.fam == 'KIN':                   # its crest only: not the tail's wisps that rise beside it
                        w *= rig.head_w(x, y)
                    if w > 0:
                        k_ = 1 - w * (d - r0) * (1 - 1 / s) / d
                        x, y = cx + (x - cx) * k_, cy + (y - cy) * k_
        return x, y
    return fn


def lit_map(rig, i):
    """How lit each pixel of drawn frame [i] can get (0..1): its eyes, and the marks that glow on it."""
    import numpy as np
    if i in rig._lit:
        return rig._lit[i]
    p, F0 = rig.p, rig.F0
    arr = np.asarray(rig.raw[i], dtype=np.float32)
    rgb, a = arr[..., :3], arr[..., 3] / 255.0
    lum = rgb @ np.array([0.3, 0.59, 0.11], np.float32)
    mx, mn = rgb.max(-1), rgb.min(-1)
    sv = (mx - mn) / 255.0                                  # (saturation x value)
    body = a > 0.8
    yy, xx = np.mgrid[0:F0, 0:F0].astype(np.float32)
    L = np.zeros((F0, F0), np.float32)
    if p.get('marks') and body.any():
        v = sv if p['marks'] == 'sv' else lum / 255.0
        region = body & (yy < rig.neck[1] + 10) if rig.fam == 'MSK' else body
        if rig.fam == 'MSK' and p.get('top', (0, 0, None))[2] == 'cloud':      # a cloud on its head is not lit
            region = region & (yy > p['top'][1])
        med, hi = np.median(v[region]), np.percentile(v[region], p.get('pct', 88))
        t0 = max(hi, med + 0.10)
        m = np.clip((v - t0) / 0.12, 0, 1) * region
        if p['marks'] == 'sv':                             # a mark is lighter than what it is drawn on, not only more coloured
            m = m * np.clip((lum - np.median(lum[region]) + 10) / 30, 0, 1)
        L = np.maximum(L, m * m * (3 - 2 * m))
    for e in p.get('eyes', []):
        ex, ey, rx, ry = e[:4]
        d = np.sqrt(((xx - ex) / rx) ** 2 + ((yy - ey) / ry) ** 2)
        inside = np.clip((1.0 - d) / 0.15, 0, 1) * body
        ring = (d > 1.15) & (d < 1.7) & body
        if not ring.any() or inside.max() <= 0:
            continue
        ring_l = np.median(lum[ring])
        mode = e[4] if len(e) > 4 else 'b' if rig.fam == 'KIN' else ('d' if (lum * inside).sum() / inside.sum() < ring_l - 12 else 'b')
        if mode == 'd':                                    # a dark socket: the dark of it lights up
            depth = max(12.0, ring_l - np.percentile(lum[inside > 0.5], 10))
            sel = np.clip((ring_l - 0.25 * depth - lum) / (0.35 * depth), 0, 1)
        else:                                              # a lit eye: all but its pupil and its outline
            sel = np.clip((lum - 55) / 60, 0, 1)
            rise = np.percentile(lum[inside > 0.5], 90) - ring_l
            if mode == 'b' and rise > 25:                  # brighter than the face it is in: only what is that bright
                sel = np.clip((lum - ring_l - 0.35 * rise) / (0.3 * rise), 0, 1)
        L = np.maximum(L, inside * sel)
    rig._lit[i] = L
    return L


def lit_frame(rig, i, e, glint=0.0):
    """Drawn frame [i] with its lit parts flared by [e] (0..1): brighter at the core, a bloom on the
    body round them and a little light past its edge."""
    if e <= 0.005 and glint <= 0.005:
        return rig.raw[i]
    import numpy as np
    L = lit_map(rig, i)
    F0 = rig.F0
    arr = np.asarray(rig.raw[i], dtype=np.float32)
    rgb, a = arr[..., :3], arr[..., 3] / 255.0
    tint = np.array(rig.tint, np.float32)
    if i not in rig._bloom:
        Li = Image.fromarray(np.clip(L * a * 255, 0, 255).astype(np.uint8), 'L')
        near = np.asarray(Li.filter(ImageFilter.GaussianBlur(5)), dtype=np.float32) / 255.0
        far = np.asarray(Li.filter(ImageFilter.GaussianBlur(14)), dtype=np.float32) / 255.0
        yy, xx = np.mgrid[0:F0, 0:F0].astype(np.float32)
        edge = np.clip((np.minimum(np.minimum(xx, F0 - 1 - xx), np.minimum(yy, F0 - 1 - yy)) - 2) / 14, 0, 1)
        rig._bloom[i] = (near, far, edge)
    near, far, edge = rig._bloom[i]
    core = 0.5 * tint + 0.5 * 255
    out = rgb + (e * L)[..., None] * (core - rgb) * (0.42 if rig.fam == 'KIN' else 0.9)     # (a Kin's great eye keeps its iris)
    g = np.clip(e * (1.3 * near + 1.6 * far), 0, 1)[..., None] * (tint / 255.0) * 0.85
    out = 255 - (255 - out) * (1 - g)
    halo = np.clip(e * (0.9 * near + 1.5 * far), 0, 0.85) * edge * (1 - a)
    na = a + (1 - a) * halo
    out = (out * a[..., None] + tint * ((1 - a) * halo)[..., None]) / np.maximum(na, 1e-4)[..., None]
    img = Image.fromarray(np.dstack([np.clip(out, 0, 255), np.clip(na * 255, 0, 255)]).astype(np.uint8), 'RGBA')
    if glint > 0.005:
        for j, (gx, gy) in enumerate(rig.p.get('glint', [])):
            star(img, gx, gy, (13 + 5 * (j % 3)) * (0.55 + 0.45 * glint), glint, rig.tint)
    return img


def puff_layer(rig, i, t):
    """What a cloud pushes out at the snap, to lie under drawn frame [i]: at each of its puffs a
    small cluster of rounds under one outline, in the cloud's own colours there, [t] (0..1) of
    the way out of its edge. The cloud's own art is not touched."""
    S2, F0 = 3, rig.F0
    frame = rig.raw[i]
    rgb, al = frame.convert('RGB'), frame.getchannel('A')
    lay = Image.new('RGBA', (F0 * S2, F0 * S2), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    ox, oy, dirs = rig.p['puffs']
    ap = al.load()
    for j, (ang, r) in enumerate(dirs):
        ux, uy = math.cos(math.radians(ang)), math.sin(math.radians(ang))
        e = 0                                              # the cloud's edge that way, in this drawn frame
        while e < F0 and 0 <= ox + ux * e < F0 and 0 <= oy + uy * e < F0 and ap[int(ox + ux * e), int(oy + uy * e)] > 128:
            e += 1
        if e < 2 * r:
            continue
        x, y = ox + ux * (e - 0.55 * r), oy + uy * (e - 0.55 * r)       # it starts just inside
        ix, iy = ox + ux * (e - 1.6 * r), oy + uy * (e - 1.6 * r)       # its colour: the cloud a little further in
        box = (int(ix - r * 0.8), int(iy - r * 0.8), int(ix + r * 0.8), int(iy + r * 0.8))
        px = [c for c, a in zip(rgb.crop(box).getdata(), al.crop(box).getdata()) if a > 250]
        if not px:
            continue
        px.sort(key=lambda c: 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2])
        fill = px[len(px) // 2]
        rim = (int(x + ux * 0.55 * r - r * 0.5), int(y + uy * 0.55 * r - r * 0.5), int(x + ux * 0.55 * r + r * 0.5), int(y + uy * 0.55 * r + r * 0.5))
        ed = sorted((c for c, a in zip(rgb.crop(rim).getdata(), al.crop(rim).getdata()) if a > 250), key=lambda c: 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2])
        line = ed[len(ed) // 12] if ed else tuple(int(v * 0.7) for v in fill)      # the cloud's own outline there
        go = t * r * 0.85 * (1.0 if j % 2 == 0 else 0.8)   # how far its middle has come: never clear of the edge
        cx, cy = x + ux * go, y + uy * go
        g = 0.45 + 0.55 * t
        rounds = [(cx, cy, r * g), (cx - uy * r * 0.62 - ux * r * 0.3, cy + ux * r * 0.62 - uy * r * 0.3, r * 0.66 * g),
                  (cx + uy * r * 0.58 - ux * r * 0.35, cy - ux * r * 0.58 - uy * r * 0.35, r * 0.6 * g)]
        w = 2.6 * F0 / 512.0
        for qx, qy, qr in rounds:                          # one outline round them all, then their fill
            d.ellipse(((qx - qr - w) * S2, (qy - qr - w) * S2, (qx + qr + w) * S2, (qy + qr + w) * S2), fill=line + (255,))
        for qx, qy, qr in rounds:
            d.ellipse(((qx - qr) * S2, (qy - qr) * S2, (qx + qr) * S2, (qy + qr) * S2), fill=fill + (255,))
    return lay.resize((F0, F0), Image.LANCZOS)


def star(img, x, y, r, alpha, tint):
    """A glint: a small four-pointed star of light at (x, y)."""
    S2 = 4
    box = int(r * 1.6) + 4
    lay = Image.new('RGBA', (2 * box * S2, 2 * box * S2), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    c = box * S2
    soft = tuple(int(0.4 * t + 0.6 * 255) for t in tint)
    for rr, th in ((r, 0.16), (r * 0.55, 0.30)):
        for q in range(2):
            ang = math.pi / 2 * q + (math.pi / 4 if rr < r else 0)
            ux, uy = math.cos(ang), math.sin(ang)
            d.polygon([(c + ux * rr * S2, c + uy * rr * S2), (c - uy * rr * th * S2, c + ux * rr * th * S2),
                       (c - ux * rr * S2, c - uy * rr * S2), (c + uy * rr * th * S2, c - ux * rr * th * S2)], fill=soft + (int(235 * alpha),))
    d.ellipse((c - r * 0.2 * S2, c - r * 0.2 * S2, c + r * 0.2 * S2, c + r * 0.2 * S2), fill=(255, 255, 255, int(255 * alpha)))
    lay = lay.resize((2 * box, 2 * box), Image.LANCZOS)
    glow = lay.filter(ImageFilter.GaussianBlur(2.5))
    for l in (glow, lay):
        img.alpha_composite(l, (max(0, int(x) - box), max(0, int(y) - box)))


# The attack's own curves beside FIRE's: how lit its eyes and marks are, how far its crest reaches
# (drawn in through the gather), and how far a front-on head sinks and lifts (of 512).
ATTACK = dict(
    lit=[0, 0.10, 0.20, 0.34, 1.00, 0.85, 0.50, 0.25, 0.08, 0],
    reach=[0, -0.4, -0.8, -1.0, 1.0, 0.75, 0.25, -0.10, 0, 0],
    glint=[0, 0, 0, 0, 1.0, 0.8, 0.4, 0, 0, 0],
    puff=[0, 0, 0, 0, 0.75, 1.0, 0.7, 0.3, 0, 0],
    hdy=[0, 2, 5, 6, -8, -5, 2, -1, 0, 0])


def build_attack(rig, fixed=None):
    """A Mask's, a Kin's or a Mystic's attack: FIRE's gather and snap, with its own material."""
    p, n = rig.p, len(rig.frames)
    seq = p.get('seq') or [k % n for k in range(10)]
    A, B = FIRE, ATTACK
    f1200, f512 = rig.F0 / 1200.0, rig.F0 / 512.0
    amt = p.get('squash', 1.0) * (0.4 if rig.floats else 1.0)
    amp = p.get('amp', 1.0)
    up, wide = fixed or (1.0, 1.0)
    ra = 1.0                                               # how much of its reach fits in the cell
    for attempt in range(1 if fixed else 10):
        out = []
        for k in range(10):
            sx, sy = A['sx'][k], A['sy'][k]
            if sy > 1:
                sx, sy = 1 + (sx - 1) * up * amt, 1 + (sy - 1) * up * amt
            else:
                sx, sy = 1 + (sx - 1) * wide * amt, 1 + (sy - 1) * amt
            if rig.side:                                   # in profile: the head rears back, then snaps forward
                hd = (-rig.side * A['hdx'][k] * f1200 * wide * amp, 0)
                hrot = -rig.side * A['hrot'][k] * amp * (up if A['hrot'][k] > 0 else 1)
            else:                                          # front on: it sinks into its shoulders, then lifts
                dy = B['hdy'][k] * f512 * amp
                hd, hrot = (0, dy * (up if dy < 0 else 1)), 0
            src = lit_frame(rig, seq[k], B['lit'][k], B['glint'][k])
            if B['puff'][k] > 0 and p.get('puffs'):       # a cloud's new puffs lie under it, and show past its edge
                under = puff_layer(rig, seq[k], B['puff'][k])
                under.alpha_composite(src)
                src = under
            if src.size[0] != rig.F:
                src = src.resize((rig.F, rig.F), Image.LANCZOS)
            out.append(rig.pose(seq[k], None, sx, sy, 0, hd, hrot, -rig.side * A['trot'][k] * 0.4 if rig.side else 0,
                                src=src, extra=reach_fn(rig, B['reach'][k], ra)))
        top = side_hit = False
        for f in out:                                      # nothing of it within 2 px of the cell's edge, its soft outline included
            bb = f.getchannel('A').point(lambda v: 255 if v > 40 else 0).getbbox()
            top |= bb[1] < 2
            side_hit |= bb[0] < 2 or bb[2] > rig.F - 2
        if not top and not side_hit:
            break
        if top and up > 0.3:                               # the stretch gives first, then the reach
            up *= 0.6
        elif top:
            up, ra = (0.0 if up < 0.1 else up * 0.7), ra * 0.6
        if side_hit:
            wide, ra = (0.0 if wide < 0.15 else wide * 0.6), ra * 0.8
    rig.poses = rig.log[-len(out):]
    return out, (up, wide)


class Rig:
    """One creature: its frames (aligned, at render scale) and where its parts are."""

    def __init__(self, hid):
        self.id = hid
        c = CREATURES.get(hid)
        if hid.startswith('MAN'):
            mp = RIGS['MAN']['P'][hid]
            c = dict(name=mp['n'].replace('mane2', 'mane (stones)').capitalize(), image='x.png', spriteData=dict(frameWidth=1200, totalFrames=8, rows=2))
        sd = c['spriteData']
        self.name = c['name']
        self.F0 = sd['frameWidth']
        self.F = int(round(self.F0 * R))
        self.k = self.F / self.F0                      # native px -> render px
        sheet = 'assets/images/' + c['image'].replace('.png', '_spritesheet.png')
        if hid[:3] in NEW_FAMS:                          # as drawn, from the working tree: one row, as many frames as it holds
            a = Image.open(sheet).convert('RGBA')
            n, rows = a.size[0] // self.F0, 1
        else:
            a = Image.open('%s/manes/%s_%s_idle2_spritesheet.png' % (S_DIR, hid, mp['n'])).convert('RGBA') if hid.startswith('MAN') else head_img(sheet)
            n, rows = sd['totalFrames'], sd.get('rows', 1)
        cols = n // rows
        raw = [a.crop(((i % cols) * self.F0, (i // cols) * self.F0, (i % cols + 1) * self.F0, (i // cols + 1) * self.F0)) for i in range(n)]
        self.offs = [(0, 0)] * n
        fam = hid[:3]
        if fam in ('HOR', 'MAN'):
            ns = RIGS[fam]
            p = ns['P'][hid]
            self.offs = [(0, 0)] + HORN_OFF[hid] if fam == 'HOR' else [(0, 0)] * n
            self.neck, self.tail = p['neck'], p['tail']
            self.head_w = lambda x, y: ns['head_w'](p, x, y)
            self.tail_w = lambda x, y: ns['sm']((x - ns['xb'](p, y)) / 50) * (1 - ns['sm']((y - p['tail'][1] - 50) / 60))
            self.px = p['neck'][0] + 30
            self.floats = p['hip'] > 1100
            self.side = True
        elif fam == 'PIP':
            ns = RIGS['PIP']
            p = ns['P'][hid]
            self.offs = [tuple(o) for o in json.load(open(S_DIR + '/pips/offs.json'))[hid]]
            self.neck, self.tail = p['neck'], p['tail']
            self.head_w = lambda x, y: ns['head_w'](p, x, y)
            self.tail_w = lambda x, y: ns['tail_w'](p, x, y)
            self.px = None
            self.floats = False
            self.side = True
        elif fam == 'WNG':
            ns = RIGS['WNG']
            p = ns['P'].get(hid) or dict(neck=(518, 555), hx=(250, 725), xb=[(740, 740), (860, 720), (940, 680)], tail=(680, 930), ttop=730)
            self.neck, self.tail = p['neck'], p['tail']
            self.head_w = lambda x, y: ns['head_w'](p, x, y)
            self.tail_w = lambda x, y: ns['tail_w'](p, x, y)
            self.px = p['neck'][0] + 60
            self.floats = True
            self.side = True
        elif fam in NEW_FAMS:
            new_rig(self, hid)
        else:
            ns = RIGS['LET']
            p = ns['P'][hid]
            self.offs = [tuple(o) for o in json.load(open(S_DIR + '/lets/offs.json'))[hid]]
            self.neck, self.tail = (256, p['neck']), None
            self.head_w = lambda x, y: sm((p['neck'] + 15 - y) / 50)
            self.tail_w = lambda x, y: 0.0
            self.px = 256
            self.floats = bool(p.get('floats'))
            self.side = False
        self.fam = fam
        # frames: corner marks cleared, aligned, scaled
        ov_path = sheet.replace('_spritesheet.png', '_albino_eyes.png')
        try:
            ov = None if fam == 'MAN' or fam in NEW_FAMS else head_img(ov_path)      # (the new families have no albino eye overlay)
        except subprocess.CalledProcessError:
            ov = None
        real = 'assets/images/creatures/%s/%s_%s_albino_eyes.png' % ('rare' if hid in ('MAN15', 'MAN16', 'MAN17', 'MAN18') else 'uncommon', hid, mp['n'].replace('mane2', 'mane')) if fam == 'MAN' else ''
        self.real_ov = fam != 'MAN' and ov is not None
        if fam == 'MAN' and os.path.exists(real):
            ov, self.real_ov = Image.open(real).convert('RGBA'), True
        elif MANE_EYES.get(hid) and ov is None:               # no overlay yet: the eyes are marked by hand
            e1 = Image.new('L', (self.F0, self.F0), 0)
            for ex, ey, erx, ery in MANE_EYES[hid]:
                ImageDraw.Draw(e1).ellipse((ex - erx, ey - ery, ex + erx, ey + ery), fill=255)
            ov = Image.new('RGBA', (cols * self.F0, rows * self.F0))
            for i in range(n):
                ov.paste(Image.merge('RGBA', (e1, e1, e1, e1)), ((i % cols) * self.F0, (i // cols) * self.F0))
        self.frames, self.eyes, self.ovs = [], [], []
        self.raw, self._lit, self._bloom = [], {}, {}       # the frames at their drawn size, and what of them lights up
        self.layer = None
        self.log = []
        # drop the sheet's corner marks and any stray specks far from the body
        q = max(4, self.F0 // 75)
        boxes = [f.getchannel('A').reduce(q).point(lambda v: 255 if v > 100 else 0).getbbox() for f in raw]
        l, t, r, b = min(x[0] for x in boxes) * q, min(x[1] for x in boxes) * q, max(x[2] for x in boxes) * q, max(x[3] for x in boxes) * q
        pad = self.F0 // 8
        keep = Image.new('L', (self.F0, self.F0), 0)
        keep.paste(255, (max(0, l - pad), max(0, t - pad), min(self.F0, r + pad), min(self.F0, b + pad)))
        if fam != 'MAN':                                  # a Mane's glow reaches further than its body
            raw = [Image.composite(f, Image.new('RGBA', f.size), keep) for f in raw]
        for i, f in enumerate(raw):
            for cx in (0, self.F0 - 14):
                for cy in (0, self.F0 - 14):
                    f.paste((0, 0, 0, 0), (cx, cy, cx + 14, cy + 14))
            m = Image.new('RGBA', (self.F0, self.F0))
            m.paste(f, self.offs[i])
            self.raw.append(m)
            self.frames.append(m.resize((self.F, self.F), Image.LANCZOS))
            if ov is not None:
                E = ov.size[0] // cols
                ovf = ov.crop(((i % cols) * E, (i // cols) * E, (i % cols + 1) * E, (i // cols + 1) * E))
                e = ovf.getchannel('A').resize((self.F0, self.F0), Image.BILINEAR)
                em = Image.new('L', (self.F0, self.F0), 0)
                em.paste(e, self.offs[i])
                om = Image.new('RGBA', (self.F0, self.F0))
                om.paste(ovf.resize((self.F0, self.F0), Image.LANCZOS), self.offs[i])
                self.ovs.append(om.resize((self.F, self.F), Image.LANCZOS) if self.real_ov else None)
                em = ImageChops.multiply(em, f.getchannel('A').point(lambda v: 255 if v > 220 else 0)) if fam == 'MAN' else em
                self.eyes.append(em.resize((self.F, self.F), Image.BILINEAR).point(lambda v: 255 if v > 40 else 0))
            else:
                self.eyes.append(None)
                self.ovs.append(None)
        a0 = self.eyes[0].histogram()[255] if self.eyes and self.eyes[0] is not None else 0
        for i in range(len(self.eyes)):
            if self.eyes[i] is not None and a0 and self.eyes[i].histogram()[255] < 0.5 * a0:
                self.eyes[i] = self.eyes[0]
        bb = [v * 16 for v in self.frames[0].getchannel('A').reduce(16).point(lambda v: 255 if v > 100 else 0).getbbox()]
        self.bbox = bb                                   # render px
        self.py = solid(self.frames[0])[3] / self.k   # native
        if self.px is None:
            self.px = (bb[0] + bb[2]) / 2 / self.k
        self._painted = {}

    # ---- faces -------------------------------------------------------------------------
    def face(self, i, mode):
        if mode is None or self.eyes[i] is None or mode not in MANE_MODES.get(self.id, (mode,)):
            return self.frames[i]
        if (i, mode) not in self._painted:
            self._painted[i, mode] = paint_eyes(self.frames[i], self.eyes[i], mode, self.F, self.id in SOFT, MANE_INK.get(self.id), 4.0 if self.fam == 'MAN' else 0, COVER.get(self.id), FAR.get(self.id, 2.4), self.id)
        return self._painted[i, mode]

    def forward(self, pt, pose):
        """Where the source point [pt] (native px) is drawn under [pose]."""
        i, sx, sy, h, hd, hrot = pose
        X, Y = pt
        for _ in range(12):
            x = self.px + (X - self.px) / sx
            y = self.py + (Y + h - self.py) / sy
            w = self.head_w(x, y)
            if w > 0 and (hrot or hd[0] or hd[1]):
                rx, ry = rot(x, y, self.neck[0], self.neck[1], hrot)
                x -= w * (rx + hd[0])
                y -= w * (ry + hd[1])
            X, Y = X - (x - pt[0]), Y - (y - pt[1])
        return X, Y

    def track(self, poses, base_of):
        """The head's move in each posed frame, for costumes: (idle frame it is fitted from,
        dx, dy as fractions of the frame, turn in radians), about the point between the eyes."""
        e = self.eyes[0].getbbox() if self.eyes and self.eyes[0] is not None else None
        a = ((e[0] + e[2]) / 2 / self.k, (e[1] + e[3]) / 2 / self.k) if e else (self.neck[0] - 0.1 * self.F0, self.neck[1] - 0.12 * self.F0)
        b = (a[0], a[1] - 0.08 * self.F0)
        out = []
        for j, pz in enumerate(poses):
            A, B = self.forward(a, pz), self.forward(b, pz)
            turn = math.atan2(B[0] - A[0], -(B[1] - A[1]))
            out.append([base_of(j, pz[0]), round((A[0] - a[0]) / self.F0, 4), round((A[1] - a[1]) / self.F0, 4), round(turn, 4)])
        return out

    # ---- one posed frame ---------------------------------------------------------------
    def pose(self, i, mode, sx=1.0, sy=1.0, h=0.0, hd=(0.0, 0.0), hrot=0.0, trot=0.0, pad=0, src=None, extra=None):
        """h, hd in native px; rotations in degrees. [src] is drawn in place of frame i; [extra]
        says where each of its points is read from, after the body's own motion."""
        src = self.face(i, mode) if src is None else src
        if self.layer is None:
            self.log.append((i, sx, sy, h, hd, hrot))
        if self.layer == 'eyes':                         # the albino eye layer: only where the eyes are open as drawn
            src = self.ovs[i] if mode is None and self.ovs[i] is not None else Image.new('RGBA', src.size)
        k, F, C = self.k, self.F, 8
        g = {}
        for gy in range(0, F + pad + 1, C):
            for gx in range(0, F + 1, C):
                X, Y = gx / k, (gy - pad) / k
                x = self.px + (X - self.px) / sx
                y = self.py + (Y + h - self.py) / sy
                w = self.head_w(x, y)
                if w > 0 and (hrot or hd[0] or hd[1]):
                    rx, ry = rot(x, y, self.neck[0], self.neck[1], hrot)
                    x -= w * (rx + hd[0])
                    y -= w * (ry + hd[1])
                if trot and self.tail is not None:
                    w = self.tail_w(x, y)
                    if w > 0:
                        rx, ry = rot(x, y, self.tail[0], self.tail[1], trot)
                        x -= w * rx
                        y -= w * ry
                if extra is not None:
                    x, y = extra(x, y)
                g[gx, gy] = (x * k, y * k)
        mesh = [((x0, y0, x0 + C, y0 + C), g[x0, y0] + g[x0, y0 + C] + g[x0 + C, y0 + C] + g[x0 + C, y0])
                for y0 in range(0, F + pad, C) for x0 in range(0, F, C)]
        return src.convert('RGBa').transform((F, F + pad), Image.MESH, mesh, Image.BICUBIC).convert('RGBA')


# ---- painting eyes --------------------------------------------------------------------------
def grow(mask, px):
    px = int(px)
    return mask.filter(ImageFilter.MaxFilter(2 * px + 1)) if px > 0 else mask


SOFT = {'WNG04', 'WNG16', 'WNG17', 'PIP16'}   # small or glowing eyes: lines in the creature's own outline colour, lighter touch


COVER = {'MAN03': 'tight', 'PIP02': 'tight', 'LET11': 'tight', 'HOR03': 'far', 'HOR09': 'far', 'HOR11': 'wide', 'PIP03': 'wide', 'PIP08': 'wide'}


def deeper(c, v):
    """[c] in its own hue, richer and darker: the line a pale or glowing creature's shut eye is drawn with."""
    import colorsys
    h, s_, val = colorsys.rgb_to_hsv(c[0] / 255.0, c[1] / 255.0, c[2] / 255.0)
    r, g, b = colorsys.hsv_to_rgb(h, min(1.0, s_ * 1.6 + 0.15), val * v)
    return (int(r * 255), int(g * 255), int(b * 255), 255)


def skin_fill(crop, region, solid_a, skin, w2):
    """What goes over an eye: not one flat colour but the skin round it, drawn in from every side, so
    a face's own light and shade carry across where the eye was."""
    import numpy as np
    from scipy import ndimage as ndi
    arr = np.asarray(crop.convert('RGB'), dtype=np.float32)
    known = np.asarray(ImageChops.multiply(solid_a, ImageChops.invert(grow(region, 0.07 * w2 + 3))), dtype=np.float32) / 255.0
    # close to the eye, only what is skin: its rim, lashes and lids are not drawn in over it
    near = np.asarray(grow(region, 0.55 * w2 + 4), dtype=np.float32) / 255.0
    lum_a = arr @ np.array([0.3, 0.59, 0.11], np.float32)
    lum_s = 0.3 * skin[0] + 0.59 * skin[1] + 0.11 * skin[2]
    off = (lum_a < lum_s - 55) | (np.abs(arr - np.array(skin[:3], np.float32)).max(-1) > 95)
    known = known * (1 - near * off)
    # and nowhere what is plainly another part (a crest, a beak, a brow): only skin is drawn in
    known = known * (np.abs(arr - np.array(skin[:3], np.float32)).max(-1) < 60)
    fill = np.empty_like(arr)
    fill[...] = np.array(skin[:3], np.float32)
    for sig in (0.55 * w2, 0.28 * w2, 0.14 * w2):
        sig = max(1.5, sig)
        num = np.stack([ndi.gaussian_filter(arr[..., c] * known, sig) for c in range(3)], -1)
        den = ndi.gaussian_filter(known, sig)
        wgt = np.clip(den / 0.35, 0, 1)[..., None]
        fill = fill * (1 - wgt) + (num / np.maximum(den, 1e-4)[..., None]) * wgt
    out = Image.fromarray(np.clip(fill, 0, 255).astype(np.uint8), 'RGB').convert('RGBA')
    return out


FAR = {'HOR03': 1.45, 'HOR09': 2.4}       # how far past the iris the eye reaches, for 'far' covers


BIG_EYES = {'LET03'}        # a small iris marked in a much bigger dark eye: the skin is read from further out


def paint_eyes(img, mask, mode, F, soft=False, ink_as=None, min_sw=0, cover_as=None, far=2.4, self_id=None):
    bb = mask.getbbox()
    if bb is None:
        return img
    # split into eyes by empty columns
    cols = mask.crop((bb[0], bb[1], bb[2], bb[3])).resize((bb[2] - bb[0], 1), Image.BOX).tobytes()
    runs, start = [], None
    for x, v in enumerate(cols):
        if v and start is None:
            start = x
        if (not v or x == len(cols) - 1) and start is not None:
            runs.append([bb[0] + start, bb[0] + x + (1 if v else 0)])
            start = None
    merged = []
    for r in runs:
        if merged and r[0] - merged[-1][1] < 0.012 * F:
            merged[-1][1] = r[1]
        else:
            merged.append(r)
    if far <= 2 or cover_as != 'far':                  # (a slit of an iris is still an eye)
        merged = [r for r in merged if r[1] - r[0] >= 0.012 * F] or merged
    out = img.copy()
    face_cx = (merged[0][0] + merged[-1][1]) / 2
    alpha = img.getchannel('A')
    for (l, r) in merged:
        col = mask.crop((l, 0, r, F))
        t, b = col.getbbox()[1], col.getbbox()[3]
        w, h = r - l, b - t
        pad = int((2.6 if cover_as == 'far' and far > 2 else 1.9) * max(w, h) + 10)
        box = (max(0, l - pad), max(0, t - pad), min(F, r + pad), min(F, b + pad))
        cw, ch = box[2] - box[0], box[3] - box[1]
        m = Image.new('L', (cw, ch), 0)
        m.paste(mask.crop((max(box[0], l), box[1], min(box[2], r), box[3])), (max(box[0], l) - box[0], 0))
        crop = out.crop(box)
        a = alpha.crop(box).point(lambda v: 255 if v > 220 else 0)
        # the skin: what lies well clear of the eye
        ring = ImageChops.multiply(ImageChops.subtract(grow(m, 0.95 * w + 4), grow(m, 0.60 * w + 3)), a)
        if ring.getbbox() is None:
            continue
        rgb = crop.convert('RGB')
        skin = tuple(int(v) for v in ImageStat.Stat(rgb, ring).median) + (255,)
        inner = tuple(int(v) for v in ImageStat.Stat(rgb, ImageChops.multiply(m, a)).median) if ImageChops.multiply(m, a).getbbox() else skin
        if self_id in BIG_EYES and max(abs(skin[i] - inner[i]) for i in range(3)) < 40:
            # the ring fell inside a big eye (a small iris marked in it): the face is what lies further out, whichever colour is commonest
            wide = ImageChops.multiply(ImageChops.subtract(grow(m, 1.8 * w + 8), grow(m, 0.9 * w + 4)), a)
            cnt = {}
            for px, mv in zip(rgb.getdata(), wide.getdata()):
                if mv and max(abs(px[i] - inner[i]) for i in range(3)) >= 40:
                    cnt.setdefault((px[0] >> 3, px[1] >> 3, px[2] >> 3), []).append(px)
            if cnt:
                best = max(cnt.values(), key=len)
                skin = tuple(sorted(c[i] for c in best)[len(best) // 2] for i in range(3)) + (255,)
        if cover_as == 'tight':                           # the colour lying right beside the eye, whichever is commonest
            near = ImageChops.multiply(ImageChops.subtract(grow(m, 0.45 * w + 3), grow(m, 0.22 * w + 2)), a)
            cnt = {}
            for px, mv in zip(rgb.getdata(), near.getdata()):
                if mv:
                    key = (px[0] >> 3, px[1] >> 3, px[2] >> 3)
                    cnt.setdefault(key, []).append(px)
            if cnt:
                best = max(cnt.values(), key=len)
                skin = tuple(sorted(c[i] for c in best)[len(best) // 2] for i in range(3)) + (255,)
        # the whole eye: whatever joins the iris and is not skin (whites, lids, outline), within reach of it
        diff = ImageChops.difference(rgb, Image.new('RGB', rgb.size, skin[:3]))
        dr, dg, db = diff.split()
        notskin = ImageChops.lighter(ImageChops.lighter(dr, dg), db).point(lambda v: 255 if v > 34 else 0)
        reach = Image.new('L', (cw, ch), 0)
        ex, ey = l - box[0] + w / 2, t - box[1] + h / 2
        qx, qy = 0.5 * w + 0.5 * max(w, h) + 3, 0.5 * h + 0.5 * max(w, h) + 3
        if cover_as == 'far':                             # a small iris in a much bigger eye
            qx, qy = qx * far, qy * (1.5 if far > 2 else 1.2)
        ImageDraw.Draw(reach).ellipse((ex - qx, ey - qy, ex + qx, ey + qy), fill=255)
        field = ImageChops.multiply(ImageChops.lighter(notskin, m), reach)
        seedbox = m.getbbox()
        base_cover = grow(m, (0.5 * w + 5) if cover_as in ('wide', 'far') else (0.3 * w + 3) if cover_as == 'tight' else (0.18 * w + 3))
        region = base_cover
        if seedbox:
            fill = field.copy()
            for sx_ in (0.3, 0.5, 0.7):
                for sy_ in (0.35, 0.5, 0.65):
                    pt = (int(seedbox[0] + (seedbox[2] - seedbox[0]) * sx_), int(seedbox[1] + (seedbox[3] - seedbox[1]) * sy_))
                    if fill.getpixel(pt) == 255:
                        ImageDraw.floodfill(fill, pt, 128)
            joined = fill.point(lambda v: 255 if v == 128 else 0)
            area = lambda im: im.histogram()[255]
            if cover_as != 'tight' and area(joined) <= (90 if cover_as == 'far' else 14) * max(1, area(base_cover)):      # a leak along an outline is not an eye
                region = ImageChops.lighter(base_cover, grow(joined, 2))
        rb = region.getbbox()
        lx, ty, w2, h2 = rb[0], rb[1], rb[2] - rb[0], rb[3] - rb[1]
        # The line a shut eye is drawn with, in the creature's own hand: its eye's outline where that is
        # darker than its skin; on a dark creature, its eye's own light; on one whose eyes glow, a warm
        # line a little darker than its skin.
        eye_px = [px for px, mv in zip(rgb.getdata(), ImageChops.multiply(grow(region, 2), a).getdata()) if mv]
        lum = lambda c: 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]
        eye_px.sort(key=lum)
        dark = eye_px[len(eye_px) // 10] if eye_px else skin
        bright = eye_px[len(eye_px) * 9 // 10] if eye_px else skin
        if lum(skin) < 80:
            if lum(bright) > lum(skin) + 60:
                ink = tuple(bright[:3]) + (255,)
            else:
                ink = (min(255, skin[0] + 120), min(255, skin[1] + 120), min(255, skin[2] + 140), 255)
        elif lum(dark) < lum(skin) - 30:
            ink = tuple(dark[:3]) + (255,)
        else:
            ink = deeper(skin, 0.62)
        if abs(lum(ink) - lum(skin)) < 55:                # it has to read against the skin it is drawn on
            ink = deeper(skin, 0.5) if lum(skin) >= 80 else (min(255, skin[0] + 150), min(255, skin[1] + 150), min(255, skin[2] + 160), 255)
        if ink_as:
            ink = ink_as
        S = 3
        lay = Image.new('RGBA', (cw * S, ch * S), (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        unit = F / 600.0
        sw = max(min_sw, min(4.4 * unit, max(1.7 * unit, 0.07 * w2) if soft else max(2.3 * unit, 0.075 * w2))) * S
        if mode in ('happy', 'sleep'):
            cover = region.filter(ImageFilter.GaussianBlur(max(1.0, 0.03 * w2)))
            cx, cy = lx + w2 / 2, ty + h2 / 2
            if mode == 'happy':
                rx, ry = 0.42 * w2, max(0.24 * h2, 0.18 * w2)
                if soft:
                    rx, ry = 0.50 * w2, 0.20 * w2
                d.arc(((cx - rx) * S, (cy - ry * 0.4) * S, (cx + rx) * S, (cy + ry * 1.9) * S), 200, 340, fill=ink, width=int(sw))
            else:
                rx, ry = 0.40 * w2, max(0.22 * h2, 0.16 * w2)
                d.arc(((cx - rx) * S, (cy - ry * 1.5) * S, (cx + rx) * S, (cy + ry * 0.9) * S), 22, 158, fill=ink, width=int(sw))
        else:                                               # aiming: a lid over the top of the eye, dipping toward the middle
            inner_right = (l + r) / 2 < face_cx if len(merged) > 1 else False
            ya, yb = (0.30, 0.52) if inner_right else (0.52, 0.30)
            if soft:
                ya, yb = (0.22, 0.42) if inner_right else (0.42, 0.22)   # lid height at the eye's left and right ends
            x0, x1 = lx - 0.06 * w2, lx + 1.06 * w2
            y0, y1 = ty + ya * h2, ty + yb * h2
            lid = Image.new('L', (cw * S, ch * S), 0)
            ImageDraw.Draw(lid).polygon([(x0 * S, y0 * S), (x1 * S, y1 * S), (x1 * S, 0), (x0 * S, 0)], fill=255)
            lid = lid.resize((cw, ch), Image.LANCZOS)
            cover = ImageChops.multiply(region, lid).filter(ImageFilter.GaussianBlur(max(0.8, 0.02 * w2)))
            d.line((x0 * S, y0 * S, x1 * S, y1 * S), fill=ink, width=int(sw * 1.15))
        cover = ImageChops.multiply(cover, alpha.crop(box))
        crop = Image.composite(skin_fill(crop, region, a, skin, w2), crop, cover)
        lay = lay.resize((cw, ch), Image.LANCZOS)
        # lines stay on the creature; a lid line stays on its eye
        clip = alpha.crop(box) if mode != 'aim' else ImageChops.multiply(alpha.crop(box), grow(region, max(2, 0.05 * w2)).filter(ImageFilter.GaussianBlur(1)))
        lay.putalpha(ImageChops.multiply(lay.getchannel('A'), clip))
        crop.alpha_composite(lay)
        out.paste(crop, box[:2])
    return out


# ---- the three animations -----------------------------------------------------------------
HOP = dict(
    sy=[1.00, 0.95, 0.86, 1.06, 1.04, 1.00, 1.00, 1.03, 0.93, 0.84, 1.05, 0.96, 1.02, 0.99, 1.00, 1.00],
    sx=[1.00, 1.03, 1.09, 0.95, 0.97, 1.00, 1.00, 0.98, 1.05, 1.11, 0.96, 1.03, 0.99, 1.01, 1.00, 1.00],
    h=[0, 0, 0, 6, 16, 22, 22, 14, 0, 0, 0, 0, 0, 0, 0, 0],                       # share of 512
    hdy=[0, -1, -2, 4, 2, -2, -3, -3, 4, 6, -4, 2, -1, 1, 0, 0],                  # the head trails the body
    trot=[0, 2, 4, -8, -6, 0, 3, 6, 10, 12, -6, 3, -2, 1, 0, 0],
    eyes=[None] * 4 + ['happy'] * 7 + [None] * 5,
    dur=[420] + [70] * 14 + [280])
FIRE = dict(
    sy=[1.00, 0.93, 0.86, 0.85, 1.08, 1.03, 0.94, 1.02, 0.99, 1.00],
    sx=[1.00, 1.05, 1.10, 1.11, 0.94, 0.98, 1.04, 0.99, 1.01, 1.00],
    hdx=[0, 10, 18, 20, -34, -22, 6, -4, 0, 0],                                    # of 1200: rear back, then snap forward
    hrot=[0, 3, 5, 6, -7, -4, 2, -1, 0, 0],
    trot=[0, -3, -6, -7, 10, 6, -3, 2, 0, 0],
    eyes=[None] + ['aim'] * 5 + [None] * 4,
    dur=[260, 60, 60, 110, 50, 60, 60, 60, 70, 200])
NS = 16


# Where each Let's mouth is while it sleeps (512 px frame).
LET_MOUTH = {'LET01': (185, 283), 'LET02': (203, 288), 'LET03': (188, 312), 'LET04': (179, 287), 'LET05': (200, 317), 'LET06': (230, 309),
             'LET07': (214, 330), 'LET08': (228, 263), 'LET09': (190, 300), 'LET10': (190, 293), 'LET11': (220, 275), 'LET12': (190, 297),
             'LET13': (200, 254), 'LET14': (215, 310), 'LET16': (215, 292), 'LET17': (205, 305)}


def sleep_bubble(img, mouth, k, b, scale):
    S2 = 4
    r = (8 + 16 * (0.5 + 0.5 * math.sin(2 * math.pi * k / NS - 1.1))) * scale
    mx, my = mouth[0] * scale, (mouth[1] - 1.5 * b) * scale
    cx, cy = mx - r * 0.72, my + r * 0.62
    lay = Image.new('RGBA', (img.size[0] * S2, img.size[1] * S2), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    d.ellipse(((cx - r) * S2, (cy - r) * S2, (cx + r) * S2, (cy + r) * S2), fill=(222, 240, 255, 105), outline=(240, 248, 255, 230), width=int(max(2, 1.8 * scale) * S2))
    d.ellipse(((cx - r * 0.55) * S2, (cy - r * 0.6) * S2, (cx - r * 0.12) * S2, (cy - r * 0.17) * S2), fill=(255, 255, 255, 235))
    out = img.copy()
    out.alpha_composite(lay.resize(img.size, Image.LANCZOS))
    return out


def fit_under(img, pad, yc, F, m=6, force=None):
    """A frame drawn with headroom, brought back into its cell: what rises past the top is
    pressed down above yc (the mane gives; the face and body are left alone)."""
    if force is None:
        top = solid(img)[1] - pad
        if top >= m:
            return img.crop((0, pad, F, F + pad)), 1.0
        s = (yc - top) / float(yc - m)
    elif force == 1.0:
        return img.crop((0, pad, F, F + pad)), 1.0
    else:
        s = force
    mesh = [((0, 0, F, yc), (0, pad + yc - yc * s, 0, pad + yc, F, pad + yc, F, pad + yc - yc * s)),
            ((0, yc, F, F), (0, pad + yc, 0, pad + F, F, pad + F, F, pad + yc))]
    return img.convert('RGBa').transform((F, F), Image.MESH, mesh, Image.BICUBIC).convert('RGBA'), s


def build(rig, name, fixed=None):
    """Returns the frames. Motion that would leave the cell is shrunk: the upward part
    (lift, stretch) and the sideways part (widening, the head's thrust) separately, so a
    creature with no headroom still crouches and squashes in full."""
    if rig.fam in NEW_FAMS:
        return build_attack(rig, fixed)
    n = len(rig.frames)
    up = wide = 1.0
    f512, f1200 = rig.F0 / 512, rig.F0 / 1200
    air = 0.4 if rig.floats else 1.0                 # a flyer has no ground to push off

    def ss(sx, sy):
        if sy > 1:
            return 1 + (sx - 1) * up * air, 1 + (sy - 1) * up * air
        return 1 + (sx - 1) * wide * air, 1 + (sy - 1) * air
    rig.log = []
    if name == 'hop' and rig.fam == 'MAN':           # a Mane with no headroom still hops: its mane gives a little at the top
        A = HOP
        for up in ((fixed[0],) if fixed else (1.0, 0.8, 0.6)):
            out, worst = [], 1.0
            if not fixed:
                rig._fits = [None] * 16
            for k in range(16):
                sx, sy = ss(A['sx'][k], A['sy'][k])
                lag = A['hdy'][k] * f512 * 0.7
                lift = A['h'][k] * f512 * up
                f = rig.pose(k % n, A['eyes'][k], sx, sy, lift, (0, lag * (up if lag < 0 else 1)), 0, A['trot'][k] * 0.35, pad=120)
                f, sq = fit_under(f, 120, int((rig.neck[1] - 200 - lift) * rig.k), rig.F, force=rig._fits[k] if fixed else None)
                rig._fits[k] = sq
                worst = max(worst, sq)
                out.append(f)
            if fixed or worst <= 1.09:
                break
        if rig.layer is None:
            rig.poses = rig.log[-16:]
        return out, (up, 1.0)
    if fixed:
        up, wide = fixed
    for attempt in range(1 if fixed else 8):
        out = []
        if name == 'hop':
            A = HOP
            for k in range(16):
                sx, sy = ss(A['sx'][k], A['sy'][k])
                lag = A['hdy'][k] * f512 * 0.7
                out.append(rig.pose(k % n, A['eyes'][k], sx, sy, A['h'][k] * f512 * up * (2.0 if rig.floats and rig.fam == 'WNG' else 1.0), (0, lag * (up if lag < 0 else 1)), 0, A['trot'][k] * 0.35))
        elif name == 'fire':
            A = FIRE
            side = 1.0 if rig.side else 0.0
            for k in range(10):
                sx, sy = ss(A['sx'][k], A['sy'][k])
                out.append(rig.pose(k % n, A['eyes'][k], sx, sy, 0, (A['hdx'][k] * f1200 * side * wide, 0),
                                    A['hrot'][k] * side * (up if A['hrot'][k] > 0 else 1), A['trot'][k] * 0.4))
        else:
            for k in range(NS):
                b = math.sin(2 * math.pi * k / NS)
                i = 0 if rig.fam == 'WNG' else (k // 2) % n     # wings rest; other drawn frames tick over slowly
                droop = (-5.0, 0.012 * rig.F0) if rig.side else (0.0, 0.010 * rig.F0)
                f = rig.pose(i, 'sleep', 1 + (0.035 - 0.012 * b) * wide, 0.945 + 0.028 * b, 0,
                             (0, droop[1] + 1.5 * f1200 * b), droop[0] + 0.6 * b, 3.0 + 1.2 * b)
                if rig.id in LET_MOUTH and rig.layer is None:      # a sleep bubble at its mouth, swelling and sinking with its breath
                    f = sleep_bubble(f, LET_MOUTH[rig.id], k, b, rig.k)
                out.append(f)
        top = side_hit = False
        for f in out:
            bb = solid(f)
            if bb is None:                                # an empty eye-layer frame
                continue
            top |= bb[1] <= 0
            side_hit |= bb[0] <= 0 or bb[2] >= rig.F
        if not top and not side_hit:
            break
        if top:
            up = 0.0 if up < 0.15 else up * 0.6
        if side_hit:
            wide = 0.0 if wide < 0.15 else wide * 0.6
    if rig.layer is None:
        rig.poses = rig.log[-len(out):]
    return out, (up, wide)


def rig_check(rig):
    """Frame 0 with its rig marked on it (the head's reach red, the tail's blue, its eyes ringed, the
    neck a dot) beside what of it lights up."""
    F0 = rig.F0
    im = Image.new('RGBA', (2 * F0, F0), BG)
    base = Image.new('RGBA', (F0, F0), BG)
    base.alpha_composite(rig.raw[0])
    q = 4
    hw = Image.new('L', (F0 // q, F0 // q))
    tw = Image.new('L', (F0 // q, F0 // q))
    hw.putdata([int(150 * rig.head_w(x * q, y * q)) for y in range(F0 // q) for x in range(F0 // q)])
    tw.putdata([int(150 * rig.tail_w(x * q, y * q)) for y in range(F0 // q) for x in range(F0 // q)])
    base = Image.composite(Image.new('RGBA', (F0, F0), (255, 40, 40, 255)), base, hw.resize((F0, F0), Image.BILINEAR))
    base = Image.composite(Image.new('RGBA', (F0, F0), (60, 90, 255, 255)), base, tw.resize((F0, F0), Image.BILINEAR))
    d = ImageDraw.Draw(base)
    for e in rig.p.get('eyes', []):
        d.ellipse((e[0] - e[2], e[1] - e[3], e[0] + e[2], e[1] + e[3]), outline=(255, 255, 255, 255))
    nx, ny = rig.neck
    d.ellipse((nx - 5, ny - 5, nx + 5, ny + 5), fill=(255, 255, 0, 255))
    if rig.tail:
        d.ellipse((rig.tail[0] - 5, rig.tail[1] - 5, rig.tail[0] + 5, rig.tail[1] + 5), fill=(0, 255, 255, 255))
    for f in rig.fl:
        if f[0] == 'up':
            d.line((0, f[2], F0, f[2]), fill=(0, 255, 0, 255))
        else:
            for sgn in (-1, 1):
                a = math.radians(f[4] + sgn * f[5])
                d.line((f[1] + f[3] * math.cos(a), f[2] + f[3] * math.sin(a), f[1] + 260 * math.cos(a), f[2] + 260 * math.sin(a)), fill=(0, 255, 0, 255))
            d.ellipse((f[1] - f[3], f[2] - f[3], f[1] + f[3], f[2] + f[3]), outline=(0, 255, 0, 255))
    if rig.p.get('puffs'):
        x, y, dirs = rig.p['puffs']
        for ang, r in dirs:
            d.line((x, y, x + 200 * math.cos(math.radians(ang)), y + 200 * math.sin(math.radians(ang))), fill=(0, 255, 255, 255))
    for gx, gy in rig.p.get('glint', []):
        d.line((gx - 6, gy, gx + 6, gy), fill=(255, 255, 255, 255))
        d.line((gx, gy - 6, gx, gy + 6), fill=(255, 255, 255, 255))
    im.paste(base, (0, 0))
    lit = Image.new('RGBA', (F0, F0), BG)
    lit.alpha_composite(lit_frame(rig, 0, 1.0, 1.0))
    im.paste(lit, (F0, 0))
    return im.convert('RGB')


def durations(name):
    return HOP['dur'] if name == 'hop' else FIRE['dur'] if name == 'fire' else [150] * NS


RIGS = {}
if FAM == 'HOR':
    RIGS['HOR'] = load('horns_build.py', "ids = ONLY or sorted(P)", [REPO, S_DIR + '/horns', 'none'])
elif FAM == 'WNG':
    RIGS['WNG'] = load('wings_build.py', "if MODE in ('overlay', 'build'):", [REPO, S_DIR + '/wings', 'none'])
elif FAM == 'PIP':
    RIGS['PIP'] = load('pips_build.py', "if MODE in ('overlay', 'build'):", [REPO, S_DIR + '/pips', 'none'])
elif FAM in NEW_FAMS:
    pass                                                   # their rigs are in this file
elif FAM == 'MAN':
    _src = open(S_DIR + '/manes_build.py').read()
    RIGS['MAN'] = dict(S=S_DIR, math=math)
    exec(_src[_src.index("src = open"):_src.index('BG = ')].replace("O = S + '/manes'", ''), RIGS['MAN'])
else:
    RIGS['LET'] = load('lets_build.py', "for h in (ONLY or sorted(P)):", [REPO, S_DIR + '/lets'])

ids = [i for i in sorted(CREATURES) if i.startswith(FAM) and i != 'LET15']
if FAM == 'MAN':
    ids = sorted(RIGS['MAN']['P'])
only = os.environ.get('ONLY')
if only:
    ids = only.split(',')
font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 18)
CELLPX, COLS = 260, 6
anims = {'fire': {}} if FAM in NEW_FAMS else {'hop': {}, 'fire': {}, 'sleep': {}}     # the new families: an attack only
TRACKS = {}
for hid in ids:
    rig = Rig(hid)
    notes = []
    for name in anims:
        frames, scale = build(rig, name)
        n_idle = len(rig.frames)
        if rig.fam == 'MAN':                              # fitted from the idle frame it was posed from
            base_of = lambda j, i: i
        elif rig.fam == 'WNG':                            # the 8-frame idle's first four are the drawn four
            base_of = lambda j, i: i % 4
        else:                                             # posed from frames steadied onto frame 0
            base_of = lambda j, i: 0
        if rig.fam not in NEW_FAMS:                       # (no costume is fitted to the new families)
            tr = rig.track(rig.poses, base_of)
            TRACKS.setdefault(hid, {})[name] = tr[::2] if name == 'sleep' else tr
        if scale != (1.0, 1.0):
            notes.append('%s up x%.2f wide x%.2f' % ((name,) + scale))
        cells = []
        for f in frames:
            c = Image.new('RGBA', f.size, BG)
            c.alpha_composite(f)
            cells.append(c.resize((CELLPX, CELLPX), Image.LANCZOS).convert('RGB'))
        anims[name][hid] = (rig.name, cells)
        if rig.fam in NEW_FAMS and os.environ.get('RIG'):  # where its parts were placed, to check by
            rig_check(rig).save('%s/%s_rig.png' % (OUT, hid))
        if os.environ.get('KEEP'):
            sheet = Image.new('RGBA', (4 * rig.F, -(-len(frames) // 4) * rig.F))
            for k, f in enumerate(frames):
                sheet.paste(f, ((k % 4) * rig.F, (k // 4) * rig.F))
            sheet.save('%s/%s_%s_spritesheet.png' % (OUT, hid, name), optimize=True)
            ep = '%s/%s_%s_eyes.png' % (OUT, hid, name)
            if os.path.exists(ep):
                os.remove(ep)
            if name != 'sleep' and any(o is not None for o in rig.ovs):     # the albino's eye layer, through the same motion
                rig.layer = 'eyes'
                eyes, _ = build(rig, name, fixed=scale)
                rig.layer = None
                es = Image.new('RGBA', sheet.size)
                for k, f in enumerate(eyes):
                    es.paste(f, ((k % 4) * rig.F, (k // 4) * rig.F))
                if es.getbbox():
                    es.save(ep, optimize=True)
    print(hid, rig.name, '' if rig.fam in NEW_FAMS else 'eyes found' if rig.eyes[0] is not None and rig.eyes[0].getbbox() else 'NO EYES', '; '.join(notes), flush=True)

tag = FAM.lower() + ('_' + only.replace(',', '_') if only else '')
for name, per in anims.items():
    rows = -(-len(per) // COLS)
    nfr = len(next(iter(per.values()))[1])
    W, H = COLS * CELLPX, 40 + rows * (CELLPX + 26)
    sheet = []
    for k in range(nfr):
        s = Image.new('RGB', (W, H), BG[:3])
        d = ImageDraw.Draw(s)
        d.text((12, 10), '%s  ·  %s' % (FAM_TITLES[FAM], name.upper()), fill=(230, 210, 160), font=font)
        for j, (hid, (nm, cells)) in enumerate(per.items()):
            x, y = (j % COLS) * CELLPX, 40 + (j // COLS) * (CELLPX + 26)
            s.paste(cells[k], (x, y + 22))
            d.text((x + 8, y), nm.upper(), fill=(200, 170, 110), font=font)
        sheet.append(s)
    p = '%s/%s_%s.gif' % (OUT, tag, name)
    sheet[0].save(p, save_all=True, append_images=sheet[1:], duration=durations(name), loop=0, optimize=True)
    # a still to check by: the frame with the painted eyes
    sheet[{'hop': 9, 'fire': 3, 'sleep': 4}[name]].save('%s/%s_%s_check.png' % (OUT, tag, name))
    print(p, (W, H), os.path.getsize(p) // 1024, 'KB')
    if FAM in NEW_FAMS:                                   # every species, its ten frames in a row
        C2 = 192
        cs = Image.new('RGB', (110 + nfr * C2, len(per) * C2), BG[:3])
        d = ImageDraw.Draw(cs)
        for j, (hid, (nm, cells)) in enumerate(per.items()):
            for k in range(nfr):
                cs.paste(cells[k].resize((C2, C2), Image.LANCZOS), (110 + k * C2, j * C2))
            d.text((8, j * C2 + 76), hid, fill=(230, 210, 160), font=font)
            d.text((8, j * C2 + 100), nm[:11], fill=(200, 170, 110), font=font)
        cs.save('%s/%s_%s_contact.png' % (OUT, tag, name))

if os.environ.get('KEEP') and FAM not in NEW_FAMS:
    json.dump(TRACKS, open('%s/tracks_%s.json' % (OUT, tag), 'w'))
