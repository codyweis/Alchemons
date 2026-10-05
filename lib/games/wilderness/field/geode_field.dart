part of 'grain_field.dart';

// Geode Hollow, through the day.
//
// The inside of a geode the size of a cavern. The roof is broken: through
// its cracks the real sky shows — sun, moon in its phase, stars — and the
// light comes down through them in shafts, leaning the way the sun or the
// moon has it, with dust turning in them that a finger stirs. Where a shaft
// lands, the floor and the crystals round it light up; everywhere else is
// the cave's own dark, and the crystals in it glow faintly, more by night.
// Touch a crystal and it rings: the light runs out from it through every
// crystal near it, and grains of light lift off their tips. In a frostfall
// ice comes down through the shafts, glittering where the light catches it,
// and leaves the whole cave rimed in white.
//
// Its own wonders: a great prism stands on the ledge under the first crack,
// and while the shaft finds it (late morning to mid afternoon, as the sun
// leans) it splits the light into a fan of colour across the cave — by
// moonlight, a faint silver one. A black pool on the floor gives back the
// crystals round it; water drips into it from far overhead, and a finger
// drawn through it sends rings out. After dark, threads of glowworm light
// hang from the roof and drift up off their threads when touched. And
// sometimes the cave sings: light rolls through every crystal on its own.
//
// Layers, matching the scene's spawn anchors:
//   sky     — screen-fixed (the camera backdrop): the real sky, seen only
//             through the cracks in the roof
//   layer2  — the far wall, lined with druse, banded like agate
//   layer3  — the roof with its cracks and hanging crystals, the ledge the
//             far creatures stand on, its crystal clusters, the shafts
//   layer4  — the floor, its clusters, columns of ice and split geodes
//   layer5  — crystal points nearest of all, along the bottom
//
// Still sheets are baked as maps (see field_art.dart):
//   far grade    r = haze, g = fleck, b = shade
//   near grades  r = haze, g = fleck, b = shade
//   crystals     r = haze, g = fleck (lit edge), b = shade

class GeodeField extends _GrainField {
  GeodeField();

  static const far = SceneLayer.layer2;
  static const mid = SceneLayer.layer3;
  static const floor = SceneLayer.layer4;
  static const fore = SceneLayer.layer5;

  static const _gWall = 0, _gRoof = 1, _gLedge = 2, _gFloor = 3;
  static const _gAmethyst = 4, _gQuartz = 5, _gIce = 6, _gRind = 7;

  /// The colours of the cave, lit; the hour's light multiplies them.
  static const _albedo = <int, Color>{
    _gWall: Color(0xFF615578),
    _gRoof: Color(0xFF34303E),
    _gLedge: Color(0xFF615A7A),
    _gFloor: Color(0xFF686080),
    _gAmethyst: Color(0xFFB08CF0),
    _gQuartz: Color(0xFFE2E8F2),
    _gIce: Color(0xFFAEE2F4),
    _gRind: Color(0xFF7C7266),
  };

  /// The light crystals give of their own, by type, as a share of their
  /// colour: how they show in the dark.
  static const _emit = <int, double>{
    _gAmethyst: 0.42,
    _gQuartz: 0.3,
    _gIce: 0.38,
  };

  static const _glowColour = <int, Color>{
    _gAmethyst: Color(0xFFC6A2FF),
    _gQuartz: Color(0xFFE6EEFF),
    _gIce: Color(0xFFA8F0FF),
  };

  @override
  List<(double, _Light)> get _keys => _geodeKeys;

  @override
  int get _starCount => 120;

  @override
  double get _starDepth => 0.3;

  // ── The hour ─────────────────────────────────────────────────────────────

  /// How dark the cave is away from the shafts: 1 at night.
  double _dark = 1;

  @override
  void _buildGrades(_Light l) {
    final lum = l.ambient.computeLuminance();
    _dark = (1 - math.sqrt(lum) * 2.2).clamp(0.0, 1.0);
    final rimed = rime;
    final hazeLow = Color.lerp(l.ambient, const Color(0xFF000000), 0.35)!;
    Color sil(int g) {
      var a = _albedo[g]!;
      if (rimed > 0 && g != _gAmethyst) {
        a = Color.lerp(a, const Color(0xFFDCE8F4), rimed * 0.85)!;
      }
      final e = (_emit[g] ?? 0) * (0.35 + 0.65 * _dark);
      return Color.from(
        alpha: 1,
        red: (a.r * l.ambient.r + a.r * e).clamp(0.0, 1.0),
        green: (a.g * l.ambient.g + a.g * e).clamp(0.0, 1.0),
        blue: (a.b * l.ambient.b + a.b * e).clamp(0.0, 1.0),
      );
    }

    final shaft = _shaftColour;
    (double, double, double) fleck(Color s, double k) => (
      s.r * 0.6 + shaft.r * k,
      s.g * 0.6 + shaft.g * k,
      s.b * 0.6 + shaft.b * k,
    );
    for (final g in _albedo.keys) {
      final s = sil(g);
      final crystal = _emit.containsKey(g);
      _grades[g] = fieldGrade(
        base: s,
        r: fieldDiff(hazeLow, s),
        g: fleck(s, crystal ? 0.55 : 0.3),
        b: fieldScale(s, crystal ? -0.55 : -0.75),
      );
    }
  }

  // ── The light through the cracks ─────────────────────────────────────────

  /// The colour of the light coming down the shafts: the sun's by day, the
  /// moon's by night.
  Color get _shaftColour {
    final byMoon = _sunUp < -0.05;
    if (!byMoon) {
      return Color.lerp(
        const Color(0xFFFFF4E0),
        _light.rim,
        0.6 * (1 - _sunUp.clamp(0.0, 1.0)),
      )!;
    }
    return const Color(0xFFB8CCF4);
  }

  /// How strong the shafts are: full under a high sun, faint and blue under
  /// a full moon, nothing on a moonless night or through heavy frostfall.
  double get _shaftStrength {
    final sun = (_sunUp * 2.4 + 0.15).clamp(0.0, 1.0);
    final lit = (1 - math.cos(_moonPhase * 2 * math.pi)) / 2;
    final moon = _sunUp < -0.05
        ? (_moonUp * 2).clamp(0.0, 1.0) * lit * 0.4
        : 0.0;
    return math.max(sun, moon) * (1 - 0.45 * frost);
  }

  /// How far the shafts lean from straight down, as run over drop: away
  /// from wherever the sun (or moon) is across the sky.
  double get _lean {
    final byMoon = _sunUp < -0.05;
    final x = byMoon ? _moonX : _sunX;
    final up = (byMoon ? _moonUp : _sunUp).clamp(0.0, 1.0);
    return (0.5 - x) * 1.5 * (1.15 - 0.7 * up);
  }

  /// The mid layer's left edge, as last drawn: the shafts belong to that
  /// layer, and every other layer finds them through it.
  double _midLeft = 0;

  /// The cracks in the roof, in the mid layer's units: (x, half width at
  /// the roof's underside).
  List<(double, double)> _cracks = const [];

  double get _roofEdgeY => _h * 0.215;

  /// Where the shaft from [crack] reaches [y], its middle.
  double _shaftX(double crackX, double y) => crackX + _lean * (y - _roofEdgeY);

  @override
  Color lightAt(SceneLayer layer, double x, FieldView view) {
    if (layer == mid) _midLeft = view.left;
    final s = _shaftStrength;
    final shaft = _shaftColour;
    if (s <= 0.01 || _cracks.isEmpty) {
      return shaft.withValues(alpha: 0);
    }
    // The shafts, where they reach this layer's ground, in its units.
    final groundY = switch (layer) {
      far => _h * 0.62,
      mid => _h * 0.72,
      fore => _h,
      _ => _h * 0.85,
    };
    final period = _period(mid);
    var k = 0.0;
    for (final (cx, hw) in _cracks) {
      final at = view.left + (_shaftX(cx, groundY) - _midLeft);
      var d = x - at;
      if (period > 0) d -= period * (d / period).roundToDouble();
      final w = hw * 2.4 + 60 * _u;
      k = math.max(k, math.exp(-(d * d) / (w * w)));
    }
    final a = s * k * (layer == far ? 0.8 : 1);
    return shaft.withValues(alpha: a.clamp(0.0, 1.0));
  }

  // ── Weather ──────────────────────────────────────────────────────────────

  /// Ice coming down through the shafts.
  double get frost => weatherKind == WeatherKind.frostfall ? weather : 0;

  /// The cave singing: light rolling through the crystals on its own.
  double get singing => weatherKind == WeatherKind.singing ? weather : 0;

  /// What the frostfall leaves: the cave rimed white.
  double get rime => aftermath * (1 - frost);

  @override
  double get _weatherKey =>
      (frost * 1000).roundToDouble() + (rime * 1000).roundToDouble() * 1000;

  @override
  double get _veil => 0.4 * frost;

  // ── Where the creatures stand ────────────────────────────────────────────

  Iterable<SpawnPoint> get _ledgeStands =>
      _spawns.where((p) => !p.aloft && p.anchor == mid && !_shares(p));

  /// Ground points on the floor too high to stand on it: each gets a split
  /// geode to stand on.
  Iterable<SpawnPoint> get _perched => _spawns.where(
    (p) =>
        !p.aloft &&
        p.anchor == floor &&
        !_shares(p) &&
        _feet(p) < _groundLine(_spawnX(p)) - 6 * _u,
  );

  @override
  double? perchFor(String spawnId) {
    for (final p in _perched) {
      if (p.id == spawnId) return _feet(p);
    }
    for (final p in _spawns) {
      if (p.id == spawnId && _shares(p)) return _sharedPerch(p);
    }
    return null;
  }

  @override
  ({double top, double rest})? groundAt(SceneLayer layer, double x) {
    switch (layer) {
      case mid:
        return (top: _ledge(x) + 3 * _u, rest: _ledge(x) + 14 * _u);
      case floor:
        for (final p in _geodes) {
          final g = _geodeShape(p);
          if (_loopDelta(x, g.x, floor).abs() < g.w * 0.3) {
            return (top: g.top + 2 * _u, rest: g.top);
          }
        }
        return (top: _groundLine(x) + 2 * _u, rest: _groundLine(x) + 0.08 * _h);
      default:
        return null;
    }
  }

  // ── The land ─────────────────────────────────────────────────────────────

  double _nf(double x, double wave, int seed) =>
      fieldLoopNoise(x, wave, seed, _period(far));
  double _nm(double x, double wave, int seed) =>
      fieldLoopNoise(x, wave, seed, _period(mid));
  double _nl(double x, double wave, int seed) =>
      fieldLoopNoise(x, wave, seed, _period(floor));

  /// The roof's underside.
  double _roofEdge(double x) =>
      _h * (0.2 + 0.03 * _nm(x, 180, 61) + 0.012 * _nm(x, 47, 62)) +
      _crackLift(x);

  /// The roof rises into each crack.
  double _crackLift(double x) {
    var y = 0.0;
    for (final (cx, hw) in _cracks) {
      final d = _loopDelta(x, cx, mid);
      final f = math.exp(-math.pow(d / (hw * 2.2), 2));
      y = math.min(y, -f * _h * 0.05);
    }
    return y;
  }

  double _ledgeBase(double x) =>
      _h *
      (0.715 -
          0.03 * (_nm(x, 260, 71) * 0.5 + 0.5) -
          0.012 * _nm(x, 70, 72) -
          0.004 * _nm(x, 19, 73));

  /// The ledge the far creatures stand on, lifted under each so its edge
  /// is above their feet.
  double _ledge(double x) {
    var y = _ledgeBase(x);
    for (final p in _ledgeStands) {
      final sx = _spawnX(p);
      final need = _ledgeBase(sx) - (_feet(p) - 9 * _u);
      if (need <= 0) continue;
      y -= need * math.exp(-math.pow(_loopDelta(x, sx, mid) / 130, 2));
    }
    return y;
  }

  double _groundLine(double x) =>
      _h * (0.812 + 0.012 * _nl(x, 240, 81) + 0.005 * _nl(x, 61, 82));

  double _wallFoot(double x) =>
      _h * (0.62 + 0.03 * _nf(x, 220, 91) + 0.01 * _nf(x, 55, 92));

