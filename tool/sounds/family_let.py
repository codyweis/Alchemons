"""Let -- the Meteors family: its auto-attack, its skyfall special, and the
landing.

What is on screen (read from the Dart, not the design notes):

THE BASIC is NOT lobbed and does not fall. createFamilyBasicAttack
(cosmic_data.dart, case 'let') throws ONE meteor flat along the aim line:
speed 0.82 x Projectile.speed (600) = ~490 units/s, life 1.6 s, collision
radius 1.55x, visualScale 1.7, ProjectileVisualStyle.meteor. It is painted
by _drawSkyfallMeteor (cosmic_projectile_vfx.dart) at full size: a
translucent tumbling rock lit from inside, a flowing plume wake behind it, a
heat bloom and sparkle glints shed into the wake. No flame tongues (they
were removed). It fires every ~1.1-1.7 s per Let (kAlchemonBaseBasicCooldown
1.5 x the family's 1.12 over the attack-power factor) and is heard on the
frame it is thrown; what it strikes plays combatHitLight/Heavy on its own.
So the cue is a heavy glowing rock LEAVING: a shove, then the rush of the
rock and its plume going away from the thrower, darkening as it goes.

THE SPECIAL is a skyfall (cosmic_data.dart _letSpecial, letSkyfallDrop,
CosmicAbilityRuntime.advanceSkyfall). At the cast frame a ground mark comes
up on the committed impact point (drawLetSkyfallTelegraph: present within
0.12 s, its ring closes and the rock's shadow swells as t^2), and the rock
starts kLetSkyfallDistance (720) up the descent line. It lands after
kLetSkyfallDuration = 0.52 s (Earth's moon drop: x1.35 = 0.70 s, from
x1.15 higher, visualScale 8 vs 6). Its height is D * (time remaining)^2, so
it comes in fast from off-screen and is close and large for the last third;
the painter grows it from 0.62x to full size and stretches its wake as it
nears. Descent embers are shed once it is past 35%. The landing
(_detonateLetSkyfall in all three games) paints drawLetCrater, 0.9 s: a
flash in the first 0.14 s, a pressure front out by 0.29 s, ejecta thrown in
broken arcs that ease out over 0.5 s, rubble seating on the lip within
0.13 s, then the bowl and stone settle and fade. Air, Spirit and Light
craters are 'airy': no ejecta curtain, no lip rubble.

So the special is TWO moments, each its own cue so each lands on its frame:
the fall (cast frame -> touchdown, a fixed time after the cast) and the
landing (the detonation frame). Dark's kill bombardment drops 2-5 more
meteors at once with durations 0.52 x (0.72 + 0.16 i): they land 83 ms
apart, a rolling barrage, each through the same detonation.

Materials: a burning body tearing through air (turbulent roar with a flame
flicker in it, never a whistle or a pitch sweep), and the ground taking a
mass (earth compacting, a dense stone seating, the pressure front, clods
and stones thrown up and falling back, rubble settling). No kick: the
weight is low NOISE leaning in and many damped inharmonic modes, never a
low sine; no crash: the crunch is low-mid and leans in, the bright part is
sparse debris, not a burst.
"""
import math
import warnings

import numpy as np
from scipy import signal

from sounds.core import SR, Mix, smooth
from sounds.combat import _solid, chips, strike, burst

# ===========================================================================
# Timing, from the Dart
# ===========================================================================

FALL = 0.52               # kLetSkyfallDuration
FALL_EARTH = 0.52 * 1.35  # Earth's moon drop: timeScale 1.35
DROP = 720.0              # kLetSkyfallDistance
CRATER = 0.9              # kLetCraterDuration
CRATER_FLASH = 0.16 * CRATER   # flash = (1 - t/0.16)^2
CRATER_SHOCK = 0.32 * CRATER   # the pressure front is out and gone
CRATER_THROW = 0.55 * CRATER   # ejecta ease out over this
BASIC_SPEED = 600.0 * 0.82     # units per second, flat
EMBERS_FROM = 0.35        # _spawnLetDescentEmbers: skyfallProgress >= 0.35

