// lib/games/cosmic_survival/components/survival_fusion_ledger.dart
//
// The pause panel's FUSIONS: every surge fusion the run has seen a parent
// of, as one plain line "A + B → C", each part grey until it is done (a
// parent taken as far as it goes, the fusion taken). Words only, no art and
// no tutorial: it is there for planning a build, not to announce anything.

import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:flutter/material.dart';

import 'survival_hud.dart' show SurvivalInk;

class SurvivalFusionLedger extends StatelessWidget {
  const SurvivalFusionLedger({super.key, required this.powerUps});

  final PowerUpState powerUps;

  /// The recipes it lists: those with a parent the run has seen (on a
  /// draft card, or taken) that can still be made — or have been.
  static List<PowerUpDef> recipesFor(PowerUpState powerUps) => [
    for (final fusion in kFusionPowerUps)
      if (fusion.fusedFrom.any(powerUps.hasSeenFusionParent) &&
          powerUps.fusionStillPossible(fusion))
        fusion,
  ];

  @override
  Widget build(BuildContext context) {
    final recipes = recipesFor(powerUps);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final fusion in recipes)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _RecipeLine(fusion: fusion, powerUps: powerUps),
          ),
      ],
    );
  }
}

class _RecipeLine extends StatelessWidget {
  const _RecipeLine({required this.fusion, required this.powerUps});

  final PowerUpDef fusion;
  final PowerUpState powerUps;

  // Grey until done; a done parent in the ink, a taken fusion in brass.
  static const _pending = Color(0xFF6E6C68);
  static const _joint = SurvivalInk.plain;

  @override
  Widget build(BuildContext context) {
    final parents = fusionParents(fusion);
    final taken = powerUps.has(fusion.id);
    TextSpan part(String name, bool done, {Color lit = SurvivalInk.ink}) =>
        TextSpan(
          text: name,
          style: TextStyle(color: done ? lit : _pending),
        );
    final spans = <TextSpan>[
      for (var i = 0; i < parents.length; i++) ...[
        if (i > 0)
          const TextSpan(
            text: '  +  ',
            style: TextStyle(color: _joint),
          ),
        part(parents[i].name, powerUps.fusionParentDone(parents[i])),
      ],
      const TextSpan(
        text: '  →  ',
        style: TextStyle(color: _joint),
      ),
      part(fusion.name, taken, lit: SurvivalInk.brassGlow),
    ];
    return Semantics(
      label: [
        '${parents.map((p) => p.name).join(' and ')} make ${fusion.name}',
        if (taken) 'taken',
      ].join(', '),
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(children: spans),
          key: ValueKey('survival.fusions.${fusion.id}'),
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
