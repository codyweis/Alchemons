"""Pip -- the Ricochet family: its basic, its special salvos, the ricochet
itself, and Dark's passive black hole.

What is drawn (pip_vfx.drawPipDart, cosmic_data.dart _pipSpecial /
createFamilyBasicAttack, cosmic_survival_game.dart):

  * Every pip shot is a DART: a keen point with a tapered trail of its own
    light. The head is the element's material -- a swept barb, a heavy
    knapped flint (Lava, Earth, Mud), a needle (Blood, Ice, Lightning), a
    cut prism (Crystal, Light). Never a ball.
  * BASIC: three darts in one frame, fanned at -0.12 / 0 / +0.12 rad, 1050
    px/s (600 x 1.75), no bounce, no homing. A pip stands 0.42 x its range
    off its target (~60-130 px), so the darts land 60-130 ms after they
    leave -- and the landing has its own sound (combatHitLight/Heavy,
    _damageEnemy). The basic is the flick and the first few metres, gone by
    the time the hit is heard. Fires every ~0.5-1.4 s; ten times faster in
    Spirit's empower window and up to 4x in Steam's (the 110 ms cue
    cooldown thins those).
  * SPECIAL: a salvo of 2-8 darts fanned 0.20 rad apart (all in one frame)
    that chain from body to body: each contact looks for the next enemy
    within 110 px, so a bounce is 70-170 ms after the last. Every contact
    already plays combatHitLight/Heavy (100 ms cooldown). The salvo comes in
    three shapes by what the darts are:
      ricochet  fast keen darts that bounce (Air, Dust, Light, Water, Ice,
                Crystal, Fire, Lightning, Steam): 660-1600 px/s
      seeker    slow homing needles, no bounce, long-lived and curling
                (Blood, Spirit, Poison, Plant): 480-660 px/s, homing 2.6-3.2,
                life 3-4 s
      heavy     two to five knapped stone heads, slow and hard-hitting (Lava,
                Earth, Mud): 540-600 px/s, x2.5 damage
    Dark has no cast: its special is a passive black hole opened by every
    auto-attack kill.

Material: the darts are small hard points, so their sound is the flick that
lets them go and the air they cut -- a thin band that recedes and dims as
the dart leaves. No tone, no whine (the cartoon ricochet "pyeww" is exactly
the thing not to make), no glass ring: the element accent layers on top of
the special and carries any colour.
"""
import math
import warnings

import numpy as np
from scipy import signal

from sounds.core import SR, Mix, smooth
from sounds.combat import _put, _solid, burst, chips, creak, strike

# ===========================================================================
# Voices
# ===========================================================================


def _band(rng, length, fc, width, env):
    """Air through a band that moves: noise carved frame by frame, so it
    slides and never settles on a resonance. [fc](u), [width](u) (natural-
    log units) and [env](u) over u = 0..1 of [length]. Mono."""
    n = round(length * SR)
    nper, hop = 512, 128
    pad = nper
    noise = rng.normal(0, 1, n + 2 * pad)
    f, tt, z = signal.stft(noise, fs=SR, nperseg=nper, noverlap=nper - hop,
                           boundary=None, padded=False)
    u = np.clip((tt - pad / SR) / length, 0, 1)
    centre = np.log(np.maximum(fc(u), 50))
    w = np.broadcast_to(width(u) if callable(width) else width, u.shape)
    logf = np.log(np.maximum(f, 20))[:, None]
    shape = np.exp(-0.5 * ((logf - centre[None, :]) / w[None, :]) ** 2)
    # Air is not white: a band higher up is no louder than one lower down.
    shape /= np.sqrt(np.maximum(f, 100) / 1000)[:, None]
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', UserWarning)
        _, y = signal.istft(z * shape, fs=SR, nperseg=nper,
                            noverlap=nper - hop, boundary=False)
    y = y[pad:pad + n]
    y *= 0.15 / max(float(np.sqrt(np.mean(y ** 2))), 1e-12)
    uu = np.arange(n) / max(n - 1, 1)
    return env(uu) * y


def _put_moving(m, start, mono, pan):
    """[mono] laid in from [start], its pan moving along [pan](u)."""
    s0 = m._at(start)
    mono = mono[: m.n - s0]
    u = np.arange(len(mono)) / max(len(mono) - 1, 1)
    p = np.clip(pan(u), -1, 1)
    m.y[0, s0:s0 + len(mono)] += np.cos((p + 1) * math.pi / 4) * mono
    m.y[1, s0:s0 + len(mono)] += np.sin((p + 1) * math.pi / 4) * mono


