part of 'grain_field.dart';

// The Arcane — the Arcane Expanse — through the day.
//
// The realm behind the portal is the void: no land and no horizon, stars
// above and below, and a great band of dust lying across the dark where a
// horizon would be. By day a white star, the Lantern, crosses it; it sets
// crimson. By night a black hole comes up in its place — seen only as a
// patch where the stars stop, the stars round it pulled aside, and the
// grains of the ring it is eating, brighter on the side that comes toward
// you. The creatures stand on what is left of something broken: what that
// is — shards, a mirror, ruins — is [ArcaneGround].
//
// Layers, matching the scene's spawn anchors:
//   sky     — screen-fixed (the camera backdrop): the void, its stars, the
//             Lantern by day and the black hole by night
//   layer2  — the dust band and its veils; far away, the smallest pieces
//   layer3  — the far ground, hazed
//   layer4  — the ground the creatures stand on
//   layer5  — dark pieces passing close
//
// The ground the creatures use is built from the spawn points: under each
// standing creature, and under the place each encounter's partner stands,
// so a partner that cannot float always has something under its feet.
//
// Still sheets are baked as maps (see field_art.dart), read through the
// hour's grades:
//   veil     r = the hem's colour, g = the dust's; alpha = how thick
//   stone    r = haze, g = what its gloss reflects, b = shade

/// What the creatures of the Arcane stand on.
enum ArcaneGround {
  /// Floating shards of black glass, coming apart into grains.
  shards,

  /// A still black mirror out to the dust band.
  mirror,

  /// Floating pieces of a carved floor.
  ruins,
}

class ArcaneField extends _GrainField {
  ArcaneField({this.ground = ArcaneGround.shards});

  final ArcaneGround ground;

  static const far = SceneLayer.layer2;
  static const mid = SceneLayer.layer3;
  static const near = SceneLayer.layer4;
  static const fore = SceneLayer.layer5;

  static const _gVeil = 0, _gFar = 1, _gRock = 2, _gFore = 3, _gStone = 4;

  /// Daylight colours of what stands in the void; the hour's ambient light
  /// multiplies them.
  static const _albedo = <int, Color>{
    _gFar: Color(0xFF221C3A),
    _gRock: Color(0xFF17121F),
    _gFore: Color(0xFF0C0A12),
    _gStone: Color(0xFF26222E),
  };

  @override
  List<(double, _Light)> get _keys => _arcaneKeys;

  // The Lantern and the black hole come up out of the dust band.
  @override
  double get _horizon => 0.6;

  @override
  Color _sunDisc(double low) =>
      Color.lerp(const Color(0xFFFFFAEE), const Color(0xFFFF8E80), low)!;

  @override
  double get _windScale => 0.45;

  @override
  double _lightK(SceneLayer layer) => switch (layer) {
    far => 0.7,
    mid => 0.85,
    _ => 1.0,
  };

  // ── The light ────────────────────────────────────────────────────────────

  Color _sil(Color a, _Light l) => Color.from(
    alpha: 1,
    red: a.r * l.ambient.r,
    green: a.g * l.ambient.g,
    blue: a.b * l.ambient.b,
  );

  /// What black glass gives back: the dust band, tinted with its hem.
  Color _sheen(_Light l) => Color.lerp(l.skyAt(0.55), l.cloudBottom, 0.3)!;

  @override
  void _buildGrades(_Light l) {
    _grades[_gVeil] = fieldGrade(
      base: l.cloudTop,
      r: fieldDiff(l.cloudBottom, l.cloudTop),
      g: fieldDiff(l.cloudGlint, l.cloudTop),
      b: (0, 0, 0),
    );
    final band = l.skyAt(0.55);
    final sheen = Color.lerp(_sheen(l), l.cloudGlint, 0.25)!;
    for (final g in [_gFar, _gRock, _gFore, _gStone]) {
      final s = _sil(_albedo[g]!, l);
      _grades[g] = fieldGrade(
        base: s,
        r: fieldDiff(band, s),
        g: fieldDiff(sheen, s),
        b: fieldScale(s, -0.85),
      );
    }
  }

  // ── The sky ──────────────────────────────────────────────────────────────

  /// The void's stars: (x, y as shares of the screen, how big, warm or
  /// cool, twinkle phase).
  late final List<(double, double, int, int, double)> _voidStars = () {
    final r = FieldRandom(1717);
    return [
      for (var i = 0; i < 420; i++)
        (
          r.next(),
          r.next(),
          r.next() < 0.06 ? 2 : (r.next() < 0.3 ? 1 : 0),
          r.next() < 0.28 ? 1 : 0,
          r.next() * math.pi * 2,
        ),
    ];
  }();

  /// Grains of the black hole's ring: (radius in hole radii, starting
  /// angle, twinkle phase).
  late final List<(double, double, double)> _ringGrains = () {
    final r = FieldRandom(2323);
    final out = <(double, double, double)>[];
    // Most in the main lane, some in a hot inner lane, a thin outer haze —
    // and gathered here and there into clumps that the orbit shears.
    const lanes = [(2.0, 0.28, 0.32), (3.0, 0.55, 0.5), (4.3, 0.5, 0.18)];
    double lane() {
      var pick = r.next();
      for (final (c, w, share) in lanes) {
        pick -= share;
        if (pick <= 0) return c + (r.next() + r.next() - 1) * w;
      }
      return lanes.last.$1;
    }

    for (var i = 0; i < 420; i++) {
      out.add((lane(), r.next() * math.pi * 2, r.next() * math.pi * 2));
    }
    for (var k = 0; k < 9; k++) {
      final a = r.next() * math.pi * 2, rad = lane();
      for (var i = 0; i < 16; i++) {
        out.add((
          rad + (r.next() - 0.5) * 0.18,
          a + (r.next() - 0.5) * 0.5,
          r.next() * math.pi * 2,
        ));
      }
    }
    return out;
  }();

  final GrainBatch _starGrains = GrainBatch(6);
  final GrainBatch _ringBack = GrainBatch(6);
  final GrainBatch _ringFront = GrainBatch(6);

  /// The black hole this frame: where it is on the screen, its radius, and
  /// how much of it shows — or null while it is down.
  (Offset, double, double)? _hole(Size screen, FieldView view) {
    if (_moonUp < -0.12) return null;
    final vis = (_light.stars * ((_moonUp + 0.12) / 0.2).clamp(0.0, 1.0)).clamp(
      0.0,
      1.0,
    );
    if (vis < 0.02) return null;
    final at = Offset(
      screen.width * _moonX,
      view.screenY(view.height * (_horizon - _moonUp * 0.49)),
    );
    return (at, 19 * _u * view.zoom, vis);
  }

