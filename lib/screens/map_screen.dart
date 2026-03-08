import 'dart:math' as math;

import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
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
  bool _showDebugInfo = false; // Add this state variable
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

  Future<void> _handlePeekRegion(String biomeId) async {
    if (widget.isTutorial) return;

    final theme = context.read<FactionTheme>();
    final spawnService = context.read<WildernessSpawnService>();
    final constellations = context.read<ConstellationEffectsService>();

    // Only available if the constellation is unlocked
    if (!constellations.hasWildernessPreview()) {
      _showToast(
        context,
        'Unlock Alchemic Wild Peek to preview wild spawns.',
        Icons.visibility_off_rounded,
        Colors.orange.shade400,
      );
      return;
    }

    final spawnPointIds = spawnService.getActiveSpawnPoints(biomeId);
    if (spawnPointIds.isEmpty) {
      _showToast(
        context,
        'No wild creatures detected in this area.',
        Icons.search_off_rounded,
        Colors.orange.shade400,
      );
      return;
    }

    final repo = context.read<CreatureCatalog>();

    Color rarityColor0(String rarityName) {
      switch (rarityName) {
        case 'legendary':
          return const Color(0xFFFFD700);
        case 'rare':
          return Colors.cyanAccent;
        case 'uncommon':
          return Colors.lightGreenAccent;
        default:
          return theme.textMuted;
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.accent, width: 1.4),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.remove_red_eye_rounded,
                  color: theme.accent,
                  size: 26,
                ),
                const SizedBox(height: 8),
                Text(
                  'Wilderness Peek',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current wild spawns in this biome:',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // List of spawns
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: spawnPointIds.length,
                    itemBuilder: (context, index) {
                      final spawnPointId = spawnPointIds[index];
                      final roll = spawnService.getSpawnAt(
                        biomeId,
                        spawnPointId,
                      );
                      if (roll == null) {
                        return ListTile(
                          dense: true,
                          title: Text(
                            'Unknown creature',
                            style: TextStyle(
                              color: theme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }

                      final base = repo.getCreatureById(roll.speciesId);
                      final rarityName = roll.rarity.name;
                      final rarityColor = rarityColor0(rarityName);

                      return ListTile(
                        dense: true,

                        title: Text(
                          base?.name ?? roll.speciesId,
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: rarityColor.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: rarityColor, width: 1),
                          ),
                          child: Text(
                            rarityName.toUpperCase(),
                            style: TextStyle(
                              color: rarityColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .6,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Buttons
                Row(
                  children: [
                    // Close
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.accent.withValues(alpha: .3),
                              width: 1.2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'CLOSE',
                            style: TextStyle(
                              color: theme.text,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: .5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Reset spawns
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          await spawnService.clearSceneSpawns(biomeId);
                          if (!mounted) return;
                          _showToast(
                            context,
                            'Spawns reset for this biome.',
                            Icons.refresh_rounded,
                            theme.accent,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: theme.accent, width: 1.4),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'RESET SPAWNS',
                            style: TextStyle(
                              color: theme.text,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: .5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    final spawnService = context.watch<WildernessSpawnService>();

    final anySpawns = const [
      'valley',
      'sky',
      'volcano',
      'swamp',
    ].any((biomeId) => spawnService.getSceneSpawnCount(biomeId) > 0);

    return ParticleBackgroundScaffold(
      whiteBackground: theme.brightness == Brightness.light,
      body: WillPopScope(
        onWillPop: () async {
          if (widget.isTutorial) {
            _showTutorialBlockedDialog();
            return false;
          }
          return true;
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                _HeaderBar(
                  onBack: () => Navigator.pop(context),
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
                          Icons.explore_rounded,
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

                // Top scorched spawn boxes row (replaces debug toggle/panel)
                if (!widget.isTutorial) ...[
                  // Compact 2x2 grid of spawn boxes (reduced top margin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        _ScorchedSpawnBox(
                          biomeId: 'valley',
                          spawnService: spawnService,
                          compact: true,
                        ),
                        _ScorchedSpawnBox(
                          biomeId: 'sky',
                          spawnService: spawnService,
                          compact: true,
                        ),
                        _ScorchedSpawnBox(
                          biomeId: 'volcano',
                          spawnService: spawnService,
                          compact: true,
                        ),
                        _ScorchedSpawnBox(
                          biomeId: 'swamp',
                          spawnService: spawnService,
                          compact: true,
                        ),
                        if (_arcaneUnlocked)
                          _ScorchedSpawnBox(
                            biomeId: 'arcane',
                            spawnService: spawnService,
                            compact: true,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
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

                // Hint bar pinned to bottom
                if (!widget.isTutorial)
                  anySpawns
                      ? _MapHintBar(theme: theme)
                      : Container(
                          decoration: BoxDecoration(
                            color: theme.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.accent.withValues(alpha: .35),
                              width: 1.2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'No wild creatures detected at this time.',
                              style: TextStyle(color: theme.textMuted),
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
              Icon(Icons.lock_outline, color: theme.accent, size: 28),
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

    if (spawnService.getSceneSpawnCount(biomeId) == 0) {
      _showToast(
        context,
        'No creatures detected in this area',
        Icons.search_off_rounded,
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
          Icons.schedule_rounded,
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
        builder: (_) => const PartyPickerScreen(enforceUniqueSpecies: false),
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
// HEADER BAR
// =====================================================

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.theme,
    required this.onInfo,
    required this.onBack,
    this.isTutorial = false,
  });

  final FactionTheme theme;
  final VoidCallback onInfo;
  final VoidCallback onBack;
  final bool isTutorial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          // top row: back + info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  isTutorial ? Icons.lock_outline : Icons.arrow_back,
                  color: isTutorial ? theme.textMuted : theme.text,
                ),
                onPressed: onBack,
              ),
              // center title/subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      isTutorial ? 'FIRST EXPEDITION' : 'FUSING EXPEDITIONS',
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTutorial
                          ? 'Begin your journey into the wilderness'
                          : 'Discover wild Alchemons & attempt fusions',
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // info
              GestureDetector(
                onTap: onInfo,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: theme.text,
                    size: 20,
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
class _SpawnDebugPanel extends StatelessWidget {
  const _SpawnDebugPanel({required this.theme, required this.spawnService});

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
              Icon(Icons.bug_report, size: 14, color: theme.accent),
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
              timeText = 'Not scheduled';
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
                        fontSize: 11,
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
                          fontSize: 10,
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
                if (arcaneUnlocked)
                  _ArcaneVortex(
                    mapSize: size,
                    hasSpawns: spawnService.getSceneSpawnCount('arcane') > 0,
                    onTap: () => onSelectRegion('arcane', arcaneScene),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =====================================================
// SCORCHED SPAWN BOX
// =====================================================
class _ScorchedSpawnBox extends StatelessWidget {
  final String biomeId;
  final WildernessSpawnService spawnService;
  final bool compact;

  const _ScorchedSpawnBox({
    required this.biomeId,
    required this.spawnService,
    this.compact = false,
  });

  String _formatTime(int? dueMs) {
    if (dueMs == null) return 'Not scheduled';
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final diff = dueMs - now;
    if (diff <= 0) return 'Due now!';
    final minutes = diff ~/ 60000;
    final seconds = (diff % 60000) ~/ 1000;
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
    final nextDue = spawnService.getNextSpawnTime(biomeId);
    final count = spawnService.getSceneSpawnCount(biomeId);

    final boxWidth = compact ? 140.0 : 180.0;
    final titleSize = compact ? 10.0 : 11.0;
    final timeSize = compact ? 9.0 : 12.0;

    return Container(
      width: boxWidth,
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: fc.bg1,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fc.borderAccent, width: 1.2),
        boxShadow: [BoxShadow(color: fc.borderDim.withValues(alpha: .12), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  biomeId.toUpperCase(),
                  style: ft.heading.copyWith(fontSize: titleSize, color: fc.amberBright),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _formatTime(nextDue),
                style: ft.mono.copyWith(fontSize: timeSize, color: fc.textSecondary),
              ),
            ],
          ),
        ],
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

// hint / legend bar at bottom of the map
class _MapHintBar extends StatelessWidget {
  const _MapHintBar({required this.theme});
  final FactionTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 40),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.accent.withValues(alpha: .35),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: theme.text),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Wild creatures detected here! Tap to explore.',
              style: TextStyle(
                color: theme.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
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
          boxShadow: [BoxShadow(color: fc.borderDim.withValues(alpha: .12), blurRadius: 12)],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row with small amber marker
            Row(
              children: [
                Container(width: 4, height: 20, color: fc.amber, margin: const EdgeInsets.only(right: 10)),
                Expanded(
                  child: Text(
                    'Fusing Expeditions',
                    style: ft.heading.copyWith(fontSize: 14, color: fc.textPrimary),
                  ),
                ),
                Icon(Icons.explore_rounded, color: fc.amberBright, size: 20),
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
