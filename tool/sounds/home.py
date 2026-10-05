"""The home biome (lib/screens/home_biome/home_biome_screen.dart): arranging
the field by hand, and what the residents do with the keepsakes and decor
stood in it (lib/games/wilderness/home_life.dart).

It was silent. Each cue is the material of the thing it belongs to -- the
stone a keepsake is set down on, the grains a carried piece of scenery comes
apart into, the glass of a chime, the water of a spring, the reeds of a nest
-- and is scored to what that thing does on screen. Nothing here is a tune.
"""
import math

import numpy as np

from sounds.core import Mix, smooth
from sounds.combat import _solid, burst, chips, creak, strike
from sounds.cosmic import (_dark_glass, _stone, bubbles, grind, knock, roar,
                           rush)


def _flat(v):
    return lambda tt: v + 0 * tt


# ---------------------------------------------------------------------------
# Arranging. Taking hold of something is a hold of the finger (0.3 s) and
# then it is in the hand: a little lift of grit. Putting it down is a press
# onto stone, not a thud. Scenery carried comes apart into grains and sets
# back into its piece where it is let go.
# ---------------------------------------------------------------------------


def take():
    m = Mix(0.5, seed=8000)
    m.grains(lambda tt: 900 * np.exp(-tt / 0.05) * (tt < 0.3), _flat(0.62),
             _flat(0.0), amp=0.5, weight=_flat(0.4))
    knock(m, 0.0, _dark_glass(m.rng, 610, ring=0.25), amp=0.03,
          attack=0.012, tau=0.006, colour=3000, floor=300)
    m.air(0.0, 0.32, 600, 3200, amp=0.02, rise=0.25)
    m.room(t60=0.6, wet=0.16)
    return m.finish(loudness_db=-35.0, fade_out=0.15)


def set_down(v=0):
    m = Mix(0.75, seed=8010 + v)
    # A press onto stone: it leans in, it does not crack.
    knock(m, 0.01, _stone(m.rng, 290 + 25 * v, ring=0.09), amp=0.45,
          attack=0.022, tau=0.012, colour=2600, floor=250)
    # Grit spilling off its foot as it settles.
    m.grains(lambda tt: np.where(tt > 0.02, 1500 * np.exp(-(tt - 0.02) / 0.09), 0),
             _flat(0.38), lambda tt: 0.15 * np.sin(9 * tt), amp=0.5,
             weight=_flat(0.5))
    m.room(t60=0.7, wet=0.18)
    return m.finish(loudness_db=-33.5, fade_out=0.2)


def scenery_gather():
    m = Mix(1.0, seed=8020)
    # The grains in the hand drawn together from either side...
    m.grains(lambda tt: 2200 * smooth(tt, 0.0, 0.3) * (1 - smooth(tt, 0.36, 0.5)),
             lambda tt: 0.55 - 0.2 * smooth(tt, 0, 0.45),
             lambda tt: 0.6 * np.cos(tt * 9) * (1 - smooth(tt, 0, 0.42)),
             amp=0.5, weight=_flat(0.45))
    # ...and setting into the piece: a coarse settle round a soft stone.
    knock(m, 0.4, _stone(m.rng, 270, ring=0.12), amp=0.3, attack=0.04,
          tau=0.016, colour=2200, floor=240)
    m.grains(lambda tt: np.where(tt > 0.4, 1800 * np.exp(-(tt - 0.4) / 0.14), 0),
             _flat(0.3), _flat(0.0), amp=0.5, weight=_flat(0.55))
    m.air(0.0, 0.6, 400, 2600, amp=0.02, rise=0.6)
    m.room(t60=0.9, wet=0.2)
    return m.finish(loudness_db=-32.5, fade_out=0.25)