  @override
  void paintSky(Canvas canvas, Size screen, FieldView view) {
    final l = _light;
    final top = view.screenY(0), bottom = view.screenY(view.height);
    canvas.drawRect(
      Offset.zero & screen,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, top),
          Offset(0, bottom),
          l.sky,
          l.stops,
        ),
    );
    if (_mirror) _paintMirrorSky(canvas, screen, view);
    final hole = _hole(screen, view);
    _paintVoidStars(canvas, screen, view, hole);
    _paintLantern(canvas, screen, view);
    if (hole != null) _paintHole(canvas, view, hole);
  }

  void _paintVoidStars(
    Canvas canvas,
    Size screen,
    FieldView view,
    (Offset, double, double)? hole,
  ) {
    final l = _light;
    if (l.stars <= 0.02) return;
    final b = _starGrains..clear();
    final t = view.time;
    // Near the Lantern its light drowns the faint ones.
    final sun = Offset(
      screen.width * _sunX,
      view.screenY(view.height * (_horizon - _sunUp * 0.49)),
    );
    final drown = _sunUp > -0.1 ? l.glow : 0.0;
    for (var i = 0; i < _voidStars.length; i++) {
      final (fx, fy, size, warm, phase) = _voidStars[i];
      var x = fx * screen.width;
      var y = view.screenY(fy * view.height);
      if (y < -4 || y > screen.height + 4) continue;
      var lvl = size.toDouble();
      // The hole hides what is behind it and pulls the stars round it
      // aside, brighter the nearer its edge.
      if (hole != null) {
        final (c, r, vis) = hole;
        final dx = x - c.dx, dy = y - c.dy;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < r * 3.6) {
          if (d < r * 1.05) continue;
          final push = r * r * 1.15 / d * vis;
          x += dx / d * push;
          y += dy / d * push;
          lvl += (r * 2.2 / d).clamp(0.0, 1.0) * vis;
        }
      }
      if (drown > 0) {
        final d = (Offset(x, y) - sun).distance / screen.width;
        if (d < 0.3 && size == 0 && d < 0.3 * drown) continue;
      }
      final tw = 0.6 + 0.4 * math.sin(t * (0.6 + (i % 7) * 0.21) + phase);
      final level = (lvl * 0.9 + tw * l.stars * 1.6 - 0.6).round().clamp(0, 2);
      if (tw * l.stars < 0.25 && size == 0) continue;
      final bucket = warm * 3 + level;
      if (_mirror) {
        // Over the glass only, and given back by it a little dimmer.
        final hy = view.screenY(view.height * _mirrorH);
        if (y > hy) continue;
        final ry = 2 * hy - y;
        final f = (ry - hy) / math.max(1.0, view.screenY(view.height) - hy);
        if (ry < screen.height + 4 && level > 0 && f < 1) {
          if (fieldHash(i, 77) < _fresnel(f)) {
            b.add(warm * 3 + level - 1, x, ry);
          }
        }
      }
      b.add(bucket, x, y);
    }
    final z = _u * view.zoom;
    final a = l.stars.clamp(0.0, 1.0);
    for (final (warm, colour) in const [
      (0, Color(0xFFE2EAFF)),
      (1, Color(0xFFFFDCD2)),
    ]) {
      b
        ..draw(canvas, warm * 3, 1.1 * z, colour.withValues(alpha: 0.42 * a))
        ..draw(canvas, warm * 3 + 1, 1.5 * z, colour.withValues(alpha: 0.7 * a))
        ..draw(canvas, warm * 3 + 2, 5.5 * z, colour.withValues(alpha: 0.1 * a))
        ..draw(canvas, warm * 3 + 2, 2.0 * z, colour.withValues(alpha: a));
    }
  }

  /// The Lantern: a small white star with no rays, only its light round it.
  void _paintLantern(Canvas canvas, Size screen, FieldView view) {
    final l = _light;
    if (_sunUp < -0.1 || l.glow <= 0.01) return;
    final z = _u * view.zoom;
    final at = Offset(
      screen.width * _sunX,
      view.screenY(view.height * (_horizon - _sunUp * 0.49)),
    );
    final low = (1 - _sunUp * 2.5).clamp(0.0, 1.0);
    final disc = _sunDisc(low);
    final up = ((_sunUp + 0.1) / 0.16).clamp(0.0, 1.0);
    void glow(double r, Color c, double a0, double a1) => canvas.drawCircle(
      at,
      r,
      Paint()
        ..shader = Gradient.radial(
          at,
          r,
          [
            c.withValues(alpha: a0 * up),
            c.withValues(alpha: a1 * up),
            c.withValues(alpha: 0),
          ],
          const [0.0, 0.3, 1.0],
        ),
    );
    glow(screen.width * 0.6, l.rim, 0.2 * l.glow, 0.07 * l.glow);
    glow(60 * z, disc, 0.42, 0.12);
    glow(14 * z, disc, 0.95, 0.5);
    canvas.drawCircle(at, 3.4 * z, Paint()..color = disc.withValues(alpha: up));
  }

  /// The black hole: a dim one-sided glow, the far half of its ring, the
  /// dark where nothing comes back, and the near half of the ring over it.
  void _paintHole(Canvas canvas, FieldView view, (Offset, double, double) h) {
    final (c, r, vis) = h;
    final t = view.time;
    const flat = 0.24, roll = -0.17;
    final cr = math.cos(roll), sr = math.sin(roll);
    // The side whose grains come toward you is the bright one.
    final bright = c + Offset(-2.3 * r * cr, -2.3 * r * sr);
    canvas.drawCircle(
      bright,
      r * 4.2,
      Paint()
        ..shader = Gradient.radial(
          bright,
          r * 4.2,
          [
            const Color(0xFF7FE6DE).withValues(alpha: 0.16 * vis),
            const Color(0xFF6E58C8).withValues(alpha: 0.06 * vis),
            const Color(0x006E58C8),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
    final back = _ringBack..clear(), front = _ringFront..clear();
    for (final (rad, a0, phase) in _ringGrains) {
      final a = a0 + t * 0.85 / (rad * math.sqrt(rad));
      final ca = math.cos(a), sa = math.sin(a);
      final px = ca * rad * r, py = sa * rad * r * flat;
      final x = c.dx + px * cr - py * sr, y = c.dy + px * sr + py * cr;
      final beam = math.pow(0.5 - 0.5 * ca, 1.6).toDouble();
      final tw = 0.5 + 0.5 * math.sin(t * 1.9 + phase);
      final hot = rad < 2.45 ? 0 : 3;
      final level = (beam * 2.2 + tw * 0.9 - 0.5 - (rad - 2) * 0.18)
          .round()
          .clamp(0, 2);
      (sa < 0 ? back : front).add(hot + level, x, y);
    }
    void ring(GrainBatch b) {
      final g = 1.25 * _u * view.zoom;
      for (final (k, colour) in const [
        (0, Color(0xFFDDFFF8)),
        (3, Color(0xFF8E7EF0)),
      ]) {
        b
          ..draw(canvas, k, g, colour.withValues(alpha: 0.22 * vis))
          ..draw(canvas, k + 1, g * 1.15, colour.withValues(alpha: 0.5 * vis))
          ..draw(canvas, k + 2, g * 1.35, colour.withValues(alpha: 0.95 * vis));
      }
    }

    ring(back);
    canvas.drawCircle(
      c,
      r * 1.32,
      Paint()
        ..shader = Gradient.radial(
          c,
          r * 1.32,
          [
            const Color(0xFF010103).withValues(alpha: vis),
            const Color(0xFF010103).withValues(alpha: vis),
            const Color(0x00010103),
          ],
          const [0.0, 0.72, 1.0],
        ),
    );
    ring(front);
  }

  // ── Where the creatures stand ────────────────────────────────────────────

  /// The shards of the mid and near layers, as built for this screen.
  final Map<SceneLayer, List<_ArcShard>> _shards = {};

  /// Every standing point on the near and mid layers stands on its own
  /// shard, seated by the creature's feet.
  @override
  double? perchFor(String spawnId) {
    for (final p in _spawns) {
      if (p.id != spawnId || p.aloft) continue;
      if (p.anchor == near || p.anchor == mid) return _feet(p);
    }
    return null;
  }

  /// The shard over [x] on [layer], and [x] moved into that shard's loop.
  (_ArcShard, double)? _shardAt(
    SceneLayer layer,
    double x, {
    double reach = 1,
  }) {
    for (final s in _shards[layer] ?? const <_ArcShard>[]) {
      final d = _loopDelta(x, s.cx, layer);
      if (d.abs() < s.hw * reach) return (s, s.cx + d);
    }
    return null;
  }

  // On a shard there is no deeper ground to stand in, and off one there is
  // only the void: anything over a shard that cannot float is stood on it.
  @override
  ({double top, double rest})? groundAt(SceneLayer layer, double x) {
    // The mirror is ground everywhere nearer than the band.
    if (_mirror) {
      if (layer != near && layer != mid) return null;
      return (top: _h * _mirrorH, rest: _h * (_mirrorH + 0.06));
    }
    final at = _shardAt(layer, x, reach: 0.86);
    if (at == null) return null;
    final (s, lx) = at;
    return (top: double.infinity, rest: _shStand(s, lx) + 1 * _u);
  }

  /// The shards on [layer] as built: each one's span, from the top of its
  /// back edge to its point.
  @visibleForTesting
  List<Rect> debugShards(SceneLayer layer) => [
    for (final s in _shards[layer] ?? const <_ArcShard>[])
      Rect.fromLTRB(s.cx - s.hw, _shBack(s, s.cx), s.cx + s.hw, s.tip.dy),
  ];

  /// Shards nobody stands on: (x as a share of the loop, where feet would
  /// stand as a share of the height, half width).
  static const _nearScenery = <(double, double, double)>[
    (0.02, 0.40, 26),
    (0.39, 0.47, 44),
    (0.78, 0.88, 40),
    (0.9, 0.55, 56),
  ];
  static const _midScenery = <(double, double, double)>[
    (0.08, 0.49, 28),
    (0.68, 0.66, 38),
    (0.87, 0.43, 24),
  ];

  List<_ArcShard> _makeShards(SceneLayer layer) {
    final w = _widths[layer] ?? _worldWidth;
    final back = layer == mid;
    final out = <_ArcShard>[];
    var seed = back ? 520 : 420;
    final ruin = ground == ArcaneGround.ruins;
    _ArcShard shard(
      double cx,
      double hw,
      double stand, {
      double? seatX,
      int extra = 0,
    }) {
      final s = seed++;
      final r = FieldRandom(s * 13);
      final a = _ArcShard(
        cx: cx,
        hw: hw,
        plate: (back ? 6.5 : 9.0) * _u * (ruin ? 1.2 : 1),
        depth: hw * (ruin ? r.range(0.42, 0.6) : r.range(0.72, 1.0)),
        seed: s,
        haze: back ? 0.32 : 0.0,
        face: ruin ? (back ? 11 : 17) * _u : 0,
        extra: ruin ? extra : 0,
      );
      // Seat it so feet at [seatX] stand at [stand].
      a.level = stand - _shStand(a, seatX ?? cx);
      _shapeShard(a);
      return a;
    }

    for (final p in _spawns.where((p) => p.anchor == layer)) {
      final x = _spawnX(p);
      final side = p.partnerSide;
      // Shards under creatures are sized by the creatures, not the screen:
      // the pace between a pair is the same on every screen.
      if (!p.aloft) {
        final hw = p.size.x * 1.3;
        out.add(shard(x + side * hw * 0.16, hw, _feet(p), seatX: x));
      }
      // Under where its encounter partner stands.
      final bp = p.getBattlePos();
      final px = x + side * kFieldPairGap;
      final hw = p.size.x * 0.85;
      out.add(
        shard(px + side * hw * 0.1, hw, bp.dy * _h + p.size.y * 0.5, seatX: px),
      );
    }
    final scenery = back ? _midScenery : _nearScenery;
    for (var i = 0; i < scenery.length; i++) {
      final (fx, fy, fhw) = scenery[i];
      final extra = back ? (i == 1 ? 1 : 0) : const [0, 1, 2, 3][i % 4];
      out.add(shard(fx * w, fhw * _u, fy * _h, extra: extra));
    }
    return out;
  }

  // ── A shard's shape (layer-local units) ──────────────────────────────────

  double _shT(_ArcShard s, double x) => ((x - s.cx) / s.hw).clamp(-1.0, 1.0);

  /// Where feet stand on [s] at [x]: flat glass, chipped away at its ends.
  double _shStand(_ArcShard s, double x) {
    final t = _shT(s, x).abs();
    return s.level +
        s.plate * 0.08 * fieldNoise(x / (30 * _u), s.seed) +
        s.plate *
            (s.slab ? 0.35 : 0.9) *
            math.pow(math.max(0.0, t - 0.86) / 0.14, 2);
  }

  double _shPinch(_ArcShard s, double x) =>
      (1 - math.pow(_shT(s, x).abs(), s.slab ? 40 : 7)).toDouble();

  /// The back of its top, against the void.
  double _shBack(_ArcShard s, double x) =>
      _shStand(s, x) - s.plate * 0.5 * _shPinch(s, x);

  /// The front lip of its top, where the facets begin.
  double _shFront(_ArcShard s, double x) =>
      _shStand(s, x) + s.plate * 0.5 * _shPinch(s, x);

  /// Where its underside begins: the front lip of its top, or on a piece of
  /// carved floor the foot of its carved face.
  double _shLip(_ArcShard s, double x) =>
      _shFront(s, x) + s.face * (0.55 + 0.45 * _shPinch(s, x));

  /// Lays out [s]'s underside — a few broad facets down to an off-centre
  /// point, on some a lesser point beside it — and the facets themselves.
  void _shapeShard(_ArcShard s) {
    final r = FieldRandom(s.seed * 31 + 7);
    final x0 = s.cx - s.hw, x1 = s.cx + s.hw;
    final tipX = s.cx + r.range(-0.32, 0.32) * s.hw;
    final tip = Offset(tipX, _shLip(s, tipX) + s.depth);
    final under = <Offset>[Offset(x0, _shLip(s, x0))];
    void flank(double from, double to, bool left) {
      final n = 2 + (r.next() * 2).floor();
      for (var k = 1; k <= n; k++) {
        final f = k / (n + 1);
        final x = from + (to - from) * (f + r.range(-0.06, 0.06));
        final drop = left ? f : 1 - f;
        final lip = _shLip(s, x);
        under.add(
          Offset(
            x,
            lip +
                (tip.dy - lip) *
                    math.pow(left ? f : 1 - f, 0.8) *
                    r.range(0.72, 0.95) +
                (drop < 0.4 ? r.range(2, 6) * _u : 0),
          ),
        );
      }
    }

    flank(x0, tipX, true);
    under.add(tip);
    // A lesser point on one flank, now and then.
    final second = fieldHash(s.seed, 53) < 0.5;
    if (second) {
      final x = tipX + (x1 - tipX) * r.range(0.3, 0.42);
      under
        ..add(Offset(x - s.hw * 0.06, tip.dy - s.depth * r.range(0.3, 0.42)))
        ..add(Offset(x + s.hw * 0.05, tip.dy - s.depth * r.range(0.12, 0.2)))
        ..add(Offset(x + s.hw * 0.18, tip.dy - s.depth * r.range(0.4, 0.55)));
      flank(x + s.hw * 0.18, x1, false);
    } else {
      flank(tipX, x1, false);
    }
    under.add(Offset(x1, _shLip(s, x1)));
    // Keep the underside below the lip, left to right.
    for (var i = 1; i < under.length - 1; i++) {
      final p = under[i];
      final lip = _shLip(s, p.dx) + 3 * _u;
      if (p.dy < lip) under[i] = Offset(p.dx, lip);
    }
    s
      ..under = under
      ..tip = tip;

    // Facets: broad planes cut down from the lip, converging on the point
    // the way a struck flake of glass breaks — those down the side toward
    // the light paler, the rest near black — clipped to the underside.
    final facets = <_ArcFacet>[];
    final cuts = <double>[x0 - 3 * _u];
    var x = x0;
    while (true) {
      x += s.hw * r.range(0.32, 0.62);
      if (x >= x1 - s.hw * 0.2) break;
      cuts.add(x);
    }
    cuts.add(x1 + 3 * _u);
    Offset low(double x) => Offset(
      tip.dx + (x - tip.dx) * r.range(0.04, 0.22),
      tip.dy - s.depth * r.range(0.0, 0.12),
    );
    var lowA = low(cuts.first);
    for (var k = 0; k + 1 < cuts.length; k++) {
      final a = cuts[k], b = cuts[k + 1];
      final lowB = low(b);
      final la = Offset(a, _shLip(s, a) - 1.5 * _u);
      final lb = Offset(b, _shLip(s, b) - 1.5 * _u);
      final side = ((a + b) / 2 - tip.dx) / s.hw;
      final lit = side < 0;
      final own = r.range(-0.06, 0.06);
      final shade = lit ? 0.42 + 0.3 * (1 + side).clamp(0.0, 1.0) : 0.86;
      // One plane of the pair a crack splits it into is turned a little
      // more to the light.
      final mid = Offset((la.dx + lb.dx) / 2, (la.dy + lb.dy) / 2);
      final split = Offset(
        (lowA.dx + lowB.dx) / 2 + (r.next() - 0.5) * s.hw * 0.08,
        (lowA.dy + lowB.dy) / 2,
      );
      final gloss = lit ? r.range(0.06, 0.2) : 0.0;
      facets
        ..add(
          _ArcFacet(
            [la, mid, split, lowA],
            la,
            lowA,
            gloss,
            shade + own,
            shade + own + 0.12,
          ),
        )
        ..add(
          _ArcFacet(
            [mid, lb, lowB, split],
            mid,
            lowB,
            gloss * 0.3,
            shade + own + 0.14,
            shade + own + 0.2,
          ),
        );
      lowA = lowB;
    }
    s.facets = facets;
  }

  Path _shTop(_ArcShard s) {
    final x0 = s.cx - s.hw, x1 = s.cx + s.hw;
    final step = 2.4 * _u;
    final path = Path()..moveTo(x0, _shBack(s, x0));
    for (var x = x0; x <= x1; x += step) {
      path.lineTo(x, _shBack(s, x));
    }
    path.lineTo(x1, _shBack(s, x1));
    for (var x = x1; x >= x0; x -= step) {
      path.lineTo(x, _shFront(s, x));
    }
    return path..close();
  }

  Path _shBody(_ArcShard s) {
    final x0 = s.cx - s.hw, x1 = s.cx + s.hw;
    final step = 2.4 * _u;
    final path = Path()..moveTo(x0, _shLip(s, x0));
    if (s.slab) {
      // Broken off, not worn: the end steps in and out down its height.
      final h = _shLip(s, x0) - _shBack(s, x0);
      path
        ..lineTo(x0 + 3 * _u, _shBack(s, x0) + h * 0.7)
        ..lineTo(x0 - 1 * _u, _shBack(s, x0) + h * 0.45)
        ..lineTo(x0 + 2 * _u, _shBack(s, x0) + h * 0.2);
    }
    for (var x = x0; x <= x1; x += step) {
      path.lineTo(x, _shBack(s, x));
    }
    if (s.slab) {
      final h = _shLip(s, x1) - _shBack(s, x1);
      path
        ..lineTo(x1 - 2 * _u, _shBack(s, x1) + h * 0.3)
        ..lineTo(x1 + 1.5 * _u, _shBack(s, x1) + h * 0.55)
        ..lineTo(x1 - 3 * _u, _shBack(s, x1) + h * 0.8);
    }
    path.lineTo(x1, _shLip(s, x1));
    for (final p in s.under.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// A shard's maps: its facets of black glass, the darker the further
  /// from the light, the lit ones giving back the dust band; its top a
  /// flat of glass dusted with pale grains.
  void _paintShard(Canvas c, _ArcShard s, {double dark = 0}) {
    final hz = s.haze;
    final body = _shBody(s);
    c.drawPath(body, Paint()..color = fieldMap(hz, 0, 0.75 + dark));
    c
      ..save()
      ..clipPath(body);
    final g = 1 - dark;
    // Flat planes, each one shade, so the glass breaks crisply; only the
    // lowest reaches darken toward the point.
    for (final f in s.facets) {
      c.drawPath(
        Path()..addPolygon(f.pts, true),
        Paint()
          ..shader = Gradient.linear(
            f.from,
            f.to,
            [
              fieldMap(hz, f.gloss * g, f.shade0 + dark),
              fieldMap(hz, f.gloss * g, f.shade0 + dark),
              fieldMap(hz, f.gloss * 0.4 * g, f.shade1 + dark),
            ],
            const [0.0, 0.6, 1.0],
          ),
      );
    }
    c.restore();
    final top = _shTop(s);
    final b = _shBack(s, s.cx), fr = _shFront(s, s.cx);
    c.drawPath(
      top,
      Paint()
        ..shader = Gradient.linear(Offset(0, b), Offset(0, fr), [
          fieldMap(hz, 0.34 * (1 - dark), 0.3 + dark),
          fieldMap(hz, 0.06 * (1 - dark), 0.55 + dark),
        ]),
    );
    if (dark > 0.5) return;
    // Pale grains settled on the glass.
    final grains = GrainBatch(3);
    final r = FieldRandom(s.seed * 5 + 2);
    final n = (s.hw * s.plate * 0.5 / (_u * _u * 3)).round();
    for (var i = 0; i < n; i++) {
      final x = s.cx + (r.next() * 2 - 1) * s.hw * 0.94;
      final back = _shBack(s, x), front = _shFront(s, x);
      if (fieldLoopNoise(x, 22 * _u, s.seed + 1, 0) < -0.2) continue;
      final y = back + r.next() * (front - back);
      grains.add((r.next() * 2.99).floor(), x, y);
    }
    for (var k = 0; k < 3; k++) {
      grains.draw(c, k, 1.2 * _u, fieldMap(hz, 0.55 + k * 0.2, 0.3, 0.75));
    }
  }

  /// A shard's light: along the back edge of its top, on the lip over the
  /// facets that face the light, and a few glints at its corners and point.
  void _paintShardLight(Canvas c, _ArcShard s) {
    final x0 = s.cx - s.hw, x1 = s.cx + s.hw;
    final step = 2.4 * _u;
    for (final (depth, a) in const [(1.1, 0.85), (2.8, 0.22)]) {
      final band = Path()..moveTo(x0, _shBack(s, x0));
      for (var x = x0; x <= x1; x += step) {
        band.lineTo(x, _shBack(s, x));
      }
      for (var x = x1; x >= x0; x -= step) {
        band.lineTo(x, _shBack(s, x) + depth * _u);
      }
      c.drawPath(
        band..close(),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a),
      );
    }
    // Where a plane turned to the light meets the next, its edge catches
    // it: a sliver tapering from the lip toward the point.
    for (final f in s.facets) {
      if (f.gloss <= 0.04) continue;
      final top = f.pts[0], low = f.pts[3];
      final w = 1.1 * _u;
      c.drawPath(
        Path()
          ..moveTo(top.dx - w, top.dy)
          ..lineTo(top.dx + w, top.dy)
          ..lineTo(
            top.dx + (low.dx - top.dx) * 0.7,
            top.dy + (low.dy - top.dy) * 0.7,
          )
          ..close(),
        Paint()
          ..shader = Gradient.linear(top, low, [
            const Color(0xFFFFFFFF).withValues(alpha: 0.5),
            const Color(0x00FFFFFF),
          ]),
      );
    }
    _glint(x0 + 2 * _u, _shBack(s, x0 + 2 * _u));
    _glint(x1 - 2 * _u, _shBack(s, x1 - 2 * _u));
    _glint(s.tip.dx, s.tip.dy - 1 * _u);
  }

  List<FieldSheet> _shardSheets(
    SceneLayer layer,
    _ArcShard s, {
    double dark = 0,
    int grade = _gRock,
  }) {
    final b = Rect.fromLTRB(
      s.cx - s.hw - 6 * _u,
      _shBack(s, s.cx) - 8 * _u,
      s.cx + s.hw + 6 * _u,
      s.tip.dy + 6 * _u,
    );
    final w = _widths[layer] ?? _worldWidth;
    // A shard over an end of its loop is drawn again a loop away.
    void each(Canvas c, void Function(Canvas c, _ArcShard s) paint) {
      _wrapped(s.cx, s.hw + 6 * _u, w, (x) {
        c
          ..save()
          ..translate(x - s.cx, 0);
        paint(c, s);
        c.restore();
      });
    }

    final res = layer == mid ? 0.8 : 1.0;
    if (s.slab) {
      final top = b.top - (s.extra == 1 ? 70 : 24) * _u;
      final sb = Rect.fromLTRB(b.left, top, b.right, b.bottom);
      return [
        FieldSheet(
          bounds: sb,
          resolution: res,
          grade: grade == _gRock ? _gStone : grade,
          paint: (c) => each(c, (c, s) => _paintSlab(c, s, dark: dark)),
        ),
        if (s.extra == 3)
          FieldSheet(
            bounds: sb,
            resolution: res,
            grade: _gVeil,
            paint: (c) => each(c, _paintSigil),
          ),
        FieldSheet(
          bounds: sb,
          resolution: res * 0.9,
          light: true,
          paint: (c) => _sinking(layer, () => each(c, _paintSlabLight)),
        ),
      ];
    }
    return [
      FieldSheet(
        bounds: b,
        resolution: res,
        grade: grade,
        paint: (c) => each(c, (c, s) => _paintShard(c, s, dark: dark)),
      ),
      FieldSheet(
        bounds: b,
        resolution: res * 0.9,
        light: true,
        paint: (c) => _sinking(layer, () => each(c, _paintShardLight)),
      ),
    ];
  }

  /// Glass grass on the near shards, in tufts with bare glass between: a
  /// fringe along each back, blades across the top, those rooted below a
  /// standing creature's feet kept short and drawn over it (row 4).
  _Blades _shardGrass(List<_ArcShard> shards) {
    final b = _BladeBuilder();
    final r = FieldRandom(646);
    for (final s in shards) {
      final x0 = s.cx - s.hw * 0.92, x1 = s.cx + s.hw * 0.92;
      for (var x = x0; x < x1; x += 2.6 * _u) {
        if (fieldLoopNoise(x, 24 * _u, s.seed, 0) < 0.1) continue;
        b.add(
          x: x + r.range(-0.6, 0.6) * _u,
          base: _shBack(s, x) + 1.2 * _u,
          height: r.range(4, 10) * _u * _shPinch(s, x),
          lean: r.range(-0.25, 0.25),
          phase: r.range(0, math.pi * 2),
          depth: 0,
          row: 0,
        );
      }
      final n = (s.hw * 2 * s.plate * 0.5 / (9 * _u * _u)).round();
      for (var j = 0; j < n; j++) {
        final x = s.cx + (r.next() * 2 - 1) * s.hw * 0.9;
        if (fieldLoopNoise(x, 24 * _u, s.seed, 0) < -0.05) continue;
        final back = _shBack(s, x), front = _shFront(s, x);
        final d = r.next();
        final y = back + 1.5 * _u + d * (front - back - 1.5 * _u);
        final feet = y > _shStand(s, x) + 0.5 * _u;
        b.add(
          x: x,
          base: y,
          height: (feet ? r.range(3, 5) : r.range(4, 9)) * _u,
          lean: r.range(-0.25, 0.25),
          phase: r.range(0, math.pi * 2),
          depth: d,
          row: feet ? 4 : (d < 0.3 ? 1 : (d < 0.6 ? 2 : 3)),
        );
      }
    }
    return b.done();
  }

  /// The glass grass on a near shard a finger at [x], [y] is in, if any.
  double? _inGrass(double x, double y) {
    final at = _shardAt(near, x, reach: 0.97);
    if (at == null) return null;
    final (s, lx) = at;
    final back = _shBack(s, lx);
    if (y < back - 26 * _u || y > _shFront(s, lx) + 10 * _u) return null;
    return back;
  }

  /// Grains falling away from each shard's point into the void, as if it
  /// were slowly coming apart.
  void _paintFalls(Canvas canvas, FieldView view, SceneLayer layer) {
    final shards = _shards[layer];
    if (shards == null) return;
    final b = _fallGrains..clear();
    final t = view.time;
    final reach = (layer == mid ? 50 : 80) * _u;
    for (final shift in _shiftsFor(layer, view, reach)) {
      for (final s in shards) {
        final x = s.tip.dx + shift;
        if (x < view.left - 20 || x > view.right + 20) continue;
        for (var i = 0; i < 12; i++) {
          final p = fieldHash(i, s.seed + 91);
          final speed = (6 + 9 * fieldHash(i, s.seed + 93)) * _u;
          final f = ((t * speed / reach) + p) % 1.0;
          final y = s.tip.dy + 1 * _u + f * reach;
          // Each drifts off its own way as it falls.
          final drift = (fieldHash(i, s.seed + 95) - 0.5) * 14 * _u * f;
          final sway = math.sin(t * 0.7 + i * 1.9) * 2 * _u * f;
          final fade = (1 - f) * math.min(1.0, f * 10);
          final level = (fade * 2.99).floor();
          if (level <= 0) continue;
          b.add(level, x + drift + sway, y);
        }
      }
    }
    final c = _light.mote;
    for (var lv = 1; lv < 3; lv++) {
      b.draw(canvas, lv, 1.2 * _u, c.withValues(alpha: 0.32 * lv));
    }
  }

  final GrainBatch _fallGrains = GrainBatch(3);

  /// Motes adrift in the void: the shared motes, without the wide halos
  /// that read as bubbles against the dark.
  void _paintVoidMotes(Canvas canvas, FieldView view, SceneLayer layer) {
    final m = _motes;
    if (m == null) return;
    final l = _light;
    _moteBatch.clear();
    final t = view.time;
    final span = m.yBottom - m.yTop;
    final shifts = _shiftsFor(layer, view, 10);
    for (var i = 0; i < m.n; i += 2) {
      final rise = (m.yBottom - m.y0[i] + t * m.speed[i] * 0.5) % span;
      final y = m.yBottom - rise + 6 * _u * math.sin(t * 0.5 + i);
      var x = (m.x0[i] + 9 * _u * math.sin(t * 0.3 + m.phase[i])) % m.width;
      for (final sh in shifts) {
        if (x + sh >= view.left - 10 && x + sh <= view.right + 10) {
          x += sh;
          break;
        }
      }
      if (x < view.left - 10 || x > view.right + 10) continue;
      final life = rise / span;
      final fade = math.min(1.0, life * 6) * math.min(1.0, (1 - life) * 3);
      final blink = math.pow(
        0.5 + 0.5 * math.sin(t * (0.9 + m.phase[i] * 0.3) + m.phase[i] * 5),
        3,
      );
      final level = (fade * (0.35 + 0.65 * blink) * 3.99).floor();
      if (level <= 0) continue;
      _moteBatch.add(level, x, y);
    }
    for (var lv = 1; lv < 4; lv++) {
      _moteBatch
        ..draw(canvas, lv, 4 * _u, l.mote.withValues(alpha: 0.035 * lv))
        ..draw(canvas, lv, 1.6 * _u, l.mote.withValues(alpha: 0.28 * lv));
    }
  }

  // ── Ruins: pieces of a carved floor ──────────────────────────────────────

  /// A piece of the floor's maps: the broken rock under it, its carved
  /// face — a lit fillet, a groove, a frieze of key blocks, a base — and
  /// its flagstones, each its own shade; then whatever stands on it.
  void _paintSlab(Canvas c, _ArcShard s, {double dark = 0}) {
    final hz = s.haze;
    final body = _shBody(s);
    c.drawPath(body, Paint()..color = fieldMap(hz, 0, 0.8 + dark));
    c
      ..save()
      ..clipPath(body);
    for (final f in s.facets) {
      c.drawPath(
        Path()..addPolygon(f.pts, true),
        Paint()..color = fieldMap(hz, 0, f.shade0 * 0.9 + 0.1 + dark),
      );
    }
    c.restore();
    final x0 = s.cx - s.hw, x1 = s.cx + s.hw;
    final step = 2.4 * _u;
    double faceY(double x, double f) =>
        _shFront(s, x) + (_shLip(s, x) - _shFront(s, x)) * f;
    Path band(double f0, double f1) {
      final path = Path()..moveTo(x0, faceY(x0, f0));
      for (var x = x0; x <= x1; x += step) {
        path.lineTo(x, faceY(x, f0));
      }
      path.lineTo(x1, faceY(x1, f0));
      for (var x = x1; x >= x0; x -= step) {
        path.lineTo(x, faceY(x, f1));
      }
      return path..close();
    }

    for (final (f0, f1, shade) in const [
      (0.0, 1.0, 0.55),
      (0.0, 0.14, 0.3),
      (0.14, 0.24, 0.9),
      (0.84, 1.0, 0.42),
    ]) {
      c.drawPath(band(f0, f1), Paint()..color = fieldMap(hz, 0, shade + dark));
    }
    // The frieze: key blocks cut back into the face, stepping up and down.
    final key = 9 * _u * (hz > 0 ? 0.7 : 1);
    var i = 0;
    for (var x = x0 + key * 0.5; x < x1 - key * 0.5; x += key, i++) {
      final up = i.isEven;
      c.drawRect(
        Rect.fromLTRB(
          x,
          faceY(x, up ? 0.32 : 0.48),
          x + key * 0.55,
          faceY(x, up ? 0.62 : 0.78),
        ),
        Paint()..color = fieldMap(hz, 0, 0.88 + dark),
      );
    }
    // The flagstones: the joints are the dark between them.
    c.drawPath(_shTop(s), Paint()..color = fieldMap(hz, 0, 0.82 + dark));
    final r = FieldRandom(s.seed * 3 + 1);
    double topY(double x, double f) =>
        _shBack(s, x) + (_shFront(s, x) - _shBack(s, x)) * f;
    var a = x0;
    while (a < x1) {
      final b = math.min(x1, a + s.hw * r.range(0.22, 0.42));
      final rows = r.next() < 0.5 ? 1 : 2;
      for (var k = 0; k < rows; k++) {
        final f0 = rows == 1 ? 0.0 : k * 0.5;
        final f1 = rows == 1 ? 1.0 : (k + 1) * 0.5;
        final gap = 0.6 * _u;
        final stone = Path()
          ..moveTo(a + gap, topY(a + gap, f0) + gap * 0.5)
          ..lineTo(b - gap, topY(b - gap, f0) + gap * 0.5)
          ..lineTo(b - gap, topY(b - gap, f1) - gap * 0.5)
          ..lineTo(a + gap, topY(a + gap, f1) - gap * 0.5)
          ..close();
        c.drawPath(
          stone,
          Paint()..color = fieldMap(hz, 0.06, r.range(0.32, 0.5) + dark),
        );
      }
      a = b;
    }
    if (dark > 0.5) return;
    switch (s.extra) {
      case 1:
        _paintColumn(c, s);
      case 2:
        _paintSteps(c, s);
    }
  }

  /// Where a broken column stands on [s], its radius and how tall it is.
  ({double x, double base, double r, double h}) _columnOf(_ArcShard s) {
    final k = s.haze > 0 ? 0.65 : 1.0;
    final x = s.cx - s.hw * 0.3;
    return (
      x: x,
      base: _shStand(s, x) + s.plate * 0.15,
      r: 9 * _u * k,
      h: (46 + 22 * fieldHash(s.seed, 41)) * _u * k,
    );
  }

  void _paintColumn(Canvas c, _ArcShard s) {
    final hz = s.haze;
    final col = _columnOf(s);
    final x0 = col.x - col.r, x1 = col.x + col.r;
    // Its plinth, then the shaft broken off in a jag.
    c.drawRect(
      Rect.fromLTRB(
        x0 - col.r * 0.35,
        col.base - 6 * _u,
        x1 + col.r * 0.35,
        col.base,
      ),
      Paint()..color = fieldMap(hz, 0, 0.5),
    );
    final foot = col.base - 6 * _u;
    final top = foot - col.h;
    final shaft = Path()
      ..moveTo(x0, foot)
      ..lineTo(x0, top + col.h * 0.1)
      ..lineTo(col.x - col.r * 0.35, top + col.h * 0.02)
      ..lineTo(col.x + col.r * 0.1, top + col.h * 0.16)
      ..lineTo(col.x + col.r * 0.55, top)
      ..lineTo(x1, top + col.h * 0.22)
      ..lineTo(x1, foot)
      ..close();
    c.drawPath(
      shaft,
      Paint()
        ..shader = Gradient.linear(
          Offset(x0, 0),
          Offset(x1, 0),
          [
            fieldMap(hz, 0.08, 0.3),
            fieldMap(hz, 0, 0.55),
            fieldMap(hz, 0, 0.9),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
    // Flutes: narrow shadowed channels down the shaft.
    c
      ..save()
      ..clipPath(shaft);
    for (var k = 1; k < 6; k++) {
      final fx = x0 + col.r * 2 * k / 6;
      c.drawRect(
        Rect.fromLTRB(fx - 0.7 * _u, top, fx + 0.7 * _u, foot),
        Paint()..color = fieldMap(hz, 0, 0.85, 0.55),
      );
    }
    c.restore();
  }

  /// Three steps going up at one end of a piece of floor, to nothing.
  List<Rect> _stepsOf(_ArcShard s) {
    final y = _shStand(s, s.cx + s.hw * 0.5);
    return [
      for (var k = 0; k < 3; k++)
        Rect.fromLTRB(
          s.cx + s.hw * (0.15 + k * 0.2),
          y - (k + 1) * 7 * _u,
          s.cx + s.hw * 0.86,
          y - k * 7 * _u + 1 * _u,
        ),
    ];
  }

  void _paintSteps(Canvas c, _ArcShard s) {
    final hz = s.haze;
    for (final step in _stepsOf(s)) {
      c
        ..drawRect(step, Paint()..color = fieldMap(hz, 0, 0.6))
        ..drawRect(
          Rect.fromLTRB(step.left, step.top, step.right, step.top + 2.4 * _u),
          Paint()..color = fieldMap(hz, 0.08, 0.32),
        );
    }
  }

  /// A sigil let into the floor: a disc of leaded glass seen low across,
  /// its panes in the hem's colour and the dust's, faintly giving light.
  void _paintSigil(Canvas c, _ArcShard s) {
    final o = Offset(s.cx + s.hw * 0.1, _shStand(s, s.cx));
    final rx = s.hw * 0.42, ry = s.plate * 0.34;
    c
      ..save()
      ..translate(o.dx, o.dy)
      ..scale(1, ry * 2.6 / rx);
    c.drawCircle(
      Offset.zero,
      rx * 1.5,
      Paint()
        ..shader = Gradient.radial(Offset.zero, rx * 1.5, [
          fieldMap(1, 0, 0, 0.22),
          fieldMap(1, 0, 0, 0),
        ]),
    );
    c.restore();
    const n = 10;
    for (var k = 0; k < n; k++) {
      final a0 = k / n * math.pi * 2 + 0.05;
      final a1 = (k + 1) / n * math.pi * 2 - 0.05;
      Offset at(double a, double f) =>
          Offset(o.dx + math.cos(a) * rx * f, o.dy + math.sin(a) * ry * f);
      for (final (f0, f1) in const [(0.42, 0.95), (0.12, 0.36)]) {
        final pane = Path()
          ..moveTo(at(a0, f0).dx, at(a0, f0).dy)
          ..lineTo(at(a0, f1).dx, at(a0, f1).dy)
          ..lineTo(at(a1, f1).dx, at(a1, f1).dy)
          ..lineTo(at(a1, f0).dx, at(a1, f0).dy)
          ..close();
        c.drawPath(
          pane,
          Paint()
            ..color = k.isEven
                ? fieldMap(0.9, 0, 0, 0.85)
                : fieldMap(0, 0.6, 0, 0.6),
        );
      }
    }
  }

  void _paintSlabLight(Canvas c, _ArcShard s) {
    final x0 = s.cx - s.hw, x1 = s.cx + s.hw;
    final step = 2.4 * _u;
    for (final (depth, a) in const [(1.0, 0.8), (2.4, 0.2)]) {
      final band = Path()..moveTo(x0, _shBack(s, x0));
      for (var x = x0; x <= x1; x += step) {
        band.lineTo(x, _shBack(s, x));
      }
      for (var x = x1; x >= x0; x -= step) {
        band.lineTo(x, _shBack(s, x) + depth * _u);
      }
      c.drawPath(
        band..close(),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a),
      );
    }
    // The fillet along the top of the carved face.
    final fillet = Path()..moveTo(x0, _shFront(s, x0));
    for (var x = x0; x <= x1; x += step) {
      fillet.lineTo(x, _shFront(s, x));
    }
    for (var x = x1; x >= x0; x -= step) {
      fillet.lineTo(x, _shFront(s, x) + 1.3 * _u);
    }
    c.drawPath(
      fillet..close(),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.4),
    );
    if (s.extra == 1) {
      final col = _columnOf(s);
      final foot = col.base - 6 * _u;
      final top = foot - col.h;
      c.drawRect(
        Rect.fromLTRB(
          col.x - col.r,
          top + col.h * 0.1,
          col.x - col.r + 1.8 * _u,
          foot,
        ),
        Paint()
          ..shader = Gradient.linear(Offset(0, top), Offset(0, foot), [
            const Color(0xFFFFFFFF).withValues(alpha: 0.6),
            const Color(0x00FFFFFF),
          ]),
      );
      _glint(col.x + col.r * 0.55, top);
    }
    if (s.extra == 2) {
      for (final st in _stepsOf(s)) {
        c.drawRect(
          Rect.fromLTRB(st.left, st.top, st.right, st.top + 1.1 * _u),
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5),
        );
      }
    }
    _glint(x0 + 2 * _u, _shBack(s, x0 + 2 * _u));
    _glint(x1 - 2 * _u, _shBack(s, x1 - 2 * _u));
  }

  // ── The mirror ───────────────────────────────────────────────────────────

  /// Where the mirror meets the dust band, as a share of the height.
  static const _mirrorH = 0.565;

  bool get _mirror => ground == ArcaneGround.mirror;

  /// How much of the void the glass gives back [f] of the way from the
  /// band down to the bottom of the screen: most where you look across it.
  double _fresnel(double f) =>
      0.78 - 0.5 * math.pow(f.clamp(0.0, 1.0), 0.7).toDouble();

  /// The void turned over in the glass below the band, dimming as the eye
  /// looks down into it; the Lantern's light lying along it in a path.
  void _paintMirrorSky(Canvas canvas, Size screen, FieldView view) {
    final l = _light;
    final hy = view.screenY(view.height * _mirrorH);
    final by = view.screenY(view.height);
    const glass = Color(0xFF020106);
    const n = 8;
    final colours = <Color>[], stops = <double>[];
    for (var i = 0; i <= n; i++) {
      final f = i / n;
      final down = (1 - _mirrorH) * f;
      final up = (_mirrorH - down).clamp(0.0, 1.0);
      colours.add(Color.lerp(glass, l.skyAt(up), _fresnel(f))!);
      stops.add(f);
    }
    canvas.drawRect(
      Rect.fromLTRB(0, hy, screen.width, math.max(screen.height, by)),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, hy),
          Offset(0, by),
          colours,
          stops,
        ),
    );
    // A still mirror gives the Lantern back whole, below the band.
    if (_sunUp > -0.1 && l.glow > 0.01) {
      final sy = view.screenY(view.height * (_horizon - _sunUp * 0.49));
      final ry = 2 * hy - sy;
      final f = (ry - hy) / math.max(1.0, by - hy);
      if (f < 1.1) {
        final k = _fresnel(f) * 0.7;
        final at = Offset(screen.width * _sunX, ry);
        final z = _u * view.zoom;
        final disc = _sunDisc((1 - _sunUp * 2.5).clamp(0.0, 1.0));
        canvas
          ..drawCircle(
            at,
            40 * z,
            Paint()
              ..shader = Gradient.radial(at, 40 * z, [
                disc.withValues(alpha: 0.3 * k),
                disc.withValues(alpha: 0),
              ]),
          )
          ..drawCircle(at, 3 * z, Paint()..color = disc.withValues(alpha: k));
      }
    }
  }

  /// Standing stones on the mirror: (x as a share of the loop, foot as a
  /// share of the height, width, height) at the reference height.
  static const _farStones = <(double, double, double, double)>[
    (0.06, 0.574, 4, 16),
    (0.21, 0.571, 3, 10),
    (0.33, 0.578, 6, 22),
    (0.52, 0.572, 3, 12),
    (0.7, 0.576, 5, 18),
    (0.84, 0.573, 3, 9),
  ];
  static const _midStones = <(double, double, double, double)>[
    (0.13, 0.62, 12, 64),
    (0.6, 0.6, 9, 40),
    (0.86, 0.63, 15, 86),
  ];
  static const _nearStones = <(double, double, double, double)>[
    (0.03, 0.86, 30, 150),
    (0.46, 0.8, 22, 104),
    (0.92, 0.9, 40, 210),
  ];

  /// A standing stone at [x] on the glass, its foot at [base], and its
  /// image in the glass under it — the image fainter the further down.
  void _paintStone(
    Canvas c,
    double x,
    double base,
    double w,
    double h,
    int seed, {
    required double haze,
    bool light = false,
  }) {
    final r = FieldRandom(seed);
    final lean = r.range(-0.06, 0.06) * h;
    final peak = Offset(x + w * r.range(-0.2, 0.3) + lean, base - h);
    final pts = [
      Offset(x - w / 2, base),
      Offset(x - w * 0.46 + lean * 0.9, base - h * r.range(0.8, 0.9)),
      peak,
      Offset(x + w * 0.5 + lean * 0.95, base - h * r.range(0.86, 0.95)),
      Offset(x + w / 2, base),
    ];
    final lit = [pts[0], pts[1], peak, Offset(x - w * 0.2 + lean, base)];
    Path poly(List<Offset> p, {bool flip = false}) => Path()
      ..addPolygon([
        for (final o in p) flip ? Offset(o.dx, 2 * base - o.dy) : o,
      ], true);
    if (light) {
      c.drawPath(
        poly([
          pts[0],
          pts[1],
          peak,
          Offset(peak.dx - w * 0.12, peak.dy + h * 0.1),
          Offset(x - w * 0.36, base),
        ]),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.45),
      );
      _glint(peak.dx, peak.dy + 1 * _u);
      return;
    }
    // Its image first, faint and going dark with depth.
    c.drawPath(
      poly(pts, flip: true),
      Paint()
        ..shader = Gradient.linear(Offset(0, base), Offset(0, base + h), [
          fieldMap(haze, 0, 0.75, 0.5),
          fieldMap(haze, 0, 0.9, 0),
        ]),
    );
    c
      ..drawPath(poly(pts), Paint()..color = fieldMap(haze, 0, 0.9))
      ..drawPath(poly(lit), Paint()..color = fieldMap(haze, 0.03, 0.72));
  }

  List<FieldSheet> _stoneSheets(
    SceneLayer layer,
    double w,
    List<(double, double, double, double)> stones,
    double haze,
  ) {
    void each(Canvas c, bool light) {
      for (var i = 0; i < stones.length; i++) {
        final (fx, fy, sw, sh) = stones[i];
        _wrapped(fx * w, sw * _u, w, (x) {
          _paintStone(
            c,
            x,
            fy * _h,
            sw * _u,
            sh * _u,
            300 + i + layer.index * 20,
            haze: haze,
            light: light,
          );
        });
      }
    }

    final top = stones.map((s) => s.$2 * _h - s.$4 * _u).reduce(math.min);
    final bottom = stones.map((s) => s.$2 * _h + s.$4 * _u).reduce(math.max);
    final b = Rect.fromLTRB(-8 * _u, top - 4 * _u, w - 0.5, bottom + 4 * _u);
    return [
      FieldSheet(
        bounds: b,
        resolution: layer == far ? 0.7 : 0.9,
        grade: layer == far ? _gFar : _gRock,
        paint: (c) => each(c, false),
      ),
      FieldSheet(
        bounds: b,
        resolution: 0.8,
        light: true,
        paint: (c) => _sinking(layer, () => each(c, true)),
      ),
    ];
  }

  // ── Far: the dust band ───────────────────────────────────────────────────

  /// The band of dust across the void where a horizon would be: soft veils
  /// with a luminous hem, and thousands of grains through them parted by a
  /// darker rift.
  void _paintDustBand(Canvas c, double w, {double lift = 0}) {
    c
      ..save()
      ..translate(0, -lift * _h);
    final p = _loop ? w : 0.0;
    double n(double x, double wave, int seed) =>
        fieldLoopNoise(x, wave * _u, seed, p);
    // Veils: long lenses of soft colour, their lower edges lit.
    final r = FieldRandom(808);
    const veils = [
      (0.55, 46.0, 0.34),
      (0.6, 28.0, 0.26),
      (0.47, 34.0, 0.16),
      (0.38, 22.0, 0.1),
      (0.68, 24.0, 0.14),
    ];
    for (var v = 0; v < veils.length; v++) {
      final (cy, thick, a) = veils[v];
      final seed = 40 + v * 7;
      final step = 6 * _u;
      double centre(double x) =>
          _h * cy + 16 * _u * n(x, 260, seed) + 6 * _u * n(x, 90, seed + 1);
      double half(double x) =>
          thick *
          _u *
          (0.55 + 0.45 * n(x, 320, seed + 2)) *
          (0.7 + 0.3 * n(x, 70, seed + 3)).clamp(0.05, 1.0);
      for (final (lo, hi, rMap, alpha) in [
        (-1.0, 0.0, 0.0, a),
        (0.0, 1.0, 0.7, a * 0.9),
      ]) {
        final path = Path()..moveTo(-8 * _u, centre(-8 * _u));
        for (var x = -8 * _u; x <= w + 8 * _u; x += step) {
          path.lineTo(x, centre(x) + half(x) * lo);
        }
        for (var x = w + 8 * _u; x >= -8 * _u; x -= step) {
          path.lineTo(x, centre(x) + half(x) * hi);
        }
        final y0 = _h * cy - thick * _u, y1 = _h * cy + thick * _u;
        c.drawPath(
          path..close(),
          Paint()
            ..shader = Gradient.linear(
              Offset(0, lo < 0 ? y0 : _h * cy),
              Offset(0, lo < 0 ? _h * cy : y1),
              lo < 0
                  ? [fieldMap(0, 0, 0, 0), fieldMap(0, 0, 0, alpha)]
                  : [fieldMap(0, 0, 0, alpha), fieldMap(rMap, 0, 0, 0)],
            ),
        );
      }
    }
    // The dust: grains thick along the band's middle, thinning away from
    // it, and few along the rift through it.
    final grains = GrainBatch(4);
    final count = (w * 6.5 / _u).round();
    for (var i = 0; i < count; i++) {
      final x = r.next() * w;
      final band = _h * 0.555 + 14 * _u * n(x, 240, 61) + 5 * _u * n(x, 60, 62);
      final spread = (20 + 12 * n(x, 300, 63)) * _u;
      final g = (r.next() + r.next() + r.next() - 1.5) / 1.5;
      final y = band + g * spread * 1.6;
      final rift = band + 3 * _u + 3 * _u * n(x, 80, 64);
      final inRift = ((y - rift) / (3.6 * _u)).abs();
      if (inRift < 1 && r.next() < 0.8 * (1 - inRift)) continue;
      final clump = 0.5 + 0.5 * n(x, 46, 65);
      if (r.next() > 0.35 + 0.65 * clump) continue;
      final near = 1 - g.abs();
      final level = (near * 2.4 + r.next() * 1.2 - 0.4).round().clamp(0, 3);
      grains.add(level, x, y);
      if (level >= 2 && r.next() < 0.025) _glint(x, y - lift * _h);
    }
    for (var k = 0; k < 4; k++) {
      grains.draw(c, k, 1.15 * _u, fieldMap(0, 1, 0, 0.22 + k * 0.22));
    }
    c.restore();
  }

  /// Pieces far off in the band, too small and hazed to be more than a
  /// shape and an edge of light.
  List<_ArcShard> _farShards(double w) {
    final r = FieldRandom(919);
    final out = <_ArcShard>[];
    final n = math.max(6, (w / (110 * _u)).round());
    for (var i = 0; i < n; i++) {
      final hw = r.range(4, 15) * _u;
      final s = _ArcShard(
        cx: (i + r.range(0.15, 0.85)) * w / n,
        hw: hw,
        plate: 2.6 * _u,
        depth: hw * r.range(0.8, 1.3),
        seed: 900 + i,
        haze: r.range(0.45, 0.8),
      );
      s.level = _h * r.range(0.32, 0.72);
      _shapeShard(s);
      out.add(s);
    }
    return out;
  }

  /// Big dark pieces passing close: one hanging from above, its point in
  /// view, and others whose tops show along the bottom.
  List<_ArcShard> _foreShards(double w) {
    final out = <_ArcShard>[];
    for (final (fx, top, hw, hang) in const [
      (0.18, -0.02, 70.0, true),
      (0.55, 0.93, 90.0, false),
      (0.86, 0.95, 60.0, false),
    ]) {
      final ruin = ground == ArcaneGround.ruins && !hang;
      final s = _ArcShard(
        cx: fx * w,
        hw: hw * _u,
        plate: 12 * _u,
        depth: hang ? _h * 0.2 : hw * _u * (ruin ? 0.5 : 1),
        seed: 960 + (fx * 100).round(),
        haze: 0,
        face: ruin ? 18 * _u : 0,
      );
      s.level = _h * top;
      _shapeShard(s);
      out.add(s);
    }
    return out;
  }

  // ── Layout for the current screen ────────────────────────────────────────

  _Blades? _nearBlades;
  _Motes? _motes;
  double _nearWidth = 0;

  @override
  List<FieldSheet> build(SceneLayer layer, Size size, Size screen) {
    _h = size.height;
    _u = _h / 475;
    _screen = screen;
    final w = size.width;
    _widths[layer] = w;
    // Full-width sheets reach back past the loop's start, so the next
    // copy's overlap covers the seam (see the Volcano).
    final m = 8 * _u;
    switch (layer) {
      case far:
        _glints[far] = _Glints();
        if (_mirror) {
          final hy = _h * _mirrorH;
          return [
            FieldSheet(
              bounds: Rect.fromLTRB(-m, _h * 0.2, w - 0.5, _h * 0.82),
              resolution: 0.6,
              grade: _gVeil,
              paint: (c) {
                _sinking(far, () => _paintDustBand(c, w, lift: 0.07));
                // The band given back by the glass, fainter, and nothing
                // of it above the line where the glass begins.
                final below = Rect.fromLTRB(-m, hy, w, _h);
                c
                  ..save()
                  ..clipRect(below)
                  ..saveLayer(below, Paint()..color = const Color(0x66000000))
                  ..translate(0, 2 * hy)
                  ..scale(1, -1);
                _paintDustBand(c, w, lift: 0.07);
                c
                  ..restore()
                  ..restore();
              },
            ),
            ..._stoneSheets(far, w, _farStones, 0.6),
          ];
        }
        final pieces = _farShards(w);
        final band = Rect.fromLTRB(-m, _h * 0.26, w - 0.5, _h * 0.8);
        return [
          FieldSheet(
            bounds: band,
            resolution: 0.6,
            grade: _gVeil,
            paint: (c) => _sinking(far, () => _paintDustBand(c, w)),
          ),
          for (final s in pieces) ..._shardSheets(far, s, grade: _gFar),
        ];
      case mid:
        _glints[mid] = _Glints();
        if (_mirror) return _stoneSheets(mid, w, _midStones, 0.3);
        final shards = _shards[mid] = _makeShards(mid);
        return [for (final s in shards) ..._shardSheets(mid, s)];
      case near:
        _glints[near] = _Glints();
        _nearWidth = w;
        _motes = _Motes.make(w, _h, _u);
        if (_mirror) {
          _nearBlades = null;
          return _stoneSheets(near, w, _nearStones, 0);
        }
        final shards = _shards[near] = _makeShards(near);
        _nearBlades = _shardGrass(shards);
        return [for (final s in shards) ..._shardSheets(near, s)];
      case fore:
        if (_mirror) return const [];
        return [
          for (final s in _foreShards(w))
            ..._shardSheets(fore, s, dark: 0.3, grade: _gFore),
        ];
      default:
        return const [];
    }
  }

  @override
  bool hasLive(SceneLayer layer, {required bool front}) => switch (layer) {
    near => true,
    far || mid => !front,
    _ => false,
  };

  // ── Live ─────────────────────────────────────────────────────────────────

  @override
  void paintLive(
    SceneLayer layer,
    Canvas canvas,
    FieldView view, {
    required bool front,
  }) {
    switch (layer) {
      case far:
        _paintGlints(canvas, view, far, _glints[far], size: 0.7, alpha: 0.8);
      case mid:
        _paintGlints(canvas, view, mid, _glints[mid], size: 0.85, alpha: 0.7);
        _paintFalls(canvas, view, mid);
      case near:
        final pushes = _pushes(view);
        if (!front) {
          _paintGlints(canvas, view, near, _glints[near], size: 1.1);
          _paintFalls(canvas, view, near);
          _kickUp(view, pushes, near, _nearWidth, _inGrass);
        }
        final blades = _nearBlades;
        if (blades != null) {
          if (!front) {
            _stirBlades(
              blades,
              near,
              _nearWidth,
              view,
              reach: 28 * _u,
              maxBend: 0.9,
              shed: true,
            );
          }
          _paintBlades(
            canvas,
            view,
            blades,
            _nearWidth,
            rows: front ? (4, 4) : (0, 3),
            fore: false,
            layer: near,
          );
        }
        if (front) {
          _paintVoidMotes(canvas, view, near);
          _paintKicked(canvas, view);
        }
      default:
        break;
    }
  }
}

