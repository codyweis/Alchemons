"""Cuts one creature out of a concept sheet and builds its 4-frame idle sheet.

The concept art comes as a grid of creatures on a flat grey card. This lifts
one of them off the card (an unmixed matte, so the outline keeps its
anti-aliasing and no grey fringe), fits it to the game's 512px frame the way
the Let sheets sit, and draws four idle frames: a slow breath anchored at the
feet, and the element's own parts glowing up and back down.

    python tool/creature_idle_sheet.py SRC --crop X0,Y0,X1,Y1 --out PREFIX

writes PREFIX.png (the still), PREFIX_spritesheet.png (4 x 512 frames, to be
played at 120 ms a frame like every other sheet) and PREFIX_preview.gif (the
loop on the grey card, for looking at).

The glowing parts are picked by hue: --glow-hue 30,70 is the yellow of
Lightning. Run with NumPy + SciPy + Pillow.
"""
import argparse
import os

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

FRAME = 512
# The Let sheets stand a creature ~448px tall with its feet ~40px off the
# frame's bottom; this leaves the same room, plus a little for the halo.
FIT_HEIGHT = 432
FEET_Y = 474

# One breath and one glow pulse per loop: rest, rising, peak, falling.
BREATH = [0.0, 0.5, 1.0, 0.5]
GLOW = [0.25, 0.6, 1.0, 0.6]


def smoothstep(x, lo, hi):
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def cut_out(rgb):
    """Premultiplied RGBA (float, 0-1) of the creature on a flat card."""
    p = rgb.astype(np.float32) / 255.0
    h, w, _ = p.shape
    border = np.concatenate([p[:6].reshape(-1, 3), p[-6:].reshape(-1, 3),
                             p[:, :6].reshape(-1, 3), p[:, -6:].reshape(-1, 3)])
    bg = np.median(border, axis=0)

    dist = np.abs(p - bg).max(-1)

    # Card is only what is card-coloured AND wide: the line art's own
    # anti-aliasing (black outline into an eye's white, gold outline into a
    # bolt) passes through the card's grey in thin threads, and those belong
    # to the creature. A real gap -- the open card, the loop of a bent arm --
    # holds a patch of flat card grey; a thread only grazes it in passing.
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
    # coloured one -- its own outline, usually: P = a*F + (1-a)*card.
    # The pale gold line round a bolt sits only ~0.15 off the card, and unmixed
    # against the bolt's yellow it would read as card; it has to count here.
    strong = body & (dist > 0.15)
    edge = ndi.binary_dilation(card, iterations=3) & ~strong
    _, (iy, ix) = ndi.distance_transform_edt(~strong, return_indices=True)
    f = p[iy, ix]
    fb = f - bg
    a_edge = ((p - bg) * fb).sum(-1) / np.maximum((fb * fb).sum(-1), 1e-4)
    a_edge = np.clip(a_edge, 0.0, 1.0)
    a_edge[card & (dist < 0.03)] = 0.0

    alpha = np.where(edge, a_edge, body.astype(np.float32)).astype(np.float32)
    # Colour where the edge is mostly card is unreliable; take the outline's.
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


