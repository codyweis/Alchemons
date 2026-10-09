"""Mane: the Catapult / Piercing family -- its auto-attack and its special,
scored to what is drawn.

THE BASIC (createFamilyBasicAttack 'mane', cosmic_data.dart)
  Two crescent blades leave on the SAME frame, side by side at +/-0.08 rad,
  15 units out, at kManeBasicSpeedMultiplier 0.5 (300 u/s, 2 s life). They
  do not spin (drawAlchemicalManeBasicVisual rotates them to their heading
  only): a material edge with a short wake, "a thrown slash rather than a
  shot". The attack range is ~160-230 units (alchemonBaseRange x 0.95), so
  the pair is in the air ~0.5-0.75 s before it lands, and the landing has
  its own hit (combatHitLight/Heavy). Fired every ~0.5-1.5 s per Mane.
  So: ONE throw releasing TWO edges together -- not two cuts in a row (the
  first pass) -- that then fly off as a pair, slowly widening, quietly gone
  by ~0.45 s.

THE SPECIAL (_maneSpecial + scaleManeProjectile, cosmic_data.dart; the
survival special branch; mane_runtime.dart)
  Nothing winds up: the shot is appended on the cast frame. Then by element:

  catapult  Lava Poison Blood Ice Crystal Plant Dust Steam Water Earth Mud
            Dark -- ONE heavy piercing body (visualScale 2.4-4.4), clamped
            to speed 0.12-0.29 = ~174 u/s and alive 11-15 s. The special
            range is ~180-260, so the first pierce lands ~1.1-1.5 s after
            the cast; the body is still on screen ~3 s. Pierces have their
            own hits. (Earth sheds a quake burst every 0.72 s, Steam a geyser
            puff and Dust a cloud every 0.35 s, Lava a blob per pierce; Mud
            bursts into ten on its first hit; Crystal blows up on a boss.)
  gale      Air -- the one fast Mane: speed clamped 0.75-1.4 (~840 u/s),
            reaches its first body in ~0.25 s, shoves what it pierces.
  volley    Fire -- 4/8/16 fireballs over a 0.92*pi fan, all on one frame,
            ~480 u/s: in range in ~0.45 s, off screen in ~1 s.
  scatter   Lightning -- 5-10 small sigil orbs flung out on golden-angle
            headings (all round, not a fan) at ~500-550 u/s; each LANDS
            0.3-1.4 s later on its own and blooms into a shock field.
  stream    Spirit -- 1..10 shots (one more each cast) in a tight line 9
            units apart, all on one frame, the later ones a touch faster.
  ward      Light -- nothing is thrown: a ring is hung (or fed) turning
            round the caster at radius 38-126, 0.62-1.55 rad/s.

  The caster's element accent (sfx_element_<x>, 0.55-0.9 s) still plays on
  top and carries the material; these carry the THROW: mass, air, motion.

LATER MOMENTS (no sound of their own until now -- they played the ship's gun
puff, combatProjectile, through _appendCompanionProjectile):
  orb_land  a Lightning orb seats and its shock field takes
  burst     the Mud ball's first hit: it bursts and flings ten clods
  shatter   the Crystal prism hits a boss and blows (survival / open space)
  quake     the Earth slab sheds a quake burst (every 0.72 s)

Voices: strike/chips/burst are the modal and pressure voices of
tool/sounds/combat.py, copied so this module does not move when that one
does; swish takes a moving pan; rush, crackle and the punch-levelling are
new here.
"""
import math
import warnings

import numpy as np
from scipy import signal

from sounds.core import SR, Mix

# ===========================================================================
# Timing, from the Dart
# ===========================================================================

BLADE_SPEED = 600 * 0.5            # Projectile.speed x kManeBasicSpeedMultiplier
BLADE_FLIGHT = 0.6                 # ~180 u attack range / 300 u/s
CATAPULT_SPEED = 600 * 0.29        # scaleManeProjectile's clamp ceiling
FIRST_PIERCE = 1.25                # ~220 u special range / 174 u/s
GALE_SPEED = 600 * 1.4             # Air's clamp ceiling
FIRE_SPEED = 600 * 0.8             # Fire's clamp ceiling
QUAKE_INTERVAL = 0.72              # Earth turretInterval

