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
      _path('mane.assault', 'Twin Fang', 'Single-target pressure and kills', [
        ('Honed Pair', 'Narrow and strengthen the paired slashes.'),
        ('Crosscut', 'Dual hits add damage and an elemental payload.'),
        ('Predator Step', 'Basic kills empower the next cast.'),
        ('Blade Dance', 'A special makes the next five slash pairs return.'),
      ]),
      _path('mane.control', 'Tempest Claw', 'Wide elemental coverage', [
        ('Sweeping Claws', 'Trade focused damage for wider slashes.'),
        ('Rending Wake', 'Each slash carries a reduced elemental payload.'),
        ('Crosswind', 'Split-target hits apply additional payload pressure.'),
        ('Tempest Ring', 'Every fourth cast releases radial slashes.'),
      ]),
      _path('mane.resonance', 'War Rhythm', 'Basic-to-special cadence', [
        ('Measured Cuts', 'Dual hits build Rhythm.'),
        ('Rising Tempo', 'Rhythm improves cadence and payload strength.'),
        ('Crescendo', 'The special spends Rhythm to empower basics.'),
        ('Encore', 'A full-Rhythm special begins an extendable frenzy.'),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.let,
    chassis: 'One large, slow meteor built around deliberate heavy impact.',
    paths: [
      _path('let.assault', 'Falling Star', 'Direct hits and elite pressure', [
        ('Dense Core', 'Make the meteor slower, smaller, and heavier.'),
        ('Cratermaker', 'Direct hits prime the next Let impact.'),
        ('Terminal Velocity', 'Long travel increases impact damage.'),
        ('Extinction Event', 'Every fifth cast becomes a giant comet.'),
      ]),
      _path('let.control', 'Scatterfall', 'Fragments and persistent zones', [
        ('Shatterstone', 'Impacts scatter fragments into nearby enemies.'),
        ('Elemental Crater', 'Impacts deliver an area elemental payload.'),
        ('Lingering Fall', 'Impacts leave a short-lived elemental zone.'),
        ('Meteor Season', 'Every third impact calls down a small shower.'),
      ]),
      _path('let.resonance', 'Orbital Cycle', 'Aftershocks around specials', [
        ('Impact Memory', 'Direct hits build Orbit.'),
        ('Satellite Fire', 'Full Orbit adds a delayed strike to a basic.'),
        ('Convergence', 'The special converts Orbit into aftershocks.'),
        ('Second Impact', 'The special produces one simplified repeat.'),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.pip,
    chassis: 'Three fast spread darts built around precision and volume.',
    paths: [
      _path('pip.assault', 'Needlepoint', 'Converging target execution', [
        ('Tight Grouping', 'Narrow and slightly strengthen each volley.'),
        ('Pin Cushion', 'Full volleys stack Pins on one target.'),
        ('Pluck the Pins', 'Consume full Pins for a physical burst.'),
        ('Thousand Cuts', 'Repeated full volleys launch a focused echo.'),
      ]),
      _path('pip.control', 'Impossible Angles', 'Ricochet crowd pressure', [
        ('Bank Shot', 'The center dart ricochets to a new target.'),
        ('Split Decision', 'Side darts seek separate enemies.'),
        ('Trick Payload', 'Trick-shot hits carry an elemental payload.'),
        ('No Safe Angle', 'Every fifth cast bends six darts into targets.'),
      ]),
      _path('pip.resonance', 'Quickwork', 'Accuracy-driven firing windows', [
        ('Clean Volley', 'Full volleys build Tempo.'),
        ('Fast Hands', 'Tempo improves cadence or converts to damage.'),
        ('Cash Out', 'The special converts Tempo into extra darts.'),
        ('Overflow', 'Full Tempo creates a temporary evolved volley.'),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.mask,
    chassis: 'One fast piercing dart paired with persistent trap specials.',
    paths: [
      _path('mask.assault', 'Phantom Needle', 'Piercing priority damage', [
        ('Long Needle', 'Extend, accelerate, and strengthen the first hit.'),
        ('Through the Veil', 'Each pierced enemy strengthens the next hit.'),
        ('Chosen Victim', 'Mark elites and bosses for focused basics.'),
        ('Phantom Lance', 'Every fourth cast becomes a broad spectral lance.'),
      ]),
      _path('mask.control', 'Hexweaver', 'Marks that empower fixtures', [
        ('Inscribed Dart', 'The first target receives a persistent Sigil.'),
        ('Binding Script', 'Repeated Sigil hits trigger a payload.'),
        ('Prepared Ground', 'Transfer the Sigil into the next fixture.'),
        ('Haunted Ground', 'The empowered fixture fires spectral basics.'),
      ]),
      _path(
        'mask.resonance',
        'Grand Masquerade',
        'Misdirection and trap payoff',
        [
          ('False Face', 'Basics draw enemies toward Mask fixtures.'),
          ('Applause', 'Successful control grants temporary attack speed.'),
          ('Curtain Call', 'Controlled kills release reduced payloads.'),
          ('Grand Masquerade', 'Active fixtures echo every third basic.'),
        ],
      ),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.horn,
    chassis: 'One slow oversized projectile backed by charges and defenses.',
    paths: [
      _path('horn.assault', 'Breaker', 'Close-range armor destruction', [
        ('Heavy Head', 'Trade projectile speed for heavier damage.'),
        ('Sunder', 'Hits apply stacking physical vulnerability.'),
        ('Point Blank', 'Close hits gain damage and stagger.'),
        ('Siege Horn', 'Every fourth cast becomes an impact shell.'),
      ]),
      _path('horn.control', 'Bastion', 'Guard and projectile interception', [
        ('Guarded Shot', 'Basic casts accumulate a small shield.'),
        ('Hold the Line', 'Repel advancing enemies with a payload.'),
        ('Interposition', 'A full shield intercepts an incoming projectile.'),
        ('Countercharge', 'An interception primes a heavy countershot.'),
      ]),
      _path('horn.resonance', 'Stampede', 'Momentum-fed special impact', [
        ('Gather Momentum', 'Basic hits build Momentum.'),
        ('Rolling Weight', 'Momentum improves projectile and attack speed.'),
        ('Impact Reserve', 'Specials consume Momentum for greater effect.'),
        ('Unstoppable', 'Full Momentum transforms the next special window.'),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.wing,
    chassis: 'Two aligned long-range shots paired with elemental beams.',
    paths: [
      _path('wing.assault', 'Twin Lance', 'Converging long-range pressure', [
        ('Synchronized Flight', 'Align and slightly strengthen both shots.'),
        ('Rangefinder', 'Long-distance hits gain damage.'),
        ('Double Tap', 'Dual hits add damage and a payload.'),
        ('Twin Suns', 'Every fifth pair fuses into a homing lance.'),
      ]),
      _path('wing.control', 'Razor Horizon', 'Wide piercing lanes', [
        ('Open Wings', 'Fire outward and pierce one enemy per side.'),
        ('Crosscurrent', 'Pierced shots bend toward another target.'),
        ('Elemental Contrails', 'First pierces deliver reduced payloads.'),
        ('Razor Horizon', 'Every fourth pair draws a damaging line.'),
      ]),
      _path('wing.resonance', 'Beamweaver', 'Basics tune beam specials', [
        ('Sightline', 'Dual hits build Focus.'),
        ('Coherent Light', 'Focus improves range and payload strength.'),
        ('Beam Feed', 'Specials consume Focus for greater effect.'),
        ('Continuum', 'Full Focus leaves a reduced special echo.'),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.kin,
    chassis: 'A charged physical laser paired with team support specials.',
    paths: [
      _path('kin.assault', 'Overcharge', 'Offensive charged lasers', [
        ('Hot Coil', 'Charge faster at a reduced damage coefficient.'),
        ('Burn Through', 'The laser pierces an additional enemy.'),
        ('Critical Mass', 'A complete target lock adds damage and payload.'),
        ('Judgment Line', 'Every fourth charge becomes a wide overcharge.'),
      ]),
      _path('kin.control', 'Conduit', 'Marks and battlefield circuits', [
        ('Conductivity', 'Laser hits mark one target.'),
        ('Ground Path', 'Firing through the mark leaves a payload lane.'),
        ('Relay Point', 'Allies pulse damage through the marked target.'),
        ('Living Circuit', 'Support windows link multiple marked targets.'),
      ]),
      _path('kin.resonance', 'Aegis Relay', 'Laser-fed team support', [
        ('Guard Charge', 'Completed lasers shield the weakest ally or orb.'),
        ('Shared Current', 'Fresh shields briefly hasten their recipient.'),
        ('Blessing Reserve', 'Laser hits store power for the special.'),
        ('Guardian Relay', 'A full Reserve relays the element through allies.'),
      ]),
    ],
  ),
  FamilyMasteryTreeDef(
    family: CreatureFamily.mystic,
    chassis: 'Three spell bolts supporting a persistent world transformation.',
    paths: [
      _path('mystic.assault', 'Starcaller', 'Focused spell offense', [
        ('Aligned Stars', 'Narrow and slightly strengthen the volley.'),
        ('Conjunction', 'Full volleys add elemental damage and payload.'),
        ('Falling Sign', 'Repeated full volleys mark a target.'),
        ('The Stars Answer', 'Every fifth cast converges into a sigil.'),
      ]),
      _path('mystic.control', 'Worldshaper', 'Seed and awaken the arena', [
        ('Seed the Field', 'Every third cast leaves a dormant Seed.'),
        ('Local Omen', 'Seeds apply weak elemental control nearby.'),
        ('Awakening', 'The active world awakens existing Seeds.'),
        ('Living World', 'The active world grows temporary new Seeds.'),
      ]),
      _path('mystic.resonance', 'Covenant', 'Accuracy-driven party support', [
        ('Witness', 'Full volleys build persistent Insight.'),
        ('Shared Vision', 'Full Insight improves party range and targeting.'),
        ('Oath Fulfilled', 'The world converts Insight into a team boon.'),
        ('Worldbond', 'Full volleys pulse support through the active world.'),
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
