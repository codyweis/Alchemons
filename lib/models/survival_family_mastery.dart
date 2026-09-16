import 'dart:collection';

import 'package:alchemons/models/elemental_group.dart';

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
    chassis: 'Twin close-angle slashes that reward landing both blades.',
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
      _path('mane.control', 'Tempest Claw', 'Spread your element across groups', [
        (
          'Sweeping Claws',
          "Slashes are 35% wider and spread further to catch more enemies, but deal 60% damage each (down from 65%).",
        ),
        (
          'Rending Wake',
          "The first enemy each slash hits takes your element's effect at 80% strength.",
        ),
        (
          'Crosswind',
          "When the two slashes hit different enemies, both take your element's effect again at 40% strength.",
        ),
        (
          'Tempest Ring',
          "Every 4th attack also bursts 8 slashes outward in a ring (20% damage each) that carry your element.",
        ),
      ]),
      _path('mane.resonance', 'War Rhythm', 'Build Rhythm, cash it in with specials', [
        (
          'Measured Cuts',
          "Landing both slashes on one enemy builds Rhythm (max 5). Each Rhythm gives +2% attack speed. Missing with both loses 1.",
        ),
        (
          'Rising Tempo',
          "Each Rhythm also gives +3% attack damage, and at 3+ Rhythm your slashes grow 15% wider.",
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
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.let,
    chassis: 'One large, slow meteor built around deliberate heavy impact.',
    paths: [
      _path('let.assault', 'Falling Star', 'Huge single hits on tough enemies', [
        (
          'Dense Core',
          "Meteors deal 135% damage (up from 115%) but are 12% smaller and fall 10% slower.",
        ),
        (
          'Cratermaker',
          "A direct hit cracks the enemy: your next meteor on it within 4s deals +18% damage.",
        ),
        (
          'Terminal Velocity',
          "Meteors hit harder the longer they travel, up to +20% damage on long throws.",
        ),
        (
          'Extinction Event',
          "Every 5th attack is a giant comet that deals 210% damage to everything in a wide crater.",
        ),
      ]),
      _path('let.control', 'Scatterfall', 'Shatter and scorch whole areas', [
        (
          'Shatterstone',
          "Meteors burst into 3 fragments on impact, each hitting another nearby enemy for 18% damage.",
        ),
        (
          'Elemental Crater',
          "Impacts splash your element's effect onto enemies around the crater at 80% strength.",
        ),
        (
          'Lingering Fall',
          "Craters linger for 2.5s, reapplying your element's effect to enemies inside every second.",
        ),
        (
          'Meteor Season',
          "Every 3rd attack calls 3 small meteors down around the impact 0.6s later (28% damage each).",
        ),
      ]),
      _path('let.resonance', 'Orbital Cycle', 'Build Orbit to amplify specials', [
        (
          'Impact Memory',
          "Each direct hit adds 1 Orbit (max 4). Each Orbit gives your meteors +4% damage.",
        ),
        (
          'Satellite Fire',
          "While at 4 Orbit, every other attack also calls a satellite strike for 30% elemental damage.",
        ),
        (
          'Convergence',
          "Casting your special spends all Orbit; each one adds an elemental aftershock around the special's target.",
        ),
        (
          'Second Impact',
          "Spending 4 Orbit also makes your special strike a second time 1s later at 40% power.",
        ),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.pip,
    chassis: 'Three fast spread darts built around precision and volume.',
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
      _path('pip.control', 'Impossible Angles', 'Trick shots that hit everything', [
        (
          'Bank Shot',
          "Your center dart ricochets to a second enemy for 45% of its damage.",
        ),
        (
          'Split Decision',
          "Side darts curve toward different nearby enemies and deal 34% damage when they split up.",
        ),
        (
          'Trick Payload',
          "The first ricochet or side-dart hit of each attack applies your element's effect at 75% strength.",
        ),
        (
          'No Safe Angle',
          "Every 5th attack fires 6 darts that curve into different enemies (22% damage each).",
        ),
      ]),
      _path('pip.resonance', 'Quickwork', 'Accuracy fuels faster firing', [
        (
          'Clean Volley',
          "Landing all 3 darts builds Tempo (max 6, fades after 4s). Each Tempo gives +1.5% dart damage.",
        ),
        (
          'Fast Hands',
          "Every 2 Tempo also gives +4% attack speed (+4% damage instead for Pips that already boost speed).",
        ),
        (
          'Cash Out',
          "Casting your special spends all Tempo: each one adds an extra dart (18% damage) to one of your next attacks.",
        ),
        (
          'Overflow',
          "Spending 6 Tempo starts 5s of Overflow: 4-dart volleys, and every 3rd attack applies your element's effect.",
        ),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.mask,
    chassis: 'One fast dart that pierces through its target.',
    paths: [
      _path('mask.assault', 'Phantom Needle', 'Pierce lines and punish elites', [
        (
          'Long Needle',
          "Your dart flies 10% faster and 25% farther, and deals 100% damage to the first enemy (up from 90%).",
        ),
        (
          'Through the Veil',
          "Each enemy your dart pierces makes it hit the next one 8% harder (up to +24%).",
        ),
        (
          'Chosen Victim',
          "The first elite or boss you hit is Marked for 3s and takes +12% damage from your darts.",
        ),
        (
          'Phantom Lance',
          "Every 4th attack is a wide spectral lance that pierces everything for 145% damage and applies your element to the first 3 enemies.",
        ),
      ]),
      _path('mask.control', 'Hexweaver', 'Brand enemies to empower traps', [
        (
          'Inscribed Dart',
          "Your dart brands the first enemy it hits with a Sigil for 4s. Your darts deal +10% damage to it.",
        ),
        (
          'Binding Script',
          "Hitting the Sigiled enemy again applies your element's effect and slows it 15% (once per second).",
        ),
        (
          'Prepared Ground',
          "Casting your special near the Sigiled enemy makes that trap 15% larger and last 20% longer.",
        ),
        (
          'Haunted Ground',
          "The empowered trap also shoots darts at nearby enemies every 1.2s (30% damage each).",
        ),
      ]),
      _path('mask.resonance', 'Grand Masquerade', 'Lure enemies into your traps', [
        (
          'False Face',
          "Enemies you hit are 20% more likely to attack your traps and decoys instead of your team for 2s.",
        ),
        (
          'Applause',
          "Whenever one of your traps catches an enemy, gain +12% attack speed for 2s.",
        ),
        (
          'Curtain Call',
          "Enemies that die while caught in a trap burst, applying your element's effect nearby at 60% strength.",
        ),
        (
          'Grand Masquerade',
          "While one of your traps is active, every 3rd attack also fires a spectral dart from the trap (35% damage).",
        ),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.horn,
    chassis: 'One slow, oversized projectile that lands a heavy hit.',
    paths: [
      _path('horn.assault', 'Breaker', 'Crush armor up close', [
        (
          'Heavy Head',
          "Projectiles deal 175% damage (up from 160%) but fly 8% slower.",
        ),
        (
          'Sunder',
          "Hits crack armor: the enemy takes +6% damage for 3s, stacking twice (half as much on bosses).",
        ),
        (
          'Point Blank',
          "Hits on nearby enemies deal +22% damage and briefly stagger regular enemies.",
        ),
        (
          'Siege Horn',
          "Every 4th attack is a siege shell: 220% damage plus a shockwave that hits nearby enemies for 55%.",
        ),
      ]),
      _path('horn.control', 'Bastion', 'Shield the team and hold ground', [
        (
          'Guarded Shot',
          "Each attack gives you a small shield worth 1.5% of your max HP, stacking up to 6%.",
        ),
        (
          'Hold the Line',
          "Hitting an enemy heading for the orb knocks it back and applies your element's effect at 70% strength.",
        ),
        (
          'Interposition',
          "With a full shield, your Horn blocks the next enemy shot aimed at the orb or a nearby ally.",
        ),
        (
          'Countercharge',
          "After a block, your next attack within 4s becomes a 190% damage countershot with big knockback and your element's effect.",
        ),
      ]),
      _path('horn.resonance', 'Stampede', 'Build Momentum for bigger charges', [
        (
          'Gather Momentum',
          "Each hit builds Momentum (max 5, fades after 5s). Each Momentum gives +2% attack damage.",
        ),
        (
          'Rolling Weight',
          "Each Momentum also gives +2% attack speed and +3% projectile speed.",
        ),
        (
          'Impact Reserve',
          "Casting your special spends Momentum for +6% special power per stack. Passive Horns release an elemental pulse at 5 instead.",
        ),
        (
          'Unstoppable',
          "Spending 5 Momentum makes your next charge unstoppable and 25% wider, and it fires your attack in 4 directions on landing.",
        ),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.wing,
    chassis: 'Two aligned long-range shots fired as a pair.',
    paths: [
      _path('wing.assault', 'Twin Lance', 'Long-range sniping', [
        (
          'Synchronized Flight',
          "Both shots fly together and angle slightly inward; each deals 53% damage (up from 50%).",
        ),
        (
          'Rangefinder',
          "Hits on distant enemies (past 60% of your range) deal +15% damage.",
        ),
        (
          'Double Tap',
          "When both shots hit the same enemy, deal +25% bonus damage and apply your element's effect.",
        ),
        (
          'Twin Suns',
          "Every 5th attack fuses both shots into one homing lance: 165% damage, pierces once, and applies your element.",
        ),
      ]),
      _path('wing.control', 'Razor Horizon', 'Piercing shots across wide lanes', [
        (
          'Open Wings',
          "Shots fan outward and each pierces one enemy, dealing 46% damage (down from 50%).",
        ),
        (
          'Crosscurrent',
          "After piercing, each shot curves toward a new nearby enemy for 35% damage.",
        ),
        (
          'Elemental Contrails',
          "The first enemy each shot pierces takes your element's effect at 60% strength.",
        ),
        (
          'Razor Horizon',
          "Every 4th attack leaves a blade of light between the shots for 1s: enemies crossing it take 65% damage and your element.",
        ),
      ]),
      _path('wing.resonance', 'Beamweaver', 'Build Focus to power beams', [
        (
          'Sightline',
          "Landing both shots on one enemy builds Focus (max 5, fades after 6s). Each Focus gives +2% attack range.",
        ),
        ('Coherent Light', "Each Focus also gives +3% attack damage."),
        (
          'Beam Feed',
          "Casting your special spends all Focus: +4% special duration and power per stack.",
        ),
        (
          'Continuum',
          "Spending 5 Focus leaves an echo of your special after it ends, dealing 35% of its power.",
        ),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.kin,
    chassis: 'A physical laser that charges up before it fires.',
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
    chassis: 'A volley of three spell bolts.',
    paths: [
      _path('mystic.assault', 'Starcaller', 'Make your spell volleys hit hard', [
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