  // ── Build ────────────────────────────────────────────────────────────────

  List<_Cluster> _midClusters = const [];
  List<_Cluster> _floorClusters = const [];
  _Motes? _dust;

  @override
  List<FieldSheet> build(SceneLayer layer, Size size, Size screen) {
    _h = size.height;
    _u = _h / 475;
    _screen = screen;
    final w = size.width;
    _widths[layer] = w;
    switch (layer) {
      case far:
        _glints[far] = _Glints();
        final bounds = Rect.fromLTWH(0, _h * 0.1, w, _h * 0.72);
        return [
          FieldSheet(
            bounds: bounds,
            resolution: 0.8,
            grade: _gWall,
            paint: (c) => _paintWall(c, w),
          ),
          FieldSheet(
            bounds: bounds,
            resolution: 0.8,
            light: true,
            paint: (c) => _sinking(far, () => _paintWallLight(c, w)),
          ),
        ];
      case mid:
        _glints[mid] = _Glints();
        _cracks = [
          for (final f in const [0.27, 0.71])
            (f * w, (26 + 10 * fieldHash((f * 100).round(), 7)) * _u),
        ];
        _midClusters = [..._makeMidClusters(w), _makePrism()];
        _worms = _makeWorms(w);
        _dust = _Motes.make(w, _h, _u);
        final ledge = Rect.fromLTWH(0, _h * 0.5, w, _h * 0.42);
        final roof = Rect.fromLTWH(0, 0, w, _h * 0.36);
        return [
          FieldSheet(
            bounds: ledge,
            grade: _gLedge,
            paint: (c) => _paintLedge(c, w),
          ),
          FieldSheet(
            bounds: ledge,
            light: true,
            paint: (c) => _rimBands(c, w, _ledge, [(3.0, 0.3), (8.0, 0.12)]),
          ),
          ..._clusterSheets(_midClusters, mid, ledge),
          FieldSheet(
            bounds: roof,
            grade: _gRoof,
            paint: (c) => _paintRoof(c, w),
          ),
          ..._clusterSheets(_hanging(w), mid, roof),
          FieldSheet(
            bounds: roof,
            light: true,
            paint: (c) => _paintRoofLight(c, w),
          ),
        ];
      case floor:
        _glints[floor] = _Glints();
        _floorClusters = _makeFloorClusters(w);
        final ground = Rect.fromLTWH(0, _h * 0.7, w, _h * 0.3);
        return [
          FieldSheet(
            bounds: ground,
            grade: _gFloor,
            paint: (c) => _paintFloor(c, w),
          ),
          FieldSheet(
            bounds: ground,
            light: true,
            paint: (c) => _sinking(floor, () => _paintFloorLight(c, w)),
          ),
          for (final p in _tarns) ..._tarnSheets(p),
          for (final p in _columns) ..._columnSheets(p),
          ..._clusterSheets(_floorClusters, floor, ground),
          for (final p in _geodes) ..._geodeSheets(p),
        ];
      case fore:
        final points = _forePoints(w);
        final bounds = Rect.fromLTWH(0, _h * 0.72, w, _h * 0.3);
        return _clusterSheets(points, fore, bounds);
      default:
        return const [];
    }
  }

  @override
  bool hasLive(SceneLayer layer, {required bool front}) => switch (layer) {
    floor => true,
    far || mid => !front,
    _ => false,
  };

  // ── The far wall ─────────────────────────────────────────────────────────

