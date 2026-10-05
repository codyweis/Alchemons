"""Wing -- the "Beams" family: its auto-attack and its special, scored to
what is drawn.

THE TIMING TABLE (Cosmic Survival is the source of truth; the open cosmos and
the dungeons build the same things from the same functions)

BASIC -- createFamilyBasicAttack 'wing' (cosmic_data.dart): TWO small glowing
bolts on the same line (ProjectileVisualStyle.standard, visualScale 0.75 --
drawGenericProjectileVisual draws a 2.3 px core in a 3.8 px glow), not a
flap. They leave 12 px and 8 px out at 600 x 1.5 = 900 px/s and 600 x 1.4 =
840 px/s, so they start nearly together and pull apart (60 px/s) as they go.
A Wing attacks from attackRange x 0.92 (_familyPreferredDistance), its
attackRange being alchemonBaseRange(int) x 1.30 = 166..312 px; at the
baseline Intelligence rating of 3 that is ~220 px, so the pair is in the air
~0.24 s (0.17 - 0.32 s across the stat range) before combatHitLight/Heavy
takes over on contact. Interval 1.5 x 0.90 / power (alchemonBasicAttack
Interval) ~0.5 - 1.35 s; Wing+Dark halves it.

SPECIAL -- _wingSpecial + _wingBeamEffects (cosmic_data.dart), held by
_ActiveWingBeam / _updateBeamEffects (cosmic_survival_game.dart):
  * The cast throws a spray of element projectiles AND opens a beam. The
    beam is on at full strength on the cast frame (its segments are re-laid
    every frame with kWingBeamFxLife 0.08 s, so there is no fade-in and it
    goes within 0.08 s of its end), and it lasts
        duration = 1.8 + rating(Int) x 0.10, clamped 1.6 .. 3.4 s
    -- ~2.1 s at the baseline rating 3, 1.9 - 2.3 s across ratings 1 - 5
    (+ any Tracer-banked time). It re-aims every frame at its target and
    ticks damage every 0.22 / targetingScale ~0.2 s (0.12 - 0.28 s); each
    tick plays its own combatHitLight/Heavy. The beam lens flickers at
    0.9 + 0.1 sin(31 t) -- ~4.9 Hz -- and sheds sparks at the hit point.
  * PATTERNS by element:
      beam    a held line to a target (nearest / lowest-HP enemy / weakest
              ally; Earth adds a second line from the orb, Spirit a cable
              into the ship and a line on from it, Light splits on a kill):
              Air Dust Lava Blood Earth Light Spirit Crystal Steam Ice Mud
              Water Plant Dark
      ring    Fire and Poison (WingBeamTargetPolicy.ring): a band laid on
              the ground round the wing at 140 + 12 x rating px, full for
              the duration, fading over its last 0.45 s (wingRingFade);
              Fire's hot sweep goes round at 3.4 rad/s (a lap per 1.85 s),
              Poison's fog turns slowly.
      charge  Lightning: chargeTime 3.0 s (stat-invariant) brewing a storm
              orb at the wing (10 -> 34 px, inward sparks at 35 -> 105 px/s,
              micro-arcs on 30 % -> 75 % of frames), then ONE blast along
              the line -- a flash 3.4x the beam's width for 0.28 s
              (kWingLightningBlast*) -- and the beam ends.
    Dark is listed as a passive on the board, but in code it casts the same
    held beam on half the cooldown (isDarkWing), so it is a 'beam'.

What each sound is made of: the beam is not a sci-fi tone. It is a jet --
a narrow stream of pressure roaring out of the wing (turbulent band noise,
roughened, carrying the lens's 4.9 Hz flicker), a fine searing hiss on top,
and a sear where it lands (tiny sparks, a little denser on each damage
tick). The element accent (sfx_element_<x>) still layers on the cast, so
nothing here carries an element's own material.

Voices added here (core.py is shared and stays as it is): roar (turbulent
pressure through a band, with moving pan), sear (sparse spark ticks from a
rate curve). strike/chips/swish/burst come from combat.py.
"""
import math

import numpy as np
from scipy import signal

