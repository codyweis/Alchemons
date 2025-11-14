import 'dart:async';
import 'dart:ui';

import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/pools/sky_pool.dart';
import 'package:alchemons/models/encounters/pools/swamp_pool.dart';
import 'package:alchemons/models/encounters/pools/volcano_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/faction_picker.dart';
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

  @override
  void initState() {
    super.initState();
    final db = context.read<AlchemonsDatabase>();

    // 1) One-shot check after first frame (Navigator is ready)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // >>> boot the spawn system once providers are available
      await _ensureSpawnsStarted();

      final mustPick = await db.settingsDao.getMustPickFaction();
      if (mustPick) _openPicker();
    });

    // 2) React to changes while the app is running
    _sub = db.settingsDao.watchMustPickFaction().listen((mustPick) {
      if (!mounted || !mustPick) return;
      _openPicker();
    });
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

    // (Optional) For dev: make first spawn “sooner”
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
  Widget build(BuildContext context) => widget.child;
}
