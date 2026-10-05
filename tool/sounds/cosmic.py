"""The cosmos: open space (cosmic_screen.dart + lib/games/cosmic/) and Cosmic
Survival's meta moments (lib/games/cosmic_survival/).

Space is dark glass and obsidian, matter motes and star dust, glyph portals
and rifts. So the materials here are mostly AIR (the ship moving, space
folding, a horde massing), STONE (obsidian bodies, ancient mechanisms
grinding, a boss's mass), FLAME (the booster) and, only where the picture is
literally grains -- matter motes, a companion gathering, an element pouring
from a cache -- grains. Glass is a body under things, never the point.

The voices this family adds (core.py has grains / glass / air / room):

  rush      a moving band of air: its centre, loudness and place follow the
            motion (being flung, a tunnel rushing past, an inhale)
  modes     a resonator bank: stone (many close modes, dying fast), dark
            glass, a thin plate (gold leaf) -- excited by whatever touches it
  knock     a body struck, leaning in over its attack (never a spike)
  grind     stick-slip friction rung through a body: a mechanism turning, a
            mass groaning, glass halves parting
  roar      combustion: turbulent low roar, flame flutter, crackle, hiss
  bubbles   wet growth: Minnaert bubbles rising through a liquid
  scratch   dry quill strokes on parchment (the glyph portal's script)
"""
import math

import numpy as np
from scipy import signal

from sounds.core import SR, Mix, seamless_loop, smooth

# ===========================================================================
# Voices
# ===========================================================================


def _sos(kind, f, order=2):
    return signal.butter(order, f, btype=kind, fs=SR, output='sos')


def _band(x, lo, hi, order=2):
    return signal.sosfilt(_sos('bandpass', [lo, min(hi, SR * 0.45)], order), x, axis=-1)


def _low(x, f, order=2):
    return signal.sosfilt(_sos('lowpass', f, order), x, axis=-1)


def _span(m, start, length):
    s0 = m._at(start)
    e0 = m._at(start + length)
    return s0, e0, m.t[s0:e0] - start


def _pan_gains(p):
    p = np.clip(p, -1, 1)
    return np.cos((p + 1) * math.pi / 4), np.sin((p + 1) * math.pi / 4)


def _put(m, s0, y, pan=0.0):
    """Adds mono [y] at [pan] (a number or a per-sample array) or stereo [y]
    as it is, from sample [s0]."""
    n = min(y.shape[-1], m.n - s0)
    if n <= 0:
        return
    if y.ndim == 1:
        gl, gr = _pan_gains(pan if np.isscalar(pan) else pan[:n])
        m.y[0, s0:s0 + n] += gl * y[:n]
        m.y[1, s0:s0 + n] += gr * y[:n]
    else:
        m.y[:, s0:s0 + n] += y[:, :n]


def _drift(rng, n, rate_hz):
    """Slow random movement (turbulence, a breeze changing its mind):
    lowpassed noise, zero mean, unit deviation."""
    pad = SR // 2
    w = _low(rng.normal(0, 1, n + pad), rate_hz)[pad:]
    return w / (np.std(w) + 1e-12)


def _modes(x, freqs, t60s, gains):
    """A resonator bank: each mode a two-pole resonator that rings for its
    own t60 when [x] touches it."""
    out = np.zeros_like(x)
    for f, t60, g in zip(freqs, t60s, gains):
        if f >= SR * 0.45:
            continue
        w = 2 * math.pi * f / SR
        r = math.exp(-6.9 / (t60 * SR))
        out += g * signal.lfilter([math.sin(w)], [1, -2 * r * math.cos(w), r * r], x, axis=-1)
    return out


def _stone(rng, f0, count=18, ring=0.12):
    """A block of stone or obsidian: many close inharmonic modes, the high
    ones dying first. A knock or a grind, never a note."""
    steps = 1 + rng.uniform(0.10, 0.38, count - 1)
    f = f0 * np.concatenate([[1.0], np.cumprod(steps)])
    t60 = ring * (f / f0) ** -0.9 * rng.uniform(0.7, 1.3, count)
    g = (f / f0) ** -0.35 * rng.uniform(0.5, 1.0, count)
    return f, t60, g


def _dark_glass(rng, f0, ring=0.5):
    """The ship's and the stations' material: a heavy glass, its modes a
    wine glass's but damped by its thickness, each split into a close pair."""
    ratios = np.array([1.0, 2.32, 4.25, 6.63, 9.38, 12.6])
    f, t60, g = [], [], []
    for k, r in enumerate(ratios):
        for d in (-0.0016, 0.0019):
            f.append(f0 * r * (1 + d + rng.normal(0, 0.0006)))
            t60.append(ring / (1 + 0.8 * k))
            g.append(math.exp(-0.7 * k))
    return np.array(f), np.array(t60), np.array(g)


def _plate(rng, f0, ring=0.06):
    """A thin metal leaf (gold foil, a flake): a plate's crowded modes."""
    ratios = np.array([1.0, 1.58, 2.14, 2.31, 2.65, 2.92, 3.16, 3.50, 3.91])
    f = f0 * ratios * (1 + rng.normal(0, 0.01, len(ratios)))
    t60 = ring * rng.uniform(0.6, 1.2, len(ratios)) / (1 + 0.15 * np.arange(len(ratios)))
    g = rng.uniform(0.4, 1.0, len(ratios))
    return f, t60, g


def _peak1(y):
    return y / (np.max(np.abs(y)) + 1e-12)


def knock(m, at, body, amp, attack=0.003, tau=0.004, colour=4000, pan=0.0,
          width=0.0, floor=120):
    """[body] (freqs, t60s, gains) struck at [at]: a short noise touch that
    leans in over [attack] and dies over [tau], rung through the body. For a
    heavy thing, attack is 20-40 ms: it presses, it doesn't crack. Below
    [floor] Hz is taken out: a phone never plays it and headphones would
    turn a big body's weight into a boom."""
    f, t60, g = body
    length = attack + 6 * tau + float(np.max(t60)) * 1.1
    s0, e0, t = _span(m, at, length)
    n = len(t)
    env = np.where(t < attack, np.sin(0.5 * math.pi * np.clip(t / attack, 0, 1)) ** 2,
                   np.exp(-(t - attack) / tau))
    out = np.zeros((2, n))
    for ch in range(2):
        exc = _low(m.rng.normal(0, 1, n) * env, colour)
        # The two sides hear the body from a little apart.
        out[ch] = _modes(exc, f * (1 + (ch - 0.5) * 0.004 * width), t60, g)
    out = signal.sosfilt(_sos('highpass', floor), out, axis=-1)
    out = _peak1(out) * amp
    gl, gr = _pan_gains(pan)
    out[0] *= gl * math.sqrt(2)
    out[1] *= gr * math.sqrt(2)
    _put(m, s0, out)
    return m


def _stick_slip(rng, speed, rate_lo, rate_hi, jitter=0.3, slide=0.15):
    """Friction: the surfaces catch and let go, faster as they move faster;
    between catches they slide (a little hiss). [speed] is 0..1 per sample."""
    n = len(speed)
    wob = _drift(rng, n, 25) if n > 10 else np.zeros(n)
    rate = (rate_lo + (rate_hi - rate_lo) * speed) * np.clip(1 + jitter * wob, 0.2, 3)
    phase = np.cumsum(rate / SR)
    k = np.floor(phase)
    hits = np.nonzero(np.diff(k, prepend=k[0]))[0]
    exc = np.zeros(n)
    live = speed[hits] > 0.01
    hits = hits[live]
    exc[hits] = speed[hits] * rng.lognormal(0, 0.45, len(hits)) * rng.choice([-1, 1], len(hits))
    exc += slide * speed * rng.normal(0, 1, n) * 0.25
    return exc


def grind(m, start, length, speed, body, amp, rate=(10, 60), jitter=0.3,
          slide=0.15, colour=3000, pan=0.0, width=0.6, floor=120):
    """A mechanism or a mass moving against itself: stick-slip friction at
    [speed](t) (0..1), rung through [body]. (Below [floor] Hz is taken out,
    as for a knock.)"""
    # Rendered on past [length] for as long as the body rings, so nothing
    # still ringing is cut off.
    s0, e0, t = _span(m, start, length + float(np.max(body[1])) * 1.1)
    sp = np.clip(speed(t), 0, 1) * (t < length)
    out = np.zeros((2, len(t)))
    shared = _stick_slip(m.rng, sp, *rate, jitter=jitter, slide=slide)
    for ch in range(2):
        own = _stick_slip(m.rng, sp, *rate, jitter=jitter, slide=slide)
        exc = _low((1 - width) * shared + width * own, colour)
        out[ch] = _modes(exc, body[0], body[1], body[2])
    out = signal.sosfilt(_sos('highpass', floor), out, axis=-1)
    out = _peak1(out) * amp
    p = pan(t) if callable(pan) else pan
    gl, gr = _pan_gains(p)
    out[0] *= gl * math.sqrt(2)
    out[1] *= gr * math.sqrt(2)
    _put(m, s0, out)
    return m


_CENTRES = np.geomspace(60, 9500, 22)


