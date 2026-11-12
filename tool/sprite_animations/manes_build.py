"""Mane idles from one drawn frame each (1200 px): breath with planted feet, head nod,
tail swing, as one smooth displacement field. 8 frames (2 rows x 4). Frame 0 = the art.

usage: manes_build.py <scratch> overlay|build [ids...]
"""
import sys, os, math
from PIL import Image, ImageDraw, ImageFont
S, MODE, ONLY = sys.argv[1], sys.argv[2], sys.argv[3:]
src = open(S + '/horns_build.py').read()
src = src[src.index('def sm(x):'):src.index('def sheet_path')]
exec(src)
U = __import__('os').path.dirname(__import__('os').path.abspath(__file__ if '__file__' in dir() else 'tool/sprite_animations/x')) + '/mane_stills/' if __import__('os').path.isdir('tool/sprite_animations/mane_stills') else 'tool/sprite_animations/mane_stills/'
O = S + '/manes'
N, CELL, DUR = 8, 10, 120
P = {
    'MAN01': dict(n='firemane', f='d3a45639', neck=(570, 740), xb=[(300, 830), (590, 820), (700, 775), (1000, 765)], tail=(770, 820), hip=900, foot=1000),
    'MAN02': dict(n='watermane', f='002fd647', neck=(560, 730), xb=[(300, 900), (560, 900), (640, 790), (1000, 790)], tail=(790, 800), hip=930, foot=1010),
    'MAN03': dict(n='earthmane', f='2e096193', neck=(560, 720), xb=[(300, 840), (640, 840), (720, 770), (1000, 740)], tail=(760, 830), hip=900, foot=990),
    'MAN04': dict(n='airmane', f='6c591cda', neck=(560, 730), xb=[(300, 920), (540, 920), (600, 725), (700, 730), (760, 800), (1000, 800)], tail=(790, 800), hip=900, foot=995),
    'MAN05': dict(n='steammane', f='4b75ba3f', neck=(600, 720), xb=[(300, 900), (700, 900), (780, 770), (1000, 760)], tail=(760, 870), hip=930, foot=1015),
    'MAN06': dict(n='lavamane', f='848c40cb', neck=(570, 700), xb=[(300, 800), (700, 800), (760, 770), (1000, 760)], tail=(760, 860), hip=900, foot=995),
    'MAN07': dict(n='lightningmane', f='53f857ab', neck=(570, 720), xb=[(300, 820), (540, 820), (600, 790), (1000, 790)], tail=(790, 800), hip=900, foot=995),
    'MAN08': dict(n='mudmane', f='6519d580', neck=(540, 740), xb=[(300, 1100), (1000, 1100)], tail=(800, 900), hip=930, foot=1005),
    'MAN09': dict(n='icemane', f='4a08166a', neck=(560, 700), xb=[(300, 840), (620, 840), (660, 775), (1000, 775)], tail=(800, 860), hip=920, foot=1005),
    'MAN10': dict(n='dustmane', f='a9a5cdf6', neck=(560, 720), xb=[(300, 800), (700, 800), (770, 725), (1000, 725)], tail=(720, 860), hip=920, foot=1010),
    'MAN11': dict(n='crystalmane', f='afdfaff5', neck=(560, 740), xb=[(300, 830), (620, 830), (690, 770), (1000, 770)], tail=(770, 850), hip=900, foot=1005),
    'MAN12': dict(n='plantmane', f='4aef4dac', neck=(560, 740), xb=[(300, 870), (560, 870), (630, 790), (800, 770), (1000, 770)], tail=(770, 850), hip=900, foot=1005),
    'MAN13': dict(n='poisonmane', f='18407a27', neck=(560, 730), xb=[(300, 840), (580, 840), (640, 780), (1000, 780)], tail=(790, 850), hip=900, foot=1000),
    'MAN14': dict(n='spiritmane', f='c65bb824', neck=(540, 740), xb=[(300, 900), (740, 900), (800, 640), (1000, 640)], tail=(620, 900), hip=1200, foot=1300),
    'MAN15': dict(n='darkmane', f='5a67451a', neck=(560, 720), xb=[(300, 800), (700, 790), (1000, 790)], tail=(800, 790), hip=900, foot=1025),
    'MAN16': dict(n='lightmane', f='0394f25d', neck=(540, 740), xb=[(300, 820), (740, 820), (800, 670), (1000, 670)], tail=(660, 870), hip=930, foot=1020),
    'MAN17': dict(n='bloodmane', f='03811362', neck=(560, 720), xb=[(300, 820), (680, 820), (760, 770), (1000, 770)], tail=(770, 860), hip=930, foot=1040),
    'MAN18': dict(n='earthmane2', f='b0768675', neck=(560, 740), xb=[(300, 780), (540, 780), (600, 790), (1000, 790)], tail=(800, 880), hip=920, foot=990),
}
BG = (14, 14, 18, 255)
font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 22)


