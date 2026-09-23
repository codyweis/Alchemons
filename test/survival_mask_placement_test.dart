import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/survival_mask_placement.dart';
import 'package:flutter_test/flutter_test.dart';

List<Projectile> cast(
  String element, {
  double beauty = 4,
  double intelligence = 4,
}) => createCosmicSpecialAbility(
  origin: Offset.zero,
  baseAngle: 0,
  family: 'mask',
  element: element,
  damage: 40,
  maxHp: 100,
  casterPower: intelligence,
  casterBeauty: beauty,
  casterIntelligence: intelligence,
  targetPos: const Offset(1000, 0),
).projectiles;

void place(
  List<Projectile> traps, {
  Offset ship = Offset.zero,
  List<Offset> allies = const [Offset.zero, Offset(60, 0)],
  Offset target = const Offset(600, 0),
}) => placeSurvivalMaskTraps(
  traps: traps,
  caster: const Offset(60, 0),
  ship: ship,
  allies: allies,
  target: target,
  arenaCenter: Offset.zero,
  arenaRadius: 1140,
);

void main() {
  test('Earth covers separated injured allies before adding spare pools', () {
    final traps = cast('Earth', beauty: 12);
    const wounded = Offset(-350, 100);
    const healthy = Offset(250, 0);
    place(traps, allies: [wounded, Offset.zero, healthy]);
    expect(traps.first.position, wounded);
    for (final ally in [wounded, Offset.zero, healthy]) {
      expect(
        traps.any((p) => (p.position - ally).distance <= p.effectRadius),
        isTrue,
      );
    }
    expect(
      traps.every((p) => (p.position - const Offset(600, 0)).distance > 200),
      isTrue,
    );
  });

  test('Ice finds shared coverage instead of targeting the distant enemy', () {
    final traps = cast('Ice');
    const ship = Offset(-140, 0), ally = Offset(140, 0);
    place(traps, ship: ship, allies: [ship, ally]);
    final pillar = traps.single;
    expect(
      (pillar.position - ship).distance,
      lessThanOrEqualTo(pillar.effectRadius),
    );
    expect(
      (pillar.position - ally).distance,
      lessThanOrEqualTo(pillar.effectRadius),
    );
  });

  test(
    'Spirit creates an accessible collection ring rather than enemy-centered scatter',
    () {
      final traps = cast('Spirit', beauty: 12);
      place(traps);
      for (final p in traps) {
        expect(p.position.distance, inInclusiveRange(56, 200));
      }
      expect(traps.map((p) => p.position).toSet().length, traps.length);
    },
  );

  for (final element in kCosmicAbilityElements.where((e) => e != 'Dust')) {
    test(
      '$element high-stat placement stays inside arena at an edge target',
      () {
        final traps = cast(element, beauty: 30, intelligence: 30);
        final count = traps.length;
        final stats = traps
            .map((p) => (p.damage, p.life, p.effectRadius, p.effectPower))
            .toList();
        place(
          traps,
          ship: const Offset(1080, 0),
          allies: [const Offset(1080, 0), const Offset(950, 80)],
          target: const Offset(1700, 200),
        );
        expect(traps.length, count);
        for (var i = 0; i < traps.length; i++) {
          final p = traps[i];
          final footprint = max(
            max(p.effectRadius, p.snareRadius),
            Projectile.radius * p.radiusMultiplier,
          );
          expect(p.position.distance + footprint, lessThanOrEqualTo(1140.0001));
          expect((p.damage, p.life, p.effectRadius, p.effectPower), stats[i]);
        }
      },
    );
  }

  test(
    'higher count increases density without flinging offensive traps farther away',
    () {
      final low = cast('Fire', beauty: 1), high = cast('Fire', beauty: 12);
      place(low);
      place(high);
      expect(high.length, greaterThan(low.length));
      expect(high.first.position, const Offset(600, 0));
      expect(low.first.position, const Offset(600, 0));
      for (final p in [...low, ...high]) {
        expect((p.position - const Offset(600, 0)).distance, lessThan(260));
      }
      expect(high.map((p) => p.position).toSet().length, high.length);
      expect(
        high.skip(1).where((p) => p.position.dx < 600).length,
        greaterThan(high.length ~/ 2),
      );
    },
  );

  test('Dust attachment seeds and other ability families remain unchanged', () {
    final dust = cast('Dust');
    final before = dust.single.position;
    place(dust);
    expect(dust.single.position, before);
    final nonMask = Projectile(
      position: const Offset(2000, 0),
      angle: 0,
      abilityFamily: 'mane',
    );
    place([nonMask]);
    expect(nonMask.position, const Offset(2000, 0));
  });
}
