"""Render the remaining sound brief with deterministic NumPy synthesis.

Run with a Python environment containing NumPy. Existing approved samples are
read, never rewritten. Produces WAV assets, a categorized preview, and manifest.
"""
import base64
import argparse
import hashlib
import html
import json
import math
import re
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/sounds'
REVIEW = ROOT / 'build/audio_review'
SR = 48000
TAU = 2 * math.pi
APPROVED = {
    'sfx_ui_tap', 'sfx_ui_confirm', 'sfx_ui_denied', 'sfx_reward_collect',
    'sfx_cosmic_portal_open', 'sfx_cosmic_orb_pickup',
    'sfx_cosmic_orb_deposit', 'sfx_cosmic_anomaly_burst',
    'sfx_cosmic_starforge_activate', 'sfx_combat_projectile',
}
COSMIC = {n for n in APPROVED if n.startswith('sfx_cosmic_')}


def asset_path(name):
    return OUT / ('cosmic' if name in COSMIC else '') / (name + '.wav')


class Synth:
    def __init__(self, duration, seed):
        self.t = np.arange(round(duration * SR)) / SR
        self.y = np.zeros(len(self.t))
        self.rng = np.random.default_rng(seed)

    def tone(self, f, start=0, decay=.08, amp=1, attack=.002, end=None,
             glide=.03, metal=.15, wobble=0):
        t = np.maximum(0, self.t - start)
        env = (self.t >= start) * (1 - np.exp(-t / attack)) * np.exp(-t / decay)
        end = f if end is None else end
        phase = TAU * (end * t + (f - end) * glide * (1 - np.exp(-t / glide)))
        phase += wobble * np.sin(TAU * 4.3 * t)
        self.y += amp * env * (np.sin(phase)
                             + metal * np.sin(phase * 2.007) * np.exp(-t / (decay * .5)))
        return self

    def noise(self, start=0, decay=.06, amp=.3, low=100, high=5000, attack=.002):
        n = len(self.t)
        freq = np.fft.rfftfreq(n, 1 / SR)
        spectrum = np.fft.rfft(self.rng.normal(size=n))
        band = (1 - np.exp(-(freq / max(low, 1)) ** 4)) * np.exp(-(freq / high) ** 4)
        texture = np.fft.irfft(spectrum * band, n=n)
        texture /= max(np.std(texture) * 3, .00001)
        t = np.maximum(0, self.t - start)
        env = (self.t >= start) * (1 - np.exp(-t / attack)) * np.exp(-t / decay)
        self.y += amp * env * texture
        return self

    def notes(self, freqs, gap=.065, start=0, decay=.10, amp=.55):
        for i, f in enumerate(freqs):
            self.tone(f, start + i * gap, decay, amp, metal=.12)
        return self

    def impact(self, start=0, size=1, amp=.65):
        self.tone(180 / size, start, .042 * size, amp,
                  end=65 / size, glide=.016 * size, metal=.18)
        self.noise(start, .026 * size, amp * .55, 130, 3400 / size)
        return self

    def debris(self, count=6, start=.04, span=.20, low=180, high=3400, amp=.25):
        for i in range(count):
            at = start + span * i / max(1, count - 1)
            self.noise(at, .012 + self.rng.random() * .02,
                       amp * (1 - .6 * i / count), low, high)
        return self

    def bubbles(self, count=5, start=0, span=.30, base=450, amp=.28):
        for i in range(count):
            at = start + span * i / max(1, count - 1)
            f = base * self.rng.uniform(.7, 1.5)
            self.tone(f, at, .022, amp, end=f * 1.8, glide=.009, metal=.05)
        return self


# Each recipe specifies timing and layers instead of simply transposing one cue.
RECIPES = {}


def recipe(name, duration, peak, draw):
    RECIPES['sfx_' + name] = (duration, peak, draw)


