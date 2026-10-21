part of 'cosmic_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE BATTLE, LIVE: two friends, two phones (docs/battle/live_pvp_design.md)
//
//  The host's phone runs the fight, as a fight against the computer runs:
//  the guest's side is side 1, played by the guest's taps as they come in
//  (applyRemoteBattleInput), or by the computer while the guest is away.
//  Its tape (battle_wire.dart) samples the fight and sends it.
//
//  The guest's phone runs the same fight as a replica. Its own side is side
//  0, so everything from the host comes turned half a turn. The host's
//  samples own who stands where, their health, shields and specials' waits,
//  who goes for whom and the end; the replica only draws: each special the
//  host cast is cast again here, from the host's origin, aim, target and
//  seed, in its caster's turn, so every projectile, beam and trap is drawn
//  by the real code. What those and the basic attacks hit here is for the
//  look only: the bodies they hit are set back each frame, and the host's
//  health is put back on after.
// ─────────────────────────────────────────────────────────────────────────────

/// A special the host cast, waiting for its caster's turn on the replica.
class _ReplicaCast {
  const _ReplicaCast(this.cast, this.at);

  final BattleCast cast;

  /// When the host cast it, on its timeline (ms).
  final int at;
}

/// A cast older than this on the playback's timeline is not drawn: its
/// caster has moved on.
const int _kReplicaCastStaleMs = 1500;

extension CosmicGameBattleLive on CosmicGame {
  // ── the host ────────────────────────────────────────────────────────────

  /// The guest's [input] on the host, for [side] (the guest's, side 1).
  /// It is taken in whether or not it could be done, so the guest knows it
  /// was heard; false when it could not.
  bool applyRemoteBattleInput(BattleInput input, {int side = 1}) {
    final b = _battle;
    if (b == null) return false;
    b.remoteApplied++;
    if (b.over) return false;
    return switch (input.kind) {
      BattleInputKind.focus => setBattleFocus(
        side,
        input.a < 0 ? null : input.a,
      ),
      BattleInputKind.fill => battleSummon(side, input.a),
      BattleInputKind.swap => battleSummon(side, input.a, spot: input.b),
      BattleInputKind.concede => concedeBattle(side),
    };
  }

  /// [side] goes for the other side's [creature] (null: whoever is
  /// nearest) — as said, not toggled as a tap on the floor is.
  bool setBattleFocus(int side, int? creature) {
    final b = _battle;
    if (b == null || b.over) return false;
    final s = b.sides[side];
    if (creature == null) {
      s.focus = null;
      return true;
    }
    final foe = b.sides[1 - side];
    if (creature < 0 || creature >= foe.creatures.length) return false;
    if (!foe.creatures[creature].onField) return false;
    s.focus = creature;
    return true;
  }

  /// The guest is away (their phone gone quiet) or back: while away the
  /// computer plays their side, and the fight goes on.
  void setBattleSideAway(int side, bool away) {
    final b = _battle;
    if (b == null) return;
    final s = b.sides[side];
    if (s.auto == away) return;
    s
      ..auto = away
      .._thinkT = 0
      .._focusT = 0;
  }

  /// [side] leaves the fight: the other side wins it.
  bool concedeBattle(int side) =>
      settleBattle(winner: 1 - side, end: BattleEnd.conceded);

  /// The fight stops with no result: the host is lost.
  void endBattleNoContest() => settleBattle(end: BattleEnd.noContest);

  /// The fight ends here, as [end] with [winner] (null: nobody), if it has
  /// not ended already: a concession, a player lost, or a replica told the
  /// end by the room when the stream never said it.
  bool settleBattle({int? winner, required BattleEnd end}) {
    final b = _battle;
    if (b == null || b.over) return false;
    b.result = BattleResult(winner: winner, end: end, at: b.clock);
    b._endedReal = b._real;
    return true;
  }

  /// Each frame on the host: what happened goes on the tape, and the tape
  /// samples and sends.
  void _tapeBattle(CosmicBattle b) {
    final tape = b.tape;
    if (tape == null) return;
    for (; b._logTaped < b.log.length; b._logTaped++) {
      final e = b.log[b._logTaped];
      tape.event(
        _wireKindOf(e.kind),
        e.side,
        e.creature,
        (e.real * 1000).round(),
        e.at,
        e.data,
      );
    }
    final r = b.result;
    if (r != null && !b._endTaped) {
      b._endTaped = true;
      tape.event(
        BattleWireKind.end,
        0,
        0,
        ((b._endedReal ?? b._real) * 1000).round(),
        r.at,
        _battleEnding(b).data,
      );
    }
    tape.frame((b._real * 1000).round(), () => _sampleBattle(b));
  }

