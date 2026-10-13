@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/screens/stadium/cup_shelf.dart';
import 'package:alchemons/screens/stadium/stadium_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The Trials' shelf as a cup is chosen: copper → silver → gold → copper,
// frame by frame; and the whole hub as it is (SHELF_OUT/hub).
//
//   SHELF_OUT=/tmp/shelf flutter test test/cup_shelf_preview_test.dart \
//     --tags preview
void main() {
  final out = Platform.environment['SHELF_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    if (out == null) return;
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
  });

  testWidgets('choosing a cup', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    // The Fold's cover screen, less the hub's gutters.
    const size = Size(443, 195);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final progress = RaceProgress({
      kRaceCups[0].id: 3,
      kRaceCups[1].id: 2,
      kRaceCups[2].id: 1,
    });
    final shot = GlobalKey();
    var selected = 0;
    late StateSetter setOuter;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: shot,
          child: ColoredBox(
            color: const Color(0xFF09090B),
            child: StatefulBuilder(
              builder: (context, set) {
                setOuter = set;
                return CupShelf(
                  cups: ShelfCup.races(progress),
                  selected: selected,
                  onSelect: (i) => set(() => selected = i),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    var frame = 0;
    Future<void> snap() async {
      await tester.runAsync(() async {
        final b =
            shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 2);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/${(frame++).toString().padLeft(3, '0')}.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
    }

    for (final next in [1, 2, 0]) {
      setOuter(() => selected = next);
      for (var t = 0; t < 1400; t += 40) {
        await tester.pump(const Duration(milliseconds: 40));
        await snap();
      }
    }
  });

  testWidgets('choosing a cup on the hub', (tester) async {
    if (out == null) return;
    final dir = '$out/hub';
    Directory(dir).createSync(recursive: true);
    SharedPreferences.setMockInitialValues({
      RaceProgress.prefsKey: '{"copper":3,"silver":3,"gold":1}',
    });
    const size = Size(475, 751);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final shot = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        builder: (context, child) => RepaintBoundary(key: shot, child: child!),
        home: const StadiumScreen(),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 33));
    }
    var frame = 0;
    Future<void> snap() async {
      await tester.runAsync(() async {
        final b =
            shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$dir/${(frame++).toString().padLeft(3, '0')}.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
    }

    final shelf = find.byType(CupShelf);
    for (final at in [.12, .5, .88]) {
      await tester.tapAt(
        tester.getTopLeft(shelf) + Offset(tester.getSize(shelf).width * at, 80),
      );
      for (var t = 0; t < 1200; t += 60) {
        await tester.pump(const Duration(milliseconds: 60));
        await snap();
      }
    }
  });
}
