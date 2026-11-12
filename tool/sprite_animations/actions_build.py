"""Hop, fire and sleep for every Let, Horn, Wing and Pip, from each one's original drawn
frames (read from git HEAD) and the rigs placed for the idle pass.

  body  : squash and stretch about the feet, a lift, the head moved/turned about the neck,
          the tail swung about its root (one smooth field, as in the idle pass)
  eyes  : found from the species' albino eye overlay, covered with the skin around them and
          redrawn shut (happy arcs, sleeping curves) or half shut under a lid (aiming)
  drawn : the original's own frames keep cycling, so flames, steam and wings stay alive

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
            ov = None if fam == 'MAN' else head_img(ov_path)
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
    def pose(self, i, mode, sx=1.0, sy=1.0, h=0.0, hd=(0.0, 0.0), hrot=0.0, trot=0.0, pad=0):
        """h, hd in native px; rotations in degrees."""
        src = self.face(i, mode)
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


def durations(name):
    return HOP['dur'] if name == 'hop' else FIRE['dur'] if name == 'fire' else [150] * NS


RIGS = {}
if FAM == 'HOR':
    RIGS['HOR'] = load('horns_build.py', "ids = ONLY or sorted(P)", [REPO, S_DIR + '/horns', 'none'])
elif FAM == 'WNG':
    RIGS['WNG'] = load('wings_build.py', "if MODE in ('overlay', 'build'):", [REPO, S_DIR + '/wings', 'none'])
elif FAM == 'PIP':
    RIGS['PIP'] = load('pips_build.py', "if MODE in ('overlay', 'build'):", [REPO, S_DIR + '/pips', 'none'])
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
anims = {'hop': {}, 'fire': {}, 'sleep': {}}
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
    print(hid, rig.name, 'eyes found' if rig.eyes[0] is not None and rig.eyes[0].getbbox() else 'NO EYES', '; '.join(notes), flush=True)

tag = FAM.lower() + ('_' + only.replace(',', '_') if only else '')
for name, per in anims.items():
    rows = -(-len(per) // COLS)
    nfr = len(next(iter(per.values()))[1])
    W, H = COLS * CELLPX, 40 + rows * (CELLPX + 26)
    sheet = []
    for k in range(nfr):
        s = Image.new('RGB', (W, H), BG[:3])
        d = ImageDraw.Draw(s)
        d.text((12, 10), '%s  ·  %s' % ({'HOR': 'HORNS', 'WNG': 'WINGS', 'PIP': 'PIPS', 'LET': 'LETS', 'MAN': 'MANES'}[FAM], name.upper()), fill=(230, 210, 160), font=font)
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

if os.environ.get('KEEP'):
    json.dump(TRACKS, open('%s/tracks_%s.json' % (OUT, tag), 'w'))
