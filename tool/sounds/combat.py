"""Combat: the hits, kills and hurts shared by the open cosmos, Cosmic
Survival and the planet dungeons; the eight family auto-attacks; the end of
a fight.

What is being hit, and so what it sounds like:

  * ENEMIES are near-black obsidian solids lit only from inside (the enemy
    look rework, enemy_body_art.dart / boss_forms.dart). A hit on one is a
    dense stone knock -- many inharmonic modes, heavily damped, with grit at
    the contact -- and a kill is that solid cracking: a fracture that leans
    in, a break with body, and the discrete shards it throws. Never a
    cymbal-like burst, never a pitched bonk.
  * The SHIP is a dark-glass hull (ship_art.dart): a blow on it is heard
    from inside -- muffled plate, a rattle of loose things.
  * The ORB's shield is a glass bubble (orb_art.dart paintOrbReadings), so
    glass is right there and nowhere else in the family.
  * Each family's auto-attack is the THING it throws (createFamilyBasicAttack
    in cosmic_data.dart) -- blades, a burning rock, darts, a ram, a blown
    dart, a wing beat, a charged line, three small sigils -- told apart by
    material and gesture, never by pitch. They are the most repeated sounds
    in the game: short, quiet, four real takes each.

Voices added here (core.py is shared and stays as it is):

  strike   modal synthesis: a contact pulse (Hertz half-sine, its width sets
           how hard the contact is) rung through damped inharmonic modes
  chips    many tiny strikes at given moments: fracture crackle, shards,
           flakes, embers
  swish    air moving past an edge: noise whose band moves with the edge
  burst    a puff of pressure: filtered noise, quick in, exponential out
  creak    stick-slip friction: an irregular impulse train through a body
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


def _contact(tc):
    """The force of a contact lasting [tc] seconds: a Hertzian half-sine.
    Short is hard (bright), long is soft (dull). Unit area."""
    n = max(2, round(tc * SR))
    p = np.sin(np.linspace(0, math.pi, n + 2)[1:-1])
    return p / p.sum()


def _ring(freqs, t60s, amps, length, phases=None):
    t = np.arange(round(length * SR)) / SR
    out = np.zeros(len(t))
    for k, (f, t60, a) in enumerate(zip(freqs, t60s, amps)):
        if f > SR * 0.45:
            continue
        ph = 0.0 if phases is None else phases[k]
        out += a * np.exp(-6.9 * t / t60) * np.sin(2 * math.pi * f * t + ph)
    return out


def _solid(rng, f0, n=14, spread=(0.10, 0.38), eta=0.05, cap=0.2, tilt=0.12):
    """The modes of an irregular solid chunk: inharmonic, irregularly spaced,
    each decaying in proportion to its frequency (a constant loss factor
    [eta]: stone ~0.03-0.08, metal ~0.002-0.01). [cap] limits the longest
    ring, which is also what keeps the lowest mode from reading as a drum."""
    ratios = np.cumprod(np.r_[1.0, 1.0 + rng.uniform(*spread, n - 1)])
    f = f0 * ratios
    t60 = np.minimum(2.2 / (eta * f), cap)
    a = np.exp(-tilt * np.arange(n)) * rng.uniform(0.45, 1.0, n)
    # Where it is struck and where it is heard sit on different sides of
    # each mode's nodes, so the modes do not all start in step: a real knock
    # is never one coherent spike.
    a *= rng.choice([-1.0, 1.0], n)
    return f, t60, a


def strike(m, start, modes, tc, amp, pan=0.0, length=None, lowpass=None):
    """[modes] = (freqs, t60s, amps), rung by a contact of width [tc]."""
    f, t60, a = modes
    length = length or min(1.5, float(np.max(t60)) * 1.3 + 0.01)
    out = signal.fftconvolve(_contact(tc), _ring(f, t60, a, length))
    # What reaches the ear is the surface's motion, not its displacement:
    # without this, modes that all start together sum to a slow push of
    # low end under the hit that no real knock has.
    out = signal.sosfilt(signal.butter(
        2, 0.7 * float(np.min(f)), btype='highpass', fs=SR, output='sos'), out)
    if lowpass:
        out = signal.sosfilt(
            signal.butter(2, lowpass, btype='lowpass', fs=SR, output='sos'), out)
    _put(m, start, amp * out, pan)


def chips(m, events, f_lo, f_hi, eta=0.05, n=4, tc=0.0004, cap=0.08,
          lowpass=None):
    """Small solids struck at [events] = [(time, size, pan)]: each its own
    little chunk, its own modes, so no two sound alike."""
    rng = m.rng
    for t0, size, pan in events:
        f0 = math.exp(rng.uniform(math.log(f_lo), math.log(f_hi)))
        modes = _solid(rng, f0, n=n, spread=(0.18, 0.6), eta=eta, cap=cap,
                       tilt=0.25)
        strike(m, t0, modes, tc * rng.uniform(0.7, 1.4), size, pan,
               lowpass=lowpass)


def swish(m, start, length, fc, width, env, amp, pan=0.0):
    """Air moving past an edge. [fc](u) is where the band sits (Hz) and
    [env](u) how loud it is, over u = 0..1 of [length]; [width] is the
    band's spread in natural-log units (0.3 ~ half an octave). The band is
    carved from noise frame by frame, so it slides continuously and never
    settles on a fixed resonance (which would whistle)."""
    n = round(length * SR)
    nper, hop = 512, 128
    pad = nper
    noise = m.rng.normal(0, 1, n + 2 * pad)
    f, tt, z = signal.stft(noise, fs=SR, nperseg=nper, noverlap=nper - hop,
                           boundary=None, padded=False)
    u = np.clip((tt - pad / SR) / length, 0, 1)
    centre = np.log(np.maximum(fc(u), 50))
    logf = np.log(np.maximum(f, 20))[:, None]
    # Air is not white: a band higher up is no louder than one lower down.
    shape = np.exp(-0.5 * ((logf - centre[None, :]) / width) ** 2)
    shape /= np.sqrt(np.maximum(f, 100) / 1000)[:, None]
    with warnings.catch_warnings():
        # The overlap-add is thin only in the padding, which is cut off.
        warnings.simplefilter('ignore', UserWarning)
        _, y = signal.istft(z * shape, fs=SR, nperseg=nper,
                            noverlap=nper - hop, boundary=False)
    y = y[pad:pad + n]
    y *= 0.15 / max(float(np.sqrt(np.mean(y ** 2))), 1e-12)
    uu = np.arange(n) / max(n - 1, 1)
    _put(m, start, amp * env(uu) * y, pan)


def burst(m, start, low, high, attack, tau, amp, pan=0.0, length=None,
          order=2):
    """A puff of pressure: band-limited noise that leans in over [attack]
    and dies away with time constant [tau]."""
    length = length or attack + 6 * tau
    n = round(length * SR)
    t = np.arange(n) / SR
    env = np.where(t < attack, (t / attack) ** 2,
                   np.exp(-(t - attack) / tau))
    sos = signal.butter(order, [low, high], btype='bandpass', fs=SR,
                        output='sos')
    _put(m, start, amp * env * signal.sosfilt(sos, m.rng.normal(0, 1, n)), pan)


def creak(m, start, length, rate, jitter, body, amp, env, pan=0.0):
    """Stick-slip friction: the surface catches and lets go [rate](u) times a
    second, irregularly, each slip ringing [body] = (freqs, t60s, amps)."""
    n = round(length * SR)
    x = np.zeros(n)
    t = 0.0
    # How hard it grips drifts: a slow random walk under the per-slip scatter.
    grip = 1.0
    while t < length:
        u = t / length
        i = int(t * SR)
        grip = float(np.clip(grip + 0.18 * m.rng.normal(), 0.35, 1.0))
        x[i] += env(u) * grip * m.rng.uniform(0.5, 1.0)
        t += max(1.0 / rate(u) * (1 + jitter * m.rng.normal()), 0.002)
    # A slip is a brief release of force, not a click.
    x = signal.fftconvolve(x, _contact(0.0008))[:n]
    f, t60, a = body
    out = signal.fftconvolve(x, _ring(f, t60, a, float(np.max(t60)) * 1.3))[:n + 2400]
    out = signal.sosfilt(signal.butter(
        2, 0.7 * float(np.min(f)), btype='highpass', fs=SR, output='sos'), out)
    _put(m, start, amp * out, pan)


def _fracture(start, span, count, size0, size1, pan0=0.0, pan1=0.0):
    """Events for a crack running: micro-fractures coming faster and larger
    until the piece gives at start + span. The lean-in of a break."""
    u = np.linspace(0, 1, count)
    times = start + span * (1 - (1 - u) ** 1.8)
    sizes = size0 + (size1 - size0) * u ** 1.5
    pans = pan0 + (pan1 - pan0) * u
    return list(zip(times, sizes, pans))


def _shards(rng, start, count, tau, size, spread, until):
    """The pieces a break throws: most leave at once, a few straggle. Each
    is quieter the later it comes; they fly outward, alternating sides."""
    times = start + np.minimum(rng.exponential(tau, count), until)
    times.sort()
    out = []
    for k, t0 in enumerate(times):
        side = 1 if k % 2 else -1
        late = (t0 - start) / max(until, 1e-3)
        out.append((t0, size * rng.uniform(0.6, 1.0) * (1 - 0.7 * late),
                    side * rng.uniform(0.15, spread)))
    return out


# ===========================================================================
# Impacts -- on the obsidian bodies
# ===========================================================================
#
# combatHitLight / combatHitHeavy fire on the frame the damage lands
# (_damageEnemy, _spawnProjectileHitSpark, _spawnHitSpark in all three
# modes); heavy is damage >= 100, and also every meteor crater, quake and
# pressure vent. The hit spark lives 0.3 - 0.6 s, so nothing rings past it.
# 100 ms cooldown, gain .55, four takes each.


def hit_light(v=0):
    """A small dense knock on an obsidian body, a flake or two off it."""
    m = Mix(0.2, seed=5100 + v)
    rng = m.rng
    pan = (-0.18, 0.1, 0.2, -0.08)[v]
    f0 = (360, 410, 330, 450)[v] * rng.uniform(0.95, 1.05)
    strike(m, 0.001, _solid(rng, f0, n=14, eta=0.07, cap=0.06), tc=0.0007,
           amp=1.0, pan=pan)
    # The grit at the contact: what makes it stone and not a clean bell.
    burst(m, 0.0, 900, 4200, attack=0.0012, tau=0.006, amp=0.08, pan=pan)
    chips(m, [(rng.uniform(0.006, 0.04), rng.uniform(0.25, 0.4),
               pan + rng.uniform(-0.4, 0.4)) for _ in range(2 + v % 2)],
          1800, 4200, eta=0.07, n=3, tc=0.0003, cap=0.03)
    m.room(t60=0.35, wet=0.1)
    return m.finish(loudness_db=-34.0, fade_out=0.06)


def hit_heavy(v=0):
    """A heavy blow: a bigger, lower body, crunching under it, and debris
    thrown off. Weight from the many low modes, not from a pitched thump."""
    m = Mix(0.42, seed=5110 + v)
    rng = m.rng
    pan = (0.0, -0.15, 0.15, 0.05)[v]
    f0 = (215, 240, 200, 255)[v] * rng.uniform(0.96, 1.04)
    # A softer, longer contact than the light hit: more body, less tick.
    strike(m, 0.002, _solid(rng, f0, n=20, spread=(0.08, 0.3), eta=0.055,
                            cap=0.12, tilt=0.07), tc=0.0022, amp=1.0, pan=pan)
    # The stone crunching under the blow: a short run of fracture.
    chips(m, _fracture(0.0, 0.05, 11, 0.06, 0.22, pan - 0.2, pan + 0.2),
          900, 3200, eta=0.08, n=3, tc=0.0004, cap=0.025)
    burst(m, 0.0, 400, 2600, attack=0.003, tau=0.022, amp=0.07, pan=pan)
    # Debris off it, spreading wide and thinning.
    chips(m, _shards(rng, 0.03, 6, 0.06, 0.32, 0.8, 0.22),
          700, 2600, eta=0.05, n=4, tc=0.0005, cap=0.05)
    # The air it shoves.
    m.air(0.0, 0.32, 200, 1100, amp=0.05, rise=0.07, pan=pan)
    m.room(t60=0.6, wet=0.15)
    return m.finish(loudness_db=-31.0, fade_out=0.15)


def enemy_defeat(v=0):
    """A body cracks, breaks, and throws its shards outward.

    Survival's kill flings six motes for 0.22 - 0.4 s (_spawnAlchemyPickup
    Burst); the open cosmos throws 14 for longer. So: a 30 ms fracture
    leaning in, the break, and pieces gone by ~0.3 s."""
    m = Mix(0.4, seed=5120 + v)
    rng = m.rng
    crack = 0.03
    # The crack running before it gives: the lean-in, not a burst.
    chips(m, _fracture(0.0, crack, 12, 0.08, 0.4, -0.3, 0.3),
          1800, 4800, eta=0.09, n=3, tc=0.0003, cap=0.02)
    f0 = (250, 280, 230, 300)[v] * rng.uniform(0.96, 1.04)
    strike(m, crack, _solid(rng, f0, n=16, eta=0.06, cap=0.1, tilt=0.1),
           tc=0.0012, amp=0.5)
    burst(m, crack - 0.004, 600, 3600, attack=0.004, tau=0.016, amp=0.06)
    # The shards, with body: little chunks, not glass.
    chips(m, _shards(rng, crack + 0.006, 9 + v % 3, 0.07, 0.9, 0.85, 0.3),
          650, 2400, eta=0.045, n=5, tc=0.0005, cap=0.06)
    # The dust it leaves.
    m.air(crack, 0.32, 300, 1800, amp=0.035, rise=0.12)
    m.room(t60=0.5, wet=0.14)
    return m.finish(loudness_db=-33.0, fade_out=0.1)


# ===========================================================================
# The player's side
# ===========================================================================


def player_hurt():
    """A blow on the ship's dark-glass hull, heard from inside: a muffled
    plate and a rattle of loose things. Fires when the ship or the orb loses
    health (650 ms cooldown; the ship is invincible for 0.65 s after)."""
    m = Mix(0.36, seed=5130)
    rng = m.rng
    # A plate's modes: denser and longer than stone, but heard through the
    # hull, so dull -- low-passed, with a soft contact.
    plate = _solid(rng, 300, n=18, spread=(0.12, 0.42), eta=0.03, cap=0.06,
                   tilt=0.03)
    strike(m, 0.002, plate, tc=0.003, amp=1.0, lowpass=2600)
    burst(m, 0.0, 300, 2000, attack=0.004, tau=0.03, amp=0.09)
    # The rattle: loose fittings knocking for a moment after.
    rattle = [(0.025 + rng.exponential(0.035), rng.uniform(0.05, 0.12),
               rng.uniform(-0.5, 0.5)) for _ in range(7)]
    chips(m, rattle, 1300, 3200, eta=0.012, n=3, tc=0.0003, cap=0.04)
    m.air(0.0, 0.28, 180, 900, amp=0.05, rise=0.06)
    m.room(t60=0.4, wet=0.12, darkness=2500)
    return m.finish(loudness_db=-30.0, fade_out=0.12)


_BUBBLE = [1.0, 2.32, 4.25, 6.63]  # core.glass's wine-glass modes


def shield_hit(v=0):
    """Something glances off the orb's glass bubble: a knock on thick glass,
    damped by the hit, and the air it turns aside. The knock leads; the
    glass is under it, short. 200 ms cooldown, so four takes."""
    m = Mix(0.32, seed=5140 + v)
    rng = m.rng
    pan = (-0.2, 0.15, 0.25, -0.1)[v]
    f0 = (430, 470, 400, 510)[v]
    f = f0 * np.array(_BUBBLE) * rng.uniform(0.98, 1.02, 4)
    strike(m, 0.001, (f, np.minimum(1.1 / (0.012 * f), 0.08), [1, 0.6, 0.35, 0.2]),
           tc=0.0015, amp=0.35, pan=pan)
    # The knock itself: dense, dead, short.
    strike(m, 0.001, _solid(rng, 520, n=10, eta=0.09, cap=0.03), tc=0.001,
           amp=0.55, pan=pan)
    swish(m, 0.004, 0.13, lambda u: 2400 - 900 * u, 0.4,
          lambda u: np.sin(math.pi * u ** 0.6) ** 2, 0.05, pan=pan * 2)
    m.room(t60=0.45, wet=0.14)
    return m.finish(loudness_db=-33.0, fade_out=0.08)


def shield_break():
    """The bubble gives: a crack runs round it, the shell lets go its
    pressure, and it comes apart as discrete pieces flying out."""
    m = Mix(0.95, seed=5150)
    rng = m.rng
    run = 0.07
    # The fracture travels across the bubble, left to right.
    chips(m, _fracture(0.0, run, 18, 0.05, 0.28, -0.7, 0.7),
          2000, 5200, eta=0.02, n=3, tc=0.0003, cap=0.03)
    # The shell's own body, once, damped by its breaking.
    m.glass(run, 215, amp=0.09, ring=0.5, attack=0.004, brightness=0.15,
            beat=3.0, ratios=[1.0, 2.32, 4.25])
    strike(m, run, _solid(rng, 320, n=12, eta=0.05, cap=0.08), tc=0.0015,
           amp=0.45)
    # The pressure inside it let go.
    m.air(run - 0.03, 0.5, 160, 1400, amp=0.07, rise=0.1)
    # The pieces: glass, so they ring a little -- but small, short, and
    # spreading, so they read as pieces and not as a chime.
    chips(m, _shards(rng, run + 0.005, 16, 0.09, 0.3, 0.95, 0.5),
          1300, 4200, eta=0.012, n=3, tc=0.0003, cap=0.09)
    m.room(t60=0.8, wet=0.2)
    return m.finish(loudness_db=-30.5, fade_out=0.25)


def heal():
    """Health coming back: a warm breath drawn in, a low glass stroked under
    it. Played at most once a second, often in a fight, so soft."""
    m = Mix(0.9, seed=5160)
    m.air(0.0, 0.8, 260, 1700, amp=0.08, rise=0.42)
    m.air(0.05, 0.6, 1200, 4200, amp=0.02, rise=0.5)
    m.glass(0.06, 297, amp=0.035, ring=1.0, attack=0.28, brightness=0.1,
            beat=0.8, ratios=[1.0, 2.32, 4.25])
    m.room(t60=0.8, wet=0.2)
    return m.finish(loudness_db=-34.0, fade_out=0.3)


def danger():
    """The orb drops under a quarter (its HP ring starts pulsing at 6 rad/s):
    its glass strains -- a creak swelling under pressure -- and a fissure
    runs across it. Noticeable by texture, not by a beep."""
    m = Mix(1.0, seed=5170)
    rng = m.rng
    # The strain: glass catching and slipping under load.
    body = (np.array([520, 890, 1360, 1720, 2290]) * rng.uniform(0.97, 1.03, 5),
            np.array([0.06, 0.04, 0.025, 0.018, 0.012]),
            np.array([1.0, 0.7, 0.5, 0.35, 0.2]))
    creak(m, 0.0, 0.62,
          lambda u: 36 + 16 * u + 7 * math.sin(2 * math.pi * 2.3 * u + 0.8),
          0.4, body, 0.5,
          lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.7) ** 1.5)
    # The pressure under it.
    m.air(0.0, 0.85, 120, 900, amp=0.05, rise=0.6)
    m.glass(0.05, 190, amp=0.04, ring=1.2, attack=0.35, brightness=0.1,
            beat=2.2, ratios=[1.0, 2.32, 4.25])
    # The fissure running across, at the height of the strain.
    chips(m, _fracture(0.42, 0.16, 16, 0.06, 0.26, -0.6, 0.6),
          1500, 4400, eta=0.03, n=3, tc=0.0003, cap=0.03)
    m.room(t60=0.7, wet=0.18)
    return m.finish(loudness_db=-29.0, fade_out=0.2)


def special_cast():
    """A special went off: a latch releasing, no flourish. Layered under the
    caster's element cue (gain .55), which carries the colour."""
    m = Mix(0.4, seed=5180)
    rng = m.rng
    # The pawl clicking free: a small damped metal tick.
    pawl = (np.array([2250, 3420, 5100]), np.array([0.03, 0.02, 0.012]),
            np.array([1.0, 0.6, 0.3]))
    strike(m, 0.0, pawl, tc=0.0003, amp=0.18, pan=0.1)
    # The arm it held, stopping hard: a dense, dead thunk.
    strike(m, 0.022, _solid(rng, 270, n=12, eta=0.08, cap=0.06), tc=0.0025,
           amp=0.7)
    # What the arm threw: pressure leaving.
    burst(m, 0.02, 300, 2400, attack=0.006, tau=0.05, amp=0.05)
    m.room(t60=0.45, wet=0.15)
    return m.finish(loudness_db=-32.0, fade_out=0.1)


