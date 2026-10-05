"""Mystic family: the auto-attack (three motes), the world a Mystic opens,
the world closing with its caster, and the moments the weather worlds act.

What is drawn, and so what is scored (Cosmic Survival is the only mode where
a Mystic has a special -- castsSpecialOutsideSurvival in
alchemon_combat_stats.dart; open space and the dungeons play only the basic):

THE BASIC (createFamilyBasicAttack, cosmic_data.dart, case 'mystic'):
  three projectiles released on the SAME frame in a tight fan (angle +/-0.12
  rad), ProjectileVisualStyle.standard at visualScale 0.7 -- a soft element-
  coloured mote (core r 2.1 px, glow r 3.5 px), no trail -- flying at the
  default 600 px/s. The Mystic's reach is ~220-300 px, so a mote is on its
  way ~0.35-0.5 s; the hit has its own cue (combatHitLight). Interval
  1.5 s / power factor: roughly every 1-1.5 s, from up to three slots.
  -> one soft release, three-fold, receding: not three puffs in a row.

THE SPECIAL is a WORLD (cosmic_survival_game.dart _igniteMysticWorld), lit
once per deployment, holding until the caster dies or is recalled:
  0.00  the cast frame: the element accent plays, the alchemy seal
        (mystic_graphx_overlay.dart _castAlchemySeal) scales 0.55 -> 1.7 and
        turns 0.62 rad over 0.52 s while its 12 runes set in 12 ms apart,
        reagent motes are flung outward (0.4 s), a ley line runs to the
        target (0.34 s)
  0-0.6 the world comes in (_MysticEnvironment.fadeIn, linear): a vignette
        that is CLEAR IN THE MIDDLE AND GATHERS AT THE SCREEN EDGES
        (mystic_world_ambience.dart), and the element's storm starts
  then  it holds, breathing very slowly (sin(t * 0.6): ~10 s a breath)
  Dark's maw opens over 1.1 s (open += dt * 0.9) and Plant's two vines grow
  over 0.9 s (growth += dt * 1.1): those two RISE after the seal; every other
  world either places its thing at full strength at once (embers, fissures,
  maelstrom, tornado, star) or is a rule with nothing placed.
  Closing (caster dead or recalled): the world fades over 1.8 s
  (_MysticEnvironment.fadeOut), its entities at 0.5-0.9 per second.

THE WEATHER WORLDS act later, on the world's own clock -- those are the
moments that matter, and none of them had its own sound:
  Lightning  every 10 s: the sky marks a spot and charges for 0.62 s
             (_MysticCharge.windUp; white snap from 82 %), then the bolt
             lands (0.36 s), the whole sky flashes, the view shakes -- and
             nothing was played at all
  Earth      every 15 s: a tremor that never stops, rising as closing^4
             toward the quake (_updateMysticWeatherClocks), then the quake:
             a front of rubble crosses the arena in 1.05 s (ease-out), the
             view shakes hard -- played combatHitHeavy, a knock on obsidian
  Steam      every 8 s: the arena exhales, a pale billowing front out over
             1.15 s, everything thrown outward, no damage -- played
             combatHitHeavy
  Lava       a boss crossing a crack: the crack flares (0.9 s) and 4-12
             meteors fall 0.85 s each (height 560 * (1 - t^2): gravity),
             staggered over a further 0.85 s -- played combatHitHeavy on the
             flare frame, nothing on the landings
  Light      every 18-46 s: the dawn star releases (flare 0.63 s, a bloom
             rolling outward, the sky flashing) and heals everything to
             full -- played combatHeal, the generic one-second heal

No world bed. A world lasts a whole fight; the ambience player holds one bed
at a time (it is the scene's); and the weather worlds already speak on their
clock. See the report for the reasoning.

Voices here (copied from combat.py so this module stands on its own):
  strike, chips, swish, burst, creak -- modal contact, small solids, air past
  an edge, a puff of pressure, stick-slip friction; plus
  wide      decorrelated air at both edges of the field (the vignette)
  rumble    low turbulent noise whose rolls are irregular bumps (thunder,
            the ground heaving), with the low end held back
"""
import math
import warnings

import numpy as np
from scipy import signal

from sounds.core import SR, Mix, smooth

# ===========================================================================
# Voices
# ===========================================================================


def _put(m, start, mono, pan=0.0):
    s0 = m._at(start)
    mono = mono[: m.n - s0]
    gl, gr = m._gains(float(np.clip(pan, -1, 1)))
    m.y[0, s0:s0 + len(mono)] += gl * mono
    m.y[1, s0:s0 + len(mono)] += gr * mono


def _sos(kind, f, order=2):
    return signal.butter(order, f, btype=kind, fs=SR, output='sos')


def _contact(tc):
    """A Hertzian half-sine contact of [tc] seconds: short = hard."""
    n = max(2, round(tc * SR))
    p = np.sin(np.linspace(0, math.pi, n + 2)[1:-1])
    return p / p.sum()