recipe('ui_back', .18, .22, lambda s: s.tone(980, decay=.024, end=740))
recipe('ui_select', .12, .20, lambda s: s.tone(880, decay=.017, metal=.08))
recipe('ui_panel_open', .24, .18, lambda s: s.noise(decay=.045, low=800, high=4000, attack=.008).tone(430, decay=.035, amp=.16, end=780))
recipe('ui_panel_close', .20, .16, lambda s: s.noise(decay=.036, low=600, high=2800, attack=.006).tone(640, decay=.03, amp=.12, end=320))
recipe('currency_gain', .40, .24, lambda s: s.notes([1320, 1760, 1480], gap=.037, decay=.045).noise(decay=.015, amp=.06, low=3000, high=6500))
recipe('purchase_success', .65, .30, lambda s: s.impact(size=.4, amp=.18).notes([659.25, 880, 1318.5], gap=.070, start=.045, decay=.085))
recipe('upgrade_complete', 1.15, .32, lambda s: s.tone(180, decay=.13, end=560, glide=.13, amp=.18).notes([440, 554.37, 659.25, 880], gap=.10, start=.04, decay=.15))
recipe('achievement_unlock', 2.00, .34, lambda s: s.notes([587.33, 739.99, 880, 1174.66], gap=.13, decay=.24).notes([293.66, 440, 587.33], gap=0, start=.4, decay=.25, amp=.30))

recipe('cosmic_dash', .30, .24, lambda s: s.noise(decay=.055, low=250, high=3600, attack=.008).tone(920, decay=.038, amp=.30, end=170, glide=.025))
recipe('cosmic_planet_enter', 1.60, .32, lambda s: s.noise(decay=.30, low=70, high=1000, attack=.08).tone(290, decay=.26, end=74, glide=.18, amp=.65, attack=.03).tone(146.83, start=.35, decay=.19, amp=.15))
recipe('cosmic_cache_open', 1.15, .30, lambda s: s.impact(size=.65, amp=.3).notes([440, 659.25, 880], start=.12, gap=.09, decay=.13).noise(start=.07, decay=.10, amp=.12, low=1200, high=6500))
recipe('cosmic_discovery', 1.60, .29, lambda s: s.notes([587.33, 880, 783.99, 1174.66], gap=.18, decay=.17, amp=.45))
recipe('cosmic_scan', .90, .22, lambda s: s.tone(740, decay=.10, attack=.012, metal=.03).tone(740, start=.22, decay=.095, amp=.24, attack=.01).tone(1480, start=.22, decay=.07, amp=.07))

recipe('combat_hit_light', .18, .28, lambda s: s.impact(size=.65))
recipe('combat_hit_heavy', .38, .38, lambda s: s.impact(size=1.65).debris(3, span=.065, high=1600, amp=.14))
recipe('combat_critical', .40, .36, lambda s: s.impact(size=1.1).notes([1568, 2093], gap=.018, start=.01, decay=.035, amp=.20))
recipe('combat_player_hurt', .38, .34, lambda s: s.impact(size=1.2).tone(360, decay=.065, end=145, glide=.033, amp=.40))
recipe('combat_enemy_defeat', .45, .25, lambda s: s.noise(decay=.065, low=300, high=2600).tone(580, decay=.07, end=105, glide=.04, amp=.4))
recipe('combat_shield_hit', .28, .26, lambda s: s.notes([622.25, 932.33, 1370], gap=0, decay=.044, amp=.35).noise(decay=.012, amp=.12, low=1800, high=6500))
recipe('combat_shield_break', .60, .31, lambda s: s.impact(size=.75, amp=.25).notes([1864.66, 1396.91, 932.33, 622.25], gap=.026, decay=.055, amp=.3).debris(7, span=.21, low=1600, high=7000, amp=.20))
recipe('combat_heal', .85, .25, lambda s: s.notes([440, 554.37, 659.25], gap=.09, decay=.12, amp=.35).tone(880, start=.16, decay=.10, amp=.13, attack=.04))
recipe('combat_danger', .46, .30, lambda s: s.notes([740, 740], gap=.15, decay=.036, amp=.5))
recipe('combat_victory', 2.60, .35, lambda s: s.notes([440, 554.37, 659.25, 880, 1108.73], gap=.16, decay=.24).notes([220, 329.63, 440], gap=0, start=.64, decay=.35, amp=.27))
recipe('combat_defeat', 2.00, .28, lambda s: s.notes([440, 349.23, 293.66, 277.18], gap=.20, decay=.23, amp=.40).tone(138.59, start=.60, decay=.25, amp=.25, attack=.02))

