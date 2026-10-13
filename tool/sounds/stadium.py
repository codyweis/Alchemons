"""The stadium race (lib/screens/stadium/race_screen.dart, lib/games/stadium/):
six racers on a side-scrolling track -- sprints, walls climbed, fusion
stations, a show ring under spotlights -- in a stadium whose stands are a
crowd drawn as lit grains.

So the materials are the crowd (its talk as breath with no voice in it, its
applause as a grain shower of claps), the racers' own grains (gathering,
pouring off, coming apart and back), the brass grains of the count and the
line, the stone of the walls, a glass under the moments that land, and a big
open room. Weight, not melody: nothing here is a fanfare, a whistle, a drum
or a note, and nothing in it is pitched to a scale.

The voices this module adds (core.py has grains / glass / air / room;
cosmic.py lends knock, rush and its bodies, dungeon.py its falling chips,
interface.py its breath):

  claps    applause as a shower of grains of air: each clap a few ms of air
           squeezed between two palms through the cupped hollow, no two
           hands alike; far ones lose their top
  murmur   a crowd talking among itself with no voice in it: many breaths
           through mouth shapes, each on its own syllable pace and its own
           turns; lifted, every mouth opens brighter and all talk at once
  slowed   time slowing: a sub-mix read slower and slower (everything in it
           drops and stretches together) while a closing filter muffles it

Rhythm is the one thing a crowd must never have here: every clap is a
Poisson event, so even a patch of a few people clapping has no beat.

Timing, race_rules.dart: the race steps at kRaceTickRate = 60; a boost winds
up for kRaceBoostWindupTicks (36 = 0.6 s) and surges for
kRaceBoostSurgeTicks (72 = 1.2 s). race_stage.dart: the count is
countdownSeconds = 3.0, one numeral a second.
"""
import math

import numpy as np
from scipy import signal

from sounds.core import SR, Mix, seamless_loop, smooth
from sounds.cosmic import (_dark_glass, _pan_gains, _plate, _put, _span,
                           _stone, knock, rush)
from sounds.dungeon import _chips
from sounds.dungeon import _drift as _wander
from sounds.dungeon import _knock as _stone_knock
from sounds.interface import _breath

# ===========================================================================
# Voices
# ===========================================================================


def _sos(kind, f, order=2):
    return signal.butter(order, f, btype=kind, fs=SR, output='sos')


def _flat(v):
    return lambda t: v + 0 * t


def _at(f, t):
    return f(t) if callable(f) else f + 0 * t


def _far(y, far):
    """A far sound loses its top: 0 is beside you, 1 the far stand."""
    if far <= 0:
        return y
    return signal.sosfilt(_sos('lowpass', 9000 * 0.2 ** far), y, axis=-1)


def _clap_bank(rng, count=12, tone=1.0):
    """A crowd's many hands. Each clap is a few ms of air squeezed out
    between two palms: a contact, a puff through the cupped hollow (a broad
    resonance -- low for a cupped clap, high for a flat one) and the skin's
    slap on top. Some palms meet a hair apart and catch twice. [tone] < 1
    is a warmer, more cupped crowd."""
    n = round(0.04 * SR)
    t = np.arange(n) / SR
    bank = []
    for _ in range(count):
        decay = rng.uniform(0.0025, 0.0065)
        env = (1 - np.exp(-t / 0.0002)) * np.exp(-t / decay)
        x = rng.normal(0, 1, n) * env
        if rng.random() < 0.45:
            d = round(rng.uniform(0.0006, 0.002) * SR)
            x[d:] += rng.uniform(0.35, 0.8) * (rng.normal(0, 1, n) * env)[:n - d]
        fc = rng.uniform(850, 2500) * tone
        half = fc / rng.uniform(1.6, 3.0) / 2
        body = signal.sosfilt(_sos('bandpass', [fc - half, fc + half]), x)
        slap = signal.sosfilt(_sos('highpass', 2600), x)
        y = body / (np.std(body) + 1e-12) + 0.4 * slap / (np.std(slap) + 1e-12)
        y *= np.clip((n - np.arange(n)) / (0.004 * SR), 0, 1)
        bank.append(y / np.sqrt(np.sum(y ** 2)))
    return bank


