// Every dungeon must look like its own planet.
//
// The sky shader fails SOFT by design: no config, or an asset that will not
// load, and DungeonSky quietly draws a plain gradient instead. That is the
// right behaviour at runtime and a terrible one in development — eleven
// dungeons shipped with no elemental background at all and nothing anywhere
// said so, because a gradient is not an error. It surfaced only when a human
// looked at Lightning, then looked at the new ones.
//
// So the coverage is asserted here instead: a planet with a dungeon has a
// palette, a built shader on disk, and that shader registered for bundling.
// Miss any one of the three and the planet silently loses its identity.

import 'dart:io';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_sky.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  group('every built dungeon has its own sky', () {
    test('a palette is configured', () {
      for (final element in kPlanetDungeonLayouts.keys) {
        expect(
          kDungeonSkyConfigs.containsKey(element),
          isTrue,
          reason: '$element has a dungeon but no DungeonSkyConfig, so it '
              'falls back to the flat gradient and looks like nowhere',
        );
      }
    });

    test('the built shader exists on disk', () {
      for (final element in kPlanetDungeonLayouts.keys) {
        final path =
            'assets/shaders/dungeon/built/${element.toLowerCase()}.frag';
        expect(
          File(path).existsSync(),
          isTrue,
          reason: '$path is missing — run '
              '`dart run tool/build_dungeon_shaders.dart`',
        );
      }
    });

    test('the shader is registered for bundling', () {
      // Present on disk but absent from pubspec means it is not shipped, and
      // FragmentProgram.fromAsset throws into the silent gradient fallback.
      for (final element in kPlanetDungeonLayouts.keys) {
        final path =
            'assets/shaders/dungeon/built/${element.toLowerCase()}.frag';
        expect(
          pubspec.contains(path),
          isTrue,
          reason: '$path is built but not listed under `shaders:` in '
              'pubspec.yaml, so it will not load on device',
        );
      }
    });

    test('a built shader has a source it was assembled from', () {
      // Guards the other direction: a hand-edited built/ file would be
      // silently overwritten the next time the builder runs.
      for (final element in kPlanetDungeonLayouts.keys) {
        final src =
            'assets/shaders/dungeon/elements/${element.toLowerCase()}.src.frag';
        expect(
          File(src).existsSync(),
          isTrue,
          reason: '$src is missing — built/ is generated, never hand-edited',
        );
      }
    });
  });

  group('the palettes are actually different planets', () {
    test('no two planets share a palette', () {
      // A copy-pasted config is the easy way to "add" a sky and end up with
      // two planets that look identical — which §5.5's visual grammar rule
      // exists to prevent.
      final seen = <String, String>{};
      kDungeonSkyConfigs.forEach((element, cfg) {
        final key = '${cfg.colorA.toARGB32()}/'
            '${cfg.colorB.toARGB32()}/'
            '${cfg.colorC.toARGB32()}';
        expect(
          seen.containsKey(key),
          isFalse,
          reason: '$element and ${seen[key]} have identical palettes',
        );
        seen[key] = element;
      });
    });

    test('each shader body is distinct, not a recoloured copy', () {
      final bodies = <String, String>{};
      for (final element in kPlanetDungeonLayouts.keys) {
        final f = File(
          'assets/shaders/dungeon/elements/${element.toLowerCase()}.src.frag',
        );
        if (!f.existsSync()) continue;
        // Compare the code with comments and whitespace stripped, so two
        // planets cannot differ only by their header comment.
        final body = f
            .readAsLinesSync()
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && !l.startsWith('//'))
            .join();
        expect(
          bodies.containsKey(body),
          isFalse,
          reason: '$element and ${bodies[body]} are the same shader',
        );
        bodies[body] = element;
      }
    });
  });
}
