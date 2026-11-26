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
CREATURES_NOW = {c['id']: c for c in json.load(open('assets/data/alchemons_creatures.json'))['creatures']}
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

MANE_INK = {
    # the Light ones: one warm amber-brown line, strong enough to read on a glowing body
    'HOR16': (150, 92, 24, 255), 'WNG16': (150, 92, 24, 255), 'PIP16': (150, 92, 24, 255), 'LET16': (150, 92, 24, 255), 'MAN16': (150, 92, 24, 255),
    'MAN15': (24, 22, 48, 255),   # Darkmane: its eyes' own near-black, as the lids of a dark almond eye
    'MAN06': (255, 135, 70, 255), 'MAN14': (40, 105, 122, 255), 'LET11': (84, 62, 150, 255)}
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
    # MYS01-09 are drawn anew (mystic_stills/): 1200 px, idles from mystics_build.py, and their attack is
    # mystics_build.py's `attack` now (a strike, not this gather and snap); these rows are kept to compare by
    'MYS01': dict(head=(510, 440, 100), neck=(505, 570), face=0, floats=True, squash=0.5, eyes=[(525, 420, 11, 20)], marks='lum',
                  fl=[(510, 380, 70, -90, 45, 0.18, 'flame')]),
    'MYS02': dict(head=(545, 420, 130), neck=(620, 620), face=-1, eyes=[(545, 442, 20, 13)], marks='lum', pct=95, amp=0.7),
    'MYS03': dict(head=(470, 680, 170), neck=(475, 830), face=0, eyes=[(385, 664, 14, 7), (560, 682, 24, 10)], amp=0.7),
    'MYS04': dict(head=(500, 450, 110), neck=(540, 580), face=0, eyes=[(455, 507, 9, 11), (507, 505, 10, 12)],
                  fl=[(540, 560, 200, -145, 40, 0.07, 'solid'), (540, 560, 200, -35, 40, 0.07, 'solid')]),
    'MYS05': dict(head=(390, 640, 150), neck=(560, 760), face=-1, eyes=[(215, 620, 9, 12), (418, 624, 16, 9)], marks='sv', amp=0.7,
                  fl=[(400, 570, 40, -95, 55, 0.12, 'flame')]),
    'MYS06': dict(head=(290, 570, 140), neck=(440, 700), face=-1, eyes=[(285, 605, 22, 25)], marks='sv', amp=0.7,
                  fl=[(760, 300, 40, -90, 60, 0.14, 'flame')]),
    'MYS07': dict(head=(250, 620, 150), neck=(420, 700), face=-1, eyes=[(175, 627, 8, 18), (295, 627, 18, 16)], marks='lum', amp=0.7,
                  fl=[(870, 450, 30, -45, 40, 0.10, 'bolt')]),
    'MYS08': dict(head=(450, 650, 150), neck=(610, 720), face=-1, eyes=[(435, 632, 12, 22)], amp=0.6),
    'MYS09': dict(head=(330, 260, 150), neck=(290, 470), face=-1, eyes=[(318, 273, 30, 10)], amp=0.6,
                  glint=[(555, 150), (885, 315), (780, 145), (720, 440), (450, 355)]),
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
MYS_TINT = {'MYS07': (150, 215, 255), 'MYS08': (255, 190, 90), 'MYS12': (255, 228, 90), 'MYS03': (255, 215, 120)}
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
        self.hip = self.foot = None                     # (Horns and Manes: where the legs start and stand)
        c = CREATURES.get(hid)
        if hid[:3] in NEW_FAMS:                          # (as they are now: some Mystics are drawn anew)
            c = CREATURES_NOW[hid]
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
            rows = sd.get('rows', 1)
            n = a.size[0] // self.F0 * rows
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
            self.hip, self.foot = p['hip'], p['foot']
            self.side = True
        elif fam == 'PIP':
            ns = RIGS['PIP']
            p = ns['P'][hid]
            self.offs = [tuple(o) for o in json.load(open(S_DIR + '/pips/offs.json'))[hid]]
            self.neck, self.tail = p['neck'], p['tail']
            self.hip, self.foot = p['hip'], p['foot']
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

    def track(self, poses, base_of, fields=None):
        """The head's move in each posed frame, for costumes: (idle frame it is fitted from,
        dx, dy as fractions of the frame, turn in radians), about the point between the eyes.
        [fields]: each frame's `extra` where it moves the head too (a shimmy)."""
        e = self.eyes[0].getbbox() if self.eyes and self.eyes[0] is not None else None
        a = ((e[0] + e[2]) / 2 / self.k, (e[1] + e[3]) / 2 / self.k) if e else (self.neck[0] - 0.1 * self.F0, self.neck[1] - 0.12 * self.F0)
        b = (a[0], a[1] - 0.08 * self.F0)
        out = []
        def unextra(g, pt):                              # the point g reads [pt] from, undone
            q = pt
            for _ in range(30):
                gx, gy = g(*q)
                q = (q[0] + pt[0] - gx, q[1] + pt[1] - gy)
            return q
        for j, pz in enumerate(poses):
            a2, b2 = (unextra(fields[j], a), unextra(fields[j], b)) if fields else (a, b)
            A, B = self.forward(a2, pz), self.forward(b2, pz)
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


SOFT = {'WNG04', 'WNG17'}   # small or glowing eyes: lines in the creature's own outline colour, lighter touch


