"""The seventeen element accents: what an element sounds like when it goes off.

Where they play (SoundCue.forElement / SoundCue.elementX):
  * a creature's special, on the frame it is cast, in Cosmic Survival
    (cosmic_survival_game.dart, the special branch) and the dungeons
    (planet_dungeon_game.dart, tryCast) -- layered OVER the plain
    combatSpecialCast, which sits under it at .55 gain and carries nothing
    elemental; this cue is the color
  * a Mystic waking at the Mystic Altar and an offering landing in the boss
    altar's Mystic (giving crosses 0.72)
  * inside the planet dungeons' puzzles, as "this element just did its
    thing": Fire lights a pitch, Ice freezes a flue into steps, Plant grows a
    tendril, Blood primes a mouth, Steam seals a corner, Dust throws sand...

So each is a short accent (0.55 - 0.9 s) that speaks on the cast frame: the
body arrives inside the first ~60 ms, leaning in over 15 - 40 ms rather than
spiking, and the rest is the element's own after-life.

Each element is its own MATERIAL -- not one house texture with a different
filter. They are drawn from how the element comes apart in
lib/widgets/fx/elemental_essence.dart (the 17 signature forms): Fire burns
up from its feet, Earth crumbles to a heap and bounces once, Lightning
crackles with every grain jumping, Dark spirals into a point and keeps
turning, Light opens from the heart out, Blood from the heart out...

Specials repeat every few seconds for whole waves, so every element has
three re-rendered variants (SoundCue.hasVariants).

LEVELLING. These sit side by side -- three companions of different elements
cast within a second of each other -- so they are matched on the loudest
300 ms a phone speaker plays, not on whole-file RMS (which would let a short
crack come out hotter than a long swell). See _level.
"""
import math

import numpy as np
from scipy import signal

from sounds.core import SR, Mix, smooth

# Every element's loudest 300 ms, phone band. The whole-file figure lands
# around -30 (the brief's "medium"), the cast cue sits under it at .55.
PUNCH_DB = -27.0


# ===========================================================================
# Voices
# ===========================================================================

def _sos(kind, f, order=2):
    return signal.butter(order, f, btype=kind, fs=SR, output='sos')


def _filt(x, kind, f, order=2):
    return signal.sosfilt(_sos(kind, f, order), x, axis=-1)


def _tt(n):
    return np.arange(n) / SR


def _put(m, start, x, pan=0.0):
    """Lays mono (panned) or stereo [x] into [m] at [start] seconds."""
    s0 = max(0, round(start * SR))
    if s0 >= m.n:
        return
    if x.ndim == 1:
        g = (math.cos((pan + 1) * math.pi / 4), math.sin((pan + 1) * math.pi / 4))
        x = np.stack([g[0] * x, g[1] * x])
    k = min(x.shape[1], m.n - s0)
    m.y[:, s0:s0 + k] += x[:, :k]


def _pan_stereo(x, pan):
    """Mono [x] spread across the field by a per-sample pan curve."""
    p = np.clip(pan, -1, 1)
    return np.stack([np.cos((p + 1) * math.pi / 4) * x,
                     np.sin((p + 1) * math.pi / 4) * x])


def _svf(x, fc, q, mode='bp'):
    """A state-variable filter whose cutoff (and Q) may move every sample:
    the squelch of mud, the closing throat of Dark, a gust's moving centre.
    Zavalishin's TPT form, so a fast sweep stays stable."""
    n = len(x)
    fc = np.broadcast_to(np.clip(fc, 20, 0.45 * SR), (n,))
    q = np.broadcast_to(q, (n,))
    g = np.tan(math.pi * fc / SR)
    k = 1.0 / q
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    xs, a1s, a2s, a3s, ks = x.tolist(), a1.tolist(), a2.tolist(), a3.tolist(), k.tolist()
    out = [0.0] * n
    ic1 = ic2 = 0.0
    want = {'bp': 0, 'lp': 1, 'hp': 2}[mode]
    for i in range(n):
        v3 = xs[i] - ic2
        v1 = a1s[i] * ic1 + a2s[i] * v3
        v2 = ic2 + a2s[i] * ic1 + a3s[i] * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        out[i] = v1 if want == 0 else v2 if want == 1 else xs[i] - ks[i] * v1 - v2
    return np.array(out)


def _modes(x, freqs, t60s, gains):
    """A resonant body: [x] rung through damped inharmonic modes, each a
    two-pole two-zero resonator normalised to unity at its peak (the zeros
    at DC and Nyquist keep a slow pulse train from leaking through as a
    thump), so [gains] are what you hear. Stone, wood, ice and quartz differ
    only in these numbers."""
    out = np.zeros_like(x)
    for f, t60, g in zip(freqs, t60s, gains):
        if f >= 0.45 * SR:
            continue
        w = 2 * math.pi * f / SR
        r = math.exp(-6.9 / (t60 * SR))
        b0 = 1 - r
        out += g * signal.lfilter([b0, 0, -b0], [1, -2 * r * math.cos(w), r * r], x)
    return out


def _bubble(f0, tau, rise):
    """One bubble: the Minnaert ring of a pocket of gas, rising a little in
    pitch as it nears the surface and dying in a handful of cycles. [rise]
    is the whole rise over its life and stays small (<= ~0.35): a long
    sweep up is a cartoon 'bloop'. Many at random sizes are liquid; one
    alone is not a note (nothing here is tuned)."""
    n = int(tau * 5 * SR)
    t = _tt(n)
    f = f0 * (1 + rise * t / (tau * 5))
    ph = 2 * math.pi * np.cumsum(f) / SR
    # In over a quarter cycle (at least 1 ms): a big, low bubble that starts
    # on a step is a click down to DC.
    env = np.exp(-t / tau) * smooth(t, 0, max(0.001, 0.25 / f0))
    return env * np.sin(ph)


def _plop(rng, f0, dur, rise=0.3, q=5.0, attack=0.004):
    """A big, thick bubble or a plop: wet noise through a throat that opens
    as the bubble rises and breaks. Where a low pure bubble would ring like
    a tom, this keeps the liquid's texture."""
    n = round(dur * SR)
    t = _tt(n)
    fc = f0 * (1 + rise * smooth(t, 0, dur))
    x = _svf(rng.normal(0, 1, n), fc, q, 'bp')
    env = smooth(t, 0, attack) * np.exp(-6.9 * np.maximum(t - attack, 0) / dur)
    return _filt(x * env, 'highpass', 150)


