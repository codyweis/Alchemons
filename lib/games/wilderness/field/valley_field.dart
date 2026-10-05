part of 'grain_field.dart';

// The Valley, through the day.
//
// Ridge after ridge steps out of the haze, each a little darker and nearer,
// down to a meadow of grass made of grains. The light follows the phone's
// clock: the sun rises on the left and sets on the right, lighting the
// edges of everything when it is low behind them; at night the moon (in its
// real phase) and the stars take over, and the motes over the grass become
// fireflies. Drag a finger through the meadow and the grass parts and
// springs back, shedding grains that drift off on the wind.
//
// Layers, matching the scene's spawn anchors:
//   sky     — screen-fixed (the camera backdrop): sun, moon, stars
//   layer2  — grain clouds (drifting) and three far ranges
//   layer3  — a forested hill line and the near hill with its trees
//   layer4  — the meadow the creatures stand in, its two great trees
//   layer5  — tall foreground grass, nearest of all
//
// Still sheets are baked as maps (see field_art.dart), read through the
// hour's grades:
//   far grades   r = haze, b = haze × how low (horizon-coloured), g = fleck
//   near grades  r = haze, b = shade, g = fleck
//   clouds       r = underside, g = glitter

class ValleyField extends _GrainField {
  ValleyField();

  static const far = SceneLayer.layer2;
  static const hills = SceneLayer.layer3;
  static const meadow = SceneLayer.layer4;
  static const fore = SceneLayer.layer5;

  static const _gRanges = 0, _gHillFar = 1, _gHill = 2, _gGround = 3;
  static const _gTree = 4, _gCloud = 5, _gRock = 6;

  /// Daylight colours of the land; the hour's ambient light multiplies them.
  static const _albedo = <int, Color>{
    _gRanges: Color(0xFF5E6E8E),
    _gHillFar: Color(0xFF48606C),
    _gHill: Color(0xFF3E5E46),
    _gGround: Color(0xFF50703A),
    _gTree: Color(0xFF2A432E),
    _gRock: Color(0xFF6A6C70),
  };

  @override
  List<(double, _Light)> get _keys => _valleyKeys;

  @override
  double _lightK(SceneLayer layer) => switch (layer) {
    far => 1.0,
    hills => 0.9,
    _ => 0.85,
  };

  @override
  void _buildGrades(_Light l) {
    final hazeHigh = l.skyAt(0.44), hazeLow = l.skyAt(0.585);
    final cover = snow;
    Color sil(int g) {
      var a = _albedo[g]!;
      // Snow lying on it: the far ranges whitest, the trees least.
      if (cover > 0) {
        a = Color.lerp(
          a,
          const Color(0xFFDCE4EC),
          cover * (_snowCover[g] ?? 0),
        )!;
      }
      return Color.from(
        alpha: 1,
        red: a.r * l.ambient.r,
        green: a.g * l.ambient.g,
        blue: a.b * l.ambient.b,
      );
    }

    (double, double, double) fleck(Color s, double k) => (
      s.r * 0.9 + l.rim.r * l.rimStrength * k,
      s.g * 0.9 + l.rim.g * l.rimStrength * k,
      s.b * 0.9 + l.rim.b * l.rimStrength * k,
    );
    for (final g in [_gRanges, _gHillFar]) {
      final s = sil(g);
      _grades[g] = fieldGrade(
        base: s,
        r: fieldDiff(hazeHigh, s),
        g: fleck(s, 0.3),
        b: fieldDiff(hazeLow, hazeHigh),
      );
    }
    for (final g in [_gHill, _gGround, _gTree, _gRock]) {
      final s = sil(g);
      _grades[g] = fieldGrade(
        base: s,
        r: fieldDiff(hazeLow, s),
        g: fleck(s, 0.4),
        b: fieldScale(s, -0.72),
      );
    }
    _grades[_gCloud] = fieldGrade(
      base: l.cloudTop,
      r: fieldDiff(l.cloudBottom, l.cloudTop),
      g: fieldScale(l.cloudGlint, 0.85),
      b: (0, 0, 0),
    );
  }

  /// Ground points on the near hill: the hill rises to meet each.
  Iterable<SpawnPoint> get _hillStands =>
      _spawns.where((p) => !p.aloft && p.anchor == hills);

  /// Ground points on the meadow too high to stand in the grass: each gets
  /// a boulder to stand on.
  Iterable<SpawnPoint> get _perched => _spawns.where(
    (p) =>
        !p.aloft &&
        p.anchor == meadow &&
        _feet(p) < _groundLine(_spawnX(p)) - 6 * _u,
  );

  @override
  double? perchFor(String spawnId) {
    for (final p in _perched) {
      if (p.id == spawnId) return _feet(p);
    }
    return null;
  }

  @override
  ({double top, double rest})? groundAt(SceneLayer layer, double x) =>
      switch (layer) {
        hills => (top: _hill(x) + 3 * _u, rest: _hill(x) + 16 * _u),
        meadow => (
          top: _groundLine(x) + 2 * _u,
          rest: _groundLine(x) + 0.08 * _h,
        ),
        _ => null,
      };

  _Blades? _meadowBlades;
  _Blades? _foreBlades;
  _Motes? _motes;
  double _meadowWidth = 0;
  double _foreWidth = 0;

  // ── Ridges (layer-local, in units of the current height) ────────────────

  double _ridged(double x, double wave, int seed) =>
      1 - fieldLoopNoise(x, wave, seed, _period(far)).abs();

  double _nf(double x, double wave, int seed) =>
      fieldLoopNoise(x, wave, seed, _period(far));
  double _nh(double x, double wave, int seed) =>
      fieldLoopNoise(x, wave, seed, _period(hills));
  double _nm(double x, double wave, int seed) =>
      fieldLoopNoise(x, wave, seed, _period(meadow));

  double _range(int i, double x) => switch (i) {
    0 =>
      _h *
          (0.535 -
              0.11 * math.pow(_ridged(x, 240, 11), 1.6) -
              0.025 * _nf(x, 70, 12) -
              0.006 * _nf(x, 21, 13)),
    1 =>
      _h *
          (0.588 -
              0.06 * math.pow(_ridged(x, 175, 14), 1.4) -
              0.014 * _nf(x, 55, 15) -
              0.004 * _nf(x, 17, 16)),
    _ =>
      _h *
          (0.632 -
              0.035 * (_nf(x, 200, 17) * 0.5 + 0.5) -
              0.01 * _nf(x, 60, 18)),
  };

  double _hillFar(double x) =>
      _h *
      (0.672 - 0.04 * (_nh(x, 210, 31) * 0.5 + 0.5) - 0.01 * _nh(x, 60, 32));

  double _hillBase(double x) =>
      _h *
      (0.716 -
          0.045 * (_nh(x, 230, 33) * 0.5 + 0.5) -
          0.014 * _nh(x, 70, 34) -
          0.004 * _nh(x, 19, 35));

  /// The near hill, lifted wherever a creature stands on it so its crest is
  /// always above their feet — never a creature against open sky.
  double _hill(double x) {
    var y = _hillBase(x);
    for (final p in _hillStands) {
      final sx = _spawnX(p);
      final need = _hillBase(sx) - (_feet(p) - 10 * _u);
      if (need <= 0) continue;
      y -= need * math.exp(-math.pow(_loopDelta(x, sx, hills) / 170, 2));
    }
    return y;
  }

  /// The meadow's grass line under a finger at [x], [y], if it is in it.
  double? _inGrass(double x, double y) {
    final g = _groundLine(x);
    return y < g - 34 * _u || y > _h + 10 ? null : g;
  }

  double _groundLine(double x) =>
      _h * (0.818 + 0.016 * _nm(x, 260, 41) + 0.006 * _nm(x, 75, 42));

