"""Planet dungeons: carved-stone rooms, with leaded glass only on the puzzle
things (docs/dungeons.md §7.11, the glass-inlay art direction).

So the dungeon's sound world is stone first: slabs that grind and seat,
catches and pins that drop home, rubble, grit, water in the dark, and the
room itself answering. Glass appears only where a puzzle piece lights, and
always as a body under the stone, never as the loudest thing.

New voices, all here (core.py is shared and stays as it is):

  * _modes   -- a bank of damped resonators: the body of a struck thing
  * _knock   -- a contact (soft or hard) rung through a stone body
  * _grind   -- stone sliding on stone: stick-slip micro-slips at a rate
                that follows the speed, ringing the slab and the grit
  * _chips   -- small pieces of stone landing (rubble, grit, pebbles)
  * _bubble  -- a single bubble ringing in water (drips, wading, trickles)
  * _chamber -- early reflections off near stone walls, then the room tail

Every cue here is timed to what its screen draws; the Dart it follows is
named next to each timing constant.
"""
import math

import numpy as np
from scipy import ndimage, signal

from sounds.core import SR, Mix, seamless_loop, smooth


# ===========================================================================
# Voices
# ===========================================================================

def _put(m, start, mono, pan=0.0):
    """Adds [mono] into [m] at [start] seconds, clipped to the buffer."""
    s0 = round(start * SR)
    if s0 >= m.n or len(mono) == 0:
        return
    if s0 < 0:
        mono = mono[-s0:]
        s0 = 0
    mono = mono[: m.n - s0]
    gl = math.cos((pan + 1) * math.pi / 4)
    gr = math.sin((pan + 1) * math.pi / 4)
    m.y[0, s0:s0 + len(mono)] += gl * mono
    m.y[1, s0:s0 + len(mono)] += gr * mono


def _noise(rng, n, lo=None, hi=None, order=2):
    """Unit-RMS noise in a band (lo=None: lowpass, hi=None: highpass)."""
    x = rng.normal(0, 1, n)
    if lo is None:
        sos = signal.butter(order, hi, btype='lowpass', fs=SR, output='sos')
    elif hi is None:
        sos = signal.butter(order, lo, btype='highpass', fs=SR, output='sos')
    else:
        sos = signal.butter(order, [lo, hi], btype='bandpass', fs=SR, output='sos')
    y = signal.sosfilt(sos, x)
    return y / max(np.std(y), 1e-12)


def _drift(rng, n, rate):
    """A slow random curve (about unit spread) that changes [rate] times a
    second: the unsteadiness of anything real -- a draught, a flame, a hand."""
    k = int(n / SR * rate) + 4
    pts = rng.normal(0, 1, k)
    x = np.interp(np.arange(n) / SR * rate, np.arange(k), pts)
    sos = signal.butter(1, max(rate, 0.02), btype='lowpass', fs=SR, output='sos')
    y = signal.sosfiltfilt(sos, x)
    return y / max(np.std(y), 1e-12)


def _modes(x, freqs, t60s, gains, rng=None):
    """[x] rung through damped resonators. A unit impulse into mode k rings
    as about gains[k] * r^n * cos(nw), decaying 60 dB over t60s[k]. Zeros
    at DC and Nyquist: a slow push (a soft contact) must not leak through
    as a thump below the body's lowest mode.

    With [rng], each mode answers a hair late by its own amount (up to a
    period and a half, at most 4 ms) -- the way a real body's modes do not
    all peak on the same sample. Without it every mode starts in phase and
    a sharp excitation becomes one spike."""
    out = np.zeros_like(x)
    for f, t60, g in zip(freqs, t60s, gains):
        if f >= SR * 0.45:
            continue
        w = 2 * math.pi * f / SR
        r = math.exp(-6.9078 / (t60 * SR))
        y = signal.lfilter([g / 2, 0, -g / 2], [1, -2 * r * math.cos(w), r * r], x)
        if rng is not None:
            d = round(rng.uniform(0, min(0.004, 1.5 / f)) * SR)
            if d:
                y = np.concatenate([np.zeros(d), y[:-d]])
        out += y
    return out


def _stone(rng, lo, hi, n, ring, tilt=0.5):
    """A stone body's modes: many, inharmonic, heavily damped, the higher
    ones dying faster. Never a pitch -- stone has no note."""
    f = np.exp(rng.uniform(math.log(lo), math.log(hi), n))
    t60 = ring * (lo / f) ** 0.45 * np.exp(rng.normal(0, 0.35, n))
    g = (f / lo) ** (-tilt) * np.exp(rng.normal(0, 0.4, n))
    return f, t60, g


def _knock(m, start, lo, hi, n=24, ring=0.08, contact=0.008, hardness=3000,
           grit=0.35, amp=1.0, pan=0.0, tilt=0.5, rng=None):
    """Two surfaces meeting: a contact [contact] seconds long (a paw is soft
    and long, a pin is hard and short) rung through a stone body with modes
    between [lo] and [hi]. A long contact is how weight sounds without a
    boom: it leans in rather than spiking."""
    rng = rng if rng is not None else m.rng
    c = max(4, round(contact * SR))
    length = c + round((ring * 2.5 + 0.03) * SR)
    x = np.zeros(length)
    pulse = np.sin(np.linspace(0, math.pi, c)) ** 2
    x[:c] = pulse * (1 + grit * _noise(rng, c, None, hardness))
    f, t60, g = _stone(rng, lo, hi, n, ring, tilt)
    # A long contact is mostly sub-bass; the body only takes what it can
    # ring, so cut below its lowest mode or it leaks through as a thud.
    sos = signal.butter(4, 0.7 * lo, btype='highpass', fs=SR, output='sos')
    y = _modes(signal.sosfilt(sos, x), f, t60, g, rng)
    # The scuff of the surfaces themselves, under the ring.
    sos = signal.butter(2, 1800, btype='highpass', fs=SR, output='sos')
    scuff = signal.sosfilt(sos, x)
    y = y / max(np.max(np.abs(y)), 1e-12)
    y += grit * 0.35 * scuff / max(np.max(np.abs(scuff)), 1e-12)
    y *= np.clip((length - np.arange(length)) / (0.004 * SR), 0, 1)  # no cut
    _put(m, start, amp * y, pan)