def rush(m, start, length, centre, amp, width_oct=0.8, pan=0.0, spread=0.8,
         flutter=0.0, seed_noise=None):
    """Moving air with no tone in it: a band of noise whose centre(t) Hz,
    loudness amp(t) and place pan(t) follow the motion. [spread] 0 is one
    point, 1 is as wide as the field. [flutter] roughens it (turbulence)."""
    s0, e0, t = _span(m, start, length)
    n = len(t)
    if n == 0:
        return m
    c = np.log2(np.maximum(centre(t), 20.0))
    a = amp(t)
    weights = []
    for fc in _CENTRES:
        weights.append(np.exp(-0.5 * ((math.log2(fc) - c) / width_oct) ** 2))
    weights = np.array(weights)
    weights /= np.sqrt(np.sum(weights ** 2, axis=0, keepdims=True)) + 1e-12
    out = np.zeros((2, n))
    for k, fc in enumerate(_CENTRES):
        w = weights[k] * a
        if np.max(w) < 1e-4:
            continue
        sos = _sos('bandpass', [fc / 2 ** 0.35, min(fc * 2 ** 0.35, SR * 0.45)])

        def unit():
            x = signal.sosfilt(sos, m.rng.normal(0, 1, n))
            return x / (np.std(x) + 1e-12)

        common = unit()
        for ch in range(2):
            out[ch] += w * (math.sqrt(1 - spread) * common + math.sqrt(spread) * unit())
    if flutter > 0:
        out *= np.clip(1 + flutter * _drift(m.rng, n, 40), 0, None)
    p = pan(t) if callable(pan) else pan
    gl, gr = _pan_gains(p)
    out[0] *= gl * math.sqrt(2)
    out[1] *= gr * math.sqrt(2)
    _put(m, s0, out)
    return m


def roar(m, start, length, env, amp, body_lo=80, body_hi=850, rasp=0.45,
         crackle=22.0, hiss=0.12, hull=None, seed_turb=None):
    """Combustion: a turbulent low roar, the flame's flutter on top of it,
    crackle, and the exhaust's hiss. [hull] (a body) is shaken by the roar
    a little, so the ship's glass is under it -- driven by noise, so it hums
    without a whine."""
    s0, e0, t = _span(m, start, length)
    n = len(t)
    e = env(t)
    out = np.zeros((2, n))
    slow = np.clip(1 + 0.35 * _drift(m.rng, n, 5), 0.2, None)
    for ch in range(2):
        flame = np.abs(_drift(m.rng, n, 70)) ** 1.4
        body = _band(m.rng.normal(0, 1, n), body_lo, body_hi, 2)
        body /= np.std(body) + 1e-12
        body *= slow * (0.75 + 0.45 * flame)
        edge = _band(m.rng.normal(0, 1, n), 700, 3600, 2)
        edge /= np.std(edge) + 1e-12
        edge *= rasp * flame * slow
        # Crackle: capped, so no single pop jumps out of the roar as a click.
        pops = (m.rng.random(n) < crackle / SR) * np.minimum(m.rng.lognormal(0, 0.5, n), 2.2)
        pops = _band(pops, 1600, 6500, 2)
        pops *= 0.3 / (np.std(pops) + 1e-12) * math.sqrt(crackle / 25)
        top = _band(m.rng.normal(0, 1, n), 4200, 11000, 2)
        top /= np.std(top) + 1e-12
        top *= hiss * (0.8 + 0.2 * slow)
        y = body + edge + pops + top
        if hull is not None:
            ring = _modes(body * 0.02, hull[0], hull[1], hull[2])
            y += ring / (np.std(ring) + 1e-12) * 0.18
        out[ch] = y * e
    out *= amp
    _put(m, s0, out)
    return m


def bubbles(m, start, length, rate, size, amp, pan=0.0, spread=0.5):
    """Bubbles rising through something wet: each a Minnaert ring whose
    pitch climbs as it nears the surface and pops. rate(t) per second,
    size(t) 0 (fine, high) .. 1 (fat, low)."""
    s0, e0, t = _span(m, start, length)
    n = len(t)
    dens = np.maximum(rate(t), 0) / SR
    hits = np.nonzero(m.rng.random(n) < dens)[0]
    out = np.zeros((2, n))
    for h in hits:
        sz = np.clip(size(t[h:h + 1])[0] + m.rng.normal(0, 0.18), 0, 1)
        f0 = 2200 * (0.18 ** sz) * m.rng.uniform(0.85, 1.15)
        dur = 0.012 + 0.05 * sz
        k = np.arange(int(dur * 3.5 * SR))
        tt = k / SR
        # A real bubble's ring climbs a little as it rises -- a fraction of
        # its pitch, never a sweep.
        f = f0 * (1 + 0.12 * tt / dur)
        ph = 2 * math.pi * np.cumsum(f) / SR
        env = np.sin(0.5 * math.pi * np.clip(tt / 0.0015, 0, 1)) * np.exp(-tt / dur)
        b = np.sin(ph) * env * m.rng.lognormal(0, 0.35) * (0.6 + 0.6 * sz)
        e = min(n, h + len(b))
        p = np.clip((pan(t[h:h + 1])[0] if callable(pan) else pan)
                    + m.rng.normal(0, spread), -1, 1)
        gl, gr = _pan_gains(p)
        out[0, h:e] += gl * b[:e - h]
        out[1, h:e] += gr * b[:e - h]
    _put(m, s0, out * amp)
    return m


def scratch(m, start, length, rate, amp, pan_spread=0.7, bright=1.0):
    """Quill strokes on parchment: each a short dry drag, the paper's fibre
    catching the nib hundreds of times a second."""
    s0, e0, t = _span(m, start, length)
    n = len(t)
    dens = np.maximum(rate(t), 0) / SR
    hits = np.nonzero(m.rng.random(n) < dens)[0]
    out = np.zeros((2, n))
    for h in hits:
        dur = m.rng.uniform(0.018, 0.07)
        k = int(dur * SR)
        tt = np.arange(k) / dur / SR
        env = np.sin(math.pi * tt) ** 1.5
        speed = env
        fibre = _stick_slip(m.rng, speed, 250, 900, jitter=0.5, slide=0.6)
        lo = 1800 * bright * m.rng.uniform(0.8, 1.25)
        x = _band(fibre, lo, lo * 3.2, 2) * m.rng.lognormal(0, 0.4)
        e = min(n, h + k)
        gl, gr = _pan_gains(m.rng.uniform(-pan_spread, pan_spread))
        out[0, h:e] += gl * x[:e - h]
        out[1, h:e] += gr * x[:e - h]
    out = out / (np.max(np.abs(out)) + 1e-12) * amp
    _put(m, s0, out)
    return m


def rumble(m, start, length, env, amp, lo=35, hi=220, spread=0.7, drift_hz=3.0):
    """A far, low mass of sound -- displaced air, a horde, the deep of space
    -- with a slow turbulence in it. Mostly below what a phone plays, so it
    carries some 200-500 Hz of its own (what a big rumble leaves on a small
    speaker)."""
    s0, e0, t = _span(m, start, length)
    n = len(t)
    e = env(t)
    out = np.zeros((2, n))
    common = m.rng.normal(0, 1, n)
    swell = np.clip(1 + 0.4 * _drift(m.rng, n, drift_hz), 0.1, None)
    for ch in range(2):
        x = math.sqrt(1 - spread) * common + math.sqrt(spread) * m.rng.normal(0, 1, n)
        deep = _band(x, lo, hi, 2)
        deep /= np.std(deep) + 1e-12
        upper = _band(x, hi, hi * 2.6, 2)
        upper /= np.std(upper) + 1e-12
        out[ch] = (deep + 0.35 * upper) * swell * e
    _put(m, s0, out * amp)
    return m


def _ease_out_cubic(x):
    x = np.clip(x, 0, 1)
    return 1 - (1 - x) ** 3


# ===========================================================================
# Open space -- the ship flying (cosmic_game.dart, cosmic_screen.dart)
# ===========================================================================


def matter_collect(v=0):
    """One mote of matter drawn into the hold (planet motes, swarms, a
    nebula). They come in streams of hundreds, the cue throttled to one per
    80 ms at .30 gain -- so each is a short soft intake and a pinch settling,
    with no edge to stack into a machine gun."""
    m = Mix(0.26, seed=5101 + v)
    rng = np.random.default_rng(90 + v)
    side = rng.uniform(-0.35, 0.35)
    # Drawn in: a breath that swells as the mote reaches the hull and stops.
    reach = 0.07 + 0.02 * v / 3
    rush(m, 0.0, reach + 0.03,
         lambda t: 900 + 1600 * smooth(t, 0, reach),
         lambda t: 0.007 * smooth(t, 0.0, reach) * (1 - smooth(t, reach, reach + 0.03)),
         width_oct=0.7, pan=side, spread=0.4)
    # Into the hold: a few grains settle, fine to begin, coarser as they sink.
    m.grains(lambda t: np.where(t > reach, 3500 * np.exp(-(t - reach) / 0.03), 0),
             lambda t: 0.7 - 0.25 * smooth(t, reach, reach + 0.08) + 0.04 * v,
             lambda t: side + 0 * t, amp=0.8, weight=lambda t: 0.5 + 0 * t)
    m.room(t60=0.5, wet=0.16)
    return m.finish(loudness_db=-35.0, fade_out=0.08)


