import 'dart:async';
import 'dart:ui';

import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/pools/sky_pool.dart';
import 'package:alchemons/models/encounters/pools/swamp_pool.dart';
import 'package:alchemons/models/encounters/pools/volcano_pool.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/faction_picker.dart';
import 'package:alchemons/screens/story/story_intro_screen.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'database/alchemons_db.dart';
import 'database/db_helper.dart';
import 'services/game_data_service.dart';
import 'providers/app_providers.dart';
import 'screens/home_screen.dart';

// >>> add these imports for scenes & pools
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/encounters/pools/valley_pool.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    print('Caught error: $error');
    print(stack);
    return true; // prevent silent crash
  };

  final db = constructDb();

  final catalog = CreatureCatalog();
  await catalog.load();

  final gameData = GameDataService(db: db, catalog: catalog);
  await gameData.init();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(AlchemonsApp(db: db, gameDataService: gameData));
}

class AlchemonsApp extends StatelessWidget {
  final AlchemonsDatabase db;
  final GameDataService gameDataService;

  const AlchemonsApp({
    super.key,
    required this.db,
    required this.gameDataService,
  });

  @override
  Widget build(BuildContext context) {
    return AppProviders(
      db: db,
      gameDataService: gameDataService,
      child: Builder(
        builder: (context) {
          final themeNotifier = context.watch<ThemeNotifier>();
          final factionSvc = context.watch<FactionService>();
          final factionId = factionSvc.current;

          final lightFactionTheme = factionThemeFor(
            factionId,
            brightness: Brightness.light,
          );
          final darkFactionTheme = factionThemeFor(
            factionId,
            brightness: Brightness.dark,
          );

          final textThemeFn = themeNotifier.currentTextThemeFn;
          // Apply it
          final textTheme = textThemeFn(Theme.of(context).textTheme);

          final lightThemeData = lightFactionTheme.toMaterialTheme(textTheme);
          final darkThemeData = darkFactionTheme.toMaterialTheme(textTheme);

          return MaterialApp(
            title: 'Alchemons',
            themeMode: themeNotifier.themeMode,
            theme: lightThemeData,
            darkTheme: darkThemeData,
            navigatorObservers: [routeObserver],
            // >>> wrap HomeScreen so we can bootstrap spawns once
            home: const AppGate(child: MainShell()),
          );
        },
      ),
    );
  }
}

class AppGate extends StatefulWidget {
  final Widget child;
  const AppGate({super.key, required this.child});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  StreamSubscription<bool>? _sub;
  bool _navigating = false;

  // >>> guard so we only initialize spawns once
  bool _spawnsStarted = false;
  bool _assetsLoaded = false;

  bool _readyToShowShell = false;

