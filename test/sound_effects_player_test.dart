import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:alchemons/audio/sound_effects_player.dart';
import 'package:alchemons/audio/sound_cue.dart';

class FakeVoice implements SoundVoice {
  Completer<void>? loading;
  final finished = Completer<void>();
  int plays = 0;
  int disposals = 0;
  String? asset;
  double? speed;
  @override
  Future<void> load(String value) async {
    asset = value;
    await loading?.future;
  }

  @override
  Future<void> configure(double volume, double value) async {
    speed = value;
  }

  @override
  Future<void> play() {
    plays++;
    return finished.future;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    if (!finished.isCompleted) finished.complete();
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'cooldown drops bursts before allocating voices; variants advance on accepted events',
    () async {
      var now = 1000;
      final voices = <FakeVoice>[];
      final engine = SoundEffectsPlayer(
        nowMs: () => now,
        createVoice: () {
          final v = FakeVoice();
          voices.add(v);
          return v;
        },
      );
      addTearDown(engine.dispose);
      unawaited(engine.play(SoundCue.cosmicOrbPickup));
      await flush();
      await engine.play(SoundCue.cosmicOrbPickup);
      expect(voices, hasLength(1));
      now += 100;
      unawaited(engine.play(SoundCue.cosmicOrbPickup));
      await flush();
      expect(voices, hasLength(2));
      expect(voices.last.asset, endsWith('_01.wav'));
    },
  );

  test(
    'six reserved slots cap concurrent loads; warning displaces only lower priority',
    () async {
      final voices = <FakeVoice>[];
      final engine = SoundEffectsPlayer(
        createVoice: () {
          final v = FakeVoice()..loading = Completer<void>();
          voices.add(v);
          return v;
        },
      );
      addTearDown(engine.dispose);
      for (final cue in [
        SoundCue.combatProjectile,
        SoundCue.combatHitLight,
        SoundCue.combatHitHeavy,
        SoundCue.combatEnemyDefeat,
        SoundCue.cosmicOrbPickup,
        SoundCue.dungeonStepStone,
      ]) {
        unawaited(engine.play(cue));
      }
      await engine.play(SoundCue.dungeonStepWater);
      expect(voices, hasLength(6));
      unawaited(engine.play(SoundCue.combatDanger));
      expect(voices, hasLength(7));
      expect(voices.first.disposals, 1);
      for (final v in voices) {
        v.loading!.complete();
      }
      await flush();
      expect(voices.first.plays, 0);
      expect(voices.last.plays, 1);
    },
  );

  test(
    'muting during an asset load prevents late playback and double disposal',
    () async {
      final v = FakeVoice()..loading = Completer<void>();
      final engine = SoundEffectsPlayer(createVoice: () => v);
      final play = engine.play(SoundCue.uiTap);
      engine.setEnabled(false);
      v.loading!.complete();
      await play;
      expect(v.plays, 0);
      expect(v.disposals, 1);
      await engine.play(SoundCue.uiConfirm);
      expect(v.plays, 0);
      engine.dispose();
      expect(v.disposals, 1);
    },
  );

  test('screen cancellation stops only its own effects', () async {
    final voices = <FakeVoice>[];
    final engine = SoundEffectsPlayer(
      createVoice: () {
        final v = FakeVoice();
        voices.add(v);
        return v;
      },
    );
    final owner = Object();
    unawaited(
      engine.play(SoundCue.extractionCreatureReveal, owner: owner, speed: 1.44),
    );
    unawaited(engine.play(SoundCue.uiTap, owner: Object()));
    await flush();
    expect(voices.first.speed, 1.44);
    engine.stopOwner(owner);
    await flush();
    expect(voices.first.disposals, 1);
    expect(voices.last.disposals, 0);
    engine.dispose();
  });

  test('completed voices are reused and disabling clears the cache', () async {
    var now = 1000;
    final voices = <FakeVoice>[];
    final engine = SoundEffectsPlayer(
      nowMs: () => now,
      createVoice: () {
        final v = FakeVoice();
        voices.add(v);
        return v;
      },
    );
    final play = engine.play(SoundCue.uiTap);
    await flush();
    voices.single.finished.complete();
    await play;
    now += 100;
    await engine.play(SoundCue.uiTap);
    expect(voices, hasLength(1));
    expect(voices.single.plays, 2);
    engine.setEnabled(false);
    expect(voices.single.disposals, 1);
    engine.dispose();
  });
}
