"""Kin -- the Rare Support family: its charged line, and the seventeen
supports it sets running, each scored to what the game draws.

THE BASIC (identical in all three modes)
  * The kin locks still and GATHERS for KinLaser.chargeTime (1.5 s): a glow
    swelling 18 -> 30 px with six motes drawn into it, cycling faster as it
    fills (1.0 -> 2.5 cycles a second, drawKinCharge). Silent until now.
  * It RELEASES: one thin lit line (drawKinLaser), at full at once and fading
    linearly over KinLaser.beamLife = 0.28 s (the dungeon's _KinBeamFx: 0.34 s).
    Every body on the line is struck on the release frame (their hit cue is
    combatHitLight/Heavy, played by _damageEnemy -- not here).
  * Cadence: cooldown (1.5 s / power factor) + the 1.5 s charge, so ~2-3 s a
    shot per kin -- the least frequent basic in the game.
  So it is two cues: sfx_basic_kin_charge, the last GATHER seconds of the
  charge (light drawn in, pressure narrowing), and sfx_basic_kin, the line let
  go -- a narrow sear that is at full at once and dies with the beam's alpha.

THE SPECIALS
  Every kin cast heals (combatHeal already sounds that, via _recordHeal) and
  blesses, then sets running ONE build-defining support whose shape differs
  per element (the design contract, project_kin_specials_design.md). Most are
  not projectiles at all. Each support shape is its own cue, its material
  chosen by what the support IS -- never the element's own material, which
  the element accent (sfx_element_<x>) still layers on top:

    escort   Light, Crystal  2-5 guards set orbiting the kin, then peel off to
                             the ship (spin-up 1.2-1.8 s)          air turned
    rain     Water           a cloud forms over the ship and rain starts on
                             the hull                              droplets
    updraft  Air             a wind column takes hold round the ship, debris
                             lifted up it                          roar+debris
    garden   Plant           shoots push up through soil at the kin's feet
                                                                   loam, roots
    wall     Earth           7-11 wall sections laid along a 120 deg arc
                                                                   stone set
    bank     Dust            a dust bank settles over the target   powder
    darts    Poison          8-16 homing darts spat out all round  spits, zips
    charge   Ice             a 2.8-4.6 s locked charge, frost drawn in
                             (+ sfx_special_kin_ice_release on the release)
    channel  Lightning       a 10-14 s tesla channel held on the kin  corona
    plate    Lava            molten plate seated on every companion basalt
    boiler   Steam           the boiler shut and made ready to take pressure
                                                                   cast iron
    sling    Mud             mud slung onto the ship, its trail starting  wet
    veil     Dark            a shadow drawn over the kin and the party  cloth
    pact     Blood           threads drawn taut between every living ally
                                                                   sinew cord
    wisp     Spirit          a soul-flame kindled to orbit the kin  a wick
                             (+ sfx_special_kin_wisp_tier when it grows)
    (Fire)   never casts (isPassiveOnlyCosmicAbility); its moment is the
             phoenix save -> sfx_special_kin_phoenix

  sfx_special_kin is the family-level cast (the blessing welling up), used
  only where an element has no pattern (Fire, which never casts) or one is
  ever missing.

Voices added here: _flame (turbulent combustion), _rustle (cloth/fibre
friction), _drops (rain), plus a moving-pan placement; the rest are the
combat voices (strike/chips/swish/burst/creak) and the elements' bubbles.
"""
import math
import warnings

import numpy as np
from scipy import signal

from sounds.combat import _fracture, _shards, _solid, burst, chips, creak, strike, swish
from sounds.core import SR, Mix, smooth
from sounds.elements import _bubbles, _pops

# -- timing, from the Dart ---------------------------------------------------

CHARGE = 1.5         # KinLaser.chargeTime
GATHER = 0.6         # the charge cue covers the charge's last 0.6 s...
CHARGE_CUE_AT = CHARGE - GATHER  # ...so it is fired 0.9 s into the charge
BEAM_LIFE = 0.28     # KinLaser.beamLife: alpha 1 -> 0, linear
ESCORT_SPIN = 1.5    # _kinEscortSpinUpDuration: 1.2 + 0.6 x progress
ESCORT_W = 2.2       # orbitSpeed rad/s (Light 2.2, Crystal 2.6)
ICE_MIN = 2.8        # iceChargeDuration: 4.0 x 0.70 .. 1.15
ICE_SHARD = 0.65     # emitKinIceRelease: frost travels 0.55-0.75 s
TESLA_PULSE = 14.0   # drawKinSupportEffects: pulse sin(time * 14)
TESLA_STEP = 16.0    # the coil's arcs are redrawn 16 times a second
PACT_W = 3.0         # drawKinBloodThreads: pulse sin(time * 3)
MUD_PATCH = 0.35     # KinSupport.mudPatchInterval
WISP_W = 1.8         # spiritWisp orbitSpeed rad/s
PHOENIX_EMBERS = 24  # emitKinPhoenixBurst: 24 embers, 0.55-0.95 s
FLAME_W = 3.2        # the reborn flames circle at time * 3.2

# Which special cue each element's cast plays (None -> sfx_special_kin).
SPECIAL_PATTERNS = {
    'Light': 'escort',
    'Crystal': 'escort',
    'Water': 'rain',
    'Air': 'updraft',
    'Plant': 'garden',
    'Earth': 'wall',
    'Dust': 'bank',
    'Poison': 'darts',
    'Ice': 'charge',
    'Lightning': 'channel',
    'Lava': 'plate',
    'Steam': 'boiler',
    'Mud': 'sling',
    'Dark': 'veil',
    'Blood': 'pact',
    'Spirit': 'wisp',
    'Fire': None,  # passive only: never casts
}


# ===========================================================================
# Voices
# ===========================================================================

def _sos(kind, f, order=2):
    return signal.butter(order, f, btype=kind, fs=SR, output='sos')


def _place(m, start, mono, pan):
    """[mono] into [m] at [start], panned by [pan] -- a number, or an array
    as long as [mono] for something that moves across the field."""
    s0 = m._at(start)
    mono = mono[: m.n - s0]
    p = np.clip(np.broadcast_to(pan, mono.shape)[: len(mono)], -1, 1)
    m.y[0, s0:s0 + len(mono)] += np.cos((p + 1) * math.pi / 4) * mono
    m.y[1, s0:s0 + len(mono)] += np.sin((p + 1) * math.pi / 4) * mono


