part of 'cosmic_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  WILD ALCHEMONS IN SPACE
//
//  Real Alchemons drifting in the dark. Ram one and the ship tears a portal
//  around it (the screen pauses space and opens the encounter); fight one and
//  it fights back with its own family's abilities, using the duel machinery
//  the retired Battle Ring was built on. Beaten, it does not die — it drifts
//  exhausted for a while, the best moment to ram it, then recovers and goes.
//
//  The game only owns what happens in space. Picking a species, rolling its
//  genetics and running the encounter belong to the screen, which answers
//  [CosmicGame.onWildSpawnWanted] with [CosmicGameWild.addWildAlchemon].
// ─────────────────────────────────────────────────────────────────────────────

/// How a fight with a wild Alchemon ended.
enum WildDuelEnd {
  /// Brought to 0 HP. It collapses and drifts, exhausted.
  exhausted,

  /// The ship went down mid-fight. The creature leaves.
  shipDown,

  /// The ship flew off. The creature keeps the damage it took.
  disengaged,

  /// The ship rammed it mid-fight, which opens the portal.
  rammed,
}

enum SpaceWildState { grazing, dueling, exhausted }

class SpaceWildAlchemon {
  SpaceWildAlchemon({
    required this.id,
    required this.member,
    required this.rarity,
    required Offset position,
    this.territorial = false,
    double? driftAngle,
  }) : position = position,
       anchor = position,
       driftAngle = driftAngle ?? 0;

  final String id;

  /// Combat identity: stats, family, sprite and genetics visuals. Its
  /// Potentials are the ones the encounter will show and pass on.
  final CosmicPartyMember member;
  final String rarity;

  /// Territorial ones pick the fight themselves when the ship gets close.
  final bool territorial;

  Offset position;
  Offset anchor;
  double driftAngle;
  double driftTimer = 0;
  double life = 0;
  SpaceWildState state = SpaceWildState.grazing;

  /// Health carried between a fight and the encounter. 1 is untouched.
  double hpFraction = 1.0;
  double exhaustedTimer = 0;

  /// 0→1 on arrival, 1→0 while [leaving].
  double fade = 0;
  bool leaving = false;

  /// After a portal is closed without an attempt, the ship has to pull clear
  /// before touching it opens another one.
  bool needsSeparation = false;

  SpriteAnimationTicker? _ticker;
  double _spriteScale = 1.0;
  TextPainter? _potentialLabel;

  /// Half the drawn sprite's height, so the readout clears any family's size.
  double _halfHeight = 30;

  String get element => member.element;
  bool get isExhausted => state == SpaceWildState.exhausted;
}

/// Whatever a fought Alchemon is aiming at: the companion when one is out,
/// otherwise the ship itself.
class _WildDuelTarget {
  _WildDuelTarget(this.game, this.companion);

  final CosmicGame game;
  final CosmicCompanion? companion;

  bool get isShip => companion == null;
  Offset get position => companion?.position ?? game.ship.pos;
  int get physDef => companion?.physDef ?? 0;
  int get elemDef => companion?.elemDef ?? 0;

  void takeDamage(int damage) {
    final comp = companion;
    if (comp != null) {
      comp.takeDamage(damage);
      return;
    }
    // Companion-scale damage onto the ship's legacy 6-point pool: a basic
    // hit is a nick, a special a real bite, and the ship's own hit
    // invulnerability keeps a fast attacker from shredding it.
    game._damageShip((damage / 45.0).clamp(0.25, 0.9));
  }
}

/// A planet alone, centred in a [CosmicEncounterBackdrop.imageSize] square —
/// the encounter backdrop for a creature met beside it.
ui.Image renderPlanetBackdropImage(CosmicPlanet planet, {double elapsed = 0}) {
  const sz = CosmicEncounterBackdrop.imageSize;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, sz.toDouble(), sz.toDouble()),
  );
  _paintBackdropLayer(canvas, planet.color, () {
    canvas.translate(sz / 2, sz / 2);
    _paintPlanetForBackdrop(canvas, planet, elapsed);
  });
  final picture = recorder.endRecording();
  final image = picture.toImageSync(sz, sz);
  picture.dispose();
  return image;
}

