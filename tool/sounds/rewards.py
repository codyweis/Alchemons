"""Rewards: money in and out, a skill or chamber set in place, a journal
reward sealed, an Enhance taken in -- and the material voices those are made
of (metal, wood, stone, paper and wax, fire), which tool/sounds/interface.py
borrows for the altar, the lab and the two small UI cues."""
import math

import numpy as np
from scipy import signal

from sounds.core import SR, Mix, smooth

# ===========================================================================
# Voices
# ===========================================================================
#
# Every struck thing here is MODAL: a contact pulse (its width is how hard
# the two things are -- a coin on a coin is a fraction of a millisecond, a
# wax seal several) rung through the body's own modes, each a decaying
# resonator. The modes are the body's, never a harmonic series, and the
# metal ones come in close split pairs (no real coin is perfectly round), so
# nothing reads as a note.

# A thin free disc: (2,0) (0,1) (3,0) (1,1) (4,0) (5,0) (2,1) (0,2).
COIN = [1.0, 1.73, 2.33, 3.91, 4.11, 6.30, 6.71, 7.34]
# A small brass part: a latch bolt, a clasp's leaf.
BRASS = [1.0, 1.58, 2.71, 3.92, 5.2]
# A plank or a counter top: few, low, quickly gone.
WOOD = [1.0, 1.58, 2.41, 3.29, 4.62, 5.9]
# A hand-sized stone: obsidian is glassy, so a little longer than granite.
STONE = [1.0, 1.47, 2.09, 2.56, 3.18, 3.91, 4.7]


def _resonate(x, freqs, t60s, gains):
    """[x] rung through decaying modes (two-pole resonators, unit impulse
    response amplitude, so [gains] are the modes' own loudness)."""
    out = np.zeros_like(x)
    for f, t60, g in zip(freqs, t60s, gains):
        if f >= SR * 0.45 or g == 0:
            continue
        r = math.exp(-6.9 / (t60 * SR))
        w = 2 * math.pi * f / SR
        out += g * signal.lfilter([math.sin(w)], [1, -2 * r * math.cos(w), r * r], x)
    return out


def _pulse(width):
    """A contact: a raised-cosine of [width] seconds with unit area, so its
    spectrum falls away above ~1/width -- a harder contact is brighter."""
    n = max(3, round(width * SR))
    p = np.hanning(n + 2)[1:-1]
    return p / p.sum()


def _place(m, at, mono, pan=0.0, spread=0.0):
    """Adds [mono] at [at] seconds, panned; [spread] decorrelates the two
    sides a little (a few samples' delay), so a body has width."""
    s0 = max(0, round(at * SR))
    if s0 >= m.n:
        return
    mono = mono[: m.n - s0]
    gl = math.cos((pan + 1) * math.pi / 4)
    gr = math.sin((pan + 1) * math.pi / 4)
    d = round(abs(spread) * 0.0006 * SR)
    m.y[0, s0:s0 + len(mono)] += gl * mono
    if d and s0 + d < m.n:
        m.y[1, s0 + d:s0 + len(mono)] += gr * mono[: len(mono) - d]
    else:
        m.y[1, s0:s0 + len(mono)] += gr * mono


def strike(m, at, f0, ratios, ring, amp=1.0, contact=0.0004, pan=0.0,
           split=0.0, tilt=0.6, click=0.0, spread=0.3, lean=0.0):
    """One body struck once.

    f0, ratios  its modes
    ring        the lowest mode's T60; higher modes die faster
    contact     the contact's width (s): hardness
    split       relative split of each mode into a beating pair (metal)
    tilt        how fast the upper modes fall away in loudness
    click       a little of the contact itself, heard as the touch
    lean        seconds over which the body comes up: a thing SET down
                rolls onto its contact rather than hitting it, and its
                first instant is not a spike
    """
    rng = m.rng
    length = ring * 1.3 + 0.02
    n = round(length * SR)
    x = np.zeros(n)
    p = _pulse(contact)
    x[: len(p)] += p
    freqs, t60s, gains = [], [], []
    for k, r in enumerate(ratios):
        # Where it is struck decides which modes speak: each strike its own.
        g = math.exp(-tilt * k) * rng.lognormal(0, 0.35)
        f = f0 * r * (1 + rng.normal(0, 0.004))
        t = ring / (1 + 0.55 * k) * rng.uniform(0.85, 1.15)
        if split > 0:
            d = split * rng.uniform(0.4, 1.0)
            freqs += [f * (1 - d / 2), f * (1 + d / 2)]
            t60s += [t, t * 0.9]
            gains += [g * 0.6, g * 0.45]
        else:
            freqs.append(f)
            t60s.append(t)
            gains.append(g)
    y = _resonate(x * 0.02, freqs, t60s, gains)
    if click > 0:
        hp = signal.butter(2, 1800, btype='highpass', fs=SR, output='sos')
        tick = np.zeros(n)
        tick[: len(p)] = rng.normal(0, 1, len(p)) * np.hanning(len(p))
        y += click * 0.004 * signal.sosfilt(hp, tick)
    if lean > 0:
        y *= smooth(np.arange(n) / SR, 0, lean) ** 0.7
    y *= amp
    _place(m, at, y, pan, spread)
    return m