# the far eye is a sliver at the edge of the face: it shuts too
SLIVER_EYES = {'WNG16'}
# a shut eye's line turned to lie along a slanted eye (degrees, anticlockwise)
ARC_TILT = {'WNG16': 20}
# a shut eye's line drawn smaller than the eye it replaces
ARC_SCALE = {'WNG16': 0.6, 'MAN15': 0.7}
COVER = {'WNG16': 'tight', 'MAN03': 'tight', 'MAN15': 'tight', 'PIP02': 'tight', 'LET11': 'tight', 'HOR03': 'far', 'HOR09': 'far', 'HOR11': 'wide', 'PIP03': 'wide', 'PIP08': 'wide'}


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
    if (far <= 2 or cover_as != 'far') and self_id not in SLIVER_EYES:      # (a slit of an iris is still an eye)
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
        sw = (0.8 if self_id in ARC_SCALE else 1.0) * max(min_sw, min(4.4 * unit, max(1.7 * unit, 0.07 * w2) if soft else max(2.3 * unit, 0.075 * w2))) * S
        if mode in ('happy', 'sleep'):
            cover = region.filter(ImageFilter.GaussianBlur(max(1.0, 0.03 * w2)))
            cx, cy = lx + w2 / 2, ty + h2 / 2
            if mode == 'happy':
                rx, ry = 0.42 * w2, max(0.24 * h2, 0.18 * w2)
                if soft:
                    rx, ry = 0.50 * w2, 0.20 * w2
                rx, ry = rx * ARC_SCALE.get(self_id, 1.0), ry * ARC_SCALE.get(self_id, 1.0)
                d.arc(((cx - rx) * S, (cy - ry * 0.4) * S, (cx + rx) * S, (cy + ry * 1.9) * S), 200, 340, fill=ink, width=int(sw))
            else:
                rx, ry = 0.40 * w2, max(0.22 * h2, 0.16 * w2)
                rx, ry = rx * ARC_SCALE.get(self_id, 1.0), ry * ARC_SCALE.get(self_id, 1.0)
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
        if mode != 'aim' and ARC_TILT.get(self_id):
            lay = lay.rotate(ARC_TILT[self_id], Image.BICUBIC, center=((lx + w2 / 2) * S, (ty + h2 / 2) * S))
        lay = lay.resize((cw, ch), Image.LANCZOS)
        # lines stay on the creature; a lid line stays on its eye
        clip = alpha.crop(box) if mode != 'aim' else ImageChops.multiply(alpha.crop(box), grow(region, max(2, 0.05 * w2)).filter(ImageFilter.GaussianBlur(1)))
        lay.putalpha(ImageChops.multiply(lay.getchannel('A'), clip))
        crop.alpha_composite(lay)
        if self_id in SLIVER_EYES and mode != 'aim':       # the far eye's white, at the face's edge: skin, with the eye shut
            wh = crop.convert('RGB').point(lambda v: 255 if v > 236 else 0).split()
            white = ImageChops.multiply(ImageChops.multiply(wh[0], wh[1]), wh[2])
            side = Image.new('L', crop.size, 0)
            side.paste(255, (0, 0, max(0, int(lx - 0.15 * w2)), ch))
            white = grow(ImageChops.multiply(ImageChops.multiply(white, side), a), 1).filter(ImageFilter.GaussianBlur(0.8))
            crop = Image.composite(Image.new('RGBA', crop.size, skin), crop, ImageChops.multiply(white, alpha.crop(box)))
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


