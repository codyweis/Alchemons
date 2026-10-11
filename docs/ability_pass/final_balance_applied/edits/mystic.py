import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import K, FINAL

STATS = 'lib/games/shared/alchemon_combat_stats.dart'
GAME = 'lib/games/cosmic_survival/cosmic_survival_game.dart'


def edits(mode):
    k = lambda n, d: K(mode, n, d)
    const = 'const' if mode == 'main' else 'final'
    E = []
    if mode == 'exp':
        E.append((STATS, """double mysticWorldHookProgress(double stat) => scaledAbilityValue(""",
                  """/// EXPERIMENT ONLY: tunables read from the harness's KNOBS env.
final Map<String, double> kBalanceKnobs = {};
double knob(String key, double fallback) => kBalanceKnobs[key] ?? fallback;

double mysticWorldHookProgress(double stat) => scaledAbilityValue("""))

    # ── the shared tempo curve ──────────────────────────────────────────────
    E.append((STATS, """//  A Mystic lights one world per deployment and the world keeps fixed clocks
//  (a player has to be able to count on the rhythm), so recasting buys it
//  nothing. Its SPECIAL buys intensity instead (user, 2026-10-10: "scale world
//  strength with SPECIAL so worlds hold about 2-3x at every band").""",
              """//  A Mystic lights one world per deployment, so recasting buys it nothing.
//  Its SPECIAL buys the world itself instead (user, 2026-10-10: "scale world
//  strength with SPECIAL so worlds hold about 2-3x at every band"): how hard a
//  damage world lands ([mysticWorldIntensity]) and how fast and how far it
//  works ([mysticWorldTempo]). A world's beat still holds steady for a given
//  creature, so a player can count on it; a stronger creature's beats faster."""))

    E.append((STATS, """/// A world quantity that should run from nothing to its full value across the
/// real stat band""",
              f"""/// The SPECIAL at which a damage world keeps its authored tempo: a Mystic's
/// SPECIAL at the P50 band (internal stats ≈4.3, level 10).
const int kMysticWorldTempoReferenceSpecial = 81;

/// How much faster — and, where a world works by covering ground, how much
/// wider — a damage world of [element] works at the caster's SPECIAL
/// ([abilityAtk]), relative to its authored tempo at P50.
///
/// A world's hits already kill most of what they reach at every band, so
/// landing harder ([mysticWorldIntensity]) buys it little. What the median
/// special gains from casts that come back about three times sooner, a world
/// gains here instead: a vine's lash and an ember's reignite come round
/// sooner, a revenant strikes sooner, the storm and the quake beat faster,
/// the tornado walks its circuit faster and the miasma spreads wider. The
/// curve is [alchemonSpecialPowerFactor]'s line, uncapped, normalised to 1 at
/// P50: about ×1.2 at P70, ×1.65 at P90 and ×2.4 at P100 + Enhancement 10
/// (ability pass, final balance, 2026-10-10). Control and support worlds keep
/// their own stat hooks and are not scaled here.
double mysticWorldTempo({{
  required String element,
  required int abilityAtk,
}}) {{
  if (!kMysticDamageWorlds.contains(element)) return 1.0;
  final curve =
      (1.0 + max(0, abilityAtk) / 30.0) /
      (1.0 + kMysticWorldTempoReferenceSpecial / 30.0);
  // A run's stat pickups keep raising SPECIAL; past about ×3 a world's beat
  // stops quickening before it turns into a continuous beam.
  return curve.clamp(0.6, 3.0).toDouble();
}}

/// A world quantity that should run from nothing to its full value across the
/// real stat band"""))

    # ── survival: the helper ────────────────────────────────────────────────
    E.append((GAME, """  /// ([mysticWorldIntensity]). Damage only: the surge above still owns counts,
  /// sizes and beats, and the clocks stay fixed.
  double _mysticWorldIntensity(CosmicSurvivalCompanion caster) =>
      mysticWorldIntensity(
        element: caster.member.element,
        abilityAtk: caster.abilityAtk,
      );""",
              """  /// ([mysticWorldIntensity]). Damage only: the surge above owns counts and
  /// sizes, and [_mysticWorldTempo] how fast and how far the world works.
  double _mysticWorldIntensity(CosmicSurvivalCompanion caster) =>
      mysticWorldIntensity(
        element: caster.member.element,
        abilityAtk: caster.abilityAtk,
      );

  /// How much faster (and, for a world that covers ground, wider) this
  /// Mystic's damage world works at its SPECIAL — 1 at P50
  /// ([mysticWorldTempo]).
  double _mysticWorldTempo(CosmicSurvivalCompanion caster) =>
      mysticWorldTempo(
        element: caster.member.element,
        abilityAtk: caster.abilityAtk,
      );

  /// Seconds between a clocked world's beats (the storm's strikes, the
  /// quake, the vents) for this caster: the authored beat, quickened by the
  /// world surge and by the caster's SPECIAL ([_mysticWorldTempo]). Divided
  /// rather than subtracted, so nothing can drive a beat to zero.
  double _mysticBeat(int slotIndex, CosmicSurvivalCompanion caster,
          double authored) =>
      authored / (_mysticWorldPower(slotIndex) * _mysticWorldTempo(caster));

  /// The beat [slotIndex]'s clocked world runs on right now, or null when it
  /// has none.
  @visibleForTesting
  double? mysticWorldBeat(int slotIndex) {
    final comp = activeCompanions[slotIndex];
    if (comp == null) return null;
    return switch (comp.member.element) {
      'Lightning' => _mysticBeat(slotIndex, comp, kMysticStrikeInterval),
      'Earth' => _mysticBeat(slotIndex, comp, kMysticQuakeInterval),
      'Steam' => _mysticBeat(slotIndex, comp, kMysticVentInterval),
      _ => null,
    };
  }"""))

    # ignition: the first beat comes on the same clock
    E.append((GAME, """        _mysticClock[slotIndex] = actsNow ? 0.0 : kMysticStrikeInterval;""",
              """        _mysticClock[slotIndex] = actsNow
            ? 0.0
            : _mysticBeat(slotIndex, comp, kMysticStrikeInterval);"""))
    E.append((GAME, """        _mysticClock[slotIndex] = actsNow ? 0.0 : kMysticQuakeInterval;""",
              """        _mysticClock[slotIndex] = actsNow
            ? 0.0
            : _mysticBeat(slotIndex, comp, kMysticQuakeInterval);"""))
    E.append((GAME, """        _mysticClock[slotIndex] = actsNow ? 0.0 : kMysticVentInterval;""",
              """        _mysticClock[slotIndex] = actsNow
            ? 0.0
            : _mysticBeat(slotIndex, comp, kMysticVentInterval);"""))

    E.append((GAME, """  /// Seconds between a Lightning world's strikes, and between an Earth world's
  /// quakes. Fixed rather than stat-scaled: these are the weather's rhythm, and
  /// a player has to be able to count on it to play around it. Stats move the
  /// damage instead.
  static const double kMysticStrikeInterval = 10.0;
  static const double kMysticQuakeInterval = 15.0;""",
              f"""  /// Seconds between a Lightning world's strikes, and between an Earth world's
  /// quakes, at P50. These are the weather's rhythm, and a player has to be
  /// able to count on it to play around it, so for a given creature the beat
  /// holds steady; a stronger creature's world beats faster
  /// ([_mysticBeat]). A strike is a single bolt and a quake floors the whole
  /// arena, so how often they come is what sets how much each world is worth.
  static {const} double kMysticStrikeInterval = {k('m.lightning.beat', 10.0)};
  static {const} double kMysticQuakeInterval = {k('m.earth.beat', 15.0)};"""))

    E.append((GAME, """          final beat = kMysticStrikeInterval / _mysticWorldPower(slot);""",
              """          final beat = _mysticBeat(slot, comp, kMysticStrikeInterval);"""))
    E.append((GAME, """          final beat = kMysticQuakeInterval / _mysticWorldPower(slot);""",
              """          final beat = _mysticBeat(slot, comp, kMysticQuakeInterval);"""))
    E.append((GAME, """          final beat = kMysticVentInterval / _mysticWorldPower(slot);""",
              """          final beat = _mysticBeat(slot, comp, kMysticVentInterval);"""))

    # ── the per-world rates ────────────────────────────────────────────────
    E.append((GAME, """        r.strikeCooldown = 0.5;""",
              f"""        r.strikeCooldown = {k('m.spirit.strike', 0.5)} / _mysticWorldTempo(owner);"""))
    E.append((GAME, """        vine.cooldown = 0.9;""",
              f"""        vine.cooldown = {k('m.plant.lash', 0.9)} / _mysticWorldTempo(owner);"""))
    E.append((GAME, """        vine.cooldown = 0.72;""",
              f"""        vine.cooldown = {k('m.plant.thorn', 0.72)} / _mysticWorldTempo(owner);"""))
    E.append((GAME, """      twister.angle += twister.travelSpeed * twister.dt;""",
              """      // A stronger Mystic's tornado walks faster, so it sweeps more of the
      // field in the same time without losing the circuit the player tracks.
      twister.angle +=
          twister.travelSpeed * _mysticWorldTempo(owner) * twister.dt;"""))
    E.append((GAME, """  final double travelSpeed = 0.34;""",
              f"""  final double travelSpeed = {k('m.air.travel', 0.34)};"""))
    E.append((GAME, """        funnelRadius: 190.0 * scale,""",
              f"""        funnelRadius: {k('m.air.funnel', 190.0)} * scale,"""))
    if mode == 'exp':
        E.append((GAME, """        radius: 44.0 * scale,""",
                  f"""        radius: {k('m.poison.radius', 44.0)} * scale * pow(_mysticWorldTempo(owner), knob('m.poison.rexp', 1.0)),"""))
    elif FINAL.get('m.poison.rexp', 1.0) > 0:
        E.append((GAME, """        radius: 44.0 * scale,""",
                  f"""        // Spreads wider for a stronger Mystic: the wake is the world's reach.
        radius: {k('m.poison.radius', 44.0)} * scale * _mysticWorldTempo(owner),"""))
    else:
        E.append((GAME, """        radius: 44.0 * scale,""",
                  f"""        radius: {k('m.poison.radius', 44.0)} * scale,"""))
    # The miasma bites faster for a stronger Mystic.
    if mode == 'exp':
        E.append((GAME, """      pool.tick = 0.45;""",
                  """      pool.tick = knob('m.poison.tick', 0.45) / pow(_mysticWorldTempo(owner), knob('m.poison.texp', 0.0));"""))
    elif FINAL.get('m.poison.texp', 0.0) > 0:
        E.append((GAME, """      pool.tick = 0.45;""",
                  f"""      // Bites faster for a stronger Mystic ([mysticWorldTempo]).
      pool.tick = {k('m.poison.tick', 0.45)} / _mysticWorldTempo(owner);"""))
    # The host grows with the caster's SPECIAL.
    if mode == 'exp' or FINAL.get('m.spirit.captempo', 0) > 0:
        tempo = "(knob('m.spirit.captempo', 0) > 0.5 ? _mysticWorldTempo(owner) : 1.0)" if mode == 'exp' else '_mysticWorldTempo(owner)'
        E.append((GAME, """    final cap =
        (_maxMysticRevenants *
                (0.5 + 0.5 * mysticWorldHookProgress(intel)) *
                surge)
            .round()
            .clamp(5, _maxMysticRevenants);""",
                  f"""    // A stronger Mystic raises a bigger host ([mysticWorldTempo]), up to
    // twice the authored one.
    final cap =
        (_maxMysticRevenants *
                (0.5 + 0.5 * mysticWorldHookProgress(intel)) *
                surge *
                {tempo})
            .round()
            .clamp(5, _maxMysticRevenants * 2);"""))
    E.append((GAME, """        ember.reignite = 1.1;""",
              f"""        ember.reignite = {k('m.fire.reignite', 1.1)} / _mysticWorldTempo(owner);"""))
    E.append((GAME, """        fissure.cooldown = 4.0;""",
              f"""        // A crack rearms sooner for a stronger Mystic ([mysticWorldTempo]).
        fissure.cooldown = {k('m.lava.cd', 4.0)} / _mysticWorldTempo(owner);"""))
    E.append((GAME, """    const splash = 78.0;""",
              f"""    {'const' if mode == 'main' else 'final'} splash = {k('m.lightning.splash', 78.0)};"""))
    E.append((GAME, """        damage: max(2.0, comp.abilityAtk * 0.42 * scale),""",
              f"""        damage: max(2.0, comp.abilityAtk * {k('m.water.grind', 0.42)} * scale),"""))
    return E
