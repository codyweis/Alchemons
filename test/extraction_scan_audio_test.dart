import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/breed_result_animation.dart';

void main() {
  testWidgets(
    'scan cue fires at start and explicit restart, never on rebuild',
    (tester) async {
      final key = GlobalKey<CreatureScanAnimationState>();
      var starts = 0;
      var ready = false;
      Widget buildScan() => MaterialApp(
        home: SizedBox(
          width: 200,
          height: 200,
          child: CreatureScanAnimation(
            key: key,
            onScanStarted: () => starts++,
            onReadyChanged: (value) => ready = value,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );
      await tester.pumpWidget(buildScan());
      expect(starts, 1);
      await tester.pumpWidget(buildScan());
      expect(starts, 1);
      await tester.pump(const Duration(milliseconds: 800));
      expect(ready, isTrue);
      key.currentState!.restart();
      expect(starts, 2);
      expect(ready, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(starts, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('discovery flash resolves its forge tokens from the theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      Provider<FactionTheme>.value(
        value: FactionTheme.scorchForge(),
        child: MaterialApp(
          home: SizedBox(
            width: 240,
            height: 240,
            child: CreatureScanAnimation(
              isNewDiscovery: true,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    );
    // Past the scan chain, then past the beat before the flash starts.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('NEW DISCOVERY'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
