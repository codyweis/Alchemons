// lib/games/stadium/stadium_space_art.dart
//
// The Trials as they hang in space (the author, 2026-10-12: "the trials in
// cosmic space look need to be optimized and bigger"): an arena on a rock
// adrift — a bowl of stands in four terraces with stairs cut down them,
// its people a head over a dimmer body, lit in pools by four floodlights on
// the rim; a dark floor with six racers lapping it, each with a streak of
// its light; and under it all the rock it is built on, its strata lit down
// one flank. The stands brighten and stir as the ship comes alongside.
//
// Every grain's place is worked out once; a frame only turns them into
// points (about 3,500, in a dozen draws, no blurs), and nothing is drawn
// off screen (the caller culls).

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';

const Color _brass = Color(0xFFCDB07A);
const Color _brassHot = Color(0xFFE2C98F);

/// The arena's half width and half depth on the floor's plane, in world px.
const double kStadiumRx = 330, kStadiumRy = 150;

/// How far below its centre the arena's name is written.
const double kStadiumLabelDrop = kStadiumRy * 2.75;

final GrainBatch _batch = GrainBatch(16);

/// The stands' people: angle round the bowl (its cos and sin), how far up
/// the terraces (1 at the track, 1.45 at the rim), and a hash each.
final _Stands _stands = _Stands();

class _Stands {
  _Stands() {
    final cs = <double>[], sn = <double>[], u = <double>[], h = <double>[];
    const tiers = 4, rows = 3;
    for (var tier = 0; tier < tiers; tier++) {
      for (var row = 0; row < rows; row++) {
        final uu =
            1.06 + (tier * (rows + 0.9) + row) / (tiers * (rows + 0.9)) * 0.42;
        final n = (300 * uu).round();
        for (var i = 0; i < n; i++) {
          final a = (i + hash01(i, tier * 7 + row + 340) * 0.7) / n * 2 * pi;
          // Stairs down every terrace at the same eighteen places.
          final stair = (a / (2 * pi) * 18) % 1;
          if (stair < 0.08) continue;
          final seats = 0.5 + 0.5 * sin(a * 9 + tier) * cos(a * 4 - row);
          final hh = hash01(i, tier * 7 + row + 341);
          if (hh > 0.5 + seats * 0.5) continue;
          cs.add(cos(a));
          sn.add(sin(a));
          u.add(uu + (hash01(i, 342) - 0.5) * 0.012);
          h.add(hh);
        }
      }
    }
    this.cs = Float32List.fromList(cs);
    this.sn = Float32List.fromList(sn);
    this.u = Float32List.fromList(u);
    this.h = Float32List.fromList(h);
    // How lit each sits: near a floodlight, and on the near side.
    light = Float32List(cs.length);
    for (var i = 0; i < cs.length; i++) {
      final a = atan2(sn[i], cs[i]);
      var l = 0.0;
      for (final lamp in _lamps) {
        var d = (a - lamp).abs();
        if (d > pi) d = 2 * pi - d;
        l = max(l, exp(-d * d / 0.18));
      }
      light[i] = l;
    }
    // The rock under it: grains in strata, lit down the left.
    final rx = <double>[], ry = <double>[], rl = <double>[];
    for (var row = 0; row < 26; row++) {
      final d = row / 26;
      final per = (70 * (1 - d * 0.7)).round();
      for (var i = 0; i < per; i++) {
        final x = -1 + 2 * hash01(row * 97 + i, 350);
        final down = _underside(x);
        if (d > down) continue;
        if (hash01(row * 97 + i, 351) > 1.15 - d / max(down, 0.05)) continue;
        rx.add(x);
        ry.add(d + (hash01(row * 97 + i, 352) - 0.5) * 0.03);
        rl.add(x < -0.4 ? 2 : (x < 0.2 ? 1 : 0));
      }
    }
    rockX = Float32List.fromList(rx);
    rockY = Float32List.fromList(ry);
    rockLit = Float32List.fromList(rl);
    // Dust lying on the floor.
    final fx = <double>[], fy = <double>[];
    for (var i = 0; i < 260; i++) {
      final a = hash01(i, 360) * 2 * pi;
      final r = 0.2 + 0.75 * sqrt(hash01(i, 361));
      fx.add(cos(a) * r);
      fy.add(sin(a) * r);
    }
    floorX = Float32List.fromList(fx);
    floorY = Float32List.fromList(fy);
  }

  late final Float32List cs, sn, u, h, light;
  late final Float32List rockX, rockY, rockLit;
  late final Float32List floorX, floorY;

  /// The floodlights' places round the rim (angles).
  static const List<double> _lamps = [-2.35, -0.8, 0.8, 2.35];

  /// How far below the rim the rock reaches at x (−1..1 across), as a
  /// share of its depth: a main point and two lesser ones.
  static double _underside(double x) {
    final main = exp(-pow((x - 0.08) / 0.42, 2));
    final left = exp(-pow((x + 0.55) / 0.24, 2)) * 0.55;
    final right = exp(-pow((x - 0.62) / 0.2, 2)) * 0.42;
    final base = sqrt(max(0.0, 1 - x * x)) * 0.25;
    return max(base, max(main, max(left, right)));
  }
}

