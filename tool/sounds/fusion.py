"""Fusion: the breed tab's merge, the eruption cinematic, and a wild fusion's
calibrate / pour / recoil."""
import json
import math

import numpy as np

from sounds.core import ROOT, SR, Mix, smooth

# ===========================================================================
# Fusion -- the breed tab's merge (FusionParticleField) and the eruption
# cinematic that follows it (FusionBurstField)
# ===========================================================================
#
# Two cues, because they are two screens: the merge runs on the live chamber,
# then the cinematic route opens ~0.15 s after it ends. The merge's tail rings
# across that seam into the eruption's knot.
#
# Both are scored from motion, as the ceremony is. The merge is MEASURED from
# the real field (tool/sound_scores/measure_fusion_merge_test.dart writes the
# JSON read here); the eruption's few lines of motion are ported below.

MERGE_LEN = 2.6          # FusionParticleField.duration
MERGE_BLOOM = 2.5        # the cloud is gone into the orb: _collapseEnd


def _merge_motion():
    data = json.loads(
        (ROOT / 'tool/sound_scores/fusion_merge_motion.json').read_text())
    t = np.array(data['t'])
    speed = np.array(data['speed'])
    born = np.array(data['born'])
    return t, speed / speed.max(), born / born.max()


def _merge(m, start, end, glints_until=0.95):
    """The merge between field seconds [start] and [end], laid into [m] from
    its time zero. The breed tab plays it whole; a wild fusion plays it in
    two pieces either side of its verdict (ParticleFusionEffect calibrates to
    0.62, holds, then fuses on to the end)."""
    mt, speed, born = _merge_motion()

    def window(curve):
        # Field time = cue time + start; nothing outside [start, end].
        def f(t):
            ft = t + start
            return np.where((ft >= start) & (ft <= end),
                            np.interp(ft, mt, curve, right=0), 0)
        return f

    for side_i, side in enumerate((-1.0, 1.0)):  # A left, B right
        sp, bn = speed[side_i], born[side_i]
        # How far this side's grains have travelled toward the orb.
        poured = np.cumsum(sp) / max(np.sum(sp), 1e-9)
        phase = 0.0 if side < 0 else math.pi

        # The sparkle line: grains being made, fine and bright.
        m.grains(window(1400 * bn), lambda t: 0.92 + 0 * t,
                 lambda t, side=side: side * 0.6 + 0 * t, amp=0.5,
                 weight=lambda t: 0.5 + 0 * t)
        # Standing grains glint now and then, for as long as they stand.
        m.grains(lambda t: np.where((t + start > 0.5) & (t + start < glints_until),
                                    35 * np.clip((glints_until - t - start) / 0.3, 0, 1), 0),
                 lambda t: 0.95 + 0 * t,
                 lambda t, side=side: side * 0.6 + 0 * t, amp=0.5,
                 weight=lambda t: 0.4 + 0 * t)

        def pan(t, poured=poured, side=side, phase=phase):
            # Over the gap to the orb, then circling it: the two clouds turn
            # opposite ways.
            ft = t + start
            p = np.interp(ft, mt, poured)
            orbit = 0.25 * np.sin(2 * math.pi * 0.9 * ft + phase) * p
            return side * 0.6 * (1 - p) + side * orbit

        m.grains(window(2600 * sp),
                 window(0.7 + 0.15 * smooth(mt, 2.15, 2.45)),
                 pan, amp=0.5, weight=window(0.5 + 0.4 * sp))

    if end >= MERGE_BLOOM:
        # The whole of it stops dead at the bloom (the field does): no stream
        # trails past the moment the cloud is gone.
        bloom = MERGE_BLOOM - start
        m.y *= np.clip((bloom + 0.03 - m.t) / 0.03, 0, 1)
        if start < 0.85 + 1.4:
            m.air(max(0.0, 0.85 - start), 1.4 - max(0.0, start - 0.85),
                  260, 2200, amp=0.03, rise=0.6)
        m.air(2.05 - start, 0.5, 300, 2600, amp=0.05, rise=0.85)
        # The bloom: the orb takes both and glows. A glass that swells.
        m.glass(bloom - 0.04, 310, amp=0.12, ring=1.6, attack=0.09,
                brightness=0.4, beat=0.9, ratios=[1.0, 2.19, 3.89, 5.91])