# Element -> which special cue. None = sfx_special_let (the standard fall).
SPECIAL_PATTERNS = {
    'Fire': None, 'Water': None, 'Air': None, 'Earth': 'earth',
    'Lightning': None, 'Steam': None, 'Lava': None, 'Poison': None,
    'Ice': None, 'Mud': None, 'Dust': None, 'Crystal': None, 'Plant': None,
    'Spirit': None, 'Dark': None, 'Light': None, 'Blood': None,
}

# Element -> which landing cue (sfx_special_let_impact[_<pattern>]).
# 'airy' follows drawLetCrater's isAiry: no ejecta curtain, no lip rubble.
IMPACT_PATTERNS = {
    'Fire': None, 'Water': None, 'Air': 'airy', 'Earth': 'earth',
    'Lightning': None, 'Steam': None, 'Lava': None, 'Poison': None,
    'Ice': None, 'Mud': None, 'Dust': None, 'Crystal': None, 'Plant': None,
    'Spirit': 'airy', 'Dark': None, 'Light': 'airy', 'Blood': None,
}


# ===========================================================================
# Voices
# ===========================================================================

def _lp(x, f, order=2):
    return signal.sosfilt(
        signal.butter(order, f, btype='lowpass', fs=SR, output='sos'), x)


def _flicker(rng, n, rate, depth):
    """A flame's unsteadiness: a quick random wobble on the loudness (a band
    from [rate]/3 to [rate] Hz, so it flutters without drifting into slow
    swells that would read as the thing changing distance), log-normal so it
    never reaches zero, centred on 1."""
    sos = signal.butter(2, [rate / 3, rate], btype='bandpass', fs=SR,
                        output='sos')
    x = signal.sosfilt(sos, rng.normal(0, 1, n + SR // 4))[SR // 4:]
    x /= max(float(np.std(x)), 1e-9)
    mod = np.exp(depth * x)
    return mod / float(np.mean(mod))


def roar(m, start, length, env, lo, hi, amp, flicker=(12.0, 0.35),
         width=lambda u: 0.5 + 0 * u, tilt=1.0):
    """Air torn by a burning body: broadband noise whose band edges move
    with the body ([lo](u), [hi](u) in Hz over u = 0..1 of [length]), a pink
    tilt so it is a roar and not a hiss, and a flame flicker on its loudness.
    [width](u) is how decorrelated the two sides are: a far thing is a
    point, a near one fills the field. The band is carved frame by frame,
    so it moves without ever settling on a resonance."""
    n = round(length * SR)
    nper, hop = 1024, 256
    pad = nper
    rng = m.rng

    def carve(noise):
        f, tt, z = signal.stft(noise, fs=SR, nperseg=nper,
                               noverlap=nper - hop, boundary=None,
                               padded=False)
        u = np.clip((tt - pad / SR) / length, 0, 1)
        ff = np.maximum(f, 20)[:, None]
        l = np.maximum(lo(u), 30)[None, :]
        h = np.maximum(hi(u), 200)[None, :]
        # 24 dB/octave either side: a band with soft shoulders, and nothing
        # far below it (the pink tilt would otherwise pile up sub-bass).
        shape = ((ff / l) ** 4 / (1 + (ff / l) ** 4)) / (1 + (ff / h) ** 4)
        shape /= (np.maximum(ff, 60) / 500) ** (tilt / 2)
        with warnings.catch_warnings():
            warnings.simplefilter('ignore', UserWarning)
            _, y = signal.istft(z * shape, fs=SR, nperseg=nper,
                                noverlap=nper - hop, boundary=False)
        y = y[pad:pad + n]
        return y / max(float(np.sqrt(np.mean(y ** 2))), 1e-12)

    common = carve(rng.normal(0, 1, n + 2 * pad))
    uu = np.arange(n) / max(n - 1, 1)
    w = np.clip(width(uu), 0, 1)
    fl = _flicker(rng, n, *flicker) if flicker else 1.0
    s0 = m._at(start)
    for ch in range(2):
        own = carve(rng.normal(0, 1, n + 2 * pad))
        y = np.sqrt(1 - w ** 2) * common + w * own
        y = 0.15 * amp * env(uu) * fl * y
        m.y[ch, s0:s0 + n] += y[: m.n - s0]


def crackle(m, events, lo=1800, hi=7000):
    """Dry flame crackle: each event a sub-millisecond spit of noise through
    its own narrow band -- a pocket of gas popping, not a struck solid."""
    rng = m.rng
    for t0, size, pan in events:
        n = round(rng.uniform(0.0004, 0.0016) * SR)
        tt = np.arange(n * 6) / SR
        tau = n / SR
        env = np.exp(-tt / tau) * np.clip(tt / 0.00015, 0, 1)
        fc = math.exp(rng.uniform(math.log(lo), math.log(hi)))
        sos = signal.butter(2, [fc / 1.5, min(fc * 1.5, 0.45 * SR)],
                            btype='bandpass', fs=SR, output='sos')
        spit = signal.sosfilt(sos, rng.normal(0, 1, len(tt))) * env
        s0 = m._at(t0)
        spit = spit[: m.n - s0]
        gl, gr = m._gains(float(np.clip(pan, -1, 1)))
        m.y[0, s0:s0 + len(spit)] += size * gl * spit
        m.y[1, s0:s0 + len(spit)] += size * gr * spit


def earth(m, start, attack, tau, cutoff, amp, tail=0.0, tail_tau=0.4):
    """The ground taking a mass: low noise (never a sine) that leans in over
    [attack] and dies with [tau], with an optional longer rumble [tail]
    under it -- the ground still shaking. Weight, not a drum: there is no
    pitch in it to fall."""
    length = attack + 7 * max(tau, tail_tau if tail else 0)
    n = round(length * SR)
    t = np.arange(n) / SR
    rng = m.rng
    lean = np.where(t < attack, smooth(t, 0, attack), 1.0)
    for ch in range(2):
        body = _lp(rng.normal(0, 1, n), cutoff, order=4)
        body /= max(float(np.std(body)), 1e-9)
        env = lean * np.exp(-np.maximum(t - attack, 0) / tau)
        y = amp * env * body
        if tail:
            rum = _lp(rng.normal(0, 1, n), cutoff * 0.7, order=4)
            rum /= max(float(np.std(rum)), 1e-9)
            y += tail * amp * lean * np.exp(-np.maximum(t - attack, 0) / tail_tau) * rum
        s0 = m._at(start)
        m.y[ch, s0:s0 + n] += 0.1 * y[: m.n - s0]


class _Dulled:
    """Lays whatever is written into it into [m] through a steep lowpass at
    [cutoff]: the contact voices are bright by nature, and a landing's
    crush and spray must not carry a broadband top (that is a crash)."""

    def __init__(self, m, cutoff):
        self.m, self.cutoff = m, cutoff
        self.sub = Mix(m.n / SR, seed=int(m.rng.integers(1 << 30)))
        self.sub.n = m.n
        self.sub.t = m.t
        self.sub.y = np.zeros_like(m.y)

    def __enter__(self):
        return self.sub

    def __exit__(self, *exc):
        sos = signal.butter(4, self.cutoff, btype='lowpass', fs=SR,
                            output='sos')
        self.m.y += signal.sosfilt(sos, self.sub.y, axis=1)


def crunch(m, start, span, count, f_lo, f_hi, size, lowpass=3200, pan=0.0,
           spread=0.4):
    """Ground compacting under a landing mass: a cluster of small dull
    fractures that thickens over its first third and thins out -- a crush
    that leans in, not one spike."""
    rng = m.rng
    # Beta(2, 4)-shaped arrival: few at first, densest a third of the way.
    times = start + span * np.sort(rng.beta(2.0, 4.0, count))
    events = []
    for t0 in times:
        x = (t0 - start) / span
        lean = min(1.0, x / 0.25) ** 0.7
        events.append((t0, size * lean * rng.uniform(0.5, 1.0),
                       pan + rng.uniform(-spread, spread)))
    chips(m, events, f_lo, f_hi, eta=0.06, n=3, tc=0.0008, cap=0.05,
          lowpass=lowpass)


def fallout(m, start, count, mean, until, size, clods=(380, 1500),
            stones=(900, 2600), stone_share=0.3, spread=0.85):
    """What the crater threw, coming back down: dirt clods (dull, damped)
    and a few stones (harder), at irregular times peaking ~[mean] after the
    landing, each quieter the later it comes, flung to both sides."""
    rng = m.rng
    times = start + np.minimum(rng.gamma(3.0, mean / 3.0, count), until)
    times.sort()
    for k, t0 in enumerate(times):
        late = (t0 - start) / max(until, 1e-3)
        # The first back down are the smallest, thrown lowest; the big ones
        # went highest and are still in the air.
        early = 0.35 + 0.65 * smooth(t0 - start, 0.0, 0.12)
        s = size * rng.uniform(0.45, 1.0) * (1 - 0.65 * late) * early
        pan = (1 if k % 2 else -1) * rng.uniform(0.15, spread)
        if rng.random() < stone_share:
            chips(m, [(t0, 0.7 * s, pan)], *stones, eta=0.035, n=4,
                  tc=0.0004, cap=0.05)
        else:
            chips(m, [(t0, s, pan)], *clods, eta=0.09, n=3, tc=0.0012,
                  cap=0.03, lowpass=2400)


# ===========================================================================
# The basic: one glowing rock thrown flat
# ===========================================================================

def basic_let(v=0):
    """A heavy glowing rock thrown flat: a shove of air as it leaves the
    thrower, then the rough rush of the rock and its plume going away --
    loud for an instant, darker and smaller as it goes (~490 units/s), a
    couple of dry spits from the glints it sheds."""
    length = 0.6
    m = Mix(length, seed=7300 + v)
    rng = m.rng
    # Distance from the thrower: the rush is loud at the hand and recedes.
    d0 = 80.0

    def away(u):
        d = BASIC_SPEED * u * length
        return 1.0 / (1.0 + d / d0)

    # The shove: a body of air pushed out ahead of the rock.
    burst(m, 0.0, 170, 1100, attack=0.012, tau=0.035, amp=0.08,
          pan=(0.0, -0.08, 0.08, 0.04)[v])
    # The rock and its plume going: a coarse roar, flickering like a flame,
    # its top falling away as it recedes (distance darkens; nothing sweeps).
    top = (3200, 3000, 3500, 3100)[v]
    roar(m, 0.004, length - 0.01,
         env=lambda u: smooth(u, 0, 0.07) * away(u) ** 1.3,
         lo=lambda u: 190 + 0 * u,
         hi=lambda u: top * (0.45 + 0.55 * away(u)),
         amp=1.0, flicker=(22.0 + 2 * v, 0.3),
         width=lambda u: 0.55 - 0.3 * u)
    # A few glints shed into the wake: sparse, irregular, quiet.
    n = 2 + (v % 2)
    t0s = np.sort(rng.uniform(0.03, 0.26, n))
    crackle(m, [(t, rng.uniform(0.02, 0.035) * away(t / length),
                 rng.uniform(-0.3, 0.3)) for t in t0s], lo=1600, hi=5200)
    m.room(t60=0.35, wet=0.12, darkness=3600)
    return m.finish(loudness_db=-35.0, fade_out=0.15)


# ===========================================================================
# The fall: cast frame -> touchdown
# ===========================================================================

def _fall(m, T, height, heft, rough=1.0, embers=1.0):
    """A burning body coming down over [T] seconds onto the listener's
    ground. Height follows advanceSkyfall exactly: with r = 1-s the time
    left, h = [height] * r * (2 - r) -- at rest at the top, fastest at
    touchdown.
    Loudness follows nearness (1 / (1 + h/h0)); nearness also opens the top
    of the band (less air between) and widens the image (a far point, a
    near mass). [heft] scales how low the roar reaches."""
    h0 = 140.0

    def near(u):
        s = np.clip(u * (m.n / SR) / T, 0, 1)
        r = 1 - s
        h = height * r * (2 - r)
        return 1.0 / (1.0 + h / h0)

    def held(u):
        # Full until touchdown, then let go fast: the landing takes over.
        t = u * (m.n / SR)
        return np.where(t <= T, 1.0, np.exp(-(t - T) / 0.03))

    # The roar: the rock and its burning wake tearing through air.
    roar(m, 0.0, m.n / SR,
         env=lambda u: near(u) ** 1.25 * held(u),
         lo=lambda u: (230 - 90 * heft) + 0 * u,
         hi=lambda u: 1500 + 4200 * near(u) ** 1.4,
         amp=1.0, flicker=(26.0 * rough, 0.18),
         width=lambda u: 0.25 + 0.55 * near(u))
    # The low body of it, the mass of air it shoves ahead of itself: only
    # there in the last stretch, where the shadow on the ground swells.
    roar(m, 0.0, m.n / SR,
         env=lambda u: near(u) ** 3 * held(u),
         lo=lambda u: 70 + 0 * u,
         hi=lambda u: 420 + 200 * heft + 0 * u,
         amp=0.9 * heft, flicker=(10.0, 0.2),
         width=lambda u: 0.6 + 0 * u)
    # The tear at its leading edge: thin, high, only when it is close.
    roar(m, 0.0, m.n / SR,
         env=lambda u: near(u) ** 2.4 * held(u),
         lo=lambda u: 2600 + 0 * u, hi=lambda u: 7500 + 0 * u,
         amp=0.22, flicker=(30.0, 0.35), tilt=0.4,
         width=lambda u: 0.8 + 0 * u)
    # Embers shed off it once it is past 35% of the drop and on screen.
    rng = m.rng
    ev = []
    t = EMBERS_FROM * T
    while t < T:
        u = t / (m.n / SR)
        nr = float(near(np.array([u]))[0])
        rate = embers * (8 + 55 * nr ** 2)
        ev.append((t, rng.uniform(0.02, 0.045) * nr, rng.uniform(-0.5, 0.5)))
        t += rng.exponential(1 / rate)
    crackle(m, ev, lo=1500, hi=6500)


def special_let():
    """The standard Let special: cast frame to touchdown (0.52 s). A burning
    rock coming down out of the sky -- far and dark at the cast (the
    element's accent has the cast frame to itself), louder, brighter and
    wider as its shadow swells, peaking on the touchdown frame and letting
    go there for the landing."""
    # Seeds chosen (of 30) for the noise that follows the nearness curve
    # most closely: a fall must swell, not lurch.
    m = Mix(FALL + 0.18, seed=7332)
    _fall(m, FALL, DROP, heft=0.8)
    m.room(t60=0.6, wet=0.12, darkness=3800)
    return m.finish(loudness_db=-30.5, fade_out=0.08)


def special_let_earth():
    """Earth's moon drop: 0.70 s from 15% higher, a bigger, slower rock. The
    roar reaches lower and builds longer; the same peak on touchdown."""
    m = Mix(FALL_EARTH + 0.18, seed=7427)
    _fall(m, FALL_EARTH, DROP * 1.15, heft=1.25, rough=0.75, embers=0.6)
    m.room(t60=0.7, wet=0.14, darkness=3400)
    return m.finish(loudness_db=-30.0, fade_out=0.08)


def basic_let_deadfall(v=0):
    """Deadfall (Let mastery): the auto-attack rock falls instead of flying,
    over the same 0.52 s. A small rock: thinner, quieter, no low body."""
    m = Mix(FALL + 0.12, seed=(7440, 7441, 7457, 7448)[v])
    _fall(m, FALL, DROP, heft=0.15, rough=1.2, embers=0.35)
    m.room(t60=0.4, wet=0.1, darkness=3800)
    return m.finish(loudness_db=-35.0, fade_out=0.06)


# ===========================================================================
# The landing: the detonation frame
# ===========================================================================

def _land(m, *, body_f0, body_amp, ground, crush_n, crush_amp, shock_amp,
          throw, debris_n, debris_mean, debris_until, debris_amp,
          settle, settle_until, tremor=0.0):
    """One meteor landing, t = 0 on the detonation frame, scored to
    drawLetCrater: the mass arrives (ground + stone + crush, leaning in over
    ~25 ms), the pressure front goes out by CRATER_SHOCK, the ejecta are
    thrown and fall back while the throw eases out (to CRATER_THROW and a
    little after), the lip's rubble settles while the bowl fades."""
    rng = m.rng
    # The ground taking it: low noise leaning in. The weight.
    earth(m, 0.0, attack=0.024, tau=0.11, cutoff=300, amp=ground,
          tail=0.25, tail_tau=0.35)
    # The rubble field's tremor (Earth): the broken ground still shaking --
    # a low-mid rattle of the slabs, not more sub-bass.
    if tremor:
        roar(m, 0.05, 1.0,
             env=lambda u: tremor * smooth(u, 0, 0.12) * (1 - u) ** 1.6,
             lo=lambda u: 130 + 0 * u, hi=lambda u: 750 + 0 * u,
             amp=1.0, flicker=(16.0, 0.55), width=lambda u: 0.7 + 0 * u)
    # The stone seating in the ground: a soft contact into many damped low
    # modes. Dense, short, below the crush; nothing in it rings.
    strike(m, 0.006, _solid(rng, body_f0, n=18, spread=(0.07, 0.28),
                            eta=0.09, cap=0.07, tilt=0.07),
           tc=0.007, amp=2.6 * body_amp, lowpass=2500)
    # The ground compacting and cracking under it.
    crush_span = 0.075
    with _Dulled(m, 2600) as d:
        # Many small fractures rather than a few big ones: a crush, and no
        # single chip standing out of it as a click.
        crunch(d, 0.0, crush_span, 2 * crush_n, 320, 2000, 0.4 * crush_amp)
    # The pressure front leaving the bowl, dulling as it spreads.
    burst(m, 0.012, 140, 1300, attack=0.02, tau=0.07, amp=shock_amp)
    roar(m, 0.02, CRATER_SHOCK,
         env=lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.4) ** 2 * (1 - u) ** 0.5,
         lo=lambda u: 160 + 0 * u, hi=lambda u: 2200 - 1500 * u,
         amp=0.55 * shock_amp / 0.1, flicker=None,
         width=lambda u: 0.4 + 0.5 * u)
    # The ejecta curtain going up: dirt thrown, a short dry spray.
    if throw:
        roar(m, 0.01, 0.16,
             env=lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.5) ** 2,
             lo=lambda u: 800 + 0 * u, hi=lambda u: 3600 + 0 * u,
             amp=throw, flicker=(40.0, 0.4), tilt=1.0,
             width=lambda u: 0.8 + 0 * u)
    # What was thrown coming back down.
    if debris_n:
        with _Dulled(m, 4200) as d:
            fallout(d, 0.07, debris_n, debris_mean, debris_until,
                    1.8 * debris_amp)
    # The rubble on the lip settling as the bowl fades.
    if settle:
        # Rubble, not sand: coarse, and nothing in it bright enough to tick.
        with _Dulled(m, 3200) as d:
            d.grains(lambda t: settle * 260 * smooth(t, 0.15, 0.3)
                     * (1 - smooth(t, 0.45, settle_until)),
                     lambda t: 0.15 + 0 * t,
                     lambda t: 0.25 * np.sin(2 * math.pi * 1.3 * t), amp=1.8,
                     weight=lambda t: 0.35 + 0 * t)