# Every special pattern is levelled on its loudest 300 ms (phone band), as
# the element accents are (their punch is -27): the throw sits a few dB
# under the element on top of it, and a long travel tail does not push the
# front of the cue up the way whole-file levelling would.
SPECIAL_PUNCH_DB = -30.5


# ===========================================================================
# Voices
# ===========================================================================


def _put(m, start, mono, pan=0.0):
    s0 = m._at(start)
    mono = mono[: m.n - s0]
    if callable(pan):
        u = np.arange(len(mono)) / max(len(mono) - 1, 1)
        p = np.clip(pan(u), -1, 1)
        m.y[0, s0:s0 + len(mono)] += np.cos((p + 1) * math.pi / 4) * mono
        m.y[1, s0:s0 + len(mono)] += np.sin((p + 1) * math.pi / 4) * mono
        return
    gl, gr = m._gains(float(np.clip(pan, -1, 1)))
    m.y[0, s0:s0 + len(mono)] += gl * mono
    m.y[1, s0:s0 + len(mono)] += gr * mono


def _contact(tc):
    """The force of a contact lasting [tc] seconds: a Hertzian half-sine."""
    n = max(2, round(tc * SR))
    p = np.sin(np.linspace(0, math.pi, n + 2)[1:-1])
    return p / p.sum()


def _ring(freqs, t60s, amps, length):
    t = np.arange(round(length * SR)) / SR
    out = np.zeros(len(t))
    for f, t60, a in zip(freqs, t60s, amps):
        if f < SR * 0.45:
            out += a * np.exp(-6.9 * t / t60) * np.sin(2 * math.pi * f * t)
    return out


def _solid(rng, f0, n=14, spread=(0.10, 0.38), eta=0.05, cap=0.2, tilt=0.12):
    """An irregular solid's modes: inharmonic, each decaying with a constant
    loss factor [eta] (stone ~0.05, crystal ~0.01); [cap] bounds the ring."""
    ratios = np.cumprod(np.r_[1.0, 1.0 + rng.uniform(*spread, n - 1)])
    f = f0 * ratios
    t60 = np.minimum(2.2 / (eta * f), cap)
    a = np.exp(-tilt * np.arange(n)) * rng.uniform(0.45, 1.0, n)
    a *= rng.choice([-1.0, 1.0], n)
    return f, t60, a


def strike(m, start, modes, tc, amp, pan=0.0, lowpass=None):
    """[modes] rung by a contact of width [tc] (short = hard, long = dull)."""
    f, t60, a = modes
    length = min(1.5, float(np.max(t60)) * 1.3 + 0.01)
    out = signal.fftconvolve(_contact(tc), _ring(f, t60, a, length))
    out = signal.sosfilt(signal.butter(
        2, 0.7 * float(np.min(f)), btype='highpass', fs=SR, output='sos'), out)
    if lowpass:
        out = signal.sosfilt(
            signal.butter(2, lowpass, btype='lowpass', fs=SR, output='sos'), out)
    _put(m, start, amp * out, pan)


def chips(m, events, f_lo, f_hi, eta=0.05, n=4, tc=0.0004, cap=0.08,
          lowpass=None):
    """Small bodies struck at [events] = [(time, size, pan)], each its own."""
    rng = m.rng
    for t0, size, pan in events:
        f0 = math.exp(rng.uniform(math.log(f_lo), math.log(f_hi)))
        modes = _solid(rng, f0, n=n, spread=(0.18, 0.6), eta=eta, cap=cap,
                       tilt=0.25)
        strike(m, t0, modes, tc * rng.uniform(0.7, 1.4), size, pan,
               lowpass=lowpass)


def burst(m, start, low, high, attack, tau, amp, pan=0.0):
    """A puff of pressure: band noise leaning in over [attack], dying [tau]."""
    n = round((attack + 6 * tau) * SR)
    t = np.arange(n) / SR
    env = np.where(t < attack, (t / attack) ** 2, np.exp(-(t - attack) / tau))
    sos = signal.butter(2, [low, high], btype='bandpass', fs=SR, output='sos')
    _put(m, start, amp * env * signal.sosfilt(sos, m.rng.normal(0, 1, n)), pan)


def _lean(a, tau):
    """An envelope over u: in as a square over [a], out exponentially."""
    return lambda u: np.where(u < a, (np.clip(u, 0, 1) / a) ** 2,
                              np.exp(-(u - a) / tau))


