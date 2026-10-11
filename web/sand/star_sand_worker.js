/* web/sand/star_sand_worker.js
 *
 * STAR SAND: the lit grains in the empty rails either side of the game
 * column on a wide desktop browser. Grains bank deep along the outer screen
 * edges and the foot of each rail, like drifts, and thin to a light scatter
 * toward the column, so the field reads as a starfield that is also sand.
 * Most are dim brass and ivory; a sparse marbling of muted element tints
 * runs through them; a few swell slowly brighter now and then.
 *
 * The mouse drawn through a rail stirs the grains along its path (the home
 * realm's "springs back" flow: drag 5, spring 14), a press twists them round
 * the point (the MIXES tap: 44 px, 3 rad, eased), and holding gathers the
 * grains nearby into a loose, lopsided swirl that drifts apart on release.
 *
 * Loaded two ways:
 *   - as a dedicated Worker (the normal path): it posts {t:'hello'}, is
 *     handed an OffscreenCanvas in {t:'init'}, and runs on its own;
 *   - as a classic <script> on the page (no OffscreenCanvas / Worker): it
 *     only defines self.StarSandCore, and star_sand.js runs the same Runner
 *     on the main thread with half the grains.
 *
 * Cheap by construction: grains live in typed arrays and are drawn as small
 * precomputed coverage kernels, added into one pixel buffer per rail. Only
 * the 16 px tiles something moved in are cleared and drawn again, and only
 * those are uploaded (putImageData with a dirty rect). At rest nothing is
 * drawn but the few twinkling grains, at ~15 fps. No blur, no strokes.
 */
