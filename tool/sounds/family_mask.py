"""The Mask family ("Traps"): its blown dart, the cast that lays its field,
and the moment a trap goes off.

What is drawn, and so what it sounds like (Cosmic Survival is the source of
truth; the open cosmos and the dungeons run the same shared code):

BASIC -- createFamilyBasicAttack 'mask' (cosmic_data.dart): ONE piercing dart,
  speed 600 x 1.3 = 780 px/s, life 1.2 s (~940 px: it crosses the screen and
  is gone in about half a second), drawn as a 2 px lit core in a 4 px glow,
  no trail. It passes through everything (combatHitLight plays for each body
  it goes through, separately). Interval: 1.5 s x 1.10 (the mask frame) /
  power -- roughly one every 1-1.7 s per Mask. So: a breath through a narrow
  tube -- the mask BLOWS the dart -- and a thin needle tearing the air that
  recedes as the dart leaves the screen. ~0.45 s, not 0.15.

SPECIAL -- _maskSpecial (cosmic_data.dart) + placeMaskTraps
  (mask_trap_placement.dart), laid by _activateMaskPlacements (survival) /
  activateMaskPlacements (open cosmos). Base cooldown 22.5 s: rare, so it may
  be fuller than a latch. EVERY fixture appears on the cast frame -- there is
  no throw arc and no grow-in (mask_trap_vfx.dart draws them at full size from
  the first frame). Four shapes:

  scatter  Air 3-25 pads, Lava 5-15 pools, Poison 3-12 clouds, Crystal 3-7,
           Fire 5-15 balls, Steam 3-8 geysers, Water 3-10, Mud 1-5, Earth 2-5
           heal pools, Spirit 4-14 wisps ringed round the ship. A field laid
           all at once, wide: one sowing sweep and many soft set-downs across
           the whole stereo field inside ~0.12 s, then the ground answering.
  single   Light's void, Dark's hole, Lightning's field, Blood's blob, Ice's
           pillar: ONE fixture set where the target stands -- one aimed sweep
           and one weightier set-down, the ground giving a little under it.
  feed     Plant: after the first cast nothing is placed; the caster's one
           vine is FED -- its trunk pulses (abilityGrowthTimer 1.0 decaying at
           1.6/s = 0.63 s) and 9 (18 on a new tendril) motes burst out of the
           root for 0.45-0.8 s. A trunk swelling: a slow low groan of wood
           under pressure, with a fibrous burst at the start. The Plant accent
           already carries leaves and a stem's creak; this sits under it.
  wrap     Dust: no ground trap at all -- a grit ring is put round the ship
           and every ally (maskDustShield), orbiting its host, with five heavy
           stones in it (interceptCharges). A circling sweep of air and the
           five stones knocking into their orbit. The Dust accent carries the
           sand itself.

SPRINGS -- a trap going off on contact. MaskTrapVisuals.contact draws a 0.55 s
  echo, at most one per fixture at a time (24 max), for the contact elements.
  The ones that are a discrete EVENT get a short cue of their own:
    Light    the void consumes one body (instant kill), collapses in 0.4 s
    Crystal  breaks into 3 smaller crystals (contact echo throws 9 shards)
    Fire     the ball bursts into a fire pool (spent, collapses in 0.35 s)
    Water    a splash on contact (torn surface fronts, sprays)
    Dark     a body reaching the middle is put out of the field
  Air (knockback pads, up to 25 of them, 22 s), Blood (marks a body) and
  Lightning (grows with every touch) fire continuously in a crowd and their
  effect is ongoing -- they stay silent; their hits already sound.
"""
import math

import numpy as np
from scipy import signal

from sounds.core import SR, Mix, smooth
from sounds.combat import (_comb, _fracture, _put, _solid, burst, chips,
                           strike, swish)
from sounds.elements import (_bubbles, _noise_env, _plop, _pops,
                             _stickslip, _svf)

# ===========================================================================
# Voices
# ===========================================================================


def _lp(x, f):
    return signal.sosfilt(signal.butter(2, f, btype='lowpass', fs=SR,
                                        output='sos'), x)


