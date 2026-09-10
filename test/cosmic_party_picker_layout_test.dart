// Layout regression tests for the cosmic crew loadout console.
//
// Cosmic space runs landscape, and short viewports have cut the bottom off
// cosmic panels before. The old picker also sized its roster grid with a fixed
// four-column count, which on a landscape phone produced tiles taller than the
// grid viewport itself. These pump the panel at the tightest sizes it ships on
// and require a clean layout plus a reachable way out.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_party_picker_overlay.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlchemonsDatabase db;
  late CreatureCatalog catalog;

  setUp(() async {
    db = AlchemonsDatabase(NativeDatabase.memory());
    catalog = CreatureCatalog.fromList([
      Creature(
        id: 'TEST01',
        name: 'Emberling Prime',
        types: const ['Fire'],
        rarity: 'Common',
        description: 'Test creature',
        image: 'test.png',
        baseStats: const SpeciesBaseStats(
          speed: 60,
          intelligence: 60,
          strength: 60,
          beauty: 60,
        ),
      ),
    ]);
    // Enough of a roster that the grid genuinely scrolls.
    for (var i = 0; i < 24; i++) {
      await db.creatureDao.insertInstance(
        instanceId: 'inst-$i',
        baseId: 'TEST01',
        level: i + 1,
      );
    }
  });

  tearDown(() => db.close());

  CosmicPartyMember member(int slot) => CosmicPartyMember(
    instanceId: 'inst-$slot',
    baseId: 'TEST01',
    displayName: 'Emberling Prime',
    element: 'Fire',
    family: 'pip',
    level: 12,
    statSpeed: 40,
    statIntelligence: 40,
    statStrength: 40,
    statBeauty: 40,
    slotIndex: slot,
    staminaBars: 3,
    staminaMax: 3,
  );

  Future<void> pump(
    WidgetTester tester, {
    required Size logical,
    int maxSlots = 3,
    int slotsUnlocked = 2,
  }) async {
    tester.view.physicalSize = Size(logical.width * 2, logical.height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<CreatureCatalog>.value(value: catalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CosmicPartyPickerOverlay(
              slotsUnlocked: slotsUnlocked,
              maxSlots: maxSlots,
              partyMembers: [member(0), null],
              activeSlot: 0,
              onAssign: (_, __) async {},
              onClear: (_) async {},
              onClose: () {},
              onBack: () {},
            ),
          ),
        ),
      ),
    );
    // The instance load is async; the loading spinner never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  }

  testWidgets('landscape phone at 460 lays out with the exit on screen', (
    tester,
  ) async {
    await pump(tester, logical: const Size(900, 460));

    final back = find.text('BACK');
    expect(back, findsOneWidget);
    final rect = tester.getRect(back);
    expect(rect.bottom, lessThanOrEqualTo(460));

    // Rack and roster are both present at once — no mode switch.
    expect(find.text('SLOTS'), findsOneWidget);
    expect(find.textContaining('ROSTER'), findsOneWidget);
  });

  testWidgets('short landscape viewport still fits', (tester) async {
    await pump(tester, logical: const Size(780, 380));
    final rect = tester.getRect(find.text('BACK'));
    expect(rect.bottom, lessThanOrEqualTo(380));
  });

  testWidgets('nine garrison slots do not overflow the rack', (tester) async {
    await pump(
      tester,
      logical: const Size(900, 460),
      maxSlots: 9,
      slotsUnlocked: 9,
    );
    expect(find.text('BACK'), findsOneWidget);
  });

  testWidgets('narrow portrait folds the rack above the roster', (
    tester,
  ) async {
    await pump(tester, logical: const Size(360, 740));
    expect(find.text('SLOTS'), findsOneWidget);
    expect(find.text('BACK'), findsOneWidget);
  });

  testWidgets('roster tiles stay tile-sized on a wide viewport', (
    tester,
  ) async {
    await pump(tester, logical: const Size(900, 460));
    // The old fixed four-column grid produced ~210x280 cards here.
    final tiles = find.byType(GridView);
    expect(tiles, findsOneWidget);
    final grid = tester.widget<GridView>(tiles);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
    expect(delegate.maxCrossAxisExtent, lessThanOrEqualTo(96));
    expect(delegate.mainAxisExtent, isNotNull);
    expect(delegate.mainAxisExtent, lessThanOrEqualTo(96));
  });
}