# ===========================================================================
# The launches
# ===========================================================================


def _comb(x, f, g):
    """A short tube: a feedback comb at [f] Hz."""
    d = max(1, round(SR / f))
    a = np.zeros(d + 1)
    a[0], a[d] = 1.0, -g
    return signal.lfilter([1.0], a, x)


def projectile(v=0):
    """The ship's gun (and its missiles, and any companion shot with no
    family cue of its own): a compressed puff through a short barrel, the
    catch clicking. A soft, compact launch -- the role the approved sample
    had -- without its falling pitch."""
    m = Mix(0.16, seed=5190 + v)
    rng = m.rng
    tube = (720, 660, 780, 700)[v] * rng.uniform(0.98, 1.02)
    n = round(0.09 * SR)
    t = np.arange(n) / SR
    env = np.where(t < 0.0015, (t / 0.0015) ** 2, np.exp(-(t - 0.0015) / 0.011))
    sos = signal.butter(2, [250, 3600], btype='bandpass', fs=SR, output='sos')
    puff = signal.sosfilt(sos, rng.normal(0, 1, n)) * env
    _put(m, 0.001, 0.12 * _comb(puff, tube, 0.5), pan=(0.0, -0.1, 0.1, 0.05)[v])
    catch = (np.array([2600, 3900, 5600]) * rng.uniform(0.95, 1.05),
             np.array([0.012, 0.009, 0.006]), np.array([1.0, 0.5, 0.25]))
    strike(m, 0.0, catch, tc=0.0003, amp=0.06)
    # The bolt leaving.
    swish(m, 0.006, 0.07, lambda u: 2300 - 900 * u, 0.35,
          lambda u: np.sin(math.pi * u ** 0.5) ** 2, 0.025)
    m.room(t60=0.3, wet=0.1)
    return m.finish(loudness_db=-33.0, fade_out=0.05)