def _grind(m, start, length, vel, rate=900, grit_band=(900, 4200),
           body=(140, 1100), body_ring=0.06, cont=0.5, rumble=0.12,
           rough_rate=14, amp=1.0, pan=0.0, rng=None):
    """Stone sliding on stone over [length] seconds, its speed vel(u) for u
    in 0..1. Friction is stick-slip: the surfaces catch and let go in
    micro-slips whose rate follows the speed, each one ringing the slab's
    body and the grit between. A rough, slowly wandering surface makes it
    grind rather than hiss."""
    rng = rng if rng is not None else m.rng
    n = round(length * SR)
    u = np.arange(n) / n
    v = np.clip(vel(u), 0, 1)
    rough = np.clip(0.75 + 0.22 * _drift(rng, n, rough_rate), 0.3, 1.3)
    hits = rng.poisson(v * rate / SR)
    imp = np.zeros(n)
    idx = np.nonzero(hits)[0]
    imp[idx] = (np.minimum(rng.lognormal(0, 0.45, len(idx)), 2.5)
                * v[idx] ** 0.6 * rough[idx])
    sos = signal.butter(2, grit_band, btype='bandpass', fs=SR, output='sos')
    grit = signal.sosfilt(sos, imp)
    f, t60, g = _stone(rng, body[0], body[1], 18, body_ring)
    bod = _modes(imp, f, t60, g, rng)
    contn = _noise(rng, n, 250, 2600) * v ** 1.3 * rough
    rum = _noise(rng, n, 80, 240) * v

    def unit(x):
        return x / max(np.sqrt(np.mean(x ** 2)), 1e-12)

    out = unit(grit) + 0.8 * unit(bod) + cont * unit(contn) + rumble * unit(rum)
    out *= smooth(u, 0, 0.01) * (1 - smooth(u, 0.99, 1.0))
    _put(m, start, amp * out / max(np.max(np.abs(out)), 1e-12), pan)


def _chips(m, times, sizes, pans, amp=1.0, dull=1.0, rng=None):
    """Small stone pieces landing: rubble, grit, a pebble. Smaller is
    higher, shorter and quieter. [dull] < 1 pulls them down (far off)."""
    for t, s, p in zip(times, sizes, pans):
        lo = 1100 / s * dull
        _knock(m, t, lo, min(9000, 5.5 * lo), n=6, ring=0.03 * s,
               contact=0.0005 + 0.0009 * s, hardness=8000 * dull, grit=0.3,
               amp=amp * s ** 0.9, pan=p, tilt=0.3, rng=rng)


def _bubble(m, start, f0, amp, pan=0.0, xi=0.12, delta=0.014):
    """One bubble ringing in water (Minnaert): its size sets the pitch, it
    rises a little as it shrinks to the surface and dies in a few cycles.
    Kept short and barely rising so it reads as water, not a cartoon drip."""
    d = math.pi * f0 * delta
    n = round(min(0.12, 7.0 / d) * SR)
    t = np.arange(n) / SR
    f = f0 * (1 + xi * d * t)
    ph = 2 * math.pi * np.cumsum(f) / SR
    env = np.exp(-d * t) * (1 - np.exp(-t / 0.0007))
    _put(m, start, amp * env * np.sin(ph), pan)


def _tame(m, accent_db=4.0, fast=0.005, slow=0.06):
    """No spikes: wherever the sound over [fast] seconds rises more than
    [accent_db] above the sound around it over [slow] seconds, it is held
    down to that. An accent stays a change of texture a few dB up, never a
    crack; contacts keep their shape, just not their spike."""
    p = np.sum(m.y ** 2, axis=0)

    def mean(x, secs):
        k = max(1, round(secs * SR))
        return np.convolve(x, np.ones(k) / k, mode='same')

    fast_env = np.sqrt(mean(p, fast)) + 1e-9
    slow_env = np.sqrt(mean(p, slow)) + 1e-9
    gain = np.minimum(1.0, slow_env * 10 ** (accent_db / 20) / fast_env)
    # Hold the deepest reduction a moment, then ease it: no ripple.
    k = round(0.003 * SR)
    gain = ndimage.minimum_filter1d(gain, k)
    m.y *= mean(gain, 0.004)


def _chamber(m, t60=1.4, wet=0.26, darkness=3600, early=0.22, accent_db=4.0):
    """A stone room: a few early reflections off near walls (different per
    side, darker than the source), then core's tail. The dry sound is
    tamed first (_tame), so the room answers the accent as it is heard."""
    if accent_db is not None:
        _tame(m, accent_db)
    taps = ([0.0097, 0.0161, 0.0239, 0.0334, 0.0470],
            [0.0113, 0.0188, 0.0272, 0.0385, 0.0529])
    sos = signal.butter(2, 3800, btype='lowpass', fs=SR, output='sos')
    dry = signal.sosfilt(sos, m.y, axis=1)
    er = np.zeros_like(m.y)
    for ch in range(2):
        for k, d in enumerate(taps[ch]):
            s = round(d * SR)
            er[ch, s:] += (0.78 ** k) * dry[1 - ch if k % 2 else ch, : m.n - s]
    m.y = m.y + early * er
    m.room(t60=t60, wet=wet, darkness=darkness)


def _rng(seed):
    return np.random.default_rng(seed)


# ===========================================================================
# Footsteps -- planet_dungeon_game.dart, the walk in update()
# ===========================================================================
#
# A step fires every 48 px of travel at 187.5 px/s (_speed): one every
# 256 ms, cooled to 220 ms, played at gain .35 and droppable (priority 0).
# Water when the walker stands in a flooded tide zone of a temple.
# They are the most repeated sound in a dungeon, so: short, soft, mostly
# below the speaker's attention, and every variant a real re-render.

def step_stone(v=0):
    """A creature's padded foot on dressed stone, with a little grit."""
    r = _rng(5100 + 37 * v)
    m = Mix(0.17, seed=5100 + v)
    # The pad: a soft contact into the floor slab -- weight, not a click.
    _knock(m, 0.006, lo=170 + 25 * v, hi=1900, n=20, ring=0.05,
           contact=0.011 + 0.002 * (v % 2), hardness=1500, grit=0.5,
           amp=0.8, pan=0.08 * (v - 1.5), rng=r)
    # The scuff: the foot rolling off, a few grains of grit under it.
    scuff = 0.03 + 0.012 * (v % 3)
    _grind(m, 0.012, scuff, lambda u: np.sin(np.pi * u) ** 1.5, rate=1400,
           grit_band=(1800, 6500), body=(600, 3000), body_ring=0.015,
           cont=0.4, rumble=0.0, rough_rate=60, amp=0.22 + 0.06 * (v % 2),
           pan=0.08 * (v - 1.5), rng=r)
    _chamber(m, t60=0.5, wet=0.12, early=0.12)
    return m.finish(loudness_db=-35.0, fade_out=0.04)


