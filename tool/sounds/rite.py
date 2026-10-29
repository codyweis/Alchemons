"""The Pureblood Rite (pureblood_rite_screen.dart): the pool of blood the
screen stands over, and the offering given to it
(pureblood_rite/rite_offering.dart)."""
import math

import numpy as np

from sounds.core import SR, Mix, seamless_loop, smooth
from sounds.cosmic import bubbles, rush
from sounds.elements import _put, _svf, _tt

# ===========================================================================
# The offering -- SoundCue.riteOffering
# ===========================================================================
#
# rite_offering.dart's clock, in seconds from when its grains are read:
#
#   0.2  - 0.55  the specimen's grains loosen, shivering in place
#   0.55 - 2.3   they let go, feet first, crown last (0.55 + (1-y)*1.5 +
#                up to 0.25 of scatter), each falling 0.8 s, quickening
#                (f^2), darkening into blood as it goes
#   1.35 - 3.1   so the pool takes them over these seconds
#   0.8  - 2.0   the pool brightens as it takes them; it settles 3.4 - 5.0
#   1.3  - 2.8   souls rise off it, thicker than before, thinning by 8
#   2.8  - 3.8   the gold counts up (SoundCue.currencyGain, from Dart)
#
# Grains, not a whoosh: a fine sand letting go that turns wet as it falls,
# and the blood taking it in thick, slow bubbles. When the last of it is in,
# the pool answers with one surge -- a heartbeat heard as flow, the Blood
# element's own voice -- and settles.

REL_START = 0.55
REL_SPAN = 1.5 + 0.25
FALL = 0.8
TAKEN = REL_START + REL_SPAN + FALL   # the last grain in: 3.1


def _released(t):
    """How fast grains are letting go at t (peak 1)."""
    return smooth(t, REL_START, REL_START + 0.12) * (1 - smooth(t, REL_START + REL_SPAN - 0.25, REL_START + REL_SPAN))


def _landing(t):
    """How fast grains reach the pool at t (peak 1)."""
    return _released(t - FALL)


def _surge(m, at, amp, length=0.24):
    """One push of thick liquid through a vessel: a dark band of noise that
    opens and closes with the push."""
    n = round(length * 1.6 * SR)
    t = _tt(n)
    push = smooth(t, 0, 0.05) * np.exp(-6.9 * np.maximum(t - 0.05, 0) / (length * 0.7))
    for side in (-1, 1):
        x = _svf(m.rng.normal(0, 1, n), (240 + 480 * push) * (1 + 0.05 * side), 1.6, 'bp')
        _put(m, at, amp * x * push, side * 0.3)


def rite_offering():
    """The specimen given to the pool: its grains loosen and let go from the
    feet up, fall, and the blood takes them in; one slow surge, and it
    settles."""
    m = Mix(5.6, seed=5101)

    # Loosening: a dry shiver in place, barely there.
    m.grains(lambda t: 260 * smooth(t, 0.2, 0.55) * (1 - smooth(t, 0.55, 1.0)),
             lambda t: 0.85 + 0 * t, lambda t: 0.15 * np.sin(7 * t), amp=0.5,
             weight=lambda t: 0.22 + 0 * t)
    # Letting go: fine and bright at first, coarsening as it rises to the
    # crown (the bigger body), each grain a little apart.
    m.grains(lambda t: 1400 * _released(t),
             lambda t: 0.78 - 0.25 * smooth(t, REL_START, REL_START + REL_SPAN),
             lambda t: 0.25 * np.sin(2.3 * t), amp=0.5,
             weight=lambda t: 0.36 + 0 * t)
    # The fall: the stream quickening down, a soft breath of it.
    rush(m, REL_START + 0.2, REL_SPAN + FALL,
         lambda t: 2600 - 1300 * smooth(t, 0, REL_SPAN + FALL),
         lambda t: 0.012 * smooth(t, 0, 0.5) * (1 - smooth(t, REL_SPAN + 0.2, REL_SPAN + FALL)),
         width_oct=0.7, spread=0.4, flutter=0.4)
    # Taken in: thick, slow bubbles where they land, low and close.
    bubbles(m, REL_START + FALL, REL_SPAN + 0.8,
            lambda t: 46 * _landing(t + REL_START + FALL),
            lambda t: 0.62 + 0.18 * smooth(t, 0, REL_SPAN), amp=0.05,
            spread=0.35)
    # The pool brightening as it takes them, then settling: warm, low air.
    m.air(0.8, 4.2, 110, 700, amp=0.05, rise=0.32)
    # Souls rising off it: a thin breath that lifts and thins.
    rush(m, 1.3, 3.6, lambda t: 1500 + 1600 * smooth(t, 0, 3.6),
         lambda t: 0.007 * smooth(t, 0, 0.9) * (1 - smooth(t, 1.6, 3.6)),
         width_oct=0.9, spread=0.8, flutter=0.2)
    # When the last of it is in, the pool answers: one surge, and a smaller.
    _surge(m, TAKEN - 0.05, 0.12)
    _surge(m, TAKEN + 0.24, 0.07, length=0.2)
    # And settles: a last few slow bubbles rising through it.
    bubbles(m, TAKEN + 0.3, 1.8, lambda t: 9 * np.exp(-t / 0.7),
            lambda t: 0.8 + 0 * t, amp=0.035, spread=0.3)
    m.room(t60=1.8, wet=0.3, darkness=3000)
    return m.finish(loudness_db=-29.5, fade_out=0.8)