def _leaving(u, attack=0.12, tail=1.6):
    """A dart going away: it arrives at full strength almost at once (it is
    nearest as it leaves the hand) and thins as it recedes."""
    u = np.clip(u, 0, 1)
    return np.where(u < attack, np.sin(0.5 * math.pi * u / attack) ** 2,
                    (1 - (u - attack) / (1 - attack)) ** tail)


def cut(m, start, length, f0, f1, amp, pan0, pan1, width=0.32,
        flutter=0.0, flutter_hz=34.0, waver=0.0, waver_hz=2.0, attack=0.12):
    """One dart's flight: the air its point cuts, receding. The band drops
    from [f0] to [f1] as it goes (it is further off, and duller), its pan
    runs from [pan0] to [pan1] (the fan opening). [flutter] is the spin of a
    fletched dart (an irregular wobble on the level, not a tone); [waver]
    bends the band as a homing dart curls."""
    rng = m.rng
    ph = rng.uniform(0, 2 * math.pi)

    def fc(u):
        base = f0 * (f1 / f0) ** (u ** 0.7)
        return base * (1 + waver * np.sin(2 * math.pi * waver_hz * length * u + ph))

    y = _band(rng, length, fc, width, lambda u: _leaving(u, attack))
    if flutter > 0:
        n = len(y)
        # A spin's wobble wanders in rate, so it never becomes a buzz.
        jitter = signal.sosfilt(signal.butter(1, 6, fs=SR, output='sos'),
                                rng.normal(0, 1, n)) * 40
        phase = np.cumsum(2 * math.pi * flutter_hz * (1 + 0.25 * jitter) / SR)
        y *= 1 + flutter * np.sin(phase)
    _put_moving(m, start, amp * y, lambda u: pan0 + (pan1 - pan0) * u ** 0.6)


def tick(m, at, size, pan, lo=2400, hi=4600, eta=0.12, cap=0.006):
    """A hard little point let go: dry, almost no ring to it."""
    chips(m, [(at, size, pan)], lo, hi, eta=eta, n=3, tc=0.00025, cap=cap)


# ===========================================================================
# The basic: three darts flicked in a fan
# ===========================================================================
#
# All three leave in one frame; a flick of three is heard as one gesture
# with a little smear, so the releases sit inside ~12 ms (the first pass
# spread them 17-26 ms apart, which is a roll -- three shots -- not a fan).
# The air they cut is gone by ~90 ms: the hit at 60-130 ms is its own cue.


def basic(v=0):
    m = Mix(0.15, seed=7100 + v)
    rng = m.rng
    pans = [-0.28, 0.0, 0.28]
    order = rng.permutation(3)
    times = np.sort(np.r_[0.0, rng.uniform(0.003, 0.007), rng.uniform(0.008, 0.012)])
    # The finger and the darts' tails brushing as they go: a breath of
    # pressure under the three, not a puff from a barrel.
    burst(m, 0.0, 700, 2600, attack=0.004, tau=0.012, amp=0.035)
    for k, at in enumerate(times):
        p = pans[order[k]]
        tick(m, 0.002 + at, rng.uniform(0.14, 0.2), p * 0.5,
             lo=2600, hi=4400)
        cut(m, 0.002 + at + 0.001, rng.uniform(0.075, 0.095),
            rng.uniform(5000, 5800), rng.uniform(3200, 3700),
            0.075 * rng.uniform(0.85, 1.0), p * 0.35, p * 1.1)
    m.room(t60=0.25, wet=0.08)
    return m.finish(loudness_db=-35.0, fade_out=0.035)


# ===========================================================================
# The specials
# ===========================================================================


def _fan_order(rng, count, spread):
    """The salvo fans from the middle out: pans for [count] darts, centre
    first, then pairs to either side, alternating which side leads."""
    out = [0.0]
    k = 1
    while len(out) < count:
        side = 1 if rng.random() < 0.5 else -1
        p = spread * k / ((count - 1) / 2 + 0.5)
        out.append(side * p)
        if len(out) < count:
            out.append(-side * p)
        k += 1
    return out


