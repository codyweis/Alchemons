import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/audio/scene_ambience.dart';
import 'package:alchemons/providers/audio_provider.dart';

class SceneAudio extends Fake implements AudioController {
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  Object? owner;
  AmbienceCue? current;
  @override
  void setAmbience(Object source, AmbienceCue cue) {
    owner = source;
    current = cue;
  }

  @override
  void stopAmbienceOwner(Object source) {
    if (identical(source, owner)) {
      owner = null;
      current = null;
    }
  }
}

void main() {
  testWidgets(
    'covering route suspends ambience; return restores; replacement takes ownership',
    (tester) async {
      final audio = SceneAudio();
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ChangeNotifierProvider<AudioController>.value(
          value: audio,
          child: MaterialApp(
            navigatorKey: nav,
            navigatorObservers: [ambienceRouteObserver],
            home: const SceneAmbience(
              cue: AmbienceCue.lab,
              child: Scaffold(body: Text('Lab')),
            ),
          ),
        ),
      );
      expect(audio.current, AmbienceCue.lab);
      unawaited(
        nav.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Silent screen')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(audio.current, isNull);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(audio.current, AmbienceCue.lab);
      unawaited(
        nav.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const SceneAmbience(
              cue: AmbienceCue.cosmicSpace,
              child: Scaffold(body: Text('Space')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(audio.current, AmbienceCue.cosmicSpace);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(audio.current, AmbienceCue.lab);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(audio.current, isNull);
    },
  );
}
