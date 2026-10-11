part of 'fusion_particles.dart';

// THE MERGE, IN A STYLE (the Athanor's fusion styles). Up to the stand it is
// the plain merge: the crest, the pair standing as grains, the hold while a
// verdict is waited on and the run back if it fails. Just past the stand
// every grain is the style's; each style's front then runs across the pair
// from the side facing the other, and the whole falls into the orb at the
// end as the plain merge does (2.15–2.5), then goes out in the style's own
// light. Every grain's place is a smooth function of time — nothing random
// from frame to frame — and each material is drawn in layers (a haze, a
// body, fine grains) so it reads as a material, not as dots.
//
//   ink           soaked through, then let go like a drop into still
//                 water: rolling mushroom caps with tendrils trailing, the
//                 caps meeting and marbling, all carried by a curling,
//                 divergence-free flow (InkFlow)
//   frost         fern frost grows across each body from the side facing
//                 the other — a trunk, branches, branchlets, the grains
//                 accreting where the growth reaches them and glittering —
//                 then the two ferns reach for each other and lock into one
//                 crystal mass
//   gilt          each breaks into thin leaves of gold that flutter and
//                 tumble, flashing light and dark as they turn, lifted on a
//                 slow vortex into one leaf-storm of both
//   ember         each catches from the side facing the other and burns:
//                 every grain a parcel of flame rising on its own buoyancy
//                 through a quick curling flow, cooling white, yellow,
//                 orange, red, to ash; sparks spiralling up and dying; the
//                 two fires lean in and merge into one blaze over the orb
//   distillation  each thins to steam that rises on a slow flow and beads
//                 into drops under the glass above the orb; each drop
//                 swells, necks and falls, and its landing ripples the pool

/// The drops a distillation condenses into.
const int _kDrops = 30;

int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

extension _StyledMerge on FusionParticleField {
  void _seedStyle() {
    final st = style!;
    final n = length;
    _matAt = Float32List(n);
    _sa = Float32List(n);
    _sb = Float32List(n);
    _fx = Float32List(n);
    _fy = Float32List(n);
    _gx = Float32List(n);
    _gy = Float32List(n);
    _ex = Float32List(n);
    _ey = Float32List(n);
    _hx = Float32List(n);
    _hy = Float32List(n);
    _look = Uint8List(n);
    _grp = Uint8List(n);
    _grpT = Float32List(_kDrops * 4);
    _matTones = [for (final g in _specimens) fusionStyleTones(st, g.tones)];
    // Each specimen's reach along its way to the orb, and across it.
    final pMin = [double.infinity, double.infinity];
    final pMax = [double.negativeInfinity, double.negativeInfinity];
    final lMax = [1.0, 1.0];
    for (var i = 0; i < n; i++) {
      // Taken over just past the stand (so the few grains the plain merge
      // would send off early never fly off and come back).
      _matAt[i] = FusionParticleField.standTime + 0.0001;
      _sa[i] = fsHash(i, 101);
      _sb[i] = fsHash(i, 102);
      final s = _side[i];
      final p = _relX[i] * _dirX[s] + _relY[i] * _dirY[s];
      final l = _relX[i] * _perpX[s] + _relY[i] * _perpY[s];
      pMin[s] = math.min(pMin[s], p);
      pMax[s] = math.max(pMax[s], p);
      lMax[s] = math.max(lMax[s], l.abs());
    }
    for (var s = 0; s < 2; s++) {
      _inkAlong[s * 2] = pMin[s].isFinite ? pMin[s] : 0;
      _inkAlong[s * 2 + 1] = pMax[s].isFinite ? pMax[s] : 0;
      _inkAlong[4 + s] = lMax[s];
    }
    var reach = 0.0;
    for (var s = 0; s < 2; s++) {
      reach = math.max(reach, (_centres[s] - core).distance - _inkAlong[s * 2]);
    }
    switch (st) {
      case FusionStyle.ink:
        for (var i = 0; i < n; i++) {
          final s = _side[i];
          final l = _relX[i] * _perpX[s] + _relY[i] * _perpY[s];
          // Its order of leaving (nearest the orb first), where it lies
          // across the way, its place in the cap (how far out on the
          // rolled sheet, and where on it) or in the stem (which tendril,
          // and where across it).
          _gy[i] = 1 - _near[i];
          _gx[i] = (l / lMax[s]).clamp(-1.0, 1.0);
          _fx[i] = 0.1 + 0.9 * math.sqrt(_sa[i]);
          _fy[i] = _sb[i] - 0.5;
          _grp[i] = math.min(3, (fsHash(i, 107) * 4).floor());
        }
        _flow = InkFlow(
          halfWidth: reach + coreRadius,
          halfHeight: math.max(reach * 0.6, coreRadius * 3),
          scale: coreRadius * 1.15,
        );
      case FusionStyle.frost:
        _seedFrost(pMin, pMax);
      case FusionStyle.gilt:
        _seedGilt();
        _flow = InkFlow(
          halfWidth: reach + coreRadius,
          halfHeight: math.max(reach * 0.6, coreRadius * 3),
          scale: coreRadius * 1.3,
        );
      case FusionStyle.ember:
        for (var i = 0; i < n; i++) {
          final q = 1 - _near[i];
          final spark = fsHash(i, 301) < 0.07;
          // When it catches (from the side facing the other), how long it
          // burns, and how high its flame carries it.
          _fx[i] = 0.68 + 1.05 * q;
          _fy[i] = (0.45 + 0.3 * _sa[i]) * (spark ? 1.7 : 1);
          _gx[i] = coreRadius * (0.9 + 0.8 * _sb[i]) * (spark ? 2.0 : 1);
          _grp[i] = spark ? 1 : 0;
        }
        _flow = InkFlow(
          halfWidth: reach + coreRadius,
          halfHeight: math.max(reach * 0.7, coreRadius * 3.4),
          scale: coreRadius * 0.55,
          nx: 48,
          ny: 32,
        );
      case FusionStyle.distillation:
        _seedDistillation();
        _flow = InkFlow(
          halfWidth: reach + coreRadius,
          halfHeight: math.max(reach * 0.7, coreRadius * 3.4),
          scale: coreRadius * 0.9,
          nx: 44,
          ny: 30,
        );
    }
  }

