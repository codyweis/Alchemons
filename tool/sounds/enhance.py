"""The Enhance screen (lib/screens/feeding/feeding_screen.dart): kin
sacrificed for experience, power orbs, potential souls, and the last level.

All four were silent: the pour, the orb's flight, the soul's whole rite --
even a Perfect Awakening, the dearest thing in the game -- played in
silence, and level 10 sounded like level 4. Each is scored to its own
animation (kin_pour.dart, infusion_particles.dart), with the timing named
where it comes from.
"""
import math

import numpy as np

from sounds.core import SR, Mix, smooth
from sounds.cosmic import _dark_glass, knock, roar, rush

# ---------------------------------------------------------------------------
# Kin pour (KinPour, _sacrifice): the pour runs (1150 + 170 * (kin - 1)) ms,
# clamped 1150-1900. Each kin comes apart head first over 0.28 of it (one
# after another, `stagger` apart), its grains arc over to the specimen in
# 0.42, and the last lands by 0.92. Then the flash (rewardCollect) takes over.
# ---------------------------------------------------------------------------


def _pour_timing(kin):
    stagger = min(0.14, 0.34 / kin)
    last = (kin - 1) * stagger + 0.28
    scale = min(1.0, (0.92 - 0.42) / max(0.01, last))
    duration = min(1.9, max(1.15, 1.15 + 0.17 * (kin - 1)))
    return stagger * scale, 0.28 * scale, duration


def kin_pour(kin):
    def build():
        stagger, apart, D = _pour_timing(kin)
        m = Mix(D + 0.35, seed=7100 + kin)
        t = m.t / D  # 0..1 over the pour
        grid = m.t
        # Grains coming apart (head down) and in flight, from the shared
        # leave times: each grain leaves at k*stagger + order*0.12*scale +
        # jitter, travels 0.42, lands.
        rng = np.random.default_rng(31 + kin)
        n = 900
        k = rng.integers(0, kin, n)
        leave = k * stagger + (rng.random(n) * apart)
        land = leave + 0.42
        leaving = np.histogram(leave, bins=len(t), range=(0, t[-1]))[0].astype(float)
        landing = np.histogram(land, bins=len(t), range=(0, t[-1]))[0].astype(float)
        flying = ((t[None, :] > leave[:, None]) & (t[None, :] < land[:, None])).mean(0)
        ker = np.exp(-0.5 * (np.arange(-300, 301) / 90.0) ** 2)
        ker /= ker.sum()
        leaving = np.convolve(leaving, ker, 'same')
        landing = np.convolve(landing, ker, 'same')
        leaving /= max(leaving.max(), 1e-9)
        landing /= max(landing.max(), 1e-9)
        flying /= max(flying.max(), 1e-9)

        def at(curve):
            return lambda tt: np.interp(tt, grid, curve)

        # The kin come apart where they sit in the tray, below and to the
        # sides: a fine crumble, spread across the field one after another.
        span = 0.5 if kin > 1 else 0.0
        side = np.interp(t, [0, 0.5], [-span, span])
        m.grains(at(1600 * leaving), lambda tt: 0.88 + 0 * tt,
                 lambda tt: np.interp(tt, grid, side), amp=0.5,
                 weight=lambda tt: 0.45 + 0 * tt)
        # In flight: a stream drawn up and over to the specimen, warming as
        # it nears (the grains warm toward the light).
        m.grains(at(1400 * flying), at(0.78 - 0.25 * flying),
                 lambda tt: 0.25 * np.sin(2 * math.pi * 0.8 * tt) * (1 - np.interp(tt, grid, t)),
                 amp=0.5, weight=at(0.45 + 0.3 * flying))
        # Landing in the body: a soft settle that thickens to the end.
        m.grains(at(2000 * landing), lambda tt: 0.42 + 0 * tt,
                 lambda tt: 0 * tt, amp=0.5, weight=at(0.5 + 0.35 * landing))
        m.air(0.0, D, 260, 2000, amp=0.025, rise=0.75)
        m.room(t60=0.9, wet=0.2)
        return m.finish(loudness_db=-31.0, fade_out=0.3)
    return build


# ---------------------------------------------------------------------------
# A power orb (_applyOrb): the tile lifts (190 ms, the sound starts after it),
# the orb lobs up and over into the specimen's heart over 520 ms
# (easeInOutCubic), then the power-up wave climbs the body over 560 ms.
# The orbs are dark glass with grains inside (power_orb.dart).
# ---------------------------------------------------------------------------

ORB_FLIGHT = 0.52
ORB_FLASH = 0.56


