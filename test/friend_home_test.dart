import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/survival_best_run.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/screens/friends/friend_best_run.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/models/profile_titles.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/utils/featured_instance.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('FriendCode', () {
    test('random codes are eight unambiguous characters', () {
      for (var i = 0; i < 200; i++) {
        final code = FriendCode.random();
        expect(code.length, 8);
        expect(FriendCode.normalize(code), code);
        expect(code, isNot(matches(RegExp('[ILO01]'))));
      }
    });

    test('entered codes are forgiving about case, spaces and dashes', () {
      expect(FriendCode.normalize('abcd-2345'), 'ABCD2345');
      expect(FriendCode.normalize(' ABCD 2345 '), 'ABCD2345');
      expect(FriendCode.pretty('ABCD2345'), 'ABCD-2345');
    });

    test('anything else is not a code', () {
      expect(FriendCode.normalize('ABCD234'), isNull);
      expect(FriendCode.normalize('ABCD23450'), isNull);
      // I, L, O, 0 and 1 are never in a code.
      expect(FriendCode.normalize('ABCD2O45'), isNull);
      expect(FriendCode.normalize('ABCD2145'), isNull);
      expect(FriendCode.normalize('ABCD-23!5'), isNull);
    });
  });

  test('publishHash is FNV-1a 64 and stable', () {
    expect(publishHash(''), 'cbf29ce484222325');
    expect(publishHash('a'), 'af63dc4c8601ec8c');
    expect(publishHash('abc'), 'e71fa2190541574b');
  });

  group('PlanetLook', () {
    test('round-trips, and bad input falls back to a plain Tiny planet', () {
      const look = PlanetLook(
        color: 'Void',
        size: 3,
        wearing: {'planetary_rings', 'vine_tendrils'},
        options: {'planetary_rings.count': 'Many'},
      );
      final back = PlanetLook.fromJson(jsonDecode(jsonEncode(look.toJson())));
      expect(back.color, 'Void');
      expect(back.size, 3);
      expect(back.wearing, look.wearing);
      expect(back.options, look.options);
      expect(back.worldRadius, 185);

      final bad = PlanetLook.fromJson({'size': 99, 'wearing': 'x'});
      expect(bad.size, 4);
      expect(bad.wearing, isEmpty);
      expect(PlanetLook.fromJson('nope').size, 0);
    });

    test('reads what the planet wears now from the cosmic save', () async {
      SharedPreferences.setMockInitialValues({
        kCosmicHomePlanetPrefsKey: HomePlanet(
          position: const Offset(12000, 12000),
          sizeTierLevel: 4,
          activeSizeTier: 2,
          activeColor: 'Fire',
          unlockedColors: {'Fire', 'Water'},
        ).serialise(),
        kCosmicCustomizationPrefsKey: HomeCustomizationState(
          unlockedIds: {'planetary_rings', 'flame_ring'},
          activeIds: {'planetary_rings'},
          options: {'planetary_rings.count': 'Many', 'flame_ring.size': 'Big'},
        ).serialise(),
      });
      final look = PlanetLook.read(await SharedPreferences.getInstance())!;
      expect(look.color, 'Fire');
      expect(look.size, 2);
      // Unlocked is not worn; options only for what is worn.
      expect(look.wearing, {'planetary_rings'});
      expect(look.options, {'planetary_rings.count': 'Many'});
    });

    test('is null before a planet is built', () async {
      SharedPreferences.setMockInitialValues({});
      expect(PlanetLook.read(await SharedPreferences.getInstance()), isNull);
    });
  });

  group('FriendHome', () {
    late AlchemonsDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AlchemonsDatabase(NativeDatabase.memory());
      await db.creatureDao.insertInstance(
        instanceId: 'a',
        baseId: 'HOR01',
        level: 40,
        nickname: 'Secret Name',
        isPrismaticSkin: true,
        genetics: {'size': 'large'},
        statStrength: 9.5,
        alchemyEffect: 'beauty_radiance',
        variantFaction: 'Pyro',
      );
      await db.creatureDao.updateCostumes(
        instanceId: 'a',
        costumes: '{"hat":"top"}',
      );
      await db.creatureDao.insertInstance(instanceId: 'b', baseId: 'WNG04');
    });

    tearDown(() => db.close());

    HomeBiomeLayout saved() => HomeBiomeLayout(
      hour: 18.8,
      moods: const {'valley': 'rain', 'sky': 'storm'},
      residents: const [
        HomeResident(instanceId: 'a', x: 0.1),
        HomeResident(instanceId: 'gone', x: 0.3),
        HomeResident(instanceId: 'b', x: 0.5, lift: 0.4),
      ],
      households: const {
        'sky': [HomeResident(instanceId: 'b', x: 0.2)],
      },
      pieces: {
        'valley': [
          ...HomeRealm.valley.defaultPieces,
          const HomePiece(id: 'try:lantern#0', kind: 'lantern_post'),
        ],
        'sky': HomeRealm.sky.defaultPieces,
      },
      seen: const {'maxim_fire'},
    );

    test('capture reads looks only, and never trims the save', () async {
      await saved().save(db.settingsDao);
      final home = await FriendHome.capture(
        db,
        trailOf: (id) => id == 'a' ? 'gilt_steps' : null,
        ambienceIn: (realm) => realm == 'valley' ? 'sun_motes' : null,
      );
      expect(home.layout.realm, HomeRealm.valley);
      expect([for (final r in home.layout.residents) r.instanceId], ['a', 'b']);
      expect(home.looks.keys, unorderedEquals(['a', 'b']));
      expect(home.looks['a']!.trail, 'gilt_steps');
      expect(home.looks['b']!.trail, isNull);
      expect(home.ambience, 'sun_motes');

      // The one released since is only left out, not cut from the save
      // (the home biome's own load does that, with the catalog in hand).
      final still = await HomeBiomeLayout.load(db.settingsDao);
      expect(still.residents.length, 3);
    });

    test(
      'what is published is one realm, with nothing about strength',
      () async {
        await saved().save(db.settingsDao);
        final raw = (await FriendHome.capture(db)).encode();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final layout = json['layout'] as Map<String, dynamic>;
        expect((layout['households'] as Map).keys, ['valley']);
        expect((layout['pieces'] as Map).keys, ['valley']);
        expect(layout['moods'], {'valley': 'rain'});
        expect(layout.containsKey('seen'), isFalse);
        // A piece only being tried on is not theirs to show.
        expect(raw.contains('try:'), isFalse);
        for (final word in [
          'Secret Name',
          'statStrength',
          'level',
          'nickname',
          'xp',
        ]) {
          expect(raw.contains(word), isFalse, reason: word);
        }
      },
    );

    test('decoded, each resident looks as it does at home', () async {
      await saved().save(db.settingsDao);
      final home = FriendHome.decode((await FriendHome.capture(db)).encode())!;
      expect(home.layout.hour, 18.8);
      expect(home.layout.mood.id, 'rain');
      expect(home.layout.residents[1].lift, 0.4);
      expect(
        [for (final p in home.layout.placed) p.id],
        [for (final p in HomeRealm.valley.defaultPieces) p.id],
      );

      final original = (await db.creatureDao.getInstance('a'))!;
      final rebuilt = home.looks['a']!.instance('a');
      expect(rebuilt.baseId, original.baseId);
      expect(rebuilt.geneticsJson, original.geneticsJson);
      expect(rebuilt.isPrismaticSkin, isTrue);
      expect(rebuilt.alchemyEffect, original.alchemyEffect);
      expect(rebuilt.costumes, '{"hat":"top"}');
      expect(rebuilt.variantFaction, 'Pyro');
      expect(rebuilt.nickname, isNull);
      expect(rebuilt.level, 1);
      expect(rebuilt.statStrength, 3);
    });

    test('residents without a look, and garbage, are left out', () {
      final raw = jsonEncode({
        'v': 9,
        'layout': {
          'realm': 'not_a_realm',
          'residents': [
            {'id': 'a', 'x': 0.1},
            {'id': 'b', 'x': 0.2},
          ],
        },
        'looks': {
          'a': {'b': 'HOR01'},
          'b': {'nope': true},
        },
      });
      final home = FriendHome.decode(raw)!;
      expect(home.layout.realm, HomeRealm.valley);
      expect([for (final r in home.layout.residents) r.instanceId], ['a']);
      expect(FriendHome.decode('{not json'), isNull);
      expect(FriendHome.decode(''), isNull);
      expect(FriendHome.decode(null), isNull);
    });
  });

  test('FriendCard falls back to a plain name and no planet', () {
    final card = FriendCard.fromJson('u1', {'name': '   ', 'planet': 3});
    expect(card.name, 'Alchemist');
    expect(card.planet, isNull);
    final full = FriendCard.fromJson('u2', {
      'name': 'Rowan',
      'faction': 'oceanic',
      'planet': {'color': 'Water', 'size': 4},
    });
    expect(full.name, 'Rowan');
    expect(full.faction, 'oceanic');
    expect(full.planet!.size, 4);
  });

  test('FriendCard reads a title and a featured look, and drops bad ones', () {
    final card = FriendCard.fromJson('u3', {
      'name': 'Rowan',
      'title': '  Red Fuser ',
      'featured': {'b': 'LET02', 'p': true},
    });
    expect(card.title, 'Red Fuser');
    expect(card.featured!.baseId, 'LET02');
    expect(card.featured!.prismatic, isTrue);
    final bad = FriendCard.fromJson('u4', {
      'name': 'Rowan',
      'title': 'x' * 41,
      'featured': {'p': true},
    });
    expect(bad.title, isNull);
    expect(bad.featured, isNull);
  });

  group('featured', () {
    late AlchemonsDatabase db;
    setUp(() => db = AlchemonsDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test(
      'the chosen one, else a prismatic one, else the most Potential',
      () async {
        expect(await loadFeaturedInstance(db), isNull);
        await db.creatureDao.insertInstance(instanceId: 'a', baseId: 'LET02');
        await db.creatureDao.insertInstance(
          instanceId: 'b',
          baseId: 'HOR02',
          isPrismaticSkin: true,
        );
        expect((await loadFeaturedInstance(db))!.instanceId, 'b');
        await db.settingsDao.setFeaturedInstanceId('a');
        expect((await loadFeaturedInstance(db))!.instanceId, 'a');
      },
    );

    // Author, 2026-10-11: "When viewing a friends planet we should probably
    // show their title too right? And maybe their featured Mon as well."
    test('is published with the title worn, for friends to read', () async {
      SharedPreferences.setMockInitialValues({'friends.code.aaaa': 'HX4N7QRT'});
      final fs = FakeFirebaseFirestore();
      await db.creatureDao.insertInstance(instanceId: 'a', baseId: 'LET02');
      await db.settingsDao.setFeaturedInstanceId('a');
      const made = MadeTitle(TitleColour.red, TitleWord.fuser);
      expect(await ProfileTitles.wear(db, made.id), isTrue);

      final friends = FriendService(
        account: _Account(_User('aaaa', 'Cody')),
        db: db,
        firestore: fs,
      );
      addTearDown(friends.dispose);
      await friends.refresh();
      await friends.publishIfChanged(force: true);

      final doc = await fs.collection('players').doc('aaaa').get();
      final card = FriendCard.fromJson('aaaa', doc.data());
      expect(card.title, 'Red Fuser');
      expect(card.featured!.baseId, 'LET02');

      // Taken off: published without one.
      await ProfileTitles.wear(db, null);
      await friends.publishIfChanged(force: true);
      final again = await fs.collection('players').doc('aaaa').get();
      expect(FriendCard.fromJson('aaaa', again.data()).title, isNull);
    });
  });

  // Author, 2026-10-11: "when adding friends and accepting, will they
  // automatically show?" — the sender's side did not until reopened.
  test('a sent request shows as answered without reopening', () async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({'friends.code.aaaa': 'HX4N7QRT'});
    final fs = FakeFirebaseFirestore();
    await fs.collection('friend_codes').doc('BCDE2345').set({'uid': 'bbbb'});
    await fs.collection('players').doc('bbbb').set({'name': 'Wren'});
    await fs.collection('friend_codes').doc('CDEF3456').set({'uid': 'cccc'});

    final friends = FriendService(
      account: _Account(_User('aaaa', 'Cody')),
      db: db,
      firestore: fs,
    );
    addTearDown(friends.dispose);
    await friends.refresh();
    expect(await friends.sendRequest('BCDE-2345'), 'Request sent.');
    expect(await friends.sendRequest('CDEF-3456'), 'Request sent.');
    expect(friends.outgoing.map((r) => r.to), ['bbbb', 'cccc']);

    // Wren accepts on their own device; Cody's lists are not re-read.
    final since = {'since': FieldValue.serverTimestamp()};
    await (fs.batch()
          ..set(
            fs
                .collection('players')
                .doc('bbbb')
                .collection('friends')
                .doc('aaaa'),
            since,
          )
          ..set(
            fs
                .collection('players')
                .doc('aaaa')
                .collection('friends')
                .doc('bbbb'),
            since,
          )
          ..delete(fs.collection('friend_requests').doc('aaaa_bbbb')))
        .commit();
    await pumpEventQueue();
    expect(friends.friends.map((f) => f.name), ['Wren']);
    expect(friends.outgoing.map((r) => r.to), ['cccc']);

    // The other declines.
    await fs.collection('friend_requests').doc('aaaa_cccc').delete();
    await pumpEventQueue();
    expect(friends.outgoing, isEmpty);

    // Wren removes Cody.
    await fs
        .collection('players')
        .doc('aaaa')
        .collection('friends')
        .doc('bbbb')
        .delete();
    await pumpEventQueue();
    expect(friends.friends, isEmpty);
  });

  // Author, 2026-10-11: "just a green dot by their name, and a seen 2 hours
  // ago etc."
  group('presence', () {
    test('seen, in the biggest whole unit', () {
      final now = DateTime(2026, 10, 11, 12);
      String at(Duration d) => seenAgo(now.subtract(d), now);
      expect(at(const Duration(seconds: 20)), 'Seen just now');
      expect(at(const Duration(minutes: 1)), 'Seen 1 minute ago');
      expect(at(const Duration(minutes: 59)), 'Seen 59 minutes ago');
      expect(at(const Duration(hours: 2, minutes: 40)), 'Seen 2 hours ago');
      expect(at(const Duration(days: 1)), 'Seen 1 day ago');
      expect(at(const Duration(days: 13)), 'Seen 13 days ago');
      expect(at(const Duration(days: 20)), 'Seen 2 weeks ago');
      expect(at(const Duration(days: 90)), 'Seen over a month ago');
    });

    test('the game says it is here, and away when it goes behind', () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      SharedPreferences.setMockInitialValues({'friends.code.aaaa': 'HX4N7QRT'});
      final fs = FakeFirebaseFirestore();
      final friends = FriendService(
        account: _Account(_User('aaaa', 'Cody')),
        db: db,
        firestore: fs,
      );
      addTearDown(friends.dispose);
      await friends.refresh();
      await pumpEventQueue();
      final here = await fs.collection('presence').doc('aaaa').get();
      expect(here.data()?['away'], isFalse);
      expect(here.data()?['at'], isA<Timestamp>());

      friends.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();
      final away = await fs.collection('presence').doc('aaaa').get();
      expect(away.data()?['away'], isTrue);

      friends.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      final back = await fs.collection('presence').doc('aaaa').get();
      expect(back.data()?['away'], isFalse);
    });

    test('a player without a code says nothing', () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      SharedPreferences.setMockInitialValues({});
      final fs = FakeFirebaseFirestore();
      final friends = FriendService(
        account: _Account(_User('aaaa', 'Cody')),
        db: db,
        firestore: fs,
      );
      addTearDown(friends.dispose);
      await pumpEventQueue();
      friends.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      final doc = await fs.collection('presence').doc('aaaa').get();
      expect(doc.exists, isFalse);
    });

    test('friends show online, then when they were seen', () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      SharedPreferences.setMockInitialValues({'friends.code.aaaa': 'HX4N7QRT'});
      final fs = FakeFirebaseFirestore();
      final since = {'since': Timestamp.now()};
      for (final (me, them) in [('aaaa', 'bbbb'), ('aaaa', 'cccc')]) {
        await fs
            .collection('players')
            .doc(me)
            .collection('friends')
            .doc(them)
            .set(since);
      }
      await fs.collection('players').doc('bbbb').set({'name': 'Wren'});
      await fs.collection('players').doc('cccc').set({'name': 'Ash'});
      final bbbb = fs.collection('presence').doc('bbbb');
      await bbbb.set({'at': Timestamp.now(), 'away': false});
      await fs.collection('presence').doc('cccc').set({
        'at': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 2, minutes: 5)),
        ),
        'away': false,
      });

      final friends = FriendService(
        account: _Account(_User('aaaa', 'Cody')),
        db: db,
        firestore: fs,
      );
      addTearDown(friends.dispose);
      await friends.refresh();
      // Nothing read until FRIENDS shows.
      expect(friends.isOnline('bbbb'), isFalse);
      expect(friends.seenLabel('bbbb'), isNull);

      friends.watchPresence();
      await pumpEventQueue();
      expect(friends.isOnline('bbbb'), isTrue);
      expect(friends.seenLabel('bbbb'), isNull);
      // Said nothing for two hours: gone, and when.
      expect(friends.isOnline('cccc'), isFalse);
      expect(friends.seenLabel('cccc'), 'Seen 2 hours ago');

      // Wren's game goes behind.
      await bbbb.set({'at': Timestamp.now(), 'away': true});
      await pumpEventQueue();
      expect(friends.isOnline('bbbb'), isFalse);
      expect(friends.seenLabel('bbbb'), 'Seen just now');

      // FRIENDS closes: no more listening, and nothing new is taken in.
      friends.unwatchPresence();
      await bbbb.set({'at': Timestamp.now(), 'away': false});
      await pumpEventQueue();
      expect(friends.isOnline('bbbb'), isFalse);
    });
  });

  // Author, 2026-10-16: show each friend's best Survival run, and a trophy
  // for whoever is furthest.
  group('best Survival run', () {
    const team = ['HOR01', 'LET12', 'PIP02', 'MAN09', 'WNG04'];
    final ranAt = DateTime(2026, 10, 13, 20, 15);

    test('the run kept is the furthest, then the highest scoring', () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final settings = db.settingsDao;
      Future<SurvivalBestRun?> kept() async => SurvivalBestRun.fromJson(
        jsonDecode((await settings.getSetting(SurvivalBestRun.settingKey))!),
      );
      await SurvivalBestRun.note(
        settings,
        wave: 12,
        score: 20000,
        team: team,
        at: ranAt,
      );
      await SurvivalBestRun.note(settings, wave: 9, score: 90000, team: []);
      expect((await kept())!.wave, 12);
      await SurvivalBestRun.note(settings, wave: 12, score: 26000, team: []);
      expect((await kept())!.score, 26000);
      await SurvivalBestRun.note(
        settings,
        wave: 13,
        score: 1,
        team: [...team, 'KIN01', '', 'x' * 30],
      );
      final run = (await kept())!;
      expect(run.wave, 13);
      // At most five, none empty or too long.
      expect(run.team, team);
    });

    test(
      'load gives the lobby\'s best, with the run that reached it',
      () async {
        final db = AlchemonsDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        expect(await SurvivalBestRun.load(db), isNull);
        await db.saveSurvivalHighScore(wave: 23, score: 48200, timeMs: 1);
        // From before runs were noted: the numbers, nothing else.
        var best = (await SurvivalBestRun.load(db))!;
        expect(best.figures, 'W23 · 48.2K');
        expect(best.at, isNull);
        expect(best.team, isEmpty);
        // A shorter run says nothing about the best.
        await SurvivalBestRun.note(
          db.settingsDao,
          wave: 15,
          score: 9000,
          team: team,
        );
        expect((await SurvivalBestRun.load(db))!.team, isEmpty);
        await SurvivalBestRun.note(
          db.settingsDao,
          wave: 23,
          score: 40100,
          team: team,
          at: ranAt,
        );
        best = (await SurvivalBestRun.load(db))!;
        // The lobby's score; that run's team and day.
        expect(best.score, 48200);
        expect(best.team, team);
        expect(best.at, ranAt);
        // The settings keys, where they are ahead of the table.
        await db.settingsDao.setSetting('cosmic_survival_best_wave', '24');
        expect((await SurvivalBestRun.load(db))!.wave, 24);
      },
    );

    test('when, in the biggest whole unit', () {
      final now = DateTime(2026, 10, 16, 12);
      String at(Duration d) => agoLabel(now.subtract(d), now);
      expect(at(const Duration(days: 3, hours: 2)), '3 days ago');
      expect(at(const Duration(days: 75)), '2 months ago');
      expect(at(const Duration(days: 400)), 'over a year ago');
      expect(
        seenAgo(now.subtract(const Duration(days: 75)), now),
        'Seen over a month ago',
      );
    });

    test('a document read as it may come', () {
      final run = survivalBestFromDoc({
        'wave': 23,
        'score': 48200,
        'at': Timestamp.fromDate(ranAt),
        'team': [...team, 7],
      })!;
      expect(run.figures, 'W23 · 48.2K');
      expect(run.at, ranAt);
      expect(run.team, team);
      expect(survivalBestFromDoc(null), isNull);
      expect(survivalBestFromDoc({'wave': 'x', 'score': 1}), isNull);
      expect(survivalBestFromDoc({'wave': -1, 'score': 1}), isNull);
      expect(survivalBestFromDoc({'wave': 0, 'score': 0}), isNull);
      // A doc without a team or a day: the numbers alone.
      final bare = survivalBestFromDoc({'wave': 4, 'score': 300})!;
      expect(bare.team, isEmpty);
      expect(bare.at, isNull);
    });

    test('published once, and again only when it changes', () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      SharedPreferences.setMockInitialValues({'friends.code.aaaa': 'HX4N7QRT'});
      final fs = FakeFirebaseFirestore();
      final doc = fs.collection('survival_best').doc('aaaa');
      final friends = FriendService(
        account: _Account(_User('aaaa', 'Cody')),
        db: db,
        firestore: fs,
      );
      addTearDown(friends.dispose);
      await pumpEventQueue();

      // Never played: nothing.
      await friends.publishIfChanged();
      expect((await doc.get()).exists, isFalse);

      await db.saveSurvivalHighScore(wave: 23, score: 48200, timeMs: 1);
      await SurvivalBestRun.note(
        db.settingsDao,
        wave: 23,
        score: 48200,
        team: team,
        at: ranAt,
      );
      await friends.publishIfChanged();
      final published = (await doc.get()).data()!;
      expect(published.keys.toSet(), {
        'wave',
        'score',
        'at',
        'team',
        'updatedAt',
      });
      expect(survivalBestFromDoc(published)!.figures, 'W23 · 48.2K');
      expect(published['team'], team);
      expect(friends.myBest!.wave, 23);
      // Nothing about how strong they are, nor their names.
      expect(jsonEncode(published['team']), isNot(contains('level')));

      // Unchanged: not written again (taken down meanwhile, it stays down).
      await doc.delete();
      await friends.publishIfChanged();
      expect((await doc.get()).exists, isFalse);

      // A new best goes out.
      await db.saveSurvivalHighScore(wave: 25, score: 51000, timeMs: 1);
      await SurvivalBestRun.note(
        db.settingsDao,
        wave: 25,
        score: 51000,
        team: team.take(3).toList(),
      );
      await friends.publishIfChanged();
      final again = survivalBestFromDoc((await doc.get()).data())!;
      expect(again.figures, 'W25 · 51.0K');
      expect(again.team, team.take(3).toList());
    });

    test('a player without a code publishes none', () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      SharedPreferences.setMockInitialValues({});
      final fs = FakeFirebaseFirestore();
      await db.saveSurvivalHighScore(wave: 23, score: 48200, timeMs: 1);
      final friends = FriendService(
        account: _Account(_User('aaaa', 'Cody')),
        db: db,
        firestore: fs,
      );
      addTearDown(friends.dispose);
      await pumpEventQueue();
      await friends.publishIfChanged(force: true);
      final doc = await fs.collection('survival_best').doc('aaaa').get();
      expect(doc.exists, isFalse);
    });

    /// Until what refresh() sends out on its own has gone (home is the
    /// last but the best run, which never fails).
    Future<void> sent(String uid) async {
      final prefs = await SharedPreferences.getInstance();
      for (
        var i = 0;
        i < 400 && prefs.getString('friends.published.$uid.home') == null;
        i++
      ) {
        await pumpEventQueue();
      }
      await pumpEventQueue(times: 40);
    }

    Future<void> befriend(FakeFirebaseFirestore fs, String uid) async {
      final since = {'since': Timestamp.now()};
      await fs
          .collection('players')
          .doc('aaaa')
          .collection('friends')
          .doc(uid)
          .set(since);
      await fs.collection('players').doc(uid).set({'name': uid});
    }

    test('read for each friend; absent or garbage is nothing', () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      SharedPreferences.setMockInitialValues({'friends.code.aaaa': 'HX4N7QRT'});
      await db.saveSurvivalHighScore(wave: 19, score: 35000, timeMs: 1);
      final fs = FakeFirebaseFirestore();
      for (final uid in ['bbbb', 'cccc', 'dddd']) {
        await befriend(fs, uid);
      }
      await fs.collection('survival_best').doc('bbbb').set({
        'wave': 31,
        'score': 102400,
        'at': Timestamp.fromDate(ranAt),
        'team': team,
      });
      await fs.collection('survival_best').doc('dddd').set({'wave': 'lots'});

      final friends = FriendService(
        account: _Account(_User('aaaa', 'Cody')),
        db: db,
        firestore: fs,
      );
      addTearDown(friends.dispose);
      await friends.refresh();
      expect(friends.error, isNull);
      final byUid = {for (final f in friends.friends) f.uid: f};
      expect(byUid.keys, unorderedEquals(['bbbb', 'cccc', 'dddd']));
      expect(byUid['bbbb']!.survival!.figures, 'W31 · 102.4K');
      expect(byUid['bbbb']!.survival!.team, team);
      expect(byUid['cccc']!.survival, isNull);
      expect(byUid['dddd']!.survival, isNull);
      // The player's own, beside them.
      expect(friends.myBest!.figures, 'W19 · 35.0K');
      await sent('aaaa');
    });

    // Rules from before survival_best (not deployed yet): its reads and
    // writes are refused, and everything else goes on as before.
    test('refused by the rules: nothing shown, the rest published', () async {
      const rules = '''
service cloud.firestore {
  match /databases/{database}/documents {
    match /players/{uid} {
      allow read, write: if true;
      match /friends/{other} {
        allow read, write: if true;
      }
    }
    match /homes/{uid} {
      allow read, write: if true;
    }
    match /presence/{uid} {
      allow read, write: if true;
    }
    match /friend_codes/{code} {
      allow read, write: if true;
    }
    match /friend_requests/{id} {
      allow read, write: if true;
    }
  }
}''';
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      SharedPreferences.setMockInitialValues({'friends.code.aaaa': 'HX4N7QRT'});
      await db.saveSurvivalHighScore(wave: 19, score: 35000, timeMs: 1);
      final fs = FakeFirebaseFirestore(securityRules: rules);
      await befriend(fs, 'bbbb');
      final friends = FriendService(
        account: _Account(_User('aaaa', 'Cody')),
        db: db,
        firestore: fs,
      );
      addTearDown(friends.dispose);
      await pumpEventQueue();
      await friends.refresh();
      expect(friends.error, isNull);
      expect(friends.friends.single.name, 'bbbb');
      expect(friends.friends.single.survival, isNull);

      await sent('aaaa');
      await friends.publishIfChanged(force: true);
      final player = await fs.collection('players').doc('aaaa').get();
      expect(player.data()?['code'], 'HX4N7QRT');
      expect((await fs.collection('homes').doc('aaaa').get()).exists, isTrue);
      // Tried again next time: nothing was taken as published.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('friends.published.aaaa.survival'), isNull);
    });

    Widget host(Widget child) => Provider<CreatureCatalog>.value(
      value: CreatureCatalog.fromList(const []),
      child: MaterialApp(home: Scaffold(body: child)),
    );

    testWidgets('a friend without one shows nothing for it', (tester) async {
      await tester.pumpWidget(
        host(
          const Column(
            children: [
              BestRunLine(run: null),
              FriendBestRunBlock(
                friend: FriendCard(uid: 'c', name: 'Ash'),
              ),
            ],
          ),
        ),
      );
      expect(find.byType(Text), findsNothing);
      expect(find.textContaining('W'), findsNothing);
    });

    testWidgets('their page shows the wave, the score and when', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          FriendBestRunBlock(
            friend: FriendCard(
              uid: 'b',
              name: 'Wren',
              survival: SurvivalBestRun(
                wave: 23,
                score: 48200,
                at: ranAt,
                team: team,
              ),
            ),
            now: ranAt.add(const Duration(days: 3, hours: 1)),
          ),
        ),
      );
      expect(find.text('BEST SURVIVAL RUN'), findsOneWidget);
      expect(find.text('W23 · 48.2K'), findsOneWidget);
      expect(find.text('3 days ago'), findsOneWidget);
    });
  });
}

class _User implements User {
  _User(this.uid, this.displayName);
  @override
  final String uid;
  @override
  final String? displayName;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Account extends ChangeNotifier implements AccountService {
  _Account(this.user);
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