  // ── frost ───────────────────────────────────────────────────────────────

  /// Frost over each body, grown from the side facing the other: a fan of
  /// feathered rays from where it first touched — each ray a spine with
  /// branchlets off both sides, the rays and their angles uneven, as frost
  /// on glass grows. Each grain takes the nearest place on it ([_gx],
  /// [_gy], along/across from the near edge) and is reached by the growth
  /// at [_fy] — the farther along, the later.
  void _seedFrost(List<double> pMin, List<double> pMax) {
    const rays = 9;
    final path = Float32List(length);
    final pathMax = [1.0, 1.0];
    final angles = [
      for (var s = 0; s < 2; s++)
        [
          for (var j = 0; j < rays; j++)
            (-78 +
                    156 * (j + 0.5) / rays +
                    (fsHash(j + s * 17, 141) - 0.5) * 9) *
                math.pi /
                180,
        ],
    ];
    for (var i = 0; i < length; i++) {
      final s = _side[i];
      final p = _relX[i] * _dirX[s] + _relY[i] * _dirY[s];
      final l = _relX[i] * _perpX[s] + _relY[i] * _perpY[s];
      // From where the frost first touched: the near edge, across the middle.
      final u = pMax[s] - p;
      final phi = math.atan2(l, math.max(u, 1e-3));
      var best = 0;
      for (var j = 1; j < rays; j++) {
        if ((phi - angles[s][j]).abs() < (phi - angles[s][best]).abs()) {
          best = j;
        }
      }
      final th = angles[s][best];
      final e1u = math.cos(th), e1l = math.sin(th);
      final e2u = -e1l, e2l = e1u;
      final along = math.max(0.0, u * e1u + l * e1l);
      final w = u * e2u + l * e2l;
      final h = fsHash(i, 108);
      // Light from the upper left: a part pointing toward it is lit.
      double lit(double du, double dl) {
        final wx = -_dirX[s] * du + _perpX[s] * dl;
        final wy = -_dirY[s] * du + _perpY[s] * dl;
        return wx * -0.55 + wy * -0.835;
      }

      double tu, tl, len;
      int tone;
      if (h < 0.3) {
        // The spine, a little thick.
        final thick = (fsHash(i, 109) - 0.5) * _grainD[s] * 1.6;
        tu = e1u * along + e2u * thick;
        tl = e1l * along + e2l * thick;
        len = along;
        tone = lit(e1u, e1l) > 0.2 ? 4 : 3;
      } else {
        // A branchlet off it, at its own slant.
        final beta = (52 + 14 * fsHash(best + s * 17, 143)) * math.pi / 180;
        final cb = math.cos(beta), sb = math.sin(beta);
        final ws = w >= 0 ? 1.0 : -1.0;
        final d2 = _grainD[s] * (2.6 + 1.4 * fsHash(best + s * 17, 144));
        final j = ((along - w.abs() * cb / sb) / d2).round();
        final sj = math.max(0.0, j * d2);
        final du = e1u * cb + e2u * ws * sb;
        final dl = e1l * cb + e2l * ws * sb;
        final bl = math.min(w.abs() / sb, d2 * 3.5);
        tu = e1u * sj + du * bl;
        tl = e1l * sj + dl * bl;
        len = sj + bl;
        final lt = lit(du, dl);
        tone = lt > 0.3 ? 4 : (lt < -0.3 ? 1 : 2);
      }
      _gx[i] = tu;
      _gy[i] = tl;
      _grp[i] = tone;
      path[i] = len;
      pathMax[s] = math.max(pathMax[s], len);
    }
    for (var i = 0; i < length; i++) {
      _fy[i] = 0.68 + 0.6 * path[i] / pathMax[_side[i]];
    }
  }

  // ── gilt ────────────────────────────────────────────────────────────────

  /// Leaves of gold: each body cut into small leaves (a few grains each,
  /// those that lay together). Per grain: its place in its leaf ([_gx],
  /// [_gy]), its leaf's place on the body ([_ex], [_ey]), its leaf's turn
  /// in leaving ([_fx]); the leaf's own two seeds in [_sa], [_sb].
  void _seedGilt() {
    final cells = <int, int>{};
    final sumX = <double>[], sumY = <double>[], sumN = <double>[];
    final cnt = <int>[];
    final leaf = Int32List(length);
    for (var i = 0; i < length; i++) {
      final s = _side[i];
      final cell = _grainD[s] / 1.28 * 4.4;
      final cx = (_relX[i] / cell).floor(), cy = (_relY[i] / cell).floor();
      final key = (s << 24) ^ ((cx & 0xFFF) << 12) ^ (cy & 0xFFF);
      final f = cells.putIfAbsent(key, () {
        sumX.add(0);
        sumY.add(0);
        sumN.add(0);
        cnt.add(0);
        return cnt.length - 1;
      });
      leaf[i] = f;
      sumX[f] += _relX[i];
      sumY[f] += _relY[i];
      sumN[f] += _near[i];
      cnt[f]++;
    }
    for (var i = 0; i < length; i++) {
      final f = leaf[i];
      final c = cnt[f];
      final mx = sumX[f] / c, my = sumY[f] / c;
      _ex[i] = mx;
      _ey[i] = my;
      _gx[i] = _relX[i] - mx;
      _gy[i] = _relY[i] - my;
      _fx[i] = 1 - sumN[f] / c;
      _sa[i] = fsHash(f, 201);
      _sb[i] = fsHash(f, 202);
      // Its place along the leaf and across it, the leaf drawn out and
      // narrowed along its own grain.
      final alpha = _sb[i] * math.pi;
      final ca = math.cos(alpha), sa = math.sin(alpha);
      final len = 0.85 + 0.55 * _sa[i];
      _hx[i] = (_gx[i] * ca + _gy[i] * sa) * len * 1.25;
      _hy[i] = (-_gx[i] * sa + _gy[i] * ca) * len * 0.38;
    }
  }