def coin(m, at, size=1.0, amp=1.0, damp=1.0, pan=0.0, lean=0.0006):
    """A coin touching another coin or a pile: a bright, hard contact and a
    short split ring. [size] > 1 is a heavier coin (lower), [damp] < 1 a
    coin lying on others (its ring cut short)."""
    f0 = m.rng.uniform(2500, 3700) / size
    return strike(m, at, f0, COIN, ring=0.32 * damp, amp=amp, contact=0.00018,
                  pan=pan, split=0.006, tilt=0.32, click=0.6, lean=lean)


def wood(m, at, f0=210, amp=1.0, ring=0.09, contact=0.0012, pan=0.0,
         lean=0.003):
    """Something set down on a wooden counter: a dull, quickly gone body."""
    strike(m, at, f0, WOOD, ring=ring, amp=4 * amp, contact=contact, pan=pan,
           tilt=0.45, spread=0.5, lean=lean)
    # The grain of the wood: a breath of fibre at the touch.
    fibre(m, at, 0.025, 900, 4200, amp * 0.25, pan)
    return m


def stone(m, at, f0=1100, amp=1.0, ring=0.07, contact=0.0003, pan=0.0,
          body=0.0, body_f=170, lean=0.003):
    """Stone on stone: a hard short contact, glassy if obsidian. [body] adds
    the slab it sits in (short, low, never a pitch that falls)."""
    strike(m, at, f0, STONE, ring=ring, amp=2 * amp, contact=contact, pan=pan,
           tilt=0.35, click=0.25, spread=0.4, lean=lean)
    if body > 0:
        strike(m, at, body_f, [1.0, 1.61, 2.27, 2.9], ring=0.07, amp=body,
               contact=0.002, pan=pan, tilt=0.7, spread=0.6, lean=lean)
    return m


def fibre(m, at, length, low, high, amp, pan=0.0):
    """A burst of band-limited noise with a quick lean in: a touch's
    texture rather than its ring."""
    n = round(length * SR)
    if n < 8:
        return m
    t = np.arange(n) / SR
    env = np.clip(t / min(0.004, length / 3), 0, 1) * np.exp(-t / (length / 3))
    sos = signal.butter(2, [low, high], btype='bandpass', fs=SR, output='sos')
    _place(m, at, amp * 0.05 * env * signal.sosfilt(sos, m.rng.normal(0, 1, n)), pan, 0.5)
    return m


def brass(m, at, f0=3000, amp=1.0, ring=0.05, contact=0.00015, pan=0.0,
          lean=0.0012):
    """A small brass part snapping home: a latch bolt, a clasp's leaf."""
    return strike(m, at, f0, BRASS, ring=ring, amp=2.5 * amp, contact=contact,
                  pan=pan, split=0.004, tilt=0.38, click=0.6, lean=lean)


