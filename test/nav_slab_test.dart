import 'package:alchemons/widgets/nav_slab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Two tabs in an IndexedStack, as the shell keeps them, each with a slab
// standing near the bottom: home's lower and wider, Fusion's higher.
class _Shell extends StatefulWidget {
  const _Shell({
    required this.fusionAvailable,
    required this.homeSlab,
    super.key,
  });
  final bool fusionAvailable;
  final bool homeSlab;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int index = 0;

  void go(int next) {
    NavSlabHandoff.instance.tabSwitch(
      from: [NavSlabSite.home, NavSlabSite.fusion, null][index],
      to: [NavSlabSite.home, NavSlabSite.fusion, null][next],
    );
    setState(() => index = next);
  }

  static const _look = NavSlabLook(fill: Color(0xE009090B));

  @override
  Widget build(BuildContext context) {
    Widget tab(int i, Widget child) =>
        TickerMode(enabled: index == i, child: child);
    return IndexedStack(
      index: index,
      children: [
        tab(
          0,
          Stack(
            children: [
              if (widget.homeSlab)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 8,
                  child: NavSlab(
                    key: const Key('home'),
                    site: NavSlabSite.home,
                    look: _look,
                    child: const SizedBox(height: 50),
                  ),
                ),
            ],
          ),
        ),
        tab(
          1,
          Stack(
            children: [
              Positioned(
                left: 40,
                right: 40,
                bottom: 46,
                child: NavSlab(
                  key: const Key('fusion'),
                  site: NavSlabSite.fusion,
                  available: widget.fusionAvailable,
                  look: const NavSlabLook(
                    fill: Color(0x33E4C16A),
                    lit: Color(0xFFE4C16A),
                    split: NavSlabSplit(
                      share: 0.6,
                      gap: 10,
                      fill: Color(0x8C131316),
                    ),
                  ),
                  child: const SizedBox(height: 48),
                ),
              ),
            ],
          ),
        ),
        tab(2, const SizedBox.expand()),
      ],
    );
  }
}

void main() {
  final shellKey = GlobalKey<_ShellState>();

  Future<void> pumpShell(
    WidgetTester tester, {
    bool fusionAvailable = true,
    bool homeSlab = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: _Shell(
          key: shellKey,
          fusionAvailable: fusionAvailable,
          homeSlab: homeSlab,
        ),
      ),
    );
  }

  testWidgets('home to Fusion hands the slab over and lands in place', (
    tester,
  ) async {
    await pumpShell(tester);
    shellKey.currentState!.go(1);
    await tester.pump();
    expect(NavSlabHandoff.instance.flying, isTrue);

    // It starts where home's bar stood, with Fusion's own contents not yet
    // up.
    Opacity opacity() => tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const Key('fusion')),
        matching: find.byType(Opacity),
      ),
    );
    Offset shift() {
      final m = tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byKey(const Key('fusion')),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getTranslation();
      return Offset(m.x, m.y);
    }

    expect(opacity().opacity, 0);
    // Home's bar centre is 38 px lower (bottom 8 + 25 vs bottom 46 + 24).
    expect(shift().dy, closeTo(37, 0.5));
    expect(shift().dx, closeTo(0, 0.5));
    // What stands on it is told where its top is: 36 px lower.
    final riders = NavSlabHandoff.instance.shiftOf(NavSlabSite.fusion);
    expect(riders.value.dy, closeTo(36, 0.5));

    // The arriving tab's ticker is unmuted by the switch's own build, so it
    // starts counting on the frame after.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(opacity().opacity, inExclusiveRange(0, 1));
    expect(shift().dy, inExclusiveRange(0, 37));
    expect(riders.value.dy, inExclusiveRange(0, 36));

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(NavSlabHandoff.instance.flying, isFalse);
    expect(opacity().opacity, 1);
    expect(shift(), Offset.zero);
    expect(riders.value, Offset.zero);
  });

  testWidgets('Fusion back to home hands it over the other way', (
    tester,
  ) async {
    await pumpShell(tester);
    shellKey.currentState!.go(1);
    await tester.pumpAndSettle();
    shellKey.currentState!.go(0);
    await tester.pump();
    expect(NavSlabHandoff.instance.flying, isTrue);
    await tester.pumpAndSettle();
    expect(NavSlabHandoff.instance.flying, isFalse);
  });

  testWidgets('no handover to a side that is not up, or a docked bar', (
    tester,
  ) async {
    await pumpShell(tester, fusionAvailable: false);
    shellKey.currentState!.go(1);
    await tester.pump();
    expect(NavSlabHandoff.instance.flying, isFalse);

    await pumpShell(tester, homeSlab: false);
    shellKey.currentState!.go(0);
    await tester.pump();
    shellKey.currentState!.go(1);
    await tester.pump();
    expect(NavSlabHandoff.instance.flying, isFalse);
  });

  testWidgets('leaving mid-flight finishes it rather than freezing it', (
    tester,
  ) async {
    await pumpShell(tester);
    shellKey.currentState!.go(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(NavSlabHandoff.instance.flying, isTrue);

    // Back home at once: the flight ends, and that switch cuts.
    shellKey.currentState!.go(0);
    await tester.pump();
    expect(NavSlabHandoff.instance.flying, isFalse);

    // Away to a third tab mid-flight: same.
    shellKey.currentState!.go(1);
    await tester.pumpAndSettle();
    shellKey.currentState!.go(0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(NavSlabHandoff.instance.flying, isTrue);
    shellKey.currentState!.go(2);
    await tester.pump();
    expect(NavSlabHandoff.instance.flying, isFalse);
  });
}
