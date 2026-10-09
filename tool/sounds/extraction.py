"""Extraction: the hatch ceremony (HatchingCinematic + HatchShell) and the
result card's reveal (ExtractionResultCard). User-approved 2026-10-04."""
import json
import math

import numpy as np

from sounds.core import ROOT, SR, Mix, smooth

# ===========================================================================
# Extraction reveal -- ExtractionResultCard
# ===========================================================================
#
# What the card shows (ElementalEssence.reveal, from the moment it is let go):
#   * the specimen's element form is already up as grains,
#   * they swirl home along a curve, feet first, cooling from the element's
#     shades into the creature's own colors,
#   * they LAND (the card's lock, below) and the sprite comes back under them.
#
# A rare specimen (new discovery, prismatic, mutation, legendary, mystic) gets
# a held beat of empty, lit stage before the grains appear.
#
# The sound follows that and nothing else: a stream that moves and cools, one
# settle when it lands, the glass the specimen now sits in. No scan, no data,
# no note run.

REVEAL_LAND = 1.20       # ordinary: grains appear at once and land here
RARE_HOLD = 0.57         # rare: the empty lit stage before grains appear
RARE_LAND = RARE_HOLD + REVEAL_LAND


def _reveal(m, appear, land, rare):
    span = land - appear

    def density(t):
        # A soft stream that thickens as it gathers, a quick press at the
        # landing, then the last few grains finding their places.
        gather = smooth(t, appear - 0.05, appear + 0.18) * (
            700 + 2600 * smooth(t, appear, land))
        settle = np.where(t > land, 6500 * np.exp(-(t - land) / 0.13), 0)
        stray = np.where(t > land, 260 * np.exp(-(t - land) / 0.55), 0)
        return np.where(t < land, gather, settle + stray)

    def bright(t):
        # Hot element shades to the creature's own colors: fine to coarse.
        # The settle itself is the coarsest moment: grains on grains.
        cool = 0.78 - 0.42 * smooth(t, appear, land + 0.1)
        return cool - 0.14 * np.exp(-np.abs(t - land - 0.04) / 0.08)

    def pan(t):
        # The swirl home: the stream crosses the field and tightens to centre.
        u = np.clip((t - appear) / span, 0, 1)
        return 0.55 * (1 - u) * np.sin(2 * math.pi * 0.85 * u + 0.6)

    def weight(t):
        # The stream is quiet while it travels; the settle carries the weight.
        travel = 0.75 + 0.45 * smooth(t, appear, land)
        return np.where(t < land, travel, 1.0)

    m.air(appear - 0.04, span + 0.3, 350, 2600, amp=0.05, rise=0.82)
    m.grains(density, bright, pan, amp=0.55, weight=weight)
    # The landing is the grains settling, not a hit: a dense, coarse patter
    # (above) inside a hush that leans in and lets go. No drum, no thump.
    m.air(land - 0.16, 0.62, 220, 1500, amp=0.10 if not rare else 0.13,
          rise=0.28)
    # The glass the specimen now stands in: struck softly, low, short.
    m.glass(land, 452, amp=0.17, ring=1.15, attack=0.006, brightness=0.5,
            pan=-0.08, beat=1.1)
    if rare:
        # A second, larger body under the first: more weight, not more notes.
        m.glass(land + 0.004, 287, amp=0.14, ring=2.0, attack=0.012,
                brightness=0.25, pan=0.1, beat=0.7,
                ratios=[1.0, 2.19, 3.89, 5.91])


def reveal_ordinary():
    m = Mix(2.3, seed=4101)
    _reveal(m, appear=0.0, land=REVEAL_LAND, rare=False)
    m.room(t60=1.0, wet=0.22)
    return m.finish(loudness_db=-29.0, fade_out=0.35)


def reveal_rare():
    m = Mix(3.3, seed=4102)
    # The held beat: the lit stage is charged before anything is on it. A
    # stroked glass, almost under hearing, and a breath that leans in.
    m.glass(0.0, 287, amp=0.05, ring=3.0, attack=0.45, brightness=0.1,
            beat=0.5, ratios=[1.0, 2.19, 3.89])
    m.air(0.0, RARE_HOLD + 0.25, 180, 900, amp=0.07, rise=0.9)
    _reveal(m, appear=RARE_HOLD, land=RARE_LAND, rare=True)
    m.room(t60=1.4, wet=0.25)
    return m.finish(loudness_db=-31.0, fade_out=0.45)  # the quiet held beat pulls the average down


