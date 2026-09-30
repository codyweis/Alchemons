part of 'cosmic_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  COMPANION MOTION — how summoned Alchemons fly in open space
//
//  Once a frame, before the companion loop, [_planCompanionMotion] decides
//  what every companion is fighting and where it should be:
//
//   • Following, the party flies a loose formation behind the ship: one
//     trails it, two flank it, three make a V. Each place is stood off the
//     ship by that creature's own size, and places go to whoever is nearest
//     them, so after a hard turn the V opens round the ship instead of
//     everyone crossing through it and each other.
//   • Fighting, the companions on one target take fanned stations on the
//     ship's side of it, stood off its SURFACE (a boss is up to ~240 across),
//     and weave along that arc together, so they circle instead of parking.
//
//  [_steerCompanion] then flies each one at its goal with a velocity, goes
//  round the ship and round each other rather than through, and sidesteps a
//  charging boss or a boss shot about to land. There are three companions at
//  most, so this is a handful of vector sums a frame.
//
//  It replaced a wander orbit round an anchor pinned to the ship. That orbit
//  lerped every companion back toward the ship's centre each frame, which
//  (a) stacked all three on the ship and on each other, and (b) cancelled
//  their chase, so they parked 40–90 units from the ship and never got a
//  boss into range.
// ─────────────────────────────────────────────────────────────────────────────

/// What a companion is fighting this frame.
class _CompanionEngagement {
  const _CompanionEngagement({
    required this.target,
    required this.position,
    required this.hitRadius,
    required this.bodyRadius,
  });

  /// Identity, so the companions on one target can share its arc.
  final Object target;
  final Offset position;

  /// The target's hitbox: an attack reaches it this far from its centre.
  final double hitRadius;

  /// The room its body takes on screen, to stand off.
  final double bodyRadius;
}

extension CosmicGameCompanionMotion on CosmicGame {
  /// The ship's hull, for keeping companions off it.
  static const double _shipBodyRadius = 26.0;

  /// Open space between the ship's hull and a follower's body.
  static const double _followGap = 70.0;

  /// A companion's hitbox, as the boss shots test it.
  static const double _companionHitbox = 15.0;

  /// Formation places, as angles off straight behind the ship, by party size.
  static const List<List<double>> _formationSpread = [
    [0.0],
    [-0.62, 0.62],
    [-1.0, 0.0, 1.0],
  ];

  /// The creature's radius on screen. It fills about two thirds of its
  /// sprite frame, which is [CosmicGame.spriteBox] scaled by its family and
  /// its size genes.
  double _companionBodyRadius(CosmicCompanion comp) =>
      CosmicGame.spriteBox *
      comp.speciesScale *
      (comp.member.spriteVisuals?.scale ?? 1.0) *
      0.34;

  // ── planning ──────────────────────────────────────────────────────────────