  // ── distillation ────────────────────────────────────────────────────────

  /// Drops: grains that left together bead together, the first to leave
  /// the first to fall. Per drop ([_grpT]): when it starts to bead, when it
  /// necks, when it lets go, when it lands. Per grain: when its steam
  /// rises ([_fy]), when it reaches its drop ([_fx]), its place in the bead
  /// ([_gx], [_gy], unit disc) and in the pool ([_ex], [_ey]).
  void _seedDistillation() {
    // In the order the steam leaves, nearest the orb first; each drop of
    // one specimen's water, the two taking turns.
    final orders = [
      for (var side = 0; side < 2; side++)
        [
          for (var i = 0; i < length; i++)
            if (_side[i] == side) i,
        ]..sort((a, b) => _near[b].compareTo(_near[a])),
    ];
    final order = <int>[];
    for (var d = 0; d < _kDrops; d++) {
      final side = d % 2;
      final list = orders[side];
      final per0 = (list.length / (_kDrops / 2)).ceil();
      final from = (d ~/ 2) * per0;
      for (var k = from; k < math.min(list.length, from + per0); k++) {
        order.add(list[k]);
      }
    }
    final per = math.max(1, (order.length / _kDrops).ceil());
    double beadAt(int d) =>
        1.15 + 0.3 * d / (_kDrops - 1) + 0.03 * fsHash(d, 4);
    for (var r = 0; r < order.length; r++) {
      final i = order[r];
      final d = math.min(_kDrops - 1, r ~/ per);
      final within = (r - d * per) / per;
      _grp[i] = d;
      _fx[i] = beadAt(d) + 0.2 * within;
    }
    for (var d = 0; d < _kDrops; d++) {
      final g0 = beadAt(d);
      final neck = g0 + 0.24;
      final go = neck + 0.1;
      _grpT[d * 4] = g0;
      _grpT[d * 4 + 1] = neck;
      _grpT[d * 4 + 2] = go;
      _grpT[d * 4 + 3] = go + 0.36;
    }
    for (var i = 0; i < length; i++) {
      // The steam leaves nearest the orb first, and takes its time rising.
      _fy[i] = 0.64 + 0.22 * (1 - _near[i]);
      _fx[i] = math.max(_fx[i], _fy[i] + 0.5);
      final ra = fsHash(i, 122) * math.pi * 2;
      final rr = math.sqrt(fsHash(i, 123));
      _gx[i] = math.cos(ra) * rr;
      _gy[i] = math.sin(ra) * rr;
      final pa = fsHash(i, 121) * math.pi * 2;
      final pr = math.sqrt(fsHash(i, 120));
      _ex[i] = math.cos(pa) * pr;
      _ey[i] = math.sin(pa) * pr;
    }
  }

  /// Where a drop beads under the glass, from the orb (in its radii).
  Offset _dropAt(int d) =>
      Offset((fsHash(d, 1) - 0.5) * 2.3, -1.45 + (fsHash(d, 2) - 0.5) * 0.25);

  /// Where styled grain [i] is at [t], having stood at ([rx], [ry]).
  void _placeStyled(int i, double t, double clock, double rx, double ry) {
    final s = _side[i];
    final cx = _centres[s].dx + shift[s].dx;
    final cy = _centres[s].dy + shift[s].dy;
    switch (style!) {
      case FusionStyle.ink:
        _placeInk(i, t, rx, ry, cx, cy);
      case FusionStyle.frost:
        _prepareFrame(t);
        _placeFrost(i, t, rx, ry, cx, cy);
      case FusionStyle.gilt:
        _prepareFrame(t);
        _placeGilt(i, t, clock, rx, ry, cx, cy);
      case FusionStyle.ember:
        _prepareFrame(t);
        _placeEmber(i, t, rx, ry, cx, cy);
      case FusionStyle.distillation:
        _prepareFrame(t);
        _placeDistillation(i, t, rx, ry);
    }
  }

  /// Into the orb at the end, as the plain merge goes; then stored.
  void _land(
    int i,
    double t,
    double x,
    double y,
    double depth,
    int mode,
    int look,
  ) {
    final c = FusionParticleField._interval(
      t,
      FusionParticleField._collapseStart,
      FusionParticleField._collapseEnd,
    );
    if (c > 0) {
      final k = 1 - 0.94 * c * c * c;
      x = core.dx + (x - core.dx) * k;
      y = core.dy + (y - core.dy) * k;
    }
    _x[i] = x;
    _y[i] = y;
    _depth[i] = depth;
    _mode[i] = mode;
    _look[i] = look;
  }

