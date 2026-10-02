import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/screens/mystic_altar/boss_altar_detail_screen.dart';
import 'package:alchemons/screens/mystic_altar/mystic_altar_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The Mystic Altar against a real (in-memory) save: a relic is held down
// onto its seat, an offering is chosen and held into the altar, and the rite
// is held, performed, watched and sealed.
void main() {
  late AlchemonsDatabase db;
  late CreatureCatalog catalog;
  final fire = altarEntryForElement('Fire')!;

  Future<void> boot(WidgetTester tester) async {
    catalog = CreatureCatalog();
    await tester.runAsync(() async {
      db = AlchemonsDatabase(NativeDatabase.memory());
      await catalog.load();
      await loadNatures();
      await OnboardingTaskService(db).markVisited('rite');
      await db.settingsDao.setBossRelicScreenStoryIntroSeen();
      await db.settingsDao.setSetting('campaign_mystic_presence_seen_v1', '1');
    });
    tester.view.physicalSize = const Size(412, 892) * 2;
    tester.view.devicePixelRatio = 2;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    tester.view.reset();
    await tester.runAsync(db.close);
  }

  /// Frames with real time for the save, the asset reads and the clock.
  Future<void> run(WidgetTester tester, int frames) async {
    for (var i = 0; i < frames; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 4)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Widget app(Widget home) => MultiProvider(
    providers: [
      Provider<AlchemonsDatabase>.value(value: db),
      Provider<CreatureCatalog>.value(value: catalog),
    ],
    child: MaterialApp(theme: ThemeData.dark(), home: home),
  );

  List<String> fireKinds() {
    final mystic = catalog.mysticByElement('Fire')!;
    return [
      for (final c in catalog.byType('Fire'))
        if (c.id != mystic.id) c.id,
    ];
  }

  Future<void> holdText(WidgetTester tester, String text, int frames) async {
    final g = await tester.startGesture(tester.getCenter(find.text(text)));
    await run(tester, frames);
    await g.up();
  }

  testWidgets('a relic held down onto its seat is spent and set, and opens '
      'its altar', (tester) async {
    await boot(tester);
    try {
      await tester.runAsync(
        () => db.inventoryDao.addItemQty(
          BossLootKeys.traitKeyForElement('Fire'),
          1,
        ),
      );
      await tester.pumpWidget(app(const MysticAltarScreen()));
      await run(tester, 20);
      // The held relic is the one the altar opens on.
      expect(find.text('HOLD TO SET THE RELIC'), findsOneWidget);

      // Let go early: nothing is spent.
      await holdText(tester, 'HOLD TO SET THE RELIC', 8);
      await run(tester, 10);
      final key = BossLootKeys.traitKeyForElement('Fire');
      expect(await tester.runAsync(() => db.inventoryDao.getItemQty(key)), 1);

      await holdText(tester, 'HOLD TO SET THE RELIC', 30);
      await run(tester, 40);
      expect(await tester.runAsync(() => db.inventoryDao.getItemQty(key)), 0);
      final placed = await tester.runAsync(
        () => db.altarDao.getRelicPlacedIds([fire.id]),
      );
      expect(placed, contains(fire.id));
      // Set, it carries on into its altar.
      expect(find.byType(BossAltarDetailScreen), findsOneWidget);
    } finally {
      await finish(tester);
    }
  });

  testWidgets('an offering is chosen, held in, and leaves the collection', (
    tester,
  ) async {
    await boot(tester);
    try {
      final kinds = fireKinds();
      await tester.runAsync(() async {
        await db.altarDao.setRelicPlaced(fire.id);
        await db.creatureDao.insertInstance(
          instanceId: 'pip-a',
          baseId: kinds.first,
          statSpeedPotential: 90,
        );
      });
      await tester.pumpWidget(app(BossAltarDetailScreen(boss: fire)));
      await run(tester, 20);
      expect(find.text('0 / ${kinds.length}'), findsOneWidget);

      // The first seat stands at the top of the circle.
      final kind = catalog.getCreatureById(kinds.first)!;
      final label = find.text(kind.name.toUpperCase());
      await tester.tapAt(tester.getTopLeft(label) - const Offset(-30, 34));
      await run(tester, 10);
      expect(find.text('AN OFFERING'), findsOneWidget);
      // Nothing chosen, nothing can be given.
      expect(find.text('CHOOSE ONE TO GIVE'), findsOneWidget);
      await tester.tap(find.textContaining('LV ').first);
      await run(tester, 4);
      await holdText(tester, 'HOLD TO GIVE ${kind.name.toUpperCase()}', 30);
      await run(tester, 20);

      expect(find.text('1 / ${kinds.length}'), findsOneWidget);
      final gone = await tester.runAsync(
        () => db.creatureDao.getInstance('pip-a'),
      );
      expect(gone, isNull);
      final placements = await tester.runAsync(
        () => db.altarDao.getPlacementsForBoss(fire.id),
      );
      expect(placements!.single.speciesId, kinds.first);
      expect(placements.single.snapshotJson, contains('"speedPotential":90'));
    } finally {
      await finish(tester);
    }
  });

  testWidgets('the rite is held, performed and sealed: the Mystic wakes and '
      'its cultivation is placed', (tester) async {
    await boot(tester);
    try {
      final kinds = fireKinds();
      await tester.runAsync(() async {
        await db.altarDao.setRelicPlaced(fire.id);
        for (final k in kinds) {
          await db.altarDao.placeAlchemon(
            bossId: fire.id,
            speciesId: k,
            instanceId: 'gone-$k',
            snapshotJson: '{"scaleVersion":2,"speedPotential":70}',
          );
        }
      });
      var popped = false;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    final r = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => BossAltarDetailScreen(boss: fire),
                      ),
                    );
                    popped = r == true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await run(tester, 24);
      expect(find.text('HOLD TO PERFORM THE RITE'), findsOneWidget);

      await holdText(tester, 'HOLD TO PERFORM THE RITE', 40);
      // Through the pour, the knot and the burst, to the waking.
      await run(tester, 150);
      expect(find.text('MYSTIC AWAKENED'), findsOneWidget);
      expect(find.text('1 OF 17 AWAKE'), findsOneWidget);
      expect(
        find.textContaining('Sealed as a cultivation in your Chamber'),
        findsOneWidget,
      );

      final summoned = await tester.runAsync(
        () => db.settingsDao.getSetting('altar_summoned_${fire.id}'),
      );
      expect(summoned, isNotNull);
      final slots = await tester.runAsync(
        () => db.select(db.incubatorSlots).get(),
      );
      final filled = slots!.where((s) => s.eggId != null).toList();
      expect(
        filled.single.resultCreatureId,
        catalog.mysticByElement('Fire')!.id,
      );
      expect(
        await tester.runAsync(() => db.altarDao.getPlacementsForBoss(fire.id)),
        isEmpty,
      );

      await tester.tap(find.text('SEAL AND DEPART'));
      await run(tester, 50);
      expect(popped, isTrue);
      expect(find.byType(BossAltarDetailScreen), findsNothing);
    } finally {
      await finish(tester);
    }
  });
}