recipe('survival_wave_start', .85, .30, lambda s: s.notes([220, 293.66, 440], gap=.13, decay=.07, amp=.45).impact(size=.9, amp=.2))
recipe('survival_wave_clear', 1.00, .29, lambda s: s.notes([587.33, 739.99, 880], gap=.11, decay=.12))
recipe('survival_boss_arrive', 2.20, .40, lambda s: s.tone(73.42, decay=.35, attack=.07, amp=.50, wobble=.6).tone(103.83, decay=.30, attack=.06, amp=.2).impact(start=.43, size=2.5, amp=.8).noise(start=.42, decay=.15, low=60, high=1000, amp=.3))
recipe('survival_powerup_collect', .45, .28, lambda s: s.tone(500, decay=.06, end=1000, glide=.02, amp=.4).notes([880, 1174.66], gap=.045, decay=.05, start=.025))
recipe('survival_powerup_choose', .70, .31, lambda s: s.notes([587.33, 880, 1174.66], gap=.065, decay=.095).tone(293.66, start=.13, decay=.085, amp=.3))
recipe('survival_outbreak', 1.40, .33, lambda s: s.notes([311.13, 440, 311.13, 440], gap=.17, decay=.09, amp=.5).noise(start=.05, decay=.22, amp=.10, low=400, high=2500))
recipe('survival_milestone', 2.00, .34, lambda s: s.notes([293.66, 440, 587.33, 739.99, 1174.66], gap=.13, decay=.22).impact(size=1.3, amp=.22))

recipe('dungeon_interact', .30, .24, lambda s: s.impact(size=.32, amp=.3).tone(587.33, decay=.045, amp=.35))
recipe('dungeon_gate_open', 1.65, .32, lambda s: s.impact(size=1.2, amp=.4).noise(start=.045, decay=.25, amp=.6, low=60, high=800, attack=.04).debris(9, start=.12, span=.70, low=100, high=1800, amp=.12).impact(start=.95, size=1.5, amp=.20))
recipe('dungeon_switch', .30, .25, lambda s: s.impact(size=.4, amp=.5).impact(start=.055, size=.6, amp=.3))
recipe('dungeon_puzzle_solved', 1.40, .30, lambda s: s.notes([392, 523.25, 587.33, 783.99], gap=.13, decay=.15))
recipe('dungeon_star_collect', 2.00, .34, lambda s: s.notes([587.33, 880, 1174.66, 1567.98], gap=.11, decay=.20).tone(293.66, start=.33, decay=.24, amp=.24))
recipe('dungeon_secret_reveal', 1.15, .25, lambda s: s.noise(decay=.14, low=800, high=4000, attack=.04, amp=.15).notes([493.88, 739.99, 987.77], gap=.14, start=.045, decay=.12, amp=.32))
recipe('dungeon_wall_break', .80, .36, lambda s: s.impact(size=1.7).debris(10, span=.40, low=70, high=2300, amp=.35))
recipe('dungeon_block_move', .60, .26, lambda s: s.noise(decay=.12, low=80, high=1500, attack=.018, amp=.65).debris(5, span=.22, low=150, high=2200, amp=.15).impact(start=.35, size=.7, amp=.18))
recipe('dungeon_hazard_trigger', .45, .29, lambda s: s.impact(size=.45).tone(440, decay=.03, amp=.25, metal=.55).noise(start=.06, decay=.04, amp=.23, low=700, high=4000))
recipe('dungeon_checkpoint', .95, .27, lambda s: s.notes([293.66, 440, 587.33], gap=.095, decay=.12, amp=.40))
recipe('dungeon_relic_collect', 2.00, .32, lambda s: s.notes([146.83, 220, 293.66], gap=.08, decay=.28, amp=.45).notes([587.33, 880], gap=.14, start=.22, decay=.22, amp=.15))
recipe('dungeon_step_stone', .14, .18, lambda s: s.impact(size=.36, amp=.35).noise(start=.018, decay=.013, amp=.12, low=300, high=2200))
recipe('dungeon_step_water', .20, .18, lambda s: s.noise(decay=.026, amp=.40, low=350, high=3800).bubbles(2, start=.016, span=.025, base=650, amp=.13))

