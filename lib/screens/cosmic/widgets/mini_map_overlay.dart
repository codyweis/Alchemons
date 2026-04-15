import 'dart:math';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
    required this.hasHomePlanet,
    required this.onTeleport,
    required this.onNavigatePlanet,
    required this.onGoHome,
    required this.onClose,
    required this.onMarkersChanged,
    this.debugShowAllContestArenasOnMap = false,
    this.debugEnableContestArenaTeleport = false,
  });

  final CosmicWorld world;
  final CosmicGame game;
  final FactionTheme theme;
  final List<MapMarker> markers;
  final bool hasHomePlanet;
  final void Function(Offset worldPos) onTeleport;
  final void Function(CosmicPlanet planet) onNavigatePlanet;
  final VoidCallback onGoHome;
  final VoidCallback onClose;
  final void Function(List<MapMarker> markers) onMarkersChanged;
  final bool debugShowAllContestArenasOnMap;
  final bool debugEnableContestArenaTeleport;

  @override
  State<MiniMapOverlay> createState() => MiniMapOverlayState();
}

class MiniMapOverlayState extends State<MiniMapOverlay> {
  final TransformationController _transformCtrl = TransformationController();
  final ScrollController _planetScrollCtrl = ScrollController();
  int _selectedColor = 0;
  bool _markerMode = false;
  bool _showMarkerColors = false;
  int _planetIndex = 0;
  bool _didPrimeMapTransform = false;
  _MiniMapTravelPromptData? _travelPrompt;
  late List<CosmicPlanet> _discoveredPlanets;

  void _refreshPlanets() {
    _discoveredPlanets =
        widget.world.planets.where((p) => p.discovered).toList()..sort(
          (a, b) => planetName(a.element).compareTo(planetName(b.element)),
        );
  }

