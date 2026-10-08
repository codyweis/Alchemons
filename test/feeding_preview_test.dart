@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/navigation/emblem_passage.dart';
import 'package:alchemons/screens/feeding/feeding_screen.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/dock_emblems.dart';
import 'package:alchemons/widgets/dock_passages.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show SpecimenGrains;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dock_passage_stage.dart';
import 'enhance_harness.dart';

// The Enhance screen on a phone: the picker, the stage, two kin chosen and
// poured in, the orb tray and the soul tray; and the dock's way in, frame by
// frame (passage_*.png).
//
//   FEED_OUT=/tmp/feed flutter test test/feeding_preview_test.dart \
//     --tags preview
void main() {
  final out = Platform.environment['FEED_OUT'];

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
    await loadFont(
      'packages/phosphoricons_flutter/PhosphorBold',
      '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/'
          'phosphoricons_flutter-1.0.0/lib/fonts/Phosphor-Bold.ttf',
    );
  });

  // The dock's creature of grains standing up, coming apart into a band of
  // light and opening on the picker; and back.
  testWidgets('enhance passage', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final emblem = GlobalKey();
    final lifted = ValueNotifier(false);
    final h = await EnhanceHarness.pump(
      tester,
      home: (_) => DockStandIn(
        kind: DockEmblemKind.enhance,
        emblemKey: emblem,
        lifted: lifted,
        top: 520,
      ),
    );
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            EnhanceHarness.shotKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/passage_$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final creature = ValueNotifier<SpecimenGrains?>(null);
    await tester.runAsync(
      () async => creature.value = await DockEmblem.creatureGrains(fine: true),
    );
    final ready = ValueNotifier(false);
    final revealed = ValueNotifier(false);
    EmblemPassage.pushScene<void>(
      emblem.currentContext!,
      scene: EnhancePassage(creature: creature),
      from: emblem,
      page: FeedingScreen(revealReady: ready, revealed: revealed),
      ready: ready,
      revealed: revealed,
      lifted: lifted,
    );
    var n = 0;
    String tag(String s) => '${(n++).toString().padLeft(2, '0')}_$s';
    await shoot(tag('home'));
    for (var i = 0; i < 6; i++) {
      await h.settle(5);
      await shoot(tag('in'));
    }
    for (var i = 0; i < 10; i++) {
      await h.settle(4);
      await shoot(tag(ready.value ? 'land' : 'hold'));
    }
    await h.settle(30);
    await shoot(tag('page'));
    Navigator.of(emblem.currentContext!).pop();
    for (var i = 0; i < 8; i++) {
      await h.settle(4);
      await shoot(tag('back'));
    }
    await h.dispose();
  });

  // A card chosen: its creature runs out of it as grains and settles onto
  // the stage while the chamber rises round it (arrive_*.png).
  testWidgets('stage arrival', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final h = await EnhanceHarness.pump(tester);
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            EnhanceHarness.shotKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/arrive_$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    var n = 0;
    String tag(String s) => '${(n++).toString().padLeft(2, '0')}_$s';
    await shoot(tag('picker'));
    // A card low on the screen, so the current has somewhere to go.
    final pick = Platform.environment['ARRIVE_CARD'] ?? '4';
    await tester.tap(
      find.byType(InstanceSprite).hitTestable().at(int.parse(pick)),
      warnIfMissed: false,
    );
    for (var i = 0; i < 26; i++) {
      await h.settle(2);
      await shoot(tag('t'));
    }
    await h.settle(20);
    await shoot(tag('settled'));
    await h.dispose();
  });

  testWidgets('enhance preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final h = await EnhanceHarness.pump(tester);

    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            EnhanceHarness.shotKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await shoot('0_picker');
    await tester.enterText(find.byType(TextField), 'plant');
    await h.settle(15);
    await shoot('0b_search');

    // Straight onto the leveled Firehorn.
    await h.reopen(open: 'fh0');
    await shoot('1_stage');

    // The stage sprite is the first; kin cards follow in the tray.
    Future<void> tapSprite(int i) async {
      await tester.tap(
        find.byType(InstanceSprite).hitTestable().at(i),
        warnIfMissed: false,
      );
      await h.settle(20);
    }

    await tapSprite(1);
    await tapSprite(2);
    await shoot('2_kin_chosen');

    await tester.tap(find.textContaining('SACRIFICE'), warnIfMissed: false);
    for (final (frames, name) in [
      (6, '3_pour_a'),
      (12, '3_pour_b'),
      (10, '3_pour_c'),
      (14, '4_flash'),
      (12, '4_count'),
      (40, '5_after'),
    ]) {
      await h.settle(frames);
      await shoot(name);
    }

    await h.settle(30);
    await tester.tap(find.textContaining('ORBS'), warnIfMissed: false);
    await h.settle(20);
    await shoot('6_orbs');

    await tester.tap(find.textContaining('SOULS'), warnIfMissed: false);
    await h.settle(20);
    await tester.tap(find.text('STR').last, warnIfMissed: false);
    await h.settle(20);
    await shoot('7_souls');

    await h.dispose();
  });
}
