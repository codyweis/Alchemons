@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/models/faction.dart';
import 'package:alchemons/widgets/background/faction_realm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Each faction's realm at rest, stirred, and the grains flying between two.
// Prints what a frame costs.
//
//   REALM_OUT=/tmp/realm flutter test \
//     test/faction_realm_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['REALM_OUT'];

  testWidgets('faction realm preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final messenger = tester.binding.defaultBinaryMessenger;
    for (final channel in const [
      'dev.fluttercommunity.plus/sensors/method',
      'dev.fluttercommunity.plus/sensors/accelerometer',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async {
        return null;
      });
    }
    tester.view.physicalSize = const Size(1248, 2772);
    tester.view.devicePixelRatio = 1248 / 412;

    Future<void> shoot(GlobalKey key, String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1248 / 412 / 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    void cost(FactionRealmField f, String what) {
      final sw = Stopwatch()..start();
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      const reps = 30;
      for (var i = 0; i < reps; i++) {
        f.step(1 / 60);
        f.paint(canvas);
      }
      rec.endRecording().dispose();
      // ignore: avoid_print
      print(
        '$what: ${(sw.elapsedMicroseconds / reps).round()} µs/frame, '
        '${f.debugSprites} sprites, ${f.debugPictures} pictures, '
        '${f.grainCount} grains',
      );
    }

    for (final ink in [false, true]) {
      for (final id in FactionId.values) {
        final key = GlobalKey();
        final field = FactionRealmField(faction: id, ink: ink);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(
              key: key,
              child: FactionRealmView(faction: id, ink: ink, field: field),
            ),
          ),
        );
        await frames(200);
        final tag = '${ink ? 'ink_' : ''}${id.name}';
        await shoot(key, '${tag}_rest');
        if (!ink) cost(field, '$tag rest');
        // A finger dragged across the ground and up through the dust.
        final g = await tester.startGesture(const Offset(30, 640));
        for (var i = 0; i < 18; i++) {
          await g.moveBy(const Offset(20, -16));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await g.up();
        await frames(4);
        await shoot(key, '${tag}_stir');
        if (!ink) cost(field, '$tag stirred');
      }
    }

    // Volcanic into Oceanic, part way.
    for (final ink in [false, true]) {
      final key = GlobalKey();
      final field = FactionRealmField(ink: ink);
      Widget host(FactionId id) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: FactionRealmView(faction: id, ink: ink, field: field),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(host(FactionId.volcanic));
      await frames(60);
      await tester.pumpWidget(host(FactionId.oceanic));
      for (final (i, n) in [(0, 25), (1, 25), (2, 30)]) {
        await frames(n);
        await shoot(key, '${ink ? 'ink_' : ''}reform_$i');
      }
      if (!ink) cost(field, 'reform tail');
      await frames(120);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