recipe('creature_summon', .80, .27, lambda s: s.noise(decay=.08, amp=.15, attack=.012, low=900, high=4600).notes([440, 659.25, 880], gap=.07, decay=.095))
recipe('capture_throw', .30, .24, lambda s: s.noise(decay=.052, amp=.35, low=600, high=4500, attack=.008).tone(620, decay=.035, end=300, amp=.14))
recipe('capture_attempt', .80, .26, lambda s: s.tone(220, decay=.12, attack=.012, amp=.50, end=293.66, glide=.09).tone(587.33, start=.055, decay=.085, amp=.15))
recipe('capture_success', 1.60, .32, lambda s: s.impact(size=.35, amp=.3).notes([523.25, 659.25, 783.99, 1046.5], start=.10, gap=.12, decay=.18))
recipe('capture_escape', .70, .27, lambda s: s.debris(4, span=.08, high=4700, amp=.2).noise(start=.04, decay=.10, amp=.25, low=900, high=4500).tone(600, decay=.07, end=210, amp=.30))
recipe('breeding_start', 1.20, .28, lambda s: s.tone(440, decay=.20, attack=.025, amp=.4, end=587.33, glide=.16).tone(739.99, decay=.20, attack=.025, amp=.30, end=587.33, glide=.16).tone(1174.66, start=.35, decay=.12, amp=.10))
def reaction_start(s):
    s.bubbles(8, span=.55, base=230, amp=.15)
    s.bubbles(9, start=.58, span=.33, base=390, amp=.22)
    s.noise(decay=.24, amp=.12, low=180, high=1600, attack=.08)
    s.noise(start=.35, decay=.23, amp=.22, low=300, high=2400, attack=.12)
    s.tone(110, decay=.27, end=220, glide=.22, amp=.15, attack=.07)
    s.tone(220, start=.40, decay=.22, end=440, glide=.20, amp=.23, attack=.12)


def reaction_burst(s):
    s.tone(210, decay=.085, end=62, glide=.027, amp=.55, attack=.004)
    s.noise(decay=.095, amp=.48, low=140, high=3300, attack=.006)
    s.bubbles(4, start=.025, span=.12, base=460, amp=.12)
    s.tone(440, start=.04, decay=.095, amp=.09, attack=.018, metal=.05)


def extraction_reveal(s, rare=False):
    # Scan passes, short telemetry packets, then a clean identification lock.
    passes = 5 if rare else 3
    for i in range(passes):
        at = i * .32
        s.tone(580 if i % 2 == 0 else 1080, start=at, decay=.072,
               end=1080 if i % 2 == 0 else 580, glide=.075,
               amp=.16, attack=.009, metal=.025)
        s.noise(start=at, decay=.052, amp=.035, low=1100, high=2800, attack=.012)
    packet_times = [.12, .19, .35, .40, .55, .63, .78, .83, .95]
    if rare:
        packet_times += [1.10, 1.16, 1.29, 1.38, 1.48, 1.57]
    for i, at in enumerate(packet_times):
        s.tone([1320, 990, 1480, 1100][i % 4], start=at,
               decay=.009, amp=.10 if i % 3 else .14,
               attack=.0015, metal=.02)
    lock = 1.08 if not rare else 1.77
    s.tone(740, start=lock, decay=.043, amp=.26, metal=.025)
    s.tone(1108.73, start=lock + .085, decay=.068, amp=.30, metal=.025)
    if rare:
        # A second verification ping marks an unusual specimen, without a flourish.
        s.tone(1480, start=lock + .21, decay=.085, amp=.24, metal=.02)


recipe('extraction_reaction_start', 1.60, .28, reaction_start)
recipe('extraction_reaction_burst', .75, .34, reaction_burst)
recipe('extraction_creature_reveal', 1.80, .30, extraction_reveal)
recipe('extraction_rare_reveal', 2.80, .36, lambda s: extraction_reveal(s, rare=True))
recipe('harvest_collect', .45, .23, lambda s: s.noise(decay=.022, amp=.14, low=600, high=3600).tone(680, decay=.035, end=450, amp=.3).tone(1174.66, start=.07, decay=.04, amp=.18))
recipe('extraction_complete', 1.05, .29, lambda s: s.tone(165, decay=.075, end=82, amp=.25).impact(start=.13, size=.4, amp=.2).notes([587.33, 880], gap=.10, start=.20, decay=.12))

