import 'dart:collection';

import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/family_combat_copy.dart';

enum FamilyMasteryCurrency { silver, gold }

class FamilyMasteryNodeDef {
  const FamilyMasteryNodeDef({
    required this.id,
    required this.name,
    required this.description,
    required this.tier,
    required this.cost,
    required this.currency,
    required this.effectId,
  });

  final String id;
  final String name;
  final String description;
  final int tier;
  final int cost;
  final FamilyMasteryCurrency currency;

  /// Stable runtime key. Combat integration can change implementation without
  /// invalidating saved purchases.
  final String effectId;

  bool get isCapstone => tier == 4;
}

class FamilyMasteryPathDef {
  const FamilyMasteryPathDef({
    required this.id,
    required this.name,
    required this.role,
    required this.nodes,
  });

  final String id;
  final String name;
  final String role;
  final List<FamilyMasteryNodeDef> nodes;
}

class FamilyMasteryTreeDef {
  const FamilyMasteryTreeDef({
    required this.family,
    required this.chassis,
    required this.paths,
  });

  final CreatureFamily family;
  final String chassis;
  final List<FamilyMasteryPathDef> paths;
}

class FamilyMasteryCatalogEntry {
  const FamilyMasteryCatalogEntry({
    required this.tree,
    required this.path,
    required this.node,
  });

  final FamilyMasteryTreeDef tree;
  final FamilyMasteryPathDef path;
  final FamilyMasteryNodeDef node;
}

class FamilyMasteryPartyMemberRef {
  const FamilyMasteryPartyMemberRef({
    required this.slotIndex,
    required this.instanceId,
    required this.family,
  });

  final int slotIndex;
  final String instanceId;
  final CreatureFamily family;
}

class EquippedFamilyMastery {
  EquippedFamilyMastery({
    required this.instanceId,
    required this.family,
    required this.pathId,
    required Iterable<String> activeNodeIds,
  }) : activeNodeIds = UnmodifiableSetView(Set<String>.of(activeNodeIds));

  final String instanceId;
  final CreatureFamily family;
  final String pathId;
  final Set<String> activeNodeIds;

  bool hasNode(String nodeId) => activeNodeIds.contains(nodeId);
}

class SurvivalFamilyMasterySnapshot {
  SurvivalFamilyMasterySnapshot(Map<int, EquippedFamilyMastery> bySlot)
    : bySlot = UnmodifiableMapView(Map<int, EquippedFamilyMastery>.of(bySlot));

  final Map<int, EquippedFamilyMastery> bySlot;

  EquippedFamilyMastery? forSlot(int slotIndex) => bySlot[slotIndex];

  static final empty = SurvivalFamilyMasterySnapshot(const {});
}

FamilyMasteryNodeDef _node(
  String pathId,
  int tier,
  String name,
  String description,
) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return FamilyMasteryNodeDef(
    id: '$pathId.$slug',
    name: name,
    description: description,
    tier: tier,
    cost: tier == 4 ? 10 : const [1000, 5000, 10000][tier - 1],
    currency: tier == 4
        ? FamilyMasteryCurrency.gold
        : FamilyMasteryCurrency.silver,
    effectId: '$pathId.$slug',
  );
}

FamilyMasteryPathDef _path(
  String id,
  String name,
  String role,
  List<(String, String)> nodes,
) {
  return FamilyMasteryPathDef(
    id: id,
    name: name,
    role: role,
    nodes: [
      for (var i = 0; i < nodes.length; i++)
        _node(id, i + 1, nodes[i].$1, nodes[i].$2),
    ],
  );
}

