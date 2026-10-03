@Tags(['preview'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/audio/scene_ambience.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/models/stored_theme_mode.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/home_screen.dart';
import 'package:alchemons/screens/profile_screen.dart';
import 'package:alchemons/screens/story/models/story_page.dart';
import 'package:alchemons/services/account_cloud_save_service.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/account_session_service.dart';
import 'package:alchemons/services/black_market_service.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/cold_storage_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/services/cosmic_memory_tutorial_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/harvest_service.dart';
import 'package:alchemons/services/inventory_service.dart';
import 'package:alchemons/services/mobile_store_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/services/starter_grant_service.dart';
import 'package:alchemons/services/survival_upgrade_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/services/wild_breed_randomizer.dart';
import 'package:alchemons/services/wilderness_catch_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/section_router.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/exit_game_dialog.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/story_dialog.dart';
import 'package:alchemons/widgets/currency_display_widget.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The real app shell — all five tabs and the dock — on an in-memory save a
// few weeks in, in the faction a player would have, with the app's own fonts
// (fetched from Google, so run with network): home, each tab, profile, the
// screens reached from home, the shared dialogs and a specimen's details.
//
//   APP_SHELL_OUT=/tmp/shell flutter test \
//     test/app_shell_preview_test.dart --tags preview
//
// APP_SHELL_FACTIONS=earthen,volcanic narrows the factions. Run one faction
// per process: the particle title caches its image across tests, and from
// the second test on it is blank.
void main() {
  final out = Platform.environment['APP_SHELL_OUT'];
  final factionFilter = Platform.environment['APP_SHELL_FACTIONS'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    final home =
        Platform.environment['PUB_CACHE'] ??
        '${Platform.environment['HOME']}/.pub-cache';
    await loadFont(
      'packages/phosphoricons_flutter/PhosphorBold',
      '$home/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/Phosphor-Bold.ttf',
    );
  });

  final factions = [
    for (final f in FactionId.values)
      if (factionFilter == null || factionFilter.split(',').contains(f.name)) f,
  ];

  for (final faction in factions) {
    testWidgets('app shell ${faction.name}', (tester) async {
      if (out == null) return;
      final dir = '$out/${faction.name}';
      Directory(dir).createSync(recursive: true);

      HttpOverrides.global = null;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => Directory.systemTemp.createTempSync('fonts').path,
      );
      for (final channel in const [
        'dev.fluttercommunity.plus/sensors/method',
        'dev.fluttercommunity.plus/sensors/accelerometer',
        'plugins.flutter.io/in_app_purchase',
        'plugins.flutter.io/firebase_core',
        'flutter_timezone',
      ]) {
        messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async {
          return null;
        });
      }
      messenger.setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async => switch (call.method) {
          'initialize' => true,
          'pendingNotificationRequests' || 'getActiveNotifications' => [],
          _ => null,
        },
      );
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      // Every player gets a channel of its own, named at run time; answer
      // them all with an empty reply.
      messenger.allMessagesHandler = (channel, handler, message) {
        if (channel.startsWith('com.ryanheise.just_audio')) {
          return Future.value(
            const StandardMethodCodec().encodeSuccessEnvelope(
              <String, dynamic>{},
            ),
          );
        }
        return handler?.call(message);
      };
      addTearDown(() => messenger.allMessagesHandler = null);
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 44 * 3, bottom: 30 * 3);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});

      final db = AlchemonsDatabase(NativeDatabase.memory());
      late CreatureCatalog catalog;
      late GameDataService gameData;
      await tester.runAsync(() async {
        // Fetched before the first frame, or the first shots are boxes.
        GoogleFonts.imFellEnglishTextTheme();
        GoogleFonts.imFellEnglish(fontStyle: FontStyle.italic);
        GoogleFonts.cinzel();
        GoogleFonts.cinzel(fontWeight: FontWeight.w700);
        GoogleFonts.cinzelDecorative();
        GoogleFonts.cinzelDecorative(fontWeight: FontWeight.w600);
        GoogleFonts.crimsonText();
        GoogleFonts.imFellGreatPrimer();
        await GoogleFonts.pendingFonts();
        final json =
            jsonDecode(
                  File(
                    'assets/data/alchemons_creatures.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        catalog = CreatureCatalog.fromList([
          for (final c in json['creatures'] as List)
            Creature.fromJson(c as Map<String, dynamic>),
        ]);
        await _seed(db, faction);
        gameData = GameDataService(db: db, catalog: catalog);
      });

      final key = GlobalKey();
      final nav = GlobalKey<NavigatorState>();
      Future<void> shoot(String name) async {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> settle([int frames = 10]) async {
        for (var i = 0; i < frames; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await tester.pumpWidget(
        _AuditProviders(
          db: db,
          gameData: gameData,
          child: Builder(
            builder: (context) {
              final themeNotifier = context.watch<ThemeNotifier>();
              final factionId = context.watch<FactionService>().current;
              final textTheme = themeNotifier.currentTextThemeFn(
                Theme.of(context).textTheme,
              );
              return MaterialApp(
                navigatorKey: nav,
                debugShowCheckedModeBanner: false,
                themeMode: themeNotifier.themeMode,
                theme: factionThemeFor(
                  factionId,
                  brightness: Brightness.light,
                ).toMaterialTheme(textTheme),
                darkTheme: factionThemeFor(
                  factionId,
                  brightness: Brightness.dark,
                ).toMaterialTheme(textTheme),
                navigatorObservers: [routeObserver, ambienceRouteObserver],
                builder: (context, child) =>
                    RepaintBoundary(key: key, child: child!),
                home: const MainShell(),
              );
            },
          ),
        ),
      );
      // Warm-up splash, then the home screen's own start.
      await settle(60);
      await shoot('01_home');

      Future<void> go(NavSection s, String name, {int frames = 40}) async {
        SectionRouter.instance.onSwitchSection?.call(s);
        await settle(frames);
        await shoot(name);
      }

      Future<void> tapText(String text, String name, {int frames = 24}) async {
        final f = find.text(text);
        if (f.evaluate().isEmpty) return;
        await tester.tap(f.first, warnIfMissed: false);
        await settle(frames);
        await shoot(name);
      }

      Future<void> scrollShot(String name, {double by = 650}) async {
        final f = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        );
        if (f.evaluate().isEmpty) return;
        // The one in view: the last mounted vertical scrollable on top.
        await tester.dragFrom(const Offset(195, 600), Offset(0, -by));
        await settle(16);
        await shoot(name);
      }

      // The currency with the notice out of its way, folded and opened.
      final close = find.byIcon(AppIcons.close_rounded);
      if (close.evaluate().isNotEmpty) {
        await tester.tap(close.first, warnIfMissed: false);
        await settle(12);
      }
      await shoot('01b_home_no_notice');
      final coins = find.byType(CurrencyDisplayWidget);
      if (coins.evaluate().isNotEmpty) {
        await tester.tap(coins.first, warnIfMissed: false);
        await settle(14);
        await shoot('01c_home_currency_open');
        await tester.tap(coins.first, warnIfMissed: false);
        await settle(14);
      }

      await go(NavSection.creatures, '02_creatures');
      await tapText('CATALOG', '02b_catalog', frames: 30);
      await go(NavSection.shop, '03_shop');
      await scrollShot('03b_shop_scrolled');
      await scrollShot('03c_shop_scrolled_more');
      await scrollShot('03d_shop_bottom', by: 1200);
      await go(NavSection.breed, '04_breed');
      await tapText('FUSION', '04b_fusion', frames: 30);
      await go(NavSection.inventory, '05_inventory');
      await tapText('Vials', '05b_inventory_vials');
      await tapText('Special', '05c_inventory_special');
      await go(NavSection.home, '06_home_again', frames: 20);

      // Everything reached from home, each given its own chance to fail.
      Future<void> step(String name, Future<void> Function() body) async {
        try {
          await body();
        } catch (e) {
          debugPrint('audit step $name failed: $e');
        }
      }

      Future<void> openAndBack(String label, String name) async {
        final f = find.text(label);
        if (f.evaluate().isEmpty) return;
        await tester.tap(f.first, warnIfMissed: false);
        await settle(50);
        await shoot(name);
        await scrollShot('${name}_scrolled');
        if (nav.currentState!.canPop()) nav.currentState!.pop();
        await settle(30);
      }

      await step('field', () => openAndBack('FIELD', '12_field_map'));
      await step('harvest', () => openAndBack('HARVEST', '13_harvest'));
      await step('upgrade', () => openAndBack('UPGRADE', '14_upgrade'));
      await step(
        'achievements',
        () => openAndBack('ACHIEVEMENTS', '15_achievements'),
      );

      final ctx = nav.currentContext!;
      await step('exit dialog', () async {
        unawaited(showExitGameDialog(ctx));
        await settle(16);
        await shoot('16_exit_dialog');
        nav.currentState!.pop();
        await settle(10);
      });
      await step('story dialog', () async {
        unawaited(
          showStoryDialog(
            ctx,
            primaryLabel: 'GOT IT',
            beats: const [
              StoryBeat(
                title: 'Cold Storage',
                message:
                    'Cold storage still cultivates your vials, but 5x slower.',
              ),
            ],
          ),
        );
        await settle(20);
        await shoot('17_story_dialog');
        nav.currentState!.pop();
        await settle(10);
      });
      await step('confirm', () async {
        final theme = ctx.read<FactionTheme>();
        unawaited(
          showBracketConfirm(
            ctx,
            palette: BracketPalette.fromTheme(theme),
            accent: ForgeTokens(theme).amber,
            title: 'Complete sale',
            message: 'Sell 3 specimens?',
            amounts: const [(CoinKind.silver, 2005)],
            warning: 'This cannot be undone.',
            confirmLabel: 'SELL',
          ),
        );
        await settle(16);
        await shoot('18_bracket_confirm');
        nav.currentState!.pop();
        await settle(10);
      });
      await step('snack', () async {
        showGameSnack(ctx, 'Harvest collected', icon: AppIcons.check_rounded);
        await settle(14);
        await shoot('19_snack');
        await settle(60);
      });

      // A specimen's details, from the creatures tab.
      await step('details', () async {
        SectionRouter.instance.onSwitchSection?.call(NavSection.creatures);
        await settle(30);
        final level = find.textContaining('LV ');
        if (level.evaluate().isEmpty) return;
        await tester.tap(level.first, warnIfMissed: false);
        await settle(50);
        await shoot('20_details');
        await scrollShot('21_details_scrolled');
        await scrollShot('22_details_scrolled_more');
        if (nav.currentState!.canPop()) nav.currentState!.pop();
        await settle(20);
        SectionRouter.instance.onSwitchSection?.call(NavSection.home);
        await settle(20);
      });

      // The profile, pushed the way the avatar does.
      nav.currentState!.push(
        CupertinoPageRoute(
          builder: (ctx) => ProfileScreen(() => Navigator.pop(ctx)),
          fullscreenDialog: true,
        ),
      );
      await settle(40);
      await shoot('08_profile');
      await scrollShot('09_profile_scrolled');
      await scrollShot('10_profile_scrolled_more');
      await scrollShot('11_profile_bottom', by: 1500);
      nav.currentState!.pop();
      await settle(20);

      await tester.pumpWidget(const SizedBox());
      // Long one-shot delays (tutorial checks, toasts) left by the screens.
      await tester.pump(const Duration(minutes: 5));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.runAsync(db.close);
    });
  }
}

