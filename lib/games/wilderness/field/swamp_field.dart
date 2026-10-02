part of 'grain_field.dart';

// The Swamp, through the day.
//
// A still bog lake in a green haze. Forest stands along the far shore in
// fog, the water holds it upside down, and bald cypresses rise out of the
// shallows on flared, fluted feet, their flat pads of leaves hung with moss.
// The creatures stand on what is solid in it — blocks of old stone, banks
// of peat with sedge on them — and the water between is water: duckweed lies
// on it in drifts, and a finger through it parts the weed and sends a
// ripple out. The light follows the phone's clock like the Valley's: a low
// sun lays a path of glitter across the lake and lights the moss, and at
// night the motes over the water are fireflies.
//
// Layers, matching the scene's spawn anchors:
//   sky     — screen-fixed (the camera backdrop): sun, moon, stars
//   layer2  — hazy cloud (drifting), the far forest, the lake to the shore
//   layer3  — cypresses back in the haze, their banks, mist on the water
//   layer4  — the great cypresses, the banks the creatures stand on, the
//             near water and its weed
//   layer5  — reeds and cattails, nearest of all
//
// The banks the creatures use are built from the spawn points: one under
// each standing creature, and one under the place each encounter's partner
// stands, so a partner that cannot float always has ground. Nothing stands
// on the water.
//
// Still sheets are baked as maps (see field_art.dart), read through the
// hour's grades:
//   far      r = haze, b = haze × how low (horizon-coloured), g = fleck
//   water    r = the sky in it, b = murk, g = light on it
//   mist     r = thinner, g = lit
//   near     r = haze, b = shade, g = fleck
//   clouds   r = underside, g = glitter

class SwampField extends _GrainField {
  SwampField();

  static const far = SceneLayer.layer2;
  static const mid = SceneLayer.layer3;
  static const near = SceneLayer.layer4;
  static const fore = SceneLayer.layer5;

  static const _gCloud = 0, _gFar = 1, _gWater = 2, _gMist = 3, _gMid = 4;
  static const _gBark = 5, _gLeaf = 6, _gMoss = 7, _gPeat = 8, _gStone = 9;
  static const _gTurf = 10, _gMud = 11;

  /// Daylight colours of the land and water; the hour's ambient light
  /// multiplies them.
  static const _albedo = <int, Color>{
    _gFar: Color(0xFF3E7A60),
    _gMid: Color(0xFF2E5A46),
    _gBark: Color(0xFF4C4832),
    _gLeaf: Color(0xFF3E6A2E),
    _gMoss: Color(0xFF7E9C5A),
    _gPeat: Color(0xFF3C3626),
    _gStone: Color(0xFF6C7A68),
    _gTurf: Color(0xFF4C7232),
    _gWater: Color(0xFF1E5648),
    _gMud: Color(0xFF868072),
  };

  /// What each of them dries to, and how far, when the Swamp has gone dry:
  /// the moss grey, the leaves yellowing, the sedge straw, the peat and
  /// stone pale, the last water muddy.
  static const _dried = <int, (Color, double)>{
    _gFar: (Color(0xFF807A62), 0.5),
    _gMid: (Color(0xFF5E5E46), 0.5),
    _gBark: (Color(0xFF6A6250), 0.5),
    _gLeaf: (Color(0xFF5E6234), 0.55),
    _gMoss: (Color(0xFFA09C88), 0.75),
    _gPeat: (Color(0xFF6A5A42), 0.6),
    _gStone: (Color(0xFF8E8C7C), 0.45),
    _gTurf: (Color(0xFF8C8048), 0.7),
    _gWater: (Color(0xFF2E3A28), 0.5),
  };

  /// Grade [g]'s daylight colour, as dry as the Swamp is.
  Color _albedoOf(int g) {
    final a = _albedo[g]!;
    final d = dry;
    final to = _dried[g];
    if (d <= 0 || to == null) return a;
    return Color.lerp(a, to.$1, to.$2 * d)!;
  }

  /// The far shore, where the lake meets the forest, as a share of the
  /// height; where the mid water and the near water start to show.
  static const _shore = 0.6, _midWater = 0.64, _nearWater = 0.76;

  /// How fast the haze above drifts, and the mist on the water, in units a
  /// second at the reference height.
  static const _cloudDrift = 2.6, _midMistDrift = 4.0, _nearMistDrift = 6.5;

  @override
  List<(double, _Light)> get _keys => _swampKeys;

  // The sun goes down behind the far forest; the wet air hides the fainter
  // stars.
  @override
  double get _horizon => 0.55;

  @override
  int get _starCount => 110;

  @override
  double get _starDepth => 0.46;

  // The wet air veils the sun to a soft brightness, and by day keeps most
  // of the motes in; at night they are all out, as fireflies. Gone dry, the
  // dust hangs in the light by day.
  @override
  double get _veil => 0.4 + 0.1 * dry;

  @override
  double get _moteShare {
    final wet = 0.22 + 0.78 * _light.firefly;
    return wet + (0.9 - wet) * dry;
  }

  // ── Gone dry ─────────────────────────────────────────────────────────────

  /// How far the Swamp has gone dry, 0 to 1 — a state it is found in, so in
  /// practice one or the other (see [WeatherKind.settled]).
  double get dry => weatherKind == WeatherKind.dry ? weather : 0;
  double get _wet => 1 - dry;

  @override
  double get _weatherKey => (dry * 1000).roundToDouble();

  /// The hour's light over the dried-out Swamp: the green haze turned to
  /// warm dust, the sedge to straw, fewer fireflies.
  @override
  _Light _weathered(_Light l) {
    final d = dry;
    if (d <= 0.001) return l;
    Color ramp(Color c, Color dark, Color light, double k) {
      final g = math.sqrt(c.computeLuminance());
      return Color.lerp(c, Color.lerp(dark, light, g)!, k * d)!;
    }

    Color dust(Color c, double k) =>
        ramp(c, const Color(0xFF1E1912), const Color(0xFFE6D6B0), k);
    final a = l.ambient;
    return _Light(
      stops: l.stops,
      sky: [for (final c in l.sky) dust(c, 0.62)],
      ambient: Color.lerp(
        a,
        Color.from(
          alpha: 1,
          red: math.min(1.0, a.r * 1.06),
          green: a.g * 0.97,
          blue: a.b * 0.82,
        ),
        d,
      )!,
      rim: Color.lerp(
        l.rim,
        Color.lerp(l.rim, const Color(0xFFFFD8A0), 0.35),
        d,
      )!,
      rimStrength: l.rimStrength * (1 + 0.15 * d),
      floor: l.floor,
      glow: l.glow,
      stars: l.stars * (1 - 0.3 * d),
      cloudTop: dust(l.cloudTop, 0.6),
      cloudBottom: dust(l.cloudBottom, 0.6),
      cloudGlint: dust(l.cloudGlint, 0.4),
      grass: [
        for (final c in l.grass)
          ramp(c, const Color(0xFF1A150C), const Color(0xFFDCC27C), 0.8),
      ],
      mote: Color.lerp(
        l.mote,
        Color.lerp(const Color(0xFFEBD9B0), const Color(0xFF8C8A80), l.firefly),
        d,
      )!,
      firefly: l.firefly * (1 - 0.7 * d),
    );
  }

  /// Only some of the glints the light sheets lay down are kept: in this
  /// much leaf and moss, all of them read as glitter.
  @override
  void _glint(double x, double y) {
    if (fieldHash(_glintSeen++, 977) < 0.16) super._glint(x, y);
  }

  int _glintSeen = 0;

  @override
  double _lightK(SceneLayer layer) => switch (layer) {
    far => 1.0,
    mid => 0.9,
    _ => 0.85,
  };

