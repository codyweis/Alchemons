import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:alchemons/games/wilderness/field/field_art.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:flutter/foundation.dart' show visibleForTesting;

part 'sky_field.dart';
part 'swamp_field.dart';
part 'valley_field.dart';
part 'volcano_field.dart';

// What every field drawn in grains shares: the hour and its light, the sun
// and the moon (in its real phase) on the phone's clock, the loop, glints
// gathered while light sheets bake, grass made of grains that a finger
// parts, the grains it sheds, and the drawing tools the fields are made
// with (ridges, rim light, grain clouds, trees). Each field is a part of
// this library, so it reaches all of it directly.

/// Light sheets are white; these are the strengths of their grains.
const _sparkAlpha = [0.35, 0.55, 0.8, 1.0];

abstract class _GrainField extends FieldArt {
  /// The field's day, keyed by hour.
  List<(double, _Light)> get _keys;

  /// Fills [_grades] for the hour's light [l].
  void _buildGrades(_Light l);

  /// How strongly the light catches edges on [layer], against the far one.
  double _lightK(SceneLayer layer) => 1;

  /// Anything besides the hour that changes the light — a storm, a flash of
  /// lightning. The light is rebuilt whenever it changes.
  double get _weatherKey => 0;
  double _lastWeather = 0;

  /// The hour's light [l] as the weather has it.
  _Light _weathered(_Light l) => l;

  /// How much of the sun and moon is hidden behind weather (0–1).
  double get _veil => 0;

  /// How many of the motes are out (1 = all); weather keeps some in.
  double get _moteShare => 1;

  /// How much harder than usual the wind blows.
  double get _windScale => 1;

  /// The sun's disc, high in the sky (0) to on the horizon (1).
  Color _sunDisc(double low) =>
      Color.lerp(const Color(0xFFFFFBEF), const Color(0xFFFFE6B4), low)!;

  /// The moon's lit face; ash or haze in the air can tint it.
  Color get _moonFace => const Color(0xFFEAF0FC);

  /// Where the sun and moon meet the horizon, as a fraction of the height.
  double get _horizon => 0.56;

  /// How many stars, and how far down the sky (a fraction of the height)
  /// they reach.
  int get _starCount => 140;
  double get _starDepth => 0.5;

  // ── The hour ─────────────────────────────────────────────────────────────

  double _hour = -1;
  late _Light _light = _keys.first.$2;
  final Map<int, ColorFilter> _grades = {};

  /// Sun and moon: x as a fraction of the screen, elevation 0 (horizon) to
  /// 1 (overhead), below 0 when set.
  double _sunX = 0.5, _sunUp = 0, _moonX = 0.5, _moonUp = -1;
  double _moonPhase = 0.5;
  static const _sunrise = 6.0, _sunset = 19.5;
  static const _moonrise = 20.0, _moonset = 5.5;

  @override
  void prepare(double hour, {double time = 0}) {
    final weather = _weatherKey;
    if (_hour >= 0 &&
        (hour - _hour).abs() < 1 / 240 &&
        weather == _lastWeather) {
      return;
    }
    _lastWeather = weather;
    _hour = hour;
    _light = _weathered(_Light.at(hour, _keys));

    final f = (hour - _sunrise) / (_sunset - _sunrise);
    _sunX = 0.18 + 0.64 * f.clamp(-0.1, 1.1);
    _sunUp = math.sin(f * math.pi);
    if (f < 0 || f > 1) _sunUp = -math.min(f.abs(), (f - 1).abs()) * 3;
    final fm =
        ((hour - _moonrise + 24) % 24) / ((_moonset - _moonrise + 24) % 24);
    _moonX = 0.16 + 0.68 * fm.clamp(0.0, 1.0);
    _moonUp = fm <= 1 ? math.sin(fm * math.pi) * 0.82 : -1;
    _moonPhase = _lunarPhase(DateTime.now());

    _buildGrades(_light);
  }

  /// The moon's age through its cycle, 0 new → 0.5 full → 1 new.
  static double _lunarPhase(DateTime now) {
    final known = DateTime.utc(2000, 1, 6, 18, 14);
    final days = now.toUtc().difference(known).inMinutes / 1440;
    final p = (days / 29.530588853) % 1;
    return p < 0 ? p + 1 : p;
  }

  @override
  ColorFilter? grade(int grade) => _grades[grade];

  @override
  Color lightAt(SceneLayer layer, double x, FieldView view) {
    final l = _light;
    if (l.rimStrength <= 0.01) return const Color(0x00000000);
    // By day the sun is the light, even just below the horizon; by night
    // the moon.
    final byMoon = _sunUp < -0.3 && _moonUp > -0.2;
    final src = byMoon ? _moonX : _sunX;
    final sx = view.left + src * _screen.width / view.zoom;
    final d = (x - sx) / (_screen.width * 0.5 / view.zoom);
    final fall = l.floor + (1 - l.floor) * math.exp(-d * d);
    final k = _lightK(layer);
    return l.rim.withValues(alpha: (l.rimStrength * fall * k).clamp(0.0, 1.0));
  }

  // ── Where the creatures stand ────────────────────────────────────────────

  List<SpawnPoint> _spawns = const [];
  double _worldWidth = 1000;

  bool _loop = false;

  /// Each layer's width as built — in a looping field, one loop of it.
  final Map<SceneLayer, double> _widths = {};

  @override
  void layout(List<SpawnPoint> spawns, double worldWidth, {bool loop = false}) {
    _spawns = spawns;
    _worldWidth = worldWidth;
    _loop = loop;
  }

  /// How far [layer] runs before it repeats (0 if it never does).
  double _period(SceneLayer layer) => _loop ? (_widths[layer] ?? 0) : 0;

  /// [x]'s distance from [from], the short way round a loop.
  double _loopDelta(double x, double from, SceneLayer layer) {
    final p = _period(layer);
    final d = x - from;
    return p <= 0 ? d : d - p * (d / p).roundToDouble();
  }

  /// A standing creature's feet, by its spawn point's own size.
  double _feet(SpawnPoint p) => p.normalizedPos.dy * _h + p.size.y * 0.42;
  double _spawnX(SpawnPoint p) =>
      p.normalizedPos.dx *
      (_loop ? (_widths[p.anchor] ?? _worldWidth) : _worldWidth);

  // ── Layout for the current screen ────────────────────────────────────────

  double _h = 475;
  double _u = 1;
  Size _screen = const Size(751, 475);

  // Live drawing: 8 grass tones × 3 grain sizes.
  final GrainBatch _grass = GrainBatch(8 * 3);
  final GrainBatch _moteBatch = GrainBatch(4);
  final GrainBatch _starBatch = GrainBatch(4);
  late final List<Offset> _stars = _makeStars();
  final _Kicked _kicked = _Kicked(420);

  /// Glints that twinkle on the clouds and trees, per layer, gathered while
  /// their light sheets bake.
  final Map<SceneLayer, _Glints> _glints = {};
  _Glints? _sink;
  final GrainBatch _glintBatch = GrainBatch(4);
  double _cloudWidth = 1;