from sounds.combat import _put, burst, chips, swish
from sounds.core import SR, Mix, smooth

# -- the basic ---------------------------------------------------------------
BOLT_SPEED = (900.0, 840.0)   # 600 px/s x 1.5 and x 1.4
BOLT_GAP = 0.004              # 12 px vs 8 px out: the second is ~4 ms behind
FLIGHT = (0.24, 0.20, 0.28, 0.22)  # per take: 220 px at 900 px/s, +/- range

# -- the special -------------------------------------------------------------
BEAM_LEN = 2.1          # 1.8 + 3 x 0.10 at the baseline Int rating
BEAM_CUT = 0.08         # kWingBeamFxLife: the last segment's life
TICK = 0.2              # 0.22 / targetingScale at baseline
FLICKER_HZ = 31 / (2 * math.pi)   # drawWingBeam: 0.9 + 0.1 sin(time * 31)
RING_FADE = 0.45        # wingRingFade
RING_LAP = 2 * math.pi / 3.4      # drawWingRing: sweep = time * 3.4
CHARGE = 3.0            # chargeTime for Lightning
BLAST = 0.28            # kWingLightningBlastLife


# ===========================================================================
# Voices
# ===========================================================================


def _band(rng, n, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype='bandpass', fs=SR, output='sos')
    return signal.sosfilt(sos, rng.normal(0, 1, n))


