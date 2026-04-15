import 'dart:async';
import 'dart:ui';

import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/pools/sky_pool.dart';
import 'package:alchemons/models/encounters/pools/swamp_pool.dart';
import 'package:alchemons/models/encounters/pools/arcane_pool.dart';
import 'package:alchemons/models/encounters/pools/volcano_pool.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/faction_picker.dart';
import 'package:alchemons/screens/story/story_intro_screen.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/account_cloud_save_service.dart';
import 'package:alchemons/services/account_session_service.dart';
import 'package:alchemons/services/save_restore_reload_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/save_transfer_service.dart';
import 'package:alchemons/utils/app_scaffold_messenger.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/alchemons_db.dart';
import 'database/db_helper.dart';
import 'firebase_options.dart';
import 'services/game_data_service.dart';
import 'providers/app_providers.dart';
import 'screens/home_screen.dart';
import 'package:alchemons/systems/effects/default_effects.dart';

// >>> add these imports for scenes & pools
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/arcane/arcane_scene.dart';
import 'package:alchemons/models/encounters/pools/valley_pool.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Increase Flutter image cache to reduce sprite eviction when navigating
  // between screens that load many creature assets.
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      150 * 1024 * 1024; // 150 MB

  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Caught error: $error');
    debugPrintStack(stackTrace: stack);
    return true; // prevent silent crash
  };

  final db = constructDb();

  final catalog = CreatureCatalog();
  await catalog.load();

  final gameData = GameDataService(db: db, catalog: catalog);
  await gameData.init();

  // Register built-in effect factories so the registry is available globally.
  registerDefaultEffects();

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
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: rootScaffoldMessengerKey,
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

      // debug helpers removed

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
      await Future.wait(
        toPrecache.map((id) async {
          if (!mounted) return;

          final creature = catalog.getCreatureById(id);
          if (creature?.spriteData == null) return;

          try {
            await precacheImage(
              AssetImage(creature!.spriteData!.spriteSheetPath),
              context,
            );
            cached++;
          } catch (e) {
            debugPrint('Failed to precache sprite for $id: $e');
          }
        }),
      );

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
          'arcane': (
            scene: arcaneScene,
            sceneWide: arcaneEncounterPools(arcaneScene).sceneWide,
            perSpawn: arcaneEncounterPools(arcaneScene).perSpawn,
          ),
        };

    // Initialize from DB (loads active spawns & schedules; creates schedules if missing)
    await spawnService.initializeActiveSpawns(
      scenes: scenes,
      suppressSummaryNotifications: true,
    );

    // debug spawn forcing removed

    // Reset any existing long-wait timers and fire overdue scenes — independent, run in parallel
    await Future.wait([
      spawnService.rescheduleAllScenes(),
      spawnService.processDueScenes(scenes, suppressSummaryNotifications: true),
    ]);

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

class _AccountMovedGate extends StatefulWidget {
  const _AccountMovedGate();

  @override
  State<_AccountMovedGate> createState() => _AccountMovedGateState();
}

class _AccountMovedGateState extends State<_AccountMovedGate> {
  bool _busy = false;

  Future<void> _restoreAccountHere() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restore account here?'),
          content: const Text(
            'This will permanently overwrite the local save on this device with the signed-in account backup. Your current local progress on this device will be lost unless it already exists somewhere else.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final account = context.read<AccountService>();
    final session = context.read<AccountSessionService>();
    final cloudSave = context.read<AccountCloudSaveService>();
    final saveTransfer = SaveTransferService(context.read<AlchemonsDatabase>());

    setState(() => _busy = true);
    try {
      await session.rotateCurrentDeviceId();
      final saveCode = await cloudSave.downloadSaveCode(account.user!.uid);
      await saveTransfer.importSaveCode(
        saveCode,
        ownerAccountId: account.user!.uid,
      );
      if (!mounted) return;
      await reloadStateAfterSaveRestore(context);
      await session.claimCurrentDevice(force: true);
      await session.refresh();
      if (!mounted) return;
      showAppSnack('Account backup restored here. This device is now active.');
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        error.toString(),
        isError: true,
        fallbackContext: context,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reactivateHere() async {
    final session = context.read<AccountSessionService>();
    setState(() => _busy = true);
    try {
      await session.rotateCurrentDeviceId();
      await session.claimCurrentDevice(force: true);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        error.toString(),
        isError: true,
        fallbackContext: context,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startNewGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Start new local game?'),
          content: const Text(
            'This clears local progress on this device and signs out of the transferred account here.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start New Game'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final db = context.read<AlchemonsDatabase>();
    final account = context.read<AccountService>();
    final factionSvc = context.read<FactionService>();
    final navigator = Navigator.of(context);

    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await db.resetToNewGame();
      await account.signOut();

      final completed = await navigator.push<bool>(
        CupertinoPageRoute(
          fullscreenDialog: true,
          builder: (_) => const StoryIntroScreen(),
        ),
      );
      if (!mounted || completed != true) return;

      final selected = await showDialog<FactionId>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const FactionPickerDialog(),
      );
      if (!mounted || selected == null) return;

      await factionSvc.setId(selected);
      showAppSnack('New local game started.');
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        error.toString(),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AccountSessionService>();
    final account = context.watch<AccountService>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ACCOUNT MOVED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This account is currently active on another device. Restore the latest account backup here to move the account, or reclaim this device using its current local save.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Signed in as ${account.email}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 13,
                    ),
                  ),
                  if (session.state.updatedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Last account switch: ${session.state.updatedAt}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'Warning: restoring the account here will permanently replace the current local save on this device.',
                    style: TextStyle(
                      color: Colors.orangeAccent.withValues(alpha: 0.92),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: _busy ? null : _restoreAccountHere,
                        child: Text(_busy ? 'Working...' : 'Restore Account Here'),
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : _reactivateHere,
                        child: const Text('Reactivate Here'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _startNewGame,
                        child: const Text('Start New Game'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