/// A floating shard of black glass.
class _ArcShard {
  _ArcShard({
    required this.cx,
    required this.hw,
    required this.plate,
    required this.depth,
    required this.seed,
    required this.haze,
    this.face = 0,
    this.extra = 0,
  });

  final double cx, hw, plate, depth, haze;
  final int seed;

  /// A piece of carved floor (ruins) rather than glass: how tall its
  /// carved face is, and what stands on it — 0 nothing, 1 a broken column,
  /// 2 steps, 3 a sigil of glass let into the floor.
  final double face;
  final int extra;
  bool get slab => face > 0;

  /// Where feet stand at its middle, set once it is seated.
  double level = 0;

  /// Its underside, left end to right end, and its point.
  List<Offset> under = const [];
  Offset tip = Offset.zero;
  List<_ArcFacet> facets = const [];
}

/// One plane of a shard's glass: its outline, the line its gradient runs
/// along, how much of the band it gives back, and its shade at either end.
class _ArcFacet {
  _ArcFacet(this.pts, this.from, this.to, this.gloss, this.shade0, this.shade1);
  final List<Offset> pts;
  final Offset from, to;
  final double gloss, shade0, shade1;
}

// ── The day in the void ────────────────────────────────────────────────────

const _arcaneStops = [0.0, 0.18, 0.34, 0.46, 0.55, 0.62, 0.72, 0.86, 1.0];