def _band(rng, length, fc, width):
    """Noise whose band slides with fc(u) (u = 0..1): swish's air, returned
    mono and unit-ish so it can be moved and shaped here."""
    n = round(length * SR)
    nper, hop, pad = 512, 128, 512
    noise = rng.normal(0, 1, n + 2 * pad)
    f, tt, z = signal.stft(noise, fs=SR, nperseg=nper, noverlap=nper - hop,
                           boundary=None, padded=False)
    u = np.clip((tt - pad / SR) / length, 0, 1)
    centre = np.log(np.maximum(fc(u), 50))
    logf = np.log(np.maximum(f, 20))[:, None]
    shape = np.exp(-0.5 * ((logf - centre[None, :]) / width) ** 2)
    shape /= np.sqrt(np.maximum(f, 100) / 1000)[:, None]
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', UserWarning)
        _, y = signal.istft(z * shape, fs=SR, nperseg=nper,
                            noverlap=nper - hop, boundary=False)
    y = y[pad:pad + n]
    return y * 0.15 / max(float(np.sqrt(np.mean(y ** 2))), 1e-12)


def _wobble(rng, n, rate, depth):
    """A slow random flutter around 1: turbulence, a flame's lick, a coil's
    pulse that is never quite regular."""
    w = signal.sosfilt(_sos('lowpass', rate), rng.normal(0, 1, n))
    w /= max(float(np.std(w)), 1e-9)
    return np.clip(1 + depth * w, 0.05, 3)


def _flame(m, start, length, lo, hi, env, amp, pan=0.0, flutter=9.0,
           depth=0.55):
    """Turbulent combustion: a band of noise whose level licks and gutters
    [flutter] times a second -- a flame, not a hiss. env(u) over 0..1."""
    n = round(length * SR)
    u = np.arange(n) / max(n - 1, 1)
    x = signal.sosfilt(_sos('bandpass', [lo, hi]), m.rng.normal(0, 1, n))
    x *= _wobble(m.rng, n, flutter, depth) * env(u)
    _place(m, start, amp * x, pan)


def _rustle(m, start, length, density, band, amp, pan=0.0):
    """Fibres catching on fibres: cloth drawn over something, a cord
    tightening. density(u) catches a second, each a few milliseconds of
    noise swelling and going -- they overlap into a dry rasp, never a train
    of clicks, and never resonant grains."""
    n = round(length * SR)
    u = np.arange(n) / max(n - 1, 1)
    hits = m.rng.poisson(np.maximum(density(u), 0) / SR)
    exc = hits * np.minimum(m.rng.lognormal(0, 0.4, n), 2.0)
    k = round(0.003 * SR)
    # Room for the last catches and the band's ring to finish: cutting them
    # off is a hard edge right across the top of the spectrum.
    tail = k + round(0.01 * SR)
    env = np.zeros(n + tail)
    full = signal.fftconvolve(exc, np.hanning(k))
    env[:len(full)] = full
    x = signal.sosfilt(_sos('bandpass', band),
                       m.rng.normal(0, 1, n + tail) * env)
    _place(m, start, amp * 0.05 * x, pan)


def _drops(m, start, length, rate, amp, pan=(-0.6, 0.6)):
    """Rain on a hull: each drop a small dull tap on the plate, all much of a
    size. rate(u) drops a second over u = 0..1 of [length]."""
    rng = m.rng
    t = 0.0
    events = []
    while t < length:
        r = max(rate(t / length), 0.0)
        t += rng.exponential(1 / 120)
        if t < length and rng.random() < r / 120:
            events.append(t)
    # Drops are all much of a size: a big outlier is a click on the hull.
    taps = [(start + t0, amp * min(rng.lognormal(-2.2, 0.35), 0.2),
             rng.uniform(*pan)) for t0 in events]
    chips(m, taps, 1600, 4200, eta=0.12, n=2, tc=0.0005, cap=0.006,
          lowpass=5200)
    return events


def _vary(v, *xs):
    return xs[v % len(xs)]


# ===========================================================================
# The basic: the charge's last breath, then the line
# ===========================================================================
#
# Both fire through SoundCue's family-basic rules (gain .34, priority 0,
# 110 ms cooldown): they may be dropped in a crowd, and are built to be.

def basic_kin_charge(v=0):
    """The last GATHER seconds of the kin's 1.5 s charge: light drawn in.

    The motes (drawKinCharge) cycle faster and faster into the glow, so their
    arrivals tighten from a few to a stream; the air narrows and rises like
    pressure being taken up. Ends on the release frame, where sfx_basic_kin
    takes over -- so it stops rather than resolving.
    """
    m = Mix(GATHER, seed=6400 + v)
    rng = m.rng
    # Motes arriving at the core: sparse at first, a stream at the end.
    m.grains(lambda t: 10 + 140 * (t / GATHER) ** 2.2,
             lambda t: 0.62 + 0.25 * t / GATHER,
             lambda t: _vary(v, -0.12, 0.1, 0.0, 0.15) + 0 * t,
             amp=0.22, weight=lambda t: 0.4 + 0.8 * (t / GATHER) ** 1.5)
    # The air drawn in, its band narrowing and rising.
    lift = rng.uniform(0.92, 1.08)
    swish(m, 0.0, GATHER, lambda u: lift * (1100 + 2300 * u ** 1.6), 0.4,
          lambda u: u ** 2.2, 0.09)
    m.room(t60=0.3, wet=0.08)
    return m.finish(loudness_db=-38.0, fade_out=0.02)