def appear():
    m = Mix(1.2, seed=8030)
    # Grains gathering in from the sides of the field to where it stands,
    # warming as they close; a stroked glass blooming as it is whole.
    m.grains(lambda tt: 1700 * smooth(tt, 0.0, 0.35) * (1 - smooth(tt, 0.45, 0.62)),
             lambda tt: 0.45 + 0.3 * smooth(tt, 0, 0.55),
             lambda tt: 0.7 * np.sign(np.sin(37 * tt)) * (1 - smooth(tt, 0, 0.55)),
             amp=0.5, weight=_flat(0.45))
    m.glass(0.5, 540, amp=0.05, ring=0.9, attack=0.07, brightness=0.35,
            beat=1.1)
    m.glass(0.52, 811, amp=0.025, ring=0.6, attack=0.08, brightness=0.3)
    m.air(0.05, 0.9, 300, 2200, amp=0.025, rise=0.55)
    m.room(t60=1.1, wet=0.22)
    return m.finish(loudness_db=-32.0, fade_out=0.3)


def dissolve():
    m = Mix(1.0, seed=8040)
    # It comes apart into grains that go off thin and fine to either side.
    m.grains(lambda tt: 1900 * np.exp(-tt / 0.28),
             lambda tt: 0.4 + 0.45 * smooth(tt, 0, 0.6),
             lambda tt: 0.7 * np.sign(np.sin(29 * tt)) * smooth(tt, 0, 0.5),
             amp=0.5, weight=lambda tt: 0.5 - 0.25 * smooth(tt, 0, 0.7))
    m.glass(0.0, 470, amp=0.02, ring=0.5, attack=0.03, brightness=0.3)
    m.air(0.0, 0.7, 500, 3600, amp=0.02, rise=0.15)
    m.room(t60=0.9, wet=0.2)
    return m.finish(loudness_db=-33.5, fade_out=0.3)


def overview_out():
    m = Mix(1.6, seed=8050)
    # The field drawn back into the dark: air opening wide and rising, and
    # the stardust along its edges catching here and there.
    rush(m, 0.0, 1.4, lambda tt: 380 * 2 ** (2.0 * smooth(tt, 0, 1.2)),
         lambda tt: 0.05 * np.sin(math.pi * np.clip(tt / 1.4, 0, 1)) ** 1.5,
         width_oct=0.9, spread=1.0, flutter=0.25)
    m.grains(lambda tt: 220 * smooth(tt, 0.3, 0.9) * (1 - smooth(tt, 1.1, 1.5)),
             _flat(0.95), lambda tt: 0.8 * np.sin(13 * tt), amp=0.5,
             weight=_flat(0.35))
    m.room(t60=1.4, wet=0.25)
    return m.finish(loudness_db=-35.0, fade_out=0.35)


def overview_in():
    m = Mix(1.1, seed=8060)
    rush(m, 0.0, 0.95, lambda tt: 1500 * 2 ** (-1.6 * smooth(tt, 0, 0.9)),
         lambda tt: 0.05 * np.sin(math.pi * np.clip(tt / 0.95, 0, 1)) ** 1.4,
         width_oct=0.9, spread=1.0, flutter=0.2)
    m.room(t60=1.0, wet=0.22)
    return m.finish(loudness_db=-36.0, fade_out=0.3)


def restyle():
    m = Mix(0.6, seed=8070)
    m.glass(0.0, 1320, amp=0.05, ring=0.35, attack=0.004, brightness=0.6,
            beat=2.0)
    m.grains(lambda tt: 700 * np.exp(-tt / 0.08), _flat(0.85), _flat(0.0),
             amp=0.5, weight=_flat(0.35))
    m.room(t60=0.7, wet=0.18)
    return m.finish(loudness_db=-35.5, fade_out=0.2)


# ---------------------------------------------------------------------------
# What the residents do with the keepsakes and decor. Each plays as the
# thing is stirred (home_life.dart: a visitor arrives, hops, sits, goes
# through) and only while it is on screen.
# ---------------------------------------------------------------------------


def flame_catch():
    # A torch's flame drawing up as someone comes to warm themselves at it:
    # the catch, a lift, the crackle settling back.
    m = Mix(1.5, seed=8100)
    roar(m, 0.0, 1.35,
         lambda tt: smooth(tt, 0, 0.09) * (0.55 + 0.45 * np.exp(-tt / 0.35)),
         amp=0.06, body_lo=160, body_hi=1500, rasp=0.5, crackle=32, hiss=0.14)
    burst(m, 0.0, 250, 1400, attack=0.03, tau=0.08, amp=0.05)
    m.room(t60=0.9, wet=0.2)
    return m.finish(loudness_db=-31.5, fade_out=0.35)


