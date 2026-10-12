// Trading with friends: the model, the save's side (TradeVault), and two
// players' TradeServices on one fake Firestore, each with their own save.

import 'dart:convert';
import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/models/owned_cosmetics.dart';
import 'package:alchemons/models/trade.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/cosmetic_wear_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/services/trade_service.dart';
import 'package:alchemons/services/trade_vault.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

late CreatureCatalog catalog;

Future<String> seed(
  AlchemonsDatabase db,
  String id, {
  String baseId = 'HOR01',
  int level = 4,
  bool favorite = false,
  String? effect,
}) async {
  await db.creatureDao.insertInstance(
    instanceId: id,
    baseId: baseId,
    level: level,
    natureId: 'Brave',
    statSpeedPotential: 61,
    statIntelligencePotential: 72,
    statStrengthPotential: 83,
    statBeautyPotential: 94,
    statStrengthEnhancement: 3,
    nickname: 'Pip $id',
  );
  if (effect != null) {
    await db.creatureDao.updateAlchemyEffect(instanceId: id, effect: effect);
  }
  if (favorite) await db.creatureDao.setFavorite(id, true);
  return id;
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final json =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    catalog = CreatureCatalog.fromList([
      for (final c in (json['creatures'] as List).cast<Map<String, dynamic>>())
        Creature.fromJson(c),
    ]);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('TradeRules', () {
    test('weeks start Monday 00:00 UTC', () {
      expect(
        TradeRules.weekOf(DateTime.utc(2026, 10, 11, 23, 59)),
        '2026-10-05',
      );
      expect(TradeRules.weekOf(DateTime.utc(2026, 10, 12)), '2026-10-12');
      expect(TradeRules.weekOf(DateTime.utc(2026, 10, 5)), '2026-10-05');
      expect(
        TradeRules.nextReset(DateTime.utc(2026, 10, 11, 10)),
        DateTime.utc(2026, 10, 12),
      );
      expect(
        TradeRules.untilText(
          DateTime.utc(2026, 10, 10, 1),
          DateTime.utc(2026, 10, 12),
        ),
        '1d 23h',
      );
    });

    test('an allowance counts only its own week', () {
      final now = DateTime.utc(2026, 10, 11);
      const old = TradeAllowance(week: '2026-09-28', used: 3);
      expect(old.left(now), 3);
      final used = old.plusOne(now);
      expect(used.week, '2026-10-05');
      expect(used.left(now), 2);
    });
  });

  group('TradeProvenance', () {
    test('keeps its first owner and newest steps', () {
      var p = const TradeProvenance([]);
      for (var i = 0; i < 30; i++) {
        p = p.plus(
          TradeStep(
            fromUid: 'u$i',
            fromName: 'N$i',
            toUid: 'u${i + 1}',
            toName: 'N${i + 1}',
            atMs: i,
          ),
        );
      }
      final back = TradeProvenance.decode(p.encode())!;
      expect(back.steps.length, TradeProvenance.maxSteps);
      expect(back.firstName, 'N0');
      expect(back.last!.toName, 'N30');
      expect(TradeProvenance.decode('nonsense'), isNull);
    });
  });

  group('TradedCreature', () {
    test('cleans what a friend sends', () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db, 'X', favorite: true, effect: 'alchemy_glow');
      final row = (await db.creatureDao.getInstance('X'))!.copyWith(
        level: 99,
        statSpeedPotential: 400,
        statBeautyEnhancement: 77,
        alchemyEffect: const Value('made_up_effect'),
        nickname: Value('x' * 80),
      );
      final card = TradedCreature(
        instance: row,
        caseStyle: CaseStyle.gilt,
      ).encode();
      final back = TradedCreature.decode(
        card,
        knownSpecies: (id) => catalog.getCreatureById(id) != null,
      )!;
      expect(back.instance.level, 10);
      expect(back.instance.statSpeedPotential, 100);
      expect(back.instance.statBeautyEnhancement, 10);
      expect(back.instance.alchemyEffect, isNull);
      expect(back.instance.nickname!.length, 24);
      expect(back.instance.isFavorite, isFalse);
      expect(back.instance.locked, isFalse);
      expect(back.caseStyle, CaseStyle.gilt);
      expect(TradedCreature.decode(card, knownSpecies: (_) => false), isNull);
    });
  });

  group('TradeView', () {
    test('phases', () {
      TradeOffer o(String id) => TradeOffer(id: id, card: '{}');
      TradePhase p(TradeTable t) => t.of('a').phase;
      expect(p(const TradeTable(a: 'a', b: 'b')), TradePhase.empty);
      expect(
        p(TradeTable(a: 'a', b: 'b', aOffer: o('1'))),
        TradePhase.waitingForThem,
      );
      expect(
        p(TradeTable(a: 'a', b: 'b', bOffer: o('2'))),
        TradePhase.yourTurn,
      );
      expect(
        p(TradeTable(a: 'a', b: 'b', aOffer: o('1'), bOffer: o('2'))),
        TradePhase.bothUp,
      );
      final theyConfirmed = TradeTable(
        a: 'a',
        b: 'b',
        aOffer: o('1'),
        bOffer: o('2'),
        bReady: true,
      );
      expect(p(theyConfirmed), TradePhase.theyConfirmed);
      expect(theyConfirmed.of('a').waitingOnMe, isTrue);
      expect(theyConfirmed.of('b').phase, TradePhase.youConfirmed);
      expect(theyConfirmed.of('b').waitingOnMe, isFalse);
      expect(TradeTable.idFor('zz', 'aa'), 'aa_zz');
    });
  });

  group('TradeVault', () {
    late AlchemonsDatabase db;
    late TradeVault vault;
    setUp(() {
      db = AlchemonsDatabase(NativeDatabase.memory());
      vault = TradeVault(db, catalog: catalog);
    });
    tearDown(() => db.close());

    test('refuses favorites and busy Alchemons', () async {
      await seed(db, 'F', favorite: true);
      await seed(db, 'S');
      await seed(db, 'P');
      await db.settingsDao.setCosmicPartySlotInstance(1, 'P');
      expect(
        await vault.whyNot((await db.creatureDao.getInstance('F'))!),
        contains('Favorites'),
      );
      expect(
        await vault.whyNot((await db.creatureDao.getInstance('P'))!),
        contains('party'),
      );
      final s = (await db.creatureDao.getInstance('S'))!;
      expect(await vault.whyNot(s), isNull);
      expect(await vault.whyNot(s, elsewhere: {'S'}), contains('another'));
    });

    test(
      'a confirmed Alchemon waits on its table and comes back whole',
      () async {
        await seed(db, 'W', effect: 'alchemy_glow');
        final before = (await db.creatureDao.getInstance('W'))!;
        expect(await vault.escrow('a_b', 'W'), isTrue);
        expect(await db.creatureDao.getInstance('W'), isNull);
        expect((await vault.escrowed())['a_b']!.instanceId, 'W');
        final back = await vault.release('a_b');
        expect(back, isNotNull);
        expect(await db.creatureDao.getInstance('W'), before);
        expect(await vault.escrowed(), isEmpty);
      },
    );

    test('collects a done trade once, wearing what it came in', () async {
      await seed(db, 'MINE');
      await db.settingsDao.setFeaturedInstanceId('MINE');
      await OwnedCosmetics.grant(db, AthanorPieceKind.trail, 'gilt_steps');
      await db.settingsDao.setSetting(
        CosmeticWear.trailKey,
        jsonEncode({'MINE': 'gilt_steps'}),
      );

      final friendDb = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(friendDb.close);
      await seed(
        friendDb,
        'THEIRS',
        baseId: 'HOR02',
        level: 7,
        effect: 'dust_ring',
      );
      final sent = (await TradeVault(
        friendDb,
        catalog: catalog,
      ).card('THEIRS'))!;
      final card = TradedCreature(
        instance: sent.instance,
        caseStyle: CaseStyle.garnet, // not owned here
      );
      final got = vault.read(card.encode())!;
      const step = TradeStep(
        fromUid: 'b',
        fromName: 'Sam',
        toUid: 'a',
        toName: 'Cody',
        atMs: 1000,
      );
      final arrived = await vault.collect(
        key: 'a_b@1000',
        tableId: 'a_b',
        giveId: 'MINE',
        got: got,
        step: step,
      );
      expect(arrived, isNotNull);
      expect(await db.creatureDao.getInstance('MINE'), isNull);
      expect(await db.settingsDao.getFeaturedInstanceId(), isNot('MINE'));
      expect(await db.settingsDao.getSetting(CosmeticWear.trailKey), '{}');

      final row = (await db.creatureDao.getInstance('THEIRS'))!;
      expect(row.baseId, 'HOR02');
      expect(row.level, 7);
      expect(row.alchemyEffect, 'dust_ring');
      expect(row.statStrengthEnhancement, 3);
      // Its stats are worked out again, as every load does.
      expect(row.statSpeed, isNot(3.0));
      expect(TradeProvenance.decode(row.provenance)!.firstName, 'Sam');

      // It stands in its garnet case here though garnet isn't owned here.
      final wear = CosmeticWearService(db);
      await wear.load();
      expect(wear.caseOf('THEIRS'), CaseStyle.garnet);
      expect(await wear.wearCase('MINE2', CaseStyle.garnet), isFalse);

      // Once only.
      expect(
        await vault.collect(
          key: 'a_b@1000',
          tableId: 'a_b',
          giveId: 'MINE',
          got: got,
          step: step,
        ),
        isNull,
      );
      expect(await db.creatureDao.countBySpecies('HOR02'), 1);
    });

    test('a restored save gives back nothing traded away', () async {
      await seed(db, 'OLD');
      await seed(db, 'BACK');
      // BACK left at 100 and came back at 200; OLD left at 300.
      await db.settingsDao.setSetting(
        TradeVault.receiptsKey,
        jsonEncode({
          'k@200': {'gave': 'Z', 'got': 'BACK', 'at': 200},
        }),
      );
      final n = await vault.enforceGone({'OLD': 300, 'BACK': 100});
      expect(n, 1);
      expect(await db.creatureDao.getInstance('OLD'), isNull);
      expect(await db.creatureDao.getInstance('BACK'), isNotNull);
    });
  });

  group('TradeService', () {
    late FakeFirebaseFirestore fs;
    late _Player cody, sam;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      cody = _Player('aaaa', 'Cody', fs);
      sam = _Player('bbbb', 'Sam', fs);
      cody.befriend(sam);
      sam.befriend(cody);
      await seed(cody.db, 'C1', level: 6, effect: 'alchemy_glow');
      await seed(cody.db, 'C2');
      await seed(sam.db, 'S1', baseId: 'HOR02', level: 9);
      await cody.settle();
      await sam.settle();
    });

    tearDown(() async {
      await cody.close();
      await sam.close();
    });

    test('both confirm: each game collects the other\'s Alchemon', () async {
      await cody.trades.put(sam.card, 'C1');
      await sam.settle();
      expect(sam.trades.tableWith('aaaa')!.phase, TradePhase.yourTurn);
      expect(sam.trades.hasAttention, isTrue);

      await sam.trades.put(cody.card, 'S1');
      await cody.settle();
      expect(cody.trades.tableWith('bbbb')!.phase, TradePhase.bothUp);

      expect(await cody.trades.confirm(sam.card), ConfirmResult.waiting);
      await cody.settle();
      // C1 waits on the table, out of Cody's collection.
      expect(await cody.db.creatureDao.getInstance('C1'), isNull);
      expect(cody.trades.waitingWith('bbbb')!.instanceId, 'C1');
      expect(cody.trades.left(), 2);
      await sam.settle();
      expect(sam.trades.tableWith('aaaa')!.phase, TradePhase.theyConfirmed);

      expect(await sam.trades.confirm(cody.card), ConfirmResult.traded);
      await sam.settle();
      await cody.settle();

      final codyGot = (await cody.db.creatureDao.getInstance('S1'))!;
      expect(codyGot.level, 9);
      expect(TradeProvenance.decode(codyGot.provenance)!.firstName, 'Sam');
      final samGot = (await sam.db.creatureDao.getInstance('C1'))!;
      expect(samGot.alchemyEffect, 'alchemy_glow');
      expect(samGot.nickname, 'Pip C1');
      expect(TradeProvenance.decode(samGot.provenance)!.last!.toName, 'Sam');
      expect(await sam.db.creatureDao.getInstance('S1'), isNull);
      expect(await cody.db.creatureDao.getInstance('C1'), isNull);
      expect(await cody.trades.vault.escrowed(), isEmpty);

      final t = cody.trades.tableWith('bbbb')!;
      expect(t.phase, TradePhase.done);
      expect(t.iClaimed && t.theyClaimed, isTrue);
      expect(cody.trades.left(), 2);
      expect(sam.trades.left(), 2);
      expect(cody.trades.arrivalWith('bbbb'), isNotNull);
      final codyTrader = await fs.collection('traders').doc('aaaa').get();
      expect((codyTrader.data()!['gone'] as Map).keys, ['C1']);

      // The table can be used again.
      await cody.trades.put(sam.card, 'C2');
      await sam.settle();
      expect(sam.trades.tableWith('aaaa')!.phase, TradePhase.yourTurn);
    });

    test('a change on the table clears both confirmations', () async {
      await cody.trades.put(sam.card, 'C1');
      await sam.trades.put(cody.card, 'S1');
      await cody.settle();
      await cody.trades.confirm(sam.card);
      await cody.settle();
      expect(await cody.db.creatureDao.getInstance('C1'), isNull);

      // Cody swaps in C2: C1 comes back and nobody is confirmed.
      await cody.trades.put(sam.card, 'C2');
      await cody.settle();
      expect(await cody.db.creatureDao.getInstance('C1'), isNotNull);
      final v = cody.trades.tableWith('bbbb')!;
      expect(v.iReady || v.theyReady, isFalse);
      expect(v.mine!.id, 'C2');
    });

    test('taking a confirmation back returns the Alchemon', () async {
      await cody.trades.put(sam.card, 'C1');
      await sam.trades.put(cody.card, 'S1');
      await cody.settle();
      await cody.trades.confirm(sam.card);
      await cody.settle();
      await cody.trades.unconfirm('bbbb');
      await cody.settle();
      final back = await cody.db.creatureDao.getInstance('C1');
      expect(back, isNotNull);
      expect(back!.alchemyEffect, 'alchemy_glow');
      expect(cody.trades.tableWith('bbbb')!.mine!.id, 'C1');
    });

    test('three a week, then 100 gold for three more', () async {
      await cody.trades.put(sam.card, 'C1');
      await fs.collection('traders').doc('aaaa').set({
        'week': TradeRules.weekOf(DateTime.now()),
        'used': 3,
        'gone': <String, int>{},
        'updatedAt': DateTime.now(),
      });
      await sam.trades.put(cody.card, 'S1');
      await cody.settle();
      expect(cody.trades.left(), 0);
      await expectLater(
        cody.trades.confirm(sam.card),
        throwsA(isA<TradeException>()),
      );
      final start = await cody.db.currencyDao.getGoldBalance();
      await cody.db.currencyDao.addGold(-start + 60);
      expect(await cody.trades.buyMore(), isFalse); // 60 is not enough
      await cody.db.currencyDao.addGold(90);
      expect(await cody.trades.buyMore(), isTrue);
      await cody.settle();
      expect(await cody.db.currencyDao.getGoldBalance(), 50);
      expect(cody.trades.left(), 3);
      expect(await cody.trades.confirm(sam.card), ConfirmResult.waiting);
    });

    test('a friendship that ends leaves nothing on the table', () async {
      await cody.trades.put(sam.card, 'C1');
      await sam.trades.put(cody.card, 'S1');
      await cody.settle();
      await cody.trades.confirm(sam.card);
      await cody.settle();
      expect(await cody.db.creatureDao.getInstance('C1'), isNull);
      cody.unfriendAll();
      await cody.settle();
      expect(await cody.db.creatureDao.getInstance('C1'), isNotNull);
    });
  });
}

