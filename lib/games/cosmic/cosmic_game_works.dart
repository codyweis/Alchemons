part of 'cosmic_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE WORKS IN SPACE
//
//  The base's buildings drawn where they stand — extractors on their
//  planets' rims, the Scavenger Bay and the Silver Press beside home — and
//  the Alchemons working them: miners beside their rigs, couriers flying the
//  hopper home, scavengers out searching and back with their finds.
//
//  Nothing here keeps time of its own. Where a courier or a scavenger is, is
//  read off the same wall-clock runs works.dart catches up with, so what is
//  drawn is what the numbers say, whether the player watched it or not.
//  Only buildings and workers in view are drawn; the solids are baked.
// ─────────────────────────────────────────────────────────────────────────────

/// A worker's sprite, loaded once per Alchemon at work.
class _WorkerSprite {
  SpriteAnimationTicker? ticker;
  double scale = 1;

  /// Its look, set once: the filter that tints it is built when the sprite
  /// loads, not every frame.
  final Paint paint = Paint()..filterQuality = ui.FilterQuality.medium;
}

/// Matter sent from one place to another, drawn as a current of grains.
class _WorksFlow {
  _WorksFlow({
    required this.from,
    required this.to,
    required this.colors,
    required this.seed,
    this.duration = 2.8,
  });

  final Offset Function() from;
  final Offset Function() to;
  final List<Color> colors;
  final int seed;
  final double duration;
  double t = 0;
}

extension CosmicGameWorks on CosmicGame {
  /// World units an art unit, for the rigs and the home buildings.
  static const double _artScale = 2.3;

  /// Planets the ship has found, in world order: what a scavenger can bring
  /// back. The screen rolls finds from the same list.
  List<String> get scavengeElements => [
    for (final p in world_.planets)
      if (p.discovered) p.element,
  ];

  CosmicPlanet? _planetOf(String element) {
    for (final p in world_.planets) {
      if (p.element == element) return p;
    }
    return null;
  }

  /// Where on its planet's rim an extractor of [element] stands: a fixed
  /// bearing per element, on the upper side so it reads standing up.
  double _rigBearing(String element) =>
      -pi / 2 + ((stableHash(element) % 1000) / 1000 - 0.5) * 2.2;

  /// The foot of [element]'s extractor, in the world.
  Offset? extractorRigPos(String element) {
    final p = _planetOf(element);
    if (p == null) return null;
    return p.position + polar(p.radius - 2, _rigBearing(element));
  }

  /// A point on [element]'s rig, given in rig units, in the world.
  Offset _onRig(String element, Offset local) {
    final foot = extractorRigPos(element) ?? Offset.zero;
    final rot = _rigBearing(element) + pi / 2;
    final c = cos(rot), s = sin(rot);
    final x = local.dx * _artScale, y = local.dy * _artScale;
    return foot + Offset(x * c - y * s, x * s + y * c);
  }

  /// How far [element]'s extractor is from home, now.
  double worksDistanceHome(String element) {
    final rig = extractorRigPos(element);
    final home = homePlanet;
    if (rig == null || home == null) return 8000;
    return _toroidalDelta(home.position, rig).distance;
  }

  /// The berths' ring: out past what the home wears (its rings, moons and
  /// veils reach about 2.2 of its radius), at the size it is shown.
  double get _worksRing {
    final vr = homePlanet?.visualRadius ?? 80;
    return vr * 2.6 + 150;
  }

  /// Where each berth stands round home, in the order they fill: the lower
  /// sides first, then the upper, then straight below and above. Never on
  /// the planet.
  static const List<double> _berthBearings = [
    pi * 5 / 6,
    pi / 6,
    pi * 7 / 6,
    pi * 11 / 6,
    pi / 2,
    pi * 3 / 2,
  ];

  /// The berths turn round home, once in eight minutes, as what orbits a
  /// planet does — a ring of buildings held still in space reads as pasted
  /// on. Each also floats a little on its own.
  double get _worksOrbit => _elapsed * 2 * pi / 480;