def orb_pickup(v=0):
    """Star dust: a gold mote with rays, gone the frame the ship touches it
    (and the ship is a little faster for good). A pinch of gold leaf, shaken
    -- a few tiny flakes catching -- with a breath under it. Small: it is
    the pickup, not the reward."""
    m = Mix(0.32, seed=5201 + v)
    rng = np.random.default_rng(300 + v)
    m.air(0.0, 0.16, 500, 3200, amp=0.012, rise=0.25)
    flakes = 4 + v % 2
    for i in range(flakes):
        at = 0.006 + rng.uniform(0, 0.05) * (i / flakes + 0.3)
        f0 = rng.uniform(3200, 5600)
        knock(m, at, _plate(rng, f0, ring=rng.uniform(0.035, 0.07)),
              amp=0.1 * rng.uniform(0.6, 1.0), attack=0.0015, tau=0.0012,
              colour=9000, pan=rng.uniform(-0.4, 0.4))
    # The warm light of it, low under the flakes: a small dark glass, barely.
    m.glass(0.004, 690 + 40 * v, amp=0.035, ring=0.15, attack=0.012,
            brightness=0.3, beat=2.0, ratios=[1.0, 2.32, 4.25])
    m.room(t60=0.6, wet=0.2)
    return m.finish(loudness_db=-33.0, fade_out=0.1)


def orb_deposit():
    """The hold emptied into the home planet (the meter resets, the planet
    grows): the hold's matter pours out and the planet takes it -- a large
    soft body taking a weight, not a chord."""
    m = Mix(1.15, seed=5301)
    pour = lambda t: np.clip(t / 0.04, 0, 1) * (1 - smooth(t, 0.22, 0.5))
    for side in (-0.3, 0.3):
        m.grains(lambda t: 3000 * pour(t), lambda t: 0.62 - 0.32 * smooth(t, 0.0, 0.45),
                 lambda t, side=side: side * (1 - smooth(t, 0.0, 0.45)),
                 amp=1.0, weight=lambda t: 0.45 + 0.3 * pour(t))
    # The planet taking it: a heavy, soft mass landing (it leans in over
    # 60 ms -- a weight received, not a blow; dense stone modes, so it is a
    # thud of matter and never a bell), a low breath, a deep swell.
    knock(m, 0.3, _stone(m.rng, 190, count=26, ring=0.09), amp=0.22, attack=0.06,
          tau=0.05, colour=1300, width=1.0, floor=150)
    rush(m, 0.12, 0.9, lambda t: 420 - 150 * smooth(t, 0, 0.6),
         lambda t: 0.012 * smooth(t, 0, 0.25) * (1 - smooth(t, 0.3, 0.9)),
         width_oct=0.9, spread=0.9)
    rumble(m, 0.15, 0.9, lambda t: smooth(t, 0, 0.2) * (1 - smooth(t, 0.25, 0.9)),
           amp=0.015, lo=60, hi=300)
    m.room(t60=1.2, wet=0.24)
    return m.finish(loudness_db=-30.0, fade_out=0.3)


# The warp anomaly (cosmic_game.dart, POIType.warpAnomaly): on contact the
# ship is moved and _warpFlash runs 1 -> 0 at 1.2/s (0.83 s): a white flash
# for its first half (0 - 0.42 s), the speed-line tunnel from 0.33 s, fading.
WARP = 1 / 1.2


def anomaly_burst():
    """Thrown across space: the anomaly grabs the ship and flings it. A
    violent rush that peaks with the flash and streams away through the
    tunnel, space tearing as it goes -- leaned in, not a crash."""
    m = Mix(1.05, seed=5401)
    flash = WARP * 0.5
    rush(m, 0.0, WARP + 0.15,
         lambda t: np.where(t < 0.06, 700 + 2600 * smooth(t, 0, 0.06),
                            3300 * (380 / 3300) ** smooth(t, 0.06, WARP)),
         lambda t: 0.09 * smooth(t, 0, 0.03) * (1 - 0.55 * smooth(t, 0.06, flash))
         * (1 - smooth(t, flash, WARP + 0.12)),
         width_oct=1.0, spread=0.95, flutter=0.25)
    # Space tearing: dense friction, fast while the flash holds.
    tear = lambda t: smooth(t, 0.0, 0.025) * (1 - smooth(t, 0.05, flash + 0.05))
    grind(m, 0.0, flash + 0.1, tear, _stone(m.rng, 900, count=14, ring=0.03),
          amp=0.22, rate=(300, 1400), jitter=0.6, slide=0.4, colour=7000, width=0.9)
    # The weight of it: displaced air under the flash.
    rumble(m, 0.0, WARP, lambda t: smooth(t, 0, 0.03) * (1 - smooth(t, 0.05, WARP)),
           amp=0.03, lo=50, hi=260)
    m.room(t60=1.1, wet=0.24)
    return m.finish(loudness_db=-30.0, fade_out=0.2)


# Portal open is the way opening, wherever it does: a rift's threshold
# taken in, the wild tear (opens over _tearOpenSeconds 0.95), the Nexus
# pocket, the glyph portal down to the home biome, the Mystic Altar's heart
# tearing into the arcane rift. All open in about a second and then hold.
PORTAL_OPEN = 0.95


def portal_open():
    """Space folding inward and opening: drawn in -- air, a strain deep in
    it, grains spiralling to a point -- and at 0.95 s it gives, and the
    pressure goes out of it into the dark."""
    m = Mix(2.1, seed=5501)
    o = PORTAL_OPEN
    draw = lambda t: (0.15 + 0.85 * smooth(t, 0.0, o) ** 1.4) * smooth(t, 0, 0.06) \
        * (1 - smooth(t, o, o + 0.05))
    # Drawn in: a thin high hiss sinking as it is pulled to a point.
    rush(m, 0.0, o + 0.08, lambda t: 4200 * (1100 / 4200) ** smooth(t, 0, o),
         lambda t: 0.022 * draw(t), width_oct=0.7,
         pan=lambda t: 0.25 * np.sin(2 * math.pi * 1.4 * t ** 1.5),
         spread=0.4, flutter=0.15)
    # Grains drawn in on a tightening spiral.
    m.grains(lambda t: 3200 * draw(t) * (t < o + 0.04),
             lambda t: 0.8 - 0.4 * smooth(t, 0, o),
             lambda t: 0.7 * (1 - smooth(t, 0, o)) * np.sin(2 * math.pi * (0.8 * t + 1.1 * t ** 2)),
             amp=1.0, weight=lambda t: 0.4 + 0.35 * draw(t))
    # The strain: something very large turning against itself.
    grind(m, 0.15, o - 0.1, lambda t: smooth(t, 0, o - 0.3) * (1 - smooth(t, o - 0.2, o - 0.12)),
          _stone(m.rng, 120, count=18, ring=0.2), amp=0.25, rate=(9, 30),
          jitter=0.35, colour=2200, floor=160)
    # It gives: the pressure goes out of it, low and wide -- a different air
    # from the hiss that drew it in, and a deep glass under it.
    rush(m, o - 0.02, 1.1, lambda t: 520 - 300 * smooth(t, 0, 1.0),
         lambda t: 0.035 * smooth(t, 0, 0.04) * (1 - smooth(t, 0.04, 1.1)),
         width_oct=1.0, spread=1.0)
    rumble(m, o - 0.03, 1.1, lambda t: smooth(t, 0, 0.05) * (1 - smooth(t, 0.06, 1.1)),
           amp=0.025, lo=40, hi=260)
    m.glass(o - 0.03, 294, amp=0.12, ring=1.4, attack=0.07, brightness=0.25,
            beat=0.7, ratios=[1.0, 2.32, 4.25])
    m.room(t60=1.6, wet=0.28)
    return m.finish(loudness_db=-29.0, fade_out=0.35)


