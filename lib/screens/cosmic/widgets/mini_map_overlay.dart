import 'package:alchemons/audio/audio.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:alchemons/games/cosmic/cosmic_cache_data.dart';
import 'package:alchemons/games/cosmic/contest_art.dart'
    show kContestChampionGold;
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:alchemons/games/cosmic/station_art.dart';
import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'cosmic_overlay_chrome.dart';
import 'cosmic_panel_kit.dart' show panelLabel, panelPalette;
import 'package:alchemons/widgets/bracket_controls.dart' show BracketButton;
import 'cosmic_screen_styles.dart';
import 'star_chart_art.dart';
import '../models/map_marker.dart';
import 'package:alchemons/widgets/app_icons.dart';

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
    this.dungeonStarsFor,
    this.dungeonStarTotal = 0,
    this.dungeonStarMax = 0,
    this.tutorialTargetPos,
    this.tutorialTargetColor,
    this.tutorialTargetLabel,
    this.debugShowAllContestArenasOnMap = false,
    this.debugEnableContestArenaTeleport = false,
  });

  final CosmicWorld world;
  final CosmicGame game;
  final FactionTheme theme;
  final List<MapMarker> markers;
  final bool hasHomePlanet;

  /// Returns 0..3 dungeon stars for a built-dungeon planet, or null for
  /// coming-soon planets (whose card shows no earned stars yet).
  final int? Function(CosmicPlanet planet)? dungeonStarsFor;

  /// Campaign star tally for the header chip (hidden when [dungeonStarMax]
  /// is 0).
  final int dungeonStarTotal;
  final int dungeonStarMax;
  final void Function(Offset worldPos) onTeleport;
  final void Function(CosmicPlanet planet) onNavigatePlanet;
  final VoidCallback onGoHome;
  final VoidCallback onClose;
  final void Function(List<MapMarker> markers) onMarkersChanged;
  final Offset? tutorialTargetPos;
  final Color? tutorialTargetColor;
  final String? tutorialTargetLabel;
  final bool debugShowAllContestArenasOnMap;
  final bool debugEnableContestArenaTeleport;

  @override
  State<MiniMapOverlay> createState() => MiniMapOverlayState();
}

/// Whether the planet carousel is collapsed. Module-level so the choice
/// survives closing and reopening the chart within a session — a player who
/// wants the big map does not want to re-collapse it every time.
bool _planetsCollapsed = false;

