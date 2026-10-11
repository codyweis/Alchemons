// The Athanor's wearables, dock sets and titles
// (docs/athanor/pieces_wearables.md): five auras, two costumes, five dock
// sets and five titles, found nowhere else.
//
//   - each aura is a real alchemy effect: an item, a painter key, applied
//     and taken off like the shop's;
//   - the crown and the monocle ride the hat's and the glasses' fits, and
//     each takes its rival off (returned to the inventory);
//   - an Athanor dock set has no faction, is never sold, and once owned is
//     worn whatever the faction;
//   - the shop sells none of them;
//   - every piece grants through grantAthanorPiece.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/models/dock_sets.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/profile_titles.dart';
import 'package:alchemons/screens/athanor/athanor_piece_art.dart';
import 'package:alchemons/services/athanor_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/utils/alchemy_effect_apply.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:alchemons/widgets/fx/costume_paint.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pieces as docs/athanor/pieces_wearables.md lists them.
const _pieces = [
  AthanorPiece(
    id: 'black.inkmaker',
    name: 'Inkmaker',
    description: 'A title for your profile.',
    kind: AthanorPieceKind.title,
    rarity: AthanorRarity.common,
    grantRef: 'inkmaker',
  ),
  AthanorPiece(
    id: 'black.ink_bloom',
    name: 'Ink Plume',
    description: 'An alchemy effect.',
    kind: AthanorPieceKind.alchemyEffect,
    rarity: AthanorRarity.rare,
    grantRef: InvKeys.alchemyInkBloom,
  ),
  AthanorPiece(
    id: 'black.darklet_dock',
    name: 'Darklet Dock',
    description: 'A dock set.',
    kind: AthanorPieceKind.dockSet,
    rarity: AthanorRarity.rare,
    grantRef: 'darklet',
  ),
  AthanorPiece(
    id: 'black.peacock_tail',
    name: "Oil Slick",
    description: 'An alchemy effect.',
    kind: AthanorPieceKind.alchemyEffect,
    rarity: AthanorRarity.epic,
    grantRef: InvKeys.alchemyPeacockTail,
  ),
  AthanorPiece(
    id: 'white.silversmith',
    name: 'Silversmith',
    description: 'A title for your profile.',
    kind: AthanorPieceKind.title,
    rarity: AthanorRarity.common,
    grantRef: 'silversmith',
  ),
  AthanorPiece(
    id: 'white.quicksilver',
    name: 'Quicksilver',
    description: 'An alchemy effect.',
    kind: AthanorPieceKind.alchemyEffect,
    rarity: AthanorRarity.rare,
    grantRef: InvKeys.alchemyQuicksilver,
  ),
  AthanorPiece(
    id: 'white.spiritlet_dock',
    name: 'Spiritlet Dock',
    description: 'A dock set.',
    kind: AthanorPieceKind.dockSet,
    rarity: AthanorRarity.rare,
    grantRef: 'spiritlet',
  ),
  AthanorPiece(
    id: 'yellow.gilder',
    name: 'Gilder',
    description: 'A title for your profile.',
    kind: AthanorPieceKind.title,
    rarity: AthanorRarity.common,
    grantRef: 'gilder',
  ),
  AthanorPiece(
    id: 'yellow.gold_leaf',
    name: 'Gold Leaf',
    description: 'An alchemy effect.',
    kind: AthanorPieceKind.alchemyEffect,
    rarity: AthanorRarity.rare,
    grantRef: InvKeys.alchemyGoldLeaf,
  ),
  AthanorPiece(
    id: 'yellow.lightlet_dock',
    name: 'Lightlet Dock',
    description: 'A dock set.',
    kind: AthanorPieceKind.dockSet,
    rarity: AthanorRarity.rare,
    grantRef: 'lightlet',
  ),
  AthanorPiece(
    id: 'red.ember_keeper',
    name: 'Ember Keeper',
    description: 'A title for your profile.',
    kind: AthanorPieceKind.title,
    rarity: AthanorRarity.common,
    grantRef: 'ember_keeper',
  ),
  AthanorPiece(
    id: 'red.cinnabar',
    name: 'Red Smoke',
    description: 'An alchemy effect.',
    kind: AthanorPieceKind.alchemyEffect,
    rarity: AthanorRarity.rare,
    grantRef: InvKeys.alchemyCinnabar,
  ),
  AthanorPiece(
    id: 'red.bloodlet_dock',
    name: 'Bloodlet Dock',
    description: 'A dock set.',
    kind: AthanorPieceKind.dockSet,
    rarity: AthanorRarity.rare,
    grantRef: 'bloodlet',
  ),
  AthanorPiece(
    id: 'red.red_king_crown',
    name: 'Garnet Crown',
    description: 'A costume.',
    kind: AthanorPieceKind.costume,
    rarity: AthanorRarity.epic,
    grantRef: InvKeys.alchemyRedKingCrown,
  ),
  AthanorPiece(
    id: 'still.distiller',
    name: 'Distiller',
    description: 'A title for your profile.',
    kind: AthanorPieceKind.title,
    rarity: AthanorRarity.common,
    grantRef: 'distiller',
  ),
  AthanorPiece(
    id: 'still.crystalet_dock',
    name: 'Crystalet Dock',
    description: 'A dock set.',
    kind: AthanorPieceKind.dockSet,
    rarity: AthanorRarity.rare,
    grantRef: 'crystalet',
  ),
  AthanorPiece(
    id: 'still.brass_monocle',
    name: 'Brass Monocle',
    description: 'A costume.',
    kind: AthanorPieceKind.costume,
    rarity: AthanorRarity.epic,
    grantRef: InvKeys.alchemyBrassMonocle,
  ),
];