def _ring(freqs, t60s, amps, length):
    t = np.arange(round(length * SR)) / SR
    out = np.zeros(len(t))
    for f, t60, a in zip(freqs, t60s, amps):
        if f > SR * 0.45:
            continue
        out += a * np.exp(-6.9 * t / t60) * np.sin(2 * math.pi * f * t)
    return out


def _solid(rng, f0, n=14, spread=(0.10, 0.38), eta=0.05, cap=0.2, tilt=0.12):
    """Modes of an irregular solid: inharmonic, each decaying with a constant
    loss factor [eta] (stone ~0.03-0.08). [cap] limits the longest ring."""
    ratios = np.cumprod(np.r_[1.0, 1.0 + rng.uniform(*spread, n - 1)])
    f = f0 * ratios
    t60 = np.minimum(2.2 / (eta * f), cap)
    a = np.exp(-tilt * np.arange(n)) * rng.uniform(0.45, 1.0, n)
    a *= rng.choice([-1.0, 1.0], n)
    return f, t60, a


def strike(m, start, modes, tc, amp, pan=0.0, length=None, lowpass=None):
    f, t60, a = modes
    length = length or min(1.5, float(np.max(t60)) * 1.3 + 0.01)
    out = signal.fftconvolve(_contact(tc), _ring(f, t60, a, length))
    out = signal.sosfilt(_sos('highpass', 0.7 * float(np.min(f))), out)
    if lowpass:
        out = signal.sosfilt(_sos('lowpass', lowpass), out)
    _put(m, start, amp * out, pan)


def chips(m, events, f_lo, f_hi, eta=0.05, n=4, tc=0.0004, cap=0.08,
          lowpass=None):
    """Small solids struck at [events] = [(time, size, pan)]."""
    rng = m.rng
    for t0, size, pan in events:
        f0 = math.exp(rng.uniform(math.log(f_lo), math.log(f_hi)))
        modes = _solid(rng, f0, n=n, spread=(0.18, 0.6), eta=eta, cap=cap,
                       tilt=0.25)
        strike(m, t0, modes, tc * rng.uniform(0.7, 1.4), size, pan,
               lowpass=lowpass)


def swish(m, start, length, fc, width, env, amp, pan=0.0):
    """Air past an edge: noise carved frame by frame into a band centred on
    [fc](u) Hz, [width] wide in natural-log units, loudness [env](u), over
    u = 0..1 of [length]. The band slides and never settles into a whistle."""
    n = round(length * SR)
    nper, hop = 512, 128
    pad = nper
    noise = m.rng.normal(0, 1, n + 2 * pad)
    f, tt, z = signal.stft(noise, fs=SR, nperseg=nper, noverlap=nper - hop,
                           boundary=None, padded=False)
    u = np.clip((tt - pad / SR) / length, 0, 1)
    centre = np.log(np.maximum(fc(u), 50))
    logf = np.log(np.maximum(f, 20))[:, None]
    shape = np.exp(-0.5 * ((logf - centre[None, :]) / width) ** 2)
    shape /= np.sqrt(np.maximum(f, 100) / 1000)[:, None]
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', UserWarning)
        _, y = signal.istft(z * shape, fs=SR, nperseg=nper,
                            noverlap=nper - hop, boundary=False)
    y = y[pad:pad + n]
    y *= 0.15 / max(float(np.sqrt(np.mean(y ** 2))), 1e-12)
    uu = np.arange(n) / max(n - 1, 1)
    # Whatever the envelope, it closes to nothing: a band cut off mid-breath
    # is a click.
    taper = np.clip((1 - uu) / 0.06, 0, 1) ** 2
    _put(m, start, amp * env(uu) * taper * y, pan)


def burst(m, start, low, high, attack, tau, amp, pan=0.0, length=None):
    """A puff of pressure: band noise leaning in over [attack], dying [tau]."""
    length = length or attack + 6 * tau
    n = round(length * SR)
    t = np.arange(n) / SR
    env = np.where(t < attack, (t / attack) ** 2, np.exp(-(t - attack) / tau))
    noise = signal.sosfilt(_sos('bandpass', [low, high]), m.rng.normal(0, 1, n))
    _put(m, start, amp * env * noise, pan)


def creak(m, start, length, rate, jitter, body, amp, env, pan=0.0):
    """Stick-slip friction: catches and lets go [rate](u) times a second,
    each slip ringing [body] = (freqs, t60s, amps)."""
    n = round(length * SR)
    x = np.zeros(n)
    t = 0.0
    grip = 1.0
    while t < length:
        u = t / length
        grip = float(np.clip(grip + 0.18 * m.rng.normal(), 0.35, 1.0))
        x[int(t * SR)] += env(u) * grip * m.rng.uniform(0.5, 1.0)
        t += max(1.0 / rate(u) * (1 + jitter * m.rng.normal()), 0.002)
    x = signal.fftconvolve(x, _contact(0.0008))[:n]
    f, t60, a = body
    out = signal.fftconvolve(x, _ring(f, t60, a, float(np.max(t60)) * 1.3))
    out = out[:n + 2400]
    out = signal.sosfilt(_sos('highpass', 0.7 * float(np.min(f))), out)
    _put(m, start, amp * out, pan)


