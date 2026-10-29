import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/vial_infusion.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/vial_infusion_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadNatures();
  });

  test('each step costs more, and a rarer vial more again', () {
    for (final r in VialRarity.values) {
      var last = 0;
      for (final s in InfusionStep.values) {
        expect(infusionCost(s, r), greaterThan(last));
        last = infusionCost(s, r);
      }
    }
    expect(
      infusionCost(InfusionStep.nature, VialRarity.rare),
      greaterThan(infusionCost(InfusionStep.nature, VialRarity.common)),
    );
  });

  test('each reroll of the same step costs 500 more essence', () {
    expect(infusionCost(InfusionStep.nature, VialRarity.common), 1000);
    expect(
      infusionCost(InfusionStep.nature, VialRarity.common, pours: 1),
      1500,
    );
    expect(
      infusionCost(InfusionStep.nature, VialRarity.common, pours: 2),
      2000,
    );
    // Rarity scales the climb too, so rarer vials stay proportionally dear.
    expect(infusionCost(InfusionStep.nature, VialRarity.rare), 4000);
    expect(infusionCost(InfusionStep.nature, VialRarity.rare, pours: 1), 6000);
  });

  test('two natures, two tints, one size come up', () {
    final rng = Random(3);
    for (var i = 0; i < 200; i++) {
      final n = VialInfusion.rollOffer(InfusionStep.nature, rng);
      expect(n, hasLength(2));
      expect(n.toSet(), hasLength(2));
      expect(n.every((id) => NatureCatalog.byId(id) != null), isTrue);
      final t = VialInfusion.rollOffer(InfusionStep.tint, rng);
      expect(t.toSet(), hasLength(2));
      expect(t.every(kInfusionTints.contains), isTrue);
      expect(t, isNot(contains('albino')));
      final s = VialInfusion.rollOffer(InfusionStep.size, rng);
      expect(s, hasLength(1));
      expect(kInfusionSizes.keys, contains(s.single));
    }
  });

  test('taking walks the steps in order and keeps what was taken', () {
    final rng = Random(7);
    var v = const VialInfusion(
      group: ElementalGroup.volcanic,
      rarity: VialRarity.uncommon,
      name: 'Volcanic Vial',
    );
    v = v.poured(rng);
    final nature = v.offer.first;
    v = v.taken(nature);
    expect(v.step, InfusionStep.tint);
    expect(v.offer, isEmpty);
    v = v.poured(rng);
    final tint = v.offer.last;
    v = v.taken(tint);
    v = v.poured(rng);
    final size = v.offer.single;
    v = v.taken(size);
    expect(v.step, InfusionStep.extract);
    expect((v.natureId, v.tint, v.size), (nature, tint, size));
    final back = VialInfusion.deserialise(v.serialise())!;
    expect(back.step, InfusionStep.extract);
    expect((back.natureId, back.tint, back.size), (nature, tint, size));
    expect(back.group, ElementalGroup.volcanic);
    expect(back.rarity, VialRarity.uncommon);
  });

  test(
    'the stand takes only its own essence, and saves what came up',
    () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final svc = VialInfusionService(db, rng: Random(1));
      await db.inventoryDao.addVial(
        'Volcanic Vial',
        ElementalGroup.volcanic,
        VialRarity.common,
      );
      await db.inventoryDao.addVial(
        'Oceanic Vial',
        ElementalGroup.oceanic,
        VialRarity.common,
      );
      final fits = await svc.vialsFor(ElementalGroup.volcanic);
      expect(fits.map((v) => v.group).toSet(), {ElementalGroup.volcanic});

      final set = await svc.set(fits.single);
      expect(set, isNotNull);
      expect(
        await db.inventoryDao.getVialQty(
          ElementalGroup.volcanic,
          VialRarity.common,
          'Volcanic Vial',
        ),
        0,
      );

      // Oceanic essence does not pour into a volcanic vial.
      await db.currencyDao.addResource('res_oceanic', 5000);
      expect(await svc.pour(ElementalGroup.volcanic), isNull);

      // Worn vial, first pour at NATURE: 1000 essence.
      await db.currencyDao.addResource('res_volcanic', 1500);
      final poured = await svc.pour(ElementalGroup.volcanic);
      expect(poured!.offer, hasLength(2));
      expect(poured.pours, 1);
      expect(await db.currencyDao.getResource('res_volcanic'), 500);
      // What came up is kept: reading it again does not roll it again.
      expect((await svc.load(ElementalGroup.volcanic))!.offer, poured.offer);
      // Not enough for a reroll (climbed to 1500): nothing spent.
      expect(await svc.pour(ElementalGroup.volcanic), isNull);
      expect(await db.currencyDao.getResource('res_volcanic'), 500);

      final took = await svc.take(ElementalGroup.volcanic, poured.offer.first);
      expect(took!.step, InfusionStep.tint);

      await svc.takeBack(ElementalGroup.volcanic);
      expect(await svc.load(ElementalGroup.volcanic), isNull);
      expect(
        await db.inventoryDao.getVialQty(
          ElementalGroup.volcanic,
          VialRarity.common,
          'Volcanic Vial',
        ),
        1,
      );
    },
  );

  test('an infused egg carries the nature, tint and size chosen', () {
    final factory = EggPayloadFactory(
      CreatureCatalog.fromList(const []),
      random: Random(5),
    );
    final firelet = Creature(
      id: 'LET01',
      name: 'Firelet',
      types: const ['Fire'],
      rarity: 'Common',
      description: 'Test creature',
      image: 'test.png',
      mutationFamily: 'Let',
    );
    final nature = NatureCatalog.rollable.first.id;
    final payload = factory.createVialPayload(
      firelet,
      vialName: 'Volcanic Vial',
      natureId: nature,
      tint: 'cool',
      size: 'giant',
    );
    expect(payload.natureId, nature);
    expect(payload.natureId2, isNull);
    expect(payload.genetics['tinting'], 'cool');
    expect(payload.genetics['size'], 'giant');
    expect(payload.source, 'vial');
  });
}