def claps(m, start, length, rate, amp, pan=0.0, spread=0.55, far=0.0,
          bank=None, sigma=0.45):
    """Applause: claps at rate(t) a second (t from 0..length), each a hand
    from [bank] at a random size, scattered round pan(t). A few a second
    is a scattering in the stands; a few thousand is the stadium on its
    feet -- the same voice, only denser."""
    s0, e0, t = _span(m, start, length)
    n = len(t)
    if n == 0:
        return m
    hits = m.rng.poisson(np.maximum(rate(t), 0) / SR)
    idx = np.nonzero(hits)[0]
    if not len(idx):
        return m
    # Capped: an outlier clap is a crack that sticks out of the crowd.
    size = hits[idx] * np.minimum(m.rng.lognormal(0, sigma, len(idx)), 2.2)
    p = np.clip(_at(pan, t[idx]) + m.rng.normal(0, spread, len(idx)), -1, 1)
    gains = _pan_gains(p)
    bank = bank if bank is not None else _clap_bank(m.rng)
    kind = m.rng.integers(0, len(bank), len(idx))
    out = np.zeros((2, n))
    for k, ker in enumerate(bank):
        sel = kind == k
        if not sel.any():
            continue
        for ch in range(2):
            imp = np.zeros(n)
            imp[idx[sel]] = size[sel] * gains[ch][sel]
            out[ch] += signal.oaconvolve(imp, ker)[:n]
    _put(m, s0, _far(out, far) * amp)
    return m


def murmur(m, start, length, level, amp, excite=None, talkers=18, far=0.4,
           spread=0.9):
    """A crowd talking among itself, with no voice in it: each talker a
    breath through a mouth shape (three broad formant bands), its syllables
    a quick random pulse and its turns coming and going. level(t) is the
    crowd's loudness; excite(t) 0..1 opens every mouth brighter and has them
    all talk at once -- a crowd lifting is brighter and denser, not only
    louder. (t from 0..length.)"""
    s0, e0, t = _span(m, start, length)
    n = len(t)
    rng = m.rng
    lv = np.maximum(level(t), 0)
    ex = np.clip(excite(t), 0, 1) if excite is not None else None
    out = np.zeros((2, n))
    for _ in range(talkers):
        shape = (rng.uniform(380, 760), rng.uniform(1000, 1850), rng.uniform(2300, 3100))
        src = rng.normal(0, 1, n)

        def mouth(lift, shape=shape, src=src):
            y = np.zeros(n)
            for f, w in zip(shape, (1.0, 0.55, 0.25)):
                f *= lift
                y += w * signal.sosfilt(_sos('bandpass', [f * 0.78, f * 1.25], 1), src)
            return y / (np.std(y) + 1e-12)

        voice = mouth(1.0)
        syl = np.clip(0.3 + 0.7 * _wander(rng, n, rng.uniform(3.0, 6.0)), 0, 1.8) ** 1.4
        turn = smooth(_wander(rng, n, rng.uniform(0.12, 0.3)), -0.6, 0.6)
        if ex is not None:
            voice = voice * (1 - ex) + mouth(1.3) * ex
            turn = turn + (1 - turn) * ex
        talk = voice * syl * (0.12 + 0.88 * turn)
        gl, gr = _pan_gains(rng.uniform(-spread, spread))
        out[0] += gl * talk
        out[1] += gr * talk
    out *= lv / math.sqrt(talkers)
    _put(m, s0, _far(out, far) * amp)
    return m


def _slowed(y, rate):
    """[y] (2, n) read at speed rate[i] per output sample: time slowing.
    Everything in it drops and stretches together, the way a tape slows --
    on a crowd of noise that is a sinking, never a pitch sliding."""
    pos = np.cumsum(rate) - rate[0]
    src = np.arange(y.shape[1])
    return np.stack([np.interp(pos, src, y[ch], right=0.0) for ch in range(2)])


def _closing(y, cutoff):
    """[y] muffled by a lowpass whose cutoff[i] (Hz, per sample) moves:
    a bank of fixed filters crossfaded in log-frequency, so it never zips."""
    cuts = np.array([9000, 5000, 2800, 1600, 900, 500, 280], dtype=float)
    pos = np.interp(np.log(cutoff), np.log(cuts[::-1]),
                    np.arange(len(cuts))[::-1].astype(float))
    out = np.zeros_like(y)
    for k, c in enumerate(cuts):
        w = np.clip(1 - np.abs(pos - k), 0, 1)
        if np.max(w) > 0:
            out += w * signal.sosfilt(_sos('lowpass', c), y, axis=-1)
    return out


def _held_breath(m, start, length, formants, amp, rise, waver=0.18):
    """A breath drawn in and held: it swells over [rise] seconds and stays,
    wavering a little, with no breath out -- it ends open."""
    s0, e0, t = _span(m, start, length)
    n = len(t)
    env = smooth(t, 0, rise) * np.clip(1 + waver * _wander(m.rng, n, 0.9), 0.3, None)
    for ch in range(2):
        noise = m.rng.normal(0, 1, n)
        y = np.zeros(n)
        for fc, bw, w in formants:
            y += w * signal.sosfilt(_sos('bandpass', [fc - bw / 2, fc + bw / 2], 1), noise)
        m.y[ch, s0:e0] += amp * env * y
    return m


# -- the racer's own grains (a fusion station, the podium) -----------------


