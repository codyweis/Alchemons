import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import K

KIN = 'lib/games/cosmic/kin_support_runtime.dart'
RT = 'lib/games/cosmic/cosmic_ability_runtime.dart'
GAME = 'lib/games/cosmic_survival/cosmic_survival_game.dart'
OPEN = 'lib/games/cosmic/cosmic_game_kin.dart'


def edits(mode):
    k = lambda n, d: K(mode, n, d)
    const = 'const' if mode == 'main' else 'final'
    E = []
    if mode == 'exp':
        E.append((KIN, """import 'horn_runtime.dart' show abilityHookScale;""",
                  """import 'horn_runtime.dart' show abilityHookScale;
import 'package:alchemons/games/shared/alchemon_combat_stats.dart' show knob;"""))

    E.append((KIN, """  static const double spiritWispLife = 60.0;
""",
              f"""  static const double spiritWispLife = 60.0;

  /// Tier 3's own attack: a shot at the nearest body this often for a kin
  /// at [spiritWispReferenceSpecial]...
  static {const} double spiritWispShotInterval = {k('kin.spirit.interval', 0.8)};

  /// ...a Kin's SPECIAL at the P50 band...
  static const int spiritWispReferenceSpecial = 50;

  /// ...for this share of the kin's SPECIAL.
  static {const} double spiritWispShotShare = {k('kin.spirit.share', 0.9)};

  /// Seconds between the wisp's shots for a kin of SPECIAL [power]. The wisp
  /// is a standing piece, so the recasts a stronger SPECIAL buys every other
  /// special arrive here as a faster shot instead — the same
  /// [alchemonSpecialPowerFactor] line the cadence reads.
  static double spiritWispShotIntervalFor(num power) =>
      spiritWispShotInterval *
      alchemonSpecialPowerFactor(spiritWispReferenceSpecial) /
      alchemonSpecialPowerFactor(power.round());

  /// What one wisp shot hits for, at the kin's SPECIAL [power].
  static double spiritWispShotDamage(num power) =>
      power * spiritWispShotShare;

  /// Tier 4: each kill the Spirit kin makes heals it for this share of its
  /// SPECIAL (the dungeon's wisp has always done the same).
  static const double spiritWispKillHealShare = 0.12;

  /// What a tier-4 wisp's kill heals its kin for, at the kin's SPECIAL
  /// [power]; nothing below tier 4.
  static double spiritWispKillHeal(Projectile? wisp, num power) =>
      wisp != null && wisp.effectCount >= 4
      ? power * spiritWispKillHealShare
      : 0.0;
"""))

    E.append((KIN, """  /// A new wisp orbiting the Spirit kin at [casterPos]. Tier 1 at spawn;
  /// it tiers up on the kin's kills.
  static Projectile spiritWisp(Offset casterPos, int? slot) {
    const orbitR = 56.0;
    return Projectile(""",
              """  /// A new wisp orbiting the Spirit kin at [casterPos]. Tier 1 at spawn;
  /// it tiers up on the kin's kills. [power] is the kin's SPECIAL, which its
  /// tier-3 shot hits off.
  static Projectile spiritWisp(Offset casterPos, int? slot, {num power = 0}) {
    const orbitR = 56.0;
    return Projectile("""))
    E.append((KIN, """      holdOrbit: true,
      followSourceCompanion: true,
      radiusMultiplier: 1.4,
      visualScale: 1.2,
      visualStyle: ProjectileVisualStyle.sigil,
      sourceSlotIndex: slot,
      abilityFamily: 'kin',
      // effectStacks = kill count, effectCount = current tier (1..4)
      effectStacks: 0,
      effectCount: 1,
    );
  }""",
              """      holdOrbit: true,
      followSourceCompanion: true,
      // A companion, not a shot: a body it brushes passes through it. It
      // used to be spent on its first contact like a bullet, so it died
      // before it could ever tier up and measured as doing nothing at all
      // (ability pass M16).
      piercing: true,
      radiusMultiplier: 1.4,
      visualScale: 1.2,
      visualStyle: ProjectileVisualStyle.sigil,
      sourceSlotIndex: slot,
      abilityFamily: 'kin',
      // Armed from tier 3 ([applySpiritWispTier]).
      turretDamage: spiritWispShotDamage(power),
      turretSpeedMultiplier: 1.1,
      turretHomingStrength: 2.4,
      // effectStacks = kill count, effectCount = current tier (1..4)
      effectStacks: 0,
      effectCount: 1,
    );
  }"""))
    E.append((KIN, """  /// Sets the wisp's form for [kills]: T1 just orbits, T2 draws aggro.
  /// (T3's attack and T4's heal are on the design board only.)
  static void applySpiritWispTier(Projectile wisp, int kills) {
    final tier = spiritWispTier(kills);
    if (wisp.effectCount == tier) return; // no change
    wisp.effectCount = tier;
    wisp.visualScale = 1.0 + 0.4 * (tier - 1);
    wisp.radiusMultiplier = 1.2 + 0.3 * (tier - 1);
    wisp.tauntRadius = tier >= 2 ? 160.0 + 30.0 * (tier - 2) : 0;
    wisp.tauntStrength = tier >= 2 ? 3.0 : 0;
  }""",
              """  /// Sets the wisp's form for [kills], per the design board: T1 just orbits,
  /// T2 draws aggro, T3 shoots at the nearest body ([spiritWispShotInterval];
  /// every mode's turret pass fires it), and T4 also heals the kin on its
  /// kills ([spiritWispKillHeal]).
  static void applySpiritWispTier(
    Projectile wisp,
    int kills, {
    num power = spiritWispReferenceSpecial,
  }) {
    final tier = spiritWispTier(kills);
    wisp.turretInterval = tier >= 3 ? spiritWispShotIntervalFor(power) : 0;
    if (wisp.effectCount == tier) return; // no change
    wisp.effectCount = tier;
    wisp.visualScale = 1.0 + 0.4 * (tier - 1);
    wisp.radiusMultiplier = 1.2 + 0.3 * (tier - 1);
    wisp.tauntRadius = tier >= 2 ? 160.0 + 30.0 * (tier - 2) : 0;
    wisp.tauntStrength = tier >= 2 ? 3.0 : 0;
  }"""))

    E.append((KIN, """import 'horn_runtime.dart' show abilityHookScale;""",
              """import 'horn_runtime.dart' show abilityHookScale;
import 'package:alchemons/games/shared/alchemon_combat_stats.dart'
    show alchemonSpecialPowerFactor;"""))
    E.append((GAME, """    KinSupport.applySpiritWispTier(wisp, comp.kinSpiritWispKills);""",
              """    KinSupport.applySpiritWispTier(
      wisp,
      comp.kinSpiritWispKills,
      power: comp.abilityAtk,
    );"""))

    # A piece can be armed after it is placed (the Spirit wisp at tier 3).
    E.append(('lib/games/cosmic/cosmic_data.dart', """  /// If > 0, orbiting projectile fires a turret shot every N seconds.
  final double turretInterval;

  /// Damage of each turret shot.
  final double turretDamage;""",
              """  /// If > 0, orbiting projectile fires a turret shot every N seconds. Not
  /// final: a piece can be armed after it is placed (the Kin Spirit wisp at
  /// tier 3), and re-powered by a recast.
  double turretInterval;

  /// Damage of each turret shot.
  double turretDamage;"""))

    # Shots a placed turret fires belong to its caster.
    E.append((RT, """    return Projectile(
      position: orb.position,
      angle: angle,
      element: orb.element,
      damage: orb.turretDamage,
      life: orb.element == 'Lightning' ? 1.15 : 1.7,""",
              """    return Projectile(
      position: orb.position,
      angle: angle,
      element: orb.element,
      damage: orb.turretDamage,
      // The shot is the caster's: credited to it, and filed as its special
      // rather than as an anonymous auto attack (a Mask Steam geyser's shots
      // were missing from its caster's damage, and fed a Blood world's tithe).
      sourceSlotIndex: orb.sourceSlotIndex,
      abilityFamily: orb.abilityFamily,
      life: orb.element == 'Lightning' ? 1.15 : 1.7,"""))

    # survival: power on spawn/refresh, heal on T4 kills
    E.append((GAME, """    if (existing != null) {
      existing.life = max(existing.life, KinSupport.spiritWispLife);
      return;
    }
    // Spawn a new wisp orbiting the spirit kin. Tier == 1 at spawn;
    // tier-up happens on the spirit kin's auto-kills.
    comp.kinSpiritWispKills = 0;
    _appendCompanionProjectile(
      KinSupport.spiritWisp(comp.position, comp.slotIndex),
    );""",
              """    if (existing != null) {
      existing.life = max(existing.life, KinSupport.spiritWispLife);
      existing.turretDamage = KinSupport.spiritWispShotDamage(comp.abilityAtk);
      return;
    }
    // Spawn a new wisp orbiting the spirit kin. Tier == 1 at spawn;
    // tier-up happens on the spirit kin's auto-kills.
    comp.kinSpiritWispKills = 0;
    _appendCompanionProjectile(
      KinSupport.spiritWisp(
        comp.position,
        comp.slotIndex,
        power: comp.abilityAtk,
      ),
    );"""))
    E.append((GAME, """      if (companion != null &&
          companion.member.family.toLowerCase() == 'kin' &&
          companion.member.element == 'Spirit') {
        companion.kinSpiritWispKills++;
      }""",
              """      if (companion != null &&
          companion.member.family.toLowerCase() == 'kin' &&
          companion.member.element == 'Spirit') {
        companion.kinSpiritWispKills++;
        final heal = KinSupport.spiritWispKillHeal(
          KinSupport.findSpiritWisp(companionProjectiles, companion.slotIndex),
          companion.abilityAtk,
        );
        if (heal > 0 && !companion.isDead) {
          companion.currentHp = min(
            companion.maxHp,
            companion.currentHp + heal.round(),
          );
        }
      }"""))

    # open space
    E.append((OPEN, """        KinSupport.applySpiritWispTier(wisp, k.kinSpiritWispKills);""",
              """        KinSupport.applySpiritWispTier(
          wisp,
          k.kinSpiritWispKills,
          power: c.abilityAtk,
        );"""))
    E.append((OPEN, """    if (member != null && _isKinMember(member) && member.element == 'Spirit') {
      (comp ?? g!).kinSpiritWispKills++;
    }""",
              """    if (member != null && _isKinMember(member) && member.element == 'Spirit') {
      (comp ?? g!).kinSpiritWispKills++;
      if (comp != null && comp.isAlive) {
        final heal = KinSupport.spiritWispKillHeal(
          KinSupport.findSpiritWisp(companionProjectiles, member.slotIndex),
          comp.abilityAtk,
        );
        if (heal > 0) {
          comp.currentHp = min(comp.maxHp, comp.currentHp + heal.round());
        }
      }
    }"""))
    E.append((OPEN, """        if (existing != null) {
          // Refresh its life so the wisp persists between casts.
          existing.life = max(existing.life, KinSupport.spiritWispLife);
        } else {
          c.kin.kinSpiritWispKills = 0;
          companionProjectiles.add(KinSupport.spiritWisp(c.position, c.slot));
        }""",
              """        if (existing != null) {
          // Refresh its life so the wisp persists between casts.
          existing.life = max(existing.life, KinSupport.spiritWispLife);
          existing.turretDamage = KinSupport.spiritWispShotDamage(c.abilityAtk);
        } else {
          c.kin.kinSpiritWispKills = 0;
          companionProjectiles.add(
            KinSupport.spiritWisp(c.position, c.slot, power: c.abilityAtk),
          );
        }"""))
    return E
