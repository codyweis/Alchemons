import 'dart:collection';
import 'dart:math' as math;

import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/family_combat_copy.dart';

/// What each tier of a path costs, in its own family's mastery points. A
/// whole path is 550.
const List<int> kFamilyMasteryTierCosts = [25, 75, 150, 300];

/// Mastery points clearing [wave] is worth: one, and one more for every ten
/// waves in, so a deep run pays more than a string of short ones.
int familyMasteryPointsForWave(int wave) => wave < 1 ? 0 : 1 + wave ~/ 10;

/// A run's base mastery: every cleared wave's worth, added up. 19 waves is
/// 29, 39 is 99, 59 is 209 and 79 is 359. An average deployed creature earns
/// its family about [kFamilyMasteryRate] of this
/// ([familyMasteryCreatureAwards]).
int familyMasteryPointsForRun(int wavesCleared) {
  var total = 0;
  for (var wave = 1; wave <= wavesCleared; wave++) {
    total += familyMasteryPointsForWave(wave);
  }
  return total;
}

/// The last wave a run fully cleared. The spawner's wave is the one being
/// fought, so a run lost on wave 41 cleared 40 — unless it ended in the
/// pause between waves, when the wave it shows has just been cleared.
int survivalWavesCleared({
  required int currentWave,
  required bool intermission,
}) {
  final cleared = intermission ? currentWave : currentWave - 1;
  return cleared < 0 ? 0 : cleared;
}

/// One creature's part in a finished run, for the mastery it earns its
/// family ([familyMasteryCreatureAwards]).
class FamilyMasteryRunCreature {
  const FamilyMasteryRunCreature({
    required this.family,
    required this.deployed,
    this.damageDealt = 0,
    this.kills = 0,
    this.healingDone = 0,
  });

  final CreatureFamily family;

  /// Summoned at some point in the run, rather than in reserve throughout.
  final bool deployed;
  final double damageDealt;
  final int kills;
  final double healingDone;
}

/// How much of a run's base ([familyMasteryPointsForRun]) its creatures
/// earn between them, as it is paid: mastery came twice as fast as a path
/// should take at 1.
const double kFamilyMasteryRate = 0.5;

/// Of a run's base ([familyMasteryPointsForRun]): what a creature earns for
/// being deployed at all, or for sitting in reserve the whole run.
const double kFamilyMasteryDeployedShare = 0.5;
const double kFamilyMasteryReserveShare = 0.125;

/// Of the base, times the number deployed, split by each creature's share
/// of what the team did — so an average deployed creature earns about one
/// base in all.
const double kFamilyMasteryPerformanceShare = 0.5;

/// No creature earns more than this many bases, however much it carried.
const double kFamilyMasteryCreatureCap = 1.5;

/// What each of [creatures] (the run's party, in party order) earns its
/// family for a run that cleared [wavesCleared] waves.
///
/// With `base` the run's [familyMasteryPointsForRun] × [kFamilyMasteryRate]:
/// - deployed: `0.5 × base` + `0.5 × base × N × c`, where N is how many were
///   deployed and c the creature's share of the team: the mean, over damage
///   dealt, kills and healing done (only the axes the team has any of), of
///   its part of the team's total. Healing counts as its own axis, so a
///   support is paid for supporting. If the team has none of any, the
///   deployed share it evenly.
/// - in reserve the whole run: `0.125 × base`.
///
/// Each is capped at `1.5 × base` and rounded to whole points; a deployed
/// creature earns at least 1 once base is. Deterministic.
List<int> familyMasteryCreatureAwards(
  List<FamilyMasteryRunCreature> creatures,
  int wavesCleared,
) {
  final base = familyMasteryPointsForRun(wavesCleared) * kFamilyMasteryRate;
  if (base <= 0) return List<int>.filled(creatures.length, 0);

  final deployed = [
    for (final c in creatures)
      if (c.deployed) c,
  ];
  final axes = <double Function(FamilyMasteryRunCreature)>[
    (c) => math.max(0, c.damageDealt),
    (c) => math.max(0, c.kills).toDouble(),
    (c) => math.max(0, c.healingDone),
  ];
  final totals = [
    for (final axis in axes) deployed.fold<double>(0, (s, c) => s + axis(c)),
  ];
  final live = [
    for (var i = 0; i < axes.length; i++)
      if (totals[i] > 0) i,
  ];

  double share(FamilyMasteryRunCreature c) {
    if (!c.deployed) return 0;
    if (live.isEmpty) return 1 / deployed.length;
    var sum = 0.0;
    for (final i in live) {
      sum += axes[i](c) / totals[i];
    }
    return sum / live.length;
  }

  final n = deployed.length;
  return [
    for (final c in creatures)
      () {
        final raw = c.deployed
            ? base * kFamilyMasteryDeployedShare +
                  base * kFamilyMasteryPerformanceShare * n * share(c)
            : base * kFamilyMasteryReserveShare;
        final capped = math.min(raw, base * kFamilyMasteryCreatureCap);
        // A hair over, so a half that floating point lands just under
        // still rounds up.
        final points = (capped + 1e-9).round();
        return c.deployed ? math.max(1, points) : points;
      }(),
  ];
}

