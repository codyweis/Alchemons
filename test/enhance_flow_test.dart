import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/stage_arrival.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'enhance_harness.dart';

class _RecordingAudio extends Fake implements AudioController {
  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  int soundEventSerial = 0;

  final sounds = <SoundCue>[];

  @override
  Future<void> playSound(
    SoundCue cue, {
    Object? owner,
    double speed = 1,
  }) async {
    soundEventSerial++;
    sounds.add(cue);
  }

  @override
  void stopSoundOwner(Object owner) {}
}

void main() {
  testWidgets('kin poured in: previewed, then XP lands, levels ring out and '
      'the kin are gone', (tester) async {
    final audio = _RecordingAudio();
    final h = await EnhanceHarness.pump(tester, open: 'fh0', audio: audio);

    // The tray lists spare kin by level, highest first: fh5 and fh2 (both
    // level 3) lead. The stage sprite is the first InstanceSprite.
    for (final i in [1, 2]) {
      await tester.tap(
        find.byType(InstanceSprite).hitTestable().at(i),
        warnIfMissed: false,
      );
      await h.settle(15);
    }
    expect(find.text('SACRIFICE 2 FOR XP'), findsOneWidget);
    expect(find.textContaining('→ LV'), findsOneWidget);
    expect(find.textContaining('XP'), findsWidgets);

    await tester.tap(find.text('SACRIFICE 2 FOR XP'));
    await h.settle(160);

    final target = await tester.runAsync(
      () => h.db.creatureDao.getInstance('fh0'),
    );
    expect(target!.level, greaterThan(4));
    for (final id in ['fh5', 'fh2']) {
      final gone = await tester.runAsync(
        () => h.db.creatureDao.getInstance(id),
      );
      expect(gone, isNull, reason: '$id was given up');
    }
    expect(audio.sounds, contains(SoundCue.rewardCollect));
    expect(audio.sounds, contains(SoundCue.upgradeComplete));
    expect(find.text('CHOOSE SPARES FOR XP'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('with no orb or soul ever held, kin stand alone', (tester) async {
    final h = await EnhanceHarness.pump(tester, open: 'fh0', items: false);
    expect(find.text('XP'), findsOneWidget);
    expect(find.textContaining('ORBS'), findsNothing);
    expect(find.textContaining('SOULS'), findsNothing);
    await h.dispose();
  });

  testWidgets('a chosen card\'s creature is carried onto the stage as '
      'grains, and the chamber is there once it lands', (tester) async {
    final audio = _RecordingAudio();
    final h = await EnhanceHarness.pump(tester, audio: audio);
    // Below the sprite, on the card's name and stats: the card is still
    // found, and its sprite read.
    await tester.tap(find.text('Firehorn').first, warnIfMissed: false);
    final flight = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is StageArrivalPainter,
    );
    var flew = false;
    for (var i = 0; i < 20 && !flew; i++) {
      await h.settle(1);
      flew = flight.evaluate().isNotEmpty;
    }
    expect(flew, isTrue, reason: 'the card was read into grains');
    expect(audio.sounds, contains(SoundCue.creatureSummon));
    // The chamber cannot be touched mid-flight.
    expect(find.textContaining('CHOOSE AN ALCHEMON'), findsOneWidget);
    await h.settle(60);
    expect(flight, findsNothing);
    expect(find.textContaining('CHOOSE AN ALCHEMON'), findsNothing);
    expect(find.textContaining('FIREHORN'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('the picker searches by species', (tester) async {
    final h = await EnhanceHarness.pump(tester);
    expect(find.text('Firehorn'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'plant');
    await h.settle(15);
    expect(find.text('Planthorn'), findsWidgets);
    expect(find.text('Firehorn'), findsNothing);
    await h.dispose();
  });
}
