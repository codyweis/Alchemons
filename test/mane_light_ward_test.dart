import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mane+Light hangs rings rather than throwing anything: outer, then middle,
/// then inner, and every cast after that feeds one of them in that order.
///
/// The mechanic only exists across a sequence of casts, so nothing a
/// single-cast test can see would catch it breaking.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember lightMane() => CosmicPartyMember(
    instanceId: 'ward',
    baseId: 'WRD01',
    displayName: 'Light Mane',
    family: 'Mane',
    element: 'Light',
    level: 10,
    slotIndex: 0,
    statSpeed: 4,
    statIntelligence: 4,
    statStrength: 4,
    statBeauty: 4,
    statSpeedPotential: 80,
    statIntelligencePotential: 80,
    statStrengthPotential: 80,
    statBeautyPotential: 80,
    staminaBars: 3,
    staminaMax: 3,
  );

  /// Boots a game and fires the Light special [casts] times, returning the
  /// rings left turning around the companion.
  Future<List<Projectile>> castWard(int casts) async {
    final game = CosmicSurvivalGame(party: [lightMane()], onGameOver: () {});
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);

    // Let a target exist so the companion is willing to fire.
    for (var i = 0; i < 600 && game.enemies.where((e) => !e.isDead).isEmpty; i++) {
      game.update(1 / 60);
    }

    final comp = game.activeCompanions[0]!;
    final target = game.enemies.firstWhere((e) => !e.isDead);

    // Count rings, not total projectiles — the companion's basic attacks are
    // landing in the same list throughout.
    int ringCount() => game.companionProjectiles
        .where((p) => p.abilityFamily == 'mane' && p.holdOrbit)
        .length;

    for (var i = 0; i < casts; i++) {
      comp.specialCooldown = 0;
      final before = ringCount();
      var fired = false;
      for (var f = 0; f < 900; f++) {
        // A companion only casts with something in range, so hold an
        // unkillable target next to it. Without this the loop silently
        // burns its frames and the cast never happens.
        target
          ..isDead = false
          ..hp = 1e9
          ..position = comp.position + const Offset(70, 0);
        game.update(1 / 60);
        if (comp.specialCooldown > 0) {
          fired = true;
          break;
        }
      }
      expect(fired, isTrue, reason: 'cast ${i + 1} never went off');
      // A cast either hangs exactly one ring or feeds one, never sprays.
      expect(
        ringCount() - before,
        lessThanOrEqualTo(1),
        reason: 'cast ${i + 1} added more than one ring',
      );
    }

    final rings = game.companionProjectiles
        .where((p) => p.abilityFamily == 'mane' && p.holdOrbit)
        .toList();
    rings.sort((a, b) => b.orbitRadius.compareTo(a.orbitRadius));
    return rings;
  }

  test('the first three casts hang three rings, outermost first', () async {
    expect((await castWard(1)).length, 1);
    expect((await castWard(2)).length, 2);

    final three = await castWard(3);
    expect(three.length, 3);
    // Outer, middle, inner — and each turning at its own rate so they never
    // collapse into one rotating spoke.
    expect(
      three.map((r) => r.orbitRadius).toList(),
      kManeLightOrbitRadii,
    );
    expect(
      three.map((r) => r.orbitSpeed).toList(),
      kManeLightOrbitSpeeds,
    );
  });

  test('a fourth ring is never hung', () async {
    for (final casts in [4, 6, 9]) {
      expect((await castWard(casts)).length, 3, reason: '$casts casts');
    }
  });

  test('casts past the third feed the rings outer, middle, inner', () async {
    final afterFourth = await castWard(4);
    // The fourth cast feeds the OUTER ring and nothing else.
    expect(afterFourth[0].effectStacks, 1);
    expect(afterFourth[1].effectStacks, 0);
    expect(afterFourth[2].effectStacks, 0);

    final afterSixth = await castWard(6);
    expect(afterSixth.map((r) => r.effectStacks).toList(), [1, 1, 1]);
  });

  test('a fed ring grows, and the ward tops out where the design says', () async {
    final fresh = (await castWard(3)).first;
    final fed = (await castWard(13)).first;
    expect(fed.visualScale, greaterThan(fresh.visualScale));
    expect(fed.radiusMultiplier, greaterThan(fresh.radiusMultiplier));

    // Half again the size of Earth's opening catapult is the authored ceiling.
    final earth = createCosmicSpecialAbility(
      origin: Offset.zero,
      baseAngle: 0,
      family: 'mane',
      element: 'Earth',
      damage: 40,
      maxHp: 400,
    ).projectiles.first;
    expect(
      kManeLightVisualByLevel.last,
      closeTo(4.0 * 1.5, 0.01),
      reason: "Earth's authored opening visualScale is 4.0",
    );
    expect(kManeLightRadiusByLevel.last, closeTo(4.9 * 1.5, 0.01));
    expect(earth.visualScale, greaterThan(0));
  });

  test('feeding stops at the cap', () async {
    // Well past kManeLightMaxGrowth, nothing keeps climbing.
    final capped = await castWard(3 + kManeLightMaxGrowth + 6);
    final total = capped.fold<int>(0, (sum, r) => sum + r.effectStacks);
    expect(total, lessThanOrEqualTo(kManeLightMaxGrowth));
    for (final ring in capped) {
      expect(
        ring.visualScale,
        lessThanOrEqualTo(kManeLightVisualByLevel.last + 0.001),
      );
    }
  });
}
