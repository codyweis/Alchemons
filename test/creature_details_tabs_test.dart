import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Swiping between Overview and Lineage has to feel immediate: the tab under
// the finger lights as soon as the page is mostly across, not when the
// spring finally comes to rest, and the spring itself is quick.
void main() {
  testWidgets('a swipe lights the next tab mid-flight and settles fast', (
    tester,
  ) async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    final catalog = CreatureCatalog();
    await tester.runAsync(() async {
      await catalog.load();
      await loadNatures();
      await db.creatureDao.insertInstance(instanceId: 'x', baseId: 'HOR01');
    });
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
          Provider<CreatureCatalog>.value(value: catalog),
          Provider<StaminaService>.value(value: StaminaService(db)),
          ChangeNotifierProvider<ConstellationEffectsService>.value(
            value: ConstellationEffectsService(db),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => CreatureDetailsDialog.show(
                    context,
                    catalog.getCreatureById('HOR01')!,
                    true,
                    instanceId: 'x',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }

    bool lit(String label) {
      final text = tester.widget<Text>(find.text(label));
      return text.style?.fontWeight == FontWeight.w800;
    }

    expect(lit('Overview'), isTrue);
    final pages = find.byType(PageView);
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: pages, matching: find.byType(Scrollable)).first,
        )
        .position;
    final width = position.viewportDimension;

    // A quick flick, a quarter of the way across.
    await tester.timedDragFrom(
      Offset(width * 0.7, 600),
      Offset(-width * 0.25, 0),
      const Duration(milliseconds: 100),
    );

    int? litAt;
    int? settledAt;
    for (var frame = 1; frame <= 120; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (litAt == null && lit('Lineage')) litAt = frame;
      if ((position.pixels - width).abs() < 0.5) {
        settledAt = frame;
        break;
      }
    }
    expect(settledAt, isNotNull, reason: 'the flick should carry it across');
    expect(litAt, isNotNull);
    // Was frame 34 for both: the label waited for a slow spring to rest.
    expect(litAt!, lessThanOrEqualTo(6), reason: 'lit while still moving');
    expect(settledAt!, lessThanOrEqualTo(18), reason: 'about a quarter second');

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.runAsync(db.close);
  });
}