def basic_kin(v=0):
    """The line let go (drawKinLaser, 0.28 s).

    0       a breath of pressure out of the core, leaning in over ~8 ms
    0       the sear: a narrow band of tearing air, at full at once (the line
            is drawn whole on the release frame) and dying as the beam's
            alpha does -- linearly, gone at 0.28 s
    0-0.25  a fine sizzle along it, thinning with the light
    """
    m = Mix(0.4, seed=6410 + v)
    rng = m.rng
    hi = _vary(v, 3400, 3100, 3700, 3250) * rng.uniform(0.97, 1.03)
    burst(m, 0.0, 450, 2400, attack=0.008, tau=0.022, amp=0.05)

    def sear_env(u):
        t = u * 0.36
        on = np.clip(t / 0.008, 0, 1) ** 2
        return on * np.clip(1 - t / BEAM_LIFE, 0, 1) ** 1.15

    # The line lights along its length: the band settles from a touch higher
    # in the first ~30 ms, then holds while it fades. It burns rather than
    # hisses: its level rasps irregularly a hundred-odd times a second, the
    # way an arc does.
    n = round(0.36 * SR)
    u = np.arange(n) / (n - 1)
    sear = _band(rng, 0.36, lambda u: hi * (1 + 0.25 * np.exp(-u * 0.36 / 0.03)),
                 0.2)
    rasp = signal.sosfilt(_sos('bandpass', [70, 220]), rng.normal(0, 1, n))
    rasp = np.clip(1 + 0.6 * rasp / np.std(rasp), 0.1, 2.5)
    _place(m, 0.0, 0.08 * sear * rasp * sear_env(u),
           _vary(v, 0.05, -0.05, 0.1, -0.1))
    # A body under the sear, lower and wider: the air the line burns through.
    swish(m, 0.0, 0.36, lambda u: 1300 + 0 * u, 0.45, sear_env, 0.03)
    fizz = sorted(BEAM_LIFE * rng.random(18) ** 1.5)
    chips(m, [(t0, 0.06 * (1 - t0 / BEAM_LIFE) + 0.01, rng.uniform(-0.3, 0.3))
              for t0 in fizz], 3200, 7000, eta=0.2, n=2, tc=0.00018, cap=0.003)
    m.room(t60=0.3, wet=0.1)
    return m.finish(loudness_db=-35.0, fade_out=0.06)


# ===========================================================================
# The family-level cast: a blessing welling up
# ===========================================================================

def special_kin():
    """drawBlessing: healing light welling up round the kin, motes lifting
    off it. A soft warm swell that rises in band as it lifts, and a few fine
    motes carried up and away. No glass: combatHeal already brings that."""
    m = Mix(1.5, seed=6500)
    m.air(0.0, 1.25, 300, 1500, amp=0.07, rise=0.35)
    swish(m, 0.05, 1.2, lambda u: 700 + 1500 * u, 0.45,
          lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.7) ** 2, 0.08)
    m.grains(lambda t: 70 * np.exp(-((t - 0.55) / 0.3) ** 2),
             lambda t: 0.6 + 0.3 * np.clip(t / 1.2, 0, 1),
             lambda t: 0.3 * np.sin(2.2 * t), amp=0.25,
             weight=lambda t: 0.6 + 0 * t)
    m.room(t60=0.8, wet=0.2)
    return m.finish(loudness_db=-31.0, fade_out=0.3)


# ===========================================================================
# The supports
# ===========================================================================

def special_escort():
    """Light's lanterns / Crystal's refractors (_kinStagedOrbitals): 2-5
    guards appear round the kin at once and are set turning (2.2 rad/s), then
    at the end of the spin-up (~1.5 s) peel off to orbit the ship.

    0       a soft release of air: they are let go into their orbit
    0-1.5   three bodies turning round the kin -- each a band of air with a
            flutter on it, its pan following its place on the circle and
            louder on the near side
    1.5-2.3 they draw off to the ship: the bands fall and dull and gather to
            one place
    """
    m = Mix(2.4, seed=6510)
    rng = m.rng
    burst(m, 0.0, 300, 1700, attack=0.025, tau=0.09, amp=0.06)
    n = m.n
    t = m.t
    away = smooth(t, ESCORT_SPIN, ESCORT_SPIN + 0.6)
    for k in range(3):
        phase = 2 * math.pi * k / 3
        ang = ESCORT_W * t + phase
        # Each passes the near side once a turn (at 0, ~0.95 and ~1.9 s):
        # louder and a touch higher coming in, lower going away.
        f0 = (1500, 1900, 2400)[k] * rng.uniform(0.95, 1.05)
        doppler = 1 + 0.12 * np.sin(ang)
        fall = 1 - 0.45 * smooth(t, ESCORT_SPIN, ESCORT_SPIN + 0.7)
        curve = f0 * doppler * fall
        x = _band(rng, n / SR,
                  lambda u, c=curve: np.interp(u, np.linspace(0, 1, n), c), 0.18)
        flutter = _wobble(rng, n, 8.0, 0.35)
        near = 0.2 + 0.8 * ((1 + np.cos(ang)) / 2) ** 3
        near = near * (1 - away) + 0.5 * away
        env = smooth(t, 0.0, 0.18) * (1 - 0.85 * away) * near * flutter
        pan = (1 - away) * 0.7 * np.sin(ang) + away * 0.35
        _place(m, 0.0, 0.06 * x * env, pan)
    m.room(t60=0.7, wet=0.18)
    return m.finish(loudness_db=-31.0, fade_out=0.35)


def special_rain():
    """Water's rain cloud (_drawRainCloud, rides the ship): the cloud forms,
    and rain starts falling on the hull below it -- twelve drops in the air
    at a time, each falling for ~0.6 s.

    0-0.5   the cloud gathering: a low soft swell
    0.25    the first drops; a patter by ~0.7 s, holding, then thinning by
            ~2.4 s (the cloud lives 3-6.5 s; the cue leaves it to the eye)
    """
    m = Mix(2.6, seed=6520)
    m.air(0.0, 0.8, 220, 1100, amp=0.018, rise=0.6)

    def rate(u):
        t = u * 2.4
        return 110 * smooth(t, 0.25, 0.7) * (1 - smooth(t, 1.5, 2.4))

    _drops(m, 0.0, 2.4, rate, 1.0)
    # Now and then one lands in the wet on the hull: a small bubble's ring.
    _bubbles(m, 0.3, 2.0, 30, 1400, 3600, 0.012, tau_cycles=(4, 9),
             rise=(0.05, 0.2), pan=(-0.6, 0.6),
             shape=lambda x: smooth(x, 0.0, 0.2) * (1 - smooth(x, 0.55, 1.0)))
    # The wet hiss of it all.
    m.air(0.35, 2.1, 2400, 7500, amp=0.012, rise=0.3)
    m.room(t60=0.6, wet=0.18)
    return m.finish(loudness_db=-31.0, fade_out=0.4)


