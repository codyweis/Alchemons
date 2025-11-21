// (imports unchanged except where noted)
import 'dart:async' as async;

import 'package:alchemons/games/survival/survival_game_screen.dart';
import 'package:alchemons/models/biome_farm_state.dart';
import 'package:alchemons/screens/boss/boss_intro_screen.dart';
import 'package:alchemons/screens/competition_hub_screen.dart';
import 'package:alchemons/screens/game_screen.dart';
import 'package:alchemons/screens/inventory_screen.dart';
import 'package:alchemons/screens/map_screen.dart';
import 'package:alchemons/screens/story/story_intro_screen.dart';
import 'package:alchemons/screens/upgrade_tree/constellation_points_widget.dart';
import 'package:alchemons/screens/upgrade_tree/constellation_screen.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/harvest_service.dart';
import 'package:alchemons/services/push_notification_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/utils/creature_instance_uti.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/widgets/avatar_widget.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:alchemons/widgets/blob_party/overlays/floating_bubble_overlay.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/widgets/creature_showcase_widget.dart';
import 'package:alchemons/widgets/currency_display_widget.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:alchemons/widgets/notification_banner_system.dart';
import 'package:alchemons/widgets/side_dock_widget.dart';
import 'package:alchemons/widgets/starter_granted_dialog.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/cupertino.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/screens/creatures_screen.dart';
import 'package:alchemons/screens/faction_picker.dart';
import 'package:alchemons/screens/feeding/feeding_screen.dart';
import 'package:alchemons/screens/harvest_screen.dart';
import 'package:alchemons/screens/profile_screen.dart';
import 'package:alchemons/screens/shop/shop_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/starter_grant_service.dart';
import 'package:alchemons/widgets/background/interactive_background_widget.dart';
import 'package:alchemons/widgets/element_resource_widget.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_dialog.dart';
import 'breed/breed_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  NavSection _currentSection = NavSection.home;

  final GlobalKey<CreaturesScreenState> _creaturesKey =
      GlobalKey<CreaturesScreenState>();

  // NEW: guard so we only request once per launch
  bool _creaturesTutorialRequested = false;

  void _goToSection(NavSection section, {int? breedInitialTab}) {
    if (section == _currentSection) return;

    setState(() {
      _currentSection = section;
    });
    HapticFeedback.mediumImpact();

    // Trigger tutorials when user actually visits these sections:
    if (section == NavSection.creatures && !_creaturesTutorialRequested) {
      _creaturesTutorialRequested = true;
      _creaturesKey.currentState?.maybeShowCreaturesTutorial();
    }
  }

  int get _navIndex {
    switch (_currentSection) {
      case NavSection.home:
        return 0;
      case NavSection.creatures:
        return 1;
      case NavSection.shop:
        return 2;
      case NavSection.breed:
        return 3;
      case NavSection.inventory:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _navIndex,
        children: [
          HomeScreen(
            isActive: _currentSection == NavSection.home,
            onNavigateSection: _goToSection,
          ),
          CreaturesScreen(key: _creaturesKey),
          const ShopScreen(),
          BreedScreen(onGoToSection: _goToSection),
          const InventoryScreen(),
        ],
      ),
      bottomNavigationBar: BottomNav(
        current: _currentSection,
        onSelect: (s) => _goToSection(s),
        theme: theme,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final bool isActive;
  final void Function(NavSection section, {int? breedInitialTab})
  onNavigateSection;

  const HomeScreen({
    super.key,
    required this.isActive,
    required this.onNavigateSection,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, RouteAware {
  late AnimationController _breathingController;
  late AnimationController _rotationController;
  late AnimationController _particleController;
  late AnimationController _waveController;
  late AnimationController _glowController;

  final PushNotificationService _pushNotifications = PushNotificationService();
  String? _lastEggStateKey;
  String? _lastHarvestStateKey;

  bool _isFieldTutorialActive = false;

  bool _isInitialized = false;

  // Notification banners
  final List<NotificationBanner> _activeNotifications = [];

  // Stream subscriptions for reactive notifications
  async.StreamSubscription<List<IncubatorSlot>>? _slotsSubscription;
  async.StreamSubscription<List<BiomeFarm>>? _biomesSubscription;

  // FEATURED HERO STATE
  PresentationData? _featuredData;
  String? _featuredInstanceId;
  bool _animationsEnabled = false;

  void _updateAnimationState() {
    // home tab active AND this route is the top-most one
    final modalRoute = ModalRoute.of(context);
    final routeIsCurrent = modalRoute?.isCurrent ?? true;
    final shouldEnable =
        widget.isActive && routeIsCurrent && !_isFieldTutorialActive;

    if (shouldEnable == _animationsEnabled) return;

    setState(() {
      _animationsEnabled = shouldEnable;
    });
  }

  @override
  void initState() {
    super.initState();

    _breathingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _particleController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    _waveController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeApp();
      if (mounted) {
        await _checkFieldTutorial();
        await _refreshNotificationsNow();
      }
    });
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _updateAnimationState();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
    _updateAnimationState();
  }

  @override
  void didPushNext() {
    _updateAnimationState(); // route no longer current → disables TickerMode
  }

  @override
  void didPopNext() {
    _updateAnimationState();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _breathingController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    _waveController.dispose();
    _glowController.dispose();
    _slotsSubscription?.cancel();
    _biomesSubscription?.cancel();

    // Remove wilderness spawn listener
    final spawnService = context.read<WildernessSpawnService>();
    spawnService.removeListener(_checkWildernessNotifications);

    super.dispose();
  }

  Future<void> _checkFieldTutorial() async {
    final db = context.read<AlchemonsDatabase>();
    final completed = await db.settingsDao.hasCompletedFieldTutorial();

    if (!completed) {
      await db.settingsDao.setNavLocked(true);

      setState(() {
        _isFieldTutorialActive = true;
        _activeNotifications.clear();
      });

      _updateAnimationState(); // 🔹 ensure animations disable for tutorial
    }
  }

  Future<void> _handleFieldTutorialTap() async {
    if (!_isFieldTutorialActive) return;

    HapticFeedback.mediumImpact();

    final tutorialCompleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const MapScreen(isTutorial: true)),
    );

    if (tutorialCompleted == true && mounted) {
      final db = context.read<AlchemonsDatabase>();
      await db.settingsDao.setFieldTutorialCompleted();
      await db.settingsDao.setNavLocked(false);

      setState(() {
        _isFieldTutorialActive = false;
      });

      _updateAnimationState(); // 🔹 re-enable after tutorial
    }
  }

  Future<void> _initializeApp() async {
    await _pushNotifications.initialize();
    try {
      await _initializeRepository();
      if (!mounted) return;
      final factionSvc = context.read<FactionService>();

      await factionSvc.loadId();
      var faction = factionSvc.current;

      if (!mounted) return;

      // First-time intro is handled in AppGate now.
      // If somehow we still don't have a faction yet, just bail for now.
      if (faction == null) {
        debugPrint(
          'HomeScreen._initializeApp: faction is null; intro flow should have run in AppGate.',
        );
        return;
      }

      if (!mounted) return;
      final spawnService = context.read<WildernessSpawnService>();

      await _grantStarterIfNeeded(faction, spawnService);

      // Load featured hero
      final featuredInstance = await _loadFeaturedInstanceOrAuto();
      if (featuredInstance != null) {
        final repo = context.read<CreatureCatalog>();
        _featuredInstanceId = featuredInstance.instanceId;
        _featuredData = _presentationFromInstance(featuredInstance, repo);
      } else {
        _featuredInstanceId = null;
        _featuredData = null;
      }

      setState(() => _isInitialized = true);

      // Reactive watchers (streams)
      _setupNotificationWatchers();

      // Check wilderness now
      _checkWildernessNotifications();

      final pushNotifications = PushNotificationService();
      await pushNotifications.debugPrintPendingNotifications();

      // Recreate per-egg schedules on cold start
      await _rehydrateEggSchedules();
    } catch (e, st) {
      debugPrint('Error during app initialization: $e');
      debugPrint('Error during app initialization: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initialize app: $e'),
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _initializeRepository() async {
    try {} catch (e) {
      debugPrint('Error loading creature repository: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load specimen database: $e'),
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  // ============================================================
  // REACTIVE NOTIFICATION SYSTEM
  // ============================================================

  void _setupNotificationWatchers() {
    final db = context.read<AlchemonsDatabase>();
    final spawnService = context.read<WildernessSpawnService>();

    // Eggs: react to slot changes (schedule/cancel per-egg notis, show in-app banner)
    _slotsSubscription = db.incubatorDao.watchSlots().listen(
      _checkEggNotifications,
    );

    // Harvests: react to biome changes
    _biomesSubscription = db.biomeDao.watchBiomes().listen(
      _checkBiomeNotifications,
    );

    // Wilderness spawns
    spawnService.addListener(_checkWildernessNotifications);
  }

  // Manual refresh when landing on Home / returning to Home
  Future<void> _refreshNotificationsNow() async {
    if (!mounted || _isFieldTutorialActive) return;

    final db = context.read<AlchemonsDatabase>();
    final slots = await db.incubatorDao.watchSlots().first;
    _checkEggNotifications(slots);

    final biomes = await db.biomeDao.watchBiomes().first;
    _checkBiomeNotifications(biomes);

    _checkWildernessNotifications();
  }

  // Wilderness
  void _checkWildernessNotifications() {
    if (!mounted) return;

    final spawnService = context.read<WildernessSpawnService>();

    if (spawnService.hasAnyActiveSpawns) {
      final debugInfo = spawnService.getDebugInfo();
      final totalSpawns = debugInfo['total_spawns'] as int;
      final scenesWithSpawns = debugInfo['scenes_with_spawns'] as int;

      debugPrint(
        '🌲 Wilderness notification check: $totalSpawns spawns across $scenesWithSpawns scenes',
      );

      _showNotification(
        NotificationBanner(
          type: NotificationBannerType.wildernessSpawn,
          title: 'SPECIMENS DETECTED',
          subtitle:
              'Wild specimens available in $scenesWithSpawns location${scenesWithSpawns > 1 ? 's' : ''}',
          count: totalSpawns,
          stateKey: 'spawns:$totalSpawns/$scenesWithSpawns',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MapScreen()),
            );
          },
        ),
      );
    } else {
      debugPrint('🌲 Clearing wilderness notification (no active spawns)');
      _clearNotification(NotificationBannerType.wildernessSpawn);
    }
  }

  // Eggs (per-egg scheduling only; no consolidated push)
  void _checkEggNotifications(List<IncubatorSlot> slots) async {
    if (!mounted) return;

    int readyEggs = 0;
    final nowUtc = DateTime.now().toUtc();
    final List<Future> scheduleTasks = [];
    final List<int> slotsToCancel = [];
    final List<int> readySlotIds = [];

    for (final slot in slots) {
      if (slot.unlocked && slot.eggId != null && slot.hatchAtUtcMs != null) {
        final hatchUtc = DateTime.fromMillisecondsSinceEpoch(
          slot.hatchAtUtcMs!,
          isUtc: true,
        );

        if (!hatchUtc.isAfter(nowUtc)) {
          readyEggs++;
          readySlotIds.add(slot.id);
          // Cancel per-slot scheduled notification (it would be in the past now)
          slotsToCancel.add(slot.id);
        } else {
          // Schedule/update the per-egg local notification
          scheduleTasks.add(
            _pushNotifications.scheduleEggHatchingNotification(
              hatchTime: hatchUtc.toLocal(),
              eggId: slot.eggId!,
              slotIndex: slot.id,
            ),
          );
        }
      }
    }

    for (final slotId in slotsToCancel) {
      await _pushNotifications.cancelEggNotification(slotIndex: slotId);
    }
    if (scheduleTasks.isNotEmpty) {
      await Future.wait(scheduleTasks);
    }

    debugPrint('🥚 Egg notification check: $readyEggs eggs ready');

    if (readyEggs > 0) {
      readySlotIds.sort();
      final stateKey = 'slots:${readySlotIds.join(",")}';

      // De-dupe: if same stateKey as last emission, do nothing.
      if (_lastEggStateKey == stateKey) return;
      _lastEggStateKey = stateKey;

      _showNotification(
        NotificationBanner(
          type: NotificationBannerType.eggReady,
          title: 'Alchemon ready to extract!',
          subtitle: 'Tap to view incubator',
          count: readyEggs,
          stateKey: stateKey,
          onTap: () {
            widget.onNavigateSection(NavSection.breed, breedInitialTab: 1);
          },
        ),
      );
    } else {
      _lastEggStateKey = null; // reset de-dupe
      _clearNotification(NotificationBannerType.eggReady);
    }
  }

  void _checkBiomeNotifications(List<BiomeFarm> biomes) async {
    if (!mounted) return;

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final db = context.read<AlchemonsDatabase>();

    // Build futures for unlocked biomes
    final futures = <Future<({BiomeFarm farm, HarvestJob? job})>>[];

    for (final farm in biomes) {
      if (!farm.unlocked) continue;

      futures.add(() async {
        final job = await db.biomeDao.getActiveJobForBiome(farm.id);
        return (farm: farm, job: job);
      }());
    }

    final results = await Future.wait(futures);

    int readyHarvests = 0;
    final List<int> readyBiomeIds = [];

    for (final result in results) {
      final job = result.job;
      if (job == null) continue;

      final endMs = job.startUtcMs + job.durationMs;
      if (endMs <= nowMs) {
        readyHarvests++;
        readyBiomeIds.add(result.farm.id);
      }
    }

    debugPrint('⚗️ Harvest notification check: $readyHarvests ready');

    if (readyHarvests > 0) {
      readyBiomeIds.sort();
      final stateKey = 'biomes:${readyBiomeIds.join(",")}';

      if (_lastHarvestStateKey == stateKey) return;
      _lastHarvestStateKey = stateKey;

      _showNotification(
        NotificationBanner(
          type: NotificationBannerType.harvestReady,
          title: 'HARVEST COMPLETE',
          subtitle: 'Tap to collect resources',
          count: readyHarvests,
          stateKey: stateKey,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BiomeHarvestScreen()),
            );
          },
        ),
      );

      await _pushNotifications.showHarvestReadyNotification(
        count: readyHarvests,
      );
    } else {
      _lastHarvestStateKey = null;
      _clearNotification(NotificationBannerType.harvestReady);
    }
  }

  // Restore per-egg schedules on app start so OS will fire them even if app is killed
  Future<void> _rehydrateEggSchedules() async {
    final db = context.read<AlchemonsDatabase>();
    final slots = await db.incubatorDao.watchSlots().first;
    final now = DateTime.now().toUtc();

    for (final s in slots) {
      if (!(s.unlocked && s.eggId != null && s.hatchAtUtcMs != null)) continue;

      final hatchUtc = DateTime.fromMillisecondsSinceEpoch(
        s.hatchAtUtcMs!,
        isUtc: true,
      );

      // Avoid duplicates: cancel then reschedule if still in the future
      await _pushNotifications.cancelEggNotification(slotIndex: s.id);
      if (hatchUtc.isAfter(now)) {
        await _pushNotifications.scheduleEggHatchingNotification(
          hatchTime: hatchUtc.toLocal(),
          eggId: s.eggId!,
          slotIndex: s.id,
        );
      }
    }
  }

  void _showNotification(NotificationBanner banner) {
    if (!mounted || _isFieldTutorialActive) return; // 🔹 block during tutorial

    setState(() {
      // Ensure ONLY ONE banner per type at a time.
      _activeNotifications.removeWhere((n) => n.type == banner.type);
      _activeNotifications.add(banner);
      debugPrint(
        '📢 Showing notification: ${banner.type} (${banner.title}) [${banner.stateKey}]',
      );
    });
  }

  void _clearNotification(NotificationBannerType type) async {
    if (!mounted) return;

    try {
      final db = context.read<AlchemonsDatabase>();
      // Clear all dismissals for this type (any prior state).
      // We want future states to be eligible again.
      await (db.delete(
        db.notificationDismissals,
      )..where((t) => t.notificationType.like('${type.toKey()}%'))).go();
    } catch (e) {
      debugPrint('Error clearing notification dismissal: $e');
    }

    setState(() {
      final hadAny = _activeNotifications.any((n) => n.type == type);
      _activeNotifications.removeWhere((n) => n.type == type);
      if (hadAny) {
        debugPrint('🗑️  Cleared notification: $type');
      }
    });
  }

  ({double particle, double rotation, double elemental}) _speedFor(
    FactionId faction,
  ) {
    switch (faction) {
      case FactionId.volcanic:
        return (particle: .1, rotation: 0.1, elemental: .3);
      case FactionId.oceanic:
        return (particle: 1, rotation: 0.1, elemental: .5);
      case FactionId.verdant:
        return (particle: 1, rotation: 0.1, elemental: 1);
      case FactionId.earthen:
        return (particle: 1, rotation: 0.1, elemental: 0.2);
    }
  }

  // ============================================================
  // FEATURED HERO HELPERS
  // ============================================================

  Future<CreatureInstance?> _loadFeaturedInstanceOrAuto() async {
    final db = context.read<AlchemonsDatabase>();

    // Attempt to load saved featured instance
    final savedId = await db.settingsDao.getFeaturedInstanceId();
    if (savedId != null && savedId.isNotEmpty) {
      final chosen = await db.creatureDao.getInstance(savedId);
      if (chosen != null) {
        return chosen;
      }
    }

    // Auto-pick fallback
    final all = await db.creatureDao.listAllInstances();
    if (all.isEmpty) return null;

    // prefer prismatic
    final prismatics = all.where((ci) => ci.isPrismaticSkin == true).toList();
    if (prismatics.isNotEmpty) {
      return prismatics.first;
    }

    // else best "rarity" via stat potential heuristic
    all.sort((a, b) {
      final aScore =
          (a.statSpeedPotential +
                  a.statIntelligencePotential +
                  a.statStrengthPotential +
                  a.statBeautyPotential)
              .toDouble();
      final bScore =
          (b.statSpeedPotential +
                  b.statIntelligencePotential +
                  b.statStrengthPotential +
                  b.statBeautyPotential)
              .toDouble();
      return bScore.compareTo(aScore);
    });

    return all.first;
  }

  PresentationData? _presentationFromInstance(
    CreatureInstance pick,
    CreatureCatalog repo,
  ) {
    final base = repo.getCreatureById(pick.baseId);
    if (base == null) {
      debugPrint(
        'FeaturedPresentation: could not find base creature for ${pick.baseId}',
      );
      return null;
    }

    final sprite = base.spriteData;
    if (sprite == null) {
      debugPrint('FeaturedPresentation: no spriteData for ${base.id}');
      return null;
    }

    // Title line: nickname or species name
    final displayTitle =
        (pick.nickname != null && pick.nickname!.trim().isNotEmpty)
        ? pick.nickname!.trim()
        : base.name;

    // Flavor subtitle
    final primaryType = (base.types.isNotEmpty) ? base.types.first : '???';

    // specimen short tag
    final shortTag = (pick.instanceId.length <= 4)
        ? pick.instanceId.toUpperCase()
        : pick.instanceId.substring(pick.instanceId.length - 4).toUpperCase();

    final subtitleLine = [
      'LVL ${pick.level}',
      primaryType.toUpperCase(),
      'SPECIMEN #$shortTag',
    ].join(' • ');

    final finalSubtitle = pick.isPrismaticSkin
        ? 'PRISMATIC VARIANT • $subtitleLine'
        : subtitleLine;

    return PresentationData(
      displayName: displayTitle,
      subtitle: finalSubtitle,
      instance: pick,
      creature: base,
    );
  }

  Future<void> _handleChooseFeaturedInstance() async {
    HapticFeedback.mediumImpact();

    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final theme = context.read<FactionTheme>();

    final available = await db.creatureDao.getSpeciesWithInstances();

    // Build typed discovered list from DB + catalog
    final playerRows = await db.creatureDao.getAllCreatures();
    final discoveredIds = playerRows
        .where((p) => p.discovered)
        .map((p) => p.id)
        .toSet();

    final discoveredTyped = repo.creatures
        .where((c) => discoveredIds.contains(c.id))
        .map(
          (c) => CreatureEntry(
            creature: c,
            player: playerRows.firstWhere((p) => p.id == c.id),
          ),
        )
        .toList(growable: false);

    // Filter to species that actually have instances
    final filteredDiscovered = filterByAvailableInstances(
      discoveredTyped,
      available,
    );

    // Step 1: pick species
    final pickedSpeciesId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return CreatureSelectionSheet(
              scrollController: scrollController,
              discoveredCreatures: filteredDiscovered,
              onSelectCreature: (creatureId) {
                Navigator.pop(context, creatureId);
              },
            );
          },
        );
      },
    );

    if (pickedSpeciesId == null) return;

    final species = repo.getCreatureById(pickedSpeciesId);
    if (species == null) return;

    // Step 2: pick instance of that species
    final pickedInstance = await showModalBottomSheet<CreatureInstance>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return BottomSheetShell(
          theme: theme,
          title: '${species.name} Specimens',
          child: InstancesSheet(
            theme: theme,
            species: species,
            onTap: (CreatureInstance ci) {
              Navigator.pop(context, ci);
            },
          ),
        );
      },
    );
    if (pickedInstance == null) return;

    // Step 3: persist choice
    await db.settingsDao.setFeaturedInstanceId(pickedInstance.instanceId);

    // Step 4: update local state
    final newPresentation = _presentationFromInstance(pickedInstance, repo);
    if (!mounted) return;
    setState(() {
      _featuredInstanceId = pickedInstance.instanceId;
      _featuredData = newPresentation;
    });

    HapticFeedback.lightImpact();
  }

  Future<void> _handleOpenFeaturedDetails() async {
    final repo = context.read<CreatureCatalog>();
    final db = context.read<AlchemonsDatabase>();

    final id = _featuredInstanceId;
    if (id == null) return;

    final inst = await db.creatureDao.getInstance(id);
    if (inst == null) return;

    final base = repo.getCreatureById(inst.baseId);
    if (base == null) return;

    CreatureDetailsDialog.show(
      context,
      base,
      true,
      instanceId: inst.instanceId,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return withGameData(
      context,
      isInitialized: _isInitialized,
      loadingBuilder: buildLoadingScreen,
      builder:
          (
            context, {
            required theme,
            required catalog,
            required entries,
            required discovered,
          }) {
            final factionSvc = context.watch<FactionService>();
            final currentFaction = factionSvc.current ?? FactionId.oceanic;
            final speeds = _speedFor(currentFaction);

            return Stack(
              children: [
                // Background is always the home background here
                TickerMode(
                  enabled: _animationsEnabled,
                  child: RepaintBoundary(
                    child: InteractiveBackground(
                      particleController: _particleController,
                      rotationController: _rotationController,
                      waveController: _waveController,
                      primaryColor: theme.primary,
                      secondaryColor: theme.secondary,
                      accentColor: theme.accent,
                      factionType: currentFaction,
                      particleSpeed: speeds.particle,
                      rotationSpeed: speeds.rotation,
                      elementalSpeed: speeds.elemental,
                    ),
                  ),
                ),

                SafeArea(
                  top: true,
                  child: Column(
                    children: [
                      _buildHeader(theme),

                      if (_featuredData != null) ...[
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 260,
                          child: Center(
                            child: TickerMode(
                              enabled: _animationsEnabled,
                              child: FeaturedHeroInteractive(
                                data: _featuredData!,
                                theme: theme,
                                breathing: _breathingController,
                                onLongPressChoose:
                                    _handleChooseFeaturedInstance,
                                onTapDetails: _handleOpenFeaturedDetails,
                                instance: _featuredData!.instance,
                                creature: _featuredData!.creature,
                              ),
                            ),
                          ),
                        ),
                      ],

                      Expanded(child: _buildHomeContent(theme)),
                    ],
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 140,
                  left: 0,
                  child: Consumer<WildernessSpawnService>(
                    builder: (context, spawnService, child) {
                      final hasSpawns = spawnService.hasAnyActiveSpawns;
                      return Stack(
                        children: [
                          child!,
                          if (hasSpawns)
                            Positioned(
                              top: 0,
                              right: 10,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.6),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                    child: SideDockFloating(
                      theme: theme,
                      showHarvestDot:
                          !_isFieldTutorialActive &&
                          context.select<HarvestService, bool>(
                            (s) =>
                                s.biomes.any((f) => f.unlocked && f.completed),
                          ),
                      highlightField: _isFieldTutorialActive,
                      onField: () {
                        if (_isFieldTutorialActive) {
                          _handleFieldTutorialTap();
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MapScreen(),
                            ),
                          );
                        }
                      },
                      onEnhance: _isFieldTutorialActive
                          ? () {}
                          : () {
                              HapticFeedback.mediumImpact();
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => const FeedingScreen(),
                                  fullscreenDialog: true,
                                ),
                              );
                            },
                      onHarvest: _isFieldTutorialActive
                          ? () {}
                          : () {
                              HapticFeedback.mediumImpact();
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => const BiomeHarvestScreen(),
                                  fullscreenDialog: true,
                                ),
                              );
                            },
                      onCompetitions: _isFieldTutorialActive
                          ? () {}
                          : () {
                              HapticFeedback.mediumImpact();
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => const CompetitionHubScreen(),
                                  fullscreenDialog: true,
                                ),
                              );
                            },

                      onBattle: _isFieldTutorialActive
                          ? () {}
                          : () {
                              HapticFeedback.mediumImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BossBattleScreen(),
                                ),
                              );
                            },
                      onBoss: _isFieldTutorialActive
                          ? () {}
                          : () {
                              HapticFeedback.mediumImpact();
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BossBattleScreen(),
                                ),
                              );
                            },
                    ),
                  ),
                ),

                // RIGHT-SIDE BUTTON (new)
                Stack(
                  children: [
                    // --- 1. First Icon (Your existing "BATTLE" icon) ---
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 125,
                      right: 0,
                      child: Opacity(
                        opacity: _isFieldTutorialActive ? 0.4 : 1.0,
                        child: IgnorePointer(
                          ignoring: _isFieldTutorialActive,
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BossBattleScreen(),
                              ),
                            ),
                            child: Column(
                              children: [ConstellationPointsWidget()],
                            ),
                          ),
                        ),
                      ),
                    ),
                    //go to survival battle screen on tap
                    // --- 2. Second Icon (NEW ICON) ---
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 200,
                      right: 0,
                      child: Opacity(
                        opacity: _isFieldTutorialActive ? 0.4 : 1.0,
                        child: IgnorePointer(
                          ignoring: _isFieldTutorialActive,
                          child: GestureDetector(
                            onTap: () =>
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SurvivalGameScreen(),
                                  ),
                                ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.shield,
                                  size: 36,
                                  color: theme.accent,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'SURVIVAL',
                                  style: TextStyle(
                                    color: theme.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Side dock etc. (static, doesn’t need TickerMode)
                TickerMode(
                  enabled: _animationsEnabled,
                  child: FloatingBubblesOverlay(
                    regionPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                    discoveredCreatures: discovered,
                    theme: theme,
                  ),
                ),

                if (_activeNotifications.isNotEmpty)
                  NotificationBannerStack(
                    key: ValueKey(
                      _activeNotifications
                          .map((n) => '${n.type.toKey()}|${n.stateKey}')
                          .join(','),
                    ),
                    notifications: _activeNotifications,
                  ),
              ],
            );
          },
    );
  }

  Widget _buildHomeContent(FactionTheme theme) {
    return SingleChildScrollView();
  }

  Future<void> _grantStarterIfNeeded(
    FactionId faction,
    WildernessSpawnService spawnService,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final starterService = context.read<StarterGrantService>(); // Add this

    // Ensure at least one slot is unlocked
    final slots = await db.incubatorDao.watchSlots().first;
    final anyUnlocked = slots.any((s) => s.unlocked);
    if (!anyUnlocked) {
      await db.incubatorDao.unlockSlot(0);
    }

    final granted = await starterService.ensureStarterGranted(
      faction,
      tutorialHatch: const Duration(seconds: 10),
    );

    if (granted) {
      await spawnService.clearSceneSpawns('valley');
      await spawnService.scheduleNextSpawnTime(
        'valley',
        windowMax: Duration(seconds: 10),
      );
      if (!mounted) return;
      await SystemDialog.show(
        context,
        title: 'VIAL SECURED',
        message:
            'Your vial has been placed in the Extraction Chamber and is ready for processing.',
        kind: SystemDialogKind.success,
        typewriter: true,
        onPrimary: () async {
          // Mark that we're in extraction tutorial phase
          final db = context.read<AlchemonsDatabase>();
          await db.settingsDao.setSetting('tutorial_extraction_pending', '1');
          await db.settingsDao.setNavLocked(true);
          if (!mounted) return;
          widget.onNavigateSection(NavSection.breed, breedInitialTab: 1);
        },
      );
    }
  }

  Widget _buildHeader(FactionTheme theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 🔹 Disable + dim Profile button during Field Tutorial
            if (_isFieldTutorialActive)
              Opacity(
                opacity: 0.35,
                child: IgnorePointer(
                  ignoring: true,
                  child: AvatarButton(
                    theme: theme,
                    onTap: () {}, // disabled during tutorial
                  ),
                ),
              )
            else
              AvatarButton(
                theme: theme,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) =>
                          ProfileScreen(() => Navigator.pop(context)),
                      fullscreenDialog: true,
                    ),
                  );
                },
              ),

            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: ResourceCollectionWidget(theme: theme),
              ),
            ),
          ],
        ),
        Column(
          children: [
            //use asset image here
            ClipRect(
              child: Align(
                // ✅ Change this back to center!
                alignment: Alignment.center,
                // Adjust this value until the padding is gone from BOTH sides.
                // It will likely be a value like 0.7 or 0.6.
                heightFactor: 0.2,
                child: theme.brightness == Brightness.dark
                    ? Image.asset(
                        'assets/images/ui/alchemonstitle.png',
                        height: 300,
                        gaplessPlayback: true,
                      )
                    : Image.asset(
                        'assets/images/ui/alchemonstitledark.png',
                        height: 300,
                        gaplessPlayback: true,
                      ),
              ),
            ),
            Text(
              'Research Facility',
              style: GoogleFonts.cinzelDecorative(
                color: theme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
            CurrencyDisplayWidget(),
          ],
        ),
      ],
    );
  }
}
