// Fusing with friends: two players' TradeServices on one fake Firestore,
// each with their own save and their own lab, fusing at the trade table.

import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/breeding_config_loaders.dart';
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/models/trade.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/breeding_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/friend_fusion_lab.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/services/trade_service.dart';
import 'package:alchemons/services/wild_breed_randomizer.dart';
import 'package:alchemons/widgets/trade/trade_origin.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

late CreatureCatalog catalog;
late ElementRecipeConfig elementRecipes;
late FamilyRecipeConfig familyRecipes;

Future<String> seed(
  AlchemonsDatabase db,
  String id, {
  String baseId = 'HOR01',
}) async {
  await db.creatureDao.insertInstance(
    instanceId: id,
    baseId: baseId,
    level: 5,
    natureId: 'Brave',
    statSpeedPotential: 61,
    statIntelligencePotential: 72,
    statStrengthPotential: 83,
    statBeautyPotential: 94,
  );
  return id;
}

/// The cultivation [db] holds, from a chamber or cold storage.
Future<EggPayload?> cultivation(AlchemonsDatabase db) async {
  final slots = await db.incubatorDao.watchSlots().first;
  for (final s in slots) {
    if (s.payloadJson != null) {
      return EggPayload.fromJson(jsonDecode(s.payloadJson!));
    }
  }
  final queued = await db.select(db.eggs).get();
  if (queued.isEmpty || queued.first.payloadJson == null) return null;
  return EggPayload.fromJson(jsonDecode(queued.first.payloadJson!));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await loadNatures();
    await GeneticsCatalog.load();
    final raw = await rootBundle.loadString(
      'assets/data/alchemons_creatures.json',
    );
    catalog = CreatureCatalog.fromList([
      for (final c
          in ((jsonDecode(raw) as Map<String, dynamic>)['creatures'] as List)
              .cast<Map<String, dynamic>>())
        Creature.fromJson(c),
    ]);
    elementRecipes = await loadElementRecipes();
    familyRecipes = await loadFamilyRecipes();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the model', () {
    test('a fused table reads as fused, not traded', () {
      final t = TradeTable.fromDoc({
        'a': 'a',
        'b': 'b',
        'aOffer': {'id': '1', 'card': '{}'},
        'bOffer': {'id': '2', 'card': '{}'},
        'mode': 'fuse',
        'aFuse': true,
        'bFuse': true,
        'status': 'fused',
        'result': '{}',
      })!;
      expect(t.done && t.fused && !t.traded, isTrue);
      expect(t.of('a').phase, TradePhase.done);
      expect(t.of('a').iReady, isFalse);
    });

    test('a fusion confirms with its own flags', () {
      TradeOffer o(String id) => TradeOffer(id: id, card: '{}');
      final t = TradeTable(
        a: 'a',
        b: 'b',
        aOffer: o('1'),
        bOffer: o('2'),
        mode: TradeMode.fuse,
        bFuse: true,
      );
      expect(t.of('a').phase, TradePhase.theyConfirmed);
      expect(t.of('a').waitingOnMe, isTrue);
      expect(t.of('b').phase, TradePhase.youConfirmed);
      // An older table, with no mode, trades.
      expect(TradeTable.fromDoc({'a': 'a', 'b': 'b'})!.mode, TradeMode.trade);
    });

    test('who fused it is kept, and said', () {
      const origin = FusionOrigin(
        byUid: 'a',
        byName: 'Cody',
        withUid: 'b',
        withName: 'Sam',
        atMs: 1760000000000,
      );
      final p = TradeProvenance.decode(
        const TradeProvenance([], fused: origin).encode(),
      )!;
      expect(p.fused!.withName, 'Sam');
      expect(tradeOriginLines(p).single, startsWith('Fused with Sam · '));
      final traded = p.plus(
        const TradeStep(
          fromUid: 'a',
          fromName: 'Cody',
          toUid: 'c',
          toName: 'Alex',
          atMs: 1760000000001,
        ),
      );
      final lines = tradeOriginLines(TradeProvenance.decode(traded.encode()));
      expect(lines.first, startsWith('Fused by Cody and Sam · '));
      expect(lines[1], startsWith('Traded to you by Cody'));
    });
  });

  test('a cultivation keeps its history to the Alchemon it hatches', () async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final made = await CreatureInstanceService(db).finalizeInstance(
      baseId: 'HOR01',
      rarity: 'Common',
      provenance: 'p',
      source: 'friend_fusion',
    );
    final row = (await db.creatureDao.getInstance(made.instanceId!))!;
    expect(row.provenance, 'p');
    expect(row.source, 'friend_fusion');
  });

  group('fusing at the table', () {
    late FakeFirebaseFirestore fs;
    late _Player cody, sam;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      cody = _Player('aaaa', 'Cody', fs);
      sam = _Player('bbbb', 'Sam', fs);
      cody.befriend(sam);
      sam.befriend(cody);
      await seed(cody.db, 'C1');
      await seed(cody.db, 'C2', baseId: 'LET01');
      await seed(sam.db, 'S1', baseId: 'HOR02');
      await cody.settle();
      await sam.settle();
    });

    tearDown(() async {
      await cody.close();
      await sam.close();
    });

    Future<void> upForFusion() async {
      await cody.trades.setMode(sam.card, TradeMode.fuse);
      await cody.trades.put(sam.card, 'C1');
      await sam.settle();
      await sam.trades.put(cody.card, 'S1');
      await cody.settle();
    }

    test('both confirm: each gets the same cultivation, and keeps their '
        'own', () async {
      await upForFusion();
      expect(sam.trades.tableWith('aaaa')!.fusing, isTrue);

      expect(await cody.trades.confirm(sam.card), ConfirmResult.waiting);
      await cody.settle();
      // Nothing waits on a fusion table: C1 stays in the collection.
      expect(await cody.db.creatureDao.getInstance('C1'), isNotNull);
      expect(await cody.trades.vault.escrowed(), isEmpty);
      expect(cody.trades.left(), 2);

      await sam.settle();
      expect(sam.trades.tableWith('aaaa')!.phase, TradePhase.theyConfirmed);
      expect(await sam.trades.confirm(cody.card), ConfirmResult.fused);
      await sam.settle();
      await cody.settle();
      await sam.settle();

      final mine = (await cultivation(cody.db))!;
      final theirs = (await cultivation(sam.db))!;
      expect(mine.source, 'friend_fusion');
      expect(theirs.baseId, mine.baseId);
      expect(theirs.natureId, mine.natureId);
      expect(theirs.potentials.toJson(), mine.potentials.toJson());
      expect(theirs.genetics, mine.genetics);
      expect(TradeProvenance.decode(mine.provenance)!.fused!.withName, 'Sam');
      expect(
        TradeProvenance.decode(theirs.provenance)!.fused!.withName,
        'Cody',
      );

      // Both parents stay with their owners, a bar of stamina spent.
      final c1 = (await cody.db.creatureDao.getInstance('C1'))!;
      final s1 = (await sam.db.creatureDao.getInstance('S1'))!;
      expect(c1.staminaBars, lessThan(c1.staminaMax));
      expect(s1.staminaBars, lessThan(s1.staminaMax));
      expect(await sam.db.creatureDao.getInstance('C1'), isNull);

      final t = cody.trades.tableWith('bbbb')!;
      expect(t.phase, TradePhase.done);
      expect(t.iClaimed && t.theyClaimed, isTrue);
      expect(cody.trades.left(), 2);
      expect(sam.trades.left(), 2);
      expect(cody.trades.arrivalWith('bbbb')!.fused, isTrue);
      expect(cody.trades.arrivalWith('bbbb')!.chamber, 0);

      // Collected once, however often it settles.
      await cody.trades.afterRestore();
      await cody.settle();
      expect(await cody.db.select(cody.db.eggs).get(), isEmpty);
      final full = (await cody.db.incubatorDao.watchSlots().first).where(
        (s) => s.eggId != null,
      );
      expect(full.length, 1);

      // The next table keeps fusing.
      await cody.trades.put(sam.card, 'C1');
      await sam.settle();
      expect(sam.trades.tableWith('aaaa')!.fusing, isTrue);
      expect(sam.trades.tableWith('aaaa')!.phase, TradePhase.yourTurn);
    });

    test('switching clears both confirmations', () async {
      await upForFusion();
      await cody.trades.confirm(sam.card);
      await sam.settle();
      await sam.trades.setMode(cody.card, TradeMode.trade);
      await cody.settle();
      final v = cody.trades.tableWith('bbbb')!;
      expect(v.fusing, isFalse);
      expect(v.iConfirmed || v.theyConfirmed, isFalse);
      expect(v.mine!.id, 'C1');
      expect(await cody.db.creatureDao.getInstance('C1'), isNotNull);
    });

    test('two families need Cross-Species Lineage', () async {
      await cody.trades.setMode(sam.card, TradeMode.fuse);
      await cody.trades.put(sam.card, 'C2');
      await sam.settle();
      await sam.trades.put(cody.card, 'S1');
      await cody.settle();
      expect(
        await cody.trades.whyNotFuse('bbbb'),
        'Two families: you need Cross-Species Lineage.',
      );
      await expectLater(
        cody.trades.confirm(sam.card),
        throwsA(isA<TradeException>()),
      );
      await cody.db.constellationDao.unlockSkill('breeder_cross_species', 0);
      expect(await cody.trades.whyNotFuse('bbbb'), isNull);
      expect(await cody.trades.confirm(sam.card), ConfirmResult.waiting);
      // Sam's own lab says no for Sam.
      await sam.settle();
      expect(
        await sam.trades.whyNotFuse('aaaa'),
        'Two families: you need Cross-Species Lineage.',
      );
    });

    test('a resting Alchemon can be up, not confirmed', () async {
      await upForFusion();
      await cody.db.creatureDao.updateStamina(
        instanceId: 'C1',
        staminaBars: 0,
        staminaLastUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      expect(await cody.trades.whyNotFuse('bbbb'), 'Yours is resting.');
      await expectLater(
        cody.trades.confirm(sam.card),
        throwsA(isA<TradeException>()),
      );
    });

    test('a favorite can fuse, though it can not trade', () async {
      await cody.db.creatureDao.setFavorite('C1', true);
      await expectLater(
        cody.trades.put(sam.card, 'C1'),
        throwsA(isA<TradeException>()),
      );
      await upForFusion();
      expect(cody.trades.tableWith('bbbb')!.mine!.id, 'C1');
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
    final breeding = BreedingServiceV2(
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
      constellation: ConstellationEffectsService(db),
      factions: FactionService(db),
      boosts: TimedBoostService(db.settingsDao),
    );
    trades.attachLab(
      FriendFusionLab(breeding: breeding, stamina: StaminaService(db)),
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
