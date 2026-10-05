part of 'grain_field.dart';

// The Tidal Shelf, through the day.
//
// A shelf of black basalt columns at the edge of the open sea. Far off, sea
// stacks stand in the haze and the sun (or the moon) lays a path of light
// across the water toward you. Nearer, a reef of columns takes the surf; the
// far creatures stand on its column tops. The near shelf is columns too,
// standing out of a flat of wet sand, and the tide comes and goes over the
// flat on the real clock — twice a day, high water flooding it to the
// shelf's feet, low water leaving it bare with pools in it where anemones
// open. A finger drawn through the water leaves a wake; tap a pool and its
// anemones close. After dark the sea is alive with light: the surf glows
// blue where it breaks, and so does a wake. Sea fog comes in some days and
// takes the horizon; a swell some days throws the surf up the columns, and
// the first clear low water after it finds shells and glass floats left on
// the sand.
//
// Layers, matching the scene's spawn anchors:
//   sky     — screen-fixed (the camera backdrop): sun, moon, stars
//   layer2  — the open sea to the horizon, the sea stacks, the light path
//   layer3  — the reef and the nearer sea, the surf
//   layer4  — the near shelf: its columns, the flat, the tide, the pools
//   layer5  — column tops nearest of all, kelp, spray

class TidalField extends _GrainField {
  TidalField();

  static const far = SceneLayer.layer2;
  static const reef = SceneLayer.layer3;
  static const shelf = SceneLayer.layer4;
  static const fore = SceneLayer.layer5;

  /// The tide pinned for previews and tests (0 low water, 1 high), or null
  /// for the real one.
  static double? debugTide;

  static const _gSea = 0, _gSeaNear = 1, _gStack = 2, _gBasalt = 3;
  static const _gFlat = 4, _gReef = 5;

  static const _albedo = <int, Color>{
    _gSea: Color(0xFF2C5068),
    _gSeaNear: Color(0xFF244458),
    _gStack: Color(0xFF4A4C56),
    _gBasalt: Color(0xFF3E414A),
    _gFlat: Color(0xFF6A6252),
    _gReef: Color(0xFF42454E),
  };

  @override
  List<(double, _Light)> get _keys => _valleyKeys;

  @override
  double get _horizon => 0.52;

  @override
  int get _starCount => 200;

  @override
  double get _starDepth => 0.5;

  /// Where the sea meets the sky, as a share of the height.
  static const _seaTop = 0.52;

  // ── The tide ─────────────────────────────────────────────────────────────

  /// The tide now, 0 at low water and 1 at high: twice a day, on the
  /// moon's clock.
  double get tide => debugTide ?? tideAt(DateTime.now());

  /// The tide at [when], 0 at low water and 1 at high — what the field
  /// draws and what the spawns go by.
  static double tideAt(DateTime when) {
    final hours = when.toUtc().millisecondsSinceEpoch / 3600000.0;
    return 0.5 + 0.5 * math.cos(hours / 12.4206 * 2 * math.pi);
  }

  /// Where the water reaches up the flat, in the shelf's units: the far edge
  /// of the flat at low water, nearly to the bottom of the screen at high.
  double get _waterline => _h * (0.815 + 0.13 * tide);

  // ── Weather ──────────────────────────────────────────────────────────────

  double get fog => weatherKind == WeatherKind.fog ? weather : 0;
  double get swell => weatherKind == WeatherKind.swell ? weather : 0;

  /// What a swell leaves on the sand: shells and glass, at the next clear
  /// visit.
  double get _wrack => aftermath * (1 - swell);

  @override
  double get _weatherKey =>
      (fog * 1000).roundToDouble() + (swell * 1000).roundToDouble() * 1000;

  @override
  double get _veil => 0.85 * fog + 0.6 * swell;

  @override
  double get _windScale => 1 + 1.4 * swell;

  /// Fog: the light gone soft and grey, the stars and sun lost in it. A
  /// swell: the sky lowered and dark over a heavy sea.
  @override
  _Light _weathered(_Light l) {
    final f = fog, s = swell;
    if (f <= 0.001 && s <= 0.001) return l;
    Color grey(Color c, double dark) {
      final g = math.sqrt(c.computeLuminance());
      final to = Color.lerp(
        const Color(0xFF1A2026),
        const Color(0xFFB4BCC4),
        g,
      )!;
      return Color.from(
        alpha: 1,
        red: to.r * dark,
        green: to.g * dark,
        blue: to.b * dark,
      );
    }

    final k = math.max(0.85 * f, 0.7 * s);
    final dark = 1 - 0.25 * s;
    Color w(Color c, double d) => Color.lerp(c, grey(c, d * dark), k)!;
    return _Light(
      stops: l.stops,
      sky: [for (final c in l.sky) w(c, 0.95)],
      ambient: w(l.ambient, 0.75),
      rim: Color.lerp(l.rim, const Color(0xFFD8E0E8), k)!,
      rimStrength: l.rimStrength * (1 - 0.7 * k),
      floor: l.floor + (math.max(0.7, l.floor) - l.floor) * k,
      glow: l.glow * (1 - 0.8 * k),
      stars: l.stars * (1 - 0.95 * k),
      cloudTop: w(l.cloudTop, 0.7),
      cloudBottom: w(l.cloudBottom, 0.8),
      cloudGlint: l.cloudGlint,
      grass: [for (final c in l.grass) w(c, 0.8)],
      mote: l.mote,
      firefly: 0,
    );
  }

  // ── The hour's colours ───────────────────────────────────────────────────

  /// How dark the hour is: 1 at night. The sea lights up with it.
  double _night = 0;

  /// The water's colours for the live parts: deep, shallow over the flat,
  /// foam, and the sea's own light after dark.
  Color _seaMid = const Color(0xFF000000),
      _deep = const Color(0xFF000000),
      _shallow = const Color(0xFF000000),
      _foam = const Color(0xFFFFFFFF);
  static const _glow = Color(0xFF6CF2FF);

  @override
  void _buildGrades(_Light l) {
    final lum = l.ambient.computeLuminance();
    // The sea's light shows once the stars are out, not at dusk.
    _night = ((l.stars - 0.3) / 0.6).clamp(0.0, 1.0);
    assert(lum >= 0);
    final hazeHigh = l.skyAt(0.5), hazeLow = l.skyAt(0.585);
    final f = fog;
    Color sil(int g) {
      final a = _albedo[g]!;
      var s = Color.from(
        alpha: 1,
        red: a.r * l.ambient.r,
        green: a.g * l.ambient.g,
        blue: a.b * l.ambient.b,
      );
      // Water gives back the sky over it.
      if (g == _gSea || g == _gSeaNear) {
        s = Color.lerp(
          s,
          l.skyAt(g == _gSea ? 0.5 : 0.4),
          g == _gSea ? 0.72 : 0.5,
        )!;
      }
      if (f > 0) {
        final k = switch (g) {
          _gSea || _gStack => 0.9,
          _gSeaNear || _gReef => 0.6,
          _ => 0.25,
        };
        s = Color.lerp(s, hazeLow, f * k)!;
      }
      return s;
    }

    (double, double, double) fleck(Color s, double k) => (
      s.r * 0.8 + l.rim.r * l.rimStrength * k,
      s.g * 0.8 + l.rim.g * l.rimStrength * k,
      s.b * 0.8 + l.rim.b * l.rimStrength * k,
    );
    for (final g in [_gSea, _gStack]) {
      final s = sil(g);
      _grades[g] = fieldGrade(
        base: s,
        r: fieldDiff(hazeHigh, s),
        g: fleck(s, 0.5),
        b: fieldScale(s, -0.6),
      );
    }
    for (final g in [_gSeaNear, _gBasalt, _gFlat, _gReef]) {
      final s = sil(g);
      _grades[g] = fieldGrade(
        base: s,
        r: fieldDiff(hazeLow, s),
        g: fleck(s, 0.45),
        b: fieldScale(s, -0.75),
      );
    }
    final sea = sil(_gSeaNear);
    // The near sea's own colour where the swimmers are, a third of the way
    // down it, as it is baked: what is drawn over them must match it.
    _seaMid = Color.from(
      alpha: 1,
      red: sea.r * 0.6 + hazeLow.r * 0.16,
      green: sea.g * 0.6 + hazeLow.g * 0.16,
      blue: sea.b * 0.6 + hazeLow.b * 0.16,
    );
    final sky = l.skyAt(0.4);
    _deep = Color.lerp(sea, sky, 0.12)!;
    _shallow = Color.lerp(sil(_gFlat), sea, 0.55)!;
    _foam = Color.lerp(
      Color.lerp(l.ambient, const Color(0xFFFFFFFF), 0.5)!,
      const Color(0xFFDDE8F0),
      0.3,
    )!;
  }

