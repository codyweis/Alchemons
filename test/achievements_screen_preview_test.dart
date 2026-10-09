@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/screens/story/campaign_journal_screen.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/campaign_rewards_button.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The achievements screen on a phone, with the app's own fonts (fetched from
// Google, so run with network), on a save part way through: the chapter
// beads and story, the ready band, tasks, each shelf of spheres, a sphere's
// sheet and its collect, the story so far, memories, a 1.3× text pass, and
// the home bar in each of its states.
//
//   ACHIEVEMENTS_OUT=/tmp/ach flutter test \
//     test/achievements_screen_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['ACHIEVEMENTS_OUT'];

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
    final home =
        Platform.environment['PUB_CACHE'] ??
        '${Platform.environment['HOME']}/.pub-cache';
    await loadFont(
      'packages/phosphoricons_flutter/PhosphorBold',
      '$home/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/Phosphor-Bold.ttf',
    );
  });

  testWidgets('achievements preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 44 * 3, bottom: 30 * 3);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.createTempSync('fonts').path,
    );

    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() async {
      GoogleFonts.imFellEnglishTextTheme();
      await GoogleFonts.pendingFonts();
      // Chapter 4 reached, the revelation's reward still to take, a few
      // systems under way and a few done.
      final settings = {
        'first_extraction_done': '1',
        'cosmic_ship_unlocked': '1',
        CampaignJournalService.revelationKey: '1',
        'campaign_claim_first_extraction': '1',
        'campaign_claim_ship': '1',
        'campaign_claim_enhance_1': '1',
        'campaign_claim_orb_use_1': '1',
        'campaign_claim_biome_harvest_1': '1',
        'campaign_claim_portal_1': '1',
        'campaign_fuse_family_let_v1': '5',
        'campaign_fuse_family_pip_v1': '3',
        'campaign_fuse_family_horn_v1': '2',
        'campaign_fuse_family_mask_v1': '4',
        'campaign_fuse_family_wing_v1': '1',
        'campaign_fuse_family_mane_v1': '2',
        'campaign_wild_fusions_v1': '6',
        'campaign_wild_harvests_v1': '10',
        'campaign_biome_harvest_v1': '1',
        'campaign_enhance_v1': '1',
        'campaign_orb_use_v1': '1',
        'campaign_portal_enter_v1': '1',
        'campaign_survival_cleared_v1': '24',
        'pureblood_rite_stage_index_v2': '2',
        // Two places visited, one of them with its silver still waiting.
        'task_seen_shop': '1',
        'task_claimed_shop': '1',
        'task_seen_inventory': '1',
      };
      for (final e in settings.entries) {
        await db.settingsDao.setSetting(e.key, e.value);
      }
      await CampaignJournalService(db).load();
    });

    final key = GlobalKey();
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    // Ready spheres keep turning, so nothing here ever settles.
    Future<void> settle([int frames = 12]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 80));
      }
    }

    final theme = factionThemeFor(
      FactionId.volcanic,
      brightness: Brightness.dark,
    );
    Future<void> show(
      Widget home, {
      double textScale = 1,
      AlchemonsDatabase? on,
    }) async {
      final db0 = on ?? db;
      await tester.pumpWidget(
        MultiProvider(
          key: UniqueKey(),
          providers: [
            Provider<AlchemonsDatabase>.value(value: db0),
            ChangeNotifierProvider<TimedBoostService>(
              create: (_) => TimedBoostService(db0.settingsDao)..load(),
            ),
            ChangeNotifierProvider<ShopService>(
              create: (ctx) => ShopService(
                db0,
                ConstellationEffectsService(db0),
                FactionService(db0),
                ctx.read<TimedBoostService>(),
              ),
            ),
            Provider<FactionTheme>.value(value: theme),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme.toMaterialTheme(
              GoogleFonts.imFellEnglishTextTheme(ThemeData.dark().textTheme),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: RepaintBoundary(key: key, child: child!),
            ),
            home: home,
          ),
        ),
      );
      await settle(16);
    }

    Future<void> scrollShot(String name, {double by = 640}) async {
      await tester.dragFrom(const Offset(195, 600), Offset(0, -by));
      await settle(8);
      await shoot(name);
    }

    await show(const CampaignJournalScreen());
    await shoot('01_top');
    await scrollShot('02_tasks');
    await scrollShot('03_collection');
    await scrollShot('04_exploration');
    await scrollShot('05_survival_challenges');
    await scrollShot('06_bottom', by: 2000);

    // A ready sphere's sheet, then collecting from it.
    await show(const CampaignJournalScreen());
    final harvest = find.text('Field collector');
    await tester.scrollUntilVisible(
      harvest,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(4);
    await tester.tap(harvest);
    await settle();
    await shoot('07_sheet_ready');
    // The sheet's, not a task row's.
    await tester.tap(find.text('COLLECT').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await shoot('08_collecting');
    await settle(14);
    await shoot('09_collected');

    // An underway one.
    final mask = find.text('A lineage of masks');
    await tester.scrollUntilVisible(
      mask,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(4);
    await tester.tap(mask);
    await settle();
    await shoot('10_sheet_underway');

    // The archive pages.
    await show(const CampaignJournalScreen());
    await tester.tap(find.text('STORY SO FAR'));
    await settle();
    await shoot('11_story_so_far');
    await tester.tap(find.byIcon(AppIcons.arrow_back_rounded));
    await settle();
    await tester.tap(find.text('MEMORIES'));
    await settle();
    await shoot('12_memories');
    final fold = find.text('READ');
    if (fold.evaluate().isNotEmpty) {
      await tester.tap(fold.first);
      await settle();
      await shoot('13_memories_open');
    }

    // Large text.
    await show(const CampaignJournalScreen(), textScale: 1.3);
    await shoot('14_large_text');
    await scrollShot('15_large_text_lower', by: 900);

    // The home bar: something waiting, then with only tasks left to visit,
    // then nothing at all; each wide and docked.
    Widget bars() => Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: Column(
          children: const [
            SizedBox(height: 30),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: CampaignRewardsButton(style: CampaignRewardsStyle.bar),
            ),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 90),
              child: CampaignRewardsButton(style: CampaignRewardsStyle.bar),
            ),
            SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 64,
                child: CampaignRewardsButton(
                  style: CampaignRewardsStyle.bar,
                  docked: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await show(bars());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await settle();
    await shoot('16_bar_ready');

    // Separate saves rather than claiming on this one mid-test: a claim
    // under the live button's database watch never returned.
    Future<AlchemonsDatabase> save(Map<String, String> settings) async {
      final other = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await tester.runAsync(() async {
        for (final e in settings.entries) {
          await other.settingsDao.setSetting(e.key, e.value);
        }
      });
      return other;
    }

    // A new save: nothing earned, every open task still to visit.
    await show(bars(), on: await save(const {}));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await settle();
    await shoot('17_bar_tasks');

    // Every task done and nothing waiting.
    await show(
      bars(),
      on: await save({
        for (final id in const [
          'shop',
          'inventory',
          'battle_tab',
          'enhance',
          'harvest',
          'rite',
          'constellation',
          'profile',
        ]) ...{'task_seen_$id': '1', 'task_claimed_$id': '1'},
      }),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await settle();
    await shoot('18_bar_quiet');

    expect(tester.takeException(), isNull);
    await tester.runAsync(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pump();
  });
}
