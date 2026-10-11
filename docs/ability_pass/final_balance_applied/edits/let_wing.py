# Main-tree edits for changes 6-8 (Let Fire, Let Dark, Wing co-beam). The
# experiment versions are knobs in levers_exp.py; these are the chosen values.
RT = 'lib/games/cosmic/cosmic_ability_runtime.dart'
GAME = 'lib/games/cosmic_survival/cosmic_survival_game.dart'
OPEN = 'lib/games/cosmic/cosmic_game_ability_pass.dart'
OPENWING = 'lib/games/cosmic/cosmic_game_wing.dart'
DUNGEON = 'lib/games/planet_dungeon/planet_dungeon_game.dart'


def edits(mode):
    if mode != 'main':
        return []
    E = []

    # ── Let Fire: the kill blast reaches twice the meteor's blast ──────────
    E.append((RT, """  static double letFireReach(Projectile p) => max(555.0, p.effectRadius * 3.0);""",
              """  static double letFireReach(Projectile p) =>
      p.effectRadius * kLetFireKillReach;

  /// Fire's kill blast reaches this many times the meteor's own blast. It was
  /// three times with a 555 px floor: most of the arena at every band, so a
  /// kill re-blasted the whole wave and Let Fire measured 5-6.5x the median
  /// special at every band. Trimming its damage barely moved that, because
  /// the blast already killed what it reached (ability pass, final balance,
  /// 2026-10-10).
  static const double kLetFireKillReach = 2.0;"""))

    # ── Let Dark: follow-ups on the anchored count curve, 1.4x the size ────
    E.append((RT, """  static int darkLetFollowupCount(double casterIntelligence) {
    return (2 + ((casterIntelligence - 0.5) / 4.5) * 3)
        .round()
        .clamp(2, 5)
        .toInt();
  }""",
              """  /// How many follow-up meteors a Dark Let's kill calls down: two from a weak
  /// caster, three from an average one, five from a perfect one, by
  /// Intelligence on the anchored count curve. It was a straight line that
  /// already read five at an average stat, so the volley never grew past P50
  /// (ability pass, final balance, 2026-10-10).
  static int darkLetFollowupCount(double casterIntelligence) =>
      scaledAbilityCount(
        casterIntelligence,
        atLow: 2,
        atAverage: 3,
        atPerfect: 5,
      );

  /// A follow-up lands this much bigger than the meteor that called it down.
  /// The board says twice as big; at twice, five of them covered the wave
  /// around every kill and Dark measured up to 4.5x the median special.
  static const double kDarkLetFollowupScale = 1.4;

  /// A follow-up's hit radius, from the meteor that called it down.
  static double darkLetFollowupRadius(Projectile source) =>
      max(3.5, source.radiusMultiplier * kDarkLetFollowupScale);

  /// A follow-up's drawn size: the same growth, so it looks as big as it hits.
  static double darkLetFollowupVisualScale(Projectile source) =>
      max(3.5, source.visualScale * kDarkLetFollowupScale);"""))
    E.append((GAME, """          // "Twice as big" per design.
          radiusMultiplier: max(3.5, source.radiusMultiplier * 2.0),
          visualScale: max(3.5, source.visualScale * 2.0),""",
              """          // Bigger than its parent, per design.
          radiusMultiplier: CosmicAbilityRuntime.darkLetFollowupRadius(source),
          visualScale: CosmicAbilityRuntime.darkLetFollowupVisualScale(source),"""))
    E.append((OPEN, """            // "Twice as big" per design — the same as survival.
            radiusMultiplier: max(3.5, source.radiusMultiplier * 2.0),
            visualScale: max(3.5, source.visualScale * 2.0),""",
              """            // Bigger than its parent, per design — the same as survival.
            radiusMultiplier: CosmicAbilityRuntime.darkLetFollowupRadius(
              source,
            ),
            visualScale: CosmicAbilityRuntime.darkLetFollowupVisualScale(
              source,
            ),"""))
    E.append((DUNGEON, """          skyfallDistance: drop.distance,
          radiusMultiplier: max(3.5, source.radiusMultiplier * 2.0),
          visualScale: max(3.5, source.visualScale * 2.0),""",
              """          skyfallDistance: drop.distance,
          radiusMultiplier: CosmicAbilityRuntime.darkLetFollowupRadius(source),
          visualScale: CosmicAbilityRuntime.darkLetFollowupVisualScale(source),"""))

    # ── Wing: a co-fired beam holds half as long ───────────────────────────
    E.append((RT, """abstract final class WingBeamRules {
  /// Live beams a game holds; the oldest goes when a new one would pass it.
  static const int beamCap = 14;
""",
              """abstract final class WingBeamRules {
  /// Live beams a game holds; the oldest goes when a new one would pass it.
  static const int beamCap = 14;

  /// A beam a Wing co-fires from an anchor (Earth's from the orb, Spirit's
  /// from the ship) holds for this share of the wing's own beam. A second
  /// full-length line doubled the cast, and Earth measured 2.7-3.7x the
  /// median special (ability pass, final balance, 2026-10-10).
  static const double coBeamLifeShare = 0.5;

  /// How long a co-fired beam of [d] holds.
  static double coBeamLife(WingBeamEffect d) => d.duration * coBeamLifeShare;
"""))
    E.append((GAME, """    this.anchorToOrb = false,
    this.anchorToShip = false,
  }) : life = descriptor.duration,""",
              """    this.anchorToOrb = false,
    this.anchorToShip = false,
  }) : life = anchorToOrb || anchorToShip
           ? WingBeamRules.coBeamLife(descriptor)
           : descriptor.duration,"""))
    E.append((OPENWING, """    this.anchor = _WingAnchor.caster,
  }) : life = descriptor.duration,""",
              """    this.anchor = _WingAnchor.caster,
  }) : life = anchor == _WingAnchor.caster
           ? descriptor.duration
           : WingBeamRules.coBeamLife(descriptor),"""))
    return E