def _cut_and_fly(u):
    """A blade's envelope over its 0.45 s: the cut (in over ~14 ms, most of
    it gone in ~60 ms), then the flight -- ~14 dB down, thinning slowly
    until about where it lands."""
    a = 0.03
    inn = np.where(u < a, (np.clip(u, 0, 1) / a) ** 2, 1.0)
    d = np.maximum(u - a, 0)
    return inn * (0.8 * np.exp(-d / 0.12) + 0.2 * np.exp(-d / 0.4))


def swish(m, start, length, fc, width, env, amp, pan=0.0, rough=None):
    """Air moving past an edge or a body. [fc](u) is where the band sits
    (Hz), [env](u) how loud, over u = 0..1 of [length]; [width] is the band's
    spread in log units. The band is carved from noise frame by frame, so it
    slides and never settles on a resonance (which would whistle). [pan] may
    be a function of u (the thing moving across the field). [rough], if
    given, is (rate Hz, depth): turbulence buffeting the stream."""
    n = round(length * SR)
    nper, hop = 512, 128
    pad = nper
    noise = m.rng.normal(0, 1, n + 2 * pad)
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
    y *= 0.15 / max(float(np.sqrt(np.mean(y ** 2))), 1e-12)
    uu = np.arange(n) / max(n - 1, 1)
    e = env(uu)
    if rough:
        e = e * _wobble(m.rng, n, *rough)
    # Whatever the envelope says at its ends, a segment never starts or stops
    # on a step (that is a click).
    k = min(round(0.008 * SR), n // 2)
    e[-k:] *= np.cos(np.linspace(0, math.pi / 2, k)) ** 2
    e[:k // 4] *= np.linspace(0, 1, k // 4)
    _put(m, start, amp * e * y, pan)


def _wobble(rng, n, rate, depth):
    """Slow random swelling, 1 +/- [depth], moving at about [rate] Hz: the
    uneven way air churns round a big tumbling body."""
    x = rng.normal(0, 1, n + SR)
    sos = signal.butter(2, rate, btype='lowpass', fs=SR, output='sos')
    x = signal.sosfilt(sos, x)[SR:]
    x /= max(float(np.std(x)), 1e-12)
    # Floored well above silence: churning air thins, it never stops, and a
    # deep trough reads as the thing being thrown twice.
    return np.clip(1 + depth * x, 0.5, None)


def rush(m, start, length, f_from, f_to, amp, peak=0.06, tau=0.45,
         width=0.55, churn=(3.0, 0.35), pan=0.0):
    """A big body shoving its way through the air and receding: a wide band
    that darkens as it goes away (f_from -> f_to), swelling in by [peak] of
    the way and dying with time constant [tau] (as a fraction), churning."""
    swish(m, start, length,
          lambda u: f_from * (f_to / f_from) ** (np.clip(u, 0, 1) ** 0.7),
          width, _lean(peak, tau), amp, pan, rough=churn)


def crackle(m, start, length, rate, low, high, amp, pan=0.0, size=None):
    """Electric crackle: a Poisson rain of tiny discharges, [rate](u) per
    second, each a sub-millisecond spit of noise, band-limited. Texture, not
    one spike. [size](u) shapes how big they are over time."""
    n = round(length * SR)
    u = np.arange(n) / max(n - 1, 1)
    hits = m.rng.poisson(np.maximum(rate(u), 0) / SR)
    idx = np.nonzero(hits)[0]
    x = np.zeros(n)
    if len(idx):
        # Sizes kept close together: one outsized spit is a click that
        # sticks out of the crackle.
        s = np.minimum(m.rng.lognormal(-0.2, 0.45, len(idx)), 1.8)
        if size is not None:
            s *= size(u[idx])
        x[idx] = s * m.rng.choice([-1.0, 1.0], len(idx))
    # Every spit its own little noise burst (one shared kernel would give
    # the whole crackle one fixed comb of a color): eight kernels, the
    # discharges dealt among them.
    k = round(0.0012 * SR)
    deal = m.rng.integers(0, 8, n)
    y = np.zeros(n)
    for g in range(8):
        kern = m.rng.normal(0, 1, k) * np.exp(
            -np.arange(k) / (m.rng.uniform(0.00015, 0.0004) * SR))
        y += signal.fftconvolve(np.where(deal == g, x, 0.0), kern)[:n]
    y = signal.sosfilt(signal.butter(2, [low, high], btype='bandpass', fs=SR,
                                     output='sos'), y)
    _put(m, start, amp * y, pan)


def _finish_punch(m, punch_db, fade_out):
    """Level so the loudest 300 ms a phone plays sits at [punch_db]."""
    y = m.finish(loudness_db=-50.0, fade_out=fade_out)
    band = signal.butter(4, [300, 8000], btype='bandpass', fs=SR, output='sos')
    ms = np.mean(signal.sosfilt(band, y, axis=1) ** 2, axis=0)
    w = round(0.3 * SR)
    run = np.convolve(ms, np.ones(w) / w, mode='valid')
    loudest = 10 * math.log10(float(run.max()) + 1e-20)
    y *= 10 ** ((punch_db - loudest) / 20)
    assert np.max(np.abs(y)) < 10 ** (-3 / 20), 'too hot: lower the punch'
    return y


# ===========================================================================
# The basic: two blades, one throw
# ===========================================================================


def basic(v=0):
    """The pair leaves together: the arm's short sweep under two edges that
    cut the air at once, one each side, then fly off as a widening pair --
    quiet by the time they would land (~0.5 s), where the hit takes over."""
    length = 0.46
    m = Mix(length, seed=7100 + v)
    rng = m.rng
    side = (0.28, 0.34, 0.24, 0.3)[v]
    lead = (1, -1, -1, 1)[v]
    # The throw: a mane whipped round, lower and broader than the edges.
    swish(m, 0.0, 0.15,
          lambda u: 520 + 900 * np.sin(math.pi * np.clip(u, 0, 1) ** 0.6),
          0.5, lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.5) ** 2,
          0.07, pan=0.08 * lead)
    # The two edges: same frame, so a few ms apart at most -- one throw of
    # two things. Each slightly different, so they are two and not one.
    for k, s in enumerate((-1, 1)):
        at = 0.003 + (0.0 if s == lead else rng.uniform(0.002, 0.006))
        top = rng.uniform(3800, 4600) * (1.0 if k == 0 else 1.09)
        low = top * 0.5
        # Bright at the cut, then darker and quieter as it flies away; the
        # pair widens (+/-0.08 rad apart) as it goes.
        swish(m, at, length - at - 0.005,
              lambda u, top=top, low=low: low + (top - low) * np.exp(
                  -np.maximum(u - 0.06, 0) / 0.18) * np.clip(u / 0.06, 0, 1) ** 0.5,
              0.26, _cut_and_fly, 0.13,
              pan=lambda u, s=s: s * (side + 0.12 * np.clip(u, 0, 1)))
    m.room(t60=0.3, wet=0.08)
    return m.finish(loudness_db=-35.0, fade_out=0.08)


# ===========================================================================
# The special: the catapult and its kin
# ===========================================================================


def _heave(m, start, amp, rng, lean=0.028):
    """The throw itself: the arm coming through (a mid sweep that leans in,
    no wind-up drawn so it is over fast) and the mass leaving it (a low
    shove of pressure). Weight from breadth, not from a thump."""
    swish(m, start, 0.22,
          lambda u: 450 + 1300 * np.sin(math.pi * np.clip(u, 0, 1) ** 0.55),
          0.5, lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.45) ** 2,
          0.11 * amp, pan=rng.uniform(-0.1, 0.1))
    burst(m, start, 160, 900, attack=lean, tau=0.07, amp=0.11 * amp)


