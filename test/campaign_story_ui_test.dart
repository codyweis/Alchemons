import 'dart:io';
import 'dart:ui' as ui;
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/story/beauty_mask_reveal.dart';
import 'package:alchemons/screens/story/campaign_journal_screen.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/widgets/campaign_rewards_button.dart';
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
    'revelation waits for taps, dissolves, then waits to acknowledge',
    (tester) async {
      tester.view.physicalSize = const Size(900, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      await tester.runAsync(
        () => Future.wait([
          for (final layer in [
            'sky',
            'clouds',
            'backhills',
            'hills',
            'foreground',
          ])
            precacheImage(
              AssetImage('assets/images/backgrounds/scenes/valley/$layer.png'),
              key.currentContext!,
            ),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Look closer'), findsOneWidget);
      expect(completed, 0);
      await capture(tester, key, 'valley_before');
      await tester.tap(find.text('Look closer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));
      await capture(tester, key, 'valley_dissolving');
      await tester.pumpAndSettle();
      expect(find.text('No, I am finally awake.'), findsOneWidget);
      expect(completed, 0);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('A memory speaks'), findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      expect(completed, 0);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
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
          CampaignJournalService.revelationKey,
          '1',
        );
        await CampaignJournalService(db).recordSurvivalClear(20);
        await CampaignJournalService(db).load();
      });
      final key = GlobalKey();
      await tester.pumpWidget(
        Provider.value(
          value: db,
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
      await tester.pumpAndSettle();
      expect(find.text('Achievements'), findsOneWidget);
      expect(find.text('What remained'), findsOneWidget);
      expect(find.text('4 rewards ready'), findsOneWidget);
      await capture(tester, key, 'achievements_home');
      await tester.tap(find.text('Story progress'));
      await tester.pumpAndSettle();
      expect(find.text('Your main story'), findsOneWidget);
      await capture(tester, key, 'achievements_story');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Memories'));
      await tester.pumpAndSettle();
      await capture(tester, key, 'achievements_memories');
      await tester.pageBack();
      await tester.pumpAndSettle();
      final collectAll = find.widgetWithText(
        FilledButton,
        'Collect all · 8 Gold + 850 Silver',
      );
      await tester.ensureVisible(collectAll);
      await tester.runAsync(() async {
        await tester.tap(collectAll);
        await Future<void>.delayed(const Duration(milliseconds: 180));
      });
      await tester.pumpAndSettle();
      final saved = await tester.runAsync(
        () => CampaignJournalService(db).load(),
      );
      expect(saved!.ready.map((a) => a.id), isEmpty);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
      await tester.pumpAndSettle();
      expect(find.text('All rewards collected'), findsOneWidget);
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
      Provider.value(
        value: db,
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

    await settleProgress();
    expect(find.byTooltip('Achievements'), findsOneWidget);
    await tester.runAsync(
      () => db.settingsDao.setSetting('first_extraction_done', '1'),
    );
    await settleProgress();
    expect(find.byTooltip('Achievements · 1 rewards ready'), findsOneWidget);
    await tester.runAsync(
      () => CampaignJournalService(db).claim('first_extraction'),
    );
    await settleProgress();
    expect(find.byTooltip('Achievements'), findsOneWidget);
    await tester.runAsync(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pump();
  });
}