  void _planCompanionMotion(double dt) {
    _trackShipMotion(dt);
    _companionEngagements.clear();
    _companionGoals.clear();

    final ringDuel =
        wildDuelActive && duelOpponent != null && duelOpponent!.isAlive;
    final slots = <int>[];
    for (final entry in activeCompanions.entries) {
      final comp = entry.value;
      if (!comp.isAlive) {
        comp.combatTarget = null;
        continue;
      }
      slots.add(entry.key);
      final engagement = _chooseCompanionEngagement(comp, ringDuel);
      comp.combatTarget = engagement?.target;
      if (engagement != null) _companionEngagements[entry.key] = engagement;
    }
    if (slots.isEmpty) return;
    slots.sort();

    // Followers make the formation among themselves; the companions on each
    // target share that target's arc.
    final followers = <int>[];
    final groups = <Object, List<int>>{};
    for (final slot in slots) {
      final e = _companionEngagements[slot];
      if (e == null) {
        followers.add(slot);
      } else {
        (groups[e.target] ??= <int>[]).add(slot);
      }
    }

    if (followers.isNotEmpty) {
      Offset place(int slot, int rank) => _followGoal(
        activeCompanions[slot]!,
        _companionBodyRadius(activeCompanions[slot]!),
        rank,
        followers.length,
      );
      final ranks = _assignPlaces(followers, place);
      for (var i = 0; i < followers.length; i++) {
        final slot = followers[i];
        _companionGoals[slot] = _keepGoalOffShip(
          place(slot, ranks[i]),
          _companionBodyRadius(activeCompanions[slot]!),
        );
      }
    }

    for (final group in groups.values) {
      final engagement = _companionEngagements[group.first]!;
      var groupBody = 0.0;
      for (final slot in group) {
        groupBody = max(
          groupBody,
          _companionBodyRadius(activeCompanions[slot]!),
        );
      }
      Offset station(int slot, int rank) {
        final comp = activeCompanions[slot]!;
        final body = _companionBodyRadius(comp);
        final goal = _combatGoal(
          comp,
          engagement,
          body: body,
          rank: rank,
          count: group.length,
          groupBody: groupBody,
        );
        // Whatever is still on the ship's hull (a bigger body than the
        // group's gap allowed for, the weave) slides round the arc off it,
        // which keeps its range to the target; pushing it straight off the
        // ship would not.
        return _slideIntoTetherAlongArc(
          _slideOffShipAlongArc(
            goal,
            engagement.position,
            body,
            current: comp.position,
          ),
          engagement.position,
          body,
        );
      }

      final ranks = _assignPlaces(group, station);
      for (var i = 0; i < group.length; i++) {
        final slot = group[i];
        _companionGoals[slot] = _keepGoalOffShip(
          station(slot, ranks[i]),
          _companionBodyRadius(activeCompanions[slot]!),
        );
      }
    }

    // Goals that would overlap push apart, so the party arrives at places
    // that clear each other rather than fighting over one. Each pass
    // re-applies the ship and tether limits, so a goal held at the tether's
    // end hands the rest of the gap to the other one instead of undoing it.
    for (var pass = 0; pass < 4; pass++) {
      for (var i = 0; i < slots.length; i++) {
        for (var j = i + 1; j < slots.length; j++) {
          final a = slots[i], b = slots[j];
          final ga = _companionGoals[a]!, gb = _companionGoals[b]!;
          final want =
              _companionBodyRadius(activeCompanions[a]!) +
              _companionBodyRadius(activeCompanions[b]!) +
              14;
          final delta = gb - ga;
          final dist = delta.distance;
          if (dist >= want) continue;
          final axis = dist > 0.5
              ? delta / dist
              : _tieBreakDirection(activeCompanions[b]!.member.instanceId);
          final shift = axis * ((want - dist) / 2);
          _companionGoals[a] = ga - shift;
          _companionGoals[b] = gb + shift;
        }
      }
      for (final slot in slots) {
        _companionGoals[slot] = _keepGoalOffShip(
          _companionGoals[slot]!,
          _companionBodyRadius(activeCompanions[slot]!),
        );
      }
    }
  }

  Offset _slideOffShipAlongArc(
    Offset goal,
    Offset center,
    double body, {
    required Offset current,
  }) {
    final clear = _shipBodyRadius + body + 18;
    if ((goal - ship.pos).distance >= clear) return goal;
    // Round the side of the ship the goal is on; dead on the line, the side
    // the companion already is.
    final line = ship.pos - center;
    var off = goal - center;
    var cross = line.dx * off.dy - line.dy * off.dx;
    if (cross.abs() < 1) {
      off = current - center;
      cross = line.dx * off.dy - line.dy * off.dx;
    }
    final dir = cross >= 0 ? 1.0 : -1.0;
    var rel = goal - center;
    final c = cos(0.08 * dir), s = sin(0.08 * dir);
    var g = goal;
    for (var i = 0; i < 20; i++) {
      rel = Offset(rel.dx * c - rel.dy * s, rel.dx * s + rel.dy * c);
      g = center + rel;
      if ((g - ship.pos).distance >= clear) break;
    }
    return g;
  }

  /// A station past the tether's end slides back round its arc toward the
  /// ship, rather than being clamped straight in, which on a big target can
  /// drag it through the target's body.
  Offset _slideIntoTetherAlongArc(Offset goal, Offset center, double body) {
    if (!companionTethered) return goal;
    const limit = CosmicGame._companionTetherHardRadius - 12;
    if ((goal - ship.pos).distance <= limit) return goal;
    final line = ship.pos - center;
    var rel = goal - center;
    final side = line.dx * rel.dy - line.dy * rel.dx;
    if (side.abs() < 1) return goal;
    final dir = side > 0 ? -1.0 : 1.0; // toward the ship's line
    final clear = _shipBodyRadius + body + 18;
    final c = cos(0.06 * dir), s = sin(0.06 * dir);
    var g = goal;
    for (var i = 0; i < 40; i++) {
      final next = Offset(rel.dx * c - rel.dy * s, rel.dx * s + rel.dy * c);
      final nextSide = line.dx * next.dy - line.dy * next.dx;
      // Never across the ship's line, and never onto its hull.
      if (nextSide * side <= 0) break;
      if ((center + next - ship.pos).distance < clear) break;
      rel = next;
      g = center + rel;
      if ((g - ship.pos).distance <= limit) break;
    }
    return g;
  }