def portal(v=0):
    # Drawn into the dark: the air pulled in after it, a deep glass in the
    # frame answering, grains spiralling down to nothing.
    m = Mix(1.3, seed=8110 + v)
    rush(m, 0.0, 1.0, lambda tt: 2600 * 2 ** (-3.0 * smooth(tt, 0, 0.9)),
         lambda tt: 0.07 * smooth(tt, 0, 0.12) * (1 - smooth(tt, 0.6, 1.0)),
         width_oct=0.7, spread=0.5, flutter=0.3)
    knock(m, 0.12, _dark_glass(m.rng, 170 + 20 * v, ring=0.9), amp=0.05,
          attack=0.07, tau=0.02, colour=1600, floor=160)
    m.grains(lambda tt: 1500 * (1 - smooth(tt, 0.1, 0.8)),
             lambda tt: 0.7 - 0.4 * smooth(tt, 0, 0.8),
             lambda tt: 0.6 * np.sin(2 * math.pi * 2.2 * tt) * (1 - smooth(tt, 0, 0.8)),
             amp=0.5, weight=_flat(0.4))
    m.room(t60=1.3, wet=0.26)
    return m.finish(loudness_db=-31.5, fade_out=0.3)


# Glass tubes hung free: a free-free bar's modes, never a harmonic series.
_TUBE = np.array([1.0, 2.756, 5.404, 8.933])


def chimes(v=0):
    # Rods swinging into each other in a breeze, then a resident's touch:
    # a few irregular knocks, each rod its own pitch from no scale, each a
    # glass tube's ring -- its overtones a free bar's, each mode a beating
    # pair, so it shimmers rather than sounding a note.
    m = Mix(3.0, seed=8120 + v)
    rng = m.rng
    rods = np.array([1210, 1433, 1702, 1955, 2290]) * rng.uniform(0.96, 1.04, 5)
    t0 = 0.0
    hits = []
    while t0 < 1.7:
        hits.append(t0)
        t0 += rng.uniform(0.09, 0.3) * (1 + 0.8 * t0)
    for k, at in enumerate(hits):
        r = int(rng.integers(0, 5))
        m.glass(at, rods[r], amp=0.05 * rng.uniform(0.75, 1.0) * (1 - 0.3 * k / len(hits)),
                ring=1.5, attack=0.0015, brightness=0.8, pan=(r - 2) * 0.3,
                beat=2.2, ratios=list(_TUBE))
        # The tap itself: two glass edges meeting.
        m.grains(lambda tt, at=at: np.where((tt > at) & (tt < at + 0.01), 2500, 0),
                 _flat(0.95), _flat((r - 2) * 0.3), amp=0.5, weight=_flat(0.3))
    m.air(0.0, 1.8, 500, 2600, amp=0.01, rise=0.3)
    m.room(t60=1.4, wet=0.24)
    return m.finish(loudness_db=-31.5, fade_out=0.6)


def water():
    # A resident drinking at the fountain: the water's arc falling back into
    # the basin, a few lapping bubbles.
    m = Mix(1.4, seed=8130)
    rush(m, 0.0, 1.2, _flat(3200),
         lambda tt: 0.022 * smooth(tt, 0, 0.15) * (1 - smooth(tt, 0.9, 1.2)),
         width_oct=0.6, spread=0.7, flutter=0.6)
    bubbles(m, 0.05, 1.1, lambda tt: 26 * (1 - smooth(tt, 0.6, 1.1)),
            _flat(0.35), amp=0.06, spread=0.4)
    m.room(t60=0.8, wet=0.2)
    return m.finish(loudness_db=-33.0, fade_out=0.3)


