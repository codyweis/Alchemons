"""Horn, the Bulky Defense Tank: its basic attack and its specials, each
scored to what is drawn.

THE BASIC (createFamilyBasicAttack 'horn', cosmic_data.dart): one plain
element-coloured orb, 1.5x the size and 1.8x the radius of a shot, at 0.65
speed (Projectile.speed 600 -> 390 px/s). A horn fights close
(_familyPreferredDistance: attackRange x 0.38, ~45-60 px off its target;
range ~115 px), so the slug is in the target 0.1-0.3 s after it leaves and
combatHitLight/Heavy plays the hit itself. It fires every ~1-1.7 s
(alchemonBasicAttackInterval, frame.basicCooldown 1.12). So the basic is
the THROW -- the horn tossing its head and a dense slug leaving it -- and
it is over by the time the hit lands.

THE SPECIAL owns the horn's body for a while (horn_runtime.dart, survival's
_handleHornWindUp / charge state, cosmic_game_horn.dart, the dungeon's horn
step). Its shape depends on the element:

  charge   the cast frame IS the ram: hornStandardDash runs it through the
           target and on by the overshoot at 400 px/s x speedMul -- constant
           speed from the first frame -- for distance/speed + 0.15 s, so
           0.4-0.85 s at the ranges a horn casts from. The slam (HornFx.slam,
           0.5 s; Earth/Lava 0.66 s) is drawn where it ends.
           Fire Steam Poison Dust Plant Blood Ice Lightning
  heavy    the same, at 0.55 speed: Lava and Earth, 0.5-1.1 s, and a bigger
           slam.
  circle   Water: one lap round the cast point in exactly 1.0 s
           (hornWaterCircle), the whirlpool dropped at the end.
  gather   Crystal: holds still 1.2 s while six shards spin up round it
           (emitHornCrystalOrbit: 5 rad/s), then the standard ram.
  brace    Spirit: holds still 2.0 s, phantoms swarming in, then rams.
  void     Dark: holds 5.0 s while everything within 260 px is dragged in
           (pull 90 -> 310 px/s), then a very fast ram (2.1x speed, 580 px,
           ~0.85 s) carrying the catch to the map edge.
  barrier  Light: no ram. Plants and holds a dome for 5.0 s x durationScale
           (4.4-5.8 s), reflecting shots, bouncing what touches it.
  passive  Air, Mud: never cast (isPassiveOnlyCosmicAbility).

and two moments after the cast that had no sound of their own:

  slam       every ram's landing (HornFx.slam is pushed on that frame).
  brew       Lightning: after the slam the horn holds 3.0 s
             (HornRules.postDashBrew) while a storm brews round it...
  discharge  ...and lets it go as a chain shockwave.

The element accent (sfx_element_*) still plays on the cast frame, at full
gain, and carries the colour; everything here is the HORN: its weight, its
horn and sinew, the air it shoves, what it hits. Weight comes from many
damped modes, soft contacts and rough air -- never from a low tone that
drops (a kick), never from a dense bright burst (a crash).

Voices added here (core.py stays as it is; the impact voices are combat.py's):
  _band      noise whose band slides with a curve (swish, returned not placed)
  _rough     a turbulent flutter on air: what makes a push sound heavy
  _moving    places a mono signal with a pan that moves
  _arcs      short irregular electric buzzes (no stable rate, so no pitch)
"""
import math
import warnings

import numpy as np
from scipy import signal

from sounds.combat import (_contact, _fracture, _put, _ring, _shards, _solid,
                           burst, chips, creak, strike)
from sounds.core import SR, Mix, smooth

# ===========================================================================
# Timing, from the Dart
# ===========================================================================

BASIC_LAND = 0.22        # 45-120 px at 390 px/s: the slug is in by here
CHARGE_TRAVEL = 0.62     # a typical ram (Fire, 100 px + 30 overshoot at 312 px/s + 0.15)
HEAVY_TRAVEL = 0.85      # Lava/Earth at 220 px/s
CIRCLE_LAP = 1.0         # HornRules.waterCircleDuration
CRYSTAL_WINDUP = 1.2     # HornRules.crystalWindUp
SPIRIT_WINDUP = 2.0      # HornRules.spiritWindUp
DARK_WINDUP = 5.0        # HornRules.darkWindUp
DARK_DASH = 0.84         # 580 px at 840 px/s + 0.15
BARRIER_LIFE = 5.0       # the Light barrier zone's life (x 0.88-1.16)
SLAM_FX = 0.5            # HornFx.slam duration
SLAM_FX_HEAVY = 0.66     # ... for Earth and Lava
BREW = 3.0               # HornRules.postDashBrew
CHAIN_ZONE = 0.6         # the discharge's chain zone life; sparks 0.3-1.2 s

# ===========================================================================
# Voices
# ===========================================================================


