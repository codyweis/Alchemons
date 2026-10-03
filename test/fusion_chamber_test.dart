import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fusion_harness.dart';

// The fusion chamber says what is in the way before FUSE, not after: a pair
// it would refuse shows why above the button, and the button waits.
void main() {
  bool fuseEnabled(WidgetTester tester) => tester
      .widget<BracketButton>(find.widgetWithText(BracketButton, 'FUSE'))
      .enabled;

  testWidgets('a ready pair: free chambers counted, FUSE open', (
    tester,
  ) async {
    final h = await FusionHarness.pump(tester, p1: 'fh', p2: 'wh');
    expect(find.text('3 FREE'), findsOneWidget);
    expect(find.text('FIREHORN'), findsOneWidget);
    expect(find.text('WATERHORN'), findsOneWidget);
    expect(fuseEnabled(tester), isTrue);
    await h.dispose();
  });

  // On the Fold the plate's text ran a pixel taller than a fixed 62 px box
  // and overflowed. Larger text, a resting plate and a two-line warning
  // must all still fit.
  testWidgets('nothing overflows with larger text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = await FusionHarness.pump(
      tester,
      p1: 'tired',
      p2: 'wl',
      busy: 4,
      storageFull: true,
    );
    expect(tester.takeException(), isNull);
    await h.dispose();
  });

  testWidgets('two families without Cross-Species Lineage wait', (
    tester,
  ) async {
    final h = await FusionHarness.pump(tester, p1: 'fh', p2: 'wl');
    expect(
      find.text('TWO FAMILIES · NEEDS CROSS-SPECIES LINEAGE'),
      findsOneWidget,
    );
    expect(fuseEnabled(tester), isFalse);
    await h.dispose();
  });

  testWidgets('…and go once it is unlocked', (tester) async {
    final h = await FusionHarness.pump(
      tester,
      p1: 'fh',
      p2: 'wl',
      crossSpecies: true,
    );
    expect(find.textContaining('TWO FAMILIES'), findsNothing);
    expect(fuseEnabled(tester), isTrue);
    await h.dispose();
  });

  testWidgets('a resting one waits, and says so on its plate', (
    tester,
  ) async {
    final h = await FusionHarness.pump(tester, p1: 'tired', p2: 'wh');
    expect(find.textContaining('FIREHORN IS RESTING'), findsOneWidget);
    expect(find.text('RESTING'), findsOneWidget);
    expect(fuseEnabled(tester), isFalse);
    await h.dispose();
  });

  testWidgets('chambers full: a note, and it still fuses into storage', (
    tester,
  ) async {
    final h = await FusionHarness.pump(tester, p1: 'fh', p2: 'wh', busy: 4);
    expect(
      find.text('CHAMBERS FULL · THIS ONE GOES TO COLD STORAGE'),
      findsOneWidget,
    );
    expect(fuseEnabled(tester), isTrue);
    await h.dispose();
  });

  testWidgets('chambers and storage full: it waits', (tester) async {
    final h = await FusionHarness.pump(
      tester,
      p1: 'fh',
      p2: 'wh',
      busy: 4,
      storageFull: true,
    );
    expect(find.text('CHAMBERS AND COLD STORAGE FULL'), findsOneWidget);
    expect(find.text('ALL FULL'), findsOneWidget);
    expect(fuseEnabled(tester), isFalse);
    await h.dispose();
  });

  testWidgets('one button does the next thing; SAME PAIR refills both', (
    tester,
  ) async {
    final h = await FusionHarness.pump(tester, lastPair: ('fh', 'wh'));
    expect(find.text('CHOOSE TWO'), findsOneWidget);
    await tester.tap(find.text('SAME PAIR'));
    await h.settle(10);
    expect(find.text('FIREHORN'), findsOneWidget);
    expect(find.text('WATERHORN'), findsOneWidget);
    expect(find.text('FUSE'), findsOneWidget);

    // Taking one out asks for one more.
    await tester.tap(find.byIcon(AppIcons.close).first);
    await h.settle(4);
    expect(find.text('CHOOSE ONE MORE'), findsOneWidget);
    await h.dispose();
  });
}