final List<FamilyMasteryTreeDef> kFamilyMasteryTrees = [
  FamilyMasteryTreeDef(
    family: CreatureFamily.mane,
    chassis: FamilyCombatCopy.of(CreatureFamily.mane).attack,
    paths: [
      _path('mane.assault', 'Twin Fang', 'Burst down single enemies', [
        (
          'Honed Pair',
          "Slashes fly 35% closer together and each deals 70% damage (up from 65%), making it easier to land both.",
        ),
        (
          'Crosscut',
          "When both slashes hit the same enemy, deal +20% bonus damage and apply your element's effect.",
        ),
        (
          'Predator Step',
          "After a kill, your next attack within 3s tracks its target better and deals +25% damage.",
        ),
        (
          'Blade Dance',
          "Casting your special makes your next 5 attacks boomerang back, hitting again for 35% damage.",
        ),
      ]),
      _path('mane.resonance', 'War Rhythm', 'Build Rhythm and spend it on cadence', [
        (
          'Measured Cuts',
          "Landing both slashes on one enemy builds Rhythm (max 5). Each Rhythm gives +2% attack speed. Missing with both loses 1.",
        ),
        (
          'Tempest Ring',
          "Every 4th attack also bursts 8 slashes outward in a ring (20% damage each) that carry your element.",
        ),
        (
          'Crescendo',
          "Casting your special spends all Rhythm: that many following attacks deal +12% damage and apply your element's effect.",
        ),
        (
          'Encore',
          "Spending 5 Rhythm starts a 6s Encore: +25% attack speed and wider slashes. Kills extend it by up to 2s.",
        ),
      ]),
      _path('mane.limitless', 'Limitless', 'Your special never stops travelling', [
        (
          'Far Throw',
          "Your special's projectiles travel 45% further before fading, piercing more enemies on the way.",
        ),
        ('Overdraw', "Your special deals 15% more damage."),
        (
          'No Horizon',
          "Your special's projectiles stop fading with time. Only the edge of the arena stops them.",
        ),
        (
          'Endless Circuit',
          "Your first special sends a shot to circle the arena rim for good, cutting down enemies as they come in. Later specials fire as normal.",
        ),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.let,
    chassis: FamilyCombatCopy.of(CreatureFamily.let).attack,
    paths: [
      _path('let.assault', 'Falling Star', 'One enormous auto-attack hit', [
        (
          'Dense Core',
          "Your auto-attack meteor deals 135% damage (up from 115%) but is 12% smaller and flies 10% slower.",
        ),
        (
          'Cratermaker',
          "An auto-attack meteor hit cracks the enemy: your next auto-attack meteor on it within 4s deals +18%.",
        ),
        (
          'Dead Weight',
          "Your auto-attack meteor deals +25% damage to enemies above half health.",
        ),
        (
          'Extinction Event',
          "Every 5th auto-attack meteor is a giant comet that deals 210% damage across a wide crater.",
        ),
      ]),
      _path('let.bombardment', 'Bombardment', 'Your auto-attack falls from the sky', [
        (
          'Deadfall',
          "Your auto-attack meteor drops onto its target from above. It can't be dodged and lands in a small crater after a short fall.",
        ),
        (
          'Heavy Ordnance',
          "Your auto-attack crater is 35% wider, and everything in it takes 75% of the hit (up from 55%).",
        ),
        (
          'Ranging Shots',
          "+25% attack range. Each drop on the same enemy within 3s of the last lands 10% harder, up to +30%.",
        ),
        (
          'Skyreach',
          "Your auto-attack meteor can reach any enemy in the arena, always landing on the toughest one.",
        ),
      ]),
      _path('let.ground_zero', 'Ground Zero', 'Your special meteor marks targets', [
        (
          'Sighted',
          "Enemies hit by your special meteor are Sighted for 6s. Your auto-attack meteors deal +20% damage to them.",
        ),
        (
          'Walking Fire',
          "Your auto-attack meteors go after Sighted enemies first, and each hit adds 1s to the Sight (up to 10s).",
        ),
        (
          'Called Shot',
          "Your whole team deals +10% damage to Sighted enemies.",
        ),
        (
          'Fire for Effect',
          "While any enemy is Sighted you attack 30% faster, and when a Sighted enemy dies its Sight jumps to the nearest enemy.",
        ),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.pip,
    chassis: FamilyCombatCopy.of(CreatureFamily.pip).attack,
    paths: [
      _path('pip.assault', 'Needlepoint', 'Pin down and shred one target', [
        (
          'Tight Grouping',
          "Darts fly 45% closer together and each deals 32% damage (up from 30%), making it easier to land all three.",
        ),
        (
          'Pin Cushion',
          "Landing all 3 darts on one enemy adds a Pin (max 5). Each Pin makes your darts deal +3% damage to it.",
        ),
        (
          'Pluck the Pins',
          "Hitting an enemy that has 5 Pins rips them out for a 55% damage burst. Bosses keep 2 Pins.",
        ),
        (
          'Thousand Cuts',
          "Every 4th time all 3 darts land, fire a bonus 5-dart volley at the same enemy (16% damage each).",
        ),
      ]),
      _path('pip.control', 'Scattershot', 'Spray darts across the whole crowd', [
        (
          'Wide Spray',
          "Darts fly 40% further apart and each curves toward its own nearby enemy.",
        ),
        (
          'Three Fronts',
          "When your 3 darts hit 3 different enemies, each one deals +20% damage.",
        ),
        ('Fourth Barrel', "Your attack fires a 4th dart."),
        (
          'Scatter Storm',
          "Every 5th attack throws 8 darts, each seeking its own enemy (22% damage each).",
        ),
      ]),
      _path('pip.salvo', 'Salvo', 'Load more darts into every special', [
        (
          'Spare Needle',
          "Your special throws 1 more dart, at 70% of a normal dart's damage.",
        ),
        (
          'Double Load',
          "Your special throws another dart, also at 70% damage.",
        ),
        (
          'Full Quiver',
          "Your special throws another dart, also at 70% damage.",
        ),
        (
          'Perfect Salvo',
          "Your special throws a 4th extra dart, and every extra dart now hits as hard as the rest.",
        ),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.mask,
    chassis: FamilyCombatCopy.of(CreatureFamily.mask).attack,
    paths: [
      _path('mask.deathmask', 'Deathmask', 'Every kill leaves a trap behind', [
        (
          'Grave Goods',
          "Enemies your darts kill leave a small trap of your element where they fell, at 35% strength.",
        ),
        (
          'Open Grave',
          "Those traps are 40% wider and last 50% longer.",
        ),
        (
          'Cold Ground',
          "They carry your element's full effect instead of a weakened one.",
        ),
        (
          'Necropolis',
          "A dart kill inside one of your own traps leaves a trap at full strength instead of a small one.",
        ),
      ]),
      _path('mask.rearm', 'Rearm', 'Your traps stop spending themselves', [
        (
          'Spring Again',
          "A trap that goes off re-arms after 2.5s instead of being used up.",
        ),
        (
          'Hair Trigger',
          "It re-arms in 1.2s, and re-arming no longer shortens how long it lasts.",
        ),
        (
          'Snap Shut',
          "A re-armed trap catches everything in reach at once, not just the first enemy to touch it.",
        ),
        (
          'Held Ground',
          "A trap that has gone off three times stops expiring, and holds until something kills it.",
        ),
      ]),
      _path('mask.contagion', 'Contagion', 'What your traps catch carries it', [
        (
          'Carrier',
          "An enemy that walks out of one of your traps alive is infected for 6s.",
        ),
        (
          'Spread',
          "An infected enemy infects others that come near it, once per second.",
        ),
        (
          'Virulence',
          "Infection ticks your element's effect on whatever is carrying it.",
        ),
        (
          'Plague',
          "An infected enemy that dies bursts, infecting everything nearby and dealing damage.",
        ),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.horn,
    chassis: FamilyCombatCopy.of(CreatureFamily.horn).attack,
    paths: [
      _path('horn.bulwark', 'Bulwark', 'Turn your bulk into damage', [
        (
          'Ironhead',
          "Your attacks hit for an extra 2.5% of your maximum HP. The tougher you are built, the harder you hit.",
        ),
        (
          'Weight Behind It',
          "Your special carries the same weight, at 60% — including passive and channelled Horns.",
        ),
        (
          'Braced',
          "The bonus rides your health: 1.5x at full HP, fading to 0.5x when you are nearly down.",
        ),
        (
          'Anvil',
          "Enemies killed by that weight rupture for 12% of your maximum HP to everything near them, carrying your element.",
        ),
      ]),
      _path('horn.bastion', 'Bastion', 'Take the hits meant for the team', [
        (
          'Guarded Shot',
          "Each attack gives you a shield worth 1.5% of your max HP, stacking up to 6%.",
        ),
        (
          'Bodyguard',
          "While you stand near the orb, a quarter of the damage it takes is dealt to you instead — and you take 40% less of it than it would have.",
        ),
        (
          'Shield Wall',
          "While your shield holds, allies near you take 20% less damage.",
        ),
        (
          'Last Stand',
          "When your shield is broken through, it ruptures for elemental damage around you and gives back 20% of your special cooldown.",
        ),
      ]),
      _path('horn.juggernaut', 'Juggernaut', 'Your special runs a second time', [
        (
          'Second Effort',
          "When your special finishes, it runs again at 45% power. Passive Horns gain a pulse of the same strength instead.",
        ),
        (
          'Full Weight',
          "The second run carries your element's full effect instead of a weakened one.",
        ),
        (
          'Relentless',
          "The second run is no longer the weak one: 75% power, and a passive Horn's pulse comes twice as often.",
        ),
        (
          'Second Front',
          "The second run begins where the first one ended, and covers 40% more ground.",
        ),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.wing,
    chassis: FamilyCombatCopy.of(CreatureFamily.wing).attack,
    paths: [
      _path('wing.burn_through', 'Burn Through', 'Hold the beam and it bites deeper', [
        (
          'Bore',
          "Your beam hits harder the longer it stays on one enemy, up to +45%. Moving off drops it.",
        ),
        (
          'Deeper',
          "It builds twice as fast and reaches +80%.",
        ),
        (
          'No Reprieve',
          "Moving off no longer drops it at once — it fades over 2s, so switching targets costs little.",
        ),
        (
          'Carry Through',
          "An enemy that dies at full bite hands it to whatever your beam touches next.",
        ),
      ]),
      _path('wing.longshot', 'Longshot', 'The further out, the harder you hit', [
        (
          'Rangefinder',
          "Everything you do to an enemy past 60% of your range deals +15%.",
        ),
        (
          'Long Lens',
          "Your range grows 20%, and the bonus climbs with distance to +35% at the edge.",
        ),
        (
          'Standoff',
          "While nothing is closer than 30% of your range, that bonus applies at any distance.",
        ),
        (
          'Horizon',
          "Your range grows another 35%, and everything past the old edge takes the full bonus.",
        ),
      ]),
      _path('wing.tracer', 'Tracer', 'Your shots feed your beam', [
        (
          'Tracer Rounds',
          "Each attack that lands takes 0.25s off your special's cooldown.",
        ),
        (
          'Ranging Shots',
          "Each landed attack also adds 0.1s to your next beam, up to 1.5s.",
        ),
        (
          'Hot Barrel',
          "Both grow: 0.4s off the cooldown and 0.18s onto the beam, up to 3s.",
        ),
        (
          'Live Feed',
          "While a beam is firing, your attacks lengthen the beam already running instead of banking for the next one.",
        ),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.kin,
    chassis: FamilyCombatCopy.of(CreatureFamily.kin).attack,
    paths: [
      _path('kin.assault', 'Overcharge', 'Turn the laser into a weapon', [
        (
          'Hot Coil',
          "Your laser charges in 1.25s instead of 1.5s. Each shot deals 10% less, but you fire faster for about +8% damage overall.",
        ),
        (
          'Burn Through',
          "Your laser pierces one more enemy, dealing 55% damage to it.",
        ),
        (
          'Critical Mass',
          "Keeping the same target for a full charge adds +20% damage and applies your element's effect.",
        ),
        (
          'Judgment Line',
          "Every 4th charge overcharges into a much wider beam that deals 180% damage.",
        ),
      ]),
      _path('kin.control', 'Conduit', 'Mark enemies for the whole team', [
        (
          'Conductivity',
          "Your laser marks its target for 4s. The marked enemy takes +8% damage from your whole team.",
        ),
        (
          'Ground Path',
          "Firing through the marked enemy leaves a 2s energy lane; enemies crossing it take your element's effect.",
        ),
        (
          'Relay Point',
          "When a teammate hits the marked enemy, a shock jumps to another nearby enemy for 20% elemental damage.",
        ),
        (
          'Living Circuit',
          "While your support special is active, you can mark up to 3 enemies at once and shocks chain between them.",
        ),
      ]),
      _path('kin.resonance', 'Aegis Relay', 'Lasers shield and speed up allies', [
        (
          'Guard Charge',
          "Each laser shields your weakest teammate or the orb for 1% of your max HP (up to 4% each).",
        ),
        ('Shared Current', "Teammates you shield get +8% attack speed for 2s."),
        (
          'Blessing Reserve',
          "Laser hits store Reserve (max 5). Casting your special spends it for +4% healing, shielding, and duration per stack.",
        ),
        (
          'Guardian Relay',
          "Spending 5 Reserve channels your element through every teammate: harmful elements hit nearby enemies; Blood and Light heal and protect.",
        ),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.mystic,
    chassis: FamilyCombatCopy.of(CreatureFamily.mystic).attack,
    paths: [
      _path('mystic.assault', 'Starcaller', 'Make your spell volleys count', [
        (
          'Aligned Stars',
          "Bolts fly 30% closer together and each deals 42% damage (up from 40%).",
        ),
        (
          'Conjunction',
          "When all 3 bolts hit one enemy, add 30% elemental damage and apply your element's effect.",
        ),
        (
          'Falling Sign',
          "Every 4th time all 3 bolts land, the enemy is marked: your next volley homes in on it for +20% damage.",
        ),
        (
          'The Stars Answer',
          "Every 5th attack calls a star sigil onto your target for 85% elemental area damage, larger while your world is active.",
        ),
      ]),
      _path('mystic.control', 'Worldshaper', 'Plant Seeds your world awakens', [
        (
          'Seed the Field',
          "Every 3rd attack plants a Seed for 8s (max 3). Seeds pulse 10% elemental damage to nearby enemies every 2s.",
        ),
        (
          'Local Omen',
          "Seeds also apply a weak version of your element's effect to nearby enemies.",
        ),
        (
          'Awakening',
          "When your world appears, all current Seeds awaken, pulse harder, and last as long as the world does.",
        ),
        (
          'Living World',
          "While your world is active, every 5th attack grows a new awakened Seed for 5s (up to 5 Seeds).",
        ),
      ]),
      _path('mystic.resonance', 'Covenant', 'Accuracy powers team-wide boons', [
        (
          'Witness',
          "Landing all 3 bolts builds Insight (max 5, never fades). Each Insight gives +2% attack damage.",
        ),
        (
          'Shared Vision',
          "At 5 Insight, your whole team gets +5% attack range and your bolts favor enemies no one else is hitting.",
        ),
        (
          'Oath Fulfilled',
          "When your world appears, it spends all Insight to give every teammate a 5s elemental boon.",
        ),
        (
          'Worldbond',
          "While your world is active, every 5 full volleys heal or shield your team and hit nearby enemies with your element.",
        ),
      ]),
    ],
  ),
];

class FamilyMasteryCatalog {
  FamilyMasteryCatalog._();

  static final Map<CreatureFamily, FamilyMasteryTreeDef> _trees = {
    for (final tree in kFamilyMasteryTrees) tree.family: tree,
  };

  static final Map<String, FamilyMasteryCatalogEntry> _nodes = {
    for (final tree in kFamilyMasteryTrees)
      for (final path in tree.paths)
        for (final node in path.nodes)
          node.id: FamilyMasteryCatalogEntry(
            tree: tree,
            path: path,
            node: node,
          ),
  };

  static FamilyMasteryTreeDef treeFor(CreatureFamily family) => _trees[family]!;

  static FamilyMasteryCatalogEntry? entryForNode(String nodeId) =>
      _nodes[nodeId];

  static FamilyMasteryPathDef? pathFor(CreatureFamily family, String pathId) {
    for (final path in treeFor(family).paths) {
      if (path.id == pathId) return path;
    }
    return null;
  }

  static Set<String> sanitizePurchases(
    CreatureFamily family,
    Iterable<String> nodeIds,
  ) {
    final result = <String>{};
    final tree = treeFor(family);
    final requested = nodeIds.toSet();
    for (final path in tree.paths) {
      for (final node in path.nodes) {
        if (!requested.contains(node.id)) break;
        result.add(node.id);
      }
    }
    return result;
  }

  static List<String> validate() {
    final errors = <String>[];
    final treeFamilies = <CreatureFamily>{};
    final pathIds = <String>{};
    final nodeIds = <String>{};
    for (final tree in kFamilyMasteryTrees) {
      if (!treeFamilies.add(tree.family)) {
        errors.add('Duplicate family tree: ${tree.family.name}');
      }
      if (tree.paths.length != 3) {
        errors.add('${tree.family.name} must have exactly three paths');
      }
      for (final path in tree.paths) {
        if (!pathIds.add(path.id)) errors.add('Duplicate path: ${path.id}');
        if (!path.id.startsWith('${tree.family.name}.')) {
          errors.add('Path ${path.id} does not belong to ${tree.family.name}');
        }
        if (path.nodes.length != 4) {
          errors.add('${path.id} must have exactly four nodes');
        }
        for (var i = 0; i < path.nodes.length; i++) {
          final node = path.nodes[i];
          if (!nodeIds.add(node.id)) errors.add('Duplicate node: ${node.id}');
          if (node.tier != i + 1) {
            errors.add('${node.id} has tier ${node.tier}, expected ${i + 1}');
          }
          final shouldBeCapstone = i == 3;
          if (node.isCapstone != shouldBeCapstone) {
            errors.add('${node.id} has invalid capstone state');
          }
          if (shouldBeCapstone) {
            if (node.currency != FamilyMasteryCurrency.gold ||
                node.cost != 10) {
              errors.add('${node.id} must cost 10 gold');
            }
          } else if (node.currency != FamilyMasteryCurrency.silver) {
            errors.add('${node.id} must cost silver');
          }
        }
      }
    }
    if (treeFamilies.length != CreatureFamily.values.length) {
      errors.add('Every CreatureFamily must have a tree');
    }
    return errors;
  }
}

CreatureFamily? creatureFamilyFromStorage(String raw) {
  final normalized = raw.trim().toLowerCase();
  for (final family in CreatureFamily.values) {
    if (family.name == normalized) return family;
  }
  return null;
}

CreatureFamily? creatureFamilyFromBaseId(String baseId) {
  if (baseId.length < 3) return null;
  return switch (baseId.substring(0, 3).toUpperCase()) {
    'LET' => CreatureFamily.let,
    'HOR' => CreatureFamily.horn,
    'KIN' => CreatureFamily.kin,
    'MAN' => CreatureFamily.mane,
    'MSK' => CreatureFamily.mask,
    'PIP' => CreatureFamily.pip,
    'WNG' => CreatureFamily.wing,
    'MYS' => CreatureFamily.mystic,
    _ => null,
  };
}