# ---- the wag: a happy little wiggle of the tail and hips ----------------------------------------
# The tail whips about its root (the tip a beat behind, a crystal or stone on it turned whole), the
# hips sway with it, the feet stay planted and the head stays still. Two wags and a settle, eyes shut
# happy. One with no tail to wag shimmies instead: its body sways from side to side over its feet.
# Per species (native px): root = where the tail turns about; poly = the tail and its glow as drawn
# (nothing outside it is turned); bend = over what distance from the root the tail bends (past it,
# what is on the tip turns whole); amp = how far it swings (1 = 9 degrees at the root, 20 at the tip);
# low = below this the legs stand still (the rig's hip by default); still = how far from the root the
# tail holds where it is (where it meets the body over a long seam, so the seam never kinks); halo =
# how far past its outline its glow is taken along; grow, tuck, seam: how far the outline is grown,
# the root's reach under the body, the band the seam is filled over (within seamr of the root). A Wing
# whose flapping wing sweeps over its tail in some drawn frames: frames = the drawn frames its wag cycles
# through (the others left out); polys = {drawn frame: outline} where the outline must differ.
WAG_RIGS = {
    # the Horns (their drawn frames, steadied as for the hop)
    'HOR01': dict(root=(880, 805), bend=(0, 150), amp=0.8, grow=3, poly=[(815, 600), (822, 520), (842, 460), (862, 400), (935, 400), (995, 510), (1000, 650), (990, 760), (960, 830), (905, 850), (870, 845), (846, 822), (840, 762), (843, 715), (838, 668), (818, 645)]),
    'HOR02': dict(root=(815, 865), bend=(0, 120), amp=0.7, poly=[(800, 835), (828, 800), (830, 720), (828, 640), (848, 610), (880, 612), (912, 680), (958, 678), (1000, 612), (1060, 615), (1062, 700), (1040, 780), (990, 812), (932, 852), (872, 902), (832, 918)]),
    'HOR03': dict(mode='shimmy'),                     # its tail is a stub along a long seam (turned, it tears): it shimmies
    'HOR04': dict(root=(690, 890), bend=(0, 260), amp=0.32, grow=3, poly=[(682, 960), (678, 880), (682, 828), (702, 768), (742, 662), (768, 600), (788, 520), (800, 430), (815, 380), (880, 362), (995, 368), (1085, 445), (1092, 585), (1020, 668), (1000, 748), (970, 830), (905, 890), (835, 942), (765, 978), (700, 975)]),
    'HOR05': dict(root=(825, 870), bend=(0, 150), amp=0.8, poly=[(800, 902), (810, 842), (858, 802), (878, 742), (864, 682), (890, 640), (928, 556), (978, 556), (1002, 652), (997, 762), (972, 832), (932, 882), (872, 932), (822, 947)]),
    'HOR06': dict(root=(865, 850), bend=(0, 80), poly=[(845, 782), (872, 750), (950, 700), (1015, 630), (1050, 655), (1042, 722), (995, 795), (935, 875), (884, 930), (855, 937), (846, 882)]),
    'HOR07': dict(root=(905, 765), bend=(0, 150), amp=0.7, still=30, poly=[(852, 722), (858, 680), (865, 640), (875, 560), (893, 478), (955, 468), (966, 560), (985, 640), (1003, 722), (985, 762), (958, 795), (925, 812), (905, 790), (900, 735), (880, 726)]),
    'HOR08': dict(root=(800, 865), bend=(0, 60), amp=1.2, grow=3, poly=[(780, 822), (790, 815), (812, 790), (845, 770), (875, 750), (905, 740), (940, 752), (948, 822), (910, 878), (858, 928), (802, 942), (778, 902)]),
    'HOR09': dict(root=(870, 880), bend=(0, 150), amp=0.8, poly=[(822, 880), (822, 800), (830, 750), (855, 690), (858, 640), (858, 590), (895, 558), (965, 558), (972, 640), (958, 720), (962, 800), (938, 872), (902, 912), (860, 932), (830, 920)]),
    'HOR10': dict(root=(855, 835), bend=(0, 120), poly=[(822, 842), (834, 762), (838, 700), (860, 640), (870, 588), (935, 585), (960, 680), (995, 780), (975, 862), (930, 890), (885, 892), (847, 885)]),
    'HOR11': dict(root=(795, 880), bend=(0, 90), poly=[(772, 902), (782, 852), (822, 822), (830, 760), (848, 680), (880, 600), (960, 575), (1035, 578), (1000, 680), (990, 762), (965, 840), (912, 892), (856, 940), (802, 958)]),
    'HOR12': dict(root=(785, 935), bend=(0, 120), poly=[(762, 962), (768, 900), (800, 862), (860, 812), (900, 765), (922, 725), (952, 712), (972, 760), (970, 850), (938, 915), (885, 965), (828, 1005), (782, 1012)]),
    'HOR13': dict(root=(860, 880), bend=(0, 150), amp=0.8, grow=2, poly=[(850, 902), (852, 800), (866, 742), (880, 712), (880, 600), (884, 530), (905, 505), (980, 510), (992, 640), (972, 722), (942, 802), (905, 875), (872, 925)]),
    'HOR14': dict(root=(754, 920), bend=(0, 120), still=60, hips=0.4, poly=[(740, 1010), (742, 900), (770, 810), (812, 752), (880, 728), (928, 726), (970, 746), (988, 800), (978, 862), (930, 885), (880, 905), (830, 955), (790, 1008)]),
    'HOR15': dict(root=(860, 870), bend=(0, 160), amp=0.8, poly=[(820, 882), (822, 800), (815, 720), (815, 640), (830, 560), (860, 498), (925, 505), (958, 610), (975, 722), (948, 812), (910, 872), (872, 905)]),
    'HOR16': dict(root=(762, 965), bend=(0, 110), poly=[(750, 1000), (750, 935), (800, 912), (860, 895), (900, 868), (922, 818), (935, 762), (1000, 772), (1000, 862), (968, 945), (912, 992), (850, 1022), (800, 1028), (772, 1020)]),
    'HOR17': dict(root=(845, 880), bend=(0, 150), amp=0.8, grow=2, poly=[(828, 640), (840, 600), (868, 568), (905, 560), (945, 610), (985, 690), (995, 790), (965, 870), (905, 918), (862, 930), (838, 905), (830, 840), (826, 780), (826, 700)]),
    # the Pips (their drawn frames steadied as for the hop; some move their tails a lot between them)
    'PIP01': dict(root=(940, 740), bend=(0, 200), amp=0.7, grow=4, poly=[(912, 760), (912, 650), (905, 600), (898, 562), (860, 548), (822, 520), (812, 450), (815, 360), (850, 280), (895, 228), (1000, 225), (1035, 300), (1050, 400), (1056, 500), (1050, 572), (1005, 592), (1000, 650), (995, 720), (990, 790), (950, 805)]),
    'PIP02': dict(root=(900, 720), bend=(0, 200), amp=0.6, poly=[(840, 700), (845, 610), (862, 520), (890, 430), (930, 395), (980, 400), (1000, 470), (1012, 560), (1060, 600), (1110, 640), (1100, 690), (1040, 740), (980, 780), (910, 790), (860, 760)]),
    'PIP03': dict(mode='shimmy'),                     # its tail is a stub along a long seam: it shimmies
    'PIP04': dict(mode='shimmy'),                     # its tail tuft is one cloud with the clouds on its back: it shimmies
    'PIP05': dict(mode='shimmy'),                     # its tail is a flat stub under the vents: it shimmies
    'PIP06': dict(root=(885, 730), bend=(0, 100), still=40, grow=4, poly=[(880, 800), (865, 760), (858, 700), (858, 660), (880, 615), (905, 575), (932, 525), (952, 532), (968, 620), (965, 690), (945, 735), (912, 795)]),
    'PIP07': dict(root=(885, 735), bend=(0, 250), amp=0.6, grow=4, poly=[(882, 780), (852, 705), (838, 650), (866, 632), (925, 590), (878, 560), (870, 540), (910, 450), (950, 345), (980, 328), (990, 420), (990, 492), (1043, 545), (1040, 612), (995, 672), (935, 742), (905, 792)]),
    'PIP08': dict(mode='shimmy'),                     # its tail is a lump of bubbles along a long seam: it shimmies
    'PIP09': dict(root=(900, 740), bend=(0, 220), amp=0.6, poly=[(860, 760), (855, 680), (820, 600), (800, 500), (790, 400), (800, 320), (870, 320), (930, 400), (990, 470), (1000, 560), (985, 640), (960, 720), (920, 780)]),
    'PIP10': dict(mode='shimmy'),
    'PIP11': dict(root=(900, 740), bend=(0, 200), still=30, amp=0.7, grow=4, poly=[(885, 808), (858, 760), (836, 700), (822, 650), (840, 618), (838, 600), (818, 560), (818, 470), (860, 415), (930, 382), (988, 402), (1048, 470), (1043, 560), (1008, 622), (984, 652), (980, 720), (962, 786), (920, 812)]),
    'PIP12': dict(root=(905, 740), bend=(0, 250), amp=0.6, grow=4, poly=[(888, 760), (882, 700), (878, 650), (850, 632), (805, 626), (785, 605), (780, 520), (795, 490), (800, 420), (798, 335), (830, 328), (890, 345), (905, 310), (925, 300), (935, 330), (965, 345), (1050, 335), (1070, 380), (1068, 470), (1040, 520), (1050, 580), (1110, 620), (1130, 690), (1118, 740), (1085, 752), (1000, 758), (950, 780), (910, 790)]),
    'PIP13': dict(root=(905, 720), bend=(0, 220), amp=0.5, grow=4, seamr=190, poly=[(905, 760), (878, 700), (868, 640), (860, 605), (832, 585), (818, 520), (805, 430), (770, 300), (830, 280), (890, 285), (940, 370), (1000, 380), (1080, 350), (1150, 350), (1200, 420), (1200, 600), (1100, 640), (1030, 660), (1000, 720), (985, 780), (940, 810)]),
    'PIP14': dict(root=(900, 760), bend=(0, 150), still=40, hips=0.6, poly=[(853, 805), (845, 700), (840, 640), (842, 600), (858, 530), (890, 488), (950, 466), (1010, 460), (1062, 486), (1070, 600), (1025, 700), (965, 812)]),
    'PIP15': dict(root=(925, 730), bend=(0, 150), grow=3, poly=[(898, 795), (885, 760), (880, 700), (875, 645), (895, 610), (922, 555), (942, 508), (963, 510), (980, 590), (982, 670), (965, 732), (932, 782), (912, 800)]),
    'PIP16': dict(root=(960, 690), bend=(0, 200), amp=0.7, grow=3, poly=[(945, 757), (912, 700), (898, 640), (896, 590), (896, 470), (905, 428), (950, 392), (1000, 372), (1052, 375), (1058, 402), (1018, 440), (1004, 480), (1050, 540), (1062, 605), (1050, 662), (1018, 712), (976, 746), (958, 760)]),
    'PIP17': dict(root=(920, 780), bend=(0, 200), amp=0.7, poly=[(870, 790), (866, 700), (858, 620), (868, 530), (884, 450), (932, 446), (962, 540), (978, 640), (978, 720), (958, 782), (920, 812)]),
    # the Wings (their drawn flaps as they are; each outline keeps clear of where the wings sweep)
    'WNG01': dict(root=(712, 915), bend=(0, 160), amp=0.8, poly=[(690, 850), (730, 868), (790, 888), (850, 910), (888, 898), (900, 858), (895, 800), (925, 790), (962, 830), (962, 920), (928, 975), (860, 1012), (800, 1032), (768, 1012), (755, 985), (720, 965), (690, 940)]),
    'WNG02': dict(root=(680, 930), bend=(0, 150), amp=0.7, poly=[(650, 1000), (655, 900), (680, 850), (735, 838), (752, 800), (752, 720), (770, 680), (820, 668), (870, 690), (892, 770), (898, 860), (882, 925), (840, 952), (760, 978), (700, 1005)]),
    'WNG03': dict(mode='shimmy'),                     # its tail is a thick stub along a long seam: it shimmies
    'WNG04': dict(root=(720, 915), bend=(0, 140), amp=0.7, frames=[0, 1, 3, 4, 5, 6], poly=[(700, 975), (700, 900), (712, 868), (785, 866), (818, 850), (822, 800), (840, 740), (865, 722), (885, 745), (895, 820), (880, 905), (835, 960), (780, 980)]),
    'WNG05': dict(root=(725, 905), bend=(0, 160), amp=0.8, poly=[(700, 960), (705, 880), (745, 808), (812, 796), (835, 770), (825, 728), (842, 680), (868, 612), (905, 596), (930, 640), (940, 720), (935, 790), (925, 832), (885, 868), (815, 920), (745, 960)]),
    'WNG06': dict(root=(650, 900), bend=(0, 140), grow=3, poly=[(640, 790), (690, 830), (760, 852), (835, 840), (855, 792), (868, 762), (900, 774), (914, 860), (896, 926), (840, 964), (760, 988), (690, 990), (682, 968), (650, 940), (630, 880)]),
    'WNG07': dict(root=(680, 920), bend=(0, 140), amp=0.8, poly=[(650, 878), (700, 862), (770, 828), (810, 790), (832, 738), (852, 704), (878, 708), (895, 780), (898, 842), (862, 882), (858, 935), (822, 962), (740, 970), (688, 968), (672, 940)]),
    'WNG08': dict(root=(705, 935), bend=(0, 80), amp=0.8, grow=2, tuck=40, poly=[(690, 960), (688, 885), (700, 850), (728, 840), (760, 830), (800, 802), (838, 806), (865, 838), (865, 912), (838, 952), (760, 978), (700, 980)]),
    'WNG09': dict(root=(705, 910), bend=(0, 140), grow=2, poly=[(695, 960), (700, 860), (705, 790), (720, 760), (760, 775), (800, 785), (840, 765), (868, 725), (892, 740), (894, 830), (876, 892), (820, 942), (740, 975)]),
    'WNG10': dict(root=(720, 900), bend=(0, 100), poly=[(705, 950), (705, 860), (722, 808), (752, 784), (790, 772), (838, 770), (858, 800), (852, 880), (820, 935), (760, 960)], polys={2: [(705, 950), (705, 860), (722, 800), (752, 762), (790, 735), (840, 735), (862, 790), (852, 880), (820, 935), (760, 960)], 3: [(705, 950), (705, 860), (722, 800), (735, 760), (760, 722), (800, 716), (842, 728), (862, 790), (852, 880), (820, 935), (760, 960)]}),
    'WNG11': dict(root=(680, 910), bend=(0, 160), poly=[(660, 870), (700, 850), (740, 815), (790, 818), (812, 800), (830, 752), (880, 718), (935, 712), (955, 760), (955, 880), (920, 925), (850, 950), (760, 965), (690, 965)]),
    'WNG12': dict(root=(650, 905), bend=(0, 160), poly=[(640, 838), (690, 852), (740, 862), (800, 845), (832, 812), (835, 760), (842, 712), (870, 705), (900, 760), (905, 830), (888, 900), (810, 958), (720, 980), (690, 978), (684, 955), (660, 925), (640, 900)]),
    'WNG13': dict(root=(700, 915), bend=(0, 150), grow=2, poly=[(700, 880), (760, 878), (810, 870), (840, 830), (838, 770), (842, 712), (872, 712), (888, 790), (892, 860), (868, 920), (810, 955), (720, 968), (690, 955)]),
    'WNG14': dict(root=(680, 900), bend=(0, 120), still=30, hips=0.4, poly=[(660, 860), (700, 836), (760, 812), (830, 790), (860, 800), (880, 850), (890, 900), (860, 925), (800, 950), (740, 975), (690, 985), (660, 960)]),
    'WNG15': dict(root=(780, 920), bend=(0, 150), amp=0.8, grow=1, poly=[(770, 960), (762, 900), (772, 860), (782, 820), (768, 760), (775, 680), (798, 615), (860, 585), (920, 605), (948, 700), (945, 800), (930, 880), (900, 930), (840, 960)], polys={0: [(770, 960), (762, 900), (752, 860), (742, 800), (752, 748), (786, 722), (791, 690), (805, 640), (822, 605), (860, 585), (920, 605), (948, 700), (945, 800), (930, 880), (900, 930), (840, 960)], 2: [(770, 960), (762, 900), (745, 860), (735, 800), (738, 740), (748, 716), (756, 699), (783, 702), (792, 692), (812, 650), (830, 610), (870, 585), (920, 605), (948, 700), (945, 800), (930, 880), (900, 930), (840, 960)], 3: [(770, 960), (762, 900), (745, 860), (732, 800), (735, 730), (758, 680), (805, 625), (835, 585), (875, 580), (925, 605), (950, 700), (948, 800), (930, 880), (900, 930), (840, 960)]}),
    'WNG16': dict(root=(620, 920), bend=(0, 160), poly=[(610, 870), (640, 848), (680, 845), (740, 855), (800, 835), (828, 790), (840, 768), (872, 768), (880, 830), (875, 900), (830, 952), (740, 978), (650, 985), (625, 960)]),
    'WNG17': dict(root=(660, 920), bend=(0, 170), amp=0.8, poly=[(640, 870), (650, 820), (690, 830), (735, 845), (758, 785), (780, 725), (830, 700), (880, 715), (910, 800), (918, 870), (890, 935), (820, 960), (720, 985), (668, 985), (650, 950)]),
    'MAN01': dict(root=(790, 845), bend=(0, 150), poly=[(785, 880), (778, 810), (800, 760), (812, 680), (830, 590), (880, 545), (950, 570), (985, 660), (985, 790), (940, 860), (870, 895), (812, 895)]),
    'MAN02': dict(root=(780, 830), bend=(0, 140), amp=0.6, poly=[(770, 880), (778, 790), (830, 720), (885, 560), (950, 548), (972, 640), (962, 810), (968, 945), (880, 948), (840, 905), (795, 905)]),
    'MAN03': dict(root=(735, 845), bend=(0, 90), poly=[(722, 885), (718, 820), (760, 790), (795, 700), (812, 612), (870, 548), (1000, 585), (1018, 720), (982, 822), (900, 888), (800, 892)]),
    'MAN04': dict(mode='shimmy'),                     # its back cloud is part of its cape, not a tail: it shimmies
    'MAN05': dict(root=(760, 862), bend=(0, 120), amp=0.8, poly=[(745, 905), (750, 830), (800, 795), (880, 775), (1000, 795), (1018, 885), (972, 962), (850, 968), (785, 935)]),
    'MAN06': dict(mode='shimmy'),                     # its tail is a stub (turned, its joints kink): it shimmies
    'MAN07': dict(root=(790, 852), bend=(0, 130), amp=0.8, halo=15, poly=[(780, 885), (790, 800), (822, 722), (812, 640), (826, 578), (862, 528), (975, 505), (1035, 615), (1020, 738), (935, 772), (905, 820), (885, 885), (830, 905)]),
    'MAN08': dict(mode='shimmy'),
    'MAN09': dict(root=(800, 832), bend=(0, 50), poly=[(793, 868), (795, 760), (797, 650), (838, 585), (918, 588), (966, 680), (962, 812), (900, 872), (822, 876)]),
    'MAN10': dict(root=(752, 850), bend=(0, 30), amp=1.4, poly=[(746, 885), (750, 808), (782, 772), (848, 780), (872, 865), (832, 925), (762, 912)]),
    'MAN11': dict(root=(815, 845), bend=(0, 62), low=885,
                  poly=[(790, 790), (812, 762), (830, 680), (900, 662), (985, 700), (992, 790), (930, 830), (900, 862), (860, 888), (830, 897), (812, 880)]),
    'MAN12': dict(root=(790, 852), bend=(0, 150), poly=[(776, 892), (780, 820), (830, 760), (852, 680), (895, 585), (992, 608), (998, 772), (962, 842), (902, 898), (830, 905)]),
    'MAN13': dict(root=(800, 842), bend=(0, 70), halo=25, poly=[(790, 872), (800, 792), (850, 742), (900, 650), (948, 568), (1012, 598), (992, 748), (956, 846), (884, 880), (830, 890)]),
    'MAN14': dict(root=(640, 930), bend=(0, 120), still=80, hips=0.4, tuck=110, poly=[(640, 1005), (640, 860), (690, 800), (742, 722), (838, 730), (858, 845), (822, 945), (730, 1002)]),
    'MAN15': dict(root=(845, 805), bend=(0, 260), amp=0.5, halo=25, tuck=60, poly=[(830, 520), (885, 440), (945, 430), (1030, 500), (1065, 600), (1062, 712), (1040, 812), (975, 872), (900, 870), (860, 836), (848, 792), (822, 742), (806, 680), (806, 600)]),
    'MAN16': dict(mode='shimmy'),                     # its tail is a nub: it shimmies
    'MAN17': dict(root=(802, 840), bend=(0, 100), amp=1.2, grow=4, tuck=80, poly=[(793, 775), (800, 748), (850, 755), (905, 768), (938, 792), (935, 842), (882, 892), (832, 925), (812, 908), (804, 900), (800, 840)]),
    'MAN18': dict(root=(810, 822), bend=(0, 60), grow=2, tuck=85, poly=[(800, 520), (860, 505), (952, 525), (992, 650), (985, 712), (965, 772), (940, 822), (895, 872), (850, 922), (826, 896), (822, 860), (812, 830), (801, 812), (800, 760), (800, 690)]),
}