def _set_down(m, at, f0, weight, pan, dull=2200.0):
    """A small thing set down on a hard floor: a soft contact (1-2 ms, so
    dull and never a click) into a small, heavily damped body, and a breath
    of grit under it. Small and many, not one big knock: a big low body here
    reads as a drum (the first take did)."""
    rng = m.rng
    modes = _solid(rng, f0, n=6, spread=(0.18, 0.5), eta=0.09, cap=0.025,
                   tilt=0.25)
    strike(m, at, modes, tc=rng.uniform(0.0012, 0.002), amp=0.55 * weight,
           pan=pan, lowpass=dull)
    burst(m, at, 900, 3200, attack=0.002, tau=0.006, amp=0.02 * weight,
          pan=pan)


def _put_moving(m, start, x, pan):
    """Mono [x] laid in with a per-sample pan curve."""
    s0 = m._at(start)
    k = min(len(x), m.n - s0)
    p = np.clip(pan, -1, 1)[:k]
    m.y[0, s0:s0 + k] += x[:k] * np.cos((p + 1) * math.pi / 4)
    m.y[1, s0:s0 + k] += x[:k] * np.sin((p + 1) * math.pi / 4)


def _cos_out(u):
    return np.cos(np.clip(u, 0, 1) * math.pi / 2) ** 2


# ===========================================================================
# BASIC -- the blown dart
# ===========================================================================
#
# The dart crosses the screen at 780 px/s and is gone in ~0.5 s; the needle's
# tear fades on that (DART_GONE), dulling as it leaves.

DART_GONE = 0.42


def basic(v=0):
    m = Mix(0.48, seed=7300 + v)
    rng = m.rng
    side = (0.3, -0.25, 0.35, -0.3)[v]
    # The breath: a short push of air through a narrow tube (the mask's
    # mouth). A comb at the tube's length gives it a bore, not a tone.
    tube = (980, 1060, 920, 1120)[v] * rng.uniform(0.98, 1.02)
    n = round(0.07 * SR)
    t = np.arange(n) / SR
    env = smooth(t, 0, 0.006) * np.exp(-np.maximum(t - 0.006, 0) / 0.014)
    sos = signal.butter(2, [350, 3400], btype='bandpass', fs=SR, output='sos')
    puff = signal.sosfilt(sos, rng.normal(0, 1, n)) * env
    _put(m, 0.0, 0.055 * _comb(puff, tube, 0.42), pan=0.0)
    # The lip letting go of it: a faint dry tick, almost not there.
    chips(m, [(0.008, 0.05, 0.0)], 1800, 3000, eta=0.12, n=2, tc=0.0004,
          cap=0.006)
    # The needle: a thin tear of air that leaves -- quick in as it clears
    # the tube, then thinning and dulling with distance. Its band settles a
    # little as it goes (no "pew": a few hundred Hz over half a second).
    hi = (4700, 4400, 5000, 4550)[v]
    swish(m, 0.006, DART_GONE,
          lambda u: hi - 900 * smooth(u, 0.0, 1.0), 0.24,
          lambda u: smooth(u, 0, 0.03) * np.exp(-u / 0.34) * _cos_out((u - 0.7) / 0.3),
          0.1, pan=0.0)
    # It drifts off to the side it was aimed at.
    swish(m, 0.03, DART_GONE - 0.03,
          lambda u: (hi - 1500) - 700 * u, 0.3,
          lambda u: smooth(u, 0, 0.1) * np.exp(-u / 0.28) * _cos_out((u - 0.6) / 0.4),
          0.03, pan=side)
    m.room(t60=0.3, wet=0.08)
    return m.finish(loudness_db=-35.0, fade_out=0.08)


# ===========================================================================
# SPECIAL -- laying the field
# ===========================================================================
#
# Everything appears on the cast frame, so the set-downs come at once:
# SET_SPREAD is how far apart the first and last land (a handful of things
# can't be heard as simultaneous anyway; 0.12 s reads as "all at once, many").

SET_AT = 0.035
SET_SPREAD = 0.12