  void _sinking(SceneLayer layer, void Function() paint) =>
      _sinkingInto(_glints[layer], _widths[layer] ?? double.infinity, paint);

  /// Gathers the glints [paint] lays down into [glints], kept to [width].
  void _sinkingInto(_Glints? glints, double width, void Function() paint) {
    _sink = glints;
    _sinkWidth = width;
    try {
      paint();
    } finally {
      _sink = null;
    }
  }

  double _sinkWidth = double.infinity;

  /// A glint at [x], [y] — once: a copy drawn across a loop's seam adds none.
  void _glint(double x, double y) {
    if (x >= 0 && x < _sinkWidth) _sink?.add(x, y);
  }

  /// Draws [paint] at [x], and again a loop away where it reaches over an
  /// edge of a layer [w] wide, so a looping layer joins without a seam.
  void _wrapped(
    double x,
    double reach,
    double w,
    void Function(double x) paint,
  ) {
    paint(x);
    if (!_loop) return;
    if (x - reach < 0) paint(x + w);
    if (x + reach > w) paint(x - w);
  }

  Path? _moonLit;
  double _moonLitPhase = -1;

  // ── Sky ──────────────────────────────────────────────────────────────────

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
    final z = view.zoom;
    // A hint of parallax on the sky's lights — none in a looping field,
    // where the camera wraps and they would jump.
    final drift = _loop ? 0.0 : view.left * 0.04 * z;
    double skyY(double up) =>
        view.screenY(view.height * (_horizon - up * 0.49));

    // Stars, under everything else in the sky.
    if (l.stars > 0.02) {
      _starBatch.clear();
      final t = view.time;
      for (var i = 0; i < _stars.length; i++) {
        final s = _stars[i];
        final y = view.screenY(s.dy * view.height);
        if (y < -4 || y > screen.height) continue;
        final tw = 0.5 + 0.5 * math.sin(t * (0.7 + (i % 5) * 0.23) + i * 1.7);
        final fade = 1 - (s.dy / _starDepth);
        final level = (fade * l.stars * (0.4 + 0.6 * tw) * 3.99).floor();
        if (level <= 0) continue;
        _starBatch.add(level.clamp(0, 3), s.dx * screen.width - drift * 0.5, y);
      }
      for (var lv = 1; lv < 4; lv++) {
        _starBatch.draw(
          canvas,
          lv,
          1.4 + lv * 0.25,
          const Color(0xFFE8ECFF).withValues(alpha: 0.2 * lv),
        );
      }
    }

    // The sun's light: a wide glow wherever it is, even just set.
    final sun = Offset(screen.width * _sunX - drift, skyY(_sunUp));
    void glow(Offset at, double r, Color c, List<double> alphas) =>
        canvas.drawCircle(
          at,
          r,
          Paint()
            ..shader = Gradient.radial(
              at,
              r,
              [
                c.withValues(alpha: alphas[0]),
                c.withValues(alpha: alphas[1]),
                c.withValues(alpha: 0),
              ],
              const [0.0, 0.38, 1.0],
            ),
        );
    if (l.glow > 0.01) {
      glow(sun, screen.width * 0.95, l.rim, [0.3 * l.glow, 0.1 * l.glow]);
      glow(sun, screen.width * 0.3, l.rim, [0.5 * l.glow, 0.16 * l.glow]);
    }
    final veil = _veil;
    if (_sunUp > -0.08 && veil < 0.98) {
      final low = (1 - _sunUp * 2.5).clamp(0.0, 1.0);
      final disc = _sunDisc(low);
      // Behind weather the disc goes first; a soft brightness stays.
      final clear = 1 - veil;
      final soft = math.pow(clear, 3).toDouble();
      glow(sun, 46 * _u * z, disc, [0.95 * soft, 0.35 * soft]);
      if (veil > 0.01) {
        glow(sun, 120 * _u * z, disc, [0.16 * veil, 0.07 * veil]);
      }
      canvas.drawCircle(
        sun,
        17 * _u * z,
        Paint()..color = disc.withValues(alpha: soft),
      );
    }