  @override
  void _buildGrades(_Light l) {
    final hazeHigh = l.skyAt(0.44), hazeLow = l.skyAt(0.585);
    Color sil(int g) {
      final a = _albedoOf(g);
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
    (double, double, double) lit(double k) => (
      l.rim.r * l.rimStrength * k,
      l.rim.g * l.rimStrength * k,
      l.rim.b * l.rimStrength * k,
    );

    final f = sil(_gFar);
    _grades[_gFar] = fieldGrade(
      base: f,
      r: fieldDiff(hazeHigh, f),
      g: fleck(f, 0.3),
      b: fieldDiff(hazeLow, hazeHigh),
    );
    for (final g in [
      _gMid,
      _gBark,
      _gLeaf,
      _gMoss,
      _gPeat,
      _gStone,
      _gTurf,
      _gMud,
    ]) {
      final s = sil(g);
      _grades[g] = fieldGrade(
        base: s,
        r: fieldDiff(hazeLow, s),
        g: fleck(s, 0.4),
        b: fieldScale(s, -0.72),
      );
    }
    final w = sil(_gWater);
    _grades[_gWater] = fieldGrade(
      base: w,
      r: fieldDiff(l.skyAt(0.47), w),
      g: lit(0.6),
      b: fieldScale(w, -0.8),
    );
    final mist = Color.lerp(hazeLow, const Color(0xFFFFFFFF), 0.12)!;
    _grades[_gMist] = fieldGrade(
      base: mist,
      r: fieldDiff(hazeHigh, mist),
      g: lit(0.55),
      b: (0, 0, 0),
    );
    _grades[_gCloud] = fieldGrade(
      base: l.cloudTop,
      r: fieldDiff(l.cloudBottom, l.cloudTop),
      g: fieldScale(l.cloudGlint, 0.85),
      b: (0, 0, 0),
    );
  }

  // ── Where the creatures stand ────────────────────────────────────────────

  /// The banks of the mid and near layers, as built for this screen.
  final Map<SceneLayer, List<_Bank>> _banks = {};

  /// Every standing point on the near and mid layers stands on its own
  /// bank, seated by the creature's feet.
  @override
  double? perchFor(String spawnId) {
    for (final p in _spawns) {
      if (p.id != spawnId || p.aloft) continue;
      if (p.anchor == near || p.anchor == mid) return _feet(p);
    }
    return null;
  }

  /// The bank over [x] on [layer], and [x] moved into that bank's own loop.
  (_Bank, double)? _bankAt(SceneLayer layer, double x, {double reach = 1}) {
    for (final b in _banks[layer] ?? const <_Bank>[]) {
      final d = _loopDelta(x, b.cx, layer);
      if (d.abs() < b.hw * reach) return (b, b.cx + d);
    }
    return null;
  }

  // On a bank there is no deeper ground to stand in, and off one there is
  // only water: anything over a bank that cannot float is stood on its top.
  // When the Swamp has gone dry the floor between is ground as well.
  @override
  ({double top, double rest})? groundAt(SceneLayer layer, double x) {
    final at = _bankAt(layer, x, reach: 0.86);
    if (at != null) {
      final (b, lx) = at;
      return (top: double.infinity, rest: _bStand(b, lx) + 1 * _u);
    }
    // Gone dry, the floor is ground too — all but the last pools.
    if (dry < 0.5 || (layer != near && layer != mid)) return null;
    final (top, rest) = layer == near ? (0.79, 0.86) : (0.672, 0.71);
    for (final p in _pools[layer] ?? const <_Pool>[]) {
      if (_inPoolOf(p, x, p.$2, layer, grow: 1.1)) return null;
    }
    return (top: _h * top, rest: _h * rest);
  }

  /// The grass on a near bank a finger at [x], [y] is in, if any.
  double? _inGrass(double x, double y) {
    final at = _bankAt(near, x, reach: 0.97);
    if (at == null) return null;
    final (b, lx) = at;
    final back = _bBack(b, lx);
    if (y < back - 30 * _u || y > _bFront(b, lx) + 10 * _u) return null;
    return back;
  }

  /// Whether a finger at [x], [y] on the near layer is in open water.
  bool _onWater(double x, double y) {
    if (y < _h * (_nearWater + 0.02)) return false;
    final at = _bankAt(near, x, reach: 1.02);
    if (at == null) return true;
    return y > _bWater(at.$1) + 2 * _u;
  }

  /// The banks on [layer] as built: each one's span, from the top of its
  /// back to the water at its foot.
  @visibleForTesting
  List<Rect> debugBanks(SceneLayer layer) => [
    for (final b in _banks[layer] ?? const <_Bank>[])
      Rect.fromLTRB(
        b.cx - b.hw - b.flare,
        _bBack(b, b.cx),
        b.cx + b.hw + b.flare,
        _bWater(b),
      ),
  ];

  /// Banks nobody stands on: (x as a share of the loop, its top as a share
  /// of the height, half width, a stone).
  static const _midScenery = <(double, double, double, bool)>[
    (0.07, 0.655, 34, false),
    (0.43, 0.65, 30, true),
  ];

  List<_Bank> _makeBanks(SceneLayer layer) {
    final back = layer == mid;
    final banks = <_Bank>[];
    var seed = back ? 300 : 200;
    final k = back ? 0.62 : 1.0;
    _Bank bank(
      double cx,
      double hw,
      double stand, {
      double? seatX,
      bool stone = false,
      int steps = 0,
    }) {
      final s = seed++;
      final r = FieldRandom(s * 13);
      final b = _Bank(
        cx: cx,
        hw: hw,
        plate: (stone ? 14 : 12) * k * _u,
        rise: (stone ? r.range(32, 40) : r.range(13, 18)) * k * _u,
        flare: stone ? hw * r.range(0.06, 0.12) : 0,
        seed: s,
        haze: back ? 0.3 : 0.0,
        stone: stone,
        steps: steps,
      );
      // Seat it so feet at [seatX] stand at [stand].
      b.level = stand - _bStand(b, seatX ?? cx);
      return b;
    }

    // Ground points in x order on the layer stand on stone and peat by
    // turns, and each one's partner on the other. A point in a pool has
    // no bank: it is in the water, its partner on the dry floor.
    final points =
        _spawns
            .where((p) => p.anchor == layer && p.perch != SpawnPerch.wade)
            .toList()
          ..sort((a, b) => _spawnX(a).compareTo(_spawnX(b)));
    var ground = 0;
    for (final p in points) {
      final x = _spawnX(p);
      final side = p.partnerSide;
      final px = x + side * kFieldPairGap;
      final bp = p.getBattlePos();
      final size = p.size.x;
      final stone = !p.aloft && ground++ % 2 == 0;
      // Banks under creatures are sized by the creatures, not the screen:
      // the pace between a pair is the same on every screen.
      if (!p.aloft) {
        final hw = size * (stone ? 1.0 : 1.2);
        banks.add(
          bank(
            x + side * hw * 0.15,
            hw,
            _feet(p),
            seatX: x,
            stone: stone,
            // A stone steps down on the side away from its partner.
            steps: stone ? -side.round() : 0,
          ),
        );
      }
      // Under where its encounter partner stands.
      if (!_partners) continue;
      final hw = size * (stone ? 0.85 : 0.75);
      banks.add(
        bank(
          px + side * hw * 0.1,
          hw,
          bp.dy * _h + size * 0.5,
          seatX: px,
          stone: !stone && !p.aloft,
        ),
      );
    }
    if (back) {
      final w = _widths[layer] ?? _worldWidth;
      for (final (fx, fy, fhw, stone) in _midScenery) {
        banks.add(bank(fx * w, fhw * _u, fy * _h, stone: stone));
      }
    }
    return banks;
  }

  // ── A bank's shape (layer-local units) ───────────────────────────────────

  double _bt(_Bank b, double x) => ((x - b.cx) / b.hw).clamp(-1.0, 1.0);

  /// The water at a bank's foot.
  double _bWater(_Bank b) => b.level + b.plate * 0.45 + b.rise;

  /// Where feet stand on [b] at [x]. A stone is flat, stepping down at one
  /// end; a peat bank crowns gently and slopes away into the water at its
  /// ends.
  double _bStand(_Bank b, double x) {
    final t = _bt(b, x);
    if (b.stone) {
      var y = b.level;
      if (b.steps != 0) {
        final s = t * b.steps;
        if (s > 0.6) y += b.rise * 0.2;
        if (s > 0.8) y += b.rise * 0.2;
      }
      return y;
    }
    return b.level +
        (b.rise + b.plate * 0.45) * math.pow(t.abs(), 3.4) +
        b.plate * 0.14 * fieldNoise(x / (22 * _u), b.seed);
  }

  double _bPinch(_Bank b, double x) =>
      (1 - math.pow(_bt(b, x).abs(), b.stone ? 8 : 5)).toDouble();

  /// The back of its top, against what is behind it — on a stone, worn
  /// uneven.
  double _bBack(_Bank b, double x) {
    final wear = b.stone
        ? 0.8 + 0.4 * (fieldNoise(x / (13 * _u), b.seed + 4) * 0.5 + 0.5)
        : 1.0;
    return _bStand(b, x) - b.plate * 0.55 * _bPinch(b, x) * wear;
  }

  /// The front lip of its top, where the face drops to the water.
  double _bFront(_Bank b, double x) =>
      _bStand(b, x) + b.plate * 0.45 * _bPinch(b, x);

  Rect _bankBounds(_Bank b) => Rect.fromLTRB(
    b.cx - b.hw - b.flare - 16 * _u,
    _bBack(b, b.cx) - 34 * _u,
    b.cx + b.hw + b.flare + 16 * _u,
    _bWater(b) + 34 * _u,
  );

  // ── Layout for the current screen ────────────────────────────────────────

  final Map<SceneLayer, List<_Cypress>> _trees = {};
  _Blades? _nearBlades;
  _Blades? _reeds;
  _Weed? _weed;
  _Motes? _motes;
  double _nearWidth = 0;
  double _foreWidth = 0;
  final _Drift _drops = _Drift(160);
  final GrainBatch _weedBatch = GrainBatch(8);
  final GrainBatch _headBatch = GrainBatch(2);
  final GrainBatch _rippleBatch = GrainBatch(3);

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
        final trees = _trees[far] = _farTrees(w);
        final forest = Rect.fromLTWH(0, _h * 0.26, w, _h * (_shore - 0.25));
        final water = Rect.fromLTWH(0, _h * (_shore - 0.012), w, _h * 0.42);
        return [
          FieldSheet(
            bounds: Rect.fromLTWH(0, 0, w, _h * 0.44),
            drift: _cloudDrift * _u,
            resolution: 0.5,
            grade: _gCloud,
            paint: (c) => _paintClouds(c, w),
          ),
          FieldSheet(
            bounds: water,
            resolution: 0.7,
            grade: _gWater,
            paint: (c) => _paintLake(c, w, trees),
          ),
          FieldSheet(
            bounds: water,
            resolution: 0.8,
            light: true,
            paint: (c) => _paintRipples(c, w, far),
          ),
          FieldSheet(
            bounds: forest,
            resolution: 0.7,
            grade: _gFar,
            paint: (c) => _paintFarForest(c, w, 0),
          ),
          FieldSheet(
            bounds: forest,
            resolution: 0.7,
            grade: _gMid,
            paint: (c) {
              for (final t in trees) {
                _wrapped(t.x, t.reach, w, (x) => _cypress(c, t.at(x), null));
              }
            },
          ),
          FieldSheet(
            bounds: forest,
            resolution: 0.7,
            grade: _gFar,
            paint: (c) => _paintFarForest(c, w, 1),
          ),
          FieldSheet(
            bounds: forest,
            resolution: 0.6,
            light: true,
            paint: (c) => _sinking(far, () {
              _paintFarLight(c, w);
              final sparks = GrainBatch(_sparkAlpha.length);
              for (final t in trees) {
                _wrapped(
                  t.x,
                  t.reach,
                  w,
                  (x) => _cypress(_NullCanvas(), t.at(x), sparks),
                );
              }
              _drawSparks(c, sparks, 1.1);
            }),
          ),
        ];
      case mid:
        _glints[mid] = _Glints();
        final banks = _banks[mid] = _makeBanks(mid);
        final trees = _trees[mid] = _midTrees(w);
        final grove = Rect.fromLTWH(0, _h * 0.2, w, _h * 0.52);
        final water = Rect.fromLTWH(0, _h * (_midWater - 0.02), w, _h * 0.32);
        _waterGlints[mid] = _Glints();
        _pools[mid] = _makePools(mid, w, banks);
        final bed = Rect.fromLTRB(0, _h * (_dryShore - 0.006), w, _h * 0.83);
        return [
          FieldSheet(
            bounds: water,
            resolution: 0.7,
            grade: _gWater,
            opacity: () => _wet,
            paint: (c) => _paintReflections(c, w, mid, trees, banks),
          ),
          FieldSheet(
            bounds: water,
            resolution: 0.8,
            light: true,
            opacity: () => _wet,
            paint: (c) => _sinkingInto(
              _waterGlints[mid],
              w,
              () => _paintRipples(c, w, mid),
            ),
          ),
          ..._drySheets(mid, w, trees, banks, bed),
          FieldSheet(
            bounds: grove,
            resolution: 0.8,
            grade: _gMid,
            paint: (c) {
              for (final t in trees) {
                _wrapped(t.x, t.reach, w, (x) => _cypress(c, t.at(x), null));
              }
            },
          ),
          FieldSheet(
            bounds: grove,
            resolution: 0.7,
            light: true,
            paint: (c) => _sinking(mid, () {
              final sparks = GrainBatch(_sparkAlpha.length);
              for (final t in trees) {
                _wrapped(
                  t.x,
                  t.reach,
                  w,
                  (x) => _cypress(_NullCanvas(), t.at(x), sparks),
                );
              }
              _drawSparks(c, sparks, 1.25);
            }),
          ),
          FieldSheet(
            bounds: Rect.fromLTWH(0, _h * 0.56, w, _h * 0.2),
            drift: _midMistDrift * _u,
            resolution: 0.45,
            grade: _gMist,
            paint: (c) => _paintMist(c, w, _h * 0.66, 0.42, seed: 61),
          ),
          // The back banks, all of them on each sheet.
          ..._mergedBankSheets(mid, w, banks),
        ];
      case near:
        _glints[near] = _Glints();
        _nearWidth = w;
        final banks = _banks[near] = _makeBanks(near);
        final trees = _trees[near] = _greatTrees(w);
        _nearBlades = _bankGrass(banks);
        _weed = _makeWeed(w, banks, trees);
        _motes = _swampMotes(w);
        final water = Rect.fromLTWH(0, _h * (_nearWater - 0.03), w, _h * 0.28);
        _waterGlints[near] = _Glints();
        _pools[near] = _makePools(near, w, banks);
        final bed = Rect.fromLTRB(0, _h * 0.755, w, _h + 6 * _u);
        return [
          FieldSheet(
            bounds: water,
            resolution: 0.8,
            grade: _gWater,
            opacity: () => _wet,
            paint: (c) => _paintReflections(c, w, near, trees, banks),
          ),
          FieldSheet(
            bounds: water,
            resolution: 0.9,
            light: true,
            opacity: () => _wet,
            paint: (c) => _sinkingInto(
              _waterGlints[near],
              w,
              () => _paintRipples(c, w, near),
            ),
          ),
          ..._drySheets(near, w, trees, banks, bed),
          for (final t in trees) ..._treeSheets(t),
          FieldSheet(
            bounds: Rect.fromLTWH(0, _h * 0.68, w, _h * 0.22),
            drift: _nearMistDrift * _u,
            resolution: 0.45,
            grade: _gMist,
            paint: (c) => _paintMist(c, w, _h * 0.79, 0.26, seed: 71),
          ),
          for (final b in banks) ..._bankSheets(near, b),
        ];
      case fore:
        _foreWidth = w;
        _reeds = _foreReeds(w);
        return const [];
      default:
        return const [];
    }
  }

  @override
  bool hasLive(SceneLayer layer, {required bool front}) => switch (layer) {
    near || mid => true,
    fore => !front,
    _ => false,
  };

  // ── Far: the haze, the forest, the lake ──────────────────────────────────

  /// The lake's colour where its maps read [sky] (the sky in it) and
  /// [murk], as the water grade would make it.
  Color _lakeAt(double sky, double murk) {
    final l = _light, a = _albedoOf(_gWater);
    final from = l.skyAt(0.47);
    double ch(double base, double s) =>
        (base + sky * (s - base) - murk * 0.8 * base).clamp(0.0, 1.0);
    return Color.from(
      alpha: 1,
      red: ch(a.r * l.ambient.r, from.r),
      green: ch(a.g * l.ambient.g, from.g),
      blue: ch(a.b * l.ambient.b, from.b),
    );
  }

  /// The lake again, under everything, fixed to the screen: where two
  /// copies of a looping sheet meet, what shows between them is water, not
  /// the sky.
  @override
  void paintSky(Canvas canvas, Size screen, FieldView view) {
    super.paintSky(canvas, screen, view);
    final top = view.screenY(_h * _shore), bottom = view.screenY(_h);
    canvas.drawRect(
      Rect.fromLTRB(0, top, screen.width, screen.height),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, top),
          Offset(0, bottom),
          [
            _lakeAt(1, 0.04),
            _lakeAt(0.7, 0.16),
            _lakeAt(0.34, 0.38),
            _lakeAt(0.12, 0.62),
          ],
          const [0.0, 0.18, 0.5, 1.0],
        ),
    );
    // Gone dry, the floor is what shows between the copies instead.
    final d = dry;
    if (d <= 0.004) return;
    final bed = view.screenY(_h * _dryShore);
    canvas.drawRect(
      Rect.fromLTRB(0, bed, screen.width, screen.height),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, bed),
          Offset(0, bottom),
          [
            _mudAt(_mudHaze(_h * _dryShore), 0.5).withValues(alpha: d),
            _mudAt(_mudHaze(_h * 0.75), 0.55).withValues(alpha: d),
            _mudAt(0, 0.62).withValues(alpha: d),
          ],
          const [0.0, 0.4, 1.0],
        ),
    );
  }

  double _nf(double x, double wave, int seed) =>
      fieldLoopNoise(x, wave, seed, _period(far));

  /// Haze drifting over the swamp: long soft lenses of cloud, lit on top
  /// and dimmer beneath, wrapping round the sheet so it can drift for ever.
  void _paintClouds(Canvas c, double w) {
    final r = FieldRandom(131);
    final banks = math.max(4, (w / (300 * _u)).round());
    for (var b = 0; b < banks; b++) {
      final cx = (b + r.range(0.15, 0.85)) * w / banks;
      final cy = _h * r.range(0.07, 0.36);
      final low = ((cy / _h - 0.07) / 0.29).clamp(0.0, 1.0);
      final rx = r.range(110, 230) * _u * (0.8 + 0.6 * low);
      final ry = rx * r.range(0.07, 0.11);
      final a = r.range(0.35, 0.6) * (1 - 0.3 * low);
      final lobes = [
        for (var k = 0; k < 3; k++)
          (
            r.range(-0.35, 0.35) * rx,
            r.range(-0.5, 0.3) * ry,
            rx * r.range(0.45, 0.75),
            ry * r.range(0.8, 1.3),
          ),
      ];
      for (final dx in [-w, 0.0, w]) {
        if (cx + dx + rx * 1.4 < 0 || cx + dx - rx * 1.4 > w) continue;
        // The body, then a dimmer underside a little below it.
        for (final (oy, under, k) in [(0.0, 0.1, 1.0), (0.45, 0.75, 0.55)]) {
          for (final (lx, ly, lrx, lry) in lobes) {
            _lens(
              c,
              cx + dx + lx,
              cy + ly + oy * lry,
              lrx,
              lry,
              fieldMap(under, 0, 0, a * k),
              fieldMap(under + 0.15, 0, 0, 0),
            );
          }
        }
      }
    }
  }

  /// A soft lens: an oval of [inner] fading out to [outer] at its edge.
  void _lens(
    Canvas c,
    double cx,
    double cy,
    double rx,
    double ry,
    Color inner,
    Color outer,
  ) {
    c
      ..save()
      ..translate(cx, cy)
      ..scale(rx / ry, 1)
      ..drawCircle(
        Offset.zero,
        ry,
        Paint()
          ..shader = Gradient.radial(
            Offset.zero,
            ry,
            [inner, Color.lerp(inner, outer, 0.55)!, outer],
            const [0.0, 0.5, 1.0],
          ),
      )
      ..restore();
  }

  /// The far forest's canopy, rank 0 the further: crowns rounded on top,
  /// pinched between, all of it rolling slowly along the shore.
  double _canopy(int rank, double x) {
    final base = _h * (rank == 0 ? 0.52 : 0.592);
    final roll = _nf(x, 300, 21 + rank) * 0.5 + 0.5;
    final crowns = math.pow(
      _nf(x, (rank == 0 ? 38 : 22) * _u, 23 + rank).abs(),
      0.6,
    );
    final leaves = math.pow(_nf(x, 8 * _u, 25 + rank).abs(), 0.8);
    return base -
        _h * (rank == 0 ? 0.1 : 0.02) * (0.25 + 0.75 * roll) -
        _h * (rank == 0 ? 0.035 : 0.009) * crowns * (0.6 + 0.8 * roll) -
        1.8 * _u * leaves;
  }

  /// Cypresses standing along the far shore, between the two ranks of the
  /// forest: deep in the haze, they are only shapes.
  List<_Cypress> _farTrees(double w) {
    final r = FieldRandom(505);
    final trees = <_Cypress>[];
    var x = r.range(10, 60) * _u;
    var i = 0;
    while (x < w - 20 * _u) {
      final h = _h * r.range(0.17, 0.27);
      trees.add(_Cypress(x, _h * r.range(0.596, 0.604), h, 5100 + i++, 0.66));
      x += r.range(70, 190) * _u;
    }
    for (final t in trees) {
      _shapeCypress(t);
    }
    return trees;
  }

  void _paintFarForest(Canvas c, double w, int rank) {
    double ridge(double x) => _canopy(rank, x);
    final crest = _h * (rank == 0 ? 0.4 : 0.55);
    final (rc, rf) = rank == 0 ? (0.86, 0.96) : (0.6, 0.84);
    final lowC = rank == 0 ? 0.2 : 0.5;
    _fillRidge(
      c,
      w,
      ridge,
      Paint()
        ..shader = Gradient.linear(Offset(0, crest), Offset(0, _h * _shore), [
          fieldMap(rc, 0, rc * lowC),
          fieldMap(rf, 0, rf),
        ]),
      bottom: _h * _shore + 2 * _u,
      step: 2 * _u,
    );
    _mistBand(
      c,
      w,
      _h * (rank == 0 ? 0.46 : 0.56),
      _h * (_shore + 0.012),
      rank == 0 ? 0.34 : 0.4,
    );
  }

  void _paintFarLight(Canvas c, double w) {
    _rimBands(c, w, (x) => _canopy(0, x), [(4.0, 0.12), (12.0, 0.06)]);
    _rimBands(c, w, (x) => _canopy(1, x), [(3.0, 0.18), (8.0, 0.08)]);
  }

  /// The lake: the sky in it toward the far shore, murkier coming nearer,
  /// with breaths of wind dulling it in bands, and the far forest standing
  /// in it upside down.
  void _paintLake(Canvas c, double w, List<_Cypress> trees) {
    final top = _h * _shore;
    c.drawRect(
      Rect.fromLTRB(-4, top - 6 * _u, w + 4, _h + 4),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, top),
          Offset(0, _h),
          [
            fieldMap(1, 0, 0.04),
            fieldMap(0.7, 0, 0.16),
            fieldMap(0.34, 0, 0.38),
            fieldMap(0.12, 0, 0.62),
          ],
          const [0.0, 0.18, 0.5, 1.0],
        ),
    );
    for (final (y0, y1, a) in const [
      (0.606, 0.622, 0.3),
      (0.655, 0.682, 0.16),
      (0.72, 0.76, 0.12),
      (0.84, 0.9, 0.08),
    ]) {
      c.drawRect(
        Rect.fromLTRB(-4, _h * y0, w + 4, _h * y1),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, _h * y0),
            Offset(0, _h * y1),
            [fieldMap(1, 0, 0, 0), fieldMap(1, 0, 0, a), fieldMap(1, 0, 0, 0)],
            const [0.0, 0.5, 1.0],
          ),
      );
    }
    // The far forest, upside down, the nearer rank the darker.
    for (var rank = 0; rank < 2; rank++) {
      final path = Path()..moveTo(-4, top);
      for (var x = -4.0; x <= w + 4; x += 2.5 * _u) {
        path.lineTo(x, top + (top - _canopy(rank, x)) * 0.62);
      }
      path
        ..lineTo(w + 4, top)
        ..close();
      final depth = (top - _h * 0.44) * 0.62;
      c.drawPath(
        path,
        Paint()
          ..shader = Gradient.linear(Offset(0, top), Offset(0, top + depth), [
            fieldMap(0.78 - rank * 0.16, 0, 0.1 + rank * 0.08, 0.85),
            fieldMap(0.8, 0, 0.1, 0),
          ]),
      );
    }
    _paintReflections(c, w, far, trees, const []);
  }

  /// Light on the water, for a light sheet: short dashes of grains where
  /// the surface tips toward the light, fine and close toward the far shore,
  /// longer nearer. Under a low sun they are the path of glitter across the
  /// lake.
  void _paintRipples(Canvas c, double w, SceneLayer layer) {
    final (top, bottom, size, density, seed) = switch (layer) {
      far => (_h * (_shore + 0.004), _h * 0.7, 1.1, 0.7, 51),
      mid => (_h * _midWater, _h * 0.84, 1.35, 0.2, 53),
      _ => (_h * _nearWater, _h * 1.0, 1.7, 0.09, 55),
    };
    final sparks = GrainBatch(_sparkAlpha.length);
    final r = FieldRandom(seed);
    final n = (w * (bottom - top) * density / (_u * _u * 26)).round();
    for (var i = 0; i < n; i++) {
      final x = r.next() * w;
      final f = math.pow(r.next(), layer == far ? 1.4 : 1.0).toDouble();
      final y = top + f * (bottom - top);
      final len = 2 + (r.next() * (3 + f * 4)).floor();
      final gap = size * _u * (0.85 + f * 0.6);
      final strength =
          math.pow(r.next(), 1.6) * (layer == far ? 1.0 - 0.5 * f : 0.85);
      for (var k = 0; k < len; k++) {
        final centre = 1 - ((k - (len - 1) / 2).abs() / (len / 2 + 0.5));
        final lv = (centre * strength * 3.6 - 0.4).floor();
        if (lv < 0) continue;
        var gx = x + (k - (len - 1) / 2) * gap;
        gx -= w * (gx / w).floorToDouble();
        sparks.add(lv.clamp(0, 3), gx, y);
      }
      if (r.next() < (layer == far ? 0.012 : 0.02)) _glint(x, y);
    }
    _drawSparks(c, sparks, size);
  }

  // ── Mid: cypresses back in the haze ──────────────────────────────────────

  List<_Cypress> _midTrees(double w) {
    final r = FieldRandom(707);
    final trees = <_Cypress>[];
    var x = r.range(20, 80) * _u;
    var i = 0;
    while (x < w - 40 * _u) {
      final h = _h * r.range(0.3, 0.42);
      final base = _h * r.range(0.645, 0.665);
      trees.add(_Cypress(x, base, h, 7100 + i++, 0.36));
      x += r.range(150, 320) * _u;
    }
    for (final t in trees) {
      _shapeCypress(t);
    }
    return trees;
  }

  // ── Near: the great cypresses ────────────────────────────────────────────

  List<_Cypress> _greatTrees(double w) {
    final trees = <_Cypress>[
      for (final (x, s, seed) in const [
        (690.0, 1.0, 1),
        (1500.0, 0.9, 2),
        (2262.0, 0.96, 3),
      ])
        if (x < w)
          _Cypress(x, _h * (0.79 - 0.01 * seed), _h * 0.98 * s, 8100 + seed, 0),
    ];
    for (final t in trees) {
      _shapeCypress(t);
    }
    return trees;
  }

  List<FieldSheet> _treeSheets(_Cypress t) {
    final b = Rect.fromLTRB(
      t.x - t.reach,
      math.max(-2 * _u, t.top - 16 * _u),
      t.x + t.reach,
      t.base + 22 * _u,
    );
    return [
      FieldSheet(
        bounds: b,
        grade: _gBark,
        paint: (c) => _cypress(c, t, null, part: _Part.bark),
      ),
      FieldSheet(
        bounds: b,
        grade: _gLeaf,
        paint: (c) => _cypress(c, t, null, part: _Part.leaf),
      ),
      FieldSheet(
        bounds: b,
        grade: _gMoss,
        paint: (c) => _cypress(c, t, null, part: _Part.moss),
      ),
      FieldSheet(
        bounds: b,
        light: true,
        paint: (c) => _sinking(near, () {
          final sparks = GrainBatch(_sparkAlpha.length);
          _cypress(_NullCanvas(), t, sparks);
          _drawSparks(c, sparks, 1.5);
        }),
      ),
    ];
  }

  /// Lays out a cypress from its seed: its outline from the flared foot up,
  /// its limbs and their pads of leaves, the moss off them, and the knees
  /// standing round it in the water.
  void _shapeCypress(_Cypress t) {
    final r = FieldRandom(t.seed);
    final h = t.h;
    final s = h / (_h * 0.98);
    final lean = r.range(-0.07, 0.07);
    final wb = h * r.range(t.haze > 0 ? 0.27 : 0.32, t.haze > 0 ? 0.33 : 0.38);
    final wt = h * r.range(0.052, 0.064);
    const top = 0.86, foot = 0.24;
    Offset spine(double f) => Offset(
      t.x + lean * h * f * f + h * 0.014 * math.sin(f * 5.2 + t.seed),
      t.base - f * h,
    );
    double half(double f) {
      if (f < foot) {
        final k = 1 - f / foot;
        return wt / 2 + (wb / 2 - wt / 2) * math.pow(k, 2.6);
      }
      return wt / 2 * (1 - 0.42 * ((f - foot) / (top - foot)));
    }

    t
      ..spine = spine
      ..half = half
      ..topF = top
      ..footF = foot
      ..wb = wb;
    final left = <Offset>[], right = <Offset>[];
    const n = 30;
    for (var k = 0; k <= n; k++) {
      final f = top * math.pow(k / n, 1.4);
      final p = spine(f);
      final hw = half(f);
      final bulge = 1 + 0.07 * fieldNoise(f * 16, t.seed + 1);
      left.add(Offset(p.dx - hw * bulge, p.dy));
      right.add(Offset(p.dx + hw * (2 - bulge), p.dy));
    }
    // The foot's own flare and fluting are its roots; nothing sticks out.
    t.outline = [...left, ...right.reversed];

    // Grooves fluting the foot, each running up into the trunk.
    t.flutes = [
      for (var k = 0, m = 5 + (r.next() * 4).floor(); k < m; k++)
        (r.range(-0.8, 0.8), r.range(0.12, 0.4), r.range(0.5, 1.0)),
    ];

    // Limbs held out flat, rising a little, and pads of leaves crowded
    // along the outer half of each, so the crown is a broad layered mass.
    final limbs = <(Offset, Offset, double)>[];
    final pads = <(Offset, double, double)>[];
    final m = 4 + (r.next() * 3).floor();
    var side = r.next() < 0.5 ? -1.0 : 1.0;
    for (var k = 0; k < m; k++) {
      final f = 0.52 + 0.32 * (k + r.range(0, 0.6)) / m;
      final from = spine(f);
      final len = h * r.range(0.14, 0.27) * (1.1 - 0.5 * (f - 0.5));
      final a = r.range(0.1, 0.45);
      final to = from + Offset(side * math.cos(a) * len, -math.sin(a) * len);
      limbs.add((from, to, wt * r.range(0.32, 0.46)));
      final n = 2 + (r.next() * 2).floor();
      for (var j = 0; j < n; j++) {
        final q = j == 0 ? 1.0 : r.range(0.45, 0.85);
        final rx = h * r.range(0.07, 0.11) * (j == 0 ? 1.15 : 0.85);
        final at = Offset.lerp(from, to, q)!;
        pads.add((
          at + Offset(side * rx * r.range(0.0, 0.35), -rx * r.range(0.12, 0.3)),
          rx,
          rx * r.range(0.3, 0.4),
        ));
      }
      side = -side;
    }
    final crown = spine(top);
    for (var j = 0; j < 4; j++) {
      final rx = h * r.range(0.08, 0.13);
      pads.add((
        crown + Offset(h * r.range(-0.1, 0.1), -h * r.range(0.0, 0.07)),
        rx,
        rx * r.range(0.32, 0.42),
      ));
    }
    t
      ..limbs = limbs
      ..pads = pads;

    // Moss off the pads and limbs, in curtains, longest where it hangs from
    // the middle of a pad.
    final moss = <(double, double, double, double, double, double)>[];
    for (final (o, rx, ry) in pads) {
      final count = (rx / (1.8 * _u)).round();
      for (var k = 0; k < count; k++) {
        final q = r.range(-0.88, 0.88);
        final under = math.sqrt(math.max(0.0, 1 - q * q));
        final x = o.dx + q * rx;
        final y = o.dy + ry * (0.2 + 0.55 * under);
        final len =
            h * (0.04 + 0.2 * math.pow(r.next(), 1.5)) * (0.4 + 0.6 * under);
        final width = math.max(1.8 * _u, r.range(3.0, 5.6) * _u * s);
        moss.add((x, y, len, width, r.range(-1, 1), r.next()));
      }
    }
    for (final (from, to, _) in limbs) {
      for (var k = 0; k < 4; k++) {
        final p = Offset.lerp(from, to, r.range(0.25, 0.9))!;
        moss.add((
          p.dx,
          p.dy + 1.5 * _u,
          h * r.range(0.03, 0.11),
          math.max(1.6 * _u, r.range(2.6, 4.4) * _u * s),
          r.range(-1, 1),
          r.next(),
        ));
      }
    }
    t.moss = moss;

    // Knees: little stumps of root standing up out of the water round it.
    t.knees = [
      for (var k = 0, kn = 2 + (r.next() * 3).floor(); k < kn; k++)
        (
          t.x + (r.next() < 0.5 ? -1 : 1) * wb * r.range(0.75, 1.5),
          t.base + r.range(-2, 7) * _u * s,
          r.range(5, 11) * _u * s,
          r.range(5, 8) * _u * s,
        ),
    ];
    var reach = wb * 1.6;
    for (final (o, rx, _) in pads) {
      reach = math.max(reach, (o.dx - t.x).abs() + rx * 1.15);
    }
    t
      ..reach = reach + 12 * _u
      ..top = pads.fold(t.base, (m, p) => math.min(m, p.$1.dy - p.$3 * 1.4));
  }

  /// Paints a cypress: its [part] as maps (all of it, on a mid tree, which
  /// is one grade) — or with [sparks], the light on it.
  void _cypress(Canvas c, _Cypress t, GrainBatch? sparks, {_Part? part}) {
    final haze = t.haze;
    final s = t.h / (_h * 0.98);
    final all = part == null && sparks == null;
    if (sparks != null) {
      _cypressLight(t, sparks);
      return;
    }
    if (all || part == _Part.bark) {
      final bark = Paint()..color = fieldMap(haze, 0, 0.5);
      // Knees behind the foot, then the limbs, then the trunk.
      for (final k in t.knees) {
        if (k.$2 < t.base) _knee(c, k, bark, haze);
      }
      for (final (from, to, wr) in t.limbs) {
        final d = to - from;
        final nrm = Offset(-d.dy, d.dx) / d.distance;
        final mid = Offset.lerp(from, to, 0.5)! + Offset(0, -t.h * 0.012);
        c.drawPath(
          Path()
            ..moveTo(from.dx + nrm.dx * wr, from.dy + nrm.dy * wr)
            ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy)
            ..quadraticBezierTo(
              mid.dx,
              mid.dy + wr * 0.6,
              from.dx - nrm.dx * wr,
              from.dy - nrm.dy * wr,
            )
            ..close(),
          Paint()..color = fieldMap(haze, 0, 0.58),
        );
      }
      final body = Path()..addPolygon(t.outline, true);
      c.drawPath(
        body,
        Paint()
          ..shader = Gradient.linear(
            Offset(t.x - t.wb, 0),
            Offset(t.x + t.wb, 0),
            [
              fieldMap(haze, 0, 0.5),
              fieldMap(haze, 0, 0.58),
              fieldMap(haze, 0.08, 0.26),
              fieldMap(haze, 0.03, 0.36),
              fieldMap(haze, 0, 0.66),
              fieldMap(haze, 0, 0.56),
            ],
            const [0.0, 0.3, 0.44, 0.56, 0.7, 1.0],
          ),
      );
      c
        ..save()
        ..clipPath(body);
      // The fluting: grooves in shade, a lit ridge beside each.
      for (final (q, fz, depth) in t.flutes) {
        for (final (off, map) in [
          (0.0, fieldMap(haze, 0, 0.84, 0.75 * depth)),
          (0.11, fieldMap(haze, 0.22, 0.12, 0.45 * depth)),
        ]) {
          final left = <Offset>[], right = <Offset>[];
          for (var k = 0; k <= 10; k++) {
            final f = fz * k / 10;
            final p = t.spine(f);
            final hw = t.half(f);
            final cx = p.dx + (q + off) * hw;
            final gw = t.wb * 0.035 * (1 - f / fz) + 0.5 * _u;
            left.add(Offset(cx - gw, p.dy));
            right.add(Offset(cx + gw, p.dy));
          }
          c.drawPath(
            Path()..addPolygon([...left, ...right.reversed], true),
            Paint()..color = map,
          );
        }
      }
      // Wet and dark where it stands in the water.
      c.drawRect(
        Rect.fromLTRB(
          t.x - t.wb,
          t.base - t.h * 0.05,
          t.x + t.wb,
          t.base + 4 * _u,
        ),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, t.base - t.h * 0.05),
            Offset(0, t.base),
            [fieldMap(haze, 0, 0.5, 0), fieldMap(haze, 0, 0.9, 0.8)],
          ),
      );
      // Bark: darker pits and paler flecks, as grains.
      final pits = GrainBatch(2);
      final n = (t.wb * t.h * 0.5 / (16 * _u * _u)).round();
      for (var i = 0; i < n; i++) {
        final f = math.pow(fieldHash(i, t.seed + 31), 1.6) * t.topF;
        final p = t.spine(f.toDouble());
        final hw = t.half(f.toDouble());
        pits.add(
          fieldHash(i, t.seed + 41) < 0.6 ? 0 : 1,
          p.dx + (fieldHash(i, t.seed + 37) * 2 - 1) * hw,
          p.dy,
        );
      }
      pits.draw(c, 0, 1.6 * _u * s, fieldMap(haze, 0, 0.8, 0.6));
      pits.draw(c, 1, 1.4 * _u * s, fieldMap(haze, 0.25, 0.2, 0.5));
      c.restore();
      for (final k in t.knees) {
        if (k.$2 >= t.base) _knee(c, k, bark, haze);
      }
    }
    if (all || part == _Part.leaf) {
      _leafCrown(
        c,
        null,
        t.pads,
        leaf: (haze > 0 ? 1.8 : 3.4) * math.max(0.6, s),
        seed: t.seed * 31,
        haze: haze,
        shade: 0.32,
      );
    }
    if (all || part == _Part.moss) {
      // Moss hanging in curtains, in three shades.
      for (var band = 0; band < 3; band++) {
        final path = Path();
        for (final (x, y, len, width, sway, shade) in t.moss) {
          if ((shade * 3).floor() != band) continue;
          _strand(path, x, y, len, width, sway, t.seed + x.round());
        }
        c.drawPath(
          path,
          Paint()
            ..shader = Gradient.linear(
              Offset(0, t.top),
              Offset(0, t.top + t.h * 0.5),
              [
                fieldMap(haze, 0.14, 0.5 - band * 0.16),
                fieldMap(haze, 0.02, 0.36 - band * 0.12),
              ],
            ),
        );
      }
    }
  }

  void _knee(
    Canvas c,
    (double, double, double, double) k,
    Paint bark,
    double haze,
  ) {
    final (x, y, hgt, wd) = k;
    c.drawPath(
      Path()
        ..moveTo(x - wd / 2, y + 1.5 * _u)
        ..quadraticBezierTo(
          x - wd * 0.36,
          y - hgt * 0.7,
          x - wd * 0.12,
          y - hgt,
        )
        ..quadraticBezierTo(
          x + wd * 0.04,
          y - hgt * 1.06,
          x + wd * 0.2,
          y - hgt * 0.9,
        )
        ..quadraticBezierTo(
          x + wd * 0.4,
          y - hgt * 0.5,
          x + wd / 2,
          y + 1.5 * _u,
        )
        ..close(),
      Paint()
        ..shader = Gradient.linear(
          Offset(x - wd / 2, 0),
          Offset(x + wd / 2, 0),
          [fieldMap(haze, 0.12, 0.2), fieldMap(haze, 0, 0.6)],
        ),
    );
  }

  /// A strand of moss: a ribbon tapering to nothing, its edges ragged, a
  /// little curved by its own weight.
  void _strand(
    Path path,
    double x,
    double y,
    double len,
    double width,
    double sway,
    int seed,
  ) {
    const n = 9;
    final left = <Offset>[], right = <Offset>[];
    for (var k = 0; k <= n; k++) {
      final f = k / n;
      final cx = x + sway * len * 0.1 * math.sin(f * math.pi * 0.9);
      final cy = y + len * f;
      final rag = 0.7 + 0.6 * fieldHash(k, seed);
      final half = width * 0.5 * math.pow(1 - f, 0.75) * rag;
      left.add(Offset(cx - half, cy));
      right.add(Offset(cx + half * (1.6 - rag), cy));
    }
    path.addPolygon([...left, ...right.reversed], true);
  }

  /// The light on a cypress: its trunk's edges, the tops of its limbs and
  /// pads, a grain here and there down its moss, the tips of its knees.
  void _cypressLight(_Cypress t, GrainBatch sparks) {
    final s = t.h / (_h * 0.98);
    for (var i = 0; i < 70; i++) {
      final f = i / 70 * t.topF;
      if (fieldHash(i, t.seed) < 0.45) continue;
      final side = fieldHash(i + 3, t.seed) < 0.5 ? -1.0 : 1.0;
      final p = t.spine(f);
      sparks.add(
        f < t.footF ? 0 : (fieldHash(i + 9, t.seed) < 0.6 ? 0 : 1),
        p.dx + side * (t.half(f) - 1.4 * _u * s),
        p.dy,
      );
    }
    for (final (from, to, wr) in t.limbs) {
      final n = ((to - from).distance / (2.4 * _u)).ceil();
      for (var k = 0; k <= n; k++) {
        if (fieldHash(k, from.dx.round()) > 0.5) continue;
        final q = Offset.lerp(from, to, k / n)!;
        sparks.add(1, q.dx, q.dy - wr * 0.6 * (1 - k / n));
      }
    }
    _leafCrown(
      _NullCanvas(),
      sparks,
      t.pads,
      leaf: (t.haze > 0 ? 1.8 : 3.4) * math.max(0.6, s),
      seed: t.seed * 31,
      haze: t.haze,
      shade: 0.32,
    );
    var k = 0;
    for (final (x, y, len, width, sway, _) in t.moss) {
      k++;
      final roll = fieldHash(k, t.seed + 5);
      if (roll > 0.55) continue;
      final f = fieldHash(k, t.seed + 6) * 0.8;
      final cx = x + sway * len * 0.1 * math.sin(f * math.pi * 0.9);
      sparks.add(roll < 0.12 ? 1 : 0, cx - width * 0.3 * (1 - f), y + len * f);
      if (roll < 0.02) _glint(cx, y + len * 0.9);
    }
    for (final (x, y, hgt, _) in t.knees) {
      sparks.add(2, x + 0.4 * _u, y - hgt + 1 * _u);
    }
  }

  // ── Banks ────────────────────────────────────────────────────────────────

  List<FieldSheet> _bankSheets(SceneLayer layer, _Bank b) {
    final bounds = _bankBounds(b);
    final res = layer == mid ? 0.8 : 1.0;
    return [
      FieldSheet(
        bounds: bounds,
        resolution: res,
        grade: b.stone ? _gStone : _gPeat,
        paint: (c) => b.stone ? _paintStone(c, b) : _paintPeat(c, b),
      ),
      FieldSheet(
        bounds: bounds,
        resolution: res,
        grade: _gTurf,
        paint: (c) => _paintTurf(c, b),
      ),
      FieldSheet(
        bounds: bounds,
        resolution: res * 0.9,
        light: true,
        paint: (c) => _sinking(layer, () => _paintBankLight(c, b)),
      ),
    ];
  }

  /// All of [banks] on one sheet per grade, each drawn again a loop away
  /// where it reaches over an edge.
  List<FieldSheet> _mergedBankSheets(
    SceneLayer layer,
    double w,
    List<_Bank> banks,
  ) {
    if (banks.isEmpty) return const [];
    var top = double.infinity, bottom = 0.0;
    for (final b in banks) {
      final r = _bankBounds(b);
      top = math.min(top, r.top);
      bottom = math.max(bottom, r.bottom);
    }
    final bounds = Rect.fromLTRB(0, top, w, bottom);
    void each(
      Canvas c,
      bool Function(_Bank) which,
      void Function(_Bank) paint,
    ) {
      for (final b in banks.where(which)) {
        _wrapped(b.cx, b.hw + b.flare + 16 * _u, w, (x) {
          // A copy across the seam lays down no glints of its own.
          final sink = _sink;
          if (x != b.cx) _sink = null;
          c
            ..save()
            ..translate(x - b.cx, 0);
          paint(b);
          c.restore();
          _sink = sink;
        });
      }
    }

    return [
      FieldSheet(
        bounds: bounds,
        resolution: 0.8,
        grade: _gPeat,
        paint: (c) => each(c, (b) => !b.stone, (b) => _paintPeat(c, b)),
      ),
      FieldSheet(
        bounds: bounds,
        resolution: 0.8,
        grade: _gStone,
        paint: (c) => each(c, (b) => b.stone, (b) => _paintStone(c, b)),
      ),
      FieldSheet(
        bounds: bounds,
        resolution: 0.8,
        grade: _gTurf,
        paint: (c) => each(c, (_) => true, (b) => _paintTurf(c, b)),
      ),
      FieldSheet(
        bounds: bounds,
        resolution: 0.7,
        light: true,
        paint: (c) => _sinking(
          layer,
          () => each(c, (_) => true, (b) => _paintBankLight(c, b)),
        ),
      ),
    ];
  }

  Path _edge(
    _Bank b,
    double Function(double) top,
    double Function(double) bottom,
  ) {
    final x0 = b.cx - b.hw, x1 = b.cx + b.hw;
    final step = 2 * _u;
    final path = Path()..moveTo(x0, top(x0));
    for (var x = x0; x <= x1; x += step) {
      path.lineTo(x, top(x));
    }
    path.lineTo(x1, top(x1));
    for (var x = x1; x >= x0; x -= step) {
      path.lineTo(x, bottom(x));
    }
    return path..close();
  }

  double _waterEdge(_Bank b, double x) =>
      _bWater(b) + 1.2 * _u * fieldNoise(x / (7 * _u), b.seed + 2);

  /// A bank of peat: its face dark and wet down to the water, roots hanging
  /// out from under the lip, a few stones at its foot.
  void _paintPeat(Canvas c, _Bank b) {
    final haze = b.haze;
    final wl = _bWater(b);
    final face = _edge(
      b,
      (x) => _bFront(b, x) - 0.5 * _u,
      (x) => _waterEdge(b, x),
    );
    final lip = _bFront(b, b.cx);
    c.drawPath(
      face,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, lip),
          Offset(0, wl),
          [
            fieldMap(haze, 0.06, 0.4),
            fieldMap(haze, 0, 0.58),
            fieldMap(haze, 0, 0.86),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
    c
      ..save()
      ..clipPath(face);
    // Layers in the peat: paler bands where it has dried, under the lip.
    final x0 = b.cx - b.hw, x1 = b.cx + b.hw;
    for (final (f, a) in const [(0.28, 0.5), (0.55, 0.35)]) {
      double at(double x) =>
          _bFront(b, x) +
          (wl - _bFront(b, x)) *
              (f + 0.06 * fieldNoise(x / (18 * _u), b.seed + 21));
      final band = Path()..moveTo(x0, at(x0));
      for (var x = x0; x <= x1; x += 2.5 * _u) {
        band.lineTo(x, at(x));
      }
      for (var x = x1; x >= x0; x -= 2.5 * _u) {
        band.lineTo(x, at(x) + 2.2 * _u);
      }
      c.drawPath(band..close(), Paint()..color = fieldMap(haze, 0.12, 0.3, a));
    }
    final grains = GrainBatch(2);
    final r = FieldRandom(b.seed * 5 + 2);
    final n = (b.hw * b.rise * 1.6 / (_u * _u * 9)).round();
    for (var k = 0; k < n; k++) {
      final x = b.cx + (r.next() * 2 - 1) * b.hw;
      final y = _bFront(b, x) + r.next() * (wl - _bFront(b, x));
      grains.add(r.next() < 0.6 ? 0 : 1, x, y);
    }
    grains.draw(c, 0, 1.5 * _u, fieldMap(haze, 0, 0.9, 0.6));
    grains.draw(c, 1, 1.3 * _u, fieldMap(haze, 0.25, 0.25, 0.5));
    c.restore();

    // Roots out from under the lip, into the water.
    final rr = FieldRandom(b.seed * 11 + 4);
    final roots = 2 + (b.hw / (34 * _u)).floor();
    for (var k = 0; k < roots; k++) {
      final x = b.cx + rr.range(-0.78, 0.78) * b.hw;
      final y = _bFront(b, x) + 1 * _u;
      final len = (wl - y) * rr.range(0.5, 1.05) + 2 * _u;
      final width = rr.range(2.2, 3.8) * _u * (haze > 0 ? 0.65 : 1);
      final path = Path();
      _strand(path, x, y, len, width, rr.range(-1.4, 1.4), b.seed + k);
      c.drawPath(path, Paint()..color = fieldMap(haze, 0.08, 0.7));
    }
    // Stones at its foot.
    final stones = Path(), tops = Path();
    for (var k = 0; k < 2 + (b.hw / (60 * _u)).floor(); k++) {
      final x = b.cx + rr.range(-0.85, 0.85) * b.hw;
      final rad = rr.range(2.5, 5) * _u * (haze > 0 ? 0.7 : 1);
      final at = Offset(x, wl - rad * 0.3);
      stones.addOval(
        Rect.fromCenter(center: at, width: rad * 2.4, height: rad * 1.4),
      );
      tops.addOval(
        Rect.fromCenter(
          center: at + Offset(-rad * 0.2, -rad * 0.3),
          width: rad * 1.3,
          height: rad * 0.6,
        ),
      );
    }
    c
      ..drawPath(stones, Paint()..color = fieldMap(haze, 0.05, 0.55))
      ..drawPath(tops, Paint()..color = fieldMap(haze, 0.3, 0.15));
  }

  /// A stone's face: from its lip down to the water, its ends breaking out
  /// a little wider toward the water.
  Path _stoneFace(_Bank b) {
    final x0 = b.cx - b.hw, x1 = b.cx + b.hw;
    final wl = _bWater(b);
    final step = 2 * _u;
    final path = Path()..moveTo(x0, _bFront(b, x0));
    for (var x = x0; x <= x1; x += step) {
      path.lineTo(x, _bFront(b, x));
    }
    path
      ..lineTo(x1, _bFront(b, x1))
      ..lineTo(
        x1 + b.flare * 0.45,
        _bFront(b, x1) + (wl - _bFront(b, x1)) * 0.4,
      )
      ..lineTo(x1 + b.flare, wl);
    for (var x = x1 + b.flare; x >= x0 - b.flare; x -= step) {
      path.lineTo(x, _waterEdge(b, x));
    }
    return path
      ..lineTo(x0 - b.flare, wl)
      ..lineTo(
        x0 - b.flare * 0.45,
        _bFront(b, x0) + (wl - _bFront(b, x0)) * 0.4,
      )
      ..close();
  }

  /// A stone: its flat top lit toward the back, stepping down at one end;
  /// its face split into planes, each in its own shade, a ledge across it,
  /// cracked and pitted.
  void _paintStone(Canvas c, _Bank b) {
    final haze = b.haze;
    final wl = _bWater(b);
    final x0 = b.cx - b.hw, x1 = b.cx + b.hw;
    final top = _edge(b, (x) => _bBack(b, x), (x) => _bFront(b, x) + 0.6 * _u);
    final face = _stoneFace(b);
    c
      ..drawPath(face, Paint()..color = fieldMap(haze, 0, 0.62))
      ..drawPath(
        top,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, _bBack(b, b.cx)),
            Offset(0, _bFront(b, b.cx)),
            [fieldMap(haze, 0.32, 0.04), fieldMap(haze, 0.12, 0.2)],
          ),
      );
    c
      ..save()
      ..clipPath(face);
    double lip(double x) => _bFront(b, x.clamp(x0, x1));
    // Planes down the face, the ends turned away into shade.
    final r = FieldRandom(b.seed * 7 + 1);
    final cuts = <double>[x0 - b.flare - 2 * _u];
    var x = x0;
    while (true) {
      x += b.hw * r.range(0.16, 0.36);
      if (x >= x1 - b.hw * 0.1) break;
      cuts.add(x);
    }
    cuts.add(x1 + b.flare + 2 * _u);
    for (var k = 0; k + 1 < cuts.length; k++) {
      final a = cuts[k], z = cuts[k + 1];
      final side = (((a + z) / 2) - b.cx) / b.hw;
      final turn = math.pow(math.min(1.0, side.abs()), 2.4).toDouble();
      final own = r.range(-0.08, 0.08);
      final lean = r.range(-0.1, 0.1) * b.rise;
      c.drawPath(
        Path()..addPolygon([
          Offset(a, lip(a) - 2 * _u),
          Offset(z, lip(z) - 2 * _u),
          Offset(z + lean, wl + 3 * _u),
          Offset(a + lean, wl + 3 * _u),
        ], true),
        Paint()
          ..shader =
              Gradient.linear(Offset(0, _bFront(b, b.cx)), Offset(0, wl), [
                fieldMap(haze, 0.04, 0.46 + 0.3 * turn + own),
                fieldMap(haze, 0, 0.76 + 0.16 * turn + own),
              ]),
      );
    }
    // A ledge across the face: lit along its top, its shadow under it.
    final ledgeF = r.range(0.4, 0.58);
    double ledge(double x) =>
        lip(x) +
        (wl - lip(x)) *
            (ledgeF + 0.08 * fieldNoise(x / (24 * _u), b.seed + 21));
    for (final (off, thick, map) in [
      (0.0, 1.5, fieldMap(haze, 0.2, 0.2, 0.7)),
      (1.5, 3.0, fieldMap(haze, 0, 0.88, 0.55)),
    ]) {
      final band = Path()..moveTo(x0 - b.flare, ledge(x0) + off * _u);
      for (var x = x0 - b.flare; x <= x1 + b.flare; x += 2.5 * _u) {
        band.lineTo(x, ledge(x) + off * _u);
      }
      for (var x = x1 + b.flare; x >= x0 - b.flare; x -= 2.5 * _u) {
        band.lineTo(x, ledge(x) + (off + thick) * _u);
      }
      c.drawPath(band..close(), Paint()..color = map);
    }
    // The edge of the top, catching the light, with its shadow under it.
    for (final (off, thick, map) in [
      (0.0, 1.4, fieldMap(haze, 0.3, 0.1, 0.8)),
      (1.4, 2.6, fieldMap(haze, 0, 0.82, 0.5)),
    ]) {
      final band = Path()..moveTo(x0, _bFront(b, x0) + off * _u);
      for (var x = x0; x <= x1; x += 2 * _u) {
        band.lineTo(x, _bFront(b, x) + off * _u);
      }
      for (var x = x1; x >= x0; x -= 2 * _u) {
        band.lineTo(x, _bFront(b, x) + (off + thick) * _u);
      }
      c.drawPath(band..close(), Paint()..color = map);
    }
    // Cracks: dark wedges down from the lip.
    for (var k = 0; k < 2 + (b.hw / (60 * _u)).floor(); k++) {
      final cx = b.cx + r.range(-0.8, 0.8) * b.hw;
      final y0 = _bFront(b, cx);
      final len = (wl - y0) * r.range(0.35, 0.85);
      final wd = r.range(1.2, 2.2) * _u;
      final bend = r.range(-1, 1) * 4 * _u;
      c.drawPath(
        Path()..addPolygon([
          Offset(cx - wd, y0),
          Offset(cx + wd, y0),
          Offset(cx + bend * 0.5 + wd * 0.3, y0 + len * 0.5),
          Offset(cx + bend, y0 + len),
          Offset(cx + bend * 0.5 - wd * 0.4, y0 + len * 0.5),
        ], true),
        Paint()..color = fieldMap(haze, 0, 0.94, 0.8),
      );
    }
    // Wet and dark where it stands in the water.
    c.drawRect(
      Rect.fromLTRB(x0 - b.flare, wl - b.rise * 0.3, x1 + b.flare, wl + 4 * _u),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, wl - b.rise * 0.3),
          Offset(0, wl),
          [fieldMap(haze, 0, 0.6, 0), fieldMap(haze, 0, 0.92, 0.75)],
        ),
    );
    final grains = GrainBatch(2);
    final n = (b.hw * b.rise * 1.4 / (_u * _u * 10)).round();
    for (var k = 0; k < n; k++) {
      final gx = b.cx + (fieldHash(k, b.seed + 31) * 2 - 1) * (b.hw + b.flare);
      final gy = lip(gx) + fieldHash(k, b.seed + 37) * (wl - lip(gx));
      grains.add(fieldHash(k, b.seed + 41) < 0.6 ? 0 : 1, gx, gy);
    }
    grains.draw(c, 0, 1.5 * _u, fieldMap(haze, 0, 0.9, 0.55));
    grains.draw(c, 1, 1.3 * _u, fieldMap(haze, 0.3, 0.2, 0.45));
    c.restore();
    // Risers where the top steps down, in shade.
    if (b.steps != 0) {
      for (final s in const [0.6, 0.8]) {
        final sx = b.cx + s * b.steps * b.hw;
        final hi = _bStand(b, sx - b.steps * 0.5 * _u);
        final lo = _bStand(b, sx + b.steps * 0.5 * _u);
        final wd = 2.5 * _u * b.steps;
        c.drawPath(
          Path()..addPolygon([
            Offset(sx, hi - b.plate * 0.55),
            Offset(sx + wd, lo - b.plate * 0.55),
            Offset(sx + wd, lo + b.plate * 0.45),
            Offset(sx, hi + b.plate * 0.45),
          ], true),
          Paint()..color = fieldMap(haze, 0, 0.55),
        );
      }
    }
  }

  /// The green on a bank: on peat, turf from its lit back to its lip, with
  /// fronds hanging over; on a stone, cushions of moss along its back and
  /// down over its edge. And lily pads on the water in front of it.
  void _paintTurf(Canvas c, _Bank b) {
    final haze = b.haze;
    final r = FieldRandom(b.seed * 3 + 5);
    if (!b.stone) {
      final plate = _edge(
        b,
        (x) => _bBack(b, x),
        (x) => _bFront(b, x) + 0.8 * _u,
      );
      c.drawPath(
        plate,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, _bBack(b, b.cx)),
            Offset(0, _bFront(b, b.cx)),
            [fieldMap(haze, 0.14, 0.04), fieldMap(haze, 0, 0.42)],
          ),
      );
      final fronds = Path();
      for (
        var x = b.cx - b.hw + 2 * _u;
        x < b.cx + b.hw - 2 * _u;
        x += 2.2 * _u
      ) {
        if (_bPinch(b, x) < 0.2) continue;
        final y = _bFront(b, x);
        final len = r.range(2, 8) * _u * (haze > 0 ? 0.6 : 1);
        final lean = r.range(-0.6, 0.6) * len * 0.4;
        fronds.addPolygon([
          Offset(x - 1.2 * _u, y - 0.5 * _u),
          Offset(x + 1.2 * _u, y - 0.5 * _u),
          Offset(x + lean, y + len),
        ], true);
      }
      c.drawPath(fronds, Paint()..color = fieldMap(haze, 0, 0.48));
      if (haze > 0) _farTufts(c, b, r);
    } else {
      // Moss: cushions along the back of the top, a few out across it, and
      // drips of it over the edge.
      final top = _edge(
        b,
        (x) => _bBack(b, x) - 0.5 * _u,
        (x) => _bFront(b, x) + 0.4 * _u,
      );
      c
        ..save()
        ..clipPath(top);
      final cushions = Path(), lit = Path();
      final n = (b.hw / (2.6 * _u)).round();
      for (var k = 0; k < n; k++) {
        final x = b.cx + r.range(-1, 1) * b.hw;
        final back = _bBack(b, x), front = _bFront(b, x);
        final d = math.pow(r.next(), 1.6).toDouble();
        final y = back + d * (front - back);
        final rad = r.range(3, 7) * _u * (1 - d * 0.5) * (haze > 0 ? 0.7 : 1);
        if (fieldLoopNoise(x, 40 * _u, b.seed, 0) < -0.2) continue;
        cushions.addOval(
          Rect.fromCenter(
            center: Offset(x, y),
            width: rad * 2.6,
            height: rad * 1.1,
          ),
        );
        lit.addOval(
          Rect.fromCenter(
            center: Offset(x - rad * 0.2, y - rad * 0.22),
            width: rad * 1.5,
            height: rad * 0.5,
          ),
        );
      }
      c
        ..drawPath(cushions, Paint()..color = fieldMap(haze, 0.04, 0.3))
        ..drawPath(lit, Paint()..color = fieldMap(haze, 0.22, 0.12))
        ..restore();
      final drips = Path();
      for (
        var x = b.cx - b.hw * 0.95;
        x < b.cx + b.hw * 0.95;
        x += r.range(4, 14) * _u
      ) {
        if (fieldLoopNoise(x, 40 * _u, b.seed, 0) < -0.1) continue;
        _strand(
          drips,
          x,
          _bFront(b, x) - 0.5 * _u,
          r.range(3, 11) * _u,
          r.range(2.4, 4.4) * _u,
          r.range(-0.5, 0.5),
          b.seed + x.round(),
        );
      }
      c.drawPath(drips, Paint()..color = fieldMap(haze, 0.02, 0.4));
      if (haze > 0) _farTufts(c, b, r);
    }
    // Lily pads on the water before it.
    if (haze == 0) {
      final pads = Path(), rims = Path();
      for (final p in _lilyPads(b)) {
        final (x, y, rx, notch) = p;
        final ry = rx * 0.3;
        final pad = Path.combine(
          PathOperation.difference,
          Path()..addOval(
            Rect.fromCenter(
              center: Offset(x, y),
              width: rx * 2,
              height: ry * 2,
            ),
          ),
          Path()..addPolygon([
            Offset(x, y),
            Offset(
              x + math.cos(notch - 0.3) * rx * 1.2,
              y + math.sin(notch - 0.3) * ry * 1.2,
            ),
            Offset(
              x + math.cos(notch + 0.3) * rx * 1.2,
              y + math.sin(notch + 0.3) * ry * 1.2,
            ),
          ], true),
        );
        pads.addPath(pad, Offset.zero);
        rims.addOval(
          Rect.fromCenter(
            center: Offset(x, y - ry * 0.25),
            width: rx * 1.6,
            height: ry * 1.1,
          ),
        );
      }
      c
        ..drawPath(pads, Paint()..color = fieldMap(0, 0, 0.42))
        ..drawPath(rims, Paint()..color = fieldMap(0, 0.14, 0.28, 0.6));
    }
  }

  /// A far bank's grass: tufts of three grains along its back.
  void _farTufts(Canvas c, _Bank b, FieldRandom r) {
    final tufts = GrainBatch(4);
    for (var k = 0; k < (b.hw * 2 / (0.9 * _u)).round(); k++) {
      final x = b.cx + (r.next() * 2 - 1) * b.hw * 0.96;
      final d = r.next();
      final y = _bBack(b, x) + d * (_bFront(b, x) - _bBack(b, x));
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
      tufts.draw(c, t, 1.25 * _u, fieldMap(b.haze, 0.1 + t * 0.22, 0.05));
    }
  }

  /// Lily pads on the water in front of a near peat bank: (x, y, half
  /// width, where its notch points).
  List<(double, double, double, double)> _lilyPads(_Bank b) {
    if (b.haze > 0 || b.stone) return const [];
    final r = FieldRandom(b.seed * 17 + 9);
    final wl = _bWater(b);
    return [
      for (var k = 0, n = 3 + (r.next() * 4).floor(); k < n; k++)
        () {
          final d = math.pow(r.next(), 1.3).toDouble();
          final y = wl + (5 + d * 26) * _u;
          return (
            b.cx + r.range(-0.95, 0.95) * b.hw,
            y,
            (5 + d * 6) * _u * r.range(0.8, 1.2),
            r.range(0, math.pi * 2),
          );
        }(),
    ];
  }

  /// The light on a bank: bands down from the back of its top, grains along
  /// the back and the lip, along a stone's edge, and where it meets the
  /// water; and the far edges of its lily pads.
  void _paintBankLight(Canvas c, _Bank b) {
    final x0 = b.cx - b.hw, x1 = b.cx + b.hw;
    final step = 2.2 * _u;
    for (final (depth, a) in [(1.4, 0.5), (3.6, 0.26), (8.0, 0.1)]) {
      final band = Path()..moveTo(x0, _bBack(b, x0));
      for (var x = x0; x <= x1; x += step) {
        band.lineTo(x, _bBack(b, x));
      }
      for (var x = x1; x >= x0; x -= step) {
        band.lineTo(
          x,
          math.min(_bFront(b, x), _bBack(b, x) + depth * _u * _bPinch(b, x)),
        );
      }
      c.drawPath(
        band..close(),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a),
      );
    }
    final sparks = GrainBatch(_sparkAlpha.length);
    var k = 0;
    for (var x = x0; x <= x1; x += step, k++) {
      final roll = fieldHash(k, b.seed * 13);
      if (roll < 0.3) {
        sparks.add((roll * 10).floor().clamp(0, 3), x, _bBack(b, x) + 0.6 * _u);
        if (roll < 0.02) _glint(x, _bBack(b, x));
      } else if (roll > (b.stone ? 0.55 : 0.88)) {
        sparks.add(b.stone ? 2 : 0, x, _bFront(b, x) + 0.7 * _u);
        if (b.stone && roll > 0.985) _glint(x, _bFront(b, x) + 0.7 * _u);
      }
      if (fieldHash(k, b.seed * 13 + 7) < 0.18) {
        sparks.add(0, x, _waterEdge(b, x) + 0.8 * _u);
      }
    }
    for (final (x, y, rx, _) in _lilyPads(b)) {
      final ry = rx * 0.3;
      for (var j = -2; j <= 2; j++) {
        if (fieldHash(j + 3, x.round()) > 0.7) continue;
        final a = -math.pi / 2 + j * 0.45;
        sparks.add(1, x + math.cos(a) * rx * 0.9, y + math.sin(a) * ry * 0.9);
      }
    }
    _drawSparks(c, sparks, 1.35);
  }

  // ── Reflections ──────────────────────────────────────────────────────────

  /// What stands in the water on [layer], upside down in it: the cypresses'
  /// feet and knees and the banks' faces, darkening the water and fading
  /// as they go down. Water-graded.
  void _paintReflections(
    Canvas c,
    double w,
    SceneLayer layer,
    List<_Cypress> trees,
    List<_Bank> banks,
  ) {
    final back = layer != near;
    // How much of the sky still shows through, and how dark, by depth.
    final (sky, dark) = switch (layer) {
      far => (0.66, 0.16),
      mid => (0.5, 0.3),
      _ => (0.2, 0.7),
    };
    for (final t in trees) {
      final depth = t.h * (back ? 0.28 : 0.2);
      _wrapped(t.x, t.reach, w, (x) {
        final dx = x - t.x;
        final mirror = <Offset>[
          for (final p in t.outline)
            if (t.base - p.dy < depth * 1.4)
              Offset(p.dx + dx, t.base + (t.base - p.dy) * 0.8),
        ];
        if (mirror.length < 3) return;
        final path = Path()..addPolygon(mirror, true);
        for (final (kx, ky, hgt, wd) in t.knees) {
          final y = ky + 1.5 * _u;
          path.addPolygon([
            Offset(kx + dx - wd / 2, y),
            Offset(kx + dx + 0.04 * wd, y + hgt * 0.85),
            Offset(kx + dx + wd / 2, y),
          ], true);
        }
        c.drawPath(
          path,
          Paint()
            ..shader = Gradient.linear(
              Offset(0, t.base),
              Offset(0, t.base + depth),
              [fieldMap(sky, 0, dark, 0.85), fieldMap(0.4, 0, 0.4, 0)],
            ),
        );
      });
    }
    for (final b in banks) {
      _wrapped(b.cx, b.hw + b.flare + 10 * _u, w, (x) {
        final dx = x - b.cx;
        final wl = _bWater(b);
        final x0 = b.cx - b.hw - b.flare, x1 = b.cx + b.hw + b.flare;
        final path = Path()..moveTo(x0 + dx, wl);
        for (var px = x0; px <= x1; px += 2.5 * _u) {
          final over = (px - b.cx).abs() - b.hw;
          final up = over > 0 && b.flare > 0
              ? (wl - _bBack(b, b.cx)) * (1 - over / b.flare)
              : wl - _bBack(b, px);
          path.lineTo(px + dx, wl + up * 0.82);
        }
        path
          ..lineTo(x1 + dx, wl)
          ..close();
        c.drawPath(
          path,
          Paint()
            ..shader = Gradient.linear(
              Offset(0, wl),
              Offset(0, wl + (wl - _bBack(b, b.cx)) * 0.82),
              [fieldMap(sky * 0.9, 0, dark, 0.9), fieldMap(0.4, 0, 0.4, 0)],
            ),
        );
      });
    }
  }

  // ── Mist ─────────────────────────────────────────────────────────────────

  /// Mist lying on the water: long soft lenses of it, wrapping round the
  /// sheet so it can drift for ever. Mist-graded.
  void _paintMist(
    Canvas c,
    double w,
    double y,
    double alpha, {
    required int seed,
  }) {
    final r = FieldRandom(seed);
    final n = math.max(3, (w / (260 * _u)).round());
    for (var k = 0; k < n; k++) {
      final cx = (k + r.range(0.1, 0.9)) * w / n;
      final cy = y + r.range(-0.035, 0.035) * _h;
      final rx = r.range(140, 300) * _u;
      final ry = r.range(9, 18) * _u;
      final a = alpha * r.range(0.5, 1);
      for (final dx in [-w, 0.0, w]) {
        if (cx + dx + rx < 0 || cx + dx - rx > w) continue;
        c
          ..save()
          ..translate(cx + dx, cy)
          ..scale(rx / ry, 1)
          ..drawCircle(
            Offset.zero,
            ry,
            Paint()
              ..shader = Gradient.radial(
                Offset.zero,
                ry,
                [
                  fieldMap(0, 0, 0, a),
                  fieldMap(0.15, 0, 0, a * 0.55),
                  fieldMap(0.3, 0, 0, 0),
                ],
                const [0.0, 0.5, 1.0],
              ),
          )
          ..restore();
      }
    }
  }

  // ── Grass, reeds and weed ────────────────────────────────────────────────

  /// Near banks' grass: a fringe along each back, blades down the top, those
  /// rooted below a standing creature's feet kept short and drawn over it
  /// (row 4), and reeds standing up at a peat bank's ends.
  _Blades _bankGrass(List<_Bank> banks) {
    final b = _BladeBuilder();
    final r = FieldRandom(626);
    for (final k in banks) {
      final sparse = k.stone ? 0.22 : 1.0;
      final x0 = k.cx - k.hw * 0.97, x1 = k.cx + k.hw * 0.97;
      for (var x = x0; x < x1; x += 2 * _u) {
        if (k.stone && fieldLoopNoise(x, 40 * _u, k.seed, 0) < 0.1) continue;
        final tall =
            0.7 + 0.6 * (fieldNoise(x / (40 * _u), k.seed + 1) * 0.5 + 0.5);
        b.add(
          x: x + r.range(-0.6, 0.6) * _u,
          base: _bBack(k, x) + 1.2 * _u,
          height:
              r.range(6, 13) *
              tall *
              _u *
              (0.5 + 0.5 * _bPinch(k, x)) *
              (k.stone ? 0.6 : 1),
          lean: r.range(-0.1, 0.3),
          phase: r.range(0, math.pi * 2),
          depth: 0,
          row: 0,
        );
      }
      final n = (k.hw * 2 * k.plate * sparse / (7 * _u * _u)).round();
      for (var j = 0; j < n; j++) {
        final x = k.cx + (r.next() * 2 - 1) * k.hw * 0.95;
        if (k.stone && fieldLoopNoise(x, 40 * _u, k.seed, 0) < -0.2) continue;
        final back = _bBack(k, x), front = _bFront(k, x);
        final d = r.next();
        final y = back + 1.5 * _u + d * (front - back - 1.5 * _u);
        final feet = y > _bStand(k, x) + 0.5 * _u;
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
      if (k.stone) continue;
      // Reeds at its ends.
      for (final end in [-1.0, 1.0]) {
        final m = 5 + (r.next() * 7).floor();
        for (var j = 0; j < m; j++) {
          final t = end * r.range(0.6, 0.92);
          final x = k.cx + t * k.hw;
          b.add(
            x: x,
            base: _bFront(k, x) - 0.5 * _u,
            height: r.range(18, 40) * _u,
            lean: end * r.range(0.0, 0.22) + r.range(-0.06, 0.06),
            phase: r.range(0, math.pi * 2),
            depth: 0.2,
            row: 2,
          );
        }
      }
    }
    return b.done();
  }

  /// Reeds and cattails standing up out of the water at the very front.
  _Blades _foreReeds(double w) {
    final b = _BladeBuilder();
    final r = FieldRandom(717);
    var cx = r.range(160, 360) * _u;
    while (cx < w) {
      final n = 16 + (r.next() * 12).floor();
      final reach = r.range(60, 120) * _u;
      for (var i = 0; i < n; i++) {
        final off = r.range(-22, 22) * _u * math.sqrt(r.next());
        b.add(
          x: _loop ? (cx + off) % w : cx + off,
          base: _h + 4 * _u,
          height: reach * r.range(0.45, 1.0),
          lean: off / (20 * _u) * 0.22 + r.range(-0.06, 0.06),
          phase: r.range(0, math.pi * 2),
          depth: 1,
          row: 0,
        );
      }
      cx += r.range(280, 700) * _u;
    }
    return b.done();
  }

  /// Duckweed drifted on the near water in mats: thick in front of the banks
  /// and round the feet of the trees, in loose rafts out across the open
  /// water, never behind what stands in it.
  _Weed _makeWeed(double w, List<_Bank> banks, List<_Cypress> trees) {
    final r = FieldRandom(919);
    final items = <(double, double, int, int)>[];
    final top = _h * (_nearWater + 0.01);
    final bottom = _h + 4 * _u;
    final period = _period(near);
    double dist(double x, double from) =>
        period > 0 ? _loopDelta(x, from, near) : x - from;
    bool hidden(double x, double y) {
      for (final b in banks) {
        final d = dist(x, b.cx);
        if (d.abs() < b.hw + b.flare + 2 * _u && y < _bWater(b) + 3.5 * _u) {
          return true;
        }
        for (final (px, py, rx, _) in _lilyPads(b)) {
          final ex = (b.cx + d - px) / rx, ey = (y - py) / (rx * 0.3);
          if (ex * ex + ey * ey < 1.3) return true;
        }
      }
      for (final t in trees) {
        final d = dist(x, t.x);
        if (d.abs() < t.wb * 0.95 && y < t.base + 4 * _u) return true;
        for (final (kx, ky, _, wd) in t.knees) {
          if ((t.x + d - kx).abs() < wd && (y - ky).abs() < 3 * _u) return true;
        }
      }
      return false;
    }

    // How thick the weed is at x, y: rafts from the noise, flattened the
    // way the water lies, and drifts gathered against whatever stands in it.
    double mat(double x, double y) {
      final raft =
          _noise2(x, y, 120 * _u, 30 * _u, 931, period) * 0.68 +
          _noise2(x, y, 44 * _u, 12 * _u, 937, period) * 0.32;
      var drift = 0.0;
      for (final b in banks) {
        final d = dist(x, b.cx).abs() / (b.hw * 1.25);
        final below = (y - _bWater(b)) / (30 * _u);
        if (d > 1 || below < 0) continue;
        drift = math.max(drift, math.exp(-below * below) * (1 - d * d));
      }
      for (final t in trees) {
        final d = dist(x, t.x).abs() / (t.wb * 1.8);
        final below = (y - t.base) / (22 * _u);
        if (d > 1 || below < 0) continue;
        drift = math.max(drift, math.exp(-below * below) * (1 - d * d));
      }
      final ragged = 0.55 + 0.45 * _noise2(x, y, 26 * _u, 7 * _u, 941, period);
      return raft * 0.42 + 0.46 + drift * 0.62 * ragged;
    }

    var y = top;
    var row = 0;
    while (y < bottom) {
      final depth = (y - top) / (bottom - top);
      final step = (2.0 + 1.1 * depth) * _u;
      final off = (row++ % 2) * step * 0.5;
      for (var x = off; x < w; x += step) {
        final m = mat(x, y);
        final edge = (m - 0.7) / 0.07;
        if (edge <= 0 || r.next() > edge) continue;
        final gx = x + r.range(-0.4, 0.4) * step;
        final gy = y + r.range(-0.3, 0.3) * step * 0.4;
        if (hidden(gx, gy)) continue;
        final tone = (r.next() * 1.8 + math.min(1.0, edge - 1) * 1.4)
            .floor()
            .clamp(0, 3);
        items.add((gx < 0 ? gx + w : gx, gy, tone, depth > 0.45 ? 1 : 0));
      }
      y += step * 0.42;
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));
    final n = items.length;
    final x = Float32List(n), ys = Float32List(n);
    final tone = Uint8List(n), size = Uint8List(n);
    for (var i = 0; i < n; i++) {
      x[i] = items[i].$1;
      ys[i] = items[i].$2;
      tone[i] = items[i].$3;
      size[i] = items[i].$4;
    }
    return _Weed(x, ys, tone, size);
  }

  /// Smooth value noise in [-1, 1] over x and y, in cells [cx] by [cy],
  /// repeating every [period] in x (0: never).
  double _noise2(
    double x,
    double y,
    double cx,
    double cy,
    int seed,
    double period,
  ) {
    final n = period > 0 ? math.max(1, (period / cx).round()) : 0;
    final u = n > 0 ? x / period * n : x / cx;
    final v = y / cy;
    final i = u.floor(), j = v.floor();
    final fu = u - i, fv = v - j;
    final su = fu * fu * (3 - 2 * fu), sv = fv * fv * (3 - 2 * fv);
    int wrap(int k) => n > 0 ? k % n : k;
    double at(int a, int b) => fieldHash(wrap(a) * 7919 + b * 104729, seed);
    final top = at(i, j) + (at(i + 1, j) - at(i, j)) * su;
    final low = at(i, j + 1) + (at(i + 1, j + 1) - at(i, j + 1)) * su;
    return (top + (low - top) * sv) * 2 - 1;
  }

  /// Motes over the water and the banks: midges by day, fireflies at night,
  /// low over the bog.
  _Motes _swampMotes(double w) {
    final r = FieldRandom(818);
    final n = (w / (7.5 * _u)).round();
    final x0 = Float32List(n),
        y0 = Float32List(n),
        speed = Float32List(n),
        phase = Float32List(n);
    for (var i = 0; i < n; i++) {
      x0[i] = r.next() * w;
      y0[i] = _h * r.range(0.44, 0.9);
      speed[i] = r.range(2, 7) * _u;
      phase[i] = r.range(0, math.pi * 2);
    }
    return _Motes(
      x0,
      y0,
      speed,
      phase,
      width: w,
      yTop: _h * 0.44,
      yBottom: _h * 0.9,
    );
  }

  // ── The dry bed ──────────────────────────────────────────────────────────

  /// Glints on the water, apart from the rest: they go when it does.
  final Map<SceneLayer, _Glints> _waterGlints = {};

  /// [layer]'s dried floor, under everything that stands on it: the
  /// cracked mud with the last pools in it, and the stained feet of what
  /// stands there, shown only when the Swamp has gone dry. The plates' lit
  /// tops are in its maps, so a low sun still catches them.
  List<FieldSheet> _drySheets(
    SceneLayer layer,
    double w,
    List<_Cypress> trees,
    List<_Bank> banks,
    Rect bed,
  ) => [
    FieldSheet(
      bounds: bed,
      resolution: layer == mid ? 0.7 : 0.8,
      grade: _gMud,
      opacity: () => dry,
      paint: (c) {
        _paintMud(c, w, layer);
        _paintFeet(c, w, layer, trees, banks);
      },
    ),
  ];

  /// Where the far strip of water ends when the Swamp has gone dry, and how
  /// far below the old water each layer's floor lies.
  static const _dryShore = _shore + 0.012;
  double _drop(SceneLayer layer) => (layer == mid ? 4 : 7) * _u;

  /// The dried floor's haze at [y]: pale toward the far shore, clear near.
  double _mudHaze(double y) =>
      ((_h * 0.72 - y) / (_h * 0.11)).clamp(0.0, 1.0) * 0.8;

  /// The mud's colour where its maps read [haze] and [shade], as its grade
  /// would make it.
  Color _mudAt(double haze, double shade) {
    final l = _light, a = _albedoOf(_gMud);
    final to = l.skyAt(0.585);
    double ch(double base, double hz) =>
        (base + haze * (hz - base) - shade * 0.72 * base).clamp(0.0, 1.0);
    return Color.from(
      alpha: 1,
      red: ch(a.r * l.ambient.r, to.r),
      green: ch(a.g * l.ambient.g, to.g),
      blue: ch(a.b * l.ambient.b, to.b),
    );
  }

  /// The last pools on [layer] when it has dried: (x, y, half width, half
  /// height, seed) — one round each point that wades, the rest in the
  /// widest gaps between its banks.
  final Map<SceneLayer, List<_Pool>> _pools = {};

  List<_Pool> _makePools(SceneLayer layer, double w, List<_Bank> banks) {
    if (banks.isEmpty) return const [];
    final sorted = [...banks]..sort((a, b) => a.cx.compareTo(b.cx));
    final gaps = <(double, double)>[];
    for (var i = 0; i < sorted.length; i++) {
      final a = sorted[i], b = sorted[(i + 1) % sorted.length];
      final from = a.cx + a.hw + a.flare;
      var to = b.cx - b.hw - b.flare;
      if (i == sorted.length - 1) to += w;
      if (to > from) gaps.add((from, to));
    }
    gaps.sort((a, b) => (b.$2 - b.$1).compareTo(a.$2 - a.$1));
    final near0 = layer == near;
    // A pool round each point that wades, its creature standing in the
    // middle of it a little toward the near side.
    final pools = <_Pool>[
      for (final p in _spawns)
        if (p.anchor == layer && p.perch == SpawnPerch.wade)
          () {
            final rx = p.size.x * 1.15;
            return (_spawnX(p), _feet(p) - rx * 0.03, rx, rx * 0.2, 391);
          }(),
    ];
    // The rest in the widest gaps that have none.
    var k = 0;
    for (final (from, to) in gaps) {
      if (pools.length >= (near0 ? 2 : 1)) break;
      final taken = pools.any((q) {
        final d = q.$1 - w * ((q.$1 - from) / w).floorToDouble();
        return d >= from - q.$3 && d <= to + q.$3;
      });
      if (taken) continue;
      final rx = math.min((to - from) * 0.36, (near0 ? 92 : 46) * _u);
      final x = (from + to) / 2;
      pools.add((
        x - w * (x / w).floorToDouble(),
        _h * (near0 ? 0.9 : 0.705),
        rx,
        rx * 0.2,
        401 + k++ + (near0 ? 0 : 10),
      ));
    }
    return pools;
  }

  /// The last pools on [layer] as built: each one's span.
  @visibleForTesting
  List<Rect> debugPools(SceneLayer layer) => [
    for (final (x, y, rx, ry, _) in _pools[layer] ?? const <_Pool>[])
      Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2),
  ];

  /// A pool's shore: an oval, uneven.
  List<Offset> _poolEdge(_Pool p, {double grow = 1}) {
    final (x, y, rx, ry, seed) = p;
    return [
      for (var k = 0; k < 28; k++)
        () {
          final a = k / 28 * math.pi * 2;
          final r =
              grow *
              (1 +
                  0.14 * fieldLoopNoise(k / 28, 1 / 5, seed, 1) +
                  0.06 * fieldLoopNoise(k / 28, 1 / 11, seed + 1, 1));
          return Offset(x + math.cos(a) * rx * r, y + math.sin(a) * ry * r);
        }(),
    ];
  }

  bool _inPoolOf(
    _Pool p,
    double x,
    double y,
    SceneLayer layer, {
    double grow = 1,
  }) {
    final (px, py, rx, ry, _) = p;
    final dx = _loopDelta(x, px, layer) / (rx * grow);
    final dy = (y - py) / (ry * grow);
    return dx * dx + dy * dy < 1;
  }

  /// The dried floor of [layer], for a mud-graded sheet: dark ground that
  /// shows in the cracks, the floor broken into plates over it — wider and
  /// deeper nearer, each lit a little at its curled top edge — darker wet
  /// ground round the last pools, and the pools. The back layer's reaches
  /// right to the strip of water left along the far shore, where it is too
  /// far off to see cracks: only speckle.
  void _paintMud(Canvas c, double w, SceneLayer layer) {
    final (top, cracks, bottom) = layer == mid
        ? (_h * (_dryShore - 0.004), _h * 0.648, _h * 0.82)
        : (_h * 0.765, _h * 0.765, _h + 4 * _u);
    final pools = _pools[layer] ?? const <_Pool>[];
    final fade = math.min(0.4, 6 * _u / (bottom - top));
    c.drawRect(
      Rect.fromLTRB(-4, top, w + 4, bottom),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, top),
          Offset(0, bottom),
          [
            fieldMap(_mudHaze(top), 0, 0.42, 0),
            fieldMap(_mudHaze(top + (bottom - top) * fade), 0, 0.42, 1),
            fieldMap(_mudHaze(bottom), 0, 0.55, 1),
          ],
          [0.0, fade, 1.0],
        ),
    );
    if (cracks > top) {
      final grains = GrainBatch(2);
      final r = FieldRandom(67);
      final span = cracks + 8 * _u - top;
      for (var i = 0; i < (w * span / (_u * _u * 5)).round(); i++) {
        final x = r.next() * w;
        final y = top + 2 * _u + r.next() * (span - 2 * _u);
        grains.add(r.next() < 0.55 ? 0 : 1, x, y);
      }
      final hz = _mudHaze(top) * 0.8;
      grains
        ..draw(c, 0, 1.1 * _u, fieldMap(hz, 0, 0.75, 0.5))
        ..draw(c, 1, 1.0 * _u, fieldMap(hz, 0.3, 0.05, 0.45));
    }
    // Wet ground round each pool, smooth, no cracks in it.
    for (final p in pools) {
      _wrapped(p.$1, p.$3 * 1.8, w, (x) {
        final (_, y, rx, ry, _) = p;
        c
          ..save()
          ..translate(x, y)
          ..scale(rx * 1.7 / (ry * 2.4), 1)
          ..drawCircle(
            Offset.zero,
            ry * 2.4,
            Paint()
              ..shader = Gradient.radial(
                Offset.zero,
                ry * 2.4,
                [
                  fieldMap(_mudHaze(y), 0, 0.82),
                  fieldMap(_mudHaze(y), 0, 0.68, 0.7),
                  fieldMap(_mudHaze(y), 0, 0.5, 0),
                ],
                const [0.0, 0.5, 1.0],
              ),
          )
          ..restore();
      });
    }

    // The plates: a crack network over the floor, the cells flattened the
    // way the floor lies and growing toward the viewer, so the cracks run
    // mostly along it.
    for (final cell in _mudCells(layer, w, cracks, bottom)) {
      final (pts, cx, cy, size, id) = cell;
      // Wet near a pool: darker, and none at all in it.
      var wet = 0.0;
      var inside = false;
      for (final q in pools) {
        for (final dx in [0.0, -w, w]) {
          final (px, py, rx, ry, _) = q;
          final ex = (cx + dx - px) / rx, ey = (cy - py) / ry;
          final e = math.sqrt(ex * ex + ey * ey);
          if (e < 1.12) inside = true;
          wet = math.max(wet, (1 - (e - 1.1) / 0.9).clamp(0.0, 1.0));
        }
      }
      if (inside) continue;
      // Plates dry unevenly: some crusted pale, some still dark. The first
      // rows come out of the speckle gradually.
      final own = (fieldHash(id, 691) - 0.5) * 0.22;
      final crust = fieldHash(id, 692) < 0.12 ? 0.12 : 0.0;
      final hz = _mudHaze(cy);
      final a = cracks > top
          ? ((cy - cracks) / (16 * _u)).clamp(0.2, 1.0)
          : 1.0;
      for (final dx in [0.0, if (cx > w - size * 3) -w, if (cx < size * 3) w]) {
        final at = [for (final q in pts) q.translate(dx, 0)];
        var y0 = double.infinity, y1 = -double.infinity;
        for (final q in at) {
          y0 = math.min(y0, q.dy);
          y1 = math.max(y1, q.dy);
        }
        c.drawPath(
          Path()..addPolygon(at, true),
          Paint()
            ..shader = Gradient.linear(Offset(0, y0), Offset(0, y1), [
              fieldMap(
                hz,
                (0.14 + crust) * (1 - wet),
                0.08 + own + 0.4 * wet,
                a,
              ),
              fieldMap(hz, 0.03 + crust * 0.5, 0.22 + own + 0.4 * wet, a),
            ]),
        );
      }
    }
    _paintPools(c, w, layer);
  }

  /// Gone dry, whatever wades in a last pool stands in it: the near part
  /// of the pool's water drawn again over its feet, from a little above
  /// where they stand, with the light catching the water round its legs.
  void _paintWading(Canvas canvas, FieldView view, SceneLayer layer) {
    final d = dry;
    if (d < 0.01) return;
    for (final p in _spawns) {
      if (p.anchor != layer || p.perch != SpawnPerch.wade) continue;
      final pool = (_pools[layer] ?? const <_Pool>[])
          .where((q) => (q.$1 - _spawnX(p)).abs() < 1)
          .firstOrNull;
      if (pool == null) continue;
      final (px, py, rx, ry, seed) = pool;
      final line = _feet(p) - p.size.y * 0.07;
      for (final shift in _shiftsFor(layer, view, rx * 1.3)) {
        final x = px + shift;
        if (x + rx < view.left || x - rx > view.right) continue;
        final edge = _poolEdge((x, py, rx, ry, seed));
        final top = py - ry, bottom = py + ry * 1.25;
        canvas
          ..save()
          ..clipRect(
            Rect.fromLTRB(x - rx * 1.3, line - 2 * _u, x + rx * 1.3, bottom),
          )
          ..drawPath(
            Path()..addPolygon(edge, true),
            Paint()
              ..shader = Gradient.linear(Offset(0, top), Offset(0, py + ry), [
                _mudAt(0.95, 0.22),
                _mudAt(0.6, 0.62),
              ])
              ..color = const Color(0xFF000000).withValues(alpha: d),
          )
          ..restore();
        // The water round its legs.
        _rippleBatch.clear();
        final t = view.time;
        final half = p.size.x * 0.32;
        for (var k = 0; k < 14; k++) {
          final f = k / 13 * 2 - 1;
          final shimmer = 0.5 + 0.5 * math.sin(t * 2.2 + k * 1.3);
          if (shimmer < 0.35) continue;
          _rippleBatch.add(
            shimmer > 0.8 ? 1 : 0,
            x + f * half,
            line + (1 - f * f) * 1.6 * _u,
          );
        }
        final col = Color.lerp(
          _light.skyAt(0.47),
          const Color(0xFFFFFFFF),
          0.35,
        )!.withValues(alpha: 0.5 * d);
        _rippleBatch
          ..draw(canvas, 0, 1.4 * _u, col)
          ..draw(canvas, 1, 1.7 * _u, col.withValues(alpha: 0.8 * d));
      }
    }
  }

  /// The cracked floor of [layer] between [top] and [bottom]: one polygon
  /// per plate — (outline, middle x, middle y, size, id) — cut as a crack
  /// network: sites scattered thinner toward the far side, each plate the
  /// ground nearer its site than any other, measured with depth stretched
  /// so the plates lie flat; drawn in from the cracks, edges a little wavy.
  /// Repeats round the loop.
  List<(List<Offset>, double, double, double, int)> _mudCells(
    SceneLayer layer,
    double w,
    double top,
    double bottom,
  ) {
    final horizon = _h * 0.575;
    final k = layer == mid ? 0.1 : 0.085;
    const stretch = 2.6;
    final seed = layer == mid ? 610 : 650;
    // Sites, row by row; a row's spacing follows its depth.
    final sites = <Offset>[];
    final sizes = <double>[];
    var y = top + 2 * _u;
    var row = 0;
    while (y < bottom + 6 * _u) {
      final rh = k * (y - horizon);
      final pw = rh * stretch * (0.9 + 0.5 * fieldHash(row, seed));
      final n = math.max(3, (w / pw).round());
      for (var i = 0; i < n; i++) {
        final jx = fieldHash(i * 2, seed + row * 7) - 0.5;
        final jy = fieldHash(i * 2 + 1, seed + row * 7) - 0.5;
        sites.add(Offset((i + 0.5 + jx * 0.8) * w / n, y + jy * rh * 0.9));
        sizes.add(rh);
      }
      y += rh * (0.85 + 0.3 * fieldHash(row, seed + 3));
      row++;
    }
    // A grid of them, to find each one's neighbours fast.
    final cellW = 80.0 * _u, cellH = 80.0 * _u / stretch;
    final grid = <int, List<int>>{};
    int key(int gx, int gy) => gx * 7919 + gy;
    final cols = math.max(1, (w / cellW).ceil());
    for (var i = 0; i < sites.length; i++) {
      final gx = (sites[i].dx / cellW).floor() % cols;
      final gy = (sites[i].dy / cellH).floor();
      grid.putIfAbsent(key(gx, gy), () => []).add(i);
    }
    final out = <(List<Offset>, double, double, double, int)>[];
    for (var i = 0; i < sites.length; i++) {
      final p = sites[i];
      final rh = sizes[i];
      if (p.dy < top - rh || p.dy > bottom + rh) continue;
      // Start from a box round it; cut away what is nearer each neighbour.
      final r = rh * stretch * 1.6;
      var poly = <Offset>[
        Offset(p.dx - r, (p.dy - r / stretch) * stretch),
        Offset(p.dx + r, (p.dy - r / stretch) * stretch),
        Offset(p.dx + r, (p.dy + r / stretch) * stretch),
        Offset(p.dx - r, (p.dy + r / stretch) * stretch),
      ];
      final ps = Offset(p.dx, p.dy * stretch);
      final gx = (p.dx / cellW).floor(), gy = (p.dy / cellH).floor();
      for (var ix = gx - 2; ix <= gx + 2; ix++) {
        for (var iy = gy - 2; iy <= gy + 2; iy++) {
          final wrapX = ix < 0 ? -w : (ix >= cols ? w : 0.0);
          for (final j in grid[key(ix % cols, iy)] ?? const <int>[]) {
            if (j == i && wrapX == 0) continue;
            final q = Offset(sites[j].dx + wrapX, sites[j].dy * stretch);
            final d = q - ps;
            if (d.distanceSquared < 1e-6) continue;
            final m = (q + ps) / 2;
            poly = _clipHalf(poly, m, d);
            if (poly.length < 3) break;
          }
        }
      }
      if (poly.length < 3) continue;
      // Back to the floor, drawn in from the cracks, edges a little wavy.
      final crack = (0.45 + 0.09 * rh / _u) * _u;
      var cx = 0.0, cy = 0.0;
      for (final q in poly) {
        cx += q.dx;
        cy += q.dy / stretch;
      }
      cx /= poly.length;
      cy /= poly.length;
      final pts = <Offset>[];
      for (var e = 0; e < poly.length; e++) {
        final a = Offset(poly[e].dx, poly[e].dy / stretch);
        final b = Offset(
          poly[(e + 1) % poly.length].dx,
          poly[(e + 1) % poly.length].dy / stretch,
        );
        for (var s = 0; s < 2; s++) {
          final q = Offset.lerp(a, b, s / 2)!;
          final wob = s == 0
              ? Offset.zero
              : Offset(0, (fieldHash(i * 13 + e, seed + 5) - 0.5) * rh * 0.14);
          final toMid = Offset(cx, cy) - q;
          final len = toMid.distance;
          final inset = len > crack * 2 ? toMid / len * crack : toMid * 0.4;
          pts.add(q + inset + wob);
        }
      }
      if (cy < top - 2 * _u) continue;
      out.add((pts, cx, cy, rh, i));
    }
    return out;
  }

  /// [poly] with what lies past the bisector through [m], facing [d], cut
  /// away.
  static List<Offset> _clipHalf(List<Offset> poly, Offset m, Offset d) {
    double side(Offset q) => (q.dx - m.dx) * d.dx + (q.dy - m.dy) * d.dy;
    final out = <Offset>[];
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      final sa = side(a), sb = side(b);
      if (sa <= 0) out.add(a);
      if ((sa <= 0) != (sb <= 0)) {
        final t = sa / (sa - sb);
        out.add(Offset.lerp(a, b, t)!);
      }
    }
    return out;
  }

  /// The last water: each pool the sky in it, murkier toward its near
  /// side. On the mud's own sheet: its grade's haze is the colour of the
  /// sky low down, which is what still water holds.
  void _paintPools(Canvas c, double w, SceneLayer layer) {
    for (final p in _pools[layer] ?? const <_Pool>[]) {
      _wrapped(p.$1, p.$3 * 1.3, w, (x) {
        final at = (x, p.$2, p.$3, p.$4, p.$5);
        c.drawPath(
          Path()..addPolygon(_poolEdge(at), true),
          Paint()
            ..shader = Gradient.linear(
              Offset(0, p.$2 - p.$4),
              Offset(0, p.$2 + p.$4),
              [fieldMap(0.95, 0, 0.22), fieldMap(0.6, 0, 0.62)],
            ),
        );
      });
    }
  }

  /// Where the water used to stand on whatever stood in it: the part that
  /// was under water, stained dark, from a pale tide line down to the dried
  /// floor. On the floor's sheet, under the banks and trees: each band
  /// starts right at the foot of what it belongs to.
  void _paintFeet(
    Canvas c,
    double w,
    SceneLayer layer,
    List<_Cypress> trees,
    List<_Bank> banks,
  ) {
    final drop = _drop(layer);
    void band(List<Offset> topEdge, double depth, double y, {double line = 1}) {
      final hz = _mudHaze(y) + (layer == mid ? 0.3 : 0);
      final stain = Path()
        ..addPolygon([
          ...topEdge,
          for (final p in topEdge.reversed)
            p.translate(0, depth * (0.9 + 0.2 * fieldHash(p.dx.round(), 7))),
        ], true);
      c.drawPath(
        stain,
        Paint()
          ..shader = Gradient.linear(Offset(0, y), Offset(0, y + depth), [
            fieldMap(hz, 0, 0.88),
            fieldMap(hz, 0, 0.62),
          ]),
      );
      // The tide line: a crust of pale silt where the water stood longest.
      c.drawPath(
        Path()..addPolygon([
          ...topEdge,
          for (final p in topEdge.reversed) p.translate(0, 1.3 * _u),
        ], true),
        Paint()..color = fieldMap(hz, 0.35, 0.04, 0.85 * line),
      );
    }

    for (final b in banks) {
      _wrapped(b.cx, b.hw + b.flare + 8 * _u, w, (x) {
        final dx = x - b.cx;
        final x0 = b.cx - b.hw - b.flare, x1 = b.cx + b.hw + b.flare;
        band(
          [
            for (var px = x0; px <= x1; px += 2.5 * _u)
              Offset(px + dx, _waterEdge(b, px)),
            Offset(x1 + dx, _waterEdge(b, x1)),
          ],
          drop,
          _bWater(b),
        );
      });
    }
    for (final t in trees) {
      _wrapped(t.x, t.wb * 1.6, w, (x) {
        final dx = x - t.x;
        final hw = t.half(0);
        band(
          [
            for (var k = 0; k <= 8; k++)
              Offset(x - hw * 1.02 + hw * 2.04 * k / 8, t.base),
          ],
          drop,
          t.base,
          line: 0.45,
        );
        for (final (kx, ky, _, wd) in t.knees) {
          band(
            [
              Offset(kx + dx - wd / 2, ky + 1.2 * _u),
              Offset(kx + dx + wd / 2, ky + 1.2 * _u),
            ],
            drop * 0.6,
            ky,
          );
        }
      });
    }
  }

  /// The near pool a finger at [x], [y] is in, if any.
  bool _inPool(double x, double y) =>
      (_pools[near] ?? const <_Pool>[]).any((p) => _inPoolOf(p, x, y, near));

  /// Whether a finger at [x], [y] on the near layer is on the dried floor.
  bool _onMud(double x, double y) {
    if (y < _h * (0.765 + 0.02)) return false;
    final at = _bankAt(near, x, reach: 1.02);
    if (at != null && y < _bWater(at.$1) + 2 * _u) return false;
    return !_inPool(x, y);
  }

  // Dust a finger raises off the dried floor: kept in the near layer's
  // units, drifting off on the wind and settling.
  final _Drift _dust = _Drift(420);
  final GrainBatch _dustBatch = GrainBatch(3);

  /// A finger across the dried floor: dust lifts off it and trails after
  /// it, curling as it slows; a tap throws up a low lopsided puff of it.
  void _raiseDust(
    double x,
    double y,
    double dir,
    double speed, {
    required bool tap,
  }) {
    final d = _dust;
    if (tap) {
      // Lopsided and low, never a ring: most of it slow and close to the
      // ground, some rolling further out, all of it rising a little.
      final lean = d.rand() < 0.5 ? -1.0 : 1.0;
      for (var k = 0; k < 64; k++) {
        final a = -math.pi * (0.05 + 0.9 * d.rand());
        final out = (10 + 90 * math.pow(d.rand(), 1.7)) * _u;
        final bias = 0.45 + 0.55 * (math.cos(a) * lean * 0.5 + 0.5);
        d.spawn(
          x: x + (d.rand() - 0.5) * 14 * _u,
          y: y - d.rand() * 4 * _u,
          vx: math.cos(a) * out * bias * 1.5,
          vy: math.sin(a) * out * bias * 0.55 - 8 * _u,
          life: 1.3 + d.rand() * 1.9,
          spin: (d.rand() - 0.5) * 2.4,
        );
      }
      return;
    }
    final pace = math.min(1.0, speed / (5 * _u));
    final n = 2 + (pace * 5).round();
    for (var k = 0; k < n; k++) {
      d.spawn(
        x: x + (d.rand() - 0.5) * 16 * _u,
        y: y - d.rand() * 5 * _u,
        vx: dir * (24 + d.rand() * 60) * _u * pace + (d.rand() - 0.5) * 18 * _u,
        vy: -(10 + d.rand() * 30) * _u,
        life: 1.5 + d.rand() * 1.8,
        spin: (d.rand() < 0.5 ? -1 : 1) * (0.4 + d.rand()),
      );
    }
  }

  void _paintDust(Canvas canvas, FieldView view) {
    final d = _dust;
    final dt = d.clock < 0 ? 0.0 : (view.time - d.clock).clamp(0.0, 0.1);
    d.clock = view.time;
    if (!d.any) return;
    final (wind, _) = _wind(
      (view.left + view.right) / 2,
      view.time,
      _nearWidth,
    );
    d.step(dt, drag: 1.5, lift: 7 * _u, windX: wind * 34 * _u);
    _dustBatch.clear();
    var any = false;
    for (var i = 0; i < d.cap; i++) {
      if (d.life[i] <= 0) continue;
      final f = d.age[i] / d.life[i];
      final fade = math.min(1.0, f * 8) * (1 - f);
      final level = (fade * 2.99).floor();
      if (level <= 0) continue;
      _dustBatch.add(level - 1, d.x[i], d.y[i]);
      any = true;
    }
    if (!any) return;
    // The floor's own colour, lifted and lit: dust in the air catches the
    // light the cracked ground under it does not.
    final col = Color.lerp(
      _mudAt(0.25, -0.15),
      Color.lerp(_light.mote, _light.rim, 0.3 * _light.rimStrength),
      0.35,
    )!;
    for (var lv = 0; lv < 3; lv++) {
      _dustBatch
        ..draw(canvas, lv, 11 * _u, col.withValues(alpha: 0.06 * (lv + 1)))
        ..draw(canvas, lv, 3.2 * _u, col.withValues(alpha: 0.2 * (lv + 1)));
    }
  }

  // ── Touching the water ───────────────────────────────────────────────────

  /// Where fingers have gone into the water lately: (x, y, when, how hard),
  /// the rings running out from each.
  final List<(double, double, double, double)> _wakes = [];
  double _routed = -1;
  double _lastWake = -1;

  /// Sends this frame's new fingers on the near layer to what is under
  /// them: a bank's grass stirs itself; water splashes and rings; the
  /// dried floor gives up dust.
  void _route(FieldView view) {
    var newest = _routed;
    for (final t in view.touches) {
      if (t.time <= _routed) continue;
      if (t.time > newest) newest = t.time;
      final moved = math.sqrt(t.dx * t.dx + t.dy * t.dy);
      final tap = moved < 0.5;
      final n = view.local(t.x, t.y);
      final speed = moved / view.zoom;
      // Gone dry, the floor gives up dust; only the last pools ring.
      if (dry > 0.5) {
        if (_onMud(n.dx, n.dy)) {
          _raiseDust(n.dx, n.dy, t.dx.sign, speed, tap: tap);
          continue;
        }
        if (!_inPool(n.dx, n.dy)) continue;
      } else if (!_onWater(n.dx, n.dy)) {
        continue;
      }
      if (tap) {
        _wakes.add((n.dx, n.dy, t.time, 1));
        _splash(n.dx, n.dy, 0, 0, count: 12);
      } else if (t.time - _lastWake > 0.07) {
        _lastWake = t.time;
        _wakes.add((
          n.dx,
          n.dy,
          t.time,
          math.min(0.7, 0.35 + speed / (20 * _u)),
        ));
        if (_drops.rand() < 0.5) {
          _splash(n.dx, n.dy, t.dx.sign, speed, count: 2);
        }
      }
    }
    _routed = newest;
    _wakes.removeWhere((w) => view.time - w.$3 > 1.6 || w.$3 > view.time);
    if (_wakes.length > 24) _wakes.removeRange(0, _wakes.length - 24);
  }

  /// Whether near water at [x], [y] is hidden behind a bank or a tree
  /// standing in it — or, gone dry, is not water at all.
  bool _standsIn(double x, double y) {
    // Gone dry, there is water only in the last pools.
    if (dry > 0.5 && !_inPool(x, y)) return true;
    for (final b in _banks[near] ?? const <_Bank>[]) {
      final d = _loopDelta(x, b.cx, near);
      if (d.abs() < b.hw + b.flare && y < _bWater(b) + 1 * _u) return true;
    }
    for (final t in _trees[near] ?? const <_Cypress>[]) {
      final d = _loopDelta(x, t.x, near);
      if (d.abs() < t.wb * 0.5 && y < t.base + 1 * _u) return true;
    }
    return false;
  }

  void _splash(
    double x,
    double y,
    double dir,
    double speed, {
    required int count,
  }) {
    final d = _drops;
    for (var k = 0; k < count; k++) {
      final a = d.rand() * math.pi;
      d.spawn(
        x: x + (d.rand() - 0.5) * 6 * _u,
        y: y - d.rand() * 2 * _u,
        vx: math.cos(a) * (14 + d.rand() * 46) * _u + dir * speed * 3,
        vy: -(30 + d.rand() * 80) * _u * math.sin(a),
        life: 0.45 + d.rand() * 0.4,
      );
    }
  }

  /// The duckweed under the fingers: a finger pressing in pushes it aside,
  /// and it drifts slowly back; a tap's ring pushes it out as it passes.
  void _stirWeed(_Weed g, FieldView view) {
    final stirs = _stirsFor(near, view);
    final now = view.time;
    final dt = g.clock < 0 ? 0.0 : (now - g.clock).clamp(0.0, 1 / 30);
    g.clock = now;
    // Dried to a crust on the mud, it does not move.
    if (dry > 0.5) return;
    final period = _period(near);
    final reach = 26 * _u;
    final live = <_Stir>[
      for (final p in stirs)
        if (now - p.time < _GrainField._hold) p,
    ];
    final rings = <(double, double, double, double)>[
      for (final w in _wakes)
        if (now - w.$3 < 1.4) w,
    ];
    final wave = _ringSpeed * _u, band = 8 * _u;
    for (final (cx0, r) in [
      for (final p in live) (p.x, reach),
      for (final w in rings) (w.$1, wave * (now - w.$3) + band * 2),
    ]) {
      final local = period > 0 ? cx0 - period * (cx0 / period).floor() : cx0;
      for (final c in [local, if (period > 0) local - period, local + period]) {
        if (c + r < 0 || c - r > (period > 0 ? period : _nearWidth)) continue;
        final a = g.firstAt(c - r), z = g.firstAt(c + r) - 1;
        if (z < a) continue;
        if (g.hi < g.lo) {
          g
            ..lo = a
            ..hi = z;
        } else {
          g.lo = math.min(g.lo, a);
          g.hi = math.max(g.hi, z);
        }
      }
    }
    if (g.hi < g.lo || dt <= 0) return;
    const k = 7.0, damp = 2.2;
    final cap = 20 * _u;
    var lo = g.n, hi = -1;
    for (var i = g.lo; i <= g.hi; i++) {
      final px = g.x[i] + g.dx[i], py = g.y[i] + g.dy[i];
      var ax = -k * g.dx[i] - damp * g.vx[i];
      var ay = -k * g.dy[i] - damp * g.vy[i];
      for (final p in live) {
        final ddx = period > 0 ? _loopDelta(px, p.x, near) : px - p.x;
        final ddy = (py - p.y) * 2.4;
        final d2 = ddx * ddx + ddy * ddy;
        if (d2 > reach * reach) continue;
        final d = math.sqrt(d2) + 0.5 * _u;
        final hold = (1 - d / reach) * (1 - (now - p.time) / _GrainField._hold);
        ax += ddx / d * 1100 * _u * hold;
        ay += ddy / d * 1100 * _u * hold / 2.4 * 0.5;
        ax += p.dir * math.min(1.0, p.speed / (8 * _u)) * 320 * _u * hold;
      }
      for (final (wx, wy, t0, strength) in rings) {
        final ddx = period > 0 ? _loopDelta(px, wx, near) : px - wx;
        final ddy = (py - wy) * 2.4;
        final d = math.sqrt(ddx * ddx + ddy * ddy) + 0.5 * _u;
        final age = now - t0;
        final off = (d - wave * age) / band;
        if (off.abs() > 2.5) continue;
        final kick = 620 * _u * strength * math.exp(-off * off - age * 2.4);
        ax += ddx / d * kick;
        ay += ddy / d * kick / 2.4 * 0.5;
      }
      var vx = g.vx[i] + ax * dt, vy = g.vy[i] + ay * dt;
      var dx = g.dx[i] + vx * dt, dy = g.dy[i] + vy * dt;
      if (dx.abs() > cap) {
        dx = dx.sign * cap;
        vx *= 0.5;
      }
      if (dy.abs() > cap * 0.3) {
        dy = dy.sign * cap * 0.3;
        vy *= 0.5;
      }
      if (dx.abs() < 0.02 * _u &&
          dy.abs() < 0.02 * _u &&
          vx.abs() < 0.05 * _u &&
          vy.abs() < 0.05 * _u) {
        dx = dy = vx = vy = 0;
      } else {
        if (i < lo) lo = i;
        hi = i;
      }
      g
        ..dx[i] = dx
        ..dy[i] = dy
        ..vx[i] = vx
        ..vy[i] = vy;
    }
    g
      ..lo = lo
      ..hi = hi;
  }

  /// How fast a ring runs out across the water, in units a second at the
  /// reference height.
  static const _ringSpeed = 70.0;

  void _paintWeed(Canvas canvas, FieldView view, _Weed g) {
    _weedBatch.clear();
    final t = view.time;
    final margin = 30 * _u;
    for (final shift in _shiftsFor(near, view, margin)) {
      final start = g.firstAt(view.left - margin - shift);
      for (var i = start; i < g.n; i++) {
        final x = g.x[i] + shift;
        if (x > view.right + margin) break;
        final bob = 0.6 * _u * math.sin(t * 0.5 + i * 1.7) * _wet;
        final moving = math.min(
          1.0,
          (g.vx[i].abs() + g.vy[i].abs()) / (40 * _u),
        );
        var tone = math.min(3, g.tone[i] + (moving > 0.4 ? 1 : 0));
        // Dried to a crust its shades all but merge: two will do; and none
        // of it lies in the last pools.
        if (dry > 0.5) {
          tone = tone >> 1;
          if (_inPool(g.x[i], g.y[i])) continue;
        }
        _weedBatch.add(
          tone * 2 + g.size[i],
          x + g.dx[i] + bob,
          g.y[i] + g.dy[i],
        );
      }
    }
    final grass = _light.grass;
    final a = _light.ambient;
    final murk = Color.from(
      alpha: 1,
      red: 0.12 * a.r,
      green: 0.34 * a.g,
      blue: 0.28 * a.b,
    );
    // Gone dry it is a pale crust, the colour of the floor it lies on.
    final d = dry;
    for (var tone = 0; tone < 4; tone++) {
      var col = Color.lerp(
        Color.lerp(grass[tone], grass[tone + 1], 0.6)!,
        murk,
        0.35 - tone * 0.06,
      )!;
      if (d > 0) {
        col = Color.lerp(col, _mudAt(0, 0.35 - tone * 0.12), 0.7 * d)!;
      }
      for (var s = 0; s < 2; s++) {
        _weedBatch.draw(
          canvas,
          tone * 2 + s,
          (s == 0 ? 1.8 : 2.4) * _u,
          col.withValues(alpha: 0.9),
        );
      }
    }
  }

  /// The rings running out from where fingers went into the water. Seen
  /// this low across the water a ring is only its far side catching the
  /// sky: a soft crest of light, brightest straight across from the finger,
  /// thinning round to the near side where it is all but gone; a tap sends
  /// a second, fainter one after the first. Where the finger went in, the
  /// water glows for a moment.
  void _paintRings(Canvas canvas, FieldView view) {
    if (_wakes.isEmpty) return;
    _rippleBatch.clear();
    final now = view.time;
    final col = Color.lerp(_light.skyAt(0.47), const Color(0xFFFFFFFF), 0.4)!;
    var any = false;
    for (final (wx, wy, t0, strength) in _wakes) {
      final age = now - t0;
      if (age < 0) continue;
      final life = 1.0 + 0.8 * strength;
      if (age > life) continue;
      final fade = math.pow(1 - age / life, 1.2) * (0.6 + 0.4 * strength);
      if (strength > 0.8 && age < 0.35) {
        final g = 1 - age / 0.35;
        final at = Offset(wx, wy);
        final r = (6 + 20 * age) * _u;
        canvas
          ..save()
          ..translate(at.dx, at.dy)
          ..scale(1, 1 / 2.4)
          ..drawCircle(
            Offset.zero,
            r,
            Paint()
              ..shader = Gradient.radial(Offset.zero, r, [
                col.withValues(alpha: 0.32 * g),
                col.withValues(alpha: 0),
              ]),
          )
          ..restore();
      }
      for (var ring = 0; ring < (strength > 0.8 ? 2 : 1); ring++) {
        final rad = _ringSpeed * _u * age * (1 - ring * 0.32) + 3 * _u;
        final n = (rad * math.pi * 2 / (2.6 * _u)).ceil().clamp(8, 180);
        final seed = (t0 * 1000).round() + ring * 31;
        for (var j = 0; j < n; j++) {
          final a = j / n * math.pi * 2;
          // Far side up: sin(a) < 0 is away from the viewer.
          final far = math.max(0.0, -math.sin(a));
          final side = 1 - math.sin(a).abs();
          final shape = math.min(1.0, 0.12 + far * 1.1 + side * 0.45);
          final wobble = 0.65 + 0.35 * fieldNoise(j / n * 9, seed);
          final bright = fade * shape * wobble * (1 - ring * 0.45);
          final level = (bright * 4.4).floor();
          if (level <= 0) continue;
          final gx = wx + math.cos(a) * rad, gy = wy + math.sin(a) * rad / 2.4;
          if (_standsIn(gx, gy)) continue;
          _rippleBatch.add(level >= 3 ? 1 : 0, gx, gy);
          any = true;
        }
      }
    }
    if (!any) return;
    for (var lv = 0; lv < 2; lv++) {
      _rippleBatch
        ..draw(canvas, lv, 4.2 * _u, col.withValues(alpha: 0.08 + 0.08 * lv))
        ..draw(canvas, lv, 1.6 * _u, col.withValues(alpha: 0.22 + 0.26 * lv));
    }
  }

  void _paintDrops(Canvas canvas, FieldView view) {
    final d = _drops;
    final dt = d.clock < 0 ? 0.0 : (view.time - d.clock).clamp(0.0, 0.1);
    d.clock = view.time;
    if (!d.any) return;
    d.step(dt, gravity: 300 * _u, drag: 0.5);
    _rippleBatch.clear();
    var any = false;
    for (var i = 0; i < d.cap; i++) {
      if (d.life[i] <= 0) continue;
      final f = d.age[i] / d.life[i];
      final level = ((1 - f) * 2.99).floor();
      if (level <= 0) continue;
      _rippleBatch.add(level - 1, d.x[i], d.y[i]);
      any = true;
    }
    if (!any) return;
    final water = Color.lerp(_light.skyAt(0.47), const Color(0xFFFFFFFF), 0.5)!;
    for (var lv = 0; lv < 2; lv++) {
      _rippleBatch.draw(
        canvas,
        lv,
        2.1 * _u,
        water.withValues(alpha: 0.5 + 0.35 * lv),
      );
    }
  }

  /// A cattail's head on a tall reed: a dark seed head a little below its
  /// tip.
  void _head(
    _Blades b,
    int i,
    double x,
    double y,
    double s,
    double c,
    double size,
  ) {
    if (b.height[i] < 30 * _u || fieldHash(i, 41) > 0.42) return;
    for (var k = 1; k <= 3; k++) {
      final back = (2.2 + k * size * 0.7) * _u;
      _headBatch.add(k == 2 ? 1 : 0, x - s * back, y + c * back);
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
      case mid:
        if (front) {
          _paintWading(canvas, view, mid);
          return;
        }
        _paintGlints(
          canvas,
          view,
          mid,
          _glints[mid],
          size: 0.85,
          alpha: 0.75 - 0.4 * _light.firefly,
        );
        _paintGlints(
          canvas,
          view,
          mid,
          _waterGlints[mid],
          size: 0.85,
          alpha: (0.75 - 0.4 * _light.firefly) * _wet,
        );
      case near:
        final pushes = _pushes(view);
        if (!front) {
          _route(view);
          _paintGlints(
            canvas,
            view,
            near,
            _glints[near],
            size: 1.2,
            alpha: 1 - 0.4 * _light.firefly,
          );
          _paintGlints(
            canvas,
            view,
            near,
            _waterGlints[near],
            size: 1.2,
            alpha: (1 - 0.4 * _light.firefly) * _wet,
          );
          final weed = _weed;
          if (weed != null) {
            _stirWeed(weed, view);
            _paintWeed(canvas, view, weed);
          }
          _paintRings(canvas, view);
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
          _headBatch.clear();
          _paintBlades(
            canvas,
            view,
            blades,
            _nearWidth,
            rows: front ? (4, 4) : (0, 3),
            fore: false,
            layer: near,
            tip: (i, x, y, s, c) => _head(blades, i, x, y, s, c, 2.4),
          );
          _drawHeads(canvas, 3.2);
        }
        if (front) {
          _paintWading(canvas, view, near);
          _paintKicked(canvas, view);
          _paintDust(canvas, view);
        }
      case fore:
        final reeds = _reeds;
        if (reeds == null) return;
        _stirBlades(
          reeds,
          fore,
          _foreWidth,
          view,
          reach: 52 * _u,
          maxBend: 0.8,
        );
        _headBatch.clear();
        _paintBlades(
          canvas,
          view,
          reeds,
          _foreWidth,
          rows: (0, 0),
          fore: true,
          layer: fore,
          tip: (i, x, y, s, c) => _head(reeds, i, x, y, s, c, 3.6),
        );
        _drawHeads(canvas, 5.0);
      default:
        break;
    }
  }

  void _drawHeads(Canvas canvas, double size) {
    final g = _light.grass;
    _headBatch
      ..draw(canvas, 0, size * _u, Color.lerp(g[0], g[2], 0.5)!)
      ..draw(canvas, 1, size * 1.1 * _u, Color.lerp(g[1], g[3], 0.5)!);
  }
}