def special_let_impact(v=0):
    """A meteor landing: the ground takes the mass (low, leaning in), the
    stone seats with a dense dead body, the ground crushes under it, the
    pressure front goes out, clods and stones thrown from the bowl patter
    back down, the lip's rubble settles."""
    m = Mix(1.25, seed=7350 + v)
    _land(m, body_f0=(150, 165, 140, 158)[v], body_amp=0.55, ground=1.0,
          crush_n=34, crush_amp=0.42, shock_amp=0.1, throw=0.35,
          debris_n=16 + v, debris_mean=0.24, debris_until=0.62,
          debris_amp=0.45, settle=1.0, settle_until=0.85)
    m.room(t60=1.0, wet=0.22, darkness=3000)
    return m.finish(loudness_db=-28.5, fade_out=0.3)


def special_let_impact_earth(v=0):
    """Earth's moon drop landing like a hammer: a bigger, lower mass, more
    ground thrown and falling for longer, and the rubble field's tremor
    still running through the ground after it."""
    m = Mix(1.6, seed=7360 + v)
    _land(m, body_f0=(118, 126, 112, 122)[v], body_amp=0.75, ground=1.05,
          crush_n=48, crush_amp=0.48, shock_amp=0.12, throw=0.45,
          debris_n=24 + v, debris_mean=0.3, debris_until=0.85,
          debris_amp=0.34, settle=1.5, settle_until=1.1, tremor=0.5)
    m.room(t60=1.2, wet=0.24, darkness=2800)
    return m.finish(loudness_db=-28.5, fade_out=0.35)