def step_water(v=0):
    """A foot into shallow standing water: the plunge, a slosh, the bubbles
    it trapped, a few drops falling back."""
    r = _rng(5200 + 41 * v)
    m = Mix(0.26, seed=5200 + v)
    pan = 0.08 * (v - 1.5)
    # The plunge: a body of water pushed aside, leaning in over ~15 ms.
    n = round(0.11 * SR)
    t = np.arange(n) / SR
    env = smooth(t, 0, 0.016) * np.exp(-np.maximum(t - 0.016, 0) / 0.035)
    _put(m, 0.0, 0.5 * env * _noise(r, n, 350, 1700), pan)
    # The slosh, a little later and brighter: water closing back in.
    n2 = round(0.12 * SR)
    t2 = np.arange(n2) / SR
    env2 = smooth(t2, 0, 0.02) * np.exp(-t2 / 0.045)
    _put(m, 0.035, 0.22 * env2 * _noise(r, n2, 900, 3600), pan)
    # Trapped air: bubbles, larger first, then small.
    for _ in range(9 + v):
        at = 0.012 + r.gamma(2.0, 0.025)
        f0 = float(np.clip(r.lognormal(math.log(1500), 0.4), 700, 4200))
        _bubble(m, at, f0, 0.09 * r.uniform(0.4, 1.0) * (1500 / f0) ** 0.5,
                pan + r.normal(0, 0.15), xi=0.08, delta=0.02)
    # Drops falling back: tiny, high, scattered.
    for _ in range(5):
        at = 0.07 + r.uniform(0, 0.11)
        f0 = float(r.uniform(2600, 5200))
        _bubble(m, at, f0, 0.035 * r.uniform(0.4, 1.0),
                pan + r.normal(0, 0.3), xi=0.05, delta=0.03)
    _chamber(m, t60=0.6, wet=0.14, early=0.14)
    return m.finish(loudness_db=-35.0, fade_out=0.05)


# ===========================================================================
# The verbs -- interact, switch, block, gate, wall, hazard
# ===========================================================================

def interact():
    """The generic answer (activateAbility's FALLBACK, ~9047: only when a
    verb took the press and said nothing of its own). A touch on carved
    stone that gives a little: the press, and a small catch under it."""
    r = _rng(5301)
    m = Mix(0.4, seed=5301)
    # The press: a paw on a carved face. Soft, mid, short.
    _knock(m, 0.005, lo=260, hi=2600, n=22, ring=0.06, contact=0.012,
           hardness=2200, grit=0.45, amp=0.75, rng=r)
    # The stone shifting under it by a hair...
    _grind(m, 0.03, 0.05, lambda u: np.sin(np.pi * u), rate=1100,
           grit_band=(1500, 5200), body=(400, 2400), body_ring=0.02,
           cont=0.3, rumble=0.0, amp=0.18, rng=r)
    # ...and seating: a smaller, harder catch.
    _knock(m, 0.082, lo=420, hi=3600, n=14, ring=0.04, contact=0.004,
           hardness=4500, grit=0.3, amp=0.42, pan=0.05, rng=r)
    m.air(0.0, 0.3, 300, 1600, amp=0.012, rise=0.3)
    _chamber(m, t60=0.9, wet=0.18)
    return m.finish(loudness_db=-34.0, fade_out=0.12)


def switch():
    """A puzzle mechanism turned one notch (mirrors rotated, a tide level
    set, a socket fitted, a lamp moved, a conduit taken -- 28 sites): a
    short turn of stone on its pivot, a pin dropping into its detent, and
    the glass piece it carries brightening under that, briefly."""
    r = _rng(5401)
    m = Mix(0.62, seed=5401)
    SEAT = 0.13       # one quick notch: the pin finds the detent as it ends
    # It keeps turning right up to the detent: no gap before the seat.
    _grind(m, 0.012, SEAT - 0.004, lambda u: smooth(u, 0, 0.25) * (1 - 0.35 * smooth(u, 0.75, 1.0)),
           rate=1300, grit_band=(1100, 4600), body=(300, 1800),
           body_ring=0.04, cont=0.45, rumble=0.05, rough_rate=30,
           amp=0.42, rng=r)
    # The detent: a hard, small stone-on-stone seat, with the pivot's body.
    _knock(m, SEAT, lo=330, hi=3800, n=20, ring=0.07, contact=0.005,
           hardness=5000, grit=0.3, amp=0.8, pan=0.04, rng=r)
    _knock(m, SEAT + 0.003, lo=150, hi=900, n=12, ring=0.09, contact=0.012,
           hardness=1500, grit=0.2, amp=0.35, rng=r)
    # The leaded piece catching the light: stroked, low, well under the stone.
    m.glass(SEAT + 0.01, 523, amp=0.09, ring=0.6, attack=0.05,
            brightness=0.25, beat=1.6, ratios=[1.0, 2.32, 4.25])
    _chamber(m, t60=1.0, wet=0.2)
    return m.finish(loudness_db=-32.0, fade_out=0.2)


def block_move():
    """A stone block, rib, plate or facet slid one place (Earth's ribs run
    0.9 s easeInOut, _kRibSlideClean; Ice's orrery 0.13 s a cell; Crystal's
    plates and facet; Blood's systole). A grind that swells and eases with
    the slide, and the block settling where it stops."""
    r = _rng(5501)
    m = Mix(1.15, seed=5501)
    SLIDE = 0.78      # between the orrery's few cells and Earth's 0.9 s
    START = 0.02
    # easeInOut's speed is a bell; stone needs a push to break free, so a
    # little extra at the very start (static friction letting go).
    _grind(m, START, SLIDE,
           lambda u: np.sin(np.pi * u) ** 1.2 + 0.35 * np.exp(-u / 0.04) * smooth(u, 0, 0.02),
           rate=1000, grit_band=(800, 3800), body=(120, 900),
           body_ring=0.07, cont=0.55, rumble=0.12, amp=0.55, rng=r)
    # Grit spilling off the moving edge.
    times = START + 0.05 + np.sort(r.uniform(0, SLIDE * 0.85, 14))
    _chips(m, times, r.uniform(0.25, 0.6, 14), r.normal(0, 0.3, 14),
           amp=0.06, rng=r)
    # It stops: a soft heavy seat, leaned into, no boom.
    END = START + SLIDE
    _knock(m, END - 0.012, lo=110, hi=1300, n=26, ring=0.12, contact=0.022,
           hardness=1600, grit=0.45, amp=0.95, rng=r)
    _chamber(m, t60=1.2, wet=0.22)
    return m.finish(loudness_db=-31.0, fade_out=0.25)


