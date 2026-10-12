import 'package:alchemons/widgets/choice_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget page(int? selected) => MaterialApp(
    home: Center(
      child: SizedBox(
        width: 300,
        height: 400,
        child: ListView(
          key: const ValueKey('page'),
          children: [
            const SizedBox(height: 200),
            ChoiceStrip(
              selected: selected,
              children: [
                for (var i = 0; i < 10; i++)
                  SizedBox(width: 100, height: 60, child: Text('tile $i')),
              ],
            ),
            // Room for the page to scroll, were the strip to move it.
            const SizedBox(height: 800),
          ],
        ),
      ),
    ),
  );

  double stripOffset(WidgetTester tester) => tester
      .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
      .controller!
      .offset;

  testWidgets('the chosen one is brought into view, the page stays put', (
    tester,
  ) async {
    await tester.pumpWidget(page(8));
    await tester.pump();

    // Tile 8 spans 864..964; centred in a 300-wide strip.
    expect(stripOffset(tester), closeTo(764, 0.5));
    final pageScroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const ValueKey('page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(pageScroll.position.pixels, 0);
  });

  testWidgets('a choice near the start leaves the strip at its start', (
    tester,
  ) async {
    await tester.pumpWidget(page(0));
    await tester.pump();
    expect(stripOffset(tester), 0);
  });
}