  static BattleWireKind _wireKindOf(BattleEventKind kind) => switch (kind) {
    BattleEventKind.special => BattleWireKind.special,
    BattleEventKind.summon => BattleWireKind.summon,
    BattleEventKind.swap => BattleWireKind.swap,
    BattleEventKind.fall => BattleWireKind.fall,
    BattleEventKind.phoenix => BattleWireKind.phoenix,
  };

  /// The fight as it stands, for the guest.
  BattleSample _sampleBattle(CosmicBattle b) => BattleSample(
    at: (b._real * 1000).round(),
    clock: b.clock,
    timeScale: b.timeScale,
    applied: b.remoteApplied,
    sides: [
      for (final side in b.sides)
        BattleSideSample(
          spots: List.of(side.spots),
          swapsLeft: side.swapsLeft,
          focus: side.focus,
          auto: side.auto,
          creatures: [
            for (final c in side.creatures)
              if (c.body case final body?)
                BattleCreatureSample(
                  place: BattlePlace.field,
                  at: body.position - b.center,
                  hp: body.currentHp,
                  maxHp: body.maxHp,
                  shield: body.shieldHp,
                  cooldown: body.specialCooldown,
                  life: body.life,
                  faceRight: body.faceRight,
                  phoenixSpent: c.phoenixSpent,
                  burning: c.burning,
                  poisoned: c.poisoned,
                  interrupted:
                      c.interruptedAt >= 0 && b.clock - c.interruptedAt < 0.9,
                )
              else
                BattleCreatureSample(
                  place: c.fallen ? BattlePlace.fallen : BattlePlace.bench,
                  share: c.hpFraction,
                  cooldown: c.specialCooldown,
                  phoenixSpent: c.phoenixSpent,
                ),
          ],
        ),
    ],
  );

  /// How [b] ended, with who did what, for the guest's result card.
  BattleEnding _battleEnding(CosmicBattle b) {
    final r = b.result!;
    return BattleEnding(
      winner: r.winner,
      end: switch (r.end) {
        BattleEnd.fieldEmpty => BattleWireEnd.fieldEmpty,
        BattleEnd.timeUp => BattleWireEnd.timeUp,
        BattleEnd.conceded => BattleWireEnd.conceded,
        BattleEnd.noContest => BattleWireEnd.noContest,
      },
      tallies: [
        for (final side in b.sides)
          [
            for (final c in side.creatures)
              (c.damageDealt.round(), c.damageTaken.round(), c.healing.round()),
          ],
      ],
    );
  }

  // ── the guest ───────────────────────────────────────────────────────────

  /// A replica's own focus, shown at once ahead of the host: [creature] of
  /// the other side (null lets go), set by this phone's input numbered
  /// [input]. The host's word on it takes over once the fight on screen
  /// has that input.
  void predictBattleFocus(int? creature, int input) {
    final b = _battle;
    if (b == null || !b.isReplica || b.over) return;
    b
      .._predictedFocus = creature
      .._predictedFor = input;
    b.sides[0].focus = creature;
  }

  /// A replica's frame: the playback moves on by this phone's [dt], the
  /// host's fight as it was then is put on the floor, the host's specials
  /// that came due are cast in their casters' turns, and everything in
  /// flight moves, for the look.
  void _updateReplica(CosmicBattle b, double dt) {
    b._real += dt;
    final step = b.playback!.advance(dt * 1000);
    b.lastStep = step;
    final sample = step.sample;
    // Once it is over here, what is still in the air settles on its own.
    final fdt = step.fightDt > 0
        ? step.fightDt
        : (b.over ? dt * b.timeScale : 0.0);
    _elapsed += fdt;
    for (final side in b.sides) {
      for (final comp in side._leaving) {
        comp.returnTimer -= fdt;
      }
      side._leaving.removeWhere((c) => c.returnTimer <= 0);
      for (final c in side.onField) {
        _companionTickers[c.member.slotIndex]?.update(fdt);
      }
    }
    if (sample != null) {
      _replicaRoster(b, sample);
      _replicaState(b, sample);
      for (final e in step.events) {
        _replicaEvent(b, e, step.at);
      }
      for (final side in b.sides) {
        side._replicaCasts.removeWhere(
          (_, c) => step.at - c.at > _kReplicaCastStaleMs,
        );
      }
      if (!b.over && fdt > 0) {
        for (final side in b.sides) {
          final foe = b.sides[1 - side.index];
          for (final entry in side._bodies.entries) {
            _tickCombatBody(
              entry.value,
              entry.key,
              fdt,
              trailInto: foe.projectiles,
              trailSlot: battleSlotFor(foe.index, 0),
            );
          }
        }
        final first = b._frame.isEven ? 0 : 1;
        b._frame++;
        for (final i in [first, 1 - first]) {
          final side = b.sides[i];
          final foe = b.sides[1 - i];
          _battleTurn(side, foe, fdt);
          _settleReplicaBodies(foe);
        }
        _fizzleOffFloor();
      }
      // The host's, whatever was hit here.
      _replicaState(b, sample);
      _replicaRipples(b);
    }
    // The camera is this phone's own: it eases on the real clock, waiting
    // for the host or not.
    _frameBattle(dt);
    _tellBattleFloor(b, fdt);
    _ageBattleFx(fdt);
  }