  // ── Where the creatures stand ────────────────────────────────────────────

  /// Every ground point, on the reef or the shelf, stands on a column top
  /// at its feet; so does each one's encounter partner.
  List<({String id, SceneLayer layer, double x, double top, double hw})>
  _platforms = const [];

  /// The basalt standing for scenery: where the wild has it, or where the
  /// player put it.
  static const _wildBasalt = <(SceneLayer, double, double, double)>[
    // (layer, x as a share of its loop, half width, height above the flat)
    // On the shelf: a great stepped headland mid-loop, a lower causeway
    // late, a small stand early.
    (SceneLayer.layer4, 0.255, 30, 46),
    (SceneLayer.layer4, 0.48, 74, 128),
    (SceneLayer.layer4, 0.985, 84, 84),
    // On the reef: stands rising out of the surf.
    (SceneLayer.layer3, 0.08, 34, 58),
    (SceneLayer.layer3, 0.42, 30, 44),
    (SceneLayer.layer3, 0.83, 40, 70),
    (SceneLayer.layer3, 0.95, 24, 40),
  ];

  /// The basalt as the home biome first has it: (far row?, x, half width,
  /// height).
  static List<(bool, double, double, double)> get homeBasalt => [
    for (final (l, x, hw, h) in _wildBasalt) (l == SceneLayer.layer3, x, hw, h),
  ];

  void _makePlatforms() {
    final out =
        <({String id, SceneLayer layer, double x, double top, double hw})>[];
    for (final p in _spawns) {
      if (p.anchor != reef && p.anchor != shelf) continue;
      final x = _spawnX(p);
      final hw = p.size.x * (p.anchor == reef ? 0.42 : 0.4) * _u;
      // One over the sea needs none of its own — but its partner, who may
      // not float, does.
      if (!p.aloft && p.perch != SpawnPerch.wade && !_shares(p)) {
        final (mid, extra) = _sharedSpan(p, x);
        out.add((
          id: p.id,
          layer: p.anchor,
          x: mid,
          top: _feet(p),
          hw: hw + extra,
        ));
      }
      if (_partners) {
        final bx = x + p.partnerSide * kFieldPairGap;
        final feet = p.getBattlePos().dy * _h + p.size.y * 0.42;
        out.add((
          id: '${p.id}_partner',
          layer: p.anchor,
          x: bx,
          top: feet,
          hw: hw,
        ));
      }
    }
    _platforms = out;
  }

  ({String id, SceneLayer layer, double x, double top, double hw})? _platformAt(
    SceneLayer layer,
    double x,
  ) {
    for (final p in _platforms) {
      if (p.layer != layer) continue;
      if (_loopDelta(x, p.x, layer).abs() <= p.hw * 1.05) return p;
    }
    return null;
  }

  @override
  double? perchFor(String spawnId) {
    for (final p in _platforms) {
      if (p.id == spawnId) return p.top;
    }
    for (final p in _spawns) {
      if (p.id == spawnId && _shares(p)) return _sharedPerch(p);
    }
    return null;
  }

  @override
  ({double top, double rest})? groundAt(SceneLayer layer, double x) {
    if (layer != reef && layer != shelf) return null;
    final p = _platformAt(layer, x);
    // On a column top: anything that cannot float is stood on it.
    if (p != null) return (top: double.infinity, rest: p.top);
    if (layer == reef) return null;
    // The flat, where there is no column.
    return (top: _flatTop + 2 * _u, rest: _flatTop + 0.08 * _h);
  }

  double get _flatTop => _h * 0.805;

  // ── Build ────────────────────────────────────────────────────────────────

  double _shelfWidth = 0, _foreWidth = 0;
  _Blades? _kelp;
  List<(double, double, double)> _foreTops = const [];

  @override
  List<FieldSheet> build(SceneLayer layer, Size size, Size screen) {
    _h = size.height;
    _u = _h / 475;
    _screen = screen;
    final w = size.width;
    _widths[layer] = w;
    _makePlatforms();
    switch (layer) {
      case far:
        _glints[far] = _Glints();
        final sea = Rect.fromLTWH(0, _h * (_seaTop - 0.12), w, _h * 0.42);
        return [
          FieldSheet(
            bounds: sea,
            resolution: 0.8,
            grade: _gSea,
            paint: (c) => _paintSea(c, w),
          ),
          FieldSheet(
            bounds: sea,
            resolution: 0.8,
            grade: _gStack,
            paint: (c) => _paintStacks(c, w, null),
          ),
          FieldSheet(
            bounds: sea,
            resolution: 0.8,
            light: true,
            paint: (c) => _sinking(far, () {
              final sparks = GrainBatch(_sparkAlpha.length);
              _paintStacks(_NullCanvas(), w, sparks);
              _drawSparks(c, sparks, 1.2);
            }),
          ),
        ];
      case reef:
        _glints[reef] = _Glints();
        final area = Rect.fromLTWH(0, _h * 0.42, w, _h * 0.5);
        return [
          FieldSheet(
            bounds: area,
            grade: _gSeaNear,
            paint: (c) => _paintNearSea(c, w),
          ),
          ..._basaltSheets(reef, area, _gReef, 0.12),
        ];
      case shelf:
        _glints[shelf] = _Glints();
        _shelfWidth = w;
        final area = Rect.fromLTWH(0, _h * 0.55, w, _h * 0.45 + 8 * _u);
        return [
          FieldSheet(
            bounds: area,
            grade: _gFlat,
            paint: (c) => _paintFlat(c, w),
          ),
          // The tide over the flat, under the columns.
          FieldSheet.live(bounds: area, live: _paintWater),
          ..._basaltSheets(shelf, area, _gBasalt, 0),
        ];
      case fore:
        _foreWidth = w;
        _foreTops = _makeForeTops(w);
        _kelp = _makeKelp(w);
        final area = Rect.fromLTWH(0, _h * 0.78, w, _h * 0.22 + 10 * _u);
        return [
          FieldSheet(
            bounds: area,
            grade: _gBasalt,
            paint: (c) {
              for (final (x, hw, ht) in _foreTops) {
                _wrapped(x, hw * 1.3, w, (at) {
                  _basalt(
                    c,
                    null,
                    at,
                    _h - ht,
                    _h + 12 * _u,
                    hw,
                    6600 + x.round(),
                    dark: 0.5,
                  );
                });
              }
            },
          ),
          FieldSheet(
            bounds: area,
            light: true,
            paint: (c) {
              final sparks = GrainBatch(_sparkAlpha.length);
              for (final (x, hw, ht) in _foreTops) {
                _wrapped(x, hw * 1.3, w, (at) {
                  _basalt(
                    _NullCanvas(),
                    sparks,
                    at,
                    _h - ht,
                    _h + 12 * _u,
                    hw,
                    6600 + x.round(),
                  );
                });
              }
              _drawSparks(c, sparks, 1.5);
            },
          ),
        ];
      default:
        return const [];
    }
  }

