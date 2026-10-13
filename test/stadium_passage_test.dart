import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/screens/stadium/stadium_passage.dart';
import 'package:alchemons/screens/stadium/stadium_screen.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/stadium_trophy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Home's trophy into the stadium and back, the phone turning between (the
// platform's orientation requests are answered by turning the test view).
//
//   PASSAGE_OUT=/tmp/passage flutter test test/stadium_passage_test.dart
// also writes frames of both ways (PASSAGE_EVERY=0.05 for every 50 ms).

CosmicPartyMember _member(String name) => CosmicPartyMember(
  instanceId: 'test:$name',
  baseId: '',
  displayName: name,
  element: 'Fire',
  family: 'mane',
  level: 1,
  statSpeed: 3.2,
  statIntelligence: 3,
  statStrength: 3,
  statBeauty: 3,
  slotIndex: 0,
  staminaBars: 3,
  staminaMax: 3,
);

void main() {
  final out = Platform.environment['PASSAGE_OUT'];
  const tall = Size(390, 844), wide = Size(844, 390);
  // (wide: what a turn would make it; the Trials never ask for one.)

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    if (out == null) return;
    // Real type for the pictures; the test font draws boxes.
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
  });

  testWidgets('the cup carries home into the Trials and back', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'stadium_race_progress_v1': '{"copper":1}',
    });
    tester.view.physicalSize = tall * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final turns = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          final first = (call.arguments as List).first as String;
          turns.add(first);
          tester.view.physicalSize =
              (first.contains('landscape') ? wide : tall) * 2;
        }
        return null;
      },
    );
    // Android's seamless-rotation switch: answered, or it never is in
    // the test's fake time.
    const rotation = MethodChannel('alchemons/rotation');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      rotation,
      (call) async => null,
    );
    addTearDown(() {
      final m = tester.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, null);
      m.setMockMethodCallHandler(rotation, null);
    });

    const look = TrophyLook(TrophyMetal.copper, fill: 1 / 3);
    final home = GlobalKey();
    final shot = GlobalKey();
    final lifted = ValueNotifier(false);
    TrophyLook? returned;
    await tester.pumpWidget(
      RepaintBoundary(
        key: shot,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) => Scaffold(
              backgroundColor: const Color(0xFF1A1012),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 120),
                    GestureDetector(
                      onTap: () => openStadiumFromHome(
                        context,
                        from: home,
                        lifted: lifted,
                        look: look,
                        cup: 0,
                        onReturn: (l) => returned = l,
                        party: [_member('Ember')],
                      ),
                      child: StadiumTrophyEmblem(
                        key: home,
                        height: 76,
                        look: look,
                        lifted: lifted,
                      ),
                    ),
                    const Text(
                      'STADIUM',
                      style: TextStyle(
                        color: Color(0xFFE6E2DA),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    var frame = 0;
    Future<void> snap(String name) async {
      if (out == null) return;
      Directory(out).createSync(recursive: true);
      await tester.runAsync(() async {
        final b =
            shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/${(frame++).toString().padLeft(3, '0')}_$name.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    // PASSAGE_EVERY=0.05: a frame that often, for an animation.
    final every = double.tryParse(Platform.environment['PASSAGE_EVERY'] ?? '');
    Future<void> play(double seconds, {List<double> at = const []}) async {
      var t = 0.0, next = every ?? double.infinity;
      final marks = [...at];
      while (t < seconds) {
        await tester.pump(const Duration(milliseconds: 16));
        t += .016;
        if (every != null) {
          if (t >= next) {
            next += every;
            await snap('f');
          }
        } else if (marks.isNotEmpty && t >= marks.first) {
          await snap('t${marks.removeAt(0).toStringAsFixed(2)}');
        }
      }
    }

    await snap('home');
    await tester.tap(find.byType(StadiumTrophyEmblem));
    await tester.pump();
    expect(lifted.value, isTrue);
    // Lift, unfold into the arena, open out onto the shelf: upright the
    // whole way, so nothing turns.
    await play(3.0, at: [.25, .5, .75, .9, 1.1, 1.4, 1.7, 2.0, 2.4, 2.9]);
    expect(turns, isEmpty);
    expect(find.byType(StadiumScreen), findsOneWidget);
    expect(tester.view.physicalSize, tall * 2);
    await snap('stadium');

    // Back the way it came.
    await tester.tap(find.byType(BracketIconButton).first);
    await tester.pump();
    await play(2.6, at: [.25, .5, .8, 1.1, 1.4, 1.8, 2.4]);
    expect(find.byType(StadiumScreen), findsNothing);
    expect(turns, isEmpty);
    expect(tester.view.physicalSize, tall * 2);
    expect(lifted.value, isFalse);
    expect(returned, look);
    await snap('home_again');
  });
}