  // ── Build ────────────────────────────────────────────────────────────────

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
        final ranges = Rect.fromLTWH(0, _h * 0.38, w, _h * 0.40);
        return [
          FieldSheet(
            bounds: Rect.fromLTWH(0, 0, w, _h * 0.48),
            drift: 3.0 * _u,
            resolution: 0.8,
            grade: _gCloud,
            paint: (c) => _sinking(far, () => _paintClouds(c, w)),
          ),
          FieldSheet(
            bounds: ranges,
            resolution: 0.8,
            grade: _gRanges,
            paint: (c) => _paintRanges(c, w),
          ),
          FieldSheet(
            bounds: ranges,
            resolution: 0.8,
            light: true,
            paint: (c) => _paintRangeLight(c, w),
          ),
        ];
      case hills:
        _glints[hills] = _Glints();
        final bounds = Rect.fromLTWH(0, _h * 0.48, w, _h * 0.40);
        return [
          FieldSheet(
            bounds: bounds,
            grade: _gHillFar,
            paint: (c) => _paintHillFar(c, w),
          ),
          // The far hill's light, under the near hill and its trees.
          FieldSheet(
            bounds: bounds,
            light: true,
            resolution: 0.8,
            paint: (c) => _rimBands(c, w, _hillFar, [(3.6, 0.32), (9.0, 0.14)]),
          ),
          FieldSheet(
            bounds: bounds,
            grade: _gHill,
            paint: (c) => _paintHill(c, w, null),
          ),
          FieldSheet(
            bounds: bounds,
            light: true,
            paint: (c) => _sinking(hills, () => _paintHillLight(c, w)),
          ),
        ];
      case meadow:
        _glints[meadow] = _Glints();
        _meadowWidth = w;
        _meadowBlades = _meadowGrass(w);
        _motes = _Motes.make(w, _h, _u);
        final ground = Rect.fromLTWH(0, _h * 0.66, w, _h * 0.34);
        return [
          FieldSheet(
            bounds: ground,
            grade: _gGround,
            paint: (c) => _paintGround(c, w, null),
          ),
          FieldSheet(
            bounds: ground,
            light: true,
            paint: (c) => _paintGroundLight(c, w),
          ),
          for (final t in _greatTrees(w)) ...[
            FieldSheet(
              bounds: t.bounds,
              grade: _gTree,
              paint: (c) => t.paint(c, null),
            ),
            FieldSheet(
              bounds: t.bounds,
              light: true,
              paint: (c) => _sinking(meadow, () {
                final sparks = GrainBatch(_sparkAlpha.length);
                t.paint(_NullCanvas(), sparks);
                _drawSparks(c, sparks, 1.5);
              }),
            ),
          ],
          for (final p in _boulders) ...[
            FieldSheet(
              bounds: _boulderBounds(p),
              grade: _gRock,
              paint: (c) => _boulder(c, null, p),
            ),
            FieldSheet(
              bounds: _boulderBounds(p),
              light: true,
              paint: (c) => _sinking(meadow, () {
                final sparks = GrainBatch(_sparkAlpha.length);
                _boulder(_NullCanvas(), sparks, p);
                _drawSparks(c, sparks, 1.4);
              }),
            ),
          ],
        ];
      case fore:
        _foreWidth = w;
        _foreBlades = _foreGrass(w);
        return const [];
      default:
        return const [];
    }
  }

  @override
  bool hasLive(SceneLayer layer, {required bool front}) => switch (layer) {
    meadow => true,
    far || hills || fore => !front,
    _ => false,
  };

  // ── Rain, and the rainbow after it ───────────────────────────────────────

  /// The Valley's weathers: rain, and snow.
  double get rain => weatherKind == WeatherKind.rain ? weather : 0;
  double get snow => weatherKind == WeatherKind.snow ? weather : 0;

  @override
  double get _windScale => 1 + 0.45 * rain + 0.15 * snow;

  @override
  double get _veil => 0.8 * rain + 0.6 * snow;

  @override
  double get _moteShare => 1 - 0.8 * rain - 0.85 * snow;

  @override
  double get _weatherKey =>
      (rain * 1000).roundToDouble() + (snow * 1000).roundToDouble() * 1000;

  /// How much of each grade the snow covers, at its deepest.
  static const _snowCover = <int, double>{
    _gRanges: 0.62,
    _gHillFar: 0.5,
    _gHill: 0.5,
    _gGround: 0.42,
    _gTree: 0.18,
    _gRock: 0.45,
  };

  /// In snow every rim the light sheets trace — ridge tops, crowns, tree
  /// tips, the boulder — holds a line of it.
  @override
  Color lightAt(SceneLayer layer, double x, FieldView view) {
    final lit = super.lightAt(layer, x, view);
    final s = snow;
    if (s < 0.01) return lit;
    // Bright where the day is; at night only a pale line the moon finds.
    final day = math.sqrt(_light.ambient.computeLuminance());
    final cap = s * (0.14 + 0.48 * day);
    return Color.from(
      alpha: math.max(lit.a, cap),
      red: lit.r + (0.94 - lit.r) * s,
      green: lit.g + (0.96 - lit.g) * s,
      blue: lit.b + (1.0 - lit.b) * s,
    );
  }

  /// The hour's light under rain: drawn down to a soft overcast grey, the
  /// light everywhere and nowhere, the grass darker for being wet.
  @override
  _Light _weathered(_Light l) {
    if (snow > 0.001) return _snowed(l);
    final r = rain;
    if (r <= 0.001) return l;
    Color grey(Color c, double dark) {
      final g = math.sqrt(c.computeLuminance());
      final to = Color.lerp(
        const Color(0xFF1C2229),
        const Color(0xFFAAB2BA),
        g,
      )!;
      return Color.from(
        alpha: 1,
        red: to.r * dark,
        green: to.g * dark,
        blue: to.b * dark,
      );
    }

    final k = 0.78 * r;
    Color wet(Color c, double dark) => Color.lerp(c, grey(c, dark), k)!;
    return _Light(
      stops: l.stops,
      sky: [for (final c in l.sky) wet(c, 0.92)],
      ambient: wet(l.ambient, 0.66),
      rim: Color.lerp(l.rim, const Color(0xFFD8E0E8), r)!,
      rimStrength: l.rimStrength * (1 - 0.7 * r),
      floor: l.floor + (math.max(0.7, l.floor) - l.floor) * r,
      glow: l.glow * (1 - 0.85 * r),
      stars: l.stars * (1 - 0.9 * r),
      cloudTop: wet(l.cloudTop, 0.62),
      cloudBottom: wet(l.cloudBottom, 0.72),
      cloudGlint: Color.lerp(l.cloudGlint, const Color(0xFF9AA4AE), r)!,
      grass: [
        for (final c in l.grass)
          Color.lerp(
            c,
            Color.from(
              alpha: 1,
              red: c.r * 0.8,
              green: c.g * 0.86,
              blue: c.b * 0.84,
            ),
            k,
          )!,
      ],
      mote: Color.lerp(l.mote, const Color(0xFFDDE6EE), r)!,
      firefly: l.firefly,
    );
  }

  /// The hour's light in snow: a bright cold overcast, the light coming from
  /// everywhere, the grass tips frosted.
  _Light _snowed(_Light l) {
    final s = snow;
    Color cold(Color c, double lift) {
      final g = math.sqrt(c.computeLuminance());
      final to = Color.lerp(
        const Color(0xFF242C38),
        const Color(0xFFDDE5EE),
        math.min(1.0, g * lift),
      )!;
      return Color.lerp(c, to, 0.8 * s)!;
    }

    const frost = Color(0xFFE6EEF6);
    final tips = l.grass.length;
    return _Light(
      stops: l.stops,
      sky: [for (final c in l.sky) cold(c, 1.08)],
      ambient: cold(l.ambient, 1.0),
      rim: Color.lerp(l.rim, const Color(0xFFF4F8FF), s)!,
      rimStrength: l.rimStrength * (1 - 0.4 * s),
      floor: l.floor + (math.max(0.7, l.floor) - l.floor) * s,
      glow: l.glow * (1 - 0.6 * s),
      stars: l.stars * (1 - 0.85 * s),
      cloudTop: cold(l.cloudTop, 1.1),
      cloudBottom: cold(l.cloudBottom, 0.95),
      cloudGlint: Color.lerp(l.cloudGlint, const Color(0xFFDCE6F2), s)!,
      grass: [
        for (var i = 0; i < tips; i++)
          Color.lerp(
            l.grass[i],
            Color.lerp(
              l.grass[i],
              frost,
              math.pow(i / (tips - 1), 2.2) * 0.85,
            )!,
            s,
          )!,
      ],
      mote: Color.lerp(l.mote, const Color(0xFFF4F8FF), s)!,
      firefly: l.firefly * (1 - s),
    );
  }

  /// Snow at three depths, flakes as soft grains swaying as they come down:
  /// fine and slow over the far ranges, larger over the hills, big near
  /// flakes drifting over everything in the meadow.
  static const _farSnow = (
    seed: 2101,
    perTile: 140,
    size: 1.1,
    halo: 0.0,
    alpha: 0.5,
    speed: 16.0,
    sway: 6.0,
    top: 0.0,
    bottom: 0.76,
  );
  static const _hillSnow = (
    seed: 2103,
    perTile: 130,
    size: 1.6,
    halo: 0.0,
    alpha: 0.62,
    speed: 26.0,
    sway: 9.0,
    top: -0.02,
    bottom: 0.88,
  );
  static const _nearSnow = (
    seed: 2105,
    perTile: 64,
    size: 3.0,
    halo: 6.5,
    alpha: 0.8,
    speed: 44.0,
    sway: 14.0,
    top: -0.06,
    bottom: 1.04,
  );

  void _paintSnow(
    Canvas canvas,
    FieldView view,
    SceneLayer layer,
    ({
      int seed,
      int perTile,
      double size,
      double halo,
      double alpha,
      double speed,
      double sway,
      double top,
      double bottom,
    })
    d,
  ) {
    final sn = snow;
    if (sn < 0.02) return;
    final (s, tiles) = _rainTile(layer);
    final t = view.time;
    final (wind, _) = _wind((view.left + view.right) / 2, t, s * 4);
    final top = _h * d.top, span = _h * (d.bottom - d.top);
    final n = (d.perTile * sn).round();
    _rainBatch.clear();
    final k0 = ((view.left - 40 * _u) / s).floor();
    final k1 = ((view.right + 40 * _u) / s).floor();
    for (var k = k0; k <= k1; k++) {
      final kk = tiles > 0 ? k % tiles : k;
      for (var i = 0; i < n; i++) {
        final h0 = fieldHash(i, d.seed + kk * 131);
        final h2 = fieldHash(i, d.seed + kk * 131 + 11);
        final fall =
            (fieldHash(i, d.seed + kk * 131 + 7) +
                t * d.speed * _u / span * (0.7 + 0.6 * h2)) %
            1.0;
        final y = top + fall * span;
        final x =
            (k + h0) * s +
            math.sin(t * (0.6 + h2) + h0 * 40) * d.sway * _u +
            wind * 40 * _u * (fall - 0.5);
        _rainBatch.add((h2 * 2.99).floor(), x, y);
      }
    }
    final col = Color.lerp(_light.skyAt(0.4), const Color(0xFFFFFFFF), 0.75)!;
    for (var lv = 0; lv < 3; lv++) {
      final a = d.alpha * sn * (0.55 + 0.22 * lv);
      if (d.halo > 0) {
        _rainBatch.draw(
          canvas,
          lv,
          d.halo * _u,
          col.withValues(alpha: a * 0.16),
        );
      }
      _rainBatch.draw(
        canvas,
        lv,
        d.size * _u * (0.8 + 0.2 * lv),
        col.withValues(alpha: a),
      );
    }
  }

  /// Rain at three depths: fine and faint over the far ranges, heavier over
  /// the hills, and big near drops over everything in the meadow.
  static const _farRain = (
    seed: 1701,
    perTile: 120,
    length: 6.0,
    size: 0.9,
    alpha: 0.3,
    speed: 230.0,
    top: 0.04,
    bottom: 0.74,
  );
  static const _hillRain = (
    seed: 1703,
    perTile: 80,
    length: 10.0,
    size: 1.15,
    alpha: 0.36,
    speed: 310.0,
    top: 0.0,
    bottom: 0.86,
  );
  static const _nearRain = (
    seed: 1705,
    perTile: 46,
    length: 19.0,
    size: 1.6,
    alpha: 0.42,
    speed: 430.0,
    top: -0.06,
    bottom: 1.04,
  );

  final GrainBatch _rainBatch = GrainBatch(3);

  /// Drop streaks, as segment pairs per brightness.
  final List<Float32List> _streaks = List.generate(3, (_) => Float32List(512));
  final List<int> _streakN = [0, 0, 0];
  static final Paint _streakPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void _streak(int level, double x0, double y0, double x1, double y1) {
    var buf = _streaks[level];
    final i = _streakN[level] * 4;
    if (i + 4 > buf.length) {
      _streaks[level] = buf = Float32List(buf.length * 2)..setAll(0, buf);
    }
    buf
      ..[i] = x0
      ..[i + 1] = y0
      ..[i + 2] = x1
      ..[i + 3] = y1;
    _streakN[level]++;
  }

  /// The width of a stretch of rain on [layer]: a looping layer holds a
  /// whole number of them, so the rain joins round the loop.
  (double, int) _rainTile(SceneLayer layer) {
    final p = _period(layer);
    if (p <= 0) return (320 * _u, 0);
    final n = math.max(1, (p / (320 * _u)).round());
    return (p / n, n);
  }

  /// Falling drops, each a short soft streak slanting with the wind.
  void _paintRain(
    Canvas canvas,
    FieldView view,
    SceneLayer layer,
    ({
      int seed,
      int perTile,
      double length,
      double size,
      double alpha,
      double speed,
      double top,
      double bottom,
    })
    d,
  ) {
    final r = rain;
    if (r < 0.02) return;
    final (s, tiles) = _rainTile(layer);
    final t = view.time;
    final (_, gust) = _wind((view.left + view.right) / 2, t, s * 4);
    final slant = 0.16 + 0.22 * gust;
    final top = _h * d.top, span = _h * (d.bottom - d.top);
    final len = d.length * _u;
    final n = (d.perTile * r).round();
    _streakN.fillRange(0, 3, 0);
    final k0 = ((view.left - 60 * _u) / s).floor();
    final k1 = ((view.right + 60 * _u) / s).floor();
    for (var k = k0; k <= k1; k++) {
      final kk = tiles > 0 ? k % tiles : k;
      for (var i = 0; i < n; i++) {
        final h0 = fieldHash(i, d.seed + kk * 131);
        final fall =
            (fieldHash(i, d.seed + kk * 131 + 7) +
                t * d.speed * _u / span * (0.85 + 0.3 * h0)) %
            1.0;
        final y = top + fall * span;
        final x = (k + h0) * s + slant * (y - top - span * 0.5);
        final level = (fieldHash(i, d.seed + 3) * 2.99).floor();
        final drop = len * (0.7 + 0.6 * h0);
        _streak(level, x, y, x - slant * drop, y - drop);
      }
    }
    final l = _light;
    final col = Color.lerp(l.skyAt(0.4), const Color(0xFFFFFFFF), 0.5)!;
    for (var lv = 0; lv < 3; lv++) {
      final n = _streakN[lv];
      if (n == 0) continue;
      _streakPaint
        ..strokeWidth = d.size * _u
        ..color = col.withValues(alpha: d.alpha * r * (0.5 + 0.25 * lv));
      canvas.drawRawPoints(
        PointMode.lines,
        Float32List.sublistView(_streaks[lv], 0, n * 4),
        _streakPaint,
      );
    }
  }

  /// Rain landing in the meadow: little crowns of spray thrown up out of
  /// the grass and gone.
  void _paintSplashes(Canvas canvas, FieldView view) {
    final r = rain;
    if (r < 0.05) return;
    final (s, tiles) = _rainTile(meadow);
    final t = view.time;
    const cycle = 0.55, life = 0.3;
    final n = (16 * r).round();
    _rainBatch.clear();
    final k0 = ((view.left - 20 * _u) / s).floor();
    final k1 = ((view.right + 20 * _u) / s).floor();
    for (var k = k0; k <= k1; k++) {
      final kk = tiles > 0 ? k % tiles : k;
      for (var i = 0; i < n; i++) {
        final phase = fieldHash(i, 1801 + kk * 37);
        final c = t / cycle + phase;
        final a = (c % 1) * cycle;
        if (a > life) continue;
        final round = c.floor();
        final x = (k + fieldHash(i * 7 + round, 1803 + kk)) * s;
        final g = _groundLine(x);
        final y =
            g +
            4 * _u +
            math.pow(fieldHash(i * 7 + round, 1805), 1.4) * (_h - g - 6 * _u);
        final f = a / life;
        final level = ((1 - f) * 2.99).floor();
        for (var j = 0; j < 5; j++) {
          final side = (j - 2) / 2;
          _rainBatch.add(
            level,
            x + side * 3.4 * _u * f,
            y - math.sin(f * math.pi) * (5 - side.abs() * 2.5) * _u,
          );
        }
      }
    }
    final col = Color.lerp(_light.skyAt(0.4), const Color(0xFFFFFFFF), 0.5)!;
    for (var lv = 0; lv < 3; lv++) {
      _rainBatch.draw(
        canvas,
        lv,
        1.3 * _u,
        col.withValues(alpha: 0.4 * r * (0.4 + 0.3 * lv)),
      );
    }
  }

  /// Grains strung along the rainbow: where on the arc (0 one foot, 1 the
  /// other), where across its band (0 inside, 1 out), and each one's beat.
  late final List<(double, double, double)> _bowGrains = [
    for (var i = 0; i < 160; i++)
      (fieldHash(i, 1901), fieldHash(i, 1903), fieldHash(i, 1905)),
  ];
  final GrainBatch _bowBatch = GrainBatch(6);

  /// The bow's colours, inside to out.
  static const _bowColors = [
    Color(0xFF8E6CF0),
    Color(0xFF5A8CF0),
    Color(0xFF6CD08A),
    Color(0xFFF2E27A),
    Color(0xFFF4A65C),
    Color(0xFFEC6A5E),
  ];

  @override
  void paintSky(Canvas canvas, Size screen, FieldView view) {
    super.paintSky(canvas, screen, view);
    _paintRainbow(canvas, screen, view);
  }

  /// After the rain: a bow in the sky opposite the sun — soft bands of
  /// colour, a fainter second bow outside it with its colours turned
  /// round, and grains of each colour drifting slowly along it. By night
  /// it is a moonbow, nearly white.
  void _paintRainbow(Canvas canvas, Size screen, FieldView view) {
    final a = aftermath * (1 - rain);
    if (a < 0.01) return;
    // Opposite the sun by day, the moon by night; the higher it is, the
    // lower the bow stands.
    final bySun = _sunUp > -0.15;
    final srcX = bySun ? _sunX : _moonX;
    final up = (bySun ? _sunUp : _moonUp).clamp(0.0, 1.0);
    final moonbow = !bySun;
    final horizon = view.screenY(view.height * _horizon);
    // A bow stands with the sun behind the one looking at it; a picture
    // seen from the side has no behind. So it stands on the far side of
    // the sun (or moon), whole on the screen, and sinks low enough that
    // the sun is never inside its arc — a low wide bow when the sun is
    // high.
    final rad = screen.height * 0.54 * view.zoom;
    final away = (srcX < 0.5 ? srcX + 0.52 : srcX - 0.52).clamp(0.36, 0.64);
    final cx = screen.width * away;
    var cy = horizon + math.min(up, 0.6) * screen.height * 0.3;
    final sun = Offset(
      screen.width * srcX,
      view.screenY(view.height * (_horizon - up * 0.49)),
    );
    final clear = rad * 1.42;
    final dx = cx - sun.dx;
    if (dx.abs() < clear) {
      cy = math.max(cy, sun.dy + math.sqrt(clear * clear - dx * dx));
    }
    final c = Offset(cx, cy);
    final vis =
        a *
        (moonbow ? 0.45 : 1) *
        (0.55 + 0.45 * _light.ambient.computeLuminance());
    List<Color> tint(double k) => [
      for (final col in _bowColors)
        (moonbow ? Color.lerp(col, const Color(0xFFE6ECF6), 0.8)! : col)
            .withValues(alpha: k * vis),
    ];
    void bow(double inner, double outer, List<Color> cols, double glow) {
      final band = <Color>[
        const Color(0x00FFFFFF).withValues(alpha: 0),
        ...cols,
        const Color(0x00FFFFFF).withValues(alpha: 0),
      ];
      final stops = <double>[
        inner / outer,
        for (var i = 0; i < cols.length; i++)
          (inner + (outer - inner) * (i + 0.5) / cols.length) / outer,
        1.0,
      ];
      canvas.drawCircle(
        c,
        outer,
        Paint()
          ..shader = Gradient.radial(
            c,
            outer,
            [
              const Color(0xFFFFFFFF).withValues(alpha: glow * vis),
              const Color(0xFFFFFFFF).withValues(alpha: glow * vis * 0.6),
              ...band,
            ],
            [0.0, inner / outer * 0.98, ...stops],
          ),
      );
    }

    bow(rad * 0.93, rad * 1.07, tint(0.34), 0.05);
    bow(rad * 1.2, rad * 1.32, tint(0.12).reversed.toList(), 0);

    // Grains along it, drifting round and twinkling.
    _bowBatch.clear();
    final t = view.time;
    for (final (along, across, beat) in _bowGrains) {
      final f = (along + t * 0.006) % 1;
      final ang = math.pi * (1.04 - 1.08 * f);
      final rr = rad * (0.93 + 0.14 * across);
      final p = c + Offset(math.cos(ang), -math.sin(ang)) * rr;
      if (p.dy > horizon + 6 * _u) continue;
      final tw = 0.5 + 0.5 * math.sin(t * (1 + beat * 1.6) + beat * 9);
      if (tw < 0.35) continue;
      _bowBatch.add((across * 5.99).floor(), p.dx, p.dy);
    }
    final grains = tint(0.7);
    for (var i = 0; i < 6; i++) {
      _bowBatch.draw(canvas, i, 1.6 * _u * view.zoom, grains[i]);
    }
  }

  // ── Far layer ────────────────────────────────────────────────────────────

  void _paintClouds(Canvas c, double w) {
    final r = FieldRandom(101);
    final grains = GrainBatch(4);
    final banks = math.max(3, (w / (300 * _u)).round());
    for (var b = 0; b < banks; b++) {
      final cx = (b + r.range(0.15, 0.85)) * w / banks;
      final cy = _h * r.range(0.13, 0.40);
      final low = ((cy / _h - 0.13) / 0.27).clamp(0.0, 1.0);
      final width = r.range(110, 240) * _u * (0.8 + 0.7 * low);
      final height = width * r.range(0.11, 0.18) * (1 - 0.4 * low);
      // Seamless wrap: a cloud over an edge is drawn on the other side too.
      for (final dx in [-w, 0.0, w]) {
        _cloud(c, grains, cx + dx, cy, width, height, low, 1000 + b, w);
      }
    }
    for (var i = 0; i < 4; i++) {
      grains.draw(c, i, 1.25 * _u, fieldMap(1, 0.4 + i * 0.2, 0, 0.9));
    }
  }

  static const _rangeHaze = [(0.66, 0.95), (0.5, 0.9), (0.36, 0.84)];

  void _paintRanges(Canvas c, double w) {
    for (var i = 0; i < 3; i++) {
      double ridge(double x) => _range(i, x);
      final crest = _h * (0.42 + i * 0.07);
      final (rc, rf) = _rangeHaze[i];
      final lowC = ((crest / _h - 0.40) / 0.2).clamp(0.0, 1.0);
      _fillRidge(
        c,
        w,
        ridge,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, crest),
            Offset(0, _h * (0.6 + i * 0.05)),
            [fieldMap(rc, 0, rc * lowC), fieldMap(rf, 0, rf)],
          ),
        bottom: _h * 0.8,
        step: 3 * _u,
      );
      _mistBand(c, w, _h * (0.53 + i * 0.045), _h * (0.61 + i * 0.045), 0.32);
    }
  }

  void _paintRangeLight(Canvas c, double w) {
    for (var i = 0; i < 3; i++) {
      _rimBands(c, w, (x) => _range(i, x), [
        (1.3, 0.55 + 0.1 * i),
        (3.6, 0.3),
        (9.0, 0.13),
      ]);
    }
  }

  // ── Hills ────────────────────────────────────────────────────────────────

  void _paintHillFar(Canvas c, double w) {
    final r = FieldRandom(303);
    final forest = Paint()..color = fieldMap(0.42, 0, 0.42 * 0.55);
    var x = r.range(0, 40) * _u;
    var i = 0;
    while (x < w) {
      final h =
          r.range(9, 22) * _u * (0.7 + 0.6 * (_nh(x, 90, 37) * 0.5 + 0.5));
      final seed = 3300 + i++;
      _wrapped(x, h, w, (at) {
        _conifer(c, null, forest, at, _hillFar(at) + 2 * _u, h, seed);
      });
      x += r.range(4, 13) * _u * (_nh(x, 140, 38) > 0.2 ? 6 : 1);
    }
    _fillRidge(
      c,
      w,
      _hillFar,
      Paint()
        ..shader = Gradient.linear(Offset(0, _h * 0.62), Offset(0, _h * 0.74), [
          fieldMap(0.4, 0, 0.4 * 0.55),
          fieldMap(0.8, 0, 0.8),
        ]),
      bottom: _h * 0.86,
      step: 3 * _u,
    );
    _mistBand(c, w, _h * 0.655, _h * 0.745, 0.34);
  }

  /// The near hill and its trees. With [sparks], paints only where light
  /// catches (for the light sheet); without, the body maps.
  void _paintHill(Canvas c, double w, GrainBatch? sparks) {
    final r = FieldRandom(304);
    final body = Paint()..color = fieldMap(0.04, 0, 0.35);
    var x = r.range(20, 60) * _u;
    var i = 0;
    while (x < w) {
      final cluster = 1 + (r.next() * 4).floor();
      for (var k = 0; k < cluster; k++) {
        final at = x + k * r.range(10, 20) * _u;
        final spruce = r.next() < 0.7;
        final size = spruce ? r.range(26, 64) * _u : r.range(16, 26) * _u;
        final seed = 3400 + i++;
        _wrapped(at, size, w, (tx) {
          _hillTree(c, sparks, body, tx, spruce, size, seed);
        });
      }
      x += r.range(80, 220) * _u;
    }
    if (sparks != null) return;
    _fillRidge(
      c,
      w,
      _hill,
      Paint()
        ..shader = Gradient.linear(Offset(0, _h * 0.66), Offset(0, _h * 0.84), [
          fieldMap(0.04, 0, 0),
          fieldMap(0.2, 0, 0.12),
        ]),
      bottom: _h * 0.88,
      step: 2.5 * _u,
    );
    _tufts(c, w, _hill, count: (w * 1.4).round(), seed: 3);
  }

  /// One tree on the near hill, from its own [seed] — so a tree drawn
  /// twice across a loop's seam is the same tree both times.
  void _hillTree(
    Canvas c,
    GrainBatch? sparks,
    Paint body,
    double tx,
    bool spruce,
    double size,
    int seed,
  ) {
    final base = _hill(tx) + 4 * _u;
    if (spruce) {
      _conifer(c, sparks, body, tx, base, size, seed);
      return;
    }
    final rad = size;
    final trunk = rad * FieldRandom(seed).range(0.8, 1.2);
    c.drawRect(
      Rect.fromLTRB(
        tx - rad * 0.08,
        base - trunk - rad * 0.3,
        tx + rad * 0.08,
        base + 4 * _u,
      ),
      body,
    );
    _leafCrown(
      c,
      sparks,
      [
        (Offset(tx, base - trunk - rad * 0.55), rad * 1.1, rad * 0.8),
        (
          Offset(tx + rad * 0.3, base - trunk - rad * 0.9),
          rad * 0.7,
          rad * 0.55,
        ),
      ],
      leaf: 2.8,
      seed: seed,
      haze: 0.04,
      shade: 0.35,
    );
  }

  void _paintHillLight(Canvas c, double w) {
    _rimBands(c, w, _hill, [(3.6, 0.36), (9.0, 0.15)]);
    final sparks = GrainBatch(_sparkAlpha.length);
    _paintHill(_NullCanvas(), w, sparks);
    _rimSparkle(sparks, w, _hill, seed: 3);
    _drawSparks(c, sparks, 1.35);
  }

  // ── Meadow ───────────────────────────────────────────────────────────────

  void _paintGround(Canvas c, double w, GrainBatch? sparks) {
    if (sparks == null) {
      // Warm air over the grass, lighting the foot of the hills.
      c.drawRect(
        Rect.fromLTWH(0, _h * 0.69, w, _h * 0.15),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, _h * 0.69),
            Offset(0, _h * 0.835),
            [fieldMap(1, 0, 0, 0), fieldMap(1, 0, 0, 0.3)],
          ),
      );
      _fillRidge(
        c,
        w,
        _groundLine,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, _h * 0.80),
            Offset(0, _h),
            [fieldMap(0, 0.12, 0), fieldMap(0, 0, 0.35), fieldMap(0, 0, 0.8)],
            const [0.0, 0.28, 1.0],
          ),
        bottom: _h,
        step: 2.5 * _u,
      );
      final flecks = GrainBatch(3);
      final r = FieldRandom(4 * 7919);
      final depth = 34 * _u;
      for (var i = 0; i < (w * 1.8).round(); i++) {
        final x = r.next() * w;
        final d = -math.log(1 - r.next() * 0.995) * depth;
        final near = math.exp(-d / depth);
        flecks.add(
          (near * 3 - r.next() * 0.8).floor().clamp(0, 2),
          x,
          _groundLine(x) + 2.5 * _u + d,
        );
      }
      for (var t = 0; t < 3; t++) {
        flecks.draw(
          c,
          t,
          1.3 * _u,
          fieldMap(0, 0.15 + t * 0.15, 0.3 - t * 0.1, 0.75),
        );
      }
    }

    // Low bushes along the meadow's edge.
    final r = FieldRandom(404);
    var x = r.range(150, 300) * _u;
    var i = 0;
    while (x < w) {
      final rad = r.range(11, 19) * _u;
      final seed = 4400 + i++;
      _wrapped(x, rad * 2.4, w, (bx) {
        final g = _groundLine(bx);
        _leafCrown(
          c,
          sparks,
          [
            (Offset(bx, g - rad * 0.25), rad * 1.5, rad * 0.65),
            (Offset(bx + rad * 0.5, g - rad * 0.55), rad * 0.8, rad * 0.5),
          ],
          leaf: 2.6,
          seed: seed,
          haze: 0,
          shade: 0.4,
        );
      });
      x += r.range(200, 480) * _u;
    }
  }

  void _paintGroundLight(Canvas c, double w) {
    final sparks = GrainBatch(_sparkAlpha.length);
    _paintGround(_NullCanvas(), w, sparks);
    _drawSparks(c, sparks, 1.4);
  }

  /// The meadow's great trees: (x, scale, seed).
  static const _trees = [(96.0, 1.0, 1), (1180.0, 0.82, 2), (1960.0, 0.92, 3)];

  /// The great trees as the home biome first has them: (x as a share of
  /// the meadow's loop of [period] units, scale).
  static List<(double, double)> homeTrees(double period) => [
    for (final (x, s, _) in _trees) (x / period, s),
  ];

  /// The meadow's great trees, each its own small sheets — where the
  /// player put them, in a field laid out by hand.
  List<({Rect bounds, void Function(Canvas, GrainBatch?) paint})> _greatTrees(
    double w,
  ) => [
    for (final (x, s, seed) in _placed
        ? [
            for (final p in _piecesOn(meadow, {FieldPiece.tree}))
              (_spawnX(p), p.size.x / 100, fieldSeedOf(p.id)),
          ]
        : _trees)
      if (x < w)
        (
          bounds: Rect.fromLTRB(
            x - 170 * s * _u,
            0,
            x + 190 * s * _u,
            _h * 0.9,
          ),
          paint: (Canvas c, GrainBatch? sparks) =>
              _greatTree(c, sparks, x, s * _u, seed),
        ),
  ];

  void _greatTree(Canvas c, GrainBatch? sparks, double x, double s, int seed) {
    final r = FieldRandom(500 + seed);
    final ground = _groundLine(x) + 6 * s;
    final body = Paint()..color = fieldMap(0, 0, 0.3);
    final lean = 16 * s;
    final topY = ground - 165 * s;

    // Trunk: tapered, a little lean, flaring into roots.
    c.drawPath(
      Path()
        ..moveTo(x - 14 * s, ground)
        ..quadraticBezierTo(x - 8 * s, ground - 90 * s, x + lean - 5 * s, topY)
        ..lineTo(x + lean + 5 * s, topY)
        ..quadraticBezierTo(x + 11 * s, ground - 80 * s, x + 16 * s, ground)
        ..close(),
      body,
    );
    for (final dir in [-1.0, 1.0]) {
      c.drawPath(
        Path()
          ..moveTo(x + dir * 8 * s, ground - 18 * s)
          ..quadraticBezierTo(
            x + dir * 17 * s,
            ground - 3 * s,
            x + dir * 34 * s,
            ground + 3 * s,
          )
          ..lineTo(x + dir * 5 * s, ground + 3 * s)
          ..close(),
        body,
      );
    }

    // Limbs reaching up and out, each ending in a mass of leaves.
    final envelope = <(Offset, double, double)>[];
    for (final a in [-2.55, -2.1, -1.6, -1.15, -0.7, -0.35]) {
      final from = Offset(x + lean * 0.75, ground - r.range(115, 160) * s);
      final len = r.range(60, 105) * s;
      final to = from + Offset(math.cos(a), math.sin(a) * 0.8) * len;
      final nrm = Offset(-math.sin(a), math.cos(a));
      final mid = (from + to) / 2 + Offset(0, -10 * s);
      c.drawPath(
        Path()
          ..moveTo(from.dx + nrm.dx * 5.5 * s, from.dy + nrm.dy * 5.5 * s)
          ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy)
          ..quadraticBezierTo(
            mid.dx,
            mid.dy + 4 * s,
            from.dx - nrm.dx * 5.5 * s,
            from.dy - nrm.dy * 5.5 * s,
          )
          ..close(),
        body,
      );
      envelope.add((to, r.range(38, 54) * s, r.range(24, 34) * s));
    }
    envelope
      ..add((Offset(x + lean, topY - 46 * s), 62 * s, 40 * s))
      ..add((Offset(x + lean - 30 * s, topY - 20 * s), 46 * s, 28 * s));
    _leafCrown(
      c,
      sparks,
      envelope,
      leaf: 4.0 * s / _u,
      seed: seed * 977,
      haze: 0,
      shade: 0.3,
    );

    // Light caught along both edges of the trunk.
    if (sparks != null) {
      for (var i = 0; i < 60; i++) {
        final f = i / 60;
        if (fieldHash(i, seed) < 0.5) continue;
        final side = fieldHash(i + 3, seed) < 0.5 ? -1.0 : 1.0;
        final half = (14 - 9 * f) * s;
        sparks.add(
          fieldHash(i + 9, seed) < 0.6 ? 0 : 1,
          x + lean * f * f + side * (half - 1.4 * s),
          ground - f * 150 * s,
        );
      }
    }
  }

  _Blades _meadowGrass(double w) {
    final b = _BladeBuilder();
    final r = FieldRandom(606);
    // The fringe: the meadow's far edge, standing against the light.
    var x = _loop ? 0.0 : -10.0;
    while (x < (_loop ? w : w + 10)) {
      final tall = 0.7 + 0.6 * (_nm(x, 46, 61) * 0.5 + 0.5);
      final jitter = r.range(-0.6, 0.6) * 2.1 * _u;
      b.add(
        x: _loop ? (x + jitter) % w : x + jitter,
        base: _groundLine(x) + 1.5 * _u,
        height: r.range(7, 16) * tall * _u,
        lean: r.range(-0.12, 0.28),
        phase: r.range(0, math.pi * 2),
        depth: 0,
        row: 0,
      );
      x += 2.1 * _u;
    }
    // Below it, blades all the way down the meadow, thinning and darkening
    // as they come nearer. Those rooted below a standing creature's feet
    // are drawn over it (row 4), and kept short so they hide only its feet.
    final feet = 44 * _u;
    final n = (w / (1.1 * _u)).round();
    for (var i = 0; i < n; i++) {
      final x = r.next() * w;
      final g = _groundLine(x);
      final depth = math.pow(r.next(), 1.35).toDouble();
      final below = 5 * _u + depth * (_h - g - 7 * _u);
      final tall = 0.7 + 0.6 * (_nm(x + 120, 40, 62) * 0.5 + 0.5);
      final front = below > feet;
      b.add(
        x: x,
        base: g + below,
        height:
            (front ? r.range(6, 12) : r.range(8, 16) * (1 + depth * 0.5)) *
            tall *
            _u,
        lean: r.range(-0.12, 0.28),
        phase: r.range(0, math.pi * 2),
        depth: depth,
        row: front ? 4 : (depth < 0.12 ? 1 : (depth < 0.3 ? 2 : 3)),
      );
    }
    return b.done();
  }

  _Blades _foreGrass(double w) {
    final b = _BladeBuilder();
    final r = FieldRandom(707);
    var cx = r.range(120, 320) * _u;
    while (cx < w) {
      final n = 9 + (r.next() * 9).floor();
      final reach = r.range(34, 70) * _u;
      for (var i = 0; i < n; i++) {
        final off = r.range(-18, 18) * _u;
        b.add(
          x: _loop ? (cx + off) % w : cx + off,
          base: _h + 4 * _u,
          height: reach * r.range(0.5, 1.0),
          lean: off / (18 * _u) * 0.34 + r.range(-0.08, 0.08),
          phase: r.range(0, math.pi * 2),
          depth: 1,
          row: 0,
        );
      }
      cx += r.range(260, 640) * _u;
    }
    return b.done();
  }

  // ── Live ─────────────────────────────────────────────────────────────────

  @override
  void paintLive(
    SceneLayer layer,
    Canvas canvas,
    FieldView view, {
    required bool front,
  }) {
    final pushes = _pushes(view);
    switch (layer) {
      case far:
        final off = (view.time * 3.0 * _u) % _cloudWidth;
        _paintGlints(
          canvas,
          view,
          far,
          _glints[far],
          shift: off,
          wrap: _cloudWidth,
        );
        _paintRain(canvas, view, far, _farRain);
        _paintSnow(canvas, view, far, _farSnow);
      case hills:
        _paintGlints(canvas, view, hills, _glints[hills]);
        _paintRain(canvas, view, hills, _hillRain);
        _paintSnow(canvas, view, hills, _hillSnow);
      case meadow:
        if (!front) {
          _paintGlints(canvas, view, meadow, _glints[meadow], size: 1.25);
          _paintMotes(canvas, view, _motes, meadow);
          _kickUp(view, pushes, meadow, _meadowWidth, _inGrass);
        }
        final blades = _meadowBlades;
        if (blades != null) {
          if (!front) {
            _stirBlades(
              blades,
              meadow,
              _meadowWidth,
              view,
              reach: 44 * _u,
              maxBend: 1.15,
              shed: true,
            );
          }
          _paintBlades(
            canvas,
            view,
            blades,
            _meadowWidth,
            rows: front ? (4, 4) : (0, 3),
            fore: false,
            layer: meadow,
          );
        }
        if (!front) _paintSplashes(canvas, view);
        if (front) {
          _paintKicked(canvas, view);
          _paintRain(canvas, view, meadow, _nearRain);
          _paintSnow(canvas, view, meadow, _nearSnow);
        }
      case fore:
        final blades = _foreBlades;
        if (blades != null) {
          _stirBlades(
            blades,
            fore,
            _foreWidth,
            view,
            reach: 52 * _u,
            maxBend: 0.9,
          );
          _paintBlades(
            canvas,
            view,
            blades,
            _foreWidth,
            rows: (0, 0),
            fore: true,
            layer: fore,
          );
        }
      default:
        break;
    }
  }

  // ── The boulder ──────────────────────────────────────────────────────────

  /// The boulders on the meadow: one under each high point, and those the
  /// player put in the grass.
  List<SpawnPoint> get _boulders => [
    ..._perched,
    ..._piecesOn(meadow, {FieldPiece.boulder}),
  ];

  /// A weathered boulder under a high meadow point, its flat top at the
  /// standing creature's feet — or one placed in the grass, as tall and
  /// wide as its piece says.
  ({double x, double top, double base, double w}) _boulderShape(SpawnPoint p) {
    final x = _spawnX(p);
    final base = _groundLine(x) + 0.035 * _h;
    if (p.piece == FieldPiece.boulder) {
      return (x: x, top: base - p.size.y * _u, base: base, w: p.size.x * _u);
    }
    final top = _feet(p);
    final w = math.max(p.size.x * 1.35, (base - top) * 1.05);
    return (x: x, top: top, base: base, w: w);
  }

  Rect _boulderBounds(SpawnPoint p) {
    final b = _boulderShape(p);
    return Rect.fromLTRB(
      b.x - b.w * 0.7,
      b.top - 12 * _u,
      b.x + b.w * 0.95,
      b.base + 4 * _u,
    );
  }

  /// Flat-shaded facets: a lit top, a front in half shade, the flanks in
  /// shadow, and a smaller stone leaning at its foot. With [sparks], only
  /// the grains of light along its top edge.
  void _boulder(Canvas c, GrainBatch? sparks, SpawnPoint p) {
    final b = _boulderShape(p);
    final h = b.base - b.top;
    final w = b.w;
    Offset at(double fx, double fy) => Offset(b.x + fx * w, b.top + fy * h);
    Path poly(List<Offset> pts) => Path()..addPolygon(pts, true);

    final topL = at(-0.27, 0.05), topM = at(0.04, 0.0), topR = at(0.31, 0.04);
    final topBackL = at(-0.16, 0.19), topBackR = at(0.21, 0.17);
    final faces = <(List<Offset>, double, double)>[
      // left flank
      (
        [
          at(-0.5, 1),
          at(-0.53, 0.62),
          at(-0.43, 0.3),
          topL,
          topBackL,
          at(-0.22, 0.66),
          at(-0.3, 1),
        ],
        0.5,
        0,
      ),
      // front
      (
        [
          topBackL,
          topBackR,
          at(0.27, 0.6),
          at(0.18, 1),
          at(-0.3, 1),
          at(-0.22, 0.66),
        ],
        0.26,
        0,
      ),
      // right flank
      (
        [
          topBackR,
          topR,
          at(0.45, 0.36),
          at(0.51, 0.74),
          at(0.47, 1),
          at(0.18, 1),
          at(0.27, 0.6),
        ],
        0.58,
        0,
      ),
      // the flat top, lit
      ([topL, topM, topR, topBackR, topBackL], 0.04, 0.3),
      // a leaning stone at its foot
      (
        [at(0.38, 1), at(0.4, 0.74), at(0.58, 0.64), at(0.78, 0.8), at(0.8, 1)],
        0.42,
        0,
      ),
      (
        [at(0.4, 0.74), at(0.58, 0.64), at(0.66, 0.7), at(0.5, 0.79)],
        0.12,
        0.25,
      ),
    ];
    if (sparks == null) {
      for (final (pts, shade, lit) in faces) {
        c.drawPath(poly(pts), Paint()..color = fieldMap(0.03, lit, shade));
      }
      // Weathering: darker pits and lighter lichen, as grains, kept to
      // the stone.
      final outline = Path();
      for (final (pts, _, _) in faces) {
        outline.addPolygon(pts, true);
      }
      c
        ..save()
        ..clipPath(outline);
      final pits = GrainBatch(2);
      for (var i = 0; i < (w * h / (14 * _u * _u)).round(); i++) {
        final fx = fieldHash(i, 31) - 0.5, fy = fieldHash(i, 37);
        pits.add(
          fieldHash(i, 41) < 0.6 ? 0 : 1,
          b.x + fx * w * 0.9,
          b.top + h * (0.08 + fy * 0.9),
        );
      }
      pits.draw(c, 0, 1.6 * _u, fieldMap(0.03, 0, 0.75));
      pits.draw(c, 1, 1.4 * _u, fieldMap(0.03, 0.35, 0.2));
      c.restore();
      return;
    }
    // Light along the top edge and the leaning stone's ridge.
    for (final (a, z) in [
      (topL, topM),
      (topM, topR),
      (at(0.4, 0.74), at(0.58, 0.64)),
    ]) {
      final n = ((z - a).distance / (1.6 * _u)).ceil();
      for (var i = 0; i <= n; i++) {
        final roll = fieldHash(i, a.dx.round());
        if (roll > 0.7) continue;
        final q = Offset.lerp(a, z, i / n)!;
        sparks.add((roll * 5).floor().clamp(0, 3), q.dx, q.dy + 0.6 * _u);
        if (roll < 0.06) _glint(q.dx, q.dy + 0.6 * _u);
      }
    }
  }
}

