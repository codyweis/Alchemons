import 'dart:async';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flutter/material.dart';

class CosmicMiniMapCircle extends StatefulWidget {
  const CosmicMiniMapCircle({
    super.key,
    required this.world,
    required this.game,
    required this.onTap,
    required this.onLongPress,
  });

  final CosmicWorld world;
  final CosmicGame game;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<CosmicMiniMapCircle> createState() => _CosmicMiniMapCircleState();
}

class _CosmicMiniMapCircleState extends State<CosmicMiniMapCircle> {
  static const _refreshInterval = Duration(milliseconds: 90);

  late final ValueNotifier<int> _repaintTick;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _repaintTick = ValueNotifier<int>(0);
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      _repaintTick.value++;
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _repaintTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: SizedBox(
        width: 84,
        height: 84,
        child: Center(
          child: RepaintBoundary(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.7),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: CustomPaint(
                  isComplex: true,
                  painter: _MiniCirclePainter(
                    world: widget.world,
                    game: widget.game,
                    repaint: _repaintTick,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniCirclePainter extends CustomPainter {
  _MiniCirclePainter({required this.world, required this.game, super.repaint});

  final CosmicWorld world;
  final CosmicGame game;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xDD060820),
    );

    final shipPos = game.ship.pos;
    final center = Offset(size.width / 2, size.height / 2);
    const visibleRadiusWorld = 2600.0;
    final mapScale = (size.shortestSide * 0.46) / visibleRadiusWorld;

    final ww = world.worldSize.width;
    final wh = world.worldSize.height;
    Offset toMini(Offset worldPos) {
      var dx = worldPos.dx - shipPos.dx;
      var dy = worldPos.dy - shipPos.dy;
      if (dx > ww / 2) dx -= ww;
      if (dx < -ww / 2) dx += ww;
      if (dy > wh / 2) dy -= wh;
      if (dy < -wh / 2) dy += wh;
      return Offset(center.dx + dx * mapScale, center.dy + dy * mapScale);
    }

    final viewR = size.shortestSide / 2;

    for (final planet in world.planets) {
      if (!planet.discovered) continue;
      final p = toMini(planet.position);
      if ((p - center).distance > viewR + 8) continue;
      canvas.drawCircle(
        p,
        (planet.radius * mapScale).clamp(1.3, 3.2),
        Paint()..color = planet.color.withValues(alpha: 0.95),
      );
    }

    if (game.homePlanet != null) {
      final hp = toMini(game.homePlanet!.position);
      if ((hp - center).distance <= viewR + 8) {
        canvas.drawCircle(hp, 3.8, Paint()..color = const Color(0xFF00E5FF));
        canvas.drawCircle(
          hp,
          5.4,
          Paint()
            ..color = const Color(0xFF00E5FF).withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }

    for (final poi in game.spacePOIs) {
      final isScanner =
          poi.type == POIType.stardustScanner ||
          poi.type == POIType.planetScanner;
      if (poi.type == POIType.comet) continue;
      final isMarket =
          poi.type == POIType.harvesterMarket ||
          poi.type == POIType.riftKeyMarket ||
          poi.type == POIType.cosmicMarket ||
          poi.type == POIType.goldConversion;
      final p = toMini(poi.position);
      final isSurvivalPortal = poi.type == POIType.survivalPortal;
      final scannerNearby = isScanner && (p - center).distance <= viewR * 0.9;
      if (!poi.discovered && !isMarket && !scannerNearby && !isSurvivalPortal) continue;
      if ((p - center).distance > viewR + 8) continue;

      Color c;
      switch (poi.type) {
        case POIType.nebula:
          c = elementColor(poi.element).withValues(alpha: 0.75);
          break;
        case POIType.derelict:
          c = const Color(0xFF90A4AE);
          break;
        case POIType.comet:
          c = elementColor(poi.element).withValues(alpha: 0.8);
          break;
        case POIType.warpAnomaly:
          c = const Color(0xFFB388FF);
          break;
        case POIType.harvesterMarket:
          c = const Color(0xFFFFB300);
          break;
        case POIType.riftKeyMarket:
          c = const Color(0xFF7C4DFF);
          break;
        case POIType.cosmicMarket:
          c = const Color(0xFF00E5FF);
          break;
        case POIType.goldConversion:
          c = const Color(0xFFFFD740);
          break;
        case POIType.stardustScanner:
          c = const Color(0xFF9CCC65);
          break;
        case POIType.planetScanner:
          c = const Color(0xFF64B5F6);
          break;
        case POIType.survivalPortal:
          c = const Color(0xFF8B5CF6);
          break;
      }
      final r = isScanner ? 3.0 : (isMarket ? 2.6 : 2.1);
      canvas.drawCircle(p, r, Paint()..color = c);
      if (isScanner) {
        canvas.drawCircle(
          p,
          5.4,
          Paint()
            ..color = c.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }

    for (final arena in world.contestArenas) {
      if (!arena.discovered) continue;
      final p = toMini(arena.position);
      if ((p - center).distance > viewR + 8) continue;
      final c = arena.trait.color;
      canvas.drawCircle(p, 2.6, Paint()..color = c.withValues(alpha: 0.9));
      canvas.drawCircle(
        p,
        4.7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = c.withValues(alpha: 0.38),
      );
    }

    // Active scanner lock: radar beeper points to the tracked star dust.
    final targetDust = game.starDustScannerTarget;
    if (targetDust != null) {
      final tp = toMini(targetDust.position);
      final dv = tp - center;
      final dist = dv.distance;
      final pulse =
          0.55 + 0.45 * sin(DateTime.now().millisecondsSinceEpoch / 170.0);
      const targetColor = Color(0xFFFFE082);

      if (dist <= viewR - 6) {
        canvas.drawCircle(
          tp,
          2.8 + pulse * 1.4,
          Paint()..color = targetColor.withValues(alpha: 0.85),
        );
        canvas.drawCircle(
          tp,
          5.5 + pulse * 1.8,
          Paint()
            ..color = targetColor.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      } else if (dist > 0.001) {
        final dir = Offset(dv.dx / dist, dv.dy / dist);
        final edge = center + dir * (viewR - 5);
        final perp = Offset(-dir.dy, dir.dx);

        final tip = edge;
        final back = edge - dir * 8;
        final tri = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(back.dx + perp.dx * 3.6, back.dy + perp.dy * 3.6)
          ..lineTo(back.dx - perp.dx * 3.6, back.dy - perp.dy * 3.6)
          ..close();
        canvas.drawPath(
          tri,
          Paint()..color = targetColor.withValues(alpha: 0.9),
        );
        canvas.drawCircle(
          edge,
          3.8 + pulse * 1.9,
          Paint()
            ..color = targetColor.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }

    final targetPlanet = game.planetScannerTarget;
    if (targetPlanet != null) {
      final tp = toMini(targetPlanet.position);
      final dv = tp - center;
      final dist = dv.distance;
      final pulse =
          0.55 + 0.45 * sin(DateTime.now().millisecondsSinceEpoch / 210.0);
      const targetColor = Color(0xFF90CAF9);

      if (dist <= viewR - 6) {
        canvas.drawCircle(
          tp,
          3.0 + pulse * 1.6,
          Paint()..color = targetColor.withValues(alpha: 0.88),
        );
        canvas.drawCircle(
          tp,
          6.4 + pulse * 2.1,
          Paint()
            ..color = targetColor.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1,
        );
      } else if (dist > 0.001) {
        final dir = Offset(dv.dx / dist, dv.dy / dist);
        final edge = center + dir * (viewR - 5);
        final perp = Offset(-dir.dy, dir.dx);

        final tip = edge;
        final back = edge - dir * 8;
        final tri = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(back.dx + perp.dx * 3.6, back.dy + perp.dy * 3.6)
          ..lineTo(back.dx - perp.dx * 3.6, back.dy - perp.dy * 3.6)
          ..close();
        canvas.drawPath(
          tri,
          Paint()..color = targetColor.withValues(alpha: 0.92),
        );
        canvas.drawCircle(
          edge,
          4.0 + pulse * 2.1,
          Paint()
            ..color = targetColor.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }

    for (final whirl in game.galaxyWhirls) {
      if (whirl.state == WhirlState.completed) continue;
      final p = toMini(whirl.position);
      if ((p - center).distance > viewR + 8) continue;
      canvas.drawCircle(
        p,
        2.3,
        Paint()..color = elementColor(whirl.element).withValues(alpha: 0.8),
      );
    }

    BossLair? nearestLair;
    double nearestLairDist = double.infinity;
    for (final lair in game.bossLairs) {
      if (lair.state != BossLairState.waiting) continue;
      final d = (lair.position - game.ship.pos).distance;
      if (d < nearestLairDist) {
        nearestLairDist = d;
        nearestLair = lair;
      }
    }
    if (nearestLair != null) {
      final p = toMini(nearestLair.position);
      if ((p - center).distance <= viewR + 8) {
        canvas.drawCircle(
          p,
          2.8,
          Paint()..color = const Color(0xFFFF5252).withValues(alpha: 0.9),
        );
      }
    }

    if (game.prismaticField.discovered && !game.prismaticField.rewardClaimed) {
      final p = toMini(game.prismaticField.position);
      if ((p - center).distance <= viewR + 8) {
        canvas.drawCircle(
          p,
          2.8,
          Paint()..color = const Color(0xFFFF00CC).withValues(alpha: 0.8),
        );
      }
    }

    if (world.elementalNexus.discovered) {
      final p = toMini(world.elementalNexus.position);
      if ((p - center).distance <= viewR + 8) {
        canvas.drawCircle(
          p,
          2.8,
          Paint()..color = const Color(0xFFB388FF).withValues(alpha: 0.8),
        );
      }
    }

    if (world.battleRing.discovered) {
      final p = toMini(world.battleRing.position);
      if ((p - center).distance <= viewR + 8) {
        canvas.drawCircle(
          p,
          2.8,
          Paint()..color = const Color(0xFFFFD740).withValues(alpha: 0.9),
        );
      }
    }

    // Radar rings around player center.
    for (final ring in [0.33, 0.66, 1.0]) {
      canvas.drawCircle(
        center,
        viewR * ring,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    final ship = center;
    canvas.drawCircle(ship, 3.0, Paint()..color = Colors.white);
    canvas.drawCircle(
      ship,
      5.5,
      Paint()
        ..color = const Color(0xFFFFF176).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniCirclePainter oldDelegate) =>
      world != oldDelegate.world || game != oldDelegate.game;
}