  /// Home buildings grow with the planet: a Huge home's stand about half as
  /// large again as a Tiny one's.
  double get _homeScale {
    final vr = homePlanet?.visualRadius ?? 80;
    return 2.0 + vr / 250 * 1.3;
  }

  /// Berth [i] in the world, or null with no home.
  Offset? berthPos(int i) {
    final home = homePlanet;
    if (home == null || i < 0) return null;
    final bearing = _berthBearings[i % _berthBearings.length] + _worksOrbit;
    final float = Offset(0, sin(_elapsed * 0.6 + i * 1.7) * 4);
    return home.position + polar(_worksRing, bearing) + float;
  }

  /// What ties a home building to its planet: the planet's own light on the
  /// side that faces it, and a faint current of grains between the two —
  /// what it makes going home, or ([inbound], the Armory) what it draws.
  void _paintHomeTies(
    Canvas canvas,
    Offset at,
    Offset homeAt,
    Color light, {
    required int seed,
    bool inbound = false,
  }) {
    final home = homePlanet;
    if (home == null) return;
    final toward = homeAt - at;
    final d = toward.distance;
    if (d < 1) return;
    final dir = toward / d;
    final k = _homeScale;
    paintDisc(
      canvas,
      stoneLightFor(home.blendedColor).pool,
      at + dir * 24 * k,
      62 * k,
      1.15,
    );
    final rim = homeAt - dir * (home.visualRadius * 0.96);
    final near = at + dir * 16 * k;
    paintSupplyLine(
      canvas,
      from: inbound ? rim : near,
      to: inbound ? near : rim,
      color: light,
      t: _elapsed,
      seed: seed,
      // Pulled back, a grain would shrink below a pixel: keep it about the
      // size it is at the middle zoom, as the gravity rings do.
      grain: 2.2 * max(1.0, 0.72 / cameraZoom),
    );
  }

  Offset? get worksBayPos => berthPos(works?.bay.berth ?? -1);
  Offset? get worksPressPos => berthPos(works?.press.berth ?? -1);
  Offset? get worksRefineryPos => berthPos(works?.refinery.berth ?? -1);
  Offset? get worksArmoryPos => berthPos(works?.armory.berth ?? -1);

  /// The bay sits level, its cradles hanging down, as the stations stand.
  double get _bayRot => 0;

  Offset _onBay(Offset local) {
    final at = worksBayPos ?? Offset.zero;
    final c = cos(_bayRot), s = sin(_bayRot);
    final x = local.dx * _homeScale, y = local.dy * _homeScale;
    return at + Offset(x * c - y * s, x * s + y * c);
  }

  // ── workers ──────────────────────────────────────────────────────────────

  /// The Alchemons at work, by instance id, with what they look like. Loads
  /// a sprite for each one not loaded yet.
  void setWorksMembers(Map<String, CosmicPartyMember> members) {
    worksMembers = members;
    _workerSprites.removeWhere((id, _) => !members.containsKey(id));
    for (final m in members.values) {
      if (_workerSprites.containsKey(m.instanceId)) continue;
      final s = _workerSprites[m.instanceId] = _WorkerSprite();
      _loadWorkerSprite(s, m).ignore();
    }
  }

  Future<void> _loadWorkerSprite(_WorkerSprite s, CosmicPartyMember m) async {
    final sheet = sheetForVisuals(m.spriteSheet, m.spriteVisuals);
    if (sheet == null) return;
    try {
      final image = await loadCreatureSheet(images, sheet.path);
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
      s.ticker = anim.createTicker();
      final v = m.spriteVisuals;
      if (v != null) s.paint.colorFilter = _creatureFilter(v);
      final sx = CosmicGame.spriteBox / sheet.frameSize.x;
      final sy = CosmicGame.spriteBox / sheet.frameSize.y;
      final family = m.family.toLowerCase();
      s.scale =
          min(sx, sy) *
          (m.spriteVisuals?.scale ?? 1.0) *
          (CosmicGame._companionSpeciesScale[family] ?? 1.0);
    } catch (e) {
      debugPrint('Failed to load worker sprite: ${sheet.path} - $e');
    }
  }

