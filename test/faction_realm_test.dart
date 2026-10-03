import 'dart:ui' as ui;

import 'package:alchemons/models/faction.dart';
import 'package:alchemons/widgets/background/faction_realm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(412, 915);

  void frame(FactionRealmField f, [int n = 1]) {
    for (var i = 0; i < n; i++) {
      f.step(1 / 60);
      final rec = ui.PictureRecorder();
      f.paint(Canvas(rec));
      rec.endRecording().dispose();
    }
  }

  for (final id in FactionId.values) {
    test('${id.name}: rests as one picture, stirs, settles back', () {
      final f = FactionRealmField(faction: id)..layout(size);
      frame(f, 30);
      expect(f.debugPictures, 1);
      // What breathes and flies stays a few thousand sprites.
      expect(f.debugSprites, lessThan(3500));
      final atRest = f.debugSprites;

      for (var i = 0; i < 10; i++) {
        f.stir(
          Offset(60 + i * 25.0, 700 - i * 20.0),
          const Offset(25, -20),
          1 / 60,
        );
        frame(f);
      }
      expect(f.debugSprites, greaterThan(atRest));
      expect(f.debugPictures, greaterThan(1));

      frame(f, 300);
      expect(f.debugPictures, 1);
      f.dispose();
    });
  }

  test('a new faction flies the same grains into the new realm', () {
    final f = FactionRealmField()..layout(size);
    frame(f, 10);
    final n = f.grainCount;
    for (final id in [
      FactionId.oceanic,
      FactionId.verdant,
      FactionId.earthen,
    ]) {
      f.faction = id;
      expect(f.reforming, isTrue);
      frame(f, 40);
      // Changed again mid-flight: picks up from where the grains are.
      f.faction = FactionId.volcanic;
      f.faction = id;
      frame(f, 140);
      expect(f.reforming, isFalse);
      expect(f.grainCount, n);
      expect(f.debugPictures, 1);
    }
    f.dispose();
  });

  testWidgets('a drag over the view stirs the grains', (
    tester,
  ) async {
    final field = FactionRealmField(faction: FactionId.earthen);
    await tester.pumpWidget(
      MaterialApp(
        home: FactionRealmView(faction: FactionId.earthen, field: field),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    final g = await tester.startGesture(const Offset(100, 420));
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(18, -10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 16));
    expect(field.debugPictures, greaterThan(1));
    await tester.pumpWidget(const SizedBox());
  });
}
