import 'package:alchemons/screens/wilderness_peek_dialog.dart';
import 'dart:async';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/rift_state.dart';
import 'dart:math' as math;

import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:alchemons/widgets/pulsing_hitbox_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:alchemons/models/scenes/arcane/arcane_scene.dart';
import 'package:alchemons/models/wilderness.dart' show PartyMember;
import 'package:alchemons/screens/party_picker/party_picker.dart';
import 'package:alchemons/screens/scenes/scene_page.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/wilderness_access_service.dart';
import 'package:alchemons/utils/faction_util.dart';
// for FactionTheme
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:alchemons/widgets/app_icons.dart';

TextStyle _display(
  BuildContext context,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w500,
  double letterSpacing = 0,
  FontStyle fontStyle = FontStyle.normal,
}) {
  final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
  return base.copyWith(
    color: color,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
  );
}

class _BracketFramePainter extends CustomPainter {
  const _BracketFramePainter({
    required this.color,
    required this.bracketSize,
    required this.strokeWidth,
  });

  final Color color;
  final double bracketSize;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final s = bracketSize;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, s)
      ..lineTo(0, 0)
      ..lineTo(s, 0)
      ..moveTo(w - s, 0)
      ..lineTo(w, 0)
      ..lineTo(w, s)
      ..moveTo(0, h - s)
      ..lineTo(0, h)
      ..lineTo(s, h)
      ..moveTo(w - s, h)
      ..lineTo(w, h)
      ..lineTo(w, h - s);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BracketFramePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bracketSize != bracketSize ||
      oldDelegate.strokeWidth != strokeWidth;
}

class MapScreen extends StatefulWidget {
  final bool isTutorial;
  final void Function(NavSection section, {int? breedInitialTab})?
  onNavigateSection;

  const MapScreen({super.key, this.isTutorial = false, this.onNavigateSection});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  bool _arcaneUnlocked = false;
  late final AnimationController _mapController;
  late final Animation<double> _mapScale;
  late final Animation<double> _mapOpacity;

