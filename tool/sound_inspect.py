"""Look at a sound you cannot hear.

    python tool/sound_inspect.py path/to/a.wav [more.wav ...] [--png DIR]

Prints, per 0.1 s, the level a phone speaker would play (300 Hz - 8 kHz) and
the left/right balance, plus the whole cue's phone-band and full-band RMS --
a big gap between those two means low end a phone drops but headphones do
not. With --png, writes a spectrogram per file (needs ffmpeg) to view.
"""
import argparse
import subprocess
import wave
from pathlib import Path

import numpy as np
from scipy import signal


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('files', nargs='+')
    ap.add_argument('--png', help='write spectrograms into this directory')
    ap.add_argument('--step', type=float, default=0.1)
    args = ap.parse_args()
    for f in args.files:
        w = wave.open(f)
        sr, ch = w.getframerate(), w.getnchannels()
        a = np.frombuffer(w.readframes(w.getnframes()), '<i2').reshape(-1, ch) / 32768
        band = signal.butter(4, [300, 8000], btype='bandpass', fs=sr, output='sos')
        phone = signal.sosfilt(band, a, axis=0)

        def db(x):
            return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)

        print(f"{Path(f).name}: {len(a) / sr:.2f}s  phone {db(phone):.1f} dB  "
              f"full {db(a):.1f} dB  peak {20 * np.log10(np.abs(a).max() + 1e-9):.1f} dB")
        h = int(sr * args.step)
        for i in range(0, len(a), h):
            p = phone[i:i + h]
            lr = (db(p[:, 0]) - db(p[:, -1])) if ch == 2 else 0.0
            d = db(p)
            print(f"  {i / sr:5.2f}s {d:6.1f} dB  L-R {lr:+5.1f}  " + '#' * int(max(0, 70 + d) / 2))
        if args.png:
            out = Path(args.png) / (Path(f).stem + '.png')
            out.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', f, '-lavfi',
                            'showspectrumpic=s=1000x400:legend=1:scale=log:fscale=log',
                            str(out)], check=True)
            print(f"  spectrogram: {out}")


if __name__ == '__main__':
    main()
