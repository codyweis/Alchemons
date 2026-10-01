part of 'grain_field.dart';

// Skyward Reach, through the day.
//
// High over a sea of cloud, isles of pale stone float with grass on their
// backs and roots trailing under them; water runs off the end of one or two
// and falls away into spray. Towers of cumulus stand on the horizon and high
// cloud drifts overhead. The light follows the phone's clock like the
// Valley's: the cloud sea goes gold under a low sun and silver under the
// moon, and at this height the stars come all the way down to it. Drag a
// finger through an isle's grass and it parts and sheds grains.
//
// Layers, matching the scene's spawn anchors:
//   sky     — screen-fixed (the camera backdrop): sun, moon, stars
//   layer2  — high cloud (drifting), towers on the horizon, the far sea
//   layer3  — the cloud sea's billows and the distant isles
//   layer4  — the isles the creatures stand on
//   layer5  — wisps of cloud blowing past, nearest of all
//
// The isles the creatures use are built from the spawn points: one under
// each standing creature, and one under the place each encounter's partner
// stands, so a partner that cannot float always has ground.
//
// Still sheets are baked as maps (see field_art.dart), read through the
// hour's grades:
//   sea     r = shade down between the tops, g = glitter, b = haze
//   cloud   r = underside, g = glitter
//   isles   r = haze, b = shade, g = fleck

class SkyField extends _GrainField {
  SkyField();

  static const far = SceneLayer.layer2;
  static const mid = SceneLayer.layer3;
  static const near = SceneLayer.layer4;
  static const fore = SceneLayer.layer5;

  static const _gSea = 0, _gCloud = 1, _gRock = 2, _gTurf = 3, _gTree = 4;

  /// Daylight colours of the isles; the hour's ambient light multiplies them.
  static const _albedo = <int, Color>{
    _gRock: Color(0xFFB8B4AE),
    _gTurf: Color(0xFF4E8248),
    _gTree: Color(0xFF2C5C3E),
  };

  /// How fast the high cloud drifts, in units a second at the reference
  /// height.
  static const _drift = 2.4;

  @override
  List<(double, _Light)> get _keys => _skyKeys;

  // The far cloud sea is the horizon, and above the weather the stars reach
  // right down to it.
  @override
  double get _horizon => 0.6;

  @override
  int get _starCount => 230;

  @override
  double get _starDepth => 0.62;

  @override
  double _lightK(SceneLayer layer) => switch (layer) {
    far => 1.0,
    mid => 0.92,
    _ => 0.85,
  };

  @override
  void _buildGrades(_Light l) {
    final hazeIsle = l.skyAt(0.5), hazeLow = l.skyAt(0.6);
    Color sil(int g) {
      final a = _albedo[g]!;
      return Color.from(
        alpha: 1,
        red: a.r * l.ambient.r,
        green: a.g * l.ambient.g,
        blue: a.b * l.ambient.b,
      );
    }

    final seaTop = l.seaTop ?? l.cloudTop, seaDeep = l.seaDeep ?? l.cloudBottom;
    _grades[_gSea] = fieldGrade(
      base: seaTop,
      r: fieldDiff(seaDeep, seaTop),
      g: fieldScale(l.cloudGlint, 0.85),
      b: fieldDiff(hazeLow, seaTop),
    );
    _grades[_gCloud] = fieldGrade(
      base: l.cloudTop,
      r: fieldDiff(l.cloudBottom, l.cloudTop),
      g: fieldScale(l.cloudGlint, 0.85),
      b: (0, 0, 0),
    );
    for (final g in [_gRock, _gTurf, _gTree]) {
      final s = sil(g);
      _grades[g] = fieldGrade(
        base: s,
        r: fieldDiff(hazeIsle, s),
        g: (
          s.r * 0.9 + l.rim.r * l.rimStrength * 0.4,
          s.g * 0.9 + l.rim.g * l.rimStrength * 0.4,
          s.b * 0.9 + l.rim.b * l.rimStrength * 0.4,
        ),
        b: fieldScale(s, -0.72),
      );
    }
  }

  // ── Where the creatures stand ────────────────────────────────────────────

  /// The isles of the mid and near layers, as built for this screen.
  final Map<SceneLayer, List<_Isle>> _isles = {};

  /// Every standing point on the near and mid layers stands on its own isle,
  /// seated by the creature's feet.
  @override
  double? perchFor(String spawnId) {
    for (final p in _spawns) {
      if (p.id != spawnId || p.aloft) continue;
      if (p.anchor == near || p.anchor == mid) return _feet(p);
    }
    return null;
  }

  /// The isle over [x] on [layer], and [x] moved into that isle's own loop.
  (_Isle, double)? _isleAt(SceneLayer layer, double x, {double reach = 1}) {
    for (final i in _isles[layer] ?? const <_Isle>[]) {
      final d = _loopDelta(x, i.cx, layer);
      if (d.abs() < i.hw * reach) return (i, i.cx + d);
    }
    return null;
  }

  // On an isle there is no deeper ground to stand in: anything over it that
  // cannot float is stood on its top.
  @override
  ({double top, double rest})? groundAt(SceneLayer layer, double x) {
    final at = _isleAt(layer, x, reach: 0.86);
    if (at == null) return null;
    final (i, lx) = at;
    return (top: double.infinity, rest: _stand(i, lx) + 1 * _u);
  }

  /// The grass on a near isle a finger at [x], [y] is in, if any.
  double? _inGrass(double x, double y) {
    final at = _isleAt(near, x, reach: 0.97);
    if (at == null) return null;
    final (i, lx) = at;
    final back = _back(i, lx);
    if (y < back - 30 * _u || y > _front(i, lx) + 14 * _u) return null;
    return back;
  }

  /// Places for isles nobody stands on: (x as a share of the loop, where
  /// feet would stand as a share of the height, half width, a tree, which
  /// end water runs off: -1 left, 1 right, 0 none).
  static const _nearScenery = <(double, double, double, bool, int)>[
    (0.235, 0.22, 40, false, 0),
    (0.69, 0.47, 96, true, 1),
    (0.972, 0.75, 64, false, -1),
  ];
  static const _midScenery = <(double, double, double, bool, int)>[
    (0.10, 0.33, 40, true, 0),
    (0.40, 0.30, 36, false, 0),
    (0.74, 0.58, 34, true, 0),
  ];

  /// The isles on [layer] as built: each one's span, from the top of its
  /// turf (or tree) to the point of its rock.
  @visibleForTesting
  List<Rect> debugIsles(SceneLayer layer) => [
    for (final i in _isles[layer] ?? const <_Isle>[])
      Rect.fromLTRB(
        i.cx - i.hw,
        i.tree ? _back(i, i.cx) - _treeOf(i).h * 1.2 : _back(i, i.cx),
        i.cx + i.hw,
        _bottom(i, _tipX(i)),
      ),
  ];

  List<_Isle> _makeIsles(SceneLayer layer) {
    final w = _widths[layer] ?? _worldWidth;
    final small = layer == mid;
    final isles = <_Isle>[];
    var seed = small ? 200 : 100;
    _Isle isle(
      double cx,
      double hw,
      double stand, {
      double? seatX,
      bool tree = false,
      int fall = 0,
    }) {
      final s = seed++;
      final i = _Isle(
        cx: cx,
        hw: hw,
        depth: hw * FieldRandom(s * 13).range(0.8, 1.15) * (small ? 0.9 : 1),
        plate: (small ? 8.5 : 11) * _u,
        seed: s,
        haze: small ? 0.3 : 0.0,
        tree: tree,
        fall: fall,
      );
      // Seat it so feet at [seatX] stand at [stand].
      i.level = stand - _stand(i, seatX ?? cx);
      return i;
    }

    for (final p in _spawns.where((p) => p.anchor == layer)) {
      final x = _spawnX(p);
      final side = p.partnerSide;
      // Isles under creatures are sized by the creatures, not the screen:
      // the pace between a pair is the same on every screen.
      if (!p.aloft) {
        // Under the creature, reaching a little further toward its partner.
        final hw = p.size.x * 1.3;
        isles.add(isle(x + side * hw * 0.16, hw, _feet(p), seatX: x));
      }
      // Under where its encounter partner stands.
      final bp = p.getBattlePos();
      final px = x + side * kFieldPairGap;
      final hw = p.size.x * 0.85;
      isles.add(
        isle(px + side * hw * 0.1, hw, bp.dy * _h + p.size.y * 0.5, seatX: px),
      );
    }
    for (final (fx, fy, fhw, tree, fall)
        in small ? _midScenery : _nearScenery) {
      isles.add(isle(fx * w, fhw * _u, fy * _h, tree: tree, fall: fall));
    }
    return isles;
  }

  // ── An isle's shape (layer-local units) ──────────────────────────────────

  double _t(_Isle i, double x) => ((x - i.cx) / i.hw).clamp(-1.0, 1.0);

  /// Where feet stand on [i] at [x]: a gentle crown, falling away at the
  /// ends, a little uneven.
  double _stand(_Isle i, double x) {
    final t = _t(i, x);
    return i.level +
        i.hw * 0.07 * math.pow(t.abs(), 4) +
        i.plate * 0.22 * fieldNoise(x / (24 * _u), i.seed);
  }

  double _pinch(_Isle i, double x) =>
      (1 - math.pow(_t(i, x).abs(), 6)).toDouble();

  /// The back of its top, where the grass is rooted against the sky.
  double _back(_Isle i, double x) =>
      _stand(i, x) - i.plate * 0.55 * _pinch(i, x);

  /// The front lip of its top, where the rock begins.
  double _front(_Isle i, double x) =>
      _stand(i, x) + i.plate * 0.45 * _pinch(i, x);

  /// Where the underside hangs to its point.
  double _tipX(_Isle i) => i.cx + (fieldHash(i.seed, 77) - 0.5) * 0.5 * i.hw;

  /// The underside: rock hanging to a ragged point off centre — on some
  /// isles a lesser second point beside it.
  double _bottom(_Isle i, double x) {
    final t = _t(i, x);
    final k = (_tipX(i) - i.cx) / i.hw;
    double hang(double k, double sharp) {
      final s = t >= k ? (t - k) / (1 - k) : (t - k) / (1 + k);
      return math
          .pow(math.max(0.0, 1 - math.pow(s.abs(), sharp)), 1.4)
          .toDouble();
    }

    var prof = hang(k, 1.6);
    if (fieldHash(i.seed, 79) < 0.5) {
      final k2 = (k + (k > 0 ? -0.62 : 0.62)).clamp(-0.8, 0.8);
      prof = math.max(prof * 0.92, hang(k2, 2.4) * 0.62);
    }
    final jag =
        1 +
        0.16 * fieldNoise(x / (9 * _u), i.seed + 3) +
        0.08 * fieldNoise(x / (3.4 * _u), i.seed + 5);
    return _front(i, x) + i.depth * prof * jag;
  }

  /// How deep the band of earth under its turf is at [x].
  double _soil(_Isle i, double x) =>
      (i.haze > 0 ? 0.6 : 1) *
      _u *
      (3.4 + 2.2 * (fieldNoise(x / (11 * _u), i.seed + 9) * 0.5 + 0.5)) *
      _pinch(i, x);

  /// A tree on [i]: where it stands and how tall, away from the end water
  /// runs off.
  ({double x, double h}) _treeOf(_Isle i) {
    final r = FieldRandom(i.seed * 17 + 3);
    final x = i.cx + (i.fall == 0 ? r.range(-0.4, 0.4) : -i.fall * 0.32) * i.hw;
    return (x: x, h: r.range(0.55, 0.75) * i.hw * (i.haze > 0 ? 1.1 : 0.85));
  }

