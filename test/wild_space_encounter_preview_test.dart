@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic/portal_tear_paint.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/cosmic/wild_space_encounter_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the backdrop a wild Alchemon is met against in space — beside a
/// planet and out in the open — at landscape phone size, so the frame can be
/// judged as a picture.
///
///   WILD_OUT=/tmp flutter test \
///     test/wild_space_encounter_preview_test.dart --tags preview
void main() {
  final outDir = Platform.environment['WILD_OUT'];

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required Creature creature,
    required CosmicEncounterBackdrop backdrop,
    bool exhausted = false,
  }) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: WildSpaceBackdrop(
            creature: creature,
            backdrop: backdrop,
            exhausted: exhausted,
          ),
        ),
      ),
    );
    // Let the sprite sheet decode.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '$outDir/wild_$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('wild space encounter backdrop previews', (tester) async {
    if (outDir == null) return;
    tester.view.physicalSize = const Size(915 * 2, 412 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final catalog = CreatureCatalog();
    await tester.runAsync(catalog.load);
    Creature pick(String element, String family) =>
        catalog.creatures.firstWhere(
          (c) => c.types.contains(element) && c.mutationFamily == family,
        );

    CosmicEncounterBackdrop beside(String element, Offset direction) {
      final planet = CosmicPlanet(
        element: element,
        position: const Offset(4000, 4000),
        radius: 120,
        discovered: true,
      );
      return CosmicEncounterBackdrop(
        image: renderPlanetBackdropImage(planet, elapsed: 3),
        planetColor: planet.color,
        label: planetName(element).toUpperCase(),
        direction: direction,
      );
    }

    await shoot(
      tester,
      name: 'fire_planet',
      creature: pick('Fire', 'Wing'),
      backdrop: beside('Fire', const Offset(0.8, 0.6)),
    );
    await shoot(
      tester,
      name: 'water_planet_exhausted',
      creature: pick('Water', 'Horn'),
      backdrop: beside('Water', const Offset(-0.9, 0.45)),
      exhausted: true,
    );
    await shoot(
      tester,
      name: 'open_space',
      creature: pick('Spirit', 'Pip'),
      backdrop: const CosmicEncounterBackdrop(),
    );
  });

  // ── the transition, as two strips of frames ───────────────────────────

  Future<ui.Image> grab(WidgetTester tester, GlobalKey key) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
  }

  Future<void> writeStrip(
    WidgetTester tester,
    String name,
    List<ui.Image> frames,
  ) async {
    final w = frames.first.width;
    final h = frames.first.height;
    const gap = 12;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, (w + gap) * frames.length - gap + 0.0, h + 0.0),
      Paint()..color = const Color(0xFF888888),
    );
    for (var i = 0; i < frames.length; i++) {
      canvas.drawImage(frames[i], Offset((w + gap) * i + 0.0, 0), Paint());
    }
    final strip = recorder.endRecording().toImageSync(
      (w + gap) * frames.length - gap,
      h,
    );
    await tester.runAsync(() async {
      final bytes = await strip.toByteData(format: ui.ImageByteFormat.png);
      File(
        '$outDir/wild_$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('portal tear transition strips', (tester) async {
    if (outDir == null) return;
    final catalog = CreatureCatalog();
    await tester.runAsync(catalog.load);
    final creature = catalog.creatures.firstWhere(
      (c) => c.types.contains('Fire') && c.mutationFamily == 'Wing',
    );
    final planet = CosmicPlanet(
      element: 'Fire',
      position: const Offset(4000, 4000),
      radius: 120,
      discovered: true,
    );
    final backdrop = CosmicEncounterBackdrop(
      image: renderPlanetBackdropImage(planet, elapsed: 3),
      planetColor: planet.color,
      label: 'FIRE PLANET',
      direction: const Offset(0.8, 0.6),
    );
    final color = elementColor('Fire');

    // In space: portrait. The space view is stood in for by the backdrop
    // itself; the tear is the real painter.
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    final spaceFrames = <ui.Image>[];
    for (final q in const [0.15, 0.35, 0.55, 0.75, 0.92]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Stand-in for the space view: the backdrop's planet and
                // stars, with the tear drawn behind the creature and over
                // the whole frame, as the game layers them.
                WildSpaceBackdrop(
                  creature: creature,
                  backdrop: backdrop,
                  behindSpecimen: (canvas, size) => paintSpaceTearBehind(
                    canvas,
                    screen: size,
                    centre: size.center(Offset.zero),
                    q: q,
                    color: color,
                    clock: q * 1.3,
                  ),
                ),
                CustomPaint(
                  painter: _TearFrame(
                    (canvas, size) => paintSpaceTearOver(
                      canvas,
                      screen: size,
                      centre: size.center(Offset.zero),
                      q: q,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      spaceFrames.add(await grab(tester, key));
    }
    await writeStrip(tester, 'tear_space', spaceFrames);

    // The encounter: landscape, on its arrival timeline.
    tester.view.physicalSize = const Size(915, 412);
    final arrivalFrames = <ui.Image>[];
    for (final p in const [0.22, 0.32, 0.42, 0.55, 0.75, 1.0]) {
      final key = GlobalKey();
      final entrance = AnimationController(
        vsync: const TestVSync(),
        value: ((p - 0.25) / 0.75).clamp(0.0, 1.0),
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: Stack(
              fit: StackFit.expand,
              children: [
                WildSpaceBackdrop(
                  creature: creature,
                  backdrop: backdrop,
                  entrance: entrance,
                ),
                CustomPaint(
                  painter: _TearFrame(
                    (canvas, size) => paintTearReveal(
                      canvas,
                      size,
                      progress: p,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      arrivalFrames.add(await grab(tester, key));
      entrance.dispose();
    }
    await writeStrip(tester, 'tear_arrival', arrivalFrames);

    // The fusion, on the two creatures standing there.
    final ally = catalog.creatures.firstWhere(
      (c) => c.types.contains('Lightning') && c.mutationFamily == 'Let',
    );
    final mergeFrames = <ui.Image>[];
    for (final t in const [0.0, 0.3, 0.6, 0.8, 0.95]) {
      final key = GlobalKey();
      final merge = AnimationController(vsync: const TestVSync(), value: t);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: WildSpaceBackdrop(
              creature: creature,
              backdrop: backdrop,
              partyCreature: ally,
              merge: merge,
              mergeColors: (elementColor('Lightning'), color),
            ),
          ),
        ),
      );
      mergeFrames.add(await grab(tester, key));
      merge.dispose();
    }
    await writeStrip(tester, 'fusion_merge', mergeFrames);

    // Failures: a fusion that would not hold, then a harvest broken out of.
    final failFrames = <ui.Image>[];
    for (final (r, b) in const [
      (0.25, 0.0),
      (0.55, 0.0),
      (0.0, 0.2),
      (0.0, 0.45),
      (0.0, 0.75),
    ]) {
      final key = GlobalKey();
      final reject = AnimationController(vsync: const TestVSync(), value: r);
      final breakFree = AnimationController(vsync: const TestVSync(), value: b);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: WildSpaceBackdrop(
              creature: creature,
              backdrop: backdrop,
              partyCreature: ally,
              mergeColors: (elementColor('Lightning'), color),
              reject: reject,
              breakFree: breakFree,
            ),
          ),
        ),
      );
      failFrames.add(await grab(tester, key));
      reject.dispose();
      breakFree.dispose();
    }
    await writeStrip(tester, 'failures', failFrames);

    // A companion stepping out of its summon tear.
    final summonFrames = <ui.Image>[];
    for (final t in const [0.12, 0.3, 0.5, 0.75, 0.92]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: WildSpaceBackdrop(
              creature: creature,
              backdrop: const CosmicEncounterBackdrop(),
              entrance: AlwaysStoppedAnimation(
                0.15 + 0.55 * ((t - 0.18) / 0.55).clamp(0.0, 1.0),
              ),
              behindSpecimen: (canvas, size) => paintSummonTear(
                canvas,
                centre: size.center(Offset.zero),
                height: 230,
                t: t,
                color: color,
              ),
            ),
          ),
        ),
      );
      summonFrames.add(await grab(tester, key));
    }
    await writeStrip(tester, 'summon', summonFrames);
    addTearDown(tester.view.reset);
  });
}

class _TearFrame extends CustomPainter {
  _TearFrame(this.draw);

  final void Function(Canvas canvas, Size size) draw;

  @override
  void paint(Canvas canvas, Size size) => draw(canvas, size);

  @override
  bool shouldRepaint(_TearFrame old) => true;
}
