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

  test('the light page has its own pigments, and gives the dark back', () {
    for (final id in FactionId.values) {
      final f = FactionRealmField(faction: id)..layout(size);
      final dark = [for (var i = 0; i < f.grainCount; i++) f.debugColorOf(i)];
      f.ink = true;
      var changed = 0;
      for (var i = 0; i < f.grainCount; i++) {
        if (f.debugColorOf(i) != dark[i]) changed++;
      }
      expect(changed, greaterThan(f.grainCount * 0.9), reason: id.name);
      f.ink = false;
      for (var i = 0; i < f.grainCount; i++) {
        expect(f.debugColorOf(i), dark[i], reason: '${id.name} grain $i');
      }
      f.dispose();
    }
  });

  // On paper the ground has to be a body darker than the paper, not a few
  // specks: compare the foot of the page with its top.
  test('on the light page the ground reads darker than the paper', () async {
    for (final id in [
      FactionId.volcanic,
      FactionId.oceanic,
      FactionId.earthen,
    ]) {
      final f = FactionRealmField(faction: id, ink: true)..layout(size);
      frame(f, 30);
      final rec = ui.PictureRecorder();
      f.paint(Canvas(rec));
      final image = rec.endRecording().toImageSync(
        size.width.toInt(),
        size.height.toInt(),
      );
      final bytes = (await image.toByteData())!;
      double band(double from, double to) {
        var sum = 0.0, n = 0;
        final w = image.width;
        for (
          var y = (from * image.height).toInt();
          y < (to * image.height).toInt();
          y += 2
        ) {
          for (var x = 0; x < w; x += 2) {
            final o = (y * w + x) * 4;
            sum +=
                0.2126 * bytes.getUint8(o) +
                0.7152 * bytes.getUint8(o + 1) +
                0.0722 * bytes.getUint8(o + 2);
            n++;
          }
        }
        return sum / n / 255;
      }

      final paper = band(0.05, 0.2), ground = band(0.8, 0.95);
      expect(paper, greaterThan(0.85), reason: id.name);
      expect(ground, lessThan(paper - 0.12), reason: id.name);
      image.dispose();
      f.dispose();
    }
  });

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