/// Paints [body] into a layer that fades to nothing before the image edge
/// (the planet's aura is wider than the square, and a cut glow reads as a
/// seam once the image is scaled up), then lays a band of atmosphere over
/// the limb.
void _paintBackdropLayer(Canvas canvas, Color color, void Function() body) {
  const sz = CosmicEncounterBackdrop.imageSize;
  final full = Rect.fromLTWH(0, 0, sz.toDouble(), sz.toDouble());
  const c = Offset(sz / 2, sz / 2);
  canvas.saveLayer(full, Paint());
  canvas.save();
  body();
  canvas.restore();
  canvas.drawRect(
    full,
    Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = ui.Gradient.radial(
        c,
        sz / 2,
        [Colors.white, Colors.white, Colors.white.withValues(alpha: 0)],
        [0.0, 0.8, 1.0],
      ),
  );
  canvas.restore();

  const r = sz * CosmicEncounterBackdrop.planetRadiusFraction;
  const outer = r * 1.16;
  canvas.drawCircle(
    c,
    outer,
    Paint()
      ..shader = ui.Gradient.radial(
        c,
        outer,
        [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.30),
          color.withValues(alpha: 0.10),
          color.withValues(alpha: 0),
        ],
        // The limb sits at r / outer ≈ 0.86: glow peaks there, fades
        // inward over the surface and outward into space.
        const [0.74, r / outer, 0.93, 1.0],
      ),
  );
}

/// Expects the canvas origin at the image centre.
void _paintPlanetForBackdrop(Canvas canvas, CosmicPlanet p, double elapsed) {
  final target =
      CosmicEncounterBackdrop.imageSize *
      CosmicEncounterBackdrop.planetRadiusFraction;
  canvas.scale(target / p.radius);
  canvas.translate(-p.position.dx, -p.position.dy);
  // The art is shared with the planet in space; the backdrop is a still
  // portrait, so no wake of the ship parting its matter.
  final component = PlanetComponent(planet: p);
  final wake = component.art.wake;
  component.art.wake = null;
  component.render(canvas, elapsed, drawLabel: false);
  component.art.wake = wake;
}

/// A planet's territory as a soft wash, centred on [pos] (the planet's
/// position as rendered, after wrapping). Each planet picks its own tint —
/// its element colour at this strength often reads as mud. One gradient
/// fill.
void paintTerritoryWash(Canvas canvas, CosmicPlanet p, Offset pos) {
  const r = kPlanetTerritoryRadius;
  final art = planetArtFor(p);
  final tint = art.territoryTint;
  final a = art.territoryStrength;
  canvas.drawCircle(
    pos,
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        pos,
        r,
        [
          tint.withValues(alpha: a),
          tint.withValues(alpha: a * 0.73),
          tint.withValues(alpha: 0),
        ],
        const [0.0, 0.78, 1.0],
      ),
  );
}

/// What the encounter screen paints behind a creature pulled out of space:
/// the nearest planet (or the home planet) as it looked when the ship hit.
class CosmicEncounterBackdrop {
  const CosmicEncounterBackdrop({
    this.image,
    this.planetColor,
    this.label,
    this.isHome = false,
    this.direction = const Offset(1, 0.4),
  });

  /// Square render of the planet, centred, [planetRadiusFraction] of the
  /// image wide in radius. Null when nothing is near.
  final ui.Image? image;
  final Color? planetColor;
  final String? label;
  final bool isHome;

  /// Unit-ish vector from the ship toward the planet, so the planet sits on
  /// the side of the frame it really is on.
  final Offset direction;

  static const double planetRadiusFraction = 0.34;
  static const int imageSize = 2048;
}

extension CosmicGameWild on CosmicGame {
  // ── API for the screen ─────────────────────────────────────────────────

  void addWildAlchemon(SpaceWildAlchemon wild) {
    _wildSpawnRequested = false;
    wildAlchemons.add(wild);
    _loadWildSprite(wild);
  }

  /// The screen could not produce a creature for the last request.
  void cancelWildSpawnRequest() => _wildSpawnRequested = false;