  /// Half the angle, round the target, that the ship's hull blocks on a
  /// station arc of [radius] when the target is [targetToShip] from the
  /// ship; 0 when the arc passes clear of it.
  double _shipGapOnArc(double radius, double targetToShip, double body) {
    if (radius < 1 || targetToShip < 1) return 0;
    final clear = _shipBodyRadius + body + 18;
    final c =
        (radius * radius + targetToShip * targetToShip - clear * clear) /
        (2 * radius * targetToShip);
    if (c >= 1) return 0;
    return acos(c.clamp(-1.0, 1.0));
  }

  static const List<List<List<int>>> _placeOrders = [
    [
      [0],
    ],
    [
      [0, 1],
      [1, 0],
    ],
    [
      [0, 1, 2],
      [0, 2, 1],
      [1, 0, 2],
      [1, 2, 0],
      [2, 0, 1],
      [2, 1, 0],
    ],
  ];

  /// Which place (rank) each of [slots] takes: the order, of the at most
  /// six, that flies them the least in total, so a turn or a new fight
  /// never sends them crossing through each other. The order they already
  /// hold is kept unless another is clearly shorter, so two near-equal
  /// choices do not flicker.
  List<int> _assignPlaces(
    List<int> slots,
    Offset Function(int slot, int rank) placeFor,
  ) {
    final n = slots.length;
    if (n > _placeOrders.length) return [for (var i = 0; i < n; i++) i];
    final cost = [
      for (final slot in slots)
        [
          for (var r = 0; r < n; r++)
            (activeCompanions[slot]!.position - placeFor(slot, r)).distance,
        ],
    ];
    double total(List<int> order) {
      var t = 0.0;
      for (var i = 0; i < n; i++) {
        t += cost[i][order[i]];
      }
      return t;
    }

    var best = _placeOrders[n - 1].first;
    var bestCost = double.infinity;
    for (final order in _placeOrders[n - 1]) {
      final t = total(order);
      if (t < bestCost) {
        bestCost = t;
        best = order;
      }
    }
    final held = [for (final slot in slots) _companionPlaceRanks[slot] ?? -1];
    final heldValid =
        held.every((r) => r >= 0 && r < n) && held.toSet().length == n;
    if (heldValid && total(held) <= bestCost + 60) best = held;
    for (var i = 0; i < n; i++) {
      _companionPlaceRanks[slots[i]] = best[i];
    }
    return best;
  }

  /// The ship's velocity and the heading the follow formation hangs off.
  void _trackShipMotion(double dt) {
    final last = _lastShipPosForCompanions;
    _lastShipPosForCompanions = ship.pos;
    if (last == null) {
      _formationHeading = ship.angle;
      return;
    }
    if (dt <= 0) return;
    final step = _toroidalDelta(ship.pos, last);
    // A warp or a teleport is not flight.
    final raw = step.distance > 2500 * dt ? Offset.zero : step / dt;
    _shipVelocity = Offset.lerp(_shipVelocity, raw, min(1.0, 12 * dt))!;
    if (_shipVelocity.distance < 30) return;

    // Turn toward the flight direction at a capped rate. Places are handed
    // out by least travel (see [_assignPlaces]), so after a hard reverse the
    // V opens and flows past the ship on both sides rather than swinging
    // round it.
    var diff = atan2(_shipVelocity.dy, _shipVelocity.dx) - _formationHeading;
    while (diff > pi) {
      diff -= 2 * pi;
    }
    while (diff < -pi) {
      diff += 2 * pi;
    }
    final maxTurn = 5.0 * dt;
    _formationHeading += (diff * min(1.0, 7.0 * dt)).clamp(-maxTurn, maxTurn);
  }

