import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/show_quick_instance_dialog.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Creature _horn(String id, String name, String type) => Creature(
  id: id,
  name: name,
  types: [type],
  rarity: 'Rare',
  description: 'test',
  image: 'test.png',
  mutationFamily: 'Horn',
  spriteData: SpriteData(
    frameWidth: 1200,
    frameHeight: 1200,
    totalFrames: 4,
    frameDurationMs: 90,
    rows: 1,
    spriteSheetPath: 'creatures/rare/HOR01_firehorn_spritesheet.png',
  ),
);

void main() {
  late AlchemonsDatabase db;
  late CreatureCatalog catalog;
  late List<CreatureInstance> roster;

  setUp(() async {
    db = AlchemonsDatabase(NativeDatabase.memory());
    catalog = CreatureCatalog.fromList([
      _horn('HOR01', 'Firehorn', 'Fire'),
      _horn('HOR02', 'Waterhorn', 'Water'),
    ]);
    for (final (id, base) in const [
      ('a', 'HOR01'),
      ('b', 'HOR01'),
      ('c', 'HOR02'),
    ]) {
      await db.creatureDao.insertInstance(instanceId: id, baseId: base);
    }
    roster = [
      for (final id in const ['a', 'b', 'c'])
        (await db.creatureDao.getInstance(id))!,
    ];
  });

  tearDown(() => db.close());

  // The cards watch the database. Queries started on the test clock only
  // finish when it moves, and closing the database waits on them — so this
  // runs even when a test fails, or tearDown hangs.
  Future<void> drain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
  }

  Future<void> open(
    WidgetTester tester, {
    required int at,
    bool withList = true,
  }) async {
    final theme = FactionTheme.scorchForge();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: theme),
          Provider<CreatureCatalog>.value(value: catalog),
          Provider<StaminaService>.value(value: StaminaService(db)),
          ChangeNotifierProvider<ConstellationEffectsService>.value(
            value: ConstellationEffectsService(db),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showQuickInstanceDialog(
                  context: context,
                  theme: theme,
                  creature: catalog.getCreatureById(roster[at].baseId)!,
                  instance: roster[at],
                  siblings: withList ? roster : null,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> frames(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
  }

  testWidgets('opens on the tapped one and swipes through the list', (
    tester,
  ) async {
    try {
      await open(tester, at: 1);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Firehorn'), findsOneWidget);

      // A swipe left is the next one, of another species, and it lands
      // fast: the default spring took a beat to settle, read as sluggish,
      // and ignores taps on the page until it is done.
      await tester.fling(find.byType(PageView), const Offset(-120, 0), 900);
      final pager = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      var settled = 0;
      while (pager.isScrollingNotifier.value && settled < 90) {
        await tester.pump(const Duration(milliseconds: 16));
        settled++;
      }
      expect(settled, lessThan(26), reason: 'took $settled frames to settle');
      await frames(tester, 3);
      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.text('Waterhorn'), findsOneWidget);

      // The arrow goes back. The card either side is built too: tap the
      // one on screen.
      final arrow = find
          .byIcon(AppIcons.chevron_left_rounded)
          .evaluate()
          .map((e) => tester.getRect(find.byWidget(e.widget)))
          .firstWhere((r) => r.left >= 0);
      await tester.tapAt(arrow.center);
      await frames(tester, 20);
      expect(find.text('2 / 3'), findsOneWidget);
    } finally {
      await drain(tester);
    }
  });

  testWidgets('a card on its own has no counter', (tester) async {
    try {
      await open(tester, at: 0, withList: false);
      expect(find.text('Firehorn'), findsOneWidget);
      expect(find.textContaining(' / '), findsNothing);
    } finally {
      await drain(tester);
    }
  });
}
