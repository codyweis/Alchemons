import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'database/alchemons_db.dart';
import 'database/db_helper.dart';
import 'services/game_data_service.dart';
import 'providers/app_providers.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = constructDb();
  final gameData = GameDataService(db: db);
  await gameData.init();

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