# The eight family basics. Each fires on its cast frame (the appender in
# survival, _fireDungeonBasic in the dungeon; a kin's at its beam's release).
# Gain .34, 110 ms cooldown per family, priority 0: they are allowed to be
# dropped, and are built to vanish politely. Level -35.

def _edge(u):
    """A blade's pass: comes up fast, goes a little slower."""
    return np.sin(math.pi * np.clip(u, 0, 1) ** 0.55) ** 2


# The family basics below are superseded by tool/sounds/family_<name>.py,
# which score each family's basic and special to its own drawn attack. Kept
# only as reference voices.


def basic_mane(v=0):
    """Mane throws two material blades side by side (+/-0.08 rad): two
    cuts of air, the second just behind and on the other side."""
    m = Mix(0.2, seed=5200 + v)
    rng = m.rng
    # Far enough apart to be two, close enough to be one throw.
    lag = (0.042, 0.048, 0.038, 0.045)[v]
    for k, (at, pan) in enumerate(((0.0, -0.3), (lag, 0.3))):
        lo = rng.uniform(1500, 1900)
        hi = rng.uniform(4200, 5200)
        # Each cut is quick and sharp-edged: the band sweeps up through the
        # pass and drops away, all inside ~55 ms.
        swish(m, at, 0.055,
              lambda u, lo=lo, hi=hi: lo + (hi - lo) * np.sin(math.pi * np.clip(u, 0, 1) ** 0.6),
              0.28, lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.8) ** 3,
              0.16 * (1.0 if k == 0 else 0.8), pan)
    m.room(t60=0.3, wet=0.1)
    return m.finish(loudness_db=-35.0, fade_out=0.05)


