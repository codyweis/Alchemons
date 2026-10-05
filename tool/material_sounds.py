"""Renders the game's sound effects and ambience from tool/sounds/*.py.

Every cue is built from materials -- grains, glass, air, metal, stone, fire,
water... -- never from clean sine tones, sweeps or note runs, and each is
scored to what its screen actually does. See tool/sounds/core.py for the
shared voices and the levelling rule, and each family module for its cues.

Run with NumPy + SciPy:

    python tool/material_sounds.py              # every cue
    python tool/material_sounds.py sfx_a sfx_b  # just these
    python tool/material_sounds.py --list       # what exists, and where
    python tool/material_sounds.py --out DIR    # render elsewhere, no manifest

A cue is `name: (build, description)` or a dict with `build`, `description`
and optionally:
    variants  N  -- also writes name_01 .. name_0N (SoundCue.assetForVariant),
                    each built with build(v=i): a real re-render with its
                    own randomness, not a pitch-shifted copy
    loop      True -- an ambience loop: checked for a seamless join
    path      'assets/audio/sounds/cosmic/x.wav' -- when not the default
"""
import argparse
import fcntl
import hashlib
import importlib
import inspect
import json
import math
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sounds.core import OUT, ROOT, SR  # noqa: E402

def load_cues():
    """Every module in tool/sounds/ but core: each exports CUES."""
    cues = {}
    here = Path(__file__).resolve().parent / 'sounds'
    for path in sorted(here.glob('*.py')):
        mod = path.stem
        if mod in ('core', '__init__') or mod.startswith('_'):
            continue
        module = importlib.import_module(f'sounds.{mod}')
        if not hasattr(module, 'CUES'):
            continue
        for name, spec in module.CUES.items():
            assert name not in cues, f'{name} is defined twice ({mod})'
            if isinstance(spec, tuple):
                spec = {'build': spec[0], 'description': spec[1]}
            spec['module'] = mod
            cues[name] = spec
    return cues


def write_wav(path, y):
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.round(np.clip(y, -1, 1) * 32767).astype('<i2').T.copy()
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())


def check(name, y, loop):
    assert y.ndim == 2 and y.shape[0] == 2, name
    assert np.isfinite(y).all() and np.max(np.abs(y)) < 0.99, name
    if loop:
        seam = np.max(np.abs(y[:, 0] - y[:, -1]))
        assert seam < 0.02, (name, 'loop seam', seam)
    else:
        assert np.max(np.abs(y[:, [0, -1]])) < 1e-3, (name, 'clicks at an end')


def render(name, spec, v=0):
    build = spec['build']
    takes_v = 'v' in inspect.signature(build).parameters
    return build(v=v) if takes_v else build()


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('names', nargs='*', help='cues to render (default all)')
    parser.add_argument('--out', help='render into this directory instead; '
                        'the manifest is left alone')
    parser.add_argument('--list', action='store_true')
    args = parser.parse_args()
    cues = load_cues()
    if args.list:
        for name, spec in cues.items():
            extra = f" x{spec['variants'] + 1}" if spec.get('variants') else ''
            print(f"{name:36s} {spec['module']:11s}{extra}  {spec['description']}")
        return
    names = args.names or list(cues)
    unknown = [n for n in names if n not in cues]
    assert not unknown, f'no such cue: {unknown}'

    rendered = []
    for name in names:
        spec = cues[name]
        loop = spec.get('loop', False)
        default = OUT / (name + '.wav')
        path = ROOT / spec['path'] if 'path' in spec else default
        if args.out:
            path = Path(args.out) / path.name
        takes = [(path, render(name, spec, 0))]
        for i in range(1, spec.get('variants', 0) + 1):
            takes.append((path.with_stem(f'{path.stem}_{i:02d}'),
                          render(name, spec, i)))
        for p, y in takes:
            check(p.stem, y, loop)
            write_wav(p, y)
        y = takes[0][1]
        row = dict(
            name=name,
            description=spec['description'],
            path=takes[0][0].relative_to(ROOT).as_posix() if not args.out else str(takes[0][0]),
            duration=round(y.shape[1] / SR, 3),
            loop=loop,
            peak_db=round(20 * math.log10(np.max(np.abs(y))), 2),
            rms_db=round(20 * math.log10(np.sqrt(np.mean(y ** 2))), 2),
            sha256=hashlib.sha256(takes[0][0].read_bytes()).hexdigest(),
            source=f"tool/sounds/{spec['module']}.py",
        )
        if len(takes) > 1:
            row['variations'] = [
                str(p) if args.out else p.relative_to(ROOT).as_posix()
                for p, _ in takes[1:]
            ]
        rendered.append(row)
        print(f"{name}: {row['duration']}s peak {row['peak_db']} dB "
              f"rms {row['rms_db']} dB" + (f" (+{len(takes) - 1} variants)" if len(takes) > 1 else ''))

    if args.out:
        return
    # Several renders can run at once (one per family); the manifest is
    # read, updated and written under a lock so none of them loses another's.
    manifest_path = OUT / 'sound_manifest.json'
    # (The lock lives outside assets/, or it would ship in the app.)
    with open(Path(tempfile.gettempdir()) / 'alchemons_sound_manifest.lock', 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        rows = json.loads(manifest_path.read_text(encoding='utf-8'))
        by_name = {r['name']: r for r in rows}
        for row in rendered:
            if row['name'] in by_name:
                by_name[row['name']].update(row)
            else:
                rows.append(row)
        manifest_path.write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