const _arcaneNight = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF020107),
    Color(0xFF05030F),
    Color(0xFF0A0719),
    Color(0xFF110C27),
    Color(0xFF181033),
    Color(0xFF130D2A),
    Color(0xFF0B081C),
    Color(0xFF060411),
    Color(0xFF03020A),
  ],
  ambient: Color(0xFF7E7AA8),
  rim: Color(0xFF8CEFE4),
  rimStrength: 0.5,
  floor: 0.32,
  glow: 0,
  stars: 1,
  cloudTop: Color(0xFF2E1C5C),
  cloudBottom: Color(0xFF3ACFC4),
  cloudGlint: Color(0xFFCDE6FF),
  grass: [
    Color(0xFF050409),
    Color(0xFF0B0915),
    Color(0xFF141228),
    Color(0xFF1E2042),
    Color(0xFF283C5E),
    Color(0xFF336A80),
    Color(0xFF4FA2AE),
    Color(0xFF92E6E0),
  ],
  mote: Color(0xFF9AF2EA),
  firefly: 0.55,
);

const _arcanePreDawn = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF03020A),
    Color(0xFF070412),
    Color(0xFF0E081E),
    Color(0xFF180C2C),
    Color(0xFF241036),
    Color(0xFF1A0C2C),
    Color(0xFF0E081C),
    Color(0xFF070412),
    Color(0xFF04020A),
  ],
  ambient: Color(0xFF8A7AA6),
  rim: Color(0xFFB8A6F0),
  rimStrength: 0.4,
  floor: 0.3,
  glow: 0.1,
  stars: 0.9,
  cloudTop: Color(0xFF341C5A),
  cloudBottom: Color(0xFF8A5AC8),
  cloudGlint: Color(0xFFE0D2FF),
  grass: [
    Color(0xFF050409),
    Color(0xFF0B0814),
    Color(0xFF151026),
    Color(0xFF221A3E),
    Color(0xFF32285A),
    Color(0xFF4A3C7C),
    Color(0xFF7462A8),
    Color(0xFFC0AEEC),
  ],
  mote: Color(0xFFC8B8FF),
  firefly: 0.35,
);