    // The moon, in tonight's phase.
    if (_moonUp > -0.08 && l.stars > 0.05) {
      final moon = Offset(screen.width * _moonX - drift, skyY(_moonUp));
      final vis = l.stars.clamp(0.0, 1.0) * (1 - veil);
      final lit = (1 - math.cos(_moonPhase * 2 * math.pi)) / 2;
      glow(moon, 120 * _u * z, const Color(0xFFB4C6F0), [
        0.32 * vis * lit,
        0.1 * vis * lit,
      ]);
      final r = 13 * _u * z;
      canvas.drawCircle(
        moon,
        r,
        Paint()..color = const Color(0xFF1A2236).withValues(alpha: 0.55 * vis),
      );
      if (_moonLit == null || (_moonLitPhase - _moonPhase).abs() > 0.01) {
        _moonLit = _moonShape(_moonPhase);
        _moonLitPhase = _moonPhase;
      }
      canvas
        ..save()
        ..translate(moon.dx, moon.dy)
        ..scale(r)
        ..drawPath(_moonLit!, Paint()..color = _moonFace.withValues(alpha: vis))
        ..restore();
    }
  }

  /// The lit part of a unit moon at [phase]: lit on the right while waxing.
  static Path _moonShape(double phase) {
    final k = math.cos(phase * 2 * math.pi);
    final waxing = phase < 0.5;
    final half = Path()
      ..moveTo(0, -1)
      ..arcTo(
        const Rect.fromLTRB(-1, -1, 1, 1),
        waxing ? -math.pi / 2 : math.pi / 2,
        math.pi,
        false,
      )
      ..close();
    final terminator = Path()
      ..addOval(
        Rect.fromCenter(center: Offset.zero, width: 2 * k.abs(), height: 2),
      );
    return Path.combine(
      k > 0 ? PathOperation.difference : PathOperation.union,
      half,
      terminator,
    );
  }

  List<Offset> _makeStars() {
    final r = FieldRandom(7);
    return [
      for (var i = 0; i < _starCount; i++)
        Offset(r.next(), math.pow(r.next(), 1.15) * _starDepth),
    ];
  }

  /// A cloud: a soft body shaded from its top to its underside, with grains
  /// glittering along the underside where a low sun catches it.
  void _cloud(
    Canvas c,
    GrainBatch grains,
    double cx,
    double cy,
    double width,
    double height,
    double low,
    int seed,
    double sheetWidth,
  ) {
    if (cx + width < 0 || cx - width > sheetWidth) return;
    final r = FieldRandom(seed);
    final k = 4 + (r.next() * 4).floor();
    final lobes = <(double, double, double, double)>[];
    for (var i = 0; i < k; i++) {
      final t = (i + 0.5) / k;
      final rx = width / k * r.range(0.9, 1.4);
      final ry =
          height * (0.4 + 0.6 * math.sin(t * math.pi)) * r.range(0.8, 1.1);
      lobes.add((cx + (t - 0.5) * width * 0.85, cy - ry * 0.45, rx, ry));
    }
    var top = cy, base = cy;
    for (final (_, oy, _, ry) in lobes) {
      top = math.min(top, oy - ry);
      base = math.max(base, oy + ry);
    }
    // Soft edges without a blur: the body three times, each a little
    // larger and fainter than the last.
    for (final (grow, a) in [(1.1, 0.2), (1.04, 0.4), (1.0, 0.8)]) {
      final body = Path();
      for (final (ox, oy, rx, ry) in lobes) {
        body.addOval(
          Rect.fromCenter(
            center: Offset(ox, oy),
            width: rx * 2 * grow,
            height: ry * 2 * grow,
          ),
        );
      }
      c.drawPath(
        body,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, top),
            Offset(0, base),
            [
              fieldMap(0, 0, 0, a),
              fieldMap(0.25, 0, 0, a),
              fieldMap(0.6 + 0.4 * low, 0, 0, a),
            ],
            const [0.0, 0.5, 1.0],
          ),
      );
    }
    final spacing = 1.7 * _u;
    final n = (width * height * 1.3 / (spacing * spacing)).round();
    for (var i = 0; i < n; i++) {
      final x = cx + (r.next() - 0.5) * width * 1.2;
      final y = top + r.next() * (base - top);
      var d = 9.0;
      for (final (ox, oy, rx, ry) in lobes) {
        final dx = (x - ox) / rx, dy = (y - oy) / ry;
        d = math.min(d, dx * dx + dy * dy);
      }
      if (d > 1.05) continue;
      final v = ((y - top) / (base - top)).clamp(0.0, 1.0);
      if (r.next() > math.pow(v, 3)) continue;
      final lit = math.pow(v, 1.4) * (0.5 + 0.5 * low);
      final tone = (lit * 4 + r.next() * 0.9 - 1.4).round();
      if (tone < 0) continue;
      grains.add(tone.clamp(0, 3), x, y);
      if (tone >= 1 && x >= 0 && x < sheetWidth && r.next() < 0.09) {
        _glint(x, y);
      }
    }
  }

  /// Distant grass on a slope: tufts of three grains, their tips catching
  /// the light near the crest, fading into the hill's shade below.
  void _tufts(
    Canvas c,
    double w,
    double Function(double) ridge, {
    required int count,
    required int seed,
  }) {
    final batch = GrainBatch(4);
    final r = FieldRandom(seed * 4211);
    final depth = 22 * _u;
    for (var i = 0; i < count; i++) {
      final x = r.next() * w;
      final d = -math.log(1 - r.next() * 0.99) * depth;
      final y = ridge(x) + 3 * _u + d;
      final near = math.exp(-d / (depth * 0.5));
      final lean = r.range(-0.4, 0.6) * _u;
      for (var j = 0; j < 3; j++) {
        final tip = j == 2 ? near * 3.4 : near * (1.2 + j);
        batch.add(
          (tip + r.next() * 0.6 - 0.3).round().clamp(0, 3),
          x + lean * j,
          y - j * 1.3 * _u,
        );
      }
    }
    const haze = 0.08;
    for (var t = 0; t < 4; t++) {
      batch.draw(c, t, 1.3 * _u, fieldMap(haze, 0.1 + t * 0.22, 0.05));
    }
  }

  /// A spruce: ragged tiers drooping from a sharp tip. With [sparks], also
  /// grains of light at its tip and tier ends.
  void _conifer(
    Canvas c,
    GrainBatch? sparks,
    Paint body,
    double x,
    double base,
    double h,
    int treeSeed,
  ) {
    final r = FieldRandom(treeSeed);
    final w = h * r.range(0.32, 0.44);
    final tiers = 6 + (r.next() * 5).floor();
    final top = base - h;
    final left = <Offset>[], right = <Offset>[];
    for (var k = 1; k <= tiers; k++) {
      final f = k / tiers;
      final y = top + h * 0.9 * f;
      final reach = w * 0.5 * (0.12 + 0.88 * math.pow(f, 0.85));
      final droop = h * 0.025;
      left
        ..add(Offset(x - reach * r.range(0.85, 1.12), y + droop))
        ..add(Offset(x - reach * r.range(0.3, 0.5), y - h * 0.02));
      right
        ..add(Offset(x + reach * r.range(0.85, 1.12), y + droop))
        ..add(Offset(x + reach * r.range(0.3, 0.5), y - h * 0.02));
    }
    final tip = r.range(-0.4, 0.4) * _u;
    if (sparks == null) {
      final path = Path()..moveTo(x + tip, top);
      for (final p in left) {
        path.lineTo(p.dx, p.dy);
      }
      path
        ..lineTo(x - w * 0.05, base + 4 * _u)
        ..lineTo(x + w * 0.05, base + 4 * _u);
      for (final p in right.reversed) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      c.drawPath(path, body);
      return;
    }
    // Light at the tier ends — upper tiers most.
    final seed = treeSeed;
    for (final (si, side) in [(0, left), (1, right)]) {
      for (var i = 0; i < side.length; i += 2) {
        final f = i / side.length;
        if (fieldHash(i * 2 + si, seed) > 0.75 - f * 0.5) continue;
        final roll = fieldHash(i * 2 + si + 97, seed);
        sparks.add(
          ((1 - f) * 3 + roll * 0.8 - 0.6).round().clamp(0, 3),
          side[i].dx,
          side[i].dy - 0.8 * _u,
        );
      }
    }
    sparks.add(3, x + tip, top + 0.6 * _u);
    if (fieldHash(seed, 211) < 0.6) _glint(x + tip, top + 0.6 * _u);
    for (var i = 0; i < right.length; i += 4) {
      if (fieldHash(i, seed + 7) < 0.3) _glint(right[i].dx, right[i].dy);
      if (fieldHash(i, seed + 9) < 0.3) _glint(left[i].dx, left[i].dy);
    }
  }

  /// A broad crown as many small leaf masses round a solid core, so its
  /// outline is lumpy like foliage, not a ring of discs. Without [sparks]
  /// it paints the crown's maps (leaf tops a little lit, leaves in varied
  /// shade); with, the grains of light along its top edge.
  void _leafCrown(
    Canvas c,
    GrainBatch? sparks,
    List<(Offset, double, double)> envelope, {
    required double leaf,
    required int seed,
    required double haze,
    required double shade,
  }) {
    final r = FieldRandom(seed);
    final leaves = <(Offset, double, double)>[];
    final core = Path();
    for (final (o, rx, ry) in envelope) {
      core.addOval(
        Rect.fromCenter(center: o, width: rx * 1.5, height: ry * 1.5),
      );
      final n = (math.pi * rx * ry / (leaf * leaf * _u * _u * 1.5)).round();
      for (var i = 0; i < n; i++) {
        final a = r.next() * math.pi * 2;
        final d = 0.6 + 0.4 * math.pow(r.next(), 0.6);
        final p = o + Offset(math.cos(a) * rx * d, math.sin(a) * ry * d);
        leaves.add((p, leaf * _u * r.range(0.6, 1.3), r.next()));
      }
    }
    if (sparks == null) {
      c.drawPath(core, Paint()..color = fieldMap(haze, 0, shade + 0.1));
      // Leaves in a few shades, each with its top a little lit.
      for (var band = 0; band < 3; band++) {
        final path = Path(), tops = Path();
        for (final (p, rad, v) in leaves) {
          if ((v * 3).floor() != band) continue;
          path.addOval(Rect.fromCircle(center: p, radius: rad));
          tops.addOval(
            Rect.fromCircle(
              center: p + Offset(0, -rad * 0.35),
              radius: rad * 0.55,
            ),
          );
        }
        c.drawPath(
          path,
          Paint()..color = fieldMap(haze, 0, shade - 0.12 + band * 0.12),
        );
        c.drawPath(
          tops,
          Paint()..color = fieldMap(haze, 0.22, shade - 0.2 + band * 0.1),
        );
      }
      return;
    }

    // Which leaf edges are the crown's outline: a grid of leaves for the
    // inside test.
    final cell = leaf * _u * 2.6;
    final grid = <int, List<int>>{};
    int key(double x, double y) =>
        (x / cell).floor() * 100003 + (y / cell).floor();
    for (var i = 0; i < leaves.length; i++) {
      grid.putIfAbsent(key(leaves[i].$1.dx, leaves[i].$1.dy), () => []).add(i);
    }
    bool covered(Offset p, int self) {
      for (final (o, rx, ry) in envelope) {
        final dx = (p.dx - o.dx) / (rx * 0.75),
            dy = (p.dy - o.dy) / (ry * 0.75);
        if (dx * dx + dy * dy < 0.94) return true;
      }
      final gx = (p.dx / cell).floor(), gy = (p.dy / cell).floor();
      for (var ix = gx - 1; ix <= gx + 1; ix++) {
        for (var iy = gy - 1; iy <= gy + 1; iy++) {
          for (final j in grid[ix * 100003 + iy] ?? const <int>[]) {
            if (j == self) continue;
            final (o, rad, _) = leaves[j];
            if ((p - o).distance < rad - 0.4 * _u) return true;
          }
        }
      }
      return false;
    }

    for (var i = 0; i < leaves.length; i++) {
      final (o, rad, _) = leaves[i];
      final steps = (rad * math.pi / (1.6 * _u)).ceil();
      for (var j = 0; j <= steps; j++) {
        final th = -math.pi + math.pi * j / steps;
        final lit = -math.sin(th);
        if (lit < 0.35 || r.next() > lit * 0.8) continue;
        final p = Offset(o.dx + rad * math.cos(th), o.dy + rad * math.sin(th));
        if (covered(p, i)) continue;
        final tone = (lit * 3.4 + r.next() * 0.8 - 0.6).round().clamp(0, 3);
        sparks.add(tone, p.dx, p.dy + 0.5 * _u);
        if (tone >= 2 && r.next() < 0.16) _glint(p.dx, p.dy + 0.5 * _u);
      }
    }
  }

  /// Wind at [x]: a slow sway everywhere, plus gusts that sweep across the
  /// layer, bending the grass hard and lighting its tips as they pass.
  /// Returns (bend, gust) where gust is the gust's strength in [0, 1].
  (double, double) _wind(double x, double t, double width) {
    final sway =
        0.12 * math.sin(1.05 * t + x * 0.011) +
        0.05 * math.sin(2.3 * t + x * 0.037 + 1.3);
    // Three gust fronts round the layer, each sweeping across it. In a
    // looping layer they go round and round; otherwise they run past the
    // ends before coming back.
    final wrap = _loop ? width : width + 900 * _u;
    var gust = 0.0;
    for (var k = 0; k < 3; k++) {
      final front =
          (t * 210 * _u + k * wrap / 3) % wrap - (_loop ? 0 : 450 * _u);
      var d = x - front;
      if (_loop) d -= wrap * (d / wrap).roundToDouble();
      final e = d > 0
          ? math.exp(-math.pow(d / (55 * _u), 2))
          : math.exp(-math.pow(d / (190 * _u), 2));
      if (e > gust) gust = e.toDouble();
    }
    return ((sway + 0.42 * gust) * _windScale, gust);
  }

  /// The whole loops of [layer] at which its content shows in [view] (with
  /// [margin] each side); just 0 for a layer that doesn't loop.
  List<double> _shiftsFor(SceneLayer layer, FieldView view, double margin) {
    final p = _period(layer);
    if (p <= 0) return const [0];
    final k0 = ((view.left - margin) / p).floor();
    final k1 = ((view.right + margin) / p).floor();
    return [for (var k = k0; k <= k1; k++) k * p];
  }

  /// The fingers in this layer's units: where, which way they were moving,
  /// how fast (layer units per sample), and how long ago.
  List<_Push> _pushes(FieldView view) {
    if (view.touches.isEmpty) return const [];
    final out = <_Push>[];
    for (final t in view.touches) {
      final age = view.time - t.time;
      if (age > 1.2 || age < 0) continue;
      final p = view.local(t.x, t.y);
      final speed = math.sqrt(t.dx * t.dx + t.dy * t.dy) / view.zoom;
      out.add(_Push(p.dx, p.dy, speed > 0.01 ? t.dx.sign : 0, speed, age));
    }
    return out;
  }

  // ── Fingers in the grass ─────────────────────────────────────────────────

  /// Fingers on each layer, in that layer's own units as they were when
  /// each sample arrived — so a drag that pans the camera does not drag
  /// what it touched along with it.
  final Map<SceneLayer, List<_Stir>> _stirs = {};
  final Map<SceneLayer, double> _stirSeen = {};

  /// How long a finger keeps hold of the grass it touched.
  static const _hold = 0.14;

  /// A tap's ripple: how fast it runs out (units a second at the reference
  /// height), how long it lasts, and how hard it pushes the grass.
  static const _rippleSpeed = 170.0, _rippleLife = 0.75, _rippleKick = 140.0;

  /// The fingers on [layer]: this frame's new samples are taken in through
  /// [view] (the camera they arrived under), older ones kept where they
  /// landed.
  List<_Stir> _stirsFor(SceneLayer layer, FieldView view) {
    final list = _stirs.putIfAbsent(layer, () => []);
    final seen = _stirSeen[layer] ?? -1;
    var newest = seen;
    for (final t in view.touches) {
      if (t.time <= seen) continue;
      final p = view.local(t.x, t.y);
      final speed = math.sqrt(t.dx * t.dx + t.dy * t.dy) / view.zoom;
      list.add(_Stir(p.dx, p.dy, speed > 0.01 ? t.dx.sign : 0, speed, t.time));
      if (t.time > newest) newest = t.time;
    }
    _stirSeen[layer] = newest;
    list.removeWhere((s) => view.time - s.time > 1.5 || s.time > view.time);
    return list;
  }

  /// Moves [b]'s blades under the fingers on [layer]. Each blade is its own
  /// damped spring: a finger holds it bent away (and along the way the
  /// finger is going) while it is there, and when it has gone the blade
  /// swings back and settles in a wobble or two. Blades that whip hard shed
  /// grains off their tips if [shed].
  void _stirBlades(
    _Blades b,
    SceneLayer layer,
    double width,
    FieldView view, {
    required double reach,
    required double maxBend,
    bool shed = false,
  }) {
    final stirs = _stirsFor(layer, view);
    final now = view.time;
    final dt = b.clock < 0 ? 0.0 : (now - b.clock).clamp(0.0, 1 / 30);
    b.clock = now;
    b.maxBend = maxBend;
    final period = _period(layer);
    final live = <_Stir>[
      for (final p in stirs)
        if (now - p.time < _hold) p,
    ];
    // A tap also sends a ripple out through the grass round it, like a
    // breath of wind running away from the finger.
    final ripples = <_Stir>[
      for (final p in stirs)
        if (p.speed < 0.5 && now - p.time < _rippleLife) p,
    ];
    final wave = _rippleSpeed * _u, band = 16 * _u;
    // Take in the blades the fingers reach.
    for (final (p, r) in [
      for (final p in live) (p, reach),
      for (final p in ripples) (p, wave * (now - p.time) + band * 2),
    ]) {
      final local = period > 0 ? p.x - period * (p.x / period).floor() : p.x;
      for (final c in [local, if (period > 0) local - period, local + period]) {
        if (c + r < 0 || c - r > width) continue;
        final a = b.firstAt(c - r), z = b.firstAt(c + r) - 1;
        if (z < a) continue;
        if (b.hi < b.lo) {
          b
            ..lo = a
            ..hi = z;
        } else {
          b.lo = math.min(b.lo, a);
          b.hi = math.max(b.hi, z);
        }
      }
    }
    if (b.hi < b.lo || dt <= 0) return;
    const k = 170.0, damp = 7.0, pullK = 700.0;
    final steps = (dt * 60).ceil().clamp(1, 2);
    final h = dt / steps;
    var lo = b.n, hi = -1;
    final k0 = _kicked;
    final mid = (view.left + view.right) / 2;
    for (var i = b.lo; i <= b.hi; i++) {
      // The finger with the strongest hold on this blade, and where it
      // wants it.
      var pull = 0.0, target = 0.0;
      final y = b.base[i] - b.height[i] * 0.5;
      for (final p in live) {
        final dx = period > 0 ? _loopDelta(b.x[i], p.x, layer) : b.x[i] - p.x;
        if (dx.abs() > reach) continue;
        final dy = y - p.y;
        if (dy.abs() > reach * 1.4) continue;
        final w =
            math.exp(-(dx * dx + dy * dy * 0.5) / (reach * reach * 0.42)) *
            (1 - (now - p.time) / _hold);
        if (w <= pull) continue;
        pull = w;
        final along = p.dir * math.min(1.0, p.speed / (8 * _u)) * 0.75;
        target = (dx.sign * 0.75 + along).clamp(-1.0, 1.0) * maxBend;
      }
      var push = 0.0;
      for (final p in ripples) {
        final dx = period > 0 ? _loopDelta(b.x[i], p.x, layer) : b.x[i] - p.x;
        final age = now - p.time;
        final off = (dx.abs() - wave * age) / band;
        if (off.abs() > 2.5 || dx.abs() < 2 * _u) continue;
        final dy = (y - p.y) / (reach * 1.6);
        push +=
            dx.sign * _rippleKick * math.exp(-off * off - dy * dy - age * 3.2);
      }
      var bend = b.bend[i], vel = b.vel[i];
      for (var s = 0; s < steps; s++) {
        final a =
            -k * bend -
            (damp + pull * 30) * vel +
            pull * pullK * (target - bend) +
            push;
        vel += a * h;
        bend += vel * h;
      }
      if (bend.abs() < 1e-3 && vel.abs() < 1e-2 && pull == 0) {
        bend = 0;
        vel = 0;
      } else {
        if (i < lo) lo = i;
        hi = i;
      }
      b.bend[i] = bend;
      b.vel[i] = vel;
      // A blade whipping back throws grains off its tip.
      if (shed && vel.abs() > 5 && k0.rand() < vel.abs() * 0.25 * dt) {
        final hgt = b.height[i];
        var x = b.x[i] + hgt * 0.5 * bend;
        if (period > 0) x += period * ((mid - x) / period).roundToDouble();
        k0.spawn(
          x: x,
          y: b.base[i] - hgt * 0.9,
          vx: (vel * hgt * 0.35).clamp(-90 * _u, 90 * _u),
          vy: -(25 + k0.rand() * 55) * _u,
          life: 1.2 + k0.rand() * 1.4,
        );
      }
    }
    b.lo = lo;
    b.hi = hi;
  }

  void _paintBlades(
    Canvas canvas,
    FieldView view,
    _Blades b,
    double width, {
    required (int, int) rows,
    required bool fore,
    required SceneLayer layer,
    void Function(int i, double x, double y, double s, double c)? tip,
  }) {
    _grass.clear();
    final t = view.time;
    final margin = 40 * _u;
    final step = (fore ? 1.9 : 1.25) * _u;
    final stirScale = b.maxBend > 0 ? 1 / b.maxBend : 0.0;
    for (final shift in _shiftsFor(layer, view, margin)) {
      final start = b.firstAt(view.left - margin - shift);
      for (var i = start; i < b.n; i++) {
        final x = b.x[i] + shift;
        if (x > view.right + margin) break;
        final row = b.row[i];
        if (row < rows.$1 || row > rows.$2) continue;
        final (wind, gust) = _wind(b.x[i], t, width);
        final h = b.height[i];
        final base = b.base[i];
        final sway =
            b.lean[i] +
            wind * (fore ? 0.7 : 1.0) +
            0.05 * math.sin(3.1 * t + b.phase[i]);
        // Each blade is an arc of its own length: the wind and the fingers
        // curve it, never stretch it.
        final turn = (2 * sway + b.bend[i]).clamp(-2.2, 2.2);
        final stirred = math.min(
          1.0,
          b.bend[i].abs() * stirScale + b.vel[i].abs() * 0.05,
        );
        final k = math.max(2, (h / step).round());
        final size = fore ? 2 : (row == 0 ? 0 : (row < 3 ? 1 : 2));
        // The fringe stands against the light, in patches; the nearer a blade,
        // the deeper in the meadow's shade.
        final double lightBase, reach;
        if (fore) {
          (lightBase, reach) = (-0.6, 2.4);
        } else if (row == 0) {
          final patch =
              0.65 +
              0.5 *
                  (fieldLoopNoise(b.x[i], 58, 71, _period(layer)) * 0.5 + 0.5);
          (lightBase, reach) = (1.0, 5.2 * patch);
        } else {
          final d = b.depth[i];
          (lightBase, reach) = (0.9 - d * 1.2, 3.6 - d * 1.4);
        }
        final lift = gust * 2.4 + stirred * 4.5;
        final seg = h / k, dTurn = turn / k;
        final cd = math.cos(dTurn), sd = math.sin(dTurn);
        var c = math.cos(dTurn * 0.5), s = math.sin(dTurn * 0.5);
        var px = x, py = base;
        for (var j = 1; j <= k; j++) {
          final f = j / k;
          px += seg * s;
          py -= seg * c;
          final tone = (lightBase + f * f * reach + lift * f).round().clamp(
            0,
            7,
          );
          _grass.add(tone * 3 + size, px, py);
          final nc = c * cd - s * sd;
          s = s * cd + c * sd;
          c = nc;
        }
        // Where it ends and which way it points, for anything it carries.
        tip?.call(i, px, py, s, c);
      }
    }
    final d = [1.6 * _u, 1.9 * _u, 2.2 * _u];
    final tones = _light.grass;
    for (var tone = 0; tone < 8; tone++) {
      for (var s = 0; s < 3; s++) {
        _grass.draw(
          canvas,
          tone * 3 + s,
          fore && s == 2 ? 2.7 * _u : d[s],
          tones[tone],
        );
      }
    }
  }

  void _paintMotes(Canvas canvas, FieldView view, _Motes? m, SceneLayer layer) {
    if (m == null) return;
    final l = _light;
    _moteBatch.clear();
    final t = view.time;
    final span = m.yBottom - m.yTop;
    // Fireflies: more of them, slower, blinking rather than twinkling.
    final ff = l.firefly;
    final shown = (m.n * (0.55 + 0.45 * ff) * _moteShare).round();
    final shifts = _shiftsFor(layer, view, 10);
    for (var i = 0; i < shown; i++) {
      final rise =
          (m.yBottom - m.y0[i] + t * m.speed[i] * (1 - ff * 0.7)) % span;
      final y = m.yBottom - rise + ff * 9 * _u * math.sin(t * 0.9 + i);
      var x =
          (m.x0[i] + t * 5 * _u + 12 * _u * math.sin(t * 0.4 + m.phase[i])) %
          m.width;
      // The repeat of it that is on screen, in a looping meadow.
      for (final s in shifts) {
        if (x + s >= view.left - 10 && x + s <= view.right + 10) {
          x += s;
          break;
        }
      }
      if (x < view.left - 10 || x > view.right + 10) continue;
      // Fade in off the grass, out near the top of the band.
      final life = rise / span;
      final fade = math.min(1.0, life * 6) * math.min(1.0, (1 - life) * 3);
      final tw =
          0.55 + 0.45 * math.sin(t * (1.3 + m.phase[i] * 0.2) + m.phase[i] * 3);
      final blink = math.pow(
        0.5 + 0.5 * math.sin(t * (1.1 + m.phase[i] * 0.3) + m.phase[i] * 5),
        6,
      );
      final lit = tw + (blink - tw) * ff;
      final level = (fade * lit * 3.99).floor();
      if (level <= 0) continue;
      final (_, gust) = _wind(x, t, m.width);
      x += gust * 6 * _u;
      _moteBatch.add(level, x, y);
    }
    final halo = 6.5 + ff * 4;
    for (var lv = 1; lv < 4; lv++) {
      _moteBatch.draw(
        canvas,
        lv,
        halo * _u,
        l.mote.withValues(alpha: (0.06 + ff * 0.05) * lv),
      );
      _moteBatch.draw(
        canvas,
        lv,
        1.8 * _u,
        l.mote.withValues(alpha: (0.26 + ff * 0.06) * lv),
      );
    }
  }

  /// Fingers through the grass shed grains: seeds and pollen by day, gold
  /// in the low sun, fireflies at night. [surface] is the top of the grass
  /// a finger at x, y on [layer] is in, or null if it is in none.
  void _kickUp(
    FieldView view,
    List<_Push> pushes,
    SceneLayer layer,
    double width,
    double? Function(double x, double y) surface,
  ) {
    final k = _kicked;
    final dt = (view.time - k.clock).clamp(0.0, 0.1);
    k.clock = view.time;
    // When the camera wraps round the loop the meadow's window jumps a
    // whole loop; grains in the air go with it.
    final period = _period(layer);
    if (period > 0 &&
        k.left != null &&
        (view.left - k.left!).abs() > period / 2) {
      final jump = period * ((view.left - k.left!) / period).roundToDouble();
      for (var i = 0; i < k.cap; i++) {
        k.x[i] += jump;
      }
    }
    k.left = view.left;
    for (final p in pushes) {
      if (p.age > dt + 1e-6 && k.seen >= 0) continue;
      final g = surface(p.x, p.y);
      if (g == null) continue;
      // A tap puffs grains off the tips round the finger; a drag sheds a
      // few as it goes, and the blades it leaves whipping throw the rest.
      final n = p.speed < 0.5 ? 9 : (k.rand() < 0.5 ? 1 : 0);
      for (var i = 0; i < n; i++) {
        k.spawn(
          x: p.x + (k.rand() - 0.5) * 34 * _u,
          y: math.max(g - 4 * _u, p.y - k.rand() * 26 * _u),
          vx: p.dir * (20 + k.rand() * 70) * _u + (k.rand() - 0.5) * 50 * _u,
          vy: -(30 + k.rand() * 90) * _u,
          life: 1.4 + k.rand() * 1.8,
        );
      }
    }
    k.seen = 0;
    if (dt <= 0) return;
    final t = view.time;
    final ff = _light.firefly;
    for (var i = 0; i < k.cap; i++) {
      if (k.life[i] <= 0) continue;
      k.age[i] += dt;
      if (k.age[i] >= k.life[i]) {
        k.life[i] = 0;
        continue;
      }
      final (wind, _) = _wind(k.x[i], t, width);
      // Light things: they slow, drift with the wind, and float.
      final drag = math.exp(-1.8 * dt);
      k.vx[i] = k.vx[i] * drag + wind * 40 * _u * dt;
      k.vy[i] = k.vy[i] * drag - (6 + ff * 4) * _u * dt;
      k.x[i] += k.vx[i] * dt + ff * math.sin(t * 3 + i) * 6 * _u * dt;
      k.y[i] += k.vy[i] * dt;
    }
  }

  void _paintKicked(Canvas canvas, FieldView view) {
    final k = _kicked;
    _moteBatch.clear();
    var any = false;
    final ff = _light.firefly;
    for (var i = 0; i < k.cap; i++) {
      if (k.life[i] <= 0) continue;
      final f = k.age[i] / k.life[i];
      final fade = math.min(1.0, f * 8) * (1 - f);
      final blink = ff > 0
          ? 0.6 + 0.4 * math.sin(view.time * 7 + i * 1.3)
          : 1.0;
      final level = (fade * blink * 3.99).floor();
      if (level <= 0) continue;
      _moteBatch.add(level, k.x[i], k.y[i]);
      any = true;
    }
    if (!any) return;
    final c = _light.mote;
    for (var lv = 1; lv < 4; lv++) {
      _moteBatch.draw(
        canvas,
        lv,
        (5.5 + ff * 4) * _u,
        c.withValues(alpha: 0.09 * lv),
      );
      _moteBatch.draw(canvas, lv, 2.2 * _u, c.withValues(alpha: 0.33 * lv));
    }
  }

  // ── Glints ───────────────────────────────────────────────────────────────

  /// Brief twinkles on clouds and trees: each glint flares now and then,
  /// warm in the sun, silver under the moon, a few of them faintly blue.
  void _paintGlints(
    Canvas canvas,
    FieldView view,
    SceneLayer layer,
    _Glints? g, {
    double shift = 0,
    double wrap = 0,
    double size = 1,
    double alpha = 1,
  }) {
    if (g == null || g.n == 0 || alpha <= 0) return;
    final t = view.time;
    _glintBatch.clear();
    var any = false;
    final loops = _shiftsFor(layer, view, 8);
    for (var i = 0; i < g.n; i++) {
      var x = g.x[i] + shift;
      if (wrap > 0 && x >= wrap) x -= wrap;
      for (final s in loops) {
        if (x + s >= view.left - 8 && x + s <= view.right + 8) {
          x += s;
          break;
        }
      }
      if (x < view.left - 8 || x > view.right + 8) continue;
      final s = math.sin(t * g.speed[i] + g.phase[i]);
      if (s < 0.55) continue;
      final bright = s > 0.86 ? 1 : 0;
      _glintBatch.add((i % 5 == 0 ? 2 : 0) + bright, x, g.y[i]);
      any = true;
    }
    if (!any) return;
    final warm = Color.lerp(_light.rim, const Color(0xFFFFFFFF), 0.45)!;
    const cool = Color(0xFFCFE2FF);
    for (var b = 0; b < 4; b++) {
      final col = b < 2 ? warm : cool;
      final k = b.isOdd ? 1.0 : 0.5;
      _glintBatch.draw(
        canvas,
        b,
        7 * size * _u,
        col.withValues(alpha: 0.2 * k * alpha),
      );
      _glintBatch.draw(
        canvas,
        b,
        2.2 * size * _u,
        Color.lerp(
          col,
          const Color(0xFFFFFFFF),
          0.6,
        )!.withValues(alpha: 0.85 * k * alpha),
      );
    }
  }

  // ── Shared drawing ───────────────────────────────────────────────────────

  Path _ridgePath(double w, double Function(double) ridge, double step) {
    final path = Path()..moveTo(-4, ridge(-4));
    for (var x = -4.0; x <= w + 4; x += step) {
      path.lineTo(x, ridge(x));
    }
    return path..lineTo(w + 4, ridge(w + 4));
  }

  void _fillRidge(
    Canvas c,
    double w,
    double Function(double) ridge,
    Paint paint, {
    required double bottom,
    required double step,
  }) {
    final path = _ridgePath(w, ridge, step)
      ..lineTo(w + 4, bottom)
      ..lineTo(-4, bottom)
      ..close();
    c.drawPath(path, paint);
  }

  /// Light through a ridge's top edge, for a light sheet: bands of white
  /// hanging from the edge, each [depth] deep at [alpha].
  void _rimBands(
    Canvas c,
    double w,
    double Function(double) ridge,
    List<(double, double)> bands,
  ) {
    const step = 3.0;
    for (final (depth, a) in bands) {
      final band = _ridgePath(w, ridge, step * _u);
      for (var x = w + 4; x >= -4; x -= step * _u) {
        band.lineTo(x, ridge(x) + depth * _u);
      }
      band.close();
      c.drawPath(
        band,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a),
      );
    }
  }

  /// Sparse grains of light along a ridge.
  void _rimSparkle(
    GrainBatch sparks,
    double w,
    double Function(double) ridge, {
    required int seed,
  }) {
    final step = 2.4 * _u;
    var i = 0;
    for (var x = 0.0; x < w; x += step, i++) {
      final roll = fieldHash(i, seed * 13);
      if (roll > 0.3) continue;
      sparks.add((roll * 10).floor().clamp(0, 3), x, ridge(x) + 0.6 * _u);
    }
  }

  void _drawSparks(Canvas c, GrainBatch sparks, double size) {
    for (var i = 0; i < _sparkAlpha.length; i++) {
      sparks.draw(
        c,
        i,
        size * _u,
        const Color(0xFFFFFFFF).withValues(alpha: _sparkAlpha[i]),
      );
    }
  }

  void _mistBand(Canvas c, double w, double top, double bottom, double a) {
    c.drawRect(
      Rect.fromLTRB(-4, top, w + 4, bottom),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, top),
          Offset(0, bottom),
          [fieldMap(1, 0, 1, 0), fieldMap(1, 0, 1, a), fieldMap(1, 0, 1, 0)],
          const [0.0, 0.62, 1.0],
        ),
    );
  }
}

