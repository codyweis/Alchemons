import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/utils/faction_util.dart';
import '../models/map_marker.dart';

class MiniMapOverlay extends StatefulWidget {
  const MiniMapOverlay({
    required this.world,
    required this.game,
    required this.theme,
    required this.markers,
    required this.onTeleport,
    required this.onClose,
    required this.onMarkersChanged,
  });

  final CosmicWorld world;
  final CosmicGame game;
  final FactionTheme theme;
  final List<MapMarker> markers;
  final void Function(Offset worldPos) onTeleport;
  final VoidCallback onClose;
  final void Function(List<MapMarker> markers) onMarkersChanged;

  @override
  State<MiniMapOverlay> createState() => MiniMapOverlayState();
}

class MiniMapOverlayState extends State<MiniMapOverlay> {
  final TransformationController _transformCtrl = TransformationController();
  int _selectedColor = 0; // 0=red, 1=blue, 2=green
  bool _markerMode = false;

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _handleTapUp(TapUpDetails details, double scale) {
    // GestureDetector is inside InteractiveViewer — localPosition is already
    // in the child's (map) coordinate space, no toScene() needed.
    final worldX = details.localPosition.dx / scale;
    final worldY = details.localPosition.dy / scale;

    if (_markerMode) {
      // Place marker
      final newMarkers = List<MapMarker>.from(widget.markers)
        ..add(
          MapMarker(
            worldPos: Offset(worldX, worldY),
            colorIndex: _selectedColor,
          ),
        );
      widget.onMarkersChanged(newMarkers);
      return;
    }

    // Teleport to nearest discovered planet (or home planet) — only if
    // the tap is close enough to the planet's dot on the map.
    final tapPos = Offset(worldX, worldY);
    CosmicPlanet? bestPlanet;
    Offset? bestPos;
    double bestDist = double.infinity;
    for (final p in widget.world.planets) {
      if (!p.discovered) continue;
      final d = (p.position - tapPos).distance;
      // Only accept if tap is within ~6× the planet's world radius
      if (d < p.radius * 6 && d < bestDist) {
        bestPlanet = p;
        bestPos = p.position;
        bestDist = d;
      }
    }
    // Also check home planet
    if (widget.game.homePlanet != null) {
      final hp = widget.game.homePlanet!;
      final d = (hp.position - tapPos).distance;
      if (d < hp.visualRadius * 6 && d < bestDist) {
        bestPlanet = null;
        bestPos = hp.position;
        bestDist = d;
      }
    }
    // Also check discovered space POIs (markets, etc.)
    for (final poi in widget.game.spacePOIs) {
      if (!poi.discovered) continue;
      final d = (poi.position - tapPos).distance;
      // Tap within ~500 world units of POI
      if (d < 500 && d < bestDist) {
        bestPlanet = null;
        bestPos = poi.position;
        bestDist = d;
      }
    }
    // Boss lairs are shown on the map but cannot be teleported to.
    if (bestPos == null) return; // tap was too far from any target
    widget.onTeleport(bestPos);
  }

