import 'package:alchemons/models/elemental_group.dart';

/// How each family fights, in words a player reads.
///
/// One source for the survival lobby's species roster, the mastery tree's
/// base-attack line and the creature battle tab, so a family never describes
/// itself two different ways on two screens. Write these for a person
/// glancing at a card: what they will see happen, not how the code is tuned.
class FamilyCombatCopy {
  const FamilyCombatCopy({
    required this.role,
    required this.attack,
    required this.special,
    required this.about,
  });

  /// A two-word job title.
  final String role;

  /// The auto-attack, in one short line.
  final String attack;

  /// What the family's specials share, in one line. Every element puts its
  /// own spin on it.
  final String special;

  /// A short paragraph on how the family plays, for wherever there is room
  /// to say more than a line.
  final String about;

  static FamilyCombatCopy of(CreatureFamily family) =>
      kFamilyCombatCopy[family]!;

  /// The copy for a family stored as a display or storage string ('Let',
  /// 'mane'), or null for anything that is not one of the eight.
  static FamilyCombatCopy? forName(String family) {
    final normalized = family.trim().toLowerCase();
    for (final entry in kFamilyCombatCopy.entries) {
      if (entry.key.name == normalized) return entry.value;
    }
    return null;
  }
}

const Map<CreatureFamily, FamilyCombatCopy> kFamilyCombatCopy = {
  CreatureFamily.let: FamilyCombatCopy(
    role: 'Siege Caster',
    attack: 'Throws one big, slow rock.',
    special:
        'Calls a meteor down onto its target. The crater carries the element\'s own effect.',
    about:
        'Lets hang back and pick on the toughest enemy on the field, bosses above all. They fire slowly but reach far, so keep them behind the front line.',
  ),
  CreatureFamily.pip: FamilyCombatCopy(
    role: 'Tempo Carry',
    attack: 'Fires three quick darts in a fan.',
    special:
        'Fires darts that ricochet from enemy to enemy, each element adding its own twist.',
    about:
        'Pips attack faster than anyone and chase down weakened or scattered enemies. Great at clearing waves, weaker against bosses.',
  ),
  CreatureFamily.mane: FamilyCombatCopy(
    role: 'Barrage Bruiser',
    attack: 'Throws two blades side by side. Land both for full damage.',
    special: 'Hurls one huge blade through every enemy in a line.',
    about:
        'Manes fight at mid range and push into the line. The more enemies stand in a row, the more a Mane gets done.',
  ),
  CreatureFamily.horn: FamilyCombatCopy(
    role: 'Frontline Bastion',
    attack: 'Fires one big, slow, heavy shot.',
    special:
        'A heavy defensive move: a charge, a slam, a wall or an aura, by element.',
    about:
        'Horns fight up close and take hits for the team. They give up some damage for toughness and hold enemies in front of everyone else.',
  ),
  CreatureFamily.mask: FamilyCombatCopy(
    role: 'Control Trapper',
    attack: 'Fires one fast dart that passes through enemies.',
    special:
        'Scatters traps that catch, lure or punish whatever walks into them.',
    about:
        'Masks shape the battlefield. They pull pressure away from your ship and into ground they have prepared for the rest of the team.',
  ),
  CreatureFamily.wing: FamilyCombatCopy(
    role: 'Beam Hunter',
    attack: 'Fires two quick shots, one right behind the other.',
    special: 'Fires a long beam down a lane of the arena.',
    about:
        'Wings keep their distance and pick enemies off from long range. They are at their best with room to shoot and a clear lane.',
  ),
  CreatureFamily.kin: FamilyCombatCopy(
    role: 'Guardian Support',
    attack: 'Charges up, then fires a laser.',
    special:
        'Heals and blesses the team, plus a support piece unique to its element.',
    about:
        'Kins keep the team alive. Every one is rare, and each element brings a kind of support no other creature has.',
  ),
  CreatureFamily.mystic: FamilyCombatCopy(
    role: 'World Shaper',
    attack: 'Fires three spell bolts in a fan.',
    special:
        'Turns the arena into its element\'s world until the Mystic falls.',
    about:
        'Only one Mystic can join a team. It is slow to cast, but while it stands the whole arena plays by its element\'s rules.',
  ),
};