  /// What every grain of a style shares this frame.
  void _prepareFrame(double t) {
    if (t == _inkFrameT) return;
    _inkFrameT = t;
    final r = coreRadius;
    switch (style!) {
      case FusionStyle.ink:
        break;
      case FusionStyle.frost:
        final fuse = fsSmooth(1.6, 2.15, t);
        _inkFrame[0] = fsSmooth(1.0, 1.8, t);
        _inkFrame[1] = fuse;
        _inkFrame[2] = math.cos(0.32 * fuse);
        _inkFrame[3] = math.sin(0.32 * fuse);
        for (var side = 0; side < 2; side++) {
          final c = _centres[side] + shift[side];
          _inkFrame[4 + side] =
              (core.dx - c.dx) * _dirX[side] + (core.dy - c.dy) * _dirY[side];
        }
      case FusionStyle.gilt:
        _inkFrame[0] = 1 - 0.3 * fsSmooth(1.3, 2.1, t);
        _inkFrame[1] = fsSmooth(1.85, 2.15, t);
        _flow!.prepare(t * 0.8);
      case FusionStyle.ember:
        _inkFrame[0] = 0.8 * fsSmooth(0.95, 1.95, t);
        _flow!.prepare(t * 2.4);
      case FusionStyle.distillation:
        _flow!.prepare(t * 0.6);
        // The pool's surface: each landed drop's ring running out from
        // where it landed, sampled across the pool's width.
        _ripple.fillRange(0, _ripple.length, 0);
        final nb = _ripple.length;
        for (var d = 0; d < _kDrops; d++) {
          final tau = t - _grpT[d * 4 + 3];
          if (tau < 0 || tau > 1.3) continue;
          final xl = _dropAt(d).dx * 0.85;
          final amp = r * 0.075 * math.exp(-2.6 * tau) * fsSmooth(0, 0.06, tau);
          final front = 1.25 * tau;
          for (var b = 0; b < nb; b++) {
            final xb = -1.1 + 2.2 * b / (nb - 1);
            final dist = (xb - xl).abs();
            final g = (dist - front) / 0.2;
            if (g.abs() > 3) continue;
            _ripple[b] +=
                -amp * math.exp(-g * g) * math.cos(dist / 0.08 - tau * 13);
          }
        }
    }
  }

  // ── frost ───────────────────────────────────────────────────────────────

  void _placeFrost(
    int i,
    double t,
    double rx,
    double ry,
    double cx,
    double cy,
  ) {
    final s = _side[i];
    final at = _fy[i];
    final k = fsEaseInOut(fsClamp01((t - at) / 0.25));
    // Its place on the fern, and the fern reaching for the other: the end
    // nearest it grows out farthest, the far end stays.
    final pMin = _inkAlong[s * 2], pMax = _inkAlong[s * 2 + 1];
    final span = math.max(1.0, pMax - pMin);
    final tu = _gx[i], tl = _gy[i];
    final reach = _inkFrame[0];
    final f = 1 - fsClamp01(tu / span);
    final along = pMax - tu + reach * (_inkFrame[4 + s] - pMax) * f;
    final lat = tl * (1 - 0.35 * reach * f);
    // Measured from where it stood, so the hand-over at the stand is exact.
    final ox = _relX[i], oy = _relY[i];
    final fx = _dirX[s] * along + _perpX[s] * lat;
    final fy = _dirY[s] * along + _perpY[s] * lat;
    var x = rx + (fx - ox) * k, y = ry + (fy - oy) * k;
    // The two lock into one mass: drawn together, turned into each other.
    final fuse = _inkFrame[1];
    if (fuse > 0) {
      final dx = x - core.dx, dy = y - core.dy;
      final c = _inkFrame[2], sn = (s == 0 ? 1.0 : -1.0) * _inkFrame[3];
      final pull = 1 - 0.5 * fuse;
      x = core.dx + (dx * c - dy * sn) * pull;
      y = core.dy + (dx * sn + dy * c) * pull;
    }
    var look = 0;
    if (t >= at) {
      // Fresh where it has just grown; glittering where light runs over
      // the crust (a slow band, the same for every grain it crosses).
      final fresh = t - at < 0.16;
      final band = (x * 0.045 + y * 0.031 - t * 0.6 + _sa[i] * 0.3) % 1.0;
      look = fresh ? 6 : (band < 0.03 && _grp[i] >= 3 ? 7 : 1 + _grp[i]);
    }
    _land(i, t, x, y, 1, k > 0 ? 2 : 1, look);
  }

  // ── gilt ────────────────────────────────────────────────────────────────