def _come_apart(m, at, amp=1.0, glass=(523, 717)):
    """A racer let go into a cloud of its element's grains: a breath out as
    it gives (leaning in over 35 ms), the grains thrown wide and going finer
    as they spread, and a stroked glass shimmering under them (two bodies,
    apart by no musical ratio, each beating fast against itself)."""
    m.air(at, 0.55, 600, 4200, amp=0.03 * amp, rise=0.07)
    burst = lambda t: smooth(t, at, at + 0.035) * np.exp(-np.maximum(t - at - 0.035, 0) / 0.26)
    for side in (-1.0, 1.0):
        m.grains(lambda t: 1900 * amp * burst(t),
                 lambda t: 0.45 + 0.4 * smooth(t, at, at + 0.7),
                 lambda t, s=side: s * 0.75 * smooth(t, at, at + 0.7),
                 amp=0.5, weight=lambda t: 0.5 - 0.2 * smooth(t, at, at + 0.8))
    # (Short and under the grains: held longer or louder, a glass is a note.)
    m.glass(at + 0.02, glass[0], amp=0.03 * amp, ring=0.6, attack=0.12,
            brightness=0.5, beat=2.6, pan=-0.15)
    m.glass(at + 0.05, glass[1], amp=0.02 * amp, ring=0.5, attack=0.15,
            brightness=0.45, beat=3.2, pan=0.2, ratios=[1.0, 2.32, 4.25])


def _cloud(m, a, b, amp=1.0):
    """The cloud hanging between: fine glints of the element, turning wide."""
    m.grains(lambda t: 260 * amp * smooth(t, a, a + 0.25) * (1 - smooth(t, b - 0.35, b)),
             _flat(0.93), lambda t: 0.6 * np.sin(2 * math.pi * 0.9 * t), amp=0.5,
             weight=_flat(0.35))


def _come_home(m, start, whole, amp=1.0, f_close=(660, 482)):
    """The grains swirling home from [start] and whole at [whole]: drawn in
    on a tightening turn, hot and fine as they leave, cooler and coarser as
    they land, on an in-breath -- then the last of them settling and a
    small glass closing (dark glass seated, a stroked glass under it)."""
    span = whole - start
    home = lambda t: smooth(t, start, whole) ** 1.3 * (1 - smooth(t, whole - 0.02, whole + 0.02))
    for side in (-1.0, 1.0):
        m.grains(lambda t: (200 * smooth(t, start, start + 0.1) + 1500 * home(t)) * amp
                 * (t < whole + 0.03),
                 lambda t: 0.85 - 0.3 * smooth(t, start + 0.1, whole),
                 lambda t, s=side: s * 0.7 * (1 - smooth(t, start, whole))
                 * np.cos(2 * math.pi * 1.4 * (t - start) + (s > 0) * math.pi),
                 amp=0.5, weight=lambda t: 0.3 + 0.3 * home(t))
    m.air(start, span + 0.03, 500, 3400, amp=0.022 * amp, rise=0.9)
    m.grains(lambda t: np.where(t > whole - 0.01, 1500 * amp * np.exp(-(t - whole + 0.01) / 0.06), 0),
             _flat(0.35), _flat(0.0), amp=0.5, weight=_flat(0.5))
    # (Floored at 320 Hz: a small glass seat has no weight below that, and a
    # low bump under it would read as a drum.)
    knock(m, whole, _dark_glass(m.rng, f_close[0], ring=0.09), amp=0.05 * amp,
          attack=0.006, tau=0.003, color=4500, floor=320)
    m.glass(whole - 0.01, f_close[1], amp=0.022 * amp, ring=0.25, attack=0.03,
            brightness=0.3, beat=1.0, ratios=[1.0, 2.32, 4.25])


# ===========================================================================
# The stands -- AmbienceCue (a bed under the whole race, at the ambience
# player's .18) and the crowd lifting on a lead change or the show ring
# ===========================================================================

LOOP = 12.0
XFADE = 1.5

# The crowd's balance, shared so the bed and every lift are one crowd
# (measured: at its peak a lift's applause sits ~5 dB over its murmur, and
# in the bed a scattered clap peaks ~8 dB over the talk). CROWD puts all of
# it on the footing of the core voices: the talk at level 1 is about as
# loud as a stream of 1500 grains a second.
CROWD = 0.016
MURMUR = 1.0 * CROWD       # the talk, at level 1
APPLAUSE = 10.0 * CROWD    # one clap in the mass of a full house
HANDS = 4.0 * CROWD        # one of the scattered hands that clap on their own
CHEER = 1.0 * CROWD        # the crowd's own air: its body, a cheer's breath