  SpaceWildAlchemon? wildById(String id) {
    for (final w in wildAlchemons) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// Close the portal opened by ramming [id]. [gone] removes it for good —
  /// harvested, fused, or lost to a failed attempt.
  void resolveWildContact(String id, {required bool gone}) {
    _wildContactPending = false;
    _beginTearClose();
    final w = wildById(id);
    if (w == null) return;
    if (gone) {
      _removeWild(w);
    } else {
      w.needsSeparation = true;
    }
  }

  /// Start a fight with [wild]. It becomes the duel opponent until one side
  /// gives or the ship flies off.
  void engageWild(SpaceWildAlchemon wild) {
    if (wildDuelActive ||
        wild.state != SpaceWildState.grazing ||
        wild.leaving ||
        _shipDead) {
      return;
    }
    spawnDuelOpponent(wild.member);
    final opp = duelOpponent;
    if (opp == null) return;
    final at = _nearestImage(wild.position, ship.pos);
    opp.position = at;
    opp.anchorPosition = at;
    // It is already here; skip the summon-in flourish.
    opp.life = 1.0;
    opp.invincibleTimer = 0.4;
    opp.currentHp = (opp.maxHp * wild.hpFraction).round().clamp(1, opp.maxHp);
    wild.state = SpaceWildState.dueling;
    _duelWildId = wild.id;
    if (nearWild == wild) {
      nearWild = null;
      onNearWild?.call(null);
    }
    onWildDuelStarted?.call(wild);
  }

  // ── per-frame ───────────────────────────────────────────────────────────

  void _updateWildAlchemons(double dt) {
    if (sandboxMode || inNexusPocket) return;

    // Keep a live duel in the ship's frame so a fight across the world's
    // wrapped edge does not send the opponent the long way round.
    final opp = duelOpponent;
    if (wildDuelActive && opp != null) {
      opp.position = _nearestImage(opp.position, ship.pos);
    }

    // ── ask the screen for a new arrival ──
    // Denser inside a planet's territory, sparse in the deep space between.
    final inTerritory = territoryAt(ship.pos) != null;
    final cap = inTerritory
        ? CosmicGame._maxWildInTerritory
        : CosmicGame._maxWildInDeepSpace;
    final interval = inTerritory
        ? CosmicGame._wildIntervalInTerritory
        : CosmicGame._wildIntervalInDeepSpace;
    _wildSpawnTimer += dt;
    if (!_wildSpawnRequested &&
        !_shipDead &&
        onWildSpawnWanted != null &&
        wildAlchemons.length < cap &&
        _wildSpawnTimer >= interval) {
      _wildSpawnTimer = 0;
      _wildSpawnRequested = true;
      final at = _pickWildSpawnPoint();
      onWildSpawnWanted!(at, _wildElementHint(at));
    }

    SpaceWildAlchemon? nearest;
    var nearestDist = CosmicGame._wildNearRange;
    final halfW = size.x / (2 * cameraZoom) + 160;
    final halfH = size.y / (2 * cameraZoom) + 160;

    for (var i = wildAlchemons.length - 1; i >= 0; i--) {
      final w = wildAlchemons[i];
      w.life += dt;

      if (w.leaving) {
        w.fade -= dt / 0.9;
        if (w.fade <= 0) _removeWild(w);
        continue;
      }
      w.fade = min(1.0, w.fade + dt / 1.2);

      if (w.state == SpaceWildState.dueling) {
        if (_duelWildId != w.id) {
          // The duel was cleared from elsewhere (sandbox, reset).
          w.state = SpaceWildState.grazing;
        } else if (opp != null) {
          w.position = _wrap(opp.position);
        }
      }

      final delta = _toroidalDelta(w.position, ship.pos);
      final dist = delta.distance;
      if (w.state != SpaceWildState.dueling &&
          dist > CosmicGame._wildDespawnRange) {
        _removeWild(w);
        continue;
      }

      switch (w.state) {
        case SpaceWildState.dueling:
          break;
        case SpaceWildState.exhausted:
          w.exhaustedTimer -= dt;
          if (w.exhaustedTimer <= 0) {
            // Recovered. It does not stay to be caught.
            w.leaving = true;
            continue;
          }
          // Adrift: a slow slide, no steering.
          w.position = _wrap(
            w.position +
                Offset(cos(w.driftAngle), sin(w.driftAngle)) * (6.0 * dt),
          );
        case SpaceWildState.grazing:
          _driftWild(w, dt);
      }

      if (w.needsSeparation && dist > 110) w.needsSeparation = false;

      // Only tick the animation when it can be seen.
      if (w.state != SpaceWildState.dueling &&
          delta.dx.abs() < halfW &&
          delta.dy.abs() < halfH) {
        w._ticker?.update(dt);
      }

      if (_shipDead || _wildContactPending) continue;

      // ── the fight starts itself ──
      // Territorial ones turn on the ship; any of them turns on a summoned
      // companion that comes close. With nothing summoned the ship can
      // drift up and ram in peace.
      if (w.state == SpaceWildState.grazing &&
          !wildDuelActive &&
          !w.needsSeparation &&
          w.fade >= 1.0 &&
          ((w.territorial && dist < CosmicGame._wildTerritoryRange) ||
              _companionNear(w.position))) {
        engageWild(w);
        continue;
      }

      // ── ramming it opens the portal ──
      if (!w.needsSeparation && w.fade >= 0.6) {
        final bodyPos = w.state == SpaceWildState.dueling && opp != null
            ? opp.position
            : w.position;
        if (_toroidalDistance(bodyPos, ship.pos) <
            CosmicGame._wildContactRange) {
          _wildContact(w);
          continue;
        }
      }

      if (w.state != SpaceWildState.dueling && dist < nearestDist) {
        nearestDist = dist;
        nearest = w;
      }
    }

    if (_wildContactPending) nearest = null;
    if (!identical(nearest, nearWild)) {
      nearWild = nearest;
      onNearWild?.call(nearest);
    }
  }

  bool _companionNear(Offset at) {
    for (final comp in activeCompanions.values) {
      if (!comp.isAlive || comp.returning) continue;
      if (_toroidalDistance(comp.position, at) <
          CosmicGame._wildCompanionEngageRange) {
        return true;
      }
    }
    return false;
  }

  void _driftWild(SpaceWildAlchemon w, double dt) {
    w.driftTimer -= dt;
    if (w.driftTimer <= 0) {
      w.driftTimer = 3.0 + _rng.nextDouble() * 3.5;
      w.driftAngle += (_rng.nextDouble() - 0.5) * 1.6;
    }
    // Tethered to where it arrived, so a grazing herd of one stays findable.
    final home = _toroidalDelta(w.anchor, w.position);
    if (home.distance > CosmicGame._wildTetherRadius) {
      final back = atan2(home.dy, home.dx);
      var diff = back - w.driftAngle;
      while (diff > pi) {
        diff -= 2 * pi;
      }
      while (diff < -pi) {
        diff += 2 * pi;
      }
      w.driftAngle += diff.clamp(-1.2 * dt, 1.2 * dt);
    }
    const speed = 22.0;
    final bob = 0.75 + 0.25 * sin(w.life * 0.9 + w.id.hashCode % 7);
    w.position = _wrap(
      w.position +
          Offset(cos(w.driftAngle), sin(w.driftAngle)) * (speed * bob * dt),
    );
  }

  void _wildContact(SpaceWildAlchemon w) {
    if (w.state == SpaceWildState.dueling) {
      _endWildDuel(WildDuelEnd.rammed);
    }
    _wildContactPending = true;
    boosting = false;
    clearSteeringInput();
    if (nearWild != null) {
      nearWild = null;
      onNearWild?.call(null);
    }
    // The portal opens in space first; the screen is told once it has
    // swallowed the view.
    _tearWild = w;
    _tearHandedOff = false;
    _tearT = 0;
    _tearCloseT = -1;
    _tearWorld = _nearestImage(w.position, ship.pos);
    _tearColor = elementColor(w.element);
    onWildTearStarted?.call();
  }

  // ── portal tear ─────────────────────────────────────────────────────────

  /// Advances the tear on real time and returns the slowed time the rest of
  /// the world runs on.
  double _tickPortalTear(double dt) {
    _tearClock += dt;
    final w = _tearWild;
    if (w != null) {
      _tearT += dt;
      if (!w.leaving && wildAlchemons.contains(w)) {
        _tearWorld = _nearestImage(w.position, ship.pos);
      }
      final p = (_tearT / CosmicGame._tearOpenSeconds).clamp(0.0, 1.0);
      final lean = Curves.easeInOutCubic.transform((p / 0.7).clamp(0.0, 1.0));
      _camPan = (_tearWorld - ship.pos) * lean;
      _camZoomMul = 1.0 + 0.6 * lean;
      if (p >= 1.0 && !_tearHandedOff) {
        _tearHandedOff = true;
        onWildContact?.call(w);
      }
      // Time all but stops as the tear takes hold.
      return dt * (1.0 - 0.92 * lean);
    }
    _tearCloseT += dt;
    final p = (_tearCloseT / CosmicGame._tearCloseSeconds).clamp(0.0, 1.0);
    final settle = Curves.easeInOutCubic.transform(p);
    _camPan = _camPanFrom * (1 - settle);
    _camZoomMul = 1.0 + 0.6 * (1 - settle);
    if (p >= 1.0) {
      _tearCloseT = -1;
      _camPan = Offset.zero;
      _camZoomMul = 1.0;
    }
    return dt * (0.08 + 0.92 * settle);
  }

  void _beginTearClose() {
    if (_tearWild == null) return;
    _tearWild = null;
    _tearCloseT = 0;
    _camPanFrom = _camPan;
  }

  /// How far open the tear is: 0→1 opening, 1→0 closing, null when none.
  double? get _tearQ {
    if (_tearWild != null) {
      return (_tearT / CosmicGame._tearOpenSeconds).clamp(0.0, 1.0);
    }
    if (_tearCloseT >= 0) {
      return 1.0 - (_tearCloseT / CosmicGame._tearCloseSeconds).clamp(0.0, 1.0);
    }
    return null;
  }

  Offset get _tearScreenPos {
    final zoom = cameraZoom;
    return Offset((_tearWorld.dx - camX) * zoom, (_tearWorld.dy - camY) * zoom);
  }

  /// Called inside the world transform, just before the wild Alchemons are
  /// drawn, so the creature hangs silhouetted in front of the slit.
  void _renderPortalTearBehind(Canvas canvas) {
    final q = _tearQ;
    if (q == null || q <= 0) return;
    final zoom = cameraZoom;
    canvas.save();
    canvas.translate(camX, camY);
    canvas.scale(1 / zoom);
    paintSpaceTearBehind(
      canvas,
      screen: Size(size.x, size.y),
      centre: _tearScreenPos,
      q: q,
      color: _tearColor,
      clock: _tearClock,
    );
    canvas.restore();
  }

  /// Drawn over the finished frame, in screen space: the dark opening in the
  /// slit until it has swallowed the view.
  void _renderPortalTear(Canvas canvas) {
    final q = _tearQ;
    if (q == null || q <= 0) return;
    paintSpaceTearOver(
      canvas,
      screen: Size(size.x, size.y),
      centre: _tearScreenPos,
      q: q,
      color: _tearColor,
    );
  }

  void _endWildDuel(WildDuelEnd how) {
    final id = _duelWildId;
    _duelWildId = null;
    _wildDuelTargetCompanion = null;
    final opp = duelOpponent;
    final w = id == null ? null : wildById(id);
    final hpFraction = opp == null || opp.maxHp <= 0
        ? 1.0
        : (opp.currentHp / opp.maxHp).clamp(0.0, 1.0);
    final at = opp != null ? _wrap(opp.position) : w?.position;
    if (opp != null && how == WildDuelEnd.exhausted) {
      _spawnHitSpark(opp.position, elementColor(opp.member.element));
    }
    dismissDuelOpponent();
    if (w == null) return;
    if (at != null) {
      w.position = at;
      w.anchor = at;
    }
    switch (how) {
      case WildDuelEnd.exhausted:
        w.state = SpaceWildState.exhausted;
        w.hpFraction = 0;
        w.exhaustedTimer = CosmicGame._wildExhaustedSeconds;
        w.driftAngle = _rng.nextDouble() * 2 * pi;
      case WildDuelEnd.shipDown:
        w.state = SpaceWildState.grazing;
        w.leaving = true;
      case WildDuelEnd.disengaged:
      case WildDuelEnd.rammed:
        w.state = SpaceWildState.grazing;
        w.hpFraction = hpFraction;
    }
    onWildDuelEnded?.call(w, how);
  }

  void _removeWild(SpaceWildAlchemon w) {
    if (_duelWildId == w.id) _endWildDuel(WildDuelEnd.disengaged);
    wildAlchemons.remove(w);
    if (identical(nearWild, w)) {
      nearWild = null;
      onNearWild?.call(null);
    }
  }

  Offset _pickWildSpawnPoint() {
    final viewHalfDiag =
        sqrt(size.x * size.x + size.y * size.y) / (2 * cameraZoom);
    final minDist = max(900.0, viewHalfDiag + 180);
    final dist = minDist + _rng.nextDouble() * 500;
    final angle = _rng.nextDouble() * 2 * pi;
    return _wrap(ship.pos + Offset(cos(angle), sin(angle)) * dist);
  }

  /// Inside a territory most arrivals are its element; strays, and anything
  /// in deep space, are left to the screen to pick freely.
  String? _wildElementHint(Offset at) {
    final here = territoryAt(at);
    if (here == null) return null;
    return _rng.nextDouble() < CosmicGame._wildTerritoryNativeShare
        ? here.$1.element
        : null;
  }

  /// The planet whose territory [at] lies in, and how deep: 1 well inside,
  /// easing to 0 at the border. Null in deep space.
  (CosmicPlanet, double)? territoryAt(Offset at) {
    CosmicPlanet? best;
    var bestDist = kPlanetTerritoryRadius;
    for (final p in world_.planets) {
      final d = _toroidalDistance(p.position, at);
      if (d < bestDist) {
        bestDist = d;
        best = p;
      }
    }
    if (best == null) return null;
    const r = kPlanetTerritoryRadius;
    final depth = (1 - (bestDist - r * 0.8) / (r * 0.2)).clamp(0.0, 1.0);
    return (best, depth);
  }

  // ── territories ─────────────────────────────────────────────────────────

  /// Each territory as a soft wash, and — for the one the view is in — its
  /// planet's own motes (see PlanetArt.motes). One gradient fill per
  /// territory in view and at most ninety small shapes; no blur.
  void _renderTerritories(
    Canvas canvas,
    double cx,
    double cy,
    double screenW,
    double screenH,
  ) {
    const r = kPlanetTerritoryRadius;
    final viewCentre = Offset(cx + screenW / 2, cy + screenH / 2);
    final reach = r + sqrt(screenW * screenW + screenH * screenH) / 2;
    for (final p in world_.planets) {
      final pos = _wrappedRenderPos(p.position, cx, cy, screenW, screenH);
      if ((pos - viewCentre).distance > reach) continue;
      paintTerritoryWash(canvas, p, pos);
    }

    final here = territoryAt(_wrap(viewCentre));
    if (here == null) return;
    final (planet, depth) = here;
    if (depth <= 0.02) return;
    planetArtFor(planet).paintTerritory(
      canvas,
      _wrappedRenderPos(planet.position, cx, cy, screenW, screenH),
      Rect.fromLTWH(cx, cy, screenW, screenH),
      depth,
      _elapsed,
    );
  }

  Offset _toroidalDelta(Offset to, Offset from) {
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    var dx = to.dx - from.dx;
    var dy = to.dy - from.dy;
    if (dx > ww / 2) dx -= ww;
    if (dx < -ww / 2) dx += ww;
    if (dy > wh / 2) dy -= wh;
    if (dy < -wh / 2) dy += wh;
    return Offset(dx, dy);
  }

  /// The copy of [p] across the wrapped edges that is nearest [reference].
  Offset _nearestImage(Offset p, Offset reference) =>
      reference + _toroidalDelta(p, reference);

  Future<void> _loadWildSprite(SpaceWildAlchemon w) async {
    final sheet = w.member.spriteSheet;
    if (sheet == null) return;
    try {
      final image = await images.load(sheet.path);
      final cols = (sheet.totalFrames + sheet.rows - 1) ~/ sheet.rows;
      final anim = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: sheet.totalFrames,
          amountPerRow: cols,
          textureSize: sheet.frameSize,
          stepTime: sheet.stepTime,
          loop: true,
        ),
      );
      // Same box and species scale as a summoned companion, so a wild one
      // reads as exactly the size of the one you own.
      const desiredSize = CosmicGame.spriteBox;
      final fit = min(
        desiredSize / sheet.frameSize.x,
        desiredSize / sheet.frameSize.y,
      );
      final species =
          CosmicGame._companionSpeciesScale[w.member.family.toLowerCase()] ??
          1.0;
      w._spriteScale = fit * (w.member.spriteVisuals?.scale ?? 1.0) * species;
      w._halfHeight = sheet.frameSize.y * w._spriteScale / 2;
      w._ticker = anim.createTicker();
    } catch (e) {
      debugPrint('Failed to load wild sprite ${sheet.path}: $e');
    }
  }

  // ── render ──────────────────────────────────────────────────────────────

  void _renderWildAlchemons(
    Canvas canvas,
    double cx,
    double cy,
    double screenW,
    double screenH,
  ) {
    _renderPortalTearBehind(canvas);
    if (wildAlchemons.isEmpty) return;
    for (final w in wildAlchemons) {
      if (w.state == SpaceWildState.dueling) continue;
      final pos = _wrappedRenderPos(w.position, cx, cy, screenW, screenH);
      if ((pos.dx - cx - screenW / 2).abs() > screenW / 2 + 140 ||
          (pos.dy - cy - screenH / 2).abs() > screenH / 2 + 140) {
        continue;
      }
      _renderWild(canvas, w, pos);
    }
  }

  void _renderWild(Canvas canvas, SpaceWildAlchemon w, Offset pos) {
    final fade = w.fade.clamp(0.0, 1.0);
    if (fade <= 0) return;
    final color = elementColor(w.element);
    final exhausted = w.isExhausted;
    final shipDist = _toroidalDistance(w.position, ship.pos);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    // A pool of its own element's light behind it — no halo, no outline.
    final glowR = 50.0;
    canvas.drawCircle(
      Offset.zero,
      glowR,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, glowR, [
          color.withValues(alpha: (exhausted ? 0.10 : 0.22) * fade),
          color.withValues(alpha: 0),
        ]),
    );

    final ticker = w._ticker;
    if (ticker != null) {
      final paint = Paint()
        ..color = Colors.white.withValues(
          alpha: fade * (exhausted ? 0.62 : 1.0),
        )
        ..filterQuality = ui.FilterQuality.medium;
      final v = w.member.spriteVisuals;
      if (v != null) {
        final isAlbino = v.brightness == 1.45 && !v.isPrismatic;
        paint.colorFilter = isAlbino
            ? _albinoColorFilter(v.brightness)
            : _geneticsColorFilter(v);
      }
      canvas.save();
      if (exhausted) {
        // Slumped and slowly turning over.
        canvas.rotate(0.45 + 0.08 * sin(w.life * 0.7));
      } else {
        canvas.translate(0, sin(w.life * 1.6) * 2.5);
      }
      final facingRight = cos(w.driftAngle) > 0;
      final s = w._spriteScale;
      canvas.scale(facingRight ? -s : s, s);
      ticker.getSprite().render(
        canvas,
        anchor: Anchor.center,
        overridePaint: paint,
      );
      canvas.restore();
    } else {
      canvas.drawCircle(
        Offset.zero,
        14,
        Paint()..color = color.withValues(alpha: 0.8 * fade),
      );
    }

    // ── Potentials, only when close enough to matter ──
    // A hard range rather than a fade: fading text means a saveLayer per
    // label per frame. No name — the creature is what you look at.
    if (showWildPotentials &&
        fade >= 1.0 &&
        shipDist < CosmicGame._wildLabelRange) {
      final label = w._potentialLabel ??= _buildPotentialLabel(w.member);
      _paintPlate(
        canvas,
        label,
        Offset(0, -w._halfHeight - label.height / 2 - 10),
      );
    }

    canvas.restore();
  }

  void _paintPlate(Canvas canvas, TextPainter tp, Offset center) {
    final rect = Rect.fromCenter(
      center: center,
      width: tp.width + 12,
      height: tp.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = const Color(0xFF0B0D12).withValues(alpha: 0.72),
    );
    tp.paint(canvas, Offset(rect.left + 6, rect.top + 3));
  }

  /// The four Potentials as a 2×2 block, so it sits over the creature
  /// rather than spreading across the view.
  TextPainter _buildPotentialLabel(CosmicPartyMember m) {
    const parchment = Color(0xFFE6E2DA);
    const muted = Color(0xFF85827C);
    const amber = Color(0xFFE4C16A);
    List<TextSpan> reading(String label, double value) {
      final v = value.round().clamp(1, 100);
      return [
        TextSpan(
          text: '$label ',
          style: const TextStyle(color: muted),
        ),
        TextSpan(
          text: '$v'.padLeft(3),
          style: TextStyle(
            color: v >= 80 ? amber : parchment,
            fontWeight: FontWeight.w800,
          ),
        ),
      ];
    }

    return TextPainter(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 9.5,
          fontFamily: 'monospace',
          letterSpacing: 0.4,
          height: 1.35,
        ),
        children: [
          ...reading('SPD', m.statSpeedPotential),
          const TextSpan(text: '   '),
          ...reading('INT', m.statIntelligencePotential),
          const TextSpan(text: '\n'),
          ...reading('STR', m.statStrengthPotential),
          const TextSpan(text: '   '),
          ...reading('BEA', m.statBeautyPotential),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  // ── encounter backdrop ──────────────────────────────────────────────────

  /// Render whatever planet the ship is beside — the home planet counts —
  /// into an image for the encounter screen. Returns an empty backdrop in
  /// open space.
  CosmicEncounterBackdrop captureEncounterBackdrop() {
    final at = ship.pos;
    const reach = 2600.0;

    CosmicPlanet? planet;
    var planetGap = reach;
    for (final p in world_.planets) {
      final gap = _toroidalDistance(p.position, at) - p.radius;
      if (gap < planetGap) {
        planetGap = gap;
        planet = p;
      }
    }
    final home = homePlanet;
    final homeGap = home == null
        ? double.infinity
        : _toroidalDistance(home.position, at) - home.visualRadius;
    final useHome = home != null && homeGap < reach && homeGap <= planetGap;
    if (!useHome && planet == null) return const CosmicEncounterBackdrop();

    const sz = CosmicEncounterBackdrop.imageSize;
    const target = sz * CosmicEncounterBackdrop.planetRadiusFraction;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, sz.toDouble(), sz.toDouble()),
    );

    final Offset centre;
    final Color color;
    final String label;
    if (useHome) {
      centre = home.position;
      color = home.blendedColor;
      label = 'HOME';
      final vr = home.visualRadius;
      _paintBackdropLayer(canvas, color, () {
        canvas.translate(sz / 2, sz / 2);
        canvas.scale(target / vr);
        canvas.translate(-centre.dx, -centre.dy);
        _renderHomeBody(canvas, centre, vr);
      });
    } else {
      final p = planet!;
      centre = p.position;
      color = p.color;
      label = planetName(p.element).toUpperCase();
      _paintBackdropLayer(canvas, color, () {
        canvas.translate(sz / 2, sz / 2);
        _paintPlanetForBackdrop(canvas, p, _elapsed);
      });
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(sz, sz);
    picture.dispose();

    final toward = _toroidalDelta(centre, at);
    final len = toward.distance;
    return CosmicEncounterBackdrop(
      image: image,
      planetColor: color,
      label: label,
      isHome: useHome,
      direction: len < 1 ? const Offset(1, 0.4) : toward / len,
    );
  }

  /// The home planet as the customization lab shows it: fitted into [area]
  /// whatever its size in the world, wearing [wearing] in [color], at
  /// [time]. The same layers the world draws, so the lab shows the planet
  /// the player will see; nothing about the real planet is changed.
  void paintHomeShowcase(
    Canvas canvas,
    Rect area,
    double time, {
    required Set<String> wearing,
    String? color,
  }) {
    final hp = homePlanet;
    if (hp == null) return;
    final savedWearing = activeCustomizations;
    final savedColor = hp.activeColor;
    final savedTime = _elapsed;
    activeCustomizations = wearing;
    hp.activeColor = color;
    _elapsed = time;
    final vr = hp.visualRadius;
    // The widest things a planet wears (rings, the black hole's disk) reach
    // about 2.6 radii.
    final fit = min(area.width, area.height) / (vr * 2 * 2.6);
    canvas.save();
    canvas.translate(area.center.dx, area.center.dy);
    canvas.scale(fit);
    try {
      _renderHomeBody(canvas, Offset.zero, vr);
    } finally {
      canvas.restore();
      activeCustomizations = savedWearing;
      hp.activeColor = savedColor;
      _elapsed = savedTime;
    }
  }

  /// The home planet's body and cosmetics, without the garrison — the same
  /// layers the world render draws.
  void _renderHomeBody(Canvas canvas, Offset pos, double vr) {
    final hp = homePlanet!;
    final col = hp.blendedColor;
    _paintHomeAura(canvas, pos, vr, col);
    _renderHomeEffectsBehind(canvas, pos, vr, col);
    _paintHomeSphere(canvas, pos, vr, col);
    _renderHomeEffectsFront(canvas, pos, vr, col);
  }
}
