// Every cue has to point at a file that exists.
//
// Cues are declared by asset path and the player loads that path blindly, so
// a typo or a missing variant is silent at compile time and only shows up as
// a sound that never plays. Variants are the easy one to get wrong: opting a
// cue into `hasVariants` promises three more files nobody thinks to render.

import 'dart:io';

import 'package:alchemons/audio/sound_cue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every cue asset is on disk', () {
    final missing = <String>[];
    for (final cue in SoundCue.values) {
      if (!File(cue.asset).existsSync()) missing.add('${cue.name}: ${cue.asset}');
    }
    expect(missing, isEmpty);
  });

  test('every cue that claims variants has all three', () {
    final missing = <String>[];
    for (final cue in SoundCue.values.where((c) => c.hasVariants)) {
      for (var i = 1; i <= 3; i++) {
        final asset = cue.assetForVariant(i);
        expect(
          asset,
          isNot(cue.asset),
          reason: '${cue.name} variant $i resolved to the canonical file',
        );
        if (!File(asset).existsSync()) missing.add('${cue.name}: $asset');
      }
    }
    expect(missing, isEmpty);
  });

  test('a cue without variants always resolves to itself', () {
    for (final cue in SoundCue.values.where((c) => !c.hasVariants)) {
      for (var i = 0; i <= 4; i++) {
        expect(cue.assetForVariant(i), cue.asset, reason: cue.name);
      }
    }
  });

  test('collecting matter is quieter and lower priority than the music', () {
    // It fires many times more often than anything else in the game; if it
    // ever gets promoted, it will be the loudest thing in cosmic space.
    const cue = SoundCue.cosmicMatterCollect;
    expect(cue.priority, 0, reason: 'must be the first thing dropped');
    expect(cue.gain, lessThan(SoundCue.cosmicOrbPickup.gain));
    expect(cue.cooldownMs, greaterThanOrEqualTo(60));
    expect(cue.hasVariants, isTrue, reason: 'or a mote field machine-guns');
  });
}