def special_scatter():
    m = Mix(0.95, seed=7310)
    rng = m.rng
    # The sowing sweep: one gesture fanning out to both sides.
    for pan in (-0.55, 0.55):
        swish(m, 0.0, 0.2, lambda u: 650 + 1100 * np.sin(math.pi * u ** 0.6),
              0.45, lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.55) ** 2,
              0.07, pan=pan)
    # The fixtures set down across the field: alternate sides, the far ones
    # (wide pans) a touch later, quieter and duller. Under them, one soft
    # mass of landing that leans in (25 ms) -- the field, not the pieces.
    burst(m, SET_AT - 0.01, 220, 1400, attack=0.025, tau=0.06, amp=0.05)
    count = 13
    for k in range(count):
        reach = (k + 1) / count
        side = 1 if k % 2 else -1
        at = SET_AT + SET_SPREAD * reach ** 1.3 + rng.uniform(-0.008, 0.008)
        pan = side * (0.1 + 0.8 * reach) + rng.uniform(-0.08, 0.08)
        _set_down(m, at, rng.uniform(520, 1100), weight=1.0 - 0.5 * reach,
                  pan=float(np.clip(pan, -0.95, 0.95)),
                  dull=3200 - 1500 * reach)
    # The ground answering: a low hush spreading out to both sides, and a
    # few grains of grit settling after.
    m.air(SET_AT, 0.7, 150, 900, amp=0.035, rise=0.18, pan=-0.6)
    m.air(SET_AT + 0.01, 0.7, 150, 900, amp=0.035, rise=0.2, pan=0.6)
    grit = [(SET_AT + 0.06 + min(rng.exponential(0.1), 0.3), rng.uniform(0.04, 0.09),
             rng.uniform(-0.85, 0.85)) for _ in range(7)]
    chips(m, grit, 1100, 2800, eta=0.08, n=3, tc=0.0004, cap=0.02)
    m.room(t60=0.6, wet=0.15)
    return m.finish(loudness_db=-31.0, fade_out=0.3)


def special_single():
    m = Mix(0.95, seed=7320)
    rng = m.rng
    land = 0.06
    # One aimed sweep: narrower, centred, with a little weight in it.
    swish(m, 0.0, 0.16, lambda u: 520 + 900 * np.sin(math.pi * u ** 0.7),
          0.4, lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.5) ** 2,
          0.1, pan=0.0)
    # The set-down: heavier and softer than a scatter's, the floor crunching
    # a little under it, and the flump of its own weight.
    strike(m, land, _solid(rng, 360, n=18, spread=(0.1, 0.35), eta=0.09,
                           cap=0.04, tilt=0.12), tc=0.004, amp=0.32,
           lowpass=2200)
    burst(m, land - 0.012, 260, 1400, attack=0.02, tau=0.045, amp=0.06)
    chips(m, _fracture(land - 0.004, 0.045, 12, 0.05, 0.16, -0.3, 0.3),
          900, 2800, eta=0.08, n=3, tc=0.0005, cap=0.02)
    # The ground answering, opening out from where it landed.
    n = round(0.75 * SR)
    t = np.arange(n) / SR
    env = smooth(t, 0, 0.05) * np.exp(-6.9 * np.maximum(t - 0.05, 0) / 0.7)
    width = smooth(t, 0, 0.4)
    sos = signal.butter(2, [220, 1200], btype='bandpass', fs=SR, output='sos')
    a = signal.sosfilt(sos, rng.normal(0, 1, n))
    b = signal.sosfilt(sos, rng.normal(0, 1, n))
    mid, sid = 0.5 * (a + b), 0.5 * (a - b)
    s0 = m._at(land)
    k = min(n, m.n - s0)
    m.y[0, s0:s0 + k] += (0.05 * env * (mid + width * sid))[:k]
    m.y[1, s0:s0 + k] += (0.05 * env * (mid - width * sid))[:k]
    m.room(t60=0.65, wet=0.16)
    return m.finish(loudness_db=-31.0, fade_out=0.3)