def basic_let(v=0):
    """Let lobs one burning rock (a meteor, 1.55x the radius, slow): a heavy
    whoosh of displaced air, the grit of it leaving the hand, embers
    crackling off its tail."""
    m = Mix(0.32, seed=5210 + v)
    rng = m.rng
    swish(m, 0.0, 0.26, lambda u: 320 + 420 * np.sin(math.pi * u ** 0.6), 0.5,
          lambda u: np.sin(math.pi * u ** 0.45) ** 2, 0.16)
    burst(m, 0.0, 350, 1800, attack=0.004, tau=0.018, amp=0.06)
    n = 7 + v
    embers = [(0.025 + 0.25 * (k / n) ** 1.3 + rng.uniform(0, 0.015),
               rng.uniform(0.05, 0.13) * (1 - 0.6 * k / n),
               rng.uniform(-0.35, 0.35)) for k in range(n)]
    # Embers: very dry pops, a fire's crackle rather than a stone's ring.
    chips(m, embers, 1400, 4800, eta=0.2, n=2, tc=0.00025, cap=0.006)
    m.room(t60=0.35, wet=0.1)
    return m.finish(loudness_db=-35.0, fade_out=0.06)


def basic_pip(v=0):
    """Pip flicks three darts in a fan (-0.12, 0, +0.12 rad): three tiny hard
    flicks in quick succession, left to right."""
    m = Mix(0.14, seed=5220 + v)
    rng = m.rng
    order = (-0.3, 0.0, 0.3) if v % 2 == 0 else (0.3, 0.0, -0.3)
    at = 0.0
    for k, pan in enumerate(order):
        # A hard little seed of a dart: dry, no ring to it.
        chips(m, [(at, 0.4, pan)], 2200, 4000, eta=0.1, n=3, tc=0.00025,
              cap=0.01)
        swish(m, at + 0.002, 0.03, lambda u: 2600 + 2400 * u, 0.3, _edge,
              0.02, pan)
        at += rng.uniform(0.017, 0.026)
    m.room(t60=0.25, wet=0.08)
    return m.finish(loudness_db=-35.0, fade_out=0.04)