// ── The light through the day ──────────────────────────────────────────────

/// Everything the hour decides: the sky, the light on the land and the
/// clouds, the grass, and the motes.
class _Light {
  const _Light({
    required this.sky,
    required this.ambient,
    required this.rim,
    required this.rimStrength,
    required this.floor,
    required this.glow,
    required this.stars,
    required this.cloudTop,
    required this.cloudBottom,
    required this.cloudGlint,
    required this.grass,
    required this.mote,
    required this.firefly,
    this.stops = valleyStops,
    this.seaTop,
    this.seaDeep,
  });

  /// Sky colours at [stops] of the layer height.
  final List<Color> sky;

  /// Multiplies the land's daylight colours.
  final Color ambient;

  /// The light catching edges, and how strongly.
  final Color rim;
  final double rimStrength;

  /// How much of the rim light reaches edges far from the sun (1 = all).
  final double floor;

  /// The glow around the sun.
  final double glow;
  final double stars;
  final Color cloudTop, cloudBottom, cloudGlint;

  /// Grass grains, root to tip.
  final List<Color> grass;
  final Color mote;

  /// 0 = motes are pollen, 1 = fireflies.
  final double firefly;

  /// Clouds seen from above: their sunlit tops and the shade down between
  /// them. A field with no cloud below it leaves these to the cloud colours.
  final Color? seaTop, seaDeep;