  /// Who stands where, as the host has it: one gone to the bench goes back
  /// to it, one fallen falls, one brought on comes on.
  void _replicaRoster(CosmicBattle b, BattleSample sample) {
    for (var s = 0; s < b.sides.length; s++) {
      final side = b.sides[s];
      final want = sample.sides[s];
      final n = min(side.creatures.length, want.creatures.length);
      for (var i = 0; i < n; i++) {
        final c = side.creatures[i];
        final w = want.creatures[i];
        c.phoenixSpent = w.phoenixSpent;
        if (!w.onField && !c.onField) {
          c
            ..hpFraction = w.share
            ..specialCooldown = w.cooldown
            ..fallen = w.place == BattlePlace.fallen;
        }
      }
      for (var spot = 0; spot < kBattleFieldSpots; spot++) {
        final have = side.spots[spot];
        final now = spot < want.spots.length ? want.spots[spot] : null;
        if (have == now) continue;
        if (have != null) {
          final w = have < n ? want.creatures[have] : null;
          if (w?.place == BattlePlace.fallen) {
            _battleFall(side, spot);
          } else {
            _leaveBattle(side, spot);
            if (w != null) side.creatures[have].hpFraction = w.share;
          }
        }
        if (now != null && now < n && !side.creatures[now].onField) {
          final c = side.creatures[now];
          final w = want.creatures[now];
          c
            ..fallen = false
            ..hpFraction = w.maxHp > 0 ? w.hp / w.maxHp : 1
            ..specialCooldown = w.cooldown;
          _enterBattle(side, spot, now);
        }
      }
    }
  }

  /// Everything the host's sample says of those on the field, and of the
  /// sides, onto the replica's.
  void _replicaState(CosmicBattle b, BattleSample sample) {
    b
      ..clock = sample.clock
      ..timeScale = sample.timeScale
      ..replicaApplied = sample.applied;
    if (b._predictedFor >= 0 && sample.applied > b._predictedFor) {
      b._predictedFor = -1;
    }
    for (var s = 0; s < b.sides.length; s++) {
      final side = b.sides[s];
      final want = sample.sides[s];
      side
        ..swapsLeft = want.swapsLeft
        ..auto = want.auto
        ..focus = s == 0 && b._predictedFor >= 0
            ? b._predictedFocus
            : want.focus;
      for (final i in side.spots) {
        if (i == null || i >= want.creatures.length) continue;
        final w = want.creatures[i];
        final comp = side.creatures[i].body;
        if (comp == null || !w.onField) continue;
        comp
          ..position = b.center + w.at
          ..currentHp = w.hp
          ..maxHp = max(1, w.maxHp)
          ..shieldHp = w.shield
          ..life = w.life
          ..invincibleTimer = max(0.0, kBattleArrival - w.life)
          ..velocity = Offset.zero
          ..shoveGlide = Offset.zero;
        if (w.cooldown case final cd?) comp.specialCooldown = cd;
        if (w.faceRight case final face?) comp.faceRight = face;
        // What lingers, as the host has it: for the look and the HUD.
        final c = side.creatures[i];
        c
          ..burnFor = w.burning ? 1 : 0
          ..poisonFor = w.poisoned ? 1 : 0;
        if (w.interrupted && (b.clock - c.interruptedAt) > 0.9) {
          c.interruptedAt = b.clock;
        }
      }
    }
  }

