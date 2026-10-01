import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:alchemons/games/alchemy/fluid_scene.dart';
import 'package:alchemons/games/alchemy/fluid_scene_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final recipes =
      jsonDecode(
            File(
              'assets/data/alchemons_element_recipes.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  FluidScene make() => FluidScene(recipeJson: recipes);
  test('Empty by default; entire 36,660-cell vessel is usable', () {
    final s = make();
    expect(s.particleCount, 0);
    expect(s.feeding, false);
    for (var y = 0; y < FluidScene.renderH; y++) {
      for (var x = 0; x < FluidScene.renderW; x++) {
        s.put(x, y, FluidMaterial.water);
      }
    }
    expect(s.particleCount, 36660);
    s.pour(.5, .5, amount: 500);
    for (var i = 0; i < 120; i++) {
      s.step(1 / 60);
    }
    expect(s.particleCount, FluidScene.capacity);
    expect(s.cells.where((e) => e != 0).length, FluidScene.capacity);
    s.reset();
    expect(s.particleCount, 0);
    expect(s.feeding, false);
  });
  test('All 41 recipes transform bulk deterministically in both orders', () {
    final s = make();
    var n = 0;
    for (final entry in (recipes['recipes'] as Map<String, dynamic>).entries) {
      final names = entry.key.split('+');
      if (names.length != 2) continue;
      n++;
      final outcomes = (entry.value as Map<String, dynamic>).entries.toList()
        ..sort((a, b) => (b.value as num).compareTo(a.value as num));
      final product = FluidMaterial.named(outcomes.first.key);
      for (final reverse in [false, true]) {
        s.clear();
        s.put(40, 40, FluidMaterial.named(names[reverse ? 1 : 0]));
        s.put(41, 40, FluidMaterial.named(names[reverse ? 0 : 1]));
        s.step(1 / 60);
        expect(s.transformations, 1, reason: entry.key);
        expect(s.cells.where((e) => e != 0).toList(), [
          product.id,
          product.id,
        ], reason: entry.key);
        expect(s.particleCount, 2);
      }
    }
    expect(n, 41);
  });
  test(
    'Water settles, gas rises, anchored crystal stays; stirring moves matter',
    () {
      final s = make();
      s.put(20, 100, FluidMaterial.water);
      s.put(70, 100, FluidMaterial.steam);
      s.put(120, 100, FluidMaterial.crystal);
      for (var i = 0; i < 30; i++) {
        s.step(1 / 60);
      }
      expect(
        s.cells.indexOf(FluidMaterial.water.id) ~/ FluidScene.renderW,
        greaterThan(100),
      );
      expect(
        s.cells.indexOf(FluidMaterial.steam.id) ~/ FluidScene.renderW,
        lessThan(100),
      );
      expect(s.cells[100 * FluidScene.renderW + 120], FluidMaterial.crystal.id);
      s.stir(120 / 160, 100 / 160, .04, -.04);
      s.step(1 / 60);
      expect(s.cells[100 * FluidScene.renderW + 120], 0);
      expect(s.particleCount, 3);
    },
  );
  test('Dense flow conserves water and erase frees local capacity', () {
    final s = make();
    for (var y = 70; y < 237; y++) {
      for (var x = 2; x < 158; x++) {
        s.put(x, y, FluidMaterial.water);
      }
    }
    final total = s.particleCount;
    expect(total, greaterThan(25000));
    for (var i = 0; i < 180; i++) {
      s.stir(.5, 1.2, .02, -.01);
      s.step(1 / 60);
    }
    expect(s.particleCount, total);
    expect(s.cells.where((e) => e != 0).length, total);
    s.erase(.5, 1.2);
    expect(s.particleCount, lessThan(total));
    s.clear();
    s.pour(.5, .4, amount: 72);
    expect(s.particleCount, 72);
    final bytes = s.encode();
    expect(bytes.length, FluidScene.atlasW * FluidScene.renderH * 4);
    for (var i = 3; i < bytes.length; i += 4) {
      if (bytes[i] != 255) fail('Atlas must remain opaque');
    }
  });
  for (final mixed in [false, true]) {
    testWidgets('Dense runtime shader renders, mixed=$mixed', (tester) async {
      tester.view.physicalSize = const Size(480, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = make();
      if (mixed) {
        s.seedBenchmark();
      } else {
        for (var y = 160; y < 237; y++) {
          for (var x = 2; x < 158; x++) {
            s.put(x, y, FluidMaterial.water);
          }
        }
      }
      for (var i = 0; i < 90; i++) {
        s.pour(.5, .5, amount: 24, material: FluidMaterial.fire);
        s.step(1 / 60);
      }
      late ui.FragmentShader shader;
      late ui.Image field;
      await tester.runAsync(() async {
        shader = (await ui.FragmentProgram.fromAsset(
          'assets/shaders/alchemy_fluid.frag',
        )).fragmentShader();
        final c = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          s.encode(),
          FluidScene.atlasW,
          FluidScene.renderH,
          ui.PixelFormat.rgba8888,
          c.complete,
        );
        field = await c.future;
      });
      shader.setImageSampler(0, field);
      final repaint = ValueNotifier(0), key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: CustomPaint(
            painter: FluidScenePainter(shader, () => s.time, repaint),
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('ALCHEMY_CAPTURE')) {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/alchemy-bulk-${mixed ? 'mixed' : 'water'}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      shader.dispose();
      field.dispose();
      repaint.dispose();
    });
  }
}
