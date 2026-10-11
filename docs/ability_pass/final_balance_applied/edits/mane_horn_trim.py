import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import K, FINAL

MANE = 'lib/games/cosmic/mane_runtime.dart'
GAME = 'lib/games/cosmic_survival/cosmic_survival_game.dart'
OPENMANE = 'lib/games/cosmic/cosmic_game_mane.dart'
DUNGEON = 'lib/games/planet_dungeon/planet_dungeon_game.dart'
DATA = 'lib/games/cosmic/cosmic_data.dart'


def edits(mode):
    k = lambda n, d: K(mode, n, d)
    E = []
    if mode == 'exp':
        E.append((MANE, """import 'cosmic_data.dart';""",
                  """import 'cosmic_data.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart' show knob;"""))

    # ── Mane Lightning: the orb count reads the cast ───────────────────────
    lo = 'knob(\'mane.lightning.max\', 10).round()' if mode == 'exp' else str(int(FINAL.get('mane.lightning.max', 10)))
    E.append((MANE, """  static List<Projectile> lightningOrbs(
    Projectile base, {
    required Offset casterPos,
    required double angle,
    required Offset scatterCenter,
    required double scatterRadius,
    required Random rng,
    required Offset Function(Offset) clamp,
    int? slot,
  }) {
    final orbCount = 5 + rng.nextInt(6);""",
              f"""  /// How many orbs a cast places: the cast's own lane count, which the
  /// special sets from Beauty (5 weak, 7 average, 12 perfect), held to the
  /// board's 5-10. It used to be a roll of 5-10 whatever the caster, so the
  /// field never grew with stats, and once the stacking rule stopped its
  /// fields piling up (ability pass M7) it lost a third of its damage at
  /// perfect and read as an early-game special.
  static int lightningOrbCount(int castLanes) => castLanes.clamp(5, {lo});

  static List<Projectile> lightningOrbs(
    Projectile base, {{
    required Offset casterPos,
    required double angle,
    required Offset scatterCenter,
    required double scatterRadius,
    required Random rng,
    required Offset Function(Offset) clamp,
    required int count,
    int? slot,
  }}) {{
    final orbCount = lightningOrbCount(count);"""))
    E.append((GAME, """          specialProjectiles = ManeRuntime.lightningOrbs(
            specialProjectiles.first,
            casterPos: comp.position,""",
              """          specialProjectiles = ManeRuntime.lightningOrbs(
            specialProjectiles.first,
            count: specialProjectiles.length,
            casterPos: comp.position,"""))
    E.append((OPENMANE, """        final orbs = ManeRuntime.lightningOrbs(
          projectiles.first,
          casterPos: origin,""",
              """        final orbs = ManeRuntime.lightningOrbs(
          projectiles.first,
          count: projectiles.length,
          casterPos: origin,"""))
    E.append((DUNGEON, """      final orbCount = 5 + _combatRng.nextInt(6);""",
              """      final orbCount = ManeRuntime.lightningOrbCount(
        specialProjectiles.length,
      );"""))

    # ── Mane Fire: the count holds above an average caster ─────────────────
    # Not one of the eight validated changes: main mode applies it only when
    # final_values.json names a count.
    fp = "knob('mane.fire.perfect', 16).round()" if mode == 'exp' else str(int(FINAL.get('mane.fire.perfect', 16)))
    if mode == 'exp' or 'mane.fire.perfect' in FINAL:
      E.append((DATA, """      // Design board: "(3–8) fireballs shot out and travel fast." The count
      // is the ability, so it scales off Beauty across the whole fielded
      // band rather than nudging within the board's original range: four
      // from a weak creature, eight from an average one, sixteen from a
      // perfected one.
      final fireballCount = scaledAbilityCount(
        casterBeauty,
        atLow: 4,
        atAverage: 8,
        atPerfect: 16,
        potential: casterBeautyPotential,
      );""",
              f"""      // Design board: "(3–8) fireballs shot out and travel fast." Four from
      // a weak creature, eight from an average one — and no more past that.
      // It used to climb to sixteen at perfect, and the count multiplied the
      // payload and the cadence both: 5-7x the median special at every band,
      // the strongest in the game at perfect (ability pass M12, final
      // balance 2026-10-10). Past average the fan grows by cadence alone.
      final fireballCount = scaledAbilityCount(
        casterBeauty,
        atLow: 4,
        atAverage: 8,
        atPerfect: {fp},
        potential: casterBeautyPotential,
      );"""))

    # ── Horn: a taunting pull keeps its authored reach ─────────────────────
    cond = "knob('horn.pullfix', 0) > 0.5 && hornZoneHoldsReach(p)" if mode == 'exp' else 'hornZoneHoldsReach(p)'
    if mode == 'exp' or FINAL.get('horn.pullfix', 0) > 0.5:
        E.append((DATA, """      // The impact zone's own reach (Water's pull, Steam's geyser, Earth's
      // quake, Dust's cyclone, Dark's void) never moved with any stat.
      effectRadius: p.effectRadius * hornZoneReach(casterBeauty),""",
                  f"""      // The impact zone's own reach (Water's pull, Steam's geyser, Earth's
      // quake) never moved with any stat. A zone that taunts AND drags
      // (Dust's cyclone, Dark's void) keeps its authored reach.
      effectRadius:
          p.effectRadius *
          ({cond} ? 1.0 : hornZoneReach(casterBeauty)),"""))
        E.append((DATA, """double hornZoneReach(double beauty) =>
    scaledAbilityReach(beauty, atLow: 1.0, atAverage: 1.0, atPerfect: 1.65);""",
                  """double hornZoneReach(double beauty) =>
    scaledAbilityReach(beauty, atLow: 1.0, atAverage: 1.0, atPerfect: 1.65);

/// A Horn impact zone that taunts and drags at once — Dust's cyclone, Dark's
/// void — keeps its authored drag reach at every stat. The taunt already
/// hauls the wave onto the impact beside the orb; a wider drag on top of it
/// pulled more of the wave together there, and measured as less control and
/// less protection at perfect, not more (ability pass, Phase 2 review).
bool hornZoneHoldsReach(Projectile p) =>
    p.tauntRadius > 0 &&
    (p.tickEffect == AbilityEffectKind.pull ||
        p.tickEffect == AbilityEffectKind.blackHole);"""))

        hcond = "knob('horn.pullfix', 0) > 0.5 && hornZoneHoldsReach(p)" if mode == 'exp' else 'hornZoneHoldsReach(p)'
        if mode == 'exp':
            E.append(('lib/games/cosmic/horn_runtime.dart', """import 'cosmic_data.dart';""",
                      """import 'cosmic_data.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart' show knob;"""))
        E.append(('lib/games/cosmic/horn_runtime.dart', """    if (p.effectRadius > effectMax) {
      p.effectRadius = effectMax;
    }""",
                  f"""    // A zone that taunts and drags keeps an average horn's cap
    // ([hornZoneHoldsReach]).
    final cap = {hcond} ? HornRules.burstEffectMax : effectMax;
    if (p.effectRadius > cap) {{
      p.effectRadius = cap;
    }}"""))

    # ── balance trims (data) ───────────────────────────────────────────────
    if mode == 'exp':
        E.append((DATA, """  damage *= kSpecialBalanceTrim['${family.toLowerCase()}/$element'] ?? 1.0;""",
                  """  damage *= knob(
    'trim.${family.toLowerCase()}/$element',
    kSpecialBalanceTrim['${family.toLowerCase()}/$element'] ?? 1.0,
  );"""))
    else:
        trims = FINAL.get('trims')
        if trims:
            body = ''.join(f"  '{a}': {v}, // {c}\n" for a, v, c in trims)
            E.append((DATA, """const Map<String, double> kSpecialBalanceTrim = {
  'wing/Dark': 0.66, //  4.6x → 3.1x (boss): the double-cadence laser
  'mane/Plant': 0.71, // 4.2x → 3.7x (boss)
  'mane/Earth': 0.88, // 3.6x → 2.7x (boss)
};""", "const Map<String, double> kSpecialBalanceTrim = {\n" + body + "};"))
    return E