def special_updraft():
    """Air's updraft column (_drawUpdraft, rides the ship): gusts spiral round
    its foot at 2.2 rad/s and debris is carried up it, each piece rising for
    ~1.4 s and thinning out as it goes.

    0-0.4   the column takes hold: a low roar leaning in
    0-2.4   it turns (the roar circles the field) and rises a little
    0.2-    leaves and grit ticking as they are lifted, brighter and fainter
            the higher they go
    """
    m = Mix(2.7, seed=6530)
    rng = m.rng
    n = m.n
    t = m.t
    hold = smooth(t, 0.0, 0.4) * (1 - smooth(t, 1.7, 2.6))
    roar = _band(rng, n / SR, lambda u: 260 + 260 * smooth(u * n / SR, 0, 0.9)
                 + 160 * u, 0.45)
    _place(m, 0.0, 0.11 * roar * hold * _wobble(rng, n, 3.0, 0.25),
           0.45 * np.sin(2.2 * t))
    inner = _band(rng, n / SR, lambda u: 1200 + 900 * u, 0.3)
    _place(m, 0.0, 0.03 * inner * hold * _wobble(rng, n, 5.0, 0.4),
           -0.45 * np.sin(2.2 * t))
    # Seven pieces of debris, each lifted for ~1.4 s, ticking as they go.
    events = []
    for i in range(7):
        t0 = 0.2 + i * 0.22 + rng.uniform(0, 0.08)
        for j in range(rng.integers(3, 6)):
            tt = t0 + j * rng.uniform(0.08, 0.2)
            if tt > 2.4:
                break
            up = (tt - t0) / 1.4
            events.append((tt, 0.12 * (1 - 0.7 * up) * rng.uniform(0.6, 1.0),
                           float(np.clip(0.45 * math.sin(2.2 * tt) + rng.normal(0, 0.2), -1, 1))))
    chips(m, events, 1500, 5000, eta=0.22, n=2, tc=0.0003, cap=0.006)
    m.room(t60=0.6, wet=0.15)
    return m.finish(loudness_db=-31.0, fade_out=0.45)


def special_garden():
    """Plant's healing garden (a ward at the kin's feet): its shoots push up
    and ripen into buds. Soil heard opening -- damp loam crumbling over
    shoots pushing up, the fibrous strain of roots taking hold -- and then
    settling. The element accent carries the leaves; this is the ground."""
    m = Mix(1.9, seed=6540)
    rng = m.rng
    m.air(0.0, 1.0, 140, 700, amp=0.05, rise=0.4)
    # Clods of damp loam turning over: dull, quick, no ring.
    clods = sorted(0.04 + rng.gamma(2.2, 0.17, 30))
    chips(m, [(t0, rng.uniform(0.15, 0.4) * math.exp(-(t0 - 0.2) / 0.8),
               rng.uniform(-0.5, 0.5)) for t0 in clods if t0 < 1.5],
          280, 1100, eta=0.14, n=3, tc=0.0012, cap=0.025, lowpass=2400)
    # Fine crumbs of it, falling back.
    m.grains(lambda t: 220 * np.exp(-((t - 0.45) / 0.35) ** 2),
             lambda t: 0.08 + 0 * t, lambda t: 0.0 * t, amp=0.18,
             weight=lambda t: 0.5 + 0 * t)
    # Roots straining as they take hold: a slow fibrous creak.
    creak(m, 0.12, 1.0, lambda u: 25 + 40 * u, 0.6,
          _solid(rng, 240, n=10, eta=0.09, cap=0.035), 0.5,
          lambda u: np.sin(math.pi * u) ** 1.5, pan=-0.15)
    m.room(t60=0.6, wet=0.15)
    return m.finish(loudness_db=-31.0, fade_out=0.35)


def special_wall():
    """Earth's wall (KinSupport.earthWallArc): 7-11 sections laid at once
    along a 120 deg arc round what it guards. Heard as the rampart heaved up
    along the arc, left to right in ~0.35 s: stone grinding up out of the
    ground, each section seating dully as the grind passes it, grit running
    off. Weight from many damped low modes and friction, never a pitched
    thump -- and the knocks are irregular and under the grind, so the row
    does not read as a roll."""
    m = Mix(1.6, seed=6550)
    rng = m.rng
    sweep = 0.35
    # The grind, in three overlapping lengths of the arc.
    for k, pan in enumerate((-0.6, 0.0, 0.6)):
        creak(m, 0.01 + k * 0.1, 0.42,
              lambda u: 260 + 160 * np.sin(math.pi * u), 0.55,
              _solid(rng, 190 + 25 * k, n=16, spread=(0.08, 0.3), eta=0.07,
                     cap=0.04), 0.3,
              lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.6) ** 2, pan)
    count = 9
    for i in range(count):
        u = i / (count - 1)
        t0 = 0.05 + sweep * u ** 0.9 + rng.uniform(-0.012, 0.018)
        pan = -0.75 + 1.5 * u
        strike(m, t0, _solid(rng, rng.uniform(170, 240), n=18,
                             spread=(0.08, 0.3), eta=0.08, cap=0.05, tilt=0.08),
               tc=rng.uniform(0.003, 0.005), amp=rng.uniform(0.35, 0.5),
               pan=pan, lowpass=2000)
        # Grit off the section as it seats.
        chips(m, [(t0 + rng.uniform(0.01, 0.12), rng.uniform(0.04, 0.09),
                   pan + rng.uniform(-0.2, 0.2)) for _ in range(3)],
              1200, 3600, eta=0.08, n=3, tc=0.0004, cap=0.02)
    m.air(0.0, 1.0, 200, 1100, amp=0.035, rise=0.25)
    m.room(t60=0.7, wet=0.2)
    return m.finish(loudness_db=-29.0, fade_out=0.35)


