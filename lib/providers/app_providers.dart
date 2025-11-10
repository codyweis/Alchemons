// providers/app_providers.dart
import 'package:alchemons/helpers/breeding_config_loaders.dart';
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/story/models/story_page.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/harvest_service.dart';
import 'package:alchemons/services/inventory_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/services/black_market_service.dart'; // ADD THIS
import 'package:alchemons/services/starter_grant_service.dart';
import 'package:alchemons/services/wild_breed_randomizer.dart';
import 'package:alchemons/services/wilderness_catch_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
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

        ChangeNotifierProvider<BlackMarketService>(
          create: (ctx) => BlackMarketService(ctx.read<AlchemonsDatabase>()),
        ),

        ChangeNotifierProvider(
          create: (ctx) => ShopService(ctx.read<AlchemonsDatabase>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => InventoryService(ctx.read<AlchemonsDatabase>()),
        ),

        ChangeNotifierProvider<StoryManager>(
          create: (ctx) {
            final db = ctx.read<AlchemonsDatabase>();
            final sm = StoryManager(db.settingsDao);
            sm.loadSeen();
            return sm;
          },
        ),

        // Game data service provider (already initialized)
        Provider<GameDataService>.value(value: gameDataService),

        // AppProviders.providers
        StreamProvider<List<CreatureEntry>?>(
          create: (ctx) => ctx.read<GameDataService>().watchAllEntries(),
          initialData: null, // null = "loading" in UI
        ),
        StreamProvider<Set<String>?>(
          create: (ctx) => ctx
              .read<AlchemonsDatabase>()
              .creatureDao
              .watchSpeciesWithInstances(),
          initialData: null,
        ),

        // Creature repository provider
        Provider<CreatureCatalog>.value(value: gameDataService.catalog),

        ChangeNotifierProvider(
          create: (context) =>
              WildernessSpawnService(context.read<AlchemonsDatabase>()),
        ),

        Provider(
          create: (context) => CatchService(context.read<AlchemonsDatabase>()),
        ),

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
        Provider<EggPayloadFactory>(
          create: (ctx) => EggPayloadFactory(ctx.read<CreatureCatalog>()),
        ),
        Provider<WildCreatureRandomizer>(
          create: (ctx) => WildCreatureRandomizer(),
        ),
        Provider<StarterGrantService>(
          create: (ctx) => StarterGrantService(
            db: ctx.read<AlchemonsDatabase>(),
            payloadFactory: ctx.read<EggPayloadFactory>(),
          ),
        ),

        // Single loader for all catalogs
        FutureProvider<CatalogData?>(
          create: (_) => _loadAllCatalogs(),
          initialData: null,
        ),

        // Breeding tuning knobs
        Provider<BreedingTuning>(create: (_) => const BreedingTuning()),

        // Breeding engine - waits for catalogs to load
        ProxyProvider2<CatalogData?, CreatureCatalog, BreedingEngine?>(
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
          CreatureCatalog,
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
      ],
      child: child,
    );
  }
}