  Rect _isleBounds(_Isle i) {
    final top = i.tree ? _back(i, i.cx) - _treeOf(i).h * 1.5 : _back(i, i.cx);
    return Rect.fromLTRB(
      i.cx - i.hw - 24 * _u,
      top - 24 * _u,
      i.cx + i.hw + 24 * _u,
      _front(i, i.cx) + i.depth * 1.45 + 60 * _u,
    );
  }

  // ── Layout for the current screen ────────────────────────────────────────

  _Blades? _nearBlades;
  _Motes? _motes;
  double _nearWidth = 0;
  _Glints _cloudGlints = _Glints();
  final List<_Fall> _falls = [];
  final GrainBatch _fallBatch = GrainBatch(6);

  @override
  List<FieldSheet> build(SceneLayer layer, Size size, Size screen) {
    _h = size.height;
    _u = _h / 475;
    _screen = screen;
    final w = size.width;
    _widths[layer] = w;
    switch (layer) {
      case far:
        _cloudWidth = w;
        _glints[far] = _Glints();
        _cloudGlints = _Glints();
        final towers = Rect.fromLTWH(0, _h * 0.03, w, _h * 0.84);
        return [
          FieldSheet(
            bounds: Rect.fromLTWH(0, 0, w, _h * 0.42),
            drift: _drift * _u,
            resolution: 0.7,
            grade: _gCloud,
            paint: (c) =>
                _sinkingInto(_cloudGlints, w, () => _paintHighCloud(c, w)),
          ),
          FieldSheet(
            bounds: towers,
            resolution: 0.8,
            grade: _gSea,
            paint: (c) => _sinking(far, () => _paintPuffs(c, _farPuffs(w))),
          ),
          FieldSheet(
            bounds: towers,
            resolution: 0.6,
            light: true,
            paint: (c) => _paintPuffs(c, _farPuffs(w), light: true),
          ),
        ];
      case mid:
        _glints[mid] = _Glints();
        final isles = _isles[mid] = _makeIsles(mid);
        final sea = Rect.fromLTWH(0, _h * 0.6, w, _h * 0.4);
        return [
          FieldSheet(
            bounds: sea,
            resolution: 0.8,
            grade: _gSea,
            paint: (c) => _sinking(mid, () => _paintPuffs(c, _seaPuffs(w))),
          ),
          FieldSheet(
            bounds: sea,
            resolution: 0.6,
            light: true,
            paint: (c) => _paintPuffs(c, _seaPuffs(w), light: true),
          ),
          for (final i in isles) ..._isleSheets(mid, i),
        ];
      case near:
        _glints[near] = _Glints();
        _nearWidth = w;
        final isles = _isles[near] = _makeIsles(near);
        _nearBlades = _isleGrass(isles);
        _motes = _Motes.make(w, _h, _u);
        _falls
          ..clear()
          ..addAll([
            for (final i in isles)
              if (i.fall != 0) _fallOf(i),
          ]);
        return [for (final i in isles) ..._isleSheets(near, i)];
      case fore:
        return [
          FieldSheet(
            bounds: Rect.fromLTWH(0, _h * 0.78, w, _h * 0.24),
            drift: 16 * _u,
            resolution: 0.45,
            grade: _gSea,
            paint: (c) => _paintWisps(c, w),
          ),
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

  // ── Cloud ────────────────────────────────────────────────────────────────

  /// High cloud: soft banks like the Valley's, their undersides catching a
  /// low sun.
  void _paintHighCloud(Canvas c, double w) {
    final r = FieldRandom(111);
    final grains = GrainBatch(4);
    final banks = math.max(3, (w / (430 * _u)).round());
    _highClouds.clear();
    for (var b = 0; b < banks; b++) {
      final cx = (b + r.range(0.15, 0.85)) * w / banks;
      final cy = _h * r.range(0.08, 0.3);
      final low = ((cy / _h - 0.08) / 0.22).clamp(0.0, 1.0);
      final width = r.range(90, 190) * _u * (0.8 + 0.6 * low);
      final height = width * r.range(0.11, 0.17) * (1 - 0.3 * low);
      _highClouds.add(
        Rect.fromCenter(
          center: Offset(cx, cy - height * 0.3),
          width: width * 1.05,
          height: height * 2.1,
        ),
      );
      for (final dx in [-w, 0.0, w]) {
        _cloud(c, grains, cx + dx, cy, width, height, low, 2000 + b, w);
      }
    }
    for (var i = 0; i < 4; i++) {
      grains.draw(c, i, 1.25 * _u, fieldMap(1, 0.4 + i * 0.2, 0, 0.9));
    }
  }

  /// Wisps blowing past low down: torn ends of the cloud sea.
  void _paintWisps(Canvas c, double w) {
    final r = FieldRandom(707);
    final grains = GrainBatch(4);
    final n = math.max(2, (w / (760 * _u)).round());
    for (var k = 0; k < n; k++) {
      final cx = (k + r.range(0.1, 0.9)) * w / n;
      final cy = _h * r.range(0.9, 0.97);
      final width = r.range(150, 280) * _u;
      for (final dx in [-w, 0.0, w]) {
        _cloud(c, grains, cx + dx, cy, width, width * 0.16, 0.3, 3000 + k, w);
      }
    }
  }

  // ── The cloud sea and the towers on it ───────────────────────────────────

  /// The towers of cumulus on the horizon, then the far sea in front of
  /// their feet — in drawing order.
  List<_Puff> _farPuffs(double w) {
    final out = <_Puff>[];
    final r = FieldRandom(121);
    final n = math.max(2, (w / (640 * _u)).round());
    final horizon = _h * 0.6;
    for (var k = 0; k < n; k++) {
      final x = (k + r.range(0.2, 0.8)) * w / n;
      final width = r.range(130, 200) * _u;
      final height = r.range(0.34, 0.48) * _h;
      final tower = _tower(x, horizon + 6 * _u, width, height, 1200 + k);
      _wrappedPuffs(tower, w, width, out);
    }
    _towerHeads = List.of(out);
    double swell(double x) => fieldLoopNoise(x, 120 * _u, 131, w) * 3 * _u;
    final sea = <_Puff>[];
    var x = 0.0;
    var i = 0;
    while (x < w) {
      final rad = r.range(7, 16) * _u;
      sea.add(
        _Puff(
          x,
          horizon + rad * 0.55 + swell(x),
          rad * r.range(1.3, 1.9),
          rad,
          r0: 0.05,
          r1: 0.5,
          haze: 0.62,
          grains: 0.6,
          seed: 1300 + i++,
        ),
      );
      x += rad * r.range(1.1, 1.7);
    }
    final seaRow = <_Puff>[];
    _wrappedPuffs(sea, w, 40 * _u, seaRow);
    seaRow.sort((a, b) => a.y.compareTo(b.y));
    out
      ..add(
        _Puff.fill(
          _edge(w, (x) => horizon + 6 * _u + swell(x)),
          _h * 0.87,
          r: 0.42,
          haze: 0.5,
        ),
      )
      ..addAll(seaRow);
    return out;
  }

  /// One tower: rounded heads stacked on a broadening column, drawn from
  /// the base up so each head's shaded underside lies on the lit top of the
  /// one below.
  List<_Puff> _tower(
    double x,
    double base,
    double width,
    double height,
    int seed,
  ) {
    final r = FieldRandom(seed);
    final out = <_Puff>[];
    final levels = 7 + (r.next() * 4).floor();
    final lean = r.range(-0.12, 0.22) * height;
    var i = 0;
    for (var k = 0; k < levels; k++) {
      final f = k / (levels - 1);
      final y = base - height * (0.06 + 0.82 * math.pow(f, 0.9));
      // Each level its own width and its own count of heads, the column
      // swelling and pinching, so its sides never repeat.
      final half =
          width * 0.5 * (1 - 0.55 * f) * (0.72 + 0.5 * fieldHash(k, seed));
      final cx = x + lean * f * f + r.range(-0.12, 0.12) * half;
      final n = 1 + (half / (24 * _u)).round() + (r.next() * 2).floor();
      for (var j = 0; j < n; j++) {
        final s = n == 1 ? r.range(-0.3, 0.3) : j / (n - 1) * 2 - 1;
        final rad = half * r.range(0.36, 0.6) * (1 - 0.2 * s.abs());
        out.add(
          _Puff(
            cx + s * half * r.range(0.55, 0.8),
            y + s.abs() * rad * 0.3 + r.range(-0.45, 0.45) * rad,
            rad * r.range(1.0, 1.25),
            rad * r.range(0.8, 1.0),
            r0: 0.3 * (1 - f),
            r1: 0.3 * (1 - f) + 0.24,
            haze: 0.5 * (1 - f) + 0.08,
            grains: 1,
            seed: seed * 64 + i++,
          ),
        );
      }
    }
    // The crown: a few heads billowing out of the top.
    final top = base - height * 0.9;
    final cx = x + lean;
    for (var j = 0; j < 3; j++) {
      final rad = width * r.range(0.16, 0.24);
      out.add(
        _Puff(
          cx + (j - 1) * rad * 1.1 + r.range(-0.2, 0.2) * rad,
          top + r.range(-0.3, 0.4) * rad,
          rad * 1.1,
          rad * 0.95,
          r0: 0.0,
          r1: 0.3,
          haze: 0.06,
          grains: 1,
          seed: seed * 64 + i++,
        ),
      );
    }
    // Turrets: small heads bulging out of the top of each, so the outline
    // is cauliflower, not a run of smooth ovals.
    final heads = List.of(out);
    for (final h in heads) {
      final k = 3 + (r.next() * 4).floor();
      for (var j = 0; j < k; j++) {
        final a = -math.pi * (0.15 + 0.7 * (j + r.range(0.2, 0.8)) / k);
        final rad = h.ry * r.range(0.18, 0.34);
        out.add(
          _Puff(
            h.x + math.cos(a) * h.rx * 0.82,
            h.y + math.sin(a) * h.ry * 0.82 + rad * 0.2,
            rad * r.range(1.0, 1.25),
            rad,
            r0: h.r0,
            r1: h.r0 + (h.r1 - h.r0) * 0.6,
            haze: h.haze,
            grains: h.grains,
            seed: seed * 64 + i++,
          ),
        );
      }
    }
    // Bottom first.
    out.sort((a, b) => b.y.compareTo(a.y));
    return out;
  }

  /// The near cloud sea: rows of billows, each lower and larger than the
  /// last, every billow lit on top and shaded beneath — in drawing order.
  List<_Puff> _seaPuffs(double w) {
    final out = <_Puff>[];
    final r = FieldRandom(141);
    var seed = 1400;
    for (final (crest, lo, hi, haze, fill) in [
      (0.655, 10.0, 20.0, 0.46, 0.7),
      (0.71, 16.0, 32.0, 0.3, 0.78),
      (0.79, 26.0, 50.0, 0.16, 0.86),
      (0.9, 40.0, 76.0, 0.04, 0.96),
    ]) {
      final row = <_Puff>[];
      final swellSeed = seed;
      double swell(double x) => fieldLoopNoise(x, 160 * _u, swellSeed, w) * 0.7;
      var x = 0.0;
      while (x < w) {
        final rad = r.range(lo, hi) * _u;
        row.add(
          _Puff(
            x,
            _h * crest + rad * (0.5 + swell(x)),
            rad * r.range(1.45, 1.95),
            rad * r.range(0.56, 0.74),
            r0: 0.0,
            r1: 0.64,
            haze: haze,
            grains: 1 - haze,
            seed: seed++,
          ),
        );
        x += rad * r.range(1.0, 1.5);
      }
      final copies = <_Puff>[];
      _wrappedPuffs(row, w, hi * 2 * _u, copies);
      copies.sort((a, b) => a.y.compareTo(b.y));
      // Solid sea behind the row, its edge just under the billows' middles
      // wherever the swell carries them.
      final mean = (lo + hi) / 2 * _u;
      out
        ..add(
          _Puff.fill(
            _edge(w, (x) => _h * crest + mean * (0.85 + swell(x))),
            _h * fill + 30,
            r: 0.8,
            haze: haze,
          ),
        )
        ..addAll(copies);
    }
    return out;
  }

  /// A line across a sheet [w] wide at [y], sampled finely enough to follow
  /// a swell.
  List<Offset> _edge(double w, double Function(double x) y) => [
    for (var x = -8.0; x <= w + 8; x += 6 * _u) Offset(x, y(x)),
    Offset(w + 8, y(w + 8)),
  ];

  /// [puffs], plus a copy a loop away of each that reaches over an edge.
  void _wrappedPuffs(
    List<_Puff> puffs,
    double w,
    double reach,
    List<_Puff> out,
  ) {
    for (final p in puffs) {
      out.add(p);
      if (!_loop) continue;
      if (p.x - p.rx - reach < 0) out.add(p.shifted(w));
      if (p.x + p.rx + reach > w) out.add(p.shifted(-w));
    }
  }

  /// Paints [puffs] in order: as maps, each soft-edged and shaded from its
  /// lit top down, with glitter on its crown; or, for a light sheet, as the
  /// light on each crown, with each puff first wiping out the light behind
  /// it so nothing hidden shines through.
  void _paintPuffs(Canvas c, List<_Puff> puffs, {bool light = false}) {
    final grains = GrainBatch(4);
    final wipe = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = const Color(0xFFFFFFFF);
    for (final p in puffs) {
      final edge = p.edge;
      if (edge != null) {
        final body = Path()..addPolygon(edge, false);
        body
          ..lineTo(edge.last.dx, p.y2)
          ..lineTo(edge.first.dx, p.y2)
          ..close();
        if (light) {
          c.drawPath(body, wipe);
          continue;
        }
        c.drawPath(
          body,
          Paint()
            ..shader = Gradient.linear(Offset(0, p.y), Offset(0, p.y2), [
              fieldMap(p.r0 * 0.6, 0, p.haze),
              fieldMap(p.r0, 0, p.haze * 0.7),
            ]),
        );
        continue;
      }
      final oval = Rect.fromCenter(
        center: Offset(p.x, p.y),
        width: p.rx * 2,
        height: p.ry * 2,
      );
      if (light) {
        c.drawOval(oval, wipe);
        // The crown: a soft cap of light from the top down to the middle.
        c.drawOval(
          Rect.fromCenter(
            center: Offset(p.x, p.y - p.ry * 0.3),
            width: p.rx * 1.7,
            height: p.ry * 1.3,
          ),
          Paint()
            ..shader = Gradient.linear(
              Offset(0, p.y - p.ry),
              Offset(0, p.y - p.ry * 0.05),
              [
                const Color(0xFFFFFFFF).withValues(alpha: 0.55),
                const Color(0x00FFFFFF),
              ],
            ),
        );
        continue;
      }
      c.drawOval(
        oval,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, p.y - p.ry),
            Offset(0, p.y + p.ry),
            [
              fieldMap(p.r0, 0, p.haze),
              fieldMap(p.r0 + (p.r1 - p.r0) * 0.55, 0, p.haze),
              fieldMap(p.r1, 0, p.haze),
            ],
            const [0.0, 0.4, 1.0],
          ),
      );
      // Glitter along the rim of the crown, thickest at the very top.
      if (p.grains <= 0) continue;
      final r = FieldRandom(p.seed);
      final n = (p.rx * 2.2 * p.grains / (3.2 * _u)).round();
      for (var i = 0; i < n; i++) {
        final a = -math.pi * (0.12 + 0.76 * r.next());
        final lit = -math.sin(a);
        if (r.next() > lit * lit) continue;
        final d = 1 - math.pow(r.next(), 2) * 0.16;
        final x = p.x + math.cos(a) * p.rx * d,
            y = p.y + math.sin(a) * p.ry * d;
        final tone = (lit * 3.2 + r.next() * 0.8 - 0.9).round();
        if (tone < 0) continue;
        grains.add(tone.clamp(0, 3), x, y + 0.8 * _u);
        if (tone >= 3 && r.next() < 0.03) _glint(_wrapX(x), y + 0.8 * _u);
      }
      // Down with its own puff, so the ones in front cover it.
      _drawGrains(c, grains);
    }
  }

  void _drawGrains(Canvas c, GrainBatch grains) {
    for (var i = 0; i < 4; i++) {
      grains.draw(c, i, 1.3 * _u, fieldMap(0, 0.35 + i * 0.22, 0, 0.85));
    }
    grains.clear();
  }

  /// [x] moved into the loop being gathered, so a glint on something drawn
  /// once across a seam still lands.
  double _wrapX(double x) {
    if (!_loop || _sinkWidth == double.infinity) return x;
    return x - _sinkWidth * (x / _sinkWidth).floorToDouble();
  }

  // ── Isles ────────────────────────────────────────────────────────────────

  List<FieldSheet> _isleSheets(SceneLayer layer, _Isle i) {
    final b = _isleBounds(i);
    final res = layer == mid ? 0.8 : 1.0;
    return [
      FieldSheet(
        bounds: b,
        resolution: res,
        grade: _gRock,
        paint: (c) => _paintRock(c, i),
      ),
      FieldSheet(
        bounds: b,
        resolution: res,
        grade: _gTurf,
        paint: (c) => _paintTurf(c, i),
      ),
      if (i.tree)
        FieldSheet(
          bounds: b,
          resolution: res,
          grade: _gTree,
          paint: (c) => _paintTree(c, null, i),
        ),
      FieldSheet(
        bounds: b,
        resolution: res * 0.9,
        light: true,
        paint: (c) => _sinking(layer, () => _paintIsleLight(c, i)),
      ),
    ];
  }

  Path _rockOutline(_Isle i) {
    final x0 = i.cx - i.hw, x1 = i.cx + i.hw;
    final step = 2.2 * _u;
    final path = Path()..moveTo(x0, _front(i, x0));
    for (var x = x0; x <= x1; x += step) {
      path.lineTo(x, _front(i, x));
    }
    path.lineTo(x1, _front(i, x1));
    for (var x = x1; x >= x0; x -= step) {
      path.lineTo(x, _bottom(i, x));
    }
    return path..close();
  }

  /// The facets of an isle's rock: broad planes split down its face,
  /// converging toward the point, each a quad (top left, top right, bottom
  /// right, bottom left) with its shade at top and bottom.
  List<(List<Offset>, double, double)> _facets(_Isle i) {
    final r = FieldRandom(i.seed * 7 + 1);
    final x0 = i.cx - i.hw, x1 = i.cx + i.hw;
    final tip = Offset(_tipX(i), _bottom(i, _tipX(i)) + 8 * _u);
    final cuts = <double>[x0 - 2 * _u];
    var x = x0;
    while (true) {
      x += i.hw * r.range(0.2, 0.4);
      if (x >= x1 - i.hw * 0.12) break;
      cuts.add(x);
    }
    cuts.add(x1 + 2 * _u);
    Offset down(double x) => Offset(
      tip.dx + (x - tip.dx) * r.range(0.08, 0.2),
      tip.dy + r.range(0, 6) * _u,
    );
    final out = <(List<Offset>, double, double)>[];
    var lowA = down(cuts.first);
    for (var k = 0; k + 1 < cuts.length; k++) {
      final a = cuts[k], b = cuts[k + 1];
      final lowB = down(b);
      final side = (((a + b) / 2) - i.cx) / i.hw;
      final turn = math.pow(side.abs(), 1.6).toDouble();
      final own = r.range(-0.045, 0.045);
      out.add((
        [
          Offset(a, _front(i, a) - 2 * _u),
          Offset(b, _front(i, b) - 2 * _u),
          lowB,
          lowA,
        ],
        0.14 + 0.26 * turn + own,
        0.56 + 0.18 * turn + own,
      ));
      lowA = lowB;
    }
    return out;
  }

  void _paintRock(Canvas c, _Isle i) {
    final body = _rockOutline(i);
    final haze = i.haze;
    c.drawPath(body, Paint()..color = fieldMap(haze, 0, 0.55));
    c
      ..save()
      ..clipPath(body);
    final top = _front(i, i.cx), tipY = _bottom(i, _tipX(i));
    for (final (pts, s0, s1) in _facets(i)) {
      c.drawPath(
        Path()..addPolygon(pts, true),
        Paint()
          ..shader = Gradient.linear(Offset(0, top), Offset(0, tipY), [
            fieldMap(haze, 0, s0),
            fieldMap(haze, 0, s1),
          ]),
      );
    }
    // Strata: a lit ledge with a shadow under it, twice down the face.
    final x0 = i.cx - i.hw, x1 = i.cx + i.hw;
    final step = 2.5 * _u;
    for (final (f, wobble) in [(0.3, 0.04), (0.58, 0.06)]) {
      double at(double x) =>
          _front(i, x) +
          (_bottom(i, x) - _front(i, x)) *
              (f + wobble * fieldNoise(x / (20 * _u), i.seed + 21));
      for (final (off, thick, shade) in [(0.0, 1.6, 0.12), (1.6, 3.2, 0.82)]) {
        final band = Path()..moveTo(x0, at(x0) + off * _u);
        for (var x = x0; x <= x1; x += step) {
          band.lineTo(x, at(x) + off * _u);
        }
        for (var x = x1; x >= x0; x -= step) {
          band.lineTo(x, at(x) + (off + thick) * _u);
        }
        c.drawPath(
          band..close(),
          Paint()..color = fieldMap(haze, 0, shade, 0.55),
        );
      }
    }
    // The band of earth under the turf.
    final soil = Path()..moveTo(x0, _front(i, x0));
    for (var x = x0; x <= x1; x += step) {
      soil.lineTo(x, _front(i, x) - 1 * _u);
    }
    for (var x = x1; x >= x0; x -= step) {
      soil.lineTo(x, _front(i, x) + _soil(i, x));
    }
    c.drawPath(soil..close(), Paint()..color = fieldMap(haze, 0, 0.84));
    // Weathering: darker pits and paler flecks, as grains.
    final grains = GrainBatch(2);
    final r = FieldRandom(i.seed * 5 + 2);
    final n = (i.hw * i.depth * 0.9 / (_u * _u * 16)).round();
    for (var k = 0; k < n; k++) {
      final x = i.cx + (r.next() * 2 - 1) * i.hw;
      final y = _front(i, x) + r.next() * (_bottom(i, x) - _front(i, x));
      grains.add(r.next() < 0.6 ? 0 : 1, x, y);
    }
    grains.draw(c, 0, 1.5 * _u, fieldMap(haze, 0, 0.7, 0.55));
    grains.draw(c, 1, 1.3 * _u, fieldMap(haze, 0.22, 0.05, 0.5));
    c.restore();

    // Roots hanging from under the turf, some past the point.
    final rr = FieldRandom(i.seed * 11 + 4);
    final roots = 2 + (i.hw / (55 * _u)).floor();
    for (var k = 0; k < roots; k++) {
      final x = i.cx + rr.range(-0.7, 0.7) * i.hw;
      final y = _front(i, x) + _soil(i, x) * 0.4;
      final reach = _bottom(i, x) - y;
      final len = reach * rr.range(0.25, 0.6) + rr.range(4, 10) * _u;
      final width = rr.range(3.2, 5.2) * _u * (haze > 0 ? 0.6 : 1);
      _root(c, x, y, len, width, rr.range(-1, 1), fieldMap(haze, 0, 0.74));
    }
  }

  /// A root: a tapered tendril hanging and swaying a little to one side.
  void _root(
    Canvas c,
    double x,
    double y,
    double len,
    double width,
    double sway,
    Color color,
  ) {
    const n = 10;
    final left = <Offset>[], right = <Offset>[];
    for (var k = 0; k <= n; k++) {
      final f = k / n;
      final cx = x + sway * len * 0.12 * math.sin(f * math.pi * 1.2);
      final cy = y + len * f;
      final half = width * 0.5 * (1 - f * 0.92);
      left.add(Offset(cx - half, cy));
      right.add(Offset(cx + half, cy));
    }
    c.drawPath(
      Path()..addPolygon([...left, ...right.reversed], true),
      Paint()..color = color,
    );
  }

  /// The turf on an isle's back: green from its lit top to its shaded lip,
  /// grass fronds hanging over the lip, and on a far isle the grass itself
  /// as tufts (a near isle's grass is live).
  void _paintTurf(Canvas c, _Isle i) {
    final haze = i.haze;
    final x0 = i.cx - i.hw, x1 = i.cx + i.hw;
    final step = 2 * _u;
    final plate = Path()..moveTo(x0, _back(i, x0));
    for (var x = x0; x <= x1; x += step) {
      plate.lineTo(x, _back(i, x));
    }
    for (var x = x1; x >= x0; x -= step) {
      plate.lineTo(x, _front(i, x) + 0.8 * _u);
    }
    c.drawPath(
      plate..close(),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, _back(i, i.cx)),
          Offset(0, _front(i, i.cx)),
          [fieldMap(haze, 0.14, 0.04), fieldMap(haze, 0, 0.4)],
        ),
    );
    // Fronds over the lip.
    final r = FieldRandom(i.seed * 3 + 5);
    final fronds = Path();
    for (var x = x0 + 2 * _u; x < x1 - 2 * _u; x += 2.4 * _u) {
      if (_pinch(i, x) < 0.2) continue;
      final y = _front(i, x);
      final len = r.range(2, 8) * _u * (haze > 0 ? 0.6 : 1);
      final lean = r.range(-0.6, 0.6) * len * 0.4;
      fronds.addPolygon([
        Offset(x - 1.2 * _u, y - 0.5 * _u),
        Offset(x + 1.2 * _u, y - 0.5 * _u),
        Offset(x + lean, y + len),
      ], true);
    }
    c.drawPath(fronds, Paint()..color = fieldMap(haze, 0, 0.46));
    if (haze > 0) {
      // A far isle's grass: tufts of three grains along its back.
      final tufts = GrainBatch(4);
      for (var k = 0; k < (i.hw * 2 / (0.8 * _u)).round(); k++) {
        final x = i.cx + (r.next() * 2 - 1) * i.hw * 0.97;
        final d = r.next();
        final y = _back(i, x) + d * (_front(i, x) - _back(i, x));
        final near = 1 - d;
        for (var j = 0; j < 3; j++) {
          tufts.add(
            (near * (1.2 + j) + r.next() * 0.6 - 0.3).round().clamp(0, 3),
            x + r.range(-0.3, 0.5) * _u * j,
            y - j * 1.2 * _u,
          );
        }
      }
      for (var t = 0; t < 4; t++) {
        tufts.draw(c, t, 1.25 * _u, fieldMap(haze, 0.1 + t * 0.22, 0.05));
      }
    }
  }

  /// A small tree leaning with the wind, on the isle's back. With
  /// [sparks], only the grains of light on its crown.
  void _paintTree(Canvas c, GrainBatch? sparks, _Isle i) {
    final t = _treeOf(i);
    final base = _back(i, t.x) + 3 * _u;
    final lean = t.h * 0.22;
    final top = Offset(t.x + lean, base - t.h);
    final r = FieldRandom(i.seed * 19 + 7);
    if (sparks == null) {
      final half = t.h * 0.05;
      c.drawPath(
        Path()
          ..moveTo(t.x - half * 1.6, base + 2 * _u)
          ..quadraticBezierTo(
            t.x - half * 0.6,
            base - t.h * 0.5,
            top.dx - half * 0.4,
            top.dy + t.h * 0.12,
          )
          ..lineTo(top.dx + half * 0.4, top.dy + t.h * 0.12)
          ..quadraticBezierTo(
            t.x + half,
            base - t.h * 0.45,
            t.x + half * 1.8,
            base + 2 * _u,
          )
          ..close(),
        Paint()..color = fieldMap(i.haze, 0, 0.55),
      );
    }
    _leafCrown(
      c,
      sparks,
      [
        (top, t.h * 0.42, t.h * 0.26),
        (top + Offset(t.h * 0.3, t.h * 0.1), t.h * 0.3, t.h * 0.2),
        (top + Offset(-t.h * 0.26, t.h * 0.14), t.h * 0.26, t.h * 0.18),
      ],
      leaf: (i.haze > 0 ? 1.8 : 2.6) * r.range(0.9, 1.1),
      seed: i.seed * 23,
      haze: i.haze,
      shade: 0.32,
    );
  }

  /// The light on an isle: along the back of its turf, its lip, the top of
  /// each facet and ledge, its tree, and where water runs off it.
  void _paintIsleLight(Canvas c, _Isle i) {
    final x0 = i.cx - i.hw, x1 = i.cx + i.hw;
    final step = 2.4 * _u;
    for (final (depth, a) in [(1.4, 0.5), (3.6, 0.26), (8.0, 0.1)]) {
      final band = Path()..moveTo(x0, _back(i, x0));
      for (var x = x0; x <= x1; x += step) {
        band.lineTo(x, _back(i, x));
      }
      for (var x = x1; x >= x0; x -= step) {
        band.lineTo(
          x,
          math.min(_front(i, x), _back(i, x) + depth * _u * _pinch(i, x)),
        );
      }
      c.drawPath(
        band..close(),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a),
      );
    }
    final sparks = GrainBatch(_sparkAlpha.length);
    var k = 0;
    // The back of the turf and the lip.
    for (var x = x0; x <= x1; x += step, k++) {
      final roll = fieldHash(k, i.seed * 13);
      if (roll < 0.32) {
        sparks.add((roll * 10).floor().clamp(0, 3), x, _back(i, x) + 0.6 * _u);
        if (roll < 0.02) _glint(_wrapX(x), _back(i, x));
      } else if (roll > 0.9) {
        sparks.add(0, x, _front(i, x) + 0.8 * _u);
      }
    }
    // Down the top of each facet edge, and along the ledges.
    for (final (pts, _, _) in _facets(i)) {
      final a = pts[0], b = pts[3];
      for (var s = 0; s < 8; s++) {
        final f = s / 8 * 0.4;
        if (fieldHash(s, a.dx.round()) > 0.45) continue;
        final p = Offset.lerp(a, b, f)!;
        sparks.add(f < 0.15 ? 2 : 1, p.dx, p.dy);
        if (s == 0 && fieldHash(9, a.dx.round()) < 0.3) {
          _glint(_wrapX(p.dx), p.dy);
        }
      }
    }
    for (final f in [0.3, 0.58]) {
      var j = 0;
      for (var x = x0; x <= x1; x += step * 1.4, j++) {
        if (fieldHash(j, i.seed + (f * 100).round()) > 0.3) continue;
        final y =
            _front(i, x) +
            (_bottom(i, x) - _front(i, x)) *
                (f + 0.05 * fieldNoise(x / (20 * _u), i.seed + 21));
        sparks.add(0, x, y + 0.6 * _u);
      }
    }
    if (i.tree) {
      _paintTree(_NullCanvas(), sparks, i);
    }
    _drawSparks(c, sparks, 1.35);
  }

  /// Near isles' grass: a fringe along each back against the sky, blades
  /// all the way down the turf, and those rooted below a standing
  /// creature's feet kept short and drawn over it (row 4).
  _Blades _isleGrass(List<_Isle> isles) {
    final b = _BladeBuilder();
    final r = FieldRandom(616);
    for (final i in isles) {
      final x0 = i.cx - i.hw * 0.97, x1 = i.cx + i.hw * 0.97;
      for (var x = x0; x < x1; x += 2 * _u) {
        final tall =
            0.7 + 0.6 * (fieldNoise(x / (40 * _u), i.seed + 1) * 0.5 + 0.5);
        b.add(
          x: x + r.range(-0.6, 0.6) * _u,
          base: _back(i, x) + 1.2 * _u,
          height: r.range(6, 13) * tall * _u * (0.5 + 0.5 * _pinch(i, x)),
          lean: r.range(-0.1, 0.3),
          phase: r.range(0, math.pi * 2),
          depth: 0,
          row: 0,
        );
      }
      final n = (i.hw * 2 * i.plate / (7 * _u * _u)).round();
      for (var k = 0; k < n; k++) {
        final x = i.cx + (r.next() * 2 - 1) * i.hw * 0.95;
        final back = _back(i, x), front = _front(i, x);
        final d = r.next();
        final y = back + 1.5 * _u + d * (front - back - 1.5 * _u);
        final feet = y > _stand(i, x) + 0.5 * _u;
        b.add(
          x: x,
          base: y,
          height: (feet ? r.range(3.5, 7) : r.range(6, 12)) * _u,
          lean: r.range(-0.1, 0.3),
          phase: r.range(0, math.pi * 2),
          depth: d,
          row: feet ? 4 : (d < 0.3 ? 1 : (d < 0.6 ? 2 : 3)),
        );
      }
    }
    return b.done();
  }

  // ── Water off the isles ──────────────────────────────────────────────────

  _Fall _fallOf(_Isle i) {
    final x = i.cx + i.fall * i.hw * 0.66;
    return _Fall(
      x: x,
      y0: _front(i, x) - 1 * _u,
      length: i.depth * 1.5 + 140 * _u,
      width: 4 * _u,
      seed: i.seed,
    );
  }

  /// Water pouring off an isle's lip: a stream that thins as it speeds up
  /// and frays, then breaks into a cloud of spray before it reaches the sea.
  void _paintFalls(Canvas canvas, FieldView view) {
    if (_falls.isEmpty) return;
    _fallBatch.clear();
    final t = view.time;
    var any = false;
    for (final shift in _shiftsFor(near, view, 90 * _u)) {
      for (final f in _falls) {
        final fx = f.x + shift;
        if (fx < view.left - 90 * _u || fx > view.right + 90 * _u) continue;
        final (_, gust) = _wind(fx, t, _nearWidth);
        final push = (gust * 10 + 4) * _u;
        // A finger in it: the water parts round it and is gone for a
        // moment below it.
        final touch = _inFall;
        final held = touch != null && touch.fall == f
            ? (1 - (t - touch.time) / 0.3).clamp(0.0, 1.0)
            : 0.0;
        final tx = held > 0 ? touch!.x - f.x + fx : 0.0;
        final ty = held > 0 ? touch!.y : 0.0;
        _paintStream(canvas, f, fx, push, cut: held > 0.5 ? ty : null);
        // The stream.
        for (var k = 0; k < 240; k++) {
          final a = (t * 0.5 + fieldHash(k, f.seed)) % 1.0;
          final fall = math.pow(a, 1.7).toDouble();
          final across = fieldHash(k, f.seed + 1) - 0.5;
          var x = fx + across * f.width * (1 + 2.6 * fall) + push * fall;
          final y = f.y0 + fall * f.length;
          if (held > 0) {
            final below = (y - ty) / (12 * _u);
            if (below > -0.5 && below < 5 && fieldHash(k, 9) < held * 0.8) {
              continue;
            }
            x += (x - tx).sign * 9 * _u * held * math.exp(-below * below / 4);
          }
          final fade = math.min(1.0, a * 20) * (1 - math.pow(a, 3));
          final level = (fade * (1.4 - across.abs()) * 2.99).floor();
          if (level <= 0) continue;
          _fallBatch.add(math.min(level, 3) - 1, x, y);
          any = true;
        }
        // The spray it breaks into, thickest toward the end.
        for (var k = 0; k < 110; k++) {
          final a =
              0.35 +
              0.65 * math.sqrt((t * 0.22 + fieldHash(k, f.seed + 2)) % 1);
          final fall = math.pow(a, 1.7).toDouble();
          final drift = (fieldHash(k, f.seed + 3) - 0.5) * 2;
          final x =
              fx +
              drift * f.width * (1 + 9 * (a - 0.35)) +
              push * fall * 1.4 +
              math.sin(t * 1.3 + k) * 2 * _u;
          final fade = math.min(1.0, (a - 0.35) * 6) * (1 - a) * 2.2;
          final level = (fade * 2.99).floor();
          if (level <= 0) continue;
          _fallBatch.add(
            2 + math.min(level, 3).toInt(),
            x,
            f.y0 + fall * f.length,
          );
          any = true;
        }
      }
    }
    if (!any) return;
    final water = _water;
    final top = _light.seaTop ?? _light.cloudTop;
    for (var lv = 0; lv < 3; lv++) {
      _fallBatch.draw(
        canvas,
        lv,
        2.2 * _u,
        water.withValues(alpha: 0.38 + 0.26 * lv),
      );
      _fallBatch.draw(
        canvas,
        3 + lv,
        3.6 * _u,
        top.withValues(alpha: 0.12 + 0.1 * lv),
      );
    }
  }

  /// The colour of falling water this hour: the cloud's light, a little
  /// clearer.
  Color get _water {
    final l = _light;
    final top = l.seaTop ?? l.cloudTop, deep = l.seaDeep ?? l.cloudBottom;
    return Color.lerp(
      Color.lerp(top, deep, 0.22)!,
      const Color(0xFFFFFFFF),
      0.25 * l.ambient.computeLuminance(),
    )!;
  }

  /// A fall's body: a ribbon tapering out of the lip and widening as it
  /// drops, bright at its edge of light and fading as it frays.
  void _paintStream(
    Canvas canvas,
    _Fall f,
    double fx,
    double push, {
    double? cut,
  }) {
    final len = cut == null
        ? f.length * 0.62
        : math.min(f.length * 0.62, math.max(0.0, cut - f.y0));
    if (len < 2 * _u) return;
    const n = 12;
    final left = <Offset>[], right = <Offset>[];
    for (var k = 0; k <= n; k++) {
      final a = k / n;
      final fall = math.pow(a, 1.7).toDouble();
      final y = f.y0 + fall * len;
      final x = fx + push * fall * 0.62;
      final half = f.width * (0.55 + 1.5 * a);
      left.add(Offset(x - half, y));
      right.add(Offset(x + half * 0.8, y));
    }
    final water = _water;
    canvas.drawPath(
      Path()..addPolygon([...left, ...right.reversed], true),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, f.y0),
          Offset(0, f.y0 + len),
          [
            water.withValues(alpha: 0.85),
            water.withValues(alpha: 0.5),
            water.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
  }

  // ── Touching the sky ─────────────────────────────────────────────────────

  /// Each layer's view as of its pass this frame, so a finger can be found
  /// on whatever is frontmost under it.
  final Map<SceneLayer, FieldView> _views = {};
  double _routed = -1;

  /// What fingers can find: the high clouds (in their drifting sheet's
  /// units) and the heads of the towers.
  final List<Rect> _highClouds = [];
  List<_Puff> _towerHeads = const [];

  /// Vapour stirred out of the clouds, kept in the layer of the cloud it
  /// came from; soft pools of light where a cloud was tapped; water
  /// splashed off the falls; and the last finger in a fall.
  final Map<SceneLayer, _Drift> _vapour = {
    SkyField.far: _Drift(220),
    SkyField.mid: _Drift(260),
  };
  final Map<SceneLayer, List<(double, double, double)>> _pools = {
    SkyField.far: [],
    SkyField.mid: [],
  };
  final _Drift _drops = _Drift(200);
  ({_Fall fall, double x, double y, double time})? _inFall;
  final GrainBatch _vapourBatch = GrainBatch(6);

  /// Sends this frame's new fingers to whatever is frontmost under each:
  /// an isle (its grass stirs itself), a fall, a far isle, the cloud sea,
  /// a high cloud or a tower — or nothing, in the open sky.
  void _route(FieldView view) {
    final farView = _views[far], midView = _views[mid];
    var newest = _routed;
    for (final t in view.touches) {
      if (t.time <= _routed) continue;
      if (t.time > newest) newest = t.time;
      final moved = math.sqrt(t.dx * t.dx + t.dy * t.dy);
      final dir = moved > 0.01 ? t.dx.sign : 0.0;
      final tap = moved < 0.5;
      final n = view.local(t.x, t.y);
      if (_onIsle(near, n.dx, n.dy, 30 * _u)) continue;
      final fall = _fallAt(n.dx, n.dy);
      if (fall != null) {
        _inFall = (fall: fall, x: n.dx, y: n.dy, time: view.time);
        _splash(n.dx, n.dy, dir, moved / view.zoom, tap: tap);
        continue;
      }
      if (midView != null) {
        final m = midView.local(t.x, t.y);
        if (_onIsle(mid, m.dx, m.dy, 10 * _u)) continue;
        if (m.dy > _h * 0.665) {
          _stirCloud(mid, m.dx, m.dy, dir, moved / midView.zoom, tap: tap);
          continue;
        }
      }
      if (farView != null) {
        final f = farView.local(t.x, t.y);
        if (_onHighCloud(f, farView.time) || _onTower(f) || f.dy > _h * 0.605) {
          _stirCloud(far, f.dx, f.dy, dir, moved / farView.zoom, tap: tap);
        }
      }
    }
    _routed = newest;
  }

  bool _onIsle(SceneLayer layer, double x, double y, double grass) {
    final at = _isleAt(layer, x);
    if (at == null) return false;
    final (i, lx) = at;
    return y > _back(i, lx) - grass && y < _bottom(i, lx) + 4 * _u;
  }

  _Fall? _fallAt(double x, double y) {
    for (final f in _falls) {
      final fall = (y - f.y0) / f.length;
      if (fall < -0.02 || fall > 0.8) continue;
      final dx = _loopDelta(x, f.x + 6 * _u * fall, near);
      if (dx.abs() < f.width * (1 + 2.6 * fall) + 12 * _u) return f;
    }
    return null;
  }

  bool _onHighCloud(Offset p, double time) {
    final w = _cloudWidth;
    final off = (time * _drift * _u) % w;
    var x = (p.dx - off) % w;
    if (x < 0) x += w;
    for (final c in _highClouds) {
      for (final cx in [x, x - w, x + w]) {
        final dx = (cx - c.center.dx) / (c.width / 2);
        final dy = (p.dy - c.center.dy) / (c.height / 2);
        if (dx * dx + dy * dy < 1) return true;
      }
    }
    return false;
  }

  bool _onTower(Offset p) {
    for (final h in _towerHeads) {
      final dx = _loopDelta(p.dx, h.x, far) / h.rx;
      final dy = (p.dy - h.y) / h.ry;
      if (dx * dx + dy * dy < 1) return true;
    }
    return false;
  }

  /// A finger through a cloud: vapour peels off and streams after it,
  /// curling as it slows; a tap puffs a lopsided cloud of it out, with a
  /// soft glow where the finger went in.
  void _stirCloud(
    SceneLayer layer,
    double x,
    double y,
    double dir,
    double speed, {
    required bool tap,
  }) {
    final v = _vapour[layer]!;
    if (tap) {
      // Lopsided and uneven, never a ring: most of it slow and close, a
      // few wisps thrown further, more of it to one side.
      final lean = v.rand() * math.pi * 2;
      for (var k = 0; k < 30; k++) {
        final a = v.rand() * math.pi * 2;
        final from = v.rand() * 9 * _u;
        final out = (6 + 72 * math.pow(v.rand(), 1.8)) * _u;
        final bias = 0.3 + 0.7 * (math.cos(a - lean) * 0.5 + 0.5);
        v.spawn(
          x: x + math.cos(a) * from,
          y: y + math.sin(a) * from * 0.7,
          vx: math.cos(a) * out * bias,
          vy: math.sin(a) * out * bias * 0.6 - 6 * _u,
          life: 0.9 + v.rand() * 1.5,
          spin: (v.rand() - 0.5) * 3,
        );
      }
      final pools = _pools[layer]!;
      pools.add((x, y, _views[layer]?.time ?? 0));
      if (pools.length > 6) pools.removeAt(0);
      return;
    }
    final pace = math.min(1.0, speed / (5 * _u));
    final n = 1 + (pace * 3).round();
    for (var k = 0; k < n; k++) {
      v.spawn(
        x: x + (v.rand() - 0.5) * 10 * _u,
        y: y + (v.rand() - 0.5) * 8 * _u,
        vx: dir * (24 + v.rand() * 60) * _u * pace + (v.rand() - 0.5) * 18 * _u,
        vy: (v.rand() - 0.6) * 22 * _u,
        life: 1.4 + v.rand() * 1.3,
        spin: (v.rand() < 0.5 ? -1 : 1) * (0.5 + v.rand()),
      );
    }
  }

  /// A finger in a fall: water splashes off it to both sides and drops
  /// away; a tap throws more.
  void _splash(
    double x,
    double y,
    double dir,
    double speed, {
    required bool tap,
  }) {
    final d = _drops;
    final n = tap ? 20 : 3;
    for (var k = 0; k < n; k++) {
      final side = d.rand() < 0.5 ? -1.0 : 1.0;
      d.spawn(
        x: x + (d.rand() - 0.5) * 6 * _u,
        y: y + d.rand() * 4 * _u,
        vx: side * (30 + d.rand() * 90) * _u + dir * speed * 4,
        vy: -(15 + d.rand() * (tap ? 95 : 55)) * _u,
        life: 0.7 + d.rand() * 0.6,
      );
    }
  }

  void _paintVapour(Canvas canvas, FieldView view, SceneLayer layer) {
    final v = _vapour[layer]!;
    final pools = _pools[layer]!;
    final dt = v.clock < 0 ? 0.0 : (view.time - v.clock).clamp(0.0, 0.1);
    v.clock = view.time;
    final l = _light;
    final lit = Color.lerp(
      l.seaTop ?? l.cloudTop,
      const Color(0xFFFFFFFF),
      0.5,
    )!;
    final shade = l.seaDeep ?? l.cloudBottom;
    // Where a cloud was tapped: it gives under the finger — a soft shaded
    // dimple that opens and fills back in — and breathes light out of it.
    pools.removeWhere((p) => view.time - p.$3 > 1.1);
    for (final (x, y, t0) in pools) {
      final f = ((view.time - t0) / 1.1).clamp(0.0, 1.0);
      final gone = math.pow(1 - f, 1.6).toDouble();
      final r = (9 + 26 * math.sqrt(f)) * _u;
      final at = Offset(x, y);
      canvas
        ..drawCircle(
          at,
          r,
          Paint()
            ..shader = Gradient.radial(
              at,
              r,
              [
                shade.withValues(alpha: 0.34 * gone),
                shade.withValues(alpha: 0.12 * gone),
                shade.withValues(alpha: 0),
              ],
              const [0.0, 0.55, 1.0],
            ),
        )
        ..drawCircle(
          at,
          r * 0.55,
          Paint()
            ..shader = Gradient.radial(at, r * 0.55, [
              lit.withValues(alpha: 0.5 * gone),
              lit.withValues(alpha: 0),
            ]),
        );
    }
    if (!v.any) return;
    v.step(dt, drag: 1.5, lift: 5 * _u, windX: layer == far ? _drift * _u : 0);
    _vapourBatch.clear();
    var any = false;
    for (var i = 0; i < v.cap; i++) {
      if (v.life[i] <= 0) continue;
      final f = v.age[i] / v.life[i];
      final fade = math.min(1.0, f * 10) * (1 - f);
      final level = (fade * 2.99).floor();
      if (level <= 0) continue;
      _vapourBatch.add((i % 3 == 0 ? 3 : 0) + level - 1, v.x[i], v.y[i]);
      any = true;
    }
    if (!any) return;
    final glint = Color.lerp(l.cloudGlint, const Color(0xFFFFFFFF), 0.2)!;
    for (var lv = 0; lv < 3; lv++) {
      for (final (b, col) in [(lv, lit), (3 + lv, glint)]) {
        _vapourBatch.draw(
          canvas,
          b,
          7.5 * _u,
          col.withValues(alpha: 0.09 * (lv + 1)),
        );
        _vapourBatch.draw(
          canvas,
          b,
          2.5 * _u,
          col.withValues(alpha: 0.3 * (lv + 1)),
        );
      }
    }
  }

  void _paintDrops(Canvas canvas, FieldView view) {
    final d = _drops;
    final dt = d.clock < 0 ? 0.0 : (view.time - d.clock).clamp(0.0, 0.1);
    d.clock = view.time;
    if (!d.any) return;
    d.step(dt, gravity: 320 * _u, drag: 0.6);
    _fallBatch.clear();
    var any = false;
    for (var i = 0; i < d.cap; i++) {
      if (d.life[i] <= 0) continue;
      final f = d.age[i] / d.life[i];
      final level = ((1 - f) * 2.99).floor();
      if (level <= 0) continue;
      _fallBatch.add(level - 1, d.x[i], d.y[i]);
      any = true;
    }
    if (!any) return;
    final water = Color.lerp(_water, const Color(0xFFFFFFFF), 0.6)!;
    for (var lv = 0; lv < 2; lv++) {
      _fallBatch.draw(
        canvas,
        lv,
        4.2 * _u,
        water.withValues(alpha: 0.1 * (lv + 1)),
      );
      _fallBatch.draw(
        canvas,
        lv,
        2.3 * _u,
        water.withValues(alpha: 0.55 + 0.35 * lv),
      );
    }
  }

  // ── The storm ────────────────────────────────────────────────────────────

  /// The stroke of lightning playing now, if any, and when the next comes.
  _Strike? _strike;
  double _nextStrike = -1;
  int _strikes = 0;

  /// How bright the lightning is lighting everything this frame (0–1).
  double _flash = 0;

  bool? _forceBolt;

  /// Sets lightning off on the next frame — a bolt, or a flicker in a cloud.
  @visibleForTesting
  void debugStrike({required bool bolt}) {
    _forceBolt = bolt;
    _nextStrike = 0;
  }

  /// The Sky's weather is a lightning storm.
  double get storm => weatherKind == WeatherKind.storm ? weather : 0;

  @override
  double get _windScale => 1 + 0.9 * storm;

  @override
  double get _veil => 0.82 * storm;

  /// How bright the lightning playing now is, before the storm dims it, and
  /// how long it has been playing.
  double _strikeLevel = 0;
  double _strikeAge = 0;

  /// How long a bolt takes to strike down from the sky to the sea.
  static const _leadTime = 0.08;

  @override
  double get _weatherKey =>
      (storm * 1000).roundToDouble() + (_flash * 100).roundToDouble() / 1000;

  @override
  void prepare(double hour, {double time = 0}) {
    _strikeTick(time);
    super.prepare(hour, time: time);
  }

  /// Lightning comes every few seconds while the storm is up: most often a
  /// flicker inside one of the towers, sometimes a bolt from high in the
  /// dark down to the horizon.
  void _strikeTick(double time) {
    if (storm < 0.35) {
      _strike = null;
      _flash = 0;
      _nextStrike = -1;
      return;
    }
    if (_nextStrike < 0) _nextStrike = time + 1.2;
    if (_forceBolt != null) _nextStrike = math.min(_nextStrike, time);
    if (time >= _nextStrike) {
      final r = FieldRandom(9000 + _strikes++);
      final view = _views[far];
      final left = view?.left ?? 0, right = view?.right ?? _cloudWidth;
      final x = left + (0.12 + 0.76 * r.next()) * (right - left);
      // A flicker lights one of the upper heads of a tower in view; a bolt
      // falls from the dark (and comes instead when no tower is in view).
      final mid = (left + right) / 2, half = (right - left) / 2 - 30 * _u;
      final heads = [
        for (final h in _towerHeads)
          if (h.y < _h * 0.5 && _loopDelta(h.x, mid, far).abs() < half) h,
      ];
      final bolt =
          heads.isEmpty ||
          ((r.next() < 0.4 || _forceBolt == true) && _forceBolt != false);
      _forceBolt = null;
      var glow = Offset(x, _h * 0.3);
      if (heads.isNotEmpty) {
        final h = heads[(r.next() * heads.length).floor()];
        glow = Offset(mid + _loopDelta(h.x, mid, far), h.y);
      }
      final lead = bolt ? _leadTime : 0.0;
      final (path, from) = bolt
          ? _boltPath(x, r)
          : (const <List<Offset>>[], const <int>[]);
      _strike = _Strike(
        start: time,
        bolt: bolt,
        glow: bolt ? Offset(x, _h * r.range(0.1, 0.2)) : glow,
        path: path,
        branchFrom: from,
        seed: _strikes,
        lead: lead,
        flickers: [
          (lead, 1.0),
          (lead + r.range(0.06, 0.12), r.range(0.4, 0.7)),
          (lead + r.range(0.18, 0.3), r.range(0.6, 0.95)),
        ],
      );
      _nextStrike = time + r.range(1.8, 5.5) / storm;
    }
    final st = _strike;
    if (st == null) {
      _flash = 0;
      return;
    }
    final age = time - st.start;
    _strikeAge = age;
    if (age > 0.7 + st.lead) {
      _strike = null;
      _flash = 0;
      return;
    }
    // While the leader feels its way down, only a faint glow.
    var f = st.lead > 0 && age < st.lead ? 0.16 * age / st.lead : 0.0;
    // Each flicker comes all at once and dies away over a few frames, with
    // a glow lingering after it.
    for (final (at, a) in st.flickers) {
      final d = age < at ? (at - age) / 0.01 : (age - at) / 0.04;
      f = math.max(
        f,
        a * math.exp(-d * d) +
            (age > at ? a * 0.25 * math.exp(-(age - at) * 6) : 0),
      );
    }
    _strikeLevel = f.clamp(0.0, 1.0);
    _flash = (f * storm * (st.bolt ? 1 : 0.45)).clamp(0.0, 1.0);
  }

  /// A bolt's channel from high in the sky down to the horizon, jagged by
  /// halving, with a branch or two off it — far-layer units.
  (List<List<Offset>>, List<int>) _boltPath(double x, FieldRandom r) {
    List<Offset> channel(Offset a, Offset b, int depth, double rough) {
      var pts = [a, b];
      for (var d = 0; d < depth; d++) {
        final next = <Offset>[pts.first];
        for (var i = 0; i + 1 < pts.length; i++) {
          final p = pts[i], q = pts[i + 1];
          final m = (p + q) / 2;
          final len = (q - p).distance;
          final n = Offset(-(q.dy - p.dy), q.dx - p.dx) / math.max(len, 1e-6);
          next
            ..add(m + n * (r.next() - 0.5) * len * rough)
            ..add(q);
        }
        pts = next;
      }
      return pts;
    }

    final top = Offset(x, _h * r.range(0.08, 0.18));
    final foot = Offset(x + r.range(-0.12, 0.12) * _h, _h * 0.605);
    final main = channel(top, foot, 6, 0.42);
    final out = [main];
    final froms = <int>[-1];
    for (var b = 0; b < 1 + (r.next() * 2).floor(); b++) {
      final at = (main.length * r.range(0.2, 0.6)).floor();
      final from = main[at];
      final reach = _h * r.range(0.08, 0.18);
      final to = from + Offset((r.next() < 0.5 ? -1 : 1) * reach * 0.8, reach);
      out.add(channel(from, to, 4, 0.5));
      froms.add(at);
    }
    return (out, froms);
  }

  /// The storm's light: the hour's light drawn down to slate and violet as
  /// the storm comes in, and thrown up toward white for a moment whenever
  /// the lightning goes.
  @override
  _Light _weathered(_Light l) {
    final s = storm, f = _flash;
    if (s <= 0.001 && f <= 0.001) return l;
    Color slate(Color c, double dark) {
      final g = math.sqrt(c.computeLuminance());
      final to = Color.lerp(
        const Color(0xFF12151F),
        const Color(0xFF6E7494),
        g,
      )!;
      return Color.from(
        alpha: 1,
        red: to.r * dark,
        green: to.g * dark,
        blue: to.b * dark,
      );
    }

    final k = 0.82 * s;
    Color st(Color c, double dark, Color flashTo, double fk) =>
        Color.lerp(Color.lerp(c, slate(c, dark), k)!, flashTo, fk * f)!;
    const pale = Color(0xFFDCE4FF);
    final seaTop = l.seaTop ?? l.cloudTop, seaDeep = l.seaDeep ?? l.cloudBottom;
    return _Light(
      stops: l.stops,
      sky: [for (final c in l.sky) st(c, 0.9, const Color(0xFFB8C2E6), 0.35)],
      ambient: st(l.ambient, 0.62, const Color(0xFFE8ECFF), 0.55),
      rim: Color.lerp(
        Color.lerp(l.rim, const Color(0xFFB8C6EE), s)!,
        const Color(0xFFFFFFFF),
        f,
      )!,
      rimStrength: l.rimStrength * (1 - 0.55 * s) + 0.7 * f,
      floor:
          l.floor + (math.max(0.5, l.floor) - l.floor) * s + (1 - l.floor) * f,
      glow: l.glow * (1 - 0.9 * s),
      stars: l.stars * (1 - 0.8 * s),
      cloudTop: st(l.cloudTop, 0.55, pale, 0.5),
      cloudBottom: st(l.cloudBottom, 0.7, pale, 0.5),
      cloudGlint: Color.lerp(l.cloudGlint, const Color(0xFFC8D4FF), s)!,
      seaTop: st(seaTop, 0.78, const Color(0xFFF2F5FF), 0.6),
      seaDeep: st(seaDeep, 0.5, const Color(0xFF8A94BE), 0.45),
      grass: [for (final c in l.grass) st(c, 0.85, pale, 0.25)],
      mote: Color.lerp(l.mote, const Color(0xFFD6E2FF), s)!,
      firefly: l.firefly,
    );
  }

  /// The lightning playing now: the light inside the cloud it lit, and the
  /// bolt if it is one — a bright core over a faint wide glow, the one place
  /// lines belong.
  void _paintStrike(Canvas canvas) {
    final st = _strike;
    if (st == null) return;
    final age = _strikeAge;
    final leading = st.bolt && age < st.lead;
    if (!leading && _flash < 0.02) return;
    final i = leading ? 0.55 : _strikeLevel;
    final r = (st.bolt ? 60 : 95) * _u;
    canvas.drawCircle(
      st.glow,
      r,
      Paint()
        ..shader = Gradient.radial(
          st.glow,
          r,
          [
            const Color(0xFFEFF2FF).withValues(alpha: 0.6 * i),
            const Color(0xFFB8C4F0).withValues(alpha: 0.22 * i),
            const Color(0x00B8C4F0),
          ],
          const [0.0, 0.4, 1.0],
        ),
    );
    if (!st.bolt) return;
    // Which flicker is playing: each one re-forks the channel a little, so
    // the bolt crackles rather than hanging there.
    var flicker = -1;
    for (var j = 0; j < st.flickers.length; j++) {
      if (age >= st.flickers[j].$1) flicker = j;
    }
    final main = st.path.first;
    final reveal = leading ? (age / st.lead).clamp(0.0, 1.0) : 1.0;
    final reached = reveal * (main.length - 1);
    Offset jitter(int b, int k, int n) {
      if (flicker < 0 || k == 0 || (b == 0 && k == n - 1)) return Offset.zero;
      final seed = st.seed * 131 + flicker * 17 + b * 5;
      return Offset(
            fieldHash(k, seed) - 0.5,
            (fieldHash(k, seed + 3) - 0.5) * 0.6,
          ) *
          (4.4 * _u);
    }

    for (var b = 0; b < st.path.length; b++) {
      final src = st.path[b];
      // How much of this channel the leader has drawn out so far.
      final from = st.branchFrom[b];
      final shown = b == 0
          ? reached
          : (reached - from) / (main.length * 0.35) * (src.length - 1);
      if (shown <= 0) continue;
      final last = math.min(src.length - 1, shown.floor());
      final pts = <Offset>[
        for (var k = 0; k <= last; k++)
          src[k] +
              (b > 0 && k == 0
                  ? jitter(0, from, main.length)
                  : jitter(b, k, src.length)),
      ];
      if (last < src.length - 1) {
        final t = shown - last;
        pts.add(Offset.lerp(src[last], src[last + 1], t)!);
      }
      if (pts.length < 2) continue;
      final path = Path()..addPolygon(pts, false);
      final k = (b == 0 ? 1.0 : 0.55) * (leading ? 0.6 : 1.0);
      for (final (wide, a, col) in [
        (9.0, 0.2, const Color(0xFFAFC0FF)),
        (3.4, 0.5, const Color(0xFFDDE6FF)),
        (1.4, 0.95, const Color(0xFFFFFFFF)),
      ]) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..strokeWidth = wide * _u * k
            ..color = col.withValues(alpha: a * i * k),
        );
      }
      // The leader's bright tip, feeling its way down.
      if (leading && b == 0) {
        final tip = pts.last;
        canvas.drawCircle(
          tip,
          7 * _u,
          Paint()
            ..shader = Gradient.radial(tip, 7 * _u, [
              const Color(0xFFFFFFFF).withValues(alpha: 0.9),
              const Color(0x00C8D4FF),
            ]),
        );
      }
    }
  }

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
        _views[far] = view;
        final off = (view.time * _drift * _u) % _cloudWidth;
        _paintGlints(
          canvas,
          view,
          far,
          _cloudGlints,
          shift: off,
          wrap: _cloudWidth,
        );
        _paintGlints(canvas, view, far, _glints[far]);
        _paintStrike(canvas);
        _paintVapour(canvas, view, far);
      case mid:
        _views[mid] = view;
        _paintGlints(canvas, view, mid, _glints[mid]);
        _paintVapour(canvas, view, mid);
      case near:
        final pushes = _pushes(view);
        if (!front) {
          _route(view);
          _paintGlints(canvas, view, near, _glints[near], size: 1.2);
          _paintFalls(canvas, view);
          _paintDrops(canvas, view);
          _paintMotes(canvas, view, _motes, near);
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
              reach: 34 * _u,
              maxBend: 1.1,
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
        if (front) _paintKicked(canvas, view);
      default:
        break;
    }
  }
}

