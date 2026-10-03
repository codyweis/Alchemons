import 'package:alchemons/services/opening_wilderness_service.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/screens/wilderness_peek_dialog.dart';
import 'dart:async';

import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:alchemons/models/scenes/arcane/arcane_scene.dart';
import 'package:alchemons/models/wilderness.dart' show PartyMember;
import 'package:alchemons/screens/party_picker/party_picker.dart';
import 'package:alchemons/screens/scenes/scene_page.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/wilderness_access_service.dart';
import 'package:alchemons/utils/faction_util.dart';
// for FactionTheme
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/story_dialog.dart';
import 'package:alchemons/widgets/wilderness/wild_map.dart';
import 'package:alchemons/widgets/wilderness/wild_map_view.dart';

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

  /// The cosmic ship has come down in the Valley and waits to be claimed:
  /// the Valley's rim pulses, as for anything else waiting there.
  bool _shipWaitsInValley = false;
  late final AnimationController _mapController;
  late final Animation<double> _mapScale;
  late final Animation<double> _mapOpacity;

  @override
  void initState() {
    super.initState();
    unawaited(_ensureHuntTargetIsReady());

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
      // Check if arcane portal is unlocked
      final db = context.read<AlchemonsDatabase>();
      final v = await db.settingsDao.getSetting('arcane_portal_unlocked');
      if (mounted && v == '1') setState(() => _arcaneUnlocked = true);
      final ship = await db.settingsDao.getSetting('cosmic_ship_scene');
      final claimed =
          await db.settingsDao.getSetting('cosmic_ship_claimed') == '1';
      if (mounted && ship == 'valley' && !claimed) {
        setState(() => _shipWaitsInValley = true);
      }
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

  /// The element whose portal twist each region's entry borrows.
  static const Map<String, String> _biomePortalElements = {
    'valley': 'plant',
    'sky': 'air',
    'volcano': 'fire',
    'swamp': 'mud',
    'arcane': 'spirit',
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
          'Spawns reset for this biome.',
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
      // The map is all the particles this screen needs; a second field
      // drifting behind it only cost frames.
      showParticles: false,
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
                  onInfo: () => _showInfoDialog(context),
                  isTutorial: widget.isTutorial,
                ),

                const SizedBox(height: 8),

                // Show tutorial hint
                if (widget.isTutorial) ...[
                  _TutorialBanner(theme: theme),
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
                    child: _WildMap(
                      theme: theme,
                      arcaneUnlocked: _arcaneUnlocked,
                      shipWaitsInValley: _shipWaitsInValley,
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
    showStoryDialog(
      context,
      icon: AppIcons.lock_outline,
      primaryLabel: 'OK',
      barrierDismissible: true,
      beats: const [
        StoryBeat(
          title: 'Not yet',
          message:
              'Finish your first expedition in the realm circled in green.',
        ),
      ],
    );
  }

  void _showInfoDialog(BuildContext context) {
    showStoryDialog(
      context,
      icon: AppIcons.explore_rounded,
      primaryLabel: 'OK',
      barrierDismissible: true,
      beats: const [
        StoryBeat(
          title: 'Alchemical Biomes',
          message:
              'Tap a realm to enter it. Its circle pulses green when a creature '
              'has been detected there.\n\nA successful fusion sends a vial to '
              'your cultivations; a successful harvest captures the '
              'creature itself. Wild Alchemons are stronger and have better '
              'stats.',
        ),
      ],
    );
  }

  // --------------------------------------------------
  // TAP HANDLER FOR MAP MARKERS
  // --------------------------------------------------
  Future<bool> _confirmLure(BuildContext context, int held) async {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.isDark ? t.bg1 : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: t.amber.withValues(alpha: .45)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 3, height: 28, color: t.amber),
                        const SizedBox(width: 12),
                        Text(
                          'WILDLIFE LURE',
                          style: TextStyle(
                            color: t.amber,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'This region is empty. Use a lure to draw a specimen '
                      'here now? You are carrying $held.',
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _LureButton(
                            label: 'CANCEL',
                            color: theme.textMuted,
                            filled: false,
                            onTap: () => Navigator.pop(ctx, false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _LureButton(
                            label: 'USE LURE',
                            color: t.amber,
                            filled: true,
                            onTap: () => Navigator.pop(ctx, true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ) ??
        false;
  }

  /// The biome the opening is pointing at should never be showing a timer.
  ///
  /// Belt and braces for the seeding and advancing paths, and the repair
  /// for saves made before those were right: the tutorial used to put a
  /// spawn timer on every core biome including the one it was about to
  /// send the player to.
  Future<void> _ensureHuntTargetIsReady() async {
    if (widget.isTutorial) return;
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final spawnService = context.read<WildernessSpawnService>();
    final open = await OpeningWildernessService.openShipHuntScene(
      db.settingsDao,
    );
    if (open == null || !mounted) return;
    if (spawnService.getSceneSpawnCount(open) > 0) return;
    // NOT forced: a clock already running must be left to run, or opening
    // the map would push it back a minute every time and it would never
    // come round.
    await spawnService.scheduleNextSpawnTime(
      open,
      windowMin: OpeningWildernessService.huntSpawnDelay,
      windowMax: OpeningWildernessService.huntSpawnDelay,
    );
  }

  Future<void> _handleRegionTap(
    BuildContext context,
    String biomeId,
    SceneDefinition scene,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final access = WildernessAccessService(db);
    context.read<FactionService>();
    final spawnService = context.read<WildernessSpawnService>();

    // Held for the ship hunt reads as empty, but it is not — and a lure
    // cannot help, because nothing will spawn there until the hunt has moved
    // on. Say so instead of offering a charge that would be wasted, and name
    // the one region that is open: the hunt points at exactly one at a time,
    // so there is always a single answer to "then where?".
    if (!widget.isTutorial &&
        await OpeningWildernessService.isHeldForShipHunt(
          db.settingsDao,
          biomeId,
        )) {
      final open = await OpeningWildernessService.openShipHuntScene(
        db.settingsDao,
      );
      if (!context.mounted) return;
      final where = open == null ? null : _biomeDisplayNames[open];
      showGameSnack(
        context,
        where == null
            ? 'This region is quiet — explore elsewhere first'
            : 'This region is quiet — $where is stirring',
        icon: AppIcons.schedule_rounded,
      );
      return;
    }

    final sceneSpawnCount = spawnService.getSceneSpawnCount(biomeId);
    if (sceneSpawnCount == 0) {
      // An empty region used to be a flat no. If the player is carrying a
      // lure, this is the one moment it is for, so offer it here rather than
      // making them find it in the inventory and work out where it applies.
      final lures = await db.inventoryDao.getItemQty(InvKeys.wildlifeLure);
      if (!context.mounted) return;
      if (lures <= 0) {
        _showToast(
          context,
          'No creatures detected in this area',
          AppIcons.search_off_rounded,
          Colors.orange.shade400,
        );
        return;
      }

      final useLure = await _confirmLure(context, lures);
      if (!context.mounted || !useLure) return;

      // Consume first: the spawn is the thing being bought, and a lure that
      // vanishes without one is worse than one that is never spent.
      final spent = await db.inventoryDao.consumeItem(InvKeys.wildlifeLure);
      if (!context.mounted) return;
      if (!spent) return;

      await spawnService.ensureSpawnsForScene(biomeId);
      if (!context.mounted) return;
      if (spawnService.getSceneSpawnCount(biomeId) == 0) {
        // Nothing took. Give the lure back rather than pocketing it.
        await db.inventoryDao.addItemQty(InvKeys.wildlifeLure, 1);
        if (!context.mounted) return;
        _showToast(
          context,
          'Nothing answered the lure — it was not spent',
          AppIcons.search_off_rounded,
          Colors.orange.shade400,
        );
        return;
      }
      showGameSnack(
        context,
        'Something has been drawn to the area',
        icon: AppIcons.pets_rounded,
      );
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

    if (!widget.isTutorial) {
      final wildFusions = await db.inventoryDao.getItemQty(InvKeys.wildFusion);
      if (!context.mounted) return;
      final proceed = await _confirmExpeditionReadiness(
        context,
        wildFusionCount: wildFusions,
      );
      if (!context.mounted || !proceed) return;
    }

    // consume entry (skip during tutorial)
    if (!widget.isTutorial) {
      await access.markEntered(biomeId);
      // Arriving is what the hunt asks for, so arriving is what opens the
      // next one — recorded here rather than on the way out, so backing
      // straight out still counts as having been.
      //
      // What comes back is whatever the hunt just made eligible and so has
      // nothing in it: the region it now points at, or all four on the visit
      // that ends it. It is empty for every visit after that, which is the
      // only thing keeping the opening's timer out of the whole game.
      final toStir = await OpeningWildernessService.registerVisitForShipHunt(
        db.settingsDao,
        biomeId,
      );
      for (final scene in toStir) {
        // Forced, because each of these has just changed status: whatever
        // an earlier state left on its clock, it starts counting from here.
        await spawnService.scheduleNextSpawnTime(
          scene,
          windowMin: OpeningWildernessService.huntSpawnDelay,
          windowMax: OpeningWildernessService.huntSpawnDelay,
          force: true,
        );
      }
    }

    // go to biome scene
    if (!context.mounted) return;

    // The glyph portal is the loading screen: it turns the phone to
    // landscape while covered and holds until the scene is built. Each
    // region borrows the palette and twist of the element it feels like.
    final ready = ValueNotifier<bool>(false);
    await VoidPortal.pushThroughGlyphs<bool>(
      context,
      page: ScenePage(
        scene: scene,
        sceneId: biomeId,
        party: selectedParty,
        isTutorial: widget.isTutorial,
        onNavigateSection: widget.onNavigateSection,
        revealReady: ready,
      ),
      title: _biomeDisplayNames[biomeId] ?? biomeId,
      element: _biomePortalElements[biomeId] ?? '',
      ready: ready,
      orientation: const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      returnOrientation: const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    );
  }

  Future<bool> _confirmExpeditionReadiness(
    BuildContext context, {
    required int wildFusionCount,
  }) async {
    // The short-party warning used to live here, on the way INTO the field,
    // where there was nothing left to do about it. It now sits in the deploy
    // confirmation inside the party picker, which is the screen that can
    // actually act on it — and which knows both the real party limit and
    // whether the player owns enough creatures to fill it. It also said "of 5"
    // while SelectedPartyNotifier.defaultMaxSize has always been 4.
    final warnings = <String>[
      if (wildFusionCount <= 0)
        'You have no Wild Fusions, so you cannot fuse with a wild specimen.',
    ];
    if (warnings.isEmpty) return true;

    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: theme.isDark ? t.bg1 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: t.amber.withValues(alpha: 0.55)),
            ),
            title: Row(
              children: [
                Icon(AppIcons.warning_amber_rounded, color: t.amber, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'EXPEDITION CHECK',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final warning in warnings) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: t.amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          warning,
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  'Enter anyway?',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(
                  'GO BACK',
                  style: TextStyle(color: theme.textMuted),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: t.amber),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('ENTER ANYWAY'),
              ),
            ],
          ),
        ) ??
        false;
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
                      isTutorial ? 'First Expedition' : 'Alchemical Biomes',
                      style: _display(
                        context,
                        23,
                        theme.text,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // info
              GestureDetector(
                onTap: context.soundAction(onInfo),
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
// THE MAP
// =====================================================

/// The wild as grains: each realm a shape on a faint circle of sand, its
/// circle pulsing green when something waits in it. A finger stirs it;
/// tapping a realm goes in.
class _WildMap extends StatelessWidget {
  const _WildMap({
    required this.theme,
    required this.onSelectRegion,
    this.onPeekRegion,
    this.arcaneUnlocked = false,
    this.shipWaitsInValley = false,
  });

  final FactionTheme theme;
  final void Function(String biomeId, SceneDefinition scene) onSelectRegion;
  final void Function(String biomeId)? onPeekRegion;
  final bool arcaneUnlocked;
  final bool shipWaitsInValley;

  static final Map<String, SceneDefinition> _scenes = {
    'valley': valleySceneCorrected,
    'sky': skyScene,
    'swamp': swampScene,
    'volcano': volcanoScene,
    'arcane': arcaneScene,
  };

  @override
  Widget build(BuildContext context) {
    final spawnService = context.watch<WildernessSpawnService>();
    final weather = <String, WeatherKind>{
      for (final id in _scenes.keys)
        if (spawnService.weatherIn(id) case final w?) id: w.kind,
    };
    final ready = <String>{
      for (final id in _scenes.keys)
        if (spawnService.getSceneSpawnCount(id) > 0) id,
      if (shipWaitsInValley) 'valley',
    };
    final volcano = switch (spawnService.fieldStageFor(
      'volcano',
      volcanoScene,
    )) {
      VolcanoField.erupting => WildVolcano.erupting,
      VolcanoField.smoking => WildVolcano.smoking,
      _ => WildVolcano.still,
    };

    return Padding(
      // Clear of the docked close button.
      padding: const EdgeInsets.only(bottom: 70),
      child: WildMapView(
        weather: weather,
        ready: ready,
        arcane: arcaneUnlocked,
        volcano: volcano,
        rainbow: spawnService.owesAftermath('valley'),
        ink: theme.brightness == Brightness.light,
        onEnter: (id) {
          final scene = _scenes[id];
          if (scene == null) return;
          context.soundTap(() => onSelectRegion(id, scene))();
        },
        onPeek: onPeekRegion,
      ),
    );
  }
}

// =====================================================
// INFO DIALOG
// =====================================================

/// The confirm dialog's buttons, in the shape the rest of the game's
/// confirmations use.
class _LureButton extends StatelessWidget {
  const _LureButton({
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(4);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: context.soundAction(onTap),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: filled
                ? color.withValues(alpha: .9)
                : color.withValues(alpha: .08),
            border: Border.all(color: color.withValues(alpha: .35)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: filled ? Colors.white : color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The first Field visit's one line of direction, in the bracket frame.
class _TutorialBanner extends StatelessWidget {
  const _TutorialBanner({required this.theme});

  final FactionTheme theme;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.fromTheme(theme);
    final accent = bracketReadableAccent(theme);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: accent.withValues(alpha: 0.9),
          bracketSize: 10,
          strokeWidth: 1.3,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          color: palette.surfaceFill(),
          child: Row(
            children: [
              Icon(AppIcons.explore_rounded, color: accent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'TAP THE REALM CIRCLED IN GREEN TO ENTER IT',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: palette.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