class _Player {
  _Player(this.uid, this.name, FakeFirebaseFirestore fs)
    : db = AlchemonsDatabase(NativeDatabase.memory()) {
    account = _FakeAccount(_FakeUser(uid, name));
    friends = _FakeFriends();
    trades = TradeService(
      account: account,
      db: db,
      catalog: catalog,
      friends: friends,
      firestore: fs,
    );
  }

  final String uid, name;
  final AlchemonsDatabase db;
  late final _FakeAccount account;
  late final _FakeFriends friends;
  late final TradeService trades;

  FriendCard get card => FriendCard(uid: uid, name: name);

  void befriend(_Player other) {
    friends.list = [...friends.list, other.card];
    friends.ping();
  }

  void unfriendAll() {
    friends.list = const [];
    friends.ping();
  }

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await pumpEventQueue();
      await trades.idle;
    }
  }

  Future<void> close() async {
    await trades.idle;
    trades.dispose();
    await db.close();
  }
}

class _FakeUser implements User {
  _FakeUser(this.uid, this.displayName);
  @override
  final String uid;
  @override
  final String? displayName;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAccount extends ChangeNotifier implements AccountService {
  _FakeAccount(this.user);
  @override
  final User? user;
  @override
  bool get initialized => true;
  @override
  bool get isConfigured => true;
  @override
  bool get isSignedIn => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeFriends extends ChangeNotifier implements FriendService {
  List<FriendCard> list = const [];
  void ping() => notifyListeners();
  @override
  List<FriendCard> get friends => list;
  @override
  bool get available => true;
  @override
  String? get code => 'HX4N-7QRT';
  @override
  bool get loaded => true;
  @override
  void publishSoon() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