  void _paintWall(Canvas c, double w) {
    final top = _h * 0.0;
    c.drawRect(
      Rect.fromLTRB(-4, top, w + 4, _h * 0.8),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, top),
          Offset(0, _h * 0.8),
          [
            fieldMap(0.1, 0, 0.55),
            fieldMap(0.25, 0, 0.3),
            fieldMap(0.45, 0, 0.5),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
    // Agate: a few broad soft swells of the geode's wall, each fading in
    // and out rather than edged, as the inside of a geode has them.
    for (var b = 0; b < 3; b++) {
      final y0 = _h * (0.18 + b * 0.14);
      final thick = _h * (0.06 + 0.03 * fieldHash(b, 97));
      double edge(double x) =>
          y0 + _h * 0.06 * _nf(x, 340, 100 + b) + _h * 0.015 * _nf(x, 110, 110);
      for (final (grow, a) in const [(1.0, 0.16), (0.55, 0.18)]) {
        final path = Path()..moveTo(-4, edge(-4) + thick * (1 - grow) / 2);
        for (var x = -4.0; x <= w + 4; x += 8 * _u) {
          path.lineTo(x, edge(x) + thick * (1 - grow) / 2);
        }
        for (var x = w + 4; x >= -4; x -= 8 * _u) {
          path.lineTo(x, edge(x) + thick * (1 + grow) / 2);
        }
        path.close();
        c.drawPath(path, Paint()..color = fieldMap(0.12, 0.1, 0.05, a));
      }
    }
    // Druse: the wall lined with tiny crystals — a few here and there, and
    // gathered thick in hollows, each hollow dark with its crystals catching
    // light along its upper lip.
    final druse = GrainBatch(3);
    final r = FieldRandom(9101);
    for (var i = 0; i < (w * _h * 0.5 / (80 * _u * _u)).round(); i++) {
      final x = r.next() * w;
      final y = top + r.next() * (_wallFoot(x) - top);
      druse.add((r.next() * 2.99).floor(), x, y);
    }
    for (var i = 0; i < (w / (70 * _u)).round(); i++) {
      final x = r.next() * w;
      final y = _h * r.range(0.24, 0.56);
      final rx = r.range(10, 34) * _u, ry = rx * r.range(0.45, 0.7);
      final seed = 9150 + i;
      _wrapped(x, rx, w, (px) {
        final at = Offset(px, y);
        c.drawOval(
          Rect.fromCenter(center: at, width: rx * 2.4, height: ry * 2.4),
          Paint()
            ..shader = Gradient.radial(at, rx * 1.2, [
              fieldMap(0.12, 0, 0.55, 0.32),
              fieldMap(0.12, 0, 0.4, 0),
            ]),
        );
      });
      final n = (rx * ry / (5 * _u * _u)).round();
      for (var j = 0; j < n; j++) {
        final a = fieldHash(j, seed) * math.pi * 2;
        final d = math.sqrt(fieldHash(j, seed + 1));
        final px = x + math.cos(a) * rx * d, py = y + math.sin(a) * ry * d;
        // Lit along the top of the hollow, dark in its depth.
        final lit = math.sin(a) < -0.2 ? 2 : (d > 0.7 ? 1 : 0);
        druse.add(lit, px % w, py);
      }
    }
    for (var t = 0; t < 3; t++) {
      druse.draw(
        c,
        t,
        1.2 * _u,
        fieldMap(0.15, 0.06 + t * 0.12, 0.3 - t * 0.1, 0.55),
      );
    }
    // The wall's foot: rubble and the floor of the far chamber.
    _fillRidge(
      c,
      w,
      _wallFoot,
      Paint()
        ..shader = Gradient.linear(Offset(0, _h * 0.6), Offset(0, _h * 0.8), [
          fieldMap(0.35, 0, 0.35),
          fieldMap(0.5, 0, 0.6),
        ]),
      bottom: _h * 0.82,
      step: 3 * _u,
    );
    // Far off in the hollow, a few great crystals standing in the haze,
    // taller than anything near.
    final gr = FieldRandom(9131);
    var gx = gr.range(100, 300) * _u;
    var gi = 0;
    while (gx < w) {
      final seed = 9170 + gi++;
      final size = gr.range(110, 200) * _u;
      final type = gi.isEven ? _gAmethyst : _gQuartz;
      _wrapped(gx, size, w, (at) {
        final cl = _Cluster.make(
          at,
          _wallFoot(at) + 6 * _u,
          size,
          seed,
          type,
          up: true,
          spread: 0.45,
        );
        for (final k in cl.crystals) {
          _crystal(c, null, k, haze: 0.55);
        }
      });
      gx += gr.range(380, 760) * _u;
    }
    // Far crystals standing along the foot of the wall.
    final rr = FieldRandom(9111);
    var x = rr.range(20, 80) * _u;
    var i = 0;
    while (x < w) {
      final seed = 9200 + i++;
      final size = rr.range(26, 66) * _u;
      final type = i.isEven ? _gAmethyst : _gQuartz;
      _wrapped(x, size * 2, w, (at) {
        final cl = _Cluster.make(
          at,
          _wallFoot(at) + 2 * _u,
          size,
          seed,
          type,
          up: true,
        );
        for (final k in cl.crystals) {
          _crystal(c, null, k, haze: 0.3);
        }
      });
      x += rr.range(45, 130) * _u;
    }
  }

  void _paintWallLight(Canvas c, double w) {
    _rimBands(c, w, _wallFoot, [(3.0, 0.2), (8.0, 0.08)]);
    // Druse glints: the wall twinkles where light finds it.
    final r = FieldRandom(9121);
    final top = _h * 0.14;
    for (var i = 0; i < (w / (16 * _u)).round(); i++) {
      final x = r.next() * w;
      _glint(x, top + r.next() * (_wallFoot(x) - top));
    }
  }

  // ── The roof, its cracks, its hanging crystals ───────────────────────────

  Path _roofPath(double w) {
    final body = Path()..moveTo(-4, -10);
    body.lineTo(w + 4, -10);
    for (var x = w + 4; x >= -4; x -= 3 * _u) {
      body.lineTo(x, _roofEdge(x));
    }
    body.close();
    // The cracks, cut right through to the sky.
    var holes = Path();
    for (final (cx, hw) in _cracks) {
      for (final shift in [0.0, if (_loop) -w, if (_loop) w]) {
        final at = cx + shift;
        if (at + hw * 4 < -4 || at - hw * 4 > w + 4) continue;
        holes = Path.combine(
          PathOperation.union,
          holes,
          _crackPath(at, cx, hw),
        );
      }
    }
    return Path.combine(PathOperation.difference, body, holes);
  }

  /// A crack through the roof at [at] (the crack at [cx] of half width
  /// [hw], drawn at one of its repeats): a ragged fissure, widest up at the
  /// sky, pinching to a narrow mouth at the roof's underside.
  Path _crackPath(double at, double cx, double hw) {
    final (left, right, mouth) = _crackOutline(at, cx, hw);
    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (final p in left.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    // The mouth comes to a ragged point, not a lintel.
    path.lineTo(mouth.dx, mouth.dy);
    for (final p in right.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// The crack's two sides, top to bottom, and the point of its mouth.
  (List<Offset>, List<Offset>, Offset) _crackOutline(
    double at,
    double cx,
    double hw,
  ) {
    const steps = 12;
    final edgeY = _roofEdge(at) + 4 * _u;
    final seed = (cx * 3).round();
    final left = <Offset>[], right = <Offset>[];
    for (var k = 0; k <= steps; k++) {
      final f = k / steps;
      final y = -10 + (edgeY + 10) * f;
      final narrow = math.pow(f, 0.8).toDouble();
      final wobble = fieldNoise(f * 5, seed) * hw * 0.45;
      left.add(
        Offset(
          at -
              hw * (2.1 - 1.55 * narrow) +
              wobble +
              (fieldHash(k, seed) - 0.5) * 5 * _u,
          y,
        ),
      );
      right.add(
        Offset(
          at +
              hw * (2.1 - 1.55 * narrow) +
              wobble * 0.6 +
              (fieldHash(k + 40, seed) - 0.5) * 5 * _u,
          y,
        ),
      );
    }
    return (left, right, Offset(at + hw * 0.1, edgeY + 7 * _u));
  }

  void _paintRoof(Canvas c, double w) {
    final roof = _roofPath(w);
    c.drawPath(
      roof,
      Paint()
        ..shader = Gradient.linear(Offset.zero, Offset(0, _h * 0.26), [
          fieldMap(0, 0, 0.85),
          fieldMap(0.04, 0, 0.45),
        ]),
    );
    // Its underside is druse too.
    c
      ..save()
      ..clipPath(roof);
    final druse = GrainBatch(2);
    final r = FieldRandom(9301);
    for (var i = 0; i < (w / (1.2 * _u)).round(); i++) {
      final x = r.next() * w;
      final y = _roofEdge(x) - math.pow(r.next(), 2) * 30 * _u;
      druse.add(r.next() < 0.5 ? 0 : 1, x, y);
    }
    druse.draw(c, 0, 1.4 * _u, fieldMap(0.04, 0.15, 0.3, 0.8));
    druse.draw(c, 1, 1.2 * _u, fieldMap(0.04, 0.3, 0.15, 0.8));
    c.restore();
  }

  void _paintRoofLight(Canvas c, double w) {
    // The cracks' edges, lit from the sky.
    final roof = _roofPath(w);
    c
      ..save()
      ..clipPath(roof);
    for (final (cx, hw) in _cracks) {
      for (final shift in [0.0, if (_loop) -w, if (_loop) w]) {
        final at = cx + shift;
        c.drawCircle(
          Offset(at, _roofEdge(at) - 6 * _u),
          hw * 3.2,
          Paint()
            ..shader =
                Gradient.radial(Offset(at, _roofEdge(at) - 6 * _u), hw * 3.2, [
                  const Color(0xFFFFFFFF).withValues(alpha: 0.55),
                  const Color(0xFFFFFFFF).withValues(alpha: 0.0),
                ]),
        );
      }
    }
    c.restore();
  }

  /// Crystals hanging from the roof, points down.
  List<_Cluster> _hanging(double w) {
    final r = FieldRandom(9401);
    final out = <_Cluster>[];
    var x = r.range(20, 90) * _u;
    var i = 0;
    while (x < w) {
      // Not across a crack: the light comes down through those.
      final clear = _cracks.every(
        (cr) => _loopDelta(x, cr.$1, mid).abs() > cr.$2 * 3,
      );
      // Mostly small, now and then a great one; some tucked up into the
      // roof, some hanging clear of it.
      final size = (12 + 50 * math.pow(r.next(), 2.2)) * _u;
      if (clear && r.next() > 0.18) {
        final roll = r.next();
        final type = roll < 0.5 ? _gAmethyst : (roll < 0.78 ? _gQuartz : _gIce);
        out.add(
          _Cluster.make(
            x,
            _roofEdge(x) - r.range(2, 12) * _u,
            size,
            9500 + i,
            type,
            up: false,
            spread: r.range(0.35, 0.95),
          ),
        );
      }
      i++;
      x += r.range(22, 150) * _u * (0.6 + size / (60 * _u));
    }
    return out;
  }

  // ── The ledge ────────────────────────────────────────────────────────────

  void _paintLedge(Canvas c, double w) {
    _fillRidge(
      c,
      w,
      _ledge,
      Paint()
        ..shader = Gradient.linear(Offset(0, _h * 0.64), Offset(0, _h * 0.9), [
          fieldMap(0.08, 0.05, 0.1),
          fieldMap(0.15, 0, 0.55),
        ]),
      bottom: _h * 0.92,
      step: 2.5 * _u,
    );
    final grit = GrainBatch(2);
    final r = FieldRandom(9601);
    for (var i = 0; i < (w * 1.4).round(); i++) {
      final x = r.next() * w;
      final y = _ledge(x) + 2 * _u + math.pow(r.next(), 1.4) * 50 * _u;
      grit.add(r.next() < 0.6 ? 0 : 1, x, y);
    }
    grit.draw(c, 0, 1.3 * _u, fieldMap(0.08, 0, 0.7, 0.8));
    grit.draw(c, 1, 1.2 * _u, fieldMap(0.08, 0.25, 0.1, 0.8));
  }

  List<_Cluster> _makeMidClusters(double w) {
    final out = <_Cluster>[];
    if (_placed) {
      for (final p in _piecesOn(mid, {FieldPiece.cluster})) {
        final x = _spawnX(p);
        final seed = fieldSeedOf(p.id);
        out.add(
          _Cluster.make(
            x,
            _ledge(x) + 4 * _u,
            p.size.y * _u * 0.62,
            seed,
            _typeOf(seed),
            up: true,
          ),
        );
      }
      return out;
    }
    for (final (fx, size, type) in _wildMidClusters) {
      final x = fx * w;
      out.add(
        _Cluster.make(
          x,
          _ledge(x) + 4 * _u,
          size * _u,
          (fx * 1000).round(),
          type,
          up: true,
        ),
      );
    }
    return out;
  }

  /// The ledge's crystal clusters where the wild has them: (x as a share
  /// of the loop, size, type).
  static const _wildMidClusters = <(double, double, int)>[
    (0.06, 34, _gAmethyst),
    (0.36, 28, _gQuartz),
    (0.53, 40, _gIce),
    (0.82, 30, _gAmethyst),
    (0.95, 22, _gQuartz),
  ];

  // ── The floor ────────────────────────────────────────────────────────────

  void _paintFloor(Canvas c, double w) {
    _fillRidge(
      c,
      w,
      _groundLine,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, _h * 0.79),
          Offset(0, _h),
          [fieldMap(0, 0.05, 0.1), fieldMap(0, 0, 0.35), fieldMap(0, 0, 0.75)],
          const [0.0, 0.3, 1.0],
        ),
      bottom: _h,
      step: 2.5 * _u,
    );
    // Stone, not speckle: broad soft patches of darker and paler rock,
    // pebbles lit on top, and a little grit.
    final rr = FieldRandom(9711);
    for (var i = 0; i < (w / (90 * _u)).round(); i++) {
      final x = rr.next() * w;
      final g = _groundLine(x);
      final y = g + 6 * _u + math.pow(rr.next(), 1.1) * (_h - g);
      final rx = rr.range(30, 90) * _u * (0.5 + (y - g) / (_h - g));
      final dark = rr.next() < 0.6;
      final at = Offset(x, y);
      _wrapped(x, rx, w, (px) {
        final c0 = Offset(px, at.dy);
        c.drawOval(
          Rect.fromCenter(center: c0, width: rx * 2, height: rx * 0.36),
          Paint()
            ..shader = Gradient.radial(c0, rx, [
              dark ? fieldMap(0, 0, 0.75, 0.55) : fieldMap(0, 0.12, 0.1, 0.4),
              fieldMap(0, 0, 0.4, 0),
            ]),
        );
      });
    }
    for (var i = 0; i < (w / (26 * _u)).round(); i++) {
      final x = rr.next() * w;
      final g = _groundLine(x);
      final f = math.pow(rr.next(), 1.2).toDouble();
      final y = g + 4 * _u + f * (_h - g);
      final r = (1.5 + 4 * rr.next()) * _u * (0.6 + f);
      _wrapped(x, r, w, (px) {
        c
          ..drawOval(
            Rect.fromCenter(
              center: Offset(px, y),
              width: r * 2.2,
              height: r * 1.3,
            ),
            Paint()..color = fieldMap(0, 0, 0.6),
          )
          ..drawOval(
            Rect.fromCenter(
              center: Offset(px - r * 0.2, y - r * 0.3),
              width: r * 1.5,
              height: r * 0.6,
            ),
            Paint()..color = fieldMap(0, 0.22, 0.1),
          );
      });
    }
    final grit = GrainBatch(2);
    for (var i = 0; i < (w * 0.6).round(); i++) {
      final x = rr.next() * w;
      final g = _groundLine(x);
      final y = g + 3 * _u + math.pow(rr.next(), 1.3) * (_h - g);
      grit.add(rr.next() < 0.7 ? 0 : 1, x, y);
    }
    grit.draw(c, 0, 1.3 * _u, fieldMap(0, 0, 0.7, 0.5));
    grit.draw(c, 1, 1.3 * _u, fieldMap(0, 0.12, 0.2, 0.4));
  }

  void _paintFloorLight(Canvas c, double w) {
    _rimBands(c, w, _groundLine, [(3.0, 0.24), (9.0, 0.1)]);
    final r = FieldRandom(9721);
    for (var i = 0; i < (w / (16 * _u)).round(); i++) {
      final x = r.next() * w;
      final g = _groundLine(x);
      _glint(x, g + 3 * _u + math.pow(r.next(), 1.3) * (_h - g - 4 * _u));
    }
  }

  List<_Cluster> _makeFloorClusters(double w) {
    final out = <_Cluster>[];
    final list = _placed
        ? [
            for (final p in _piecesOn(floor, {FieldPiece.cluster}))
              (_spawnX(p), p.size.y, fieldSeedOf(p.id)),
          ]
        : [
            for (final (fx, size, _) in _wildFloorClusters)
              (fx * w, size, (fx * 1000).round() + 17),
          ];
    for (var i = 0; i < list.length; i++) {
      final (x, size, seed) = list[i];
      final type = _placed ? _typeOf(seed) : _wildFloorClusters[i].$3;
      out.add(
        _Cluster.make(
          x,
          _groundLine(x) + 0.03 * _h,
          size * _u * 0.62,
          seed,
          type,
          up: true,
        ),
      );
    }
    return out;
  }

  int _typeOf(int seed) => const [_gAmethyst, _gQuartz, _gIce][seed % 3];

  /// The floor's crystal clusters where the wild has them: (x as a share
  /// of the loop, height, type).
  static const _wildFloorClusters = <(double, double, int)>[
    (0.03, 80, _gQuartz),
    (0.25, 110, _gAmethyst),
    (0.445, 72, _gIce),
    (0.73, 120, _gIce),
  ];

  /// The floor's ice columns where the wild has them: (x, width, height).
  static const _wildColumns = <(double, double, double)>[(0.94, 26, 150)];

  /// The scenery as the home biome first has it: (far row?, piece, x as a
  /// share of its row's loop, width, height).
  static List<(bool, String, double, double, double)> get homeScenery => [
    for (final (fx, size, _) in _wildMidClusters)
      (true, FieldPiece.cluster, fx, size / 0.62, size / 0.62),
    for (final (fx, size, _) in _wildFloorClusters)
      (false, FieldPiece.cluster, fx, size, size),
    for (final (fx, w, h) in _wildColumns) (false, FieldPiece.column, fx, w, h),
    for (final (fx, hw) in _wildTarns) (false, FieldPiece.tarn, fx, hw, 30),
  ];

  // ── Crystals ─────────────────────────────────────────────────────────────

  List<FieldSheet> _clusterSheets(
    List<_Cluster> clusters,
    SceneLayer layer,
    Rect area,
  ) {
    if (clusters.isEmpty) return const [];
    final byType = <int, List<_Cluster>>{};
    for (final cl in clusters) {
      byType.putIfAbsent(cl.type, () => []).add(cl);
    }
    final w = _widths[layer] ?? _worldWidth;
    final near = layer == fore;
    return [
      for (final MapEntry(key: type, value: list) in byType.entries)
        FieldSheet(
          bounds: area,
          grade: type,
          paint: (c) {
            for (final cl in list) {
              _wrapped(cl.x, cl.reach, w, (at) {
                for (final k in cl.at(at).crystals) {
                  _crystal(c, null, k, haze: near ? 0 : 0.04, dark: near);
                }
              });
            }
          },
        ),
      FieldSheet(
        bounds: area,
        light: true,
        paint: (c) => _sinking(layer, () {
          final sparks = GrainBatch(_sparkAlpha.length);
          for (final cl in clusters) {
            _wrapped(cl.x, cl.reach, w, (at) {
              for (final k in cl.at(at).crystals) {
                _crystal(_NullCanvas(), sparks, k);
                _crystalEdge(c, k);
              }
            });
          }
          _drawSparks(c, sparks, 1.3);
        }),
      ),
    ];
  }

  /// One crystal: a six-sided prism seen from the side — a lit face, a face
  /// in half shade and one in shadow — ending in a pointed tip. Each face
  /// clears toward the tip as light goes into it, and the body is full of
  /// small inclusions, grains a shade lighter or darker, so it reads as
  /// stone grown clear rather than a flat shape.
  void _crystal(
    Canvas c,
    GrainBatch? sparks,
    _Crystal k, {
    double haze = 0,
    bool dark = false,
  }) {
    final dir = Offset(math.sin(k.angle), -math.cos(k.angle));
    final side = Offset(-dir.dy, dir.dx);
    final half = k.width / 2;
    final body = k.length * 0.78;
    Offset at(double s, double l) => k.base + side * (s * half) + dir * l;
    final tip = at(0.05, k.length);
    if (sparks != null) {
      // Light along its two ridges, thickest toward the top, and at its tip.
      for (final (s, k0) in const [(-0.25, 0.55), (0.45, 0.35)]) {
        final n = (body / (1.7 * _u)).ceil();
        for (var i = 0; i < n; i++) {
          final f = i / n;
          if (fieldHash(i + (s * 100).round(), k.seed) > k0 * f + 0.05) {
            continue;
          }
          final p = at(s, body * f);
          sparks.add(f > 0.7 ? 2 : 1, p.dx, p.dy);
        }
      }
      sparks.add(3, tip.dx, tip.dy);
      if (fieldHash(k.seed, 3) < 0.6) _glint(tip.dx, tip.dy);
      return;
    }
    final shade = dark ? 0.55 : 0.0;
    final b0 = at(0, 0), b1 = at(0, k.length);
    Paint face(List<Color> cols) =>
        Paint()..shader = Gradient.linear(b0, b1, cols, const [0.0, 0.62, 1.0]);
    // Three faces of the prism, each clearing toward the tip.
    c
      ..drawPath(
        Path()
          ..moveTo(at(-1, 0).dx, at(-1, 0).dy)
          ..lineTo(at(-1, body).dx, at(-1, body).dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(at(-0.25, body).dx, at(-0.25, body).dy)
          ..lineTo(at(-0.25, 0).dx, at(-0.25, 0).dy)
          ..close(),
        face([
          fieldMap(haze, 0.05, shade + 0.45, 0.9),
          fieldMap(haze, 0.32, shade + 0.05),
          fieldMap(haze, 0.6, shade),
        ]),
      )
      ..drawPath(
        Path()
          ..moveTo(at(-0.25, 0).dx, at(-0.25, 0).dy)
          ..lineTo(at(-0.25, body).dx, at(-0.25, body).dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(at(0.45, body).dx, at(0.45, body).dy)
          ..lineTo(at(0.45, 0).dx, at(0.45, 0).dy)
          ..close(),
        face([
          fieldMap(haze, 0, shade + 0.62, 0.9),
          fieldMap(haze, 0.1, shade + 0.25),
          fieldMap(haze, 0.25, shade + 0.1),
        ]),
      )
      ..drawPath(
        Path()
          ..moveTo(at(0.45, 0).dx, at(0.45, 0).dy)
          ..lineTo(at(0.45, body).dx, at(0.45, body).dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(at(1, body).dx, at(1, body).dy)
          ..lineTo(at(1, 0).dx, at(1, 0).dy)
          ..close(),
        face([
          fieldMap(haze, 0, shade + 0.9, 0.9),
          fieldMap(haze, 0, shade + 0.62),
          fieldMap(haze, 0.06, shade + 0.42),
        ]),
      );
    // Inclusions: grains through the body, lighter up toward the light.
    final grains = GrainBatch(2);
    final n = (k.width * body / (16 * _u * _u)).round().clamp(3, 300);
    for (var i = 0; i < n; i++) {
      final s = fieldHash(i, k.seed + 11) * 1.8 - 0.9;
      final f = math.pow(fieldHash(i, k.seed + 13), 0.8).toDouble();
      final p = at(s, body * f);
      grains.add(
        fieldHash(i, k.seed + 17) < 0.35 + f * 0.4 ? 0 : 1,
        p.dx,
        p.dy,
      );
    }
    grains
      ..draw(c, 0, 1.0 * _u, fieldMap(haze, 0.45, shade, 0.3))
      ..draw(c, 1, 0.9 * _u, fieldMap(haze, 0, shade + 0.6, 0.22));
  }

  /// A crystal's lit edge on a light sheet: light lying along its lit face,
  /// strongest toward the tip, which the shafts colour.
  void _crystalEdge(Canvas c, _Crystal k) {
    final dir = Offset(math.sin(k.angle), -math.cos(k.angle));
    final side = Offset(-dir.dy, dir.dx);
    final half = k.width / 2;
    final body = k.length * 0.78;
    Offset at(double s, double l) => k.base + side * (s * half) + dir * l;
    c.drawPath(
      Path()
        ..moveTo(at(-1, body * 0.2).dx, at(-1, body * 0.2).dy)
        ..lineTo(at(-1, body).dx, at(-1, body).dy)
        ..lineTo(at(0.05, k.length).dx, at(0.05, k.length).dy)
        ..lineTo(at(-0.55, body).dx, at(-0.55, body).dy)
        ..lineTo(at(-0.55, body * 0.2).dx, at(-0.55, body * 0.2).dy)
        ..close(),
      Paint()
        ..shader = Gradient.linear(at(0, body * 0.2), at(0, k.length), [
          const Color(0x00FFFFFF),
          const Color(0xFFFFFFFF).withValues(alpha: 0.45),
        ]),
    );
  }

  /// Crystal points nearest of all, along the bottom of the screen.
  List<_Cluster> _forePoints(double w) {
    final r = FieldRandom(9801);
    final out = <_Cluster>[];
    var x = r.range(200, 400) * _u;
    var i = 0;
    while (x < w) {
      out.add(
        _Cluster.make(
          x,
          _h + 12 * _u,
          r.range(36, 60) * _u,
          9900 + i,
          const [_gAmethyst, _gIce][i % 2],
          up: true,
          spread: 0.5,
        ),
      );
      i++;
      x += r.range(650, 1250) * _u;
    }
    return out;
  }

  // ── Columns of ice ───────────────────────────────────────────────────────

  List<SpawnPoint> get _columns => [
    if (_placed)
      ..._piecesOn(floor, {FieldPiece.column})
    else
      for (var i = 0; i < _wildColumns.length; i++)
        SpawnPoint(
          id: 'geode_column_$i',
          normalizedPos: Offset(_wildColumns[i].$1, 0),
          anchor: floor,
          size: Vector2(_wildColumns[i].$2, _wildColumns[i].$3),
          piece: FieldPiece.column,
        ),
  ];

  List<FieldSheet> _columnSheets(SpawnPoint p) {
    final x = _spawnX(p);
    final w = p.size.x * _u, h = p.size.y * _u;
    final foot = _groundLine(x) + 0.03 * _h;
    final bounds = Rect.fromLTRB(
      x - w,
      foot - h - 10 * _u,
      x + w,
      foot + 6 * _u,
    );
    final k = _Crystal(
      base: Offset(x, foot + 4 * _u),
      angle: (fieldHash(fieldSeedOf(p.id), 5) - 0.5) * 0.08,
      length: h,
      width: w,
      seed: fieldSeedOf(p.id),
    );
    return [
      FieldSheet(
        bounds: bounds,
        grade: _gIce,
        paint: (c) => _crystal(c, null, k),
      ),
      FieldSheet(
        bounds: bounds,
        light: true,
        paint: (c) => _sinking(floor, () {
          final sparks = GrainBatch(_sparkAlpha.length);
          _crystal(_NullCanvas(), sparks, k);
          _crystalEdge(c, k);
          _drawSparks(c, sparks, 1.4);
        }),
      ),
    ];
  }

  // ── Split geodes ─────────────────────────────────────────────────────────

  /// The split geodes on the floor: one under each high point, and those
  /// placed by hand.
  List<SpawnPoint> get _geodes => [
    ..._perched,
    if (_placed) ..._piecesOn(floor, {FieldPiece.geode}),
  ];

  ({double x, double top, double base, double w}) _geodeShape(SpawnPoint p) {
    final x = _spawnX(p);
    final base = _groundLine(x) + 0.035 * _h;
    if (p.piece == FieldPiece.geode) {
      return (x: x, top: base - p.size.y * _u, base: base, w: p.size.x * _u);
    }
    final top = _feet(p);
    final w = math.max(p.size.x * 1.25, (base - top) * 1.3);
    return (x: x, top: top, base: base, w: w);
  }

  List<FieldSheet> _geodeSheets(SpawnPoint p) {
    final g = _geodeShape(p);
    final bounds = Rect.fromLTRB(
      g.x - g.w * 0.65,
      g.top - 10 * _u,
      g.x + g.w * 0.65,
      g.base + 6 * _u,
    );
    return [
      FieldSheet(bounds: bounds, grade: _gRind, paint: (c) => _geodeRind(c, g)),
      FieldSheet(
        bounds: bounds,
        grade: _gAmethyst,
        paint: (c) => _geodeHeart(c, g, fieldSeedOf(p.id)),
      ),
      FieldSheet(
        bounds: bounds,
        light: true,
        paint: (c) =>
            _sinking(floor, () => _geodeLight(c, g, fieldSeedOf(p.id))),
      ),
    ];
  }

  /// A rough loop round [c], [rx] across and [ry] down, its radius wandering
  /// by [rough] — a stone's outline, or a band inside one.
  List<Offset> _blob(Offset c, double rx, double ry, int seed, double rough) {
    const n = 40;
    return [
      for (var i = 0; i < n; i++)
        () {
          final a = i / n * math.pi * 2;
          final k =
              1 +
              rough *
                  (fieldNoise(i / n * 7, seed) * 0.7 +
                      fieldNoise(i / n * 19, seed + 1) * 0.3);
          return Offset(
            c.dx + math.cos(a) * rx * k,
            c.dy + math.sin(a) * ry * k,
          );
        }(),
    ];
  }

  Path _outlineOf(List<Offset> pts) => Path()..addPolygon(pts, true);

  /// A geode's outline: a rough rounded stone, broad at the foot, its top
  /// worn flat enough to stand on.
  List<Offset> _geodeStone(({double x, double top, double base, double w}) g) {
    final h = g.base - g.top;
    final c = Offset(g.x, g.top + h * 0.56);
    return [
      for (final p in _blob(c, g.w * 0.5, h * 0.6, (g.x * 7).round(), 0.07))
        Offset(p.dx, p.dy.clamp(g.top + h * 0.02, g.base + 2 * _u)),
    ];
  }

  /// The face it was split along, toward the viewer.
  ({Offset c, double rx, double ry}) _geodeFace(
    ({double x, double top, double base, double w}) g,
  ) {
    final h = g.base - g.top;
    return (
      c: Offset(g.x + g.w * 0.03, g.top + h * 0.58),
      rx: g.w * 0.39,
      ry: h * 0.4,
    );
  }

  void _geodeRind(Canvas c, ({double x, double top, double base, double w}) g) {
    final seed = (g.x * 7).round();
    final stone = _outlineOf(_geodeStone(g));
    final h = g.base - g.top;
    // The rind: rough, dull stone, lit from above, in shade toward its foot.
    c.drawPath(
      stone,
      Paint()
        ..shader = Gradient.linear(
          Offset(g.x - g.w * 0.3, g.top),
          Offset(g.x + g.w * 0.2, g.base),
          [fieldMap(0.02, 0.18, 0.1), fieldMap(0.02, 0, 0.65)],
        ),
    );
    c
      ..save()
      ..clipPath(stone);
    final pits = GrainBatch(2);
    for (var i = 0; i < (g.w * h / (10 * _u * _u)).round(); i++) {
      pits.add(
        fieldHash(i, seed) < 0.6 ? 0 : 1,
        g.x + (fieldHash(i, seed + 1) - 0.5) * g.w,
        g.top + fieldHash(i, seed + 2) * h,
      );
    }
    pits
      ..draw(c, 0, 1.4 * _u, fieldMap(0.02, 0, 0.8, 0.7))
      ..draw(c, 1, 1.2 * _u, fieldMap(0.02, 0.3, 0.2, 0.6));
    c.restore();
    // Agate: bands following the stone's own wander, a shade apart — milky,
    // smoky, milky — each a little rougher than the last.
    final f = _geodeFace(g);
    for (final (k, lit, shade) in const [
      (1.0, 0.12, 0.25),
      (0.86, 0.32, 0.08),
      (0.76, 0.05, 0.45),
      (0.68, 0.24, 0.15),
    ]) {
      c.drawPath(
        _outlineOf(
          _blob(f.c, f.rx * k, f.ry * k, seed + (k * 100).round(), 0.08),
        ),
        Paint()..color = fieldMap(0.02, lit, shade),
      );
    }
  }

  /// The hollow heart of the split geode, lined with crystals pointing in.
  void _geodeHeart(
    Canvas c,
    ({double x, double top, double base, double w}) g,
    int seed,
  ) {
    final f = _geodeFace(g);
    final cavity = _outlineOf(_blob(f.c, f.rx * 0.6, f.ry * 0.58, seed, 0.12));
    c.drawPath(cavity, Paint()..color = fieldMap(0.02, 0, 0.85));
    c
      ..save()
      ..clipPath(cavity);
    const n = 22;
    for (var i = 0; i < n; i++) {
      final a = i / n * math.pi * 2 + fieldHash(i, seed) * 0.25;
      final rim = Offset(
        f.c.dx + math.cos(a) * f.rx * 0.62,
        f.c.dy + math.sin(a) * f.ry * 0.6,
      );
      final len = f.ry * (0.32 + 0.3 * fieldHash(i + 3, seed));
      _crystal(
        c,
        null,
        _Crystal(
          base: rim,
          // Pointing in, toward the middle, give or take.
          angle:
              math.atan2(f.c.dx - rim.dx, -(f.c.dy - rim.dy)) +
              (fieldHash(i, seed + 4) - 0.5) * 0.5,
          length: len,
          width: len * 0.4,
          seed: seed + i,
        ),
      );
    }
    c.restore();
  }

  void _geodeLight(
    Canvas c,
    ({double x, double top, double base, double w}) g,
    int seed,
  ) {
    final sparks = GrainBatch(_sparkAlpha.length);
    // Light along the stone's top.
    final stone = _geodeStone(g);
    for (var i = 0; i < stone.length; i++) {
      final p = stone[i];
      if (p.dy > g.top + (g.base - g.top) * 0.25) continue;
      final roll = fieldHash(i, seed);
      if (roll > 0.75) continue;
      sparks.add((roll * 5).floor().clamp(0, 3), p.dx, p.dy + 0.8 * _u);
    }
    // Light caught deep in the heart.
    final f = _geodeFace(g);
    for (var i = 0; i < 28; i++) {
      final a = fieldHash(i, seed + 5) * math.pi * 2;
      final r = 0.2 + 0.4 * fieldHash(i, seed + 6);
      final p = Offset(
        f.c.dx + math.cos(a) * f.rx * r,
        f.c.dy + math.sin(a) * f.ry * r,
      );
      sparks.add(2 + (i % 2), p.dx, p.dy);
      if (i % 5 == 0) _glint(p.dx, p.dy);
    }
    _drawSparks(c, sparks, 1.3);
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
        _paintSparkles(
          canvas,
          view,
          far,
          _glints[far],
          alpha: 0.3 + 0.3 * _dark,
        );
        _paintFall(canvas, view, far, 0.5);
      case mid:
        _midLeft = view.left;
        _paintCracks(canvas, view);
        _paintShafts(canvas, view);
        _paintPrism(canvas, view);
        _stirDust(view);
        _paintDust(canvas, view);
        _sing(view);
        _paintGlow(canvas, view, mid, _midClusters);
        _paintWorms(canvas, view);
        _paintSparkles(
          canvas,
          view,
          mid,
          _glints[mid],
          alpha: 0.6 + 0.4 * _dark,
        );
        _paintFall(canvas, view, mid, 0.8);
      case floor:
        if (!front) {
          _paintPools(canvas, view);
          _paintTarns(canvas, view);
          _paintCrystalLight(canvas, view);
          _paintGlow(canvas, view, floor, _floorClusters);
          _paintSparkles(
            canvas,
            view,
            floor,
            _glints[floor],
            alpha: 0.55 + 0.45 * math.max(_dark, rime),
          );
        } else {
          _paintRings(canvas, view);
          _paintFall(canvas, view, floor, 1.2);
        }
      default:
        break;
    }
  }

  final GrainBatch _sparkBatch = GrainBatch(2);

  /// Glints as fine points that flash and are gone — never a halo.
  void _paintSparkles(
    Canvas canvas,
    FieldView view,
    SceneLayer layer,
    _Glints? g, {
    required double alpha,
  }) {
    if (g == null || g.n == 0 || alpha <= 0.01) return;
    final t = view.time;
    _sparkBatch.clear();
    var any = false;
    final loops = _shiftsFor(layer, view, 4);
    for (var i = 0; i < g.n; i++) {
      final s = math.sin(t * g.speed[i] * 2.2 + g.phase[i]);
      if (s < 0.8) continue;
      var x = g.x[i] + 0.0;
      for (final sh in loops) {
        if (x + sh >= view.left - 4 && x + sh <= view.right + 4) {
          x += sh;
          break;
        }
      }
      if (x < view.left - 4 || x > view.right + 4) continue;
      _sparkBatch.add(s > 0.94 ? 1 : 0, x, g.y[i]);
      any = true;
    }
    if (!any) return;
    final col = Color.lerp(_shaftColour, const Color(0xFFFFFFFF), 0.5)!;
    _sparkBatch
      ..draw(canvas, 0, 1.2 * _u, col.withValues(alpha: 0.55 * alpha))
      ..draw(canvas, 1, 3.0 * _u, col.withValues(alpha: 0.16 * alpha))
      ..draw(canvas, 1, 1.5 * _u, col.withValues(alpha: 0.95 * alpha));
  }

  static final Paint _plus = Paint()..blendMode = BlendMode.plus;

  final GrainBatch _crackStars = GrainBatch(2);

  /// The sky through each crack, as the hour has it, with its stars at
  /// night.
  void _paintCracks(Canvas canvas, FieldView view) {
    final l = _light;
    Color sky(double y) => l.skyAt((y / (_h * 0.6)).clamp(0.0, 1.0));
    final t = view.time;
    for (final shift in _shiftsFor(mid, view, 120 * _u)) {
      for (final (cx, hw) in _cracks) {
        final at = cx + shift;
        if (at + hw * 3 < view.left || at - hw * 3 > view.right) continue;
        // A strip of triangles down the crack, side to side, each corner
        // the sky's colour at its height.
        final (left, right, mouth) = _crackOutline(at, cx, hw);
        final pos = <Offset>[], cols = <Color>[];
        for (var i = 0; i + 1 < left.length; i++) {
          final a = left[i], b = right[i], c = left[i + 1], d = right[i + 1];
          pos.addAll([a, b, c, b, d, c]);
          cols.addAll([
            sky(a.dy),
            sky(b.dy),
            sky(c.dy),
            sky(b.dy),
            sky(d.dy),
            sky(c.dy),
          ]);
        }
        pos.addAll([left.last, right.last, mouth]);
        cols.addAll([sky(left.last.dy), sky(right.last.dy), sky(mouth.dy)]);
        canvas.drawVertices(
          Vertices(VertexMode.triangles, pos, colors: cols),
          BlendMode.dst,
          _meshPaint,
        );
        if (l.stars > 0.05) {
          // Stars, each somewhere between the crack's two sides.
          _crackStars.clear();
          final seed = (cx * 7).round();
          for (var i = 0; i < 26; i++) {
            final row = (fieldHash(i, seed) * (left.length - 1)).floor();
            final across = fieldHash(i, seed + 1);
            final p = Offset.lerp(left[row], right[row], across)!;
            final tw = math.sin(t * (0.8 + fieldHash(i, 31) * 1.4) + i);
            _crackStars.add(tw > 0.2 ? 1 : 0, p.dx, p.dy + 3 * _u);
          }
          const star = Color(0xFFE8ECFF);
          _crackStars
            ..draw(canvas, 0, 1.2 * _u, star.withValues(alpha: 0.35 * l.stars))
            ..draw(canvas, 1, 1.5 * _u, star.withValues(alpha: 0.85 * l.stars));
        }
      }
    }
  }

  static final Paint _meshPaint = Paint();

  /// The shafts: light standing in the air from each crack down to the
  /// ledge, soft at its edges, leaning with the sun.
  void _paintShafts(Canvas canvas, FieldView view) {
    final s = _shaftStrength;
    if (s < 0.02) return;
    final col = _shaftColour;
    final y1 = _h * 0.8;
    for (final shift in _shiftsFor(mid, view, 300 * _u)) {
      for (final (cx0, hw) in _cracks) {
        final cx = cx0 + shift;
        final bx = _shaftX(cx, y1);
        // From the crack's mouth, where it opens under the roof.
        final y0 = _roofEdge(cx0) + 4 * _u;
        final tx = _shaftX(cx, y0);
        if (math.max(cx, bx) + hw * 4 < view.left ||
            math.min(cx, bx) - hw * 4 > view.right) {
          continue;
        }
        // Soft edges without a blur: the shaft three times, each narrower
        // and brighter than the last — triangles shaded corner by corner,
        // bright at the mouth, fading to nothing at the ledge.
        final ym = y0 + (y1 - y0) * 0.55;
        final mx = _shaftX(cx, ym);
        for (final (grow, a) in const [
          (1.9, 0.07),
          (1.35, 0.09),
          (0.85, 0.12),
        ]) {
          final top = hw * grow * 0.45, bottom = hw * grow * 2.6;
          final middle = top + (bottom - top) * 0.55;
          final c0 = col.withValues(alpha: (a * s * 1.4).clamp(0.0, 1.0));
          final c1 = col.withValues(alpha: (a * s).clamp(0.0, 1.0));
          final c2 = col.withValues(alpha: 0);
          final p0l = Offset(tx - top, y0), p0r = Offset(tx + top, y0);
          final p1l = Offset(mx - middle, ym), p1r = Offset(mx + middle, ym);
          final p2l = Offset(bx - bottom, y1), p2r = Offset(bx + bottom, y1);
          canvas.drawVertices(
            Vertices(
              VertexMode.triangles,
              [p0l, p0r, p1l, p0r, p1r, p1l, p1l, p1r, p2l, p1r, p2r, p2l],
              colors: [c0, c0, c1, c0, c1, c1, c1, c1, c2, c1, c2, c2],
            ),
            BlendMode.dst,
            _plus,
          );
        }
      }
    }
    _plus.shader = null;
  }

  /// Where the shafts land on the floor: a pool of their light.
  void _paintPools(Canvas canvas, FieldView view) {
    final s = _shaftStrength;
    if (s < 0.02) return;
    final col = _shaftColour;
    final period = _period(mid);
    for (final (cx, hw) in _cracks) {
      final y = _h * 0.86;
      var at = view.left + (_shaftX(cx, y) - _midLeft);
      // The repeat of it nearest the middle of the view.
      if (period > 0) {
        final midX = (view.left + view.right) / 2;
        at += period * ((midX - at) / period).roundToDouble();
      }
      for (final dx in [0.0, if (period > 0) -period, if (period > 0) period]) {
        final x = at + dx;
        if (x + 200 * _u < view.left || x - 200 * _u > view.right) continue;
        final r = hw * 4.4 + 40 * _u;
        final c = Offset(x, y);
        canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 2, height: r * 0.5),
          _plus
            ..shader = Gradient.radial(
              c,
              r,
              [
                col.withValues(alpha: 0.32 * s),
                col.withValues(alpha: 0.1 * s),
                col.withValues(alpha: 0),
              ],
              const [0.0, 0.45, 1.0],
            ),
        );
      }
    }
    _plus.shader = null;
  }

  /// The floor round each cluster lit by its own glow: little by day, a
  /// pool of its colour at night.
  void _paintCrystalLight(Canvas canvas, FieldView view) {
    final k = 0.04 + 0.2 * _dark;
    for (final shift in _shiftsFor(floor, view, 120 * _u)) {
      for (final cl in _floorClusters) {
        final x = cl.x + shift;
        if (x + cl.reach * 2 < view.left || x - cl.reach * 2 > view.right) {
          continue;
        }
        final col = _glowColour[cl.type]!;
        final c = Offset(x, cl.crystals.first.base.dy);
        final r = cl.reach * 1.6;
        canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 2, height: r * 0.55),
          _plus
            ..shader = Gradient.radial(
              c,
              r,
              [
                col.withValues(alpha: k),
                col.withValues(alpha: k * 0.35),
                col.withValues(alpha: 0),
              ],
              const [0.0, 0.5, 1.0],
            ),
        );
      }
    }
    _plus.shader = null;
  }