/// A floating isle of the Sky: a turfed back on a hanging point of rock.
class _Isle {
  _Isle({
    required this.cx,
    required this.hw,
    required this.depth,
    required this.plate,
    required this.seed,
    required this.haze,
    this.tree = false,
    this.fall = 0,
  });

  /// Its middle and half its width, in layer units.
  final double cx, hw;

  /// How far its rock hangs below its top, and how deep its turf is.
  final double depth, plate;

  /// How far off it is (0 near; a far isle is hazed).
  final double haze;
  final int seed;
  final bool tree;

  /// Which end water runs off: -1 left, 1 right, 0 none.
  final int fall;

  /// Where feet stand at its middle, less its unevenness there; set once
  /// it is seated.
  double level = 0;
}

/// A rounded head of cloud, or (with an [edge]) the solid sea behind a row
/// of them: r maps from [r0] on top to [r1] beneath, b is its haze.
class _Puff {
  _Puff(
    this.x,
    this.y,
    this.rx,
    this.ry, {
    required this.r0,
    required this.r1,
    required this.haze,
    required this.grains,
    required this.seed,
  }) : edge = null,
       y2 = 0;

  _Puff.fill(
    List<Offset> this.edge,
    this.y2, {
    required double r,
    required this.haze,
  }) : x = 0,
       y = edge.fold(double.infinity, (m, p) => math.min(m, p.dy)),
       rx = 0,
       ry = 0,
       r0 = r,
       r1 = r,
       grains = 0,
       seed = 0;

