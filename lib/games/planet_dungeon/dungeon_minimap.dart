// lib/games/planet_dungeon/dungeon_minimap.dart
//
// Room-scale dungeon minimap. Shows the current chamber, walls, doorways, star
// markers and live creature positions in the dark/alchemical palette. Modeled
// on the cosmic mini-map but fed dungeon-room data.

import 'dart:math' as math;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter/material.dart';

/// Short display labels per room — shared by the full map nodes and the
/// minimap caption.
const Map<String, String> kDungeonRoomLabels = {
  'entry': 'ENTRY',
  'hub': 'HUB',
  'spiral_cloud': 'SPIRAL',
  'ring_cloud': 'RING',
  'lower_spire': 'SPIRE',
  'feather_cloud': 'FEATHER',
  'crosswind_hall': 'GUST',
  'cloud_platforms': 'CLOUDS',
  'spire_summit': 'WIND STAR',
  'sky_loom': 'LOOM',
  'anvil_cloud': 'ANVIL',
  'veil_cloud': 'VEIL',
  'relic_chamber': 'RELIC',
  'storm_rune_hall': 'RUNES',
  'twin_conduit': 'CONDUITS',
  'storm_altar': 'ALTAR',
  'guardian_summit': 'GUARDIAN',
};

const Size _fullMapCanvasSize = Size(880, 980);
const double _fullMapPadding = 8;
const Map<String, Offset> _airFullMapNodePositions = {
  // These positions are an authored atlas, not an auto-layout graph. They
  // follow the room-door geography closely enough that the full map feels
  // like the dungeon the player is walking through.
  'entry': Offset(0.10, 0.26),
  'hub': Offset(0.28, 0.26),
  'spiral_cloud': Offset(0.21, 0.09),
  'ring_cloud': Offset(0.36, 0.09),
  'lower_spire': Offset(0.48, 0.28),
  'feather_cloud': Offset(0.36, 0.43),
  'crosswind_hall': Offset(0.66, 0.18),
  'cloud_platforms': Offset(0.83, 0.18),
  'spire_summit': Offset(0.83, 0.06),
  'sky_loom': Offset(0.63, 0.52),
  'anvil_cloud': Offset(0.47, 0.67),
  'veil_cloud': Offset(0.73, 0.67),
  'relic_chamber': Offset(0.86, 0.46),
  'storm_rune_hall': Offset(0.82, 0.62),
  'twin_conduit': Offset(0.94, 0.70),
  'storm_altar': Offset(0.94, 0.88),
  'guardian_summit': Offset(0.80, 0.82),
};

Offset _fullMapNodePoint(String roomId, Size size) {
  final normalised =
      _airFullMapNodePositions[roomId] ??
      _airFullMapNodePositions['hub'] ??
      const Offset(0.5, 0.5);
  final chart = (Offset.zero & size).deflate(_fullMapPadding);
  return Offset(
    chart.left + chart.width * normalised.dx,
    chart.top + chart.height * normalised.dy,
  );
}

class DungeonMiniMap extends StatelessWidget {
  const DungeonMiniMap({super.key, required this.game, this.boxSize = 132});