def crowd_loop():
    """The stands during a race, far: a crowd talking among itself that
    comes and goes like a tide, a ripple running through it once, and here
    and there someone clapping -- a few a second, scattered, now and then a
    little patch of hands for a moment. Never a beat; it sits under
    everything."""
    total = LOOP + XFADE
    m = Mix(total, seed=9101)
    rng = np.random.default_rng(91)
    t_all = m.t
    tide = 1 + 0.22 * _wander(rng, m.n, 0.08)
    ripple = 0.35 * np.exp(-((t_all - 6.1) / 0.8) ** 2)
    lv = np.clip(tide + ripple, 0.3, None)
    level = lambda t: np.interp(t, t_all, lv)
    murmur(m, 0.0, total, level, amp=MURMUR, talkers=22, far=0.55, spread=0.95)
    # The body of a full stand: a wide low air under the talk.
    rush(m, 0.0, total, _flat(430), lambda t: 0.12 * CHEER * level(t), width_oct=1.0,
         spread=1.0, flutter=0.15)
    # Scattered hands across the stands.
    scatter = np.clip(1 + 0.6 * _wander(rng, m.n, 0.2), 0.2, None) * 3.2
    claps(m, 0.0, total, lambda t: np.interp(t, t_all, scatter), amp=HANDS * 4.5,
          spread=0.75, far=0.45)
    # A few patches where a handful clap together for a moment.
    for at, length, pan, rate in ((1.7, 2.0, -0.6, 13), (5.4, 1.6, 0.55, 10),
                                  (8.3, 2.2, -0.15, 15), (10.2, 1.5, 0.75, 8)):
        claps(m, at, length,
              lambda t, L=length, r=rate: r * np.sin(math.pi * np.clip(t / L, 0, 1)) ** 2,
              amp=HANDS * 3.5, pan=pan, spread=0.15, far=0.4)
    m.room(t60=2.0, wet=0.4, darkness=3200)
    y = m.finish(loudness_db=-36.0, fade_out=0)
    return seamless_loop(y, XFADE)


SWELL = 2.6


def crowd_swell(v=0):
    """The crowd lifting (a lead change, the player's racer under the show
    ring's spotlights): the talk opening and brightening, the scattered
    hands thickening into applause, a breath of cheer with no voice in it
    -- and falling back to the stands' murmur."""
    m = Mix(SWELL, seed=9201 + 13 * v)
    rng = np.random.default_rng(920 + v)
    peak = 0.92 + 0.06 * v
    lean = rng.uniform(-0.3, 0.3)
    lift = lambda t: smooth(t, 0.0, peak) * (1 - smooth(t, peak + 0.15, SWELL - 0.1))
    murmur(m, 0.0, SWELL, lambda t: (0.35 + 1.4 * lift(t)) * smooth(t, 0, 0.3),
           amp=MURMUR, excite=lambda t: 0.85 * lift(t), talkers=18, far=0.35)
    claps(m, 0.0, SWELL, lambda t: 25 + 1800 * lift(t) ** 1.6, amp=APPLAUSE,
          pan=lean, spread=0.75, far=0.3)
    claps(m, 0.0, SWELL, lambda t: 4 + 120 * lift(t) ** 2, amp=HANDS * 1.2,
          pan=lean, spread=0.9, far=0.1)
    rush(m, 0.0, SWELL, lambda t: 800 + 700 * lift(t),
         lambda t: 0.25 * CHEER * lift(t) ** 1.3, width_oct=1.0, spread=1.0, flutter=0.3)
    m.room(t60=1.9, wet=0.36, darkness=3400)
    return m.finish(loudness_db=-31.0, fade_out=0.3)


# ===========================================================================
# The count -- race_stage.dart's countdown, one numeral a second: brass
# grains gather from scattered places into the numeral over 0 - 0.35 s,
# hold, and drift apart 0.75 - 1.0 s
# ===========================================================================

GATHER = 0.35
DRIFT = 0.75
TICK = 1.0


