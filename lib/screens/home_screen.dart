// (imports unchanged except where noted)
import 'dart:async' as async;
import 'dart:math';

import 'package:lottie/lottie.dart';
import 'package:alchemons/models/biome_farm_state.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/battle_mode_screen.dart';
import 'package:alchemons/screens/boss/boss_intro_screen.dart';
import 'package:alchemons/screens/competition_hub_screen.dart';
import 'package:alchemons/screens/inventory_screen.dart';
import 'package:alchemons/screens/map_screen.dart';
import 'package:alchemons/screens/upgrade_tree/constellation_points_widget.dart';
import 'package:alchemons/screens/mystic_altar/mystic_altar_screen.dart';
import 'package:alchemons/data/boss_data.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/providers/boss_provider.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/harvest_service.dart';
import 'package:alchemons/services/notification_preferences_service.dart';
import 'package:alchemons/services/push_notification_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/utils/creature_instance_uti.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/widgets/avatar_widget.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';

import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/widgets/creature_showcase_widget.dart';
import 'package:alchemons/widgets/currency_display_widget.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:alchemons/widgets/notification_banner_system.dart';
import 'package:alchemons/widgets/side_dock_widget.dart';
import 'package:alchemons/widgets/starter_granted_dialog.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flame/flame.dart' show Flame;
import 'package:flutter/cupertino.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/screens/creatures_screen.dart';
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
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'breed/breed_screen.dart';

const bool kEnableCosmicShip = true;

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

    // Unfocus the creatures search field when leaving that tab
    if (_currentSection == NavSection.creatures) {
      _creaturesKey.currentState?.unfocusSearch();
    }

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
          TickerMode(
            enabled: _currentSection == NavSection.home,
            child: HomeScreen(
              isActive: _currentSection == NavSection.home,
              onNavigateSection: _goToSection,
            ),
          ),
          TickerMode(
            enabled: _currentSection == NavSection.creatures,
            child: CreaturesScreen(key: _creaturesKey),
          ),
          TickerMode(
            enabled: _currentSection == NavSection.shop,
            child: const ShopScreen(),
          ),
          TickerMode(
            enabled: _currentSection == NavSection.breed,
            child: BreedScreen(onGoToSection: _goToSection),
          ),
          TickerMode(
            enabled: _currentSection == NavSection.inventory,
            child: const InventoryScreen(),
          ),
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

// Wrapper that pulses the cosmic orb when the ship home-animation flag is pending.
class _AnimatedCosmicOrb extends StatefulWidget {
  final VoidCallback? onPulse;
  const _AnimatedCosmicOrb({this.onPulse});

  @override
  State<_AnimatedCosmicOrb> createState() => _AnimatedCosmicOrbState();
}