/// One of the last pools of a dried-out Swamp: (x, y, half width, half
/// height, seed).
typedef _Pool = (double, double, double, double, int);

/// What part of a cypress a sheet holds.
enum _Part { bark, leaf, moss }

/// A bald cypress standing in the water. Its shape is laid out once by
/// [SwampField._shapeCypress].
class _Cypress {
  _Cypress(this.x, this.base, this.h, this.seed, this.haze);

  /// Where it stands, where the water meets it, and how tall it is.
  final double x, base, h;
  final int seed;

  /// How far off it is (0 near; a far tree is hazed).
  final double haze;

  late Offset Function(double f) spine;
  late double Function(double f) half;
  late double topF, footF, wb;
  late List<Offset> outline;
  late List<(double, double, double)> flutes;
  late List<(Offset, Offset, double)> limbs;
  late List<(Offset, double, double)> pads;

  /// (x, y, length, width, sway, shade) of each strand of moss.
  late List<(double, double, double, double, double, double)> moss;

  /// (x, y, height, width) of each knee.
  late List<(double, double, double, double)> knees;

  /// How far it reaches to either side, and the top of its crown.
  late double reach, top;

  /// The same tree moved to [x] — a copy drawn across a loop's seam.
  _Cypress at(double x) {
    if (x == this.x) return this;
    final dx = x - this.x;
    Offset move(Offset p) => p.translate(dx, 0);
    final t = _Cypress(x, base, h, seed, haze)
      ..spine = ((f) => move(spine(f)))
      ..half = half
      ..topF = topF
      ..footF = footF
      ..wb = wb
      ..outline = [for (final p in outline) move(p)]
      ..flutes = flutes
      ..limbs = [for (final (a, b, w) in limbs) (move(a), move(b), w)]
      ..pads = [for (final (o, rx, ry) in pads) (move(o), rx, ry)]
      ..moss = [
        for (final (mx, y, l, w, s, sh) in moss) (mx + dx, y, l, w, s, sh),
      ]
      ..knees = [for (final (kx, y, h, w) in knees) (kx + dx, y, h, w)]
      ..reach = reach
      ..top = top;
    return t;
  }
}