// ── The Valley's day ──────────────────────────────────────────────────────

const _valleyNight = _Light(
  sky: [
    Color(0xFF03060F),
    Color(0xFF060B1A),
    Color(0xFF0B1328),
    Color(0xFF111B36),
    Color(0xFF172341),
    Color(0xFF1B2948),
    Color(0xFF1F2E4E),
    Color(0xFF223252),
    Color(0xFF223252),
  ],
  ambient: Color(0xFF21263D),
  rim: Color(0xFF9FB4E0),
  rimStrength: 0.2,
  floor: 0.35,
  glow: 0,
  stars: 1,
  cloudTop: Color(0xFF0C1222),
  cloudBottom: Color(0xFF1C2640),
  cloudGlint: Color(0xFF7E92BE),
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
  mote: Color(0xFFD2F57E),
  firefly: 1,
);

const _valleyPreDawn = _Light(
  sky: [
    Color(0xFF04081A),
    Color(0xFF08102A),
    Color(0xFF0F1A3A),
    Color(0xFF18254A),
    Color(0xFF232F55),
    Color(0xFF2E385E),
    Color(0xFF3A4166),
    Color(0xFF44496C),
    Color(0xFF44496C),
  ],
  ambient: Color(0xFF292D46),
  rim: Color(0xFFA8B6E0),
  rimStrength: 0.18,
  floor: 0.3,
  glow: 0.1,
  stars: 0.85,
  cloudTop: Color(0xFF121A2E),
  cloudBottom: Color(0xFF2A3050),
  cloudGlint: Color(0xFF8A94C0),
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
  mote: Color(0xFFD2F57E),
  firefly: 0.9,
);