/// Paints the arena centred on [at] at time [t]; [near] (0..1) lights it
/// as the ship arrives. While it is the [beacon] the story sends the player
/// to find, it throbs with light and a column of grains rises off it.
void paintStadium(
  Canvas c, {
  required Offset at,
  required double t,
  double near = 0,
  bool beacon = false,
}) {
  const rx = kStadiumRx, ry = kStadiumRy;
  if (beacon) {
    final pulse = 0.5 + 0.5 * sin(t * 3.2);
    final r = rx * 2.4;
    c.drawCircle(
      at,
      r,
      Paint()
        ..shader = ui.Gradient.radial(at, r, [
          _brassHot.withValues(alpha: 0.1 + 0.16 * pulse),
          _brassHot.withValues(alpha: 0),
        ]),
    );
    final col = _batch..clear();
    for (var i = 0; i < 160; i++) {
      final life = (t * 0.32 + hash01(i, 330)) % 1.0;
      final x = at.dx + (hash01(i, 331) - 0.5) * 50 + sin(life * 6 + i) * 8;
      col.add(life < 0.5 ? 0 : 1, x, at.dy - ry * 0.4 - life * 900);
    }
    col.draw(c, 0, 3.0, _brassHot.withValues(alpha: 0.55 + 0.35 * pulse));
    col.draw(c, 1, 2.2, _brassHot.withValues(alpha: 0.25 + 0.2 * pulse));
  }

  // The arena itself: still unless the ship is alongside (the crowd stirs
  // then), so while it is still it is recorded once and replayed.
  if (near > 0.2) {
    _paintArena(c, at, t, near);
  } else {
    final key = (near * 10).round();
    final picture = _still[key] ??= () {
      final rec = ui.PictureRecorder();
      _paintArena(Canvas(rec), Offset.zero, 0, key / 10);
      return rec.endRecording();
    }();
    c.save();
    c.translate(at.dx, at.dy);
    c.drawPicture(picture);
    c.restore();
  }
  _paintRacers(c, at, t);
}

/// The still arena, by how near the ship is (in tenths, up to 0.2).
final Map<int, ui.Picture> _still = {};

/// Everything but the racers: the light round it, the rock, the bowl and
/// floor, the stands and the floodlights.
void _paintArena(Canvas c, Offset at, double t, double near) {
  const rx = kStadiumRx, ry = kStadiumRy;
  const rim = 1.5;
  final s = _stands;
  // The light it sits in.
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(1, ry / rx);
  c.drawCircle(
    Offset.zero,
    rx * 2.1,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        rx * 2.1,
        [
          _brass.withValues(alpha: 0.09 + 0.07 * near),
          _brass.withValues(alpha: 0.03 + 0.02 * near),
          _brass.withValues(alpha: 0),
        ],
        const [0.0, 0.5, 1.0],
      ),
  );
  c.restore();

  // The rock it is built on, hanging under the near half of the rim.
  final depth = ry * 1.6;
  final rimLift = (rim - 1) * ry * 0.5;
  double rimY(double x) =>
      at.dy + sqrt(max(0.0, 1 - x * x)) * ry * rim - rimLift;
  final rock = Path()..moveTo(at.dx - rx * rim, at.dy - rimLift);
  for (var q = 0; q <= 40; q++) {
    final x = -1 + 2 * q / 40;
    rock.lineTo(
      at.dx + x * rx * rim,
      rimY(x) + _Stands._underside(x) * depth * (0.95 + 0.08 * sin(x * 23)),
    );
  }
  rock.lineTo(at.dx + rx * rim, at.dy - rimLift);
  c.drawPath(rock, Paint()..color = const Color(0xFF0C0B0A));

  // The bowl: its outer wall and the stands' ground, dark; the floor
  // darker, with a little light pooled under each lamp.
  c.drawOval(
    Rect.fromCenter(
      center: at.translate(0, -rimLift * 0.5),
      width: rx * rim * 2,
      height: ry * rim * 2,
    ),
    Paint()..color = const Color(0xFF121115),
  );
  // The floor: the infield darkest, the track round it a little lighter,
  // one soft gradient — no lines.
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(1, ry / rx);
  c.drawCircle(
    Offset.zero,
    rx,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        rx,
        const [
          Color(0xFF070709),
          Color(0xFF08080A),
          Color(0xFF15141A),
          Color(0xFF15141A),
          Color(0xFF0B0B0E),
        ],
        const [0.0, 0.5, 0.64, 0.9, 1.0],
      ),
  );
  c.restore();
  for (final lamp in _Stands._lamps) {
    final p = at + Offset(cos(lamp) * rx * 0.62, sin(lamp) * ry * 0.62);
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(1, ry / rx);
    final r = rx * 0.42;
    c.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, r, [
          _brassHot.withValues(alpha: 0.05 + 0.05 * near),
          _brassHot.withValues(alpha: 0),
        ]),
    );
    c.restore();
  }

  final b = _batch..clear();
  // Buckets: 0..2 rock strata, 3 floor dust, 4..6 people by light (far
  // side dimmer), 7..9 their bodies, 10 lamps, 11..13 racers' heads.
  for (var i = 0; i < s.rockX.length; i++) {
    final x = s.rockX[i];
    b.add(
      s.rockLit[i].round(),
      at.dx + x * rx * rim * (1 - 0.05 * s.rockY[i]),
      rimY(x) + 6 + s.rockY[i] * depth,
    );
  }
  for (var i = 0; i < s.floorX.length; i++) {
    b.add(3, at.dx + s.floorX[i] * rx * 0.92, at.dy + s.floorY[i] * ry * 0.92);
  }
  final stir = near > 0.2;
  for (var i = 0; i < s.cs.length; i++) {
    final u = s.u[i];
    final back = s.sn[i] < 0;
    final hh = s.h[i];
    final bob = stir ? sin(t * (4 + hh * 3) + i).abs() * 1.6 * near : 0.0;
    final x = at.dx + s.cs[i] * rx * u;
    final y = at.dy + s.sn[i] * ry * u - (u - 1) * ry * 0.5 - bob;
    final lit = s.light[i] * (back ? 0.75 : 1) + 0.25 * near + hh * 0.2;
    final level = lit > 0.75 ? 2 : (lit > 0.4 ? 1 : 0);
    b.add(4 + level, x, y);
    b.add(7 + level, x, y + 2.6);
  }
  // The floodlights on the rim.
  for (final lamp in _Stands._lamps) {
    final p =
        at + Offset(cos(lamp) * rx * rim, sin(lamp) * ry * rim - rimLift - 10);
    for (var g = 0; g < 7; g++) {
      b.add(
        10,
        p.dx + (hash01(g, 370) - 0.5) * 8,
        p.dy + (hash01(g, 371) - 0.5) * 5,
      );
    }
  }
  b.draw(c, 0, 2.0, const Color(0xFF3E362C).withValues(alpha: 0.9));
  b.draw(c, 1, 2.0, const Color(0xFF6A5C48));
  b.draw(c, 2, 2.2, const Color(0xFF9C8664));
  b.draw(c, 3, 1.6, const Color(0xFF8E8676).withValues(alpha: 0.22));
  b.draw(c, 7, 3.0, const Color(0xFF4A4440).withValues(alpha: 0.5));
  b.draw(c, 8, 3.2, const Color(0xFF6A625A).withValues(alpha: 0.6));
  b.draw(c, 9, 3.4, const Color(0xFF8A7E70).withValues(alpha: 0.7));
  b.draw(c, 4, 2.0, const Color(0xFF9C8FB0).withValues(alpha: 0.45));
  b.draw(c, 5, 2.2, const Color(0xFFB8A27A).withValues(alpha: 0.75));
  b.draw(c, 6, 2.5, _brassHot.withValues(alpha: 0.95));
  b.draw(c, 10, 2.6, const Color(0xFFFBF1D4));
}

