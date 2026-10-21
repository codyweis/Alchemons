import 'dart:convert';
import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/breeding_config_loaders.dart';
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/breeding_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/services/wild_breed_randomizer.dart';
import 'package:alchemons/utils/cultivation_time.dart';
import 'package:alchemons/utils/instance_stat_traits.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The mutation meter: each wilderness fusion that doesn't mutate raises the
// chance that the next does, a full meter makes it certain, and a mutation
// empties it. Six mutations, each with its own perk; Prismatic is one of
// them now, not a skin.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the chance', () {
    test('0.5% empty, about 2% half full, 10% one short, certain full', () {
      expect(mutationChance(0), closeTo(0.005, 1e-9));
      expect(mutationChance(50), closeTo(0.02, 0.0015));
      expect(mutationChance(99), closeTo(0.10, 1e-9));
      expect(mutationChance(kMutationMeterNotches), 1.0);
      expect(mutationChance(500), 1.0);
    });

    test('it only ever rises', () {
      for (var n = 1; n <= kMutationMeterNotches; n++) {
        expect(mutationChance(n), greaterThan(mutationChance(n - 1)));
      }
    });

    test('an empty meter: about one in two hundred, spread over all six', () {
      final rng = Random(7);
      final counts = <AlchemonMutation?, int>{};
      const n = 600000;
      for (var i = 0; i < n; i++) {
        final m = AlchemonMutation.roll(rng);
        counts[m] = (counts[m] ?? 0) + 1;
      }
      for (final m in AlchemonMutation.values) {
        expect(counts[m]! / n, closeTo(0.005 / 6, 0.0003));
      }
    });

    test('a full meter always mutates', () {
      final rng = Random(3);
      for (var i = 0; i < 2000; i++) {
        expect(
          AlchemonMutation.roll(rng, notches: kMutationMeterNotches),
          isNotNull,
        );
      }
    });

    test('ids round-trip, and every mutation has a perk', () {
      expect(AlchemonMutation.values, hasLength(6));
      for (final m in AlchemonMutation.values) {
        expect(AlchemonMutation.byId(m.id), m);
        expect(m.perk, isNotEmpty);
      }
      expect(AlchemonMutation.byId('opalite'), isNull);
    });
  });

  test('the old prismatic flag reads as the mutation, never over another', () {
    expect(prismaticMutation(true, null), isTrue);
    expect(prismaticMutation(true, ''), isTrue);
    expect(prismaticMutation(false, 'prismatic'), isTrue);
    expect(prismaticMutation(true, 'alchemized'), isFalse);
    expect(prismaticMutation(false, null), isFalse);
  });

  test('an Obsidian parent halves the extraction time', () {
    const base = Duration(hours: 4);
    expect(cultivationDuration(base: base), base);
    expect(
      cultivationDuration(base: base, obsidianParent: true),
      const Duration(hours: 2),
    );
  });

  group('saved Alchemons', () {
    late AlchemonsDatabase db;
    setUp(() => db = AlchemonsDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> raw(String id, {required bool flag, String? mutation}) =>
        db.customStatement(
          'INSERT INTO creature_instances '
          '(instance_id, base_id, is_prismatic_skin, mutation) '
          "VALUES ('$id', 'LET02', ${flag ? 1 : 0}, "
          "${mutation == null ? 'NULL' : "'$mutation'"})",
        );

    test('a prismatic becomes the mutation; a mutated one keeps its own', () async {
      await raw('p', flag: true);
      await raw('a', flag: true, mutation: 'alchemized');
      await raw('n', flag: false);
      await db.movePrismaticToMutation();

      final p = await db.creatureDao.getInstance('p');
      expect(p!.mutation, 'prismatic');
      expect(p.isPrismaticSkin, isTrue, reason: 'the flag mirrors it');
      final a = await db.creatureDao.getInstance('a');
      expect(a!.mutation, 'alchemized');
      expect(a.isPrismaticSkin, isFalse);
      final n = await db.creatureDao.getInstance('n');
      expect(n!.mutation, isNull);
    });

    test('a new row with only the old flag is saved as the mutation', () async {
      await db.creatureDao.insertInstance(
        instanceId: 'r',
        baseId: 'LET02',
        isPrismaticSkin: true,
      );
      final r = await db.creatureDao.getInstance('r');
      expect(r!.mutation, 'prismatic');
      expect(r.isPrismaticSkin, isTrue);

      await db.creatureDao.insertInstance(
        instanceId: 's',
        baseId: 'LET02',
        mutation: 'starlit',
      );
      final s = await db.creatureDao.getInstance('s');
      expect(s!.mutation, 'starlit');
      expect(s.isPrismaticSkin, isFalse);
    });

    test('a Prismatic has +1% in every stat', () async {
      await db.creatureDao.insertInstance(
        instanceId: 'y',
        baseId: 'LET02',
        mutation: 'prismatic',
      );
      final prism = (await db.creatureDao.getInstance('y'))!;
      // The same Alchemon unmutated (its id seeds its purity roll, so it is
      // compared with itself).
      final plain = prism.copyWith(mutation: const Value(null));
      for (final stat in ['speed', 'intelligence', 'strength', 'beauty']) {
        expect(
          instanceTraitMultiplier(prism, stat),
          closeTo(
            instanceTraitMultiplier(plain, stat) * (1 + kPrismaticStatBonus),
            1e-9,
          ),
        );
      }
    });
  });

  group('the meter, through a wild fusion', () {
    late CreatureCatalog catalog;
    late ElementRecipeConfig elementRecipes;
    late FamilyRecipeConfig familyRecipes;

    setUpAll(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      await loadNatures();
      await GeneticsCatalog.load();
      final rawJson = await rootBundle.loadString(
        'assets/data/alchemons_creatures.json',
      );
      catalog = CreatureCatalog.fromList([
        for (final c
            in ((jsonDecode(rawJson) as Map<String, dynamic>)['creatures']
                    as List)
                .cast<Map<String, dynamic>>())
          Creature.fromJson(c),
      ]);
      elementRecipes = await loadElementRecipes();
      familyRecipes = await loadFamilyRecipes();
    });

    late AlchemonsDatabase db;
    late BreedingServiceV2 breeding;
    late ConstellationEffectsService effects;

    Future<void> build({required bool meter}) async {
      SharedPreferences.setMockInitialValues({});
      db = AlchemonsDatabase(NativeDatabase.memory());
      if (meter) await db.constellationDao.unlockSkill(kMutationMeterSkillId, 0);
      effects = ConstellationEffectsService(db);
      // Its first read of the unlocks is asynchronous.
      for (var i = 0; i < 20 && effects.hasMutationMeter() != meter; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      breeding = BreedingServiceV2(
        gameData: GameDataService(db: db, catalog: catalog),
        db: db,
        engine: BreedingEngine(
          catalog,
          elementRecipes: elementRecipes,
          familyRecipes: familyRecipes,
          tuning: const BreedingTuning(),
        ),
        payloadFactory: EggPayloadFactory(catalog),
        wildRandomizer: WildCreatureRandomizer(),
        constellation: effects,
        factions: FactionService(db),
        boosts: TimedBoostService(db.settingsDao),
      );
      await db.creatureDao.insertInstance(instanceId: 'own', baseId: 'LET02');
    }

    tearDown(() => db.close());

    // An RNG whose every roll lands high: never a mutation below full.
    Random never() => _Fixed(0.999);

    Future<EggCreationResult> fuse({
      bool field = true,
      AlchemonMutation? forced,
      bool forcePrismatic = false,
    }) async {
      final own = (await db.creatureDao.getInstance('own'))!;
      return breeding.breedWithWild(
        own,
        catalog.getCreatureById('LET02')!,
        fieldMutations: field,
        mutationRng: never(),
        forcedMutation: forced,
        forcePrismatic: forcePrismatic,
      );
    }

    test('without its node the meter never moves', () async {
      await build(meter: false);
      final r = await fuse();
      expect(r.success, isTrue);
      expect(r.mutation, isNull);
      expect(await db.settingsDao.getMutationMeter(), 0);
    });

    test('each fusion adds a notch; a mutation empties it', () async {
      await build(meter: true);
      for (var i = 1; i <= 3; i++) {
        final r = await fuse();
        expect(r.success, isTrue);
        expect(r.mutation, isNull);
        expect(await db.settingsDao.getMutationMeter(), i);
      }
      final hit = await fuse(forced: AlchemonMutation.obsidian);
      expect(hit.mutation, AlchemonMutation.obsidian);
      expect(await db.settingsDao.getMutationMeter(), 0);
    });

    test('a full meter makes the next fusion mutate', () async {
      await build(meter: true);
      await db.settingsDao.setMutationMeter(kMutationMeterNotches);
      final r = await fuse();
      expect(r.mutation, isNotNull);
      expect(await db.settingsDao.getMutationMeter(), 0);
    });

    test('space fusions neither mutate nor fill it', () async {
      await build(meter: true);
      await db.settingsDao.setMutationMeter(kMutationMeterNotches);
      final r = await fuse(field: false);
      expect(r.mutation, isNull);
      expect(await db.settingsDao.getMutationMeter(), kMutationMeterNotches);
    });

    test('a void-bred fusion is always Prismatic', () async {
      await build(meter: false);
      final r = await fuse(field: false, forcePrismatic: true);
      expect(r.mutation, AlchemonMutation.prismatic);
    });
  });
}

class _Fixed implements Random {
  _Fixed(this.v);
  final double v;
  @override
  double nextDouble() => v;
  @override
  int nextInt(int max) => (v * max).floor().clamp(0, max - 1);
  @override
  bool nextBool() => v >= 0.5;
}
