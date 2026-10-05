"""Interface: the two small UI cues that are still played (confirm, denied),
the Mystic Altar's rite (boss_altar_detail_screen.dart), and the Harvest
screen's room tone. The struck-material voices are tool/sounds/rewards.py's."""
import math

import numpy as np
from scipy import signal

from sounds.core import SR, Mix, seamless_loop, smooth
from sounds.rewards import (STONE, brass, crackle, fibre, flare, friction,
                            strike, wood)

# ===========================================================================
# UI -- uiConfirm (the boss altar's fallback when an element has no cue of
# its own) and uiDenied (black market, shop, Harvest screen, a locked nav
# tab, a refused dungeon press)
# ===========================================================================
#
# Both were approved in September as small, unobtrusive two-part sounds;
# they keep that size and shape, made of a latch instead of tones. Confirm
# is a latch catching: a light touch, then the bolt seating. Denied is the
# same latch, locked: the bolt knocks against its keeper twice and does not
# give -- muffled, a soft refusal, never a buzzer.


def ui_confirm():
    """A latch catching: a light brass touch, then the bolt seats."""
    m = Mix(0.3, seed=4901)
    brass(m, 0.008, 4100, amp=0.35, ring=0.025, contact=0.00012)
    brass(m, 0.068, 3300, amp=0.8, ring=0.03)
    # The frame it seats in.
    wood(m, 0.068, f0=520, amp=0.25, ring=0.03, contact=0.0008)
    m.room(t60=0.3, wet=0.08, darkness=4200)
    return m.finish(loudness_db=-34.0, fade_out=0.08)


def ui_denied():
    """A locked latch tried: the bolt knocks its keeper twice, dull, and
    does not give."""
    m = Mix(0.34, seed=4902)
    for at, a in ((0.01, 1.0), (0.105, 0.7)):
        # Wood and a dull bit of metal, both muffled: soft contacts, short.
        wood(m, at, f0=470, amp=0.9 * a, ring=0.035, contact=0.0016, lean=0.004)
        strike(m, at + 0.001, 1500, [1.0, 1.58, 2.71], ring=0.03, amp=0.9 * a,
               contact=0.0009, tilt=0.6, lean=0.003)
        fibre(m, at, 0.03, 300, 1400, 0.8 * a)
    m.room(t60=0.3, wet=0.1, darkness=3000)
    return m.finish(loudness_db=-34.5, fade_out=0.08)


# ===========================================================================
# The Mystic Altar -- boss_altar_detail_screen.dart + altar_rite_field.dart
# ===========================================================================
#
# One Mystic's altar: its offerings stand round it as grains, and the rite
# (field.summon, in seconds, a real clock) does this:
#
#   0    - 1.7   pour: every given offering pours from its seat into the
#                middle, each a beat behind the last (seat i over
#                i*0.06 .. 1.1 + i*0.06); the relic rises in from below
#                (0.25 - 1.35); the room darkens (0.4 - 1.8)
#   0.7  - 2.7   the knot: it grows (0.7 - 1.5) and is squeezed (1.2 - 2.7),
#                shivering (sin(26 s): ~4.1 Hz) and spinning faster
#                (2 + 9*squeeze rad/s), heating toward white (1.0 - 2.7);
#                the circle of ash is drawn into it (crush, 0.9 - 2.7); the
#                screen's haptics quicken: 1.0, 1.6, 2.05, 2.4
#   2.7          the knot bursts: a spray of grains thrown out, slowing
#                (1 - e^(-4.6 b)), white for a breath, cooling over 0.7 s;
#                every fifth an ember that runs on and cools over 1.5 s;
#                a flash, e^(-3.2 b); the room lifts (2.7 - 3.9)
#   2.8  - 5.0   the Mystic comes as its element and gathers into itself
#   5.16         awake (formEnd + 0.15): the card fades in over 0.9 s
#   tap          SEAL AND DEPART: it folds into a sphere of its grains
#                (0 - 0.74 s), and the sphere drops away (0.74 - 1.35 s)
#
# Three cues for three moments the player causes: the rite (it used to be
# extractionReactionStart + extractionReactionBurst, two loose sounds from
# the old hatchery), the waking, and the sealing. The rite is one sound so
# the burst can never drift from the knot it bursts out of. A tap after the
# burst hurries the form along, so nothing is scored past ~3.6 s but the
# burst's own embers.