def special(v=0):
    """catapult: one heavy body heaved off and crawling away through the
    field. The rush of it peaks as it leaves and stays heard, churning and
    slowly darkening, through the ~1.25 s it takes to reach its first body
    (that pierce is its own hit), then thins out by ~2.3 s while it is still
    in view."""
    length = 2.4
    m = Mix(length, seed=7200 + v)
    rng = m.rng
    _heave(m, 0.0, 1.0, rng)
    # The body in the air: wide, low-mid, churning at 2-4 Hz.
    rush(m, 0.01, length - 0.05, 1050, 380, 0.15,
         peak=0.03, tau=0.55, width=0.6, churn=(3.0, 0.22))
    # Its leading face tearing the air: a thinner, higher layer that fades
    # first, so the body sounds further off as it goes.
    rush(m, 0.02, 1.5, 2400, 900, 0.045, peak=0.04, tau=0.3, width=0.4,
         churn=(6.0, 0.5), pan=0.05)
    m.room(t60=0.9, wet=0.2, darkness=3000)
    return _finish_punch(m, SPECIAL_PUNCH_DB, fade_out=0.4)


def special_gale(v=0):
    """gale (Air): the one fast Mane. Thrown hard and gone: a heavy gust
    tearing past, buffeted, on its first body in ~0.25 s and off the screen
    in well under a second -- the tail is it going away."""
    length = 1.05
    m = Mix(length, seed=7300 + v)
    rng = m.rng
    side = (0.3, -0.3, 0.25, -0.2)[v]
    _heave(m, 0.0, 0.7, rng, lean=0.02)
    # The shot itself: bright as it leaves, darkening fast as it goes away,
    # carried to one side, roughened by turbulence.
    swish(m, 0.005, length - 0.01,
          lambda u: 900 + 2600 * np.exp(-np.maximum(u - 0.05, 0) / 0.2)
          * np.clip(u / 0.05, 0, 1),
          0.45, _lean(0.04, 0.22), 0.2,
          pan=lambda u: side * np.clip(u / 0.4, 0, 1), rough=(40.0, 0.45))
    rush(m, 0.0, 0.8, 700, 300, 0.1, peak=0.06, tau=0.3, churn=(8.0, 0.4),
         pan=lambda u: 0.6 * side * u)
    m.room(t60=0.6, wet=0.15)
    return _finish_punch(m, SPECIAL_PUNCH_DB + 0.5, fade_out=0.2)