  @override
  void initState() {
    super.initState();

    _mapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _mapScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _mapController, curve: Curves.easeOutCubic),
    );

    _mapOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mapController, curve: Curves.easeOutQuad),
    );

    // Start the animation after the first frame so it feels like
    // the map is animating in instead of just appearing.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      precacheImage(const AssetImage('assets/images/ui/map.png'), context);
      // Check if arcane portal is unlocked
      final db = context.read<AlchemonsDatabase>();
      final v = await db.settingsDao.getSetting('arcane_portal_unlocked');
      if (mounted && v == '1') setState(() => _arcaneUnlocked = true);
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) _mapController.forward();
    });
  }

  static const Map<String, String> _biomeDisplayNames = {
    'valley': 'Verdant Valley',
    'sky': 'Skyward Reach',
    'volcano': 'Ashen Volcano',
    'swamp': 'Sunken Swamp',
    'arcane': 'Arcane Expanse',
  };

  Future<void> _handlePeekRegion(String biomeId) async {
    if (widget.isTutorial) return;

    final spawnService = context.read<WildernessSpawnService>();
    final constellations = context.read<ConstellationEffectsService>();

    // Only available if the constellation is unlocked
    if (!constellations.hasWildernessPreview()) {
      _showToast(
        context,
        'Unlock Alchemic Wild Peek to preview wild spawns.',
        AppIcons.visibility_off_rounded,
        Colors.orange.shade400,
      );
      return;
    }

    final spawnPointIds = spawnService.getActiveSpawnPoints(biomeId);
    if (spawnPointIds.isEmpty) {
      _showToast(
        context,
        'No wild creatures detected in this area.',
        AppIcons.search_off_rounded,
        Colors.orange.shade400,
      );
      return;
    }

    final repo = context.read<CreatureCatalog>();
    final spawns = <PeekedSpawn>[];
    for (final id in spawnPointIds) {
      final roll = spawnService.getSpawnAt(biomeId, id);
      if (roll == null) {
        spawns.add(const PeekedSpawn(rarityName: 'unknown'));
        continue;
      }
      spawns.add(
        PeekedSpawn(
          rarityName: roll.rarity.name,
          creature: repo.getCreatureById(roll.speciesId),
          fallbackId: roll.speciesId,
        ),
      );
    }

    if (!mounted) return;
    await showWildernessPeekDialog(
      context: context,
      biomeName: _biomeDisplayNames[biomeId] ?? biomeId,
      spawns: spawns,
      onResetSpawns: () async {
        await spawnService.clearSceneSpawns(biomeId);
        if (!mounted) return;
        _showToast(
          context,
          'Spawns cleared for this biome.',
          AppIcons.refresh_rounded,
          Colors.orange.shade400,
        );
      },
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();

    return ParticleBackgroundScaffold(
      whiteBackground: theme.brightness == Brightness.light,
      body: PopScope(
        canPop: !widget.isTutorial,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && widget.isTutorial) {
            _showTutorialBlockedDialog();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: FloatingCloseButton(
            onTap: () {
              if (widget.isTutorial) {
                _showTutorialBlockedDialog();
                return;
              }
              Navigator.pop(context);
            },
            theme: theme,
          ),
          body: SafeArea(
            child: Column(
              children: [
                _HeaderBar(
                  theme: theme,
                  onInfo: () {
                    showDialog(
                      context: context,
                      builder: (_) => _InfoDialog(theme: theme),
                    );
                  },
                  isTutorial: widget.isTutorial,
                ),

                const SizedBox(height: 12),

                if (!widget.isTutorial) _RiftBanner(theme: theme),

                if (!widget.isTutorial) const SizedBox(height: 16),

                // Show tutorial hint
                if (widget.isTutorial) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.accent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accent.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.explore_rounded,
                          color: theme.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'TAP A GLOWING AREA TO ENTER A REALM.',
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // MAP AREA
                // MAP AREA (animated in)
                Expanded(
                  child: AnimatedBuilder(
                    animation: _mapController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _mapOpacity.value,
                        child: Transform.scale(
                          scale: _mapScale.value,
                          child: child,
                        ),
                      );
                    },
                    child: _ExpeditionMap(
                      theme: theme,
                      isTutorial: widget.isTutorial,
                      arcaneUnlocked: _arcaneUnlocked,
                      onSelectRegion: (biomeId, scene) {
                        _handleRegionTap(context, biomeId, scene);
                      },
                      onPeekRegion: (biomeId) {
                        _handlePeekRegion(biomeId);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTutorialBlockedDialog() {
    final theme = context.read<FactionTheme>();

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E27).withValues(alpha: .95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.accent, width: 1.4),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.lock_outline, color: theme.accent, size: 28),
              const SizedBox(height: 12),
              Text(
                'Tutorial In Progress',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please complete your first expedition to continue.',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 12,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.accent, width: 1.4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: theme.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // TAP HANDLER FOR MAP MARKERS
  // --------------------------------------------------
  Future<void> _handleRegionTap(
    BuildContext context,
    String biomeId,
    SceneDefinition scene,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final access = WildernessAccessService(db);
    context.read<FactionService>();
    final spawnService = context.read<WildernessSpawnService>();

    final sceneSpawnCount = spawnService.getSceneSpawnCount(biomeId);
    if (sceneSpawnCount == 0) {
      _showToast(
        context,
        'No creatures detected in this area',
        AppIcons.search_off_rounded,
        Colors.orange.shade400,
      );
      return;
    }

    // During tutorial, skip access checks
    if (!widget.isTutorial) {
      // <-- Changed: only check access when NOT in tutorial
      var ok = await access.canEnter(biomeId);

      if (!ok) {
        final left = access.timeUntilReset();
        final hh = left.inHours;
        final mm = left.inMinutes.remainder(60);
        final ss = left.inSeconds.remainder(60);

        if (!context.mounted) return;
        _showToast(
          context,
          'Breeding ground refreshes in ${hh}h ${mm}m ${ss}s',
          AppIcons.schedule_rounded,
          Colors.orange.shade400,
        );
        return;
      }
    }

    // choose party (skip during tutorial - use auto party)
    List<PartyMember> selectedParty;

    if (!context.mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PartyPickerScreen(
          enforceUniqueSpecies: false,
          teamStorageKey: 'saved_teams_wilderness',
        ),
      ),
    );
    if (result == null) return;
    selectedParty = (result as List).cast<PartyMember>();

    // consume entry (skip during tutorial)
    if (!widget.isTutorial) {
      await access.markEntered(biomeId);
    }

    // go to biome scene
    if (!context.mounted) return;

    await VoidPortal.pushLandscape<bool>(
      context,
      page: ScenePage(
        scene: scene,
        sceneId: biomeId,
        party: selectedParty,
        isTutorial: widget.isTutorial,
        onNavigateSection: widget.onNavigateSection,
      ),
    );
  }

  void _showToast(
    BuildContext context,
    String message,
    IconData icon,
    Color color,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        showCloseIcon: true,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
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


// =====================================================
// PENDING RIFT BANNER
// =====================================================

/// Surfaces the open rift so a persisted portal is findable.
///
/// A rift that survives leaving the scene is only half a fix if the player has
/// to remember which biome it was in and guess how long is left. This names
/// the biome, counts down, and says whether the required faction key is
/// already in the bag — the whole point of the window is to go and get one.
class _RiftBanner extends StatefulWidget {
  const _RiftBanner({required this.theme});
  final FactionTheme theme;

  @override
  State<_RiftBanner> createState() => _RiftBannerState();
}

class _RiftBannerState extends State<_RiftBanner> {
  PendingRift? _rift;
  int _keyQty = 0;
  Timer? _tick;

  static const _biomeNames = {
    'valley': 'Verdant Valley',
    'sky': 'Skyward Reach',
    'volcano': 'Ashen Volcano',
    'swamp': 'Sunken Swamp',
    'arcane': 'Arcane Expanse',
  };

  @override
  void initState() {
    super.initState();
    _load();
    // Once a minute is enough for an 8h countdown shown in whole minutes.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final db = context.read<AlchemonsDatabase>();
    final rift = PendingRift.deserialise(
      await db.settingsDao.getSetting('wild_rift_pending_v1'),
    );
    var qty = 0;
    if (rift != null) {
      qty = await db.inventoryDao.getItemQty(
        InvKeys.portalKeyForFaction(rift.factionName),
      );
    }
    if (!mounted) return;
    setState(() {
      _rift = rift;
      _keyQty = qty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rift = _rift;
    final now = DateTime.now().toUtc();
    if (rift == null || !rift.isOpen(now)) return const SizedBox.shrink();

    final faction = rift.factionName;
    final label = faction[0].toUpperCase() + faction.substring(1);
    final hasKey = _keyQty > 0;
    final accent = hasKey
        ? const Color(0xFF6FD08C)
        : const Color(0xFFE0885A);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Icon(AppIcons.auto_awesome_rounded, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$label rift open in '
                  '${_biomeNames[rift.sceneId] ?? rift.sceneId}',
                  style: TextStyle(
                    color: widget.theme.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasKey
                      ? 'Closes in ${rift.remainingLabel(now)} · key in hand'
                      : 'Closes in ${rift.remainingLabel(now)} · '
                            'needs a $label Portal Key',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// HEADER BAR
// =====================================================

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.theme,
    required this.onInfo,
    this.isTutorial = false,
  });

  final FactionTheme theme;
  final VoidCallback onInfo;
  final bool isTutorial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Column(
        children: [
          // top row: back + info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40, height: 40),
              // center title/subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      isTutorial ? 'First Expedition' : 'Fusing Expeditions',
                      style: _display(
                        context,
                        23,
                        theme.text,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTutorial
                          ? 'Begin your journey into the wilderness'
                          : 'Discover wild Alchemons & attempt fusions',
                      style: _display(
                        context,
                        13,
                        theme.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // info
              GestureDetector(
                onTap: onInfo,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CustomPaint(
                    painter: _BracketFramePainter(
                      color: theme.textMuted.withValues(alpha: 0.38),
                      bracketSize: 8,
                      strokeWidth: 1,
                    ),
                    child: Icon(
                      AppIcons.info_outline_rounded,
                      color: theme.text,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================================================
// SPAWN DEBUG PANEL
// =====================================================
class SpawnDebugPanel extends StatelessWidget {
  const SpawnDebugPanel({
    super.key,
    required this.theme,
    required this.spawnService,
  });

  final FactionTheme theme;
  final WildernessSpawnService spawnService;

  @override
  Widget build(BuildContext context) {
    final biomes = [
      ('valley', 'Valley'),
      ('sky', 'Sky'),
      ('volcano', 'Volcano'),
      ('swamp', 'Swamp'),
      ('arcane', 'Arcane Portal'),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.accent.withValues(alpha: .35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.bug_report, size: 14, color: theme.accent),
              const SizedBox(width: 6),
              Text(
                'Next Spawn Times',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...biomes.map((biome) {
            final biomeId = biome.$1;
            final biomeName = biome.$2;
            final nextDue = spawnService.getNextSpawnTime(biomeId);

            final spawnCount = spawnService.getSceneSpawnCount(biomeId);

            String timeText;
            if (nextDue == null) {
              timeText = 'Calculating...';
            } else {
              final now = DateTime.now().toUtc().millisecondsSinceEpoch;
              final diff = nextDue - now;

              if (diff <= 0) {
                timeText = 'Due now!';
              } else {
                final minutes = diff ~/ 60000;
                final seconds = (diff % 60000) ~/ 1000;
                timeText = '${minutes}m ${seconds}s';
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$biomeName: $timeText',
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (spawnCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: theme.accent, width: 1),
                      ),
                      child: Text(
                        '$spawnCount active',
                        style: TextStyle(
                          color: theme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// =====================================================
// MAP + MARKERS
// =====================================================
class _ExpeditionMap extends StatelessWidget {
  const _ExpeditionMap({
    required this.theme,
    required this.onSelectRegion,
    this.isTutorial = false,
    this.onPeekRegion,
    this.arcaneUnlocked = false,
  });

  final FactionTheme theme;
  final void Function(String biomeId, SceneDefinition scene) onSelectRegion;
  final bool isTutorial;
  final void Function(String biomeId)? onPeekRegion; // NEW
  final bool arcaneUnlocked;

  @override
  Widget build(BuildContext context) {
    final spawnService = context.watch<WildernessSpawnService>();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the actual size the map will occupy (square/circular)
        final size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;

        Widget hotspot({
          required double leftPct,
          required double topPct,
          required String biomeId,
          required SceneDefinition scene,
        }) {
          // Use the calculated size instead of separate width/height
          final dx = size * leftPct;
          final dy = size * topPct;

          final hasSpawns = scene.spawnPoints.any(
            (sp) => spawnService.hasSpawnAt(biomeId, sp.id),
          );

          return Positioned(
            left: dx - 70,
            top: dy - 70,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelectRegion(biomeId, scene),
              onLongPress: () {
                if (onPeekRegion != null) {
                  HapticFeedback.selectionClick();
                  onPeekRegion!(biomeId);
                }
              },
              child: SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (hasSpawns)
                      PulsingDebugHitbox(
                        size: 125,
                        color: Colors.red,
                        clipOval: true,
                      ),
                    // Below centre, clear of the biome name painted into the
                    // map art.
                    Align(
                      alignment: const Alignment(0, 0.62),
                      child: _BiomeTimerPill(
                        biomeId: biomeId,
                        spawnService: spawnService,
                        hasSpawns: hasSpawns,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                ClipOval(
                  child: Container(
                    color: const Color.fromARGB(255, 48, 69, 82),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Image.asset(
                        gaplessPlayback: true,
                        'assets/images/ui/map.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                // HOTSPOTS
                hotspot(
                  leftPct: 0.3,
                  topPct: 0.3,
                  biomeId: 'valley',
                  scene: valleySceneCorrected,
                ),
                hotspot(
                  leftPct: 0.72,
                  topPct: 0.3,
                  biomeId: 'sky',
                  scene: skyScene,
                ),
                hotspot(
                  leftPct: 0.25,
                  topPct: 0.75,
                  biomeId: 'volcano',
                  scene: volcanoScene,
                ),
                hotspot(
                  leftPct: 0.75,
                  topPct: 0.72,
                  biomeId: 'swamp',
                  scene: swampScene,
                ),

                // ARCANE PORTAL VORTEX — centre of map
                if (arcaneUnlocked) ...[
                  _ArcaneVortex(
                    mapSize: size,
                    hasSpawns: spawnService.getSceneSpawnCount('arcane') > 0,
                    onTap: () => onSelectRegion('arcane', arcaneScene),
                  ),
                  Positioned(
                    left: size * 0.5 - 45,
                    top: size * 0.5 + 34,
                    child: SizedBox(
                      width: 90,
                      child: Center(
                        child: _BiomeTimerPill(
                          biomeId: 'arcane',
                          spawnService: spawnService,
                          hasSpawns:
                              spawnService.getSceneSpawnCount('arcane') > 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}


// =====================================================
// BIOME SPAWN TIMER PILL
// =====================================================

/// The spawn countdown, sitting on the biome it belongs to.
///
/// These used to be a row of boxes above the map, which meant reading
/// "Swamp 47m 28s" and then hunting for Swamp on the map — two lookups for one
/// decision — while printing each biome's name a second time next to the one
/// already painted into the artwork.
///
/// Carries its own one-second ticker rather than rebuilding the map screen:
/// the parent holds the map image and the hotspot stack, and none of that
/// needs to repaint to advance a clock.
class _BiomeTimerPill extends StatefulWidget {
  const _BiomeTimerPill({
    required this.biomeId,
    required this.spawnService,
    required this.hasSpawns,
  });

  final String biomeId;
  final WildernessSpawnService spawnService;

  /// Something is already waiting to be caught — more useful than a countdown.
  final bool hasSpawns;

  @override
  State<_BiomeTimerPill> createState() => _BiomeTimerPillState();
}

class _BiomeTimerPillState extends State<_BiomeTimerPill> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Seconds only matter when the wait is short; above an hour they are noise.
  String _label(int? dueMs) {
    if (dueMs == null) return '--';
    final diff = dueMs - DateTime.now().toUtc().millisecondsSinceEpoch;
    if (diff <= 0) return 'DUE';
    final total = diff ~/ 1000;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final sec = total % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${sec}s';
    return '${sec}s';
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.hasSpawns;
    final text = ready
        ? 'READY'
        : _label(widget.spawnService.getNextSpawnTime(widget.biomeId));
    final accent = ready ? const Color(0xFF7BE38B) : const Color(0xFFE4C16A);

    // Isolated so the ticking text cannot dirty the map behind it.
    return RepaintBoundary(
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xE60A0D12),
            border: Border.all(color: accent.withValues(alpha: 0.7)),
            boxShadow: const [
              BoxShadow(color: Color(0xAA000000), blurRadius: 6),
            ],
          ),
          child: Text(
            text,
            style: TextStyle(
              color: ready ? accent : const Color(0xFFEDE3CF),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// ARCANE VORTEX (black hole in map centre)
// =====================================================
class _ArcaneVortex extends StatefulWidget {
  final double mapSize;
  final VoidCallback onTap;
  final bool hasSpawns;
  const _ArcaneVortex({
    required this.mapSize,
    required this.onTap,
    this.hasSpawns = false,
  });

  @override
  State<_ArcaneVortex> createState() => _ArcaneVortexState();
}

class _ArcaneVortexState extends State<_ArcaneVortex>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.hasSpawns ? 3 : 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const vortexSize = 100.0;
    final cx = widget.mapSize * 0.50 - vortexSize / 2;
    final cy = widget.mapSize * 0.50 - vortexSize / 2;

    return Positioned(
      left: cx,
      top: cy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          width: vortexSize,
          height: vortexSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.hasSpawns)
                PulsingDebugHitbox(
                  size: 90,
                  color: Colors.black,
                  clipOval: true,
                ),
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) =>
                    CustomPaint(painter: _VortexPainter(t: _ctrl.value)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VortexPainter extends CustomPainter {
  final double t;
  const _VortexPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final pulse = (math.sin(t * math.pi * 2) + 1) / 2;

    // Outer event-horizon glow
    canvas.drawCircle(
      center,
      size.width * 0.48,
      Paint()
        ..color = const Color(0xFF7C3AED).withValues(alpha: 0.08 + pulse * 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    // Dark accretion disc rings
    for (int ring = 0; ring < 3; ring++) {
      final r = size.width * (0.18 + ring * 0.10);
      final alpha = (0.12 - ring * 0.03 + pulse * 0.04).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = const Color(0xFF7C3AED).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 - ring * 0.2,
      );
    }

    // Spiral arms (4 arms, faster spin)
    const arms = 4;
    const sweepRad = math.pi * 1.8;
    const steps = 40;

    for (int arm = 0; arm < arms; arm++) {
      final armOffset = (arm / arms) * math.pi * 2;
      for (int s = 0; s < steps; s++) {
        final frac = s / steps;
        final r = size.width * 0.04 + frac * size.width * 0.42;
        final angle = t * math.pi * 2 * 2 + armOffset + frac * sweepRad;
        final nextFrac = (s + 1) / steps;
        final rN = size.width * 0.04 + nextFrac * size.width * 0.42;
        final angleN = t * math.pi * 2 * 2 + armOffset + nextFrac * sweepRad;

        final pA = Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
        final pB = Offset(
          cx + rN * math.cos(angleN),
          cy + rN * math.sin(angleN),
        );

        final opacity = (0.08 + frac * 0.5).clamp(0.0, 1.0);
        canvas.drawLine(
          pA,
          pB,
          Paint()
            ..color = const Color(
              0xFFAB78FF,
            ).withValues(alpha: opacity * (0.5 + pulse * 0.5))
            ..strokeWidth = 0.6 + frac * 1.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Black hole centre
    canvas.drawCircle(
      center,
      size.width * 0.08,
      Paint()..color = const Color(0xFF050010),
    );
    // Hot edge glow
    canvas.drawCircle(
      center,
      size.width * 0.10,
      Paint()
        ..color = const Color(0xFFAB78FF).withValues(alpha: 0.25 + pulse * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Tiny white core
    canvas.drawCircle(
      center,
      1.5,
      Paint()..color = Colors.white.withValues(alpha: 0.7 + pulse * 0.3),
    );
  }

  @override
  bool shouldRepaint(_VortexPainter old) => old.t != t;
}

class _MarkerTapWrapper extends StatefulWidget {
  const _MarkerTapWrapper({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_MarkerTapWrapper> createState() => _MarkerTapWrapperState();
}

class _MarkerTapWrapperState extends State<_MarkerTapWrapper> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        scale: _down ? 0.94 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Touchable hotspot area for the biome icon itself.
            // (This is invisible but ensures the hit box is chunky.)
            SizedBox(
              width: 64,
              height: 64,
              // uncomment to debug tap zones:
              // child: ColoredBox(color: Colors.red.withValues(alpha: .2)),
            ),
            const SizedBox(height: 6),
            widget.child,
          ],
        ),
      ),
    );
  }
}

// =====================================================
// INFO DIALOG
// =====================================================

class _InfoDialog extends StatelessWidget {
  const _InfoDialog({required this.theme});
  final FactionTheme theme;

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: fc.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fc.borderAccent, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: fc.borderDim.withValues(alpha: .12),
              blurRadius: 12,
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row with small amber marker
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  color: fc.amber,
                  margin: const EdgeInsets.only(right: 10),
                ),
                Expanded(
                  child: Text(
                    'Fusing Expeditions',
                    style: ft.heading.copyWith(
                      fontSize: 14,
                      color: fc.textPrimary,
                    ),
                  ),
                ),
                Icon(AppIcons.explore_rounded, color: fc.amberBright, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Wild areas will light up when a creature has been detected. Venture into diverse biomes to discover new creatures. Successful breeding or harvesting will create an offspring you can extract in the Incubator. Wild Alchemons are more powerful and have better stats.',
              style: ft.body.copyWith(color: fc.textSecondary),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: fc.bg3,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: fc.borderMid, width: 1),
                ),
                alignment: Alignment.center,
                child: Text(
                  'OK',
                  style: ft.mono.copyWith(color: fc.amberBright, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