POUR_END = 1.7
KNOT_END = 2.7
BEATS = (1.0, 1.6, 2.05, 2.4)   # _riteBeats' haptics, before the burst
SEAL_FOLD = 0.55 * 1.35         # seal 0..0.55 of its 1.35 s
SEAL_END = 1.35


def _bell(t, a, b):
    """How fast a smoothstep from a to b is moving at t (peak 1)."""
    u = np.clip((t - a) / (b - a), 0, 1)
    return 4 * u * (1 - u) * ((t > a) & (t < b))


def altar_rite():
    """The rite, whole: the offerings pour into the middle, are crushed into
    a shivering, heating knot, and it bursts."""
    m = Mix(4.6, seed=4911)
    burst = KNOT_END

    # -- the pour: one stream per seat, from round the circle to the middle.
    seats = 7
    for i in range(seats):
        a, b = i * 0.06, 1.1 + i * 0.06
        side = 0.85 * math.cos(2 * math.pi * i / seats + 0.4)
        m.grains(lambda t, a=a, b=b: 900 * _bell(t, a, b),
                 lambda t: 0.66 + 0 * t,
                 lambda t, a=a, b=b, side=side: side * (1 - smooth(t, a, b)),
                 amp=0.5, weight=lambda t: 0.4 + 0 * t)
    # The relic rises in from under the Mystic: coarser, heavier grains.
    m.grains(lambda t: 1100 * _bell(t, 0.25, 1.35), lambda t: 0.38 + 0 * t,
             lambda t: 0 * t, amp=0.5, weight=lambda t: 0.5 + 0 * t)
    # The room darkening: a low held breath, under everything until the
    # burst lets it out.
    m.air(0.35, burst - 0.3, 110, 620, amp=0.045, rise=0.93)

    # -- the knot: grains crushed together, shivering and spinning.
    def squeeze(t):
        return smooth(t, 1.2, burst)

    def heat(t):
        return smooth(t, 1.0, burst)

    def beats(t):
        # The quickening pulse the screen's haptics play: each a swell of
        # the knot's own texture, never a thump.
        out = 0 * t
        for b in BEATS:
            d = t - b
            out = out + np.where(d > 0, smooth(d, 0, 0.025) * np.exp(-d / 0.12), 0)
        return out

    def knot(t):
        grow = smooth(t, 0.7, 1.5)
        shiver = 1 + 0.45 * squeeze(t) * np.sin(26 * t)
        return (np.where(t < burst, 1, 0) * grow * shiver
                * (1300 + 2400 * squeeze(t)) * (1 + 0.55 * beats(t)))

    def spin_pan(t):
        # The knot turns faster as it is squeezed: 2 + 9*squeeze rad/s.
        phase = 2 * t + 9 * np.cumsum(squeeze(t)) / SR
        return 0.3 * np.sin(phase) * (1 - 0.4 * squeeze(t))

    m.grains(knot, lambda t: 0.3 + 0.32 * heat(t), spin_pan, amp=0.5,
             weight=lambda t: 0.5 + 0.2 * squeeze(t))
    # Crushed: grains grinding on grains under the squeeze.
    friction(m, 1.15, burst - 1.15,
             lambda t: 2600 * smooth(t, 0, 1.4) * (1 + 0.5 * np.sin(26 * (t + 1.15))),
             760, STONE, ring=0.02, amp=0.7, contact=0.0004, rub=0.4,
             rub_band=(300, 1800))
    # The circle of ash drawn in from wide, finer, while the knot is crushed.
    for side in (-0.9, 0.9):
        m.grains(lambda t: 650 * _bell(t, 1.0, 2.6),
                 lambda t: 0.8 + 0 * t,
                 lambda t, side=side: side * (1 - smooth(t, 1.0, 2.6)),
                 amp=0.5, weight=lambda t: 0.35 + 0 * t)
    # Heat: the knot going white starts to crackle and roar, softly.
    crackle(m, 1.2, burst - 1.2, lambda t: 260 * smooth(t, 0, 1.5) ** 2,
            amp=0.45, low=1200, high=5200, width=0.25)
    m.air(1.3, burst - 1.3 + 0.03, 200, 1300, amp=0.035, rise=0.97)

    # The knot stops dead at the burst: what it was is now the spray.
    m.y *= np.clip((burst + 0.025 - m.t) / 0.025, 0, 1)
    # (the held breath and roar keep their last 30 ms, so the burst leans
    # in out of them rather than starting from silence)

    # -- the burst: thrown wide, white for a breath, cooling.
    for side in (-1.0, 1.0):
        m.grains(lambda t: np.where(t > burst,
                                    4200 * smooth(t, burst, burst + 0.03)
                                    * np.exp(-(t - burst) / 0.16), 0),
                 lambda t: 0.85 - 0.45 * smooth(t, burst, burst + 0.7),
                 lambda t, side=side: side * (0.25 + 0.6 * (1 - np.exp(-4.6 * np.maximum(t - burst, 0)))),
                 amp=0.5, weight=lambda t: 0.55 + 0 * t)
        # The rush of it, wide, decorrelated each side.
        m.air(burst - 0.01, 1.3, 260, 3600, amp=0.05, rise=0.04, pan=0.7 * side)
    # The flash: a low bloom of air, not a hit.
    m.air(burst - 0.01, 1.2, 90, 520, amp=0.06, rise=0.05)
    # Embers: one in five runs on, crackling, and cools over 1.5 s.
    crackle(m, burst + 0.02, 1.6,
            lambda t: 420 * np.exp(-t / 0.45) * (t < 1.5),
            amp=0.6, low=1300, high=6000, width=0.7)
    m.room(t60=1.6, wet=0.26, darkness=3800)
    return m.finish(loudness_db=-28.5, fade_out=0.6)