def orb(v=0):
    m = Mix(ORB_FLIGHT + ORB_FLASH + 0.5, seed=7200 + 13 * v)
    t = m.t
    x = np.clip(t / ORB_FLIGHT, 0, 1)
    pos = np.where(x < 0.5, 4 * x ** 3, 1 - (-2 * x + 2) ** 3 / 2)
    speed = np.gradient(pos, t)
    speed /= speed.max()
    grid = t

    def at(curve):
        return lambda tt: np.interp(tt, grid, curve)

    # The lob: air moving with it, from the lower right in to the centre.
    rush(m, 0.0, ORB_FLIGHT + 0.05,
         lambda tt: 900 + 900 * np.interp(tt, grid, speed),
         lambda tt: 0.022 * np.interp(tt, grid, speed) * smooth(tt, 0, 0.03),
         width_oct=0.8, spread=0.3,
         pan=lambda tt: 0.3 * (1 - np.interp(tt, grid, pos)))
    # The grains loose inside it, glinting as it turns.
    m.grains(at(220 * (x < 1)), lambda tt: 0.9 + 0 * tt,
             lambda tt: 0.3 * (1 - np.interp(tt, grid, pos)), amp=0.5,
             weight=lambda tt: 0.4 + 0 * tt)
    # Into the heart: the glass taken in, softly.
    knock(m, ORB_FLIGHT - 0.01, _dark_glass(m.rng, 420 * (1 + 0.03 * v), ring=0.35),
          amp=0.05, attack=0.012, tau=0.006, colour=2500, floor=250)
    # The power climbing the body: grains lifting, swelling, settling.
    u = np.clip((t - ORB_FLIGHT) / ORB_FLASH, 0, 1)
    swell = np.sin(math.pi * np.minimum(1.0, u / 0.85)) * (t > ORB_FLIGHT)
    m.grains(at(2800 * swell), at(0.55 + 0.3 * u),
             lambda tt: 0 * tt, amp=0.5, weight=at(0.45 + 0.35 * swell))
    m.air(ORB_FLIGHT, ORB_FLASH + 0.2, 300, 2400, amp=0.05, rise=0.45)
    m.room(t60=0.9, wet=0.22)
    return m.finish(loudness_db=-31.0, fade_out=0.3)


# ---------------------------------------------------------------------------
# A potential soul (_applySoul, _soulReveal): a spirit flame rises above the
# specimen's head (0-0.22 of the orb phase), hangs there burning brighter
# (to hangUntil), plunges in (easeInCubic), then the awakening flash climbs
# the body. Longer and brighter with the roll: tiers 1-5.
# ---------------------------------------------------------------------------

SOUL_TIERS = {
    1: dict(orb=2.10, flash=0.72, hang=0.78, glow=1.55),
    2: dict(orb=2.35, flash=0.84, hang=0.80, glow=1.8),
    3: dict(orb=2.65, flash=0.98, hang=0.83, glow=2.15),
    4: dict(orb=3.05, flash=1.20, hang=0.86, glow=2.7),
    5: dict(orb=3.60, flash=1.50, hang=0.89, glow=3.4),
}


