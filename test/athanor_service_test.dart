// A pour is one transaction that either happens whole or changes nothing
// (docs/athanor_design.md, lib/services/athanor_service.dart).
//
// These run the service against an in-memory database: a pour that cannot
// be paid changes nothing, tincture and gold are spent exactly, the capstone
// comes with the last piece, the daily pour is once per UTC day and pays the
// old chest's rewards (with or without a draw), gold pours alone are off in
// Belgium, the first fire is given once with its back-pay, and each kind of
// piece lands in its own system.

import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/profile_titles.dart';
import 'package:alchemons/services/athanor_service.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _effect = AthanorPiece(
  id: 't.aura',
  name: 'Test Aura',
  description: 'A test aura.',
  kind: AthanorPieceKind.alchemyEffect,
  rarity: AthanorRarity.common,
  grantRef: 'alchemy.test_aura',
);
const _decor = AthanorPiece(
  id: 't.lantern',
  name: 'Test Lantern',
  description: 'A test lantern.',
  kind: AthanorPieceKind.homeDecor,
  rarity: AthanorRarity.rare,
  grantRef: 'lantern_post',
);
const _title = AthanorPiece(
  id: 't.title',
  name: 'Keeper of Tests',
  description: 'A test title.',
  kind: AthanorPieceKind.title,
  rarity: AthanorRarity.epic,
  grantRef: 'title.keeper',
);
const _capstone = AthanorPiece(
  id: 't.crown',
  name: 'Test Crown',
  description: 'The test capstone.',
  kind: AthanorPieceKind.alchemyEffect,
  rarity: AthanorRarity.epic,
  grantRef: 'alchemy.test_crown',
);

const _batch = AthanorBatch(
  id: 'test',
  name: 'Test',
  description: 'A test batch.',
  pieces: [_effect, _decor, _title],
  capstone: _capstone,
);

/// A Random that plays back [doubles] and [ints], then falls back to a seeded
/// one, so a test can choose what the daily chest rolls.
class _ScriptedRandom implements Random {
  _ScriptedRandom({List<double> doubles = const [], List<int> ints = const []})
    : _doubles = [...doubles],
      _ints = [...ints];
  final List<double> _doubles;
  final List<int> _ints;
  final Random _rest = Random(3);
  @override
  double nextDouble() =>
      _doubles.isEmpty ? _rest.nextDouble() : _doubles.removeAt(0);
  @override
  int nextInt(int max) =>
      _ints.isEmpty ? _rest.nextInt(max) : _ints.removeAt(0).clamp(0, max - 1);
  @override
  bool nextBool() => _rest.nextBool();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AlchemonsDatabase db;
  var now = DateTime.utc(2026, 10, 10, 12);

  AthanorService service({
    String? country,
    Random? random,
    CreatureCatalog? catalog,
  }) => AthanorService(
    db,
    batches: const [_batch],
    random: random ?? Random(11),
    storefrontCountry: () async => country,
    catalog: catalog,
    clock: () => now,
  );