  void _placeGilt(
    int i,
    double t,
    double clock,
    double rx,
    double ry,
    double cx,
    double cy,
  ) {
    final r = coreRadius;
    final q = _fx[i];
    final ha = _sa[i], hb = _sb[i];
    final turnAt = 0.66 + 0.3 * q;
    final launch = 0.86 + 0.55 * q;
    final k = fsSmooth(turnAt, turnAt + 0.3, t);
    final settle = _inkFrame[1];
    // The leaf tumbles (turning about its own long axis, so it narrows to
    // its edge and opens again) and spins slowly in its plane.
    final lifted = fsSmooth(launch - 0.15, launch + 0.3, t);
    final since = math.max(0.0, t - launch + 0.15) * lifted;
    final tumble = (ha * math.pi * 2 + (3 + 4 * hb) * since) * (1 - settle);
    final spin = (ha - 0.5) * 2.4 * since;
    final face = math.cos(tumble);
    // A thin leaf of its own length, laid along its own grain: the cell it
    // was cut from, drawn out and narrowed.
    final lx = _hx[i] * face, ly = _hy[i];
    final ca = math.cos(hb * math.pi + spin),
        sa = math.sin(hb * math.pi + spin);
    final cs = ca, sn = sa;
    final ox = _gx[i] + (lx * cs - ly * sn - _gx[i]) * k;
    final oy = _gy[i] + (lx * sn + ly * cs - _gy[i]) * k;
    // The leaf itself: on the body, then lifted onto the vortex.
    var lfx = _ex[i], lfy = _ey[i];
    var depth = 1.0;
    final w = fsEaseInOut(fsClamp01((t - launch) / 0.7));
    if (w > 0) {
      final rho0 = r * (0.55 + 1.05 * ((ha * 7.31) % 1.0));
      final rho = rho0 * _inkFrame[0];
      final om = 1.5 / (0.5 + (rho0 / r) * (rho0 / r));
      final th = hb * math.pi * 2 + om * (t - launch);
      final ph = (2.2 + 1.5 * ((hb * 5.17) % 1.0)) * clock + ha * 6;
      var vx = core.dx + rho * math.cos(th) + r * 0.1 * math.sin(ph);
      // A storm, not a ring: each leaf at a height of its own.
      var vy =
          core.dy -
          r * 0.15 +
          rho * math.sin(th) * 0.34 +
          (((ha * 3.7) % 1.0) - 0.5) * r * 1.1 * _inkFrame[0] +
          r * 0.05 * (1 - math.cos(2 * ph));
      // The air carries it on its curls.
      final flow = _flow!;
      flow.sample(vx - core.dx, vy - core.dy);
      vx += r * 0.28 * w * flow.vx;
      vy += r * 0.28 * w * flow.vy;
      // Laid on the orb at the end: drawn onto its face, lying flat.
      if (settle > 0) {
        final dx = vx - core.dx, dy = vy - core.dy;
        final dl = math.max(math.sqrt(dx * dx + dy * dy), r * 0.5);
        vx += (core.dx + dx / dl * r * 0.7 - vx) * settle;
        vy += (core.dy + dy / dl * r * 0.7 - vy) * settle;
      }
      final standX = cx + _ex[i], standY = cy + _ey[i];
      lfx = _ex[i] + (vx - standX) * w;
      lfy = _ey[i] + (vy - standY) * w;
      if (w > 0.6) depth = math.sin(th) < -0.2 && settle < 0.5 ? -1 : 1;
    }
    final x = rx + (lfx + ox) - (_ex[i] + _gx[i]);
    final y = ry + (lfy + oy) - (_ey[i] + _gy[i]);
    var look = 0;
    if (t >= turnAt) {
      // Two-toned foil: the gold face bright, its back old gold, a flash
      // as it turns full to the light.
      final f = face.abs();
      look = face >= 0
          ? (f > 0.996 ? 7 : 4 + (f > 0.94 ? 2 : (f > 0.6 ? 1 : 0)))
          : 3 - (f > 0.7 ? 2 : (f > 0.35 ? 1 : 0));
    }
    _land(i, t, x, y, depth, w > 0 ? 2 : 1, look);
  }

  // ── ember ───────────────────────────────────────────────────────────────

  void _placeEmber(
    int i,
    double t,
    double rx,
    double ry,
    double cx,
    double cy,
  ) {
    final r = coreRadius;
    final ig = _fx[i], life = _fy[i], hMax = _gx[i];
    final spark = _grp[i] == 1;
    // What is left to burn draws toward the other as it burns, and in on
    // itself.
    final sl = _inkFrame[0];
    final tx = (core.dx - cx) * sl - _relX[i] * 0.3 * sl;
    final ty = (core.dy - cy) * sl - _relY[i] * 0.3 * sl;
    final a = (t - ig) / life;
    if (a <= 0) {
      _land(i, t, rx + tx, ry + ty, 1, 1, 0);
      return;
    }
    // Caught: a parcel of flame from where it was when it caught, rising
    // on its own buoyancy (from rest, quickening), then as ash, slowing.
    final sli = 0.8 * fsSmooth(0.95, 1.95, ig);
    final bx = rx + (core.dx - cx) * sli - _relX[i] * 0.3 * sli;
    final by = ry + (core.dy - cy) * sli - _relY[i] * 0.3 * sli;
    final top = hMax * (1 - 0.3 * fsSmooth(1.15, 1.8, ig));
    final h = a <= 1
        ? top * a * a * (2 - a)
        : top * (1 + 0.35 * (1 - math.exp(-(a - 1) / 0.35)));
    final rise = math.min(1.0, h / top);
    // The later it caught, the more its flame leans into the other's.
    final joined = fsSmooth(1.15, 1.8, ig);
    var x = bx + (core.dx - bx) * (0.32 + 0.45 * joined) * rise;
    var y = by - h;
    if (spark) {
      x += math.sin(a * 7 + _sb[i] * 6) * r * 0.3 * math.min(a, 1.4);
    }
    // Torn and re-formed by a quick curling flow, more the higher it is.
    final flow = _flow!;
    final eps = r * (0.08 * fsSmooth(0, 0.15, a) + 0.3 * rise);
    for (var step = 0; step < 2; step++) {
      flow.sample(x - core.dx, y - core.dy);
      x += eps * flow.vx;
      y += eps * flow.vy * 0.7;
    }
    // The blaze falls in on itself at the end: all of it drawn down into
    // the coal it leaves.
    final gather = fsSmooth(1.9, 2.25, t);
    if (gather > 0) {
      x = core.dx + (x - core.dx) * (1 - 0.6 * gather);
      y = core.dy + (y - core.dy) * (1 - 0.6 * gather);
    }
    // Cooling as it rises: white, yellow, orange, red, dark red, ash.
    final cool = spark ? a * 0.75 : a;
    var tone = cool < 0.1
        ? 5
        : (cool < 0.25
              ? 4
              : (cool < 0.45 ? 3 : (cool < 0.7 ? 2 : (cool < 1 ? 1 : 0))));
    // Gathered into the coal, it glows again.
    if (gather > 0.3) {
      final dx = (x - core.dx) / r, dy = (y - core.dy) / r;
      final dd = dx * dx + dy * dy;
      final coal = dd < 0.12 ? 4 : (dd < 0.4 ? 3 : (dd < 0.9 ? 2 : 0));
      if (gather > 0.3 + 0.4 * math.min(1.0, dd)) tone = math.max(tone, coal);
    }
    _land(i, t, x, y, 1, 2, 1 + tone);
  }