def _wag_table(n=16, per=6):
    env = [0, .55, .9, 1, 1, 1, 1, 1, 1, 1, 1, 1, .8, .55, .3, 0]
    root, tip, hips, bob = [], [], [], []
    for k in range(n):
        ph = 2 * math.pi * (k - 1 + 0.5) / per
        e = env[k]
        root.append(e * math.sin(ph))
        tip.append(e * math.sin(ph - 0.9))                # the tip a beat behind
        hips.append(e * math.sin(ph - 0.35))
        bob.append(e * abs(math.sin(ph - 0.35)))           # a dip at each end of the sway
    return root, tip, hips, bob


_wr, _wt, _wh, _wb = _wag_table()
WAG = dict(
    root=_wr, tip=_wt, hips=_wh, bob=_wb,
    a_root=float(os.environ.get('WAG_ROOT', 9)), a_tip=float(os.environ.get('WAG_TIP', 20)),     # degrees
    a_hips=float(os.environ.get('WAG_HIPS', 16)), a_bob=float(os.environ.get('WAG_BOB', 0.012)),  # native px; share of height
    a_rock=float(os.environ.get('WAG_ROCK', 2.0)),       # degrees the rump rocks about the belly, against the tail
    a_shimmy=float(os.environ.get('WAG_SHIMMY', 3.5)),   # degrees a tailless body sways over its feet
    eyes=[None] + ['happy'] * 13 + [None] * 2 if os.environ.get('WAG_EYES') != 'open' else [None] * 16,
    dur=[90] + [55] * 13 + [80, 120])