def soul(tier):
    def build():
        T = SOUL_TIERS[tier]
        O, F, H = T['orb'], T['flash'], T['hang']
        jackpot = tier >= 3
        m = Mix(O + F + 1.2, seed=7300 + tier)
        t = m.t
        p = np.clip(t / O, 0, 1)
        grid = t
        rise_end, hang_end = 0.22 * O, H * O
        charge = smooth(p, 0.2, H)
        burning = (t < O).astype(float) * smooth(t, 0.0, 0.25)
        # The flame: catching as it rises, burning brighter the longer it
        # hangs, pulled long as it plunges.
        roar(m, 0.0, O + 0.05,
             lambda tt: np.interp(tt, grid, burning * (0.35 + 0.65 * charge)),
             amp=0.011 + 0.0015 * tier, body_lo=180, body_hi=1500, rasp=0.5,
             crackle=12 + 10 * tier, hiss=0.15)
        # Rising, and plunging: air that follows it.
        rush(m, 0.0, rise_end + 0.1,
             lambda tt: 700 + 900 * smooth(tt, 0, rise_end),
             lambda tt: 0.014 * smooth(tt, 0, 0.08) * (1 - smooth(tt, rise_end * 0.6, rise_end + 0.1)),
             width_oct=0.9, spread=0.4)
        plunge_len = O - hang_end
        rush(m, hang_end, plunge_len + 0.06,
             lambda tt: 600 + 2600 * (tt / max(plunge_len, 0.01)) ** 3,
             lambda tt: 0.06 * (tt / max(plunge_len, 0.01)) ** 2 * (tt < plunge_len),
             width_oct=0.9, spread=0.3)
        # The awakening: the soul taken into the heart. A low glass body
        # swelling (kept under), the specimen's grains thrown up and settling,
        # warm air -- bigger with the roll. A jackpot answers itself 110 ms
        # later (the screen's second thump).
        knock(m, O - 0.01, _dark_glass(m.rng, 300 - 15 * tier, ring=0.5 + 0.15 * tier),
              amp=0.05 + 0.012 * tier, attack=0.02, tau=0.01, colour=2200, floor=180)
        u = np.clip((t - O) / F, 0, 1)
        swell = np.sin(math.pi * np.minimum(1.0, u / 0.85)) * (t > O)
        m.grains(lambda tt: np.interp(tt, grid, (2200 + 700 * tier) * swell),
                 lambda tt: np.interp(tt, grid, 0.5 + 0.35 * u),
                 lambda tt: 0.35 * np.sin(2 * math.pi * 0.7 * tt), amp=0.5,
                 weight=lambda tt: np.interp(tt, grid, 0.5 + 0.35 * swell))
        m.air(O - 0.05, F + 0.6, 260, 2600, amp=0.05 + 0.012 * tier, rise=0.35)
        if jackpot:
            m.air(O + 0.11, F + 0.5, 220, 1800, amp=0.025 + 0.008 * tier, rise=0.25)
            m.grains(lambda tt: np.where(tt > O + 0.11, 900 * np.exp(-(tt - O - 0.11) / 0.25), 0),
                     lambda tt: 0.4 + 0 * tt, lambda tt: 0 * tt, amp=0.5,
                     weight=lambda tt: 0.55 + 0 * tt)
        m.room(t60=1.2 + 0.15 * tier, wet=0.24)
        return m.finish(loudness_db=-30.5 + 0.5 * tier, fade_out=0.5)
    return build


# ---------------------------------------------------------------------------
# The last level (AlchemonStatSystem.maxLevel = 10): played on the tick the
# count-up reaches it, in place of the ordinary level-up. The specimen is
# complete: a fuller settle into the room, a warm low bloom.
# ---------------------------------------------------------------------------


def max_level():
    m = Mix(2.4, seed=7400)
    t = m.t
    # Everything it was given settling into it at once.
    for side in (-0.5, 0.0, 0.5):
        m.grains(lambda tt: 1300 * smooth(tt, 0, 0.18) * np.exp(-np.maximum(tt - 0.18, 0) / 0.35),
                 lambda tt: 0.5 - 0.15 * smooth(tt, 0, 0.6),
                 lambda tt, side=side: side * (1 - smooth(tt, 0, 0.5)), amp=0.5,
                 weight=lambda tt: 0.55 + 0 * tt)
    # A warm flame catching in it, held a moment.
    roar(m, 0.1, 1.2, lambda u: smooth(u, 0, 0.12) * np.exp(-np.maximum(u - 0.15, 0) / 0.4),
         amp=0.05, body_lo=160, body_hi=1300, rasp=0.4, crackle=25, hiss=0.12)
    # Two low glass bodies blooming under it -- weight, not a chime.
    knock(m, 0.16, _dark_glass(m.rng, 233, ring=1.4), amp=0.05, attack=0.05,
          tau=0.012, colour=2000, floor=160)
    knock(m, 0.18, _dark_glass(m.rng, 347, ring=1.0), amp=0.035, attack=0.05,
          tau=0.012, colour=2400, floor=200)
    m.air(0.0, 1.8, 240, 2200, amp=0.04, rise=0.2)
    m.room(t60=1.7, wet=0.28)
    return m.finish(loudness_db=-30.0, fade_out=0.5)


CUES = {
    **{f'sfx_enhance_pour_{k}': (kin_pour(k), f'{k} kin coming apart and pouring into the specimen ({_pour_timing(k)[2]:.2f} s pour)')
       for k in range(1, 7)},
    'sfx_enhance_orb': {
        'build': orb,
        'description': 'A dark-glass power orb lobbed in, taken into the heart, its power climbing the body',
        'variants': 3,
    },
    **{f'sfx_enhance_soul_{k}': (soul(k), f'A potential soul, roll {k}: rises burning, hangs, plunges in, the awakening')
       for k in range(1, 6)},
    'sfx_enhance_max_level': (max_level, 'Level 10: everything it was given settling in, a warm catch, a low bloom'),
}