const _arcaneDawn = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF06030C),
    Color(0xFF0E0616),
    Color(0xFF1C0A22),
    Color(0xFF300E2A),
    Color(0xFF4A1430),
    Color(0xFF320E26),
    Color(0xFF1A0818),
    Color(0xFF0C050E),
    Color(0xFF060308),
  ],
  ambient: Color(0xFFB08A9E),
  rim: Color(0xFFFF8A86),
  rimStrength: 0.65,
  floor: 0.22,
  glow: 0.65,
  stars: 0.8,
  cloudTop: Color(0xFF4A1A44),
  cloudBottom: Color(0xFFFF6A6A),
  cloudGlint: Color(0xFFFFD2D6),
  grass: [
    Color(0xFF070408),
    Color(0xFF0E0810),
    Color(0xFF1A0E1C),
    Color(0xFF2A1428),
    Color(0xFF42203A),
    Color(0xFF6A3048),
    Color(0xFFA65060),
    Color(0xFFEFA0A0),
  ],
  mote: Color(0xFFFFB0A8),
  firefly: 0.1,
);

const _arcaneSunrise = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF080818),
    Color(0xFF0E0E28),
    Color(0xFF1A163A),
    Color(0xFF2C1E48),
    Color(0xFF40264E),
    Color(0xFF2E1E44),
    Color(0xFF1A1430),
    Color(0xFF0E0A1E),
    Color(0xFF080614),
  ],
  ambient: Color(0xFFC4ACC4),
  rim: Color(0xFFFFC8A8),
  rimStrength: 0.6,
  floor: 0.25,
  glow: 0.6,
  stars: 0.7,
  cloudTop: Color(0xFF46306E),
  cloudBottom: Color(0xFFF0A890),
  cloudGlint: Color(0xFFFFE6DA),
  grass: [
    Color(0xFF07060C),
    Color(0xFF0F0C18),
    Color(0xFF1C162C),
    Color(0xFF2C2240),
    Color(0xFF46345A),
    Color(0xFF6C5074),
    Color(0xFFA8808E),
    Color(0xFFF2C8B8),
  ],
  mote: Color(0xFFFFD6B8),
  firefly: 0,
);