def fusion_merge():
    """Two specimens turn to grains and pour into the orb (the breed tab).

    0.05 - 0.52  a sparkle line runs down each, turning it to grains
    0.52 - 0.9   they stand, loose and glinting
    0.9  - 1.45  the pour: grains arc over the gap, faster and faster
    1.6  - 2.15  one cloud orbiting the orb
    2.2  - 2.5   it spins up and falls in, then is simply gone: the bloom
    """
    m = Mix(MERGE_LEN + 0.55, seed=4301)
    _merge(m, 0.0, MERGE_LEN)
    m.room(t60=1.2, wet=0.22)
    return m.finish(loudness_db=-29.0, fade_out=0.3)


# A wild fusion: the catalyst is spent, the pair calibrate (turn to grains
# and stand, 0.6 s), the roll is waited on (650 ms) and the panel gets out of
# the way (260 ms) before they fuse -- so they stand ~0.9 s past the
# calibration, glinting.
WILD_STAND = 0.62
WILD_HOLD = 0.9


def fusion_calibrate():
    """The catalyst spent: both turn to grains where they stand, and wait."""
    m = Mix(WILD_STAND + WILD_HOLD + 0.5, seed=4311)
    _merge(m, 0.0, WILD_STAND, glints_until=WILD_STAND + WILD_HOLD + 0.2)
    # The held breath of the verdict.
    m.air(0.3, WILD_HOLD + 0.6, 260, 1800, amp=0.018, rise=0.7)
    m.room(t60=1.0, wet=0.22)
    return m.finish(loudness_db=-32.0, fade_out=0.35)


def fusion_pour():
    """The verdict held: the standing pair pour together and fall in."""
    m = Mix(MERGE_LEN - WILD_STAND + 0.55, seed=4321)
    _merge(m, WILD_STAND, MERGE_LEN)
    m.room(t60=1.2, wet=0.22)
    return m.finish(loudness_db=-29.0, fade_out=0.3)


def fusion_recoil():
    """The verdict failed: the grains run back into the pair (0.62 -> 0 of
    the merge in 0.52 s), and they are themselves again. No glass: nothing
    was made."""
    m = Mix(1.2, seed=4331)
    mt, _, born = _merge_motion()
    rate = WILD_STAND / 0.52
    for side_i, side in enumerate((-1.0, 1.0)):
        bn = born[side_i]
        # Field time runs backward: the crest climbs back up each specimen.
        m.grains(lambda t, bn=bn: np.interp(WILD_STAND - t * rate, mt, 1400 * bn,
                                            left=0, right=0) * (t * rate <= WILD_STAND),
                 lambda t: 0.8 - 0.25 * smooth(t, 0.0, 0.52),
                 lambda t, side=side: side * 0.6 + 0 * t, amp=0.5,
                 weight=lambda t: 0.5 + 0 * t)
        # Whole again: a brief coarse settle as each body takes its grains.
        m.grains(lambda t: np.where(t > 0.4, 900 * np.exp(-(t - 0.4) / 0.09), 0),
                 lambda t: 0.25 + 0 * t,
                 lambda t, side=side: side * 0.6 + 0 * t, amp=0.5,
                 weight=lambda t: 0.6 + 0 * t)
    m.air(0.0, 0.75, 220, 1400, amp=0.04, rise=0.2)
    m.room(t60=0.9, wet=0.2)
    return m.finish(loudness_db=-31.0, fade_out=0.3)