/// [awards] (from [familyMasteryCreatureAwards]) added up by family, in the
/// order [creatures] first fields each. A family that earned nothing is left
/// out. Bringing more of a family earns that family more.
Map<CreatureFamily, int> familyMasteryFamilySums(
  List<FamilyMasteryRunCreature> creatures,
  List<int> awards,
) {
  final sums = <CreatureFamily, int>{};
  for (var i = 0; i < creatures.length && i < awards.length; i++) {
    sums.update(
      creatures[i].family,
      (v) => v + awards[i],
      ifAbsent: () => awards[i],
    );
  }
  sums.removeWhere((_, points) => points <= 0);
  return sums;
}

/// The node [family] is working toward: the first one not yet owned on its
/// equipped path, then on any other path (the order the mastery screen
/// opens on). Null when the whole tree is owned.
FamilyMasteryNodeDef? familyMasteryNextNode(
  CreatureFamily family, {
  required Set<String> owned,
  String? selectedPathId,
}) {
  final tree = FamilyMasteryCatalog.treeFor(family);
  final ordered = [
    ...tree.paths.where((path) => path.id == selectedPathId),
    ...tree.paths.where((path) => path.id != selectedPathId),
  ];
  for (final path in ordered) {
    for (final node in path.nodes) {
      if (!owned.contains(node.id)) return node;
    }
  }
  return null;
}

class FamilyMasteryNodeDef {
  const FamilyMasteryNodeDef({
    required this.id,
    required this.name,
    required this.description,
    required this.tier,
    required this.cost,
    required this.effectId,
  });

  final String id;
  final String name;
  final String description;
  final int tier;

