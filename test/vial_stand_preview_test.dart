@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/screens/essence/vial_stand.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'extraction_hub_harness.dart';

// The Essence screen's vial stand, from the socket to a vial drawn out, on
// the harness's phone. Each frame is 33 ms of the screen's clock:
//
//   STAND_OUT=/tmp/stand flutter test \
//     test/vial_stand_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['STAND_OUT'];

  setUp(muteNotifications);

  testWidgets('vial stand preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final h = await HubHarness.pump(tester);
    await tester.runAsync(() async {
      await loadNatures();
      await h.db.inventoryDao.addVial(
        'Volcanic Vial',
        ElementalGroup.volcanic,
        VialRarity.common,
        qty: 2,
      );
      await h.db.inventoryDao.addVial(
        'Volcanic Vial',
        ElementalGroup.volcanic,
        VialRarity.uncommon,
      );
      await h.db.currencyDao.addResource('res_volcanic', 20000);
    });
    await h.select(0);
    await h.settle(30);

    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            h.shotKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await shoot('00_socket');
    await tester.tap(find.byType(VialStandSocket).first);
    await h.settle(8);
    await shoot('01_passage');
    await h.settle(30);
    await shoot('02_choose');
    await tester.tap(find.text('SET').first);
    await h.settle(10);
    await shoot('03_setting');
    await h.settle(30);
    await shoot('04_set');

    // NATURE: the pour, then the picks rising into words.
    await tester.tap(find.textContaining('POUR'));
    await h.settle(12);
    await shoot('05_pour_early');
    await h.settle(18);
    await shoot('06_pour_mid');
    await h.settle(34);
    await shoot('07_reveal_leaving');
    await h.settle(22);
    await shoot('08_reveal_words');
    await h.settle(50);
    await shoot('09_natures');

    // Taken: one runs into its slot, the other back into the vial.
    await tester.tap(find.text('TAKE').first);
    await h.settle(10);
    await shoot('10_take_flow');
    await h.settle(40);
    await shoot('11_taken');

    // TINT, then SIZE, straight through.
    await tester.tap(find.textContaining('POUR'));
    await h.settle(140);
    await shoot('12_tints');
    await tester.tap(find.text('TAKE').last);
    await h.settle(50);
    await tester.tap(find.textContaining('POUR'));
    await h.settle(140);
    await shoot('13_size');
    await tester.tap(find.text('KEEP'));
    await h.settle(50);
    await shoot('14_extract');

    // Back to the chamber, and in again, with a vial on the stand.
    await tester.tap(find.byType(BracketIconButton).last);
    await h.settle(7);
    await shoot('15_back_mid');
    await h.settle(30);
    await shoot('16_home');
    await tester.tap(find.byType(VialStandSocket).first);
    await h.settle(9);
    await shoot('17_in_mid');
    await h.settle(30);
    await shoot('18_in');

    // Drawn out: the last measure flows in and the vial spirals away.
    await tester.tap(find.textContaining('EXTRACT  ·'));
    await h.settle(40);
    await shoot('19_extract_pour');
    await h.settle(36);
    await shoot('20_drawn_out');
    await h.settle(50);
    await shoot('21_after');

    await h.dispose();
    unmuteNotifications();
  });
}