  /// Where [sky]'s colours sit, as fractions of the layer height.
  final List<double> stops;

  static const valleyStops = [
    0.0,
    0.16,
    0.30,
    0.40,
    0.47,
    0.52,
    0.565,
    0.6,
    1.0,
  ];

  Color skyAt(double f) {
    for (var i = 1; i < stops.length; i++) {
      if (f <= stops[i]) {
        final t = (f - stops[i - 1]) / (stops[i] - stops[i - 1]);
        return Color.lerp(sky[i - 1], sky[i], t)!;
      }
    }
    return sky.last;
  }

  static _Light lerp(_Light a, _Light b, double t) {
    List<Color> list(List<Color> x, List<Color> y) => [
      for (var i = 0; i < x.length; i++) Color.lerp(x[i], y[i], t)!,
    ];
    double d(double x, double y) => x + (y - x) * t;
    return _Light(
      sky: list(a.sky, b.sky),
      ambient: Color.lerp(a.ambient, b.ambient, t)!,
      rim: Color.lerp(a.rim, b.rim, t)!,
      rimStrength: d(a.rimStrength, b.rimStrength),
      floor: d(a.floor, b.floor),
      glow: d(a.glow, b.glow),
      stars: d(a.stars, b.stars),
      cloudTop: Color.lerp(a.cloudTop, b.cloudTop, t)!,
      cloudBottom: Color.lerp(a.cloudBottom, b.cloudBottom, t)!,
      cloudGlint: Color.lerp(a.cloudGlint, b.cloudGlint, t)!,
      grass: list(a.grass, b.grass),
      mote: Color.lerp(a.mote, b.mote, t)!,
      firefly: d(a.firefly, b.firefly),
      stops: a.stops,
      seaTop: Color.lerp(a.seaTop ?? a.cloudTop, b.seaTop ?? b.cloudTop, t),
      seaDeep: Color.lerp(
        a.seaDeep ?? a.cloudBottom,
        b.seaDeep ?? b.cloudBottom,
        t,
      ),
    );
  }