def gate_open():
    """A sealed door gives (_queueDoorReveal, ~2616; Earth's lintel lifted,
    Water's seals, Ice's caps, Plant's and Blood's gates -- 23 sites). The
    door turns from slab to passage at once and gold rings spread from it
    over 2.2 s (_DoorRevealFx), so the sound starts on the frame: the catch
    lets go, the slab grinds clear, dust falls from the lintel, it seats."""
    r = _rng(5601)
    m = Mix(1.9, seed=5601)
    RELEASE = 0.0
    GRIND = (0.07, 1.18)  # the slab's travel: heavy, so slow to start
    SEAT = GRIND[1]
    # The catch: a bar lifted out of its keeper.
    _knock(m, RELEASE + 0.004, lo=200, hi=2400, n=20, ring=0.07,
           contact=0.009, hardness=3200, grit=0.4, amp=0.75, rng=r)
    length = GRIND[1] - GRIND[0]

    def vel(u):
        # Breaks free, gathers, and eases into the seat.
        return (0.45 * np.exp(-u / 0.05) * smooth(u, 0, 0.02)
                + smooth(u, 0.0, 0.2) * (1 - smooth(u, 0.7, 1.0)) * 0.8 + 0.08)

    _grind(m, GRIND[0], length, vel, rate=800, grit_band=(700, 3400),
           body=(95, 800), body_ring=0.1, cont=0.6, rumble=0.18,
           rough_rate=10, amp=0.55, rng=r)
    # Dust and grit shaken off the lintel while it moves.
    times = GRIND[0] + 0.1 + np.sort(r.gamma(2.0, 0.22, 26))
    times = times[times < SEAT + 0.3]
    _chips(m, times, r.uniform(0.2, 0.55, len(times)),
           r.normal(0, 0.35, len(times)), amp=0.07, rng=r)
    m.air(GRIND[0] + 0.15, length + 0.4, 400, 3200, amp=0.02, rise=0.6)
    # The seat: a soft, heavy landing, leaned into over ~25 ms.
    _knock(m, SEAT - 0.02, lo=95, hi=1100, n=30, ring=0.16, contact=0.026,
           hardness=1300, grit=0.5, amp=1.0, rng=r)
    _knock(m, SEAT + 0.05, lo=160, hi=1400, n=18, ring=0.08, contact=0.012,
           hardness=1800, grit=0.4, amp=0.3, pan=0.1, rng=r)  # it rocks once
    m.air(SEAT - 0.02, 0.5, 250, 1800, amp=0.03, rise=0.15)  # the puff
    _chamber(m, t60=1.6, wet=0.26)
    return m.finish(loudness_db=-30.0, fade_out=0.35)


def wall_break():
    """Masonry giving way (Earth's anvil shell, Dust, Crystal, Mud, Ice,
    Plant, Blood -- 9 sites): it cracks, a mass breaks free and lands in
    pieces, rubble scatters, dust hangs. The crack builds over ~40 ms rather
    than arriving as one burst, so it is stone breaking, not a crash."""
    r = _rng(5701)
    m = Mix(1.35, seed=5701)
    # The crack running: snaps that come faster and harder as it opens.
    k = 16
    snap_t = 0.045 * (1 - np.linspace(1, 0, k) ** 1.8)
    for i, t in enumerate(snap_t):
        s = 0.25 + 0.5 * i / k
        _knock(m, t + r.uniform(0, 0.003), lo=600 + 400 * r.random(), hi=7000,
               n=8, ring=0.025, contact=0.0008, hardness=9000, grit=0.4,
               amp=0.12 + 0.25 * i / k, pan=r.normal(0, 0.15), tilt=0.25, rng=r)
    # The mass breaking free: big pieces land, each a heavy soft contact.
    BREAK = 0.07
    for j, (dt, size, pan) in enumerate([(0.0, 1.0, -0.05), (0.06, 0.8, 0.25),
                                         (0.11, 0.9, -0.3), (0.19, 0.6, 0.15),
                                         (0.27, 0.5, -0.2), (0.38, 0.45, 0.3)]):
        _knock(m, BREAK + dt + r.uniform(0, 0.01), lo=110 / size ** 0.5,
               hi=1600 / size ** 0.3, n=24, ring=0.1 * size,
               contact=0.012 + 0.01 * size, hardness=2000, grit=0.6,
               amp=0.55 * size, pan=pan, rng=r)
    # Rubble: many small pieces, thick at first, thinning, bouncing out.
    nchip = 70
    times = BREAK + 0.03 + r.gamma(1.5, 0.12, nchip)
    times = times[times < 1.05]
    _chips(m, times, np.clip(r.lognormal(-0.8, 0.45, len(times)), 0.15, 1.0),
           r.normal(0, 0.45, len(times)), amp=0.22, rng=r)
    # Dust, hanging and settling.
    m.air(BREAK, 1.1, 500, 4200, amp=0.035, rise=0.15)
    m.air(BREAK + 0.02, 0.6, 180, 900, amp=0.04, rise=0.1)
    _chamber(m, t60=1.5, wet=0.26)
    return m.finish(loudness_db=-30.0, fade_out=0.3)


def hazard_trigger():
    """The room pushing back (stepping into a hazard, ~10358; a scoured chute
    giving way under you, Ice; a closing window refilling, Crystal and Dust;
    a thrombosed vessel, Blood; the Botanica's strike and its shake, Plant;
    the Solarin's bolts, Light). A lurch: something heavy shifts, grit pours
    down after it, a breath goes out. No seat -- nothing settles."""
    r = _rng(5801)
    m = Mix(0.75, seed=5801)
    LURCH = 0.24
    _grind(m, 0.0, LURCH, lambda u: smooth(u, 0, 0.12) * np.exp(-np.maximum(u - 0.15, 0) / 0.35),
           rate=1400, grit_band=(500, 2800), body=(90, 650), body_ring=0.09,
           cont=0.7, rumble=0.25, rough_rate=22, amp=0.85, rng=r)
    # The drop: grit and small stone pouring down after it.
    n = 40
    times = 0.06 + np.sort(r.gamma(1.6, 0.09, n))
    times = times[times < 0.65]
    _chips(m, times, np.clip(r.lognormal(-0.9, 0.4, len(times)), 0.15, 0.8),
           r.normal(0, 0.4, len(times)), amp=0.18, dull=0.8, rng=r)
    m.air(0.02, 0.6, 220, 1400, amp=0.05, rise=0.12)
    _chamber(m, t60=1.1, wet=0.22, darkness=2800)
    return m.finish(loudness_db=-32.0, fade_out=0.2)


