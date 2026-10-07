import 'package:alchemons/navigation/emblem_passage.dart';
import 'package:alchemons/widgets/home_emblems.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A page that counts how often it is built and says when it is tapped.
class _Page extends StatefulWidget {
  const _Page({required this.onBuilt, required this.onTap});

  final VoidCallback onBuilt;
  final VoidCallback onTap;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  void initState() {
    super.initState();
    widget.onBuilt();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: widget.onTap,
    child: const ColoredBox(
      color: Color(0xFF101014),
      child: SizedBox.expand(child: Text('THE PAGE')),
    ),
  );
}

void main() {
  late GlobalKey emblem;
  late ValueNotifier<bool> lifted;
  late GlobalKey<NavigatorState> nav;
  var homeTaps = 0;

  setUp(() {
    emblem = GlobalKey();
    lifted = ValueNotifier(false);
    nav = GlobalKey<NavigatorState>();
    homeTaps = 0;
  });

  Future<void> pumpHome(WidgetTester tester, HomeEmblemKind kind) async {
    // A phone, so the taps below land on it.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: Scaffold(
          backgroundColor: const Color(0xFF09090B),
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => homeTaps++,
                ),
              ),
              Positioned(
                right: 12,
                top: 240,
                // Still, or home never settles once it is back in view.
                child: HomeEmblem(
                  key: emblem,
                  kind: kind,
                  size: 80,
                  animate: false,
                  lifted: lifted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Opacity pageOpacity(WidgetTester tester) => tester.widget<Opacity>(
    find.ancestor(of: find.byType(_Page), matching: find.byType(Opacity)).first,
  );

  for (final kind in HomeEmblemKind.values) {
    testWidgets('${kind.name}: built once covered, shown once ready, '
        'and back home', (tester) async {
      await pumpHome(tester, kind);
      final ready = ValueNotifier(false);
      var built = 0, pageTaps = 0;
      EmblemPassage.push<void>(
        nav.currentContext!,
        kind: kind,
        from: emblem,
        page: _Page(onBuilt: () => built++, onTap: () => pageTaps++),
        ready: ready,
        lifted: lifted,
      );
      await tester.pump();
      expect(lifted.value, isTrue, reason: 'the icon leaves its place');

      // Growing over the screen: no page yet, and home does not answer.
      await tester.pump(const Duration(milliseconds: 400));
      expect(built, 0);
      await tester.tapAt(const Offset(40, 500));
      expect(homeTaps, 0);

      // Covered: the page is built, but hidden while it is not ready.
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();
      expect(built, 1);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(pageOpacity(tester).opacity, 0);
      await tester.tapAt(const Offset(40, 500));
      expect(pageTaps, 0, reason: 'nothing answers mid-passage');

      // Ready: it gives way to the page, which then answers.
      ready.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      final mid = pageOpacity(tester).opacity;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      await tester.pumpAndSettle();
      expect(pageOpacity(tester).opacity, 1);
      await tester.tapAt(const Offset(40, 500));
      expect(pageTaps, 1);
      expect(built, 1, reason: 'built once');

      // Back: the page sinks, the scene gathers home, the icon returns.
      nav.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(pageOpacity(tester).opacity, lessThan(1));
      expect(lifted.value, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(_Page), findsNothing);
      expect(lifted.value, isFalse);
      await tester.tapAt(const Offset(40, 500));
      expect(homeTaps, 1);
    });
  }

  testWidgets('a page that never says ready is shown after the timeout', (
    tester,
  ) async {
    await pumpHome(tester, HomeEmblemKind.altar);
    EmblemPassage.push<void>(
      nav.currentContext!,
      kind: HomeEmblemKind.altar,
      from: emblem,
      page: _Page(onBuilt: () {}, onTap: () {}),
      ready: ValueNotifier(false),
      lifted: lifted,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(pageOpacity(tester).opacity, 0);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(pageOpacity(tester).opacity, 1);
  });

  testWidgets('a page with no ready is shown as soon as it is built', (
    tester,
  ) async {
    await pumpHome(tester, HomeEmblemKind.rite);
    EmblemPassage.push<void>(
      nav.currentContext!,
      kind: HomeEmblemKind.rite,
      from: emblem,
      page: _Page(onBuilt: () {}, onTap: () {}),
      lifted: lifted,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();
    expect(pageOpacity(tester).opacity, 1);
  });

  testWidgets('backing out mid-passage goes home without the page', (
    tester,
  ) async {
    await pumpHome(tester, HomeEmblemKind.constellation);
    var built = 0;
    EmblemPassage.push<void>(
      nav.currentContext!,
      kind: HomeEmblemKind.constellation,
      from: emblem,
      page: _Page(onBuilt: () => built++, onTap: () {}),
      ready: ValueNotifier(false),
      lifted: lifted,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(built, 0);
    expect(lifted.value, isFalse);
  });

  testWidgets('an emblem not laid out falls back to a plain push', (
    tester,
  ) async {
    await pumpHome(tester, HomeEmblemKind.altar);
    EmblemPassage.push<void>(
      nav.currentContext!,
      kind: HomeEmblemKind.altar,
      from: GlobalKey(),
      page: _Page(onBuilt: () {}, onTap: () {}),
      lifted: lifted,
    );
    await tester.pumpAndSettle();
    expect(find.text('THE PAGE'), findsOneWidget);
    expect(lifted.value, isFalse);
  });
}
