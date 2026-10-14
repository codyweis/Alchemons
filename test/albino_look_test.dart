import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/shared/creature_looks.dart';
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/pureblood_rite_service.dart';
import 'package:alchemons/services/wildlife_generator.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/fx/albino_look.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:drift/native.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sheet = SpriteSheetDef(
    path: 'creatures/common/LET01_firelet_spritesheet.png',
    totalFrames: 4,
    rows: 1,
    frameSize: Vector2.all(512),
    stepTime: 0.2,
  );

  group('which sheet an albino is drawn from', () {
    test('its own baked copy, with its eyes', () {
      final albino = mutatedSheet(sheet, albino: true);
      expect(albino.path, isNot(sheet.path));
      expect(isMutatedSheetPath(albino.path), isTrue);
      expect(albinoEyesPath(sheet.path), contains('_albino_eyes.png'));
    });

    test('a prismatic or mutated albino is not baked albino', () {
      expect(
        mutatedSheet(sheet, albino: true, prismatic: true).path,
        sheet.path,
      );
      expect(
        mutatedSheet(sheet, albino: true, mutation: 'alchemized').path,
        mutatedSheet(sheet, mutation: 'alchemized').path,
      );
    });

    test('a baked sheet passed back in is itself', () {
      final albino = mutatedSheet(sheet, albino: true);
      expect(mutatedSheet(albino, albino: true).path, albino.path);
      expect(
        sheetForVisuals(albino, const SpriteVisuals(brightness: 1.45))!.path,
        albino.path,
      );
    });

    test('sheetForVisuals and the filter agree', () {
      const albino = SpriteVisuals(brightness: 1.45, saturation: 0);
      expect(sheetForVisuals(sheet, albino)!.path, contains('albino'));
      // Its sheet carries the look: no filter over it.
      expect(creatureGeneticsFilter(albino, 0), isNull);
      // A mutated albino's sheet carries the mutation: filtered albino.
      const grains = SpriteVisuals(
        brightness: 1.45,
        saturation: 0,
        mutation: 'alchemized',
      );
      expect(sheetForVisuals(sheet, grains)!.path, isNot(contains('albino')));
      expect(creatureGeneticsFilter(grains, 0), kAlbinoFilter);
      // A prismatic one is no albino at all.
      const prismatic = SpriteVisuals(brightness: 1.45, isPrismatic: true);
      expect(sheetForVisuals(sheet, prismatic)!.path, sheet.path);
      expect(creatureGeneticsFilter(prismatic, 0), isNotNull);
    });
  });

  group('the albino bake', () {
    const size = 16;
    Uint8List disc(int r, int g, int b) {
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

    MutationBakeJob job(Uint8List rgba, {Uint8List? eyes}) => MutationBakeJob(
      rgba: rgba,
      width: size,
      height: size,
      frameW: size,
      frameH: size,
      cols: 1,
      frames: 1,
      look: MutationLook.albino,
      eyes: eyes,
    );

    double lum(Uint8List p, int o) =>
        (0.299 * p[o] + 0.587 * p[o + 1] + 0.114 * p[o + 2]) / 255;

    test('a dark creature comes out pale and warm, its shape kept', () {
      final src = disc(30, 26, 52);
      final out = bakeMutation(job(src));
      final o = (size ~/ 2 * size + size ~/ 2) * 4;
      expect(out[o + 3], 255);
      expect(lum(out, o), greaterThan(0.6));
      // Ivory, not grey: warmer than it is blue, whatever it was before.
      expect(out[o], greaterThan(out[o + 2]));
      for (var i = 3; i < src.length; i += 4) {
        expect(out[i], src[i]);
      }
    });

    test('its eyes are laid over where the overlay has them', () {
      final src = disc(200, 200, 200);
      final eyes = Uint8List(src.length);
      final o = (size ~/ 2 * size + size ~/ 2) * 4;
      eyes
        ..[o] = 200
        ..[o + 1] = 30
        ..[o + 2] = 40
        ..[o + 3] = 255;
      final out = bakeMutation(job(src, eyes: eyes));
      expect(out[o], 200);
      expect(out[o + 1], 30);
      final off = o + 8;
      expect(out[off + 1], greaterThan(150));
    });
  });

  group('the eye overlays', () {
    final creatures =
        (jsonDecode(
                  File(
                    'assets/data/alchemons_creatures.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>)['creatures']
            as List;

    test('every species listed has one, at its baked size', () async {
      for (final e in creatures.cast<Map<String, dynamic>>()) {
        final id = e['id'] as String;
        if (!kAlbinoEyeSpecies.contains(id)) continue;
        final sd = e['spriteData'] as Map<String, dynamic>;
        final path = albinoEyesPath(
          (e['image'] as String).replaceAll('.png', '_spritesheet.png'),
        )!;
        final file = File('assets/images/$path');
        expect(file.existsSync(), isTrue, reason: id);
        final (fw, fh) = bakedFrameSize(
          (sd['frameWidth'] as num).toDouble(),
          (sd['frameHeight'] as num).toDouble(),
        );
        final frames = (sd['totalFrames'] as num).toInt();
        final rows = (sd['rows'] as num?)?.toInt() ?? 1;
        final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
        final image = (await codec.getNextFrame()).image;
        expect(image.width, fw * ((frames + rows - 1) ~/ rows), reason: id);
        expect(image.height, fh * rows, reason: id);
        image.dispose();
        codec.dispose();
      }
    });

    test('no species has one it is not listed for', () {
      final stray = Directory('assets/images/creatures')
          .listSync(recursive: true)
          .map((f) => f.path.split('/').last)
          .where((n) => n.endsWith('_albino_eyes.png'))
          .map((n) => n.substring(0, 5))
          .where((id) => !kAlbinoEyeSpecies.contains(id));
      expect(stray, isEmpty);
    });

    test('Darklet keeps the frame size its ring knows it by', () {
      expect(bakedFrameSize(724, 724), (724, 724));
      expect(bakedFrameSize(1200, 1200), (512, 512));
    });
  });

  group('how rare an albino is', () {
    late CreatureCatalog repository;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
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
    });

    test('about 1 in 100 wild', () {
      final wild = WildlifeGenerator(repository, rng: Random(7));
      const n = 20000;
      var albino = 0;
      for (var i = 0; i < n; i++) {
        final c = wild.generate(i.isEven ? 'LET15' : 'HOR05')!;
        if (c.genetics?.get('tinting') == 'albino') albino++;
      }
      expect(albino / n, inInclusiveRange(0.006, 0.014));
    });

    test('rare bred, but two albinos mostly breed true', () {
      final engine = BreedingEngine(
        repository,
        elementRecipes: ElementRecipeConfig(recipes: const {}),
        familyRecipes: const FamilyRecipeConfig(recipes: {}),
      );
      Creature tinted(String tint) => repository
          .getCreatureById('LET15')!
          .copyWith(genetics: Genetics({'tinting': tint, 'size': 'normal'}));
      double albinoPct(String a, String b) =>
          engine
              .getTintDistribution(tinted(a), tinted(b))
              .asPercentages()['albino'] ??
          0;
      // Two parents of one tint mostly pass on their own.
      expect(albinoPct('normal', 'normal'), inInclusiveRange(0.15, 0.5));
      expect(albinoPct('warm', 'cool'), inInclusiveRange(0.6, 1.4));
      expect(albinoPct('albino', 'normal'), inInclusiveRange(0.6, 1.4));
      expect(albinoPct('albino', 'albino'), greaterThan(50));
    });

    test('the Pureblood Rite never asks for one', () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final rite = PurebloodRiteService(db, repository);
      for (final c in rite.challengeLadder) {
        expect(c.requiredTint, isNot('albino'), reason: c.displayTitle);
      }
      expect(rite.weeklyChallenge().requiredTint, isNot('albino'));
    });
  });
}