def special_feed():
    """Plant: the vine's trunk swelling as it is fed (0.63 s flash)."""
    m = Mix(0.9, seed=7330)
    rng = m.rng
    # The burst out of the root: fibres parting, quick and spread wide (the
    # 9-18 motes leaving the root on the cast frame).
    fibres = [(0.004 + rng.exponential(0.03), rng.uniform(0.08, 0.18),
               rng.uniform(-0.8, 0.8)) for _ in range(14)]
    chips(m, fibres, 800, 2400, eta=0.14, n=3, tc=0.0006, cap=0.012)
    # The trunk taking the feed: a thick body under strain, dense irregular
    # catches (a groan, not a ratchet -- slow catches buzz like a motor),
    # loudest with the flash on the cast frame and easing as it fades
    # (0.63 s).
    _stickslip(m, 0.01, 0.62, lambda x: 85 + 70 * math.sin(math.pi * min(x, 1) ** 0.5),
               0.5, 0.3, [190, 310, 455, 640, 880, 1180],
               [0.05, 0.045, 0.04, 0.03, 0.025, 0.02],
               [0.7, 1.0, 0.85, 0.6, 0.4, 0.25],
               pan=0.1, roughness=0.25, hp=160,
               env=lambda x: smooth(np.array(x), 0, 0.06) * math.exp(-x / 0.45)
               * float(_cos_out((x - 0.75) / 0.25)))
    # Sap drawn up it: a low push whose band climbs a little as it rises.
    n = round(0.6 * SR)
    t = np.arange(n) / SR
    sap = _svf(rng.normal(0, 1, n), 260 + 320 * smooth(t, 0, 0.45), 1.6, 'bp')
    _put(m, 0.0, 0.05 * sap * smooth(t, 0, 0.04) * np.exp(-t / 0.3)
         * _cos_out((t - 0.45) / 0.15), pan=-0.1)
    m.room(t60=0.55, wet=0.14, darkness=3200)
    return m.finish(loudness_db=-31.0, fade_out=0.25)


def special_wrap():
    """Dust: a grit ring put round every ally, orbiting, five stones in it."""
    m = Mix(1.0, seed=7340)
    rng = m.rng
    # The ring going round: air whose place in the field circles (1.4 turns
    # over the cue), swelling as it forms and easing into its orbit.
    n = round(0.85 * SR)
    t = np.arange(n) / SR
    env = (smooth(t, 0, 0.06) * np.exp(-np.maximum(t - 0.12, 0) / 0.35)
           * _cos_out((t - 0.6) / 0.25))
    turn = 2 * math.pi * (1.0 * t + 0.35 * t * t)
    sos = signal.butter(2, [600, 2600], btype='bandpass', fs=SR, output='sos')
    for ph in (0.0, math.pi):
        x = signal.sosfilt(sos, rng.normal(0, 1, n)) * env
        p = 0.8 * np.sin(turn + ph)
        # The far side of the ring is quieter.
        near = 0.7 + 0.3 * np.cos(turn + ph)
        s0 = m._at(0.0)
        m.y[0, s0:s0 + n] += 0.05 * near * x * np.cos((p + 1) * math.pi / 4)
        m.y[1, s0:s0 + n] += 0.05 * near * x * np.sin((p + 1) * math.pi / 4)
    # The five stones knocking into their places round the ring.
    for k in range(5):
        at = 0.08 + 0.065 * k + rng.uniform(-0.01, 0.01)
        pan = 0.75 * math.sin(2 * math.pi * (1.0 * at + 0.35 * at * at))
        chips(m, [(at, rng.uniform(0.18, 0.26) * (1 - 0.1 * k), pan)],
              750, 1800, eta=0.06, n=4, tc=0.0007, cap=0.03)
    m.room(t60=0.55, wet=0.15)
    return m.finish(loudness_db=-31.0, fade_out=0.3)


# ===========================================================================
# SPRINGS -- a trap going off (the 0.55 s contact echo)
# ===========================================================================


def spring_light(v=0):
    """The void takes one body: the lit slit tears open on it and closes
    (the fixture collapses over 0.4 s). An incision, then the air drawn in
    after it, cut off."""
    m = Mix(0.48, seed=7400 + v)
    rng = m.rng
    # The tear: a dense rip of tiny high fractures, ~60 ms, leaning in --
    # random in time and band, so it never buzzes at a pitch -- with the
    # slit's bright edge running along it.
    pan = (0.1, -0.1, 0.15, -0.05)[v]
    _pops(m, 0.0, 0.065, 2600, 2400, 9000, 0.05, decay=(0.0002, 0.0007),
          q=(1.5, 3.0), pan=(pan - 0.25, pan + 0.25),
          shape=lambda x: math.sin(math.pi * min(x, 1) ** 0.6) ** 1.5)
    swish(m, 0.0, 0.09, lambda u: 3600 + 2600 * u, 0.35,
          lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.5) ** 2, 0.05, pan)
    # The closing: air drawn into the slit, its top closing off, stopping
    # short as the lens shuts (0.32 s).
    stop = 0.32 + 0.02 * (v % 2)
    n = round(stop * SR)
    t = np.arange(n) / SR
    x = t / stop
    cutoff = 4200 * (700 / 4200) ** x
    swell = smooth(t, 0.04, 0.1) * (0.3 + 0.7 * x) * np.clip((stop - t) / 0.02, 0, 1)
    for side in (-1, 1):
        a = _svf(rng.normal(0, 1, n), cutoff, 0.9, 'lp')
        a = signal.sosfilt(signal.butter(2, 300, btype='highpass', fs=SR,
                                         output='sos'), a)
        _put_moving(m, 0.0, 0.035 * a * swell, side * 0.5 * (1 - x))
    m.room(t60=0.35, wet=0.1, darkness=5200)
    return m.finish(loudness_db=-33.0, fade_out=0.06)