  _CompanionEngagement? _chooseCompanionEngagement(
    CosmicCompanion comp,
    bool ringDuel,
  ) {
    final family = comp.member.family.toLowerCase();
    final acquire = _effectiveCombatAcquireRange(
      _combatAcquireRange(
        family: family,
        attackRange: comp.attackRange,
        specialRange: comp.specialAbilityRange,
      ),
    );
    final range = companionTethered && !ringDuel
        ? min(acquire, CosmicGame._companionTetherEngageRange)
        : acquire;

    // Mid-duel, the wild Alchemon comes first.
    if (ringDuel) {
      final opp = duelOpponent!;
      if ((opp.position - comp.position).distance < range) {
        return _CompanionEngagement(
          target: opp,
          position: opp.position,
          hitRadius: 15.0,
          bodyRadius: _companionBodyRadius(opp),
        );
      }
    }

    // Nearest by distance to its surface. The current target keeps a head
    // start, so two enemies at similar range do not trade places each frame.
    const stickiness = 90.0;
    final current = comp.combatTarget;
    Object? best;
    var bestScore = double.infinity;
    for (final e in enemies) {
      if (e.dead) continue;
      if (!_companionTetherAllowsTarget(e.position, radius: e.radius)) {
        continue;
      }
      final reach = (e.position - comp.position).distance - e.radius;
      if (reach > range) continue;
      final score = identical(e, current) ? reach - stickiness : reach;
      if (score < bestScore) {
        bestScore = score;
        best = e;
      }
    }
    final boss = activeBoss;
    if (boss != null &&
        !boss.dead &&
        _companionTetherAllowsTarget(boss.position, radius: boss.radius)) {
      final reach = (boss.position - comp.position).distance - boss.radius;
      if (reach <= range) {
        final score = identical(boss, current) ? reach - stickiness : reach;
        if (score < bestScore) best = boss;
      }
    }

    if (best is CosmicBoss) {
      return _CompanionEngagement(
        target: best,
        position: best.position,
        hitRadius: best.radius,
        bodyRadius: best.radius,
      );
    }
    if (best is CosmicEnemy) {
      return _CompanionEngagement(
        target: best,
        position: best.position,
        hitRadius: best.radius,
        bodyRadius: best.radius,
      );
    }
    return null;
  }

  /// Where a newly summoned companion's tear opens: its own place in the
  /// formation (the next one along), so it steps out beside the ship rather
  /// than on top of it or of the others.
  Offset _companionSummonPoint(CosmicCompanion comp) {
    final count = _livingActiveCompanions.length + 1;
    final spread = _formationSpread[(count - 1).clamp(0, 2)];
    final taken = <int>{};
    for (final slot in activeCompanions.keys) {
      final rank = _companionPlaceRanks[slot];
      if (rank != null && activeCompanions[slot]!.isAlive) taken.add(rank);
    }
    var rank = 0;
    while (rank < spread.length - 1 && taken.contains(rank)) {
      rank++;
    }
    return _formationPlace(_companionBodyRadius(comp), rank, count);
  }

  // ── goals ─────────────────────────────────────────────────────────────────

  Offset _followGoal(CosmicCompanion comp, double body, int rank, int count) {
    // Unlinked, it holds the ground it was left on.
    if (!companionTethered) return comp.anchorPosition + _companionBob(rank);
    return _formationPlace(body, rank, count) + _companionBob(rank);
  }

  /// Place [rank] of a [count]-strong formation behind the ship, for a body
  /// of radius [body].
  Offset _formationPlace(double body, int rank, int count) {
    final spread = _formationSpread[(count - 1).clamp(0, 2)];
    final offset = spread[rank.clamp(0, spread.length - 1)];
    // The point of a three-strong V trails a little further back.
    final trailing = count == 3 && rank == 1 ? 22.0 : 0.0;
    final radius = _shipBodyRadius + _followGap + body + trailing;
    final heading = _lastShipPosForCompanions == null
        ? ship.angle
        : _formationHeading;
    final a = heading + pi + offset;
    return ship.pos + Offset(cos(a), sin(a)) * radius;
  }