  final double x, y, rx, ry, r0, r1, haze, grains;

  /// A fill's top edge, and how far down it reaches.
  final List<Offset>? edge;
  final double y2;
  final int seed;

  _Puff shifted(double dx) => _Puff(
    x + dx,
    y,
    rx,
    ry,
    r0: r0,
    r1: r1,
    haze: haze,
    grains: grains,
    seed: seed,
  );
}

/// A stroke of lightning: when it went, the cloud it lit, the bolt's
/// channels (none for a flicker inside a cloud), and its flickers (when,
/// how bright). A bolt's leader strikes down first; its flickers come once
/// it has reached the sea.
class _Strike {
  const _Strike({
    required this.start,
    required this.bolt,
    required this.glow,
    required this.path,
    required this.branchFrom,
    required this.seed,
    required this.lead,
    required this.flickers,
  });
  final double start;
  final bool bolt;
  final Offset glow;

  /// The main channel first, then its branches, and for each branch the
  /// point on the main channel it leaves from (-1 for the main channel).
  final List<List<Offset>> path;
  final List<int> branchFrom;
  final int seed;

  /// How long its leader takes to reach the sea (0 for a flicker).
  final double lead;
  final List<(double, double)> flickers;
}

/// Light things set moving by a finger — vapour, spray — as a fixed pool.
class _Drift {
  _Drift(this.cap)
    : x = Float32List(cap),
      y = Float32List(cap),
      vx = Float32List(cap),
      vy = Float32List(cap),
      age = Float32List(cap),
      life = Float32List(cap),
      spin = Float32List(cap);

