// lib/screens/scenes/scene_page.dart
import 'dart:math';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/encounter_sheet.dart';
import 'package:alchemons/games/wilderness/rift_portal_component.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/pools/valley_pool.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/scenes/landscape_dialog.dart';
import 'package:alchemons/screens/scenes/rift_portal_screen.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:alchemons/widgets/background/daynight_filter.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:alchemons/widgets/wilderness/wilderness_controls.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flame/game.dart';

import 'package:alchemons/models/inventory.dart' show InvKeys;
import 'package:alchemons/models/wilderness.dart'
    show PartyMember, WildEncounter;
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/services/encounter_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wildlife_generator.dart';

class ScenePage extends StatefulWidget {
  final SceneDefinition scene;
  final List<PartyMember> party;
  final String sceneId;
  final bool isTutorial;
  final void Function(NavSection section, {int? breedInitialTab})?
  onNavigateSection;

  const ScenePage({
    super.key,
    required this.scene,
    this.party = const [],
    required this.sceneId,
    this.isTutorial = false,
    this.onNavigateSection,
  });

  @override
  State<ScenePage> createState() => _ScenePageState();
}

class _ScenePageState extends State<ScenePage> with TickerProviderStateMixin {
  late SceneGame _game;
  late EncounterService _encounters;
  bool _resolverHooked = false;
  bool _tutorialDialogShown = false;

  // Saved references
  late WildernessSpawnService _spawnService;
  late EncounterPool _scenePool;
  late FactionService _factionService;
  late AlchemonsDatabase _db;
  late CreatureCatalog _repo;

  // Encounter state
  bool _inEncounter = false;
  Creature? _wildCreature;
  bool _showTutorialHighlight = false;
  bool _riftSpawned = false;

  String? _usedSpawnPointId;

  @override
  void initState() {
    super.initState();

    _game = SceneGame(scene: widget.scene);

    // 🆕 Enable tutorial mode if this is tutorial
    if (widget.isTutorial) {
      _game.isTutorialMode = true;
    }

    _encounters = EncounterService(
      scene: widget.scene,
      party: widget.party,
      tableBuilder: valleyEncounterPools,
    );

    _game.attachEncounters(_encounters);

    _game.onStartEncounter = (spawnId, speciesId, hydrated) {
      _usedSpawnPointId = spawnId;
      setState(() {
        _inEncounter = true;
        _wildCreature = hydrated as Creature;
        _showTutorialHighlight = widget.isTutorial;
      });
      HapticFeedback.mediumImpact();
    };

    _game.onRiftTapped = (faction) => _onRiftTapped(faction);
  }

  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _spawnService = context.read<WildernessSpawnService>();
    _scenePool = valleyEncounterPools(widget.scene).sceneWide;
    _factionService = context.read<FactionService>();
    _db = context.read<AlchemonsDatabase>();
    _repo = context.read<CreatureCatalog>();

