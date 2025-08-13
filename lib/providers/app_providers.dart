// providers/app_providers.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/alchemons_db.dart';
import '../services/game_data_service.dart';
import '../services/creature_repository.dart';
import '../services/breeding_engine.dart';

class AppProviders extends StatelessWidget {
  final AlchemonsDatabase db;
  final GameDataService gameDataService;
  final Widget child;

  const AppProviders({
    super.key,
    required this.db,
    required this.gameDataService,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Database provider
        Provider<AlchemonsDatabase>.value(value: db),

        // Game data service provider (already initialized)
        Provider<GameDataService>.value(value: gameDataService),

        // Creature repository provider
        Provider<CreatureRepository>(create: (context) => CreatureRepository()),

        // Breeding engine provider
        ProxyProvider<CreatureRepository, BreedingEngine>(
          update: (context, repository, breedingEngine) {
            return BreedingEngine(repository);
          },
        ),

        // Game state provider for reactive UI updates
        ChangeNotifierProvider<GameStateNotifier>(
          create: (context) => GameStateNotifier(gameDataService),
        ),
      ],
      child: child,
    );
  }
}

// Game state notifier for reactive updates
class GameStateNotifier extends ChangeNotifier {
  final GameDataService _gameDataService;
  List<Map<String, dynamic>> _creatures = [];
  bool _isLoading = true;
  String? _error;

  GameStateNotifier(this._gameDataService) {
    _loadCreatures();
  }

  // Getters
  List<Map<String, dynamic>> get creatures => _creatures;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Map<String, dynamic>> get discoveredCreatures =>
      _creatures.where((c) => c['player'].discovered == true).toList();

  Future<void> _loadCreatures() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final data = await _gameDataService.getMergedCreatureData();
      _creatures = data;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markDiscovered(String creatureId) async {
    try {
      await _gameDataService.markDiscovered(creatureId);
      // Refresh the creature list
      await _loadCreatures();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _loadCreatures();
  }
}