  /// In this node's family's mastery points.
  final int cost;

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

/// [slug] keeps a renamed node's saved id: without it the id is spelled from
/// [name], so renaming a node would orphan every purchase of it.
FamilyMasteryNodeDef _node(
  String pathId,
  int tier,
  String name,
  String description, {
  String? slug,
}) {
  // An apostrophe is dropped rather than split on: Hunter's Arc is
  // `hunters_arc`, not `hunter_s_arc`.
  slug ??= name
      .toLowerCase()
      .replaceAll("'", '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return FamilyMasteryNodeDef(
    id: '$pathId.$slug',
    name: name,
    description: description,
    tier: tier,
    cost: kFamilyMasteryTierCosts[tier - 1],
    effectId: '$pathId.$slug',
  );
}

/// [slugs] holds, by tier, the saved slug of a node renamed since it was
/// first sold ([_node]).
FamilyMasteryPathDef _path(
  String id,
  String name,
  String role,
  List<(String, String)> nodes, {
  Map<int, String> slugs = const {},
}) {
  return FamilyMasteryPathDef(
    id: id,
    name: name,
    role: role,
    nodes: [
      for (var i = 0; i < nodes.length; i++)
        _node(id, i + 1, nodes[i].$1, nodes[i].$2, slug: slugs[i + 1]),
    ],
  );
}

final List<FamilyMasteryTreeDef> kFamilyMasteryTrees = [
  FamilyMasteryTreeDef(
    family: CreatureFamily.mane,
    chassis: FamilyCombatCopy.of(CreatureFamily.mane).attack,
    paths: [
      _path('mane.resonance', 'War Rhythm', 'Build Rhythm and spend it on cadence', [
        (
          'Measured Cuts',
          "Landing both slashes on one enemy builds Rhythm (max 5). Each Rhythm gives +2% attack speed. Missing with both loses 1.",
        ),
        (
          'Crosscut',
          "When both slashes hit the same enemy, they cross through it to the next enemy ahead, carrying your element's effect. Up to 3 crossings.",
        ),
        (
          'Tempest Ring',
          "Every 4th attack also bursts 8 slashes outward in a ring (20% damage each) that carry your element.",
        ),
        (
          'Encore',
          "Casting your special at 5 Rhythm spends it and starts a 6s Encore: +25% attack speed and wider slashes. Kills extend it by up to 2s.",
        ),
      ]),
      _path('mane.limitless', 'Limitless', 'Your special never stops travelling', [
        (
          'Far Throw',
          "Your special's projectiles travel 45% further before fading, piercing more enemies on the way.",
        ),
        (
          "Hunter's Arc",
          "After its first hit, each of your special's projectiles bends toward the nearest enemy ahead of it.",
        ),
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
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.pip,
    chassis: FamilyCombatCopy.of(CreatureFamily.pip).attack,
    paths: [
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
          "Your special throws 1 more dart, at 60% of a normal dart's damage and reach.",
        ),
        (
          'Second Volley',
          "Your special throws another dart, and the extra darts fly a moment after the first throw, as a second volley.",
        ),
        (
          'Wide Load',
          "Another dart, and the extra darts fan out across a wider arc, so the special covers more of the crowd.",
        ),
        (
          'Perfect Salvo',
          "Your special throws a 4th extra dart, and every extra dart now hits and reaches at 75%.",
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
          'Restless Graves',
          "Your grave traps walk to the nearest enemy standing still and stay under it. With none standing still, they go where enemies are thickest.",
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
          "Infection eats at whatever is carrying it, every half second.",
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
          "Your special carries the same weight, at 60%. A Horn whose special strikes no blow of its own carries it on its attacks instead.",
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
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.wing,
    chassis: FamilyCombatCopy.of(CreatureFamily.wing).attack,
    paths: [
      _path('wing.longshot', 'Longshot', 'The further out, the harder you hit', [
        (
          'Rangefinder',
          "Everything you do to an enemy past 60% of your range deals +15%.",
        ),
        (
          'Long Lens',
          "Your range grows 20%, and your attacks aim ahead of far enemies, so long shots land.",
        ),
        (
          'Standoff',
          "While nothing is closer than 30% of your range, that bonus applies at any distance.",
        ),
        (
          'Overwatch',
          "Every enemy entering the far reach of your range takes a free shot, once. An enemy taking aim within twice your range takes one every time.",
        ),
      ]),
      _path(
        'wing.tracer',
        'Tracer',
        'Your shots feed your beam',
        [
          (
            'Tracer Rounds',
            "Each attack that lands takes 0.25s off your special's cooldown.",
          ),
          (
            'Loaded Beam',
            "Each landed attack also adds 0.1s to your next beam, up to 1.5s.",
          ),
          (
            'Hot Barrel',
            "While your beam is firing, your attacks come twice as fast.",
          ),
          (
            'Live Feed',
            "While a beam is firing, your attacks lengthen the beam already running instead of banking for the next one.",
          ),
        ],
        // Loaded Beam was sold as Ranging Shots, a name Let's Bombardment
        // also uses.
        slugs: {2: 'ranging_shots'},
      ),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.kin,
    chassis: FamilyCombatCopy.of(CreatureFamily.kin).attack,
    paths: [
      _path('kin.conduction', 'Conduction', 'The line carries help, not just harm', [
        (
          'Live Current',
          "Allies your laser passes through gain a shield worth 30% of the damage it dealt.",
        ),
        (
          'Lifeline',
          "An ally below half health is healed instead, for half again as much.",
        ),
        (
          'Grounding',
          "Your element's effect lands on every enemy down the line, not only the first.",
        ),
        (
          'Transfusion',
          "The shield and the heal are worth 50% more, and reach allies near the line as well as on it.",
        ),
      ]),
      _path(
        'kin.benediction',
        'Benediction',
        'Your support reaches the whole team',
        [
          (
            'Kindred',
            "Your support also reaches the ally standing nearest you, at full strength and for as long.",
          ),
          (
            'Vigil',
            "While any ally is below half health, your support recharges twice as fast.",
          ),
          (
            'Unbroken',
            "Being downed no longer ends it — your support runs its full course without you.",
          ),
          (
            'Communion',
            "It reaches every ally and the ship however far apart you are standing: the nearest at full strength, the rest at half.",
          ),
        ],
      ),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.mystic,
    chassis: FamilyCombatCopy.of(CreatureFamily.mystic).attack,
    paths: [
      _path(
        'mystic.quickening',
        'Quickening',
        'Your world acts far more often',
        [
          (
            'Quickening',
            "Each time your world acts, the next enemy to die makes it act again at once at half strength. An Ice world gains an act: a freeze every 6s.",
          ),
          (
            'First Light',
            "It acts the moment it ignites, instead of waiting out a full turn.",
          ),
          (
            'Aftershock',
            "Each time your world acts, it acts again half a second later at 40% strength, in the same place. A repeat is never repeated.",
          ),
          (
            'Relentless Sky',
            "Each time your world acts, it acts once more straight after, at full strength.",
          ),
        ],
      ),
      _path('mystic.firmament', 'Firmament', 'Your world shelters its makers', [
        ('Native Air', "Allies standing in your world take 15% less damage."),
        ('Home Ground', "They deal 15% more while they stand in it."),
        ('Tended', "Your world slowly mends the allies inside it."),
        (
          'Sanctum',
          "Their attacks carry your world's element for as long as they stay.",
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

  /// Problems with the catalog, or with [trees] when a test hands its own.
  static List<String> validate([List<FamilyMasteryTreeDef>? trees]) {
    final errors = <String>[];
    final treeFamilies = <CreatureFamily>{};
    final pathIds = <String>{};
    final nodeIds = <String>{};
    for (final tree in trees ?? kFamilyMasteryTrees) {
      if (!treeFamilies.add(tree.family)) {
        errors.add('Duplicate family tree: ${tree.family.name}');
      }
      // Every family has two. Two paths where every node changes how the
      // attack behaves beat three where one is filler (2026-10-29; Mystic
      // had two from the start).
      const expectedPaths = 2;
      if (tree.paths.length != expectedPaths) {
        errors.add(
          '${tree.family.name} must have exactly $expectedPaths paths',
        );
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
          // Bought with the family's own mastery points, at the tier's
          // price.
          if (i < kFamilyMasteryTierCosts.length &&
              node.cost != kFamilyMasteryTierCosts[i]) {
            errors.add(
              '${node.id} must cost ${kFamilyMasteryTierCosts[i]} mastery',
            );
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
