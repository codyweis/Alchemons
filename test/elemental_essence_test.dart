import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({VoidCallback? onLongPress}) => MaterialApp(
    home: Center(
      child: SizedBox(
        width: 120,
        height: 120,
        child: ElementalEssence(
          element: 'Fire',
          onLongPress: onLongPress,
          child: Center(
            child: Container(width: 70, height: 90, color: Colors.orange),
          ),
        ),
      ),
    ),
  );

  bool playing(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .any((p) => p.painter is EssencePainter);

  testWidgets('a tap turns it to grains and back, then leaves nothing', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byType(ElementalEssence));
    // The capture reads the screen, which needs real async.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(playing(tester), isTrue);

    // The sprite is hidden while it is grains…
    await tester.pump(const Duration(milliseconds: 900));
    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(ElementalEssence),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fade.opacity.value, 0);

    // …and back, with the painter gone, once it is over.
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();
    expect(playing(tester), isFalse);
    expect(fade.opacity.value, 1);
  });

  testWidgets('a long press is passed through', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(host(onLongPress: () => pressed++));
    await tester.longPress(find.byType(ElementalEssence));
    await tester.pump();
    expect(pressed, 1);
    expect(playing(tester), isFalse);
  });

  test('every element scrubs end to end', () {
    final grains = SpecimenGrains.disc(const Color(0xFF8040C0), radius: 30);
    for (final e in EssenceElement.values) {
      final field = EssenceField(grains, e);
      // The sprite shows at both ends and is gone in the middle.
      expect(EssenceField.spriteOpacity(0), 1, reason: '$e');
      expect(EssenceField.spriteOpacity(EssenceField.duration), 1);
      expect(EssenceField.spriteOpacity(1.0), 0, reason: '$e');
      // Scrub it end to end; a form that read past its arrays would throw.
      for (var t = 0.0; t < EssenceField.duration; t += 0.05) {
        field.paint(_NullCanvas(), Offset.zero, t);
      }
    }
  });

  double heldOpacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.descendant(
          of: find.byType(ElementalEssence),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;

  Widget revealHost(
    EssenceReveal reveal, {
    bool announces = true,
    bool hold = false,
  }) => MaterialApp(
    home: Center(
      child: SizedBox(
        width: 120,
        height: 120,
        child: ElementalEssence(
          element: 'Earth',
          reveal: reveal,
          hold: hold,
          child: Center(child: _FakeSprite(announces: announces)),
        ),
      ),
    ),
  );

  testWidgets('a reveal holds the sprite back, then gathers it in', (
    tester,
  ) async {
    final reveal = EssenceReveal.once();
    await tester.pumpWidget(revealHost(reveal));
    // Faint, not gone, so it can be read.
    expect(heldOpacity(tester), lessThan(0.05));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(playing(tester), isTrue);
    expect(heldOpacity(tester), 1);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(playing(tester), isFalse);

    // The same ticket again: spent, so it just shows.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(revealHost(reveal));
    await tester.pump();
    expect(heldOpacity(tester), 1);
    expect(playing(tester), isFalse);
  });

  testWidgets('a held reveal waits, out of sight, until it is let go', (
    tester,
  ) async {
    final reveal = EssenceReveal.once();
    await tester.pumpWidget(revealHost(reveal, hold: true));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    // Held well past the time a stuck sprite would be shown.
    await tester.pump(const Duration(seconds: 3));
    expect(heldOpacity(tester), lessThan(0.05));
    expect(playing(tester), isFalse);

    await tester.pumpWidget(revealHost(reveal));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(playing(tester), isTrue);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(playing(tester), isFalse);
    expect(heldOpacity(tester), 1);
  });

  testWidgets('swiped away and back mid-reveal, the sprite always returns', (
    tester,
  ) async {
    double faded() => tester
        .widget<FadeTransition>(
          find.descendant(
            of: find.byType(ElementalEssence),
            matching: find.byType(FadeTransition),
          ),
        )
        .opacity
        .value;
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
    }

    // Arrives and starts revealing.
    final first = EssenceReveal.once();
    await tester.pumpWidget(revealHost(first));
    await settle();
    expect(playing(tester), isTrue);
    await tester.pump(const Duration(milliseconds: 400));

    // Swiped away part-way: re-armed and held, out of view.
    final second = EssenceReveal.once();
    await tester.pumpWidget(revealHost(second, hold: true));
    await tester.pump();
    // Swiped to, and straight off again before its reveal can read.
    await tester.pumpWidget(revealHost(second));
    await tester.pumpWidget(revealHost(second, hold: true));
    // Long enough for a give-up timer to have fired while it was away.
    await tester.pump(const Duration(seconds: 3));

    // Back for good.
    await tester.pumpWidget(revealHost(second));
    await settle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(playing(tester), isFalse);
    expect(heldOpacity(tester), 1);
    expect(faded(), 1);
  });

  testWidgets('a sprite that never says it is ready is shown anyway', (
    tester,
  ) async {
    await tester.pumpWidget(revealHost(EssenceReveal.once(), announces: false));
    expect(heldOpacity(tester), lessThan(0.05));
    await tester.pump(const Duration(seconds: 2));
    expect(heldOpacity(tester), 1);
    expect(playing(tester), isFalse);
  });

  test('type names map to elements, unknown ones to spirit', () {
    expect(EssenceElement.of('Lava'), EssenceElement.lava);
    expect(EssenceElement.of('lightning'), EssenceElement.lightning);
    expect(EssenceElement.of(null), EssenceElement.spirit);
    expect(EssenceElement.of('Cosmic'), EssenceElement.spirit);
  });
}

/// Stands in for a CreatureSprite: a block of color that says it is ready
/// after its first frame, as the real one does once loaded.
class _FakeSprite extends StatefulWidget {
  const _FakeSprite({required this.announces});
  final bool announces;

  @override
  State<_FakeSprite> createState() => _FakeSpriteState();
}

class _FakeSpriteState extends State<_FakeSprite> {
  @override
  void initState() {
    super.initState();
    if (!widget.announces) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) const SpriteReadyNotification().dispatch(context);
    });
  }

  @override
  Widget build(BuildContext context) =>
      Container(width: 70, height: 90, color: Colors.brown);
}

class _NullCanvas implements Canvas {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