# ===========================================================================
# The card coming apart -- CardDissolve (card_dissolve.dart), on CONTINUE
# ===========================================================================
#
# A ragged edge climbs the card from the foot in DISSOLVE_SWEEP, starting a
# touch slow and picking up (up = 0.35p + 0.65p^2), and every piece it passes
# lifts off on a rising draught, turns into a grain of the specimen's sand
# and thins to nothing within about half a second. All gone by ~0.75 s.
#
# So: grains as many as the edge is letting go, finer as they rise and thin,
# and the draught under them. No whoosh, no hit, no glass -- the specimen has
# already been rung in; this is only its sand going.

DISSOLVE_SWEEP = 0.30


def dissolve():
    m = Mix(1.0, seed=4111)

    def density(t):
        p = np.clip(t / DISSOLVE_SWEEP, 0, 1)
        # The rate the edge passes pieces is d(up)/dp: 0.35 + 1.3p.
        letting_go = np.where(t < DISSOLVE_SWEEP, 1100 * (0.35 + 1.3 * p), 0)
        thinning = np.where(
            t >= DISSOLVE_SWEEP,
            1100 * 1.65 * np.exp(-(t - DISSOLVE_SWEEP) / 0.13), 0)
        return (letting_go + thinning) * smooth(t, 0, 0.03)

    m.grains(density,
             lambda t: 0.42 + 0.48 * smooth(t, 0.0, 0.6),
             lambda t: 0.3 * np.sin(2 * math.pi * 1.3 * t + 0.4),
             amp=0.5, weight=lambda t: 1.0 - 0.55 * smooth(t, 0.25, 0.75))
    m.air(0.0, 0.75, 700, 4400, amp=0.03, rise=0.42)
    m.room(t60=0.8, wet=0.18)
    return m.finish(loudness_db=-32.0, fade_out=0.3)


# ===========================================================================
# Extraction ceremony -- HatchingCinematic + HatchShell
# ===========================================================================
#
# One cue for the whole ceremony, so it cannot drift from itself, and scored
# from the animation's OWN motion: _shell_score() below ports the shell's
# per-strand timing (the same hash, constants and easings as hatch_shell.dart
# and hatching_cinematic.dart) and measures how fast everything is moving at
# every millisecond. Grains are as loud and as dense as the particles are
# fast, so the sound moves when -- and only when -- the picture does.
#
# What that gives, in wall-clock seconds (the shell's arc runs over 0.88 of
# the 7 s ceremony, so a shell fraction f lands at f * 6.16 s):
#
#   0    - 1.05  two still clusters of motes, one per parent (A right, B left)
#   1.05 - 1.85  the motes sprout into strands, busiest at 1.6, then stop
#   1.85 - 2.3   almost nothing moves
#   2.3  - 4.25  the strands swirl in, fastest at 3.3, slowing to rest at 4.25
#   4.25 - 4.99  the shell CINCHES: in fast, deepest at 4.62, back out
#   4.9  - 5.85  the newborn's grains leave the shell and land head first,
#                most of them around 5.6
#   5.24 - 6.05  the shell unravels, slow at first and accelerating
#   5.88 - 6.05  everything dissolves; the cue is RELEASED at the handover
#                and its ringing tail carries on under the result card
#
# The same language as the reveal that follows it -- grains, glass, air -- so
# the two read as one moment. No riser, no hit, no drum.

_SHELL = 0.88 * 7.0
CINCH = 0.69 * _SHELL
UNRAVEL = 0.85 * _SHELL
DISSOLVE = 0.840 * 7.0
HANDOVER = 0.865 * 7.0

# A typical species' strand count at tube density (92 strands x 2.1). The
# hash spreads strands evenly, so a few more or less change nothing audible.
_STRANDS = 193