def friction(m, start, length, rate, f0, ratios, ring, amp=1.0,
             contact=0.0004, pan=0.0, tilt=0.4, rub=0.0, rub_band=(400, 2400)):
    """Two surfaces dragged: stick-slip. Each slip is a little contact,
    rung through the body's modes; [rate](t) is slips per second at each
    moment of the drag (0..length). [rub] adds the continuous noise of the
    surfaces under it."""
    n = round(length * SR)
    t = np.arange(n) / SR
    r = np.maximum(rate(t), 0) / SR
    hits = m.rng.poisson(r).astype(float)
    hits *= np.minimum(m.rng.lognormal(-0.3, 0.6, n), 3)
    x = np.convolve(hits, _pulse(contact))[:n]
    freqs = [f0 * k for k in ratios]
    t60s = [ring / (1 + 0.55 * k) for k in range(len(ratios))]
    gains = [math.exp(-tilt * k) for k in range(len(ratios))]
    y = _resonate(x * 0.02, freqs, t60s, gains)
    if rub > 0:
        sos = signal.butter(2, list(rub_band), btype='bandpass', fs=SR, output='sos')
        y += rub * 0.02 * signal.sosfilt(sos, m.rng.normal(0, 1, n)) * np.sqrt(r * SR / max(1, np.max(r * SR)))
    edge = np.clip(np.minimum(t, length - t) / 0.01, 0, 1)
    _place(m, start, 0.3 * amp * y * edge, pan, 0.4)
    return m


def crackle(m, start, length, rate, amp=1.0, low=1500, high=7000, pan=0.0,
            width=0.4, size=1.0, tick=0.0003):
    """Sparse sharp ticks with a long tail of sizes: paper, embers, a wax
    seal pulling free. [rate](t) per second, t from 0..length. Each tick is
    a tiny decaying burst ([tick] s), not a single sample: a real crackle
    has a body, however small, and a bare impulse is a spike."""
    n = round(length * SR)
    t = np.arange(n) / SR
    hits = m.rng.poisson(np.maximum(rate(t), 0) / SR).astype(float)
    idx = np.nonzero(hits)[0]
    if not len(idx):
        return m
    # Pareto sizes, capped: mostly faint, now and then one you notice.
    sizes = hits[idx] * np.minimum(m.rng.pareto(2.6, len(idx)) + 0.3, 2.5) * size
    # Each tick lands a little to one side or the other.
    lean = np.clip(pan + width * m.rng.normal(0, 1, len(idx)), -1, 1)
    gains = (np.cos((lean + 1) * math.pi / 4), np.sin((lean + 1) * math.pi / 4))
    kl = round(tick * 6 * SR)
    kt = np.arange(kl) / SR
    kinds = m.rng.integers(0, 3, len(idx))
    kernels = []
    for _ in range(3):
        k = m.rng.normal(0, 1, kl) * np.exp(-kt / tick)
        kernels.append(k / np.sqrt(np.sum(k ** 2)))
    sos = signal.butter(2, [low, high], btype='bandpass', fs=SR, output='sos')
    s0 = round(start * SR)
    e = min(m.n, s0 + n)
    for ch in range(2):
        y = np.zeros(n)
        for j, k in enumerate(kernels):
            sel = kinds == j
            x = np.zeros(n)
            x[idx[sel]] = sizes[sel] * gains[ch][sel]
            y += np.convolve(x, k)[:n]
        y = signal.sosfilt(sos, y) * amp * 0.16
        m.y[ch, s0:e] += y[: e - s0]
    return m


def flare(m, at, length, amp=1.0, low=220, high=1700, rise=0.05,
          flicker=0.5, crackles=0.0, pan=0.0):
    """A flame catching: a soft swell of turbulent air (it leans in over
    [rise]; a fire never starts with a bang), flickering, with a few
    crackles in it. No tone."""
    n = round(length * SR)
    t = np.arange(n) / SR
    env = smooth(t, 0, rise) * np.exp(-np.maximum(t - rise, 0) / (length / 3.2))
    # Flicker: the flame's own unsteady breath, a slow random wobble.
    lp = signal.butter(2, 9, btype='lowpass', fs=SR, output='sos')
    wob = signal.sosfilt(lp, m.rng.normal(0, 1, n))
    wob /= max(np.max(np.abs(wob)), 1e-9)
    env = env * (1 + flicker * wob)
    sos = signal.butter(2, [low, high], btype='bandpass', fs=SR, output='sos')
    for ch in range(2):
        g = math.cos((pan + 1) * math.pi / 4) if ch == 0 else math.sin((pan + 1) * math.pi / 4)
        y = amp * 0.035 * g * env * signal.sosfilt(sos, m.rng.normal(0, 1, n))
        s0 = round(at * SR)
        e = min(m.n, s0 + n)
        m.y[ch, s0:e] += y[: e - s0]
    if crackles > 0:
        crackle(m, at + rise * 0.5, length * 0.8,
                lambda tt: crackles * np.exp(-tt / (length * 0.3)),
                amp=amp * 0.9, low=1400, high=6000, pan=pan, width=0.3)
    return m