def _bubbles(m, start, length, rate, f_lo, f_hi, amp, tau_cycles=(6, 14),
             rise=(0.08, 0.3), pan=(-0.5, 0.5), shape=None):
    """A field of bubbles: Poisson in time, log-uniform in size. Bigger ones
    are louder and ring longer. [shape](x) shapes the rate over 0..1."""
    rng = m.rng
    tcur = 0.0
    while True:
        r = rate * (shape(tcur / length) if shape else 1.0)
        tcur += rng.exponential(1 / max(rate, 1e-6))
        if tcur >= length:
            break
        if rng.random() > r / rate:
            continue  # thinning: the rate falls away where [shape] says
        f0 = math.exp(rng.uniform(math.log(f_lo), math.log(f_hi)))
        tau = rng.uniform(*tau_cycles) / f0
        size = (f_lo / f0) ** 0.5 * min(rng.lognormal(0, 0.45), 2.2)
        b = _bubble(f0, tau, rng.uniform(*rise))
        _put(m, start + tcur, amp * size * b, rng.uniform(*pan))


def _pops(m, start, length, rate, f_lo, f_hi, amp, decay=(0.0006, 0.004),
          q=(1.2, 3.0), pan=(-0.6, 0.6), shape=None, big=0.0, sigma=0.6):
    """Crackle: tiny noise bursts rung through a random band. A fire's sap
    pockets, a sizzle's spitting, the fizz of something acrid. [big] is the
    share that are a heavier, lower snap."""
    rng = m.rng
    tcur = 0.0
    while True:
        tcur += rng.exponential(1 / max(rate, 1e-6))
        if tcur >= length:
            break
        if shape and rng.random() > shape(tcur / length):
            continue
        heavy = rng.random() < big
        d = rng.uniform(*decay) * (2.5 if heavy else 1)
        n = int(d * 7 * SR) + 16
        t = _tt(n)
        burst = rng.normal(0, 1, n) * np.exp(-t / d) * np.clip(t / 0.0003, 0, 1)
        fc = math.exp(rng.uniform(math.log(f_lo), math.log(f_hi)))
        if heavy:
            fc *= 0.45
        qq = rng.uniform(*q)
        lo, hi = fc / (1 + 0.5 / qq), min(fc * (1 + 0.5 / qq), 0.45 * SR)
        x = _filt(burst, 'bandpass', [lo, hi])
        size = min(rng.lognormal(0, sigma), 2.5) * (1.8 if heavy else 1)
        _put(m, start + tcur, amp * size * x, rng.uniform(*pan))


def _stickslip(m, start, length, rate_fn, jitter, amp, freqs, t60s, gains,
               pan=0.0, roughness=0.15, env=None, hp=80):
    """Friction: something held catching and letting go, many times a second
    -- a stem stretching, ice under strain, stone dragged on stone. The
    catches are a pulse train (rate_fn(x) per second over 0..1, each period
    jittered) rung through the body's modes."""
    rng = m.rng
    n = round(length * SR)
    exc = np.zeros(n)
    tcur = 0.0
    while tcur < length:
        x = tcur / length
        i = round(tcur * SR)
        if i < n:
            exc[i] += min(rng.lognormal(0, 0.35), 2.0) * (env(x) if env else 1.0)
        tcur += (1 / rate_fn(x)) * (1 + jitter * rng.normal())
        tcur = max(tcur, (i + 2) / SR)
    exc += roughness * rng.normal(0, 1, n) * (np.interp(_tt(n) / length, *_env_pts(env))
                                             if env else 1.0)
    # [hp]: the catch rate itself is a low buzz no body would pass.
    _put(m, start, amp * _filt(_modes(exc, freqs, t60s, gains), 'highpass', hp), pan)


def _env_pts(env):
    xs = np.linspace(0, 1, 64)
    return xs, np.array([env(x) for x in xs])


def _noise_env(m, start, length, kind, band, amp, attack, t60=None,
               release=None, pan=0.0, stereo=False, order=2):
    """A band of noise shaped by a lean-in attack and an exponential decay
    (t60) or a cos release; [stereo] decorrelates the sides."""
    n = round(length * SR)
    t = _tt(n)
    a = np.clip(t / attack, 0, 1)
    e = np.sin(a * math.pi / 2) ** 2
    if t60:
        e = e * np.exp(-6.9 * np.maximum(t - attack, 0) / t60)
    if release:
        e = e * np.cos(np.clip((t - (length - release)) / release, 0, 1) * math.pi / 2) ** 2
    chans = 2 if stereo else 1
    xs = [_filt(m.rng.normal(0, 1, n), kind, band, order) * e * amp
          for _ in range(chans)]
    _put(m, start, np.stack(xs) * (0.75 if stereo else 1) if stereo else xs[0], pan)


def _level(m, fade_out=0.12, punch_db=PUNCH_DB):
    """Every element matched on its loudest 300 ms through a phone's band.

    A cue whose transients would then pass -3.5 dB peak (a crack's or an
    arc's crest) is set just low enough to fit -- at most ~2 dB under the
    rest, and transient material reads louder per RMS anyway."""
    y = m.finish(loudness_db=-45.0, fade_out=fade_out)
    phone = signal.sosfilt(_sos('bandpass', [300, 8000], 4), y, axis=1)
    p = np.mean(phone ** 2, axis=0)
    w = round(0.3 * SR)
    run = np.convolve(p, np.ones(w) / w, mode='valid') if len(p) > w else [p.mean()]
    loud = math.sqrt(max(np.max(run), 1e-20))
    gain = 10 ** (punch_db / 20) / loud
    gain = min(gain, 10 ** (-3.5 / 20) / np.max(np.abs(y)))
    assert 20 * math.log10(gain * loud) > punch_db - 2.5, 'too peaky to level with the rest'
    return y * gain


# Bodies, by their mode tables: frequency (Hz), t60 (s), gain.
STONE = ([142, 263, 409, 588, 811, 1093, 1490],
         [0.09, 0.07, 0.06, 0.045, 0.04, 0.03, 0.025],
         [0.5, 0.8, 1.0, 0.8, 0.6, 0.45, 0.3])
WOOD = ([212, 447, 731, 1062, 1508, 2210],
        [0.06, 0.05, 0.04, 0.035, 0.03, 0.02],
        [0.6, 1.0, 0.85, 0.6, 0.4, 0.25])
ICE = ([1130, 1870, 2690, 3810, 5240, 6930],
       [0.05, 0.045, 0.04, 0.03, 0.025, 0.02],
       [0.5, 0.8, 1.0, 0.8, 0.6, 0.4])


