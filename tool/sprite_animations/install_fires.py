"""Install fire sheets (<base>_fire.png): the 10 trial frames in a 4x3 grid at half the
trial's size (combat draws creatures small). Hard-edged families get a 256-colour palette;
the soft-shaded ones (Masks, Kin, Mystics) a palette fitted to their own colours, with a fine
grain so their gradients and glows do not step (FULL=1 keeps them in full colour, about four
times the size; needs numpy and scipy). The species already listed in creature_actions.dart
stay listed: a run installs what its scratch folder holds and adds to them."""
import sys, os, re, json, glob
from PIL import Image
S = sys.argv[1]
SOFT = ('MSK', 'KIN', 'MYS')


def fitted_palette(im, colors=256, rounds=10, dither=2.5):
    """[im] (RGBA) in a palette of its own colours: FASTOCTREE's first guess moved onto the
    colours the sheet really has (by how often each is seen, premultiplied, so the soft edge
    of a glow counts for what shows of it), one entry kept clear, then laid down through a
    fine ordered grain."""
    import numpy as np
    from scipy.spatial import cKDTree
    arr = np.ascontiguousarray(np.asarray(im.convert('RGBA')))
    h, w = arr.shape[:2]
    packed = arr.reshape(-1, 4).view(np.uint32).ravel()
    uniq, inv, cnt = np.unique(packed, return_inverse=True, return_counts=True)
    u = uniq.view(np.uint8).reshape(-1, 4).astype(np.float32)
    pts = np.hstack([u[:, :3] * u[:, 3:4] / 255.0, u[:, 3:4]])
    wts = cnt.astype(np.float64)
    seed = np.ascontiguousarray(np.asarray(im.quantize(colors - 1, method=Image.FASTOCTREE, dither=Image.NONE).convert('RGBA'))).reshape(-1, 4)
    sp = np.unique(seed.view(np.uint32).ravel()).view(np.uint8).reshape(-1, 4).astype(np.float32)
    cen = np.hstack([sp[:, :3] * sp[:, 3:4] / 255.0, sp[:, 3:4]])
    cen = cen[cen[:, 3] > 0][:colors - 1]
    solid = pts[:, 3] > 0
    for _ in range(rounds):
        _, lab = cKDTree(cen).query(pts[solid])
        sums = np.zeros_like(cen, dtype=np.float64)
        np.add.at(sums, lab, pts[solid] * wts[solid][:, None])
        tot = np.bincount(lab, weights=wts[solid], minlength=len(cen))
        live = tot > 0
        cen[live] = (sums[live] / tot[live][:, None]).astype(np.float32)
        if (~live).any():                                       # an unused entry goes to the worst-served colour
            d = np.linalg.norm(pts[solid] - cen[lab], axis=1) * np.sqrt(wts[solid])
            cen[~live] = pts[solid][np.argsort(d)[::-1][:int((~live).sum())]]
    cen = np.vstack([np.zeros((1, 4), np.float32), cen])
    bayer = np.array([[0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26], [12, 44, 4, 36, 14, 46, 6, 38], [60, 28, 52, 20, 62, 30, 54, 22],
                      [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25], [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21]], np.float32)
    grain = (np.tile(bayer, (h // 8 + 1, w // 8 + 1))[:h, :w] / 63.0 - 0.5) * 2 * dither
    full = pts[inv].reshape(h, w, 4)
    seen = full[..., 3] > 0
    _, lab = cKDTree(cen[1:]).query(full[seen] + grain[seen][:, None] * np.array([1, 1, 1, 0.5], np.float32))
    idx = np.zeros((h, w), np.uint8)
    idx[seen] = lab + 1
    rgb = np.clip(np.rint(cen[:, :3] / (np.maximum(cen[:, 3:4], 1e-3) / 255.0)), 0, 255).astype(np.uint8)
    out = Image.fromarray(idx)
    out.putpalette(rgb.tobytes())
    out.info['transparency'] = bytes(int(v) for v in np.clip(np.rint(cen[:, 3]), 0, 255))
    return out


J = {c['id']: c for c in json.load(open('assets/data/alchemons_creatures.json'))['creatures']}
done, total = [], 0
for p in sorted(glob.glob(S + '/actions/*_fire_spritesheet.png')):
    hid = os.path.basename(p)[:5]
    if hid not in J:
        continue
    im = Image.open(p).convert('RGBA')
    F = im.size[0] // 4
    assert im.size == (4 * F, 3 * F), (hid, im.size)
    pm = im          # at the trial's own size: sharp where a battle draws creatures large
    out = 'assets/images/' + J[hid]['image'].replace('.png', '_fire.png')
    if hid.startswith('MAN') or (hid[:3] in SOFT and os.environ.get('FULL')):
        pm.save(out, optimize=True)
    elif hid[:3] in SOFT:
        fitted_palette(pm).save(out, optimize=True)
    else:
        pm.quantize(256, method=Image.FASTOCTREE, dither=Image.NONE).save(out, optimize=True)
    total += os.path.getsize(out)
    done.append(hid)
    # its albino eye layer, through the same motion (512 px a frame: the size an albino is baked at)
    ep = p.replace('_spritesheet.png', '_eyes.png')
    eo = out.replace('.png', '_albino_eyes.png')
    if os.path.exists(ep) and hid != 'LET15':
        e = Image.open(ep).convert('RGBA')
        n = e.size[0] // 4
        k = min(1.0, 512 / n)
        e.convert('RGBa').resize((int(e.size[0] * k), int(e.size[1] * k)), Image.LANCZOS).convert('RGBA').save(eo, optimize=True)
        total += os.path.getsize(eo)
    elif os.path.exists(eo):
        os.remove(eo)
pth = 'lib/widgets/creature_actions.dart'
s = open(pth).read()
a, b = s.index('  // GENERATED: fire species\n'), s.index('  // END GENERATED: fire')
new = len(done)
done = sorted(set(done) | set(re.findall(r"'([A-Z]{3}\d\d)'", s[a:b])))       # with those already listed
rows = [done[i:i + 6] for i in range(0, len(done), 6)]
s = s[:a] + '  // GENERATED: fire species\n' + ''.join('  ' + ', '.join("'%s'" % h for h in r) + ',\n' for r in rows) + s[b:]
open(pth, 'w').write(s)
print(new, 'fire sheets installed,', total // (1024 * 1024), 'MB;', len(done), 'species listed')