def splash():
    # Slipping into the hot spring: the water parting, a soft plunge, the
    # bubbles coming up after and the surface settling.
    m = Mix(1.8, seed=8140)
    burst(m, 0.0, 300, 2400, attack=0.02, tau=0.11, amp=0.08)
    rush(m, 0.0, 0.6, lambda tt: 1800 - 900 * smooth(tt, 0, 0.5),
         lambda tt: 0.05 * np.exp(-tt / 0.18), width_oct=0.8, spread=0.6,
         flutter=0.5)
    bubbles(m, 0.06, 1.5, lambda tt: 70 * np.exp(-tt / 0.4),
            lambda tt: 0.65 - 0.3 * smooth(tt, 0, 1.2), amp=0.07, spread=0.5)
    m.room(t60=1.0, wet=0.22)
    return m.finish(loudness_db=-31.0, fade_out=0.4)


def swing_creak():
    # The swing taking weight: the seat knocks, then the ropes and the beam
    # creak through two slow swings.
    m = Mix(2.8, seed=8150)
    wood = _solid(m.rng, 420, n=12, eta=0.02, cap=0.09, tilt=0.12)
    strike(m, 0.0, _solid(m.rng, 290, n=12, eta=0.04, cap=0.08), tc=0.002,
           amp=0.25)
    for start in (0.15, 1.35):
        creak_voice(m, start, 1.0, wood)
    m.room(t60=0.9, wet=0.2)
    return m.finish(loudness_db=-32.5, fade_out=0.4)


def creak_voice(m, start, length, wood):
    creak(m, start, length,
          lambda u: 16 + 52 * math.sin(math.pi * u),
          0.35, wood, amp=0.8,
          env=lambda u: math.sin(math.pi * u) ** 1.5 * 0.6)


def step_boards(v=0):
    # A hop landing on the stage: a light footfall on stone, a little grit.
    m = Mix(0.45, seed=8160 + v)
    strike(m, 0.0, _solid(m.rng, 330 + 30 * v, n=14, eta=0.06, cap=0.06),
           tc=0.0035, amp=0.4)
    m.grains(lambda tt: 900 * np.exp(-tt / 0.05), _flat(0.4), _flat(0.0),
             amp=0.5, weight=_flat(0.35))
    m.room(t60=0.6, wet=0.16)
    return m.finish(loudness_db=-35.0, fade_out=0.15)


def reeds():
    # Settling into the nest (or the Elder Tree's branches): dry reeds and
    # leaves giving under it, a few fibres springing back.
    m = Mix(1.3, seed=8170)
    rng = m.rng
    events = []
    t0 = 0.0
    while t0 < 0.95:
        u = t0 / 0.95
        events.append((t0, 0.08 * math.sin(math.pi * u) ** 0.8 * rng.uniform(0.3, 1),
                       rng.uniform(-0.5, 0.5)))
        t0 += rng.uniform(0.004, 0.02)
    chips(m, events, 1800, 6000, eta=0.08, n=3, tc=0.0004, cap=0.02)
    m.air(0.0, 1.0, 1500, 6000, amp=0.012, rise=0.3)
    m.room(t60=0.6, wet=0.16)
    return m.finish(loudness_db=-34.0, fade_out=0.3)


def perch():
    # A flyer landing on a perch: its last wingbeats, the grip on the wood.
    m = Mix(1.1, seed=8180)
    for k, at in enumerate((0.0, 0.17, 0.32)):
        burst(m, at, 220, 1500, attack=0.035, tau=0.05, amp=0.07 * (1 - 0.25 * k),
              pan=0.2 * (k - 1))
    strike(m, 0.42, _solid(m.rng, 480, n=10, eta=0.035, cap=0.05), tc=0.0025,
           amp=0.2)
    events = [(0.43 + 0.012 * i, 0.03 * (1 - i / 10), 0.0) for i in range(10)]
    chips(m, events, 2400, 5200, eta=0.08, n=3, cap=0.015)
    m.room(t60=0.7, wet=0.18)
    return m.finish(loudness_db=-32.5, fade_out=0.25)


