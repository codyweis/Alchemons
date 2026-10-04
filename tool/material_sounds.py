"""Sound effects built from materials: grains, glass, air, room.

The older generator (generate_sound_library.py) builds its cues from clean
sine tones, pitch sweeps and note runs, which is what makes them read as
bleeps and jingles. Everything here is made from things the game's screens
are made of instead:

  * grains  -- thousands of tiny resonant ticks, like sand poured or settling
  * glass   -- a struck glass body: inharmonic modes, each one split into a
               slowly beating pair, the way a real glass rings
  * room    -- a short dark tail, so nothing sounds like it was made in a box

No melodies, no musical intervals, no success chimes. Each cue is scored to
what its screen actually does, with the timing written next to it.

Run with NumPy + SciPy:  python tool/material_sounds.py [name ...]
Writes the WAVs into assets/audio/sounds/ and updates their manifest rows.
"""
import argparse
import hashlib
import json
import math
import wave
from pathlib import Path

import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/sounds'
SR = 48000


class Mix:
    """A stereo buffer with material voices written into it."""

    def __init__(self, duration, seed):
        self.n = round(duration * SR)
        self.t = np.arange(self.n) / SR
        self.y = np.zeros((2, self.n))
        self.rng = np.random.default_rng(seed)

    def _at(self, start):
        return min(self.n, max(0, round(start * SR)))

    # -- grains -------------------------------------------------------------

    def grains(self, density, brightness, pan, amp=1.0, weight=None):
        """Poured or settling grains.

        density(t)    grains per second at each moment
        brightness(t) 0..1, where the grains' ring sits: 0 coarse, 1 fine
        pan(t)        -1..1, where the stream is; each grain scatters around it
        weight(t)     optional per-grain loudness envelope (default flat)

        Each grain is one impulse rung through a band; the bands are spread
        from coarse to fine and brightness decides which band a grain lands
        in, so a stream can cool or warm as it moves.
        """
        t = self.t
        rate = np.maximum(density(t), 0) / SR
        hits = self.rng.poisson(rate)
        idx = np.nonzero(hits)[0]
        if not len(idx):
            return self
        # Grain sizes are lopsided: mostly small, a few big enough to tick.
        # Capped: an outlier grain is a click that sticks out of the stream.
        size = np.minimum(self.rng.lognormal(-0.2, 0.75, len(idx)), 2.4) * hits[idx]
        if weight is not None:
            size *= weight(t[idx])
        bands = np.array([900, 1400, 2100, 3100, 4500, 6400, 9000])
        b = brightness(t[idx])
        centre = b * (len(bands) - 1)
        choice = np.clip(
            np.round(centre + self.rng.normal(0, 1.1, len(idx))),
            0, len(bands) - 1,
        ).astype(int)
        # Coarser grains are heavier: a touch louder.
        size *= 1.25 - 0.08 * choice
        p = np.clip(pan(t[idx]) + self.rng.normal(0, 0.35, len(idx)), -1, 1)
        gl = np.cos((p + 1) * math.pi / 4)
        gr = np.sin((p + 1) * math.pi / 4)
        for k, fc in enumerate(bands):
            sel = choice == k
            if not sel.any():
                continue
            imp = np.zeros((2, self.n))
            imp[0, idx[sel]] = size[sel] * gl[sel]
            imp[1, idx[sel]] = size[sel] * gr[sel]
            q = 4.5
            sos = signal.butter(
                2, [fc / (1 + 0.5 / q), fc * (1 + 0.5 / q)],
                btype='bandpass', fs=SR, output='sos',
            )
            self.y += amp * 0.9 * signal.sosfilt(sos, imp, axis=1)
        return self

    # -- glass --------------------------------------------------------------

    def glass(self, start, f0, amp=1.0, ring=1.2, attack=0.004,
              brightness=0.5, pan=0.0, beat=1.3, ratios=None):
        """A glass body struck (or, with a slow attack, stroked).

        The modes are a wine glass's, not a harmonic series, so it never
        reads as a note on an instrument. Each mode is a close pair that
        beats slowly against itself, which is the shimmer a real glass has
        and a sine never does.
        """
        ratios = ratios or [1.0, 2.32, 4.25, 6.63, 9.38]
        s0 = self._at(start)
        t = self.t[s0:] - start
        env_in = np.clip(t / attack, 0, 1) ** 2 if attack > 0 else 1
        out = np.zeros(len(t))
        for k, r in enumerate(ratios):
            f = f0 * r
            if f > SR * 0.45:
                break
            weight = math.exp(-k * (1.6 - 1.2 * brightness)) / (1 + 0.4 * k)
            t60 = ring / (1 + 0.9 * k)
            env = np.exp(-6.9 * t / t60)
            b = beat * (0.6 + 0.5 * self.rng.random())
            ph1, ph2 = self.rng.random(2) * 2 * math.pi
            mode = (np.sin(2 * math.pi * (f - b / 2) * t + ph1)
                    + 0.8 * np.sin(2 * math.pi * (f + b / 2) * t + ph2))
            out += weight * env * mode
        out *= env_in * amp * 0.5
        self._place(s0, out, pan)
        return self

    # -- air ----------------------------------------------------------------

    def air(self, start, length, low, high, amp=1.0, rise=0.5, pan=0.0):
        """A breath of filtered air that swells and goes, no tone in it."""
        s0 = self._at(start)
        e0 = self._at(start + length)
        t = self.t[s0:e0] - start
        x = t / length
        env = np.where(x < rise, (x / rise) ** 2,
                       np.cos((x - rise) / (1 - rise) * math.pi / 2) ** 2)
        sos = signal.butter(2, [low, high], btype='bandpass', fs=SR, output='sos')
        for ch, g in enumerate(self._gains(pan)):
            noise = signal.sosfilt(sos, self.rng.normal(0, 1, len(t)))
            self.y[ch, s0:e0] += amp * g * env * noise
        return self

    # -- room ---------------------------------------------------------------

    def room(self, t60=1.1, wet=0.2, darkness=4200):
        """A dark, short tail behind everything: decorrelated per side."""
        length = round(t60 * 1.2 * SR)
        tt = np.arange(length) / SR
        decay = np.exp(-6.9 * tt / t60)
        sos = signal.butter(2, darkness, btype='lowpass', fs=SR, output='sos')
        wet_y = np.zeros_like(self.y)
        for ch in range(2):
            ir = signal.sosfilt(sos, self.rng.normal(0, 1, length)) * decay
            ir[: round(0.012 * SR)] = 0  # predelay: the room answers, not doubles
            ir /= np.sqrt(np.sum(ir ** 2))
            wet_y[ch] = signal.fftconvolve(self.y[ch], ir)[: self.n]
        self.y = self.y + wet * wet_y
        return self

    # -- helpers ------------------------------------------------------------

    @staticmethod
    def _gains(pan):
        return math.cos((pan + 1) * math.pi / 4), math.sin((pan + 1) * math.pi / 4)

    def _place(self, s0, mono, pan):
        gl, gr = self._gains(pan)
        self.y[0, s0:s0 + len(mono)] += gl * mono
        self.y[1, s0:s0 + len(mono)] += gr * mono

    def finish(self, loudness_db, fade_out=0.25):
        """Level by what a phone speaker plays (300 Hz - 8 kHz RMS), not by
        peak: a peak is usually low end the speaker never reproduces, and
        levelling on it leaves the audible part quiet."""
        y = self.y - self.y.mean(axis=1, keepdims=True)
        # Clean the very bottom: rumble no phone plays only eats headroom.
        sos = signal.butter(2, 45, btype='highpass', fs=SR, output='sos')
        y = signal.sosfilt(sos, y, axis=1)
        fade = round(fade_out * SR)
        y[:, -fade:] *= np.cos(np.linspace(0, math.pi / 2, fade)) ** 2
        y[:, :48] *= np.linspace(0, 1, 48)
        band = signal.butter(4, [300, 8000], btype='bandpass', fs=SR, output='sos')
        heard = np.sqrt(np.mean(signal.sosfilt(band, y, axis=1) ** 2))
        y *= 10 ** (loudness_db / 20) / heard
        assert np.max(np.abs(y)) < 10 ** (-3 / 20), 'too hot: lower the loudness'
        return y