def special_ricochet():
    """The salvo: the darts fanned out of the hand and let go in a riffle.

    A brief catch first -- the shafts sliding over each other as the fan
    opens (a scratchy stick-slip, ~25 ms: the lean-in) -- then seven dry
    releases over ~30 ms, centre first and out to the sides, each with its
    own keen cut receding as the fan opens wide. The darts reach the first
    bodies at ~0.1-0.3 s; from there the ricochets and the hits are their
    own cues. Done by ~0.4 s, leaving the element accent the tail."""
    m = Mix(0.42, seed=7200)
    rng = m.rng
    lean = 0.026
    body = (np.array([2300, 3350, 4700, 6100]) * rng.uniform(0.96, 1.04, 4),
            np.array([0.012, 0.009, 0.006, 0.004]),
            np.array([1.0, 0.7, 0.45, 0.25]))
    creak(m, 0.0, lean + 0.006, lambda u: 520 + 500 * u, 0.5, body, 0.3,
          lambda u: smooth(u, 0.0, 0.85) * (1 - smooth(u, 0.9, 1.0)))
    count = 7
    pans = _fan_order(rng, count, 0.7)
    times = lean + 0.03 * (np.arange(count) / (count - 1)) ** 0.85
    times += rng.uniform(-0.002, 0.002, count)
    for k, (at, p) in enumerate(zip(times, pans)):
        tick(m, at, rng.uniform(0.2, 0.28) * (1 - 0.04 * k), p * 0.4)
        cut(m, at + 0.001, rng.uniform(0.17, 0.24),
            rng.uniform(5600, 6600), rng.uniform(2800, 3400),
            0.085 * rng.uniform(0.8, 1.0), p * 0.3, p * 1.15, width=0.3)
    # The air the whole fan throws forward.
    burst(m, lean - 0.008, 500, 2800, attack=0.018, tau=0.045, amp=0.05)
    m.room(t60=0.35, wet=0.1)
    return m.finish(loudness_db=-31.0, fade_out=0.1)


def special_seeker():
    """Slow homing needles (Blood, Spirit, Poison, Plant): they leave softly
    and then hunt -- 480-660 px/s with strong homing, alive for 3-4 s, the
    outer ones curling back in toward the bodies in front.

    A softer, slower riffle of five needles; their cuts are lower (a slower
    point moves less air high up), longer, and bend as the darts turn, the
    pans swinging out with the fan and then curling back toward the middle.
    A faint spin on each (fletching flutter) is what tells a seeker from a
    keen dart. Gone by ~0.75 s."""
    m = Mix(0.8, seed=7300)
    rng = m.rng
    lean = 0.03
    body = (np.array([1900, 2800, 3900]) * rng.uniform(0.96, 1.04, 3),
            np.array([0.014, 0.01, 0.007]), np.array([1.0, 0.6, 0.35]))
    creak(m, 0.0, lean + 0.008, lambda u: 380 + 300 * u, 0.5, body, 0.22,
          lambda u: smooth(u, 0.0, 0.85) * (1 - smooth(u, 0.9, 1.0)))
    count = 5
    pans = _fan_order(rng, count, 0.6)
    times = lean + 0.05 * (np.arange(count) / (count - 1))
    times += rng.uniform(-0.003, 0.003, count)
    for k, (at, p) in enumerate(zip(times, pans)):
        tick(m, at, rng.uniform(0.16, 0.22), p * 0.4, lo=2200, hi=3800,
             eta=0.1, cap=0.008)
        length = rng.uniform(0.48, 0.66)
        y_amp = 0.08 * rng.uniform(0.8, 1.0)
        # Out with the fan, then curling back in to what it is hunting.
        swing = p * 1.1
        rng_ph = rng.uniform(0, 1)

        def pan(u, swing=swing, ph=rng_ph):
            out = swing * np.sin(math.pi * np.clip(u / 0.45, 0, 1) * 0.5)
            back = smooth(u, 0.35, 1.0) * 0.75
            return out * (1 - back) + 0.08 * np.sin(2 * math.pi * (u * 1.3 + ph))

        y = _band(rng, length,
                  lambda u, a=rng.uniform(3600, 4200), b=rng.uniform(1800, 2200),
                  ph=rng.uniform(0, 6.3):
                  (a * (b / a) ** (u ** 0.6)) * (1 + 0.1 * np.sin(2 * math.pi * 1.8 * u + ph)),
                  0.34, lambda u: _leaving(u, attack=0.1, tail=1.3))
        n = len(y)
        jitter = signal.sosfilt(signal.butter(1, 6, fs=SR, output='sos'),
                                rng.normal(0, 1, n)) * 40
        phase = np.cumsum(2 * math.pi * rng.uniform(26, 34) * (1 + 0.25 * jitter) / SR)
        y *= 1 + 0.3 * np.sin(phase)
        _put_moving(m, at + 0.002, y_amp * y, pan)
    burst(m, lean - 0.01, 400, 2200, attack=0.025, tau=0.06, amp=0.04)
    m.room(t60=0.45, wet=0.12)
    return m.finish(loudness_db=-31.0, fade_out=0.15)