  final int cap;
  final Float32List x, y, vx, vy, age, life, spin;
  int _next = 0;
  double clock = -1;
  final math.Random _r = math.Random(11);

  /// Whether anything in it may still be alive.
  bool any = false;

  double rand() => _r.nextDouble();

  void spawn({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required double life,
    double spin = 0,
  }) {
    final i = _next;
    _next = (_next + 1) % cap;
    this.x[i] = x;
    this.y[i] = y;
    this.vx[i] = vx;
    this.vy[i] = vy;
    age[i] = 0;
    this.life[i] = life;
    this.spin[i] = spin;
    any = true;
  }

  /// Moves everything on by [dt]: [gravity] pulls down, [lift] up, [drag]
  /// slows, [windX] carries, and each turns its heading by its own spin.
  void step(
    double dt, {
    double gravity = 0,
    double lift = 0,
    double drag = 1,
    double windX = 0,
  }) {
    if (dt <= 0) return;
    final slow = math.exp(-drag * dt);
    var alive = false;
    for (var i = 0; i < cap; i++) {
      if (life[i] <= 0) continue;
      age[i] += dt;
      if (age[i] >= life[i]) {
        life[i] = 0;
        continue;
      }
      alive = true;
      var ux = vx[i] * slow, uy = vy[i] * slow + (gravity - lift) * dt;
      final turn = spin[i] * dt;
      if (turn != 0) {
        final c = math.cos(turn), s = math.sin(turn);
        (ux, uy) = (ux * c - uy * s, ux * s + uy * c);
      }
      vx[i] = ux;
      vy[i] = uy;
      x[i] += (ux + windX) * dt;
      y[i] += uy * dt;
    }
    any = alive;
  }
}