def smooth(x, a, b):
    """0 before a, 1 after b, an S between."""
    u = np.clip((x - a) / (b - a), 0, 1)
    return u * u * (3 - 2 * u)


# ===========================================================================
# Extraction reveal -- ExtractionResultCard
# ===========================================================================
#
# What the card shows (ElementalEssence.reveal, from the moment it is let go):
#   * the specimen's element form is already up as grains,
#   * they swirl home along a curve, feet first, cooling from the element's
#     shades into the creature's own colours,
#   * they LAND (the card's lock, below) and the sprite comes back under them.
#
# A rare specimen (new discovery, prismatic, mutation, legendary, mystic) gets
# a held beat of empty, lit stage before the grains appear.
#
# The sound follows that and nothing else: a stream that moves and cools, one
# settle when it lands, the glass the specimen now sits in. No scan, no data,
# no note run.

REVEAL_LAND = 1.20       # ordinary: grains appear at once and land here
RARE_HOLD = 0.57         # rare: the empty lit stage before grains appear
RARE_LAND = RARE_HOLD + REVEAL_LAND


def _reveal(m, appear, land, rare):
    span = land - appear

    def density(t):
        # A soft stream that thickens as it gathers, a quick press at the
        # landing, then the last few grains finding their places.
        gather = smooth(t, appear - 0.05, appear + 0.18) * (
            700 + 2600 * smooth(t, appear, land))
        settle = np.where(t > land, 6500 * np.exp(-(t - land) / 0.13), 0)
        stray = np.where(t > land, 260 * np.exp(-(t - land) / 0.55), 0)
        return np.where(t < land, gather, settle + stray)

    def bright(t):
        # Hot element shades to the creature's own colours: fine to coarse.
        # The settle itself is the coarsest moment: grains on grains.
        cool = 0.78 - 0.42 * smooth(t, appear, land + 0.1)
        return cool - 0.14 * np.exp(-np.abs(t - land - 0.04) / 0.08)

    def pan(t):
        # The swirl home: the stream crosses the field and tightens to centre.
        u = np.clip((t - appear) / span, 0, 1)
        return 0.55 * (1 - u) * np.sin(2 * math.pi * 0.85 * u + 0.6)

    def weight(t):
        # The stream is quiet while it travels; the settle carries the weight.
        travel = 0.75 + 0.45 * smooth(t, appear, land)
        return np.where(t < land, travel, 1.0)

    m.air(appear - 0.04, span + 0.3, 350, 2600, amp=0.05, rise=0.82)
    m.grains(density, bright, pan, amp=0.55, weight=weight)
    # The landing is the grains settling, not a hit: a dense, coarse patter
    # (above) inside a hush that leans in and lets go. No drum, no thump.
    m.air(land - 0.16, 0.62, 220, 1500, amp=0.10 if not rare else 0.13,
          rise=0.28)
    # The glass the specimen now stands in: struck softly, low, short.
    m.glass(land, 452, amp=0.17, ring=1.15, attack=0.006, brightness=0.5,
            pan=-0.08, beat=1.1)
    if rare:
        # A second, larger body under the first: more weight, not more notes.
        m.glass(land + 0.004, 287, amp=0.14, ring=2.0, attack=0.012,
                brightness=0.25, pan=0.1, beat=0.7,
                ratios=[1.0, 2.19, 3.89, 5.91])


