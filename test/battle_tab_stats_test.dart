library;

import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/battle_tab.dart';
import 'package:alchemons/screens/ability_preview_screen.dart';
import 'package:drift/native.dart';
import 'package:flame/game.dart';
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
              liveStage: false,
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

  testWidgets('one sheet: the attacks, the stats and the gauges they feed', (
    tester,
  ) async {
    await pumpBattleTab(tester, 'Pip');

    // The two attacks, with how often each comes round.
    expect(find.text('AUTO ATTACK'), findsOneWidget);
    expect(find.text('SPECIAL'), findsNWidgets(2)); // the row and its gauge
    expect(find.textContaining('every '), findsNWidgets(2));
    // The stage's frame is there; the arena itself is off in tests.
    expect(find.text('FULL VIEW'), findsOneWidget);
    expect(find.byType(GameWidget<AbilityPreviewGame>), findsNothing);

    // Every combat number as a gauge.
    for (final label in ['HP', 'P-ATK', 'E-ATK', 'P-DEF', 'E-DEF', 'RANGE']) {
      expect(find.text(label), findsOneWidget, reason: 'missing $label gauge');
    }
    final stats = expectedStats('Pip', _instance());
    for (final v in [
      stats.maxHp,
      stats.physAtk,
      stats.abilityAtk,
      stats.physDef,
      stats.elemDef,
    ]) {
      expect(find.text('$v'), findsWidgets);
    }

    // Nothing rolls critical hits, and there is no mode to pick: every mode
    // builds the creature from the same numbers.
    expect(find.text('CRIT'), findsNothing);
    expect(find.text('Cosmic Space'), findsNothing);
    expect(find.byType(SegmentedButton<bool>), findsNothing);

    // The four stats as chips; Strength 4.4 is this specimen's best, so it
    // starts picked and the gauges show its share of each.
    for (final (abbrev, rating) in [
      ('STR', '440'),
      ('INT', '385'),
      ('BEA', '160'),
      ('SPD', '210'),
    ]) {
      expect(find.text(abbrev), findsWidgets); // chip, and a gauge source
      expect(find.text(rating), findsWidgets);
    }
    expect(find.text('BEST'), findsOneWidget);
    expect(find.text('STRENGTH · 440 · BEST'), findsOneWidget);
    expect(find.text('STR 68%'), findsOneWidget); // HP
    expect(find.text('STR 55%'), findsOneWidget); // a Pip's SPECIAL
    expect(find.text('STR 63%'), findsOneWidget); // P-DEF
    expect(find.text('BEA·INT'), findsOneWidget); // E-DEF, not Strength's
    expect(find.textContaining('special power 55%'), findsOneWidget);

    // Picking another stat moves the dock and the shares with it.
    await tester.tap(find.text('385').first); // the INT chip
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('INTELLIGENCE · 385'), findsOneWidget);
    expect(find.text('INT 32%'), findsOneWidget); // HP
    expect(find.textContaining('reach ('), findsOneWidget);

    // Picking an attack explains it in the same dock.
    await tester.tap(find.text('AUTO ATTACK'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('P-ATK per hit, from Strength.'), findsOneWidget);
    await tester.tap(find.text('SPECIAL').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('SPECIAL, from Strength 55% · Beauty 45%.'),
      findsOneWidget,
    );

    // Persistent modifiers at the foot, only the ones this specimen has.
    expect(find.text('BOOSTS'), findsOneWidget);
    expect(find.text('NATURE'), findsNothing);
    expect(find.text('ENHANCEMENT'), findsNothing);
    expect(find.text('PURITY · PURE'), findsOneWidget);
    expect(find.text('COMBAT CONSTELLATION'), findsNothing);
    expect(find.text('FAMILY FRAME · PIP'), findsOneWidget);
    expect(find.textContaining('HP −20%'), findsOneWidget);
  });

  testWidgets('special power follows family stats instead of Beauty alone', (
    tester,
  ) async {
    await pumpBattleTab(tester, 'Mane');
    final stats = expectedStats('Mane', _instance());
    expect(stats.abilityAtk, greaterThan(stats.elemAtk));
    expect(find.text('${stats.abilityAtk}'), findsOneWidget);
    await tester.tap(find.text('SPECIAL').first);
    await tester.pump(const Duration(milliseconds: 300));
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

  testWidgets('a Mystic says its world is a Survival ability only', (
    tester,
  ) async {
    await pumpBattleTab(tester, 'Mystic');
    await tester.tap(find.text('SPECIAL').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.textContaining(
        'in Cosmic Space and the planet dungeons a Mystic fights with its '
        'auto attack',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the sheet fits a 360pt-wide phone', (tester) async {
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
      'Mane',
      'Mystic',
    ]) {
      await pumpBattleTab(tester, family);
      expect(
        tester.takeException(),
        isNull,
        reason: '$family overflowed at 360pt',
      );
      await tester.tap(find.text('SPECIAL').first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '$family special dock');
    }
  });
}
