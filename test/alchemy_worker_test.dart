import 'dart:convert';
import 'dart:io';
import 'package:alchemons/games/alchemy/fluid_worker.dart';
import 'package:alchemons/games/alchemy/fluid_scene.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final recipes =
      jsonDecode(
            File(
              'assets/data/alchemons_element_recipes.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 200 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(
      condition(),
      true,
      reason: 'Worker did not publish the requested state',
    );
  }

  test(
    'Worker batches input, publishes textures and clears paused state',
    () async {
      var frames = 0;
      final worker = FluidWorker(onFrame: () => frames++);
      addTearDown(worker.dispose);
      await worker.start(recipes);
      await worker.start(recipes);
      expect(worker.pixels!.length, FluidScene.atlasW * FluidScene.renderH * 4);
      worker.clear();
      await until(() => worker.particleCount == 0);
      worker.pour(.5, .7, amount: 8, material: FluidMaterial.earth);
      worker.pour(.5, .7, amount: 8, material: FluidMaterial.water);
      worker.step(1 / 60);
      await until(() => worker.transformations > 0);
      expect(worker.lastReaction, 'Earth + Water → Mud');
      expect(worker.particleCount, 16);
      worker.pause();
      worker.clear();
      await until(() => worker.particleCount == 0);
      expect(worker.feeding, false);
      expect(frames, greaterThan(2));
    },
  );
  test(
    'Disposal during startup closes the worker without late callbacks',
    () async {
      var frames = 0;
      final worker = FluidWorker(onFrame: () => frames++);
      final startup = worker.start(recipes);
      worker.dispose();
      await startup;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(frames, 0);
    },
  );
}