def reveal_ordinary():
    m = Mix(2.3, seed=4101)
    _reveal(m, appear=0.0, land=REVEAL_LAND, rare=False)
    m.room(t60=1.0, wet=0.22)
    return m.finish(loudness_db=-29.0, fade_out=0.35)


def reveal_rare():
    m = Mix(3.3, seed=4102)
    # The held beat: the lit stage is charged before anything is on it. A
    # stroked glass, almost under hearing, and a breath that leans in.
    m.glass(0.0, 287, amp=0.05, ring=3.0, attack=0.45, brightness=0.1,
            beat=0.5, ratios=[1.0, 2.19, 3.89])
    m.air(0.0, RARE_HOLD + 0.25, 180, 900, amp=0.07, rise=0.9)
    _reveal(m, appear=RARE_HOLD, land=RARE_LAND, rare=True)
    m.room(t60=1.4, wet=0.25)
    return m.finish(loudness_db=-31.0, fade_out=0.45)  # the quiet held beat pulls the average down


# ===========================================================================
# Extraction ceremony -- HatchingCinematic + HatchShell
# ===========================================================================
#
# One cue for the whole ceremony, so it cannot drift from itself, and scored
# from the animation's OWN motion: _shell_score() below ports the shell's
# per-strand timing (the same hash, constants and easings as hatch_shell.dart
# and hatching_cinematic.dart) and measures how fast everything is moving at
# every millisecond. Grains are as loud and as dense as the particles are
# fast, so the sound moves when -- and only when -- the picture does.
#
# What that gives, in wall-clock seconds (the shell's arc runs over 0.88 of
# the 7 s ceremony, so a shell fraction f lands at f * 6.16 s):
#
#   0    - 1.05  two still clusters of motes, one per parent (A right, B left)
#   1.05 - 1.85  the motes sprout into strands, busiest at 1.6, then stop
#   1.85 - 2.3   almost nothing moves
#   2.3  - 4.25  the strands swirl in, fastest at 3.3, slowing to rest at 4.25
#   4.25 - 4.99  the shell CINCHES: in fast, deepest at 4.62, back out
#   4.9  - 5.85  the newborn's grains leave the shell and land head first,
#                most of them around 5.6
#   5.24 - 6.05  the shell unravels, slow at first and accelerating
#   5.88 - 6.05  everything dissolves; the cue is RELEASED at the handover
#                and its ringing tail carries on under the result card
#
# The same language as the reveal that follows it -- grains, glass, air -- so
# the two read as one moment. No riser, no hit, no drum.