Future<void> _seed(AlchemonsDatabase db, FactionId faction) async {
  final s = db.settingsDao;
  // A save that once picked light mode still opens dark.
  await s.setStoredThemeMode(StoredThemeMode.light);
  await s.setSetting('audio.master_enabled', '0');
  await s.setSetting('starter_granted_v1', '1');
  await s.setSetting('first_extraction_done', '1');
  await s.setFieldTutorialCompleted();
  await s.setCreaturesTutorialSeen();
  await s.setConstellationTutorialSeen();
  await s.setBiomeHarvestTutorialSeen();
  await s.setFeedingTutorialSeen();
  await s.setNavLocked(false);
  await s.setMustPickFaction(false);
  await s.setSetting(ColdStorageService.introSeenSettingKey, '1');
  await CosmicMemoryTutorialService.markCompleted(s);
  await CosmicMemoryTutorialService.acknowledgeStory(s);
  for (final task in kOnboardingTasks) {
    await s.setSetting(task.settingKey, '1');
    await s.setSetting(task.claimedKey, '1');
  }
  await FactionService(db).setId(faction);

  await db.currencyDao.addGold(42);
  await db.currencyDao.addSilver(12850);

  const owned = <(String, int)>[
    ('LET01', 14),
    ('LET02', 9),
    ('LET04', 6),
    ('PIP01', 18),
    ('PIP04', 12),
    ('HOR01', 22),
    ('HOR07', 10),
    ('MAN03', 8),
    ('MSK04', 5),
    ('WNG05', 25),
    ('KIN02', 4),
    ('MYS06', 30),
  ];
  var n = 0;
  for (final (base, level) in owned) {
    await db.creatureDao.addOrUpdateCreature(
      PlayerCreaturesCompanion(id: Value(base), discovered: const Value(true)),
    );
    await db.creatureDao.insertInstance(
      instanceId: 'i${n++}',
      baseId: base,
      level: level,
      staminaBars: 3,
      statSpeedPotential: 2.0 + (n % 3),
      statIntelligencePotential: 3.0 + (n % 2),
      statStrengthPotential: 2.5 + (n % 4) * 0.5,
      statBeautyPotential: 3.5,
    );
  }
  await s.setFeaturedInstanceId('i9');

  await db.incubatorDao.purchaseFusionSlot();
  await db.incubatorDao.placeEgg(
    slotId: 0,
    eggId: 'egg0',
    resultCreatureId: 'HOR01',
    rarity: 'rare',
    hatchAtUtc: DateTime.now().toUtc().add(const Duration(hours: 3)),
  );
  await db.incubatorDao.placeEgg(
    slotId: 1,
    eggId: 'egg1',
    resultCreatureId: 'LET02',
    rarity: 'common',
    hatchAtUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
  );
  await db.incubatorDao.enqueueEgg(
    eggId: 'stored0',
    resultCreatureId: 'PIP01',
    rarity: 'uncommon',
    remaining: const Duration(hours: 5),
  );
}