def count_tick(v=0):
    """A numeral of the count: fine brass grains drawn in from all over to
    one place, settling into it with a small glass seat; held; then letting
    go and drifting apart, thinner and finer. Every take the same weight --
    3, 2 and 1 are the same gesture, so there is no rising pitch to make a
    tune of the count."""
    m = Mix(TICK, seed=9301 + 7 * v)
    rng = np.random.default_rng(930 + v)
    # Drawn in from scattered places: loose streams converging, fine, a
    # little coarser as they land.
    for i in range(5):
        side = rng.uniform(-0.85, 0.85)
        a = rng.uniform(0.0, 0.08)
        m.grains(lambda t, a=a: 520 * smooth(t, a, GATHER - 0.05)
                 * (1 - smooth(t, GATHER - 0.03, GATHER + 0.01)),
                 lambda t: 0.86 - 0.18 * smooth(t, 0, GATHER),
                 lambda t, s=side: s * (1 - smooth(t, 0.0, GATHER)),
                 amp=0.5, weight=lambda t: 0.3 + 0.25 * smooth(t, 0, GATHER))
    m.air(0.0, GATHER + 0.06, 900, 5200, amp=0.012, rise=0.85)
    # Settled into the numeral: the last grains and a small glass seat
    # (soft contact, floored so it is not a bump), with a stroked glass of
    # the brass's glow under it.
    m.grains(lambda t: np.where(t > GATHER - 0.01, 1800 * np.exp(-(t - GATHER + 0.01) / 0.04), 0),
             _flat(0.62), _flat(0.0), amp=0.5, weight=_flat(0.55))
    # (Rung short and kept under the grains: a glass that rings on through
    # the hold is a beep.)
    f0 = rng.uniform(820, 960)
    knock(m, GATHER, _dark_glass(rng, f0, ring=0.07), amp=0.03,
          attack=0.008, tau=0.003, color=5000, floor=350)
    m.glass(GATHER - 0.004, f0 / 1.37, amp=0.012, ring=0.2,
            attack=0.02, brightness=0.3, beat=1.4, ratios=[1.0, 2.32, 4.25])
    # Held: the odd glint.
    m.grains(lambda t: 70 * smooth(t, GATHER + 0.05, GATHER + 0.15) * (1 - smooth(t, DRIFT - 0.05, DRIFT)),
             _flat(0.95), _flat(0.0), amp=0.5, weight=_flat(0.3))
    # Drifting apart: two thin streams going out either side, finer as
    # they thin.
    for side in (-1.0, 1.0):
        m.grains(lambda t: 420 * smooth(t, DRIFT - 0.03, DRIFT + 0.06) * (1 - smooth(t, DRIFT + 0.08, 0.97)),
                 lambda t: 0.78 + 0.17 * smooth(t, DRIFT, TICK),
                 lambda t, s=side: s * 0.7 * smooth(t, DRIFT, TICK),
                 amp=0.5, weight=lambda t: 0.32 - 0.12 * smooth(t, DRIFT, TICK))
    m.air(DRIFT - 0.02, 0.24, 1200, 6000, amp=0.006, rise=0.3)
    m.room(t60=0.9, wet=0.22)
    return m.finish(loudness_db=-32.0, fade_out=0.06)


# ===========================================================================
# The start -- the count reaches 0: the start line's curtain of grains
# rises and the crowd lifts
# ===========================================================================

GUN = 1.8


def race_gun():
    """Off: a clean struck accent -- stone and a glass, bright, nothing
    under 300 Hz, so it is a mark and not a shot or a drum -- then the
    start line's curtain of grains lifting away, finer as it rises, the air
    lifting with it, and the stands lifting gently behind."""
    m = Mix(GUN, seed=9401)
    rng = np.random.default_rng(94)
    knock(m, 0.002, _stone(rng, 560, count=18, ring=0.08), amp=0.3,
          attack=0.0015, tau=0.0018, color=7000, width=0.6, floor=320)
    m.glass(0.002, 622, amp=0.09, ring=0.7, attack=0.0025, brightness=0.55, beat=0.9)
    # The curtain rising: thick at once, thinning and finer as it lifts.
    rise = lambda t: smooth(t, 0.0, 0.05) * np.exp(-np.maximum(t - 0.05, 0) / 0.32)
    for side in (-0.45, 0.0, 0.45):
        m.grains(lambda t: 1500 * rise(t),
                 lambda t: 0.35 + 0.5 * smooth(t, 0.02, 0.9),
                 lambda t, s=side: s * (1 + 0.3 * smooth(t, 0, 0.8)),
                 amp=0.5, weight=lambda t: 0.45 - 0.15 * smooth(t, 0, 0.9))
    rush(m, 0.0, 1.2, lambda t: 700 * 2 ** smooth(t, 0, 1.0),
         lambda t: 0.035 * smooth(t, 0, 0.06) * (1 - smooth(t, 0.15, 1.2)),
         width_oct=0.9, spread=0.9)
    # The stands lift behind it, gently.
    lift = lambda t: smooth(t, 0.1, 0.75) * (1 - smooth(t, 1.0, 1.75))
    murmur(m, 0.0, GUN, lambda t: 1.3 * lift(t), amp=MURMUR * 1.8,
           excite=lambda t: 0.6 * lift(t), talkers=14, far=0.4)
    claps(m, 0.0, GUN, lambda t: 700 * lift(t) ** 1.5, amp=APPLAUSE * 1.8,
          spread=0.8, far=0.35)
    m.room(t60=1.8, wet=0.32, darkness=3600)
    return m.finish(loudness_db=-29.0, fade_out=0.3)


# ===========================================================================
# The boost -- RaceSim._boost: 0.6 s wind-up (the racer gathers itself),
# then a 1.2 s surge
# ===========================================================================

