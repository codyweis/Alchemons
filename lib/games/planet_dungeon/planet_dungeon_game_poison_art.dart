// lib/games/planet_dungeon/planet_dungeon_game_poison_art.dart
//
// THE VENOM MONASTERY, IN GLASS (docs/dungeons.md §7.11) — Poison's glass, as
// a part of planet_dungeon_game.dart.
//
// The monastery was already a built house — walls, bays, beds, flags, the
// wax on the doors (the 2026-09 art pass) — so it keeps its stone. What it
// gains is apothecary glass on the things that mean something:
//
//   · the prior's cross carries a rondel at its crossing, and that is where
//     THE DOSE is scored: one pane of the wisp's colour for each colour walked
//     home, the heart blooming white as the rite binds — and kept, on every
//     later descent. The maxim used to leave nothing at all;
//   · a relic socket at the cross's foot is a glass lens, the brew's colour
//     once a reliquary is set in it;
//   · the lustral font holds its water as a pane of glass, sick green until
//     the vial goes in and clear after.

part of 'planet_dungeon_game.dart';

const GlassPalette _kVenomGlass = kVenomGlass;

extension VenomMonasteryArt on PlanetDungeonGame {
  void _updateVenomGlass(double dt) {
    _tickPotRites(dt);
    final found = discoveredClouds.contains(kPoisonDoseEggId);
    final target = found || _ritePendingEgg == kPoisonDoseEggId ? 1.0 : 0.0;
    if (_doseHeart < 0) {
      _doseHeart = target;
    } else if (_doseHeart < target) {
      _doseHeart = min(target, _doseHeart + dt / 2.2);
    } else if (_doseHeart > target) {
      _doseHeart = target;
    }
  }