  void _drawWorker(
    Canvas canvas,
    String? id,
    Offset at, {
    double size = 0.4,
    bool facingRight = false,
    double bob = 0,
  }) {
    if (id == null) return;
    final s = _workerSprites[id];
    final m = worksMembers[id];
    if (m == null) return;
    final light = stoneLightFor(elementColor(m.element));
    canvas.save();
    canvas.translate(at.dx, at.dy + bob);
    // A pool of its own light under it (a cached unit shader, scaled).
    paintDisc(canvas, light.pool, Offset.zero, 40 * size, 0.9);
    final ticker = s?.ticker;
    if (ticker != null) {
      final k = s!.scale * size;
      canvas.scale(facingRight ? -k : k, k);
      ticker.getSprite().render(
        canvas,
        anchor: Anchor.center,
        overridePaint: s.paint,
      );
    } else {
      paintDisc(canvas, light.spark, Offset.zero, 9 * size);
    }
    canvas.restore();
  }

  // ── flows ────────────────────────────────────────────────────────────────

  /// [element]'s hopper sent home: a current of its grains from the rig to
  /// home.
  void playHopperSentHome(String element) {
    final col = elementColor(element);
    _addFlow(
      _WorksFlow(
        from: () => _onRig(element, kHopperAt),
        to: () => homePlanet?.position ?? ship.pos,
        colors: [col, Color.lerp(col, Colors.white, 0.3)!],
        seed: stableHash(element) & 0xff,
        duration: 3.2,
      ),
    );
  }

  /// Matter out of the hold building [element]'s extractor: a current from
  /// the ship to the rig.
  void playHoldToRig(String element) {
    final col = elementColor(element);
    _addFlow(
      _WorksFlow(
        from: () => ship.pos,
        to: () => _onRig(element, kHopperAt),
        colors: [col, Color.lerp(col, Colors.white, 0.4)!],
        seed: 3,
        duration: 2.2,
      ),
    );
  }

  /// The bay's crates emptied into home: their colours pour off the rail.
  void playCratesEmptied(List<Color> colors) {
    if (colors.isEmpty || worksBayPos == null) return;
    _addFlow(
      _WorksFlow(
        from: () => _onBay(const Offset(-2, -12.5)),
        to: () => homePlanet?.position ?? ship.pos,
        colors: colors.take(4).toList(),
        seed: 7,
        duration: 2.6,
      ),
    );
  }

  /// Silver off the press, into home. One at a time: the press ticks
  /// while the world is held still under a panel, and those must not pile
  /// up into a burst when it resumes.
  void playSilverPressed() {
    final at = worksPressPos;
    if (at == null || _worksFlows.any((f) => f.seed == 11)) return;
    _addFlow(
      _WorksFlow(
        from: () => (worksPressPos ?? at) + const Offset(25, 29) * _homeScale,
        to: () => homePlanet?.position ?? ship.pos,
        colors: const [kSilverPressLight],
        seed: 11,
        duration: 2.4,
      ),
    );
  }

  void _addFlow(_WorksFlow f) {
    if (_worksFlows.length >= 8) _worksFlows.removeAt(0);
    _worksFlows.add(f);
  }

  void _updateWorks(double dt) {
    if (works == null && _worksFlows.isEmpty) return;
    for (final s in _workerSprites.values) {
      s.ticker?.update(dt);
    }
    for (var i = _worksFlows.length - 1; i >= 0; i--) {
      final f = _worksFlows[i];
      f.t += dt / f.duration;
      if (f.t >= 1) _worksFlows.removeAt(i);
    }
  }

  // ── drawing ──────────────────────────────────────────────────────────────

