"""Generate original UI and cosmic prototypes using Python's standard library."""

import base64
import math
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/sounds"
RATE = 48000


def bell(t, frequency, decay):
    if t < 0:
        return 0.0
    attack = 1.0 - math.exp(-t / 0.0015)
    return attack * (
        math.sin(2 * math.pi * frequency * t) * math.exp(-t / decay)
        + 0.19 * math.sin(2 * math.pi * frequency * 2.003 * t)
        * math.exp(-t / (decay * 0.55))
        + 0.045 * math.sin(2 * math.pi * frequency * 3.98 * t)
        * math.exp(-t / (decay * 0.30))
    )


def write_sound(name, duration, synth, peak):
    samples = []
    for i in range(round(duration * RATE)):
        t = i / RATE
        # End on a smooth fade, even when a resonant tail is still present.
        end = min(1.0, max(0.0, (duration - t) / 0.018))
        fade = 0.5 - 0.5 * math.cos(math.pi * end)
        samples.append(synth(t) * fade)
    gain = peak / max(abs(s) for s in samples)
    pcm = [round(s * gain * 32767) for s in samples]
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(struct.pack(f"<{len(pcm)}h", *pcm))
    with wave.open(str(path), "rb") as audio:
        assert audio.getnframes() == len(pcm)
        assert audio.getframerate() == RATE
        assert audio.getnchannels() == 1
        assert max(abs(s) for s in pcm) < 32767
        assert abs(pcm[0]) < 2 and abs(pcm[-1]) < 2
    print(f"{name}: {duration:.2f}s, 48 kHz mono PCM WAV, peak {20 * math.log10(peak):.1f} dBFS")
    return path


def portal_sound(t):
    # Descending bass and inharmonic low resonances suggest a heavy space rift.
    # Upper bass harmonics keep the effect audible on small speakers.
    swell = (1 - math.exp(-t / 0.12)) * math.exp(-t / 0.48)
    phase = 2 * math.pi * (64 * t + 43 * 0.32 * (1 - math.exp(-t / 0.32)))
    field = swell * (
        0.52 * math.sin(phase + 0.65 * math.sin(2 * math.pi * 2.3 * t))
        + 0.24 * math.sin(phase * 1.017)
        + 0.25 * math.sin(phase * 2.003)
        + 0.14 * math.sin(phase * 3.011)
    )
    hollow = 0.0
    for frequency, level in [(146.83, 0.17), (207.65, 0.12), (311.13, 0.07)]:
        local = max(0.0, t - 0.24)
        envelope = (1 - math.exp(-local / 0.025)) * math.exp(-local / 0.31)
        hollow += level * envelope * math.sin(2 * math.pi * frequency * local)
    # Dense deterministic partials supply a subdued rushing texture.
    rush = sum(math.sin(2 * math.pi * (173 + i * 37.71) * t
                        + 0.8 * math.sin(2 * math.pi * (0.7 + i * 0.13) * t))
               for i in range(12)) / 12
    return field + hollow + 0.20 * swell * rush


def sweep(t, start, end, speed, decay):
    if t < 0:
        return 0.0
    phase = 2 * math.pi * (end * t + (start - end) * speed * (1 - math.exp(-t / speed)))
    return (1 - math.exp(-t / 0.003)) * math.exp(-t / decay) * (
        math.sin(phase) + 0.18 * math.sin(phase * 2.013))


def anomaly_sound(t):
    crackle = sum(math.sin(2 * math.pi * (211 + i * 139.31) * t
                           + 2.2 * math.sin(2 * math.pi * (31 + i) * t))
                  for i in range(14)) / 14
    return (0.65 * sweep(t, 260, 65, 0.045, 0.17)
            + 0.50 * (1 - math.exp(-t / 0.002)) * math.exp(-t / 0.085) * crackle
            + 0.12 * bell(t - 0.055, 233.08, 0.17)
            + 0.08 * bell(t - 0.095, 329.63, 0.13))