def basic_horn(v=0):
    """Horn shoves one slow heavy shot (1.8x the radius, 0.65 speed): a low
    push of air with a dense, dead body behind it. Weight without a bang."""
    m = Mix(0.3, seed=5230 + v)
    rng = m.rng
    swish(m, 0.0, 0.25, lambda u: 230 + 330 * np.sin(math.pi * u ** 0.5), 0.55,
          lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.35) ** 2, 0.2)
    # A soft contact into many damped low modes: a shoulder into a load,
    # not a struck drum.
    strike(m, 0.004, _solid(rng, (190, 210, 180, 220)[v], n=16,
                            spread=(0.08, 0.3), eta=0.09, cap=0.06, tilt=0.06),
           tc=0.004, amp=0.6)
    burst(m, 0.0, 250, 1300, attack=0.006, tau=0.03, amp=0.05)
    m.room(t60=0.3, wet=0.1)
    return m.finish(loudness_db=-35.0, fade_out=0.06)


def basic_mask(v=0):
    """Mask blows one piercing dart (fast, thin): a short puff behind it, a
    dry click, and a thin zip that goes straight through."""
    m = Mix(0.15, seed=5240 + v)
    burst(m, 0.0, 450, 2200, attack=0.003, tau=0.01, amp=0.045)
    chips(m, [(0.001, 0.12, 0.0)], 1500, 2400, eta=0.09, n=3, tc=0.0003,
          cap=0.012)
    swish(m, 0.006, 0.08, lambda u: 5600 - 2200 * u, 0.16,
          lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.3) ** 2, 0.1,
          pan=(0.1, -0.1, 0.15, -0.05)[v])
    m.room(t60=0.25, wet=0.08)
    return m.finish(loudness_db=-35.0, fade_out=0.04)