def starforge_activate():
    """A planet's gate unsealed: the offering is taken out of the meter
    (it resets on this frame) and an ancient gate in the planet turns and
    seats. Poured in, a heavy stone mechanism catching and turning, a seat
    that leans in, then the gate stands open, humming deep."""
    m = Mix(2.8, seed=5601)
    # The offering, poured in (0 - 0.5 s).
    m.grains(lambda t: 3200 * np.clip(t / 0.04, 0, 1) * (1 - smooth(t, 0.25, 0.55)),
             lambda t: 0.6 - 0.3 * smooth(t, 0, 0.5),
             lambda t: 0.35 * (1 - smooth(t, 0, 0.5)) * np.sin(2 * math.pi * 1.2 * t),
             amp=1.0, weight=lambda t: 0.45 + 0 * t)
    # The mechanism: creeps (sparse catches), turns, slows to the seat.
    seat = 1.58
    # (Grind time runs from 0.3 s: the seat is at seat - 0.3 in it.)
    turn = lambda t: (0.35 * smooth(t, 0.0, 0.3) + 0.65 * smooth(t, 0.3, 0.6)) \
        * (1 - 0.65 * smooth(t, seat - 0.3 - 0.6, seat - 0.3)) * (t < seat - 0.3)
    body = _stone(m.rng, 170, count=22, ring=0.1)
    grind(m, 0.3, seat - 0.3 + 0.05, turn, body, amp=0.22, rate=(6, 34),
          jitter=0.35, slide=0.25, colour=3200, width=0.5, floor=160)
    # The seat: stone set on stone, pressing in over 30 ms.
    knock(m, seat, _stone(m.rng, 150, count=24, ring=0.3), amp=0.17,
          attack=0.03, tau=0.025, colour=2000, width=1.0, floor=170)
    m.grains(lambda t: np.where(t > seat + 0.02, 2000 * np.exp(-(t - seat - 0.02) / 0.18), 0),
             lambda t: 0.3 + 0 * t, lambda t: 0.2 * np.sin(9 * t), amp=1.0,
             weight=lambda t: 0.45 + 0 * t)
    # Open: the deep of the planet breathing out through it.
    rumble(m, seat - 0.05, 1.3, lambda t: smooth(t, 0, 0.12) * (1 - smooth(t, 0.2, 1.3)),
           amp=0.018, lo=45, hi=280)
    rush(m, seat, 1.2, lambda t: 650 - 250 * smooth(t, 0, 1.0),
         lambda t: 0.01 * smooth(t, 0, 0.1) * (1 - smooth(t, 0.15, 1.2)),
         width_oct=1.0, spread=1.0)
    m.glass(seat + 0.02, 262, amp=0.14, ring=1.6, attack=0.25, brightness=0.3,
            beat=0.6, ratios=[1.0, 2.32, 4.25])
    m.room(t60=1.7, wet=0.27)
    return m.finish(loudness_db=-28.5, fade_out=0.4)


# The elemental cache's unsealing (cosmic_cache_vfx.dart paintCacheUnseal,
# cosmic_game_caches.dart). ElementalCache.openDuration is 3 s; in seconds:
#   0    - 1.05  charge: the companion circles (two turns in 3 s), feeding
#                the seal; its element streams in from the ring
#   0.9  - 2.25  crack: the two near-black glass halves part (easeOutCubic:
#                fastest at 0.9); the six seal shards spin up (5 t^2) and
#                fly out (radius 120 crack^2: fastest as they go, ~2.2 s)
#   0    - 3     the element pours out of the seam as grains
#   2.1  - 3.0   bloom: light opening out of the seam
#   3.0          _finishCacheUnseal: 34 motes thrown out (half of them gold)
#                and two shock rings; the reward card follows
# The cue now plays on the tap that starts the ritual (it used to play
# portal-open there and this at 3 s), so the whole ritual is scored.
CACHE = 3.0


def cache_open():
    """Unsealing an elemental cache, start to finish: its element streams
    in, the dark glass halves grind apart, the seal's shards whirl up and
    fly loose, light opens out of the seam -- and the cache gives."""
    m = Mix(CACHE + 0.9, seed=5701)
    tau = lambda t: np.clip(t / CACHE, 0, 1)
    orbit = lambda t: np.cos(4 * math.pi * tau(t))
    charge = lambda t: np.clip(t / 1.05, 0, 1)
    crack = lambda t: np.clip((t - 0.9) / 1.35, 0, 1)
    bloom = lambda t: np.clip((t - 2.1) / 0.9, 0, 1)
    live = lambda t: (t < CACHE).astype(float)
    # The element streaming in from the circling companion.
    m.grains(lambda t: 1400 * smooth(t, 0, 0.3) * (1 - 0.6 * crack(t)) * live(t),
             lambda t: 0.72 + 0 * t, lambda t: 0.55 * orbit(t), amp=1.0,
             weight=lambda t: 0.4 + 0.2 * charge(t))
    # ...and pouring out of the seam, wider as it opens.
    energy = lambda t: np.clip(t / 0.75, 0, 1) * (1 - 0.7 * _ease_out_cubic(bloom(t)))
    for side in (-1.0, 1.0):
        m.grains(lambda t: 1000 * energy(t) * live(t), lambda t: 0.5 + 0.15 * crack(t),
                 lambda t, side=side: side * (0.1 + 0.5 * crack(t)), amp=1.0,
                 weight=lambda t: 0.4 + 0.25 * energy(t))
    # The seam's glow under it all: a dark glass, stroked.
    m.glass(0.05, 349, amp=0.08, ring=2.2, attack=0.8, brightness=0.2,
            beat=1.1, ratios=[1.0, 2.32, 4.25])
    # The halves parting: glass on glass, fastest as the crack starts.
    part_speed = lambda t: 3 * (1 - crack(t)) ** 2 * (crack(t) > 0) / 3 \
        * smooth(t, 0.9, 0.96)
    grind(m, 0.85, 1.45, lambda t: part_speed(t + 0.85),
          _dark_glass(m.rng, 820, ring=0.045), amp=0.07, rate=(12, 70),
          jitter=0.4, slide=0.3, colour=5000, width=0.7, floor=250)
    # The seal's shards whirling up: air cut by six blades, their pass rate
    # rising with the spin, gone as they fly.
    spin = lambda t: 10 * tau(t) / CACHE * 6 / (2 * math.pi)
    whirl = lambda t: (1 - crack(t)) * smooth(t, 0.4, 1.2)
    rush(m, 0.4, 1.9,
         lambda t: 1300 + 900 * crack(t + 0.4),
         lambda t: 0.02 * whirl(t + 0.4)
         * (0.55 + 0.45 * np.cos(2 * math.pi * np.cumsum(spin(t + 0.4)) / SR)),
         width_oct=0.7, pan=lambda t: 0.45 * np.sin(2 * math.pi * np.cumsum(spin(t + 0.4) / 6) / SR),
         spread=0.5)
    # Flung loose: each shard a small flick of air going out.
    rng = np.random.default_rng(57)
    for i in range(6):
        at = 1.85 + 0.05 * i + rng.uniform(0, 0.04)
        rush(m, at, 0.22, lambda t: 2400 - 1200 * smooth(t, 0, 0.2),
             lambda t: 0.012 * smooth(t, 0, 0.03) * (1 - smooth(t, 0.04, 0.22)),
             width_oct=0.6, pan=math.cos(i * math.pi / 3) * 0.8, spread=0.2)
    # Bloom: light opening -- a breath swelling to the give.
    rush(m, 2.0, 1.05, lambda t: 500 + 900 * smooth(t, 0, 1.0),
         lambda t: 0.018 * smooth(t, 0, 0.98) ** 2 * (1 - smooth(t, 0.98, 1.04)),
         width_oct=1.0, spread=0.9)
    # It gives: thrown out (leaning in over 30 ms), half of it gold.
    burst = lambda t: np.where(t > CACHE, np.clip((t - CACHE) / 0.03, 0, 1)
                               * np.exp(-np.maximum(t - CACHE, 0) / 0.22), 0)
    for side in (-0.8, 0.0, 0.8):
        m.grains(lambda t: 1600 * burst(t), lambda t: 0.7 + 0 * t,
                 lambda t, side=side: side * (0.5 + 0.5 * smooth(t, CACHE, CACHE + 0.4)),
                 amp=1.0, weight=lambda t: 0.5 + 0.3 * burst(t))
    rush(m, CACHE - 0.01, 0.75, lambda t: 1100 - 600 * smooth(t, 0, 0.7),
         lambda t: 0.025 * smooth(t, 0, 0.03) * (1 - smooth(t, 0.03, 0.75)),
         width_oct=1.0, spread=1.0)
    for i in range(7):
        at = CACHE + 0.02 + rng.uniform(0, 0.25)
        knock(m, at, _plate(rng, rng.uniform(2600, 4800), ring=0.09),
              amp=0.15 * rng.uniform(0.5, 1), attack=0.002, tau=0.0015,
              colour=9000, pan=rng.uniform(-0.8, 0.8))
    m.glass(CACHE - 0.02, 311, amp=0.11, ring=1.2, attack=0.06, brightness=0.3,
            beat=1.2)
    m.room(t60=1.3, wet=0.25)
    return m.finish(loudness_db=-28.0, fade_out=0.4)


def discovery():
    """Something new in the dark: a place found in space, or a star seen in
    the Ice dungeon's pool. Not a chime -- a widening: the air opens out, a
    few far glints come into focus across the field, and a low glass swells
    under it."""
    m = Mix(1.7, seed=5801)
    rush(m, 0.0, 1.5, lambda t: 700 + 900 * smooth(t, 0, 0.7),
         lambda t: 0.01 * smooth(t, 0, 0.45) * (1 - smooth(t, 0.55, 1.5)),
         width_oct=1.2, spread=1.0,
         pan=0.0)
    rumble(m, 0.0, 1.5, lambda t: smooth(t, 0, 0.4) * (1 - smooth(t, 0.4, 1.5)),
           amp=0.012, lo=50, hi=260, spread=1.0)
    # Far glints, sparse, spreading from the middle out across the field.
    for side in (-1.0, 1.0):
        m.grains(lambda t: 380 * smooth(t, 0.1, 0.5) * (1 - smooth(t, 0.7, 1.35)),
                 lambda t: 0.93 + 0 * t,
                 lambda t, side=side: side * (0.1 + 0.8 * smooth(t, 0.1, 1.1)),
                 amp=1.2, weight=lambda t: 0.5 + 0 * t)
    m.glass(0.08, 392, amp=0.2, ring=1.5, attack=0.35, brightness=0.25,
            beat=1.0, ratios=[1.0, 2.32, 4.25, 6.63])
    m.room(t60=1.8, wet=0.3)
    return m.finish(loudness_db=-31.0, fade_out=0.35)