(function (G) {
  'use strict';

  // ── Constants ─────────────────────────────────────────────────────────────

  var TAU = Math.PI * 2;

  // The flow a pointer leaves (sand_floor.dart, "springs back").
  var CELL = 12; // flow cell, CSS px
  var DRAG = 5;
  var SPRING = 14;
  var REACH = 30; // how far round the pointer the wake is felt
  var SIDE = 0.3; // how much of it goes out to the sides of the path
  var VMAX = 1300; // pointer speeds clamp here (px/s)

  // A press: the MIXES tap's twist.
  var TWIST_R = 44;
  var TWIST_TURN = 3.0;
  var TWIST_EASE = 0.16;

  // A hold: the eddy the grains are gathered into.
  var GATHER_R = 78; // how far round it grains are drawn in
  var SW_V = 46; // its fastest turn (px/s), at SW_CORE out
  var SW_CORE = 26;
  var SW_IN = 30; // how fast it draws grains in (px/s)

  // Grains.
  var CAP = 30000; // most grains, however big the screen
  var PX_PER_GRAIN = 10; // CSS px² of rail per grain, below the cap
  var REF_GRAIN_AREA = 7; // full-density px² per grain at which grains are 1x
  var MARGIN = 12; // clear margin round obstacles (CSS px)
  var TAPER = 44; // past the margin, the sand thins in over this (CSS px)
  var MIN_RAIL = 24; // narrower rails get no sand
  var EVICT_SHARE = 0.2; // grains under a new obstacle pushed aside (rest buried)

  // Drawing.
  var TILE_CSS = 16;
  var MAX_DEV_PX = 4.6e6; // device pixels of rail, most
  var Q = 24; // twinkle brightness steps
  var IDLE_MS = 66; // twinkles at rest: ~15 fps
  var GRID = 12; // the density field is read every GRID CSS px

  // Flags.
  var F_ACTIVE = 1,
    F_HIDDEN = 2,
    F_EVICTED = 4,
    F_TWINKLE = 8,
    F_STAR = 16;

  // Palette: ink + pale brass, and the element tints.
  var BG_R = 9,
    BG_G = 9,
    BG_B = 11;
  var BG32 = ((255 << 24) | (BG_B << 16) | (BG_G << 8) | BG_R) >>> 0;
  var BRASS = [184, 150, 86],
    BRIGHT = [205, 176, 122],
    GLOW = [226, 201, 143],
    IVORY = [230, 226, 218],
    MUTED = [142, 140, 136];
  var TINTS = [
    [224, 122, 95], // coral
    [92, 166, 158], // sea teal
    [192, 140, 66], // earthy ochre
    [146, 180, 214], // pale sky
    [164, 138, 206], // soft violet
  ];

  // Each grain's palette entry, worked out once: its color (to be dimmed to
  // its level), its color lit, and lit for a bright grain. Brass, bright
  // brass, ivory, muted, then the five tints (muted, and lit toward ivory).
  var PAL = (function () {
    var out = [];
    function mix(a, b, t) {
      return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
    }
    function push(base, lit) {
      var star = mix(lit, IVORY, 0.3);
      out.push(base[0], base[1], base[2], lit[0], lit[1], lit[2], star[0], star[1], star[2]);
    }
    var tones = [BRASS, BRIGHT, IVORY, MUTED];
    for (var i = 0; i < tones.length; i++) push(tones[i], mix(tones[i], GLOW, 0.55));
    for (i = 0; i < TINTS.length; i++) push(mix(TINTS[i], MUTED, 0.3), mix(TINTS[i], IVORY, 0.35));
    return new Float32Array(out);
  })();

  var now =
    typeof performance !== 'undefined' && performance.now
      ? function () {
          return performance.now();
        }
      : function () {
          return Date.now();
        };

  // ── Small helpers ─────────────────────────────────────────────────────────

  function clamp(v, a, b) {
    return v < a ? a : v > b ? b : v;
  }
  function clamp01(v) {
    return v < 0 ? 0 : v > 1 ? 1 : v;
  }
  function smooth01(x) {
    var c = x < 0 ? 0 : x > 1 ? 1 : x;
    return c * c * (3 - 2 * c);
  }
  function smoothstep(a, b, x) {
    return smooth01((x - a) / (b - a));
  }
  // Polynomial smooth minimum: rounds the corner where two banks meet.
  function smin(a, b, k) {
    var h = clamp01(0.5 + (0.5 * (b - a)) / k);
    return b + (a - b) * h - k * h * (1 - h);
  }

  function hashInt(a, b, c) {
    var h =
      Math.imul(a | 0, 0x27d4eb2d) ^
      Math.imul(b | 0, 0x165667b1) ^
      Math.imul(c | 0, 0x5bd1e995);
    h = Math.imul(h ^ (h >>> 15), 0x2c1b3c6d);
    h = Math.imul(h ^ (h >>> 12), 0x297a2d39);
    return h ^ (h >>> 15);
  }
  function hash01(a, b, c) {
    return (hashInt(a, b, c) >>> 0) / 4294967296;
  }

  // A small sequential generator (mulberry32), reseeded per grain.
  var rs = 1;
  function rnd() {
    rs = (rs + 0x6d2b79f5) | 0;
    var t = Math.imul(rs ^ (rs >>> 15), 1 | rs);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  // Value noise and three octaves of it (hatch_sand.dart's).
  function lattice(x, y, seed) {
    return (hashInt(x, y, seed) & 0xffffff) / 0xffffff;
  }
  function vnoise(x, y, seed) {
    var xi = Math.floor(x),
      yi = Math.floor(y);
    var fx = x - xi,
      fy = y - yi;
    fx = fx * fx * (3 - 2 * fx);
    fy = fy * fy * (3 - 2 * fy);
    var a = lattice(xi, yi, seed),
      b = lattice(xi + 1, yi, seed);
    var c = lattice(xi, yi + 1, seed),
      d = lattice(xi + 1, yi + 1, seed);
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
  }
  function fbm(x, y, seed) {
    return (
      (vnoise(x, y, seed) * 0.5 +
        vnoise(x * 2.03, y * 2.03, seed + 31) * 0.25 +
        vnoise(x * 4.12, y * 4.12, seed + 62) * 0.125) /
      0.875
    );
  }

  function pack(r, g, b) {
    return (
      (clamp(Math.round(r), 0, 255) << 16) |
      (clamp(Math.round(g), 0, 255) << 8) |
      clamp(Math.round(b), 0, 255)
    );
  }

  // ── Kernels: a grain, and a soft light, as pixel coverage ────────────────

  // A grain [d] device px across, in the home realm's grain sprite profile:
  // solid to 55% of its radius, 0.6 at 80%, gone at the rim, so a small grain
  // is a crisp lit point with a soft edge. Its centre sits at one of four
  // sub-pixel places each way (moving grains glide smoothly) or, index 4, the
  // pixel's middle (grains at rest are drawn crisp).
  function grainProfile(r) {
    if (r <= 0.55) return 1;
    if (r <= 0.8) return 1 - (0.4 * (r - 0.55)) / 0.25;
    if (r < 1) return (0.6 * (1 - r)) / 0.2;
    return 0;
  }
  var grainCache = [];
  function grainKernel(d, qx, qy) {
    var sc = Math.round(d * 8);
    if (sc < 4) sc = 4;
    if (sc > 255) sc = 255;
    var idx = sc * 25 + qx * 5 + qy;
    var K = grainCache[idx];
    if (K) return K;
    var R = sc / 16;
    var cx = qx === 4 ? 0.5 : (qx + 0.5) / 4;
    var cy = qy === 4 ? 0.5 : (qy + 0.5) / 4;
    var ext = Math.ceil(R + 1);
    var n = ext * 2 + 1;
    var data = new Float32Array(n * n);
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        var sum = 0;
        for (var b = 0; b < 4; b++) {
          var sy = j - ext + (b + 0.5) / 4 - cy;
          for (var a = 0; a < 4; a++) {
            var sx = i - ext + (a + 0.5) / 4 - cx;
            sum += grainProfile(Math.sqrt(sx * sx + sy * sy) / R);
          }
        }
        data[j * n + i] = sum / 16;
      }
    }
    K = { o: -ext, n: n, d: data };
    grainCache[idx] = K;
    return K;
  }

  // A soft light [d] device px across: the home realm's glow sprite profile.
  var haloCache = [];
  var HALO_AT = [0, 0.18, 0.42, 0.7, 1];
  var HALO_V = [1, 0.55, 0.18, 0.05, 0];
  function haloProfile(r) {
    if (r >= 1) return 0;
    for (var i = 1; i < 5; i++) {
      if (r <= HALO_AT[i]) {
        var t = (r - HALO_AT[i - 1]) / (HALO_AT[i] - HALO_AT[i - 1]);
        return HALO_V[i - 1] + (HALO_V[i] - HALO_V[i - 1]) * t;
      }
    }
    return 0;
  }
  function haloKernel(d) {
    var sc = Math.round(d * 2);
    if (sc < 4) sc = 4;
    if (sc > 160) sc = 160;
    var K = haloCache[sc];
    if (K) return K;
    var R = sc / 4;
    var ext = Math.ceil(R);
    var n = ext * 2 + 1;
    var data = new Float32Array(n * n);
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        var sum = 0;
        for (var b = 0; b < 2; b++) {
          for (var a = 0; a < 2; a++) {
            var sx = i - ext + (a + 0.5) / 2 - 0.5;
            var sy = j - ext + (b + 0.5) / 2 - 0.5;
            sum += haloProfile(Math.sqrt(sx * sx + sy * sy) / R);
          }
        }
        data[j * n + i] = sum / 4;
      }
    }
    K = { o: -ext, n: n, d: data };
    haloCache[sc] = K;
    return K;
  }

  // Adds kernel [K] at pixel (px, py), in (r, g, b), inside the clip.
  function splat(u8, bw, px, py, K, r, g, b, cx0, cy0, cx1, cy1) {
    var n = K.n;
    var x0 = px + K.o,
      y0 = py + K.o;
    var xs = x0 < cx0 ? cx0 : x0,
      xe = x0 + n > cx1 ? cx1 : x0 + n;
    var ys = y0 < cy0 ? cy0 : y0,
      ye = y0 + n > cy1 ? cy1 : y0 + n;
    if (xs >= xe || ys >= ye) return;
    var d = K.d;
    for (var y = ys; y < ye; y++) {
      var kr = (y - y0) * n - x0,
        row = y * bw;
      for (var x = xs; x < xe; x++) {
        var w = d[kr + x];
        if (w > 0.004) {
          var p = (row + x) << 2;
          u8[p] += r * w;
          u8[p + 1] += g * w;
          u8[p + 2] += b * w;
        }
      }
    }
  }

  // ── The field ─────────────────────────────────────────────────────────────

  function Core(opts) {
    opts = opts || {};
    this.half = !!opts.half;
    this.reduced = !!opts.reduced;
    this.n = 0;
    this.capN = 0;
    this.t = 0;
    this.W = 0;
    this.H = 0;
    this.s = 1;
    this.cw = 0;
    this.ch = 0;
    this.key = '';
    this.obsKey = '';
    this.rails = [];
    this.twists = [];
    this.hold = null;
    this.down = false;
    this.havePtr = false;
    this.px = 0;
    this.py = 0;
    this.pts = 0;
    this.ptrT = -10;
    this.ptrSpeed = 0;
    this.lastDx = 1;
    this.stamp = 0;
    this.fullDirty = true;
    this.fieldOn = false;
    this.activeN = 0;
    this.twN = 0;
    this.buildMs = 0;
    this.su = 0;
    this.sv = 0;
    // The look of one grain, filled by look().
    this.ap = { x: 0, y: 0, d: 0, r: 0, g: 0, b: 0, hd: 0, hr: 0, hg: 0, hb: 0, tr: 0, tx: 0, ty: 0 };
    this.tr = { tx0: 0, ty0: 0, tx1: 0, ty1: 0 };
  }

  /** Takes a layout; returns 'rebuilt', 'obstacles' or 'same'. */
  Core.prototype.setLayout = function (L) {
    var W = Math.max(1, Math.round(+L.width || 0));
    var H = Math.max(1, Math.round(+L.height || 0));
    var dpr = clamp(+L.dpr || 1, 1, 2);
    var col = L.column;
    var specs = [];
    var colX0 = W / 2,
      colX1 = W / 2,
      hasCol = false;
    if (col && +col.w > 0) {
      hasCol = true;
      colX0 = clamp(+col.x, 0, W);
      colX1 = clamp(+col.x + +col.w, 0, W);
    }
    if (colX0 >= MIN_RAIL) specs.push({ x0: 0, x1: colX0, outerLeft: true, gutter: hasCol });
    if (W - colX1 >= MIN_RAIL) specs.push({ x0: colX1, x1: W, outerLeft: false, gutter: hasCol });
    var area = 0;
    for (var i = 0; i < specs.length; i++) area += (specs[i].x1 - specs[i].x0) * H;
    // Device px × min(dpr, 2), unless that is a great many pixels (half as
    // many on the main thread).
    var maxPx = this.half ? MAX_DEV_PX / 2 : MAX_DEV_PX;
    var s = dpr;
    if (area * s * s > maxPx) s = Math.max(1, Math.sqrt(maxPx / area));
    s = Math.round(s * 100) / 100;
    var obs = [];
    var list = L.obstacles || [];
    for (var o = 0; o < list.length; o++) {
      var b = list[o];
      if (!b || !(+b.w > 0) || !(+b.h > 0)) continue;
      obs.push({ x: +b.x, y: +b.y, w: +b.w, h: +b.h });
    }
    var key = W + 'x' + H + '@' + s + '|' + colX0.toFixed(1) + ',' + colX1.toFixed(1);
    var obsKey = JSON.stringify(obs);
    if (key !== this.key) {
      this.key = key;
      this.obsKey = obsKey;
      this.build(W, H, s, specs, obs);
      return 'rebuilt';
    }
    if (obsKey !== this.obsKey) {
      this.obsKey = obsKey;
      this.setObstacles(obs, true);
      this.fullDirty = true;
      return 'obstacles';
    }
    return 'same';
  };

  // How thickly the sand lies at a point of rail [r], 0..1, given how far it
  // is from the rail's outer screen edge [e] and from the foot [b] (CSS px):
  // a bank along the outer edge, deeper toward the foot, and one along the
  // foot, deeper toward the outer corner, their inner side wandering as a
  // drift's does; clumped like a nebula; and a light scatter beyond them,
  // thinning toward the column.
  Core.prototype.densityAt = function (r, e, b, gutter) {
    var H = this.H,
      w = r.w;
    var u = clamp01(e / w);
    var yy = clamp01(1 - b / H); // 0 at the top, 1 at the foot
    var bankOut = clamp(w * (0.19 + 0.26 * Math.pow(yy, 1.6)), 44, w * 0.62);
    var bankBot = H * (0.1 + 0.08 * (1 - u));
    var m = smin(e / bankOut, b / bankBot, 0.35);
    m += 0.4 * (fbm(e / 150, b / 150, r.seed + 7) - 0.5) + 0.14 * (fbm(e / 46, b / 46, r.seed + 9) - 0.5);
    var inside = 1 - smoothstep(0.7, 1.2, m);
    var deep = 0.42 + 0.58 * (1 - clamp01(m));
    var clump = 0.5 + 0.75 * fbm(e / 66, b / 66, r.seed + 3);
    var scatter =
      (0.03 + 0.1 * (1 - u) * (1 - u)) * (0.5 + 0.9 * fbm(e / 120, b / 120, r.seed + 13));
    var d = Math.min(1, inside * deep * clump + (1 - inside) * scatter);
    // A dark gutter along the column.
    if (gutter < 60) d *= smoothstep(4, 60, gutter);
    return d;
  };

  // Marbling: where the element tints run, 0..1 (veins of a warped field).
  Core.prototype.veinAt = function (r, e, b) {
    var qx = fbm(e / 240, b / 240, r.seed + 21),
      qy = fbm(e / 240, b / 240, r.seed + 23);
    var wx = e + 220 * (qx - 0.5),
      wy = b + 220 * (qy - 0.5);
    var v = fbm(wx / 170, wy / 170, r.seed + 29);
    var a = Math.abs(v - 0.4),
      c = Math.abs(v - 0.58);
    return 1 - smoothstep(0, 0.026, Math.min(a, c));
  };

  Core.prototype.gridAt = function (r, arr, x, y) {
    var fx = clamp((x - r.x0) / GRID, 0, r.gw - 1.001);
    var fy = clamp(y / GRID, 0, r.gh - 1.001);
    var i = fx | 0,
      j = fy | 0;
    var tx = fx - i,
      ty = fy - j;
    var k = j * r.gw + i;
    var a = arr[k],
      b = arr[k + 1],
      c = arr[k + r.gw],
      d = arr[k + r.gw + 1];
    return a + (b - a) * tx + (c - a) * ty + (a - b - c + d) * tx * ty;
  };

  Core.prototype.build = function (W, H, s, specs, obs) {
    var t0 = now();
    this.W = W;
    this.H = H;
    this.s = s;
    this.cw = Math.round(W * s);
    this.ch = Math.round(H * s);
    var TD = Math.max(8, Math.round(TILE_CSS * s));
    this.TD = TD;
    var rails = [];
    var tiles = 0;
    var areaEff = 0,
      railArea = 0;
    for (var ri = 0; ri < specs.length; ri++) {
      var sp = specs[ri];
      var r = {
        x0: sp.x0,
        x1: sp.x1,
        w: sp.x1 - sp.x0,
        outerLeft: sp.outerLeft,
        gutter: sp.gutter,
        seed: sp.outerLeft ? 101 : 202,
        dx0: Math.round(sp.x0 * s),
        excl: [],
        raw: [],
      };
      r.bw = Math.max(1, Math.round(sp.x1 * s) - r.dx0);
      r.bh = this.ch;
      r.tw = Math.ceil(r.bw / TD);
      r.th = Math.ceil(r.bh / TD);
      r.base = tiles;
      tiles += r.tw * r.th;
      r.dirty = new Uint8Array(r.tw * r.th);
      r.dlist = new Int32Array(r.tw * r.th);
      r.dn = 0;
      r.rowMin = new Int32Array(r.th);
      r.rowMax = new Int32Array(r.th);
      r.img = this.pixels(ri, r.bw, r.bh);
      r.u8 = r.img.data;
      r.u32 = new Uint32Array(r.u8.buffer);
      // The lie of the sand, read every GRID px.
      r.gw = Math.ceil(r.w / GRID) + 2;
      r.gh = Math.ceil(H / GRID) + 2;
      var gn = r.gw * r.gh;
      r.gD = new Float32Array(gn);
      r.gV = new Float32Array(gn);
      r.gT = new Float32Array(gn);
      var sum = 0;
      for (var j = 0; j < r.gh; j++) {
        var y = j * GRID,
          b = H - y;
        for (var i = 0; i < r.gw; i++) {
          var x = r.x0 + i * GRID;
          var e = r.outerLeft ? x : W - x;
          var gut = !r.gutter ? 1e9 : r.outerLeft ? r.x1 - x : x - r.x0;
          var k = j * r.gw + i;
          var d = this.densityAt(r, e, b, gut);
          r.gD[k] = d;
          r.gV[k] = this.veinAt(r, e, b);
          r.gT[k] = fbm(e / 320, b / 320, r.seed + 31);
          if (i * GRID < r.w && y < H) sum += d;
        }
      }
      areaEff += sum * GRID * GRID;
      railArea += r.w * H;
      rails.push(r);
    }
    this.rails = rails;
    this.tiles = tiles;
    var maxTw = 1;
    for (ri = 0; ri < rails.length; ri++) maxTw = Math.max(maxTw, rails[ri].tw);
    // Open upload rects: [a, b, y0, y1, tiles, grew] each.
    this.open = new Int32Array(6 * (2 * maxTw + 8));

    // How many grains (one per PX_PER_GRAIN of rail, capped), laid by the
    // density; and how big: a big screen gets bigger grains, not more.
    var full = Math.max(1, Math.min(CAP, railArea / PX_PER_GRAIN));
    var want = this.half ? full * 0.5 : full;
    var cellA = Math.max(2.5, areaEff / Math.max(1, want));
    var gScale = clamp(Math.sqrt(areaEff / full / REF_GRAIN_AREA), 1, 1.45);
    this.gScale = gScale;
    var cap = Math.ceil(want * 1.25 + 600);
    this.alloc(cap);

    var n = 0;
    var spc = Math.sqrt(cellA);
    var HX = this.HX,
      HY = this.HY,
      IX = this.IX,
      IY = this.IY,
      SZ = this.SZ,
      PH = this.PH,
      DIE = this.DIE,
      COL = this.COL,
      LIT = this.LIT,
      FL = this.FL,
      RAIL = this.RAIL;
    var twTmp = [];
    for (ri = 0; ri < rails.length && n < cap; ri++) {
      r = rails[ri];
      // One cell to a grain, anchored to the rail's outer edge and the foot,
      // so a resize keeps the sand where it lay.
      var ci1 = Math.ceil(r.w / spc),
        cj1 = Math.ceil(H / spc);
      for (var cj = 0; cj < cj1 && n < cap; cj++) {
        for (var ci = 0; ci < ci1; ci++) {
          rs = hashInt(ci, cj, r.seed);
          var ee = (ci + rnd()) * spc,
            bb = (cj + rnd()) * spc;
          var gx = r.outerLeft ? r.x0 + ee : r.x1 - ee;
          var gy = H - bb;
          if (gx <= r.x0 || gx >= r.x1 || gy <= 0 || gy >= H) continue;
          var dens = this.gridAt(r, r.gD, gx, gy);
          if (rnd() >= dens) continue;
          HX[n] = IX[n] = gx;
          HY[n] = IY[n] = gy;
          RAIL[n] = ri;
          this.dress(n, r, gx, gy, dens, gScale, twTmp);
          n++;
          if (n >= cap) break;
        }
      }
    }
    this.n = n;
    // Twinkles.
    this.twN = twTmp.length / 4;
    this.twIdx = new Int32Array(this.twN);
    this.twP = new Float32Array(this.twN);
    this.twO = new Float32Array(this.twN);
    this.twA = new Float32Array(this.twN);
    for (var q = 0; q < this.twN; q++) {
      this.twIdx[q] = twTmp[q * 4];
      this.twP[q] = twTmp[q * 4 + 1];
      this.twO[q] = twTmp[q * 4 + 2];
      this.twA[q] = twTmp[q * 4 + 3];
    }
    // Bins: grains by the tile their home is in.
    this.HEAD = new Int32Array(Math.max(1, tiles));
    this.HEAD.fill(-1);
    for (var g = 0; g < n; g++) this.link(g, this.binOf(g));
    // The flow.
    this.fw = Math.ceil(W / CELL) + 2;
    this.fh = Math.ceil(H / CELL) + 2;
    this.fu = new Float32Array(this.fw * this.fh);
    this.fv = new Float32Array(this.fw * this.fh);
    this.ft = new Float32Array(this.fw * this.fh);
    this.fieldOn = false;
    this.activeN = 0;
    this.twists.length = 0;
    this.hold = null;
    this.havePtr = false;
    this.setObstacles(obs, false);
    this.fullDirty = true;
    this.buildMs = now() - t0;
  };

  // A w × h pixel buffer for rail [ri], over memory kept from the last build
  // when it is big enough: a resize allocates (and leaves for the collector)
  // megabytes only when the rails grow past what they had.
  Core.prototype.pixels = function (ri, w, h) {
    var bufs = this.pixBufs || (this.pixBufs = []);
    var need = w * h * 4;
    var buf = bufs[ri];
    if (!buf || buf.byteLength < need) buf = bufs[ri] = new ArrayBuffer(Math.ceil(need * 1.2));
    try {
      return new ImageData(new Uint8ClampedArray(buf, 0, need), w, h);
    } catch (e) {
      bufs[ri] = null;
      return new ImageData(w, h);
    }
  };

  // The grains' arrays, kept from the last build when they hold enough.
  Core.prototype.alloc = function (want) {
    if (this.capN >= want) return;
    var cap = Math.ceil(want * 1.15);
    this.capN = cap;
    this.HX = new Float32Array(cap);
    this.HY = new Float32Array(cap);
    this.IX = new Float32Array(cap);
    this.IY = new Float32Array(cap);
    this.OX = new Float32Array(cap);
    this.OY = new Float32Array(cap);
    this.VX = new Float32Array(cap);
    this.VY = new Float32Array(cap);
    this.SZ = new Float32Array(cap);
    this.PH = new Float32Array(cap);
    this.DIE = new Float32Array(cap);
    this.HEAT = new Float32Array(cap);
    this.SLACK = new Float32Array(cap);
    this.COL = new Int32Array(cap);
    this.LIT = new Int32Array(cap);
    this.FL = new Uint8Array(cap);
    this.TQ = new Uint8Array(cap);
    this.RAIL = new Uint8Array(cap);
    this.NEXT = new Int32Array(cap);
    this.PREV = new Int32Array(cap);
    this.BIN = new Int32Array(cap);
    this.BB = new Int16Array(cap * 4);
    this.STAMP = new Uint32Array(cap);
    this.ACT = new Int32Array(cap);
  };

  // Grain [n]'s size and colors: most dim brass and ivory "stars" of varied
  // brightness; the scatter a little brighter than the bank, so it reads as
  // stars; a sparse marbling of muted element tints along the veins; a few
  // bright grains with a faint halo; and a few that swell now and then.
  Core.prototype.dress = function (n, r, x, y, dens, gScale, twTmp) {
    var big = rnd();
    var size = (1.3 + 1.1 * big * big) * gScale;
    this.DIE[n] = rnd();
    this.PH[n] = rnd();
    var tone = rnd();
    var p = tone < 0.48 ? 0 : tone < 0.72 ? 1 : tone < 0.88 ? 2 : 3;
    var lv = rnd();
    var level = 0.18 + 0.5 * lv * lv + 0.14 * (1 - dens);
    var vein = this.gridAt(r, r.gV, x, y);
    var flags = 0;
    if (rnd() < 0.02 + 0.26 * vein) {
      var hue = this.gridAt(r, r.gT, x, y);
      p = 4 + (Math.floor((((hue * 3.7) % 1) + 1) % 1 * TINTS.length) % TINTS.length);
      level = 0.24 + 0.4 * rnd();
    }
    var lit = 3;
    if (rnd() < 0.006 + 0.016 * (1 - dens)) {
      flags |= F_STAR;
      level = 0.78 + 0.3 * rnd();
      if (size < 2.05 * gScale) size = 2.05 * gScale;
      lit = 6;
    }
    if (rnd() < 0.0022 + 0.0045 * (1 - dens)) {
      flags |= F_TWINKLE;
      var period = 10 + 12 * rnd();
      twTmp.push(n, period, rnd() * period, 0.65 + 0.35 * rnd());
    }
    var q = p * 9;
    this.SZ[n] = size;
    this.COL[n] = pack(PAL[q] * level, PAL[q + 1] * level, PAL[q + 2] * level);
    this.LIT[n] = pack(PAL[q + lit] * 1.05, PAL[q + lit + 1] * 1.05, PAL[q + lit + 2] * 1.05);
    this.FL[n] = flags;
    this.TQ[n] = 0;
    this.OX[n] = this.OY[n] = this.VX[n] = this.VY[n] = 0;
    this.HEAT[n] = this.SLACK[n] = 0;
    this.BB[n * 4] = -1;
  };

  // ── Bins ──────────────────────────────────────────────────────────────────

  Core.prototype.binOf = function (g) {
    var r = this.rails[this.RAIL[g]];
    var TD = this.TD;
    var tx = Math.floor((this.HX[g] * this.s - r.dx0) / TD);
    var ty = Math.floor((this.HY[g] * this.s) / TD);
    tx = tx < 0 ? 0 : tx >= r.tw ? r.tw - 1 : tx;
    ty = ty < 0 ? 0 : ty >= r.th ? r.th - 1 : ty;
    return r.base + ty * r.tw + tx;
  };

  Core.prototype.link = function (g, bin) {
    var h = this.HEAD[bin];
    this.NEXT[g] = h;
    this.PREV[g] = -1;
    if (h >= 0) this.PREV[h] = g;
    this.HEAD[bin] = g;
    this.BIN[g] = bin;
  };

  Core.prototype.unlink = function (g) {
    var p = this.PREV[g],
      nx = this.NEXT[g];
    if (p >= 0) this.NEXT[p] = nx;
    else this.HEAD[this.BIN[g]] = nx;
    if (nx >= 0) this.PREV[nx] = p;
  };

  // Tiles of rail [r] under the CSS rect, into this.tr; false if none.
  Core.prototype.tileRange = function (r, x0, y0, x1, y1) {
    var s = this.s,
      TD = this.TD,
      tr = this.tr;
    tr.tx0 = Math.max(0, Math.floor((x0 * s - r.dx0) / TD));
    tr.tx1 = Math.min(r.tw - 1, Math.floor((x1 * s - r.dx0) / TD));
    tr.ty0 = Math.max(0, Math.floor((y0 * s) / TD));
    tr.ty1 = Math.min(r.th - 1, Math.floor((y1 * s) / TD));
    return tr.tx0 <= tr.tx1 && tr.ty0 <= tr.ty1;
  };

  // ── Homes, obstacles ──────────────────────────────────────────────────────

  // How far (x, y) lies outside the nearest obstacle's margin; 0 inside one.
  Core.prototype.clearance = function (r, x, y) {
    var ex = r.excl,
      best = 1e9;
    for (var i = 0; i < ex.length; i++) {
      var o = ex[i];
      var dx = Math.max(o.x0 - x, 0, x - o.x1),
        dy = Math.max(o.y0 - y, 0, y - o.y1);
      if (dx === 0 && dy === 0) return 0;
      var d = Math.sqrt(dx * dx + dy * dy);
      if (d < best) best = d;
    }
    return best;
  };

  // Whether grain [k] may lie at (x, y): on its rail and clear of every
  // obstacle's margin; just past a margin only a share of grains lie, more
  // the further out, so the sand thins in toward a box instead of stopping
  // at a ruled edge.
  Core.prototype.keepAt = function (k, x, y) {
    var r = this.rails[this.RAIL[k]];
    if (x <= r.x0 || x >= r.x1 || y <= 0 || y >= this.H) return false;
    if (!r.excl.length) return true;
    var c = this.clearance(r, x, y);
    if (c >= TAPER) return true;
    if (c <= 0) return false;
    return hash01(k, 91, 3) < smoothstep(0, TAPER, c);
  };

  // Grain [k] given a new home at (x, y): drawn where it is and gliding there.
  Core.prototype.rehome = function (k, x, y) {
    if (!(this.FL[k] & F_ACTIVE)) this.activate(k);
    var cx = this.HX[k] + this.OX[k],
      cy = this.HY[k] + this.OY[k];
    this.HX[k] = x;
    this.HY[k] = y;
    this.OX[k] = cx - x;
    this.OY[k] = cy - y;
    var bin = this.binOf(k);
    if (bin !== this.BIN[k]) {
      this.unlink(k);
      this.link(k, bin);
    }
  };

  // Grain [k] put at (x, y) at once.
  Core.prototype.place = function (k, x, y) {
    this.HX[k] = x;
    this.HY[k] = y;
    this.OX[k] = this.OY[k] = this.VX[k] = this.VY[k] = 0;
    var bin = this.binOf(k);
    if (bin !== this.BIN[k]) {
      this.unlink(k);
      this.link(k, bin);
    }
  };

  // Obstacles (ad boxes): no grain lies within MARGIN of one. A share of the
  // grains a new box lands on are pushed aside and banked softly against it;
  // the rest are buried under it, and come back if it goes.
  Core.prototype.setObstacles = function (obs, glide) {
    var rails = this.rails;
    for (var ri = 0; ri < rails.length; ri++) {
      var r = rails[ri];
      r.excl = [];
      r.raw = [];
      for (var i = 0; i < obs.length; i++) {
        var o = obs[i];
        var x0 = o.x - MARGIN,
          x1 = o.x + o.w + MARGIN;
        if (x1 <= r.x0 || x0 >= r.x1) continue;
        r.excl.push({ x0: x0, y0: o.y - MARGIN, x1: x1, y1: o.y + o.h + MARGIN });
        r.raw.push({ x0: o.x, y0: o.y, x1: o.x + o.w, y1: o.y + o.h });
      }
    }
    var FL = this.FL;
    for (var k = 0; k < this.n; k++) {
      var f = FL[k];
      var origOK = this.keepAt(k, this.IX[k], this.IY[k]);
      if (f & F_HIDDEN) {
        if (origOK) {
          FL[k] = f & ~F_HIDDEN;
          this.place(k, this.IX[k], this.IY[k]);
        }
        continue;
      }
      if (f & F_EVICTED && origOK) {
        FL[k] = f & ~F_EVICTED;
        if (glide) this.rehome(k, this.IX[k], this.IY[k]);
        else this.place(k, this.IX[k], this.IY[k]);
        continue;
      }
      if (this.keepAt(k, this.HX[k], this.HY[k])) continue;
      var spot = hash01(k, 77, 5) < EVICT_SHARE ? this.spotBeside(k) : null;
      if (spot) {
        FL[k] |= F_EVICTED;
        if (glide) this.rehome(k, spot[0], spot[1]);
        else this.place(k, spot[0], spot[1]);
      } else {
        FL[k] = (FL[k] | F_HIDDEN) & ~F_ACTIVE;
        this.OX[k] = this.OY[k] = this.VX[k] = this.VY[k] = 0;
        this.HEAT[k] = this.SLACK[k] = 0;
      }
    }
    // Hidden grains leave the moving list.
    var A = this.ACT,
      m = 0;
    for (var a = 0; a < this.activeN; a++) {
      if (FL[A[a]] & F_ACTIVE) A[m++] = A[a];
    }
    this.activeN = m;
  };

  // Somewhere outside the box grain [k] lies under, past where it thins in.
  Core.prototype.spotBeside = function (k) {
    var x = this.HX[k],
      y = this.HY[k];
    var ex = this.rails[this.RAIL[k]].excl;
    var o = null;
    for (var i = 0; i < ex.length; i++) {
      var e = ex[i];
      if (x > e.x0 && x < e.x1 && y > e.y0 && y < e.y1) {
        o = e;
        break;
      }
    }
    if (!o) return null;
    var u = hash01(k, 78, 5),
      v = hash01(k, 79, 5);
    var out = TAPER * 0.6 + 90 * u;
    var along = (v - 0.5) * 24;
    var d = [x - o.x0, o.x1 - x, y - o.y0, o.y1 - y];
    for (var tries = 0; tries < 4; tries++) {
      var best = 0;
      for (var j = 1; j < 4; j++) if (d[j] < d[best]) best = j;
      var nx = x,
        ny = y;
      if (best === 0) (nx = o.x0 - out), (ny = y + along);
      else if (best === 1) (nx = o.x1 + out), (ny = y + along);
      else if (best === 2) (ny = o.y0 - out), (nx = x + along);
      else (ny = o.y1 + out), (nx = x + along);
      if (this.keepAt(k, nx, ny)) return [nx, ny];
      d[best] = 1e9;
    }
    return null;
  };

  // ── The flow a pointer leaves ─────────────────────────────────────────────

  Core.prototype.injectStir = function (ax, ay, vx, vy, ux, uy, sp) {
    var fw = this.fw,
      fh = this.fh,
      fu = this.fu,
      fv = this.fv;
    var g0x = Math.max(0, Math.floor((ax - REACH) / CELL));
    var g1x = Math.min(fw - 1, Math.ceil((ax + REACH) / CELL));
    var g0y = Math.max(0, Math.floor((ay - REACH) / CELL));
    var g1y = Math.min(fh - 1, Math.ceil((ay + REACH) / CELL));
    var r2 = REACH * REACH;
    var side = sp * SIDE;
    for (var gy = g0y; gy <= g1y; gy++) {
      for (var gx = g0x; gx <= g1x; gx++) {
        var dx = gx * CELL - ax,
          dy = gy * CELL - ay;
        var q = (dx * dx + dy * dy) / r2;
        if (q >= 1) continue;
        var w = (1 - q) * (1 - q);
        // Out to whichever side of its path it lies.
        var sd = dx * -uy + dy * ux >= 0 ? 1 : -1;
        var i = gy * fw + gx;
        // Toward the pointer's own speed, never past it.
        fu[i] += (vx - uy * sd * side - fu[i]) * w * 0.7;
        fv[i] += (vy + ux * sd * side - fv[i]) * w * 0.7;
      }
    }
    if (!this.fieldOn) {
      this.fieldOn = true;
      this.fx0 = g0x;
      this.fx1 = g1x;
      this.fy0 = g0y;
      this.fy1 = g1y;
    } else {
      if (g0x < this.fx0) this.fx0 = g0x;
      if (g1x > this.fx1) this.fx1 = g1x;
      if (g0y < this.fy0) this.fy0 = g0y;
      if (g1y > this.fy1) this.fy1 = g1y;
    }
  };

  Core.prototype.stepField = function (dt) {
    if (!this.fieldOn) return;
    var decay = Math.exp(-dt / 0.3);
    var fw = this.fw,
      fh = this.fh,
      t = this.ft;
    var x0 = Math.max(0, this.fx0 - 1),
      x1 = Math.min(fw - 1, this.fx1 + 1);
    var y0 = Math.max(0, this.fy0 - 1),
      y1 = Math.min(fh - 1, this.fy1 + 1);
    var most = 0;
    var nx0 = fw,
      nx1 = -1,
      ny0 = fh,
      ny1 = -1;
    for (var pass = 0; pass < 2; pass++) {
      var f = pass === 0 ? this.fu : this.fv;
      for (var gy = y0; gy <= y1; gy++) {
        var row = gy * fw;
        for (var gx = x0; gx <= x1; gx++) {
          var i = row + gx;
          var s = f[i] * 4,
            w = 4;
          if (gx > 0) (s += f[i - 1]), w++;
          if (gx < fw - 1) (s += f[i + 1]), w++;
          if (gy > 0) (s += f[i - fw]), w++;
          if (gy < fh - 1) (s += f[i + fw]), w++;
          t[i] = (s / w) * decay;
        }
      }
      for (gy = y0; gy <= y1; gy++) {
        row = gy * fw;
        for (gx = x0; gx <= x1; gx++) {
          i = row + gx;
          var v = t[i];
          var a = v < 0 ? -v : v;
          if (a < 0.5) {
            f[i] = 0;
            continue;
          }
          f[i] = v;
          if (a > most) most = a;
          if (gx < nx0) nx0 = gx;
          if (gx > nx1) nx1 = gx;
          if (gy < ny0) ny0 = gy;
          if (gy > ny1) ny1 = gy;
        }
      }
    }
    if (most < 3 || nx1 < 0) {
      for (gy = y0; gy <= y1; gy++) {
        this.fu.fill(0, gy * fw + x0, gy * fw + x1 + 1);
        this.fv.fill(0, gy * fw + x0, gy * fw + x1 + 1);
      }
      this.fieldOn = false;
      return;
    }
    this.fx0 = nx0;
    this.fx1 = nx1;
    this.fy0 = ny0;
    this.fy1 = ny1;
  };

  // The flow at (x, y), into this.su, this.sv.
  Core.prototype.sample = function (x, y) {
    var fx = x / CELL,
      fy = y / CELL;
    var gx = Math.floor(fx),
      gy = Math.floor(fy);
    if (gx < 0 || gy < 0 || gx >= this.fw - 1 || gy >= this.fh - 1) {
      this.su = this.sv = 0;
      return;
    }
    var tx = fx - gx,
      ty = fy - gy;
    var fw = this.fw,
      i = gy * fw + gx;
    var fu = this.fu,
      fv = this.fv;
    var u0 = fu[i],
      u1 = fu[i + 1],
      u2 = fu[i + fw],
      u3 = fu[i + fw + 1];
    this.su = u0 + (u1 - u0) * tx + (u2 - u0) * ty + (u0 - u1 - u2 + u3) * tx * ty;
    var v0 = fv[i],
      v1 = fv[i + 1],
      v2 = fv[i + fw],
      v3 = fv[i + fw + 1];
    this.sv = v0 + (v1 - v0) * tx + (v2 - v0) * ty + (v0 - v1 - v2 + v3) * tx * ty;
  };

  // ── The pointer ───────────────────────────────────────────────────────────

  /** kind: 0 move, 1 down, 2 up, 3 leave. Positions in CSS px. */
  Core.prototype.pointer = function (kind, x, y, ts, buttons) {
    if (!this.n || this.reduced) return;
    if (kind === 3) {
      this.havePtr = false;
      this.hold = null;
      return;
    }
    this.movePtr(x, y, ts);
    if (kind === 1) {
      var sgn = this.lastDx >= 0 ? 1 : -1;
      this.twists.push({ x: x, y: y, left: TWIST_TURN, sgn: sgn });
      if (this.twists.length > 6) this.twists.shift();
      this.hold = { x: x, y: y, t0: this.t, sgn: sgn };
    } else if (kind === 2) {
      this.hold = null;
    } else if (this.hold) {
      if (buttons === 0) this.hold = null;
      else {
        this.hold.x = x;
        this.hold.y = y;
      }
    }
  };

  Core.prototype.movePtr = function (x, y, ts) {
    if (!this.havePtr) {
      this.havePtr = true;
      this.px = x;
      this.py = y;
      this.pts = ts;
      this.ptrT = this.t;
      return;
    }
    var dx = x - this.px,
      dy = y - this.py;
    var len = Math.sqrt(dx * dx + dy * dy);
    var dt = (ts - this.pts) / 1000;
    if (!(dt > 1 / 240)) dt = 1 / 240;
    if (dt > 0.1) dt = 0.1;
    if (len >= 0.5) {
      var vx = clamp(dx / dt, -VMAX, VMAX),
        vy = clamp(dy / dt, -VMAX, VMAX);
      var sp = Math.sqrt(vx * vx + vy * vy);
      if (sp >= 1) {
        var ux = vx / sp,
          uy = vy / sp;
        // Laid along the way it came a step at a time: a fast pointer
        // leaves no gaps.
        var steps = Math.max(1, Math.ceil(len / 10));
        for (var i = 1; i <= steps; i++) {
          var f = i / steps;
          this.injectStir(this.px + dx * f, this.py + dy * f, vx, vy, ux, uy, sp);
        }
      }
      if (Math.abs(dx) > 0.5) this.lastDx = dx;
      this.ptrSpeed = len / dt;
      this.ptrT = this.t;
    }
    this.px = x;
    this.py = y;
    this.pts = ts;
  };

  // ── Twists (a press) ──────────────────────────────────────────────────────

  Core.prototype.turnTwists = function (dt) {
    // Quick at first, slowing to a stop.
    var share = 1 - Math.exp(-dt / TWIST_EASE);
    var tw = this.twists;
    for (var i = tw.length - 1; i >= 0; i--) {
      var w = tw[i];
      var turn = w.left < 0.01 ? w.left : w.left * share;
      this.twist(w.x, w.y, turn * w.sgn);
      w.left -= turn;
      if (w.left <= 1e-4) tw.splice(i, 1);
    }
  };

  // The sand round (cx, cy) turned about it by [turn] at the middle, less
  // further out: a turn that neither gathers nor spreads it. Homes move with
  // it, so the swirl stays in the sand as marbling.
  Core.prototype.twist = function (cx, cy, turn) {
    var R2 = TWIST_R * TWIST_R;
    var st = ++this.stamp;
    var HX = this.HX,
      HY = this.HY,
      FL = this.FL,
      ST = this.STAMP,
      NEXT = this.NEXT,
      HEAD = this.HEAD;
    for (var ri = 0; ri < this.rails.length; ri++) {
      var r = this.rails[ri];
      if (!this.tileRange(r, cx - TWIST_R, cy - TWIST_R, cx + TWIST_R, cy + TWIST_R)) continue;
      var tr = this.tr;
      var tx0 = tr.tx0,
        tx1 = tr.tx1,
        ty0 = tr.ty0,
        ty1 = tr.ty1;
      for (var ty = ty0; ty <= ty1; ty++) {
        for (var tx = tx0; tx <= tx1; tx++) {
          var k = HEAD[r.base + ty * r.tw + tx];
          while (k >= 0) {
            var nk = NEXT[k];
            if (ST[k] !== st && !(FL[k] & F_HIDDEN)) {
              ST[k] = st;
              var dx = HX[k] - cx,
                dy = HY[k] - cy;
              var d2 = dx * dx + dy * dy;
              if (d2 < R2) {
                var f = 1 - d2 / R2;
                var th = turn * f * f;
                var c = Math.cos(th),
                  s = Math.sin(th);
                var nx = cx + dx * c - dy * s,
                  ny = cy + dx * s + dy * c;
                if (this.keepAt(k, nx, ny)) this.rehome(k, nx, ny);
              }
            }
            k = nk;
          }
        }
      }
    }
  };

  // ── Stepping ──────────────────────────────────────────────────────────────

  Core.prototype.activate = function (k) {
    this.FL[k] |= F_ACTIVE;
    this.ACT[this.activeN++] = k;
    // What it looked like at rest, to be wiped where it was.
    this.look(k, false);
    this.storeBox(k);
  };

  // Grains lying under the flow that it is strong enough to move.
  Core.prototype.activateUnderField = function () {
    var x0 = this.fx0 * CELL - CELL,
      x1 = this.fx1 * CELL + CELL;
    var y0 = this.fy0 * CELL - CELL,
      y1 = this.fy1 * CELL + CELL;
    var FL = this.FL,
      NEXT = this.NEXT,
      HEAD = this.HEAD,
      HX = this.HX,
      HY = this.HY;
    for (var ri = 0; ri < this.rails.length; ri++) {
      var r = this.rails[ri];
      if (!this.tileRange(r, x0, y0, x1, y1)) continue;
      var tr = this.tr;
      for (var ty = tr.ty0; ty <= tr.ty1; ty++) {
        for (var tx = tr.tx0; tx <= tr.tx1; tx++) {
          var k = HEAD[r.base + ty * r.tw + tx];
          while (k >= 0) {
            if (!(FL[k] & (F_ACTIVE | F_HIDDEN))) {
              this.sample(HX[k], HY[k]);
              var su = this.su,
                sv = this.sv;
              if ((su < 0 ? -su : su) + (sv < 0 ? -sv : sv) > 2) this.activate(k);
            }
            k = NEXT[k];
          }
        }
      }
    }
  };

  Core.prototype.activateNear = function (cx, cy, rad) {
    var r2 = rad * rad;
    var FL = this.FL,
      NEXT = this.NEXT,
      HEAD = this.HEAD,
      HX = this.HX,
      HY = this.HY;
    for (var ri = 0; ri < this.rails.length; ri++) {
      var r = this.rails[ri];
      if (!this.tileRange(r, cx - rad, cy - rad, cx + rad, cy + rad)) continue;
      var tr = this.tr;
      for (var ty = tr.ty0; ty <= tr.ty1; ty++) {
        for (var tx = tr.tx0; tx <= tr.tx1; tx++) {
          var k = HEAD[r.base + ty * r.tw + tx];
          while (k >= 0) {
            if (!(FL[k] & (F_ACTIVE | F_HIDDEN))) {
              var dx = HX[k] - cx,
                dy = HY[k] - cy;
              if (dx * dx + dy * dy < r2) this.activate(k);
            }
            k = NEXT[k];
          }
        }
      }
    }
  };

  Core.prototype.step = function (dtIn) {
    if (!this.n || this.reduced) return;
    var dt = dtIn > 0.04 ? 0.04 : dtIn;
    this.t += dtIn > 0.25 ? 0.25 : dtIn;
    var t = this.t;
    if (this.twists.length) this.turnTwists(dt);
    this.stepField(dt);
    var fieldOn = this.fieldOn;

    // A hold: its pull ramps in slowly, and its centre wanders a little round
    // the pointer, so the swirl is lopsided.
    var hold = this.hold,
      g = 0,
      hcx = 0,
      hcy = 0,
      sgn = 1;
    if (hold) {
      g = smoothstep(0.2, 1.7, t - hold.t0);
      sgn = hold.sgn;
      hcx = hold.x + 6 * Math.cos(0.8 * t);
      hcy = hold.y + 4 * Math.sin(0.8 * t);
    }
    if (fieldOn) this.activateUnderField();
    if (g > 0) this.activateNear(hcx, hcy, GATHER_R * 0.92);

    var A = this.ACT,
      FL = this.FL,
      HX = this.HX,
      HY = this.HY,
      OX = this.OX,
      OY = this.OY,
      VX = this.VX,
      VY = this.VY,
      PH = this.PH,
      DIE = this.DIE,
      HEAT = this.HEAT,
      SLACK = this.SLACK;
    var GR = GATHER_R,
      GR2 = GR * GR;
    // Glints only right round a pointer that is moving.
    var hot = t - this.ptrT < 0.12 && this.havePtr;
    var pcx = this.px,
      pcy = this.py;
    var heatDecay = Math.exp(-dt * 3.4);
    var slackDecay = Math.exp(-dt / 0.9);
    var lop = 0.9 * t * sgn;
    for (var i = this.activeN - 1; i >= 0; i--) {
      var k = A[i];
      if (FL[k] & F_HIDDEN) {
        FL[k] &= ~F_ACTIVE;
        A[i] = A[--this.activeN];
        continue;
      }
      var ox = OX[k],
        oy = OY[k],
        vx = VX[k],
        vy = VY[k];
      var x = HX[k] + ox,
        y = HY[k] + oy;
      var fu = 0,
        fv = 0;
      if (fieldOn) {
        this.sample(x, y);
        // Some go further than others.
        var m = 0.85 + 0.15 * (DIE[k] * 2 - 1);
        fu = this.su * m;
        fv = this.sv * m;
      }
      var sl = SLACK[k] * slackDecay;
      var held = 0;
      if (g > 0) {
        var dx = x - hcx,
          dy = y - hcy,
          d2 = dx * dx + dy * dy;
        if (d2 < GR2) {
          var d = Math.sqrt(d2) + 1e-3,
            kk = 1 - d / GR;
          var ux = dx / d,
            uy = dy / d;
          // A slow eddy the grains are carried in: it turns fastest a little
          // out from the middle, faster on one side (the side itself turning
          // slowly round), and draws them in only as far as each grain's own
          // radius, so they bunch into a loose, lopsided spiral, never a ring.
          var lopf = 1 + 0.55 * Math.cos(Math.atan2(dy, dx) - lop);
          var vt = (d < SW_CORE ? (SW_V * d) / SW_CORE : (SW_V * SW_CORE) / d) * lopf * sgn;
          var ring = 2 + 48 * Math.pow(PH[k], 0.9);
          var vr = -SW_IN * clamp((d - ring) / 16, -1, 1);
          held = g * Math.min(1, kk * 2.5);
          fu += (-uy * vt + ux * vr) * held;
          fv += (ux * vt + uy * vr) * held;
          var want = Math.min(1, kk * 1.8) * g;
          if (want > sl) sl = want;
        }
      }
      var loose = 1 - sl;
      var spr = SPRING * loose * loose;
      // In the eddy a grain keeps to the flow, as sand in water does (left to
      // its own weight it would be flung out of the middle into a ring); let
      // go, it coasts a little further before the spring has it back.
      var drg = held > 0 ? DRAG * (1 + 0.8 * held) : DRAG * (1 - 0.45 * sl);
      var ax = drg * (fu - vx) - spr * ox;
      var ay = drg * (fv - vy) - spr * oy;
      vx += ax * dt;
      vy += ay * dt;
      ox += vx * dt;
      oy += vy * dt;
      var h = HEAT[k] * heatDecay;
      if (hot && DIE[k] < 0.35) {
        var qx = HX[k] + ox - pcx,
          qy = HY[k] + oy - pcy,
          q2 = qx * qx + qy * qy;
        if (q2 < 676) {
          var spd = (vx < 0 ? -vx : vx) + (vy < 0 ? -vy : vy);
          var hh = clamp01((spd - 140) / 480) * (1 - Math.sqrt(q2) / 26);
          // Only some of those right under it, and not all at once.
          if (hh > h && Math.sin(t * 9 + PH[k] * 40) > 0.2) h = hh;
        }
      }
      if (
        fu < 1 && fu > -1 && fv < 1 && fv > -1 &&
        ox < 0.15 && ox > -0.15 && oy < 0.15 && oy > -0.15 &&
        vx < 1 && vx > -1 && vy < 1 && vy > -1 &&
        h < 0.02 && sl < 0.03
      ) {
        // Home: a jump too small to see.
        OX[k] = OY[k] = VX[k] = VY[k] = 0;
        HEAT[k] = SLACK[k] = 0;
        FL[k] &= ~F_ACTIVE;
        A[i] = A[--this.activeN];
        this.markBox(k);
        this.look(k, false);
        this.markLook(k);
        this.BB[k * 4] = -1;
        continue;
      }
      OX[k] = ox;
      OY[k] = oy;
      VX[k] = vx;
      VY[k] = vy;
      HEAT[k] = h;
      SLACK[k] = sl;
    }
  };

  Core.prototype.busy = function () {
    return (
      this.activeN > 0 ||
      this.fieldOn ||
      this.twists.length > 0 ||
      !!this.hold ||
      this.t - this.ptrT < 2
    );
  };

  Core.prototype.setReduced = function (v) {
    this.reduced = !!v;
    if (!this.reduced || !this.n) return;
    // A still field: everything home, nothing lit.
    for (var a = 0; a < this.activeN; a++) {
      var k = this.ACT[a];
      this.OX[k] = this.OY[k] = this.VX[k] = this.VY[k] = 0;
      this.HEAT[k] = this.SLACK[k] = 0;
      this.FL[k] &= ~F_ACTIVE;
    }
    this.activeN = 0;
    this.TQ.fill(0);
    this.fu.fill(0);
    this.fv.fill(0);
    this.fieldOn = false;
    this.twists.length = 0;
    this.hold = null;
    this.fullDirty = true;
  };

  // ── Drawing ───────────────────────────────────────────────────────────────

  // How grain [k] looks now ([live]: where the flow has it, lit by its heat
  // and speed; else at rest at home), into this.ap. Device px, rail-local.
  Core.prototype.look = function (k, live) {
    var s = this.s,
      r = this.rails[this.RAIL[k]],
      ap = this.ap;
    var ox = live ? this.OX[k] : 0,
      oy = live ? this.OY[k] : 0;
    var X = (this.HX[k] + ox) * s - r.dx0,
      Y = (this.HY[k] + oy) * s;
    var D = this.SZ[k] * s;
    var c = this.COL[k],
      l = this.LIT[k];
    var cr = (c >> 16) & 255,
      cg = (c >> 8) & 255,
      cb = c & 255;
    var mixA = 0,
      grow = 0,
      haloA = 0,
      haloS = 0;
    var f = this.FL[k];
    if (f & F_TWINKLE) {
      var w = this.TQ[k] / Q;
      if (w > 0) {
        mixA = 0.85 * w;
        grow = 0.35 * w;
        if (w > 0.05) {
          haloA = 0.3 * w;
          haloS = 3.6;
        }
      }
    }
    if (f & F_STAR && haloA < 0.075) {
      haloA = 0.075;
      haloS = 3.0;
    }
    var trail = 0;
    if (live) {
      var h = this.HEAT[k];
      if (h > 0.01) {
        if (0.8 * h > mixA) mixA = 0.8 * h;
        if (0.25 * h > grow) grow = 0.25 * h;
        if (h > 0.45 && 0.2 * h > haloA) {
          haloA = 0.2 * h;
          haloS = 3.4;
        }
      }
      var vx = this.VX[k],
        vy = this.VY[k];
      var sp = (vx < 0 ? -vx : vx) + (vy < 0 ? -vy : vy);
      if (sp > 30) {
        // A little lighter while it moves; never bleached.
        var m2 = 0.28 * Math.min(1, (sp - 30) / 400);
        if (m2 > mixA) mixA = m2;
        if (sp > 110) {
          trail = Math.min(1, (sp - 110) / 320);
          ap.tx = -vx * s * 0.011;
          ap.ty = -vy * s * 0.011;
        }
      }
    }
    if (mixA > 0) {
      cr += (((l >> 16) & 255) - cr) * mixA;
      cg += (((l >> 8) & 255) - cg) * mixA;
      cb += ((l & 255) - cb) * mixA;
    }
    ap.x = X;
    ap.y = Y;
    ap.d = D * (1 + grow);
    ap.r = cr;
    ap.g = cg;
    ap.b = cb;
    if (haloA > 0) {
      ap.hd = D * haloS;
      ap.hr = ((l >> 16) & 255) * haloA;
      ap.hg = ((l >> 8) & 255) * haloA;
      ap.hb = (l & 255) * haloA;
    } else ap.hd = 0;
    ap.tr = trail;
  };

  // The tiles this.ap covers, into BB[k] (for wiping it next frame).
  Core.prototype.storeBox = function (k) {
    var ap = this.ap,
      r = this.rails[this.RAIL[k]],
      TD = this.TD;
    var ext = (ap.hd > ap.d ? ap.hd : ap.d) * 0.5 + 2;
    var x0 = ap.x - ext,
      x1 = ap.x + ext,
      y0 = ap.y - ext,
      y1 = ap.y + ext;
    if (ap.tr > 0) {
      var tx = ap.tx * 2,
        ty = ap.ty * 2;
      if (tx < 0) x0 += tx;
      else x1 += tx;
      if (ty < 0) y0 += ty;
      else y1 += ty;
    }
    var b = k * 4;
    this.BB[b] = clamp(Math.floor(x0 / TD), 0, r.tw - 1);
    this.BB[b + 1] = clamp(Math.floor(y0 / TD), 0, r.th - 1);
    this.BB[b + 2] = clamp(Math.floor(x1 / TD), 0, r.tw - 1);
    this.BB[b + 3] = clamp(Math.floor(y1 / TD), 0, r.th - 1);
  };

  Core.prototype.markTiles = function (r, tx0, ty0, tx1, ty1) {
    var dirty = r.dirty,
      dl = r.dlist,
      tw = r.tw;
    for (var ty = ty0; ty <= ty1; ty++) {
      for (var tx = tx0; tx <= tx1; tx++) {
        var i = ty * tw + tx;
        if (!dirty[i]) {
          dirty[i] = 1;
          dl[r.dn++] = i;
        }
      }
    }
  };

  // Marks the tiles grain [k] was last drawn over.
  Core.prototype.markBox = function (k) {
    var b = k * 4,
      BB = this.BB;
    if (BB[b] < 0) return;
    this.markTiles(this.rails[this.RAIL[k]], BB[b], BB[b + 1], BB[b + 2], BB[b + 3]);
  };

  // Marks the tiles this.ap covers.
  Core.prototype.markLook = function (k) {
    this.storeBox(k);
    this.markBox(k);
  };

  // Adds this.ap into rail [r]'s pixels, inside the clip.
  Core.prototype.drawLook = function (r, live, cx0, cy0, cx1, cy1) {
    var ap = this.ap,
      u8 = r.u8,
      bw = r.bw;
    var X = ap.x,
      Y = ap.y;
    var px = Math.floor(X),
      py = Math.floor(Y);
    var K;
    if (live) {
      var qx = ((X - px) * 4) | 0,
        qy = ((Y - py) * 4) | 0;
      K = grainKernel(ap.d, qx, qy);
    } else K = grainKernel(ap.d, 4, 4);
    if (ap.hd > 0) {
      splat(u8, bw, px, py, haloKernel(ap.hd), ap.hr, ap.hg, ap.hb, cx0, cy0, cx1, cy1);
    }
    splat(u8, bw, px, py, K, ap.r, ap.g, ap.b, cx0, cy0, cx1, cy1);
    if (ap.tr > 0) {
      // A short faint trail behind a grain moving fast.
      var a1 = 0.4 * ap.tr,
        a2 = 0.18 * ap.tr;
      var x1 = X + ap.tx,
        y1 = Y + ap.ty,
        x2 = X + ap.tx * 2,
        y2 = Y + ap.ty * 2;
      var p1 = Math.floor(x1),
        q1 = Math.floor(y1),
        p2 = Math.floor(x2),
        q2 = Math.floor(y2);
      splat(u8, bw, p1, q1, grainKernel(ap.d, ((x1 - p1) * 4) | 0, ((y1 - q1) * 4) | 0),
        ap.r * a1, ap.g * a1, ap.b * a1, cx0, cy0, cx1, cy1);
      splat(u8, bw, p2, q2, grainKernel(ap.d, ((x2 - p2) * 4) | 0, ((y2 - q2) * 4) | 0),
        ap.r * a2, ap.g * a2, ap.b * a2, cx0, cy0, cx1, cy1);
    }
  };

  // Whether a moving grain at (x, y) (CSS) is under an obstacle or off its
  // rail: it is not drawn there.
  Core.prototype.hiddenAt = function (r, x, y) {
    if (x < r.x0 || x > r.x1) return true;
    var raw = r.raw;
    for (var i = 0; i < raw.length; i++) {
      var o = raw[i];
      if (x > o.x0 && x < o.x1 && y > o.y0 && y < o.y1) return true;
    }
    return false;
  };

  Core.prototype.updateTwinkles = function (mark) {
    if (this.reduced) return;
    var t = this.t,
      TQ = this.TQ,
      FL = this.FL;
    for (var i = 0; i < this.twN; i++) {
      var k = this.twIdx[i];
      if (FL[k] & F_HIDDEN) continue;
      var p = this.twP[i];
      var x = ((t + this.twO[i]) % p) / 3.0;
      var w = 0;
      if (x < 1) {
        // A slow swell and fade, smooth at both ends.
        var sn = Math.sin(Math.PI * x);
        w = sn * sn * this.twA[i];
      }
      var q = Math.round(w * Q);
      var old = TQ[k];
      if (q === old) continue;
      if (mark && !(FL[k] & F_ACTIVE)) {
        TQ[k] = q > old ? q : old;
        this.look(k, false);
        this.storeBox(k);
        this.markBox(k);
        this.BB[k * 4] = -1;
      }
      TQ[k] = q;
    }
  };

  /** Draws what changed into the context. */
  Core.prototype.render = function (ctx) {
    if (!this.n) return;
    var rails = this.rails;
    if (this.fullDirty) {
      this.fullDirty = false;
      this.drawAll(ctx);
      return;
    }
    this.updateTwinkles(true);
    var A = this.ACT,
      FL = this.FL,
      k,
      i;
    // Moving grains: wipe where they were, and where they are now.
    for (i = 0; i < this.activeN; i++) {
      k = A[i];
      this.markBox(k);
      this.look(k, true);
      this.markLook(k);
    }
    var TD = this.TD,
      HEAD = this.HEAD,
      NEXT = this.NEXT;
    for (var ri = 0; ri < rails.length; ri++) {
      var r = rails[ri];
      if (!r.dn) continue;
      if (r.dn > r.tw * r.th * 0.45) {
        this.drawRail(ri);
        r.full = true;
        continue;
      }
      var u32 = r.u32,
        bw = r.bw,
        bh = r.bh,
        tw = r.tw,
        th = r.th;
      for (var j = 0; j < r.dn; j++) {
        var ti = r.dlist[j];
        var ty = (ti / tw) | 0,
          tx = ti - ty * tw;
        var cx0 = tx * TD,
          cy0 = ty * TD;
        var cx1 = Math.min(bw, cx0 + TD),
          cy1 = Math.min(bh, cy0 + TD);
        for (var y = cy0; y < cy1; y++) u32.fill(BG32, y * bw + cx0, y * bw + cx1);
        // The grains at rest round it, clipped to it.
        var by0 = ty > 0 ? ty - 1 : 0,
          by1 = ty < th - 1 ? ty + 1 : ty;
        var bx0 = tx > 0 ? tx - 1 : 0,
          bx1 = tx < tw - 1 ? tx + 1 : tx;
        for (var by = by0; by <= by1; by++) {
          for (var bx = bx0; bx <= bx1; bx++) {
            k = HEAD[r.base + by * tw + bx];
            while (k >= 0) {
              if (!(FL[k] & (F_ACTIVE | F_HIDDEN))) {
                this.look(k, false);
                this.drawLook(r, false, cx0, cy0, cx1, cy1);
              }
              k = NEXT[k];
            }
          }
        }
      }
    }
    // Moving grains, once each: all of each lies in tiles wiped above.
    for (i = 0; i < this.activeN; i++) {
      k = A[i];
      var rr = rails[this.RAIL[k]];
      if (rr.full) continue;
      if (this.hiddenAt(rr, this.HX[k] + this.OX[k], this.HY[k] + this.OY[k])) continue;
      this.look(k, true);
      this.drawLook(rr, true, 0, 0, rr.bw, rr.bh);
    }
    this.upload(ctx);
  };

  // Rail [ri] drawn whole.
  Core.prototype.drawRail = function (ri) {
    var r = this.rails[ri];
    r.u32.fill(BG32);
    var FL = this.FL,
      HEAD = this.HEAD,
      NEXT = this.NEXT;
    var nt = r.tw * r.th;
    for (var t = 0; t < nt; t++) {
      var k = HEAD[r.base + t];
      while (k >= 0) {
        var f = FL[k];
        if (!(f & F_HIDDEN)) {
          var live = (f & F_ACTIVE) !== 0;
          if (!live || !this.hiddenAt(r, this.HX[k] + this.OX[k], this.HY[k] + this.OY[k])) {
            this.look(k, live);
            this.drawLook(r, live, 0, 0, r.bw, r.bh);
          }
          if (live) this.storeBox(k);
        }
        k = NEXT[k];
      }
    }
  };

  Core.prototype.drawAll = function (ctx) {
    var t0 = now();
    this.updateTwinkles(false);
    for (var ri = 0; ri < this.rails.length; ri++) {
      var r = this.rails[ri];
      this.drawRail(ri);
      for (var j = 0; j < r.dn; j++) r.dirty[r.dlist[j]] = 0;
      r.dn = 0;
      r.full = false;
      ctx.putImageData(r.img, r.dx0, 0);
    }
    this.fullMs = now() - t0;
  };

  // Sends the dirty tiles up, a few rects per rail.
  Core.prototype.upload = function (ctx) {
    var TD = this.TD;
    for (var ri = 0; ri < this.rails.length; ri++) {
      var r = this.rails[ri];
      if (!r.dn) continue;
      if (r.full) {
        r.full = false;
        ctx.putImageData(r.img, r.dx0, 0);
      } else {
        var rowMin = r.rowMin,
          rowMax = r.rowMax,
          tw = r.tw;
        var top = r.th,
          bot = -1,
          j,
          ti,
          ty,
          tx;
        for (j = 0; j < r.dn; j++) {
          ty = (r.dlist[j] / tw) | 0;
          if (ty < top) top = ty;
          if (ty > bot) bot = ty;
        }
        for (var z = top; z <= bot; z++) {
          rowMin[z] = tw;
          rowMax[z] = -1;
        }
        for (j = 0; j < r.dn; j++) {
          ti = r.dlist[j];
          ty = (ti / tw) | 0;
          tx = ti - ty * tw;
          if (tx < rowMin[ty]) rowMin[ty] = tx;
          if (tx > rowMax[ty]) rowMax[ty] = tx;
        }
        // Each row's runs of dirty tiles (a one-tile gap is bridged), grown
        // down into the rects of the rows above while that wastes little.
        var dirty = r.dirty,
          O = this.open;
        var on = 0,
          y,
          k2;
        for (y = top; y <= bot + 1; y++) {
          for (k2 = 0; k2 < on; k2++) O[k2 * 6 + 5] = 0;
          if (y <= bot && rowMax[y] >= 0) {
            var x = rowMin[y],
              xe = rowMax[y],
              row = y * tw;
            while (x <= xe) {
              if (!dirty[row + x]) {
                x++;
                continue;
              }
              var a = x,
                cnt = 0;
              while (x <= xe && (dirty[row + x] || (x + 1 <= xe && dirty[row + x + 1]))) {
                if (dirty[row + x]) cnt++;
                x++;
              }
              var b = x - 1;
              // The open rect above it, if growing it down wastes little.
              var hit = -1;
              for (k2 = 0; k2 < on; k2++) {
                var p = k2 * 6;
                if (O[p + 5] || a > O[p + 1] + 1 || b < O[p] - 1) continue;
                var na = a < O[p] ? a : O[p],
                  nb = b > O[p + 1] ? b : O[p + 1];
                if ((nb - na + 1) * (y - O[p + 2] + 1) <= 1.4 * (O[p + 4] + cnt) + 2) hit = k2;
                break;
              }
              if (hit >= 0) {
                p = hit * 6;
                if (a < O[p]) O[p] = a;
                if (b > O[p + 1]) O[p + 1] = b;
                O[p + 3] = y;
                O[p + 4] += cnt;
                O[p + 5] = 1;
              } else {
                p = on++ * 6;
                O[p] = a;
                O[p + 1] = b;
                O[p + 2] = y;
                O[p + 3] = y;
                O[p + 4] = cnt;
                O[p + 5] = 1;
              }
            }
          }
          // Rects that did not grow this row are done: send them.
          var keep = 0;
          for (k2 = 0; k2 < on; k2++) {
            p = k2 * 6;
            if (O[p + 5] && y <= bot) {
              if (keep !== k2) for (var c = 0; c < 6; c++) O[keep * 6 + c] = O[p + c];
              keep++;
              continue;
            }
            var sx = O[p] * TD,
              sy = O[p + 2] * TD;
            var sw = Math.min(r.bw, (O[p + 1] + 1) * TD) - sx,
              sh = Math.min(r.bh, (O[p + 3] + 1) * TD) - sy;
            if (sw > 0 && sh > 0) ctx.putImageData(r.img, r.dx0, 0, sx, sy, sw, sh);
          }
          on = keep;
        }
      }
      for (j = 0; j < r.dn; j++) r.dirty[r.dlist[j]] = 0;
      r.dn = 0;
    }
  };

  // ── The runner: a canvas, a clock, messages ───────────────────────────────

  function Runner(canvas, opts) {
    opts = opts || {};
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d', { alpha: false });
    this.core = new Core({ half: !!opts.half, reduced: !!opts.reduced });
    this.reduced = !!opts.reduced;
    this.paused = opts.run === false;
    this.dead = false;
    this.pending = null;
    this.rafId = 0;
    this.toId = 0;
    this.last = 0;
    this.hasRaf = typeof G.requestAnimationFrame === 'function';
    this.busyT = new Float32Array(240);
    this.busyN = 0;
    this.idleT = new Float32Array(120);
    this.idleN = 0;
    this.putT = new Float32Array(240);
    this.frames = 0;
    var self = this;
    this._frame = function () {
      self.rafId = 0;
      self.frame();
    };
    this._idle = function () {
      self.toId = 0;
      self.frame();
    };
    if (canvas.addEventListener) {
      canvas.addEventListener('contextrestored', function () {
        self.core.fullDirty = true;
        self.wake();
      });
    }
  }

  Runner.prototype.handle = function (m) {
    if (this.dead) return;
    switch (m.t) {
      case 'layout':
        this.pending = m.L;
        this.wake();
        break;
      case 'p':
        if (!this.reduced && this.core.n) {
          this.core.pointer(m.k, m.x, m.y, m.ts, m.b);
          this.wake();
        }
        break;
      case 'run':
        this.paused = !m.on;
        if (this.paused) this.cancel();
        else {
          this.last = 0;
          this.wake();
        }
        break;
      case 'reduced':
        this.reduced = !!m.v;
        this.core.setReduced(this.reduced);
        this.core.fullDirty = true;
        this.wake();
        break;
      case 'destroy':
        this.dead = true;
        this.cancel();
        break;
    }
  };

  Runner.prototype.cancel = function () {
    if (this.rafId) {
      if (this.hasRaf) G.cancelAnimationFrame(this.rafId);
      else clearTimeout(this.rafId);
      this.rafId = 0;
    }
    if (this.toId) {
      clearTimeout(this.toId);
      this.toId = 0;
    }
  };

  Runner.prototype.wake = function () {
    if (this.paused || this.dead || this.rafId) return;
    if (this.toId) {
      clearTimeout(this.toId);
      this.toId = 0;
    }
    this.rafId = this.hasRaf ? G.requestAnimationFrame(this._frame) : setTimeout(this._frame, 16);
  };

  Runner.prototype.applyLayout = function () {
    if (!this.pending) return;
    var core = this.core,
      ctx = this.ctx;
    var L = this.pending;
    this.pending = null;
    if (core.setLayout(L) === 'rebuilt') {
      this.canvas.width = core.cw;
      this.canvas.height = core.ch;
      ctx.fillStyle = '#09090B';
      ctx.fillRect(0, 0, core.cw, core.ch);
      core.fullDirty = true;
    }
  };

  Runner.prototype.frame = function () {
    if (this.paused || this.dead) return;
    var core = this.core,
      ctx = this.ctx;
    this.applyLayout();
    if (!core.n) return;
    var t0 = now();
    var dt = this.last ? (t0 - this.last) / 1000 : 1 / 60;
    this.last = t0;
    if (this.reduced) {
      if (core.fullDirty) core.render(ctx);
      return;
    }
    var wasBusy = core.busy();
    core.step(dt);
    var t1 = now();
    core.render(ctx);
    var t2 = now();
    this.frames++;
    var ms = t2 - t0;
    if (wasBusy) {
      this.busyT[this.busyN % 240] = ms;
      this.putT[this.busyN % 240] = t2 - t1;
      this.busyN++;
    } else {
      this.idleT[this.idleN % 120] = ms;
      this.idleN++;
    }
    if (core.busy()) this.wake();
    else this.toId = setTimeout(this._idle, IDLE_MS);
  };

  function summary(arr, n) {
    var m = Math.min(n, arr.length);
    if (!m) return { n: 0 };
    var a = Array.prototype.slice.call(arr, 0, m).sort(function (x, y) {
      return x - y;
    });
    var sum = 0;
    for (var i = 0; i < m; i++) sum += a[i];
    return {
      n: n,
      avg: +(sum / m).toFixed(3),
      p50: +a[Math.floor(m * 0.5)].toFixed(3),
      p95: +a[Math.min(m - 1, Math.floor(m * 0.95))].toFixed(3),
      max: +a[m - 1].toFixed(3),
    };
  }

  Runner.prototype.getStats = function () {
    var c = this.core;
    return {
      grains: c.n,
      twinklers: c.twN,
      active: c.activeN,
      scale: c.s,
      grainScale: c.gScale,
      canvas: [c.cw, c.ch],
      railPx: c.rails.map(function (r) {
        return [r.bw, r.bh];
      }),
      buildMs: +c.buildMs.toFixed(2),
      fullDrawMs: +(c.fullMs || 0).toFixed(2),
      busy: summary(this.busyT, this.busyN),
      stepDraw: summary(this.putT, this.busyN),
      idle: summary(this.idleT, this.idleN),
      frames: this.frames,
      mode: c.busy() ? 'busy' : 'idle',
      half: c.half,
    };
  };

  Runner.prototype.resetStats = function () {
    this.busyN = 0;
    this.idleN = 0;
  };

  /**
   * Debug: [o.frames] scripted frames timed back to back, whatever the page's
   * visibility. o.kind: 'stir' (a wavy stroke through the first rail at a
   * mouse's pace), 'hold' (a press held), or 'idle' (twinkle ticks at rest).
   * With o.freeze the field is left as it is and the loop stays stopped
   * (for a screenshot); a later 'run' message starts it again.
   */
  Runner.prototype.bench = function (o) {
    o = o || {};
    var core = this.core,
      ctx = this.ctx;
    this.applyLayout();
    var r = core.rails[0];
    if (!r || this.reduced) return null;
    this.cancel();
    if (core.fullDirty) core.render(ctx);
    var frames = o.frames || 240,
      kind = o.kind || 'stir';
    var dt = kind === 'idle' ? IDLE_MS / 1000 : 1 / 60;
    var H = core.H,
      ts = 0,
      hx = r.x0 + r.w * 0.3,
      hy = H * 0.8;
    var all = new Float32Array(frames),
      steps = new Float32Array(frames),
      most = 0;
    var pts = new Float32Array(frames);
    for (var f = 0; f < frames; f++) {
      var u = f / frames;
      if (kind === 'stir') {
        var x = r.x0 + r.w * (0.12 + 0.6 * (0.5 + 0.5 * Math.sin(u * TAU * 2.3)));
        core.pointer(0, x, H * (0.25 + 0.68 * u), ts, 0);
      } else if (kind === 'hold' && f === 0) {
        core.pointer(0, hx - 20, hy, ts - 30, 0);
        core.pointer(1, hx, hy, ts, 1);
      }
      ts += dt * 1000;
      var t0 = now();
      core.step(dt);
      var t1 = now();
      core.render(ctx);
      var t2 = now();
      all[f] = t2 - t0;
      steps[f] = t1 - t0;
      pts[f] = t2 - t1;
      if (core.activeN > most) most = core.activeN;
    }
    var res = {
      kind: kind,
      grains: core.n,
      scale: core.s,
      frame: summary(all, frames),
      step: summary(steps, frames),
      draw: summary(pts, frames),
      maxActive: most,
    };
    if (!o.freeze) {
      if (kind === 'hold') core.pointer(2, hx, hy, ts, 0);
      core.pointer(3, 0, 0, ts, 0);
      this.last = 0;
      this.wake();
    } else this.paused = true;
    return res;
  };

  G.StarSandCore = { Core: Core, Runner: Runner };

  // ── As a worker ───────────────────────────────────────────────────────────

  var inWorker =
    typeof WorkerGlobalScope !== 'undefined' && G instanceof WorkerGlobalScope;
  if (inWorker) {
    var runner = null;
    G.onmessage = function (e) {
      var m = e.data;
      if (!m) return;
      if (m.t === 'init') {
        runner = new Runner(m.canvas, { reduced: m.reduced, run: m.run });
        if (m.L) runner.handle({ t: 'layout', L: m.L });
        return;
      }
      if (!runner) return;
      if (m.t === 'stats') {
        if (m.reset) runner.resetStats();
        G.postMessage({ t: 'stats', id: m.id, s: runner.getStats() });
        return;
      }
      if (m.t === 'bench') {
        G.postMessage({ t: 'stats', id: m.id, s: runner.bench(m.o) });
        return;
      }
      runner.handle(m);
      if (m.t === 'destroy') G.close();
    };
    G.postMessage({ t: 'hello' });
  }
})(typeof self !== 'undefined' ? self : this);