    if (!_initialized) {
      _initialized = true;

      _spawnService.markSceneActive(widget.sceneId);
      _spawnService.addListener(_onSpawnServiceChanged);

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _db
            .into(_db.activeSceneEntry)
            .insertOnConflictUpdate(
              ActiveSceneEntryCompanion.insert(
                sceneId: widget.sceneId,
                enteredAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
              ),
            );

        // 🆕 Guarantee tutorial spawn BEFORE showing dialog
        if (widget.isTutorial) {
          await _ensureTutorialSpawn();
        }

        if (widget.isTutorial && !_tutorialDialogShown && mounted) {
          _tutorialDialogShown = true;
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            await _showWelcomeDialog();
          }
        }
      });
    }

    _syncSpawnsFromService();

    // Spawn rift portal once per scene entry (10% chance, skip tutorial)
    if (!_riftSpawned && !widget.isTutorial) {
      _riftSpawned = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _game.spawnRiftIfChance();
      });
    }
  }

  // 🆕 Guarantee a LET spawn for tutorial
  Future<void> _ensureTutorialSpawn() async {
    // Clear any existing spawns first
    await _spawnService.clearSceneSpawns(widget.sceneId);

    // Find the best spawn point for tutorial (front-center is ideal)
    // SP_valley_02 is at (0.58, 0.80) - front middle, perfect for tutorial
    const tutorialSpawnId = 'SP_valley_02';

    // Force spawn LET04 at common rarity
    final tutorialEncounter = EncounterRoll(
      speciesId: 'LET04',
      rarity: EncounterRarity.common,
      spawnId: tutorialSpawnId,
    );

    _spawnService.forceSpawnAt(
      widget.sceneId,
      tutorialSpawnId,
      tutorialEncounter,
    );

    // Persist to database
    await _db
        .into(_db.activeSpawns)
        .insert(
          ActiveSpawnsCompanion.insert(
            id: '${widget.sceneId}_$tutorialSpawnId',
            sceneId: widget.sceneId,
            spawnPointId: tutorialSpawnId,
            speciesId: 'LET04',
            rarity: 'common',
            spawnedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrReplace,
        );

    debugPrint('✨ Tutorial spawn guaranteed: LET04 at $tutorialSpawnId');
  }

  Future<void> _showWelcomeDialog() async {
    await LandscapeDialog.show(
      context,
      title: 'Alchemy is Power',
      message:
          'Tap the creature to begin your first fusion. Select one of your Alchemons to attempt the fuse. Alchemons are stronger here. Fusing with them should provide formidable results.',
      typewriter: true,
      kind: LandscapeDialogKind.info,
      icon: Icons.explore_rounded,
      primaryLabel: 'Begin',
      barrierDismissible: false,
    );
  }

  Future<void> _showSuccessDialog() async {
    await LandscapeDialog.show(
      context,
      title: 'Fusion Successful!',
      message: 'Your new Alchemon is cultivating in the chamber.',
      typewriter: false,
      kind: LandscapeDialogKind.success,
      icon: Icons.check_circle_rounded,
      primaryLabel: 'Return to Lab',
      barrierDismissible: false,
    );
  }

  @override
  void dispose() {
    _maybeRestoreWaterParty();
    _spawnService.markSceneInactive(widget.sceneId);
    _spawnService.removeListener(_onSpawnServiceChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _db.delete(_db.activeSceneEntry).go();
      } catch (_) {}
      await _spawnService.clearSceneSpawns(widget.sceneId);
    });

    super.dispose();
  }

  void _onSpawnServiceChanged() {
    _syncSpawnsFromService();
  }

  void _syncSpawnsFromService() {
    _encounters.clearSpawns();

    for (final sp in widget.scene.spawnPoints) {
      final enc = _spawnService.getSpawnAt(widget.sceneId, sp.id);
      if (enc == null) continue;

      final asWild = WildEncounter(
        wildBaseId: enc.speciesId,
        baseBreedChance: breedChanceForRarity(enc.rarity),
        rarity: enc.rarity.name,
      );

      _encounters.forceSpawnAt(sp.id, asWild);
    }

    _game.attachEncounters(_encounters);
    _game.syncWildFromEncounters();
  }

  Future<void> _maybeRestoreWaterParty() async {
    if (!(_factionService.isWater() && await _factionService.perk2Active()))
      return;

    for (final p in widget.party) {
      final inst = await _db.creatureDao.getInstance(p.instanceId);
      if (inst == null) continue;
      final base = _repo.getCreatureById(inst.baseId);
      if (base?.types.contains('Water') != true) continue;

      await _db.creatureDao.updateStamina(
        instanceId: inst.instanceId,
        staminaBars: inst.staminaMax,
        staminaLastUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    }
  }

  void _onPartyCreatureSelected(Creature hydrated) {
    if (_showTutorialHighlight) {
      setState(() {
        _showTutorialHighlight = false;
      });
    }
    _game.spawnPartyCreature(hydrated);
  }

  void _exitEncounter({String? clearSpawnId}) {
    setState(() {
      _inEncounter = false;
      _showTutorialHighlight = false;
    });
    _game.exitEncounterMode();

    if (clearSpawnId != null) {
      _game.clearWildAt(clearSpawnId);
    }

    HapticFeedback.lightImpact();
  }

  // ── Rift portal ─────────────────────────────────────────────────────────────

  void _onRiftTapped(RiftFaction faction) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 900),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (ctx, animation, secondary) => _RiftVoidPage(
          faction: faction,
          party: widget.party,
          onEnter: () async {
            Navigator.of(ctx).pop();
            // Don't clear the rift yet — only clear it if the player
            // successfully breeds or catches inside the void.
            final success = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) =>
                    RiftPortalScreen(faction: faction, party: widget.party),
              ),
            );
            if (success == true) {
              _game.clearRift();
            }
          },
        ),
        transitionsBuilder: (ctx, animation, secondary, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.18, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final bool night = isNight(now);

    return Consumer<CreatureCatalog>(
      builder: (context, gameState, _) {
        if (!_resolverHooked) {
          final repo = context.read<CreatureCatalog>();
          _game.wildVisualResolver = (speciesId, rarity) async {
            final gen = WildlifeGenerator(repo);
            return gen.generate(speciesId, rarity: rarity.name);
          };
          _resolverHooked = true;
        }

        return PopScope(
          canPop: false,
          child: Scaffold(
            body: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final game = SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: GameWidget(game: _game),
                    );

                    return DayNightFilter(
                      intensity: night ? 1.0 : 0.0,
                      tint: const Color(0xFF081028),
                      minLuma: 0.45,
                      child: game,
                    );
                  },
                ),

                IgnorePointer(
                  child: AlchemicalParticleBackground(
                    opacity: 0.9,
                    backgroundColor: Colors.transparent,
                  ),
                ),
                if (_inEncounter && _wildCreature != null)
                  EncounterOverlay(
                    encounter: WildEncounter(
                      wildBaseId: _wildCreature!.id,
                      baseBreedChance: breedChanceForRarity(
                        EncounterRarity.values.byName(
                          _wildCreature!.rarity.toLowerCase(),
                        ),
                      ),
                      rarity: _wildCreature!.rarity,
                    ),
                    hydratedWildCreature: _wildCreature!,
                    party: widget.party,
                    highlightPartyHUD: _showTutorialHighlight,
                    isTutorial: widget.isTutorial, // 🆕 Pass tutorial flag
                    onPreRollShake: () {
                      _game.shake(
                        duration: const Duration(milliseconds: 800),
                        amplitude: 14,
                      );
                    },
                    onPartyCreatureSelected: _onPartyCreatureSelected,
                    onClosedWithResult: (success) async {
                      final id = _usedSpawnPointId;

                      _exitEncounter();

                      if (success && id != null) {
                        _game.clearWildAt(id);
                        await _spawnService.removeSpawn(widget.sceneId, id);
                        _syncSpawnsFromService();

                        _usedSpawnPointId = null;

                        // 🆕 Handle tutorial completion AFTER everything
                        if (!widget.isTutorial || !mounted) return;

                        await _showSuccessDialog();
                        if (!mounted) return;

                        final settingsDao = _db.settingsDao;
                        await settingsDao.setFieldTutorialCompleted();
                        await settingsDao.setNavLocked(false);

                        // Pop back with a result indicating tutorial completion
                        if (!mounted) return;
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);

                        // Signal the navigation request
                        if (widget.onNavigateSection != null) {
                          // Need to use the context AFTER we've returned to MainShell
                          // Use a microtask to ensure we're in the right build context
                          Future.microtask(() {
                            if (mounted) {
                              widget.onNavigateSection!(
                                NavSection.breed,
                                breedInitialTab: 1,
                              );
                            }
                          });
                        }
                      }
                    },
                  ),
                // Back / leave button - 🆕 Hidden in tutorial
                if (!widget.isTutorial)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: WildernessControls(
                          party: widget.party,
                          onLeave: () async {
                            await _db.delete(_db.activeSceneEntry).go();
                            await _spawnService.clearSceneSpawns(
                              widget.sceneId,
                            );

                            if (!mounted) return;

                            VoidPortal.pop(context);
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
// ── Rift Void Page (full-screen mystical overlay) ────────────────────────────

class _RiftVoidPage extends StatefulWidget {
  final RiftFaction faction;
  final List<PartyMember> party;
  final VoidCallback onEnter;

  const _RiftVoidPage({
    required this.faction,
    required this.party,
    required this.onEnter,
  });

  @override
  State<_RiftVoidPage> createState() => _RiftVoidPageState();
}

class _RiftVoidPageState extends State<_RiftVoidPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  String? _feedback;
  bool _feedbackIsWarning = false;
  bool _confirming = false;

  // Current portal key quantity for this faction.
  Future<int>? _keyFuture;

  String get _portalKeyInvKey =>
      InvKeys.portalKeyForFaction(widget.faction.name);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _keyFuture ??= _loadKeyQty();
  }

  Future<int> _loadKeyQty() async {
    final db = context.read<AlchemonsDatabase>();
    return db.inventoryDao.getItemQty(_portalKeyInvKey);
  }

  Future<void> _refreshKeyQty() async {
    final db = context.read<AlchemonsDatabase>();
    final qty = await db.inventoryDao.getItemQty(_portalKeyInvKey);
    if (mounted) setState(() => _keyFuture = Future.value(qty));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String get _essenceLabel => switch (widget.faction) {
    RiftFaction.volcanic => 'IGNEOUS RESONANCE',
    RiftFaction.oceanic => 'ABYSSAL RESONANCE',
    RiftFaction.verdant => 'SYLVAN RESONANCE',
    RiftFaction.earthen => 'LITHIC RESONANCE',
    RiftFaction.arcane => 'VOID RESONANCE',
  };

  String get _crypticHint => switch (widget.faction) {
    RiftFaction.volcanic =>
      'Those born of flame, ruin, or ancient blood may approach.',
    RiftFaction.oceanic => 'Those shaped by tide and the deep cold may answer.',
    RiftFaction.verdant =>
      'Those of wind, bloom, and radiance know the passage.',
    RiftFaction.earthen =>
      'Those carved from stone, clay, crystal, and dust may enter.',
    RiftFaction.arcane =>
      'Those steeped in shadow, spirit, storm, or venom are expected.',
  };

  @override
  Widget build(BuildContext context) {
    final color = widget.faction.primaryColor;
    final coreColor = widget.faction.coreColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          final pulse = 0.85 + 0.15 * _pulseCtrl.value;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _VoidPainter(
                    color: color,
                    coreColor: coreColor,
                    pulse: pulse,
                    time: _pulseCtrl.value,
                  ),
                ),
              ),
              SafeArea(child: child!),
            ],
          );
        },
        child: _buildContent(color),
      ),
    );
  }

  Widget _buildContent(Color color) {
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Left panel: lore ─────────────────────────────────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THE RIFT STIRS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${widget.faction.displayName.toUpperCase()} THRESHOLD',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: color.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(2),
                      color: color.withOpacity(0.07),
                    ),
                    child: Text(
                      _essenceLabel,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _crypticHint,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: color.withOpacity(0.65),
                      fontSize: 10,
                      height: 1.55,
                      letterSpacing: 0.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            // ── Vertical divider ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 160,
                child: VerticalDivider(
                  color: color.withOpacity(0.25),
                  thickness: 1,
                  width: 1,
                ),
              ),
            ),

            // ── Right panel: key check → vessel selection ─────────────────
            Expanded(child: _buildRightPanel(color)),
          ],
        ),
      ),
    );
  }

  // ── Gated right panel ────────────────────────────────────────────────────

  Widget _buildRightPanel(Color color) {
    return FutureBuilder<int>(
      future: _keyFuture,
      builder: (ctx, keySnap) {
        if (keySnap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 70,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white24,
              ),
            ),
          );
        }
        final keyQty = keySnap.data ?? 0;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Key status chip ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(
                  color: keyQty > 0 ? color.withOpacity(0.6) : Colors.white24,
                ),
                borderRadius: BorderRadius.circular(2),
                color: keyQty > 0
                    ? color.withOpacity(0.10)
                    : Colors.white.withOpacity(0.04),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.vpn_key_rounded,
                    color: keyQty > 0 ? color : Colors.white30,
                    size: 11,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    keyQty > 0
                        ? '${widget.faction.displayName.toUpperCase()} KEY  ×$keyQty'
                        : 'NO PORTAL KEY',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: keyQty > 0 ? color : Colors.white30,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (keyQty <= 0) ...[
              // ── No key: prompt to buy ────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(3),
                  color: Colors.white.withOpacity(0.03),
                ),
                child: Text(
                  'You need a\n${widget.faction.displayName.toUpperCase()} PORTAL KEY\nto enter this rift.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.white38,
                    fontSize: 10,
                    height: 1.6,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ] else if (!_confirming) ...[
              // ── Has key: enter prompt ────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: color.withOpacity(0.25)),
                  borderRadius: BorderRadius.circular(3),
                  color: color.withOpacity(0.05),
                ),
                child: const Text(
                  'YOUR ENTIRE PARTY\nWILL ENTER THE VOID',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.white54,
                    fontSize: 10,
                    height: 1.7,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _handleEnterTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: color, width: 1.5),
                    borderRadius: BorderRadius.circular(3),
                    color: color.withOpacity(0.18),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    'ENTER THE RIFT',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ] else ...[
              // ── Confirmation ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: color.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(3),
                  color: color.withOpacity(0.08),
                ),
                child: Text(
                  'USE 1 ${widget.faction.displayName.toUpperCase()}\nPORTAL KEY?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: color,
                    fontSize: 11,
                    height: 1.7,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _confirming = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.white.withOpacity(0.05),
                      ),
                      child: const Text(
                        'BACK',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _handleConfirmEnter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: color, width: 1.5),
                        borderRadius: BorderRadius.circular(2),
                        color: color.withOpacity(0.2),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Text(
                        'ENTER',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),
            if (_feedback != null)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _feedbackIsWarning
                        ? const Color(0xFFE06060)
                        : const Color(0xFF88EE88),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Text(
                    _feedback!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: _feedbackIsWarning
                          ? const Color(0xFFE06060)
                          : const Color(0xFF88EE88),
                      fontSize: 10,
                      height: 1.5,
                      letterSpacing: 0.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'STEP BACK FROM THE THRESHOLD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Color.fromARGB(151, 255, 255, 255),
                    fontSize: 14,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleEnterTap() {
    setState(() {
      _confirming = true;
      _feedback = null;
    });
  }

  Future<void> _handleConfirmEnter() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    // Race-condition guard: re-check key quantity.
    final keyQty = await db.inventoryDao.getItemQty(_portalKeyInvKey);
    if (keyQty <= 0) {
      setState(() {
        _feedback = 'Your portal key has gone. Visit the Shop.';
        _feedbackIsWarning = true;
        _confirming = false;
      });
      await _refreshKeyQty();
      return;
    }
    // Consume one key and enter.
    await db.inventoryDao.addItemQty(_portalKeyInvKey, -1);
    if (!mounted) return;
    widget.onEnter();
  }
}