def special_volley(v=0):
    """volley (Fire): a spray of fireballs over a half-circle fan, all let
    go on one frame and fast. One throw that comes apart into many small
    tears of air across the whole field, left to right, gone in ~1 s."""
    length = 1.0
    m = Mix(length, seed=7400 + v)
    rng = m.rng
    _heave(m, 0.0, 0.6, rng, lean=0.02)
    count = (8, 9, 7, 10)[v]
    for i in range(count):
        t = i / (count - 1) - 0.5
        # Same frame: tiny jitter only, which also keeps the front leaning in
        # rather than piling into one spike.
        at = 0.006 + abs(rng.normal(0, 0.012))
        top = rng.uniform(3000, 4400)
        swish(m, at, rng.uniform(0.4, 0.6),
              lambda u, top=top: 1300 + (top - 1300) * np.exp(
                  -np.maximum(u - 0.06, 0) / 0.25) * np.clip(u / 0.06, 0, 1) ** 0.5,
              0.3, _lean(0.04, rng.uniform(0.18, 0.28)),
              0.07 * rng.uniform(0.7, 1.0),
              pan=lambda u, t=t: np.clip(1.7 * t * (0.8 + 0.3 * u), -1, 1))
    # The spray as one thing, going away.
    rush(m, 0.01, 0.95, 2200, 900, 0.05, peak=0.05, tau=0.35, width=0.6,
         churn=(10.0, 0.4))
    m.room(t60=0.6, wet=0.14)
    return _finish_punch(m, SPECIAL_PUNCH_DB + 0.5, fade_out=0.2)


def special_scatter(v=0):
    """scatter (Lightning): a handful of small orbs flung out every way at
    once (golden-angle headings round the field). Light flicks spread all
    over the stereo field; each orb's LANDING is its own cue (orb_land)."""
    length = 0.95
    m = Mix(length, seed=7500 + v)
    rng = m.rng
    # A toss, not a heave: lighter and quicker.
    swish(m, 0.0, 0.15,
          lambda u: 600 + 1200 * np.sin(math.pi * np.clip(u, 0, 1) ** 0.55),
          0.5, lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.5) ** 2,
          0.07, pan=rng.uniform(-0.1, 0.1))
    count = (7, 6, 8, 7)[v]
    phase = rng.uniform(0, 2 * math.pi)
    for i in range(count):
        at = 0.005 + abs(rng.normal(0, 0.014))
        top = rng.uniform(3600, 5200)
        pan = 0.85 * math.sin(phase + i * 2.399963)
        # Each flick, then its orb in the air, thinning toward where the
        # landings (orb_land) take over.
        swish(m, at, rng.uniform(0.75, 0.9),
              lambda u, top=top: 1800 + (top - 1800) * np.exp(
                  -np.maximum(u - 0.03, 0) / 0.1) * np.clip(u / 0.03, 0, 1) ** 0.5,
              0.24, lambda u: _cut_and_fly(u * 0.45 / 0.8), 0.06 * rng.uniform(0.7, 1.0),
              pan=lambda u, p=pan: p * (0.6 + 0.4 * np.clip(u * 2, 0, 1)))
    m.room(t60=0.5, wet=0.12)
    return _finish_punch(m, SPECIAL_PUNCH_DB - 1.5, fade_out=0.15)


