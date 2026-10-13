// lib/screens/stadium/course_map.dart
//
// A course as the stadium's screen shows it before a race: the track's
// shape from start to line in a dotted line of grains — over each hill,
// down into a pond, broken over a gap — and one small mark where each
// stretch asks something: drops for rain, a cloud and its bolt for a storm,
// posts for turns, a lit edge on a long sprint, water in the pond, glints
// on ice, clots of mud, a fusion station's element turning, the stands for
// the crowd. Under each mark, plainly, what it is. Read at a glance: what
// this course will ask, and where.

import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:alchemons/games/stadium/race_layout.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/games/stadium/race_scenes.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const Color _ink = Color(0xFFE6E2DA);
const Color _brass = Color(0xFFCDB07A);
const Color _brassHot = Color(0xFFE2C98F);
const Color _dust = Color(0xFFA89C88);

class CourseMapPainter extends CustomPainter {
  CourseMapPainter({
    required this.course,
    required this.clock,
    required this.textStyle,
  }) : layout = RaceLayout(course),
       super(repaint: clock);

  final RaceCourse course;
  final RaceLayout layout;
  final ValueListenable<double> clock;
  final TextStyle textStyle;

  static final GrainBatch _batch = GrainBatch(16);

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final w = size.width;
    final ground = size.height * 0.56;
    final sx = (w - 12) / layout.finishX;
    // The tallest hill stands about this high on the map, per world px.
    const rise = 0.22;
    double xOf(double trackX) => 6 + trackX * sx;
    double yOf(double trackX) =>
        ground -
        layout.groundAt(trackX) * rise +
        layout.pondBedAt(trackX) * 0.25;
    final b = _batch..clear();

    // The track's line, following its shape, broken over gaps.
    for (var x = 0.0; x <= layout.finishX; x += 4 / sx) {
      if (!layout.solidAt(x)) continue;
      final at = layout.legAtX(x);
      final kind = at == null ? null : course.legs[at.$1].kind;
      final px = xOf(x), py = yOf(x);
      final h = hash01(px.round(), 30);
      final bucket = switch (kind) {
        RaceLegKind.pond => 4,
        RaceLegKind.ice => h < 0.3 ? 12 : 11,
        RaceLegKind.mud => 13,
        _ => 6,
      };
      b.add(bucket, px, py);
      if (kind != RaceLegKind.pond) {
        b.add(0, px + (h - 0.5) * 2, py + 4 + h * 2);
      }
    }
    // Start and finish.
    for (var y = 0.0; y < 26; y += 3) {
      b.add(2, xOf(0), ground - y);
      b.add(3, xOf(layout.finishX), ground - y);
    }