  void _renderWorks(
    Canvas canvas,
    double cx,
    double cy,
    double screenW,
    double screenH,
  ) {
    final w = works;
    if (w == null) {
      _renderWorksFlows(canvas, cx, cy, screenW, screenH);
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final home = homePlanet;

    for (final x in w.extractors.values) {
      final planet = _planetOf(x.element);
      if (planet == null) continue;
      final foot = extractorRigPos(x.element)!;
      final at = _wrappedRenderPos(foot, cx, cy, screenW, screenH);
      final shift = at - foot;
      final rot = _rigBearing(x.element) + pi / 2;
      final mining = x.miners.any(
        (id) => id != null && worksMembers[id] != null,
      );
      if (!isOutsideViewport(at, cx, cy, screenW, screenH, margin: 0.75)) {
        final gap = _toroidalDelta(ship.pos, foot).distance;
        paintExtractor(
          canvas,
          at: at,
          essence: planet.color,
          tier: x.tier,
          t: _elapsed + (stableHash(x.element) % 97) * 0.1,
          rot: rot,
          scale: _artScale,
          fill: x.hopper / x.hopperCap,
          mining: mining,
          wake: (1 - (gap - 160) / 360).clamp(0.0, 1.0),
        );
        // The miners stand by the rig, bobbing at their work.
        for (var i = 0; i < x.miners.length; i++) {
          final local = kMinerAt + Offset(i * -16.0, i * 10.0);
          _drawWorker(
            canvas,
            x.miners[i],
            _onRig(x.element, local) + shift,
            bob: sin(_elapsed * 2.2 + i) * 1.6,
            facingRight: true,
          );
        }
        if (gap < 700) {
          final label = _worldLabel(
            '${x.hopper.floor()}/${x.hopperCap}',
            color: elementInkFor(planet.color).withValues(alpha: 0.85),
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          );
          final top =
              _onRig(x.element, kHopperAt + const Offset(0, -24)) + shift;
          label.paint(canvas, top - Offset(label.width / 2, label.height / 2));
        }
      }

      // The courier, wherever its run has it.
      final courier = x.courier;
      if (courier != null &&
          home != null &&
          x.cycleMs > 0 &&
          worksMembers[courier] != null) {
        final ledge = _onRig(x.element, kCourierPerchAt) + shift;
        final homeAt = _nearestImage(home.position, foot) + shift;
        final dock = WorkRules.courierDockMs / x.cycleMs;
        final ph = ((now - x.cycleStartMs) / x.cycleMs).clamp(0.0, 1.0);
        Offset pos;
        var carrying = 0.0;
        var heading = const Offset(1, 0);
        if (ph < dock) {
          pos = ledge;
          carrying = x.cargo;
        } else if (ph < 0.5) {
          final u = Curves.easeInOutSine.transform((ph - dock) / (0.5 - dock));
          pos = Offset.lerp(ledge, homeAt, u)!;
          heading = homeAt - ledge;
          carrying = x.delivered ? 0 : x.cargo;
        } else if (ph < 0.5 + dock) {
          pos = homeAt;
        } else {
          final u = Curves.easeInOutSine.transform(
            ((ph - 0.5 - dock) / (0.5 - 2 * dock)).clamp(0.0, 1.0),
          );
          pos = Offset.lerp(homeAt, ledge, u)!;
          heading = ledge - homeAt;
        }
        if (!isOutsideViewport(pos, cx, cy, screenW, screenH, margin: 0.7)) {
          final dir = heading.distance > 0
              ? heading / heading.distance
              : heading;
          final col = elementColor(worksMembers[courier]!.element);
          if (heading.distance > 1) {
            paintWorkerWake(canvas, pos, dir, col, _elapsed);
          }
          final load = WorkRules.courierLoad(
            worksMembers[courier]!.statStrength,
          );
          paintCarriedPod(
            canvas,
            pos + const Offset(0, 21),
            planet.color,
            _elapsed,
            carrying / max(1, load),
          );
          _drawWorker(
            canvas,
            courier,
            pos,
            size: 0.46,
            facingRight: dir.dx > 0,
          );
        }
      }
    }

    // ── the home buildings ──
    if (home != null) {
      final homeAt = _wrappedRenderPos(home.position, cx, cy, screenW, screenH);
      final shift = homeAt - home.position;
      final bay = w.bay;
      if (bay.built) {
        final at = worksBayPos! + shift;
        final rest = [
          for (final s in bay.slots) s.instanceId != null && !s.out,
        ];
        if (!isOutsideViewport(at, cx, cy, screenW, screenH, margin: 0.75)) {
          _paintHomeTies(canvas, at, homeAt, kScavengerBayLight, seed: 1);
          paintScavengerBay(
            canvas,
            at: at,
            tier: bay.tier,
            t: _elapsed,
            rot: _bayRot,
            scale: _homeScale,
            resting: rest,
            crates: _crateColorsFor(bay.crates),
            crateCap: bay.crateCap,
            searching: bay.out > 0,
          );
          for (var i = 0; i < bay.slots.length; i++) {
            if (!rest[i]) continue;
            _drawWorker(
              canvas,
              bay.slots[i].instanceId,
              _onBay(bayBerthAt(i, bay.tier) + const Offset(0, -2)) + shift,
              size: 0.42 * _homeScale / _artScale,
              bob: sin(_elapsed * 1.6 + i * 2) * 1.2,
            );
          }
        }
        // Scavengers out: toward the planet whose matter they will bring
        // back, a while searching there, then home with it.
        for (final s in bay.slots) {
          final id = s.instanceId;
          if (id == null || !s.out || worksMembers[id] == null) continue;
          final m = worksMembers[id]!;
          final trip = _scavengeTripOf(id, s.trips);
          final lead = trip.lead;
          final mouth = _onBay(kBayMouthAt) + shift;
          final target = _scavengeTarget(trip.hash, lead, mouth);
          final ph = ((now - s.tripStartMs) / max(1, s.tripMs)).clamp(0.0, 1.0);
          Offset pos;
          Offset heading;
          var carrying = 0.0;
          if (ph < 0.38) {
            final u = Curves.easeInOutSine.transform(ph / 0.38);
            pos = Offset.lerp(mouth, target, u)!;
            heading = target - mouth;
          } else if (ph < 0.62) {
            final u = (ph - 0.38) / 0.24;
            final a = u * 2 * pi + trip.spin;
            pos = target + Offset(cos(a) * 150, sin(a) * 90) * sin(u * pi);
            heading = Offset(-sin(a), cos(a));
          } else {
            final u = Curves.easeInOutSine.transform((ph - 0.62) / 0.38);
            pos = Offset.lerp(target, mouth, u)!;
            heading = mouth - target;
            carrying = 1;
          }
          if (isOutsideViewport(pos, cx, cy, screenW, screenH, margin: 0.7)) {
            continue;
          }
          final dir = heading.distance > 0
              ? heading / heading.distance
              : heading;
          paintWorkerWake(canvas, pos, dir, elementColor(m.element), _elapsed);
          paintCarriedPod(
            canvas,
            pos + const Offset(0, 21),
            elementColor(lead),
            _elapsed,
            carrying * 0.7,
          );
          _drawWorker(canvas, id, pos, size: 0.46, facingRight: dir.dx > 0);
        }
      }

      final press = w.press;
      if (press.built) {
        final at = worksPressPos! + shift;
        if (!isOutsideViewport(at, cx, cy, screenW, screenH, margin: 0.75)) {
          final pressing =
              press.presser != null &&
              worksMembers[press.presser] != null &&
              worksPressIntake.isNotEmpty;
          _paintHomeTies(canvas, at, homeAt, kSilverPressLight, seed: 2);
          paintSilverPress(
            canvas,
            at: at,
            tier: press.tier,
            t: _elapsed,
            scale: _homeScale,
            pressing: pressing,
            intake: worksPressIntake,
          );
          _drawWorker(
            canvas,
            press.presser,
            at + const Offset(-36, 8) * _homeScale,
            size: 0.4 * _homeScale / _artScale,
            facingRight: true,
            bob: pressing ? sin(_elapsed * 2 * pi / 3.6) * 1.4 : 0,
          );
        }
      }

      final armory = w.armory;
      if (armory.built && worksArmoryPos != null) {
        final at = worksArmoryPos! + shift;
        if (!isOutsideViewport(at, cx, cy, screenW, screenH, margin: 0.75)) {
          _paintHomeTies(
            canvas,
            at,
            homeAt,
            kArmoryLight,
            seed: 3,
            inbound: true,
          );
          paintArmory(
            canvas,
            at: at,
            tier: armory.tier,
            t: _elapsed,
            scale: _homeScale,
            skin: activeShipSkin,
          );
        }
      }

      final refinery = w.refinery;
      if (refinery.built && worksRefineryPos != null) {
        final at = worksRefineryPos! + shift;
        if (!isOutsideViewport(at, cx, cy, screenW, screenH, margin: 0.75)) {
          final parts = refinery.parts;
          final working =
              worksRefining &&
              refinery.refiner != null &&
              worksMembers[refinery.refiner] != null;
          _paintHomeTies(
            canvas,
            at,
            homeAt,
            parts == null ? kRefineryLight : elementColor(parts.$3),
            seed: 4,
          );
          paintRefinery(
            canvas,
            at: at,
            tier: refinery.tier,
            t: _elapsed,
            scale: _homeScale,
            inA: parts == null ? null : elementColor(parts.$1),
            inB: parts == null ? null : elementColor(parts.$2),
            out: parts == null ? null : elementColor(parts.$3),
            working: working,
          );
          _drawWorker(
            canvas,
            refinery.refiner,
            at + const Offset(-38, 14) * _homeScale,
            size: 0.4 * _homeScale / _artScale,
            facingRight: true,
            bob: working ? sin(_elapsed * 2.4) * 1.2 : 0,
          );
        }
      }
    }

    _renderWorksFlows(canvas, cx, cy, screenW, screenH);
  }

  /// The trip scavenger [id] is on: the element its find leads with (the
  /// same roll the works make for it) and the hashes that place its search.
  ({int trip, String lead, int hash, int spin}) _scavengeTripOf(
    String id,
    int trip,
  ) {
    final known = _scavengeTrips[id];
    if (known != null && known.trip == trip) return known;
    final find = rollFind(
      instanceId: id,
      trip: trip,
      units: 1,
      shardOdds: 0,
      elements: scavengeElements,
    );
    return _scavengeTrips[id] = (
      trip: trip,
      lead: find.elements.keys.first,
      hash: stableHash('$id:$trip'),
      spin: stableHash(id) % 7,
    );
  }

  /// The colour of each crate in the bay: its find's largest element.
  List<Color> _crateColorsFor(List<ScavengerFind> crates) {
    final key = (crates.length, crates.isEmpty ? null : crates.last);
    if (key == _crateColorsOf) return _crateColors;
    _crateColorsOf = key;
    return _crateColors = [
      for (final c in crates)
        elementColor(
          c.elements.entries.reduce((a, b) => a.value >= b.value ? a : b).key,
        ),
    ];
  }

  /// Where a scavenger searches on the trip hashed [h]: out toward the
  /// planet of [element], some of the way, a little to one side.
  Offset _scavengeTarget(int h, String element, Offset from) {
    final planet = _planetOf(element);
    final along = 0.35 + (h % 1000) / 1000 * 0.3;
    final side = (((h >> 10) % 1000) / 1000 - 0.5) * 900;
    Offset to;
    if (planet == null) {
      to = from + polar(3000, (h % 628) / 100);
    } else {
      to = from + _toroidalDelta(planet.position, from) * along;
    }
    final d = to - from;
    final n = d.distance > 0
        ? Offset(-d.dy, d.dx) / d.distance
        : const Offset(0, 1);
    return to + n * side;
  }

  void _renderWorksFlows(
    Canvas canvas,
    double cx,
    double cy,
    double screenW,
    double screenH,
  ) {
    for (final f in _worksFlows) {
      final from = _wrappedRenderPos(f.from(), cx, cy, screenW, screenH);
      final to = from + _toroidalDelta(f.to(), f.from());
      if (isOutsideViewport(from, cx, cy, screenW, screenH, margin: 1.2) &&
          isOutsideViewport(to, cx, cy, screenW, screenH, margin: 1.2)) {
        continue;
      }
      paintGrainFlow(
        canvas,
        from: from,
        to: to,
        p: f.t,
        colors: f.colors,
        seed: f.seed,
        count: 120,
        grain: 2.2,
      );
    }
  }
}

/// A light-enough ink of [c] to read as small text over space.
Color elementInkFor(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness(max(hsl.lightness, 0.66)).toColor();
}
