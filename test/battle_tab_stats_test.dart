library;

import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/battle_tab.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Creature _species(String family) => Creature(
  id: 'TST_$family',
  name: '$family Specimen',
  types: const ['Fire'],
  rarity: 'common',
  description: 'test',
  image: 'creatures/common/preview.png',
  mutationFamily: family,
);

db.CreatureInstance _instance() => db.CreatureInstance(
  instanceId: 'i1',
  baseId: 'TST01',
  level: 7,
  xp: 0,
  locked: false,
  isPrismaticSkin: false,
  source: 'test',
  staminaMax: 3,
  staminaBars: 3,
  staminaLastUtcMs: 0,
  createdAtUtcMs: 0,
  statSpeed: 2.1,
  statIntelligence: 3.85,
  statStrength: 4.4,
  statBeauty: 1.6,
  statSpeedPotential: 40,
  statIntelligencePotential: 72,
  statStrengthPotential: 88,
  statBeautyPotential: 30,
  statSpeedEnhancement: 0,
  statIntelligenceEnhancement: 0,
  statStrengthEnhancement: 0,
  statBeautyEnhancement: 0,
  generationDepth: 0,
  isPure: true,
  isFavorite: false,
);

void main() {
  late db.AlchemonsDatabase database;

  setUp(() {
    database = db.AlchemonsDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpBattleTab(WidgetTester tester, String family) async {
    final theme = FactionTheme.scorchForge();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<db.AlchemonsDatabase>.value(value: database),
          Provider<FactionTheme>.value(value: theme),
          ChangeNotifierProvider<ConstellationEffectsService>.value(
            value: ConstellationEffectsService(database),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ImprovedBattleScrollArea(
              theme: theme,
              creature: _species(family),
              instance: _instance(),
            ),
          ),
        ),
      ),
    );
    // pumpAndSettle never returns: the tab hosts a repeating animation.
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the stat grid names the genetic stat behind every number', (
    tester,
  ) async {
    await pumpBattleTab(tester, 'Pip');

    // Every derived figure carries its source, and RANGE — intelligence's
    // most legible contribution — is present rather than invisible.
    for (final label in ['HP', 'P-ATK', 'E-ATK', 'RANGE', 'CD', 'CRIT']) {
      expect(find.text(label), findsOneWidget, reason: 'missing $label tile');
    }
    expect(find.text('STR-INT'), findsNWidgets(2)); // HP and P-DEF
    expect(find.text('BEA-INT'), findsOneWidget); // E-DEF
    expect(find.text('SPD'), findsOneWidget); // CD

    // Speed 2.1 gives a cooldown-reduction factor below 1.0, which divides
    // the base cooldown — so the tile must read above x1.00, not below it.
    final cdr = CosmicBalance.companionCooldownReduction(2.1);
    expect(cdr, lessThan(1.0));
    expect(find.text('×${(1 / cdr).toStringAsFixed(2)}'), findsOneWidget);

    // The live preview sits over the grid.
    expect(find.text('PREVIEW ABILITIES'), findsOneWidget);

    // Persistent modifiers live in one bottom section, grouped by source, and
    // only the boosts this specimen has are listed: no nature, no enhancement
    // and no constellation rows for a specimen that has none of them.
    expect(find.text('Boosts'), findsOneWidget);
    expect(find.text('NATURE'), findsNothing);
    expect(find.text('No Nature boost'), findsNothing);
    expect(find.text('ENHANCEMENT'), findsNothing);
    expect(find.text('PURITY · PURE'), findsOneWidget);
    expect(find.text('COMBAT CONSTELLATION'), findsNothing);
    expect(find.text('FAMILY FRAME · PIP'), findsOneWidget);
    expect(find.textContaining('Ratings past 500'), findsNothing);

    // The attack cards follow the grid before role and boost details.
    expect(find.text('Auto Attack'), findsOneWidget);
    expect(find.text('Special Ability'), findsOneWidget);
    expect(find.text('Survival'), findsNothing);
    final visibleLabels = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList(growable: false);
    expect(
      visibleLabels.indexOf('Auto Attack'),
      lessThan(visibleLabels.indexOf('Special Ability')),
    );
    expect(
      visibleLabels.indexOf('Special Ability'),
      lessThan(visibleLabels.indexOf('Role')),
    );
    expect(
      visibleLabels.indexOf('Role'),
      lessThan(visibleLabels.indexOf('Boosts')),
    );
  });

  testWidgets('reported HP and DEF include the family shape modifiers', (
    tester,
  ) async {
    final instance = _instance();
    final baseHp = CosmicBalance.companionMaxHp(
      level: instance.level,
      strength: instance.statStrength,
      intelligence: instance.statIntelligence,
    );
    final hornHp = (baseHp * CosmicBalance.familyHpMultiplier('Horn')).round();
    expect(hornHp, greaterThan(baseHp), reason: 'horn multiplier is not 1.0');

    // A Horn's summoned companion gets +30% HP and +20% DEF; the tab used to
    // print the unmodified figures, understating every tank it described.
    await pumpBattleTab(tester, 'Horn');
    expect(find.text('$hornHp'), findsOneWidget);
    expect(find.text('$baseHp'), findsNothing);
    expect(find.text('FAMILY FRAME · HORN'), findsOneWidget);
    expect(find.textContaining('HP +30%'), findsOneWidget);

    await pumpBattleTab(tester, 'Pip');
    expect(find.text('$baseHp'), findsOneWidget);
    expect(find.text('FAMILY FRAME · PIP'), findsOneWidget);
    expect(find.textContaining('Special range +20%'), findsOneWidget);
  });

  testWidgets('the stats block fits a 360pt-wide phone', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final family in ['Horn', 'Wing', 'Let', 'Mask', 'Kin', 'Pip']) {
      await pumpBattleTab(tester, family);
      expect(
        tester.takeException(),
        isNull,
        reason: '$family overflowed at 360pt',
      );
    }
  });
}
