"""Harvest: the wilderness harvest field's beats, the Harvest screen, and
the shared reward flight."""
import json
import math

import numpy as np

from sounds.core import ROOT, SR, Mix, smooth

# ===========================================================================
# Harvest -- HarvestParticleField, in the scene (HarvestFieldEffect) or the
# overlay (showHarvestCinematic)
# ===========================================================================
#
# Both hosts announce HarvestParticleField.beats as they happen -- engage,
# then take or shatter -- and the encounter sheet plays these on them, so a
# take lands on the frame the crest starts rather than when a dialog closes.
#
# The seize, in seconds from engage (HarvestFieldEffect, minSeize 1.5):
#   0.02 - 0.63  the rings of motes sweep in from wide and close
#   0.57 - 0.83  the bite: the specimen flinches (deepest at 0.70)
#   0.83 -       the strain: it shoves every 0.83 s (2.4 pi rad/s), trembling,
#                for as long as the roll takes -- ~1.5 s in all

SEIZE = 1.5


def harvest_primed():
    """A device chosen: a pinch of grains dropped into glass. Small."""
    m = Mix(0.5, seed=4501)
    m.grains(lambda t: np.where(t < 0.09, 2600 * np.exp(-t / 0.03), 0),
             lambda t: 0.6 + 0 * t, lambda t: 0 * t, amp=0.5,
             weight=lambda t: 0.6 + 0 * t)
    m.glass(0.01, 610, amp=0.05, ring=0.35, attack=0.008, brightness=0.25,
            beat=2.0, ratios=[1.0, 2.32, 4.25])
    m.room(t60=0.7, wet=0.2)
    return m.finish(loudness_db=-34.0, fade_out=0.2)


def harvest_seize():
    m = Mix(SEIZE + 0.75, seed=4502)
    closing = np.clip((m.t - 0.02) / (SEIZE * 0.42 - 0.02), 0, 1)
    lock = np.clip((m.t - SEIZE * 0.38) / (SEIZE * 0.17), 0, 1)
    pressure = np.clip((m.t - SEIZE * 0.55) / (SEIZE * 0.45), 0, 1)
    # Past the minimum the strain goes on as long as the roll does; the
    # outcome normally arrives by ~1.6 s, so it thins away after that.
    pressure *= np.clip((SEIZE + 0.6 - m.t) / 0.5, 0, 1)
    push = pressure * (0.5 - 0.5 * np.cos(m.t * math.pi * 2.4))
    tremble = (lock + pressure) * (0.5 + 0.5 * np.sin(m.t * 26))
    closing_speed = np.gradient(1 - (1 - closing) ** 3, m.t)
    closing_speed /= closing_speed.max()
    grid = m.t

    def at(curve):
        return lambda t: np.interp(t, grid, curve)

    # The rings: motes on orbits round the specimen, coming in from wide.
    # Two streams turning opposite ways, near and far.
    for side, phase in ((1.0, 0.0), (-1.0, math.pi)):
        spread = 0.9 - 0.55 * closing
        orbiting = 0.6 * (closing > 0) + 1.4 * closing_speed
        m.grains(at(500 * orbiting + 300 * push),
                 at(0.88 - 0.1 * closing),
                 lambda t, side=side, phase=phase: side * np.interp(t, grid, spread)
                 * (0.6 + 0.4 * np.sin(2 * math.pi * 0.8 * t + phase)),
                 amp=0.5, weight=at(0.45 + 0.25 * closing_speed + 0.2 * push))
    # The bite: a short dark press as the field closes on it.
    bite = np.sin(np.pi * lock) * (lock < 1)
    m.grains(at(1300 * bite), lambda t: 0.25 + 0 * t, lambda t: 0 * t,
             amp=0.5, weight=at(0.5 + 0.35 * bite))
    # The specimen fighting it: coarse grains shaken at its tremble, and a
    # swell on every shove.
    m.grains(at(700 * tremble * (0.4 + 0.6 * pressure) + 900 * push),
             lambda t: 0.32 + 0 * t,
             lambda t: 0.12 * np.sin(t * 26), amp=0.5,
             weight=at(0.45 + 0.3 * push))
    m.air(0.0, 0.7, 300, 2600, amp=0.035, rise=0.35)
    m.air(SEIZE * 0.55, SEIZE + 0.5 - SEIZE * 0.55, 200, 1200, amp=0.03,
          rise=0.5)
    m.room(t60=1.0, wet=0.2)
    return m.finish(loudness_db=-30.0, fade_out=0.4)


TAKE = 1.3     # HarvestParticleField.takeSeconds
BREAK = 0.9    # HarvestParticleField.breakSeconds


