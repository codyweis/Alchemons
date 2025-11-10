import 'dart:async';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Create the database
  final db = constructDb();

  // 2. Load the catalog from assets
  final catalog = CreatureCatalog();
  await catalog.load(); // this reads assets/data/alchemons_creatures.json

  // 3. Create the game data service with the catalog and db
  final gameData = GameDataService(db: db, catalog: catalog);
  await gameData.init();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 4. Run the app
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
          // 1. Pull in both providers we care about
          final themeNotifier = context.watch<ThemeNotifier>();

          // ... (rest of your theme logic) ...
          final factionSvc = context.watch<FactionService>();
          final factionId = factionSvc.current;

          // Build LIGHT faction theme
          final lightFactionTheme = factionThemeFor(
            factionId,
            brightness: Brightness.light,
          );

          // Build DARK faction theme
          final darkFactionTheme = factionThemeFor(
            factionId,
            brightness: Brightness.dark,
          );

          // Shared base text theme with your font
          final textTheme = GoogleFonts.aBeeZeeTextTheme(
            Theme.of(context).textTheme,
          );

          final lightThemeData = lightFactionTheme.toMaterialTheme(textTheme);
          final darkThemeData = darkFactionTheme.toMaterialTheme(textTheme);

          return MaterialApp(
            title: 'Alchemons',

            // 👇 This is the persisted user choice from ThemeNotifier
            themeMode: themeNotifier.themeMode,

            // 👇 Supply both palettes to Flutter
            theme: lightThemeData,
            darkTheme: darkThemeData,

            // 2. ADD THIS LINE
            // This connects your app's navigation to the RouteAware mixin
            navigatorObservers: [routeObserver],

            home: const AppGate(child: HomeScreen()),
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

  @override
  void initState() {
    super.initState();
    final db = context.read<AlchemonsDatabase>();

    // 1) One-shot check after first frame (Navigator is ready)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final mustPick = await db.settingsDao.getMustPickFaction();
      if (mustPick) _openPicker();
    });

    // 2) React to changes while the app is running
    _sub = db.settingsDao.watchMustPickFaction().listen((mustPick) {
      if (!mounted || !mustPick) return;
      _openPicker();
    });
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