def place(premul):
    """Scales the cut-out to stand in a FRAME x FRAME cell."""
    a = premul[..., 3]
    ys, xs = np.nonzero(a > 0.02)
    premul = premul[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = premul.shape[:2]
    s = FIT_HEIGHT / h
    nw, nh = round(w * s), round(h * s)
    small = resize(premul, (nw, nh))
    cell = np.zeros((FRAME, FRAME, 4), np.float32)
    x0 = (FRAME - nw) // 2
    y0 = FEET_Y - nh
    cell[y0:y0 + nh, x0:x0 + nw] = small
    return cell


def element_mask(premul, hue_lo, hue_hi):
    """How much each pixel belongs to the element's glowing parts (0-1)."""
    a = premul[..., 3]
    c = premul[..., :3] / np.maximum(a, 1e-4)[..., None]
    mx, mn = c.max(-1), c.min(-1)
    chroma = mx - mn
    sat = chroma / np.maximum(mx, 1e-4)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    safe = np.maximum(chroma, 1e-4)
    hue = np.where(mx == r, ((g - b) / safe) % 6,
                   np.where(mx == g, (b - r) / safe + 2, (r - g) / safe + 4)) * 60
    mid = (hue_lo + hue_hi) / 2
    half = (hue_hi - hue_lo) / 2
    in_hue = 1.0 - smoothstep(np.abs(hue - mid), half * 0.7, half)
    return a * in_hue * smoothstep(sat, 0.12, 0.28) * smoothstep(mx, 0.45, 0.7)


def breathe(img, t):
    """Rises a hair at the head and narrows a hair at the waist, feet fixed."""
    sy = 1.0 + 0.010 * t
    sx = 1.0 - 0.004 * t
    cx = FRAME / 2
    # PIL's affine maps output -> input.
    coeffs = (1 / sx, 0, cx - cx / sx, 0, 1 / sy, FEET_Y - FEET_Y / sy)
    if img.ndim == 2:
        return np.asarray(Image.fromarray(img).transform(
            (FRAME, FRAME), Image.AFFINE, coeffs, Image.BICUBIC))
    return np.dstack([breathe(img[..., c], t) for c in range(img.shape[2])])


def blur(x, sigma):
    return ndi.gaussian_filter(x, sigma, mode="constant")


def frame(base, mask, t, g, glow_rgb, core_rgb):
    body = np.clip(breathe(base, t), 0.0, 1.0)
    m = np.clip(breathe(mask, t), 0.0, 1.0)
    a = body[..., 3:4]
    col = body[..., :3] / np.maximum(a, 1e-4)

    # The parts themselves warm toward a hot core, gently enough that their
    # own markings (the orb's cracks) still read at the peak.
    hot = (m * (0.08 + 0.27 * g))[..., None]
    col = col + (core_rgb - col) * hot

    # Light spilling out of them: onto the body nearby, and into the air.
    halo = (blur(m, 5) * 0.9 + blur(m, 14) * 1.2 + blur(m, 30) * 0.8) * g
    spill = (np.clip(halo * 0.5, 0.0, 0.8) * (1.0 - m))[..., None]
    col = 1 - (1 - col) * (1 - glow_rgb * spill)  # screen

    sprite = np.dstack([col * a, a])
    air = np.clip(halo * 0.75, 0.0, 0.8)[..., None]
    behind = np.dstack([glow_rgb * air, air])
    out = sprite + behind * (1 - a)
    return np.clip(out, 0.0, 1.0)


def to_image(premul):
    a = premul[..., 3:4]
    rgb = premul[..., :3] / np.maximum(a, 1e-4)
    rgba = np.dstack([rgb, a])
    rgba[a[..., 0] < 1 / 255] = 0
    return Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src")
    ap.add_argument("--crop", required=True, help="X0,Y0,X1,Y1 in the source")
    ap.add_argument("--out", required=True, help="output path without .png")
    ap.add_argument("--glow-hue", default="30,70", help="hue range, degrees")
    ap.add_argument("--glow-color", default="255,226,110")
    ap.add_argument("--core-color", default="255,246,190")
    ap.add_argument("--card", default="146,146,146", help="preview background")
    args = ap.parse_args()

    box = tuple(int(v) for v in args.crop.split(","))
    hue_lo, hue_hi = (float(v) for v in args.glow_hue.split(","))
    glow_rgb = np.array([int(v) for v in args.glow_color.split(",")], np.float32) / 255
    core_rgb = np.array([int(v) for v in args.core_color.split(",")], np.float32) / 255

    src = np.asarray(Image.open(args.src).convert("RGB").crop(box))
    base = place(cut_out(src))
    mask = element_mask(base, hue_lo, hue_hi).astype(np.float32)

    frames = [to_image(frame(base, mask, t, g, glow_rgb, core_rgb))
              for t, g in zip(BREATH, GLOW)]

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    sheet = Image.new("RGBA", (FRAME * len(frames), FRAME))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * FRAME, 0))
    sheet.save(args.out + "_spritesheet.png", optimize=True)
    frames[0].save(args.out + ".png", optimize=True)

    card = tuple(int(v) for v in args.card.split(","))
    shown = []
    for f in frames:
        bg = Image.new("RGBA", f.size, card + (255,))
        bg.alpha_composite(f)
        shown.append(bg.convert("RGB"))
    shown[0].save(args.out + "_preview.gif", save_all=True, append_images=shown[1:],
                  duration=120, loop=0, disposal=1)
    print("wrote", args.out + "{.png,_spritesheet.png,_preview.gif}")


if __name__ == "__main__":
    main()