  // ── Dust in the shafts ───────────────────────────────────────────────────

  /// Each mote's push from a finger, springing back.
  Float32List _dx = Float32List(0), _dy = Float32List(0);
  Float32List _vx = Float32List(0), _vy = Float32List(0);
  double _dustClock = -1, _dustSeen = -1;

  void _stirDust(FieldView view) {
    final m = _dust;
    if (m == null) return;
    if (_dx.length != m.n) {
      _dx = Float32List(m.n);
      _dy = Float32List(m.n);
      _vx = Float32List(m.n);
      _vy = Float32List(m.n);
    }
    final now = view.time;
    final dt = _dustClock < 0 ? 0.0 : (now - _dustClock).clamp(0.0, 1 / 30);
    _dustClock = now;
    final stirs = _stirsFor(mid, view);
    for (final p in stirs) {
      if (p.time <= _dustSeen) continue;
      _dustSeen = math.max(_dustSeen, p.time);
      final tap = p.speed < 0.5;
      _pushDust(p, tap);
      // A touch on a crystal rings it.
      _ring(mid, p);
    }
    if (dt <= 0) return;
    const k = 6.0, damp = 3.2;
    for (var i = 0; i < m.n; i++) {
      if (_dx[i] == 0 && _dy[i] == 0 && _vx[i] == 0 && _vy[i] == 0) continue;
      _vx[i] += (-k * _dx[i] - damp * _vx[i]) * dt;
      _vy[i] += (-k * _dy[i] - damp * _vy[i]) * dt;
      _dx[i] += _vx[i] * dt;
      _dy[i] += _vy[i] * dt;
      if (_dx[i].abs() + _dy[i].abs() < 0.05 &&
          _vx[i].abs() + _vy[i].abs() < 0.05) {
        _dx[i] = _dy[i] = _vx[i] = _vy[i] = 0;
      }
    }
  }