def special_stream(v=0):
    """stream (Spirit): one to ten shots in a tight line, thrown on one
    frame. The throw, then several edges in close file -- a ripple through
    the air, not a rhythm -- and a lighter body crawling away like the
    catapult's (they share its speed)."""
    length = 2.0
    m = Mix(length, seed=7600 + v)
    rng = m.rng
    _heave(m, 0.0, 0.75, rng)
    edges = (5, 4, 6, 5)[v]
    at = 0.004
    for i in range(edges):
        top = rng.uniform(2600, 3400)
        swish(m, at, 0.5,
              lambda u, top=top: 1000 + (top - 1000) * np.exp(
                  -np.maximum(u - 0.05, 0) / 0.22) * np.clip(u / 0.05, 0, 1) ** 0.5,
              0.3, _lean(0.05, 0.25), 0.06 * (1 - 0.1 * i),
              pan=((i % 3) - 1) * 0.14)
        at += rng.uniform(0.009, 0.016)
    rush(m, 0.02, length - 0.06, 1300, 520, 0.1, peak=0.04, tau=0.5,
         width=0.55, churn=(3.5, 0.35))
    m.room(t60=0.9, wet=0.22, darkness=3600)
    return _finish_punch(m, SPECIAL_PUNCH_DB, fade_out=0.35)


def special_ward(v=0):
    """ward (Light): nothing is thrown. A weight is swung out and taken into
    orbit round the caster: one slow arc of air carried across the field as
    the ring comes round, settling into a soft held turning that fades."""
    length = 1.5
    m = Mix(length, seed=7700 + v)
    rng = m.rng
    d = (1, -1, 1, -1)[v]
    # The swing out: slow in (~70 ms), the band lifting as it comes round
    # and settling as it takes its station.
    swish(m, 0.0, 1.0,
          lambda u: 420 + 1100 * np.sin(math.pi * np.clip(u, 0, 1) ** 0.6) ** 1.5,
          0.5, lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.55) ** 2,
          0.15, pan=lambda u: d * (-0.55 + 1.05 * np.clip(u, 0, 1) ** 0.8))
    # The held turning: a soft wide breath that circles a little and goes.
    swish(m, 0.25, length - 0.27,
          lambda u: 900 - 250 * u, 0.6,
          lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.75) ** 2,
          0.1, pan=lambda u: 0.35 * d * np.cos(math.pi * (u + 0.2)),
          rough=(1.5, 0.3))
    m.room(t60=1.0, wet=0.24, darkness=3800)
    return _finish_punch(m, SPECIAL_PUNCH_DB - 1.0, fade_out=0.35)


# ===========================================================================
# Later moments
# ===========================================================================


def orb_land(v=0):
    """A Lightning orb seats where it was thrown and its shock field takes:
    a small soft settle, and a crackle that spreads across the field's
    44-48 unit radius and thins (the field then lives 4 s on its own)."""
    length = 0.5
    m = Mix(length, seed=7800 + v)
    rng = m.rng
    pan = (-0.3, 0.25, 0.1, -0.15)[v]
    strike(m, 0.004, _solid(rng, rng.uniform(620, 760), n=10, eta=0.1,
                            cap=0.03), tc=0.0025, amp=0.35, pan=pan)
    # The field taking: the discharges lean in over ~25 ms, thickest at once,
    # thinning as it settles.
    crackle(m, 0.0, 0.46,
            lambda u: 3200 * np.minimum(u / 0.05, 1) * np.exp(-u / 0.2) + 50,
            2200, 7000, 0.55, pan=pan,
            size=lambda u: np.minimum(u / 0.05, 1) ** 0.5 * np.exp(-u / 0.5))
    m.air(0.0, 0.3, 900, 3500, amp=0.025, rise=0.15, pan=pan)
    m.room(t60=0.35, wet=0.1)
    return m.finish(loudness_db=-35.0, fade_out=0.1)