def _breath(m, start, length, formants, amp, rise, pan=0.0):
    """A breath: noise through the throat's resonances (no voice), swelling
    and going. [formants] are (centre Hz, bandwidth Hz, weight)."""
    n = round(length * SR)
    t = np.arange(n) / SR
    x = t / length
    env = np.where(x < rise, smooth(x, 0, rise), np.cos((x - rise) / (1 - rise) * math.pi / 2) ** 2)
    # A breath is not steady: it wavers a little as it goes.
    lp = signal.butter(2, 6, btype='lowpass', fs=SR, output='sos')
    wob = signal.sosfilt(lp, m.rng.normal(0, 1, n))
    wob /= max(np.max(np.abs(wob)), 1e-9)
    env = env * (1 + 0.25 * wob)
    for ch in range(2):
        noise = m.rng.normal(0, 1, n)
        y = np.zeros(n)
        for fc, bw, w in formants:
            sos = signal.butter(1, [fc - bw / 2, fc + bw / 2], btype='bandpass',
                                fs=SR, output='sos')
            y += w * signal.sosfilt(sos, noise)
        g = math.cos((pan + 1) * math.pi / 4) if ch == 0 else math.sin((pan + 1) * math.pi / 4)
        s0 = round(start * SR)
        e = min(m.n, s0 + n)
        m.y[ch, s0:e] += (amp * 0.06 * g * env * y)[: e - s0]
    return m


def altar_awake():
    """Awake: the Mystic, whole, takes its first breath -- in, and a long
    breath out -- as the card comes up."""
    m = Mix(2.5, seed=4912)
    # The last of its grains finding their places as the sprite takes over.
    m.grains(lambda t: 700 * np.exp(-t / 0.18), lambda t: 0.35 + 0 * t,
             lambda t: 0 * t, amp=0.5, weight=lambda t: 0.45 + 0 * t)
    # In: airy, high in the throat.
    _breath(m, 0.08, 0.62, [(1100, 700, 0.6), (2300, 1200, 0.8), (3800, 1600, 0.5)],
            amp=0.75, rise=0.8)
    # Out: longer and warmer, lower in the chest.
    _breath(m, 0.78, 1.5, [(520, 300, 1.0), (1150, 500, 0.7), (2500, 1100, 0.35)],
            amp=1.0, rise=0.12)
    # The altar's room answering, low and slow, under the out-breath.
    m.air(0.75, 1.6, 120, 600, amp=0.03, rise=0.25)
    m.room(t60=1.5, wet=0.3, darkness=3600)
    return m.finish(loudness_db=-30.0, fade_out=0.45)


