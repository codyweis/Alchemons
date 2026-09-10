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

  test('collecting matter stays quiet but can still claim a voice', () {
    // It fires more often than anything else in the game, so it is quiet
    // and rate-limited — but NOT priority 0. The mixer only evicts a voice
    // whose priority is strictly lower than the incoming cue's, so a 0 can
    // never take a slot: in a busy scene it simply stopped being audible.
    const cue = SoundCue.cosmicMatterCollect;
    expect(cue.priority, greaterThan(0), reason: 'a 0 can evict nothing');
    expect(cue.gain, lessThan(SoundCue.cosmicOrbPickup.gain));
    expect(cue.cooldownMs, greaterThanOrEqualTo(60));
    expect(cue.hasVariants, isTrue, reason: 'or a mote field machine-guns');
  });

  test('nothing at priority 0 expects to be heard in a crowd', () {
    // Documenting the mixer's rule where someone will see it: everything
    // here is a texture that may simply vanish under load.
    final droppable = SoundCue.values.where((c) => c.priority == 0).toSet();
    expect(droppable, {
      SoundCue.combatProjectile,
      SoundCue.combatHitLight,
      SoundCue.combatHitHeavy,
      SoundCue.combatEnemyDefeat,
      SoundCue.cosmicOrbPickup,
      SoundCue.dungeonStepStone,
      SoundCue.dungeonStepWater,
    });
  });
}