WINDUP = 36 / 60      # kRaceBoostWindupTicks / kRaceTickRate
SURGE = 72 / 60       # kRaceBoostSurgeTicks / kRaceTickRate
BOOST = WINDUP + SURGE


def boost(v=0):
    """A boost: the racer gathers itself -- its grains drawn in from round
    it, quicker and finer as the tension climbs, on a breath in -- and at
    0.6 s lets go into a surge: a current of grains pouring off behind it
    (left: the track runs left to right) and the air it tears, thinning out
    by 1.8 s."""
    m = Mix(BOOST, seed=9501 + 11 * v)
    rng = np.random.default_rng(950 + v)
    w = WINDUP
    pull = lambda t: smooth(t, 0.0, w) ** 1.5 * (1 - smooth(t, w - 0.015, w + 0.01))
    for side in (-0.7, 0.7):
        reach = side * rng.uniform(0.85, 1.1)
        m.grains(lambda t: (150 + 1700 * pull(t)) * (t < w + 0.01),
                 lambda t: 0.5 + 0.35 * smooth(t, 0, w),
                 lambda t, s=reach: s * (1 - smooth(t, 0, w)),
                 amp=0.5, weight=lambda t: 0.3 + 0.3 * pull(t))
    j = rng.uniform(0.92, 1.08)
    _breath(m, 0.02, w, [(1200 * j, 700, 0.6), (2400 * j, 1200, 0.8), (3900 * j, 1600, 0.5)],
            amp=0.9, rise=0.96)
    rush(m, 0.0, w + 0.02, lambda t: 500 + 700 * smooth(t, 0, w),
         lambda t: 0.012 * pull(t), width_oct=0.8, spread=0.6)
    # Let go: the current of grains pouring off behind it.
    surge = lambda t: smooth(t, w, w + 0.03) * np.exp(-np.maximum(t - w - 0.03, 0) / 0.42) \
        * (1 - smooth(t, BOOST - 0.35, BOOST - 0.02))
    for to, dens in ((-0.65, 2200), (-0.25, 1600)):
        dens *= rng.uniform(0.9, 1.1)
        m.grains(lambda t, d=dens: d * surge(t),
                 lambda t: 0.62 - 0.22 * smooth(t, w, BOOST),
                 lambda t, p=to: p * smooth(t, w, w + 0.5),
                 amp=0.5, weight=lambda t: 0.35 + 0.3 * surge(t))
    rush(m, w - 0.01, SURGE + 0.01, lambda t: 1500 * (600 / 1500) ** smooth(t, 0, SURGE),
         lambda t: 0.045 * smooth(t, 0, 0.03) * np.exp(-t / 0.5) * (1 - smooth(t, SURGE - 0.3, SURGE)),
         width_oct=1.0, pan=lambda t: -0.45 * smooth(t, 0, 0.5), spread=0.7, flutter=0.3)
    m.room(t60=1.0, wet=0.2)
    return m.finish(loudness_db=-30.0, fade_out=0.15)


# ===========================================================================
# A wall leg -- stone grains crumbling under a climbing creature's feet
# ===========================================================================

CRUMBLE = 0.8


def wall_crumble(v=0):
    """A foothold giving on a stone wall: a few small stones letting go at
    once, pieces falling away down the wall -- thick at first, thinning,
    duller as they fall further -- and the grit trickling after them."""
    m = Mix(CRUMBLE, seed=9601 + 17 * v)
    r = np.random.default_rng(960 + 31 * v)
    foot = r.uniform(-0.25, 0.25)
    for i in range(3 + v % 2):
        _stone_knock(m, 0.004 + 0.012 * i + r.uniform(0, 0.006), lo=r.uniform(420, 800),
                     hi=6000, n=10, ring=0.03, contact=r.uniform(0.0012, 0.003),
                     hardness=6000, grit=0.5, amp=0.25 * r.uniform(0.6, 1.0),
                     pan=foot + r.normal(0, 0.1), tilt=0.35, rng=r)
    times = 0.03 + np.sort(r.gamma(1.4, 0.09, 26))
    times = times[times < 0.68]
    near = times < 0.25
    _chips(m, times[near], np.clip(r.lognormal(-1.0, 0.4, near.sum()), 0.12, 0.6),
           foot + r.normal(0, 0.25, near.sum()), amp=0.2, rng=r)
    _chips(m, times[~near], np.clip(r.lognormal(-1.1, 0.4, (~near).sum()), 0.12, 0.5),
           foot + r.normal(0, 0.3, (~near).sum()), amp=0.13, dull=0.75, rng=r)
    m.grains(lambda t: 1700 * smooth(t, 0.01, 0.04) * np.exp(-np.maximum(t - 0.04, 0) / 0.2),
             lambda t: 0.3 + 0.18 * smooth(t, 0.05, 0.6), _flat(foot), amp=0.5,
             weight=lambda t: 0.45 - 0.15 * smooth(t, 0, 0.6))
    m.air(0.01, 0.6, 500, 3500, amp=0.012, rise=0.12)
    m.room(t60=0.9, wet=0.18, darkness=3600)
    return m.finish(loudness_db=-33.0, fade_out=0.15)