def burst_mud(v=0):
    """The Mud ball's first hit (ManeRuntime.shattersOnHit): it bursts wet
    and throws ten clods every way at once (36 degrees apart, 840 u/s, 1 s
    life). A thick splat, the squelch under it, ten short wet flights
    radiating out across the field."""
    length = 0.75
    m = Mix(length, seed=7900 + v)
    rng = m.rng
    # The splat: a thick wet throat closing (its formant falls), leaning in.
    swish(m, 0.0, 0.22, lambda u: 1300 * (380 / 1300) ** np.clip(u, 0, 1),
          0.5, _lean(0.09, 0.3), 0.22)
    burst(m, 0.0, 180, 1100, attack=0.02, tau=0.04, amp=0.12)
    # The squelch: a few soft, dull wet knocks inside it.
    chips(m, [(0.012 + rng.uniform(0, 0.05), rng.uniform(0.2, 0.4),
               rng.uniform(-0.3, 0.3)) for _ in range(5)],
          260, 650, eta=0.25, n=3, tc=0.0025, cap=0.03, lowpass=1600)
    # Ten clods flung radially: pans round the circle, near-simultaneous.
    phase = rng.uniform(0, 2 * math.pi)
    for i in range(10):
        p = 0.9 * math.cos(phase + i * 2 * math.pi / 10)
        at = 0.012 + abs(rng.normal(0, 0.01))
        swish(m, at, rng.uniform(0.2, 0.3),
              lambda u: 700 + 1300 * np.sin(math.pi * np.clip(u, 0, 1) ** 0.5),
              0.4, _lean(0.1, 0.3), 0.055 * rng.uniform(0.7, 1.0),
              pan=lambda u, p=p: p * (0.5 + 0.5 * np.clip(u, 0, 1)))
    m.room(t60=0.45, wet=0.12, darkness=3000)
    return _finish_punch(m, -29.5, fade_out=0.15)


def shatter_crystal(v=0):
    """The Crystal prism meets a boss and blows (survival / open space): a
    crack runs through it (~45 ms, the lean-in), the prism gives with a
    dense mineral crunch under a blast of pressure (the 240-unit burst), and
    its facets fly and settle. The crunch is many dense modes, so it is a
    break and never a struck bell; the pieces are short."""
    length = 1.7
    m = Mix(length, seed=8000 + v)
    rng = m.rng
    run = 0.045
    u = np.linspace(0, 1, 16)
    chips(m, list(zip(run * (1 - (1 - u) ** 1.8), 0.05 + 0.25 * u ** 1.5,
                      -0.5 + u)),
          2200, 5200, eta=0.015, n=3, tc=0.0003, cap=0.025)
    strike(m, run, _solid(rng, 520, n=22, spread=(0.08, 0.3), eta=0.03,
                          cap=0.1, tilt=0.06), tc=0.0012, amp=0.3)
    # The prism coming apart is a crunch: fracture all through the break.
    chips(m, [(run + rng.exponential(0.02), rng.uniform(0.1, 0.3),
               rng.uniform(-0.5, 0.5)) for _ in range(14)],
          1500, 4500, eta=0.03, n=3, tc=0.0003, cap=0.02)
    burst(m, run - 0.02, 140, 1100, attack=0.03, tau=0.16, amp=0.16)
    m.air(run - 0.01, 1.1, 200, 2400, amp=0.06, rise=0.06)
    # The facets: thrown wide, most at once, a few straggling and landing.
    times = np.sort(run + 0.004 + np.minimum(rng.exponential(0.09, 26), 0.6))
    shards = [(t0, rng.uniform(0.12, 0.3) * (1 - 0.6 * (t0 - run) / 0.6),
               (1 if k % 2 else -1) * rng.uniform(0.2, 0.95))
              for k, t0 in enumerate(times)]
    chips(m, shards, 1400, 4800, eta=0.012, n=3, tc=0.0003, cap=0.05)
    settle = [(0.5 + 0.9 * (k / 6) ** 1.4 + rng.uniform(0, 0.05),
               0.06 * (1 - 0.6 * k / 6), rng.uniform(-0.8, 0.8))
              for k in range(7)]
    chips(m, settle, 1600, 4200, eta=0.02, n=3, tc=0.0003, cap=0.03)
    m.room(t60=1.2, wet=0.26, darkness=3600)
    return _finish_punch(m, -28.5, fade_out=0.3)