def _jit(m, base, spread):
    return base * (1 + spread * (m.rng.random() * 2 - 1))


# ===========================================================================
# The elements
# ===========================================================================

def fire(v=0):
    """Ignition and crackle. Essence: it burns up from its feet into a
    flame, tongues licking sideways, white-hot at the base.

    0     the catch: a breath of gas taking light -- a low noise whose top
          opens up over ~60 ms (a WHOOMF, never a pitched drop)
    0.03  the flame: turbulent roar, fluttering, rising a little brighter
    0.04  crackle all through it, thickest at the catch, sap snaps among it
    """
    m = Mix(0.78, seed=1100 + 31 * v)
    n = round(0.6 * SR)
    t = _tt(n)
    # The catch: a lowpass whose cutoff flares open and settles.
    fc = 260 + 3200 * smooth(t, 0.0, 0.06) * np.exp(-np.maximum(t - 0.06, 0) / 0.18)
    catch = _svf(m.rng.normal(0, 1, n), fc + 300, 0.8, 'lp')
    env = smooth(t, 0, 0.03) * np.exp(-6.9 * np.maximum(t - 0.03, 0) / 0.5)
    catch = _filt(catch, 'highpass', 130)
    _put(m, 0.0, 0.13 * catch * env, _jit(m, 0.0, 0.2))
    # The flame body: turbulent, the flicker a slow noise on its level.
    n2 = round(0.7 * SR)
    t2 = _tt(n2)
    flicker = 1 + 0.55 * _filt(m.rng.normal(0, 1, n2), 'lowpass', 14) * 9
    body_env = smooth(t2, 0.0, 0.05) * np.exp(-6.9 * t2 / 1.1) * np.clip(flicker, 0.2, 2)
    for side in (-0.35, 0.35):
        roar = _svf(m.rng.normal(0, 1, n2), 600 + 500 * smooth(t2, 0, 0.3), 1.1, 'bp')
        _put(m, 0.02, 0.05 * roar * body_env, side)
    # Crackle: dense at the catch, thinning as it burns.
    _pops(m, 0.03, 0.62, 170, 1300, 6500, 0.085, shape=lambda x: math.exp(-1.2 * x),
          big=0.12, pan=(-0.7, 0.7))
    m.room(t60=0.5, wet=0.12, darkness=3800)
    return _level(m, fade_out=0.12)


def water(v=0):
    """A splash and the flow after it. Essence: waves roll across it, every
    grain turning on its own orbit; the body sways on a slower swell.

    0     the slap of the surface: broadband but leaning in over 12 ms
    0.01  the bubble cloud the splash drives under, thinning fast
    0.12  droplets falling back, sparse and higher
    0.08  the water moving on: a slow slosh, swaying side to side
    """
    m = Mix(0.75, seed=1200 + 31 * v)
    _noise_env(m, 0.0, 0.25, 'bandpass', [350, 5200], 0.09, attack=0.012, t60=0.12,
               stereo=True)
    _bubbles(m, 0.008, 0.36, 480, 520, 2600, 0.07, shape=lambda x: math.exp(-3.5 * x),
             pan=(-0.7, 0.7))
    _bubbles(m, 0.12, 0.45, 40, 1300, 3800, 0.045, tau_cycles=(8, 14),
             shape=lambda x: 1 - x, pan=(-0.8, 0.8))
    n = round(0.62 * SR)
    t = _tt(n)
    swell = smooth(t, 0, 0.1) * np.cos(np.clip(t / 0.62, 0, 1) * math.pi / 2) ** 2
    slosh = _svf(m.rng.normal(0, 1, n), 550 + 280 * np.sin(2 * math.pi * 3.2 * t), 1.6, 'bp')
    pan = 0.5 * np.sin(2 * math.pi * 1.6 * t + m.rng.random() * 6)
    _put(m, 0.07, _pan_stereo(0.05 * slosh * swell, pan))
    m.room(t60=0.4, wet=0.1)
    return _level(m, fade_out=0.14)


def air(v=0):
    """A gust. Essence: a whirlwind round its own axis, wide at the top,
    rising -- so the gust circles the stereo field and climbs as it goes.

    0     the gust leans in (~60 ms, wind never spikes) and peaks at ~0.18
    then  its centre lifts and circles; a lower body under it; it thins out
    """
    m = Mix(0.72, seed=1300 + 31 * v)
    L = 0.68
    n = round(L * SR)
    t = _tt(n)
    x = t / L
    env = smooth(x, 0, 0.26) * np.cos(np.clip((x - 0.26) / 0.74, 0, 1) * math.pi / 2) ** 1.6
    gusty = 1 + 0.35 * np.clip(_filt(m.rng.normal(0, 1, n), 'lowpass', 9) * 12, -1, 1)
    centre = 650 * (1 + 1.3 * smooth(x, 0.05, 0.7)) * (1 + 0.15 * np.sin(2 * math.pi * 5.5 * t))
    whirl = 0.65 * np.sin(2 * math.pi * 2.3 * t + m.rng.random() * 6)
    hi = _svf(m.rng.normal(0, 1, n), centre * 1.8, 1.4, 'bp')
    mid = _svf(m.rng.normal(0, 1, n), centre, 0.9, 'bp')
    _put(m, 0.0, _pan_stereo(0.06 * hi * env * gusty, whirl))
    _put(m, 0.0, _pan_stereo(0.07 * mid * env * gusty, -0.6 * whirl))
    m.air(0.0, 0.55, 180, 700, amp=0.03, rise=0.3)
    m.room(t60=0.5, wet=0.1)
    return _level(m, fade_out=0.15)