def _shell_score(t):
    """How fast each part of the ceremony is moving at times [t] (seconds).

    Every curve is a sum of per-element speeds, normalised to peak 1 over the
    ceremony, so the shape is the animation's and the level is the mix's.
    """
    def h(i, salt):  # hatch_shell.dart's _h
        v = np.sin(i * 127.1 + salt * 311.7) * 43758.5453
        return v - np.floor(v)

    def ease_out(x):
        return 1 - (1 - x) ** 3

    def ease_in(x):
        return x ** 3

    def ease_in_out(x):
        return np.where(x < 0.5, 4 * x ** 3, 1 - (-2 * x + 2) ** 3 / 2)

    def speed(f):
        return np.abs(np.gradient(f, t, axis=-1))

    # HatchShellTuning
    mote_hold, string_by, sprout_stagger = 0.17, 0.33, 0.56
    converge_end, stagger, unravel_at = 0.69, 0.33, 0.85
    cinch_span, overshoot = 0.12, 0.18

    k = np.arange(_STRANDS)
    g_lead, t0 = h(k, 18), h(k, 6)
    group_b = h(k, 14) >= 0.5
    u = t / _SHELL
    g_total = string_by - mote_hold
    g_dur = g_total * (1 - sprout_stagger)

    sprout = np.zeros((2, len(t)))
    converge = np.zeros((2, len(t)))
    gathered = np.zeros((2, len(t)))
    unravel = np.zeros(len(t))
    for i in k:
        side = int(group_b[i])
        g_start = mote_hold + g_lead[i] * g_total * sprout_stagger
        g_end = g_start + g_dur
        sprout[side] += speed(ease_out(np.clip((u - g_start) / g_dur, 0, 1)))
        window = converge_end - g_end
        lead = g_end + t0[i] * stagger * window
        span = window * (1 - t0[i] * stagger)
        form = ease_in_out(np.clip((u - lead) / span, 0, 1))
        converge[side] += speed(form)
        gathered[side] += form
        unrav = ease_in(np.clip(
            (u - unravel_at) / (1 - unravel_at) - t0[i] * 0.25, 0, 1))
        # A strand fades as it unravels (culled at 0.88), so what you see
        # moving is its speed times what is left of it.
        unravel += speed(unrav) * np.clip(1 - unrav / 0.88, 0, 1)
    counts = np.array([np.sum(~group_b), np.sum(group_b)])[:, None]
    gathered /= counts

    # The cinch: one shared overshoot, sin-shaped over 0.12 of the shell.
    x = (u - converge_end) / cinch_span
    cinch = speed(np.where((x > 0) & (x < 1),
                           np.sin(x * np.pi) * overshoot, 0))

    # The newborn's grains (hatching_cinematic.dart, _SilhouetteGrains):
    # each leaves on its own clock, head first, and eases home.
    rng = np.random.default_rng(7)
    n = 2400
    delay = 0.6 * rng.random(n) + 0.4 * rng.random(n)
    gather_span = (0.835 - 0.70) * 7.0
    leave = 0.70 * 7.0 + 0.45 * delay * gather_span
    fly = 0.55 * gather_span
    landing = leave + fly
    newborn = np.zeros(len(t))
    for c in np.array_split(np.arange(n), 12):
        p = np.clip((t[None, :] - leave[c, None]) / fly, 0, 1)
        newborn += speed(ease_in_out(p)).sum(0)
    # How many land in each moment: a smoothed arrival rate.
    hist, edges = np.histogram(landing, bins=len(t), range=(t[0], t[-1]))
    kernel = np.exp(-0.5 * (np.arange(-120, 121) / 40.0) ** 2)
    lands = np.convolve(hist, kernel / kernel.sum(), mode='same')

    def norm(c):
        return c / max(np.max(c), 1e-9)

    sprout_peak = max(sprout.max(), 1e-9)
    converge_peak = max(converge.max(), 1e-9)
    return dict(
        sprout=sprout / sprout_peak, converge=converge / converge_peak,
        gathered=gathered, cinch=norm(cinch), newborn=norm(newborn),
        lands=norm(lands), unravel=norm(unravel),
    )


# How long the cue rings on past the handover. HatchingCinematic releases it
# there instead of cutting it, so this tail plays under the result card
# coming up and meets the reveal's own grains.
TAIL = 1.1