def basic_wing(v=0):
    """Wing beats once and two light shots leave it: a feathered flap of air
    -- noise ruffled by the vanes -- then two quick high flicks."""
    m = Mix(0.2, seed=5250 + v)
    rng = m.rng
    n = round(0.11 * SR)
    t = np.arange(n) / SR
    env = np.where(t < 0.014, (t / 0.014) ** 2, np.exp(-(t - 0.014) / 0.028))
    # The vanes: a fast irregular ruffle on the air (60-90 per second).
    ruffle = 1 + 0.55 * signal.sosfilt(
        signal.butter(2, [55, 95], btype='bandpass', fs=SR, output='sos'),
        rng.normal(0, 1, n)) * 6
    sos = signal.butter(2, [250, 1800], btype='bandpass', fs=SR, output='sos')
    flap = signal.sosfilt(sos, rng.normal(0, 1, n)) * env * np.clip(ruffle, 0, 2)
    _put(m, 0.0, 0.1 * flap)
    # The two shots leaving it: small, high, quick, one each side.
    for at, pan in ((0.045, -0.25), (0.068, 0.25)):
        swish(m, at + rng.uniform(-0.004, 0.004), 0.03,
              lambda u: 3400 + 2200 * u, 0.25,
              lambda u: np.sin(math.pi * np.clip(u, 0, 1) ** 0.7) ** 2, 0.06, pan)
    m.room(t60=0.3, wet=0.1)
    return m.finish(loudness_db=-35.0, fade_out=0.05)