  /// One of the host's events, come due on the replica at [now] (the
  /// playback's time).
  void _replicaEvent(CosmicBattle b, BattleWireEvent e, double now) {
    if (e.side < 0 || e.side >= b.sides.length) return;
    final side = b.sides[e.side];
    BattleEventKind? logged;
    switch (e.kind) {
      case BattleWireKind.special:
        logged = BattleEventKind.special;
        if (now - e.at <= _kReplicaCastStaleMs && e.data.length >= 6) {
          side._replicaCasts[e.creature] = _ReplicaCast(
            BattleCast.fromData(e.data),
            e.at,
          );
        }
      case BattleWireKind.summon:
        logged = BattleEventKind.summon;
      case BattleWireKind.swap:
        logged = BattleEventKind.swap;
      case BattleWireKind.fall:
        logged = BattleEventKind.fall;
      case BattleWireKind.phoenix:
        logged = BattleEventKind.phoenix;
        if (e.creature >= 0 && e.creature < side.creatures.length) {
          final c = side.creatures[e.creature];
          c.phoenixSpent = true;
          final kin = c.body;
          final f = e.data.isEmpty ? -1 : e.data.first;
          final fallen = f >= 0 && f < side.creatures.length
              ? side.creatures[f].body
              : null;
          if (kin != null) {
            _awakenOpenPhoenix(
              _KinCaster.companion(kin),
              (fallen ?? kin).position,
            );
          }
        }
      case BattleWireKind.end:
        if (b.over) return;
        final ending = BattleEnding.fromData(e.data);
        b.result = BattleResult(
          winner: ending.winner,
          end: switch (ending.end) {
            BattleWireEnd.fieldEmpty => BattleEnd.fieldEmpty,
            BattleWireEnd.timeUp => BattleEnd.timeUp,
            BattleWireEnd.conceded => BattleEnd.conceded,
            BattleWireEnd.noContest => BattleEnd.noContest,
          },
          at: e.clock,
        );
        b._endedReal = b._real;
        for (var s = 0; s < b.sides.length && s < ending.tallies.length; s++) {
          final cs = b.sides[s].creatures;
          final ts = ending.tallies[s];
          for (var i = 0; i < cs.length && i < ts.length; i++) {
            final (dealt, taken, healed) = ts[i];
            cs[i]
              ..damageDealt = dealt.toDouble()
              ..damageTaken = taken.toDouble()
              ..healing = healed.toDouble();
          }
        }
    }
    if (logged != null) {
      b.log.add(
        BattleEvent(e.clock, e.side, logged, e.creature, real: e.at / 1000),
      );
    }
  }

  /// A replica: [comp]'s special the host cast, if one is waiting, cast
  /// again from where and at what the host cast it, from its seed.
  void _replayDueCast(BattleSide side, CosmicCompanion comp) {
    final index = comp.member.slotIndex - battleSlotFor(side.index, 0);
    final waiting = side._replicaCasts.remove(index);
    if (waiting == null) return;
    final b = _battle!;
    final cast = waiting.cast;
    comp
      ..position = b.center + cast.origin
      ..angle = cast.angle;
    _castRng = Random(cast.seed);
    try {
      _castCompanionSpecial(comp, b.center + cast.target);
    } finally {
      _castRng = null;
    }
    if (index >= 0 && index < side.creatures.length) {
      side.creatures[index].lastSpecialAt = b.clock;
    }
    b.replayedCasts++;
    b.floor.special(cast.target, elementColor(comp.member.element), _elapsed);
  }

  /// A replica: what [side]'s bodies took here is the look of it only; they
  /// stand again, whole, where their creatures stand.
  void _settleReplicaBodies(BattleSide side) {
    for (final entry in side._bodies.entries) {
      final comp = entry.key;
      final cb = entry.value;
      cb.body
        ..health = _kCombatBodyHealth
        ..dead = false
        ..knockbackVelocity = Offset.zero
        ..position = comp.position;
      cb
        ..damageCarry = 0
        ..executes = 0
        ..from = comp.position
        // What lingers is the host's to say.
        ..burned = false
        ..poisoned = 0
        ..poisonedBy = null;
    }
  }

  /// A replica: the floor feels the host's blows, from the health each one
  /// on the field lost since the last frame.
  void _replicaRipples(CosmicBattle b) {
    final seen = <int>{};
    for (final side in b.sides) {
      for (final c in side.onField) {
        final comp = c.body!;
        final slot = comp.member.slotIndex;
        seen.add(slot);
        final now = comp.currentHp + comp.shieldHp;
        final was = b._replicaHealth[slot];
        b._replicaHealth[slot] = now;
        if (was == null || !_battleArrived(comp)) continue;
        final lost = was - now;
        if (lost > comp.maxHp * 0.02) {
          b.floor.hit(
            comp.position - b.center,
            elementColor(comp.member.element),
            (lost / (comp.maxHp * 0.12)).clamp(0.0, 1.0),
            _elapsed,
          );
        }
      }
    }
    b._replicaHealth.removeWhere((slot, _) => !seen.contains(slot));
  }
}