const _arcaneMorning = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF09091C),
    Color(0xFF0F0F30),
    Color(0xFF181744),
    Color(0xFF232156),
    Color(0xFF2C2860),
    Color(0xFF221F52),
    Color(0xFF16143A),
    Color(0xFF0D0B26),
    Color(0xFF08061A),
  ],
  ambient: Color(0xFFD0CCEC),
  rim: Color(0xFFFFEED0),
  rimStrength: 0.55,
  floor: 0.3,
  glow: 0.5,
  stars: 0.6,
  cloudTop: Color(0xFF423C88),
  cloudBottom: Color(0xFFE6D6A8),
  cloudGlint: Color(0xFFFFF4E0),
  grass: [
    Color(0xFF07070D),
    Color(0xFF0F0F1C),
    Color(0xFF1A1A30),
    Color(0xFF2A2A48),
    Color(0xFF42426A),
    Color(0xFF66668E),
    Color(0xFFA4A0BC),
    Color(0xFFF2E8D0),
  ],
  mote: Color(0xFFFFF0D2),
  firefly: 0,
);

const _arcaneDay = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF0A0A1E),
    Color(0xFF101034),
    Color(0xFF191848),
    Color(0xFF24225A),
    Color(0xFF2E2A64),
    Color(0xFF242056),
    Color(0xFF17153C),
    Color(0xFF0E0C28),
    Color(0xFF08071C),
  ],
  ambient: Color(0xFFDCD8F4),
  rim: Color(0xFFFFF4DC),
  rimStrength: 0.5,
  floor: 0.35,
  glow: 0.45,
  stars: 0.55,
  cloudTop: Color(0xFF464290),
  cloudBottom: Color(0xFFE8DCB0),
  cloudGlint: Color(0xFFFFF6E6),
  grass: [
    Color(0xFF07070D),
    Color(0xFF0F0F1C),
    Color(0xFF1A1A30),
    Color(0xFF2A2A48),
    Color(0xFF42426A),
    Color(0xFF66668E),
    Color(0xFFA4A0BC),
    Color(0xFFF2E8D0),
  ],
  mote: Color(0xFFFFF2D6),
  firefly: 0,
);