  // ── distillation ────────────────────────────────────────────────────────

  void _placeDistillation(int i, double t, double rx, double ry) {
    final r = coreRadius;
    final d = _grp[i];
    final g0 = _grpT[d * 4], neck = _grpT[d * 4 + 1];
    final go = _grpT[d * 4 + 2], land = _grpT[d * 4 + 3];
    final steamAt = _fy[i], arrive = _fx[i];
    if (t < steamAt) {
      _land(i, t, rx, ry, 1, 1, 0);
      return;
    }
    final drop = _dropAt(d);
    final dropX = core.dx + drop.dx * r, dropY = core.dy + drop.dy * r;
    final rMax = r * 0.16 * (0.65 + 0.7 * fsHash(d, 5));
    double x, y;
    int tone;
    if (t < arrive) {
      // Steam, rising off it on a slow flow, bowing up as it goes, into
      // the bead forming under the glass.
      final k = fsSmooth(steamAt, arrive, t);
      final lift = math.sin(math.pi * k);
      x = rx + (dropX - rx) * k;
      y = ry + (dropY - ry) * k - r * 0.45 * lift;
      final flow = _flow!;
      final eps = r * 0.2 * lift;
      for (var step = 0; step < 2; step++) {
        flow.sample(x - core.dx, y - core.dy);
        x += eps * flow.vx;
        y += eps * flow.vy;
      }
      tone = k < 0.3 ? 0 : (k < 0.7 ? 1 : 2);
    } else if (t < land) {
      // The bead: swelling as the steam comes in, then necking — the top
      // drawn thin, the body heavy — then let go, falling, its shape
      // ringing back to round.
      final grow = math.sqrt(fsSmooth(g0, neck, t));
      final j = fsSmooth(arrive, arrive + 0.12, t);
      final ox = _gx[i], oy = _gy[i];
      double lx, ly, cyy = dropY, rr = rMax * math.max(grow, 0.25);
      if (t < go) {
        final nk = fsSmooth(neck, go, t);
        lx = ox * (1 - 0.45 * nk * math.max(0.0, -oy));
        ly = oy * (1 + 0.8 * nk) + 0.5 * nk;
      } else {
        final tau = t - go;
        final fall = land - go;
        final g = 2 * (core.dy + r * 0.2 - dropY) / (fall * fall);
        cyy = dropY + 0.5 * g * tau * tau;
        final ring = math.exp(-5 * tau);
        lx = ox * (1 - 0.45 * math.exp(-8 * tau) * math.max(0.0, -oy));
        ly = oy * (1 + 0.8 * ring * math.cos(16 * tau)) + 0.5 * ring;
        rr = rMax;
      }
      x = dropX + lx * rr * j;
      y = cyy + ly * rr * j;
      tone = fsDropTone(ox, oy);
    } else {
      // In the pool: spreading into its place, rocked by the rings.
      final tau = t - land;
      final m = fsEaseInOut(fsClamp01(tau / 0.3));
      final fallG =
          2 * (core.dy + r * 0.2 - dropY) / ((land - go) * (land - go));
      final endY = dropY + 0.5 * fallG * (land - go) * (land - go);
      final px = core.dx + _ex[i] * r * 0.85;
      final b = ((_ex[i] * 0.85 + 1.1) / 2.2 * (_ripple.length - 1)).round();
      final wave = _ripple[_clampInt(b, 0, _ripple.length - 1)];
      final py = core.dy + r * 0.2 + _ey[i] * r * 0.2 + wave;
      final lx = _gx[i] * rMax, ly = _gy[i] * rMax;
      x = dropX + lx + (px - dropX - lx) * m;
      y = endY + ly + (py - endY - ly) * m;
      // The far surface catches the light where a ring lifts it.
      tone = _ey[i] < -0.55 && wave < -r * 0.03 ? 5 : (_ey[i] < -0.2 ? 4 : 3);
    }
    _land(i, t, x, y, 1, 2, 1 + tone);
  }

