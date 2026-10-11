"""Apply exact-string edits to a tree.

usage: python3 apply.py <root> <edits.py> [<edits.py> ...] [--check] [--exp]
A module may define edits(mode) instead of EDITS; mode is exp or main.
Each edits file defines EDITS = [(relpath, old, new), ...].
An edit whose `new` text is already present (and `old` absent) is skipped.
`old` must occur exactly once, else the edit fails (nothing is written for that file).
"""
import sys, os, runpy

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    check = '--check' in sys.argv
    mode = 'exp' if '--exp' in sys.argv else 'main'
    root, files = args[0], args[1:]
    edits = []
    for f in files:
        ns = runpy.run_path(f)
        edits += ns['edits'](mode) if 'edits' in ns else ns['EDITS']
    byfile = {}
    for rel, old, new in edits:
        byfile.setdefault(rel, []).append((old, new))
    ok = True
    for rel, es in byfile.items():
        p = os.path.join(root, rel)
        src = open(p).read()
        out = src
        file_ok = True
        for old, new in es:
            n = out.count(old)
            if new in out and (old in new or n == 0):
                print(f'  skip   {rel}: already applied {new.strip()[:50]!r}')
            elif n == 1:
                out = out.replace(old, new)
                print(f'  apply  {rel}: {old.strip()[:60]!r}')
            elif n == 0 and new in out:
                print(f'  skip   {rel}: already applied {new.strip()[:50]!r}')
            else:
                print(f'  FAIL   {rel}: old found {n}x: {old.strip()[:70]!r}')
                ok = False
                file_ok = False
        if not check and file_ok and out != src:
            open(p, 'w').write(out)
    sys.exit(0 if ok else 1)

main()