def _eruption_motion(u, radius=70.0, n=2600):
    """FusionBurstField's motion, ported (fusion_burst.dart _seed + paint):
    per-role speed in px/s, and how many sigil grains are glinting."""
    rng = np.random.default_rng(29)
    ph = rng.random(n)
    direction = rng.random(n) * 2 * np.pi
    lobe = rng.random() * 2 * np.pi
    lobes = (0.85 + 0.2 * np.sin(direction * 2 + lobe)
             + 0.12 * np.sin(direction * 3 + lobe * 1.7)
             + 0.08 * np.sin(direction * 5 + lobe * 2.3)
             + 0.12 * (rng.random(n) - 0.5))
    dist = radius * (0.25 + 2.5 * rng.random(n) ** 1.3) * lobes
    knot_r = radius * 0.32 * (0.2 + 0.8 * np.sqrt(rng.random(n)))
    r = rng.random(n)
    role = np.where(r < 0.2, 2, np.where(r < 0.42, 1, 0))  # ember, sigil, shell
    lat = np.arcsin(rng.random(n) * 2 - 1)
    lon0 = rng.random(n) * 2 * np.pi
    omega = 0.5 + 0.7 * rng.random(n)
    shell_r = radius * (0.86 + 0.14 * rng.random(n))
    along = rng.random(n)
    gather = np.where(role == 1, 0.9 + along * 0.45, 0.68 + rng.random(n) * 0.4)
    burst_at, gather_dur, lock_from, lock_end, sigil_from = 0.45, 0.55, 1.55, 2.0, 0.9

    def clamp(x):
        return np.clip(x, 0, 1)

    def ease(x):
        return np.where(x < 0.5, 4 * x ** 3, 1 - (-2 * x + 2) ** 3 / 2)

    def pos(v):
        heat = min(1.0, v / burst_at)
        bt = v - burst_at
        if bt <= 0:
            pulse = 1 + 0.12 * heat * math.sin(v * 30)
            a = direction + v * (6 + 4 * ph)
            rr = knot_r * pulse * (1 - 0.45 * heat)
            shiver = heat * 1.6 * np.sin(v * 50 + ph * 40)
            return np.cos(a) * rr + shiver, np.sin(a) * rr * 0.85
        out = 1 - math.exp(-6 * bt)
        a = direction + 0.35 * out
        rr = knot_r + dist * out
        bx, by = np.cos(a) * rr, np.sin(a) * rr
        drift = max(0.0, bt - 0.4) * 22
        swirl = (1 - float(smooth(np.array(v), sigil_from, lock_end))) * np.pi * 1.25
        sa = along * 2 * np.pi + swirl
        lon = lon0 + omega * v
        c = np.cos(lat)
        px, py, pz = shell_r * c * np.cos(lon), shell_r * np.sin(lat), shell_r * c * np.sin(lon)
        hx = np.where(role == 1, np.cos(sa) * radius * 0.7, px)
        hy = np.where(role == 1, np.sin(sa) * radius * 0.7,
                      py * math.cos(0.3) + pz * math.sin(0.3))
        g = clamp((v - gather) / gather_dur)
        e = ease(g)
        bend = np.sin(np.pi * g) * radius * 0.35 * (ph - 0.5)
        dx, dy = hx - bx, hy - by
        length = np.sqrt(dx * dx + dy * dy) + 1e-3
        x = bx + dx * e - dy / length * bend
        y = by + dy * e + dx / length * bend
        x = np.where(role == 2, bx + np.cos(a) * drift, x)
        y = np.where(role == 2, by + np.sin(a) * drift - drift * 0.4, y)
        return x, y

    curves = {k: np.zeros(len(u)) for k in ('knot', 'thrown', 'gather', 'embers', 'glint')}
    dt = u[1] - u[0]
    px, py = pos(u[0])
    for j, v in enumerate(u):
        x, y = pos(v)
        sp = np.sqrt((x - px) ** 2 + (y - py) ** 2) / dt
        px, py = x, y
        if v <= burst_at:
            curves['knot'][j] = sp.mean()
            continue
        g = clamp((v - gather) / gather_dur)
        ember_vis = 1 - min(1.0, max(0.0, (v - 0.9) / 0.8))
        curves['thrown'][j] = np.sum(sp * ((g <= 0) & (role != 2))) / n
        curves['gather'][j] = np.sum(sp * ((g > 0) & (g < 1) & (role != 2))) / n
        curves['embers'][j] = np.sum(sp * (role == 2)) / n * ember_vis
        lock = float(smooth(np.array(v), lock_from, lock_end))
        landed = np.sum((role == 1) & (g >= 1)) / n
        curves['glint'][j] = landed * (0.3 * (1 - lock) if 0 < lock < 1 else 0.012)
    return {k: c / max(c.max(), 1e-9) for k, c in curves.items()}


ERUPT_BURST = 0.45       # FusionBurstField.burstAt
ERUPT_LOCK = 1.55        # _lockFrom
ERUPT_CLOSE = 3.13       # route: 2.8 s visible + the 260 ms flash + 70 ms


