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
      'let': 'LET02',
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
  Future<bool> equip(
    String id, [
    String item = InvKeys.alchemyCelebration,
    Color? color,
  ]) => applyAlchemyEffect(db, instanceId: id, itemKey: item, color: color);
  Future<String?> worn(String id) async =>
      (await db.creatureDao.getInstance(id))?.alchemyEffect;

  Future<int> owned(String item) => db.inventoryDao.getItemQty(item);

  test('bought like any effect: one each, as many as are paid for', () async {
    final hat = FamilyCostume.partyHat.offerId;
    expect(await shop.purchase(hat), true);
    expect(await shop.purchase(hat, qty: 2), true);
    expect(await owned(InvKeys.alchemyCelebration), 3);
    expect((await db.currencyDao.getAllCurrencies())['gold'], 70);
    await shop.reloadFromStorage();
    expect(shop.getPurchaseStatus(hat), isNot('OWNED'));
    expect(await shop.purchase(FamilyCostume.nose.offerId), true);
    expect(await owned(InvKeys.alchemyNose), 1);
  });

  test('one dresses one creature; more need more', () async {
    await shop.purchase(FamilyCostume.partyHat.offerId);
    expect(await equip('wing'), true);
    expect(await worn('wing'), 'celebration.WNG04');
    expect(await owned(InvKeys.alchemyCelebration), 0);
    // None left for the second Wing until another is bought.
    expect(await equip('wing2'), false);
    expect(await worn('wing2'), null);
    await shop.purchase(FamilyCostume.partyHat.offerId);
    expect(await equip('wing2'), true);
    expect(await worn('wing2'), 'celebration.WNG01');
    expect(await owned(InvKeys.alchemyCelebration), 0);
    // Taken off, it goes back to the inventory, to be put on again.
    await removeAlchemyEffect(db, instanceId: 'wing');
    expect(await worn('wing'), null);
    expect(await owned(InvKeys.alchemyCelebration), 1);
    // Put on what it already wears, it keeps the item.
    expect(await equip('wing2'), true);
    expect(await owned(InvKeys.alchemyCelebration), 1);
  });

  test('each only for its own family, and never on a missing one', () async {
    await shop.purchase(FamilyCostume.partyHat.offerId);
    await shop.purchase(FamilyCostume.nose.offerId);
    expect(await equip('pip'), false);
    expect(await equip('let'), false);
    expect(await equip('missing'), false);
    expect(await equip('wing', InvKeys.alchemyNose), false);
    expect(await equip('let', InvKeys.alchemyNose), false);
    expect(await worn('let'), null);
    expect(await owned(InvKeys.alchemyCelebration), 1);
    expect(await owned(InvKeys.alchemyNose), 1);
    expect(await equip('pip', InvKeys.alchemyNose), true);
    expect(await worn('pip'), 'celebration.PIP01');
    expect(await owned(InvKeys.alchemyNose), 0);
  });

  test('swapping returns what was worn, whichever it was', () async {
    await shop.purchase(FamilyCostume.partyHat.offerId);
    await db.inventoryDao.addItemQty(InvKeys.alchemyGlow, 1);
    expect(await equip('wing', InvKeys.alchemyGlow), true);
    expect(await owned(InvKeys.alchemyGlow), 0);
    expect(await equip('wing'), true);
    expect(await owned(InvKeys.alchemyGlow), 1);
    expect(await owned(InvKeys.alchemyCelebration), 0);
    expect(await equip('wing', InvKeys.alchemyGlow), true);
    expect(await owned(InvKeys.alchemyCelebration), 1);
    await removeAlchemyEffect(db, instanceId: 'wing');
    await removeAlchemyEffect(db, instanceId: 'wing');
    expect(await owned(InvKeys.alchemyGlow), 1);
    expect(await owned(InvKeys.alchemyCelebration), 1);
  });

  test('overlapping applies cannot spend one consumable twice', () async {
    await db.inventoryDao.addItemQty(InvKeys.alchemyGlow, 1);
    final results = await Future.wait([
      equip('wing', InvKeys.alchemyGlow),
      equip('pip', InvKeys.alchemyGlow),
    ]);
    expect(results.where((ok) => ok).length, 1);
    expect(await db.inventoryDao.getItemQty(InvKeys.alchemyGlow), 0);
  });
  test('each is an inventory item like the others, and every fitted species '
      'is fitted in every frame', () {
    final registry = buildInventoryRegistry(db);
    for (final costume in FamilyCostume.values) {
      final definition = registry[costume.itemKey]!;
      expect(definition.name, costume.title);
      expect(definition.stackable, true);
      expect(AlchemyEffectPaint.has(costume.previewKey), true);
    }
    expect(FamilyCostume.nose.title, 'Alchemical Nose');
    expect(FamilyCostume.placements.length, 34);
    for (final species in FamilyCostume.placements.keys) {
      final costume = FamilyCostume.forSpecies(species)!;
      expect(costume.family, species.substring(0, 3));
      final effect = costume.effectOn(species)!;
      // Part of the sprite, never an effect painted round it.
      expect(AlchemyEffectPaint.has(effect), false);
      expect(FamilyCostume.isEffect(effect), true);
      for (var f = 0; f < 4; f++) {
        expect(FamilyCostume.fitAt(species, f), isNotNull);
      }
      expect(InvKeys.alchemyItemFor(effect), costume.itemKey);
    }
    expect(FamilyCostume.isEffect('celebration.LET02'), false);
    expect(FamilyCostume.fitAt('LET02', 0), isNull);
  });

  test('a tracked species moves its costume frame by frame, starting where '
      'it was fitted', () {
    for (final MapEntry(key: species, value: frames)
        in FamilyCostume.frameFits.entries) {
      final fit = FamilyCostume.placements[species]!;
      expect(frames.first.$1, fit.$1, reason: species);
      expect(frames.first.$2, fit.$2, reason: species);
      for (var f = 0; f < frames.length * 2; f++) {
        final at = FamilyCostume.fitAt(species, f)!;
        final want = frames[f % frames.length];
        expect((at.x, at.y, at.tilt), (want.$1, want.$2, want.$3));
        expect(at.size, fit.$3);
      }
    }
    // Firewing's head rises over its wingbeat: the hat goes with it.
    expect(
      FamilyCostume.fitAt('WNG01', 3)!.y,
      lessThan(FamilyCostume.fitAt('WNG01', 0)!.y),
    );
    // Every Wing's hat and every Pip's nose is tracked through every frame
    // of its sheet.
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
    for (final species in FamilyCostume.placements.keys) {
      expect(
        FamilyCostume.frameFits[species]?.length,
        frameCounts[species],
        reason: species,
      );
    }
  });

  test('a hat carries its colour in its save; no colour, or a bad one, is '
      'the violet', () {
    const ruby = Color(0xFF8A2338);
    final hat = FamilyCostume.partyHat;
    expect(hat.effectOn('WNG01'), 'celebration.WNG01');
    expect(
      hat.effectOn('WNG01', color: FamilyCostume.partyHat.defaultColor),
      'celebration.WNG01',
    );
    final red = hat.effectOn('WNG01', color: ruby)!;
    expect(red, 'celebration.WNG01#8A2338');
    expect(FamilyCostume.speciesFor(red), 'WNG01');
    expect(FamilyCostume.ofEffect(red), hat);
    expect(FamilyCostume.fitAt(FamilyCostume.speciesFor(red)!, 0), isNotNull);
    expect(InvKeys.alchemyItemFor(red), InvKeys.alchemyCelebration);
    expect(AlchemyEffectPaint.has(red), false);
    expect(FamilyCostume.colorOf(red), ruby);
    // Saves from before colours, and anything unreadable, are the violet.
    expect(
      FamilyCostume.colorOf('celebration.WNG01'),
      FamilyCostume.partyHat.defaultColor,
    );
    expect(
      FamilyCostume.colorOf('celebration.WNG01#zz'),
      FamilyCostume.partyHat.defaultColor,
    );
    expect(FamilyCostume.isEffect('celebration.LET02#8A2338'), false);
    // A nose carries its own, against its own default (ruby glass).
    final nose = FamilyCostume.nose;
    expect(
      nose.effectOn('PIP01', color: nose.defaultColor),
      'celebration.PIP01',
    );
    final teal = nose.effectOn('PIP01', color: const Color(0xFF1FB5B0))!;
    expect(teal, 'celebration.PIP01#1FB5B0');
    expect(FamilyCostume.ofEffect(teal), nose);
    expect(FamilyCostume.colorOf(teal), const Color(0xFF1FB5B0));
    expect(FamilyCostume.colorOf('celebration.PIP01'), nose.defaultColor);
    // A costume's colour is read only off that costume.
    expect(nose.colorIn(red), nose.defaultColor);
    expect(hat.colorIn(teal), hat.defaultColor);
    // Every preset is one of the costume's own, its default first.
    for (final c in FamilyCostume.values) {
      expect(c.presets.first, c.defaultColor);
      expect(c.presets.length, 9);
    }
    // Round the ring, the same depth of velvet in every hue.
    for (var i = 0; i < 12; i++) {
      final hsv = HSVColor.fromColor(
        FamilyCostume.partyHat.colorForHue(i / 12),
      );
      expect(hsv.value, closeTo(0.53, 0.01));
      expect(hsv.saturation, closeTo(0.62, 0.01));
    }
  });

  test('a hat goes on in its colour, changes colour free, and comes off '
      'whole', () async {
    const ruby = Color(0xFF8A2338), teal = Color(0xFF1F6A6A);
    await shop.purchase(FamilyCostume.partyHat.offerId);
    expect(await equip('wing', InvKeys.alchemyCelebration, ruby), true);
    expect(await worn('wing'), 'celebration.WNG04#8A2338');
    expect(await owned(InvKeys.alchemyCelebration), 0);
    // Put on again in another colour: the same hat, no second one spent.
    expect(await equip('wing', InvKeys.alchemyCelebration, teal), true);
    expect(await worn('wing'), 'celebration.WNG04#1F6A6A');
    expect(await owned(InvKeys.alchemyCelebration), 0);
    // Recoloured from the Effect slot, free.
    expect(await recolorCostume(db, instanceId: 'wing', color: ruby), true);
    expect(await worn('wing'), 'celebration.WNG04#8A2338');
    expect(await owned(InvKeys.alchemyCelebration), 0);
    // Only something wearing a costume can be recoloured.
    expect(await recolorCostume(db, instanceId: 'pip', color: ruby), false);
    expect(await recolorCostume(db, instanceId: 'let', color: ruby), false);
    expect(await recolorCostume(db, instanceId: 'missing', color: ruby), false);
    // Off, it goes back to the inventory as one hat.
    await removeAlchemyEffect(db, instanceId: 'wing');
    expect(await worn('wing'), null);
    expect(await owned(InvKeys.alchemyCelebration), 1);
  });

  test('a nose goes on in its colour and recolours free, like a hat', () async {
    const teal = Color(0xFF1FB5B0), gold = Color(0xFFE8B021);
    await shop.purchase(FamilyCostume.nose.offerId);
    expect(await equip('pip', InvKeys.alchemyNose, teal), true);
    expect(await worn('pip'), 'celebration.PIP01#1FB5B0');
    expect(await owned(InvKeys.alchemyNose), 0);
    expect(await recolorCostume(db, instanceId: 'pip', color: gold), true);
    expect(await worn('pip'), 'celebration.PIP01#E8B021');
    // Back to its own ruby: saved plain, as before colours.
    expect(
      await recolorCostume(
        db,
        instanceId: 'pip',
        color: FamilyCostume.nose.defaultColor,
      ),
      true,
    );
    expect(await worn('pip'), 'celebration.PIP01');
    await removeAlchemyEffect(db, instanceId: 'pip');
    expect(await owned(InvKeys.alchemyNose), 1);
  });
}