def special_let_impact_airy(v=0):
    """Air, Spirit and Light land without a curtain of ground (their crater
    throws no ejecta and seats no rubble): the mass and the pressure front,
    a pale bowl, a couple of grains."""
    m = Mix(1.0, seed=7370 + v)
    _land(m, body_f0=(165, 175, 158, 170)[v], body_amp=0.45, ground=0.8,
          crush_n=18, crush_amp=0.3, shock_amp=0.14, throw=0.0,
          debris_n=3, debris_mean=0.15, debris_until=0.35,
          debris_amp=0.18, settle=0.0, settle_until=0.6)
    m.room(t60=1.0, wet=0.24, darkness=3400)
    return m.finish(loudness_db=-29.5, fade_out=0.3)


def special_let_impact_barrage(v=0):
    """One of Dark's follow-up meteors (2-5 land 83 ms apart): a full
    landing with the tail cut short, so a rolling barrage stays a run of
    impacts rather than one smear."""
    m = Mix(0.75, seed=7380 + v)
    _land(m, body_f0=(140, 152, 134, 146)[v], body_amp=0.55, ground=0.9,
          crush_n=24, crush_amp=0.4, shock_amp=0.09, throw=0.25,
          debris_n=7, debris_mean=0.16, debris_until=0.4,
          debris_amp=0.26, settle=0.0, settle_until=0.6)
    m.room(t60=0.7, wet=0.18, darkness=2800)
    return m.finish(loudness_db=-31.0, fade_out=0.2)