def _slow(rng, n, cutoff):
    """A smooth random wander, unit RMS, below [cutoff] Hz."""
    sos = signal.butter(2, cutoff, btype='lowpass', fs=SR, output='sos')
    x = signal.sosfilt(sos, rng.normal(0, 1, n + SR // 2))[SR // 2:]
    return x / max(float(np.sqrt(np.mean(x ** 2))), 1e-12)


def _place(m, start, left, right, pan):
    """[left]/[right] laid in from [start], [pan] an array the same length."""
    s0 = m._at(start)
    k = min(len(left), m.n - s0)
    p = np.clip(pan[:k], -1, 1)
    m.y[0, s0:s0 + k] += np.cos((p + 1) * math.pi / 4) * left[:k]
    m.y[1, s0:s0 + k] += np.sin((p + 1) * math.pi / 4) * right[:k]


def roar(m, start, length, lo, hi, env, amp, rough=0.45, rough_hz=60,
         flicker=0.0, pan=lambda u: 0 * u, spread=0.25):
    """Pressure forced through a narrow place: band noise roughened by
    turbulence (a fast random swell, [rough] deep, under [rough_hz]) -- the
    grain of a jet or a torch, never a tone. [flicker] is the depth of the
    beam lens's own 4.9 Hz flicker. The two sides share most of the stream
    and differ by [spread], so it has width without splitting in two."""
    rng = m.rng
    n = round(length * SR)
    t = np.arange(n) / SR
    u = t / length
    turb = np.clip(1 + rough * _slow(rng, n, rough_hz), 0.15, None)
    flick = 1 + flicker * np.sin(2 * math.pi * FLICKER_HZ * t
                                 + rng.uniform(0, 2 * math.pi))
    body = _band(rng, n, lo, hi)
    e = env(u) * turb * flick * amp
    sides = [(1 - spread) * body + spread * _band(rng, n, lo, hi)
             for _ in range(2)]
    _place(m, start, sides[0] * e, sides[1] * e, pan(u))


def _events(rng, start, length, rate, size, pan):
    """Poisson moments from a rate curve: [(time, size, pan)]."""
    out = []
    t = 0.0
    peak = max(float(np.max(rate(np.linspace(0, 1, 200)))), 1e-6)
    while True:
        t += rng.exponential(1 / peak)
        if t >= length:
            return out
        u = t / length
        if rng.random() < float(rate(np.array(u))) / peak:
            out.append((start + t, float(size(np.array(u))) * rng.uniform(0.5, 1.0),
                        float(pan(np.array(u))) + rng.uniform(-0.25, 0.25)))


def sear(m, start, length, rate, size, pan, f_lo=3200, f_hi=7500):
    """Sparks where a beam lands: tiny hot ticks from a rate curve -- fine
    and dry, a sizzle rather than a crackle of anything breaking."""
    chips(m, _events(m.rng, start, length, rate, size, pan), f_lo, f_hi,
          eta=0.15, n=2, tc=0.00018, cap=0.004)


# ===========================================================================
# Basic: two glowing bolts on one line
# ===========================================================================


def basic_wing(v=0):
    """Two small bolts leave the wing together and draw apart on the way to
    the target: two thin bright streaks, the second a hair behind and a
    shade darker (it is slower), each with a fine fizz trailing it, that
    recede and thin out over the ~0.24 s flight. The hit is its own cue."""
    flight = FLIGHT[v]
    m = Mix(flight + 0.14, seed=7100 + v)
    rng = m.rng
    aim = (0.22, -0.18, 0.3, -0.26)[v]   # where the target is
    # What lets them go: a small soft push of air from the wing, no click.
    burst(m, 0.0, 380, 1900, attack=0.012, tau=0.03, amp=0.05, pan=aim * 0.2)
    for k, speed in enumerate(BOLT_SPEED):
        at = k * (BOLT_GAP + rng.uniform(0.004, 0.009))
        life = flight * BOLT_SPEED[0] / speed
        # Receding: the band drops and narrows as it goes away, level falls.
        hi = (5600, 4900)[k] * rng.uniform(0.95, 1.05)
        swish(m, at, life,
              lambda u, hi=hi: hi - 1900 * u,
              0.3 - 0.05 * k,
              lambda u: np.where(u < 0.06, (u / 0.06) ** 2,
                                 (1 - smooth(u, 0.8, 1.0)) * (1 - 0.25 * u)),
              (0.11, 0.085)[k])
        # The glow fizzing behind it: sparse, fine, thinning.
        trail = [(at + life * x, rng.uniform(0.12, 0.25) * (1 - 0.6 * x),
                  aim * (0.2 + 0.7 * x) + rng.uniform(-0.12, 0.12))
                 for x in np.sort(rng.uniform(0.02, 0.85, 9))]
        chips(m, trail, 4200, 8200, eta=0.15, n=2, tc=0.00016, cap=0.003)
    # Both streaks travel toward the target: pan the whole take there.
    m.y = _travel(m.y, aim, flight)
    m.room(t60=0.3, wet=0.1)
    return m.finish(loudness_db=-35.0, fade_out=0.06)


def _travel(y, aim, flight):
    """Moves a centred stereo take toward [aim] over [flight] seconds."""
    n = y.shape[1]
    t = np.arange(n) / SR
    p = aim * smooth(t, 0.0, flight)
    mono = 0.5 * (y[0] + y[1])
    side = 0.5 * (y[0] - y[1])
    gl = np.cos((p + 1) * math.pi / 4) * math.sqrt(2)
    gr = np.sin((p + 1) * math.pi / 4) * math.sqrt(2)
    return np.vstack([mono * gl + side, mono * gr - side])


# ===========================================================================
# Special: the held beam (14 of 17 elements)
# ===========================================================================


def special_beam(v=0, hold=None):
    """The beam opens on the cast frame and holds ~2.1 s: a stream of
    pressure roaring out of the wing with a searing hiss on it, flickering
    with the lens, sparks where it lands that thicken on every damage tick,
    and once or twice a swing as it re-aims; then it is gone in a breath
    (the segments die 0.08 s after the beam does). The cast's spray of
    element projectiles flicks out at the start."""
    hold = hold or BEAM_LEN
    m = Mix(hold + 0.55, seed=7200 + v + _bucket_seed(hold))
    rng = m.rng
    aim = (0.25, -0.2, 0.15, -0.3)[v]
    on = 0.04        # lean in: the beam is up on the cast frame
    total = hold + BEAM_CUT + 0.1

    def env(u):
        t = u * total
        rise = smooth(t, 0.0, on)
        # The opening bite: about +4 dB over the hold, gone by ~0.25 s.
        bite = 1 + 0.7 * np.exp(-np.maximum(t - on, 0) / 0.12) * rise
        cut = 1 - smooth(t, hold - 0.02, hold + BEAM_CUT + 0.05)
        return rise * bite * cut

    # Re-aims: the beam swings to a new target once or twice.
    # About one more every 0.7 s of extra hold, so a long beam keeps
    # moving the way a short one does.
    swings = sorted(rng.uniform(0.5, hold - 0.4,
                                1 + v % 2 + int((hold - BEAM_LEN) / 0.7)))

    def pan(u):
        t = u * total
        p = aim * smooth(t, 0.0, 0.05) * 0.7
        for k, s in enumerate(swings):
            p = p + (0.25 if k % 2 == v % 2 else -0.25) * smooth(t, s, s + 0.12)
        return p

    # The stream itself: a jet's roar, the body of the beam.
    roar(m, 0.0, total, 480, 1900, env, 0.22, rough=0.65, rough_hz=110,
         flicker=0.1, pan=pan, spread=0.3)
    # Its searing top, wandering so it never settles into a whistle.
    wander = rng.uniform(0, 2 * math.pi)
    swish(m, 0.0, total,
          lambda u: 3300 + 450 * np.sin(2 * math.pi * 0.7 * u * total + wander)
          + 250 * np.sin(2 * math.pi * 1.9 * u * total),
          0.32, env, 0.12, pan=aim * 0.6)
    # Where it lands: fine sparks, a little thicker on each tick.
    phase = rng.uniform(0, TICK)

    def rate(u):
        t = u * hold
        in_tick = np.exp(-(((t - phase) % TICK) / 0.035))
        return (320 + 420 * in_tick) * smooth(t, 0.02, 0.06)

    sear(m, 0.01, hold, rate, lambda u: 0.45 + 0 * u,
         lambda u: aim + 0 * u)
    # The bite at the first target: a short sizzle crowding in.
    sear(m, 0.0, 0.12, lambda u: 450 * (1 - u) * smooth(u, 0, 0.25), lambda u: 0.45 + 0 * u,
         lambda u: aim + 0 * u, f_lo=2400, f_hi=6000)
    # The spray of element projectiles leaving with it: quick thin flicks
    # fanned to both sides.
    for k in range(3):
        side = (-0.5, 0.45, 0.1)[k]
        at = 0.015 + 0.03 * k + rng.uniform(0, 0.01)
        swish(m, at, 0.12, lambda u: 4600 - 1500 * u, 0.22,
              lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.5) ** 2,
              0.05, pan=side)
    # The end: the stream stops and the air it held lets go, softly.
    burst(m, hold + 0.01, 260, 1300, attack=0.02, tau=0.06, amp=0.03,
          pan=aim * 0.3)
    m.room(t60=0.5, wet=0.14)
    return m.finish(loudness_db=-32.0, fade_out=0.12)


# ===========================================================================
# Special: the ring (Fire, Poison)
# ===========================================================================


def special_ring(hold=None):
    """A band laid on the ground all round the wing: a wide low pressure
    going out to the circle, then a ring of stream that circles the listener
    -- its hot part travelling round once every 1.85 s, brighter and nearer
    as it passes in front -- with the drag of the band on the ground under
    it; full for the duration, fading over the last 0.45 s as the ring
    does."""
    hold = hold or BEAM_LEN
    total = hold + 0.05
    m = Mix(total + 0.5, seed=7300 + _bucket_seed(hold))
    rng = m.rng

    def fade(t):
        return np.clip((hold - t) / RING_FADE, 0, 1) ** 1.2

    # Laying it out: pressure spreading to the circle.
    burst(m, 0.0, 200, 1200, attack=0.035, tau=0.1, amp=0.07)
    swish(m, 0.0, 0.3, lambda u: 900 + 1300 * u, 0.45,
          lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.4) ** 2, 0.06)

    # The perimeter as a whole: a wide, low stream on both sides at once.
    def base_env(u):
        t = u * total
        return smooth(t, 0.0, 0.06) * (1 + 0.35 * np.exp(-t / 0.15)) * fade(t)

    roar(m, 0.0, total, 240, 1000, base_env, 0.2, rough=0.4, rough_hz=40,
         spread=0.85)

    # The sweep: the hot part going round. Front of the circle = centre and
    # bright; behind = darker, quieter; it crosses both sides each lap.
    start_ang = rng.uniform(0, 2 * math.pi)

    def ang(u):
        return start_ang + 2 * math.pi * (u * total) / RING_LAP

    def sweep_env(u):
        t = u * total
        front = 0.5 + 0.5 * np.cos(ang(u))
        return smooth(t, 0.02, 0.12) * (0.45 + 0.55 * front) * fade(t)

    roar(m, 0.0, total, 500, 2400, sweep_env, 0.22, rough=0.55, rough_hz=70,
         pan=lambda u: 0.85 * np.sin(ang(u)), spread=0.15)
    swish(m, 0.0, total,
          lambda u: 2100 + 900 * (0.5 + 0.5 * np.cos(ang(u))), 0.35,
          lambda u: sweep_env(u) * (0.4 + 0.6 * (0.5 + 0.5 * np.cos(ang(u)))),
          0.06)
    # The band dragging on the ground: a dry scuff spread all round.
    sear(m, 0.04, hold, lambda u: 90 * fade(0.04 + u * hold),
         lambda u: 0.3 * fade(0.04 + u * hold),
         lambda u: rng.uniform(-0.9, 0.9) + 0 * u,
         f_lo=1200, f_hi=3400)
    m.room(t60=0.6, wet=0.16)
    return m.finish(loudness_db=-31.0, fade_out=0.2)