  Offset _combatGoal(
    CosmicCompanion comp,
    _CompanionEngagement e, {
    required double body,
    required int rank,
    required int count,
    required double groupBody,
  }) {
    final family = comp.member.family.toLowerCase();
    // Hold distance is measured from the target's surface, so the reach an
    // attack is checked against is the same whatever the target's size.
    final hold = _combatHoldDistance(
      family: family,
      attackRange: comp.attackRange,
      specialRange: comp.specialAbilityRange,
      basicCooldown: comp.basicCooldown,
      specialCooldown: comp.specialCooldown,
    );
    final longestReach = e.hitRadius + comp.attackRange - 8;
    final standoff = min(
      max(e.hitRadius + hold, e.bodyRadius + body * 0.6),
      max(longestReach, e.hitRadius + hold),
    );

    // Fight from the side the ship is on (or, unlinked, the side it was left
    // on), fanned across that arc and spaced by the biggest body in the
    // group so their sprites clear each other.
    final home = companionTethered ? ship.pos : comp.anchorPosition;
    var toHome = home - e.position;
    if (toHome.distance < 1) toHome = comp.position - e.position;
    final baseAngle = atan2(toHome.dy, toHome.dx);
    final step = ((2 * groupBody + 34) / max(standoff, 1.0)).clamp(0.38, 1.25);
    // When the arc runs through the ship (a ranged companion whose range is
    // about the target's distance from the ship), the ship takes the middle
    // of the fan and the places go out on alternate sides of it: the same
    // layout every frame, so no one has to pick a side and cross a
    // neighbour when it changes its mind.
    // (Not when the target is up against the ship: there is no arc to leave
    // a gap in, and the places would swing round it as it moves.)
    final shipGap =
        companionTethered &&
            toHome.distance > e.bodyRadius + _shipBodyRadius + 60
        ? _shipGapOnArc(standoff, toHome.distance, groupBody)
        : 0.0;
    final fan = shipGap > 0
        ? (rank.isEven ? -1.0 : 1.0) * (shipGap + (rank ~/ 2) * step)
        : (rank - (count - 1) / 2) * step;

    // The whole group weaves along the arc on one beat, so they circle the
    // target together and never cross. Round the ship's gap the swing stays
    // inside it, so a place never swings across the ship. Breathing only
    // ever draws them in, so it cannot carry them out of reach.
    final beat = _elapsed * 0.8 + (identityHashCode(e.target) % 628) / 100.0;
    final weaveReach = shipGap > 0
        ? min(_companionWeave(family), shipGap * 0.8)
        : _companionWeave(family);
    final weave = weaveReach * sin(beat);
    final breathe = 1.0 - 0.06 * (0.5 + 0.5 * sin(_elapsed * 1.3 + rank * 1.7));
    final a = baseAngle + fan + weave;
    return e.position + Offset(cos(a), sin(a)) * (standoff * breathe);
  }

  /// A small idle drift, so a companion at its place still looks alive.
  Offset _companionBob(int rank) => Offset(
    sin(_elapsed * 0.9 + rank * 2.1) * 9.0,
    cos(_elapsed * 0.7 + rank * 1.3) * 7.0,
  );

  Offset _keepGoalOffShip(Offset goal, double body) {
    var g = goal;
    final fromShip = g - ship.pos;
    final dist = fromShip.distance;
    final clear = _shipBodyRadius + body + 18;
    if (dist < clear) {
      final away = dist > 0.5
          ? fromShip / dist
          : Offset(cos(_formationHeading + pi), sin(_formationHeading + pi));
      g = ship.pos + away * clear;
    }
    // Never ask for a place the tether would drag it back from.
    if (companionTethered) {
      const limit = CosmicGame._companionTetherHardRadius - 12;
      final d = g - ship.pos;
      final dd = d.distance;
      if (dd > limit) g = ship.pos + d / dd * limit;
    }
    return g;
  }

  // ── steering ──────────────────────────────────────────────────────────────

  /// How long a summoned companion stands in its tear before it flies.
  static const double _emergeSeconds = 0.55;

