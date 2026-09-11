import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ambient particle pool is a single shared resource that every effect in
/// the game competes for — hit sparks, kill bursts, zone wisps, meteor craters.
/// Nothing arbitrates that competition; each caller just tests the pool against
/// its own hard-coded ceiling, so whoever runs first with the highest ceiling
/// wins and starves the rest.
///
/// The Mane trail was the worst offender: it emitted per PROJECTILE per FRAME,
/// and Mane casts spawn up to sixteen of them, so one cast could claim the
/// whole pool in a few frames and hold it for the projectiles' lifetime.
///
/// These tests pin the thing that actually matters — what fraction of the pool
/// one cast may hold — rather than any particular emission rate, so the trail
/// can be retuned freely without silently reintroducing the monopoly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember member(String family, String element, int slot) =>
      CosmicPartyMember(
        instanceId: 'budget_$slot',
        baseId: 'BUD0$slot',
        displayName: '$family $element',
        family: family,
        element: element,
        level: 10,
        slotIndex: slot,
        statSpeed: 4.0,
        statIntelligence: 4.0,
        statStrength: 4.0,
        statBeauty: 4.0,
        statSpeedPotential: 80,
        statIntelligencePotential: 80,
        statStrengthPotential: 80,
        statBeautyPotential: 80,
        staminaBars: 3,
        staminaMax: 3,
      );

  Future<CosmicSurvivalGame> boot() async {
    final game = CosmicSurvivalGame(
      party: [member('Mane', 'Dust', 0)],
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);
    return game;
  }

  /// Fires one real Mane cast into the field and runs it to exhaustion,
  /// reporting the high-water mark of the shared particle pool.
  Future<({int peak, int projectiles})> runOneCast(String element) async {
    final game = await boot();
    final result = createCosmicSpecialAbility(
      origin: game.orb.position,
      baseAngle: 0.4,
      family: 'mane',
      element: element,
      damage: 40,
      maxHp: 400,
      casterBeauty: 5.0,
      casterIntelligence: 5.0,
      targetPos: game.orb.position + const Offset(260, 90),
    );
    for (final p in result.projectiles) {
      p.sourceSlotIndex = 0;
    }
    game.companionProjectiles.addAll(result.projectiles);
    final projectiles = result.projectiles.length;

    var peak = 0;
    for (var frame = 0; frame < 150; frame++) {
      game.update(1 / 60);
      if (game.vfxParticleCount > peak) peak = game.vfxParticleCount;
    }
    return (peak: peak, projectiles: projectiles);
  }

  test('a single Mane cast cannot monopolise the ambient particle pool', () async {
    // Dust was the widest fan in the family (9-16 lanes) when this test was
    // written, which made it the worst case for a per-projectile emitter. The
    // family has since been consolidated to single heavy shots, so the worst
    // case now is simply "a cast is in flight" — which is the right thing to
    // measure anyway, and the narrow-fan test below is what really pins it.
    final dust = await runOneCast('Dust');
    // ignore: avoid_print
    print(
      'mane Dust: ${dust.projectiles} projectiles, peak particles ${dust.peak}',
    );
    expect(
      dust.peak,
      lessThanOrEqualTo(kManeTrailParticleBudget),
      reason:
          'One cast held ${dust.peak} particles. The trail must stay inside '
          'its own budget so hit sparks, kill bursts and meteor craters can '
          'still get particles while a Mane cast is in flight.',
    );
  });

  test('even the narrowest Mane cast leaves the pool free', () async {
    // Before the fix, Blood at three projectiles and Dust at nine BOTH pinned
    // the pool at its ceiling (137 and 136) — the trail had no budget, only a
    // race against a hard-coded gate, so projectile count was never the
    // variable that mattered. Pinning a narrow cast is what stops a future
    // "just clamp the wide ones" fix from passing.
    final blood = await runOneCast('Blood');
    // ignore: avoid_print
    print('mane Blood: ${blood.projectiles} proj / peak ${blood.peak}');
    expect(
      blood.peak,
      lessThanOrEqualTo(kManeTrailParticleBudget),
      reason:
          'A three-projectile Mane cast held ${blood.peak} ambient particles.',
    );
  });
}
