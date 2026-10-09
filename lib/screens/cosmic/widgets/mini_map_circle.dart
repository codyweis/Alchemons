import 'package:alchemons/audio/audio.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/contest_art.dart'
    show kContestChampionGold;
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:alchemons/games/cosmic/station_art.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

import 'star_chart_art.dart';

class CosmicMiniMapCircle extends StatefulWidget {
  const CosmicMiniMapCircle({
    super.key,
    required this.world,
    required this.game,
    required this.onTap,
    required this.onLongPress,
    this.tutorialTargetPos,
  });

  final CosmicWorld world;
  final CosmicGame game;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Offset? tutorialTargetPos;

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
      onTap: context.soundAction(widget.onTap),
      onLongPress: widget.onLongPress,
      child: SizedBox(
        width: 84,
        height: 84,
        child: Center(
          child: RepaintBoundary(
            // A dark lens in the HUD's bracket frame: the radar is a window
            // onto the chart, not a badge.
            child: CustomPaint(
              foregroundPainter: BracketFramePainter(
                color: BracketPalette.dark.line.withValues(alpha: 0.75),
                bracketSize: 8,
                strokeWidth: 1.05,
              ),
              child: SizedBox(
                width: 76,
                height: 76,
                child: CustomPaint(
                  isComplex: true,
                  painter: _MiniCirclePainter(
                    world: widget.world,
                    game: widget.game,
                    tutorialTargetPos: widget.tutorialTargetPos,
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
  _MiniCirclePainter({
    required this.world,
    required this.game,
    this.tutorialTargetPos,
    super.repaint,
  });

  final CosmicWorld world;
  final CosmicGame game;
  final Offset? tutorialTargetPos;

  /// Dark glass, its rim catching a little light: the lens's edge is drawn
  /// by the glass, not by a ring round it.
  static final ui.Shader _lens = ui.Gradient.radial(
    Offset.zero,
    1,
    const [
      Color(0xF00C0D15),
      Color(0xF0101119),
      Color(0xF01A1B28),
      Color(0xE8262838),
      Color(0x00262838),
    ],
    const [0.0, 0.62, 0.86, 0.95, 1.0],
  );

  static final Map<Color, ui.Shader> _territory = {};

  @override
  void paint(Canvas canvas, Size size) {
    final shipPos = game.ship.pos;
    final center = Offset(size.width / 2, size.height / 2);
    final viewR = size.shortestSide / 2;
    const visibleRadiusWorld = 2600.0;
    final mapScale = (size.shortestSide * 0.46) / visibleRadiusWorld;

    paintDisc(canvas, _lens, center, viewR);
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: viewR - 2)),
    );

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

    bool inView(Offset p, [double pad = 8]) =>
        (p - center).distance <= viewR + pad;

    // The territory the radar sits in shows as a pool of its element.
    for (final planet in world.planets) {
      if (!planet.discovered) continue;
      final p = toMini(planet.position);
      final tr = kPlanetTerritoryRadius * mapScale;
      if (!inView(p, tr)) continue;
      final shader = _territory[planet.color] ??= ui.Gradient.radial(
        Offset.zero,
        1,
        [
          planet.color.withValues(alpha: 0.22),
          planet.color.withValues(alpha: 0.08),
          planet.color.withValues(alpha: 0),
        ],
        const [0.0, 0.6, 1.0],
      );
      paintDisc(canvas, shader, p, tr);
    }

    for (final planet in world.planets) {
      if (!planet.discovered) continue;
      final p = toMini(planet.position);
      if (!inView(p)) continue;
      final m = stoneLightFor(planet.color);
      final r = (planet.radius * mapScale * 1.4).clamp(2.0, 3.6);
      paintDisc(canvas, m.leak, p, r * 2.4, 0.6);
      paintOrb(canvas, m, p, r);
    }

    if (game.homePlanet case final hp?) {
      final p = toMini(hp.position);
      if (inView(p)) {
        paintChartGlyph(canvas, ChartGlyph.home, p, kChartAmber, r: 3.2);
      }
    }

    // Lights: a station, a landmark — each a small point of its own light.
    void light(Offset p, Color c, double r) {
      final m = stoneLightFor(c);
      paintDisc(canvas, m.leak, p, r * 2.4, 0.7);
      paintDisc(canvas, m.spark, p, r, 1);
    }

    for (final poi in game.spacePOIs) {
      final isScanner =
          poi.type == POIType.stardustScanner ||
          poi.type == POIType.planetScanner;
      if (poi.type == POIType.comet) continue;
      final kind = stationKindFor(poi.type);
      final isShop = kind != null && !isScanner;
      final p = toMini(poi.position);
      final isSurvivalPortal = poi.type == POIType.survivalPortal;
      final scannerNearby = isScanner && (p - center).distance <= viewR * 0.9;
      if (!poi.discovered && !isShop && !scannerNearby && !isSurvivalPortal) {
        continue;
      }
      if (!inView(p)) continue;
      // A station is the color it is lit in space.
      final c =
          kind?.accent ??
          switch (poi.type) {
            POIType.nebula => elementColor(poi.element),
            POIType.derelict => const Color(0xFF8FA3B0),
            POIType.warpAnomaly => const Color(0xFFB388FF),
            _ => const Color(0xFF8B5CF6),
          };
      light(p, c, isScanner || isShop ? 2.6 : 2.0);
    }

    // Sealed elemental caches — the radar picks them up whenever they are in
    // range, whether or not the ship has already been right on top of one.
    for (final cache in game.elementalCacheField.caches) {
      if (!cache.isPresent) continue;
      final p = toMini(cache.position);
      if (!inView(p)) continue;
      final m = stoneLightFor(cache.color);
      final pulse = 0.55 + 0.45 * sin(cache.life * 2.2);
      paintDisc(canvas, m.leak, p, 5 + 2 * pulse, 0.5 + 0.4 * pulse);
      paintOrb(canvas, m, p, 2.0);
    }

    for (final arena in world.contestArenas) {
      if (!arena.discovered) continue;
      final p = toMini(arena.position);
      if (!inView(p)) continue;
      // A mastered arena burns in the champion's gold.
      light(
        p,
        arena.masteredAt != null ? kContestChampionGold : arena.trait.color,
        2.4,
      );
    }

    for (final whirl in game.galaxyWhirls) {
      if (whirl.state == WhirlState.completed) continue;
      final p = toMini(whirl.position);
      if (!inView(p)) continue;
      light(p, elementColor(whirl.element), 2.2);
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
      if (inView(p)) light(p, const Color(0xFFE0453A), 2.8);
    }

    if (game.prismaticField.discovered && !game.prismaticField.rewardClaimed) {
      final p = toMini(game.prismaticField.position);
      if (inView(p)) light(p, const Color(0xFFFF5FD2), 2.6);
    }

    if (world.elementalNexus.discovered) {
      final p = toMini(world.elementalNexus.position);
      if (inView(p)) light(p, const Color(0xFFB388FF), 2.6);
    }

    // Locks: the scanners' targets and the tutorial signal. In range they
    // breathe where they are; out of range an arrow on the rim points the
    // way.
    final now = DateTime.now().millisecondsSinceEpoch;
    void lock(Offset world, Color col, double period) {
      final tp = toMini(world);
      final dv = tp - center;
      final dist = dv.distance;
      final m = stoneLightFor(col);
      final pulse = 0.55 + 0.45 * sin(now / period);
      if (dist <= viewR - 6) {
        paintDisc(canvas, m.leak, tp, 6 + pulse * 3, 0.9);
        paintDisc(canvas, m.spark, tp, 3 + pulse, 1);
      } else if (dist > 0.001) {
        final dir = dv / dist;
        final tip = center + dir * (viewR - 4);
        final back = tip - dir * 8;
        final perp = Offset(-dir.dy, dir.dx);
        paintDisc(canvas, m.leak, tip - dir * 4, 7 + pulse * 2, 0.8);
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(back.dx + perp.dx * 3.6, back.dy + perp.dy * 3.6)
            ..lineTo(back.dx - perp.dx * 3.6, back.dy - perp.dy * 3.6)
            ..close(),
          Paint()..color = Color.lerp(col, const Color(0xFFFFFFFF), 0.25)!,
        );
      }
    }

    if (game.starDustScannerTarget case final dust?) {
      lock(dust.position, const Color(0xFFFFE082), 170);
    }
    if (game.planetScannerTarget case final planet?) {
      lock(planet.position, const Color(0xFF90CAF9), 210);
    }
    if (tutorialTargetPos case final target?) {
      lock(target, const Color(0xFF8B5CF6), 180);
    }

    canvas.restore();
    paintChartShip(canvas, center, game.ship.angle, r: 5);
  }

  @override
  bool shouldRepaint(covariant _MiniCirclePainter oldDelegate) =>
      world != oldDelegate.world ||
      game != oldDelegate.game ||
      tutorialTargetPos != oldDelegate.tutorialTargetPos;
}
