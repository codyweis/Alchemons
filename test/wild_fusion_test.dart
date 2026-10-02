import 'dart:convert';
import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/creature_stats.dart';
import 'package:alchemons/models/egg/egg_payload.dart' as egg;
import 'package:alchemons/models/potential_genetics.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// What a wild fusion gives that the chamber cannot: the wild parent's best
// Potential always reaches the child, and a wilderness child can be mutated.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CreatureStats stats(double spd, double intel, double str, double bea) =>
      CreatureStats(
        speed: 1,
        intelligence: 1,
        strength: 1,
        beauty: 1,
        speedPotential: spd,
        intelligencePotential: intel,
        strengthPotential: str,
        beautyPotential: bea,
      );

  group('wildTopPotential', () {
    test('picks the highest of the four', () {
      final top = wildTopPotential(stats(40, 55, 91, 70))!;
      expect(top.stat, StatKind.strength);
      expect(top.value, 91);
    });

    test('a tie goes to the stat the scanner shows first', () {
      expect(wildTopPotential(stats(60, 80, 80, 80))!.stat,
          StatKind.intelligence);
      expect(wildTopPotential(stats(77, 77, 77, 77))!.stat, StatKind.speed);
    });

    test('no stats, no guarantee', () {
      expect(wildTopPotential(null), isNull);
    });
  });

  group('AlchemonMutation.roll', () {
    test('about one in a hundred of each', () {
      final rng = Random(7);
      final counts = <AlchemonMutation?, int>{};
      const n = 200000;
      for (var i = 0; i < n; i++) {
        final m = AlchemonMutation.roll(rng, prismatic: false);
        counts[m] = (counts[m] ?? 0) + 1;
      }
      for (final m in AlchemonMutation.values) {
        expect(counts[m]! / n, closeTo(AlchemonMutation.chance, 0.0015));
      }
    });

    test('a prismatic child can be Alchemized but never Transmuted', () {
      final rng = Random(11);
      var alchemized = 0;
      for (var i = 0; i < 100000; i++) {
        final m = AlchemonMutation.roll(rng, prismatic: true);
        expect(m, isNot(AlchemonMutation.transmuted));
        if (m == AlchemonMutation.alchemized) alchemized++;
      }
      expect(alchemized, greaterThan(500));
    });

    test('ids round-trip', () {
      for (final m in AlchemonMutation.values) {
        expect(AlchemonMutation.byId(m.id), m);
      }
      expect(AlchemonMutation.byId(null), isNull);
      expect(AlchemonMutation.byId('nonsense'), isNull);
    });
  });

  test('the debug mutation only works with the tools on, and clears', () async {
    SharedPreferences.setMockInitialValues({});
    final debug = DebugSettingsService();
    await debug.setForcedWildMutation('transmuted');

    await debug.setEnabled(false);
    expect(await debug.pendingForcedWildMutation(), isNull);

    await debug.setEnabled(true);
    expect(await debug.pendingForcedWildMutation(), 'transmuted');

    // What the encounter does once the fusion lands.
    await debug.setForcedWildMutation(null);
    expect(await debug.pendingForcedWildMutation(), isNull);
    expect(DebugSettingsService.forcedWildMutationNotifier.value, isNull);
    await debug.setEnabled(false);
  });

  test('a cultivation payload keeps its mutation', () {
    final payload = egg.EggPayload(
      baseId: 'LET02',
      rarity: 'Common',
      source: 'wild_fusion',
      genetics: const {},
      mutation: 'alchemized',
      stats: const egg.CreatureStats(
        speed: 0,
        intelligence: 0,
        strength: 0,
        beauty: 0,
      ),
      potentials: egg.CreatureStatPotentials(
        speed: 50,
        intelligence: 50,
        strength: 50,
        beauty: 50,
      ),
      lineage: egg.LineageData(
        generationDepth: 0,
        factionLineage: const {},
        elementLineage: const {},
        familyLineage: const {},
      ),
    );
    final back = egg.EggPayload.fromJson(
      jsonDecode(payload.toJsonString()) as Map<String, dynamic>,
    );
    expect(back.mutation, 'alchemized');
  });

  group('the engine guarantees the wild top Potential', () {
    late CreatureCatalog repository;
    late ElementRecipeConfig elementRecipes;
    late FamilyRecipeConfig familyRecipes;

    setUpAll(() async {
      await loadNatures();
      await GeneticsCatalog.load();
      final creaturesJson =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/data/alchemons_creatures.json',
                ),
              )
              as Map<String, dynamic>;
      repository = CreatureCatalog.fromList(
        (creaturesJson['creatures'] as List<dynamic>)
            .map((j) => Creature.fromJson(j as Map<String, dynamic>))
            .toList(growable: false),
      );
      final elementSrc =
          (jsonDecode(
                    await rootBundle.loadString(
                      'assets/data/alchemons_element_recipes.json',
                    ),
                  )
                  as Map<String, dynamic>)['recipes']
              as Map<String, dynamic>;
      final elementOut = <String, Map<String, int>>{};
      for (final e in elementSrc.entries) {
        final inner = {
          for (final r in (e.value as Map<String, dynamic>).entries)
            ElementRecipeConfig.norm(r.key): (r.value as num).toInt(),
        };
        if (e.key.contains('+')) {
          final parts = e.key.split('+').map((s) => s.trim()).toList();
          elementOut[ElementRecipeConfig.keyOf(parts[0], parts[1])] = inner;
        } else {
          elementOut[ElementRecipeConfig.norm(e.key.trim())] = inner;
        }
      }
      elementRecipes = ElementRecipeConfig(recipes: elementOut);
      final familySrc =
          (jsonDecode(
                    await rootBundle.loadString(
                      'assets/data/alchemons_family_recipes.json',
                    ),
                  )
                  as Map<String, dynamic>)['recipes']
              as Map<String, dynamic>;
      familyRecipes = FamilyRecipeConfig.fromRaw(
        familySrc.map(
          (k, v) => MapEntry(
            k,
            (v as Map<String, dynamic>).map(
              (f, w) =>
                  MapEntry(FamilyRecipeConfig.norm(f), (w as num).toInt()),
            ),
          ),
        ),
      );
    });

    db.CreatureInstance owned(String baseId, double potential) =>
        db.CreatureInstance(
          instanceId: 'owned',
          baseId: baseId,
          level: 1,
          xp: 0,
          locked: false,
          isPrismaticSkin: false,
          source: 'test',
          staminaMax: 3,
          staminaBars: 3,
          staminaLastUtcMs: 0,
          createdAtUtcMs: 0,
          statSpeed: 3,
          statIntelligence: 3,
          statStrength: 3,
          statBeauty: 3,
          statSpeedPotential: potential,
          statIntelligencePotential: potential,
          statStrengthPotential: potential,
          statBeautyPotential: potential,
          statSpeedEnhancement: 0,
          statIntelligenceEnhancement: 0,
          statStrengthEnhancement: 0,
          statBeautyEnhancement: 0,
          generationDepth: 0,
          isPure: true,
          isFavorite: false,
        );

    test('every child gets at least the wild best, in that stat', () {
      final parent = owned('LET02', 20);
      final wild = repository
          .getCreatureById('LET02')!
          .copyWith(stats: stats(30, 25, 94, 35));
      var belowWithout = 0;
      for (var seed = 0; seed < 300; seed++) {
        BreedingEngine engine() => BreedingEngine(
          repository,
          elementRecipes: elementRecipes,
          familyRecipes: familyRecipes,
          tuning: const BreedingTuning(globalMutationChance: 0),
          random: Random(seed),
        );
        final child = engine().breedInstanceWithCreature(parent, wild).creature!;
        expect(child.stats!.strengthPotential, greaterThanOrEqualTo(94));

        // Without the guarantee (two owned parents), most fall short.
        final lab = engine()
            .breedInstances(parent, owned('LET02', 94))
            .creature!;
        if (lab.stats!.strengthPotential < 94) belowWithout++;
      }
      expect(belowWithout, greaterThan(100));
    });
  });

  group('mutated sheets', () {
    test('a big sheet is baked at 512px frames under its own key', () {
      final sheet = SpriteSheetDef(
        path: 'creatures/rare/HOR01_firehorn_spritesheet.png',
        totalFrames: 4,
        rows: 1,
        frameSize: Vector2(1200, 1200),
        stepTime: 0.09,
      );
      final gold = mutatedSheet(sheet, mutation: 'transmuted');
      expect(gold.path, isNot(sheet.path));
      expect(isMutatedSheetPath(gold.path), isTrue);
      expect(gold.frameSize, Vector2(512, 512));
      expect(gold.totalFrames, 4);
      expect(mutatedSheet(sheet).path, sheet.path);
      // A prismatic Alchemized one is its own bake; a prismatic gold is not.
      expect(
        mutatedSheet(sheet, mutation: 'alchemized', prismatic: true).path,
        isNot(mutatedSheet(sheet, mutation: 'alchemized').path),
      );
      expect(
        mutatedSheet(sheet, mutation: 'transmuted', prismatic: true).path,
        gold.path,
      );
    });

    test('a Transmuted creature carries no tint', () {
      final albino = Creature(
        id: 'X',
        name: 'X',
        types: const ['Fire'],
        rarity: 'Common',
        description: '',
        image: '',
        genetics: Genetics(const {'tinting': 'albino'}),
        isPrismaticSkin: true,
        wildMutation: 'transmuted',
      );
      final v = visualsFromInstance(albino, null);
      expect(v.mutation, 'transmuted');
      expect(v.brightness, 1.0);
      expect(v.saturation, 1.0);
      expect(v.hueShiftDeg, 0.0);
      expect(v.isAlbino, isFalse);
      expect(v.isPrismatic, isFalse);

      // An Alchemized one keeps its pigment: grains take its colours.
      final grains = visualsFromInstance(
        albino.copyWith(wildMutation: 'alchemized'),
        null,
      );
      expect(grains.brightness, isNot(1.0));
      expect(grains.isPrismatic, isTrue);
    });

    // One 16×16 frame: a solid disc of [rgb] on transparency.
    Uint8List disc(int r, int g, int b, {int size = 16}) {
      final out = Uint8List(size * size * 4);
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final dx = x - size / 2 + 0.5, dy = y - size / 2 + 0.5;
          if (dx * dx + dy * dy > (size * 0.4) * (size * 0.4)) continue;
          final o = (y * size + x) * 4;
          out[o] = r;
          out[o + 1] = g;
          out[o + 2] = b;
          out[o + 3] = 255;
        }
      }
      return out;
    }

    MutationBakeJob job(Uint8List rgba, MutationLook look, {int size = 16}) =>
        MutationBakeJob(
          rgba: rgba,
          width: size,
          height: size,
          frameW: size,
          frameH: size,
          cols: 1,
          frames: 1,
          look: look,
        );

    test('gold keeps the silhouette and turns it gold', () {
      final src = disc(40, 90, 200);
      final out = bakeMutation(job(src, MutationLook.transmuted));
      for (var o = 0; o < src.length; o += 4) {
        expect(out[o + 3], src[o + 3]);
        if (src[o + 3] == 255) {
          // Warm: red over green over blue, whatever it was before.
          expect(out[o], greaterThanOrEqualTo(out[o + 1]));
          expect(out[o + 1], greaterThanOrEqualTo(out[o + 2]));
        }
      }
    });

    test('grains stay on the body', () {
      const size = 96;
      final src = disc(200, 80, 40, size: size);
      final out = bakeMutation(job(src, MutationLook.alchemized, size: size));
      var covered = 0, stray = 0;
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final o = (y * size + x) * 4;
          if (out[o + 3] == 0) continue;
          covered++;
          final dx = x - size / 2 + 0.5, dy = y - size / 2 + 0.5;
          // A grain at the edge may spill by its own radius, no further.
          if (sqrt(dx * dx + dy * dy) > size * 0.4 + 6) stray++;
        }
      }
      expect(covered, greaterThan(0));
      expect(stray, 0);
    });

    test('prismatic grains are a rainbow, plain grains keep the colour', () {
      const size = 96;
      final src = disc(200, 80, 40, size: size);
      Set<int> hues(MutationLook look) {
        final out = bakeMutation(job(src, look, size: size));
        final seen = <int>{};
        for (var o = 0; o < out.length; o += 4) {
          if (out[o + 3] < 250) continue;
          final r = out[o], g = out[o + 1], b = out[o + 2];
          // Coarse hue bucket by the dominant channel.
          seen.add(r >= g && r >= b ? 0 : (g >= b ? 1 : 2));
        }
        return seen;
      }

      expect(hues(MutationLook.alchemized), {0});
      expect(hues(MutationLook.alchemizedPrismatic).length, 3);
    });
  });
}