# ===========================================================================
# The rewards -- weight scaled to importance
# ===========================================================================
#
#   checkpoint  < secret < star seat < puzzle solved < relic
#
# All mechanism and stone, with the leaded glass of the puzzle piece lit
# underneath. No chime runs, no struck glass on top.

def checkpoint():
    """The party whole again: a downed creature revived beside you
    (_reviveCreature, ~1443), the party gathered (Dark), the chime stilled
    (Spirit). A breath in and something set down gently on stone, warm."""
    r = _rng(5901)
    m = Mix(1.1, seed=5901)
    m.air(0.0, 0.7, 220, 1300, amp=0.05, rise=0.45)
    SET = 0.3
    _knock(m, SET - 0.015, lo=150, hi=1500, n=22, ring=0.09, contact=0.02,
           hardness=1500, grit=0.3, amp=0.5, rng=r)
    m.glass(SET - 0.02, 311, amp=0.12, ring=1.3, attack=0.12,
            brightness=0.15, beat=0.8, ratios=[1.0, 2.32, 4.25])
    _chamber(m, t60=1.3, wet=0.24)
    return m.finish(loudness_db=-33.0, fade_out=0.35)


def secret_reveal():
    """Something hidden becomes real (a key turning in shadow, a niche
    cleared, a hatch prised up, a lost maxim found, a vault essence
    fizzling -- 11 sites + the screen's _onCloudDiscovered). A stone gives
    way to one side, lighter than a gate, and behind it a leaded piece
    comes up out of the dark: light swelling, fine dust settling."""
    r = _rng(6001)
    m = Mix(1.7, seed=6001)
    SHIFT = 0.26
    _grind(m, 0.0, SHIFT, lambda u: smooth(u, 0, 0.15) * (1 - smooth(u, 0.55, 1.0)),
           rate=1100, grit_band=(1000, 4400), body=(220, 1600),
           body_ring=0.05, cont=0.45, rumble=0.04, amp=0.18, rng=r)
    _knock(m, SHIFT - 0.012, lo=200, hi=1800, n=18, ring=0.07, contact=0.014,
           hardness=2200, grit=0.4, amp=0.2, rng=r)
    # The piece lighting: two glass bodies stroked up from nothing.
    m.glass(0.12, 392, amp=0.1, ring=1.6, attack=0.35, brightness=0.45,
            beat=0.9, pan=-0.1)
    m.glass(0.16, 541, amp=0.06, ring=1.2, attack=0.3, brightness=0.35,
            beat=1.3, pan=0.12, ratios=[1.0, 2.32, 4.25])
    m.air(0.05, 1.1, 350, 2800, amp=0.07, rise=0.4)
    times = 0.25 + np.sort(r.gamma(1.8, 0.2, 18))
    times = times[times < 1.4]
    _chips(m, times, r.uniform(0.15, 0.35, len(times)),
           r.normal(0, 0.4, len(times)), amp=0.04, rng=r)
    _chamber(m, t60=1.6, wet=0.28)
    return m.finish(loudness_db=-31.0, fade_out=0.4)


def puzzle_solved():
    """A room's puzzle done (earnStar for stars 1 and 2, ~10522; Dark's rite
    and chambers, Plant's cut, Light's floor setting, Spirit's walk). The
    room's mechanism settles home: a catch lets go at once, something heavy
    under the floor travels and SEATS as the star swells to full (its
    easeOutBack peaks ~0.4 s, _kStarBirth), the chamber answers, and the
    leaded piece the puzzle was made of lights under it all.

    It plays together with sfx_dungeon_star_collect for the first two
    stars, whose own weight comes later (the star seating at 1.76 s), so
    this one owns the first second and is gone by then."""
    r = _rng(6101)
    m = Mix(2.3, seed=6101)
    SEAT = 0.42
    # The catch, on the frame.
    _knock(m, 0.004, lo=240, hi=2600, n=18, ring=0.07, contact=0.008,
           hardness=3500, grit=0.35, amp=0.35, rng=r)
    # The mechanism travelling: low, heavy, quick to gather.
    _grind(m, 0.03, SEAT - 0.03,
           lambda u: smooth(u, 0, 0.3) * (1 - 0.5 * smooth(u, 0.8, 1.0)),
           rate=750, grit_band=(600, 3000), body=(85, 700), body_ring=0.12,
           cont=0.6, rumble=0.2, rough_rate=9, amp=0.22, rng=r)
    # The seat: a large slab meeting its bed, leaned into over ~30 ms.
    _knock(m, SEAT - 0.03, lo=170, hi=2000, n=34, ring=0.16, contact=0.042,
           hardness=1400, grit=0.5, amp=0.85, tilt=0.3, rng=r)
    _knock(m, SEAT + 0.07, lo=140, hi=1300, n=18, ring=0.1, contact=0.014,
           hardness=1800, grit=0.4, amp=0.2, pan=-0.12, rng=r)
    m.air(SEAT - 0.03, 0.55, 220, 1500, amp=0.045, rise=0.15)
    m.air(SEAT, 1.3, 300, 2400, amp=0.03, rise=0.3)  # the light, blooming
    # The leaded piece lit: stroked up under the seat, never struck.
    m.glass(SEAT - 0.05, 262, amp=0.14, ring=2.4, attack=0.22,
            brightness=0.4, beat=0.7, pan=-0.08, ratios=[1.0, 2.19, 3.89, 5.91])
    m.glass(SEAT, 338, amp=0.1, ring=1.6, attack=0.2, brightness=0.2,
            beat=1.1, pan=0.1, ratios=[1.0, 2.32, 4.25])
    # A little dust shaken loose by the seat.
    times = SEAT + 0.02 + np.sort(r.gamma(1.6, 0.18, 16))
    _chips(m, times, r.uniform(0.15, 0.4, 16), r.normal(0, 0.4, 16),
           amp=0.05, rng=r)
    _chamber(m, t60=2.0, wet=0.32, early=0.26)
    return m.finish(loudness_db=-31.0, fade_out=0.5)


# The star's flight (planet_dungeon_screen.dart, _buildFlyingStar):
STAR_FLIGHT = 2.15                 # _kStarFlightDuration
STAR_BIRTH = 0.30 * STAR_FLIGHT    # _kStarBirth: swells and HOLDS where earned
STAR_LAND = 0.82 * STAR_FLIGHT     # _kStarLand: seats in its tracker slot


