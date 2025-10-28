// providers/app_providers.dart
import 'package:alchemons/helpers/breeding_config_loaders.dart';
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/harvest_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/likelihood_analyzer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/alchemons_db.dart';
import '../services/game_data_service.dart';
import '../services/creature_repository.dart';
import '../services/breeding_engine.dart';

/// Load all static data catalogs together
Future<CatalogData> _loadAllCatalogs() async {
  final results = await Future.wait([
    loadElementRecipes(),
    loadSpecialRules(),
    loadFamilyRecipes(),
    loadNatures().then((_) => true), // Convert void to bool
    GeneticsCatalog.load().then((_) => true), // Convert void to bool
  ]);

  debugPrint(
    '[AppProviders] All catalogs loaded (genetics=${GeneticsCatalog.all.length})',
  );

  return CatalogData(
    elementRecipes: results[0] as ElementRecipeConfig,
    specialRules: results[1] as SpecialRulesConfig,
    familyRecipes: results[2] as FamilyRecipeConfig,
    naturesLoaded: results[3] as bool,
    geneticsLoaded: results[4] as bool,
  );
}

/// Container for all loaded catalog data
class CatalogData {
  final ElementRecipeConfig elementRecipes;
  final SpecialRulesConfig specialRules;
  final FamilyRecipeConfig familyRecipes;
  final bool naturesLoaded;
  final bool geneticsLoaded;

  const CatalogData({
    required this.elementRecipes,
    required this.specialRules,
    required this.familyRecipes,
    required this.naturesLoaded,
    required this.geneticsLoaded,
  });

  bool get isFullyLoaded => naturesLoaded && geneticsLoaded;
}

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

        // Theme (light/dark/system)
        ChangeNotifierProvider<ThemeNotifier>(
          create: (ctx) => ThemeNotifier(ctx.read<AlchemonsDatabase>()),
        ),

        ChangeNotifierProvider<HarvestService>(
          create: (ctx) => HarvestService(ctx.read<AlchemonsDatabase>()),
        ),

        // Game data service provider (already initialized)
        Provider<GameDataService>.value(value: gameDataService),

        // Creature repository provider
        Provider<CreatureRepository>(create: (_) => CreatureRepository()),

        ChangeNotifierProvider<SelectedPartyNotifier>(
          create: (_) => SelectedPartyNotifier(),
        ),
        ChangeNotifierProvider<FactionService>(
          create: (ctx) => FactionService(ctx.read<AlchemonsDatabase>()),
        ),

        ProxyProvider2<FactionService, ThemeNotifier, FactionTheme>(
          update: (ctx, factionSvc, themeNotifier, __) {
            final mode = themeNotifier.themeMode;

            // What brightness should the faction skin use?
            final platformBrightness =
                MediaQuery.maybeOf(ctx)?.platformBrightness ?? Brightness.light;

            final effectiveBrightness = switch (mode) {
              ThemeMode.light => Brightness.light,
              ThemeMode.dark => Brightness.dark,
              ThemeMode.system => platformBrightness,
            };

            return factionThemeFor(
              factionSvc.current,
              brightness: effectiveBrightness,
            );
          },
        ),

        // Stamina service provider
        Provider<StaminaService>(
          create: (ctx) => StaminaService(ctx.read<AlchemonsDatabase>()),
        ),

        // Single loader for all catalogs
        FutureProvider<CatalogData?>(
          create: (_) => _loadAllCatalogs(),
          initialData: null,
        ),

        // Breeding tuning knobs
        Provider<BreedingTuning>(
          create: (_) => const BreedingTuning(
            variantChanceCross: 1,
            parentRepeatChance: 20,
            variantChanceOnPure: 5,
            variantBlockedTypes: {"Blood"},
          ),
        ),

        // Breeding engine - waits for catalogs to load
        ProxyProvider2<CatalogData?, CreatureRepository, BreedingEngine?>(
          update: (context, catalogData, repo, previous) {
            if (catalogData == null || !catalogData.isFullyLoaded) {
              return null; // Wait for catalogs to load
            }

            final tuning = context.read<BreedingTuning>();
            return BreedingEngine(
              repo,
              elementRecipes: catalogData.elementRecipes,
              familyRecipes: catalogData.familyRecipes,
              specialRules: catalogData.specialRules,
              tuning: tuning,
              logToConsole: true,
            );
          },
        ),

        // Breeding likelihood analyzer - needs the live engine
        ProxyProvider3<
          CatalogData?,
          CreatureRepository,
          BreedingEngine?,
          BreedingLikelihoodAnalyzer?
        >(
          update: (context, catalogData, repo, engine, previous) {
            if (catalogData == null ||
                !catalogData.isFullyLoaded ||
                engine == null) {
              return null;
            }

            final tuning = context.read<BreedingTuning>();
            return BreedingLikelihoodAnalyzer(
              repository: repo,
              elementRecipes: catalogData.elementRecipes,
              familyRecipes: catalogData.familyRecipes,
              specialRules: catalogData.specialRules,
              tuning: tuning,
              engine: engine,
            );
          },
        ),

        // Game state provider for reactive UI updates
        ChangeNotifierProvider<GameStateNotifier>(
          create: (_) => GameStateNotifier(gameDataService),
        ),
      ],
      child: child,
    );
  }
}

/// Game state notifier for reactive updates
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