def harvest_take():
    """The roll held. In seconds from the take beginning:
    0.13 - 0.44  a crest runs down the specimen, turning it to grains
    0.26 - 1.04  the rings fall in on the harvester, turning as they go
    0.39 - 1.27  the specimen's grains are drawn down into it, in order
    1.01 - 1.3   the harvester's mote swells, and goes out
    """
    m = Mix(TAKE + 0.8, seed=4503)
    t = m.t
    take = np.clip(t / TAKE, 0, 1)
    crest = ((take > 0.1) & (take < 0.34)).astype(float)
    pull = np.clip((take - 0.2) / 0.6, 0, 1)
    pull = np.where(pull < 0.5, 4 * pull ** 3, 1 - (-2 * pull + 2) ** 3 / 2)
    pull_speed = np.gradient(pull, t)
    pull_speed /= pull_speed.max()
    # Specimen grains in flight: each leaves at 0.3 + 0.4 * order and takes
    # 0.28 of the take.
    order = np.linspace(0, 1, 400)
    leave = (0.3 + 0.4 * order) * TAKE
    fly = 0.28 * TAKE
    in_flight = ((t[None, :] > leave[:, None]) &
                 (t[None, :] < leave[:, None] + fly)).mean(0)
    in_flight /= max(in_flight.max(), 1e-9)

    def at(curve):
        return lambda tt: np.interp(tt, t, curve)

    m.grains(at(1500 * crest), lambda tt: 0.92 + 0 * tt, lambda tt: 0 * tt,
             amp=0.5, weight=lambda tt: 0.5 + 0 * tt)
    for side, sign in ((0.7, 1.0), (-0.7, -1.0)):
        swirl = side * (1 - pull) * np.cos(pull * 2.4 * sign)
        m.grains(at(1100 * pull_speed), at(0.85 - 0.25 * pull),
                 lambda tt, swirl=swirl: np.interp(tt, t, swirl), amp=0.5,
                 weight=at(0.5 + 0.35 * pull_speed))
    # The specimen poured down into the harvester: cooling as it goes.
    m.grains(at(2000 * in_flight), at(0.7 - 0.35 * in_flight),
             lambda tt: 0.1 * np.sin(2 * math.pi * 1.1 * tt), amp=0.5,
             weight=at(0.55 + 0.35 * in_flight))
    m.air(0.2, 1.0, 260, 2000, amp=0.035, rise=0.75)
    # The harvester sealing it in: a small glass, swelling with the mote.
    m.glass(0.96, 520, amp=0.065, ring=1.3, attack=0.16, brightness=0.35,
            beat=1.2)
    m.room(t60=1.1, wet=0.22)
    return m.finish(loudness_db=-28.0, fade_out=0.4)


def harvest_break():
    """The roll failed: the field is thrown apart (fast, then slowing) with a
    faint flash of heat, and the specimen is still standing."""
    m = Mix(BREAK + 0.6, seed=4504)
    t = m.t
    sh = np.clip(t / BREAK, 0, 1)
    thrown = 3 * (1 - sh) ** 2 * (t < BREAK)
    thrown /= thrown.max()
    # Leans in over ~40 ms: at full density on the first sample, four
    # streams flung at once are a crash.
    thrown *= np.clip(t / 0.04, 0, 1)

    def at(curve):
        return lambda tt: np.interp(tt, t, curve)

    for side in (-1.0, -0.4, 0.4, 1.0):
        m.grains(at(420 * thrown), at(0.86 - 0.2 * (1 - thrown)),
                 lambda tt, side=side: side * (0.45 + 0.5 * np.interp(tt, t, sh)),
                 amp=0.5, weight=at(0.45 + 0.4 * thrown))
    # The heat: a warm breath out, no edge on it.
    m.air(0.0, 0.55, 220, 1500, amp=0.06, rise=0.12)
    # The specimen shrugging it off, where it stands.
    m.grains(lambda tt: np.where(tt > 0.05, 700 * np.exp(-(tt - 0.05) / 0.12), 0),
             lambda tt: 0.28 + 0 * tt, lambda tt: 0 * tt, amp=0.5,
             weight=lambda tt: 0.55 + 0 * tt)
    m.room(t60=0.9, wet=0.2)
    return m.finish(loudness_db=-31.0, fade_out=0.35)  # a failure: not one of the louder moments


# ===========================================================================
# The Harvest screen (extraction_hub_screen.dart) and the reward flight
# (reward_collect_burst.dart) it -- and the journal, and onboarding -- ends on
# ===========================================================================

DRAIN = 1.1          # _drainCtrl: the level falls easeInOutCubic
VENT_UNTIL = 0.88    # ExtractionVessel vents while the drain is < 0.8


def harvest_collect():
    """One chamber collected: the flask drains, its essence venting up out of
    the surface as the level falls (fastest mid-drain)."""
    m = Mix(DRAIN + 0.5, seed=4601)
    t = m.t
    x = np.clip(t / DRAIN, 0, 1)
    level = np.where(x < 0.5, 4 * x ** 3, 1 - (-2 * x + 2) ** 3 / 2)
    speed = np.gradient(level, t)
    speed /= speed.max()
    venting = (t < VENT_UNTIL).astype(float) * np.clip(t / 0.05, 0, 1)

    def at(curve):
        return lambda tt: np.interp(tt, t, curve)

    # Grains leaving the surface, rising: fine, a little spread.
    for side in (-0.35, 0.35):
        m.grains(at(1300 * speed * venting + 60 * venting),
                 at(0.8 + 0.1 * speed), lambda tt, side=side: side + 0 * tt,
                 amp=0.5, weight=at(0.5 + 0.35 * speed))
    # The body of it going down: a dark, slow pour under the vent.
    m.grains(at(900 * speed), lambda tt: 0.22 + 0 * tt, lambda tt: 0 * tt,
             amp=0.5, weight=at(0.45 + 0.3 * speed))
    m.air(0.0, DRAIN, 220, 1600, amp=0.035, rise=0.5)
    # The flask itself, touched as it opens.
    m.glass(0.0, 470, amp=0.04, ring=0.8, attack=0.01, brightness=0.3,
            beat=1.5, ratios=[1.0, 2.32, 4.25])
    m.room(t60=1.0, wet=0.22)
    return m.finish(loudness_db=-31.0, fade_out=0.35)


