part of 'cosmic_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE BATTLE'S STRATEGY: what an element is good against, what lingers on
//  an Alchemon, and who draws the blows (the author, 2026-10-21: "burn
//  should cut healing in half. poison should be a dot. we should add the
//  typing mechanics … and fix taunts, interrupts as well")
//
//  • Typing. The game's own chart (games/shared/type_effectiveness.dart),
//    softened for a real-time fight: an element strong against another's
//    hits it [kBattleTypeStrong] as hard, one it is weak against
//    [kBattleTypeWeak]. Each blow is the creature's who struck it (the
//    battle's tally knows), so a pair's mixed elements each count.
//  • Burn. A Fire or Lava ability (not a basic attack) leaves its target
//    burning for [kBurnSeconds]: every heal it gets lands at half
//    (games/shared/burn_healing.dart — survival's enemies burn the same).
//  • Poison. A poison's harm comes over [kBattlePoisonSeconds] instead of at
//    once, and more of it adds on.
//  • Swapping out ends a burn and a poison: the bench is the cure.
//  • Interrupts. Frozen or stunned, an Alchemon's special waits
//    [kBattleInterruptSeconds] longer — once in [kBattleInterruptGap], so it
//    is never held down. Nothing takes away its basic attacks or its
//    special.
//  • Taunts. A Horn's taunt (and a decoy) draws the other side's Alchemons
//    near it onto the Horn, unless their player has picked a target with a
//    tap: the player's own choice always holds.
//
//  All battle-only: no creature's numbers change, and open space, survival
//  and the dungeons are as they were. No chance in any of it.
// ─────────────────────────────────────────────────────────────────────────────

/// A body slowed this hard is frozen or stunned (a freeze holds at 0.05, a
/// stun at 0.08; a root, at 0, holds it in place but does not interrupt).
const double _kBattleFrozenBelow = 0.09;

final GrainBatch _statusGrains = GrainBatch(4);

/// How often each rule came into a fight ([CosmicBattle.counts]).
class BattleStrategyCount {
  int burns = 0;
  double poisonHarm = 0;
  double healCut = 0;
  int interrupts = 0;
  double tauntSeconds = 0;
  double typeUp = 0;
  double typeDown = 0;
}

extension CosmicGameBattleStatus on CosmicGame {
  /// [enemy]'s stand-in, if it is a battle's (it carries a creature's
  /// health).
  _CombatBody? _battleBodyOf(CosmicEnemy enemy) {
    if (_battle == null) return null;
    final cb = _combatBodies[enemy];
    return cb != null && cb.carriesHealth ? cb : null;
  }

  /// A Fire or Lava ability — or a burn — landed on [enemy].
  void _battleBurn(CosmicEnemy enemy) => _battleBodyOf(enemy)?.burned = true;

  /// An ability of [element] landed on [enemy]: Fire and Lava burn.
  void _battleAbilityHit(CosmicEnemy enemy, String? element) {
    if (battleBurns(element)) _battleBurn(enemy);
  }

  /// [amount] of poison for [enemy], from [slot]: on a battle's body it is
  /// kept to come over time, and true; anywhere else false (it lands now).
  bool _battlePoison(CosmicEnemy enemy, double amount, int? slot) {
    final cb = _battleBodyOf(enemy);
    if (cb == null) return false;
    cb.poisoned += amount;
    if (slot != null) cb.poisonedBy = slot;
    return true;
  }

  /// How much harder the blows [body] took this turn landed, by who struck
  /// them: each creature's share of what the body lost at its element's
  /// matchup with [defender], what the side dealt as a whole at none.
  double _battleTypeFactor(BattleSide by, int body, String defender) {
    final credit = _battle!._turnCredit[body];
    var all = 0.0, weighted = 0.0;
    for (var a = 0; a < credit.length; a++) {
      final share = credit[a];
      if (share <= 0) continue;
      all += share;
      weighted +=
          share *
          (a < by.creatures.length
              ? battleTypeMultiplier(by.creatures[a].member.element, defender)
              : 1.0);
    }
    return all > 0 ? weighted / all : 1;
  }

  /// What [cb] carried from the other side's turn onto [c] besides the
  /// blows: a burn, a poison to come, a freeze's interrupt. [perPoint] is
  /// the body's units to the creature's health.
  void _battleCarryStatus(
    BattleSide side,
    BattleSide by,
    BattleCreature c,
    CosmicCompanion comp,
    _CombatBody cb,
    double perPoint,
  ) {
    final b = _battle!;
    if (cb.burned) {
      cb.burned = false;
      if (c.burnFor <= 0) b.counts.burns++;
      c.burnFor = kBurnSeconds;
    }
    if (cb.poisoned > 0) {
      final slot = cb.poisonedBy;
      final i = slot == null ? -1 : slot - battleSlotFor(by.index, 0);
      final type = i >= 0 && i < by.creatures.length
          ? battleTypeMultiplier(by.creatures[i].member.element, comp.member.element)
          : 1.0;
      // What is still to come, and the new, over the poison's length.
      final left = c.poisonFor * c.poisonDps;
      final more = cb.poisoned * perPoint * type;
      c
        ..poisonFor = kBattlePoisonSeconds
        ..poisonDps = (left + more) / kBattlePoisonSeconds
        ..poisonBy = i >= 0 && i < by.creatures.length ? i : c.poisonBy;
      cb
        ..poisoned = 0
        ..poisonedBy = null;
    }
    // Frozen or stunned: the special waits longer, once in a while.
    final body = cb.body;
    final frozen =
        body.slowTimer > 0 &&
        body.slowMultiplier > 0 &&
        body.slowMultiplier <= _kBattleFrozenBelow;
    if (frozen && c.interruptGap <= 0 && battleHasSpecial(comp.member)) {
      comp.specialCooldown = min(
        max(0.1, comp.effectiveSpecialCooldown),
        comp.specialCooldown + kBattleInterruptSeconds,
      );
      c
        ..interruptGap = kBattleInterruptGap
        ..interruptedAt = b.clock;
      b.counts.interrupts++;
      _spawnHitSpark(comp.position, const Color(0xFFBFE8FF));
    }
  }

