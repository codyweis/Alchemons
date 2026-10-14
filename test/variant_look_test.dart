import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:alchemons/games/shared/creature_looks.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:alchemons/widgets/fx/variant_look.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

void main() {
  SpriteSheetDef sheetOf(String path) => SpriteSheetDef(
    path: path,
    totalFrames: 4,
    rows: 1,
    frameSize: Vector2.all(512),
    stepTime: 0.2,
  );
  final firelet = sheetOf('creatures/common/LET01_firelet_spritesheet.png');
  final kin = sheetOf('creatures/rare/KIN02_waterkin_spritesheet.png');

  group('which variants are a palette swap', () {
    test('the polished families, in a faction with a palette', () {
      expect(variantSwap(speciesId: 'LET01', faction: 'Oceanic'), 'Oceanic');
      expect(variantSwap(speciesId: 'WNG07', faction: 'earthen'), 'Earthen');
      expect(variantSwap(speciesId: 'KIN02', faction: 'Oceanic'), isNull);
      expect(variantSwap(speciesId: 'LET01', faction: 'Bloodborn'), isNull);
      expect(variantSwap(speciesId: 'LET01', faction: null), isNull);
    });

    test('never an albino or a mutated one', () {
      expect(
        variantSwap(speciesId: 'LET01', faction: 'Oceanic', albino: true),
        isNull,
      );
      expect(
        variantSwap(
          speciesId: 'LET01',
          faction: 'Oceanic',
          mutation: 'alchemized',
        ),
        isNull,
      );
    });

    test('a swapped variant draws its baked sheet, no tint over it', () {
      expect(
        mutatedSheet(firelet, variant: 'Oceanic').path,
        endsWith('#mut:variant-oceanic'),
      );
      expect(mutatedSheet(kin, variant: 'Oceanic').path, kin.path);
      // An albino has no pigment to turn.
      expect(
        mutatedSheet(firelet, variant: 'Oceanic', albino: true).path,
        endsWith('#mut:albino'),
      );

      const tint = Color(0xFF7CB3FF);
      const variant = SpriteVisuals(
        speciesId: 'LET01',
        variantFaction: 'Oceanic',
        tint: tint,
        hueShiftDeg: 15,
      );
      expect(sheetForVisuals(firelet, variant)!.path, contains('variant'));
      expect(variantBaked(variant), isTrue);
      expect(
        creatureGeneticsFilter(variant, 0),
        creatureGeneticsFilter(
          const SpriteVisuals(
            speciesId: 'LET01',
            variantFaction: 'Oceanic',
            hueShiftDeg: 15,
          ),
          0,
        ),
      );
      // Not knowing its species, it keeps the tint, on its own sheet.
      const unknown = SpriteVisuals(variantFaction: 'Oceanic', tint: tint);
      expect(sheetForVisuals(firelet, unknown)!.path, firelet.path);
      expect(
        creatureGeneticsFilter(unknown, 0),
        isNot(creatureGeneticsFilter(const SpriteVisuals(), 0)),
      );
    });
  });

  group('the palette swap', () {
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

    Uint8List bake(Uint8List src, MutationLook look, {Uint8List? eyes}) =>
        bakeMutation(
          MutationBakeJob(
            rgba: src,
            width: size,
            height: size,
            frameW: size,
            frameH: size,
            cols: 1,
            frames: 1,
            look: look,
            eyes: eyes,
          ),
        );

    const mid = (size ~/ 2 * size + size ~/ 2) * 4;
    double lum(Uint8List p, int o) =>
        0.2126 * p[o] + 0.7152 * p[o + 1] + 0.0722 * p[o + 2];
    double chroma(Uint8List p, int o) =>
        [p[o], p[o + 1], p[o + 2]].reduce(math.max) -
        [p[o], p[o + 1], p[o + 2]].reduce(math.min).toDouble();

    test('a red body turns blue, as light as it was, its shape kept', () {
      final src = disc(230, 70, 60);
      final out = bake(src, MutationLook.variantOceanic);
      expect(out[mid + 2], greaterThan(out[mid] + 60));
      expect((lum(out, mid) - lum(src, mid)).abs(), lessThan(40));
      for (var i = 3; i < src.length; i += 4) {
        expect(out[i], src[i]);
      }
    });

    test('Earthen is muted beside Volcanic', () {
      final src = disc(60, 120, 230);
      final earthen = bake(src, MutationLook.variantEarthen);
      final volcanic = bake(src, MutationLook.variantVolcanic);
      expect(chroma(earthen, mid), lessThan(chroma(volcanic, mid) * 0.75));
    });

    test('its eyes keep their own color', () {
      final src = disc(230, 70, 60);
      final eyes = Uint8List(src.length)..[mid + 3] = 255;
      final out = bake(src, MutationLook.variantOceanic, eyes: eyes);
      expect(out.sublist(mid, mid + 3), [230, 70, 60]);
      expect(out[mid + 4 + 2], greaterThan(out[mid + 4]));
    });
  });
}