def wide(m, start, length, fc, width, env, amp, spread=0.9):
    """The world at the edges of the screen: two independent airs, one each
    side, so the middle is hollow -- the vignette is clear in the centre and
    gathers at the edges, and the element's accent is the thing in the
    middle."""
    for side in (-spread, spread):
        swish(m, start, length, fc, width, env, amp, side)


def rumble(m, start, length, low, high, amp, env, rolls, pan=0.0, rate=7.0):
    """Low turbulent noise -- thunder, the ground heaving. [rolls] are
    (time, gain, width) bumps: a roll is irregular, never a pulse. [rate]
    is how fast the turbulence churns. The band starts well above what a
    phone drops, so it is heard, not just felt in headphones."""
    n = round(length * SR)
    t = np.arange(n) / SR
    noise = signal.sosfilt(_sos('bandpass', [low, high], 2), m.rng.normal(0, 1, n))
    churn = signal.sosfilt(_sos('lowpass', rate, 2), m.rng.normal(0, 1, n))
    churn = 1 + 0.6 * churn / max(float(np.std(churn)), 1e-9)
    shape = np.zeros(n)
    for t0, g, w in rolls:
        shape += g * np.exp(-0.5 * ((t - t0) / w) ** 2)
    out = noise * np.clip(churn, 0.1, 3) * shape * env(t)
    _put(m, start, amp * out, pan)


def _poisson(rng, t0, t1, rate, step=0.002):
    """Times of events between t0 and t1 at [rate](t) per second."""
    grid = np.arange(t0, t1, step)
    hit = rng.random(len(grid)) < np.clip(rate(grid) * step, 0, 1)
    return grid[hit] + rng.uniform(0, step, int(hit.sum()))


def _sub(m):
    """A second buffer the same length, for a layer with its own room."""
    s = Mix(m.n / SR, seed=int(m.rng.integers(1 << 30)))
    return s


# ===========================================================================
# The basic -- three motes let go together
# ===========================================================================

MOTE_FLIGHT = 0.38   # ~230 px of reach at Projectile.speed 600 px/s


def basic_mystic(v=0):
    """Three soft motes leave on one frame in a tight fan: a single hushed
    release, three-fold -- three narrow airs a hair apart in the field,
    receding together -- with a breath of warmth under it. The hit is its
    own cue."""
    m = Mix(MOTE_FLIGHT + 0.12, seed=7100 + v)
    rng = m.rng
    # The release: one breath, leaning in over ~14 ms (no puff-per-mote).
    burst(m, 0.0, 420, 2200, attack=0.014, tau=0.025, amp=0.03)
    # The three motes: the fan is +/-0.12 rad, so they sit close together
    # and drift a little apart; each its own band, none related.
    centres = np.sort(rng.uniform(2000, 3800, 3)) * (1, 1.04, 1.08)
    order = (-0.18, 0.0, 0.18) if v % 2 == 0 else (0.18, 0.0, -0.18)
    for k, pan in enumerate(order):
        f0 = centres[k]
        life = MOTE_FLIGHT * rng.uniform(0.82, 1.0)
        swish(m, 0.002 + rng.uniform(0, 0.004), life,
              lambda u, f0=f0: f0 * (1 - 0.16 * u), 0.2,
              lambda u: np.where(u < 0.05, (u / 0.05) ** 2,
                                 np.exp(-(u - 0.05) / 0.42)),
              0.04, pan)
    # The motes' glow, as a whisper of a warm body under the air.
    m.glass(0.004, rng.uniform(470, 610), amp=0.005, ring=0.22, attack=0.012,
            brightness=0.1, beat=2.2, ratios=[1.0, 2.32, 4.25])
    m.room(t60=0.4, wet=0.14)
    return m.finish(loudness_db=-35.0, fade_out=0.09)


# ===========================================================================
# The world opening
# ===========================================================================

SEAL = 0.52       # _castAlchemySeal: the root's scale/turn/fade tween
WORLD_IN = 0.6    # _MysticEnvironment.fadeIn
RISE = 1.0        # maw open (1 / 0.9 = 1.11 s) and grove growth (0.91 s)
CLOSE = 1.8       # _MysticEnvironment.fadeOut


def _scribe(m, amp):
    """The seal turning: a stylus drawing a circle on stone, one quick turn
    under the element's accent, its runes set as it goes."""
    rng = m.rng
    body = _solid(rng, 1700, n=6, spread=(0.2, 0.5), eta=0.07, cap=0.02,
                  tilt=0.3)
    creak(m, 0.004, 0.2, lambda u: 220 + 160 * u, 0.35, body, amp,
          lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.6) ** 2, pan=-0.1)


def _bodies(m, start, attack, ring, amp):
    """The two counter-rotating rings of the sigil as two low stroked glass
    bodies that beat slowly against each other: a body under the world,
    never its peak."""
    m.glass(start, 127.0, amp=amp, ring=ring, attack=attack, brightness=0.12,
            pan=-0.35, beat=0.55, ratios=[1.0, 2.19, 3.89, 5.91])
    m.glass(start + 0.04, 134.6, amp=amp * 0.85, ring=ring * 0.9,
            attack=attack * 1.1, brightness=0.12, pan=0.35, beat=0.7,
            ratios=[1.0, 2.19, 3.89, 5.91])