  void _pushDust(_Stir p, bool tap) {
    final m = _dust!;
    final reach = (tap ? 60 : 36) * _u;
    for (var i = 0; i < m.n; i++) {
      final (x, y) = _dustAt(i, _dustClock);
      final dx = _loopDelta(x, p.x, mid), dy = y - p.y;
      final d2 = dx * dx + dy * dy;
      if (d2 > reach * reach) continue;
      final d = math.sqrt(d2) + 1e-3;
      final f = 1 - d / reach;
      if (tap) {
        _vx[i] += dx / d * f * 160 * _u;
        _vy[i] += dy / d * f * 160 * _u;
      } else {
        _vx[i] +=
            (p.dir * math.min(1.0, p.speed / (8 * _u)) * 140 + dx / d * 40) *
            f *
            _u;
        _vy[i] += dy / d * f * 40 * _u;
      }
    }
  }

  /// Where mote [i] drifts at [t], before any push: slowly turning inside
  /// the shaft it belongs to.
  (double, double) _dustAt(int i, double t) {
    final m = _dust!;
    final (cx, hw) = _cracks[i % _cracks.length];
    final span = _h * 0.8 - _roofEdgeY;
    final v = (m.y0[i] / _h * 1.7 + t * m.speed[i] / span * 0.25) % 1.0;
    final y = _roofEdgeY + v * span;
    final across = (m.x0[i] / m.width) * 2 - 1;
    final half = hw * (0.9 + 1.6 * v);
    final x =
        _shaftX(cx, y) +
        across * half +
        math.sin(t * 0.3 + m.phase[i]) * 8 * _u;
    return (x, y);
  }