  @override
  void initState() {
    super.initState();
    final db = context.read<AlchemonsDatabase>();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // 1) Precache assets
      await _precacheAssets();

      // 2) Start spawns
      await _ensureSpawnsStarted();

      // 3) Run first-launch story BEFORE we ever show the shell
      await _runFirstLaunchFlow();

      // 4) Existing "must pick faction" watcher / bootstrap
      final mustPick = await db.settingsDao.getMustPickFaction();
      if (mustPick) _openPicker();

      if (!mounted) return;
      await context.read<ConstellationService>().calculateRetroactivePoints();
      setState(() {
        _readyToShowShell = true;
      });
    });

    // Still listen for future "must pick faction" changes
    _sub = db.settingsDao.watchMustPickFaction().listen((mustPick) {
      if (!mounted || !mustPick) return;
      _openPicker();
    });
  }

  Future<void> _runFirstLaunchFlow() async {
    final factionSvc = context.read<FactionService>();

    // Make sure faction is loaded
    await factionSvc.loadId();
    if (!mounted) return;

    // If we already have a faction, it's not first launch; nothing to do
    if (factionSvc.current != null) {
      return;
    }

    // 1) Show story intro as full-screen route
    final completed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const StoryIntroScreen(),
      ),
    );

    if (!mounted || completed != true) {
      // User bailed somehow; don't proceed to shell setup yet
      return;
    }

    // 2) Immediately show faction picker (same as before, just moved up here)
    final selected = await showDialog<FactionId>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FactionPickerDialog(),
    );

    if (!mounted || selected == null) {
      return;
    }

    await factionSvc.setId(selected);
  }

  /// ============================================================
  /// ASSET PRECACHING - Runs once per app launch
  /// ============================================================
  Future<void> _precacheAssets() async {
    if (_assetsLoaded) return;
    _assetsLoaded = true;

    final startTime = DateTime.now();
    debugPrint('🎨 Starting asset precaching...');

    try {
      // Step 1: Precache UI assets (navbar, icons, etc.)
      await _precacheUIAssets();

      // Step 2: Precache creature sprites (discovered/owned only)
      await _precacheCreatureSprites();

      final duration = DateTime.now().difference(startTime);
      debugPrint('✅ Asset precaching complete in ${duration.inMilliseconds}ms');
    } catch (e) {
      debugPrint('⚠️  Error during asset precaching: $e');
      // Don't block app launch on precache failures
    }
  }

  Future<void> _precacheUIAssets() async {
    if (!mounted) return;

    const uiPaths = <String>[
      // Bottom nav
      'assets/images/ui/inventorylight.png',
      'assets/images/ui/inventorydark.png',
      'assets/images/ui/dexicon_light.png',
      'assets/images/ui/dexicon.png',
      'assets/images/ui/homeicon2.png',
      'assets/images/ui/breedicon.png',
      'assets/images/ui/shopicon2.png',
      'assets/images/ui/trialsicon.png',
      'assets/images/ui/map.png',

      // Header/avatar + quick actions
      'assets/images/ui/profileicon.png',
      'assets/images/ui/enhanceicon.png',
      'assets/images/ui/fieldicon.png',
      'assets/images/ui/competeicon.png',

      // Title images (both light/dark variants)
      'assets/images/ui/alchemonstitle.png',
      'assets/images/ui/alchemonstitledark.png',
    ];

    // Precache at multiple sizes for different UI states
    const sizes = [
      Size(55, 55), // Inactive navbar icons
      Size(120, 120), // Expanded navbar icons
    ];

    int cached = 0;
    for (final path in uiPaths) {
      for (final size in sizes) {
        try {
          await precacheImage(AssetImage(path), context, size: size);
          cached++;
        } catch (e) {
          debugPrint('Failed to precache $path at $size: $e');
        }
      }
    }

    debugPrint('🎨 Precached $cached UI assets');
  }

  Future<void> _precacheCreatureSprites() async {
    if (!mounted) return;

    try {
      final catalog = context.read<CreatureCatalog>();
      final db = context.read<AlchemonsDatabase>();

      // Get user's creature instances (guaranteed to be viewed)
      final instances = await db.creatureDao.listAllInstances();
      final ownedIds = instances.map((i) => i.baseId).toSet();

      // Get discovered creatures (likely to be viewed)
      final playerCreatures = await db.creatureDao.getAllCreatures();
      final discoveredIds = playerCreatures
          .where((p) => p.discovered)
          .map((p) => p.id)
          .toSet();

      // Combine: owned first (highest priority), then discovered
      final priorityIds = <String>[
        ...ownedIds,
        ...discoveredIds.where((id) => !ownedIds.contains(id)),
      ];

      // Limit to first 20-30 creatures to keep loading reasonable
      const maxPrecache = 25;
      final toPrecache = priorityIds.take(maxPrecache);

      int cached = 0;
      for (final id in toPrecache) {
        if (!mounted) break;

        final creature = catalog.getCreatureById(id);
        if (creature?.spriteData == null) continue;

        try {
          await precacheImage(
            AssetImage(creature!.spriteData!.spriteSheetPath),
            context,
          );
          cached++;
        } catch (e) {
          debugPrint('Failed to precache sprite for $id: $e');
        }
      }

      debugPrint(
        '🐉 Precached $cached creature sprites (${ownedIds.length} owned, ${discoveredIds.length} discovered)',
      );
    } catch (e) {
      debugPrint('Error precaching creature sprites: $e');
    }
  }

  // >>> spawn bootstrap
  Future<void> _ensureSpawnsStarted() async {
    if (_spawnsStarted) return;
    _spawnsStarted = true;

    // Pull the service and build the scenes/pools map exactly once
    final spawnService = context.read<WildernessSpawnService>();

    final scenes =
        <
          String,
          ({
            SceneDefinition scene,
            EncounterPool sceneWide,
            Map<String, EncounterPool> perSpawn,
          })
        >{
          'valley': (
            scene: valleySceneCorrected,
            sceneWide: valleyEncounterPools(valleySceneCorrected).sceneWide,
            perSpawn: valleyEncounterPools(valleySceneCorrected).perSpawn,
          ),
          'sky': (
            scene: skyScene,
            sceneWide: skyEncounterPools(skyScene).sceneWide,
            perSpawn: skyEncounterPools(skyScene).perSpawn,
          ),
          'volcano': (
            scene: volcanoScene,
            sceneWide: volcanoEncounterPools(volcanoScene).sceneWide,
            perSpawn: volcanoEncounterPools(volcanoScene).perSpawn,
          ),
          'swamp': (
            scene: swampScene,
            sceneWide: swampEncounterPools(swampScene).sceneWide,
            perSpawn: swampEncounterPools(swampScene).perSpawn,
          ),
        };

    // (Optional) For dev: make first spawn "sooner"
    // spawnService.setGlobalSpawnWindow(Duration.zero, const Duration(seconds: 2));

    // Initialize from DB (loads active spawns & schedules; creates schedules if missing)
    await spawnService.initializeActiveSpawns(scenes: scenes);

    // (Optional) Fire once so any overdue scenes materialize immediately
    await spawnService.processDueScenes(scenes);

    // Start the background tick owned by the service (default: 10s)
    spawnService.startTick(
      interval: const Duration(seconds: 10),
      scenes: scenes,
    );
  }

  Future<void> _openPicker() async {
    if (_navigating) return; // prevent stacking
    _navigating = true;
    try {
      await Navigator.of(context).push(
        CupertinoPageRoute(
          fullscreenDialog: true,
          builder: (_) => const FactionPickerDialog(),
        ),
      );
    } finally {
      _navigating = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_readyToShowShell) {
      // You can make this a nice splash / logo if you want.
      return const Scaffold(backgroundColor: Colors.black);
    }

    return widget.child;
  }
}
