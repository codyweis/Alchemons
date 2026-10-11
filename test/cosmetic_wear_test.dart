// What is worn of the Athanor's case styles, trails, fusion styles and
// home ambiences (lib/models/cosmetic_wear.dart,
// lib/services/cosmetic_wear_service.dart): its rows read back whatever is
// in them without throwing, only owned things are worn, and a creature's
// choices are its own and survive a reload.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/models/owned_cosmetics.dart';
import 'package:alchemons/services/cosmetic_wear_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decoding never throws and keeps only what it can read', () {
    const junk = [
      null,
      '',
      'not json',
      '[]',
      '[1, 2]',
      '"gilt"',
      '42',
      'null',
      '{"a": 5, "b": null, "c": ["gilt"], "d": {"x": 1}}',
      '{"a": "no_such_style"}',
      '{"": "gilt"}',
      '{"a": "gilt"',
    ];

    test('junk rows are empty', () {
      for (final raw in junk) {
        final w = CosmeticWear.decode(
          cases: raw,
          trails: raw,
          fusion: raw == '"gilt"' ? null : raw,
          ambience: raw,
        );
        expect(w.cases, isEmpty, reason: '$raw');
        expect(w.trails, isEmpty, reason: '$raw');
        expect(w.ambience, isEmpty, reason: '$raw');
      }
      for (final raw in [null, '', 'nope', '{}', '[]', '"nope"', '12']) {
        expect(CosmeticWear.decodeFusion(raw), isNull, reason: '$raw');
      }
    });

    test('good entries survive among bad ones', () {
      final w = CosmeticWear.decode(
        cases: '{"a": "gilt", "b": "nope", "c": 3, "d": "frost"}',
        trails: '{"a": "hoarfrost_steps", "b": "gilt"}',
        fusion: 'frost',
        ambience: '{"valley": "peat_mist", "sky": "fog"}',
      );
      expect(w.cases, {'a': CaseStyle.gilt, 'd': CaseStyle.frost});
      // A trail's id is not a case style's: "gilt" is not a trail.
      expect(w.trails, {'a': TrailStyle.hoarfrost});
      expect(w.fusion, FusionStyle.frost);
      expect(w.ambience, {'valley': HomeAmbience.peatMist});
      // The fusion row as a JSON string reads too.
      expect(CosmeticWear.decodeFusion('"ember"'), FusionStyle.ember);
    });

    test('a map encodes and decodes to itself', () {
      final map = {'b': CaseStyle.brass, 'a': CaseStyle.obsidian};
      final raw = CosmeticWear.encodeMap(map, (s) => s.id);
      expect(CosmeticWear.decodeMap(raw, CaseStyle.byId), map);
    });

    test('what is not owned is not shown', () {
      final w = CosmeticWear.decode(
        cases: '{"a": "gilt", "b": "frost"}',
        trails: '{"a": "gilt_steps"}',
        fusion: 'ink',
        ambience: '{"valley": "sun_motes"}',
      );
      final shown = w.owned({
        AthanorPieceKind.caseStyle: {'frost'},
      });
      expect(shown.cases, {'b': CaseStyle.frost});
      expect(shown.trails, isEmpty);
      expect(shown.fusion, isNull);
      expect(shown.ambience, isEmpty);
    });
  });

  group('the service', () {
    late AlchemonsDatabase db;
    setUp(() => db = AlchemonsDatabase(NativeDatabase.memory()));
    tearDown(() async {
      FusionStyle.worn.value = null;
      await db.close();
    });

    Future<CosmeticWearService> loaded() async {
      final s = CosmeticWearService(db);
      await s.load();
      return s;
    }

    test('only owned things can be worn; refusing changes nothing', () async {
      final s = await loaded();
      expect(await s.wearCase('a', CaseStyle.gilt), isFalse);
      expect(await s.wearTrail('a', TrailStyle.gilt), isFalse);
      expect(await s.wearFusionStyle(FusionStyle.ink), isFalse);
      expect(await s.wearAmbience('valley', HomeAmbience.peatMist), isFalse);
      expect(s.caseOf('a'), isNull);
      expect(s.trailOf('a'), isNull);
      expect(s.fusionStyle, isNull);
      expect(s.ambienceIn('valley'), isNull);
      expect(await db.settingsDao.getSetting(CosmeticWear.caseKey), isNull);
      expect(await db.settingsDao.getSetting(CosmeticWear.fusionKey), isNull);

      await OwnedCosmetics.grant(db, AthanorPieceKind.caseStyle, 'gilt');
      await s.load();
      expect(s.ownedCases, [CaseStyle.gilt]);
      expect(await s.wearCase('a', CaseStyle.gilt), isTrue);
      expect(s.caseOf('a'), CaseStyle.gilt);
      // Owning the gilt case owns nothing else.
      expect(await s.wearCase('a', CaseStyle.frost), isFalse);
      expect(s.caseOf('a'), CaseStyle.gilt);
      // The plain case is always allowed.
      expect(await s.wearCase('a', null), isTrue);
      expect(s.caseOf('a'), isNull);
    });

    test('each creature keeps its own, and it survives a reload', () async {
      await OwnedCosmetics.grant(db, AthanorPieceKind.caseStyle, 'gilt');
      await OwnedCosmetics.grant(db, AthanorPieceKind.caseStyle, 'frost');
      await OwnedCosmetics.grant(db, AthanorPieceKind.trail, 'hoarfrost_steps');
      await OwnedCosmetics.grant(db, AthanorPieceKind.ambience, 'ember_fall');
      final s = await loaded();
      await s.wearCase('a', CaseStyle.gilt);
      await s.wearCase('b', CaseStyle.frost);
      await s.wearTrail('b', TrailStyle.hoarfrost);
      await s.wearAmbience('volcano', HomeAmbience.emberFall);

      final again = await loaded();
      expect(again.caseOf('a'), CaseStyle.gilt);
      expect(again.caseOf('b'), CaseStyle.frost);
      expect(again.caseOf('c'), isNull);
      expect(again.trailOf('a'), isNull);
      expect(again.trailOf('b'), TrailStyle.hoarfrost);
      expect(again.ambienceIn('volcano'), HomeAmbience.emberFall);
      expect(again.ambienceIn('valley'), isNull);

      // Changing one creature leaves the other as it was.
      await again.wearCase('a', null);
      final third = await loaded();
      expect(third.caseOf('a'), isNull);
      expect(third.caseOf('b'), CaseStyle.frost);
    });

    test('a worn piece no longer owned shows plain, and comes back', () async {
      await OwnedCosmetics.grant(db, AthanorPieceKind.caseStyle, 'garnet');
      await OwnedCosmetics.grant(
        db,
        AthanorPieceKind.fusionStyle,
        'distillation',
      );
      final s = await loaded();
      await s.wearCase('a', CaseStyle.garnet);
      await s.wearFusionStyle(FusionStyle.distillation);
      expect(FusionStyle.worn.value, FusionStyle.distillation);

      // A restored save that never owned them.
      await db.settingsDao.setSetting(OwnedCosmetics.key, '{}');
      await s.load();
      expect(s.caseOf('a'), isNull);
      expect(s.fusionStyle, isNull);
      expect(FusionStyle.worn.value, isNull);

      // Owned again, the choice is still there.
      await OwnedCosmetics.grant(db, AthanorPieceKind.caseStyle, 'garnet');
      await s.load();
      expect(s.caseOf('a'), CaseStyle.garnet);
    });

    test('the worn fusion style is what the fusion fields read', () async {
      await OwnedCosmetics.grant(db, AthanorPieceKind.fusionStyle, 'gilt');
      final s = await loaded();
      expect(FusionStyle.worn.value, isNull);
      await s.wearFusionStyle(FusionStyle.gilt);
      expect(FusionStyle.worn.value, FusionStyle.gilt);
      expect(await db.settingsDao.getSetting(CosmeticWear.fusionKey), 'gilt');
      await s.wearFusionStyle(null);
      expect(FusionStyle.worn.value, isNull);
    });

    test('a junk row reads as nothing worn', () async {
      await OwnedCosmetics.grant(db, AthanorPieceKind.caseStyle, 'gilt');
      await db.settingsDao.setSetting(CosmeticWear.caseKey, '{oops');
      await db.settingsDao.setSetting(CosmeticWear.fusionKey, '[[');
      final s = await loaded();
      expect(s.caseOf('a'), isNull);
      // Wearing still works over it.
      expect(await s.wearCase('a', CaseStyle.gilt), isTrue);
      expect((await loaded()).caseOf('a'), CaseStyle.gilt);
    });
  });
}