_SHELL = 0.88 * 7.0
CINCH = 0.69 * _SHELL
UNRAVEL = 0.85 * _SHELL
DISSOLVE = 0.840 * 7.0
HANDOVER = 0.865 * 7.0

# A typical species' strand count at tube density (92 strands x 2.1). The
# hash spreads strands evenly, so a few more or less change nothing audible.
_STRANDS = 193


def _shell_score(t):
    """How fast each part of the ceremony is moving at times [t] (seconds).

    Every curve is a sum of per-element speeds, normalised to peak 1 over the
    ceremony, so the shape is the animation's and the level is the mix's.
    """
    def h(i, salt):  # hatch_shell.dart's _h
        v = np.sin(i * 127.1 + salt * 311.7) * 43758.5453
        return v - np.floor(v)

    def ease_out(x):
        return 1 - (1 - x) ** 3

    def ease_in(x):
        return x ** 3

    def ease_in_out(x):
        return np.where(x < 0.5, 4 * x ** 3, 1 - (-2 * x + 2) ** 3 / 2)

    def speed(f):
        return np.abs(np.gradient(f, t, axis=-1))

    # HatchShellTuning
    mote_hold, string_by, sprout_stagger = 0.17, 0.33, 0.56
    converge_end, stagger, unravel_at = 0.69, 0.33, 0.85
    cinch_span, overshoot = 0.12, 0.18

    k = np.arange(_STRANDS)
    g_lead, t0 = h(k, 18), h(k, 6)
    group_b = h(k, 14) >= 0.5
    u = t / _SHELL
    g_total = string_by - mote_hold
    g_dur = g_total * (1 - sprout_stagger)

    sprout = np.zeros((2, len(t)))
    converge = np.zeros((2, len(t)))
    gathered = np.zeros((2, len(t)))
    unravel = np.zeros(len(t))
    for i in k:
        side = int(group_b[i])
        g_start = mote_hold + g_lead[i] * g_total * sprout_stagger
        g_end = g_start + g_dur
        sprout[side] += speed(ease_out(np.clip((u - g_start) / g_dur, 0, 1)))
        window = converge_end - g_end
        lead = g_end + t0[i] * stagger * window
        span = window * (1 - t0[i] * stagger)
        form = ease_in_out(np.clip((u - lead) / span, 0, 1))
        converge[side] += speed(form)
        gathered[side] += form
        unrav = ease_in(np.clip(
            (u - unravel_at) / (1 - unravel_at) - t0[i] * 0.25, 0, 1))
        # A strand fades as it unravels (culled at 0.88), so what you see
        # moving is its speed times what is left of it.
        unravel += speed(unrav) * np.clip(1 - unrav / 0.88, 0, 1)
    counts = np.array([np.sum(~group_b), np.sum(group_b)])[:, None]
    gathered /= counts

    # The cinch: one shared overshoot, sin-shaped over 0.12 of the shell.
    x = (u - converge_end) / cinch_span
    cinch = speed(np.where((x > 0) & (x < 1),
                           np.sin(x * np.pi) * overshoot, 0))

    # The newborn's grains (hatching_cinematic.dart, _SilhouetteGrains):
    # each leaves on its own clock, head first, and eases home.
    rng = np.random.default_rng(7)
    n = 2400
    delay = 0.6 * rng.random(n) + 0.4 * rng.random(n)
    gather_span = (0.835 - 0.70) * 7.0
    leave = 0.70 * 7.0 + 0.45 * delay * gather_span
    fly = 0.55 * gather_span
    landing = leave + fly
    newborn = np.zeros(len(t))
    for c in np.array_split(np.arange(n), 12):
        p = np.clip((t[None, :] - leave[c, None]) / fly, 0, 1)
        newborn += speed(ease_in_out(p)).sum(0)
    # How many land in each moment: a smoothed arrival rate.
    hist, edges = np.histogram(landing, bins=len(t), range=(t[0], t[-1]))
    kernel = np.exp(-0.5 * (np.arange(-120, 121) / 40.0) ** 2)
    lands = np.convolve(hist, kernel / kernel.sum(), mode='same')

    def norm(c):
        return c / max(np.max(c), 1e-9)

    sprout_peak = max(sprout.max(), 1e-9)
    converge_peak = max(converge.max(), 1e-9)
    return dict(
        sprout=sprout / sprout_peak, converge=converge / converge_peak,
        gathered=gathered, cinch=norm(cinch), newborn=norm(newborn),
        lands=norm(lands), unravel=norm(unravel),
    )