def _band(rng, length, fc, width, tilt=True):
    """Noise whose band sits at [fc](u) Hz over u = 0..1 of [length], [width]
    in natural-log units. Carved frame by frame (as combat.swish), so it
    slides and never settles on a resonance. Returned, unit RMS."""
    n = round(length * SR)
    nper, hop = 1024, 256
    pad = nper
    noise = rng.normal(0, 1, n + 2 * pad)
    f, tt, z = signal.stft(noise, fs=SR, nperseg=nper, noverlap=nper - hop,
                           boundary=None, padded=False)
    u = np.clip((tt - pad / SR) / length, 0, 1)
    centre = np.log(np.maximum(fc(u), 40))
    logf = np.log(np.maximum(f, 20))[:, None]
    shape = np.exp(-0.5 * ((logf - centre[None, :]) / width) ** 2)
    if tilt:
        shape /= np.sqrt(np.maximum(f, 100) / 1000)[:, None]
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', UserWarning)
        _, y = signal.istft(z * shape, fs=SR, nperseg=nper,
                            noverlap=nper - hop, boundary=False)
    y = y[pad:pad + n]
    if len(y) < n:
        y = np.pad(y, (0, n - len(y)))
    return y / max(float(np.sqrt(np.mean(y ** 2))), 1e-12)