/// Solid ground in the Swamp: a stone of stone or a bank of peat, standing
/// up out of the water.
class _Bank {
  _Bank({
    required this.cx,
    required this.hw,
    required this.plate,
    required this.rise,
    required this.seed,
    required this.haze,
    required this.stone,
    this.flare = 0,
    this.steps = 0,
  });

  /// Its middle and half its width, in layer units, and how much wider a
  /// stone is at the water than at its top.
  final double cx, hw, flare;

  /// How deep its top is, and how far its lip stands above the water.
  final double plate, rise;
  final int seed;

  /// How far off it is (0 near; a far bank is hazed).
  final double haze;
  final bool stone;

  /// Which end of a stone steps down toward the water: -1 left, 1 right.
  final int steps;

  /// Where feet stand at its middle, less its unevenness there; set once
  /// it is seated.
  double level = 0;
}

/// Duckweed on the near water, sorted by x, each grain a slow spring that a
/// finger pushes aside.
class _Weed {
  _Weed(this.x, this.y, this.tone, this.size)
    : n = x.length,
      dx = Float32List(x.length),
      dy = Float32List(x.length),
      vx = Float32List(x.length),
      vy = Float32List(x.length);

  final Float32List x, y;
  final Uint8List tone, size;
  final int n;
  final Float32List dx, dy, vx, vy;