  void _steerCompanion(int slot, CosmicCompanion comp, double dt) {
    final goal = _companionGoals[slot];
    if (goal == null || dt <= 0) return;
    if (comp.life < _emergeSeconds) {
      comp.steerGoal = goal;
      return;
    }
    final engagement = _companionEngagements[slot];
    final family = comp.member.family.toLowerCase();
    final body = _companionBodyRadius(comp);

    // Match the goal's own motion (the ship flying, the target circling) so
    // the companion keeps pace instead of trailing. A jump (a new target, a
    // new formation) is a new goal, not a fast one.
    var goalVel = Offset.zero;
    final lastGoal = comp.steerGoal;
    if (lastGoal != null) {
      final moved = goal - lastGoal;
      if (moved.distance < 1400 * dt) goalVel = moved / dt;
    }
    comp.steerGoal = goal;

    // If the straight line to the goal crosses the ship (the formation
    // swinging round after a hard turn) or the body of what it is fighting
    // (its station flipping to the far side as a boss dashes past), go round
    // instead of through. Round the ship it keeps pace with the ship rather
    // than with the swinging goal.
    // Each way round treats the other obstacle as a blocker, so going round
    // the ship never cuts through a boss parked against it, and vice versa.
    final shipAim = _routeRound(
      comp.position,
      goal,
      ship.pos,
      _shipBodyRadius + body + 4,
      blocker: engagement?.position,
      blockerClear: engagement == null ? 0 : engagement.bodyRadius + body * 0.6,
    );
    final targetAim = engagement == null
        ? null
        : _routeRound(
            comp.position,
            goal,
            engagement.position,
            engagement.bodyRadius + body * 0.6,
            blocker: ship.pos,
            blockerClear: _shipBodyRadius + body,
          );
    Offset? aim;
    if (shipAim != null && targetAim != null) {
      // Round whichever is in the way first.
      aim =
          (ship.pos - comp.position).distance <
              (engagement!.position - comp.position).distance
          ? shipAim
          : targetAim;
    } else {
      aim = shipAim ?? targetAim;
    }
    if (identical(aim, shipAim) && aim != null) goalVel = _shipVelocity;
    final toGoal = (aim ?? goal) - comp.position;
    final dist = toGoal.distance;
    final chase = _combatChaseSpeed(family, comp.member.statSpeed.toDouble());
    // The pace it closes a gap at; well off its place, it hurries.
    final cruise =
        (engagement == null
            ? max(chase * 1.3, 190.0)
            : max(chase * 1.6, 210.0)) +
        max(0.0, dist - 140.0) * 1.6;

    var desired = goalVel;
    if (dist > 0.5) desired += toGoal / dist * min(cruise, dist * 2.8);
    desired += _companionSpacing(
      comp,
      body,
      heading: dist > 20 ? toGoal / dist : null,
    );
    desired += _companionDodge(comp, body, family);

    comp.velocity +=
        (desired - comp.velocity) * min(1.0, _agility(family) * dt);
    final cap = goalVel.distance + cruise + 360.0;
    final speed = comp.velocity.distance;
    if (speed > cap) comp.velocity = comp.velocity / speed * cap;
    comp.position += comp.velocity * dt;
  }

  /// A waypoint round a circular obstacle at [center] when the straight line
  /// from [from] to [goal] would put the companion within [clear] of it;
  /// null when the way is clear. The waypoint is a step round the obstacle
  /// toward the goal's side, so the companion orbits it to its place rather
  /// than pressing through. If [blocker] (the ship) sits on the short way
  /// round, it goes the long way, rather than squeezing between the two.
  Offset? _routeRound(
    Offset from,
    Offset goal,
    Offset center,
    double clear, {
    Offset? blocker,
    double blockerClear = 0,
  }) {
    final seg = goal - from;
    final segLen2 = seg.dx * seg.dx + seg.dy * seg.dy;
    if (segLen2 < 1) return null;
    final rel = center - from;
    final t = (rel.dx * seg.dx + rel.dy * seg.dy) / segLen2;
    if (t <= 0 || t >= 1) return null;
    final off = from + seg * t - center;
    if (off.distance >= clear) return null;

    final fromCenter = from - center;
    final goalCenter = goal - center;
    final a1 = atan2(fromCenter.dy, fromCenter.dx);
    var diff = atan2(goalCenter.dy, goalCenter.dx) - a1;
    while (diff > pi) {
      diff -= 2 * pi;
    }
    while (diff < -pi) {
      diff += 2 * pi;
    }
    final r = max(clear + 14, min(fromCenter.distance, goalCenter.distance));
    if (blocker != null) {
      final toBlocker = blocker - center;
      if (toBlocker.distance < r + blockerClear) {
        var ab = atan2(toBlocker.dy, toBlocker.dx) - a1;
        while (ab > pi) {
          ab -= 2 * pi;
        }
        while (ab < -pi) {
          ab += 2 * pi;
        }
        // The blocker lies on the swept arc: take the other way round.
        final onArc = diff >= 0 ? ab > 0 && ab < diff : ab < 0 && ab > diff;
        if (onArc) diff -= diff.sign * 2 * pi;
      }
    }
    final a = a1 + diff.clamp(-0.7, 0.7);
    return center + Offset(cos(a), sin(a)) * r;
  }