def glass_stir(v=0):
    # A glass keepsake stirred by a visitor: a slow stroked bloom, a second
    # glass under it, the light in it moving as a few fine grains.
    m = Mix(1.8, seed=8190 + v)
    f0 = [430, 560, 690][v % 3] * m.rng.uniform(0.97, 1.03)
    m.glass(0.0, f0, amp=0.06, ring=1.3, attack=0.14, brightness=0.4, beat=0.9)
    m.glass(0.05, f0 * 1.43, amp=0.025, ring=0.8, attack=0.16, brightness=0.3)
    m.grains(lambda tt: 260 * smooth(tt, 0.05, 0.3) * (1 - smooth(tt, 0.7, 1.3)),
             _flat(0.9), lambda tt: 0.4 * np.sin(5 * tt), amp=0.5,
             weight=_flat(0.3))
    m.air(0.0, 1.3, 400, 2800, amp=0.015, rise=0.35)
    m.room(t60=1.4, wet=0.25)
    return m.finish(loudness_db=-33.0, fade_out=0.45)


def stone_stir(v=0):
    # A stone keepsake (the Palm, a headstone, an effigy's plinth) giving a
    # little under a visitor: a low grind of stone on stone, dust settling.
    m = Mix(1.5, seed=8200 + v)
    grind(m, 0.0, 0.8, lambda tt: np.sin(math.pi * np.clip(tt / 0.8, 0, 1)) ** 1.5 * 0.7,
          _stone(m.rng, 220 + 30 * v, ring=0.15), amp=0.3, rate=(8, 40),
          jitter=0.4, colour=2600, floor=220)
    m.grains(lambda tt: 600 * smooth(tt, 0.2, 0.6) * (1 - smooth(tt, 0.8, 1.3)),
             _flat(0.3), _flat(0.0), amp=0.5, weight=_flat(0.45))
    m.room(t60=1.0, wet=0.22)
    return m.finish(loudness_db=-33.5, fade_out=0.35)


def spark():
    # The fulgurite's spark running through its glass: a dry electric
    # crackle, thinning out.
    m = Mix(1.0, seed=8210)
    rng = m.rng
    events = []
    t0 = 0.0
    while t0 < 0.6:
        events.append((t0, 0.05 * math.exp(-t0 / 0.25) * rng.uniform(0.3, 1),
                       rng.uniform(-0.4, 0.4)))
        t0 += rng.exponential(0.012)
    chips(m, events, 3000, 9000, eta=0.02, n=3, tc=0.0002, cap=0.008)
    m.air(0.0, 0.5, 3500, 9000, amp=0.012, rise=0.1)
    m.glass(0.0, 1900, amp=0.015, ring=0.4, attack=0.003, brightness=0.7)
    m.room(t60=0.8, wet=0.2)
    return m.finish(loudness_db=-33.0, fade_out=0.3)


def steam_breath():
    # Steam breathing through the harmony pipes: a long exhale through a
    # bore, breathy, the band of it no narrower than a voice's.
    m = Mix(2.0, seed=8220)
    env = lambda tt: smooth(tt, 0, 0.35) * (1 - smooth(tt, 1.1, 1.7))
    rush(m, 0.0, 1.8, lambda tt: 820 + 120 * np.sin(2.3 * tt),
         lambda tt: 0.05 * env(tt), width_oct=0.45, spread=0.5, flutter=0.3)
    rush(m, 0.0, 1.8, _flat(3600), lambda tt: 0.025 * env(tt), width_oct=0.9,
         spread=0.8, flutter=0.5)
    m.room(t60=1.1, wet=0.22)
    return m.finish(loudness_db=-33.0, fade_out=0.4)


def heartbeat():
    # The garnet heart's two strokes: a heavy glass pressed, not struck --
    # a throb with no pitch falling through it (never a kick).
    m = Mix(1.4, seed=8230)
    for at, amp in ((0.04, 0.6), (0.32, 0.38)):
        knock(m, at, _dark_glass(m.rng, 262, ring=0.45), amp=amp,
              attack=0.035, tau=0.022, colour=2400, floor=250)
        burst(m, at, 200, 900, attack=0.03, tau=0.05, amp=0.03)
    m.room(t60=0.9, wet=0.2)
    return m.finish(loudness_db=-32.0, fade_out=0.35)