# ===========================================================================
# The pool's room -- AmbienceCue.ritePool
# ===========================================================================
#
# What the screen stands over, at the ambience player's level: a deep, dark
# room; blood moving slowly in the pool, a thick bubble now and then; the
# souls drifting off it as a faint, wandering breath. Never a heartbeat on a
# beat -- that is the haptics' and the Blood dungeon's.

POOL_LEN = 26.0
POOL_XFADE = 1.5


def pool_loop():
    """The pool: a deep, dark room, the blood turning slowly, a thick bubble
    now and then, and the souls' faint breath over it."""
    total = POOL_LEN + POOL_XFADE
    m = Mix(total, seed=5102)
    rng = m.rng
    # The room and the blood's slow turning: low, warm, breathing.
    rush(m, 0, total, lambda t: 300 + 90 * np.sin(2 * math.pi * t / 9.3),
         lambda t: 0.012 + 0.004 * np.sin(2 * math.pi * t / 6.1),
         width_oct=1.0, spread=0.9, flutter=0.15)
    # The souls: a thin breath, high and far, wandering across.
    rush(m, 0, total, lambda t: 2400 + 500 * np.sin(2 * math.pi * t / 11.7),
         lambda t: 0.0028 * (1 + np.sin(2 * math.pi * t / 7.9)),
         pan=0.0, width_oct=0.8, spread=1.0, flutter=0.3)
    # Thick bubbles rising through it now and then, in little runs; none in
    # the crossfade (they would play twice).
    at = 1.2
    while at < POOL_LEN - 1.5:
        pan = rng.uniform(-0.45, 0.45)
        bubbles(m, at, 0.6, lambda t: 14 * np.exp(-t / 0.18),
                lambda t: 0.82 + 0 * t, amp=0.03, pan=pan, spread=0.15)
        at += rng.uniform(1.8, 4.5)
    # Once or twice the pool turns over heavily: a slow, quiet surge.
    for at in (8.4, 19.1):
        _surge(m, at, 0.035, length=0.5)
    m.room(t60=2.2, wet=0.34, darkness=2600)
    y = m.finish(loudness_db=-37.0, fade_out=0)
    return seamless_loop(y, POOL_XFADE)


CUES = {
    'sfx_rite_offering': (rite_offering, 'The Pureblood Rite\'s offering: the specimen\'s grains loosen and let go from the feet up, fall, and the blood takes them in thick bubbles; one slow surge, and it settles'),
    'amb_rite_pool_loop': {
        'build': pool_loop,
        'description': 'The pool of blood the rite stands over: a deep dark room, blood turning slowly, a thick bubble now and then, the souls\' faint breath',
        'loop': True,
    },
}
