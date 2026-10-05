@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/breed/nursery_tab.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The nursery's Active cultivation chambers on a phone: a new player's two
// empty chambers, then a mix of cultivating, ready and empty ones.
//
//   NURSERY_OUT=/tmp/nursery flutter test \
//     test/nursery_chambers_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['NURSERY_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
  });

  testWidgets('nursery chambers preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(390 * 3, 760 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

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

    Future<void> settle([int frames = 12]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    Map<String, dynamic> parent(String id, String image, String type) => {
      'baseId': id,
      'name': id,
      'types': [type],
      'rarity': 'Rare',
      'image': image,
    };

    Future<AlchemonsDatabase> chambers({
      required bool mixed,
      bool withReady = true,
    }) async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        if (!mixed) {
          await db.incubatorDao.watchSlots().first;
          return;
        }
        await db.incubatorDao.purchaseFusionSlot();
        await db.incubatorDao.purchaseFusionSlot();
        await db.incubatorDao.placeEgg(
          slotId: 0,
          eggId: 'egg0',
          resultCreatureId: 'HOR01',
          rarity: 'rare',
          hatchAtUtc: DateTime.now().toUtc().add(const Duration(hours: 3)),
          payloadJson: jsonEncode({
            'parentage': {
              'parentA': parent(
                'HOR01',
                'creatures/rare/HOR01_firehorn.png',
                'Fire',
              ),
              'parentB': parent(
                'LET02',
                'creatures/common/LET02_waterlet.png',
                'Water',
              ),
            },
          }),
        );
        if (!withReady) return;
        await db.incubatorDao.placeEgg(
          slotId: 2,
          eggId: 'egg1',
          resultCreatureId: 'LET02',
          rarity: 'common',
          hatchAtUtc: DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          ),
        );
      });
      return db;
    }

    Future<void> show(AlchemonsDatabase db) async {
      final theme = FactionTheme.scorchForge();
      final palette = BracketPalette.fromTheme(theme);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            Provider<FactionTheme>.value(value: theme),
            ChangeNotifierProvider<ConstellationEffectsService>.value(
              value: ConstellationEffectsService(db),
            ),
            ChangeNotifierProvider<FactionService>(
              create: (_) => FactionService(db),
            ),
            ChangeNotifierProvider<TimedBoostService>(
              create: (_) => TimedBoostService(db.settingsDao),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            builder: (context, child) =>
                RepaintBoundary(key: key, child: child!),
            home: Scaffold(
              backgroundColor: palette.bg0,
              body: NurseryTab(
                onHatchComplete: () {},
                onRequestAddEgg: () {},
                onRequestFusion: () {},
              ),
            ),
          ),
        ),
      );
      await settle();
    }

    final fresh = await chambers(mixed: false);
    await show(fresh);
    await shoot('1_new_player');
    await settle(20);
    await shoot('1b_new_player_later');

    final mixed = await chambers(mixed: true);
    await show(mixed);
    await settle(10);
    await shoot('2_mixed');

    final waiting = await chambers(mixed: true, withReady: false);
    await show(waiting);
    await shoot('3_one_cultivating');

    // Two ready (EXTRACT ALL shows), then each chamber's details.
    DebugSettingsService.enabledNotifier.value = true;
    final twoReady = await chambers(mixed: true);
    await tester.runAsync(
      () => twoReady.incubatorDao.placeEgg(
        slotId: 3,
        eggId: 'egg3',
        resultCreatureId: 'PIP01',
        rarity: 'uncommon',
        hatchAtUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      ),
    );
    await tester.runAsync(
      () => twoReady.settingsDao.setSetting('first_extraction_done', '1'),
    );
    await show(twoReady);
    await shoot('4_two_ready');

    Future<void> openChamber(int index, String name) async {
      final cells = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key as ValueKey).value}'.startsWith('slot-'),
      );
      await tester.tap(cells.at(index), warnIfMissed: false);
      await settle(16);
      await shoot(name);
    }

    await openChamber(0, '5_details_cultivating');
    final accel = find.text('ACCELERATE');
    if (accel.evaluate().isNotEmpty) {
      await tester.tap(accel.first, warnIfMissed: false);
      await settle(14);
      await shoot('6_accelerate');
      final cancel = find.text('CANCEL');
      if (cancel.evaluate().isNotEmpty) {
        await tester.tap(cancel.first, warnIfMissed: false);
        await settle(10);
      }
    }
    final close = find.byTooltip('Close');
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first, warnIfMissed: false);
      await settle(10);
    }
    await openChamber(1, '7_details_ready');
    final discard = find.byTooltip('Discard specimen');
    if (discard.evaluate().isNotEmpty) {
      await tester.tap(discard.first, warnIfMissed: false);
      await settle(12);
      await shoot('8_discard');
      await tester.tap(find.text('CANCEL').first, warnIfMissed: false);
      await settle(8);
    } else {
      final closeReady = find.byTooltip('Close');
      if (closeReady.evaluate().isNotEmpty) {
        await tester.tap(closeReady.first, warnIfMissed: false);
        await settle(8);
      }
    }
    final all = find.textContaining('EXTRACT ALL');
    if (all.evaluate().isNotEmpty) {
      await tester.tap(all.first, warnIfMissed: false);
      await settle(12);
      await shoot('9_extract_all_confirm');
      await tester.tap(find.text('CANCEL').first, warnIfMissed: false);
      await settle(8);
    }
    DebugSettingsService.enabledNotifier.value = false;

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.runAsync(() async {
      await fresh.close();
      await mixed.close();
      await waiting.close();
      await twoReady.close();
    });
  });
}