# How long the cue rings on past the handover. HatchingCinematic releases it
# there instead of cutting it, so this tail plays under the result card
# coming up and meets the reveal's own grains.
TAIL = 1.1


def ceremony():
    m = Mix(HANDOVER + TAIL, seed=4201)
    T = np.arange(0, m.n) / SR
    step = 0.002
    grid = np.arange(0, T[-1] + step, step)
    sc = _shell_score(grid)

    def at(curve):
        return lambda t: np.interp(t, grid, curve)

    rng = np.random.default_rng(4202)
    for side_i, side in enumerate((1.0, -1.0)):  # A right, B left
        sprout = sc['sprout'][side_i]
        converge = sc['converge'][side_i]
        gathered = sc['gathered'][side_i]
        phase = rng.uniform(0, 2 * math.pi)
        # Strands drawing out are thin and quick; strands swirling in carry
        # weight. Motes alone barely tick.
        density = at(30 + 1500 * sprout + 2100 * converge)
        level = at(0.5 + 0.15 * sprout + 0.35 * converge)
        bright = at(0.9 - 0.08 * sprout - 0.12 * converge)

        def pan(t, gathered=gathered, phase=phase, side=side):
            # Each parent's side, swirling, drawn to the centre exactly as
            # its strands arrive.
            g = np.interp(t, grid, gathered)
            swirl = 0.3 * np.sin(2 * math.pi * 0.7 * t + phase) * g * (1 - g) * 4
            return side * 0.62 * (1 - g) + swirl

        m.grains(density, bright, pan, amp=0.5, weight=level)

    # The cinch: the shell squeezes and lets go. Darker grains, at the
    # centre, as fast as the squeeze.
    m.grains(at(1100 * sc['cinch']), lambda t: 0.25 + 0 * t,
             lambda t: 0 * t, amp=0.5, weight=at(0.5 + 0.4 * sc['cinch']))

    # The newborn's grains streaming in from the shell, then landing:
    # the same settle as the card's reveal, so the two are one gesture.
    m.grains(at(2200 * sc['newborn']), at(0.72 - 0.2 * sc['lands']),
             lambda t: 0.12 * np.sin(2 * math.pi * 1.3 * t), amp=0.5,
             weight=at(0.55 + 0.25 * sc['newborn']))
    m.grains(at(2600 * sc['lands']), lambda t: 0.28 + 0 * t,
             lambda t: 0 * t, amp=0.5, weight=at(0.6 + 0.4 * sc['lands']))

    # The unravel, flying out to both sides as it speeds up.
    for side in (0.8, -0.8):
        m.grains(at(1500 * sc['unravel']), lambda t: 0.86 + 0 * t,
                 lambda t, side=side: side + 0 * t, amp=0.5,
                 weight=at(0.5 + 0.3 * sc['unravel']))

    # Everything moving goes with the picture: it dissolves linearly over
    # 5.88 - 6.05. Only what rings (below) carries on into the card.
    m.y *= np.clip((HANDOVER - T) / (HANDOVER - DISSOLVE), 0, 1)

    # The last of the newborn's grains finding their places, on into the
    # card's first moment, where the reveal's own grains take over.
    m.grains(lambda t: np.where(t > 5.8, 260 * np.exp(-(t - 5.8) / 0.4), 0),
             lambda t: 0.3 + 0 * t, lambda t: 0 * t, amp=0.5,
             weight=lambda t: 0.55 + 0 * t)

    # Air: a bed from the start; it leans in with the swirl and lets go with
    # the unravel.
    m.air(0.0, HANDOVER, 300, 2800, amp=0.02, rise=0.55)
    m.air(2.3, 2.2, 240, 1700, amp=0.05, rise=0.45)
    m.air(UNRAVEL, HANDOVER - UNRAVEL, 600, 4800, amp=0.05, rise=0.85)
    # The breath out that carries across the handover.
    m.air(5.6, HANDOVER + TAIL - 5.6, 280, 2000, amp=0.045, rise=0.28)

    # Each parent's glass, stroked so slowly it is barely a note, swelling
    # with its swirl and letting go as the strands come to rest.
    m.glass(2.2, 241, amp=0.045, ring=3.0, attack=1.1,
            brightness=0.15, pan=0.5, beat=0.6, ratios=[1.0, 2.32, 4.25])
    m.glass(2.35, 263, amp=0.04, ring=3.0, attack=1.0,
            brightness=0.15, pan=-0.5, beat=0.5, ratios=[1.0, 2.32, 4.25])
    # The shell, one body, pressed by its own cinch.
    # A swell, not a strike: a quick low glass reads as a bong, and a bong
    # is a drum.
    m.glass(CINCH, 196, amp=0.09, ring=2.2, attack=0.16, brightness=0.3,
            beat=0.8, ratios=[1.0, 2.19, 3.89, 5.91])
    # The newborn's glass blooms as its grains come home, and is still
    # ringing as the card arrives.
    m.glass(5.38, 338, amp=0.12, ring=2.6, attack=0.12, brightness=0.45,
            beat=1.1)

    m.room(t60=1.3, wet=0.22)
    return m.finish(loudness_db=-28.0, fade_out=0.5)