def star_collect():
    """A star banked (_onStarEarned). Scored to its flight: born where it
    was earned (quiet -- the room's own sfx_dungeon_puzzle_solved carries
    that second), drawn up to the tracker on a breath that follows its
    easeInOut speed, and SEATED in its slot at 1.76 s: a small, exact stone
    setting, the socket's glass lit beneath."""
    r = _rng(6201)
    m = Mix(STAR_LAND + 0.75, seed=6201)
    # Birth: light gathering, under everything.
    m.air(0.0, STAR_BIRTH + 0.2, 500, 3600, amp=0.022, rise=0.55)
    # Flight: the breath is the star's speed (easeInOut's derivative).
    n = round((STAR_LAND - STAR_BIRTH + 0.1) * SR)
    t = np.arange(n) / SR
    u = np.clip(t / (STAR_LAND - STAR_BIRTH), 0, 1)
    speed = np.sin(np.pi * u) ** 2 + 0.05
    speed *= smooth(t, 0, 0.06) * (1 - smooth(t, n / SR - 0.08, n / SR))
    for ch, side in enumerate((-1, 1)):
        x = speed * (0.6 * _noise(r, n, 500, 2600) + 0.4 * _noise(r, n, 2000, 6000))
        m.y[ch, round(STAR_BIRTH * SR): round(STAR_BIRTH * SR) + n] += 0.01 * x
    # The socket waking as the star nears it: the lean into the seat.
    m.glass(STAR_LAND - 0.2, 466, amp=0.05, ring=0.5, attack=0.2,
            brightness=0.2, beat=1.2, ratios=[1.0, 2.32, 4.25])
    m.air(STAR_LAND - 0.25, 0.35, 700, 4200, amp=0.02, rise=0.75)
    # The seat: lean in with a short slide into the socket, then set.
    _grind(m, STAR_LAND - 0.06, 0.06, lambda u: smooth(u, 0, 0.5),
           rate=1500, grit_band=(1600, 5600), body=(500, 2600),
           body_ring=0.02, cont=0.3, rumble=0.0, amp=0.12, rng=r)
    _knock(m, STAR_LAND - 0.01, lo=360, hi=3400, n=22, ring=0.08,
           contact=0.012, hardness=4200, grit=0.35, amp=0.55, rng=r)
    _knock(m, STAR_LAND - 0.004, lo=170, hi=1100, n=14, ring=0.12,
           contact=0.015, hardness=1500, grit=0.2, amp=0.25, rng=r)
    # The socket's leaded glass lighting under the seat (the slot glows).
    m.glass(STAR_LAND - 0.01, 466, amp=0.12, ring=1.1, attack=0.06,
            brightness=0.3, beat=1.2, ratios=[1.0, 2.32, 4.25, 6.63])
    m.air(STAR_LAND - 0.02, 0.5, 400, 2600, amp=0.03, rise=0.2)
    _chamber(m, t60=1.3, wet=0.24)
    return m.finish(loudness_db=-33.0, fade_out=0.4)


def relic_collect():
    """A relic taken into keeping (the dungeon: the guardian's relic as it
    expands away, _RelicDropFx's claim from 2.6 s, its last second; the
    Mystic Altar: a relic set into its seat, whose pool of light swells and
    goes over 0.95 s, peaking ~0.47). The heaviest reward here: old weight
    pressed into stone, and deep leaded glass lighting slowly under it and
    staying lit while the light blooms and goes."""
    r = _rng(6301)
    m = Mix(2.9, seed=6301)
    SET = 0.03
    _grind(m, 0.0, SET + 0.02, lambda u: smooth(u, 0, 0.8), rate=900,
           grit_band=(700, 3200), body=(120, 900), body_ring=0.05,
           cont=0.4, rumble=0.1, amp=0.25, rng=r)
    _knock(m, SET - 0.01, lo=160, hi=1600, n=36, ring=0.18, contact=0.04,
           hardness=1200, grit=0.45, amp=0.4, tilt=0.35, rng=r)
    # The light swelling through it: deep glass, stroked, peaking ~0.45 s.
    m.glass(SET, 196, amp=0.16, ring=2.8, attack=0.4, brightness=0.45,
            beat=0.6, pan=-0.06, ratios=[1.0, 2.19, 3.89, 5.91])
    m.glass(SET + 0.05, 304, amp=0.12, ring=2.0, attack=0.38, brightness=0.25,
            beat=0.9, pan=0.12)
    m.air(0.0, 1.3, 260, 2200, amp=0.07, rise=0.35)
    m.air(0.1, 1.0, 1200, 5200, amp=0.012, rise=0.4)
    times = SET + 0.05 + np.sort(r.gamma(1.6, 0.25, 22))
    times = times[times < 2.0]
    _chips(m, times, r.uniform(0.12, 0.35, len(times)),
           r.normal(0, 0.45, len(times)), amp=0.04, rng=r)
    _chamber(m, t60=2.2, wet=0.34, early=0.25)
    return m.finish(loudness_db=-30.0, fade_out=0.6)


# ===========================================================================
# Ambience -- AmbienceCue.forDungeon (lib/audio/ambience_player.dart)
# ===========================================================================
#
# Looped under the whole dungeon at volume .18. Each is 30 s of room tone
# with its element's character, built of random events and slow drifts so
# nothing is rhythmic or musical and nothing stands out to repeat. Rendered
# LOOP_XFADE longer and folded with seamless_loop.

LOOP = 30.0
LOOP_XFADE = 1.5


def _events(rng, rate, length, jitter=0.7):
    """Event times with no pulse: a Poisson stream, thinned so two never
    stack, at [rate] per second over [length] seconds."""
    times, t = [], rng.exponential(1 / rate)
    while t < length:
        times.append(t)
        t += rng.exponential(1 / rate) * (1 - jitter) + jitter * rng.uniform(0.2, 1.8) / rate
    return np.array(times)


def _distant(sub, cutoff):
    """Pull a sub-mix back: a far event loses its top."""
    sos = signal.butter(2, cutoff, btype='lowpass', fs=SR, output='sos')
    return signal.sosfilt(sos, sub.y, axis=1)


def _sway(rng, n, rate, depth, spread=0.25, power=1.0):
    """A layer's slow swell as a gain per ear: one shared motion (so the
    room never leans to one side) with a little of its own in each ear.
    [depth] is how far it swings either way around 1."""
    shared = _drift(rng, n, rate)
    out = []
    for _ in range(2):
        own = _drift(rng, n, rate * 1.7)
        g = 1 + depth * ((1 - spread) * shared + spread * own)
        out.append(np.clip(g, 0.05, None) ** power)
    return out


