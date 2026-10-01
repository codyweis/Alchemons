import 'package:alchemons/screens/alchemy_chamber_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(844, 390),
    const Size(1100, 800),
  ]) {
    testWidgets('Fluid controls, lifecycle and layout at $size', (
      tester,
    ) async {
      rootBundle.evict('assets/data/alchemons_element_recipes.json');
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: AlchemyChamberScreen()));
      for (
        var i = 0;
        i < 80 && find.byKey(const Key('alchemy-canvas')).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();
      }
      expect(find.byKey(const Key('alchemy-canvas')), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Pause'));
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(find.byTooltip('Resume'), findsOneWidget);
      expect(find.text('Vessel 0% full'), findsOneWidget);
      await tester.ensureVisible(find.text('Elements ▾'));
      await tester.tap(find.text('Elements ▾'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ChoiceChip), findsNWidgets(17));
      await tester.ensureVisible(find.text('Crystal'));
      await tester.tap(find.text('Crystal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Crystal ▾'), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('alchemy-canvas')),
        const Offset(30, 20),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Stir'));
      await tester.tap(find.text('Stir'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
