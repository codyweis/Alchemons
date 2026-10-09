import 'dart:convert';
import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/utils/alchemy_effect_apply.dart';
import 'package:alchemons/widgets/fx/alchemical_sunglasses.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:drift/native.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlchemonsDatabase db;
  late ShopService shop;
  setUp(() async {
    db = AlchemonsDatabase(NativeDatabase.memory());
    shop = ShopService(
      db,
      ConstellationEffectsService(db),
      FactionService(db),
      TimedBoostService(db.settingsDao),
    );
    await shop.reloadFromStorage();
    await db.settingsDao.setSetting('wallet_gold', '100');
    for (final entry in {
      'wing': 'WNG04',
      'wing2': 'WNG01',
      'pip': 'PIP01',
      'horn': 'HOR03',
      'let': 'LET02',
      'mane': 'MAN01',
    }.entries) {
      await db.creatureDao.insertInstance(
        instanceId: entry.key,
        baseId: entry.value,
      );
    }
  });
  tearDown(() async {
    shop.dispose();
    await db.close();
  });
  const hat = FamilyCostume.partyHat,
      nose = FamilyCostume.nose,
      glasses = FamilyCostume.sunglasses;
  Future<bool> wear(String id, FamilyCostume costume, [Color? color]) =>
      wearCostume(db, instanceId: id, costume: costume, color: color);
  Future<bool> takeOff(String id, FamilyCostume costume) =>
      takeOffCostume(db, instanceId: id, costume: costume);
  Future<String?> costumes(String id) async =>
      (await db.creatureDao.getInstance(id))?.costumes;
  Future<String?> effect(String id) async =>
      (await db.creatureDao.getInstance(id))?.alchemyEffect;
  Future<int> owned(String item) => db.inventoryDao.getItemQty(item);
  Future<void> buyAll() async {
    for (final c in FamilyCostume.values) {
      await shop.purchase(c.offerId);
    }
  }

  test('bought like any effect: one each, as many as are paid for', () async {
    expect(await shop.purchase(hat.offerId), true);
    expect(await shop.purchase(hat.offerId, qty: 2), true);
    expect(await owned(InvKeys.alchemyCelebration), 3);
    expect((await db.currencyDao.getAllCurrencies())['gold'], 70);
    await shop.reloadFromStorage();
    expect(shop.getPurchaseStatus(hat.offerId), isNot('OWNED'));
    expect(await shop.purchase(nose.offerId), true);
    expect(await owned(InvKeys.alchemyNose), 1);
    expect(await shop.purchase(glasses.offerId), true);
    expect(await owned(InvKeys.alchemySunglasses), 1);
  });

  test('the shop keeps costumes apart from effects', () {
    final effects = shop.getAlchemyEffectOffers().map((o) => o.id);
    final offered = shop.getCostumeOffers().map((o) => o.id);
    expect(offered, [for (final c in FamilyCostume.values) c.offerId]);
    expect(effects.toSet().intersection(offered.toSet()), isEmpty);
  });

  test('all three at once, beside an effect', () async {
    await buyAll();
    await db.inventoryDao.addItemQty(InvKeys.alchemyGlow, 1);
    expect(
      await applyAlchemyEffect(
        db,
        instanceId: 'pip',
        itemKey: InvKeys.alchemyGlow,
      ),
      true,
    );
    const teal = Color(0xFF1FB5B0);
    expect(await wear('pip', hat), true);
    expect(await wear('pip', nose, teal), true);
    expect(await wear('pip', glasses), true);
    expect(await effect('pip'), 'alchemy_glow');
    expect(await costumes('pip'), 'PIP01:hat,nose#1FB5B0,sunglasses');
    for (final c in FamilyCostume.values) {
      expect(await owned(c.itemKey), 0);
    }
    final worn = WornCostumes.parse(await costumes('pip'))!;
    expect(worn.species, 'PIP01');
    expect(worn.colorOf(nose), teal);
    expect(worn.colorOf(hat), hat.defaultColor);
    // Swapping the effect leaves the costumes on.
    await db.inventoryDao.addItemQty(InvKeys.alchemyVoidRift, 1);
    await applyAlchemyEffect(
      db,
      instanceId: 'pip',
      itemKey: InvKeys.alchemyVoidRift,
    );
    expect(await costumes('pip'), 'PIP01:hat,nose#1FB5B0,sunglasses');
    expect(await owned(InvKeys.alchemyGlow), 1);
    // Taking one off returns only that one.
    expect(await takeOff('pip', nose), true);
    expect(await costumes('pip'), 'PIP01:hat,sunglasses');
    expect(await owned(InvKeys.alchemyNose), 1);
    expect(await takeOff('pip', nose), false);
    await takeOff('pip', hat);
    await takeOff('pip', glasses);
    expect(await costumes('pip'), null);
    expect(await effect('pip'), 'void_rift');
  });

  test('one dresses one creature; more need more', () async {
    await shop.purchase(hat.offerId);
    expect(await wear('wing', hat), true);
    expect(await owned(InvKeys.alchemyCelebration), 0);
    // None left for the second Wing until another is bought.
    expect(await wear('wing2', hat), false);
    expect(await costumes('wing2'), null);
    await shop.purchase(hat.offerId);
    expect(await wear('wing2', hat), true);
    expect(await owned(InvKeys.alchemyCelebration), 0);
  });

  test('a costume goes on a species it fits, and never as an effect', () async {
    await buyAll();
    // Every family fitted wears every costume.
    for (final id in ['wing', 'pip', 'horn', 'let']) {
      for (final c in FamilyCostume.values) {
        await db.inventoryDao.addItemQty(c.itemKey, 1);
        expect(await wear(id, c), true, reason: '$id ${c.tag}');
      }
    }
    // Not yet one that has not been fitted.
    expect(await wear('mane', hat), false);
    expect(await wear('missing', hat), false);
    // The effect slot will not take one.
    expect(
      await applyAlchemyEffect(
        db,
        instanceId: 'mane',
        itemKey: InvKeys.alchemyCelebration,
      ),
      false,
    );
    expect(await effect('mane'), null);
    for (final c in FamilyCostume.values) {
      expect(await owned(c.itemKey), 1);
    }
    expect(FamilyCostume.fittedFamiliesText, 'Wings, Pips, Horns and Lets');
  });

  test(
    'a costume changes color free, and back to its own saves plain',
    () async {
      const ruby = Color(0xFF8A2338), amber = Color(0xFF8C5A14);
      await shop.purchase(glasses.offerId);
      expect(await wear('horn', glasses, amber), true);
      expect(await costumes('horn'), 'HOR03:sunglasses#8C5A14');
      // Put on again in another color: the same pair, no second one spent.
      await shop.purchase(glasses.offerId);
      expect(await wear('horn', glasses, ruby), true);
      expect(await owned(InvKeys.alchemySunglasses), 1);
      expect(
        await recolorCostume(
          db,
          instanceId: 'horn',
          costume: glasses,
          color: glasses.defaultColor,
        ),
        true,
      );
      expect(await costumes('horn'), 'HOR03:sunglasses');
      // Only something wearing it can be recolored.
      expect(
        await recolorCostume(db, instanceId: 'horn', costume: hat, color: ruby),
        false,
      );
      expect(
        await recolorCostume(db, instanceId: 'let', costume: hat, color: ruby),
        false,
      );
    },
  );

  test('a saved string reads back only what fits, in colors that read', () {
    expect(WornCostumes.parse(null), isNull);
    expect(WornCostumes.parse(''), isNull);
    expect(WornCostumes.parse('nonsense'), isNull);
    // A costume the species was not fitted for, or an unknown one, drops.
    expect(WornCostumes.parse('MAN01:hat'), isNull);
    final worn = WornCostumes.parse('LET02:cape,hat#zz,nose#FFFFFF')!;
    expect(worn.colors.keys, [hat, nose]);
    expect(worn.colorOf(hat), hat.defaultColor);
    expect(worn.colorOf(nose), const Color(0xFFFFFFFF));
    // Encoded in a fixed order, whatever order they went on in.
    expect(
      const WornCostumes('LET02', {}).wear(glasses).wear(hat).encode(),
      'LET02:hat,sunglasses',
    );
    expect(WornCostumes.on('LET02', 'PIP01:hat').isEmpty, true);
  });

  test('legacy saves move their costume out of the effect slot', () async {
    for (final (id, saved) in [
      ('wing', 'celebration.WNG04#8A2338'),
      ('pip', 'celebration.PIP01'),
      ('horn', 'celebration.HOR03#16706C'),
      ('let', 'alchemy_glow'),
    ]) {
      await db.creatureDao.updateAlchemyEffect(instanceId: id, effect: saved);
    }
    await db.moveCostumesOutOfEffects();
    expect(await costumes('wing'), 'WNG04:hat#8A2338');
    expect(await costumes('pip'), 'PIP01:nose');
    expect(await costumes('horn'), 'HOR03:sunglasses#16706C');
    expect(await costumes('let'), null);
    expect(await effect('wing'), null);
    expect(await effect('let'), 'alchemy_glow');
    expect(
      WornCostumes.parse(await costumes('wing'))!.colorOf(hat),
      const Color(0xFF8A2338),
    );
  });

  test('each is an inventory item with a card, and every fitted species is '
      'fitted in every frame', () {
    final registry = buildInventoryRegistry(db);
    final frameCounts = {
      for (final c
          in (jsonDecode(
                    File(
                      'assets/data/alchemons_creatures.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['creatures']
              as List)
        c['id'] as String: c['spriteData']?['totalFrames'] as int?,
    };
    for (final costume in FamilyCostume.values) {
      final definition = registry[costume.itemKey]!;
      expect(definition.name, costume.title);
      expect(definition.stackable, true);
      expect(AlchemyEffectPaint.has(costume.previewKey), true);
      expect(InvKeys.alchemyItemFor(costume.previewKey), isNull);
      expect(costume.placements.length, 68, reason: costume.tag);
      for (final family in ['WNG', 'PIP', 'HOR', 'LET']) {
        expect(
          costume.placements.keys.where((s) => s.startsWith(family)).length,
          17,
        );
      }
      for (final species in costume.tilts.keys) {
        expect(costume.placements, contains(species));
      }
      for (final MapEntry(key: species, value: fit)
          in costume.placements.entries) {
        final frames = costume.frameFits[species]!;
        expect(frames.length, frameCounts[species], reason: species);
        // Starts where it was fitted.
        expect(frames.first.$1, closeTo(fit.$1, 0.0005), reason: species);
        expect(frames.first.$2, closeTo(fit.$2, 0.0005), reason: species);
        for (var f = 0; f < frames.length * 2; f++) {
          final at = costume.fitAt(species, f)!;
          final want = frames[f % frames.length];
          final tilt = (costume.tilts[species] ?? 0) + want.$3;
          expect((at.x, at.y, at.tilt), (want.$1, want.$2, tilt));
          expect(at.size, fit.$3);
        }
      }
    }
    expect(hat.fitAt('MAN01', 0), isNull);
    // Firewing's head rises over its wingbeat: the hat goes with it.
    expect(hat.fitAt('WNG01', 3)!.y, lessThan(hat.fitAt('WNG01', 0)!.y));
  });

  test('each costume moves with the head, all together', () {
    for (final species in hat.placements.keys) {
      final frames = hat.frameFits[species]!.length;
      for (var f = 0; f < frames; f++) {
        final moves = [
          for (final c in FamilyCostume.values)
            (
              c.fitAt(species, f)!.x - c.fitAt(species, 0)!.x,
              c.fitAt(species, f)!.y - c.fitAt(species, 0)!.y,
            ),
        ];
        for (final m in moves) {
          expect(m.$1, closeTo(moves.first.$1, 0.002), reason: '$species $f');
          expect(m.$2, closeTo(moves.first.$2, 0.002), reason: '$species $f');
        }
      }
    }
  });

  test('sunglasses are seen as each family is drawn', () {
    expect(GlassesView.of('HOR01'), GlassesView.threeQuarter);
    expect(GlassesView.of('PIP01'), GlassesView.threeQuarter);
    expect(GlassesView.of('WNG01'), GlassesView.profile);
    expect(GlassesView.of('WNG03'), GlassesView.front);
    expect(GlassesView.of('LET01'), GlassesView.front);
  });

  test('every preset is the costume\'s own, its default first; the ring is '
      'one depth all round', () {
    for (final c in FamilyCostume.values) {
      expect(c.presets.first, c.defaultColor);
      expect(c.presets.length, 9);
      for (var i = 0; i < 12; i++) {
        final hsv = HSVColor.fromColor(c.colorForHue(i / 12));
        expect(hsv.value, closeTo(c.ringValue, 0.01));
        expect(hsv.saturation, closeTo(c.ringSaturation, 0.01));
      }
    }
  });
}