  void _runAfterBuild(VoidCallback action) {
    final phase = WidgetsBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        action();
      });
      return;
    }
    action();
  }

  @override
  void initState() {
    super.initState();
    _refreshPlanets();
  }

  @override
  void didUpdateWidget(MiniMapOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshPlanets();
  }

  @override
  void dispose() {
    _planetScrollCtrl.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  Offset _worldFromViewport(Offset viewportPosition, double scale) {
    final scenePosition = _transformCtrl.toScene(viewportPosition);
    return Offset(scenePosition.dx / scale, scenePosition.dy / scale);
  }

  void _primeMapTransform({
    required double viewportSize,
    required double scale,
  }) {
    if (_didPrimeMapTransform || viewportSize <= 0 || scale <= 0) return;
    _didPrimeMapTransform = true;

    const initialZoom = 1.25;
    final shipScene = widget.game.ship.pos * scale;
    final minTranslate = viewportSize - (viewportSize * initialZoom);
    final tx = (viewportSize / 2 - shipScene.dx * initialZoom).clamp(
      minTranslate,
      0.0,
    );
    final ty = (viewportSize / 2 - shipScene.dy * initialZoom).clamp(
      minTranslate,
      0.0,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _transformCtrl.value = Matrix4.identity()
        ..translateByDouble(tx, ty, 0, 1)
        ..scaleByDouble(initialZoom, initialZoom, 1, 1);
    });
  }

  void _handleTapUp(TapUpDetails details, double scale) {
    final tapWorld = _worldFromViewport(details.localPosition, scale);
    final wx = tapWorld.dx;
    final wy = tapWorld.dy;

    if (_markerMode) {
      HapticFeedback.selectionClick();
      setState(() => _travelPrompt = null);
      widget.onMarkersChanged([
        ...widget.markers,
        MapMarker(worldPos: Offset(wx, wy), colorIndex: _selectedColor),
      ]);
      return;
    }

    final tapPos = Offset(wx, wy);
    final bestTarget = _bestTravelPromptAt(tapPos);
    setState(() => _travelPrompt = bestTarget);
  }

  void _handleTapDown(TapDownDetails details, double scale) {
    if (_markerMode) return;
    final tapWorld = _worldFromViewport(details.localPosition, scale);
    if (_bestTravelPromptAt(tapWorld) != null) {
      HapticFeedback.selectionClick();
    }
  }

  _MiniMapTravelPromptData? _bestTravelPromptAt(Offset tapPos) {
    _MiniMapTravelPromptData? bestTarget;
    double bestDist = double.infinity;

    void tryUpdate(_MiniMapTravelPromptData target, double dist) {
      if (dist < bestDist) {
        bestDist = dist;
        bestTarget = target;
      }
    }

    for (final p in widget.world.planets) {
      if (!p.discovered) continue;
      final d = (p.position - tapPos).distance;
      final hitRadius = max(p.radius * 9.0, 980.0);
      if (d < hitRadius) {
        tryUpdate(
          _MiniMapTravelPromptData(
            title: 'TRAVEL TO ${planetName(p.element).toUpperCase()}',
            subtitle: 'Planet route',
            accent: p.color,
            icon: Icons.public_rounded,
            actionLabel: 'TRAVEL',
            onConfirm: () => _runAfterBuild(() => widget.onNavigatePlanet(p)),
          ),
          d,
        );
      }
    }

    if (widget.game.homePlanet case final hp?) {
      final d = (hp.position - tapPos).distance;
      final hitRadius = max(hp.visualRadius * 9.0, 1080.0);
      if (d < hitRadius) {
        tryUpdate(
          _MiniMapTravelPromptData(
            title: 'TRAVEL TO HOME BASE',
            subtitle: 'Return home',
            accent: hp.blendedColor,
            icon: Icons.home_rounded,
            actionLabel: 'TRAVEL',
            onConfirm: () => _runAfterBuild(widget.onGoHome),
          ),
          d,
        );
      }
    }

    for (final poi in widget.game.spacePOIs) {
      if (!poi.discovered && poi.type != POIType.survivalPortal) continue;
      if (poi.type == POIType.survivalPortal) {
        final d = (poi.position - tapPos).distance;
        if (d < 920) {
          tryUpdate(
            _MiniMapTravelPromptData(
              title: poi.discovered
                  ? 'TRAVEL TO SURVIVAL PORTAL'
                  : 'UNKNOWN SIGNAL',
              subtitle: poi.discovered
                  ? 'Survival game mode'
                  : 'Signal origin unknown',
              accent: _poiColor(poi.type),
              icon: _poiIcon(poi.type),
              actionLabel: poi.discovered ? 'TRAVEL' : null,
              onConfirm: poi.discovered
                  ? () => _runAfterBuild(() => widget.onTeleport(poi.position))
                  : null,
            ),
            d,
          );
        }
        continue;
      }
      if (poi.type != POIType.harvesterMarket &&
          poi.type != POIType.riftKeyMarket &&
          poi.type != POIType.cosmicMarket &&
          poi.type != POIType.goldConversion) {
        final d = (poi.position - tapPos).distance;
        if (d < 920) {
          tryUpdate(
            _MiniMapTravelPromptData(
              title: _poiLabel(poi.type),
              subtitle: 'Space landmark',
              accent: _poiColor(poi.type),
              icon: _poiIcon(poi.type),
            ),
            d,
          );
        }
        continue;
      }
      final d = (poi.position - tapPos).distance;
      if (d < 920) {
        tryUpdate(
          _MiniMapTravelPromptData(
            title: 'TRAVEL TO ${_poiLabel(poi.type)}',
            subtitle: 'Space destination',
            accent: _poiColor(poi.type),
            icon: Icons.storefront_rounded,
            actionLabel: 'TRAVEL',
            onConfirm: () =>
                _runAfterBuild(() => widget.onTeleport(poi.position)),
          ),
          d,
        );
      }
    }

    for (final arena in widget.world.contestArenas) {
      if (!widget.debugShowAllContestArenasOnMap && !arena.discovered) {
        continue;
      }
      final d = (arena.position - tapPos).distance;
      if (d < 1080) {
        tryUpdate(
          _MiniMapTravelPromptData(
            title: widget.debugEnableContestArenaTeleport
                ? 'TRAVEL TO ${arena.trait.arenaLabel.toUpperCase()}'
                : arena.trait.arenaLabel.toUpperCase(),
            subtitle: 'Contest arena',
            accent: arena.trait.color,
            icon: Icons.emoji_events_rounded,
            actionLabel: widget.debugEnableContestArenaTeleport
                ? 'TRAVEL'
                : null,
            onConfirm: widget.debugEnableContestArenaTeleport
                ? () => _runAfterBuild(() => widget.onTeleport(arena.position))
                : null,
          ),
          d,
        );
      }
    }

    for (final whirl in widget.game.galaxyWhirls) {
      if (whirl.state == WhirlState.completed) continue;
      final d = (whirl.position - tapPos).distance;
      if (d < 980) {
        tryUpdate(
          _MiniMapTravelPromptData(
            title: 'LV ${whirl.level} ${whirl.hordeTypeName.toUpperCase()}',
            subtitle: 'Galaxy whirl',
            accent: elementColor(whirl.element),
            icon: Icons.cyclone_rounded,
          ),
          d,
        );
      }
    }

    for (final lair in widget.game.bossLairs) {
      if (lair.state != BossLairState.waiting) continue;
      final d = (lair.position - tapPos).distance;
      if (d < 1100) {
        tryUpdate(
          _MiniMapTravelPromptData(
            title: lair.template.name.toUpperCase(),
            subtitle: 'Boss lair',
            accent: elementColor(lair.template.element),
            icon: Icons.warning_amber_rounded,
          ),
          d,
        );
      }
    }

    final pf = widget.game.prismaticField;
    if (pf.discovered) {
      final d = (pf.position - tapPos).distance;
      if (d < max(pf.radius * 2.2, 1200.0)) {
        tryUpdate(
          const _MiniMapTravelPromptData(
            title: 'PRISMATIC AURORA',
            subtitle: 'Ancient anomaly',
            accent: Color(0xFFFF00CC),
            icon: Icons.auto_awesome_rounded,
          ),
          d,
        );
      }
    }

    final nx = widget.world.elementalNexus;
    if (nx.discovered) {
      final d = (nx.position - tapPos).distance;
      if (d < 1080) {
        tryUpdate(
          const _MiniMapTravelPromptData(
            title: 'ELEMENTAL NEXUS',
            subtitle: 'Ancient structure',
            accent: Color(0xFFB388FF),
            icon: Icons.blur_circular_rounded,
          ),
          d,
        );
      }
    }

    final br = widget.world.battleRing;
    if (br.discovered) {
      final d = (br.position - tapPos).distance;
      if (d < 1080) {
        tryUpdate(
          _MiniMapTravelPromptData(
            title: br.isCompleted ? 'BATTLE ARENA' : 'BATTLE RING',
            subtitle: 'Combat landmark',
            accent: const Color(0xFFFFD740),
            icon: Icons.shield_rounded,
          ),
          d,
        );
      }
    }

    final ring = widget.world.bloodRing;
    if (ring.discovered) {
      final d = (ring.position - tapPos).distance;
      if (d < 1080) {
        tryUpdate(
          _MiniMapTravelPromptData(
            title: ring.ritualCompleted ? 'BLOOD PORTAL' : 'BLOOD RING',
            subtitle: 'Forbidden landmark',
            accent: const Color(0xFFFF8A80),
            icon: Icons.radio_button_checked_rounded,
          ),
          d,
        );
      }
    }

    return bestTarget;
  }

  void _handleLongPress(LongPressStartDetails details, double scale) {
    final tapWorld = _worldFromViewport(details.localPosition, scale);

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
    final target =
        _discoveredPlanets[_planetIndex.clamp(
          0,
          _discoveredPlanets.length - 1,
        )];
    _runAfterBuild(() => widget.onNavigatePlanet(target));
  }

  static String _poiLabel(POIType type) => switch (type) {
    POIType.harvesterMarket => 'HARVESTER SHOP',
    POIType.riftKeyMarket => 'RIFT KEY SHOP',
    POIType.cosmicMarket => 'COSMIC MARKET',
    POIType.stardustScanner => 'STAR DUST SCANNER',
    POIType.planetScanner => 'PLANET SCANNER',
    POIType.goldConversion => 'GOLD CONVERSION',
    POIType.nebula => 'NEBULA',
    POIType.derelict => 'DERELICT',
    POIType.warpAnomaly => 'ANOMALY',
    POIType.survivalPortal => 'SURVIVAL PORTAL',
    _ => 'DESTINATION',
  };

  static Color _poiColor(POIType type) => switch (type) {
    POIType.nebula => const Color(0xFF64B5F6),
    POIType.derelict => const Color(0xFF90A4AE),
    POIType.warpAnomaly => const Color(0xFFB388FF),
    POIType.harvesterMarket => const Color(0xFFFFD54F),
    POIType.riftKeyMarket => const Color(0xFF80DEEA),
    POIType.cosmicMarket => const Color(0xFFCE93D8),
    POIType.stardustScanner => const Color(0xFFA5D6A7),
    POIType.planetScanner => const Color(0xFF90CAF9),
    POIType.goldConversion => const Color(0xFFFFD740),
    POIType.survivalPortal => const Color(0xFF8B5CF6),
    _ => const Color(0xFF90CAF9),
  };

  static IconData _poiIcon(POIType type) => switch (type) {
    POIType.nebula => Icons.blur_on_rounded,
    POIType.derelict => Icons.grid_3x3_rounded,
    POIType.warpAnomaly => Icons.change_history_rounded,
    POIType.stardustScanner => Icons.radar_rounded,
    POIType.planetScanner => Icons.travel_explore_rounded,
    POIType.harvesterMarket => Icons.storefront_rounded,
    POIType.riftKeyMarket => Icons.storefront_rounded,
    POIType.cosmicMarket => Icons.storefront_rounded,
    POIType.goldConversion => Icons.storefront_rounded,
    POIType.survivalPortal => Icons.cyclone_rounded,
    _ => Icons.place_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (_discoveredPlanets.isNotEmpty &&
        _planetIndex >= _discoveredPlanets.length) {
      _planetIndex = _discoveredPlanets.length - 1;
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF08091A), Color(0xFF060B18)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                hasHomePlanet: widget.hasHomePlanet,
                discoveredCount: _discoveredPlanets.length,
                markerCount: widget.markers.length,
                onGoHome: () => _runAfterBuild(widget.onGoHome),
                onClose: widget.onClose,
              ),
              _MarkerToolbar(
                markerMode: _markerMode,
                showMarkerColors: _showMarkerColors,
                selectedColor: _selectedColor,
                hasMarkers: widget.markers.isNotEmpty,
                onToggleMode: () => setState(() {
                  final nextOpen = !_showMarkerColors;
                  _showMarkerColors = nextOpen;
                  if (!nextOpen) _markerMode = false;
                }),
                onSelectColor: (i) => setState(() {
                  _selectedColor = i;
                  _showMarkerColors = true;
                  _markerMode = true;
                }),
                onClearAll: () => widget.onMarkersChanged([]),
              ),
              // ── Carousel + Navigate button ─────────────────────────────────
              if (_discoveredPlanets.isNotEmpty) ...[
                SizedBox(
                  height: 136,
                  child: _PlanetCarousel(
                    planets: _discoveredPlanets,
                    selectedIndex: _planetIndex,
                    scrollController: _planetScrollCtrl,
                    onChanged: (i) {
                      setState(() => _planetIndex = i);
                      HapticFeedback.selectionClick();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                _NavigateButton(
                  planet:
                      _discoveredPlanets[_planetIndex.clamp(
                        0,
                        _discoveredPlanets.length - 1,
                      )],
                  onTap: _navigateToSelected,
                ),
                const SizedBox(height: 8),
              ],
              // ── Map takes all remaining space ───────────────────────────────
              Expanded(
                child: _MapView(
                  world: widget.world,
                  game: widget.game,
                  markers: widget.markers,
                  transformCtrl: _transformCtrl,
                  onTapDown: _handleTapDown,
                  onTapUp: _handleTapUp,
                  onLongPress: _handleLongPress,
                  onViewportReady: _primeMapTransform,
                  showAllContestArenas: widget.debugShowAllContestArenasOnMap,
                ),
              ),
              if (_travelPrompt != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: _TravelPromptCard(
                    prompt: _travelPrompt!,
                    onDismiss: () => setState(() => _travelPrompt = null),
                    onConfirm: () {
                      final prompt = _travelPrompt;
                      setState(() => _travelPrompt = null);
                      prompt?.onConfirm?.call();
                    },
                  ),
                ),
              _Legend(
                markerMode: _markerMode,
                showContestTip: widget.debugEnableContestArenaTeleport,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMapTravelPromptData {
  const _MiniMapTravelPromptData({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    this.actionLabel,
    this.onConfirm,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onConfirm;
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER  (redesigned)
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.hasHomePlanet,
    required this.discoveredCount,
    required this.markerCount,
    required this.onGoHome,
    required this.onClose,
  });

  final bool hasHomePlanet;
  final int discoveredCount;
  final int markerCount;
  final VoidCallback onGoHome;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: home | title block | close ──────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Home button
                if (hasHomePlanet)
                  _IconBtn(
                    icon: Icons.home_rounded,
                    onTap: onGoHome,
                    accent: const Color(0xFFF6D55C),
                    tooltip: 'Home',
                  )
                else
                  const SizedBox(width: 42),

                const SizedBox(width: 12),

                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Decorative top rule
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 1,
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'COSMIC NAVIGATION',
                            style: TextStyle(
                              color: const Color(
                                0xFFD6A45A,
                              ).withValues(alpha: 0.55),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Main title with gradient-ish layering
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFF3E7D3), Color(0xFFB89B72)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          'STAR MAP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.5,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Close button
                _IconBtn(
                  icon: Icons.close_rounded,
                  onTap: onClose,
                  accent: Colors.white,
                  tooltip: 'Close',
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Stats row ────────────────────────────────────────────────────
            Row(
              children: [
                _StatChip(
                  icon: Icons.public_rounded,
                  label: '$discoveredCount PLANETS',
                  color: const Color(0xFFD97706),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.push_pin_rounded,
                  label: '$markerCount MARKERS',
                  color: const Color(0xFF0EA5E9),
                ),
                const Spacer(),
                // Tiny coordinate-style decoration
                Text(
                  '${DateTime.now().millisecondsSinceEpoch % 9999 + 1000} LY',
                  style: TextStyle(
                    color: const Color(0xFFD6A45A).withValues(alpha: 0.35),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.accent,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color accent;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.28), width: 1.0),
        ),
        child: Icon(icon, color: accent.withValues(alpha: 0.88), size: 22),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.7), size: 11),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.75),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
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
    required this.showMarkerColors,
    required this.selectedColor,
    required this.hasMarkers,
    required this.onToggleMode,
    required this.onSelectColor,
    required this.onClearAll,
  });

  final bool markerMode;
  final bool showMarkerColors;
  final int selectedColor;
  final bool hasMarkers;
  final VoidCallback onToggleMode;
  final ValueChanged<int> onSelectColor;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onToggleMode();
            },
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: markerMode
                    ? const Color(0xFFD97706).withValues(alpha: 0.2)
                    : const Color(0xFF141820),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: markerMode
                      ? MapMarker.colors[selectedColor].withValues(alpha: 0.95)
                      : const Color(0xFF3A3020),
                  width: markerMode ? 1.5 : 1.0,
                ),
              ),
              child: Icon(
                Icons.push_pin,
                color: markerMode
                    ? MapMarker.colors[selectedColor]
                    : const Color(0xFF8A7B6A),
                size: 15,
              ),
            ),
          ),
          if (showMarkerColors) ...[
            const SizedBox(width: 8),
            for (var i = 0; i < 3; i++) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelectColor(i);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: MapMarker.colors[i].withValues(
                      alpha: selectedColor == i && markerMode ? 0.86 : 0.28,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectedColor == i && markerMode
                          ? const Color(0xFFE8DCC8)
                          : const Color(0xFF3A3020),
                      width: selectedColor == i && markerMode ? 1.8 : 1.0,
                    ),
                  ),
                ),
              ),
              if (i < 2) const SizedBox(width: 6),
            ],
          ],
          const Spacer(),
          if (hasMarkers)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.mediumImpact();
                onClearAll();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF141820),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFF3A3020)),
                ),
                child: const Text(
                  'CLEAR ALL',
                  style: TextStyle(
                    color: Color(0xFF8A7B6A),
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
// PLANET CAROUSEL  (flat horizontal scroll — one row, bigger planets)
// ─────────────────────────────────────────────────────────────────────────────

class _PlanetCarousel extends StatefulWidget {
  const _PlanetCarousel({
    required this.planets,
    required this.selectedIndex,
    required this.scrollController,
    required this.onChanged,
  });

  final List<CosmicPlanet> planets;
  final int selectedIndex;
  final ScrollController scrollController;
  final ValueChanged<int> onChanged;

  @override
  State<_PlanetCarousel> createState() => _PlanetCarouselState();
}

class _PlanetCarouselState extends State<_PlanetCarousel> {
  static const double _cardW = 112.0;
  static const double _cardGap = 12.0;
  static const double _cardExtent = _cardW + _cardGap; // 90
  bool _didPrimeScroll = false;

  @override
  void didUpdateWidget(_PlanetCarousel old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToSelected();
      });
    }
  }

  // With sidePad on both ends the scroll offset that centres card[i] is:
  //   i * _cardExtent   (sidePad cancels out — card 0 starts at scrollOffset 0)
  void _scrollToSelected() {
    if (!widget.scrollController.hasClients) return;
    final pos = widget.scrollController.position;
    final target = (widget.selectedIndex * _cardExtent).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    widget.scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final planets = widget.planets;
    if (planets.isEmpty) return const SizedBox.shrink();

    if (!_didPrimeScroll) {
      _didPrimeScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.scrollController.hasClients) return;
        final pos = widget.scrollController.position;
        final target = (widget.selectedIndex * _cardExtent).clamp(
          pos.minScrollExtent,
          pos.maxScrollExtent,
        );
        widget.scrollController.jumpTo(target);
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // sidePad centres card[0] in the viewport; gap is baked into each item
        final sidePad = (constraints.maxWidth - _cardW) / 2;
        return ListView.builder(
          controller: widget.scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          // padding adds sidePad on left; right side handled by last item margin
          padding: EdgeInsets.only(left: sidePad),
          itemCount: planets.length,
          itemBuilder: (context, index) {
            final planet = planets[index];
            final isSelected = index == widget.selectedIndex;
            // Every card except the last gets a right margin equal to _cardGap
            final isLast = index == planets.length - 1;
            return Padding(
              padding: EdgeInsets.only(right: isLast ? sidePad : _cardGap),
              child: _PlanetCard(
                planet: planet,
                isSelected: isSelected,
                onTap: () => widget.onChanged(index),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Single planet card ────────────────────────────────────────────────────────

class _PlanetCard extends StatelessWidget {
  const _PlanetCard({
    required this.planet,
    required this.isSelected,
    required this.onTap,
  });

  final CosmicPlanet planet;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const globeSize = 82.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: SizedBox(
        width: 112,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Globe
            RepaintBoundary(
              child: SizedBox(
                width: globeSize,
                height: globeSize,
                child: CustomPaint(
                  isComplex: true,
                  painter: _PlanetPreviewPainter(
                    planet: planet,
                    spin: 0,
                    highlighted: isSelected,
                    explicitRadius: 31,
                    alpha: isSelected ? 1.0 : 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                planetName(planet.element).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.3),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Navigate button (single, below carousel) ──────────────────────────────────

class _NavigateButton extends StatelessWidget {
  const _NavigateButton({required this.planet, required this.onTap});

  final CosmicPlanet planet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final col = planet.color;
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: col.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: col.withValues(alpha: 0.4), width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.navigation_rounded, color: col, size: 12),
              const SizedBox(width: 6),
              Text(
                'NAVIGATE TO ${planetName(planet.element).toUpperCase()}',
                style: TextStyle(
                  color: col,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TravelPromptCard extends StatelessWidget {
  const _TravelPromptCard({
    required this.prompt,
    required this.onDismiss,
    required this.onConfirm,
  });

  final _MiniMapTravelPromptData prompt;
  final VoidCallback onDismiss;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final accent = prompt.accent;
    final canConfirm = prompt.onConfirm != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141820).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.32)),
            ),
            child: Icon(prompt.icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  prompt.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFE8DCC8),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  prompt.subtitle.toUpperCase(),
                  style: TextStyle(
                    color: const Color(0xFF8A7B6A),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onDismiss();
            },
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              child: Icon(
                Icons.close_rounded,
                color: const Color(0xFF8A7B6A),
                size: 18,
              ),
            ),
          ),
          if (canConfirm) ...[
            const SizedBox(width: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.mediumImpact();
                onConfirm();
              },
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.navigation_rounded, color: accent, size: 13),
                    const SizedBox(width: 6),
                    Text(
                      prompt.actionLabel ?? 'TRAVEL',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAP VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _MapView extends StatefulWidget {
  const _MapView({
    required this.world,
    required this.game,
    required this.markers,
    required this.transformCtrl,
    required this.onTapDown,
    required this.onTapUp,
    required this.onLongPress,
    required this.onViewportReady,
    required this.showAllContestArenas,
  });

  final CosmicWorld world;
  final CosmicGame game;
  final List<MapMarker> markers;
  final TransformationController transformCtrl;
  final void Function(TapDownDetails, double) onTapDown;
  final void Function(TapUpDetails, double) onTapUp;
  final void Function(LongPressStartDetails, double) onLongPress;
  final void Function({required double viewportSize, required double scale})
  onViewportReady;
  final bool showAllContestArenas;

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  double _lastFitSize = -1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fitSize = min(constraints.maxWidth, constraints.maxHeight);
          final scale =
              fitSize /
              max(widget.world.worldSize.width, widget.world.worldSize.height);
          final discoveredPlanetCount = widget.world.discoveredCount;
          if (_lastFitSize != fitSize) {
            _lastFitSize = fitSize;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              widget.onViewportReady(viewportSize: fitSize, scale: scale);
            });
          }

          return Center(
            child: SizedBox(
              width: fitSize,
              height: fitSize,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => widget.onTapDown(d, scale),
                  onTapUp: (d) => widget.onTapUp(d, scale),
                  onLongPressStart: (d) => widget.onLongPress(d, scale),
                  child: InteractiveViewer(
                    transformationController: widget.transformCtrl,
                    minScale: 1.0,
                    maxScale: 8.0,
                    boundaryMargin: EdgeInsets.zero,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        isComplex: true,
                        size: Size(fitSize, fitSize),
                        painter: _MiniMapPainter(
                          world: widget.world,
                          game: widget.game,
                          scale: scale,
                          shipPos: widget.game.ship.pos,
                          revealedCellCount: widget.game.revealedCells.length,
                          discoveredPlanetCount: discoveredPlanetCount,
                          showAllContestArenasOnMap:
                              widget.showAllContestArenas,
                          markers: widget.markers,
                        ),
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
        ? 'Tap destination, then travel  •  Pinch to zoom'
        : 'Tap destination, then travel  •  Pinch to zoom  •  Drag to pan';

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: const Color(0xFF3A3020).withValues(alpha: 0.75),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hint,
            style: TextStyle(
              color: const Color(0xFF8A7B6A),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Tip: Long-press the map icon to toggle it.',
            style: TextStyle(
              color: const Color(0xFFD6A45A),
              fontSize: 9.5,
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
    this.alpha = 1.0,
  });

  final CosmicPlanet planet;
  final double spin;
  final bool highlighted;
  final double? explicitRadius;
  final double alpha;

  static final _sphereShaderPaintCache = <int, Paint>{};

  static void _drawSphere(
    Canvas c,
    Offset p,
    double r,
    Color color, {
    double highlight = 0.4,
    double shadow = 0.6,
    double alpha = 1.0,
  }) {
    final baseColor = color.withValues(alpha: color.a * alpha);
    final key = Object.hash(
      baseColor,
      (r * 10).round(),
      (highlight * 100).round(),
      (shadow * 100).round(),
      p.dx.round(),
      p.dy.round(),
    );
    final paint = _sphereShaderPaintCache.putIfAbsent(
      key,
      () => Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(baseColor, Colors.white, highlight)!,
            baseColor,
            Color.lerp(baseColor, Colors.black, shadow)!,
          ],
          stops: const [0.0, 0.55, 1.0],
          center: const Alignment(-0.35, -0.35),
          radius: 1.05,
        ).createShader(Rect.fromCircle(center: p, radius: r)),
    );
    c.drawCircle(p, r, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = explicitRadius ?? min(size.width, size.height) * 0.42;
    final col = planet.color;
    final glowA = highlighted ? 0.13 : 0.07;
    final showDetail = highlighted || r >= 30;

    canvas.drawCircle(
      c,
      r * (highlighted ? 1.55 : 1.3),
      Paint()
        ..color = col.withValues(alpha: glowA * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlighted ? r * 0.2 : r * 0.14,
    );

    switch (planet.element) {
      case 'Fire':
        if (showDetail) {
          for (var i = 0; i < 6; i++) {
            final a = spin * 0.8 + i * pi / 3;
            canvas.drawCircle(
              Offset(c.dx + cos(a) * r * 1.2, c.dy + sin(a) * r * 1.2),
              r * (0.2 + 0.08 * sin(spin * 2 + i)),
              Paint()
                ..color = const Color(
                  0xFFFF6D00,
                ).withValues(alpha: 0.22 * alpha),
            );
          }
        }
        _drawSphere(canvas, c, r, col, alpha: alpha);

      case 'Lava':
        _drawSphere(
          canvas,
          c,
          r,
          const Color(0xFF3E2723),
          highlight: 0.2,
          alpha: alpha,
        );
        if (showDetail) {
          final crack = Paint()
            ..color = const Color(0xFFFFAB40).withValues(alpha: 0.6 * alpha)
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
        }

      case 'Lightning':
        _drawSphere(
          canvas,
          c,
          r,
          const Color(0xFF1A237E),
          highlight: 0.5,
          alpha: alpha,
        );
        if (showDetail) {
          canvas.drawCircle(
            c,
            r * (1.2 + 0.08 * sin(spin * 2.0)),
            Paint()
              ..color = const Color(0xFF90CAF9).withValues(alpha: 0.28 * alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
          for (var i = 0; i < 7; i++) {
            final a = spin * (0.9 + i * 0.08) + i * (pi * 2 / 7);
            canvas.drawCircle(
              Offset(c.dx + cos(a) * r * 1.3, c.dy + sin(a) * r * 1.3),
              r * 0.06,
              Paint()..color = Colors.white.withValues(alpha: 0.72 * alpha),
            );
          }
        }

      case 'Water':
        _drawSphere(
          canvas,
          c,
          r,
          const Color(0xFF0D47A1),
          highlight: 0.35,
          alpha: alpha,
        );
        if (showDetail) {
          canvas.save();
          canvas.clipPath(
            Path()..addOval(Rect.fromCircle(center: c, radius: r)),
          );
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
              Paint()
                ..color = Colors.white.withValues(
                  alpha: (0.08 + i * 0.03) * alpha,
                ),
            );
          }
          canvas.restore();
        }

      case 'Ice':
        _drawSphere(
          canvas,
          c,
          r,
          const Color(0xFFB3E5FC),
          shadow: 0.45,
          alpha: alpha,
        );
        if (showDetail) {
          for (var i = 0; i < 5; i++) {
            final a = i * 1.2 + spin * 0.07;
            canvas.drawLine(
              Offset(c.dx + cos(a) * r * 0.15, c.dy + sin(a) * r * 0.15),
              Offset(
                c.dx + cos(a + 0.7) * r * 0.82,
                c.dy + sin(a + 0.7) * r * 0.82,
              ),
              Paint()
                ..color = Colors.white.withValues(alpha: 0.45 * alpha)
                ..strokeWidth = 1.0,
            );
          }
        }

      case 'Steam':
        _drawSphere(
          canvas,
          c,
          r,
          const Color(0xFF607D8B),
          highlight: 0.35,
          alpha: alpha,
        );
        if (showDetail) {
          for (var i = 0; i < 7; i++) {
            final a = i * 0.9 + spin * 0.6;
            canvas.drawCircle(
              Offset(c.dx + cos(a) * r * 1.2, c.dy + sin(a) * r * 1.0),
              r * 0.2,
              Paint()..color = Colors.white.withValues(alpha: 0.11 * alpha),
            );
          }
        }

      case 'Earth':
        _drawSphere(
          canvas,
          c,
          r,
          const Color(0xFF5D4037),
          highlight: 0.28,
          alpha: alpha,
        );
        if (showDetail) {
          final rng = Random(planet.element.hashCode);
          for (var i = 0; i < 6; i++) {
            final a = rng.nextDouble() * pi * 2;
            final d = r * (0.2 + rng.nextDouble() * 0.55);
            canvas.drawCircle(
              Offset(c.dx + cos(a) * d, c.dy + sin(a) * d),
              r * (0.1 + rng.nextDouble() * 0.12),
              Paint()
                ..color = const Color(
                  0xFF8BC34A,
                ).withValues(alpha: 0.5 * alpha),
            );
          }
        }

      case 'Mud':
        _drawSphere(
          canvas,
          c,
          r,
          const Color(0xFF4E342E),
          highlight: 0.18,
          alpha: alpha,
        );
        if (showDetail) {
          for (var i = 0; i < 7; i++) {
            final a = i * (pi * 2 / 7) + spin * 0.2;
            canvas.drawCircle(
              Offset(c.dx + cos(a) * r * 0.58, c.dy + sin(a) * r * 0.58),
              r * 0.07,
              Paint()..color = Colors.black.withValues(alpha: 0.28 * alpha),
            );
          }
        }

      case 'Dust':
        _drawSphere(canvas, c, r, col, shadow: 0.42, alpha: alpha);
        if (showDetail) {
          canvas
            ..save()
            ..translate(c.dx, c.dy)
            ..scale(1.0, 0.35)
            ..drawCircle(
              Offset.zero,
              r * 1.9,
              Paint()
                ..color = col.withValues(alpha: 0.4 * alpha)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2,
            )
            ..restore();
        }

      case 'Crystal':
        _drawSphere(
          canvas,
          c,
          r,
          col,
          highlight: 0.62,
          shadow: 0.3,
          alpha: alpha,
        );
        if (showDetail) {
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
              Paint()..color = Colors.white.withValues(alpha: 0.18 * alpha),
            );
          }
        }

      case 'Air':
        _drawSphere(
          canvas,
          c,
          r,
          col,
          highlight: 0.55,
          shadow: 0.2,
          alpha: alpha,
        );
        if (showDetail) {
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
                ..color = Colors.white.withValues(alpha: 0.2 * alpha)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0,
            );
          }
        }

      case 'Plant':
        _drawSphere(
          canvas,
          c,
          r,
          const Color(0xFF33691E),
          highlight: 0.25,
          alpha: alpha,
        );
        if (showDetail) {
          for (var i = 0; i < 5; i++) {
            final a = i * (pi * 2 / 5) + spin * 0.2;
            canvas.drawLine(
              Offset(c.dx + cos(a) * r * 0.92, c.dy + sin(a) * r * 0.92),
              Offset(
                c.dx + cos(a + 0.4) * r * 1.25,
                c.dy + sin(a + 0.4) * r * 1.25,
              ),
              Paint()
                ..color = const Color(0xFF66BB6A).withValues(alpha: 0.7 * alpha)
                ..strokeWidth = 1.2,
            );
          }
        }

      case 'Poison':
        _drawSphere(canvas, c, r, col, highlight: 0.22, alpha: alpha);
        if (showDetail) {
          for (var i = 0; i < 6; i++) {
            final a = i * 1.05 + spin * 0.35;
            canvas.drawCircle(
              Offset(c.dx + cos(a) * r * 1.25, c.dy + sin(a) * r * 1.05),
              r * 0.22,
              Paint()
                ..color = const Color(
                  0xFFBA68C8,
                ).withValues(alpha: 0.16 * alpha),
            );
          }
        }

      case 'Spirit':
        _drawSphere(
          canvas,
          c,
          r,
          const Color(0xFF303F9F),
          highlight: 0.42,
          alpha: alpha,
        );
        if (showDetail) {
          for (var i = 0; i < 5; i++) {
            final a = spin * 0.7 + i * (pi * 2 / 5);
            canvas.drawCircle(
              Offset(c.dx + cos(a) * r * 1.15, c.dy + sin(a) * r * 1.15),
              r * 0.09,
              Paint()..color = Colors.white.withValues(alpha: 0.65 * alpha),
            );
          }
        }

      case 'Dark':
        _drawSphere(
          canvas,
          c,
          r,
          const Color(0xFF1A0930),
          highlight: 0.12,
          shadow: 0.72,
          alpha: alpha,
        );
        if (showDetail) {
          canvas.drawCircle(
            c,
            r * 1.32,
            Paint()
              ..color = const Color(0xFF6A0DAD).withValues(alpha: 0.28 * alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
        }

      case 'Light':
        _drawSphere(
          canvas,
          c,
          r,
          const Color(0xFFFFF8E1),
          highlight: 0.7,
          shadow: 0.22,
          alpha: alpha,
        );
        if (showDetail) {
          for (var i = 0; i < 8; i++) {
            final a = i * (pi * 2 / 8) + spin * 0.08;
            canvas.drawLine(
              Offset(c.dx + cos(a) * r * 1.05, c.dy + sin(a) * r * 1.05),
              Offset(c.dx + cos(a) * r * 1.42, c.dy + sin(a) * r * 1.42),
              Paint()
                ..color = const Color(
                  0xFFFFECB3,
                ).withValues(alpha: 0.55 * alpha)
                ..strokeWidth = 1.2,
            );
          }
        }

      case 'Blood':
        _drawSphere(
          canvas,
          c,
          r,
          const Color(0xFF8B0000),
          highlight: 0.25,
          alpha: alpha,
        );
        if (showDetail) {
          canvas.drawCircle(
            c,
            r * (1.2 + 0.06 * sin(spin * 1.5)),
            Paint()
              ..color = const Color(0xFFD32F2F).withValues(alpha: 0.35 * alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6,
          );
        }

      default:
        _drawSphere(canvas, c, r, col, alpha: alpha);
    }

    if (highlighted) {
      canvas.drawCircle(
        c,
        r * 1.07,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.10 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlanetPreviewPainter old) {
    if (old.planet.element != planet.element) return true;
    if (old.highlighted != highlighted) return true;
    if (old.explicitRadius != explicitRadius) return true;
    if (old.alpha != alpha) return true;
    if (!highlighted && !old.highlighted) return false;
    return old.spin != spin;
  }
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

  static final _tpCache = <int, TextPainter>{};

  static TextPainter _tp(
    String text,
    TextStyle style, {
    TextAlign align = TextAlign.left,
  }) {
    final key = Object.hash(
      text,
      style.fontSize,
      style.color,
      style.fontWeight?.value,
      align.name,
    );
    return _tpCache.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout(),
    );
  }

  static final _glowPaintCache = <int, Paint>{};

  static Paint _glowPaint(Color color, double alpha, double blur) {
    final key = Object.hash(color, (alpha * 1000).round(), (blur * 10).round());
    return _glowPaintCache.putIfAbsent(
      key,
      () => Paint()
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

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
      if (i == 0) {
        hexPath.moveTo(pt.dx, pt.dy);
      } else {
        hexPath.lineTo(pt.dx, pt.dy);
      }
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

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF040613),
    );

    // Revealed fog cells
    final fogCellScaled = CosmicGame.fogCellSize * scale;
    final gridW = (world.worldSize.width / CosmicGame.fogCellSize).ceil();
    final revealPaint = Paint()
      ..color = const Color(0xFF141C46).withValues(alpha: 0.52);
    final revealEdgePaint = Paint()
      ..color = const Color(0x331E2D70).withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final showFogEdges = fogCellScaled >= 2.0 && revealedCellCount <= 5000;
    if (fogCellScaled < 2.0) {
      final bucketSide = max(1, (3.0 / fogCellScaled).ceil());
      final bucketGridW = (gridW / bucketSide).ceil();
      final bucketSize = fogCellScaled * bucketSide;
      final paintedBuckets = <int>{};
      for (final key in game.revealedCells) {
        final gx = key % gridW;
        final gy = key ~/ gridW;
        final bx = gx ~/ bucketSide;
        final by = gy ~/ bucketSide;
        final bucketKey = by * bucketGridW + bx;
        if (!paintedBuckets.add(bucketKey)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            bx * bucketSize,
            by * bucketSize,
            bucketSize,
            bucketSize,
          ),
          revealPaint,
        );
      }
    } else {
      for (final key in game.revealedCells) {
        final gx = key % gridW;
        final gy = key ~/ gridW;
        final rect = Rect.fromLTWH(
          gx * fogCellScaled,
          gy * fogCellScaled,
          fogCellScaled,
          fogCellScaled,
        );
        canvas.drawRect(rect, revealPaint);
        if (showFogEdges) {
          canvas.drawRect(rect.deflate(0.2), revealEdgePaint);
        }
      }
    }

    final showPlanetLabels = scale >= 0.012;
    final showStructureLabels = scale >= 0.014;
    final showPoiLabels = scale >= 0.016;
    final showContestLabels = scale >= 0.018;

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

      if (showPlanetLabels) {
        _paintLabel(
          canvas,
          planetName(planet.element),
          planet.color,
          0.8,
          pos,
          pr,
        );
      }
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
      if (showStructureLabels) {
        _paintLabel(
          canvas,
          'Lv${whirl.level} ${whirl.hordeTypeName}',
          wColor,
          0.7,
          wPos,
          8,
        );
      }
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

      final tag = switch (lair.template.preferredType ??
          bossTypeForLevel(lair.level)) {
        BossType.charger => '⚡',
        BossType.gunner => '🔫',
        BossType.skirmisher => '🎯',
        BossType.bulwark => '🛡️',
        BossType.carrier => '🛸',
        BossType.warden => '👑',
      };
      if (showStructureLabels) {
        _paintLabel(
          canvas,
          '$tag Lv${lair.level} ${lair.template.name.toUpperCase()}',
          const Color(0xFFFF5252),
          1.0,
          lPos,
          9,
        );
      }
    }

    // Space POIs
    for (final poi in game.spacePOIs) {
      if (poi.type == POIType.comet || poi.type == POIType.stardustScanner) {
        continue;
      }

      final isMarket =
          poi.type == POIType.harvesterMarket ||
          poi.type == POIType.riftKeyMarket ||
          poi.type == POIType.cosmicMarket ||
          poi.type == POIType.goldConversion;
      final isSurvivalPortal = poi.type == POIType.survivalPortal;
      if (!poi.discovered && !isMarket && !isSurvivalPortal) continue;

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

        case POIType.goldConversion:
          poiColor = const Color(0xFFFFD740);
          poiLabel = 'GOLD CONVERSION';
          poiDotR = 5.0;
          _paintHexMarker(
            canvas,
            poiPos,
            poiColor,
            poi.discovered ? 0.7 : 0.25,
            poi.discovered,
          );

        case POIType.survivalPortal:
          poiColor = const Color(0xFF8B5CF6);
          poiLabel = poi.discovered ? 'SURVIVAL PORTAL' : 'UNKNOWN SIGNAL';
          poiDotR = 5.0;
          canvas
            ..drawCircle(
              poiPos,
              8,
              _glowPaint(poiColor, poi.discovered ? 0.35 : 0.18, 10),
            )
            ..drawCircle(
              poiPos,
              poiDotR,
              Paint()
                ..color = poiColor.withValues(
                  alpha: poi.discovered ? 0.8 : 0.4,
                ),
            )
            ..drawCircle(
              poiPos,
              7,
              Paint()
                ..color = poiColor.withValues(
                  alpha: poi.discovered ? 0.35 : 0.15,
                )
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2,
            );

        default:
          continue;
      }

      if (showPoiLabels) {
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
    }

    // Prismatic field
    if (game.prismaticField.discovered) {
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

      if (showStructureLabels) {
        _paintLabel(canvas, 'PRISMATIC AURORA', pfColor, 0.7, pfPos, pfr);
      }
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
      if (showStructureLabels) {
        _paintLabel(canvas, 'ELEMENTAL NEXUS', nexusColor, 0.7, nxPos, 12);
      }
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
        if (i == 0) {
          octPath.moveTo(pt.dx, pt.dy);
        } else {
          octPath.lineTo(pt.dx, pt.dy);
        }
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

      if (showStructureLabels) {
        _paintLabel(
          canvas,
          br.isCompleted ? 'BATTLE ARENA' : 'BATTLE RING',
          brColor,
          0.7,
          brPos,
          12,
        );
      }
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

      if (showContestLabels) {
        _paintLabel(
          canvas,
          '${arena.trait.label.toUpperCase()} CONTEST',
          aColor,
          0.78,
          aPos,
          12,
        );
      }
    }

    // Blood Ring – subtle red ring hint even before discovery
    final ring = world.bloodRing;
    if (!ring.discovered) {
      final ringPos = ring.position * scale;
      canvas.drawCircle(
        ringPos,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFFB71C1C).withValues(alpha: 0.18),
      );
    }
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

      if (showStructureLabels) {
        _paintLabel(
          canvas,
          ring.ritualCompleted ? 'BLOOD PORTAL' : 'BLOOD RING',
          ringColor,
          0.7,
          ringPos,
          12,
        );
      }
    }

    // Ship
    final shipScaled = shipPos * scale;
    canvas
      ..drawCircle(shipScaled, 5, _glowPaint(const Color(0xFF00E5FF), 1.0, 4))
      ..drawCircle(shipScaled, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter old) {
    if (scale != old.scale) return true;
    if (revealedCellCount != old.revealedCellCount) return true;
    if (discoveredPlanetCount != old.discoveredPlanetCount) return true;
    if (showAllContestArenasOnMap != old.showAllContestArenasOnMap) return true;
    if (!identical(markers, old.markers)) return true;
    // Only repaint when ship has moved a visible amount on the minimap.
    return (shipPos - old.shipPos).distance * scale > 0.5;
  }
}