def basic_kin(v=0):
    """A kin's charged line let go (KinLaser.beamLife 0.28 s): pressure
    released, then the line itself -- a narrow searing hiss with a fine
    sizzle on it, dying with the beam -- and a low glass warmth under it."""
    m = Mix(0.36, seed=5260 + v)
    rng = m.rng
    burst(m, 0.0, 220, 1000, attack=0.005, tau=0.03, amp=0.06)
    hi = (3300, 3000, 3600, 3150)[v]
    swish(m, 0.003, 0.3, lambda u: hi - 600 * u, 0.22,
          lambda u: np.where(u < 0.03, (u / 0.03) ** 2, np.exp(-(u - 0.03) / 0.3)),
          0.07)
    fizz = [(0.005 + rng.uniform(0, 0.2) ** 1.3, rng.uniform(0.02, 0.06),
             rng.uniform(-0.3, 0.3)) for _ in range(14)]
    chips(m, fizz, 3000, 6500, eta=0.15, n=2, tc=0.0002, cap=0.004)
    m.glass(0.0, (352, 330, 371, 341)[v], amp=0.018, ring=0.2, attack=0.008,
            brightness=0.15, beat=1.5, ratios=[1.0, 2.32, 4.25])
    m.room(t60=0.3, wet=0.1)
    return m.finish(loudness_db=-35.0, fade_out=0.06)


def basic_mystic(v=0):
    """A mystic lets go three small sigils in a fan: three soft hushed
    puffs, each with a breath of glass in it. Softer than a pip's darts."""
    m = Mix(0.2, seed=5270 + v)
    rng = m.rng
    at = 0.0
    for pan in (-0.25, 0.0, 0.25):
        burst(m, at, 500, 2600, attack=0.006, tau=0.02, amp=0.07, pan=pan)
        m.glass(at + 0.003, rng.uniform(540, 660), amp=0.012, ring=0.16,
                attack=0.006, brightness=0.15, pan=pan, beat=2.0,
                ratios=[1.0, 2.32, 4.25])
        at += rng.uniform(0.026, 0.034)
    m.room(t60=0.3, wet=0.1)
    return m.finish(loudness_db=-35.0, fade_out=0.05)


# ===========================================================================
# The end of a fight
# ===========================================================================
#
# Victory: a boss killed in the open cosmos (_handleBossKill -- the kill also
# plays combatHitHeavy and throws 40 pieces), or a dungeon raid cleared (the
# reward popup comes up). Defeat: the ship destroyed in the open cosmos
# (respawn in 2.5 s), "YOU FELL" in a dungeon (1.4 s), or the orb gone and a
# Survival run over (the game pauses and the result panel follows).
#
# Both are about the SPACE rather than a material. Victory opens it: the
# pressure lets go into a vast dark room and the last pieces drift in it.
# Defeat closes it: a dull give, and everything smothered into a small dark
# space. No fanfare, no falling chord, no struck bell as the peak.