def _world(m, rise, tail, amp=1.0):
    """The world coming in from the screen's edges over [rise] seconds, and
    the space it makes ringing out over [tail]."""
    length = rise + tail
    world = _sub(m)

    def env(u):
        t = u * length
        up = smooth(t, 0.0, rise)
        # Held while it settles, then let go into the room slowly: the world
        # stays (it is the vignette that stays, quietly), the arrival goes.
        down = np.where(t < rise + 0.15, 1.0,
                        np.exp(-(t - rise - 0.15) / (tail * 0.32)))
        return up * down

    # The pressure of it: low-mid air at both edges, warming as it arrives.
    wide(world, 0.0, length,
         lambda u: 380 + 420 * smooth(u * length, 0, rise), 0.55, env,
         0.11 * amp)
    # Its sheen: a finer air over it, thinner, also at the edges.
    wide(world, 0.05, length - 0.05,
         lambda u: 2300 + 900 * smooth(u * length, 0, rise), 0.45,
         lambda u: env(u) ** 1.4, 0.03 * amp, spread=0.75)
    # A slow breath drawn in under the seal: the space opening.
    world.air(0.0, rise + 0.9, 150, 900, amp=0.035 * amp, rise=0.55)
    _bodies(world, 0.05, attack=rise * 0.8, ring=tail * 0.9, amp=0.014 * amp)
    # A big dark room: this is a world, not a spell.
    world.room(t60=2.6, wet=0.5, darkness=2800)
    m.y += world.y


def special_mystic():
    """A Mystic opens its world: under the element's accent, the seal is
    scribed in one turn, and the world gathers in from the screen's edges
    over 0.6 s -- hollow in the middle, wide at the sides -- and opens into
    a large dark space that rings on quietly."""
    tail = 2.6
    m = Mix(WORLD_IN + tail + 0.2, seed=7200)
    _scribe(m, 0.05)
    _world(m, WORLD_IN, tail)
    m.room(t60=0.5, wet=0.1)
    return m.finish(loudness_db=-32.0, fade_out=0.6)


def special_mystic_rise():
    """A world that grows a thing after the seal (Dark's maw opening over
    1.1 s, Plant's vines growing over 0.9 s): the same edges, gathering
    slower, and a heavy material straining open under them that reaches its
    full at ~1 s and settles."""
    tail = 2.6
    m = Mix(RISE + tail + 0.2, seed=7300)
    rng = m.rng
    _scribe(m, 0.05)
    _world(m, RISE, tail, amp=0.9)
    # Something large straining open: slow stick-slip through a heavy body,
    # catching faster as it opens, let go once it is open.
    body = _solid(rng, 210, n=16, spread=(0.08, 0.3), eta=0.06, cap=0.12,
                  tilt=0.08)
    creak(m, 0.12, RISE + 0.25,
          lambda u: 14 + 46 * u ** 1.5, 0.4, body, 0.16,
          lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 1.3) ** 2 * (0.4 + 0.6 * u),
          pan=0.05)
    # Its weight: a low pressure that swells with it.
    m.air(0.1, RISE + 0.7, 110, 520, amp=0.05, rise=0.62)
    m.room(t60=0.9, wet=0.18)
    return m.finish(loudness_db=-31.0, fade_out=0.6)


def special_mystic_close():
    """The caster is gone and its world closes over 1.8 s: the air at the
    edges thins and darkens and the big room shrinks to nothing, the sigil's
    bodies released."""
    m = Mix(CLOSE + 0.6, seed=7400)
    length = CLOSE + 0.3

    def env(u):
        t = u * length
        # Already there: a soft lean-in, then the linear fade the world has.
        return smooth(t, 0, 0.18) * np.clip(1 - t / CLOSE, 0, 1) ** 1.3

    world = _sub(m)
    wide(world, 0.0, length, lambda u: 820 - 520 * u, 0.55, env, 0.11)
    wide(world, 0.0, length * 0.6, lambda u: 2600 - 1200 * u, 0.45,
         lambda u: env(u * 0.6) ** 1.6, 0.025, spread=0.75)
    _bodies(world, 0.0, attack=0.25, ring=1.4, amp=0.01)
    # The room is still big as it starts to close; a second, dry layer of
    # the same air carries the end, so the space seems to draw in.
    world.room(t60=1.6, wet=0.35, darkness=2200)
    m.y += world.y
    wide(m, 0.6, CLOSE - 0.5, lambda u: 420 - 180 * u, 0.5,
         lambda u: np.sin(math.pi * np.clip(u, 0, 1)) ** 2 * (1 - u), 0.035,
         spread=0.5)
    m.room(t60=0.5, wet=0.1)
    return m.finish(loudness_db=-32.0, fade_out=0.5)


# ===========================================================================
# The weather worlds' moments
# ===========================================================================

WIND_UP = 0.62        # _MysticCharge.windUp
SNAP = 0.82 * WIND_UP  # paintMysticStormCharge: the white snap begins


