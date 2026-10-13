import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/poi_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The lore notes are scattered back through open space (the author,
// 2026-10-12), each where it lay before the contests were retired.
//
//   LORE_OUT=/tmp/lore.png flutter test test/lore_notes_test.dart
void main() {
  test('every world scatters every note, apart and clear of landmarks', () {
    for (final seed in [1, 37, 1234]) {
      final world = CosmicWorld.generate(seed: seed);
      final notes = world.loreNotes;
      expect(notes.length, kCosmicContestHintLore.length);
      expect(notes.map((n) => n.id).toSet().length, notes.length);
      for (var i = 0; i < notes.length; i++) {
        for (var j = i + 1; j < notes.length; j++) {
          expect(
            (notes[i].position - notes[j].position).distance,
            greaterThan(1100),
          );
        }
        for (final p in world.planets) {
          expect((p.position - notes[i].position).distance, greaterThan(1400));
        }
      }
      // The same seed, the same places.
      final again = CosmicWorld.generate(seed: seed).loreNotes;
      expect(
        [for (final n in again) n.position],
        [for (final n in notes) n.position],
      );
    }
  });

  test('a note taken stays taken through its saved form', () {
    final ids = {'fast_family_wing', 'contest_no_luck'};
    expect(deserialiseContestHintIds(serialiseContestHintIds(ids)), ids);
    expect(deserialiseContestHintIds(''), isEmpty);
  });

  test('the note art draws', () async {
    final out = Platform.environment['LORE_OUT'];
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(
      const Rect.fromLTWH(0, 0, 480, 140),
      Paint()..color = const Color(0xFF050507),
    );
    for (var i = 0; i < 4; i++) {
      paintLoreNote(
        c,
        at: Offset(70 + i * 110.0, 80),
        t: 1.0 + i * 0.9,
        seed: 9 + i,
      );
    }
    final img = rec.endRecording().toImageSync(480, 140);
    if (out != null) {
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(png!.buffer.asUint8List());
    }
    img.dispose();
  });
}