# ===========================================================================
# Money -- the black market, the specimen exchange, gold conversion, the
# cosmic sell sheet (currencyGain); shop and market purchases and slot
# unlocks (purchaseSuccess)
# ===========================================================================
#
# Every one of these fires on the confirm, after its save, with only a toast
# to look at -- so they are short, and they are the money itself: coins.
# What changes between them is which way the money goes.


def currency_gain():
    """Coins in: a small handful dropped on a pile. The first lands as a
    little cluster, a couple slide off it, and the last one rocks to rest
    (its touches coming quicker as it settles)."""
    m = Mix(0.62, seed=4801)
    rng = m.rng
    # The handful: five coins in ~70 ms, each landing on others.
    for k in range(5):
        at = 0.012 + 0.07 * (k / 4) ** 1.4 + rng.uniform(0, 0.008)
        coin(m, at, size=rng.uniform(0.9, 1.15), amp=0.85 - 0.08 * k,
             damp=0.55, pan=rng.uniform(-0.35, 0.35))
    # Two slide off the top a moment later.
    coin(m, 0.135, amp=0.42, damp=0.5, pan=0.3)
    coin(m, 0.19, amp=0.3, damp=0.5, pan=-0.25)
    # The last one rocking to rest: touches closer and softer each time.
    gap, at, a = 0.06, 0.24, 0.32
    while gap > 0.012 and at < 0.45:
        coin(m, at, size=1.05, amp=a, damp=0.4, pan=0.12)
        at += gap
        gap *= 0.68
        a *= 0.78
    # The pile under them: a dull give, no ring.
    fibre(m, 0.014, 0.05, 500, 2400, 0.25)
    m.room(t60=0.5, wet=0.14, darkness=5200)
    return m.finish(loudness_db=-33.5, fade_out=0.12)


def purchase_success():
    """Coins out: two set down on a wooden counter (the second onto the
    first), and the purse's brass clasp snapped shut on what is left -- the
    deal is done."""
    m = Mix(0.78, seed=4802)
    # Set down, not dropped: a soft wood touch under a coin's damped ring.
    wood(m, 0.02, f0=330, amp=0.4, ring=0.05, contact=0.0012, pan=-0.2,
         lean=0.005)
    coin(m, 0.022, size=1.1, amp=0.6, damp=0.35, pan=-0.2, lean=0.002)
    # The second coin onto the first.
    coin(m, 0.115, size=1.0, amp=0.7, damp=0.45, pan=-0.12)
    coin(m, 0.128, size=1.1, amp=0.3, damp=0.3, pan=-0.12)
    # The clasp: two leaves kiss past each other and lock -- two brass
    # clicks a breath apart, the second (the lock) the firmer.
    brass(m, 0.31, 4300, amp=0.3, ring=0.03, contact=0.00012, pan=0.25)
    brass(m, 0.336, 3700, amp=0.5, ring=0.045, pan=0.25)
    # The purse it closes on: a little leather give.
    fibre(m, 0.334, 0.06, 350, 1600, 0.5, 0.25)
    m.room(t60=0.45, wet=0.1, darkness=4200)
    return m.finish(loudness_db=-32.0, fade_out=0.15)


# ===========================================================================
# Set in place -- a chamber unlocked, a level reached on Enhance's line, a
# constellation stone with no link (upgradeComplete); a linked stone, which
# the pour runs down to first (constellationAttune)
# ===========================================================================
#
# A constellation stone is obsidian and it ignites (constellation_game.dart:
# the pour down the link takes ConnectionLine.pourDuration = 1.05 s, then
# _ignite: a flash gone by ~0.5 s and a ring of 26 grains thrown out over
# _igniteDuration = 0.9 s). The same "a stone seats, and it is lit" is what
# a chamber opening and a level reached are, so upgradeComplete is that
# ignition with no pour, and Enhance can fire it several times in a count.

POUR = 1.05          # ConnectionLine.pourDuration
IGNITE = 0.9         # ConstellationNode._igniteDuration