const _auras = {
  InvKeys.alchemyInkBloom: AlchemyEffectPaint.inkBloom,
  InvKeys.alchemyPeacockTail: AlchemyEffectPaint.peacockTail,
  InvKeys.alchemyQuicksilver: AlchemyEffectPaint.quicksilver,
  InvKeys.alchemyGoldLeaf: AlchemyEffectPaint.goldLeaf,
  InvKeys.alchemyCinnabar: AlchemyEffectPaint.cinnabar,
};

/// Counts what a frame draws, and any blur.
class _Census implements Canvas {
  int draws = 0, blurs = 0, layers = 0;

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    if (n.contains('"draw')) draws++;
    if (n.contains('saveLayer')) layers++;
    for (final a in i.positionalArguments) {
      if (a is Paint && (a.maskFilter != null || a.imageFilter != null)) {
        blurs++;
      }
    }
    if (n.contains('getSaveCount')) return 1;
    return null;
  }
}

void main() {
  late AlchemonsDatabase db;
  late FactionService factions;
  late ShopService shop;

  setUp(() async {
    db = AlchemonsDatabase(NativeDatabase.memory());
    factions = FactionService(db);
    shop = ShopService(
      db,
      ConstellationEffectsService(db),
      factions,
      TimedBoostService(db.settingsDao),
    );
    await shop.reloadFromStorage();
    await db.settingsDao.setSetting('wallet_gold', '1000');
    for (final e in {
      'wing': 'WNG04',
      'horn': 'HOR03',
      'let': 'LET02',
    }.entries) {
      await db.creatureDao.insertInstance(instanceId: e.key, baseId: e.value);
    }
  });
  tearDown(() async {
    shop.dispose();
    await db.close();
  });

  Future<int> owned(String key) => db.inventoryDao.getItemQty(key);
  Future<String?> costumes(String id) async =>
      (await db.creatureDao.getInstance(id))?.costumes;

  group('auras', () {
    test('each is a registered alchemy effect, with an item for it', () {
      final registry = buildInventoryRegistry(db);
      for (final MapEntry(key: item, value: effect) in _auras.entries) {
        expect(InvKeys.alchemyEffectFor(item), effect);
        expect(InvKeys.alchemyItemFor(effect), item);
        expect(AlchemyEffectPaint.has(effect), isTrue, reason: effect);
        expect(AlchemyEffectPaint.hasFront(effect), isTrue, reason: effect);
        expect(AlchemyEffectPaint.athanorKeys, contains(effect));
        expect(registry[item]?.name, isNotEmpty, reason: item);
        expect(InvKeys.athanorOnlyItems, contains(item));
      }
    });

    test('put on, swapped and taken off like the shop\'s', () async {
      await db.inventoryDao.addItemQty(InvKeys.alchemyGoldLeaf, 1);
      await db.inventoryDao.addItemQty(InvKeys.alchemyCinnabar, 1);
      expect(
        await applyAlchemyEffect(
          db,
          instanceId: 'wing',
          itemKey: InvKeys.alchemyGoldLeaf,
        ),
        isTrue,
      );
      expect(
        (await db.creatureDao.getInstance('wing'))!.alchemyEffect,
        'gold_leaf',
      );
      expect(await owned(InvKeys.alchemyGoldLeaf), 0);
      await applyAlchemyEffect(
        db,
        instanceId: 'wing',
        itemKey: InvKeys.alchemyCinnabar,
      );
      expect(await owned(InvKeys.alchemyGoldLeaf), 1);
      await removeAlchemyEffect(db, instanceId: 'wing');
      expect(await owned(InvKeys.alchemyCinnabar), 1);
      expect((await db.creatureDao.getInstance('wing'))!.alchemyEffect, null);
    });

    test('each paints with no blur, no layer, and batched', () {
      for (final effect in _auras.values) {
        for (final r in const [12.0, 24.0, 55.0, 95.0]) {
          for (var f = 0; f < 60; f++) {
            for (final front in const [false, true]) {
              final c = _Census();
              AlchemyEffectPaint.paint(
                c as Canvas,
                effect,
                const Offset(100, 100),
                r,
                f * 0.2,
                front: front,
              );
              expect(c.blurs, 0, reason: effect);
              expect(c.layers, 0, reason: effect);
              expect(c.draws, lessThanOrEqualTo(16), reason: '$effect r$r');
            }
          }
        }
      }
    });
  });

  group('costumes', () {
    const hat = FamilyCostume.partyHat, glasses = FamilyCostume.sunglasses;
    const crown = FamilyCostume.crown, monocle = FamilyCostume.monocle;

    test('the crown rides the hat\'s fits, the monocle the glasses\'', () {
      expect(crown.placements, same(hat.placements));
      expect(crown.frameFits, same(hat.frameFits));
      expect(crown.tilts, same(hat.tilts));
      expect(monocle.placements, same(glasses.placements));
      expect(monocle.frameFits, same(glasses.frameFits));
      expect(crown.fits('WNG04'), isTrue);
      expect(monocle.fits('LET02'), isTrue);
      expect(crown.fits('MAN01'), isFalse);
      expect(crown.exclusiveWith, hat);
      expect(hat.exclusiveWith, crown);
      expect(monocle.exclusiveWith, glasses);
      expect(glasses.exclusiveWith, monocle);
      expect(FamilyCostume.nose.exclusiveWith, isNull);
      expect(FamilyCostume.sold, [hat, FamilyCostume.nose, glasses]);
      for (final c in [crown, monocle]) {
        expect(c.athanorOnly, isTrue);
        expect(InvKeys.alchemyEffectFor(c.itemKey), c.previewKey);
        expect(AlchemyEffectPaint.has(c.previewKey), isTrue);
        expect(FamilyCostume.ofItem(c.itemKey), c);
      }
    });

    test('the crown takes the hat off, and the hat the crown', () async {
      await db.inventoryDao.addItemQty(hat.itemKey, 1);
      await db.inventoryDao.addItemQty(crown.itemKey, 1);
      await db.inventoryDao.addItemQty(FamilyCostume.nose.itemKey, 1);
      Future<bool> wear(FamilyCostume c, [Color? color]) =>
          wearCostume(db, instanceId: 'wing', costume: c, color: color);

      expect(await wear(hat), isTrue);
      expect(await wear(FamilyCostume.nose), isTrue);
      expect(await costumes('wing'), 'WNG04:hat,nose');
      const amethyst = Color(0xFF5A2E8F);
      expect(await wear(crown, amethyst), isTrue);
      // The hat came off and went back; the nose stayed.
      expect(await costumes('wing'), 'WNG04:nose,crown#5A2E8F');
      expect(await owned(hat.itemKey), 1);
      expect(await owned(crown.itemKey), 0);
      // And back again.
      expect(await wear(hat), isTrue);
      expect(await costumes('wing'), 'WNG04:hat,nose');
      expect(await owned(crown.itemKey), 1);
      expect(await owned(hat.itemKey), 0);
      // Taken off, the crown goes back too.
      await wear(crown);
      expect(
        await takeOffCostume(db, instanceId: 'wing', costume: crown),
        isTrue,
      );
      expect(await owned(crown.itemKey), 1);
      expect(await owned(hat.itemKey), 1);
      expect(await costumes('wing'), 'WNG04:nose');
    });

    test('the monocle takes the sunglasses off, and back', () async {
      await db.inventoryDao.addItemQty(glasses.itemKey, 1);
      await db.inventoryDao.addItemQty(monocle.itemKey, 1);
      expect(
        await wearCostume(db, instanceId: 'horn', costume: glasses),
        isTrue,
      );
      expect(
        await wearCostume(db, instanceId: 'horn', costume: monocle),
        isTrue,
      );
      expect(await costumes('horn'), 'HOR03:monocle');
      expect(await owned(glasses.itemKey), 1);
      expect(
        await wearCostume(db, instanceId: 'horn', costume: glasses),
        isTrue,
      );
      expect(await costumes('horn'), 'HOR03:sunglasses');
      expect(await owned(monocle.itemKey), 1);
      // None owned: nothing comes off.
      await db.inventoryDao.decrementItem(monocle.itemKey, by: 1);
      expect(
        await wearCostume(db, instanceId: 'horn', costume: monocle),
        isFalse,
      );
      expect(await costumes('horn'), 'HOR03:sunglasses');
    });

    test('a save with two on one spot reads as the first, and wear() keeps '
        'one', () {
      final worn = WornCostumes.parse('LET02:hat,sunglasses,crown,monocle')!;
      expect(worn.wears(hat), isTrue);
      expect(worn.wears(glasses), isTrue);
      expect(worn.wears(crown), isFalse);
      expect(worn.wears(monocle), isFalse);
      final swapped = worn.wear(crown).wear(monocle);
      expect(swapped.wears(hat), isFalse);
      expect(swapped.wears(glasses), isFalse);
      expect(swapped.encode(), 'LET02:crown,monocle');
      expect(WornCostumes.parse(swapped.encode())!.colors.keys, [
        crown,
        monocle,
      ]);
    });

    test('worn, the crown and the monocle keep the costume budget', () {
      for (final species in ['WNG01', 'WNG04', 'PIP01', 'HOR01', 'LET01']) {
        for (var f = 0; f < 40; f++) {
          final c = _Census();
          CostumePaint.paintWorn(
            c as Canvas,
            WornCostumes(species, {
              crown: crown.defaultColor,
              monocle: monocle.defaultColor,
              FamilyCostume.nose: FamilyCostume.nose.defaultColor,
            }).encode(),
            const Rect.fromLTWH(0, 0, 200, 200),
            f % 4,
            f * 0.2,
          );
          expect(c.blurs, 0, reason: species);
          expect(c.layers, 0, reason: species);
          expect(c.draws, inInclusiveRange(1, 40), reason: species);
        }
      }
    });
  });

  group('dock sets', () {
    test('five, with no faction, each its own Let', () {
      final sets = DockSet.athanorSets;
      expect(
        [for (final s in sets) s.id],
        ['darklet', 'spiritlet', 'lightlet', 'bloodlet', 'crystalet'],
      );
      expect(
        [for (final s in sets) s.letId],
        ['LET15', 'LET14', 'LET16', 'LET17', 'LET11'],
      );
      for (final s in sets) {
        expect(s.faction, isNull);
        expect(s.athanorOnly, isTrue);
        expect(s.free, isFalse);
        expect(s.companions.length, 2);
        expect(s.companions.every((c) => c.athanorOnly && c != s), isTrue);
        expect(DockSet.byOffer(s.offerId), isNull);
      }
      // Every Let on the dock is a different one.
      expect({for (final s in kDockSets) s.letId}.length, kDockSets.length);
      // The factions keep their three.
      for (final f in FactionId.values) {
        expect(DockSet.ofFaction(f).length, 3);
      }
    });

    test('once drawn, worn whatever the faction', () async {
      await factions.setId(FactionId.volcanic);
      final darklet = DockSet.byId('darklet')!;
      expect(factions.ownsDockSet(darklet), isFalse);
      await factions.wearDockSet(darklet);
      expect(factions.dockSet, DockSet.of(FactionId.volcanic));

      // The Athanor grants it inside its pour, by its settings row.
      await db.transaction(
        () => grantAthanorPiece(
          db,
          _pieces.firstWhere((p) => p.id == 'black.darklet_dock'),
        ),
      );
      await factions.reloadDockSets();
      expect(factions.ownsDockSet(darklet), isTrue);
      await factions.wearDockSet(darklet);
      expect(factions.dockSet, darklet);

      // Another faction: still owned, and can be worn there too.
      await factions.setId(FactionId.oceanic);
      expect(factions.ownsDockSet(darklet), isTrue);
      await factions.wearDockSet(darklet);
      expect(factions.dockSet, darklet);

      // A relaunch reads it back.
      final again = FactionService(db);
      await again.loadId();
      expect(again.ownsDockSet(darklet), isTrue);
      expect(again.dockSet, darklet);
    });
  });

  group('never sold', () {
    test('the shop has no offer for any of them it would sell', () async {
      for (final key in InvKeys.athanorOnlyItems) {
        for (final o in ShopService.allOffers.where(
          (o) => o.inventoryKey == key,
        )) {
          expect(ShopService.sells(o), isFalse, reason: o.id);
          expect(shop.canPurchase(o.id), isFalse, reason: o.id);
          expect(await shop.purchase(o.id), isFalse, reason: o.id);
        }
        expect(await owned(key), 0);
      }
      final listed = {
        ...shop.getAlchemyEffectOffers().map((o) => o.inventoryKey),
        ...shop.getCostumeOffers().map((o) => o.inventoryKey),
      };
      expect(listed.intersection(InvKeys.athanorOnlyItems), isEmpty);
      // No dock offer for an Athanor set, in any faction.
      for (final f in FactionId.values) {
        await factions.setId(f);
        for (final s in DockSet.athanorSets) {
          expect(
            ShopService.allOffers.where((o) => o.id == s.offerId),
            isEmpty,
          );
          expect(shop.canPurchase(s.offerId), isFalse);
        }
      }
    });
  });

  testWidgets('every piece has a look in the Athanor, with or without its '
      'Let loaded', (tester) async {
    for (final look in AthanorPieceLook.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Wrap(
            children: [
              for (final p in _pieces)
                SizedBox.square(
                  dimension: 96,
                  child: AthanorPieceArt(piece: p, look: look),
                ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  test('every piece grants through its kind', () async {
    await db.transaction(() async {
      for (final p in _pieces) {
        await grantAthanorPiece(db, p);
      }
    });
    for (final key in InvKeys.athanorOnlyItems) {
      expect(await owned(key), 1, reason: key);
    }
    final titles = await ProfileTitles.load(db);
    expect(titles.owned, {
      'inkmaker',
      'silversmith',
      'gilder',
      'ember_keeper',
      'distiller',
    });
    final batch = AthanorBatch(
      id: 'test',
      name: 'Test',
      description: 'A test batch.',
      pieces: _pieces.sublist(0, _pieces.length - 1),
      capstone: _pieces.last,
    );
    expect(ProfileTitles.nameOf('gilder', batches: [batch]), 'Gilder');
    await factions.loadId();
    for (final s in DockSet.athanorSets) {
      expect(await db.settingsDao.getSetting(s.settingKey), '1');
      expect(factions.ownsDockSet(s), isTrue, reason: s.id);
    }
  });
}
