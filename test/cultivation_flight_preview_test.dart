@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/breed/nursery_tab.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
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

// A chamber opened: its sphere flies up out of the card onto the details
// stage, frame by frame, as one contact sheet.
//
//   FLIGHT_OUT=/tmp/flight.png flutter test \
//     test/cultivation_flight_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['FLIGHT_OUT'];

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

  testWidgets('cultivation flight preview', (tester) async {
    if (out == null) return;
    tester.view.physicalSize = const Size(390 * 2, 760 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    final frames = <(String, ui.Image)>[];
    Future<void> shoot(String label) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        frames.add((label, await boundary.toImage(pixelRatio: 1)));
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

    final ready = Platform.environment['FLIGHT_READY'] == '1';
    final db = AlchemonsDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      await db.incubatorDao.purchaseFusionSlot();
      await db.incubatorDao.placeEgg(
        slotId: 1,
        eggId: 'egg0',
        resultCreatureId: 'HOR01',
        rarity: 'rare',
        hatchAtUtc: ready
            ? DateTime.now().toUtc().subtract(const Duration(minutes: 1))
            : DateTime.now().toUtc().add(const Duration(minutes: 20)),
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
      await db.settingsDao.setSetting('first_extraction_done', '1');
    });

    final theme = FactionTheme.scorchForge();
    final palette = BracketPalette.fromTheme(theme);
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
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
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
    await settle(20);
    await shoot('before');

    final cell = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('slot-'),
    );
    await tester.tap(cell.first, warnIfMissed: false);
    // The extraction dialog checks its tutorial flag before it opens.
    if (ready) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
    }
    var ms = 0;
    for (var i = 0; i <= 33; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      ms += 33;
      if (i <= 2 || i % 3 == 0) await shoot('${ms}ms');
    }

    await tester.runAsync(() async {
      const cols = 6;
      final w = 390.0, h = 760.0, gap = 6.0;
      final rows = (frames.length / cols).ceil();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(
        Rect.fromLTWH(0, 0, cols * (w + gap), rows * (h + gap + 24)),
        Paint()..color = const Color(0xFF202020),
      );
      for (var i = 0; i < frames.length; i++) {
        final (label, img) = frames[i];
        final o = Offset((i % cols) * (w + gap), (i ~/ cols) * (h + gap + 24));
        c.drawImage(img, o + const Offset(0, 24), Paint());
        final pb = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 18))
          ..pushStyle(ui.TextStyle(color: const Color(0xFFFFFFFF)))
          ..addText(label);
        final p = pb.build()..layout(const ui.ParagraphConstraints(width: 300));
        c.drawParagraph(p, o + const Offset(6, 2));
      }
      final img = rec.endRecording().toImageSync(
        (cols * (w + gap)).round(),
        (rows * (h + gap + 24)).round(),
      );
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.runAsync(() => db.close());
  });
}