/// AppProviders with the network-backed services stood in for.
class _AuditProviders extends StatelessWidget {
  const _AuditProviders({
    required this.db,
    required this.gameData,
    required this.child,
  });

  final AlchemonsDatabase db;
  final GameDataService gameData;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AlchemonsDatabase>.value(value: db),
        ChangeNotifierProvider<AccountService>(create: (_) => _FakeAccount()),
        ChangeNotifierProvider<AccountSessionService>(
          create: (_) => _FakeSession(),
        ),
        Provider<AccountCloudSaveService>(create: (_) => _FakeCloudSave()),
        ChangeNotifierProvider<AudioController>(
          create: (ctx) => AudioController(db),
        ),
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier(db)),
        ChangeNotifierProvider<HarvestService>(
          create: (_) => HarvestService(db),
        ),
        Provider<CreatureCatalog>.value(value: gameData.catalog),
        ChangeNotifierProvider<ConstellationEffectsService>(
          create: (_) => ConstellationEffectsService(db),
        ),
        ChangeNotifierProvider<TimedBoostService>(
          create: (_) => TimedBoostService(db.settingsDao)..load(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (ctx) => BlackMarketService(
            db,
            ctx.read<ConstellationEffectsService>(),
            ctx.read<CreatureCatalog>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => InventoryService(db)),
        ChangeNotifierProvider<MobileStoreService>(create: (_) => _FakeStore()),
        ChangeNotifierProvider<StoryManager>(
          create: (_) => StoryManager(db.settingsDao)..loadSeen(),
        ),
        Provider<GameDataService>.value(value: gameData),
        StreamProvider<List<CreatureEntry>?>(
          create: (_) => gameData.watchAllEntries(),
          initialData: null,
        ),
        StreamProvider<Set<String>?>(
          create: (_) => db.creatureDao.watchSpeciesWithInstances(),
          initialData: null,
        ),
        ChangeNotifierProvider<FactionService>(
          create: (_) => FactionService(db)..loadId(),
        ),
        ChangeNotifierProvider(
          create: (_) => WildernessSpawnService(
            db,
            defaultWindowMin: const Duration(minutes: 1),
            defaultWindowMax: const Duration(hours: 4),
          ),
        ),
        Provider(
          create: (ctx) =>
              CatchService(db, ctx.read<ConstellationEffectsService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ShopService(
            db,
            ctx.read<ConstellationEffectsService>(),
            ctx.read<FactionService>(),
            ctx.read<TimedBoostService>(),
          ),
        ),
        ChangeNotifierProvider<SurvivalUpgradeService>(
          create: (_) => SurvivalUpgradeService(db)..load(),
        ),
        ChangeNotifierProvider<FamilyMasteryService>(
          create: (_) => FamilyMasteryService(db)..load(),
        ),
        ChangeNotifierProvider<SelectedPartyNotifier>(
          create: (_) => SelectedPartyNotifier(),
        ),
        ProxyProvider2<FactionService, ThemeNotifier, FactionTheme>(
          update: (ctx, factionSvc, themeNotifier, _) {
            final platform =
                MediaQuery.maybeOf(ctx)?.platformBrightness ?? Brightness.light;
            final effective = switch (themeNotifier.themeMode) {
              ThemeMode.light => Brightness.light,
              ThemeMode.dark => Brightness.dark,
              ThemeMode.system => platform,
            };
            return factionThemeFor(factionSvc.current, brightness: effective);
          },
        ),
        Provider<StaminaService>(create: (_) => StaminaService(db)),
        Provider<EggPayloadFactory>(
          create: (ctx) => EggPayloadFactory(ctx.read<CreatureCatalog>()),
        ),
        Provider<WildCreatureRandomizer>(
          create: (_) => WildCreatureRandomizer(),
        ),
        Provider<StarterGrantService>(
          create: (ctx) => StarterGrantService(
            db: db,
            payloadFactory: ctx.read<EggPayloadFactory>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => ConstellationService(db)),
        Provider<CatalogData?>.value(
          value: CatalogData(
            elementRecipes: ElementRecipeConfig(recipes: const {}),
            familyRecipes: const FamilyRecipeConfig(recipes: {}),
            naturesLoaded: true,
            geneticsLoaded: true,
          ),
        ),
      ],
      child: child,
    );
  }
}