  @override
  bool hasLive(SceneLayer layer, {required bool front}) => switch (layer) {
    shelf || reef => true,
    far || fore => !front,
    _ => false,
  };

  // ── The sea ──────────────────────────────────────────────────────────────

  void _paintSea(Canvas c, double w) {
    final top = _h * _seaTop, bottom = _h * 0.86;
    c.drawRect(
      Rect.fromLTRB(-4, top, w + 4, bottom),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, top),
          Offset(0, bottom),
          [
            fieldMap(0.85, 0.05, 0.05),
            fieldMap(0.4, 0, 0.3),
            fieldMap(0.15, 0, 0.6),
          ],
          const [0.0, 0.25, 1.0],
        ),
    );
    // Swells: broad soft bands, closer together toward the horizon, a
    // shade lighter on their faces.
    for (var k = 0; k < 16; k++) {
      final f = math.pow((k + 0.5) / 16, 1.7).toDouble();
      final y = top + f * (bottom - top);
      final th = (1.2 + 6 * f) * _u;
      double edge(double x) => y + _nf(x, 120 + 200 * f, 300 + k) * th * 1.4;
      final band = Path()..moveTo(-4, edge(-4));
      for (var x = -4.0; x <= w + 4; x += 6 * _u) {
        band.lineTo(x, edge(x));
      }
      for (var x = w + 4; x >= -4; x -= 6 * _u) {
        band.lineTo(x, edge(x) + th);
      }
      band.close();
      c.drawPath(band, Paint()..color = fieldMap(0.3, 0.14, 0.15, 0.35));
    }
  }

  double _nf(double x, double wave, int seed) =>
      fieldLoopNoise(x, wave, seed, _period(far));
  double _nr(double x, double wave, int seed) =>
      fieldLoopNoise(x, wave, seed, _period(reef));

  /// The sea stacks far out: (x as a share of the loop, half width,
  /// height as a share of the height).
  static const _stacks = [
    (0.12, 0.035, 0.11),
    (0.18, 0.018, 0.06),
    (0.53, 0.05, 0.16),
    (0.6, 0.02, 0.07),
    (0.84, 0.03, 0.09),
  ];

  void _paintStacks(Canvas c, double w, GrainBatch? sparks) {
    for (var i = 0; i < _stacks.length; i++) {
      final (fx, hw, ht) = _stacks[i];
      _wrapped(fx * w, hw * _h * 1.4, w, (x) {
        _basalt(
          c,
          sparks,
          x,
          _h * (_seaTop + 0.02 - ht),
          _h * (_seaTop + 0.03),
          hw * _h,
          4100 + i,
          haze: 0.55,
          column: 9,
        );
      });
    }
  }

  void _paintNearSea(Canvas c, double w) {
    final top = _h * 0.6, bottom = _h * 0.9;
    c.drawRect(
      Rect.fromLTRB(-4, top, w + 4, bottom),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, top),
          Offset(0, bottom),
          [
            fieldMap(0.3, 0, 0.3, 0),
            fieldMap(0.2, 0, 0.45),
            fieldMap(0.05, 0, 0.7),
          ],
          const [0.0, 0.25, 1.0],
        ),
    );
    for (var k = 0; k < 7; k++) {
      final f = (k + 0.5) / 7;
      final y = top + f * (bottom - top);
      final th = (3 + 7 * f) * _u;
      double edge(double x) => y + _nr(x, 160, 400 + k) * th;
      final band = Path()..moveTo(-4, edge(-4));
      for (var x = -4.0; x <= w + 4; x += 6 * _u) {
        band.lineTo(x, edge(x));
      }
      for (var x = w + 4; x >= -4; x -= 6 * _u) {
        band.lineTo(x, edge(x) + th);
      }
      band.close();
      c.drawPath(band, Paint()..color = fieldMap(0.15, 0.12, 0.2, 0.3));
    }
  }

  // ── Basalt ───────────────────────────────────────────────────────────────

  /// The columns of [layer]: under every point that stands there, and the
  /// scenery.
  List<({double x, double top, double base, double hw, int seed})> _columnsOf(
    SceneLayer layer,
  ) {
    final width = _widths[layer] ?? _worldWidth;
    final foot = layer == reef ? _h * 0.74 : _h * 0.95;
    final out = <({double x, double top, double base, double hw, int seed})>[
      for (final p in _platforms)
        if (p.layer == layer)
          (
            x: p.x,
            top: p.top,
            base: math.max(foot, p.top + 22 * _u),
            hw: p.hw,
            seed: fieldSeedOf(p.id),
          ),
    ];
    if (_placed) {
      for (final p in _piecesOn(layer, {FieldPiece.basalt})) {
        final x = _spawnX(p);
        final base = layer == reef ? _h * 0.72 : _h * 0.9;
        out.add((
          x: x,
          top: base - p.size.y * _u,
          base: base + 20 * _u,
          hw: p.size.x * _u,
          seed: fieldSeedOf(p.id),
        ));
      }
    } else {
      var i = 0;
      for (final (l, fx, hw, ht) in _wildBasalt) {
        if (l != layer) continue;
        final base = layer == reef ? _h * 0.72 : _h * 0.9;
        out.add((
          x: fx * width,
          top: base - ht * _u,
          base: base + 20 * _u,
          hw: hw * _u,
          seed: 8800 + i++,
        ));
      }
    }
    // Back to front: the tallest behind.
    out.sort((a, b) => a.top.compareTo(b.top));
    return out;
  }

  List<FieldSheet> _basaltSheets(
    SceneLayer layer,
    Rect area,
    int grade,
    double haze,
  ) {
    final cols = _columnsOf(layer);
    final w = _widths[layer] ?? _worldWidth;
    return [
      FieldSheet(
        bounds: area,
        grade: grade,
        paint: (c) {
          for (final k in cols) {
            _wrapped(k.x, k.hw * 1.4, w, (at) {
              _basalt(c, null, at, k.top, k.base, k.hw, k.seed, haze: haze);
            });
          }
        },
      ),
      FieldSheet(
        bounds: area,
        light: true,
        paint: (c) => _sinking(layer, () {
          final sparks = GrainBatch(_sparkAlpha.length);
          for (final k in cols) {
            _wrapped(k.x, k.hw * 1.4, w, (at) {
              _basalt(_NullCanvas(), sparks, at, k.top, k.base, k.hw, k.seed);
            });
          }
          _drawSparks(c, sparks, 1.3);
        }),
      ),
    ];
  }

  /// A mass of sea rock, weathered round by the water: a broad foot, sides
  /// bulging and cut back where the sea has worked them, and a top worn
  /// nearly level where feet go at [top] (a far stack, [spire], keeps a
  /// rough crown instead). Lit from above and fading to wet dark at its
  /// foot, cracked, pitted, with barnacles and weed along the tide line.
  /// With [sparks], only the light along its top: wet, catching.
  void _basalt(
    Canvas c,
    GrainBatch? sparks,
    double cx,
    double top,
    double base,
    double hw,
    int seed, {
    double haze = 0,
    double dark = 0,
    int? column,
  }) {
    final spire = column != null;
    final outline = _rockOutline(cx, top, base, hw, seed, spire: spire);
    if (sparks != null) {
      // Light along the top edge, wet.
      for (var i = 0; i < outline.length; i++) {
        final p = outline[i];
        if (p.dy > top + (base - top) * (spire ? 0.35 : 0.18)) continue;
        final roll = fieldHash(i, seed);
        if (roll > 0.7) continue;
        sparks.add((roll * 5).floor().clamp(0, 3), p.dx, p.dy + 0.8 * _u);
        if (roll < 0.05) _glint(p.dx, p.dy + 0.8 * _u);
      }
      return;
    }
    final rock = _smooth(outline);
    final h = base - top;
    c.drawPath(
      rock,
      Paint()
        ..shader = Gradient.linear(
          Offset(cx - hw * 0.6, top),
          Offset(cx + hw * 0.4, base),
          [
            fieldMap(haze, 0.16, 0.08 + dark),
            fieldMap(haze, 0.03, 0.42 + dark * 0.4),
            fieldMap(haze, 0, 0.82),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
    c
      ..save()
      ..clipPath(rock);
    final r = FieldRandom(seed * 7 + 5);
    // Planes the sea has cut: soft darker facets down its shaded side, and
    // a few lighter ones up its lit side.
    for (var i = 0; i < 6; i++) {
      final right = i < 4;
      final fx = cx + (right ? r.range(0.05, 0.8) : r.range(-0.8, -0.2)) * hw;
      final fy = top + r.range(0.15, 0.85) * h;
      final fw = hw * r.range(0.25, 0.5), fh = h * r.range(0.2, 0.45);
      c.drawPath(
        Path()..addPolygon([
          Offset(fx - fw * 0.5, fy - fh * 0.3),
          Offset(fx + fw * 0.2, fy - fh * 0.5),
          Offset(fx + fw * 0.55, fy + fh * 0.1),
          Offset(fx + fw * 0.1, fy + fh * 0.5),
          Offset(fx - fw * 0.45, fy + fh * 0.25),
        ], true),
        Paint()
          ..color = right
              ? fieldMap(haze, 0, 0.75, 0.35)
              : fieldMap(haze, 0.1, 0.1, 0.25),
      );
    }
    // Streaks where water runs down it: broad, soft, a shade darker.
    for (var i = 0; i < 4; i++) {
      final x0 = cx + r.range(-0.7, 0.6) * hw;
      final sw = r.range(3, 8) * _u;
      final y0 = top + h * r.range(0.1, 0.4);
      c.drawRect(
        Rect.fromLTRB(x0, y0, x0 + sw, base),
        Paint()
          ..shader = Gradient.linear(Offset(0, y0), Offset(0, base), [
            fieldMap(haze, 0, 0.7, 0),
            fieldMap(haze, 0, 0.7, 0.3),
          ]),
      );
    }
    // Pitting, and lighter grains where it is dry.
    final grains = GrainBatch(4);
    for (var i = 0; i < (hw * h / (12 * _u * _u)).round(); i++) {
      final x = cx + (fieldHash(i, seed) - 0.5) * hw * 2.2;
      final y = top + fieldHash(i, seed + 1) * h;
      final f = (y - top) / h;
      grains.add(f < 0.45 ? 1 : 0, x, y);
    }
    // Barnacles along the tide line, and weed hanging from it.
    final tideLine = top + h * (spire ? 0.82 : 0.62);
    for (var i = 0; i < (hw * 2 / (1.4 * _u)).round(); i++) {
      final x = cx - hw * 1.1 + fieldHash(i, seed + 3) * hw * 2.2;
      final y = tideLine + (fieldHash(i, seed + 4) - 0.5) * 8 * _u;
      grains.add(2, x, y);
      if (fieldHash(i, seed + 5) < 0.55) {
        final drop = fieldHash(i, seed + 6) * 16 * _u;
        for (var d = 0.0; d < drop; d += 1.5 * _u) {
          grains.add(3, x + math.sin(d * 0.3) * 0.6 * _u, y + 3 * _u + d);
        }
      }
    }
    grains
      ..draw(c, 0, 1.4 * _u, fieldMap(haze, 0, 0.95, 0.55))
      ..draw(c, 1, 1.2 * _u, fieldMap(haze, 0.25, 0.1, 0.45))
      ..draw(c, 2, 1.4 * _u, fieldMap(haze, 0.14, 0.3, 0.45))
      ..draw(c, 3, 1.7 * _u, fieldMap(haze, 0.04, 0.6, 0.85));
    // Wet and dark below the tide line.
    c.drawRect(
      Rect.fromLTRB(cx - hw * 1.4, tideLine, cx + hw * 1.4, base + 2 * _u),
      Paint()
        ..shader = Gradient.linear(Offset(0, tideLine), Offset(0, base), [
          fieldMap(haze, 0.05, 0.4, 0.2),
          fieldMap(haze, 0.08, 0.8, 0.7),
        ]),
    );
    c.restore();
  }

  /// A rock's outline, going round: worn level across the middle of its top
  /// at [top] (or a rough crown, for a [spire]), its shoulders rounded off,
  /// its sides bulging and cut back, broad at its foot.
  List<Offset> _rockOutline(
    double cx,
    double top,
    double base,
    double hw,
    int seed, {
    bool spire = false,
  }) {
    final h = base - top;
    final pts = <Offset>[];
    final flat = spire ? 0.2 : 0.42;
    const n = 18;
    for (var i = 0; i <= n; i++) {
      final f = i / n * 2 - 1;
      final edge = (f.abs() - flat).clamp(0.0, 1.0) / (1 - flat);
      final drop =
          math.pow(edge, 1.7) * h * (spire ? 0.35 : 0.3) +
          fieldNoise(i * 0.9, seed) * (spire ? 4 : 1.5) * _u;
      pts.add(Offset(cx + f * hw * 0.9, top + drop));
    }
    for (var i = 1; i <= 6; i++) {
      final f = i / 6;
      final out =
          0.92 + 0.3 * math.pow(f, 1.5) + 0.12 * fieldNoise(f * 3, seed + 2);
      pts.add(
        Offset(cx + hw * out * (spire ? 0.8 : 1), top + h * (0.3 + 0.72 * f)),
      );
    }
    for (var i = 6; i >= 1; i--) {
      final f = i / 6;
      final out =
          0.94 + 0.34 * math.pow(f, 1.5) + 0.12 * fieldNoise(f * 3, seed + 3);
      pts.add(
        Offset(cx - hw * out * (spire ? 0.8 : 1), top + h * (0.3 + 0.72 * f)),
      );
    }
    return pts;
  }

  /// A closed outline drawn smooth: through the middles of its edges, each
  /// corner a curve.
  Path _smooth(List<Offset> pts) {
    final path = Path();
    final n = pts.length;
    final first = Offset.lerp(pts[n - 1], pts[0], 0.5)!;
    path.moveTo(first.dx, first.dy);
    for (var i = 0; i < n; i++) {
      final a = pts[i], b = pts[(i + 1) % n];
      final mid = Offset.lerp(a, b, 0.5)!;
      path.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
    }
    return path..close();
  }

  // ── The flat ─────────────────────────────────────────────────────────────

  /// The pools in the flat where the wild has them: (x as a share of the
  /// loop, how far down the flat, half width).
  static const _pools = [
    (0.07, 0.62, 42.0),
    (0.43, 0.75, 54.0),
    (0.66, 0.55, 36.0),
    (0.79, 0.82, 48.0),
  ];

  ({double x, double y, double hw, double hh}) _poolShape(int i, double w) {
    final (fx, f, hw) = _pools[i];
    final y = _flatTop + f * (_h - _flatTop);
    final s = (0.6 + f * 0.7) * _u;
    return (x: fx * w, y: y, hw: hw * s, hh: hw * s * 0.24);
  }

  void _paintFlat(Canvas c, double w) {
    c.drawRect(
      Rect.fromLTRB(-4, _flatTop, w + 4, _h + 8 * _u),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, _flatTop),
          Offset(0, _h),
          [
            fieldMap(0.2, 0.12, 0.25),
            fieldMap(0, 0.04, 0.35),
            fieldMap(0, 0, 0.6),
          ],
          const [0.0, 0.3, 1.0],
        ),
    );
    // Ripple marks the ebb left: soft wandering bands, closer far off.
    for (var k = 0; k < 14; k++) {
      final f = math.pow((k + 0.5) / 14, 1.3).toDouble();
      final y = _flatTop + f * (_h - _flatTop);
      final th = (1.5 + 5 * f) * _u;
      double edge(double x) =>
          y + fieldLoopNoise(x, 70 + 80 * f, 500 + k, _period(shelf)) * th;
      final band = Path()..moveTo(-4, edge(-4));
      for (var x = -4.0; x <= w + 4; x += 5 * _u) {
        band.lineTo(x, edge(x));
      }
      for (var x = w + 4; x >= -4; x -= 5 * _u) {
        band.lineTo(x, edge(x) + th);
      }
      band.close();
      c.drawPath(band, Paint()..color = fieldMap(0, 0.12, 0.1, 0.3));
    }
    // The pools: rimmed with weed, dark and still.
    for (var i = 0; i < _pools.length; i++) {
      final s = _poolShape(i, w);
      _wrapped(s.x, s.hw * 1.3, w, (x) {
        final oval = Rect.fromCenter(
          center: Offset(x, s.y),
          width: s.hw * 2,
          height: s.hh * 2,
        );
        c
          ..drawOval(
            oval.inflate(2 * _u),
            Paint()..color = fieldMap(0, 0.06, 0.55, 0.8),
          )
          ..drawOval(
            oval,
            Paint()
              ..shader = Gradient.linear(oval.topCenter, oval.bottomCenter, [
                fieldMap(0.25, 0.1, 0.5),
                fieldMap(0.05, 0, 0.92),
              ]),
          );
      });
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
        _paintLightPath(canvas, view);
        _paintStackFoam(canvas, view);
        _paintFog(canvas, view, far, 0.4, 0.8);
      case reef:
        if (front) {
          _paintSwimming(canvas, view);
        } else {
          _paintSurf(canvas, view);
          _paintFog(canvas, view, reef, 0.5, 0.9);
        }
      case shelf:
        if (!front) {
          _paintPools(canvas, view);
          _paintWrack(canvas, view);
        } else {
          _paintWake(canvas, view);
          _paintSpray(canvas, view);
        }
      case fore:
        final kelp = _kelp;
        if (kelp != null) {
          _stirBlades(
            kelp,
            fore,
            _foreWidth,
            view,
            reach: 50 * _u,
            maxBend: 0.9,
          );
          _paintBlades(
            canvas,
            view,
            kelp,
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

  final GrainBatch _pathBatch = GrainBatch(3);

  /// The sun's path across the water, or the moon's: glitter in a column
  /// under it, narrow at the horizon and spreading toward you, brightest
  /// with the light low.
  void _paintLightPath(Canvas canvas, FieldView view) {
    final byMoon = _sunUp < -0.05;
    final up = byMoon ? _moonUp : _sunUp;
    if (up < -0.05) return;
    final lit = byMoon
        ? (1 - math.cos(_moonPhase * 2 * math.pi)) / 2 * 0.7
        : 1.0;
    final low = (1 - up.clamp(0.0, 1.0) * 0.8);
    final strength = lit * low * (1 - fog * 0.9);
    if (strength < 0.04) return;
    final sx =
        view.left + (byMoon ? _moonX : _sunX) * _screen.width / view.zoom;
    final top = _h * _seaTop, span = _h * 0.3;
    final t = view.time;
    _pathBatch.clear();
    for (var i = 0; i < 300; i++) {
      final d = math.pow(fieldHash(i, 41), 1.4).toDouble();
      final y = top + 1 * _u + d * span;
      final spread = (4 + d * 70) * _u * (0.6 + 0.6 * low);
      final across = (fieldHash(i, 43) - 0.5) * 2;
      // Concentrated in the middle of the path.
      final x = sx + across * across.abs() * spread;
      final s = math.sin(t * (1.5 + fieldHash(i, 47) * 2.5) + i * 1.7);
      if (s < 0.25) continue;
      _pathBatch.add(s > 0.85 ? 2 : (s > 0.55 ? 1 : 0), x, y);
    }
    final col = byMoon
        ? const Color(0xFFDDE6FF)
        : Color.lerp(_light.rim, const Color(0xFFFFFFFF), 0.4)!;
    for (var lv = 0; lv < 3; lv++) {
      _pathBatch.draw(
        canvas,
        lv,
        (1.0 + 0.35 * lv) * _u,
        col.withValues(alpha: (strength * (0.3 + 0.3 * lv)).clamp(0.0, 1.0)),
      );
    }
  }

  final GrainBatch _foamBatch = GrainBatch(4);

  /// Foam breathing round the feet of the far stacks.
  void _paintStackFoam(Canvas canvas, FieldView view) {
    final t = view.time;
    _foamBatch.clear();
    final w = _widths[far] ?? 1;
    for (final shift in _shiftsFor(far, view, 40 * _u)) {
      for (var i = 0; i < _stacks.length; i++) {
        final (fx, hw, _) = _stacks[i];
        final x0 = fx * w + shift;
        final half = hw * _h;
        if (x0 + half * 2 < view.left || x0 - half * 2 > view.right) continue;
        final y = _h * (_seaTop + 0.028);
        for (var j = 0; j < 24; j++) {
          final a = fieldHash(j, 70 + i);
          final s = math.sin(t * 0.9 + a * 9 + i);
          if (s < 0) continue;
          _foamBatch.add(
            j % 2,
            x0 + (a - 0.5) * half * 2.6,
            y - s * (1 + 3 * fieldHash(j, 71)) * _u,
          );
        }
      }
    }
    _foamBatch
      ..draw(canvas, 0, 1.2 * _u, _foam.withValues(alpha: 0.45))
      ..draw(canvas, 1, 1.0 * _u, _foam.withValues(alpha: 0.65));
  }

  /// How hard the surf comes in: a swell throws it twice as high.
  double get _surge => 1 + 1.4 * swell;

  /// The surf on the reef: each stand of columns has the sea surging round
  /// its feet, throwing foam up its sides and sliding back off. After dark
  /// it glows blue where it breaks.
  void _paintSurf(Canvas canvas, FieldView view) {
    final t = view.time;
    final cols = _columnsOf(reef);
    _foamBatch.clear();
    for (final shift in _shiftsFor(reef, view, 80 * _u)) {
      for (final k in cols) {
        final x0 = k.x + shift;
        if (x0 + k.hw * 2 < view.left || x0 - k.hw * 2 > view.right) continue;
        final period = 5.5 - 2 * swell + fieldHash(k.seed, 3) * 2;
        final ph = ((t + fieldHash(k.seed, 5) * period) / period) % 1.0;
        // A wave's rise and its fall back.
        final rise = ph < 0.35
            ? math.sin(ph / 0.35 * math.pi / 2)
            : math.pow(1 - (ph - 0.35) / 0.65, 2).toDouble();
        final sea = _h * 0.72;
        final reach = (14 + 22 * rise) * _u * _surge;
        final n = (70 * (0.3 + rise) * (1 + 1.6 * swell)).round();
        for (var j = 0; j < n; j++) {
          final a = fieldHash(j, k.seed);
          final b = fieldHash(j, k.seed + 7);
          final x = x0 + (a - 0.5) * k.hw * 2.8;
          // Higher at the columns, lower off their sides.
          final atCol = (1 - ((a - 0.5).abs() * 2 - 0.6).clamp(0.0, 1.0));
          // Most of it a low band of white water hugging the feet, the
          // rest thrown up the columns.
          final lift = b < 0.6 ? b * 0.15 : b;
          final y = sea - lift * reach * atCol - (1 - atCol) * 2 * _u;
          final level = b > 0.75 ? 3 : (b > 0.4 ? 2 : (b > 0.15 ? 1 : 0));
          _foamBatch.add(level, x, y);
        }
      }
    }
    // Whitecaps across the near sea in a swell, breaking and gone.
    if (swell > 0.05) {
      final n = (160 * swell).round();
      for (var i = 0; i < n; i++) {
        final life = (t * 0.6 + fieldHash(i, 1201)) % 1.0;
        if (life > 0.4) continue;
        final round = (t * 0.6 + fieldHash(i, 1201)).floor();
        final x =
            view.left +
            fieldHash(i * 31 + round, 1203) * (view.right - view.left);
        final y = _h * (0.6 + 0.24 * fieldHash(i * 31 + round, 1205));
        final level = life < 0.15 ? 3 : (life < 0.3 ? 2 : 1);
        for (var j = 0; j < 4; j++) {
          _foamBatch.add(level, x + (j - 1.5) * 2.2 * _u, y - (j % 2) * _u);
        }
      }
    }
    final glow = _night * (1 - fog * 0.6);
    final col = Color.lerp(_foam, _glow, glow * 0.85)!;
    for (var lv = 0; lv < 4; lv++) {
      if (glow > 0.05 && lv >= 2) {
        _foamBatch.draw(
          canvas,
          lv,
          3.2 * _u,
          _glow.withValues(alpha: 0.18 * glow),
        );
      }
      _foamBatch.draw(
        canvas,
        lv,
        (1.0 + 0.25 * lv) * _u,
        col.withValues(alpha: 0.25 + 0.18 * lv),
      );
    }
  }

  // ── Swimming ─────────────────────────────────────────────────────────────

  final GrainBatch _swimBatch = GrainBatch(3);

  /// Whatever swims out in the sea at a point that wades: the sea drawn
  /// again over its lower half, soft at the sides, with a ring of foam round
  /// it where the water meets it and rings spreading off it. At night the
  /// foam glows.
  void _paintSwimming(Canvas canvas, FieldView view) {
    final t = view.time;
    _swimBatch.clear();
    var any = false;
    for (final p in _spawns) {
      if (p.anchor != reef || p.perch != SpawnPerch.wade) continue;
      final feet = _feet(p);
      final line =
          feet - p.size.y * 0.38 + math.sin(t * 1.4 + p.id.length) * 1.2 * _u;
      final half = p.size.x * 0.62;
      for (final shift in _shiftsFor(reef, view, half * 1.4)) {
        final x = _spawnX(p) + shift;
        if (x + half * 1.4 < view.left || x - half * 1.4 > view.right) continue;
        any = true;
        final rect = Rect.fromLTRB(
          x - half * 1.1,
          line,
          x + half * 1.1,
          feet + 2 * _u,
        );
        canvas.drawRect(
          rect,
          Paint()
            ..shader = Gradient.linear(
              rect.centerLeft,
              rect.centerRight,
              [
                _seaMid.withValues(alpha: 0),
                _seaMid.withValues(alpha: 0.96),
                _seaMid.withValues(alpha: 0.96),
                _seaMid.withValues(alpha: 0),
              ],
              const [0.0, 0.25, 0.75, 1.0],
            ),
        );
        // Foam where the water meets it, and two rings spreading.
        for (var k = 0; k < 22; k++) {
          final f = k / 21 * 2 - 1;
          final shimmer = 0.5 + 0.5 * math.sin(t * 2.4 + k * 1.1);
          if (shimmer < 0.3) continue;
          _swimBatch.add(
            shimmer > 0.8 ? 2 : 1,
            x + f * half * 0.55,
            line + (1 - f * f) * 1.8 * _u,
          );
        }
        for (var r = 0; r < 2; r++) {
          final age = ((t * 0.45 + r * 0.5) % 1.0);
          final rx = half * (0.6 + age * 0.9), ry = rx * 0.16;
          final n = 30;
          for (var k = 0; k < n; k++) {
            if (fieldHash(k + r * 31, (t * 0.45 + r * 0.5).floor()) >
                1 - age * 0.6) {
              continue;
            }
            final a = k / n * math.pi * 2;
            _swimBatch.add(
              0,
              x + math.cos(a) * rx,
              line + 2 * _u + math.sin(a) * ry,
            );
          }
        }
      }
    }
    if (!any) return;
    final glow = _night * (1 - fog * 0.6);
    final col = Color.lerp(_foam, _glow, glow * 0.85)!;
    _swimBatch
      ..draw(canvas, 0, 1.2 * _u, col.withValues(alpha: 0.45))
      ..draw(canvas, 1, 1.4 * _u, col.withValues(alpha: 0.6))
      ..draw(canvas, 2, 1.7 * _u, col.withValues(alpha: 0.85));
    if (glow > 0.05) {
      _swimBatch.draw(canvas, 2, 3.4 * _u, _glow.withValues(alpha: 0.2 * glow));
    }
  }

  // ── The tide ─────────────────────────────────────────────────────────────

  /// The water over the flat, as a live sheet under the columns: from the
  /// flat's far edge down to the waterline, clear and shallow at its edge,
  /// with the swash running up and back at the line itself.
  void _paintWater(Canvas canvas, FieldView view) {
    final t = view.time;
    final swash =
        math.sin(t * 0.8) * (3 + 6 * swell) * _u +
        math.sin(t * 1.9 + 1) * 1.2 * _u;
    final line = _waterline + swash;
    final top = _flatTop - 3 * _u;
    if (line <= top + 1) return;
    final rect = Rect.fromLTRB(view.left - 4, top, view.right + 4, line);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, top),
          Offset(0, line),
          [
            _deep.withValues(alpha: 0.95),
            Color.lerp(_deep, _shallow, 0.6)!.withValues(alpha: 0.75),
            _shallow.withValues(alpha: 0.4),
          ],
          const [0.0, 0.75, 1.0],
        ),
    );
    // The sky lying on it in long soft bands, drifting.
    final sky = _light.skyAt(0.45);
    for (var k = 0; k < 4; k++) {
      final f = (k + 0.5) / 4;
      final y = top + (line - top) * f + math.sin(t * 0.3 + k * 2) * 1.5 * _u;
      final th = (1.5 + 3 * f) * _u;
      canvas.drawRect(
        Rect.fromLTRB(view.left - 4, y, view.right + 4, y + th),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, y),
            Offset(0, y + th),
            [
              sky.withValues(alpha: 0),
              sky.withValues(alpha: 0.22 * (1 - f * 0.5)),
              sky.withValues(alpha: 0),
            ],
            const [0.0, 0.5, 1.0],
          ),
      );
    }
    // The swash's lace at the waterline, and its glow at night.
    _foamBatch.clear();
    final step = 3 * _u;
    for (var x = view.left - (view.left % step); x < view.right; x += step) {
      final i = (x / step).round();
      final a = fieldHash(i, 811);
      final y =
          line - a * (2 + 3 * swell) * _u + math.sin(t * 2 + i * 0.7) * _u;
      _foamBatch.add(a > 0.6 ? 2 : (a > 0.25 ? 1 : 0), x + a * step, y);
      if (a > 0.85) _foamBatch.add(3, x, y - 3 * _u * a);
    }
    final glow = _night * (1 - fog * 0.6);
    final col = Color.lerp(_foam, _glow, glow * 0.8)!;
    for (var lv = 0; lv < 4; lv++) {
      _foamBatch.draw(
        canvas,
        lv,
        (1.2 + 0.25 * lv) * _u,
        col.withValues(alpha: 0.3 + 0.15 * lv),
      );
    }
    if (glow > 0.05) {
      _foamBatch
        ..draw(canvas, 2, 3.4 * _u, _glow.withValues(alpha: 0.2 * glow))
        ..draw(canvas, 3, 3.8 * _u, _glow.withValues(alpha: 0.24 * glow));
    }
  }

  // ── Pools and their anemones ─────────────────────────────────────────────

  /// When each pool was last touched.
  final Map<int, double> _poolTouched = {};
  final GrainBatch _anemoneBatch = GrainBatch(6);
  double _shelfSeen = -1;

  static const _anemoneColours = [
    Color(0xFFE86A9A),
    Color(0xFF8EE0A0),
    Color(0xFFF2A65E),
  ];

  /// The pools the tide has left: still water, and anemones in them that
  /// open in the clear water and close when touched.
  void _paintPools(Canvas canvas, FieldView view) {
    final t = view.time;
    final w = _shelfWidth;
    // Fingers: in a pool, it closes; in the water, a wake.
    for (final p in _stirsFor(shelf, view)) {
      if (p.time <= _shelfSeen) continue;
      _shelfSeen = math.max(_shelfSeen, p.time);
      var inPool = false;
      for (var i = 0; i < _pools.length; i++) {
        final s = _poolShape(i, w);
        final dx = _loopDelta(p.x, s.x, shelf) / s.hw, dy = (p.y - s.y) / s.hh;
        if (dx * dx + dy * dy < 1.6 && s.y > _waterline) {
          _poolTouched[i] = p.time;
          inPool = true;
        }
      }
      if (!inPool && p.y < _waterline && p.y > _flatTop) {
        _wake.add((p.x, p.y, p.time, p.speed < 0.5 ? 1.0 : 0.7));
        if (_wake.length > 60) _wake.removeAt(0);
      }
    }
    _anemoneBatch.clear();
    for (final shift in _shiftsFor(shelf, view, 60 * _u)) {
      for (var i = 0; i < _pools.length; i++) {
        final s = _poolShape(i, w);
        // Under the tide, the pool is just more sea.
        if (s.y - s.hh < _waterline) continue;
        final x0 = s.x + shift;
        if (x0 + s.hw < view.left || x0 - s.hw > view.right) continue;
        final touched = _poolTouched[i];
        final age = touched == null ? 99.0 : t - touched;
        // Closed while touched, opening again after.
        final open = age < 2.5
            ? 0.15
            : (0.15 + 0.85 * ((age - 2.5) / 1.5).clamp(0.0, 1.0));
        final n = 3 + i % 3;
        for (var a = 0; a < n; a++) {
          final ax = x0 + (fieldHash(a, 90 + i) - 0.5) * s.hw * 1.3;
          final ay = s.y + (fieldHash(a, 95 + i) - 0.3) * s.hh * 1.0;
          final ci = (i + a) % 3;
          const tentacles = 13;
          for (var k = 0; k < tentacles; k++) {
            final ang = -math.pi / 2 + (k / (tentacles - 1) - 0.5) * 2.2;
            final sway = math.sin(t * 1.3 + k + a * 2) * 0.15;
            for (var j = 1; j <= 4; j++) {
              final r = j * 1.1 * _u * open * (1 + 0.25 * fieldHash(k, a));
              _anemoneBatch.add(
                ci * 2 + (j == 4 ? 1 : 0),
                ax + math.cos(ang + sway) * r,
                ay + math.sin(ang + sway) * r * 0.9,
              );
            }
          }
          _anemoneBatch.add(ci * 2, ax, ay);
        }
      }
    }
    for (var c = 0; c < 3; c++) {
      final col = Color.lerp(_anemoneColours[c], _light.ambient, 0.5)!;
      _anemoneBatch
        ..draw(canvas, c * 2, 1.0 * _u, col.withValues(alpha: 0.7))
        ..draw(
          canvas,
          c * 2 + 1,
          1.6 * _u,
          Color.lerp(col, const Color(0xFFFFFFFF), 0.4)!.withValues(alpha: 0.9),
        );
    }
  }

  // ── A wake ───────────────────────────────────────────────────────────────

  /// Where a finger went through the water: (x, y, when, strength).
  final List<(double, double, double, double)> _wake = [];
  final GrainBatch _wakeBatch = GrainBatch(3);

  /// Rings spreading behind a finger in the water, and after dark the sea's
  /// own light stirred up where it went, fading.
  void _paintWake(Canvas canvas, FieldView view) {
    final t = view.time;
    _wake.removeWhere((w) => t - w.$3 > 2.5);
    if (_wake.isEmpty) return;
    _wakeBatch.clear();
    final period = _period(shelf);
    final glow = _night * (1 - fog * 0.5);
    for (final (x0, y, at, k) in _wake) {
      var x = x0;
      if (period > 0) {
        x +=
            period *
            (((view.left + view.right) / 2 - x) / period).roundToDouble();
      }
      final age = t - at;
      final r = (3 + age * 26) * _u;
      final fade = (1 - age / 2.5) * k;
      final n = (8 + r / (2.4 * _u)).clamp(8, 36).round();
      for (var i = 0; i < n; i++) {
        if (fieldHash(i, (at * 100).round()) > fade + 0.2) continue;
        final a = i / n * math.pi * 2;
        final py = y + math.sin(a) * r * 0.3;
        if (py > _waterline || py < _flatTop) continue;
        _wakeBatch.add(0, x + math.cos(a) * r, py);
      }
      if (glow > 0.05) {
        for (var i = 0; i < 6; i++) {
          final s = math.sin(t * 5 + i * 1.7 + at);
          if (s < 0) continue;
          _wakeBatch.add(
            fade > 0.5 ? 2 : 1,
            x + (fieldHash(i, (at * 31).round()) - 0.5) * 10 * _u,
            y + (fieldHash(i + 3, (at * 31).round()) - 0.5) * 4 * _u,
          );
        }
      }
    }
    _wakeBatch.draw(canvas, 0, 1.3 * _u, _foam.withValues(alpha: 0.6));
    if (glow > 0.05) {
      _wakeBatch
        ..draw(canvas, 1, 3 * _u, _glow.withValues(alpha: 0.14 * glow))
        ..draw(canvas, 1, 1.6 * _u, _glow.withValues(alpha: 0.75 * glow))
        ..draw(canvas, 2, 3.6 * _u, _glow.withValues(alpha: 0.18 * glow))
        ..draw(canvas, 2, 2.0 * _u, _glow.withValues(alpha: 0.95 * glow));
    }
  }

  // ── After a swell: shells and glass ──────────────────────────────────────

  final GrainBatch _wrackBatch = GrainBatch(3);

  /// What a swell left on the flat, wherever the tide is not over it:
  /// shells catching the light, and here and there a glass float.
  void _paintWrack(Canvas canvas, FieldView view) {
    final k = _wrack;
    if (k < 0.02) return;
    final w = _shelfWidth;
    final t = view.time;
    _wrackBatch.clear();
    final r = FieldRandom(7701);
    final floats = <Offset>[];
    for (var i = 0; i < 110; i++) {
      final x = r.next() * w;
      final f = r.next();
      final y = _flatTop + 4 * _u + f * (_h - _flatTop - 6 * _u);
      final isFloat = i % 9 == 0;
      if (y < _waterline) continue;
      for (final shift in _shiftsFor(shelf, view, 10 * _u)) {
        final px = x + shift;
        if (px < view.left - 6 || px > view.right + 6) continue;
        if (isFloat) {
          floats.add(Offset(px, y));
        } else {
          final s = math.sin(t * (1 + fieldHash(i, 3)) + i);
          _wrackBatch.add(s > 0.8 ? 2 : (i.isEven ? 0 : 1), px, y);
        }
      }
    }
    _wrackBatch
      ..draw(
        canvas,
        0,
        2.6 * _u,
        const Color(0xFFF2E6D8).withValues(alpha: 0.8 * k),
      )
      ..draw(
        canvas,
        1,
        2.2 * _u,
        const Color(0xFFE8B8A8).withValues(alpha: 0.75 * k),
      )
      ..draw(
        canvas,
        2,
        2.0 * _u,
        const Color(0xFFFFFFFF).withValues(alpha: 0.95 * k),
      );
    // Glass floats: small green-blue spheres, lit on top, a shadow under.
    for (final p in floats) {
      final rad = 5.0 * _u;
      canvas
        ..drawOval(
          Rect.fromCenter(
            center: p + Offset(0, rad * 0.8),
            width: rad * 2.6,
            height: rad * 0.8,
          ),
          Paint()..color = const Color(0xFF000000).withValues(alpha: 0.3 * k),
        )
        ..drawCircle(
          p,
          rad,
          Paint()
            ..shader = Gradient.radial(
              p - Offset(rad * 0.35, rad * 0.4),
              rad * 1.4,
              [
                const Color(0xFFCFF6EA).withValues(alpha: 0.9 * k),
                const Color(0xFF3E8C88).withValues(alpha: 0.85 * k),
                const Color(0xFF1C4A50).withValues(alpha: 0.9 * k),
              ],
              const [0.0, 0.5, 1.0],
            ),
        );
    }
  }

  // ── Spray in a swell ─────────────────────────────────────────────────────

  final GrainBatch _sprayBatch = GrainBatch(2);

  /// In a swell, spray thrown up off the shelf's columns where the sea
  /// reaches them, and the waterline lacing higher.
  void _paintSpray(Canvas canvas, FieldView view) {
    final s = swell;
    if (s < 0.05) return;
    final t = view.time;
    _sprayBatch.clear();
    for (final shift in _shiftsFor(shelf, view, 60 * _u)) {
      for (final k in _columnsOf(shelf)) {
        final x0 = k.x + shift;
        if (x0 + k.hw * 2 < view.left || x0 - k.hw * 2 > view.right) continue;
        final period = 4.2 + fieldHash(k.seed, 9) * 2;
        final ph = ((t + fieldHash(k.seed, 11) * period) / period) % 1.0;
        if (ph > 0.45) continue;
        final burst = math.sin(ph / 0.45 * math.pi);
        for (var j = 0; j < 40; j++) {
          final a = fieldHash(j, k.seed + 13);
          final b = fieldHash(j, k.seed + 17);
          final x = x0 + (a - 0.5) * k.hw * 2.4 + (a - 0.5) * 30 * _u * ph;
          final y = k.top - b * 60 * _u * burst * s + ph * ph * 30 * _u;
          _sprayBatch.add(b > 0.6 ? 1 : 0, x, y);
        }
      }
    }
    _sprayBatch
      ..draw(canvas, 0, 1.4 * _u, _foam.withValues(alpha: 0.5 * s))
      ..draw(canvas, 1, 1.8 * _u, _foam.withValues(alpha: 0.75 * s));
  }

  // ── Fog ──────────────────────────────────────────────────────────────────

  /// Sea fog: a wash over the layer, thickest at the water, and banks of it
  /// drifting through.
  void _paintFog(
    Canvas canvas,
    FieldView view,
    SceneLayer layer,
    double top,
    double bottom,
  ) {
    final f = fog;
    if (f < 0.02) return;
    final col = Color.lerp(_light.skyAt(0.55), const Color(0xFFD0D8E0), 0.3)!;
    final y0 = _h * top, y1 = _h * bottom;
    canvas.drawRect(
      Rect.fromLTRB(view.left, y0, view.right, y1),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, y0),
          Offset(0, y1),
          [
            col.withValues(alpha: 0),
            col.withValues(alpha: 0.55 * f),
            col.withValues(alpha: 0.3 * f),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
    final t = view.time;
    final p = _period(layer);
    final tiles = p > 0 ? math.max(1, (p / (360 * _u)).round()) : 0;
    final s = tiles > 0 ? p / tiles : 360 * _u;
    final k0 = ((view.left - 200 * _u) / s).floor();
    final k1 = ((view.right + 200 * _u) / s).floor();
    for (var k = k0; k <= k1; k++) {
      final kk = tiles > 0 ? k % tiles : k;
      final h0 = fieldHash(kk, 600 + layer.index);
      final ph = (h0 + t * 6 * _u / s) % 1.0;
      final c = Offset((k + ph) * s, y0 + (y1 - y0) * (0.3 + 0.5 * h0));
      final r = (120 + 80 * h0) * _u;
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 2.6, height: r * 0.7),
        Paint()
          ..shader = Gradient.radial(c, r * 1.3, [
            col.withValues(alpha: 0.32 * f * math.sin(ph * math.pi)),
            col.withValues(alpha: 0),
          ]),
      );
    }
  }

  // ── Fore ─────────────────────────────────────────────────────────────────

  List<(double, double, double)> _makeForeTops(double w) {
    final r = FieldRandom(6601);
    final out = <(double, double, double)>[];
    var x = r.range(700, 900) * _u;
    while (x < w) {
      out.add((x, r.range(40, 80) * _u, r.range(0.04, 0.09) * _h));
      x += r.range(700, 1300) * _u;
    }
    return out;
  }

  /// Kelp over the near columns' tops, long and swaying.
  _Blades _makeKelp(double w) {
    final b = _BladeBuilder();
    final r = FieldRandom(6611);
    for (final (cx, hw, ht) in _foreTops) {
      final n = 6 + (r.next() * 6).floor();
      for (var i = 0; i < n; i++) {
        final off = r.range(-1, 1) * hw;
        final x = cx + off;
        b.add(
          x: _loop ? x % w : x,
          base: _h - ht + 4 * _u,
          height: r.range(24, 60) * _u,
          lean: off / hw * 0.3 + r.range(-0.1, 0.1),
          phase: r.range(0, math.pi * 2),
          depth: 1,
          row: 0,
        );
      }
    }
    return b.done();
  }
}
