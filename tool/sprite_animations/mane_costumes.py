"""Costume fits for the Manes: frame-0 placements (px on the 1200 frame) and the fit in each
of the 8 idle frames, moved with the head by the idle's own body motion (one shared move per
frame, so all three costumes travel together). Rewrites the MAN rows of costume_fits.dart."""
import sys, re, math
S = sys.argv[1]
src = open(S + '/manes2_build.py').read()
ns = {'__name__': 'x'}
sys.argv = ['x', S, 'none']
exec(src[:src.index("ids = ONLY or sorted(P)")], ns)
P, M, disp = ns['P'], ns['M'], ns['disp']
# eyes (far, near) and where a hat sits (px)
EYES = {
    'MAN01': ((337, 605), (510, 600)), 'MAN02': ((330, 610), (495, 597)), 'MAN03': ((318, 570), (517, 572)),
    'MAN04': ((325, 575), (517, 578)), 'MAN05': ((340, 515), (458, 512)), 'MAN06': ((330, 590), (470, 585)),
    'MAN07': ((330, 600), (520, 592)), 'MAN08': ((345, 590), (515, 580)), 'MAN09': ((340, 607), (497, 602)),
    'MAN10': ((333, 612), (522, 605)), 'MAN11': ((340, 600), (510, 598)), 'MAN12': ((328, 592), (520, 592)),
    'MAN13': ((318, 632), (470, 625)), 'MAN14': ((327, 598), (515, 605)), 'MAN15': ((335, 625), (520, 615)),
    'MAN16': ((333, 620), (513, 610)), 'MAN17': ((330, 605), (515, 605)), 'MAN18': ((310, 612), (520, 605)),
}
HAT = {
    'MAN01': (540, 130), 'MAN02': (450, 330), 'MAN03': (430, 200), 'MAN04': (480, 200), 'MAN05': (480, 75),
    'MAN06': (440, 190), 'MAN07': (470, 330), 'MAN08': (560, 215), 'MAN09': (440, 200), 'MAN10': (560, 270),
    'MAN11': (430, 110), 'MAN12': (510, 130), 'MAN13': (470, 320), 'MAN14': (560, 160), 'MAN15': (480, 110),
    'MAN16': (480, 290), 'MAN17': (500, 270), 'MAN18': (410, 230),
}
HAT.update(eval(open(S + '/mane_hat_override.txt').read()) if __import__('os').path.exists(S + '/mane_hat_override.txt') else {})
NOSE = {}
if __import__('os').path.exists(S + '/mane_nose_override.txt'):
    NOSE.update(eval(open(S + '/mane_nose_override.txt').read()))


def move(hid, x, y, k):
    p, cfg = P[hid], M[hid]
    t = 2 * math.pi * k / 8
    a, b = disp(p, x, y, t), disp(p, x, y, 0.0)
    g = cfg.get('body', 1.5)
    dx, dy = (a[0] - b[0]) * g, (a[1] - b[1]) * g
    if cfg.get('jelly'):
        s = 0.012 * math.sin(t + 0.5)
        sm = lambda v: (lambda q: q * q * (3 - 2 * q))(max(0.0, min(1.0, v)))
        dx += (x - p['neck'][0]) * s * sm((p['foot'] - y) / 500)
        dy += -(p['foot'] - y) * s * 0.9
        s0 = 0.012 * math.sin(0.5)          # the jelly is not at rest in frame 0: take frame 0's own out
        dx -= (x - p['neck'][0]) * s0 * sm((p['foot'] - y) / 500)
        dy -= -(p['foot'] - y) * s0 * 0.9
    return dx, dy


place, frames = {'partyHat': {}, 'nose': {}, 'sunglasses': {}}, {'partyHat': {}, 'nose': {}, 'sunglasses': {}}
for hid in sorted(EYES):
    (ax, ay), (bx, by) = EYES[hid]
    mx, my = (ax + bx) / 2, (ay + by) / 2
    d = math.hypot(bx - ax, by - ay)
    nose = NOSE.get(hid, (mx - 0.20 * d, my + 0.42 * d))
    pts = {'partyHat': (HAT[hid][0], HAT[hid][1], 0.2), 'nose': (nose[0], nose[1], 0.03), 'sunglasses': (mx, my, d / 1200)}
    mv = []
    for k in range(8):
        ms = [move(hid, pts[c][0], pts[c][1], k) for c in pts]
        mv.append((sum(m[0] for m in ms) / 3 / 1200, sum(m[1] for m in ms) / 3 / 1200))
    for c, (x, y, size) in pts.items():
        place[c][hid] = (round(x / 1200, 3), round(y / 1200, 3), round(size, 3))
        frames[c][hid] = [(round(place[c][hid][0] + mv[k][0], 3), round(place[c][hid][1] + mv[k][1], 3), 0.0) for k in range(8)]

pth = 'lib/models/costume_fits.dart'
s = open(pth).read()
# drop any MAN rows already there
s = re.sub(r"    'MAN\d\d': \([-\d., ]+\),\n", '', s)
s = re.sub(r"    'MAN\d\d': \[\n(?:      \(.*\),\n)+    \],\n", '', s)
a = s.index('const _frameFits')
head, tail = s[:a], s[a:]
for c in place:
    key = '  FamilyCostume.%s: {\n' % c
    rows = ''.join("    '%s': (%s, %s, %s),\n" % ((h,) + tuple(repr(v) for v in place[c][h])) for h in sorted(place[c]))
    i = head.index(key) + len(key)
    head = head[:i] + rows + head[i:]
    rows = ''.join("    '%s': [\n%s    ],\n" % (h, ''.join('      (%r, %r, %r),\n' % f for f in frames[c][h])) for h in sorted(frames[c]))
    i = tail.index(key) + len(key)
    tail = tail[:i] + rows + tail[i:]
open(pth, 'w').write(head + tail)
print('wrote', len(EYES), 'Manes x 3 costumes')