recipe('element_fire', .65, .30, lambda s: s.noise(decay=.11, amp=.6, low=80, high=2600, attack=.009).debris(5, span=.22, low=600, high=4200, amp=.2).tone(120, decay=.055, amp=.2, end=65))
recipe('element_water', .65, .28, lambda s: s.noise(decay=.07, amp=.4, low=300, high=3400).bubbles(7, span=.30, base=660, amp=.23))
recipe('element_air', .45, .24, lambda s: s.noise(decay=.08, amp=.6, low=650, high=4500, attack=.024).tone(480, decay=.06, amp=.045, end=820))
recipe('element_earth', .65, .34, lambda s: s.impact(size=1.7).debris(6, span=.25, low=80, high=1300, amp=.3))
recipe('element_lightning', .35, .33, lambda s: s.noise(decay=.025, amp=.5, low=800, high=7500).tone(110, decay=.045, amp=.22, metal=1.2).debris(3, span=.07, low=2200, high=8000, amp=.22))
recipe('element_steam', .70, .27, lambda s: s.impact(size=.35, amp=.13).noise(decay=.13, amp=.65, low=1800, high=7200, attack=.015))
recipe('element_lava', .80, .33, lambda s: s.bubbles(5, span=.35, base=170, amp=.4).noise(decay=.13, amp=.33, low=50, high=1200).tone(72, decay=.10, amp=.25))
recipe('element_poison', .65, .28, lambda s: s.bubbles(6, span=.30, base=370, amp=.30).noise(start=.03, decay=.12, amp=.22, low=1700, high=5900))
recipe('element_ice', .50, .28, lambda s: s.debris(6, span=.17, low=2100, high=7500, amp=.26).notes([1480, 2093, 2793.83], gap=.04, decay=.055, amp=.24))
recipe('element_mud', .50, .28, lambda s: s.noise(decay=.05, amp=.5, low=70, high=900).bubbles(4, span=.12, base=170, amp=.35))
recipe('element_dust', .65, .24, lambda s: s.noise(decay=.12, amp=.45, low=750, high=3500, attack=.025).debris(8, span=.30, low=1400, high=4400, amp=.08))
recipe('element_crystal', .70, .28, lambda s: s.notes([880, 1318.5, 1760], gap=.025, decay=.10, amp=.40).tone(2217.46, start=.04, decay=.07, amp=.12))
recipe('element_plant', .65, .26, lambda s: s.noise(decay=.09, amp=.22, low=400, high=2200, attack=.008).debris(7, span=.25, low=700, high=4500, amp=.15).tone(280, decay=.065, end=560, amp=.13, metal=.05))
recipe('element_spirit', .95, .27, lambda s: s.tone(293.66, decay=.15, amp=.4, attack=.025, wobble=.45).tone(440, decay=.15, amp=.18, attack=.04).tone(587.33, start=.15, decay=.11, amp=.12, attack=.025).noise(decay=.12, amp=.06, low=1800, high=4500, attack=.03))
recipe('element_dark', .80, .32, lambda s: s.tone(155, decay=.13, amp=.60, end=55, glide=.07, attack=.02).tone(207.65, decay=.13, amp=.18, wobble=.7).noise(decay=.12, amp=.20, low=60, high=650, attack=.02))
recipe('element_light', .80, .28, lambda s: s.notes([659.25, 880, 1318.5], gap=.035, decay=.115, amp=.36).noise(decay=.08, amp=.04, low=3500, high=7000, attack=.02))
recipe('element_blood', .65, .30, lambda s: s.tone(85, decay=.045, amp=.6, end=58).tone(95, start=.17, decay=.06, amp=.5, end=62).bubbles(3, start=.02, span=.20, base=200, amp=.15))


def write_wav(path, data, peak, loop=False):
    data = np.asarray(data, dtype=np.float64)
    data -= np.mean(data, axis=0)
    if not loop:
        fade = np.ones(len(data))
        n = min(round(.018 * SR), len(data) // 3)
        fade[-n:] = .5 + .5 * np.cos(np.linspace(0, math.pi, n))
        fade[:48] *= .5 - .5 * np.cos(np.linspace(0, math.pi, 48))
        data *= fade[:, None] if data.ndim == 2 else fade
    data *= peak / max(np.max(np.abs(data)), 1e-9)
    pcm = np.round(data * 32767).astype('<i2')
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(1 if data.ndim == 1 else data.shape[1])
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())