  /// THE DOSE, scored in glass at the cross's crossing. Three petals, one per
  /// colour the wisp must be walked home in — dark until that colour is home,
  /// then its own glass — round a heart that blooms white as the rite binds.
  /// Found, all of it stays lit.
  void _drawDoseRose(Canvas canvas, Offset c) {
    final found = discoveredClouds.contains(kPoisonDoseEggId);
    final home = found ? kWispOrder.length : monastery.wispStage;
    final heart = _doseHeart.clamp(0.0, 1.0);
    const r0 = 8.0, r1 = 20.0;
    final n = kWispOrder.length;
    paintRondel(
      canvas,
      c,
      r1 + 1,
      _kVenomGlass,
      fill: _kVenomGlass.smoke,
      rim: home > 0 ? 1.0 : 0.55,
    );
    for (var i = 0; i < n; i++) {
      final a0 = -pi / 2 + i * 2 * pi / n + 0.06;
      final a1 = a0 + 2 * pi / n - 0.12;
      final lit = i < home;
      final col = Color.lerp(elementColor(kWispOrder[i]), Colors.white, 0.15)!;
      paintPane(
        canvas,
        sectorPath(c, r0, r1, a0, a1),
        lit ? col : Color.lerp(_kVenomGlass.frostAt(i), col, 0.18)!,
        _kVenomGlass,
        lead: 1.8,
      );
      if (lit) {
        paintPaneFill(
          canvas,
          sectorPath(c, r0, r1, a0, a1),
          Colors.white,
          opacity: 0.06 + 0.05 * sin(_time * 1.6 + i * 2),
        );
      }
    }
    // The heart: the dose, taken.
    paintRondel(
      canvas,
      c,
      r0,
      _kVenomGlass,
      fill: heart > 0
          ? Color.lerp(_kVenomGlass.smoke, _kVenomGlass.silver, heart)!
          : _kVenomGlass.smoke,
      rim: heart > 0 ? 1.0 : 0.5,
      lead: 1.8,
    );
    if (heart > 0 && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        24 + 26 * heart,
        _kVenomGlass.silver.withValues(
          alpha: heart < 1 ? 0.45 * heart : 0.18 + 0.05 * sin(_time * 1.3),
        ),
      );
    }
  }

  /// A relic socket's lens: dark glass, and the brew's own colour once full.
  void _drawSocketLens(Canvas canvas, Offset at, Color? brew) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(1, 0.72);
    paintRondel(
      canvas,
      Offset.zero,
      7.5,
      _kVenomGlass,
      fill: brew ?? _kVenomGlass.smoke,
      rim: brew != null ? 1.0 : 0.5,
      lead: 1.6,
    );
    canvas.restore();
  }

  /// The font's water, as a pane of glass lying in the bowl.
  void _drawFontGlass(Canvas canvas, Rect bowl, Color water, bool clean) {
    final pane = Path()..addOval(bowl);
    paintPane(
      canvas,
      pane,
      water.withValues(alpha: clean ? 0.7 : 0.5),
      _kVenomGlass,
      lead: 2,
    );
    paintStreak(
      canvas,
      bowl.deflate(bowl.height * 0.2),
      opacity: clean ? 0.7 : 0.3,
    );
  }

  /// The bell ward's floor carries the bell's own mouth, cast in the stone
  /// under where it hangs; the scriptorium's, an illuminated border round
  /// the reading place. Carved, never glazed — decoration is stone (§7.11).
  void _renderWardInlay(Canvas canvas, DungeonRoom room) {
    final c = room.bounds.center;
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = const Color(0xFF0A0D09).withValues(alpha: 0.75);
    final lip = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4
      ..color = const Color(0xFF8A8A68).withValues(alpha: 0.22);
    void cut(Path p) {
      canvas.drawPath(p, groove);
      canvas.drawPath(p.shift(const Offset(0, 2)), lip);
    }

    switch (room.id) {
      case 'ward_bell':
        // The bell's mouth: a double rim, its lip notched where it was cast.
        for (final r in const [104.0, 88.0]) {
          cut(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
        }
        for (var i = 0; i < 12; i++) {
          final a = i / 12 * 2 * pi;
          cut(
            Path()
              ..moveTo(c.dx + cos(a) * 88, c.dy + sin(a) * 88)
              ..lineTo(c.dx + cos(a) * 104, c.dy + sin(a) * 104),
          );
        }
      case 'ward_scriptorium':
        // An illuminated border: a square frame with a knot at each corner.
        final r = Rect.fromCenter(center: c, width: 220, height: 170);
        cut(Path()..addRect(r));
        cut(Path()..addRect(r.deflate(12)));
        for (final k in [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft]) {
          cut(Path()..addOval(Rect.fromCircle(center: k, radius: 13)));
          cut(Path()..addOval(Rect.fromCircle(center: k, radius: 5)));
        }
    }
  }

  // ── THE ENTRANCE POT (2026-09-24) ───────────────────────
  // The quarantine door used to open to one Poison press. Now a pot stands
  // in the middle of the lazar gate and takes ONE gift from every hand in
  // the party — any element — and the draught it brews runs the wax off the
  // door. It is the planet's verb taught before it costs anything: none of
  // these gifts count against the brewing gives.

  Offset get _entrancePotAt {
    final b = layout.rooms[layout.entranceRoomId]!.bounds;
    return Offset(b.center.dx, b.center.dy + 10);
  }

  bool _tryEntrancePot(DungeonCreature a, DungeonRoom room) {
    final at = _entrancePotAt;
    if ((a.position - at).distance > _kMonasteryReach + 20) return false;
    final m = monastery;
    final id = a.member.instanceId;
    if (m.entryGiven.contains(id)) {
      final left = [
        for (final c in creatures)
          if (c.alive && !m.entryGiven.contains(c.member.instanceId))
            c.member.displayName,
      ];
      _setBlockedHint(
        '${a.member.displayName} has given. Still to give: ${left.join(', ')}.',
      );
      return true;
    }
    m.entryGiven.add(id);
    _spawnAlchemyBurst(
      at,
      producedElement: a.member.element,
      particleCount: 14,
      intensity: 0.8,
    );
    final all = creatures
        .where((c) => c.alive)
        .every((c) => m.entryGiven.contains(c.member.instanceId));
    if (!all) return true;
    // The last gift: the pot brews, and the door lets go.
    m.entryBrew = 1.0;
    entryDoorRevealed = true;
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId);
    speakConsequence(
      'The pot takes all of you and brews. The wax runs off the door.',
      3.6,
    );
    _spawnAlchemyBurst(
      at,
      producedElement: 'Poison',
      reagentElements: [for (final c in creatures) c.member.element],
      particleCount: 34,
      intensity: 1.3,
    );
    _shake = 4.0;
    return true;
  }

  void _drawEntrancePot(Canvas canvas) {
    final m = monastery;
    final c = _entrancePotAt;
    final open = entryDoorRevealed;
    // Coals, then the pot.
    canvas.drawOval(
      Rect.fromCenter(center: c + const Offset(0, 30), width: 96, height: 26),
      Paint()..color = const Color(0xFF3A1A0A).withValues(alpha: 0.9),
    );
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c + const Offset(0, 30),
        44,
        const Color(0xFFE07A2A).withValues(alpha: 0.35),
      );
    }
    final body = Rect.fromCenter(
      center: c + const Offset(0, 8),
      width: 92,
      height: 56,
    );
    canvas.drawOval(body, Paint()..color = const Color(0xFF1A1C16));
    final rim = Rect.fromCenter(
      center: c - const Offset(0, 8),
      width: 96,
      height: 30,
    );
    canvas.drawOval(rim, Paint()..color = const Color(0xFF2E3226));
    // The draught: one ring of colour per gift, the pot filling as you give.
    final givers = [
      for (final cr in creatures)
        if (m.entryGiven.contains(cr.member.instanceId)) cr.member.element,
    ];
    final surface = rim.deflate(6);
    if (givers.isEmpty && !open) {
      canvas.drawOval(surface, Paint()..color = const Color(0xFF0A0C08));
    } else {
      for (var i = 0; i < givers.length; i++) {
        final k = 1 - i / max(1, givers.length);
        canvas.drawOval(
          Rect.fromCenter(
            center: surface.center,
            width: surface.width * k,
            height: surface.height * k,
          ),
          Paint()..color = elementColor(givers[i]).withValues(alpha: 0.8),
        );
      }
      if (open && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          surface.center,
          50 + 30 * m.entryBrew,
          const Color(0xFF9CE06A).withValues(alpha: 0.3 + 0.4 * m.entryBrew),
        );
      }
    }
    canvas.drawOval(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = VenomMonasteryPuzzle._venomBronzeLit.withValues(alpha: 0.8),
    );
    // One pip per hand, lit in the colour of whoever gave.
    final hands = creatures.where((cr) => cr.alive).toList();
    for (var i = 0; i < hands.length; i++) {
      final at = c + Offset((i - (hands.length - 1) / 2) * 22, 50);
      final given = m.entryGiven.contains(hands[i].member.instanceId);
      canvas.drawCircle(at, 7, Paint()..color = const Color(0xFF0A0C08));
      canvas.drawCircle(
        at,
        5,
        Paint()
          ..color = given
              ? elementColor(hands[i].member.element)
              : const Color(0xFF2E3226),
      );
    }
    if (!open) {
      _drawTinyLabel(canvas, c + const Offset(0, 72), 'ONE GIFT FROM EACH');
    }
  }

  // ── THE BOIL-OVER (2026-09-24) ──────────────────────────
  // The party holds exactly the gives the four brews need. A brew made twice
  // (or a gift into a pot with nothing left to become) spends a hand another
  // brew cannot do without. That is allowed — mistakes are allowed — but the
  // house must never be left unfinishable. So the moment the gives left
  // cannot make the brews still wanted, the pot BOILS OVER: it heaves, the
  // bottles on the bench burst, and every gift not already poured into a
  // plague comes back. Plagues woken or slain stay so; the font stays open.

  static const double _kBoilSeconds = 2.6;
  static const double _kBoilBurst = 0.9;

  void _checkBrewStrand(DungeonRoom room) {
    final m = monastery;
    if (room.guardian != null || m.boilOver >= 0) return;
    if (_brewsStillFinishable()) return;
    m
      ..boilOver = 0
      ..boilApplied = false
      ..boilBottles = m.bottled.length + (m.carriedPotion != null ? 1 : 0);
    speakConsequence(
      'Not enough left to make what is still needed. The pot boils over, and '
      'every hand it took comes back.',
      4.4,
    );
    _shake = 5.0;
  }

  /// Can the gives still in the party, plus whatever is in the pot, make
  /// every brew the house still wants?
  bool _brewsStillFinishable() {
    final m = monastery;
    final need = <String, int>{};
    for (final p in kAllBrews) {
      if (_brewAlreadyMade(p)) continue;
      need[p.first] = (need[p.first] ?? 0) + 1;
      need[p.second] = (need[p.second] ?? 0) + 1;
    }
    final free = <String, int>{};
    for (final c in creatures) {
      final el = c.member.element;
      final left =
          contributionsAllowedFor(el) - (m.given[c.member.instanceId] ?? 0);
      free[el] = (free[el] ?? 0) + max(0, left);
    }
    final supply = Map<String, int>.from(free);
    for (final el in m.pot) {
      supply[el] = (supply[el] ?? 0) + 1;
    }
    for (final e in need.entries) {
      if ((supply[e.key] ?? 0) < e.value) return false;
    }
    // Something sitting in the pot that nothing needs will eat one gift from
    // whatever it is mixed with; there has to be a spare hand for that.
    if (m.pot.isNotEmpty && (need[m.pot.first] ?? 0) == 0) {
      final x = m.pot.first;
      return kPotionIngredientEffect.keys.any(
        (e) =>
            (e != x || e == 'Poison') && (free[e] ?? 0) - (need[e] ?? 0) >= 1,
      );
    }
    return true;
  }

  void _tickPotRites(double dt) {
    final m = monastery;
    if (m.entryBrew > 0) m.entryBrew = max(0, m.entryBrew - dt / 1.8);
    if (m.boilOver < 0) return;
    m.boilOver += dt;
    if (!m.boilApplied && m.boilOver >= _kBoilBurst) {
      m.boilApplied = true;
      _applyBoilOver();
    }
    if (m.boilOver >= _kBoilSeconds) m.boilOver = -1;
  }

  /// Back to where you were: every brew not yet poured is gone, and every
  /// gift that went into one comes back.
  void _applyBoilOver() {
    final m = monastery;
    final used = <String>{
      ...m.woken,
      ...m.slain,
      if (m.cloisterOpen) kPureVial.id,
    };
    m.bottled.clear();
    m.carriedPotion = null;
    m.pot.clear();
    m.potHands.clear();
    m.given.clear();
    m.potionHands.removeWhere((id, _) => !used.contains(id));
    for (final hands in m.potionHands.values) {
      for (final h in hands) {
        m.given[h] = (m.given[h] ?? 0) + 1;
      }
    }
  }

  /// The pot heaving over, and the bench's bottles bursting into shards.
  void _drawBoilOver(Canvas canvas, Offset pot, Offset bench) {
    final m = monastery;
    final t = m.boilOver / _kBoilSeconds;
    final fade = t > 0.7 ? max(0.0, 1 - (t - 0.7) / 0.3) : 1.0;
    // Foam heaving out of the pot in rings.
    for (var k = 0; k < 4; k++) {
      final ph = ((m.boilOver * 1.4 + k / 4) % 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: pot + const Offset(0, 10),
          width: 70 + ph * 150,
          height: 30 + ph * 60,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - ph)
          ..color = const Color(
            0xFF9CE06A,
          ).withValues(alpha: 0.6 * (1 - ph) * fade),
      );
    }
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        pot,
        90,
        const Color(0xFF7ACB3A).withValues(alpha: 0.35 * fade),
      );
    }
    // The bottles burst at the turn: shards flying out and falling.
    final since = m.boilOver - _kBoilBurst;
    if (since < 0 || m.boilBottles == 0) return;
    final g = since * 1.0;
    for (var b = 0; b < m.boilBottles; b++) {
      final origin = bench + Offset((b - (m.boilBottles - 1) / 2) * 26, -12);
      if (_fx.ready && since < 0.4) {
        drawGlow(
          canvas,
          _fx.glow!,
          origin,
          40,
          const Color(0xFFBFF0A0).withValues(alpha: 0.7 * (1 - since / 0.4)),
        );
      }
      for (var i = 0; i < 8; i++) {
        final a = i / 8 * 2 * pi + b;
        final v = Offset(cos(a), sin(a) - 0.6) * (90 + (i % 3) * 30.0);
        final p = origin + v * g + Offset(0, 260 * g * g);
        canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy - 4)
            ..lineTo(p.dx + 4, p.dy + 3)
            ..lineTo(p.dx - 3, p.dy + 2)
            ..close(),
          Paint()
            ..color = const Color(0xFFD8F0C8).withValues(alpha: 0.85 * fade),
        );
      }
    }
  }
}