class _AnimatedCosmicOrbState extends State<_AnimatedCosmicOrb>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  Animation<double>? _scale;
  bool _visible = false;
  bool _wiredSettings = false;
  bool _isPulsing = false;
  async.StreamSubscription<String?>? _shipUnlockedSub;
  async.StreamSubscription<String?>? _shipAnimPendingSub;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl!, curve: Curves.easeInOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wiredSettings) return;
    _wiredSettings = true;
    final db = context.read<AlchemonsDatabase>();

    _shipUnlockedSub = db.settingsDao
        .watchSetting('cosmic_ship_unlocked')
        .listen((raw) {
          final unlocked = raw == '1';
          if (!mounted || unlocked == _visible) return;
          setState(() => _visible = unlocked);
        });

    _shipAnimPendingSub = db.settingsDao
        .watchSetting('cosmic_ship_home_anim_pending')
        .listen((raw) {
          if (raw == '1') {
            _consumePendingPulse(db);
          }
        });
  }

  Future<void> _consumePendingPulse(AlchemonsDatabase db) async {
    if (!mounted || _isPulsing) return;
    _isPulsing = true;
    widget.onPulse?.call();

    try {
      _ctrl?.stop();
      _ctrl?.reset();
      await _ctrl?.forward();
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      _ctrl?.reset();
      await _ctrl?.forward();
    } catch (_) {
      // ignore animation errors if lifecycle changes mid-pulse
    } finally {
      try {
        await db.settingsDao.deleteSetting('cosmic_ship_home_anim_pending');
      } catch (_) {}
      _isPulsing = false;
    }
  }

  @override
  void dispose() {
    _shipUnlockedSub?.cancel();
    _shipAnimPendingSub?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _ctrl!,
      builder: (context, child) {
        final s = _scale?.value ?? 1.0;
        return Transform.scale(scale: s, child: child);
      },
      child: const CosmicOrbWidget(),
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
  static const List<String> _coreWildernessBiomes = [
    'valley',
    'sky',
    'volcano',
    'swamp',
  ];

  late AnimationController _breathingController;
  late AnimationController _rotationController;
  late AnimationController _particleController;
  late AnimationController _waveController;
  late AnimationController _shakeController;

  final PushNotificationService _pushNotifications = PushNotificationService();
  String? _lastEggStateKey;
  String? _lastHarvestStateKey;
  String? _lastWildernessStateKey;
  final Map<int, int> _lastScheduledEggHatchMsBySlot = {};
  Set<int> _lastReadyEggSlotIds = <int>{};

  bool _isFieldTutorialActive = false;
  bool _tutorialCheckInProgress =
      false; // prevents double-fire from didUpdateWidget + didPopNext
  bool _arcanePortalUnlocked = false;

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

    if (shouldEnable) {
      async.unawaited(context.read<AudioController>().playHomeMusic());
    }
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

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeApp();
      if (mounted) {
        await _checkFieldTutorial();
        await _refreshNotificationsNow();
      }
    });
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

  // MODIFY didUpdateWidget to call it:

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _updateAnimationState();

      if (widget.isActive) {
        // 🔄 Always sync from DB when Home becomes active
        _checkFieldTutorial();
      }
    }
  }

  @override
  void didPopNext() {
    _updateAnimationState();

    if (widget.isActive) {
      // 🔄 When returning to Home, sync from DB
      _checkFieldTutorial();
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _breathingController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    _waveController.dispose();
    _shakeController.dispose();
    _slotsSubscription?.cancel();
    _biomesSubscription?.cancel();

    // Remove wilderness spawn listener
    final spawnService = context.read<WildernessSpawnService>();
    spawnService.removeListener(_checkWildernessNotifications);

    super.dispose();
  }

  Future<void> _checkFieldTutorial() async {
    if (_tutorialCheckInProgress) return;
    _tutorialCheckInProgress = true;
    try {
      final db = context.read<AlchemonsDatabase>();
      final spawnService = context.read<WildernessSpawnService>();

      // 🔹 First: if tutorial is already completed in DB, make sure local state matches
      final completed = await db.settingsDao.hasCompletedFieldTutorial();

      if (completed) {
        // unlock nav just in case
        await db.settingsDao.setNavLocked(false);

        if (_isFieldTutorialActive) {
          if (!mounted) return;
          setState(() {
            _isFieldTutorialActive = false;
            _activeNotifications.clear();
          });
          _updateAnimationState();
        }

        return; // nothing else to do
      } // Check if extraction tutorial is still pending
      final extractionPending =
          await db.settingsDao.getSetting('tutorial_extraction_pending') == '1';
      if (extractionPending) {
        debugPrint(
          '🎓 Tutorial: Extraction pending, redirecting to breed screen',
        );
        await db.settingsDao.setNavLocked(true);
        widget.onNavigateSection(NavSection.breed, breedInitialTab: 1);
        return;
      }

      if (!completed) {
        // 🔑 STEP 3: Verify user actually has creatures before starting field tutorial
        final instances = await db.creatureDao.listAllInstances();

        if (instances.isEmpty) {
          debugPrint('🎓 Tutorial: No creatures found, checking for eggs...');

          // No creatures yet - check if there's an egg they need to extract
          final slots = await db.incubatorDao.watchSlots().first;
          final hasEgg = slots.any((s) => s.unlocked && s.eggId != null);

          if (hasEgg) {
            // Has egg but no creatures - send to extraction
            debugPrint('🎓 Tutorial: Found egg, redirecting to extraction');
            await db.settingsDao.setNavLocked(true);
            // Mark extraction as pending since they clearly need to do it
            await db.settingsDao.setSetting('tutorial_extraction_pending', '1');
            widget.onNavigateSection(NavSection.breed, breedInitialTab: 1);
          } else {
            // No egg and no creatures - check if starter was ever granted
            final starterGranted =
                await db.settingsDao.getSetting('starter_granted_v1') == '1';

            if (!starterGranted) {
              // Let normal starter flow handle it in _grantStarterIfNeeded
              debugPrint(
                '🎓 Tutorial: No starter granted yet, waiting for grant flow',
              );
            } else {
              // Edge case: starter was granted but egg is gone and no creatures
              // This shouldn't happen, but if it does, skip tutorial
              debugPrint(
                '🎓 Tutorial: Edge case - starter granted but no egg/creatures, skipping field tutorial',
              );
              await db.settingsDao.setFieldTutorialCompleted();
              await db.settingsDao.setNavLocked(false);
            }
          }
          return;
        }

        // User has creatures - proceed with field tutorial
        debugPrint('🎓 Tutorial: Starting field tutorial');
        await db.settingsDao.setNavLocked(true);

        final hasCoreBiomeSpawns = _coreWildernessBiomes.any(
          (biomeId) => spawnService.getSceneSpawnCount(biomeId) > 0,
        );
        if (!hasCoreBiomeSpawns) {
          debugPrint(
            '🎓 Tutorial: No spawns found, scheduling immediate spawn for tutorial',
          );
          await spawnService.clearSceneSpawns('valley');
          await spawnService.scheduleNextSpawnTime(
            'valley',
            windowMax: const Duration(seconds: 3),
            force: true,
          );
        }

        setState(() {
          _isFieldTutorialActive = true;
          _activeNotifications.clear();
        });

        _updateAnimationState();
      }
    } finally {
      _tutorialCheckInProgress = false;
    }
  }

  Future<void> _handleFieldTutorialTap() async {
    if (!_isFieldTutorialActive) return;

    HapticFeedback.mediumImpact();

    // We don't care about the bool now, Scene/Map writes to DB
    await Navigator.push<bool>(
      context,
      CupertinoPageRoute(
        builder: (_) => MapScreen(
          isTutorial: true,
          onNavigateSection: widget.onNavigateSection,
        ),
        fullscreenDialog: true,
      ),
    );

    if (!mounted) return;

    // 🔄 After returning, always sync with DB flag
    await _checkFieldTutorial();
  }

  Future<void> _initializeApp() async {
    await _pushNotifications.initialize();
    try {
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
      await _seedMissingBossTraitKeys();

      // Load featured hero
      final featuredInstance = await _loadFeaturedInstanceOrAuto();
      debugPrint('🎯 Featured instance: ${featuredInstance?.instanceId}');
      debugPrint('🎯 Featured baseId: ${featuredInstance?.baseId}');

      if (featuredInstance != null) {
        if (!mounted) return;
        final repo = context.read<CreatureCatalog>();
        final base = repo.getCreatureById(featuredInstance.baseId);

        debugPrint('🎯 Base creature: ${base?.name}');
        debugPrint('🎯 SpriteData: ${base?.spriteData}');
        debugPrint('🎯 SpriteData path: ${base?.spriteData?.spriteSheetPath}');

        _featuredInstanceId = featuredInstance.instanceId;
        await _prewarmFeaturedSprite(featuredInstance, repo);
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

      await _pushNotifications.debugPrintPendingNotifications();

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
    await _checkEggNotifications(slots);

    final biomes = await db.biomeDao.watchBiomes().first;
    await _checkBiomeNotifications(biomes);

    await _checkWildernessNotifications();
  }

  // Wilderness
  Future<void> _checkWildernessNotifications() async {
    if (!mounted) return;
    final enabled = await NotificationPreferencesService()
        .isWildernessEnabled();
    if (!mounted) return;
    if (!enabled) {
      _lastWildernessStateKey = null;
      await _pushNotifications.cancelWildernessNotifications();
      _clearNotification(NotificationBannerType.wildernessSpawn);
      return;
    }

    final spawnService = context.read<WildernessSpawnService>();
    final visibleBiomes = await _visibleWildernessBiomes();
    if (!mounted) return;
    final totalSpawns = visibleBiomes.fold<int>(
      0,
      (sum, biomeId) => sum + spawnService.getSceneSpawnCount(biomeId),
    );
    final scenesWithSpawns = visibleBiomes.where((biomeId) {
      return spawnService.getSceneSpawnCount(biomeId) > 0;
    }).length;

    if (totalSpawns > 0) {
      final stateKey = 'spawns:$totalSpawns/$scenesWithSpawns';

      debugPrint(
        '🌲 Wilderness notification check: $totalSpawns visible spawns across $scenesWithSpawns scenes',
      );

      if (_lastWildernessStateKey == stateKey) return;
      _lastWildernessStateKey = stateKey;

      _showNotification(
        NotificationBanner(
          type: NotificationBannerType.wildernessSpawn,
          title: 'SPECIMENS DETECTED',
          subtitle:
              'Wild specimens available in $scenesWithSpawns location${scenesWithSpawns > 1 ? 's' : ''}',
          count: totalSpawns,
          stateKey: stateKey,
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => const MapScreen(),
                fullscreenDialog: true,
              ),
            );
          },
        ),
      );
    } else {
      debugPrint('🌲 Clearing wilderness notification (no active spawns)');
      _lastWildernessStateKey = null;
      _clearNotification(NotificationBannerType.wildernessSpawn);
    }
  }

  Future<List<String>> _visibleWildernessBiomes() async {
    final db = context.read<AlchemonsDatabase>();
    final arcaneUnlocked =
        await db.settingsDao.getSetting('arcane_portal_unlocked') == '1';
    if (mounted && _arcanePortalUnlocked != arcaneUnlocked) {
      setState(() => _arcanePortalUnlocked = arcaneUnlocked);
    }
    return [..._coreWildernessBiomes, if (arcaneUnlocked) 'arcane'];
  }

  // Eggs: keep per-egg schedules current and emit summary push only when
  // new slots become ready.
  Future<void> _checkEggNotifications(List<IncubatorSlot> slots) async {
    if (!mounted) return;
    final enabled = await NotificationPreferencesService()
        .isCultivationsEnabled();
    if (!enabled) {
      _lastEggStateKey = null;
      _lastScheduledEggHatchMsBySlot.clear();
      _lastReadyEggSlotIds.clear();
      await _pushNotifications.cancelEggNotification();
      await _pushNotifications.cancelEggReadySummaryNotification();
      _clearNotification(NotificationBannerType.eggReady);
      return;
    }

    int readyEggs = 0;
    final nowUtc = DateTime.now().toUtc();
    final List<Future> scheduleTasks = [];
    final List<int> slotsToCancel = [];
    final List<int> readySlotIds = [];
    final Set<int> activeSlotIds = <int>{};

    for (final slot in slots) {
      if (slot.unlocked && slot.eggId != null && slot.hatchAtUtcMs != null) {
        activeSlotIds.add(slot.id);
        final hatchUtc = DateTime.fromMillisecondsSinceEpoch(
          slot.hatchAtUtcMs!,
          isUtc: true,
        );

        if (!hatchUtc.isAfter(nowUtc)) {
          readyEggs++;
          readySlotIds.add(slot.id);
          // Cancel per-slot scheduled notification (it would be in the past now)
          slotsToCancel.add(slot.id);
          _lastScheduledEggHatchMsBySlot.remove(slot.id);
        } else {
          // Schedule only when this slot's hatch timestamp actually changed.
          final lastScheduledMs = _lastScheduledEggHatchMsBySlot[slot.id];
          final hatchMs = slot.hatchAtUtcMs!;
          if (lastScheduledMs != hatchMs) {
            scheduleTasks.add(
              _pushNotifications.scheduleEggHatchingNotification(
                hatchTime: hatchUtc.toLocal(),
                eggId: slot.eggId!,
                slotIndex: slot.id,
              ),
            );
            _lastScheduledEggHatchMsBySlot[slot.id] = hatchMs;
          }
        }
      } else {
        // Slot is empty/invalid -> ensure any stale scheduled notification is cleared.
        slotsToCancel.add(slot.id);
        _lastScheduledEggHatchMsBySlot.remove(slot.id);
      }
    }

    // If slot list changed, clean up removed slot IDs too.
    final staleTrackedSlots = _lastScheduledEggHatchMsBySlot.keys
        .where((slotId) => !activeSlotIds.contains(slotId))
        .toList();
    for (final slotId in staleTrackedSlots) {
      slotsToCancel.add(slotId);
      _lastScheduledEggHatchMsBySlot.remove(slotId);
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
      final readySlotIdSet = readySlotIds.toSet();
      final hasNewReadyEggs = readySlotIdSet.any(
        (slotId) => !_lastReadyEggSlotIds.contains(slotId),
      );
      final hasRemovedReadyEggs = _lastReadyEggSlotIds.any(
        (slotId) => !readySlotIdSet.contains(slotId),
      );
      final stateKey = 'slots:${readySlotIds.join(",")}';

      // De-dupe: if same stateKey as last emission, do nothing.
      if (_lastEggStateKey == stateKey) {
        _lastReadyEggSlotIds = readySlotIdSet;
        return;
      }
      _lastEggStateKey = stateKey;

      // Only send a local push when NEW eggs become ready.
      // Avoid re-alerting while the user extracts from an already-ready set.
      if (hasNewReadyEggs) {
        await _pushNotifications.showEggReadyNotification(count: readyEggs);
      } else if (hasRemovedReadyEggs) {
        // Ready count decreased (e.g., extraction). Clear stale summary instead
        // of re-alerting with a new count.
        await _pushNotifications.cancelEggReadySummaryNotification();
      }

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
      _lastReadyEggSlotIds = readySlotIdSet;
    } else {
      _lastEggStateKey = null; // reset de-dupe
      _lastReadyEggSlotIds.clear();
      await _pushNotifications.cancelEggReadySummaryNotification();
      _clearNotification(NotificationBannerType.eggReady);
    }
  }

  Future<void> _checkBiomeNotifications(List<BiomeFarm> biomes) async {
    if (!mounted) return;
    final enabled = await NotificationPreferencesService()
        .isExtractionsEnabled();
    if (!enabled) {
      _lastHarvestStateKey = null;
      await _pushNotifications.cancelHarvestNotification();
      _clearNotification(NotificationBannerType.harvestReady);
      return;
    }

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (!mounted) return;
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

    for (final existing in _activeNotifications) {
      if (existing.type == banner.type &&
          existing.stateKey == banner.stateKey) {
        return;
      }
    }

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

  /// Pre-loads the featured creature's sprite sheet into Flame's image cache
  /// so that [CreatureSprite] can display it synchronously (no loading flash).
  Future<void> _prewarmFeaturedSprite(
    CreatureInstance inst,
    CreatureCatalog repo,
  ) async {
    try {
      final base = repo.getCreatureById(inst.baseId);
      if (base?.spriteData == null) return;
      final sheet = sheetFromCreature(base!);
      await Flame.images.load(sheet.path);
    } catch (_) {}
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
    if (!mounted) return;
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
    if (!mounted) return;
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
    await _prewarmFeaturedSprite(pickedInstance, repo);
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

    if (!mounted) return;
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

            return AnimatedBuilder(
              animation: _shakeController,
              builder: (ctx, child) {
                final t = _shakeController.value;
                final damp = (1.0 - t);
                final dx = sin(t * pi * 12) * 18.0 * damp;
                final dy = cos(t * pi * 10) * 8.0 * damp;
                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: child,
                );
              },
              child: Stack(
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
                        final visibleBiomes = [
                          ..._coreWildernessBiomes,
                          if (_arcanePortalUnlocked) 'arcane',
                        ];
                        final hasSpawns = visibleBiomes.any(
                          (biomeId) =>
                              spawnService.getSceneSpawnCount(biomeId) > 0,
                        );
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
                                        color: Colors.red.withValues(
                                          alpha: 0.6,
                                        ),
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
                        lockNonField: _isFieldTutorialActive,
                        showHarvestDot:
                            !_isFieldTutorialActive &&
                            context.select<HarvestService, bool>(
                              (s) => s.biomes.any(
                                (f) => f.unlocked && f.completed,
                              ),
                            ),
                        highlightField: _isFieldTutorialActive,
                        onField: () {
                          if (_isFieldTutorialActive) {
                            _handleFieldTutorialTap();
                          } else {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => const MapScreen(),
                                fullscreenDialog: true,
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
                                    builder: (_) =>
                                        const CompetitionHubScreen(),
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
                                  CupertinoPageRoute(
                                    builder: (_) => const GameModeScreen(),
                                    fullscreenDialog: true,
                                  ),
                                );
                              },
                        onBoss: _isFieldTutorialActive
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
                        onMysticAltar: null,
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _AnimatedCosmicOrb(onPulse: _playHomeShake),
                                const SizedBox(height: 10),
                                ConstellationPointsWidget(),
                                if (context
                                        .watch<BossProgressNotifier>()
                                        .totalBossesDefeated >
                                    0) ...[
                                  const SizedBox(height: 10),
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.heavyImpact();
                                      VoidPortal.push(
                                        context,
                                        page: const MysticAltarScreen(),
                                      );
                                    },
                                    child: Image.asset(
                                      'assets/images/ui/relicicon.png',
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Daily Treasure Chest — bottom center above nav bar
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 90),
                      child: Opacity(
                        opacity: _isFieldTutorialActive ? 0.35 : 1.0,
                        child: IgnorePointer(
                          ignoring: _isFieldTutorialActive,
                          child: _DailyTreasureChest(),
                        ),
                      ),
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
              ),
            );
          },
    );
  }

  Widget _buildHomeContent(FactionTheme theme) {
    return const SizedBox.shrink();
  }

  void _playHomeShake() {
    try {
      _shakeController.forward(from: 0.0);
    } catch (_) {}
  }

  /// One-time migration: grant trait keys for bosses already beaten before
  /// the Mystic Altar feature was introduced.
  Future<void> _seedMissingBossTraitKeys() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final bossProgress = context.read<BossProgressNotifier>();

    // Wait for SharedPreferences to finish loading into the notifier
    if (!bossProgress.isLoaded) {
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return !bossProgress.isLoaded;
      });
    }

    if (!mounted) return;

    for (final boss in BossRepository.allBosses) {
      if (!bossProgress.isBossDefeated(boss.id)) continue;
      final traitKey = BossLootKeys.traitKeyForElement(boss.element);
      final qty = await db.inventoryDao.getItemQty(traitKey);
      if (qty == 0) {
        await db.inventoryDao.addItemQty(traitKey, 1);
        debugPrint('🔑 Seeded missing trait key: $traitKey (${boss.name})');
      }
    }
  }

  Future<void> _grantStarterIfNeeded(
    FactionId faction,
    WildernessSpawnService spawnService,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final starterService = context.read<StarterGrantService>();

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
      // 🔑 Set extraction pending IMMEDIATELY after grant (before any UI)
      // This ensures restart will know to redirect to extraction
      await db.settingsDao.setSetting('tutorial_extraction_pending', '1');
      await db.settingsDao.setNavLocked(true);

      await spawnService.clearSceneSpawns('valley');
      await spawnService.scheduleNextSpawnTime(
        'valley',
        windowMax: Duration(seconds: 10),
        force: true,
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
                child: Opacity(
                  opacity: _isFieldTutorialActive ? 0.35 : 1.0,
                  child: IgnorePointer(
                    ignoring: _isFieldTutorialActive,
                    child: ResourceCollectionWidget(theme: theme),
                  ),
                ),
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
            Opacity(
              opacity: _isFieldTutorialActive ? 0.35 : 1.0,
              child: IgnorePointer(
                ignoring: _isFieldTutorialActive,
                child: CurrencyDisplayWidget(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily Treasure Chest
// ─────────────────────────────────────────────────────────────────────────────

class _DailyTreasureChest extends StatefulWidget {
  const _DailyTreasureChest();

  @override
  State<_DailyTreasureChest> createState() => _DailyTreasureChestState();
}

class _DailyTreasureChestState extends State<_DailyTreasureChest>
    with TickerProviderStateMixin {
  late final AnimationController _lottieCtrl;
  bool _isClaimed = false;
  bool _isPlaying = false;
  bool _ready = false; // true once lottie loaded

  static const _settingKey = 'daily_loot_key';

  String get _todayKey =>
      DateTime.now().toUtc().toIso8601String().split('T').first;

  @override
  void initState() {
    super.initState();
    _lottieCtrl = AnimationController(vsync: this);
    _checkClaimed();
  }

  Future<void> _checkClaimed() async {
    final db = context.read<AlchemonsDatabase>();
    final saved = await db.settingsDao.getSetting(_settingKey);
    if (!mounted) return;
    setState(() {
      _isClaimed = saved == _todayKey;
    });
  }

  @override
  void dispose() {
    _lottieCtrl.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_isClaimed || _isPlaying || !_ready) return;
    setState(() => _isPlaying = true);

    // Start lottie — show loot after 1.5 s without waiting for it to finish
    _lottieCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Grant rewards
    final rng = Random();
    final db = context.read<AlchemonsDatabase>();
    final silver = 150 + rng.nextInt(351); // 150–500
    final int gold = rng.nextDouble() < 0.15 ? 1 : 0;
    final bool givesVial = rng.nextDouble() < 0.25;

    await db.currencyDao.addSilver(silver);
    if (gold > 0) await db.currencyDao.addGold(gold);
    if (givesVial) {
      try {
        final groups = ElementalGroup.values;
        final group = groups[rng.nextInt(groups.length)];
        await db.inventoryDao.addVial('Daily Vial', group, VialRarity.common);
      } catch (_) {}
    }

    // Persist claim
    await db.settingsDao.setSetting(_settingKey, _todayKey);
    if (!mounted) return;
    setState(() {
      _isClaimed = true;
      _isPlaying = false;
    });

    // Build loot rewards
    final rewards = [
      _TreasureReward(
        icon: Icons.monetization_on_rounded,
        amount: '+$silver',
        name: 'SILVER',
        color: const Color(0xFFB0BEC5),
      ),
      if (gold > 0)
        _TreasureReward(
          icon: Icons.stars_rounded,
          amount: '+$gold',
          name: 'GOLD',
          color: const Color(0xFFFFD700),
        ),
      if (givesVial)
        _TreasureReward(
          icon: Icons.science_rounded,
          amount: '×1',
          name: 'COMMON VIAL',
          color: const Color(0xFF4CAF50),
        ),
    ];

    if (!mounted) return;
    await _showTreasureLootDialog(context, rewards);
  }

  @override
  Widget build(BuildContext context) {
    if (_isClaimed) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow ring when unclaimed
          if (!_isClaimed)
            Container(
              width: 81,
              height: 81,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFAA00).withValues(alpha: 0.22),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          Opacity(
            opacity: 1.0,
            child: SizedBox(
              width: 160,
              height: 160,
              child: Lottie.asset(
                'assets/animations/treasure_lottie.json',
                controller: _lottieCtrl,
                fit: BoxFit.contain,
                repeat: false,
                onLoaded: (comp) {
                  if (!mounted) return;
                  _lottieCtrl.duration = comp.duration;
                  _lottieCtrl.value = 0;
                  setState(() => _ready = true);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Treasure Loot Dialog — sleek animated reward reveal
// ─────────────────────────────────────────────────────────────────────────────

class _TreasureReward {
  final IconData icon;
  final String amount;
  final String name;
  final Color color;

  const _TreasureReward({
    required this.icon,
    required this.amount,
    required this.name,
    required this.color,
  });
}

Future<void> _showTreasureLootDialog(
  BuildContext context,
  List<_TreasureReward> rewards,
) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.80),
    transitionDuration: const Duration(milliseconds: 350),
    transitionBuilder: (ctx, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
    pageBuilder: (ctx, _, __) => _TreasureLootDialog(rewards: rewards),
  );
}

class _TreasureLootDialog extends StatefulWidget {
  final List<_TreasureReward> rewards;
  const _TreasureLootDialog({required this.rewards});

  @override
  State<_TreasureLootDialog> createState() => _TreasureLootDialogState();
}

class _TreasureLootDialogState extends State<_TreasureLootDialog>
    with TickerProviderStateMixin {
  late final List<AnimationController> _rowCtrls;
  late final List<Animation<double>> _rowFade;
  late final List<Animation<Offset>> _rowSlide;
  late final AnimationController _btnCtrl;
  late final Animation<double> _btnFade;

  @override
  void initState() {
    super.initState();

    _rowCtrls = List.generate(
      widget.rewards.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 480),
      ),
    );
    _rowFade = _rowCtrls
        .map(
          (c) => CurvedAnimation(
            parent: c,
            curve: Curves.easeOut,
          ).drive(Tween(begin: 0.0, end: 1.0)),
        )
        .toList();
    _rowSlide = _rowCtrls
        .map(
          (c) => CurvedAnimation(
            parent: c,
            curve: Curves.easeOutCubic,
          ).drive(Tween(begin: const Offset(0, 0.25), end: Offset.zero)),
        )
        .toList();

    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _btnFade = CurvedAnimation(
      parent: _btnCtrl,
      curve: Curves.easeIn,
    ).drive(Tween(begin: 0.0, end: 1.0));

    // Stagger rows then button
    for (int i = 0; i < _rowCtrls.length; i++) {
      Future.delayed(Duration(milliseconds: 300 + i * 240), () {
        if (mounted) _rowCtrls[i].forward();
      });
    }
    final btnDelay = 300 + widget.rewards.length * 240 + 180;
    Future.delayed(Duration(milliseconds: btnDelay), () {
      if (mounted) _btnCtrl.forward();
    });
  }

  @override
  void dispose() {
    for (final c in _rowCtrls) {
      c.dispose();
    }
    _btnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFFAA00);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'DAILY REWARDS',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: amber,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5.0,
                ),
              ),
              const SizedBox(height: 8),
              Container(height: 1, color: amber.withValues(alpha: 0.25)),
              const SizedBox(height: 36),

              // Reward rows
              ...List.generate(widget.rewards.length, (i) {
                final r = widget.rewards[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: FadeTransition(
                    opacity: _rowFade[i],
                    child: SlideTransition(
                      position: _rowSlide[i],
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: r.color.withValues(alpha: 0.12),
                              border: Border.all(
                                color: r.color.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Icon(r.icon, color: r.color, size: 22),
                          ),
                          const SizedBox(width: 18),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.amount,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: r.color,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                r.name,
                                style: const TextStyle(
                                  color: Color(0xFF7A7A8A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 8),

              // Collect button
              FadeTransition(
                opacity: _btnFade,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: amber, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: amber.withValues(alpha: 0.22),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'COLLECT',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFFFFCC44),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0,
                        ),
                      ),
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
}