def special_let_impact_minor(v=0):
    """A mastery rock landing (Deadfall's auto-attack, a comet's crater):
    drawLetCrater's minor bowl -- a small mass, a short crush, a few clods."""
    m = Mix(0.55, seed=7390 + v)
    _land(m, body_f0=(230, 250, 215, 240)[v], body_amp=0.45, ground=0.55,
          crush_n=12, crush_amp=0.32, shock_amp=0.06, throw=0.0,
          debris_n=4, debris_mean=0.12, debris_until=0.3,
          debris_amp=0.22, settle=0.0, settle_until=0.4)
    m.room(t60=0.45, wet=0.14, darkness=3000)
    return m.finish(loudness_db=-33.5, fade_out=0.15)


def _v(build, description, n=3):
    return {'build': build, 'description': description, 'variants': n}


CUES = {
    'sfx_basic_let': _v(
        basic_let, 'A heavy glowing rock thrown flat: a shove of air, then its rough flickering rush going away'),
    'sfx_basic_let_deadfall': _v(
        basic_let_deadfall, 'Deadfall: a small burning rock falling 0.52 s onto its mark, peaking at touchdown'),
    'sfx_special_let': (
        special_let, 'A burning rock falling out of the sky for 0.52 s: far and dark, nearer, louder and wider until touchdown'),
    'sfx_special_let_earth': (
        special_let_earth, 'Earth\'s moon drop: a bigger rock falling 0.70 s from higher, its roar reaching lower'),
    'sfx_special_let_impact': _v(
        special_let_impact, 'A meteor landing: the ground takes the mass, the stone seats, pressure goes out, clods patter back down'),
    'sfx_special_let_impact_earth': _v(
        special_let_impact_earth, 'The moon drop landing like a hammer: a deeper mass, more ground thrown, a tremor after'),
    'sfx_special_let_impact_airy': _v(
        special_let_impact_airy, 'Air/Spirit/Light landing: the mass and the pressure front, no curtain of ground thrown'),
    'sfx_special_let_impact_barrage': _v(
        special_let_impact_barrage, 'One of Dark\'s follow-up meteors landing: a full landing with its tail cut short'),
    'sfx_special_let_impact_minor': _v(
        special_let_impact_minor, 'A small mastery rock landing in its minor crater: a small mass, a short crush, a few clods'),
}