/// Six racers lapping the floor, each with a streak of its light behind.
void _paintRacers(Canvas c, Offset at, double t) {
  const rx = kStadiumRx, ry = kStadiumRy;
  final b = _batch..clear();
  const racers = [
    Color(0xFFF08A4B),
    Color(0xFF5BC8E8),
    Color(0xFF8BD17C),
    Color(0xFFE2C98F),
    Color(0xFFB9A8FF),
    Color(0xFFE8E4DA),
  ];
  for (var r = 0; r < 6; r++) {
    final speed = 0.42 + hash01(r, 310) * 0.12;
    final k = 0.6 + (r % 3) * 0.12;
    final a = t * speed + r * 0.9;
    final head = at + Offset(cos(a) * rx * k, sin(a) * ry * k);
    final tail = at + Offset(cos(a - 0.22) * rx * k, sin(a - 0.22) * ry * k);
    _streak(c, head, tail, 4.5, racers[r]);
    for (var g = 0; g < 3; g++) {
      b.add(
        11 + (r % 3),
        head.dx + (g - 1) * 1.6,
        head.dy + (g == 1 ? -1.4 : 0.6),
      );
    }
  }
  b.draw(c, 11, 2.8, Colors.white.withValues(alpha: 0.95));
  b.draw(c, 12, 2.8, const Color(0xFFFBF1D4).withValues(alpha: 0.95));
  b.draw(c, 13, 2.8, const Color(0xFFE6F8FF).withValues(alpha: 0.95));
}

/// A racer's streak: soft at its edges, gone at its tail.
void _streak(Canvas c, Offset head, Offset tail, double w, Color col) {
  final d = head - tail;
  final len = d.distance;
  if (len < 2) return;
  final n = Offset(-d.dy / len, d.dx / len);
  for (final (f, a) in [(1.0, 0.18), (0.45, 0.45)]) {
    final path = Path()
      ..moveTo(head.dx + n.dx * w * f, head.dy + n.dy * w * f)
      ..lineTo(tail.dx, tail.dy)
      ..lineTo(head.dx - n.dx * w * f, head.dy - n.dy * w * f)
      ..close();
    c.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(head, tail, [
          col.withValues(alpha: a),
          col.withValues(alpha: 0),
        ]),
    );
  }
}
