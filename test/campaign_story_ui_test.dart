import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/screens/story/beauty_mask_reveal.dart';
import 'package:alchemons/screens/story/campaign_journal_screen.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/campaign_rewards_button.dart';
import 'package:alchemons/widgets/fx/realm_sift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final output = Platform.environment['STORY_UI_OUT'];
  setUpAll(() async {
    if (output != null) {
      final font = FontLoader('Roboto')
        ..addFont(
          File(
            'C:/Windows/Fonts/arial.ttf',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await icons.load();
    }
  });
  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (output == null) return;
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'revelation: every realm falls, each line waits for a tap, then it ends',
    (tester) async {
      tester.view.physicalSize = const Size(900, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const size = Size(900, 540);
      // A plain colour stands in for each realm's field.
      final pictures = <RealmPicture>[];
      var shade = 0;
      for (final (id, _) in maskedRealms()) {
        final colour = Color(0xFF203040 + 0x0F0A05 * shade++);
        final picture = await tester.runAsync(
          () => RealmPicture.record(
            id,
            size,
            1,
            (c) => c.drawRect(Offset.zero & size, Paint()..color = colour),
          ),
        );
        pictures.add(picture!);
      }
      final key = GlobalKey();
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFF29121D)),
                ),
                Positioned.fill(
                  child: BeautyMaskReveal(
                    pictures: pictures,
                    onComplete: () async {
                      completed++;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      // A frame at a time: the cinematic steps at most 1/20 s a frame.
      Future<void> run(double seconds) async {
        for (var t = 0.0; t < seconds; t += 0.05) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      Future<void> read(String line, String hint) async {
        await run(2);
        expect(find.text(line), findsOneWidget);
        expect(find.text(hint), findsOneWidget);
        expect(completed, 0);
        // A tap the moment a line shows is not taken as read.
        await tester.tap(find.byType(BeautyMaskReveal), warnIfMissed: false);
      }

      // The Valley alone, then its line, which waits however long.
      await run(5);
      await run(20);
      await capture(tester, key, 'valley_before');
      await read('The valley is here, where it cannot be.', 'LOOK CLOSER');
      // Every realm falls; then the planet, bare.
      await run(16);
      await capture(tester, key, 'realms_falling');
      await run(26);
      await read('Trees and valleys are absent in this universe.', 'CONTINUE');
      // The realms gather on the map and come apart.
      await run(15);
      expect(find.text('AM I DREAMING?'), findsOneWidget);
      await read('No, I am finally awake.', 'CONTINUE');
      await read(
        'You did not make the valley to hide the world from danger. You '
            'made it to hide your work from yourself.',
        'CONTINUE',
      );
      // No memory without its cast: straight to what the alchemist says,
      // which comes a line at a time and is not taken as read until all of
      // it is there.
      await run(1);
      expect(find.text('I am not sorry.'), findsOneWidget);
      await tester.tap(find.byType(BeautyMaskReveal), warnIfMissed: false);
      await run(1);
      expect(
        find.text('If Alchemy is wrong, why is it so beautiful?'),
        findsOneWidget,
      );
      await run(5);
      expect(completed, 0);
      await tester.tap(find.byType(BeautyMaskReveal), warnIfMissed: false);
      // The planet's light rises, and only then is it over.
      await run(1);
      expect(completed, 0);
      await run(3);
      expect(completed, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'journal shows objectives and claimable rewards on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() async {
        await db.settingsDao.setSetting('first_extraction_done', '1');
        await db.settingsDao.setSetting('cosmic_ship_unlocked', '1');
        await db.settingsDao.setSetting(
          CampaignJournalService.stadiumFoundKey,
          '1',
        );
        await db.settingsDao.setSetting(
          CampaignJournalService.revelationKey,
          '1',
        );
        await CampaignJournalService(db).recordSurvivalClear(20);
        await CampaignJournalService(db).load();
      });
      final key = GlobalKey();
      // Not pumpAndSettle: a sphere whose reward is waiting keeps turning, so
      // this screen never settles. Long enough for a route or a sheet.
      Future<void> settle() async {
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            ChangeNotifierProvider<TimedBoostService>(
              create: (_) => TimedBoostService(db.settingsDao)..load(),
            ),
            ChangeNotifierProvider<ShopService>(
              create: (ctx) => ShopService(
                db,
                ConstellationEffectsService(db),
                FactionService(db),
                ctx.read<TimedBoostService>(),
              ),
            ),
            // The journal is forge-themed now and reads FactionTheme the same
            // way every other themed screen does; the app provides it globally.
            Provider<FactionTheme>.value(
              value: factionThemeFor(
                FactionId.volcanic,
                brightness: Brightness.dark,
              ),
            ),
          ],
          child: RepaintBoundary(
            key: key,
            child: const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: CampaignJournalScreen(),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await settle();
      expect(find.text('Achievements'), findsOneWidget);
      expect(find.text('What remained'), findsOneWidget);
      expect(find.text('6 READY'), findsOneWidget);
      await capture(tester, key, 'achievements_home');
      await tester.tap(find.text('STORY SO FAR'));
      await settle();
      expect(find.text('Story so far'), findsOneWidget);
      await capture(tester, key, 'achievements_story');
      await tester.tap(find.byIcon(AppIcons.arrow_back_rounded));
      await settle();
      await tester.tap(find.text('MEMORIES').last);
      await settle();
      expect(find.text('Memories'), findsOneWidget);
      await capture(tester, key, 'achievements_memories');
      await tester.tap(find.byIcon(AppIcons.arrow_back_rounded));
      await settle();
      final collectAll = find.text('COLLECT ALL');
      await tester.ensureVisible(collectAll);
      await tester.runAsync(() async {
        await tester.tap(collectAll);
        await Future<void>.delayed(const Duration(milliseconds: 180));
      });
      await settle();
      final saved = await tester.runAsync(
        () => CampaignJournalService(db).load(),
      );
      expect(saved!.ready.map((a) => a.id), isEmpty);
      await settle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
      await settle();
      // Nothing left to collect, so the ready band has gone.
      expect(find.text('COLLECT ALL'), findsNothing);
      expect(find.text('4 READY'), findsNothing);
      await capture(tester, key, 'achievements_after_collect');
      expect(
        saved.claimed,
        containsAll(['first_extraction', 'ship', 'revelation', 'survival_20']),
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pump();
    },
  );
  testWidgets('home reward badge updates after earning and claiming', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() => CampaignJournalService(db).load());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          ChangeNotifierProvider<TimedBoostService>(
            create: (_) => TimedBoostService(db.settingsDao)..load(),
          ),
          ChangeNotifierProvider<ShopService>(
            create: (ctx) => ShopService(
              db,
              ConstellationEffectsService(db),
              FactionService(db),
              ctx.read<TimedBoostService>(),
            ),
          ),
          // The badge takes its gold from the theme now, so that it stays
          // legible in light mode as well as dark.
          Provider<FactionTheme>.value(
            value: factionThemeFor(FactionId.oceanic),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: CampaignRewardsButton())),
      ),
    );
    Future<void> settleProgress() async {
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
    }

    // The badge counts open tasks as well as claimable rewards — a task
    // nobody is told about is a task nobody does — so a fresh save is
    // already showing the ungated ones before any achievement lands.
    final openTasks = kOnboardingTasks
        .where((t) => t.gate == TaskGate.always)
        .length;
    await settleProgress();
    expect(find.byTooltip('Achievements · $openTasks waiting'), findsOneWidget);
    await tester.runAsync(
      () => db.settingsDao.setSetting('first_extraction_done', '1'),
    );
    await settleProgress();
    expect(
      find.byTooltip('Achievements · ${openTasks + 1} waiting'),
      findsOneWidget,
      reason: 'the earned reward is added to the open tasks',
    );
    await tester.runAsync(
      () => CampaignJournalService(db).claim('first_extraction'),
    );
    await settleProgress();
    expect(
      find.byTooltip('Achievements · $openTasks waiting'),
      findsOneWidget,
      reason: 'claiming removes the reward and leaves the tasks',
    );
    await tester.runAsync(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pump();
  });
}