def special_mystic_strike(v=0):
    """Lightning world, on its clock: the sky marks a spot and charges for
    0.62 s -- static drawn in, crackling faster and brighter, a white snap at
    the end -- then the bolt tears down and the thunder rolls off far away.
    Played when the charge is laid, so the strike lands on the bolt."""
    m = Mix(WIND_UP + 2.3, seed=7500 + v)
    rng = m.rng
    # The charge: dry static ticks drawn in, faster and larger as it builds.
    times = _poisson(rng, 0.02, WIND_UP - 0.01,
                     lambda t: 25 + 520 * (t / WIND_UP) ** 2.4)
    ev = [(t0, 0.03 + 0.12 * (t0 / WIND_UP) ** 1.6 * rng.uniform(0.5, 1),
           rng.uniform(-0.25, 0.25)) for t0 in times]
    chips(m, ev, 2800, 8000, eta=0.25, n=2, tc=0.00015, cap=0.003)
    # The air going taut, brightening into the snap.
    swish(m, 0.0, WIND_UP + 0.02,
          lambda u: 2600 + 2600 * u ** 1.5, 0.5,
          lambda u: 0.15 * u + u ** 2.2, 0.05)
    # The strike: a tearing run of crackle over ~35 ms, leaning in over the
    # first ~10 ms -- a dense texture, not a broadband spike.
    n_tear = 70
    tear = np.sort(WIND_UP - 0.004 + rng.gamma(1.6, 0.012, n_tear))
    ev = [(t0, 0.09 * rng.uniform(0.5, 1) * math.exp(-(t0 - WIND_UP) / 0.05)
           * min(1.0, (t0 - WIND_UP + 0.012) / 0.014),
           rng.uniform(-0.35, 0.35)) for t0 in tear]
    chips(m, ev, 1400, 7000, eta=0.2, n=2, tc=0.0002, cap=0.004)
    burst(m, WIND_UP - 0.004, 900, 5200, attack=0.01, tau=0.05, amp=0.05)
    # Thunder, far off: rolls arriving after the light (sound is slower),
    # wide and dark, under the strike rather than over it.
    t_roll = WIND_UP + 0.12
    rolls = [(0.05, 1.0, 0.07)]
    at = 0.05
    for k in range(4):
        at += rng.uniform(0.18, 0.42)
        rolls.append((at, rng.uniform(0.45, 0.85) * math.exp(-k * 0.35),
                      rng.uniform(0.08, 0.16)))
    for side in (-0.7, 0.7):
        rumble(m, t_roll, 2.0, 160, 800, 0.045,
               lambda t: smooth(t, 0, 0.05) * np.exp(-t / 0.9),
               rolls, pan=side * rng.uniform(0.8, 1.0))
    m.room(t60=2.2, wet=0.35, darkness=2600)
    return m.finish(loudness_db=-31.0, fade_out=0.6)


QUAKE_LEAD = 1.6      # the cue starts this long before the quake (see report)
QUAKE_FRONT = 1.05    # _MysticQuake.maxAge: the front crossing the arena
QUAKE_BEAT = 15.0     # kMysticQuakeInterval


def _tremor(t):
    """_tremor in pixels at cue time t (quake at QUAKE_LEAD): 0.9 + 7.5 *
    closing^4, closing = 1 - next / beat."""
    closing = 1 - np.clip(QUAKE_LEAD - t, 0, None) / QUAKE_BEAT
    return 0.9 + 7.5 * closing ** 4