  final PlanetDungeonGame game;
  final double boxSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boxSize,
      height: boxSize,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF080808).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF74613A).withValues(alpha: 0.7),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DungeonMiniMapPainter(game)),
          ),
          // Room caption so the chamber map reads at a glance.
          Positioned(
            left: 0,
            right: 0,
            bottom: 1,
            child: Text(
              kDungeonRoomLabels[game.currentRoomId] ??
                  game.currentRoomId.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFE4C16A).withValues(alpha: 0.85),
                fontSize: 7.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          // Expand affordance — the minimap opens the full chart on tap.
          Positioned(
            top: 1,
            right: 1,
            child: Icon(
              Icons.open_in_full_rounded,
              size: 9,
              color: const Color(0xFFC4A35A).withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _DungeonMiniMapPainter extends CustomPainter {
  _DungeonMiniMapPainter(this.game);

  final PlanetDungeonGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final room = game.currentRoom;
    final b = room.bounds;
    final scale = (size.width / b.width).clamp(0.0, size.height / b.height);
    final drawW = b.width * scale;
    final drawH = b.height * scale;
    final ox = (size.width - drawW) / 2;
    final oy = (size.height - drawH) / 2;

    Offset map(Offset world) => Offset(
      ox + (world.dx - b.left) * scale,
      oy + (world.dy - b.top) * scale,
    );

    // Floor.
    final floor = Rect.fromLTWH(ox, oy, drawW, drawH);
    canvas.drawRect(floor, Paint()..color = const Color(0xFF14120E));
    canvas.drawRect(
      floor,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF74613A).withValues(alpha: 0.6),
    );

    // Walls.
    final wallPaint = Paint()..color = const Color(0xFF2E2A23);
    for (final w in room.walls) {
      canvas.drawRect(
        Rect.fromPoints(map(w.topLeft), map(w.bottomRight)),
        wallPaint,
      );
    }

    // Doors (teal; star-locked doors render amber-dim).
    final doorPaint = Paint()
      ..color = const Color(0xFF5BC8E8).withValues(alpha: 0.85);
    final lockedPaint = Paint()
      ..color = const Color(0xFFC4A35A).withValues(alpha: 0.45);
    for (final d in room.doors) {
      if (game.isDoorHidden(room, d)) continue;
      canvas.drawRect(
        Rect.fromPoints(map(d.rect.topLeft), map(d.rect.bottomRight)),
        game.isDoorLocked(room, d) ? lockedPaint : doorPaint,
      );
    }

    // Star markers.
    for (final s in room.stars) {
      final earned = game.hasStar(s.starIndex);
      canvas.drawCircle(
        map(s.position),
        earned ? 2.0 : 3.0,
        Paint()
          ..color = const Color(
            0xFFE4C16A,
          ).withValues(alpha: earned ? 0.35 : 0.95),
      );
    }

    // Objective beacon: this chamber's unfinished business, so no room
    // ever reads as stale on the map.
    Offset? objective;
    if (room.anchors.isEmpty &&
        room.clouds.length == 1 &&
        !game.discoveredClouds.contains(room.clouds.first.id)) {
      objective = room.clouds.first.position; // sealed wonder trial
    } else if (room.summit != null && !game.hasStar(room.summit!.starIndex)) {
      objective = room.summit!.rect.center;
    } else if (room.loomStarIndex != null &&
        !game.hasStar(room.loomStarIndex!)) {
      objective = room.bounds.center;
    } else if (room.guardian != null &&
        !game.hasStar(room.guardian!.starIndex)) {
      objective = room.guardian!.position;
    } else if (room.conduits.isNotEmpty && !game.hasStar(2)) {
      objective = room.conduits.first.position;
    } else if (room.rings.isNotEmpty && !game.hasStar(0)) {
      objective = room.rings.first.position;
    }
    if (objective != null) {
      final p = map(objective);
      canvas.drawCircle(
        p,
        4.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = const Color(0xFFE4C16A).withValues(alpha: 0.8),
      );
      canvas.drawCircle(
        p,
        1.6,
        Paint()..color = const Color(0xFFE4C16A).withValues(alpha: 0.95),
      );
    }

    // Creatures (active = amber, others element-tinted).
    for (var i = 0; i < game.creatures.length; i++) {
      final c = game.creatures[i];
      final isActive = i == game.activeIndex;
      canvas.drawCircle(
        map(c.position),
        isActive ? 3.0 : 2.0,
        Paint()
          ..color = isActive
              ? const Color(0xFFE4C16A)
              : elementColor(c.member.element).withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DungeonMiniMapPainter oldDelegate) => true;
}

class DungeonFullMap extends StatefulWidget {
  const DungeonFullMap({super.key, required this.game, required this.onClose});

  final PlanetDungeonGame game;
  final VoidCallback onClose;

  @override
  State<DungeonFullMap> createState() => _DungeonFullMapState();
}

class _DungeonFullMapState extends State<DungeonFullMap> {
  final TransformationController _mapController = TransformationController();
  String? _centeredRoomId;
  Size? _centeredViewport;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _centerOnCurrentRoom(Size viewport) {
    final roomId = widget.game.currentRoomId;
    if (_centeredRoomId == roomId && _centeredViewport == viewport) return;
    _centeredRoomId = roomId;
    _centeredViewport = viewport;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scale = (viewport.width / 540).clamp(0.56, 0.78).toDouble();
      final node = _fullMapNodePoint(roomId, _fullMapCanvasSize);
      final tx = viewport.width / 2 - node.dx * scale;
      final ty = viewport.height / 2 - node.dy * scale;
      _mapController.value = Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setEntry(0, 3, tx)
        ..setEntry(1, 3, ty);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = math.min(screen.width - 28, 410.0);
    final height = math.min(screen.height - 70, 620.0);

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF080808).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFC4A35A).withValues(alpha: 0.68),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5BC8E8).withValues(alpha: 0.16),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'WIND-CROWN SPIRE',
                  style: TextStyle(
                    color: Color(0xFFE8DFC8),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.7,
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14120E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF74613A).withValues(alpha: 0.7),
                    ),
                  ),
                  child: const Text(
                    'CLOSE',
                    style: TextStyle(
                      color: Color(0xFFE4C16A),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _centerOnCurrentRoom(
                    Size(constraints.maxWidth, constraints.maxHeight),
                  );
                  return InteractiveViewer(
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(140),
                    minScale: 0.46,
                    maxScale: 1.7,
                    transformationController: _mapController,
                    child: CustomPaint(
                      size: _fullMapCanvasSize,
                      painter: _DungeonFullMapPainter(widget.game),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'DRAG / PINCH MAP',
            style: TextStyle(
              color: const Color(0xFFE8DFC8).withValues(alpha: 0.46),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          const _FullMapLegend(),
        ],
      ),
    );
  }
}