# ===========================================================================
# Special: the charge (Lightning)
# ===========================================================================


def special_charge():
    """Three seconds of gathering at the wing, then one blast down the line.

    The storm orb grows and pulls harder as it fills: air drawn in, thicker
    and closer (density and level, not pitch), circling slowly as the motes
    do; inward sparks that come faster; little arcs snapping inside it, more
    often toward the end. At 3.0 s it lets go along the line: a tearing
    stream that leans in over ~25 ms and holds the 0.28 s of the flash, a
    shove of air under it, the line crackling out toward the target, and
    the air settling after. The heavy hit on whatever it strikes is its own
    cue."""
    total = CHARGE + BLAST + 0.75
    m = Mix(total, seed=7400)
    rng = m.rng
    aim = 0.3

    def prog(t):
        return np.clip(t / CHARGE, 0, 1)

    # Air drawn in toward the orb: grows, and closes in at the very end.
    def draw_env(u):
        t = u * CHARGE
        p = prog(t)
        return (smooth(t, 0.0, 0.25) * (0.25 + 0.75 * p ** 1.6)
                * (1 - smooth(t, CHARGE - 0.04, CHARGE + 0.01)))

    roar(m, 0.0, CHARGE, 260, 1300, draw_env, 0.26, rough=0.35, rough_hz=25,
         pan=lambda u: 0.35 * np.sin(2 * math.pi * 0.13 * u * CHARGE),
         spread=0.6)
    # A brighter layer that only comes in as it fills: the orb getting hot.
    roar(m, 0.0, CHARGE, 1400, 4200,
         lambda u: draw_env(u) * smooth(u, 0.3, 1.0) ** 1.5, 0.14,
         rough=0.6, rough_hz=80, spread=0.4)
    # Sparks pulled inward, faster as it fills.
    sear(m, 0.05, CHARGE - 0.05,
         lambda u: 14 + 70 * u ** 1.4, lambda u: 0.25 + 0.2 * u,
         lambda u: 0.5 * np.sin(2 * math.pi * 3.0 * u), f_lo=2600, f_hi=6800)
    # Micro-arcs: a few snaps bunched into a few ms, 30 % -> 75 % of frames
    # on screen; heard as ~2 -> 12 a second.
    t = 0.15
    while t < CHARGE - 0.04:
        p = t / CHARGE
        n = rng.integers(3, 6)
        snaps = [(t + rng.uniform(0, 0.012), (0.3 + 0.35 * p) * rng.uniform(0.6, 1),
                  rng.uniform(-0.45, 0.45)) for _ in range(n)]
        chips(m, snaps, 2200, 6500, eta=0.12, n=2, tc=0.0002, cap=0.006)
        t += rng.exponential(1 / (2 + 10 * p ** 1.3))

    # THE BLAST, along the line.
    b = CHARGE
    lean = 0.025

    def blast_env(u):
        tt = u * (BLAST + 0.4)
        return (smooth(tt, 0.0, lean)
                * np.where(tt < BLAST, 1 - 0.25 * tt / BLAST,
                           0.75 * np.exp(-(tt - BLAST) / 0.07)))

    roar(m, b, BLAST + 0.4, 600, 3800, blast_env, 0.4, rough=0.7,
         rough_hz=90, pan=lambda u: aim * smooth(u, 0, 0.2), spread=0.3)
    # The air it shoves aside: low and soft-edged, never a thump.
    burst(m, b, 140, 700, attack=0.03, tau=0.13, amp=0.1, pan=aim * 0.4)
    # The line crackling out to the target over the first few frames.
    chips(m, [(b + 0.005 + 0.07 * x ** 1.2, 0.18 * (1 - 0.5 * x),
               aim * x + rng.uniform(-0.1, 0.1))
              for x in np.sort(rng.uniform(0, 1, 16))],
          1800, 5600, eta=0.1, n=3, tc=0.00025, cap=0.012)
    # Settling: sparks thinning out after the flash.
    sear(m, b + BLAST, 0.45, lambda u: 80 * (1 - u) ** 2,
         lambda u: 0.3 + 0 * u, lambda u: aim * 0.8 + 0 * u)
    m.air(b + 0.05, 0.6, 200, 1400, amp=0.04, rise=0.15, pan=aim * 0.3)
    m.room(t60=0.9, wet=0.2)
    return m.finish(loudness_db=-32.0, fade_out=0.3)


