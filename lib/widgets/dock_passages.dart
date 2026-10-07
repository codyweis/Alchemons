// lib/widgets/dock_passages.dart
//
// The dock's ways in (navigation/emblem_passage.dart): the scene the player
// touched lifts off home and carries them to its screen, ending as that
// screen's own first thing, in the same place, so the page takes over
// without a seam.
//
//   Harvest   the flask rises to the middle of the screen and swirls while
//             the chamber is got ready, then settles onto the chamber's own
//             flask on the bench — its liquid taking that chamber's colour
//             and level — and gives way to it
//   Field     the dawn hills grow into a window of grains; the grains come
//             loose and drift down into the map's realm circles as the dust
//             each realm opens as
//   Survival  the equipped orb grows onto the survival hub's orb
//   Enhance   the creature of grains stands up in the middle of the screen,
//             the infusion's light climbing it, then comes apart into a band
//             of light that opens — one edge rising, one falling — on the
//             page
//
// Going back plays each the other way. Points in batches, gradients for
// light; no blur, no stroked outlines.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/navigation/emblem_passage.dart';
import 'package:alchemons/widgets/dock_emblems.dart';
import 'package:alchemons/widgets/fx/extraction_vessel.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/home_emblems.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

double _smooth(double e0, double e1, double x) {
  final t = _clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
}