def quake_earth(v=0):
    """The Earth slab sheds a quake burst (every 0.72 s, a 1.05 s zone with
    a hit spark): a chunk cracks off and lands -- a short stone crack, a
    dull damped body, grit. Quiet: it repeats for the slab's whole life."""
    length = 0.5
    m = Mix(length, seed=8100 + v)
    rng = m.rng
    pan = (-0.2, 0.15, 0.3, -0.05)[v]
    u = np.linspace(0, 1, 7)
    chips(m, list(zip(0.022 * (1 - (1 - u) ** 1.8), 0.04 + 0.13 * u, pan + 0 * u)),
          1100, 3000, eta=0.08, n=3, tc=0.0004, cap=0.02)
    # Only a little body under it: this repeats every 0.72 s for the slab's
    # whole life, and a low knock on that period would be a beat.
    strike(m, 0.022, _solid(rng, rng.uniform(300, 380), n=14,
                            spread=(0.1, 0.35), eta=0.09, cap=0.04, tilt=0.08),
           tc=0.0025, amp=0.22, pan=pan, lowpass=2600)
    # The pieces it throws, and grit running off them.
    pieces = [(0.025 + rng.exponential(0.05), rng.uniform(0.08, 0.2),
               pan + rng.uniform(-0.5, 0.5)) for _ in range(6)]
    chips(m, pieces, 600, 1800, eta=0.07, n=4, tc=0.0006, cap=0.03)
    grit = [(0.03 + rng.exponential(0.08), rng.uniform(0.03, 0.09),
             pan + rng.uniform(-0.4, 0.4)) for _ in range(14)]
    chips(m, grit, 1200, 3600, eta=0.08, n=3, tc=0.0004, cap=0.015)
    m.air(0.02, 0.4, 400, 1800, amp=0.04, rise=0.12, pan=pan)
    m.room(t60=0.4, wet=0.12, darkness=2800)
    return m.finish(loudness_db=-35.5, fade_out=0.12)


# ===========================================================================
# Export
# ===========================================================================

# Which special cue an element's cast plays: None is the family-level
# sfx_special_mane (the catapult), anything else sfx_special_mane_<pattern>.
SPECIAL_PATTERNS = {
    'Fire': 'volley',
    'Lightning': 'scatter',
    'Air': 'gale',
    'Spirit': 'stream',
    'Light': 'ward',
    'Water': None,
    'Earth': None,
    'Steam': None,
    'Lava': None,
    'Mud': None,
    'Ice': None,
    'Dust': None,
    'Crystal': None,
    'Plant': None,
    'Poison': None,
    'Dark': None,
    'Blood': None,
}


def _v(build, description):
    return {'build': build, 'description': description, 'variants': 3}


CUES = {
    'sfx_basic_mane': _v(
        basic, 'Mane auto-attack: one throw lets two blades go together, one each side, flying off as a widening pair'),
    'sfx_special_mane': _v(
        special, 'Mane catapult: a heavy body heaved off, its churning rush crawling away and darkening over ~2 s'),
    'sfx_special_mane_gale': _v(
        special_gale, 'Mane Air: a heavy gust thrown hard, buffeted, tearing away to one side in under a second'),
    'sfx_special_mane_volley': _v(
        special_volley, 'Mane Fire: one throw comes apart into a spray of small fast tears of air across the field'),
    'sfx_special_mane_scatter': _v(
        special_scatter, 'Mane Lightning: a handful of small orbs flung out every way at once, light flicks all round'),
    'sfx_special_mane_stream': _v(
        special_stream, 'Mane Spirit: the throw, a ripple of edges in close file, a lighter body crawling away'),
    'sfx_special_mane_ward': _v(
        special_ward, 'Mane Light: a weight swung out and taken into orbit, one slow arc of air settling into a held turning'),
    'sfx_special_mane_orb_land': _v(
        orb_land, 'Mane Lightning orb seats and its shock field takes: a soft settle and a spreading crackle'),
    'sfx_special_mane_burst': _v(
        burst_mud, 'Mane Mud ball bursts on its first hit: a thick wet splat and ten clods flung every way'),
    'sfx_special_mane_shatter': (
        shatter_crystal, 'Mane Crystal prism blows on a boss: a crack runs, a dense mineral crunch under a blast, facets fly'),
    'sfx_special_mane_quake': _v(
        quake_earth, 'Mane Earth slab sheds a chunk: a short stone crack, a dull damped body, grit'),
}