# ===========================================================================
# Length buckets
# ===========================================================================
#
# A beam's hold is 1.8 + Int rating x 0.10, clamped 1.6 .. 3.4 s, plus any
# Tracer-banked time; the game picks the file whose hold is nearest at cast
# time (see BEAM_BUCKETS). Each bucket is its own render, not a stretched or
# looped copy: the flicker, re-aims and ticks run on for the whole hold.

BEAM_BUCKETS = {'': 2.1, '_long': 2.7, '_longest': 3.4}


def _bucket_seed(hold):
    return int(round((hold - BEAM_LEN) * 10)) * 1000  # 0 for the base take


# ===========================================================================
# Exports
# ===========================================================================

# Element -> which special cue the cast plays. None is the family-level
# sfx_special_wing (the held beam).
SPECIAL_PATTERNS = {
    'Air': None, 'Dust': None, 'Lava': None, 'Blood': None, 'Earth': None,
    'Light': None, 'Spirit': None, 'Crystal': None, 'Steam': None,
    'Ice': None, 'Mud': None, 'Water': None, 'Plant': None, 'Dark': None,
    'Fire': 'ring', 'Poison': 'ring',
    'Lightning': 'charge',
}

CUES = {
    'sfx_basic_wing': {
        'build': basic_wing, 'variants': 3,
        'description': 'Two small glowing bolts leave together and draw apart: '
                       'thin bright streaks receding over the ~0.24 s flight, a fizz behind each',
    },
    'sfx_special_wing_charge': (
        special_charge, 'Lightning: 3 s of air drawn into a growing storm orb, sparks and arcs '
                        'quickening, then one tearing blast down the line and the air settling'),
}

for _suffix, _hold in BEAM_BUCKETS.items():
    CUES['sfx_special_wing' + _suffix] = {
        'build': (lambda v=0, h=_hold: special_beam(v, h)), 'variants': 3,
        'description': f'The held beam, {_hold} s hold: a jet of pressure roaring out of the '
                       'wing, a searing hiss, sparks where it lands thickening each tick; '
                       'gone in a breath',
    }
    CUES['sfx_special_wing_ring' + _suffix] = (
        (lambda h=_hold: special_ring(h)),
        f'Fire/Poison ring, {_hold} s: pressure laid out round the wing, a stream circling '
        'once per 1.85 s with the band dragging on the ground; fades over its last 0.45 s')