  /// Where ink grain [i] is at [t], having stood at ([rx], [ry]) in the
  /// specimen standing at ([cx], [cy]).
  void _placeInk(int i, double t, double rx, double ry, double cx, double cy) {
    final s = _side[i];
    final r = coreRadius;
    final q = _gy[i];
    // What the whole side shares this frame.
    if (t != _inkFrameT) {
      _inkFrameT = t;
      final prog = fsClamp01((t - 0.86) / 0.85);
      final meet = fsSmooth(1.45, 2.05, t);
      final drain = fsSmooth(1.0, 1.95, t);
      for (var side = 0; side < 2; side++) {
        final c = _centres[side] + shift[side];
        final reach =
            (core.dx - c.dx) * _dirX[side] + (core.dy - c.dy) * _dirY[side];
        final pMin = _inkAlong[side * 2], pMax = _inkAlong[side * 2 + 1];
        // The cap rolls out toward the orb, slowing as a ring of ink
        // does, and spreads where it meets the other.
        final head = pMax + (reach - pMax) * (1 - math.pow(1 - prog, 2.2));
        final a = r * 0.55 * (0.65 + 0.35 * prog) * (1 + 0.7 * meet);
        final capBack = head - 1.0 * a;
        _inkFrame[side * 3] = head;
        _inkFrame[side * 3 + 1] = a;
        _inkFrame[side * 3 + 2] = pMin + (capBack - pMin) * drain;
      }
      _inkFrame[6] = fsSmooth(1.45, 2.3, t);
      _flow!.prepare(t);
    }
    // Soaked through by a front running across it from the orb's side, it
    // darkens, softens and sinks a little where it stands.
    final inkAt = 0.66 + 0.34 * q;
    final k = fsSmooth(inkAt, inkAt + 0.4, t);
    var px = rx, py = ry + r * 0.1 * k * (0.4 + 0.6 * _sa[i]);
    var tone = 1;
    // Let go, nearest the orb first.
    final emit = 0.86 + 0.48 * q;
    final w = fsEaseInOut(fsClamp01((t - emit) / 0.45));
    if (w > 0) {
      final dx = _dirX[s], dy = _dirY[s], nx = _perpX[s], ny = _perpY[s];
      final head = _inkFrame[s * 3], a = _inkFrame[s * 3 + 1];
      double along, lat;
      if (q < 0.38) {
        // The cap: two round lobes (one each side of the way), each
        // rolling up its own sheet, the inside turning fastest, so bands
        // of it wind into spirals.
        final sigma = _gx[i] >= 0 ? 1.0 : -1.0;
        final rn = _fx[i];
        final rho = a * 0.95 * rn;
        final om = 5.0 / (0.35 + 1.6 * rn * rn);
        final phi =
            sigma * (math.pi / 2 + _fy[i] * math.pi * 1.7) +
            sigma * om * math.max(0.0, t - emit);
        final c = math.cos(phi), sn = math.sin(phi);
        along = head - 0.3 * a + rho * c;
        lat = sigma * a * 0.92 + rho * sn;
        // Thick in the roll, thinner out along the sheet; bands of the
        // sheet a shade apart, so the winding shows; light from the upper
        // left on the outside of it.
        final band = ((_fy[i] + 0.5) * 4).floor().isEven ? 0 : 1;
        final lit =
            c * (dx * -0.55 + dy * -0.835) + sn * (nx * -0.55 + ny * -0.835);
        tone = rn > 0.93 && lit > 0.9 && band == 0
            ? 5
            : _clampInt((rn * 3.2).floor() + band - 1, 0, 3);
      } else {
        // The stem: tendrils trailing back to where it stood, thinning,
        // swaying, drawn on into the cap as the last of it leaves.
        final v = (q - 0.38) / 0.62;
        final capBack = head - 1.0 * a;
        final tail = _inkFrame[s * 3 + 2];
        along = capBack + (tail - capBack) * v;
        final f = _grp[i];
        const lanes = [-0.62, -0.2, 0.24, 0.66];
        final local = _fy[i] * 0.24;
        final half = a * (0.8 - 0.45 * v);
        lat =
            (lanes[f] + local) * half +
            a * 0.28 * v * math.sin(v * 6.5 - t * 1.6 + f * 1.7 + s * 2.3) +
            a * 0.08 * math.sin(v * 13 + t * 1.1 + f);
        // Thin, and its own color, only while the stem is long; drawn in
        // it thickens again.
        final long = fsSmooth(0.6, 1.6, (capBack - tail) / a);
        tone = v > 0.72 && long > 0.5
            ? 4
            : (local.abs() < 0.07 ? 1 : (long > 0.5 ? 3 : 2));
      }
      final jx = cx + dx * along + nx * lat;
      final jy = cy + dy * along + ny * lat;
      px += (jx - px) * w;
      py += (jy - py) * w;
      if (w < 0.5) tone = 1;
    }
    // The two marble into each other: a slow shear round the orb, fastest
    // near it, drawing them together.
    final m = _inkFrame[6];
    if (m > 0) {
      final ox = px - core.dx, oy = py - core.dy;
      final dd = (ox * ox + oy * oy) / (r * r * 2.0);
      final beta = m * 1.4 / (0.6 + dd);
      final cb = math.cos(beta), sb = math.sin(beta);
      final pull = 1 - 0.22 * m;
      px = core.dx + (ox * cb - oy * sb) * pull;
      py = core.dy + (ox * sb + oy * cb) * pull;
    }
    // And the water carries all of it along its curls.
    final flow = _flow!;
    final eps = r * (0.08 * k + 0.12 * w + 0.07 * m);
    for (var step = 0; step < 2; step++) {
      flow.sample(px - core.dx, py - core.dy);
      px += eps * flow.vx;
      py += eps * flow.vy;
    }
    // Into the orb at the end, as the plain merge goes.
    final c = FusionParticleField._interval(
      t,
      FusionParticleField._collapseStart,
      FusionParticleField._collapseEnd,
    );
    if (c > 0) {
      final kk = 1 - 0.94 * c * c * c;
      px = core.dx + (px - core.dx) * kk;
      py = core.dy + (py - core.dy) * kk;
    }
    _x[i] = px;
    _y[i] = py;
    _depth[i] = 1;
    _mode[i] = w > 0 ? 2 : 1;
    _look[i] = t < inkAt ? 0 : 1 + tone;
  }

  static final ui.Shader _waterLight = ui.Gradient.radial(
    Offset.zero,
    1,
    const [
      Color(0xFF9CA4C8),
      Color(0x669CA4C8),
      Color(0x149CA4C8),
      Color(0x009CA4C8),
    ],
    const [0.0, 0.35, 0.72, 1.0],
  );