def earth(v=0):
    """Stone shifting and grit. Essence: it crumbles from the crown down,
    falls to a heap at its feet, a small bounce, and stays.

    0     the slab lets go: stone grinding on stone for ~120 ms (friction)
    0.03  the crumble: coarse grit and gravel pouring down, heaviest early
    0.2   the mass settles into the heap -- a dull, damped stone body, no
          pitch in it (a pitched low drop is a drum)
    0.32  the small bounce, and grit trickling to rest
    """
    m = Mix(0.8, seed=1400 + 31 * v)
    _stickslip(m, 0.0, 0.16, lambda x: 45 + 25 * x, 0.25, 0.22, *STONE,
               pan=_jit(m, 0, 0.3), roughness=0.35,
               env=lambda x: smooth(x, 0, 0.2) * (1 - 0.6 * x))
    # The crumble: coarse grains, which is what the picture literally is.
    m.grains(lambda t: 2600 * smooth(t, 0.02, 0.06) * np.exp(-np.maximum(t - 0.06, 0) / 0.16),
             lambda t: 0.08 + 0.15 * smooth(t, 0.1, 0.5),
             lambda t: 0.2 * np.sin(5 * t), amp=0.5,
             weight=lambda t: 0.9 - 0.4 * smooth(t, 0.1, 0.5))
    # The heap taking the weight, then the bounce: noise-excited stone.
    for at, a in ((0.2, 1.0), (0.33, 0.45)):
        n = round(0.05 * SR)
        tt = _tt(n)
        exc = m.rng.normal(0, 1, n) * smooth(tt, 0, 0.012) * np.exp(-tt / 0.012)
        body = _modes(np.concatenate([exc, np.zeros(round(0.2 * SR))]), *STONE)
        _put(m, _jit(m, at, 0.05), 0.5 * a * _filt(body, 'highpass', 110), _jit(m, 0, 0.3))
    m.grains(lambda t: np.where(t > 0.33, 500 * np.exp(-(t - 0.33) / 0.14), 0),
             lambda t: 0.3 + 0 * t, lambda t: 0 * t, amp=0.5,
             weight=lambda t: 0.5 + 0 * t)
    m.room(t60=0.6, wet=0.14, darkness=3000)
    return _level(m, fade_out=0.15)


def lightning(v=0):
    """A real electric discharge, not a laser. Essence: struck from above
    all at once, then every grain jumps somewhere new every few frames,
    hardest at the strike.

    0     leader crackle building over ~22 ms into the snap
    0.022 the snap: a dense knot of tiny discharges (texture, not one spike)
    0.03  the arc: irregular bursts of crackle, each jumping to a new place
          in the field, thinning; ozone hiss under; a far, quiet rumble
    """
    m = Mix(0.62, seed=1500 + 31 * v)
    rng = m.rng
    # Bursts: an arc is a train of discharges in clumps.
    tcur = 0.0
    while tcur < 0.38:
        strength = math.exp(-tcur / 0.12)
        if tcur < 0.022:
            strength *= 0.35 + 0.65 * tcur / 0.022
        blen = rng.uniform(0.003, 0.012) * (2.2 if tcur < 0.03 else 1)
        nb = round(blen * SR)
        # Dense and even: an arc is many small discharges, not a few big
        # clicks (those are a peak meter's problem and a crash's onset).
        clicks = (rng.random(nb) < rng.uniform(0.15, 0.35)) * np.minimum(
            rng.lognormal(0, 0.35, nb), 1.8)
        clicks *= rng.choice([-1, 1], nb)
        x = _filt(clicks, 'highpass', 900)
        x = x + 0.5 * _filt(clicks, 'bandpass', [2500, 7500])
        x = np.concatenate([x, np.zeros(round(0.004 * SR))])
        x = _filt(x, 'lowpass', 11000)
        x /= max(np.abs(x).max(), 1e-9)
        _put(m, tcur, 0.06 * strength * rng.uniform(0.6, 1.0) * x, rng.uniform(-0.8, 0.8))
        tcur += blen + rng.exponential(0.006 + 0.05 * (tcur / 0.38))
    _noise_env(m, 0.015, 0.5, 'bandpass', [3000, 10000], 0.016, attack=0.02, t60=0.3,
               stereo=True)
    _noise_env(m, 0.03, 0.55, 'bandpass', [130, 420], 0.012, attack=0.05, t60=0.45)
    m.room(t60=0.7, wet=0.16, darkness=5000)
    return _level(m, fade_out=0.12)


def steam(v=0):
    """Hiss and venting. Essence: it billows, swelling out and up, soft and
    drifting -- so the vent widens across the field as it goes.

    0     the valve: a short low chuff as pressure finds the gap
    0.01  the hiss: high, turbulent, pressure falling so its centre sinks
    0.08  spitting droplets in it, sparse
    """
    m = Mix(0.8, seed=1600 + 31 * v)
    _noise_env(m, 0.0, 0.22, 'bandpass', [250, 1400], 0.08, attack=0.022, t60=0.12)
    L = 0.72
    n = round(L * SR)
    t = _tt(n)
    x = t / L
    env = smooth(x, 0, 0.04) * (1 - 0.45 * smooth(x, 0.05, 0.5)) \
        * np.cos(np.clip((x - 0.45) / 0.55, 0, 1) * math.pi / 2) ** 2
    flutter = 1 + 0.25 * np.clip(_filt(m.rng.normal(0, 1, n), 'lowpass', 30) * 8, -1, 1)
    centre = 6200 - 2400 * smooth(x, 0.05, 0.8)
    width = 0.15 + 0.7 * smooth(x, 0, 0.6)
    for side in (-1, 1):
        hiss = _svf(m.rng.normal(0, 1, n), centre * (1 + 0.08 * side), 0.9, 'bp')
        _put(m, 0.008, 0.05 * hiss * env * flutter, side * width.mean())
    _pops(m, 0.07, 0.4, 35, 2500, 7000, 0.035, pan=(-0.8, 0.8),
          shape=lambda x: 1 - x)
    m.room(t60=0.55, wet=0.14)
    return _level(m, fade_out=0.15)


def lava(v=0):
    """Heavy, viscous bubbling and a sizzle. Essence: it melts, sags and
    spreads, drips run off its underside; a dark crust with heat breaking
    through.

    0     the mass slumps: a thick, low glorp leaning in over ~40 ms
    0.05  big slow bubbles push up through it and burst (low, long, few)
    0.02  the sizzle where heat meets air, fine and constant, fading
    0.5   a thick drip or two run off
    """
    m = Mix(0.88, seed=1700 + 31 * v)
    rng = m.rng
    n = round(0.7 * SR)
    t = _tt(n)
    glorp = _svf(rng.normal(0, 1, n), 320 + 160 * np.sin(2 * math.pi * 4.5 * t), 2.2, 'bp')
    env = smooth(t, 0, 0.04) * np.exp(-6.9 * t / 0.7)
    _put(m, 0.0, 0.09 * _filt(glorp, 'highpass', 160) * env, _jit(m, 0, 0.3))
    # Big bubbles: each a slow swell of the surface and a heavy burst.
    times = [0.05, 0.19, 0.34, 0.5]
    for i, at in enumerate(times):
        at = _jit(m, at, 0.12)
        f0 = rng.uniform(260, 420)
        b = _plop(rng, f0, rng.uniform(0.07, 0.11), rise=rng.uniform(0.2, 0.4), q=4.0,
                  attack=0.012)
        a = 0.26 * (1 - 0.15 * i)
        _put(m, at, 0.9 * a * b, rng.uniform(-0.5, 0.5))
        # the burst: a thick pop of the skin
        _noise_env(m, at + len(b) / SR * 0.55, 0.05, 'bandpass', [400, 2400],
                   0.1 * a / 0.26, attack=0.004, t60=0.035, pan=rng.uniform(-0.5, 0.5))
    _pops(m, 0.02, 0.8, 260, 2800, 9000, 0.02, decay=(0.0003, 0.0012),
          shape=lambda x: math.exp(-2.0 * x), pan=(-0.8, 0.8))
    _noise_env(m, 0.02, 0.7, 'bandpass', [3500, 9500], 0.008, attack=0.03, t60=0.6,
               stereo=True)
    for at in (0.55, 0.68):
        f0 = rng.uniform(420, 600)
        _put(m, _jit(m, at, 0.05), 0.14 * _plop(rng, f0, 0.05, q=6.0), rng.uniform(-0.4, 0.4))
    m.room(t60=0.6, wet=0.13, darkness=3200)
    return _level(m, fade_out=0.14)