// ── Void background painter ───────────────────────────────────────────────────

class _VoidPainter extends CustomPainter {
  final Color color;
  final Color coreColor;
  final double pulse;
  final double time;

  const _VoidPainter({
    required this.color,
    required this.coreColor,
    required this.pulse,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.28);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 1.3,
          colors: [
            Color.lerp(coreColor, Colors.black, 0.2)!,
            const Color(0xFF04040F),
            Colors.black,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Offset.zero & size),
    );

    for (int i = 4; i >= 0; i--) {
      final r = 55.0 + i * 52.0 + 18 * (1 - pulse);
      canvas.drawCircle(
        center,
        r * pulse,
        Paint()
          ..color = color.withOpacity((0.13 - i * 0.02) * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }

    const spokeCount = 8;
    final spokePaint = Paint()
      ..color = color.withOpacity(0.05 * pulse)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < spokeCount; i++) {
      final angle = (i / spokeCount) * pi * 2 + time * 0.4;
      canvas.drawLine(
        center,
        Offset(center.dx + 320 * cos(angle), center.dy + 320 * sin(angle)),
        spokePaint,
      );
    }

    canvas.drawCircle(
      center,
      38 * pulse,
      Paint()
        ..color = color.withOpacity(0.15 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
  }

  @override
  bool shouldRepaint(_VoidPainter old) => true;
}