def _ignite(m, at, weight=1.0):
    """A stone seats, and catches: a short grind into its socket, a hard
    obsidian touch, and a warm flame catching inside it. The ring of grains
    the stone throws out rides on the flame as a few sparks."""
    # The grind is a lead-in, well under the seat.
    friction(m, at - 0.06, 0.07,
             lambda t: 1600 * smooth(t, 0.0, 0.05) * (1 - smooth(t, 0.055, 0.07)),
             1300, STONE, ring=0.025, amp=0.45 * weight, contact=0.0003, rub=0.3,
             rub_band=(700, 3200))
    stone(m, at, f0=1180, amp=1.3 * weight, ring=0.1, body=0.3 * weight,
          body_f=185)
    # Lit: the flash is gone by ~0.5 s; the flame's breath with it.
    flare(m, at + 0.015, 0.75, amp=0.8 * weight, low=260, high=1900,
          rise=0.06, flicker=0.45)
    # The grains thrown out as sparks, spreading and dimming over the
    # ignition.
    crackle(m, at + 0.03, IGNITE * 0.85,
            lambda t: 70 * np.exp(-t / 0.28), amp=0.35 * weight,
            low=2200, high=7500, width=0.6)


def upgrade_complete():
    """Set in place, and lit: a stone grinds into its socket, seats, and a
    warm flame catches in it."""
    m = Mix(1.0, seed=4803)
    _ignite(m, 0.065)
    m.room(t60=0.8, wet=0.18, darkness=4200)
    return m.finish(loudness_db=-31.0, fade_out=0.25)


def constellation_attune():
    """A linked constellation stone: grains run down the link from the
    parent for 1.05 s, and the stone seats and ignites as they arrive."""
    m = Mix(POUR + 1.0, seed=4804)

    # The pour: the link fills from the parent at a steady run -- it eases
    # in, keeps going, and the last of it lands in the stone.
    def pour(t):
        return 1500 * smooth(t, 0.0, 0.18) * (t < POUR + 0.02)

    m.grains(pour, lambda t: 0.74 - 0.1 * smooth(t, 0.0, POUR),
             lambda t: -0.35 * (1 - smooth(t, 0.0, POUR)), amp=0.5,
             weight=lambda t: 0.3 + 0.12 * smooth(t, 0.0, POUR))
    # Arrived: a quick settle of the stream into the stone.
    m.grains(lambda t: np.where(t > POUR - 0.02, 2600 * np.exp(-(t - POUR + 0.02) / 0.05), 0),
             lambda t: 0.45 + 0 * t, lambda t: 0 * t, amp=0.5,
             weight=lambda t: 0.55 + 0 * t)
    _ignite(m, POUR, weight=1.1)
    m.room(t60=1.0, wet=0.2, darkness=4200)
    return m.finish(loudness_db=-30.0, fade_out=0.3)


# ===========================================================================
# Sealed -- an achievement or onboarding task claimed in the journal
# (achievementUnlock)
# ===========================================================================
#
# The claimed row reads SEALED (campaign_journal_screen.dart), and the reward
# flight leaves it at the same instant, landing 0.98 s later with a settle of
# its own (sfx_reward_flight). So this is the seal: the parchment pressed
# flat, a brass seal set into warm wax on a wooden desk, and lifted off --
# all of its weight in the first 0.35 s and nothing left by 0.9 s.


def achievement_unlock():
    """A seal pressed into wax on parchment, on a wooden desk, and lifted."""
    m = Mix(1.0, seed=4805)
    # The parchment flattened under the hand.
    crackle(m, 0.0, 0.11, lambda t: 1600 * smooth(t, 0, 0.03) * np.exp(-t / 0.05),
            amp=0.28, low=1300, high=6500, width=0.5)
    fibre(m, 0.0, 0.1, 1500, 5500, 0.3)
    # The seal goes down: wax gives first (soft, a few ms), then the desk
    # takes it -- through the paper, so no hard click.
    PRESS = 0.06
    fibre(m, PRESS - 0.008, 0.07, 260, 1300, 1.6)
    # The stamp's wooden handle and the desk under it.
    wood(m, PRESS, f0=410, amp=0.55, ring=0.035, contact=0.0009, lean=0.005)
    fibre(m, PRESS, 0.05, 300, 1500, 1.3)
    brass(m, PRESS + 0.002, 2100, amp=0.25, ring=0.04, contact=0.0004)
    # The wax squeezed out round the brass.
    crackle(m, PRESS + 0.01, 0.14, lambda t: 500 * np.exp(-t / 0.05),
            amp=0.6, low=600, high=2600, width=0.2, tick=0.0008)
    # Lifted: the wax lets go of the seal -- a tacky peel that quickens and
    # stops.
    LIFT = 0.31
    crackle(m, LIFT, 0.09, lambda t: 1400 * smooth(t, 0, 0.07) * (t < 0.08),
            amp=0.3, low=1200, high=5200, width=0.25)
    fibre(m, LIFT + 0.075, 0.03, 500, 2200, 0.3)
    m.room(t60=0.6, wet=0.16, darkness=4600)
    return m.finish(loudness_db=-30.0, fade_out=0.3)