  static _Light at(double hour, List<(double, _Light)> keys) {
    final h = hour % 24;
    for (var i = 1; i < keys.length; i++) {
      final (h1, b) = keys[i];
      if (h <= h1) {
        final (h0, a) = keys[i - 1];
        final t = ((h - h0) / (h1 - h0)).clamp(0.0, 1.0);
        return lerp(a, b, t * t * (3 - 2 * t));
      }
    }
    return keys.last.$2;
  }
}

// ── Glints ─────────────────────────────────────────────────────────────────

/// Where glints sit, and each one's own rhythm. Gathered point by point
/// while a sheet bakes, packed on first use.
class _Glints {
  final List<double> _x = [], _y = [];
  Float32List x = Float32List(0), y = Float32List(0);
  Float32List phase = Float32List(0), speed = Float32List(0);

  int get n {
    if (x.length != _x.length) _pack();
    return x.length;
  }

  void add(double px, double py) {
    _x.add(px);
    _y.add(py);
  }

  void _pack() {
    final n = _x.length;
    x = Float32List.fromList(_x);
    y = Float32List.fromList(_y);
    phase = Float32List(n);
    speed = Float32List(n);
    for (var i = 0; i < n; i++) {
      phase[i] = fieldHash(i, 1301) * math.pi * 2;
      speed[i] = 0.5 + fieldHash(i, 1303) * 1.3;
    }
  }
}