def _bed(m, rng, low_amp, air_amp, air_band=(300, 1400)):
    """The still air of a stone room: dark, and different in each ear."""
    sway = _sway(rng, m.n, 0.06, 0.2)
    for ch in range(2):
        m.y[ch] += low_amp * _noise(rng, m.n, None, 420)
        m.y[ch] += air_amp * sway[ch] * _noise(rng, m.n, *air_band)


def _loop_out(m, loudness):
    y = m.finish(loudness_db=loudness, fade_out=0)
    return seamless_loop(y, LOOP_XFADE)


def amb_ruins():
    """Stone ruins (Earth, Air, Dust, Plant and any other): still
    dark air, a draught through gaps that comes and goes, grit trickling
    somewhere, a pebble falling far off, the odd distant drip."""
    r = _rng(6401)
    total = LOOP + LOOP_XFADE
    m = Mix(total, seed=6401)
    _bed(m, r, 0.006, 0.0035)
    # The draught: three loose bands with their own slow swells, so the
    # wind's colour wanders without ever whistling.
    for fc, bw in ((520, 380), (840, 520), (1300, 800)):
        g = _sway(r, m.n, 0.09, 0.45, power=1.5)
        for ch in range(2):
            m.y[ch] += 0.0022 * g[ch] * _noise(r, m.n, fc - bw / 2, fc + bw / 2)
    far = Mix(total, seed=6402)
    # Grit trickling down a wall somewhere: little clusters, no pulse.
    for t0 in _events(r, 1 / 4.5, total):
        k = r.integers(4, 18)
        times = t0 + np.sort(r.gamma(1.5, 0.12, k))
        _chips(far, times, r.uniform(0.15, 0.4, k),
               np.full(k, r.uniform(-0.8, 0.8)) + r.normal(0, 0.1, k),
               amp=r.uniform(0.3, 0.7), dull=0.7, rng=r)
    # A pebble letting go, far off: it lands and skitters.
    for t0 in _events(r, 1 / 11.0, total):
        pan = r.uniform(-0.8, 0.8)
        s = r.uniform(0.35, 0.6)
        times = t0 + np.cumsum([0] + [0.11 * 0.6 ** i for i in range(4)])
        _chips(far, times, s * 0.75 ** np.arange(5), np.full(5, pan),
               amp=0.35, dull=0.65, rng=r)
    # The odd drip, deep in the stone.
    for t0 in _events(r, 1 / 8.0, total):
        _bubble(far, t0, r.uniform(900, 1700), 0.15, r.uniform(-0.7, 0.7))
    m.y += 0.2 * _distant(far, 5000)
    m.room(t60=2.6, wet=0.45, darkness=2400)
    return _loop_out(m, -38.0)


def amb_water():
    """Wet stone (Water, Ice, Mud, Poison): water moving somewhere out of
    sight, a slow lap against stone, drips falling into pools at no pace
    at all, a cold room around them."""
    r = _rng(6501)
    total = LOOP + LOOP_XFADE
    m = Mix(total, seed=6501)
    _bed(m, r, 0.005, 0.0025)
    # Lapping: water against a stone edge, slow and uneven.
    lap = _sway(r, m.n, 0.35, 0.55, spread=0.35, power=2)
    for ch in range(2):
        m.y[ch] += 0.004 * lap[ch] * _noise(r, m.n, 180, 900)
    # A trickle far off: a stream of tiny bubbles whose flow wanders.
    stream = Mix(total, seed=6502)
    flow = np.clip(1 + 0.3 * _drift(r, m.n, 0.12), 0.3, None)
    rate = 85 * flow / SR
    idx = np.nonzero(r.poisson(rate))[0]
    for i in idx:
        f0 = float(np.clip(r.lognormal(math.log(1700), 0.35), 800, 4500))
        _bubble(stream, i / SR, f0, 0.05 * r.uniform(0.3, 1.0),
                -0.3 + r.normal(0, 0.18), xi=0.1, delta=0.02)
    m.y += 1.0 * _distant(stream, 3200)
    # Drips into pools: near and far, never on a beat.
    drips = Mix(total, seed=6503)
    for t0 in _events(r, 1 / 2.1, total, jitter=0.9):
        near = r.random() < 0.3
        pan = r.uniform(-0.85, 0.85)
        f0 = r.uniform(950, 2100)
        amp = r.uniform(0.25, 0.5) if near else r.uniform(0.08, 0.2)
        n = round(0.004 * SR)
        _put(drips, t0, amp * 0.25 * _noise(r, n, 2500, 9000)
             * np.hanning(n), pan)
        _bubble(drips, t0 + 0.002, f0, amp, pan, xi=0.18, delta=0.012)
    m.y += 0.25 * _distant(drips, 4200)
    m.room(t60=2.9, wet=0.5, darkness=2800)
    return _loop_out(m, -36.0)


def amb_fire():
    """Hot stone (Fire, Lava, Steam): a fire burning in another chamber --
    a low roar that breathes, its flicker, embers cracking at no steady
    rate, now and then a coal settling -- and heat ticking in the walls."""
    r = _rng(6601)
    total = LOOP + LOOP_XFADE
    m = Mix(total, seed=6601)
    _bed(m, r, 0.004, 0.002)
    breathe = _sway(r, m.n, 0.25, 0.3)
    flicker = _sway(r, m.n, 5.0, 0.45, spread=0.4)
    for ch in range(2):
        m.y[ch] += 0.007 * breathe[ch] * _noise(r, m.n, 80, 520)
        m.y[ch] += 0.0028 * breathe[ch] * flicker[ch] * _noise(r, m.n, 350, 1600)
    # Crackle: bursts of pops; the fire's mood changes how many.
    crack = Mix(total, seed=6602)
    mood = np.clip(1 + 0.4 * _drift(r, m.n, 0.15), 0.1, None) ** 2
    idx = np.nonzero(r.poisson(3.5 * mood / SR))[0]
    for i in idx:
        t0 = i / SR
        pan = r.uniform(-0.6, 0.6)
        for j in range(1 + r.poisson(0.8)):
            at = t0 + (0 if j == 0 else r.uniform(0.008, 0.07))
            c = round(r.uniform(0.0003, 0.0018) * SR) + 2
            pop = np.zeros(c + round(0.02 * SR))
            pop[:c] = np.hanning(c) * r.normal(0, 1, c)
            f, t60, g = _stone(r, 900, 5200, 5, 0.012, tilt=0.2)
            pop = _modes(pop, f, t60, g, r) + 0.5 * pop
            size = min(r.lognormal(-0.5, 0.6), 1.2)
            _put(crack, at, size * pop / max(np.max(np.abs(pop)), 1e-9),
                 pan + r.normal(0, 0.1))
    m.y += 0.1 * _distant(crack, 4500)
    # A coal settling: a soft knock and a few bits, far off, rarely.
    far = Mix(total, seed=6603)
    for t0 in _events(r, 1 / 9.0, total):
        pan = r.uniform(-0.6, 0.6)
        _knock(far, t0, lo=160, hi=1400, n=16, ring=0.05, contact=0.01,
               hardness=1500, grit=0.5, amp=0.6, pan=pan, rng=r)
        k = r.integers(3, 9)
        _chips(far, t0 + 0.02 + np.sort(r.gamma(1.5, 0.06, k)),
               r.uniform(0.2, 0.45, k), np.full(k, pan), amp=0.4,
               dull=0.8, rng=r)
    # Heat ticking in the stone: lone small ticks, sparse.
    for t0 in _events(r, 1 / 3.5, total):
        _chips(far, [t0], [r.uniform(0.15, 0.3)], [r.uniform(-0.9, 0.9)],
               amp=0.35, rng=r)
    m.y += 0.05 * _distant(far, 3000)
    m.room(t60=2.0, wet=0.38, darkness=2600)
    return _loop_out(m, -36.0)


