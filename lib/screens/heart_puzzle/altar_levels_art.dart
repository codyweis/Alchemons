// lib/screens/heart_puzzle/altar_levels_art.dart
//
// ALCHEMY's level select, in the stage's own language (the author,
// 2026-10-08: "is our stage selector outdated"): each chapter stands on a
// still of the realm it is played in, and each level is a circle — the
// stage's sand ring — with the level's goal over it.
//
//   · LOCKED: a faint ring, nothing on it.
//   · OPEN: the ring, and empty glass over it: the goal not yet made.
//   · NEXT: the one to play, its ring lit and turning, its goal breathing
//     faintly in the glass — the only thing on the page that moves.
//   · SOLVED: the goal made, its element's orb over a ring warmed to it.
//
// Under each, its number and its stars as three grain sparkles. Everything
// but the next level is drawn once, still.

import 'dart:math' as math;

import 'package:alchemons/games/planet_dungeon/blood_rite_fx.dart';
import 'package:alchemons/screens/heart_puzzle/altar_stage_art.dart';
import 'package:alchemons/widgets/fx/element_orb.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum AltarCell { locked, open, next, solved }

/// One level's circle, in a cell [kAltarCellHeight] tall.
class AltarCellPainter extends CustomPainter {
  AltarCellPainter({
    required this.cell,
    required this.stars,
    required this.orb,
    required this.salt,
    this.ghost,
    this.clock,
  }) : super(repaint: clock);

  final AltarCell cell;
  final int stars;

  /// What hangs over the ring: the goal's orb once solved, empty glass
  /// before; none while locked.
  final ElementOrb? orb;
  final int salt;

  /// The goal, breathing faintly inside the next level's glass.
  final ElementOrb? ghost;

  /// Only the next level turns; the rest are one still frame.
  final ValueListenable<double>? clock;

  static final RiteGrainBatch _batch = RiteGrainBatch();

  static const double orbY = 24, ringY = 43, starsY = 78;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // A still frame of its own, so no two rings lie alike.
    final time = clock?.value ?? salt * 1.37;
    final ring = Offset(cx, ringY);
    final locked = cell == AltarCell.locked;
    final next = cell == AltarCell.next;
    final solved = cell == AltarCell.solved;
    final o = orb;

    // Shade under it, so it reads over a bright realm; and light on the
    // ground under the next one, or the made goal's colour.
    paintFloorShade(canvas, ring + const Offset(0, -6), 30, 20, locked ? .3 : .5);
    if (next) {
      paintFloorPool(
        canvas,
        ring,
        28,
        9,
        kAltarBrass,
        .2 + .06 * math.sin(time * 1.4),
      );
    } else if (solved && o != null) {
      paintFloorPool(canvas, ring, 24, 8, o.color, .14);
    }
    paintSeatRing(
      _batch,
      ring,
      time,
      glow: next ? .9 : (solved ? .3 : 0),
      fade: locked ? .32 : 1,
      tint: solved ? o?.color : null,
      salt: salt,
      rx: 18,
      ry: 6,
      grains: 40,
    );
    _batch.paint(canvas);

    if (o != null) {
      final bob = next ? math.sin(time * 1.2) * 1.2 : 0.0;
      final at = Offset(cx, orbY + bob);
      o.paint(canvas, at, time);
      ghost?.paint(canvas, at, time, fade: .34 + .12 * math.sin(time * 1.3));
    }

    if (!locked) {
      for (var i = 0; i < 3; i++) {
        paintGrainStar(
          _batch,
          Offset(cx + (i - 1) * 12, starsY),
          4.1,
          lit: i < stars ? 1 : 0,
        );
      }
      _batch.paint(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant AltarCellPainter old) =>
      old.cell != cell ||
      old.stars != stars ||
      old.orb != orb ||
      old.ghost != ghost ||
      old.salt != salt ||
      old.clock != clock;
}

/// How tall a level's cell stands.
const double kAltarCellHeight = 92;

/// A chapter's realm behind it: the still, darkened under the circles and
/// gone to black at both edges, so each chapter's realm comes up out of the
/// dark and goes back into it. Faded up once decoded.
class AltarRealmStill extends StatelessWidget {
  const AltarRealmStill({super.key, required this.asset, this.dim = .5});
  final String asset;

  /// 0 as it is, 1 black.
  final double dim;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: const Alignment(0, .35),
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, sync) => sync
                ? child
                : AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOut,
                    child: child,
                  ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  Colors.black.withValues(alpha: dim + (1 - dim) * .35),
                  Colors.black.withValues(alpha: dim),
                  Colors.black.withValues(alpha: dim + (1 - dim) * .3),
                  Colors.black,
                ],
                stops: const [0, .22, .5, .82, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
