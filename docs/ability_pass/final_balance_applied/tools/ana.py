"""Final-balance analysis: shares against the all-136 band medians.

usage: python3 ana.py --base DIR [--boss DIR] [--over DIR ...] [--show fam/El,fam,...] [--long DIR]
  base: main pass dir (*.jsonl, incl. control.jsonl)
  over: experiment dirs; their rows REPLACE base rows for the abilities they hold
        (medians are recomputed with the replacement).
"""
import json, sys, glob, statistics as st, collections, os, argparse, math

BANDS = ['P50', 'P70', 'P90', 'P100E10']
NONBOSS = ['horde', 'siege', 'shooters']
PASSIVE = {'horn/Air', 'horn/Mud', 'pip/Dark', 'kin/Fire'}
FAMS = ['horn', 'wing', 'let', 'pip', 'mane', 'mask', 'kin', 'mystic']


def load_dir(d):
    rows = []
    for p in sorted(glob.glob(os.path.join(d, '*.jsonl'))):
        for l in open(p):
            l = l.strip()
            if l:
                try:
                    rows.append(json.loads(l))
                except Exception:
                    pass
    return rows


def ab(r):
    return f"{r['family']}/{r['element']}"


def merge(base, overs, key=lambda r: True):
    """overs rows replace base rows per (ability, band, scen)."""
    over_keys = set()
    for o in overs:
        for r in o:
            if r['mode'] != 'control':
                over_keys.add((ab(r), r['band'], r['scen']))
    out = [r for r in base if r['mode'] == 'control' or (ab(r), r['band'], r['scen']) not in over_keys]
    seen = set()
    # later overs win
    for o in reversed(overs):
        for r in o:
            if r['mode'] == 'control':
                continue
            k = (ab(r), r['band'], r['scen'], r['seed'], r['mode'])
            if k in seen:
                continue
            seen.add(k)
            out.append(r)
    return out


def field(r, k):
    if k == 'ccSeconds':
        return r['ccUptime'] * r['enemiesPerFrame'] * (r.get('simSeconds') or r['seconds'])
    v = r.get(k)
    return float(v) if v is not None else 0.0


def cells(rows):
    full = collections.defaultdict(dict)
    auto = collections.defaultdict(dict)
    for r in rows:
        if r['mode'] == 'control':
            continue
        k = (ab(r), r['band'], r['scen'])
        (full if r['mode'] == 'full' else auto)[k][r['seed']] = r
    famauto = collections.defaultdict(list)
    for k, v in auto.items():
        if k[0] in PASSIVE:
            continue
        famauto[(k[0].split('/')[0], k[1], k[2])].extend(v.values())
    out = {}
    for k, fv in full.items():
        av = auto.get(k, {})
        pairs = [(fv[s], av[s]) for s in fv if s in av]
        base = None
        if k[0] in PASSIVE:
            b = famauto[(k[0].split('/')[0], k[1], k[2])]
            if b:
                base = {f: st.median([field(r, f) for r in b]) for f in ['damage', 'lost', 'healTotal', 'ccSeconds', 'bossRate']}
        if pairs:
            out[k] = (pairs, base)
    return out


def added(c, f):
    pairs, base = c
    return st.mean([field(a, f) - (base[f] if base else field(b, f)) for a, b in pairs])


def saved(c, f):
    pairs, base = c
    return st.mean([(base[f] if base else field(b, f)) - field(a, f) for a, b in pairs])


def fullv(c, f):
    vals = [float(a.get(f)) for a, _ in c[0] if a.get(f) is not None]
    return st.mean(vals) if vals else float('nan')


def thirds(c):
    t = [st.mean([float(a['thirdsTotal'][i]) - float(b['thirdsTotal'][i]) for a, b in c[0]]) for i in range(3)]
    return t


