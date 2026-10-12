import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
}
