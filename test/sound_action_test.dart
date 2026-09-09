import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/audio/navigation_sounds.dart';
import 'package:alchemons/providers/audio_provider.dart';

class ActionAudio extends Fake implements AudioController {
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
}

void main() {
  testWidgets(
    'accepted taps sound once; outcomes override tap; disabled stays silent',
    (tester) async {
      final audio = ActionAudio();
      var calls = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider<AudioController>.value(
          value: audio,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: context.soundAction(() {
                      calls++;
                    }),
                    child: const Text('Tap'),
                  ),
                  TextButton(
                    onPressed: context.soundAction(() {
                      context.sound(SoundCue.uiConfirm);
                    }),
                    child: const Text('Confirm'),
                  ),
                  TextButton(
                    onPressed: context.soundAction(null),
                    child: const Text('Disabled'),
                  ),
                  TextButton(
                    onPressed: context.soundAction(
                      context.soundAction(() {
                        calls++;
                      }),
                    ),
                    child: const Text('Nested'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Tap'));
      await tester.tap(find.text('Confirm'));
      await tester.tap(find.text('Disabled'));
      await tester.tap(find.text('Nested'));
      expect(calls, 2);
      expect(audio.sounds, [
        SoundCue.uiTap,
        SoundCue.uiConfirm,
        SoundCue.uiTap,
      ]);
    },
  );

  testWidgets('popup opens and barrier dismissal sound without duplicate tap', (
    tester,
  ) async {
    final audio = ActionAudio();
    await tester.pumpWidget(
      ChangeNotifierProvider<AudioController>.value(
        value: audio,
        child: MaterialApp(
          navigatorObservers: [NavigationSoundObserver()],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: context.soundAction(() {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(content: Text('Panel')),
                  );
                }),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(audio.sounds, isEmpty);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(audio.sounds, [SoundCue.uiPanelOpen]);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(audio.sounds, [SoundCue.uiPanelOpen, SoundCue.uiPanelClose]);
  });
}