# ===========================================================================
# Taken in -- Enhance: the kin poured in, the specimen lit (rewardCollect)
# ===========================================================================
#
# feeding_screen.dart plays it (at speed 1.08) the moment the kin's pour has
# landed and the flash starts (InfusionPainter, 860 ms): a bloom at the heart
# gone in the first 30%, and a wave of gold that climbs the specimen from its
# feet over 55% of the flash, lifting its grains off it like heat, which
# settle back. The picture is grains, so the sound is: the specimen's own,
# lifting and settling, with the warmth of the light under them.

FLASH = 0.86 * 1.08  # in file time, so it plays out over the 860 ms flash


def reward_collect():
    """The kin taken in: a warm breath at the heart, the specimen's grains
    lifting off it as a wave climbs it, and settling back."""
    m = Mix(0.78, seed=4806)
    u = lambda t: t / FLASH  # noqa: E731

    def lift(t):
        # How many grains are mid-lift: the wave's band (38% wide) climbing
        # over the first 55%, then nothing.
        return smooth(u(t), 0.0, 0.2) * (1 - smooth(u(t), 0.6, 0.93))

    # The bloom at the heart: a warm breath, quick -- the loudest moment,
    # and gone by the time the wave is halfway up.
    m.air(0.0, 0.34, 260, 2200, amp=0.07, rise=0.1)
    flare(m, 0.0, 0.42, amp=1.1, low=280, high=2000, rise=0.035, flicker=0.3)
    # Lifting: the band of lifted grains grows as the wave gets onto the
    # body, brightening as it reaches the crown, and is gone at the top.
    m.grains(lambda t: 1500 * lift(t) * (0.5 + 0.5 * smooth(u(t), 0.1, 0.4)),
             lambda t: 0.45 + 0.2 * smooth(u(t), 0.0, 0.55),
             lambda t: 0.25 * np.sin(2 * math.pi * 2.0 * t), amp=0.5,
             weight=lambda t: 0.4 + 0.1 * lift(t))
    # The loose few that come right off glint.
    m.grains(lambda t: 120 * lift(t), lambda t: 0.95 + 0 * t,
             lambda t: 0.5 * np.sin(2 * math.pi * 1.3 * t + 1), amp=0.5,
             weight=lambda t: 0.45 + 0 * t)
    # Settling back together: coarser, softer, and done.
    m.grains(lambda t: 1400 * smooth(u(t), 0.5, 0.62) * np.exp(-np.maximum(u(t) - 0.62, 0) / 0.12),
             lambda t: 0.32 + 0 * t, lambda t: 0 * t, amp=0.5,
             weight=lambda t: 0.45 + 0 * t)
    m.room(t60=0.7, wet=0.16)
    return m.finish(loudness_db=-33.5, fade_out=0.15)


CUES = {
    'sfx_currency_gain': (currency_gain, 'Coins in: a small handful dropped on a pile, the last one rocking to rest'),
    'sfx_purchase_success': (purchase_success, 'Coins out: two set down on a wooden counter, and a brass purse clasp snapped shut'),
    'sfx_upgrade_complete': (upgrade_complete, 'Set in place, and lit: a stone grinds into its socket, seats, and a warm flame catches in it'),
    'sfx_constellation_attune': (constellation_attune, 'Grains run down a constellation link for 1.05 s, and the obsidian stone seats and ignites as they land'),
    'sfx_achievement_unlock': (achievement_unlock, 'Sealed: parchment pressed flat, a brass seal into warm wax on a wooden desk, and lifted; gone before the reward flight lands'),
    'sfx_reward_collect': (reward_collect, 'Enhance taken in: a warm breath at the heart, the specimen\'s grains lifting off it like heat and settling back'),
}