def spring_crystal(v=0):
    """A crystal breaks into three smaller ones: the crack running, the
    break with a mineral body, and the three pieces setting down apart."""
    m = Mix(0.42, seed=7410 + v)
    rng = m.rng
    crack = 0.025
    chips(m, _fracture(0.0, crack, 10, 0.05, 0.25, -0.2, 0.2),
          2400, 5800, eta=0.02, n=3, tc=0.0003, cap=0.025)
    # The break: a dense quartz body, short -- many modes, none standing out.
    strike(m, crack, _solid(rng, (1150, 1260, 1080, 1320)[v], n=18,
                            spread=(0.1, 0.32), eta=0.03, cap=0.035, tilt=0.06),
           tc=0.0006, amp=0.2)
    burst(m, crack - 0.003, 1200, 5200, attack=0.003, tau=0.01, amp=0.04)
    # The three pieces, flung apart and landing.
    pans = rng.permutation([-0.55, 0.0, 0.55])
    for k, pan in enumerate(pans):
        at = crack + 0.05 + 0.045 * k + rng.uniform(0, 0.02)
        chips(m, [(at, 0.4 * (1 - 0.15 * k), float(pan))], 1500, 3600,
              eta=0.045, n=5, tc=0.0004, cap=0.022)
    m.room(t60=0.3, wet=0.08)
    return m.finish(loudness_db=-33.0, fade_out=0.08)


def spring_fire(v=0):
    """The fire ball bursts and spreads into a pool: a whumpf whose top
    flares open, the flame spreading low and flat, a few embers."""
    m = Mix(0.5, seed=7420 + v)
    rng = m.rng
    n = round(0.42 * SR)
    t = np.arange(n) / SR
    fc = 240 + 2600 * smooth(t, 0.0, 0.045) * np.exp(-np.maximum(t - 0.045, 0) / 0.12)
    whumpf = _svf(rng.normal(0, 1, n), fc + 250, 0.8, 'lp')
    whumpf = signal.sosfilt(signal.butter(2, 150, btype='highpass', fs=SR,
                                          output='sos'), whumpf)
    env = smooth(t, 0, 0.025) * np.exp(-6.9 * np.maximum(t - 0.025, 0) / 0.38)
    _put(m, 0.0, 0.12 * whumpf * env, pan=(0.0, -0.1, 0.1, 0.05)[v])
    # The pool spreading: flame flutter moving out to both sides.
    flick = 1 + 0.5 * _lp(rng.normal(0, 1, n), 16) * 9
    for side in (-0.45, 0.45):
        roar = _svf(rng.normal(0, 1, n), 700 + 300 * smooth(t, 0, 0.2), 1.2, 'bp')
        e2 = smooth(t, 0.02, 0.08) * np.exp(-6.9 * t / 0.45) * np.clip(flick, 0.2, 2)
        _put(m, 0.015, 0.035 * roar * e2, pan=side)
    _pops(m, 0.02, 0.35, 70, 1400, 6000, 0.06,
          shape=lambda x: math.exp(-2.0 * x), big=0.1, pan=(-0.6, 0.6))
    m.room(t60=0.4, wet=0.1, darkness=3800)
    return m.finish(loudness_db=-33.0, fade_out=0.1)


def spring_water(v=0):
    """A splash on contact: the surface slapped open (leaning in ~10 ms),
    the bubbles it drives under, drops falling back."""
    m = Mix(0.45, seed=7430 + v)
    rng = m.rng
    _noise_env(m, 0.0, 0.2, 'bandpass', [380, 5000], 0.08, attack=0.01,
               t60=0.09, stereo=True)
    _put(m, 0.004, 0.14 * _plop(rng, rng.uniform(260, 360), 0.07, rise=0.2,
                                q=4.0, attack=0.006), pan=0.0)
    _bubbles(m, 0.01, 0.22, 420, 600, 2800, 0.06,
             shape=lambda x: math.exp(-4 * x), pan=(-0.7, 0.7))
    # Drops falling back onto the surface, spread out from it.
    for k in range(4 + v % 2):
        at = 0.1 + rng.uniform(0, 0.22)
        _put(m, at, 0.03 * _plop(rng, rng.uniform(700, 1400), 0.03, rise=0.3,
                                 q=3.5, attack=0.006),
             pan=float(rng.uniform(-0.8, 0.8)))
    m.room(t60=0.35, wet=0.1)
    return m.finish(loudness_db=-33.0, fade_out=0.08)


