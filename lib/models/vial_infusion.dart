// lib/models/vial_infusion.dart
//
// INFUSION: a vial set on its chamber's stand (screens/essence/vial_stand
// .dart) and steered with that chamber's essence before it is extracted.
// A vial takes only its own group's essence. Four steps, in order, each
// dearer than the last and dearer for a rarer vial:
//
//   NATURE   pour, and two natures come up: take one, or pour again
//   TINT     pour, and two tints come up: take one, or pour again
//   SIZE     pour, and one size comes up: keep it, or pour again
//   EXTRACT  pour, and it is drawn out as an egg with what was chosen
//
// What comes up is saved the moment it is poured for, so leaving and coming
// back cannot roll it again for free.

import 'dart:convert';
import 'dart:math';

import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';

enum InfusionStep { nature, tint, size, extract }

extension InfusionStepX on InfusionStep {
  String get label => switch (this) {
    InfusionStep.nature => 'NATURE',
    InfusionStep.tint => 'TINT',
    InfusionStep.size => 'SIZE',
    InfusionStep.extract => 'EXTRACT',
  };

  /// How many come up per pour.
  int get offers => switch (this) {
    InfusionStep.nature || InfusionStep.tint => 2,
    InfusionStep.size => 1,
    InfusionStep.extract => 0,
  };
}

/// Essence a Worn vial takes to fill at each step: a round thousand per
/// step, rising for the harder-won answers.
const Map<InfusionStep, int> kInfusionBaseCost = {
  InfusionStep.nature: 1000,
  InfusionStep.tint: 2000,
  InfusionStep.size: 3000,
  InfusionStep.extract: 4000,
};

/// A rarer vial costs this many times more at every step.
const Map<VialRarity, int> kInfusionRarityScale = {
  VialRarity.common: 1,
  VialRarity.uncommon: 2,
  VialRarity.rare: 4,
  VialRarity.legendary: 8,
  VialRarity.mythic: 12,
};

/// Each reroll of the SAME step costs this much more essence than the
/// pour before, scaled by rarity: the stand asks dearer answers more.
const int kInfusionRerollRise = 500;

/// What the [pours]th pour of [step] costs on a [rarity] vial. Pour 0 is
/// the first; each after it costs [kInfusionRerollRise] more essence,
/// scaled by rarity.
int infusionCost(InfusionStep step, VialRarity rarity, {int pours = 0}) =>
    (kInfusionBaseCost[step]! + pours * kInfusionRerollRise) *
    kInfusionRarityScale[rarity]!;

/// The tints a pour can bring up. Albino is never poured for (as no tint
/// mutation is ever albino), and normal is what a vial already is.
const List<String> kInfusionTints = ['warm', 'cool', 'vibrant', 'pale'];

/// The sizes a pour can bring up, weighted as the genetics weigh them.
const Map<String, int> kInfusionSizes = {
  'tiny': 1,
  'small': 3,
  'normal': 6,
  'large': 3,
  'giant': 1,
};

/// One vial on one chamber's stand.
class VialInfusion {
  const VialInfusion({
    required this.group,
    required this.rarity,
    required this.name,
    this.step = InfusionStep.nature,
    this.pours = 0,
    this.natureId,
    this.tint,
    this.size,
    this.offer = const [],
  });

  final ElementalGroup group;
  final VialRarity rarity;

  /// The vial's inventory name, so it can go back where it came from.
  final String name;

  final InfusionStep step;

  /// How many times essence has been poured at the current step so far.
  /// Each pour costs [kInfusionRerollRise] more than the one before.
  final int pours;

  final String? natureId, tint, size;

  /// What the last pour brought up at [step], waiting to be taken. Empty
  /// until it is poured for.
  final List<String> offer;

  /// What a pour would cost right now.
  int get stepCost => infusionCost(step, rarity, pours: pours);

  /// The essence it takes: its own group's, and only that.
  String get essenceBiomeId => groupIdFrom(group);

  VialInfusion copyWith({
    InfusionStep? step,
    int? pours,
    String? natureId,
    String? tint,
    String? size,
    List<String>? offer,
  }) => VialInfusion(
    group: group,
    rarity: rarity,
    name: name,
    step: step ?? this.step,
    pours: pours ?? this.pours,
    natureId: natureId ?? this.natureId,
    tint: tint ?? this.tint,
    size: size ?? this.size,
    offer: offer ?? this.offer,
  );

  /// Poured for at [step]: what comes up, and the pour count climbs.
  VialInfusion poured(Random rng) =>
      copyWith(offer: rollOffer(step, rng), pours: pours + 1);

  /// [id], one of [offer], taken: on to the next step with a fresh pour
  /// count.
  VialInfusion taken(String id) {
    assert(offer.contains(id));
    final next = InfusionStep.values[step.index + 1];
    return VialInfusion(
      group: group,
      rarity: rarity,
      name: name,
      step: next,
      pours: 0,
      natureId: step == InfusionStep.nature ? id : natureId,
      tint: step == InfusionStep.tint ? id : tint,
      size: step == InfusionStep.size ? id : size,
    );
  }

  static List<String> rollOffer(InfusionStep step, Random rng) =>
      switch (step) {
        InfusionStep.nature => _natures(rng),
        InfusionStep.tint => ([...kInfusionTints]..shuffle(rng)).sublist(0, 2),
        InfusionStep.size => [_size(rng)],
        InfusionStep.extract => const [],
      };

  static List<String> _natures(Random rng) {
    final first = NatureCatalogWeighted.weightedRandom(rng);
    final second = NatureCatalogWeighted.weightedRandom(
      rng,
      excludeIds: {first.id},
    );
    return [first.id, second.id];
  }

  static String _size(Random rng) {
    final total = kInfusionSizes.values.fold(0, (a, b) => a + b);
    var roll = rng.nextInt(total);
    for (final e in kInfusionSizes.entries) {
      roll -= e.value;
      if (roll < 0) return e.key;
    }
    return 'normal';
  }

  Map<String, dynamic> toJson() => {
    'group': group.name,
    'rarity': rarity.name,
    'name': name,
    'step': step.name,
    'pours': pours,
    'nature': ?natureId,
    'tint': ?tint,
    'size': ?size,
    'offer': offer,
  };

  String serialise() => jsonEncode(toJson());

  static VialInfusion? deserialise(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return VialInfusion(
        group: ElementalGroup.values.byName(m['group'] as String),
        rarity: VialRarity.values.byName(m['rarity'] as String),
        name: m['name'] as String,
        step: InfusionStep.values.byName(m['step'] as String),
        pours: (m['pours'] as num?)?.toInt() ?? 0,
        natureId: m['nature'] as String?,
        tint: m['tint'] as String?,
        size: m['size'] as String?,
        offer: [for (final o in (m['offer'] as List? ?? const [])) '$o'],
      );
    } catch (_) {
      return null;
    }
  }
}