  Future<int> tincture() => db.inventoryDao.getItemQty(InvKeys.athanorTincture);
  Future<int> gold() => db.currencyDao.getGoldBalance();
  Future<int> silver() => db.currencyDao.getSilverBalance();
  Future<String?> stateRow() => db.settingsDao.getSetting(AthanorState.key);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AlchemonsDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 10, 10, 12);
    // A new save starts with a little of each; these count from nothing.
    await db.settingsDao.setSetting('wallet_gold', '0');
    await db.settingsDao.setSetting('wallet_silver', '0');
  });
  tearDown(() => db.close());

  group('paying', () {
    test('too little tincture or gold: null, and nothing changes', () async {
      await db.inventoryDao.addItemQty(InvKeys.athanorTincture, 9);
      await db.currencyDao.addGold(49);
      final athanor = service(country: 'US');
      await athanor.load();

      expect(athanor.canPour('test', AthanorPayment.tincture), isFalse);
      expect(athanor.canPour('test', AthanorPayment.gold), isFalse);
      expect(await athanor.pour('test', AthanorPayment.tincture), isNull);
      expect(await athanor.pour('test', AthanorPayment.gold), isNull);

      expect(await tincture(), 9);
      expect(await gold(), 49);
      expect(await stateRow(), isNull);
      expect(athanor.drawnIn('test'), isEmpty);
      for (final piece in _batch.pieces) {
        expect(athanor.ownsPiece(piece.id), isFalse);
      }
      expect(await db.inventoryDao.getItemQty('alchemy.test_aura'), 0);
    });

    test('a tincture pour spends exactly its price', () async {
      await db.inventoryDao.addItemQty(
        InvKeys.athanorTincture,
        kAthanorTincturePerPour + 15,
      );
      await db.currencyDao.addGold(60);
      final athanor = service(country: 'US');
      await athanor.load();

      final result = await athanor.pour('test', AthanorPayment.tincture);
      expect(result, isNotNull);
      expect(await tincture(), 15);
      expect(athanor.tincture, 15);
      expect(await gold(), 60);
      expect(athanor.drawnIn('test'), {result!.piece.id});
      expect(athanor.ownsPiece(result.piece.id), isTrue);
    });

    test('a gold pour spends exactly 50', () async {
      await db.inventoryDao.addItemQty(InvKeys.athanorTincture, 25);
      await db.currencyDao.addGold(60);
      final athanor = service(country: 'US');
      await athanor.load();

      expect(await athanor.pour('test', AthanorPayment.gold), isNotNull);
      expect(await gold(), 10);
      expect(athanor.gold, 10);
      expect(await tincture(), 25);
    });

    test('two pours at once with tincture for one: exactly one', () async {
      await db.inventoryDao.addItemQty(
        InvKeys.athanorTincture,
        kAthanorTincturePerPour,
      );
      final athanor = service(country: 'US');
      await athanor.load();

      final results = await Future.wait([
        athanor.pour('test', AthanorPayment.tincture),
        athanor.pour('test', AthanorPayment.tincture),
      ]);
      expect(results.whereType<AthanorPourResult>(), hasLength(1));
      expect(await tincture(), 0);
      expect(athanor.drawnIn('test'), hasLength(1));
    });

    test('an unknown batch is never poured into', () async {
      await db.inventoryDao.addItemQty(InvKeys.athanorTincture, 10);
      final athanor = service(country: 'US');
      await athanor.load();
      expect(athanor.canPour('nope', AthanorPayment.tincture), isFalse);
      expect(await athanor.pour('nope', AthanorPayment.tincture), isNull);
      expect(athanor.nextPourOdds('nope'), isEmpty);
      expect(await tincture(), 10);
    });
  });

  group('a batch', () {
    test('is done in as many pours as it has pieces; the capstone comes with '
        'the last and only then', () async {
      await db.inventoryDao.addItemQty(
        InvKeys.athanorTincture,
        kAthanorTincturePerPour * _batch.pieces.length + 30,
      );
      final athanor = service(country: 'US');
      await athanor.load();

      final seen = <String>{};
      for (var i = 0; i < _batch.pieces.length; i++) {
        final odds = athanor.nextPourOdds('test');
        expect(odds, hasLength(_batch.pieces.length - i));
        final result = await athanor.pour('test', AthanorPayment.tincture);
        expect(result, isNotNull);
        expect(seen.add(result!.piece.id), isTrue);
        expect(odds.map((o) => o.$1.id), contains(result.piece.id));
        final last = i == _batch.pieces.length - 1;
        expect(result.capstone?.id, last ? _capstone.id : null);
        expect(athanor.isComplete('test'), last);
      }

      expect(await db.inventoryDao.getItemQty('alchemy.test_crown'), 1);
      expect(athanor.ownsPiece(_capstone.id), isTrue);
      expect(athanor.nextPourOdds('test'), isEmpty);
      expect(athanor.canPour('test', AthanorPayment.tincture), isFalse);

      // Done: a further pour is refused and costs nothing.
      final before = await tincture();
      expect(await athanor.pour('test', AthanorPayment.tincture), isNull);
      expect(await tincture(), before);
      expect(before, 30);
    });

    test('grants each kind through its own system', () async {
      await db.inventoryDao.addItemQty(
        InvKeys.athanorTincture,
        kAthanorTincturePerPour * _batch.pieces.length,
      );
      final athanor = service(country: 'US');
      await athanor.load();
      for (var i = 0; i < _batch.pieces.length; i++) {
        await athanor.pour('test', AthanorPayment.tincture);
      }
      expect(await db.inventoryDao.getItemQty('alchemy.test_aura'), 1);
      // The lantern post is a Curio, which comes several at a time.
      expect(
        await db.inventoryDao.getItemQty('home.lantern_post'),
        kAthanorCurioCopies,
      );
      final titles = await ProfileTitles.load(db);
      expect(titles.owned, {'title.keeper'});
      expect(titles.worn, isNull);
    });

    test('state survives a fresh service (a relaunch)', () async {
      await db.inventoryDao.addItemQty(
        InvKeys.athanorTincture,
        2 * kAthanorTincturePerPour,
      );
      final first = service(country: 'US');
      await first.load();
      final a = await first.pour('test', AthanorPayment.tincture);

      final second = service(country: 'US');
      await second.load();
      expect(second.drawnIn('test'), {a!.piece.id});
      expect(second.tincture, kAthanorTincturePerPour);
      final b = await second.pour('test', AthanorPayment.tincture);
      expect(b!.piece.id, isNot(a.piece.id));
    });
  });

  group('the daily pour', () {
    test('is once per UTC day and pays the chest', () async {
      final athanor = service(country: 'US');
      await athanor.load();
      expect(athanor.dailyPourReady, isTrue);
      expect(athanor.canPour('test', AthanorPayment.daily), isTrue);

      final result = await athanor.pour('test', AthanorPayment.daily);
      expect(result, isNotNull);
      final extras = result!.daily!;
      expect(extras.silver, inInclusiveRange(150, 500));
      expect(extras.gold, anyOf(0, 1));
      expect(await silver(), extras.silver);
      expect(await gold(), extras.gold);
      expect(athanor.dailyPourReady, isFalse);

      // Again the same day: refused, nothing paid.
      expect(await athanor.pour('test', AthanorPayment.daily), isNull);
      expect(await silver(), extras.silver);
      expect(athanor.drawnIn('test'), hasLength(1));

      // Late the same UTC day still counts as today.
      now = DateTime.utc(2026, 10, 10, 23, 59);
      expect(athanor.dailyPourReady, isFalse);

      // The next UTC day it is back, without a reload.
      now = DateTime.utc(2026, 10, 11, 0, 1);
      expect(athanor.dailyPourReady, isTrue);
      expect(await athanor.pour('test', AthanorPayment.daily), isNotNull);
      expect(athanor.drawnIn('test'), hasLength(2));
    });

    test('ignores the old chest key: everyone starts with one', () async {
      await db.settingsDao.setSetting('daily_loot_key', athanorDayKey(now));
      final athanor = service(country: 'US');
      await athanor.load();
      expect(athanor.dailyPourReady, isTrue);
    });

    test('pays its gold and its common vial when they roll', () async {
      final catalog = CreatureCatalog();
      await catalog.load();
      // Draw, then silver 0 → 150, gold 0.1 < 0.15, vial 0.1 < 0.25, group 0.
      final athanor = service(
        country: 'US',
        catalog: catalog,
        random: _ScriptedRandom(doubles: [0.0, 0.1, 0.1], ints: [0, 0]),
      );
      await athanor.load();
      final extras = (await athanor.pour('test', AthanorPayment.daily))!.daily!;
      expect(extras.silver, 150);
      expect(extras.gold, 1);
      expect(extras.vialGroupName, isNotNull);
      final group = extras.vialGroup!;
      expect(group, isNot(ElementalGroup.arcane));
      final vialKey = 'vial.${group.name}.common.Daily Vial';
      expect(await db.inventoryDao.getItemQty(vialKey), 1);
      expect(await gold(), 1);
      expect(await silver(), 150);
    });

    test('pays no vial and no gold when they do not roll', () async {
      final catalog = CreatureCatalog();
      await catalog.load();
      final athanor = service(
        country: 'US',
        catalog: catalog,
        random: _ScriptedRandom(doubles: [0.0, 0.9, 0.9], ints: [350]),
      );
      await athanor.load();
      final extras = (await athanor.pour('test', AthanorPayment.daily))!.daily!;
      expect(extras.silver, 500);
      expect(extras.gold, 0);
      expect(extras.vialGroupName, isNull);
      expect(await gold(), 0);
    });

    test('a paid pour leaves the daily alone and pays no extras', () async {
      await db.inventoryDao.addItemQty(
        InvKeys.athanorTincture,
        kAthanorTincturePerPour,
      );
      final athanor = service(country: 'US');
      await athanor.load();
      final result = await athanor.pour('test', AthanorPayment.tincture);
      expect(result!.daily, isNull);
      expect(await silver(), 0);
      expect(athanor.dailyPourReady, isTrue);
    });
  });

  group('Belgium', () {
    for (final code in ['BE', 'BEL', 'be', ' bel ']) {
      test('"$code" turns gold pours off, and only gold pours', () async {
        await db.inventoryDao.addItemQty(
          InvKeys.athanorTincture,
          kAthanorTincturePerPour,
        );
        await db.currencyDao.addGold(500);
        final athanor = service(country: code);
        await athanor.load();

        expect(athanor.goldPoursAvailable, isFalse);
        expect(athanor.canPour('test', AthanorPayment.gold), isFalse);
        expect(await athanor.pour('test', AthanorPayment.gold), isNull);
        expect(await gold(), 500);

        expect(athanor.canPour('test', AthanorPayment.tincture), isTrue);
        expect(athanor.canPour('test', AthanorPayment.daily), isTrue);
        expect(await athanor.pour('test', AthanorPayment.tincture), isNotNull);
        expect(await athanor.pour('test', AthanorPayment.daily), isNotNull);
      });
    }

    test('elsewhere, and where the country is unknown, gold pours are on', () {
      for (final code in ['US', 'USA', 'NL', 'BR', null, '']) {
        expect(athanorIsBelgium(code), isFalse, reason: '$code');
      }
    });

    test('an unknown or failing country leaves gold pours on', () async {
      final failing = AthanorService(
        db,
        batches: const [_batch],
        storefrontCountry: () async => throw StateError('no store'),
        clock: () => now,
      );
      await failing.load();
      expect(failing.goldPoursAvailable, isTrue);

      final unknown = service();
      await unknown.load();
      expect(unknown.goldPoursAvailable, isTrue);
    });

    test('the country is asked once and kept', () async {
      var asked = 0;
      final athanor = AthanorService(
        db,
        batches: const [_batch],
        storefrontCountry: () async {
          asked++;
          return 'BE';
        },
        clock: () => now,
      );
      await athanor.load();
      await athanor.load();
      expect(asked, 1);
      expect(athanor.goldPoursAvailable, isFalse);
    });
  });

  group('the daily without a draw', () {
    test('pays the chest once per UTC day and draws nothing', () async {
      final athanor = service(country: 'US');
      await athanor.load();
      final extras = await athanor.takeDailyExtras();
      expect(extras, isNotNull);
      expect(extras!.silver, inInclusiveRange(150, 500));
      expect(await silver(), extras.silver);
      expect(athanor.drawnIn('test'), isEmpty);
      expect(athanor.dailyPourReady, isFalse);

      expect(await athanor.takeDailyExtras(), isNull);
      expect(await silver(), extras.silver);

      now = DateTime.utc(2026, 10, 11, 0, 1);
      expect(athanor.dailyPourReady, isTrue);
      expect(await athanor.takeDailyExtras(), isNotNull);
    });

    test('shares the day with a daily pour: a pour first spends it', () async {
      final athanor = service(country: 'US');
      await athanor.load();
      expect(await athanor.pour('test', AthanorPayment.daily), isNotNull);
      final paid = await silver();
      expect(await athanor.takeDailyExtras(), isNull);
      expect(await silver(), paid);
    });

    test('shares the day with a daily pour: extras first spend it', () async {
      final athanor = service(country: 'US');
      await athanor.load();
      expect(await athanor.takeDailyExtras(), isNotNull);
      expect(athanor.canPour('test', AthanorPayment.daily), isFalse);
      expect(await athanor.pour('test', AthanorPayment.daily), isNull);
      expect(athanor.drawnIn('test'), isEmpty);
    });

    test('works with no batches at all', () async {
      final athanor = AthanorService(
        db,
        batches: const [],
        storefrontCountry: () async => 'US',
        clock: () => now,
      );
      await athanor.load();
      expect(athanor.anyPiecesLeft, isFalse);
      expect(athanor.dailyPourReady, isTrue);
      expect(await athanor.takeDailyExtras(), isNotNull);
      expect(athanor.dailyPourReady, isFalse);
    });

    test('anyPiecesLeft follows the batches', () async {
      await db.inventoryDao.addItemQty(InvKeys.athanorTincture, 100);
      final athanor = service(country: 'US');
      await athanor.load();
      for (var i = 0; i < _batch.pieces.length; i++) {
        expect(athanor.anyPiecesLeft, isTrue);
        await athanor.pour('test', AthanorPayment.tincture);
      }
      expect(athanor.anyPiecesLeft, isFalse);
    });
  });

  group('first fire', () {
    Future<void> claimAchievements(int n) async {
      for (final a in campaignAchievements.take(n)) {
        await db.settingsDao.setSetting('campaign_claim_${a.id}', '1');
      }
    }

    test('a fresh save gets 30, once', () async {
      final athanor = service(country: 'US');
      await athanor.load();
      // Not yet opened: the home emblem pulses to be found.
      expect(athanor.opened, isFalse);
      expect(await athanor.takeFirstFire(), kAthanorFirstFireTincture);
      expect(athanor.opened, isTrue);
      expect(await tincture(), kAthanorFirstFireTincture);
      expect(athanor.tincture, kAthanorFirstFireTincture);
      expect(await athanor.takeFirstFire(), 0);
      expect(await tincture(), kAthanorFirstFireTincture);

      // And not again from a fresh service.
      final again = service(country: 'US');
      await again.load();
      expect(again.opened, isTrue);
      expect(await again.takeFirstFire(), 0);
      expect(await tincture(), kAthanorFirstFireTincture);
    });

    test('pays back for each achievement and star claimed before', () async {
      await claimAchievements(3);
      // Volcanic's three stars claimed; oceanic's two earned, one claimed.
      SharedPreferences.setMockInitialValues({
        'cosmic_planet_stars': 'oceanic=3.1,volcanic=7.7',
      });
      final athanor = service(country: 'US');
      await athanor.load();
      const owed = 3 * kAthanorAchievementTincture + 4 * kAthanorStarTincture;
      expect(await athanor.takeFirstFire(), 30 + owed);
      expect(await tincture(), 30 + owed);
      expect(await athanor.takeFirstFire(), 0);
      expect(await tincture(), 30 + owed);
    });

    test('back-pay stops at 90', () async {
      final n = campaignAchievements.length;
      await claimAchievements(n);
      // Five planets' stars all claimed: fifteen.
      SharedPreferences.setMockInitialValues({
        'cosmic_planet_stars': 'Fire=7.7,Water=7.7,Earth=7.7,Air=7.7,Ice=7.7',
      });
      final owed = n * kAthanorAchievementTincture + 15 * kAthanorStarTincture;
      expect(owed, greaterThan(kAthanorFirstFireBackPayCap));
      final athanor = service(country: 'US');
      await athanor.load();
      expect(
        await athanor.takeFirstFire(),
        30 + min(kAthanorFirstFireBackPayCap, owed),
      );
      expect(await tincture(), 30 + kAthanorFirstFireBackPayCap);
    });

    test('stars earned but not claimed are not paid back: their claim pays '
        'them', () async {
      SharedPreferences.setMockInitialValues({
        'cosmic_planet_stars': 'volcanic=7.0',
      });
      final athanor = service(country: 'US');
      await athanor.load();
      expect(await athanor.takeFirstFire(), kAthanorFirstFireTincture);
    });

    test('claims that already paid tincture are not paid again', () async {
      await db.settingsDao.setSetting('first_extraction_done', '1');
      expect(
        await CampaignJournalService(db).claim('first_extraction'),
        isTrue,
      );
      expect(await tincture(), kAthanorAchievementTincture);
      // Two more claimed before the Athanor existed.
      await db.settingsDao.setSetting(
        'campaign_claim_${campaignAchievements[1].id}',
        '1',
      );
      await db.settingsDao.setSetting(
        'campaign_claim_${campaignAchievements[2].id}',
        '1',
      );
      final athanor = service(country: 'US');
      await athanor.load();
      expect(
        await athanor.takeFirstFire(),
        30 + 2 * kAthanorAchievementTincture,
      );
    });

    test('taken twice at once is still given once', () async {
      final athanor = service(country: 'US');
      await athanor.load();
      final given = await Future.wait([
        athanor.takeFirstFire(),
        athanor.takeFirstFire(),
      ]);
      expect(given..sort(), [0, kAthanorFirstFireTincture]);
      expect(await tincture(), kAthanorFirstFireTincture);
    });
  });

  test('a saved row it cannot read loads as a fresh state', () async {
    await db.settingsDao.setSetting(AthanorState.key, '{not json');
    await db.inventoryDao.addItemQty(
      InvKeys.athanorTincture,
      kAthanorTincturePerPour,
    );
    final athanor = service(country: 'US');
    await athanor.load();
    expect(athanor.loaded, isTrue);
    expect(athanor.drawnIn('test'), isEmpty);
    expect(athanor.dailyPourReady, isTrue);
    expect(await athanor.pour('test', AthanorPayment.tincture), isNotNull);
    expect(AthanorState.decode(await stateRow()).drawnIn('test'), hasLength(1));
  });
}
