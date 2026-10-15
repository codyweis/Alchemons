import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/extraction_vessel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// An Alchemized Alchemon put into the harvest flask packs itself in once it
// has been read — once per put-in, however often the chamber is built — and
// a plain one never does. The pack says so with a firm tap of the phone.

/// Stands in for a creature's sprite: a solid shape that says it is drawn.
class _Sprite extends StatefulWidget {
  const _Sprite(this.size);
  final double size;
  @override
  State<_Sprite> createState() => _SpriteState();
}

class _SpriteState extends State<_Sprite> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) const SpriteReadyNotification().dispatch(context);
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    width: widget.size * 0.6,
    height: widget.size * 0.6,
    color: const Color(0xFFE0603A),
  );
}

void main() {
  late List<String> haptics;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> putIn(
    WidgetTester tester, {
    required bool alchemized,
    required EssenceReveal reveal,
    Key? key,
  }) async {
    final level = ValueNotifier(0.0);
    addTearDown(level.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 390,
            height: 300,
            child: ExtractionVessel(
              key: key,
              accent: const Color(0xFFFF6B35),
              mode: VesselMode.running,
              level: level,
              creatureId: 'firehorn',
              element: 'Fire',
              reveal: reveal,
              alchemized: alchemized,
              creature: (size) => _Sprite(size),
            ),
          ),
        ),
      ),
    );
    // Past the reveal's wait, then let the read of the sprite finish.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 600));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  const pack = 'HapticFeedbackType.mediumImpact';

  testWidgets('an Alchemized Alchemon packs itself in, once', (tester) async {
    final reveal = EssenceReveal.once();
    await putIn(tester, alchemized: true, reveal: reveal);
    expect(haptics.where((h) => h == pack), hasLength(1));

    // The chamber built afresh with the same put-in: no second pack.
    await putIn(tester, alchemized: true, reveal: reveal, key: UniqueKey());
    expect(haptics.where((h) => h == pack), hasLength(1));

    // Put in again (a reload): it packs again.
    await putIn(
      tester,
      alchemized: true,
      reveal: EssenceReveal.once(),
      key: UniqueKey(),
    );
    expect(haptics.where((h) => h == pack), hasLength(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a plain Alchemon never packs', (tester) async {
    await putIn(tester, alchemized: false, reveal: EssenceReveal.once());
    expect(haptics.where((h) => h == pack), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  test('pack() starts the pack, which runs on the field\'s clock', () {
    final f = ExtractionVesselField()
      ..mode = VesselMode.running
      ..occupied = true
      ..alchemized = true;
    f.layout(const Size(390, 300));
    for (var i = 0; i < 30; i++) {
      f.step(1 / 60);
    }
    expect(f.packAge, greaterThan(10));
    f.pack();
    for (var i = 0; i < 60; i++) {
      f.step(1 / 60);
    }
    expect(f.packAge, closeTo(1, 0.02));
  });
}
