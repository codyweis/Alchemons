// A HEAL DURING THE COMBAT TICK STAYS HEALED.
//
// Each dungeon frame copies the creature's health into its combat body,
// runs the combat tick, then copies the combat body's health back. Heals
// inside the tick (`_healCreature`) write the creature, so until 2026-10-07
// the copy back erased every one of them the frame it landed: a Kin's
// blessing regen, kill heals, drain heals, zone heals. Only a button press
// (outside the tick) and Wing Water's beam (it writes the combat body)
// survived. The copy back now carries only what the tick changed.
//
// And a Kin's heals reach the party: survival's ship and orb shares, which
// the dungeon dropped or shrank to nothing, land on each ally.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member({
  int slot = 0,
  String element = 'Air',
  String family = 'wing',
}) => CosmicPartyMember(
  instanceId: 'inst_$slot',
  baseId: 'base_$slot',
  displayName: '$element $family',
  element: element,
  family: family,
  level: 10,
  statSpeed: 3,
  statIntelligence: 3,
  statStrength: 3,
  statBeauty: 3,
  slotIndex: slot,
  staminaBars: 3,
  staminaMax: 3,
);

PlanetDungeonGame _game([List<CosmicPartyMember>? party]) {
  final members = party ?? [_member()];
  final g = PlanetDungeonGame(
    element: 'Air',
    party: members,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = g.layout.entranceRoomId;
  final at = g.layout.entranceSpawn;
  for (var i = 0; i < members.length; i++) {
    final p = at + Offset(i * 40.0, 0);
    g.creatures.add(
      DungeonCreature(member: members[i])
        ..position = p
        ..lastSafe = p,
    );
    g.combatCompanions.add(g.debugCreateCombatCompanion(members[i], p));
  }
  return g;
}

/// A Water Kin (active) and an Air Wing, both at half health, the Kin's
/// special cast once.
PlanetDungeonGame _kinCast() {
  final g = _game([
    _member(slot: 0, element: 'Water', family: 'kin'),
    _member(slot: 1),
  ]);
  for (final c in g.creatures) {
    c.hp = c.maxHp / 2;
  }
  g.combatCompanions.first.specialCooldown = 0;
  expect(g.activateCombatAbility(), isTrue);
  return g;
}

/// Health a 40/s blessing restores over two seconds at [fps], in combat
/// units, starting from half health.
double _blessingGain(int fps) {
  final g = _game();
  final c = g.creatures.single;
  final comp = g.combatCompanions.single;
  c.hp = c.maxHp / 2;
  comp
    ..blessingTimer = 5
    ..blessingHealPerTick = 40;
  final before = comp.maxHp * c.hpFraction;
  for (var i = 0; i < 2 * fps; i++) {
    g.update(1 / fps);
  }
  return comp.maxHp * c.hpFraction - before;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a blessing heals across the combat tick', () {
    expect(_blessingGain(60), closeTo(80, 2));
  });

  test('the blessing heals the same at 60 and 120 fps', () {
    final at60 = _blessingGain(60);
    final at120 = _blessingGain(120);
    expect((at120 - at60).abs() / at60, lessThan(0.05));
  });

  // In survival a Kin's ship heal is a share of the ship's hundred points
  // (Water: 5), and survival pays the orb the same share of the orb's pool.
  // Down here the party is the vessel. It used to land as flat HP, halved:
  // 2.5 points of a six-hundred pool.
  test("a Kin's ship heal lands on each ally as a share of its pool", () {
    final g = _kinCast();
    final ally = g.creatures[1];
    expect(ally.hpFraction - 0.5, greaterThan(0.04));
    expect(ally.hpFraction - 0.5, lessThan(0.08));
  });

  // In survival a blessing also mends the orb at half the caster's rate;
  // with no orb down here, that half lands on each ally.
  test('a blessing also mends each ally at half the caster rate', () {
    final g = _kinCast();
    final kin = g.combatCompanions[0];
    final ally = g.combatCompanions[1];
    expect(kin.blessingTimer, greaterThan(0));
    expect(ally.blessingTimer, kin.blessingTimer);
    expect(ally.blessingHealPerTick, closeTo(kin.blessingHealPerTick / 2, 1e-9));
  });

  test('the combat body agrees with the creature after a heal', () {
    final g = _game();
    final c = g.creatures.single;
    final comp = g.combatCompanions.single;
    c.hp = c.maxHp / 2;
    comp
      ..blessingTimer = 5
      ..blessingHealPerTick = 40;
    for (var i = 0; i < 60; i++) {
      g.update(1 / 60);
    }
    expect(comp.currentHp / comp.maxHp, closeTo(c.hpFraction, 0.01));
  });
}