// ── Touch ──────────────────────────────────────────────────────────────────

/// A finger sample on a layer, in the layer's units.
class _Stir {
  const _Stir(this.x, this.y, this.dir, this.speed, this.time);
  final double x, y, dir, speed, time;
}

class _Push {
  const _Push(this.x, this.y, this.dir, this.speed, this.age);
  final double x, y, dir, speed, age;
}

/// Grains shed from the grass by a finger, as a fixed pool.
class _Kicked {
  _Kicked(this.cap)
    : x = Float32List(cap),
      y = Float32List(cap),
      vx = Float32List(cap),
      vy = Float32List(cap),
      age = Float32List(cap),
      life = Float32List(cap);

  final int cap;
  final Float32List x, y, vx, vy, age, life;
  int _next = 0;
  double clock = 0;
  double? left;
  int seen = -1;
  final math.Random _r = math.Random(5);

  double rand() => _r.nextDouble();

  void spawn({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required double life,
  }) {
    final i = _next;
    _next = (_next + 1) % cap;
    this.x[i] = x;
    this.y[i] = y;
    this.vx[i] = vx;
    this.vy[i] = vy;
    age[i] = 0;
    this.life[i] = life;
  }
}

// ── Grass ──────────────────────────────────────────────────────────────────

/// Blades sorted by x, so a frame only walks the ones it can see.
class _Blades {
  _Blades(
    this.x,
    this.base,
    this.height,
    this.lean,
    this.phase,
    this.depth,
    this.row,
  ) : n = x.length,
      bend = Float32List(x.length),
      vel = Float32List(x.length);
  final Float32List x, base, height, lean, phase, depth;
  final Uint8List row;
  final int n;

