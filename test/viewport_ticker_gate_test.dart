// An animated section inside a long scroll view should stop driving frames the
// moment it leaves the viewport, and should never be able to dirty the whole
// scroll view's layer on the way there.

import 'package:alchemons/widgets/perf/viewport_ticker_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Spinner extends StatefulWidget {
  const _Spinner();

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, _) => SizedBox(height: 200, width: 200),
  );
}

void main() {
  testWidgets('a gated section stops ticking once it scrolls out of view', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: const Column(
              children: [
                ViewportTickerGate(child: _Spinner()),
                SizedBox(height: 4000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Visible: the controller is driving frames.
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    // The gate isolates the section into its own layer either way.
    expect(
      find.descendant(
        of: find.byType(ViewportTickerGate),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );

    // Scroll it far past the viewport (and past the gate's slack).
    controller.jumpTo(2000);
    await tester.pump();
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);

    // Bring it back and it resumes.
    controller.jumpTo(0);
    await tester.pump();
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });
}