CUES = {
    'sfx_extraction_ceremony': (
        ceremony,
        'Two parents\' grains gather into one shell, settle as it cinches, and ring it open as it unravels',
    ),
    'sfx_extraction_creature_reveal': (
        reveal_ordinary,
        'Grains swirl home and settle with a soft weight; a low glass rings once',
    ),
    'sfx_extraction_rare_reveal': (
        reveal_rare,
        'A held, charged beat, then grains swirl home and settle into two glass bodies',
    ),
}


# ===========================================================================


def write_wav(path, y):
    pcm = np.round(np.clip(y, -1, 1) * 32767).astype('<i2').T.copy()
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('names', nargs='*', help='cues to render (default all)')
    args = parser.parse_args()
    names = args.names or list(CUES)
    manifest_path = OUT / 'sound_manifest.json'
    rows = json.loads(manifest_path.read_text(encoding='utf-8'))
    by_name = {r['name']: r for r in rows}
    for name in names:
        build, description = CUES[name]
        y = build()
        assert np.isfinite(y).all() and np.max(np.abs(y)) < 0.99, name
        path = OUT / (name + '.wav')
        write_wav(path, y)
        row = by_name.get(name)
        if row is None:
            row = {'name': name, 'category': 'Alchemical extraction'}
            rows.append(row)
        row.update(
            description=description,
            path=path.relative_to(ROOT).as_posix(),
            duration=round(y.shape[1] / SR, 3),
            loop=False,
            peak_db=round(20 * math.log10(np.max(np.abs(y))), 2),
            rms_db=round(20 * math.log10(np.sqrt(np.mean(y ** 2))), 2),
            sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            source='tool/material_sounds.py',
        )
        print(f"{name}: {row['duration']}s peak {row['peak_db']} dB rms {row['rms_db']} dB")
    manifest_path.write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