def special_mystic_quake(v=0):
    """Earth world, on its clock: the ground that never quite stops
    trembling grinds harder as the quake comes, then heaves -- a mass of
    rubble thrown up along a front that crosses the arena in a second, the
    ground splitting behind it -- and settles in grit."""
    m = Mix(QUAKE_LEAD + QUAKE_FRONT + 1.8, seed=7600 + v)
    rng = m.rng
    lead = QUAKE_LEAD
    # How hard it is trembling, 0..1 over the lead (the tremor curve,
    # stretched so the build is heard from quiet).
    def strain(t):
        x = (_tremor(t) - _tremor(0.0)) / (_tremor(lead) - _tremor(0.0))
        return np.clip(x, 0, 1) * (t <= lead + 0.02)

    # The strain: stone grinding on stone, catching faster as it builds.
    body = _solid(rng, 240, n=14, spread=(0.1, 0.35), eta=0.07, cap=0.08,
                  tilt=0.1)
    creak(m, 0.0, lead, lambda u: 18 + 70 * strain(u * lead) ** 1.2, 0.45,
          body, 0.1, lambda u: 0.15 + 0.85 * strain(u * lead), pan=-0.15)
    body = _solid(rng, 330, n=14, spread=(0.1, 0.35), eta=0.07, cap=0.07,
                  tilt=0.1)
    creak(m, 0.03, lead, lambda u: 14 + 60 * strain(u * lead) ** 1.2, 0.45,
          body, 0.08, lambda u: 0.1 + 0.9 * strain(u * lead), pan=0.2)
    # Its low churn, rising under the grinding.
    for side in (-0.5, 0.5):
        rumble(m, 0.0, lead + 0.05, 160, 700, 0.035,
               lambda t: 0.08 + strain(t) ** 1.5, [(lead * 0.5, 1.0, lead)],
               pan=side, rate=11)
    # Grit shaken loose, more and more of it.
    times = _poisson(rng, 0.1, lead, lambda t: 6 + 70 * strain(t) ** 2)
    chips(m, [(t0, 0.03 + 0.05 * float(strain(t0)), rng.uniform(-0.6, 0.6))
              for t0 in times], 1200, 3600, eta=0.08, n=3, tc=0.0003,
          cap=0.02)

    # THE QUAKE. Not a hit: the texture changes over ~40 ms -- the ground
    # heaving, a front of rubble thrown up as it goes (ease-out radius,
    # (1 - t)^2 strength), the view shaking hardest in the first ~0.3 s.
    def front(t):
        x = np.clip((t - lead) / QUAKE_FRONT, 0, 1)
        return 1 - (1 - x) ** 2

    def fade(t):
        x = np.clip((t - lead) / QUAKE_FRONT, 0, 1)
        return (1 - x) ** 2

    for side in (-0.75, 0.0, 0.75):
        rumble(m, lead - 0.02, QUAKE_FRONT + 1.2, 150, 800, 0.24,
               lambda t: smooth(t, 0, 0.045) * (0.25 + 0.75 * fade(t + lead))
               * np.exp(-np.clip(t - QUAKE_FRONT, 0, None) / 0.35),
               [(0.12, 1.0, 0.16), (0.42, 0.55, 0.2), (0.85, 0.3, 0.25)],
               pan=side, rate=14)
    # The rubble on the front: thickest as it leaves the middle (the front
    # is fastest at first), spreading outward through the stereo field.
    times = _poisson(rng, lead, lead + QUAKE_FRONT,
                     lambda t: 420 * (fade(t) + 0.05) * smooth(t, lead, lead + 0.04))
    ev = []
    for t0 in times:
        side = rng.choice([-1.0, 1.0])
        ev.append((t0, rng.uniform(0.09, 0.22) * (0.3 + 0.7 * float(fade(t0))),
                   side * (0.1 + 0.85 * float(front(t0))) * rng.uniform(0.7, 1)))
    chips(m, ev, 200, 900, eta=0.06, n=4, tc=0.0012, cap=0.05, lowpass=2600)
    # The ground splitting behind it: a few cracks running.
    for k in range(3):
        t0 = lead + 0.05 + 0.12 * k + rng.uniform(0, 0.05)
        span = rng.uniform(0.08, 0.14)
        cnt = 9
        uu = np.linspace(0, 1, cnt)
        side = (-0.5, 0.45, -0.1)[k]
        chips(m, [(t0 + span * (1 - (1 - u) ** 1.8), 0.025 + 0.05 * u ** 1.5,
                   side) for u in uu], 900, 2600, eta=0.05, n=3, tc=0.0004,
              cap=0.03)
    # It settles: the last grit pattering down.
    times = _poisson(rng, lead + 0.6, lead + QUAKE_FRONT + 1.4,
                     lambda t: 40 * np.exp(-(t - lead - 0.6) / 0.6))
    chips(m, [(t0, rng.uniform(0.02, 0.05), rng.uniform(-0.8, 0.8))
              for t0 in times], 900, 3000, eta=0.07, n=3, tc=0.0003, cap=0.02)
    m.room(t60=1.4, wet=0.28, darkness=2400)
    return m.finish(loudness_db=-31.0, fade_out=0.5)


VENT_FRONT = 1.15     # _MysticVent.maxAge


def special_mystic_vent(v=0):
    """Steam world, on its clock: the arena exhales. Pressure let go all at
    once -- a vast hiss leaning in over ~35 ms that leaves the middle and
    billows outward with the front, duller as it spreads, gone in ~1.2 s.
    Pressure, not fracture: nothing breaks, nothing is hurt."""
    m = Mix(VENT_FRONT + 0.9, seed=7700 + v)
    rng = m.rng
    length = VENT_FRONT + 0.4

    def fade(u):
        t = u * length
        x = np.clip(t / VENT_FRONT, 0, 1)
        return smooth(t, 0, 0.035) * ((1 - x) ** 2 + 0.06 * np.exp(-t / 0.5))

    def billow(u, ph):
        # The front's puffs: slow irregular swell on the hiss.
        t = u * length
        return 1 + 0.22 * np.sin(2 * math.pi * 2.3 * t + ph) * np.sin(
            2 * math.pi * 0.9 * t + 2 * ph)

    # The middle lets go first: the exhale leaves the centre.
    swish(m, 0.0, length * 0.55,
          lambda u: 4200 - 1600 * u, 0.7,
          lambda u: fade(u * 0.55) ** 1.6, 0.13)
    # Then it is everywhere at the edge of the front: two wide sides,
    # sinking from a hiss into a billow as the front widens.
    for side in (-0.85, 0.85):
        ph = rng.uniform(0, 2 * math.pi)
        swish(m, 0.004, length,
              lambda u: 3400 * (1 - 0.65 * (1 - (1 - np.clip(
                  u * length / VENT_FRONT, 0, 1)) ** 2)), 0.8,
              lambda u, ph=ph: fade(u) * billow(u, ph), 0.12, side)
    # The weight of air moving: a soft low push, no thump.
    burst(m, 0.0, 120, 600, attack=0.04, tau=0.3, amp=0.05)
    m.room(t60=1.3, wet=0.3, darkness=3600)
    return m.finish(loudness_db=-30.0, fade_out=0.35)