  void _handleLongPress(LongPressStartDetails details, double scale) {
    // localPosition is already in child coordinate space
    final worldX = details.localPosition.dx / scale;
    final worldY = details.localPosition.dy / scale;
    final tapWorld = Offset(worldX, worldY);

    int? closestIdx;
    double closestDist = double.infinity;
    for (var i = 0; i < widget.markers.length; i++) {
      final d = (widget.markers[i].worldPos - tapWorld).distance;
      if (d < closestDist) {
        closestDist = d;
        closestIdx = i;
      }
    }
    // Remove if within ~800 world units
    if (closestIdx != null && closestDist < 800) {
      final newMarkers = List<MapMarker>.from(widget.markers)
        ..removeAt(closestIdx);
      widget.onMarkersChanged(newMarkers);
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'STAR MAP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Marker toolbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  // Toggle marker mode
                  GestureDetector(
                    onTap: () => setState(() => _markerMode = !_markerMode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _markerMode ? Colors.white24 : Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                        border: _markerMode
                            ? Border.all(
                                color: MapMarker.colors[_selectedColor],
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin,
                            color: _markerMode
                                ? MapMarker.colors[_selectedColor]
                                : Colors.white54,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _markerMode ? 'MARKING' : 'MARK',
                            style: TextStyle(
                              color: _markerMode
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Color selectors
                  for (var i = 0; i < 3; i++) ...[
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedColor = i;
                        _markerMode = true;
                      }),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: MapMarker.colors[i].withValues(
                            alpha: _selectedColor == i && _markerMode
                                ? 0.9
                                : 0.35,
                          ),
                          shape: BoxShape.circle,
                          border: _selectedColor == i && _markerMode
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                      ),
                    ),
                    if (i < 2) const SizedBox(width: 6),
                  ],
                  const Spacer(),
                  // Clear all markers
                  if (widget.markers.isNotEmpty)
                    GestureDetector(
                      onTap: () => widget.onMarkersChanged([]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'CLEAR ALL',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Zoomable / pannable map
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final mapW = constraints.maxWidth;
                    final mapH = constraints.maxHeight;
                    // Use the tighter dimension so the square map fills the
                    // available space without dead gaps on any side.
                    final fitSize = min(mapW, mapH);
                    final scale =
                        fitSize /
                        max(
                          widget.world.worldSize.width,
                          widget.world.worldSize.height,
                        );

                    return Center(
                      child: SizedBox(
                        width: fitSize,
                        height: fitSize,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: InteractiveViewer(
                            transformationController: _transformCtrl,
                            minScale: 1.0,
                            maxScale: 8.0,
                            boundaryMargin: EdgeInsets.zero,
                            child: GestureDetector(
                              onTapUp: (d) => _handleTapUp(d, scale),
                              onLongPressStart: (d) =>
                                  _handleLongPress(d, scale),
                              child: CustomPaint(
                                size: Size(fitSize, fitSize),
                                painter: _MiniMapPainter(
                                  world: widget.world,
                                  game: widget.game,
                                  scale: scale,
                                  markers: widget.markers,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Legend
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _markerMode
                    ? 'Tap to place marker  •  Long-press to remove'
                    : 'Tap planet to teleport  •  Pinch to zoom  •  Drag to pan',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({
    required this.world,
    required this.game,
    required this.scale,
    this.markers = const [],
  });

  final CosmicWorld world;
  final CosmicGame game;
  final double scale;
  final List<MapMarker> markers;

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF060820),
    );

    // Fog grid
    final fogCellScaled = CosmicGame.fogCellSize * scale;
    final gridW = (world.worldSize.width / CosmicGame.fogCellSize).ceil();

    // Draw revealed cells as slightly lighter
    final revealPaint = Paint()..color = const Color(0xFF0C1030);
    for (final key in game.revealedCells) {
      final gx = key % gridW;
      final gy = key ~/ gridW;
      canvas.drawRect(
        Rect.fromLTWH(
          gx * fogCellScaled,
          gy * fogCellScaled,
          fogCellScaled,
          fogCellScaled,
        ),
        revealPaint,
      );
    }

    // Planets
    for (final planet in world.planets) {
      if (!planet.discovered) continue;
      final px = planet.position.dx * scale;
      final py = planet.position.dy * scale;
      final pr = max(3.0, planet.radius * scale);

      // Glow
      canvas.drawCircle(
        Offset(px, py),
        pr * 3,
        Paint()
          ..color = planet.color.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Dot
      canvas.drawCircle(Offset(px, py), pr, Paint()..color = planet.color);

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: planetName(planet.element),
          style: TextStyle(
            color: planet.color.withValues(alpha: 0.8),
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(px - tp.width / 2, py + pr + 2));
    }

    // Asteroid belt (faint ring)
    final belt = game.asteroidBelt;
    final bx = belt.center.dx * scale;
    final by = belt.center.dy * scale;
    canvas.drawCircle(
      Offset(bx, by),
      belt.innerRadius * scale,
      Paint()
        ..color = const Color(0xFF5D4037).withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (belt.outerRadius - belt.innerRadius) * scale,
    );

    // Home planet
    if (game.homePlanet != null) {
      final hp = game.homePlanet!;
      final hx = hp.position.dx * scale;
      final hy = hp.position.dy * scale;
      final hr = max(4.0, hp.visualRadius * scale);

      // Glow
      canvas.drawCircle(
        Offset(hx, hy),
        hr * 3,
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Dot
      canvas.drawCircle(Offset(hx, hy), hr, Paint()..color = hp.blendedColor);
      // HOME label
      final homeLabel = TextPainter(
        text: const TextSpan(
          text: 'HOME',
          style: TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      homeLabel.paint(canvas, Offset(hx - homeLabel.width / 2, hy + hr + 2));
    }

    // Map markers
    for (final marker in markers) {
      final mx = marker.worldPos.dx * scale;
      final my = marker.worldPos.dy * scale;

      // Glow
      canvas.drawCircle(
        Offset(mx, my),
        8,
        Paint()
          ..color = marker.color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      // Pin dot
      canvas.drawCircle(Offset(mx, my), 4, Paint()..color = marker.color);
      // White outline
      canvas.drawCircle(
        Offset(mx, my),
        4,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Galaxy whirls (horde encounters) — show dormant & active
    for (final whirl in game.galaxyWhirls) {
      if (whirl.state == WhirlState.completed) continue;
      final wx = whirl.position.dx * scale;
      final wy = whirl.position.dy * scale;
      final wColor = elementColor(whirl.element);

      // Swirl glow
      canvas.drawCircle(
        Offset(wx, wy),
        10,
        Paint()
          ..color = wColor.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      // Spiral icon (3 curved arcs)
      final spiralPaint = Paint()
        ..color = wColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (var i = 0; i < 3; i++) {
        final startAngle = i * (pi * 2 / 3);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(wx, wy), radius: 5),
          startAngle,
          pi * 0.7,
          false,
          spiralPaint,
        );
      }
      // Center dot
      canvas.drawCircle(Offset(wx, wy), 2, Paint()..color = wColor);

      // Label
      final whirlLabel = TextPainter(
        text: TextSpan(
          text: 'Lv${whirl.level} ${whirl.hordeTypeName}',
          style: TextStyle(
            color: wColor.withValues(alpha: 0.7),
            fontSize: 7,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      whirlLabel.paint(canvas, Offset(wx - whirlLabel.width / 2, wy + 8));
    }

    // Boss lairs — only show the nearest waiting lair on the map
    BossLair? nearestLair;
    double nearestLairDist = double.infinity;
    for (final lair in game.bossLairs) {
      if (lair.state != BossLairState.waiting) continue;
      final dx = lair.position.dx - game.ship.pos.dx;
      final dy = lair.position.dy - game.ship.pos.dy;
      final d = sqrt(dx * dx + dy * dy);
      if (d < nearestLairDist) {
        nearestLairDist = d;
        nearestLair = lair;
      }
    }
    if (nearestLair != null) {
      final lair = nearestLair;
      final lx = lair.position.dx * scale;
      final ly = lair.position.dy * scale;
      final bColor = elementColor(lair.template.element);

      // Ominous glow
      canvas.drawCircle(
        Offset(lx, ly),
        12,
        Paint()
          ..color = const Color(0xFFFF1744).withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      // Diamond/skull shape
      final path = Path()
        ..moveTo(lx, ly - 6) // top
        ..lineTo(lx + 5, ly) // right
        ..lineTo(lx, ly + 6) // bottom
        ..lineTo(lx - 5, ly) // left
        ..close();
      canvas.drawPath(path, Paint()..color = bColor.withValues(alpha: 0.7));
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFF1744).withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Label
      final bossTypeTag = switch (bossTypeForLevel(lair.level)) {
        BossType.charger => '⚡',
        BossType.gunner => '🔫',
        BossType.warden => '👑',
      };
      final bossLabel = TextPainter(
        text: TextSpan(
          text:
              '$bossTypeTag Lv${lair.level} ${lair.template.name.toUpperCase()}',
          style: const TextStyle(
            color: Color(0xFFFF5252),
            fontSize: 6,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      bossLabel.paint(canvas, Offset(lx - bossLabel.width / 2, ly + 9));
    }

    // Discovered space POIs (nebula, derelict, comet, warp anomaly)
    // Markets always show their marker but hide the label until discovered.
    for (final poi in game.spacePOIs) {
      final isMarket =
          poi.type == POIType.harvesterMarket ||
          poi.type == POIType.riftKeyMarket ||
          poi.type == POIType.cosmicMarket;
      if (!poi.discovered && !isMarket) continue;

      final poiX = poi.position.dx * scale;
      final poiY = poi.position.dy * scale;

      late Color poiColor;
      late String poiLabel;
      late double poiDotR;

      switch (poi.type) {
        case POIType.nebula:
          poiColor = elementColor(poi.element);
          poiLabel = '${poi.element.toUpperCase()} NEBULA';
          poiDotR = 4.0;
          // Cloud-like glow
          canvas.drawCircle(
            Offset(poiX, poiY),
            10,
            Paint()
              ..color = poiColor.withValues(alpha: poi.interacted ? 0.12 : 0.25)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
          canvas.drawCircle(
            Offset(poiX, poiY),
            poiDotR,
            Paint()
              ..color = poiColor.withValues(alpha: poi.interacted ? 0.4 : 0.8),
          );
          break;
        case POIType.derelict:
          poiColor = const Color(0xFF78909C);
          poiLabel = 'DERELICT';
          poiDotR = 3.0;
          // Small square
          canvas.drawRect(
            Rect.fromCenter(center: Offset(poiX, poiY), width: 6, height: 6),
            Paint()
              ..color = poiColor.withValues(alpha: poi.interacted ? 0.35 : 0.7),
          );
          break;
        case POIType.comet:
          poiColor = elementColor(poi.element);
          poiLabel = 'COMET';
          poiDotR = 3.0;
          // Small triangle
          final cPath = Path()
            ..moveTo(poiX, poiY - 4)
            ..lineTo(poiX + 3.5, poiY + 3)
            ..lineTo(poiX - 3.5, poiY + 3)
            ..close();
          canvas.drawPath(
            cPath,
            Paint()..color = poiColor.withValues(alpha: 0.7),
          );
          break;
        case POIType.warpAnomaly:
          poiColor = const Color(0xFFB388FF);
          poiLabel = 'ANOMALY';
          poiDotR = 4.0;
          // Purple ring
          canvas.drawCircle(
            Offset(poiX, poiY),
            poiDotR,
            Paint()
              ..color = poiColor.withValues(alpha: poi.interacted ? 0.3 : 0.6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
          canvas.drawCircle(
            Offset(poiX, poiY),
            2,
            Paint()
              ..color = poiColor.withValues(alpha: poi.interacted ? 0.3 : 0.7),
          );
          break;
        case POIType.harvesterMarket:
          poiColor = const Color(0xFFFFB300); // amber
          poiLabel = 'HARVESTER SHOP';
          poiDotR = 5.0;
          final hAlpha = poi.discovered ? 0.7 : 0.25;
          // Hexagonal station marker
          final hHexPath = Path();
          for (int i = 0; i < 6; i++) {
            final a = pi / 3 * i - pi / 6;
            final hx = poiX + 5.0 * cos(a);
            final hy = poiY + 5.0 * sin(a);
            if (i == 0) {
              hHexPath.moveTo(hx, hy);
            } else {
              hHexPath.lineTo(hx, hy);
            }
          }
          hHexPath.close();
          canvas.drawPath(
            hHexPath,
            Paint()..color = poiColor.withValues(alpha: hAlpha),
          );
          canvas.drawPath(
            hHexPath,
            Paint()
              ..color = poiColor.withValues(alpha: poi.discovered ? 1.0 : 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
          break;
        case POIType.riftKeyMarket:
          poiColor = const Color(0xFF7C4DFF); // purple
          poiLabel = 'RIFT KEY SHOP';
          poiDotR = 5.0;
          final rAlpha = poi.discovered ? 0.7 : 0.25;
          // Hexagonal station marker
          final rHexPath = Path();
          for (int i = 0; i < 6; i++) {
            final a = pi / 3 * i - pi / 6;
            final rx = poiX + 5.0 * cos(a);
            final ry = poiY + 5.0 * sin(a);
            if (i == 0) {
              rHexPath.moveTo(rx, ry);
            } else {
              rHexPath.lineTo(rx, ry);
            }
          }
          rHexPath.close();
          canvas.drawPath(
            rHexPath,
            Paint()..color = poiColor.withValues(alpha: rAlpha),
          );
          canvas.drawPath(
            rHexPath,
            Paint()
              ..color = poiColor.withValues(alpha: poi.discovered ? 1.0 : 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
          break;
        case POIType.cosmicMarket:
          poiColor = const Color(0xFF00E5FF); // cyan/teal
          poiLabel = 'COSMIC MARKET';
          poiDotR = 5.0;
          final cAlpha = poi.discovered ? 0.7 : 0.25;
          // Hexagonal station marker
          final cHexPath = Path();
          for (int i = 0; i < 6; i++) {
            final a = pi / 3 * i - pi / 6;
            final cx2 = poiX + 5.0 * cos(a);
            final cy2 = poiY + 5.0 * sin(a);
            if (i == 0) {
              cHexPath.moveTo(cx2, cy2);
            } else {
              cHexPath.lineTo(cx2, cy2);
            }
          }
          cHexPath.close();
          canvas.drawPath(
            cHexPath,
            Paint()..color = poiColor.withValues(alpha: cAlpha),
          );
          canvas.drawPath(
            cHexPath,
            Paint()
              ..color = poiColor.withValues(alpha: poi.discovered ? 1.0 : 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
          break;
      }

      // Label (hidden for undiscovered markets)
      if (poi.discovered || !isMarket) {
        final poiTp = TextPainter(
          text: TextSpan(
            text: poiLabel,
            style: TextStyle(
              color: poiColor.withValues(alpha: poi.interacted ? 0.35 : 0.65),
              fontSize: 6,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        poiTp.paint(canvas, Offset(poiX - poiTp.width / 2, poiY + poiDotR + 2));
      } else {
        // Undiscovered market: show '?' instead
        final poiTp = TextPainter(
          text: TextSpan(
            text: '?',
            style: TextStyle(
              color: poiColor.withValues(alpha: 0.4),
              fontSize: 7,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        poiTp.paint(canvas, Offset(poiX - poiTp.width / 2, poiY + poiDotR + 2));
      }
    }

    // Rift portals are secret — not shown on the minimap.

    // Prismatic field marker — only shown if discovered and not yet claimed
    if (game.prismaticField.discovered && !game.prismaticField.rewardClaimed) {
      final pf = game.prismaticField;
      final pfx = pf.position.dx * scale;
      final pfy = pf.position.dy * scale;
      final pfr = max(6.0, pf.radius * scale);

      // Rainbow glow
      canvas.drawCircle(
        Offset(pfx, pfy),
        pfr,
        Paint()
          ..color = const Color(0xFFFF00CC).withValues(alpha: 0.15)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, pfr * 0.5),
      );
      // Prismatic ring
      canvas.drawCircle(
        Offset(pfx, pfy),
        pfr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = const Color(0xFFFF00CC).withValues(alpha: 0.6),
      );
      // Inner shimmer dot
      canvas.drawCircle(
        Offset(pfx, pfy),
        3,
        Paint()..color = const Color(0xFFFFDD00).withValues(alpha: 0.8),
      );
      // Label
      final pfLabel = TextPainter(
        text: const TextSpan(
          text: 'PRISMATIC AURORA',
          style: TextStyle(
            color: Color(0xB3FF00CC),
            fontSize: 6,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      pfLabel.paint(canvas, Offset(pfx - pfLabel.width / 2, pfy + pfr + 3));
    }

    // Elemental Nexus marker (only after discovery)
    {
      final nx = world.elementalNexus;
      if (nx.discovered) {
        final nxX = nx.position.dx * scale;
        final nxY = nx.position.dy * scale;

        // Dark void glow
        canvas.drawCircle(
          Offset(nxX, nxY),
          14,
          Paint()
            ..color = const Color(0xFF7C4DFF).withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
        // Black core
        canvas.drawCircle(
          Offset(nxX, nxY),
          6,
          Paint()..color = const Color(0xFF0A0A0A),
        );
        // Multi-element ring
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = const Color(0xFFB388FF).withValues(alpha: 0.7);
        canvas.drawCircle(Offset(nxX, nxY), 7, ringPaint);
        // 4 tiny element dots orbiting
        const nexusDotColors = [
          Color(0xFFFF6D00), // fire
          Color(0xFF2196F3), // water
          Color(0xFF4CAF50), // earth
          Color(0xFF90CAF9), // air
        ];
        for (var i = 0; i < 4; i++) {
          final a = i * pi / 2;
          canvas.drawCircle(
            Offset(nxX + 10 * cos(a), nxY + 10 * sin(a)),
            2,
            Paint()..color = nexusDotColors[i].withValues(alpha: 0.8),
          );
        }
        // Label
        final nxLabel = TextPainter(
          text: const TextSpan(
            text: 'ELEMENTAL NEXUS',
            style: TextStyle(
              color: Color(0xB3B388FF),
              fontSize: 6,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        nxLabel.paint(canvas, Offset(nxX - nxLabel.width / 2, nxY + 12));
      }
    }

    // Battle Ring marker (always visible for debug)
    {
      final br = world.battleRing;
      if (br.discovered) {
        final brX = br.position.dx * scale;
        final brY = br.position.dy * scale;

        // Golden glow
        canvas.drawCircle(
          Offset(brX, brY),
          12,
          Paint()
            ..color = const Color(0xFFFFD740).withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );

        // Octagon outline
        final octPath = Path();
        for (var i = 0; i < 8; i++) {
          final a = i * pi / 4 - pi / 8;
          final x = brX + cos(a) * 8;
          final y = brY + sin(a) * 8;
          if (i == 0) {
            octPath.moveTo(x, y);
          } else {
            octPath.lineTo(x, y);
          }
        }
        octPath.close();
        canvas.drawPath(
          octPath,
          Paint()
            ..color = const Color(0xFFFFD740).withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );

        // Center dot
        canvas.drawCircle(
          Offset(brX, brY),
          2.5,
          Paint()..color = const Color(0xFFFFD740).withValues(alpha: 0.9),
        );

        // Label
        final brLabel = TextPainter(
          text: TextSpan(
            text: br.isCompleted ? 'BATTLE ARENA' : 'BATTLE RING',
            style: const TextStyle(
              color: Color(0xB3FFD740),
              fontSize: 6,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        brLabel.paint(canvas, Offset(brX - brLabel.width / 2, brY + 12));
      }
    }

    // Ship position
    final sx = game.ship.pos.dx * scale;
    final sy = game.ship.pos.dy * scale;
    canvas.drawCircle(
      Offset(sx, sy),
      5,
      Paint()
        ..color = const Color(0xFF00E5FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(Offset(sx, sy), 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────
// SUMMON POPUP
// ─────────────────────────────────────────────────────────
