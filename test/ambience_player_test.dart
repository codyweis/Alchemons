import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:alchemons/audio/ambience_player.dart';

class Voice extends Fake implements AmbienceVoice {
  bool failLoad = false;
  Completer<void>? loading;
  final ended = Completer<void>();
  final levels = <double>[];
  String? asset;
  int starts = 0;
  int disposals = 0;
  @override
  Future<void> load(String path) async {
    asset = path;
    if (failLoad) throw StateError('test asset load failure');
    await loading?.future;
  }

  @override
  Future<void> volume(double value) async {
    levels.add(value);
  }

  @override
  Future<void> play() {
    starts++;
    return ended.future;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    if (!ended.isCompleted) ended.complete();
  }
}

void main() {
  late List<Voice> voices;
  late AmbiencePlayer engine;
  setUp(() {
    voices = [];
    engine = AmbiencePlayer(
      createVoice: () {
        final v = Voice();
        voices.add(v);
        return v;
      },
      delay: (_) async {},
    );
  });
  tearDown(() async {
    engine.dispose();
    await engine.settled;
  });

  test('failed asset is disposed and does not block the next scene', () async {
    engine.dispose();
    await engine.settled;
    engine = AmbiencePlayer(
      createVoice: () {
        final voice = Voice()..failLoad = voices.isEmpty;
        voices.add(voice);
        return voice;
      },
      delay: (_) async {},
    );
    engine.setEnabled(true);
    engine.setScene(Object(), AmbienceCue.lab);
    await engine.settled;
    expect(voices.first.disposals, 1);
    expect(voices.first.starts, 0);
    engine.setScene(Object(), AmbienceCue.cosmicSpace);
    await engine.settled;
    expect(voices.last.starts, 1);
  });

  test(
    'same scene rebuild does not reload; old owner cannot stop new scene',
    () async {
      final first = Object(), second = Object();
      engine.setEnabled(true);
      engine.setScene(first, AmbienceCue.cosmicSpace);
      await engine.settled;
      engine.setScene(first, AmbienceCue.cosmicSpace);
      await engine.settled;
      expect(voices, hasLength(1));
      engine.setScene(second, AmbienceCue.lab);
      await engine.settled;
      engine.stopOwner(first);
      await engine.settled;
      expect(voices, hasLength(2));
      expect(voices.first.disposals, 1);
      expect(voices.last.starts, 1);
      expect(voices.last.disposals, 0);
    },
  );

  test('muting stops loop and preserves scene for foreground/unmute', () async {
    engine.setScene(Object(), AmbienceCue.dungeonWater);
    await engine.settled;
    expect(voices, isEmpty);
    engine.setEnabled(true);
    await engine.settled;
    expect(voices.single.starts, 1);
    engine.setEnabled(false);
    await engine.settled;
    expect(voices.single.levels.last, 0);
    expect(voices.single.disposals, 1);
    engine.setEnabled(true);
    await engine.settled;
    expect(voices, hasLength(2));
    expect(voices.last.asset, AmbienceCue.dungeonWater.asset);
  });

  test('scene replaced while loading never starts stale loop', () async {
    final loading = Completer<void>();
    engine.dispose();
    await engine.settled;
    engine = AmbiencePlayer(
      createVoice: () {
        final v = Voice();
        if (voices.isEmpty) v.loading = loading;
        voices.add(v);
        return v;
      },
      delay: (_) async {},
    );
    engine.setEnabled(true);
    engine.setScene(Object(), AmbienceCue.cosmicSpace);
    await Future<void>.delayed(Duration.zero);
    engine.setScene(Object(), AmbienceCue.dungeonFire);
    loading.complete();
    await engine.settled;
    expect(voices.first.starts, 0);
    expect(voices.first.disposals, 1);
    expect(voices.last.asset, AmbienceCue.dungeonFire.asset);
    expect(voices.last.starts, 1);
  });

  test(
    'dispose during load prevents late playback and disposes exactly once',
    () async {
      engine.dispose();
      await engine.settled;
      final voice = Voice()..loading = Completer<void>();
      engine = AmbiencePlayer(createVoice: () => voice, delay: (_) async {});
      engine.setEnabled(true);
      engine.setScene(Object(), AmbienceCue.lab);
      await Future<void>.delayed(Duration.zero);
      engine.dispose();
      voice.loading!.complete();
      await engine.settled;
      expect(voice.starts, 0);
      expect(voice.disposals, 1);
    },
  );
}