def ambience(name, duration, seed):
    """Periodic FFT noise, integer-cycle oscillators, and wrapped spot events."""
    rng = np.random.default_rng(seed)
    n = round(duration * SR)
    t = np.arange(n) / SR
    freq = np.fft.rfftfreq(n, 1 / SR)
    y = np.zeros((n, 2))
    style = name.removeprefix('amb_').removesuffix('_loop')
    high, hum = {
        'cosmic_space': (400, 65.4), 'dungeon_ruins': (650, 73.4),
        'dungeon_water': (3200, 110), 'dungeon_fire': (1500, 55),
        'dungeon_arcane': (550, 146.83), 'lab': (950, 120),
    }[style]
    for channel in range(2):
        noise = np.fft.rfft(rng.normal(size=n))
        shape = np.exp(-(freq / high) ** 2) * (1 - np.exp(-(freq / 35) ** 4))
        noise = np.fft.irfft(noise * shape, n=n)
        noise /= max(np.std(noise) * 4, 1e-9)
        phase_offset = channel * .37
        mod = .75 + .18 * np.sin(TAU * 2 * t / duration + phase_offset)
        y[:, channel] = noise * mod * (.40 if style in ('dungeon_water', 'dungeon_fire') else .16)
        for harmonic, gain in [(1, .14), (2.003, .045), (3.011, .015)]:
            cycles = round(hum * harmonic * duration)
            y[:, channel] += gain * np.sin(TAU * cycles * t / duration + phase_offset) * (
                .80 + .12 * np.sin(TAU * t / duration + phase_offset))
    count = 26 if style == 'dungeon_fire' else 12 if style == 'dungeon_water' else 6
    for i in range(count):
        onset = rng.uniform(0, duration)
        local = (t - onset) % duration
        pan = rng.uniform(.2, .8)
        f = rng.uniform(450, 1100)
        if style in ('dungeon_water', 'lab'):
            f *= .7 if style == 'lab' else 1
            env = (1 - np.exp(-local / .002)) * np.exp(-local / .05)
            event = .13 * env * np.sin(TAU * (f * local + f * .015 * (1 - np.exp(-local / .015))))
        elif style == 'dungeon_fire':
            env = (1 - np.exp(-local / .001)) * np.exp(-local / .015)
            event = .12 * env * np.sin(TAU * f * local + 2 * np.sin(TAU * 217 * local))
        elif style == 'dungeon_ruins':
            env = (1 - np.exp(-local / .015)) * np.exp(-local / .15)
            event = .10 * env * (np.sin(TAU * 93 * local) + .2 * np.sin(TAU * 231 * local))
        else:
            f = rng.choice([293.66, 440, 587.33])
            env = (1 - np.exp(-local / .06)) * np.exp(-local / .45)
            event = .035 * env * np.sin(TAU * f * local)
        y[:, 0] += event * math.sqrt(1 - pan)
        y[:, 1] += event * math.sqrt(pan)
    return y


def read_pcm(path):
    with wave.open(str(path), 'rb') as f:
        assert f.getframerate() == SR and f.getsampwidth() == 2
        channels = f.getnchannels()
        pcm = np.frombuffer(f.readframes(f.getnframes()), dtype='<i2').reshape(-1, channels)
    return pcm.astype(np.float64) / 32768


def catalog():
    section = ''
    rows = []
    for line in (ROOT / 'docs/sound_asset_brief.md').read_text(encoding='utf-8').splitlines():
        if line.startswith('## '):
            section = line[3:].split(':')[0]
        if not line.startswith('|'):
            continue
        match = re.search(r'`((?:sfx|amb)_\w+)\.wav`', line)
        if match:
            cells = [c.strip() for c in line.split('|')[1:-1]]
            rows.append({'name': match[1], 'category': section, 'description': cells[-1],
                         'target': cells[-2]})
    assert len(rows) == 89, len(rows)
    return rows


