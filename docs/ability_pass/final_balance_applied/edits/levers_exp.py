# EXPERIMENT-ONLY knobs for the kill-limited standouts (trims did not move them).
RT = 'lib/games/cosmic/cosmic_ability_runtime.dart'
GAME = 'lib/games/cosmic_survival/cosmic_survival_game.dart'
DATA = 'lib/games/cosmic/cosmic_data.dart'


def edits(mode):
    if mode != 'exp':
        return []
    E = []
    E.append((RT, """import 'horn_runtime.dart' show hornStatScale;""",
              """import 'horn_runtime.dart' show hornStatScale;
import 'package:alchemons/games/shared/alchemon_combat_stats.dart' show knob;"""))
    # Let Fire: kill blast reach
    E.append((RT, """  static double letFireReach(Projectile p) => max(555.0, p.effectRadius * 3.0);""",
              """  static double letFireReach(Projectile p) => max(knob('let.fire.floor', 555.0), p.effectRadius * knob('let.fire.k', 3.0));"""))
    # Let Dark: follow-up count on the anchored curve, follow-up size
    E.append((RT, """  static int darkLetFollowupCount(double casterIntelligence) {
    return (2 + ((casterIntelligence - 0.5) / 4.5) * 3)
        .round()
        .clamp(2, 5)
        .toInt();
  }""",
              """  static int darkLetFollowupCount(double casterIntelligence) {
    if (knob('let.dark.anchored', 0) > 0.5) {
      return scaledAbilityCount(casterIntelligence, atLow: 2, atAverage: knob('let.dark.avg', 3).round(), atPerfect: 5);
    }
    return (2 + ((casterIntelligence - 0.5) / 4.5) * 3)
        .round()
        .clamp(2, 5)
        .toInt();
  }

  static double darkLetFollowupRadius(Projectile source) => max(3.5, source.radiusMultiplier * knob('let.dark.radius', 2.0));"""))
    E.append((GAME, """          radiusMultiplier: max(3.5, source.radiusMultiplier * 2.0),""",
              """          radiusMultiplier: CosmicAbilityRuntime.darkLetFollowupRadius(source),"""))
    # Mane Plant: an explosion does not re-arm the root tag
    E.append((GAME, """          other.maneRootSlot = enemy.maneRootSlot;
          other.maneRootTimer = max(other.maneRootTimer, 1.4);
          other.slowTimer = max(other.slowTimer, 1.4);""",
              """          if (knob('mane.plant.nochain', 0) < 0.5) {
            other.maneRootSlot = enemy.maneRootSlot;
            other.maneRootTimer = max(other.maneRootTimer, 1.4);
          }
          other.slowTimer = max(other.slowTimer, 1.4);"""))
    # Mane Dark: pull / eat reach
    E.append((DATA, """              pierceEffect: AbilityEffectKind.blackHole,
              effectPower: damage * 0.55,
              effectRadius: 180,
              effectDuration: 1.5,
              // Survival per-frame hook reads snareRadius as the pull
              // radius for the traveling void bolt.
              snareRadius: 180,""",
              """              pierceEffect: AbilityEffectKind.blackHole,
              effectPower: damage * 0.55,
              effectRadius: knob('mane.dark.reach', 180),
              effectDuration: 1.5,
              // Survival per-frame hook reads snareRadius as the pull
              // radius for the traveling void bolt.
              snareRadius: knob('mane.dark.reach', 180),"""))
    # Mane Fire: average count
    E.append((DATA, """        atLow: 4,
        atAverage: 8,
        atPerfect: knob('mane.fire.perfect', 16).round(),""",
              """        atLow: 4,
        atAverage: knob('mane.fire.avg', 8).round(),
        atPerfect: knob('mane.fire.perfect', 16).round(),"""))
    # Wing Dark: a pulse
    E.append((DATA, """  final duration = element == 'Lightning'
      ? 3.2
      : (1.8 + effectiveIntelligence * 0.10).clamp(1.6, 3.4);""",
              """  final duration = element == 'Lightning'
      ? 3.2
      : (1.8 + effectiveIntelligence * 0.10).clamp(1.6, 3.4) * (element == 'Dark' ? knob('wing.dark.pulse', 1.0) : 1.0);"""))
    # Wing co-beams (Earth's orb beam, Spirit's ship beam)
    E.append((GAME, """            origin: orb.position,
            angle: angle,
            anchorToOrb: true,
          ),
        );""",
              """            origin: orb.position,
            angle: angle,
            anchorToOrb: true,
          )..life *= knob('wing.cobeam', 1.0),
        );"""))
    E.append((GAME, """            origin: ship.position,
            angle: angle,
            anchorToShip: true,
          ),
        );""",
              """            origin: ship.position,
            angle: angle,
            anchorToShip: true,
          )..life *= knob('wing.cobeam', 1.0),
        );"""))
    # Mask Steam turret share
    E.append((DATA, """            turretDamage: damage * 0.75,""",
              """            turretDamage: damage * knob('mask.steam.turret', 0.75),"""))
    return E