  /// The grains still moving, as an index range (empty when hi < lo), and
  /// when they were last moved.
  int lo = 0, hi = -1;
  double clock = -1;

  int firstAt(double left) {
    var lo = 0, hi = n;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (x[mid] < left) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}

// ── The Swamp's day ────────────────────────────────────────────────────────

const _swampNight = _Light(
  sky: [
    Color(0xFF020706),
    Color(0xFF040D0B),
    Color(0xFF071410),
    Color(0xFF0B1B16),
    Color(0xFF0F231C),
    Color(0xFF132920),
    Color(0xFF172F25),
    Color(0xFF1A3328),
    Color(0xFF1A3328),
  ],
  ambient: Color(0xFF1C2A27),
  rim: Color(0xFF9FD6C2),
  rimStrength: 0.22,
  floor: 0.35,
  glow: 0,
  stars: 0.8,
  cloudTop: Color(0xFF0A1411),
  cloudBottom: Color(0xFF182A24),
  cloudGlint: Color(0xFF7CB2A0),
  grass: [
    Color(0xFF040806),
    Color(0xFF070C09),
    Color(0xFF0A120E),
    Color(0xFF0F1914),
    Color(0xFF15221B),
    Color(0xFF1E3127),
    Color(0xFF2D4839),
    Color(0xFF4E7464),
  ],
  mote: Color(0xFFC6F27A),
  firefly: 1,
);

const _swampPreDawn = _Light(
  sky: [
    Color(0xFF030A0C),
    Color(0xFF061214),
    Color(0xFF0B1C1E),
    Color(0xFF132628),
    Color(0xFF1C3032),
    Color(0xFF263A3A),
    Color(0xFF304440),
    Color(0xFF384A44),
    Color(0xFF384A44),
  ],
  ambient: Color(0xFF253532),
  rim: Color(0xFFA6CCC4),
  rimStrength: 0.18,
  floor: 0.3,
  glow: 0.1,
  stars: 0.65,
  cloudTop: Color(0xFF0F1C1C),
  cloudBottom: Color(0xFF263836),
  cloudGlint: Color(0xFF86A8A2),
  grass: [
    Color(0xFF050A09),
    Color(0xFF080F0D),
    Color(0xFF0D1613),
    Color(0xFF131E1A),
    Color(0xFF1B2A24),
    Color(0xFF283A34),
    Color(0xFF3C5048),
    Color(0xFF647C72),
  ],
  mote: Color(0xFFC6F27A),
  firefly: 0.9,
);

const _swampDawn = _Light(
  sky: [
    Color(0xFF0A2024),
    Color(0xFF12302E),
    Color(0xFF1E4038),
    Color(0xFF34524A),
    Color(0xFF5A6656),
    Color(0xFF8A7C62),
    Color(0xFFB8946E),
    Color(0xFFD2A87A),
    Color(0xFFD2A87A),
  ],
  ambient: Color(0xFF4C5A4E),
  rim: Color(0xFFF0B494),
  rimStrength: 0.5,
  floor: 0.1,
  glow: 0.55,
  stars: 0.2,
  cloudTop: Color(0xFF2E423E),
  cloudBottom: Color(0xFFCC9C86),
  cloudGlint: Color(0xFFFFC8B0),
  grass: [
    Color(0xFF0A120F),
    Color(0xFF101A15),
    Color(0xFF18241C),
    Color(0xFF223024),
    Color(0xFF343E2C),
    Color(0xFF545438),
    Color(0xFF86745A),
    Color(0xFFC09C84),
  ],
  mote: Color(0xFFFFDCC4),
  firefly: 0.4,
);

const _swampSunrise = _Light(
  sky: [
    Color(0xFF1E4A48),
    Color(0xFF2C5E56),
    Color(0xFF447664),
    Color(0xFF6A8E72),
    Color(0xFFA2A67C),
    Color(0xFFD8BC84),
    Color(0xFFF4CE8E),
    Color(0xFFFCDA9C),
    Color(0xFFFCDA9C),
  ],
  ambient: Color(0xFF8C8E74),
  rim: Color(0xFFFFD48E),
  rimStrength: 0.95,
  floor: 0.1,
  glow: 1,
  stars: 0,
  cloudTop: Color(0xFF667C6E),
  cloudBottom: Color(0xFFF4C690),
  cloudGlint: Color(0xFFFFE2AA),
  grass: [
    Color(0xFF101A10),
    Color(0xFF182616),
    Color(0xFF22341C),
    Color(0xFF324624),
    Color(0xFF4C5C2E),
    Color(0xFF7C7C3E),
    Color(0xFFB8A05A),
    Color(0xFFF0D28E),
  ],
  mote: Color(0xFFFFE6AC),
  firefly: 0,
);

const _swampMorning = _Light(
  sky: [
    Color(0xFF3E8C76),
    Color(0xFF4E9C82),
    Color(0xFF66AC8E),
    Color(0xFF80BC9A),
    Color(0xFF98C8A2),
    Color(0xFFAAD0A8),
    Color(0xFFB6D6AE),
    Color(0xFFBCD8B2),
    Color(0xFFBCD8B2),
  ],
  ambient: Color(0xFFD4DEC8),
  rim: Color(0xFFF8F2CC),
  rimStrength: 0.32,
  floor: 0.5,
  glow: 0.5,
  stars: 0,
  cloudTop: Color(0xFFE4F0DA),
  cloudBottom: Color(0xFFA4C4A2),
  cloudGlint: Color(0xFFB8A874),
  grass: [
    Color(0xFF16220F),
    Color(0xFF203216),
    Color(0xFF2C441C),
    Color(0xFF3C5A24),
    Color(0xFF50722C),
    Color(0xFF6A8C36),
    Color(0xFF8EA64A),
    Color(0xFFB8C470),
  ],
  mote: Color(0xFFF0F6DA),
  firefly: 0,
);

const _swampDay = _Light(
  sky: [
    Color(0xFF4C9E84),
    Color(0xFF5CAA8E),
    Color(0xFF72B696),
    Color(0xFF88C29E),
    Color(0xFF9CCCA4),
    Color(0xFFAAD4A8),
    Color(0xFFB4D8AC),
    Color(0xFFBADAB0),
    Color(0xFFBADAB0),
  ],
  ambient: Color(0xFFF2F6EA),
  rim: Color(0xFFFFFFF0),
  rimStrength: 0.2,
  floor: 0.8,
  glow: 0.35,
  stars: 0,
  cloudTop: Color(0xFFEAF4DE),
  cloudBottom: Color(0xFFA6CAA4),
  cloudGlint: Color(0xFFBCB27A),
  grass: [
    Color(0xFF18240F),
    Color(0xFF223616),
    Color(0xFF2E4A1C),
    Color(0xFF3E6024),
    Color(0xFF52782C),
    Color(0xFF6C9236),
    Color(0xFF92AC4C),
    Color(0xFFBECA76),
  ],
  mote: Color(0xFFF2F8DE),
  firefly: 0,
);

const _swampAfternoon = _Light(
  sky: [
    Color(0xFF3E8274),
    Color(0xFF4C9080),
    Color(0xFF62A08A),
    Color(0xFF7EAE92),
    Color(0xFFA2B894),
    Color(0xFFC4C092),
    Color(0xFFDCC896),
    Color(0xFFE6CE9C),
    Color(0xFFE6CE9C),
  ],
  ambient: Color(0xFFD6CFA4),
  rim: Color(0xFFFFD898),
  rimStrength: 0.55,
  floor: 0.3,
  glow: 0.7,
  stars: 0,
  cloudTop: Color(0xFFE2E2CC),
  cloudBottom: Color(0xFFCCB088),
  cloudGlint: Color(0xFFFFDEAE),
  grass: [
    Color(0xFF16200E),
    Color(0xFF203014),
    Color(0xFF2C421A),
    Color(0xFF405822),
    Color(0xFF5C6E2C),
    Color(0xFF84883C),
    Color(0xFFB4A85A),
    Color(0xFFE4D290),
  ],
  mote: Color(0xFFFFEAB4),
  firefly: 0,
);

const _swampGolden = _Light(
  sky: [
    Color(0xFF10282A),
    Color(0xFF183634),
    Color(0xFF26483E),
    Color(0xFF425C48),
    Color(0xFF7C7E58),
    Color(0xFFBC9C62),
    Color(0xFFE4B466),
    Color(0xFFFAD08A),
    Color(0xFFFAD08A),
  ],
  ambient: Color(0xFF5E5A42),
  rim: Color(0xFFFFD088),
  rimStrength: 1,
  floor: 0.06,
  glow: 1,
  stars: 0,
  cloudTop: Color(0xFF22383A),
  cloudBottom: Color(0xFFDCA46C),
  cloudGlint: Color(0xFFFFDA9C),
  grass: [
    Color(0xFF0D140E),
    Color(0xFF141E14),
    Color(0xFF1D2A1A),
    Color(0xFF2C3A22),
    Color(0xFF4A542C),
    Color(0xFF7C743C),
    Color(0xFFBA9C58),
    Color(0xFFEECC86),
  ],
  mote: Color(0xFFFFDE9C),
  firefly: 0,
);

const _swampSunset = _Light(
  sky: [
    Color(0xFF0A1C20),
    Color(0xFF102828),
    Color(0xFF1C3632),
    Color(0xFF34443C),
    Color(0xFF6A5644),
    Color(0xFFB46A4E),
    Color(0xFFE28A52),
    Color(0xFFF4A660),
    Color(0xFFF4A660),
  ],
  ambient: Color(0xFF3E3A2E),
  rim: Color(0xFFFFA464),
  rimStrength: 0.95,
  floor: 0.06,
  glow: 1,
  stars: 0.05,
  cloudTop: Color(0xFF1A2A2C),
  cloudBottom: Color(0xFFE6865E),
  cloudGlint: Color(0xFFFFBC86),
  grass: [
    Color(0xFF0A0F0C),
    Color(0xFF111812),
    Color(0xFF182218),
    Color(0xFF242E1F),
    Color(0xFF3A3C27),
    Color(0xFF665634),
    Color(0xFFA47646),
    Color(0xFFDC9860),
  ],
  mote: Color(0xFFFFC88C),
  firefly: 0.15,
);

const _swampDusk = _Light(
  sky: [
    Color(0xFF040E0E),
    Color(0xFF081816),
    Color(0xFF0F2420),
    Color(0xFF182E28),
    Color(0xFF243630),
    Color(0xFF343E36),
    Color(0xFF46483C),
    Color(0xFF4E4C3E),
    Color(0xFF4E4C3E),
  ],
  ambient: Color(0xFF222A26),
  rim: Color(0xFFD8A48A),
  rimStrength: 0.24,
  floor: 0.2,
  glow: 0.4,
  stars: 0.45,
  cloudTop: Color(0xFF0E1A18),
  cloudBottom: Color(0xFF34362E),
  cloudGlint: Color(0xFF9C8C7C),
  grass: [
    Color(0xFF050907),
    Color(0xFF09100C),
    Color(0xFF0E1712),
    Color(0xFF141F18),
    Color(0xFF1C2A20),
    Color(0xFF2A382C),
    Color(0xFF424A3E),
    Color(0xFF6C6858),
  ],
  mote: Color(0xFFD8F28A),
  firefly: 0.75,
);

/// The day, keyed by hour. The night window lines up with the encounter
/// tables' (20:00–05:00).
const _swampKeys = <(double, _Light)>[
  (0, _swampNight),
  (4.4, _swampNight),
  (5.0, _swampPreDawn),
  (5.6, _swampDawn),
  (6.4, _swampSunrise),
  (7.8, _swampMorning),
  (10.0, _swampDay),
  (15.5, _swampDay),
  (17.6, _swampAfternoon),
  (18.7, _swampGolden),
  (19.4, _swampSunset),
  (20.1, _swampDusk),
  (21.0, _swampNight),
  (24, _swampNight),
];