class _FullMapLegend extends StatelessWidget {
  const _FullMapLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 5,
      children: const [
        _LegendChip(color: Color(0xFFE4C16A), label: 'CURRENT'),
        _LegendChip(color: Color(0xFF5BC8E8), label: 'DISCOVERED'),
        _LegendChip(color: Color(0xFF22C55E), label: 'STAR DONE'),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFFE8DFC8).withValues(alpha: 0.72),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _DungeonFullMapPainter extends CustomPainter {
  _DungeonFullMapPainter(this.game);

  final PlanetDungeonGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final positions = {
      for (final entry in _airFullMapNodePositions.entries)
        if (game.layout.rooms.containsKey(entry.key))
          entry.key: _fullMapNodePoint(entry.key, size),
    };

    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF101928), Color(0xFF090B10)],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      background,
    );

    _drawSectionAura(canvas, positions, const [
      'lower_spire',
      'crosswind_hall',
      'cloud_platforms',
      'spire_summit',
    ], const Color(0xFF5BC8E8));
    _drawSectionAura(canvas, positions, const [
      'spiral_cloud',
      'ring_cloud',
      'feather_cloud',
      'sky_loom',
      'anvil_cloud',
      'veil_cloud',
      'relic_chamber',
    ], const Color(0xFFE4C16A));
    _drawSectionAura(canvas, positions, const [
      'storm_rune_hall',
      'twin_conduit',
      'storm_altar',
      'guardian_summit',
    ], const Color(0xFFFFFF8A));

    _drawEdges(canvas, positions);
    for (final id in positions.keys) {
      _drawNode(canvas, positions[id]!, id);
    }
  }

  void _drawSectionAura(
    Canvas canvas,
    Map<String, Offset> positions,
    List<String> ids,
    Color color,
  ) {
    final points = ids.map((id) => positions[id]).whereType<Offset>().toList();
    if (points.isEmpty) return;
    var minX = points.first.dx;
    var maxX = points.first.dx;
    var minY = points.first.dy;
    var maxY = points.first.dy;
    for (final p in points.skip(1)) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final aura = Rect.fromLTRB(minX, minY, maxX, maxY).inflate(28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(aura, const Radius.circular(28)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.10),
    );
  }

  void _drawEdges(Canvas canvas, Map<String, Offset> positions) {
    final seen = <String>{};
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    for (final room in game.layout.rooms.values) {
      final from = positions[room.id];
      if (from == null) continue;
      for (final door in room.doors) {
        final to = positions[door.targetRoomId];
        if (to == null) continue;
        final key = room.id.compareTo(door.targetRoomId) < 0
            ? '${room.id}:${door.targetRoomId}'
            : '${door.targetRoomId}:${room.id}';
        if (!seen.add(key)) continue;
        final active =
            room.id == game.currentRoomId ||
            door.targetRoomId == game.currentRoomId;
        paint.color =
            (active ? const Color(0xFF5BC8E8) : const Color(0xFF74613A))
                .withValues(alpha: active ? 0.62 : 0.34);
        final path = Path()..moveTo(from.dx, from.dy);
        final control = _edgeControl(room.id, door.targetRoomId, from, to);
        path.quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
        canvas.drawPath(path, paint);
      }
    }
  }

  Offset _edgeControl(String a, String b, Offset from, Offset to) {
    final mid = Offset.lerp(from, to, 0.5)!;
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final distance = (to - from).distance;
    if (distance < 95) return mid;

    final key = a.compareTo(b) < 0 ? '$a:$b' : '$b:$a';
    final bend = switch (key) {
      'hub:sky_loom' => const Offset(-50, 22),
      'sky_loom:spire_summit' => const Offset(46, 64),
      'crosswind_hall:lower_spire' => const Offset(16, -42),
      'guardian_summit:storm_altar' => const Offset(-38, -30),
      _ => Offset(-dy, dx) / distance * 18,
    };
    return mid + bend;
  }

  void _drawNode(Canvas canvas, Offset c, String id) {
    final room = game.layout.rooms[id]!;
    final current = id == game.currentRoomId;
    final star =
        room.summit?.starIndex ??
        room.loomStarIndex ??
        room.guardian?.starIndex;
    final starDone = star != null && game.hasStar(star);
    final cloudTouched =
        room.clouds.isNotEmpty &&
        room.clouds.any(
          (cloud) =>
              game.discoveredClouds.contains(cloud.id) ||
              game.placedClouds.contains(cloud.id),
        );
    final stormLive =
        room.conduits.isNotEmpty &&
        (game.altarOpen || game.conduitEnergy.isNotEmpty);

    final color = current
        ? const Color(0xFFE4C16A)
        : starDone
        ? const Color(0xFF22C55E)
        : stormLive
        ? const Color(0xFFFFFF8A)
        : cloudTouched
        ? const Color(0xFF5BC8E8)
        : const Color(0xFF74613A);
    final radius = current ? 10.5 : 8.0;

    if (current || starDone || stormLive) {
      canvas.drawCircle(
        c,
        radius + 8,
        Paint()..color = color.withValues(alpha: current ? 0.18 : 0.10),
      );
    }
    canvas.drawCircle(c, radius, Paint()..color = const Color(0xFF14120E));
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = current ? 2.4 : 1.5
        ..color = color.withValues(alpha: current ? 0.95 : 0.72),
    );

    if (star != null) {
      _drawStar(canvas, c, starDone ? 4.2 : 3.5, color);
    } else if (room.clouds.isNotEmpty) {
      canvas.drawCircle(
        c,
        3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: 0.8),
      );
    } else if (room.conduits.isNotEmpty || room.guardian != null) {
      canvas.drawLine(
        c + const Offset(-3, 3),
        c + const Offset(2, -4),
        Paint()
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.9),
      );
      canvas.drawLine(
        c + const Offset(2, -4),
        c + const Offset(5, 1),
        Paint()
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.9),
      );
    }

    _drawLabel(
      canvas,
      c + Offset(0, current ? 20 : 17),
      kDungeonRoomLabels[id] ?? id,
    );
  }

  void _drawStar(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.86));
  }

  void _drawLabel(Canvas canvas, Offset center, String label) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: const Color(0xFFE8DFC8).withValues(alpha: 0.72),
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 62);
    tp.paint(canvas, center - Offset(tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant _DungeonFullMapPainter oldDelegate) => true;
}