def special_bank():
    """Dust's cloud (KinSupport.dustCloud): a 160 px bank appears over the
    target, far from the kin, and grit turns slowly inside it for 30 s.
    A muffled billow -- a mass of powder settling, heard from a distance --
    and the fine grit left hanging in it, drifting. (The element accent is
    the dry whoosh of dust in the wind; this is the bank coming to rest.)"""
    m = Mix(2.1, seed=6560)
    m.air(0.0, 1.1, 180, 1000, amp=0.09, rise=0.22)
    swish(m, 0.02, 1.4, lambda u: 800 - 380 * u, 0.6,
          lambda u: np.where(u < 0.15, (u / 0.15) ** 2,
                             np.exp(-(u - 0.15) / 0.3)), 0.07)
    # Grit hanging in it: literally grains here.
    m.grains(lambda t: 380 * smooth(t, 0.05, 0.3) * np.exp(-np.maximum(t - 0.3, 0) / 0.6),
             lambda t: 0.82 + 0 * t, lambda t: 0.5 * np.sin(0.9 * t + 0.5),
             amp=0.2, weight=lambda t: 0.5 + 0 * t)
    m.room(t60=0.9, wet=0.28, darkness=3000)
    return m.finish(loudness_db=-31.0, fade_out=0.45)


def special_darts():
    """Poison's venom swirl: 8-16 darts (twelve here) leave the kin all
    round at once and home on bodies, living 2.6 s. A ring of small wet
    spits rippling round the field in ~70 ms -- each a puff and a wet click
    -- and the darts' thin zips going out and away. Their hits are
    combatHit's, not this."""
    m = Mix(1.0, seed=6570)
    rng = m.rng
    count = 12
    for k in range(count):
        a = 2 * math.pi * k / count
        pan = 0.8 * math.sin(a)
        t0 = 0.006 * k + rng.uniform(0, 0.005)
        burst(m, t0, 700, 3000, attack=0.002, tau=0.007, amp=0.035, pan=pan)
        chips(m, [(t0, rng.uniform(0.05, 0.09), pan)], 900, 2200, eta=0.18,
              n=2, tc=0.0004, cap=0.006)
        f = rng.uniform(3300, 4300)
        swish(m, t0 + 0.004, 0.4, lambda u, f=f: f * (1 - 0.35 * u), 0.18,
              lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.25) ** 2 * (1 - u),
              0.018, pan=float(np.clip(pan * 1.15, -1, 1)))
    m.room(t60=0.4, wet=0.12)
    return m.finish(loudness_db=-30.0, fade_out=0.2)


def special_ice_charge():
    """Ice's charge: the kin is locked for 2.8-4.6 s while seven frost shards
    are drawn in round it and the frost brightens (drawKinSupportEffects,
    iceChargeProgress). Cold tightening: frost forming finer and denser,
    the strain of it as a slow creak, the air drawn in and narrowing. It
    builds to the shortest charge (2.8 s) and holds there faintly, so a
    longer charge is not left with a climax that came too soon; the release
    is its own cue, on its own frame."""
    m = Mix(3.4, seed=6580)
    rng = m.rng
    m.grains(lambda t: 30 + 320 * smooth(t, 0.0, ICE_MIN),
             lambda t: 0.82 + 0.12 * smooth(t, 0, ICE_MIN),
             lambda t: 0.25 * np.sin(0.4 * t * 2 * math.pi / 3),
             amp=0.3, weight=lambda t: 0.3 + 0.7 * smooth(t, 0, ICE_MIN))
    # The strain: short creaks, each in a different piece of the ice (its
    # own modes, so no pitch carries from one to the next), closer together
    # and harder as the charge fills.
    t0 = 0.5
    while t0 < 3.0:
        grow = smooth(t0, 0.3, ICE_MIN)
        span = rng.uniform(0.08, 0.2)
        creak(m, t0, span, lambda u, g=grow: 30 + 60 * g, 0.6,
              _solid(rng, rng.uniform(380, 950), n=10, spread=(0.15, 0.5),
                     eta=0.06, cap=0.02), 0.1 + 0.16 * grow,
              lambda u: np.sin(math.pi * np.clip(u, 0, 1)) ** 2,
              pan=rng.uniform(-0.4, 0.4))
        t0 += span + rng.uniform(0.25, 0.5) * (1.2 - 0.7 * grow)
    # Frost forming: a fine crackle thickening.
    _pops(m, 0.2, 2.9, 90, 2500, 7000, 0.035,
          shape=lambda x: 0.1 + 0.9 * min(1.0, x * 2.9 / ICE_MIN) ** 1.5,
          pan=(-0.5, 0.5))
    swish(m, 0.0, 3.3, lambda u: 2200 + 3000 * np.minimum(u * 3.3 / ICE_MIN, 1), 0.35,
          lambda u: smooth(u * 3.3, 0, ICE_MIN) ** 1.5, 0.04)
    m.room(t60=0.6, wet=0.15)
    return m.finish(loudness_db=-33.0, fade_out=0.6)


def special_ice_release():
    """Ice's release (emitKinIceRelease): frost shoots from the kin to every
    body it slowed (0.55-0.75 s) and a sheen spreads out round it. A frozen
    sheet giving all at once -- the crack leans in over ~30 ms -- the cold
    rushing outward, and fine ice thrown wide, thinning as it reaches its
    marks. Small, dense pieces: never a chime."""
    m = Mix(1.4, seed=6590)
    rng = m.rng
    chips(m, _fracture(0.0, 0.03, 10, 0.05, 0.28, -0.3, 0.3),
          1500, 4500, eta=0.02, n=4, tc=0.0004, cap=0.03)
    strike(m, 0.03, _solid(rng, 640, n=12, spread=(0.15, 0.45), eta=0.06,
                           cap=0.035), tc=0.0015, amp=0.22, lowpass=4000)
    swish(m, 0.02, ICE_SHARD + 0.25, lambda u: 3200 - 1500 * u, 0.5,
          lambda u: np.where(u < 0.05, (u / 0.05) ** 2,
                             np.exp(-(u - 0.05) / 0.35)), 0.09)
    chips(m, _shards(rng, 0.03, 30, 0.22, 0.13, 0.95, ICE_SHARD + 0.15),
          2600, 7000, eta=0.012, n=3, tc=0.0003, cap=0.04)
    m.room(t60=0.8, wet=0.2)
    return m.finish(loudness_db=-29.0, fade_out=0.3)