def scan():
    """A scanner station locks on: its glass lenses spin up round the
    obsidian core and the needle swings to the target and settles; a fan of
    motes sweeps the dark. A pivot turning, a seat, a sweep."""
    m = Mix(0.95, seed=5901)
    settle = 0.52
    # The pivot: glass on stone, spinning up, swinging, slowing into place.
    speed = lambda t: smooth(t, 0.0, 0.12) * (1 - smooth(t, 0.3, settle - 0.01)) \
        + 0.25 * np.exp(-((t - settle - 0.05) / 0.03) ** 2)
    grind(m, 0.0, settle + 0.15, speed, _stone(m.rng, 420, count=20, ring=0.05),
          amp=0.07, rate=(20, 110), jitter=0.25, slide=0.35, colour=6000, width=0.5)
    knock(m, settle, _stone(m.rng, 380, count=14, ring=0.06), amp=0.13,
          attack=0.008, tau=0.004, colour=4000, floor=250)
    # The sweep: a fan of motes crossing left to right.
    m.grains(lambda t: 1000 * smooth(t, 0.08, 0.2) * (1 - smooth(t, 0.45, 0.7)),
             lambda t: 0.85 + 0 * t, lambda t: -0.8 + 1.6 * smooth(t, 0.08, 0.7),
             amp=1.0, weight=lambda t: 0.4 + 0 * t)
    rush(m, 0.06, 0.66, lambda t: 1600 + 1000 * smooth(t, 0, 0.5),
         lambda t: 0.007 * smooth(t, 0, 0.15) * (1 - smooth(t, 0.35, 0.66)),
         width_oct=0.7, pan=lambda t: -0.8 + 1.6 * smooth(t, 0.02, 0.64), spread=0.3)
    m.room(t60=0.9, wet=0.22)
    return m.finish(loudness_db=-31.0, fade_out=0.25)


# The ship's booster. _startBoosting plays the kick on the press; the held
# thrust (amb_cosmic_boost_loop) starts under it when the game reports the
# boost engaging, and is cut when it stops.
_HULL_F0 = 182


def dash():
    """The booster catching: gas lit -- a chuff that leans in over 20 ms,
    flame tearing up out of it, the ship pushed forward -- settling into
    the held thrust that starts underneath."""
    m = Mix(0.5, seed=6001)
    roar(m, 0.0, 0.45,
         lambda t: smooth(t, 0, 0.02) * (0.45 + 0.55 * np.exp(-np.maximum(t - 0.02, 0) / 0.07))
         * (1 - smooth(t, 0.2, 0.45)),
         amp=0.07, body_lo=110, body_hi=1100, rasp=0.7, crackle=60, hiss=0.2,
         hull=_dark_glass(m.rng, _HULL_F0, ring=0.4))
    # The push: air torn past the hull as it lunges.
    rush(m, 0.0, 0.42, lambda t: 900 + 2200 * smooth(t, 0, 0.05) - 1500 * smooth(t, 0.05, 0.4),
         lambda t: 0.045 * smooth(t, 0, 0.025) * (1 - smooth(t, 0.04, 0.42)),
         width_oct=0.9, spread=0.8)
    m.room(t60=0.7, wet=0.18)
    return m.finish(loudness_db=-30.0, fade_out=0.12)


BOOST_LOOP = 5.0
_XFADE = 1.5


def boost_loop():
    """The booster held: a physical thrust -- turbulent combustion roar,
    the flame's flutter, crackle, exhaust hiss, the dark-glass hull shaken
    under it. Nothing in it is periodic, so 5 s never sounds like a loop."""
    m = Mix(BOOST_LOOP + _XFADE, seed=6101)
    roar(m, 0.0, BOOST_LOOP + _XFADE, lambda t: 1 + 0 * t, amp=0.06,
         body_lo=90, body_hi=950, rasp=0.5, crackle=26, hiss=0.15,
         hull=_dark_glass(m.rng, _HULL_F0, ring=0.45))
    # The wake going past: a slow-moving breath of air.
    rush(m, 0.0, BOOST_LOOP + _XFADE, lambda t: 1300 + 500 * np.sin(2 * math.pi * 0.31 * t),
         lambda t: 0.03 + 0 * t, width_oct=1.0, spread=1.0, flutter=0.3)
    m.room(t60=0.6, wet=0.12)
    y = m.finish(loudness_db=-33.0, fade_out=0)
    return seamless_loop(y, _XFADE)


SPACE_LOOP = 30.0


def space_loop():
    """The open cosmos, behind the music: vast and dark. A deep slow tide
    of air, a far higher hush that comes and goes, and now and then
    something far off -- dust drifting past, a groan of something enormous
    turning a long way away, the hull ticking as it cools. Mostly silence."""
    total = SPACE_LOOP + _XFADE
    m = Mix(total, seed=6201)
    rng = np.random.default_rng(62)
    rumble(m, 0.0, total, lambda t: 1 + 0 * t, amp=0.035, lo=35, hi=160,
           spread=1.0, drift_hz=0.25)
    tide = lambda t: 0.6 + 0.4 * np.sin(2 * math.pi * t / 15.75 + 0.7) ** 2
    rush(m, 0.0, total, lambda t: 520 + 180 * np.sin(2 * math.pi * t / 10.5),
         lambda t: 0.013 * tide(t), width_oct=1.1, spread=1.0, flutter=0.35)
    # Dust drifting past, far: thin streams crossing the field.
    for at, length, a, b in ((3.2, 3.5, -0.9, 0.4), (14.5, 4.0, 0.8, -0.5),
                             (23.5, 3.2, -0.3, 0.9)):
        m.grains(lambda t, at=at, length=length: np.where(
                     (t > at) & (t < at + length),
                     220 * np.sin(math.pi * np.clip((t - at) / length, 0, 1)) ** 2, 0),
                 lambda t: 0.8 + 0 * t,
                 lambda t, at=at, length=length, a=a, b=b: a + (b - a) * np.clip((t - at) / length, 0, 1),
                 amp=2.0, weight=lambda t: 0.35 + 0 * t)
    # Something enormous, a long way off, turning.
    for at, length, f0, pan in ((8.0, 4.5, 55, -0.5), (19.5, 5.0, 48, 0.6)):
        grind(m, at, length, lambda t, length=length: np.sin(math.pi * np.clip(t / length, 0, 1)) ** 2,
              _stone(rng, f0 * 2.5, count=16, ring=0.4), amp=0.1, rate=(3, 9),
              jitter=0.4, slide=0.3, colour=700, pan=pan, width=0.8)
    # The hull ticking as it cools, close and tiny.
    for at in (6.1, 6.45, 17.3, 26.8):
        knock(m, at, _dark_glass(rng, rng.uniform(900, 1300), ring=0.08),
              amp=0.05, attack=0.002, tau=0.001, colour=6000,
              pan=rng.uniform(-0.5, 0.5))
    m.room(t60=3.2, wet=0.35, darkness=2600)
    y = m.finish(loudness_db=-42.0, fade_out=0)
    return seamless_loop(y, _XFADE)


# The glyph portal down into a planet (planet_dungeon_portal.dart, played
# in PlanetDungeonScreen.initState with the descent's ticker):
#   0   - 0.6   the cipher glyphs gather out of the void, ring by ring
#   0   - 1.7   the camera eases from a drift (0.9/s) into a rush (3.2/s);
#               six rings of script 0.92 apart rush past it
#   1.7 - 2.2   the dungeon fades in under it
PORTAL_SECONDS = 1.7
_RING_GAP = 5.5 / 6


def _travel(t):
    v0, v1, T = 0.9, 3.2, PORTAL_SECONDS
    return np.where(t <= T, v0 * t + (v1 - v0) * t * t / (2 * T),
                    v0 * T + (v1 - v0) * T / 2 + v1 * (t - T))