def wag_mask(rig, i=0):
    """The tail as drawn in drawn frame i (its outline grown a little, nearly hard at the edge): 0..1 a
    native px. Sets rig._wagF to that frame's cuts at render scale: (hard, soft, tuck)."""
    import numpy as np
    W = WAG_RIGS[rig.id]
    poly = W.get('polys', {}).get(i, W.get('poly'))
    cache = rig.__dict__.setdefault('_wagcache', {})
    key = tuple(poly) if poly else None
    if key not in cache:
        m = Image.new('L', (rig.F0, rig.F0), 0)
        if poly:
            ImageDraw.Draw(m).polygon(poly, fill=255)
            m = m.filter(ImageFilter.MaxFilter(2 * W.get('grow', 8) + 1)).filter(ImageFilter.GaussianBlur(W.get('soft', 2.5)))
        mask = np.asarray(m, dtype=np.float32) / 255.0
        mf = np.asarray(m.resize((rig.F, rig.F), Image.BILINEAR), dtype=np.float32) / 255.0
        # in a glow the cut is wide and soft, so the glow follows the tail and thins out, never an edge
        ms = Image.new('L', (rig.F0, rig.F0), 0)
        if poly:
            ImageDraw.Draw(ms).polygon(poly, fill=255)
            ms = ms.filter(ImageFilter.MaxFilter(2 * (W.get('grow', 8) + W.get('halo', 0)) + 1)).filter(ImageFilter.GaussianBlur(18))
        msf = np.asarray(ms.resize((rig.F, rig.F), Image.BILINEAR), dtype=np.float32) / 255.0
        # where the tail's root tucks in under the body: drawn with the tail, hidden by the body
        yy, xx = np.mgrid[0:rig.F, 0:rig.F] / rig.k
        rx, ry = W['root']
        tuck = np.clip((W.get('tuck', 70) - np.hypot(xx - rx, yy - ry)) / 15.0, 0, 1)
        cache[key] = (mask, (mf, msf, tuck))
    rig._wagF = cache[key][1]
    return cache[key][0]


