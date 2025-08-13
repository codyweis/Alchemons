import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
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
  Widget build(BuildContext context) {
    return AppProviders(
      db: db,
      gameDataService: gameDataService,
      child: MaterialApp(
        title: 'Alchemons',
        theme: ThemeData.dark(),
        home: const HomeScreen(),
      ),
    );
  }
}
