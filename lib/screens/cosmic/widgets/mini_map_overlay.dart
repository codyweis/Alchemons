import 'dart:math';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/utils/faction_util.dart';
import '../models/map_marker.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MINI MAP OVERLAY
// ─────────────────────────────────────────────────────────────────────────────

class MiniMapOverlay extends StatefulWidget {
  const MiniMapOverlay({
    super.key,
    required this.world,
    required this.game,
    required this.theme,
    required this.markers,
    required this.onTeleport,
    required this.onNavigatePlanet,
    required this.onClose,
    required this.onMarkersChanged,
    this.debugShowAllContestArenasOnMap = false,
    this.debugEnableContestArenaTeleport = false,
  });

  final CosmicWorld world;
  final CosmicGame game;
  final FactionTheme theme;
  final List<MapMarker> markers;
  final void Function(Offset worldPos) onTeleport;
  final void Function(CosmicPlanet planet) onNavigatePlanet;
  final VoidCallback onClose;
  final void Function(List<MapMarker> markers) onMarkersChanged;
  final bool debugShowAllContestArenasOnMap;
  final bool debugEnableContestArenaTeleport;

  @override
  State<MiniMapOverlay> createState() => MiniMapOverlayState();
}

class MiniMapOverlayState extends State<MiniMapOverlay>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformCtrl = TransformationController();
  int _selectedColor = 0;
  bool _markerMode = false;
  int _planetIndex = 0;
  late final AnimationController _spinCtrl;

  // Sorted + filtered once per build, cached here to avoid repeated sorts.
  late List<CosmicPlanet> _discoveredPlanets;

  void _refreshPlanets() {
    _discoveredPlanets =
        widget.world.planets.where((p) => p.discovered).toList()..sort(
          (a, b) => planetName(a.element).compareTo(planetName(b.element)),
        );
  }

  @override
  void initState() {
    super.initState();
    _refreshPlanets();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  void _handleTapUp(TapUpDetails details, double scale) {
    final wx = details.localPosition.dx / scale;
    final wy = details.localPosition.dy / scale;

    if (_markerMode) {
      widget.onMarkersChanged([
        ...widget.markers,
        MapMarker(worldPos: Offset(wx, wy), colorIndex: _selectedColor),
      ]);
      return;
    }

    final tapPos = Offset(wx, wy);
    Offset? bestPos;
    double bestDist = double.infinity;

    void _tryUpdate(Offset pos, double dist) {
      if (dist < bestDist) {
        bestDist = dist;
        bestPos = pos;
      }
    }

    for (final p in widget.world.planets) {
      if (!p.discovered) continue;
      final d = (p.position - tapPos).distance;
      if (d < p.radius * 7) _tryUpdate(p.position, d);
    }

    if (widget.game.homePlanet case final hp?) {
      final d = (hp.position - tapPos).distance;
      if (d < hp.visualRadius * 7) _tryUpdate(hp.position, d);
    }

    for (final poi in widget.game.spacePOIs) {
      if (!poi.discovered) continue;
      if (poi.type != POIType.harvesterMarket &&
          poi.type != POIType.riftKeyMarket &&
          poi.type != POIType.cosmicMarket)
        continue;
      final d = (poi.position - tapPos).distance;
      if (d < 620) _tryUpdate(poi.position, d);
    }

    if (widget.debugEnableContestArenaTeleport) {
      for (final arena in widget.world.contestArenas) {
        if (!widget.debugShowAllContestArenasOnMap && !arena.discovered) {
          continue;
        }
        final d = (arena.position - tapPos).distance;
        if (d < 760) _tryUpdate(arena.position, d);
      }
    }

    if (bestPos != null) widget.onTeleport(bestPos!);
  }

  void _handleLongPress(LongPressStartDetails details, double scale) {
    final tapWorld = Offset(
      details.localPosition.dx / scale,
      details.localPosition.dy / scale,
    );

    var closestDist = double.infinity;
    var closestIdx = -1;
    for (var i = 0; i < widget.markers.length; i++) {
      final d = (widget.markers[i].worldPos - tapWorld).distance;
      if (d < closestDist) {
        closestDist = d;
        closestIdx = i;
      }
    }

    if (closestIdx >= 0 && closestDist < 800) {
      final updated = List<MapMarker>.from(widget.markers)
        ..removeAt(closestIdx);
      widget.onMarkersChanged(updated);
      HapticFeedback.lightImpact();
    }
  }

  void _navigateToSelected() {
    if (_discoveredPlanets.isEmpty) return;
    widget.onNavigatePlanet(
      _discoveredPlanets[_planetIndex.clamp(0, _discoveredPlanets.length - 1)],
    );
  }

  @override
  Widget build(BuildContext context) {
    _refreshPlanets();

    if (_discoveredPlanets.isNotEmpty &&
        _planetIndex >= _discoveredPlanets.length) {
      _planetIndex = _discoveredPlanets.length - 1;
    }

    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: Column(
          children: [
            _Header(onClose: widget.onClose),
            _MarkerToolbar(
              markerMode: _markerMode,
              selectedColor: _selectedColor,
              hasMarkers: widget.markers.isNotEmpty,
              onToggleMode: () => setState(() => _markerMode = !_markerMode),
              onSelectColor: (i) => setState(() {
                _selectedColor = i;
                _markerMode = true;
              }),
              onClearAll: () => widget.onMarkersChanged([]),
            ),
            Expanded(
              child: Column(
                children: [
                  if (_discoveredPlanets.isNotEmpty)
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        child: _PlanetCarousel(
                          planets: _discoveredPlanets,
                          selectedIndex: _planetIndex,
                          spinCtrl: _spinCtrl,
                          onChanged: (i) {
                            setState(() => _planetIndex = i);
                            HapticFeedback.selectionClick();
                          },
                          onNavigate: _navigateToSelected,
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: _MapView(
                      world: widget.world,
                      game: widget.game,
                      markers: widget.markers,
                      transformCtrl: _transformCtrl,
                      onTapUp: _handleTapUp,
                      onLongPress: _handleLongPress,
                      showAllContestArenas:
                          widget.debugShowAllContestArenasOnMap,
                    ),
                  ),
                ],
              ),
            ),
            _Legend(
              markerMode: _markerMode,
              showContestTip: widget.debugEnableContestArenaTeleport,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.white70, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARKER TOOLBAR
// ─────────────────────────────────────────────────────────────────────────────

class _MarkerToolbar extends StatelessWidget {
  const _MarkerToolbar({
    required this.markerMode,
    required this.selectedColor,
    required this.hasMarkers,
    required this.onToggleMode,
    required this.onSelectColor,
    required this.onClearAll,
  });

  final bool markerMode;
  final int selectedColor;
  final bool hasMarkers;
  final VoidCallback onToggleMode;
  final ValueChanged<int> onSelectColor;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggleMode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: markerMode ? Colors.white24 : Colors.white10,
                borderRadius: BorderRadius.circular(8),
                border: markerMode
                    ? Border.all(
                        color: MapMarker.colors[selectedColor],
                        width: 1.5,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.push_pin,
                    color: markerMode
                        ? MapMarker.colors[selectedColor]
                        : Colors.white54,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    markerMode ? 'MARKING' : 'MARK',
                    style: TextStyle(
                      color: markerMode ? Colors.white : Colors.white54,
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
          for (var i = 0; i < 3; i++) ...[
            GestureDetector(
              onTap: () => onSelectColor(i),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: MapMarker.colors[i].withValues(
                    alpha: selectedColor == i && markerMode ? 0.9 : 0.35,
                  ),
                  shape: BoxShape.circle,
                  border: selectedColor == i && markerMode
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
              ),
            ),
            if (i < 2) const SizedBox(width: 6),
          ],
          const Spacer(),
          if (hasMarkers)
            GestureDetector(
              onTap: onClearAll,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLANET CAROUSEL
// ─────────────────────────────────────────────────────────────────────────────

class _PlanetCarousel extends StatefulWidget {
  const _PlanetCarousel({
    required this.planets,
    required this.selectedIndex,
    required this.spinCtrl,
    required this.onChanged,
    required this.onNavigate,
  });

  final List<CosmicPlanet> planets;
  final int selectedIndex;
  final AnimationController spinCtrl;
  final ValueChanged<int> onChanged;
  final VoidCallback onNavigate;

  @override
  State<_PlanetCarousel> createState() => _PlanetCarouselState();
}

class _PlanetCarouselState extends State<_PlanetCarousel> {
  late final PageController _ctrl;
  double _page = 0;

  static const double _centerSize = 125.0;
  static const double _sideSize = 55.0;
  static const double _rowHeight = 130.0;

  @override
  void initState() {
    super.initState();
    _page = widget.selectedIndex.toDouble();
    _ctrl = PageController(
      initialPage: widget.selectedIndex,
      viewportFraction: 0.34,
    )..addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_PlanetCarousel old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex && _ctrl.hasClients) {
      _ctrl.animateToPage(
        widget.selectedIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _ctrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_ctrl.hasClients) return;
    final p = _ctrl.page ?? _page;
    if ((p - _page).abs() < 0.001) return;
    setState(() => _page = p);
  }

  @override
  Widget build(BuildContext context) {
    final planets = widget.planets;
    if (planets.isEmpty) return const SizedBox.shrink();
    final selected = planets[widget.selectedIndex];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: PageView.builder(
            controller: _ctrl,
            itemCount: planets.length,
            onPageChanged: widget.onChanged,
            itemBuilder: (context, index) {
              final rawDist = (_page - index).abs().clamp(0.0, 1.0);
              final eased = Curves.easeOutCubic.transform(1.0 - rawDist);
              final isCenter = index == _page.round();

              final size = _sideSize + (_centerSize - _sideSize) * eased;
              final vertLift = (1.0 - eased) * 22.0;
              final opacity = 0.28 + eased * 0.72;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => isCenter
                    ? widget.onNavigate()
                    : _ctrl.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      ),
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, vertLift),
                    child: Opacity(
                      opacity: opacity,
                      child: AnimatedBuilder(
                        animation: widget.spinCtrl,
                        builder: (context, _) {
                          final spin = widget.spinCtrl.value * pi * 2;
                          final pulse = isCenter
                              ? 1.0 + 0.04 * sin(spin * 1.1)
                              : 1.0;
                          final drawSize = size * pulse;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: drawSize,
                                height: drawSize,
                                child: CustomPaint(
                                  painter: _PlanetPreviewPainter(
                                    planet: planets[index],
                                    spin: spin,
                                    highlighted: isCenter,
                                    explicitRadius: drawSize * 0.38,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                planetName(
                                  planets[index].element,
                                ).toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isCenter
                                      ? Colors.white
                                      : Colors.white38,
                                  fontSize: isCenter ? 11.0 : 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        _PipRow(count: planets.length, page: _page, color: selected.color),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: widget.onNavigate,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: selected.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected.color.withValues(alpha: 0.5),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.navigation_rounded, color: selected.color, size: 13),
                const SizedBox(width: 7),
                Text(
                  'NAVIGATE TO PLANET',
                  style: TextStyle(
                    color: selected.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Pip row ──────────────────────────────────────────────────────────────────

class _PipRow extends StatelessWidget {
  const _PipRow({required this.count, required this.page, required this.color});

  final int count;
  final double page;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (count > 17) {
      return Text(
        'Planet ${page.round() + 1} of $count',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final t = (1.0 - (page - i).abs()).clamp(0.0, 1.0);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 6.0 + t * 16.0,
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.28 + t * 0.72),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAP VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _MapView extends StatelessWidget {
  const _MapView({
    required this.world,
    required this.game,
    required this.markers,
    required this.transformCtrl,
    required this.onTapUp,
    required this.onLongPress,
    required this.showAllContestArenas,
  });

  final CosmicWorld world;
  final CosmicGame game;
  final List<MapMarker> markers;
  final TransformationController transformCtrl;
  final void Function(TapUpDetails, double) onTapUp;
  final void Function(LongPressStartDetails, double) onLongPress;
  final bool showAllContestArenas;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fitSize = min(constraints.maxWidth, constraints.maxHeight);
          final scale =
              fitSize / max(world.worldSize.width, world.worldSize.height);

          return Center(
            child: SizedBox(
              width: fitSize,
              height: fitSize,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  transformationController: transformCtrl,
                  minScale: 1.0,
                  maxScale: 8.0,
                  boundaryMargin: EdgeInsets.zero,
                  child: GestureDetector(
                    onTapUp: (d) => onTapUp(d, scale),
                    onLongPressStart: (d) => onLongPress(d, scale),
                    child: CustomPaint(
                      size: Size(fitSize, fitSize),
                      painter: _MiniMapPainter(
                        world: world,
                        game: game,
                        scale: scale,
                        shipPos: game.ship.pos,
                        revealedCellCount: game.revealedCells.length,
                        discoveredPlanetCount: world.planets
                            .where((p) => p.discovered)
                            .length,
                        showAllContestArenasOnMap: showAllContestArenas,
                        markers: markers,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEGEND
// ─────────────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend({required this.markerMode, required this.showContestTip});
  final bool markerMode;
  final bool showContestTip;

  @override
  Widget build(BuildContext context) {
    final hint = markerMode
        ? 'Tap to place marker  •  Long-press to remove'
        : showContestTip
        ? 'Tap planet/market/contest to teleport  •  Pinch to zoom  •  Drag to pan'
        : 'Tap planet/market to teleport  •  Pinch to zoom  •  Drag to pan';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hint,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tip: Long-press the map icon (or mini-map) to toggle it.',
            style: TextStyle(
              color: Colors.amber.withValues(alpha: 0.75),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLANET PREVIEW PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class _PlanetPreviewPainter extends CustomPainter {
  const _PlanetPreviewPainter({
    required this.planet,
    required this.spin,
    this.highlighted = false,
    this.explicitRadius,
  });

  final CosmicPlanet planet;
  final double spin;
  final bool highlighted;
  final double? explicitRadius;

  // Shared helper — draws a sphere with radial gradient shading.
  static void _drawSphere(
    Canvas c,
    Offset p,
    double r,
    Color color, {
    double highlight = 0.4,
    double shadow = 0.6,
  }) {
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(color, Colors.white, highlight)!,
            color,
            Color.lerp(color, Colors.black, shadow)!,
          ],
          stops: const [0.0, 0.55, 1.0],
          center: const Alignment(-0.35, -0.35),
          radius: 1.05,
        ).createShader(Rect.fromCircle(center: p, radius: r)),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = explicitRadius ?? min(size.width, size.height) * 0.42;
    final col = planet.color;
    final glowA = highlighted ? 0.11 : 0.05;

    // Ambient glow
    canvas.drawCircle(
      c,
      r * (highlighted ? 1.55 : 1.3),
      Paint()
        ..color = col.withValues(alpha: glowA)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, highlighted ? 5 : 3),
    );

    switch (planet.element) {
      case 'Fire':
        for (var i = 0; i < 6; i++) {
          final a = spin * 0.8 + i * pi / 3;
          canvas.drawCircle(
            Offset(c.dx + cos(a) * r * 1.2, c.dy + sin(a) * r * 1.2),
            r * (0.2 + 0.08 * sin(spin * 2 + i)),
            Paint()
              ..color = const Color(0xFFFF6D00).withValues(alpha: 0.38)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
        _drawSphere(canvas, c, r, col);

      case 'Lava':
        _drawSphere(canvas, c, r, const Color(0xFF3E2723), highlight: 0.2);
        final crack = Paint()
          ..color = const Color(0xFFFFAB40).withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.5;
        for (var i = 0; i < 4; i++) {
          final a = i * (pi * 2 / 4) + spin * 0.2;
          canvas.drawLine(
            Offset(c.dx + cos(a) * r * 0.2, c.dy + sin(a) * r * 0.2),
            Offset(
              c.dx + cos(a + 0.5) * r * 0.82,
              c.dy + sin(a + 0.5) * r * 0.82,
            ),
            crack,
          );
        }

      case 'Lightning':
        _drawSphere(canvas, c, r, const Color(0xFF1A237E), highlight: 0.5);
        canvas.drawCircle(
          c,
          r * (1.2 + 0.08 * sin(spin * 2.0)),
          Paint()
            ..color = const Color(0xFF90CAF9).withValues(alpha: 0.28)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        for (var i = 0; i < 7; i++) {
          final a = spin * (0.9 + i * 0.08) + i * (pi * 2 / 7);
          canvas.drawCircle(
            Offset(c.dx + cos(a) * r * 1.3, c.dy + sin(a) * r * 1.3),
            r * 0.06,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.72)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }

      case 'Water':
        _drawSphere(canvas, c, r, const Color(0xFF0D47A1), highlight: 0.35);
        canvas.save();
        canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
        for (var i = 0; i < 5; i++) {
          final y = c.dy - r + (2 * r) * (i + 0.5) / 5;
          final p = Path()..moveTo(c.dx - r - 8, y);
          for (var x = -r - 8.0; x <= r + 8; x += 4) {
            p.lineTo(
              c.dx + x,
              y + sin((x / r) * pi * 2 + spin * 1.1 + i) * r * 0.07,
            );
          }
          p
            ..lineTo(c.dx + r + 8, c.dy + r + 8)
            ..lineTo(c.dx - r - 8, c.dy + r + 8)
            ..close();
          canvas.drawPath(
            p,
            Paint()..color = Colors.white.withValues(alpha: 0.08 + i * 0.03),
          );
        }
        canvas.restore();

      case 'Ice':
        _drawSphere(canvas, c, r, const Color(0xFFB3E5FC), shadow: 0.45);
        for (var i = 0; i < 5; i++) {
          final a = i * 1.2 + spin * 0.07;
          canvas.drawLine(
            Offset(c.dx + cos(a) * r * 0.15, c.dy + sin(a) * r * 0.15),
            Offset(
              c.dx + cos(a + 0.7) * r * 0.82,
              c.dy + sin(a + 0.7) * r * 0.82,
            ),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.45)
              ..strokeWidth = 1.0,
          );
        }

      case 'Steam':
        _drawSphere(canvas, c, r, const Color(0xFF607D8B), highlight: 0.35);
        for (var i = 0; i < 7; i++) {
          final a = i * 0.9 + spin * 0.6;
          canvas.drawCircle(
            Offset(c.dx + cos(a) * r * 1.2, c.dy + sin(a) * r * 1.0),
            r * 0.2,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.16)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
        }

      case 'Earth':
        _drawSphere(canvas, c, r, const Color(0xFF5D4037), highlight: 0.28);
        final rng = Random(planet.element.hashCode);
        for (var i = 0; i < 6; i++) {
          final a = rng.nextDouble() * pi * 2;
          final d = r * (0.2 + rng.nextDouble() * 0.55);
          canvas.drawCircle(
            Offset(c.dx + cos(a) * d, c.dy + sin(a) * d),
            r * (0.1 + rng.nextDouble() * 0.12),
            Paint()..color = const Color(0xFF8BC34A).withValues(alpha: 0.5),
          );
        }

      case 'Mud':
        _drawSphere(canvas, c, r, const Color(0xFF4E342E), highlight: 0.18);
        for (var i = 0; i < 7; i++) {
          final a = i * (pi * 2 / 7) + spin * 0.2;
          canvas.drawCircle(
            Offset(c.dx + cos(a) * r * 0.58, c.dy + sin(a) * r * 0.58),
            r * 0.07,
            Paint()..color = Colors.black.withValues(alpha: 0.28),
          );
        }

      case 'Dust':
        _drawSphere(canvas, c, r, col, shadow: 0.42);
        canvas
          ..save()
          ..translate(c.dx, c.dy)
          ..scale(1.0, 0.35)
          ..drawCircle(
            Offset.zero,
            r * 1.9,
            Paint()
              ..color = col.withValues(alpha: 0.4)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          )
          ..restore();

      case 'Crystal':
        _drawSphere(canvas, c, r, col, highlight: 0.62, shadow: 0.3);
        for (var i = 0; i < 6; i++) {
          final a = i * (pi * 2 / 6) + spin * 0.12;
          final p1 = Offset(c.dx + cos(a) * r * 0.2, c.dy + sin(a) * r * 0.2);
          final p2 = Offset(
            c.dx + cos(a + 0.22) * r * 0.74,
            c.dy + sin(a + 0.22) * r * 0.74,
          );
          final p3 = Offset(
            c.dx + cos(a - 0.22) * r * 0.74,
            c.dy + sin(a - 0.22) * r * 0.74,
          );
          canvas.drawPath(
            Path()
              ..moveTo(p1.dx, p1.dy)
              ..lineTo(p2.dx, p2.dy)
              ..lineTo(p3.dx, p3.dy)
              ..close(),
            Paint()..color = Colors.white.withValues(alpha: 0.18),
          );
        }

      case 'Air':
        _drawSphere(canvas, c, r, col, highlight: 0.55, shadow: 0.2);
        for (var i = 0; i < 4; i++) {
          final y = c.dy - r * 0.55 + i * r * 0.38;
          final p = Path()..moveTo(c.dx - r, y);
          for (var s = 0; s <= 18; s++) {
            final fx = s / 18;
            p.lineTo(
              c.dx - r + fx * r * 2,
              y + sin(fx * pi * 3 + spin * 1.2 + i) * r * 0.07,
            );
          }
          canvas.drawPath(
            p,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.2)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
        }

      case 'Plant':
        _drawSphere(canvas, c, r, const Color(0xFF33691E), highlight: 0.25);
        for (var i = 0; i < 5; i++) {
          final a = i * (pi * 2 / 5) + spin * 0.2;
          canvas.drawLine(
            Offset(c.dx + cos(a) * r * 0.92, c.dy + sin(a) * r * 0.92),
            Offset(
              c.dx + cos(a + 0.4) * r * 1.25,
              c.dy + sin(a + 0.4) * r * 1.25,
            ),
            Paint()
              ..color = const Color(0xFF66BB6A).withValues(alpha: 0.7)
              ..strokeWidth = 1.2,
          );
        }

      case 'Poison':
        _drawSphere(canvas, c, r, col, highlight: 0.22);
        for (var i = 0; i < 6; i++) {
          final a = i * 1.05 + spin * 0.35;
          canvas.drawCircle(
            Offset(c.dx + cos(a) * r * 1.25, c.dy + sin(a) * r * 1.05),
            r * 0.22,
            Paint()
              ..color = const Color(0xFFBA68C8).withValues(alpha: 0.22)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
        }

      case 'Spirit':
        _drawSphere(canvas, c, r, const Color(0xFF303F9F), highlight: 0.42);
        for (var i = 0; i < 5; i++) {
          final a = spin * 0.7 + i * (pi * 2 / 5);
          canvas.drawCircle(
            Offset(c.dx + cos(a) * r * 1.15, c.dy + sin(a) * r * 1.15),
            r * 0.09,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.65)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }

      case 'Dark':
        _drawSphere(
          canvas,
          c,
          r,
          const Color(0xFF1A0930),
          highlight: 0.12,
          shadow: 0.72,
        );
        canvas.drawCircle(
          c,
          r * 1.32,
          Paint()
            ..color = const Color(0xFF6A0DAD).withValues(alpha: 0.28)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );

      case 'Light':
        _drawSphere(
          canvas,
          c,
          r,
          const Color(0xFFFFF8E1),
          highlight: 0.7,
          shadow: 0.22,
        );
        for (var i = 0; i < 8; i++) {
          final a = i * (pi * 2 / 8) + spin * 0.08;
          canvas.drawLine(
            Offset(c.dx + cos(a) * r * 1.05, c.dy + sin(a) * r * 1.05),
            Offset(c.dx + cos(a) * r * 1.42, c.dy + sin(a) * r * 1.42),
            Paint()
              ..color = const Color(0xFFFFECB3).withValues(alpha: 0.55)
              ..strokeWidth = 1.2,
          );
        }

      case 'Blood':
        _drawSphere(canvas, c, r, const Color(0xFF8B0000), highlight: 0.25);
        canvas.drawCircle(
          c,
          r * (1.2 + 0.06 * sin(spin * 1.5)),
          Paint()
            ..color = const Color(0xFFD32F2F).withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );

      default:
        _drawSphere(canvas, c, r, col);
    }

    if (highlighted) {
      canvas.drawCircle(
        c,
        r * 1.07,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlanetPreviewPainter old) =>
      old.planet.element != planet.element ||
      old.spin != spin ||
      old.highlighted != highlighted ||
      old.explicitRadius != explicitRadius;
}

// ─────────────────────────────────────────────────────────────────────────────
// MINIMAP PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter({
    required this.world,
    required this.game,
    required this.scale,
    required this.shipPos,
    required this.revealedCellCount,
    required this.discoveredPlanetCount,
    this.showAllContestArenasOnMap = false,
    this.markers = const [],
  });

  final CosmicWorld world;
  final CosmicGame game;
  final double scale;
  final Offset shipPos;
  final int revealedCellCount;
  final int discoveredPlanetCount;
  final bool showAllContestArenasOnMap;
  final List<MapMarker> markers;

  // ── helpers ────────────────────────────────────────────────────────────────

  static TextPainter _tp(
    String text,
    TextStyle style, {
    TextAlign align = TextAlign.left,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
  }

  static Paint _glowPaint(Color color, double alpha, double blur) => Paint()
    ..color = color.withValues(alpha: alpha)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

  void _paintLabel(
    Canvas canvas,
    String text,
    Color color,
    double alpha,
    Offset pos,
    double dotR, {
    double fontSize = 6,
  }) {
    final tp = _tp(
      text,
      TextStyle(
        color: color.withValues(alpha: alpha),
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + dotR + 2));
  }

  void _paintHexMarker(
    Canvas canvas,
    Offset pos,
    Color color,
    double alpha,
    bool discovered,
  ) {
    final hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final a = pi / 3 * i - pi / 6;
      final pt = Offset(pos.dx + 5.0 * cos(a), pos.dy + 5.0 * sin(a));
      if (i == 0)
        hexPath.moveTo(pt.dx, pt.dy);
      else
        hexPath.lineTo(pt.dx, pt.dy);
    }
    hexPath.close();
    canvas
      ..drawPath(hexPath, Paint()..color = color.withValues(alpha: alpha))
      ..drawPath(
        hexPath,
        Paint()
          ..color = color.withValues(alpha: discovered ? 1.0 : 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
  }

  // ── paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF060820),
    );

    // Revealed fog cells
    final fogCellScaled = CosmicGame.fogCellSize * scale;
    final gridW = (world.worldSize.width / CosmicGame.fogCellSize).ceil();
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
      final pos = Offset(px, py);

      canvas
        ..drawCircle(pos, pr * 3, _glowPaint(planet.color, 0.2, 6))
        ..drawCircle(pos, pr, Paint()..color = planet.color);

      _paintLabel(
        canvas,
        planetName(planet.element),
        planet.color,
        0.8,
        pos,
        pr,
      );
    }

    // Asteroid belt
    final belt = game.asteroidBelt;
    canvas.drawCircle(
      Offset(belt.center.dx * scale, belt.center.dy * scale),
      belt.innerRadius * scale,
      Paint()
        ..color = const Color(0xFF5D4037).withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (belt.outerRadius - belt.innerRadius) * scale,
    );

    // Home planet
    if (game.homePlanet case final hp?) {
      final hx = hp.position.dx * scale;
      final hy = hp.position.dy * scale;
      final hr = max(4.0, hp.visualRadius * scale);
      final hPos = Offset(hx, hy);

      canvas
        ..drawCircle(hPos, hr * 3, _glowPaint(const Color(0xFF00E5FF), 0.3, 6))
        ..drawCircle(hPos, hr, Paint()..color = hp.blendedColor);

      _paintLabel(
        canvas,
        'HOME',
        const Color(0xFF00E5FF),
        1.0,
        hPos,
        hr,
        fontSize: 8,
      );
    }

    // Map markers
    for (final marker in markers) {
      final mPos = marker.worldPos * scale;
      canvas
        ..drawCircle(mPos, 8, _glowPaint(marker.color, 0.35, 5))
        ..drawCircle(mPos, 4, Paint()..color = marker.color)
        ..drawCircle(
          mPos,
          4,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
    }

    // Galaxy whirls
    for (final whirl in game.galaxyWhirls) {
      if (whirl.state == WhirlState.completed) continue;
      final wPos = whirl.position * scale;
      final wColor = elementColor(whirl.element);

      canvas.drawCircle(wPos, 10, _glowPaint(wColor, 0.3, 8));

      final spiralPaint = Paint()
        ..color = wColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (var i = 0; i < 3; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: wPos, radius: 5),
          i * (pi * 2 / 3),
          pi * 0.7,
          false,
          spiralPaint,
        );
      }
      canvas.drawCircle(wPos, 2, Paint()..color = wColor);

      _paintLabel(
        canvas,
        'Lv${whirl.level} ${whirl.hordeTypeName}',
        wColor,
        0.7,
        wPos,
        8,
      );
    }

    // Nearest waiting boss lair
    BossLair? nearestLair;
    double nearestDist = double.infinity;
    for (final lair in game.bossLairs) {
      if (lair.state != BossLairState.waiting) continue;
      final d = (lair.position - game.ship.pos).distance;
      if (d < nearestDist) {
        nearestDist = d;
        nearestLair = lair;
      }
    }
    if (nearestLair != null) {
      final lair = nearestLair;
      final lPos = lair.position * scale;
      final bColor = elementColor(lair.template.element);

      canvas.drawCircle(
        lPos,
        12,
        _glowPaint(const Color(0xFFFF1744), 0.35, 10),
      );

      final diamond = Path()
        ..moveTo(lPos.dx, lPos.dy - 6)
        ..lineTo(lPos.dx + 5, lPos.dy)
        ..lineTo(lPos.dx, lPos.dy + 6)
        ..lineTo(lPos.dx - 5, lPos.dy)
        ..close();
      canvas
        ..drawPath(diamond, Paint()..color = bColor.withValues(alpha: 0.7))
        ..drawPath(
          diamond,
          Paint()
            ..color = const Color(0xFFFF1744).withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );

      final tag = switch (bossTypeForLevel(lair.level)) {
        BossType.charger => '⚡',
        BossType.gunner => '🔫',
        BossType.warden => '👑',
      };
      _paintLabel(
        canvas,
        '$tag Lv${lair.level} ${lair.template.name.toUpperCase()}',
        const Color(0xFFFF5252),
        1.0,
        lPos,
        9,
      );
    }

    // Space POIs
    for (final poi in game.spacePOIs) {
      if (poi.type == POIType.comet || poi.type == POIType.stardustScanner)
        continue;

      final isMarket =
          poi.type == POIType.harvesterMarket ||
          poi.type == POIType.riftKeyMarket ||
          poi.type == POIType.cosmicMarket;
      if (!poi.discovered && !isMarket) continue;

      final poiPos = poi.position * scale;
      late Color poiColor;
      late String poiLabel;
      late double poiDotR;

      switch (poi.type) {
        case POIType.nebula:
          poiColor = elementColor(poi.element);
          poiLabel = '${poi.element.toUpperCase()} NEBULA';
          poiDotR = 4.0;
          canvas
            ..drawCircle(
              poiPos,
              10,
              _glowPaint(poiColor, poi.interacted ? 0.12 : 0.25, 8),
            )
            ..drawCircle(
              poiPos,
              poiDotR,
              Paint()
                ..color = poiColor.withValues(
                  alpha: poi.interacted ? 0.4 : 0.8,
                ),
            );

        case POIType.derelict:
          poiColor = const Color(0xFF78909C);
          poiLabel = 'DERELICT';
          poiDotR = 3.0;
          canvas.drawRect(
            Rect.fromCenter(center: poiPos, width: 6, height: 6),
            Paint()
              ..color = poiColor.withValues(alpha: poi.interacted ? 0.35 : 0.7),
          );

        case POIType.warpAnomaly:
          poiColor = const Color(0xFFB388FF);
          poiLabel = 'ANOMALY';
          poiDotR = 4.0;
          canvas
            ..drawCircle(
              poiPos,
              poiDotR,
              Paint()
                ..color = poiColor.withValues(alpha: poi.interacted ? 0.3 : 0.6)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            )
            ..drawCircle(
              poiPos,
              2,
              Paint()
                ..color = poiColor.withValues(
                  alpha: poi.interacted ? 0.3 : 0.7,
                ),
            );

        case POIType.harvesterMarket:
          poiColor = const Color(0xFFFFB300);
          poiLabel = 'HARVESTER SHOP';
          poiDotR = 5.0;
          _paintHexMarker(
            canvas,
            poiPos,
            poiColor,
            poi.discovered ? 0.7 : 0.25,
            poi.discovered,
          );

        case POIType.riftKeyMarket:
          poiColor = const Color(0xFF7C4DFF);
          poiLabel = 'RIFT KEY SHOP';
          poiDotR = 5.0;
          _paintHexMarker(
            canvas,
            poiPos,
            poiColor,
            poi.discovered ? 0.7 : 0.25,
            poi.discovered,
          );

        case POIType.cosmicMarket:
          poiColor = const Color(0xFF00E5FF);
          poiLabel = 'COSMIC MARKET';
          poiDotR = 5.0;
          _paintHexMarker(
            canvas,
            poiPos,
            poiColor,
            poi.discovered ? 0.7 : 0.25,
            poi.discovered,
          );

        default:
          continue;
      }

      if (poi.discovered || !isMarket) {
        _paintLabel(
          canvas,
          poiLabel,
          poiColor,
          poi.interacted ? 0.35 : 0.65,
          poiPos,
          poiDotR,
        );
      } else {
        _paintLabel(canvas, '?', poiColor, 0.4, poiPos, poiDotR, fontSize: 7);
      }
    }

    // Prismatic field
    if (game.prismaticField.discovered && !game.prismaticField.rewardClaimed) {
      final pf = game.prismaticField;
      final pfPos = pf.position * scale;
      final pfr = max(6.0, pf.radius * scale);
      const pfColor = Color(0xFFFF00CC);

      canvas
        ..drawCircle(pfPos, pfr, _glowPaint(pfColor, 0.15, pfr * 0.5))
        ..drawCircle(
          pfPos,
          pfr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..color = pfColor.withValues(alpha: 0.6),
        )
        ..drawCircle(
          pfPos,
          3,
          Paint()..color = const Color(0xFFFFDD00).withValues(alpha: 0.8),
        );

      _paintLabel(canvas, 'PRISMATIC AURORA', pfColor, 0.7, pfPos, pfr);
    }

    // Elemental Nexus
    final nx = world.elementalNexus;
    if (nx.discovered) {
      final nxPos = nx.position * scale;
      const nexusColor = Color(0xFFB388FF);

      canvas
        ..drawCircle(nxPos, 14, _glowPaint(const Color(0xFF7C4DFF), 0.3, 10))
        ..drawCircle(nxPos, 6, Paint()..color = const Color(0xFF0A0A0A))
        ..drawCircle(
          nxPos,
          7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..color = nexusColor.withValues(alpha: 0.7),
        );

      const dotColors = [
        Color(0xFFFF6D00),
        Color(0xFF2196F3),
        Color(0xFF4CAF50),
        Color(0xFF90CAF9),
      ];
      for (var i = 0; i < 4; i++) {
        final a = i * pi / 2;
        canvas.drawCircle(
          Offset(nxPos.dx + 10 * cos(a), nxPos.dy + 10 * sin(a)),
          2,
          Paint()..color = dotColors[i].withValues(alpha: 0.8),
        );
      }
      _paintLabel(canvas, 'ELEMENTAL NEXUS', nexusColor, 0.7, nxPos, 12);
    }

    // Battle Ring
    final br = world.battleRing;
    if (br.discovered) {
      final brPos = br.position * scale;
      const brColor = Color(0xFFFFD740);

      canvas.drawCircle(brPos, 12, _glowPaint(brColor, 0.25, 8));

      final octPath = Path();
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4 - pi / 8;
        final pt = Offset(brPos.dx + cos(a) * 8, brPos.dy + sin(a) * 8);
        if (i == 0)
          octPath.moveTo(pt.dx, pt.dy);
        else
          octPath.lineTo(pt.dx, pt.dy);
      }
      octPath.close();
      canvas
        ..drawPath(
          octPath,
          Paint()
            ..color = brColor.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        )
        ..drawCircle(
          brPos,
          2.5,
          Paint()..color = brColor.withValues(alpha: 0.9),
        );

      _paintLabel(
        canvas,
        br.isCompleted ? 'BATTLE ARENA' : 'BATTLE RING',
        brColor,
        0.7,
        brPos,
        12,
      );
    }

    // Contest arenas
    for (final arena in world.contestArenas) {
      if (!showAllContestArenasOnMap && !arena.discovered) continue;
      final aPos = arena.position * scale;
      final aColor = arena.trait.color;

      canvas
        ..drawCircle(aPos, 11, _glowPaint(aColor, 0.22, 7))
        ..drawCircle(
          aPos,
          7.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = aColor.withValues(alpha: 0.9),
        )
        ..drawCircle(
          aPos,
          2.2,
          Paint()..color = aColor.withValues(alpha: 0.92),
        );

      _paintLabel(
        canvas,
        '${arena.trait.label.toUpperCase()} CONTEST',
        aColor,
        0.78,
        aPos,
        12,
      );
    }

    // Blood Ring
    final ring = world.bloodRing;
    if (ring.discovered) {
      final ringPos = ring.position * scale;
      const ringColor = Color(0xFFFF8A80);

      canvas
        ..drawCircle(ringPos, 12, _glowPaint(const Color(0xFFB71C1C), 0.26, 8))
        ..drawCircle(
          ringPos,
          8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = ringColor.withValues(alpha: 0.9),
        )
        ..drawCircle(
          ringPos,
          2.5,
          Paint()..color = const Color(0xFFFFCDD2).withValues(alpha: 0.85),
        );

      _paintLabel(
        canvas,
        ring.ritualCompleted ? 'BLOOD PORTAL' : 'BLOOD RING',
        ringColor,
        0.7,
        ringPos,
        12,
      );
    }

    // Ship
    final shipScaled = shipPos * scale;
    canvas
      ..drawCircle(shipScaled, 5, _glowPaint(const Color(0xFF00E5FF), 1.0, 4))
      ..drawCircle(shipScaled, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter old) =>
      scale != old.scale ||
      revealedCellCount != old.revealedCellCount ||
      discoveredPlanetCount != old.discoveredPlanetCount ||
      showAllContestArenasOnMap != old.showAllContestArenasOnMap ||
      shipPos != old.shipPos ||
      !identical(markers, old.markers);
}