def wag_field(rig, k, part='tail'):
    """Where each point of wag frame k is read from (native px), after the body's own squash. 'body'
    is the hips' sway alone; 'tail' is the tail cut out (see wag_frame) turned about its root as well."""
    W, A = WAG_RIGS[rig.id], WAG
    amp = W.get('amp', 1.0)
    px = rig.px
    low = W.get('low', rig.hip - 15 if rig.hip else 2000)          # (a Wing hovers: no legs to keep still)
    foot = W.get('foot', rig.foot or 1150)
    hips = W.get('hips', 0.5 if rig.floats else 1.0)
    if W.get('mode') == 'shimmy':
        # no tail: the body sways over its planted feet, the head riding along
        ang = A['a_shimmy'] * amp * A['hips'][k]
        hx = 0.6 * A['a_hips'] * amp * A['hips'][k]
        cx, cy = px, foot

        def g(x, y):
            w = sm((foot - 25 - y) / 160) if not rig.floats else 1.0
            if w <= 0:
                return x, y
            ra = math.radians(-ang * w)
            ux, uy = x - cx, y - cy
            return cx + ux * math.cos(ra) - uy * math.sin(ra) + w * hx, cy + ux * math.sin(ra) + uy * math.cos(ra)
        return g
    rx, ry = W['root']
    th_r, th_t = A['a_root'] * amp * A['root'][k], A['a_tip'] * amp * A['tip'][k]
    hx = A['a_hips'] * hips * A['hips'][k]
    rock = -A['a_rock'] * hips * A['hips'][k]
    d0, d1 = W['bend']
    still = W.get('still', 0)
    bx, by = px + 20, low - 30                           # the belly the rump rocks about

    def f(x, y):
        # the hips: the rear half sways sideways and rocks, the feet stay where they stand
        wr = sm((x - (px + 10)) / 160) * sm((y - (rig.neck[1] - 60)) / 80) * (1 - sm((y - (low + 20)) / 85))
        if wr > 0:
            ra = math.radians(-rock * wr)
            ux, uy = x - bx, y - by
            x, y = bx + ux * math.cos(ra) - uy * math.sin(ra) - wr * hx, by + ux * math.sin(ra) + uy * math.cos(ra)
        if part == 'body':
            return x, y
        # the tail: turned about its root, still at the root, bending near it, what is on the tip
        # turned whole
        dx, dy = x - rx, y - ry
        d = math.hypot(dx, dy)
        e = max(0.0, d - still)                         # (within [still] of the root it holds where it is)
        th = th_r * sm(e / 50) + (th_t - th_r) * sm((e - d0) / (d1 - d0))
        a = math.radians(-th)
        return rx + dx * math.cos(a) - dy * math.sin(a), ry + dx * math.sin(a) + dy * math.cos(a)
    return f