  /// Push away from other companions closer than their two bodies, and off
  /// the ship's hull.
  Offset _companionSpacing(
    CosmicCompanion comp,
    double body, {
    Offset? heading,
  }) {
    var push = Offset.zero;
    for (final other in activeCompanions.values) {
      if (identical(other, comp) || !other.isAlive) continue;
      final delta = comp.position - other.position;
      final dist = delta.distance;
      final want = body + _companionBodyRadius(other) + 14;

      // One standing in the way: pass it on the side, rather than pressing
      // into it until the push-apart and the pull to the goal cancel out.
      if (heading != null) {
        final ahead = -delta.dx * heading.dx - delta.dy * heading.dy;
        final lookahead = want + 60;
        if (ahead > 0 && ahead < lookahead) {
          final lateral = -delta - heading * ahead;
          final lat = lateral.distance;
          if (lat < want) {
            final side = lat > 0.5
                ? -lateral / lat
                : Offset(-heading.dy, heading.dx);
            push += side * (280.0 * (1 - lat / want) * (1 - ahead / lookahead));
          }
        }
      }

      if (dist >= want) continue;
      // Summoned on the same spot: split them by a fixed per-creature angle.
      final away = dist > 0.5
          ? delta / dist
          : _tieBreakDirection(comp.member.instanceId);
      push += away * (600.0 * (1 - dist / want) + 40.0);
    }
    final fromShip = comp.position - ship.pos;
    final shipDist = fromShip.distance;
    final shipClear = _shipBodyRadius + body + 10;
    if (shipDist < shipClear) {
      final away = shipDist > 0.5
          ? fromShip / shipDist
          : _tieBreakDirection(comp.member.instanceId);
      push += away * (360.0 * (1 - shipDist / shipClear) + 40.0);
    }

    // The ship flying at it (a hard turn back through the formation): part
    // to the side and let it through, like stepping off a charge.
    final shipSpeed = _shipVelocity.distance;
    if (shipSpeed > 60) {
      final heading = _shipVelocity / shipSpeed;
      final along = fromShip.dx * heading.dx + fromShip.dy * heading.dy;
      if (along > 0 && along < shipClear + shipSpeed * 0.6) {
        final perp = fromShip - heading * along;
        final perpDist = perp.distance;
        final lane = shipClear + 12;
        if (perpDist < lane) {
          final side = perpDist > 0.5
              ? perp / perpDist
              : Offset(-heading.dy, heading.dx);
          push += side * ((shipSpeed + 120) * (1 - perpDist / lane));
        }
      }
    }
    return push;
  }

  Offset _tieBreakDirection(String id) {
    final a = (id.hashCode % 628) / 100.0;
    return Offset(cos(a), sin(a));
  }