def special_heavy():
    """Knapped stone heads (Lava, Earth, Mud): two to five of them, slow
    (540-600 px/s) and heavy (x2.5 damage). Each leaves its rest with a
    gritty knock of flint on flint, and its cut is thick and low -- a shoved
    weight of air rather than a keen line. Three heads, ~15 ms apart."""
    m = Mix(0.55, seed=7400)
    rng = m.rng
    pans = _fan_order(rng, 3, 0.45)
    times = 0.012 + np.array([0.0, 0.014, 0.03]) + rng.uniform(-0.002, 0.002, 3)
    # A lean-in: the heads grating in the hand before they go.
    chips(m, [(0.012 * (k / 5) ** 0.8, 0.05 + 0.03 * k / 5, rng.uniform(-0.2, 0.2))
              for k in range(6)], 1400, 3200, eta=0.07, n=3, tc=0.0003, cap=0.012)
    for k, (at, p) in enumerate(zip(times, pans)):
        # Flint on flint: a dense, short knock with a little grit.
        strike(m, at, _solid(rng, rng.uniform(900, 1150), n=12, eta=0.11,
                             cap=0.014, tilt=0.12),
               tc=0.0006, amp=0.16, pan=p * 0.4)
        burst(m, at, 900, 3600, attack=0.002, tau=0.008, amp=0.05, pan=p * 0.4)
        cut(m, at + 0.003, rng.uniform(0.3, 0.38),
            rng.uniform(2300, 2700), rng.uniform(1000, 1250),
            0.11 * rng.uniform(0.85, 1.0), p * 0.3, p * 1.1, width=0.48,
            attack=0.16)
    m.air(0.0, 0.32, 260, 1200, amp=0.04, rise=0.18)
    m.room(t60=0.4, wet=0.12)
    return m.finish(loudness_db=-31.0, fade_out=0.12)


# ===========================================================================
# The ricochet
# ===========================================================================
#
# One per BOUNCE of a moving special dart (the bounce branch, when a next
# target was found). The body it bounced off already sounds -- combatHit
# Light/Heavy plays on that same frame -- so this is only the dart's part:
# its point skidding across the obsidian for a few ms, and the cut leaving
# in a new direction. Bounces come 70-170 ms apart, often from several darts
# at once; the cue's cooldown (140 ms) and these four takes keep a chain
# from machine-gunning. Short, dry, under the hit.


def ricochet(v=0):
    m = Mix(0.12, seed=7500 + v)
    rng = m.rng
    side = (-1, 1, 1, -1)[v]
    p0 = side * rng.uniform(0.05, 0.2)
    # The skid: the point catching and letting go a few times in ~8 ms.
    skid = sorted(rng.uniform(0.0, 0.008, 5))
    chips(m, [(t, 0.2 * (1 - 0.13 * k), p0) for k, t in enumerate(skid)],
          3200, 6200, eta=0.12, n=2, tc=0.0002, cap=0.003)
    burst(m, 0.0, 2500, 7000, attack=0.0015, tau=0.004, amp=0.03, pan=p0)
    # Off it goes the other way.
    cut(m, 0.004, rng.uniform(0.07, 0.09), rng.uniform(5200, 6000),
        rng.uniform(3600, 4200), 0.07, p0, -side * rng.uniform(0.3, 0.5),
        width=0.36, attack=0.1)
    m.room(t60=0.22, wet=0.07)
    return m.finish(loudness_db=-36.0, fade_out=0.03)