double _ease(double x) {
  final t = _clamp01(x);
  return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _h(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

/// The ink the dock's screens stand on.
const Color _kGround = Color(0xFF09090B);

void _paintGround(Canvas canvas, EmblemStage s, [Color ground = _kGround]) {
  if (s.ground <= 0) return;
  canvas.drawRect(
    Offset.zero & s.screen,
    Paint()..color = ground.withValues(alpha: s.ground),
  );
}

// ── Harvest ─────────────────────────────────────────────────────────────────

/// Where the harvest chamber's flask stands once its screen is laid out, and
/// what is in it: what the Harvest passage lands on.
@immutable
class HarvestFlaskTarget {
  const HarvestFlaskTarget({
    required this.centre,
    required this.radius,
    required this.ink,
    required this.level,
  });

  /// The bulb's centre and radius, in global coordinates.
  final Offset centre;
  final double radius;

  /// The liquid's colour, and how full it stands (0..1 of full).
  final Color ink;
  final double level;
}

class HarvestPassage extends PassageScene {
  HarvestPassage({required this.target});

  /// Set by the chamber once it is laid out.
  final ValueListenable<HarvestFlaskTarget?> target;

  @override
  Duration get inward => const Duration(milliseconds: 600);

  @override
  Duration get outward => const Duration(milliseconds: 650);

  @override
  Duration get landing => const Duration(milliseconds: 650);

  @override
  Listenable? get listenable => target;

  /// The chamber comes up round the flask once it is nearly on the bench.
  @override
  double pageShown(double land) => _smooth(0.3, 0.9, land);

  @override
  void paint(
    Canvas canvas,
    EmblemStage s, {
    required bool back,
    required bool front,
  }) {
    if (back) _paintGround(canvas, s);
    if (!front) return;
    final w = s.screen.width, h = s.screen.height;
    final icon = dockFlaskIn(s.box);
    final accent = DockEmblemKind.harvest.accent;
    final iconLevel = dockFlaskLevel(s.time);
    // The middle of the screen, where it waits while the chamber is got
    // ready: large, still swirling.
    final holdC = Offset(w / 2, h * 0.47);
    final holdR = math.min(w * 0.26, h * 0.17);
    final tgt = target.value;
    final grow = s.grow;

    Offset c;
    double r, level;
    Color ink;
    if (!s.closing) {
      c = Offset.lerp(icon.centre, holdC, grow)!;
      r = _lerp(icon.radius, holdR, grow);
      ink = accent;
      level = iconLevel;
      if (tgt != null) {
        // Settling onto the bench, taking on what that chamber holds.
        final settle = _ease(s.land / 0.45);
        c = Offset.lerp(c, tgt.centre, settle)!;
        r = _lerp(r, tgt.radius, settle);
        ink = Color.lerp(accent, tgt.ink, settle)!;
        level = _lerp(iconLevel, tgt.level, settle);
      }
    } else {
      // Going back it lifts straight off the bench and home.
      final homeC = tgt?.centre ?? holdC;
      final homeR = tgt?.radius ?? holdR;
      c = Offset.lerp(icon.centre, homeC, grow)!;
      r = _lerp(icon.radius, homeR, grow);
      ink = Color.lerp(accent, tgt?.ink ?? accent, grow)!;
      level = _lerp(iconLevel, tgt?.level ?? iconLevel, grow);
    }
    // In place, it gives way to the chamber's own flask.
    final alpha = 1 - _smooth(0.55, 1, s.land);
    paintFlaskEmblem(
      canvas,
      c,
      r,
      s.time,
      ink: ink,
      level: level,
      motes: 1 - 0.7 * grow,
      alpha: alpha,
    );
  }
}

// ── Field ───────────────────────────────────────────────────────────────────

/// One of the map's realm circles once its screen is laid out: where the
/// Field passage's grains come down as dust.
@immutable
class FieldCircle {
  const FieldCircle({
    required this.centre,
    required this.radius,
    required this.tint,
  });

  /// In global coordinates.
  final Offset centre;
  final double radius;

  /// The colour of the realm's dust.
  final Color tint;
}

/// Each realm's dust, by scene id, as the map opens on it.
const Map<String, Color> kRealmDust = {
  'valley': Color(0xFF86B472),
  'sky': Color(0xFFD6DFEC),
  'volcano': Color(0xFFD98A5E),
  'swamp': Color(0xFF93A36C),
  'arcane': Color(0xFFA68BDC),
  'dunes': Color(0xFFDDBE88),
  'geode': Color(0xFFAECBEA),
  'tidal': Color(0xFF7EC2D4),
};

class FieldPassage extends PassageScene {
  FieldPassage({required this.target});

  /// Set by the map once it is laid out.
  final ValueListenable<List<FieldCircle>?> target;

  @override
  Duration get inward => const Duration(milliseconds: 650);

  @override
  Duration get outward => const Duration(milliseconds: 800);

  @override
  Duration get landing => const Duration(milliseconds: 800);

  @override
  Listenable? get listenable => target;

  /// The map comes up under its dust once most of it has come down.
  @override
  double pageShown(double land) => _smooth(0.45, 1, land);

  /// Going back the map clears quickly; the dust has the rest.
  @override
  double get backSplit => 0.78;

  static const int _count = 2600;

  /// Buckets: hill body (3 far→near), crest (3, plus 3 lit toward the sun),
  /// stars, fireflies, then one per realm circle.
  static const int _bodyB = 0, _crestB = 3, _litB = 6, _starB = 9;
  static const int _flyB = 10, _dustB = 11;
  static final GrainBatch _b = GrainBatch(_dustB + 8);
  static final Paint _p = Paint();

  static const List<Color> _body = [
    Color(0xFF4F8A7C),
    Color(0xFF3A7064),
    Color(0xFF2A5C50),
  ];
  static const List<Color> _crest = [
    Color(0xFF7FC4A4),
    Color(0xFF5FA888),
    Color(0xFF3F7C64),
  ];
  static const List<Color> _lit = [
    Color(0xFFF2D9A0),
    Color(0xFFE9C68A),
    Color(0xFFD9AE76),
  ];

  /// Hill [k]'s crest at [u] (0..1 across), in the window's unit space
  /// (centre 0, radius 1) — the icon's own ridges.
  static double _ridge(int k, double u) =>
      (0.12 + 0.24 * k) -
      (0.16 - 0.03 * k) *
          (0.6 * math.sin(u * 5.1 + k * 1.7) +
              0.4 * math.sin(u * 11.3 + k * 0.6));

  @override
  void paint(
    Canvas canvas,
    EmblemStage s, {
    required bool back,
    required bool front,
  }) {
    if (back) _paintGround(canvas, s);
    if (!front) return;
    final w = s.screen.width, h = s.screen.height;
    final t = s.time;
    final land = s.land;
    final closing = s.closing;
    // Going back, [p] is 0..1 of the way home once the map has sunk away:
    // the dust drifts back up into the hills while they are still large
    // (to 0.8), and only then do the hills ease down into the icon (0.5 to
    // 1) — overlapping, unhurried, so nothing springs.
    // It starts as the map finishes clearing (land under 0.45), so the
    // dust is never left sitting still in the circles.
    final p = !closing
        ? 0.0
        : land > 0
        ? 0.1 * _clamp01((0.45 - land) / 0.45)
        : 0.1 + 0.9 * (1 - s.open);
    // The window the hills are seen through: the icon's box, then most of
    // the screen.
    final win = closing ? 1 - _smooth(0.5, 1.0, p) : s.grow;
    final c = Offset.lerp(s.box.center, Offset(w / 2, h * 0.46), win)!;
    final r = _lerp(s.box.shortestSide / 2, math.min(w, h) * 0.44, win);
    // The icon itself hands over to its grains in the first moments (and
    // takes them back at the last).
    final iconAlpha = closing
        ? _smooth(0.8, 1.0, p)
        : 1 - _smooth(0.0, 0.3, s.open);
    if (iconAlpha > 0) {
      DockEmblemPainter.paintField(
        canvas,
        Rect.fromCircle(center: c, radius: r),
        t,
        alpha: iconAlpha,
      );
    }
    final grains = closing
        ? 1 - _smooth(0.86, 1.0, p)
        : _smooth(0.04, 0.32, s.open);
    if (grains <= 0) return;
    final circles = target.value ?? const <FieldCircle>[];
    final scene = 1 - _smooth(0.62, 1, land);
    if (scene <= 0) return;
    // How much of the hills' night is showing: their dawn, stars and
    // fireflies go as the dust comes down, and come back as it returns.
    final night = closing ? _smooth(0.3, 0.8, p) : 1 - _smooth(0.0, 0.5, land);

    // The dawn behind the hills.
    final sun = c + Offset(r * 0.2, r * 0.02);
    final dawn = grains * night;
    if (dawn > 0) {
      canvas.drawCircle(
        sun,
        r,
        _p
          ..shader = ui.Gradient.radial(
            sun,
            r,
            [
              const Color(0xFFFFE6B0).withValues(alpha: 0.9 * dawn),
              const Color(0xFFF0A46E).withValues(alpha: 0.5 * dawn),
              const Color(0xFF407F80).withValues(alpha: 0.18 * dawn),
              const Color(0x00000000),
            ],
            const [0.0, 0.16, 0.5, 1.0],
          ),
      );
      _p.shader = null;
    }

    // Each circle's share of the dust, by its area.
    var area = 0.0;
    for (final k in circles) {
      area += k.radius * k.radius;
    }

    final b = _b..clear();
    for (var i = 0; i < _count; i++) {
      // Its place in the hills.
      final k = i % 3;
      final u = _h(i, 1);
      final ridge = _ridge(k, u);
      final v = math.pow(_h(i, 2), 1.8).toDouble();
      final ux = -1 + 2 * u;
      final uy = ridge + v * (1.0 - ridge);
      // The window's soft edge: thinned toward its rim, as the icon fades.
      final d2 = ux * ux + uy * uy;
      if (d2 > math.pow(0.72 + 0.28 * _h(i, 3), 2)) continue;
      var x = c.dx + ux * r;
      var y = c.dy + uy * r;
      final crest = v < 0.04;
      final toSun = 1 - ((x - sun.dx).abs() / (r * 1.4)).clamp(0.0, 1.0);
      var bucket = crest
          ? (toSun > 0.55 ? _litB + k : _crestB + k)
          : _bodyB + k;

      if (circles.isNotEmpty && (land > 0 || closing)) {
        // Its circle, and a place in it.
        var pick = _h(i, 4) * area;
        var j = 0;
        while (j < circles.length - 1) {
          final a = circles[j].radius * circles[j].radius;
          if (pick < a) break;
          pick -= a;
          j++;
        }
        final to = circles[j];
        final ang = _h(i, 5) * math.pi * 2;
        final rr = math.sqrt(_h(i, 6)) * to.radius * 0.9;
        final end = to.centre + Offset(math.cos(ang) * rr, math.sin(ang) * rr);
        // Loosening a little after its neighbours, drifting down in a lazy
        // curve rather than a line; going back, drifting up again the same
        // way, gently.
        final delay = _h(i, 7) * 0.3;
        final f = !closing
            ? _ease((land * 1.35 - delay) / 0.8)
            : 1 - _smooth(0, 1, (p - delay) / 0.5);
        if (f > 0) {
          final from = Offset(x, y);
          final dir = end - from;
          final side = Offset(-dir.dy, dir.dx) * ((_h(i, 8) - 0.5) * 0.35);
          final p = Offset.lerp(from, end, f)! + side * math.sin(math.pi * f);
          x = p.dx;
          y = p.dy;
          if (f > 0.5) bucket = _dustB + j;
        }
      }
      b.add(bucket, x, y);
    }
    // Stars still out over the hills, and fireflies.
    if (night > 0) {
      for (var i = 0; i < 10; i++) {
        if ((t * 0.5 + _h(i, 35) * 4) % 1.0 > 0.8) continue;
        b.add(
          _starB,
          c.dx + (-0.75 + _h(i, 33) * 1.5) * r,
          c.dy + (-0.85 + _h(i, 34) * 0.5) * r,
        );
      }
      for (var i = 0; i < 8; i++) {
        final ph = (t * (0.06 + 0.03 * _h(i, 30)) + _h(i, 31)) % 1.0;
        b.add(
          _flyB,
          c.dx + (-0.7 + _h(i, 32) * 1.4 + math.sin(t + i) * 0.05) * r,
          c.dy + (0.45 - ph * 0.5) * r,
        );
      }
    }
    final a = grains * scene;
    final dot = _lerp(1.2, 1.7, win);
    Color fade(Color color, double k) =>
        color.withValues(alpha: (color.a * k * a).clamp(0.0, 1.0));
    for (var k = 0; k < 3; k++) {
      b.draw(canvas, _bodyB + k, dot, fade(_body[k], 0.9));
      b.draw(canvas, _crestB + k, dot * 1.1, fade(_crest[k], 1));
      b.draw(canvas, _litB + k, dot * 1.15, fade(_lit[k], 1));
    }
    b.draw(canvas, _starB, dot * 0.8, fade(const Color(0xCCE8F4FF), night));
    b.draw(canvas, _flyB, dot * 1.3, fade(const Color(0xFFFFF0B0), night));
    for (var j = 0; j < circles.length && j < 8; j++) {
      // As the map's own dust: faint.
      b.draw(canvas, _dustB + j, dot, fade(circles[j].tint, 0.7));
    }
  }
}

// ── Survival ────────────────────────────────────────────────────────────────

class SurvivalPassage extends PassageScene {
  SurvivalPassage({required this.skin, required this.target});

  /// The orb the player has equipped.
  final OrbBaseSkin skin;

  /// Where the survival hub's orb core stands on a screen of the given size
  /// and safe area (its centre and radius).
  final ({Offset centre, double radius}) Function(Size screen, EdgeInsets pad)
  target;

  @override
  Duration get inward => const Duration(milliseconds: 950);

  @override
  Duration get outward => const Duration(milliseconds: 1000);

  @override
  Duration get landing => const Duration(milliseconds: 800);

  @override
  void paint(
    Canvas canvas,
    EmblemStage s, {
    required bool back,
    required bool front,
  }) {
    // The hub's own deeper black.
    if (back) _paintGround(canvas, s, const Color(0xFF050507));
    if (!front) return;
    final icon = dockOrbIn(s.box);
    final hub = target(s.screen, s.pad);
    final grow = s.grow;
    final c = Offset.lerp(icon.centre, hub.centre, grow)!;
    final r = _lerp(icon.radius, hub.radius, grow);
    // In place, it gives way to the hub's own orb (drawn on its own clock),
    // through a layer only as large as the orb's light.
    final alpha = 1 - _smooth(0.45, 1, s.land);
    if (alpha <= 0.004) return;
    final fading = alpha < 0.999;
    if (fading) {
      canvas.saveLayer(
        Rect.fromCircle(center: c, radius: r * 1.8),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
      );
    }
    paintDockOrb(canvas, c, r, skin, s.time, light: 1 - 0.6 * grow);
    if (fading) canvas.restore();
  }
}

// ── Enhance ─────────────────────────────────────────────────────────────────

/// The Enhance creature — the dock's Light Horn of grains — lifts off and
/// stands in the middle of the screen, the infusion's light still climbing
/// it, while Enhance is got ready. Then it comes apart from the crown down:
/// its grains pour sideways into a band of light across the screen, and the
/// band opens, one edge rising and one falling, with the page between them,
/// until both have passed off the screen and thinned to nothing.
class EnhancePassage extends PassageScene {
  EnhancePassage({required this.creature});

  /// The creature read finely enough to stand over the screen
  /// (`DockEmblem.creatureGrains(fine: true)`); only its floor light shows
  /// until it is.
  final ValueListenable<SpecimenGrains?> creature;

  @override
  Duration get inward => const Duration(milliseconds: 650);

  @override
  Duration get outward => const Duration(milliseconds: 800);

  @override
  Duration get landing => const Duration(milliseconds: 850);

  @override
  Listenable? get listenable => creature;

  /// Going back the edges close in the first half; the creature gathers and
  /// goes home in the rest.
  @override
  double get backSplit => 0.5;

  @override
  double pageShown(double land) => _smooth(0.1, 0.45, land);

  @override
  Rect? pageWindow(EmblemStage s) {
    final e = _edges(s);
    return Rect.fromLTRB(0, e.top, s.screen.width, e.bottom);
  }

  /// Where it stands while Enhance is got ready.
  static ({Offset c, double r}) _hold(Size screen) => (
    c: Offset(screen.width / 2, screen.height * 0.45),
    r: math.min(screen.width * 0.34, screen.height * 0.2),
  );

  /// How far the band has opened at [land]: it gathers first.
  static double _opening(double land) => _ease((land - 0.24) / 0.76);

  /// Fully open, the edges stand this far past the screen, so nothing of
  /// them is left to see.
  static const double _past = 90;

  /// The two edges: from the creature's own middle out past the screen.
  static ({double top, double bottom}) _edges(EmblemStage s) {
    final hold = _hold(s.screen);
    final seam = hold.c.dy + hold.r * 0.08;
    final o = _opening(s.land);
    return (
      top: seam - o * (seam + _past),
      bottom: seam + o * (s.screen.height - seam + _past),
    );
  }

  /// Buckets: 0–7 the creature's own tones, 8–11 the wave of light, 12–14
  /// on an edge (right at it → thrown off it).
  static final GrainBatch _b = GrainBatch(15);
  static final Paint _p = Paint();

  // Each grain's part, read once per creature.
  SpecimenGrains? _seeded;
  late EnhanceFit _fit;
  late Float32List _keep, _along, _off, _delay, _out, _bend, _lift;
  late Uint8List _rises;

  void _seed(SpecimenGrains g) {
    if (identical(g, _seeded)) return;
    _seeded = g;
    final fit = _fit = EnhanceFit(g);
    final n = g.length;
    _keep = Float32List(n);
    _along = Float32List(n);
    _off = Float32List(n);
    _delay = Float32List(n);
    _out = Float32List(n);
    _bend = Float32List(n);
    _lift = Float32List(n);
    _rises = Uint8List(n);
    for (var i = 0; i < n; i++) {
      final rise = fit.rise(i);
      _keep[i] = _h(i, 50);
      // The upper body rides the rising edge, the lower the falling one.
      _rises[i] = rise > 0.5 + (_h(i, 51) - 0.5) * 0.4 ? 1 : 0;
      // Its place along the edge: a little of where it stood across the
      // body, mostly anywhere, so the edges fill evenly.
      final across = g.hx[i] / (2 * fit.reach) + 0.5;
      _along[i] = _lerp(across, _h(i, 52), 0.72) * 1.12 - 0.06;
      // Mostly right on its edge; a few thrown out ahead of it.
      _off[i] = math.pow(_h(i, 53), 2.2) * 30 - 5;
      // The crown loosens first, as the infusion lifts off it.
      _delay[i] = 0.02 + 0.16 * (1 - rise) + 0.06 * _h(i, 54);
      // How far open the band is when it goes out.
      _out[i] = 0.5 + 0.45 * _h(i, 55);
      _bend[i] = (_h(i, 56) - 0.5) * 0.45;
      // As the icon: one in seven is thrown high by the wave.
      _lift[i] = _h(i, 40) > 0.85 ? 0.16 : 0.04;
    }
  }

  @override
  void paint(
    Canvas canvas,
    EmblemStage s, {
    required bool back,
    required bool front,
  }) {
    if (back) _paintGround(canvas, s);
    if (!front) return;
    final w = s.screen.width;
    final t = s.time;
    final land = s.land;
    final hold = _hold(s.screen);
    final grow = s.grow;
    // From the icon's own fit in its box (half its side round its centre)
    // to the middle of the screen.
    final c = Offset.lerp(s.box.center, hold.c, grow)!;
    final r = _lerp(s.box.shortestSide / 2, hold.r, grow);
    final o = _opening(land);
    final edges = _edges(s);
    final accent = DockEmblemKind.enhance.accent;

    // Its light at its feet goes as it comes loose.
    paintEnhanceFloor(canvas, c, r, alpha: 1 - _smooth(0.0, 0.3, land));
    if (land > 0) _paintEdges(canvas, s, edges, o, accent);

    final g = creature.value;
    if (g == null || g.length == 0) return;
    _seed(g);
    final fit = _fit;
    final n = g.length;
    // As many grains as the icon has at its size, filling in as it grows,
    // so it is the same creature the moment it lifts off.
    final dens = _lerp(math.min(1.0, 520 / n), 1, grow);
    final scale = fit.scale(r);
    final body = fit.centre(c, r);
    final b = _b..clear();
    for (var i = 0; i < n; i++) {
      if (_keep[i] > dens) continue;
      final pulse = fit.pulse(i, t);
      var x = body.dx + g.hx[i] * scale;
      var y =
          body.dy +
          (g.hy[i] - fit.midY) * scale -
          pulse * r * (0.04 + _lift[i]);
      final f = land <= 0 ? 0.0 : _ease((land - _delay[i]) / 0.42);
      if (f <= 0) {
        b.add(
          pulse > 0.3
              ? 8 + math.min(3, (pulse * 4).floor())
              : math.min(7, g.tone[i]),
          x,
          y,
        );
        continue;
      }
      if (o > _out[i]) continue;
      // Out to its edge in a lazy curve, riding it once there.
      final rises = _rises[i] == 1;
      final ex = _along[i] * w;
      final sway = math.sin(ex * 0.019 + t * 1.2 + (rises ? 0 : 2.1)) * 5 * f;
      final ey = (rises ? edges.top - _off[i] : edges.bottom + _off[i]) + sway;
      final dx = ex - x, dy = ey - y;
      final bend = math.sin(math.pi * f) * _bend[i];
      x += dx * f - dy * bend;
      y += dy * f + dx * bend;
      // Its own shade as it lifts away, lighting up on the way out to its
      // edge rather than all at once.
      b.add(
        f < 0.12
            ? math.min(7, g.tone[i])
            : f < 0.5
            ? 8 + math.min(3, ((f - 0.12) * 10).floor())
            : (_off[i] < 4 ? 12 : (_off[i] < 14 ? 13 : 14)),
        x,
        y,
      );
    }
    final d = math.max(1.1, g.step * scale * 1.15 / math.sqrt(dens));
    for (var k = 0; k < math.min(8, g.tones.length); k++) {
      b.draw(canvas, k, d, enhanceInk(g.tones[k]));
    }
    for (var k = 0; k < 4; k++) {
      b.draw(
        canvas,
        8 + k,
        d * 1.05,
        Color.lerp(accent, Colors.white, 0.15 * k)!,
      );
    }
    // The edges' grains thin to nothing as they pass off the screen.
    final gone = 1 - _smooth(0.78, 1.0, o);
    if (gone > 0) {
      final e = math.min(d, 1.8);
      b.draw(
        canvas,
        12,
        e * 1.1,
        Color.lerp(accent, Colors.white, 0.4)!.withValues(alpha: gone),
      );
      b.draw(canvas, 13, e, accent.withValues(alpha: 0.85 * gone));
      b.draw(
        canvas,
        14,
        e * 0.9,
        const Color(0xFF7A5CC0).withValues(alpha: 0.6 * gone),
      );
    }
  }

  /// Under the edges' grains: their light, and the dark the page eases out
  /// of just inside each, so it never meets the ground at a hard line.
  void _paintEdges(
    Canvas canvas,
    EmblemStage s,
    ({double top, double bottom}) edges,
    double o,
    Color accent,
  ) {
    final w = s.screen.width;
    const feather = 46.0;
    // The band's light swells as the creature pours into it and thins as
    // it opens; brightest in the middle, off to one side, so it reads as
    // light and not as a bar.
    final glow = _smooth(0.1, 0.4, s.land) * (1 - _smooth(0.5, 1.0, o));
    for (final rising in const [true, false]) {
      final y = rising ? edges.top : edges.bottom;
      if (o > 0) {
        final inner = rising ? y + feather : y - feather;
        _p.shader = ui.Gradient.linear(Offset(0, y), Offset(0, inner), [
          _kGround,
          _kGround.withValues(alpha: 0),
        ]);
        canvas.drawRect(
          Rect.fromLTRB(0, math.min(y, inner), w, math.max(y, inner)),
          _p,
        );
      }
      if (glow > 0) {
        final cx = w * (rising ? 0.56 : 0.46);
        canvas.save();
        canvas.translate(cx, y);
        canvas.scale(1, 0.06);
        _p.shader = ui.Gradient.radial(
          Offset.zero,
          w * 0.62,
          [
            accent.withValues(alpha: 0.34 * glow),
            accent.withValues(alpha: 0.12 * glow),
            accent.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        );
        canvas.drawCircle(Offset.zero, w * 0.62, _p);
        canvas.restore();
      }
    }
    _p.shader = null;
  }
}
