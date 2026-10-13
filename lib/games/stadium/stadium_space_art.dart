// lib/games/stadium/stadium_space_art.dart
//
// The stadium as it hangs in space: an oval bowl of stands in warm grains,
// a dark track inside it, and six lit grains running laps with short trails.
// The stands brighten as the ship comes alongside. About 700 points, no
// blurs; drawn only when on screen.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';

const Color _brass = Color(0xFFCDB07A);
const Color _brassHot = Color(0xFFE2C98F);

final GrainBatch _batch = GrainBatch(10);

/// Paints the stadium centred on [at] at time [t]; [near] (0..1) lights it
/// as the ship arrives. While it is the [beacon] the story sends the player
/// to find, it throbs with light and a column of grains rises off it.
void paintStadium(
  Canvas c, {
  required Offset at,
  required double t,
  double near = 0,
  bool beacon = false,
}) {
  const rx = 150.0, ry = 74.0;
  if (beacon) {
    final pulse = 0.5 + 0.5 * sin(t * 3.2);
    c.drawCircle(
      at,
      rx * 2.6,
      Paint()
        ..shader = ui.Gradient.radial(at, rx * 2.6, [
          _brassHot.withValues(alpha: 0.12 + 0.18 * pulse),
          _brassHot.withValues(alpha: 0),
        ]),
    );
    final col = _batch..clear();
    for (var i = 0; i < 120; i++) {
      final life = (t * 0.35 + hash01(i, 330)) % 1.0;
      final x = at.dx + (hash01(i, 331) - 0.5) * 26 + sin(life * 6 + i) * 5;
      col.add(life < 0.5 ? 0 : 1, x, at.dy - life * 520);
    }
    col.draw(c, 0, 2.4, _brassHot.withValues(alpha: 0.55 + 0.35 * pulse));
    col.draw(c, 1, 1.8, _brassHot.withValues(alpha: 0.25 + 0.2 * pulse));
  }
  // The light it sits in.
  c.drawOval(
    Rect.fromCenter(center: at, width: rx * 3, height: ry * 3),
    Paint()
      ..shader = ui.Gradient.radial(at, rx * 1.5, [
        _brass.withValues(alpha: 0.10 + 0.08 * near),
        _brass.withValues(alpha: 0),
      ]),
  );
  // The bowl's dark floor.
  c.drawOval(
    Rect.fromCenter(center: at, width: rx * 1.5, height: ry * 1.5),
    Paint()..color = const Color(0xFF0B0B0E).withValues(alpha: 0.92),
  );
  final b = _batch..clear();
  // Stands: grains scattered through a band round the bowl, in clusters,
  // rising toward the rim — not rows, which would read as orbits. The far
  // side sits higher and dimmer.
  for (var i = 0; i < 760; i++) {
    final h1 = hash01(i, 300), h2 = hash01(i, 301), h3 = hash01(i, 302);
    final a = h1 * pi * 2;
    final seats = 0.5 + 0.5 * sin(a * 7 + 1.3) * cos(a * 3 - 0.4);
    if (h3 > 0.45 + seats * 0.55) continue;
    final u = 1.0 + h2 * 0.36;
    final back = sin(a) < 0;
    final x = at.dx + cos(a) * rx * u + (h3 - 0.5) * 4;
    final y = at.dy + sin(a) * ry * u - (u - 1) * 30 - (back ? 6 : 0);
    final cheer = 0.5 + 0.5 * sin(t * 3 + i * 0.7);
    final lit = (back ? 0 : 2) + (cheer * near > 0.4 ? 1 : 0);
    b.add(lit, x, y);
  }
  // Six racers lapping the floor, each a lit grain with a trail.
  const tones = [7, 7, 8, 8, 9, 9];
  for (var r = 0; r < 6; r++) {
    final speed = 0.5 + hash01(r, 310) * 0.14;
    final k = 0.52 + (r % 3) * 0.1;
    for (var j = 0; j < 9; j++) {
      final a = t * speed + r * 0.55 - j * 0.03;
      b.add(
        j == 0 ? 5 : (j < 4 ? tones[r] : 6),
        at.dx + cos(a) * rx * k,
        at.dy + sin(a) * ry * k,
      );
    }
  }
  b.draw(c, 0, 1.5, const Color(0xFF8E8676).withValues(alpha: 0.32));
  b.draw(c, 1, 1.7, _brass.withValues(alpha: 0.5));
  b.draw(c, 2, 1.7, const Color(0xFFB8A27A).withValues(alpha: 0.55));
  b.draw(c, 3, 2.0, _brassHot.withValues(alpha: 0.85));
  b.draw(c, 6, 1.3, _brassHot.withValues(alpha: 0.18));
  b.draw(c, 7, 1.9, const Color(0xFFF08A4B).withValues(alpha: 0.55));
  b.draw(c, 8, 1.9, const Color(0xFF5BC8E8).withValues(alpha: 0.55));
  b.draw(c, 9, 1.9, const Color(0xFF8BD17C).withValues(alpha: 0.55));
  b.draw(c, 5, 2.8, _brassHot.withValues(alpha: 0.95));
}
