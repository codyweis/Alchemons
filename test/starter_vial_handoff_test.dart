import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/background/faction_realm.dart';
import 'package:alchemons/widgets/fx/starter_vial_handoff.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// The faction → first chamber handoff. Frames for a look:
//
//   HANDOFF_OUT=/tmp/handoff flutter test test/starter_vial_handoff_test.dart
void main() {
  const vial = ExtractionVial(
    price: null,
    id: 'starter_volcanic',
    name: 'STARTER VIAL',
    group: ElementalGroup.volcanic,
    rarity: VialRarity.uncommon,
    quantity: 1,
  );

  final rootKey = GlobalKey();
  final chamberKey = GlobalKey();
  late BuildContext appContext;

  Widget app() => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    builder: (context, child) => RepaintBoundary(key: rootKey, child: child!),
    home: Builder(
      builder: (context) {
        appContext = context;
        return Scaffold(
          backgroundColor: const Color(0xFF0E1117),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 120, 16, 0),
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                key: chamberKey,
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: const Color(0xFF384150)),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  void begin() {
    StarterVialHandoff.instance.chamberKey = chamberKey;
    StarterVialHandoff.instance.markShellWarming();
    StarterVialHandoff.instance.begin(
      appContext,
      faction: FactionId.volcanic,
      ink: false,
      field: FactionRealmField(faction: FactionId.volcanic),
      vial: vial,
      orbRect: const Rect.fromLTWH(141, 60, 108, 108),
      grainColors: const [
        Color(0xFFFF6B35),
        Color(0xFFFFAA64),
        Color(0xFFE8DCC8),
      ],
    );
  }

  Future<void> run(WidgetTester tester, double seconds) async {
    final frames = (seconds / 0.05).round();
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('lands in the chamber and takes itself away', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    begin();
    await tester.pump();
    expect(StarterVialHandoff.instance.active, isTrue);

    // Asked to land, but the shell is still warming: it holds.
    StarterVialHandoff.instance.land();
    await run(tester, 2);
    expect(StarterVialHandoff.instance.active, isTrue);

    StarterVialHandoff.instance.markShellReady();
    await run(tester, 1.6);
    expect(StarterVialHandoff.instance.active, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('fades out on its own when no vial is coming', (tester) async {
    await tester.pumpWidget(app());
    begin();
    await tester.pump();
    StarterVialHandoff.instance.cancel();
    await run(tester, 2.6);
    expect(StarterVialHandoff.instance.active, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('handoff preview', (tester) async {
    final out = Platform.environment['HANDOFF_OUT'];
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            rootKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> runReal(double seconds) async {
      final frames = (seconds / 0.05).round();
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 4)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await tester.pumpWidget(app());
    begin();
    await runReal(0.35);
    await shoot('1_gather_early');
    await runReal(0.5);
    await shoot('2_gather_mid');
    await runReal(1.0);
    await shoot('3_hold');
    StarterVialHandoff.instance.land();
    StarterVialHandoff.instance.markShellReady();
    await runReal(0.45);
    await shoot('4_landing');
    await runReal(0.4);
    await shoot('5_landing_late');
    await runReal(1);
    await shoot('6_after');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