METEOR_FALL = 0.85    # _MysticMeteor.fallTime, and the stagger on top of it
FLARE = 1 / 1.1       # fissure.flare decay: 0.91 s


def special_mystic_rain(v=0):
    """Lava world, a boss on a crack: the crack flares -- a molten roar
    with fire spitting off it -- and the rocks come down out of the sky,
    the rush of them growing as they near the ground and thinning as they
    land (each landing is its own cue)."""
    m = Mix(2 * METEOR_FALL + 0.6, seed=7800 + v)
    rng = m.rng
    # The crack flaring: a low molten roar that dies with the glow.
    rumble(m, 0.0, FLARE + 0.3, 160, 1100, 0.12,
           lambda t: smooth(t, 0, 0.04) * np.clip(1 - t / FLARE, 0, 1) ** 1.2,
           [(0.25, 1.0, 0.35)], pan=0.0, rate=18)
    # Fire spitting off it: dry pops, thickest as it flares.
    times = _poisson(rng, 0.01, FLARE, lambda t: 70 * (1 - t / FLARE) ** 1.5)
    chips(m, [(t0, rng.uniform(0.02, 0.06), rng.uniform(-0.3, 0.3))
              for t0 in times], 1500, 5000, eta=0.2, n=2, tc=0.00025,
          cap=0.006)
    # The rocks coming down: the drawn fall accelerates (height 560 *
    # (1 - t^2)), so each one's rush grows into the ground. Five of them,
    # spread over the stagger; the field thins as they land.
    for k in range(5):
        land = METEOR_FALL + rng.uniform(0, METEOR_FALL)
        start = land - METEOR_FALL
        pan = rng.uniform(-0.7, 0.7)
        swish(m, start, METEOR_FALL - 0.015,
              lambda u: 700 + 1300 * u ** 2, 0.5,
              lambda u: (u ** 2) ** 1.4 * smooth(u, 0, 0.3), 0.07, pan)
    m.room(t60=1.1, wet=0.25, darkness=3000)
    return m.finish(loudness_db=-31.0, fade_out=0.4)


def special_mystic_meteor(v=0):
    """One molten rock hitting the arena floor: a dull heavy landing with
    body (a soft contact into many damped modes, not a drum), the crust
    crunching, spatter thrown, and the scorch hissing as it cools."""
    m = Mix(0.9, seed=7900 + v)
    rng = m.rng
    pan = (-0.2, 0.25, -0.05, 0.15)[v]
    # A heavy, soft body landing: many modes, heavily damped, no pitch.
    strike(m, 0.004, _solid(rng, (230, 210, 250, 220)[v], n=18,
                            spread=(0.07, 0.28), eta=0.09, cap=0.07, tilt=0.07),
           tc=0.006, amp=0.16, pan=pan, lowpass=2000)
    # The crust giving: a crunch over ~25 ms.
    t_c = 0.008 + np.sort(rng.gamma(2.2, 0.009, 16))
    chips(m, [(t0, rng.uniform(0.025, 0.06), pan + rng.uniform(-0.2, 0.2))
              for t0 in t_c], 500, 2200, eta=0.06, n=3, tc=0.0008, cap=0.03)
    # Spatter: molten pieces thrown, dry pops landing around it.
    t_s = 0.04 + np.sort(rng.exponential(0.09, 9))
    chips(m, [(t0, rng.uniform(0.02, 0.05), pan + rng.uniform(-0.6, 0.6))
              for t0 in t_s], 1600, 4800, eta=0.2, n=2, tc=0.00025, cap=0.005)
    # The scorch: a hiss of heat cooling.
    swish(m, 0.03, 0.7, lambda u: 4200 - 800 * u, 0.6,
          lambda u: smooth(u, 0, 0.06) * np.exp(-u / 0.35), 0.05, pan)
    m.room(t60=0.6, wet=0.16)
    return m.finish(loudness_db=-33.0, fade_out=0.2)


DAWN_FLARE = 1 / 1.6   # star.flare decay: 0.63 s
SKY_FLASH = 1 / 3.4    # _mysticSkyFlash decay: 0.29 s