def spring_dark(v=0):
    """A body reaches the hole and is put out of the field: the echo pulls in
    for its first quarter (0.14 s) and then throws streaks outward. A gulp
    that closes off, then the release leaving to one side."""
    m = Mix(0.52, seed=7440 + v)
    rng = m.rng
    gulp = 0.13
    n = round(gulp * SR)
    t = np.arange(n) / SR
    x = t / gulp
    cutoff = 3000 * (320 / 3000) ** x
    swell = smooth(t, 0, 0.03) * (0.5 + 0.5 * x) * np.clip((gulp - t) / 0.015, 0, 1)
    for side in (-1, 1):
        a = _svf(rng.normal(0, 1, n), cutoff, 0.9, 'lp')
        a = signal.sosfilt(signal.butter(2, 140, btype='highpass', fs=SR,
                                         output='sos'), a)
        _put_moving(m, 0.0, 0.09 * a * swell, side * 0.6 * (1 - x))
    # Thrown out: a streak of air leaving, quick in, carried off to a side.
    out = (0.7, -0.7, -0.6, 0.65)[v]
    swish(m, gulp - 0.008, 0.32, lambda u: 1700 - 900 * u, 0.4,
          lambda u: smooth(u, 0, 0.06) * np.exp(-u / 0.3) * _cos_out((u - 0.6) / 0.4),
          0.12, pan=out * 0.6)
    m.room(t60=0.35, wet=0.08, darkness=2400)
    return m.finish(loudness_db=-33.0, fade_out=0.08)


# ===========================================================================
# The game picks the special's file by element: None is the family-level
# sfx_special_mask (the scatter, the shape most Masks cast); the rest are
# sfx_special_mask_<pattern>.
# ===========================================================================

SPECIAL_PATTERNS = {
    'Air': None, 'Lava': None, 'Poison': None, 'Crystal': None, 'Fire': None,
    'Steam': None, 'Water': None, 'Mud': None, 'Earth': None, 'Spirit': None,
    'Light': 'single', 'Dark': 'single', 'Lightning': 'single',
    'Blood': 'single', 'Ice': 'single',
    'Plant': 'feed',
    'Dust': 'wrap',
}

# Which elements' traps have a spring cue (sfx_special_mask_spring_<x>).
SPRING_ELEMENTS = ('Light', 'Crystal', 'Fire', 'Water', 'Dark')


def _v(build, description):
    return {'build': build, 'description': description, 'variants': 3}


CUES = {
    'sfx_basic_mask': _v(
        basic, 'A breath through a narrow tube and a thin needle tearing the air, receding'),
    'sfx_special_mask': (
        special_scatter, 'A sowing sweep and many soft set-downs across the field at once; the ground answers'),
    'sfx_special_mask_single': (
        special_single, 'One aimed sweep and one weighty set-down, the floor giving under it'),
    'sfx_special_mask_feed': (
        special_feed, 'Fibres parting at the root and a thick trunk groaning as it swells'),
    'sfx_special_mask_wrap': (
        special_wrap, 'Air circling round and five small stones knocking into their orbit'),
    'sfx_special_mask_spring_light': _v(
        spring_light, 'A bright incision tearing, then air drawn into the slit, cut off'),
    'sfx_special_mask_spring_crystal': _v(
        spring_crystal, 'A crystal cracks and breaks; three pieces land apart'),
    'sfx_special_mask_spring_fire': _v(
        spring_fire, 'A fire ball bursts into a pool: a flaring whumpf, flame spreading, embers'),
    'sfx_special_mask_spring_water': _v(
        spring_water, 'A splash: the surface slapped open, bubbles, drops falling back'),
    'sfx_special_mask_spring_dark': _v(
        spring_dark, 'A gulp that closes off, then a streak of air thrown out to one side'),
}