/// Water running off an isle: where it leaves the lip, how far it falls
/// before it is all spray, and how wide it starts.
class _Fall {
  const _Fall({
    required this.x,
    required this.y0,
    required this.length,
    required this.width,
    required this.seed,
  });
  final double x, y0, length, width;
  final int seed;
}

// ── The Sky's day ──────────────────────────────────────────────────────────

/// Above the weather the sky runs deeper blue overhead and down to a pale
/// band where it meets the cloud sea.
const _skyStops = [0.0, 0.14, 0.28, 0.40, 0.50, 0.56, 0.60, 0.64, 1.0];

const _skyNight = _Light(
  stops: _skyStops,
  sky: [
    Color(0xFF02040C),
    Color(0xFF040919),
    Color(0xFF08112A),
    Color(0xFF0C1936),
    Color(0xFF132242),
    Color(0xFF182A4A),
    Color(0xFF1D3050),
    Color(0xFF22365A),
    Color(0xFF22365A),
  ],
  ambient: Color(0xFF20263C),
  rim: Color(0xFFA2B8E8),
  rimStrength: 0.24,
  floor: 0.35,
  glow: 0,
  stars: 1,
  cloudTop: Color(0xFF0C1222),
  cloudBottom: Color(0xFF1A2440),
  cloudGlint: Color(0xFF8CA4D8),
  seaTop: Color(0xFF34446C),
  seaDeep: Color(0xFF080E20),
  grass: [
    Color(0xFF05080A),
    Color(0xFF080D11),
    Color(0xFF0C1318),
    Color(0xFF111A21),
    Color(0xFF18242E),
    Color(0xFF22334A),
    Color(0xFF34496A),
    Color(0xFF5E7AA4),
  ],
  mote: Color(0xFFD0E0FF),
  firefly: 0.45,
);