const _arcaneAfternoon = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF0B0B22),
    Color(0xFF13143C),
    Color(0xFF1E1E52),
    Color(0xFF2C2A62),
    Color(0xFF3A326A),
    Color(0xFF2C265C),
    Color(0xFF1C1842),
    Color(0xFF100D2C),
    Color(0xFF09071E),
  ],
  ambient: Color(0xFFDCCFE8),
  rim: Color(0xFFFFE6C4),
  rimStrength: 0.6,
  floor: 0.28,
  glow: 0.55,
  stars: 0.6,
  cloudTop: Color(0xFF4C3E88),
  cloudBottom: Color(0xFFF0CC98),
  cloudGlint: Color(0xFFFFEEDC),
  grass: [
    Color(0xFF08070D),
    Color(0xFF100E1A),
    Color(0xFF1C182E),
    Color(0xFF2C2644),
    Color(0xFF463C62),
    Color(0xFF6C5C80),
    Color(0xFFAC94A8),
    Color(0xFFF4DCC0),
  ],
  mote: Color(0xFFFFE6C4),
  firefly: 0,
);

const _arcaneGolden = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF0A091C),
    Color(0xFF141232),
    Color(0xFF241C46),
    Color(0xFF3A2652),
    Color(0xFF56304E),
    Color(0xFF3E2446),
    Color(0xFF221630),
    Color(0xFF120C20),
    Color(0xFF0A0716),
  ],
  ambient: Color(0xFFD0B4C4),
  rim: Color(0xFFFFB890),
  rimStrength: 0.7,
  floor: 0.22,
  glow: 0.7,
  stars: 0.65,
  cloudTop: Color(0xFF52306E),
  cloudBottom: Color(0xFFFF9C78),
  cloudGlint: Color(0xFFFFE0CC),
  grass: [
    Color(0xFF08060C),
    Color(0xFF100C16),
    Color(0xFF1E1426),
    Color(0xFF30203A),
    Color(0xFF4C3050),
    Color(0xFF784866),
    Color(0xFFB87074),
    Color(0xFFFFC0A0),
  ],
  mote: Color(0xFFFFC8A0),
  firefly: 0,
);