def poison(v=0):
    """Wet, acrid bubbling. Essence: the body swells into blisters that rise
    and burst, and what is left drips.

    0     it starts to boil from the feet: a quick swell of mid bubbles
    0.03  blisters burst wetly among them, a few at a time
    0.04  the acrid fizz: a thin carbonated crackle and a sour hiss
    0.45  what is left drips
    """
    m = Mix(0.78, seed=1800 + 31 * v)
    rng = m.rng
    _bubbles(m, 0.0, 0.48, 520, 450, 1500, 0.06,
             shape=lambda x: smooth(np.array(x), 0, 0.08) * math.exp(-1.6 * x),
             tau_cycles=(6, 12), rise=(0.1, 0.35), pan=(-0.6, 0.6))
    for at in (0.035, 0.11, 0.2, 0.31):
        at = _jit(m, at, 0.2)
        f0 = rng.uniform(320, 520)
        _put(m, at, 0.2 * _plop(rng, f0, 0.045, q=6.0), rng.uniform(-0.5, 0.5))
        _noise_env(m, at + 0.02, 0.04, 'bandpass', [900, 4200], 0.035,
                   attack=0.002, t60=0.02, pan=rng.uniform(-0.6, 0.6))
    _pops(m, 0.04, 0.6, 320, 3500, 9500, 0.014, decay=(0.0002, 0.0008),
          shape=lambda x: math.exp(-1.8 * x), pan=(-0.9, 0.9))
    _noise_env(m, 0.03, 0.6, 'bandpass', [2400, 6500], 0.012, attack=0.04, t60=0.5,
               stereo=True)
    for at in (0.5, 0.63):
        f0 = rng.uniform(900, 1300)
        _put(m, _jit(m, at, 0.06), 0.05 * _bubble(f0, 8 / f0, 0.35), rng.uniform(-0.3, 0.3))
    m.room(t60=0.5, wet=0.12)
    return _level(m, fade_out=0.12)


def ice(v=0):
    """Ice cracking and creaking, and a cold glassy tick. Essence: it
    freezes from the feet up onto a frost lattice, each grain snapping onto
    it, then drifts off as a sparkling flurry.

    0     frost spreading: a fine crystalline crackle thickening (~20 ms in)
    0.04  the sheet cracks, twice, sharp but small, ringing as ice does
    0.14  it creaks under the strain, high and glassy (friction)
    0.36  one cold tick as it sets -- small and short, not a chime
    then  a few flurry glints
    """
    m = Mix(0.78, seed=1900 + 31 * v)
    rng = m.rng
    # Frost is many even, tiny crystallisations: an outlier would be a click.
    _pops(m, 0.0, 0.3, 700, 4000, 11000, 0.02, decay=(0.0002, 0.0007),
          shape=lambda x: smooth(np.array(x), 0, 0.08) * (1 - 0.7 * x), pan=(-0.8, 0.8),
          sigma=0.3)
    for at, a in ((0.04, 1.0), (0.12, 0.7)):
        at = _jit(m, at, 0.15)
        # A crack is a run of small fractures over ~15 ms, not one click.
        n = round(0.03 * SR)
        tt = _tt(n)
        exc = np.zeros(n)
        for k in range(rng.integers(3, 6)):
            t0 = rng.uniform(0, 0.015) * (k > 0)
            blip = rng.normal(0, 1, n) * np.exp(-np.maximum(tt - t0, 0) / 0.0015) * (tt >= t0)
            exc += blip * rng.uniform(0.4, 1.0) * (1 if k == 0 else 0.6)
        exc *= smooth(tt, 0, 0.002)
        freqs = [f * rng.uniform(0.9, 1.1) for f in ICE[0]]
        pad = np.zeros(round(0.12 * SR))
        ring = _modes(np.concatenate([exc, pad]), freqs, ICE[1], ICE[2])
        direct = np.concatenate([_filt(exc, 'highpass', 2500), pad])
        crack = ring / np.abs(ring).max() + 0.3 * direct / np.abs(direct).max()
        crack = _filt(crack, 'highpass', 500)
        _put(m, at, 0.014 * a * crack, rng.uniform(-0.5, 0.5))
    _stickslip(m, 0.15, 0.2, lambda x: 90 + 120 * x, 0.18, 0.1,
               [f * 0.62 for f in ICE[0]], [0.03] * 6, ICE[2],
               pan=_jit(m, 0, 0.4), roughness=0.1, hp=550,
               env=lambda x: math.sin(math.pi * x) ** 2)
    m.glass(_jit(m, 0.37, 0.04), rng.uniform(2300, 2700), amp=0.0065, ring=0.1,
            attack=0.002, brightness=0.6, pan=rng.uniform(-0.4, 0.4), beat=3.0,
            ratios=[1.0, 2.74, 5.1])
    m.grains(lambda t: np.where(t > 0.4, 110 * np.exp(-(t - 0.4) / 0.2), 0),
             lambda t: 0.97 + 0 * t, lambda t: 0.4 * np.sin(4 * t), amp=0.5,
             weight=lambda t: 0.15 + 0 * t)
    m.room(t60=0.45, wet=0.1, darkness=6000)
    return _level(m, fade_out=0.15)


