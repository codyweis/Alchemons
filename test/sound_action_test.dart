// Taps are felt, not heard.
//
// soundAction used to default to SoundCue.uiTap, which put a sound on roughly
// 500 buttons, back arrows and dismissals, and the navigator observer added
// another on every route push and pop — so opening a sheet and closing it made
// three sounds on top of each other. Sound is now reserved for things worth
// hearing; ordinary taps get a haptic.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/audio/navigation_sounds.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/widgets/fast_long_press_detector.dart';

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

/// Records the haptics the platform was asked for.
List<String> captureHaptics(WidgetTester tester) {
  final fired = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        fired.add(call.arguments as String? ?? 'default');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return fired;
}

void main() {
  _gridTests();

  testWidgets('an ordinary tap is felt, not heard', (tester) async {
    final audio = ActionAudio();
    final haptics = captureHaptics(tester);
    var calls = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider<AudioController>.value(
        value: audio,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: context.soundAction(() => calls++),
                  child: const Text('Tap'),
                ),
                TextButton(
                  onPressed: context.soundAction(null),
                  child: const Text('Disabled'),
                ),
                TextButton(
                  onPressed: context.soundAction(
                    context.soundAction(() => calls++),
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
    await tester.tap(find.text('Disabled'));
    await tester.tap(find.text('Nested'));

    expect(calls, 2, reason: 'the disabled button must not fire');
    expect(audio.sounds, isEmpty, reason: 'chrome taps are silent');
    // Two live taps; the nested wrapper buzzes once per wrapper, which is why
    // widgets should wrap a callback once.
    expect(haptics, everyElement('HapticFeedbackType.lightImpact'));
    expect(haptics, isNotEmpty);
  });

  testWidgets('a tap that earns a sound still gets one', (tester) async {
    final audio = ActionAudio();
    captureHaptics(tester);

    await tester.pumpWidget(
      ChangeNotifierProvider<AudioController>.value(
        value: audio,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: context.soundAction(
                    () {},
                    SoundCue.purchaseSuccess,
                  ),
                  child: const Text('Buy'),
                ),
                // An action that plays its own sound suppresses the tap cue,
                // so an outcome never doubles up with the button.
                TextButton(
                  onPressed: context.soundAction(
                    () => context.sound(SoundCue.uiDenied),
                    SoundCue.purchaseSuccess,
                  ),
                  child: const Text('Refused'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buy'));
    await tester.tap(find.text('Refused'));

    expect(audio.sounds, [SoundCue.purchaseSuccess, SoundCue.uiDenied]);
  });

  testWidgets('opening and closing a route makes no sound', (tester) async {
    final audio = ActionAudio();
    captureHaptics(tester);

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

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Panel'), findsOneWidget);
    expect(audio.sounds, isEmpty);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Panel'), findsNothing);
    expect(audio.sounds, isEmpty, reason: 'navigation is not an event');
  });
}

/// The grid cards are the most-tapped thing in the app and they do not go
/// through a button widget — they use FastLongPressDetector directly. Pinned
/// here because "tapping an alchemon does nothing" was the first thing to go
/// wrong when taps stopped making a sound.
void _gridTests() {
  testWidgets('a specimen card tap is felt', (tester) async {
    final audio = ActionAudio();
    final haptics = captureHaptics(tester);
    var taps = 0;
    var longPresses = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider<AudioController>.value(
        value: audio,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: FastLongPressDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                onLongPress: () => longPresses++,
                child: const SizedBox(width: 200, height: 200),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(FastLongPressDetector));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(haptics, ['HapticFeedbackType.lightImpact']);

    await tester.longPress(find.byType(FastLongPressDetector));
    await tester.pumpAndSettle();
    expect(longPresses, 1);
    expect(haptics.length, 2, reason: 'a long press is felt too');
    expect(audio.sounds, isEmpty, reason: 'browsing the grid is silent');
  });
}