def altar_seal():
    """Sealed: its grains wind into a sphere, a glass stopper is turned home
    in it, and it drops away."""
    m = Mix(1.75, seed=4913)
    fold, end = SEAL_FOLD, SEAL_END

    def gather(t):
        return _bell(t, 0.0, fold)

    def swirl(t):
        # The sphere spins at 3 + 8/1.35 rad/s, its spread tightening.
        return 0.45 * (1 - 0.7 * smooth(t, 0, fold)) * np.sin(8.9 * t)

    m.grains(lambda t: 1500 * gather(t) * (t < fold + 0.02),
             lambda t: 0.5 + 0.25 * smooth(t, 0, fold), swirl, amp=0.5,
             weight=lambda t: 0.45 + 0.1 * smooth(t, 0, fold))
    m.air(0.0, fold + 0.05, 300, 2400, amp=0.035, rise=0.75)
    # The stopper: ground glass turned into the neck, then seated.
    friction(m, fold - 0.09, 0.09,
             lambda t: 1500 * smooth(t, 0, 0.03) * (1 - smooth(t, 0.07, 0.09)),
             1700, [1.0, 2.32, 4.25, 6.63], ring=0.02, amp=0.8,
             contact=0.0002, rub=0.3, rub_band=(1500, 5000))
    # Seated, not struck: a dull glass-on-glass seat, held by the hand that
    # turned it (its ring cut short), and the give of the seal under it.
    strike(m, fold, 680, [1.0, 2.32, 4.25, 6.63, 9.38], ring=0.055, amp=2.6,
           contact=0.0008, split=0.004, tilt=0.55, click=0.2, lean=0.004)
    fibre(m, fold - 0.004, 0.05, 280, 1600, 1.4)
    # Dropping away: a fall of air that recedes, the last glints going out.
    m.air(fold, end - fold + 0.2, 200, 1500, amp=0.022, rise=0.25)
    m.grains(lambda t: np.where((t > fold) & (t < end), 90, 0),
             lambda t: 0.9 + 0 * t, lambda t: 0 * t, amp=0.5,
             weight=lambda t: 0.4 * (1 - smooth(t, fold, end)))
    m.room(t60=1.2, wet=0.24, darkness=3800)
    return m.finish(loudness_db=-30.5, fade_out=0.35)


# ===========================================================================
# The Harvest screen's room -- AmbienceCue.lab (extraction_hub_screen.dart)
# ===========================================================================
#
# The Biome Extractors: an Alchemon on a bench, its essence arcing into a
# dark-glass flask. The bed sits under everything, at the ambience player's
# 0.18, so it is a ROOM, not a scene: a warm low air, the flask simmering
# faintly, and now and then something on the bench settling -- never on a
# beat, never a note.

LAB_LEN = 24.0
LAB_XFADE = 1.5


def _bubble(m, at, f0, amp, pan):
    """A tiny bubble freeing itself at the surface: a short ring whose pitch
    rises as it shrinks (Minnaert), gone in a few ms. Small and quiet, or
    it is a cartoon blip."""
    life = m.rng.uniform(0.006, 0.016)
    n = round(life * 5 * SR)
    t = np.arange(n) / SR
    f = f0 * (1 + 0.25 * np.clip(t / life, 0, 2))
    ph = 2 * math.pi * np.cumsum(f) / SR
    y = np.sin(ph) * np.exp(-t / life) * np.clip(t / 0.0008, 0, 1)
    gl = math.cos((pan + 1) * math.pi / 4)
    gr = math.sin((pan + 1) * math.pi / 4)
    s0 = round(at * SR)
    if s0 >= m.n:
        return
    e = min(m.n, s0 + n)
    m.y[0, s0:e] += amp * gl * y[: e - s0]
    m.y[1, s0:e] += amp * gr * y[: e - s0]