# ===========================================================================
# Dark: the black hole
# ===========================================================================
#
# Dark pip has no cast (isPassiveOnlyCosmicAbility): every auto-attack kill
# opens a void on the body (life 3.6 s, pulls everything within 120 px
# inward, executes the weak). drawVfxVoid draws it at full size at once and
# fades it over its last 0.5 s. Until now nothing at all was heard of it --
# a Dark pip's special was silent.
#
# The sound is the opening: the air rushing in to a point -- a wide hiss
# that narrows and darkens as it is drawn in -- and grit pulled in after it,
# the ticks coming faster, closer together, duller and toward the middle,
# as things fall into it. Then quiet: the hole holds, and the bodies it
# pulls make their own hits. It can fire on every auto kill, so a long
# cooldown (800 ms) and a modest level.


def void(v=0):
    m = Mix(1.15, seed=7600 + v)
    rng = m.rng
    inrush = 0.14

    def env(u):
        t = u * 0.95
        return smooth(t, 0.0, inrush) * (1 - smooth(t, 0.55, 0.92)) ** 1.4

    y = _band(rng, 0.95,
              lambda u: 3400 * (480 / 3400) ** (u ** 0.8),
              lambda u: 0.95 - 0.55 * u, env)
    _put_moving(m, 0.0, 0.11 * y, lambda u: 0.25 * (1 - u) * np.sin(7 * u))
    # The fine high part of the rush goes first: it is drawn off the top.
    y2 = _band(rng, 0.5, lambda u: 5200 + 0 * u, 0.5,
               lambda u: smooth(u, 0.0, 0.25) * (1 - smooth(u, 0.3, 1.0)))
    _put(m, 0.02, 0.035 * y2)
    # Grit falling in: intervals shrinking toward the swallow, each piece
    # duller, quieter and nearer the middle than the last.
    count = 14
    swallow = 0.78
    u = np.arange(count) / (count - 1)
    times = 0.1 + (swallow - 0.1) * (1 - (1 - u) ** 2.2)
    for k in range(count):
        side = 1 if k % 2 else -1
        chips(m, [(times[k] + rng.uniform(-0.006, 0.006),
                   0.1 * (1 - 0.55 * u[k]),
                   side * 0.75 * (1 - u[k]) + rng.uniform(-0.08, 0.08))],
              900, 2600, eta=0.06, n=3, tc=0.0004, cap=0.03,
              lowpass=5200 - 3400 * u[k])
    # The swallow: a soft closing of pressure, no thump.
    burst(m, swallow - 0.02, 220, 900, attack=0.03, tau=0.06, amp=0.04)
    m.room(t60=0.6, wet=0.16, darkness=2600)
    return m.finish(loudness_db=-32.0, fade_out=0.25)


# ===========================================================================
# The table
# ===========================================================================

# Which salvo each element throws (None -> sfx_special_pip, the keen
# ricochet salvo). Dark never casts: its special is the black hole, played
# as sfx_special_pip_void where the void is placed.
SPECIAL_PATTERNS = {
    'Air': None,
    'Dust': None,
    'Light': None,
    'Water': None,
    'Ice': None,
    'Crystal': None,
    'Fire': None,
    'Lightning': None,
    'Steam': None,
    'Blood': 'seeker',
    'Spirit': 'seeker',
    'Poison': 'seeker',
    'Plant': 'seeker',
    'Lava': 'heavy',
    'Earth': 'heavy',
    'Mud': 'heavy',
    'Dark': 'void',
}


def _v(build, description):
    return {'build': build, 'description': description, 'variants': 3}


CUES = {
    'sfx_basic_pip': _v(
        basic, 'Three darts flicked in one fan: dry releases inside 12 ms, '
        'three thin cuts receding left, centre and right'),
    'sfx_special_pip': (
        special_ricochet, 'A pip salvo: shafts sliding as the fan opens, a '
        'riffle of seven dry releases, keen cuts spreading wide and away'),
    'sfx_special_pip_seeker': (
        special_seeker, 'Slow homing needles: a soft riffle, then low '
        'fluttering cuts that swing out and curl back in'),
    'sfx_special_pip_heavy': (
        special_heavy, 'Three knapped stone heads let go: gritty flint '
        'knocks and thick low cuts of air'),
    'sfx_special_pip_ricochet': _v(
        ricochet, 'A dart point skidding off obsidian and cutting away the '
        'other way: dry, a few ms, under the hit'),
    'sfx_special_pip_void': _v(
        void, 'Dark pip\'s black hole opening: air rushing in to a point, '
        'narrowing and darkening, grit falling in after it'),
}