def harvest_collect_all():
    """Collect all: every finished chamber lets go at once. Short; the reward
    flights that follow carry the landing."""
    m = Mix(0.8, seed=4602)
    t = m.t
    release = np.where(t < 0.5, np.clip(t / 0.03, 0, 1) * np.exp(-t / 0.14), 0)

    def at(curve):
        return lambda tt: np.interp(tt, t, curve)

    for side in (-0.7, 0.0, 0.7):
        m.grains(at(900 * release), lambda tt: 0.78 + 0 * tt,
                 lambda tt, side=side: side + 0 * tt, amp=0.5,
                 weight=at(0.5 + 0.3 * release))
    m.air(0.0, 0.5, 260, 2200, amp=0.05, rise=0.1)
    m.room(t60=1.0, wet=0.22)
    return m.finish(loudness_db=-31.0, fade_out=0.25)


FLIGHT = 0.98        # _RewardBurst


def reward_flight():
    """A reward leaving its card and arriving where rewards go.

    0    - 0.29  the card answers: a ring pushes out of it
    0    - 0.33  coins thrown out, each a little late (up to 0.27)
    0.22 - 0.98  drawn in, accelerating -- and every one arrives at 0.98
    """
    m = Mix(FLIGHT + 0.6, seed=4603)
    t = m.t
    rng = np.random.default_rng(11)
    delay = rng.random(24) * 0.28
    local = np.clip((t[None, :] / FLIGHT - delay[:, None]) / (1 - delay[:, None]), 0, 1)
    scatter = 1 - (1 - np.clip(local / 0.34, 0, 1)) ** 3
    fly = np.clip((local - 0.22) / 0.78, 0, 1) ** 3
    thrown = np.gradient(scatter, t, axis=1).mean(0)
    drawn = np.gradient(fly, t, axis=1).mean(0) * (t < FLIGHT)
    thrown /= max(thrown.max(), 1e-9)
    drawn /= max(drawn.max(), 1e-9)

    def at(curve):
        return lambda tt: np.interp(tt, t, curve)

    # Thrown out: a loose scatter of small bright ticks (they spin, so they
    # glint).
    m.grains(at(700 * thrown), lambda tt: 0.9 + 0 * tt,
             lambda tt: 0.3 * np.sin(2 * math.pi * 3 * tt), amp=0.5,
             weight=at(0.45 + 0.3 * thrown))
    # Drawn in, faster and faster, to one point.
    m.grains(at(1500 * drawn), at(0.85 - 0.25 * drawn),
             lambda tt: 0.4 * (1 - np.interp(tt, t, drawn)) * np.sin(7 * tt),
             amp=0.5, weight=at(0.45 + 0.4 * drawn))
    # Arrived: they settle into the total, and it rings, small.
    m.grains(lambda tt: np.where(tt > FLIGHT, 1600 * np.exp(-(tt - FLIGHT) / 0.07), 0),
             lambda tt: 0.45 + 0 * tt, lambda tt: 0 * tt, amp=0.5,
             weight=lambda tt: 0.6 + 0 * tt)
    m.glass(FLIGHT - 0.01, 560, amp=0.05, ring=0.9, attack=0.03,
            brightness=0.4, beat=1.6)
    m.air(0.0, 0.3, 300, 2400, amp=0.03, rise=0.15)
    m.room(t60=0.9, wet=0.2)
    return m.finish(loudness_db=-32.0, fade_out=0.3)


CUES = {
    'sfx_harvest_collect': (
        harvest_collect,
        'A chamber collected: the flask drains, its essence venting up out of the surface',
    ),
    'sfx_extraction_complete': (
        harvest_collect_all,
        'Collect all: every finished chamber lets go at once',
    ),
    'sfx_reward_flight': (
        reward_flight,
        'A reward thrown out of its card, drawn in faster and faster, and settled into its total',
    ),
    'sfx_capture_throw': (
        harvest_primed,
        'A harvester chosen: a pinch of grains into glass',
    ),
    'sfx_capture_attempt': (
        harvest_seize,
        'Rings of motes close on the specimen, bite, and strain as it shoves',
    ),
    'sfx_capture_success': (
        harvest_take,
        'The specimen turned to grains and drawn down, turning, into the harvester, sealed with a small glass',
    ),
    'sfx_capture_escape': (
        harvest_break,
        'The field thrown apart with a breath of heat; the specimen shrugs it off',
    ),
}