const _arcaneSunset = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF07040C),
    Color(0xFF100616),
    Color(0xFF200A22),
    Color(0xFF380E2A),
    Color(0xFF58142C),
    Color(0xFF3C0E24),
    Color(0xFF1E0816),
    Color(0xFF0E050E),
    Color(0xFF070308),
  ],
  ambient: Color(0xFFB88A98),
  rim: Color(0xFFFF7A70),
  rimStrength: 0.75,
  floor: 0.18,
  glow: 0.8,
  stars: 0.75,
  cloudTop: Color(0xFF561A40),
  cloudBottom: Color(0xFFFF5C5C),
  cloudGlint: Color(0xFFFFC8C8),
  grass: [
    Color(0xFF070408),
    Color(0xFF0E0810),
    Color(0xFF1A0E1C),
    Color(0xFF2A1428),
    Color(0xFF42203A),
    Color(0xFF6A3048),
    Color(0xFFA65060),
    Color(0xFFEFA0A0),
  ],
  mote: Color(0xFFFFA098),
  firefly: 0.15,
);

const _arcaneDusk = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF040209),
    Color(0xFF080412),
    Color(0xFF10081E),
    Color(0xFF1C0C2C),
    Color(0xFF261034),
    Color(0xFF1A0C2A),
    Color(0xFF0E081C),
    Color(0xFF070410),
    Color(0xFF04020A),
  ],
  ambient: Color(0xFF8E7EA6),
  rim: Color(0xFFC890D8),
  rimStrength: 0.45,
  floor: 0.3,
  glow: 0.2,
  stars: 0.95,
  cloudTop: Color(0xFF3A1C5A),
  cloudBottom: Color(0xFF9A60C0),
  cloudGlint: Color(0xFFE6D0FF),
  grass: [
    Color(0xFF050409),
    Color(0xFF0B0814),
    Color(0xFF151026),
    Color(0xFF221A3E),
    Color(0xFF32285A),
    Color(0xFF4A3C7C),
    Color(0xFF7462A8),
    Color(0xFFC0AEEC),
  ],
  mote: Color(0xFFD0B0FF),
  firefly: 0.4,
);

const _arcaneKeys = <(double, _Light)>[
  (0, _arcaneNight),
  (4.4, _arcaneNight),
  (5.0, _arcanePreDawn),
  (5.6, _arcaneDawn),
  (6.4, _arcaneSunrise),
  (7.8, _arcaneMorning),
  (10.0, _arcaneDay),
  (15.5, _arcaneDay),
  (17.6, _arcaneAfternoon),
  (18.7, _arcaneGolden),
  (19.4, _arcaneSunset),
  (20.1, _arcaneDusk),
  (21.0, _arcaneNight),
  (24, _arcaneNight),
];
