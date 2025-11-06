// lib/screens/home_screen.dart

import 'dart:async' as async;

import 'package:alchemons/models/encounters/pools/valley_pool.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:alchemons/screens/competition_hub_screen.dart';
import 'package:alchemons/screens/game_screen.dart';
import 'package:alchemons/screens/inventory_screen.dart';
import 'package:alchemons/screens/map_screen.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/utils/creature_instance_uti.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/widgets/avatar_widget.dart';
import 'package:alchemons/widgets/blob_party/overlays/floating_bubble_overlay.dart';
import 'package:alchemons/widgets/creature_showcase_widget.dart';
import 'package:alchemons/widgets/currency_display_widget.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:alchemons/widgets/notification_banner_system.dart';
import 'package:alchemons/widgets/side_dock_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/screens/creatures_screen.dart';
import 'package:alchemons/screens/faction_picker.dart';
import 'package:alchemons/screens/feeding_screen.dart';
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
import '../providers/app_providers.dart';
import 'breed/breed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

const double _kNavHeight = 92;
const double _kNavReserve = _kNavHeight + 12;

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _rotationController;
  late AnimationController _particleController;
  late AnimationController _waveController;
  late AnimationController _glowController;
  late AnimationController _navAnimController;

  bool _isInitialized = false;
  NavSection _currentSection = NavSection.home;
  int? _pendingBreedInitialTab;

  // Notification banners
  final List<NotificationBanner> _activeNotifications = [];

  // Stream subscriptions for reactive notifications
  async.StreamSubscription<List<IncubatorSlot>>? _slotsSubscription;
  async.StreamSubscription<List<BiomeFarm>>? _biomesSubscription;
  async.Timer? _notificationCheckTimer;

  // FEATURED HERO STATE
  PresentationData? _featuredData;
  String? _featuredInstanceId;
  async.Timer? _spawnTimer;

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
    _navAnimController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeApp();
    });
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    _waveController.dispose();
    _glowController.dispose();
    _navAnimController.dispose();
    _slotsSubscription?.cancel();
    _biomesSubscription?.cancel();
    _notificationCheckTimer?.cancel();
    _spawnTimer?.cancel();
    super.dispose();
  }

  void _goToSection(NavSection section, {int? breedInitialTab}) {
    debugPrint(
      '📱 Navigating to: $section (active notifications: ${_activeNotifications.length})',
    );
    setState(() {
      _currentSection = section;
      if (section == NavSection.breed) {
        _pendingBreedInitialTab = breedInitialTab;
      }
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _initializeApp() async {
    try {
      await _initializeRepository();
      final factionSvc = context.read<FactionService>();

      await factionSvc.loadId();
      var faction = factionSvc.current;

      if (!mounted) return;

      if (faction == null) {
        final selected = await showDialog<FactionId>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const FactionPickerDialog(),
        );
        if (!mounted || selected == null) return;
        await factionSvc.setId(selected);
        faction = selected;
      }

      await factionSvc.ensureAirExtraSlotUnlocked();
      await _grantStarterIfNeeded(faction);

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

      if (!mounted) return;
      setState(() => _isInitialized = true);

      // Set up reactive notification watchers
      _setupNotificationWatchers();

      final spawnService = context.read<WildernessSpawnService>();

      // ✅ await initialization
      await spawnService.initializeActiveSpawns(
        scenes: {
          'valley': (
            scene: valleyScene,
            pool: valleyEncounterPools(valleyScene).sceneWide,
          ),
          'sky': (
            scene: skyScene,
            pool: valleyEncounterPools(skyScene).sceneWide,
          ),
          'volcano': (
            scene: volcanoScene,
            pool: valleyEncounterPools(volcanoScene).sceneWide,
          ),
          'swamp': (
            scene: swampScene,
            pool: valleyEncounterPools(swampScene).sceneWide,
          ),
        },
      );

      // ✅ fire once right away so overdue spawns appear instantly
      await spawnService.processDueScenes({
        'valley': (
          scene: valleyScene,
          pool: valleyEncounterPools(valleyScene).sceneWide,
        ),
        'sky': (
          scene: skyScene,
          pool: valleyEncounterPools(skyScene).sceneWide,
        ),
        'volcano': (
          scene: volcanoScene,
          pool: valleyEncounterPools(volcanoScene).sceneWide,
        ),
        'swamp': (
          scene: swampScene,
          pool: valleyEncounterPools(swampScene).sceneWide,
        ),
      });

      // 🔁 lightweight periodic check
      _spawnTimer = async.Timer.periodic(const Duration(minutes: 1), (_) async {
        try {
          await spawnService.processDueScenes({
            'valley': (
              scene: valleyScene,
              pool: valleyEncounterPools(valleyScene).sceneWide,
            ),
            'sky': (
              scene: skyScene,
              pool: valleyEncounterPools(skyScene).sceneWide,
            ),
            'volcano': (
              scene: volcanoScene,
              pool: valleyEncounterPools(volcanoScene).sceneWide,
            ),
            'swamp': (
              scene: swampScene,
              pool: valleyEncounterPools(swampScene).sceneWide,
            ),
          });
        } catch (e, st) {
          debugPrint('processDueScenes error: $e\n$st');
        }
      });
    } catch (e, st) {
      debugPrint('Error during app initialization: $e');
      debugPrint('Error during app initialization: $e\n$st'); // <—
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

    // Watch incubator slots for ready eggs
    _slotsSubscription = db.incubatorDao.watchSlots().listen(
      _checkEggNotifications,
    );

    // Watch biomes for harvest opportunities
    _biomesSubscription = db.biomeDao.watchBiomes().listen(
      _checkBiomeNotifications,
    );

    // Set up a timer to check time-based conditions (like eggs becoming ready)
    // This is lighter than full polling - just checks if NOW crosses any thresholds
    _notificationCheckTimer = async.Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkTimeBasedNotifications(),
    );
  }

  void _checkEggNotifications(List<IncubatorSlot> slots) {
    if (!mounted || _currentSection != NavSection.home) return;

    int readyEggs = 0;
    final now = DateTime.now();

    for (final slot in slots) {
      if (slot.unlocked && slot.eggId != null && slot.hatchAtUtcMs != null) {
        final hatchTime = DateTime.fromMillisecondsSinceEpoch(
          slot.hatchAtUtcMs!,
          isUtc: true,
        );
        if (hatchTime.isBefore(now) || hatchTime.isAtSameMomentAs(now)) {
          readyEggs++;
        }
      }
    }

    debugPrint('🥚 Egg notification check: $readyEggs eggs ready');

    if (readyEggs > 0) {
      _showNotification(
        NotificationBanner(
          type: NotificationBannerType.eggReady,
          title: 'EGG READY TO HATCH',
          subtitle: 'Tap to view incubator',
          count: readyEggs,
          onTap: () {
            _goToSection(NavSection.breed, breedInitialTab: 1);
          },
        ),
      );
    } else {
      debugPrint('🥚 Clearing egg notification (no eggs ready)');
      // Clear notification if no eggs are ready
      _clearNotification(NotificationBannerType.eggReady);
    }
  }

  void _checkBiomeNotifications(List<BiomeFarm> biomes) {
    if (!mounted || _currentSection != NavSection.home) return;

    // Example: Check for completed harvest jobs
    // You'll need to expand this based on your actual BiomeJob tracking

    // For now, this is a placeholder
    // In a full implementation, you'd watch BiomeJobs and check completion
  }

  void _checkTimeBasedNotifications() {
    if (!mounted || _currentSection != NavSection.home) return;

    // This is called periodically to catch eggs that just became ready
    // The stream won't fire unless the slot data changes, but eggs become
    // ready based on time, so we need this lightweight check

    final db = context.read<AlchemonsDatabase>();
    db.incubatorDao.watchSlots().first.then(_checkEggNotifications);
  }

  void _showNotification(NotificationBanner banner) {
    if (!mounted) return;
    setState(() {
      // Remove duplicates of same type
      _activeNotifications.removeWhere((n) => n.type == banner.type);
      _activeNotifications.add(banner);
      debugPrint('📢 Showing notification: ${banner.type} (${banner.title})');
    });
  }

  void _clearNotification(NotificationBannerType type) async {
    if (!mounted) return;

    // Clear from database if it was dismissed
    try {
      final db = context.read<AlchemonsDatabase>();
      await (db.delete(
        db.notificationDismissals,
      )..where((t) => t.notificationType.equals(type.toKey()))).go();
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
      case FactionId.fire:
        return (particle: .1, rotation: 0.1, elemental: .3);
      case FactionId.water:
        return (particle: 1, rotation: 0.1, elemental: .5);
      case FactionId.air:
        return (particle: 1, rotation: 0.1, elemental: 1);
      case FactionId.earth:
        return (particle: 1, rotation: 0.1, elemental: 0.2);
    }
  }

  void _navigateToSection(NavSection section) {
    _goToSection(section);
    // Notifications persist across navigation - they're only cleared when:
    // 1. User manually dismisses them
    // 2. The underlying condition resolves (e.g., egg is hatched)
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
        return InstancesSheet(
          theme: theme,
          species: species,
          onTap: (CreatureInstance ci) {
            Navigator.pop(context, ci);
          },
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
            final currentFaction = factionSvc.current ?? FactionId.water;
            final speeds = _speedFor(currentFaction);

            return Scaffold(
              extendBody: true,
              body: Stack(
                children: [
                  // Background
                  InteractiveBackground(
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

                  // Main content
                  SafeArea(
                    top: _currentSection == NavSection.home,
                    bottom: false,
                    child: Column(
                      children: [
                        if (_currentSection == NavSection.home)
                          _buildHeader(theme),

                        if (_featuredData != null &&
                            _currentSection == NavSection.home) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 260,
                            child: Center(
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
                        ],

                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            child: _buildSectionContent(
                              theme,
                              key: ValueKey(_currentSection),
                            ),
                          ),
                        ),

                        BottomNav(
                          current: _currentSection,
                          onSelect: (s) => _navigateToSection(s),
                          theme: theme,
                        ),
                      ],
                    ),
                  ),

                  if (_currentSection == NavSection.home)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 140,
                      left: 0,
                      child: Consumer<WildernessSpawnService>(
                        builder: (context, spawnService, child) {
                          final hasSpawns = spawnService.hasAnyActiveSpawns;

                          return Stack(
                            children: [
                              child!, // The actual map button
                              if (hasSpawns)
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    width: 15,
                                    height: 15,
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
                        // 👇 Everything below should be INSIDE SideDockFloating
                        child: SideDockFloating(
                          theme: theme,
                          onField: () {
                            final spawnService = context
                                .read<WildernessSpawnService>();
                            final hasSpawns = spawnService.hasAnyActiveSpawns;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MapScreen(),
                              ),
                            );
                          },
                          onEnhance: () {
                            HapticFeedback.mediumImpact();
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => const FeedingScreen(),
                                fullscreenDialog: true,
                              ),
                            );
                          },
                          onHarvest: () {
                            HapticFeedback.mediumImpact();
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => const BiomeHarvestScreen(),
                                fullscreenDialog: true,
                              ),
                            );
                          },
                          onCompetitions: () {
                            HapticFeedback.mediumImpact();
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => const CompetitionHubScreen(),
                                fullscreenDialog: true,
                              ),
                            );
                          },
                          onBattle: () {
                            HapticFeedback.mediumImpact();
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => const GameScreen(),
                                fullscreenDialog: true,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  if (_currentSection == NavSection.home)
                    FloatingBubblesOverlay(
                      regionPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                      discoveredCreatures:
                          discovered, // <-- typed CreatureEntry list
                      theme: theme,
                    ),

                  if (_currentSection == NavSection.home &&
                      _activeNotifications.isNotEmpty)
                    NotificationBannerStack(
                      notifications: _activeNotifications,
                    ),
                ],
              ),
            );
          },
    );
  }

  Widget _buildSectionContent(FactionTheme theme, {Key? key}) {
    switch (_currentSection) {
      case NavSection.home:
        return _buildHomeContent(theme);
      case NavSection.creatures:
        return const CreaturesScreen();
      case NavSection.shop:
        return const ShopScreen();
      case NavSection.breed:
        return const BreedScreen();
      case NavSection.enhance:
        return const FeedingScreen();
      case NavSection.inventory:
        return InventoryScreen(accent: theme.surface);
    }
  }

  Widget _buildHomeContent(FactionTheme theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: const Column(
        children: [SizedBox(height: 16), SizedBox(height: 80)],
      ),
    );
  }

  Future<void> _grantStarterIfNeeded(FactionId faction) async {
    final db = context.read<AlchemonsDatabase>();
    final starterService = context.read<StarterGrantService>(); // Add this
    final theme = context.read<FactionTheme>();

    // Ensure at least one slot is unlocked
    final slots = await db.incubatorDao.watchSlots().first;
    final anyUnlocked = slots.any((s) => s.unlocked);
    if (!anyUnlocked) {
      await db.incubatorDao.unlockSlot(0);
    }

    final granted = await starterService.ensureStarterGranted(
      faction,
      tutorialHatch: const Duration(seconds: 20),
    );

    if (!mounted) return;

    if (granted) {
      // Show dialog instead of SnackBar, then go to Breed
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Text(
            'Starter secured',
            style: TextStyle(color: theme.text, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Your starter Alchemon has been placed in the Extraction Chamber.',
            style: TextStyle(fontSize: 16, color: theme.text),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      // Navigate to Breed screen (optionally with incubator tab preselected)
      _goToSection(NavSection.breed, breedInitialTab: 1);
    }
  }

  Widget _buildHeader(FactionTheme theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AvatarButton(
              theme: theme,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
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
            Text(
              'ALCHEMONS',
              style: GoogleFonts.cinzelDecorative(
                color: theme.text,
                fontWeight: FontWeight.w800,
                fontSize: 40,
                letterSpacing: 1,
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
