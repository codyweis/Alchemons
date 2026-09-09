import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/audio/scene_ambience.dart';
import 'package:alchemons/audio/navigation_sounds.dart';
import 'dart:async';
import 'package:alchemons/widgets/progress_reset_host.dart';
import 'package:alchemons/services/progress_reset_service.dart';
import 'package:alchemons/services/mobile_store_service.dart';
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
import 'package:alchemons/screens/onboarding/first_launch_account_flow.dart';
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
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'database/alchemons_db.dart';
import 'database/db_helper.dart';
import 'firebase_options.dart';
import 'services/game_data_service.dart';
import 'providers/app_providers.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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

  // Hydrate the developer-tools switch BEFORE the first frame, so every
  // debug affordance reads the persisted value from frame one. Screens used
  // to hydrate it themselves on mount, which meant whichever screen you
  // landed on decided whether the tools were there yet.
  await DebugSettingsService().isEnabled();

  final db = constructDb();

  final catalog = CreatureCatalog();
  await catalog.load();

  // Register built-in effect factories so the registry is available globally.
  registerDefaultEffects();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(
    ProgressResetHost(
      db: db,
      buildGame: () async {
        final gameData = GameDataService(db: db, catalog: catalog);
        await gameData.init();
        return AlchemonsApp(db: db, gameDataService: gameData);
      },
    ),
  );
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
            navigatorObservers: [
              routeObserver,
              ambienceRouteObserver,
              navigationSoundObserver,
            ],
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
  String _loadingStatus = 'Preparing your alchemy lab';
  double _loadingProgress = 0.08;

  void _setLoadingState(String status, double progress) {
    if (!mounted) return;
    setState(() {
      _loadingStatus = status;
      _loadingProgress = progress;
    });
  }

  @override
  void initState() {
    super.initState();
    final db = context.read<AlchemonsDatabase>();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // 1) Precache assets
      _setLoadingState('Warming artwork', 0.18);
      await _precacheAssets();

      // 2) Start spawns
      _setLoadingState('Synchronizing the wilderness', 0.38);
      await _ensureSpawnsStarted();

      // debug helpers removed

      // 3) Run first-launch story BEFORE we ever show the shell
      _setLoadingState('Restoring your journey', 0.54);
      await _runFirstLaunchFlow();

      // 4) Existing "must pick faction" watcher / bootstrap
      final mustPick = await db.settingsDao.getMustPickFaction();
      if (mustPick) _openPicker();

      if (!mounted) return;
      _setLoadingState('Reading the constellations', 0.66);
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

    // 0) Ask returning players if they want to sign in and restore a cloud
    // backup. If they do, the restored save brings its own faction/progress,
    // so we skip the story intro and faction picker entirely.
    final db = context.read<AlchemonsDatabase>();
    final resetOnboarding =
        await db.settingsDao.getSetting(ProgressResetService.onboardingKey) ==
        '1';
    if (!mounted) return;
    final restored = resetOnboarding
        ? false
        : await runFirstLaunchAccountRestore(context);
    if (!mounted) return;
    if (restored) {
      await factionSvc.loadId();
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
      // Precache only the small, shared UI assets. Creature sprite sheets are
      // 4800x1200 and decode to roughly 23 MB each; bulk-loading 25 of them
      // here used hundreds of MB and immediately thrashed the image cache.
      // Visible creature art is warmed later when each navigation screen is
      // mounted behind the startup splash.
      await _precacheUIAssets();

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
    final catalogs = context.watch<CatalogData?>();
    final catalogsReady = catalogs?.isFullyLoaded ?? false;

    if (!_readyToShowShell || !catalogsReady) {
      return AlchemonsSplash(
        status: _readyToShowShell ? 'Loading alchemy systems' : _loadingStatus,
        progress: _readyToShowShell ? 0.72 : _loadingProgress,
      );
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
              onPressed: context.soundAction(
                () => Navigator.pop(context, false),
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: context.soundAction(
                () => Navigator.pop(context, true),
              ),
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
      showAppSnack(error.toString(), isError: true, fallbackContext: context);
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
      showAppSnack(error.toString(), isError: true, fallbackContext: context);
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
              onPressed: context.soundAction(
                () => Navigator.pop(context, false),
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: context.soundAction(
                () => Navigator.pop(context, true),
              ),
              child: const Text('Start New Game'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final db = context.read<AlchemonsDatabase>();
    final store = context.read<MobileStoreService>();
    final deviceId = context.read<AccountSessionService>().deviceId ?? 'local';
    setState(() => _busy = true);
    try {
      await store.pauseForReset();
      await ProgressResetService(db).request(deviceId: deviceId, signOut: true);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(error.toString(), isError: true);
    } finally {
      store.cancelResetPause();
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
                        onPressed: context.soundAction(
                          _busy ? null : _restoreAccountHere,
                        ),
                        child: Text(
                          _busy ? 'Working...' : 'Restore Account Here',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: context.soundAction(
                          _busy ? null : _reactivateHere,
                        ),
                        child: const Text('Reactivate Here'),
                      ),
                      TextButton(
                        onPressed: context.soundAction(
                          _busy ? null : _startNewGame,
                        ),
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
