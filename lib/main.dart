import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
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

          // NOTE: The FactionTheme you get from context.watch<FactionTheme>()
          // is already brightness-aware based on the *effective* brightness
          // (we wired that in ProxyProvider2 above).
          //
          // But MaterialApp needs TWO themes: one for light, one for dark.
          // So we generate them manually using your factionThemeFor factory.

          // We'll grab the current faction id once so we don't assume null.
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

            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