  final GrainBatch _dustBatch = GrainBatch(3);

  void _paintDust(Canvas canvas, FieldView view) {
    final m = _dust;
    final s = _shaftStrength;
    if (m == null || s < 0.03) return;
    _dustBatch.clear();
    final t = view.time;
    final shifts = _shiftsFor(mid, view, 40 * _u);
    final count = math.min(m.n, 360);
    for (var i = 0; i < count; i++) {
      var (x, y) = _dustAt(i, t);
      x += i < _dx.length ? _dx[i] : 0;
      y += i < _dy.length ? _dy[i] : 0;
      final tw = 0.5 + 0.5 * math.sin(t * (1.1 + m.phase[i] * 0.2) + i);
      final level = (tw * 2.99).floor();
      for (final sh in shifts) {
        final px = x + sh;
        if (px < view.left - 4 || px > view.right + 4) continue;
        _dustBatch.add(level, px, y);
      }
    }
    final col = Color.lerp(_shaftColour, const Color(0xFFFFFFFF), 0.5)!;
    for (var lv = 0; lv < 3; lv++) {
      _dustBatch.draw(
        canvas,
        lv,
        (1.1 + 0.3 * lv) * _u,
        col.withValues(alpha: (0.18 + 0.2 * lv) * s),
      );
    }
  }

  // ── The crystals' own light, and their ringing ───────────────────────────

  /// Rings sent out through the crystals from a finger: (layer, x, y, when).
  final List<(SceneLayer, double, double, double)> _rings = [];

  static const _ringSpeed = 240.0, _ringBand = 40.0, _ringLife = 1.8;

  void _ring(SceneLayer layer, _Stir p) {
    // A drag rings as it goes, not on every sample.
    if (_rings.isNotEmpty) {
      final (l, x, y, t) = _rings.last;
      if (l == layer &&
          p.time - t < 0.18 &&
          (x - p.x).abs() + (y - p.y).abs() < 60 * _u) {
        return;
      }
    }
    _rings.add((layer, p.x, p.y, p.time));
    if (_rings.length > 16) _rings.removeAt(0);
  }

  /// How strongly [layer]'s crystal at [x], [y] is ringing at [t].
  double _ringing(SceneLayer layer, double x, double y, double t) {
    var e = 0.0;
    for (final (l, rx, ry, rt) in _rings) {
      if (l != layer) continue;
      final age = t - rt;
      if (age < 0 || age > _ringLife) continue;
      final dx = _loopDelta(x, rx, layer), dy = y - ry;
      final d = math.sqrt(dx * dx + dy * dy);
      final off = (d - age * _ringSpeed * _u) / (_ringBand * _u);
      e += math.exp(-off * off) * math.exp(-age * 1.6);
    }
    return e.clamp(0.0, 1.5);
  }

  final GrainBatch _glowBatch = GrainBatch(6);

  /// Each crystal's tip glowing in its own colour: faint by day, plain at
  /// night, bright while it rings.
  void _paintGlow(
    Canvas canvas,
    FieldView view,
    SceneLayer layer,
    List<_Cluster> clusters,
  ) {
    if (clusters.isEmpty) return;
    final t = view.time;
    // Fingers on the floor ring the floor's crystals.
    if (layer == floor) {
      for (final p in _stirsFor(floor, view)) {
        if (p.time <= _floorSeen) continue;
        _floorSeen = math.max(_floorSeen, p.time);
        if (_inTarn(p.x, p.y)) {
          _tarnRings.add((p.x, p.y, p.time, p.speed < 0.5 ? 1.0 : 0.6));
          if (_tarnRings.length > 24) _tarnRings.removeAt(0);
        } else if (_groundLine(p.x) - 120 * _u < p.y) {
          _ring(floor, p);
        }
      }
    }
    _rings.removeWhere((r) => t - r.$4 > _ringLife);
    // Each crystal lit from inside in its own colour: nothing at its foot,
    // filling toward its tip — all of them in one mesh. A ringing one fills
    // brighter, and sparkles run up through it.
    final base = 0.16 + 0.5 * _dark + 0.3 * singing;
    final pos = <Offset>[];
    final cols = <Color>[];
    _glowBatch.clear();
    var sparkled = false;
    final types = const [_gAmethyst, _gQuartz, _gIce];
    for (final shift in _shiftsFor(layer, view, 60 * _u)) {
      for (final cl in clusters) {
        final x0 = cl.x + shift;
        if (x0 + cl.reach < view.left || x0 - cl.reach > view.right) continue;
        final col = _glowColour[cl.type]!;
        final ti = types.indexOf(cl.type);
        for (final k in cl.crystals) {
          final tipAt = cl.tipOf(k) + Offset(shift, 0);
          final e = _ringing(layer, tipAt.dx, tipAt.dy, t);
          final pulse = 0.88 + 0.12 * math.sin(t * 0.9 + k.seed);
          final level = (base * pulse + e * 0.9).clamp(0.0, 1.2);
          if (level < 0.06) continue;
          final dir = Offset(math.sin(k.angle), -math.cos(k.angle));
          final side = Offset(-dir.dy, dir.dx);
          final half = k.width / 2 * 0.85;
          final body = k.length * 0.78;
          final b = k.base + Offset(shift, 0);
          Offset at(double s, double l) => b + side * (s * half) + dir * l;
          final foot = col.withValues(alpha: 0);
          final mid = col.withValues(alpha: (0.22 * level).clamp(0.0, 1.0));
          final top = col.withValues(alpha: (0.42 * level).clamp(0.0, 1.0));
          final l0 = at(-1, body * 0.1), r0 = at(1, body * 0.1);
          final l1 = at(-1, body * 0.6), r1 = at(1, body * 0.6);
          final l2 = at(-1, body), r2 = at(1, body);
          final tip = at(0.05, k.length * 0.97);
          pos.addAll([
            l0,
            r0,
            l1,
            r0,
            r1,
            l1,
            l1,
            r1,
            l2,
            r1,
            r2,
            l2,
            l2,
            r2,
            tip,
          ]);
          cols.addAll([
            foot,
            foot,
            mid,
            foot,
            mid,
            mid,
            mid,
            mid,
            top,
            mid,
            top,
            top,
            top,
            top,
            top,
          ]);
          if (e > 0.25) {
            // Sparkles running up through it as the ring passes.
            for (var j = 0; j < 4; j++) {
              final f = ((t * 1.6 + j * 0.25 + k.seed * 0.1) % 1.0);
              final p = at((fieldHash(j, k.seed) - 0.5) * 1.2, body * f);
              _glowBatch.add(ti, p.dx, p.dy);
              sparkled = true;
            }
          }
          // A ringing tip on the floor sheds grains of light.
          if (layer == floor && e > 0.6 && _kicked.rand() < 0.25) {
            _kicked.spawn(
              x: tipAt.dx,
              y: tipAt.dy,
              vx: (_kicked.rand() - 0.5) * 30 * _u,
              vy: -(20 + _kicked.rand() * 40) * _u,
              life: 1.0 + _kicked.rand(),
            );
          }
        }
      }
    }
    if (pos.isNotEmpty) {
      canvas.drawVertices(
        Vertices(VertexMode.triangles, pos, colors: cols),
        BlendMode.dst,
        _plus,
      );
    }
    if (sparkled) {
      for (var i = 0; i < 3; i++) {
        final col = Color.lerp(
          _glowColour[types[i]]!,
          const Color(0xFFFFFFFF),
          0.5,
        )!;
        _glowBatch.draw(canvas, i, 1.6 * _u, col.withValues(alpha: 0.9));
      }
    }
  }

  double _floorSeen = -1;

  /// The grains of light ringing crystals shed, lifting and fading.
  void _paintRings(Canvas canvas, FieldView view) {
    final k = _kicked;
    final dt = (view.time - k.clock).clamp(0.0, 0.1);
    k.clock = view.time;
    _moteBatch.clear();
    var any = false;
    for (var i = 0; i < k.cap; i++) {
      if (k.life[i] <= 0) continue;
      k.age[i] += dt;
      if (k.age[i] >= k.life[i]) {
        k.life[i] = 0;
        continue;
      }
      k.vx[i] *= math.exp(-1.5 * dt);
      k.vy[i] = k.vy[i] * math.exp(-1.0 * dt) - 8 * _u * dt;
      k.x[i] += k.vx[i] * dt;
      k.y[i] += k.vy[i] * dt;
      final f = k.age[i] / k.life[i];
      final level = ((1 - f) * 3.99).floor();
      if (level <= 0) continue;
      _moteBatch.add(level, k.x[i], k.y[i]);
      any = true;
    }
    if (!any) return;
    final col = Color.lerp(
      _glowColour[_gAmethyst]!,
      const Color(0xFFFFFFFF),
      0.5,
    )!;
    for (var lv = 1; lv < 4; lv++) {
      _moteBatch.draw(canvas, lv, 1.6 * _u, col.withValues(alpha: 0.28 * lv));
    }
  }

  // ── Frostfall ────────────────────────────────────────────────────────────