const _valleyDawn = _Light(
  sky: [
    Color(0xFF0A1430),
    Color(0xFF142246),
    Color(0xFF22345C),
    Color(0xFF3A4670),
    Color(0xFF5E5878),
    Color(0xFF8E6A7E),
    Color(0xFFC08884),
    Color(0xFFDCA08A),
    Color(0xFFDCA08A),
  ],
  ambient: Color(0xFF4C4A61),
  rim: Color(0xFFF2A6A0),
  rimStrength: 0.5,
  floor: 0.1,
  glow: 0.55,
  stars: 0.25,
  cloudTop: Color(0xFF3A3F62),
  cloudBottom: Color(0xFFD89A98),
  cloudGlint: Color(0xFFFFC8C0),
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

const _valleySunriseL = _Light(
  sky: [
    Color(0xFF1C3462),
    Color(0xFF2A4A7C),
    Color(0xFF44659A),
    Color(0xFF7486AE),
    Color(0xFFB49CA6),
    Color(0xFFE8B48E),
    Color(0xFFFFCF96),
    Color(0xFFFFDDA6),
    Color(0xFFFFDDA6),
  ],
  ambient: Color(0xFF8C807A),
  rim: Color(0xFFFFD08E),
  rimStrength: 0.95,
  floor: 0.1,
  glow: 1,
  stars: 0,
  cloudTop: Color(0xFF6E7898),
  cloudBottom: Color(0xFFFFC898),
  cloudGlint: Color(0xFFFFE6B0),
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

const _valleyMorning = _Light(
  sky: [
    Color(0xFF2D5C9A),
    Color(0xFF3C6EAA),
    Color(0xFF5686BA),
    Color(0xFF7EA2CA),
    Color(0xFFA4BED6),
    Color(0xFFC6D3DE),
    Color(0xFFDADFE0),
    Color(0xFFE4E4DE),
    Color(0xFFE4E4DE),
  ],
  ambient: Color(0xFFDBDBD6),
  rim: Color(0xFFFFF0D0),
  rimStrength: 0.32,
  floor: 0.5,
  glow: 0.5,
  stars: 0,
  cloudTop: Color(0xFFF4F4F2),
  cloudBottom: Color(0xFFB8C2D0),
  cloudGlint: Color(0xFFC0A070),
  grass: [
    Color(0xFF1A2814),
    Color(0xFF263A1A),
    Color(0xFF344E22),
    Color(0xFF46642A),
    Color(0xFF5C7C34),
    Color(0xFF7A9640),
    Color(0xFF9EB054),
    Color(0xFFC6CC7C),
  ],
  mote: Color(0xFFFFF6DC),
  firefly: 0,
);

const _valleyDay = _Light(
  sky: [
    Color(0xFF22528F),
    Color(0xFF3268A6),
    Color(0xFF4C80B8),
    Color(0xFF72A0CA),
    Color(0xFF9ABBD8),
    Color(0xFFBAD0E2),
    Color(0xFFCEDDE8),
    Color(0xFFD8E4EC),
    Color(0xFFD8E4EC),
  ],
  ambient: Color(0xFFFFFFFF),
  rim: Color(0xFFFFFFFF),
  rimStrength: 0.2,
  floor: 0.8,
  glow: 0.35,
  stars: 0,
  cloudTop: Color(0xFFFBFCFE),
  cloudBottom: Color(0xFFBCC8D6),
  cloudGlint: Color(0xFFB89A62),
  grass: [
    Color(0xFF1C2C14),
    Color(0xFF28401A),
    Color(0xFF365622),
    Color(0xFF486E2A),
    Color(0xFF5E8634),
    Color(0xFF7CA040),
    Color(0xFFA2BA56),
    Color(0xFFCCD686),
  ],
  mote: Color(0xFFFFF8E4),
  firefly: 0,
);

const _valleyAfternoon = _Light(
  sky: [
    Color(0xFF23497F),
    Color(0xFF335C94),
    Color(0xFF4E76A8),
    Color(0xFF7894B8),
    Color(0xFFA8AEBE),
    Color(0xFFD2BCA8),
    Color(0xFFEACCA2),
    Color(0xFFF2D6AA),
    Color(0xFFF2D6AA),
  ],
  ambient: Color(0xFFD9C7A8),
  rim: Color(0xFFFFD69A),
  rimStrength: 0.55,
  floor: 0.3,
  glow: 0.7,
  stars: 0,
  cloudTop: Color(0xFFE8E2E0),
  cloudBottom: Color(0xFFD6A88C),
  cloudGlint: Color(0xFFFFE0B0),
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

const _valleyGolden = _Light(
  sky: [
    Color(0xFF0E1D40),
    Color(0xFF172C55),
    Color(0xFF273F6C),
    Color(0xFF4A5680),
    Color(0xFF8E7E92),
    Color(0xFFD49C7C),
    Color(0xFFF2B672),
    Color(0xFFFFD898),
    Color(0xFFFFD898),
  ],
  ambient: Color(0xFF66574D),
  rim: Color(0xFFFFD48E),
  rimStrength: 1,
  floor: 0.06,
  glow: 1,
  stars: 0,
  cloudTop: Color(0xFF2C3354),
  cloudBottom: Color(0xFFE8A67C),
  cloudGlint: Color(0xFFFFDDA0),
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

const _valleySunsetL = _Light(
  sky: [
    Color(0xFF0A1534),
    Color(0xFF12214A),
    Color(0xFF22305E),
    Color(0xFF3E3E6A),
    Color(0xFF7A5470),
    Color(0xFFC46E62),
    Color(0xFFEC9058),
    Color(0xFFFFB068),
    Color(0xFFFFB068),
  ],
  ambient: Color(0xFF42333A),
  rim: Color(0xFFFFA868),
  rimStrength: 0.95,
  floor: 0.06,
  glow: 1,
  stars: 0.05,
  cloudTop: Color(0xFF22284A),
  cloudBottom: Color(0xFFF08A66),
  cloudGlint: Color(0xFFFFC08A),
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

const _valleyDusk = _Light(
  sky: [
    Color(0xFF050A1C),
    Color(0xFF09112A),
    Color(0xFF121C3C),
    Color(0xFF1E2649),
    Color(0xFF2E3052),
    Color(0xFF463A58),
    Color(0xFF5E465C),
    Color(0xFF6A4E5E),
    Color(0xFF6A4E5E),
  ],
  ambient: Color(0xFF262436),
  rim: Color(0xFFE89A9A),
  rimStrength: 0.24,
  floor: 0.2,
  glow: 0.4,
  stars: 0.55,
  cloudTop: Color(0xFF121628),
  cloudBottom: Color(0xFF3E3550),
  cloudGlint: Color(0xFFA88090),
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
  mote: Color(0xFFDCF08A),
  firefly: 0.7,
);

/// The day, keyed by hour. The night window lines up with the encounter
/// tables' (20:00–05:00).
const _valleyKeys = <(double, _Light)>[
  (0, _valleyNight),
  (4.4, _valleyNight),
  (5.0, _valleyPreDawn),
  (5.6, _valleyDawn),
  (6.4, _valleySunriseL),
  (7.8, _valleyMorning),
  (10.0, _valleyDay),
  (15.5, _valleyDay),
  (17.6, _valleyAfternoon),
  (18.7, _valleyGolden),
  (19.4, _valleySunsetL),
  (20.1, _valleyDusk),
  (21.0, _valleyNight),
  (24, _valleyNight),
];
