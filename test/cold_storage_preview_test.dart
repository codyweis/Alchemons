@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/cold_storage_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/nursery/storage_section_widget.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Cold storage's stasis rack on a phone, on both themes: a part-full rack
// with one vial ready, a faction filter, an empty rack, the largest rack,
// and a vial's details.
//
//   COLD_OUT=/tmp/cold flutter test \
//     test/cold_storage_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['COLD_OUT'];

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
  });

  // The nursery's section heading, as nursery_tab draws it.
  Widget header(
    BuildContext context,
    String title,
    IconData _,
    Color color, {
    Widget? trailing,
  }) {
    final palette = BracketPalette.of(context);
    return Row(
      children: [
        Container(width: 3, height: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title[0] + title.substring(1).toLowerCase(),
          style: bracketText(
            context,
            13,
            palette.ink,
            weight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: palette.lineSoft)),
        if (trailing != null) ...[const SizedBox(width: 10), trailing],
      ],
    );
  }

  testWidgets('cold storage preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(390 * 3, 700 * 3);
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

    Future<void> settle([int frames = 10]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    const stock = [
      ('volcanic', 'Rare', 30.0, false),
      ('oceanic', 'Common', 2.5, false),
      ('verdant', 'Uncommon', 0.0, true),
      ('arcane', 'Legendary', 70.0, false),
      ('earthen', 'Rare', 12.0, false),
      ('oceanic', 'Uncommon', 18.0, false),
      ('volcanic', 'Common', 0.6, false),
    ];

    Future<AlchemonsDatabase> rack(int capacity, int stored) async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await db.settingsDao.setSetting(
          ColdStorageService.capacitySettingKey,
          '$capacity',
        );
        for (var i = 0; i < stored; i++) {
          final (faction, rarity, hours, ready) = stock[i % stock.length];
          await db.incubatorDao.enqueueEgg(
            eggId: 'egg$i',
            resultCreatureId: 'HOR01',
            rarity: rarity,
            remaining: Duration(minutes: ready ? 0 : (hours * 60).round()),
            payloadJson: jsonEncode({
              'lineage': {'nativeFaction': faction},
            }),
          );
        }
      });
      return db;
    }

    Future<void> show(AlchemonsDatabase db, {required bool dark}) async {
      final theme = dark
          ? FactionTheme.scorchForge()
          : factionThemeFor(null, brightness: Brightness.light);
      final palette = BracketPalette.fromTheme(theme);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            Provider<FactionTheme>.value(value: theme),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            builder: (context, child) =>
                RepaintBoundary(key: key, child: child!),
            home: Scaffold(
              backgroundColor: palette.bg0,
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Builder(
                  builder: (context) => StorageSection(
                    primaryColor: theme.text,
                    quality: CinematicQuality.cinematic,
                    canAutoMove: true,
                    buildSectionHeader:
                        (title, icon, color, {Widget? trailing}) => header(
                          context,
                          title,
                          icon,
                          color,
                          trailing: trailing,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await settle();
    }

    for (final dark in [true, false]) {
      final tag = dark ? 'dark' : 'light';
      final db = await rack(10, 7);
      await show(db, dark: dark);
      await shoot('1_rack_$tag');

      if (dark) {
        await tester.tap(find.text('Oceanic'));
        await settle();
        await shoot('2_filter_$tag');

        await tester.tap(find.text('All'));
        await settle();
        await tester.tap(find.text('READY'));
        await settle(14);
        await shoot('3_details_$tag');
        await tester.tap(find.text('Delete specimen'));
        await settle();
        await shoot('4_delete_$tag');
      }
      await tester.runAsync(db.close);
    }

    for (final dark in [true, false]) {
      final tag = dark ? 'dark' : 'light';
      final empty = await rack(5, 0);
      await show(empty, dark: dark);
      await shoot('5_empty_$tag');
      await tester.runAsync(empty.close);
    }

    final full = await rack(20, 18);
    await show(full, dark: true);
    await shoot('6_largest_dark');
    await tester.runAsync(full.close);

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  });
}