def wag_frame(rig, i, mode, sx, sy, k):
    """Wag frame k from idle frame i: the tail cut out and turned on its own, behind the body (whose
    hole where the tail was shows what is behind it). The tail's root reaches in under the body, so
    the seam never opens; at rest the two together are the frame exactly."""
    import numpy as np
    W = WAG_RIGS[rig.id]
    if W.get('mode') == 'shimmy':
        return rig.pose(i, mode, sx, sy, 0, (0, 0), 0, 0, extra=wag_field(rig, k))
    if rig.layer == 'eyes':                              # (the eyes are nowhere near the tail)
        return rig.pose(i, mode, sx, sy, 0, (0, 0), 0, 0, extra=wag_field(rig, k, 'body'))
    wag_mask(rig, i)
    mh, ms, tuck = rig._wagF
    face = rig.face(i, mode)
    al = np.asarray(face.getchannel('A'), dtype=np.float32) / 255.0
    if getattr(rig, '_wag_hard', None) is None:          # hard-edged art (a Horn's) has no glow: what is half-clear
        seen = al > 0.05                                  # round it is its anti-aliased outline
        rig._wag_hard = bool(((al > 0.05) & (al < 0.9)).sum() < 0.04 * max(1, seen.sum()))
    solid_ = np.clip((al - 0.5) / 0.4, 0, 1)
    mc = mh if rig._wag_hard else mh * solid_ + ms * (1 - solid_)     # hard where it is solid, soft in its glow
    # the tail's share: what makes "body over tail" give back the frame (opaque where the tail is)
    g = np.maximum(tuck, np.clip(mc / np.maximum(1e-3, 1 - (1 - mc) * al), 0, 1))
    tail = face.copy()
    tail.putalpha(Image.fromarray(np.round(al * g * 255).astype(np.uint8)))
    body = face.copy()
    body.putalpha(Image.fromarray(np.round(al * (1 - mc) * 255).astype(np.uint8)))
    # where the solid tail was, the glow round it, laid under the tail: hidden while the tail is there,
    # it keeps the glow whole once the tail swings away (an empty patch in a glow reads as a dark hole)
    from scipy.ndimage import gaussian_filter
    ab = al * (1 - mc)
    w = ((ab > 0.02) & (ab < 0.85)).astype(np.float32) * (1 - mc)
    rgb = np.asarray(face.convert('RGB'), dtype=np.float32)
    sg = 10 * rig.k / 0.5
    den = gaussian_filter(w, sg)
    na = gaussian_filter(ab * w, sg)
    nrgb = np.stack([gaussian_filter(rgb[..., c] * ab * w, sg) for c in range(3)], -1)
    fa = mh * (al > 0.9) * np.where(den > 1e-4, na / np.maximum(den, 1e-4), 0) * np.clip(den / 0.25, 0, 1)
    if rig._wag_hard:                                    # (no glow to fill: its outline would smear)
        fa = fa * 0
    frgb = np.where(na[..., None] > 1e-5, nrgb / np.maximum(na[..., None], 1e-5), 0)
    fill = Image.fromarray(np.dstack([np.clip(frgb, 0, 255), np.clip(fa * 255, 0, 255)]).round().astype(np.uint8), 'RGBA')
    # where the tail meets the body, its base as drawn, left where it is under everything: the tail
    # turning off it never opens a gap there (hidden at rest under the solid tail)
    from scipy.ndimage import distance_transform_edt
    yy, xx = np.mgrid[0:rig.F, 0:rig.F] / rig.k
    near = np.hypot(xx - W['root'][0], yy - W['root'][1]) < W.get('seamr', 150)     # (where the tail meets the body)
    seam = (mh > 0.15) & (mh < 0.85) & (al > 0.9) & near
    band = np.clip((W.get('seam', 26) * rig.k - distance_transform_edt(~seam)) / (4 * rig.k), 0, 1) if seam.any() else np.zeros_like(al)
    # its colour: the body's own just beside the seam, carried across it (an average of the body round
    # it took in stripes and outlines and showed as a grey streak)
    src_ = (ab > 0.9) & (mc < 0.1)
    if src_.any():
        _, (iy, ix) = distance_transform_edt(~src_, return_indices=True)
        srgb = rgb[iy, ix]
        srgb = np.stack([gaussian_filter(srgb[..., c], 1.5 * rig.k / 0.5) for c in range(3)], -1)
    else:
        srgb = rgb
    ua = (al > 0.9) * band        # (solid across the seam: half of it under half a body showed a dark line)
    under = Image.fromarray(np.dstack([np.clip(srgb, 0, 255), ua * 255]).round().astype(np.uint8), 'RGBA')
    # the body's glow goes under the tail, its solid parts over it (the tail is behind the body)
    sb = Image.fromarray(((al > 0.9) * 255).astype(np.uint8))
    bglow, bsolid = body.copy(), body.copy()
    bglow.putalpha(ImageChops.multiply(body.getchannel('A'), ImageChops.invert(sb)))
    bsolid.putalpha(ImageChops.multiply(body.getchannel('A'), sb))
    t = rig.pose(i, mode, sx, sy, 0, (0, 0), 0, 0, src=tail, extra=wag_field(rig, k, 'tail'))
    rig.log.pop()                                        # (one pose a frame, for the costume's track)
    layers = []
    for src in (under, fill, bglow):
        layers.append(rig.pose(i, mode, sx, sy, 0, (0, 0), 0, 0, src=src, extra=wag_field(rig, k, 'body')))
        rig.log.pop()
    b = rig.pose(i, mode, sx, sy, 0, (0, 0), 0, 0, src=bsolid, extra=wag_field(rig, k, 'body'))
    out = layers[0]
    for lay in layers[1:] + [t, b]:
        out = Image.alpha_composite(out, lay)
    return out