    final labels = <(double, String, Color)>[];
    for (var j = 0; j < course.legs.length; j++) {
      final leg = course.legs[j];
      final x0 = layout.starts[j], x1 = x0 + layout.widths[j];
      final midX = (x0 + x1) / 2;
      final mid = xOf(midX);
      final base = yOf(midX);
      switch (leg.kind) {
        case RaceLegKind.sprint:
          // One small mark at the middle of the stretch: a clear sprint has
          // none.
          switch (leg.level) {
            case 2:
              // A few drops falling.
              for (var i = 0; i < 7; i++) {
                final fall = (t * 0.9 + i / 7) % 1.0;
                b.add(
                  4,
                  mid + (hash01(i, 33) - 0.5) * 14,
                  base - 26 + fall * 20,
                );
              }
            case 3:
              // A cloud and its bolt, which flashes now and then.
              for (var i = 0; i < 9; i++) {
                b.add(5, mid - 8 + i * 2.0, base - 27 + (i.isEven ? 0 : -1.5));
              }
              final flash = ((t / 2.1 + j) % 1.0) < 0.1;
              const bolt = [
                Offset(1, -24),
                Offset(-2.5, -16),
                Offset(1.5, -15),
                Offset(-2, -7),
              ];
              for (var k = 0; k < bolt.length - 1; k++) {
                for (var u = 0.0; u < 1; u += 0.25) {
                  final p = Offset.lerp(bolt[k], bolt[k + 1], u)!;
                  b.add(flash ? 9 : 10, mid + p.dx, base + p.dy);
                }
              }
            case 4:
              // The lane bending: a short zigzag of posts.
              for (var k = 0; k <= 8; k++) {
                final u = k / 8;
                b.add(6, mid - 10 + u * 20, base - 6 - (k.isEven ? 0 : 6));
              }
            case 5:
              // The long stretch lit along its edge.
              for (var x = x0; x < x1; x += 5 / sx) {
                final glow = 0.5 + 0.5 * sin(t * 4 - x * 0.1);
                b.add(glow > 0.6 ? 3 : 6, xOf(x), yOf(x) + 5);
              }
          }
        case RaceLegKind.hill:
          // The hill is its own mark: a few stones on its top.
          for (var i = 0; i < 10; i++) {
            final u = 0.35 + hash01(i, 40 + j) * 0.35;
            final x = x0 + u * (x1 - x0);
            b.add(7, xOf(x), yOf(x) - 2 - hash01(i, 41 + j) * 3);
          }
          if (leg.level == 2) {
            // Hot: embers off it.
            for (var i = 0; i < 6; i++) {
              final life = (t * 0.5 + hash01(i, 42 + j)) % 1.0;
              b.add(
                14,
                mid + (hash01(i, 43) - 0.5) * 12,
                yOf(midX - 30) - 8 - life * 14,
              );
            }
          }
        case RaceLegKind.pond:
          // Water filling the dip, light moving on it.
          for (var x = x0; x < x1; x += 2.5 / sx) {
            for (var y = ground; y < yOf(x) + 0.5; y += 2.2) {
              final glint = sin(t * 2 + x * 0.04 + y);
              b.add(glint > 0.7 ? 9 : 4, xOf(x), y);
            }
          }
        case RaceLegKind.gap:
          // The dark going down, its edges.
          final a = xOf(x0 + kRaceGapLip * (x1 - x0));
          final z = xOf(x1 - kRaceGapLip * (x1 - x0));
          for (var y = ground; y < ground + 14; y += 2.4) {
            b.add(8, a, y);
            b.add(8, z, y);
          }
        case RaceLegKind.ice:
          // Glints along the stretch.
          for (var i = 0; i < 6; i++) {
            final x = x0 + (i + 0.5) / 6 * (x1 - x0);
            if (sin(t * 2.6 + i * 1.7) > 0.4) b.add(12, xOf(x), yOf(x) - 3);
          }
        case RaceLegKind.mud:
          for (var i = 0; i < 12; i++) {
            final x = x0 + hash01(i, 44 + j) * (x1 - x0);
            b.add(13, xOf(x), yOf(x) - 1 - hash01(i, 45) * 3);
          }
        case RaceLegKind.fuse:
          final col = elementColor(leg.element!);
          final at = Offset(mid, base - 14);
          final pool = Rect.fromCenter(
            center: Offset(mid, base),
            width: 30,
            height: 8,
          );
          canvas.drawOval(
            pool,
            Paint()
              ..shader = RadialGradient(
                colors: [col.withValues(alpha: 0.4), col.withValues(alpha: 0)],
              ).createShader(pool),
          );
          final fb = Paint()..color = col.withValues(alpha: 0.85);
          for (var i = 0; i < 26; i++) {
            final h1 = hash01(i, 40 + j), h2 = hash01(i, 41 + j);
            final a = h1 * pi * 2 + t * (0.6 + h2) * (i.isEven ? 1 : -1);
            final r = 2 + h2 * 6;
            canvas.drawCircle(
              at + Offset(cos(a) * r, sin(a) * r * 0.8),
              h2 < 0.3 ? 1.2 : 0.9,
              fb,
            );
          }
        case RaceLegKind.crowd:
          // The stands behind the stretch: a few rows of grains.
          for (var x = x0; x < x1; x += 3.2 / sx) {
            for (var r = 0; r < 3; r++) {
              final h1 = hash01((x * sx).round() * 3 + r, 46);
              if (h1 > 0.6) continue;
              b.add(15, xOf(x) + (h1 - 0.3) * 2, base - 14 - r * 3.2);
            }
          }
      }
      final label = leg.mapLabel;
      if (label.isNotEmpty) labels.add((mid, label, raceLegTint(leg)));
    }
    b.draw(canvas, 0, 1.0, _dust.withValues(alpha: 0.25));
    b.draw(canvas, 2, 1.4, _ink.withValues(alpha: 0.5));
    b.draw(canvas, 3, 1.6, _brassHot.withValues(alpha: 0.85));
    b.draw(canvas, 4, 1.4, const Color(0xFF5BC8E8).withValues(alpha: 0.6));
    b.draw(canvas, 5, 1.1, const Color(0xFF9C8FB0).withValues(alpha: 0.5));
    b.draw(canvas, 6, 1.5, _brass.withValues(alpha: 0.6));
    b.draw(canvas, 7, 1.8, const Color(0xFFB8AE9C).withValues(alpha: 0.85));
    b.draw(canvas, 8, 1.6, const Color(0xFF6E6A80).withValues(alpha: 0.8));
    b.draw(canvas, 9, 1.4, const Color(0xFFEFF2FF).withValues(alpha: 0.95));
    b.draw(canvas, 10, 1.1, const Color(0xFFEFF2FF).withValues(alpha: 0.4));
    b.draw(canvas, 11, 1.4, const Color(0xFFCFEFF8).withValues(alpha: 0.55));
    b.draw(canvas, 12, 1.9, const Color(0xFFF2FCFF).withValues(alpha: 0.95));
    b.draw(canvas, 13, 1.8, const Color(0xFF9A7650).withValues(alpha: 0.85));
    b.draw(canvas, 14, 1.4, const Color(0xFFF5A060).withValues(alpha: 0.8));
    b.draw(canvas, 15, 1.3, _brass.withValues(alpha: 0.45));

    // What each mark is, staggered onto a second row when two would touch.
    var rowEnd = [-1e9, -1e9];
    for (final (x, text, color) in labels) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: textStyle.copyWith(
            color: color.withValues(alpha: 0.9),
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final left = (x - tp.width / 2).clamp(0.0, w - tp.width);
      final row = left > rowEnd[0] + 6 ? 0 : 1;
      if (row == 1 && left <= rowEnd[1] + 6) continue;
      rowEnd[row] = left + tp.width;
      tp.paint(canvas, Offset(left, ground + 9 + row * 12));
    }
  }

  @override
  bool shouldRepaint(CourseMapPainter old) => old.course != course;
}
