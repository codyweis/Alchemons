"""Cuts the new family off its concept card and builds each one's idle sheet.

The concept art is a grid of seventeen creatures on a flat grey card. For each
one this lifts it off the card (an unmixed matte, so the outline keeps its
anti-aliasing and no grey fringe), stands it in the game's 512px frame -- one
scale for the whole card, so the family keeps its sizes -- and draws four idle
frames in its element's own way: a breath, a sway, a glow, and only what its
element really throws off (lightning's arcs, a flame's embers, a drip). Every motion runs one full cycle in the four frames, so the loop has no
seam when the game plays it at 120 ms a frame like every other sheet.

    python tool/creature_idle_sheet.py               # all seventeen
    python tool/creature_idle_sheet.py fire water    # just these
    python tool/creature_idle_sheet.py --contact     # also a contact sheet

writes NAME.png (the still), NAME_spritesheet.png (4 x 512 frames) and
NAME_preview.gif (the loop on the grey card) into art_sources/creatures/
new_family/. Run with NumPy + SciPy + Pillow.
"""
import argparse
import math
import os

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = os.path.join("art_sources", "creatures", "new_family")
CARD = os.path.join(HERE, "concept_sheet.jpg")

FRAME = 512
FRAMES = 4
# The Let sheets stand their feet ~40px off the frame's bottom.
FEET_Y = 474
# One scale for the whole card: its tallest (Steam, with its cloud ring)
# stands ~438px, the rest in proportion.
SCALE = 0.775

# Phase of each frame through the loop, 0..1.
PHASE = [f / FRAMES for f in range(FRAMES)]
# A breath or a pulse: rest, rising, peak, falling.
SWELL = [0.0, 0.5, 1.0, 0.5]


def smoothstep(x, lo, hi):
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def rgb(*c):
    return np.array(c, np.float32) / 255.0


# ---------------------------------------------------------------------------
# Lifting a creature off the card