const _skyPreDawn = _Light(
  stops: _skyStops,
  sky: [
    Color(0xFF03071A),
    Color(0xFF07102C),
    Color(0xFF0E1A3C),
    Color(0xFF17264C),
    Color(0xFF222E58),
    Color(0xFF2C3860),
    Color(0xFF384266),
    Color(0xFF42486C),
    Color(0xFF42486C),
  ],
  ambient: Color(0xFF282C46),
  rim: Color(0xFFA8B8E4),
  rimStrength: 0.2,
  floor: 0.3,
  glow: 0.1,
  stars: 0.9,
  cloudTop: Color(0xFF121A30),
  cloudBottom: Color(0xFF2A3052),
  cloudGlint: Color(0xFF8A96C4),
  seaTop: Color(0xFF2E3860),
  seaDeep: Color(0xFF0E1430),
  grass: [
    Color(0xFF06090B),
    Color(0xFF0A0F13),
    Color(0xFF0F161B),
    Color(0xFF151E25),
    Color(0xFF1D2832),
    Color(0xFF2A384C),
    Color(0xFF3E4E6C),
    Color(0xFF6A7CA0),
  ],
  mote: Color(0xFFD0E0FF),
  firefly: 0.4,
);

const _skyDawn = _Light(
  stops: _skyStops,
  sky: [
    Color(0xFF0A1430),
    Color(0xFF132248),
    Color(0xFF213460),
    Color(0xFF384872),
    Color(0xFF5E5A7E),
    Color(0xFF8E6C84),
    Color(0xFFC08A8A),
    Color(0xFFDAA290),
    Color(0xFFDAA290),
  ],
  ambient: Color(0xFF4C4A62),
  rim: Color(0xFFF2A6A0),
  rimStrength: 0.5,
  floor: 0.1,
  glow: 0.55,
  stars: 0.3,
  cloudTop: Color(0xFF383E62),
  cloudBottom: Color(0xFFD69C9C),
  cloudGlint: Color(0xFFFFC8C0),
  seaTop: Color(0xFFD49CA4),
  seaDeep: Color(0xFF343A60),
  grass: [
    Color(0xFF0C1214),
    Color(0xFF121A1C),
    Color(0xFF1A2524),
    Color(0xFF25322C),
    Color(0xFF384234),
    Color(0xFF5A5A44),
    Color(0xFF8C7A66),
    Color(0xFFC6A090),
  ],
  mote: Color(0xFFFFD6C8),
  firefly: 0.4,
);