def planet_enter():
    """Descending into a planet through the glyph portal: script written
    out of the void (quill on parchment, gathering), then the tunnel -- air
    rushing faster and faster, each ring of glyphs passing like a gust --
    and at the fade the rush lets go into the deep of the dungeon."""
    m = Mix(2.6, seed=6301)
    T = PORTAL_SECONDS
    scratch(m, 0.0, 0.9, lambda t: 70 * smooth(t, 0, 0.15) * (1 - smooth(t, 0.4, 0.85)),
            amp=0.25, pan_spread=0.8)
    speed = lambda t: (0.9 + 2.3 * np.clip(t / T, 0, 1)) / 3.2
    # A ring passes each time the camera travels one gap.
    def gust(t):
        ph = _travel(t) / _RING_GAP - 0.5
        d = (ph - np.round(ph)) * _RING_GAP
        return np.exp(-(d / 0.16) ** 2)
    let_go = lambda t: 1 - smooth(t, T + 0.05, T + 0.55)
    rush(m, 0.05, 2.3,
         lambda t: 380 + 1000 * speed(t + 0.05) ** 1.5 + 500 * gust(t + 0.05),
         lambda t: 0.05 * smooth(t, 0, 0.35) * speed(t + 0.05) ** 1.2
         * (0.6 + 0.4 * gust(t + 0.05)) * let_go(t + 0.05),
         width_oct=0.9, spread=0.85, flutter=0.15)
    # The script itself, faint, as it streams past.
    m.grains(lambda t: 700 * gust(t) * smooth(t, 0.3, 0.9) * let_go(t),
             lambda t: 0.6 + 0 * t, lambda t: 0.7 * np.sin(2 * math.pi * 0.6 * t),
             amp=1.2, weight=lambda t: 0.4 + 0 * t)
    # Down: the dungeon's deep, breathing out, and its stone answering.
    rumble(m, T - 0.2, 0.9, lambda t: smooth(t, 0, 0.25) * (1 - smooth(t, 0.3, 0.9)),
           amp=0.025, lo=40, hi=250)
    rush(m, T, 0.85, lambda t: 420 - 150 * smooth(t, 0, 0.8),
         lambda t: 0.025 * smooth(t, 0, 0.12) * (1 - smooth(t, 0.12, 0.85)),
         width_oct=1.0, spread=1.0)
    m.room(t60=1.9, wet=0.3, darkness=3200)
    return m.finish(loudness_db=-29.0, fade_out=0.35)


# The companion gathering out of grains of itself (grain_assembly.dart,
# drawn by cosmic_game.dart over summonDur 0.9 s): each grain sets off at
# 0.45 rise + 0.2 random of the way through (feet first, crown last), flies
# 0.38 of it on an ease-out swirl from up to two body-widths out -- hot with
# its element, cooling as it lands -- and the sprite is back at 0.8 - 0.98.
SUMMON = 0.9


def _summon_motion(t, n=900, seed=19):
    rng = np.random.default_rng(seed)
    rise = rng.random(n)
    start = np.clip(0.45 * rise + 0.2 * rng.random(n), 0, 0.62)
    r0 = 1.2 + 1.3 * np.sqrt(rng.random(n))
    u = t / SUMMON
    v = np.clip((u[None, :] - start[:, None]) / 0.38, 0, 1)
    flying = (v > 0) & (v < 1)
    speed = np.sum(flying * 3 * (1 - v) ** 2 * r0[:, None], axis=0)
    landed = np.sum(v >= 1, axis=0).astype(float)
    landing = np.gradient(landed, t)
    return speed / speed.max(), landing / landing.max()


def creature_summon():
    """A companion summoned: its grains swirl in from round where it will
    stand, fast as they leave and easing as they land, feet first, hot and
    cooling -- and it is whole."""
    m = Mix(SUMMON + 0.45, seed=6401)
    grid = np.arange(0, m.n / SR + 0.004, 0.002)
    speed, landing = _summon_motion(grid)

    def at(curve):
        return lambda t: np.interp(t, grid, curve)

    for side in (-1.0, 1.0):
        m.grains(at(1300 * speed), lambda t: 0.85 - 0.25 * smooth(t, 0.1, SUMMON),
                 lambda t, side=side: side * 0.5 * (1 - smooth(t, 0, SUMMON))
                 * np.sin(2 * math.pi * 1.3 * t + (side > 0) * math.pi),
                 amp=0.5, weight=at(0.4 + 0.35 * speed))
    m.grains(at(1100 * landing), lambda t: 0.4 + 0 * t,
             lambda t: 0.15 * np.sin(2 * math.pi * 0.9 * t), amp=0.5,
             weight=at(0.45 + 0.3 * landing))
    # Its element's light where it gathers (sin(pi u)): a breath, no more.
    m.air(0.0, SUMMON, 300, 2200, amp=0.01, rise=0.5)
    m.room(t60=1.0, wet=0.22)
    return m.finish(loudness_db=-31.0, fade_out=0.3)


# ===========================================================================
# Cosmic Survival -- the waves and the meta moments around the fighting
# (cosmic_survival_screen.dart, cosmic_survival_game.dart)
# ===========================================================================
#
# The arena is a dark field round the orb; the horde spawns outside its rim
# and comes in. Enemies and bosses are near-black obsidian solids lit only by
# their own light. None of these moments is a fanfare or an alarm: they are
# pressure arriving and pressure lifting.


def wave_start():
    """A wave begins (the plate shows at once; the horde forms beyond the
    rim and comes in). A far mass gathering: pressure leaning in, a low
    swell, a distant clatter of many dark bodies."""
    m = Mix(1.35, seed=7101)
    rng = np.random.default_rng(71)
    rumble(m, 0.0, 1.3, lambda t: smooth(t, 0, 0.6) * (1 - smooth(t, 0.75, 1.3)),
           amp=0.025, lo=40, hi=260, spread=1.0)
    rush(m, 0.0, 1.25, lambda t: 300 + 500 * smooth(t, 0, 0.7),
         lambda t: 0.014 * smooth(t, 0, 0.7) * (1 - smooth(t, 0.8, 1.25)),
         width_oct=1.0, spread=1.0, flutter=0.3)
    # Far bodies, many, rattling in from all round: small stone knocks, dim.
    for i in range(26):
        at = 0.15 + 0.85 * rng.random() ** 0.7
        knock(m, at, _stone(rng, rng.uniform(300, 700), count=10, ring=0.04),
              amp=0.15 * rng.uniform(0.4, 1.0) * float(smooth(np.array(at), 0.1, 0.6)),
              attack=0.006, tau=0.004, colour=2200, pan=rng.uniform(-0.95, 0.95))
    m.room(t60=1.6, wet=0.32, darkness=2400)
    return m.finish(loudness_db=-31.0, fade_out=0.3)


def wave_clear():
    """The last of a wave falls and the intermission opens: the pressure
    lifts. Air let out, the dust of it settling, the low swell going."""
    m = Mix(1.2, seed=7201)
    rush(m, 0.0, 1.05, lambda t: 1500 * (380 / 1500) ** smooth(t, 0, 0.9),
         lambda t: 0.025 * smooth(t, 0, 0.04) * (1 - smooth(t, 0.05, 1.05)),
         width_oct=1.0, spread=1.0)
    rumble(m, 0.0, 0.9, lambda t: smooth(t, 0, 0.04) * (1 - smooth(t, 0.04, 0.9)),
           amp=0.018, lo=45, hi=260)
    m.grains(lambda t: np.where(t > 0.05, 1500 * np.exp(-(t - 0.05) / 0.3), 0),
             lambda t: 0.45 - 0.2 * smooth(t, 0.05, 0.8),
             lambda t: 0.6 * np.sin(2 * math.pi * 0.7 * t), amp=1.0,
             weight=lambda t: 0.4 + 0 * t)
    m.room(t60=1.3, wet=0.28)
    return m.finish(loudness_db=-31.0, fade_out=0.3)


def milestone():
    """Wave 50 broken (its reward dialog follows): the same lift, but the
    arena opening out into something vast -- a heavy settle that presses
    in, a long exhale, dust coming down, a deep glass under it all."""
    m = Mix(2.4, seed=7301)
    knock(m, 0.04, _stone(m.rng, 120, count=24, ring=0.45), amp=0.3,
          attack=0.035, tau=0.03, colour=1800, width=1.0)
    rush(m, 0.0, 2.0, lambda t: 1300 * (300 / 1300) ** smooth(t, 0, 1.8),
         lambda t: 0.022 * smooth(t, 0, 0.08) * (1 - smooth(t, 0.1, 2.0)),
         width_oct=1.1, spread=1.0)
    rumble(m, 0.0, 1.9, lambda t: smooth(t, 0, 0.06) * (1 - smooth(t, 0.1, 1.9)),
           amp=0.02, lo=40, hi=260)
    for side in (-0.6, 0.6):
        m.grains(lambda t: 1500 * smooth(t, 0.15, 0.4) * (1 - smooth(t, 0.6, 1.6)),
                 lambda t: 0.5 - 0.25 * smooth(t, 0.2, 1.5),
                 lambda t, side=side: side + 0 * t, amp=1.0,
                 weight=lambda t: 0.4 + 0 * t)
    m.glass(0.12, 262, amp=0.1, ring=2.2, attack=0.4, brightness=0.3,
            beat=0.5, ratios=[1.0, 2.32, 4.25])
    m.room(t60=2.4, wet=0.34, darkness=3000)
    return m.finish(loudness_db=-29.0, fade_out=0.5)


# A boss arrives (_beginBossEntrance): a detonation burst at its station on
# the frame it spawns, and it glides in from 220 - 520 px out over 0.78 -
# 2.05 s, most of them easing out (fast, then settling). The dungeon's
# guardian wakes to the same cue.
BOSS_SETTLE = 1.2