def art(hid):
    im = Image.open(U + P[hid]['f'] + '-image.png').convert('RGBA')
    keep = Image.new('L', im.size, 255)
    d = ImageDraw.Draw(keep)
    for x in (0, 1160):
        for y in (0, 1160):
            d.rectangle((x, y, x + 40, y + 40), fill=0)      # the corner marks
    return Image.composite(im, Image.new('RGBA', im.size), keep)


def cell(f, n):
    c = Image.new('RGBA', (1200, 1200), BG)
    c.alpha_composite(f)
    return c.resize((n, n), Image.LANCZOS).convert('RGB')


def build(hid):
    p = P[hid]
    a = art(hid)
    base = a.convert('RGBa')
    hard = sum(a.getchannel('A').histogram()[1:255]) < 8000
    out = []
    for i in range(N):
        ph = 2 * math.pi * i / N
        g = {}
        for gy in range(0, 1201, CELL):
            for gx in range(0, 1201, CELL):
                dx, dy = disp(p, gx, gy, ph)
                d0 = disp(p, gx, gy, 0.0)
                g[gx, gy] = (gx - dx + d0[0], gy - dy + d0[1])
        mesh = [((x0, y0, x0 + CELL, y0 + CELL), g[x0, y0] + g[x0, y0 + CELL] + g[x0 + CELL, y0 + CELL] + g[x0 + CELL, y0])
                for y0 in range(0, 1200, CELL) for x0 in range(0, 1200, CELL)]
        f = base.transform((1200, 1200), Image.MESH, mesh, Image.BICUBIC).convert('RGBA')
        if hard:
            f.putalpha(f.getchannel('A').point(lambda v: 255 if v >= 128 else 0))
        bb = f.getbbox()
        assert bb[0] > 0 and bb[1] > 0 and bb[2] < 1200 and bb[3] < 1200, (hid, i, bb)
        out.append(f)
    name = hid + '_' + p['n']
    sheet = Image.new('RGBA', (4800, 2400))
    for i, f in enumerate(out):
        sheet.paste(f, ((i % 4) * 1200, (i // 4) * 1200))
    sheet.save('%s/%s_idle_spritesheet.png' % (O, name), optimize=True)
    n = 320
    g = []
    for k in range(N):
        c = Image.new('RGB', (2 * n + 10, n + 34), BG[:3])
        c.paste(cell(a, n), (0, 34))
        c.paste(cell(out[k], n), (n + 10, 34))
        d = ImageDraw.Draw(c)
        d.text((10, 6), p['n'].upper() + '  STILL', fill=(200, 170, 110), font=font)
        d.text((n + 20, 6), 'IDLE', fill=(200, 170, 110), font=font)
        g.append(c)
    print(hid, p['n'], 'hard' if hard else 'soft', out[2].getbbox(), flush=True)
    return g


def overlay(ids):
    Sx = Image.new('RGB', (6 * 330, 3 * 330), (60, 60, 70))
    for k, hid in enumerate(ids):
        p = P[hid]
        c = Image.new('RGBA', (1200, 1200), (60, 60, 70, 255))
        c.alpha_composite(art(hid))
        d = ImageDraw.Draw(c)
        d.line([(xb(p, y), y) for y in range(100, 1150, 10)], fill=(0, 255, 0, 255), width=6)
        for (x, y), col in ((p['neck'], (255, 0, 255, 255)), (p['tail'], (0, 255, 255, 255))):
            d.ellipse((x - 16, y - 16, x + 16, y + 16), fill=col)
        d.line((150, p['neck'][1] + 40, 1050, p['neck'][1] + 40), fill=(255, 0, 255, 255), width=3)
        for yy in (p['hip'], p['foot']):
            d.line((150, yy, 1050, yy), fill=(255, 255, 255, 255), width=4)
        d.text((20, 20), hid, fill='white', font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 60))
        Sx.paste(c.resize((330, 330), Image.LANCZOS).convert('RGB'), ((k % 6) * 330, (k // 6) * 330))
    Sx.save(O + '/overlay.png')


ids = ONLY or sorted(P)
if MODE == 'overlay':
    overlay(ids)
else:
    cells = [build(h) for h in ids]
    cols = 3
    rows = -(-len(cells) // cols)
    w, h = cells[0][0].size
    fr = []
    for k in range(N):
        c = Image.new('RGB', (cols * (w + 16), rows * (h + 10)), BG[:3])
        for j, g in enumerate(cells):
            c.paste(g[k], ((j % cols) * (w + 16), (j // cols) * (h + 10)))
        fr.append(c.quantize(255, dither=Image.NONE))
    fr[0].save(O + '/manes_all_side_by_side.gif', save_all=True, append_images=fr[1:], duration=DUR, loop=0)
    print(fr[0].size)