# Inharmonic on purpose: no two of these sit near a simple interval (checked
# below), so the resonance never adds up to a chord or a note.
_ARCANE_HUM = (75.6, 143.9, 280.8, 393.7, 537.1, 824.1)


def _assert_unmusical(freqs, tol=0.02):
    simple = [1, 6 / 5, 5 / 4, 4 / 3, 3 / 2, 8 / 5, 5 / 3, 2]
    for i, a in enumerate(freqs):
        for b in freqs[i + 1:]:
            x = b / a
            while x > 2.0 + tol:
                x /= 2
            assert all(abs(x / s - 1) > tol for s in simple), (a, b, x)


_assert_unmusical(_ARCANE_HUM)


def amb_arcane():
    """Arcane stone (Crystal, Spirit, Light, Dark, Lightning, Blood): a low
    resonance in the walls, breathy and unpitched -- narrow bands of air
    that swell and fade on their own clocks -- air moving through a large
    space, and very rarely the stone settling."""
    r = _rng(6701)
    total = LOOP + LOOP_XFADE
    m = Mix(total, seed=6701)
    _bed(m, r, 0.004, 0.0022, air_band=(250, 2000))
    for k, f in enumerate(_ARCANE_HUM):
        # Low bands narrow (a resonance), the upper ones wide (air in it):
        # a narrow band up where the phone plays would be a whistle.
        bw = f / 35 if f < 300 else f / 9
        # Each band on its own slow clock, so the balance between them
        # keeps changing while the whole stays level.
        swell = _sway(r, m.n, 0.05 + 0.017 * k, 0.6, spread=0.3, power=2)
        amp = 0.0035 * (110 / f) ** 0.2 if f < 300 else 0.003 * (391 / f) ** 1.2
        for ch in range(2):
            m.y[ch] += amp * swell[ch] * _noise(r, m.n, f - bw, f + bw)
    # The air in a large room moving, and a faint high sheen of it.
    mv = _sway(r, m.n, 0.07, 0.35)
    for ch in range(2):
        m.y[ch] += 0.0025 * mv[ch] * _noise(r, m.n, 400, 2400)
        m.y[ch] += 0.0007 * mv[ch] * _noise(r, m.n, 4500, 9000)
    far = Mix(total, seed=6702)
    for t0 in _events(r, 1 / 10.0, total):
        pan = r.uniform(-0.8, 0.8)
        k = r.integers(2, 7)
        _chips(far, t0 + np.sort(r.gamma(1.4, 0.08, k)),
               r.uniform(0.15, 0.35, k), np.full(k, pan), amp=0.5,
               dull=0.7, rng=r)
    m.y += 0.5 * _distant(far, 4500)
    m.room(t60=3.2, wet=0.45, darkness=2200)
    return _loop_out(m, -37.0)


CUES = {
    'sfx_dungeon_step_stone': dict(
        build=step_stone, variants=3,
        description='A padded foot on dressed stone, a little grit under it'),
    'sfx_dungeon_step_water': dict(
        build=step_water, variants=3,
        description='A foot into shallow water: plunge, slosh, trapped bubbles, drops'),
    'sfx_dungeon_interact': (
        interact, 'A touch on carved stone that gives a hair and catches'),
    'sfx_dungeon_switch': (
        switch, 'A mechanism turned one notch: stone pivot, pin into detent, its glass lit under'),
    'sfx_dungeon_block_move': (
        block_move, 'A stone block grinds one place along and settles'),
    'sfx_dungeon_gate_open': (
        gate_open, 'A catch lets go, a slab grinds clear shedding dust, and seats'),
    'sfx_dungeon_wall_break': (
        wall_break, 'Masonry cracks, falls in pieces, rubble scatters, dust hangs'),
    'sfx_dungeon_hazard_trigger': (
        hazard_trigger, 'A lurch of shifting stone and grit pouring down after it'),
    'sfx_dungeon_checkpoint': (
        checkpoint, 'A breath in and something set down gently on stone, warm glass under'),
    'sfx_dungeon_secret_reveal': (
        secret_reveal, 'A stone gives way to one side and a leaded piece lights up behind it'),
    'sfx_dungeon_puzzle_solved': (
        puzzle_solved, 'The room\'s mechanism travels and seats home; its leaded glass lights under it'),
    'sfx_dungeon_star_collect': (
        star_collect, 'A star drawn up on a breath and set into its stone socket, glass lit beneath'),
    'sfx_dungeon_relic_collect': (
        relic_collect, 'Old weight pressed into stone; deep leaded glass lights slowly under it'),
    'amb_dungeon_ruins_loop': dict(
        build=amb_ruins, loop=True,
        description='Stone ruins: still dark air, a wandering draught, grit and pebbles far off'),
    'amb_dungeon_water_loop': dict(
        build=amb_water, loop=True,
        description='Wet stone: a far trickle, slow lapping, drips into pools at no pace'),
    'amb_dungeon_fire_loop': dict(
        build=amb_fire, loop=True,
        description='Hot stone: a fire breathing in another chamber, embers cracking, heat ticks'),
    'amb_dungeon_arcane_loop': dict(
        build=amb_arcane, loop=True,
        description='Arcane stone: unpitched low resonance in the walls, air moving in a large room'),
}