class _FakeAccount extends ChangeNotifier implements AccountService {
  @override
  bool get initialized => true;
  @override
  bool get isConfigured => true;
  @override
  bool get isSignedIn => false;
  @override
  String get displayName => 'NO NAME SET';
  @override
  String get email => '';
  @override
  String? get configurationError => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeSession extends ChangeNotifier implements AccountSessionService {
  @override
  AccountSessionState get state => const AccountSessionState.idle();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeCloudSave implements AccountCloudSaveService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeStore extends ChangeNotifier implements MobileStoreService {
  @override
  List<GoldPackDefinition> get packDefinitions => const [
    GoldPackDefinition(
      productId: 'alchemons_gold_small',
      title: 'Pouch',
      subtitle: 'A little gold.',
      goldAmount: 20,
      badge: '',
    ),
    GoldPackDefinition(
      productId: 'alchemons_gold_popular',
      title: 'Coffer',
      subtitle: 'The usual.',
      goldAmount: 120,
      badge: 'POPULAR',
    ),
    GoldPackDefinition(
      productId: 'alchemons_gold_celestial',
      title: 'Celestial',
      subtitle: 'Heavy stockpile.',
      goldAmount: 500,
      badge: 'PREMIUM',
    ),
  ];
  @override
  bool get isSupportedPlatform => true;
  @override
  bool get isLoading => false;
  @override
  bool get requiresSignIn => true;
  @override
  int get pendingRedeemCount => 0;
  @override
  String? get lastError => null;
  @override
  bool isPurchasePending(String productId) => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