class MiniMapOverlayState extends State<MiniMapOverlay> {
  final TransformationController _transformCtrl = TransformationController();
  final ScrollController _planetScrollCtrl = ScrollController();
  int _selectedColor = 0;
  bool _markerMode = false;
  bool _eraseMode = false;
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
    required Size viewport,
    required Size content,
    required double scale,
  }) {
    if (_didPrimeMapTransform ||
        viewport.isEmpty ||
        content.isEmpty ||
        scale <= 0) {
      return;
    }
    _didPrimeMapTransform = true;

    const initialZoom = 1.25;
    final shipScene = widget.game.ship.pos * scale;
    // Clamp per axis against the painted content, not one square dimension:
    // the chart is now cover-scaled, so the two axes overflow differently.
    final minTx = viewport.width - content.width * initialZoom;
    final minTy = viewport.height - content.height * initialZoom;
    final tx = (viewport.width / 2 - shipScene.dx * initialZoom).clamp(
      min(minTx, 0.0),
      0.0,
    );
    final ty = (viewport.height / 2 - shipScene.dy * initialZoom).clamp(
      min(minTy, 0.0),
      0.0,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _transformCtrl.value = Matrix4.identity()
        ..translateByDouble(tx.toDouble(), ty.toDouble(), 0, 1)
        ..scaleByDouble(initialZoom, initialZoom, 1, 1);
    });
  }

  /// World-space distance corresponding to [screenPx] on screen right now, so
  /// the pick radius feels the same whether zoomed out or all the way in.
  double _worldTolerance(double scale, double screenPx) {
    final zoom = _transformCtrl.value.getMaxScaleOnAxis();
    final denom = scale * (zoom <= 0 ? 1.0 : zoom);
    return denom <= 0 ? 800.0 : screenPx / denom;
  }

  /// Removes the marker nearest [tapWorld] if one is within reach. Returns
  /// whether anything was removed.
  bool _removeMarkerNear(Offset tapWorld, double scale) {
    var closestDist = double.infinity;
    var closestIdx = -1;
    for (var i = 0; i < widget.markers.length; i++) {
      final d = (widget.markers[i].worldPos - tapWorld).distance;
      if (d < closestDist) {
        closestDist = d;
        closestIdx = i;
      }
    }
    final tol = max(_worldTolerance(scale, 26), 240.0);
    if (closestIdx >= 0 && closestDist < tol) {
      final updated = List<MapMarker>.from(widget.markers)
        ..removeAt(closestIdx);
      widget.onMarkersChanged(updated);
      HapticFeedback.lightImpact();
      return true;
    }
    return false;
  }

  void _handleTapUp(TapUpDetails details, double scale) {
    final tapWorld = _worldFromViewport(details.localPosition, scale);
    final wx = tapWorld.dx;
    final wy = tapWorld.dy;

    if (_eraseMode) {
      setState(() => _travelPrompt = null);
      _removeMarkerNear(tapWorld, scale);
      return;
    }

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
          ),
          d,
        );
      }
    }

    return bestTarget;
  }

  void _handleLongPress(LongPressStartDetails details, double scale) {
    // Kept as a shortcut, but it is no longer the only way to remove one —
    // it competes with the viewer's pan gesture and often never fires.
    _removeMarkerNear(_worldFromViewport(details.localPosition, scale), scale);
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

  static Color _poiColor(POIType type) =>
      stationKindFor(type)?.accent ?? _otherPoiColor(type);

  static Color _otherPoiColor(POIType type) => switch (type) {
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


  @override
  Widget build(BuildContext context) {
    if (_discoveredPlanets.isNotEmpty &&
        _planetIndex >= _discoveredPlanets.length) {
      _planetIndex = _discoveredPlanets.length - 1;
    }

    return Material(
      color: Colors.transparent,
      child: CosmicOverlayBackdrop(
        alpha: 0.97,
        child: Column(
          children: [
            _Header(
              hasHomePlanet: widget.hasHomePlanet,
              discoveredCount: _discoveredPlanets.length,
              planetTotal: widget.world.totalCount,
              markerCount: widget.markers.length,
              starTotal: widget.dungeonStarTotal,
              starMax: widget.dungeonStarMax,
              onGoHome: () => _runAfterBuild(widget.onGoHome),
              onClose: widget.onClose,
            ),
            // ── Carousel + Navigate button (collapsible) ───────────────────
            if (_discoveredPlanets.isNotEmpty) ...[
              // One row: marker tools on the left, planets toggle on the
              // right. They were stacked, which cost the chart a whole extra
              // row the moment the tools appeared.
              _ChartToolRow(
                showMarkerTools: _planetsCollapsed,
                markerMode: _markerMode,
                eraseMode: _eraseMode,
                showMarkerColors: _showMarkerColors,
                selectedColor: _selectedColor,
                hasMarkers: widget.markers.isNotEmpty,
                onToggleMarkerMode: () => setState(() {
                  final nextOpen = !_showMarkerColors;
                  _showMarkerColors = nextOpen;
                  if (!nextOpen) _markerMode = false;
                  if (nextOpen) _eraseMode = false;
                }),
                onToggleErase: () => setState(() {
                  _eraseMode = !_eraseMode;
                  if (_eraseMode) {
                    _markerMode = false;
                    _showMarkerColors = false;
                  }
                }),
                onSelectColor: (i) => setState(() {
                  _selectedColor = i;
                  _showMarkerColors = true;
                  _markerMode = true;
                  _eraseMode = false;
                }),
                onClearAll: () => widget.onMarkersChanged([]),
                collapsed: _planetsCollapsed,
                onToggle: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _planetsCollapsed = !_planetsCollapsed;
                    if (!_planetsCollapsed) {
                      // The marker toolbar goes with it — leaving place or
                      // erase armed with no visible control would silently
                      // hijack the next tap on the chart.
                      _markerMode = false;
                      _eraseMode = false;
                      _showMarkerColors = false;
                    }
                  });
                },
              ),
              // Collapsing hands the carousel's ~190px straight to the chart.
              //
              // Deliberately NOT animated. An AnimatedSize here re-lays-out
              // the chart on every frame of the transition, and the map
              // painter is isComplex — it redraws the whole galaxy at a new
              // size each time. That is ~13 full repaints for a 220ms slide,
              // which is exactly the hitch it was supposed to smooth over.
              // One reflow is cheaper and reads as snappier.
              if (!_planetsCollapsed)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 136,
                      child: _PlanetCarousel(
                        planets: _discoveredPlanets,
                        selectedIndex: _planetIndex,
                        scrollController: _planetScrollCtrl,
                        dungeonStarsFor: widget.dungeonStarsFor,
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
                      onTap: context.soundTap(_navigateToSelected),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
            ],
            if (_discoveredPlanets.isEmpty)
              _ChartToolRow(
                showMarkerTools: true,
                markerMode: _markerMode,
                eraseMode: _eraseMode,
                showMarkerColors: _showMarkerColors,
                selectedColor: _selectedColor,
                hasMarkers: widget.markers.isNotEmpty,
                onToggleMarkerMode: () => setState(() {
                  final nextOpen = !_showMarkerColors;
                  _showMarkerColors = nextOpen;
                  if (!nextOpen) _markerMode = false;
                  if (nextOpen) _eraseMode = false;
                }),
                onToggleErase: () => setState(() {
                  _eraseMode = !_eraseMode;
                  if (_eraseMode) {
                    _markerMode = false;
                    _showMarkerColors = false;
                  }
                }),
                onSelectColor: (i) => setState(() {
                  _selectedColor = i;
                  _showMarkerColors = true;
                  _markerMode = true;
                  _eraseMode = false;
                }),
                onClearAll: () => widget.onMarkersChanged([]),
                collapsed: true,
                onToggle: null,
              ),
            // ── Map takes all remaining space, edge to edge ────────────────
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _MapView(
                      world: widget.world,
                      game: widget.game,
                      markers: widget.markers,
                      transformCtrl: _transformCtrl,
                      onTapDown: _handleTapDown,
                      onTapUp: _handleTapUp,
                      onLongPress: _handleLongPress,
                      onViewportReady: _primeMapTransform,
                      showAllContestArenas:
                          widget.debugShowAllContestArenasOnMap,
                      tutorialTargetPos: widget.tutorialTargetPos,
                      tutorialTargetColor: widget.tutorialTargetColor,
                      tutorialTargetLabel: widget.tutorialTargetLabel,
                    ),
                  ),
                  // Prompt and legend float ON the chart now. Stacked below it
                  // they stole height and forced the map back off the bottom
                  // edge, which is the boxed-in look we are getting rid of.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: true,
                      child: Container(
                        // This backs the controls below it. It was 132px tall
                        // reaching 96% opacity, with the ramp starting at 55%
                        // — so it was near-solid well above the controls and
                        // swallowed the bottom of the chart. Shorter, and the
                        // darkening now happens late, close to the controls
                        // that actually need it.
                        height: 108,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              CosmicScreenStyles.bg1.withValues(alpha: 0.0),
                              CosmicScreenStyles.bg1.withValues(alpha: 0.40),
                              CosmicScreenStyles.bg1.withValues(alpha: 0.86),
                            ],
                            stops: const [0.0, 0.62, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_travelPrompt != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                              child: _TravelPromptCard(
                                prompt: _travelPrompt!,
                                onDismiss: () =>
                                    setState(() => _travelPrompt = null),
                                onConfirm: () {
                                  final prompt = _travelPrompt;
                                  setState(() => _travelPrompt = null);
                                  prompt?.onConfirm?.call();
                                },
                              ),
                            ),
                          _Legend(
                            markerMode: _markerMode,
                            eraseMode: _eraseMode,
                            showContestTip:
                                widget.debugEnableContestArenaTeleport,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    this.actionLabel,
    this.onConfirm,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final String? actionLabel;
  final VoidCallback? onConfirm;
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

/// The chart's title row, in the ship console's type: the name in spaced
/// ink with its readings under it, HOME and the close cross at the end.
class _Header extends StatelessWidget {
  const _Header({
    required this.hasHomePlanet,
    required this.discoveredCount,
    required this.planetTotal,
    required this.markerCount,
    this.starTotal = 0,
    this.starMax = 0,
    required this.onGoHome,
    required this.onClose,
  });

  final bool hasHomePlanet;
  final int discoveredCount;
  final int planetTotal;
  final int markerCount;
  final int starTotal;
  final int starMax;
  final VoidCallback onGoHome;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    InlineSpan reading(String value, String label, Color color) => TextSpan(
      children: [
        TextSpan(text: value, style: panelLabel(11.5, color, spacing: 0.6)),
        TextSpan(
          text: ' $label',
          style: panelLabel(9, panelPalette.muted, spacing: 1.4),
        ),
      ],
    );
    const gap = TextSpan(text: '    ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'STAR CHART',
                  style: panelLabel(13, panelPalette.ink, spacing: 2.6),
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        reading(
                          '$discoveredCount/$planetTotal',
                          'PLANETS',
                          panelPalette.ink,
                        ),
                        if (starMax > 0) ...[
                          gap,
                          reading('$starTotal/$starMax', 'STARS', kChartAmber),
                        ],
                        gap,
                        reading('$markerCount', 'MARKERS', panelPalette.ink),
                      ],
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          if (hasHomePlanet) ...[
            const SizedBox(width: 8),
            _ChartChip(
              label: 'HOME',
              icon: AppIcons.home_rounded,
              accent: kChartAmber,
              active: true,
              height: 32,
              onTap: () {
                HapticFeedback.lightImpact();
                onGoHome();
              },
            ),
          ],
          CosmicCloseButton(onTap: onClose),
        ],
      ),
    );
  }
}

/// A small control in the chart's bracket frame: an icon, a word, or both.
/// [active] lights its frame in [accent].
class _ChartChip extends StatelessWidget {
  const _ChartChip({
    this.icon,
    this.label,
    required this.accent,
    required this.onTap,
    this.active = false,
    this.height = 30,
    this.width,
  });

  final IconData? icon;
  final String? label;
  final Color accent;
  final VoidCallback onTap;
  final bool active;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final ink = active ? accent : panelPalette.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: active
              ? accent.withValues(alpha: 0.85)
              : panelPalette.line.withValues(alpha: 0.75),
          bracketSize: 6,
          strokeWidth: active ? 1.2 : 1,
        ),
        child: Container(
          height: height,
          width: width,
          padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 10),
          alignment: Alignment.center,
          color: active
              ? accent.withValues(alpha: 0.12)
              : panelPalette.bg1.withValues(alpha: 0.8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A chip with a label says what it does; only a bare chip
              // needs its icon.
              if (icon != null && label == null)
                Icon(icon, size: 14, color: ink),
              if (label != null)
                Text(label!, style: panelLabel(10, ink, spacing: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The chart's one control row: marker tools on the left, planets toggle on
/// the right. They used to be stacked, which cost the chart a whole extra row
/// the moment the marker tools appeared.
class _ChartToolRow extends StatelessWidget {
  const _ChartToolRow({
    required this.showMarkerTools,
    required this.markerMode,
    required this.eraseMode,
    required this.showMarkerColors,
    required this.selectedColor,
    required this.hasMarkers,
    required this.onToggleMarkerMode,
    required this.onToggleErase,
    required this.onSelectColor,
    required this.onClearAll,
    required this.collapsed,
    required this.onToggle,
  });

  final bool showMarkerTools;
  final bool markerMode;
  final bool eraseMode;
  final bool showMarkerColors;
  final int selectedColor;
  final bool hasMarkers;
  final VoidCallback onToggleMarkerMode;
  final VoidCallback onToggleErase;
  final ValueChanged<int> onSelectColor;
  final VoidCallback onClearAll;
  final bool collapsed;

  /// Null when there are no planets to show or hide.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            if (showMarkerTools) ...[
              _ChartChip(
                icon: AppIcons.push_pin,
                width: 32,
                height: 32,
                active: markerMode,
                accent: MapMarker
                    .colors[selectedColor.clamp(0, MapMarker.typeCount - 1)],
                onTap: () {
                  HapticFeedback.selectionClick();
                  onToggleMarkerMode();
                },
              ),
              const SizedBox(width: 6),
              // Erase mode — one marker at a time. Removal used to exist only
              // as a long-press, which competes with the map's own pan gesture
              // and so was close to unusable; this makes it explicit.
              _ChartChip(
                icon: AppIcons.delete_outline_rounded,
                width: 32,
                height: 32,
                active: eraseMode,
                accent: const Color(0xFFFF6B6B),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onToggleErase();
                },
              ),
              const SizedBox(width: 6),
              if (showMarkerColors)
                Expanded(
                  child: Row(
                    children: [
                      for (var i = 0; i < MapMarker.typeCount; i++) ...[
                        Expanded(
                          child: _MarkerSwatch(
                            index: i,
                            selected: selectedColor == i && markerMode,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onSelectColor(i);
                            },
                          ),
                        ),
                        if (i < MapMarker.typeCount - 1)
                          const SizedBox(width: 3),
                      ],
                    ],
                  ),
                )
              else
                const Spacer(),
              if (hasMarkers) ...[
                const SizedBox(width: 6),
                // Small and quiet: it wipes every marker, so it should not be
                // the most inviting control in the row.
                _ChartChip(
                  label: 'CLEAR',
                  height: 26,
                  accent: panelPalette.muted,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onClearAll();
                  },
                ),
              ],
            ] else
              const Spacer(),
            if (onToggle != null) ...[
              const SizedBox(width: 8),
              _ChartChip(
                label: 'PLANETS',
                icon: collapsed
                    ? AppIcons.keyboard_arrow_down_rounded
                    : AppIcons.keyboard_arrow_up_rounded,
                accent: kChartAmber,
                active: !collapsed,
                onTap: onToggle!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARKER TOOLBAR
// ─────────────────────────────────────────────────────────────────────────────

/// One of the six marker types, drawn as its real silhouette so the picker
/// shows exactly what will land on the chart.
class _MarkerSwatch extends StatelessWidget {
  const _MarkerSwatch({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = MapMarker.colors[index];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: selected
              ? color.withValues(alpha: 0.9)
              : panelPalette.line.withValues(alpha: 0.6),
          bracketSize: 5,
          strokeWidth: selected ? 1.3 : 1,
        ),
        child: Container(
          color: selected
              ? color.withValues(alpha: 0.16)
              : panelPalette.bg1.withValues(alpha: 0.8),
          // Shape only. At the size these swatches get, 6.5px labels were
          // unreadable anyway, and the silhouette already carries the
          // identity.
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CustomPaint(
                painter: _SwatchPainter(
                  shape: MapMarker.shapes[index],
                  color: color,
                  dim: !selected,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter({
    required this.shape,
    required this.color,
    required this.dim,
  });

  final MarkerShape shape;
  final Color color;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    paintMarkerShape(
      canvas,
      Offset(size.width / 2, size.height / 2),
      6.4,
      shape,
      Paint()..color = color.withValues(alpha: dim ? 0.6 : 1.0),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  @override
  bool shouldRepaint(covariant _SwatchPainter old) =>
      old.shape != shape || old.color != color || old.dim != dim;
}

class _PlanetCarousel extends StatefulWidget {
  const _PlanetCarousel({
    required this.planets,
    required this.selectedIndex,
    required this.scrollController,
    required this.onChanged,
    this.dungeonStarsFor,
  });

  final List<CosmicPlanet> planets;
  final int selectedIndex;
  final ScrollController scrollController;
  final ValueChanged<int> onChanged;
  final int? Function(CosmicPlanet planet)? dungeonStarsFor;

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
                dungeonStars: widget.dungeonStarsFor?.call(planet),
                onTap: context.soundTap(() => widget.onChanged(index)),
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
    this.dungeonStars,
    required this.onTap,
  });

  final CosmicPlanet planet;
  final bool isSelected;

  /// Non-null for built-dungeon planets: earned dungeon stars (0..3) shown in
  /// amber. Null for coming-soon planets (no stars earned yet).
  final int? dungeonStars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const globeSize = 82.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(() {
        HapticFeedback.selectionClick();
        onTap();
      }),
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
                style: panelLabel(
                  10.5,
                  isSelected
                      ? elementInk(planet.element)
                      : panelPalette.muted.withValues(alpha: 0.6),
                  spacing: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Dungeon stars (built-dungeon planets, amber); coming-soon
            // planets show dim placeholders. Earned = solid + glowing.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final isDungeon = dungeonStars != null;
                final filled = i < (dungeonStars ?? 0);
                final fillColor = isDungeon
                    ? const Color(0xFFE4C16A)
                    : planet.color;
                return Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : 2),
                  child: Icon(
                    // Earned stars render solid/filled; unearned stay outline.
                    filled ? AppIcons.star_filled : AppIcons.star_rounded,
                    size: 12,
                    color: filled
                        ? fillColor.withValues(alpha: isSelected ? 1.0 : 0.85)
                        : CosmicScreenStyles.textMuted.withValues(
                            alpha: isSelected ? 0.28 : 0.16,
                          ),
                    shadows: filled
                        ? [
                            Shadow(
                              color: fillColor.withValues(
                                alpha: isSelected ? 0.8 : 0.4,
                              ),
                              blurRadius: 7,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
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
    return Center(
      child: IntrinsicWidth(
        child: BracketButton(
          label: 'NAVIGATE TO ${planetName(planet.element).toUpperCase()}',
          palette: panelPalette,
          accent: elementInk(planet.element),
          height: 36,
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
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
    final accent = Color.lerp(prompt.accent, Colors.white, 0.18)!;
    final canConfirm = prompt.onConfirm != null;
    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: accent.withValues(alpha: 0.75),
        bracketSize: 9,
        strokeWidth: 1.2,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 9, 9),
        color: panelPalette.bg0.withValues(alpha: 0.94),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    prompt.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: panelLabel(11.5, panelPalette.ink, spacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    prompt.subtitle.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: panelLabel(9, panelPalette.muted, spacing: 1.4),
                  ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: context.soundAction(() {
                HapticFeedback.selectionClick();
                onDismiss();
              }),
              child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  AppIcons.close_rounded,
                  color: panelPalette.muted,
                  size: 17,
                ),
              ),
            ),
            if (canConfirm) ...[
              const SizedBox(width: 4),
              BracketButton(
                label: prompt.actionLabel ?? 'TRAVEL',
                palette: panelPalette,
                accent: accent,
                height: 34,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onConfirm();
                },
              ),
            ],
          ],
        ),
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
    this.tutorialTargetPos,
    this.tutorialTargetColor,
    this.tutorialTargetLabel,
  });

  final CosmicWorld world;
  final CosmicGame game;
  final List<MapMarker> markers;
  final TransformationController transformCtrl;
  final void Function(TapDownDetails, double) onTapDown;
  final void Function(TapUpDetails, double) onTapUp;
  final void Function(LongPressStartDetails, double) onLongPress;
  final void Function({
    required Size viewport,
    required Size content,
    required double scale,
  })
  onViewportReady;
  final bool showAllContestArenas;
  final Offset? tutorialTargetPos;
  final Color? tutorialTargetColor;
  final String? tutorialTargetLabel;

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  double _lastFitSize = -1;
  final ValueNotifier<int> _pulseTick = ValueNotifier<int>(0);
  Timer? _pulseTimer;

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  /// The tutorial target is the only thing on the chart that pulses, so the
  /// pulse runs only while there is one. It steps [_pulseTick], which
  /// repaints the pin layer alone — not the chart body. The timer dies with
  /// the map (closing it removes this widget).
  void _syncPulse() {
    final wantsPulse = widget.tutorialTargetPos != null;
    if (wantsPulse && _pulseTimer == null) {
      _pulseTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        if (!mounted) return;
        _pulseTick.value++;
      });
    } else if (!wantsPulse && _pulseTimer != null) {
      _pulseTimer!.cancel();
      _pulseTimer = null;
    }
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _pulseTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Full-bleed: the chart runs to the edges instead of sitting as a
        // centred square card. The world is scaled to COVER the viewport, so
        // whichever axis is short overflows and becomes pannable rather than
        // being letterboxed away.
        final vw = constraints.maxWidth;
        final vh = constraints.maxHeight;
        final worldW = widget.world.worldSize.width;
        final worldH = widget.world.worldSize.height;
        final scale = max(vw / worldW, vh / worldH);
        final contentW = worldW * scale;
        final contentH = worldH * scale;

        if (_lastFitSize != scale) {
          _lastFitSize = scale;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onViewportReady(
              viewport: Size(vw, vh),
              content: Size(contentW, contentH),
              scale: scale,
            );
          });
        }

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: CosmicScreenStyles.bg0),
              // Far stars, fixed to the glass rather than the chart.
              const RepaintBoundary(
                child: CustomPaint(painter: _ChartStarsPainter()),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => widget.onTapDown(d, scale),
                onTapUp: (d) => widget.onTapUp(d, scale),
                onLongPressStart: (d) => widget.onLongPress(d, scale),
                child: InteractiveViewer(
                  transformationController: widget.transformCtrl,
                  minScale: 1.0,
                  maxScale: 8.0,
                  boundaryMargin: EdgeInsets.zero,
                  constrained: false,
                  // The chart body — explored haze, territories, the belt,
                  // the planets as they look in space — zooms with the
                  // fingers and is recorded once per open.
                  child: RepaintBoundary(
                    child: SizedBox(
                      width: contentW,
                      height: contentH,
                      child: CustomPaint(
                        isComplex: true,
                        willChange: false,
                        painter: _ChartBodyPainter(
                          world: widget.world,
                          game: widget.game,
                          scale: scale,
                          revealedCellCount: widget.game.revealedCells.length,
                          discoveredPlanetCount: widget.world.discoveredCount,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Everything you navigate BY — stations, landmarks, labels,
              // markers, the ship — stays one size on the glass however far
              // the chart is zoomed, and moves with it.
              IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _ChartPinsPainter(
                      world: widget.world,
                      game: widget.game,
                      scale: scale,
                      transform: widget.transformCtrl,
                      pulse: _pulseTick,
                      markers: widget.markers,
                      showAllContestArenas: widget.showAllContestArenas,
                      tutorialTargetPos: widget.tutorialTargetPos,
                      tutorialTargetColor: widget.tutorialTargetColor,
                      tutorialTargetLabel: widget.tutorialTargetLabel,
                    ),
                  ),
                ),
              ),
              const IgnorePointer(
                child: CustomPaint(painter: _ChartFramePainter()),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A sparse field of far stars behind the chart, painted once.
class _ChartStarsPainter extends CustomPainter {
  const _ChartStarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dim = PointBatch(260);
    final bright = PointBatch(40);
    for (var i = 0; i < 300; i++) {
      final x = hash01(i, 21) * size.width;
      final y = hash01(i, 43) * size.height;
      (hash01(i, 67) < 0.13 ? bright : dim).add(x, y);
    }
    dim.draw(canvas, 1.0, const Color(0x38D8D0E8));
    bright.draw(canvas, 1.5, const Color(0x70E8DCC8));
  }

  @override
  bool shouldRepaint(covariant _ChartStarsPainter oldDelegate) => false;
}

/// The chart's frame: an edge vignette, against the real screen edges.
class _ChartFramePainter extends CustomPainter {
  const _ChartFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Edge vignette so the chart melts into the console.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: 0.85,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
          stops: const [0.68, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _ChartFramePainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// LEGEND
// ─────────────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend({
    required this.markerMode,
    required this.eraseMode,
    required this.showContestTip,
  });
  final bool markerMode;
  final bool eraseMode;
  final bool showContestTip;

  @override
  Widget build(BuildContext context) {
    final hint = eraseMode
        ? 'TAP A MARKER TO REMOVE IT'
        : markerMode
        ? 'TAP TO PLACE  ·  LONG-PRESS A MARKER TO REMOVE'
        : showContestTip
        ? 'TAP A PLACE TO TRAVEL  ·  PINCH TO ZOOM'
        : 'TAP A PLACE TO TRAVEL  ·  PINCH TO ZOOM  ·  DRAG TO PAN';

    // No top rule: the legend floats over the chart on its own scrim, and a
    // hard divider line across the map was exactly the boxed-in edge this
    // layout got rid of.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          hint,
          maxLines: 1,
          style: panelLabel(9, panelPalette.muted, spacing: 1.3),
        ),
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

  /// Seconds added to the moment shown — the planet as it looks in space,
  /// turned this far.
  final double spin;
  final bool highlighted;
  final double? explicitRadius;
  final double alpha;

  /// The moment each card shows: the moon in front of Aquathos, the turning
  /// worlds at a flattering angle.
  static const double _moment = 2.7;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final art = planetArtFor(planet);
    // The same art as in space. A planet whose rings or moon reach further
    // is drawn smaller, so it keeps inside its card.
    final full = explicitRadius ?? min(size.width, size.height) * 0.42;
    final r = min(full, (size.width / 2 + 12) / art.cardReach);
    final t = _moment + spin;

    final bounds = Rect.fromCenter(
      center: c,
      width: size.width + 40,
      height: size.height + 40,
    );
    // The planet's light fades out before the card's edge instead of being
    // cut off square there.
    canvas.saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    if (highlighted) {
      // Selected: lifted by a soft pool of its own light, not a ring.
      final glow = r * 1.9;
      canvas.drawCircle(
        c,
        glow,
        Paint()
          ..shader = RadialGradient(
            colors: [
              planet.color.withValues(alpha: 0.22),
              planet.color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: glow)),
      );
    }
    art.paintBack(canvas, c, r, t);
    art.paintBody(canvas, c, r, t);
    art.paintFront(canvas, c, r, t);
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.radial(
          c,
          bounds.shortestSide / 2,
          const [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          const [0.0, 0.6, 1.0],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlanetPreviewPainter old) =>
      old.planet.element != planet.element ||
      old.highlighted != highlighted ||
      old.explicitRadius != explicitRadius ||
      old.alpha != alpha ||
      old.spin != spin;
}

// ─────────────────────────────────────────────────────────────────────────────
// CHART PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

/// The chart body, in chart units (world × [scale]), zoomed by the viewer:
/// explored space as a haze, each found planet's territory as a pool of its
/// own light, the belt as dust, and the planets themselves — the same art as
/// in space, at chart size. Recorded once per open, re-recorded only when a
/// cell is revealed or a planet found.
class _ChartBodyPainter extends CustomPainter {
  const _ChartBodyPainter({
    required this.world,
    required this.game,
    required this.scale,
    required this.revealedCellCount,
    required this.discoveredPlanetCount,
  });

  final CosmicWorld world;
  final CosmicGame game;
  final double scale;
  final int revealedCellCount;
  final int discoveredPlanetCount;

  /// The moment each planet is shown at, the same as the carousel cards.
  static const double _moment = 2.7;

  /// The radius planet art is drawn at before it is scaled down, so its
  /// grains and rings keep their proportions.
  static const double _artR = 30;

  static final Map<Color, ui.Shader> _territory = {};

  /// A planet on the chart is drawn this much bigger than it is in the
  /// world, so it reads at a glance.
  static double planetRadius(double worldRadius, double scale) =>
      max(4.0, worldRadius * scale * 1.5);

  @override
  void paint(Canvas canvas, Size size) {
    final ws = world.worldSize;
    final gw = (ws.width / CosmicGame.fogCellSize).ceil();
    final gh = (ws.height / CosmicGame.fogCellSize).ceil();
    ChartFog.paint(
      canvas,
      Rect.fromLTWH(0, 0, ws.width * scale, ws.height * scale),
      game.revealedCells,
      gw,
      gh,
    );

    // Territories: a pool of each planet's own tint, strongest at its heart,
    // gone at its border — so the map shows where each element's wild
    // Alchemons live without drawing a line round them.
    for (final planet in world.planets) {
      if (!planet.discovered) continue;
      final art = planetArtFor(planet);
      final tint = art.territoryTint;
      final s = (art.territoryStrength * 5).clamp(0.25, 0.6);
      final shader = _territory[tint] ??= ui.Gradient.radial(
        Offset.zero,
        1,
        [
          tint.withValues(alpha: s),
          tint.withValues(alpha: s * 0.45),
          tint.withValues(alpha: 0),
        ],
        const [0.0, 0.55, 1.0],
      );
      paintDisc(
        canvas,
        shader,
        planet.position * scale,
        kPlanetTerritoryRadius * scale,
      );
    }

    // The asteroid belt: a faint band of dust with its rocks as grains.
    final belt = game.asteroidBelt;
    final bc = belt.center * scale;
    final ri = belt.innerRadius * scale, ro = belt.outerRadius * scale;
    canvas.drawCircle(
      bc,
      ro,
      Paint()
        ..shader = ui.Gradient.radial(
          bc,
          ro,
          const [
            Color(0x00A08C74),
            Color(0x00A08C74),
            Color(0x1CA08C74),
            Color(0x00A08C74),
          ],
          [0.0, ri / ro * 0.97, (ri / ro + 1) / 2, 1.0],
        ),
    );
    final rocks = PointBatch(700);
    for (var i = 0; i < 700; i++) {
      final rr = ri + (ro - ri) * hash01(i, 71);
      final a = hash01(i, 73) * 2 * pi;
      rocks.add(bc.dx + cos(a) * rr, bc.dy + sin(a) * rr);
    }
    rocks.draw(canvas, 0.7, const Color(0x80A8957D));

    // The planets, as they look in space.
    for (final planet in world.planets) {
      if (!planet.discovered) continue;
      final art = planetArtFor(planet);
      final r = planetRadius(planet.radius, scale);
      final saved = art.wake;
      art.wake = null;
      canvas.save();
      canvas.translate(planet.position.dx * scale, planet.position.dy * scale);
      canvas.scale(r / _artR);
      art.paintBack(canvas, Offset.zero, _artR, _moment);
      art.paintBody(canvas, Offset.zero, _artR, _moment);
      art.paintFront(canvas, Offset.zero, _artR, _moment);
      canvas.restore();
      art.wake = saved;
    }

    // Home, wearing what it wears.
    if (game.homePlanet case final hp?) {
      final r = planetRadius(hp.visualRadius, scale);
      game.paintHomeShowcase(
        canvas,
        Rect.fromCircle(center: hp.position * scale, radius: r * 2.6),
        _moment,
        wearing: game.activeCustomizations,
        color: hp.activeColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartBodyPainter old) =>
      scale != old.scale ||
      revealedCellCount != old.revealedCellCount ||
      discoveredPlanetCount != old.discoveredPlanetCount ||
      !identical(game, old.game);
}

/// Everything you navigate by, on the glass: one size however far the chart
/// is zoomed, carried along with it by [transform]. Labels come in as the
/// chart is zoomed — planets always, stations next, then the lesser places —
/// so a whole-galaxy view is never a wall of words.
class _ChartPinsPainter extends CustomPainter {
  _ChartPinsPainter({
    required this.world,
    required this.game,
    required this.scale,
    required this.transform,
    required ValueListenable<int> pulse,
    required this.markers,
    required this.showAllContestArenas,
    this.tutorialTargetPos,
    this.tutorialTargetColor,
    this.tutorialTargetLabel,
  }) : _pulse = pulse,
       super(repaint: Listenable.merge([transform, pulse]));

  final CosmicWorld world;
  final CosmicGame game;
  final double scale;
  final TransformationController transform;
  final ValueListenable<int> _pulse;
  final List<MapMarker> markers;
  final bool showAllContestArenas;
  final Offset? tutorialTargetPos;
  final Color? tutorialTargetColor;
  final String? tutorialTargetLabel;

  static const Color _derelict = Color(0xFF8FA3B0);
  static const Color _anomaly = Color(0xFFB388FF);
  static const Color _portal = Color(0xFF8B5CF6);
  static const Color _lair = Color(0xFFE0453A);
  static const Color _prismatic = Color(0xFFFF5FD2);
  static const Color _nexus = Color(0xFFB388FF);
  static const Color _blood = Color(0xFFC62828);

  static final _tpCache = <int, TextPainter>{};

  static TextPainter _tp(String text, Color color, double size) {
    final key = Object.hash(text, color, size);
    return _tpCache.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'monospace',
            color: color,
            fontSize: size,
            fontWeight: FontWeight.w700,
            letterSpacing: size * 0.16,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  /// [text] centred under a mark of radius [r] at [at].
  static void _label(
    Canvas c,
    String text,
    Color color,
    Offset at,
    double r, {
    double size = 8,
  }) {
    final tp = _tp(text, color, size);
    tp.paint(c, Offset(at.dx - tp.width / 2, at.dy + r + 4));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final m = transform.value;
    final zoom = m.getMaxScaleOnAxis();
    // How many screen pixels a world unit is right now.
    final es = scale * zoom;
    final view = (Offset.zero & size).inflate(28);
    Offset at(Offset world) => MatrixUtils.transformPoint(m, world * scale);
    // Marks grow a little as the chart is zoomed in, never a lot.
    final k = (0.85 + 0.1 * zoom).clamp(0.9, 1.25);

    final stationLabels = es >= 0.024;
    final landmarkLabels = es >= 0.03;
    final minorLabels = es >= 0.04;

    // Sealed elemental caches — pinned once the ship has been right on top
    // of one.
    for (final cache in game.elementalCacheField.caches) {
      if (!cache.discovered || !cache.isPresent) continue;
      final p = at(cache.position);
      if (!view.contains(p)) continue;
      paintChartGlyph(canvas, ChartGlyph.cache, p, cache.color, r: 4.6 * k);
      if (landmarkLabels) {
        // Named by its riddle, not its element — the chart should not hand
        // you the answer the seal is asking for.
        _label(
          canvas,
          cacheHintFor(cache.element).toUpperCase(),
          elementInk(cache.element).withValues(alpha: 0.75),
          p,
          4.6 * k,
          size: 7,
        );
      }
    }

    // Galaxy whirls.
    for (final whirl in game.galaxyWhirls) {
      if (whirl.state == WhirlState.completed) continue;
      final p = at(whirl.position);
      if (!view.contains(p)) continue;
      final col = elementColor(whirl.element);
      paintChartGlyph(canvas, ChartGlyph.whirl, p, col, r: 5.5 * k);
      if (landmarkLabels) {
        _label(
          canvas,
          'LV${whirl.level} ${whirl.hordeTypeName.toUpperCase()}',
          elementInk(whirl.element).withValues(alpha: 0.8),
          p,
          6 * k,
          size: 7,
        );
      }
    }

    // Contest arenas.
    for (final arena in world.contestArenas) {
      if (!showAllContestArenas && !arena.discovered) continue;
      final p = at(arena.position);
      if (!view.contains(p)) continue;
      // A mastered arena burns in the champion's gold.
      final col = arena.masteredAt != null
          ? kContestChampionGold
          : arena.trait.color;
      paintChartGlyph(canvas, ChartGlyph.contest, p, col, r: 5 * k);
      if (minorLabels) {
        _label(
          canvas,
          '${arena.trait.label.toUpperCase()} CONTEST',
          col.withValues(alpha: 0.8),
          p,
          5 * k,
          size: 7,
        );
      }
    }

    // Space POIs: stations, the survival portal, and the lesser places.
    for (final poi in game.spacePOIs) {
      if (poi.type == POIType.comet || poi.type == POIType.stardustScanner) {
        continue;
      }
      final kind = stationKindFor(poi.type);
      final isShop = kind != null && kind != StationKind.planetScanner;
      final isPortal = poi.type == POIType.survivalPortal;
      if (!poi.discovered && !isShop && !isPortal) continue;
      final p = at(poi.position);
      if (!view.contains(p)) continue;
      final spent = poi.interacted ? 0.45 : 1.0;

      switch (poi.type) {
        case POIType.nebula:
          final col = elementColor(poi.element);
          paintChartGlyph(
            canvas,
            ChartGlyph.nebula,
            p,
            col,
            r: 4.6 * k,
            dim: spent,
            salt: poi.position.dx.toInt() & 63,
          );
          if (minorLabels) {
            _label(
              canvas,
              '${poi.element.toUpperCase()} NEBULA',
              elementInk(poi.element).withValues(alpha: 0.7 * spent),
              p,
              5 * k,
              size: 7,
            );
          }
        case POIType.derelict:
          paintChartGlyph(
            canvas,
            ChartGlyph.derelict,
            p,
            _derelict,
            r: 4.6 * k,
            dim: spent,
          );
          if (minorLabels) {
            _label(
              canvas,
              'DERELICT',
              _derelict.withValues(alpha: 0.75 * spent),
              p,
              4.6 * k,
              size: 7,
            );
          }
        case POIType.warpAnomaly:
          paintChartGlyph(
            canvas,
            ChartGlyph.anomaly,
            p,
            _anomaly,
            r: 4.4 * k,
            dim: spent,
          );
          if (minorLabels) {
            _label(
              canvas,
              'ANOMALY',
              _anomaly.withValues(alpha: 0.75 * spent),
              p,
              5.5 * k,
              size: 7,
            );
          }
        case POIType.survivalPortal:
          if (poi.discovered) {
            paintChartGlyph(canvas, ChartGlyph.portal, p, _portal, r: 5 * k);
          } else {
            paintChartGlyph(canvas, ChartGlyph.signal, p, _portal, r: 5 * k);
          }
          if (stationLabels) {
            _label(
              canvas,
              poi.discovered ? 'SURVIVAL PORTAL' : 'UNKNOWN SIGNAL',
              const Color(
                0xFFC4A8FF,
              ).withValues(alpha: poi.discovered ? 0.9 : 0.5),
              p,
              6.5 * k,
            );
          }
        default:
          if (kind == null) continue;
          paintChartGlyph(
            canvas,
            ChartGlyph.station,
            p,
            kind.accent,
            r: 5.6 * k,
            dim: poi.discovered ? 1 : 0.35,
          );
          if (stationLabels && poi.discovered) {
            _label(
              canvas,
              kind.title,
              Color.lerp(kind.accent, Colors.white, 0.25)!,
              p,
              5.6 * k,
            );
          }
      }
    }

    // Prismatic field.
    final pf = game.prismaticField;
    if (pf.discovered) {
      final p = at(pf.position);
      if (view.contains(p)) {
        final r = max(6.0 * k, pf.radius * es * 0.35);
        paintChartGlyph(canvas, ChartGlyph.prismatic, p, _prismatic, r: r);
        if (landmarkLabels) {
          _label(
            canvas,
            'PRISMATIC AURORA',
            const Color(0xFFFFA8E6),
            p,
            r * 1.4,
            size: 7.5,
          );
        }
      }
    }

    // Elemental Nexus.
    final nx = world.elementalNexus;
    if (nx.discovered) {
      final p = at(nx.position);
      if (view.contains(p)) {
        paintChartGlyph(canvas, ChartGlyph.nexus, p, _nexus, r: 5.2 * k);
        if (landmarkLabels) {
          _label(
            canvas,
            'ELEMENTAL NEXUS',
            const Color(0xFFCDB4FF),
            p,
            9 * k,
            size: 7.5,
          );
        }
      }
    }

    // The Blood Ring: only a faint warmth in the dark until it is found.
    final ring = world.bloodRing;
    final ringAt = at(ring.position);
    if (view.contains(ringAt)) {
      if (!ring.discovered) {
        paintChartGlyph(canvas, ChartGlyph.bloodHint, ringAt, _blood, r: 6);
      } else {
        paintChartGlyph(canvas, ChartGlyph.bloodRing, ringAt, _blood, r: 6 * k);
        if (landmarkLabels) {
          _label(
            canvas,
            ring.ritualCompleted ? 'BLOOD PORTAL' : 'BLOOD RING',
            const Color(0xFFFF8A80),
            ringAt,
            8 * k,
            size: 7.5,
          );
        }
      }
    }

    // The nearest waiting boss lair.
    BossLair? nearestLair;
    var nearestDist = double.infinity;
    for (final lair in game.bossLairs) {
      if (lair.state != BossLairState.waiting) continue;
      final d = (lair.position - game.ship.pos).distance;
      if (d < nearestDist) {
        nearestDist = d;
        nearestLair = lair;
      }
    }
    if (nearestLair != null) {
      final p = at(nearestLair.position);
      if (view.contains(p)) {
        paintChartGlyph(canvas, ChartGlyph.lair, p, _lair, r: 5.6 * k);
        if (landmarkLabels) {
          _label(
            canvas,
            'LV${nearestLair.level} '
            '${nearestLair.template.name.toUpperCase()}',
            const Color(0xFFFF7A6E),
            p,
            6 * k,
            size: 7.5,
          );
        }
      }
    }

    // Planet names, under the planets the body draws.
    for (final planet in world.planets) {
      if (!planet.discovered) continue;
      final p = at(planet.position);
      if (!view.contains(p)) continue;
      final r =
          _ChartBodyPainter.planetRadius(planet.radius, scale) *
          zoom *
          planetArtFor(planet).cardReach;
      _label(
        canvas,
        planetName(planet.element).toUpperCase(),
        elementInk(planet.element),
        p,
        r,
        size: 8.5,
      );
    }

    if (game.homePlanet case final hp?) {
      final p = at(hp.position);
      if (view.contains(p)) {
        final r = _ChartBodyPainter.planetRadius(hp.visualRadius, scale) * zoom;
        _label(canvas, 'HOME', kChartAmber, p, r * 1.15, size: 9);
      }
    }

    // Markers — each type has its own silhouette as well as its own colour,
    // so they stay distinguishable without relying on hue alone.
    final markerInk = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final marker in markers) {
      final p = at(marker.worldPos);
      if (!view.contains(p)) continue;
      paintDisc(canvas, stoneLightFor(marker.color).leak, p, 12, 0.6);
      paintMarkerShape(
        canvas,
        p,
        5,
        marker.shape,
        Paint()..color = marker.color,
        markerInk,
      );
    }

    // The tutorial signal, breathing.
    if (tutorialTargetPos case final target?) {
      final p = at(target);
      final col = tutorialTargetColor ?? _portal;
      final light = stoneLightFor(col);
      final breath = 0.55 + 0.45 * sin(_pulse.value * 0.42);
      paintDisc(canvas, light.leak, p, 12 + breath * 9, 0.9);
      paintDisc(canvas, light.spark, p, 4.5 + breath * 1.5, 1);
      if (tutorialTargetLabel case final label?) {
        _label(canvas, label, Color.lerp(col, Colors.white, 0.3)!, p, 9);
      }
    }

    // The ship, on top of everything.
    paintChartShip(canvas, at(game.ship.pos), game.ship.angle);
  }

  @override
  bool shouldRepaint(covariant _ChartPinsPainter old) => true;
}