def wag_rig_check(rig, hid):
    """Its first frame with the tail's mask tinted and the root marked (or SHIMMY written on it)."""
    base = Image.new('RGBA', (rig.F0, rig.F0), (46, 46, 56, 255))
    base.alpha_composite(rig.raw[0])
    W = WAG_RIGS[hid]
    d = ImageDraw.Draw(base)
    if W.get('mode') == 'shimmy':
        d.text((40, 40), 'SHIMMY', fill=(255, 255, 0, 255), font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 80))
    else:
        m = Image.fromarray((wag_mask(rig) * 150).astype('uint8'))
        base = Image.composite(Image.new('RGBA', base.size, (0, 255, 120, 255)), base, m)
        d = ImageDraw.Draw(base)
        rx, ry = W['root']
        d.ellipse((rx - 8, ry - 8, rx + 8, ry + 8), fill=(255, 0, 255, 255))
        for r in W['bend'][1:]:
            d.ellipse((rx - r, ry - r, rx + r, ry + r), outline=(255, 0, 255, 255), width=2)
    low = W.get('low', rig.hip - 15 if rig.hip else 2000)
    d.line((0, low, rig.F0, low), fill=(255, 255, 255, 120), width=2)
    return base.convert('RGB')


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
        elif name == 'wag':
            A = WAG
            for k in range(16):
                sy = 1 - A['a_bob'] * A['bob'][k]
                sx = 1 + 0.5 * A['a_bob'] * A['bob'][k] * wide
                seq = WAG_RIGS[rig.id].get('frames') or list(range(n))       # (the drawn frames it cycles through)
                out.append(wag_frame(rig, seq[(k // 2) % len(seq)], A['eyes'][k], sx, sy, k))
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
    return HOP['dur'] if name == 'hop' else FIRE['dur'] if name == 'fire' else WAG['dur'] if name == 'wag' else [150] * NS


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
if os.environ.get('ANIMS'):                                # only these (the wag is made only this way: ANIMS=wag)
    anims = {a: {} for a in os.environ['ANIMS'].split(',')}
    if 'wag' in anims:                                 # (the Manes, Horns, Wings and Pips)
        ids = [i for i in ids if i in WAG_RIGS]
TRACKS = {}
for hid in ids:
    rig = Rig(hid)
    notes = []
    if 'wag' in anims and os.environ.get('WAG_RIG') and hid in WAG_RIGS:    # the tail's mask and root, to place them by
        wag_rig_check(rig, hid).save('%s/%s_wag_rig.png' % (OUT, hid))
        if os.environ.get('WAG_RIG') == 'only':
            continue
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
            shim = name == 'wag' and WAG_RIGS.get(hid, {}).get('mode') == 'shimmy'
            tr = rig.track(rig.poses, base_of, [wag_field(rig, k) for k in range(16)] if shim else None)
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

if os.environ.get('WAG_RIG') == 'only':                # the rigs alone
    sys.exit(0)
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
    sheet[{'hop': 9, 'fire': 3, 'sleep': 4, 'wag': 5}[name]].save('%s/%s_%s_check.png' % (OUT, tag, name))
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
