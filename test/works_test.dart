import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/hold_loading.dart';
import 'package:alchemons/games/cosmic/works.dart';
import 'package:flutter_test/flutter_test.dart';

WorkerProfile _w(
  String id, {
  String element = 'Fire',
  double speed = 3,
  double intelligence = 3,
  double strength = 3,
  int harvestRate = 6,
}) => WorkerProfile(
  instanceId: id,
  element: element,
  speed: speed,
  intelligence: intelligence,
  strength: strength,
  harvestRate: harvestRate,
);

const _min = 60000;

void main() {
  group('extractor', () {
    test('a miner fills the hopper at its rate, up to the cap', () {
      final x = ExtractorState(element: 'Fire', updatedMs: 1000, miners: ['m']);
      final works = WorksState(extractors: {'Fire': x});
      final storage = <String, double>{};
      advanceWorks(
        works,
        nowMs: 1000 + 10 * _min,
        storage: storage,
        workers: {'m': _w('m', harvestRate: 6)},
        distanceHome: (_) => 5000,
        scavengeElements: const [],
      );
      expect(x.hopper, closeTo(60, 0.01));
      advanceWorks(
        works,
        nowMs: 1000 + 100 * _min,
        storage: storage,
        workers: {'m': _w('m', harvestRate: 6)},
        distanceHome: (_) => 5000,
        scavengeElements: const [],
      );
      expect(x.hopper, WorkRules.hopperCap(1));
      expect(storage, isEmpty, reason: 'without a courier nothing goes home');
    });

    test('a missing worker is off the job', () {
      final x = ExtractorState(element: 'Fire', updatedMs: 1000, miners: ['m']);
      advanceWorks(
        WorksState(extractors: {'Fire': x}),
        nowMs: 1000 + 10 * _min,
        storage: {},
        workers: const {},
        distanceHome: (_) => 5000,
        scavengeElements: const [],
      );
      expect(x.hopper, 0);
    });

    test('a courier carries the hopper home run by run', () {
      final x = ExtractorState(
        element: 'Water',
        updatedMs: 0,
        tier: 2,
        miners: ['m'],
        courier: 'c',
        hopper: 100,
      );
      final works = WorksState(extractors: {'Water': x});
      final workers = {
        'm': _w('m', element: 'Water', harvestRate: 6),
        'c': _w('c', speed: 3, strength: 3),
      };
      final storage = <String, double>{};
      const distance = 6000.0;
      final cycle = WorkRules.courierCycleMs(distance, 3);
      final load = WorkRules.courierLoad(3);
      x.updatedMs = 1;
      advanceWorks(
        works,
        nowMs: 1,
        storage: storage,
        workers: workers,
        distanceHome: (_) => distance,
        scavengeElements: const [],
      );
      // Its first run has set off with a full load.
      expect(x.cargo, load);
      expect(x.hopper, closeTo(100 - load, 0.01));

      advanceWorks(
        works,
        nowMs: 1 + cycle * 3 + cycle ~/ 2 + 1,
        storage: storage,
        workers: workers,
        distanceHome: (_) => distance,
        scavengeElements: const [],
      );
      // Four runs have reached home.
      expect(storage['Water'], closeTo(load * 4.0, 0.01));
    });

    test('the run cannot carry more than the hopper holds', () {
      final x = ExtractorState(
        element: 'Fire',
        updatedMs: 1,
        tier: 2,
        courier: 'c',
      );
      final storage = <String, double>{};
      advanceWorks(
        WorksState(extractors: {'Fire': x}),
        nowMs: 1 + 50 * _min,
        storage: storage,
        workers: {'c': _w('c')},
        distanceHome: (_) => 3000,
        scavengeElements: const [],
      );
      expect(storage['Fire'] ?? 0, 0);
    });

    test('a long absence catches up as at most three days', () {
      final x = ExtractorState(element: 'Fire', updatedMs: 1, miners: ['m']);
      advanceWorks(
        WorksState(extractors: {'Fire': x}),
        nowMs: 1 + 40 * 24 * 3600 * 1000,
        storage: {},
        workers: {'m': _w('m', harvestRate: 60)},
        distanceHome: (_) => 3000,
        scavengeElements: const [],
      );
      expect(x.hopper, WorkRules.hopperCap(1));
    });

    test('ending a run sends what it carries home', () {
      final x = ExtractorState(
        element: 'Fire',
        updatedMs: 1,
        tier: 2,
        courier: 'c',
        cargo: 20,
        delivered: false,
        cycleStartMs: 1,
        cycleMs: 60000,
      );
      final storage = <String, double>{};
      endCourierRun(x, storage);
      expect(storage['Fire'], 20);
      expect(x.cargo, 0);
    });
  });

  group('scavenger bay', () {
    test('finds fill the crates, then scavengers rest', () {
      final bay = ScavengerBayState(tier: 1);
      bay.slots[0].instanceId = 's';
      final works = WorksState(bay: bay);
      final workers = {'s': _w('s', speed: 3)};
      advanceWorks(
        works,
        nowMs: 1000,
        storage: {},
        workers: workers,
        distanceHome: (_) => 0,
        scavengeElements: const ['Fire', 'Water'],
      );
      expect(bay.slots[0].out, isTrue);
      final trip = WorkRules.scavengerTripMs(3);
      final report = advanceWorks(
        works,
        nowMs: 1000 + trip * 50,
        storage: {},
        workers: workers,
        distanceHome: (_) => 0,
        scavengeElements: const ['Fire', 'Water'],
      );
      expect(bay.crates.length, WorkRules.crateCap(1));
      expect(report.finds, WorkRules.crateCap(1));
      expect(bay.slots[0].out, isFalse);
      for (final c in bay.crates) {
        expect(c.units, WorkRules.scavengerFind(3));
        expect(
          c.elements.keys.every((e) => e == 'Fire' || e == 'Water'),
          isTrue,
        );
      }
    });

    test('collecting empties the crates into storage and sends them out', () {
      final bay = ScavengerBayState(tier: 1);
      bay.slots[0].instanceId = 's';
      bay.crates.addAll([
        const ScavengerFind(elements: {'Fire': 10, 'Dust': 6}, shards: 2),
        const ScavengerFind(elements: {'Fire': 4}),
      ]);
      final storage = <String, double>{'Fire': 1};
      final (got, shards) = collectCrates(
        bay,
        storage,
        nowMs: 5000,
        workers: {'s': _w('s')},
      );
      expect(got, {'Fire': 14, 'Dust': 6});
      expect(shards, 2);
      expect(storage, {'Fire': 15, 'Dust': 6});
      expect(bay.crates, isEmpty);
      expect(bay.slots[0].tripStartMs, 5000);
    });

    test('a find is the same every time it is rolled', () {
      ScavengerFind roll() => rollFind(
        instanceId: 'abc-123',
        trip: 7,
        units: 20,
        shardOdds: 0.3,
        elements: const ['Fire', 'Water', 'Dust'],
      );
      expect(roll().elements, roll().elements);
      expect(roll().shards, roll().shards);
      expect(roll().units, 20);
    });
  });

  group('silver press', () {
    test('presses only what is over the reserve', () {
      final press = SilverPressState(
        tier: 1,
        presser: 'p',
        reserve: 100,
        updatedMs: 1,
      );
      final storage = <String, double>{'Fire': 160, 'Water': 50};
      final report = advanceWorks(
        WorksState(press: press),
        nowMs: 1 + 600 * _min,
        storage: storage,
        workers: {'p': _w('p', strength: 3)},
        distanceHome: (_) => 0,
        scavengeElements: const [],
      );
      expect(storage['Fire'], closeTo(100, 0.01));
      expect(storage['Water'], 50);
      expect(report.silver, 60 ~/ WorkRules.grainsPerSilver);
    });

    test('presses at its rate when there is plenty', () {
      final press = SilverPressState(
        tier: 1,
        presser: 'p',
        reserve: 0,
        updatedMs: 1,
      );
      final storage = <String, double>{'Fire': 5000};
      final report = advanceWorks(
        WorksState(press: press),
        nowMs: 1 + 10 * _min,
        storage: storage,
        workers: {'p': _w('p', strength: 3)},
        distanceHome: (_) => 0,
        scavengeElements: const [],
      );
      final grains = WorkRules.pressRate(3, 1) * 10;
      expect(storage['Fire'], closeTo(5000 - grains, 0.01));
      expect(report.silver, grains ~/ WorkRules.grainsPerSilver);
    });
  });

  group('costs', () {
    test('matter comes off the largest stocks first', () {
      final plan = planMatter(100, {'Fire': 200, 'Water': 80, 'Dust': 10});
      expect(plan!.values.fold(0, (a, b) => a + b), 100);
      expect(plan['Dust'], isNull);
      expect(plan['Fire']!, greaterThan(plan['Water'] ?? 0));
    });

    test('named elements are set aside before matter', () {
      final cost = const WorksCost(elements: {'Fire': 150}, matter: 40);
      final plan = elementsForCost(cost, {'Fire': 170, 'Water': 30});
      // 20 Fire is left over the 150; the two are drawn down to one level.
      expect(plan, {'Fire': 165, 'Water': 25});
      expect(elementsForCost(cost, {'Fire': 170}), isNull);
    });

    test('not enough is null', () {
      expect(planMatter(100, {'Fire': 60, 'Water': 30}), isNull);
    });
  });

  group('state', () {
    test('survives a round trip', () {
      final works = WorksState(
        extractors: {
          'Fire': ExtractorState(
            element: 'Fire',
            updatedMs: 99,
            tier: 2,
            miners: ['a'],
            courier: 'b',
            hopper: 12.5,
          ),
        },
        bay: ScavengerBayState(
          tier: 2,
          crates: [
            const ScavengerFind(elements: {'Ice': 9}, shards: 1),
          ],
        ),
        press: SilverPressState(tier: 1, presser: 'c', reserve: 500),
      );
      works.bay.slots[1].instanceId = 'd';
      final back = WorksState.deserialise(works.serialise());
      expect(back.extractors['Fire']!.courier, 'b');
      expect(back.extractors['Fire']!.hopper, 12.5);
      expect(back.bay.slots.length, 2);
      expect(back.bay.slots[1].instanceId, 'd');
      expect(back.bay.crates.single.elements, {'Ice': 9});
      expect(back.press.reserve, 500);
      expect(back.workerIds, {'a', 'b', 'c', 'd'});
      expect(back.jobOf('b')?.$1, WorkJob.courier);
    });

    test('a broken save is an empty works', () {
      expect(WorksState.deserialise('{nope').isEmpty, isTrue);
    });
  });

  group('loading the hold for a gate', () {
    test('a pure pattern fills the hold with the planet', () {
      final plan = planGateLoad(PlanetRecipe.pure(element: 'Fire'), {
        'Fire': 300,
      });
      expect(plan, {'Fire': 100});
    });

    test('a mixed pattern fills exactly and matches', () {
      const recipe = PlanetRecipe(
        planetElement: 'Steam',
        level: 1,
        components: {'Steam': 55, 'Earth': 37},
        randomPct: 8,
      );
      final plan = planGateLoad(recipe, {
        'Steam': 200,
        'Earth': 200,
        'Dust': 50,
      })!;
      expect(plan.values.fold(0, (a, b) => a + b), 100);
      expect(plan['Dust'], 8);
      final meter = ElementMeter();
      for (final e in plan.entries) {
        meter.add(e.key, e.value.toDouble());
      }
      expect(meter.isFull, isTrue);
      expect(
        recipe.matchScore(meter.breakdown, meter.total),
        closeTo(1.0, 1e-9),
      );
    });

    test('not enough stored is null', () {
      expect(
        planGateLoad(PlanetRecipe.pure(element: 'Fire'), {'Fire': 40}),
        isNull,
      );
    });
  });

  group('refinery', () {
    RefineryState refinery({int tier = 1, int keep = 0}) => RefineryState(
      tier: tier,
      refiner: 'r',
      recipe: 'Fire+Water',
      keep: keep,
      updatedMs: 1,
    );

    test('takes two in equal parts and makes half as much', () {
      final r = refinery();
      final storage = <String, double>{'Fire': 1000, 'Water': 1000};
      final report = advanceWorks(
        WorksState(refinery: r),
        nowMs: 1 + 10 * _min,
        storage: storage,
        workers: {'r': _w('r', intelligence: 3)},
        distanceHome: (_) => 0,
        scavengeElements: const [],
      );
      final taken = WorkRules.refineRate(3) * 10;
      expect(storage['Fire'], closeTo(1000 - taken / 2, 0.01));
      expect(storage['Water'], closeTo(1000 - taken / 2, 0.01));
      expect(storage['Steam'], closeTo(taken * 0.5, 0.01));
      expect(report.refined['Steam'], closeTo(taken * 0.5, 0.01));
    });

    test('never makes more than it takes, at any tier', () {
      for (var tier = 1; tier <= WorkRules.maxTier; tier++) {
        expect(WorkRules.refineYield(tier), lessThanOrEqualTo(1));
      }
      expect(WorkRules.refineYield(3), greaterThan(WorkRules.refineYield(1)));
    });

    test('stops at what it keeps of the scarcer input', () {
      final r = refinery(keep: 50);
      final storage = <String, double>{'Fire': 1000, 'Water': 80};
      advanceWorks(
        WorksState(refinery: r),
        nowMs: 1 + 600 * _min,
        storage: storage,
        workers: {'r': _w('r')},
        distanceHome: (_) => 0,
        scavengeElements: const [],
      );
      expect(storage['Water'], closeTo(50, 0.01));
      expect(storage['Fire'], closeTo(970, 0.01));
      expect(storage['Steam'], closeTo(30, 0.01));
    });

    test('does nothing with no refiner or no recipe', () {
      final storage = <String, double>{'Fire': 100, 'Water': 100};
      advanceWorks(
        WorksState(
          refinery: RefineryState(tier: 1, refiner: 'r', updatedMs: 1),
        ),
        nowMs: 1 + 60 * _min,
        storage: storage,
        workers: {'r': _w('r')},
        distanceHome: (_) => 0,
        scavengeElements: const [],
      );
      expect(storage, {'Fire': 100, 'Water': 100});
    });

    test('every recipe it offers can be found by breeding', () {
      final recipes =
          (jsonDecode(
                    File(
                      'assets/data/alchemons_element_recipes.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['recipes']
              as Map<String, dynamic>;
      for (final e in WorkRules.refineRecipes.entries) {
        final ab = e.key.split('+');
        final pair =
            (recipes['${ab[0]}+${ab[1]}'] ?? recipes['${ab[1]}+${ab[0]}'])
                as Map<String, dynamic>?;
        expect(pair, isNotNull, reason: '${e.key} has no breeding pair');
        expect(pair!.containsKey(e.value), isTrue, reason: e.key);
      }
      expect(WorkRules.refineRecipes.containsKey('Dust+Spirit'), isFalse);
    });
  });

  group('berths', () {
    test('a home has two to six, by the largest size unlocked', () {
      expect(
        [for (var t = 0; t <= 4; t++) homeBerthsForTier(t)],
        [2, 3, 4, 5, 6],
      );
    });

    test('buildings take the first free berth', () {
      final works = WorksState(
        bay: ScavengerBayState(tier: 1, berth: 0),
        refinery: RefineryState(tier: 1, berth: 2),
      );
      expect(works.freeBerth(4), 1);
      expect(works.freeBerth(2), 1);
      works.press
        ..tier = 1
        ..berth = 1;
      expect(works.freeBerth(3), isNull);
      expect(works.berthsUsed, 3);
    });

    test('buildings from before berths each get one of their own', () {
      final works = WorksState(
        bay: ScavengerBayState(tier: 1),
        press: SilverPressState(tier: 1),
      );
      expect(works.bay.berth, isNot(works.press.berth));
      expect({works.bay.berth, works.press.berth}, {0, 1});
      final dup = WorksState(
        bay: ScavengerBayState(tier: 1, berth: 0),
        press: SilverPressState(tier: 1, berth: 0),
      );
      expect({dup.bay.berth, dup.press.berth}, {0, 1});
    });

    test('a refinery survives a round trip', () {
      final works = WorksState(
        refinery: RefineryState(
          tier: 2,
          berth: 3,
          refiner: 'x',
          recipe: 'Air+Fire',
          keep: 200,
          made: 12.5,
        ),
      );
      final back = WorksState.deserialise(works.serialise());
      expect(back.refinery.recipe, 'Air+Fire');
      expect(back.refinery.parts, ('Air', 'Fire', 'Lightning'));
      expect(back.refinery.berth, 3);
      expect(back.jobOf('x')?.$1, WorkJob.refiner);
    });
  });

  group('armory', () {
    test('its tier caps how far the ship\'s upgrades go', () {
      expect(
        [for (var t = 0; t <= 3; t++) WorkRules.armoryPowerCap(t)],
        [0, 2, 4, 5],
      );
      expect(
        [for (var t = 0; t <= 3; t++) WorkRules.armoryTankCap(t)],
        [0, 1, 2, 3],
      );
    });

    test('it stands in a berth and is cheap to start', () {
      final works = WorksState(armory: ArmoryState(tier: 1));
      expect(works.armory.berth, 0);
      expect(works.berthsUsed, 1);
      final cost = worksCost(WorksBuilding.armory, 1);
      expect(cost.silver, 0);
      expect(cost.matter, lessThanOrEqualTo(100));
      final back = WorksState.deserialise(works.serialise());
      expect(back.armory.tier, 1);
      expect(back.armory.berth, 0);
    });

    test('taking a building down frees its berth and its workers', () {
      final works = WorksState(
        bay: ScavengerBayState(tier: 2, berth: 0),
        refinery: RefineryState(
          tier: 1,
          berth: 1,
          refiner: 'r',
          recipe: 'Fire+Water',
        ),
      );
      works.bay.slots[0].instanceId = 's';
      expect(works.freeBerth(2), isNull);
      works.dismantle(WorksBuilding.refinery);
      expect(works.freeBerth(2), 1);
      expect(works.workerIds, {'s'});
      works.dismantle(WorksBuilding.scavengerBay);
      expect(works.workerIds, isEmpty);
      expect(works.bay.slots, isEmpty);
      expect(works.berthsUsed, 0);
    });
  });
}