  /// Each ink tone in three layers — a haze, a body, fine grains — so the
  /// plume reads as one fluid: the thick tones darker than the light in the
  /// water (the ink's shadow), the thin ones their own color.
  void _drawInkLayers(
    Canvas canvas,
    GrainBatch b,
    double Function(int side) grain,
    double toLight,
  ) {
    final light = fusionStyleLight(FusionStyle.ink);
    for (var pass = 0; pass < 3; pass++) {
      for (var s = 0; s < 2; s++) {
        final d = grain(s);
        final tones = _matTones[s];
        for (var k = 0; k < kFusionStyleTones; k++) {
          final col = Color.lerp(tones[k], light, toLight)!;
          final thin = k >= 4;
          if (thin && pass == 1) continue;
          final shade = thin
              ? col
              : Color.lerp(col, const Color(0xFF000000), 0.45)!;
          final (size, color) = switch (pass) {
            0 => (
              d * 4.2,
              (thin ? col : shade).withValues(alpha: thin ? 0.07 : 0.16),
            ),
            1 => (d * 2.0, shade.withValues(alpha: 0.3)),
            _ => (
              d * (thin ? 0.8 : 0.85),
              col.withValues(alpha: thin ? 0.9 : 0.72),
            ),
          };
          b.draw(
            canvas,
            FusionParticleField._mat + s * kFusionStyleTones + k,
            size,
            color,
          );
        }
      }
    }
  }

  /// The ink style's paint: a faint light in the water first, so the ink is
  /// darker than what is round it; then each tone as a soft wide layer
  /// under a fine one, so the plume reads as one fluid, not as dots.
  void _paintInk(
    Canvas canvas,
    double t, {
    required bool back,
    required double now,
  }) {
    final b = _batch..clear();
    for (var i = 0; i < length; i++) {
      if (_mode[i] == 0) continue;
      if ((_depth[i] < 0) != back) continue;
      final look = _look[i];
      if (look == 0) {
        _addOwn(b, i, t, now, back: back);
        continue;
      }
      b.add(
        FusionParticleField._mat + _side[i] * kFusionStyleTones + look - 1,
        _x[i],
        _y[i],
      );
    }
    if (!back) {
      final water =
          fsSmooth(0.75, 1.3, t) *
          (1 - fsSmooth(2.1, 2.5, t)) *
          (darkBackdrop ? 0.34 : 0.16);
      if (water > 0.004) {
        final mid = Offset.lerp(_centres[0], _centres[1], 0.5)!;
        final at = Offset.lerp(mid, core, 0.6)!;
        final span =
            math.max(
              (_centres[1] - _centres[0]).distance * 0.62,
              coreRadius * 1.6,
            ) *
            (1 - 0.45 * fsSmooth(1.6, 2.4, t));
        canvas
          ..save()
          ..translate(at.dx, at.dy)
          ..scale(span, coreRadius * 2.2);
        canvas.drawCircle(
          Offset.zero,
          1,
          Paint()
            ..shader = _waterLight
            ..color = Color.fromRGBO(0, 0, 0, water),
        );
        canvas.restore();
      }
    }
    _drawOwn(canvas, t, back: back);
    final c = FusionParticleField._interval(
      t,
      FusionParticleField._collapseStart,
      FusionParticleField._collapseEnd,
    );
    final shrink = 1 - 0.7 * c;
    final light = fusionStyleLight(FusionStyle.ink);
    _drawInkLayers(canvas, b, (s) => _grainD[s] * shrink, c * c * 0.35);
    if (back) return;
    _bloom(
      canvas,
      t,
      Color.lerp(light, const Color(0xFFFFFFFF), 0.4)!,
      light,
      fusionStyleFlare(FusionStyle.ink),
    );
  }

  /// A style's grains in their layers: every haze first, then every body,
  /// then the fine grains, so the material reads as one.
  void _drawLayers(
    Canvas canvas,
    GrainBatch b,
    FusionStyle st,
    double shrink,
    double toLight, {
    bool back = false,
  }) {
    final light = fusionStyleLight(st);
    final size = fusionStyleGrain(st);
    for (var pass = 0; pass < 3; pass++) {
      for (var s = 0; s < 2; s++) {
        final d = _grainD[s] * shrink * size;
        final tones = _matTones[s];
        for (var k = 0; k < kFusionStyleTones; k++) {
          final (mul, alpha, dark) = fusionStyleLayers(st, k)[pass];
          if (alpha <= 0) continue;
          var col = Color.lerp(tones[k], light, toLight)!;
          if (dark > 0) col = Color.lerp(col, const Color(0xFF000000), dark)!;
          if (back) col = Color.lerp(col, const Color(0xFF000000), 0.35)!;
          b.draw(
            canvas,
            FusionParticleField._mat + s * kFusionStyleTones + k,
            d * mul,
            col.withValues(alpha: alpha),
          );
        }
      }
    }
  }

  void _paintStyled(
    Canvas canvas,
    double t, {
    required bool back,
    required double now,
  }) {
    final st = style!;
    if (st == FusionStyle.ink) {
      _paintInk(canvas, t, back: back, now: now);
      return;
    }
    final b = _batch..clear();
    for (var i = 0; i < length; i++) {
      if (_mode[i] == 0) continue;
      if ((_depth[i] < 0) != back) continue;
      final look = _look[i];
      if (look == 0) {
        _addOwn(b, i, t, now, back: back);
        continue;
      }
      final x = _x[i], y = _y[i];
      if (look == 7) {
        b.add(FusionParticleField._glint, x, y);
        continue;
      }
      b.add(
        FusionParticleField._mat + _side[i] * kFusionStyleTones + look - 1,
        x,
        y,
      );
    }
    _drawOwn(canvas, t, back: back);
    final c = FusionParticleField._interval(
      t,
      FusionParticleField._collapseStart,
      FusionParticleField._collapseEnd,
    );
    _drawLayers(canvas, b, st, 1 - 0.7 * c, c * c * 0.4, back: back);
    if (back) return;
    final light = fusionStyleLight(st);
    _bloom(
      canvas,
      t,
      Color.lerp(light, const Color(0xFFFFFFFF), 0.4)!,
      light,
      fusionStyleFlare(st),
    );
  }
}