def ceremony():
    m = Mix(HANDOVER + TAIL, seed=4201)
    T = np.arange(0, m.n) / SR
    step = 0.002
    grid = np.arange(0, T[-1] + step, step)
    sc = _shell_score(grid)

    def at(curve):
        return lambda t: np.interp(t, grid, curve)

    rng = np.random.default_rng(4202)
    for side_i, side in enumerate((1.0, -1.0)):  # A right, B left
        sprout = sc['sprout'][side_i]
        converge = sc['converge'][side_i]
        gathered = sc['gathered'][side_i]
        phase = rng.uniform(0, 2 * math.pi)
        # Strands drawing out are thin and quick; strands swirling in carry
        # weight. Motes alone barely tick.
        density = at(30 + 1500 * sprout + 2100 * converge)
        level = at(0.5 + 0.15 * sprout + 0.35 * converge)
        bright = at(0.9 - 0.08 * sprout - 0.12 * converge)

        def pan(t, gathered=gathered, phase=phase, side=side):
            # Each parent's side, swirling, drawn to the centre exactly as
            # its strands arrive.
            g = np.interp(t, grid, gathered)
            swirl = 0.3 * np.sin(2 * math.pi * 0.7 * t + phase) * g * (1 - g) * 4
            return side * 0.62 * (1 - g) + swirl

        m.grains(density, bright, pan, amp=0.5, weight=level)

    # The cinch: the shell squeezes and lets go. Darker grains, at the
    # centre, as fast as the squeeze.
    m.grains(at(1100 * sc['cinch']), lambda t: 0.25 + 0 * t,
             lambda t: 0 * t, amp=0.5, weight=at(0.5 + 0.4 * sc['cinch']))

    # The newborn's grains streaming in from the shell, then landing:
    # the same settle as the card's reveal, so the two are one gesture.
    m.grains(at(2200 * sc['newborn']), at(0.72 - 0.2 * sc['lands']),
             lambda t: 0.12 * np.sin(2 * math.pi * 1.3 * t), amp=0.5,
             weight=at(0.55 + 0.25 * sc['newborn']))
    m.grains(at(2600 * sc['lands']), lambda t: 0.28 + 0 * t,
             lambda t: 0 * t, amp=0.5, weight=at(0.6 + 0.4 * sc['lands']))

    # The unravel, flying out to both sides as it speeds up.
    for side in (0.8, -0.8):
        m.grains(at(1500 * sc['unravel']), lambda t: 0.86 + 0 * t,
                 lambda t, side=side: side + 0 * t, amp=0.5,
                 weight=at(0.5 + 0.3 * sc['unravel']))

    # Everything moving goes with the picture: it dissolves linearly over
    # 5.88 - 6.05. Only what rings (below) carries on into the card.
    m.y *= np.clip((HANDOVER - T) / (HANDOVER - DISSOLVE), 0, 1)

    # The last of the newborn's grains finding their places, on into the
    # card's first moment, where the reveal's own grains take over.
    m.grains(lambda t: np.where(t > 5.8, 260 * np.exp(-(t - 5.8) / 0.4), 0),
             lambda t: 0.3 + 0 * t, lambda t: 0 * t, amp=0.5,
             weight=lambda t: 0.55 + 0 * t)

    # Air: a bed from the start; it leans in with the swirl and lets go with
    # the unravel.
    m.air(0.0, HANDOVER, 300, 2800, amp=0.02, rise=0.55)
    m.air(2.3, 2.2, 240, 1700, amp=0.05, rise=0.45)
    m.air(UNRAVEL, HANDOVER - UNRAVEL, 600, 4800, amp=0.05, rise=0.85)
    # The breath out that carries across the handover.
    m.air(5.6, HANDOVER + TAIL - 5.6, 280, 2000, amp=0.045, rise=0.28)

    # Each parent's glass, stroked so slowly it is barely a note, swelling
    # with its swirl and letting go as the strands come to rest.
    m.glass(2.2, 241, amp=0.045, ring=3.0, attack=1.1,
            brightness=0.15, pan=0.5, beat=0.6, ratios=[1.0, 2.32, 4.25])
    m.glass(2.35, 263, amp=0.04, ring=3.0, attack=1.0,
            brightness=0.15, pan=-0.5, beat=0.5, ratios=[1.0, 2.32, 4.25])
    # The shell, one body, pressed by its own cinch.
    # A swell, not a strike: a quick low glass reads as a bong, and a bong
    # is a drum.
    m.glass(CINCH, 196, amp=0.09, ring=2.2, attack=0.16, brightness=0.3,
            beat=0.8, ratios=[1.0, 2.19, 3.89, 5.91])
    # The newborn's glass blooms as its grains come home, and is still
    # ringing as the card arrives.
    m.glass(5.38, 338, amp=0.12, ring=2.6, attack=0.12, brightness=0.45,
            beat=1.1)

    m.room(t60=1.3, wet=0.22)
    return m.finish(loudness_db=-28.0, fade_out=0.5)


CUES = {
    'sfx_extraction_ceremony': (
        ceremony,
        'Two parents\' grains gather into one shell, settle as it cinches, and ring it open as it unravels',
    ),
    'sfx_extraction_creature_reveal': (
        reveal_ordinary,
        'Grains swirl home and settle with a soft weight; a low glass rings once',
    ),
    'sfx_extraction_rare_reveal': (
        reveal_rare,
        'A held, charged beat, then grains swirl home and settle into two glass bodies',
    ),
    'sfx_extraction_dissolve': (
        dissolve,
        'The result card coming apart from the foot up: a quick rising patter of grains that thins to nothing',
    ),
}
