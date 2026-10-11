import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import K

PLACE = 'lib/games/cosmic/mask_trap_placement.dart'
GAME = 'lib/games/cosmic_survival/cosmic_survival_game.dart'
OPEN = 'lib/games/cosmic/cosmic_game_mask.dart'
SCREEN = 'lib/games/cosmic_survival/cosmic_survival_screen.dart'


def edits(mode):
    k = lambda n, d: K(mode, n, d)
    const = 'const' if mode == 'main' else 'final'
    E = []
    if mode == 'exp':
        E.append((PLACE, """import 'cosmic_data.dart';""",
                  """import 'cosmic_data.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart' show knob;"""))
    # The wisp carries its cast's clear threshold.
    E.append((PLACE, """  MaskSpiritWisp({
    required this.position,
    required this.sourceSlotIndex,
    required this.damage,
    required this.bobPhase,
    required this.life,
  });

  /// One wisp for a Spirit placement.
  factory MaskSpiritWisp.fromTrap(
    Projectile trap, {
    required int? sourceSlotIndex,
    required double bobPhase,
  }) => MaskSpiritWisp(
    position: trap.position,
    sourceSlotIndex: sourceSlotIndex,
    damage: trap.effectPower,
    bobPhase: bobPhase,
    life: max(8.0, trap.life),
  );""",
              """  MaskSpiritWisp({
    required this.position,
    required this.sourceSlotIndex,
    required this.damage,
    required this.bobPhase,
    required this.life,
    this.clearAt = 1,
  });

  /// One wisp for a Spirit placement that scattered [castSize] of them.
  factory MaskSpiritWisp.fromTrap(
    Projectile trap, {
    required int? sourceSlotIndex,
    required double bobPhase,
    required int castSize,
  }) => MaskSpiritWisp(
    position: trap.position,
    sourceSlotIndex: sourceSlotIndex,
    damage: trap.effectPower,
    bobPhase: bobPhase,
    life: max(8.0, trap.life),
    clearAt: maskSpiritClearThreshold(castSize),
  );"""))
    E.append((PLACE, """  final double damage;
  final double bobPhase;
  bool get dead => life <= 0;
}""",
              """  final double damage;
  final double bobPhase;

  /// How many banked wisps set off the clear when this one is taken: its
  /// cast's [maskSpiritClearThreshold].
  final int clearAt;
  bool get dead => life <= 0;
}"""))
    E.append((PLACE, """/// Wisps banked by one caster that set off its clear.
const int kMaskSpiritNukeThreshold = 6;""",
              f"""/// How many casts' worth of wisps one clear takes.
///
/// It was a flat six wisps, under the eight a single average cast scatters,
/// so every cast cleared the field on its own and Spirit measured 5.5-7x the
/// median special at every band, with nothing building. Banking across casts
/// is the ability's ramp ("faster progressed": it grows inside a run) — the
/// first casts of a deployment only fill the bank, and from then on a clear
/// lands every couple of casts. Counting in casts rather than wisps keeps that
/// rhythm the same for a weak caster's four wisps and a perfect one's
/// fourteen (ability pass, final balance, 2026-10-10).
{const} double kMaskSpiritCastsPerClear = {k('mask.spirit.k', 2.5)};

/// Wisps banked by one caster that set off its clear, for a cast that
/// scattered [castSize] of them.
int maskSpiritClearThreshold(int castSize) =>
    max(2, (kMaskSpiritCastsPerClear * max(1, castSize)).round());"""))

    # survival
    E.append((GAME, """  // Mask+Spirit special: ship-collected wisp count. Distinct from
  // `abilityKillStacks` (which counts auto-kills for the passive AOE).
  // Threshold reached → fires the non-boss nuke and resets to 0.
  int maskSpiritWispBank;""",
              """  // Mask+Spirit special: ship-collected wisp count. Distinct from
  // `abilityKillStacks` (which counts auto-kills for the passive AOE).
  // Threshold reached → fires the non-boss nuke and resets to 0. The bank
  // carries across casts: a clear takes several casts' worth of wisps
  // ([maskSpiritClearThreshold]); [maskSpiritClearAt] is the last cast's.
  int maskSpiritWispBank;
  int maskSpiritClearAt = 0;"""))
    E.append((GAME, """      case 'Spirit':
        for (final wisp in placements) {
          if (_spiritWisps.length >= kMaskSpiritWispCap) break;
          _spiritWisps.add(
            MaskSpiritWisp.fromTrap(
              wisp,
              sourceSlotIndex: slotIndex,
              bobPhase: _rng.nextDouble() * pi * 2,
            ),
          );
        }
        return true;""",
              """      case 'Spirit':
        comp?.maskSpiritClearAt = maskSpiritClearThreshold(placements.length);
        for (final wisp in placements) {
          if (_spiritWisps.length >= kMaskSpiritWispCap) break;
          _spiritWisps.add(
            MaskSpiritWisp.fromTrap(
              wisp,
              sourceSlotIndex: slotIndex,
              bobPhase: _rng.nextDouble() * pi * 2,
              castSize: placements.length,
            ),
          );
        }
        return true;"""))
    E.append((GAME, """        if (comp.maskSpiritWispBank >= kMaskSpiritNukeThreshold) {""",
              """        if (comp.maskSpiritWispBank >= wisp.clearAt) {"""))

    # open space
    E.append((OPEN, """          _maskSpiritWisps.add(
            MaskSpiritWisp.fromTrap(
              trap,
              sourceSlotIndex: seed.sourceSlotIndex,
              bobPhase: _rng.nextDouble() * pi * 2,
            ),
          );""",
              """          _maskSpiritWisps.add(
            MaskSpiritWisp.fromTrap(
              trap,
              sourceSlotIndex: seed.sourceSlotIndex,
              bobPhase: _rng.nextDouble() * pi * 2,
              castSize: placements.length,
            ),
          );"""))
    E.append((OPEN, """    if (bank >= kMaskSpiritNukeThreshold) {""",
              """    if (bank >= wisp.clearAt) {"""))
    E.append((OPEN, """  /// A wisp reached the collector. It banks for its caster only while the
  /// caster is still out; the sixth clears the field.""",
              """  /// A wisp reached the collector. It banks for its caster only while the
  /// caster is still out; a few casts' worth clears the field
  /// ([maskSpiritClearThreshold])."""))

    # the run panel's readout
    E.append((SCREEN, """    out.add(('Wisp bank', '${live.maskSpiritWispBank}/6'));""",
              """    out.add((
      'Wisp bank',
      live.maskSpiritClearAt > 0
          ? '${live.maskSpiritWispBank}/${live.maskSpiritClearAt}'
          : '${live.maskSpiritWispBank}',
    ));"""))
    return E
