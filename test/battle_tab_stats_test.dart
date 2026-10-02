library;

import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
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

  Future<void> pumpBattleTab(
    WidgetTester tester,
    String family, {
    db.CreatureInstance? instance,
  }) async {
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
              instance: instance ?? _instance(),
            ),
          ),
        ),
      ),
    );
    // pumpAndSettle never returns: the tab hosts a repeating animation.
    await tester.pump(const Duration(milliseconds: 400));
  }

  AlchemonCombatStats expectedStats(String family, db.CreatureInstance i) =>
      deriveAlchemonCombatStats(
        member: CosmicPartyMember(
          instanceId: i.instanceId,
          baseId: i.baseId,
          displayName: 'Test',
          family: family,
          element: 'Fire',
          level: i.level,
          statStrength: i.statStrength,
          statIntelligence: i.statIntelligence,
          statSpeed: i.statSpeed,
          statBeauty: i.statBeauty,
          slotIndex: 0,
          staminaBars: 3,
          staminaMax: 3,
        ),
      );

  testWidgets('one stat sheet, each number naming the stats behind it', (
    tester,
  ) async {
    await pumpBattleTab(tester, 'Pip');

    for (final label in [
      'HP',
      'P-ATK',
      'E-ATK',
      'SPECIAL',
      'P-DEF',
      'E-DEF',
      'ATTACKS',
      'SPECIAL CD',
      'RANGE',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'missing $label tile');
    }
    // Sources come from the shared stat contract, strongest share first.
    expect(find.text('STR·INT'), findsNWidgets(2)); // HP and P-DEF
    expect(find.text('BEA·INT'), findsOneWidget); // E-DEF
    expect(find.text('SPD·STR'), findsOneWidget); // auto-attack rate
    expect(find.text('STR·BEA'), findsOneWidget); // a Pip's SPECIAL
    // Nothing rolls critical hits, and there is no longer a mode to pick:
    // every mode builds the creature from the same numbers.
    expect(find.text('CRIT'), findsNothing);
    expect(find.text('Cosmic Space'), findsNothing);
    expect(find.byType(SegmentedButton<bool>), findsNothing);

    final stats = expectedStats('Pip', _instance());
    expect(find.text('${stats.maxHp}'), findsOneWidget);
    expect(find.text('${stats.physAtk}'), findsWidgets);

    // The bridge from ratings to roles: every stat says what it feeds.
    expect(find.text('WHAT EACH STAT DOES'), findsOneWidget);
    for (final stat in ['STRENGTH', 'INTELLIGENCE', 'BEAUTY', 'SPEED']) {
      expect(find.text(stat), findsOneWidget);
    }
    // Strength 4.4 is this specimen's best stat.
    expect(find.text('440 · best'), findsOneWidget);
    expect(find.textContaining('special power 55%'), findsOneWidget);
    expect(find.textContaining('special power 45%'), findsOneWidget);

    expect(find.text('PREVIEW ABILITIES'), findsOneWidget);

    // Persistent modifiers live in one bottom section, grouped by source, and
    // only the boosts this specimen has are listed.
    expect(find.text('Boosts'), findsOneWidget);
    expect(find.text('NATURE'), findsNothing);
    expect(find.text('ENHANCEMENT'), findsNothing);
    expect(find.text('PURITY · PURE'), findsOneWidget);
    expect(find.text('COMBAT CONSTELLATION'), findsNothing);
    expect(find.text('FAMILY FRAME · PIP'), findsOneWidget);
    expect(find.textContaining('HP −20%'), findsOneWidget);

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

  testWidgets('special power follows family stats instead of Beauty alone', (
    tester,
  ) async {
    await pumpBattleTab(tester, 'Mane');
    final stats = expectedStats('Mane', _instance());
    expect(stats.abilityAtk, greaterThan(stats.elemAtk));
    final tile = find
        .ancestor(of: find.text('SPECIAL'), matching: find.byType(Column))
        .first;
    expect(
      find.descendant(of: tile, matching: find.text('${stats.abilityAtk}')),
      findsOneWidget,
    );
    expect(
      find.text('SPECIAL, from Strength 80% · Intelligence 20%.'),
      findsOneWidget,
    );
  });

  testWidgets('reported HP and DEF include the family frame', (tester) async {
    final instance = _instance();
    final horn = expectedStats('Horn', instance);
    final pip = expectedStats('Pip', instance);
    expect(horn.maxHp, greaterThan(pip.maxHp));

    await pumpBattleTab(tester, 'Horn');
    expect(find.text('${horn.maxHp}'), findsOneWidget);
    expect(find.text('FAMILY FRAME · HORN'), findsOneWidget);
    expect(find.textContaining('HP +40%'), findsOneWidget);

    await pumpBattleTab(tester, 'Pip');
    expect(find.text('${pip.maxHp}'), findsOneWidget);
    expect(find.textContaining('Special range +5%'), findsOneWidget);
  });

  testWidgets('a Mystic says its world is a Survival ability only', (tester) async {
    await pumpBattleTab(tester, 'Mystic');
    expect(
      find.textContaining(
        'in Cosmic Space and the planet dungeons a Mystic fights with its '
        'auto attack',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the stats block fits a 360pt-wide phone', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final family in [
      'Horn',
      'Wing',
      'Let',
      'Mask',
      'Kin',
      'Pip',
      'Mystic',
    ]) {
      await pumpBattleTab(tester, family);
      expect(
        tester.takeException(),
        isNull,
        reason: '$family overflowed at 360pt',
      );
    }
  });
}