def lab_loop():
    """The extractor room: warm low air, a flask simmering faintly, and the
    bench settling now and then."""
    total = LAB_LEN + LAB_XFADE
    m = Mix(total, seed=4921)
    rng = m.rng
    t = m.t

    # The room: a soft, slowly breathing air, mostly low-mid -- warm, and
    # kept out of the sub so headphones do not get a hum.
    lp = signal.butter(2, 0.08, btype='lowpass', fs=SR, output='sos')
    drift = signal.sosfilt(lp, rng.normal(0, 1, m.n))
    drift = 1 + 0.35 * drift / max(np.max(np.abs(drift)), 1e-9)
    for ch in range(2):
        low = signal.sosfilt(signal.butter(2, [90, 420], btype='bandpass', fs=SR, output='sos'),
                             rng.normal(0, 1, m.n))
        mid = signal.sosfilt(signal.butter(2, [380, 1600], btype='bandpass', fs=SR, output='sos'),
                             rng.normal(0, 1, m.n))
        m.y[ch] += drift * (0.0065 * low + 0.0016 * mid)

    # The flask: a faint simmer on the right of the bench. Its rate wanders
    # (a few a second, sometimes a little cluster), never periodic.
    lpr = signal.butter(1, 0.15, btype='lowpass', fs=SR, output='sos')
    wander = signal.sosfilt(lpr, rng.normal(0, 1, m.n))
    wander = np.clip(wander / max(np.max(np.abs(wander)), 1e-9), -1, 1)
    rate = 2.2 + 1.8 * wander
    hits = np.nonzero(rng.poisson(rate / SR))[0]
    for i in hits:
        _bubble(m, t[i], rng.uniform(1900, 4200), rng.uniform(0.003, 0.008),
                0.35 + rng.normal(0, 0.08))
        # Bubbles come in little runs: sometimes one or two follow at once.
        for k in range(rng.poisson(0.7)):
            _bubble(m, t[i] + rng.uniform(0.02, 0.12), rng.uniform(2200, 4600),
                    rng.uniform(0.002, 0.006), 0.35 + rng.normal(0, 0.08))
    # The liquid under it: a breath of moving water, very low.
    for ch, g in enumerate((0.8, 1.0)):
        sl = signal.sosfilt(signal.butter(2, [600, 2200], btype='bandpass', fs=SR, output='sos'),
                            rng.normal(0, 1, m.n))
        m.y[ch] += 0.0011 * g * sl * (0.6 + 0.4 * (wander + 1) / 2)

    # The bench settling: a handful of tiny events, spread unevenly, none in
    # the crossfade (they would play twice, faintly).
    events = np.sort(rng.uniform(1.0, LAB_LEN - 1.0, 7))
    kinds = ['glass', 'metal', 'glass', 'wood', 'metal', 'glass', 'grains']
    rng.shuffle(kinds)
    for at, kind in zip(events, kinds):
        pan = rng.uniform(-0.6, 0.6)
        if kind == 'glass':
            # A flask shifting a hair on its stand: a tiny, damped glass.
            strike(m, at, rng.uniform(1300, 2200), [1.0, 2.32, 4.25, 6.63],
                   ring=0.25, amp=0.09, contact=0.0004, split=0.004, tilt=0.6,
                   pan=pan, lean=0.002)
        elif kind == 'metal':
            # A clamp or a stand ticking as it warms.
            brass(m, at, rng.uniform(2200, 3200), amp=0.06, ring=0.12, pan=pan)
        elif kind == 'wood':
            wood(m, at, f0=rng.uniform(300, 420), amp=0.2, ring=0.04, pan=pan)
        else:
            # A pinch of dust or salt sifting off the bench.
            m.grains(lambda tt, at=at: np.where((tt > at) & (tt < at + 0.5),
                                                120 * np.exp(-(tt - at) / 0.15), 0),
                     lambda tt: 0.6 + 0 * tt, lambda tt, p=pan: p + 0 * tt,
                     amp=0.5, weight=lambda tt: 0.12 + 0 * tt)
    m.room(t60=1.4, wet=0.3, darkness=3200)
    y = m.finish(loudness_db=-37.0, fade_out=0)
    return seamless_loop(y, LAB_XFADE)


CUES = {
    'sfx_ui_confirm': (ui_confirm, 'A latch catching: a light brass touch, then the bolt seats'),
    'sfx_ui_denied': (ui_denied, 'A locked latch tried: the bolt knocks its keeper twice, muffled, and does not give'),
    'sfx_altar_rite': (altar_rite, 'The Mystic Altar\'s rite: offerings pour into the middle, are crushed into a shivering, heating knot, and it bursts into a spray of grains and embers'),
    'sfx_altar_awake': (altar_awake, 'The Mystic awake: its grains settle and it takes a first breath, in and a long breath out'),
    'sfx_altar_seal': (altar_seal, 'Sealed and departing: grains wind into a sphere, a glass stopper is turned home, and it drops away'),
    'amb_lab_loop': {
        'build': lab_loop,
        'description': 'The Harvest room: warm low air, a flask simmering faintly, the bench settling now and then',
        'loop': True,
    },
}
