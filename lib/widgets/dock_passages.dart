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
  Duration get inward => const Duration(milliseconds: 900);

  @override
  Duration get outward => const Duration(milliseconds: 850);

  @override
  Duration get landing => const Duration(milliseconds: 950);

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
  Duration get inward => const Duration(milliseconds: 950);

  @override
  Duration get outward => const Duration(milliseconds: 950);

  @override
  Duration get landing => const Duration(milliseconds: 1250);

  @override
  Listenable? get listenable => target;

  /// The map comes up under its dust once most of it has come down.
  @override
  double pageShown(double land) => _smooth(0.45, 1, land);

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
    final o = s.grow;
    // The window the hills are seen through: the icon's box, then most of
    // the screen.
    final c = Offset.lerp(s.box.center, Offset(w / 2, h * 0.46), o)!;
    final r = _lerp(s.box.shortestSide / 2, math.min(w, h) * 0.44, o);
    // The icon itself hands over to its grains in the first moments.
    final iconAlpha = 1 - _smooth(0.0, 0.3, s.open);
    if (iconAlpha > 0) {
      DockEmblemPainter.paintField(
        canvas,
        Rect.fromCircle(center: c, radius: r),
        t,
        alpha: iconAlpha,
      );
    }
    final grains = _smooth(0.04, 0.32, s.open);
    if (grains <= 0) return;
    final circles = target.value ?? const <FieldCircle>[];
    final land = s.land;
    final scene = 1 - _smooth(0.62, 1, land);
    if (scene <= 0) return;

    // The dawn behind the hills, thinning as they come loose.
    final sun = c + Offset(r * 0.2, r * 0.02);
    final dawn = grains * (1 - _smooth(0.0, 0.5, land));
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

      if (circles.isNotEmpty && land > 0) {
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
        // curve rather than a line.
        final delay = _h(i, 7) * 0.3;
        final f = _ease((land * 1.35 - delay) / 0.8);
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
    if (land < 0.5) {
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
    final dot = _lerp(1.2, 1.7, o);
    Color fade(Color color, double k) =>
        color.withValues(alpha: (color.a * k * a).clamp(0.0, 1.0));
    for (var k = 0; k < 3; k++) {
      b.draw(canvas, _bodyB + k, dot, fade(_body[k], 0.9));
      b.draw(canvas, _crestB + k, dot * 1.1, fade(_crest[k], 1));
      b.draw(canvas, _litB + k, dot * 1.15, fade(_lit[k], 1));
    }
    final night = 1 - _smooth(0.0, 0.5, land);
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
  Duration get outward => const Duration(milliseconds: 850);

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