def preview(rows):
    sections = []
    categories = list(dict.fromkeys(r['category'] for r in rows))
    categories.sort(key=lambda c: c != 'Alchemical extraction')
    for category in categories:
        cards = []
        for r in (r for r in rows if r['category'] == category):
            name = r['name']
            title = name.removeprefix('sfx_').removeprefix('amb_').replace('_', ' ').capitalize()
            source = '../../' + r['path']
            if not r['loop']:
                source = 'data:audio/wav;base64,' + base64.b64encode((ROOT / r['path']).read_bytes()).decode('ascii')
            badge = 'Approved' if name in APPROVED else 'New'
            options = ''
            if r.get('variations'):
                options = '<p class="variants">Variations: ' + ' · '.join(
                    f'<a href="../../{v}" target="_blank">{i + 1}</a>'
                    for i, v in enumerate(r['variations'])) + '</p>'
            cards.append(f'''<article data-search="{html.escape(title + ' ' + r['description'], quote=True)}">
<h3>{html.escape(title)} <span>{badge}</span></h3><p>{html.escape(r['description'])}</p>
<audio controls preload="none" {'loop' if r['loop'] else ''} src="{source}"></audio>
<p class="meta">{r['duration']:.2f} sec · {'Stereo loop' if r['loop'] else 'Mono WAV'}</p>
<a class="filename" href="../../{r['path']}" download>{name}.wav</a>{options}</article>''')
        sections.append(f'<section data-category="{html.escape(category, quote=True)}"><h2>{html.escape(category)}</h2><div class="grid">' + ''.join(cards) + '</div></section>')
    options = ''.join(f'<option>{html.escape(c)}</option>' for c in categories)
    page = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Alchemons · Complete sound library</title><style>
