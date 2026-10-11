import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/ability_grains.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart'
    show elementColor, kElementColors;
import 'package:alchemons/games/cosmic/vfx_shapes.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/widgets/fx/fusion_burst.dart' show octagramLine;
import 'package:flutter/material.dart';
import 'package:graphx/graphx.dart';

// The flourish a Mystic throws when it casts its world, drawn over the game
// in screen pixels: the element forming at the caster, the sigil written
// under it, the cast carried to its target and a small sigil where it lands.
//
// A cast is alchemy, so it is written in the game's particle language: lit
// grains in motion (the ability grain, one atlas draw per cast) over soft
// pooled light (vfxSpill) and a few filled material shapes from the shared
// kit (vfx_shapes.dart), coloured by each element's material. No strokes,
// hoops, spokes or reticles; nothing flashes, nothing is blurred. The sigil
// is the ringed octagram {8/3}, written in grains along its own lines as the
// fusion writes it.
//
// Each cast is one display object painting straight to the canvas from its
// age (no tweens, no child sprites, so no offscreen layers), and the scene's
// ticker sleeps whenever nothing is playing.

class MysticGraphxOverlayController {
  _MysticGraphxScene? _scene;

  void _attach(_MysticGraphxScene scene) {
    _scene = scene;
  }

  void _detach(_MysticGraphxScene scene) {
    if (identical(_scene, scene)) {
      _scene = null;
    }
  }

  void spawn(MysticSpecialCastEvent event) {
    _scene?.spawn(event);
  }

  void clear() {
    _scene?.clearEffects();
  }

  void dispose() {
    _scene = null;
  }
}

class MysticGraphxOverlay extends StatefulWidget {
  final MysticGraphxOverlayController controller;

  const MysticGraphxOverlay({super.key, required this.controller});

  @override
  State<MysticGraphxOverlay> createState() => _MysticGraphxOverlayState();
}

class _MysticGraphxOverlayState extends State<MysticGraphxOverlay> {
  late final _MysticGraphxScene _scene;

  @override
  void initState() {
    super.initState();
    // The grain the casts are drawn in (the survival game loads it too;
    // until it lands the grains are drawn as plain discs).
    AbilityGrainSprite.ensureLoaded().ignore();
    _scene = _MysticGraphxScene();
    widget.controller._attach(_scene);
  }

  @override
  void dispose() {
    widget.controller._detach(_scene);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The scene's ticker only runs while a cast is playing: it sleeps once the
    // last effect has gone (see _MysticGraphxScene.update), so the full-screen
    // layer is not repainted every frame of a run with nothing on it.
    return IgnorePointer(
      child: SceneBuilderWidget(
        autoSize: true,
        builder: () =>
            SceneController(front: _scene, config: SceneConfig.autoRender),
      ),
    );
  }
}

class _MysticGraphxScene extends GSprite {
  /// Most casts on screen at once; past it the oldest goes.
  static const int _maxCasts = 12;
  static const int _spawnWindowMs = 700;

  final Random _rng = Random();
  final List<int> _recentSpawnMs = <int>[];

  /// Casts that arrived while the ticker slept (or before the scene was on
  /// stage). They are written on the next tick, from [update]: by then that
  /// tick's long first step after a sleep has gone by, so it cannot carry a
  /// fresh cast straight to its end.
  final List<MysticSpecialCastEvent> _pending = <MysticSpecialCastEvent>[];

  /// The controller starts its ticker running; the first empty tick puts it
  /// to sleep.
  bool _ticking = true;

  /// Whether the scene's ticker is running (a cast is playing).
  bool get isTicking => _ticking;

  GTicker? get _ticker => stage?.scene.core.ticker;

  @override
  void update(double delta) {
    super.update(delta);
    if (_pending.isNotEmpty) {
      final casts = List<MysticSpecialCastEvent>.of(_pending);
      _pending.clear();
      casts.forEach(_spawnNow);
    }
    // Nothing left to animate: this tick paints the empty layer, then the
    // ticker sleeps until the next cast.
    if (numChildren == 0 && _ticking) {
      _ticking = false;
      _ticker?.pause();
    }
  }

  void clearEffects() {
    _recentSpawnMs.clear();
    _pending.clear();
    removeChildren(0, -1, true);
  }

  void spawn(MysticSpecialCastEvent e) {
    if (_ticking && stage != null) {
      _spawnNow(e);
      return;
    }
    _pending.add(e);
    if (!_ticking && stage != null) {
      _ticking = true;
      _ticker?.resume();
    }
  }

  void _spawnNow(MysticSpecialCastEvent e) {
    final tier = _captureQualityTier(e.isEcho);
    addChild(_CastFx(e, tier: tier, seed: _rng.nextDouble() * 997));
    while (numChildren > _maxCasts) {
      removeChildAt(0, true);
    }
  }

  int _captureQualityTier(bool echo) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _recentSpawnMs.removeWhere((t) => now - t > _spawnWindowMs);
    _recentSpawnMs.add(now);

    // A cast is one child now (it was three to a dozen), so each weighs four
    // of the old pressure points.
    final pressure = numChildren * 4 + (_recentSpawnMs.length * (echo ? 2 : 3));
    if (echo && pressure > 36) return 0;
    if (pressure > 30) return 1;
    if (pressure > 18) return 2;
    return 3;
  }
}

// ─── timing ─────────────────────────────────────────────────────────────────

double _c01(double x) => x <= 0 ? 0 : (x >= 1 ? 1 : x);

/// Ease out (cubic): fast away, settling in.
double _eo(double x) {
  final u = 1 - _c01(x);
  return 1 - u * u * u;
}

/// Ease in and out (smoothstep).
double _ss(double x) {
  final u = _c01(x);
  return u * u * (3 - 2 * u);
}

/// 0 → 1 over [a]–[b], held, then 1 → 0 over [c]–[d], eased both ways.
double _win(double t, double a, double b, double c, double d) =>
    _ss((t - a) / (b - a)) * (1 - _ss((t - c) / (d - c)));

double _backOut(double x) {
  const c1 = 1.9, c3 = c1 + 1;
  final y = x - 1;
  return 1 + c3 * y * y * y + c1 * y * y;
}