def fusion_eruption():
    """The cinematic, from the moment its particles take over.

    0    - 0.45  the knot: spinning, tightening, shivering as it heats
    0.45         it erupts: thrown out fast, slowing
    0.7  - 1.85  gathered back into the cultivation; embers drift on and out
    1.55 - 1.95  the sigil locks and glints
    then         it turns slowly until the route closes (~3.1 s)
    """
    tail = 0.6
    m = Mix(ERUPT_CLOSE + tail, seed=4401)
    step = 0.004
    grid = np.arange(0, m.n / SR + step, step)
    c = _eruption_motion(grid)

    def at(curve):
        return lambda t: np.interp(t, grid, curve)

    heat = np.clip(grid / ERUPT_BURST, 0, 1) * (grid <= ERUPT_BURST)
    # The knot's shiver is its pulse: 30 rad/s, as deep as it is hot.
    tremble = 1 + 0.6 * heat * np.sin(grid * 30)
    m.grains(at(1500 * c['knot'] * tremble), at(0.62 + 0.3 * heat),
             lambda t: 0.1 * np.sin(2 * math.pi * 1.6 * t), amp=0.5,
             weight=at(0.45 + 0.35 * heat))

    # Thrown out: wide, mid-weight grains, as fast as the spray. Spread over
    # three streams so it fills the field without stacking into a burst of
    # noise in the middle.
    for side in (-0.75, 0.0, 0.75):
        m.grains(at(750 * c['thrown']), at(0.5 + 0.25 * (1 - c['thrown'])),
                 lambda t, side=side: side + 0 * t, amp=0.5,
                 weight=at(0.55 + 0.35 * c['thrown']))
    # Embers on out, fine and wide, going out.
    for side in (-0.85, 0.85):
        m.grains(at(500 * c['embers']), lambda t: 0.9 + 0 * t,
                 lambda t, side=side: side + 0 * t, amp=0.5,
                 weight=lambda t: 0.45 + 0 * t)

    # Gathered back: in from the edges to the cultivation.
    gathered = np.cumsum(c['gather'])
    gathered /= max(gathered[-1], 1e-9)
    for side in (-1.0, 1.0):
        m.grains(at(1600 * c['gather']), at(0.75 - 0.3 * gathered),
                 lambda t, side=side: side * 0.7 * (1 - np.interp(t, grid, gathered)),
                 amp=0.5, weight=at(0.5 + 0.35 * c['gather']))

    # The sigil's glints as it locks, then now and then while it turns.
    m.grains(at(1300 * c['glint']), lambda t: 0.97 + 0 * t,
             lambda t: 0.3 * np.sin(2 * math.pi * 0.5 * t), amp=0.5,
             weight=lambda t: 0.55 + 0 * t)

    # Air: the heat leaning in, the release of the eruption, a breath under
    # the turning cultivation.
    m.air(0.0, ERUPT_BURST + 0.05, 300, 1800, amp=0.04, rise=0.92)
    # Not a hit: the release leans out over ~80 ms, as a crash never does.
    m.air(ERUPT_BURST - 0.04, 0.75, 250, 2400, amp=0.07, rise=0.11)
    m.air(1.7, ERUPT_CLOSE + tail - 1.7, 300, 2000, amp=0.02, rise=0.3)
    # The heat as a stroked glass under the knot, let go at the eruption.
    m.glass(0.0, 233, amp=0.05, ring=0.9, attack=0.4, brightness=0.2,
            beat=1.6, ratios=[1.0, 2.32, 4.25])
    # The cultivation's own glass, blooming under the lock. Kept below the
    # glints: a bright glass on top of a climax is a chime.
    m.glass(ERUPT_LOCK - 0.05, 392, amp=0.075, ring=2.4, attack=0.32,
            brightness=0.35, beat=1.4)
    m.room(t60=1.3, wet=0.24)
    return m.finish(loudness_db=-28.0, fade_out=0.45)


CUES = {
    'sfx_fusion_calibrate': (
        fusion_calibrate,
        'A wild fusion\'s catalyst spent: both turn to grains where they stand and glint while the verdict is out',
    ),
    'sfx_fusion_pour': (
        fusion_pour,
        'The verdict held: the standing pair pour together, circle and fall in to a bloom',
    ),
    'sfx_fusion_recoil': (
        fusion_recoil,
        'The verdict failed: the grains run back up into the pair and they settle, whole',
    ),
    'sfx_fusion_merge': (
        fusion_merge,
        'Two specimens turn to grains, pour over the gap and circle the orb, then fall in and bloom',
    ),
    'sfx_fusion_eruption': (
        fusion_eruption,
        'A hot knot shivers, erupts, and is gathered back into a cultivation whose sigil locks with a glint',
    ),
}