def special_channel():
    """Lightning's tesla channel: for 10-14 s the kin is locked with a coil
    of arcs round it (redrawn 16 times a second, pulsing at 14 rad/s) and the
    ship crackles with it. The charge taking hold and held: a corona's hiss
    and arcs crawling on it -- each a quick cluster of tiny discharges --
    densest as it catches, then held on the pulse and let fade (a one-shot
    cannot hold 10 s; the picture keeps it). The element accent is the
    discharge; this is the charge that stays."""
    m = Mix(2.4, seed=6600)
    rng = m.rng
    t = m.t
    hold = smooth(t, 0.0, 0.3) * (0.55 + 0.45 * np.exp(-np.maximum(t - 0.3, 0) / 0.35))
    hold *= 1 - smooth(t, 1.2, 2.35)
    pulse = 0.75 + 0.25 * np.sin(TESLA_PULSE * t)
    hiss = _band(rng, m.n / SR, lambda u: 4200 + 0 * u, 0.35)
    # A corona does not hiss evenly: it buzzes, its level rasping a hundred-
    # odd times a second.
    rasp = signal.sosfilt(_sos('bandpass', [80, 240]), rng.normal(0, 1, m.n))
    rasp = np.clip(1 + 0.7 * rasp / np.std(rasp), 0.05, 2.6)
    _place(m, 0.0, 0.032 * hiss * rasp * hold * pulse, 0.0)
    events = []
    tt = 0.0
    while tt < 2.3:
        tt += rng.exponential(1 / TESLA_STEP) * (0.5 if tt < 0.3 else 1.0)
        i = min(int(tt * SR), m.n - 1)
        lvl = hold[i] * pulse[i]
        pan = rng.uniform(-0.45, 0.45)
        for _ in range(rng.integers(3, 8)):
            events.append((tt + rng.uniform(0, 0.02),
                           0.09 * lvl * rng.uniform(0.4, 1.0), pan))
    chips(m, events, 2500, 8000, eta=0.3, n=2, tc=0.00015, cap=0.002)
    m.room(t60=0.4, wet=0.12)
    return m.finish(loudness_db=-31.0, fade_out=0.4)


def special_plate():
    """Lava's molten plate (drawKinLavaPlate): five dark plates seat round
    every companion at once and the ship starts to glow; struck, they will
    splash back. Heavy basalt plates closing on the bodies -- a tight
    cluster of dense, dull knocks per body, irregularly apart -- with the
    heat in their seams as a low warm breath and a faint tick of cooling.
    The element accent brings the molten glorp; this is the armour."""
    m = Mix(1.3, seed=6610)
    rng = m.rng
    for g, (t0, pan) in enumerate(((0.0, -0.5), (0.11, 0.45), (0.27, -0.05))):
        for j in range(3):
            strike(m, t0 + j * rng.uniform(0.012, 0.022),
                   _solid(rng, rng.uniform(360, 520), n=12, eta=0.06,
                          cap=0.05, tilt=0.15),
                   tc=rng.uniform(0.0012, 0.002), amp=rng.uniform(0.18, 0.3),
                   pan=pan + rng.uniform(-0.1, 0.1), lowpass=3000)
        m.air(t0, 0.8, 200, 900, amp=0.025, rise=0.2, pan=pan)
    _pops(m, 0.1, 1.0, 40, 1500, 5000, 0.03,
          shape=lambda x: math.exp(-2.5 * x), pan=(-0.6, 0.6))
    m.room(t60=0.6, wet=0.15)
    return m.finish(loudness_db=-30.0, fade_out=0.3)


def special_boiler():
    """Steam's boiler: nothing is drawn at the cast -- the pressure (vents
    thickening, the N/10 badge) comes as the party is struck. So this is
    the vessel made ready: a heavy iron hatch swung to and seated, its
    wheel turned down (the pawl ticking slower as it tightens), a last
    small seat, and pressure beginning to swell inside. Cast iron, heavily
    damped: a clank, never a bell. The element accent is the vapour.

    0       the hatch swings in on its hinge (~60 ms of friction)
    0.065   it lands: a dense, dull iron clank
    0.3-0.9 the wheel: five pawl ticks, slowing
    1.0     seated
    0.9-1.6 the pressure taking up: a low swell, faintly unsteady
    """
    m = Mix(1.7, seed=6620)
    rng = m.rng
    swish(m, 0.0, 0.08, lambda u: 900 + 500 * u, 0.4,
          lambda u: np.clip(u, 0, 1) ** 2, 0.06)
    strike(m, 0.065, _solid(rng, 260, n=24, spread=(0.06, 0.25), eta=0.045,
                            cap=0.07, tilt=0.07),
           tc=0.003, amp=0.3, lowpass=2600)
    burst(m, 0.065, 300, 2000, attack=0.003, tau=0.025, amp=0.05)
    # The wheel: each pawl tick its own small iron, so no pitch repeats.
    for k, t0 in enumerate((0.3, 0.41, 0.54, 0.7, 0.9)):
        chips(m, [(t0 + rng.uniform(-0.01, 0.01), 0.09 - 0.01 * k,
                   0.15 + rng.uniform(-0.1, 0.1))],
              1300, 2600, eta=0.03, n=4, tc=0.0005, cap=0.02)
    # The thread grinding under the wheel between the ticks.
    swish(m, 0.28, 0.66, lambda u: 1800 - 500 * u, 0.5,
          lambda u: np.sin(math.pi * np.clip(u, 0, 1)) ** 2, 0.012, pan=0.15)
    strike(m, 1.0, _solid(rng, 380, n=14, eta=0.05, cap=0.05),
           tc=0.002, amp=0.06, lowpass=3000)
    # Pressure taking up inside.
    n = round(0.8 * SR)
    tt = np.arange(n) / SR
    groan = signal.sosfilt(_sos('bandpass', [220, 700]), rng.normal(0, 1, n))
    groan *= _wobble(rng, n, 4.0, 0.4) * np.sin(math.pi * tt / 0.8) ** 2
    _place(m, 0.9, 0.014 * groan, 0.0)
    m.room(t60=0.7, wet=0.2, darkness=3000)
    return m.finish(loudness_db=-31.5, fade_out=0.3)


