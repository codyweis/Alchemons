import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/screens/ability_preview_screen.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Battle tab's live preview: one companion, a ring of practice bodies,
/// the waves held back, the special on a button.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember member(String family, String element) => CosmicPartyMember(
    instanceId: 'preview-test',
    baseId: 'MAN06',
    displayName: 'Preview $family',
    family: family,
    element: element,
    level: 10,
    slotIndex: 0,
    statSpeed: 4,
    statIntelligence: 4,
    statStrength: 4,
    statBeauty: 4,
    statSpeedPotential: 50,
    statIntelligencePotential: 50,
    statStrengthPotential: 50,
    statBeautyPotential: 50,
    staminaBars: 3,
    staminaMax: 3,
  );

  Future<AbilityPreviewGame> load(String family, String element) async {
    final game = AbilityPreviewGame(member: member(family, element));
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    return game;
  }

  test('the companion is out and only practice bodies stand', () async {
    final game = await load('Mane', 'Lava');
    expect(game.activeCompanions[0], isNotNull);
    expect(game.enemies.length, 10);
    for (var i = 0; i < 60 * 8; i++) {
      game.update(1 / 60);
    }
    // Waves keep trying; none of theirs stay. Ten posts plus at most ten
    // runners are ever on the field.
    expect(game.enemies.length, lessThanOrEqualTo(20));
    expect(game.enemies.where((e) => e.speed == 0).length, 10);
    expect(game.enemies.where((e) => e.speed > 0), isNotEmpty);
    expect(game.activeBoss, isNull);
    // Never interrupted, never lost.
    expect(game.showingPowerUpSelection, isFalse);
    expect(game.isGameOver, isFalse);
    expect(game.orb.currentHp, game.orb.maxHp);
    // The ship's gun stays holstered.
    expect(game.shipProjectiles, isEmpty);
  });

  test('the auto attack lands and fallen bodies come back', () async {
    final game = await load('Mane', 'Lava');
    var sawDamage = false;
    var sawDeath = false;
    for (var i = 0; i < 60 * 30; i++) {
      game.update(1 / 60);
      if (game.enemies.any((e) => e.hp < e.maxHp)) sawDamage = true;
      if (game.stats.kills > 0) sawDeath = true;
    }
    expect(sawDamage, isTrue);
    expect(sawDeath, isTrue);
    // After a beat every slot is standing again.
    for (var i = 0; i < 60 * 3; i++) {
      game.update(1 / 60);
    }
    expect(game.enemies.where((e) => !e.isDead).length, greaterThan(6));
  });

  test('the cast button fires the special and the ring refills', () async {
    final game = await load('Mane', 'Lava');
    final comp = game.activeCompanions[0]!;
    comp.specialCooldown = 99;
    game.update(1 / 60);
    expect(game.specialReady, isFalse);
    game.castSpecial();
    var fired = false;
    for (var i = 0; i < 60 * 3; i++) {
      game.update(1 / 60);
      if (game.companionProjectiles.any((p) => p.abilityFamily == 'mane')) {
        fired = true;
      }
    }
    expect(fired, isTrue);
    expect(comp.specialCooldown, greaterThan(0));
    expect(game.specialProgress, inInclusiveRange(0.0, 1.0));
  });

  test('the ship is hidden unless the special involves it', () async {
    final mane = await load('Mane', 'Lava');
    expect(mane.shipInvolved, isFalse);
    expect(mane.renderShip, isFalse);
    final lightKin = await load('Kin', 'Light');
    expect(lightKin.shipInvolved, isTrue);
    expect(lightKin.renderShip, isTrue);
    final poisonKin = await load('Kin', 'Poison');
    expect(poisonKin.renderShip, isFalse);
  });

  test(
    'drag and pinch move the camera and double-tap brings it home',
    () async {
      final game = await load('Mane', 'Lava');
      final home = game.cameraPanOffset;
      game.beginCameraGesture();
      game.cameraGesture(panDelta: const Offset(-60, 0), scale: 1.5);
      game.update(1 / 60);
      expect(game.cameraZoom, closeTo(0.75 * 1.5, 1e-6));
      expect(game.cameraPanOffset.dx, greaterThan(home.dx));
      game.resetView();
      game.update(1 / 60);
      expect(game.cameraZoom, 0.75);
      expect(game.cameraPanOffset, home);
    },
  );

  test('a passive-only special is reported as such', () {
    final s = AbilityPreviewSubject(
      member: member('Kin', 'Fire'),
      autoAttackName: '',
      autoAttackDescription: '',
      autoAttackIcon: const IconData(0),
      specialName: '',
      specialSubtitle: '',
      specialDescription: '',
      specialIcon: const IconData(0),
      accent: const Color(0xFFFFFFFF),
    );
    expect(s.specialIsPassive, isTrue);
  });
}
