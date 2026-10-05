"""The material voices every cue is built from, and the rules they share.

  * grains  -- thousands of tiny resonant ticks, like sand poured or settling
  * glass   -- a struck or stroked glass body: inharmonic modes, each split
               into a slowly beating pair, the way a real glass rings
  * air     -- a breath of filtered noise that swells and goes
  * room    -- a short dark tail, so nothing sounds like it was made in a box

Family modules (tool/sounds/*.py) add their own voices where a moment is
made of something else -- metal, stone, wood, fire, water -- and each
exports CUES. Level every cue with Mix.finish(loudness_db=...): it measures
what a phone speaker plays (300 Hz - 8 kHz), not the peak.
"""
import math
from pathlib import Path

import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parents[2]
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
        levelling on it leaves the audible part quiet. fade_out=0 for a loop
        (it is joined with seamless_loop instead, and must not fade)."""
        y = self.y - self.y.mean(axis=1, keepdims=True)
        # Clean the very bottom: rumble no phone plays only eats headroom.
        sos = signal.butter(2, 45, btype='highpass', fs=SR, output='sos')
        y = signal.sosfilt(sos, y, axis=1)
        fade = round(fade_out * SR)
        if fade > 0:
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


def seamless_loop(y, xfade=1.5):
    """Folds the last [xfade] seconds of [y] over its start with an
    equal-power crossfade, so the result loops with no seam. Render a loop
    [xfade] seconds longer than it should play."""
    n = round(xfade * SR)
    head, body, tail = y[:, :n], y[:, n:-n], y[:, -n:]
    k = np.linspace(0, math.pi / 2, n)
    joined = tail * np.cos(k) + head * np.sin(k)
    return np.concatenate([joined, body], axis=1)