# ===========================================================================
# A fusion station -- the racer comes apart into its element's grains, and
# comes back
# ===========================================================================

FUSE = 1.1
REFORM = 0.74


def fuse_in():
    """At a fusion station: the racer let go into a cloud of its element's
    grains -- a release, the grains spreading wide and fine, a glass
    shimmering under the cloud."""
    m = Mix(FUSE, seed=9701)
    _come_apart(m, 0.0)
    _cloud(m, 0.15, 1.05)
    m.room(t60=1.2, wet=0.24)
    return m.finish(loudness_db=-31.0, fade_out=0.3)


def fuse_out():
    """Fused: the grains swirl home, coarser as they land, and the racer is
    whole at 0.74 s -- the last of them settling and a small glass closing."""
    m = Mix(FUSE, seed=9801)
    _come_home(m, 0.0, REFORM)
    m.room(t60=1.0, wet=0.22)
    return m.finish(loudness_db=-31.5, fade_out=0.25)


# ===========================================================================
# The end -- the line, a photo finish, the podium
# ===========================================================================

FINISH = 3.0


def race_finish():
    """The winner through the line's curtain of brass grains -- a shower
    parting round it, crossing left to right, brass flakes catching, a warm
    glass under it -- and the stadium erupting into full applause, then
    settling."""
    m = Mix(FINISH, seed=9901)
    rng = np.random.default_rng(99)
    curtain = lambda t: smooth(t, 0, 0.02) * np.exp(-np.maximum(t - 0.02, 0) / 0.22)
    for off in (-0.3, 0.3):
        m.grains(lambda t: 2000 * curtain(t), lambda t: 0.84 - 0.12 * smooth(t, 0, 0.5),
                 lambda t, o=off: o - 0.4 + 0.9 * smooth(t, 0, 0.45),
                 amp=0.5, weight=_flat(0.45))
    for _ in range(9):
        at = 0.005 + rng.gamma(1.5, 0.06)
        knock(m, at, _plate(rng, rng.uniform(2600, 4800), ring=rng.uniform(0.06, 0.11)),
              amp=0.06 * rng.uniform(0.5, 1), attack=0.0015, tau=0.0012, color=9000,
              pan=rng.uniform(-0.6, 0.6))
    m.glass(0.01, 392, amp=0.06, ring=1.1, attack=0.06, brightness=0.35, beat=0.8,
            ratios=[1.0, 2.32, 4.25])
    # The stadium erupts, holds, and settles.
    roar = lambda t: smooth(t, 0.05, 0.4) * (1 - 0.75 * smooth(t, 1.1, 2.4)) \
        * (1 - smooth(t, 2.3, FINISH - 0.05))
    # (Louder than a lift: the whole house, and the loudest thing here.)
    full = 1.6
    murmur(m, 0.0, FINISH, lambda t: (0.3 + 2.0 * roar(t)) * smooth(t, 0, 0.15),
           amp=MURMUR * full, excite=roar, talkers=20, far=0.3)
    claps(m, 0.0, FINISH, lambda t: 40 + 3200 * roar(t) ** 1.3, amp=APPLAUSE * full,
          spread=0.85, far=0.25)
    claps(m, 0.0, FINISH, lambda t: 6 + 260 * roar(t) ** 1.5, amp=HANDS * 1.2 * full,
          spread=0.95, far=0.05)
    rush(m, 0.03, FINISH - 0.1, lambda t: 850 + 600 * roar(t + 0.03),
         lambda t: 0.3 * CHEER * full * roar(t + 0.03) ** 1.2, width_oct=1.0, spread=1.0,
         flutter=0.35)
    m.room(t60=2.0, wet=0.34, darkness=3600)
    return m.finish(loudness_db=-27.5, fade_out=0.4)


HUSH = 1.4