  final GrainBatch _fallBatch = GrainBatch(3);

  /// Ice coming down: fine and slow far off, larger near, brightest where
  /// it falls through a shaft.
  void _paintFall(
    Canvas canvas,
    FieldView view,
    SceneLayer layer,
    double size,
  ) {
    final f = frost;
    if (f < 0.02) return;
    final period = _period(layer);
    final tiles = period > 0 ? math.max(1, (period / (300 * _u)).round()) : 0;
    final s = tiles > 0 ? period / tiles : 300 * _u;
    final t = view.time;
    final top = _roofEdgeY, span = _h - top;
    final n = (90 * f * size).round();
    _fallBatch.clear();
    final k0 = ((view.left - 20 * _u) / s).floor();
    final k1 = ((view.right + 20 * _u) / s).floor();
    final seed = 7300 + layer.index * 17;
    for (var k = k0; k <= k1; k++) {
      final kk = tiles > 0 ? k % tiles : k;
      for (var i = 0; i < n; i++) {
        final h0 = fieldHash(i, seed + kk * 131);
        final h2 = fieldHash(i, seed + kk * 131 + 11);
        final fall =
            (fieldHash(i, seed + kk * 131 + 7) +
                t * (14 + 18 * size) * _u / span * (0.7 + 0.6 * h2)) %
            1.0;
        final y = top + fall * span;
        final x = (k + h0) * s + math.sin(t * (0.6 + h2) + h0 * 40) * 7 * _u;
        _fallBatch.add((h2 * 2.99).floor(), x, y);
      }
    }
    const col = Color(0xFFE6F2FF);
    for (var lv = 0; lv < 3; lv++) {
      _fallBatch.draw(
        canvas,
        lv,
        size * (1.6 + 0.5 * lv) * _u,
        col.withValues(alpha: f * (0.25 + 0.2 * lv)),
      );
    }
  }

  // ── The prism ────────────────────────────────────────────────────────────

  /// The great prism on the ledge, standing where the first crack's shaft
  /// lands when the sun is overhead.
  _Cluster _makePrism() {
    final x = _cracks.first.$1;
    return _Cluster(x, _gQuartz, [
      _Crystal(
        base: Offset(x, _ledge(x) + 5 * _u),
        angle: 0.12,
        length: 70 * _u,
        width: 26 * _u,
        seed: 4242,
      ),
      _Crystal(
        base: Offset(x - 12 * _u, _ledge(x) + 6 * _u),
        angle: -0.5,
        length: 30 * _u,
        width: 11 * _u,
        seed: 4243,
      ),
    ], 60 * _u);
  }

  /// How fully the shaft is on the prism: none until the sun leans it
  /// there, all of it with the sun near overhead.
  double get _prismHit {
    if (_cracks.isEmpty) return 0;
    final x = _cracks.first.$1;
    final tipY = _ledge(x) - 50 * _u;
    final d = (_shaftX(x, tipY) - x) / (36 * _u);
    return _shaftStrength * math.exp(-d * d);
  }

  /// The colours the prism splits the light into.
  static const _spectrum = [
    Color(0xFFFF6B6B),
    Color(0xFFFFB45C),
    Color(0xFFFFE66D),
    Color(0xFF6CDB8E),
    Color(0xFF5CA8FF),
    Color(0xFFB07CFF),
  ];

  final GrainBatch _fleckBatch = GrainBatch(6);

  /// The prism splitting the shaft: a fan of colour thrown sideways across
  /// the cave, brightest where it falls on the far wall, and flecks of each
  /// colour twinkling there. By moonlight it is faint and nearly silver.
  void _paintPrism(Canvas canvas, FieldView view) {
    final hit = _prismHit;
    if (hit < 0.03) return;
    final night = _sunUp < -0.05;
    final x0 = _cracks.first.$1;
    final apex0 = Offset(x0 + 2 * _u, _ledge(x0) - 44 * _u);
    final side = _lean >= 0 ? 1.0 : -1.0;
    final length = 250 * _u;
    final t = view.time;
    _fleckBatch.clear();
    for (final shift in _shiftsFor(mid, view, length)) {
      final apex = apex0 + Offset(shift, 0);
      if (apex.dx + length < view.left || apex.dx - length > view.right) {
        continue;
      }
      for (var i = 0; i < _spectrum.length; i++) {
        var col = _spectrum[i];
        if (night) col = Color.lerp(col, const Color(0xFFDDE6FF), 0.7)!;
        final a0 = side * (1.62 + i * 0.09),
            a1 = side * (1.62 + (i + 1) * 0.09);
        Offset at(double a, double r) =>
            apex + Offset(math.sin(a), math.cos(a) * 0.55) * r;
        final strength = hit * (night ? 0.5 : 1.0);
        final cMid = col.withValues(alpha: (0.3 * strength).clamp(0.0, 1.0));
        final cIn = col.withValues(alpha: (0.1 * strength).clamp(0.0, 1.0));
        final cOut = col.withValues(alpha: 0);
        canvas.drawVertices(
          Vertices(
            VertexMode.triangles,
            [
              apex,
              at(a0, length * 0.72),
              at(a1, length * 0.72),
              at(a0, length * 0.72),
              at(a1, length * 0.72),
              at(a0, length),
              at(a1, length * 0.72),
              at(a1, length),
              at(a0, length),
            ],
            colors: [cIn, cMid, cMid, cMid, cMid, cOut, cMid, cOut, cOut],
          ),
          BlendMode.dst,
          _plus,
        );
        // Where it lands on the wall: a soft smear of the colour.
        final land = at((a0 + a1) / 2, length * 0.84);
        canvas.drawOval(
          Rect.fromCenter(center: land, width: 46 * _u, height: 22 * _u),
          _plus
            ..shader = Gradient.radial(land, 24 * _u, [
              col.withValues(alpha: (0.3 * strength).clamp(0.0, 1.0)),
              col.withValues(alpha: 0),
            ]),
        );
        _plus.shader = null;
        // Flecks of it where it lands.
        for (var j = 0; j < 10; j++) {
          final f = 0.6 + 0.35 * fieldHash(j, 600 + i);
          final across = fieldHash(j, 700 + i);
          final p = at(a0 + (a1 - a0) * across, length * f);
          final tw = math.sin(t * (1.2 + fieldHash(j, 800 + i)) + j * 2.1);
          if (tw < 0.2) continue;
          _fleckBatch.add(i, p.dx, p.dy);
        }
      }
    }
    for (var i = 0; i < _spectrum.length; i++) {
      final col = night
          ? Color.lerp(_spectrum[i], const Color(0xFFDDE6FF), 0.7)!
          : _spectrum[i];
      _fleckBatch.draw(
        canvas,
        i,
        1.6 * _u,
        col.withValues(alpha: (0.8 * hit).clamp(0.0, 1.0)),
      );
    }
  }

  // ── The black pool ───────────────────────────────────────────────────────

  /// The pools on the floor where the wild has them: (x as a share of the
  /// loop, half width at the reference height).
  static const _wildTarns = <(double, double)>[(0.49, 150)];

  List<SpawnPoint> get _tarns => [
    if (_placed)
      ..._piecesOn(floor, {FieldPiece.tarn})
    else
      for (var i = 0; i < _wildTarns.length; i++)
        SpawnPoint(
          id: 'geode_tarn_$i',
          normalizedPos: Offset(_wildTarns[i].$1, 0),
          anchor: floor,
          size: Vector2(_wildTarns[i].$2, 30),
          piece: FieldPiece.tarn,
        ),
  ];

  /// A pool's surface: its middle, and how far it reaches across and back.
  ({double x, double y, double hw, double hh}) _tarnShape(SpawnPoint p) {
    final x = _spawnX(p);
    final hw = p.size.x * _u;
    return (
      x: x,
      y: _groundLine(x) + 0.095 * _h,
      hw: hw,
      hh: math.min(hw * 0.17, 0.07 * _h),
    );
  }

  bool _inTarn(double x, double y) {
    for (final p in _tarns) {
      final s = _tarnShape(p);
      final dx = _loopDelta(x, s.x, floor) / s.hw, dy = (y - s.y) / s.hh;
      if (dx * dx + dy * dy < 1) return true;
    }
    return false;
  }

  List<FieldSheet> _tarnSheets(SpawnPoint p) {
    final s = _tarnShape(p);
    final oval = Rect.fromCenter(
      center: Offset(s.x, s.y),
      width: s.hw * 2,
      height: s.hh * 2,
    );
    final bounds = oval.inflate(8 * _u);
    // What stands round it, given back upside down from its far edge.
    final near = [
      for (final cl in [..._floorClusters])
        if (_loopDelta(cl.x, s.x, floor).abs() < s.hw + cl.reach) cl,
    ];
    return [
      FieldSheet(
        bounds: bounds,
        grade: _gFloor,
        paint: (c) {
          // Its rim of wet stone, soft into the floor, then the black water:
          // the cave's dim light lying along its far edge, dark under the
          // near one.
          c
            ..drawOval(
              oval.inflate(9 * _u),
              Paint()
                ..shader = Gradient.radial(
                  oval.center,
                  s.hw + 9 * _u,
                  [fieldMap(0, 0.1, 0.4), fieldMap(0, 0.06, 0.3, 0)],
                  const [0.85, 1.0],
                ),
            )
            ..drawOval(
              oval,
              Paint()
                ..shader = Gradient.linear(
                  oval.topCenter,
                  oval.bottomCenter,
                  [
                    fieldMap(0.35, 0.18, 0.25),
                    fieldMap(0.1, 0.02, 0.7),
                    fieldMap(0, 0, 0.95),
                  ],
                  const [0.0, 0.35, 1.0],
                ),
            );
        },
      ),
      for (final type in {for (final cl in near) cl.type})
        FieldSheet(
          bounds: bounds,
          grade: type,
          paint: (c) {
            c
              ..save()
              ..clipRRect(RRect.fromRectXY(oval, s.hw, s.hh))
              ..translate(0, oval.top)
              ..scale(1, -0.55)
              ..translate(0, -oval.top);
            for (final cl in near.where((cl) => cl.type == type)) {
              // Each standing at its own height above the far edge.
              final lift = cl.crystals.first.base.dy - oval.top;
              c
                ..save()
                ..translate(0, -lift);
              for (final k in cl.crystals) {
                _crystal(c, null, k, haze: 0.3, dark: true);
              }
              c.restore();
            }
            c.restore();
          },
        ),
      FieldSheet(
        bounds: bounds,
        light: true,
        paint: (c) => _sinking(floor, () {
          // Light along its near lip.
          final sparks = GrainBatch(_sparkAlpha.length);
          for (var i = 0; i < 70; i++) {
            final a = math.pi * (0.1 + 0.8 * i / 70);
            if (fieldHash(i, 51) > 0.6) continue;
            sparks.add(
              (fieldHash(i, 53) * 3.99).floor(),
              s.x + math.cos(a) * s.hw,
              s.y + math.sin(a) * s.hh + 1.5 * _u,
            );
          }
          _drawSparks(c, sparks, 1.3);
        }),
      ),
    ];
  }

  /// Rings sent out across the pools by a finger: (x, y, when, strength).
  final List<(double, double, double, double)> _tarnRings = [];

  final GrainBatch _tarnBatch = GrainBatch(3);

  /// How long between drips into each pool.
  static const _dripEvery = 2.7;