def mushroom():
    # A cap lit as a resident lands on it: a soft puff of spores, rising
    # fine.
    m = Mix(1.0, seed=8240)
    burst(m, 0.0, 500, 3600, attack=0.015, tau=0.07, amp=0.06)
    m.grains(lambda tt: 900 * np.exp(-tt / 0.18) * smooth(tt, 0, 0.03),
             _flat(0.92), lambda tt: 0.3 * np.sin(7 * tt), amp=0.5,
             weight=_flat(0.3))
    m.glass(0.02, 880, amp=0.015, ring=0.45, attack=0.03, brightness=0.3)
    m.room(t60=0.8, wet=0.2)
    return m.finish(loudness_db=-35.0, fade_out=0.3)


def orrery():
    # The orrery's ring turning with its rider: glass running on its
    # bearings, a slow even roll, the worlds on it ticking past.
    m = Mix(2.4, seed=8250)
    grind(m, 0.0, 2.1, lambda tt: 0.5 * smooth(tt, 0, 0.4) * (1 - smooth(tt, 1.6, 2.1)),
          _dark_glass(m.rng, 410, ring=0.3), amp=0.25, rate=(30, 90),
          jitter=0.35, colour=3600, floor=260)
    for at in (0.55, 1.2, 1.8):
        m.glass(at, 1240 * m.rng.uniform(0.95, 1.05), amp=0.015, ring=0.5,
                attack=0.01, brightness=0.5)
    m.room(t60=1.2, wet=0.24)
    return m.finish(loudness_db=-34.0, fade_out=0.4)


def _v(build, description, n=3):
    return {'build': build, 'description': description, 'variants': n}


CUES = {
    'sfx_home_take': (take, 'Home biome: a piece taken hold of (after the hold), lifted with a little grit'),
    'sfx_home_set': _v(set_down, 'Home biome: something set down on its ground, a press onto stone with grit'),
    'sfx_home_scenery_gather': (scenery_gather, 'Home biome: carried scenery, grains in the hand, setting back into its piece'),
    'sfx_home_appear': (appear, 'Home biome: a new piece gathering out of grains where it stands, a stroked glass as it is whole'),
    'sfx_home_dissolve': (dissolve, 'Home biome: a piece put away, coming apart into grains that go off thin'),
    'sfx_home_overview_out': (overview_out, 'Home biome: zooming out, the field drawn back into the dark, stardust on its edges'),
    'sfx_home_overview_in': (overview_in, 'Home biome: zooming back in'),
    'sfx_home_restyle': (restyle, 'Home biome: a piece of decor given its next look'),
    'sfx_home_flame': (flame_catch, 'Home biome: a torch flame drawing up for a visitor'),
    'sfx_home_portal': _v(portal, 'Home biome: a resident drawn into one of the Black Sun portals'),
    'sfx_home_chimes': _v(chimes, 'Home biome: glass chime rods knocking in a breeze and at a touch'),
    'sfx_home_water': (water, 'Home biome: a resident drinking at the grain fountain'),
    'sfx_home_splash': (splash, 'Home biome: slipping into the hot spring'),
    'sfx_home_creak': (swing_creak, 'Home biome: the swing taking a rider, ropes and beam creaking'),
    'sfx_home_step': _v(step_boards, 'Home biome: a hop landing on the stage'),
    'sfx_home_reeds': (reeds, 'Home biome: settling into a rest nest or the elder tree'),
    'sfx_home_perch': (perch, 'Home biome: a flyer landing on a perch'),
    'sfx_home_glass': _v(glass_stir, 'Home biome: a glass keepsake stirred by a visitor'),
    'sfx_home_stone': _v(stone_stir, 'Home biome: a stone keepsake giving a little under a visitor'),
    'sfx_home_spark': (spark, 'Home biome: the fulgurite spark crackling through its glass'),
    'sfx_home_steam': (steam_breath, 'Home biome: steam breathing through the harmony pipes'),
    'sfx_home_heart': (heartbeat, 'Home biome: the garnet heart beating, pressed glass'),
    'sfx_home_spores': (mushroom, 'Home biome: a glow mushroom cap lit, a puff of spores'),
    'sfx_home_orrery': (orrery, 'Home biome: the grand orrery turning with its rider'),
}