  /// Each blade's bend from fingers (radians) and how fast it is swinging.
  final Float32List bend, vel;

  /// The blades still moving, as an index range (empty when hi < lo), the
  /// time they were last moved, and the most a finger bends one.
  int lo = 0, hi = -1;
  double clock = -1;
  double maxBend = 0;

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

class _BladeBuilder {
  final _items = <(double, double, double, double, double, double, int)>[];

  void add({
    required double x,
    required double base,
    required double height,
    required double lean,
    required double phase,
    required double depth,
    required int row,
  }) => _items.add((x, base, height, lean, phase, depth, row));

  _Blades done() {
    _items.sort((a, b) => a.$1.compareTo(b.$1));
    final n = _items.length;
    final x = Float32List(n),
        base = Float32List(n),
        height = Float32List(n),
        lean = Float32List(n),
        phase = Float32List(n),
        depth = Float32List(n);
    final row = Uint8List(n);
    for (var i = 0; i < n; i++) {
      final it = _items[i];
      x[i] = it.$1;
      base[i] = it.$2;
      height[i] = it.$3;
      lean[i] = it.$4;
      phase[i] = it.$5;
      depth[i] = it.$6;
      row[i] = it.$7;
    }
    return _Blades(x, base, height, lean, phase, depth, row);
  }
}

// ── Motes ──────────────────────────────────────────────────────────────────

/// Motes rising slowly off the meadow, spread over the whole layer.
class _Motes {
  _Motes(
    this.x0,
    this.y0,
    this.speed,
    this.phase, {
    required this.width,
    required this.yTop,
    required this.yBottom,
  }) : n = x0.length;

  factory _Motes.make(double width, double h, double u) {
    final r = FieldRandom(808);
    final n = (width / (9 * u)).round();
    final x0 = Float32List(n),
        y0 = Float32List(n),
        speed = Float32List(n),
        phase = Float32List(n);
    for (var i = 0; i < n; i++) {
      x0[i] = r.next() * width;
      y0[i] = h * r.range(0.36, 0.86);
      speed[i] = r.range(3, 10) * u;
      phase[i] = r.range(0, math.pi * 2);
    }
    return _Motes(
      x0,
      y0,
      speed,
      phase,
      width: width,
      yTop: h * 0.36,
      yBottom: h * 0.86,
    );
  }

  final Float32List x0, y0, speed, phase;
  final double width, yTop, yBottom;
  final int n;
}

/// A canvas that draws nothing, for walking a painter only for the grains
/// of light it lays down.
class _NullCanvas implements Canvas {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.memberName == #getSaveCount ? 1 : null;
}