def mud(v=0):
    """Sucking and squelch. Essence: it slumps into a puddle at its feet,
    rippling, the odd plop.

    0     the suck: a thick throat of noise drawn in, its formant sliding
          up as the mud gives (~150 ms)
    0.15  it lets go -- the squelch, formant falling
    0.3   the puddle: slow low plops, a ripple between
    """
    m = Mix(0.75, seed=2000 + 31 * v)
    rng = m.rng
    n = round(0.42 * SR)
    t = _tt(n)
    split = _jit(m, 0.15, 0.1)
    formant = np.where(t < split, 260 + 520 * smooth(t, 0.0, split),
                       780 - 520 * smooth(t, split, split + 0.2))
    env = smooth(t, 0, 0.035) * (1 + 0.6 * np.exp(-((t - split) / 0.025) ** 2)) \
        * np.cos(np.clip((t - 0.25) / 0.17, 0, 1) * math.pi / 2) ** 2
    sq = _svf(rng.normal(0, 1, n), formant, 3.2, 'bp')
    sq2 = _svf(rng.normal(0, 1, n), formant * 2.6, 2.5, 'bp')
    _put(m, 0.0, 0.12 * sq * env + 0.035 * sq2 * env, _jit(m, 0, 0.3))
    for at in (0.3, 0.46, 0.6):
        at = _jit(m, at, 0.1)
        f0 = rng.uniform(170, 300)
        _put(m, at, 0.3 * _plop(rng, f0, 0.06, rise=0.5, q=4.5, attack=0.006),
             rng.uniform(-0.5, 0.5))
        _noise_env(m, at + 0.015, 0.05, 'bandpass', [350, 1500], 0.03,
                   attack=0.004, t60=0.03, pan=rng.uniform(-0.5, 0.5))
    _bubbles(m, 0.2, 0.45, 30, 300, 700, 0.04, tau_cycles=(5, 9), rise=(0.15, 0.3))
    m.room(t60=0.45, wet=0.1, darkness=2800)
    return _level(m, fade_out=0.12)


def dust(v=0):
    """A dry sandy whoosh. Essence: blown away downwind, streaming, turning
    over -- grains really are the subject here.

    0     the wind takes it (leaning in ~40 ms) on the windward side
    then  the stream of sand pours downwind across the field and thins
    """
    m = Mix(0.78, seed=2100 + 31 * v)
    wind = -1 if v % 2 else 1  # the side it blows from, varied
    m.grains(lambda t: 5200 * smooth(t, 0.0, 0.05) * np.exp(-np.maximum(t - 0.08, 0) / 0.22),
             lambda t: 0.62 + 0.15 * smooth(t, 0.05, 0.5),
             lambda t: wind * (-0.6 + 1.4 * smooth(t, 0.0, 0.55)), amp=0.5,
             weight=lambda t: 0.6 + 0 * t)
    n = round(0.7 * SR)
    t = _tt(n)
    env = smooth(t, 0, 0.05) * np.exp(-6.9 * np.maximum(t - 0.05, 0) / 0.6)
    whoosh = _svf(m.rng.normal(0, 1, n), 900 + 1500 * smooth(t, 0, 0.12)
                  - 900 * smooth(t, 0.12, 0.6), 0.9, 'bp')
    _put(m, 0.0, _pan_stereo(0.07 * whoosh * env, wind * (-0.5 + 1.1 * smooth(t, 0, 0.5))))
    m.room(t60=0.45, wet=0.1)
    return _level(m, fade_out=0.15)


def crystal(v=0):
    """A clear, mineral resonance. Essence: it cracks into facets that stand
    off it, each turning a little and lit its own way, the cracks bright.

    0     the cracks: three or four crisp fractures inside ~60 ms, and each
          one rings the SAME quartz body (the body is the resonance; the
          fractures are what strike it, so it is never a run of notes)
    0.01  a soft stroke keeps the body sounding for a breath -- it leans in
          over ~30 ms rather than being struck like a bell
    then  the facets glitter, high and sparse

    The body is many inharmonic modes of near-equal weight, each a close
    pair that beats slowly (the facets turning): a mineral shimmer with no
    single pitch standing out, which is what keeps it off a chime.
    """
    m = Mix(0.85, seed=2200 + 31 * v)
    rng = m.rng
    L = 0.8
    n = round(L * SR)
    tt = _tt(n)
    exc = np.zeros(n)
    hits = sorted(rng.uniform(0.0, 0.09, 5))
    hits[0] = 0.0
    for k, at in enumerate(hits):
        s0 = round(at * SR)
        u = tt[:n - s0]
        # Crisp, but each leans in over 1.5 ms: a fracture, not a mallet.
        blip = rng.normal(0, 1, n - s0) * smooth(u, 0, 0.0015) * np.exp(-u / 0.0012)
        exc[s0:] += blip * (1.0 if k == 0 else rng.uniform(0.4, 0.8))
    # The stroke: a breath of friction under the cracks.
    exc += 0.05 * rng.normal(0, 1, n) * smooth(tt, 0.0, 0.03) * np.exp(-6.9 * tt / 0.35)
    f0 = _jit(m, 870, 0.07)
    ratios = [1.0, 1.43, 1.97, 2.61, 3.12, 3.89, 4.71, 5.66, 6.83]
    t60s = [0.55, 0.5, 0.45, 0.4, 0.34, 0.3, 0.24, 0.2, 0.16]
    gains = [0.55, 0.8, 0.75, 0.9, 0.7, 0.75, 0.55, 0.5, 0.35]
    for side in (-1, 1):
        # Each side hears the facets a hair apart: the pair beats.
        freqs = [f0 * r * (1 + side * rng.uniform(0.0006, 0.0018)) for r in ratios]
        body = _modes(exc, freqs, t60s, gains)
        body = _filt(body, 'highpass', 500)
        _put(m, 0.0, 0.06 * body / max(np.abs(body).max(), 1e-9), side * 0.45)
    # The bright edge of the fractures themselves.
    _put(m, 0.0, 0.03 * _filt(exc, 'highpass', 4000) / max(np.abs(exc).max(), 1e-9))
    m.grains(lambda t: np.where(t > 0.06, 140 * np.exp(-(t - 0.06) / 0.25), 0),
             lambda t: 0.96 + 0 * t, lambda t: 0.5 * np.sin(3 * t), amp=0.5,
             weight=lambda t: 0.35 + 0 * t)
    m.room(t60=0.8, wet=0.16, darkness=6000)
    return _level(m, fade_out=0.2)