def special_sling():
    """Mud's ship enchant: the kin slings mud onto the ship, and the ship
    drops a slowing patch every 0.35 s for 5 s or so. The throw, a broad wet
    slap onto the hull (its plate heard dully under it), then the trail
    starting -- soft wet pats on the patch beat, fading as the cue leaves
    the rest of the trail to the eye."""
    m = Mix(2.4, seed=6630)
    rng = m.rng
    swish(m, 0.0, 0.16, lambda u: 500 + 700 * np.sin(math.pi * u), 0.5,
          lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.6) ** 2, 0.05,
          pan=-0.3)
    land = 0.15
    burst(m, land - 0.008, 250, 2200, attack=0.016, tau=0.035, amp=0.07,
          pan=0.05)
    _pops(m, land, 0.14, 120, 600, 2600, 0.016, decay=(0.001, 0.004),
          pan=(-0.3, 0.4))
    strike(m, land + 0.003, _solid(rng, 230, n=14, eta=0.06, cap=0.06),
           tc=0.01, amp=0.12, lowpass=1200)
    for k in range(5):
        t0 = land + MUD_PATCH * (k + 1) + rng.uniform(-0.01, 0.01)
        a = 0.6 * (1 - k / 6)
        pan = -0.15 + 0.12 * k
        burst(m, t0, 250, 1500, attack=0.015, tau=0.03, amp=0.06 * a, pan=pan)
        _pops(m, t0, 0.08, 80, 500, 2000, 0.012 * a, decay=(0.001, 0.003),
              pan=(pan - 0.15, pan + 0.15))
    m.room(t60=0.5, wet=0.15)
    return m.finish(loudness_db=-30.0, fade_out=0.3)


def special_veil():
    """Dark's veil: a shadow is drawn round the kin and, for 7 s, the party
    cannot be targeted and the orb is hidden. A heavy cloth drawn over --
    the rasp of it sweeping round, a soft fall of air under it -- and then
    everything hushed beneath it: the band closes down as it lands."""
    m = Mix(1.8, seed=6640)
    rng = m.rng
    n = round(0.8 * SR)
    for k, (t0, pan) in enumerate(((0.0, -0.45), (0.06, 0.3))):
        sub = Mix(0.8, seed=6641 + k)
        _rustle(sub, 0.0, 0.75,
                lambda u: 2600 * np.sin(math.pi * np.clip(u, 0, 1) ** 0.6) ** 2,
                [900, 5000], 1.0)
        x = sub.y[0] / math.cos(math.pi / 4)
        # The cloth closing down as it lands: its band falls away.
        cut = 5000 - 3800 * smooth(np.arange(n) / SR, 0.1, 0.6)
        x = _sweep_lowpass(x, cut)
        _place(m, t0, 0.5 * x, np.linspace(pan, pan * 0.3, len(x)))
    swish(m, 0.0, 0.9, lambda u: 1300 - 950 * u, 0.6,
          lambda u: np.where(u < 0.35, (u / 0.35) ** 2,
                             np.cos((u - 0.35) / 0.65 * math.pi / 2) ** 2), 0.08)
    m.air(0.4, 1.3, 220, 900, amp=0.05, rise=0.15)
    m.room(t60=0.6, wet=0.12, darkness=2200)
    return m.finish(loudness_db=-31.0, fade_out=0.4)


def _sweep_lowpass(x, cut):
    """A lowpass whose cutoff follows [cut] (Hz per sample), in short
    blocks: a sound being covered over."""
    out = np.zeros_like(x)
    blk = 256
    zi = None
    for i in range(0, len(x), blk):
        fc = float(np.clip(cut[min(i, len(cut) - 1)], 200, 0.45 * SR))
        sos = _sos('lowpass', fc)
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        out[i:i + blk], zi = signal.sosfilt(sos, x[i:i + blk], zi=zi)
    return out


def special_pact():
    """Blood's pact (drawKinBloodThreads): threads drawn between every
    living ally -- ship included, every pair -- pulsing slowly (sin 3t, so
    a swell peaking ~0.5 s in). Cords pulled taut one after another round
    the field, each a short creak of sinew under tension, and the held
    strain of them all swelling with the first pulse and easing. The
    element accent is the heartbeat; this is the binding."""
    m = Mix(1.9, seed=6650)
    rng = m.rng
    ties = ((0.0, -0.6), (0.07, 0.5), (0.16, -0.1), (0.21, 0.75),
            (0.31, -0.35), (0.38, 0.2))
    for t0, pan in ties:
        creak(m, t0, 0.2, lambda u: 140 - 70 * u, 0.5,
              _solid(rng, rng.uniform(300, 460), n=10, eta=0.07, cap=0.03),
              0.22, lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.5) ** 2,
              pan)
        _rustle(m, t0, 0.16, lambda u: 900 * np.sin(math.pi * u), [1200, 4000],
                0.35, pan)
    peak = math.pi / (2 * PACT_W)  # sin(3t) first peaks here
    swish(m, 0.1, 1.7, lambda u: 320 - 60 * u, 0.5,
          lambda u: np.exp(-((u * 1.7 + 0.1 - peak) / 0.4) ** 2), 0.06)
    m.room(t60=0.6, wet=0.15)
    return m.finish(loudness_db=-31.0, fade_out=0.35)


def special_wisp():
    """Spirit's wisp: a small soul-flame kindled beside the kin (orbit 56 px,
    1.8 rad/s, starting on its right), flickering. A wick catching -- a soft
    breath of flame leaning in -- and the small flame fluttering as it
    swings round once, fading as it settles. (A recast that only refreshes
    the wisp plays the same.)"""
    m = Mix(1.9, seed=6660)
    burst(m, 0.0, 300, 1500, attack=0.035, tau=0.07, amp=0.06, pan=0.4)
    n = m.n
    pan = 0.5 * np.cos(WISP_W * m.t)
    x = signal.sosfilt(_sos('bandpass', [450, 2600]), m.rng.normal(0, 1, n))
    env = smooth(m.t, 0.0, 0.05) * (0.45 + 0.55 * np.exp(-m.t / 0.25))
    env *= 1 - smooth(m.t, 1.0, 1.85)
    x *= _wobble(m.rng, n, 7.0, 0.5) * env
    _place(m, 0.0, 0.05 * x, pan)
    m.room(t60=0.7, wet=0.2)
    return m.finish(loudness_db=-32.0, fade_out=0.3)