def victory():
    m = Mix(3.4, seed=5280)
    rng = m.rng
    # A short lean-in: the last strain before it goes.
    chips(m, _fracture(0.0, 0.09, 12, 0.05, 0.3, -0.4, 0.4),
          900, 3000, eta=0.05, n=3, tc=0.0004, cap=0.03)
    # Something very large giving: not one blow but a mass coming apart,
    # far enough off that it arrives dull, thickest at once and thinning.
    # It swells over the first ~0.2 s rather than landing as one hit.
    far = sorted(0.09 + rng.gamma(2.0, 0.1, 34))
    far = [(t0, rng.uniform(0.3, 0.7) * math.exp(-(t0 - 0.09) / 0.5),
            (1 if k % 2 else -1) * rng.uniform(0.1, 0.85))
           for k, t0 in enumerate(far)]
    chips(m, far, 200, 900, eta=0.05, n=5, tc=0.0018, cap=0.14, lowpass=1800)
    # The pressure of it going out into the room.
    m.air(0.06, 2.2, 140, 1300, amp=0.06, rise=0.12)
    # The last pieces, sparse and further apart, each one long in the room:
    # this is what tells the ear how big the space is.
    drift = [(0.55 + 1.6 * (k / 7) ** 1.3 + rng.uniform(0, 0.08),
              rng.uniform(0.25, 0.4) * (1 - 0.55 * k / 7),
              (1 if k % 2 else -1) * rng.uniform(0.35, 0.9)) for k in range(8)]
    chips(m, drift, 600, 1900, eta=0.035, n=5, tc=0.0006, cap=0.09)
    # Two low bodies, stroked: warmth in the room, never the peak.
    m.glass(0.12, 183, amp=0.04, ring=2.6, attack=0.5, brightness=0.1,
            pan=-0.2, beat=0.6, ratios=[1.0, 2.19, 3.89])
    m.glass(0.2, 263, amp=0.03, ring=2.4, attack=0.6, brightness=0.1,
            pan=0.25, beat=0.5, ratios=[1.0, 2.19, 3.89])
    # The room is the point: big, dark, long.
    m.room(t60=3.2, wet=0.6, darkness=2600)
    return m.finish(loudness_db=-28.0, fade_out=0.8)


def defeat():
    m = Mix(2.0, seed=5290)
    rng = m.rng
    # The give: a dull, heavy crumple, heard as if through the hull.
    chips(m, _fracture(0.0, 0.05, 9, 0.04, 0.18, 0.3, -0.3),
          700, 2400, eta=0.05, n=3, tc=0.0006, cap=0.03, lowpass=2500)
    strike(m, 0.05, _solid(rng, 200, n=18, spread=(0.08, 0.3), eta=0.05,
                           cap=0.2, tilt=0.06), tc=0.005, amp=0.55,
           lowpass=1200)
    # The breath going out, long and falling away.
    m.air(0.03, 1.6, 160, 900, amp=0.09, rise=0.08)
    # Pieces drifting off, duller and further each time: the space closing.
    for k in range(7):
        t0 = 0.12 + 1.1 * (k / 6) ** 1.3 + rng.uniform(0, 0.05)
        chips(m, [(t0, 0.22 * (1 - 0.75 * k / 6),
                   (1 if k % 2 else -1) * rng.uniform(0.2, 0.7))],
              500, 1600, eta=0.05, n=4, tc=0.0008, cap=0.06,
              lowpass=2200 - 1600 * k / 6)
    # A small, dark room: close walls, nothing opening.
    m.room(t60=1.1, wet=0.3, darkness=1400)
    return m.finish(loudness_db=-30.0, fade_out=0.5)


def _v(build, description):
    return {'build': build, 'description': description, 'variants': 3}


CUES = {
    'sfx_combat_projectile': _v(
        projectile, 'A compressed puff through a short barrel and a catch clicking: the ship\'s gun'),
    'sfx_combat_hit_light': _v(
        hit_light, 'A small dense knock on an obsidian body, a flake or two off it'),
    'sfx_combat_hit_heavy': _v(
        hit_heavy, 'A heavy blow on obsidian: a low dense body, a crunch, debris thrown wide'),
    'sfx_combat_enemy_defeat': _v(
        enemy_defeat, 'An obsidian body cracks, breaks and throws its shards outward'),
    'sfx_combat_player_hurt': (
        player_hurt, 'A blow on the hull heard from inside: a muffled plate and a rattle'),
    'sfx_combat_shield_hit': _v(
        shield_hit, 'A knock on the orb\'s thick glass bubble and the air it turns aside'),
    'sfx_combat_shield_break': (
        shield_break, 'A crack runs round the glass bubble, its pressure lets go, pieces fly'),
    'sfx_combat_heal': (
        heal, 'A warm breath drawn in over a low stroked glass'),
    'sfx_combat_danger': (
        danger, 'The orb\'s glass strains -- a creak swelling under pressure -- and a fissure runs across it'),
    'sfx_combat_special_cast': (
        special_cast, 'A latch releasing: a pawl clicks free and a heavy arm stops dead'),
    'sfx_combat_victory': (
        victory, 'Pressure let go into a vast dark room; something huge crumbles far off; pieces drift'),
    'sfx_combat_defeat': (
        defeat, 'A dull heavy give, the breath going out, pieces drifting off into a small dark room'),
}