const _skySunrise = _Light(
  stops: _skyStops,
  sky: [
    Color(0xFF183868),
    Color(0xFF234C80),
    Color(0xFF36649A),
    Color(0xFF5C80AE),
    Color(0xFF9C9CB4),
    Color(0xFFD8AE9C),
    Color(0xFFF6C89C),
    Color(0xFFFFDCAE),
    Color(0xFFFFDCAE),
  ],
  ambient: Color(0xFF8E847E),
  rim: Color(0xFFFFD08E),
  rimStrength: 0.95,
  floor: 0.1,
  glow: 1,
  stars: 0,
  cloudTop: Color(0xFF6E7A9C),
  cloudBottom: Color(0xFFFFC9A0),
  cloudGlint: Color(0xFFFFE4B4),
  seaTop: Color(0xFFFFDDB6),
  seaDeep: Color(0xFF5E6E9C),
  grass: [
    Color(0xFF121A12),
    Color(0xFF1A2618),
    Color(0xFF26341F),
    Color(0xFF384728),
    Color(0xFF556032),
    Color(0xFF84803F),
    Color(0xFFBFA25C),
    Color(0xFFF2D490),
  ],
  mote: Color(0xFFFFE6AC),
  firefly: 0,
);

const _skyMorning = _Light(
  stops: _skyStops,
  sky: [
    Color(0xFF1C5C9E),
    Color(0xFF286CAE),
    Color(0xFF3C84C0),
    Color(0xFF5C9ECE),
    Color(0xFF86BAD8),
    Color(0xFFAED0E2),
    Color(0xFFCADFE8),
    Color(0xFFDDE8EC),
    Color(0xFFDDE8EC),
  ],
  ambient: Color(0xFFE2E0DA),
  rim: Color(0xFFFFF0D2),
  rimStrength: 0.34,
  floor: 0.5,
  glow: 0.5,
  stars: 0,
  cloudTop: Color(0xFFF8F8F4),
  cloudBottom: Color(0xFFB0C8DA),
  cloudGlint: Color(0xFFD0B47E),
  seaTop: Color(0xFFFFF8EC),
  seaDeep: Color(0xFF7EB2D2),
  grass: [
    Color(0xFF1A2A16),
    Color(0xFF263E1C),
    Color(0xFF345424),
    Color(0xFF466C2C),
    Color(0xFF5C8436),
    Color(0xFF789C42),
    Color(0xFF9CB458),
    Color(0xFFC8D284),
  ],
  mote: Color(0xFFF8FAFF),
  firefly: 0,
);

const _skyDay = _Light(
  stops: _skyStops,
  sky: [
    Color(0xFF0B4E8C),
    Color(0xFF135F9E),
    Color(0xFF1F76B2),
    Color(0xFF3290C4),
    Color(0xFF4EA8D4),
    Color(0xFF72BEDE),
    Color(0xFF9ED2E8),
    Color(0xFFBCDDEC),
    Color(0xFFBCDDEC),
  ],
  ambient: Color(0xFFFFFFFF),
  rim: Color(0xFFFFFFFF),
  rimStrength: 0.2,
  floor: 0.8,
  glow: 0.35,
  stars: 0,
  cloudTop: Color(0xFFFDFBF4),
  cloudBottom: Color(0xFF9CC8E2),
  cloudGlint: Color(0xFFD8C08A),
  seaTop: Color(0xFFFFFCF2),
  seaDeep: Color(0xFF6AAED6),
  grass: [
    Color(0xFF1C3418),
    Color(0xFF27461C),
    Color(0xFF345C22),
    Color(0xFF44742A),
    Color(0xFF578C32),
    Color(0xFF70A23C),
    Color(0xFF94BA52),
    Color(0xFFC4D884),
  ],
  mote: Color(0xFFF4FAFF),
  firefly: 0,
);

const _skyAfternoon = _Light(
  stops: _skyStops,
  sky: [
    Color(0xFF13457E),
    Color(0xFF1F5896),
    Color(0xFF3672AC),
    Color(0xFF5E90BE),
    Color(0xFF94AEC6),
    Color(0xFFC6BEB4),
    Color(0xFFE2CAAE),
    Color(0xFFEED6B6),
    Color(0xFFEED6B6),
  ],
  ambient: Color(0xFFDACCB0),
  rim: Color(0xFFFFD69C),
  rimStrength: 0.55,
  floor: 0.3,
  glow: 0.7,
  stars: 0,
  cloudTop: Color(0xFFEEE6DE),
  cloudBottom: Color(0xFFD4AC92),
  cloudGlint: Color(0xFFFFE0B0),
  seaTop: Color(0xFFFFF0DC),
  seaDeep: Color(0xFF8E9CC0),
  grass: [
    Color(0xFF182412),
    Color(0xFF223419),
    Color(0xFF304820),
    Color(0xFF455E28),
    Color(0xFF627034),
    Color(0xFF8E8C44),
    Color(0xFFC0AA60),
    Color(0xFFEED494),
  ],
  mote: Color(0xFFFFEAB8),
  firefly: 0,
);

const _skyGolden = _Light(
  stops: _skyStops,
  sky: [
    Color(0xFF0C1C40),
    Color(0xFF152A56),
    Color(0xFF243E70),
    Color(0xFF485482),
    Color(0xFF8A7C94),
    Color(0xFFD29C80),
    Color(0xFFF2B878),
    Color(0xFFFFD8A0),
    Color(0xFFFFD8A0),
  ],
  ambient: Color(0xFF6A5A50),
  rim: Color(0xFFFFD48E),
  rimStrength: 1,
  floor: 0.06,
  glow: 1,
  stars: 0,
  cloudTop: Color(0xFF2E3658),
  cloudBottom: Color(0xFFEAA87E),
  cloudGlint: Color(0xFFFFDCA0),
  seaTop: Color(0xFFFFD49A),
  seaDeep: Color(0xFF44426C),
  grass: [
    Color(0xFF0E1510),
    Color(0xFF151F17),
    Color(0xFF1F2B1E),
    Color(0xFF2F3B25),
    Color(0xFF4D552F),
    Color(0xFF80763F),
    Color(0xFFBE9F5C),
    Color(0xFFF0D08A),
  ],
  mote: Color(0xFFFFE1A0),
  firefly: 0,
);

const _skySunset = _Light(
  stops: _skyStops,
  sky: [
    Color(0xFF0A1434),
    Color(0xFF112048),
    Color(0xFF202E5C),
    Color(0xFF3C3C68),
    Color(0xFF785270),
    Color(0xFFC26E62),
    Color(0xFFEA8E58),
    Color(0xFFFFAE68),
    Color(0xFFFFAE68),
  ],
  ambient: Color(0xFF42333A),
  rim: Color(0xFFFFA868),
  rimStrength: 0.95,
  floor: 0.06,
  glow: 1,
  stars: 0.05,
  cloudTop: Color(0xFF22284A),
  cloudBottom: Color(0xFFF08C66),
  cloudGlint: Color(0xFFFFC08A),
  seaTop: Color(0xFFFFAA74),
  seaDeep: Color(0xFF362C54),
  grass: [
    Color(0xFF0B100E),
    Color(0xFF121813),
    Color(0xFF1A2219),
    Color(0xFF262E20),
    Color(0xFF3E3E28),
    Color(0xFF6A5A36),
    Color(0xFFA87A48),
    Color(0xFFE09C62),
  ],
  mote: Color(0xFFFFC890),
  firefly: 0.1,
);

const _skyDusk = _Light(
  stops: _skyStops,
  sky: [
    Color(0xFF050A1C),
    Color(0xFF09112A),
    Color(0xFF121C3C),
    Color(0xFF1E2648),
    Color(0xFF2C3050),
    Color(0xFF443A58),
    Color(0xFF5C465C),
    Color(0xFF684E5E),
    Color(0xFF684E5E),
  ],
  ambient: Color(0xFF262436),
  rim: Color(0xFFE89A9A),
  rimStrength: 0.24,
  floor: 0.2,
  glow: 0.4,
  stars: 0.6,
  cloudTop: Color(0xFF121628),
  cloudBottom: Color(0xFF3E3550),
  cloudGlint: Color(0xFFA8809A),
  seaTop: Color(0xFF584A6A),
  seaDeep: Color(0xFF12142C),
  grass: [
    Color(0xFF06090B),
    Color(0xFF0A0F12),
    Color(0xFF0F161A),
    Color(0xFF151E24),
    Color(0xFF1E2830),
    Color(0xFF2C3646),
    Color(0xFF44465E),
    Color(0xFF706078),
  ],
  mote: Color(0xFFD0E0FF),
  firefly: 0.3,
);

/// The Sky's day, on the same hours as the Valley's (the night window lines
/// up with the encounter tables', 20:00–05:00).
const _skyKeys = <(double, _Light)>[
  (0, _skyNight),
  (4.4, _skyNight),
  (5.0, _skyPreDawn),
  (5.6, _skyDawn),
  (6.4, _skySunrise),
  (7.8, _skyMorning),
  (10.0, _skyDay),
  (15.5, _skyDay),
  (17.6, _skyAfternoon),
  (18.7, _skyGolden),
  (19.4, _skySunset),
  (20.1, _skyDusk),
  (21.0, _skyNight),
  (24, _skyNight),
];