def plant(v=0):
    """Leaves rustling and a woody creak of growth. Essence: the grains
    climb into curling stems and leaves, base first, which sway as they
    stand.

    0     the leaves shake out: a flurry of leaf contacts (dry, papery)
    0.06  the stems stretch: a woody creak, its catches quickening as it
          grows (friction through wood modes)
    then  the leaves keep rustling, swaying side to side, settling
    """
    m = Mix(0.85, seed=2300 + 31 * v)
    rng = m.rng
    # Leaf contacts come in flurries; a sway carries them across the field.
    sway_ph = rng.random() * 6
    # Leaves touch in flurries, each time a stem moves; the first is the
    # shake-out at the cast.
    flurries = np.concatenate([[0.02], np.sort(rng.uniform(0.08, 0.55, 5))])
    tcur = 0.0
    while tcur < 0.62:
        x = tcur / 0.62
        bunch = 0.2 + np.sum(np.exp(-((tcur - flurries) / 0.035) ** 2))
        rate = 520 * (1 - 0.6 * x) * min(bunch, 1.4)
        tcur += rng.exponential(1 / rate)
        dur = rng.uniform(0.004, 0.022)
        nb = round(dur * SR) + 64
        tt = _tt(nb)
        leaf = rng.normal(0, 1, nb) * smooth(tt, 0, 0.002) * np.exp(-tt / (dur * 0.5))
        fc = rng.uniform(1800, 5500)
        x2 = _filt(leaf, 'bandpass', [fc * 0.6, min(fc * 1.6, 15000)])
        pan = 0.6 * math.sin(2 * math.pi * 1.4 * tcur + sway_ph) + rng.normal(0, 0.15)
        size = (smooth(np.array(tcur), 0, 0.025) * (1 - 0.6 * min(x, 1))
                * min(rng.lognormal(0, 0.4), 1.8))
        _put(m, tcur, 0.016 * size * x2, float(np.clip(pan, -1, 1)))
    _stickslip(m, _jit(m, 0.06, 0.2), 0.42, lambda x: 22 + 55 * x ** 1.5, 0.22, 0.32,
               *WOOD, pan=_jit(m, 0, 0.3), roughness=0.08, hp=150,
               env=lambda x: smooth(np.array(x), 0, 0.15) * (1 - smooth(np.array(x), 0.75, 1)))
    m.room(t60=0.5, wet=0.12, darkness=4200)
    return _level(m, fade_out=0.15)


def spirit(v=0):
    """A breath, and a faint stroked resonance under it. Essence: it rises
    as a ghost, a waving column narrowing to a tail.

    0     the breath leans in (~90 ms): whispered air through a throat whose
          shape drifts up as the column rises
    0.04  a glass stroked very softly under it -- the column's body
    then  narrowing: the breath thins to a high tail, waving side to side
    """
    m = Mix(0.92, seed=2400 + 31 * v)
    rng = m.rng
    L = 0.85
    n = round(L * SR)
    t = _tt(n)
    x = t / L
    env = smooth(x, 0, 0.12) * np.cos(np.clip((x - 0.25) / 0.75, 0, 1) * math.pi / 2) ** 1.5
    rise = smooth(x, 0.05, 0.9)
    wave = 0.55 * np.sin(2 * math.pi * 1.7 * t + rng.random() * 6)
    breath = np.zeros(n)
    # Whisper formants (unvoiced: no pitch, only a throat's shape).
    for f, q, g in ((620, 3.0, 1.0), (1150, 3.5, 0.8), (2500, 4.0, 0.5)):
        breath += g * _svf(rng.normal(0, 1, n), f * (1 + 0.6 * rise), q * (1 + rise), 'bp')
    _put(m, 0.0, _pan_stereo(0.06 * breath * env, wave))
    m.air(0.0, 0.7, 2500, 7000, amp=0.012, rise=0.3)
    m.glass(0.04, _jit(m, 415, 0.05), amp=0.045, ring=0.9, attack=0.18,
            brightness=0.25, beat=1.1, ratios=[1.0, 2.32, 4.25])
    m.room(t60=1.0, wet=0.22, darkness=5000)
    return _level(m, fade_out=0.2)


def dark(v=0):
    """Low and swallowing: an inhale, sound taken away rather than made.
    Essence: it is swallowed from the edges in, spirals into a point at its
    heart, the inside turning faster, and keeps turning there.

    0     it is heard from the cast frame (~25 ms in): everything around is
          drawn in -- a reversed room swelling toward the point, its top
          closing off (5 kHz -> 300 Hz) -- subtractive, not added
    0.05  the spiral: a slow swirl in it, turning faster as it closes
    0.38  swallowed: it stops short (a 20 ms close, not a hit); a dim, low
          turning is left where it went
    """
    m = Mix(0.66, seed=2500 + 31 * v)
    rng = m.rng
    stop = _jit(m, 0.38, 0.06)
    n = round(stop * SR)
    t = _tt(n)
    x = t / stop
    # A reversed room: a decay played backwards swells into the stop; a
    # floor under it so the cast frame is not silent.
    swell = (0.18 + np.exp(-6.9 * (1 - x) * stop / 0.3)) * smooth(t, 0, 0.025)
    cutoff = 5000 * (300 / 5000) ** smooth(x, 0.0, 1.0)
    swirl_rate = 3 + 15 * x ** 1.5
    swirl = 1 + 0.35 * np.sin(2 * math.pi * np.cumsum(swirl_rate) / SR)
    close = np.clip((stop - t) / 0.02, 0, 1)
    for side in (-1, 1):
        inhale = _svf(rng.normal(0, 1, n), cutoff, 0.9, 'lp')
        inhale = _filt(inhale, 'highpass', 110)
        pan = side * 0.7 * (1 - x)  # from the edges, into the point
        _put(m, 0.0, _pan_stereo(0.11 * inhale * swell * swirl * close, pan))
    # The low pressure under it, no pitch, closing with it.
    low = _filt(rng.normal(0, 1, n), 'bandpass', [90, 260])
    _put(m, 0.0, 0.045 * low * swell * close)
    # What is left: a dim turning at the point.
    n2 = round(0.24 * SR)
    t2 = _tt(n2)
    after = _svf(rng.normal(0, 1, n2), 380 + 80 * np.sin(2 * math.pi * 9 * t2), 2.5, 'bp')
    after = _filt(after, 'lowpass', 1200)
    _put(m, stop, 0.03 * after * smooth(t2, 0, 0.03) * np.exp(-6.9 * t2 / 0.24))
    m.room(t60=0.35, wet=0.06, darkness=1800)
    return _level(m, fade_out=0.05)