def photo_hush():
    """Time slows for a photo finish: the crowd on its feet sinks -- read
    slower and slower, so all of it drops and stretches together -- and
    muffles as if heard through a held breath, and the breath is held. It
    ends open: the finish, or the result, is what lets it go."""
    m = Mix(HUSH, seed=10001)
    sub = Mix(HUSH, seed=10002)
    murmur(sub, 0.0, HUSH, lambda t: 1.6 * smooth(t, 0, 0.08), amp=MURMUR,
           excite=_flat(0.8), talkers=18, far=0.3)
    claps(sub, 0.0, HUSH, _flat(1400), amp=APPLAUSE, spread=0.85, far=0.3)
    rush(sub, 0.0, HUSH, _flat(1300), lambda t: 0.2 * CHEER * smooth(t, 0, 0.08),
         width_oct=1.0, spread=1.0, flutter=0.3)
    slowed = _slowed(sub.y, 1 - 0.6 * smooth(m.t, 0.05, 0.6))
    muffled = _closing(slowed, 7500 * (420 / 7500) ** smooth(m.t, 0.05, 0.75))
    m.y += muffled * (1 - 0.7 * smooth(m.t, 0.1, 0.8))
    _held_breath(m, 0.08, HUSH - 0.08, [(380, 220, 1.0), (850, 420, 0.6), (1700, 800, 0.3)],
                 amp=0.05, rise=0.55)
    m.room(t60=1.6, wet=0.3, darkness=3000)
    return m.finish(loudness_db=-32.0, fade_out=0.12)


PODIUM = 3.4
BURST = 0.3
WHOLE = BURST + 2.6


def podium():
    """The podium: three racers stand on plinths of grain as warm applause
    rises; the winner bursts into its element's grains at 0.3 s, the cloud
    turns over its plinth, and swirls home -- whole at 2.9 s -- with a small
    glass closing, the applause easing under it."""
    m = Mix(PODIUM, seed=10101)
    rng = np.random.default_rng(101)
    warm = lambda t: smooth(t, 0, 0.35) * (1 - 0.45 * smooth(t, 1.2, 3.0)) \
        * (1 - smooth(t, 2.9, PODIUM - 0.05))
    claps(m, 0.0, PODIUM, lambda t: 900 * warm(t), amp=APPLAUSE * 0.45, spread=0.85,
          far=0.45, bank=_clap_bank(rng, tone=0.8))
    murmur(m, 0.0, PODIUM, lambda t: 0.9 * warm(t), amp=MURMUR * 0.5,
           excite=lambda t: 0.4 * warm(t), talkers=16, far=0.45)
    # The plinths taking their racers: coarse grain settling under each.
    # (Grain only: three stone knocks this close together are a drum roll.)
    for at, pan, size in ((0.0, -0.55, 0.8), (0.07, 0.55, 0.7), (0.14, 0.0, 1.0)):
        m.grains(lambda t, a=at, s=size: 1100 * s * smooth(t, a, a + 0.025)
                 * np.exp(-np.maximum(t - a, 0) / 0.16),
                 _flat(0.32), _flat(pan), amp=0.5, weight=_flat(0.5))
    _come_apart(m, BURST, amp=1.1)
    _cloud(m, BURST + 0.2, WHOLE - 0.4)
    _come_home(m, WHOLE - 1.0, WHOLE, f_close=(620, 452))
    m.room(t60=2.0, wet=0.32, darkness=3400)
    return m.finish(loudness_db=-28.5, fade_out=0.4)


CUES = {
    'amb_race_crowd_loop': {
        'build': crowd_loop, 'loop': True,
        'description': 'The stands during a race, far: a crowd murmuring like a tide, scattered hands clapping, never on a beat',
    },
    'sfx_race_crowd_swell': {
        'build': crowd_swell, 'variants': 3,
        'description': 'The crowd lifting: talk opening and brightening, hands thickening into applause, falling back',
    },
    'sfx_race_count_tick': {
        'build': count_tick, 'variants': 3,
        'description': 'A numeral of the count: fine brass grains drawn in and seated with a small glass, held, drifting apart',
    },
    'sfx_race_gun': (
        race_gun,
        'Off: a struck stone-and-glass accent, the start line\'s curtain of grains lifting, the stands lifting behind',
    ),
    'sfx_race_boost': {
        'build': boost, 'variants': 3,
        'description': 'A boost: grains drawn in on a breath for 0.6 s, then a current of grains and air pouring off behind',
    },
    'sfx_race_wall_crumble': {
        'build': wall_crumble, 'variants': 3,
        'description': 'A foothold giving: small stones letting go, pieces falling down the wall, grit trickling after',
    },
    'sfx_race_fuse_in': (
        fuse_in,
        'At a fusion station: the racer let go into a cloud of its element\'s grains, a glass shimmering under it',
    ),
    'sfx_race_fuse_out': (
        fuse_out,
        'Fused: the grains swirl home, coarser as they land, whole at 0.74 s with a small glass closing',
    ),
    'sfx_race_finish': (
        race_finish,
        'Through the line\'s curtain of brass grains, and the stadium erupting into full applause and settling',
    ),
    'sfx_race_photo_hush': (
        photo_hush,
        'A photo finish: the crowd slowing, sinking and muffling to a held breath, ending open',
    ),
    'sfx_race_podium': (
        podium,
        'The podium: plinths of grain, the winner bursting into its grains and back by 2.9 s over warm applause',
    ),
}