def boss_arrive():
    """Something enormous arrives: space ruptured where it will stand
    (pressure leaning in, torn), a great dark mass of obsidian driven in
    through it, groaning, and settling with a weight that presses the
    field down. No alarm, no hit."""
    m = Mix(2.6, seed=7401)
    # The rupture: displaced air leaning in over 40 ms, torn at its edge.
    rumble(m, 0.0, 1.6, lambda t: smooth(t, 0, 0.04) * (0.55 + 0.45 * np.exp(-t / 0.25))
           * (1 - smooth(t, 0.6, 1.6)), amp=0.035, lo=35, hi=240)
    rush(m, 0.0, 0.7, lambda t: 1200 - 800 * smooth(t, 0, 0.6),
         lambda t: 0.022 * smooth(t, 0, 0.04) * (1 - smooth(t, 0.05, 0.7)),
         width_oct=1.1, spread=1.0, flutter=0.3)
    grind(m, 0.0, 0.5, lambda t: smooth(t, 0, 0.04) * (1 - smooth(t, 0.04, 0.45)),
          _stone(m.rng, 260, count=16, ring=0.05), amp=0.2, rate=(200, 700),
          jitter=0.6, slide=0.4, colour=3500, width=0.9)
    # Its mass driven in: a low rush closing, and its body groaning as it
    # moves (slow stick-slip through a huge stone).
    glide = lambda t: smooth(t, 0.0, 0.15) * (1 - 0.7 * smooth(t, 0.4, BOSS_SETTLE)) \
        * (t < BOSS_SETTLE)
    rush(m, 0.05, BOSS_SETTLE, lambda t: 500 - 250 * smooth(t, 0, BOSS_SETTLE),
         lambda t: 0.018 * smooth(t, 0.0, 0.1) * (1 - smooth(t, 0.35, BOSS_SETTLE - 0.05)),
         width_oct=0.9, spread=0.7,
         pan=lambda t: -0.3 + 0.3 * smooth(t, 0, BOSS_SETTLE))
    grind(m, 0.1, BOSS_SETTLE, lambda t: glide(t + 0.1),
          _stone(m.rng, 80, count=22, ring=0.3), amp=0.5, rate=(7, 18),
          jitter=0.3, slide=0.3, colour=2000, width=0.6, floor=150)
    # Settled: weight pressing in over 40 ms, and the field holding it.
    knock(m, BOSS_SETTLE, _stone(m.rng, 90, count=26, ring=0.5), amp=0.35,
          attack=0.04, tau=0.04, colour=1600, width=1.0)
    rumble(m, BOSS_SETTLE - 0.02, 1.35, lambda t: smooth(t, 0, 0.05) * (1 - smooth(t, 0.05, 1.35)),
           amp=0.02, lo=35, hi=240)
    m.room(t60=2.2, wet=0.32, darkness=2600)
    return m.finish(loudness_db=-28.0, fade_out=0.45)


def outbreak():
    """An outbreak takes the arena (waves 20/30/40/50): cysts, molds and
    blights grow at one to three anchors round the orb. Not an alarm -- a
    growth: flesh stretching, something wet bubbling up inside it, spores
    puffed out at each anchor."""
    m = Mix(1.55, seed=7501)
    # Stretching: a slow wet creak through a soft low body.
    grind(m, 0.0, 0.8, lambda t: smooth(t, 0, 0.3) * (1 - smooth(t, 0.4, 0.8)),
          _stone(m.rng, 220, count=14, ring=0.05), amp=0.3, rate=(14, 40),
          jitter=0.5, slide=0.6, colour=1800, width=0.5)
    bubbles(m, 0.1, 1.2, lambda t: 90 * smooth(t, 0, 0.25) * (1 - smooth(t, 0.4, 1.15)),
            lambda t: 0.75 - 0.35 * smooth(t, 0.0, 1.0), amp=0.07,
            pan=lambda t: np.sin(5 * t) * 0.4, spread=0.4)
    for i, (at, pan) in enumerate(((0.32, -0.6), (0.5, 0.0), (0.68, 0.6))):
        rush(m, at, 0.4, lambda t: 1600 - 700 * smooth(t, 0, 0.35),
             lambda t: 0.02 * smooth(t, 0, 0.04) * (1 - smooth(t, 0.05, 0.4)),
             width_oct=0.8, pan=pan, spread=0.3)
    rumble(m, 0.0, 1.3, lambda t: smooth(t, 0, 0.3) * (1 - smooth(t, 0.4, 1.3)),
           amp=0.035, lo=50, hi=200)
    m.room(t60=1.2, wet=0.26)
    return m.finish(loudness_db=-30.0, fade_out=0.3)


def powerup_collect():
    """The alchemical meter is full and surges (the game pauses for the
    draft): a hot surge filling a vessel to the brim -- air and matter
    rushing in -- and the dark glass core of it taking the charge."""
    m = Mix(0.75, seed=7601)
    full = 0.3
    rush(m, 0.0, full + 0.35, lambda t: 500 + 1500 * smooth(t, 0, full),
         lambda t: 0.02 * smooth(t, 0, full) ** 1.5 * (1 - smooth(t, full, full + 0.35)),
         width_oct=0.9, spread=0.7)
    m.grains(lambda t: 3000 * smooth(t, 0.02, full) * (t < full + 0.02),
             lambda t: 0.5 + 0.3 * smooth(t, 0, full), lambda t: 0.2 * np.sin(14 * t),
             amp=1.2, weight=lambda t: 0.45 + 0.25 * smooth(t, 0, full))
    m.glass(full - 0.02, 349, amp=0.12, ring=0.8, attack=0.05, brightness=0.3,
            beat=1.4, ratios=[1.0, 2.32, 4.25])
    m.room(t60=1.0, wet=0.22)
    return m.finish(loudness_db=-31.0, fade_out=0.25)


def powerup_choose():
    """A power taken from the draft: a heavy glass stopper seated in the
    vessel (two quick contacts, glass on glass), the charge drawn in."""
    m = Mix(0.65, seed=7701)
    rush(m, 0.0, 0.2, lambda t: 800 + 900 * smooth(t, 0, 0.18),
         lambda t: 0.013 * smooth(t, 0, 0.17) * (1 - smooth(t, 0.17, 0.2)),
         width_oct=0.8, spread=0.5)
    seat = 0.18
    # (Floors at 300 Hz: a small glass seat has no weight below that, and
    # a low bump under it would read as a drum.)
    knock(m, seat, _dark_glass(m.rng, 610, ring=0.1), amp=0.08,
          attack=0.003, tau=0.002, colour=5000, floor=300)
    knock(m, seat + 0.014, _dark_glass(m.rng, 640, ring=0.13), amp=0.12,
          attack=0.004, tau=0.003, colour=4000, floor=300)
    knock(m, seat + 0.012, _stone(m.rng, 320, count=12, ring=0.05), amp=0.06,
          attack=0.004, tau=0.003, colour=2500, floor=300)
    m.room(t60=0.8, wet=0.2)
    return m.finish(loudness_db=-31.0, fade_out=0.25)


# The Mystic Altar's heart tearing into the arcane rift (mystic_altar_screen
# _openArcane, painted by altar_hub_field.dart): `arcane` climbs 0 -> 1
# linearly over 3.4 s. The heart (a disk of grains falling inward) swells by
# a quarter and spins 1 + 9 arcane^2 times faster; its glow grows with it;
# a violet flash covers everything from 0.8 to 1.0 of it (2.72 - 3.4 s),
# brightest at 0.9 (3.06 s); the card naming the rift follows at 3.4 s.
ALTAR_RUN = 3.4
ALTAR_TEAR = 0.9 * ALTAR_RUN


def altar_rift_tear():
    """The heart torn open: its grain disk spinning up and falling inward,
    the strain deepening under it, the air drawn in harder -- and at the
    flash it tears, and the pressure goes out of it into the dark while
    the card comes up."""
    m = Mix(ALTAR_RUN + 1.1, seed=6501)
    s = lambda t: np.clip(t / ALTAR_RUN, 0, 1)
    spin = lambda t: (1 + 9 * s(t) ** 2) / 10
    before = lambda t: 1 - smooth(t, ALTAR_TEAR - 0.04, ALTAR_TEAR + 0.04)
    turns = lambda t: np.cumsum(0.4 + 2.2 * spin(t)) / SR
    # The disk: grains on an orbit that quickens; pan follows the turning.
    m.grains(lambda t: (300 + 2600 * spin(t)) * smooth(t, 0, 0.4) * before(t),
             lambda t: 0.55 + 0.35 * s(t),
             lambda t: 0.6 * (1 - 0.5 * s(t)) * np.sin(2 * math.pi * turns(t)),
             amp=1.0, weight=lambda t: 0.4 + 0.35 * spin(t))
    # The strain: something very large turning against itself, harder.
    grind(m, 0.3, ALTAR_TEAR - 0.3,
          lambda t: (0.25 + 0.75 * s(t + 0.3) ** 2) * smooth(t, 0, 0.5),
          _stone(m.rng, 120, count=18, ring=0.2), amp=0.2, rate=(6, 36),
          jitter=0.35, colour=2200)
    # Drawn in: a hiss sinking as the swell tightens.
    rush(m, 0.0, ALTAR_TEAR + 0.08,
         lambda t: 3800 * (1000 / 3800) ** s(t / 0.9),
         lambda t: 0.018 * (0.2 + 0.8 * s(t) ** 2) * smooth(t, 0, 0.3) * before(t),
         width_oct=0.7, spread=0.5, flutter=0.15)
    # The tear: leaned in over 40 ms, a crackling rip, then the pressure
    # going out, low and wide, with a deep glass under it.
    tear = lambda t: smooth(t, 0, 0.04) * (1 - smooth(t, 0.05, 0.4))
    grind(m, ALTAR_TEAR - 0.04, 0.45, tear, _stone(m.rng, 900, count=14, ring=0.03),
          amp=0.16, rate=(300, 1300), jitter=0.6, slide=0.4, colour=7000, width=0.9)
    rush(m, ALTAR_TEAR - 0.04, 1.3, lambda t: 560 - 320 * smooth(t, 0, 1.2),
         lambda t: 0.035 * smooth(t, 0, 0.04) * (1 - smooth(t, 0.05, 1.3)),
         width_oct=1.0, spread=1.0)
    rumble(m, ALTAR_TEAR - 0.05, 1.3, lambda t: smooth(t, 0, 0.05) * (1 - smooth(t, 0.06, 1.3)),
           amp=0.025, lo=40, hi=260)
    m.glass(ALTAR_TEAR - 0.04, 294, amp=0.06, ring=1.6, attack=0.07,
            brightness=0.25, beat=0.7, ratios=[1.0, 2.32, 4.25])
    m.room(t60=1.7, wet=0.28)
    return m.finish(loudness_db=-28.5, fade_out=0.4)