  /// The pools live: the shaft's light lying on the water, drops falling
  /// into it from far overhead, and rings running out across it.
  void _paintTarns(Canvas canvas, FieldView view) {
    final pools = _tarns;
    if (pools.isEmpty) return;
    final t = view.time;
    _tarnRings.removeWhere((r) => t - r.$3 > 2.2);
    _tarnBatch.clear();
    final light = Color.lerp(_shaftColour, const Color(0xFFFFFFFF), 0.4)!;
    final period = _period(floor);
    for (final p in pools) {
      final s0 = _tarnShape(p);
      for (final shift in _shiftsFor(floor, view, s0.hw + 20 * _u)) {
        final s = (x: s0.x + shift, y: s0.y, hw: s0.hw, hh: s0.hh);
        if (s.x + s.hw < view.left || s.x - s.hw > view.right) continue;
        // The shaft's light on the water, if it lands near.
        final shaft = _shaftStrength;
        if (shaft > 0.02) {
          var k = 0.0;
          for (final (cx, _) in _cracks) {
            final at = view.left + (_shaftX(cx, _h * 0.86) - _midLeft);
            var d = s.x - at;
            if (period > 0) d -= period * (d / period).roundToDouble();
            k = math.max(k, math.exp(-math.pow(d / (s.hw * 1.4), 2)));
          }
          for (var i = 0; i < 40 * k; i++) {
            final f = fieldHash(i, 91) * 2 - 1;
            final y = s.y - s.hh * (0.5 + 0.35 * fieldHash(i, 92));
            final flick = math.sin(t * (2 + fieldHash(i, 93) * 2) + i);
            if (flick < 0.3) continue;
            _tarnBatch.add(2, s.x + f * s.hw * 0.6, y);
          }
        }
        // Drops, and the rings they leave.
        final round = (t / _dripEvery).floor();
        for (var n = round - 1; n <= round; n++) {
          final seed = (p.id.hashCode & 0xFFFF) + n * 7;
          final hitAt = n * _dripEvery + fieldHash(n, 97) * 0.6;
          final dx = (fieldHash(seed, 95) - 0.5) * 1.3 * s.hw;
          final dy = (fieldHash(seed, 96) - 0.5) * 1.2 * s.hh;
          final age = t - hitAt;
          if (age < 0 && age > -0.45) {
            // Still falling, the last of its way.
            _tarnBatch.add(1, s.x + dx, s.y + dy + age * 260 * _u);
          } else if (age >= 0 && age < 2.0) {
            _addRing(s, s.x + dx, s.y + dy, age, 0.7);
          }
        }
        for (final (rx, ry, rt, k) in _tarnRings) {
          var x = rx;
          if (period > 0) x += period * ((s.x - x) / period).roundToDouble();
          if ((x - s.x).abs() > s.hw) continue;
          _addRing(s, x, ry, t - rt, k);
        }
      }
    }
    _tarnBatch
      ..draw(canvas, 0, 1.9 * _u, light.withValues(alpha: 0.75))
      ..draw(canvas, 1, 2.0 * _u, light.withValues(alpha: 0.85))
      ..draw(
        canvas,
        2,
        1.7 * _u,
        light.withValues(alpha: 0.8 * _shaftStrength),
      );
    _paintTarnShimmer(canvas, view, pools);
  }

  /// The glow of the crystals round a pool lying on its water: a soft
  /// upright smear of each one's colour, trembling.
  void _paintTarnShimmer(
    Canvas canvas,
    FieldView view,
    List<SpawnPoint> pools,
  ) {
    final base = 0.08 + 0.22 * _dark + 0.2 * singing;
    final t = view.time;
    for (final p in pools) {
      final s0 = _tarnShape(p);
      for (final shift in _shiftsFor(floor, view, s0.hw + 20 * _u)) {
        final sx = s0.x + shift;
        if (sx + s0.hw < view.left || sx - s0.hw > view.right) continue;
        for (final cl in _floorClusters) {
          final d = _loopDelta(cl.x, s0.x, floor);
          if (d.abs() > s0.hw * 1.05) continue;
          final x = sx + d.clamp(-s0.hw * 0.8, s0.hw * 0.8);
          final col = _glowColour[cl.type]!;
          final tremble = 0.85 + 0.15 * math.sin(t * 3.1 + cl.x);
          final c = Offset(x, s0.y - s0.hh * 0.2);
          final r = s0.hh * 1.1;
          canvas.drawOval(
            Rect.fromCenter(center: c, width: r * 0.9, height: r * 1.8),
            _plus
              ..shader = Gradient.radial(c, r, [
                col.withValues(alpha: base * tremble),
                col.withValues(alpha: 0),
              ]),
          );
        }
      }
    }
    _plus.shader = null;
  }

  /// One ring on the water at [age]: grains round a widening ellipse, kept
  /// to the pool, fading as it goes.
  void _addRing(
    ({double x, double y, double hw, double hh}) s,
    double cx,
    double cy,
    double age,
    double k,
  ) {
    final life = 2.0;
    if (age < 0 || age > life) return;
    final r = (4 + age * 34) * _u;
    final fade = (1 - age / life) * k;
    if (fade < 0.1) return;
    final n = (10 + r / (2.2 * _u)).clamp(10, 48).round();
    for (var i = 0; i < n; i++) {
      if (fieldHash(i, (age * 30).floor()) > fade + 0.25) continue;
      final a = i / n * math.pi * 2;
      final x = cx + math.cos(a) * r;
      final y = cy + math.sin(a) * r * 0.28;
      final dx = (x - s.x) / s.hw, dy = (y - s.y) / s.hh;
      if (dx * dx + dy * dy > 0.92) continue;
      _tarnBatch.add(0, x, y);
    }
  }

  // ── Glowworms ────────────────────────────────────────────────────────────

  /// The threads hanging from the roof: (x, how many lights, phase).
  List<(double, int, double)> _worms = const [];

  /// When each thread was last touched, and how hard.
  final Map<int, (double, double)> _wormTouch = {};

  List<(double, int, double)> _makeWorms(double w) {
    final r = FieldRandom(9951);
    final out = <(double, int, double)>[];
    var x = r.range(8, 30) * _u;
    while (x < w) {
      final clear = _cracks.every(
        (cr) => _loopDelta(x, cr.$1, mid).abs() > cr.$2 * 2.6,
      );
      if (clear) out.add((x, 4 + (r.next() * 9).floor(), r.range(0, 6.28)));
      x += r.range(9, 30) * _u;
    }
    return out;
  }

  final GrainBatch _wormBatch = GrainBatch(2);
  double _wormSeen = -1;

  /// After dark, glowworm threads hang from the roof, swaying a little; a
  /// finger sends their lights drifting up off the threads, and they
  /// settle back.
  void _paintWorms(Canvas canvas, FieldView view) {
    final vis = ((_dark - 0.35) / 0.4).clamp(0.0, 1.0) * (1 - 0.6 * frost);
    if (vis < 0.02 || _worms.isEmpty) return;
    final t = view.time;
    for (final p in _stirsFor(mid, view)) {
      if (p.time <= _wormSeen) continue;
      _wormSeen = math.max(_wormSeen, p.time);
      for (var i = 0; i < _worms.length; i++) {
        final d = _loopDelta(_worms[i].$1, p.x, mid).abs();
        if (d < 40 * _u && p.y < _roofEdge(p.x) + 90 * _u) {
          _wormTouch[i] = (p.time, 1 - d / (40 * _u));
        }
      }
    }
    _wormBatch.clear();
    for (final shift in _shiftsFor(mid, view, 20 * _u)) {
      for (var i = 0; i < _worms.length; i++) {
        final (x0, n, phase) = _worms[i];
        final x = x0 + shift;
        if (x < view.left - 10 || x > view.right + 10) continue;
        final top = _roofEdge(x0) + 2 * _u;
        final touch = _wormTouch[i];
        final age = touch == null ? 99.0 : t - touch.$1;
        final lift = touch == null || age > 4
            ? 0.0
            : touch.$2 *
                  math.sin(math.min(age * 2.2, math.pi / 2)) *
                  math.exp(-age * 0.9);
        for (var j = 0; j < n; j++) {
          final f = (j + 1) / n;
          final sway = math.sin(t * 0.5 + phase) * 1.6 * _u * f * f;
          var px = x + sway, py = top + j * 4.2 * _u;
          if (lift > 0) {
            px += (fieldHash(j, i) - 0.5) * 26 * _u * lift;
            py -= (8 + 24 * fieldHash(j + 9, i)) * _u * lift;
          }
          // The thread's beads faint; its last few the bright lights.
          _wormBatch.add(j >= n - 3 ? 1 : 0, px, py);
        }
      }
    }
    const col = Color(0xFF8EF2D8);
    _wormBatch
      ..draw(canvas, 0, 1.0 * _u, col.withValues(alpha: 0.35 * vis))
      ..draw(canvas, 1, 5 * _u, col.withValues(alpha: 0.1 * vis))
      ..draw(canvas, 1, 1.7 * _u, col.withValues(alpha: 0.9 * vis));
  }

  // ── The cave singing ─────────────────────────────────────────────────────

  int _lastSong = -1;

  /// While the cave sings, light rolls out from crystal after crystal on
  /// its own, and the pool answers.
  void _sing(FieldView view) {
    final s = singing;
    if (s < 0.2) return;
    final beat = (view.time / 0.9).floor();
    if (beat == _lastSong) return;
    _lastSong = beat;
    final onFloor = beat.isOdd && _floorClusters.isNotEmpty;
    final list = onFloor ? _floorClusters : _midClusters;
    if (list.isEmpty) return;
    final cl = list[(fieldHash(beat, 5) * list.length).floor() % list.length];
    final k = cl.crystals.last;
    final tip = cl.tipOf(k);
    _rings.add((onFloor ? floor : mid, tip.dx, tip.dy, view.time));
    if (_rings.length > 16) _rings.removeAt(0);
    if (beat % 3 == 0) {
      for (final p in _tarns) {
        final t = _tarnShape(p);
        _tarnRings.add((t.x, t.y, view.time, 0.8));
      }
    }
  }
}

/// One crystal: where it grows from, which way it points (radians from
/// straight up), how long and wide it is.
class _Crystal {
  const _Crystal({
    required this.base,
    required this.angle,
    required this.length,
    required this.width,
    required this.seed,
  });
  final Offset base;
  final double angle, length, width;
  final int seed;

  _Crystal moved(double dx) => _Crystal(
    base: base + Offset(dx, 0),
    angle: angle,
    length: length,
    width: width,
    seed: seed,
  );
}

/// A cluster of crystals growing from one spot, all of one kind.
class _Cluster {
  _Cluster(this.x, this.type, this.crystals, this.reach);

  /// Crystals fanning out of [base] at [x]: up from the ground, or down
  /// from the roof.
  factory _Cluster.make(
    double x,
    double base,
    double size,
    int seed,
    int type, {
    required bool up,
    double spread = 0.75,
  }) {
    final r = FieldRandom(seed * 7 + 3);
    final n = 3 + (r.next() * 4).floor();
    final out = <_Crystal>[];
    for (var i = 0; i < n; i++) {
      final f = n == 1 ? 0.0 : i / (n - 1) - 0.5;
      final main = i == n ~/ 2;
      final len = size * (main ? 1.0 : r.range(0.45, 0.8));
      final angle = f * spread * 1.6 + r.range(-0.12, 0.12);
      out.add(
        _Crystal(
          base: Offset(x + f * size * 0.5, base),
          angle: up ? angle : math.pi - angle,
          length: len,
          width: len * r.range(0.26, 0.36),
          seed: seed * 31 + i,
        ),
      );
    }
    // The tall one last, so it stands in front.
    out.sort((a, b) => a.length.compareTo(b.length));
    return _Cluster(x, type, out, size * 1.4);
  }

  final double x;
  final int type;
  final List<_Crystal> crystals;
  final double reach;

  /// The same cluster standing at [at] instead.
  _Cluster at(double at) => at == x
      ? this
      : _Cluster(at, type, [for (final k in crystals) k.moved(at - x)], reach);

  Offset tipOf(_Crystal k) =>
      k.base +
      Offset(math.sin(k.angle), -math.cos(k.angle)) * (k.length * 0.97);
}

// ── The Hollow's day ───────────────────────────────────────────────────────

/// The cave's own dark: what is left of the day's light inside it.
const _caveDark = Color(0xFF15121F);

/// The Valley's sky (seen through the cracks), and inside, a share of its
/// light.
final List<(double, _Light)> _geodeKeys = [
  for (final (h, l) in _valleyKeys) (h, _caved(l)),
];

_Light _caved(_Light l) => _Light(
  sky: l.sky,
  ambient: Color.lerp(_caveDark, l.ambient, 0.42)!,
  rim: l.rim,
  rimStrength: 1,
  floor: 0,
  glow: l.glow,
  stars: l.stars,
  cloudTop: l.cloudTop,
  cloudBottom: l.cloudBottom,
  cloudGlint: l.cloudGlint,
  grass: l.grass,
  mote: l.mote,
  firefly: 0,
);