def _rough(rng, n, low=14.0, high=42.0, depth=0.6):
    """A turbulent flutter: a slow irregular swell-and-catch on the air, the
    way a big body shoving through it is never a smooth hiss. Mean 1."""
    sos = signal.butter(2, [low, high], btype='bandpass', fs=SR, output='sos')
    w = signal.sosfilt(sos, rng.normal(0, 1, n + SR // 4))[SR // 4:]
    w /= max(float(np.std(w)), 1e-12)
    return np.clip(1 + depth * w, 0.15, 2.4)


def _moving(m, start, mono, pan):
    """[mono] placed from [start] with a pan that moves: [pan] an array as
    long as [mono], -1..1."""
    s0 = m._at(start)
    mono = mono[: m.n - s0].copy()
    # Never start or stop dead: a layer cut at full level is a click.
    k = min(len(mono) // 2, round(0.012 * SR))
    if k > 1:
        ramp = np.sin(np.linspace(0, math.pi / 2, k)) ** 2
        mono[:k] *= ramp
        mono[-k:] *= ramp[::-1]
    p = np.clip(pan[: len(mono)], -1, 1)
    m.y[0, s0:s0 + len(mono)] += np.cos((p + 1) * math.pi / 4) * mono
    m.y[1, s0:s0 + len(mono)] += np.sin((p + 1) * math.pi / 4) * mono


def _env(t, attack, hold, tau):
    """In over [attack] (squared, so it leans in), flat until [hold], then
    an exponential away with time constant [tau]."""
    a = np.clip(t / attack, 0, 1) ** 2
    d = np.where(t < hold, 1.0, np.exp(-(t - hold) / tau))
    return a * d


def _horn_body(rng, f0):
    """The horn and the skull behind it: keratin over bone, a dense curved
    solid. Irregular modes, damped harder than stone in the highs (fibrous),
    so struck it is a dull dry 'tok', never a ring."""
    return _solid(rng, f0, n=18, spread=(0.09, 0.34), eta=0.07, cap=0.11,
                  tilt=0.09)


def _arcs(m, events, amp):
    """Short electric arcs at [events] = [(time, length, size, pan)]: noise
    gated by an impulse train whose rate wanders +-35 % inside each arc, so
    it buzzes without settling on a pitch."""
    rng = m.rng
    for t0, length, size, pan in events:
        n = round(length * SR)
        if n < 32:
            continue
        x = np.zeros(n)
        t = 0.0
        rate = rng.uniform(260, 700)
        while t < length:
            x[int(t * SR)] = rng.uniform(0.4, 1.0)
            t += 1.0 / (rate * max(0.4, 1 + 0.35 * rng.normal()))
        sos = signal.butter(2, [rng.uniform(1500, 2400), rng.uniform(5000, 6500)],
                            btype='bandpass', fs=SR, output='sos')
        y = signal.sosfilt(sos, x + 0.25 * rng.normal(0, 1, n))
        tt = np.arange(n) / SR
        env = (np.clip(tt / 0.006, 0, 1) ** 2 * np.exp(-tt / (0.45 * length))
               * (1 - smooth(tt, 0.75 * length, length)))
        _put(m, t0, amp * size * env * y, pan)


def _knock(m, start, modes, tc, amp, pan=0.0, hp=160.0):
    """combat.strike with a steeper, fixed highpass: the weight of a blow
    kept in its many modes and its crunch, with the bottom that would turn
    it into a boom (or, worse, a kick) taken off."""
    f, t60, a = modes
    length = min(1.5, float(np.max(t60)) * 1.3 + 0.01)
    out = signal.fftconvolve(_contact(tc), _ring(f, t60, a, length))
    out = signal.sosfilt(signal.butter(3, hp, btype='highpass', fs=SR,
                                       output='sos'), out)
    _put(m, start, amp * out, pan)


# -- shared gestures ---------------------------------------------------------


def _push_off(m, at, weight=1.0, pan=0.0):
    """The horn setting off: sinew and horn loading for an instant (a short
    creak), the body's mass going -- a soft, dense shove that leans in over
    ~25 ms -- and the air it starts to move. No hit: nothing is struck."""
    rng = m.rng
    creak(m, at - 0.035 * weight, 0.04 * weight,
          lambda u: 70 + 160 * u, 0.35,
          _solid(rng, 240, n=10, spread=(0.15, 0.5), eta=0.06, cap=0.05),
          0.05 * weight, lambda u: np.sin(math.pi * np.clip(u, 0, 1)) ** 2, pan)
    burst(m, at, 180, 1200, attack=0.025, tau=0.05 * weight, amp=0.045 * weight,
          pan=pan)
    # The body's own give as it throws its weight: a very soft contact into
    # the horn's modes, more felt than heard.
    _knock(m, at + 0.01, _horn_body(rng, 210 * rng.uniform(0.95, 1.05)),
           tc=0.006, amp=0.22 * weight, pan=pan, hp=230)


def _rush(m, at, length, peak_at, hold, tau, lo, hi, amp, pan0=0.0, pan1=0.0,
          rough=0.6, width=0.55):
    """The bow wave of a heavy body ramming through: a wide band of shoved
    air, rough with turbulence, that rises as it gets going and lets go
    after [hold]. The band rises a little toward [hi] as it reaches speed."""
    rng = m.rng
    n = round(length * SR)
    t = np.arange(n) / SR
    y = _band(rng, length,
              lambda u: lo + (hi - lo) * smooth(u * length, 0, peak_at)
              * (1 - 0.35 * smooth(u * length, hold, length)), width)
    y *= _rough(rng, n, depth=rough)
    env = _env(t, peak_at, hold, tau)
    pan = pan0 + (pan1 - pan0) * smooth(t, 0, length)
    _moving(m, at, amp * env * y, pan)


# ===========================================================================
# The basic
# ===========================================================================


def basic(v=0):
    """The horn tosses its head and a dense slug leaves it: a quick heavy
    swing of air past the horn, the slug's own thick push going away from
    us, and the head's weight stopping under it."""
    m = Mix(0.32, seed=7300 + v)
    rng = m.rng
    pan = (0.0, -0.12, 0.12, 0.06)[v]
    # The toss: a heavy curved thing swung through the air, low and quick.
    swing = (0.11, 0.12, 0.10, 0.115)[v]
    n = round(swing * SR)
    tt = np.arange(n) / SR
    y = _band(rng, swing, lambda u: 380 + 520 * np.sin(math.pi * u ** 0.7), 0.42)
    env = np.sin(math.pi * np.clip(tt / swing, 0, 1) ** 0.85) ** 2
    _put(m, 0.02, 0.045 * env * y, pan - 0.1)
    # The slug leaving: thick shoved air, darkening as it goes (it is in the
    # target by BASIC_LAND; the hit is someone else's sound).
    length = BASIC_LAND + 0.06
    n = round(length * SR)
    tt = np.arange(n) / SR
    y = _band(rng, length, lambda u: 820 - 420 * u, 0.5)
    y *= _rough(rng, n, 18, 46, 0.55)
    env = _env(tt, 0.03, 0.05, 0.06)
    _moving(m, 0.05, 0.05 * env * y, pan + 0.25 * smooth(tt, 0, length))
    # The slug's mass under it: a soft contact into dense low-mid modes as
    # the head stops, felt rather than struck.
    _knock(m, 0.055, _horn_body(rng, (200, 215, 190, 225)[v]), tc=0.007,
           amp=0.16, pan=pan, hp=220)
    m.room(t60=0.3, wet=0.1)
    return m.finish(loudness_db=-35.0, fade_out=0.06)


# ===========================================================================
# The specials -- the casts
# ===========================================================================


def charge(v=0):
    """A ram (the family-level special): the horn sets off and the air it
    shoves comes up fast and rough -- it is at full speed from the first
    frame -- holds while it runs, and lets go after CHARGE_TRAVEL, where the
    slam cue takes over. Built to sit right whether the slam lands at 0.4 s
    or at 0.85 s."""
    m = Mix(1.1, seed=7310 + v)
    pan = (0.0, -0.15, 0.15, 0.0)[v]
    _push_off(m, 0.035, 1.0, pan)
    _rush(m, 0.04, 1.0, peak_at=0.07, hold=0.4, tau=0.17, lo=300, hi=820,
          amp=0.11, pan0=pan, pan1=pan + 0.3 * (1 if v % 2 else -1))
    # Grit torn up by the wake (drawHornChargeWake throws debris behind it):
    # sparse small pieces, thinning as it runs.
    rng = m.rng
    grit = [(0.08 + 0.5 * rng.random() ** 1.3, rng.uniform(0.04, 0.1),
             pan + rng.uniform(-0.5, 0.5)) for _ in range(9)]
    chips(m, grit, 900, 3200, eta=0.08, n=3, tc=0.0004, cap=0.02)
    m.room(t60=0.45, wet=0.14)
    return m.finish(loudness_db=-31.0, fade_out=0.25)


def charge_heavy(v=0):
    """Lava and Earth: the heaviest ram, at 0.55 speed. A slower, deeper
    set-off, a lower rougher shove that takes longer to come up, and grit
    ground loose under it for the whole run."""
    m = Mix(1.45, seed=7320 + v)
    rng = m.rng
    pan = (0.0, 0.12, -0.12, 0.05)[v]
    _push_off(m, 0.05, 1.5, pan)
    _rush(m, 0.05, 1.35, peak_at=0.16, hold=0.6, tau=0.24, lo=220, hi=560,
          amp=0.12, pan0=pan, pan1=pan - 0.25, rough=0.8, width=0.6)
    # The weight grinding: a slow irregular stick-slip under the run, low.
    creak(m, 0.08, 0.8, lambda u: 40 + 30 * u, 0.5,
          _solid(rng, 170, n=14, spread=(0.1, 0.4), eta=0.07, cap=0.06),
          0.035, lambda u: smooth(u, 0, 0.15) * (1 - smooth(u, 0.6, 1.0)), pan)
    grit = [(0.1 + 0.8 * rng.random() ** 1.2, rng.uniform(0.05, 0.12),
             pan + rng.uniform(-0.6, 0.6)) for _ in range(14)]
    chips(m, grit, 700, 2600, eta=0.07, n=3, tc=0.0005, cap=0.025)
    m.room(t60=0.55, wet=0.16)
    return m.finish(loudness_db=-30.0, fade_out=0.3)


def circle(v=0):
    """Water: one lap round the cast point in CIRCLE_LAP. The shove of air
    goes once round the listener -- across, behind, back -- brighter on the
    near side of the lap, darker on the far, and lets go as the lap closes
    (the slam and the whirlpool take it from there)."""
    m = Mix(1.35, seed=7330 + v)
    rng = m.rng
    _push_off(m, 0.03, 1.0, 0.0)
    length = CIRCLE_LAP + 0.2
    n = round(length * SR)
    t = np.arange(n) / SR
    # Starts square to the aim (startAngle = fireAngle - pi/2) and turns at
    # 2 pi / lap.
    ph = 2 * math.pi * np.clip(t / CIRCLE_LAP, 0, 1.1)
    near = 0.5 + 0.5 * np.cos(ph)          # 1 = the near side of the lap
    y = _band(rng, length, lambda u: 380 + 520 * np.interp(
        u * length, t, near), 0.5)
    y *= _rough(rng, n, depth=0.6)
    env = _env(t, 0.07, CIRCLE_LAP - 0.05, 0.12) * (0.55 + 0.45 * near)
    _moving(m, 0.04, 0.11 * env * y, 0.75 * np.sin(ph))
    m.room(t60=0.45, wet=0.15)
    return m.finish(loudness_db=-31.0, fade_out=0.15)


def _windup(m, length, tension, swirl_rate):
    """The horn held still and loading: sinew and horn creaking under a
    strain that tightens to the release (the creak's rate climbs), and the
    air round it turning at [swirl_rate] Hz -- what is gathering there is
    the element's, the strain is the horn's."""
    rng = m.rng
    # Fast enough that the slips fuse into a groan (a door creaks at 20-60
    # a second through a bright panel; this is 35-110 through a dull, damped
    # body), quiet, and tightening.
    creak(m, 0.05, length - 0.05, lambda u: 35 + tension * u ** 1.6, 0.45,
          _solid(rng, 170, n=14, spread=(0.1, 0.4), eta=0.09, cap=0.05),
          0.035, lambda u: 0.25 + 0.75 * smooth(u, 0, 0.9), 0.0)
    n = round(length * SR)
    t = np.arange(n) / SR
    y = _band(rng, length, lambda u: 300 + 500 * u, 0.6)
    y *= _rough(rng, n, 8, 24, 0.5)
    # Up with the strain, and gone into the set-off rather than cut.
    env = smooth(t, 0, length) ** 1.5 * (1 - smooth(t, length - 0.12, length))
    _moving(m, 0.0, 0.05 * env * y, 0.35 * np.sin(2 * math.pi * swirl_rate * t))


def gather(v=0):
    """Crystal: 1.2 s held still while the shards spin up round it (about
    0.8 turns a second), then the ram."""
    m = Mix(CRYSTAL_WINDUP + 1.0, seed=7340 + v)
    _windup(m, CRYSTAL_WINDUP, tension=75, swirl_rate=0.8)
    _push_off(m, CRYSTAL_WINDUP, 1.0, 0.0)
    _rush(m, CRYSTAL_WINDUP + 0.005, 0.95, peak_at=0.07, hold=0.4, tau=0.17,
          lo=300, hi=820, amp=0.11, pan0=0.0, pan1=0.25)
    m.room(t60=0.45, wet=0.14)
    return m.finish(loudness_db=-31.0, fade_out=0.25)


def brace(v=0):
    """Spirit: 2.0 s held still and hardened (60 % less damage) while the
    phantoms swarm in, the strain building the whole time, then the ram."""
    m = Mix(SPIRIT_WINDUP + 1.0, seed=7350 + v)
    _windup(m, SPIRIT_WINDUP, tension=70, swirl_rate=0.55)
    _push_off(m, SPIRIT_WINDUP, 1.1, 0.0)
    _rush(m, SPIRIT_WINDUP + 0.005, 0.95, peak_at=0.07, hold=0.38, tau=0.17,
          lo=320, hi=880, amp=0.11, pan0=0.0, pan1=-0.25)
    m.room(t60=0.5, wet=0.15)
    return m.finish(loudness_db=-31.0, fade_out=0.25)


def void(v=0):
    """Dark: five seconds holding against a pull that grows from 90 to 310
    px/s. The horn's strain under it, the air dragged past it in a slow
    rising roar, and -- more and more as the pull hardens -- the obsidian
    bodies it is reeling in knocking together where they bunch. Then the
    very fast ram (2.1x, ~0.85 s) away with the catch."""
    L = DARK_WINDUP
    m = Mix(L + 1.1, seed=7360 + v)
    rng = m.rng
    # Pull, normalised the way hornDarkPullSpeed ramps it (linear in time).
    pull = lambda t: np.clip(t / L, 0, 1)  # noqa: E731
    # The strain: slow at first, tight by the end.
    creak(m, 0.1, L - 0.1, lambda u: 10 + 55 * u ** 1.8, 0.5,
          _solid(rng, 160, n=16, spread=(0.08, 0.4), eta=0.06, cap=0.08),
          0.05, lambda u: 0.25 + 0.75 * smooth(u, 0, 0.95), 0.0)
    # The drawn air: low and wide, rising and thickening with the pull.
    n = round(L * SR)
    t = np.arange(n) / SR
    y = _band(rng, L, lambda u: 220 + 380 * u ** 1.4, 0.65)
    y *= _rough(rng, n, 6, 20, 0.55)
    # ...and stops being drawn as the ram goes: it falls away over the
    # last ~0.15 s instead of being cut.
    env = ((0.12 + 0.88 * smooth(t, 0, L) ** 1.6) * smooth(t, 0, 0.6)
           * (1 - smooth(t, L - 0.15, L)))
    _moving(m, 0.0, 0.07 * env * y, 0.25 * np.sin(2 * math.pi * 0.2 * t))
    # Bodies colliding as they bunch: emitHornDarkVoidBrew's spawns step up
    # at 40 % and 75 % of the wind-up; the knocks thicken the same way.
    times = []
    tt = 0.5
    while tt < L - 0.05:
        p = float(pull(tt))
        rate = 0.8 + 3.5 * p + 3.0 * (p > 0.4) + 4.0 * (p > 0.75)
        times.append(tt)
        tt += rng.exponential(1.0 / rate)
    for t0 in times:
        p = float(pull(t0))
        side = rng.uniform(-0.7, 0.7) * (1 - 0.6 * p)  # drawn to the middle
        f0 = rng.uniform(260, 520)
        strike(m, t0, _solid(rng, f0, n=10, eta=0.07, cap=0.04),
               tc=0.0012, amp=(0.05 + 0.12 * p) * rng.uniform(0.5, 1.0),
               pan=side, lowpass=3200)
    # The release: a heavier set-off and a faster, brighter shove.
    _push_off(m, L, 1.3, 0.0)
    _rush(m, L + 0.005, 1.05, peak_at=0.05, hold=DARK_DASH - 0.4, tau=0.15,
          lo=380, hi=1100, amp=0.13, pan0=0.0, pan1=0.45, rough=0.5)
    m.room(t60=0.6, wet=0.18)
    return m.finish(loudness_db=-31.0, fade_out=0.3)


def _cavity(rng, n, f0, ratios, q, drift=0.015):
    """Air heard from inside a hollow: noise coloured by the cavity's own
    resonances, which for a dome are inharmonic (the zeros of a sphere's
    Bessel modes, not a harmonic series), so it is the hush in a shell,
    never a note. Each resonance wanders by [drift] so none settles."""
    out = np.zeros(n)
    noise = rng.normal(0, 1, n)
    t = np.arange(n) / SR
    for k, r in enumerate(ratios):
        f = f0 * r * (1 + drift * np.sin(2 * math.pi * rng.uniform(0.05, 0.12)
                                         * t + rng.uniform(0, 6.3)))
        # A resonator whose centre moves: filter in short blocks, overlap.
        blk = 2048
        y = np.zeros(n)
        win = np.hanning(2 * blk)
        for i in range(0, n, blk):
            a, b = max(0, i - blk), min(n, i + blk)
            fc = float(f[min(i, n - 1)])
            bb, aa = signal.iirpeak(fc, q, fs=SR)
            seg = signal.lfilter(bb, aa, noise[a:b])
            w = win[(a - (i - blk)):(a - (i - blk)) + (b - a)]
            y[a:b] += seg * w
        out += y / (1 + 0.5 * k)
    return out / max(float(np.std(out)), 1e-12)


def barrier(v=0):
    """Light: no ram. The horn plants itself -- its weight set down in a
    short crush of contacts, grit giving under it -- and a dome stands round
    it for the channel. Inside a dome the air takes on the dome's hollow
    resonances: a quiet shell-hush, swelling up as it forms, breathing
    slowly as its sheen slides, over a big glass body stroked very low,
    until it thins away (4.4-5.8 s with the caster's stats)."""
    L = BARRIER_LIFE
    m = Mix(L + 0.6, seed=7370 + v)
    rng = m.rng
    # Planted: set down, not struck -- a run of soft contacts into the
    # horn's dense modes over ~40 ms -- and the grit crushed under it.
    body = _solid(rng, 205, n=20, spread=(0.08, 0.3), eta=0.06, cap=0.12,
                  tilt=0.07)
    horn = _horn_body(rng, 340)
    for k, w in enumerate((0.3, 0.55, 0.8, 1.0)):
        at = 0.04 * (k / 3) ** 0.8
        _knock(m, at, body, tc=0.009, amp=0.14 * w, hp=200)
        _knock(m, at + 0.001, horn, tc=0.004, amp=0.03 * w, hp=260)
    chips(m, _fracture(0.0, 0.06, 12, 0.03, 0.12, -0.35, 0.35), 800, 2800,
          eta=0.08, n=3, tc=0.0005, cap=0.02)
    burst(m, 0.0, 220, 1200, attack=0.035, tau=0.09, amp=0.06)
    # The dome forming round it: the hollow comes up over ~0.6 s.
    n = round((L + 0.5) * SR)
    t = np.arange(n) / SR
    hush = _cavity(rng, n, 270, [1.0, 1.61, 2.17, 2.72, 3.26, 3.8], q=9)
    breathe = 0.82 + 0.18 * np.sin(2 * math.pi * t / 3.1 + 0.6)
    env = smooth(t, 0.08, 0.7) * (1 - smooth(t, L - 1.0, L + 0.4)) * breathe
    # The sheen sliding over it: a slow sway across.
    _moving(m, 0.0, 0.0055 * env * hush, 0.3 * np.sin(2 * math.pi * t / 6.0))
    # The shell itself: a big glass body stroked very low, under everything.
    m.glass(0.1, 196, amp=0.01, ring=6.0, attack=0.7, brightness=0.1,
            pan=-0.15, beat=0.45, ratios=[1.0, 2.32, 4.25])
    m.glass(0.2, 287, amp=0.005, ring=5.0, attack=0.9, brightness=0.08,
            pan=0.2, beat=0.35, ratios=[1.0, 2.32])
    m.room(t60=1.0, wet=0.2)
    return m.finish(loudness_db=-37.0, fade_out=0.6)


# ===========================================================================
# The moments after the cast
# ===========================================================================


def _slam(m, heavy, v):
    rng = m.rng
    pan = (0.0, -0.12, 0.12, 0.05)[v]
    f0 = (205 if not heavy else 175) * rng.uniform(0.95, 1.05)
    # The horn into the body in front of it. Not one point of contact: a
    # ram crushes in, so the blow is a run of contacts over ~25 ms, each
    # harder than the last, into the same dense modes (horn and struck stone
    # together). Contacts of ~2 ms, as hard as combatHitHeavy's, so the
    # weight is heard in the crunch of many modes a phone plays; a softer
    # contact put it all under 300 Hz, which is a thump. The run is also
    # what keeps the onset from being a spike.
    body = _solid(rng, f0, n=24, spread=(0.07, 0.28), eta=0.055,
                  cap=0.16 if not heavy else 0.2, tilt=0.06)
    horn = _horn_body(rng, 330 * rng.uniform(0.95, 1.05))
    span = 0.024 if not heavy else 0.034
    for k, w in enumerate((0.25, 0.4, 0.6, 0.8, 1.0)):
        at = span * (k / 4) ** 0.8 + rng.uniform(0, 0.002)
        _knock(m, at, body, tc=(0.0022 if not heavy else 0.003) * rng.uniform(0.85, 1.15),
               amp=(0.2 if not heavy else 0.1) * w, pan=pan,
               hp=300 if not heavy else 260)
        _knock(m, at + 0.001, horn, tc=0.0015, amp=0.05 * w, pan=pan, hp=280)
    # Stone giving under the horn: a short run of fracture leading in.
    chips(m, _fracture(0.0, 0.04, 10, 0.04, 0.12, pan - 0.25, pan + 0.25),
          900, 3400, eta=0.08, n=3, tc=0.0004, cap=0.025)
    # The shock: pressure leaving the hit, leaning in, heaviest forward.
    burst(m, 0.0, 240, 1500 if not heavy else 1150, attack=0.022,
          tau=0.09 if not heavy else 0.13, amp=0.11, pan=pan)
    # The horn skidding to a stop against what it hit: a short rough grind.
    creak(m, 0.015, 0.14 if not heavy else 0.22, lambda u: 120 - 70 * u, 0.5,
          _solid(rng, 380, n=10, spread=(0.15, 0.5), eta=0.07, cap=0.03),
          0.05, lambda u: (1 - u) ** 1.5, pan)
    # Debris thrown forward with the shock front (drawHornSlam's pieces fly
    # out over the 0.5 s it eases out); heavy throws bigger, lower chunks.
    count = 9 if not heavy else 12
    lo, hi = (800, 2800) if not heavy else (450, 1900)
    chips(m, _shards(rng, 0.04, count, 0.1 if not heavy else 0.14,
                     0.15 if not heavy else 0.12, 0.85,
                     (SLAM_FX if not heavy else SLAM_FX_HEAVY) - 0.1),
          lo, hi, eta=0.07, n=4, tc=0.0006 if not heavy else 0.0009,
          cap=0.035 if not heavy else 0.05)
    if heavy:
        # Earth/Lava: the heap settling after it, a few big pieces late.
        late = [(0.22 + 0.3 * k / 4 + rng.uniform(0, 0.04),
                 0.06 * (1 - 0.5 * k / 4), rng.uniform(-0.6, 0.6))
                for k in range(5)]
        chips(m, late, 380, 1300, eta=0.07, n=5, tc=0.0012, cap=0.05)
    m.air(0.0, 0.45 if not heavy else 0.6, 230, 1000, amp=0.05, rise=0.08,
          pan=pan)


def slam(v=0):
    """A ram landing (HornFx.slam): the horn driven into what is in front of
    it -- a dense, dull blow with no boom -- the stone giving, a short skid,
    the shock leaving forward and the debris it throws, all inside the
    slam's 0.5 s. The obsidian hits themselves are combatHit's."""
    m = Mix(0.62, seed=7380 + v)
    _slam(m, False, v)
    m.room(t60=0.55, wet=0.15)
    return m.finish(loudness_db=-30.0, fade_out=0.15)


def slam_heavy(v=0):
    """Earth and Lava's slam (0.66 s): lower, softer and longer in the
    contact, bigger pieces thrown, and the heap settling after."""
    m = Mix(0.82, seed=7390 + v)
    _slam(m, True, v)
    m.room(t60=0.7, wet=0.17)
    return m.finish(loudness_db=-29.0, fade_out=0.18)


def brew(v=0):
    """Lightning: the horn landed and holds for BREW while a storm brews on
    it. Static crawling over it, sparse then thick; arcs jumping more often
    as it goes (emitHornLightningStormBrew: 0.30 -> 0.75 of frames, spawns
    stepping up at 40 % and 75 %); the air round it tightening. It does not
    release: the discharge is its own cue, on the frame the burst goes.
    (The horn is still and the storm is the point, so no strain under it.)"""
    m = Mix(BREW + 0.05, seed=7400 + v)
    rng = m.rng
    t = np.arange(m.n) / SR
    k = lambda t: np.clip(t / BREW, 0, 1)  # noqa: E731
    # Static: fine dry ticks crawling over the body.
    m.grains(lambda t: 60 + 900 * k(t) ** 1.5 + 400 * (k(t) > 0.4)
             + 600 * (k(t) > 0.75),
             lambda t: 0.42 + 0.25 * k(t),
             lambda t: 0.4 * np.sin(2 * math.pi * 0.7 * t), amp=0.4,
             weight=lambda t: 0.35 + 0.4 * k(t))
    # Arcs: a few a second at first, many by the end; each 20-80 ms.
    events = []
    tt = 0.15
    while tt < BREW - 0.04:
        p = tt / BREW
        rate = 2.0 + 14.0 * p ** 1.4
        length = rng.uniform(0.02, 0.05 + 0.04 * p)
        events.append((tt, length, rng.uniform(0.4, 1.0) * (0.35 + 0.65 * p),
                       rng.uniform(-0.6, 0.6)))
        tt += rng.exponential(1.0 / rate)
    _arcs(m, events, 0.2)
    # The air round it charging: a thin hiss, rising and brightening.
    y = _band(rng, BREW, lambda u: 1100 + 1600 * u, 0.5)
    y *= _rough(rng, len(y), 10, 30, 0.3)
    env = smooth(np.arange(len(y)) / SR, 0, BREW) ** 2
    _moving(m, 0.0, 0.012 * env * y, np.zeros(len(y)))
    m.room(t60=0.4, wet=0.12)
    return m.finish(loudness_db=-33.0, fade_out=0.05)


def discharge(v=0):
    """Lightning: the brew let go as a chain shockwave. A crackle that leans
    in over ~25 ms and spreads -- a change of texture, not a crash -- the
    pressure shoved out from the horn, and sparks crackling away outward and
    thinning over the burst's ~1 s (emitHornLightningChainBurst: 0.3-1.2 s
    particles flying out at 60-240 px/s)."""
    m = Mix(1.1, seed=7410 + v)
    rng = m.rng
    # The let-go: dense crackle, coming up over ~25 ms.
    m.grains(lambda t: 9000 * smooth(t, 0.0, 0.025) * np.exp(-np.maximum(t - 0.025, 0) / 0.07),
             lambda t: 0.8 + 0 * t, lambda t: 0 * t, amp=0.3,
             weight=lambda t: 0.6 + 0 * t)
    _arcs(m, [(rng.uniform(0.0, 0.03), rng.uniform(0.05, 0.09),
               rng.uniform(0.7, 1.0), rng.uniform(-0.5, 0.5)) for _ in range(5)],
          0.07)
    # The shock: pressure leaving, low and wide.
    burst(m, 0.0, 280, 2200, attack=0.028, tau=0.13, amp=0.08)
    # The horn bracing against its own blast.
    _knock(m, 0.01, _horn_body(rng, 230), tc=0.006, amp=0.12, hp=260)
    # Sparks flying outward and dying: wider, sparser, later.
    sparks = []
    for k in range(40):
        t0 = 0.03 + rng.exponential(0.2)
        if t0 > 1.0:
            continue
        side = (1 if k % 2 else -1) * min(0.95, 0.15 + 0.9 * t0)
        sparks.append((t0, 0.12 * math.exp(-t0 / 0.45) * rng.uniform(0.5, 1.0),
                       side * rng.uniform(0.6, 1.0)))
    chips(m, sparks, 2000, 5200, eta=0.2, n=2, tc=0.00025, cap=0.006)
    _arcs(m, [(0.08 + rng.exponential(0.18), rng.uniform(0.02, 0.05),
               rng.uniform(0.3, 0.6), rng.uniform(-0.9, 0.9)) for _ in range(6)],
          0.04)
    m.room(t60=0.6, wet=0.16)
    return m.finish(loudness_db=-30.0, fade_out=0.25)


# ===========================================================================
# What the game picks by element
# ===========================================================================

# Element -> the special's cast pattern. None = the family-level
# sfx_special_horn (the standard ram). Air and Mud never cast (passive).
SPECIAL_PATTERNS = {
    'Fire': None,
    'Lava': 'heavy',
    'Lightning': None,      # + sfx_special_horn_brew / _discharge after it lands
    'Water': 'circle',
    'Ice': None,
    'Steam': None,
    'Earth': 'heavy',
    'Mud': None,            # passive: never cast
    'Dust': None,
    'Crystal': 'gather',
    'Air': None,            # passive: never cast
    'Plant': None,
    'Poison': None,
    'Spirit': 'brace',
    'Dark': 'void',
    'Light': 'barrier',
    'Blood': None,
}

# Element -> the slam played when its ram lands (Light, Air and Mud never ram).
SLAM_CUES = {e: 'sfx_special_horn_slam' for e in SPECIAL_PATTERNS}
SLAM_CUES.update({'Earth': 'sfx_special_horn_slam_heavy',
                  'Lava': 'sfx_special_horn_slam_heavy'})
for _e in ('Light', 'Air', 'Mud'):
    SLAM_CUES[_e] = None


def _v(build, description):
    return {'build': build, 'description': description, 'variants': 3}


CUES = {
    'sfx_basic_horn': _v(
        basic, 'Horn tosses its head: a heavy swing of air, a thick slug shoved away, the head\'s weight stopping under it'),
    'sfx_special_horn': _v(
        charge, 'A ram: the horn sets off and the rough air it shoves comes up fast, holds while it runs and lets go'),
    'sfx_special_horn_heavy': _v(
        charge_heavy, 'Lava/Earth ram: a slow deep set-off, a lower rougher shove and grit ground loose all the way'),
    'sfx_special_horn_circle': (
        circle, 'Water: the shove of air goes once round the listener in a second, near side bright, far side dark'),
    'sfx_special_horn_gather': (
        gather, 'Crystal: held 1.2 s, horn and sinew creaking tighter as the air turns round it, then the ram'),
    'sfx_special_horn_brace': (
        brace, 'Spirit: held 2.0 s, the strain building as the swarm turns in, then the ram'),
    'sfx_special_horn_void': (
        void, 'Dark: five seconds straining against a growing pull, the air dragged past, reeled-in bodies knocking together, then a very fast ram'),
    'sfx_special_horn_barrier': (
        barrier, 'Light: the horn plants itself, and inside the dome the air takes its hollow hush over a low stroked glass for five seconds, breathing, then thins'),
    'sfx_special_horn_slam': _v(
        slam, 'A ram landing: a dense dull blow, stone giving, a short skid, the shock and the debris thrown forward'),
    'sfx_special_horn_slam_heavy': _v(
        slam_heavy, 'Earth/Lava ram landing: lower and softer in the blow, bigger pieces thrown, the heap settling'),
    'sfx_special_horn_brew': (
        brew, 'Lightning horn holding 3 s: static crawling thicker, arcs jumping more often, the air tightening'),
    'sfx_special_horn_discharge': (
        discharge, 'The brewed storm let go: crackle leaning in and spreading, pressure shoved out, sparks thinning away'),
}
