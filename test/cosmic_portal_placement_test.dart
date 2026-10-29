import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:flutter_test/flutter_test.dart';

Offset _survivalPortal(CosmicWorld world) => SpacePOI.generate(
  seed: world.seed ^ 0xBB22,
  worldSize: world.worldSize,
  planets: world.planets,
).firstWhere((p) => p.type == POIType.survivalPortal).position;

void main() {
  test('each world puts its survival portal somewhere of its own', () {
    final a = CosmicWorld.generate(seed: 1);
    final b = CosmicWorld.generate(seed: 2);
    expect(_survivalPortal(a), isNot(_survivalPortal(b)));
    expect(_survivalPortal(a), _survivalPortal(CosmicWorld.generate(seed: 1)));
  });

  test('a moved rift stays moved after the world is rebuilt', () {
    final world = CosmicWorld.generate(seed: 42);
    final rift = world.riftPortals.first;
    rift.position = const Offset(5000, 6000);
    final saved = RiftPortal.serialiseAll(world);

    final rebuilt = CosmicWorld.generate(seed: 42);
    RiftPortal.restoreAll(rebuilt, saved);
    expect(rebuilt.riftPortals.first.position, const Offset(5000, 6000));
    // The caches still lay out round where the world first put it.
    expect(rebuilt.riftPortals.first.origin, isNot(const Offset(5000, 6000)));

    final other = CosmicWorld.generate(seed: 43);
    final before = other.riftPortals.first.position;
    RiftPortal.restoreAll(other, saved);
    expect(other.riftPortals.first.position, before);
  });
}