def cut_out(rgb_u8):
    """Premultiplied RGBA (float, 0-1) of the creature on a flat card."""
    p = rgb_u8.astype(np.float32) / 255.0
    border = np.concatenate([p[:6].reshape(-1, 3), p[-6:].reshape(-1, 3),
                             p[:, :6].reshape(-1, 3), p[:, -6:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    dist = np.abs(p - bg).max(-1)

    # Card is only what is card-coloured AND holds a patch of flat card grey:
    # the line art's own anti-aliasing (black outline into an eye's white,
    # gold outline into a bolt) passes through the card's grey in thin
    # threads, and those belong to the creature. A real gap -- the open card,
    # the loop of a bent arm -- holds a patch of flat grey; a thread doesn't.
    greyish = dist <= 0.10
    flat = ndi.binary_erosion(greyish, iterations=1) & (dist < 0.07)
    lab, n = ndi.label(greyish)
    patches = ndi.sum(flat, lab, np.arange(1, n + 1))
    card = np.isin(lab, 1 + np.nonzero(patches >= 8)[0])
    body = ~card
    lab, n = ndi.label(body)
    sizes = ndi.sum(body, lab, np.arange(1, n + 1))
    body = np.isin(lab, 1 + np.nonzero(sizes >= 400)[0])
    card = ~body

    # Along the card's edge, unmix each pixel against the nearest strongly
    # coloured one -- its own outline, usually: P = a*F + (1-a)*card. A pale
    # outline (a bolt's gold line) sits only ~0.15 off the card and still
    # has to count as strong, or it would unmix to nothing.
    strong = body & (dist > 0.15)
    edge = ndi.binary_dilation(card, iterations=3) & ~strong
    far, (iy, ix) = ndi.distance_transform_edt(~strong, return_indices=True)
    f = p[iy, ix]
    fb = f - bg
    a_edge = ((p - bg) * fb).sum(-1) / np.maximum((fb * fb).sum(-1), 1e-4)
    a_edge = np.clip(a_edge, 0.0, 1.0)
    # Card well away from the creature is card, whatever its JPEG noise says;
    # a soft wisp fading out keeps its fade inside that reach.
    a_edge[card & ((dist < 0.03) | (far > 14))] = 0.0

    alpha = np.where(edge, a_edge, body.astype(np.float32)).astype(np.float32)
    safe = np.maximum(alpha, 1e-4)[..., None]
    unmixed = np.clip(bg + (p - bg) / safe, 0.0, 1.0)
    keep = smoothstep(alpha, 0.25, 0.6)[..., None]
    color = np.where(edge[..., None], unmixed * keep + f * (1 - keep), p)
    return np.dstack([color * alpha[..., None], alpha])


def resize(premul, size):
    chans = [np.asarray(Image.fromarray(premul[..., c]).resize(size, Image.LANCZOS))
             for c in range(4)]
    out = np.dstack(chans)
    out[..., 3] = np.clip(out[..., 3], 0.0, 1.0)
    out[..., :3] = np.clip(out[..., :3], 0.0, out[..., 3:4])
    return out


def place(premul, nudge_x=0, lift=0):
    """Stands the cut-out in a FRAME x FRAME cell; returns it and its box."""
    a = premul[..., 3]
    ys, xs = np.nonzero(a > 0.02)
    premul = premul[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = premul.shape[:2]
    nw, nh = round(w * SCALE), round(h * SCALE)
    small = resize(premul, (nw, nh))
    cell = np.zeros((FRAME, FRAME, 4), np.float32)
    x0 = (FRAME - nw) // 2 + nudge_x
    y0 = FEET_Y - nh - lift
    cell[y0:y0 + nh, x0:x0 + nw] = small
    return cell, (x0, y0, x0 + nw, y0 + nh)


# ---------------------------------------------------------------------------
# Picking parts of a creature


class Body:
    """The placed creature, with helpers to pick its parts."""

    def __init__(self, premul, box):
        self.premul = premul
        self.box = box
        a = premul[..., 3]
        self.alpha = a
        self.color = premul[..., :3] / np.maximum(a, 1e-4)[..., None]
        c = self.color
        mx, mn = c.max(-1), c.min(-1)
        chroma = mx - mn
        self.val = mx
        self.sat = chroma / np.maximum(mx, 1e-4)
        r, g, b = c[..., 0], c[..., 1], c[..., 2]
        safe = np.maximum(chroma, 1e-4)
        self.hue = np.where(mx == r, ((g - b) / safe) % 6,
                            np.where(mx == g, (b - r) / safe + 2,
                                     (r - g) / safe + 4)) * 60
        self.lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        yy, xx = np.mgrid[0:FRAME, 0:FRAME].astype(np.float32)
        x0, y0, x1, y1 = box
        self.u = (xx - x0) / (x1 - x0)
        self.v = (yy - y0) / (y1 - y0)

    def at(self, u, v):
        """Frame pixel of a point given across the creature's box (0-1)."""
        x0, y0, x1, y1 = self.box
        return x0 + u * (x1 - x0), y0 + v * (y1 - y0)

    def size(self, s):
        """A length given as a share of the creature's height, in pixels."""
        return s * (self.box[3] - self.box[1])

    def mask(self, hue=None, sat=None, val=None, lum=None, box=None, soft=0.0):
        """Soft 0-1 mask of the pixels matching every test given."""
        m = self.alpha.copy()
        if hue is not None:
            # A hue range, wrapping through red when lo > hi (340, 20).
            lo, hi = hue
            width = (hi - lo) % 360
            mid = (lo + width / 2) % 360
            d = np.abs((self.hue - mid + 180) % 360 - 180) - width / 2
            m = m * (1.0 - smoothstep(d, 0.0, 8.0))
        for arr, rng in ((self.sat, sat), (self.val, val), (self.lum, lum)):
            if rng is None:
                continue
            lo, hi = rng
            if lo is not None:
                m = m * smoothstep(arr, lo - 0.06, lo + 0.06)
            if hi is not None:
                m = m * (1.0 - smoothstep(arr, hi - 0.06, hi + 0.06))
        if box is not None:
            u0, v0, u1, v1 = box
            m = m * ((self.u >= u0) & (self.u <= u1) & (self.v >= v0) & (self.v <= v1))
        if soft:
            m = ndi.gaussian_filter(m, soft)
        return m.astype(np.float32)

    def lowest(self, box):
        """The lowest solid pixel in a region: where a drop would hang."""
        m = self.mask(box=box) > 0.5
        ys, xs = np.nonzero(m)
        i = np.argmax(ys + 0.001 * xs)
        y = ys[i]
        row = xs[ys == y]
        return float(row.mean()), float(y)

    def points(self, mask, n, seed, min_gap=0.0):
        """n random pixels inside a mask, weighted by it."""
        rng = np.random.default_rng(seed)
        w = mask.ravel().astype(np.float64)
        w = w / w.sum()
        picks = []
        tries = 0
        while len(picks) < n and tries < n * 50:
            tries += 1
            i = rng.choice(w.size, p=w)
            y, x = divmod(i, FRAME)
            if all((x - px) ** 2 + (y - py) ** 2 >= min_gap ** 2 for px, py in picks):
                picks.append((float(x), float(y)))
        return picks


# ---------------------------------------------------------------------------
# Motion: every motion maps each output pixel back to where it samples from


class Motion:
    def __init__(self):
        yy, xx = np.mgrid[0:FRAME, 0:FRAME].astype(np.float32)
        self.x = xx
        self.y = yy
        self.sx = xx.copy()
        self.sy = yy.copy()

    def scale_about(self, cx, cy, kx, ky):
        self.sx = cx + (self.sx - cx) / kx
        self.sy = cy + (self.sy - cy) / ky

    def shift(self, dx, dy):
        self.sx = self.sx - dx
        self.sy = self.sy - dy

    def apply(self, img, order=1):
        if img.ndim == 2:
            return ndi.map_coordinates(img, [self.sy, self.sx], order=order,
                                       mode="constant", cval=0.0).astype(np.float32)
        return np.dstack([self.apply(img[..., c], order) for c in range(img.shape[2])])


def breathe(m, body, f, rise=0.010, narrow=0.004):
    t = SWELL[f]
    cx = (body.box[0] + body.box[2]) / 2
    m.scale_about(cx, FEET_Y, 1 - narrow * t, 1 + rise * t)


def heartbeat(m, body, f, beat=0.022):
    """Lub-dub: a strong beat, a smaller one, then rest."""
    t = [0.0, 1.0, 0.45, 0.0][f]
    cx = (body.box[0] + body.box[2]) / 2
    m.scale_about(cx, FEET_Y, 1 + beat * 0.6 * t, 1 + beat * t)


def bob(m, body, f, px=5.0):
    """Floats up and down a full cycle per loop."""
    m.shift(0.0, -px * math.sin(2 * math.pi * PHASE[f]))


def sway(m, body, f, amp=4.0, pivot=0.35, top=0.0, wave=1.2, where=None, phase=0.0):
    """Sways what lies beyond `pivot` (share of height from the top) toward
    `top` side to side, more the further out it is; `wave` sends the sway
    along it as a ripple. With top > pivot it sways what hangs below."""
    py = body.at(0, pivot)[1]
    ty = body.at(0, top)[1]
    out = (py - m.y) / (py - ty) if ty != py else np.zeros_like(m.y)
    w = smoothstep(out, 0.0, 1.0) ** 1.4
    if where is not None:
        w = w * where
    dx = amp * w * np.sin(2 * math.pi * (PHASE[f] + phase) - wave * out * math.pi)
    m.shift(dx, 0.0)


def flap(m, body, f, where, amp=4.0, phase=0.0):
    """Lifts and drops one part (a wing, a tail) a full cycle a loop."""
    m.shift(0.0, -amp * where * math.sin(2 * math.pi * (PHASE[f] + phase)))


def flicker(m, body, f, where, amp=3.0, waves=3.0, lift=2.0):
    """Licks a flame: ripples running up through `where`, and a tug upward."""
    yspan = body.box[3] - body.box[1]
    k = 2 * math.pi * waves / yspan
    ph = 2 * math.pi * PHASE[f]
    dx = amp * where * np.sin(k * m.y + ph) * (0.6 + 0.4 * np.cos(k * 0.37 * m.x - ph))
    dy = lift * where * (0.5 + 0.5 * np.sin(k * 0.8 * m.y + ph + 1.3))
    m.shift(dx, -dy)


# ---------------------------------------------------------------------------
# Light: glows and arcs


def blur(x, sigma):
    return ndi.gaussian_filter(x, sigma, mode="constant")


def glow(fr, mask, f, color, core=None, levels=(0.25, 0.6, 1.0, 0.6), heat=(0.08, 0.27),
         halo=1.0, spill=0.5, reach=1.0):
    """The masked parts warm toward a hot core and throw light around them."""
    g = levels[f]
    core = color if core is None else core
    hot = (mask * (heat[0] + heat[1] * g))[..., None]
    fr.col = fr.col + (core - fr.col) * hot
    h = (blur(mask, 5 * reach) * 0.9 + blur(mask, 14 * reach) * 1.2 +
         blur(mask, 30 * reach) * 0.8) * g * halo
    s = (np.clip(h * spill, 0.0, 0.8) * (1.0 - mask))[..., None]
    fr.col = 1 - (1 - fr.col) * (1 - color * s)
    air = np.clip(h * 0.75, 0.0, 0.8)
    fr.behind_add(color, air)


def tint(fr, mask, f, color, levels=(0.0, 0.5, 1.0, 0.5), amount=0.35, mode="screen"):
    """Washes the masked parts toward a colour as the pulse rises."""
    k = (mask * amount * levels[f])[..., None]
    if mode == "screen":
        fr.col = 1 - (1 - fr.col) * (1 - color * k)
    elif mode == "multiply":
        fr.col = fr.col * (1 - k + color * k)
    else:
        fr.col = fr.col + (color - fr.col) * k


def motes(fr, f, pts, color, rise=(0, -60), size=4.0, grow=(1.0, 1.0), shape="soft",
          seed=0, alpha=0.9, wobble=6.0, layer="front", edge=None, spin=0.0, fade=0.8):
    """One mote per point, each at its own phase of a life that lasts one loop;
    `rise` is how far a mote travels over its life."""
    rng = np.random.default_rng(seed)
    for (x0, y0) in pts:
        ph = rng.random()
        wob = rng.random() * 2 * math.pi
        sz = size * (0.7 + 0.6 * rng.random())
        ang0 = rng.random() * math.pi
        t = (ph + PHASE[f]) % 1.0
        rx, ry = rise(x0, y0) if callable(rise) else rise
        x = x0 + rx * t + wobble * math.sin(2 * math.pi * t + wob)
        y = y0 + ry * t
        # `fade` below 1 keeps a mote solid most of its life, gone quickly.
        life = math.sin(math.pi * t) ** fade
        s = sz * (grow[0] + (grow[1] - grow[0]) * t)
        fr.dot(x, y, s, color, alpha * life, shape=shape, layer=layer, edge=edge,
               angle=ang0 + spin * t * 2 * math.pi, vel=(rx, ry))


def drip(fr, x, y, f, color, r=4.0, fall=44.0, shade=None, shine=True, offset=0):
    """A drop swells, sags, lets go and falls: one drop a loop."""
    k = (f + offset) % FRAMES
    x, y = fr.fwd(x, y)
    dark = color * 0.55 if shade is None else shade
    if k == 0:
        drops = [(x, y + r * 0.2, r * 0.55, 1.0, 1.0)]
    elif k == 1:
        drops = [(x, y + r * 0.7, r * 0.9, 1.25, 1.0), (x, y + r * 0.1, r * 0.45, 1.6, 1.0)]
    elif k == 2:
        drops = [(x, y + fall * 0.4, r * 0.8, 1.35, 1.0), (x, y + r * 0.1, r * 0.3, 1.0, 1.0)]
    else:
        drops = [(x, y + fall, r * 0.7, 1.5, 0.75)]
    for (dx, dy, rr, stretch, a) in drops:
        fr.dot(dx, dy, rr, color, a, shape="egg", edge=dark, stretch=stretch)
        if shine:
            fr.dot(dx - rr * 0.3, dy - rr * 0.35 * stretch, rr * 0.28, rgb(255, 255, 255),
                   0.75 * a, shape="soft")


def arcs(fr, f, ends, color, seed=0, width=1.2, jag=0.22, per_frame=2):
    """Electric arcs jumping between pairs of points, a new crackle each frame."""
    rng = np.random.default_rng(seed + 101 * f)
    order = rng.permutation(len(ends))[:per_frame]
    for i in order:
        (ax, ay), (bx, by) = ends[i]
        ax, ay = fr.fwd(ax, ay)
        bx, by = fr.fwd(bx, by)
        n = 7
        L = math.hypot(bx - ax, by - ay)
        nx, ny = -(by - ay) / (L or 1), (bx - ax) / (L or 1)
        pts = []
        for j in range(n + 1):
            t = j / n
            off = 0.0 if j in (0, n) else rng.normal() * jag * L * math.sin(math.pi * t)
            pts.append((ax + (bx - ax) * t + nx * off, ay + (by - ay) * t + ny * off))
        fr.polyline(pts, width * 3.5, color, 0.35)
        fr.polyline(pts, width, color, 1.0)
        fr.polyline(pts, width * 0.45, rgb(255, 255, 255), 1.0)


def licks(fr, f, color, rim=None, source=None, reach=7.0, height=46.0, strength=0.8,
          waves=4.0, wobble=5.0, soft=1.6, cap=0.9, layer="behind"):
    """Tongues licking up off the creature (or off `source`, a mask of part
    of it): Dark's shadow flames, Steam's vapor. Each loop the tongues sway
    and flicker one full cycle, so they never jump at the seam."""
    src = fr.alpha if source is None else source
    base = np.clip(blur(src, reach) * 1.6, 0, 1)
    x, y = fr.motion.x, fr.motion.y
    ph = 2 * math.pi * PHASE[f]
    acc = np.zeros_like(base)
    steps = 32
    for i in range(1, steps + 1):
        k = i / steps
        dx = wobble * k * np.sin(y / FRAME * 2 * math.pi * waves + ph + 1.7 * k) + 3.0 * k * np.sin(x / 23.0 - ph)
        dy = height * k
        sx = x - dx
        sy = y + dy
        lick = 0.55 + 0.45 * np.sin(x / 17.0 + ph * 1.0 + k * 2.0)
        smp = ndi.map_coordinates(base, [sy, sx], order=1, mode="constant")
        acc = np.maximum(acc, smp * (1 - k) ** 1.3 * lick)
    a = np.clip(blur(acc, soft) * strength, 0, cap)
    if layer == "behind":
        fr.behind_add(color, a)
    else:
        lay = np.concatenate([color * a[..., None], a[..., None]], -1)
        fr.front = lay + fr.front * (1 - a[..., None])
    if rim is not None:
        edge = np.clip(a - np.clip(blur(a, 3.0) - 0.04, 0, 1), 0, 1)
        fr.behind_add(rim, np.clip(edge * 1.5, 0, 0.6))


def boil(m, body, f, where, amp=2.5, scale=16.0):
    """Churns a cloud: its lobes roll and its edges billow, a full turn a loop."""
    ph = 2 * math.pi * PHASE[f]
    x, y = m.x, m.y
    dx = amp * where * np.sin(y / scale + ph + np.sin(x / (scale * 1.4)))
    dy = amp * where * np.cos(x / scale - ph + np.sin(y / (scale * 1.2)))
    m.shift(dx, dy)


def swell(m, body, f, center, k=0.025, where=None):
    """Swells a part out from `center` with the breath, like pressure building."""
    cx, cy = center
    g = 1 + k * SWELL[f]
    w = 1.0 if where is None else where
    m.sx = m.sx + w * ((cx + (m.sx - cx) / g) - m.sx)
    m.sy = m.sy + w * ((cy + (m.sy - cy) / g) - m.sy)


def aura(fr, f, color, levels=SWELL, reach=10.0, strength=0.6, mask=None):
    """Coloured light behind the creature, hugging its outline."""
    a = fr.alpha if mask is None else mask
    h = (blur(a, reach) * 0.7 + blur(a, reach * 2.5) * 0.6) * strength * levels[f]
    fr.behind_add(color, np.clip(h, 0, 0.85))


# ---------------------------------------------------------------------------
# A frame being drawn


class Frame:
    def __init__(self, body, f, motion):
        self.f = f
        self.motion = motion
        moved = np.clip(motion.apply(body.premul), 0.0, 1.0)
        self.alpha = moved[..., 3]
        self.col = moved[..., :3] / np.maximum(self.alpha, 1e-4)[..., None]
        self.col = np.clip(self.col, 0.0, 1.0)
        self.behind = np.zeros((FRAME, FRAME, 4), np.float32)
        self.front = np.zeros((FRAME, FRAME, 4), np.float32)

    def warp(self, mask):
        """A mask picked on the still, moved the way this frame moved."""
        return np.clip(self.motion.apply(mask), 0.0, 1.0)

    def fwd(self, x, y):
        """Where a point on the still sits in this frame."""
        xi, yi = int(round(min(max(x, 0), FRAME - 1))), int(round(min(max(y, 0), FRAME - 1)))
        return x - (self.motion.sx[yi, xi] - x), y - (self.motion.sy[yi, xi] - y)

    def polyline(self, pts, width, color, a, layer="front"):
        """A line through pts; width and a may be one value or one per point,
        so a stroke can taper. Painted once, so its joints don't bead."""
        n = len(pts)
        ws = list(width) if isinstance(width, (list, tuple)) else [width] * n
        als = list(a) if isinstance(a, (list, tuple)) else [a] * n
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        R = int(math.ceil(max(ws) * 3 + 2))
        x0, y0 = int(min(xs)) - R, int(min(ys)) - R
        x1, y1 = int(max(xs)) + R + 1, int(max(ys)) + R + 1
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        cov = np.zeros(xx.shape, np.float32)
        for i in range(n - 1):
            (ax, ay), (bx, by) = pts[i], pts[i + 1]
            vx, vy = bx - ax, by - ay
            t = np.clip(((xx - ax) * vx + (yy - ay) * vy) / max(vx * vx + vy * vy, 1e-6), 0, 1)
            d = np.hypot(xx - ax - t * vx, yy - ay - t * vy)
            w = ws[i] + (ws[i + 1] - ws[i]) * t
            al = als[i] + (als[i + 1] - als[i]) * t
            cov = np.maximum(cov, np.exp(-(d * d) / (2 * (w * 0.6) ** 2)) * al)
        self.paint(layer, 0, 0, np.clip(cov, 0, 1), color, x0, y0)

    def behind_add(self, color, a):
        """Adds light behind the creature (premultiplied, screen-like)."""
        a = np.clip(a, 0, 1)[..., None]
        lay = np.concatenate([color * a, a], -1)
        self.behind = lay + self.behind * (1 - a)

    def _layer(self, layer):
        return self.front if layer == "front" else self.behind

    def paint(self, layer, x, y, a_patch, color, x0, y0):
        """Composites a coverage patch (0-1) of one colour onto a layer."""
        lay = self._layer(layer)
        h, w = a_patch.shape
        X0, Y0 = max(x0, 0), max(y0, 0)
        X1, Y1 = min(x0 + w, FRAME), min(y0 + h, FRAME)
        if X1 <= X0 or Y1 <= Y0:
            return
        a = a_patch[Y0 - y0:Y1 - y0, X0 - x0:X1 - x0][..., None]
        src = np.concatenate([np.broadcast_to(color, a.shape[:2] + (3,)) * a, a], -1)
        dst = lay[Y0:Y1, X0:X1]
        lay[Y0:Y1, X0:X1] = src + dst * (1 - a)

    def dot(self, x, y, s, color, a, shape="soft", layer="front", edge=None, angle=0.0,
            vel=(0, -1), stretch=1.0):
        if a <= 0.01 or s <= 0.2:
            return
        R = int(math.ceil(s * 3 * max(stretch, 1.0) + 3))
        x0, y0 = int(math.floor(x)) - R, int(math.floor(y)) - R
        yy, xx = np.mgrid[y0:y0 + 2 * R + 1, x0:x0 + 2 * R + 1].astype(np.float32)
        dx, dy = xx - x, yy - y
        d = np.hypot(dx, dy)
        if shape == "soft":
            cov = np.exp(-(d * d) / (2 * (s * 0.6) ** 2))
        elif shape == "disc":
            cov = np.clip(s + 0.5 - d, 0, 1)
        elif shape == "egg":
            # A drop: round below, drawn out to a point above.
            ry = np.where(dy < 0, s * stretch, s)
            e = np.sqrt((dx / s) ** 2 + (dy / ry) ** 2)
            cov = np.clip((1.0 - e) * s + 0.5, 0, 1)
        elif shape == "streak":
            vx, vy = vel
            n = math.hypot(vx, vy) or 1.0
            ux, uy = vx / n, vy / n
            along = dx * ux + dy * uy
            across = -dx * uy + dy * ux
            cov = np.exp(-(along ** 2) / (2 * (s * 1.6) ** 2) - (across ** 2) / (2 * (s * 0.35) ** 2))
        else:
            raise ValueError(shape)
        cov = np.clip(cov * a, 0, 1)
        if edge is not None:
            # A darker rim, drawn first, so the mote reads on light ground.
            rim = np.clip(ndi.grey_dilation(cov, size=(3, 3)) - cov, 0, 1)
            self.paint(layer, x, y, rim * 0.8, edge, x0, y0)
        self.paint(layer, x, y, cov, color, x0, y0)

    def opacity(self, k):
        self.alpha = self.alpha * k

    def compose(self):
        a = self.alpha[..., None]
        sprite = np.dstack([np.clip(self.col, 0, 1) * a, a])
        out = sprite + self.behind * (1 - a)
        out = self.front + out * (1 - self.front[..., 3:4])
        # Light and motes fade out before the frame's edge, never cut by it.
        e = np.minimum(np.minimum(self.motion.x, FRAME - 1 - self.motion.x),
                       np.minimum(self.motion.y, FRAME - 1 - self.motion.y))
        out = out * smoothstep(e, 0.0, 14.0)[..., None]
        return np.clip(out, 0.0, 1.0)


def to_image(premul):
    a = premul[..., 3:4]
    col = premul[..., :3] / np.maximum(a, 1e-4)
    rgba = np.dstack([col, a])
    rgba[a[..., 0] < 1 / 255] = 0
    return Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


# ---------------------------------------------------------------------------
# The family: where each sits on the card, and how each idles

def scatter(b, n, seed, box):
    """n fixed points spread over a region of the creature's box."""
    rng = np.random.default_rng(seed)
    u0, v0, u1, v1 = box
    return [b.at(u0 + (u1 - u0) * rng.random(), v0 + (v1 - v0) * rng.random()) for _ in range(n)]


# Each idle is called twice a frame: first without `fr` for how the body
# moves, then with the moved frame to light it and set motes around it.

def lightning(b, f, fr=None):
    if fr is None:
        m = Motion()
        breathe(m, b, f)
        return m
    bolts = fr.warp(b.mask(hue=(30, 70), sat=(0.2, None), val=(0.6, None)))
    glow(fr, bolts, f, rgb(255, 226, 110), core=rgb(255, 246, 190))
    orb = b.at(0.885, 0.6)
    r = b.size(0.075)
    ends = [
        (b.at(0.08, 0.03), b.at(0.02, -0.04)),
        (b.at(0.40, 0.03), b.at(0.47, -0.05)),
        (b.at(0.70, 0.18), b.at(0.80, 0.12)),
        ((orb[0] + r * 0.9, orb[1] - r * 0.5), (orb[0] + r * 1.9, orb[1] - r * 1.4)),
        ((orb[0] - r * 0.2, orb[1] - r * 0.95), (orb[0] + r * 0.3, orb[1] - r * 2.1)),
        ((orb[0] + r * 0.6, orb[1] + r * 0.8), (orb[0] + r * 1.7, orb[1] + r * 1.5)),
    ]
    arcs(fr, f, ends, rgb(255, 236, 130), seed=3, per_frame=2 if f != 2 else 3)


def mud(b, f, fr=None):
    if fr is None:
        m = Motion()
        breathe(m, b, f, rise=0.016, narrow=0.008)
        return m
    cap = fr.warp(b.mask(val=(None, 0.42), box=(0, 0, 1, 0.32)))
    tint(fr, cap, f, rgb(255, 235, 200), levels=(0.1, 0.3, 0.55, 0.3), amount=0.18)
    drip(fr, *b.lowest((0.15, 0.5, 0.45, 0.68)), f, rgb(128, 88, 54), r=8.5, fall=58,
         shade=rgb(70, 46, 28))
    drip(fr, *b.lowest((0.85, 0.5, 1.0, 0.8)), f, rgb(100, 66, 40), r=6.5, fall=46,
         shade=rgb(56, 36, 20), offset=2)


def ice(b, f, fr=None):
    if fr is None:
        m = Motion()
        breathe(m, b, f, rise=0.008, narrow=0.003)
        return m
    cubes = fr.warp(b.mask(box=(0, 0, 1, 0.5), val=(0.8, None)))
    glow(fr, cubes, f, rgb(160, 230, 255), core=rgb(235, 250, 255), heat=(0.0, 0.12),
         halo=0.55, spill=0.25)


def dust(b, f, fr=None):
    if fr is None:
        m = Motion()
        breathe(m, b, f, rise=0.010, narrow=0.006)
        sway(m, b, f, amp=9.0, pivot=0.25, top=0.0, wave=1.6,
             where=b.mask(box=(0.45, 0, 0.85, 0.3), soft=4))
        return m


def crystal(b, f, fr=None):
    if fr is None:
        m = Motion()
        breathe(m, b, f)
        return m
    gems = b.mask(hue=(265, 330), sat=(0.18, None), val=(0.62, None))
    gems = gems * (1 - b.mask(box=(0.0, 0.5, 0.45, 0.62)))
    glow(fr, fr.warp(gems), f, rgb(225, 160, 255), core=rgb(255, 235, 255), heat=(0.04, 0.2),
         halo=0.8, spill=0.35)


def plant(b, f, fr=None):
    if fr is None:
        m = Motion()
        breathe(m, b, f)
        sway(m, b, f, amp=5.5, pivot=0.42, top=0.0, wave=1.0)
        return m


def _fire_parts(b):
    head = b.mask(box=(0, 0, 1, 0.52)) * smoothstep(-b.v, -0.50, -0.30)
    tail = b.mask(box=(0.72, 0.55, 1.0, 0.92))
    return np.clip(ndi.gaussian_filter(head + tail, 3), 0, 1)


def fire(b, f, fr=None):
    if fr is None:
        m = Motion()
        breathe(m, b, f)
        flicker(m, b, f, _fire_parts(b), amp=3.2, waves=3.0, lift=2.5)
        return m
    flames = fr.warp(b.mask(hue=(15, 60), val=(0.85, None)) * _fire_parts(b))
    glow(fr, flames, f, rgb(255, 160, 70), core=rgb(255, 232, 160), heat=(0.04, 0.16),
         halo=1.0, spill=0.3)
    tops = b.points(b.mask(box=(0.05, 0.0, 0.95, 0.3)) * _fire_parts(b), 12, seed=51, min_gap=18)
    tops += b.points(b.mask(box=(0.75, 0.55, 1.0, 0.7)), 3, seed=52, min_gap=10)
    motes(fr, f, tops, rgb(255, 214, 110), rise=(4, -75), size=2.7, shape="streak",
          seed=53, alpha=1.0, wobble=7)
    motes(fr, f, tops[::2], rgb(255, 245, 200), rise=(4, -75), size=1.2, shape="disc",
          seed=53, alpha=1.0, wobble=7)


def water(b, f, fr=None):
    if fr is None:
        m = Motion()
        breathe(m, b, f)
        sway(m, b, f, amp=3.5, pivot=0.42, top=0.0, wave=1.4)
        return m


def hover(b, box):
    """A soft region of the frame (not just the creature) to lift."""
    u0, v0, u1, v1 = box
    m = ((b.u >= u0) & (b.u <= u1) & (b.v >= v0) & (b.v <= v1)).astype(np.float32)
    return ndi.gaussian_filter(m, 2.5)


def earth(b, f, fr=None):
    if fr is None:
        m = Motion()
        breathe(m, b, f, rise=0.007, narrow=0.003)
        # Its stones hover a little off it, each on its own beat.
        # The lifted regions run past each stone's outer edges (open air), so
        # only the seam where a stone meets the head stretches.
        flap(m, b, f, hover(b, (0.34, -0.2, 0.60, 0.09)), amp=5.0)
        flap(m, b, f, hover(b, (-0.2, -0.2, 0.36, 0.17)), amp=2.5, phase=0.5)
        flap(m, b, f, hover(b, (0.78, 0.30, 1.2, 0.53)), amp=4.5, phase=0.25)
        return m
    eyes = fr.warp(b.mask(hue=(15, 50), sat=(0.45, None), val=(0.55, None), box=(0.05, 0.4, 0.5, 0.58)))
    glow(fr, eyes, f, rgb(255, 170, 70), heat=(0.0, 0.25), halo=0.45, spill=0.2, reach=0.5)


def air(b, f, fr=None):
    if fr is None:
        m = Motion()
        bob(m, b, f, px=4.0)
        flap(m, b, f, b.mask(box=(0.0, 0.05, 0.32, 0.4), soft=6), amp=6.0)
        flap(m, b, f, b.mask(box=(0.62, 0.05, 1.0, 0.42), soft=6), amp=6.0)
        return m


def _steam_ring(b):
    return b.mask(lum=(0.72, None), sat=(None, 0.35), box=(0, 0, 1, 0.65), soft=3)


def steam(b, f, fr=None):
    if fr is None:
        m = Motion()
        breathe(m, b, f)
        ring = _steam_ring(b)
        # The ring is steam held under pressure: it swells with the breath,
        # and its clouds keep churning.
        swell(m, b, f, b.at(0.47, 0.40), k=0.03, where=ring)
        boil(m, b, f, np.clip(ndi.gaussian_filter(ndi.grey_dilation(ring, size=(9, 9)), 3), 0, 1),
             amp=2.6, scale=15.0)
        sway(m, b, f, amp=3.0, pivot=0.62, top=0.0, wave=1.0, where=ring)
        return m
    # Wisps curl up off the outer sides of the ring, where there's room above.
    ring = fr.warp(b.mask(lum=(0.72, None), sat=(None, 0.35), box=(0, 0, 1, 0.65)))
    above = np.clip(ring - np.roll(ring, 5, axis=0), 0, 1)
    sides = (b.u < 0.24) | (b.u > 0.76)
    lips = above * sides * (b.v > 0.12)
    licks(fr, f, rgb(246, 249, 253), source=lips, reach=2.5, height=b.size(0.10),
          strength=1.6, wobble=6.0, soft=2.0, cap=0.65)


def lava(b, f, fr=None):
    if fr is None:
        m = Motion()
        breathe(m, b, f)
        return m
    cracks = fr.warp(b.mask(hue=(345, 45), sat=(0.45, None), val=(0.45, None)))
    glow(fr, cracks, f, rgb(255, 110, 40), core=rgb(255, 215, 130), heat=(0.1, 0.35),
         halo=0.9, spill=0.45, reach=0.8)
    embers = scatter(b, 12, 101, (0.12, -0.02, 0.78, 0.3))
    motes(fr, f, embers, rgb(255, 150, 60), rise=(0, -90), size=2.0, shape="streak",
          seed=102, alpha=1.0, wobble=8)


def poison(b, f, fr=None):
    if fr is None:
        m = Motion()
        breathe(m, b, f)
        return m
    tips = fr.warp(b.mask(hue=(295, 345), sat=(0.25, None), val=(0.75, None)))
    glow(fr, tips, f, rgb(235, 120, 255), core=rgb(255, 205, 255), heat=(0.04, 0.2),
         halo=0.75, spill=0.3)
    eyes = fr.warp(b.mask(hue=(80, 160), sat=(0.25, None), val=(0.6, None), box=(0.1, 0.5, 0.45, 0.62)))
    glow(fr, eyes, f, rgb(170, 255, 140), heat=(0.05, 0.25), halo=0.4, spill=0.2, reach=0.5)
    drip(fr, *b.lowest((0.15, 0.6, 0.45, 0.76)), f, rgb(232, 112, 232), r=5.0, fall=50,
         shade=rgb(116, 36, 136))


def spirit(b, f, fr=None):
    if fr is None:
        m = Motion()
        bob(m, b, f, px=6.0)
        sway(m, b, f, amp=4.0, pivot=0.45, top=0.0, wave=1.5, where=b.mask(box=(0.55, 0, 1, 0.5), soft=5))
        sway(m, b, f, amp=5.0, pivot=0.78, top=1.0, wave=1.5, phase=0.25)
        return m
    fr.opacity(0.9 + 0.07 * math.cos(2 * math.pi * PHASE[f]))
    eyes = fr.warp(b.mask(hue=(170, 205), sat=(0.35, None), val=(0.7, None), box=(0, 0.5, 0.6, 0.66)))
    glow(fr, eyes, f, rgb(110, 240, 255), core=rgb(225, 255, 255), heat=(0.1, 0.3),
         halo=0.9, spill=0.35, reach=0.7)
    tint(fr, fr.warp(b.mask()), f, rgb(170, 245, 255), levels=(0.2, 0.45, 0.7, 0.45), amount=0.25)
    aura(fr, f, rgb(140, 238, 255), levels=(0.55, 0.8, 1.0, 0.8), reach=9, strength=0.6)


def dark(b, f, fr=None):
    if fr is None:
        m = Motion()
        breathe(m, b, f)
        sway(m, b, f, amp=4.0, pivot=0.3, top=0.0, wave=1.2)
        flap(m, b, f, b.mask(box=(0.7, 0.35, 1.0, 0.85), soft=6), amp=5.0, phase=0.25)
        return m
    licks(fr, f, rgb(46, 18, 78), rim=rgb(150, 90, 230), reach=3.5, height=b.size(0.15),
          strength=1.15)
    collar = fr.warp(b.mask(hue=(215, 250), sat=(0.3, None), val=(0.5, None), box=(0.25, 0.6, 0.5, 0.8)))
    glow(fr, collar, f, rgb(120, 140, 255), heat=(0.02, 0.18), halo=0.5, spill=0.2, reach=0.6)


def light(b, f, fr=None):
    if fr is None:
        m = Motion()
        breathe(m, b, f)
        return m
    crest = fr.warp(b.mask(box=(0, 0, 1, 0.66)))
    glow(fr, crest, f, rgb(255, 228, 130), core=rgb(255, 250, 225), heat=(0.0, 0.14),
         halo=0.7, spill=0.2)


def blood(b, f, fr=None):
    if fr is None:
        m = Motion()
        heartbeat(m, b, f)
        return m
    beat = (0.15, 1.0, 0.5, 0.1)
    aura(fr, f, rgb(200, 20, 35), levels=beat, reach=8, strength=0.75)
    shine = fr.warp(b.mask(lum=(0.45, None)))
    tint(fr, shine, f, rgb(255, 225, 225), levels=beat, amount=0.4)
    drip(fr, *b.lowest((0.02, 0.62, 0.3, 0.86)), f, rgb(176, 16, 28), r=5.5, fall=56,
         shade=rgb(92, 6, 14))


CREATURES = {
    # name: (where it stands on the card, how it idles)
    "lightning": ((164, 48, 578, 595), lightning),
    "mud": ((818, 120, 1136, 597), mud),
    "ice": ((1345, 113, 1777, 600), ice),
    "dust": ((1988, 59, 2331, 604), dust),
    "crystal": ((2512, 52, 2910, 598), crystal),
    "plant": ((3152, 73, 3587, 601), plant),
    "fire": ((125, 752, 550, 1306), fire),
    "water": ((770, 792, 1197, 1310), water),
    "earth": ((1386, 828, 1785, 1305), earth),
    "air": ((1916, 821, 2389, 1301), air),
    "steam": ((2499, 747, 2960, 1312), steam),
    "lava": ((3171, 812, 3537, 1307), lava),
    "poison": ((123, 1480, 566, 2013), poison),
    "spirit": ((824, 1472, 1126, 1986), spirit),
    "dark": ((1402, 1475, 1841, 2024), dark),
    "light": ((1964, 1490, 2325, 2024), light),
    "blood": ((2552, 1487, 2922, 2037), blood),
}


def build(name, contact=None):
    box, idle = CREATURES[name]
    card = Image.open(CARD).convert("RGB")
    pad = 40
    crop = card.crop((box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad))
    premul, where = place(cut_out(np.asarray(crop)))
    b = Body(premul, where)
    frames = []
    for f in range(FRAMES):
        motion = idle(b, f)
        fr = Frame(b, f, motion)
        idle(b, f, fr)
        frames.append(to_image(fr.compose()))
    return frames


def save(name, frames):
    out = os.path.join(HERE, name)
    sheet = Image.new("RGBA", (FRAME * FRAMES, FRAME))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * FRAME, 0))
    sheet.save(out + "_spritesheet.png", optimize=True)
    frames[0].save(out + ".png", optimize=True)
    shown = []
    for f in frames:
        bg = Image.new("RGBA", f.size, (146, 146, 146, 255))
        bg.alpha_composite(f)
        shown.append(bg.convert("RGB"))
    shown[0].save(out + "_preview.gif", save_all=True, append_images=shown[1:],
                  duration=120, loop=0, disposal=1)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("names", nargs="*", help="which to build (default: all)")
    ap.add_argument("--contact", metavar="PNG", help="also write a contact sheet here")
    ap.add_argument("--dry", action="store_true", help="contact sheet only, write nothing else")
    args = ap.parse_args()
    names = args.names or list(CREATURES)
    rows = []
    for name in names:
        frames = build(name)
        if not args.dry:
            save(name, frames)
        rows.append(frames)
        print("built", name)
    if args.contact:
        grounds = [(146, 146, 146), (16, 19, 27)]
        sheet = Image.new("RGB", (FRAME * FRAMES * len(grounds), FRAME * len(rows)))
        for r, frames in enumerate(rows):
            for g, ground in enumerate(grounds):
                for i, fimg in enumerate(frames):
                    bg = Image.new("RGBA", (FRAME, FRAME), ground + (255,))
                    bg.alpha_composite(fimg)
                    sheet.paste(bg.convert("RGB"), ((g * FRAMES + i) * FRAME, r * FRAME))
        sheet.save(args.contact)


if __name__ == "__main__":
    main()