  /// Each frame of the fight: poisons hurt, burns and the interrupts' gaps
  /// run down. A poison's harm is its giver's in the tally.
  void _tickBattleStatus(CosmicBattle b, double dt) {
    for (final side in b.sides) {
      final by = b.sides[1 - side.index];
      for (final c in side.creatures) {
        if (c.burnFor > 0) c.burnFor = max(0.0, c.burnFor - dt);
        if (c.interruptGap > 0) c.interruptGap = max(0.0, c.interruptGap - dt);
        if (c.poisonFor <= 0) continue;
        final step = min(dt, c.poisonFor);
        c.poisonFor -= step;
        final comp = c.body;
        if (comp == null || !comp.isAlive) continue;
        c.poisonCarry += c.poisonDps * step;
        final whole = c.poisonCarry.floor();
        if (whole <= 0) continue;
        c.poisonCarry -= whole;
        final before = comp.currentHp + comp.shieldHp;
        comp.takeAbilityDamage(whole);
        final lost = (before - (comp.currentHp + comp.shieldHp)).toDouble();
        c.damageTaken += lost;
        b.counts.poisonHarm += lost;
        final giver = c.poisonBy;
        if (giver != null && giver < by.creatures.length) {
          by.creatures[giver].damageDealt += lost;
        } else {
          _shareBattleLoss(by, lost);
        }
      }
    }
  }

  /// The share of a heal [c] gets now: overtime's, and half again while it
  /// burns.
  double _battleHealShare(BattleCreature c) =>
      _battle!.healNow * (c.burnFor > 0 ? kBurnHealingMultiplier : 1);

  /// The Alchemon of [foe] whose taunt draws [comp], if one does: the
  /// nearest live taunt (or decoy) of theirs it stands within reach of,
  /// whose caster is on the field and can be fought.
  CosmicCompanion? _battleTaunter(BattleSide foe, CosmicCompanion comp) {
    CosmicCompanion? best;
    var bestDist = double.infinity;
    for (final p in foe.projectiles) {
      if (p.life <= 0 || p.tauntRadius <= 0) continue;
      if (p.decoy && p.decoyHp <= 0) continue;
      final d = (p.position - comp.position).distance;
      if (d > p.tauntRadius * kBattleTauntReach || d >= bestDist) continue;
      final slot = p.sourceSlotIndex;
      if (slot == null) continue;
      final i = slot - battleSlotFor(foe.index, 0);
      if (i < 0 || i >= foe.creatures.length) continue;
      final caster = foe.creatures[i].body;
      if (caster == null || !caster.isAlive || !_battleArrived(caster)) {
        continue;
      }
      best = caster;
      bestDist = d;
    }
    return best;
  }

  /// A burn and a poison end when [c] leaves the field (to the bench, or
  /// fallen): the bench is the cure.
  void _clearBattleStatus(BattleCreature c) {
    c
      ..burnFor = 0
      ..poisonFor = 0
      ..poisonDps = 0
      ..poisonCarry = 0
      ..poisonBy = null;
  }

  /// What lingers on those on the field, drawn under their feet and round
  /// them: embers rising off one burning, drops of green falling off one
  /// poisoned. Grains in batches; no blur.
  void _paintBattleStatus(Canvas canvas) {
    final b = _battle!;
    final g = _statusGrains..clear();
    var any = false;
    for (final side in b.sides) {
      for (final c in side.onField) {
        final comp = c.body!;
        if (!comp.isAlive) continue;
        final r = _companionBodyRadius(comp);
        if (c.burnFor > 0) {
          any = true;
          for (var k = 0; k < 14; k++) {
            final phase = (_elapsed * (0.6 + 0.05 * (k % 5)) + k * 0.137) % 1;
            final a = k * 2.399963 + comp.member.slotIndex;
            final x = comp.position.dx + cos(a) * r * (0.5 + 0.4 * sin(k * 1.7));
            final y = comp.position.dy + r * 0.7 - phase * r * 2.1;
            g.add(phase < 0.5 ? 0 : 1, x, y);
          }
        }
        if (c.poisonFor > 0) {
          any = true;
          for (var k = 0; k < 10; k++) {
            final phase = (_elapsed * (0.45 + 0.04 * (k % 4)) + k * 0.191) % 1;
            final a = k * 2.399963 + comp.member.slotIndex * 1.3;
            final x = comp.position.dx + cos(a) * r * 0.75;
            final y = comp.position.dy - r * 0.4 + phase * phase * r * 1.6;
            g.add(phase < 0.6 ? 2 : 3, x, y);
          }
        }
      }
    }
    if (!any) return;
    g
      ..draw(canvas, 0, 2.6, const Color(0xFFFFB347))
      ..draw(canvas, 1, 2.0, const Color(0xCCE0603A))
      ..draw(canvas, 2, 2.4, const Color(0xFF8FD26A))
      ..draw(canvas, 3, 1.8, const Color(0x996FA84E));
  }
}