def special_mystic_dawn():
    """Light world: the star on the horizon breaks. A warm rush of air
    rolling out from it as the bloom spreads and the sky flashes, then the
    space lit and warm: two low bodies glowing under a long open room.
    Everything the player owns is whole again; no chime says so."""
    m = Mix(3.2, seed=8000)
    rng = m.rng
    # The star sits up and to the right of the orb (0.62, -0.78 of the
    # arena): the bloom starts there and rolls across.
    # The rush: leans in over ~60 ms with the flash, rolls outward with the
    # bloom (its band widening), and goes with the flare.
    swish(m, 0.0, DAWN_FLARE + 0.9,
          lambda u: 900 + 900 * smooth(u, 0, 0.3), 0.75,
          lambda u: smooth(u * (DAWN_FLARE + 0.9), 0, 0.06)
          * np.exp(-u * (DAWN_FLARE + 0.9) / 0.45), 0.12, pan=0.35)
    wide(m, 0.03, DAWN_FLARE + 1.2,
         lambda u: 700 + 500 * u, 0.6,
         lambda u: smooth(u * (DAWN_FLARE + 1.2), 0, 0.15)
         * np.exp(-u * (DAWN_FLARE + 1.2) / 0.7), 0.07)
    # The light itself as a fine air high up, the brightness of the flash.
    swish(m, 0.0, SKY_FLASH + 0.5,
          lambda u: 5200 + 900 * u, 0.4,
          lambda u: smooth(u * (SKY_FLASH + 0.5), 0, 0.04)
          * np.exp(-u * (SKY_FLASH + 0.5) / 0.22), 0.03, pan=0.2)
    # Warmth: two low bodies glowing up under it, slow, never the peak.
    m.glass(0.02, 174.0, amp=0.012, ring=2.6, attack=0.22, brightness=0.2,
            pan=0.1, beat=0.6, ratios=[1.0, 2.19, 3.89])
    m.glass(0.08, 231.0, amp=0.01, ring=2.4, attack=0.3, brightness=0.15,
            pan=0.4, beat=0.5, ratios=[1.0, 2.19, 3.89])
    m.air(0.1, 2.6, 200, 1400, amp=0.022, rise=0.15, pan=0.2)
    m.room(t60=2.8, wet=0.5, darkness=4000)
    return m.finish(loudness_db=-30.0, fade_out=0.7)


# ===========================================================================
# Which world opens which way
# ===========================================================================

# The element -> special file for a Mystic's cast. None plays the family
# cue (sfx_special_mystic); 'rise' plays sfx_special_mystic_rise.
SPECIAL_PATTERNS = {
    'Fire': None,       # embers placed at once across the arena
    'Lava': None,       # cracks placed at once (their flare: _rain)
    'Lightning': None,  # a rule on a clock (its strike: _strike)
    'Water': None,      # maelstrom placed at once
    'Ice': None,        # a rule: everything slowed
    'Steam': None,      # a rule on a clock (its exhale: _vent)
    'Earth': None,      # a rule on a clock (its quake: _quake)
    'Mud': None,        # a rule on the ship's guns
    'Dust': None,       # a rule on shooters
    'Crystal': None,    # a rule on kills
    'Air': None,        # tornado placed at once
    'Plant': 'rise',    # two vines growing for 0.9 s
    'Poison': None,     # a rule on the ship's wake
    'Spirit': None,     # a rule on deaths
    'Dark': 'rise',     # the maw opening for 1.1 s
    'Light': None,      # a star placed at once (its dawn: _dawn)
    'Blood': None,      # a rule on auto attacks
}


def _v(build, description):
    return {'build': build, 'description': description, 'variants': 3}


CUES = {
    'sfx_basic_mystic': _v(
        basic_mystic,
        'Three soft motes let go on one frame: a single hushed release, '
        'three narrow airs receding together, a breath of warmth under it'),
    'sfx_special_mystic': (
        special_mystic,
        'A Mystic opens its world: the seal scribed in one turn, the world '
        'gathering in from the screen\'s edges over 0.6 s into a large dark '
        'space that rings on'),
    'sfx_special_mystic_rise': (
        special_mystic_rise,
        'A world that grows after the seal (Dark\'s maw, Plant\'s grove): '
        'the edges gather slower over a heavy material straining open for ~1 s'),
    'sfx_special_mystic_close': (
        special_mystic_close,
        'The caster gone, its world closes over 1.8 s: the edge air thins '
        'and darkens and the big room draws in to nothing'),
    'sfx_special_mystic_strike': _v(
        special_mystic_strike,
        'Lightning world: static drawn in for 0.62 s, a tearing strike, '
        'thunder rolling off far away'),
    'sfx_special_mystic_quake': _v(
        special_mystic_quake,
        'Earth world: stone grinding harder for 1.6 s, then the ground heaves '
        'and a front of rubble crosses the arena; grit settles'),
    'sfx_special_mystic_vent': _v(
        special_mystic_vent,
        'Steam world: the arena exhales -- a vast hiss leaving the middle and '
        'billowing outward with the front, gone in ~1.2 s'),
    'sfx_special_mystic_rain': _v(
        special_mystic_rain,
        'Lava world: a crack flares with a molten roar and spitting fire, '
        'and rocks rush down out of the sky'),
    'sfx_special_mystic_meteor': _v(
        special_mystic_meteor,
        'One molten rock landing: a dull heavy body, the crust crunching, '
        'spatter, the scorch hissing'),
    'sfx_special_mystic_dawn': (
        special_mystic_dawn,
        'Light world: the star breaks -- a warm rush rolling out with the '
        'bloom, then a lit, open space with two low bodies glowing under it'),
}