  /// Step off a charging boss's line, and out of the path of a boss shot
  /// that would land within half a second. Late or slow, it still gets hit:
  /// it turns no faster than its family's agility.
  Offset _companionDodge(CosmicCompanion comp, double body, String family) {
    final boss = activeBoss;
    if (boss == null && bossProjectiles.isEmpty) return Offset.zero;
    final speed = family == 'horn' ? 240.0 : 340.0;
    var dodge = Offset.zero;

    if (boss != null && !boss.dead && boss.charging) {
      final dir = Offset(cos(boss.chargeAngle), sin(boss.chargeAngle));
      final rel = comp.position - boss.position;
      final along = rel.dx * dir.dx + rel.dy * dir.dy;
      final reach =
          boss.baseSpeed *
              CosmicBoss.chargeSpeedMultiplier *
              boss.chargeDashTimer +
          boss.radius +
          body;
      if (along > -boss.radius && along < reach) {
        final perp = rel - dir * along;
        final perpDist = perp.distance;
        final clear = boss.radius + body * 0.6 + 20;
        if (perpDist < clear) {
          final side = perpDist > 0.5
              ? perp / perpDist
              : Offset(-dir.dy, dir.dx);
          // Dead on the line either way is as short; off it, the near way.
          final way = perpDist < clear * 0.35
              ? _unCrowdedSide(comp, body, side)
              : side;
          dodge += way * (speed * (1.3 - perpDist / clear));
        }
      }
    }

    for (final bp in bossProjectiles) {
      final rel = comp.position - bp.position;
      if (rel.dx.abs() > 200 || rel.dy.abs() > 200) continue;
      final v = Offset(cos(bp.angle), sin(bp.angle)) * bp.speed;
      final vv = v.dx * v.dx + v.dy * v.dy;
      if (vv < 1) continue;
      final t = (rel.dx * v.dx + rel.dy * v.dy) / vv;
      if (t <= 0 || t > 0.5) continue;
      final miss = rel - v * t;
      final missDist = miss.distance;
      final hit = bp.radius + _companionHitbox + 8;
      if (missDist >= hit) continue;
      final side = missDist > 0.5
          ? miss / missDist
          : Offset(-v.dy, v.dx) / sqrt(vv);
      final way = missDist < hit * 0.35
          ? _unCrowdedSide(comp, body, side)
          : side;
      dodge += way * (speed * 0.8);
    }

    final d = dodge.distance;
    return d > speed ? dodge / d * speed : dodge;
  }

  /// For a companion dead on a threat's line, where either way off it is
  /// as short: take [side] unless it steps into a friend and the other way
  /// does not.
  Offset _unCrowdedSide(CosmicCompanion comp, double body, Offset side) {
    double crowd(Offset dir) {
      var c = 0.0;
      for (final other in activeCompanions.values) {
        if (identical(other, comp) || !other.isAlive) continue;
        final to = other.position - comp.position;
        final d = to.distance;
        final near = body + _companionBodyRadius(other) + 40;
        if (d < 0.5 || d > near) continue;
        c += max(0.0, (to.dx * dir.dx + to.dy * dir.dy) / d) * (1 - d / near);
      }
      return c;
    }

    return crowd(-side) + 0.05 < crowd(side) ? -side : side;
  }

  /// How quickly it turns its velocity toward what it wants, per second.
  double _agility(String family) => switch (family) {
    'horn' => 4.0,
    'mystic' => 4.5,
    'mane' || 'mask' || 'kin' => 5.0,
    'let' => 5.5,
    'wing' => 6.5,
    'pip' => 7.0,
    _ => 5.0,
  };

  /// How far (radians) it weaves along its arc round a target. Skirmishers
  /// range wide, bruisers hold their line.
  double _companionWeave(String family) => switch (family) {
    'wing' => 0.42,
    'pip' => 0.38,
    'let' => 0.30,
    'mystic' => 0.28,
    'mask' => 0.26,
    'kin' => 0.24,
    'mane' => 0.22,
    'horn' => 0.16,
    _ => 0.24,
  };

  // ── the wild Alchemon's side ──────────────────────────────────────────────

  /// Contact with the ship counts as a ram and opens the portal, so a wild
  /// Alchemon fighting a companion never walks into the ship on its own:
  /// the part of its step toward the ship is dropped. The ship can still
  /// fly into it.
  Offset _wildStepClearOfShip(Offset from, Offset to) {
    const keepOff = CosmicGame._wildContactRange + 30;
    final rel = to - ship.pos;
    final dist = rel.distance;
    if (dist >= keepOff || dist < 0.001) return to;
    final before = (from - ship.pos).distance;
    if (dist >= before) return to;
    return ship.pos + rel / dist * min(keepOff, before);
  }

  /// The companion a wild Alchemon fights: the nearest, held until another
  /// is clearly closer or it falls. Null when none is out (it fights the
  /// ship).
  CosmicCompanion? _pickWildDuelTarget(CosmicCompanion opp) {
    CosmicCompanion? best;
    var bestScore = double.infinity;
    for (final comp in _livingActiveCompanions) {
      var score = (comp.position - opp.position).distance;
      if (identical(comp, _wildDuelTargetCompanion)) score -= 110;
      if (score < bestScore) {
        bestScore = score;
        best = comp;
      }
    }
    _wildDuelTargetCompanion = best;
    return best;
  }
}