def summarise(main_rows, boss_rows=None, long_rows=None):
    c = cells(main_rows)
    abil = sorted({k[0] for k in c})
    med = {}
    for b in BANDS:
        for s in NONBOSS:
            vals = [added(c[(a, b, s)], 'damage') for a in abil if (a, b, s) in c]
            med[(b, s)] = st.median(vals) if vals else 1
    ctrl = collections.defaultdict(list)
    for r in main_rows:
        if r['mode'] == 'control':
            ctrl[(r['band'], r['scen'])].append(r['lost'])
    lostbase = {}
    for b in BANDS:
        v = [st.mean(ctrl[(b, s)]) for s in NONBOSS if ctrl[(b, s)]]
        lostbase[b] = st.mean(v) if v else 1
    bc = cells(boss_rows) if boss_rows else {}
    medboss = {}
    for b in BANDS:
        vals = [added(bc[(a, b, 'boss')], 'bossRate') for a in abil if (a, b, 'boss') in bc]
        medboss[b] = st.median(vals) if vals else float('nan')
    lc = cells(long_rows) if long_rows else {}
    medramp = {}
    for b in BANDS:
        vals = []
        for a in abil:
            k = (a, b, 'horde')
            if k in lc:
                t = thirds(lc[k])
                if t[0] > 0:
                    vals.append(t[2] / t[0])
        medramp[b] = st.median(vals) if vals else float('nan')
    res = {}
    for a in abil:
        d = {}
        for b in BANDS:
            nb = [c.get((a, b, s)) for s in NONBOSS]
            if any(x is None for x in nb):
                continue
            share = st.mean([added(c[(a, b, s)], 'damage') / max(1, med[(b, s)]) for s in NONBOSS])
            per = {s: added(c[(a, b, s)], 'damage') / max(1, med[(b, s)]) for s in NONBOSS}
            prot = st.mean([saved(x, 'lost') for x in nb]) / max(1, lostbase[b])
            heal = st.mean([added(x, 'healTotal') for x in nb]) / max(1, lostbase[b])
            cc = st.mean([added(x, 'ccSeconds') for x in nb])
            casts = st.mean([fullv(x, 'casts') for x in nb])
            live = st.mean([fullv(x, 'concMean') for x in nb])
            livemax = st.mean([fullv(x, 'concMax') for x in nb])
            boss = float('nan')
            if (a, b, 'boss') in bc and medboss[b] == medboss[b]:
                boss = added(bc[(a, b, 'boss')], 'bossRate') / max(1, medboss[b])
            ramp = float('nan')
            if (a, b, 'horde') in lc:
                t = thirds(lc[(a, b, 'horde')])
                if t[0] > 0 and medramp[b] > 0:
                    ramp = (t[2] / t[0]) / medramp[b]
            d[b] = dict(share=share, per=per, prot=prot, heal=heal, cc=cc, casts=casts, live=live,
                        livemax=livemax, boss=boss, ramp=ramp, n=len(nb[0][0]))
        res[a] = d
    return res, med, medboss


def fmt(v, w=6, p=2):
    return f'{v:{w}.{p}f}' if v == v else ' ' * (w - 1) + '-'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--base', required=True)
    ap.add_argument('--boss')
    ap.add_argument('--long')
    ap.add_argument('--over', action='append', default=[])
    ap.add_argument('--overboss', action='append', default=[])
    ap.add_argument('--show', default='')
    ap.add_argument('--cols', default='share')
    a = ap.parse_args()
    base = load_dir(a.base)
    overs = [load_dir(d) for d in a.over]
    rows = merge(base, overs)
    brows = None
    if a.boss:
        brows = merge(load_dir(a.boss), [load_dir(d) for d in a.overboss])
    lrows = load_dir(a.long) if a.long else None
    res, med, medboss = summarise(rows, brows, lrows)
    show = [s for s in a.show.split(',') if s]
    def want(x):
        if not show:
            return True
        return any(x == s or x.split('/')[0] == s for s in show)
    cols = a.cols.split(',')
    for x in sorted(res, key=lambda k: (FAMS.index(k.split('/')[0]), k)):
        if not want(x):
            continue
        d = res[x]
        line = f'{x:18}'
        for col in cols:
            line += f' {col}:' + ' '.join(fmt(d.get(b, {}).get(col, float('nan')), 6, 2 if col not in ('cc',) else 0) for b in BANDS)
        print(line)
    # family medians of share
    print('family median share  P50 P70 P90 P100E10')
    for f in FAMS:
        ms = []
        for b in BANDS:
            v = [res[x][b]['share'] for x in res if x.startswith(f + '/') and b in res[x]]
            ms.append(st.median(v) if v else float('nan'))
        print(f'  {f:7}', ' '.join(fmt(m) for m in ms))


if __name__ == '__main__':
    main()