def light(v=0):
    """A soft, bright swell -- warm air and shimmer, never a ding. Essence:
    it opens from the heart out, and gathers back crown first.

    0     the bloom leans in over ~90 ms from the centre and opens wide:
          warm air whose top lifts as it opens
    0.04  the shimmer: a cloud of faint, high, slowly beating partials --
          dozens at unrelated pitches, none louder than the air, so it is a
          glow and never a note
    then  a few motes catch the light and it settles
    """
    m = Mix(0.88, seed=2600 + 31 * v)
    rng = m.rng
    L = 0.82
    n = round(L * SR)
    t = _tt(n)
    x = t / L
    env = smooth(x, 0, 0.13) * np.cos(np.clip((x - 0.18) / 0.82, 0, 1) * math.pi / 2) ** 1.8
    width = 0.15 + 0.85 * smooth(x, 0, 0.35)
    # Warm air, mid-to-bright, mid/side so it opens from the centre.
    a = _svf(rng.normal(0, 1, n), 1500 + 1300 * smooth(x, 0, 0.3), 1.1, 'bp')
    b = _svf(rng.normal(0, 1, n), 1500 + 1300 * smooth(x, 0, 0.3), 1.1, 'bp')
    a, b = _filt(a, 'lowpass', 6500), _filt(b, 'lowpass', 6500)
    mid, side = 0.5 * (a + b), 0.5 * (a - b)
    _put(m, 0.0, 0.05 * np.stack([mid + width * side, mid - width * side]) * env)
    warm = _svf(rng.normal(0, 1, n), 700, 0.8, 'bp')
    _put(m, 0.0, 0.035 * warm * smooth(x, 0, 0.15) * np.exp(-6.9 * t / 0.7))
    # The shimmer cloud.
    cloud = np.zeros((2, n))
    for _ in range(40):
        f = math.exp(rng.uniform(math.log(2200), math.log(8500)))
        trem = 0.5 + 0.5 * np.sin(2 * math.pi * rng.uniform(2, 7) * t + rng.random() * 6)
        part = np.sin(2 * math.pi * f * t + rng.random() * 6) * trem * rng.uniform(0.3, 1)
        p = rng.uniform(-1, 1) * width
        cloud += np.stack([np.cos((p + 1) * math.pi / 4) * part,
                           np.sin((p + 1) * math.pi / 4) * part])
    sw = smooth(x, 0.03, 0.2) * np.cos(np.clip((x - 0.25) / 0.75, 0, 1) * math.pi / 2) ** 2
    _put(m, 0.0, 0.011 * cloud * sw)
    m.grains(lambda t: 90 * smooth(t, 0.06, 0.2) * np.exp(-np.maximum(t - 0.2, 0) / 0.25),
             lambda t: 0.9 + 0 * t, lambda t: 0.6 * np.sin(7 * t), amp=0.5,
             weight=lambda t: 0.3 + 0 * t)
    m.room(t60=0.9, wet=0.2, darkness=7000)
    return _level(m, fade_out=0.2)


def blood(v=0):
    """Thick and pulsing: a heartbeat's pressure, heard as flow, not a drum.
    Essence: from the heart out.

    0     LUB: a surge of thick liquid through a vessel -- a dark whoosh
          whose band opens and closes with the push (~40 ms in)
    0.27  DUB: the second, smaller surge (a heart's lub-dub spacing)
    then  a viscous gurgle in the vessel between and after
    """
    m = Mix(0.82, seed=2700 + 31 * v)
    rng = m.rng
    dub = _jit(m, 0.27, 0.05)
    for at, a, ln in ((0.0, 1.0, 0.2), (dub, 0.7, 0.18)):
        n = round(ln * SR)
        t = _tt(n)
        push = smooth(t, 0, 0.04) * np.exp(-6.9 * np.maximum(t - 0.04, 0) / (ln * 0.6))
        centre = 260 + 520 * push
        for side in (-1, 1):
            surge = _svf(rng.normal(0, 1, n), centre * (1 + 0.05 * side), 1.6, 'bp')
            _put(m, at, 0.12 * a * surge * push, side * 0.3)
        # Something thick moving in it.
        _bubbles(m, at + 0.02, ln * 0.7, 18, 220, 520, 0.035 * a,
                 tau_cycles=(5, 9), rise=(0.05, 0.2), pan=(-0.3, 0.3))
    _bubbles(m, 0.4, 0.3, 10, 240, 480, 0.015, tau_cycles=(5, 9))
    m.room(t60=0.5, wet=0.12, darkness=2600)
    return _level(m, fade_out=0.14)


_ELEMENTS = {
    'fire': (fire, 'Ignition and crackle: a breath of gas catching into a fluttering flame'),
    'water': (water, 'A splash, the bubble cloud it drives under, droplets and a swaying slosh'),
    'air': (air, 'A gust that leans in, circles the field like a whirlwind and lifts away'),
    'earth': (earth, 'Stone grinding loose, grit pouring down, the heap taking its weight and one small bounce'),
    'lightning': (lightning, 'An electric discharge: leader crackle into a snap, then arcing bursts that jump about the field'),
    'steam': (steam, 'A valve chuffs and vents a falling hiss that widens as it billows, droplets spitting'),
    'lava': (lava, 'A heavy viscous glorp, big slow bubbles bursting through it, a fine sizzle and a thick drip'),
    'poison': (poison, 'Wet acrid bubbling: blisters swelling and bursting, a sour fizz, a drip'),
    'ice': (ice, 'Frost crackling in, the sheet cracking and creaking under strain, one cold glassy tick'),
    'mud': (mud, 'A thick suck and squelch, then slow plops into the puddle'),
    'dust': (dust, 'A dry sandy whoosh: the wind takes it and sand streams downwind'),
    'crystal': (crystal, 'Crisp fractures and one clear quartz body answering, its facets glittering'),
    'plant': (plant, 'Leaves shaking out and rustling as they sway, a woody creak of stems growing'),
    'spirit': (spirit, 'A whispered breath rising and thinning, a glass stroked faintly under it'),
    'dark': (dark, 'An inhale: the room drawn in, its top closing, swirling faster until it is swallowed'),
    'light': (light, 'A soft bright swell opening from the centre: warm air, flickering shimmer, a few motes'),
    'blood': (blood, 'A heartbeat heard as flow: two thick surges through a vessel and a viscous gurgle'),
}

CUES = {
    f'sfx_element_{name}': {'build': build, 'description': desc, 'variants': 3}
    for name, (build, desc) in _ELEMENTS.items()
}