def special_wisp_tier():
    """The wisp grows a tier (_drawWisp: a veil trailing it, then motes it
    throws, then a crown): its flame swells larger and lower, a breath of
    veil unfurling behind it, and settles at its new size."""
    m = Mix(1.3, seed=6670)
    _flame(m, 0.0, 1.2, 250, 2000,
           lambda u: smooth(u * 1.2, 0, 0.25) * (0.5 + 0.5 * np.exp(-np.maximum(u * 1.2 - 0.25, 0) / 0.3))
           * (1 - smooth(u * 1.2, 0.8, 1.2)),
           0.06, pan=0.15, flutter=7.0, depth=0.5)
    swish(m, 0.1, 0.8, lambda u: 1600 - 700 * u, 0.5,
          lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.6) ** 2, 0.04,
          pan=-0.2)
    m.room(t60=0.7, wet=0.2)
    return m.finish(loudness_db=-31.0, fade_out=0.3)


def special_phoenix():
    """Fire's phoenix (never cast: the save). The orb (Survival), the ship
    (open cosmos) or a fallen creature (dungeon) is caught at a quarter
    health; 24 embers are thrown out (0.55-0.95 s) and the kin's flames
    begin to circle it for good.

    0       fire bursting back: a breath of gas catching, leaning in ~40 ms
    0-0.6   the flame roaring up, embers crackling outward and thinning
    0.5-    settling into the reborn flames, circling the field
    """
    m = Mix(2.5, seed=6680)
    rng = m.rng
    n = round(0.9 * SR)
    tt = np.arange(n) / SR
    fc = 300 + 2600 * smooth(tt, 0.0, 0.07) * np.exp(-np.maximum(tt - 0.07, 0) / 0.25)
    catch = _sweep_lowpass(rng.normal(0, 1, n), fc)
    catch = signal.sosfilt(_sos('highpass', 140), catch)
    env = smooth(tt, 0, 0.04) * np.exp(-6.9 * np.maximum(tt - 0.04, 0) / 0.8)
    _place(m, 0.0, 0.08 * catch * env, 0.0)
    _flame(m, 0.02, 1.0, 250, 1800,
           lambda u: smooth(u, 0, 0.1) * np.exp(-u / 0.5), 0.07, pan=0.0)
    # The reborn flames circling.
    t = m.t
    ring = signal.sosfilt(_sos('bandpass', [400, 2400]), rng.normal(0, 1, m.n))
    ring *= _wobble(rng, m.n, 9.0, 0.5) * smooth(t, 0.35, 0.8) * (1 - smooth(t, 1.4, 2.4))
    _place(m, 0.0, 0.018 * ring, 0.55 * np.sin(FLAME_W * t))
    # The embers thrown.
    embers = sorted(0.02 + np.minimum(rng.exponential(0.16, PHOENIX_EMBERS), 0.9))
    chips(m, [(t0, rng.uniform(0.08, 0.18) * (1 - 0.6 * (t0 - 0.02) / 0.9),
               (1 if k % 2 else -1) * rng.uniform(0.2, 0.95))
              for k, t0 in enumerate(embers)],
          1400, 4800, eta=0.2, n=2, tc=0.00025, cap=0.006)
    _pops(m, 0.03, 1.4, 90, 1300, 6000, 0.05,
          shape=lambda x: math.exp(-2.2 * x), big=0.1, pan=(-0.8, 0.8))
    m.room(t60=1.0, wet=0.22, darkness=3600)
    return m.finish(loudness_db=-28.0, fade_out=0.4)


def _v(build, description):
    return {'build': build, 'description': description, 'variants': 3}


CUES = {
    'sfx_basic_kin': _v(
        basic_kin, 'A kin\'s charged line let go: a narrow sear at full at once, dying with the 0.28 s beam'),
    'sfx_basic_kin_charge': _v(
        basic_kin_charge, 'The last 0.6 s of a kin\'s charge: motes drawn into the glow, air narrowing; ends on the release'),
    'sfx_special_kin': (
        special_kin, 'A kin\'s blessing welling up: a warm swell rising, a few motes lifted away'),
    'sfx_special_kin_escort': (
        special_escort, 'Guards set turning round the kin, then peeling off to the ship (Light, Crystal)'),
    'sfx_special_kin_rain': (
        special_rain, 'A cloud gathering over the ship and rain starting on the hull (Water)'),
    'sfx_special_kin_updraft': (
        special_updraft, 'A wind column taking hold round the ship, debris ticking up it (Air)'),
    'sfx_special_kin_garden': (
        special_garden, 'Damp loam opening as shoots push up, roots straining (Plant)'),
    'sfx_special_kin_wall': (
        special_wall, 'A stone rampart heaved up along an arc, sections seating, grit running off (Earth)'),
    'sfx_special_kin_bank': (
        special_bank, 'A bank of dust settling far off, fine grit left hanging in it (Dust)'),
    'sfx_special_kin_darts': (
        special_darts, 'A ring of wet spits round the field and the darts zipping away (Poison)'),
    'sfx_special_kin_charge': (
        special_ice_charge, 'Frost forming finer and denser, ice under strain, air drawn in (Ice charge)'),
    'sfx_special_kin_ice_release': (
        special_ice_release, 'A frozen sheet giving, cold rushing out, fine ice thrown wide (Ice release)'),
    'sfx_special_kin_channel': (
        special_channel, 'A held charge: corona hiss with arcs crawling on it, pulsing (Lightning)'),
    'sfx_special_kin_plate': (
        special_plate, 'Basalt plates closing on each body, heat in the seams (Lava)'),
    'sfx_special_kin_boiler': (
        special_boiler, 'An iron hatch seated, its wheel turned tight, pressure groaning inside (Steam)'),
    'sfx_special_kin_sling': (
        special_sling, 'Mud slung onto the hull with a wet slap, the trail starting (Mud)'),
    'sfx_special_kin_veil': (
        special_veil, 'A heavy cloth drawn over and everything hushed beneath it (Dark)'),
    'sfx_special_kin_pact': (
        special_pact, 'Sinew cords pulled taut round the field, the strain swelling once (Blood)'),
    'sfx_special_kin_wisp': (
        special_wisp, 'A soul-flame kindled like a wick, fluttering as it swings round (Spirit)'),
    'sfx_special_kin_wisp_tier': (
        special_wisp_tier, 'The wisp\'s flame swelling larger and lower, a veil unfurling (Spirit tier-up)'),
    'sfx_special_kin_phoenix': (
        special_phoenix, 'Fire bursting back to life, embers thrown, reborn flames circling (Fire save)'),
}
