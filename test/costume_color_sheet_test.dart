// A costume's colour step: shown on the creature, a preset or a turn of the
// ring picks it, and backing out picks nothing — for a Wing's hat and a
// Pip's nose.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/costume/costume_color_sheet.dart';
import 'package:alchemons/widgets/fx/costume_paint.dart';
import 'package:drift/native.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late CreatureCatalog catalog;
  late CreatureInstance wing;
  late CreatureInstance pip;

  testWidgets('a preset, the ring and backing out', (tester) async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() async {
      final entries =
          (jsonDecode(
                    File(
                      'assets/data/alchemons_creatures.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['creatures']
              as List;
      catalog = CreatureCatalog.fromList([
        for (final e in entries.cast<Map<String, dynamic>>())
          if (e['id'] == 'WNG04' || e['id'] == 'PIP01') Creature.fromJson(e),
      ]);
      await db.creatureDao.insertInstance(instanceId: 'w', baseId: 'WNG04');
      wing = (await db.creatureDao.getInstance('w'))!;
      await db.creatureDao.insertInstance(instanceId: 'p', baseId: 'PIP01');
      pip = (await db.creatureDao.getInstance('p'))!;
      for (final id in ['WNG04', 'PIP01']) {
        final sheet = catalog.getCreatureById(id)!.spriteData!.spriteSheetPath;
        final codec = await ui.instantiateImageCodec(
          File('assets/images/$sheet').readAsBytesSync(),
        );
        Flame.images.add(sheet, (await codec.getNextFrame()).image);
      }
    });
    addTearDown(Flame.images.clearCache);
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late BuildContext ctx;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
          Provider<CreatureCatalog>.value(value: catalog),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    Future<(bool, Color?)> ask(
      Future<void> Function() act, {
      FamilyCostume costume = FamilyCostume.partyHat,
    }) async {
      var done = false;
      Color? picked;
      final noun = costume.noun.toUpperCase();
      pickCostumeColor(
        ctx,
        instance: costume == FamilyCostume.nose ? pip : wing,
        costume: costume,
        confirmLabel: 'WEAR $noun',
      ).then((c) {
        picked = c;
        done = true;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('$noun COLOUR'), findsOneWidget);
      // Shown on the creature, wearing it.
      expect(find.byType(WornCostume), findsOneWidget);
      await act();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return (done, picked);
    }

    // A preset, then wear it.
    const ruby = Color(0xFF8A2338);
    var (done, picked) = await ask(() async {
      await tester.tap(find.byKey(const ValueKey(ruby)));
      await tester.pump();
      await tester.tap(find.text('WEAR HAT'));
    });
    expect(done, true);
    expect(picked, ruby);

    // A drag round the ring from its top (red) to its bottom (cyan-ish).
    (done, picked) = await ask(() async {
      final centre = tester.getCenter(find.byKey(CostumeColorSheet.ringKey));
      final gesture = await tester.startGesture(centre + const Offset(0, -136));
      await gesture.moveTo(centre + const Offset(136, 0));
      await gesture.moveTo(centre + const Offset(0, 136));
      await gesture.up();
      await tester.pump();
      await tester.tap(find.text('WEAR HAT'));
    });
    expect(done, true);
    expect(
      HSVColor.fromColor(picked!).hue,
      closeTo(180, 6),
      reason: 'the bottom of the ring is half way round from red',
    );
    expect(picked, isNot(FamilyCostume.partyHat.defaultColor));

    // Backing out picks nothing.
    (done, picked) = await ask(() async {
      await tester.tap(find.text('CANCEL'));
    });
    expect(done, true);
    expect(picked, isNull);

    // A Pip's nose: its own presets, its own ring, a Pip to show it on.
    const teal = Color(0xFF1FB5B0);
    (done, picked) = await ask(costume: FamilyCostume.nose, () async {
      // The nose's presets, not the hat's.
      expect(
        find.byKey(ValueKey(FamilyCostume.nose.defaultColor)),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey(FamilyCostume.partyHat.defaultColor)),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey(teal)));
      await tester.pump();
      await tester.tap(find.text('WEAR NOSE'));
    });
    expect(done, true);
    expect(picked, teal);
    (done, picked) = await ask(costume: FamilyCostume.nose, () async {
      final centre = tester.getCenter(find.byKey(CostumeColorSheet.ringKey));
      final gesture = await tester.startGesture(centre + const Offset(0, -136));
      await gesture.moveTo(centre + const Offset(136, 0));
      await gesture.up();
      await tester.pump();
      await tester.tap(find.text('WEAR NOSE'));
    });
    expect(done, true);
    final hsv = HSVColor.fromColor(picked!);
    expect(hsv.hue, closeTo(90, 6), reason: 'a quarter of the way round');
    expect(hsv.value, closeTo(FamilyCostume.nose.ringValue, 0.01));
  });
}