int _mix(int a, int b, double t) {
  int ch(int sh) {
    final x = (a >> sh) & 0xFF, y = (b >> sh) & 0xFF;
    return (x + (y - x) * t).round().clamp(0, 255);
  }

  return (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

int _rgbOf(Color c) => c.toARGB32() & 0xFFFFFF;

// ─── materials ──────────────────────────────────────────────────────────────

/// An element as cast art paints it: its material (vfx_shapes.dart), the
/// light it pools ([abilityMaterialTint]: the material's light tinted toward
/// the element, more for the glowing elements) and its grain tone
/// ([abilityGrainTone]: [lit] at birth, cooling to [body]).
class _Pal {
  _Pal._(String element)
    : m = vfxMaterial(kElementColors.containsKey(element) ? element : null),
      light = abilityMaterialTint(elementColor(element)) {
    final tone = abilityGrainTone(elementColor(element));
    lit = tone.lit;
    body = tone.body;
    glint = _rgbOf(m.glint);
    hot = _mix(lit, glint, 0.35);
  }

  static final Map<String, _Pal> _cache = {};
  static _Pal of(String element) => _cache[element] ??= _Pal._(element);

  final VfxMaterial m;
  final Color light;
  late final int lit, body, glint;

  /// A grain at its hottest: its lit shade a third of the way to the glint.
  late final int hot;
}

// ─── one cast ───────────────────────────────────────────────────────────────

/// One Mystic cast, painted from its age each frame and gone when done.
///
/// Quality tiers (from the scene's spawn pressure): 0 a small puff of grains
/// only; 1 the element's form (with the puff, unless an echo); 2 adds the
/// sigil and the target's cue; 3 adds the grains carried to the target.
class _CastFx extends GShape {
  _CastFx(MysticSpecialCastEvent e, {required this.tier, required this.seed})
    : element = e.element,
      o = e.originScreen,
      target = e.targetScreen,
      echo = e.isEcho,
      pal = _Pal.of(e.element),
      s = e.isEcho ? 0.78 : 1.0,
      fade = e.isEcho ? 0.68 : 1.0 {
    duration = _durationOf();
  }

  final String element;
  final Offset o;
  final Offset? target;
  final bool echo;
  final int tier;
  final double seed;
  final _Pal pal;

  /// Size: an echo is smaller...
  final double s;

  /// ...and fainter.
  final double fade;

  late final double duration;
  double age = 0;

  static final AbilityGrainBatch _grains = AbilityGrainBatch(320);

  bool get _quick => tier <= 0 || (tier == 1 && !echo);
  bool get _form => tier >= 1;
  bool get _seal => tier >= 2;
  bool get _cue => tier >= 2 && target != null;
  bool get _stream =>
      tier >= 3 &&
      target != null &&
      (target! - o).distance >= 24 &&
      element != 'Lightning' &&
      element != 'Plant';

  /// When the cast reaches its target.
  double get _cueAt => switch (element) {
    'Lightning' => 0.04,
    'Blood' => 0.06,
    'Plant' => 0.3,
    'Spirit' => 0.4,
    _ => 0.24,
  };

  static const Map<String, double> _formDur = {
    'Fire': 1.0,
    'Lava': 1.05,
    'Lightning': 0.5,
    'Water': 0.9,
    'Ice': 1.05,
    'Steam': 1.45,
    'Earth': 0.95,
    'Mud': 1.0,
    'Dust': 1.05,
    'Crystal': 0.85,
    'Air': 0.95,
    'Plant': 1.05,
    'Poison': 1.2,
    'Spirit': 1.05,
    'Dark': 0.85,
    'Light': 1.0,
    'Blood': 1.05,
  };

  double _durationOf() {
    var d = _quick ? 0.4 : 0.0;
    if (_form) d = max(d, _formDur[element] ?? 0.8);
    if (_seal) d = max(d, 0.95);
    if (_cue) d = max(d, _cueAt + 0.62);
    if (_stream) d = max(d, 0.75);
    return d;
  }

  @override
  void update(double delta) {
    super.update(delta);
    age += min(delta, 0.1);
    if (age >= duration) removeFromParent(true);
  }

  @override
  GRect? getBounds(GDisplayObject? targetSpace, [GRect? out]) {
    final t = target ?? o;
    return (out ?? GRect())..setTo(
      min(o.dx, t.dx) - 70,
      min(o.dy, t.dy) - 70,
      (o.dx - t.dx).abs() + 140,
      (o.dy - t.dy).abs() + 140,
    );
  }

  @override
  void $applyPaint(ui.Canvas canvas) {
    final t = age;
    if (_seal) _sealLight(canvas, t);
    if (_quick) _paintQuick(canvas, t);
    if (_form) {
      switch (element) {
        case 'Fire':
          _fire(canvas, t);
        case 'Lava':
          _lava(canvas, t);
        case 'Lightning':
          _lightning(canvas, t);
        case 'Water':
          _water(canvas, t);
        case 'Ice':
          _ice(canvas, t);
        case 'Steam':
          _steam(canvas, t);
        case 'Earth':
          _earth(canvas, t);
        case 'Mud':
          _mud(canvas, t);
        case 'Dust':
          _dust(canvas, t);
        case 'Crystal':
          _crystal(canvas, t);
        case 'Air':
          _air(canvas, t);
        case 'Plant':
          _plant(canvas, t);
        case 'Poison':
          _poison(canvas, t);
        case 'Spirit':
          _spirit(canvas, t);
        case 'Dark':
          _dark(canvas, t);
        case 'Light':
          _light(canvas, t);
        case 'Blood':
          _blood(canvas, t);
        default:
          _default(canvas, t);
      }
    }
    if (_seal) _sealGrains(t);
    if (_stream) _paintStream(t);
    if (_cue) _paintCue(canvas, t);
    _grains.flush(canvas);
  }

  // ─── drawing helpers ──────────────────────────────────────────────────────

  /// Stable per-cast dice.
  double _h(int i, int k) => vfxHash(seed + i * 7.31 + k * 1.913);

  int _n(int normal, int echoCount) {
    final base = echo ? echoCount : normal;
    final scale = switch (tier) {
      >= 3 => 1.0,
      2 => 0.72,
      1 => 0.46,
      _ => 0.25,
    };
    return max(1, (base * scale).round());
  }

  void _spill(ui.Canvas c, Offset at, double r, Color color, double a) =>
      vfxSpill(c, at, r * s, color, a * fade);

  void _fill(ui.Canvas c, ui.Path p, Color color, double a) =>
      vfxFillPath(c, p, color, a * fade);

  void _g(double x, double y, double r, int rgb, double a) {
    if (a <= 0.01) return;
    _grains.add(x, y, r * s, rgb, a * fade);
  }

  // What a grain function writes: where the grain is, a size factor, and a
  // colour override (-1 for the element's own, cooling as it dies). Fields,
  // so a frame of grains allocates no records.
  double _px = 0, _py = 0, _pk = 1;
  int _pc = -1;

  /// Adds [n] grains, each with a short trail of itself a moment earlier.
  /// [at] places grain i at a time (into [_px], [_py]) and returns how
  /// strong it is, 0..1 (0: not there); a grain shrinks and cools from
  /// [hot] (default its lit shade) toward its body as it weakens.
  void _grainsOf(
    int n,
    double t,
    double Function(int i, double tt) at, {
    double r = 1.0,
    double alpha = 1,
    int trail = 2,
    double lag = 0.026,
    int? hot,
  }) {
    final lit = hot ?? pal.lit;
    for (var i = 0; i < n; i++) {
      _pk = 1;
      _pc = -1;
      final f = _c01(at(i, t));
      if (f <= 0.01) continue;
      final x = _px, y = _py, k = _pk;
      final rgb = _pc >= 0 ? _pc : _mix(pal.body, lit, f * f);
      for (var j = trail; j >= 1; j--) {
        final ft = _c01(at(i, t - j * lag));
        if (ft <= 0.01) continue;
        _g(
          _px,
          _py,
          r * k * (1 - 0.2 * j),
          rgb,
          min(f, ft) * alpha * (0.5 / (j + 0.4)),
        );
      }
      _g(x, y, r * k * (0.55 + 0.45 * f), rgb, f * alpha);
    }
  }

  static List<Offset> _alongLine(List<Offset> line, int per) => [
    for (var i = 0; i + 1 < line.length; i++)
      for (var k = 0; k < per; k++) Offset.lerp(line[i], line[i + 1], k / per)!,
  ];

  static List<Offset> _ringOf(int n) => [
    for (var k = 0; k < n; k++)
      Offset(cos(-pi / 2 + k * 2 * pi / n), sin(-pi / 2 + k * 2 * pi / n)) *
          0.84,
  ];

  // The sigil at unit radius, in the order it is written: the ring at 0.84,
  // the star's one unbroken line at 0.74 (fusionSigilLines' proportions).
  static final List<Offset> _ringUnit = _ringOf(56);
  static final List<Offset> _starUnit = _alongLine(octagramLine(0.74), 8);
  static final List<Offset> _ringSmall = _ringOf(18);
  static final List<Offset> _starSmall = _alongLine(octagramLine(0.74), 3);

  /// Points along the quadratic from [a] by [c] to [b], cut off at [end].
  static List<Offset> _quadPart(
    Offset a,
    Offset c,
    Offset b,
    double end, {
    int n = 8,
  }) {
    final out = <Offset>[];
    for (var k = 0; k <= n; k++) {
      final t = end * k / n, u = 1 - t;
      out.add(a * (u * u) + c * (2 * u * t) + b * (t * t));
    }
    return out;
  }

  /// A faceted chunk added to three shared paths (body, lit face, glint), so
  /// a handful of stones costs three fills (vfxChunk's shape, batched).
  static void _chunkInto(
    ui.Path body,
    ui.Path face,
    ui.Path glint,
    Offset c,
    double r,
    double seed,
    double rot,
  ) {
    const sides = 6;
    final pts = <Offset>[
      for (var k = 0; k < sides; k++)
        c +
            vfxPolar(
              rot + k * pi * 2 / sides + (vfxHash(seed + k) - 0.5) * 0.5,
              r * (0.72 + 0.4 * vfxHash(seed + k * 2.3)),
            ),
    ];
    body.addPolygon(pts, true);
    face.addPolygon([c + (pts[0] - c) * 0.2, pts[0], pts[1], pts[2]], true);
    glint.addPolygon([pts[0], pts[1], c + (pts[1] - c) * 0.55], true);
  }

  // ─── the sigil, the carry, the landing ────────────────────────────────────

  void _sealLight(ui.Canvas c, double t) {
    _spill(c, o, 34, pal.light, 0.2 * _win(t, 0, 0.14, 0.4, 0.95));
  }

  /// The ringed octagram {8/3} written in grains along its own lines — the
  /// ring one way round, the star the other, as the fusion draws it — held
  /// a moment, turning slowly, then let go: each grain drifts off and goes
  /// out. (It was a band ring with rune dots and orbiting reagent motes.)
  void _sealGrains(double t) {
    final r = 21.0 * s;
    final turn = (echo ? -0.22 : 0.22) * t;
    final stride = tier >= 3 && !echo ? 1 : 2;
    final lock = _win(t, 0.24, 0.32, 0.38, 0.56);
    void line(List<Offset> pts, double way, double alpha, double grain) {
      final n = pts.length;
      for (var j = 0; j < n; j += stride) {
        final u = _eo((t - 0.02 - j / n * 0.26) / 0.16);
        if (u <= 0) continue;
        final d = _ss((t - 0.48 - 0.12 * _h(j, 3)) / 0.4);
        final f = u * (1 - d) * (0.78 + 0.22 * lock);
        if (f <= 0.01) continue;
        final p = pts[j];
        final a =
            atan2(p.dy, p.dx) +
            turn +
            way * 0.7 * (1 - u) +
            (_h(j, 5) - 0.5) * 0.5 * d;
        final rr =
            p.distance * r * (1 + 0.4 * (1 - u) + 0.45 * d * (0.5 + _h(j, 4)));
        _g(
          o.dx + cos(a) * rr,
          o.dy + sin(a) * rr - 7 * s * d,
          grain * (0.6 + 0.4 * f),
          _mix(pal.body, pal.lit, f * f),
          f * alpha,
        );
      }
    }

    line(_ringUnit, -1, 0.5, 0.8);
    line(_starUnit, 1, 0.72, 0.95);
  }

  /// The smallest cast: light and a puff of grains.
  void _paintQuick(ui.Canvas c, double t) {
    _spill(c, o, 22, pal.light, 0.35 * _win(t, 0, 0.05, 0.12, 0.38));
    _grainsOf(8, t, (i, tt) {
      final u = (tt - 0.01 * i) / 0.34;
      if (u <= 0 || u >= 1) return 0;
      final a = (i + _h(i, 0)) * pi * 2 / 8;
      final e = _eo(u);
      _px = o.dx + cos(a) * (3 + 14 * e) * s;
      _py = o.dy + sin(a) * (3 + 14 * e) * s - 4 * s * e;
      return 1 - u;
    }, trail: 1);
  }

  /// The cast carried to its target: grains streaming along a gentle bow,
  /// each leaving and arriving eased, with a short trail (it was a dashed
  /// line of stroked segments). Blood's runs the other way: the tithe drains
  /// home to the caster.
  void _paintStream(double t) {
    final blood = element == 'Blood';
    final from = blood ? target! : o;
    final to = blood ? o : target!;
    final d = to - from;
    final len = d.distance;
    final nrm = Offset(-d.dy, d.dx) / len;
    final water = element == 'Water', spirit = element == 'Spirit';
    // Water's arc is thrown up and falls in; the rest bow either way.
    final side = water
        ? (nrm.dy < 0 ? 1.0 : -1.0)
        : (_h(0, 9) < 0.5 ? -1.0 : 1.0);
    final bow = len * (water ? 0.2 : 0.11) * side;
    final dur = spirit ? 0.34 : 0.24;
    final start = blood ? 0.08 : 0.03;
    final n = _n(12, 7);
    _grainsOf(
      n,
      t,
      (i, tt) {
        final u =
            (tt - start - 0.15 * i / n - 0.02 * _h(i, 1)) /
            (dur + 0.05 * _h(i, 2));
        if (u <= 0 || u >= 1) return 0;
        final e = _ss(u);
        final sway =
            sin(e * pi) *
            (bow +
                (_h(i, 3) - 0.5) * 9 * s +
                (spirit ? sin(e * pi * 3 + i) * 5 * s : 0));
        _px = from.dx + d.dx * e + nrm.dx * sway;
        _py = from.dy + d.dy * e + nrm.dy * sway;
        _pk = 0.8 + 0.4 * _h(i, 4);
        return _c01(u * 5) * (1 - _ss((u - 0.75) / 0.25));
      },
      alpha: 0.85,
      lag: 0.022,
    );
  }

  /// Where the cast lands: its light pooled on the ground and a small ringed
  /// octagram gathering in grains, held a moment, then let go (it was a
  /// stroked reticle, then a band-ringed seal).
  void _paintCue(ui.Canvas c, double t) {
    final at = target!;
    final t0 = _cueAt;
    _spill(
      c,
      at,
      18,
      pal.light,
      0.36 * _win(t, t0 - 0.06, t0 + 0.06, t0 + 0.2, t0 + 0.6),
    );
    final r = 9.0 * s;
    void line(List<Offset> pts, double way, double alpha) {
      final n = pts.length;
      for (var j = 0; j < n; j++) {
        final u = _eo((t - t0 - 0.1 * j / n) / 0.14);
        if (u <= 0) continue;
        final d = _ss((t - t0 - 0.26 - 0.08 * _h(j, 6)) / 0.32);
        final f = u * (1 - d);
        if (f <= 0.01) continue;
        final p = pts[j];
        final a = atan2(p.dy, p.dx) + way * 0.6 * (1 - u);
        final rr = p.distance * r * (1 + 0.6 * (1 - u) + 0.5 * d);
        _g(
          at.dx + cos(a) * rr,
          at.dy + sin(a) * rr - 5 * s * d,
          0.75 * (0.6 + 0.4 * f),
          _mix(pal.body, pal.lit, f * f),
          f * alpha,
        );
      }
    }

    line(_ringSmall, -1, 0.5);
    line(_starSmall, 1, 0.75);
  }

  // ─── the seventeen forms ──────────────────────────────────────────────────

  /// FIRE — the Ember Season. Flame tongues swell at the caster and are drawn
  /// back into themselves while its embers gather in; then the embers are
  /// thrown out on their own curves, rising as they slow, cooling and going
  /// out. (It was a ring that burst, then a ring of orbiting dots.)
  void _fire(ui.Canvas c, double t) {
    final S = s;
    _spill(c, o, 34, pal.light, 0.5 * _win(t, 0, 0.07, 0.2, 0.75));
    final size = 9 * S * _eo(t / 0.1) * (1 - _ss((t - 0.12) / 0.3));
    if (size > 0.4) {
      final body = ui.Path(), core = ui.Path();
      for (var j = 0; j < 3; j++) {
        final rr = size * (j == 1 ? 1.0 : 0.62 + 0.1 * j);
        final a = pi / 2 + sin(t * 13 + j * 2.1) * 0.2 + (j - 1) * 0.18;
        final at = o + Offset((j - 1) * 4.2 * S, 3 * S);
        body.addPath(vfxDrop(at, rr, a), Offset.zero);
        core.addPath(
          vfxDrop(at + Offset(0, rr * 0.2), rr * 0.5, a),
          Offset.zero,
        );
      }
      _fill(c, body, pal.m.mid, 0.8);
      _fill(c, core, Color.lerp(pal.light, pal.m.glint, 0.3)!, 0.7);
    }
    _grainsOf(
      _n(16, 9),
      t,
      (i, tt) {
        if (tt <= 0) return 0;
        final a = pi * 2 * _h(i, 0);
        final r0 = (20 + 12 * _h(i, 1)) * S;
        if (tt < 0.12) {
          final g = _ss(tt / 0.12);
          final rr = r0 * (1 - 0.85 * g);
          final aa = a + 0.7 * (1 - g);
          _px = o.dx + cos(aa) * rr;
          _py = o.dy + sin(aa) * rr;
          return 0.35 + 0.6 * g;
        }
        final u = (tt - 0.12 - 0.06 * _h(i, 2)) / (0.7 + 0.18 * _h(i, 3));
        if (u <= 0) {
          _px = o.dx + cos(a) * r0 * 0.15;
          _py = o.dy + sin(a) * r0 * 0.15;
          return 0.95;
        }
        if (u >= 1) return 0;
        final e = _eo(u);
        final a2 = a + (_h(i, 4) - 0.5) * 0.8;
        final dist = r0 * 0.15 + (26 + 24 * _h(i, 1)) * S * e;
        final curl = sin(e * pi) * (_h(i, 5) - 0.5) * 16 * S;
        _px = o.dx + cos(a2) * dist - sin(a2) * curl;
        _py =
            o.dy +
            sin(a2) * dist +
            cos(a2) * curl -
            (10 + 16 * _h(i, 2)) * S * u * u;
        _pk = 0.8 + 0.5 * _h(i, 6);
        return pow(1 - u, 1.2).toDouble();
      },
      r: 1.25,
      hot: pal.hot,
    );
  }

  /// LAVA — the Fissures. A dark crust spreads on the ground under the
  /// caster and cracks along chords (never spokes) that open from one end
  /// and glow; molten grains well up out of them and run off, cooling.
  /// (It was a crater ring round a red disc.)
  void _lava(ui.Canvas c, double t) {
    final S = s;
    final g = o + Offset(0, 8 * S);
    _spill(c, g, 32, pal.light, 0.5 * _win(t, 0, 0.08, 0.3, 0.95));
    final cr = 14 * S * (0.6 + 0.4 * _eo(t / 0.14));
    _fill(
      c,
      vfxBlob(g, cr, seed, n: 10, wobble: 0.2, squash: 0.5),
      pal.m.ink,
      0.75 * _win(t, 0, 0.06, 0.5, 1.0),
    );
    final open = _eo((t - 0.05) / 0.18);
    final glow = _win(t, 0.05, 0.15, 0.4, 1.0);
    if (open > 0 && glow > 0.01) {
      final wide = ui.Path(), molten = ui.Path();
      for (var j = 0; j < (echo ? 2 : 3); j++) {
        final a1 = pi * 2 * _h(j, 20);
        final a2 = a1 + 1.9 + 1.1 * _h(j, 21);
        final p1 = g + Offset(cos(a1) * cr * 0.92, sin(a1) * cr * 0.46);
        final p2 = g + Offset(cos(a2) * cr * 0.92, sin(a2) * cr * 0.46);
        final mid =
            Offset.lerp(p1, p2, 0.5)! * 0.7 +
            g * 0.3 +
            Offset(0, (_h(j, 22) - 0.5) * 3 * S);
        final spine = _quadPart(p1, mid, p2, open);
        vfxLensRibbon(spine, 5.5 * S, into: wide);
        vfxLensRibbon(spine, 2.2 * S, into: molten);
      }
      _fill(c, wide, pal.light, 0.3 * glow);
      _fill(c, molten, Color.lerp(pal.light, pal.m.glint, 0.35)!, 0.85 * glow);
    }
    _grainsOf(
      _n(10, 6),
      t,
      (i, tt) {
        final k = tt - 0.08 - 0.26 * _h(i, 0);
        const life = 0.55;
        if (k <= 0 || k >= life) return 0;
        final vx = (_h(i, 3) - 0.5) * 26 * S;
        final vy = (24 + 22 * _h(i, 4)) * S;
        _px = g.dx + (_h(i, 1) - 0.5) * 1.6 * cr + vx * k;
        _py =
            g.dy + (_h(i, 2) - 0.5) * 0.7 * cr - vy * k + 0.5 * 170 * S * k * k;
        return 1 - k / life;
      },
      r: 1.2,
      hot: pal.hot,
    );
  }

  /// LIGHTNING — the Storm. A few short arcs writhe off the caster at uneven
  /// bearings and one strikes the target: filled ribbons whose bends glide
  /// between poses (vfxArcInto). Charge crackles round the caster as grains
  /// that glide from place to place, and sparks fly at the strike. (It was a
  /// wheel of stroked zig-zags.)
  void _lightning(ui.Canvas c, double t) {
    final S = s;
    _spill(c, o, 28, pal.light, 0.5 * _win(t, 0, 0.03, 0.08, 0.4));
    final env = _win(t, 0, 0.03, 0.14, 0.34);
    if (env > 0.01) {
      final glow = ui.Path(), core = ui.Path();
      // Short leaders fork off the root of the strike toward its side, the
      // way a bolt branches: never a wheel of arcs round the caster.
      final aim = target != null && (target! - o).distance > 12
          ? atan2(target!.dy - o.dy, target!.dx - o.dx)
          : -pi / 2;
      final arcs = echo ? 1 : 2;
      for (var j = 0; j < arcs; j++) {
        final a0 = aim + (j.isEven ? -1 : 1) * (0.5 + 0.45 * _h(j, 30));
        final a1 = a0 + (_h(j, 31) - 0.5) * 0.6;
        vfxArcInto(
          glow,
          core,
          o + vfxPolar(a0, 3 * S),
          o + vfxPolar(a1, (16 + 14 * _h(j, 32)) * S),
          seed + j * 5.3,
          t,
          width: 1.5 * S,
          amp: 0.22,
          segs: 4,
          rate: 3.2,
        );
      }
      final at = target;
      if (at != null && (at - o).distance > 12) {
        final d = at - o;
        vfxArcInto(
          glow,
          core,
          o + d / d.distance * 4 * S,
          at,
          seed + 17,
          t,
          width: 1.9 * S,
          amp: 0.15,
          segs: 6,
          rate: 3.0,
        );
      }
      _fill(c, glow, pal.light, 0.32 * env);
      _fill(
        c,
        core,
        Color.lerp(pal.m.glint, elementColor('Lightning'), 0.3)!,
        0.88 * env,
      );
    }
    _grainsOf(
      _n(14, 8),
      t,
      (i, tt) {
        final a =
            pi * 2 * _h(i, 0) + (vfxGlide(seed + i * 3.1, tt, 7) - 0.5) * 1.4;
        final rr = (5 + 18 * vfxGlide(seed + i * 5.3 + 1, tt, 8)) * S;
        _px = o.dx + cos(a) * rr;
        _py = o.dy + sin(a) * rr;
        return _win(tt, 0, 0.02, 0.1 + 0.1 * _h(i, 1), 0.32 + 0.1 * _h(i, 2));
      },
      r: 0.95,
      hot: pal.hot,
      trail: 1,
      lag: 0.02,
    );
    final at = target;
    if (at != null) {
      _grainsOf(
        _n(6, 3),
        t,
        (i, tt) {
          final u = (tt - 0.03 - 0.02 * _h(i, 3)) / 0.26;
          if (u <= 0 || u >= 1) return 0;
          final a = pi * 2 * _h(i, 4);
          final rr = (3 + 13 * _eo(u)) * S;
          _px = at.dx + cos(a) * rr;
          _py = at.dy + sin(a) * rr + 6 * S * u * u;
          return 1 - u;
        },
        r: 0.9,
        hot: pal.hot,
      );
    }
  }

  /// WATER — the Maelstrom. Current arms wind into an eye at the caster and
  /// turn; water is drawn in along them, then spray is thrown off and falls.
  /// (It was two stroked chevrons and a scatter of dots.)
  void _water(ui.Canvas c, double t) {
    final S = s;
    _spill(c, o, 30, pal.light, 0.42 * _win(t, 0, 0.08, 0.25, 0.8));
    final env = _win(t, 0, 0.1, 0.35, 0.75);
    if (env > 0.01) {
      final arms = ui.Path(), crest = ui.Path();
      final count = echo ? 2 : 3;
      final r = 24 * S * (0.85 + 0.3 * _eo(t / 0.2));
      for (var j = 0; j < count; j++) {
        final a = pi * 2 * j / count + _h(j, 40) * 0.8 + t * 4.0;
        arms.addPath(vfxSpiralArm(o, r, a, 2.4, 5.2 * S), Offset.zero);
        crest.addPath(
          vfxSpiralArm(o, r * 0.94, a + 0.08, 2.2, 2.0 * S),
          Offset.zero,
        );
      }
      _fill(c, arms, pal.m.mid, 0.6 * env);
      _fill(c, crest, pal.light, 0.42 * env);
    }
    _grainsOf(_n(12, 7), t, (i, tt) {
      final u = (tt - 0.04 * _h(i, 0)) / 0.45;
      if (u <= 0 || u >= 1) return 0;
      final e = _eo(u);
      final a = pi * 2 * _h(i, 1) + e * 2.6 + tt * 1.5;
      final rr = (30 - 26 * e) * S * (0.8 + 0.4 * _h(i, 2));
      _px = o.dx + cos(a) * rr;
      _py = o.dy + sin(a) * rr;
      return _ss(u / 0.15) * (1 - _ss((u - 0.6) / 0.4));
    });
    _grainsOf(
      _n(8, 4),
      t,
      (i, tt) {
        final k = tt - 0.2 - 0.14 * _h(i, 3);
        const life = 0.5;
        if (k <= 0 || k >= life) return 0;
        final vx = (_h(i, 4) - 0.5) * 70 * S;
        final vy = (40 + 30 * _h(i, 5)) * S;
        _px = o.dx + vx * k;
        _py = o.dy - vy * k + 0.5 * 240 * S * k * k;
        return 1 - k / life;
      },
      r: 1.05,
      hot: pal.hot,
    );
  }

  /// ICE — the Blizzard. Frost condenses out of the air onto a small crown
  /// of ice rising at the caster (a few short shards in a cluster, each with
  /// a lit face), which lets go into a flurry drifting off sideways and
  /// down, swaying, a few grains catching the light. (It was a stroked
  /// hexagon and an asterisk of lances.)
  void _ice(ui.Canvas c, double t) {
    final S = s;
    _spill(c, o, 28, pal.light, 0.4 * _win(t, 0, 0.1, 0.35, 0.95));
    final keep = 1 - _ss((t - 0.4) / 0.28);
    if (keep > 0.01) {
      // A skin of frost on the ground first, its far edge catching the
      // light; then slim needles stand up out of it, each rooted at its own
      // place and near upright (a crown, never a fan from one point).
      final plate = _eo((t - 0.04) / 0.2);
      if (plate > 0.01) {
        final g = o + Offset(0, 6 * S);
        _fill(
          c,
          vfxBlob(g, 13 * S * plate, seed + 2, n: 7, wobble: 0.22, squash: 0.42),
          pal.m.mid,
          0.55 * keep,
        );
        _fill(
          c,
          vfxBlob(
            g - Offset(1.5 * S, 1.8 * S),
            9 * S * plate,
            seed + 5,
            n: 6,
            wobble: 0.25,
            squash: 0.3,
          ),
          pal.light,
          0.4 * keep,
        );
      }
      final body = ui.Path(), face = ui.Path();
      const tilt = [-0.26, 0.04, 0.3, -0.12];
      const lens = [10.0, 14.5, 9.0, 7.0];
      const at = [-1.0, 0.0, 1.0, 0.45];
      final count = echo ? 2 : (tier >= 3 ? 4 : 3);
      for (var j = 0; j < count; j++) {
        final grow = _eo((t - 0.12 - 0.035 * j) / 0.16);
        if (grow <= 0) continue;
        final a = -pi / 2 + tilt[j] + (_h(j, 50) - 0.5) * 0.12;
        final len = lens[j] * S * grow;
        final w = 2.3 * S * (0.6 + 0.4 * grow);
        final base = o + Offset(at[j] * 5.5 * S, (5 + 1.2 * at[j].abs()) * S);
        final cc = base + vfxPolar(a, len * 0.35);
        body.addPath(vfxShard(cc, len, w, a), Offset.zero);
        final d = vfxPolar(a, 1), nn = Offset(-d.dy, d.dx);
        face.addPolygon([cc + d * len, cc + nn * w, cc - d * len * 0.35], true);
      }
      _fill(c, body, pal.m.mid, 0.9 * keep);
      _fill(c, face, pal.light, 0.65 * keep);
    }
    _grainsOf(_n(16, 9), t, (i, tt) {
      if (tt <= 0) return 0;
      final from = o + vfxPolar(pi * 2 * _h(i, 0), (24 + 12 * _h(i, 1)) * S);
      final q = o + Offset((_h(i, 2) - 0.5) * 12 * S, -(2 + 10 * _h(i, 3)) * S);
      final e = _eo((tt - 0.04 * _h(i, 4)) / 0.26);
      var p = Offset.lerp(from, q, e)!;
      var f = 0.45 + 0.55 * e;
      final u = (tt - 0.36 - 0.16 * _h(i, 5)) / 0.55;
      if (u > 0) {
        if (u >= 1) return 0;
        p += Offset(
          sin(u * 5 + _h(i, 6) * 6) * 6 * S + (_h(i, 7) - 0.5) * 34 * S * u,
          (12 + 14 * _h(i, 8)) * S * u,
        );
        f = 1 - u;
      }
      _px = p.dx;
      _py = p.dy;
      if (_h(i, 9) > 0.78) {
        _pc = _mix(
          _mix(pal.body, pal.lit, f * f),
          pal.glint,
          0.6 * _win(tt, 0.22, 0.3, 0.36, 0.5),
        );
      }
      return f;
    }, hot: pal.hot);
  }

  /// STEAM — the Pressure. Soft puffs billow out and up from the vent while
  /// its light swells outward, and vapour grains rise slowly through them.
  /// (Its fog ring is gone: the push is the light.)
  void _steam(ui.Canvas c, double t) {
    final S = s;
    _spill(
      c,
      o,
      18 + 34 * _eo(t / 0.5),
      pal.light,
      0.3 * _win(t, 0, 0.08, 0.2, 0.8),
    );
    final env = _win(t, 0, 0.12, 0.55, 1.35);
    if (env > 0.01) {
      final body = ui.Path(), lit = ui.Path();
      final n = _n(7, 4);
      for (var i = 0; i < n; i++) {
        final u = _c01(
          (t - 0.03 * i - 0.05 * _h(i, 0)) / (0.9 + 0.4 * _h(i, 1)),
        );
        if (u <= 0) continue;
        final e = _eo(u);
        final side = (_h(i, 2) - 0.5) * 2;
        final cc =
            o +
            Offset(
              side * (4 + 18 * e) * S,
              -(4 + 30 * e * (0.6 + 0.6 * _h(i, 3))) * S,
            );
        final rr =
            (4 + 10 * e) *
            S *
            (0.8 + 0.4 * _h(i, 4)) *
            (1 - 0.25 * _ss((u - 0.6) / 0.4));
        body.addPath(
          vfxBlob(cc, rr, seed + i * 3.3, n: 9, wobble: 0.22),
          Offset.zero,
        );
        lit.addPath(
          vfxBlob(
            cc + Offset(-rr * 0.18, -rr * 0.28),
            rr * 0.55,
            seed + i * 5.1,
            n: 8,
            wobble: 0.2,
          ),
          Offset.zero,
        );
      }
      _fill(c, body, pal.light, 0.24 * env);
      _fill(c, lit, Color.lerp(pal.light, pal.m.glint, 0.4)!, 0.16 * env);
    }
    _grainsOf(
      _n(14, 8),
      t,
      (i, tt) {
        final u = (tt - 0.05 * _h(i, 0)) / (1.05 + 0.25 * _h(i, 1));
        if (u <= 0 || u >= 1) return 0;
        final e = _eo(u);
        _px =
            o.dx +
            (_h(i, 2) - 0.5) * (14 + 24 * e) * S +
            sin(tt * 2.2 + _h(i, 3) * 6) * 4 * S;
        _py = o.dy - (3 + 40 * e * (0.5 + _h(i, 4))) * S;
        return sin(pi * u) * 0.8;
      },
      r: 1.3,
      trail: 0,
    );
  }

  /// EARTH — the Quaking. A dust front runs out low along the ground while
  /// rubble is thrown up and comes down to rest — dark stone, a lit face, a
  /// glint — with grit raining round it. (It was a crater ring and flat
  /// rectangles.)
  void _earth(ui.Canvas c, double t) {
    final S = s;
    final g = o + Offset(0, 9 * S);
    final e = _eo(t / 0.5);
    final env = _win(t, 0, 0.06, 0.25, 0.9);
    _fill(
      c,
      vfxBlob(g, (10 + 30 * e) * S, seed, n: 12, wobble: 0.2, squash: 0.36),
      pal.light,
      0.26 * env,
    );
    _fill(
      c,
      vfxBlob(g, (8 + 18 * e) * S, seed + 9, n: 10, wobble: 0.2, squash: 0.36),
      pal.m.mid,
      0.3 * env,
    );
    final bodies = ui.Path(), faces = ui.Path(), glints = ui.Path();
    const grav = 300.0;
    for (var i = 0; i < _n(6, 4); i++) {
      var k = t - 0.02 * _h(i, 0);
      if (k <= 0) continue;
      final a = -pi / 2 + (_h(i, 1) - 0.5) * 2.4;
      final v = (50 + 40 * _h(i, 2)) * S;
      final vy = sin(a) * v;
      final y0 = g.dy - 4 * S;
      final floor = g.dy + (_h(i, 3) - 0.5) * 8 * S;
      // Lands, and stays where it fell.
      final land =
          (-vy + sqrt(vy * vy + 2 * grav * S * (floor - y0))) / (grav * S);
      k = min(k, land);
      final at = Offset(
        g.dx + cos(a) * v * k,
        y0 + vy * k + 0.5 * grav * S * k * k,
      );
      final rot = _h(i, 5) * 6 + k * (_h(i, 6) - 0.5) * 10;
      _chunkInto(
        bodies,
        faces,
        glints,
        at,
        (2.4 + 1.6 * _h(i, 4)) * S,
        seed + i,
        rot,
      );
    }
    final keep = 1 - _ss((t - 0.55) / 0.35);
    _fill(c, bodies, Color.lerp(pal.m.ink, pal.m.mid, 0.45)!, 0.92 * keep);
    _fill(c, faces, Color.lerp(pal.m.mid, pal.light, 0.5)!, 0.8 * keep);
    _fill(c, glints, pal.m.glint, 0.35 * keep);
    _grainsOf(
      _n(14, 8),
      t,
      (i, tt) {
        final k = tt - 0.01 * _h(i, 0);
        const life = 0.6;
        if (k <= 0 || k >= life) return 0;
        final a = -pi / 2 + (_h(i, 1) - 0.5) * 2.6;
        final v = (30 + 50 * _h(i, 2)) * S;
        _px = g.dx + cos(a) * v * k;
        _py = g.dy - 3 * S + sin(a) * v * k + 0.5 * 260 * S * k * k;
        return 1 - k / life;
      },
      r: 0.95,
      trail: 1,
    );
  }

  /// MUD — the Mire. A puddle spreads on the ground under the caster, its
  /// far edge catching the light, a slow swell of wet light under it, and
  /// mud plops up off it and falls back in. (It was a flat splat disc.)
  void _mud(ui.Canvas c, double t) {
    final S = s;
    final g = o + Offset(0, 9 * S);
    final env = _win(t, 0, 0.05, 0.45, 1.0);
    final rx = (8 + 12 * _eo(t / 0.22)) * S;
    final sw = _ss((t - 0.08) / 0.6);
    _fill(
      c,
      vfxBlob(
        g,
        rx * (0.7 + 0.7 * sw),
        seed + 4,
        n: 11,
        wobble: 0.14,
        squash: 0.42,
      ),
      pal.light,
      0.16 * (1 - sw) * env,
    );
    _fill(
      c,
      vfxBlob(g, rx, seed, n: 11, wobble: 0.18, squash: 0.42),
      pal.m.mid,
      0.75 * env,
    );
    _fill(
      c,
      vfxEllipseCrescent(g, rx * 0.86, rx * 0.36, 1.8 * S, -pi / 2, 2.3),
      pal.light,
      0.5 * env,
    );
    const grav = 240.0;
    _grainsOf(
      _n(8, 5),
      t,
      (i, tt) {
        final k = tt - 0.04 - 0.3 * _h(i, 0);
        if (k <= 0) return 0;
        final vy = (28 + 24 * _h(i, 1)) * S;
        final land = 2 * vy / (grav * S);
        if (k >= land + 0.08) return 0;
        final kk = min(k, land);
        _px =
            g.dx + (_h(i, 2) - 0.5) * 1.5 * rx + (_h(i, 4) - 0.5) * 22 * S * kk;
        _py =
            g.dy +
            (_h(i, 3) - 0.5) * 0.2 * rx -
            vy * kk +
            0.5 * grav * S * kk * kk;
        return k < land ? 1 : 1 - (k - land) / 0.08;
      },
      r: 1.25,
      hot: pal.hot,
    );
  }

  /// DUST — the Haze. Dust curls loose off the caster and streams away
  /// downwind, fluttering, under a haze of its own light. (It was an even
  /// golden spiral of motes fanning out.)
  void _dust(ui.Canvas c, double t) {
    final S = s;
    final w = vfxPolar(-0.25 + (_h(0, 60) - 0.5) * 0.3, 1);
    final across = Offset(-w.dy, w.dx);
    final e = _eo(t / 0.8);
    _spill(
      c,
      o + w * 18 * S * e,
      20 + 16 * e,
      pal.light,
      0.26 * _win(t, 0, 0.1, 0.3, 0.95),
    );
    _grainsOf(
      _n(24, 13),
      t,
      (i, tt) {
        final u = (tt - 0.012 * i) / (0.78 + 0.2 * _h(i, 0));
        if (u <= 0 || u >= 1) return 0;
        final ee = _eo(u);
        final a = pi * 2 * _h(i, 1) + 1.4 * ee;
        final r0 = (3 + 9 * _h(i, 2)) * S * (1 + 0.6 * ee);
        final run = (44 + 30 * _h(i, 3)) * S * pow(ee, 1.2);
        final flutter = sin(tt * 5 + _h(i, 4) * 6) * 4 * S * ee;
        _px = o.dx + cos(a) * r0 + w.dx * run + across.dx * flutter;
        _py = o.dy + sin(a) * r0 + w.dy * run + across.dy * flutter;
        _pk = 0.8 + 0.4 * _h(i, 5);
        return pow(sin(pi * u), 0.6).toDouble();
      },
      r: 0.95,
      lag: 0.03,
    );
  }

  /// CRYSTAL — the Vein. A cluster of prisms grows up out of the ground
  /// under the caster, each rooted at its own place along the vein and
  /// standing near upright, chunky and two-faced (lit side, shadow side);
  /// a glint runs along them; then they lift a little and come apart into
  /// chips that glint as they fall. (It was a wheel of stroked spokes, then
  /// a pinwheel of loose facets round the caster.)
  void _crystal(ui.Canvas c, double t) {
    final S = s;
    final g = o + Offset(0, 7 * S);
    _spill(c, g, 26, pal.light, 0.42 * _win(t, 0, 0.06, 0.3, 0.8));
    final n = echo ? 3 : 5;
    const heights = [8.0, 13.0, 16.0, 11.0, 7.0];
    final keep = 1 - _ss((t - 0.42) / 0.3);
    if (keep > 0.01) {
      final shade = ui.Path(), lit = ui.Path(), glints = ui.Path();
      final lift = 5 * S * _ss((t - 0.4) / 0.35);
      for (var j = 0; j < n; j++) {
        final x = j - (n - 1) / 2;
        final grow = _backOut(_c01((t - 0.035 * j) / 0.18));
        if (grow <= 0.01) continue;
        // Rooted along the vein; the outer prisms lean out a little, as a
        // geode cluster does. Never fanned from one point.
        final lean = x * 0.17 + (_h(j, 70) - 0.5) * 0.14;
        final up = vfxPolar(-pi / 2 + lean, 1), side = Offset(-up.dy, up.dx);
        final base =
            g +
            Offset(x * 4.6 * S + (_h(j, 71) - 0.5) * 1.6 * S, x * x * 0.5 * S) -
            Offset(0, lift * (0.6 + 0.4 * _h(j, 72)));
        final hgt = heights[(j + (n == 3 ? 1 : 0)) % 5] *
            (0.85 + 0.3 * _h(j, 73)) *
            S *
            grow;
        final w = (2.4 + 0.8 * _h(j, 74)) * S * min(1.0, grow);
        final shoulder = base + up * hgt * 0.72;
        final tip = base + up * hgt;
        final bl = base - side * w, br = base + side * w;
        final sl = shoulder - side * w, sr = shoulder + side * w;
        // Shadow face right, lit face left (one light for the cluster).
        shade.addPolygon([base, br, sr, tip, shoulder], true);
        lit.addPolygon([bl, base, shoulder, tip, sl], true);
        // A glint runs along the cluster, left to right.
        final run = _win(t, 0.16 + 0.05 * j, 0.2 + 0.05 * j, 0.26 + 0.05 * j,
            0.34 + 0.05 * j);
        if (run > 0.05) {
          glints.addPolygon(
            [sl, tip, Offset.lerp(sl, shoulder, 0.55)! + up * w * 0.4 * run],
            true,
          );
        }
      }
      _fill(c, shade, pal.m.mid, 0.92 * keep);
      _fill(c, lit, Color.lerp(pal.m.mid, pal.light, 0.62)!, 0.95 * keep);
      _fill(c, glints, pal.m.glint, 0.8 * keep);
    }
    // Chips: they glint off the prisms as the glint passes, then, as the
    // cluster lets go, fall away and go out.
    _grainsOf(
      _n(14, 8),
      t,
      (i, tt) {
        final j = i % n;
        final x = j - (n - 1) / 2;
        final h0 = heights[(j + (n == 3 ? 1 : 0)) % 5] * S;
        final px = g.dx + x * 4.6 * S + (_h(i, 1) - 0.5) * 5 * S;
        final py = g.dy - h0 * (0.3 + 0.6 * _h(i, 2));
        final born = 0.18 + 0.05 * j + 0.04 * _h(i, 3);
        final k = tt - born;
        if (k <= 0) return 0;
        const life = 0.7;
        if (k >= life) return 0;
        final drift = (_h(i, 4) - 0.5) * 22 * S;
        _px = px + drift * k;
        _py = py - 8 * S * k + 46 * S * k * k;
        if (k < 0.1) _pc = pal.glint;
        return _ss(k / 0.04) * (1 - k / life);
      },
      r: 0.95,
      hot: pal.hot,
    );
  }

  /// AIR — the updraft that feeds the Tornado. Bands of moving air slide up
  /// a curling path off the caster, and grains lift and curl round an eddy
  /// the way smoke curls. (It was a dashed ring and stroked velocity ticks.)
  void _air(ui.Canvas c, double t) {
    final S = s;
    final env = _win(t, 0, 0.1, 0.5, 0.9);
    _spill(c, o, 24, pal.light, 0.22 * env);
    if (env > 0.01) {
      final band = ui.Path(), haze = ui.Path();
      final head = 1.1 * _ss(t / 0.8);
      for (var j = 0; j < (echo ? 1 : 2); j++) {
        final s0 = -0.25 + head - j * 0.2;
        final dir = j == 0 ? 1.0 : -1.0;
        final spine = <Offset>[];
        for (var k = 0; k <= 12; k++) {
          final q = s0 + 0.42 * k / 12;
          if (q < 0 || q > 1) continue;
          spine.add(
            o +
                Offset(
                  dir * sin(q * 4.4 + j * 2.4) * (8 + 10 * q) * S,
                  (10 - 50 * q) * S,
                ),
          );
        }
        if (spine.length >= 3) {
          vfxLensRibbon(spine, 3.4 * S, into: band);
          vfxLensRibbon(spine, 8 * S, into: haze);
        }
      }
      _fill(c, haze, pal.light, 0.1 * env);
      _fill(c, band, pal.light, 0.34 * env);
    }
    final eddy = o + Offset(6 * S, -16 * S);
    final sig2 = (16 * S) * (16 * S);
    _grainsOf(_n(20, 11), t, (i, tt) {
      final u = (tt - 0.03 * _h(i, 0)) / (0.78 + 0.15 * _h(i, 1));
      if (u <= 0 || u >= 1) return 0;
      final e = _eo(u);
      final a0 = pi * 2 * _h(i, 2);
      final r0 = (4 + 12 * _h(i, 3)) * S;
      final qx = o.dx + cos(a0) * r0;
      final qy =
          o.dy +
          sin(a0) * r0 * 0.6 -
          (10 + 30 * e) * S * (0.6 + 0.6 * _h(i, 4));
      final dx = qx - eddy.dx, dy = qy - eddy.dy;
      final ang = 1.8 * e * exp(-(dx * dx + dy * dy) / sig2);
      final cs = cos(ang), sn = sin(ang);
      _px = eddy.dx + dx * cs - dy * sn;
      _py = eddy.dy + dx * sn + dy * cs;
      return pow(sin(pi * u), 0.6).toDouble() * 0.9;
    }, lag: 0.03);
  }

  /// PLANT — the Grove. A vine grows from the caster to its target, a filled
  /// tapering ribbon with leaves opening along it as it passes, pollen lifting
  /// off them. (It was a stroked line with stroked thorns.)
  void _plant(ui.Canvas c, double t) {
    final S = s;
    final at0 = target;
    var d = at0 != null ? at0 - o : const Offset(1, -0.25);
    if (d.distance < 1) d = const Offset(1, 0);
    final dir = d / d.distance;
    final nrm = Offset(-dir.dy, dir.dx);
    final len = min(150.0, at0 != null ? d.distance : 104.0);
    final grow = _eo(t / 0.34);
    final env = _win(t, 0, 0.04, 0.6, 1.0);
    final phase = _h(0, 80) * 6;
    Offset along(double f) =>
        o +
        dir * (len * f) +
        nrm * (sin(f * pi * 1.6 + phase) * len * 0.07 * (1 - 0.3 * f));
    // When the growing tip passes f (the inverse of its ease).
    double reaches(double f) => 0.34 * (1 - pow(1 - f, 1 / 3).toDouble());
    if (grow > 0.02 && env > 0.01) {
      final spine = <Offset>[
        for (var k = 0; k <= 12; k++) along(grow * k / 12),
      ];
      _fill(c, vfxRibbon(spine, 5.5 * S, 1.4 * S), pal.m.mid, 0.9 * env);
      _fill(c, vfxRibbon(spine, 2.0 * S, 0.4 * S), pal.light, 0.32 * env);
    }
    final nodes = echo ? 3 : 4;
    final leaves = ui.Path();
    for (var j = 0; j < nodes; j++) {
      final f = (j + 0.8) / (nodes + 0.6);
      final open = _eo((t - reaches(f)) / 0.16);
      if (open <= 0) continue;
      final tan = along(f + 0.02) - along(f - 0.02);
      final a = atan2(tan.dy, tan.dx) + (j.isEven ? 0.95 : -0.95);
      leaves.addPath(
        vfxLeaf(along(f), (6.5 + 2 * _h(j, 81)) * S * open, a),
        Offset.zero,
      );
    }
    _fill(c, leaves, Color.lerp(pal.m.mid, pal.light, 0.55)!, 0.85 * env);
    _grainsOf(
      _n(10, 6),
      t,
      (i, tt) {
        final f = (i % nodes + 0.8) / (nodes + 0.6);
        final u = (tt - reaches(f) - 0.1 - 0.2 * _h(i, 0)) / 0.6;
        if (u <= 0 || u >= 1) return 0;
        final p = along(f);
        _px =
            p.dx +
            sin(tt * 5 + _h(i, 1) * 6) * 4 * S +
            (_h(i, 2) - 0.5) * 8 * S;
        _py = p.dy - (3 + 22 * u) * S;
        return sin(pi * u);
      },
      r: 0.95,
      hot: pal.hot,
      lag: 0.03,
    );
  }

  /// POISON — the Miasma. A low cloud gathers in a pool of sick light while
  /// blisters swell and rise, each bursting in its own time into grains that
  /// drip. (It was two expanding rings.)
  void _poison(ui.Canvas c, double t) {
    final S = s;
    final env = _win(t, 0, 0.12, 0.4, 1.1);
    _spill(c, o, 30, pal.light, 0.38 * env);
    _fill(
      c,
      vfxBlob(
        o + Offset(0, 4 * S),
        (10 + 10 * _eo(t / 0.5)) * S,
        seed,
        n: 10,
        wobble: 0.25,
        squash: 0.6,
      ),
      pal.m.mid,
      0.24 * env,
    );
    final n = _n(6, 4);
    double bornAt(int i) => 0.03 + 0.12 * _h(i, 0);
    double popAt(int i) => 0.38 + 0.4 * _h(i, 3);
    Offset blister(int i, double tt) {
      final rise = _eo((tt - bornAt(i)) / 0.8);
      return o +
          Offset(
            (_h(i, 1) - 0.5) * 20 * S + sin(tt * 6 + i) * 2 * S,
            -(2 + 26 * rise * (0.6 + 0.6 * _h(i, 2))) * S,
          );
    }

    final skins = ui.Path(), shines = ui.Path();
    for (var i = 0; i < n; i++) {
      final t0 = bornAt(i), pop = popAt(i);
      if (t < t0 || t >= pop) continue;
      final cc = blister(i, t);
      final rr =
          (1.5 + 3.5 * _eo((t - t0) / 0.3)) *
          S *
          (0.8 + 0.4 * _h(i, 4)) *
          (1 + 0.18 * _ss((t - pop + 0.08) / 0.08));
      skins.addOval(Rect.fromCircle(center: cc, radius: rr));
      shines.addOval(
        Rect.fromCircle(
          center: cc + Offset(-rr * 0.35, -rr * 0.38),
          radius: rr * 0.32,
        ),
      );
    }
    _fill(c, skins, pal.light, 0.5);
    _fill(c, shines, pal.m.glint, 0.5);
    final venom = _mix(pal.lit, _rgbOf(elementColor('Poison')), 0.35);
    _grainsOf(n * 5, t, (i, tt) {
      final b = i ~/ 5, k = i % 5;
      final pop = popAt(b);
      final u = (tt - pop) / 0.42;
      if (u <= 0 || u >= 1) return 0;
      final cc = blister(b, pop);
      final a = pi * 2 * (k + _h(i, 5) * 0.6) / 5;
      final rr = (2 + 9 * _eo(u)) * S;
      _px = cc.dx + cos(a) * rr;
      _py = cc.dy + sin(a) * rr * 0.8 + 12 * S * u * u;
      if (k.isOdd) _pc = _mix(pal.body, venom, (1 - u) * (1 - u));
      return 1 - u;
    }, r: 0.95);
  }

  /// SPIRIT — the Turning. Pale wisps phase in at the caster and rise,
  /// waving, narrowing to a tail, veil grains rising in waving columns, and
  /// one wisp drifts off to the target. (It was a ring of dots and a hoop.)
  void _spirit(ui.Canvas c, double t) {
    final S = s;
    _spill(c, o, 26, pal.light, 0.35 * _win(t, 0, 0.1, 0.35, 0.95));
    final env = _win(t, 0, 0.12, 0.45, 0.95);
    if (env > 0.01) {
      final bodies = ui.Path(), heads = ui.Path();
      for (var j = 0; j < (echo ? 2 : 4); j++) {
        final u = _c01((t - 0.04 * j) / 0.9);
        final e = _eo(u);
        final sway = sin(t * 4.5 + j * 1.7);
        final p =
            o +
            Offset(
              (_h(j, 90) - 0.5) * 2 * (6 + 14 * e) * S + sway * 4 * S * e,
              -(2 + 32 * e * (0.7 + 0.5 * _h(j, 91))) * S,
            );
        final r = (3.2 + 1.2 * _h(j, 92)) * S * (1 - 0.35 * u);
        final a = -pi / 2 + sway * 0.25;
        bodies.addPath(vfxDrop(p, r, a), Offset.zero);
        heads.addPath(
          vfxDrop(p + vfxPolar(a, r * 0.25), r * 0.55, a),
          Offset.zero,
        );
      }
      _fill(c, bodies, pal.m.mid, 0.55 * env);
      _fill(c, heads, pal.light, 0.6 * env);
    }
    final at = target;
    final go = _win(t, 0.08, 0.14, 0.36, 0.48);
    if (at != null && tier >= 2 && go > 0.01 && (at - o).distance > 16) {
      final d = at - o;
      final nrm = Offset(-d.dy, d.dx) / d.distance;
      final e = _ss((t - 0.08) / 0.34);
      final p =
          o +
          d * e +
          nrm * (sin(e * pi) * (d.distance * 0.12 + sin(e * pi * 3) * 4 * S));
      final a = atan2(d.dy, d.dx) + cos(e * pi * 3) * 0.3;
      final r = 3.0 * S;
      _fill(c, vfxDrop(p, r, a), pal.m.mid, 0.55 * go);
      _fill(
        c,
        vfxDrop(p + vfxPolar(a, r * 0.25), r * 0.55, a),
        pal.light,
        0.6 * go,
      );
    }
    _grainsOf(
      _n(14, 8),
      t,
      (i, tt) {
        final u = (tt - 0.05 * _h(i, 0)) / (0.8 + 0.2 * _h(i, 1));
        if (u <= 0 || u >= 1) return 0;
        final y = 30 * _eo(u) * S * (0.5 + _h(i, 2));
        _px =
            o.dx +
            (_h(i, 3) - 0.5) * 18 * S +
            sin(y * 0.12 - tt * 4 + _h(i, 4) * 3) * 5 * S;
        _py = o.dy - y;
        return sin(pi * u) * 0.75;
      },
      r: 1.1,
      lag: 0.03,
    );
  }

  /// DARK — the Maw. Dark pools round the caster under a halo of its bent
  /// light; accretion arms wind in to a black core with lit crescents round
  /// it, and grains spiral into the point, the inside turning faster. (It
  /// was a ring collapsing on a purple disc.)
  void _dark(ui.Canvas c, double t) {
    final S = s;
    final env = _win(t, 0, 0.1, 0.4, 0.85);
    _spill(c, o, 32, pal.light, 0.28 * env);
    _spill(c, o, 22, const Color(0xFF000000), 0.7 * env);
    final arms = ui.Path();
    final ar = 28 * S * (1 - 0.35 * _ss(t / 0.6));
    for (var j = 0; j < (echo ? 1 : 2); j++) {
      arms.addPath(
        vfxSpiralArm(o, ar, j * pi + _h(j, 95) + t * 3.2, 2.3, 4.2 * S),
        Offset.zero,
      );
    }
    _fill(c, arms, Color.lerp(pal.m.mid, pal.light, 0.35)!, 0.5 * env);
    final r = 7 * S * _eo(t / 0.18) * (1 - _ss((t - 0.42) / 0.33));
    if (r > 0.3) {
      _fill(c, vfxBlob(o, r, seed, n: 10, wobble: 0.06), pal.m.ink, 0.92);
      final spin = -0.6 + t * 2.0;
      _fill(
        c,
        vfxCrescent(o, r * 1.45, r * 0.5, spin, 2.5),
        pal.light,
        0.62 * env,
      );
      _fill(
        c,
        vfxCrescent(o, r * 1.3, r * 0.3, spin + pi, 1.6),
        pal.light,
        0.3 * env,
      );
    }
    _grainsOf(
      _n(20, 11),
      t,
      (i, tt) {
        final k0 = _c01((tt - 0.012 * i) / 0.6);
        final k = k0 * k0;
        final d = 0.45 + 0.55 * _h(i, 0);
        final rr = d * 34 * S * (1 - 0.92 * k);
        final a = pi * 2 * _h(i, 1) + k * (1.6 + 2.2 * (1 - d)) + tt * 2.0 * k;
        _px = o.dx + cos(a) * rr;
        _py = o.dy + sin(a) * rr * 0.85;
        return _ss((tt - 0.012 * i + 0.06) / 0.1) * (1 - _ss((k - 0.7) / 0.3));
      },
      r: 1.05,
      hot: pal.hot,
    );
  }

  /// LIGHT — the Dawn. Warm light pools at the caster and a small gold sun
  /// lifts off it (never a white core), while motes rise through the light
  /// like dust in a morning beam, swaying, each flaring as it passes the sun
  /// and going out above it. (It was an even wheel of stroked beams round a
  /// halo ring, then grains gathered into radial rays.)
  void _light(ui.Canvas c, double t) {
    final S = s;
    _spill(c, o, 38, pal.light, 0.5 * _win(t, 0, 0.08, 0.3, 0.95));
    final sunEnv = _win(t, 0.02, 0.14, 0.4, 0.9);
    final sun = o + Offset(0, -16 * S * _eo(t / 0.6));
    _spill(c, sun, 14, pal.light, 0.45 * sunEnv);
    _fill(
      c,
      vfxBlob(sun, 3.2 * S, seed, n: 10, wobble: 0.08),
      Color.lerp(pal.m.mid, pal.light, 0.7)!,
      0.7 * sunEnv,
    );
    _grainsOf(
      _n(26, 14),
      t,
      (i, tt) {
        final k = tt - 0.01 - 0.22 * _h(i, 0);
        final life = 0.55 + 0.25 * _h(i, 1);
        if (k <= 0 || k >= life) return 0;
        final u = k / life;
        // Born in a low, wide pool round the caster; risen on a gentle
        // sway, faster as they warm.
        final x0 = (_h(i, 2) - 0.5) * 34 * S;
        final y0 = (2 + 9 * _h(i, 3)) * S;
        final rise = (20 + 26 * _h(i, 4)) * S * (u + 0.6 * u * u);
        _px =
            o.dx +
            x0 * (1 - 0.35 * u) +
            sin(u * 4 + _h(i, 5) * 6) * 3.5 * S;
        _py = o.dy + y0 - rise;
        final near = 1 - _c01(((Offset(_px, _py) - sun).distance) / (11 * S));
        if (near > 0.05 && sunEnv > 0.05) {
          _pc = _mix(_mix(pal.body, pal.lit, 0.8), pal.glint, 0.7 * near);
        }
        _pk = 0.8 + 0.4 * _h(i, 6);
        return _ss(u / 0.12) * pow(1 - u, 0.9).toDouble();
      },
      r: 1.05,
      hot: pal.hot,
      lag: 0.03,
    );
  }

  /// BLOOD — the Crimson Tithe. A heart beats at the caster, lub-dub, its
  /// light spreading on each beat; grains gather tight on each beat and
  /// loosen between as they drift out, and a few drops run down. Its carry
  /// runs from the target home (see [_paintStream]). (It was two rings.)
  void _blood(ui.Canvas c, double t) {
    final S = s;
    double beat(double x) => exp(-(x * x) / 0.0018);
    double beats(double tt) => beat(tt - 0.07) + 0.7 * beat(tt - 0.25);
    final b = beats(t);
    final env = _win(t, 0, 0.04, 0.5, 1.0);
    _spill(
      c,
      o,
      (18 + 12 * _eo(t / 0.4)) * (1 + 0.25 * b),
      pal.light,
      (0.25 + 0.35 * b) * env,
    );
    final heart = _win(t, 0, 0.04, 0.32, 0.55);
    if (heart > 0.01) {
      _fill(
        c,
        vfxBlob(o, (5 + 3 * b) * S, seed, n: 10, wobble: 0.12),
        pal.m.mid,
        0.6 * heart,
      );
      _fill(
        c,
        vfxBlob(
          o + Offset(-0.8 * S, -S),
          (2.6 + 1.8 * b) * S,
          seed + 3,
          n: 9,
          wobble: 0.12,
        ),
        pal.light,
        0.5 * heart,
      );
    }
    _grainsOf(
      _n(18, 10),
      t,
      (i, tt) {
        if (tt <= 0) return 0;
        final bb = beats(tt);
        final a = pi * 2 * _h(i, 0) + 0.12 * tt;
        final rr =
            (6 + 14 * _h(i, 1)) *
            S *
            (1 + 0.9 * _eo(tt / 0.8)) *
            (1 - 0.3 * bb);
        _px = o.dx + cos(a) * rr;
        _py = o.dy + sin(a) * rr;
        return _ss(tt / 0.05) *
            (1 - _ss((tt - 0.5 - 0.2 * _h(i, 2)) / 0.35)) *
            (0.6 + 0.4 * min(1.0, bb));
      },
      r: 1.1,
      hot: pal.hot,
      trail: 1,
    );
    final drops = ui.Path();
    for (var j = 0; j < (echo ? 2 : 4); j++) {
      final k = t - 0.3 - 0.1 * j;
      if (k <= 0) continue;
      final p = o + Offset((_h(j, 110) - 0.5) * 16 * S, 4 * S + 80 * S * k * k);
      drops.addPath(vfxDrop(p, 1.7 * S, pi / 2), Offset.zero);
    }
    _fill(
      c,
      drops,
      Color.lerp(pal.m.mid, pal.light, 0.5)!,
      0.8 * _win(t, 0.3, 0.36, 0.7, 1.0),
    );
  }

  /// Any other element: its light and a soft burst of its grains.
  void _default(ui.Canvas c, double t) {
    _spill(c, o, 26, pal.light, 0.4 * _win(t, 0, 0.06, 0.25, 0.7));
    _grainsOf(_n(12, 7), t, (i, tt) {
      final u = (tt - 0.02 * _h(i, 0)) / (0.5 + 0.2 * _h(i, 1));
      if (u <= 0 || u >= 1) return 0;
      final a = pi * 2 * _h(i, 2);
      final rr = (3 + 26 * _eo(u)) * s;
      _px = o.dx + cos(a) * rr;
      _py = o.dy + sin(a) * rr - 6 * s * u * u;
      return 1 - u;
    });
  }
}