*{box-sizing:border-box}body{background:#101321;color:#edf0ff;font:16px system-ui;margin:0;padding:30px 22px}
main{max-width:1080px;margin:auto}h1{font-size:32px;margin-bottom:8px}p{color:#b9c1dc;line-height:1.5}
h2{font-size:23px;margin-top:34px}h3{font-size:18px;margin:0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(290px,1fr));gap:16px}
article{background:#1b2035;border:1px solid #343c60;border-radius:16px;padding:22px;min-width:0}
article p{font-size:14px}h3 span{font-size:10px;color:#9de9d2;display:inline-block;margin-left:6px;text-transform:uppercase}
audio{width:100%;margin:8px 0}.meta{font-size:12px}.filename{font:11px monospace;overflow-wrap:anywhere}
a{color:#a5c6ff}.controls{display:flex;gap:10px;flex-wrap:wrap;position:sticky;top:0;background:#101321ee;padding:14px 0;z-index:1}
input,select,button{background:#232a43;color:#edf0ff;border:1px solid #465273;border-radius:9px;padding:11px;font:14px system-ui}
input{flex:1;min-width:190px}button{cursor:pointer}[hidden]{display:none!important}.variants{font-size:12px}
</style><main><h1>Alchemons · Sound library</h1>
<p>89 core sounds · 21 extra variations · 10 approved samples preserved.<br>
Revised extraction sounds appear first: reaction buildup and release, then scanner sweeps, data ticks, and identification tones.<br>
Synthesized prototypes for review. Six ambient tracks loop automatically; playback is one sound at a time.</p>
<div class="controls"><input id="search" aria-label="Search sounds" placeholder="Search sounds…">
<select id="category" aria-label="Category"><option value="">All categories</option>OPTIONS</select>
<button id="stop">Stop audio</button></div>SECTIONS
<p>Runtime integration and on-device mixing remain a separate step. New effects have not yet had your listening review.</p>
</main><script>
const players=[...document.querySelectorAll('audio')];
players.forEach(a=>{a.volume=.7;a.addEventListener('play',()=>players.forEach(b=>{if(b!==a){b.pause();b.currentTime=0}}))});
document.querySelector('#stop').onclick=()=>players.forEach(a=>{a.pause();a.currentTime=0});
function filter(){const query=document.querySelector('#search').value.toLowerCase();const cat=document.querySelector('#category').value;
document.querySelectorAll('section').forEach(s=>{let visible=0;s.querySelectorAll('article').forEach(a=>{a.hidden=!!((cat&&s.dataset.category!==cat)||!a.dataset.search.toLowerCase().includes(query));if(!a.hidden)visible++;else a.querySelector('audio').pause()});s.hidden=!visible})}
document.querySelector('#search').oninput=filter;document.querySelector('#category').onchange=filter;
</script></html>'''.replace('OPTIONS', options).replace('SECTIONS', ''.join(sections))
    REVIEW.mkdir(parents=True, exist_ok=True)
    (REVIEW / 'index.html').write_text(page, encoding='utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--only-extraction', action='store_true',
                        help='Render the four revised extraction cues; preserve all other WAVs.')
    args = parser.parse_args()
    revised = {'sfx_extraction_reaction_start', 'sfx_extraction_reaction_burst',
               'sfx_extraction_creature_reveal', 'sfx_extraction_rare_reveal'}
    rows = catalog()
    original = {n: hashlib.sha256(asset_path(n).read_bytes()).hexdigest() for n in APPROVED}
    new_names = {r['name'] for r in rows if not r['name'].startswith('amb_')} - APPROVED
    assert set(RECIPES) == new_names, (set(RECIPES) - new_names, new_names - set(RECIPES))
    for i, r in enumerate(rows):
        name = r['name']
        loop = name.startswith('amb_')
        path = asset_path(name)
        if name in RECIPES and (not args.only_extraction or name in revised):
            duration, peak, draw = RECIPES[name]
            s = Synth(duration, 8500 + i)
            draw(s)
            write_wav(path, s.y, peak)
        elif loop and not args.only_extraction:
            write_wav(path, ambience(name, 30, 8500 + i), .15, loop=True)
        pcm = read_pcm(path)
        assert np.isfinite(pcm).all() and np.max(np.abs(pcm)) < .99, name
        assert np.max(np.abs(pcm.mean(axis=0))) < .01, name
        if loop:
            assert pcm.shape[1] == 2
            seam = np.max(np.abs(pcm[0] - pcm[-1]))
            assert seam < .025, (name, seam)
            r['loop_seam_delta'] = round(float(seam), 6)
        else:
            assert np.max(np.abs(pcm[[0, -1]])) < .0001, name
        r.update(path=path.relative_to(ROOT).as_posix(), duration=len(pcm)/SR,
                 loop=loop, peak_db=round(20 * math.log10(np.max(np.abs(pcm))), 2),
                 rms_db=round(20 * math.log10(np.sqrt(np.mean(pcm ** 2))), 2),
                 sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    # Three additional subtle speed/timbre variants leave each canonical file intact.
    varying = {'sfx_combat_projectile', 'sfx_combat_hit_light', 'sfx_combat_hit_heavy',
               'sfx_combat_enemy_defeat', 'sfx_cosmic_orb_pickup',
               'sfx_dungeon_step_stone', 'sfx_dungeon_step_water'}
    for r in rows:
        if r['name'] not in varying:
            continue
        source = read_pcm(asset_path(r['name']))[:, 0]
        r['variations'] = []
        for i, rate in enumerate([.94, 1.035, 1.08], 1):
            y = np.interp(np.arange(0, len(source) - 1, rate), np.arange(len(source)), source)
            path = asset_path(r['name']).with_stem(r['name'] + f'_{i:02d}')
            if not args.only_extraction:
                write_wav(path, y, float(np.max(np.abs(source))) * [0.96, 1, .92][i - 1])
            pcm = read_pcm(path)
            assert np.max(np.abs(pcm)) < .99 and np.max(np.abs(pcm[[0,-1]])) < .0001
            r['variations'].append(path.relative_to(ROOT).as_posix())
    for n, digest in original.items():
        assert hashlib.sha256(asset_path(n).read_bytes()).hexdigest() == digest, n
    preview(rows)
    (OUT / 'sound_manifest.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    size = sum(asset_path(r['name']).stat().st_size for r in rows)
    print(json.dumps({'core_sounds': len(rows), 'new_core_sounds': len(rows) - len(APPROVED),
                      'variations': 21, 'approved_unchanged': len(original),
                      'core_wav_megabytes': round(size / 1e6, 2),
                      'validation': 'PCM, duration, clipping, DC offset, endpoints, loop seam, approved hashes passed',
                      'preview': str(REVIEW / 'index.html')}, indent=2))


if __name__ == '__main__':
    main()