def starforge_sound(t):
    charge = (1 - math.exp(-t / 0.18)) * math.exp(-t / 0.50)
    phase = 2 * math.pi * (82.41 * t + 28 * t * t)
    field = charge * (0.30 * math.sin(phase) + 0.18 * math.sin(phase * 2.008))
    ignition = 0.70 * sweep(t - 0.72, 180, 55, 0.07, 0.34)
    resonance = sum(level * bell(t - 0.74, freq, 0.40)
                    for freq, level in [(110, 0.24), (164.81, 0.17),
                                        (220, 0.12), (261.63, 0.08)])
    return field + ignition + resonance + 0.045 * bell(t - 0.95, 659.25, 0.35)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    tap = write_sound(
        "sfx_ui_tap.wav", 0.12,
        lambda t: bell(t, 1174.66, 0.018) + 0.16 * bell(t, 587.33, 0.012),
        0.24,
    )
    confirm = write_sound(
        "sfx_ui_confirm.wav", 0.30,
        lambda t: 0.72 * bell(t, 1174.66, 0.036)
        + bell(t - 0.075, 1760.0, 0.045)
        + 0.12 * bell(t - 0.075, 880.0, 0.040),
        0.32,
    )
    denied = write_sound(
        "sfx_ui_denied.wav", 0.32,
        lambda t: bell(t, 392.0, 0.026)
        + 0.85 * bell(t - 0.105, 329.63, 0.032),
        0.25,
    )
    reward = write_sound(
        "sfx_reward_collect.wav", 0.70,
        lambda t: 0.65 * bell(t, 587.33, 0.065)
        + 0.70 * bell(t - 0.060, 739.99, 0.075)
        + 0.75 * bell(t - 0.120, 880.0, 0.090)
        + 0.85 * bell(t - 0.185, 1174.66, 0.110)
        + 0.12 * bell(t - 0.285, 1760.0, 0.075),
        0.32,
    )
    portal = write_sound(
        "cosmic/sfx_cosmic_portal_open.wav", 2.10, portal_sound, 0.38,
    )
    orb = write_sound(
        "cosmic/sfx_cosmic_orb_pickup.wav", 0.20,
        lambda t: 0.85 * bell(t, 1567.98, 0.027)
        + 0.30 * bell(t - 0.018, 2093.0, 0.024)
        + 0.12 * bell(t, 783.99, 0.018),
        0.20,
    )
    deposit = write_sound(
        "cosmic/sfx_cosmic_orb_deposit.wav", 0.80,
        lambda t: 0.30 * bell(t, 1567.98, 0.034)
        + 0.38 * bell(t - 0.045, 1174.66, 0.045)
        + 0.48 * bell(t - 0.090, 880, 0.055)
        + 0.65 * bell(t - 0.15, 293.66, 0.105)
        + 0.30 * bell(t - 0.15, 440, 0.100)
        + 0.25 * bell(t - 0.15, 587.33, 0.090),
        0.30,
    )
    anomaly = write_sound(
        "cosmic/sfx_cosmic_anomaly_burst.wav", 0.95, anomaly_sound, 0.36,
    )
    starforge = write_sound(
        "cosmic/sfx_cosmic_starforge_activate.wav", 2.80, starforge_sound, 0.38,
    )
    projectile = write_sound(
        "sfx_combat_projectile.wav", 0.18,
        lambda t: sweep(t, 1250, 310, 0.018, 0.024), 0.22,
    )
    cards = []
    for label, detail, path in [
        ("Orb deposit · new", "0.80 seconds · gathering particles settle into a warm chord", deposit),
        ("Anomaly burst · new", "0.95 seconds · dark energy rupture with a crackling edge", anomaly),
        ("Starforge activation · new", "2.80 seconds · ancient machine charges and ignites", starforge),
        ("Projectile launch · new", "0.18 seconds · compact descending energy pulse", projectile),
        ("Cosmic portal opening", "2.10 seconds · dark descending rumble and hollow resonance", portal),
        ("Locked / unavailable", "0.32 seconds · gentle descending double pulse", denied),
        ("Reward collection", "0.70 seconds · sparkling ascending flourish", reward),
        ("Cosmic orb pickup", "0.20 seconds · light liquid-glass plink", orb),
        ("Button tap", "0.12 seconds · soft crystalline tick", tap),
        ("Confirm action", "0.30 seconds · rising two-note chime", confirm),
    ]:
        encoded = base64.b64encode(path.read_bytes()).decode("ascii")
        cards.append(f'''<section><h2>{label}</h2><p>{detail}</p>
<audio controls preload="auto" src="data:audio/wav;base64,{encoded}"></audio>
<p class="filename">{path.name}</p></section>''')
    preview = ROOT / "build/audio_review"
    preview.mkdir(parents=True, exist_ok=True)
    (preview / "index.html").write_text('''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Alchemons sound samples · Batch 3</title><style>
body{background:#101321;color:#edf0ff;font:16px system-ui;margin:0;padding:40px 24px}
main{max-width:650px;margin:auto}h1{font-size:30px}p{color:#b9c1dc;line-height:1.6}
section{background:#1b2035;border:1px solid #343c60;border-radius:18px;padding:24px;margin:20px 0}
h2{margin:0 0 8px;font-size:21px}audio{width:100%;margin:12px 0}.filename{font:13px monospace}
</style><main><h1>Alchemons · Sound samples</h1><p>Batch 3: orb deposit, anomaly burst, starforge activation, and projectile launch. The four new samples appear first, followed by the six approved sounds.</p>
''' + "\n".join(cards) + "</main></html>", encoding="utf-8")
    print(f"Preview: {preview / 'index.html'}")


if __name__ == "__main__":
    main()