_COSMIC = 'assets/audio/sounds/cosmic/'

# ---------------------------------------------------------------------------
# The ship's own weapons (cosmic_game.dart "ship shooting", cosmic_survival
# _fireShipAt). They used the creatures' generic launch -- an air-gun puff and
# a catch click -- which is a creature's sound, not a dark-glass ship's.
# ---------------------------------------------------------------------------

def ship_bolt(v=0):
    """The ship's gun: a bolt of light, 4 a second (8 on the machine gun),
    for as long as the trigger is held -- so it is tiny, dry and varied.
    A capacitor letting go (a tight electric crack, leaned in over 3 ms), the
    air the bolt shoves aside as it leaves, and the hull taking the recoil as
    a damped knock of its dark glass. No pew: nothing in it changes pitch."""
    m = Mix(0.16, seed=6101 + 17 * v)
    rng = m.rng
    # The discharge: a dense, capped crackle in the top of a phone's range.
    t = m.t
    env = smooth(t, 0.0, 0.003) * np.exp(-np.maximum(t - 0.003, 0) / (0.010 + 0.003 * rng.random()))
    pops = (rng.random((2, m.n)) < 9000 / SR) * np.minimum(rng.lognormal(0, 0.5, (2, m.n)), 2.0)
    crack = _band(pops, 2200, 7500, 2)
    crack = crack / (np.std(crack) + 1e-12) * env * 0.05
    m.y += crack
    # The bolt leaving: a short band of air, no tone.
    rush(m, 0.002, 0.09, lambda tt: (1500 + 400 * rng.random()) - 500 * smooth(tt, 0, 0.09),
         lambda tt: 0.03 * smooth(tt, 0, 0.004) * (1 - smooth(tt, 0.01, 0.09)),
         width_oct=0.9, spread=0.5, pan=(rng.random() - 0.5) * 0.3)
    # The hull answering: its glass, heavily damped -- a knock, not a ring.
    knock(m, 0.001, _dark_glass(rng, _HULL_F0 * (1.9 + 0.2 * rng.random()), ring=0.05),
          amp=0.03, attack=0.002, tau=0.003, colour=3000, floor=300)
    m.room(t60=0.35, wet=0.12)
    return m.finish(loudness_db=-36.0, fade_out=0.04)


def ship_missile():
    """A homing missile: a clamp lets go on the hull, the motor catches
    (a chuff leaned in over 20 ms) and it tears away ahead of the ship,
    its roar thinning as it goes."""
    m = Mix(0.8, seed=6111)
    knock(m, 0.0, _dark_glass(m.rng, _HULL_F0 * 1.4, ring=0.12), amp=0.05,
          attack=0.004, tau=0.004, colour=2500, floor=250)
    roar(m, 0.03, 0.7,
         lambda t: smooth(t, 0, 0.02) * np.exp(-np.maximum(t - 0.05, 0) / 0.22),
         amp=0.06, body_lo=180, body_hi=1400, rasp=0.8, crackle=45, hiss=0.25)
    rush(m, 0.03, 0.6, lambda t: 2400 - 1600 * smooth(t, 0, 0.6),
         lambda t: 0.04 * smooth(t, 0, 0.03) * (1 - smooth(t, 0.05, 0.6)),
         width_oct=1.0, spread=0.4)
    m.room(t60=0.8, wet=0.2)
    return m.finish(loudness_db=-32.0, fade_out=0.15)


CUES = {
    'sfx_ship_bolt': {
        'build': ship_bolt,
        'description': 'The ship\'s gun: a capacitor crack, the air the bolt shoves aside, the dark-glass hull knocked by the recoil',
        'variants': 3,
    },
    'sfx_ship_missile': (ship_missile, 'A missile: a clamp lets go on the hull, the motor catches and tears away, thinning'),
    'sfx_cosmic_matter_collect': {
        'build': matter_collect, 'variants': 3,
        'description': 'A mote of matter drawn into the hold: a short soft intake and a pinch of grains settling',
    },
    'sfx_cosmic_orb_pickup': {
        'build': orb_pickup, 'variants': 3, 'path': _COSMIC + 'sfx_cosmic_orb_pickup.wav',
        'description': 'Star dust taken: a pinch of gold leaf shaken over a breath, a little dark glass under it',
    },
    'sfx_cosmic_orb_deposit': {
        'build': orb_deposit, 'path': _COSMIC + 'sfx_cosmic_orb_deposit.wav',
        'description': 'The hold poured out into the home planet, and the planet taking the weight: a deep soft body',
    },
    'sfx_cosmic_anomaly_burst': {
        'build': anomaly_burst, 'path': _COSMIC + 'sfx_cosmic_anomaly_burst.wav',
        'description': 'Flung across space by a warp anomaly: a leaned-in rush, space tearing, streaming away through the tunnel',
    },
    'sfx_cosmic_portal_open': {
        'build': portal_open, 'path': _COSMIC + 'sfx_cosmic_portal_open.wav',
        'description': 'Space drawn in on itself -- air, a deep strain, grains spiralling -- and giving at 0.95 s into the dark',
    },
    'sfx_altar_rift_tear': (
        altar_rift_tear,
        'The Mystic Altar heart torn into the arcane rift: its grain disk spinning up over 3.4 s, tearing at the flash',
    ),
    'sfx_cosmic_starforge_activate': {
        'build': starforge_activate, 'path': _COSMIC + 'sfx_cosmic_starforge_activate.wav',
        'description': 'A planet gate unsealed: the offering poured in, an ancient stone mechanism turning and seating, the deep breathing out',
    },
    'sfx_cosmic_cache_open': (
        cache_open,
        'An elemental cache unsealed over its 3 s ritual: element streaming in, glass halves grinding apart, shards whirling loose, the give',
    ),
    'sfx_cosmic_discovery': (
        discovery,
        'Something new in the dark: the air opening out, far glints coming into focus, a low glass under it',
    ),
    'sfx_cosmic_scan': (
        scan,
        'A scanner locking on: a glass pivot spinning up and settling, a fan of motes sweeping left to right',
    ),
    'sfx_cosmic_dash': (
        dash,
        'The booster catching: a gas chuff leaning in, flame tearing up, air torn past the hull',
    ),
    'sfx_cosmic_planet_enter': (
        planet_enter,
        'Down through the glyph portal: script written out of the void, a tunnel rushing faster ring by ring, the deep of the dungeon',
    ),
    'sfx_creature_summon': (
        creature_summon,
        'A companion gathering out of its grains: a swirl in, easing as they land feet first, whole',
    ),
    'sfx_survival_wave_start': (
        wave_start,
        'A wave forming beyond the rim: pressure leaning in, a low swell, a far clatter of many dark bodies',
    ),
    'sfx_survival_wave_clear': (
        wave_clear,
        'The wave broken: the pressure let out, its dust settling, the low swell going',
    ),
    'sfx_survival_milestone': (
        milestone,
        'Wave 50 broken: a heavy settle, a long exhale into something vast, dust coming down',
    ),
    'sfx_survival_boss_arrive': (
        boss_arrive,
        'A boss arriving: space ruptured, a great obsidian mass driven in groaning, settling with a weight',
    ),
    'sfx_survival_outbreak': (
        outbreak,
        'An outbreak growing: flesh stretching, something wet bubbling up, spores puffed out at its anchors',
    ),
    'sfx_survival_powerup_collect': (
        powerup_collect,
        'The meter surging full: a hot rush filling the vessel to the brim, its dark glass core taking the charge',
    ),
    'sfx_survival_powerup_choose': (
        powerup_choose,
        'A power taken: the charge drawn in and a heavy glass stopper seated',
    ),
    'amb_cosmic_space_loop': {
        'build': space_loop, 'loop': True,
        'description': 'The open cosmos: a deep slow tide of air, a far hush, dust drifting past, something enormous turning far off',
    },
    'amb_cosmic_boost_loop': {
        'build': boost_loop, 'loop': True,
        'description': 'The booster held: turbulent combustion roar, flame flutter, crackle, exhaust hiss, the hull shaken under it',
    },
}
